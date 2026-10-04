-- Projectile engine.
--
-- One lightweight entity type carries every energy projectile. All logic is
-- server-side: each step the travelled segment is tested against walkable
-- nodes (raycast) and against actors modelled as capsules, so fast or big
-- projectiles never tunnel through targets. Projectiles have a maximum range
-- and lifetime, are never saved to the map, and are tracked in a registry
-- that lets opposing projectiles collide (the base for Beam Clash).
--
--   dbil.projectiles.spawn({
--       owner = obj, team = "players", technique = "ki_blast",
--       pos = vector, dir = unit vector, speed = 25, range = 50, radius = 0.35,
--       damage = 14, knockback = 2, lift = 0, hitstun = 0.1,
--       piercing = false, explosion_radius = 0,
--       attacker_power = n, attacker_derived = t,   -- caster snapshot
--       color = "#7fd4ff", texture = "ki_ball", trail = "projectile_trail",
--       impact = "ki_explosion", sound_impact = "explosion",
--   })
--
-- Events: projectile_impact(spec, point, target), projectile_clash(winner, loser)

local projectiles = dbil.projectiles
local cfg = dbil.config.techniques
local actors = dbil.actors
local vadd, vsub, vmul, vdot = vector.add, vector.subtract, vector.multiply, vector.dot

local ENTITY = "dbil_techniques:projectile"
local active = {}

-- Clash resolvers decide what happens when two projectiles meet. The default
-- one compares power; a future Beam Clash resolver can take over for beams.
local clash_resolvers = {}

function projectiles.register_clash_resolver(fn)
	table.insert(clash_resolvers, 1, fn)
end

function projectiles.count_by_owner(owner)
	local n = 0
	for ent in pairs(active) do
		if ent._spec and ent._spec.owner == owner then
			n = n + 1
		end
	end
	return n
end

function projectiles.active_count()
	return dbil.util.count(active)
end

local function remove(ent)
	active[ent] = nil
	if ent._trail then
		dbil.fx.stop(ent._trail)
		ent._trail = nil
	end
	ent._spec = nil
	if ent.object:is_valid() then
		ent.object:remove()
	end
end

-- Closest distance between segments p1-q1 and p2-q2 (Ericson, RTCD 5.1.9).
-- Returns squared distance and the parameter s along the first segment.
local function segment_distance_sq(p1, q1, p2, q2)
	local d1, d2, r = vsub(q1, p1), vsub(q2, p2), vsub(p1, p2)
	local a, e, f = vdot(d1, d1), vdot(d2, d2), vdot(d2, r)
	local s, t
	local eps = 1e-9
	if a <= eps and e <= eps then
		s, t = 0, 0
	elseif a <= eps then
		s, t = 0, math.max(0, math.min(1, f / e))
	else
		local c = vdot(d1, r)
		if e <= eps then
			t, s = 0, math.max(0, math.min(1, -c / a))
		else
			local b = vdot(d1, d2)
			local denom = a * e - b * b
			s = denom ~= 0 and math.max(0, math.min(1, (b * f - c * e) / denom)) or 0
			t = (b * s + f) / e
			if t < 0 then
				t, s = 0, math.max(0, math.min(1, -c / a))
			elseif t > 1 then
				t, s = 1, math.max(0, math.min(1, (b - c) / a))
			end
		end
	end
	local c1 = vadd(p1, vmul(d1, s))
	local c2 = vadd(p2, vmul(d2, t))
	local dv = vsub(c1, c2)
	return vdot(dv, dv), s
end
projectiles.segment_distance_sq = segment_distance_sq

local function is_hostile_to(spec, obj)
	if obj == spec.owner then
		return false
	end
	local team = actors.get_team(obj)
	if team ~= spec.team then
		return true
	end
	return team == "players" and dbil.config.combat.pvp
end

local function actor_capsule(obj)
	local pos = obj:get_pos()
	local box = obj:get_properties().collisionbox
	local r = math.max(box[4] - box[1], box[6] - box[3]) / 2
	local bottom = vector.new(pos.x, pos.y + box[2] + r, pos.z)
	local top = vector.new(pos.x, pos.y + math.max(box[5] - r, box[2] + r), pos.z)
	return bottom, top, r
