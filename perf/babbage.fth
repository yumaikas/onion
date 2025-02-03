
: babbage (\*)
    1 { n }
    do? 
        n n * 1000000 mod
            269696 neq?
    while
        1 += n
    loop n ;


os.clock(\*)
500 1 do { i } 
    babbage drop
loop
os.clock(\*)
swap - print(*)
babbage print(*)
