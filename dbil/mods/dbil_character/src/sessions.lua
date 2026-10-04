-- Player sessions: join/leave lifecycle, character activation, runtime
-- state and saving.
--
-- Persistent data lives in state.account / state.char (saved).
-- Runtime-only data (cooldowns, flight state, HUD ids...) lives in other
-- fields of the state table, created by each system on "character_ready".
--
-- Events emitted (see docs/API.md):
--   player_joined(player, state)
--   character_required(player, state)       -- no character yet: UI shows creation
--   character_created(player, char, state)
--   character_ready(player, char, state)    -- systems initialize here
--   character_leaving(player, char, state)  -- systems write back runtime values
--   character_reset(player, state)

local players = {}
dbil.players = players

local cfg = dbil.config.general
local states = {}

local function name_of(p)
	if type(p) == "string" then
		return p
	end
	if p and p.is_player and p:is_player() then
		return p:get_player_name()
	end
	return nil
end

function players.get_state(p)
	local name = name_of(p)
	return name and states[name]
end

--- Active character data of an online player (nil if none / not ready).
function players.get_character(p)
	local state = players.get_state(p)
	return state and state.ready and state.char or nil
end

function players.is_ready(p)
	local state = players.get_state(p)
	return state ~= nil and state.ready == true
end

function players.is_alive(player)
	return players.is_ready(player) and player:get_hp() > 0
end

function players.mark_dirty(p)
	local state = players.get_state(p)
	if state then
		state.dirty = true
	end
end

--- Calls fn(player, state) for every online player with an active character.
function players.for_each_ready(fn)
	for _, state in pairs(states) do
		if state.ready then
			fn(state.player, state)
		end
	end
end

--- Writes the account to storage now.
function players.save(p)
	local state = players.get_state(p)
	if not state or not state.account then
		return false
	end
	if state.ready then
		dbil.events.emit("character_saving", state.player, state.char, state)
	end
	local ok = dbil.accounts.save(state.name, state.account)
	if ok then
		state.dirty = false
		if dbil.config.debug.verbose then
			dbil.log.verbose("saved account %s", state.name)
		end
	end
	return ok
end

--- Registers a periodic function run for each ready player:
-- fn(player, state, elapsed). Lower priority runs first.
function players.register_tick(name, interval, fn, priority)
	dbil.scheduler.every(name, interval, function(elapsed)
		for _, state in pairs(states) do
			if state.ready then
				fn(state.player, state, elapsed)
			end
		end
	end, priority)
end

local function activate(player, state)
	state.char = dbil.model.active_character(state.account)
	if not state.char then
		state.ready = false
		dbil.events.emit("character_required", player, state)
		return false
	end
	state.ready = true
	dbil.log.info("%s plays as '%s' (%s, level %d)", state.name, state.char.name,
		state.char.race, state.char.level)
	dbil.events.emit("character_ready", player, state.char, state)
	return true
end

--- Validates a character name. Returns cleaned name or nil, error message.
function players.validate_name(raw)
	local name = dbil.util.clean_name(raw, cfg.name_max_length)
	if #name < cfg.name_min_length then
		return nil, ("O nome precisa ter pelo menos %d letras."):format(cfg.name_min_length)
	end
	return name
end

--- Creates the character for the active slot and activates it.
-- Returns true or false, error message. All checks are server-side.
function players.create_character(player, raw_name, race_id)
	local state = players.get_state(player)
	if not state then
		return false, "Jogador não encontrado."
	end
	if state.ready then
		return false, "Você já possui um personagem ativo."
	end
	local name, err = players.validate_name(raw_name)
	if not name then
		return false, err
	end
	local race = dbil.races.get(race_id)
	if not race or not race.playable then
		return false, "Raça inválida."
	end
	local slot = state.account.active
	if slot > cfg.max_characters then
		slot = 1
		state.account.active = 1
	end
	local char = dbil.model.new_character(state.name, name, race_id)
	state.account.characters[slot] = char
	dbil.events.emit("character_created", player, char, state)
	activate(player, state)
	players.save(player)
	return true
end

--- Deletes the active character (debug/reset). The player is sent back to
-- character creation.
function players.reset_character(player)
	local state = players.get_state(player)
	if not state then
		return false
	end
	if state.ready then
		dbil.events.emit("character_leaving", player, state.char, state)
	end
	state.account.characters[state.account.active] = nil
	state.ready = false
	state.char = nil
	players.save(player)
	dbil.events.emit("character_reset", player, state)
	dbil.events.emit("character_required", player, state)
	return true
end

core.register_on_joinplayer(function(player)
	local name = player:get_player_name()
	local acc, status = dbil.accounts.load(name)
	local state = {
		name = name,
		player = player,
		account = acc,
		ready = false,
		dirty = false,
		joined_at = dbil.util.now(),
	}
	states[name] = state
	if status == "loaded" and cfg.backup_on_join then
		dbil.accounts.backup(name, acc)
	end
	dbil.events.emit("player_joined", player, state)
	activate(player, state)
end)

core.register_on_leaveplayer(function(player)
	local name = player:get_player_name()
	local state = states[name]
	if not state then
		return
	end
	if state.ready then
		dbil.events.emit("character_leaving", player, state.char, state)
	end
	players.save(name)
	states[name] = nil
end)

core.register_on_shutdown(function()
	for name, state in pairs(states) do
		if state.ready then
			dbil.events.emit("character_leaving", state.player, state.char, state)
		end
		players.save(name)
	end
end)

dbil.scheduler.every("autosave", cfg.autosave_interval, function()
	for name, state in pairs(states) do
		if state.dirty then
			players.save(name)
		end
	end
end, 900)
