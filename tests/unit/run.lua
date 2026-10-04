-- Unit tests for pure game logic. Run from the repository root:
--   luajit tests/unit/run.lua
-- Loads every game module against a mocked `core` (which also validates all
-- content definitions) and checks formulas, schemas, config, events, data
-- model, migrations and persistence.

package.path = "tests/unit/?.lua;" .. package.path
local mock = require("mock_core")

mock.settings["dbil.flight.speed"] = "3.5"
mock.settings["dbil.combat.pvp"] = "nonsense"

local MODS = {
	"dbil_core", "dbil_character", "dbil_races", "dbil_input", "dbil_ki", "dbil_movement",
	"dbil_combat", "dbil_progression", "dbil_techniques", "dbil_items", "dbil_enemies",
	"dbil_world", "dbil_ui", "dbil_transformations", "dbil_quests", "dbil_debug",
}

local passed, failed = 0, 0
local function test(name, fn)
	local ok, err = xpcall(fn, debug.traceback)
	if ok then
		passed = passed + 1
		print("ok   " .. name)
	else
		failed = failed + 1
		print("FAIL " .. name .. "\n     " .. tostring(err))
	end
end

local function eq(a, b, msg)
	if a ~= b then
		error((msg or "values differ") .. ": expected " .. tostring(b) .. ", got " .. tostring(a), 2)
	end
end

local function truthy(v, msg)
	if not v then
		error(msg or "expected truthy value", 2)
	end
end

local function near(a, b, eps, msg)
	if math.abs(a - b) > (eps or 1e-6) then
		error((msg or "not near") .. ": " .. tostring(a) .. " vs " .. tostring(b), 2)
	end
end

test("all modules load and content definitions validate", function()
	for _, mod in ipairs(MODS) do
		mock.load_mod(mod)
	end
	truthy(dbil.races.get("human") and dbil.races.get("saiyan"))
	truthy(dbil.techniques.get("ki_blast") and dbil.techniques.get("energy_wave"))
	truthy(dbil.enemies.get("saibaman") and dbil.enemies.get("training_dummy"))
	truthy(dbil.transformations.get("kaioken") and dbil.transformations.get("super_saiyan"))
	truthy(dbil.quests.get("tutorial_ki"))
end)

-- Config ------------------------------------------------------------------------

test("config overrides from settings", function()
	eq(dbil.config.flight.speed, 3.5, "numeric override")
	eq(dbil.config.combat.pvp, false, "invalid boolean ignored")
end)

-- Util --------------------------------------------------------------------------

test("format_int", function()
	eq(dbil.util.format_int(1234567), "1.234.567")
	eq(dbil.util.format_int(0), "0")
	eq(dbil.util.format_int(-1500), "-1.500")
	eq(dbil.util.format_int(999), "999")
end)

