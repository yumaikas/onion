local symbIdx = 1

local function log(...)
    local toLog = {}
    for i,v in ipairs({...}) do
        print(i, tostring(v))
        toLog[i] = tostring(v)
    end
    print(table.unpack(toLog))
end

local function getenv(env, k)
    if env.vars[k] then
        return env.vars[k]
    elseif env._parent then
        return getenv(env._parent, k)
    else
        return nil
    end
end

local function setenv(env, k, v)
    env.vars[k] = v
end

local envmt = { __index = getenv }

local function proxy(env) 
    local ret = {}
    local mt = {}
    function mt:__index(k)
        return getenv(env, k)
    end
    setmetatable(ret, mt)
    return ret
end

local varmt = { __tostring = function(s) return "var="..s.var end }
local litmt = { __tostring = function(s) return "lit="..s.lit end }

local function env(parent) 
    local ret = { _parent = parent, vars = {} }
    -- setmetatable(ret, envmt)
    return ret
end

local function LSpace() 
    local tuples = {}
    local toDel = {}
    local rules = {}

    function genSym() local ret = "_"..symbIdx symbIdx = symbIdx + 1 return ret end
    
    function add(rule) table.insert(rules, rule) end

    function matchPhrases(todos, phrases, pidx, vars, tuples)
        -- print("PIDX", pidx, #phrases)
        local anyMatch = false
        local phrase = phrases[pidx]
        for ti=#tuples, 1,-1 do
            local rowVars = env(vars)
            local tuple = tuples[ti]
            -- log("Testing Tuple", table.unpack(tuple))
            if not tuple then
                goto nomatch
            end
            if #phrase ~= #tuple then 
                -- print("len nomatch")
                goto nomatch 
            end
            if toDel[ti] then
                goto nomatch
            end
            for i=1,#tuple do
                local t, w = tuple[i], phrase[i]
                if w.lit and t ~= w.lit then
                    -- print("lit ", t, w, "nomatch")
                    goto nomatch
                end
                if w.var then
                    local v = getenv(rowVars, w.var)
                    if v and v ~= t then
                        -- print("var ", t, w, "nomatch")
                        goto nomatch
                    elseif not v then
                        setenv(rowVars, w.var, t)
                    end
                end
            end
            if #phrases == pidx then
                -- print("YO!")
                --table.remove(tuples, ti)
                toDel[ti] = true
                anyMatch = true
                for _,todo in ipairs(todos) do
                    todo(proxy(rowVars))
                    -- table.insert(matches, ti)
                end
            elseif pidx < #phrases then
                -- print("OY!")
                if matchPhrases(todos, phrases, pidx+1, env(rowVars), tuples) then
                    toDel[ti]=true
                    anyMatch=true
                end
            end
            ::nomatch::
        end
        return anyMatch
    end

    function match(rules, tuples)
        for _, rule in ipairs(rules) do
            local vars = env()
            local matched = true
            local tuple = tuples[ti]
            --local matchIds = 
            matchPhrases(rule.consequents, rule.phrases, 1, vars, tuples)
            local removing = {}
            for k in pairs(toDel) do
                table.insert(removing, k)
                toDel[k] = nil
            end
            -- print("matched",table.unpack(matchIds))
            table.sort(removing)
            for i=#removing,1,-1 do
                table.remove(tuples, removing[i])
            end
        end
    end

    function makeRuleStr(r) 
        local rule = { }
        for w in r:gmatch("%S+") do
            if w:match("^%$") then
                local p = { var=w:sub(2) }
                setmetatable(p, varmt)
                table.insert(rule, p)
            else
                local p = { lit=w }
                setmetatable(p, litmt)
                table.insert(rule, p)
            end
        end
        return rule
    end

    function list(...)
        local t, vars, parts = {}, {}, {...}
        local prevSym = genSym()
        local headSym = prevSym
        for i,p in ipairs(parts) do
            if type(p) == "string" then
                t = {}
                t[#t+1] = prevSym
                for w in p:gmatch("%S+") do
                    if w:match("^%$") then
                        vars[w] = vars[w] or genSym()
                        t[#t+1] = vars[w]
                    else t[#t+1] = w end
                end
                prevSym = genSym()
                t[#t+1] = prevSym
                table.insert(tuples, t)
            end
        end
        t[#t] = nil
        match(rules, tuples)
        return headSym
    end

    function box(n, t)
        local sym = genSym()
        table.insert(tuples, { n, t })
        match(rules, tuples)
        return n.." "..sym
    end

    function fact(...) 
        local t, vars, parts = {}, {}, {...}
        for i,p in ipairs(parts) do
            if type(p) == "string" then
                for w in p:gmatch("%S+") do
                    if w:match("^%$") then
                        vars[w] = vars[w] or genSym()
                        t[#t+1] = vars[w]
                    else t[#t+1] = w end
                end
                table.insert(tuples, t)
                t = {}
            end
        end
        match(rules, tuples)
    end

    function rule(...) 
        local ruleDef = {
            phrases = {},
            consequents = {},
        }
        local ruleTemps = {...}
        for i,r in ipairs(ruleTemps) do
            if type(r) == "string" then
                table.insert(ruleDef.phrases, makeRuleStr(r))
            else
                error("Cannot make rule out of nonstring")
            end
        end

        function so(...) 
            local consequents = {...}
            for i, c in ipairs(consequents) do
                if type(c) == "string" then
                    table.insert(ruleDef.consequents, function(vars)
                        fact(c:gsub("(%$%S+)", function(var)
                            vars[var] = vars[var] or genSym()
                            return vars[var]
                        end))
                    end)
                elseif type(c) == "function" then
                    table.insert(ruleDef.consequents, c)
                else
                    error("Cannot add a consequent that isn't a string or function!")
                end
            end
            add(ruleDef)
            match(rules, tuples)
        end
        return { so=so }
    end

    return rule, fact, list, box, tuples, rules
end

return LSpace
