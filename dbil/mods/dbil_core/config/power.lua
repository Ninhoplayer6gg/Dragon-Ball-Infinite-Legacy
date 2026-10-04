-- Power Level (Poder de Luta) formula. See dbil_character/src/power.lua.
return {
	weights = {
		strength = 1.0,
		resistance = 0.9,
		speed = 0.8,
		ki_control = 0.8,
		ki_capacity = 0.8,
	},
	exponent = 1.6,
	scale = 1.0,
	-- Bonus per mastery level summed over all masteries (small, capped).
	mastery_bonus_per_level = 0.004,
	mastery_bonus_max = 0.25,

	-- Current power factors.
	ki_factor_min = 0.55,      -- power at 0 Ki relative to full Ki
	health_factor_min = 0.7,   -- power at 0 HP relative to full HP
	charging_bonus = 0.12,     -- extra power while charging Ki
	-- Readings above this are shown as "???" by limited sensors (future Scouter).
	scouter_limit = 180000,
}
