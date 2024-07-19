local iter = require("iter")
local record = require("record")
local eff=require("eff")
local molecules = require("molecules")
local trace = require("trace")
local Object = require("classic")
local f, w = iter.f, iter.w
local claw = require("claw")
local atoms = require("atoms")


local Env = Object:extend()

function Env:new(parent)
    self.kv = {}
    self.parent = parent
end

function Env:get(key)
    if self.kv[key] then
        return self.kv[key]
    elseif self.parent then
        return self.parent:get(key)
    else
        return nil
    end
end

function Env:put(key, value) self.kv[key] = value end

local call_eff = {}
function call_eff.is(word) return word:find("([^(]*)%(#?%**\\?%**%)$") ~= nil end
function call_eff.parse(word) 
    local _,_, called, ins, outs = word:find("([^(]*)%((#?%**)\\?(%**)%)$")
    trace:pp{called,ins,outs}
    if ins then
        return called, iter.chars(ins), iter.chars(outs or "") 
    else
        trace(self.name)
        return nil
    end
end

function claw.body:resolve(env)
    for idx, node in ipairs(self._items) do
        function map(to) self._items[idx] = to end
        if instanceof(node, claw.unresolved) then
            if tonumber(node.tok) then
                map(atoms.number(tonumber(node.tok)))
            elseif node.tok:find('^"') and node.tok:find('"$') then
                map(atoms.string(node.tok:sub(2,-2)))
            elseif env:get(node.tok) then
                local val = env:get(node.tok)
                if type(val) == "function" then 
                    val = val() 
                end
                if instanceof(val, atoms.assign_op) then
                    assert(instanceof(self._items[idx+1], claw.unresolved))
                    map(molecules.assign_op(val.op, self._items[idx+1].tok))
                    table.remove(self._items, idx+1)
                elseif instanceof(val, claw.func) then
                    map(molecules.call(
                        val.name, 
                        iter.has_value(val.inputs, '#'),
                        iter.copy(val.inputs), 
                        iter.copy(val.outputs)
                    ))
                else
                    local v = env:get(node.tok)
                    if type(v) == "function" then
                        map(v())
                    else
                        map(v)
                    end
                end

            elseif call_eff.is(node.tok) then
                local word, ins, outs = call_eff.parse(node.tok)
                if word:find("^:") then
                    map(molecules.mcall(
                        word:sub(2),
                        iter.has_value(ins, "#"),
                        ins,
                        outs
                    ))
                else
                    map(molecules.call(
                        word,
                        iter.has_value(ins, "#"),
                        ins,
                        outs
                    ))
                end
            elseif node.tok:match("^%.") then
                map(molecules.propget(node.tok:sub(2)))
            elseif node.tok:match("^>>") then
                map(molecules.prop_set_it(node.tok:sub(3)))
            elseif node.tok:match("^>") then
                map(molecules.propset(node.tok:sub(2)))
            elseif node.tok:match(">>$") then
                map(molecules.prop_get_it(node.tok:sub(1,-3)))
            elseif node.tok:match('[\r\n]') then
                self._items[idx] = atoms.whitespace(node.tok)
            else
                error("Unable to resolve token: ["..node.tok.."]")
            end
        else
            trace("RESOLVING: "..tostring(node))
            node:resolve(env)
            trace("RESOLVED: "..tostring(node))
        end
    end
end

function claw.whitespace:resolve(env) end

function claw.assign_many:resolve(env) 
    self.is_new = {}
    for i, v in ipairs(self.varnames) do
        local ev = env:get(v)
        self.is_new[i] = not env:get(v)
        env:put(v, atoms.var(v))
    end
end

function resolve_namelist(self, env, list)
    self.is_new = {}
    local i = 1
    for v in iter.each(list) do
        local ev = env:get(v)
        self.is_new[i] = not env:get(v)
        env:put(v, atoms.var(v))
        i = i + 1
    end
end

function claw.ifelse:resolve(env) 
    self.when_true:resolve(env)
    self.when_false:resolve(env)
end

function claw.if_:resolve(env) self.when_true:resolve(env) end
function claw.func:resolve(env)
    trace:push(self.name)
    env:put(self.name, self)
    local fenv = Env(env)
    if self.input_assigns then resolve_namelist(self, fenv, self.inputs) end
    self.body:resolve(fenv)
    self.env = fenv
    trace:pop()
end

local body_res = f'(s, env) s.body:resolve(env)'

claw.iter.resolve = body_res
claw.do_loop.resolve = body_res
claw.do_step_loop.resolve = body_res
claw.do_while_loop.resolve = f'(s, env) s.cond:resolve(env) s.body:resolve(env)'
claw.each_loop.resolve = body_res

function claw.cond_clause:resolve(env)
    self.pred:resolve(env)
    self.body:resolve(env)
end

function claw.cond:resolve(env)
    for c in iter.each(self.clauses) do 
        c:resolve(env)
    end
end


return { Env=Env, Atom=Atom, atoms=atoms}
