-- Death, respawn and engine damage integration.
--
-- * Engine damage (falls, drowning, damaging nodes) is designed for 20 HP;
--   it is rescaled to the character's max HP.
-- * Engine punches between players are replaced by the dbil pipeline.
-- * Death emits "player_died"; respawn refills Ki/Stamina and grants a short
--   invulnerability. Where the player respawns is decided by dbil_world
--   (respawn resolvers), which allows the future Other World.

local cfg = dbil.config.combat
local ENGINE_HP = 20

local function is_dbil_reason(reason)
	return reason and (reason.dbil or (reason.custom_type and reason.custom_type:sub(1, 5) == "dbil:"))
end

core.register_on_player_hpchange(function(player, hp_change, reason)
	if hp_change >= 0 or is_dbil_reason(reason) or not dbil.players.is_ready(player) then
		return hp_change
	end
	local rtype = reason and reason.type
	if rtype ~= "fall" and rtype ~= "node_damage" and rtype ~= "drown" and rtype ~= "punch" then
		return hp_change -- set_hp from other code, hp_max clamping, /kill...
	end
	if dbil.movement.is_invulnerable(player) then
		return 0
	end
	-- Fighters in flight control their landing.
	if rtype == "fall" and dbil.flight and dbil.flight.is_flying(player) then
		return 0
	end
	local max = dbil.resources.get_max(player, "hp")
	local mult = rtype == "fall" and cfg.fall_damage_mult or cfg.environment_damage_mult
	return math.min(-1, math.floor(hp_change * max / ENGINE_HP * mult + 0.5))
end, true)

core.register_on_player_hpchange(function(player, hp_change, reason)
	if hp_change < 0 and not is_dbil_reason(reason) and dbil.players.is_ready(player) then
		dbil.events.emit("player_damaged", {
			player = player, amount = -hp_change, kind = "environment", source = reason and reason.type,
		})
	end
end, false)

-- Engine punches (non-kit items) are routed to a light attack; the engine
-- damage itself is cancelled.
core.register_on_punchplayer(function(player, hitter)
	if hitter and hitter:is_player() and hitter ~= player then
		local item = hitter:get_wielded_item()
		if not dbil.input.is_kit_item(item) then
			dbil.input.trigger(hitter, "light_attack", { pointed = { type = "object", ref = player } })
		end
	end
	return true
end)

core.register_on_dieplayer(function(player, reason)
	local char = dbil.players.get_character(player)
	if char then
		char.stats.deaths = (char.stats.deaths or 0) + 1
		dbil.players.mark_dirty(player)
	end
	dbil.physics.reset(player)
	dbil.events.emit("player_died", { player = player, reason = reason })
end)

core.register_on_respawnplayer(function(player)
	if dbil.players.is_ready(player) then
		dbil.resources.set(player, "ki", dbil.resources.get_max(player, "ki"), "respawn")
		dbil.resources.set(player, "stamina", dbil.resources.get_max(player, "stamina"), "respawn")
		dbil.movement.set_invulnerable(player, cfg.respawn_invulnerability)
		dbil.stats.recalculate(player)
		dbil.events.emit("player_respawned", player)
	end
end)

-- Kill statistics for players.
dbil.events.on("actor_killed", function(info)
	local attacker = info.attacker
	if attacker and attacker:is_player() then
		local char = dbil.players.get_character(attacker)
		if char then
			char.stats.kills = (char.stats.kills or 0) + 1
			dbil.players.mark_dirty(attacker)
		end
	end
end)
