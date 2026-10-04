-- Control polling and intents.
--
-- Every server step the raw controls of each player are read once and turned
-- into *intents* (what the player wants to do). Systems read intents, never
-- raw keys, so the control scheme can change in one place.
--
-- Default mapping (PC key / touchscreen button):
--   Aux1 (E / Aux1)        held, standing still -> charge Ki
--   Aux1 + movement        dash (edge) then sprint on ground / boost in flight
--   Zoom (Z / Zoom)        held -> guard (block)
--   Jump / Sneak           ascend / descend while flying
--   Place held (RMB / long press) with a technique item -> charge Ki
--
-- state.ctrl       raw controls this step
-- state.intent     { charge, block, sprint, boost, ascend, descend, moving }
-- state.pressed    keys that went down this step

local input = dbil.input

local KEYS = { "up", "down", "left", "right", "jump", "aux1", "sneak", "dig", "place", "zoom" }

local EMPTY = {}

local function moving(ctrl)
	if ctrl.up or ctrl.down or ctrl.left or ctrl.right then
		return true
	end
	local mx, my = ctrl.movement_x or 0, ctrl.movement_y or 0
	return mx * mx + my * my > 0.04
end

--- World-space horizontal direction the player is trying to move in, or nil.
function input.move_direction(player, ctrl)
	local fx, sx = 0, 0
	local my, mx = ctrl.movement_y, ctrl.movement_x
	if my and mx and (math.abs(my) > 0.1 or math.abs(mx) > 0.1) then
		fx, sx = my, mx
	else
		if ctrl.up then fx = fx + 1 end
		if ctrl.down then fx = fx - 1 end
		if ctrl.right then sx = sx + 1 end
		if ctrl.left then sx = sx - 1 end
	end
	if fx == 0 and sx == 0 then
		return nil
	end
	local yaw = player:get_look_horizontal()
	local forward = dbil.util.yaw_dir(yaw)
	local right = vector.new(forward.z, 0, -forward.x)
	return vector.normalize(vector.add(vector.multiply(forward, fx), vector.multiply(right, sx)))
end

-- Items can declare that holding "place" means charging Ki.
local function wields_charge_item(player)
	local def = player:get_wielded_item():get_definition()
	return def and def._dbil_place_charges == true
end

local function update(player, state)
	local prev = state.ctrl or EMPTY
	local ctrl = player:get_player_control()
	state.prev_ctrl = prev
	state.ctrl = ctrl
	local pressed = state.pressed or {}
	for _, key in ipairs(KEYS) do
		pressed[key] = ctrl[key] and not prev[key] or false
	end
	state.pressed = pressed

	local intent = state.intent or {}
	local is_moving = moving(ctrl)
	local flying = state.flight and state.flight.active
	intent.moving = is_moving
	intent.ascend = ctrl.jump and not ctrl.sneak
	intent.descend = ctrl.sneak and not ctrl.jump
	intent.block = ctrl.zoom
	-- No Ki charging while a technique is being cast (it uses the same buttons).
	intent.charge = not state.casting
		and ((ctrl.aux1 and not is_moving) or (ctrl.place and wields_charge_item(player)))
	intent.sprint = ctrl.aux1 and is_moving and not flying
	intent.boost = ctrl.aux1 and is_moving and flying
	-- Dash fires when Aux1 and movement become active together.
	intent.dash = ctrl.aux1 and is_moving and not (prev.aux1 and moving(prev))
	state.intent = intent
end

dbil.players.register_tick("input_poll", 0, function(player, state)
	update(player, state)
	if state.intent.dash then
		input.trigger(player, "dash")
	end
end, 10)

dbil.events.on("character_ready", function(player, char, state)
	state.ctrl = nil
	state.intent = {}
	state.pressed = {}
end)
