-- Dash and sprint.
return {
	dash_stamina = 22,
	dash_cooldown = 0.45,
	dash_ground_speed = 13,       -- added horizontal velocity on the ground
	dash_air_speed = 16,          -- added velocity while flying
	dash_lift = 1.5,              -- small upward kick on ground dashes
	dash_invulnerable = 0.18,     -- i-frames at the start of a dash (dodge)
	-- After the burst, a short high-acceleration window stops the slide.
	dash_brake_delay = 0.2,
	dash_brake_duration = 0.18,
	dash_brake_ground_accel = 6,
	dash_brake_air_accel = 2,

	sprint_speed = 1.45,          -- walk speed multiplier while sprinting
	sprint_stamina_per_second = 9,
}
