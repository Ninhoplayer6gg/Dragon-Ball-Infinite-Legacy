-- Character appearance: model + texture layers.
--
-- The race provides the base look (mesh, skin, hair). Other systems push
-- named overlays (a transformation changes the hair, an outfit adds a layer)
-- and remove them later; the visual is recomposed from all active layers.
--
--   dbil.appearance.push(player, "transformation", { hair = "x.png", skin_overlay = "y.png" }, 50)
--   layer fields: mesh, skin, skin_overlay (texture), skin_mod ("^[..." modifier), hair
--   dbil.appearance.pop(player, "transformation")

local appearance = {}
dbil.appearance = appearance

appearance.DEFAULT_MESH = "dbil_character.b3d"
appearance.DEFAULT_SKIN = "dbil_skin_human.png"
appearance.BLANK = "dbil_blank.png"

local function layers_of(state)
	if not state.appearance_layers then
		state.appearance_layers = {}
	end
	return state.appearance_layers
end

local function sorted_layers(layers)
	local list = {}
	for source, layer in pairs(layers) do
		list[#list + 1] = { source = source, layer = layer }
	end
	table.sort(list, function(a, b)
		return (a.layer.priority or 0) < (b.layer.priority or 0)
	end)
	return list
end

--- Recomposes and sends the player's visual properties.
function appearance.refresh(player)
	local state = dbil.players.get_state(player)
	if not state then
		return
	end
	local char = state.ready and state.char
	local race = char and dbil.races.get(char.race)
	local base = race and race.appearance or {}
	local mesh = base.mesh or appearance.DEFAULT_MESH
	local skin = base.skin or appearance.DEFAULT_SKIN
	local hair = base.hair or appearance.BLANK

	for _, entry in ipairs(sorted_layers(layers_of(state))) do
		local layer = entry.layer
		if layer.mesh then mesh = layer.mesh end
		if layer.skin then skin = layer.skin end
		if layer.skin_overlay then skin = skin .. "^(" .. layer.skin_overlay .. ")" end
		if layer.skin_mod then skin = skin .. layer.skin_mod end
		if layer.hair then hair = layer.hair end
	end

	player:set_properties({
		visual = "mesh",
		mesh = mesh,
		textures = { skin, hair },
		visual_size = { x = 1, y = 1, z = 1 },
		collisionbox = { -0.3, 0.0, -0.3, 0.3, 1.77, 0.3 },
		selectionbox = { -0.3, 0.0, -0.3, 0.3, 1.77, 0.3 },
		stepheight = 0.6,
		eye_height = 1.6,
		use_texture_alpha = true,
		backface_culling = false,
		nametag = char and char.name or "",
		nametag_color = base.nametag_color or "#ffffff",
	})
end

function appearance.push(player, source, layer, priority)
	local state = dbil.players.get_state(player)
	if not state then
		return
	end
	layer.priority = priority or layer.priority or 0
	layers_of(state)[source] = layer
	appearance.refresh(player)
end

function appearance.pop(player, source)
	local state = dbil.players.get_state(player)
	if not state or not layers_of(state)[source] then
		return
	end
	layers_of(state)[source] = nil
	appearance.refresh(player)
end

dbil.events.on("player_joined", function(player, state)
	state.appearance_layers = {}
	appearance.refresh(player)
end)

dbil.events.on("character_ready", function(player, char, state)
	appearance.refresh(player)
end, 30)

dbil.events.on("character_reset", function(player, state)
	state.appearance_layers = {}
	appearance.refresh(player)
end)
