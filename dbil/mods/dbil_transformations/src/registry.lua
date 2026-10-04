-- Transformation registry.
--
-- A transformation is data: who can use it, how it is unlocked, what it costs,
-- what it multiplies and how mastery improves it. Paths are free-form tags
-- (classic, divine, primal, instinct, destroyer, kaioken...) and requirements
-- may reference any other form, flag or mastery, so paths can mix instead of
-- forming a rigid tree. Nothing checks race/form names in code.
--
--   dbil.transformations.register("super_saiyan", { ... })

local S = dbil.schema
local tf = dbil.transformations

local modifier_schema = { type = "map", key = "string", value = {
	type = "table", fields = { add = S.opt(S.num(0)), mul = S.opt(S.num(1)) },
} }

tf.schema = {
	type = "table",
	fields = {
		name = { type = "string", max_len = 60 },
		description = S.str("", 600),
		color = S.str("#ffd866", 16),
		races = S.opt({ type = "list", item = S.str("", 40) }),
		paths = { type = "list", item = S.str("", 40), default = {} },
		-- Forms this one can be entered from (e.g. SSJ2 from SSJ). Empty = base form only.
		from = { type = "list", item = S.str("", 64), default = {} },
		requirements = {
			type = "table",
			fields = {
				level = S.int(1, 1, 1000),
				forms = S.opt({ type = "list", item = S.str("", 64) }),      -- must be unlocked
				flags = S.opt({ type = "list", item = S.str("", 64) }),
				mastery = S.opt({ type = "map", key = "string", value = S.int(0, 0) }),
			},
		},
		-- auto: unlocked as soon as the requirements are met; otherwise unlocked
		-- by story/quests/masters (dbil.transformations.unlock).
		unlock = { type = "table", fields = { auto = S.bool(false) } },
		modifiers = modifier_schema,
		cost = { type = "table", fields = { ki = S.num(0, 0) } },
		drain = {
			type = "table",
			fields = {
				ki = S.num(0, 0),           -- per second
				stamina = S.num(0, 0),      -- per second
				hp_percent = S.num(0, 0),   -- % of max HP per second (never lethal)
			},
		},
		transform_time = S.num(1, 0, 30),
		mastery = {
			type = "table",
			fields = {
				max_level = S.int(10, 0, 100),
				xp_per_second = S.num(1, 0),
				drain_reduction_per_level = S.num(0.07, 0, 0.1),
				time_reduction_per_level = S.num(0.08, 0, 0.1),
				power_bonus_per_level = S.num(0.03, 0, 1),
			},
		},
		appearance = S.opt({
			type = "table",
			fields = {
				hair = S.opt(S.str(nil, 200)),
				skin_mod = S.opt(S.str(nil, 200)),
			},
		}),
		aura = { type = "table", fields = { color = S.str("#ffffff", 16), amount = S.int(36, 0, 200) } },
	},
}

local reg = dbil.registry.new("transformation", { schema = tf.schema })
tf.registry = reg

function tf.register(id, def)
	return reg:register(id, def)
end

function tf.get(id)
	return reg:get(id)
end

function tf.iter()
	return reg:iter()
end

function tf.mastery_key(id)
	return "transformation:" .. id
end

--- Checks requirements for a character. Returns ok, reason.
function tf.meets_requirements(char, def)
	if def.races and not dbil.util.contains(def.races, char.race) then
		return false, "Raça incompatível"
	end
	local req = def.requirements
	if char.level < req.level then
		return false, ("Requer nível %d"):format(req.level)
	end
	for _, form in ipairs(req.forms or {}) do
		if not char.transformations.unlocked[form] then
			local fdef = reg:get(form)
			return false, "Requer " .. (fdef and fdef.name or form)
		end
	end
	for _, flag in ipairs(req.flags or {}) do
		if not char.flags[flag] then
			return false, "Requisito de história não cumprido"
		end
	end
	for key, level in pairs(req.mastery or {}) do
		local entry = char.mastery[key]
		if not entry or entry.level < level then
			return false, "Maestria insuficiente"
		end
	end
	return true
end

function tf.is_unlocked(player, id)
	local char = dbil.players.get_character(player)
	return char ~= nil and char.transformations.unlocked[id] == true
end

function tf.unlock(player, id, opts)
	local char = dbil.players.get_character(player)
	local def = reg:get(id)
	if not char or not def then
		return false, "Transformação desconhecida."
	end
	if char.transformations.unlocked[id] then
		return false, "Já desbloqueada."
	end
	if not (opts and opts.force) then
		local ok, reason = tf.meets_requirements(char, def)
		if not ok then
			return false, reason
		end
	end
	char.transformations.unlocked[id] = true
	dbil.players.mark_dirty(player)
	dbil.events.emit("transformation_unlocked", player, id)
	dbil.events.emit("notify", player, "Transformação desbloqueada: " .. def.name, "power")
	return true
end

function tf.lock(player, id)
	local char = dbil.players.get_character(player)
	if not char or not char.transformations.unlocked[id] then
		return false
	end
	char.transformations.unlocked[id] = nil
	dbil.players.mark_dirty(player)
	dbil.events.emit("transformation_locked", player, id)
	return true
end

function tf.check_auto_unlock(player)
	local char = dbil.players.get_character(player)
	if not char then
		return
	end
	for id, def in reg:iter() do
		if def.unlock.auto and not char.transformations.unlocked[id] and tf.meets_requirements(char, def) then
			tf.unlock(player, id)
		end
	end
end

dbil.events.on("level_up", tf.check_auto_unlock)
dbil.events.on("mastery_level_up", tf.check_auto_unlock)
dbil.events.on("character_ready", function(player)
	tf.check_auto_unlock(player)
end, 145)
