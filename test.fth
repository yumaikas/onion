: even? ( a -- ? ) 2 mod 0 eq? ;
: dup2 { a b -- a b a b } a b a b ;
\ : sum ( t -- sum ) 0 { sum } each sum + { sum } for sum ;
: ?print-if-even ( n -- ) dup even? if drop else print(*) then ;
: tsum-evens ( t -- sum ) 0 { sum } each dup even? if sum + { sum } else drop then for sum ;

: square ( a -- 'a ) dup * ;
: cube ( a -- 'a ) dup dup * * ;
: abs ( a -- +a ) dup 0 < if -1 * then ;
 : abs_ { a -- a } a 0 < if a -1 * else a then ;
\ : sign { a -- -1/0/1 }
\     a 0 eq?  if 0 else a 0 > if 1 else -1 then then ;
\ \ 
\ \ 
: counter { init -- fn } 
     : ( -- v ) init 1 + { init } init ; 
  ;
\ : updown { init -- obj } 
\     init { v }
\     table { ret }
\     : ret.up ( -- v ) v 1 + { v } v ;
\     : ret.down ( -- v ) v 1 - { v } v ;
\     ret
\  ;
\ 1 updown

: xy_of_pt ( pt -- x y ) [ it .x it .y ]. ;
: xy_of_pt_1 ( pt -- x y ) [ x>> y>> ]. ;
: v2_of_xy ( x y -- t ) table [ table.insert(#*) table.insert(#*) ] ;

: /move-up ( # by -- ) y>> + >>y ;
: /bounce ( # --  ) 10 /move-up ;

1 2  v2_of_xy
: tbl-test ( -- obj )  table dup 1 swap >x ;

: add ( a b -- c ) + ;
: xy_to_pt ( x y -- pt ) table [ >>y >>x ] ;
: vaddxy { a b -- t } a .x b .x add a .y b .y add(**\*) xy_to_pt ; 
: printall ( t -- ) each print(*) for ;

: NL ( -- ) print() ;
: tsum ( t -- sum ) 0 { s } each s + { s } for s ;




