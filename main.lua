local _1={} local _2=20 _1.x = _2 local _3=20 _1.y = _3 local text_loc=_1 local _4=0 local total_time=_4 local gfx=love.graphics function sin(p1) local _5 = math.sin(p1) return _5 end
function cos(p1) local _1 = math.cos(p1) return _1 end
function love.update(dt) total_time=(total_time+dt) local _1=text_loc local _2 = sin(total_time) local _3=20 _1.x = (_2*_3) local _4 = cos(total_time) local _5=20 _1.y = (_4*_5) end
function love.draw() local _1="Hi from Onion and love!" local _2=_1 local _3=text_loc local _4=40 local _5=40 gfx.print(_2, (_3.x+_4), (_3.y+_5)) end
