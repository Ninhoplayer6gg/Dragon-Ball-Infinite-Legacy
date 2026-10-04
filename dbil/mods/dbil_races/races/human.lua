dbil.races.register("human", {
	name = "Humano",
	description = "Guerreiros da Terra. Sem o poder bruto de outras raças, compensam com "
		.. "técnica refinada, uso eficiente do Ki e uma capacidade de aprender "
		.. "que nenhuma outra raça possui.",
	attributes = {
		strength = 8,
		resistance = 8,
		speed = 10,
		ki_control = 13,
		ki_capacity = 10,
	},
	growth = {
		strength = 1.1,
		resistance = 1.0,
		speed = 1.2,
		ki_control = 1.7,
		ki_capacity = 1.3,
	},
	traits = {
		ki_cost_mult = 0.85,   -- eficiência de Ki
		training_mult = 1.25,  -- aprendizagem rápida
		mastery_mult = 1.5,    -- domínio técnico
		xp_mult = 1.05,
	},
	appearance = {
		skin = "dbil_skin_human.png",
		hair = "dbil_hair_black.png",
		nametag_color = "#ffe9b0",
	},
	features = {
		"Técnicas custam 15% menos Ki",
		"Treino rende 25% mais",
		"Maestria de técnicas 50% mais rápida",
		"Futuro: Kaioken, Potencial Desbloqueado, técnicas avançadas",
	},
	tags = { "earthling" },
})
