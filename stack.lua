local Object = require("classic")
local Buffer = require("buffer")
local Ast = require("ast")

Stack = Object:extend()

function Stack:new() 
    error("Stack is an abstract class, make an ExprStack or an ItStack instead") 
end


ExprStack = Stack:extend()

Barrier = Object:extend()


function Barrier:new(nextvar)
    self.nextvar = nextvar
    self.vars = {}
    self.exists = {}
    self.assigns = {}
end

function Barrier:compile(value)
    if instanceof(value, Var) then
        table.insert(self.vars, value)
        table.insert(self.exists, value)
        return value
    else
    local var = Var(self.nextvar())
    table.insert(self.assigns, Assign(var.var, value, true))
    table.insert(self.vars, var)
    return var
    end
end

function ExprStack:new(name)
    self.name = name
    self.storage = Buffer()
    self:reset_effect()
end

function ExprStack:reset_effect()
    self.min_depth = self.storage:size()
    self.max_depth = self.storage:size()
    self.initial_depth = self.storage:size()
end

function ExprStack:infer_effect()
    local inputs = self.initial_depth - self.min_depth
    local outputs = self.storage:size() - self.min_depth
    return inputs, outputs
end

function ExprStack:is_effect_balanced()
    local i, o = self:infer_effect()
    return i == o
end

function ExprStack:matches_effect(inputs, outputs)
    local i, o = self:infer_effect()
    return i == inputs and o == outputs
end

function ExprStack:copy(name)
    local newStack = ExprStack(name)
    newStack.name = name
    newStack.storage = self.storage:copy()
    newStack:reset_effect()
    return newStack
end

function ExprStack:pop()
    pp(self.storage)
    local ok, item = self.storage:pop_check()
    if not ok then
        error(self.name.." stack underflow!")
    end
    if instanceof(item, Barrier) then
        local barrier = item
        -- TODO: finish here
        local behind_barrier = self.storage:pop_throw(self.name.." stack underflow")
        self.storage:push(barrier)
        return barrier:compile(behind_barrier)
    end

    return item
end

function ExprStack:push(value) 
    self.storage:push(value) 
    self.max_depth = math.max(self.max_depth, self.storage:size())
end


function ExprStack:peek() return self.storage:peek() end
function ExprStack:size() return self.storage:size() end
function ExprStack:each() return self.storage:each() end


ItStack = Stack:extend()

function ItStack:new(name)
    self.name = name
    self.storage = Buffer()
end

function ItStack:copy(name)
    local newStack = ItStack(name)
    newStack.storage = self.storage:copy()
    return newStack
end

function ItStack:pop()
    local ok, item = self.storage:pop_check()
    if not ok then
        error(self.name.." stack underflow!")
    end
    return item
end

function ItStack:peek()
    return self.storage:peek() or error("No It Stack Values")
end

function ItStack:push(value)
    self.storage:push(value)
    return self
end

DefStack = Stack:extend()

function DefStack:new(name)
    self.storage = Buffer()
    self.storage:push(name)
end

function DefStack:copy()
    local newStack = DefStack()
    newStack.storage = self.storage:copy()
end

function DefStack:pop()
    local ok, item = self.storage:pop_check()
    if not ok then
        error("DefStack underflow")
    end
    return item
end

function DefStack:peek()
    return self.storage:peek() or error("Empty Def Stack! This shouldn't happen!")
end

function DefStack:push(value)
    self.storage:push(value)
    return self
end


ExprState = Object:extend()

function ExprState:new(name, it_name)
    self.stack = ExprStack(name)
    self.it_stack = ItStack(it_name)
    self.def_info = DefStack("toplevel")
end
function ExprState:copy(name, it_name)
    local newState = ExprState()
    newState.stack = self.stack:copy(name or self.name)
    newState.it_stack = self.it_stack:copy(it_name or self.it_name)
    newState.def_info = self.def_info:copy()
    return newState
end

function ExprState:push(value) self.stack:push(value) end
function ExprState:peek() return self.stack:peek() end
function ExprState:pop() return self.stack:pop() end
function ExprState:has_size(size) 
    pp(self.stack)
    return self.stack:size() == size 
end
function ExprStack:barrier(nextvar) 
    local barrier = Barrier(nextvar)
    self.stack:push(barrier)
    return barrier
end
function ExprState:push_def_info(name) self.def_info:push(name) end
function ExprState:pop_def_info() self.def_info:pop() end
function ExprState:current_def_name() return self.def_info:peek() end
function ExprState:push_it(val) self.it_stack:push(val) end
function ExprState:peek_it() return self.it_stack:peek() end
function ExprState:pop_it() return self.it_stack:pop() end



