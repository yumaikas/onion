: , (#*\) table.insert(#*) ;
behaves tostring (*\*) behaves type (*\*)
\ Based on Fennel's view file, tweaked for Onion 

t[ ::type_order 
    1 >>number  2 >>boolean  3 >>string 4 >>table  5 >>function 6 >>userdata 7 >>thread ].
t[ ::default_opts
    false >>one_line
    true >>detect_cycles
    false >>empty_as_sequence
    true >>metamethod
    \ false >>prefer_colon
    false >>escape_newlines 
    true >>utf8
    80 >>line_length
    128 >>depth
    10 >>max_sparse_gap
].

@pairs { lua_pairs }
@ipairs { lua_ipairs }
: metaget* { t k -- m m } t getmetatable(*\*) k get dup ;


: pairs { t -- * * } t "__pairs" metaget* { p } if t p(*\**) else t lua_pairs(*\**) then ;
: ipairs { t -- * * * } t "__ipairs" metaget* { i } if t i(*\***) else t lua_ipairs(*\***) then ;
: length* { t -- l } t "__len" metaget* { l } if t l(*\*) else t len then ;
: get-default { k -- v } 
    k default_opts get { v }
    v not if 
        k tostring "options '%s' doesn't have a default value, use the :after key to set it" 
            :format(*\*) error(*) then
    v ;

\ Get an option with respect to `:once` semantics
: getopt ( k opts -- v ) get dup .once if .once else dup drop then ;

: normalize-opts { opts -- opts } 
\ Prepare options for a nested invocation of the pretty printer
    t[ opts pairs[*\**] { k v } v type(*\*) { vt }
            it cond
                v .after -> v .after of
                vt "table" eq? v .once and -> k get-default of
                true -> v of
            end k put
        for ] ;

: sort-keys { p -- 1/0/-1 } 0 p get 1 p get { a b } 
    a type b type { ta tb }
    ta tb eq? ta "string" eq? ta "number" eq? or and if
        a b <
        else
        a type_order get b type_order get { dta dtb }
        cond
            dta dtb and -> dta dtb < of
            dta -> true of
            dtb -> false of
            true -> ta tb < of
        end
    then ;

: max-index-gap { kv -- gap } 
    0 { gap }
    kv length* 0 > if 
        0 { i } 
        kv each 1 get { k } 
            k i - gap > if k i - { gap } then
            k { i }
        for 
    then gap ;

: fill-gaps { kv -- } 
    t[ ] 0 { missing-indexes i } 
    kv each 1 get { j }
        1 += i
        do? j i > while missing-indexes [ i , ]. 1 += i loop
    for
    missing-indexes each { k } kv k t[ k , ] table.insert(***) for ;
