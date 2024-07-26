local claw = require("claw")
local atoms = require("atoms")
local pp = require("pprint")
local trace = require("trace")
local molecules = require("molecules")
local iter = require("iter")
local Object = require("classic")
local seam = require("seam")

local LuaOutput = Object:extend()

function LuaOutput:new()
    self.line_padding = 0
    self.ssa_idx = 1
    self.out = {}
end

function LuaOutput:next_ssa()
    local ret = "_"..self.ssa_idx
    self.ssa_idx = self.ssa_idx + 1
    return ret
end

function LuaOutput:indent(amt)
    self.line_padding = self.line_padding + amt
end

function LuaOutput:dedent(atm)
    self.line_padding = self.line_padding - amt
end

function LuaOutput:write(...)
    iter.push(self.out, ...)
end

function LuaOutput:pop() iter.pop(self.out) end

function LuaOutput:comment(...)
    self:write("--[[", ...)
    self:write("]]")
end

function LuaOutput:echo(val)
    if val.to_lua then
        val:to_lua(self)
    elseif type(val) == "string" then
        self:write(val)
    else
        self:comment(val, val.___name, type(val))
    end
end

function LuaOutput:echo_list(list, sep)
    for i in iter.each(list) do
        self:echo(i)
        self:write(sep)
    end
    if #list > 0 then iter.pop(self.out) end
end

function LuaOutput:write_list(list, sep)
    for i in iter.each(list) do
        self:write(i)
        self:write(sep)
    end
    if #list > 0 then iter.pop(self.out) end
end

function LuaOutput:nl()
    iter.push(self.out,"\n", string.rep(" ", self.line_padding))
end

function LuaOutput:str() return iter.str(self.out) end

function claw.body:to_lua(out)
    for node in iter.each(self) do 
        if node.no_out then
        elseif node.to_lua then
            node:to_lua(out)
            out:write(" ")
        else
            out:comment("Unsupported: ", tostring(node))
        end
    end
end

