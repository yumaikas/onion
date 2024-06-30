local iter = require("iter")
require("stack")

local test = {}

function test.that_stack_infers_correctly()
	local st = ExprStack("test expr", "test it")

	st:push(".")
	st:push(".")
	st:reset_effect()
	st:pop()
	st:pop()
	st:push("a")
	st:push("b")

	print(format_effect(st:infer_effect()))
	print(table.concat(st.record))

end

for n, fn in pairs(test) do
	fn()
end
