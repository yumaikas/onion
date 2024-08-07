local Object = require("classic")
local iter = require("iter")
local f = iter.f
local eff = require('eff')
local atoms = {}

local record = require("record")
local last = nil
local function e(i,o) last.eff = eff.n(i, o) end
local function atom(name, ...) 
    last = record(name, Object, ...) 
    atoms[name] = last
end

atom("var", "name") e(0, 1)
atoms.var.__tostring = f'(s) -> "$["..tostring(s.name).."]"'
atom("number", "val") e(0,1)
atom("lit", "val") e(0, 1)
atoms.number.__tostring = f'(s) -> "["..tostring(s.val).."]"'
atom("string", "val") e(0,1)
atom("bool", "val") e(0,1)
atom("whitespace", "ws") e(0,0)
atoms.whitespace.__tostring = f'(s) -> "ws("..s.ws:gsub("[\\r\\n]", {["\\r"] = "\\\\r", ["\\n"] = "\\\\n"})..")"'
atom("assign_op", "op") e(1,1)

return atoms
