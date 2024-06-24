local pprint = require("pprint")
local whitespace = " \t\r\n"
local Buffer = require("buffer")
local iter = require("iter")
local lex = require("lex")
local Effect = require("effects")
require("ast")
require("outputs")
require("inputs")
require("stack")
require("scanner")

local pfmt = pprint.pformat
pprint.setup {
    -- use_tostring = true
}

function pp(...)
    local dbg_info = debug.getinfo(2)
    local cl = dbg_info.currentline
    local f = dbg_info.source:sub(2)
    local fn = dbg_info.name
    io.write(string.format("at: %s:%s: %s: ",f,cl,fn))
    pprint(...)
end

function cond(pred, if_true, if_false)
    if pred then return if_true else return if_false end
end

function parse_if_then_else(seq)
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

function chunk_for_each_loop(seq)
    local depth = 0
    local ret = {}
    for tok in iter.each(seq) do
        if tok == "for" then depth = depth + 1 end
        if tok == "each" then depth = depth - 1 end
        table.insert(ret, tok)
    end

    return ret
end

function parse_do_loop(seq)
    local ret = {}
    for iv in iter.each(seq) do
    end
    error("do loops not implemented!")
end

local trace = false

local ssa_idx = 1

function nextvar()
    local ret = "_"..ssa_idx
    ssa_idx = ssa_idx + 1
    return ret
end

function compile_op(op, input, output, stacks)
    local err_info = {op=op, tok, idx, code}
    -- pp{OP=op}
    print(stacks.stack)
    local b = stacks:pop(err_info)
    local a = stacks:pop(err_info)
    output:compile(stacks:push(Op(op, a, b)))
    input:tok_next()
    return _output, Effect({'a','b'}, {'c'})
end

local pre = Buffer()

