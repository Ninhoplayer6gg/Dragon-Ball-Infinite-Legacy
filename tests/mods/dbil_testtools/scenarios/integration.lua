-- End-to-end integration scenario with real connected clients (P1, P2).
--
-- Phase "api": scripted checks of every system through the public APIs,
--              using the real player objects of both clients.
-- Phase "input": the Python harness presses keys/mouse on P1's client while
--              this scenario logs events (charge, flight, attacks...).
-- Phase "persist": snapshots are compared after reconnects/server restarts.
--
-- Every result is logged as "[dbil-test] PASS|FAIL <name> <detail>".

local results = { pass = 0, fail = 0 }
local tag = "[dbil-test] "

local function log(fmt, ...)
	core.log("action", tag .. string.format(fmt, ...))
end

local function check(cond, name, detail)
	if cond then
		results.pass = results.pass + 1
		log("PASS %s %s", name, detail or "")
	else
		results.fail = results.fail + 1
		log("FAIL %s %s", name, detail or "")
	end
	return cond
end

-- Event log (used by the harness for input checks) ---------------------------

local function pname(obj)
	if obj and obj:is_valid() then
		return obj:is_player() and obj:get_player_name() or (dbil.actors.get_name(obj) or "?")
	end
	return "-"
end

local orig_trigger = dbil.input.trigger
dbil.input.trigger = function(player, name, params)
	local result = orig_trigger(player, name, params)
	log("ACTION %s %s %s", pname(player), name, tostring(result))
	return result
end

for _, event in ipairs({ "charge_started", "flight_started", "dash", "guard_started", "level_up", "zenkai" }) do
	dbil.events.on(event, function(player, ...)
		log("EVENT %s %s %s", event, pname(player), table.concat({ ... }, " "))
	end)
