local onion_packages = {}
local onion = require("onion")

local req = {}

function req.resolve(package_name)
    return package.searchpath(package_name, "./?.fth;./?/init.fth;") 
end


return req
