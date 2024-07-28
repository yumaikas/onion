local resolve = require("resolve")
local Env = resolve.Env
local atoms = require("atoms")
local pp = require("pprint")
local iter = require("iter")
local w = iter.w

local claw = require("claw")
local molecules = require("molecules")

local function curry(f, ...) 
    local args = {...}
    return function()
        return f(table.unpack(args)) 
    end
end 

local function makeBaseEnv() 
    local baseEnv = Env()

    local ops = [[(+ +)(- -)(* *)(> >)(< <)(div /)(idiv //)(mod %)(eq? ==)(neq? ~=)(.. ..)(or or)(and and)(<= <=)(>= >=)]]
    for k, v in ops:gmatch("%((%S+) (%S+)%)")  do
        baseEnv:put(k, curry(molecules.binop, v))
    end
    local assign_ops = [[(+= +)(-= -)(or= or)(and= and)(*= *)(div= /)(..= ..)(mod= %)]]
    for k, v in assign_ops:gmatch("%((%S+) (%S+)%)")  do
        baseEnv:put(k, curry(atoms.assign_op, v))
    end

    baseEnv:put("dup", molecules.shuffle('dup', w'a', w'a a'))
    baseEnv:put("swap", molecules.shuffle('swap', w'a b', w'b a'))
    baseEnv:put("nip", molecules.shuffle('nip', w'a b', w'b'))
    baseEnv:put("drop", molecules.shuffle('drop', w'a', w''))
    baseEnv:put("true", atoms.bool(true))
    baseEnv:put("false", atoms.bool(false))
    function ctor(k, v)
        baseEnv:put(k, function() return v() end)
    end
    ctor("table", molecules.table_lit)
    ctor("get",  molecules.get)
    ctor("put", molecules.put)
    ctor("len", molecules.len)
    ctor("not", molecules._not)
    ctor("t[", molecules.new_table_it)
    ctor("[", molecules.push_it)
    ctor("]", molecules.pop_it)
    ctor("].", molecules.drop_it)
    ctor("it", molecules.ref_it)

    return baseEnv
end


return makeBaseEnv