function mangle_name(n)
    n = n:gsub("[?#/\\%,!+<>=*-]", {
        ['='] = '_equal_',
        ['+'] = "_plus_", 
        ['<'] = "_lt_",
        ['*'] = "_mult_",
        ['>'] = "_gt_",
        ['!'] = "_bang_",
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

function seam.cell:to_lua(out)
    if self:get().to_lua then
        self:get():to_lua(out)
    else
        out:echo(self:get())
    end
end

function seam.lit:to_lua(out)
    out:write(self.val)
end

function seam.strlit:to_lua(out) out:write((string.format("%q", self.val):gsub("\\\\", "\\"))) end

function molecules.ref_it:to_lua(out) end
function molecules.drop_it:to_lua(out) end

function molecules.push_it:to_lua(out)
    out:echo(self.var)
end

function molecules.new_table_it:to_lua(out)
    out:write("local ") 
    out:echo(self.var)
    out:write(" = {} ")
end

function molecules.name_it:to_lua(out)
    if not self.to:get().name:find(".") then
        out:write("local ")
    end
    out:echo(self.to)
    out:write(" = ")
    out:echo(self.from)
end

function molecules.prop_set_it:to_lua(out)
    out:echo(self.obj)
    out:write(".", self.prop, " = ")
    out:echo(self.val)
end

function molecules.len:to_lua(out)
    out:write("#")
    out:echo(self.obj)
end

function molecules._not:to_lua(out)
    out:write("not ")
    out:echo(self.obj)
end

function molecules.binop:to_lua(out)
    out:write("(")
    out:echo(self.a)
    out:write(" ", self.op, " ")
    out:echo(self.b)
    out:write(")")
end

function molecules.call:to_lua(out)
    -- out:comment("call!!", #self.outputs," ", #self.inputs)
    if #self.outputs > 0 then
        out:write(" local ") 
        for o in iter.each(self.outputs) do
            out:echo(o)
            out:write(', ')
        end
        out:pop()
        out:write(" = ")
    end
    out:write(mangle_name(self.name))
    out:write("(")
    if #self.inputs > 0 then
        for i in iter.each(self.inputs) do
            -- out:comment(i)
            out:echo(i)
            out:write(", ")
        end
        out:pop()
    end
    out:write(") ")
end

function molecules.mcall:to_lua(out)
    -- out:comment("call!!", #self.outputs," ", #self.inputs)
    if #self.outputs > 0 then
        out:write(" local ") 
        for o in iter.each(self.outputs) do
            out:echo(o)
            out:write(', ')
        end
        out:pop()
        out:write(" = ")
    end
    out:echo(self.on)
    out:write(":")
    out:write(mangle_name(self.name))
    out:write("(")
    if #self.inputs > 0 then
        for i in iter.each(self.inputs) do
            out:echo(i)
            out:write(", ")
        end
        out:pop()
    end
    out:write(") ")
end

function map_it_params(v)
    if v == "#" then return "it" else return v end 
end

function params() 
    local i = 0
    return function(v) 
        if v == "#" then 
            return "it" 
        else 
            i = i + 1
            return "p"..i
        end 
    end
end

function claw.assign_many:to_lua(out)
    local new_vars = {}
    local reassigns = {}
    for i, v in ipairs(self.varnames) do
        if self.is_new[i] then
            iter.push(new_vars, {v, self.assigns[i]})
        else
            iter.push(reassigns, {v, self.assigns[i]})
        end
    end
    if #new_vars > 0 then
        out:write("local ") 
        for v in iter.each(new_vars) do 
            out:echo(mangle_name(v[1])) out:write(",")  
        end
        out:pop()
        out:write(" = ")
        for v in iter.each(new_vars) do out:echo(v[2]) out:write(", ") end
        out:pop()
    end
    if #reassigns > 0 then
        for v in iter.each(reassigns) do out:echo(mangle_name(v[1])) out:write(",")  end
        out:pop()
        out:write(" = ")
        for v in iter.each(reassigns) do out:echo(v[2]) out:write(", ") end
        out:pop()
    end
end

function claw.func:to_lua(out)
    if self.name == claw.anon_fn then
        out:write(" ")
    end
    out:write("function ")
    if self.name ~= claw.anon_fn then
        out:write(mangle_name(self.name))
    end
    out:write("(" ) 
    if not self.input_assigns then
        out:write_list(iter.map(self.inputs, params()), ", ")
    elseif self.input_assigns then
        out:write_list(iter.map(self.inputs, map_it_params), ", ")
    end
    out:write(") ")
    self.body:to_lua(out)
    if #self.seam_outputs > 0 then
        out:write(" return ")
    end
    if #self.seam_outputs > 0 then
        for so in iter.each(self.seam_outputs) do
            if so.to_lua then
                so:to_lua(out)
            else
                out:comment(so)
            end
            out:write(", ")
        end
        out:pop()
    end
    out:write(" end ")
end

function molecules.assign_op:to_lua(out)
    out:write(self.var, " = ", self.var, self.op)
    out:echo(self.value)
end

function molecules.prop_get_it:to_lua(out)
    out:echo(self.obj)
    out:write(".")
    out:write(mangle_name(self.prop))
end

function molecules.propget:to_lua(out)
    out:echo(self.obj)
    out:write(".")
    out:write(mangle_name(self.prop))
end

function molecules.propset:to_lua(out)
    out:echo(self.obj)
    out:write(".")
    out:write(mangle_name(self.prop), " = ")
    out:echo(self.val)
    out:write(" ")
end

function molecules.prop_set_it:to_lua(out)
    out:echo(self.obj)
    out:write(".")
    out:write(mangle_name(self.prop), " = ")
    out:echo(self.val)
    out:write(" ")
end


function molecules.get:to_lua(out)
    out:echo(self.obj)
    out:write("[")
    out:echo(self.key)
    out:write("]")
end

function molecules.put:to_lua(out)
    out:echo(self.obj)
    out:write("[")
    out:echo(self.key)
    out:write("]")
    out:write(" = ")
    out:echo(self.val)
end

function molecules.table_lit:to_lua(out)
    out:write("local ") 
    out:echo(self.var)
    out:write(" = {} ")
end

function claw.if_:to_lua(out)
    if #self.out_vars > 0 then 
        for idx, o in ipairs(self.out_vars) do
            out:write(" local ") out:echo(o) out:write(" = ") out:echo(self.in_vals[idx])
        end
    end
    out:write(" if ") out:echo(self.cond) out:write(" then ")
    out:echo(self.when_true)
    if #self.out_vars > 0 then 
        for idx, o in ipairs(self.out_vars) do
            out:echo(o)
            out:write(" = ")
            out:echo(self.out_vals[idx])
        end
    end
    out:write(" end ")
end

function claw.ifelse:to_lua(out) 
    if #self.out_vars > 0 then 
        out:write(" local ") 
        for idx, o in ipairs(self.out_vars) do
            out:echo(o)
            out:write(",")
        end out:pop()
    end

    out:write(" if ")
    out:echo(self.cond)
    out:write(" then ")
    out:echo(self.when_true)
    if #self.out_vars > 0 then 
        for idx, o in ipairs(self.out_vars) do
            out:echo(o) out:write(" = ") out:echo(self.t_rets[idx])
        end 
    end
    out:write(" else ")
    out:echo(self.when_false)
    if #self.out_vars > 0 then 
        for idx, o in ipairs(self.out_vars) do
            out:echo(o) out:write(" = ") out:echo(self.f_rets[idx])
            out:write(" ")
        end 
    end
    out:write(" end ")
end

function claw.each_loop:to_lua(out)
    -- out:comment("each_loop")
    -- out:comment(pp.pformat(self))
    out:write(" for _, ")
    out:echo(self.loop_var)
    out:write(" in ipairs(")
    out:echo(self.in_var)
    out:write(") do ")
    self.body:to_lua(out)
    out:write(" end ")
end

function claw.iter:to_lua(out)
    assert(#self.loop_vars > 0, "invalid loop_vars!")

    out:write(" for ")
    out:echo_list(self.loop_vars, ",")
    out:write(" in ")
    if #self.word > 0 then out:write(self.word, "(") end
    out:echo_list(self.input_cells, ",")
    if #self.word > 0 then out:write(")") end
    out:write(" do ")
    out:echo(self.body)
    out:write(" end ")
end

function claw.do_loop:to_lua(out)
    out:write(" for ")
    out:echo(self.var)
    out:write(" = ")
    out:echo(self.from)
    out:write(",")
    out:echo(self.to)
    out:write(" do ")
    out:echo(self.body)
    out:write(" end ")
end

function claw.do_step_loop:to_lua(out)
    out:write(" for ")
    out:echo(self.var)
    out:write(" = ")
    out:echo(self.from)
    out:write(",")
    out:echo(self.to)
    out:write(",")
    out:echo(self.step)
    out:write(" do ")
    out:echo(self.body)
    out:write(" end ")
end

function claw.do_while_loop:to_lua(out)
    out:write(" while ")
    out:echo(self.cond_val)
    out:write(" do ")
    out:echo(self.body)
    out:write(" end ")
end

function claw.cond:to_lua(out)
    local first = true
    if #self.out_vars > 0 then
        out:write(" local ")
        for ov in iter.each(self.out_vars) do
            out:echo(ov)
        end
    end
    for c in iter.each(self.clauses) do
        if first then out:write(" if ") first = false else
            out:write(" elseif ")
        end
        if c.pre then out:echo(c.pre) end
        out:echo(c.pred.cond_expr)
        out:write(" then ")
        out:echo(c.body)
        for idx, ov in ipairs(c.out_vars) do
            out:echo(self.out_vars[idx])
            out:write(" = ")
            out:echo(ov)
            out:write(" ")
        end
        if c.post then out:echo(c.post) end
    end
    out:echo(" end ")
end

function seam.var:to_lua(out) 
    out:write(mangle_name(self.name))
end

function atoms.number:to_lua(out)
    out:write(self.val)
end

function atoms.lit:to_lua(out)
    out:write(self.val)
end

function atoms.var:to_lua(out)
    out:write(mangle_name(self.name))
end

function seam.var:to_lua(out)
    out:write(mangle_name(self.name))
end

function seam.ssa_var:to_lua(out)
    if not self.varname then
        self.varname = out:next_ssa()
    end
    out:write(self.varname)
end

function seam.ssa_assign:to_lua(out)
    if not self.varname then
        self.varname = out:next_ssa()
        out:write(" local ", self.varname, " = ") 
        out:echo(self.to)
        out:write(" ")
    else
        out:write(self.varname)
    end
end

function atoms.whitespace:to_lua(out) out:write(self.ws) end
function claw.whitespace:to_lua(out) out:write(self.ws) end

return LuaOutput
