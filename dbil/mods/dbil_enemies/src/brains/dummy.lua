-- "dummy" brain: a training target. Never attacks, never dies, turns to face
-- whoever hits it and slowly recovers when left alone.

local enemies = dbil.enemies
local ai = enemies.ai
local cfg = dbil.config.enemies
local now = dbil.util.now

local dummy = {}

function dummy.init(self)
	self._ai = {}
	self.object:set_velocity(vector.new(0, 0, 0))
end

function dummy.on_damaged(self, attacker)
	ai.face(self, attacker:get_pos())
end

function dummy.think(self, dt)
	if not ai.is_knocked(self) then
		ai.stop(self)
	end
	-- Stay close to the original spot even after knockback.
	if ai.distance_home(self) > 1.5 and not ai.is_knocked(self) then
		self.object:set_pos(self._home)
	end
	if self._hp < self._max_hp and now() - (self._last_hit or 0) > cfg.dummy_regen_delay then
		self._hp = math.min(self._max_hp, self._hp + self._max_hp * cfg.dummy_regen_percent / 100 * dt)
	end
	if not dbil.animation.in_action(self.object) then
		dbil.animation.set(self.object, "block")
	end
end

enemies.register_brain("dummy", dummy)
