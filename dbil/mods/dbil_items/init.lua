-- Consumable items.

local cfg = dbil.config.items
local now = dbil.util.now

-- Senzu: fully restores HP, Ki and Stamina.
core.register_craftitem("dbil_items:senzu", {
	description = "Semente dos Deuses (Senzu)\nRestaura completamente Vida, Ki e Stamina.\n[Clique / Toque] Comer",
	inventory_image = "dbil_item_senzu.png",
	stack_max = 10,
	-- Short tap eats on touchscreens.
	touch_interaction = "short_dig_long_place",
	on_use = function(itemstack, user)
		if not user or not user:is_player() or not dbil.players.is_alive(user) then
			return nil
		end
		local state = dbil.players.get_state(user)
		local t = now()
		if t < (state.senzu_ready or 0) then
			return nil
		end
		state.senzu_ready = t + cfg.senzu_cooldown
		dbil.resources.fill(user)
		dbil.fx.burst("level_up", vector.add(user:get_pos(), vector.new(0, 1, 0)), { color = "#9cff8a", amount = 20 })
		dbil.events.emit("item_used", user, "dbil_items:senzu")
		dbil.events.emit("notify", user, "Senzu! Energia totalmente restaurada.", "success")
		itemstack:take_item()
		return itemstack
	end,
})

-- Automatic pickup: kit items (fists, techniques) use the click for combat,
-- so dropped rewards are collected by walking or flying over them.
dbil.players.register_tick("item_pickup", cfg.pickup_interval, function(player)
	if player:get_hp() <= 0 then
		return
	end
	local pos = vector.add(player:get_pos(), vector.new(0, 0.6, 0))
	local inv = player:get_inventory()
	for _, obj in ipairs(core.get_objects_inside_radius(pos, cfg.pickup_radius)) do
		local ent = not obj:is_player() and obj:get_luaentity()
		if ent and ent.name == "__builtin:item" and ent.itemstring ~= "" then
			local stack = ItemStack(ent.itemstring)
			if inv:room_for_item("main", stack) then
				inv:add_item("main", stack)
				ent.itemstring = ""
				obj:remove()
				dbil.events.emit("item_picked_up", player, stack:get_name(), stack:get_count())
			end
		end
	end
end)
