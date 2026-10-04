-- Flight. Ki values are per second before Ki efficiency is applied.
return {
	min_ki_to_start = 5,
	takeoff_lift = 4,        -- upward speed when taking off from the ground
	toggle_debounce = 0.3,   -- ignore repeated toggles within this time
	guard_descend_mult = 0.3,-- descending while guarding is slower
	drain_moving = 2.0,
	drain_hover = 0.8,
	drain_boost = 6.0,

	speed = 2.2,             -- walk speed multiplier while flying
	boost_speed = 4.0,       -- multiplier while boosting (Aux1 + move)
	air_acceleration = 3.0,  -- physics acceleration_air multiplier
	vertical_speed = 7,      -- nodes/s up/down
	boost_vertical_speed = 12,
	-- When moving forward without up/down input, follow the camera pitch.
	pitch_follow = true,
	pitch_follow_factor = 0.85,
	-- Jump again while airborne to start flying.
	jump_to_fly = true,
	jump_to_fly_min_airtime = 0.2,
	-- Holding sneak while touching the ground lands (stops flight).
	land_with_sneak = true,
	land_ground_time = 0.25,

	-- Velocity controller tuning (network latency compensation).
	settle_time = 0.25,
	tolerance = 0.35,
}
