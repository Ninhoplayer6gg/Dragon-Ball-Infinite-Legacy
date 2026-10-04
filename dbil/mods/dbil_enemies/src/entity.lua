-- Enemy entity: actor interface, health, damage, death, rewards and
-- persistence. Behaviour is delegated to the enemy's brain.

local enemies = dbil.enemies
local cfg = dbil.config.enemies
local actors = dbil.actors
local now = dbil.util.now

local GRAVITY = -9.81

local Enemy = {}

-- Actor interface (see dbil_character/src/actors.lua) ------------------------

function Enemy:dbil_get_name()
	return self._def.name
end

function Enemy:dbil_get_team()
	return self._def.team
end

function Enemy:dbil_get_power()
	local ratio = self._hp / self._max_hp
	local min = dbil.config.power.health_factor_min
	return math.max(1, math.floor(self._power * (min + (1 - min) * ratio)))
end

function Enemy:dbil_get_derived()
	return self._derived
end

function Enemy:dbil_get_hp()
	return self._hp
end

function Enemy:dbil_get_max_hp()
	return self._max_hp
end

function Enemy:dbil_is_alive()
	return not self._dead and self._hp > 0
end

function Enemy:dbil_get_look_dir()
	local yaw = self.object:get_yaw() or 0
	return dbil.util.yaw_dir(yaw)
end

function Enemy:dbil_knockback(push)
	local obj = self.object
	obj:set_velocity(vector.add(obj:get_velocity(), push))
	self._knock_until = now() + cfg.knockback_time
end

local function update_nametag(self)
	local text = self._def.name
	if self._hp < self._max_hp and not self._def.passive then
		text = ("%s (%d%%)"):format(text, math.ceil(self._hp / self._max_hp * 100))
	end
	self.object:set_properties({ nametag = text })
end

function Enemy:dbil_receive_damage(info)
	if self._dead then
		return
	end
	local amount = info.damage
	self._hp = math.max(0, self._hp - amount)
	self._last_hit = now()
	local name = info.attacker and info.attacker:is_player() and info.attacker:get_player_name()
		or info.attacker_name
	if name then
		self._damage_by[name] = (self._damage_by[name] or 0) + amount
		-- Retaliate against whoever is hurting us.
		if info.attacker and info.attacker:is_valid() and self._brain.on_damaged then
			self._brain.on_damaged(self, info.attacker)
		end
	end
	if self._hp <= 0 then
		if self._def.passive then
			-- Training dummies cannot die.
			self._hp = 1
		else
			self:dbil_die(info)
			return
		end
	end
	update_nametag(self)
end

local function drop_items(self, pos)
	for _, drop in ipairs(self._def.drops) do
		if math.random() <= drop.chance and core.registered_items[drop.item] then
			local count = math.random(drop.min, math.max(drop.min, drop.max))
			local obj = core.add_item(vector.add(pos, vector.new(0, 0.5, 0)), ItemStack(drop.item .. " " .. count))
			if obj then
				obj:set_velocity(vector.new(math.random() * 2 - 1, 3, math.random() * 2 - 1))
			end
		end
	end
end

function Enemy:dbil_die(info)
	if self._dead then
		return
	end
	self._dead = true
	self._hp = 0
	self._remove_at = now() + cfg.corpse_time
	local obj = self.object
	local pos = obj:get_pos()
	obj:set_velocity(vector.new(0, 0, 0))
	obj:set_properties({ nametag = "", pointable = false })
	dbil.animation.set(obj, "dead")
	dbil.fx.burst("death", vector.add(pos, vector.new(0, 0.8, 0)))
	dbil.fx.sound("enemy_death", pos)
	actors.untrack(self)
	drop_items(self, pos)
	dbil.events.emit("enemy_killed", {
		id = self._id,
		name = self._def.name,
		xp = self._def.xp * (self._power_mult or 1),
		power = self._power,
		pos = pos,
		contributors = self._damage_by,
		killer = info and info.attacker,
	})
end

-- Lifecycle -------------------------------------------------------------------

function Enemy:on_activate(staticdata)
	local data = core.deserialize(staticdata or "", true) or {}
	local def = self._def
	local variance = cfg.power_variance
	self._power_mult = data.power_mult or (1 + (math.random() * 2 - 1) * variance)
	self._power = def.power * self._power_mult
	self._max_hp = math.floor(def.hp * self._power_mult)
	self._hp = data.hp and math.min(data.hp, self._max_hp) or self._max_hp
	self._home = data.home or self.object:get_pos()
	self._spawner = data.spawner
	self._damage_by = {}
	self._derived = { melee_mult = def.melee_mult, ki_mult = def.ki_mult, defense = def.defense }
	self._dead = false
	self._ai_timer = math.random() * cfg.think_interval
	self._last_player_seen = now()
	self.object:set_armor_groups({ immortal = 1 })
	self.object:set_acceleration(vector.new(0, GRAVITY, 0))
	self.object:set_yaw(math.random() * math.pi * 2)
	self._brain = enemies.get_brain(def.brain)
	if self._brain.init then
		self._brain.init(self)
	end
	actors.track(self)
	update_nametag(self)
	dbil.animation.set(self.object, "stand")
end

function Enemy:get_staticdata()
	return core.serialize({
		hp = self._hp,
		home = self._home,
		spawner = self._spawner,
		power_mult = self._power_mult,
	})
end

function Enemy:on_deactivate()
	actors.untrack(self)
end

function Enemy:on_step(dtime, moveresult)
	if self._dead then
		if now() >= self._remove_at then
			self.object:remove()
		end
		return
	end
	self._moveresult = moveresult
	if self._brain.step then
		self._brain.step(self, dtime, moveresult)
	end
	self._ai_timer = self._ai_timer + dtime
	if self._ai_timer >= cfg.think_interval then
		local elapsed = self._ai_timer
		self._ai_timer = 0
		self._brain.think(self, elapsed)
		-- Despawn spawner enemies left alone for a long time.
		if self._spawner and now() - self._last_player_seen > cfg.despawn_alone_time then
			self.object:remove()
		end
	end
end

-- Engine punches (hand or non-kit items) become a light attack.
function Enemy:on_punch(puncher)
	if puncher and puncher:is_player() and not dbil.input.is_kit_item(puncher:get_wielded_item()) then
		dbil.input.trigger(puncher, "light_attack", { pointed = { type = "object", ref = self.object } })
	end
	return true
end

function enemies.register_entity(id, def)
	local v = def.visual
	local entity = {
		initial_properties = {
			physical = true,
			collide_with_objects = true,
			collisionbox = v.collisionbox,
			selectionbox = v.collisionbox,
			visual = "mesh",
			mesh = v.mesh,
			textures = v.textures,
			visual_size = { x = v.visual_size, y = v.visual_size, z = v.visual_size },
			use_texture_alpha = true,
			backface_culling = false,
			stepheight = 0.6,
			hp_max = 1000,
			nametag_color = v.nametag_color,
			damage_texture_modifier = "^[colorize:#ff303080",
			static_save = true,
		},
		_dbil_actor = true,
		_def = def,
		_id = id,
	}
	for k, fn in pairs(Enemy) do
		entity[k] = fn
	end
	core.register_entity(enemies.entity_name(id), entity)
end
