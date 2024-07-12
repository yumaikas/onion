local Object = require("classic")
local iter = require("iter")

local function dup(fn) 
    return function(v)
        return fn(v, v)
    end
end

local function fmt(format) 
    return function(...)
        return string.format(format, ...)
    end
end

local function record(name, super, ...) 
    local fields = {...}
    local me = super:extend()

    local code = [[local me = ({...})[1]  function me:new(]]..iter.str(fields, ", ")..[[)
]]..iter.strmap(fields, dup(fmt("    self.%s = %s")), "\n")..[[
    if self.init then self:init() end
end
function me:__tostring()
    return "]]..name..[[("..string.format("]] 
        .. iter.strmap(fields, fmt(' %s = %%s ', ", "))  
        ..  [[", ]]..iter.strmap(fields, fmt("tostring(self.%s)"), ", ") ..[[)..")"
end
]]

    assert(load(code, "rec: "..name, "t"))(me)
    return me
end

return record
