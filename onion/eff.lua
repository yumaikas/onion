local iter = require("iter")
local Effect = require("effects")

local function eff(i, o) return Effect(i, o) end

local mod = {}
function mod.n(n_i, n_o) return Effect(iter.rep('*', n_i), iter.rep('*', n_o)) end
local meta = { __call = eff }
setmetatable(mod, meta)

return mod
