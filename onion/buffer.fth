"classic" require(*\*) { Object }
"iter" require(*\*) { iter }

: tpop ( * -- * ) table.remove(*\*) ;
: tpush ( * * -- ) table.insert(**) ;
\ : ?error ( cond to-throw -- ) [ if ] error(*) then ;
: ?error ( cond to-throw -- ) swap if error(*) else drop then ;

Object :extend(\*) { Buffer }

: Buffer.from ( ... -- b ) ... Buffer(*\*) ;
: Buffer.__add ( b v -- v ) dup [ swap :push(*) ] ;
: Buffer.new ( # items -- ) table or >>items ; 
: Buffer.tostring ( # -- * ) "Buffer" ; 
: Buffer.push! ( # val -- ) items>> swap tpush ;
: Buffer.push ( # val -- me ) Buffer.push! it ;
: Buffer.peek ( # -- item ) items>> dup len get ;
: Buffer.put { # idx val -- } items>> idx val put ;
: Buffer.each ( # -- * ) items>> iter.each(*\*) ;
: Buffer.concat ( # sep -- * ) items>> swap table.concat(**\*) ;
: Buffer.str ( # -- * ) "" Buffer.concat ;
: Buffer.size ( # -- * ) items>> len ;
: Buffer.empty ( # -- ? ) Buffer.size 0 eq? ;
: Buffer.pop_check ( # -- ok item? ) Buffer.empty if false nil else true items>> tpop then ;
: Buffer.pop_throw { # msg -- * } Buffer.pop_check [ msg ?error ] ;
: Buffer.collect ( # iter -- * ) [*\*] Buffer.push! for it ;
: Buffer.last ( # n -- * ) items>> swap iter.last(**\*) ;
: Buffer.copy ( # -- * ) Buffer.each Buffer(\*) :collect(*\*) ;

Buffer
