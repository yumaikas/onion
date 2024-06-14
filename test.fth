: add ( a b -- c ) + ;
: dup2 { a b -- a b a b } a b a b ;
: square ( a -- 'a ) dup * ;
: cube ( a -- 'a ) dup dup * * ;
: abs ( a -- +a ) dup 0 < if -1 * then ;
: abs { a -- +a } a 0 < if a -1 * else a then ;
: sign { a -- -1/0/1 } a 0 eq? if 0 else a 0 > if 1 else -1 then then ;


: counter { init -- fn } 
    : ( -- v ) init 1 + { init } init ; 
;
: updown { init -- obj } 
    init { v }
    table { ret }
    : ret.up ( -- v ) v 1 + { v } v ;
    : ret.down ( -- v ) v 1 - { v } v ;
    ret
;
1 updown

