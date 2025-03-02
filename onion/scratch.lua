package.path = "./onion/?.lua;"..package.path
-- lex (str) -> tokens
-- parse(tokens) -> ast
---- chunk(tokens, until) -> toks, new_toks
-- resolve_names(ast) -> ast + env
-- effects(ast) -> ast+(blocks & exprs) ! underflows (?)
-- stitch(ast+(blocks & exprs))
-- ssa allocate (ast + (blocks & exprs))
local trace = require("trace")

local Lex = require("lexer")
local Env = require("resolve")
local BaseEnv = require("basenv")
local LuaOutput = require("lunar")
local JsOutput = require("spider")
local atoms = require("atoms")
local seam = require("seam")
local claw = require("claw") 
local molecules = require("molecules")
local iter = require("iter")
local f = iter.f
require("check_stack")
require("stitch")
local tests = require("tests")
local onion = {}

local function matcher(of)
    function any_of(options)
        for i, v in ipairs(options) do
            options[i] = matcher(v)
        end

        return function(el)
            for _, pred in ipairs(options) do
                if pred(el) then
                    return true
                end
            end
            return false
        end
    end
	if type(of) == "function" then
        return of
    elseif of == Lex.EOF then
        return function(el) return el == Lex.EOF end
    elseif type(of) == "table" then
        return any_of(of)
	else
	    return function(el) return el == of end
	end
end

local cond = f'(bool, a, b) if bool then -> a else -> b ;'

function chunk(t, end_match, end_name)
    local end_pred = matcher(end_match)
    local ret = {}
    while t:tok() do
        if t:can(end_pred) then
            return ret, t:tok()
        else
            iter.push(ret, t:tok())
            t:next()
        end
    end
    error("In "..trace:peek().." expected "..end_name.." before end of tokens!")
end

local call_eff = {}
function call_eff.is(word) return word:find("([^(]+)%(%**\\?%**%)$") ~= nil end
function call_eff.parse(word) 
    local _,_, called, ins, outs = word:find("([^(]+)%((%**)\\?(%**)%)$")

    trace("CALL_EFF_PARSE", word, word:find("([^(]+)%((%**)\\?(%**)%)$"))

    if ins then
        return called, #ins, #(outs or {})
    else
        return nil
    end
end

local short_eff = {}
function short_eff.is(word) return word:find("^%(#?%**\\?%**%)$") ~= nil end
function short_eff.parse(word) 
    local _,_,ins, outs = word:find("^%((#?%**)\\?(%**)%)$")
    if ins then
        return ins, outs
    else
        return nil, "unable to parse short-effect: "..word
    end
end

local iter_eff = {}
function iter_eff.is(word) 
    -- trace:enable()
    trace(word==Lex.EOF)
    --trace:pp(word)
    -- trace.disable()
    return (not not string.find(word, "[^[]*%[#?%**\\[*_]*%]$")) end

function iter_eff.parse(word)
    if not iter_eff.is(word) then
        error ("invalid iter effect: "..word)
    end
    local patt = "([^[]*)%[(#?%**)\\([*_]*)%]$"
    local _, _, word, inputs, loop_vars = word:find(patt)
    return word, iter.chars(inputs), iter.chars(loop_vars)
end

local parse =  {}

function parse.cond_body(t)
    local clauses = claw.body() 

    while t:tok() do
        local ws
        if t:matches("[\r\n]") then
            ws = claw.whitespace(t:tok())
            t:next()
        end
        local pred_body = parse.of_chunk(t, "->", "cond pred clause") t:next()
        local when_true_body = parse.of_chunk(t, "of", "cond body clause") t:next()
        local clause = claw.cond_clause(pred_body, when_true_body)
        if ws then clause.pre = ws end
        clauses:compile(clause)
        if t:matches("[\r\n]") then
            clause.post = claw.whitespace(t:tok())
            t:next()
        end
        if t:is("end") then
            t:next()
            return claw.cond(clauses)
        end
    end
    error("Expected an 'end' token")
