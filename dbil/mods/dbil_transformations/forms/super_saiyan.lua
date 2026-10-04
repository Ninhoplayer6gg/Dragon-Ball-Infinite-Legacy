-- Super Saiyan (EXPERIMENTAL first pass): golden hair, golden aura and big
-- multipliers. A fresh form drains a lot of Ki and transforms slowly; mastery
-- makes it fast and cheap. Unlocked by story (flag), not automatically.
-- Later forms (SSJ2, SSJ3, divine/primal paths) chain through `from`.
dbil.transformations.register("super_saiyan", {
	name = "Super Saiyajin",
	description = "A lendária transformação Saiyajin, despertada pela fúria.",
	color = "#ffd84a",
	races = { "saiyan" },
	paths = { "classic" },
	requirements = { level = 20, flags = { "ssj_awakened" } },
	unlock = { auto = false },
	modifiers = {
		power_mult = { mul = 3.0 },
		strength = { mul = 1.6 },
		resistance = { mul = 1.3 },
		speed = { mul = 1.4 },
		ki_control = { mul = 1.2 },
	},
	cost = { ki = 40 },
	drain = { ki = 4.0 },
	transform_time = 2.5,
	mastery = {
		max_level = 10,
		xp_per_second = 0.5,
		drain_reduction_per_level = 0.08,
		time_reduction_per_level = 0.08,
		power_bonus_per_level = 0.03,
	},
	appearance = { hair = "dbil_hair_gold.png" },
	aura = { color = "#ffd84a", amount = 50 },
})
