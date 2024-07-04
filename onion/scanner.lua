local Object = require("classic")
local pprint = require("pprint")

Scanner = Object:extend()

function matcher(of)
	if type(of) == "function" then
        return of
	else
	    return function(el) return el == of end
	end
end

function Scanner:new(t, idx)
	self.subject = t
	self.idx = idx

	if type(self.subject) == "string" then
		self._fetch = function(s, idx) return s:sub(idx,idx) end
	else
		self._fetch = function(tbl, idx) return tbl[idx] end
	end
end

function Scanner:go_next() self.idx = self.idx + 1 end
function Scanner:at() return self._fetch(self.subject, self.idx) end


function Scanner:upto(target)
	local pred
	if type(target) == "function" then
		pred = target
	else
		pred = function(el) return el == target end
	end

	return function() 
		if not pred(self:at()) and self.idx <= #(self.subject) then
			local ret = self:at()
			self:go_next()
			return ret
		else
			if self.idx > #self.subject then
				print(debug.getinfo(2).currentline)
				error(pprint.pformat(target).." not found!")
			end
			self:go_next()
			return nil
		end
	end
end

function Scanner:rest()
	return function()
		if self.idx <= #self.subject then
			local ret = self:at()
			self:go_next()
			return ret
		else
			return nil
		end
	end
end

function any_of(...)
    local options = {...}
    for i, v in ipairs(options) do
        options[i] = matcher(v)
    end

    return function(el)
        for _, pred in ipairs(options) do
            if pred(el) then
                return true
            end
        end
        return false
    end
end

function balanced(down, up)
    local is_down = matcher(down)
    local is_up = matcher(up)
    local depth = 1
    return function(el)
        if is_down(el)  then depth = depth + 1 end
        if is_up(el) then depth = depth - 1 end
        return is_up(el) and depth == 0
    end
end
