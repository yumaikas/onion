local pprint = require("pprint")
local whitespace = " \t\r\n"

pprint.setup {
    use_tostring = true
}

function pp(...)
    io.write("at: ".. debug.getinfo(2).currentline.." ")
    pprint(...)
end

function mangle_name(n)
    n = n:gsub("[#/\\-]", {
        ['#'] = "_hash_",
        ['/'] = "_slash_",
        ['\\'] = '_backslash_',
        ['-'] = '_',
    })
    if n:find("^[^_a-zA-Z]") then
        n = "__" .. n
    end
    return n
end

function handle_escapes(s)
    return s:gsub("\\([tnr])", {t="\t",n="\n",r="\r"})
end

function tcopy(t)
    local ret = {}
    for k,v in pairs(t) do
        ret[k] = v
    end
    return ret
end

function select_keys(t, ...)
    local ret = {}
    for _,k in ipairs{...} do
        ret[k] = t[k]
    end
    return ret
end

function reverse(tab)
    for i = 1, #tab//2, 1 do
        tab[i], tab[#tab-i+1] = tab[#tab-i+1], tab[i]
    end
    return tab
end

function each(t)
    local i = 1
    return function()
        local ret = t[i]
        i = i + 1
        return ret
    end
end

function as_class(cls) 
    local mt = {__index = cls}
    return function(obj) 
        setmetatable(obj, mt)
        return obj 
    end 
end


--[[
It stack words
- it
- >>set
- get>>
- [ aka push_it
- ] aka pop_it
- ]. aka drop_it
]]

function into(t)
    local obj = {}
    function obj:collect(iter)
        for el in iter do
            table.insert(t, el)
        end
    end
    return obj
end

function collect(iter)
    local ret = {}
    for el in iter do
        table.insert(ret, el)
    end
    return ret
end


function collect_into(t, iter)
    for el in iter do
        table.insert(t, el)
    end
    return t
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

function parse_do_loop(seq)
    local ret = {}
    for iv in each(seq) do
    end
    error("do loops not implemented!")
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

as_buffer = (function (me) 
    local me = {}

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
    function me:empty() return self:size() == 0 end

    return as_class(me)
end)({})



function buffer() return as_buffer({output={}}) end

function makestack(name)
    local me = buffer()
    me:on_underflow(function(context) pp(context) error(name.." stack underflow! See log for context.") end)
    function me:copy(name)
        local cp = makestack(name)
        cp.output = tcopy(self.output)
        return cp
    end
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
        local ret = buffer()
        for i=idx,#other.output do
            ret:push(other.output[i])
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
local anon_fn = {}
setmetatable(parent, {
    __tostring = function(_) return "key-parent" end
})
setmetatable(anon_fn, {
    __tostring = function(_) return "anon-fn" end
})


local trace = false

function env_(of) return {[parent]=of, [t_env]=true, order={}} end

local ssa_idx = 1

function build_mt(mt, fns)
    for k, v in pairs(fns) do
        mt[k] = v
    end
end

function makeenv(curenv)
    local me = {order={}}
    me[parent] = curenv
    return me
end


local as_expr_state = (function (me) 
    function me:push(val) self.stack:push(val) end
    function me:peek() return self.stack:peek() end
    function me:pop(ctx) return self.stack:pop(ctx) end
    function me:has_size(size) return self.stack:size() == size end

    function me:push_def_info(name)
        self.def_info:push(name)
    end
    function me:pop_def_info(name) 
        self.def_info:pop(name)
    end

    function me:push_it(val) self.it_stack:push(val) end
    function me:peek_it()
        if self.it_stack:size() <= 0 then
            error("It Stack Underflow in "..self.def_info:peek().."!")
        end
        return self.it_stack:peek() 
    end
    function me:pop_it(ctx) return self.it_stack:pop(ctx) end
    function me:has_size_it(size) return self.stack:size() == size end

    local derp = as_class(me)
    function me:copy() 
        return derp({
            stack = self.stack:copy(),
            it_stack = self.it_stack:copy(),
            def_info = self.def_info:copy(),
        })
    end


    return as_class(me)
end)({})


