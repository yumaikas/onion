local Object = require("classic")
require("scanner")

CompilerInput = Object:extend()

function CompilerInput:new(tokens)
	self.tokens = tokens
	self.token_idx = 1
end

function CompilerInput:tok() return self.tokens[self.token_idx] end
function CompilerInput:tok_at(idx) return self.tokens[idx] end
function CompilerInput:tok_next() self.token_idx = self.token_idx + 1 end
function CompilerInput:has_more_tokens() 
	return self.token_idx <= #self.tokens
 end
function CompilerInput:goto_scan(scan) self.token_idx = scan.idx end
function CompilerInput:scan_ahead_by(ahead_by) 
	return Scanner(self.tokens, self.token_idx + ahead_by)
end
