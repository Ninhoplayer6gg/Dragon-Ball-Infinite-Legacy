-- Character sheet, shown as the inventory screen (key I / inventory button).
-- Tabs: Status, Técnicas, Itens, Opções. The formspec is only re-sent when
-- its content changes.

local ui = dbil.ui
local esc = core.formspec_escape
local fmt_int = dbil.util.format_int
local colors = dbil.config.theme.colors

local W, H = 18, 11.5

-- Tabs are registered, so other modules (quests, transformations...) can add
-- their own pages: ui.register_sheet_tab(id, title, build_fn, fields_fn, order)
local tabs = {}

function ui.register_sheet_tab(id, title, build, on_fields, order)
	tabs[#tabs + 1] = { id = id, title = title, build = build, on_fields = on_fields, order = order or 100 }
	table.sort(tabs, function(a, b)
		return a.order < b.order
	end)
end

local function tab_titles()
	local titles = {}
	for i, tab in ipairs(tabs) do
		titles[i] = esc(tab.title)
	end
	return table.concat(titles, ",")
end

local function header(state)
	return table.concat({
		"formspec_version[6]",
		("size[%f,%f]"):format(W, H),
		"no_prepend[]",
		"bgcolor[#05070dcc;true]",
		"background9[0,0;1,1;dbil_ui_panel.png;true;8]",
		"style_type[label;font_size=+1]",
		("tabheader[0,0;tab;%s;%d;false;true]"):format(tab_titles(), state.sheet_tab or 1),
	})
end

local function bar(x, y, w, h, ratio, color)
	ratio = math.max(0, math.min(1, ratio))
	return ("box[%f,%f;%f,%f;#00000099]box[%f,%f;%f,%f;%s]"):format(x, y, w, h, x, y, w * ratio, h, color)
end

ui.sheet_size = { w = W, h = H }

function ui.sheet_bar(x, y, w, h, ratio, color)
	return bar(x, y, w, h, ratio, color)
end

local function line(x, y, text, color)
	return ("label[%f,%f;%s]"):format(x, y, core.colorize(color or colors.text, esc(text)))
end

local function status_tab(player, state)
	local char, d = state.char, state.derived
	local race = dbil.races.get(char.race)
	local need = dbil.progression.xp_to_next(char.level)
	local max_level = dbil.config.progression.max_level
	local out = {}
	local function add(s) out[#out + 1] = s end

	add(("hypertext[0.5,0.3;8.5,1.6;name;%s]"):format(esc(("<global color=#ffffff><big><b>%s</b></big>\n<style color=#9fb3d9>%s  •  Nível %d</style>")
		:format(char.name, race and race.name or char.race, char.level))))
	add(line(0.5, 2.0, ("Experiência: %s / %s"):format(fmt_int(char.xp), char.level >= max_level and "MÁX" or fmt_int(need)), colors.xp))
	add(bar(0.5, 2.35, 8.3, 0.25, char.level >= max_level and 1 or char.xp / need, colors.xp))
	add(line(0.5, 3.1, "Poder de Luta (base): " .. dbil.power.format(dbil.power.get_base(player)), colors.power))
	add(line(0.5, 3.6, "PL atual: no HUD (varia com Ki, Vida e estado)", colors.text_dim))
	add(line(0.5, 4.4, ("Vida máxima: %s"):format(fmt_int(d.max_hp)), colors.hp))
	add(line(0.5, 4.9, ("Ki máximo: %s"):format(fmt_int(d.max_ki)), colors.ki))
	add(line(0.5, 5.4, ("Stamina máxima: %s"):format(fmt_int(d.max_stamina)), colors.stamina))
	add(line(0.5, 6.1, ("Dano físico: x%.2f    Dano de Ki: x%.2f"):format(d.melee_mult, d.ki_mult)))
	add(line(0.5, 6.6, ("Redução de dano: %d%%    Custo de Ki: %d%%"):format(
		math.floor(d.defense * 100 + 0.5), math.floor(d.ki_cost_mult * 100 + 0.5))))
	add(line(0.5, 7.1, ("Velocidade de movimento: x%.2f"):format(d.move_speed)))
	local s = char.stats
	add(line(0.5, 8.0, ("Inimigos derrotados: %d    Derrotas: %d"):format(s.kills or 0, s.deaths or 0), colors.text_dim))
	if race then
		add(line(0.5, 8.8, "Traços raciais:", colors.power))
		for i, feature in ipairs(race.features) do
			if i > 3 then break end
			add(line(0.7, 8.8 + i * 0.5, "• " .. feature, colors.text_dim))
		end
	end

	-- Attributes with training progress.
	add(line(9.6, 0.8, "Atributos", colors.power))
	local cap = dbil.progression.training_cap(char.level)
	for i, attr in ipairs(dbil.ATTRIBUTES) do
		local y = 1.2 + i * 1.3
		local base = char.attributes[attr]
		local final = state.attributes[attr]
		local gained = char.training.gained[attr] or 0
		local points = char.training.points[attr] or 0
		local cost = dbil.progression.training_cost(gained)
		local value = ("%.1f"):format(final)
		if math.abs(final - base) > 0.05 then
			value = value .. (" (base %.1f)"):format(base)
		end
		add(line(9.6, y, dbil.ATTRIBUTE_INFO[attr].name .. ": " .. value))
		add(line(9.6, y + 0.45, ("Treino +%d/%d"):format(gained, cap), colors.text_dim))
		add(bar(12.4, y + 0.33, 5.1, 0.22, gained >= cap and 1 or points / cost, gained >= cap and colors.ready or colors.charging))
	end
	add(line(9.6, 9.3, "Treine lutando, carregando Ki, voando,", colors.text_dim))
	add(line(9.6, 9.8, "defendendo e usando técnicas.", colors.text_dim))
	add(line(9.6, 10.3, "O limite de treino sobe a cada nível.", colors.text_dim))
	return table.concat(out)
end

local function techniques_tab(player, state)
	local char = state.char
	local out = {}
	local function add(s) out[#out + 1] = s end
	add(line(0.5, 0.7, "Técnicas — toque em 1-4 para equipar no espaço da barra rápida", colors.power))
	local slot_of = {}
	for i, id in ipairs(char.techniques.equipped) do
		slot_of[id] = i
	end
	local y = 1.3
	for id, def in dbil.techniques.iter() do
		local learned = char.techniques.learned[id]
		add(("box[0.5,%f;17,1.9;%s]"):format(y, learned and "#16243fdd" or "#11151fdd"))
		if def.icon then
			add(("image[0.7,%f;1.5,1.5;%s]"):format(y + 0.2, esc(def.icon) .. (learned and "" or "^[colorize:#000000:150")))
		end
		add(line(2.4, y + 0.4, def.name, learned and colors.text or colors.text_dim))
		local m = dbil.mastery.get(player, dbil.techniques.mastery_key(id))
		local numbers = dbil.techniques.compute(def, m.level, 1)
		local info = ("Dano %d  •  Ki %d  •  Recarga %.1fs"):format(
			math.floor(numbers.damage + 0.5), math.floor(dbil.ki.cost(player, numbers.cost) + 0.5), numbers.cooldown)
		if def.max_charge_time > 0 then
			info = info .. "  •  Carregável"
		end
		add(line(2.4, y + 0.9, info, colors.text_dim))
		if learned then
			add(line(2.4, y + 1.4, ("Maestria %d/%d"):format(m.level, def.mastery.max_level), colors.charging))
			local need = dbil.mastery.xp_to_next(m.level)
			add(bar(4.6, y + 1.3, 3, 0.2, m.level >= def.mastery.max_level and 1 or m.xp / need, colors.charging))
			for slot = 1, dbil.input.KIT_SLOTS.technique_count do
				local equipped_here = slot_of[id] == slot
				add(("style[equip_%s_%d;bgcolor=%s]"):format(id, slot, equipped_here and "#ffb000" or "#33466e"))
				add(("button[%f,%f;1.1,1.1;equip_%s_%d;%d]"):format(12.6 + (slot - 1) * 1.2, y + 0.4, id, slot, slot))
			end
		else
			local _, reason = dbil.techniques.meets_requirements(char, def)
			add(line(10.5, y + 0.9, "Bloqueada: " .. (reason or "requisitos"), colors.cooldown))
		end
		y = y + 2.1
	end
	return table.concat(out)
end

local function items_tab()
	return table.concat({
		line(0.5, 0.7, "Itens  (os itens do kit de combate ficam fixos na barra rápida)", colors.power),
		"list[current_player;main;3.85,1.4;8,1;]",
		"list[current_player;main;3.85,2.9;8,3;8]",
		"listring[current_player;main]",
		line(0.5, 7.7, "Senzu: toque/clique com ela na mão para comer e restaurar tudo.", colors.text_dim),
	})
end

local function options_tab(player, state)
	local settings = state.account.settings
	local help = table.concat({
		"<global color=#dfe6f3 size=14>",
		"<b><style color=#ffd866>PC</style></b>",
		"Mover: WASD  •  Pular / subir no voo: Espaço  •  Descer / agachar: Shift",
		"Carregar Ki: segure E (Aux1) parado  •  Dash/Correr: E + direção",
		"Voo: item Voo ou pule de novo no ar  •  Voo rápido: E + direção voando",
		"Defesa: segure Z (Zoom)  •  Punhos: clique = rápido, botão direito = pesado",
		"Técnicas: clique com a técnica selecionada (segure para carregar as carregáveis)",
		"",
		"<b><style color=#ffd866>Celular</style></b>",
		"Joystick: mover  •  Pulo: subir  •  Agachar: descer  •  Aux1: Ki / dash",
		"Zoom: defesa  •  Toque na tela: ação principal  •  Toque longo: ação secundária",
		"Toque na barra rápida para trocar entre Punhos, Voo e Técnicas",
	}, "\n")
	return table.concat({
		line(0.5, 0.7, "Opções", colors.power),
		("checkbox[0.5,1.5;opt_aim_assist;Mira assistida para técnicas (recomendado no celular);%s]"):format(tostring(settings.aim_assist)),
		("checkbox[0.5,2.2;opt_show_tips;Mostrar dicas na tela;%s]"):format(tostring(settings.show_tips)),
		("hypertext[0.5,3.1;17,7.8;help;%s]"):format(esc(help)),
	})
end

function ui.sheet_line(x, y, text, color)
	return line(x, y, text, color)
end

local function technique_fields(player, state, fields)
	for key in pairs(fields) do
		local id, slot = key:match("^equip_([%w_]+)_(%d)$")
		if id then
			dbil.techniques.equip(player, tonumber(slot), id)
		end
	end
end

local function option_fields(player, state, fields)
	if fields.opt_aim_assist then
		state.account.settings.aim_assist = fields.opt_aim_assist == "true"
		dbil.players.mark_dirty(player)
	end
	if fields.opt_show_tips then
		state.account.settings.show_tips = fields.opt_show_tips == "true"
		dbil.players.mark_dirty(player)
	end
end

ui.register_sheet_tab("status", "Status", status_tab, nil, 10)
ui.register_sheet_tab("techniques", "Técnicas", techniques_tab, technique_fields, 20)
ui.register_sheet_tab("items", "Itens", items_tab, nil, 50)
ui.register_sheet_tab("options", "Opções", options_tab, option_fields, 90)

function ui.sheet_formspec(player, state)
	local index = math.max(1, math.min(#tabs, state.sheet_tab or 1))
	return header(state) .. tabs[index].build(player, state)
end

function ui.refresh_sheet(player)
	local state = dbil.players.get_state(player)
	if not state or not state.ready or not state.derived then
		return
	end
	local fs = ui.sheet_formspec(player, state)
	if fs ~= state.sheet_last then
		state.sheet_last = fs
		player:set_inventory_formspec(fs)
	end
end

core.register_on_player_receive_fields(function(player, formname, fields)
	if formname ~= "" or not dbil.players.is_ready(player) then
		return false
	end
	local state = dbil.players.get_state(player)
	local current = tabs[state.sheet_tab or 1]
	if current and current.on_fields then
		current.on_fields(player, state, fields)
	end
	if fields.tab then
		state.sheet_tab = math.max(1, math.min(#tabs, tonumber(fields.tab) or 1))
	end
	ui.refresh_sheet(player)
	return true
end)

dbil.events.on("character_ready", function(player, char, state)
	state.sheet_tab = state.sheet_tab or 1
	state.sheet_last = nil
	ui.refresh_sheet(player)
end, 220)

for _, event in ipairs({ "level_up", "techniques_changed", "mastery_level_up", "attribute_trained", "zenkai" }) do
	dbil.events.on(event, function(player)
		ui.refresh_sheet(player)
	end)
end

-- Slowly changing values (XP, training progress) are refreshed periodically.
dbil.players.register_tick("sheet_refresh", 2, function(player)
	ui.refresh_sheet(player)
end, 850)
