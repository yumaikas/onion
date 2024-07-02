local Object = require("classic")
local Buffer = require("buffer")
require("ast")
require("stack")

CompilerOutput = Object:extend()

Env = Object:extend()

function Env:new(parent)
	self.parent = parent
	self.kv = {}
end

function Env:def(name, val)
	self.kv[name] = val
end

function Env:defn(name, val)
	self.parent.kv[name] = val
end

function Env:getlocal(key) 
    return self.kv[key]
end

function Env:get(key)
	local val = self.kv[key] 
	if val then return val end
	if not val and self.parent then
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
	self.code = code or Block()
	self.def_depth = def_depth or 0
	self.needs_it = false
end

function CompilerOutput:enter() 
	print("comp-in")
	self.def_depth = self.def_depth + 1 end
function CompilerOutput:exit() 
	print("comp-out")
	self.def_depth = self.def_depth - 1 end
function CompilerOutput:compile(ast) self.code:compile(ast) end
--[[
: CompilerOutput:compiler_iter { # i -- } for i dup nip do * #compile(*) each ;
]] 
function CompilerOutput:compile_iter(iter) for c in iter do self.code:compile(c) end end

function CompilerOutput:pushenv() self.env = Env(self.env) end
function CompilerOutput:popenv() self.env = self.env.parent end
function CompilerOutput:def(name, val) self.env:def(name, val) end
function CompilerOutput:defn(name, val) self.env:defn(name, val) end
function CompilerOutput:mark_needs_it() self.needs_it = true end
function CompilerOutput:is_toplevel() return not self.env.parent end
function CompilerOutput:envgetlocal(key)
	return self.env:getlocal(key) 
end
function CompilerOutput:envget(key) 
	return self.env:get(key) 
end
function CompilerOutput:envkeys() return self.env:keys() end
function CompilerOutput:derived()
	return CompilerOutput(self.env, nil, self.def_depth)
end
	
