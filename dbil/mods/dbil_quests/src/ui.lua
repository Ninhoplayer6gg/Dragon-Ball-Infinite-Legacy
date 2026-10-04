-- Quest tracker (HUD, right side) and the "Missões" sheet tab.

local quests = dbil.quests
local colors = dbil.config.theme.colors
local esc = core.formspec_escape

local MAX_LINES = 5
local RIGHT = { x = 1, y = 0.3 }

local function tracker_lines(player, state)
	local lines = {}
	for id in pairs(state.char.quests.active) do
		local def = quests.get(id)
		local progress = def and quests.progress(player, id)
		if progress then
			lines[#lines + 1] = core.colorize(colors.quest, def.title)
			for _, p in ipairs(progress) do
				local done = p.done >= p.count
				lines[#lines + 1] = core.colorize(done and colors.ready or colors.text,
					("%s %s (%d/%d)"):format(done and "+" or "-", p.text, math.floor(p.done), p.count))
			end
		end
		if #lines >= MAX_LINES then
			break
		end
	end
	return lines
end

local function refresh(player)
	local state = dbil.players.get_state(player)
	if not state or not state.ready or not state.quest_hud then
		return
	end
	local lines = tracker_lines(player, state)
	for i = 1, MAX_LINES do
		state.quest_hud[i]:set(lines[i] or "")
	end
end
quests.refresh_tracker = refresh

dbil.events.on("character_ready", function(player, char, state)
	if state.quest_hud then
		for _, t in ipairs(state.quest_hud) do t:remove() end
	end
	state.quest_hud = {}
	for i = 1, MAX_LINES do
		state.quest_hud[i] = dbil.ui.new_text(player, {
			position = RIGHT,
			offset = { x = -16, y = (i - 1) * 22 },
			alignment = { x = -1, y = 0 },
			z = 20,
		})
	end
	refresh(player)
	-- The client reports its window/touch information shortly after joining.
	local name = player:get_player_name()
	core.after(1.5, function()
		local p = core.get_player_by_name(name)
		local st = p and dbil.players.get_state(p)
		if st and st.quest_hud and dbil.ui.is_touch(p) then
			for i, line in ipairs(st.quest_hud) do
				line:set_offset({ x = -16 - dbil.config.hud.touch_right_margin, y = (i - 1) * 22 })
			end
		end
	end)
end, 230)

dbil.events.on("character_leaving", function(player, char, state)
	if state.quest_hud then
		for _, t in ipairs(state.quest_hud) do t:remove() end
		state.quest_hud = nil
	end
end)

for _, event in ipairs({ "quest_started", "quest_progress", "quest_completed" }) do
	dbil.events.on(event, function(player)
		refresh(player)
		dbil.ui.refresh_sheet(player)
	end)
end

local function build(player, state)
	local char = state.char
	local line = dbil.ui.sheet_line
	local out = { line(0.5, 0.7, "Missões", colors.power) }
	local y = 1.3
	for id, def in quests.iter() do
		local active = char.quests.active[id]
		local done = char.quests.completed[id]
		if active or done then
			out[#out + 1] = ("box[0.5,%f;17,%f;%s]"):format(y, active and 2.6 or 0.9, active and "#16243fdd" or "#11151fdd")
			out[#out + 1] = line(0.8, y + 0.45, def.title .. (done and "  (concluída)" or ""), done and colors.ready or colors.quest)
			if active then
				out[#out + 1] = ("textarea[0.8,%f;9,1.6;;;%s]"):format(y + 0.8, esc(def.description))
				for i, p in ipairs(quests.progress(player, id)) do
					out[#out + 1] = line(10.2, y + 0.35 + i * 0.5, ("%s (%d/%d)"):format(p.text, math.floor(p.done), p.count),
						p.done >= p.count and colors.ready or colors.text)
				end
				y = y + 2.8
			else
				y = y + 1.1
			end
		end
	end
	if y == 1.3 then
		out[#out + 1] = line(0.8, 1.6, "Nenhuma missão no momento.", colors.text_dim)
	end
	return table.concat(out)
end

dbil.ui.register_sheet_tab("quests", "Missões", build, nil, 40)