end

local function damage_target(spec, target, amount, point, knockback_mult)
	local owner = spec.owner
	if owner and not owner:is_valid() then
		owner = nil
	end
	return dbil.combat.deal_damage({
		attacker = owner,
		attacker_name = spec.owner_name,
		attacker_power = spec.attacker_power,
		attacker_derived = spec.attacker_derived,
		target = target,
		amount = amount,
		kind = "ki",
		source = spec.technique,
		knockback = spec.knockback * (knockback_mult or 1),
		lift = spec.lift,
		direction = spec.dir,
		hitstun = spec.hitstun,
		pos = point,
		fx = "none",
		ignore_teams = true, -- team rules already applied by the projectile
	})
end

local function explode(spec, point, exclude)
	local radius = spec.explosion_radius
	for _, obj in ipairs(actors.in_radius(point, radius + 1)) do
		if obj ~= exclude and is_hostile_to(spec, obj) then
			local d = vector.distance(point, actors.get_center(obj))
			if d <= radius + 0.5 then
				local falloff = 1 - 0.5 * math.min(1, d / radius)
				damage_target(spec, obj, spec.damage * falloff, point, falloff)
			end
		end
	end
end

local function impact(ent, point, target)
	local spec = ent._spec
	if target then
		damage_target(spec, target, spec.damage, point)
		spec.hit[target] = true
	end
	if spec.explosion_radius > 0 then
		explode(spec, point, target)
	end
	local fx_size = math.max(1, spec.radius * 4)
	dbil.fx.burst(spec.impact, point, { color = spec.color, size = fx_size, spread = spec.radius })
	if spec.radius >= 0.5 or spec.explosion_radius > 0 then
		dbil.fx.burst("ki_smoke", point, { size = fx_size * 1.5 })
	end
	dbil.fx.sound(spec.sound_impact, point, { gain = math.min(1, 0.4 + spec.radius) })
	dbil.events.emit("projectile_impact", spec, point, target)
	if not (spec.piercing and target) then
		remove(ent)
	end
end

local function fizzle(ent)
	local spec = ent._spec
	dbil.fx.burst(spec.impact, ent.object:get_pos(), { color = spec.color, size = spec.radius * 2, amount = 6 })
	remove(ent)
end

local function step(ent, dtime)
	local spec = ent._spec
	local obj = ent.object
	if not spec then
		obj:remove()
		return
	end
	spec.age = spec.age + dtime
	local pos = obj:get_pos()
	local from = spec.last_pos
	local seg = vsub(pos, from)
	local seg_len = vector.length(seg)
	spec.travelled = spec.travelled + seg_len

	if seg_len > 1e-6 then
		-- Walkable nodes along the path.
		local node_s, node_point
		local ahead = vadd(pos, vmul(spec.dir, spec.radius * 0.5))
		for pointed in core.raycast(from, ahead, false, false) do
			if pointed.type == "node" then
				local node = core.get_node(pointed.under)
				local def = core.registered_nodes[node.name]
				if def and def.walkable ~= false then
					node_point = pointed.intersection_point
					node_s = vector.distance(from, node_point) / seg_len
					break
				end
			end
		end

		-- Actors along the path (capsule test).
		local best_s, best_obj
		local mid = vadd(from, vmul(seg, 0.5))
		for _, target in ipairs(actors.in_radius(mid, seg_len / 2 + spec.radius + 2.5)) do
			if not spec.hit[target] and is_hostile_to(spec, target) then
				local bottom, top, r = actor_capsule(target)
				local d2, s = segment_distance_sq(from, pos, bottom, top)
				local reach = spec.radius + r
				if d2 <= reach * reach and (not best_s or s < best_s) then
					best_s, best_obj = s, target
				end
			end
		end

		if best_obj and (not node_s or best_s <= node_s) then
			impact(ent, vadd(from, vmul(seg, best_s)), best_obj)
			if not ent._spec then
				return
			end
			-- A piercing projectile can still hit a wall later in this step.
			if node_point then
				impact(ent, node_point, nil)
				return
			end
		elseif node_point then
			impact(ent, node_point, nil)
			return
		end
	end

	if spec.travelled >= spec.range or spec.age >= spec.max_life then
		fizzle(ent)
		return
	end
	spec.last_pos = pos
