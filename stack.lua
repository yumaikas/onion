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
    self.assigns = {}
end

function Barrier:compile(value)
    local var_name = self.nextvar()
    table.insert(self.assigns, Assign(var_name, value, true))
    return Var(var_name)
end


function ExprStack:new(name)
    self.storage = Buffer()
    self.min_depth = 0
    self.max_depth = 0
    self.initial_depth = 0
end

function ExprStack:pop()
    local ok, item = self.storage:pop_check()
    if not ok then
        error(self.name.." stack underflow!")
    end
    if instanceof(item, Barrier) then
        local barrier = item
        -- TODO: finish here
        local behind_barrier = self.storage:pop_throw(self.name.." stack underflow")
        local ret
        if not instanceof(behind_barrier, Var) then
            ret = barrier:compile(behind_barrier)
        else
            ret = behind_barrier
        end
        self.storage:push(barrier)
    end

    return item
end

function ExprStack:push(value) 
    self.storage:push(value) 
    self.max_depth = math.max(self.max_depth, self.storage:size())
end

function ExprStack:peek() return self.storage:peek() end

ItStack = Stack:extend()

function ItStack:new()
    self.storage = Buffer()
end



