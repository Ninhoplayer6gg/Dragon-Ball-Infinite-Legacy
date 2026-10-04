-- Technique registry: techniques are declared as data and executed by
-- generic systems (shapes + projectile engine + casting). Adding Kamehameha,
-- Masenko, Destructo Disc... means adding a definition (and, when needed, a
-- new shape), never touching the core systems.
--
--   dbil.techniques.register("ki_blast", { name = "...", shape = "ball", ... })
--
-- The same data format is meant for future player-made techniques: a custom
-- technique is a definition built from a shape + properties + visuals.

local S = dbil.schema
local techniques = dbil.techniques
local mastery_cfg = dbil.config.progression.mastery
local tcfg = dbil.config.techniques

techniques.TYPES = { "projectile", "beam", "melee", "buff", "utility" }

techniques.schema = {
	type = "table",
	fields = {
		name = { type = "string", max_len = 60 },
		description = S.str("", 600),
		type = S.str("projectile", 20, techniques.TYPES),
		shape = S.str("ball", 40),
		icon = S.opt(S.str(nil, 200)),
		damage = S.num(10, 0, 100000),
		ki_cost = S.num(10, 0, 100000),
		charge_time = S.num(0, 0, 30),        -- minimum cast time
		max_charge_time = S.num(0, 0, 30),    -- holding longer powers it up (0 = no)
		max_charge_mult = S.num(1, 1, 10),    -- damage/size multiplier at full charge
		cooldown = S.num(1, 0, 600),
		speed = S.num(20, 0.1, 200),
		range = S.num(50, 1, 500),
		size = S.num(0.4, 0.05, 20),           -- radius in nodes
		knockback = S.num(0, 0, 100),
		lift = S.num(0, 0, 100),
		hitstun = S.num(0, 0, 10),
		animation = S.str("fire", 40),
		-- Free-form behaviour flags read by shapes/projectiles:
		-- piercing (bool), explosion_radius (n), count (n), spread_degrees (n)...
		properties = { type = "map", key = "string", value = { type = "any" }, default = {} },
		requirements = {
			type = "table",
			fields = {
				level = S.int(1, 1, 1000),
				races = S.opt({ type = "list", item = S.str("", 40) }),
				techniques = S.opt({ type = "list", item = S.str("", 64) }),
				flags = S.opt({ type = "list", item = S.str("", 64) }),
			},
		},
		-- auto: learned automatically when the requirements are met.
		-- Masters/quests can teach techniques with auto = false.
		learn = { type = "table", fields = { auto = S.bool(false) } },
		mastery = {
			type = "table",
			fields = {
				max_level = S.int(mastery_cfg.default_max_level, 0, 100),
				xp_per_use = S.num(4, 0),
				xp_per_hit = S.num(6, 0),
				damage_per_level = S.num(0.05, 0, 1),
				cost_reduction_per_level = S.num(0.03, 0, 0.1),
				cooldown_reduction_per_level = S.num(0.02, 0, 0.1),
				charge_reduction_per_level = S.num(0.04, 0, 0.1),
			},
		},
		visual = {
			type = "table",
			fields = {
				texture = S.str("ki_ball", 200),
				color = S.str("#7fd4ff", 16),
				trail = S.str("projectile_trail", 40),
				impact = S.str("ki_explosion", 40),
				sound_fire = S.str("ki_fire", 40),
				sound_impact = S.str("explosion", 40),
				sound_charge = S.str("ki_charge_wave", 40),
			},
		},
	},
}

local reg = dbil.registry.new("technique", { schema = techniques.schema })
techniques.registry = reg

function techniques.register(id, def)
	return reg:register(id, def)
end

function techniques.get(id)
	return reg:get(id)
end

function techniques.iter()
	return reg:iter()
end

function techniques.mastery_key(id)
	return "technique:" .. id
end

-- Shapes ---------------------------------------------------------------------

local shapes = {}

--- Registers how a technique shape is fired:
-- def.fire(caster, technique_def, params) where params contains
-- origin, dir, damage, size, speed, range, charge_mult, snapshot.
function techniques.register_shape(id, def)
	assert(type(def.fire) == "function", "shape needs fire(): " .. id)
	shapes[id] = def
end

function techniques.get_shape(id)
	return shapes[id]
end

-- Knowledge / equipment ------------------------------------------------------

function techniques.knows(player, id)
	local char = dbil.players.get_character(player)
	return char ~= nil and char.techniques.learned[id] == true
end

