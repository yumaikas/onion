local Object = require("classic")

local Ast = Object:extend()

Var = Ast:extend()

function Var:new(name)
    self.var = name
end

Assign = Ast:extend()

function Assign:new(target, value, new)
    self.assign=target
    self.value=value
    self.new = new or false
end

Barelit = Ast:extend()

function Barelit:new(to_print)
    self.barelit = to_print
end

Op = Ast:extend()

function Op:new(op, a, b)
    self.op = op
    self.a = a
    self.b = b
end

Declare = Ast:extend()

function Declare:new()
    self.decl = {}
end

function Declare:add(name)
    table.insert(self.decl, name)
end

If = Ast:extend()

function If:new(cond, when_true, when_false)
    self.cond = cond
    self.when_true = when_true or error("If AST node needs when_true")
    self.when_false = when_false or {}
end

AnonFnName = Ast:extend()

Fn = Ast:extend()

function Fn:new(name, body, inputs, outputs)
    self.fn = name
    self.body = body or {}
    self.input = inputs or {}
    self.outputs = outputs or {}
end

Call = Ast:extend()

function Call:new(name, args, returns, needs_it)
    self.name = name
    self.args = args or {}
    self.rets = returns or returns
    self.needs_it = needs_it or false
end

PropSet = Ast:extend()

function PropSet:new(prop_name, on, to)
    self.prop_set = prop_name
    self.on = on
    self.to = to
end

PropGet = Ast:extend()

function PropGet:new(on, prop) 
    self.value = on
    self.prop_get = prop
end

For = Ast:extend()

