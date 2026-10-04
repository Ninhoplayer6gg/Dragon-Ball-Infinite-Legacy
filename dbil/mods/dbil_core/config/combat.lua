-- Melee combat and the shared damage pipeline.
return {
	-- Player versus player damage (sparring). Off by default for co-op.
	pvp = false,

	light = {
		damage = 8,
		stamina = 3,
		cooldown = 0.32,
		reach = 3.6,
		knockback = 1.5,
		hitstun = 0.25,
	},
	heavy = {
		damage = 20,
		stamina = 12,
		cooldown = 0.9,
		reach = 3.9,
		knockback = 9,
		lift = 3,
		hitstun = 0.6,
	},
	-- Light attacks chained within the window build a combo; every
	-- `finisher_every` hits the strike is a finisher.
	combo_window = 0.85,
	finisher_every = 3,
	finisher_damage_mult = 1.5,
	finisher_knockback = 5,

	-- Punching without Stamina still works, with reduced damage.
	exhausted_damage_mult = 0.5,

	-- Melee target search when the crosshair is not on a target.
	melee_cone_degrees = 40,

	block = {
		melee_reduction = 0.75,
		ki_reduction = 0.5,
		stamina_per_damage = 0.6,   -- stamina spent per point of damage blocked
		move_speed = 0.4,
		guard_break_stun = 0.9,
		arc_degrees = 80,          -- attacks within this angle of the facing are blocked
		knockback_mult = 0.3,      -- knockback kept on a blocked hit
	},

	-- Power Level ratio influence on damage: (attacker/defender)^exponent.
	power_ratio_exponent = 0.35,
	power_ratio_min = 0.35,
	power_ratio_max = 2.5,

	-- Seconds a target remains "in combat" after damage (blocks HP regen).
	combat_tag_time = 8,
	-- Engine damage (falls, drowning, nodes) is designed for 20 HP; it is
	-- rescaled to the character's max HP and multiplied by these factors.
	environment_damage_mult = 0.6,
	fall_damage_mult = 0.35,
	respawn_invulnerability = 3,
}
