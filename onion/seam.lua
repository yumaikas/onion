-- This is a stack, the file name needs to be changed later

local record = require("record")
local iter = require("iter"0
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
cell.set = f'(s,val) s.item = val'
cell.get = f'(s) -> s.item'

rec("const", "val")
rec("expr", "tree")
rec("var", "name")
rec("ssa_assign", "to")
rec("ssa_var")
rec("assign", "name", "val")

function seam.to_var(val) error("seam.to_var not implemented!") end

seam.stack = seam.base:extend()
function seam.stack:new(name)
    self.name = name
    self._items = {}
end

seam.stack.push = f'(s) iter.push(s._items, val)'
seam.stack.peek = f'(s) -> s._items[#s._items]'
seam.stack.pop = f[[(s)
  if #s._items > 0 then -> iter.pop(s._items) else error("Stack underflow!") end]]
seam.stack.__len = f'(s) -> #s._items'
function seam.stack:copy(name)
    local ret = seam.stack(name)
    ret._items = iter.copy(self._items)
    return ret
end



