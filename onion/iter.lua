local Object = require("classic")
local iter = {}

local Table = Object:extend()

function Table.__add(t, v)
    table.insert(t, v)
    return t
end

function iter.t()
    return Table()
end

function iter.w(items) return iter.collect(items:gmatch("%S+")) end

function iter.f(code)
    local lua = ("let iter = require('iter') -> @ "..code.." ;")
    :gsub("->", "return")
    :gsub("let", "local")
    :gsub("@", "function")
    :gsub(";", "end")
    :gsub("([%w%.]+)([+-/%*])=([%w%.]+)", "%1 = %1 %2 %3")
    :gsub("([%w%.]+):|([%w%.]+)", "%1 = %1 or %2")
    :gsub("([%w%.]+):&([%w%.]+)", "%1 = %1 and %2")

    local val, msg = load(lua)
    if not val then print(lua) end
    return assert(val, msg)()
end

function iter.getter(prop) return iter.f("(s) -> s."..prop) end

function iter.each(t)
    if t.__each then return t:__each() end

    local i = 1
    return function()
        local ret = t[i]
        i = i + 1
        return ret
    end
end

function iter.pairwise(t)
    local i = 1

    if #t % 2 ~= 0 then
        error("Cannot loop pairwise over uneven table")
    end

    return function()
        if i > #t then
            return nil
        else
            local ra, rb = t[i], t[i+1]
            i = i + 2
            return ra, rb
        end
    end

end

function iter.reverse(tab) 
    for i = 1, #tab//2, 1 do
        tab[i], tab[#tab-i+1] = tab[#tab-i+1], tab[i]
    end
    return tab
end

function iter.backwards(t)
    local ret = iter.copy(t)
    iter.reverse(t)
    return iter.each(t)
end

function iter.copy(t)
    return iter.collect(iter.each(t))
end

function iter.back(t) return t[#t] end

function iter.last(t, n)
    local i = #t-n
    return function()
        local ret = t[i]
        i = i + 1
        return ret
    end
end

function iter.chars(str)
    return iter.collect(str:gmatch("."))
end


function iter.collect(iter)
    local ret = {}
    for el in iter do
        table.insert(ret, el)
    end
    return ret
end

function iter.into(t)
    local obj = {}
    function obj:collect(iter)
        for el in iter do
            table.insert(t, el)
        end
        return t
    end
    return obj
end

function iter.of_keys(t, ...)
    pp({t, ...})
    local ret = {}
    for k in iter.each({...}) do
        ret[k] = t[k]
    end
    return ret
end

function iter.has_value(t, v)
    for _, iv in ipairs(t) do
        if iv == v then return true end
    end
    return false
end

function iter.map(t, fn)
    local ret = {}
    for el in iter.each(t) do
        ret[#ret+1] = fn(el)
    end
    return ret
end

function iter.str(t, sep)
    return table.concat(iter.map(t, tostring), sep or "")
end

local function compn(...)
    local fns = {...}
    return function(...)
        local args = {...}
        for _,f in ipairs(fns) do
            args = table.pack(f(table.unpack(args)))
        end
        return table.unpack(args)
    end
end

local function comp(a, b)
    return function(...)
        return b(a(...))
    end
end

function iter.strmap(t, fn, sep)
    return table.concat(iter.map(t, comp(fn, tostring)), sep or "")
end

function iter.push(t, ...)
    for i in iter.each({...}) do
        t[#t+1] = i
    end
end

function iter.pop(t)
    return table.remove(t)
end

function iter.from_back(t, i)
    return #t - (i - 1)
end

function iter.filter(t, pred)
    local ret = {}
    for v in iter.each(t) do
        if pred(v) then
            ret[#ret+1] = v
        end
    end
    return ret
end

function iter.find(t, pred)
    for v in iter.each(t) do
        if pred(v) then return v end
    end
    return nil
end

function iter.split(t, on) 
    local ret = {{}}
    for v in iter.each(t) do
        if v == on then 
            iter.push(ret, {}) 
        else
            iter.push(ret[#ret], v)
        end
    end
    return ret
end

function iter.rep(el, n)
    local ret = {}
    for i=1,n do
        iter.push(ret, el)
    end
    return ret
end


return iter
