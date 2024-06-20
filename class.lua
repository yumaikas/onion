local function class(cls) 
    local mt = {__index = cls}
    return function(obj) 
        setmetatable(obj, mt)
        return obj 
    end 
end

return class
