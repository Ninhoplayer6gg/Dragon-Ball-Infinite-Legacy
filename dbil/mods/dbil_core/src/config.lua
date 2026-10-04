-- Central gameplay configuration.
--
-- Every tunable number lives in dbil_core/config/<section>.lua, loaded into
-- dbil.config.<section>. Any leaf value can be overridden by the server owner
-- in minetest.conf using the dotted path, e.g.:
--   dbil.flight.drain_per_second = 1.5
--   dbil.combat.pvp = true

local config = {}
dbil.config = config

local modpath = core.get_modpath(core.get_current_modname())
local config_dir = modpath .. "/config"

local function parse_override(raw, current)
	local t = type(current)
	if t == "number" then
		return tonumber(raw)
	elseif t == "boolean" then
		if raw == "true" or raw == "1" then return true end
		if raw == "false" or raw == "0" then return false end
		return nil
	elseif t == "string" then
		return raw
	end
	return nil
end

local overrides_applied = {}

local function apply_overrides(tbl, path)
	for key, value in pairs(tbl) do
		if type(key) == "string" then
			local full = path .. "." .. key
			if type(value) == "table" then
				apply_overrides(value, full)
			else
				local raw = core.settings:get(full)
				if raw ~= nil then
					local parsed = parse_override(raw, value)
					if parsed ~= nil then
						tbl[key] = parsed
						overrides_applied[#overrides_applied + 1] = full .. " = " .. tostring(parsed)
					else
						dbil.log.warn("ignoring invalid setting %s = %s", full, raw)
					end
				end
			end
		end
	end
end

local files = core.get_dir_list(config_dir, false)
table.sort(files)
for _, file in ipairs(files) do
	local section = file:match("^([%w_]+)%.lua$")
	if section then
		local data = dofile(config_dir .. "/" .. file)
		assert(type(data) == "table", "config/" .. file .. " must return a table")
		config[section] = data
	end
end

apply_overrides(config, "dbil")
for _, line in ipairs(overrides_applied) do
	dbil.log.info("config override: %s", line)
end

--- Lets other mods add their own config section with the same override rules.
function config.register_section(name, data)
	assert(config[name] == nil, "config section already exists: " .. name)
	config[name] = data
	apply_overrides(data, "dbil." .. name)
	return data
end
