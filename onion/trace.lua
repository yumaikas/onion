local seam = require("seam") -- TODO pull seam's stack out into it's own module
local pp = require("pprint")
local iter = require("iter")

local log = seam.stack:extend()

function log:init() 
    self.enabled = false
end

function log:__call(...)
    if not self.enabled then return end
    -- local db_inf = debug.getinfo(2)
    -- print(self:peek(), db_inf.source..":"..db_inf.currentline, ...)
    print(self:peek(), ...) 
end

function log:enable() self.enabled = true end
function log:disable() self.enabled = false end

function log:error(msg)
    error("Error "..msg.." in: \n"..iter.str(iter.reverse(self._items), "\n\t")) 
end

function log:pp(...)
    if not self.enabled then return end
    -- pp(self.push)
    print(self:peek(), pp.pformat(...))
end

local l = log("Function Context")

return l 

