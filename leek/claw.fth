"iter" require(*\*) { iter }
"classic" require(*\*) { Object }
table { claw }
: , (#*\) table.insert(#*) ;
: ]s (#\*) table.concat(#\*) ]. ;
: #pop (#) table.remove(#) ;
: qwt (*\*) "'" swap .. "'" .. ;

: class (\*) Object :extend(\*) ;

class [ ::claw.parse ].

class [ ::claw.namelist
:: new (#*\) >>_items ;
:: __push ( # i -- ) _items>> [ , ].  ;
:: __tostring ( # -- s ) _items>> t[ "n:{ " , each qwt , ", " , for #pop " }" , ]s ;
:: items ( # -- s ) _items>> ;
:: __each ( # -- iter ) _items>> iter.each(*\*) ;
].

class [ ::claw.ifelse :: new ( t f -- ) >>when_false >>when_true ; ].
class [ ::claw.if_ :: new (#*\) >>when_true ; ].
class [ ::claw.whitespace :: new (#*\) >>whitespace ; ].
class [ ::claw.assign_many 
:: new (#*\) >>varnames ; 
:: __tostring ( # -- s ) varnames>> t[ "::{ " , each qwt , ", " , for #pop " }" ,  ]s  ;
].

class [ ::claw.func :: new (#****\) >>body >>outputs >>inputs >>name ; ].
class [ ::claw.iter 
:: new (#****\) >>body >>loop_vars >>inputs >>word ; 
:: init ( # -- ) inputs>> table or >>inputs loop_vars>> table or >>loop_vars ;
].

class [ ::claw.do_loop :: new (#*\) >>body ; ].
class [ ::claw.do_step_loop :: new (#*\) >>body ; ].
class [ ::claw.do_while_loop :: new (#**\) >>body >>cond ; ].

class [ ::claw.cond :: new (#*\) >>clauses ; ].
class [ ::claw.cond_claus :: new (#**\) >>body >>pred ; ].
class [ ::claw.each_loop :: new (#*\) >>body ; ].
class [ ::claw.body 
:: new (#*\) >>_items ;
:: compile ( # item -- ) _items>> [ , ]. ;
:: __tostring ( # -- s ) t[ "{{ " , _items>> each , " " , for #pop " }}" , ]s ;
:: __each ( # -- * ) _items>> iter.each(*\*) ;
].

class [ ::claw.unresolved
:: new (#*\) >>tok ;
:: __tostring (#\*) "%[" tok>> .. "]" .. ;
].

class [ ::claw.it_fn :: new (#*\) >>name ; :: __tostring (#\*) "it-fn" ; ].
class [ ::anon :: __tostring ( # -- s ) "anon-fn"  ; ].
claw "anon_fn" anon(\*) put



