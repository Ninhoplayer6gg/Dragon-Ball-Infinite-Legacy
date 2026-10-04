-- Sprint: holding Aux1 while moving on the ground runs faster and drains
-- Stamina. When Stamina runs out the key must be released to sprint again.

local cfg = dbil.config.movement

dbil.players.register_tick("sprint", 0.1, function(player, state, dt)
	local intent = state.intent
	if not intent then
		return
	end
	local wants = intent.sprint and not (state.charge and state.charge.active)
	if not wants then
		state.sprint_exhausted = false
	end
	if wants and not state.sprint_exhausted and dbil.input.can_act(player) then
		local cost = cfg.sprint_stamina_per_second * dt
		if dbil.resources.drain(player, "stamina", cost, "sprint") < cost then
			state.sprint_exhausted = true
		end
	else
		wants = false
	end
	if wants and not state.sprint_exhausted then
		if not state.sprinting then
			state.sprinting = true
			dbil.physics.set(player, "sprint", { speed = cfg.sprint_speed })
		end
	elseif state.sprinting then
		state.sprinting = false
		dbil.physics.clear(player, "sprint")
	end
end, 45)
