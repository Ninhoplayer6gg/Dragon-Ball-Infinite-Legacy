-- Casting techniques.
--
-- Player flow (action "use_technique", slot N):
--   validate (known, cooldown, Ki) -> spend Ki -> optional cast time
--   (chargeable techniques grow stronger while the button is held) -> fire.
-- NPCs use dbil.techniques.cast_npc() with the same definitions and shapes.
--
-- Events: technique_used(caster, id, info), technique_cast_started(player, id),
--         technique_cast_cancelled(player, id, reason)

local techniques = dbil.techniques
local cfg = dbil.config.techniques
local now = dbil.util.now
local clamp = dbil.util.clamp

local function mastery_level(player, id)
	return dbil.mastery.get_level(player, techniques.mastery_key(id))
end

function techniques.cooldown_remaining(player, id)
	local state = dbil.players.get_state(player)
	if not state or not state.tech_cooldowns then
		return 0
	end
	return math.max(0, (state.tech_cooldowns[id] or 0) - now())
end

function techniques.is_casting(player)
	local state = dbil.players.get_state(player)
	return state ~= nil and state.casting ~= nil
end

local function aim_direction(caster, origin, dir, range)
	if caster:is_player() then
		local state = dbil.players.get_state(caster)
		if state and not state.account.settings.aim_assist then
			return dir
		end
	end
	local target = dbil.combat.find_in_cone(caster, {
		range = math.min(range, cfg.aim_assist_range),
		cone_degrees = cfg.aim_assist_degrees * 2,
		dir = dir,
	})
	if target then
		return vector.normalize(vector.subtract(dbil.actors.get_center(target), origin))
	end
	return dir
end

local function launch_origin(caster, dir, size)
	local eye = dbil.actors.get_eye_pos(caster)
	-- Big projectiles start further ahead so they do not cover the camera.
	local origin = vector.add(eye, vector.multiply(dir, cfg.spawn_forward + (size or 0)))
	origin.y = origin.y - cfg.spawn_drop
	return origin
end

local function snapshot_derived(caster)
	local d = dbil.actors.get_derived(caster)
	if not d then
		return nil
	end
	return { ki_mult = d.ki_mult, melee_mult = d.melee_mult, defense = d.defense }
end

--- Fires a technique for any actor. Returns true if something was fired.
local function fire(caster, def, numbers, charge_mult, dir_override)
	local shape = techniques.get_shape(def.shape)
	if not shape then
		dbil.log.error("technique %s uses unknown shape %s", def.id, def.shape)
		return false
	end
	local look = dir_override or dbil.actors.get_look_dir(caster)
	local origin = launch_origin(caster, look, numbers.size)
	local dir = aim_direction(caster, origin, look, numbers.range)
	local attacker_power = dbil.actors.get_power(caster)
	local ok = shape.fire(caster, def, {
		origin = origin,
		dir = dir,
		damage = numbers.damage,
		power = numbers.damage * (attacker_power ^ dbil.config.combat.power_ratio_exponent),
		size = numbers.size,
		speed = numbers.speed,
		range = numbers.range,
		knockback = numbers.knockback,
		lift = numbers.lift,
		hitstun = numbers.hitstun,
		charge_mult = charge_mult,
		attacker_power = attacker_power,
		attacker_derived = snapshot_derived(caster),
	})
	if ok then
		dbil.animation.action(caster, def.animation, 0.35)
		dbil.fx.sound(def.visual.sound_fire, caster)
		dbil.events.emit("technique_used", caster, def.id, { charge_mult = charge_mult })
	end
	return ok
end

local function finish_cast(player, state, reason)
	local c = state.casting
	if not c then
		return
	end
	state.casting = nil
	dbil.physics.clear(player, "casting")
	dbil.fx.stop(c.aura)
	if reason then
		dbil.events.emit("technique_cast_cancelled", player, c.id, reason)
	end
end

local function release(player, state, def, charge_mult)
	local level = mastery_level(player, def.id)
	local numbers = techniques.compute(def, level, charge_mult)
	if fire(player, def, numbers, charge_mult) then
		state.tech_cooldowns[def.id] = now() + numbers.cooldown
		dbil.mastery.add_xp(player, techniques.mastery_key(def.id), def.mastery.xp_per_use, def.mastery.max_level)
		dbil.events.emit("training", player, "technique_cast", 1)
	end
