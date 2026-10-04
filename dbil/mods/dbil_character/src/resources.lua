-- Resources: HP, Ki and Stamina behind one API.
--
-- HP is the engine HP (server-authoritative, hp_max follows the character's
-- max HP). Ki and Stamina are server-side floats kept in the runtime state
-- and written back to the character on save.
--
--   dbil.resources.get(player, "ki")
--   dbil.resources.get_max(player, "stamina")
--   dbil.resources.can_spend(player, "ki", 10)
--   dbil.resources.spend(player, "ki", 10, "technique")  -> true/false
--   dbil.resources.add(player, "stamina", 5)
--   dbil.resources.set(player, "hp", 50)
--
-- Event: resource_spent(player, kind, amount, reason)

local resources = {}
dbil.resources = resources

local cfg = dbil.config.resources
local now = dbil.util.now
local clamp = dbil.util.clamp

resources.KINDS = { "hp", "ki", "stamina" }

local MAX_KEY = { hp = "max_hp", ki = "max_ki", stamina = "max_stamina" }

local function ready_state(player)
	local state = dbil.players.get_state(player)
	if state and state.ready and state.res then
		return state
	end
end

function resources.get_max(player, kind)
	local state = ready_state(player)
	if not state then
		return 0
	end
	return state.derived[MAX_KEY[kind]] or 0
end

function resources.get(player, kind)
	if kind == "hp" then
		return player:get_hp()
	end
	local state = ready_state(player)
	return state and state.res[kind] or 0
end

function resources.ratio(player, kind)
	local max = resources.get_max(player, kind)
	if max <= 0 then
		return 0
	end
	return clamp(resources.get(player, kind) / max, 0, 1)
end

function resources.set(player, kind, value, cause)
	local state = ready_state(player)
	if not state then
		return false
	end
	local max = resources.get_max(player, kind)
	if kind == "hp" then
		value = clamp(math.floor(value + 0.5), 0, max)
		player:set_hp(value, { type = "set_hp", custom_type = "dbil:" .. (cause or "set"), dbil = true })
	else
		state.res[kind] = clamp(value, 0, max)
	end
	return true
end

function resources.add(player, kind, delta, cause)
	return resources.set(player, kind, resources.get(player, kind) + delta, cause)
end

function resources.can_spend(player, kind, amount)
	return ready_state(player) ~= nil and resources.get(player, kind) >= amount
end

--- Spends `amount` if available. Returns true on success.
function resources.spend(player, kind, amount, reason)
	local state = ready_state(player)
	if not state or amount < 0 then
		return false
	end
	if amount == 0 then
		return true
	end
	if resources.get(player, kind) < amount then
		return false
	end
	resources.set(player, kind, resources.get(player, kind) - amount, reason)
	state.last_spend[kind] = now()
	dbil.events.emit("resource_spent", player, kind, amount, reason)
	return true
end

--- Drains up to `amount`; returns the amount actually removed.
-- Used by continuous costs (flight) that should consume what is left.
function resources.drain(player, kind, amount, reason)
	local state = ready_state(player)
	if not state or amount <= 0 then
		return 0
	end
	local available = resources.get(player, kind)
	local taken = math.min(available, amount)
	if taken > 0 then
		resources.set(player, kind, available - taken, reason)
		state.last_spend[kind] = now()
		dbil.events.emit("resource_spent", player, kind, taken, reason)
	end
	return taken
end

function resources.fill(player)
	for _, kind in ipairs(resources.KINDS) do
		resources.set(player, kind, resources.get_max(player, kind), "fill")
	end
end

--- Prevents passive regeneration of a resource while `source` holds it.
function resources.block_regen(player, kind, source, blocked)
	local state = ready_state(player)
	if not state then
		return
	end
	state.regen_blocks[kind][source] = blocked or nil
end

--- Marks the player as in combat (pauses HP regeneration).
function resources.mark_combat(player)
	local state = dbil.players.get_state(player)
	if state then
		state.last_combat = now()
	end
end

function resources.in_combat(player)
	local state = dbil.players.get_state(player)
	return state ~= nil and state.last_combat ~= nil
		and now() - state.last_combat < cfg.hp_regen_combat_delay
end

local function regen_allowed(state, kind)
	return next(state.regen_blocks[kind]) == nil
end

dbil.players.register_tick("resources_regen", cfg.tick_interval, function(player, state, dt)
	if not state.res or player:get_hp() <= 0 then
		return
	end
	local t = now()
	local d = state.derived

	if regen_allowed(state, "ki") and t - (state.last_spend.ki or 0) >= cfg.ki_regen_delay then
		local ki = state.res.ki
		if ki < d.max_ki then
			state.res.ki = math.min(d.max_ki, ki + d.max_ki * cfg.ki_regen_percent / 100 * dt * d.ki_regen_mult)
		end
	end

	if regen_allowed(state, "stamina") and t - (state.last_spend.stamina or 0) >= cfg.stamina_regen_delay then
		state.res.stamina = math.min(d.max_stamina, state.res.stamina + cfg.stamina_regen_per_second * dt)
	end

	if regen_allowed(state, "hp") and not resources.in_combat(player) then
		local hp = player:get_hp()
		if hp < d.max_hp then
			state.hp_regen_acc = (state.hp_regen_acc or 0) + d.max_hp * cfg.hp_regen_percent / 100 * dt * d.hp_regen_mult
			if state.hp_regen_acc >= 1 then
				local whole = math.floor(state.hp_regen_acc)
				state.hp_regen_acc = state.hp_regen_acc - whole
				resources.set(player, "hp", hp + whole, "regen")
			end
		end
	end
end, 60)

local function stored_or_max(stored, max)
	if stored == nil or stored < 0 then
		return max
	end
	return clamp(stored, 0, max)
end

dbil.events.on("character_ready", function(player, char, state)
	state.last_spend = {}
	state.regen_blocks = { hp = {}, ki = {}, stamina = {} }
	state.res = {
		ki = stored_or_max(char.resources.ki, state.derived.max_ki),
		stamina = stored_or_max(char.resources.stamina, state.derived.max_stamina),
	}
	-- A dead player stays dead (the engine shows the respawn screen).
	if player:get_hp() > 0 then
		local hp = stored_or_max(char.resources.hp, state.derived.max_hp)
		resources.set(player, "hp", math.max(1, hp), "load")
	end
end, 20)

local function write_back(player, char, state)
	if not state.res then
		return
	end
	char.resources.ki = state.res.ki
	char.resources.stamina = state.res.stamina
	if player:is_valid() then
		char.resources.hp = player:get_hp()
	end
end

dbil.events.on("character_saving", write_back)
dbil.events.on("character_leaving", write_back, 10)

-- Keep Ki/Stamina within new maximums when stats change.
dbil.events.on("stats_changed", function(player, derived, state)
	if state.res then
		state.res.ki = math.min(state.res.ki, derived.max_ki)
		state.res.stamina = math.min(state.res.stamina, derived.max_stamina)
	end
end)
