local iter = require("iter")
local f = iter.f
local record = require("record")
local Object = require("classic")

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
-- 928cd7a4753edc
local Lex = record("lex", Object, "input")
function Lex.init()
    self.idx = 0
    self._toks = lexer.lex(self.input)
end

local function matcher(of)
    function any_of(options)
        for i, v in ipairs(options) do
            options[i] = matcher(v)
        end

        return function(el)
            for _, pred in ipairs(options) do
                if pred(el) then
                    return true
                end
            end
            return false
        end
    end
	if type(of) == "function" then
        return of
    elseif type(of) == "table" then
        return any_of(of)
	else
	    return function(el) return el == of end
	end
end

Lex.tok = f'(s, match) -> s._toks[s.idx]'
Lex.is = f'(s, match) -> s:tok() == match'
Lex.next = f'(s) s.idx+=1'
Lex.at = f'(s,idx) -> s._toks[s.idx+idx]'
Lex.can = f'(s,pred) -> pred(s:tok())'
Lex.matches = f'(s,patt) -> s:tok():find(patt) ~= nil'
Lex.any_of = f'(s, opts) -> iter.find(opts, @(i) -> s:is(i) ;) ~= nil'


return Lex
