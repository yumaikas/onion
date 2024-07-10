local pprint = require("pprint")
local whitespace = " \t\r\n"
local Buffer = require("buffer")
local iter = require("iter")
local lex = require("lex")
local Effect = require("effects")
local Object = require("classic")
local tests = require("tests")
require("ast")
require("outputs")
require("inputs")
require("stack")
require("scanner")

function pp(...)
    local dbg_info = debug.getinfo(2)
    local cl = dbg_info.currentline
    local f = dbg_info.source:sub(2)
    local fn = dbg_info.name
    io.write(string.format("at: %s:%s: %s: ",f,cl,fn))
    pprint(...)
end

local function cond(pred, if_true, if_false)
    if pred then return if_true else return if_false end
end

function bind(obj, fn)
    return function(...)
        return fn(obj, ...)
    end
end

local function ssa_counter(start)
    local ssa_idx = start or 1

    return function()
        local ret = "_"..ssa_idx
        ssa_idx = ssa_idx + 1
        return ret
    end, function (to) ssa_idx = to end
end

local function parse_if_then_else(seq)
    local ret = {{}}
    local depth = 0
    for iv in iter.each(seq) do
        if iv == "then" then depth = depth - 1 end
        if iv == "if" then depth  = depth + 1 end
        if iv == "then" and depth == -1 then
            break
        end
        if iv == "else" and depth == 0 then 
            table.insert(ret, {})
        else
            table.insert(ret[#ret], iv)
        end
    end
    return ret
end

local iter_eff = {}
function iter_eff.is(word) return not not word:find("[^[]*%[#?%**\\[*_]*%]$") end
function tests.iter_effs_parse()
    function t(a, b) assert(iter_eff.is(a), b) end
    t("[*\\*]", "1 to 1")
    t("[\\*]", "0 to 1")
    t("[**\\*]", "2 to 1")
    t("[#\\*]", "it to 1")
    t("[#\\*_]", "it to 1,_")
end
function tests.word_iter_effs_parse()
    function t(a, b) assert(iter_eff.is(a), b) end
    t("ipairs[*\\*]", "1 to 1")
    t(":nodes[\\*]", "0 to 1")
    t("derp[**\\*]", "2 to 1")
    t("ipairs[#\\*]", "it to 1")
end

function iter_eff.parse(word, nextvar, pop)
    if not iter_eff.is(word) then
        error ("invalid iter effect: "..word)
    end
    local patt = "([^[]*)%[(#?%**)\\([*_]*)%]$"
    local _, _, word, inputs, loop_vars = word:find(patt)

    local iterAst = Iter(word)

    if inputs:find("^#") then
        iter.push(iterAst.inputs, Var("it"))
    end
    for i in inputs:gmatch("%*") do
        iter.push(iterAst.inputs, pop())
    end
    iter.reverse(iterAst.inputs)

    for i in loop_vars:gmatch("[*_]") do
        if i == "*" then
            iter.push(iterAst.loop_vars, Var(nextvar()))
        elseif i == "_" then
            iter.push(iterAst.loop_vars, Var("_"))
        end
    end

    return iterAst
end

function parse_require(tok_seq)
    local reqs = RequireList()
    for from, var in iter.pairwise(tok_seq) do
        assert(k:find('^"[^"]+"$'), "Not a valid path")
        if var == "_" then
            reqs:push(Require(from))
        else
            reqs:push(RequirePair(from, var))
        end
    end
    return reqs
end

function parse_cond_body(tok_seq)
    local clauses = {}

    for t in iter.each(tok_seq) do
        if t == "when" then 
            iter.push(clauses, {}) 
        else
            iter.push(clauses[#clauses], t)
        end
    end
    for c in iter.each(clauses) do
        assert(iter.last(c) == "then", "Cond clauses need to end with 'then'")
        assert(iter.find(c, "of"),  "Cond clauses need at least one 'of'")
        iter.pop(c)
    end

    return clauses
end

function tests.parse_iter_word()
    local stack = ItStack()
    local nextvar, reset = ssa_counter()
    local ast = iter_eff.parse("ipairs[*\\_*]",  nextvar, bind(stack, stack.pop))
    assert(ast.word == "ipairs", "parsed word")
    assert(ast.inputs[1].var, "has a var as the input")
    assert(ast.loop_vars[1].var == "_", "discards first loop var")
    assert(ast.loop_vars[2].var ~= "_", "does not discard second loop var")
end

function tests.parse_iter_noname()
    local stack = ItStack()
    local nextvar, reset = ssa_counter()
    local ast = iter_eff.parse("[*\\_*]",  nextvar, bind(stack, stack.pop))
    assert(ast.word == "", "parsed word")
    assert(ast.inputs[1].var, "has a var as the input")
    assert(ast.loop_vars[1].var == "_", "discards first loop var")
    assert(ast.loop_vars[2].var ~= "_", "does not discard second loop var")
end

local starts_do_loop = any_of("do", "+do", "do?")

local trace = false

local nextvar, reset_ssa = ssa_counter(1)

local function compile_op(op, input, _output, stacks)
    local err_info = {op=op, tok, idx, code}
    local b = stacks:pop(err_info)
    local a = stacks:pop(err_info)
    stacks:push(Op(op, a, b))
    input:tok_next()
    return _output, Effect({'a','b'}, {'c'})
end

local function compile_assign_op(op, input, output, stacks)
    input:tok_next()
    local varname = input:tok()
    local var = Var(varname)
    output:compile(Assign(varname, Op(op, var, stacks:pop())))
    input:tok_next()
end

local pre = Buffer()

local function compile(input, output, stacks)
    local function dbg()
        pp({
            input=input,
            output=output,
            stacks=stacks,
        })
    end
    local tok
    local total_effect = Effect({}, {})
    local function add_effect(a, b, ctx)
        local eff = Effect(a, b)
        total_effect = total_effect..eff
    end
    local function merge_effect(eff, ctx)
        total_effect = total_effect .. eff
    end

    local stack_height = stacks.stack:size()

    local function op(of)
        local _, effect = compile_op(of, input, output, stacks)
        merge_effect(effect, of)
    end

    while input:has_more_tokens() do
        tok = input:tok()

        if trace then pp{tok} end
        if output:envget(tok) ~= nil then
            local expr = output:envget(tok)
            if expr.var then
                stacks:push(expr)
                add_effect({}, {expr.var}, "var")
                input:tok_next()
            elseif expr.fn then 
                local call_eff = Effect({}, {})
                local call = Call(Barelit(expr.actual)) 
                for a in iter.each(expr.inputs) do
                    if a.var ~= "it" then
                        call_eff:add_in(a.var)
                        table.insert(call.args, stacks:pop())
                    end
                end
                iter.reverse(call.args)
                if expr.needs_it then
                    table.insert(call.args, 1, stacks:peek_it(tok))
                end
                for _ in iter.each(expr.outputs) do
                    local v = nextvar()
                    call_eff:add_out(v)
                    table.insert(call.rets, v)
                end
                output:compile(call)
                for r in iter.each(call.rets) do
                    stacks:push(Var(r))
                end
                merge_effect(call_eff, "call")
                input:tok_next()
            else
                pp({expr, tok})
                error("Unsupported def!")
            end
        elseif tok == "[STOP]" then error("[STOP]")
        elseif tok == "+" then op("+")
        elseif tok == "-" then op("-")
        elseif tok == "*" then op("*")
        elseif tok == "div" then op("/")
        elseif tok == "and" then op(" and ")
        elseif tok == "mod" then op("%")
        elseif tok == "or" then op(" or ")
        elseif tok == ">" then op(">")
        elseif tok == "<" then op("<")
        elseif tok == "eq?" then op("==")
        elseif tok == "<=" then op("<=")
        elseif tok == ">=" then op(">=")
        elseif tok == "neq?" then op("~=")
        elseif tok == ".." then op("..")
        elseif tok == "+=" then 
            compile_assign_op("+", input, output, stacks)
            add_effect({"a"}, {}, "+=")
        elseif tok == "-=" then 
            compile_assign_op("-", input, output, stacks)
            add_effect({"a"}, {}, "-=")
        elseif tok == "*=" then 
            compile_assign_op("-", input, output, stacks)
            add_effect({"a"}, {}, "-=")
        elseif tok == "div=" then 
            compile_assign_op("/", input, output, stacks)
            add_effect({"a"}, {}, "div=")
        elseif tok == "mod=" then 
            compile_assign_op("%", input, output, stacks)
            add_effect({"a"}, {}, "mod=")
        elseif tok == "or=" then
            compile_assign_op(" or ", input, output, stacks)
            add_effect({"a"}, {}, "or=")
        elseif tok == "and=" then
            compile_assign_op("and", input, output, stacks)
            add_effect({"a"}, {}, "and=")
        elseif tok == "..." then
            local new = nextvar()
            output:compile(Assign(new, Barelit("{...}"), true))
            stacks:push(Var(new))
            add_effect({}, {"..."}, "vararg-capture")
            input:tok_next()
        elseif tok == "len" then 
            stacks:push(UnaryOp("#", stacks:pop()))
            input:tok_next()
            add_effect({"a"}, {"#a"}, "len")
        elseif tok == "not" then
            stacks:push(UnaryOp(" not ", stacks:pop()))
            input:tok_next()
            add_effect({"a"}, {"~a"}, "not")
        elseif tok == "t[" then
            local itvar = Var(nextvar())
            output:compile(Assign(itvar.var, Barelit("{}"), true))
            stacks:push_it(itvar)
            input:tok_next()
            add_effect({}, {}, "it<")
        elseif tok == "[" then
            local itvar = Var(nextvar())
            output:compile(Assign(itvar.var, stacks:pop(), true))
            stacks:push_it(itvar)
            input:tok_next()
            add_effect({'it'}, {}, "it<")
        elseif tok == "]" then
            stacks:push(stacks:pop_it())
            input:tok_next()
            add_effect({}, {'it'}, "it>")
        elseif tok == "]." then
            stacks:pop_it()
            input:tok_next()
        elseif tok == "it" then
            stacks:push(stacks:peek_it())
            input:tok_next()
            add_effect({}, {'it'}, "it")
        elseif tok:find("%(#?[*\\]+%)$") then ---
            local _, _, name, effect = tok:find("([^(]+)%((#?[*\\]+)%)$")
            local call = Call("")
            if name:find("^%.") then
                call.call = PropGet(stacks:pop(), name:sub(2)) 
                add_effect({"obj"}, {}, "obj get call")
            elseif name:find("^:") then
                call.call = MethodGet(stacks:pop(), name:sub(2))
                add_effect({"mobj"}, {}, "obj method call")
            else
                call.call = Barelit(name) 
            end
            if effect:find("^#") then
                table.insert(call.args, stacks:peek_it(tok))
                effect = effect:sub(2)
            end
            local call_eff = Effect({}, {})

            if effect:find("^%*+$") then
                local args = {}
                for i=1,#effect do
                    table.insert(args, stacks:pop())
                    call_eff:add_in('arg'..i)
                end
                for a in iter.backwards(args) do
                    table.insert(call.args, a)
                end
                output:compile(call)
            elseif effect:find("^%**\\%**$") then
                local _,_,args,rets = effect:find("(%**)\\(%**)")
                local targs = {}
                for i=1,#args do
                    table.insert(targs, stacks:pop())
                    call_eff:add_in('arg'..i)
                end
                iter.into(call.args):collect(iter.backwards(targs))
                for i=1,#rets do
                    table.insert(call.rets,nextvar())
                end
                output:compile(call)
                for r in iter.each(call.rets) do
                    call_eff:add_out(r)
                    stacks:push(Var(r))
                end
            else
                error("Could not parse ffi call "..tok)
            end
            merge_effect(call_eff, "ffi-call")
            input:tok_next()
        elseif tok:find("^%.") then
            local prop 
            _, _, prop = tok:find("^%.(.+)")
            stacks:push(PropGet(stacks:pop(), prop)) 
            add_effect({'obj'}, {'propval'}, "getter: "..prop)
            input:tok_next()
        elseif tok:find("[^>]+>>$") then
            local name
            _,_, name = tok:find("([^>]+)>>")
            stacks:push(PropGet(stacks:peek_it(), name))
            add_effect({}, {'propval'}, "it-getter:"..name)
            input:tok_next()
        elseif tok:find("^>>.+") then
            local name
            _,_, name = tok:find("^>>(.+)")
            add_effect({'propval'}, {}, "it-setter: "..name)
            output:compile(PropSet(name, stacks:peek_it(), stacks:pop()))
            input:tok_next()
        elseif tok:find("^>.+") then
            _,_, name = tok:find("^>(.+)")
            output:compile(PropSet(name, stacks:pop(), stacks:pop()))
            input:tok_next()
            add_effect({'obj','propval'}, {}, "setter: "..name)
        elseif tok:find("^->.+") then
            _,_, name = tok:find("^->(.+)")
            local val, obj = stacks:pop(), stacks:pop()
            output:compile(PropSet(name, obj, val))
            stacks:push(obj)
            input:tok_next()
            add_effect({'obj','propval'}, {'obj'}, "setter: "..name)
        elseif tok == "dup" then
            local to_dup = stacks:pop()
            stacks:push(to_dup)
            stacks:push(to_dup)
            input:tok_next()
            add_effect({'x'}, {'x','x'}, "dup")
        elseif tok == "nip" then
            local keep = stacks:pop()
            stacks:pop()
            stacks:push(keep)
            input:tok_next()
            add_effect({'a', 'b'}, {'b'}, "nip")
        elseif tok == "swap" then
            local b, a = stacks:pop(), stacks:pop()
            stacks:push(b)
            stacks:push(a)
            input:tok_next()
            add_effect({'a', 'b'}, {'b', 'a'}, "swap")
        elseif tok == "drop" then
            stacks:pop()
            input:tok_next()
            add_effect({'a'}, {}, "drop")
        elseif tok:find("^@.+") then
            local name
            _,_, name = tok:find("^@(.+)")
            local val = Var(name)
            stacks:push(val)
            input:tok_next()
            add_effect({}, {name}, "litname")
        elseif tok == "true" then
            stacks:push(Barelit("true"))
            add_effect({}, {"true"}, "true")
            input:tok_next()
        elseif tok == "false" then
            stacks:push(Barelit(var))
            add_effect({}, {"false"}, "false")
            input:tok_next()
        elseif tonumber(tok) then
            local var = nextvar()
            output:compile(Assign(var, Barelit(tonumber(tok)), true))
            stacks:push(Var(var))
            add_effect({}, {var}, "number")
            input:tok_next()
        elseif tok == "nil" then
            local var = nextvar()
            output:compile(Assign(var, Barelit("nil"), true))
            stacks:push(Var(var))
            add_effect({}, {var}, "number")
            input:tok_next()
        elseif tok:find('^"') then
            local var = Var(nextvar())
            output:compile(Assign(var.var, Strlit(tok:sub(2, -2)), true))
            stacks:push(var)
            add_effect({}, {var.var}, "strlit")
            input:tok_next()
        elseif tok:find("[\r\n]") then
            output:compile(Whitespace(tok))
            input:tok_next()
        elseif tok:find("[^(]+%(%)") then -- print(), aka no-args call
            local _,_, name = tok:find("^([^(]+)%(%)$")
            output:compile(Call(Barelit(name)))
            input:tok_next()
        elseif tok == "table" then
            local new = nextvar()
            output:compile(Assign(new, Barelit("{}"), true))
            stacks:push(Var(new))
            add_effect({}, {'table'}, "tblnew")
            input:tok_next()
        elseif tok == "get" then
            local new = nextvar()
            local idx = stacks:pop()
            local on = stacks:pop()
            output:compile(Assign(new, IdxGet(on, idx), true))
            stacks:push(Var(new))
            add_effect({'on', 'idx'}, {'value'}, 'get')
            input:tok_next()
        elseif tok == "put" then
            local new = nextvar()
            local to = stacks:pop()
            local idx = stacks:pop()
            local on = stacks:pop()
            output:compile(IdxSet(on, idx, to))
            add_effect({'on','idx','to'},{}, 'put')
            input:tok_next()
        elseif tok == "{" then
            local scan = input:scan_ahead_by(1)
            local assigns = {}
            for stok in scan:upto("}") do
                table.insert(assigns, stok)
            end
            iter.reverse(assigns)
            for var in iter.each(assigns) do
                if not output:envget(var) then
                    output:def(var, Var(var))
                    output:compile(Assign(var, stacks:pop(), true))
                elseif not output:envget(var).var then
                    -- If this a function instead of a var, we should redefine it
                    output:def(var, Var(var))
                    output:compile(Assign(var, stacks:pop()))
                else
                    output:compile(Assign(var, stacks:pop()))
                end
            end
            add_effect(iter.copy(assigns), {}, "locals")
            input:goto_scan(scan)
        elseif tok == "require{" then
            local scan = input:scan_ahead_by(1)
            local req_toks = iter.into({}):collect(scan:upto("}"))
            local req_ast = parse_require(req_toks)

        elseif tok == ":" then
            local fn_name = input:tok_at(input.token_idx + 1)
            local fn = Fn(fn_name)

            output:pushenv()
            local is_anon = fn.fn == "{" or fn.fn == "("
            if is_anon then
                fn.fn = AnonFnName
            end
            local scan = input:scan_ahead_by(cond(is_anon, 1, 2))
            local stok = scan:at()

            assert(stok == "(" or stok == "{", "Stack effect comment required!")
            scan:go_next()
            local params_to_locals = stok == "{"
            fn.inputs = {}

            -- local expr_stack = makestack("Expr stack for "..tostring(fn.fn).." definition")
            local fn_stacks = ExprState(
                "Expr stack for "..tostring(fn.fn).." def",
                "It stack for "..tostring(fn.fn).." def"
            )

            local body_ast = Buffer()
            local arg_eff = Effect({}, {})
            for stok in scan:upto("--") do
                if stok == "}" or stok == ")" then
                    error("Missing -- in stack effect definition for " .. fn.fn .. "!")
                end
                if stok == "#"  then
                    fn.needs_it = true
                    fn_stacks:push_it(Var("it"))
                elseif stok == "..." then
                    local par = Var("...")
                    iter.push(fn.inputs, par)
                    arg_eff:add_in(par.var)
                elseif params_to_locals then
                    local param = Var(stok) 
                    iter.push(fn.inputs, param)
                    arg_eff:add_in(param.var)
                    output:def(stok, param)
                else
                    local param = Var("p"..(#fn.inputs + 1))
                    iter.push(fn.inputs, param)
                    arg_eff:add_in(param.var)
                    arg_eff:add_out(param.var)
                    fn_stacks:push(param)
                end
            end
            fn.outputs = {}
            local end_tok
            if params_to_locals then end_tok = "}" else end_tok = ")" end

            iter.into(fn.outputs):collect(scan:upto(end_tok))
            fn.body_toks = iter.collect(scan:upto(balanced(':', ';')))
            local _input_ = CompilerInput(fn.body_toks)
            local _output_ = output:derived()
            local body_comp, body_eff = compile(_input_,_output_, fn_stacks)
            local comb_eff = arg_eff..body_eff
            comb_eff:assert_matches_depths(#fn.inputs, #fn.outputs, fn.fn)
            fn.body = body_comp.code
            if fn.needs_it then table.insert(fn.inputs, 1, Var("it")) end
            -- merge_effect(comb_eff, "strange-def?")
            local ret = Return() 

            for val in fn_stacks.stack:each() do
                if not instanceof(val, Barrier) then
                    ret:push(val)
                end
            end
            fn.body:compile(ret)
            if fn.fn ~= AnonFnName then
                output:compile(fn)
                output:defn(fn.fn, fn)
            else
                stacks:push(fn)
                add_effect({}, {'anon_fn'}, "anon_fn")
            end
            input:goto_scan(scan)
            output:popenv()
            if output:is_toplevel() then
                print() print() print()
                reset_ssa(1)
            end
        elseif tok == "if" then
            local cond = stacks:pop() 
            add_effect({'cond'}, {}, "if-cond")
            local scan = input:scan_ahead_by(1)
            local body = iter.collect(scan:upto(balanced("if", "then")))

            if iter.has_value(body, "else") then
                local arms = parse_if_then_else(body)
                if #arms ~= 2 then
                    pp(arms)
                    error("cannot have more than one 'else' in an if body")
                end
                local s_true = stacks:copy("If True")
                local s_false = stacks:copy("If False")

                local barrier = s_true:barrier(nextvar)
                local arm_true, eff_true = compile(CompilerInput(arms[1]), output:derived(), s_true)
                local arm_false, eff_false = compile(CompilerInput(arms[2]), output:derived(), s_false)

                eff_true:assert_match(eff_false)
                -- Declare the destination variables for the if/else branches
                for i=1,#eff_true.in_eff do
                    stacks:pop()
                end
                for a in iter.each(barrier.assigns) do output:compile(a) end
                local bar_vars = iter.copy(barrier.vars)
                for o=1,#eff_true.out_eff do
                    local v = table.remove(bar_vars) 
                    if not v then
                        v = Var(nextvar())
                        output:compile(Declare():add(v.var))
                    end
                    arm_true:compile(Assign(v.var, s_true:pop()))
                    arm_false:compile(Assign(v.var, s_false:pop()))
                    stacks:push(v)
                end

                output:compile(If(cond, arm_true.code, arm_false.code))
                -- print(pre:str().."true_eff", eff_true)
                -- print(pre:str().."false_eff", eff_false)
                merge_effect(eff_true, "if-else")
            else
                local barrier = stacks:barrier(nextvar)
                local if_body, if_eff = compile(CompilerInput(body), output:derived(), stacks)

                print(pre:str().."IF_EFF", if_eff, total_effect)

                for a in iter.each(barrier.assigns) do output:compile(a) end

                local outvars = Buffer()
                local bar_vars = iter.copy(barrier.vars)
                for o=1,#if_eff.out_eff do
                    local v = table.remove(bar_vars)
                    if_body:compile(Assign(v.var, stacks:pop()))
                    outvars:push(v)
                end
                stacks.stack:pop_barrier()
                for d in outvars:each() do
                    stacks:push(d)
                end
                merge_effect(if_eff, "if")
                output:compile(If(cond, if_body.code))
            end
            input:goto_scan(scan)
        elseif tok == "do" then
            local from = stacks:pop()
            local to = stacks:pop()
            add_effect({"from", "to"}, {}, "do loop")
            local scan = input:scan_ahead_by(1)
            local cnt_var = Var(nextvar())
            stacks:push(cnt_var)
            local loop_body = iter.collect(scan:upto(balanced(starts_do_loop, "loop")))
            local loop_code, loop_eff = compile(CompilerInput(loop_body), output:derived(), stacks)
            loop_eff:assert_matches_depths(1, 0, "do loop body")
            output:compile(DoRange(from, to, cnt_var, loop_code.code))
            input:goto_scan(scan)
        elseif tok == "+do" then
            local step = stacks:pop()
            local from = stacks:pop()
            local to = stacks:pop()
            add_effect({"from", "to", "step"}, {}, "do loop")
            local scan = input:scan_ahead_by(1)
            local cnt_var = Var(nextvar())
            stacks:push(cnt_var)
            local loop_body = iter.collect(scan:upto(balanced(starts_do_loop, "loop")))
            local loop_code, loop_eff = compile(CompilerInput(loop_body), output:derived(), stacks)
            loop_eff:assert_matches_depths(1, 0, "do loop body")
            output:compile(DoRangeStep(from, to, step, cnt_var, loop_code.code))
            input:goto_scan(scan)
        elseif tok == "do?" then
            local scan = input:scan_ahead_by(1)
            local cond = iter.collect(scan:upto("while"))
            local body = iter.collect(scan:upto(balanced(starts_do_loop, "loop")))
            local cond_body, cond_eff = compile(CompilerInput(cond), output:derived(), stacks)
            cond_eff:assert_matches_depths(0, 1, "do?..while loop cond")
            cond_body:compile(stacks:pop())
            local loop_body, loop_eff = compile(CompilerInput(body), output:derived(), stacks)
            loop_eff:assert_matches_depths(0, 0, "do?..while loop body")
            output:compile(DoWhile(cond_body.code, loop_body.code))
            input:goto_scan(scan)
        elseif tok == "cond" then
            local scan = input:scan_ahead_by(1)
            local cond_body = iter.collect(scan:upto("end"))
            local clauses = parse_cond_body(cond_body)
            local clauseBodies = {}
            local clause_in = nil
            local clause_out = nil

            -- error("Cond not yet implemented!")
            -- TODO: 
            local clause_stack_1 = stacks:copy()
            local clause_barrier = clause_stack_1:barrier()

            for c in iter.each(clauses) do
                local arms = iter.split(c, "of")
                assert(#arms == 2, "Each clause should only have one 'of' token")

                local pred_body, pred_eff = compile(CompilerInput(arms[1]), output:derived(), stacks)
                pred_eff:assert_matches_depths(0, 1, "cond clause predicate arm")
                pred_body:compile(stacks:pop())
                local barrier= clause_stack:barrier(nextvar)
                if clause_in and clause_out then
                    local clause_body, clause_eff = compile(CompilerInput(arms[2]), output:derived(), stacks:copy())
                    clause_eff:assert_matches_depths(clause_in, clause_out, "cond clause body arm")
                else
                    local clause_body, clause_eff = compile(CompilerInput(arms[2]), output:derived(), clause_stack_1)
                    clause_in = #clause_eff.in_eff
                    clause_out = #clause_eff.out_eff
                end
            end
        elseif tok == "each" then
            local table_to_each = stacks:pop() 
            add_effect({'to-iter'}, {}, "each-table")
            local scan = input:scan_ahead_by(1)
            local body = iter.collect(scan:upto(balanced(any_of("each", iter_eff.is), "for")))
            local iter_var = Var(nextvar())
            stacks:push(iter_var)
            local each_body, each_eff = compile(CompilerInput(body), output:derived(), stacks)
            each_eff:assert_matches_depths(1, 0, "each body")
            output:compile(Each(table_to_each, iter_var, each_body.code))
            input:goto_scan(scan)
        elseif iter_eff.is(tok) then
            local iterAst = iter_eff.parse(tok, nextvar, bind(stacks, stacks.pop))
            add_effect(iter.map(iterAst.inputs, tostring), {}, "iter inputs")
            local scan = input:scan_ahead_by(1)
            local body = iter.collect(scan:upto(balanced(any_of(iter_eff.is, "each"), "for")))
            local num_loop_vars = 0
            for iter_var in iter.each(iterAst.loop_vars) do
                if iter_var.var ~= "_" then
                    stacks:push(iter_var)
                    num_loop_vars = num_loop_vars + 1
                end
            end
            local iter_body, iter_eff = compile(CompilerInput(body), output:derived(), stacks)
            iter_eff:assert_matches_depths(num_loop_vars, 0, "iter_body")
            iterAst.body = iter_body.code
            output:compile(iterAst)
            input:goto_scan(scan)
        else
            pp{tok, output:envkeys()}

            error("Unexpected token: " .. tok)
        end 
    end
    if output:is_toplevel() then
        local ret = Return()
        for r in stacks.stack:each() do
            ret:push(r)
        end
        output:compile(ret)
    end
    return output, total_effect
end

local function emit(ast, output)
    if not instanceof(ast, Ast) then
        output:push("--[[")
        output:push(string.format("Unsupported node: %s", ast or "nil"))
        output:push("]]")
        return
    end

    if instanceof(ast, Block) then
        for item in ast:each() do
            emit(item, output)
        end
    elseif instanceof(ast, Whitespace) then
        output:push(ast.ws)
    elseif instanceof(ast, DoWhile) then
        output:push(" while ")
        emit(ast.cond, output)
        output:push(" do ")
        emit(ast.body, output)
        output:push(" end ")
    elseif instanceof(ast, Each) then
        output:push(" for _, " .. ast.itervar.var .. " in ipairs(")
        emit(ast.input, output)
        output:push(") do ")
        emit(ast.body, output)
        output:push(" end ")
    elseif instanceof(ast, IdxGet) then
        output:push(" ")
        emit(ast.on, output)
        output:push("[")
        emit(ast.idx, output)
        output:push("]")
    elseif instanceof(ast, IdxSet) then
        output:push(" ")
        emit(ast.on, output)
        output:push("[")
        emit(ast.idx, output)
        output:push("] = ")
        emit(ast.to, output)
        output:push(" ")
    elseif instanceof(ast, DoRange) then
        output:push(" for ")
        emit(ast.loop_var, output)
        output:push("=")
        emit(ast.from, output)
        output:push(", ")
        emit(ast.to, output)
        output:push(" do ")
        emit(ast.body, output)
        output:push(" end ")
    elseif instanceof(ast, DoRangeStep) then
        output:push(" for ")
        emit(ast.loop_var, output)
        output:push("=")
        emit(ast.from, output)
        output:push(", ")
        emit(ast.to, output)
        output:push(", ")
        emit(ast.step, output)
        output:push(" do ")
        emit(ast.body, output)
        output:push(" end ")
    elseif instanceof(ast, Iter) then
        output:push(" for ")
        for v in iter.each(ast.loop_vars) do
            emit(v, output)
            output:push(", ")
        end
        if #ast.loop_vars > 0 then output:pop_throw("iter.loop_vars") end
        output:push(" in ")
        if #ast.word > 0 then
            output:push(ast.word)
            output:push("(")
            for inp in iter.each(ast.inputs) do 
                emit(inp, output)
                output:push(", ") 
            end
            if #ast.inputs > 0 then output:pop_throw("iter.inputs") end
            output:push(")")
        else
            for inp in iter.each(ast.inputs) do 
                emit(inp, output)
                output:push(", ") 
            end
            if #ast.inputs > 0 then output:pop_throw("iter.inputs") end
        end
        output:push(" do ")
        emit(ast.body, output)
        output:push(" end ")
    elseif instanceof(ast, UnaryOp) then
        output:push("(")
        output:push(ast.op)
        emit(ast.a, output)
        output:push(")")
    elseif instanceof(ast, Fn) then
        output:push(' function ')
        if ast.fn ~= AnonFnName then
            output:push(ast.actual)
        end
        output:push('(')
        if #ast.inputs > 0 then
            for inp in iter.each(ast.inputs) do
                output:push(inp.var)
                output:push(", ")
            end
            output:pop_throw("fnargs")
        end
        output:push(') ')
        for stmt in ast.body:each() do
            emit(stmt, output)
        end
        output:push(" end ")
    elseif instanceof(ast, MethodGet) then
        emit(ast.on, output)
        output:push(":"..ast.name)
        output:push("")
    elseif ast.cond and ast.when_true and ast.when_false then
        output:push(" if ")
        emit(ast.cond, output)
        output:push(" then ")
        for stmt in ast.when_true:each() do
            emit(stmt, output)
        end
        output:push(" else ")
        for stmt in ast.when_false:each() do
            emit(stmt, output)
        end
        output:push(" end ")
    elseif ast.cond and ast.when_true then
        output:push(" if ")
        emit(ast.cond, output)
        output:push(" then ")
        for stmt in ast.when_true:each() do
            emit(stmt, output)
        end
        output:push(" end ")
    elseif ast.prop_set then
        emit(ast.on, output)
        output:push("."..ast.prop_set)
        output:push(" = ")
        emit(ast.to, output)
        output:push(" ")
    elseif ast.prop_get then
        emit(ast.value, output)
        output:push("."..ast.prop_get)
        output:push("")
    elseif ast.assign then
        if ast.new then
            output:push(" local ")
        end
        output:push(" ")
        output:push(ast.assign)
        output:push("=")
        emit(ast.value, output)
        output:push(" ")
    elseif ast.decl then
        output:push(" local ")
        for d in iter.each(ast.decl) do
            output:push(d)
            output:push(",")
        end
        output:pop_throw("decls")
        output:push(" ")
    elseif ast.var then
        output:push(ast.var)
    elseif ast.op then
        output:push("(")
        emit(ast.a, output)
        output:push(ast.op)
        emit(ast.b, output)
        output:push(")")
    elseif ast.barelit ~= nil then
        output:push(tostring(ast.barelit))
    elseif ast.strlit ~= nil then
        output:push(string.format("%q", ast.strlit))
    elseif ast.ret then
        output:push(" return ")
        for v in ast.ret:each() do
            emit(v, output)
            output:push(", ")
        end
        output:pop_throw("returns")
    elseif ast.call then
        if #ast.rets > 0 then
            output:push(" local ")
        end
        for r in iter.each(ast.rets) do
            output:push(r)
            output:push(", ")
        end
        if #ast.rets > 0 then
            output:pop_throw("call rets")
            output:push(" = ")
        end
        output:push(" ")
        emit(ast.call, output)
        output:push("(")
        for a in iter.each(ast.args) do
            emit(a, output)
            output:push(", ")
        end
        if #ast.args > 0 then
            output:pop_throw("call args")
        end
        output:push(")")

    else
        output:push("--[[")
        output:push(string.format("Unsupported node: %s", ast or "nil"))
        output:push("]]")
    end
end

local function rootEnv()
    local ret = Env()
    ret:def("ipairs", Fn("ipairs",nil, {Var("t")}, {Var("f"), Var("s"), Var("v")}))
    return ret
end

local function eval_ast_as_lua(ast)
    local output = Buffer()
    local ok, err = pcall(emit, ast, output)
    if not ok then error(err) end
    local lua_code = output:str()
    local maybe_fn, msg = pcall(load, lua_code)
    if maybe_fn then
        return maybe_fn()
    else
        error(msg)
    end
end

local function compile_ast_to_lua(ast)
    local output = Buffer()
    local ok, err = pcall(emit, ast, output)
    local lua_code = output:str()
    return lua_code
end

local function compile_ast_as_chunk(ast, name, env)
    local output = Buffer()
    local ok, err = pcall(emit, ast, output)
    if not ok then error(err) end
    local lua_code = output:str()
    local maybe_fn, msg_or_ret = load(lua_code, name, "t", env)
    if maybe_fn then
        return maybe_fn
    else
        error(msg)
    end
end

local onion = {}

function onion.load(code, name, env)
    local toks = lex(code)
    local ast, _ = compile(
        CompilerInput(toks),
        CompilerOutput(rootEnv()),
        ExprState("toplevel expression", "toplevel subject")
    )
    return compile_ast_as_chunk(ast.code, name, env or _G)
end

function onion.req(calling_env, req_name, req_var) 
    local req = require("require")
    local path = package.searchpath(package_name, "./?.fth;./?/init.fth")
    local f = io.open(path, "r")
    local str = f:read("*a")
    f:close()
    local toks = lex(str)
    local myEnv = rootEnv()
    local myStacks = ExprState("toplevel experssion", "toplevel subject")

    local ast, _ = compile(CompilerInput(toks), CompilerOutput(myEnv), myStacks)
end

function onion.eval(code)
    local toks = lex(code)
    local ast, _ = compile(
        CompilerInput(toks),
        CompilerOutput(rootEnv()),
        ExprState("toplevel expression", "toplevel subject")
    )
    return eval_ast_as_lua(ast.code)
end

function onion.compile(code)
    local toks = lex(code)
    local env = rootEnv()
    local ast, _ = compile(
        CompilerInput(toks),
        CompilerOutput(env),
        ExprState("toplevel expression", "toplevel subject")
    )
    pp{env=env}
    return compile_ast_to_lua(ast.code)
end

function onion.repl_session()
    local onionEnv = rootEnv()
    local fnEnv = {cont=true}
    local exprState = ExprState(
        "toplevel expression", "toplevel subject"
    )
    local stack = {}
    setmetatable(fnEnv, {__index=_G})

    local ret = {}
    local repl_idx = 0
    function ret.eval(line)
        local toks = lex(line)
        local ast, eff = compile(
            CompilerInput(toks),
            CompilerOutput(onionEnv),
            exprState
        )
        repl_idx = repl_idx + 1
        local chunk = compile_ast_as_chunk(ast.code, "repl:"..repl_idx, fnEnv)
        for i=1, exprState.stack:size() do
            exprState.stack:put(i,Barelit("(({...})["..i.."])")) 
        end
        
        stack = table.pack(chunk(table.unpack(stack)))
        return stack
    end
    function ret.should_continue()
        return fnEnv.cont
    end

    return ret
end


return onion
