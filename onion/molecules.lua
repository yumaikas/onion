local iter = require("iter")
local Object = require("classic")
local f, w, getter = iter.f, iter.w, iter.getter
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

function mol(name, new, tostr) 
    local e = molecules.expr:extend() 
    e.new = fn(new)
    e.__tostring = fn(tostr)
    molecules[name] = e
end

mol('binop', '(s,op) s.op=op', '(s) -> "binop("..s.op..")"')
mol('assign_op', '(s,op) s.op=op', '(s) -> "op=("..s.op..")"')
mol('table_lit', '()', '(s) -> "table"')
mol('shuffle', '(s, name, ins, outs) s.name=name s.ins=ins s.outs=outs', getter'name')
mol('propget', '(s, prop) s.prop=prop', '(s) -> "pget("..s.prop..")"')
mol('propset', '(s, prop) s.prop=prop', '(s) -> "pset("..s.prop..")"')
mol('prop_set_it', '(s, prop) s.prop=prop', '(s) -> "pset_it("..s.prop..")"')
mol('prop_get_it', '(s, prop) s.prop=prop', '(s) -> "pget_it("..s.prop..")"')
mol('get', '()', '(s) -> "get"')
mol('put', '()', '(s) -> "put"')
mol('len', '()', '(s) -> "len"')

function mol_str(name, str) mol(name, '()', '() -> "'..str..'"') end
mol_str('new_table_it', 'new-table-it')
mol_str('push_it', 'push-it')
mol_str('pop_it', 'pop-it')
mol_str('drop_it', 'drop-it')
mol_str('ref_it', 'ref-it')

return molecules
