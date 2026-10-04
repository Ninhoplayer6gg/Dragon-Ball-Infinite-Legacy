-- Race-specific mechanics (race base stats live in dbil_races/races/*.lua).
return {
	saiyan = {
		zenkai_threshold = 0.15,    -- HP ratio that counts as "near death"
		zenkai_recover = 0.6,       -- HP ratio needed afterwards to trigger it
		zenkai_cooldown = 600,      -- seconds between Zenkai boosts
		zenkai_gain = { strength = 0.6, resistance = 0.8, ki_capacity = 0.4 },
		zenkai_cap_per_level = 1.2, -- max total Zenkai points per attribute per level
	},
}
