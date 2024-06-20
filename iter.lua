local iter = {}
function iter.each(t)
    local i = 1
    return function()
        local ret = t[i]
        i = i + 1
        return ret
    end
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


return iter
