local onion = require ("onion.scratch")

function repl() 
    local _repl = onion.repl()
    while _repl.should_continue() do
        io.write("> ")
        local to_exec = io.read("l")
        local ok, ret = pcall(_repl.eval, to_exec)
        if ok then
            print(table.unpack(ret, 1, ret.n))
        else
            print("Error: "..tostring(ret)) 
        end
    end
end

function eval_line(line) 
    local _repl = onion.repl()
    local ok, ret = pcall(_repl.eval, line)
    if ok then
        print(table.unpack(ret, 1, ret.n))
    else
        print("Error: "..tostring(ret)) 
    end
end


function main()
    -- print(io)

    local argIdx = 1
    while argIdx <= #arg do
        if arg[argIdx] == "--lex" then
            local f = io.open(arg[argIdx + 1], "r")
            local str = f:read("*a")
            local toks = lex(str)
            for i,t in ipairs(toks) do
                io.write("["..t .. "] ")
            end
            print()
            argIdx = argIdx + 2
        elseif arg[argIdx] == "-e" or arg[argIdx] == "--eval" then
            argIdx = argIdx + 2
        elseif arg[argIdx] == "--exec" then
            local f = io.open(arg[argIdx + 1], "r")
            local str = f:read("*a") f:close()
            local code = onion.exec(str)
            argIdx = argIdx + 2
        elseif arg[argIdx] == "--compile" then
            local f = io.open(arg[argIdx + 1], "r")
            local str = f:read("*a")
            local code = onion.compile(str)
            local out_f = io.open(arg[argIdx + 2], "w")
            out_f:write(code)
            f:close()
            out_f:close()
            argIdx = argIdx + 3
        elseif arg[argIdx] == "--comptest" then
            for i=1,4 do
                print(string.rep("*", 30) )
            end
            print()
            local f = io.open(arg[argIdx + 1], "r")
            local str = f:read("*a")
            print(onion.compile(str))
            f:close()
            argIdx = argIdx + 2
            print() print()
        elseif arg[argIdx] == "--repl" then
            repl()
        else
            error("Unrecognized arg: " .. arg[argIdx])
        end
    end
end

main()
