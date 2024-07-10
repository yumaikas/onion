: while ( pred -- ) : ( -- cont ) pred(\*) if true else nil end ; ;

: { input -- lexer }
    input " " .. { input }
    0 table { pos tokens }
    nil nil nil { tok new_tok newpos }

    : nt_match ( patt -- ? )  new_tok :find(*\*) ;
    : go ( -- cont ) pos input len < ;

    go while[*\_] 
        "%S+" input :find(*\*) if 
            "(%S+)([\r\n\t ]*)()" pos input :find(**\*****) { _ _ new_tok spacing new_pos }
            new_pos { pos }
        then

        cond
            when "^\\$" nt_match of "[^\r\n]+[\r\n]+()" pos input :find(**\__*) { pos } then
            when  "^\"" nt_match "\"$" nt_match and of  then
            when true of "derp" print(*)  then
            of true when "derp" print(*) then 
        end

        "^\\$" new_tok :find(*\*) if "[^\r\n]+[\r\n]+()" pos input :find(**\__*) { pos } then

        
    for



    

if then
elif then
elif then
