local claw = require("claw")
local atoms = require("atoms")
local molecules = require("molecules")
local Effect = require("effects")
local iter = require("iter")
local f = iter.f
local pp = require("pprint")
local eff = require("eff")
local trace = require("trace")

function claw.whitespace:stack_infer() 
    self.eff = Effect({}, {})
    return self.eff
end

function claw.body:stack_infer()
    local total_body_eff = Effect({}, {})
    for c in iter.each(self._items) do
        trace(c)
        if c.eff then
            trace("EFF", total_body_eff, c.eff, c, total_body_eff..c.eff)
            total_body_eff = total_body_eff..c.eff
        elseif c.stack_infer then
            local c_eff = c:stack_infer()
            trace("INFER", c_eff)
            total_body_eff = total_body_eff..c_eff
        else
            trace:error("Unable to infer stack effect of "..tostring(c))
        end
    end
    self.eff = total_body_eff
    trace(self.eff)
    return self.eff
end

function claw.ifelse:stack_infer()
    local total_eff = Effect({'cond'}, {})
    local true_eff = self.when_true:stack_infer()
    local false_eff = self.when_false:stack_infer()
    true_eff:assert_match(false_eff, 'ifelse')
    self.eff = total_eff..true_eff
    return self.eff
end
function claw.if_:stack_infer()
    local total_eff = Effect({'cond'}, {})
    local eff = self.when_true:stack_infer()
    eff:assert_balanced()
    self.eff = total_eff..eff
    return self.eff
end

function claw.assign_many:stack_infer()
    self.eff = Effect(iter.copy(self.varnames), {})
    return self.eff
end

function claw.func:stack_infer()
    trace:push(self.name)
    -- internal eff
    local body_eff = self.body:stack_infer()
    local inputs = iter.filter(self.inputs, f'(i) -> i ~= "#" and i ~= "it"')
    body_eff:assert_matches_depths(#inputs, #self.outputs, tostring(trace))
    -- External eff 
    if self.name == claw.anon_fn then
        self.eff = Effect({}, {'fn'})
    else
        self.eff = Effect({},{})
    end
    trace:pop()
    return self.eff
end

function claw.iter:stack_infer()
    local total_eff = Effect(iter.copy(self.inputs), {})
    local loop_var_eff = Effect({}, iter.filter(self.loop_vars, f'(s) -> s ~= "_"'))
    local body_eff = self.body:stack_infer()
    -- TODO-longterm: Figure out a way to make this 
    -- more flexible (aka, only require it to be balanced
    local comb_eff = loop_var_eff..body_eff
    comb_eff:assert_matches_depths(0,0)
    self.eff = total_eff
    return self.eff
end

function claw.each_loop:stack_infer()
    trace(tostring(self))
    local total_eff = Effect({'t'}, {})
    local loop_var_eff = Effect({}, {'item'})
    trace("EACH_BODY", self.body)
    local body_eff = self.body:stack_infer()
    trace("BODY_EFF", (body_eff or nil))
    local comb_eff = loop_var_eff..body_eff
    comb_eff:assert_matches_depths(0,0)
    self.eff = total_eff
    return self.eff
end

function molecules.call:stack_infer()
    --TODO: RESUME
end

function claw.do_loop:stack_infer()
    local total_eff = Effect({'to','from'}, {})
    local body_eff = self.body:stack_infer()
    body_eff:assert_matches_depths(1,0)
    self.eff = total_eff
    return self.eff
end

function claw.do_step_loop:stack_infer()
    local total_eff = Effect({'to', 'from', 'step'}, {})
    local body_eff = self.body:stack_infer()
    body_eff:assert_matches_depths(1, 0)
    self.eff = total_eff
    return self.eff
end

function claw.do_while_loop:stack_infer()
    local total_eff = Effect({},{})
    local cond_eff = self.cond:stack_infer()
    cond_eff:assert_matches_depths(0,1)
    local body_eff = self.body:stack_infer()
    body_eff:assert_matches_depths(0,0)
    self.eff = total_eff
    return self.eff
end

function claw.cond:stack_infer()
    local total_eff = Effect({},{})
    local bi, bo
    for i in iter.each(self.clauses) do
        pp(i)
        local cond_eff = i.pred:stack_infer()
        cond_eff:assert_matches_depths(0,1)
        local body_eff = i.body:stack_infer()
        if bi and bo then
            body_eff:assert_matches_depths(bi, bo)
        else
            bi = #body_eff.in_eff
            bo = #body_eff.out_eff
        end
    end
    self.eff = eff.n(bi, bo)
    return self.eff
end

