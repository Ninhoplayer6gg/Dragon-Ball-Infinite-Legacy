-- Tutorial chain: teaches the core loop (Ki -> flight -> combat -> training).
-- Future masters (Mestre Kame, Piccolo...) hand out quests the same way.

local function self_only(player, subject)
	return subject == player and 1 or nil
end

dbil.quests.register("tutorial_ki", {
	title = "Despertar do Ki",
	description = "Sinta a energia dentro de você. Segure Aux1 (tecla E) parado, ou mantenha pressionado o "
		.. "botão secundário com uma técnica na mão, até encher o Ki. Depois dispare uma Rajada de Ki.",
	auto_start = true,
	objectives = {
		{
			event = "charge_stopped",
			text = "Carregue o Ki até o máximo",
			progress = function(player, subject, reason)
				return subject == player and reason == "full" and 1 or nil
			end,
		},
		{
			event = "technique_used",
			count = 3,
			text = "Use técnicas de Ki",
			progress = self_only,
		},
	},
	rewards = { xp = 60 },
	next = "tutorial_flight",
})

dbil.quests.register("tutorial_flight", {
	title = "Bukujutsu",
	description = "Controle o Ki para voar: use o item Voo ou pule de novo no ar. Pulo sobe, agachar desce, "
		.. "Aux1 + direção acelera. Dê alguns dashes (Aux1 + direção) para aprender a esquivar.",
	objectives = {
		{
			event = "training",
			count = 15,
			text = "Voe por 15 segundos",
			progress = function(player, subject, source, units)
				return subject == player and source == "flight_second" and units or nil
			end,
		},
		{
			event = "dash",
			count = 3,
			text = "Faça dashes",
			progress = self_only,
		},
	},
	rewards = { xp = 80 },
	next = "tutorial_saibamen",
})

dbil.quests.register("tutorial_saibamen", {
	title = "Os Saibamen",
	description = "Saibamen estão brotando dos canteiros ao redor da arena. Derrote-os! "
		.. "Cuidado: quando estão quase derrotados, alguns tentam se explodir.",
	objectives = {
		{
			event = "enemy_killed",
			count = 3,
			text = "Derrote Saibamen",
			progress = function(player, info)
				return info.id == "saibaman" and info.contributors[player:get_player_name()] and 1 or nil
			end,
		},
	},
	rewards = { xp = 150, items = { "dbil_items:senzu 2" } },
	next = "tutorial_training",
})

dbil.quests.register("tutorial_training", {
	title = "Treino na Arena",
	description = "Os bonecos de treino da arena aguentam qualquer golpe. Use-os para treinar combos e "
		.. "golpes pesados. Segure Zoom (tecla Z) para defender golpes inimigos.",
	objectives = {
		{
			event = "damage_dealt",
			count = 20,
			text = "Acerte o boneco de treino",
			progress = function(player, info)
				if info.attacker ~= player or info.target:is_player() then
					return nil
				end
				local ent = info.target:get_luaentity()
				return ent and ent._id == "training_dummy" and 1 or nil
			end,
		},
		{
			event = "damage_dealt",
			count = 3,
			text = "Defenda ataques",
			progress = function(player, info)
				return info.target == player and info.result == "blocked" and 1 or nil
			end,
		},
	},
	rewards = { xp = 120 },
})
