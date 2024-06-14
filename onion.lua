local pprint = require("pprint")
local whitespace = " \t\r\n"

pprint.setup {
    use_tostring = true
}

function pp(...)
    io.write("at: ".. debug.getinfo(2).currentline.." ")
    pprint(...)
end

function handle_escapes(s)
    return s:replace("\\n", "\n"):replace("\\t", "\t"):replace("\\r", "\r")
end

function tcopy(t)
    local ret = {}
    for k,v in pairs(t) do
        ret[k] = v
    end
    return ret
end

function reverse(t)
    table.sort(t, function(a,b) return a>b end)
    return t
end

function each(t)
    local i = 1
    return function()
        local ret = t[i]
        i = i + 1
        return ret
    end
end

function collect(iter)
    local ret = {}
    for el in iter do
        table.insert(ret, el)
    end
    return ret
end


function backwards(t)
    local ret = tcopy(t)
    reverse(ret)
    return ipairs(ret)
end

function t_has_v(t, v)
    for _, iv in ipairs(t) do
        if iv == v then return true end
    end
    return false
end

function parse_if_then_else(seq)
    local ret = {{}}
    local depth = 0
    for iv in each(seq) do
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


-- Assumes that `seeking` removes depth, and an unpaired `seeking` is the split point
function t_split_at_depth(t, seeking, adds_depth)
    local ret = {{}}
    local depth = 1
    for iv in each(t) do
        pp{iv, depth}
        if iv == seeking then depth = depth - 1 end
        if iv == adds_depth then depth = depth + 1 end
        if iv == seeking and depth == 0 then
            table.insert(ret, {})
        else
            table.insert(ret[#ret], iv)
        end
    end
    return ret
    
end

function t_split(t, v)
    local ret = {{}}
    for iv in each(t) do
        if iv == v then
            table.insert(ret, {})
        else
            table.insert(ret[#ret], iv)
        end
    end
    return ret
end


function scanner(t, idx)
    local scanner = {
        subject = t,
        idx = idx
    }
    if type(t) == "string" then
        scanner._fetch = function (s, idx) return s:sub(idx,idx) end 
    else
        scanner._fetch = function(t, idx) return t[idx] end
    end
    function scanner:go_next()
        self.idx = self.idx + 1
    end
    function scanner:at()
        return self._fetch(self.subject, self.idx)
    end
    function scanner:upto(target)
        local pred
        if type(target) == "function" then
            pred = target
        else
            pred = function(el) return el == target end
        end

        return function() 
            if not pred(self:at()) and self.idx <= #(self.subject) then
                local ret = self:at()
                self:go_next()
                return ret
            else
                if self.idx > #self.subject then
                    print(debug.getinfo(2).currentline)
                    error(pprint.pformat(target).." not found!")
                end
                self:go_next()
                return null
            end
        end
    end
    return scanner
end

function balanced(down, up)
    local depth = 1
    return function(el)
        if el == down then depth = depth + 1 end
        if el == up then depth = depth - 1 end
        return el == up and depth == 0
    end
end

function buffer()
    local me = {output={}}

    function me:pop(context)
        if self._underflow_handler and #self.output == 0 then
            self._underlow_handler(context)
        end
        return table.remove(self.output)
    end
    function me:collect(iter)
        for el in iter do
            self:push(el)
        end
        return self
    end

    function me:on_underflow(fn) self._underflow_hanlder = fn return self end
    function me:push(val) table.insert(self.output, val) return self end
    function me:peek() return self.output[#self.output] end
    function me:str() return table.concat(self.output, "") end
    function me:concat(sep) return table.concat(self.output, sep) end
    function me:each() return each(self.output) end
    function me:size() return #self.output end
    return me
end

function makestack(name)
    local me = buffer()
    me:on_underflow(function(context) pp(context) error(name.." stack underflow! See log for context.") end)
    function me:suffix_difference(other)
        -- me: a b c
        -- other: a e f
        -- returns e f
        --
        -- me: a
        -- other: a b c
        -- returns b c
        --
        --me: a b c
        --other: b
        --returns b
        --
        -- me: a b c
        -- other: a
        -- returns {}
        -- 
        local idx = #other.output + 1
        for i=1,math.max(#other.output,#self.output) do
            if other.output[i] ~= self.output[i] then
                idx = i
                break
            end
        end
        local ret = {}
        for i=idx,#other.output do
            table.insert(ret, other.output[i])
        end
        return ret

    end

    return me
end

function copy_stack(name, to_copy)
    local me = makestack(name)
    me.output = tcopy(to_copy.output)
    return me
end

    

function lex(input)
    local pos = 0
    local tokens = {}
    local tok, new_tok
    local newpos
    while pos < #input do
        if not input:find("%S+", pos) then break end
        _, _, new_tok, new_pos = input:find("(%S+)()", pos)
        pos = new_pos
        if new_tok:find("^\\") then 
            _, _, pos = input:find("[^\r\n]+[\r\n]+()", pos)
        elseif new_tok:find('^"') then
            local quote_scanning = true
            local scan_tok
            local scan_pos = pos
            while quote_scanning do
                if input:find('[^"]*"', scan_pos) then
                    _, _, scan_tok, new_scan_pos = input:find('([^"]*")()', scan_pos)
                    quote_scanning = scan_tok:find('\\"$') ~= nil
                    new_tok = new_tok .. scan_tok
                    scan_pos = new_scan_pos
                else
                    io.write("Seeking in ", input:sub(scan_pos))
                    error("Unclosed quote in input!")
                end
            end
            pos = scan_pos
            table.insert(tokens, new_tok)
        else
            table.insert(tokens, new_tok)
        end
    end
    return tokens
end


local parent = {}
local t_env = {}
setmetatable(parent, {
    __tostring = function(_) return "key-parent" end
})

local trace = false

function env_(of) return {[parent]=of, [t_env]=true, order={}} end

local ssa_idx = 1

local dept = 0
function compile(toks, defs, code, stack)
    dept = dept + 1
    print(string.rep(".", dept))
    function dbg()
        pp({
            toks=toks, 
            --defs, 
            --code, 
            stack=stack
        })
    end
    -- pp({stack=stack, "compile"})
    local env = env_(defs)
    print("called from: ".. debug.getinfo(2).currentline)
    pp({env=env, defs=defs})

    function get_(name)
        -- pp({name=name})
        local to_search = env
        while to_search ~= nil do
            if to_search[name] ~= nil then
                return to_search[name]
            else
                to_search = to_search[parent]
            end
        end
        return nil
    end

    local idx = 1
    function inc(amt)
        idx = idx + amt
    end
    local tok
    function nextvar()
        local ret = "__s"..ssa_idx
        ssa_idx = ssa_idx + 1
        return ret
    end

    function local_assigns(scan_idx)
        local scan = scanner(toks, scan_idx)
        local assigns = {}
            
        for stok in scan:upto("}") do
            table.insert(assigns, stok)
        end
        reverse(assigns)
        for _,var in ipairs(assigns) do
            env[var] = {var=var,ins=0,out=1}
            code:push({assign=var, to=stack:pop()})
        end
        idx = scan.idx
    end

    function op(op)
        local err_info = {op=op, tok, idx, code}
        stack:push({op=op, b=stack:pop(err_info), a=stack:pop(err_info)})
        inc(1)
    end

    if trace then pp{idx, toks} end
    while idx <= #toks do
        if trace then pp{tok, idx} end
        tok = toks[idx]
        -- pp({'dbg',tok, idx})

        if get_(tok) ~= nil then
            local expr = get_(tok)
            if expr.var then
                stack:push(expr)
                inc(1)
            elseif expr.fn then
                local call = {call=expr.fn, args={}, rets={}}
                for _, a in backwards(expr.inputs) do
                    table.insert(call.args, pop())
                end
                for _, r in ipairs(expr.outputs) do
                    table.insert(call.rets, nextvar())
                end
                table.insert(code, call)
                for _, r in ipairs(call.rets) do
                    stack:push({var=r})
                end
                inc(1)
            else
                pp({expr == parent, tok})
                error("Unsupported def!")
            end
        elseif tok == "+" then op("+")
        elseif tok == "-" then op("-")
        elseif tok == "*" then op("*")
        elseif tok == "div" then op("/")
        elseif tok == "and" then op("and")
        elseif tok == "or" then op("or")
        elseif tok == ">" then op(">")
        elseif tok == "<" then op("<")
        elseif tok == "eq?" then op("==")
        elseif tok == "<=" then op("<=")
        elseif tok == ">=" then op(">=")
        elseif tok == "neq?" then op("~=")
        elseif tok == "dup" then
            local var = nextvar()
            code:push({assign=var,new=true,value=stack:peek()})
            stack:push({var=var})
            inc(1)
        elseif tonumber(tok) then
            stack:push({barelit = tonumber(tok)})
            inc(1)
        elseif tok:find('^"') then
            stack:push({strlit=tok})
            inc(1)
        elseif tok == "{" then
            local_assigns(idx + 1)
        elseif tok == ":" then
            local fn = {}
            fn.fn = toks[idx + 1]
            local fenv = env_(env)
            local scan = scanner(toks, idx + 2)
            local stok = scan:at()
            assert(stok == "(" or stok == "{", "Stack effect comment required!")
            scan:go_next()
            local params_to_locals = stok == "{"
            fn.inputs = {}
            local expr_stack = makestack("Expr stack for "..fn.fn.." definition")
            local body_ast = buffer()
            for stok in scan:upto("--") do
                if stok == "}" or stok == ")" then
                    error("Missing -- in stack effect definition for " .. name .. "!")
                end
                if params_to_locals then
                    local param = {var=stok}
                    table.insert(fn.inputs, {var=stok})
                    fenv[stok] = param
                else
                    local param = {var="p"..(#fn.inputs + 1)}
                    table.insert(fn.inputs, param)
                    expr_stack:push(param)
                end
            end

            fn.outputs = {}
            local end_tok
            if params_to_locals then end_tok = "}" else end_tok = ")" end
            for stok in scan:upto(end_tok) do
                table.insert(fn.outputs, stok)
            end
            fn.body_toks = {}
            for stok in scan:upto(balanced(':', ';')) do
                -- if stok == ':' then error("Cannot nest definitions (yet)!") end
                table.insert(fn.body_toks, stok)
            end
            -- pp("before body compile")
            -- pp({fn=fn, expr_stack=expr_stack, fenv=fenv})
            
            pp{XERDS=fn, fenv=fenv, env=env}
            fn.body = compile(fn.body_toks, fenv, body_ast, expr_stack)
            if expr_stack:size() ~= #fn.outputs then
                pp({ expected=fn.outputs, actual= expr_stack })
                error("Stack effect mismatch!")
            end
            local ret = {ret=expr_stack}
            for val in expr_stack:each() do
                table.insert(ret,val) 
            end
            fn.body:push(ret)
            -- pp("after body compile")
            -- pp({fn=fn})
            env[parent][fn.fn] = fn
            table.insert(env[parent].order, fn.fn)
            idx = scan.idx
        elseif tok == "if" then
            local cond = {_if=stack:pop()}
            local scan = scanner(toks, idx + 1)
            pp{"KIPO", toks}
            local body = buffer():collect(scan:upto(balanced("if", "then"))).output

            if t_has_v(body, "else") then
                local arms = parse_if_then_else(body)
                pp(arms)
                if #arms ~= 2 then
                    error("cannot have more than one 'else' in an if body")
                end
                local s_true = copy_stack("If True Expression", stack)
                local s_false = copy_stack("If False Expression", stack)

                local body_true = buffer()

                local arm_true = compile(arms[1], env, body_true, s_true)
                local body_false = buffer()
                local arm_false = compile(arms[2], env, body_false, s_false)

                local diff_true = stack:suffix_difference(s_true)
                local diff_false = stack:suffix_difference(s_false)

                if s_true:size() ~= s_false:size() or #diff_true ~= #diff_false then
                    pp({
                        body=body,arms=arms,t=s_true,f=s_false,
                        dt=diff_true,df=diff_false,
                        bt=body_true,bf=body_false,
                        
                    })
                    error("Sides of if/else/then clause do not have the same stack effect!")
                end

                local decl = {decl={}}
                for _ in each(diff_true) do
                    table.insert(decl.decl, nextvar())
                end
                -- Declare the destination variables for the if/else branches
                pp(code)
                code:push(decl)

                for d in each(decl.decl) do
                    local err_ctx = {tok, code, trying_to_assign=d}
                    arm_true:push({assign=d, value=s_true:pop(err_ctx)})
                    arm_false:push({assign=d, value=s_false:pop(err_ctx)})
                    stack:push({var=d})
                end
                cond.when_true = arm_true
                cond.when_false = arm_false
                code:push(cond)
            else
                local stack_depth = stack:size()
                local before_if_stack = copy_stack("Before If Expression Stack", stack)
                local if_body = compile(body, env, buffer(), stack)
                if stack:size() ~= stack_depth then
                    pp({body, cond, code, tok})
                    error("Unbalanced if stack effect!")
                end
                local diffs = before_if_stack:suffix_difference(stack)
                local decl = {decl={}}
                for v in each(diffs) do
                    table.insert(decl.decl, nextvar())
                end
                -- code:push(decl)
                for d in each(decl.decl) do
                    code:push({assign=d,new=true,value=before_if_stack:pop()})
                    if_body:push({assign=d,value=stack:pop()})
                end
                for d in each(decl.decl) do
                    stack:push({var=d})
                end
                -- pp({der=if_body})
                cond.when_true = if_body
                code:push(cond)
            end
            idx = scan.idx
        else
            pp{tok, env}
            error("Unexpected token: " .. tok)
        end 
        
    end
    dept = dept - 1 
    return code
end

function emit(ast, output)
    if ast[t_env] then
        for k in each(ast.order) do
            emit(ast[k], output)
        end
    elseif ast.fn then
        output:push('function ')
        output:push(ast.fn)
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
        output:push("if ")
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
    else
        pp({'unsupported', output, ast})
        error("Unsupported ast node!")
    end
end

function to_lua(ast)
    local output = buffer()
    -- pp(ast)
    emit(ast, output)
    local towrite = output:str():gsub("[ \t]+", " ")
    io.write(towrite)
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
            print()
            print()
            local f = io.open(arg[argIdx + 1], "r")
            local str = f:read("*a")
            local toks = lex(str)
            local env = env_()
            local ast = compile(toks, env, buffer(), makestack("Expression"))
            print(str)
            print()
            to_lua(env)

            argIdx = argIdx + 2
            print()
            print()
        else
            error("Unrecognized arg: " .. arg[argIdx])
        end
    end
end

main()

