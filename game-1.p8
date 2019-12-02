pico-8 cartridge // http://www.pico-8.com
version 18
__lua__

local player
local walls
local enemies

local game_objects

local global_timer = 0
local enemysprite = 3

function _init()

	enemies={
		make_enemy(90,64)
	}
	walls={
		make_wall(16,16,true),
		make_wall(24,16),
		make_wall(8,8)
	}

	for i = 0,16,1 
	do 
		add(walls, make_wall(0, i*8))
		if i > 0 then
			add(walls, make_wall(i*8, 0))
		end
	end

	bombs={}
	init_protag()

end

function _update()

	local obj
	for obj in all(game_objects) do
		obj:update()
	end

	player:update()

	local enemy
	for enemy in all(enemies) do
		enemy:update()
	end

	local wall
	for wall in all(walls) do
		wall:update()
	end

	local bomb
	for bomb in all(bombs) do
		bomb:update()
	end

	update_global_timer()
	
end

function _draw()

	cls(3)

	local obj
	for obj in all(game_objects) do
		obj:draw()
	end

	local enemy
	for enemy in all(enemies) do
		enemy:draw()
	end

	local wall
	for wall in all(walls) do
		wall:draw()
	end

	local bomb
	for bomb in all(bombs) do
		bomb:draw()
	end

	player:draw()
	
end

function update_global_timer()

	global_timer += 1
	if global_timer==30 then
		global_timer = 0
	end

end

function are_lines_overlapping(min1,max1,min2,max2)

	return max1 > min2 and max2 > min1

end

function are_rects_overlapping(left1,top1,right1,bottom1,left2,top2,right2,bottom2)

	return are_lines_overlapping(left1,right1,left2,right2) and are_lines_overlapping(top1,bottom1,top2,bottom2)

end

function are_object_rects_colliding(first, second)

	return are_rects_overlapping(first.x,first.y,first.x+first.width,first.y+first.height,second.x,second.y,second.x+second.width,second.y+second.height)

end

function init_protag()

	player = {
		name="bomberman",
		x=64,
		y=64,
		width=8,
		height=8,
		facing=1, -- 0123 = lrud
		draw=function(self)

			spr(48,self.x,self.y)

		end,
		update=function(self)

			-- In a bomberman-type game, it's weird if you can move diag, so limit to one direction at a time.
			-- TODO: it feels bad to stop when two keys are held, actually.
			if btn(0) and not (btn(1) or btn(2) or btn(3)) then -- left
				self.facing = 0
				self.x -= 1
			elseif btn(1) and not (btn(0) or btn(2) or btn(3)) then -- right
				self.facing = 1
				self.x += 1
			elseif btn(3) and not (btn(1) or btn(2) or btn(0)) then -- down
				self.facing = 3
				self.y += 1
			elseif btn(2) and not (btn(0) or btn(1) or btn(3)) then -- up
				self.facing = 2
				self.y -= 1
			end
						
			if btnp(4) then -- space ?

				local bomb_x = player.x
				local bomb_y = player.y

				if self.facing == 0 then
					bomb_x = player.x - 8
				elseif self.facing == 1 then
					bomb_x = player.x + 8
				elseif self.facing == 2 then
					bomb_y = player.y - 8
				elseif self.facing == 3 then
					bomb_y = player.y + 8
				end

				add(bombs, make_bomb(bomb_x,bomb_y,self.facing))

			end

		end,
		check_for_collision_with_wall=function(self,wall)

			local x,y,w,h = self.x,self.y,self.width,self.height

			-- collision top
			local top_hitbox = {
				x = x+2,
				y = y,
				width = w-4,
				height = h/2
			} 
			--hitbox/collision bottom
			local bottom_hitbox = {
				x = x+2,
				y = y+(h/2),
				width = w-4,
				height = h/2
			}
			--hitbox/collision left
			local left_hitbox = {
				x = x,
				y = y+2,
				width = w/2,
				height = h-4
			} 
			--hitbox/collision right
			local right_hitbox = {
				x = x+(w/2),
				y = y+2,
				width = w/2,
				height = h-4
			} 
			if are_object_rects_colliding(wall, top_hitbox) then
				self.y = wall.y + self.height
			end
			if are_object_rects_colliding(wall, bottom_hitbox) then
				self.y = wall.y - self.height
			end
			if are_object_rects_colliding(wall, left_hitbox) then
				self.x = wall.x + self.width
			end
			if are_object_rects_colliding(wall, right_hitbox) then
				self.x = wall.x - self.width
			end

		end
	}

end

function make_wall(x,y,bombable)
	
	local wall={
		name="wall",
		x=x,
		y=y,
		width=8,
		height=8,
		bombable=bombable,
		update=function(self)

			player:check_for_collision_with_wall(self)
			if self.bombable==true then
				local b
				for b in all(bombs) do
					if b.exploding==true and b:check_for_collision_with_other_object(self)==true then
						del(walls, self)
					end
				end
			end

		end,
		draw=function(self)

			if self.bombable then 
				spr(17,self.x,self.y)
			else
				spr(1,self.x,self.y)
			end

		end
	}
	return wall

end

