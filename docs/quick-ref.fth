\ Onion Quick reference
\ Word defs
: add ( a b -- c ) + ; : 2dup { a b -- * * * * } a b a b ; : mod? (**\*) mod 0 eq? ; 

\ Words can be anonymous, and they can be nested in other words
: range-clamp { l h -- f } : (*\*) l max h min ; ; -1 1 range-clamp { 1clamp } \ nested and anonymous def
: rX (*\*) 0 swap randint ; : echo (*\) console.log(*) ; : readln (\*) io.read(\*) ;
behaves tostring (*\*) \ As a function
behaves _G @ \ Like a variable
behaves 1clap (*\*) \ We can change the default semanitics of Onion words too
\ Subject\it stack
: mov ( # dx dy  -- ) y>> + >>y x>> + >>x ;
\ Locals
0 1 2 3 { r0 r90 r180 r270 } \ TIC-80 rotation
\ Operators, literals
10 2 + 3 * 6 div 3 mod { n } 
true false and true or { can? } "foo" "bar" .. { str }
\ Assign-ops
1 += n 1 -= n 2 *= n 2 div= n 3 mod= n true or= can? false and= can? "baz" ..= str 
\ Conditionals
4 rX 2 mod? if "even!" else "odd.." then echo
\ if w/o else has to have same number of inputs and outputs
10 rX 9 >= if "Above 8!" echo then  2 rX { res } 
cond res 0 eq? -> "zero" of res 1 eq? -> "one" of true -> "High!" of end echo
\ Loops
array { nums }
nums [ 10 1 do , loop  10 20 -1 +do , loop \ counted, and step-counted loops
do? it len 30 < while "Other!" , loop ]. \ conditional
nums each echo for nums ipairs[*\_*] echo for \ iterator-style

