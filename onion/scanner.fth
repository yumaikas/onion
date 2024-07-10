: req ( path -- module ) require(*\*) ;
"classic" req "pprint" req { Object pprint }
: class ( -- new-class ) Object :extend(\*) ;
: typeof ( val -- type ) type(*\*) ;
: function? ( fn -- ? ) typeof "function" eq? ;
: string? ( str? -- ? ) typeof "string" eq? ;
: tget ( t idx -- el ) get ;
: strget ( s idx -- c ) swap [ dup ] :sub(**\*) ;
: matcher { _of -- pred } _of function? if _of else : ( el -- ? ) _of eq? ; then ;

class { Scanner }

: Scanner.new ( # t idx -- ) >>idx >>subject subject>> string? if @strget else @tget then >>_fetch ;
: Scanner.go_next ( # -- ) idx>> 1 + >>idx ;
: Scanner.at ( # -- c ) subject>> idx>> it ._fetch(**\*) ;
: Scanner.len ( # -- l ) subject>> len ;

: Scanner.upto { # target -- iter }
    target matcher { pred }
    it { me }
    : ( -- el ) me [
        Scanner.at pred(*\*) not idx>> Scanner.len <= and if 
            Scanner.at Scanner.go_next 
        else
            idx>> Scanner.len > if 
                2 debug.getinfo(*\*) .currentline print(*) 
                target pprint.pformat(*\*) "not found! " .. error(*) 
            then
            Scanner.go_next nil
        then
    ]. ;
; 

: Scanner.rest ( # -- iter ) it { me } 
: ( -- el ) me [ idx>> Scanner.len <= if Scanner.at Scanner.go_next else nil then ]. ;  ;

: any_of ( ... -- pred ) ... { options } 
    options ipairs[*\**] matcher { idx mval } options idx mval put for
    : { el -- ? } false { found } 
        options each { p } el p(*\*) or= found for found ; ;

: balanced { up down -- pred } up matcher down matcher 1 { is_up is_down depth }
: ( el -- ? ) [
 is_down(#\*) if 1 += depth then
 is_up(#\*)   if 1 -= depth then
 is_up(#\*) ]. depth 0 eq? and  ; ;

