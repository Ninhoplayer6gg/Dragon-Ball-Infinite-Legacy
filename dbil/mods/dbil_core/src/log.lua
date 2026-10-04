-- Thin logging wrapper so every message carries the same prefix and
-- error reports from protected calls include a traceback.

local log = {}
dbil.log = log

local PREFIX = "[dbil] "

local function fmt(msg, ...)
	if select("#", ...) > 0 then
		local ok, out = pcall(string.format, msg, ...)
		if ok then
			return out
		end
	end
	return tostring(msg)
end

function log.info(msg, ...)
	core.log("action", PREFIX .. fmt(msg, ...))
end

function log.warn(msg, ...)
	core.log("warning", PREFIX .. fmt(msg, ...))
end

function log.error(msg, ...)
	core.log("error", PREFIX .. fmt(msg, ...))
end

function log.verbose(msg, ...)
	core.log("verbose", PREFIX .. fmt(msg, ...))
end

--- Calls fn(...) protected. On failure logs the error with a traceback and
-- returns nil. Used where one faulty listener must not take the server down.
function log.protect(label, fn, ...)
	local results = { xpcall(fn, debug.traceback, ...) }
	if not results[1] then
		log.error("%s failed: %s", label, tostring(results[2]))
		return nil
	end
	return unpack(results, 2)
end
