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
local claw = require("claw")
local iter = require("iter")
local f = iter.f
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
            t:next()
            return ret, t:tok()
        else
            iter.push(ret, t:tok())
            t:next()
        end
    end
    error("Expected "..end_name.." before end of tokens!")
end

local call_eff = {}
function call_eff.is(word) return word:find("%(%**\\?%**%)$") ~= nil end
function call_eff.parse(word) 
    local _,_,ins, outs = word:find("%((%**)\\?(%**)%)$")
    if ins then
        return #ins, #(outs or {})
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
    return word, inputs, loop_vars
end

local parse =  {}

function parse.cond_body(t)
   local clauses = Block() 
   local body = Block()

   while t:tok() do
        if t:matches("[\r\n]") then
            body:compile(claw.whitespace(t:tok()))
            t:next()
        end

        assert(is("when"))
        go_next()

        local pred_body, when_true_body
        pred_body = parse.of_chunk(t, "of", "cond pred clause")
        when_true_body = parse.of_chunk(t, "then", "cond body clause")
        clauses:compile(claw.cond_clause(pred_body, when_true))
        if is("end") then
            return body
        end
   end
   error("Expected an 'end' token")
end

function parse.of_chunk(t, end_, end_name)
    local is_end = matcher(end_)
    local body = Block()
    while t:tok() do
        if is_end(t:tok()) then
            t:next()
            return body, t:tok()
        end

        if t:is("if") then
            local body, t
            t_body, tail = parse.of_chunk(t, {"else", "then"})
            if tail == "else" then
                f_body = parse.of_chunk(t, "then")
                block:compile(claw.ifelse(t_body, f_body))
            else
                block:compile(claw.if_(t_body))
            end
        elseif t:is(":") then
            t:next()
            local name = cond(t:any_of{"(", "{"} or t:can(short_eff.is), claw.anon_fn, t:tok())
            if name ~= claw.anon_fn then t:next() end
            local inputs, outputs = nil, nil
            assert(t:any_of{"(", "{"} or t:can(short_eff.is), "Word def should have stack effect")
            if is("(") then
                inputs = chunk(t, "--", "stack effect split")
                ouputs = chunk(t, ")", "end of stack effect")
            elseif is("{") then
                inputs = chunk(t, "--", "var stack effect split")
                ouputs = chunk(t, "}", "end of var stack effect")
            elseif t:can(short_eff.is) then
                local i, o = assert(short_eff.parse(t:tok()))
                t:next()
                inputs = iter.rep("*", i)
                outputs = iter.rep("*", o)
            else
                error("Word def should have stack effect!")
            end
            fn_body = parse.of_chunk(t, ";")
            body:compile(claw.func(name, inputs, outputs, fn_body))
        elseif t:is("do") then
            local loop_body = parse.of_chunk(t, "loop")
            body:compile(claw.do_loop(loop_body))
        elseif t:is("+do") then
            local loop_body = parse.of_chunk(t, "loop")
            body:compile(claw.do_step_loop(loop_body))
        elseif t:is("do?") then
            local loop_pred = parse.of_chunk(t, "while")
            local loop_body = parse.of_chunk(t, "loop")
            body:compile(claw.do_while_loop(loop_pred, loop_body))
        elseif t:is("each") then
            local loop_body = parse.of_chunk(t, "for")
            body:compile(claw.each_loop(loop_body))
        elseif t:can(iter_eff.is) then
            local w, i, o = iter_eff.parse(t:tok())
            local loop_body = parse.of_chunk(t, "for")
            body:compile(claw.iter(w, i, o, loop_body))
        elseif t:is("cond") then
            local cond_body = parse.of_chunk(toks, "end")
            error("not done")

        elseif t:is("{") then
            local vars, tail = chunk(t, "}", "close curly")
            block:compile(claw.assign_many(vars))
        else
            block:compile(claw.unresolved(t:tok()))
            go_next()
        end
    end
    error("Expected "..end_name.." before end of code!")
end

function onion.parse(code)
end

function onion.compile(code)
    local toks = Lex(code)
    local ast = parse.chunk(toks, lexer.EOF)

end

