-- Visual and audio effects.
--
-- Gameplay code asks for effects by *meaning* ("hit_heavy", "explosion"),
-- never by file name. The theme (config/theme.lua) maps meanings to textures,
-- colors and sounds, so art can be replaced without touching gameplay code.

local fx = {}
dbil.fx = fx

local theme = dbil.config.theme

--- Returns a texture string for a theme entry, optionally tinted.
function fx.texture(name, color)
	local tex = theme.textures[name] or name
	if color then
		tex = tex .. "^[multiply:" .. color
	end
	return tex
end

--- Plays a themed sound. `target` is an ObjectRef or a position.
-- Missing sounds are ignored silently (sound packs are optional).
function fx.sound(name, target, opts)
	local spec = theme.sounds[name]
	if not spec then
		return
	end
	local params = {
		gain = (opts and opts.gain) or spec.gain or 1.0,
		pitch = (opts and opts.pitch) or spec.pitch or (0.92 + math.random() * 0.16),
		max_hear_distance = spec.distance or 32,
	}
	if type(target) == "userdata" then
		params.object = target
	elseif target then
		params.pos = target
	end
	if opts and opts.to_player then
		params.to_player = opts.to_player
	end
	return core.sound_play(spec.name, params, not (opts and opts.loop))
end

--- One-shot particle burst at pos.
-- kind: theme particle preset name; overrides tweak the preset.
function fx.burst(kind, pos, overrides)
	local p = theme.particles[kind]
	if not p then
		return
	end
	local color = (overrides and overrides.color) or p.color
	local size = (overrides and overrides.size) or p.size or 2
	local spread = (overrides and overrides.spread) or p.spread or 0.5
	local speed = (overrides and overrides.speed) or p.speed or 3
	core.add_particlespawner({
		amount = (overrides and overrides.amount) or p.amount or 12,
		time = 0.05,
		pos = {
			min = vector.subtract(pos, spread),
			max = vector.add(pos, spread),
		},
		vel = {
			min = vector.new(-speed, -speed * 0.5, -speed),
			max = vector.new(speed, speed, speed),
		},
		drag = vector.new(2, 2, 2),
		acc = vector.new(0, p.gravity or 0, 0),
		exptime = { min = p.life_min or 0.25, max = p.life_max or 0.6 },
		size = { min = size * 0.6, max = size * 1.2 },
		texture = {
			name = fx.texture(p.texture, color),
			alpha_tween = { 1, 0 },
			scale_tween = { 1, p.end_scale or 0.3 },
			blend = p.blend or "add",
		},
		glow = p.glow or 14,
		collisiondetection = false,
	})
end

--- Continuous particle effect attached to an object (aura, trails...).
-- For players the effect is split: other players see it fully, while the
-- player sees a fainter version so it does not cover their own view.
-- Returns a handle to stop later with fx.stop().
function fx.attach(kind, object, overrides)
	local p = theme.particles[kind]
	if not p or not object then
		return nil
	end
	overrides = overrides or {}
	local color = overrides.color or p.color
	local size = overrides.size or p.size or 2
	local spread = overrides.spread or p.spread or 0.4
	local offset = overrides.offset or p.offset or vector.zero()
	local rise = overrides.rise or p.rise or 1.5
	local amount = overrides.amount or p.amount or 20
	local alpha = p.start_alpha or 0.9
	local function spawner(amount_mult, alpha_mult, target)
		local def = {
			amount = math.max(1, math.floor(amount * amount_mult)),
			time = overrides.time or 0,
			attached = object,
			pos = {
				min = vector.new(offset.x - spread, offset.y - spread * (p.vertical_spread or 1), offset.z - spread),
				max = vector.new(offset.x + spread, offset.y + spread * (p.vertical_spread or 1), offset.z + spread),
			},
			vel = {
				min = vector.new(-0.3, rise * 0.5, -0.3),
				max = vector.new(0.3, rise, 0.3),
			},
			exptime = { min = p.life_min or 0.3, max = p.life_max or 0.7 },
			size = { min = size * 0.7, max = size * 1.3 },
			texture = {
				name = fx.texture(p.texture, color),
				alpha_tween = { alpha * alpha_mult, 0 },
				scale_tween = { 1, p.end_scale or 0.5 },
				blend = p.blend or "add",
			},
			glow = p.glow or 14,
		}
		if target then
			for k, v in pairs(target) do
				def[k] = v
			end
		end
		return core.add_particlespawner(def)
	end
	if object:is_player() then
		local name = object:get_player_name()
		return {
			spawner(1, 1, { exclude_player = name }),
			spawner(p.owner_amount or 0.5, p.owner_alpha or 0.55, { playername = name }),
		}
	end
	return spawner(1, 1)
end

function fx.stop(handle)
	if type(handle) == "table" then
		for _, id in ipairs(handle) do
			core.delete_particlespawner(id)
		end
	elseif handle then
		core.delete_particlespawner(handle)
	end
end
