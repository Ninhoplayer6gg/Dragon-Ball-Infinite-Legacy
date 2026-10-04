-- Enemy AI and spawning.
return {
	think_interval = 0.2,       -- AI decision rate (seconds)
	perception_interval = 0.5,  -- how often enemies look for targets
	despawn_distance = 96,      -- removed when no player is this close
	spawner_interval = 6,       -- spawner node timer
	spawner_player_radius = 48, -- spawners only work with players nearby
	spawner_max_alive = 2,
	spawner_respawn_delay = 20,
	power_variance = 0.15,      -- +-15% power for spawned enemies
	knockback_time = 0.35,      -- AI does not steer while being knocked back
	corpse_time = 0.8,          -- seconds the body stays before removal
	despawn_alone_time = 60,    -- spawner enemies vanish after this long without players
	lose_target_mult = 1.6,     -- target dropped beyond view_range * this
	wander_chance = 0.25,       -- chance per think to start wandering when idle
	wander_radius = 10,
	dummy_regen_delay = 3,      -- training dummy recovers after this long without hits
	dummy_regen_percent = 20,   -- % of max HP per second
}
