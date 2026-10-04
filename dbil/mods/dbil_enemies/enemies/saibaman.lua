-- Saibaman: small plant-born warriors. Fast, aggressive, spit Ki at fliers
-- and sometimes self-destruct when badly hurt.
dbil.enemies.register("saibaman", {
	name = "Saibaman",
	description = "Guerreiros cultivados a partir de sementes. Fracos sozinhos, perigosos em grupo.",
	power = 380,
	hp = 140,
	attack = 9,
	defense = 0.1,
	speed = 4.2,
	jump = 6.5,
	view_range = 20,
	attack_range = 2.2,
	attack_cooldown = 1.3,
	attack_windup = 0.35,
	knockback = 3,
	hitstun = 0.3,
	leash = 40,
	xp = 45,
	ranged = {
		technique = "ki_blast",
		min_range = 5,
		max_range = 22,
		cooldown = 3.5,
		chance = 0.35,
	},
	self_destruct = {
		hp_ratio = 0.25,
		chance = 0.3,
		trigger_range = 3,
		windup = 1.3,
		radius = 3.5,
		damage = 40,
	},
	drops = {
		{ item = "dbil_items:senzu", chance = 0.08 },
	},
	visual = {
		textures = { "dbil_enemy_saibaman.png", "dbil_blank.png" },
		visual_size = 0.85,
		collisionbox = { -0.28, 0, -0.28, 0.28, 1.5, 0.28 },
		nametag_color = "#9cff8a",
	},
})