end

function parse.of_chunk(t, end_, end_name)
    trace("Parsing for "..(end_name or 'nil'))
    local is_end = matcher(end_)
    local body = claw.body()
    while t:tok() and not (t:tok() == Lex.EOF and end_ ~= Lex.EOF)  do
        if is_end(t:tok()) then
            return body, t:tok()
        end

        if t:is("if") then
            t:next()
            local t_body, tail = parse.of_chunk(t, {"else", "then"}, "else/then in "..trace:peek())
            if tail == "else" then
                t:next()
                f_body = parse.of_chunk(t, "then", "then")
                body:compile(claw.ifelse(t_body, f_body))
            else
                body:compile(claw.if_(t_body))
            end
            t:next()
        elseif t:is("behaves") then
            t:next()
            local key = t:tok() t:next()
            local behavoior = t:tok() t:next()
            body:compile(molecules.behaves(key, behavoior))
        elseif t:is(":") or t:is("::") or t:is("async:") or t:is("async::") then
            local is_it_fn = t:is("::") or t:is("async::")
            local is_async = t:is("async:") or t:is("async::")
            t:next()
            local name = cond(t:any_of{"(", "{"} or t:can(short_eff.is), claw.anon_fn, t:tok())
            trace:push(tostring(name))
            if is_it_fn and name == claw.anon_fn then error("An :: function defintion cannot be anonymous") end
            if is_it_fn then name = claw.it_fn(name) end
            if name ~= claw.anon_fn then t:next() end
            local input_assigns = false
            local inputs, outputs = nil, nil
            assert(t:any_of{"(", "{"} or t:can(short_eff.is), "Word def should have stack effect")
            if t:is("(") then
                t:next()
                inputs = claw.namelist(chunk(t, "--", "stack effect split"))
                t:next()
                outputs = claw.namelist(chunk(t, ")", "end of stack effect"))
                t:next()
            elseif t:is("{") then
                input_assigns = true
                t:next()
                inputs = claw.namelist(chunk(t, "--", "var stack effect split"))
                t:next()
                outputs = claw.namelist(chunk(t, "}", "end of var stack effect"))
                t:next()
            elseif t:can(short_eff.is) then
                local i, o = assert(short_eff.parse(t:tok()))
                t:next()
                inputs = claw.namelist(iter.chars(i))
                outputs = claw.namelist(iter.chars(o))
            else
                error("Word def should have stack effect!")
            end
            fn_body = parse.of_chunk(t, ";", "end of "..tostring(name))
            local fn = claw.func(name, inputs, outputs, fn_body)
            fn.input_assigns = input_assigns
            fn.is_async = is_async
            body:compile(fn)
            t:next()
            trace:pop()
        elseif t:is("do") then
            t:next()
            local loop_body = parse.of_chunk(t, "loop", "do loop")
            t:next()
            body:compile(claw.do_loop(loop_body))
        elseif t:is("+do") then
            t:next()
            local loop_body = parse.of_chunk(t, "loop", "+do loop")
            t:next()
            body:compile(claw.do_step_loop(loop_body))
        elseif t:is("do?") then
            t:next()
            local loop_pred = parse.of_chunk(t, "while", "while")
            t:next()
            local loop_body = parse.of_chunk(t, "loop", "do? loop")
            t:next()
            body:compile(claw.do_while_loop(loop_pred, loop_body))
        elseif t:is("each") then
            t:next()
            local loop_body = parse.of_chunk(t, "for", "for")
            body:compile(claw.each_loop(loop_body))
            t:next()
        elseif t:is("each/await") then
            t:next()
            local loop_body = parse.of_chunk(t, "for", "for")
            local node = claw.each_loop(loop_body);
            node.is_await = true
            body:compile(node)
            t:next()
        elseif t:can(iter_eff.is) then
            local w, i, o = iter_eff.parse(t:tok())
            t:next()
            local loop_body = parse.of_chunk(t, "for", t:tok().." end")
            body:compile(claw.iter(w, i, o, loop_body))
            t:next()
        elseif t:is("cond") then
            t:next()
            body:compile(parse.cond_body(t))
        elseif t:is("{") then
            t:next()
            local vars, tail = chunk(t, "}", "close curly")
            t:next()
            body:compile(claw.assign_many(vars))
        else
            body:compile(claw.unresolved(t:tok()))
            t:next()
        end
    end
    error("In "..trace:peek().." expected "..(end_name or "nil" ).." before end of code!")
