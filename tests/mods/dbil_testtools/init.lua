-- Test automation helpers. Loaded only in test worlds (worldmods).
-- Behaviour is selected with the setting dbil_test.scenario.

local scenario = core.settings:get("dbil_test.scenario") or ""
local modpath = core.get_modpath(core.get_current_modname())

dbil.log.info("testtools loaded, scenario '%s'", scenario)

if scenario ~= "" then
	dofile(modpath .. "/scenarios/" .. scenario .. ".lua")
end
