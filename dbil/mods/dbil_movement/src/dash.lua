-- Dash: a quick burst in the movement direction that costs Stamina and
-- grants a short invulnerability window (dodge). Works on the ground and in
-- flight (air dash). After the burst a brief "brake" restores normal speed.

local movement = dbil.movement
local cfg = dbil.config.movement
local now = dbil.util.now

dbil.input.register_action("dash", {
	handler = function(player, state)
		local t = now()
		state.dash = state.dash or {}
		if t < (state.dash.ready_at or 0) then
			return false
		end
		local dir = dbil.input.move_direction(player, state.ctrl or {})
		if not dir then
			return false
		end
		if not dbil.resources.spend(player, "stamina", cfg.dash_stamina, "dash") then
			return false
		end
		state.dash.ready_at = t + cfg.dash_cooldown
		local flying = state.flight and state.flight.active
		local speed = flying and cfg.dash_air_speed or cfg.dash_ground_speed
		local impulse = vector.multiply(dir, speed)
		if not flying then
			impulse.y = cfg.dash_lift
		end
		player:add_velocity(impulse)
		movement.set_invulnerable(player, cfg.dash_invulnerable)
		dbil.fx.burst("dash", player:get_pos())
		dbil.fx.sound("dash", player)
		dbil.events.emit("dash", player)
		dbil.events.emit("training", player, "dash", 1)

		-- Brake: high acceleration for a moment so the burst ends crisply
		-- instead of sliding (movement acceleration on the ground is low).
		local name = player:get_player_name()
		core.after(cfg.dash_brake_delay, function()
			local p = core.get_player_by_name(name)
			if not p then
				return
			end
			dbil.physics.set(p, "dash_brake", {
				acceleration_default = cfg.dash_brake_ground_accel,
				acceleration_air = cfg.dash_brake_air_accel,
			})
			core.after(cfg.dash_brake_duration, function()
				local p2 = core.get_player_by_name(name)
				if p2 then
					dbil.physics.clear(p2, "dash_brake")
				end
			end)
		end)
		return true
	end,
})
