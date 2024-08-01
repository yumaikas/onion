"bin/onion" "w" io.open(**\*) { out-file }
: echo ( l -- ) out-file :write(*) "\n" out-file :write(*) ;
: ingest { path -- }  path io.lines[*\*] echo for ;
: pack { pkg path -- } 
    "package.preload['%s'] = package.preload['%s'] or function(...)\n" 
        pkg pkg string.format(***\*) echo
        path ingest
    "end\n\n" echo ;

"#!/usr/bin/env lua\n" echo

\ These exist because baseline lua interpreters don't come with a directory lsiting function
"atoms" "onion/atoms.lua" pack
"basenv" "onion/basenv.lua" pack
"check_stack" "onion/check_stack.lua" pack
"classic" "onion/classic.lua" pack
"claw" "onion/claw.lua" pack
"effects" "onion/effects.lua" pack
"eff" "onion/eff.lua" pack
"iter" "onion/iter.lua" pack
"lexer" "onion/lexer.lua" pack
"lunar" "onion/lunar.lua" pack
"molecules" "onion/molecules.lua" pack
"pprint" "onion/pprint.lua" pack
"record" "onion/record.lua" pack
"resolve" "onion/resolve.lua" pack
"onion.scratch" "onion/scratch.lua" pack
"seam" "onion/seam.lua" pack
"stitch" "onion/stitch.lua" pack
"trace" "onion/trace.lua" pack

"cli.lua" ingest

out-file :close()