function compile(input, output, stacks)
    --io.write(pre:str()) 
    output:enter()
    --pre:push("    ")
    local function dbg()
        pp({
            input=input,
            output=output,
            stacks=stacks,
        })
    end
    -- print("Compile called from: ".. debug.getinfo(2).currentline)
    -- pp({env=env, defs=defs})

    local tok
    local total_effect = Effect({}, {})
    local function add_effect(a, b, ctx)
        local eff = Effect(a, b)
        total_effect = total_effect..eff
        print(pre:str().."a", ctx, tok, total_effect, eff)
    end
    local function merge_effect(eff, ctx)
        total_effect = total_effect .. eff
        print(pre:str().."m", ctx, tok, total_effect, eff)
    end

    local stack_height = stacks.stack:size()

    local function op(of)
        local _, effect = compile_op(of, input, output, stacks)
        merge_effect(effect, of)
    end

    while input:has_more_tokens() do
        tok = input:tok()

        if trace then pp{tok} end
        -- pp(output)
        if output:envget(tok) ~= nil then
            local expr = output:envget(tok)
            -- pp{EXPR=expr}
            if expr.var then
                output:compile(stacks:push(expr))
                input:tok_next()
                add_effect({}, {expr.var}, "var")
            elseif expr.fn then 
                local call_eff = Effect({}, {})
                local call = Call(Barelit(expr.actual)) 
                if expr.needs_it then
                    table.insert(call.args, stacks:peek_it(tok))
                    table.remove(call.args, 1)
                end
                --pp({"INPUTS", expr.inputs})
                for a in iter.each(expr.inputs) do
                    if a.var ~= "it" then
                        call_eff:add_in(a.var)
                        table.insert(call.args, stacks:pop())
                    end
                end
                iter.reverse(call.args)
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
        elseif tok == "and" then op("and")
        elseif tok == "mod" then op("%")
        elseif tok == "or" then op("or")
        elseif tok == ">" then op(">")
        elseif tok == "<" then op("<")
        elseif tok == "eq?" then op("==")
        elseif tok == "<=" then op("<=")
        elseif tok == ">=" then op(">=")
        elseif tok == "neq?" then op("~=")
        elseif tok == "[" then
            local itvar = Var("it_"..(stacks.it_stack:size()+1))
            output:compile(Assign(itvar.var, stacks:pop(), true))
            stacks:push_it(itvar)
            input:tok_next()
            add_effect({'it'}, {}, "it<")
        elseif tok == "]" then
            output:compile(stacks:push(stacks:pop_it()))
            input:tok_next()
            add_effect({}, {'it'}, "it>")
        elseif tok == "]." then
            stacks:pop_it()
            input:tok_next()
        elseif tok == "it" then
            output:compile(stacks:push(stacks:peek_it()))
            input:tok_next()
            add_effect({}, {'it'}, "it")
        elseif tok:find("^%.") then
            local prop 
            _, _, prop = tok:find("^%.(.+)")
            --output:compile(PropGet(stacks:pop(), prop))
            --stacks.stack:push_return()
            output:compile(stacks:push(PropGet(stacks:pop(), prop)))
            add_effect({'obj'}, {'propval'}, "getter: "..prop)
            input:tok_next()
        elseif tok:find("[^>]+>>$") then
            local name
            _,_, name = tok:find("([^>]+)>>")
            output:compile(stacks:push(PropGet(stacks:peek_it(), name)))
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
        elseif tok == "dup" then
            local to_dup = stacks:pop()
            stacks:push(to_dup)
            output:compile(stacks:push(to_dup))
            input:tok_next()
            add_effect({'x'}, {'x','x'}, "dup")
        elseif tok == "nip" then
            local keep = stacks:pop()
            stacks:pop()
            output:compile(stacks:push(keep))
            input:tok_next()
            add_effect({'a', 'b'}, {'b'}, "nip")
        elseif tok == "swap" then
            local b, a = stacks:pop(), stacks:pop()
            local ex
            output:compile(stacks:push(b))
            output:compile(stacks:push(a))
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
            output:compile(stacks:push(val))
            input:tok_next()
            add_effect({}, {name}, "litname")
        elseif tonumber(tok) then
            output:compile(stacks:push(Barelit(tonumber(tok))))
            add_effect({}, {"n"..stacks.stack:size()}, "number")
            input:tok_next()
        elseif tok:find('^"') then
            local var = Var(nextvar())
            output:compile(stacks:push(Strlit(tok)))
            add_effect({}, {var}, "strlit")
            input:tok_next()
        elseif tok:find("[^(]+%(%)") then -- print(), aka no-args call
            local _,_, name = tok:find("^([^(]+)%(%)$")
            output:compile(Call(Barelit(name)))
            -- Has no stack effect
            input:tok_next()
        elseif tok:find("%(#?[*\\]+%)$") then ---
            local _, _, name, effect = tok:find("([^(]+)%((#?[*\\]+)%)$")

            local call = Call("")
            if name:find("^%.") then
                call.call = PropGet(stacks:pop(), name:sub(2)) 
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
            elseif effect:find("^%*+\\%*+$") then
                local _,_,args,rets = effect:find("(%*+)\\(%*+)")
                local targs = {}
                for i=1,#args do
                    table.insert(targs, stacks:pop())
                    call_eff:add_in('arg'..i)
                end
                iter.into(call.args):collect(iter.backwards(targs))

                --error("Calls need to switch to new stack vars")
                output:compile(call)
                local ret_assigns = {}
                for r in iter.each(call.rets) do
                    call_eff:add_out(r)
                    iter.push(ret_assigns, stacks:push_return())
                end
                call.ret = ret_assigns
            else
                error("Could not parse ffi call "..tok)
            end
            merge_effect(call_eff, "ffi-call")
            input:tok_next()
        elseif tok == "table" then
            output:compile(stacks:push(Barelit("{}")))
            add_effect({}, {'table'}, "tblnew")
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
                else
                    output:compile(Assign(var, stacks:pop()))
                end
            end
            add_effect(iter.copy(assigns), {}, "locals")
            input:goto_scan(scan)
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
            local _output_ = output:derived()
            for stok in scan:upto("--") do
                --pp{stok}
                if stok == "}" or stok == ")" then
                    error("Missing -- in stack effect definition for " .. fn.fn .. "!")
                end
                if stok == "#"  then
                    fn.needs_it = true
                    fn_stacks:push_it(Var("it"))
                elseif params_to_locals then
                    local param = Var(stok) 
                    table.insert(fn.inputs, param)
                    arg_eff:add_in(param.var)
                    _output_:def(stok, param)
                else
                    local param = Var("p"..(#fn.inputs + 1))
                    table.insert(fn.inputs, param)
                    arg_eff:add_in(param.var)
                    arg_eff:add_out(param.var)
                    _output_:compile(fn_stacks:push(param))
                end
            end
            fn.outputs = {}
            local end_tok
            if params_to_locals then end_tok = "}" else end_tok = ")" end

            iter.into(fn.outputs):collect(scan:upto(end_tok))
            fn.body_toks = iter.collect(scan:upto(balanced(':', ';')))
            -- fn_stacks:push_def_info(fn.fn)
            local _input_ = CompilerInput(fn.body_toks)
            local body_comp, body_eff = compile(_input_,_output_, fn_stacks)
            local comb_eff = arg_eff..body_eff
            print(arg_eff, body_eff)
            print(comb_eff)
            -- print(pre:str().."XRD", body_eff)
            -- print(pre:str().."def", comb_eff,arg_eff,body_eff, pfmt(fn.body_toks), pfmt(fn.inputs), pfmt(fn.outputs))
            comb_eff:assert_matches_depths(#fn.inputs, #fn.outputs, fn.fn)
            -- fn_stacks:pop_def_info()
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
                output:compile(stacks:push(fn))
                add_effect({}, {'anon_fn'}, "anon_fn")
            end
            input:goto_scan(scan)
            output:popenv()
            fn.stackvars = iter.copy(fn_stacks.stack.vars)
            if output:is_toplevel() then
                print() print() print()
                ssa_idx = 1
            end
        elseif tok == "if" then
            local cond = stacks:pop() 
            add_effect({'cond'}, {}, "if-cond")
            local scan = input:scan_ahead_by(1)
            local arms = parse_if_then_else(iter.collect(scan:upto(balanced("if", "then"))))
            if #arms > 2 then
                    pp(arms)
                error("Cannot have more tha  one 'else' in an if body")
            end

            if #arms == 2 then
                local s_true = stacks:copy("If True")
                print("S_TRUE", stacks.stack)
                print("S_TRUE", s_true.stack)
                local s_false = stacks:copy("If False")

                local arm_true, eff_true = compile(CompilerInput(arms[1]), output:derived(), s_true)
                local arm_false, eff_false = compile(CompilerInput(arms[2]), output:derived(), s_false)

                eff_true:assert_match(eff_false)
                for i=stacks.stack:size()+1,s_true.stack:size() do
                    stacks.stack:push_return()
                end
                -- for i=stacks.stack:size(),s_true.stack:size(),-1 do
                --      stacks.stack:pop()
                -- end

                -- Declare the destination variables for the if/else branches

                output:compile(If(cond, arm_true.code, arm_false.code))
                print(pre:str().."true_eff", eff_true)
                print(pre:str().."false_eff", eff_false)
                merge_effect(eff_true, "if-else")
                print("der")
            else
                local if_body, if_eff = compile(CompilerInput(arms[1]), output:derived(), stacks)
                merge_effect(if_eff, "if")
                output:compile(If(cond, if_body.code))
            end
            input:goto_scan(scan)
        elseif tok == "do" then
            error("Do loops not implemented")
        elseif tok == "for" then
            local scan = input:scan_ahead_by(1)
            local body = Buffer():collect(scan:upto(balanced("for", "each"))).items
            local iter_scan = Scanner(body, 1)
            local iterator_expr =  Buffer():collect(iter_scan:upto("do"))
            local body_arg_effect = iter_scan:at() 
            iter_scan:go_next()
            local loop_body = iter.collect(iter_scan:rest())
            local for_eff = Effect({}, {})
            local iter_body, iter_eff = compile(CompilerInput(iterator_expr.items), output:derived(), stacks)
            output:compile_iter(iter_body.code:each())
            if #iter_eff.out_eff > 3 then
                error(
                "Too many outputs in iterator expresion for loop in "
                ..stacks:current_def_name())
            end
            for_eff = for_eff..Effect(iter_eff.in_eff, {})
            local loop_def = For()
            for i=1,#iter_eff.out_eff do 
                loop_def:add_iter_var(stacks:pop()) 
            end
            iter.reverse(loop_def.for_iter)

            if not body_arg_effect:find("^[*_]+$") then
                error("Invalid for body arg notation: "
                ..body_arg_effect.." in "..stacks:current_def_name())
            end
            local arg_eff = Effect({},{})
            for c in body_arg_effect:gmatch("([_*])") do
                if c == "_" then
                    table.insert(loop_def.var_expr, Var("_"))
                elseif c == "*" then
                    local v = stacks.stack:push_return()
                    table.insert(loop_def.var_expr, v)
                    arg_eff:add_out(v.var)
                end
            end
            print(stacks.stack)

            local main_loop_body, main_loop_eff = compile(CompilerInput(loop_body), output:derived(), stacks)
            print(main_loop_body.code)

            local comb_eff = arg_eff..main_loop_eff
            comb_eff:assert_balanced()
            for_eff = for_eff..arg_eff..main_loop_eff

            loop_def.body = main_loop_body.code
            output:compile(loop_def)
            input:goto_scan(scan)
            merge_effect(for_eff, "foreach")
        else
            pp{tok, output:envkeys()}

            error("Unexpected token: " .. tok)
        end 
        
    end
    -- print(pre:str().."TOTAL", total_effect)
    -- io.write(pre:str()) 
    output:exit()
    --pre:pop_throw()
    return output, total_effect
end

function emit(ast, output)
    if not instanceof(ast, Ast) then
        output:push(" --[[unsupported: ")
        output:push(tostring(ast))
        output:push("]] ")
        return 
    end

    if instanceof(ast, Block) then
        for item in ast:items() do
            emit(item, output)
        end
    elseif instanceof(ast, Box) then
        emit(ast.holding, output)
    elseif ast.for_iter then
        output:push(" for ")
        for var in iter.each(ast.var_expr) do
            output:push(var.var)
            output:push(", ")
        end
        output:pop_throw("for") 
        output:push(" in ")
        for var in iter.each(ast.for_iter) do
            output:push(var.var)
            output:push(", ")
        end
        output:pop_throw("iter")
        output:push(" do ")
        for stmt in ast.body:each() do
            emit(stmt, output)
        end
        output:push(" end ")
    elseif ast.fn then
        output:push('function ')
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

        if #ast.stackvars > 0 then
            output:push(" local ")
            output:push(iter.str(iter.map(ast.stackvars, function(v) return v.var end), ","))
        end
        for stmt in ast.body:each() do
            emit(stmt, output)
        end
        output:push(" end\n")
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
        output:push("if ")
        emit(ast.cond, output)
        output:push(" then ")
        for stmt in ast.when_true:each() do
            -- pp(stmt)
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
        -- pp(ast)
        if ast.new then
            output:push("local")
        end
        output:push(" ")
        output:push(ast.assign)
        output:push("=")
        emit(ast.value, output)
        output:push(" ")
    elseif ast.decl then
        output:push("local ")
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
        output:push("return ")
        for v in ast.ret:each() do
            emit(v, output)
            output:push(", ")
        end
        output:pop_throw("returns")
    elseif ast.call then
        --if #ast.rets > 0 then output:push("local ") end
        for r in iter.each(ast.rets) do
            output:push(r)
            output:push(", ")
        end
        if #ast.rets > 0 then
            output:pop_throw("call rets")
            output:push(" = ")
        end
        --pp(ast)
        emit(ast.call, output)
        output:push("(")
        for a in iter.each(ast.args) do
            emit(a, output)
            output:push(", ")
        end
        if #ast.args > 0 then
            output:pop_throw("call args")
        end
        output:push(") ")

    else
        output:push("--[[ Unsupported: ")
        output:push(tostring(ast))
        output:push("]]")
    end
end


function to_lua(ast)
    local output = Buffer()
    -- pp{output}
    local ok, err = pcall(emit, ast, output)
    -- pp("ERR?",ok, err, output)
    if ok then
        local towrite = output:str():gsub("[ \t]+", " ")
        io.write(towrite)
    else
        for i=1,4 do print(string.rep("*", 40)) end
        pprint.setup {
            use_tostring=false
        }
        print("unsupported ast", ast)
        pprint.setup {
            use_tostring=false
        }
        error(err)
    end

end

function rootEnv()
    local ret = Env()
    ret:def("ipairs", Fn("ipairs",nil, {Var("t")}, {Var("f"), Var("s"), Var("v")}))
    return ret
end

function main()

    local argIdx = 1
    while argIdx <= #arg do
        if arg[argIdx] == "--lex" then
            local f = io.open(arg[argIdx + 1], "r")
            local str = f:read("*a")
            local toks = lex(str)
            for i,t in ipairs(toks) do
                io.write("["..t .. "] ")
            end
            print()
            argIdx = argIdx + 2
        elseif arg[argIdx] == "--compile" then
            print() print()
            local f = io.open(arg[argIdx + 1], "r")
            local str = f:read("*a")
            local toks = lex(str)
            local output = CompilerOutput(rootEnv()) 
            local input = CompilerInput(toks)
            local stacks = ExprState("toplevel expression", "toplevel subject")
            local ast = compile(input, output, stacks).code
            --pprint(output.def_depth)
            print((table.concat(toks, " "):gsub(";%s+", ";\r\n")))
            -- print(str) print()
            -- to_lua(output.env)
            -- pp(ast)

            for n in ast:each() do
                --print(n)
                to_lua(n)
            end

            local buf = Buffer()
            if stacks.stack:size() > 0 then
                buf:push(" return ")
                for n in stacks.stack:each() do
                    emit(n, buf)
                    buf:push(", ")
                end
                buf:pop_throw()
            end
            -- io.write(buf:str())

            argIdx = argIdx + 2
            print() print()
        else
            error("Unrecognized arg: " .. arg[argIdx])
        end
    end
end

main()

