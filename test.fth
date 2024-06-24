\ Working functions
: add ( a b -- c ) + ;
: dup2 { a b -- a b a b } a b a b ;
: square ( a -- 'a ) dup * ;
: cube ( a -- 'a ) dup dup * * ;
: abs ( a -- +a ) dup 0 < if -1 * then ;
: even? ( a -- ? ) 2 mod 0 eq? ;
: abs_ { a -- a }
    a 0 < if a -1 * else a then ;
 : sign { a -- -1/0/1 }
     a 0 eq?  if 0 else a 0 > if 1 else -1 then then ;

: counter { init -- fn } 
    : ( -- v ) init 1 + { init } init ; ;
: updown { init -- obj } 
    init { v }
    table { ret }
    : ret.up ( -- v ) v 1 + { v } v ;
    : ret.down ( -- v ) v 1 - { v } v ;
    ret
 ;

: xy_of_pt ( pt -- x y ) [ it .x it .y ]. ;
: xy_of_pt_1 ( pt -- x y ) [ x>> y>> ]. ;
: /move-up ( # by -- ) y>> + >>y ;

: /bounce ( # --  ) 10 /move-up ;
: v2_of_xy ( x y -- t ) table [ table.insert(#*) table.insert(#*) ] ;
: xy_to_pt ( x y -- pt ) table [ >>y >>x ] ;

: tbl-test ( -- obj )  table dup 1 swap >x ;
: add ( a b -- c ) + ;

: NL ( -- ) print() ;

\ Problem functions

\ Iterators broke with the new stuff
: tsum ( t -- sum ) 0 swap for ipairs do _*  + each ;
: printall ( t -- ) [ for it ipairs do _* dup print(*) io.write(*) each ]. ;

\ Return two values, when they only return 1
: add-if-even ( a b -- c  ) 0 0 eq? if dup even? if + else drop then then ;
: tsum-evens ( t -- sum ) 0 swap for ipairs do _* dup even? if + else drop then each ;
: tsum-evens-2 ( t -- sum ) 
    0 { total } 
    for ipairs do _* dup even? if total + { total } else drop then each total ;

\ Toplevel code is... dodgy atm
1 updown : ( --  ) ;


\ These crash the compiler
\ : vaddxy { a b -- t } a .x b .x add a .y b .y add(**\*) xy_to_pt ; 

\ ^^^^:





