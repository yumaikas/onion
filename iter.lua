local iter = {}
function iter.each(t)
    local i = 1
    return function()
        local ret = t[i]
        i = i + 1
        return ret
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

function iter.last(t, n)
    local i = #t-n
    return function()
        local ret = t[i]
        i = i + 1
        return ret
    end
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

return iter