end

core.register_entity(ENTITY, {
	initial_properties = {
		physical = false,
		collide_with_objects = false,
		pointable = false,
		visual = "sprite",
		textures = { "dbil_blank.png" },
		visual_size = { x = 1, y = 1 },
		use_texture_alpha = true,
		glow = 14,
		static_save = false,
		shaded = false,
		collisionbox = { 0, 0, 0, 0, 0, 0 },
	},
	on_step = function(self, dtime)
		step(self, dtime)
	end,
	on_deactivate = function(self)
		if self._spec then
			remove(self)
		end
	end,
})

function projectiles.spawn(spec)
	if spec.owner and projectiles.count_by_owner(spec.owner) >= cfg.max_projectiles_per_caster then
		return nil
	end
	local obj = core.add_entity(spec.pos, ENTITY)
	if not obj then
		return nil
	end
	local ent = obj:get_luaentity()
	spec.dir = vector.normalize(spec.dir)
	spec.range = math.min(spec.range or 50, cfg.max_projectile_range)
	spec.max_life = spec.range / spec.speed + 0.5
	spec.age = 0
	spec.travelled = 0
	spec.last_pos = vector.copy(spec.pos)
	spec.hit = {}
	spec.knockback = spec.knockback or 0
	spec.lift = spec.lift or 0
	spec.explosion_radius = spec.explosion_radius or 0
	spec.power = spec.power or spec.damage
	spec.initial_power = spec.power
	spec.impact = spec.impact or "ki_explosion"
	ent._spec = spec
	local diameter = spec.radius * 2 * (spec.visual_scale or 1.5)
	obj:set_properties({
		textures = { dbil.fx.texture(spec.texture or "ki_ball", spec.color) },
		visual_size = { x = diameter, y = diameter },
	})
	obj:set_velocity(vmul(spec.dir, spec.speed))
	ent._trail = dbil.fx.attach(spec.trail or "projectile_trail", obj, {
		color = spec.color,
		size = math.max(0.8, spec.radius * 3),
		spread = spec.radius * 0.4,
	})
	active[ent] = true
	return obj
end

-- Clashes ----------------------------------------------------------------------

local function default_clash(a, b)
	local winner, loser = a, b
	if b._spec.power > a._spec.power then
		winner, loser = b, a
	end
	local ws, ls = winner._spec, loser._spec
	local point = vector.divide(vadd(winner.object:get_pos(), loser.object:get_pos()), 2)
	dbil.fx.burst(ls.impact, point, { color = ls.color, size = ls.radius * 4 })
	dbil.fx.sound(ls.sound_impact, point)
	local remaining = ws.power - ls.power
	dbil.events.emit("projectile_clash", ws, ls)
	remove(loser)
	if remaining <= ws.initial_power * cfg.clash_min_remaining then
		dbil.fx.burst(ws.impact, point, { color = ws.color, size = ws.radius * 4 })
		remove(winner)
	else
		local factor = remaining / ws.power
		ws.damage = ws.damage * factor
		ws.power = remaining
	end
	return true
end

local function clashing(a, b)
	local sa, sb = a._spec, b._spec
	if not sa or not sb then
		return false
	end
	if sa.team == sb.team and not (sa.team == "players" and dbil.config.combat.pvp and sa.owner ~= sb.owner) then
		return false
	end
	local reach = sa.radius + sb.radius + 0.3
	return dbil.util.dist_sq(a.object:get_pos(), b.object:get_pos()) <= reach * reach
end

dbil.scheduler.every("projectile_clash", 0, function()
	if not cfg.projectile_clash then
		return
	end
	local list = {}
	for ent in pairs(active) do
		if ent._spec and ent.object:is_valid() then
			list[#list + 1] = ent
		end
	end
	for i = 1, #list - 1 do
		for j = i + 1, #list do
			local a, b = list[i], list[j]
			if clashing(a, b) then
				local handled = false
				for _, resolver in ipairs(clash_resolvers) do
					if resolver(a, b) then
						handled = true
						break
					end
				end
				if not handled then
					default_clash(a, b)
				end
			end
		end
	end
end, 70)
