-- Test region: a circular training arena (tournament style) built at the
-- world center the first time the world runs, with Saibaman spawners around
-- it and training dummies on the stage. Works with any terrain: hills are
-- cut, gaps and water are filled with a foundation.
--
-- Stored in mod storage ("world:arena"): { built = true, spawn = pos, center = pos }

local world = dbil.world
local cfg = dbil.config.world

local KEY = "world:arena"
local ids = {}

local function cid(name)
	if not ids[name] then
		ids[name] = core.get_content_id(name)
	end
	return ids[name]
end

local function arena_data()
	return dbil.storage.load_table(KEY) or {}
end

function world.get_spawn()
	local data = arena_data()
	return data.spawn and vector.new(data.spawn.x, data.spawn.y, data.spawn.z) or nil
end

function world.arena_info()
	return arena_data()
end

local function is_solid(name)
	local def = core.registered_nodes[name]
	return def ~= nil and def.walkable ~= false and def.liquidtype == "none"
		and def.drawtype ~= "plantlike"
end

local function is_liquid(name)
	local def = core.registered_nodes[name]
	return def ~= nil and def.liquidtype ~= "none"
end

--- Surface height at (x, z) scanning down from top. Returns y, is_liquid.
function world.surface_level(x, z, top, bottom)
	for y = top, bottom, -1 do
		local node = core.get_node_or_nil(vector.new(x, y, z))
		if node and node.name ~= "ignore" then
			if is_liquid(node.name) then
				return y, true
			elseif is_solid(node.name) then
				return y, false
			end
		end
	end
	return nil
end

local function build_platform(center, floor_y)
	local r = cfg.arena_radius
	local clear_h = cfg.arena_clear_height
	local pmin = vector.new(center.x - r - 2, floor_y - 40, center.z - r - 2)
	local pmax = vector.new(center.x + r + 2, floor_y + clear_h, center.z + r + 2)
	local vm = core.get_voxel_manip()
	local emin, emax = vm:read_from_map(pmin, pmax)
	local area = VoxelArea(emin, emax)
	local data = vm:get_data()
	local c_air = cid("air")
	local c_tile = cid("dbil_world:arena_tile")
	local c_trim = cid("dbil_world:arena_trim")
	local c_found = cid("dbil_world:arena_foundation")

	for z = center.z - r - 2, center.z + r + 2 do
		for x = center.x - r - 2, center.x + r + 2 do
			local dx, dz = x - center.x, z - center.z
			local d = math.sqrt(dx * dx + dz * dz)
			if d <= r + 0.5 then
				data[area:index(x, floor_y, z)] = d > r - 1.0 and c_trim or c_tile
				-- Foundation down to solid ground.
				for y = floor_y - 1, floor_y - 40, -1 do
					local i = area:index(x, y, z)
					local name = core.get_name_from_content_id(data[i])
					if is_solid(name) and name ~= "dbil_world:arena_foundation" then
						break
					end
					data[i] = c_found
				end
			end
			if d <= r + 2 then
				for y = floor_y + 1, floor_y + clear_h do
					data[area:index(x, y, z)] = c_air
				end
			end
		end
	end

	-- Four corner pillars mark the stage.
	for i = 0, 3 do
		local angle = math.pi / 4 + i * math.pi / 2
		local px = center.x + math.floor(math.cos(angle) * (r - 1) + 0.5)
		local pz = center.z + math.floor(math.sin(angle) * (r - 1) + 0.5)
		for y = floor_y + 1, floor_y + 3 do
			data[area:index(px, y, pz)] = c_trim
		end
	end

	vm:set_data(data)
	vm:write_to_map(true)
end

local function place_spawners(center, floor_y)
	if not core.registered_nodes["dbil_enemies:spawner"] then
		return
	end
	local n = cfg.spawner_count
	for i = 1, n do
		local angle = (i - 0.5) / n * math.pi * 2
		local x = center.x + math.floor(math.cos(angle) * cfg.spawner_distance + 0.5)
		local z = center.z + math.floor(math.sin(angle) * cfg.spawner_distance + 0.5)
		local y, liquid = world.surface_level(x, z, floor_y + 40, floor_y - 40)
		if not y or liquid then
			-- No dry ground there (sea, cliff...): use the arena's own edge.
			x = center.x + math.floor(math.cos(angle) * (cfg.arena_radius - 3) + 0.5)
			z = center.z + math.floor(math.sin(angle) * (cfg.arena_radius - 3) + 0.5)
			y = floor_y
			dbil.log.info("spawner %d placed on the arena edge (no dry ground outside)", i)
		end
		core.set_node(vector.new(x, y, z), { name = "dbil_enemies:spawner" })
		-- Clear a little room above the spawner.
		for h = 1, 3 do
			local p = vector.new(x, y + h, z)
			if core.get_node(p).name ~= "air" then
				core.set_node(p, { name = "air" })
			end
		end
	end
