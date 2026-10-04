-- Target acquisition.
--
-- Melee and techniques ask "what am I attacking?" here. Resolution order:
--   1. the object under the crosshair / finger (if it is a valid hostile actor)
--   2. the locked target (lock-on API below; not bound to a key yet)
--   3. the best hostile actor inside a forward cone (forgiving on touchscreens)
--
-- Lock-on API (ready for a future control binding / camera assist):
--   dbil.combat.set_lock(player, obj), get_lock(player), clear_lock(player)

local combat = dbil.combat
local actors = dbil.actors

local function angle_between(a, b)
	local la, lb = vector.length(a), vector.length(b)
	if la == 0 or lb == 0 then
		return math.pi
	end
	local c = vector.dot(a, b) / (la * lb)
	return math.acos(math.max(-1, math.min(1, c)))
end
combat.angle_between = angle_between

local function valid_target(attacker, obj)
	return obj and obj ~= attacker and actors.is_alive(obj) and actors.are_hostile(attacker, obj)
end

local function within(attacker_eye, obj, range)
	return vector.distance(attacker_eye, actors.get_center(obj)) <= range
end

function combat.set_lock(player, obj)
	local state = dbil.players.get_state(player)
	if state and valid_target(player, obj) then
		state.lock_target = obj
		dbil.events.emit("lock_changed", player, obj)
		return true
	end
	return false
end

function combat.get_lock(player)
	local state = dbil.players.get_state(player)
	local obj = state and state.lock_target
	if obj and valid_target(player, obj) then
		return obj
	end
	if state and state.lock_target then
		state.lock_target = nil
		dbil.events.emit("lock_changed", player, nil)
	end
	return nil
end

function combat.clear_lock(player)
	local state = dbil.players.get_state(player)
	if state and state.lock_target then
		state.lock_target = nil
		dbil.events.emit("lock_changed", player, nil)
	end
end

--- Best hostile actor inside a cone in front of `attacker`.
-- opts: range, cone_degrees, dir (defaults to look dir), line_of_sight,
--       flat (compare only the horizontal direction; used by melee so short
--       or slightly lower/higher targets right in front are not missed)
function combat.find_in_cone(attacker, opts)
	local eye = actors.get_eye_pos(attacker)
	local dir = opts.dir or actors.get_look_dir(attacker)
	if opts.flat then
		dir = vector.new(dir.x, 0, dir.z)
	end
	local half = math.rad(opts.cone_degrees or 40) / 2
	local best, best_score
	for _, obj in ipairs(actors.in_radius(eye, opts.range + 1.5)) do
		if valid_target(attacker, obj) then
			local center = actors.get_center(obj)
			local to = vector.subtract(center, eye)
			local dist = vector.length(to)
			local ang
			if opts.flat then
				local flat_to = vector.new(to.x, 0, to.z)
				-- Targets almost directly above/below count as in front.
				ang = vector.length(flat_to) < 0.3 and 0 or angle_between(dir, flat_to)
			else
				ang = angle_between(dir, to)
			end
			if dist <= opts.range and ang <= half then
				local score = ang * 3 + dist / opts.range
				if (not best_score or score < best_score)
						and (opts.line_of_sight == false or core.line_of_sight(eye, center)) then
					best, best_score = obj, score
				end
			end
		end
	end
	return best
end

--- Resolves the target of an attack. Returns ObjectRef or nil.
-- opts: range, cone_degrees, pointed (pointed_thing from the item callback)
function combat.resolve_target(attacker, opts)
	local eye = actors.get_eye_pos(attacker)
	local pointed = opts.pointed
	if pointed and pointed.type == "object" then
		local obj = pointed.ref
		if valid_target(attacker, obj) and within(eye, obj, opts.range + 0.75) then
			return obj
		end
	end
	if attacker:is_player() then
		local locked = combat.get_lock(attacker)
		if locked and within(eye, locked, opts.range) then
			return locked
		end
	end
	return combat.find_in_cone(attacker, opts)
end
