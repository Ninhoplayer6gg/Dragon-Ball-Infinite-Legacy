-- Transformation runtime: transforming, staying transformed, reverting.
--
-- Mastery makes a form faster to enter, cheaper to keep and stronger
-- (e.g. a fresh Super Saiyan drains a lot of Ki and takes long to transform;
-- a mastered one is quick and efficient).
--
-- API: dbil.transformations.activate(player, id), deactivate(player, reason),
--      get_active(player), next_form(player), is_transforming(player)
-- Events: transformed(player, id), reverted(player, id, reason)

local tf = dbil.transformations
local now = dbil.util.now

local function mastery_level(player, id)
	return dbil.mastery.get_level(player, tf.mastery_key(id))
end

local MIN_FACTOR = dbil.config.progression.mastery.min_factor

local function factor(level, per_level)
	return math.max(MIN_FACTOR, 1 - level * per_level)
end

function tf.get_active(player)
	local state = dbil.players.get_state(player)
	return state and state.form and state.form.def or nil
end

function tf.is_transforming(player)
	local state = dbil.players.get_state(player)
	return state ~= nil and state.form_pending ~= nil
end

--- Can `id` be entered right now from the current form?
local function reachable(state, def)
	local current = state.form and state.form.id
	if not current then
		return #def.from == 0
	end
	return dbil.util.contains(def.from, current)
end

--- The next form in a chain (base -> first form -> its successors).
function tf.next_form(player)
	local state = dbil.players.get_state(player)
	if not state or not state.ready then
		return nil
	end
	for id, def in tf.iter() do
		if state.char.transformations.unlocked[id] and reachable(state, def)
				and tf.meets_requirements(state.char, def) then
			return id
		end
	end
	return nil
end

function tf.activate(player, id)
	local state = dbil.players.get_state(player)
	local def = tf.get(id)
	if not state or not state.ready or not def then
		return false, "Transformação desconhecida."
	end
	if state.form_pending then
		return false, "Já está se transformando."
	end
	if not state.char.transformations.unlocked[id] then
		return false, "Transformação bloqueada."
	end
	local ok, reason = tf.meets_requirements(state.char, def)
	if not ok then
		return false, reason
	end
	if not reachable(state, def) then
		return false, "Não é possível alcançar esta forma a partir da atual."
	end
	if not dbil.input.can_act(player) then
		return false, "Não é possível agora."
	end
	local level = mastery_level(player, id)
	if def.cost.ki > 0 and not dbil.ki.try_spend(player, def.cost.ki, "transformation") then
		return false, "Ki insuficiente para se transformar."
	end
	local duration = def.transform_time * factor(level, def.mastery.time_reduction_per_level)
	dbil.ki.stop_charging(player, "transform")
	state.form_pending = {
		id = id,
		ready_at = now() + duration,
		aura = dbil.fx.attach("aura", player, { color = def.aura.color, amount = def.aura.amount * 2 }),
	}
	dbil.input.lock(player, "transforming", duration)
	dbil.physics.set(player, "transforming", { speed = 0, jump = 0 })
	dbil.fx.sound("charge_start", player, { gain = 1 })
	dbil.events.emit("transformation_started", player, id)
	return true
end

local function remove_effects(player, state)
	local form = state.form
	if form then
		dbil.stats.clear_modifier(player, "transformation")
		dbil.appearance.pop(player, "transformation")
		dbil.fx.stop(form.aura)
	end
	state.form = nil
end

local function apply(player, state, id)
	local def = tf.get(id)
	local previous = state.form and state.form.id
	remove_effects(player, state)
	local level = mastery_level(player, id)
	local mods = dbil.util.deep_copy(def.modifiers)
	mods.power_mult = mods.power_mult or {}
	mods.power_mult.mul = (mods.power_mult.mul or 1) * (1 + level * def.mastery.power_bonus_per_level)
	dbil.stats.set_modifier(player, "transformation", mods)
	if def.appearance then
		dbil.appearance.push(player, "transformation", {
			hair = def.appearance.hair,
			skin_mod = def.appearance.skin_mod,
		}, 50)
	end
	state.form = {
		id = id,
		def = def,
		started = now(),
		aura = dbil.fx.attach("aura", player, { color = def.aura.color, amount = def.aura.amount }),
		hp_acc = 0,
		xp_acc = 0,
	}
	local pos = vector.add(player:get_pos(), vector.new(0, 1, 0))
	dbil.fx.burst("level_up", pos, { color = def.aura.color, amount = 50, speed = 6 })
	dbil.fx.sound("explosion", player, { gain = 0.6, pitch = 1.4 })
	dbil.events.emit("transformed", player, id, previous)
	dbil.events.emit("notify", player, def.name .. "!", "power")
