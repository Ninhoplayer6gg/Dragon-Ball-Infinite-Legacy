-- Actors: one interface for every fighter, player or NPC.
--
-- Combat, techniques, targeting and the future Scouter talk to actors only,
-- so NPCs (enemies, masters, allies, bosses) and players share the same
-- damage pipeline and technique system.
--
-- A Lua entity becomes an actor by setting `_dbil_actor = true` and
-- implementing these methods (see dbil_enemies for the reference):
--   self:dbil_get_name()         display name
--   self:dbil_get_team()         team id ("enemies", "players", ...)
--   self:dbil_get_power()        current Power Level
--   self:dbil_get_derived()      table with melee_mult, ki_mult, defense
--   self:dbil_get_hp(), self:dbil_get_max_hp()
--   self:dbil_is_alive()
--   self:dbil_receive_damage(info)   apply final damage (see dbil_combat)
--   self:dbil_get_look_dir()
-- and calling dbil.actors.track(self) / dbil.actors.untrack(self).

local actors = {}
dbil.actors = actors

local tracked = {} -- luaentity -> true

function actors.track(ent)
	tracked[ent] = true
end

function actors.untrack(ent)
	tracked[ent] = nil
end

--- Returns the actor luaentity of an object, if it is one.
function actors.entity(obj)
	if not obj or obj:is_player() then
		return nil
	end
	local ent = obj:get_luaentity()
	if ent and ent._dbil_actor then
		return ent
	end
	return nil
end

function actors.is_actor(obj)
	if not obj or not obj:is_valid() then
		return false
	end
	if obj:is_player() then
		return dbil.players.is_ready(obj)
	end
	return actors.entity(obj) ~= nil
end

function actors.is_alive(obj)
	if not actors.is_actor(obj) then
		return false
	end
	if obj:is_player() then
		return obj:get_hp() > 0
	end
	return actors.entity(obj):dbil_is_alive()
end

function actors.get_name(obj)
	if obj:is_player() then
		local char = dbil.players.get_character(obj)
		return char and char.name or obj:get_player_name()
	end
	local ent = actors.entity(obj)
	return ent and ent:dbil_get_name() or "?"
end

function actors.get_team(obj)
	if obj:is_player() then
		return "players"
	end
	local ent = actors.entity(obj)
	return ent and ent:dbil_get_team() or "neutral"
end

function actors.get_power(obj)
	if obj:is_player() then
		return dbil.power.get_current(obj)
	end
	local ent = actors.entity(obj)
	return ent and ent:dbil_get_power() or 0
end

function actors.get_derived(obj)
	if obj:is_player() then
		return dbil.stats.derived(obj)
	end
	local ent = actors.entity(obj)
	return ent and ent:dbil_get_derived()
end

function actors.get_hp(obj)
	if obj:is_player() then
		return obj:get_hp()
	end
	local ent = actors.entity(obj)
	return ent and ent:dbil_get_hp() or 0
end

function actors.get_max_hp(obj)
	if obj:is_player() then
		return dbil.resources.get_max(obj, "hp")
	end
	local ent = actors.entity(obj)
	return ent and ent:dbil_get_max_hp() or 1
end

--- Middle of the body (good aim point).
function actors.get_center(obj)
	local pos = obj:get_pos()
	local box = obj:get_properties().collisionbox
	return vector.new(pos.x, pos.y + (box[2] + box[5]) / 2, pos.z)
end

function actors.get_eye_pos(obj)
	local pos = obj:get_pos()
	if obj:is_player() then
		return vector.new(pos.x, pos.y + obj:get_properties().eye_height, pos.z)
	end
	local box = obj:get_properties().collisionbox
	return vector.new(pos.x, pos.y + box[5] * 0.85, pos.z)
end

function actors.get_look_dir(obj)
	if obj:is_player() then
		return obj:get_look_dir()
	end
	local ent = actors.entity(obj)
	if ent then
		return ent:dbil_get_look_dir()
	end
	return dbil.util.yaw_dir(obj:get_yaw() or 0)
end

--- Whether `a` may damage `b`. PvP rules live in dbil_combat.
function actors.are_hostile(a, b)
	if a == b then
		return false
	end
	local ta, tb = actors.get_team(a), actors.get_team(b)
	if ta ~= tb then
		return true
	end
	if ta == "players" then
		return dbil.config.combat.pvp
	end
	return false
end

--- Iterates every living actor (players with characters + tracked entities)
-- within `radius` of `pos`. Cheap: walks known actors, no map object search.
function actors.in_radius(pos, radius)
	local out = {}
	local r2 = radius * radius
	dbil.players.for_each_ready(function(player)
		if player:get_hp() > 0 and dbil.util.dist_sq(player:get_pos(), pos) <= r2 then
			out[#out + 1] = player
		end
	end)
	for ent in pairs(tracked) do
		local obj = ent.object
		if obj and obj:is_valid() then
			if ent:dbil_is_alive() and dbil.util.dist_sq(obj:get_pos(), pos) <= r2 then
				out[#out + 1] = obj
			end
		else
			tracked[ent] = nil
		end
	end
	return out
end

function actors.tracked_count()
	return dbil.util.count(tracked)
end
