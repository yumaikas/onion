: even? ( a -- ? ) 2 mod 0 eq? ;
: tsum-evens ( t -- sum ) 0 swap for ipairs do _* dup even? if + else drop then each ;

\ : dup2 { a b -- a b a b } a b a b ;
\ : square ( a -- 'a ) dup * ;
\ : cube ( a -- 'a ) dup dup * * ;
\ : abs ( a -- +a ) dup 0 < if -1 * then ;
\ : abs_ { a -- a }
\     a 0 < if a -1 * else a then ;
\ : sign { a -- -1/0/1 }
\     a 0 eq?  if 0 else a 0 > if 1 else -1 then then ;
\ \ 
\ \ 
\ : counter { init -- fn } 
\     : ( -- v ) init 1 + { init } init ; 
\  ;
\ : updown { init -- obj } 
\     init { v }
\     table { ret }
\     : ret.up ( -- v ) v 1 + { v } v ;
\     : ret.down ( -- v ) v 1 - { v } v ;
\     ret
\  ;
\ 1 updown

\ : xy_of_pt ( pt -- x y ) [ it .x it .y ]. ;
\ : xy_of_pt_1 ( pt -- x y ) [ x>> y>> ]. ;

\ : /move-up ( # by -- ) y>> + >>y ;
\ : /bounce ( # obj --  ) 10 /move-up ;
\ : tbl-test ( -- obj )  table dup 1 swap >x ;

\ : v2_of_xy ( x y -- t ) table [ table.insert(#*) table.insert(#*) ] ;
\ \ 
\ : add ( a b -- c ) + ;
\ : xy_to_pt ( x y -- pt ) table [ >>y >>x ] ;
\ : vaddxy { a b -- t } 
\     a .x b .x add a .y b .y add(**\*) xy_to_pt ; 

\ : NL ( -- ) print() ;

\ : tsum ( t -- sum ) 0 swap for ipairs do _*  + each ;
\ : printall ( t -- ) [ for it ipairs do _* dup print(*) io.write(*) each ]. ;




