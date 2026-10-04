-- Gameplay actions: named, server-validated entry points for everything a
-- player can actively do. Items, controls, chat commands and future UI
-- buttons all go through input.trigger(), so validation lives in one place.
--
--   dbil.input.register_action("light_attack", {
--       allow_stunned = false,   -- default false
--       handler = function(player, state, params) ... return true end,
--   })
--   dbil.input.trigger(player, "light_attack", { pointed = pointed_thing })

local input = dbil.input
local now = dbil.util.now

local actions = {}

function input.register_action(name, def)
	assert(type(def.handler) == "function", "action needs a handler: " .. name)
	assert(not actions[name], "action already registered: " .. name)
	actions[name] = def
end

--- Temporarily prevents actions (stuns, cast times...).
function input.lock(player, source, duration)
	local state = dbil.players.get_state(player)
	if not state then
		return
	end
	state.locks = state.locks or {}
	local expires = now() + duration
	if (state.locks[source] or 0) < expires then
		state.locks[source] = expires
	end
end

function input.unlock(player, source)
	local state = dbil.players.get_state(player)
	if state and state.locks then
		state.locks[source] = nil
	end
end

function input.is_locked(player)
	local state = dbil.players.get_state(player)
	if not state or not state.locks then
		return false
	end
	local t = now()
	for source, expires in pairs(state.locks) do
		if t < expires then
			return true, source
		end
		state.locks[source] = nil
	end
	return false
end

--- Whether the player can act at all right now.
function input.can_act(player)
	if not dbil.players.is_alive(player) then
		return false
	end
	return not input.is_locked(player)
end

--- Runs an action after common validation. Returns the handler result.
function input.trigger(player, name, params)
	local def = actions[name]
	if not def then
		dbil.log.warn("unknown action '%s'", tostring(name))
		return false
	end
	if not player or not player:is_player() or not dbil.players.is_alive(player) then
		return false
	end
	if not def.allow_locked and input.is_locked(player) then
		return false
	end
	local state = dbil.players.get_state(player)
	return dbil.log.protect("action '" .. name .. "'", def.handler, player, state, params or {})
end

function input.has_action(name)
	return actions[name] ~= nil
end
