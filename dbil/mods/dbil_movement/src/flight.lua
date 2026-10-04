-- Flight (Bukujutsu).
--
-- Implementation: gravity is removed with a physics layer and the server
-- drives the vertical velocity from the player's intents (jump = up,
-- sneak = down, moving forward follows the camera pitch). Horizontal
-- movement stays client-predicted (smooth on any connection) with higher
-- air acceleration and speed. Ki drains every tick; at 0 Ki the fighter falls.
--
-- The vertical controller assumes the last commanded velocity for a short
-- "settle" window after each correction, so network latency cannot make it
-- oscillate; afterwards it corrects drift using the reported velocity.
--
-- Hooks for the future: dash works in the air (dash.lua), boost is high-speed
-- flight, and flight state is public for aerial combat/chase/aura systems.
--
-- API: dbil.flight.start(player), stop(player, reason), toggle(player),
--      is_flying(player)
-- Events: flight_started(player), flight_stopped(player, reason)

local flight = {}
dbil.flight = flight

local cfg = dbil.config.flight
local movement = dbil.movement
local now = dbil.util.now

function flight.is_flying(player)
	local state = dbil.players.get_state(player)
	return state ~= nil and state.flight ~= nil and state.flight.active == true
end

local function control_vertical(player, fs, target)
	local t = now()
	local base
	if t < fs.expect_until then
		base = fs.expected
	else
		base = player:get_velocity().y
	end
	local err = target - base
	if math.abs(err) > cfg.tolerance then
		player:add_velocity(vector.new(0, err, 0))
		fs.expected = target
		fs.expect_until = t + cfg.settle_time
	end
end

function flight.start(player)
	local state = dbil.players.get_state(player)
	if not state or not state.ready or not dbil.players.is_alive(player) then
		return false, "Indisponível."
	end
	local fs = state.flight
	if fs.active then
		return true
	end
	if dbil.ki.get(player) < cfg.min_ki_to_start then
		return false, "Ki insuficiente para voar."
	end
	fs.active = true
	fs.started = now()
	fs.expected = 0
	fs.expect_until = 0
	fs.ground_time = 0
	fs.train_acc = 0
	dbil.physics.set(player, "flight", {
		gravity = 0,
		jump = 0,
		speed = cfg.speed,
		acceleration_air = cfg.air_acceleration,
	})
	dbil.resources.block_regen(player, "ki", "flight", true)
	-- Cancel falling and lift off the ground a little.
	local vy = player:get_velocity().y
	local lift = movement.on_ground(player) and cfg.takeoff_lift or 0
	player:add_velocity(vector.new(0, lift - vy, 0))
	fs.expected = lift
	fs.expect_until = now() + cfg.settle_time
	fs.trail = dbil.fx.attach("flight_trail", player)
	dbil.fx.sound("flight_start", player)
	dbil.events.emit("flight_started", player)
	return true
end

function flight.stop(player, reason)
	local state = dbil.players.get_state(player)
	if not state or not state.flight or not state.flight.active then
		return
	end
	local fs = state.flight
	fs.active = false
	fs.ended = now()
	dbil.physics.clear(player, "flight")
	dbil.physics.clear(player, "flight_boost")
	dbil.resources.block_regen(player, "ki", "flight", false)
	dbil.fx.stop(fs.trail)
	fs.trail = nil
	fs.boosting = false
	dbil.events.emit("flight_stopped", player, reason or "manual")
end

function flight.toggle(player)
	if flight.is_flying(player) then
		flight.stop(player, "manual")
		return true
	end
	local ok, err = flight.start(player)
	if not ok and err then
		dbil.events.emit("notify", player, err, "warning")
	end
	return ok
end

dbil.input.register_action("toggle_flight", {
	handler = function(player, state)
		local t = now()
		if t - (state.flight.last_toggle or 0) < cfg.toggle_debounce then
			return false
		end
		state.flight.last_toggle = t
		return flight.toggle(player)
	end,
})

