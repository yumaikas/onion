: r: ( p -- m ) require(*\*) ; : r! ( p -- ) require(*) ;
"classic" r: "buffer" r: { Object Buffer }

: class ( -- cls ) Object :extend(\*) ;

class { Env }

: Env.new ( # parent -- ) >>parent table >>kv ; 
: Env.def { # name val -- } kv>> name val put ;
: Env.defn { # name val -- } parent>> .kv name val put ;
: Env.getlocal ( # key -- l ) kv>> swap get ;
: Env.get { # key -- val } kv>> key get { val } 
     val if val else 
         val not parent>> and if key parent>> :get(*\*) else nil then 
     then ;

: iter-parents { env -- iter } : ( -- env )  env [ parent>> { env } ] ; ;
: Env.keys ( me -- keys ) t[ iter-parents[*\*] .kv pairs[*\*] table.insert(#*) for for ] ;

class { CompilerOuput } 

: +def_depth ( # amt -- ) def_depth>> + >>def_depth ;
: CompilerOutput.new ( # env code def_depth -- ) 0 or >>def_depth >>code >>env false >>needs_it ; 
: CompilerOutput.enter ( # -- ) "comp-in" print(*) 1 +def_depth ;
: CompilerOutput.exit ( # -- ) "comp-out" print(*) -1 +def_depth ;
: CompilerOutput.compile ( # ast -- ) code>> :compile(*) ;
: CompilerOutput.complie_iter ( # iter -- ) [*\*] CompilerOutput.compile for ;
: CompilerOutput.pushenv ( # -- ) env>> Env(*\*) >>env ;
: CompilerOutput.popenv ( # -- ) env>> .parent >>env ;
: CompilerOutput.def ( # name val --  )  env>> [ Env.def ]. ;
: CompilerOutput.defn ( # name val -- ) env>> [ Env.defn ]. ;
: CompilerOutput.mark_needs_it ( # -- ) true >>needs_it ;
: CompilerOutput.is_toplevel ( # -- ? ) env>> .parent not ;
: CompilerOutput.envget ( # key -- val ) env>> [ Env.get ]. ;
: CompilerOutput.envgetlocal ( # key -- val ) env>> [ Env.getlocal ]. ;
: CompilerOutput.envkeys ( # -- keys ) env>> Env.keys ;
: CompilerOutput.derived ( # -- new ) env>> nil def_depth>> CompilerOutput(***\*) ;

@_G [ CompilerOuput >>CompilerOuput  Env >>Env ].
