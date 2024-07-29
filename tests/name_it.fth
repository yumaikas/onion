: , ( # v -- ) table.insert(#*) ;
: ts ( t -- s ) table.concat(*\*) ;
: new ( -- * ) t[ ::derp 1 >>x 2 >>y :: pos ( # -- x y ) x>> y>> ; 
    :: __tostring ( # -- s ) it { me } t[ "x: " , me .x , "y: ", me .y , ] ts ;
] ;



