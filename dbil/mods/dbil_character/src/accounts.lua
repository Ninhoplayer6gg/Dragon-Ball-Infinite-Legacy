-- Loading and saving accounts (all characters of one player name).
--
-- Storage keys:
--   acc:<name>      current data
--   acc:<name>:bak  last good copy taken when the player joined
-- On load the data is migrated to the current format and sanitized; if the
-- main copy is unreadable the backup is used instead.

local accounts = {}
dbil.accounts = accounts

local model = dbil.model

local function key(name)
	return "acc:" .. name
end

local function backup_key(name)
	return "acc:" .. name .. ":bak"
end

local function decode(raw_table, label)
	local acc, err = model.migrate(raw_table)
	if not acc then
		return nil, err
	end
	local clean, issues = model.sanitize_account(acc)
	for _, issue in ipairs(issues) do
		dbil.log.warn("%s: repaired %s", label, issue)
	end
	return clean
end

--- Loads an account. Returns account (never nil) and a status string:
-- "new", "loaded", "restored_backup".
function accounts.load(name)
	local raw, err = dbil.storage.load_table(key(name))
	if raw then
		local acc, derr = decode(raw, "account " .. name)
		if acc then
			return acc, "loaded"
		end
		err = derr
	end
	if err ~= "missing" then
		dbil.log.error("account %s could not be loaded (%s), trying backup", name, tostring(err))
		local braw = dbil.storage.load_table(backup_key(name))
		if braw then
			local acc = decode(braw, "backup " .. name)
			if acc then
				dbil.log.warn("account %s restored from backup", name)
				return acc, "restored_backup"
			end
		end
		dbil.log.error("account %s: no usable data, starting fresh", name)
		-- Keep the unreadable data aside for manual recovery.
		local broken = dbil.storage.get_raw(key(name))
		if broken then
			dbil.storage.set_raw(key(name) .. ":broken:" .. os.time(), broken)
		end
	end
	return model.new_account(), "new"
end

function accounts.save(name, acc)
	acc.format = model.FORMAT
	return dbil.storage.save_table(key(name), acc)
end

function accounts.backup(name, acc)
	return dbil.storage.save_table(backup_key(name), acc)
end

function accounts.exists(name)
	return dbil.storage.get_raw(key(name)) ~= nil
end

function accounts.delete(name)
	dbil.storage.delete(key(name))
end
