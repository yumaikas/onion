\ asdf
t[ 20 >>x 20 >>y ] { text_loc }
0 { total_time }

@love.graphics { gfx }

: sin ( a -- 'a ) math.sin(*\*) ;
: cos ( a -- 'a ) math.cos(*\*) ;

: love.update { dt -- } 
    dt += total_time
    text_loc [ total_time dup sin 20 * >>x cos 20 * >>y ].
;

: love.draw { -- }
    "Hi from Onion and love!" [ text_loc [ x>> 40 + y>> 40 + ]. gfx.print(#**) ].
;
