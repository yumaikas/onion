local claw = require("claw")
local atoms = require("atoms")
local molecules = require("molecules")
local Effect = require("effects")
local iter = require("iter")
local f = iter.f
local pp = require("pprint")
local eff = require("eff")

function claw.whitespace:stack_infer() 
    self.eff = Effect({}, {})
    return self.eff
end

function claw.body:stack_infer()
    pp("BODY STACK INFER")
    local total_body_eff = Effect({}, {})
    for c in iter.each(self._items) do
        pp("INFER "..tostring(c))
        if c.eff then
            pp("HAS_EFF"..tostring(c.eff))
            total_body_eff = total_body_eff..c.eff
        elseif c.stack_infer then
            local c_eff = c:stack_infer()
            pp("INFERRED_EFF"..tostring(c_eff))
            total_body_eff = total_body_eff..c_eff
        else
            error("Unable to infer stack effect of "..tostring(c))
        end
    end
    self.eff = total_eff
    return self.eff
end

function claw.ifelse:stack_infer()
    local total_eff = Effect({'cond'}, {})
    local true_eff = self.when_true:stack_infer()
    local false_eff = self.when_false:stack_infer()
    true_eff:assert_matche(false_eff)
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
    -- internal eff
    local body_eff = self.body:stack_infer()
    pp(self.body)
    print(tostring(self.body))
    body_eff:assert_matches_depths(#self.inputs, #self.outputs)
    -- External eff 
    if self.name == claw.anon_fn then
        self.eff = Effect({}, {'fn'})
    else
        self.eff = Effect({},{})
    end

    return self.eff
end

function claw.iter:stack_infer()
    local total_eff = Effect(iter.copy(self.inputs), {})
    local loop_var_eff = Effect({}, iter.copy(loop_vars))
    local body_eff = self.body:stack_infer()
    -- TODO-longterm: Figure out a way to make this 
    -- more flexible (aka, only require it to be balanced
    (loop_var_eff..body_eff):assert_matches_depths(0,0)
    self.eff = total_eff
    return self.eff
end

function claw.each_loop:stack_infer()
    local total_eff = Effect({'t'}, {})
    local loop_var_eff = Effect({}, {'item'})
    local body_eff = self.body:stack_infer()
    (loop_var_eff..body_eff):assert_matches_depths(0,0)
    self.eff = total_eff
    return self.eff
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
    pp("COND STACK INFER")
    local total_eff = Effect({},{})
    local bi, bo
    for i in iter.each(self.clauses) do
        local cond_eff = i.cond:stack_infer()
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
end

