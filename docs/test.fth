: dX (*\*) 1 swap randint ;
4 dX { r }
1
cond 
    \ For now, the predicate/condition clause can't take any inputs
    \ and must only output one value. 
    r 1 eq? -> "one" .. of
    \ Meanwhile, every guarded clause needs to have the same stack effect, but can have 
    r 2 eq? -> "two" .. of
    r 3 eq? -> "three" .. of
    r 4 eq? -> "four" .. of
    \ TODO: Enforce a default clause if any clauses have outputs?
    true -> "other" ..  of
end print

table { t }
t 1 >a 
t .a print
"b" { k }
t k 2 put \ Use a variable as a key into a table
