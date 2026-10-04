-- Declarative data schemas.
--
-- The same schema description is used in two ways:
--   * schema.sanitize(): repairs untrusted data (save files). Wrong or missing
--     values are replaced by defaults and every repair is reported.
--   * schema.check(): validates content definitions at load time (races,
--     techniques, enemies...). Any problem raises an error with a clear path,
--     so broken content fails fast instead of misbehaving in game.
--
-- Schema node fields:
--   type      "number" | "string" | "boolean" | "table" | "map" | "list" | "any" | "function"
--   default   value used when missing/invalid (tables are deep-copied)
--   optional  nil is accepted and left as nil
--   min, max, integer           (number)
--   max_len, enum               (string)
--   fields, extra="keep"|"drop" (table; default extra = "keep")
--   key="string"|"number", value=<schema>, max_entries  (map)
--   item=<schema>, max_items    (list)

local schema = {}
dbil.schema = schema

local deep_copy = dbil.util.deep_copy

-- Content definitions may carry callbacks; save data may not.
local allow_functions = false

local function is_data(v)
	local t = type(v)
	if t == "function" then
		return allow_functions
	end
	return t ~= "userdata" and t ~= "thread"
end

local function default_of(node)
	if node.default ~= nil then
		return deep_copy(node.default)
	end
	if node.type == "table" then
		return schema.sanitize({}, node)
	end
	if node.type == "map" or node.type == "list" then
		return {}
	end
	return nil
end

local function report(issues, path, msg)
	if issues then
		issues[#issues + 1] = (path ~= "" and path or "<root>") .. ": " .. msg
	end
end

local sanitize

local function sanitize_table(value, node, path, issues)
	local out = {}
	local fields = node.fields or {}
	for key, sub in pairs(fields) do
		out[key] = sanitize(value[key], sub, path .. "." .. key, issues)
	end
	if node.extra ~= "drop" then
		for key, v in pairs(value) do
			if fields[key] == nil and is_data(v) then
				out[key] = type(v) == "table" and deep_copy(v) or v
			end
		end
	end
	return out
end

local function sanitize_map(value, node, path, issues)
	local out, n = {}, 0
	local key_type = node.key or "string"
	for key, v in pairs(value) do
		if type(key) ~= key_type then
			report(issues, path, "dropped key of wrong type: " .. tostring(key))
		elseif node.max_entries and n >= node.max_entries then
			report(issues, path, "too many entries, extra dropped")
			break
		else
			local clean = sanitize(v, node.value or { type = "any" }, path .. "[" .. tostring(key) .. "]", issues)
			if clean ~= nil then
				out[key] = clean
				n = n + 1
			end
		end
	end
	return out
end

local function sanitize_list(value, node, path, issues)
	local out = {}
	for i, v in ipairs(value) do
		if node.max_items and #out >= node.max_items then
			report(issues, path, "too many items, extra dropped")
			break
		end
		local clean = sanitize(v, node.item or { type = "any" }, path .. "[" .. i .. "]", issues)
		if clean ~= nil then
			out[#out + 1] = clean
		end
	end
	return out
end

sanitize = function(value, node, path, issues)
	path = path or ""
	if value == nil then
		if node.optional then
			return nil
		end
		local d = default_of(node)
		if d == nil and node.type ~= "any" then
			report(issues, path, "missing required value")
		end
		return d
	end

	local t = node.type
	if t == "any" then
		if not is_data(value) then
			report(issues, path, "unserializable value dropped")
			return default_of(node)
		end
		return value
	end

	local vt = type(value)
	local expected = (t == "map" or t == "list") and "table" or t
	if vt ~= expected then
		report(issues, path, ("expected %s, got %s"):format(t, vt))
		return default_of(node)
	end

	if t == "number" then
		if value ~= value or value == math.huge or value == -math.huge then
			report(issues, path, "non-finite number")
			return default_of(node)
		end
		if node.integer then
			value = math.floor(value + 0.5)
		end
		if node.min and value < node.min then
			report(issues, path, ("below minimum %s"):format(node.min))
			value = node.min
		elseif node.max and value > node.max then
			report(issues, path, ("above maximum %s"):format(node.max))
			value = node.max
		end
		return value
	elseif t == "string" then
		if node.max_len and #value > node.max_len then
			report(issues, path, "string too long, truncated")
			value = value:sub(1, node.max_len)
		end
		if node.enum and not dbil.util.contains(node.enum, value) then
			report(issues, path, "invalid value '" .. value .. "'")
			return default_of(node)
		end
		return value
	elseif t == "table" then
		return sanitize_table(value, node, path, issues)
	elseif t == "map" then
		return sanitize_map(value, node, path, issues)
	elseif t == "list" then
		return sanitize_list(value, node, path, issues)
	end
	return value
end

--- Repairs `value` against `node`. Returns the clean copy and a list of issues.
function schema.sanitize(value, node, path)
	local issues = {}
	local out = sanitize(value, node, path or "", issues)
	return out, issues
end

--- Validates a content definition. Raises an error listing every problem.
-- Returns the definition with defaults applied (a new table; functions kept).
function schema.check(def, node, context)
	if type(def) ~= "table" then
		error(("%s: definition must be a table"):format(context), 2)
	end
	local issues = {}
	allow_functions = true
	local ok, out = pcall(sanitize, def, node, "", issues)
	allow_functions = false
	if not ok then
		error(out, 0)
	end
	if #issues > 0 then
		error(("%s: invalid definition:\n  %s"):format(context, table.concat(issues, "\n  ")), 2)
	end
	return out
end

-- Shorthand constructors keep schema declarations compact.
function schema.num(default, min, max, extra)
	local n = { type = "number", default = default, min = min, max = max }
	if extra then
		for k, v in pairs(extra) do n[k] = v end
	end
	return n
end

function schema.int(default, min, max)
	return { type = "number", default = default, min = min, max = max, integer = true }
end

function schema.str(default, max_len, enum)
	return { type = "string", default = default, max_len = max_len, enum = enum }
end

function schema.bool(default)
	return { type = "boolean", default = default }
end

function schema.opt(node)
	local copy = {}
	for k, v in pairs(node) do copy[k] = v end
	copy.optional = true
	copy.default = nil
	return copy
end
