-- Persistence backend: serialized Lua tables in the core mod storage.
--
-- Mod storage is committed to disk by the engine every
-- `server_map_save_interval` seconds and on shutdown, so writes here are
-- cheap; higher level code decides *when* to write (dirty flags, events).

local storage = {}
dbil.storage = storage

local backend = core.get_mod_storage()

function storage.get_raw(key)
	local value = backend:get_string(key)
	if value == "" then
		return nil
	end
	return value
end

function storage.set_raw(key, value)
	backend:set_string(key, value or "")
end

--- Loads a table stored with storage.save_table.
-- Returns table, or nil plus an error message ("missing" when absent).
function storage.load_table(key)
	local raw = storage.get_raw(key)
	if not raw then
		return nil, "missing"
	end
	local data = core.deserialize(raw, true)
	if type(data) ~= "table" then
		return nil, "corrupt data"
	end
	return data
end

function storage.save_table(key, data)
	local raw = core.serialize(data)
	if not raw or raw == "" then
		dbil.log.error("could not serialize data for key %s", key)
		return false
	end
	backend:set_string(key, raw)
	return true
end

function storage.delete(key)
	backend:set_string(key, "")
end

function storage.keys()
	return backend:get_keys()
end
