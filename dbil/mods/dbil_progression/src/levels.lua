-- Experience and levels.
--
-- Levels raise attributes by the race growth table. The curve and the level
-- cap keep growth bounded. XP comes from defeating enemies (shared between
-- co-op participants), training and quests.
--
-- API: dbil.progression.add_xp(player, amount, source)
--      dbil.progression.xp_to_next(level)
--      dbil.progression.set_level(player, level)
-- Events: xp_gained(player, amount, source), level_up(player, level)

local progression = dbil.progression
local cfg = dbil.config.progression

function progression.xp_to_next(level)
	return math.floor(cfg.xp_base * level ^ cfg.xp_exponent)
end

local function apply_level_up(player, char)
	char.level = char.level + 1
	local race = dbil.races.get(char.race)
	if race then
		for attr, amount in pairs(race.growth) do
			char.attributes[attr] = char.attributes[attr] + amount
		end
	end
end

local function after_levels(player, char, from_level)
	dbil.players.mark_dirty(player)
	dbil.stats.recalculate(player)
	if cfg.level_up_restore then
		dbil.resources.fill(player)
	end
	dbil.fx.burst("level_up", vector.add(player:get_pos(), vector.new(0, 1, 0)))
	dbil.fx.sound("level_up", player)
	dbil.events.emit("level_up", player, char.level, from_level)
	dbil.events.emit("notify", player, ("Nível %d alcançado! Seus atributos aumentaram."):format(char.level), "level")
	-- Save right away: level ups are important progress.
	dbil.players.save(player)
end

--- Adds experience. Returns the amount actually granted.
function progression.add_xp(player, amount, source)
	local char = dbil.players.get_character(player)
	if not char or amount <= 0 then
		return 0
	end
	if char.level >= cfg.max_level then
		return 0
	end
	local derived = dbil.stats.derived(player)
	amount = amount * (derived and derived.xp_mult or 1)
	char.xp = char.xp + amount
	local from = char.level
	while char.level < cfg.max_level and char.xp >= progression.xp_to_next(char.level) do
		char.xp = char.xp - progression.xp_to_next(char.level)
		apply_level_up(player, char)
	end
	if char.level >= cfg.max_level then
		char.xp = 0
	end
	dbil.players.mark_dirty(player)
	dbil.events.emit("xp_gained", player, amount, source)
	if char.level > from then
		after_levels(player, char, from)
	end
	return amount
end

--- Sets the level (debug/admin). Raising applies race growth per level.
function progression.set_level(player, level)
	local char = dbil.players.get_character(player)
	if not char then
		return false
	end
	level = math.max(1, math.min(math.floor(level), cfg.max_level))
	local from = char.level
	if level < from then
		-- Lowering cannot undo growth safely; only the number changes.
		char.level = level
		char.xp = 0
		dbil.players.mark_dirty(player)
		dbil.stats.recalculate(player)
		return true
	end
	while char.level < level do
		apply_level_up(player, char)
	end
	char.xp = 0
	if char.level > from then
		after_levels(player, char, from)
	end
	return true
end

-- Rewards for defeating enemies ---------------------------------------------

--- XP multiplier from enemy/player power ratio (weak enemies give less).
function progression.kill_xp_mult(enemy_power, player_power)
	if enemy_power <= 0 or player_power <= 0 then
		return 1
	end
	local m = (enemy_power / player_power) ^ cfg.kill_xp_ratio_exponent
	return math.max(cfg.kill_xp_min_mult, math.min(cfg.kill_xp_max_mult, m))
end

-- info: { name, xp, power, pos, contributors = { [player_name] = damage } }
dbil.events.on("enemy_killed", function(info)
	local total = 0
	for _, dmg in pairs(info.contributors) do
		total = total + dmg
	end
	if total <= 0 then
		return
	end
	for name, dmg in pairs(info.contributors) do
		local player = core.get_player_by_name(name)
		if player and dbil.players.is_ready(player)
				and vector.distance(player:get_pos(), info.pos) <= cfg.reward_share_radius then
			local share = math.max(cfg.reward_min_share, dmg / total)
			local mult = progression.kill_xp_mult(info.power, dbil.power.get_base(player))
			local gained = progression.add_xp(player, info.xp * share * mult, "kill")
			if gained > 0 then
				dbil.events.emit("notify", player, ("+%d XP (%s derrotado)"):format(math.floor(gained + 0.5), info.name), "xp")
			end
		end
	end
end)
