-- Power Level (Poder de Luta).
--
-- power_base:    potential without temporary effects. Comes from final base
--                attributes, race and total mastery.
-- power_current: what the fighter really has right now: power_base scaled by
--                available Ki, health, state (charging...) and buffs
--                (transformations, via the power_mult derived modifier).
-- perceived:     what a sensor (Scouter, Ki sense) reads. Reserved for
--                suppression/hidden Ki and sensor limits.
--
-- API:
--   dbil.power.get_base(player)
--   dbil.power.get_current(player)
--   dbil.power.get_perceived(target_object, observer, sensor)
--   dbil.power.compute_base(attributes, race_mult, mastery_levels)  (pure)
--   dbil.power.format(value)
--   dbil.power.register_state_factor(name, fn(player, state) -> multiplier)

local power = {}
dbil.power = power

local cfg = dbil.config.power
local clamp = dbil.util.clamp

--- Pure formula, shared by players and the UI previews.
function power.compute_base(attrs, power_mult, mastery_levels)
	local core_value = 0
	for attr, weight in pairs(cfg.weights) do
		core_value = core_value + (attrs[attr] or 0) * weight
	end
	local mastery_bonus = math.min((mastery_levels or 0) * cfg.mastery_bonus_per_level, cfg.mastery_bonus_max)
	return math.floor(cfg.scale * core_value ^ cfg.exponent * (power_mult or 1) * (1 + mastery_bonus))
end

-- State factors: temporary multipliers based on what the fighter is doing.
local state_factors = {}

function power.register_state_factor(name, fn)
	state_factors[#state_factors + 1] = { name = name, fn = fn }
end

local function total_mastery_levels(char)
	local total = 0
	for _, m in pairs(char.mastery) do
		total = total + m.level
	end
	return total
end

function power.get_base(player)
	local state = dbil.players.get_state(player)
	if not state or not state.ready or not state.derived then
		return 0
	end
	local race = dbil.races.get(state.char.race)
	local race_mult = race and race.traits.power_mult or 1
	-- Base attributes only: transformation/buff modifiers are not potential.
	return power.compute_base(state.char.attributes, race_mult, total_mastery_levels(state.char))
end

function power.get_current(player)
	local state = dbil.players.get_state(player)
	if not state or not state.ready or not state.derived or not state.res then
		return 0
	end
	local d = state.derived
	-- Final (modified) attributes and the power_mult derived value, which
	-- combines the race trait with active buffs such as transformations.
	local value = power.compute_base(state.attributes, d.power_mult, total_mastery_levels(state.char))

	local ki_ratio = d.max_ki > 0 and state.res.ki / d.max_ki or 0
	local ki_factor = cfg.ki_factor_min + (1 - cfg.ki_factor_min) * clamp(ki_ratio, 0, 1)
	local hp_ratio = d.max_hp > 0 and player:get_hp() / d.max_hp or 0
	local hp_factor = cfg.health_factor_min + (1 - cfg.health_factor_min) * clamp(hp_ratio, 0, 1)
	value = value * ki_factor * hp_factor

	for i = 1, #state_factors do
		local f = state_factors[i].fn(player, state)
		if f then
			value = value * f
		end
	end
	return math.max(1, math.floor(value))
end

--- What `observer` (or a sensor) reads from `target`.
-- Suppression: state.power_suppression in [0,1] lowers the reading.
-- sensor.limit: readings above it return math.huge ("off the scale").
function power.get_perceived(target, observer, sensor)
	local value = dbil.actors.get_power(target)
	local state = target:is_player() and dbil.players.get_state(target)
	if state and state.power_suppression then
		value = value * state.power_suppression
	end
	local limit = sensor and sensor.limit
	if limit and value > limit then
		return math.huge
	end
	return math.floor(value)
end

--- Formats a Power Level for display.
function power.format(value)
	if value == math.huge then
		return "???"
	end
	return dbil.util.format_int(value)
end
