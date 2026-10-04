-- On-screen notifications (top center), fading after a few seconds.
-- Any system can call dbil.events.emit("notify", player, text, kind).
-- kinds: info, warning, success, level, xp, training, power

local ui = dbil.ui
local cfg = dbil.config.hud
local colors = dbil.config.theme.colors
local now = dbil.util.now

local KIND_COLORS = {
	info = colors.text,
	warning = colors.cooldown,
	success = colors.ready,
	level = colors.power,
	xp = colors.xp,
	training = colors.charging,
	power = colors.power,
	quest = colors.quest,
}

-- Important messages are also written to chat as a persistent log.
local TO_CHAT = { level = true, success = true, quest = true, power = true }

local function render(state)
	local n = state.notify
	if not n then
		return
	end
	for i = 1, cfg.notify_max do
		local entry = n.list[i]
		n.lines[i]:set(entry and core.colorize(entry.color, entry.text) or "")
	end
end

function ui.notify(player, text, kind)
	local state = dbil.players.get_state(player)
	kind = kind or "info"
	if TO_CHAT[kind] then
		core.chat_send_player(player:get_player_name(), core.colorize(KIND_COLORS[kind] or colors.text, text))
	end
	if not state or not state.notify then
		return
	end
	local list = state.notify.list
	-- Collapse identical consecutive messages.
	if list[1] and list[1].text == text then
		list[1].expires = now() + cfg.notify_time
		return
	end
	table.insert(list, 1, { text = text, color = KIND_COLORS[kind] or colors.text, expires = now() + cfg.notify_time })
	while #list > cfg.notify_max do
		table.remove(list)
	end
	render(state)
end

dbil.events.on("notify", function(player, text, kind)
	if player and player:is_player() then
		ui.notify(player, text, kind)
	end
end)

dbil.players.register_tick("notify_expire", 0.25, function(player, state)
	local n = state.notify
	if not n then
		return
	end
	local t = now()
	local changed = false
	for i = #n.list, 1, -1 do
		if t >= n.list[i].expires then
			table.remove(n.list, i)
			changed = true
		end
	end
	if changed then
		render(state)
	end
end)

local function destroy(player, state)
	if state.notify then
		for _, line in ipairs(state.notify.lines) do
			line:remove()
		end
		state.notify = nil
	end
end

dbil.events.on("character_ready", function(player, char, state)
	destroy(player, state)
	local lines = {}
	for i = 1, cfg.notify_max do
		lines[i] = ui.new_text(player, {
			position = { x = 0.5, y = 0.2 },
			offset = { x = 0, y = (i - 1) * 24 },
			style = 1,
			z = 100,
		})
	end
	state.notify = { list = {}, lines = lines }
end, 210)

dbil.events.on("character_leaving", destroy)
dbil.events.on("character_reset", destroy)

-- Gameplay tips for new players.
local TIPS = {
	"Dica: segure Aux1 (tecla E / botão Aux1) parado para carregar Ki.",
	"Dica: pule duas vezes ou use o item Voo para voar. Pulo sobe, agachar desce.",
	"Dica: Aux1 + andar dá um dash (esquiva) e corrida; no voo, ativa o voo rápido.",
	"Dica: segure Zoom (tecla Z / botão Zoom) para defender golpes de frente.",
	"Dica: Punhos: clique = golpe rápido, botão direito = golpe pesado. No celular: toque e toque longo.",
	"Dica: abra o inventário (tecla I) para ver sua ficha, técnicas e controles.",
	"Dica: Saibamen surgem dos canteiros ao redor da arena. Bonecos de treino ajudam a treinar.",
}

dbil.players.register_tick("tips", cfg.tip_interval, function(player, state)
	if not state.account.settings.show_tips or state.char.level >= 5 then
		return
	end
	state.tip_index = (state.tip_index or 0) % #TIPS + 1
	ui.notify(player, TIPS[state.tip_index], "info")
end)
