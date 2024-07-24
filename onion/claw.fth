"iter" require(*\*) { iter }
"classic" require(*\*) { Object }
table { claw }
: , (#*\) table.insert(#*) ;
: ]s (#) table.concat(#\*) ]. ;
: #pop (#) table.remove(#) ;
@nil { me }
: qwt (*\*) "'" swap .. "'" .. ;

: clawss { name ctor -- } Object :extend(\*) { cls } cls "new" ctor put  claw name cls put cls { me } ;

"parse" : (*\) ; clawss

"namelist" : ( # from -- ) >>_items ; clawss 
: me.__push ( # i -- ) _items>> [ , ]  ;
: me.__tostring ( # -- s ) _items>> t[ "n:{ " , each qwt , ", " , for #pop " }" , ]s ;
: me.items ( # -- s ) _items>> ;
: me.__each ( # -- iter ) _items>> iter.each(*\*) ;

"ifelse" : ( # t f -- ) >>when_false >>when_true ; clawss 
"if_" : (#*\) >>when_true ; clawss 
"whitespace" : (#*\) >>whitespace ; clawss 
"assign_many" : ( # vars -- ) >>varnames ; clawss
: me.__tostring ( # -- s ) varnames>> t[ "::{ " , each qwt , ", " , for #pop " }" ,  ]s  ;
"func" : (#****\) >>body >>outputs >>inputs >>name ; clawss

"iter" : (#****\) >>body >>loop_vars >>inputs >>word ; clawss
: me.init ( # -- s ) inputs>> table or >>inputs loop_vars>> table or >>loop_vars ;

: of_body (#*\) >>body ;

"do_loop" @of_body clawss
"do_step_loop" @of_body clawss
"do_while_loop" : (#**\) >>body >>cond ; clawss
"cond" : (#*\) >>clauses ; clawss
"cond_clause" : (#**\) >>body >>pred ; clawss
"each_loop" @of_body clawss

"body" : (#*\) >>_items ; clawss
: me.compile ( # item -- ) _items>> [ , ] ;
: me.__tostring ( # -- s ) t[ "{{ " , _items>> each , " " , for #pop " }}" , ]s ;
: me.__each ( # -- * ) _items>> iter.each(*\*) ;

"unresolved" : (#*\) >>tok ; clawss 
: me.__tostring (#\*) "%[" tok>> .. "]" .. ;
Object :extend(\*) { anon }
: anon.__tostring ( # -- s ) "anon-fn"  ;
claw "anon_fn" anon(\*) put



