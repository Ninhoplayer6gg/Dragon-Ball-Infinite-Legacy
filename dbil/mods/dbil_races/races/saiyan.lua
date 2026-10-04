-- Saiyan: raw power and Zenkai (power boost after surviving near death).
-- Future: tail/Oozaru, Super Saiyan paths (classic, divine, primal...),
-- registered as transformations — not hardcoded here.

local cfg = dbil.config.races.saiyan

dbil.races.register("saiyan", {
	name = "Saiyajin",
	description = "Raça guerreira de enorme potencial. Ficam mais fortes a cada batalha "
		.. "e voltam ainda mais poderosos depois de chegar perto da morte (Zenkai).",
	attributes = {
		strength = 11,
		resistance = 10,
		speed = 10,
		ki_control = 7,
		ki_capacity = 9,
	},
	growth = {
		strength = 1.7,
		resistance = 1.4,
		speed = 1.2,
		ki_control = 0.8,
		ki_capacity = 1.4,
	},
	traits = {
		power_mult = 1.1,
		xp_mult = 1.1,
		max_hp_mult = 1.05,
	},
	appearance = {
		skin = "dbil_skin_saiyan.png",
		hair = "dbil_hair_saiyan.png",
		nametag_color = "#ffb38a",
	},
	features = {
		"Poder de Luta 10% maior",
		"Crescimento físico superior a cada nível",
		"Zenkai: sobreviver perto da morte aumenta atributos permanentemente",
		"Futuro: cauda, Oozaru, Super Saiyajin e outros caminhos",
	},
	tags = { "saiyan" },
})

-- Zenkai -------------------------------------------------------------------

dbil.races.on("saiyan", "player_damaged", function(info)
	local player = info.player
	local state = dbil.players.get_state(player)
	if dbil.resources.ratio(player, "hp") <= cfg.zenkai_threshold and player:get_hp() > 0 then
		state.zenkai_pending = true
	end
end)

dbil.races.on("saiyan", "player_died", function(info)
	-- Death resets the near-death window: Zenkai rewards *surviving*.
	local state = dbil.players.get_state(info.player)
	state.zenkai_pending = nil
end)

dbil.players.register_tick("saiyan_zenkai", 1.0, function(player, state)
	if not state.zenkai_pending or state.char.race ~= "saiyan" then
		return
	end
	if dbil.resources.ratio(player, "hp") < cfg.zenkai_recover then
		return
	end
	state.zenkai_pending = nil
	local char = state.char
	local last = char.flags.zenkai_last or 0
	if os.time() - last < cfg.zenkai_cooldown then
		return
	end
	local cap = cfg.zenkai_cap_per_level * char.level
	local gained_any = false
	for attr, amount in pairs(cfg.zenkai_gain) do
		local key = "zenkai_" .. attr
		local total = char.flags[key] or 0
		local add = math.min(amount, cap - total)
		if add > 0 then
			char.flags[key] = total + add
			char.attributes[attr] = char.attributes[attr] + add
			gained_any = true
		end
	end
	if gained_any then
		char.flags.zenkai_last = os.time()
		dbil.players.mark_dirty(player)
		dbil.stats.recalculate(player)
		dbil.events.emit("zenkai", player)
		dbil.events.emit("notify", player, "Zenkai! Seu corpo se recuperou mais forte.", "power")
	end
end)
