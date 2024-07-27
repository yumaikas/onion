local atoms = require("atoms")
local molecules = require("molecules")
local trace = require("trace")
local iter = require("iter")
local claw = require("claw")
local Object = require("classic")
local record = require("record")
local seam = require("seam")
local f, w, getter = iter.f, iter.w, iter.getter

local function to_assign(val)
    if instanceof(val:get(), seam.var) then
        return val, false
    elseif instanceof(val:get(), seam.cell) then
        return to_assign(val:get())
    elseif instanceof(val:get(), seam.ssa_var) then
        return val:get(), false
    else
        val:set(seam.ssa_assign(val:get()))
        return val, true
    end
end

-- molecule stitches
--
function atoms.bool:stitch(stack, it_stack)
    stack:push(seam.cell(seam.lit(self.val)))
    self.no_out = true
end

function atoms.var:stitch(stack, it_stack)
    stack:push(seam.cell(seam.var(self.name)))
    self.no_out = true
end

function atoms.number:stitch(stack, it_stack)
    stack:push(seam.cell(seam.lit(self.val)))
    self.no_out = true
end

function atoms.string:stitch(stack, it_stack)
    stack:push(seam.cell(seam.strlit(self.val)))
    self.no_out = true
end

function atoms.lit:stitch(stack, it_stack)
    stack:push(seam.cell(seam.var(self.val)))
    self.no_out = true
end

function molecules.binop:stitch(stack, it_stack) 
    self.b, self.a = stack:pop(), stack:pop()
    stack:push(seam.cell(self))
    self.no_out = true
end

function molecules.assign_op:stitch(stack, it_stack) 
    self.value = stack:pop()
end

function molecules.table_lit:stitch(stack, it_stack)
    self.var = seam.cell(seam.ssa_var())
    stack:push(self.var)
end

function molecules.shuffle:stitch(stack, it_stack) 
    local in_kv = {}
    for i in iter.backwards(self.ins) do
        in_kv[i] = stack:pop()
    end
    for i in iter.each(self.outs) do
        stack:push(in_kv[i] or error("Invalid shuffle word!"))
    end
    self.no_out = true
end

function molecules.len:stitch(stack, it_stack)
    self.obj = stack:pop()
    stack:push(seam.cell(self))
    self.no_out = true
end

function molecules._not:stitch(stack, it_stack)
    self.obj = stack:pop()
    stack:push(seam.cell(self))
    self.no_out = true
end


function molecules.get:stitch(stack, it_stack)
    self.obj = stack:pop()
    self.key = stack:pop()
    stack:push(seam.cell(self))
    self.no_out = true
end

function molecules.put:stitch(stack, it_stack)
    self.val = stack:pop()
    self.key = stack:pop()
    self.obj = stack:pop()
end

function molecules.propget:stitch(stack, it_stack)
    self.obj = stack:pop()
    stack:push(seam.cell(self))
    self.no_out = true
end

function molecules.propset:stitch(stack, it_stack)
    self.val = stack:pop()
    self.obj = stack:pop()
end

function molecules.prop_get_it:stitch(stack, it_stack)
    self.obj = it_stack:peek()
    stack:push(seam.cell(self))
    self.no_out = true
end

function molecules.prop_set_it:stitch(stack, it_stack)
    self.obj = it_stack:peek()
    self.val = stack:pop()
end

function molecules.push_it:stitch(stack, it_stack)
    self.var, self.is_new = to_assign(stack:pop())
    it_stack:push(seam.cell(self.var))
    self.no_out = not self.is_new
end

function molecules.pop_it:stitch(stack, it_stack)
    stack:push(it_stack:pop())
    self.no_out = true
end

function molecules.drop_it:stitch(stack, it_stack) 
    self.no_out = true
    it_stack:pop() 
end

function molecules.ref_it:stitch(stack, it_stack) 
    stack:push(it_stack:peek()) 
    self.no_out = true
end

function molecules.name_it:stitch(stack, it_stack)
    self.from = it_stack:pop()
    self.to = seam.cell(seam.var(self.name))
    it_stack:push(to)
end

function molecules.new_table_it:stitch(stack, it_stack)
    self.var = seam.cell(seam.ssa_var())
    it_stack:push(self.var)
end

function molecules.behaves:stitch(stack, it_stack) self.no_out = true end

-- call stitches
function molecules.call:stitch(stack, it_stack)
    trace:pp{"HORKY", self, stack}
    local new_inputs = {}
    for v in iter.backwards(self.inputs) do
        trace("INP", v)
        if v == '#' then
            iter.shift(new_inputs, it_stack:peek() or error("It stack underflow"))
        else
            iter.shift(new_inputs, stack:pop())
        end
    end
    self.inputs = new_inputs
    local idx = 1
    for v in iter.each(self.outputs) do
        local var = seam.cell(seam.ssa_var())
        self.outputs[idx] = var:get()
        stack:push(var)
        idx = idx + 1
    end
end

function molecules.mcall:stitch(stack, it_stack)
    self.on = stack:pop()
    for idx, v in iter.ripairs(self.inputs) do
        if v == '#' then
            self.inputs[idx] = it_stack:peek() or error("It stack underflow")
        else
            self.inputs[idx] = stack:pop()
        end
    end
    for idx, _ in ipairs(self.outputs) do
        local var = seam.cell(seam.ssa_var())
        self.outputs[idx] = var:get()
        stack:push(var)
    end
