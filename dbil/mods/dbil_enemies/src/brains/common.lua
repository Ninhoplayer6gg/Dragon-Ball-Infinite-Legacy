-- Shared AI helpers: perception, steering and jumping.

local enemies = dbil.enemies
local actors = dbil.actors
local cfg = dbil.config.enemies
local now = dbil.util.now

local ai = {}
enemies.ai = ai

function ai.face(self, pos)
	local p = self.object:get_pos()
	local dx, dz = pos.x - p.x, pos.z - p.z
	if dx * dx + dz * dz > 1e-4 then
		self.object:set_yaw(math.atan2(-dx, dz))
	end
end

function ai.is_knocked(self)
	return self._knock_until ~= nil and now() < self._knock_until
end

function ai.is_stunned(self)
	return self._stunned_until ~= nil and now() < self._stunned_until
end

--- Sets horizontal velocity, keeping the vertical one (gravity/jumps).
function ai.move(self, dir, speed)
	if ai.is_knocked(self) then
		return
	end
	local v = self.object:get_velocity()
	self.object:set_velocity(vector.new(dir.x * speed, v.y, dir.z * speed))
end

function ai.stop(self)
	if ai.is_knocked(self) then
		return
	end
	local v = self.object:get_velocity()
	self.object:set_velocity(vector.new(0, v.y, 0))
end

function ai.on_ground(self)
	local mr = self._moveresult
	return mr ~= nil and mr.touching_ground
end

--- Jumps when walking into an obstacle or a step up.
function ai.jump_if_blocked(self, dir)
	if not ai.on_ground(self) then
		return
	end
	local blocked = false
	local mr = self._moveresult
	if mr and mr.collides then
		for _, c in ipairs(mr.collisions) do
			if c.type == "node" and c.axis ~= "y" then
				blocked = true
				break
			end
		end
	end
	if not blocked then
		local p = self.object:get_pos()
		local ahead = vector.new(p.x + dir.x * 0.8, p.y + 0.5, p.z + dir.z * 0.8)
		local node = core.get_node_or_nil(ahead)
		local def = node and core.registered_nodes[node.name]
		blocked = def ~= nil and def.walkable ~= false
	end
	if blocked then
		local v = self.object:get_velocity()
		self.object:set_velocity(vector.new(v.x, self._def.jump, v.z))
	end
end

function ai.can_see(self, obj)
	return core.line_of_sight(actors.get_eye_pos(self.object), actors.get_center(obj))
end

--- Nearest visible hostile player within view range (players only; cheap).
function ai.find_target(self)
	local pos = self.object:get_pos()
	local range = self._def.view_range
	local best, best_d
	dbil.players.for_each_ready(function(player)
		if player:get_hp() > 0 and actors.are_hostile(self.object, player) then
			local d = vector.distance(pos, player:get_pos())
			if d <= cfg.despawn_distance then
				self._last_player_seen = now()
			end
			if d <= range and (not best_d or d < best_d) and ai.can_see(self, player) then
				best, best_d = player, d
			end
		end
	end)
	return best
end

function ai.target_valid(self, target)
	if not target or not actors.is_alive(target) then
		return false
	end
	local d = vector.distance(self.object:get_pos(), target:get_pos())
	return d <= self._def.view_range * cfg.lose_target_mult
end

function ai.distance_home(self)
	return vector.distance(self.object:get_pos(), self._home)
end
