"classic" require(*\*) { Object }
"scanner" require(*)

Object :extend(\*) { CompilerInput }

: CompilerInput.new ( # tokens -- ) >>tokens 1 >>token_idx ;
: CompilerInput.tok ( # -- t ) tokens>> token_idx>> get ;
: CompilerInput.tok_at ( # idx -- t ) tokens>> swap get ;
: CompilerInput.has_more_tokens ( # -- ? ) token_idx>> tokens>> len <= ;
: CompilerInput.goto_scan ( # scan -- ) .idx >>token_idx ;
: CompilerInput.scan_ahead_by ( # amt -- scan ) token_idx>> + tokens>> swap Scanner(**\*) ;

@_G "CompilerInput" CompilerInput put
