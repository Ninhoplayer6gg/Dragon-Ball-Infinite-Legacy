-- Character data model, save format version and migrations.
--
-- Saved structure ("account", one per player name):
--   {
--     format = <save format version>,
--     active = <active character slot>,
--     characters = { [slot] = <character> },
--     settings = { personal UI/gameplay preferences },
--   }
-- Multiple slots are supported by the format; the UI uses slot 1 for now.

local S = dbil.schema
local model = {}
dbil.model = model

--- Bump when the saved structure changes and add a migration below.
model.FORMAT = 1

local function attributes_schema()
	local fields = {}
	for _, attr in ipairs(dbil.ATTRIBUTES) do
		fields[attr] = S.num(10, dbil.config.stats.attribute_min, dbil.config.stats.attribute_max)
	end
	return { type = "table", fields = fields }
end

local function number_map()
	return { type = "map", key = "string", value = S.num(0) }
end

model.character_schema = {
	type = "table",
	fields = {
		id = S.str("", 64),
		name = S.str("Guerreiro", 40),
		race = S.str("human", 40),
		origin = S.str("earth", 40),
		style = S.str("balanced", 40),
		created_at = S.int(0, 0),
		level = S.int(1, 1, 1000),
		xp = S.num(0, 0),
		attributes = attributes_schema(),
		training = {
			type = "table",
			fields = {
				points = number_map(),   -- progress toward the next training gain
				gained = number_map(),   -- attribute points obtained by training
			},
		},
		-- -1 means "full" (used for new characters).
		resources = {
			type = "table",
			fields = {
				hp = S.num(-1),
				ki = S.num(-1),
				stamina = S.num(-1),
			},
		},
		techniques = {
			type = "table",
			fields = {
				learned = { type = "map", key = "string", value = S.bool(true) },
				equipped = { type = "list", item = S.str("", 64), max_items = 4 },
			},
		},
		transformations = {
			type = "table",
			fields = {
				unlocked = { type = "map", key = "string", value = S.bool(true) },
			},
		},
		mastery = {
			type = "map",
			key = "string",
			value = {
				type = "table",
				fields = { level = S.int(0, 0, 1000), xp = S.num(0, 0) },
			},
		},
		-- Story / unlock flags. Values may be booleans, numbers or strings.
		flags = { type = "map", key = "string", value = { type = "any" } },
		quests = {
			type = "table",
			fields = {
				active = { type = "map", key = "string", value = { type = "table", fields = {
					progress = { type = "map", key = "number", value = S.num(0, 0) },
					started_at = S.int(0, 0),
				} } },
				completed = { type = "map", key = "string", value = S.int(0, 0) },
			},
		},
		-- Lifetime statistics (kills, deaths, damage...).
		stats = number_map(),
	},
}

model.account_schema = {
	type = "table",
	fields = {
		format = S.int(model.FORMAT, 1),
		active = S.int(1, 1, 16),
		characters = { type = "map", key = "number", value = model.character_schema },
		settings = {
			type = "table",
			fields = {
				aim_assist = S.bool(true),
				show_tips = S.bool(true),
				hud_compact = S.bool(false),
			},
		},
	},
}

-- Migrations: migrations[n] converts an account from format n to n + 1.
-- Example for the future:
--   model.migrations[1] = function(acc) acc.something_new = {} ; return acc end
model.migrations = {}

--- Upgrades raw data to the current format. Returns account or nil, error.
function model.migrate(acc)
	local from = tonumber(acc.format) or 1
	if from > model.FORMAT then
		return nil, ("save format %d is newer than supported %d"):format(from, model.FORMAT)
	end
	while from < model.FORMAT do
		local step = model.migrations[from]
		if not step then
			return nil, ("no migration from save format %d"):format(from)
		end
		acc = step(acc) or acc
		from = from + 1
		acc.format = from
		dbil.log.info("migrated save data to format %d", from)
	end
	return acc
end

function model.new_account()
	local acc = S.sanitize({}, model.account_schema)
	acc.format = model.FORMAT
	return acc
end

local id_counter = 0

--- Builds a brand-new level 1 character for a race.
function model.new_character(owner, name, race_id)
	local race = dbil.races.get(race_id)
	assert(race, "unknown race " .. tostring(race_id))
	id_counter = id_counter + 1
	local char = S.sanitize({}, model.character_schema)
	char.id = ("%s-%d-%d"):format(owner, os.time(), id_counter)
	char.name = name
	char.race = race_id
	char.created_at = os.time()
	for _, attr in ipairs(dbil.ATTRIBUTES) do
		char.attributes[attr] = race.attributes[attr]
	end
	return char
end

--- Repairs an account loaded from storage. Returns account, issues.
function model.sanitize_account(raw)
	local acc, issues = S.sanitize(raw, model.account_schema)
	for slot, char in pairs(acc.characters) do
		if not dbil.races.exists(char.race) then
			issues[#issues + 1] = ("characters[%d]: unknown race '%s'"):format(slot, char.race)
			-- Remember the original race so data can be recovered, then fall
			-- back to a playable race to keep the character usable.
			char.flags.missing_race = char.race
			local fallback = dbil.races.playable()[1]
			char.race = fallback and fallback.id or char.race
		end
	end
	return acc, issues
end

function model.active_character(acc)
	return acc and acc.characters[acc.active]
end
