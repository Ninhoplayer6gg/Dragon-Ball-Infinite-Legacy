-- Kaioken: multiplies power at the cost of HP strain. Mastery reduces the strain.
dbil.transformations.register("kaioken", {
	name = "Kaioken",
	description = "Técnica que multiplica todo o Ki do corpo por alguns instantes. O corpo sofre com o esforço.",
	color = "#ff4d4d",
	races = { "human" },
	paths = { "kaioken", "technique" },
	requirements = { level = 5 },
	unlock = { auto = true },
	modifiers = {
		power_mult = { mul = 2.0 },
		strength = { mul = 1.4 },
		speed = { mul = 1.25 },
		ki_control = { mul = 1.2 },
	},
	cost = { ki = 15 },
	drain = { ki = 1.5, hp_percent = 0.8 },
	transform_time = 0.6,
	mastery = {
		max_level = 10,
		xp_per_second = 1,
		drain_reduction_per_level = 0.07,
		time_reduction_per_level = 0.05,
		power_bonus_per_level = 0.02,
	},
	appearance = { skin_mod = "^[colorize:#ff202048" },
	aura = { color = "#ff3030", amount = 40 },
})
