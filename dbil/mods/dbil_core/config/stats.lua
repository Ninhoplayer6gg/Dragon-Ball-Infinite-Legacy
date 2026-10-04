-- Attribute -> derived value formulas. See dbil_character/src/stats.lua.
return {
	attribute_min = 1,
	attribute_max = 9999,

	hp_base = 80,
	hp_per_resistance = 5,
	hp_per_level = 4,

	ki_base = 60,
	ki_per_capacity = 6,
	ki_per_level = 2,

	stamina_base = 80,
	stamina_per_resistance = 1.5,
	stamina_per_speed = 1.5,

	-- Movement speed multiplier = 1 + (speed - reference) * per_point, clamped.
	speed_reference = 10,
	speed_per_point = 0.01,
	speed_mult_min = 0.85,
	speed_mult_max = 1.45,

	-- Damage multipliers.
	melee_per_strength = 0.04,
	ki_damage_per_control = 0.024,
	ki_damage_per_capacity = 0.016,

	-- Damage reduction = resistance / (resistance + k), capped.
	defense_k = 60,
	defense_max = 0.6,

	-- Ki cost multiplier = 1 - ki_control * per_point (clamped), times race trait.
	ki_efficiency_per_control = 0.008,
	ki_efficiency_min = 0.45,
}
