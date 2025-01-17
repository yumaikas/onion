behaves require (*\*)
: , (#*\) table.insert(#*) ;
: ]s (#\*) table.concat(#\*) ;
"classic" require { Object }
"eff" require { eff }
behaves tostring (*\*) 
behaves Object:extend (\*) 

: str (*\*) tostring(*\*) ;
: atom { name -- cls } Object:extend [ ::cls
    name >>_name
    t[ ] >>slots
    :: __tostring (#\*) ::me t[ name>> , "{ " , slots>> each [ it , "=" , me it get , ]. for  " }" , ]s ;
] ;

: slot ( # name -- ) slots>> [ , ]. ;
t[ ] { atoms }
: e ( # i o -- ) eff.n(**\*) >>eff ;

"var" atom [ ::atoms.var "name" slot :: new (#*\) >>name 0 1 e ; :: __tostring (#\*) "$[" name>> tostring .. "]" .. ; ].
"number" atom [ ::atoms.number :: new (#*\) >>val 0 1 e ; "val" slot ].
"lit" atom  [ ::atoms.lit :: new (#*\) >>val 0 1 e ; "val" slot ].
"string" atom [ ::atoms.string :: new (#*\) >>val 0 1 e ; "val" slot ].
"bool" atom [ ::atoms.bool :: new (#*\) >>val 0 1 e ; "val" slot ].
"whitespace" atom [ ::atoms.whitespace :: new (#*\) >>ws 0 1 e ; "val" slot
    :: _tostring (#\*) t[ "ws(" , "[\\r\\n]" t[ it "\\r" "\\\\r" put it "\\n" "\\\\n" put ] ws>> :gsub(**\*) , ")" , ]s ;
].
"assign_op" atom [ ::atoms.var :: new (#*\) >>op 1 1 e ; "op" slot ].

behaves atoms.var (*\*)
behaves atoms.number (*\*)
behaves atoms.lit (*\*)
behaves atoms.string (*\*)
behaves atoms.bool (*\*)
behaves atoms.whitespace (*\*)
behaves atoms.assign_op (*\*)
