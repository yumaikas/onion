local Object = require("classic")
local Buffer = require("buffer")
local pprint = require("pprint")
local iter = require("iter")
local pfmt = pprint.pformat

local s = tostring

Ast = Object:extend()

function Ast:__tostring() return "AST" end

Block = Ast:extend()

function Block:new()
    self.storage = Buffer()
end

function Block:__tostring()
    return "Block(".. iter.str(self:items(), "\n")..")"
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
    return "Var("..self.var..")"
end

Box = Ast:extend()

function Box:new(val) self.holding=val end
function Box:set(to) self.holding=to end
function Box:get() 
    if instanceof(self.holding, Box) then
        return self.holding:get()
    else
        return self.holding
    end
 end

function Box:__tostring()
    return string.format("Box(%s)",self.holding)
end

Input = Box:extend()



Assign = Ast:extend()

function Assign:new(target, value, new)
    -- self.dbg = debug.getinfo(3)
    self.assign=target
    self.value=value
    self.new = new or false
end

function Assign:__tostring()
    if self.new then
        return "AssignNew("..s(self.value).." to "..s(self.assign)..")"
    else
        return "Assign("..s(self.value).." to "..s(self.assign)..")"
    end
end

Barelit = Ast:extend()

function Barelit:new(to_print) self.barelit = to_print end
function Barelit:__tostring()
    return "Barelit("..s(self.barelit)..")"
end

Strlit = Ast:extend()

function Strlit:new(str) self.strlit = str end
function Strlit:__tostring()
    return "Strlit("..s(self.strlit)..")"
end

Op = Ast:extend()

function Op:new(op, a, b)
    self.op = op
    self.a = a
    self.b = b
end
function Op:__tostring()
    return "Op("..s(self.op).." "..s(self.a).." "..s(self.b)..")"
end

UnaryOp = Ast:extend()

function UnaryOp:new(op, a, b)
    self.op = op
    self.a = a
end

function UnaryOp:__tostring()
    return "UnaryOp("..s(self.op).." "..s(self.a)..")"
end

Declare = Ast:extend()

function Declare:new()
    self.decl = {}
end
function Declare:__tostring()
    return "Declare("..iter.str(self.decl, ", ")..")"
end
function Declare:add(name)
    iter.push(self.decl, name)
    return self
end

If = Ast:extend()

function If:new(cond, when_true, when_false)
    self.cond = cond
    self.when_true = when_true or error("If AST node needs when_true")
    self.when_false = when_false or nil
end
function If:__tostring()
    if self.when_false then
        return "If("..s(self.cond).." then: "..s(self.when_true)
            .." else: "..s(self.when_false)..")"
    else
        return "If("..s(self.cond).." then: "..s(self.when_true)..")"
    end
end

AnonFnName = Ast:extend()
function AnonFnName:__tostring()
    return "AnonFn"
end

Fn = Ast:extend()

function Fn:new(name, body, inputs, outputs)
    self.fn = name
    self.actual = mangle_name(name)
    self.body = body or Block()
    self.inputs = inputs or {}
    self.stackvars = {}
    self.outputs = outputs or {}
end

function Fn:__tostring()
    return string.format("Fn(name:%s\n actual %s\n, body: %s\n, inputs: %s\n, stackvars:%s\n outputs: %s\n)",
        self.fn, self.actual, self.body, 
        iter.str(self.inputs, ", "), 
        iter.str(self.stackvars, ", "), 
        iter.str(self.outputs, ", ")
    )
end

Return = Ast:extend()
function Return:new() self.ret = Block() end
function Return:push(item) self.ret:compile(item) end
function Return:__tostring()
    return "Return("..iter.str(self.ret:items(), ", ")..")"
end

Call = Ast:extend()

function Call:new(name, args, returns, needs_it)
    self.call = name
    self.args = args or {}
    self.rets = returns or {}
    self.needs_it = needs_it or false
