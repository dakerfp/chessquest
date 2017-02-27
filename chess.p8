pico-8 cartridge // http://www.pico-8.com
version 8
__lua__
-- chessquest v0.5
-- by dakerfp

-- todo:
--- add ember side fire
--- add slime slow
--- add elemental
--- add mage
--- add beholder
--- add dark knights
--- add cocatrice
--- decide for 8x8 or 16x16
--- create particles
--- add dragon

flag_wall = 0
flag_stairs = 1
flag_trap = 2

u = 8 -- unit
map_width = 11
map_height = 8

e_player     = 33
e_bat        = 49
e_red_bat    = 51
e_slime      = 57
e_skeleton   = 59
e_kobold     = 37
e_ghost      = 39
e_dead       = 4
e_ember      = 41
e_knight     = 43
e_dead_slime = 5
e_dead_skel  = 6
e_floor_trap = 61
e_spinner    = 20

p = {t=e_player,x=u,y=u,vx=u,cx=u,cy=u}
t = 0
dead_bodies = {}
enemies = {}        
traps = {}

function randomize_section(from, to)
	-- 5 diff level parts
	my = flr(1 + rnd(7)) * map_height
	for y=0,map_height-1 do
		for x=from,to do
			mset(x,y,mget(x,my+y))
			if its_a_trap(x, y) then
				add(traps, {x=x*u, y=y*u, i=0, t=3}) -- xxx: t=0
			end
		end
	end
end

function cast_shadow(x,y)
	v = mget(x,y)
	return fget(v,flag_wall) or fget(v,flag_stairs) 
end

function randomize_map()
	randomize_section(1,3)
	randomize_section(4,6)
	randomize_section(7,10)
	-- build shadow
	for y=0,10 do
		for x=0,9 do
			s = 64
			if cast_shadow(x,y) then
				mset(x+11,y,s)
			else
				right=cast_shadow(x+1,y)
				up=cast_shadow(x,y-1)
				lcor=cast_shadow(x-1,y-1)
				rcor=cast_shadow(x+1,y-1)
				if right and up then
					s = 113
				elseif right then
					if rcor then s=112 else s=114 end
				elseif up then
					if rcor then s = 116 else s = 117 end
				elseif rcor then
					s = 115
				end
				mset(x+11,y,s)
			end
		end
	end
end