end

local notify_at = {}

local function warn(player, text)
	local name = player:get_player_name()
	local t = now()
	if t >= (notify_at[name] or 0) then
		notify_at[name] = t + 1.5
		dbil.events.emit("notify", player, text, "warning")
	end
end

dbil.input.register_action("use_technique", {
	handler = function(player, state, params)
		if state.casting then
			return false
		end
		local id, def = techniques.get_equipped(player, params.slot or 1)
		if not id then
			warn(player, "Nenhuma técnica equipada neste espaço.")
			return false
		end
		if techniques.cooldown_remaining(player, id) > 0 then
			return false
		end
		if dbil.combat.is_guarding(player) then
			return false
		end
		local level = mastery_level(player, id)
		local base = techniques.compute(def, level, 1)
		local ok = dbil.ki.try_spend(player, base.cost, "technique")
		if not ok then
			warn(player, "Ki insuficiente! Segure Aux1 (E) parado para carregar.")
			return false
		end
		dbil.ki.stop_charging(player, "technique")

		if base.charge_time <= 0 and def.max_charge_time <= 0 then
			release(player, state, def, 1)
			return true
		end
		local t = now()
		local extra = math.max(0, def.max_charge_time - def.charge_time)
		state.casting = {
			id = id,
			def = def,
			started = t,
			min_until = t + base.charge_time,
			max_until = t + base.charge_time + extra,
			aura = dbil.fx.attach("aura", player, { color = def.visual.color, amount = 24 }),
		}
		dbil.physics.set(player, "casting", { speed = cfg.cast_move_speed, jump = 0 })
		dbil.fx.sound(def.visual.sound_charge, player)
		dbil.events.emit("technique_cast_started", player, id)
		return true
	end,
})

dbil.players.register_tick("technique_casting", 0, function(player, state)
	local c = state.casting
	if not c then
		return
	end
	if player:get_hp() <= 0 or dbil.input.is_locked(player) then
		finish_cast(player, state, "interrupted")
		return
	end
	local t = now()
	if t < c.min_until then
		return
	end
	local ctrl = state.ctrl or {}
	local holding = ctrl.dig or ctrl.place
	if holding and t < c.max_until then
		return
	end
	local charge_mult = 1
	if c.max_until > c.min_until then
		local f = clamp((t - c.min_until) / (c.max_until - c.min_until), 0, 1)
		charge_mult = 1 + (c.def.max_charge_mult - 1) * f
	end
	local def = c.def
	finish_cast(player, state, nil)
	release(player, state, def, charge_mult)
end, 55)

dbil.animation.register_pose(320, function(player, state)
	if state.casting then
		return "charge"
	end
end)

-- Being hit while casting cancels the technique (the Ki is lost).
dbil.events.on("player_damaged", function(info)
	local state = dbil.players.get_state(info.player)
	if state and state.casting and info.kind ~= "environment" then
		finish_cast(info.player, state, "interrupted")
	end
end)

--- NPC casting. opts: dir (unit vector) or target (ObjectRef), mastery (level)
function techniques.cast_npc(obj, id, opts)
	local def = techniques.get(id)
	if not def then
		return false
	end
	opts = opts or {}
	local numbers = techniques.compute(def, opts.mastery or 0, 1)
	local dir = opts.dir
	if not dir and opts.target then
		local eye = dbil.actors.get_eye_pos(obj)
		dir = vector.normalize(vector.subtract(dbil.actors.get_center(opts.target), eye))
	end
	return fire(obj, def, numbers, 1, dir)
end

dbil.events.on("character_ready", function(player, char, state)
	state.tech_cooldowns = {}
	state.casting = nil
end)

dbil.events.on("character_leaving", function(player, char, state)
	finish_cast(player, state, "leaving")
end)

dbil.events.on("player_died", function(info)
	local state = dbil.players.get_state(info.player)
	if state then
		finish_cast(info.player, state, "died")
	end
end)

-- Mastery XP when a player's technique hits.
dbil.events.on("projectile_impact", function(spec, point, target)
	if target and spec.owner and spec.owner:is_valid() and spec.owner:is_player() then
		local def = techniques.get(spec.technique)
		if def then
			dbil.mastery.add_xp(spec.owner, techniques.mastery_key(def.id), def.mastery.xp_per_hit, def.mastery.max_level)
		end
	end
end)