test("clean_name strips formspec characters", function()
	eq(dbil.util.clean_name("  Go[ku];,  \n"), "Goku")
	eq(dbil.util.clean_name("A   B"), "A B")
	eq(#dbil.util.clean_name(string.rep("x", 50), 20), 20)
end)

-- Schema ------------------------------------------------------------------------

test("schema sanitize repairs data", function()
	local S = dbil.schema
	local node = { type = "table", fields = {
		n = S.num(5, 0, 10), s = S.str("x", 3), b = S.bool(true),
		l = { type = "list", item = S.int(0, 0, 9), max_items = 2 },
	} }
	local out, issues = S.sanitize({ n = 99, s = "abcdef", b = "no", l = { 1, "x", 3, 4 } }, node)
	eq(out.n, 10)
	eq(out.s, "abc")
	eq(out.b, true)
	eq(#out.l, 2)
	truthy(#issues >= 4)
end)

test("schema check rejects bad definitions and keeps callbacks", function()
	local S = dbil.schema
	local node = { type = "table", fields = { name = { type = "string" }, fn = { type = "function" } } }
	local ok = pcall(S.check, { name = 3, fn = print }, node, "x")
	eq(ok, false)
	local def = S.check({ name = "a", fn = print }, node, "x")
	eq(def.fn, print)
end)

-- Events --------------------------------------------------------------------------

test("events run by priority and survive failing listeners", function()
	local order = {}
	dbil.events.on("t_evt", function() order[#order + 1] = "b" end, 20)
	dbil.events.on("t_evt", function() error("boom") end, 15)
	dbil.events.on("t_evt", function() order[#order + 1] = "a" end, 10)
	dbil.events.emit("t_evt")
	eq(table.concat(order), "ab")
	dbil.events.on("t_ask", function() return false end)
	eq(dbil.events.ask("t_ask"), false)
end)

test("registry rejects duplicates and bad ids", function()
	local reg = dbil.registry.new("thing")
	reg:register("one", {})
	eq(pcall(reg.register, reg, "one", {}), false)
	eq(pcall(reg.register, reg, "bad id!", {}), false)
end)

-- Data model / persistence ------------------------------------------------------

test("new character uses race attributes", function()
	local c = dbil.model.new_character("tester", "Kale", "saiyan")
	eq(c.race, "saiyan")
	eq(c.level, 1)
	eq(c.attributes.strength, dbil.races.get("saiyan").attributes.strength)
	eq(c.resources.hp, -1)
end)

test("corrupted account is repaired", function()
	local acc, issues = dbil.model.sanitize_account({
		format = 1,
		characters = { [1] = { name = 5, level = -3, race = "unknown_race", attributes = { strength = "x" } } },
	})
	local c = acc.characters[1]
	eq(type(c.name), "string")
	eq(c.level, 1)
	eq(c.attributes.strength, 10)
	eq(c.flags.missing_race, "unknown_race")
	eq(c.race, "human")
	truthy(#issues >= 4)
end)

test("migrations upgrade old formats and refuse newer ones", function()
	local FORMAT = dbil.model.FORMAT
	dbil.model.FORMAT = FORMAT + 1
	dbil.model.migrations[FORMAT] = function(acc) acc.migrated = true return acc end
	local acc = dbil.model.migrate({ format = FORMAT })
	eq(acc.format, FORMAT + 1)
	eq(acc.migrated, true)
	dbil.model.FORMAT = FORMAT
	dbil.model.migrations[FORMAT] = nil
	local none, err = dbil.model.migrate({ format = FORMAT + 5 })
	eq(none, nil)
	truthy(err)
end)

test("accounts save/load roundtrip and backup recovery", function()
	local acc = dbil.model.new_account()
	acc.characters[1] = dbil.model.new_character("rt", "Yuki", "human")
	acc.characters[1].xp = 42.5
	dbil.accounts.save("rt", acc)
	dbil.accounts.backup("rt", acc)
	local loaded, status = dbil.accounts.load("rt")
	eq(status, "loaded")
	eq(loaded.characters[1].name, "Yuki")
	eq(loaded.characters[1].xp, 42.5)
	mock.storage["acc:rt"] = "return {{{ broken"
	local restored, status2 = dbil.accounts.load("rt")
	eq(status2, "restored_backup")
	eq(restored.characters[1].name, "Yuki")
	local fresh, status3 = dbil.accounts.load("nobody")
	eq(status3, "new")
	eq(next(fresh.characters), nil)
end)

-- Formulas ----------------------------------------------------------------------

local function attrs(v)
	return { strength = v, resistance = v, speed = v, ki_control = v, ki_capacity = v }
end

test("derived stats grow with attributes and respect caps", function()
	local low = dbil.stats.compute_derived(attrs(10), 1)
	local high = dbil.stats.compute_derived(attrs(100), 1)
	truthy(high.max_hp > low.max_hp and high.max_ki > low.max_ki and high.defense > low.defense)
	local huge = dbil.stats.compute_derived(attrs(100000), 1)
	near(huge.defense, dbil.config.stats.defense_max)
	near(huge.ki_cost_mult, dbil.config.stats.ki_efficiency_min)
	near(huge.move_speed, dbil.config.stats.speed_mult_max)
end)

test("power level: multi-factor, race and mastery", function()
	local p10 = dbil.power.compute_base(attrs(10), 1, 0)
	local p20 = dbil.power.compute_base(attrs(20), 1, 0)
	truthy(p20 > p10 * 2, "power grows faster than linear")
	truthy(dbil.power.compute_base(attrs(10), 1.1, 0) > p10, "race multiplier")
	local capped = dbil.power.compute_base(attrs(10), 1, 100000)
	near(capped, math.floor(p10 * (1 + dbil.config.power.mastery_bonus_max) + 0.5), 2, "mastery bonus capped")
	eq(dbil.power.format(math.huge), "???")
end)

test("damage formula uses multipliers, power ratio and defense", function()
	local att = { melee_mult = 1.5, ki_mult = 2, defense = 0 }
	local def = { melee_mult = 1, ki_mult = 1, defense = 0.25 }
	near(dbil.combat.compute_damage(10, "melee", att, 100, def, 100), 10 * 1.5 * 0.75)
	near(dbil.combat.compute_damage(10, "ki", att, 100, def, 100), 10 * 2 * 0.75)
	near(dbil.combat.compute_damage(10, "true", att, 100, def, 100), 10)
	near(dbil.combat.power_ratio_factor(1e9, 1), dbil.config.combat.power_ratio_max)
	near(dbil.combat.power_ratio_factor(1, 1e9), dbil.config.combat.power_ratio_min)
end)

test("experience curve and kill rewards are bounded", function()
	local prev = 0
	for level = 1, 30 do
		local need = dbil.progression.xp_to_next(level)
		truthy(need > prev)
		prev = need
	end
	near(dbil.progression.kill_xp_mult(1, 1e9), dbil.config.progression.kill_xp_min_mult)
	near(dbil.progression.kill_xp_mult(1e9, 1), dbil.config.progression.kill_xp_max_mult)
	truthy(dbil.progression.training_cost(10) > dbil.progression.training_cost(0))
end)

test("technique numbers include mastery with floors", function()
	local def = dbil.techniques.get("ki_blast")
	local base = dbil.techniques.compute(def, 0, 1)
	local mastered = dbil.techniques.compute(def, def.mastery.max_level, 1)
	truthy(mastered.damage > base.damage and mastered.cost < base.cost and mastered.cooldown < base.cooldown)
	local wave = dbil.techniques.get("energy_wave")
	local charged = dbil.techniques.compute(wave, 0, wave.max_charge_mult)
	near(charged.damage, wave.damage * wave.max_charge_mult)
	truthy(charged.size > wave.size)
end)

test("technique requirements", function()
	local c = dbil.model.new_character("t", "T", "human")
	eq(dbil.techniques.meets_requirements(c, dbil.techniques.get("ki_blast")), true)
	local ok, reason = dbil.techniques.meets_requirements(c, dbil.techniques.get("energy_wave"))
	eq(ok, false)
	truthy(reason)
	c.level = 3
	eq(dbil.techniques.meets_requirements(c, dbil.techniques.get("energy_wave")), true)
end)

test("transformation requirements are data driven", function()
	local human = dbil.model.new_character("t", "H", "human")
	local saiyan = dbil.model.new_character("t", "S", "saiyan")
	human.level, saiyan.level = 30, 30
	eq(dbil.transformations.meets_requirements(human, dbil.transformations.get("kaioken")), true)
	eq((dbil.transformations.meets_requirements(saiyan, dbil.transformations.get("kaioken"))), false)
	eq((dbil.transformations.meets_requirements(saiyan, dbil.transformations.get("super_saiyan"))), false)
	saiyan.flags.ssj_awakened = true
	eq(dbil.transformations.meets_requirements(saiyan, dbil.transformations.get("super_saiyan")), true)
end)

test("projectile segment distance", function()
	local d2, s = dbil.projectiles.segment_distance_sq(
		vector.new(0, 1, -5), vector.new(0, 1, 5), vector.new(0.5, 0, 0), vector.new(0.5, 2, 0))
	near(d2, 0.25)
	near(s, 0.5)
end)

print(("\n%d passed, %d failed"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
