-- Animation of player and NPC models.
--
-- The frame ranges live in the theme (config/theme.lua). Players get a base
-- pose every tick from "pose providers" (flight, charging, guard...) and
-- one-shot actions (punches, Ki blasts, hits) override it briefly.
--
--   dbil.animation.register_pose(priority, function(player, state) return "fly" end)
--   dbil.animation.action(object, "heavy", 0.35)

local animation = {}
dbil.animation = animation

local frames = dbil.config.theme.animations
local now = dbil.util.now

local pose_providers = {}

--- Higher priority providers are asked first; the first non-nil wins.
function animation.register_pose(priority, fn)
	pose_providers[#pose_providers + 1] = { priority = priority, fn = fn }
	table.sort(pose_providers, function(a, b)
		return a.priority > b.priority
	end)
end

-- Per-object current animation cache (players use their state table,
-- entities their luaentity), so set_animation is only sent on changes.
local function holder_of(obj)
	if obj:is_player() then
		return dbil.players.get_state(obj)
	end
	return obj:get_luaentity()
end

--- Sets a looping/base animation on any object if it is not already playing.
function animation.set(obj, name, speed_mult)
	local holder = holder_of(obj)
	local anim = frames[name]
	if not holder or not anim then
		return
	end
	local speed = anim.speed * (speed_mult or 1)
	if holder._anim == name and holder._anim_speed == speed then
		return
	end
	holder._anim = name
	holder._anim_speed = speed
	obj:set_animation({ x = anim.x, y = anim.y }, speed, 0.12, anim.loop ~= false)
end

--- Plays a one-shot animation that takes priority for `duration` seconds.
function animation.action(obj, name, duration)
	local holder = holder_of(obj)
	if not holder or not frames[name] then
		return
	end
	holder._anim = nil -- force restart even if the same action repeats
	holder._anim_action_until = now() + (duration or 0.3)
	animation.set(obj, name)
end

function animation.in_action(obj)
	local holder = holder_of(obj)
	return holder ~= nil and holder._anim_action_until ~= nil and now() < holder._anim_action_until
end

local function is_moving(ctrl)
	return ctrl.up or ctrl.down or ctrl.left or ctrl.right
		or (ctrl.movement_x and math.abs(ctrl.movement_x) > 0.1)
		or (ctrl.movement_y and math.abs(ctrl.movement_y) > 0.1)
end

-- Default ground poses (lowest priority).
animation.register_pose(0, function(player, state)
	local ctrl = state.ctrl or player:get_player_control()
	if is_moving(ctrl) then
		return state.sprinting and "run" or "walk"
	end
	return "stand"
end)

animation.register_pose(1000, function(player)
	if player:get_hp() <= 0 then
		return "dead"
	end
end)

dbil.players.register_tick("animation", 0.1, function(player, state)
	if animation.in_action(player) then
		return
	end
	for i = 1, #pose_providers do
		local pose = pose_providers[i].fn(player, state)
		if pose then
			animation.set(player, pose)
			return
		end
	end
end, 500)
