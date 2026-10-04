-- Lightweight event bus. Systems announce what happened; other systems react
-- without hard dependencies (progression listens to combat, quests listen to
-- everything, UI refreshes on changes...).
--
--   dbil.events.on("enemy_killed", function(info) ... end)
--   dbil.events.emit("enemy_killed", { ... })
--
-- Listeners run protected: a failing listener is logged and skipped.
-- Known events are documented in docs/API.md.

local events = {}
dbil.events = events

local listeners = {}

--- Registers a listener. Lower priority runs first (default 100).
function events.on(name, fn, priority)
	assert(type(name) == "string", "event name must be a string")
	assert(type(fn) == "function", "event listener must be a function")
	local list = listeners[name]
	if not list then
		list = {}
		listeners[name] = list
	end
	list[#list + 1] = { fn = fn, priority = priority or 100, order = #list }
	table.sort(list, function(a, b)
		if a.priority == b.priority then
			return a.order < b.order
		end
		return a.priority < b.priority
	end)
end

function events.emit(name, ...)
	local list = listeners[name]
	if not list then
		return
	end
	for i = 1, #list do
		dbil.log.protect("event '" .. name .. "' listener", list[i].fn, ...)
	end
end

--- Like emit, but any listener returning false vetoes the action.
-- Returns true when nobody vetoed.
function events.ask(name, ...)
	local list = listeners[name]
	if not list then
		return true
	end
	for i = 1, #list do
		if dbil.log.protect("event '" .. name .. "' listener", list[i].fn, ...) == false then
			return false
		end
	end
	return true
end

function events.has_listeners(name)
	return listeners[name] ~= nil and #listeners[name] > 0
end
