return function(input)
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
            table.insert(tokens, new_tok)
        elseif new_tok:find('^"') then
            local quote_scanning = true
            local scan_tok
            local scan_pos = pos
            while quote_scanning do
                if input:find('[^"]*"', scan_pos) then
                    _, _, scan_tok, new_scan_pos = input:find('([^"]*")()', scan_pos)
                    quote_scanning = scan_tok:find('\\"$') ~= nil
                    new_tok = new_tok .. scan_tok
                    scan_pos = new_scan_pos
                else
                    io.write("Seeking in ", input:sub(scan_pos))
                    error("Unclosed quote in input!")
                end
            end
            pos = scan_pos
            table.insert(tokens, new_tok)
        else
            table.insert(tokens, new_tok)
        end
        if spacing:find("[\r\n]") then
            table.insert(tokens, spacing)
        end
    end
    return tokens
end
