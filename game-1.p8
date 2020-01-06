pico-8 cartridge // http://www.pico-8.com
version 18
__lua__

player=nil
bomb=nil
game_objects={}
background_tiles={}
bomb_is_deployed=false
current_level=1
levels={}
global_timer=0
cam=nil
game_state="menu"
sky=nil

function _init()

	init_levels()
	load_level(1)

	player=make_protag(levels[current_level].player_spawn_x,levels[current_level].player_spawn_y,8,8)

	cam={
		x=player.x-64,
		y=player.y-64
	}

	local cur_level=levels[1]
	sky=init_sky(cur_level.lower_bound_x*8,cur_level.lower_bound_y*8,(cur_level.upper_bound_x*8)+100,(cur_level.upper_bound_y*8)+100,750)

end

function _update()

	if game_state=="menu" then
		update_menu()
	elseif game_state=="game" then
		update_game()
	elseif game_state=="paused" then
		update_pause()
	elseif game_state=="level complete" then
		update_level_complete()
	end

	update_camera()
	
end

function _draw()

	if game_state=="menu" then
		draw_menu()
	elseif game_state=="dead" then
		draw_text_box("GAME OVER",8)
	elseif game_state=="game" then
		draw_game()
	elseif game_state=="paused" then
		draw_text_box("pause",7)
	elseif game_state=="level complete" then
		draw_text_box("rock on!!!",7)
	end

end

function draw_menu()

	cls()
	print("pico-bomber\n")
	print("2019 lex leesch")
	print("\n\n\npress z to play")

end

