-- Hotbar kit: the items that expose actions to every platform.
--
-- On PC: number keys select, left/right mouse use. On touchscreens: tap a
-- hotbar slot to select, tap the world for the primary action and long-press
-- for the secondary one. Kit items cannot be dropped, moved or lost.
--
-- Layout: 1 Punhos | 2 Voo | 3-6 Técnicas equipadas | 7 Transformação (quando
-- houver) | 8 livre

local input = dbil.input

input.KIT_SLOTS = {
	fists = 1,
	flight = 2,
	technique_first = 3,
	technique_count = 4,
}

local reach = dbil.config.combat.light.reach + 0.5

local function trigger(action, params)
	return function(itemstack, user)
		if user and user:is_player() then
			input.trigger(user, action, params)
		end
		return nil
	end
end

local function no_drop(itemstack)
	return itemstack
end

local function noop()
	return nil
end

local common = {
	stack_max = 1,
	range = reach,
	-- Short tap = primary (on_use), long press = secondary (place).
	touch_interaction = "short_dig_long_place",
	groups = { dbil_kit = 1, not_in_creative_inventory = 1 },
	tool_capabilities = {
		full_punch_interval = 0.25,
		max_drop_level = 0,
		groupcaps = {},
		damage_groups = {},
	},
	on_drop = no_drop,
}

local function kit_item(name, def)
	for k, v in pairs(common) do
		if def[k] == nil then
			def[k] = v
		end
	end
	core.register_tool("dbil_input:" .. name, def)
end

kit_item("fists", {
	description = "Punhos\n[Clique / Toque] Golpe rápido\n[Botão direito / Segurar] Golpe pesado",
	inventory_image = "dbil_item_fists.png",
	wield_image = "dbil_item_fists.png",
	wield_scale = { x = 0.7, y = 0.7, z = 1 },
	on_use = function(itemstack, user, pointed)
		input.trigger(user, "light_attack", { pointed = pointed })
		return nil
	end,
	on_secondary_use = function(itemstack, user, pointed)
		input.trigger(user, "heavy_attack", { pointed = pointed })
		return nil
	end,
	on_place = function(itemstack, user, pointed)
		input.trigger(user, "heavy_attack", { pointed = pointed })
		return nil
	end,
})

kit_item("flight", {
	description = "Voo\n[Clique / Toque] Ativar ou desativar o voo\nPulo: subir | Agachar: descer | Aux1 + mover: voo rápido",
	inventory_image = "dbil_item_flight.png",
	wield_image = "dbil_blank.png",
	on_use = trigger("toggle_flight"),
	on_secondary_use = noop,
	on_place = noop,
})

for slot = 1, input.KIT_SLOTS.technique_count do
	kit_item("technique_" .. slot, {
		description = "Técnica " .. slot,
		inventory_image = "dbil_item_technique.png",
		wield_image = "dbil_blank.png",
		-- Holding place (right mouse / long press) charges Ki.
		_dbil_place_charges = true,
		on_use = function(itemstack, user, pointed)
			input.trigger(user, "use_technique", { slot = slot, pointed = pointed })
			return nil
		end,
		on_secondary_use = noop,
		on_place = noop,
	})
end

-- The bare hand (empty hotbar slot) looks like the fists and can punch
-- creatures (entity punches are turned into light attacks by dbil_combat).
core.override_item("", {
	wield_image = "dbil_item_fists.png",
	wield_scale = { x = 0.7, y = 0.7, z = 1 },
	range = reach,
	tool_capabilities = {
		full_punch_interval = 0.4,
		max_drop_level = 0,
		groupcaps = {},
		damage_groups = {},
	},
})

local function is_kit(stack)
	return core.get_item_group(stack:get_name(), "dbil_kit") > 0
end
input.is_kit_item = is_kit

-- Technique items show the equipped technique's name and icon.
local function technique_info(char, slot)
	local id = char.techniques.equipped[slot]
	if not id or id == "" then
		return nil
	end
	local def = dbil.techniques and dbil.techniques.get(id)
	return id, def