local function horizontal_speed(player)
	local v = player:get_velocity()
	return math.sqrt(v.x * v.x + v.z * v.z)
end

local function vertical_target(player, state, boosting)
	local intent = state.intent
	local speed = boosting and cfg.boost_vertical_speed or cfg.vertical_speed
	if intent.ascend then
		return speed
	elseif intent.descend then
		-- Guarding while descending is slower and safer.
		if intent.block then
			return -speed * cfg.guard_descend_mult
		end
		return -speed
	end
	if cfg.pitch_follow and state.ctrl.up then
		local pitch = player:get_look_vertical() -- positive = looking down
		return -math.sin(pitch) * horizontal_speed(player) * cfg.pitch_follow_factor
	end
	return 0
end

local function tick_flying(player, state, dt)
	local fs = state.flight
	if player:get_hp() <= 0 then
		flight.stop(player, "died")
		return
	end
	local intent = state.intent

	-- Boost (high-speed flight).
	local boosting = intent.boost and true or false
	if boosting ~= fs.boosting then
		fs.boosting = boosting
		if boosting then
			dbil.physics.set(player, "flight_boost", { speed = cfg.boost_speed / cfg.speed })
		else
			dbil.physics.clear(player, "flight_boost")
		end
	end

	-- Ki drain.
	local rate
	if boosting then
		rate = cfg.drain_boost
	elseif intent.moving or intent.ascend or intent.descend then
		rate = cfg.drain_moving
	else
		rate = cfg.drain_hover
	end
	local cost = dbil.ki.cost(player, rate * dt)
	dbil.resources.drain(player, "ki", cost, "flight")
	if dbil.ki.get(player) <= 0 then
		flight.stop(player, "no_ki")
		dbil.events.emit("notify", player, "Seu Ki acabou! Carregue Ki para voar de novo.", "warning")
		return
	end

	control_vertical(player, fs, vertical_target(player, state, boosting))

	-- Landing: hold sneak while touching the ground.
	if cfg.land_with_sneak and intent.descend and movement.on_ground(player) then
		fs.ground_time = fs.ground_time + dt
		if fs.ground_time >= cfg.land_ground_time then
			flight.stop(player, "landed")
			return
		end
	else
		fs.ground_time = 0
	end

	if intent.moving then
		fs.train_acc = fs.train_acc + dt
		if fs.train_acc >= 1 then
			fs.train_acc = fs.train_acc - 1
			dbil.events.emit("training", player, "flight_second", 1)
		end
	end
end

-- Jump again while airborne to take off.
local function tick_grounded(player, state, dt)
	local fs = state.flight
	if not cfg.jump_to_fly then
		return
	end
	if movement.on_ground(player) then
		fs.airtime = 0
		return
	end
	fs.airtime = (fs.airtime or 0) + dt
	if state.pressed.jump and fs.airtime >= cfg.jump_to_fly_min_airtime and dbil.input.can_act(player) then
		local ok = flight.start(player)
		if ok then
			fs.airtime = 0
		end
	end
end

dbil.players.register_tick("flight", 0, function(player, state, dt)
	local fs = state.flight
	if not fs or not state.intent or not state.ctrl then
		return
	end
	if fs.active then
		tick_flying(player, state, dt)
	else
		tick_grounded(player, state, dt)
	end
end, 40)

dbil.animation.register_pose(200, function(player, state)
	local fs = state.flight
	if fs and fs.active then
		if state.intent and state.intent.moving then
			return "fly"
		end
		return "hover"
	end
end)

--- Seconds since the player stopped flying (nil if never).
function flight.time_since_landing(player)
	local state = dbil.players.get_state(player)
	if state and state.flight and state.flight.ended then
		return now() - state.flight.ended
	end
end

dbil.events.on("character_ready", function(player, char, state)
	state.flight = { active = false, expected = 0, expect_until = 0 }
end)

dbil.events.on("character_leaving", function(player)
	flight.stop(player, "leaving")
end)

dbil.events.on("player_died", function(info)
	flight.stop(info.player, "died")
end)
