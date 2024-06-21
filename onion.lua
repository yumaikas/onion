local pprint = require("pprint")
local whitespace = " \t\r\n"
local Buffer = require("buffer")
local iter = require("iter")
local lex = require("lex")
require("ast")
require("outputs")
require("inputs")
require("stack")
require("scanner")

pprint.setup {
    -- use_tostring = true
}

function pp(...)
    io.write("at: ".. debug.getinfo(2).currentline.." ")
    pprint(...)
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

function compile(input, output, stacks)
    -- pp{"COMPILE", output.def_depth}
    output:enter()
    function dbg()
        pp({
            input=input,
            output=output,
            stacks=stacks,
        })
    end
    -- print("Compile called from: ".. debug.getinfo(2).currentline)
    -- pp({env=env, defs=defs})

    function nextvar()
        local ret = "__s"..ssa_idx
        ssa_idx = ssa_idx + 1
        return ret
    end
    local tok

    function op(op)
        local err_info = {op=op, tok, idx, code}
        pp{OP=op}
        stacks:push({op=op, b=stacks:pop(err_info), a=stacks:pop(err_info)})
        input:tok_next()
    end

    -- pp{toks}
    if trace then pp{idx, toks} end

    while input:has_more_tokens() do
        tok = input:tok()
        if trace then pp{tok} end
        -- pp({'dbg',tok, idx, debug.getinfo(2).currentline})

        pp(output)
        if output:envget(tok) ~= nil then
            local expr = output:envget(tok)
            pp{EXPR=expr}
            if expr.var then
                stacks:push(expr)
                input:tok_next()
            elseif expr.fn then
                pp{"IPAIRS?", expr}
                local call = {call={barelit=expr.actual}, args={}, rets={}}
                if expr.needs_it then
                    table.insert(call.args, stacks:peek_it(tok))
                    table.remove(call.args, 1)
                end
                -- pp({"INPUTS", expr.inputs})
                for a in iter.each(expr.inputs) do
                    table.insert(call.args, stacks:pop())
                end
                iter.reverse(call.args)
                for _ in iter.each(expr.outputs) do
                    table.insert(call.rets, nextvar())
                end
                output:compile(call)
                for r in iter.each(call.rets) do
                    stacks:push(Var(r))
                end
                input:tok_next()
            else
                pp({expr, tok})
                error("Unsupported def!")
            end
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
            local itvar = Var(nextvar())
            output:compile({assign=itvar.var,new=true,value=stacks:pop()})
            stacks:push_it(itvar)
            input:tok_next()
        elseif tok == "]" then
            stacks:push(stacks:pop_it())
            input:tok_next()
        elseif tok == "]." then
            stacks:pop_it()
            input:tok_next()
        elseif tok == "it" then
            -- if stacks.it_stack:empty() then
               -- output:mark_needs_it()
                --stacks:push_it(Var("it"))
                -- output:compile({it=true})
            -- end
            stacks:push(stacks:peek_it())
            input:tok_next()
        elseif tok:find("^%.") then
            local prop 
            _, _, prop = tok:find("^%.(.+)")
            stacks:push({prop_get=prop,value=stacks:pop()})
            input:tok_next()
        elseif tok:find("[^>]+>>$") then
            local name
            _,_, name = tok:find("([^>]+)>>")
            -- if stacks.it_stack:empty() then
              --  output:mark_needs_it()
               -- stacks:push_it(Var("it"))
            -- end
            stacks:push({prop_get=name,value=stacks:peek_it()})
            input:tok_next()
        elseif tok:find("^>>.+") then
            local name
            _,_, name = tok:find("^>>(.+)")
            -- if stacks.it_stack:empty() then
              --  output:mark_needs_it()
               -- stacks:push_it(Var("it"))
            -- end
            output:compile({prop_set=name,on=stacks:peek_it(),to=stacks:pop()})
            input:tok_next()
        elseif tok:find("^>.+") then
            _,_, name = tok:find("^>(.+)")
            output:compile({
                prop_set=name,
                on=stacks:pop(),
                to=stacks:pop()})
            input:tok_next()
        elseif tok == "dup" then
            -- local var = nextvar()
            -- output:compile({assign=var,new=true,value=stacks:peek()})
            local to_dup = stacks:pop()
            stacks:push(to_dup)
            stacks:push(to_dup)
            input:tok_next()
        elseif tok == "nip" then
            local keep = stacks:pop()
            stacks:pop()
            stacks:push(keep)
            input:tok_next()
        elseif tok == "swap" then
            local b, a = stacks:pop(), stacks:pop()
            stacks:push(b)
            stacks:push(a)
            input:tok_next()
        elseif tok == "drop" then
            stacks:pop()
            input:tok_next()
        elseif tok:find("^@.+") then
            local name
            _,_, name = tok:find("^@(.+)")
            local val = Var(name)
            stacks:push(val)
            input:tok_next()
        elseif tonumber(tok) then
            local var = nextvar()
            output:compile({assign=var,new=true,value={barelit=tonumber(tok)}})
            stacks:push(Var(var))
            input:tok_next()
        elseif tok:find('^"') then
            local var = Var(nextvar())
            output:compile({assign=var.var,new=true,{strlit=tok}})
            stacks:push(Var(var))
            input:tok_next()
        elseif tok:find("[^(]+%(%)") then -- print(), aka no-args call
            local _,_, name = tok:find("^([^(]+)%(%)$")
            output:compile({call={barelit=name},rets={},args={}})
            input:tok_next()
        elseif tok:find("%(#?[*\\]+%)$") then
            local _, _, name, effect = tok:find("([^(]+)%((#?[*\\]+)%)$")

            local call = {call={},args={},rets={}}
            if name:find("^%.") then
                call.call = {prop_get=name:sub(2),value=stacks:pop()}
            else
                call.call = {barelit=name}
            end
            if effect:find("^#") then
                table.insert(call.args, stacks:peek_it(tok))
                effect = effect:sub(2)
            end

            if effect:find("^%*+$") then
                local args = {}
                for i=1,#effect do
                    table.insert(args, stacks:pop())
                end
                for a in iter.backwards(args) do
                    table.insert(call.args, a)
                end
                pp{ARGS=call}
                output:compile(call)
            elseif effect:find("^%*+\\%*+$") then
                local _,_,args,rets = effect:find("(%*+)\\(%*+)")
                local targs = {}
                for i=1,#args do
                    table.insert(targs, stacks:pop())
                end
                iter.into(call.args):collect(iter.backwards(targs))

                for i=1,#rets do
                    table.insert(call.rets,nextvar())
                end
                output:compile(call)
                for r in each(call.rets) do
                    stacks:push(Var(r))
                end
            else
                error("Could not parse ffi call "..tok)
            end
            input:tok_next()
        elseif tok == "table" then
            local new = nextvar()
            output:compile({assign=new,new=true,value={barelit="{}"}})
            stacks:push(Var(new))
            input:tok_next()
        elseif tok == "{" then
            local scan = input:scan_ahead_by(1)
            local assigns = {}
                
            for stok in scan:upto("}") do
                table.insert(assigns, stok)
            end
            reverse(assigns)
            for _,var in ipairs(assigns) do
                if not output:envget(var) then
                    output:def(var, Var(var))
                    output:compile({assign=var,new=true,value=stacks:pop()})
                else
                    output:compile({assign=var,value=stacks:pop()})
                end
            end
            input:goto_scan(scan)
        elseif tok == ":" then
            local fn = {}
            fn.fn =  input:tok_at(input.token_idx + 1)
            fn.actual = mangle_name(fn.fn)
            output:pushenv()
            local scan 
            if fn.fn == "{" or fn.fn == "(" then
                fn.fn = AnonFnName
                scan = input:scan_ahead_by(1) 
            else
                scan = input:scan_ahead_by(2)
            end
            pp{scan}
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
                    table.insert(fn.inputs, Var(stok))
                    output:def(stok, param)
                else
                    local param = Var("p"..(#fn.inputs + 1))
                    table.insert(fn.inputs, param)
                    fn_stacks:push(param)
                end
            end

            fn.outputs = {}
            local end_tok
            if params_to_locals then end_tok = "}" else end_tok = ")" end

            iter.into(fn.outputs):collect(scan:upto(end_tok))
            fn.body_toks = iter.collect(scan:upto(balanced(':', ';')))
            fn_stacks:push_def_info(fn.fn)
            pp{"BODYFN",fn}
            local body_comp = compile(CompilerInput(fn.body_toks), output:derived(), fn_stacks)

            fn_stacks:pop_def_info()
            fn.body = body_comp.code

            if not fn_stacks:matches_effect(#fn.inputs, #fn.outputs) then
                pp({fn=fn,expected=fn.outputs, actual= fn_stacks })
                error("Stack effect mismatch in "..tostring(fn.fn).."!")
            end

            if fn.needs_it then
                table.insert(fn.inputs, 1, Var("it"))
            end

            local ret = {ret=Buffer()}
            ret.ret:collect(fn_stacks.stack:each())
            fn.body:push(ret)
            if fn.fn ~= AnonFnName then
                output:compile(fn)
                output:def(fn.fn, fn)
            else
                stacks:push(fn)
            end

            input:goto_scan(scan)
            output:popenv()
        elseif tok == "if" then
            local cond = {_if=stacks:pop()}
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

                local barrier = s_true.stack:barrier()
                local arm_true = compile(CompilerInput(arms[1]), output:derived(), s_true)
                local arm_false = compile(CompilerInput(arms[2]), output:derived(), s_false)

                if not s_true:matches_effect(s_false:infer_effect()) then
                    pp({
                        s_true, s_false
                    })
                    error("Sides of if/else/then clause do not have the same stack effect!")
                end

                -- Declare the destination variables for the if/else branches
                for a in iter.each(barrier.assigns) do output:compile(a) end
                local _,outs = s_true:infer_effect()

                for o=1,outs do
                    local v = table.remove(barrier.vars)
                    arm_true:compile(Assign(var.var, s_true:pop()))
                    arm_false:compile(Assign(var.var, s_false:pop()))
                    stacks:push(v)
                end

                cond.when_true = arm_true.code
                cond.when_false = arm_false.code
                output:compile(cond)
            else
                local barrier = stacks.stack:barrier()
                stacks.stack:reset_effect()
                local if_body = compile(CompilerInput(body), output:derived(), stacks)
                if not stacks.stack:is_effect_balanced() then
                    pp({body, cond, code, tok})
                    error("Unbalanced if stack effect!")
                end
                local _,outs = stacks.stack:infer_effect()

                for a in each(barrier.assigns) do output:compile(a) end

                local outvars = Buffer()
                for o=1,outs do
                    local v = table.remove(barrier.vars)
                    if_body:compile(Assign(var.var, stacks:pop()))
                    outvars:push(v)
                end
                for d in outvars:each() do
                    stacks:push(d)
                end
                cond.when_true = if_body.code
                output:compile(cond)
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
            input:goto_scan(scan)
            local before_iter_expr = stacks:copy("Before Iter Expr")
            local iter_input = CompilerInput(iterator_expr)
            pp(iterator_expr)
            stacks.stack:reset_effect()
            local iter_body = compile(CompilerInput(iterator_expr.items), output:derived(), stacks)
            local _,iter_outputs = stacks.stack:infer_effect()
            output:compile_iter(iter_body.code:each())
            if iter_outputs > 3 then
                error(
                "Too many outputs in iterator expresion for loop in "
                ..stacks:current_def_name())
            end
            function spop() return stacks:pop() end
         -- : spop \* stacks :pop(\*) ;

            local loop_def = {for_iter=reverse(iter_outputs:map_to_t(spop)), var_expr={}, body={}}
            if not body_arg_effect:find("^[*_]+$") then
                error("Invalid for body arg notation: "
                ..body_arg_effect.." in "..stacks:current_def_name())
            end
            local barrier = stacks.stack:barrier()
            stacks.stack:reset_effect()
            for c in body_arg_effect:gmatch("([_*])") do
                if c == "_" then
                    table.insert(loop_def.var_expr, Var("_"))
                elseif c == "*" then
                    local v = Var(nextvar())
                    table.insert(loop_def.var_expr, v)
                    stacks:push(v)
                end
            end

            local main_loop_body = compile(CompilerInput(loop_body), output:derived(), stacks)
            if not stacks.stack:is_effect_balanced() then
                pp{
                    now=stacks,
                    before=before_loop_body_stack
                }
                error("Unbalanced loop body stack effect!")
            end
            local _,outs = stacks.stack:infer_effect()
            -- TODO Get stack effect outputs emitted
            -- TODO-CRTICAL: Figure out how to work with 
            -- nested stack effect trackings
            -- so that reset_effect doesn't ruin them.

            for d in before_loop_body_stack.stack:each() do
                main_loop_body:compile({assign=d.var,value=stacks:pop{}})
            end

            for d in before_loop_body_stack.stack:each() do
                stacks:push(d)
            end

            loop_def.body = main_loop_body.code
            output:compile(loop_def)

        else
            pp{tok, output:envkeys()}

            error("Unexpected token: " .. tok)
        end 
        
    end
    output:exit()
    return output
end

function emit(ast, output)
    if ast.order then
        for k in each(ast.order) do
            emit(ast[k], output)
        end
    elseif ast.for_iter then
        output:push("for ")
        for var in each(ast.var_expr) do
            output:push(var.var)
            output:push(", ")
        end
        output:pop() output:push(" in ")
        for var in each(ast.for_iter) do
            output:push(var.var)
            output:push(", ")
        end
        output:pop()
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
            for inp in each(ast.inputs) do
                output:push(inp.var)
                output:push(", ")
            end
            output:pop()
        end
        output:push(') ')
        for stmt in ast.body:each() do
            emit(stmt, output)
        end
        output:push(" end\n")
    elseif ast._if and ast.when_true and ast.when_false then
        output:push(" if ")
        emit(ast._if, output)
        output:push(" then ")
        for stmt in ast.when_true:each() do
            emit(stmt, output)
        end
        output:push(" else ")
        for stmt in ast.when_false:each() do
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
    elseif ast._if and ast.when_true then
        output:push("if ")
        emit(ast._if, output)
        output:push(" then ")
        for stmt in ast.when_true:each() do
            -- pp(stmt)
            emit(stmt, output)
        end
        output:push(" end ")
        
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
        for d in each(ast.decl) do
            output:push(d)
            output:push(",")
        end
        output:pop()
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
        output:pop()
    elseif ast.call then
        if #ast.rets > 0 then
            output:push("local ")
        end
        for r in each(ast.rets) do
            output:push(r)
            output:push(", ")
        end
        if #ast.rets > 0 then
            output:pop()
            output:push(" = ")
        end
        emit(ast.call, output)
        output:push("(")
        for a in each(ast.args) do
            emit(a, output)
            output:push(", ")
        end
        if #ast.args > 0 then
            output:pop()
        end
        output:push(") ")

    else
        pp({'unsupported', output, ast})
        error("Unsupported ast node!")
    end
end

function to_lua(ast)
    -- pp{"TOLUA",ast}
    local output = Buffer()
    -- pp(ast)
    emit(ast, output)
    -- pp(output)
    local towrite = output:str():gsub("[ \t]+", " ")
    --[[ local chk, err=load(towrite)
    if err then error(err) 
    else
        chk()
    end
    ]]


    io.write(towrite)
end

function rootEnv()
    local ret = Env()
    ret:def("ipairs", Fn("ipairs", nil, {Var("t")}, {Var("f"), Var("s"), Var("v")} ))
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
            print(table.concat(toks, " "))
            -- print(str) print()
            -- to_lua(output.env)
            -- pp(ast)
            for n in ast:each() do
                to_lua(n)
            end

            local buf = Buffer()
            if stacks.stack:size() > 0 then
                buf:push(" return ")
                for n in stacks.stack:each() do
                    emit(n, buf)
                    buf:push(", ")
                end
                buf:pop()
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

