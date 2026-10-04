-- Experience, levels, training and mastery.
return {
	max_level = 50,
	xp_base = 100,
	xp_exponent = 1.5,
	-- Restore HP/Ki/Stamina on level up.
	level_up_restore = true,

	-- Kill rewards scale with enemy/player power: clamp(ratio^exp, min, max).
	kill_xp_ratio_exponent = 0.6,
	kill_xp_min_mult = 0.2,
	kill_xp_max_mult = 2.0,
	-- Players who damaged the enemy within this radius share the reward.
	reward_share_radius = 64,
	-- A participant receives at least this fraction of the full reward.
	reward_min_share = 0.5,

	training = {
		-- Points needed for +1 attribute: base * (1 + gained * growth).
		points_base = 100,
		points_growth = 0.12,
		-- Max attribute points gained by training: cap_base + level * cap_per_level.
		cap_base = 5,
		cap_per_level = 1.5,
		-- Anti-macro: max training points per attribute per minute.
		points_per_minute = 140,
		xp_per_gain = 15,
		sources = {
			melee_hit = { strength = 4 },
			melee_heavy_hit = { strength = 7, resistance = 1 },
			damage_taken = { resistance = 0.15 },  -- per % of max HP lost
			block = { resistance = 3 },
			dash = { speed = 3 },
			flight_second = { speed = 0.8 },
			charge_second = { ki_control = 4, ki_capacity = 1.5 },
			technique_cast = { ki_control = 3 },
			ki_spent = { ki_capacity = 0.12 },     -- per Ki point spent
		},
	},

	mastery = {
		default_max_level = 10,
		xp_base = 50,
		xp_exponent = 1.4,
		-- Mastery reductions (drain, transform time) never go below this factor.
		min_factor = 0.2,
	},
}
