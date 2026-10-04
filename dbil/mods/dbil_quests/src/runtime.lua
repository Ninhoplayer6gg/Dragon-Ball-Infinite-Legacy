-- Quest progress, completion and rewards (all server-side).
--
-- API: dbil.quests.start(player, id), complete(player, id), abandon(player, id),
--      is_active(player, id), is_completed(player, id), progress(player, id)
-- Events: quest_started(player, id), quest_progress(player, id),
--         quest_completed(player, id)

local quests = dbil.quests

local function char_of(player)
	return dbil.players.get_character(player)
end

function quests.is_active(player, id)
	local char = char_of(player)
	return char ~= nil and char.quests.active[id] ~= nil
end

function quests.is_completed(player, id)
	local char = char_of(player)
	return char ~= nil and char.quests.completed[id] ~= nil
end

function quests.can_start(player, id)
	local char = char_of(player)
	local def = quests.get(id)
	if not char or not def then
		return false, "Missão desconhecida."
	end
	if char.quests.active[id] or char.quests.completed[id] then
		return false, "Missão já iniciada ou concluída."
	end
	if char.level < def.requirements.level then
		return false, ("Requer nível %d."):format(def.requirements.level)
	end
	for _, other in ipairs(def.requirements.quests or {}) do
		if not char.quests.completed[other] then
			return false, "Requer outra missão."
		end
	end
	return true
end

function quests.start(player, id, silent)
	local ok, err = quests.can_start(player, id)
	if not ok then
		return false, err
	end
	local char = char_of(player)
	char.quests.active[id] = { progress = {}, started_at = os.time() }
	dbil.players.mark_dirty(player)
	dbil.events.emit("quest_started", player, id)
	if not silent then
		dbil.events.emit("notify", player, "Nova missão: " .. quests.get(id).title, "quest")
	end
	return true
end

function quests.abandon(player, id)
	local char = char_of(player)
	if not char or not char.quests.active[id] then
		return false
	end
	char.quests.active[id] = nil
	dbil.players.mark_dirty(player)
	dbil.events.emit("quest_progress", player, id)
	return true
end

local function give_rewards(player, def)
	local r = def.rewards
	if r.xp > 0 then
		dbil.progression.add_xp(player, r.xp, "quest")
	end
	local inv = player:get_inventory()
	for _, item in ipairs(r.items) do
		local stack = ItemStack(item)
		if core.registered_items[stack:get_name()] then
			local left = inv:add_item("main", stack)
			if not left:is_empty() then
				core.add_item(player:get_pos(), left)
			end
		end
	end
	for _, tech in ipairs(r.techniques) do
		dbil.techniques.learn(player, tech, { force = true })
	end
	local char = char_of(player)
	for _, flag in ipairs(r.flags) do
		char.flags[flag] = true
	end
end

function quests.complete(player, id)
	local char = char_of(player)
	local def = quests.get(id)
	if not char or not def or not char.quests.active[id] then
		return false
	end
	char.quests.active[id] = nil
	char.quests.completed[id] = os.time()
	give_rewards(player, def)
	dbil.players.mark_dirty(player)
	dbil.events.emit("quest_completed", player, id)
	dbil.events.emit("notify", player, "Missão concluída: " .. def.title, "quest")
	if def.next then
		quests.start(player, def.next)
	end
	dbil.players.save(player)
	return true
end

--- Progress of each objective: list of { done, count, text }.
function quests.progress(player, id)
	local char = char_of(player)
	local def = quests.get(id)
	local entry = char and char.quests.active[id]
	if not def or not entry then
		return nil
	end
	local out = {}
	for i, objective in ipairs(def.objectives) do
		out[i] = {
			done = math.min(entry.progress[i] or 0, objective.count),
			count = objective.count,
			text = objective.text,
		}
	end
	return out
end

local function check_done(player, id)
	local progress = quests.progress(player, id)
	for _, p in ipairs(progress) do
		if p.done < p.count then
			return false
		end
	end
	return true
end

--- Called for every event that some objective listens to.
function quests.dispatch(event, ...)
	local list = quests.listeners[event]
	if not list then
		return
	end
	local args = { ... }
	local n = select("#", ...)
	dbil.players.for_each_ready(function(player, state)
		local active = state.char.quests.active
		for _, ref in ipairs(list) do
			local entry = active[ref.quest]
			if entry then
				local objective = quests.get(ref.quest).objectives[ref.index]
				local current = entry.progress[ref.index] or 0
				if current < objective.count then
					local add = objective.progress(player, unpack(args, 1, n))
					if type(add) == "number" and add > 0 then
						entry.progress[ref.index] = math.min(objective.count, current + add)
						dbil.players.mark_dirty(player)
						dbil.events.emit("quest_progress", player, ref.quest)
						if check_done(player, ref.quest) then
							quests.complete(player, ref.quest)
						end
					end
				end
			end
		end
	end)
end

--- Starts quests flagged auto_start whose requirements are met.
function quests.check_auto_start(player)
	for id, def in quests.iter() do
		if def.auto_start and quests.can_start(player, id) then
			quests.start(player, id)
		end
	end
end

dbil.events.on("character_ready", function(player)
	quests.check_auto_start(player)
end, 160)

dbil.events.on("level_up", function(player)
	quests.check_auto_start(player)
end)
