behaves require (*\*)

"resolve" require .Env { Env }
"atoms" require { atoms } behaves atoms.assign_op (*\*) behaves atoms.bool (*\*) 
"iter" require .w { w } behaves w (*\*)
"molecules" require { molecules } 
behaves molecules.binop (*\*) 
behaves molecules.shuffle (***\*)

: makeBaseEnv ( -- env )
    Env(\*) { baseEnv }
    : based (**\) baseEnv :put(**) ;
    : ren-op { k v -- } k : ( -- * ) v molecules.binop ; based ;
    : op ( k -- ) dup ren-op ;

    "+" op "-" op "*" op ">" op "<" op ".." op "or" op "and" op "<=" op ">=" op
    "div" "/" ren-op "idiv" "//" ren-op "mod" "%" ren-op "eq?" "==" ren-op "neq?" "~=" ren-op

    : =op { k v -- } k : ( -- * ) v atoms.assign_op ; based ;
    "+=" "+" =op "-=" "-" =op "or=" "or" =op "and=" "and" =op "*=" "*" =op "div=" "/" =op "..=" ".." =op

    : shuf { k in out -- } baseEnv k k in w out w molecules.shuffle put ; 
    "dup" "a" "a a" shuf "swap" "a b" "b a" shuf "nip" "a b" "b" shuf "drop" "a" "" shuf
    "true" true atoms.bool based "false" false atoms.bool based

    : ctor { k fn -- } k : (\*) fn(\*) ; based ;
    "table" @molecules.table_lit ctor "get" @molecules.get ctor "put" @molecules.put ctor
    "len" @molecules.len ctor "not" @molecules._not ctor
    "t[" @molecules.new_table_it ctor "[" @molecules.push_it ctor "]" @molecules.pop_it ctor 
    "]." @molecules.drop_it ctor "it" @molecules.ref_it ctor

    baseEnv
;
