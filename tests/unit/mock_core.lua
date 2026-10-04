-- Minimal stand-in for the Luanti `core` API so game modules can be loaded
-- and their pure logic tested with plain LuaJIT. Registration functions are
-- recorded, not executed.

local mock = { registered = {}, settings = {}, storage = {}, log_lines = {} }
local GAME = arg and arg[1] or "dbil"

local current_mod = nil
local t0 = os.clock()

local function vec(x, y, z)
	return setmetatable({ x = x, y = y, z = z }, mock.vector_mt)
end

mock.vector_mt = {}
vector = {
	new = function(x, y, z) if type(x) == "table" then return vec(x.x, x.y, x.z) end return vec(x or 0, y or 0, z or 0) end,
	zero = function() return vec(0, 0, 0) end,
	copy = function(v) return vec(v.x, v.y, v.z) end,
	add = function(a, b) if type(b) == "number" then return vec(a.x + b, a.y + b, a.z + b) end return vec(a.x + b.x, a.y + b.y, a.z + b.z) end,
	subtract = function(a, b) if type(b) == "number" then return vec(a.x - b, a.y - b, a.z - b) end return vec(a.x - b.x, a.y - b.y, a.z - b.z) end,
	multiply = function(a, s) return vec(a.x * s, a.y * s, a.z * s) end,
	divide = function(a, s) return vec(a.x / s, a.y / s, a.z / s) end,
	dot = function(a, b) return a.x * b.x + a.y * b.y + a.z * b.z end,
	length = function(a) return math.sqrt(a.x * a.x + a.y * a.y + a.z * a.z) end,
	distance = function(a, b) return vector.length(vector.subtract(a, b)) end,
	normalize = function(a) local l = vector.length(a) if l == 0 then return vec(0, 0, 0) end return vector.divide(a, l) end,
	offset = function(a, x, y, z) return vec(a.x + x, a.y + y, a.z + z) end,
}

-- Tiny serializer compatible with what the game stores (plain data).
local function ser(v, out)
	local t = type(v)
	if t == "table" then
		out[#out + 1] = "{"
		for k, val in pairs(v) do
			out[#out + 1] = "["
			ser(k, out)
			out[#out + 1] = "]="
			ser(val, out)
			out[#out + 1] = ","
		end
		out[#out + 1] = "}"
	elseif t == "string" then
		out[#out + 1] = string.format("%q", v)
	elseif t == "number" then
		out[#out + 1] = string.format("%.17g", v)
	elseif t == "boolean" or t == "nil" then
		out[#out + 1] = tostring(v)
	else
		error("cannot serialize " .. t)
	end
end

local storage_obj = {
	get_string = function(_, k) return mock.storage[k] or "" end,
	set_string = function(_, k, v) if v == "" then mock.storage[k] = nil else mock.storage[k] = v end end,
	get_keys = function() local keys = {} for k in pairs(mock.storage) do keys[#keys + 1] = k end return keys end,
}

core = setmetatable({
	log = function(level, msg) mock.log_lines[#mock.log_lines + 1] = level .. ": " .. msg end,
	get_us_time = function() return math.floor((os.clock() - t0) * 1e6) end,
	get_current_modname = function() return current_mod end,
	get_modpath = function(name) return GAME .. "/mods/" .. name end,
	get_dir_list = function(path)
		local files = {}
		local p = io.popen('ls "' .. path .. '"')
		for f in p:lines() do files[#files + 1] = f end
		p:close()
		return files
	end,
	settings = { get = function(_, k) return mock.settings[k] end, get_bool = function(_, k, d)
		local v = mock.settings[k] if v == nil then return d end return v == "true" end },
	get_mod_storage = function() return storage_obj end,
	serialize = function(v) local out = { "return " } ser(v, out) return table.concat(out) end,
	deserialize = function(s)
		local f = loadstring(s)
		if not f then return nil end
		setfenv(f, {})
		local ok, v = pcall(f)
		if ok then return v end
		return nil
	end,
	formspec_escape = function(s) return s end,
	colorize = function(_, s) return s end,
	get_item_group = function() return 0 end,
	override_item = function(name) mock.registered.override_item = (mock.registered.override_item or 0) + 1 end,
	registered_nodes = {},
	registered_items = {},
}, {
	__index = function(_, key)
		if type(key) == "string" and (key:find("^register_") or key:find("^clear_registered")) then
			return function(...)
				mock.registered[key] = (mock.registered[key] or 0) + 1
				return ...
			end
		end
		return nil
	end,
})
minetest = core

function string.split(s, sep)
	local out = {}
	for part in (s .. sep):gmatch("(.-)" .. sep:gsub("%p", "%%%0")) do
		if part ~= "" then out[#out + 1] = part end
	end
	return out
end

function table.copy(t)
	local out = {}
	for k, v in pairs(t) do out[k] = type(v) == "table" and table.copy(v) or v end
	return out
end

function mock.load_mod(name)
	local prev = current_mod
	current_mod = name
	dofile(GAME .. "/mods/" .. name .. "/init.lua")
	current_mod = prev
end

return mock