function make_bomb(x,y,dropped_while_player_facing)
	
	local bomb = {
		name="bomb",
		x=x,
		y=y,
		width=8,
		height=8,
		seconds_since_bomb_deployed=0,
		starting_time=global_timer,
		dropped_while_player_facing=dropped_while_player_facing,
		exploding=false,
		update=function(self)

			-- ensure bomb does not get stuck in wall
			local w
			for w in all(walls) do
				while are_object_rects_colliding(self, w)==true do
					if self.dropped_while_player_facing==0 then
						self.x += 1
					elseif self.dropped_while_player_facing==1 then
						self.x -= 1
					elseif self.dropped_while_player_facing==2 then
						self.y += 1
					elseif self.dropped_while_player_facing==3 then
						self.y -= 1
					end
				end
			end

			if global_timer==self.starting_time then
				self.seconds_since_bomb_deployed += 1
			end

			if self.exploding==true then
				if self.seconds_since_bomb_deployed==5 then
					del(bombs, self)
				end
			elseif self.seconds_since_bomb_deployed==4 then
				self.exploding = true
			end

			player:check_for_collision_with_wall(self)

		end,
		draw=function(self)

			if self.exploding==true then
				spr(33,self.x,self.y)
				spr(35,self.x+8,self.y)
				spr(35,self.x-8,self.y)
				spr(34,self.x,self.y+8)
				spr(34,self.x,self.y-8)
			else 
				spr(32,self.x,self.y)
			end	

		end,
		check_for_collision_with_other_object=function(self, other_obj)

			local horizontal_hitbox = {
				x = self.x - 8,
				y = self.y,
				width = self.width + 16,
				height = self.height
			} 
			local vertical_hitbox = {
				x = self.x,
				y = self.y - 8,
				width = self.width,
				height = self.height + 16
			} 

			if are_object_rects_colliding(horizontal_hitbox, other_obj) or are_object_rects_colliding(vertical_hitbox, other_obj) then
				return true
			else
				return false
			end

		end

	}
	return bomb

end

function make_enemy(x,y)

	local enemy={
		name="enemy",
		x=x,
		y=y,
		width=8,
		height=8,
		enemysprite=3,
		movement_dir=0,
		facing_right=false,
		speed=0.5,
		update=function(self)

			if self.x%8 == 0 and self.y%8==0 and flr(rnd(5))==4 then
				self.movement_dir=flr(rnd(4))
			end

			if self.movement_dir==0 then
				self.x -= self.speed
				facing_right = false
			elseif self.movement_dir==1 then
				self.x += self.speed
				facing_right = true
			elseif self.movement_dir==2 then
				self.y -= self.speed
			elseif self.movement_dir==3 then
				self.y += self.speed
			end

			local wall
			for wall in all(walls) do
				if are_object_rects_colliding(wall,self) then
					if self.movement_dir==0 then
						self.x += self.speed
						self.movement_dir = 1
					elseif self.movement_dir==1 then
						self.x -= self.speed
						self.movement_dir = 0				
					elseif self.movement_dir==2 then
						self.y += self.speed
						self.movement_dir = 3
					elseif self.movement_dir==3 then
						self.y -= self.speed
						self.movement_dir = 2
					end
				end
			end

		end,
		draw=function(self)

			if global_timer==29 then
				if enemysprite==4 then
					enemysprite=3
				elseif enemysprite==3 then
					enemysprite=4
				end
			end

			spr(enemysprite,self.x,self.y,1,1,facing_right)

		end
	}

	return enemy

end


__gfx__
0000000011111111333333330000000000aaa0000000000090077700000000000000000000000000000000000000000000000000000000000000000000000000
00000000155555513333333300aaa000099a5a000000000009075700900777000000000000000000000000000000000000000000000000000000000000000000
007007001555555133333333099a5a009999a000000aaa0000977700090757000000000000000000000000000000000000000000000000000000000000000000
0007700015555551333333339999a00000aa00000099a5a088999000809777000000000000000000000000000000000000000000000000000000000000000000
0007700015555551333333330aaa000a0aaaa00a09999a00090a0000089990000000000000000000000000000000000000000000000000000000000000000000
007007001555555133333333aaaaaaaaaaaaaaaaaaaaaaaa900a000a090a000a0000000000000000000000000000000000000000000000000000000000000000
000000001555555133333333aaaaaaa0aaaaaaa00aaaaaaa00aaaaaa900a00aa0000000000000000000000000000000000000000000000000000000000000000
0000000011111111333333330aaaaa000aaaaa0000aaaaa000aaaaa000aaaaa00000000000000000000000000000000000000000000000000000000000000000
00077700011101110000000000000000000000000000000000000000000000000000000000000000000000000000000000000000c000000c0000000000000000
0070007010555051008880000077700000777000007770000077700000777000007770000077700000777000000000000c0000c00c0000c00000000000000000
0022000905555501099a0a00088888000777070007770700077707000777070007770700077707000777070000c00c0000c00c0000c00c000000000000000000
02888000105555519999a0009999a000888880007777700077777000777770007777700077777000777770000000000000000000000000000000000000000000
2888e8001d0555d00aaa000a0aaa000a0aaa000a0888000a00700008007000000070000000700000007000000000000000000000000000000000000000000000
288888001d055501aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa888888887770707077707070777070707770707000c00c0000c00c0000c00c000000000000000000
2888880010505551aaaaaaa0aaaaaaa0aaaaaaa0aaaaaaa0aaaaaaa088888880888888807777777077777770000000000c0000c00c0000c00000000000000000
02222000011d01110aaaaa000aaaaa000aaaaa000aaaaa000aaaaa000aaaaa000aaaaa0008888800077777000000000000000000c000000c0000000000000000
00077700988998898889988888888888000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00700070898998988889988888888888000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00550009889999888889988888888888000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
05ddd000999999998889988899999999000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
5ddd6d00999999998889988899999999000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
5ddddd00889999888889988888888888000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
5ddddd00898998988889988888888888000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
05555000988998898889988888888888000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
07777770077777700777777000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
7f5ff5f707ff5f570777f5f000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
07777770077777700777777000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00cccc0000cccc0000cccc0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00cccc0000cccc0000cccc0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0ecccce000eccc0000cecc0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00c00c00000c0c000000c00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00c00c00000cc0000000cc0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
