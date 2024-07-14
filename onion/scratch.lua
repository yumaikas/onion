package.path = "./onion/?.lua;"..package.path
-- lex (str) -> tokens
-- parse(tokens) -> ast
---- chunk(tokens, until) -> toks, new_toks
-- resolve_names(ast) -> ast + env
-- effects(ast) -> ast+(blocks & exprs) ! underflows (?)
-- stitch(ast+(blocks & exprs))
-- ssa allocate (ast + (blocks & exprs))

-- local lexer = require("lex")
local Lex = require("lexer")
local Env = require("resolve")
local BaseEnv = require("basenv")
local claw = require("claw") 
local iter = require("iter")
local f = iter.f
require("check_stack")
local tests = require("tests")
local pp = require("pprint")
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
    error("Expected "..end_name.." before end of tokens!")
end

local call_eff = {}
function call_eff.is(word) return word:find("([^%(]*)%(%**\\?%**%)$") ~= nil end
function call_eff.parse(word) 
    local _,_, called, ins, outs = word:find("([%(]*)%((%**)\\?(%**)%)$")

    if ins then
        return called, #ins, #(outs or {})
    else
        return nil
    end
end

local short_eff = {}
function short_eff.is(word) return word:find("^%(%**\\?%**%)$") ~= nil end
function short_eff.parse(word) 
    local _,_,ins, outs = word:find("^%((%**)\\?(%**)%)$")
    if ins then
        return #ins, #(outs or {})
    else
        return nil, "unable to parse short-effect: "..word
    end
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
        if t:matches("[\r\n]") then
            body:compile(claw.whitespace(t:tok()))
            t:next()
        end
        local pred_body = parse.of_chunk(t, "->", "cond pred clause") t:next()
        local when_true_body = parse.of_chunk(t, "of", "cond body clause") t:next()
        clauses:compile(claw.cond_clause(pred_body, when_true_body))
        if t:is("end") then
            t:next()
            return claw.cond(clauses)
        end
   end
   error("Expected an 'end' token")
end

function parse.of_chunk(t, end_, end_name)
    print("Parsing for "..(end_name or 'nil'))
    local is_end = matcher(end_)
    local body = claw.body()
    while t:tok() do
        if is_end(t:tok()) then
            return body, t:tok()
        end

        if t:is("if") then
            t:next()
            local t_body, tail = parse.of_chunk(t, {"else", "then"}, "else/then")
            if tail == "else" then
                t:next()
                f_body = parse.of_chunk(t, "then", "then")
                body:compile(claw.ifelse(t_body, f_body))
            else
                body:compile(claw.if_(t_body))
            end
            t:next()
        elseif t:is(":") then
            t:next()
            local name = cond(t:any_of{"(", "{"} or t:can(short_eff.is), claw.anon_fn, t:tok())
            if name ~= claw.anon_fn then t:next() end
            local inputs, outputs = nil, nil
            assert(t:any_of{"(", "{"} or t:can(short_eff.is), "Word def should have stack effect")
            if t:is("(") then
                t:next()
                inputs = claw.namelist(chunk(t, "--", "stack effect split"))
                t:next()
                outputs = claw.namelist(chunk(t, ")", "end of stack effect"))
                t:next()
            elseif t:is("{") then
                t:next()
                inputs = claw.assign_many(chunk(t, "--", "var stack effect split"))
                t:next()
                outputs = claw.namelist(chunk(t, "}", "end of var stack effect"))
                t:next()
            elseif t:can(short_eff.is) then
                local i, o = assert(short_eff.parse(t:tok()))
                t:next()
                inputs = iter.rep("*", i)
                outputs = iter.rep("*", o)
            else
                error("Word def should have stack effect!")
            end
            fn_body = parse.of_chunk(t, ";", "end-of-word")
            body:compile(claw.func(name, inputs, outputs, fn_body))
            t:next()
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
            local loop_body = parse.of_chunk(t, "for", "each")
            body:compile(claw.each_loop(loop_body))
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
    error("Expected "..(end_name or "nil" ).." before end of code!")
end

function onion.parse(code)
    local toks = Lex(code)
    local ast = parse.of_chunk(toks, Lex.EOF, 'EOF')
end

function onion.compile(code)
    local toks = Lex(code)
    print(toks)
    local ast = parse.of_chunk(toks, Lex.EOF, 'EOF')
    local env = BaseEnv()
    ast:resolve(env)
    ast:stack_infer()

    -- for i in iter.each(ast._items) do print(i) end

end

return onion
