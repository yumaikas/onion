require("onion")

local tests = require("tests")

for tname, fn in pairs(tests) do
    local pass, ret = pcall(fn)
    if not pass then
        print("Test "..tname.." failed: "..tostring(ret))
        break
    else 
        io.write(".")
    end
end
print()

