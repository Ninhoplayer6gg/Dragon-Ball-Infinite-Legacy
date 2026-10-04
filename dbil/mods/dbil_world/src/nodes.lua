-- Terrain and structure nodes. Terrain cannot be dug by players for now
-- (the RPG does not use building); groups are kept for future systems
-- such as destructible terrain from big Ki attacks.

local function terrain(name, def)
	def.is_ground_content = true
	def.groups = def.groups or {}
	def.groups.dbil_terrain = 1
	core.register_node("dbil_world:" .. name, def)
end

terrain("stone", {
	description = "Rocha",
	tiles = { "dbil_stone.png" },
	groups = { cracky = 3, stone = 1 },
})

terrain("dirt", {
	description = "Terra",
	tiles = { "dbil_dirt.png" },
	groups = { crumbly = 3, soil = 1 },
})

terrain("grass", {
	description = "Terra com Grama",
	tiles = { "dbil_grass_top.png", "dbil_dirt.png", "dbil_grass_side.png" },
	groups = { crumbly = 3, soil = 1 },
})

terrain("sand", {
	description = "Areia",
	tiles = { "dbil_sand.png" },
	groups = { crumbly = 3, sand = 1 },
})

terrain("gravel", {
	description = "Cascalho",
	tiles = { "dbil_gravel.png" },
	groups = { crumbly = 2 },
})

terrain("wasteland_rock", {
	description = "Rocha do Deserto Rochoso",
	tiles = { "dbil_wasteland_rock.png" },
	groups = { cracky = 3, stone = 1 },
})

terrain("wasteland_soil", {
	description = "Solo Árido",
	tiles = { "dbil_wasteland_soil.png", "dbil_wasteland_rock.png", "dbil_wasteland_soil_side.png" },
	groups = { crumbly = 3 },
})

core.register_node("dbil_world:tree_trunk", {
	description = "Tronco",
	tiles = { "dbil_tree_top.png", "dbil_tree_top.png", "dbil_tree_trunk.png" },
	groups = { choppy = 2, tree = 1 },
	paramtype2 = "facedir",
	is_ground_content = false,
})

core.register_node("dbil_world:leaves", {
	description = "Folhas",
	drawtype = "allfaces_optional",
	tiles = { "dbil_leaves.png" },
	paramtype = "light",
	groups = { snappy = 3, leaves = 1 },
	is_ground_content = false,
})

core.register_node("dbil_world:grass_tuft", {
	description = "Capim",
	drawtype = "plantlike",
	tiles = { "dbil_grass_tuft.png" },
	inventory_image = "dbil_grass_tuft.png",
	paramtype = "light",
	sunlight_propagates = true,
	walkable = false,
	buildable_to = true,
	floodable = true,
	selection_box = { type = "fixed", fixed = { -0.4, -0.5, -0.4, 0.4, 0.1, 0.4 } },
	groups = { snappy = 3, attached_node = 1, flora = 1 },
	is_ground_content = false,
})

-- Liquids ------------------------------------------------------------------

local function liquid(name, desc, texture, alpha, range, renewable)
	local source = "dbil_world:" .. name .. "_source"
	local flowing = "dbil_world:" .. name .. "_flowing"
	local common = {
		paramtype = "light",
		walkable = false,
		pointable = false,
		diggable = false,
		buildable_to = true,
		is_ground_content = false,
		drop = "",
		drowning = 1,
		liquid_alternative_source = source,
		liquid_alternative_flowing = flowing,
		liquid_viscosity = 1,
		liquid_range = range,
		liquid_renewable = renewable,
		post_effect_color = { a = 110, r = 30, g = 80, b = 140 },
		use_texture_alpha = "blend",
		groups = { water = 3, liquid = 3 },
	}
	local src = table.copy(common)
	src.description = desc
	src.drawtype = "liquid"
	src.liquidtype = "source"
	src.tiles = { { name = texture, backface_culling = false } }
	src.special_tiles = { { name = texture, backface_culling = true } }
	core.register_node(source, src)

	local flow = table.copy(common)
	flow.description = desc .. " (corrente)"
	flow.drawtype = "flowingliquid"
	flow.liquidtype = "flowing"
	flow.paramtype2 = "flowingliquid"
	flow.tiles = { texture }
	flow.special_tiles = {
		{ name = texture, backface_culling = false },
		{ name = texture, backface_culling = true },
	}
	flow.groups = { water = 3, liquid = 3, not_in_creative_inventory = 1 }
	core.register_node(flowing, flow)
end

liquid("water", "Água", "dbil_water.png", 160, 8, true)
liquid("river_water", "Água de Rio", "dbil_river_water.png", 160, 2, false)

-- Arena ----------------------------------------------------------------------

local function structure(name, def)
	def.is_ground_content = false
	def.groups = def.groups or { cracky = 1, dbil_structure = 1 }
	core.register_node("dbil_world:" .. name, def)
end

structure("arena_tile", {
	description = "Piso da Arena",
	tiles = { "dbil_arena_tile.png" },
})

structure("arena_trim", {
	description = "Borda da Arena",
	tiles = { "dbil_arena_trim.png" },
})

structure("arena_foundation", {
	description = "Fundação da Arena",
	tiles = { "dbil_stone.png^[colorize:#40404060" },
})
