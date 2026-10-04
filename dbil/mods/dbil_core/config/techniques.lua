-- Global technique and projectile settings.
return {
	-- Aim assist bends projectiles toward a target inside this cone.
	aim_assist_degrees = 10,
	aim_assist_range = 40,
	-- Safety limits.
	max_projectiles_per_caster = 6,
	max_projectile_range = 120,
	-- Projectiles from different teams collide and cancel (base for Beam Clash).
	projectile_clash = true,
	-- Mastery discounts never reduce cost/cooldown/charge below this fraction.
	mastery_floor = 0.3,
	-- Fraction of the charge multiplier applied to projectile size.
	charge_size_factor = 0.5,
	-- Movement multiplier while casting a technique with cast time.
	cast_move_speed = 0.35,
	-- Projectiles spawn this far in front of the caster's chest.
	spawn_forward = 0.9,
	spawn_drop = 0.35,
	-- Minimum fraction of power a projectile keeps after winning a clash.
	clash_min_remaining = 0.1,
}
