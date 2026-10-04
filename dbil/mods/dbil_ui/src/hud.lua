-- Main HUD: HP / Ki / Stamina / XP bars, level + Power Level + state line,
-- and technique cooldowns. Only changed values are sent to clients.

local ui = dbil.ui
local cfg = dbil.config.hud
local colors = dbil.config.theme.colors
local colorize = core.colorize
local fmt_int = dbil.util.format_int

local BOTTOM = { x = 0.5, y = 1 }

local function create(player, state)
	local W, H, gap, y = cfg.bar_width, cfg.bar_height + 4, cfg.gap, cfg.bottom_offset
	local left = -gap / 2 - W
	local right = gap / 2
	local hud = {}
	hud.hp = ui.new_bar(player, { position = BOTTOM, x = left, y = y, width = W, height = H, color = colors.hp, label = true })
	hud.ki = ui.new_bar(player, { position = BOTTOM, x = right, y = y, width = W, height = H, color = colors.ki, label = true })
	local sy = y + H / 2 + cfg.small_bar_height / 2 + 6
	hud.stamina = ui.new_bar(player, { position = BOTTOM, x = left, y = sy, width = W, height = cfg.small_bar_height, color = colors.stamina })
	hud.xp = ui.new_bar(player, { position = BOTTOM, x = right, y = sy, width = W, height = cfg.small_bar_height, color = colors.xp })
	hud.status = ui.new_text(player, { position = BOTTOM, offset = { x = 0, y = y - H / 2 - 16 }, style = 1 })
	hud.techniques = ui.new_text(player, { position = BOTTOM, offset = { x = 0, y = y - H / 2 - 40 } })
	state.hud = hud
end

local function destroy(player, state)
	if not state.hud then
		return
	end
	for _, widget in pairs(state.hud) do
		widget:remove()
	end
	state.hud = nil
end

local function status_line(player, state)
	local char = state.char
	local parts = {
		colorize(colors.text, ("Nv %d"):format(char.level)),
		colorize(colors.power, "PL " .. dbil.power.format(dbil.power.get_current(player))),
	}
	if state.flight and state.flight.active then
		parts[#parts + 1] = colorize(colors.flight, state.flight.boosting and "VOO RÁPIDO" or "VOO")
	end
	if state.charge and state.charge.active then
		parts[#parts + 1] = colorize(colors.charging, "CARREGANDO KI")
	elseif state.casting then
		parts[#parts + 1] = colorize(colors.charging, "CONCENTRANDO: " .. state.casting.def.name)
	end
	if state.guard and state.guard.active then
		parts[#parts + 1] = colorize(colors.ki, "DEFESA")
	end
	if dbil.transformations then
		local form = dbil.transformations.get_active(player)
		if form then
			parts[#parts + 1] = colorize(form.color or colors.power, form.name:upper())
		end
	end
	return table.concat(parts, colorize(colors.text_dim, "  |  "))
end

local function techniques_line(player, state)
	local parts = {}
	for slot = 1, dbil.input.KIT_SLOTS.technique_count do
		local id, def = dbil.techniques.get_equipped(player, slot)
		if id then
			local key = tostring(dbil.input.KIT_SLOTS.technique_first + slot - 1)
			local cd = dbil.techniques.cooldown_remaining(player, id)
			local cost = dbil.ki.cost(player, dbil.techniques.compute(def,
				dbil.mastery.get_level(player, dbil.techniques.mastery_key(id)), 1).cost)
			local ready
			if cd > 0 then
				ready = colorize(colors.cooldown, ("%.1fs"):format(cd))
			elseif dbil.ki.get(player) < cost then
				ready = colorize(colors.hp, "sem Ki")
			else
				ready = colorize(colors.ready, "pronto")
			end
			parts[#parts + 1] = colorize(colors.text_dim, "[" .. key .. "] ") .. colorize(colors.text, def.name) .. " " .. ready
		end
	end
	return table.concat(parts, "    ")
end

local function update(player, state)
	local hud = state.hud
	if not hud then
		return
	end
	local d = state.derived
	local hp, ki, st = player:get_hp(), dbil.ki.get(player), dbil.resources.get(player, "stamina")
	local hp_ratio = hp / d.max_hp
	hud.hp:set(hp_ratio, ("Vida %s/%s"):format(fmt_int(hp), fmt_int(d.max_hp)),
		hp_ratio <= cfg.low_hp and colors.hp_low or colors.hp)
	hud.ki:set(ki / d.max_ki, ("Ki %s/%s"):format(fmt_int(ki), fmt_int(d.max_ki)))
	hud.stamina:set(st / d.max_stamina)
	local need = dbil.progression.xp_to_next(state.char.level)
	hud.xp:set(state.char.level >= dbil.config.progression.max_level and 1 or state.char.xp / need)
	hud.status:set(status_line(player, state))
	hud.techniques:set(techniques_line(player, state))
end

dbil.players.register_tick("hud", cfg.update_interval, function(player, state)
	dbil.log.protect("hud update", update, player, state)
end, 800)

dbil.events.on("player_joined", function(player)
	player:hud_set_flags({ healthbar = false, breathbar = true, minimap = true, minimap_radar = false })
end)

dbil.events.on("character_ready", function(player, char, state)
	destroy(player, state)
	create(player, state)
	update(player, state)
end, 200)

dbil.events.on("character_leaving", function(player, char, state)
	destroy(player, state)
end)

dbil.events.on("character_reset", function(player, state)
	destroy(player, state)
end)
