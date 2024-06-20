
function tsum(p1) 
    local __s1=0 
    local __s2, __s3, __s4 = ipairs(p1) 
    for _, __s5 in __s2, __s3, __s4 do
        __s1=(__s1+__s5) 
    end 
    return __s1 
end

print("TSUM: ",tsum({1,2,3}))
