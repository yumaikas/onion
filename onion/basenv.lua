local Env, Atom = require("resolve")
local record = require("record")
local iter = require("iter")
local claw = require("claw")
local Object = require("classic")
local f, w = iter.f, iter.w

local Expr = Object:extend()
local BinOp = Expr:extend()
BinOp.new = f'(s,op) s.op=op'
local op = function(op) return BinOp(op) end
local AssignOp = Expr:extend()
AssignOp.new = f'(s, op) s.op=op'

local Shuffle = Expr:extend()
Shuffle.new = f'(s, ins, outs) s.ins=ins s.outs=outs'

local function makeBaseEnv() 
    local baseEnv = Env()

    local ops = [[(+ +) (- -) (* *) (> >) (< <) (mod %) 
        (eq? ==) (neq? ~=) ]]
    for k, v in ops:gmatch("%((%S+) (%S+)%)")  do
        baseEnv:put(k, op(v))
    end
    local assign_ops = [[(+= +)(-= -)(or= or)(and= and)(*= *)(div= /)(..= ..)]]
    for k, v in assign_ops:gmatch("%((%S+) (%S+)%)")  do
        baseEnv:put(k, AssignOp(v))
    end

    baseEnv:put("dup", Shuffle(w'a', w'a a'))
    baseEnv:put("swap", Shuffle(w'a b', w'b a'))
    baseEnv:put("nip", Shuffle(w'a b', w'b'))
    baseEnv:put("drop", Shuffle(w'a', w''))


    return baseEnv
end



return makeBaseEnv
