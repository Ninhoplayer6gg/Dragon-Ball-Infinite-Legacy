-- Dragon Ball: Infinite Legacy — core module.
-- Creates the global `dbil` namespace shared by every other module.

dbil = {
	version = "0.1.0",
}

--- Runs a Lua file relative to the mod that is currently loading.
-- Every dbil mod uses this instead of repeating get_modpath boilerplate.
function dbil.include(relpath)
	local modname = core.get_current_modname()
	assert(modname, "dbil.include can only be used at load time")
	return dofile(core.get_modpath(modname) .. "/" .. relpath)
end

dbil.include("src/log.lua")
dbil.include("src/util.lua")
dbil.include("src/schema.lua")
dbil.include("src/config.lua")
dbil.include("src/events.lua")
dbil.include("src/scheduler.lua")
dbil.include("src/storage.lua")
dbil.include("src/registry.lua")
dbil.include("src/fx.lua")

dbil.log.info("core %s loaded", dbil.version)