function fetch_next_enemy(cost)
	cost_table = {
		{e_bat, 1}, -- bat must come first
		{e_red_bat, 2},
        {e_spinner, 2},
		{e_slime, 3},
        {e_ember, 3},
        {e_skeleton, 3},
		{e_kobold, 4},
		{e_ghost, 4},
        {e_knight, 5},
	}
	i = 1 + flr(rnd(#cost_table) + 4) % #cost_table
	while i > 0 do
		row = cost_table[i]
		if row[2] <= cost then
			return row[1], row[2]
		end
		i -= 1
	end
	return e_dead, 0 -- should never happen
end

function init_random_level(cost)
	dead_bodies = {}
	enemies={}
	traps = {}
	randomize_map() -- xxx
	p = {x=u,y=5*u,vx=u,cx=u,cy=5*u}
	while cost > 0 do
		while true do
			-- 2x more probable to fit in 2nd half
			x = flr(9 - rnd(9 + 4) % 9) * u
			y = flr(rnd(7)) * u
			vx = 1 - 2 * flr(rnd(2)) -- 1 or -1
            vy = 1 - 2 * flr(rnd(2)) -- 1 or -1

			if not hits_wall(x, y)
				and get_enemy_at(x,y) == nil
				and x != p.x and y != p.y
			then	
				-- xxx
				tp, c = fetch_next_enemy(cost)
				cost -= c
				add(enemies, {t=tp, x=x, y=y, vx=vx*u, vy=vy*u, state=flr(rnd(2))}) -- state 0 or 1
				break
			end
		end
	end
end

function move_red_bat(e)
    e.vx = sgn(p.x - e.x) * u
    if can_move_to(e,e.x+e.vx,e.y) then
		e.x += e.vx	
    end
end

function move_bat(e)
	if can_move_to(e,e.x+e.vx,e.y) then
	   e.x += e.vx
	else
		e.vx = -e.vx
	end
end

function move_spinner(e)
    if can_move_to(e,e.x+e.vx,e.y+e.vy) then
        e.x += e.vx
        e.y += e.vy
    elseif can_move_to(e,e.x+e.vx,e.y-e.vy) then
        e.x += e.vx
        e.y -= e.vy
        e.vy = -e.vy
    elseif can_move_to(e,e.x-e.vx,e.y+e.vy) then
        e.x -= e.vx
        e.y += e.vy
        e.vx = -e.vx
    else
        e.x -= e.vx
        e.y -= e.vy
        e.vx = -e.vx
        e.vy = -e.vy
    end
end

function move_slime(e)
	return move_closest(e, {
		{x=e.x-u,y=e.y  },
		{x=e.x+u,y=e.y  },
		{x=e.x  ,y=e.y-u},
		{x=e.x  ,y=e.y+u}}, false)
end

function dist2(a, b)
	dx, dy = a.x-b.x, a.y-b.y
	return dx*dx +dy*dy
end

function move_skeleton(e)
	return move_closest(e, {
		{x=e.x-u,y=e.y-u},
		{x=e.x-u,y=e.y+u},
		{x=e.x+u,y=e.y-u},
		{x=e.x+u,y=e.y+u}}, false)
end

function move_kobold(e)
	if e.state == 0 then
		e.state = 1
		return move_closest(e, {
			{x=e.x-u,y=e.y-u},
			{x=e.x-u,y=e.y+u},
			{x=e.x+u,y=e.y-u},
			{x=e.x+u,y=e.y+u}}, true)
	else
		e.state = 0
		return move_closest(e, {
			{x=e.x,y=e.y-u},
			{x=e.x,y=e.y+u},
			{x=e.x+u,y=e.y},
			{x=e.x+u,y=e.y}}, true)
	end
end

function move_ghost(e)
	return move_closest(e, {
		{x=e.x-u,y=e.y-2*u},
		{x=e.x-u,y=e.y+2*u},
		{x=e.x+u,y=e.y-2*u},
		{x=e.x+u,y=e.y+2*u},
		{x=e.x-2*u,y=e.y-u},
		{x=e.x-2*u,y=e.y+u},
		{x=e.x+2*u,y=e.y-u},
		{x=e.x+2*u,y=e.y+u}}, true)
end

function move_knight(e)
    return move_closest(e, {
        {x=e.x-u,y=e.y},
        {x=e.x-u,y=e.y+u},
        {x=e.x-u,y=e.y-u},
        {x=e.x,y=e.y},
        {x=e.x,y=e.y+u},
        {x=e.x,y=e.y-u},
        {x=e.x+u,y=e.y},
        {x=e.x+u,y=e.y+u},
        {x=e.x+u,y=e.y-u}}, true)
end

function move_ember(e)
    tries = {
        {x=e.x-u,y=e.y},
        {x=e.x+u,y=e.y},
        {x=e.x,y=e.y-u},
        {x=e.x,y=e.y+u}
    }
    if can_move_to(e,e.x+u,e.y) then
        add(tries,{x=e.x+2*u,y=e.y})
    end
    if can_move_to(e,e.x-u,e.y) then
        add(tries,{x=e.x-2*u,y=e.y})
    end
    if can_move_to(e,e.x,e.y-u) then
        add(tries,{x=e.x,y=e.y-2*u})
    end
    if can_move_to(e,e.x,e.y+u) then
        add(tries,{x=e.x,y=e.y+2*u})
    end
	return move_closest(e, tries, true)
end

function move_closest(e, tries, flp)
	md = 1000*1000
	for try in all(tries) do
		if can_move_to(e,try.x,try.y) then
			d = dist2(p, try)
			if d < md or (d == md and rnd(2) > 1) then
				to, md = try, d
				if flp then
					e.vx += sgn(try.x - e.x) * u
				end
				e.x, e.y = try.x, try.y
			end
		end
	end
end

function get_enemy_at(x,y)
	for e in all(enemies) do
		if e.x == x and e.y == y then
			return e
		end
	end
	return nil
end

function can_move_to(e,x,y)
	return not hits_wall(x,y) and (get_enemy_at(x,y) == nil or e.t == e_spinner)
        and x >= 0 and x <= 10*u and y >= 0 and y <= 8*u
end

function hits_wall(x,y)
	val = mget(x/u,y/u)
	return fget(val, flag_wall)
end

function hits_stairs(x, y)
	val = mget(x/u,y/u)
 return fget(val, flag_stairs)
end

function its_a_trap(x, y)
	val = mget(x,y)
 return fget(val, flag_trap)
end

function _init()
	level = 0
    show_player = true
	_update = s_home
    _draw = draw_home
end

function over_dead_slime(e)
    for b in all(dead_bodies) do
        if e.x == b.x and e.y == b.y and b.t == e_dead_slime then
            return true
        end
    end
    return false
end

dpressed = false
function move_cursor(p)
	if dpressed and
		(btn(0) or btn(1)
		 or btn(2) or btn(3)) then
		 -- pass
    elseif btn(0) then
		if p.cy == p.y and
			p.cx >= p.x - u and
			not hits_wall(p.cx - u, p.cy) and (
				p.cx > p.x or
				can_move_to(p,p.cx,p.cy)
			)
        then
			p.cx -= u
        end
        dpressed = true
    elseif btn(1) then
        if p.cy == p.y and
            p.cx <= p.x + u and
            not hits_wall(p.cx + u, p.cy) and (
				p.cx < p.x or
				can_move_to(p,p.cx,p.cy)
			)
        then
			p.cx += u
		end
        dpressed = true
    elseif btn(2) then
        if p.cx == p.x and
            p.cy >= p.y - u and
            not hits_wall(p.cx, p.cy - u) and (
 			    p.cy > p.y or
 			    can_move_to(p,p.cx,p.cy)
            )
        then
			p.cy -= u
		end
        dpressed = true
	elseif btn(3) then
		if p.cx == p.x and
            p.cy <= p.y + u and not hits_wall(p.cx, p.cy + u) and (
 			p.cy < p.y or
 			can_move_to(e,p.cx,p.cy))
		then
			p.cy += u
		end
        dpressed = true
	else
		dpressed = false
	end
 
	if p.cx > p.x then
		p.vx = u
    elseif p.cx < p.x then
        p.vx = -u
	end

	return btn(4)
end

function update_animation()
	t += 1 -- time for animation
	t = t % 64
end

-- states --

function s_idle()
	update_animation()
	show_hint = true
	if move_cursor(p) then 
		_update = s_player
		show_hint = false
	end
end

function kill(e)
	add(dead_bodies, e)
	del(enemies, e)
	sfx(11)
end

function s_player()
	update_animation()
	fx, fy = p.x, p.y
	p.x, p.y = p.cx, p.cy
	sfx(10)

	_update = animate(p,fx,fy,function ()
		e = get_enemy_at(p.x,p.y)
		if e != nil then
            if e.t == e_spinner then
                _update = s_die
                return
            end
			kill(e)
		end
		_update = s_traps
	end)
end

function s_die()
	sfx(12)
	update_animation()
	show_player = false
    _draw = draw_game_over
	_update = s_dead
end

function s_dead()
	update_animation()
    if btn(4) and btn(5) then
        _init()
    end
end

function s_traps()
	_update = s_enemies
	for trap in all(traps) do
		trap.i = (trap.i + 1) % trap.t
		if trap.i == 0 then
			sfx(14)
		 	e = get_enemy_at(trap.x,trap.y)
			if e != nil then
				kill(e)
			elseif trap.x == p.x and trap.y == p.y then
				_update = s_die
			end
		end
	end
end

idx = 1
function s_enemies()
	update_animation()

	if idx > #enemies then
		_update = s_check
		idx = 1
		return
	end

	e = enemies[idx]
	if e.t == e_bat then
		sfx(13)
		animate_move(e, move_bat)
	elseif e.t == e_red_bat then
		sfx(13)
		animate_move(e, move_red_bat)
    elseif e.t == e_spinner then
        sfx(13)
        animate_move(e, move_spinner)
	elseif e.t == e_slime then
		sfx(13)
		animate_move(e, move_slime)
	elseif e.t == e_skeleton then
		sfx(13)
		animate_move(e, move_skeleton)
	elseif e.t == e_kobold then
		sfx(13)
		animate_move(e, move_kobold) 
	elseif e.t == e_ghost then
		sfx(13)
		animate_move(e, move_ghost)
	elseif e.t == e_ember then
		sfx(13)
		animate_move(e, move_ember)
    elseif e.t == e_knight then
        sfx(13)
        animate_move(e, move_knight)
	end
	idx += 1
end

function animate_move(e, move)
	px,py=e.x,e.y
	next_s = s_enemies
    move(e)
	if e.x == p.x and e.y == p.y then
		next_s = s_die
    elseif e.t == e_spinner then
        for o in all(enemies) do
            if o != e and e.x == o.x and e.y == o.y then
                kill(o)
            end
        end
	end

	_update=animate(e,px,py,next_s)
end

function animate(e, x, y, after)
	a, fs = 0, 8 -- frames
	tx, ty = e.x, e.y
	e.x, e.y = x, y
	return function()
		update_animation()
		a += 1
		if a >= fs then
			e.x, e.y = tx, ty
			_update = after
		else
			e.x = (x * (fs - a) + tx * a) / fs
			e.y = (y * (fs - a) + ty * a) / fs
		end
	end
end

function s_check()
	if hits_stairs(p.x,p.y) then
		sfx(9)
		_update = s_next_level
 	else
		_update = s_idle
	end
end

level = 0
function s_next_level()
	level += 1
	if level <= 10 then
		enemies = {}
		init_random_level(3 * level)
		_update = s_idle
	else
		_update = s_dead
		_draw = draw_win()
	end
end

function s_home()
    if btn(4) and not btn(5) then
        _update = s_next_level
        _draw = draw_game
    else
        _update = s_home
        _draw = draw_home
    end
end

show_hint = true
function draw_hint(x, y)
	if hits_wall(x,y) then
		spr(17, x, y)	
	else
		spr(19, x, y)	
	end
end

show_player = true
function draw_game()
	cls()
 
	off = {x=20, y=30}
 
	mapdraw(0, 0, off.x, off.y, 11, 8) -- tiles
	mapdraw(22,0, off.x, off.y, 11, 8) -- map
	mapdraw(11,0, off.x, off.y, 11, 8) -- shadow
 
	ds = (t%64) / 16

	-- draw possible moves?
	-- draw cursor
	if show_hint then
		if p.cx > p.x then
			p.vx = u
		elseif p.cx < p.x then
			p.vx = -u
		end
		draw_hint(off.x + p.cx, off.y + p.cy)
	end
	
	for e in all(dead_bodies) do
		s = e_dead
		if e.t == e_slime	then
			s = e_dead_slime
		elseif e.t == e_skeleton then
			s = e_dead_skel
		end
		spr(s, off.x + e.x, off.y + e.y - 2,
			1, 1, (e.vx > 0))
	end
	
	for trap in all(traps) do
		if trap.i == 0 then
			spr(e_floor_trap, off.x+trap.x,off.y+trap.y,1,1)
        elseif trap.i == 2  then
            spr(e_floor_trap+1, off.x+trap.x,off.y+trap.y,1,1)
		end
	end

 	for e in all(enemies) do
		s = e.t + ds/2
		if e.t == e_skeleton or
			e.t == e_kobold or
			e.t == e_ember or
            e.t == e_knight
		then
			palt(11, true)
			palt(0, false)
		end
		spr(s, off.x+e.x, off.y+e.y - 2,
			1, 1, (e.vx > 0))
		palt(0, true)
		palt(11, false)
	end
	if show_player then
		spr(33 + ds, off.x+p.x, off.y+p.y - 2, 1, 1, (p.vx > 0))
	end
end

home_show=0
function draw_home()
    cls()
    mapdraw(0, 0, 20, 30, 11, 8) -- tiles
    print('chessquest', 45, 44)
    home_show = (home_show+1)%32
    if home_show < 16 then
        print('press \142 to play', 34, 44 + 2 * u)
    end
end

death_msg = 'game over'
function draw_game_over()
	cls()
	spr(33, 64, 64)
	print(death_msg, 50, 44)
end

function draw_win()
	cls()
	spr(33, 64, 64)
	print('you win!', 50, 44)
end

__gfx__
000000000000000000a7aa0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000088088000a0000a000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000008888878000a7aa0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000088888880000a000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000008888800000a0000000000000020020000b00b0000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000888000000aa00006760000022220020bbbb00b76007007000000000000000000000000000000000000000000000000000000000000000000000000
0000000000080000000a000006067666022022200bb0bbb000506650000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000aa0000666060600020000000b000007060700000000000000000000000000000000000000000000000000000000000000000000000000
000000007770077777000077aaa00aaa000700000000700000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000007000000770000007a000000a000887000078800000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000007000000700000000a000000a078888000088887000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000088a88877888988000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000007888a8800889888700000000000000000000000000000000000000000000000000000000000000000000000000000000
000000007000000700000000a000000a008888700788880000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000007000000770000007a000000a007880000008870000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000007770077777000077aaa00aaa000070000007000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000003333000033330000333300003333006b5bb5bb6b5bb5bb0077700000000000bbbbbbbbbbbbbbbbb0bb0babb0bb0bab000000000000000000000000
00000000033330000333300003333000033330006b5555bb6b5555bb0777770000777000b9999bbbb9999bbbb0000aaab0000aaa007070000070700000000000
0000000001f1900001f1900001f1900001f190004b0505bb4b0505bb7474477007777700b0909bbbb0909bbbb5550b0bb5550b0b044444440444444400000000
000000000fff94000fff94000fff94000fff94004b5555bb4b5555b57777777074744770b9999babb9999b8bb0500b0bb0500b0b00a4a44000a4a44000000000
00000000003344400033444000334440003344404566775b4566775b7788777077777770bb449b8bbb449bab0000000b0000000b004444000044440000000000
000000000fb44a4400b44a440fb44a4400b44a444b6677b54b6677bb0778777077887770bbaa949bbbaa949bb0000b0bb0000b0b005555400055554000000000
00000000003344400f334440003344400f3344404b4444bb4b4444bb0077777707887770bba949bbbba949bbb0000b0bb0000b0b040444040404440400000000
00000000003034000030340000303400003034004b5bb5bb4b5bb5bb0000000000777777bb9b9bbbbb9b9bbbb0bb0b0bb0bb0b0b000404000004040000000000
00000000000000000000000000000000000400400044450000444450bbbbb999bbbbb9990000000000000000bbbbbbbbbbbbbbbb000000000000000000000000
00000000000000000020000200000000044000040555544005555544bbbbbbc9bb444bc900777b0000000000bbbbbbbbbb6777bb006000700000000000000000
00000000222022200200002244404440440000440707744007077744bb444b99b480849907773bb00077bb00bb6777bbb506707b066007700000000000000000
0000000002aa11022220222004882244444044440777444004444444b480849bb400049b077333b007773bb0b506707bb560077b066007700660066000000000
000000000011000002aa110000224004048822400444444000444440b400049bb444449b073333b0077333b0b560077bbb5667bb007000600000000000000000
00000000000000000011000000000000002240000044440000000000bb44490bbb44490b0b3333b00b3333b0bb5667bbb6b56b7b077006600000000000000000
00000000001100000000000000110000000000000000000000111100b044494bb044494b0bb33bb00bb33bb0b6b56b7bbbb56bbb077006600660066000000000
00000000011110000111100001111000011110000111111001111110b0444944b0444944bbbbbb33bbbbb333bb6bb7bbbb6bb7bb000000000000000000000000
00000000dddddddd22222222222222225555d55d1111d5d5222222225d5d111122222222dddddddd555555550000000000000000000000000000000000000000
00000000dddddddd2222222222222222dd5ddddd11d5d5d5222222225d5d5d1122222222dddddddd555555550000000000000000000000000000000000000000
00000000dddddddd2222222222222222d5555dddd5d5d5d5222222225d5d5d5d22222222dddddddd555555550000000000000000000000000000000000000000
00000000dddddddd2222222222222222ddddddddd5d5d5d5222222225d5d5d5d22222222dddddddd555555550000000000000000000000000000000000000000
00000000dddddddd0000000022222222ddddddddd5d5d50000000000005d5d5d00000000dddddddd555555550000000000000000000000000000000000000000
00000000dddddddd0000000022222222ddd5555dd5d500000000001100005d5d11000000dddddddd555555550000000000000000000000000000000000000000
00000000dddddddd0000000022222222ddddd5ddd5000000000011110000005d111100005dddddddd55555550000000000000000000000000000000000000000
00000000dddddddd0000000022222222d555dddd00000000001111d5000000005d11110055555555dddddddd0000000000000000000000000000000000000000
55555555000000000000000000000000000000550000000055555555555555550000000000000000000000000000000000000000000000000000000000000000
55555555000000000000000000000000000000550000000555555555055555550000000000000000000000000000000000000000000000000000000000000000
55555555000000000000000000000000000000550000005500000055000000550000000000000000000000000000000000000000000000000000000000000000
55555555000000000000000000000000000000550000005500000055000000550000000000000000000000000000000000000000000000000000000000000000
55555555000000000000000000000000000000550000005500000055000000550000000000000000000000000000000000000000000000000000000000000000
55555555000000000000000000000000000000550000005500000055000000550000000000000000000000000000000000000000000000000000000000000000
55555555000000000000000000000000000000550000005500000055000000550000000000000000000000000000000000000000000000000000000000000000
55555555000000000000000000000000000000550000005500000055000000550000000000000000000000000000000000000000000000000000000000000000
555505500000000055555055000000000000000000000000dddd0dd000000000ddddd0dd00000000000000000000000030033333000000000000000000000000
00500000000550555500555000000000000000000000000000d00000000dd0dddd00ddd000000000000000000000000030330000000000000000000000000000
0555500000005550500000000000000055550000000000000dddd0000000ddd0d000000000000000dddd00000003300033000000000000000000000000000000
0000000000000500500000000000000000000000000000000000000000000d00d000000000000000000000000000333003000000000000000000000000000000
000000000550055050000000000000050000000000000033000000000dd00dd0d00000000000000d000000000030000003000000000000000000000000000000
000555505500005050000000000500000000000033000330000dddd0dd0000d0d0000000000d0000000000000030000033000000000000000000000000000000
00000500000500505000000000000000000000000330000000000d00000d00d0d000000000000000000000000330000030000000000000000000000000000000
0555000000000000000000000000000000000000000000000ddd0000000000000000000000000000000000000000000000000000000000000000000000000000
00000011111111110000000000000011111111111111111000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000011111111110000000100000011111111111111110000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000011000000110000001100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000011000000110000001100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000011000000110000001100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000011000000110000001100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000011000000110000001100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000011000000110000001100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
34242424242424242464340000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
66666666666666660000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
34140514051405140554340000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
66555555555556660000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
34051405140514051405340000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
66656566666666660000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
34140514051405140514340000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
66666666666666660000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
34051405140514051405340000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
66666666666555550000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
34140514051405140514340000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
66665555555555550000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
34343434343434343434340000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
66666666656665660000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
34343434343434343434340000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
66666666666666660000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
34242424242424242464340000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
34140514051405140554340000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
34059405143414051434340000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
34140514243424140534340000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
34059405142414051424340000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
34140514051405140514340000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
34343434343434343434340000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
34343434343434343434340000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
34343434242424242464340000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
34242424051405140554340000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
3405140514a414051405340000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
34140514a414a4140514340000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
3405140514a414051405340000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
34140514051405343434340000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
34343434343434343434340000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
34343434343434343434340000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
34242424242424242464340000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
34940514059405140554340000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
34a414051405140514a4340000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
34940514051405140594340000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
34a414051405140514a4340000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
34140514059405140594340000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
34343434343434343434340000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
34343434343434343434340000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__label__
dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
dddddddddddddddddddfddddddfdfddfdddddddddddddddddddddffdddfdfdfddfdfddfdddfdfdfdfdfdddfdddfdfdfdddddddfdddfdfdfdfdfdddddfddddddd
ddfdddfddddddddddddddddddddddddddddddddddddddddfdfdfdddfdfdfdddfdfdfdddddfdfdddddddddddddddddddddddddddddddddddddddfdddfdddddddd
ddddddddddddddddddddddddfdfdddddddddfddddddddddfddddddddfddddfdffdddddddfdfddddddfdddddfdddddddddfddffdddddddddddddfddddfdfdffff
dddddddddddddddddddfdddfdddddddfdfdddddddfdfdddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
dddddddddddddddddddddddddfdfdddddddddddddfddddddfddffddddddfdfddddfdfdddddddfddfdddfdfddddddddddffddddddddddddddddddddddddddddfd
fdfddfdddddfddddfdddddddddffddddddddddddddddfddddddddddddddddddddddddddddddfdddddddddddddddddddddddfdddddddddddddffdfdfdddfddffd
dddfdfdddddddddfddddddddfddfdddddfddddddddddddddddddddfddfdddddddddddddffdddddddddddddddddfdddddddfdfdfdddddfdfddddffddfdddfdddd
ddddddddddddddfdddddddddddddddddddddfdddddfdfdfddddfddddfddfddfdddffdffdddfdfdddffdddfdddddddfddfdfdfdfdddfdddddddddddddfddfddfd
dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd

__gff__
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000101000201020104040000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__map__
4342424242424242424243404040404000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
4340404040404040404043404040404000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
4340404040404040404043404040404000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
4340404040404040404043404040404000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
4340404040404040404043404040404000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
4340404040404040404043404040404000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
4340404040404040404043404040404000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
4343434343434343434343404040404000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
4342424242434242424643404040404000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
4341504150425041504543404040404000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
4350495041504150495043404040404000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
4341424950415049424143404040404000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
4350495041504150495043404040404000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
4341504150435041504143404040404000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
4343434343434343434343404040404000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
4343434343434343434343404040404000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
4342424242424243484243000000404000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
4341504150415043474143000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
4350415042504143415043000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
4341504150415042504143000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
4350414242424150415043000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
4341504150415041504143000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
4350415041504150415043000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
4343434343434343434343000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
4342424243434342424643000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
4341504142424241504543000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
4350415049504950415043000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
434142424a414a42424143000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
4350415049504950415043000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
4341504143434341504143000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
4343434343434343434343000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
4343434343434343434343400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__sfx__
0010000000472004620c3400c34318470004311842500415003700c30500375183750c3000c3751f4730c375053720536211540114330c37524555247120c3730a470163521d07522375164120a211220252e315
01100000183732440518433394033c65539403185432b543184733940318433394033c655306053940339403184733940318423394033c655394031845321433184733940318473394033c655394033940339403
01100000247552775729755277552475527755297512775524755277552b755277552475527757297552775720755247572775524757207552475227755247522275526757297552675722752267522975526751
01100000001750c055003550c055001750c055003550c05500175180650c06518065001750c065003650c065051751106505365110650c17518075003650c0650a145160750a34516075111451d075113451d075
011000001b5771f55722537265171b5361f52622515265121b7771f76722757267471b7461f7362271522712185771b5571d53722517187361b7261d735227122454527537295252e5171d73514745227452e745
01100000275422754227542275422e5412e5452b7412b5422b5452b54224544245422754229541295422954224742277422e7422b7422b5422b5472954227542295422b742307422e5422e7472b547305462e742
0110000030555307652e5752b755295622e7722b752277622707227561297522b072295472774224042275421b4421b5451b5421b4421d542295471d442295422444624546245472444727546275462944729547
0110000000200002000020000200002000020000200002000020000200002000020000200002000020000200110171d117110171d227131211f227130371f2370f0411b1470f2471b35716051221571626722367
011000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002e775000002e1752e075000002e1752e77500000
001200002101018020180401c510165201d540220101d020255402704027010287102a0102a0102a0002a0000a100130001300013000130001300004400377000440024100026000260002600036000160001600
000100000a15008150071500615006150081501715007150033000330001300033000530001300174000330005300063000230020500074001c50015500155001550015500175000230005300073001740000000
001000001763007120041300375000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000b15007150091500615008150061500715004150051500115001150011400114001130011300112001120011100111000000000000000000000000000000000000000000000000000000000000000000
00060000091200c130041300213004100021000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00050000316100f61012620176203f6102e6100c620096200f610316003b6001560013600166001b6003c600376000d6000f6003c6003460018600126000b6000860007600066000660006600066000560004600
00180000175501b5501a5501f550175501a55019550204501c050194501d050264502045009450200501c4502c450200501b4501f450285502e05029550000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__music__
03 00440208
00 00044108
00 00010304
00 00414304
01 00010203
00 00014203
00 40414345
00 00010306
00 00010305
00 00010306
00 00010245
02 00010243
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344