--- Checks requirements against character data. Returns ok, reason.
function techniques.meets_requirements(char, def)
	local req = def.requirements
	if char.level < req.level then
		return false, ("Requer nível %d"):format(req.level)
	end
	if req.races and not dbil.util.contains(req.races, char.race) then
		return false, "Raça incompatível"
	end
	for _, other in ipairs(req.techniques or {}) do
		if not char.techniques.learned[other] then
			local odef = reg:get(other)
			return false, "Requer " .. (odef and odef.name or other)
		end
	end
	for _, flag in ipairs(req.flags or {}) do
		if not char.flags[flag] then
			return false, "Requisito de história"
		end
	end
	return true
end

--- Learns a technique. Auto-equips it in a free slot.
function techniques.learn(player, id, opts)
	local char = dbil.players.get_character(player)
	local def = reg:get(id)
	if not char or not def then
		return false, "Técnica desconhecida."
	end
	if char.techniques.learned[id] then
		return false, "Técnica já aprendida."
	end
	if not (opts and opts.force) then
		local ok, reason = techniques.meets_requirements(char, def)
		if not ok then
			return false, reason
		end
	end
	char.techniques.learned[id] = true
	local equipped = char.techniques.equipped
	if #equipped < dbil.input.KIT_SLOTS.technique_count and not dbil.util.contains(equipped, id) then
		equipped[#equipped + 1] = id
	end
	dbil.players.mark_dirty(player)
	dbil.events.emit("technique_learned", player, id)
	dbil.events.emit("techniques_changed", player)
	if not (opts and opts.silent) then
		dbil.events.emit("notify", player, "Nova técnica aprendida: " .. def.name, "success")
	end
	return true
end

function techniques.forget(player, id)
	local char = dbil.players.get_character(player)
	if not char or not char.techniques.learned[id] then
		return false
	end
	char.techniques.learned[id] = nil
	for i = #char.techniques.equipped, 1, -1 do
		if char.techniques.equipped[i] == id then
			table.remove(char.techniques.equipped, i)
		end
	end
	dbil.players.mark_dirty(player)
	dbil.events.emit("techniques_changed", player)
	return true
end

--- Puts a learned technique in a slot (1..4). Swaps if it was elsewhere.
function techniques.equip(player, slot, id)
	local char = dbil.players.get_character(player)
	local max = dbil.input.KIT_SLOTS.technique_count
	if not char or slot < 1 or slot > max or not char.techniques.learned[id] or not reg:get(id) then
		return false
	end
	local equipped = char.techniques.equipped
	local current = {}
	for i = 1, max do
		current[i] = equipped[i]
	end
	for i = 1, max do
		if current[i] == id then
			current[i] = current[slot]
		end
	end
	current[slot] = id
	-- Rebuild as a dense list (the save format stores a list).
	local dense = {}
	for i = 1, max do
		if current[i] then
			dense[#dense + 1] = current[i]
		end
	end
	char.techniques.equipped = dense
	dbil.players.mark_dirty(player)
	dbil.events.emit("techniques_changed", player)
	return true
end

function techniques.get_equipped(player, slot)
	local char = dbil.players.get_character(player)
	local id = char and char.techniques.equipped[slot]
	if id and char.techniques.learned[id] and reg:get(id) then
		return id, reg:get(id)
	end
	return nil
end

--- Learns every auto technique whose requirements are met.
function techniques.check_auto_learn(player, silent)
	local char = dbil.players.get_character(player)
	if not char then
		return
	end
	for id, def in reg:iter() do
		if def.learn.auto and not char.techniques.learned[id]
				and techniques.meets_requirements(char, def) then
			techniques.learn(player, id, { silent = silent })
		end
	end
end

-- Final numbers -------------------------------------------------------------

--- Numbers of a technique for a caster, including mastery bonuses.
-- mastery_level: 0..max. charge_mult: 1..max_charge_mult.
function techniques.compute(def, mastery_level, charge_mult)
	local m = def.mastery
	local lvl = math.min(mastery_level or 0, m.max_level)
	charge_mult = charge_mult or 1
	local floor = tcfg.mastery_floor
	return {
		damage = def.damage * (1 + lvl * m.damage_per_level) * charge_mult,
		cost = def.ki_cost * math.max(floor, 1 - lvl * m.cost_reduction_per_level),
		cooldown = def.cooldown * math.max(floor, 1 - lvl * m.cooldown_reduction_per_level),
		charge_time = def.charge_time * math.max(floor, 1 - lvl * m.charge_reduction_per_level),
		size = def.size * (1 + (charge_mult - 1) * tcfg.charge_size_factor),
		speed = def.speed,
		range = math.min(def.range, tcfg.max_projectile_range),
		knockback = def.knockback * charge_mult,
		lift = def.lift,
		hitstun = def.hitstun,
	}
end

dbil.events.on("character_ready", function(player)
	techniques.check_auto_learn(player, true)
end, 140)

dbil.events.on("level_up", function(player)
	techniques.check_auto_learn(player, false)
end)
