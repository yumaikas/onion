local Object = require "classic"

local Effect = Object:extend()

function Effect:__tostring()
    return "[ " .. table.concat(self.in_eff, " ") .. " -- " .. table.concat(self.out_eff, " ") .. " ]"
end

local function mouse_notation(i,o)
	return string.format("%s\\%s", string.rep("*", i), string.rep("*", o))
end

function Effect:new(in_eff, out_eff)
    self.in_eff  = in_eff
    self.out_eff = out_eff
end

function Effect:add_in(name)
	table.insert(self.in_eff, name)
end

function Effect:add_out(name)
	table.insert(self.out_eff, name)
end

function Effect:assert_match(other)
	if #self.in_eff == #other.in_eff and #self.out_eff == #other.out_eff then
	else
		error(string.format("Stack Effect Mismatch %s %s", self, other))
	end
end

function Effect:assert_balanced()
	return (#self.in_eff == #self.out_eff) or error("Unbalanced stack effect!")
end

function Effect:assert_matches_depths(i, o, fn)
	return (#self.in_eff == i and #self.out_eff == o) 
	or error(
		string.format("Stack effect mismatch in %s! expected %s, got %s", 
		fn, mouse_notation(i, o), self))
end

function Effect:__concat(other)
    local out_height = #self.out_eff
    local in_height = #other.in_eff
    local flow = out_height - in_height
    if flow < 0 then
        local needed = {}
        for i=1,math.abs(flow) do
            needed[i] = other.in_eff[i]
        end
        for i=1,#self.in_eff do
            needed[#needed+1] = self.in_eff[i]
        end
        return Effect(needed, other.out_eff)
    elseif flow > 0 then
        local leaves = {}
        for i=1,math.abs(flow) do
            leaves[#leaves+1] = self.out_eff[i]
        end
        for i=1,#other.out_eff do
            leaves[#leaves+1] = other.out_eff[i]
        end
        return Effect(self.in_eff, leaves)
    else
        return Effect(self.in_eff, other.out_eff)
    end
end

return Effect