function expr_state(name, it_name)
    return as_expr_state{
        stack = makestack(name), 
        it_stack = makestack(it_name),
        def_info = makestack("toplevel")
    }
end

local as_comp_input = (function (me) 
    function me:goto_scan(scan) self.tok_idx = scan.idx end
    function me:set_tok_idx(to) self.tok_idx = to end
    function me:tok_next() 
        self.tok_idx = self.tok_idx + 1 
        -- pp(self.toks[self.tok_idx])
    end
    function me:tok() return self.toks[self.tok_idx] end
    function me:tok_at(idx) return self.toks[idx] end
    function me:has_more_toks() return self.tok_idx <= #self.toks end
    function me:scan_ahead_by(ahead_by)
        return scanner(self.toks, self.tok_idx + ahead_by)
    end
    return as_class(me)
end)({})

function comp_input(toks)
    return as_comp_input({ toks = toks, tok_idx = 1 })
end

local as_comp_output = (function(me)
    function me:enter_comp() 
        self.def_depth = self.def_depth + 1 
    end
    function me:exit_comp() 
        self.def_depth = self.def_depth - 1
    end


    function me:compile(ast) 
        self.code:push(ast) 
    end

    function me:pushenv() self.env = makeenv(self.env) end
    function me:popenv() self.env = self.env[parent] end
    function me:def(name, val)
        self.env[name] = val
    end
    function me:defn(name, ast)
        self.env[parent][name] = ast
        table.insert(self.env[parent].order, name)
    end
    function me:mark_needs_it()
        self.needs_it = true
    end
    function me:is_toplevel()
        return self.def_depth == 0
    end
    function me:envkeys()
        local ret = {}
        local to_search = self.env
        while to_search ~= nil do
            for k,_ in pairs(ret) do
                table.insert(ret, k)
            end
            to_search = to_search[parent]
        end
        return ret
    end
    function me:envget(key) 
        local to_search = self.env
        while to_search ~= nil do
            if to_search[key] ~= nil then
                return to_search[key]
            else
                to_search = to_search[parent]
            end
        end
        return nil
    end

    return as_class(me)
end)({})

function comp_output(opts)
    return as_comp_output({
        def_depth = opts.def_depth or -1,
        env = opts.env or makeenv(),
        code = opts.code or buffer(),
    })
end


