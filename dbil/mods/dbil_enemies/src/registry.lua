-- Enemy registry. An enemy is a data definition plus a "brain" (AI
-- behaviour) name. register() validates the data and creates the entity.
--
--   dbil.enemies.register("saibaman", { name = "Saibaman", power = 380, ... })
--   dbil.enemies.spawn("saibaman", pos)

local S = dbil.schema
local enemies = dbil.enemies

enemies.schema = {
	type = "table",
	fields = {
		name = { type = "string", max_len = 60 },
		description = S.str("", 600),
		power = S.num(100, 1),
		hp = S.num(100, 1, 1e7),
		attack = S.num(8, 0),            -- melee base damage
		melee_mult = S.num(1, 0),
		ki_mult = S.num(1, 0),
		defense = S.num(0, 0, 0.9),
		speed = S.num(4, 0, 50),         -- walk speed (nodes/s)
		jump = S.num(6.5, 0, 50),
		view_range = S.num(18, 0, 100),
		attack_range = S.num(2.2, 0.5, 20),
		attack_cooldown = S.num(1.2, 0.1, 60),
		attack_windup = S.num(0.35, 0, 10),
		knockback = S.num(3, 0, 100),
		hitstun = S.num(0.3, 0, 10),
		leash = S.num(40, 4, 500),
		xp = S.num(10, 0),
		brain = S.str("brawler", 40),
		team = S.str("enemies", 40),
		passive = S.bool(false),
		-- Optional ranged attack using a registered technique.
		ranged = S.opt({
			type = "table",
			fields = {
				technique = { type = "string", max_len = 64 },
				min_range = S.num(5, 0),
				max_range = S.num(20, 0),
				cooldown = S.num(3, 0.1),
				chance = S.num(0.5, 0, 1),
			},
		}),
		-- Optional suicide attack (Saibaman style).
		self_destruct = S.opt({
			type = "table",
			fields = {
				hp_ratio = S.num(0.25, 0, 1),
				chance = S.num(0.3, 0, 1),
				trigger_range = S.num(3, 0),
				windup = S.num(1.2, 0),
				radius = S.num(3.5, 0),
				damage = S.num(35, 0),
				knockback = S.num(10, 0),
				lift = S.num(4, 0),
				hitstun = S.num(0.6, 0),
			},
		}),
		drops = {
			type = "list",
			default = {},
			item = { type = "table", fields = {
				item = { type = "string", max_len = 100 },
				chance = S.num(1, 0, 1),
				min = S.int(1, 1),
				max = S.int(1, 1),
			} },
		},
		visual = {
			type = "table",
			fields = {
				mesh = S.str("dbil_character.b3d", 128),
				textures = { type = "list", item = S.str("", 256) },
				visual_size = S.num(1, 0.1, 20),
				collisionbox = { type = "list", item = S.num(0), default = { -0.3, 0, -0.3, 0.3, 1.7, 0.3 } },
				nametag_color = S.str("#ff8080", 16),
			},
		},
	},
}

local reg = dbil.registry.new("enemy", { schema = enemies.schema })
enemies.registry = reg

local brains = {}

--- Registers an AI brain: { init = fn(self), think = fn(self, dt), step = fn(self, dt, moveresult) }
function enemies.register_brain(name, def)
	brains[name] = def
end

function enemies.get_brain(name)
	return brains[name]
end

function enemies.entity_name(id)
	return "dbil_enemies:" .. id
end

function enemies.register(id, def)
	def = reg:register(id, def)
	enemies.register_entity(id, def)
	return def
end

function enemies.get(id)
	return reg:get(id)
end

function enemies.iter()
	return reg:iter()
end

--- Spawns an enemy. extra: { spawner = pos, power_mult = n }
function enemies.spawn(id, pos, extra)
	if not reg:get(id) then
		return nil
	end
	local data = core.serialize({ spawner = extra and extra.spawner, power_mult = extra and extra.power_mult })
	return core.add_entity(pos, enemies.entity_name(id), data)
end
