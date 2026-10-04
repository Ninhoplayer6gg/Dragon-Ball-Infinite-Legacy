-- Enemy spawners. A spawner node keeps a few enemies alive around it while
-- players are nearby (node timers only run in loaded areas, so idle parts of
-- the world cost nothing). Enemies remember their spawner and despawn when
-- abandoned.

local enemies = dbil.enemies
local cfg = dbil.config.enemies

local function count_alive(pos)
	local key = core.pos_to_string(pos)
	local n = 0
	for _, obj in ipairs(core.get_objects_inside_radius(pos, 40)) do
		local ent = obj:get_luaentity()
		if ent and ent._dbil_actor and ent._spawner and not ent._dead
				and core.pos_to_string(ent._spawner) == key then
			n = n + 1
		end
	end
	return n
end

local function players_near(pos, radius)
	for _, player in ipairs(core.get_connected_players()) do
		if vector.distance(player:get_pos(), pos) <= radius then
			return true
		end
	end
	return false
end

local function spawn_spot(pos)
	for _ = 1, 6 do
		local p = vector.add(pos, vector.new(math.random(-3, 3), 1, math.random(-3, 3)))
		local below = core.get_node(vector.offset(p, 0, -1, 0))
		local here = core.get_node(p)
		local above = core.get_node(vector.offset(p, 0, 1, 0))
		local bdef = core.registered_nodes[below.name]
		local hdef = core.registered_nodes[here.name]
		local adef = core.registered_nodes[above.name]
		if bdef and bdef.walkable and hdef and not hdef.walkable and adef and not adef.walkable then
			return p
		end
	end
	return vector.offset(pos, 0, 1, 0)
end

local function on_timer(pos)
	local meta = core.get_meta(pos)
	local enemy = meta:get_string("enemy")
	if enemy == "" then
		enemy = "saibaman"
	end
	if not enemies.get(enemy) then
		return true
	end
	if not players_near(pos, cfg.spawner_player_radius) then
		return true
	end
	local t = os.time()
	if count_alive(pos) < cfg.spawner_max_alive and t >= meta:get_int("next_spawn") then
		enemies.spawn(enemy, spawn_spot(pos), { spawner = pos })
		meta:set_int("next_spawn", t + cfg.spawner_respawn_delay)
	end
	return true
end

core.register_node("dbil_enemies:spawner", {
	description = "Canteiro de Saibaman (gerador de inimigos)",
	tiles = { "dbil_spawner_top.png", "dbil_wasteland_rock.png", "dbil_spawner_side.png" },
	groups = { cracky = 1, dbil_structure = 1 },
	is_ground_content = false,
	on_construct = function(pos)
		core.get_node_timer(pos):start(cfg.spawner_interval)
	end,
	on_timer = on_timer,
})

-- Restart timers of spawners placed by schematics/voxel manipulators.
core.register_lbm({
	label = "Start dbil enemy spawner timers",
	name = "dbil_enemies:spawner_timer",
	nodenames = { "dbil_enemies:spawner" },
	run_at_every_load = true,
	action = function(pos)
		local timer = core.get_node_timer(pos)
		if not timer:is_started() then
			timer:start(cfg.spawner_interval)
		end
	end,
})
