local iter = require("iter")
local Object = require("classic")
local f, w, getter = iter.f, iter.w, iter.getter
local pp = require("pprint")
local eff = require("eff")
local molecules = {}

molecules.expr = Object:extend()
local function fn(s) 
    if type(s) == "string" then 
        return f(s)
    elseif type(s) == "function" then
        return s
    else
        error("Cannot turn "..tostring(s).." into a function!")
    end
end

local last = nil
local function e(i,o) last.eff = eff.n(i, o) end

function mol(name, new, tostr) 
    local e = molecules.expr:extend() 
    e.new = fn(new)
    e.__tostring = fn(tostr)
    molecules[name] = e
    last = e
end

mol('binop', '(s,op) s.op=op', '(s) -> "binop("..s.op..")"') e(2, 1)
mol('assign_op', '(s,op) s.op=op', '(s) -> "op=("..s.op..")"') e(1,1)
mol('table_lit', '()', '(s) -> "table"') e(0, 1)
mol('shuffle', '(s, name, ins, outs) s.name=name s.ins=ins s.outs=outs s:init()', getter'name') 
function molecules.shuffle:init()
    self.eff = eff(iter.copy(self.ins),iter.copy(self.outs))
end

mol('propget', '(s, prop) s.prop=prop', '(s) -> "pget("..s.prop..")"')  e(1,1)
mol('propset', '(s, prop) s.prop=prop', '(s) -> "pset("..s.prop..")"') e(1, 1)
mol('prop_set_it', '(s, prop) s.prop=prop', '(s) -> "pset_it("..s.prop..")"') e(1, 0)
mol('prop_get_it', '(s, prop) s.prop=prop', '(s) -> "pget_it("..s.prop..")"') e(0, 1)
mol('get', '()', '(s) -> "get"') e(2, 1)
mol('put', '()', '(s) -> "put"') e(3, 0)
mol('len', '()', '(s) -> "len"') e(1,1)

mol('call', [[(s, name, has_it, inputs, outputs) 
s.name=name s.has_it=has_it s.inputs=inputs s.outputs=outputs s:init()
]], [[(s) 
    if s.has_it then
        -> string.format("call[%s](it+%s\\%s)", 
            s.name, 
            iter.str(s.inputs),
            iter.str(s.outputs))
    else
        -> string.format("call[%s](%s\\%s)", 
            s.name, 
            iter.str(s.inputs),
            iter.str(s.outputs))
    end]])

function molecules.call:init() self.eff = eff(self.inputs, self.outputs) end

function mol_str(name, str) mol(name, '()', '() -> "'..str..'"') end
mol_str('new_table_it', 'new-table-it') e(0, 0)
mol_str('push_it', 'push-it') e(1, 0)
mol_str('pop_it', 'pop-it') e(0, 1)
mol_str('drop_it', 'drop-it') e(0,1)
mol_str('ref_it', 'ref-it') e(0, 1)

return molecules
