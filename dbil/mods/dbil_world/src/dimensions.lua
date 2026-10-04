-- Dimensions and respawn rules.
--
-- A dimension is a vertical slice of the map (the usual way to host several
-- worlds in Luanti). Today only Earth exists; Other World, Namek, Beerus's
-- planet... will be registered the same way, each with its own respawn rule.
--
-- Respawn resolvers decide where a player returns after dying. The first
-- resolver that returns a position wins (e.g. a future "Other World" resolver
-- can send dead fighters to King Yemma's checkpoint).

local world = dbil.world

local dimensions = {}
local resolvers = {}

--- def: { name, y_min, y_max, respawn = function(player) -> pos|nil }
function world.register_dimension(id, def)
	assert(def.y_min and def.y_max and def.y_min < def.y_max, "dimension needs y_min < y_max")
	def.id = id
	dimensions[#dimensions + 1] = def
end

function world.get_dimension(pos)
	for _, def in ipairs(dimensions) do
		if pos.y >= def.y_min and pos.y <= def.y_max then
			return def
		end
	end
	return nil
end

function world.register_respawn_resolver(fn, priority)
	resolvers[#resolvers + 1] = { fn = fn, priority = priority or 100 }
	table.sort(resolvers, function(a, b)
		return a.priority < b.priority
	end)
end

function world.resolve_respawn(player)
	for _, r in ipairs(resolvers) do
		local pos = r.fn(player)
		if pos then
			return pos
		end
	end
	return nil
end

world.register_dimension("earth", {
	name = "Terra",
	y_min = -31000,
	y_max = 20000,
	respawn = function()
		return world.get_spawn()
	end,
})

-- A server-wide static spawnpoint always wins.
world.register_respawn_resolver(function()
	local static = core.setting_get_pos("static_spawnpoint")
	return static
end, 0)

-- Default: the respawn point of the dimension where the player died.
world.register_respawn_resolver(function(player)
	local state = dbil.players and dbil.players.get_state(player)
	local died_at = state and state.death_pos or player:get_pos()
	local dim = world.get_dimension(died_at)
	return dim and dim.respawn and dim.respawn(player)
end, 100)

core.register_on_dieplayer(function(player)
	local state = dbil.players and dbil.players.get_state(player)
	if state then
		state.death_pos = player:get_pos()
	end
end)

core.register_on_respawnplayer(function(player)
	local pos = world.resolve_respawn(player)
	if pos then
		player:set_pos(pos)
		return true
	end
	return false
end)
