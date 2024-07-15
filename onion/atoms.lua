local Object = require("classic")
local Atom = Object:extend()
local iter = require("iter")
local f = iter.f
local eff = require('eff')
Atom.__tostring = f'() -> "Atom"'
local atoms = {}

local record = require("record")
local Object = require("classic")
local last = nil
local function e(i,o) last.eff = eff.n(i, o) end
local function atom(name, ...) 
    last = record(name, Object, ...) 
    atoms[name] = last
end

atom("var", "name") e(0, 1)
atom("number", "val") e(0,1)
atom("string", "val") e(0,1)
atom("bool", "val") e(0,1)
atom("whitespace", "ws") e(0,0)
atom("assign_op", "op") e(1,1)

return atoms
