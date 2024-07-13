local resolve = require("resolve")
local Env, Atom, atoms = resolve.Env, resolve.Atom, resolve.atoms

local record = require("record")
local iter = require("iter")
local claw = require("claw")
local Object = require("classic")
local f, w, getter = iter.f, iter.w, iter.getter

local molecules = require("molecules")

local function makeBaseEnv() 
    local baseEnv = Env()

    local ops = [[(+ +)(- -)(* *)(> >)(< <)(mod %)(eq? ==)(neq? ~=)]]
    for k, v in ops:gmatch("%((%S+) (%S+)%)")  do
        baseEnv:put(k, molecules.binop(v))
    end
    local assign_ops = [[(+= +)(-= -)(or= or)(and= and)(*= *)(div= /)(..= ..)]]
    for k, v in assign_ops:gmatch("%((%S+) (%S+)%)")  do
        baseEnv:put(k, molecules.assign_op(v))
    end

    baseEnv:put("dup", molecules.shuffle('dup', w'a', w'a a'))
    baseEnv:put("swap", molecules.shuffle('swap', w'a b', w'b a'))
    baseEnv:put("nip", molecules.shuffle('nip', w'a b', w'b'))
    baseEnv:put("drop", molecules.shuffle('drop', w'a', w''))
    baseEnv:put("true", atoms.bool(true))
    baseEnv:put("false", atoms.bool(false))
    baseEnv:put("table", molecules.table_lit())
    baseEnv:put("get", molecules.get())
    baseEnv:put("put", molecules.put())
    baseEnv:put("len", molecules.len())
    baseEnv:put("t[", molecules.new_table_it())
    baseEnv:put("[", molecules.push_it())
    baseEnv:put("]", molecules.pop_it())
    baseEnv:put("].", molecules.drop_it())
    baseEnv:put("it", molecules.push_it())

    return baseEnv
end


return makeBaseEnv
