-- Layered physics overrides.
--
-- Several systems change player physics at the same time (flight removes
-- gravity, charging slows down, sprint speeds up, transformations buff
-- speed...). Each one owns a named layer; the final override is the product
-- of all layers and is only sent to the client when it actually changes.
--
--   dbil.physics.set(player, "charge", { speed = 0.3, jump = 0 })
--   dbil.physics.clear(player, "charge")

local physics = {}
dbil.physics = physics

local FIELDS = {
	"speed", "speed_walk", "speed_crouch", "speed_fast", "speed_climb",
	"jump", "gravity", "acceleration_default", "acceleration_air",
	"acceleration_fast", "liquid_fluidity", "liquid_sink",
}

local function get_layers(state)
	local layers = state.physics_layers
	if not layers then
		layers = {}
		state.physics_layers = layers
	end
	return layers
end

local function combine(layers)
	local out = {}
	for _, field in ipairs(FIELDS) do
		out[field] = 1
	end
	out.sneak = true
	for _, layer in pairs(layers) do
		for k, v in pairs(layer) do
			if k == "sneak" then
				out.sneak = out.sneak and v
			elseif out[k] then
				out[k] = out[k] * v
			end
		end
	end
	return out
end

local function apply(player, state)
	local combined = combine(get_layers(state))
	local last = state.physics_applied
	if last then
		local same = last.sneak == combined.sneak
		if same then
			for _, field in ipairs(FIELDS) do
				if math.abs(last[field] - combined[field]) > 1e-4 then
					same = false
					break
				end
			end
		end
		if same then
			return
		end
	end
	state.physics_applied = combined
	player:set_physics_override(combined)
end

function physics.set(player, layer, values)
	local state = dbil.players.get_state(player)
	if not state then
		return
	end
	get_layers(state)[layer] = values
	apply(player, state)
end

function physics.clear(player, layer)
	local state = dbil.players.get_state(player)
	if not state or not state.physics_layers or not state.physics_layers[layer] then
		return
	end
	state.physics_layers[layer] = nil
	apply(player, state)
end

function physics.has(player, layer)
	local state = dbil.players.get_state(player)
	return state ~= nil and state.physics_layers ~= nil and state.physics_layers[layer] ~= nil
end

--- Removes every layer (used on death/reset).
function physics.reset(player)
	local state = dbil.players.get_state(player)
	if not state then
		return
	end
	state.physics_layers = {}
	apply(player, state)
end

dbil.events.on("player_joined", function(player, state)
	state.physics_layers = {}
	state.physics_applied = nil
	apply(player, state)
end)