end

function Call:__tostring()
    if needs_it then
        return "Call(args("..iter.str(self.args, ", ").."), rets("..iter.str(self.rets, ", ").."))"
    else
        return "CallWithIt(args("..iter.str(self.args, ", ").."), rets("..iter.str(self.rets, ", ").."))"
    end
end

PropSet = Ast:extend()

function PropSet:new(prop_name, on, to)
    self.prop_set = prop_name
    self.on = on
    self.to = to
end
function PropSet:__tostring()
    return string.format("PropSet(%s, on: %s, to: %s)", self.prop_set, self.on, self.to)
end

PropGet = Ast:extend()

function PropGet:new(on, prop) 
    self.value = on
    self.prop_get = prop
end
function PropGet:__tostring()
    return string.format("PropGet(%s, on: %s)", self.prop_set, self.value)
end

MethodGet = Ast:extend()

function MethodGet:new(on, name)
    self.on = on
    self.name = name
end

function MethodGet:__tostring()
    return string.format("MethodGet(%s, on: %s)", self.on, self.name)
end


IdxGet = Ast:extend()

function IdxGet:new(on, idx)
    self.on = on
    self.idx = idx
end

function IdxGet:__tostring()
    return string.format("IdxGet(%s, on: %s)", self.idx, self.on)
end

IdxSet = Ast:extend()

function IdxSet:new(on, idx, to)
    self.on = on
    self.idx = idx
    self.to = to
end

function IdxSet:__tostring()
    return string.format("IdxSet(at: %s, on: %s, to: %s)", 
        self.idx,
        self.on,
        self.to
    )
end

For = Ast:extend()

function For:new()
    self.for_iter = {}
    self.var_expr = {}
    self.body = {}
end
function For:__tostring()
    return string.format("For(%s in %s do %s )",
        tostring(iter.str(self.var_expr, ", ")),
        tostring(iter.str(self.for_iter, ", ")),
        tostring(self.body)
    )
end

Each = Ast:extend()

function Each:new(input, itervar, body)
    self.input = input
    self.itervar = itervar
    self.body = body
end

function Each:__tostring()
    return string.format("Each(%s in %s do %s)",
        self.itervar,
        self.input,
        self.body
    )
end

DoRange = Ast:extend()

function DoRange:new(from, to, var, body)
    self.from = from
    self.to = to
    self.loop_var = var
    self.body = body or Block()
end

function DoRange:__tostring()
    return string.format("DoRange(%s,%s do %s)",
        self.from,
        self.to,
        self.body
    )
end

DoRangeStep = Ast:extend()

function DoRangeStep:new(from, to, step, var, body)
    self.from = from
    self.to = to
    self.step = step
    self.loop_var = var
    self.body = body or Block()
end

function DoRangeStep:__tostring()
    return string.format("DoRange(%s,%s,%s do %s)",
        self.from,
        self.to,
        self.step,
        self.body
    )
end

Iter = Ast:extend()

function Iter:new(word, inputs, loop_vars, body)
    self.word = word
    self.inputs = inputs or {}
    self.loop_vars = loop_vars or {}
    self.body = body or {}
end

function Iter:__tostring()
    return string.format("Iter(%s in %s(%s) do %s)",
        iter.str(self.loop_vars, ", "),
        self.word,
        iter.str(self.inputs, ", "),
        self.body
    )
end

function mangle_name(n)
    n = n:gsub("[?#/\\-%,]", {
        [','] = "_comma_",
        ['#'] = "_hash_",
        ['/'] = "_slash_",
        ['\\'] = '_backslash_',
        ['?'] = '_question_',
        ['-'] = '_'
    })
    if n:find("^[^_a-zA-Z]") then
        n = "__" .. n
    end
    return n
end

function handle_escapes(s)
    return s:gsub("\\([tnr])", {t="\t",n="\n",r="\r"})
end

