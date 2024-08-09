local Space = require("lspace")
local enemies = {}
local r, f, l, box, tuples, rules = Space()

local function p(...)
    local args = {...}
    return function() print(table.unpack(args)) end
end

function espawn(vars) 
    print("Spawning "..vars.enemy.." at "..vars.x..", "..vars.y)
    table.insert(enemies, {t=vars.enemy, x=vars.x,y=vars.y})
end

f('play level 1')
r('play level 1').so(
    p"Started Level 1!",
    'spawn a flyer at 60 10', 
    'spawn a flyer at 60 20',
    'spawn a flyer at 60 30',
    'playing level 1'
)
r('spawn a $enemy at $x $y').so(espawn)
r('spawn an $enemy at $x $y').so(espawn)
r('playing level 1', 'all enemies are dead').so(p'LEVEL 2', 'play level 2')
r('there are $some enemies').so(
    function(v) 
        -- print("some", v.some, type(v.some)) 
        if v.some == "0" then f('all enemies are dead') end 
    end
    )
r('an enemy died').so(
    function(_) print('ded') f('there are '.. #enemies..' enemies') end
)

r('a','b','c').so(p'a,b&c')
f('a')
f('b')
f('letters '..l('a', 'b', 'c'))
f('c')
r('a', 'b').so(p'a&b',"a and b")
r('MYVARR $vals').so(function(vars) print(table.unpack(vars.vals)) end)
box('MYVARR', {1,2,3,4})

print("***************************")
for _, t in ipairs(tuples) do
    print(t, table.unpack(t))
end

print("***************************")
function kill() 
    table.remove(enemies, 1)
    f('an enemy died')
end

kill()
kill()
kill()

print("***************************")

for _, t in ipairs(tuples) do
    print(table.unpack(t))
end
