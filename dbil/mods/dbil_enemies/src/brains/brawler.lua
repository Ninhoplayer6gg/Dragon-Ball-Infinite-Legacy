-- "brawler" brain: idle/wander -> notice player -> chase -> telegraphed melee,
-- Ki blasts at range (and against flying players), optional self-destruct,
-- leash back home when dragged too far.

local enemies = dbil.enemies
local ai = enemies.ai
local cfg = dbil.config.enemies
local actors = dbil.actors
local now = dbil.util.now

local brawler = {}

function brawler.init(self)
	self._ai = {
		state = "idle",
		next_perception = 0,
		attack_ready = 0,
		ranged_ready = now() + 2,
		windup_until = nil,
		wander_until = 0,
		wander_dir = nil,
	}
end

function brawler.on_damaged(self, attacker)
	local a = self._ai
	if attacker:is_player() and (not a.target or a.state == "idle" or a.state == "return") then
		a.target = attacker
		a.state = "chase"
	end
end

local function strike(self, target)
	local def = self._def
	local d = vector.distance(self.object:get_pos(), target:get_pos())
	if d > def.attack_range + 1.0 then
		dbil.fx.sound("swing", self.object)
		return
	end
	dbil.combat.deal_damage({
		attacker = self.object,
		target = target,
		amount = def.attack,
		kind = "melee",
		source = "enemy_melee",
		knockback = def.knockback,
		hitstun = def.hitstun,
		fx = "hit_light",
		sound = "punch_light",
	})
end

local function explode(self)
	local sd = self._def.self_destruct
	local pos = actors.get_center(self.object)
	for _, obj in ipairs(actors.in_radius(pos, sd.radius + 1)) do
		if actors.are_hostile(self.object, obj) then
			local d = vector.distance(pos, actors.get_center(obj))
			if d <= sd.radius then
				dbil.combat.deal_damage({
					attacker = self.object,
					target = obj,
					amount = sd.damage * (1 - 0.5 * d / sd.radius),
					kind = "ki",
					source = "self_destruct",
					knockback = sd.knockback,
					lift = sd.lift,
					hitstun = sd.hitstun,
					fx = "hit_heavy",
				})
			end
		end
	end
	dbil.fx.burst("ki_explosion", pos, { color = "#b6ff9a", size = 6, amount = 40, speed = 8, spread = 1 })
	dbil.fx.burst("ki_smoke", pos, { size = 8 })
	dbil.fx.sound("explosion", pos, { gain = 1 })
	self:dbil_die(nil)
end

local function start_self_destruct(self)
	local a = self._ai
	a.state = "self_destruct"
	a.explode_at = now() + self._def.self_destruct.windup
	a.aura = dbil.fx.attach("aura", self.object, { color = "#ff5050", amount = 40 })
	dbil.animation.set(self.object, "charge")
	ai.stop(self)
end

