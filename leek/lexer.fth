"iter" require(\*) { iter }
"classic" require(\*) { Object }
: , (#*\) table.insert(#*) ;
: 2drop (**\) drop drop ;
: str (*\*) tostring(*\*) ;
: type? (**\*) [ type(*\*) ] eq? ;
: s_has (**\*) :find(*\*) ;
: nil? (*\*) @nil eq? ;
: include_resolve (*\*) "./?.fth;./?/init.fth;./?;" package.searchpath(**\*) ;

: lex { input -- toks }
    "#include%(([^)]+)%)" : ( path -- contents )
        include_resolve "r" io.open(**\*) "*a" swap :read(*\*) dup :close() ; 
    input :gsub(**\*) { input }

    " " ..= input 
    0 t[ ] @nil @nil @nil { pos tokens tok new_tok newpos }
    : nt_find (*\*) new_tok :find(*\*) ;
    : in_find (*\*) input :find(*\*) ;
    do? input len pos > while
        "%S+" input s_has if else
        "(%S+)([\r\n\t ]*)()" pos input :find(**\*****) { new_tok spacing new_pos } 2drop
        new_pos { pos }

        cond
           "^\\$" nt_find -> "[^\r\n]+[\r\n]+()" pos input :find(**\***) { pos } 2drop of
           "^\"" nt_find "\"$" nt_find and new_tok len 1 > and -> tokens [ new_tok , ]. of
           "^\"" nt_find ->
                true @nil pos { quote_scanning scan_tok scan_pos }
                do? quote_scanning while 
                   "[^\"]*\"" scan_pos input :find(**\*) if 
                    "([^\"]*")()" scan_pos input :find(**\****) { scan_tok new_scan_pos } 2drop
                    "\\\"$" scan_tok s_has nil? not { quote_scanning } \ "
                    new_scan_pos { scan_pos }
                   else
                        "Seeking in " scan_pos input :sub(*\*) io.write(**)
                        "Unclosed quote in input!" error(*\)
                   then
                loop
                tokens [ pos new_tok len - 1 - scan_pos 1 - input :sub(**\*) , ].
                scan_pos { pos }
            of
            true -> tokens [ new_tok , ]. of
        end
        "[\r\n]" spacing s_has if tokens [ spacing , ]. then
        then
    loop
    tokens [ @Lex.EOF , ]
;

: matcher { forval -- pred }
    : any_of { opts -- pred }
        opts ipairs[*\**] { i v } opts i v matcher put for
        : { el -- ? } false { ret } opts each { pred } el pred(*\*) or= ret for ret ;
    ;
    cond
        forval "function" type? -> forval of
        forval "table" type? -> forval any_of of
        true -> : (*\*) forval eq? ; of
    end
;

Object :extend(\*) [ ::Lex 
:: new (#*\) >>input ;
:: init (\) 1 >>idx input>> lex >>_toks @nil >>input ;
:: __tostring (\*) 
    "lex(idx = %d, toks=%s" idx>> 
    toks>> : { s -- s } "[" s str .. "]" .. ; iter.strmap(**\*)
    string.format(***\*) ;
:: tok (#\*) idx>> _toks>> get ;
:: is (#*\*) Lex.tok eq? ;
:: next (#\) idx>> 1 + >>idx ;
:: at (#*\*) idx>> + _toks>> get ;
:: can { # pred -- ? } Lex.tok pred(*\*) ;
:: matches ( # patt -- ? ) Lex.tok :find(*\*) nil? not ;
:: any_of ( # opts -- ? ) ::me : (*\*) me :is(*\*) ; iter.find(**\*) nil? not ;
Lex Object :extend(\*) >EOF

].


