-- Technique shapes: how a technique materializes when fired.
--
-- "ball": one or more energy spheres (count/spread_degrees properties give
--         rapid barrages).
-- Planned shapes (same interface): "beam" (continuous, Kamehameha / Galick
-- Gun, enables Beam Clash), "disc" (Destructo Disc, slicing), "explosion"
-- (area around the caster), "wave" (wide arc), "barrage".

local techniques = dbil.techniques
local projectiles = dbil.projectiles

local function rotate_yaw(dir, angle)
	local c, s = math.cos(angle), math.sin(angle)
	return vector.new(dir.x * c - dir.z * s, dir.y, dir.x * s + dir.z * c)
end

techniques.register_shape("ball", {
	fire = function(caster, def, p)
		local props = def.properties
		local count = math.max(1, math.floor(props.count or 1))
		local spread = math.rad(props.spread_degrees or 0)
		local fired = 0
		for i = 1, count do
			local dir = p.dir
			if count > 1 then
				local offset = (i - (count + 1) / 2) / math.max(1, count - 1) * spread
				dir = rotate_yaw(p.dir, offset)
			end
			local obj = projectiles.spawn({
				owner = caster,
				owner_name = caster:is_player() and caster:get_player_name() or nil,
				team = dbil.actors.get_team(caster),
				technique = def.id,
				pos = p.origin,
				dir = dir,
				speed = p.speed,
				range = p.range,
				radius = p.size,
				damage = p.damage / count,
				power = p.power / count,
				knockback = p.knockback,
				lift = p.lift,
				hitstun = p.hitstun,
				piercing = props.piercing == true,
				explosion_radius = (props.explosion_radius or 0) * (1 + (p.charge_mult - 1) * 0.5),
				attacker_power = p.attacker_power,
				attacker_derived = p.attacker_derived,
				color = def.visual.color,
				texture = def.visual.texture,
				trail = def.visual.trail,
				impact = def.visual.impact,
				sound_impact = def.visual.sound_impact,
			})
			if obj then
				fired = fired + 1
			end
		end
		return fired > 0
	end,
})