local function think_combat(self, target)
	local a = self._ai
	local def = self._def
	local t = now()
	local pos = self.object:get_pos()
	local tpos = target:get_pos()
	local dist = vector.distance(pos, tpos)
	local height = tpos.y - pos.y

	ai.face(self, tpos)

	-- Finish a telegraphed attack.
	if a.windup_until then
		if t >= a.windup_until then
			a.windup_until = nil
			a.attack_ready = t + def.attack_cooldown
			strike(self, target)
		end
		return
	end

	local sd = def.self_destruct
	if sd and not a.self_destruct_rolled and self._hp / self._max_hp <= sd.hp_ratio then
		a.self_destruct_rolled = true
		if math.random() < sd.chance then
			a.self_destruct_armed = true
		end
	end
	if a.self_destruct_armed and dist <= sd.trigger_range + 1 then
		start_self_destruct(self)
		return
	end

	if dist <= def.attack_range and math.abs(height) < 2.5 then
		ai.stop(self)
		if t >= a.attack_ready then
			a.windup_until = t + def.attack_windup
			dbil.animation.action(self.object, "heavy", def.attack_windup + 0.3)
		end
		return
	end

	local r = def.ranged
	if r and t >= a.ranged_ready and dist >= r.min_range and dist <= r.max_range and ai.can_see(self, target) then
		-- Flying targets are always shot at; grounded ones only sometimes.
		if height > 3 or math.random() < r.chance then
			a.ranged_ready = t + r.cooldown
			ai.stop(self)
			dbil.techniques.cast_npc(self.object, r.technique, { target = target })
			return
		end
		a.ranged_ready = t + 0.8
	end

	-- Chase on foot. Against high flyers keep a shooting distance instead.
	local dir = vector.subtract(tpos, pos)
	dir.y = 0
	if vector.length(dir) < 0.01 then
		ai.stop(self)
		return
	end
	dir = vector.normalize(dir)
	if height > 4 and r and dist < r.min_range + 2 then
		dir = vector.multiply(dir, -1)
	end
	ai.move(self, dir, def.speed)
	ai.jump_if_blocked(self, dir)
end

function brawler.think(self, dt)
	local a = self._ai
	local def = self._def
	local t = now()

	if a.state == "self_destruct" then
		if t >= a.explode_at then
			dbil.fx.stop(a.aura)
			explode(self)
		end
		return
	end

	if ai.is_stunned(self) then
		a.windup_until = nil
		ai.stop(self)
		return
	end

	if t >= a.next_perception then
		a.next_perception = t + cfg.perception_interval
		if not ai.target_valid(self, a.target) then
			a.target = nil
			if a.state == "chase" then
				a.state = "return"
			end
		end
		if not a.target and a.state ~= "return" then
			a.target = ai.find_target(self)
			if a.target then
				a.state = "chase"
			end
		elseif a.target then
			ai.find_target(self) -- keeps the "player seen" timer fresh
		end
	end

	if a.state == "chase" and a.target and ai.distance_home(self) > def.leash then
		a.target = nil
		a.state = "return"
	end

	if a.state == "chase" and a.target then
		think_combat(self, a.target)
	elseif a.state == "return" then
		local home = self._home
		local pos = self.object:get_pos()
		local dir = vector.subtract(home, pos)
		dir.y = 0
		if vector.length(dir) < 2 then
			a.state = "idle"
			ai.stop(self)
			-- Recover while resting at home.
			self._hp = self._max_hp
			self._damage_by = {}
			self.object:set_properties({ nametag = def.name })
		else
			dir = vector.normalize(dir)
			ai.face(self, home)
			ai.move(self, dir, def.speed)
			ai.jump_if_blocked(self, dir)
		end
	else
		-- Idle: occasionally wander around home.
		if t < a.wander_until and a.wander_dir then
			ai.move(self, a.wander_dir, def.speed * 0.4)
			ai.jump_if_blocked(self, a.wander_dir)
		else
			ai.stop(self)
			if math.random() < cfg.wander_chance * dt then
				local angle = math.random() * math.pi * 2
				local dir = vector.new(-math.sin(angle), 0, math.cos(angle))
				if ai.distance_home(self) > cfg.wander_radius then
					dir = vector.normalize(vector.subtract(self._home, self.object:get_pos()))
					dir.y = 0
				end
				a.wander_dir = dir
				a.wander_until = t + 1.5 + math.random() * 2
				ai.face(self, vector.add(self.object:get_pos(), dir))
			end
		end
	end

	-- Base animation (actions such as attacks override it for a while).
	if not dbil.animation.in_action(self.object) and a.state ~= "self_destruct" then
		local v = self.object:get_velocity()
		if v.x * v.x + v.z * v.z > 0.5 then
			dbil.animation.set(self.object, "walk", self._def.speed / 4)
		else
			dbil.animation.set(self.object, "stand")
		end
	end
end

enemies.register_brain("brawler", brawler)
