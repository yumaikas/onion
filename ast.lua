local Object = require("classic")
local Buffer = require("buffer")
local pprint = require("pprint")
local pfmt = pprint.pformat

Ast = Object:extend()

function Ast:__tostring() return "AST" end

Block = Ast:extend()

function Block:new()
    self.storage = Buffer()
end

function Block:__tostring()
    local res = {"Block:"}
    for n in self.storage:each() do
        table.insert(res, tostring(n))
    end
    return table.concat(res," ")

 end

function Block:compile(node)
    if not instanceof(node, Ast) then
        error("Unsupported node: "..pfmt(node))
    else
        self.storage:push(node)
    end
end

function Block:items()
    return self.storage.items
end

function Block:each()
    return self.storage:each()
end


Var = Ast:extend()

function Var:new(name)
    self.var = name
end

function Var:__tostring()
    return "Var: "..self.var
end

Assign = Ast:extend()

function Assign:new(target, value, new)
    -- self.dbg = debug.getinfo(3)
    self.assign=target
    self.value=value
    self.new = new or false
end

Barelit = Ast:extend()

function Barelit:new(to_print) self.barelit = to_print end

Strlit = Ast:extend()

function Strlit:new(str) self.strlit = str end

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
    return self
end

If = Ast:extend()

function If:new(cond, when_true, when_false)
    self.cond = cond
    self.when_true = when_true or error("If AST node needs when_true")
    self.when_false = when_false or nil
end

AnonFnName = Ast:extend()

Fn = Ast:extend()

function Fn:new(name, body, inputs, outputs)
    self.fn = name
    self.actual = mangle_name(name)
    self.body = body or Block()
    self.inputs = inputs or {}
    self.outputs = outputs or {}
end

function Fn:__tostring()
    return string.format("[Fn: %s, actual %s, body: %s, inputs: %s, outputs: %s]",
        self.fn, self.actual, self.body, self.inputs, self.outputs
    )
end

Return = Ast:extend()

function Return:new()
    self.ret = Block()
end

function Return:push(item)
    self.ret:compile(item)
end
Call = Ast:extend()

function Call:new(name, args, returns, needs_it)
    self.call = name
    self.args = args or {}
    self.rets = returns or {}
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

function For:new()
    self.for_iter = {}
    self.var_expr = {}
    self.body = {}
end


function For:add_iter_var(v)
    table.insert(self.for_iter, v)
end

function mangle_name(n)
    n = n:gsub("[?#/\\-]", {
        ['#'] = "_hash_",
        ['/'] = "_slash_",
        ['\\'] = '_backslash_',
        ['?'] = '_question_',
        ['-'] = '_',
    })
    if n:find("^[^_a-zA-Z]") then
        n = "__" .. n
    end
    return n
end

function handle_escapes(s)
    return s:gsub("\\([tnr])", {t="\t",n="\n",r="\r"})
end

