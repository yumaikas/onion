local iter = require("iter")
local record = require("record")
local Object = require("classic")
local f = iter.f
local claw = require("claw")

local Atom = Object:extend()
Atom.__tostring = f'() -> "Atom"'
local atoms = {}

local function atom(name, ...) atoms[name] = record(name, Object, ...) end

atom("var", "name")
atom("number", "val")
atom("string", "val")
atom("call", "name", "num_inputs", "num_outputs")
atom("whitespace", "ws")


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
function call_eff.is(word) return word:find("([^%(]*)%(%**\\?%**%)$") ~= nil end
function call_eff.parse(word) 
    local _,_, called, ins, outs = word:find("([%(]*)%((%**)\\?(%**)%)$")

    if ins then
        return called, #ins, #(outs or {})
    else
        return nil
    end
end

function claw.body:resolve(env)
    for idx, node in ipairs(self._items) do
        if instanceof(node, claw.unresolved) then
            if tonumber(node.tok) then
                self._items[idx] = atoms.number(tonumber(node.tok))
            elseif node.tok:find('^"') and node.tok:find('"$') then
                self._items[idx] = atoms.string(node.tok:sub(2,-2))
            elseif env:get(node.tok) then
                self._items[idx] = env:get(node.tok)
            elseif call_eff.is(node.tok) then
                self._items[idx] = atoms.call(call_eff.parse(node.tok))
            elseif node.tok:match('[\r\n]') then
                self._items[idx] = atoms.whitespace(node.tok)
            else
                error("Unable to resolve token: ["..node.tok.."]")
            end
        else
            node:resolve(env)
        end
    end
end

function claw.whitespace:resolve(env) end
function claw.assign_many:resolve(env) 
    for v in iter.each(self.varnames) do
        env:put(v, atoms.var(v))
    end
end

function claw.ifelse:resolve(env) 
    self.when_true:resolve(env)
    self.when_false:resolve(env)
end
function claw.if_:resolve(env) self.when_true:resolve(env) end
function claw.func:resolve(env)
    env:put(self.name, self)
    local fenv = Env(env)
    if instanceof(self.inputs, claw.assign_many) then self.inputs:resolve(fenv) end
    self.body:resolve(fenv)
end

local body_res = f'(s, env) s.body:resolve(env)'

claw.iter.resolve = body_res
claw.do_loop.resolve = body_res
claw.do_step_loop.resolve = body_res
claw.do_while_loop.resolve = body_res
claw.each_loop.resolve = body_res

function claw.cond_clause:resolve(env)
    self.pred:resolve(env)
    self.body:resolve(env)
end

function claw.cond:resolve(env)
    for c in iter.each(env) do c:resolve(env) end
end


return Env, Atom, atoms