-- Ki charging (power up).
--
-- While the charge intent is held (see dbil_input) the fighter powers up:
-- Ki rises quickly, movement slows down, an aura appears and the current
-- Power Level gets a bonus. Charging stops automatically at max Ki and needs
-- the key to be released before charging again. Taking damage interrupts it.
--
-- Events: charge_started(player), charge_stopped(player, reason)

local ki = dbil.ki
local cfg = dbil.config.ki
local now = dbil.util.now

function ki.is_charging(player)
	local state = dbil.players.get_state(player)
	return state ~= nil and state.charge ~= nil and state.charge.active == true
end

local function start_charge(player, state)
	local charge = state.charge
	charge.active = true
	charge.started = now()
	charge.trained = 0
	dbil.physics.set(player, "ki_charge", { speed = cfg.charge_move_speed, jump = 0 })
	dbil.resources.block_regen(player, "ki", "charge", true)
	charge.aura = dbil.fx.attach("aura", player)
	dbil.fx.sound("charge_start", player)
	dbil.events.emit("charge_started", player)
end

local function stop_charge(player, state, reason)
	local charge = state.charge
	if not charge or not charge.active then
		return
	end
	charge.active = false
	dbil.physics.clear(player, "ki_charge")
	dbil.resources.block_regen(player, "ki", "charge", false)
	dbil.fx.stop(charge.aura)
	charge.aura = nil
	if reason == "full" then
		-- Must release the key before charging again.
		charge.latched = true
	end
	dbil.events.emit("charge_stopped", player, reason)
end

function ki.stop_charging(player, reason)
	local state = dbil.players.get_state(player)
	if state and state.charge then
		stop_charge(player, state, reason or "manual")
	end
end

--- Ki gained per second while charging.
function ki.charge_rate(player)
	local max = ki.get_max(player)
	local control = dbil.stats.get(player, "ki_control")
	return max * (cfg.charge_percent_per_second + control * cfg.charge_percent_per_control) / 100
end

dbil.players.register_tick("ki_charge", 0, function(player, state, dt)
	local charge = state.charge
	if not charge then
		return
	end
	local wants = state.intent and state.intent.charge
	if not wants then
		charge.latched = false
	end

	if charge.active then
		if not wants or not dbil.input.can_act(player) or now() < (charge.lockout or 0) then
			stop_charge(player, state, "released")
			return
		end
		local max = ki.get_max(player)
		local current = ki.get(player)
		if current >= max then
			stop_charge(player, state, "full")
			return
		end
		local gain = math.min(ki.charge_rate(player) * dt, max - current)
		dbil.resources.add(player, "ki", gain, "charge")
		charge.trained = charge.trained + dt
		if charge.trained >= 1 then
			charge.trained = charge.trained - 1
			dbil.events.emit("training", player, "charge_second", 1)
		end
		return
	end

	if wants and not charge.latched and now() >= (charge.lockout or 0)
			and dbil.input.can_act(player) and ki.get(player) < ki.get_max(player) then
		start_charge(player, state)
	end
end, 30)

-- Being hit interrupts the charge.
dbil.events.on("player_damaged", function(info)
	local state = dbil.players.get_state(info.player)
	if state and state.charge and state.charge.active then
		stop_charge(info.player, state, "interrupted")
		state.charge.lockout = now() + cfg.interrupt_lockout
	end
end)

-- Powering up raises the current Power Level.
dbil.power.register_state_factor("charging", function(player, state)
	if state.charge and state.charge.active then
		return 1 + dbil.config.power.charging_bonus
	end
end)

dbil.animation.register_pose(300, function(player, state)
	if state.charge and state.charge.active then
		return "charge"
	end
end)

dbil.events.on("character_ready", function(player, char, state)
	state.charge = { active = false, latched = false }
end)

dbil.events.on("character_leaving", function(player, char, state)
	if state.charge then
		stop_charge(player, state, "leaving")
	end
end)

dbil.events.on("player_died", function(info)
	ki.stop_charging(info.player, "died")
end)