end

-- claw stitches

function claw.body:stitch(stack, it_stack)
    assert(stack, "missing stack!")
    assert(it_stack, "missing it_stack!")
    for idx, node in ipairs(self._items) do
        trace("BEFORE", node, type(node), stack)
        node:stitch(stack, it_stack)
        trace("AFTER",tostring(node).." |$| ", stack)
    end
end

function claw.func:stitch(outer_stack, it_stack)
    trace:push(self.name)
    local stack = seam.stack(tostring(self.name) .. ' value')
    -- trace.pp{"BITSCANNON", self.inputs, instanceof(self.inputs, claw.namelist)}
    if not self.input_assigns then
        local idx = 1
        for i in iter.each(self.inputs) do
            if i ~= '#' then
                stack:push(seam.cell(seam.var("p"..idx)))
                idx = idx+1
            else
                it_stack:push(seam.cell(seam.var("it")))
            end
        end
    end
    if self.input_assigns then
        for i in iter.each(self.inputs) do
            if i == '#' then
                it_stack:push(seam.cell(seam.var("it")))
            end
        end
    end
    self.body:stitch(stack, it_stack)
    self.seam_outputs = stack:copy(self.name)
    trace(self.outputs, "==", self.seam_outputs)
    assert(#self.seam_outputs == #self.outputs, "Invalid stack effect!")

    if self.name == claw.anon_fn then
        outer_stack:push(seam.cell(self))
    end
    trace:pop()
    self.no_out = self.name == claw.anon_fn
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

    for idx, lv in ipairs(self.loop_vars) do
        if lv ~= '_' then
            local v = seam.ssa_var()
            body_stack:push(seam.cell(v))
            self.loop_vars[idx] = v
        end
    end
    self.body:stitch(body_stack, it_stack)
end

function claw.each_loop:stitch(stack, it_stack)
    self.in_var = stack:pop()
    local body_stack = seam.stack()
    self.loop_var = seam.ssa_var()
    body_stack:push(seam.cell(self.loop_var))
    self.body:stitch(body_stack, it_stack)
end


function claw.do_loop:stitch(stack, it_stack)
    self.from = stack:pop()
    self.to = stack:pop()
    self.var = seam.ssa_var()
    stack:push(seam.cell(self.var))
    self.body:stitch(stack, it_stack)
end

function claw.do_step_loop:stitch(stack, it_stack)
    self.step = stack:pop()
    self.to = stack:pop()
    self.from = stack:pop()
    self.var = seam.ssa_var()
    stack:push(seam.cell(self.var))
    self.body:stitch(stack, it_stack)
end

function claw.do_while_loop:stitch(stack, it_stack)
    local cond_stack = seam.stack()
    self.cond:stitch(cond_stack, it_stack)
    self.cond_val = cond_stack:pop()
    self.body:stitch(seam.stack(), it_stack)
end


function claw.assign_many:stitch(stack, it_stack)
    self.assigns = {}
    for n in iter.backwards(self.varnames) do
        iter.push(self.assigns, stack:pop())
    end
end

function claw.whitespace:stitch(_,_) end
function atoms.whitespace:stitch(_,_) end

function claw.if_:stitch(stack, it_stack)
    self.cond = stack:pop()
    local cond_stack = stack:copy()
    self.when_true:stitch(cond_stack, it_stack)
    self.in_vals = {}
    self.out_vals = {}
    self.out_vars = {}
    for o in iter.each(self.when_true.eff.out_eff) do
        iter.shift(self.out_vals, cond_stack:pop())
        local ov = seam.ssa_var()
        iter.shift(self.in_vals, stack:pop())
        iter.shift(self.out_vars, ov)
        stack:push(seam.cell(ov))
    end
end

function claw.ifelse:stitch(stack, it_stack)
    self.cond = stack:pop()
    local t_stack = stack:copy()
    self.when_true:stitch(t_stack, it_stack)
    self.t_rets = {}
    for o in iter.each(self.when_true.eff.out_eff) do
        iter.shift(self.t_rets, t_stack:pop())
    end
    self.when_false:stitch(stack, it_stack)
    self.f_rets = {}
    for o in iter.each(self.when_false.eff.out_eff) do
        iter.shift(self.f_rets, stack:pop())
    end
    self.out_vars = {}
    for o in iter.each(self.t_rets) do
        local out_var = seam.ssa_var()
        iter.push(self.out_vars, out_var)
        stack:push(seam.cell(out_var))
    end
end

function claw.cond:stitch(stack, it_stack)
    for c in iter.each(self.clauses) do
        local c_stack = stack:copy()
        c.pred:stitch(c_stack, it_stack)
        c.pred.cond_expr = c_stack:pop()
        c.body:stitch(c_stack, it_stack)
        c.out_vars = {}
        for ov in iter.each(c.body.eff.out_eff) do
            iter.shift(c.out_vars, c_stack:pop())
        end
    end
    self.in_vars = {}
    for _ in iter.each(self.eff.in_eff) do
        iter.shift(self.in_vars, stack:pop())
    end

    self.out_vars = {}
    for _ in iter.each(self.eff.out_eff) do
        local out_var = seam.ssa_var()
        iter.shift(self.out_vars, out_var)
        stack:push(seam.cell(out_var))
    end
end

