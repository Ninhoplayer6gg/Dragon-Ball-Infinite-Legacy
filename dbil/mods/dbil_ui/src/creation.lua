-- Character creation screen. Shown when a player has no character; the
-- player cannot play until a character exists. All validation happens on the
-- server (dbil.players.create_character).

local ui = dbil.ui
local esc = core.formspec_escape
local FORM = "dbil_ui:create"

local function selected_race(state)
	local c = state.creation
	if c.race and dbil.races.get(c.race) then
		return c.race
	end
	local first = dbil.races.playable()[1]
	c.race = first and first.id
	return c.race
end

local function race_card(entry, x, y, w, h, selected)
	local def = entry.def
	local lines = { "<global margin=4 valign=top color=#dfe6f3 size=13>" }
	lines[#lines + 1] = def.description
	for _, feature in ipairs(def.features) do
		lines[#lines + 1] = "<style color=#ffd866>•</style> " .. feature
	end
	return table.concat({
		("box[%f,%f;%f,%f;%s]"):format(x, y, w, h, selected and "#2b4f8fff" or "#141d33ff"),
		("style[race_%s;bgcolor=%s;font_size=+4;textcolor=%s]"):format(entry.id,
			selected and "#ffb000" or "#33466e", selected and "#1a1200" or "#ffffff"),
		("button[%f,%f;%f,1.1;race_%s;%s]"):format(x + 0.25, y + 0.25, w - 0.5, entry.id,
			esc((selected and "> " or "") .. def.name .. (selected and " <" or ""))),
		("hypertext[%f,%f;%f,%f;desc_%s;%s]"):format(x + 0.25, y + 1.5, w - 0.5, h - 1.7,
			entry.id, esc(table.concat(lines, "\n"))),
	})
end

function ui.creation_formspec(state)
	local c = state.creation
	local race = selected_race(state)
	local races = dbil.races.playable()
	local W, H = 18, 11.5
	local parts = {
		"formspec_version[6]",
		("size[%f,%f]"):format(W, H),
		"no_prepend[]",
		"bgcolor[#05070dcc;true]",
		"background9[0,0;1,1;dbil_ui_panel.png;true;8]",
		"style_type[label;font_size=+2]",
		"style_type[field;font_size=+4]",
		("hypertext[0.5,0.3;%f,1.2;title;%s]"):format(W - 1, esc(
			"<global halign=center color=#ffffff><big><b>Dragon Ball: Infinite Legacy</b></big>\n"
			.. "<style color=#9fb3d9>Crie o guerreiro que vai escrever esta nova linha do tempo</style>")),
		("field[0.5,2.3;8.5,1.1;name;Nome do personagem;%s]"):format(esc(c.name or "")),
		"field_close_on_enter[name;false]",
	}
	if c.error then
		parts[#parts + 1] = ("hypertext[9.4,2.3;8.1,1.1;err;%s]"):format(esc("<global valign=middle color=#ff7070>" .. c.error))
	end
	local n = #races
	local gap = 0.4
	local card_w = (W - 1 - gap * (n - 1)) / n
	for i, entry in ipairs(races) do
		parts[#parts + 1] = race_card(entry, 0.5 + (i - 1) * (card_w + gap), 3.8, card_w, 5.9, entry.id == race)
	end
	parts[#parts + 1] = "style[create;bgcolor=#ff8c1a;textcolor=#1a0d00;font_size=+6]"
	parts[#parts + 1] = ("button[0.5,10;%f,1.2;create;Começar a jornada]"):format(W - 1)
	return table.concat(parts)
end

function ui.show_creation(player)
	local state = dbil.players.get_state(player)
	if not state or state.ready then
		return
	end
	state.creation = state.creation or {}
	local fs = ui.creation_formspec(state)
	player:set_inventory_formspec(fs)
	core.show_formspec(player:get_player_name(), FORM, fs)
end

core.register_on_player_receive_fields(function(player, formname, fields)
	if formname ~= FORM and not (formname == "" and not dbil.players.is_ready(player)) then
		return false
	end
	local state = dbil.players.get_state(player)
	if not state or state.ready then
		return true
	end
	state.creation = state.creation or {}
	local c = state.creation
	if fields.name then
		c.name = fields.name
	end
	for _, entry in ipairs(dbil.races.playable()) do
		if fields["race_" .. entry.id] then
			c.race = entry.id
			c.error = nil
			ui.show_creation(player)
			return true
		end
	end
	if fields.create or fields.key_enter_field == "name" then
		local ok, err = dbil.players.create_character(player, c.name, selected_race(state))
		if ok then
			state.creation = nil
			core.close_formspec(player:get_player_name(), FORM)
		else
			c.error = err
			ui.show_creation(player)
		end
		return true
	end
	if fields.quit then
		-- No character yet: keep the creation screen up.
		local name = player:get_player_name()
		core.after(0.4, function()
			local p = core.get_player_by_name(name)
			if p and not dbil.players.is_ready(p) then
				ui.show_creation(p)
			end
		end)
	end
	return true
end)

dbil.events.on("character_required", function(player, state)
	dbil.physics.set(player, "creating", { speed = 0, jump = 0 })
	local name = player:get_player_name()
	-- Small delay so the client finished joining before the form opens.
	core.after(0.5, function()
		local p = core.get_player_by_name(name)
		if p then
			ui.show_creation(p)
		end
	end)
end)

dbil.events.on("character_ready", function(player)
	dbil.physics.clear(player, "creating")
	core.close_formspec(player:get_player_name(), FORM)
end, 5)
