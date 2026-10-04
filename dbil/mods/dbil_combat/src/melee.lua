-- Melee attacks: light (fast, combos) and heavy (slow, strong knockback).
--
-- Attack data lives in config.combat.light / .heavy. The structure is ready
-- for future moves (launchers, aerial chase, vanish, counters): each attack
-- is an `attack spec` executed by combat.perform_melee().

local combat = dbil.combat
local cfg = dbil.config.combat
local now = dbil.util.now

--- Executes a melee attack spec for a player. Returns true if it was performed.
-- spec: damage, stamina, cooldown, reach, knockback, lift, hitstun,
--       animation, fx, sound, training, source
function combat.perform_melee(player, state, spec, pointed)
	local cs = state.combat
	local t = now()
	if t < cs.ready_at or combat.is_guarding(player) then
		return false
	end
	dbil.ki.stop_charging(player, "attack")

	local damage = spec.damage
	-- Exhausted fighters can still punch, just weakly.
	if not dbil.resources.spend(player, "stamina", spec.stamina, "attack") then
		damage = damage * cfg.exhausted_damage_mult
	end
	cs.ready_at = t + spec.cooldown
	dbil.animation.action(player, spec.animation, spec.cooldown)

	local target = combat.resolve_target(player, {
		range = spec.reach,
		cone_degrees = cfg.melee_cone_degrees,
		flat = true,
		pointed = pointed,
	})
	if not target then
		dbil.fx.sound("swing", player)
		return true
	end
	local dir = vector.subtract(target:get_pos(), player:get_pos())
	local dealt, result = combat.deal_damage({
		attacker = player,
		target = target,
		amount = damage,
		kind = "melee",
		source = spec.source,
		knockback = spec.knockback,
		lift = spec.lift,
		direction = dir,
		hitstun = spec.hitstun,
		fx = spec.fx,
		sound = spec.sound,
	})
	if dealt > 0 and result ~= "blocked" then
		dbil.events.emit("training", player, spec.training, 1)
	end
	return true
end

dbil.input.register_action("light_attack", {
	handler = function(player, state, params)
		local cs = state.combat
		local t = now()
		if t < cs.ready_at then
			return false
		end
		if t - cs.last_light <= cfg.combo_window then
			cs.combo = cs.combo + 1
		else
			cs.combo = 1
		end
		cs.last_light = t
		local light = cfg.light
		local finisher = cs.combo % cfg.finisher_every == 0
		return combat.perform_melee(player, state, {
			source = finisher and "light_finisher" or "light",
			damage = light.damage * (finisher and cfg.finisher_damage_mult or 1),
			stamina = light.stamina,
			cooldown = light.cooldown,
			reach = light.reach,
			knockback = finisher and cfg.finisher_knockback or light.knockback,
			lift = 0,
			hitstun = light.hitstun,
			animation = cs.combo % 2 == 1 and "light" or "light_alt",
			fx = finisher and "hit_heavy" or "hit_light",
			sound = finisher and "punch_heavy" or "punch_light",
			training = "melee_hit",
		}, params.pointed)
	end,
})

dbil.input.register_action("heavy_attack", {
	handler = function(player, state, params)
		local heavy = cfg.heavy
		state.combat.combo = 0
		return combat.perform_melee(player, state, {
			source = "heavy",
			damage = heavy.damage,
			stamina = heavy.stamina,
			cooldown = heavy.cooldown,
			reach = heavy.reach,
			knockback = heavy.knockback,
			lift = heavy.lift,
			hitstun = heavy.hitstun,
			animation = "heavy",
			fx = "hit_heavy",
			sound = "punch_heavy",
			training = "melee_heavy_hit",
		}, params.pointed)
	end,
})

dbil.events.on("character_ready", function(player, char, state)
	state.combat = { ready_at = 0, last_light = 0, combo = 0 }
end)
