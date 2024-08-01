"onion.h" "w" io.open(**\*) { out-file }
: echo ( l -- ) out-file :write(*) ;

: byte ( c -- s ) string.byte(*\*) "0x%02x" swap string.format(**\*) ;

0 { size }
"unsigned char onion[] = {" echo
" \n  " echo

"bin/onion" 1 io.lines[**\*] byte echo ", " echo 1 += size 
    size 12 mod 0 eq? if " \n  " echo  then
for

"0x0a\n};\n" echo 1 += size 
"\nunsigned int onion_len = " size .. ";" ..  echo 
" \n " echo





