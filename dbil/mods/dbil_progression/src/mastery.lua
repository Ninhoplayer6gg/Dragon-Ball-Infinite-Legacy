-- Generic mastery. Anything can have a mastery track identified by a key:
--   "technique:<id>", "transformation:<id>", "style:<id>", "race:<id>".
-- Each definition decides what its levels mean (cheaper Ki, faster
-- transformation, more damage...). Data is stored per character.
--
-- API: dbil.mastery.get_level(player, key), get(player, key),
--      add_xp(player, key, amount, max_level), set_level(player, key, level),
--      xp_to_next(level)
-- Events: mastery_level_up(player, key, level)

local mastery = dbil.mastery
local cfg = dbil.config.progression.mastery

function mastery.xp_to_next(level)
	return math.floor(cfg.xp_base * (level + 1) ^ cfg.xp_exponent)
end

function mastery.get(player, key)
	local char = dbil.players.get_character(player)
	return char and char.mastery[key] or { level = 0, xp = 0 }
end

function mastery.get_level(player, key)
	local char = dbil.players.get_character(player)
	local entry = char and char.mastery[key]
	return entry and entry.level or 0
end

function mastery.add_xp(player, key, amount, max_level)
	local state = dbil.players.get_state(player)
	if not state or not state.ready or amount <= 0 then
		return
	end
	local char = state.char
	max_level = max_level or cfg.default_max_level
	local entry = char.mastery[key]
	if not entry then
		entry = { level = 0, xp = 0 }
		char.mastery[key] = entry
	end
	if entry.level >= max_level then
		return
	end
	entry.xp = entry.xp + amount * state.derived.mastery_mult
	while entry.level < max_level and entry.xp >= mastery.xp_to_next(entry.level) do
		entry.xp = entry.xp - mastery.xp_to_next(entry.level)
		entry.level = entry.level + 1
		dbil.events.emit("mastery_level_up", player, key, entry.level)
	end
	if entry.level >= max_level then
		entry.xp = 0
	end
	dbil.players.mark_dirty(player)
end

function mastery.set_level(player, key, level)
	local char = dbil.players.get_character(player)
	if not char then
		return false
	end
	char.mastery[key] = { level = math.max(0, math.floor(level)), xp = 0 }
	dbil.players.mark_dirty(player)
	return true
end