end

function tf.deactivate(player, reason)
	local state = dbil.players.get_state(player)
	if not state then
		return false
	end
	if state.form_pending then
		dbil.fx.stop(state.form_pending.aura)
		state.form_pending = nil
		dbil.physics.clear(player, "transforming")
		dbil.input.unlock(player, "transforming")
	end
	local form = state.form
	if not form then
		return false
	end
	remove_effects(player, state)
	dbil.events.emit("reverted", player, form.id, reason or "manual")
	if reason == "exhausted" then
		dbil.events.emit("notify", player, "Energia esgotada: a transformação se desfez.", "warning")
	end
	return true
end

dbil.players.register_tick("transformations", 0.25, function(player, state, dt)
	local pending = state.form_pending
	if pending then
		if player:get_hp() <= 0 then
			tf.deactivate(player, "died")
		elseif now() >= pending.ready_at then
			dbil.fx.stop(pending.aura)
			state.form_pending = nil
			dbil.physics.clear(player, "transforming")
			apply(player, state, pending.id)
		end
		return
	end
	local form = state.form
	if not form then
		return
	end
	local def = form.def
	local level = mastery_level(player, form.id)
	local drain = factor(level, def.mastery.drain_reduction_per_level)
	if def.drain.ki > 0 then
		local cost = dbil.ki.cost(player, def.drain.ki * dt * drain)
		dbil.resources.drain(player, "ki", cost, "transformation")
		if dbil.ki.get(player) <= 0 then
			tf.deactivate(player, "exhausted")
			return
		end
	end
	if def.drain.stamina > 0 then
		dbil.resources.drain(player, "stamina", def.drain.stamina * dt * drain, "transformation")
	end
	if def.drain.hp_percent > 0 then
		local max = dbil.resources.get_max(player, "hp")
		form.hp_acc = form.hp_acc + max * def.drain.hp_percent / 100 * dt * drain
		if form.hp_acc >= 1 then
			local loss = math.floor(form.hp_acc)
			form.hp_acc = form.hp_acc - loss
			local hp = player:get_hp()
			-- Strain hurts but never kills on its own.
			dbil.resources.set(player, "hp", math.max(1, hp - loss), "transformation_strain")
		end
	end
	form.xp_acc = form.xp_acc + dt
	if form.xp_acc >= 1 then
		form.xp_acc = form.xp_acc - 1
		dbil.mastery.add_xp(player, tf.mastery_key(form.id), def.mastery.xp_per_second, def.mastery.max_level)
	end
end, 65)

dbil.input.register_action("transform_next", {
	handler = function(player)
		local id = tf.next_form(player)
		if not id then
			dbil.events.emit("notify", player, "Nenhuma transformação disponível.", "warning")
			return false
		end
		local ok, err = tf.activate(player, id)
		if not ok and err then
			dbil.events.emit("notify", player, err, "warning")
		end
		return ok
	end,
})

dbil.input.register_action("transform_revert", {
	allow_locked = true,
	handler = function(player)
		return tf.deactivate(player, "manual")
	end,
})

dbil.animation.register_pose(400, function(player, state)
	if state.form_pending then
		return "charge"
	end
end)

dbil.events.on("character_ready", function(player, char, state)
	state.form = nil
	state.form_pending = nil
end)

dbil.events.on("character_leaving", function(player)
	tf.deactivate(player, "leaving")
end, 50)

dbil.events.on("player_died", function(info)
	tf.deactivate(info.player, "died")
end)
