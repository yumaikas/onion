local iter = require("iter")

local lexer = {}
lexer.EOF = {}

function lexer.lex(input)
    input = input.." "
    local pos = 0
    local tokens = {}
    local tok, new_tok
    local newpos
    while pos < #input do
        if not input:find("%S+", pos) then break end
        _, _, new_tok, spacing, new_pos = input:find("(%S+)([\r\n\t ]*)()", pos)
        pos = new_pos
        if new_tok:find("^\\$") then 
            _, _, pos = input:find("[^\r\n]+[\r\n]+()", pos)
        elseif new_tok:find('^"') and new_tok:find('"$') then
            iter.push(tokens, new_tok)
        elseif new_tok:find('^"') then
            local quote_scanning = true
            local scan_tok
            local scan_pos = pos
            while quote_scanning do
                if input:find('[^"]*"', scan_pos) then
                    _, _, scan_tok, new_scan_pos = input:find('([^"]*")()', scan_pos)
                    quote_scanning = scan_tok:find('\\"$') ~= nil
                    -- new_tok = new_tok .. scan_tok
                    scan_pos = new_scan_pos
                else
                    io.write("Seeking in ", input:sub(scan_pos))
                    error("Unclosed quote in input!")
                end
            end
            iter.push(tokens, input:sub(pos - #new_tok - 1, scan_pos-1))
            pos = scan_pos
        else
            iter.push(tokens, new_tok)
        end
        if spacing:find("[\r\n]") then
            iter.push(tokens, spacing)
        end
    end
    iter.push(tokens, lexer.EOF)

    return tokens
end

return lexer
