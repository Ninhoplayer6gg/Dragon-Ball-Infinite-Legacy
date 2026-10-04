-- Race registry. Races are pure data plus optional event hooks, so adding a
-- new race (Namekian, Majin, Frieza race, Android...) means adding one file in
-- the dbil_races mod — no changes to the systems that use races.

local S = dbil.schema
local races = {}
dbil.races = races

local function attribute_table(required)
	local fields = {}
	for _, attr in ipairs(dbil.ATTRIBUTES) do
		fields[attr] = required and { type = "number", min = 0 } or S.num(0, 0)
	end
	return { type = "table", fields = fields }
end

races.schema = {
	type = "table",
	fields = {
		name = { type = "string", max_len = 40 },
		description = S.str("", 1000),
		playable = S.bool(true),
		-- Attributes of a new level 1 character.
		attributes = attribute_table(true),
		-- Attribute points gained per level.
		growth = attribute_table(true),
		-- Multipliers applied as a "race" stat modifier.
		traits = {
			type = "table",
			fields = {
				power_mult = S.num(1, 0.1, 10),
				ki_cost_mult = S.num(1, 0.1, 10),
				max_hp_mult = S.num(1, 0.1, 10),
				max_ki_mult = S.num(1, 0.1, 10),
				max_stamina_mult = S.num(1, 0.1, 10),
				hp_regen_mult = S.num(1, 0, 10),
				ki_regen_mult = S.num(1, 0, 10),
				xp_mult = S.num(1, 0.1, 10),
				training_mult = S.num(1, 0.1, 10),
				mastery_mult = S.num(1, 0.1, 10),
			},
		},
		appearance = {
			type = "table",
			fields = {
				mesh = S.str("dbil_character.b3d", 128),
				skin = { type = "string", max_len = 256 },
				hair = S.str("dbil_blank.png", 256),
				nametag_color = S.str("#ffffff", 16),
			},
		},
		-- Player-facing list of racial features (shown on creation screen).
		features = { type = "list", item = { type = "string", max_len = 200 }, default = {} },
		tags = { type = "list", item = { type = "string", max_len = 40 }, default = {} },
	},
}

local reg = dbil.registry.new("race", { schema = races.schema })
races.registry = reg

function races.register(id, def)
	return reg:register(id, def)
end

function races.get(id)
	return reg:get(id)
end

function races.exists(id)
	return reg:exists(id)
end

--- Playable races in registration order: list of {id=, def=}.
function races.playable()
	local out = {}
	for id, def in reg:iter() do
		if def.playable then
			out[#out + 1] = { id = id, def = def }
		end
	end
	return out
end

--- Subscribes to a dbil event only for players of the given race.
-- The event's first argument must be a player ObjectRef or an info table
-- with a `player` field.
function races.on(race_id, event, fn)
	dbil.events.on(event, function(first, ...)
		local player = first
		if type(first) == "table" then
			player = first.player
		end
		if not player or not dbil.players then
			return
		end
		local char = dbil.players.get_character(player)
		if char and char.race == race_id then
			return fn(first, ...)
		end
	end)
end
