-- Test region generation.
return {
	-- The arena is built on the first land site found searching outward from
	-- this point (so ocean seeds still get a proper test region).
	arena_center_x = 0,
	arena_center_z = 0,
	site_search_radius = 1024,
	site_search_step = 32,
	arena_radius = 14,
	arena_clear_height = 24,
	-- Enemy spawners placed around the arena.
	spawner_count = 4,
	spawner_distance = 36,
	training_dummies = 2,
}