end

local function decorate(stack, char, slot)
	local id, def = technique_info(char, slot)
	if not id then
		return
	end
	local meta = stack:get_meta()
	local name = def and def.name or id
	meta:set_string("description", ("%s\n[Clique / Toque] Usar técnica\n[Segurar botão direito / pressionar] Carregar Ki"):format(name))
	if def and def.icon then
		meta:set_string("inventory_image", def.icon)
	end
	meta:set_string("dbil_technique", id)
end

-- Extra kit slots registered by other modules (e.g. transformations):
-- condition(player, char) decides whether the item is currently given.
local extra_slots = {}

function input.register_kit_slot(slot, item_name, condition)
	assert(slot > input.KIT_SLOTS.technique_first + input.KIT_SLOTS.technique_count - 1 and slot <= 8,
		"kit slot must be 7 or 8")
	extra_slots[#extra_slots + 1] = { slot = slot, item = item_name, condition = condition }
end

local function wanted_layout(player, char)
	local wanted = {
		[input.KIT_SLOTS.fists] = "dbil_input:fists",
		[input.KIT_SLOTS.flight] = "dbil_input:flight",
	}
	for i = 1, input.KIT_SLOTS.technique_count do
		if technique_info(char, i) then
			wanted[input.KIT_SLOTS.technique_first + i - 1] = "dbil_input:technique_" .. i
		end
	end
	for _, extra in ipairs(extra_slots) do
		if extra.condition(player, char) then
			wanted[extra.slot] = extra.item
		end
	end
	return wanted
end

local function find_free_slot(inv, wanted)
	for i = inv:get_size("main"), 1, -1 do
		if not wanted[i] and inv:get_stack("main", i):is_empty() then
			return i
		end
	end
end

--- Rebuilds the kit items in the hotbar (idempotent).
function input.refresh_kit(player)
	local char = dbil.players.get_character(player)
	if not char then
		return
	end
	local inv = player:get_inventory()
	if inv:get_size("main") < 32 then
		inv:set_size("main", 32)
	end
	player:hud_set_hotbar_itemcount(8)

	local wanted = wanted_layout(player, char)
	-- Remove kit items that are misplaced or no longer needed.
	for i = 1, inv:get_size("main") do
		local stack = inv:get_stack("main", i)
		if is_kit(stack) and wanted[i] ~= stack:get_name() then
			inv:set_stack("main", i, ItemStack(""))
		end
	end
	for i, name in pairs(wanted) do
		local stack = inv:get_stack("main", i)
		if stack:get_name() ~= name then
			if not stack:is_empty() then
				-- A normal item occupies the slot: move it out of the way.
				local free = find_free_slot(inv, wanted)
				if free then
					inv:set_stack("main", free, stack)
				else
					core.add_item(player:get_pos(), stack)
				end
			end
			stack = ItemStack(name)
		end
		local slot = i - input.KIT_SLOTS.technique_first + 1
		if name:find("technique_", 1, true) then
			decorate(stack, char, slot)
		end
		inv:set_stack("main", i, stack)
	end
end

function input.remove_kit(player)
	local inv = player:get_inventory()
	for i = 1, inv:get_size("main") do
		if is_kit(inv:get_stack("main", i)) then
			inv:set_stack("main", i, ItemStack(""))
		end
	end
end

-- Kit items stay where the kit puts them.
core.register_allow_player_inventory_action(function(player, action, inventory, info)
	if action == "move" then
		local from = inventory:get_stack(info.from_list, info.from_index)
		local to = inventory:get_stack(info.to_list, info.to_index)
		if is_kit(from) or is_kit(to) then
			return 0
		end
	elseif action == "put" or action == "take" then
		if is_kit(info.stack) then
			return 0
		end
	end
end)

dbil.events.on("character_ready", function(player)
	input.refresh_kit(player)
end, 150)

dbil.events.on("techniques_changed", function(player)
	input.refresh_kit(player)
end)

dbil.events.on("character_reset", function(player)
	input.remove_kit(player)
end)
