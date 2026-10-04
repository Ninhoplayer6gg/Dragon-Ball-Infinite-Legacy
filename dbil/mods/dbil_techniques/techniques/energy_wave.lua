-- Charged energy wave: needs a short cast time, grows stronger while the
-- button is held and explodes on impact. Prototype for Kamehameha-like moves.
dbil.techniques.register("energy_wave", {
	name = "Onda de Energia",
	description = "Concentra Ki nas mãos e libera uma onda que explode no impacto. "
		.. "Segure o botão para carregar mais (até o dobro de poder).",
	type = "projectile",
	shape = "ball",
	icon = "dbil_tech_energy_wave.png",
	damage = 36,
	ki_cost = 26,
	charge_time = 0.6,
	max_charge_time = 2.2,
	max_charge_mult = 2.0,
	cooldown = 5,
	speed = 22,
	range = 70,
	size = 0.7,
	knockback = 9,
	lift = 2,
	hitstun = 0.5,
	properties = {
		explosion_radius = 2.5,
	},
	requirements = { level = 3 },
	learn = { auto = true },
	mastery = {
		max_level = 10,
		xp_per_use = 6,
		xp_per_hit = 8,
		damage_per_level = 0.06,
		cost_reduction_per_level = 0.03,
		cooldown_reduction_per_level = 0.03,
		charge_reduction_per_level = 0.05,
	},
	visual = {
		texture = "wave_core",
		color = "#ffe27a",
		impact = "ki_explosion",
	},
})