function compile(input, output, stacks)
    -- pp{"COMPILE", output.def_depth}
    output:enter_comp()
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

    pp{toks}
    if trace then pp{idx, toks} end

    while input:has_more_toks() do
        tok = input:tok()
        if trace then pp{tok} end
        -- pp({'dbg',tok, idx, debug.getinfo(2).currentline})

        if output:envget(tok) ~= nil then
            local expr = output:envget(tok)
            -- pp{EXPR=expr}
            if expr.var then
                stacks:push(expr)
                input:tok_next()
            elseif expr.fn then
                local call = {call={barelit=expr.actual}, args={}, rets={}}
                if expr.needs_it then
                    table.insert(call.args, stacks:peek_it(tok))
                    table.remove(call.args, 1)
                end
                -- pp({"INPUTS", expr.inputs})
                for _, a in ipairs(expr.inputs) do
                    table.insert(call.args, stacks:pop())
                end
                reverse(call.args)
                for _ in each(expr.outputs) do
                    table.insert(call.rets, nextvar())
                end
                output:compile(call)
                for _, r in ipairs(call.rets) do
                    stacks:push({var=r})
                end
                input:tok_next()
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
        elseif tok == "[" then
            local itvar ={var= nextvar()}
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
                --stacks:push_it({var="it"})
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
               -- stacks:push_it({var="it"})
            -- end
            stacks:push({prop_get=name,value=stacks:peek_it()})
            input:tok_next()
        elseif tok:find("^>>.+") then
            local name
            _,_, name = tok:find("^>>(.+)")
            -- if stacks.it_stack:empty() then
              --  output:mark_needs_it()
               -- stacks:push_it({var="it"})
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
            local var = nextvar()
            output:compile({assign=var,new=true,value=stacks:peek()})
            stacks:push({var=var})
            input:tok_next()
        elseif tok == "swap" then
            local b, a = stacks:pop(), stacks:pop()
            stacks:push(b)
            stacks:push(a)
            input:tok_next()
        elseif tok:find("^@.+") then
            local name
            _,_, name = tok:find("^@(.+)")
            local val = {var=name}
            stacks:push(val)
            input:tok_next()
        elseif tonumber(tok) then
            stacks:push({barelit = tonumber(tok)})
            input:tok_next()
        elseif tok:find('^"') then
            stacks:push({strlit=tok})
            input:tok_next()
        elseif tok:find("[^(]+%(%)") then
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
                for _, a in backwards(args) do
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
                for _, a in backwards(targs) do
                    table.insert(call.args, a)
                end

                for i=1,#rets do
                    table.insert(call.rets,nextvar())
                end
                output:compile(call)
                for r in each(call.rets) do
                    stacks:push({var=r})
                end
            else
                error("Could not parse ffi call "..tok)
            end
            input:tok_next()
        elseif tok == "table" then
            local new = nextvar()
            output:compile({assign=new,new=true,value={barelit="{}"}})
            stacks:push({var=new})
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
                    output:def(var, {var=var})
                    output:compile({assign=var,new=true,value=stacks:pop()})
                else
                    output:compile({assign=var,value=stacks:pop()})
                end
            end
            input:goto_scan(scan)
        elseif tok == ":" then
            local fn = {}
            fn.fn =  input:tok_at(input.tok_idx + 1)
            fn.actual = mangle_name(fn.fn)
            output:pushenv()
            local scan 
            if fn.fn == "{" or fn.fn == "(" then
                fn.fn = anon_fn
                scan = input:scan_ahead_by(1) 
            else
                scan = input:scan_ahead_by(2)
            end
            local stok = scan:at()

            assert(stok == "(" or stok == "{", "Stack effect comment required!")
            scan:go_next()
            local params_to_locals = stok == "{"
            fn.inputs = {}

            -- local expr_stack = makestack("Expr stack for "..tostring(fn.fn).." definition")
            local fn_stacks = expr_state(
                "Expr stack for "..tostring(fn.fn).." def",
                "It stack for "..tostring(fn.fn).." def"
            )

            local body_ast = buffer()
            for stok in scan:upto("--") do
                pp{stok}
                if stok == "}" or stok == ")" then
                    error("Missing -- in stack effect definition for " .. fn.fn .. "!")
                end
                if stok == "#"  then
                    fn.needs_it = true
                    fn_stacks:push_it({var="it"})
                elseif params_to_locals then
                    local param = {var=stok}
                    table.insert(fn.inputs, {var=stok})
                    output:def(stok, param)
                else
                    local param = {var="p"..(#fn.inputs + 1)}
                    table.insert(fn.inputs, param)
                    fn_stacks:push(param)
                end
            end

            fn.outputs = {}
            local end_tok
            if params_to_locals then end_tok = "}" else end_tok = ")" end
            into(fn.outputs):collect(scan:upto(end_tok))
            fn.body_toks = collect(scan:upto(balanced(':', ';')))
            fn_output = comp_output(select_keys(output, "env", "def_depth"))
            fn_stacks:push_def_info(fn.fn)
            local body_comp = compile(comp_input(fn.body_toks), fn_output, fn_stacks)
            fn_stacks:pop_def_info()
            fn.body = body_comp.code
            if fn.needs_it then
                table.insert(fn.inputs, 1, {var="it"})
            end
            if not fn_stacks:has_size(#fn.outputs) then
                pp({fn=fn,expected=fn.outputs, actual= fn_stacks })
                error("Stack effect mismatch in "..tostring(fn.fn).."!")
            end
            local ret = {ret=buffer()}
            ret.ret:collect(fn_stacks.stack:each())
            fn.body:push(ret)
            if fn.fn ~= anon_fn then
                output:compile(fn)
                output:defn(fn.fn, fn)
            else
                stacks:push(fn)
            end

            input:goto_scan(scan)
            output:popenv()
        elseif tok == "if" then
            local cond = {_if=stacks:pop()}
            local scan = input:scan_ahead_by(1)
            local body = buffer():collect(scan:upto(balanced("if", "then"))).output

            if t_has_v(body, "else") then
                local arms = parse_if_then_else(body)
                if #arms ~= 2 then
                    pp(arms)
                    error("cannot have more than one 'else' in an if body")
                end
                local s_true = stacks:copy("If True")
                local s_false = stacks:copy("If False")

                local out_true = comp_output(select_keys(output, "env", "def_depth"))
                local arm_true = compile(comp_input(arms[1]), out_true, s_true)

                local out_false = comp_output(select_keys(output, "env", "def_depth"))
                local arm_false = compile(comp_input(arms[2]), out_false, s_false)

                local diff_true = stacks.stack:suffix_difference(s_true.stack)
                local diff_false = stacks.stack:suffix_difference(s_false.stack)

                if s_true.stack:size() ~= s_false.stack:size() 
                    or diff_true:size() ~= diff_false:size() then
                    pp({
                        body=body,arms=arms,t=s_true,f=s_false,
                        dt=diff_true,df=diff_false,
                        bt=body_true,bf=body_false,
                    })
                    error("Sides of if/else/then clause do not have the same stack effect!")
                end

                local decl = {decl={}}
                pp{"DIFF_TRUE", diff_true}
                for _ in diff_true:each() do
                    table.insert(decl.decl, nextvar())
                end
                -- Declare the destination variables for the if/else branches
                output:compile(decl)

                for d in each(decl.decl) do
                    local err_ctx = {tok, code, trying_to_assign=d}
                    arm_true:compile({assign=d, value=s_true:pop(err_ctx)})
                    arm_false:compile({assign=d, value=s_false:pop(err_ctx)})
                    stacks:push({var=d})
                end
                cond.when_true = arm_true.code
                cond.when_false = arm_false.code
                output:compile(cond)
            else
                local stack_depth = stacks.stack:size()
                local before_if_stack = stacks:copy()
                local out_if = comp_output(select_keys(output, "env", "def_depth"))

                local if_body = compile(comp_input(body), out_if, stacks)
                if stacks.stack:size() ~= stack_depth then
                    pp({body, cond, code, tok})
                    error("Unbalanced if stack effect!")
                end
                pp{before_if_stack}
                local diffs = before_if_stack.stack:suffix_difference(stacks.stack)
                local decl = {decl={}}
                for v in diffs:each() do
                    table.insert(decl.decl, nextvar())
                end
                -- code:push(decl)
                for d in each(decl.decl) do
                    output:compile({assign=d,new=true,value=before_if_stack:pop()})
                    if_body:compile({assign=d,value=stacks:pop()})
                end
                for d in each(decl.decl) do
                    stacks:push({var=d})
                end
                -- pp({der=if_body})
                cond.when_true = if_body.code
                output:compile(cond)
            end
            input:goto_scan(scan)
        elseif tok == "do" then
            error("Do loops not implemented")
        elseif tok == "for" then
            error("For loops not implemented")
        else
            pp{tok, output:envkeys()}

            error("Unexpected token: " .. tok)
        end 
        
    end
    -- pp{'COMP-DONE', output}
    output:exit_comp()
    return output
end

function emit(ast, output)
    if ast.order then
        for k in each(ast.order) do
            emit(ast[k], output)
        end
    elseif ast.fn then
        output:push('function ')
        if ast.fn ~= anon_fn then
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
    local output = buffer()
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
            local output = comp_output({env=makeenv()})
            local input = comp_input(toks)
            local stacks = expr_state("", "")
            local ast = compile(input, output, stacks).code
            --pprint(output.def_depth)
            print(str) print()
            -- to_lua(output.env)
            -- pp(ast)
            for n in ast:each() do
                to_lua(n)
            end

            local buf = buffer()
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

