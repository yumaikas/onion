local Object = require("classic")
local Buffer = require("buffer")

CompilerOutput = Object:extend()

Env = Object:extend()

function Env:new(parent)
	self.parent = parent
	self.kv = {}
end

function Env:def(name, val)
	self.kv[name] = val
end

function Env:get(key)
	local val = self.kv[key] 
	if val then return val end
	if not val and self.parent then
		pp{self.parent}
		return self.parent:get(key)
	end
	return nil
end

function Env:keys()
	local ret = {}
	local to_search = self
	while to_search ~= nil do
		for k,_ in pairs(to_search.kv) do
			table.insert(ret, k)
		end
		to_search = to_search.parent
	end
	return ret
end


function CompilerOutput:new(env, code, def_depth)
	self.env = env or Env()
	self.code = code or Buffer()
	self.def_depth = def_depth or 0
	self.needs_it = false
end

function CompilerOutput:enter() self.def_depth = self.def_depth + 1 end
function CompilerOutput:exit() self.def_depth = self.def_depth - 1 end
function CompilerOutput:compile(ast) self.code:push(ast) end
function CompilerOutput:compile_iter(iter) self.code:collect(iter) end
function CompilerOutput:pushenv() self.env = Env(self.env) end
function CompilerOutput:popenv() self.env = self.env.parent end
function CompilerOutput:def(name, val) self.env:def(name, val) end
function CompilerOutput:mark_needs_it() self.needs_it = true end
function CompilerOutput:is_toplevel() return self.def_depth == 0 end
function CompilerOutput:envget(key) 
	pp(tostring(self.env.get))
	return self.env:get(key) 
end
function CompilerOutput:envkeys() return self.env:keys() end
function CompilerOutput:derived()
	return CompilerOutput(self.env, nil, self.def_depth)
end
	