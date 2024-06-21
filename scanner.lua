local Object = require("classic")

Scanner = Object:extend()

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
			return null
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

function balanced(down, up)
    local depth = 1
    return function(el)
        if el == down then depth = depth + 1 end
        if el == up then depth = depth - 1 end
        return el == up and depth == 0
    end
end