end
dbil.events.on("charge_stopped", function(player, reason)
	log("EVENT charge_stopped %s %s", pname(player), tostring(reason))
end)
dbil.events.on("flight_stopped", function(player, reason)
	log("EVENT flight_stopped %s %s", pname(player), tostring(reason))
end)
dbil.events.on("technique_used", function(caster, id, info)
	log("EVENT technique_used %s %s charge=%.2f", pname(caster), id, info and info.charge_mult or 1)
end)
dbil.events.on("damage_dealt", function(info)
	log("EVENT damage %s -> %s %d %s %s", pname(info.attacker), pname(info.target), info.damage, info.kind, info.result)
end)
dbil.events.on("enemy_killed", function(info)
	local names = {}
	for n in pairs(info.contributors) do
		names[#names + 1] = n
	end
	log("EVENT enemy_killed %s by %s", info.id, table.concat(names, ","))
end)
dbil.events.on("player_died", function(info)
	log("EVENT player_died %s", pname(info.player))
end)
dbil.events.on("quest_completed", function(player, id)
	log("EVENT quest_completed %s %s", pname(player), id)
end)

-- Helpers ---------------------------------------------------------------------

local function P(name)
	return core.get_player_by_name(name)
end

local function snapshot(player)
	local char = dbil.players.get_character(player)
	return {
		name = char.name,
		race = char.race,
		level = char.level,
		xp = math.floor(char.xp),
		strength = math.floor(char.attributes.strength * 100),
		techniques = dbil.util.count(char.techniques.learned),
		kills = char.stats.kills or 0,
	}
end

local function same(a, b)
	for k, v in pairs(a) do
		if b[k] ~= v then
			return false, ("%s: %s ~= %s"):format(k, tostring(v), tostring(b[k]))
		end
	end
	return true
end

local function snapshot_key(name)
	return "test:snapshot:" .. name
end

local function front_of(player, dist)
	local dir = dbil.util.yaw_dir(player:get_look_horizontal())
	local pos = vector.add(player:get_pos(), vector.multiply(dir, dist))
	pos.y = pos.y + 0.5
	return pos
end

local function clear_enemies(pos, radius)
	for _, obj in ipairs(core.get_objects_inside_radius(pos, radius or 60)) do
		local ent = obj:get_luaentity()
		if ent and ent._dbil_actor and ent._id ~= "training_dummy" then
			obj:remove()
		end
	end
end

local function face(player, pos)
	local d = vector.subtract(pos, player:get_pos())
	player:set_look_horizontal(math.atan2(-d.x, d.z))
	player:set_look_vertical(0.1)
end

-- Step runner -----------------------------------------------------------------

local steps = {}
local ctx = {}

local function step(name, fn)
	steps[#steps + 1] = { name = name, fn = fn }
end

local function run(i)
	if i > #steps then
		log("PHASE api done pass=%d fail=%d", results.pass, results.fail)
		return
	end
	local s = steps[i]
	local ok, wait = xpcall(s.fn, debug.traceback)
	if not ok then
		check(false, s.name, "error: " .. tostring(wait))
		wait = 0.2
	end
	core.after(wait or 0.2, run, i + 1)
end

-- API phase -------------------------------------------------------------------

step("creation_validation", function()
	local p1 = P("P1")
	local ok1 = dbil.players.create_character(p1, "", "human")
	local ok2 = dbil.players.create_character(p1, "Yuki", "no_such_race")
	check(not ok1 and not ok2, "creation_rejects_invalid")
	check(dbil.players.create_character(p1, "Yuki", "human"), "create_human")
	check(dbil.players.create_character(P("P2"), "Kale", "saiyan"), "create_saiyan")
	return 1.0
end)

step("initial_state", function()
	for _, name in ipairs({ "P1", "P2" }) do
		local p = P(name)
		local d = dbil.stats.derived(p)
		check(dbil.players.is_ready(p), name .. "_ready")
		check(p:get_hp() == d.max_hp and p:get_properties().hp_max == d.max_hp, name .. "_hp_full",
			("%d/%d"):format(p:get_hp(), d.max_hp))
		check(math.abs(dbil.ki.get(p) - d.max_ki) < 0.01, name .. "_ki_full")
		local inv = p:get_inventory()
		check(inv:get_stack("main", 1):get_name() == "dbil_input:fists"
			and inv:get_stack("main", 2):get_name() == "dbil_input:flight"
			and inv:get_stack("main", 3):get_name() == "dbil_input:technique_1", name .. "_kit")
		check(dbil.techniques.knows(p, "ki_blast"), name .. "_knows_ki_blast")
		check(dbil.quests.is_active(p, "tutorial_ki"), name .. "_tutorial_started")
		log("INFO %s PL base=%d current=%d hp=%d ki=%d", name, dbil.power.get_base(p), dbil.power.get_current(p),
			d.max_hp, d.max_ki)
	end
	local b1, b2 = dbil.power.get_base(P("P1")), dbil.power.get_base(P("P2"))
	check(b1 > 0 and b2 > 0 and b2 > b1, "power_saiyan_higher", ("%d vs %d"):format(b1, b2))
end)

step("ki_api", function()
	local p = P("P1")
	dbil.ki.set(p, 50)
	local ok, cost = dbil.ki.try_spend(p, 20, "test")
	check(ok and cost < 20 and math.abs(dbil.ki.get(p) - (50 - cost)) < 0.01, "ki_spend_with_efficiency",
		("cost=%.2f"):format(cost))
	check(not dbil.ki.try_spend(p, 1000, "test"), "ki_cannot_overspend")
	local cur_low = dbil.power.get_current(p)
	dbil.ki.set(p, dbil.ki.get_max(p))
	check(dbil.power.get_current(p) > cur_low, "power_rises_with_ki")
end)

step("melee_hits_enemy", function()
	local p = P("P1")
	local spawn = dbil.world.get_spawn()
	clear_enemies(spawn)
	p:set_pos(vector.add(spawn, vector.new(0, 0, -6)))
	face(p, spawn)
	local pos = vector.add(spawn, vector.new(0, 0.2, -3.6))
	ctx.enemy = dbil.enemies.spawn("saibaman", pos)
	check(ctx.enemy ~= nil, "spawn_saibaman")
	-- Keep the AI still so the checks are deterministic (AI is tested later).
	ctx.enemy:get_luaentity()._stunned_until = dbil.util.now() + 30
	return 0.5
end)

step("melee_light_heavy", function()
	local p = P("P1")
	face(p, ctx.enemy:get_pos())
	local ent = ctx.enemy:get_luaentity()
	local hp0 = ent._hp
	dbil.input.trigger(p, "light_attack", {})
	local hp1 = ent._hp
	check(hp1 < hp0, "light_attack_damages", ("%d -> %d"):format(hp0, hp1))
	ctx.enemy_hp = hp1
	return 1.0
end)

step("heavy_attack", function()
	local p = P("P1")
	face(p, ctx.enemy:get_pos())
	local ent = ctx.enemy:get_luaentity()
	local before = ent._hp
	local pos0 = ctx.enemy:get_pos()
	dbil.input.trigger(p, "heavy_attack", {})
	check(ent._hp < before, "heavy_attack_damages", ("%d -> %d"):format(before, ent._hp))
	ctx.knock_from = pos0
	return 0.6
end)

step("knockback", function()
	local moved = vector.distance(ctx.knock_from, ctx.enemy:get_pos())
	check(moved > 0.8, "heavy_knockback_moves_enemy", ("%.2f nodes"):format(moved))
	return 1.5
end)

step("technique_projectile", function()
	local p = P("P1")
	face(p, ctx.enemy:get_pos())
	ctx.enemy_hp = ctx.enemy:get_luaentity()._hp
	dbil.ki.set(p, dbil.ki.get_max(p))
	local ki0 = dbil.ki.get(p)
	local ok = dbil.input.trigger(p, "use_technique", { slot = 1 })
	check(ok, "technique_fires")
	check(dbil.ki.get(p) < ki0, "technique_costs_ki")
	check(dbil.projectiles.active_count() >= 1, "projectile_exists")
	check(dbil.techniques.cooldown_remaining(p, "ki_blast") > 0, "technique_cooldown")
	check(not dbil.input.trigger(p, "use_technique", { slot = 1 }), "technique_blocked_by_cooldown")
	return 1.2
end)

step("projectile_hit", function()
	local ent = ctx.enemy:get_luaentity()
	check(ent and ent._hp < ctx.enemy_hp, "projectile_damages_enemy",
		ent and ("%d -> %d"):format(ctx.enemy_hp, ent._hp) or "enemy gone")
	check(dbil.projectiles.active_count() == 0, "projectile_removed_after_hit")
end)

step("kill_enemy_rewards", function()
	local p = P("P1")
	local char = dbil.players.get_character(p)
	ctx.xp0 = char.xp
	ctx.level0 = char.level
	local ent = ctx.enemy:get_luaentity()
	ent._invulnerable_until = 0
	-- Finish it through the damage pipeline (the AI may be moving around).
	for _ = 1, 40 do
		if not ent:dbil_is_alive() then
			break
		end
		dbil.combat.deal_damage({ attacker = p, target = ctx.enemy, amount = 30, kind = "melee", source = "test" })
	end
	check(not ent:dbil_is_alive(), "enemy_dies")
	return 1.2
end)

step("rewards_given", function()
	local p = P("P1")
	local char = dbil.players.get_character(p)
	check(char.level > ctx.level0 or char.xp > ctx.xp0, "kill_gives_xp", ("xp %.1f -> %.1f"):format(ctx.xp0, char.xp))
	check((char.stats.kills or 0) >= 1, "kill_counted")
	check(ctx.enemy:get_luaentity() == nil, "enemy_removed")
end)

step("level_up", function()
	local p = P("P1")
	local char = dbil.players.get_character(p)
	local str0 = char.attributes.strength
	local max0 = dbil.stats.derived(p).max_hp
	local level0 = char.level
	dbil.progression.add_xp(p, dbil.progression.xp_to_next(char.level) + 1, "test")
	check(char.level == level0 + 1, "level_up_by_xp")
	check(char.attributes.strength > str0, "level_up_grows_attributes")
	check(dbil.stats.derived(p).max_hp > max0 and p:get_hp() == dbil.stats.derived(p).max_hp, "level_up_restores_hp")
	dbil.progression.add_xp(p, 1e9, "test")
	check(char.level == dbil.config.progression.max_level, "level_cap", tostring(char.level))
	dbil.progression.set_level(p, 3)
end)

step("training", function()
	local p = P("P1")
	local char = dbil.players.get_character(p)
	local before = char.attributes.ki_control
	for _ = 1, 40 do
		dbil.events.emit("training", p, "charge_second", 1)
	end
	check(char.attributes.ki_control > before, "training_raises_attribute",
		("%.1f -> %.1f"):format(before, char.attributes.ki_control))
	local gained = char.training.gained.ki_control or 0
	for _ = 1, 400 do
		dbil.events.emit("training", p, "charge_second", 1)
	end
	check((char.training.gained.ki_control or 0) - gained <= 2, "training_rate_limited")
end)

step("flight_start", function()
	local p = P("P1")
	dbil.ki.set(p, dbil.ki.get_max(p))
	check(dbil.flight.start(p), "flight_starts")
	check(p:get_physics_override().gravity == 0, "flight_no_gravity")
	ctx.fly_ki = dbil.ki.get(p)
	ctx.fly_y = p:get_pos().y
	return 2.0
end)

step("flight_drain", function()
	local p = P("P1")
	check(dbil.flight.is_flying(p), "still_flying")
	check(dbil.ki.get(p) < ctx.fly_ki, "flight_drains_ki")
	check(p:get_pos().y > ctx.fly_y - 0.5, "flight_does_not_fall", ("%.2f -> %.2f"):format(ctx.fly_y, p:get_pos().y))
	dbil.ki.set(p, 0.05)
	return 1.5
end)

step("flight_runs_out", function()
	local p = P("P1")
	check(not dbil.flight.is_flying(p), "flight_stops_without_ki")
	check(p:get_physics_override().gravity == 1, "gravity_restored")
	dbil.resources.fill(p)
end)

step("kaioken", function()
	local p = P("P1")
	dbil.progression.set_level(p, 5)
	check(dbil.transformations.is_unlocked(p, "kaioken"), "kaioken_auto_unlock_at_5")
	check(p:get_inventory():get_stack("main", 7):get_name() == "dbil_transformations:transform", "transform_item_in_kit")
	ctx.pl_before = dbil.power.get_current(p)
	check(dbil.input.trigger(p, "transform_next"), "transform_starts")
	return 1.2
end)

step("kaioken_active", function()
	local p = P("P1")
	local form = dbil.transformations.get_active(p)
	check(form and form.id == "kaioken", "kaioken_active")
	local pl = dbil.power.get_current(p)
	check(pl > ctx.pl_before * 1.6, "kaioken_multiplies_power", ("%d -> %d"):format(ctx.pl_before, pl))
	check(not dbil.transformations.activate(P("P2"), "kaioken"), "saiyan_cannot_kaioken")
	return 2.0
end)

step("kaioken_revert", function()
	local p = P("P1")
	check(p:get_hp() < dbil.stats.derived(p).max_hp, "kaioken_strains_hp")
	dbil.input.trigger(p, "transform_revert")
	check(dbil.transformations.get_active(p) == nil, "transformation_reverts")
	check(dbil.power.get_current(p) < ctx.pl_before * 1.3, "power_back_to_normal")
	dbil.resources.fill(p)
end)

step("ai_attacks_player", function()
	local p2 = P("P2")
	local spawn = dbil.world.get_spawn()
	p2:set_pos(vector.add(spawn, vector.new(5, 0, 5)))
	ctx.p2_hp = p2:get_hp()
	ctx.ai_enemy = dbil.enemies.spawn("saibaman", vector.add(spawn, vector.new(7, 0.3, 5)))
	return 6.0
end)

step("ai_damage_dealt", function()
	local p2 = P("P2")
	check(p2:get_hp() < ctx.p2_hp, "enemy_ai_damages_player", ("%d -> %d"):format(ctx.p2_hp, p2:get_hp()))
	if ctx.ai_enemy:get_luaentity() then
		ctx.ai_enemy:remove()
	end
	dbil.resources.fill(p2)
end)

step("simultaneous_techniques", function()
	local p1, p2 = P("P1"), P("P2")
	local spawn = dbil.world.get_spawn()
	clear_enemies(spawn)
	ctx.target = dbil.enemies.spawn("saibaman", vector.add(spawn, vector.new(0, 0.3, 6)))
	local ent = ctx.target:get_luaentity()
	ent._stunned_until = dbil.util.now() + 30
	-- P1 kept level 50 attributes from the cap test: make the target sturdy
	-- so both projectiles land before it dies.
	ent._max_hp = 3000
	ent._hp = 3000
	p1:set_pos(vector.add(spawn, vector.new(-3, 0, 0)))
	p2:set_pos(vector.add(spawn, vector.new(3, 0, 0)))
	return 0.5
end)

step("simultaneous_fire", function()
	local p1, p2 = P("P1"), P("P2")
	face(p1, ctx.target:get_pos())
	face(p2, ctx.target:get_pos())
	ctx.target_hp = ctx.target:get_luaentity()._hp
	local a = dbil.input.trigger(p1, "use_technique", { slot = 1 })
	local b = dbil.input.trigger(p2, "use_technique", { slot = 1 })
	check(a and b, "both_players_fire")
	return 1.5
end)

step("shared_kill_rewards", function()
	local ent = ctx.target:get_luaentity()
	check(ent and ent._damage_by.P1 and ent._damage_by.P2, "both_players_credited")
	if not ent then
		return
	end
	ctx.p1_xp = dbil.players.get_character(P("P1")).xp
	ctx.p2_xp = dbil.players.get_character(P("P2")).xp
	ctx.p2_level = dbil.players.get_character(P("P2")).level
	for _ = 1, 200 do
		if not ent:dbil_is_alive() then break end
		dbil.combat.deal_damage({ attacker = P("P2"), target = ctx.target, amount = 30, kind = "melee", source = "test" })
	end
	check(not ent:dbil_is_alive(), "shared_target_dies")
	return 1.0
end)

step("shared_kill_check", function()
	local c1, c2 = dbil.players.get_character(P("P1")), dbil.players.get_character(P("P2"))
	check(c1.xp > ctx.p1_xp or c1.level > 5, "p1_shares_xp")
	check(c2.xp > ctx.p2_xp or c2.level > ctx.p2_level, "p2_gets_xp")
end)

step("pvp_off_by_default", function()
	local p1, p2 = P("P1"), P("P2")
	local hp = p2:get_hp()
	local dmg = dbil.combat.deal_damage({ attacker = p1, target = p2, amount = 20, kind = "melee" })
	check(dmg == 0 and p2:get_hp() == hp, "pvp_disabled")
	dbil.config.combat.pvp = true
	dmg = dbil.combat.deal_damage({ attacker = p1, target = p2, amount = 20, kind = "melee" })
	check(dmg > 0 and p2:get_hp() < hp, "pvp_toggle_works")
	dbil.config.combat.pvp = false
	dbil.resources.fill(p2)
end)

step("guard_reduces_damage", function()
	local p2 = P("P2")
	local state = dbil.players.get_state(p2)
	local enemy = dbil.enemies.spawn("saibaman", front_of(p2, 2))
	ctx.guard_enemy = enemy
	local hp = p2:get_hp()
	local open = dbil.combat.deal_damage({ attacker = enemy, target = p2, amount = 20, kind = "melee" })
	-- Simulate holding the block key.
	state.guard.active = true
	face(p2, enemy:get_pos())
	local blocked, result = dbil.combat.deal_damage({ attacker = enemy, target = p2, amount = 20, kind = "melee" })
	state.guard.active = false
	check(result == "blocked" and blocked < open, "guard_blocks", ("%d vs %d"):format(blocked, open))
	enemy:remove()
	dbil.resources.fill(p2)
end)

step("death_and_respawn", function()
	local p2 = P("P2")
	ctx.deaths = dbil.players.get_character(p2).stats.deaths or 0
	dbil.combat.deal_damage({ target = p2, amount = 100000, kind = "true" })
	check(p2:get_hp() == 0, "player_can_die")
	return 0.5
end)

step("respawn", function()
	local p2 = P("P2")
	p2:respawn()
	return 0.5
end)

step("respawn_check", function()
	local p2 = P("P2")
	local spawn = dbil.world.get_spawn()
	check(p2:get_hp() > 0, "respawned_alive")
	check(vector.distance(p2:get_pos(), spawn) < 3, "respawn_at_arena")
	check(dbil.players.get_character(p2).stats.deaths == ctx.deaths + 1, "death_counted")
	check(math.abs(dbil.ki.get(p2) - dbil.ki.get_max(p2)) < 0.01, "respawn_refills_ki")
end)

step("energy_wave_cast_time", function()
	local p1 = P("P1")
	dbil.resources.fill(p1)
	check(dbil.techniques.knows(p1, "energy_wave"), "energy_wave_learned_by_level")
	local slot
	for i, id in ipairs(dbil.players.get_character(p1).techniques.equipped) do
		if id == "energy_wave" then slot = i end
	end
	check(slot ~= nil, "energy_wave_auto_equipped")
	ctx.wave_slot = slot
	check(dbil.input.trigger(p1, "use_technique", { slot = slot or 2 }), "energy_wave_starts_casting")
	check(dbil.techniques.is_casting(p1), "casting_state")
	return 1.0
end)

step("energy_wave_released", function()
	local p1 = P("P1")
	check(not dbil.techniques.is_casting(p1), "cast_finished_after_min_time")
	check(dbil.techniques.cooldown_remaining(p1, "energy_wave") > 0, "energy_wave_on_cooldown")
	return 0.5
end)

step("ranged_vs_flyer_setup", function()
	local p2 = P("P2")
	local spawn = dbil.world.get_spawn()
	clear_enemies(spawn)
	dbil.resources.fill(p2)
	-- Only the flying player is in range (the AI attacks the nearest target).
	P("P1"):set_pos(vector.add(spawn, vector.new(0, 0, -120)))
	p2:set_pos(vector.add(spawn, vector.new(0, 7, 0)))
	dbil.flight.start(p2)
	ctx.flyer_hp = p2:get_hp()
	ctx.shooter = dbil.enemies.spawn("saibaman", vector.add(spawn, vector.new(0, 0.3, 10)))
	return 9.0
end)

step("ranged_vs_flyer", function()
	local p2 = P("P2")
	check(p2:get_hp() < ctx.flyer_hp, "saibaman_shoots_flying_player", ("%d -> %d"):format(ctx.flyer_hp, p2:get_hp()))
	if ctx.shooter:get_luaentity() then
		ctx.shooter:remove()
	end
	dbil.flight.stop(p2, "test")
	dbil.resources.fill(p2)
	P("P1"):set_pos(dbil.world.get_spawn())
	return 1.0
end)

step("persistence_roundtrip", function()
	local p1 = P("P1")
	dbil.players.save(p1)
	local loaded = dbil.accounts.load("P1")
	local char = dbil.model.active_character(loaded)
	local live = dbil.players.get_character(p1)
	check(char and char.level == live.level and char.name == live.name
		and math.abs(char.attributes.strength - live.attributes.strength) < 1e-6, "save_load_roundtrip")
	check(loaded.format == dbil.model.FORMAT, "save_has_format_version")
end)

step("persistence_corruption", function()
	-- Corrupted data must be repaired, never crash.
	local repaired, issues = dbil.model.sanitize_account({
		format = 1, active = 1,
		characters = { [1] = { name = 5, level = -3, attributes = { strength = "x" }, race = "human" } },
	})
	local c = repaired.characters[1]
	check(type(c.name) == "string" and c.level == 1 and c.attributes.strength == 10 and #issues >= 3,
		"corrupt_data_repaired", #issues .. " issues")
	dbil.storage.set_raw("acc:Ghost", "not lua at all {{{")
	local acc, status = dbil.accounts.load("Ghost")
	check(acc ~= nil and status == "new", "unreadable_save_handled", status)
end)

step("enter_input_phase", function()
	local p1 = P("P1")
	local spawn = dbil.world.get_spawn()
	clear_enemies(spawn)
	dbil.flight.stop(p1, "test")
	p1:set_pos(spawn)
	p1:set_look_horizontal(0)
	p1:set_look_vertical(0.1)
	dbil.resources.fill(p1)
	dbil.ki.set(p1, dbil.ki.get_max(p1) * 0.3)
	p1:get_inventory():set_stack("main", 9, ItemStack("dbil_items:senzu 2"))
	-- Snapshot for the reconnect test.
	dbil.players.save(p1)
	dbil.storage.save_table(snapshot_key("P1"), snapshot(p1))
	log("PHASE input")
	ctx.track_pos = true
end)

-- Position log during the input phase (lets the harness check flight height).
dbil.scheduler.every("test_pos_log", 0.5, function()
	if ctx.track_pos then
		local p1 = P("P1")
		if p1 then
			local pos = p1:get_pos()
			log("POS P1 %.2f %.2f %.2f ki=%.1f flying=%s", pos.x, pos.y, pos.z, dbil.ki.get(p1),
				tostring(dbil.flight.is_flying(p1)))
		end
	end
end)

-- Start / reconnect handling ---------------------------------------------------

local started = false

core.register_on_joinplayer(function(player)
	local name = player:get_player_name()
	core.after(2, function()
		local p = P(name)
		if not p then
			return
		end
		local saved = dbil.storage.load_table(snapshot_key(name))
		if saved and dbil.players.is_ready(p) then
			-- Rejoin after quit / server restart: data must be identical.
			local snap = snapshot(p)
			local ok, why = same(saved, snap)
			check(ok, "persist_" .. name, why or ("level=%d xp=%d"):format(snap.level, snap.xp))
			log("PHASE persist_checked %s", name)
			return
		end
		if not started and P("P1") and P("P2") and dbil.world.get_spawn() then
			started = true
			log("PHASE api start")
			run(1)
		end
	end)
end)

-- Leaving (quit or shutdown): remember what the character looked like.
dbil.events.on("character_leaving", function(player)
	if started then
		dbil.storage.save_table(snapshot_key(player:get_player_name()), snapshot(player))
	end
end)

core.register_on_shutdown(function()
	log("SHUTDOWN results pass=%d fail=%d", results.pass, results.fail)
end)
