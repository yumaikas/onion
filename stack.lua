local Object = require("classic")
local Buffer = require("buffer")
local Ast = require("ast")
local iter = require("iter")

Stack = Object:extend()

function Stack:new() 
    error("Stack is an abstract class, make an ExprStack or an ItStack instead") 
end


ExprStack = Stack:extend()

Barrier = Object:extend()


InputStack = Stack:extend()

function InputStack:new(name, underflow_limit) 
    self.vars = {}
    self.name = name
    self.storage = Buffer()
end

function InputStack:__tostring()
    return string.format("InputStack('%s', items: %s, vars: %s)",
        self.name,
        iter.str(self.storage.items, ", "),
        iter.str(self.vars, ", ")
    )
end

function InputStack:pop()
    return self.storage:pop_throw(self.name.." stack undeflow!")
end
local none = {}
function InputStack:push(val) 
    self.storage:push(none) 
    local var = Var("_"..self.storage:size())
    self.vars[self.storage:size()] = var
    self.storage:put(var)
    return Assign(var.var, val)
end

function InputStack:push_return()
    self.storage:push(none) 
    local var = Var("_"..self.storage:size())
    self.vars[self.storage:size()] = var
    self.storage:put(var)
    return var 
end

function InputStack:peek() return self.storage:peek() end
function InputStack:size() 
    return self.storage:size() 
end
function InputStack:each() return self.storage:each() end
function InputStack:copy(name)
    local ret = InputStack()
    ret.vars = self.vars
    ret.name = self.name
    ret.storage = self.storage:copy()
    return ret
end


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

function ItStack:size()
    return self.storage:size()
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

function ExprState:new(name, it_name, capacity)
    self.stack = InputStack(name, capacity or 0)
    self.it_stack = ItStack(it_name)
    -- self.def_info = DefStack("toplevel")
end
function ExprState:copy(name, it_name)
    local newState = ExprState()
    newState.stack = self.stack:copy(name or self.name)
    newState.it_stack = self.it_stack:copy(it_name or self.it_name)
    -- newState.def_info = self.def_info:copy()
    return newState
end

function ExprState:push(value) return self.stack:push(value) end
function ExprState:peek() return self.stack:peek() end
function ExprState:pop() return self.stack:pop() end
function ExprState:has_size(size) 
    pp(self.stack)
    return self.stack:size() == size 
end

function ExprState:fill_input_stacks(inputs, dbg)
    if #inputs == 0 then
        error("Need to pass stacks to fill_input_stacks via a table")
    end
    if dbg then
        print("DBG", iter.str(inputs, " "))
    end
    local max_input_size = 0
    for input in iter.each(inputs) do
        max_input_size = math.max(max_input_size, #input.stack.to_fill)
    end

    local fill_vals = {}
    for i=1,max_input_size do
        fill_vals[#fill_vals + 1] = self.stack:pop()
    end

    local ret = {}
    for input in iter.each(inputs) do
        for i=1,#input.stack.to_fill do
            local fb = iter.from_back(input.stack.to_fill, i)
            local box = input.stack.to_fill[fb]
            local fv_idx = iter.from_back(fill_vals, i)
            box:set(fill_vals[fv_idx])
            iter.push(ret, box)
        end
    end
    return ret
end


--function ExprState:push_def_info(name) self.def_info:push(name) end
-- function ExprState:pop_def_info() self.def_info:pop() end
function ExprState:current_def_name() return self.def_info:peek() end
function ExprState:push_it(val) self.it_stack:push(val) end
function ExprState:peek_it() return self.it_stack:peek() end
function ExprState:pop_it() return self.it_stack:pop() end



