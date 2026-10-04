local movement = dbil.movement

--- True when the player stands on a walkable node (server-side check).
function movement.on_ground(player)
	local pos = player:get_pos()
	local below = core.get_node_or_nil(vector.new(pos.x, pos.y - 0.1, pos.z))
	if not below then
		return false
	end
	local def = core.registered_nodes[below.name]
	return def ~= nil and def.walkable ~= false
end

--- Whether the player is currently invulnerable (dash i-frames, respawn...).
function movement.is_invulnerable(player)
	local state = dbil.players.get_state(player)
	return state ~= nil and state.invulnerable_until ~= nil
		and dbil.util.now() < state.invulnerable_until
end

function movement.set_invulnerable(player, duration)
	local state = dbil.players.get_state(player)
	if state then
		local expires = dbil.util.now() + duration
		state.invulnerable_until = math.max(state.invulnerable_until or 0, expires)
	end
end