function draw_text_box(text, color)

	rectfill(cam.x+56-#text*2,cam.y+64-8,(cam.x+64+#text*2)+8,cam.y+64+8,0)
	print(text,cam.x+64-#text*2,cam.y+61,color)

end

function draw_game()

	cls(3)

	camera(cam.x, cam.y)

	sky:draw()

	local tile
	for tile in all(background_tiles) do
		if tile.x>(cam.x)-8 and tile.x<(cam.x+128) and tile.y>(cam.y)-8 and tile.y<(cam.y+128) then
			tile:draw()
		end
	end

	local obj
	for obj in all(game_objects) do
		if obj.x>(cam.x)-8 and obj.x<(cam.x+128) and obj.y>(cam.y)-8 and obj.y<(cam.y+128) then
			obj:draw()
		end
	end

end

function init_sky(lower_bound_x,lower_bound_y,upper_bound_x,upper_bound_y,star_count)

	local sky={
		lower_bound_x=lower_bound_x,
		lower_bound_y=lower_bound_y,
		upper_bound_x=upper_bound_x,
		upper_bound_y=upper_bound_y,
		star_count=star_count,
		stars={},
		get_random_star_position=function(self,x_or_y)
			if x_or_y=="x" then
				return rnd(self.upper_bound_x-self.lower_bound_x) + self.lower_bound_x
			else
				return rnd(self.upper_bound_y-self.lower_bound_y) + self.lower_bound_y
			end
		end,
		get_layer_multiplier=function(self,layer)
			local layer_multiplier
			if layer==1 then
				layer_multiplier=1
			elseif layer==2 then
				layer_multiplier=0.75
			elseif layer==3 then
				layer_multiplier=0.50
			end
			return layer_multiplier
		end,
		create_star=function(self,random_x)
			local star_x
			if random_x==true then
				star_x=self:get_random_star_position("x")
			else
				star_x=self.upper_bound_x
			end
			local colr = flr(rnd(15)) + 1
			-- 1 in 700 chance its a planet
			if (flr(rnd(700))+1) == 1 then
				add(self.stars, init_star(star_x, self:get_random_star_position("y"),18,colr,1,.005))
			end
			-- 1 in 75 chance it uses a sprite
			if (flr(rnd(75))+1) == 1 then
				colr=rnd(4) + 16
			end

			local layer = flr(rnd(3)) + 1
			local layer_multiplier=self:get_layer_multiplier(layer)

			local radius = flr(rnd(2 * 100)) / 100
			local speed = .2*layer_multiplier
			radius=radius*layer_multiplier
			add(self.stars, init_star(star_x, self:get_random_star_position("y"),radius,colr,layer,speed))
		end,
		draw=function(self)
			rectfill(self.lower_bound_x,self.lower_bound_y,self.upper_bound_x,self.upper_bound_y,0)
			for star in all(self.stars) do
				star:draw()
				local layer_multiplier=self:get_layer_multiplier(star.layer)
				star.x=star.x-star.speed
				if star.x<self.lower_bound_x then
					del(self.stars,star)
				end
			end
			if count(self.stars)<self.star_count then
				self:create_star(false)
			end
		end
	}

	for i=0,sky.star_count,1 do
		sky:create_star(true)
	end

	return sky

end

function init_star(x, y, radius, colr, layer, speed)

	local star={
		x=x,
		y=y,
		speed=speed,
		radius=radius,
		colr=colr,
		layer=layer,
		draw=function(self)
			if self.colr>15 then
				spr(self.colr-8,self.x,self.y)
				return
			end
			color(self.colr)
			circfill(self.x,self.y,self.radius)
		end
	}
	return star

end

function update_menu()

	if btnp(4) then 
		game_state="game"
	end

end

function update_game()
	
	local obj

	if not are_any_enemies_still_alive() then
		game_state="level complete"
	end

	for obj in all(game_objects) do
		obj:update()
	end

	update_global_timer()

end

function update_pause()
	if btnp(5) then
		game_state="game"
	end
end

level_complete_frame_counter = 0
function update_level_complete()
	
	level_complete_frame_counter+=1
	if level_complete_frame_counter==120 then
		current_level=current_level+1
		level_complete_frame_counter=0
		load_level(current_level)
		player=make_protag(levels[current_level].player_spawn_x,levels[current_level].player_spawn_y,8,8)
		game_state="game"
	end

end

function init_levels()

	make_level(1,0,38,0,28,128,128)
	make_level(2,8,20,42,58,72,344)
	
end

function load_level(level_number)

	background_tiles={}
	game_objects={}
	local level_to_load=levels[level_number]
	sky=init_sky((level_to_load.lower_bound_x*8)-100,(level_to_load.lower_bound_y*8)-100,(level_to_load.upper_bound_x*8)+100,(level_to_load.upper_bound_y*8)+100,750)

	for i=level_to_load.lower_bound_x,level_to_load.upper_bound_x,1 do 
		for j=level_to_load.lower_bound_y,level_to_load.upper_bound_y,1 do
			if mget(i,j)==1 then
				make_wall(i*8,j*8,8,8)
			end
			if mget(i,j)==17 then
				make_background_tile(i*8,j*8,36)
				make_wall(i*8,j*8,8,8,true)
			end
			if mget(i,j)==2 then
				make_background_tile(i*8,j*8,2)
			end
			if mget(i,j)==36 then
				make_background_tile(i*8,j*8,36)
			end
		end
	end
	-- make enemies last so their animation isnt blocked
	for i=level_to_load.lower_bound_x,level_to_load.upper_bound_x,1 do 
		for j=level_to_load.lower_bound_y,level_to_load.upper_bound_y,1 do
			if mget(i,j)==3 then
				make_background_tile(i*8,j*8,36)
				make_enemy(i*8,j*8,8,8)
			end
		end
	end

end

function make_level(level_number, lower_bound_x, upper_bound_x, lower_bound_y, upper_bound_y, player_spawn_x, player_spawn_y)

	local level={
		level_number=level_number,
		lower_bound_x=lower_bound_x,
		upper_bound_x=upper_bound_x,
		lower_bound_y=lower_bound_y,
		upper_bound_y=upper_bound_y,
		player_spawn_x=player_spawn_x,
		player_spawn_y=player_spawn_y
	}

	add(levels, level)


end

function are_any_enemies_still_alive()

	for obj in all(game_objects) do
		if obj.name=="enemy" then
			return true
		end
	end
	return false

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

--test_rect:draw()
--sspr(0,24,8,8,test_rect.ulx,test_rect.uly,test_rect.lrx-test_rect.ulx,test_rect.lry-test_rect.uly)
function create_sprite_rect(x0, y0, x1, y1, shrink_bound, grow_bound)

	local rect = {
		x0=x0,
		y0=y0,
		x1=x1,
		y1=y1,
		increase_num=0,
		growing_or_shrinking="growing",
		ulx=x0,
		uly=y0,
		lrx=x1,
		lry=y1,
		update=function(self)

			local num_to_add=1
			if self.growing_or_shrinking=="shrinking" then
				num_to_add=-1
			end
			self.increase_num=self.increase_num+num_to_add

			if self.increase_num==grow_bound and self.growing_or_shrinking=="growing" then
				self.growing_or_shrinking="shrinking"
			elseif -(self.increase_num)==shrink_bound and self.growing_or_shrinking=="shrinking" then
				self.growing_or_shrinking="growing"
			end

			self.ulx=self.x0-self.increase_num
			self.uly=self.y0-self.increase_num
			self.lrx=self.x1+self.increase_num
			self.lry=self.y1+self.increase_num

		end
	}

	return rect

end

function make_background_tile(x,y,sprite_num)

	local tile={
		x=x,
		y=y,
		sprite_num=sprite_num,
		draw=function(self)
			palt(0, false)
			spr(self.sprite_num,self.x,self.y)
			palt(0, true)
		end
	}

	add(background_tiles, tile)
	return tile

end


function make_game_object(x,y,width,height,properties)

	local obj={
		x=x,
		y=y,
		width=width,
		height=height,
		dying=false,
		dead=false,
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
				else
					self.dead=true
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
		facing=3, -- 0123 = lrud
		is_stuck=false,
		moving=false,
		current_sprite=58,
		sprite_ascending=true,
		death_frame_timer=0,
		walk_frame_timer=0,
		sprite_flipped=false,
		draw=function(self)

			if self.is_stuck == true then
				print("oh no!",self.x+self.width+2,self.y-4,7)
			end

			if self.is_stuck==true or self.dying==true or self.dead==true then
				self:animate_dying()
			elseif self.facing==3 then 
				if self.moving==true then
					if self.walk_frame_timer==3 then 
						self.current_sprite=59
						self.sprite_flipped=false
					elseif self.walk_frame_timer==6 or self.walk_frame_timer==12 then
						self.current_sprite=58
					elseif self.walk_frame_timer==9 then
						self.current_sprite=59
						self.sprite_flipped=true
					end
					self.walk_frame_timer=self.walk_frame_timer+1
				else
					self.current_sprite=58
				end
			elseif self.facing==1 then
				self.sprite_flipped=false
				if self.moving==true then
					if self.walk_frame_timer==3 or self.walk_frame_timer==9 then 
						self.current_sprite=61
					elseif self.walk_frame_timer==6 or self.walk_frame_timer==12 then
						self.current_sprite=60
					end
					self.walk_frame_timer=self.walk_frame_timer+1
				else
					self.current_sprite=60
				end
			elseif self.facing==0 then
				self.sprite_flipped=true
				if self.moving==true then
					if self.walk_frame_timer==3 or self.walk_frame_timer==9 then 
						self.current_sprite=61
					elseif self.walk_frame_timer==6 or self.walk_frame_timer==12 then
						self.current_sprite=60
					end
					self.walk_frame_timer=self.walk_frame_timer+1
				else
					self.current_sprite=60
				end
			elseif self.facing==2 then
				if self.moving==true then
					if self.walk_frame_timer==3 then 
						self.current_sprite=63
						self.sprite_flipped=false
					elseif self.walk_frame_timer==6 or self.walk_frame_timer==12 then
						self.current_sprite=62
					elseif self.walk_frame_timer==9 then
						self.current_sprite=63
						self.sprite_flipped=true
					end
					self.walk_frame_timer=self.walk_frame_timer+1
				else
					self.current_sprite=62
				end
			end
			spr(self.current_sprite-16,self.x,self.y-8,1,1,self.sprite_flipped)
			spr(self.current_sprite,self.x,self.y,1,1,self.sprite_flipped)

			if self.walk_frame_timer==13 then
				self.walk_frame_timer=0
			end

		end,
		animate_dying=function(self)

			if self.death_frame_timer==29 then
				self.death_frame_timer=0
			else 
				self.death_frame_timer += 1
			end

			if self.current_sprite>50 then
				self.current_sprite=29
			elseif self.current_sprite==29 and self.death_frame_timer==09 then
				self.current_sprite=30
			elseif self.current_sprite==30 and self.death_frame_timer==19 then
				self.current_sprite=31
			elseif self.current_sprite==31 and self.death_frame_timer==29 then
				self.current_sprite=30
			elseif self.current_sprite==30 and self.death_frame_timer==09 then
				self.current_sprite=29
			end			

		end,
		update=function(self)

			if self.dead==true then
				game_state="dead"
				return
			end

			self:check_for_being_exploded()

			if self.is_stuck==true or self.dying==true then
				self:check_for_dead()
				return
			end

			self:check_for_collision_with_enemy()

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
					bomb = make_bomb(bomb_x,bomb_y,self.facing)
					bomb_is_deployed = true
				end
			end

			if btnp(5) then
				game_state="paused"
			end

		end,
		check_for_collision_with_enemy=function(self)

			local e
			for e in all(game_objects) do
				if e.name=="enemy" and (not e.dying) and abs(e.x - self.x) < 30 and abs(e.y - self.y) < 30 and are_object_rects_colliding(self,e)==true then
					self.dying=true
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

			palt(0, false)
			spr(self.current_sprite,self.x,self.y)
			palt(0, true)

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
		growth_rect=create_sprite_rect(x,y,x+8,y+8,0,2),
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
				self.exploding = true
			end

			if player.is_stuck==false then
				player:check_for_collision_with_wall(self)
			end

		end,
		draw=function(self)

			if self.exploding==true then
				if global_timer%3==1 then
					pal(9, 8)
					pal(8, 9)
				end
				spr(33,self.x,self.y)
				spr(35,self.x+8,self.y)
				spr(35,self.x-8,self.y,1,1,true)
				spr(34,self.x,self.y+8,1,1,false,true)
				spr(34,self.x,self.y-8)
				pal()
			else 
				if global_timer%2==1 then
					self.growth_rect:update()
					self.growth_rect.x0=self.x
					self.growth_rect.x1=self.x+8
					self.growth_rect.y0=self.y
					self.growth_rect.y1=self.y+8
				end

				sspr(0,16,8,8,self.growth_rect.ulx,self.growth_rect.uly,self.growth_rect.lrx-self.growth_rect.ulx,self.growth_rect.lry-self.growth_rect.uly)
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
		growth_rect=create_sprite_rect(x,y,x+8,y+8,1,4),
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

			if self.dying==true then
				self.growth_rect.x0=self.x
				self.growth_rect.x1=self.x+8
				self.growth_rect.y0=self.y
				self.growth_rect.y1=self.y+8
				self.growth_rect:update()
				if self.current_sprite==3 then
					sspr(48,0,8,8,self.growth_rect.ulx,self.growth_rect.uly,self.growth_rect.lrx-self.growth_rect.ulx,self.growth_rect.lry-self.growth_rect.uly,self.facing_right)
				else
					sspr(40,0,8,8,self.growth_rect.ulx,self.growth_rect.uly,self.growth_rect.lrx-self.growth_rect.ulx,self.growth_rect.lry-self.growth_rect.uly,self.facing_right)
				end
			else
				spr(self.current_sprite,self.x,self.y,1,1,self.facing_right)
			end

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
0000000066666666000000000000000000777000000000009007770000000000000090a000e0000e0000000000000000eeeeeeee000000000000000000000000
00000000dd5555dd5050505000777000094656000000000009075700900777000009990a000e00e00000000000066000eeeeeeee000000000000000000000000
00700700d511115d05050505094656004444600000077700004777000907570000999a990020ee00000ff000006dd600eeeeeeee000000000000000000000000
00077000d511115d535353534444600000760000009465608244400080477700098a909002000e000ffffff006d77d60eeeeeeee000000000000000000000000
00077000151111513535353507660007076670070444460004060000024440000888a900020e00e00ffffff006d77d60eeeeeeee076666700766667007666670
00700700151111513333333376667776766667767666677740060007040700070888900000e0020e000ff000006dd600eeeeeeee7666666776666667755ff557
0000000011555511333333336666666066666660066666660077777640070076098900000e0220000000000000066000eeeeeeee7666666776666667ccffffcc
000000001111111133333333066666000666660000666660006666600066666000900000e00000000000000000000000eeeeeeee66666666655ff556cf2222fc
000777000666600600000000000000000000000000000000000000000000000000000000000000000000000000000000c000000c77777777ccffffccc222222c
00700070005500dd0088800000777000007770000077700000777000007770000077700000777000000000000c0000c00c0000c0c55ff55ccf2222fcc222222c
00220009d000115d099606000888880007770700077707000777070007770700077707000777070000c00c0000c00c0000c00c00cc2222ccc222222cc222222c
02888000d51100009999600099996000888880007777700077777000777770007777700077777000000000000000000000000000c228822cc228822cc228822c
2888e800151101500777000707770007077700070888000700700008007000000070000000700000000000000000000000000000cffffffccffffffccffffffc
2888880015001051766677767666777676667776766677768888888877707070777070707770707000c00c0000c00c0000c00c007cddddc77cddddc77cddddc7
28888800000050116666666066666660666666606666666066666660888888807777777077777770000000000c0000c00c0000c00eeeeee00eeeeee00eeeeee0
022220000001110106666600066666000666660006666600066666000666660008888800077777000000000000000000c000000c500000055000000550000005
00077700988998890089980088888800333333331111111100000000000777000007770000077700000000000000000000000000000000000000000000000000
00600060898998980889988088888880333333331111111100000000006000600060006000700070000000000000000000000000000000000000000000000000
00dd000988999988888998888888888833333333111111110000000000dd00090022000900880009077777700777777007777770077777700777777007777770
05ddd00099999999888998889999999933333333111111110000000005ddd0000122200002888000776666777766667777666667776666677766667777666677
5ddd6d009999999988899888999999993333333311111111000000005ddd6d00122262002888e800766666677666666776666666766666667666666776666667
5ddddd008899998888899888888888883333333311111111000000005ddddd001222220028888800666666666666666666666666666666666666666666666666
5ddddd008989989888899888888888803333333300000000000000005ddddd00122222002888880066155166661551666665515f6665515f6666666666666666
0555500098899889888998888888880033333333000000000000000005555000011110000222200006ffff6006ffff60066ffff0066ffff00666666006666660
0000000000000000000000000000000000000000000000000000000000000000000000000000000000cccc0000cccc0000cccc0000cccc0000cccc0000cccc00
000000000000000000000000000000000000000000000000000000000000000000000000000000000cddddc00cddddc00cddddc00cddddc00cddddc00cddddc0
000000000000000000000000000000000000000000000000000000000000000000000000000000000dddddd00dddddd00dddddd00dddddd00dddddd00dddddd0
000000000000000000000000000000000000000000000000000000000000000000000000000000007dddddd77dddddd70dd67dd0067dddd07dddddd77dddddd7
000000000000000000000000000000000000000000000000000000000000000000000000000000006eeeeee6655eeee600e66e00066eee056eeeeee66eeeeee6
000000000000000000000000000000000000000000000000000000000000000000000000000000000e2002e0055002e0000ee200002eeee50e2002e0522002e0
00000000000000000000000000000000000000000000000000000000000000000000000000000000020000200000002000022000522202250200002055000020
00000000000000000000000000000000000000000000000000000000000000000000000000000000550000550000005500055550555000005500005500000055
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
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000032
63636363636363636363636263636363636363636363636363636363636363636363636363636363838363636363636363636363636363636363636363434343
43434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343
63636363636363636363636363636363636363636363636363636363636363636363636363636363836363636363636363636363636363636363636363434343
43434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343
62626262626262626363636363636363636363636363636363636363636363636363636363636363636363636363636363636363636363636363636363434343
43434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343
62626262626262626363636363636363636363636363636363636363636363636363636363636363636363636363636363636363636363636363636363434343
43434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343
62626262626262626363636363636363636363636363636363636363636363636363636363636363636363636363636363636363636363636363636363434343
43434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343
43434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343
43434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343
43434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343
43434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343
43434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343
43434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343
43434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343
43434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343
43434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343
43434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343
43434343434343431010101010101010101010101043434343434343434343434343434343434343434343434343434343434343434343434343434343434343
43434343434343434343434343434343434343434343434343434310101010101010101010101010101010101010101010101010434343434343434343434343
43434343434343431020202020112020203020201043434343434343434343434343434343434343434343434343434343434343434343434343434343434343
43434343434343434343434343434343434343434343434343434310000000000000000000000000000000000000000000000010434343434343434343434343
43434343434343431042104210111011101110111043434343434343434343434343434343434343434343434343434343434343434343434343434343434343
43434343434343434343434343434343434343434343434343434310001000100010001000100010001000100010001000100010434343434343434343434343
43434343434343431042204220112042203020421043434343434343434343434343434343434343434343434343434343434343434343434343434343434343
43434343434343434343434343434343434343434343434343434310002000200020002000200020002000200020002000200010434343434343434343434343
43434343434343431011101110111011101110111043434343434343434343434343434343434343434343434343434343434343434343434343434343434343
43434343434343434343434343434343434343434343434343434310001000100010001000100010001000100010001000100010434343434343434343434343
43434343434343431042204220422011203020421043434343434343434343434343434343434343434343434343434343434343434343434343434343434343
43434343434343434343434343434343434343434343434343434310002000200020002000200020002000200020002000200010434343434343434343434343
43434343434343431042104210421011101110111043434343434343434343434343434343434343434343434343434343434343434343434343434343434343
43434343434343434343434343434343434343434343434343434310001000100010001000100010001000100010001000100010434343434343434343434343
43434343434343431042204220112011203020421043434343434343434343434343434343434343434343434343434343434343434343434343434343434343
43434343434343434343434343434343434343434343434343434310002000200020002000200020002000200020002000200010434343434343434343434343
43434343434343431042104210421042104210421043434343434343434343434343434343434343434343434343434343434343434343434343434343434343
43434343434343434343434343434343434343434343434343434310001000100010001000100010001000100010001000100010434343434343434343434343
43434343434343431042204220112011203020421043434343434343434343434343434343434343434343434343434343434343434343434343434343434343
43434343434343434343434343434343434343434343434343434310002000200020002000200020002000200020002000200010434343434343434343434343
43434343434343431042104210421042104210421043434343434343434343434343434343434343434343434343434343434343434343434343434343434343
43434343434343434343434343434343434343434343434343434310001000100010001000100010001000100010001000100010434343434343434343434343
43434343434343431042201120422011203020421043434343434343434343434343434343434343434343434343434343434343434343434343434343434343
43434343434343434343434343434343434343434343434343434310002000200020002000200020002000200020002000200010434343434343434343434343
43434343434343431042104210421042104210421043434343434343434343434343434343434343434343434343434343434343434343434343434343434343
43434343434343434343434343434343434343434343434343434310001000100010001000100010001000100010001000100010434343434343434343434343
43434343434343431042201120422011203020421043434343434343434343434343434343434343434343434343434343434343434343434343434343434343
43434343434343434343434343434343434343434343434343434310002000200020002000200020002000200020002000200010434343434343434343434343
43434343434343431042104210421042104210421043434343434343434343434343434343434343434343434343434343434343434343434343434343434343
43434343434343434343434343434343434343434343434343434310001000100010001000100010001000100010001000100010434343434343434343434343
43434343434343431042204220112042203020421043434343434343434343434343434343434343434343434343434343434343434343434343434343434343
43434343434343434343434343434343434343434343434343434310002000200020002000200020002000200020002000200010434343434343434343434343
43434343434343431010101010101010101010101043434343434343434343434343434343434343434343434343434343434343434343434343434343434343
43434343434343434343434343434343434343434343434343434310101010101010101010101010101010101010101010101010434343434343434343434343
43434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343
43434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343
43434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343
43434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343
43434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343
43434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343
43434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343
43434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343
43434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343
43434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343
__map__
3434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434
3434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434
3434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434
3636363636363636363636363636363636363636363636363636363636363636363636363636363636363636363636363636363636363636363636363634343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434
3636363636363636363636363636363636363636363636363636363636363636363636363636363638363636363636363636363636363636363636363634343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434
3636363636363636363636363636363636363636363636363636363636363636363636363636363638383636363636363636363636363636363636363634343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434
3636363636363636363636363636363636363636363636363636363636363636363636363636363838383636363636363636363636363636363636363634343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434
3636363636363636363636263636363636363636363636363636363636363636363636363636363838363636363636363636363636363636363636363634343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434
3636363636363636363636263636363636363636363636363636363636363636363636363636363838363636363636363636363636363636363636363634343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434
3636363636363636363636263636363636363636363636363636363636363636363636363636383638383636363636363636363636363636363636363634343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434
3636363636363636363636260101010101010101010101010101010101010101010101010136383638383636363636363636363636363636363636363634343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434
3636363636363636363636260102020202020202020202010202110202020202020202020136383838383636363636363636363636363636363636363634343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434
3636363636363636363636260124012401240124012401010124012401240124012401240136363838363636363636363636363636363636363636363634343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434
3636363636363636363636260124022402240224022402010224112402240224022402240136363838363636363636363636363636363636363636363634343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434
3636363636363636363636260124012401240124012401010124012401240124012401240136363638363636363636363636363636363636363636363634343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434
3636363636363636363636260124022402240224022402010224112402240224022402240136363638363636363636363636363636363636363636363634343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434
3636363636363636363636260124012401240124012401010124012401110111012401240136363638363636363636363636363636363636363636363634343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434
3636363636363636363636260124022402240224022402011124112402240224022402240136363638363636363636363636363636363636363636363634343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434
3636363636363636363636260124010101240101010101010124012401240124012401240136363838363636363636363636363636363636363636363634343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434
3636363636363636363636260124020202240102020211020203022411240224022402240136363638383636363636363636363636363636363636363634343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434
3636363636363636363636260124012401240111011101110111012401240124012401010136363838383636363636363636363636363636363636363634343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434
3636363636363636363636260124022402010224022402240224022402240224022402020136363838383836363636363636363636363636363636363634343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434
3636363636363636363636260124012401020124012401240124012401110111012401240136363838363836363636363636363636363636363636363634343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434
3636363636363636363636260124022411031124022402110211020302240224022402240136363638363836363636363636363636363636363636363634343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434
3636363636363636363636260124012401240124012401240124012401240124012401110136363838363636363636363636363636363636363636363634343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434
3636363636363636363636260124022402010224022411240224022402240224022411030136363638383636363636363636363636363636363636363634343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434
3636363636363636363636260101010101010101010101010101010101010101010101010136363638383636363636363636363636363636363636363634343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434
3636363636363636363636262525252525252525252525252525252525252525252525252536363638383636363636363636363636363636363636363634343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434
3636363636363636363636263636363636363636363636363636363636363636363636363636363638383636363636363636363636363636363636363634343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434
3636363636363636363636263636363636363636363636363636363636363636363636363636363638383636363636363636363636363636363636363634343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434
3636363636363636363636263636363636363636363636363636363636363636363636363636363638383636363636363636363636363636363636363634343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434
3636363636363636363636263636363636363636363636363636363636363636363636363636363638383636363636363636363636363636363636363634343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434
__sfx__
00050000096100d6101061014610156101761018610186101861017610156101461013610116100f6100c6100a6100761004610026100061000610006000d6000060001600016000160000600006000060000600
00010000003100131005310083100c3101031013310163101831018310183101631013310103100d3100931005310023100030002300003000000000000000000000000000000000000000000000000000000000
000800000f45113451194511e451214512445125451264512645125451234511e451154510d451134511645118451184511845116451124510d45108451074510a4510c4510d4510e4510d4510c4510945103451
000400000e55010550155501a55020550265502a5500b55011550165501a5501e550215500d550125501555018550065300a5300c5300f5300f53003530045300553006530065300053000530005200052000510
