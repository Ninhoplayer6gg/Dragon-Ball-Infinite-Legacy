-- Single globalstep that drives every periodic system at its own interval.
-- Keeps per-tick work explicit, ordered and cheap.
--
--   dbil.scheduler.every("ki_regen", 0.5, function(elapsed) ... end, 50)

local scheduler = {}
dbil.scheduler = scheduler

local tasks = {}
local by_name = {}

local function sort_tasks()
	table.sort(tasks, function(a, b)
		if a.priority == b.priority then
			return a.order < b.order
		end
		return a.priority < b.priority
	end)
end

--- Runs fn(elapsed) every `interval` seconds (0 = every server step).
-- Lower priority runs first in the same step (default 100).
function scheduler.every(name, interval, fn, priority)
	assert(not by_name[name], "scheduler task already registered: " .. name)
	local task = {
		name = name,
		interval = interval,
		fn = fn,
		priority = priority or 100,
		order = #tasks,
		elapsed = 0,
		label = "scheduler task '" .. name .. "'",
	}
	tasks[#tasks + 1] = task
	by_name[name] = task
	sort_tasks()
	return task
end

core.register_globalstep(function(dtime)
	for i = 1, #tasks do
		local task = tasks[i]
		task.elapsed = task.elapsed + dtime
		if task.elapsed >= task.interval then
			local elapsed = task.elapsed
			-- Avoid catch-up storms after a lag spike.
			task.elapsed = 0
			dbil.log.protect(task.label, task.fn, elapsed)
		end
	end
end)
