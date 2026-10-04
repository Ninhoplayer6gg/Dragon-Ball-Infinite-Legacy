-- Mapgen setup: aliases for the engine mapgens, biomes and decorations.

core.register_alias("mapgen_stone", "dbil_world:stone")
core.register_alias("mapgen_water_source", "dbil_world:water_source")
core.register_alias("mapgen_river_water_source", "dbil_world:river_water_source")
core.register_alias("mapgen_singlenode", "air")

core.clear_registered_biomes()
core.clear_registered_decorations()

-- Grassy plains: most common, good for exploring and flying.
core.register_biome({
	name = "dbil:plains",
	node_top = "dbil_world:grass", depth_top = 1,
	node_filler = "dbil_world:dirt", depth_filler = 3,
	node_riverbed = "dbil_world:gravel", depth_riverbed = 2,
	y_max = 31000, y_min = 4,
	heat_point = 45, humidity_point = 55,
})

-- Rocky wasteland with red stone and tall rock spires.
core.register_biome({
	name = "dbil:wasteland",
	node_top = "dbil_world:wasteland_soil", depth_top = 1,
	node_filler = "dbil_world:wasteland_rock", depth_filler = 6,
	node_stone = "dbil_world:wasteland_rock",
	node_riverbed = "dbil_world:sand", depth_riverbed = 2,
	y_max = 31000, y_min = 4,
	heat_point = 80, humidity_point = 30,
})

core.register_biome({
	name = "dbil:desert",
	node_top = "dbil_world:sand", depth_top = 1,
	node_filler = "dbil_world:sand", depth_filler = 4,
	node_riverbed = "dbil_world:sand", depth_riverbed = 2,
	y_max = 31000, y_min = 4,
	heat_point = 95, humidity_point = 8,
})

-- Beaches and sea floor everywhere below y = 4.
core.register_biome({
	name = "dbil:shore",
	node_top = "dbil_world:sand", depth_top = 1,
	node_filler = "dbil_world:sand", depth_filler = 3,
	node_riverbed = "dbil_world:sand", depth_riverbed = 2,
	y_max = 3, y_min = -255,
	heat_point = 50, humidity_point = 50,
})

core.register_biome({
	name = "dbil:underground",
	y_max = -256, y_min = -31000,
	heat_point = 50, humidity_point = 50,
})

core.register_decoration({
	name = "dbil:grass_tufts",
	deco_type = "simple",
	place_on = { "dbil_world:grass" },
	sidelen = 16,
	fill_ratio = 0.09,
	biomes = { "dbil:plains" },
	y_max = 200, y_min = 4,
	decoration = "dbil_world:grass_tuft",
})

core.register_decoration({
	name = "dbil:rock_spires",
	deco_type = "simple",
	place_on = { "dbil_world:wasteland_soil" },
	sidelen = 16,
	noise_params = { offset = -0.004, scale = 0.012, spread = { x = 60, y = 60, z = 60 }, seed = 4242, octaves = 2, persist = 0.6 },
	biomes = { "dbil:wasteland" },
	y_max = 200, y_min = 4,
	decoration = "dbil_world:wasteland_rock",
	height = 4,
	height_max = 16,
})

-- Simple broad-leaf tree as an in-code schematic.
local T, L, A = { name = "dbil_world:tree_trunk" }, { name = "dbil_world:leaves", prob = 230 }, { name = "air", prob = 0 }
local size = { x = 5, y = 7, z = 5 }
local data = {}
for z = 0, 4 do
	for y = 0, 6 do
		for x = 0, 4 do
			local node = A
			local center = x == 2 and z == 2
			if center and y <= 4 then
				node = T
			elseif y >= 3 and y <= 5 then
				local edge = (x == 0 or x == 4) and (z == 0 or z == 4)
				if not edge and not (y == 5 and (x == 0 or x == 4 or z == 0 or z == 4)) then
					node = L
				end
			elseif y == 6 and x >= 1 and x <= 3 and z >= 1 and z <= 3 then
				node = L
			end
			data[#data + 1] = node
		end
	end
end

core.register_decoration({
	name = "dbil:trees",
	deco_type = "schematic",
	place_on = { "dbil_world:grass" },
	sidelen = 16,
	noise_params = { offset = 0.0005, scale = 0.006, spread = { x = 120, y = 120, z = 120 }, seed = 777, octaves = 3, persist = 0.6 },
	biomes = { "dbil:plains" },
	y_max = 200, y_min = 4,
	schematic = { size = size, data = data },
	flags = "place_center_x, place_center_z",
	rotation = "random",
})
