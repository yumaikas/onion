-- This is a stack, the file name needs to be changed later

local record = require("record")
--local trace = require("trace")
local iter = require("iter")
local f = iter.f
local Object = require("classic")

local seam = {}
seam.base = Object:extend()


function rec(name, ...) 
    local cls = record(name, seam.base, ...)
    seam[name] = cls
    last=cls
    return cls
end

rec("cell", "item")
seam.cell.set = f'(s,val) s.item = val'
seam.cell.get = f'(s) -> s.item'
seam.cell.__tostring = f'(s) -> "$["..tostring(s.item).."]"'

rec("lit", "val")
rec("strlit", "val")
rec("expr", "tree")
rec("var", "name")
seam.var.__tostring = f'(s) -> "\'"..tostring(s.name).."\'"'
rec("ssa_assign", "to")
rec("ssa_var")
seam.ssa_var.__tostring = f'(s) -> "%ssa"'
rec("assign", "name", "val")

function seam.to_var(val) error("seam.to_var not implemented!") end

seam.stack = seam.base:extend()
function seam.stack:new(name)
    self.name = name
    self._items = {}
end

seam.stack.push = f'(s, val) print("push", s.name, val) iter.push(s._items, val)'
seam.stack.peek = f'(s) -> s._items[#s._items]'
seam.stack.pop = f[[(s)
    print("pop", s.name)
  if #s._items > 0 then -> iter.pop(s._items) else error("Stack underflow!") end]]
seam.stack.__each = f'(s) -> iter.each(s._items)'
seam.stack.__len = f'(s) -> #s._items'
function seam.stack:__tostring()
    return '{- '..iter.str(self._items, ", ")..' -}'
end
function seam.stack:copy(name)
    local ret = seam.stack(name)
    ret._items = iter.copy(self._items)
    return ret
end


return seam

