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

function io(i, o)
    last.num_in = i
    last.num_out = o
end

rec("ifelse", "when_true", "when_false") 
rec("if_", "when_true")
rec("whitespace", "whitespace") io(0,0)
rec("assign_many", "varnames") 
rec("func", "name", "inputs", "outputs", "body")
rec("iter", "word", "inputs", "loop_vars", "body")
rec("do_loop", "body")
rec("do_step_loop", "body")
rec("do_while_loop", "cond", "body")
rec("cond", "clauses")
rec("cond_clause", "pred", "when_true")
rec("each_loop", "body")


function claw.iter:init()
    self.inputs = self.inputs or {}
    self.loop_vars = self.loop_vars or {}
end
rec("unresolved", "tok") 

claw.anon_fn = {}

return claw


