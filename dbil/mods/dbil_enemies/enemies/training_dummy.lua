-- Training dummy: a punching bag for testing techniques and training.
-- Gives training points through normal hits but no kill experience.
dbil.enemies.register("training_dummy", {
	name = "Boneco de Treino",
	description = "Absorve golpes e se recupera sozinho.",
	power = 200,
	hp = 600,
	attack = 0,
	defense = 0.2,
	speed = 0,
	view_range = 0,
	leash = 100,
	xp = 0,
	brain = "dummy",
	passive = true,
	team = "training",
	visual = {
		textures = { "dbil_enemy_dummy.png", "dbil_blank.png" },
		visual_size = 1,
		collisionbox = { -0.3, 0, -0.3, 0.3, 1.77, 0.3 },
		nametag_color = "#ffd27f",
	},
})
