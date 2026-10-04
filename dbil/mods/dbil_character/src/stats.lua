-- Attributes, modifiers and derived values.
--
-- final attribute = (base + sum(add)) * product(mul)
-- Derived values (max HP, damage multipliers, Ki efficiency...) are computed
-- from final attributes and can be modified the same way.
--
-- Modifiers are owned by a named source so they can be removed cleanly:
--   dbil.stats.set_modifier(player, "transformation", {
--       strength = { mul = 1.5 }, power_mult = { mul = 2 }, max_ki = { add = 50 },
--   })
--   dbil.stats.clear_modifier(player, "transformation")

local stats = {}
dbil.stats = stats

local cfg = dbil.config.stats
local clamp = dbil.util.clamp
local ATTRIBUTES = dbil.ATTRIBUTES

-- Derived keys and what they mean (documentation + default values).
stats.DERIVED = {
	max_hp = "Vida máxima",
	max_ki = "Ki máximo",
	max_stamina = "Stamina máxima",
	move_speed = "Multiplicador de movimento",
	melee_mult = "Multiplicador de dano físico",
	ki_mult = "Multiplicador de dano de Ki",
	defense = "Redução de dano (0-1)",
	ki_cost_mult = "Multiplicador de custo de Ki",
	power_mult = "Multiplicador de Poder de Luta",
	hp_regen_mult = "Multiplicador de regeneração de Vida",
	ki_regen_mult = "Multiplicador de regeneração de Ki",
	xp_mult = "Multiplicador de experiência",
	training_mult = "Multiplicador de treino",
	mastery_mult = "Multiplicador de maestria",
}

local function compute_attributes(char, modifiers)
	local out = {}
	for _, attr in ipairs(ATTRIBUTES) do
		local add, mul = 0, 1
		for _, mods in pairs(modifiers) do
			local m = mods[attr]
			if m then
				add = add + (m.add or 0)
				mul = mul * (m.mul or 1)
			end
		end
		out[attr] = math.max(0, (char.attributes[attr] + add) * mul)
	end
	return out
end

--- Pure function: derived values from final attributes and level.
-- Exposed for tests and for previews in the UI.
function stats.compute_derived(attrs, level)
	local d = {}
	d.max_hp = cfg.hp_base + attrs.resistance * cfg.hp_per_resistance + level * cfg.hp_per_level
	d.max_ki = cfg.ki_base + attrs.ki_capacity * cfg.ki_per_capacity + level * cfg.ki_per_level
	d.max_stamina = cfg.stamina_base + attrs.resistance * cfg.stamina_per_resistance
		+ attrs.speed * cfg.stamina_per_speed
	d.move_speed = clamp(1 + (attrs.speed - cfg.speed_reference) * cfg.speed_per_point,
		cfg.speed_mult_min, cfg.speed_mult_max)
	d.melee_mult = 1 + attrs.strength * cfg.melee_per_strength
	d.ki_mult = 1 + attrs.ki_control * cfg.ki_damage_per_control
		+ attrs.ki_capacity * cfg.ki_damage_per_capacity
	d.defense = math.min(attrs.resistance / (attrs.resistance + cfg.defense_k), cfg.defense_max)
	d.ki_cost_mult = math.max(1 - attrs.ki_control * cfg.ki_efficiency_per_control, cfg.ki_efficiency_min)
	d.power_mult = 1
	d.hp_regen_mult = 1
	d.ki_regen_mult = 1
	d.xp_mult = 1
	d.training_mult = 1
	d.mastery_mult = 1
	return d
end

local function apply_derived_modifiers(d, modifiers)
	for key in pairs(stats.DERIVED) do
		local add, mul = 0, 1
		for _, mods in pairs(modifiers) do
			local m = mods[key]
			if m then
				add = add + (m.add or 0)
				mul = mul * (m.mul or 1)
			end
		end
		d[key] = (d[key] + add) * mul
	end
	d.max_hp = math.max(1, math.min(math.floor(d.max_hp), 65535))
	d.max_ki = math.max(1, math.floor(d.max_ki))
	d.max_stamina = math.max(1, math.floor(d.max_stamina))
	d.defense = clamp(d.defense, 0, 0.9)
	d.ki_cost_mult = math.max(d.ki_cost_mult, 0.1)
end

local function get_modifiers(state)
	if not state.modifiers then
		state.modifiers = {}
	end
	return state.modifiers
end

--- Recomputes attributes/derived values and applies them to the player.
function stats.recalculate(player)
	local state = dbil.players.get_state(player)
	if not state or not state.ready then
		return
	end
	local mods = get_modifiers(state)
	local attrs = compute_attributes(state.char, mods)
	local derived = stats.compute_derived(attrs, state.char.level)
	apply_derived_modifiers(derived, mods)
	state.attributes = attrs
	state.derived = derived

	local props = player:get_properties()
	if props.hp_max ~= derived.max_hp then
		player:set_properties({ hp_max = derived.max_hp })
	end
	dbil.physics.set(player, "stats", { speed = derived.move_speed })
	dbil.events.emit("stats_changed", player, derived, state)
end

function stats.set_modifier(player, source, mods)
	local state = dbil.players.get_state(player)
	if not state then
		return
	end
	get_modifiers(state)[source] = mods
	stats.recalculate(player)
end

function stats.clear_modifier(player, source)
	local state = dbil.players.get_state(player)
	if not state or not state.modifiers or not state.modifiers[source] then
		return
	end
	state.modifiers[source] = nil
	stats.recalculate(player)
end

--- Final value of an attribute (after modifiers).
function stats.get(player, attr)
	local state = dbil.players.get_state(player)
	return state and state.attributes and state.attributes[attr] or 0
end

--- Table of derived values (read-only by convention).
function stats.derived(player)
	local state = dbil.players.get_state(player)
	return state and state.derived
end

--- Adds points to a base attribute (level up, training, rewards).
function stats.add_base(player, attr, amount)
	local char = dbil.players.get_character(player)
	if not char or char.attributes[attr] == nil then
		return false
	end
	char.attributes[attr] = clamp(char.attributes[attr] + amount, cfg.attribute_min, cfg.attribute_max)
	dbil.players.mark_dirty(player)
	stats.recalculate(player)
	return true
end

function stats.set_base(player, attr, value)
	local char = dbil.players.get_character(player)
	if not char or char.attributes[attr] == nil then
		return false
	end
	char.attributes[attr] = clamp(value, cfg.attribute_min, cfg.attribute_max)
	dbil.players.mark_dirty(player)
	stats.recalculate(player)
	return true
end

--- Race traits become a regular modifier source.
local function race_modifiers(race)
	local t = race.traits
	return {
		power_mult = { mul = t.power_mult },
		ki_cost_mult = { mul = t.ki_cost_mult },
		max_hp = { mul = t.max_hp_mult },
		max_ki = { mul = t.max_ki_mult },
		max_stamina = { mul = t.max_stamina_mult },
		hp_regen_mult = { mul = t.hp_regen_mult },
		ki_regen_mult = { mul = t.ki_regen_mult },
		xp_mult = { mul = t.xp_mult },
		training_mult = { mul = t.training_mult },
		mastery_mult = { mul = t.mastery_mult },
	}
end

dbil.events.on("character_ready", function(player, char, state)
	state.modifiers = {}
	local race = dbil.races.get(char.race)
	if race then
		state.modifiers.race = race_modifiers(race)
	end
	stats.recalculate(player)
end, 10)

dbil.events.on("character_leaving", function(player, char, state)
	state.modifiers = {}
end, 900)
