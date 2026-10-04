-- Training: doing things makes the fighter better at them.
--
-- Systems emit dbil.events.emit("training", player, source, units). The
-- source table in config.progression.training.sources converts units into
-- training points per attribute. Enough points give +1 to that attribute.
-- Limits: cost grows with each gain, total gains are capped by level, and a
-- per-minute budget stops macro/AFK farming.
--
-- Future training (gravity rooms, meditation, masters, Hyperbolic Time
-- Chamber) only needs new sources and multipliers.

local cfg = dbil.config.progression.training
local now = dbil.util.now

local progression = dbil.progression

function progression.training_cap(level)
	return math.floor(cfg.cap_base + level * cfg.cap_per_level)
end

function progression.training_cost(gained)
	return cfg.points_base * (1 + gained * cfg.points_growth)
end

local function budget(state, attr, points)
	local t = now()
	local w = state.training_window
	if not w or t - w.start >= 60 then
		w = { start = t, used = {} }
		state.training_window = w
	end
	local left = cfg.points_per_minute - (w.used[attr] or 0)
	local allowed = math.max(0, math.min(left, points))
	w.used[attr] = (w.used[attr] or 0) + allowed
	return allowed
end

function progression.add_training(player, attr, points)
	local state = dbil.players.get_state(player)
	if not state or not state.ready or points <= 0 then
		return
	end
	local char = state.char
	local tr = char.training
	local gained = tr.gained[attr] or 0
	local cap = progression.training_cap(char.level)
	if gained >= cap then
		return
	end
	points = budget(state, attr, points * state.derived.training_mult)
	if points <= 0 then
		return
	end
	tr.points[attr] = (tr.points[attr] or 0) + points
	local changed = false
	while gained < cap and tr.points[attr] >= progression.training_cost(gained) do
		tr.points[attr] = tr.points[attr] - progression.training_cost(gained)
		gained = gained + 1
		char.attributes[attr] = char.attributes[attr] + 1
		changed = true
		dbil.events.emit("notify", player,
			("Treino: %s +1"):format(dbil.ATTRIBUTE_INFO[attr].name), "training")
		dbil.events.emit("attribute_trained", player, attr, gained)
	end
	tr.gained[attr] = gained
	if gained >= cap then
		tr.points[attr] = 0
	end
	dbil.players.mark_dirty(player)
	if changed then
		dbil.stats.recalculate(player)
		progression.add_xp(player, cfg.xp_per_gain, "training")
	end
end

dbil.events.on("training", function(player, source, units)
	local spec = cfg.sources[source]
	if not spec or not units or units <= 0 then
		return
	end
	for attr, per_unit in pairs(spec) do
		progression.add_training(player, attr, per_unit * units)
	end
end)

dbil.events.on("player_damaged", function(info)
	local max = dbil.resources.get_max(info.player, "hp")
	if max > 0 then
		dbil.events.emit("training", info.player, "damage_taken", info.amount / max * 100)
	end
end)

dbil.events.on("resource_spent", function(player, kind, amount, reason)
	if kind == "ki" and player:is_player() then
		dbil.events.emit("training", player, "ki_spent", amount)
	end
end)
