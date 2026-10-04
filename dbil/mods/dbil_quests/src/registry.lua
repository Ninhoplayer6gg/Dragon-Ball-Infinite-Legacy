-- Quest registry.
--
-- Objectives listen to dbil events. Each objective names an event and a
-- `progress(player, ...)` function returning how much that event advances it
-- for that player (nil/0 = no progress). Masters will hand out quests with
-- the same structure (giver = master id) — training sessions and challenges
-- are just quests with special objectives and rewards (techniques, flags).
--
--   dbil.quests.register("first_steps", {
--       title = "...", description = "...",
--       objectives = { { event = "technique_used", count = 3, text = "...",
--                        progress = function(player, caster) return caster == player and 1 end } },
--       rewards = { xp = 100, items = { "dbil_items:senzu" }, techniques = {}, flags = {} },
--       next = "another_quest", auto_start = false,
--   })

local S = dbil.schema
local quests = dbil.quests

quests.schema = {
	type = "table",
	fields = {
		title = { type = "string", max_len = 80 },
		description = S.str("", 1000),
		giver = S.str("system", 64),
		auto_start = S.bool(false),
		requirements = {
			type = "table",
			fields = {
				level = S.int(1, 1, 1000),
				quests = S.opt({ type = "list", item = S.str("", 64) }),
			},
		},
		objectives = {
			type = "list",
			item = {
				type = "table",
				fields = {
					event = { type = "string", max_len = 64 },
					count = S.num(1, 1),
					text = { type = "string", max_len = 120 },
					progress = { type = "function" },
				},
			},
		},
		rewards = {
			type = "table",
			fields = {
				xp = S.num(0, 0),
				items = { type = "list", item = S.str("", 100), default = {} },
				techniques = { type = "list", item = S.str("", 64), default = {} },
				flags = { type = "list", item = S.str("", 64), default = {} },
			},
		},
		next = S.opt(S.str(nil, 64)),
	},
}

local reg = dbil.registry.new("quest", { schema = quests.schema })
quests.registry = reg

-- event name -> list of { quest_id, index }
quests.listeners = {}

function quests.register(id, def)
	def = reg:register(id, def)
	for index, objective in ipairs(def.objectives) do
		local list = quests.listeners[objective.event]
		if not list then
			list = {}
			quests.listeners[objective.event] = list
			dbil.events.on(objective.event, function(...)
				quests.dispatch(objective.event, ...)
			end)
		end
		list[#list + 1] = { quest = id, index = index }
	end
	return def
end

function quests.get(id)
	return reg:get(id)
end

function quests.iter()
	return reg:iter()
end
