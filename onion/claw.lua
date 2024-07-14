local f = require("iter").f
local record = require("record")
local Object = require("classic")

local claw = {}

claw.parse = Object:extend()

local last
function rec(name, ...) 
    local cls = record(name, claw.parse, ...)
    claw[name] = cls
    last=cls
    return cls
end


claw.namelist = Object:extend()
claw.namelist.new = f'(s, from) s._items = from'
claw.namelist.__push = f'(s, item) iter.push(s._items, item)'
claw.namelist.__tostring = f[[(s) -> "n:{ "..iter.strmap(s._items, @(i) -> "\'"..i.."\'" ;, ", ").." }"]]


rec("ifelse", "when_true", "when_false") 
rec("if_", "when_true")
rec("whitespace", "whitespace")
rec("assign_many", "varnames") 
claw.assign_many.__tostring = f[[(s) -> "::{ "..iter.strmap(s.varnames, @(i) -> "\'"..i.."\'" ;, ", ").." }"]]
rec("func", "name", "inputs", "outputs", "body")
rec("iter", "word", "inputs", "loop_vars", "body")
rec("do_loop", "body")
rec("do_step_loop", "body")
rec("do_while_loop", "cond", "body")
rec("cond", "clauses")
rec("cond_clause", "pred", "body")
rec("each_loop", "body")


function claw.iter:init()
    self.inputs = self.inputs or {}
    self.loop_vars = self.loop_vars or {}
end

claw.body = Object:extend()
claw.body.new = f'(s) s._items = {}'
claw.body.compile = f'(s, item) iter.push(s._items, item)' 
claw.body.__tostring = f'(s) -> "{{ "..iter.str(s._items, " ").." }}"'
claw.body.__each = f'(s) -> iter.each(s._items)'

rec("unresolved", "tok") 
claw.unresolved.__tostring = f'(s) -> "%["..s.tok.."]"'

local anon = Object:extend()
anon.__tostring = f'(s) -> "anon-fn"'
claw.anon_fn = anon()

return claw


