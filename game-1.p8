pico-8 cartridge // http://www.pico-8.com
version 18
__lua__

local player
local bomb
local game_objects={}
local bomb_is_deployed = false
local global_timer = 0
local cam
local game_state = "menu"

function _init()

	for i=0,200,1 do 
		for j=0,200,1 do
			if mget(i,j)==1 then
				make_wall(i*8,j*8,8,8)
			end
			if mget(i,j)==17 then
				make_wall(i*8,j*8,8,8,true)
			end
			if mget(i,j)==3 then
				make_enemy(i*8,j*8,8,8)
			end
		end
	end

	player = make_protag(128,128,8,8)

	cam = {
		x=player.x-64,
		y=player.y-64
	}

end

function _update()

	if game_state=="menu" then
		update_menu()
	elseif game_state=="game" then
		update_game()
	end

	update_camera()
	
end

function _draw()

	if game_state=="menu" then
		draw_menu()
	elseif game_state=="dead" then
		draw_dead()
	elseif game_state=="game" then
		draw_game()
	end

end

function draw_menu()

	cls()
	print("pico-bomber\n")
	print("2019 lex leesch")
	print("\n\n\npress z to play")

end

function draw_dead()

	local game_over = "game over"
	rectfill(cam.x+56-#game_over*2,cam.y+64-8,(cam.x+64+#game_over*2)+8,cam.y+64+8,0)
	print(game_over,cam.x+64-#game_over*2,cam.y+61,8)

end

function draw_game()

	cls(3)

	camera(cam.x, cam.y)	

	local obj
	for obj in all(game_objects) do
		obj:draw()
	end

end

function update_menu()

	if btnp(4) then 
		game_state="game"
	end

end

function update_game()
	
	local obj
	for obj in all(game_objects) do
		obj:update()
	end

	update_global_timer()

end

function update_global_timer()

	global_timer += 1
	if global_timer==30 then
		global_timer = 0
	end

end

function update_camera()

	cam.x = player.x-64
	cam.y = player.y-64

end

function are_lines_overlapping(min1,max1,min2,max2)

	return max1 > min2 and max2 > min1

end

function are_rects_overlapping(left1,top1,right1,bottom1,left2,top2,right2,bottom2)

	return are_lines_overlapping(left1,right1,left2,right2) and are_lines_overlapping(top1,bottom1,top2,bottom2)

end

function are_object_rects_colliding(first,second)

	return are_rects_overlapping(first.x,first.y,first.x+first.width,first.y+first.height,second.x,second.y,second.x+second.width,second.y+second.height)

end

function for_each_game_object(name,callback)

	local obj
	for obj in all(game_objects) do
		if obj.name==name then
			callback(obj)
		end
	end

end

function make_game_object(x,y,width,height,properties)

	local obj = {
		x=x,
		y=y,
		width=width,
		height=height,
		dying=false,
		death_frame_counter=0,
		check_for_being_exploded=function(self)

			if bomb_is_deployed==true then
				local b
				for b in all(game_objects) do
					if b.name == "bomb" and b.exploding==true and b:check_for_collision_with_other_object(self)==true then
						self.dying=true
					end
				end
			end

		end,
		check_for_dead=function(self)

			if self.dying==false then
				return
			end
			if self.death_frame_counter==60 then
				self.dying=false
				self.death_frame_counter=0
				if self.name=="enemy" then
					del(game_objects,self)
				end
			else
				self.death_frame_counter += 1
			end

		end
	}

	local k,v
	for k,v in pairs(properties) do
		obj[k] = v
	end
	add(game_objects, obj)
	return obj

end

function make_protag(x,y,width,height)

	local player = make_game_object(x,y,width,height,
	{
		name="bomberman",
		facing=1, -- 0123 = lrud
		is_stuck=false,
		moving=false,
		current_sprite=48,
		draw=function(self)

			if self.is_stuck == true then
				print("oh no!",self.x+self.width+2,self.y-4,7)
			end

			spr(self.current_sprite,self.x,self.y)

		end,
		check_for_dead=function(self)

			game_state="dead"

		end,
		update=function(self)

			if self.is_stuck == true or self.dying==true then
				self:check_for_dead()
				return
			end

			self:check_for_being_exploded()

			-- In a bomberman-type game, it's weird if you can move diag, so limit to one direction at a time.
			-- TODO: it feels bad to stop when two keys are held, actually.
			self.moving=false
			if btn(0) and (self.y%8==0) and not (btn(1) or btn(2) or btn(3)) then -- left
				self.facing = 0
				self.moving = true
				self.x -= 1
			elseif btn(1) and (self.y%8==0) and not (btn(0) or btn(2) or btn(3)) then -- right
				self.facing = 1
				self.moving = true
				self.x += 1
			elseif btn(3) and (self.x%8==0) and not (btn(1) or btn(2) or btn(0)) then -- down
				self.facing = 3
				self.moving = true
				self.y += 1
			elseif btn(2) and (self.x%8==0) and not (btn(0) or btn(1) or btn(3)) then -- up
				self.facing = 2
				self.moving = true
				self.y -= 1
			end

			if self.moving==false then
				if not (self.x%8 == 0) then
					if self.facing==0 then
						self.x -= 1
					else
						self.x += 1
					end
				end
				if not (self.y%8 == 0) then
					if self.facing==2 then
						self.y -= 1
					else
						self.y += 1
					end
				end
			end
						
			if btnp(4) then -- space ?

				local bomb_x = self.x
				local bomb_y = self.y

				if self.facing == 0 then
					bomb_x = self.x - 8
				elseif self.facing == 1 then
					bomb_x = self.x + 8
				elseif self.facing == 2 then
					bomb_y = self.y - 8
				elseif self.facing == 3 then
					bomb_y = self.y + 8
				end

				if bomb_is_deployed == false then
					sfx(1)
					bomb = make_bomb(bomb_x,bomb_y,self.facing)
					bomb_is_deployed = true
				end
			end

		end,
		check_for_collision_with_wall = function(self,wall)

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
	})

	return player

end

function make_wall(x,y,width,height,bombable)
	
	local sprite
	if bombable==true then
		sprite=17
	else
		sprite=1
	end

	local wall = make_game_object(x,y,width,height,
	{
		name="wall",
		bombable=bombable,
		current_sprite=sprite,
		update=function(self)

			if abs(player.x - self.x) < 20 then
				player:check_for_collision_with_wall(self)
			end

			if self.bombable==true and bomb_is_deployed==true and abs(bomb.x - self.x) < 30 then
				local b
				for b in all(game_objects) do
					if b.name == "bomb" and b.exploding==true and b:check_for_collision_with_other_object(self)==true then
						del(game_objects, self)
					end
				end
			end

		end,
		draw=function(self)

			spr(self.current_sprite,self.x,self.y)

		end
	})

	return wall

end

function make_bomb(x,y,dropped_while_player_facing)
	
	local bomb = make_game_object(x,y,8,8,
	{
		name="bomb",
		seconds_since_bomb_deployed=0,
		starting_time=global_timer,
		dropped_while_player_facing=dropped_while_player_facing,
		exploding=false,
		colliding_with_wall=false,
		update=function(self)

			player_x_orig = player.x
			player_y_orig = player.y

			-- ensure bomb does not get stuck in wall
			local w
			for w in all(game_objects) do
				while w.name=="wall" and are_object_rects_colliding(self, w)==true do
					if self.dropped_while_player_facing==0 then
						self.x += 1
						if are_object_rects_colliding(self,player) and not player.is_stuck then
							player.x += 1
						end
					elseif self.dropped_while_player_facing==1 then
						self.x -= 1
						if are_object_rects_colliding(self,player) and not player.is_stuck then
							player.x -= 1
						end
					elseif self.dropped_while_player_facing==2 then
						self.y += 1
						if are_object_rects_colliding(self,player) and not player.is_stuck then
							player.y += 1
						end
					elseif self.dropped_while_player_facing==3 then
						self.y -= 1
						if are_object_rects_colliding(self,player) and not player.is_stuck then
							player.y -= 1
						end
					end
					for w in all(game_objects) do
						if w.name=="wall" and are_object_rects_colliding(w,player) then
							player.is_stuck = true
							player.x = player_x_orig
							player.y = player_y_orig
						end
					end
				end
			end

			if global_timer==self.starting_time then
				self.seconds_since_bomb_deployed += 1
			end

			if self.exploding==true then
				if self.seconds_since_bomb_deployed>=4 then
					del(game_objects, self)
					bomb_is_deployed = false
					bomb = nil
				end
			elseif self.seconds_since_bomb_deployed==3 then
				sfx(0)
				self.exploding = true
			end

			if player.is_stuck==false then
				player:check_for_collision_with_wall(self)
			end

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
	})

	for e in all(game_objects) do
		if e.name=="enemy" and are_object_rects_colliding(e,bomb) then
			e.bomb_placed_on_enemy = true
		end
	end
	
	return bomb

end

function make_enemy(x,y,width,height)

	local enemy = make_game_object(x,y,8,8,
	{
		name="enemy",
		current_sprite=3,
		movement_dir=0,
		facing_right=false,
		speed=0.5,
		bomb_placed_on_enemy=false,
		orig_dir=0,
		changed_dir=false,
		update=function(self)

			if self.dying==true then
				self:check_for_dead()
				return
			end

			self:check_for_being_exploded()

			if self.x%8 == 0 and self.y%8==0 and flr(rnd(4))==3 then
				self.changed_dir=true
				self.orig_dir=self.movement_dir
				self.movement_dir=flr(rnd(4))
			end

			self:move()

			local wall
			for wall in all(game_objects) do
				if (wall.name=="wall" or wall.name=="bomb") and are_object_rects_colliding(wall,self) then
					if wall.name=="bomb" and self.bomb_placed_on_enemy==true then
						return
					elseif self.movement_dir==0 then
						self.x += self.speed
						self.movement_dir = 1
						self:restore_dir()
					elseif self.movement_dir==1 then
						self.x -= self.speed
						self.movement_dir = 0		
						self:restore_dir()		
					elseif self.movement_dir==2 then
						self.y += self.speed
						self.movement_dir = 3
						self:restore_dir()
					elseif self.movement_dir==3 then
						self.y -= self.speed
						self.movement_dir = 2
						self:restore_dir()
					end
				end
			end

			self.bomb_placed_on_enemy=false

		end,
		draw=function(self)

			if global_timer==29 or global_timer==14 then
				if self.current_sprite==3 then
					self.current_sprite=4
				else 
					self.current_sprite=3
				end
			end

			spr(self.current_sprite,self.x,self.y,1,1,self.facing_right)

		end,
		restore_dir=function(self)

			if self.changed_dir==true then
				self.movement_dir=self.orig_dir
				self.orig_dir=0
				self.changed_dir=false
			end

		end,
		move=function(self)

			if self.movement_dir==0 then
				self.x -= self.speed
				self.facing_right = false
			elseif self.movement_dir==1 then
				self.x += self.speed
				self.facing_right = true
			elseif self.movement_dir==2 then
				self.y -= self.speed
			elseif self.movement_dir==3 then
				self.y += self.speed
			end

		end
	})

	return enemy

end


__gfx__
0000000011111111333333330000000000aaa00000000000900777000000000000000000000000000000000000000000eeeeeeee000000000000000000000000
00000000155555513333333300aaa000099a5a000000000009075700900777000d00000000000000000000000d000000eeeeeeee000000000000000000000000
007007001555555133333333099a5a009999a000000aaa000097770009075700000000000000000000000d0000000000eeeeeeee000000000000000000000000
0007700015555551333333339999a00000aa00000099a5a0889990008097770000000000000000000000ddd000000000eeeeeeee000000000000000000000000
0007700015555551333333330aaa000a0aaaa00a09999a00090a000008999000000000000000000000000d0000000000eeeeeeee000000000000000000000000
007007001555555133333333aaaaaaaaaaaaaaaaaaaaaaaa900a000a090a000a00000000000000000d00000000000d00eeeeeeee000000000000000000000000
000000001555555133333333aaaaaaa0aaaaaaa00aaaaaaa00aaaaaa900a00aa000d0000000000e00000000000000000eeeeeeee000000000000000000000000
0000000011111111333333330aaaaa000aaaaa0000aaaaa000aaaaa000aaaaa000000000000000000000000000000000eeeeeeee000000000000000000000000
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
07777770077777700777777007777770077777700000000000000000077777700777777007777770000000000000000000000000000000000000000000000000
7f5ff5f77f5ff5f77f5ff5f707ff5f570777f5f0000000000000000007ff5f570777f5f077777777000000000000000000000000000000000000000000000000
07777770077777700777777007777770077777700000000000000000077777700777777007777770000000000000000000000000000000000000000000000000
00cccc0000cccc0000cccc0000cccc0000cccc00000000000000000000cccc0000cccc0000cccc00000000000000000000000000000000000000000000000000
00cccc0000cccc0000cccce000cccc0000cccc00000000000000000000cccc0000cccc0000cccc00000000000000000000000000000000000000000000000000
0ecccce00ecccce000ddcc0000eccc0000cecc00000000000000000000eccc0000cecc000ecccce0000000000000000000000000000000000000000000000000
00c00c0000c00c000edd0c00000c0c000000c0000000000000000000000c0c000000c00000c00c00000000000000000000000000000000000000000000000000
00c00c0000dd0c0000000c00000cc0000000cc000000000000000000000cc0000000cc0000c00c00000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0
c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0
c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0
c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0
c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0
c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0
c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0
c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0
c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0
c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0
c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0
c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0
c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0
c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0
c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0
c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0
c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0
c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0
c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0
c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c010101010101010101010101010101010101010101010101010c0c0c0c0c0c0c0c0c0c0c0c0
c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0
c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c010000000000000000000000000000000000000000000000010c0c0c0c0c0c0c0c0c0c0c0c0
c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0
c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c010001000100010001000100010001000100010001000100010c0c0c0c0c0c0c0c0c0c0c0c0
c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0
c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c010000000000000000000000000000000000000000000000010c0c0c0c0c0c0c0c0c0c0c0c0
c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0
c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c010001000100010001000100010001000100010001000100010c0c0c0c0c0c0c0c0c0c0c0c0
c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0
c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c010000000000000000000000000000000000000000000000010c0c0c0c0c0c0c0c0c0c0c0c0
c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0
c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c010001000100010001000100010001000100010001000100010c0c0c0c0c0c0c0c0c0c0c0c0
c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0
c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c010000000000000000000000000000000000000000000000010c0c0c0c0c0c0c0c0c0c0c0c0
c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0
c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c010001000100010001000100010001000100010001000100010c0c0c0c0c0c0c0c0c0c0c0c0
c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0
c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c010000000000000000000000000000000000000000000000010c0c0c0c0c0c0c0c0c0c0c0c0
c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0
c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c010001000100010001000100010001000100010001000100010c0c0c0c0c0c0c0c0c0c0c0c0
c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0
c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c010000000000000000000000000000000000000000000000010c0c0c0c0c0c0c0c0c0c0c0c0
c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0
c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c010001000100010001000100010001000100010001000100010c0c0c0c0c0c0c0c0c0c0c0c0
c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0
c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c010000000000000000000000000000000000000000000000010c0c0c0c0c0c0c0c0c0c0c0c0
c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0
c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c010001000100010001000100010001000100010001000100010c0c0c0c0c0c0c0c0c0c0c0c0
c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0
c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c010000000000000000000000000000000000000000000000010c0c0c0c0c0c0c0c0c0c0c0c0
c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0
c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c010101010101010101010101010101010101010101010101010c0c0c0c0c0c0c0c0c0c0c0c0
c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0
c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0
c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0
c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0
c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0
c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0
c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0
c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0
c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0
c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0
c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0
c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0
__map__
0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c
0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c
0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c
0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c
0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c
0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c
0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c
0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c
0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c
0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c
0c0c0c0c0c0c0c0c0c0c0c0c010101010101010101010101010101010101010101010101010c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c
0c0c0c0c0c0c0c0c0c0c0c0c010000000000000000000000000011000000000000000000010c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c
0c0c0c0c0c0c0c0c0c0c0c0c010001000100010001000100010001000100010001000100010c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c
0c0c0c0c0c0c0c0c0c0c0c0c010000000000000000000000000011000000000000000000010c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c
0c0c0c0c0c0c0c0c0c0c0c0c010001000100010001000100010001000100010001000100010c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c
0c0c0c0c0c0c0c0c0c0c0c0c010000000000000000000000000311000000000000000000010c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c
0c0c0c0c0c0c0c0c0c0c0c0c010001000100010001000100010001000111011101000100010c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c
0c0c0c0c0c0c0c0c0c0c0c0c010000000000030000000000110011000000002500000000010c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c
0c0c0c0c0c0c0c0c0c0c0c0c010001260100010001000100010001000100010001000100010c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c
0c0c0c0c0c0c0c0c0c0c0c0c010000000000110000001100000000001100000000000026010c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c
0c0c0c0c0c0c0c0c0c0c0c0c010001000100011101110111011101000100010001000126010c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c
0c0c0c0c0c0c0c0c0c0c0c0c010000000011000000030000000000000000000000000003010c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c
0c0c0c0c0c0c0c0c0c0c0c0c010001000100010001000100010001000111011101000100010c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c
0c0c0c0c0c0c0c0c0c0c0c0c010000000000000000000011001100000025000000000000010c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c
0c0c0c0c0c0c0c0c0c0c0c0c010001000100010001000100010001000100010001000111010c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c
0c0c0c0c0c0c0c0c0c0c0c0c010000000011000000001100002500000000000000001103010c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c
0c0c0c0c0c0c0c0c0c0c0c0c010101010101010101010101010101010101010101010101010c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c
0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c
0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c
0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c
0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c
0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c
__sfx__
00050000096100d6101061014610156101761018610186101861017610156101461013610116100f6100c6100a6100761004610026100061000610006000d6000060001600016000160000600006000060000600
00010000003100131005310083100c3101031013310163101831018310183101631013310103100d3100931005310023100030002300003000000000000000000000000000000000000000000000000000000000
