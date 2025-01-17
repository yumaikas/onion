: , (#*\) it :push(*) ; 
: s/join { # -- ret } it :join(\*) ;
: str (*\*) :toString(\*) ;

: print (*\) @console :log(*\) ;

: max (**\*) Math.max(**\*) ;
: min (**\*) Math.min(**\*) ;

: between { i ra rb -- } 
    i ra rb min > 
    i ra rb max <= and ;

: randint { l h -- res } 
 l Math.ceil(*\*) { L }
 h Math.floor(*\*) { H }
 Math.random(\*) H L - L + * ;

: randf ( -- res ) Math.random(\*) ;

: array ( -- arr ) Array(\*) ;
