-- Small generic helpers. Nothing here knows about gameplay.

local util = {}
dbil.util = util

local floor, sqrt, abs = math.floor, math.sqrt, math.abs

function util.clamp(v, lo, hi)
	if v < lo then return lo end
	if v > hi then return hi end
	return v
end

function util.lerp(a, b, t)
	return a + (b - a) * t
end

function util.round(v, decimals)
	local m = 10 ^ (decimals or 0)
	return floor(v * m + 0.5) / m
end

--- Monotonic time in seconds (server uptime based, safe for cooldowns).
function util.now()
	return core.get_us_time() / 1e6
end

function util.deep_copy(t, seen)
	if type(t) ~= "table" then
		return t
	end
	seen = seen or {}
	if seen[t] then
		return seen[t]
	end
	local out = {}
	seen[t] = out
	for k, v in pairs(t) do
		out[util.deep_copy(k, seen)] = util.deep_copy(v, seen)
	end
	return out
end

--- Recursively fills missing keys of `t` from `defaults` (in place).
function util.apply_defaults(t, defaults)
	for k, v in pairs(defaults) do
		if t[k] == nil then
			t[k] = util.deep_copy(v)
		elseif type(t[k]) == "table" and type(v) == "table" then
			util.apply_defaults(t[k], v)
		end
	end
	return t
end

function util.count(t)
	local n = 0
	for _ in pairs(t) do
		n = n + 1
	end
	return n
end

function util.sorted_keys(t)
	local keys = {}
	for k in pairs(t) do
		keys[#keys + 1] = k
	end
	table.sort(keys, function(a, b)
		return tostring(a) < tostring(b)
	end)
	return keys
end

function util.contains(list, value)
	for _, v in ipairs(list) do
		if v == value then
			return true
		end
	end
	return false
end

--- Formats big numbers with a dot as thousands separator: 1234567 -> "1.234.567".
function util.format_int(n)
	n = floor((tonumber(n) or 0) + 0.5)
	local s = tostring(abs(n))
	local out = s:reverse():gsub("(%d%d%d)", "%1."):reverse()
	if out:sub(1, 1) == "." then
		out = out:sub(2)
	end
	return (n < 0 and "-" or "") .. out
end

--- Converts a "#rrggbb" string into the 0xRRGGBB integer used by HUD text.
function util.color_to_int(hex)
	local r, g, b = hex:match("^#(%x%x)(%x%x)(%x%x)")
	if not r then
		return 0xFFFFFF
	end
	return tonumber(r, 16) * 65536 + tonumber(g, 16) * 256 + tonumber(b, 16)
end

-- Vector helpers that avoid allocating when only scalars are needed.

function util.dist_sq(a, b)
	local dx, dy, dz = a.x - b.x, a.y - b.y, a.z - b.z
	return dx * dx + dy * dy + dz * dz
end

function util.dist(a, b)
	return sqrt(util.dist_sq(a, b))
end

--- Unit horizontal direction for a yaw (Luanti convention: CCW from +Z).
function util.yaw_dir(yaw)
	return vector.new(-math.sin(yaw), 0, math.cos(yaw))
end

function util.dir_to_yaw(dir)
	return math.atan2(-dir.x, dir.z)
end

--- Sanitizes a free-text name typed by a player.
function util.clean_name(s, max_len)
	s = tostring(s or "")
	s = s:gsub("[%c]", ""):gsub("^%s+", ""):gsub("%s+$", ""):gsub("%s+", " ")
	-- Formspec/translation escape characters are not allowed in names.
	s = s:gsub("[%[%]%;%,\\\27]", "")
	if max_len and #s > max_len then
		s = s:sub(1, max_len)
	end
	return s
end

--- Weighted random pick from {item = weight} (weights > 0).
function util.weighted_pick(weights, rand)
	local total = 0
	for _, w in pairs(weights) do
		total = total + w
	end
	if total <= 0 then
		return nil
	end
	local r = (rand or math.random)() * total
	for item, w in pairs(weights) do
		r = r - w
		if r <= 0 then
			return item
		end
	end
	return next(weights)
end
