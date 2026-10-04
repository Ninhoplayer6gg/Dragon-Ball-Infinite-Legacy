-- Presentation layer: textures, colors, sounds, particles and animations.
-- Gameplay code refers to these entries by meaning only. Replacing art means
-- editing this file (or overriding the texture files), never gameplay code.
-- Files marked TEMP are generated placeholder art (see docs/ASSETS.md).
return {
	colors = {
		hp = "#e5484d",
		hp_low = "#ff2020",
		ki = "#45b8ff",
		stamina = "#ffcc33",
		xp = "#b07cff",
		bar_back = "#0b0d14",
		text = "#ffffff",
		text_dim = "#b8c0d0",
		power = "#ffd866",
		flight = "#9be7ff",
		charging = "#7fd4ff",
		cooldown = "#ff9a5c",
		ready = "#8dff9c",
		enemy = "#ff6b6b",
		quest = "#ffe08a",
	},

	textures = {
		bar_frame = "dbil_hud_bar_frame.png",     -- TEMP
		bar_fill = "dbil_hud_bar_fill.png",       -- TEMP
		bar_back = "dbil_hud_bar_back.png",       -- TEMP
		particle_glow = "dbil_fx_glow.png",       -- TEMP
		particle_spark = "dbil_fx_spark.png",     -- TEMP
		particle_smoke = "dbil_fx_smoke.png",     -- TEMP
		particle_dust = "dbil_fx_dust.png",       -- TEMP
		ki_ball = "dbil_fx_ki_ball.png",          -- TEMP
		wave_core = "dbil_fx_wave_core.png",      -- TEMP
	},

	particles = {
		hit_light = { texture = "particle_spark", color = "#ffffff", amount = 8, size = 1.2, speed = 4, life_min = 0.12, life_max = 0.3 },
		hit_heavy = { texture = "particle_spark", color = "#ffe9a8", amount = 18, size = 2.0, speed = 7, life_min = 0.15, life_max = 0.4 },
		block = { texture = "particle_spark", color = "#9fd8ff", amount = 10, size = 1.4, speed = 4, life_min = 0.1, life_max = 0.25 },
		dash = { texture = "particle_dust", color = "#d9d2c0", amount = 14, size = 2.4, speed = 1.5, life_min = 0.3, life_max = 0.6, blend = "alpha", gravity = 0.5 },
		ki_explosion = { texture = "particle_glow", color = "#7fd4ff", amount = 26, size = 3.2, speed = 6, life_min = 0.25, life_max = 0.55, spread = 0.4 },
		ki_smoke = { texture = "particle_smoke", color = "#cfd8e6", amount = 10, size = 4, speed = 1.6, life_min = 0.6, life_max = 1.1, blend = "alpha", gravity = 0.6 },
		death = { texture = "particle_glow", color = "#b6ff9a", amount = 40, size = 2.6, speed = 5, life_min = 0.4, life_max = 0.9, spread = 0.6 },
		level_up = { texture = "particle_glow", color = "#ffe27a", amount = 40, size = 2.2, speed = 3, life_min = 0.6, life_max = 1.2, spread = 0.8, gravity = 1.5 },
		-- Continuous effects (fx.attach)
		aura = { texture = "particle_glow", color = "#8fd8ff", amount = 34, size = 2.6, spread = 0.45, vertical_spread = 2.0, offset = { x = 0, y = 1.0, z = 0 }, rise = 2.2, life_min = 0.25, life_max = 0.55, start_alpha = 0.55 },
		flight_trail = { texture = "particle_glow", color = "#bfe9ff", amount = 10, size = 1.4, spread = 0.2, offset = { x = 0, y = 0.4, z = 0 }, rise = 0.1, life_min = 0.2, life_max = 0.35, start_alpha = 0.35 },
		projectile_trail = { texture = "particle_glow", color = "#7fd4ff", amount = 30, size = 1.6, spread = 0.12, rise = 0.05, life_min = 0.12, life_max = 0.25, start_alpha = 0.8 },
	},

	-- Sound files are generated TEMP placeholders in dbil_core/sounds.
	sounds = {
		punch_light = { name = "dbil_punch_light", gain = 0.7, distance = 24 },
		punch_heavy = { name = "dbil_punch_heavy", gain = 0.9, distance = 32 },
		swing = { name = "dbil_swing", gain = 0.4, distance = 16 },
		block = { name = "dbil_block", gain = 0.7, distance = 24 },
		dash = { name = "dbil_dash", gain = 0.6, distance = 24 },
		ki_fire = { name = "dbil_ki_fire", gain = 0.7, distance = 40 },
		ki_charge_wave = { name = "dbil_ki_charge", gain = 0.5, distance = 32 },
		explosion = { name = "dbil_explosion", gain = 0.8, distance = 48 },
		charge_start = { name = "dbil_ki_charge", gain = 0.6, distance = 32 },
		flight_start = { name = "dbil_flight", gain = 0.6, distance = 32 },
		level_up = { name = "dbil_level_up", gain = 0.8, distance = 24, pitch = 1.0 },
		enemy_death = { name = "dbil_explosion", gain = 0.6, distance = 32, pitch = 1.3 },
	},

	-- Animation frame ranges of dbil_character.b3d (see tools/gen_model.py).
	animations = {
		stand = { x = 0, y = 40, speed = 15 },
		walk = { x = 50, y = 70, speed = 30 },
		run = { x = 50, y = 70, speed = 48 },
		light = { x = 80, y = 90, speed = 55, loop = false },
		light_alt = { x = 95, y = 105, speed = 55, loop = false },
		heavy = { x = 110, y = 126, speed = 45, loop = false },
		block = { x = 130, y = 135, speed = 10 },
		charge = { x = 140, y = 160, speed = 30 },
		fly = { x = 170, y = 190, speed = 18 },
		hover = { x = 200, y = 220, speed = 15 },
		fire = { x = 230, y = 240, speed = 35, loop = false },
		hurt = { x = 250, y = 256, speed = 30, loop = false },
		dead = { x = 260, y = 262, speed = 1 },
	},
}
