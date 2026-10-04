-- Guard (block). Hold the block intent (Zoom key / Zoom button) to reduce
-- incoming damage from the front at the cost of Stamina. Running out of
-- Stamina while guarding causes a guard break (stun).

local combat = dbil.combat
local cfg = dbil.config.combat.block
local now = dbil.util.now

function combat.is_guarding(player)
	local state = dbil.players.get_state(player)
	return state ~= nil and state.guard ~= nil and state.guard.active == true
end

local function set_guard(player, state, active)
	if state.guard.active == active then
		return
	end
	state.guard.active = active
	if active then
		dbil.physics.set(player, "guard", { speed = cfg.move_speed, jump = 0 })
		dbil.ki.stop_charging(player, "guard")
		dbil.events.emit("guard_started", player)
	else
		dbil.physics.clear(player, "guard")
		dbil.events.emit("guard_stopped", player)
	end
end

dbil.players.register_tick("guard", 0, function(player, state)
	local guard = state.guard
	if not guard or not state.intent then
		return
	end
	local wants = state.intent.block and dbil.input.can_act(player)
		and now() >= (guard.broken_until or 0)
		and dbil.resources.get(player, "stamina") > 0
	set_guard(player, state, wants and true or false)
end, 35)

combat.register_modifier(function(info)
	local target = info.target
	if not target:is_player() or not combat.is_guarding(target) then
		return
	end
	if info.can_block == false or info.kind == "true" or info.damage <= 0 then
		return
	end
	local from
	if info.attacker then
		from = vector.subtract(info.attacker:get_pos(), target:get_pos())
	else
		from = vector.multiply(info.direction, -1)
	end
	from.y = 0
	local facing = dbil.util.yaw_dir(target:get_look_horizontal())
	if combat.angle_between(facing, from) > math.rad(cfg.arc_degrees) then
		return
	end
	local reduction = info.kind == "ki" and cfg.ki_reduction or cfg.melee_reduction
	local prevented = info.damage * reduction
	local cost = prevented * cfg.stamina_per_damage
	local state = dbil.players.get_state(target)
	if dbil.resources.spend(target, "stamina", cost, "block") then
		info.damage = info.damage - prevented
		info.knockback = info.knockback * cfg.knockback_mult
		info.lift = 0
		info.hitstun = 0
		info.result = "blocked"
		info.fx = "block"
		info.sound = "block"
		dbil.events.emit("training", target, "block", 1)
	else
		dbil.resources.set(target, "stamina", 0, "guard_break")
		info.result = "guard_break"
		info.hitstun = cfg.guard_break_stun
		state.guard.broken_until = now() + cfg.guard_break_stun
		set_guard(target, state, false)
		dbil.events.emit("notify", target, "Defesa quebrada!", "warning")
	end
end, 50)

dbil.animation.register_pose(250, function(player, state)
	if state.guard and state.guard.active then
		return "block"
	end
end)

dbil.events.on("character_ready", function(player, char, state)
	state.guard = { active = false }
end)

dbil.events.on("character_leaving", function(player, char, state)
	if state.guard then
		set_guard(player, state, false)
	end
end)
