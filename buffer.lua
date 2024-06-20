local Object = require("classic")
local iter = require("iter")

local EmptyBuffer = Object:extend()

function EmptyBuffer:__tostring()
    return "[EmptyBuffer]"
end

local Buffer = Object:extend()

Buffer.EOS = EmptyBuffer()

function Buffer:new(items)
    self.items = items or {}
end

function Buffer.from(...)
    return Buffer({...})
end

function Buffer:push(val) table.insert(self.items, val) return self end
function Buffer:peek() return self.items[#self.items] end
function Buffer:each() return iter.each(self.items) end
function Buffer:concat(sep) table.concat(self.items, sep) return end
function Buffer:str() return self:concat("") end
function Buffer:size() return #self.items end
function Buffer:empty() return self:size() == 0 end
function Buffer:pop_status() 
    if #self.items == 0 then
        return false, nil
    else
        return true, table.remove(self.items)
    end
end

function Buffer:items() return self.items end

function Buffer:pop_throw(msg) 
    local ok, item = self:pop_status()
    if not ok then
        error(msg)
    else
        return item
    end
end

function Buffer:collect(iter)
    for el in iter do
        self:push(el)
    end
    return self
end

function Buffer:last(n)
    return iter.last(self.items, n)
end

function Buffer:copy()
    return Buffer():collect(self:each())
end


return Buffer