end

--- Finds a dry, low site for the arena, searching outward in square rings.
-- Uses the mapgen's spawn level estimate, so nothing has to be generated.
local function find_site()
	local cx, cz = cfg.arena_center_x, cfg.arena_center_z
	local fallback
	local function land(x, z)
		return core.get_spawn_level(x, z) ~= nil
	end
	local function good(x, z)
		if not land(x, z) then
			return false
		end
		fallback = fallback or { x = x, z = z }
		local dry = 0
		for i = 1, cfg.spawner_count do
			local angle = (i - 0.5) / cfg.spawner_count * math.pi * 2
			if land(x + math.floor(math.cos(angle) * cfg.spawner_distance),
					z + math.floor(math.sin(angle) * cfg.spawner_distance)) then
				dry = dry + 1
			end
		end
		return dry >= cfg.spawner_count - 1
	end
	local step = cfg.site_search_step
	if good(cx, cz) then
		return cx, cz
	end
	for r = step, cfg.site_search_radius, step do
		for i = -r, r, step do
			for _, p in ipairs({ { cx + i, cz - r }, { cx + i, cz + r }, { cx - r, cz + i }, { cx + r, cz + i } }) do
				if good(p[1], p[2]) then
					return p[1], p[2]
				end
			end
		end
	end
	if fallback then
		return fallback.x, fallback.z
	end
	return cx, cz
end

local function place_dummies(center, floor_y)
	if not (dbil.enemies and dbil.enemies.get("training_dummy")) then
		return
	end
	local n = cfg.training_dummies
	for i = 1, n do
		local angle = math.pi + (i - (n + 1) / 2) * 0.5
		local x = center.x + math.cos(angle) * (cfg.arena_radius - 4)
		local z = center.z + math.sin(angle) * (cfg.arena_radius - 4)
		dbil.enemies.spawn("training_dummy", vector.new(x, floor_y + 1, z))
	end
end

local building = false
local waiting = {}

local function finish(spawn)
	building = false
	for _, fn in ipairs(waiting) do
		fn(spawn)
	end
	waiting = {}
end

--- Builds the arena (once per world). callback(spawn_pos) runs when ready.
function world.ensure_arena(callback)
	local data = arena_data()
	if data.built then
		if callback then
			callback(world.get_spawn())
		end
		return
	end
	if callback then
		waiting[#waiting + 1] = callback
	end
	if building then
		return
	end
	building = true
	local sx, sz = find_site()
	local center = vector.new(sx, 0, sz)
	local reach = cfg.spawner_distance + 8
	local pmin = vector.new(center.x - reach, -48, center.z - reach)
	local pmax = vector.new(center.x + reach, 96, center.z + reach)
	dbil.log.info("generating the training arena at %d,%d...", center.x, center.z)
	core.emerge_area(pmin, pmax, function(_, _, remaining)
		if remaining > 0 then
			return
		end
		local water = tonumber(core.settings:get("water_level")) or 1
		local gy = world.surface_level(center.x, center.z, 90, -40) or water
		local floor_y = math.max(gy + 1, water + 2)
		build_platform(center, floor_y)
		place_spawners(center, floor_y)
		place_dummies(center, floor_y)
		local spawn = vector.new(center.x, floor_y + 1, center.z)
		dbil.storage.save_table(KEY, {
			built = true,
			spawn = spawn,
			center = vector.new(center.x, floor_y, center.z),
		})
		dbil.log.info("training arena ready, spawn at %s", core.pos_to_string(spawn))
		finish(spawn)
	end)
end

core.register_on_mods_loaded(function()
	core.after(0.5, function()
		world.ensure_arena()
	end)
end)

-- New players start on the arena.
core.register_on_newplayer(function(player)
	local name = player:get_player_name()
	world.ensure_arena(function(spawn)
		local p = core.get_player_by_name(name)
		if p and spawn then
			p:set_pos(spawn)
		end
	end)
end)
