-- Ki API. Thin layer over dbil.resources that adds efficiency (Ki Control,
-- race traits, mastery discounts) so every Ki cost is computed the same way.
--
--   local cost = dbil.ki.cost(player, 12)            -- after efficiency
--   if dbil.ki.try_spend(player, 12, "technique") then ... end
--   dbil.ki.get(player), dbil.ki.get_max(player), dbil.ki.add(player, 10)

local ki = {}
dbil.ki = ki

local resources = dbil.resources

function ki.get(player)
	return resources.get(player, "ki")
end

function ki.get_max(player)
	return resources.get_max(player, "ki")
end

function ki.set(player, value)
	return resources.set(player, "ki", value, "set")
end

function ki.add(player, amount)
	return resources.add(player, "ki", amount, "add")
end

function ki.ratio(player)
	return resources.ratio(player, "ki")
end

--- Final cost of a base Ki cost for this player.
-- extra_mult: optional additional multiplier (e.g. technique mastery).
function ki.cost(player, base_cost, extra_mult)
	local derived = dbil.stats.derived(player)
	local mult = derived and derived.ki_cost_mult or 1
	return base_cost * mult * (extra_mult or 1)
end

function ki.can_spend(player, base_cost, extra_mult)
	return resources.can_spend(player, "ki", ki.cost(player, base_cost, extra_mult))
end

--- Spends the efficiency-adjusted cost. Returns success and the amount spent.
function ki.try_spend(player, base_cost, reason, extra_mult)
	local cost = ki.cost(player, base_cost, extra_mult)
	if resources.spend(player, "ki", cost, reason) then
		return true, cost
	end
	return false, cost
end

--- Spends an exact amount (already adjusted by the caller).
function ki.spend_exact(player, amount, reason)
	return resources.spend(player, "ki", amount, reason)
end
