local atoms = require("atoms")
local iter = require("iter")
local claw = require("claw")
local Object = require("classic")
local record = require("record")
local seam = require("seam")
local f, w, getter = iter.f, iter.w, iter.getter

function to_assign(val)
    if instanceof(val:get(), seam.var) then
        return val
    else
        val:set(seam.ssa_assign(val:get()))
    end
end

function claw.body:stitch(stack, it_stack)
    for idx, node in ipairs(self._items) do
        -- TODO: Special case anon funcs?
        node:stitch(stack, it_stack)
    end
end

function claw.func:stitch(outer_stack, it_stack)
    local stack = seam.stack()
    if instanceof(self.inputs, claw.namelist) then
        local idx = 1
        for i in iter.each(self.inputs) do
            stack:push(seam.cell(atoms.var("p"..idx)))
            idx = idx+1
        end
    end
    self.body:stitch(stack, it_stack)
    self.seam_outputs = stack:copy()
    assert(#seam_outputs == #self.outputs, "Invalid stack effect!")

    if self.name == claw.anon_fn then
        outer_stack:push(self)
    end
end

function claw.iter:stitch(stack, it_stack)
    self.input_cells = {}
    for i in iter.backwards(self.inputs) do
        if i == '#' then
            iter.push(self.input_cells, it_stack:peek())
        else
            iter.push(self.input_cells, stack:pop())
        end
    end

    local body_stack = seam.stack()

    for lv in iter.each(self.loop_vars) do
        if lv ~= '_' then
            body_stack:push(seam.ssa_var())
        end
    end
    self.body:stitch(body_stack, it_stack)
end

function claw.do_loop:stitch(stack, it_stack)
    self.to = stack:pop()
    self.from = stack:pop()
    stack:push(seam.ssa_var())
    self.body:stitch(stack, it_stack)
end

function claw.do_step_loop:stitch(stack, it_stack)
    self.step = stack:pop()
    self.to = stack:pop()
    self.from = stack:pop()
    stack:push(seam.ssa_var())
    self.body:stitch(stack, it_stack)
end

function claw.do_while_loop:stitch(stack, it_stack)
    local cond_stack = seam.stack()
    self.cond:stitch(cond_stack, it_stack)
    self.body:stitch(seam.stack(), it_stack)
end


function claw.assign_many:stitch(stack, it_stack)
    self.assigns = {}
    for n in iter.backwards(self.varnames) do
        iter.push(self.assigns, seam.assign(n, stack:pop()))
    end
end

function claw.whitespace:stitch(_,_) end

function claw.if_:stich(stack, it_stack)
    self.cond = stack:pop()
    self.when_true:stitch(stack)
    self.out_vars = {}
    for o in iter.each(self.when_true.eff.out_eff) do
        iter.shift(out_vars, stack:pop())
    end
    for o in iter.each(self.out_vars) do
        stack:push(to_assign(o))
    end
end

function claw.iflese:stitch(stack)
    self.cond = stack:pop()
    local t_stack = stack:copy()
    self.when_true:stitch(t_stack)
    self.t_rets = {}
    for o in iter.each(self.when_true.eff.out_eff) do
        iter.shift(self.t_rets, t_stack:pop())
    end
    self.when_false:stitch(f_stack)
    self.f_rets = {}
    for o in iter.each(self.when_false.eff.out_eff) do
        iter.shift(self.f_rets, t_stack:pop())
    end
    self.out_vars = {}
    for o in iter.each(self.t_rets) do
        local out_var = seam.autovar()
        iter.shift(self.out_vars, out_var)
        stack:push(out_var)
    end
end

function claw.cond:stitch(stack, it_stack)
    -- TODO-RESUME: here
end