end

local js_plat = [=[
: , (#*\) it :push(*) ; 
: s/join { # -- ret } it :join(\*) ;
: str (*\*) :toString(\*) ;

: print (*\) @console :log(*\) ;

: max (**\*) Math.max(**\*) ;
: min (**\*) Math.min(**\*) ;

: randint { l h -- res } 
 l Math.ceil(*\*) { L }
 h Math.floor(*\*) { H }
 Math.random(\*) H L - L + * ;

: randf ( -- res ) Math.random(\*) ;

: array ( -- arr ) Array(\*) ;

]=]

local lua_plat = [=[
: , (#*\) table.insert(#*) ;
: s/join (#\*) table.concat(#\*) ;
: str (*\*) tostring(*\*) ;

behaves print (*\)

: max (**\*) math.max(**\*) ;
: min (**\*) math.min(**\*) ;

: randint (**\*) math.random(**\*) math.floor(*\*) ;
: randf (\*) math.random(\*) ;

: array (\*) table ;
]=]

local stdlib = [=[
: between { i ra rb -- ? } 
    i ra rb min >=
    i ra rb max <= and ;

]=]

function get_plat(lang)
    if lang == "js" then
        return js_plat
    else
        return lua_plat
    end
end

function onion.compile(code, lang)
    lang = lang or "lua"
    trace:push("TOPLEVEL")

    local toks = Lex(get_plat(lang)..stdlib..code)
    local ast = parse.of_chunk(toks, Lex.EOF, 'EOF')
    local env = BaseEnv()
    ast:resolve(env)
    ast:stack_infer()
    local stack = seam.stack('toplevel')
    local it_stack = seam.stack('toplevel it')
    -- trace:enable()
    ast:stitch(stack, it_stack)
    -- trace:pp(ast)
    --trace:disable()
    -- for a in iter.each(ast) do trace("AST", a) end
    if lang == "lua" then
        local out = LuaOutput()
        ast:to_lua(out, stack)
        trace:pop()
        return out:str()
    elseif lang == "js" then
        local out = JsOutput()
        ast:to_js(out, stack)
        trace:pop()
        return out:str()
    else
        error("Unsupported output language: "..lang)
    end
end

function onion.exec(code, ...)
    assert(load(onion.compile(code), "t"))(...)
end

function onion.repl()
    trace:push("TOPLEVEL")
    local env = BaseEnv()
    local fnEnv = {CONT=true}
    setmetatable(fnEnv, {__index=_G})
    local vstack = {}
    local stack = seam.stack('toplevel')
    local it_stack = seam.stack('toplevel it')
    local ret = {}
    local repl_idx = 0
    function ret.eval(line)
        local toks = Lex(line)
        local ast = parse.of_chunk(toks, Lex.EOF, 'EOF')
        ast:resolve(env)
        ast:stack_infer()
        ast:stitch(stack, it_stack)
        local out = LuaOutput()
        ast:to_lua(out, stack)

        for i=1, #stack._items do
            stack._items[i] = atoms.lit("(({...})["..i.."])") 
        end
        local fn = assert(load(out:str(), "repl:"..repl_idx, "t", fnEnv))
        vstack = table.pack(fn(table.unpack(vstack)))
        return vstack
    end

    function ret.should_continue()
        return fnEnv.CONT
    end
    return ret
end


return onion
