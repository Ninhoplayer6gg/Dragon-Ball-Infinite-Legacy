-- The damage pipeline. Every source of combat damage (punches, Ki
-- techniques, NPC attacks, future beam clashes and explosions) goes through
-- dbil.combat.deal_damage(), so rules are applied consistently and on the
-- server only.
--
--   dbil.combat.deal_damage({
--       attacker = obj or nil,     -- ObjectRef of the attacker
--       target = obj,              -- ObjectRef of an actor
--       amount = 20,               -- base damage
--       kind = "melee" | "ki" | "true",
--       source = "heavy",          -- attack/technique id (for listeners)
--       knockback = 8, lift = 3,   -- optional
--       direction = vector,        -- optional knockback direction
--       hitstun = 0.5,             -- optional
--       can_block = true,          -- default true
--       fx = "hit_heavy", sound = "punch_heavy", pos = vector,
--       attacker_power = n, attacker_derived = t,  -- optional snapshots
--   })
--   -> final damage (number), result ("hit"|"blocked"|"guard_break"|"immune"|"invalid")
--
-- Extension point: dbil.combat.register_modifier(fn(info)) runs before
-- damage is applied and may change info.damage, info.knockback, etc.
--
-- Events: player_damaged(info), damage_dealt(info), actor_killed(info)

local combat = dbil.combat
local actors = dbil.actors
local cfg = dbil.config.combat
local clamp = dbil.util.clamp
local now = dbil.util.now

local modifiers = {}

function combat.register_modifier(fn, priority)
	modifiers[#modifiers + 1] = { fn = fn, priority = priority or 100 }
	table.sort(modifiers, function(a, b)
		return a.priority < b.priority
	end)
end

--- Power Level influence: (attacker / defender) ^ exponent, clamped.
function combat.power_ratio_factor(attacker_power, defender_power)
	if attacker_power <= 0 or defender_power <= 0 then
		return 1
	end
	local f = (attacker_power / defender_power) ^ cfg.power_ratio_exponent
	return clamp(f, cfg.power_ratio_min, cfg.power_ratio_max)
end

--- Pure damage formula (used by deal_damage and by tests).
function combat.compute_damage(amount, kind, attacker_derived, attacker_power, defender_derived, defender_power)
	local dmg = amount
	if kind ~= "true" then
		if attacker_derived then
			dmg = dmg * (kind == "ki" and attacker_derived.ki_mult or attacker_derived.melee_mult)
			dmg = dmg * combat.power_ratio_factor(attacker_power, defender_power)
		end
		if defender_derived then
			dmg = dmg * (1 - defender_derived.defense)
		end
	end
	return dmg
end

local function is_invulnerable(obj)
	if obj:is_player() then
		return dbil.movement.is_invulnerable(obj)
	end
	local ent = actors.entity(obj)
	return ent ~= nil and ent._invulnerable_until ~= nil and now() < ent._invulnerable_until
end

--- Pushes an actor. Players get an impulse, entities handle it themselves.
function combat.knockback(obj, dir, force, lift)
	if force <= 0 and (lift or 0) <= 0 then
		return
	end
	local push = vector.multiply(vector.normalize(vector.new(dir.x, 0, dir.z)), force)
	push.y = lift or 0
	if obj:is_player() then
		obj:add_velocity(push)
	else
		local ent = actors.entity(obj)
		if ent and ent.dbil_knockback then
			ent:dbil_knockback(push)
		else
			obj:add_velocity(push)
		end
	end
end

local function apply_hitstun(obj, duration)
	if not duration or duration <= 0 then
		return
	end
	if obj:is_player() then
		dbil.input.lock(obj, "hitstun", duration)
	else
		local ent = actors.entity(obj)
		if ent then
			ent._stunned_until = math.max(ent._stunned_until or 0, now() + duration)
		end
	end
end

function combat.deal_damage(info)
	local target, attacker = info.target, info.attacker
	if not actors.is_alive(target) then
		return 0, "invalid"
	end
	if attacker and attacker:is_valid() then
		if not info.ignore_teams and not actors.are_hostile(attacker, target) then
			return 0, "invalid"
		end
	else
		attacker = nil
		info.attacker = nil
	end
	info.kind = info.kind or "melee"
	info.pos = info.pos or actors.get_center(target)
	if is_invulnerable(target) then
		dbil.events.emit("attack_dodged", info)
		return 0, "immune"
	end

	-- Projectiles snapshot their caster's numbers at launch, so they keep
	-- their strength even if the caster dies or leaves before impact.
	local attacker_power = info.attacker_power or (attacker and actors.get_power(attacker)) or 0
	local attacker_derived = info.attacker_derived or (attacker and actors.get_derived(attacker))
	local defender_power = actors.get_power(target)
	info.damage = combat.compute_damage(info.amount, info.kind,
		attacker_derived, attacker_power,
		actors.get_derived(target), defender_power)
	info.knockback = info.knockback or 0
	info.lift = info.lift or 0
	info.result = "hit"
	if not info.direction then
		if attacker then
			info.direction = vector.subtract(target:get_pos(), attacker:get_pos())
		else
			info.direction = vector.new(0, 0, 1)
		end
	end

	for i = 1, #modifiers do
		dbil.log.protect("damage modifier", modifiers[i].fn, info)
	end

	local dmg = info.damage
	if dmg > 0 then
		dmg = math.max(1, math.floor(dmg + 0.5))
	else
		dmg = 0
	end
	info.damage = dmg

	-- Apply.
	if dmg > 0 then
		if target:is_player() then
			dbil.resources.set(target, "hp", target:get_hp() - dmg, "combat")
			dbil.events.emit("player_damaged", {
				player = target, amount = dmg, attacker = attacker, kind = info.kind, source = info.source,
			})
		else
			actors.entity(target):dbil_receive_damage(info)
		end
	end

	for _, obj in ipairs({ target, attacker }) do
		if obj and obj:is_player() then
			dbil.resources.mark_combat(obj)
		end
	end

	combat.knockback(target, info.direction, info.knockback, info.lift)
	apply_hitstun(target, info.hitstun)
	if info.result ~= "blocked" and dmg > 0 then
		dbil.animation.action(target, "hurt", 0.2)
	end
	dbil.fx.burst(info.fx or (info.result == "blocked" and "block" or "hit_light"), info.pos)
	if info.sound then
		dbil.fx.sound(info.sound, info.pos)
	end

	dbil.events.emit("damage_dealt", info)
	if not actors.is_alive(target) then
		dbil.events.emit("actor_killed", info)
	end
	return dmg, info.result
end
