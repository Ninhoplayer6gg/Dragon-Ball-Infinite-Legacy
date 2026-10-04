-- Transformation controls (hotbar item) and the "Transformações" sheet tab.

local tf = dbil.transformations
local esc = core.formspec_escape
local colors = dbil.config.theme.colors

core.register_tool("dbil_transformations:transform", {
	description = "Transformação\n[Clique / Toque] Transformar (próxima forma)\n[Botão direito / Segurar] Voltar ao normal",
	inventory_image = "dbil_item_transform.png",
	wield_image = "dbil_blank.png",
	stack_max = 1,
	range = 4,
	touch_interaction = "short_dig_long_place",
	groups = { dbil_kit = 1, not_in_creative_inventory = 1 },
	tool_capabilities = { full_punch_interval = 0.5, max_drop_level = 0, groupcaps = {}, damage_groups = {} },
	on_drop = function(itemstack)
		return itemstack
	end,
	on_use = function(itemstack, user)
		dbil.input.trigger(user, "transform_next")
		return nil
	end,
	on_secondary_use = function(itemstack, user)
		dbil.input.trigger(user, "transform_revert")
		return nil
	end,
	on_place = function(itemstack, user)
		dbil.input.trigger(user, "transform_revert")
		return nil
	end,
})

-- The item appears in hotbar slot 7 once any form is unlocked.
dbil.input.register_kit_slot(7, "dbil_transformations:transform", function(player, char)
	return next(char.transformations.unlocked) ~= nil
end)

for _, event in ipairs({ "transformation_unlocked", "transformation_locked" }) do
	dbil.events.on(event, function(player)
		dbil.input.refresh_kit(player)
		dbil.ui.refresh_sheet(player)
	end)
end

local function describe_mods(def)
	local parts = {}
	for key, m in pairs(def.modifiers) do
		local label = dbil.ATTRIBUTE_INFO[key] and dbil.ATTRIBUTE_INFO[key].short
			or (key == "power_mult" and "PL") or key
		if m.mul and m.mul ~= 1 then
			parts[#parts + 1] = ("%s x%.2g"):format(label, m.mul)
		end
		if m.add and m.add ~= 0 then
			parts[#parts + 1] = ("%s %+d"):format(label, m.add)
		end
	end
	table.sort(parts)
	return table.concat(parts, "  ")
end

local function build(player, state)
	local char = state.char
	local line, bar = dbil.ui.sheet_line, dbil.ui.sheet_bar
	local out = { line(0.5, 0.7, "Transformações — use o item Transformação (espaço 7) para ativar", colors.power) }
	local y = 1.3
	local any = false
	for id, def in tf.iter() do
		local visible = not def.races or dbil.util.contains(def.races, char.race)
		if visible then
			any = true
			local unlocked = char.transformations.unlocked[id]
			out[#out + 1] = ("box[0.5,%f;17,2.1;%s]"):format(y, unlocked and "#2a1f10dd" or "#11151fdd")
			out[#out + 1] = line(0.8, y + 0.4, def.name, unlocked and def.color or colors.text_dim)
			out[#out + 1] = line(0.8, y + 0.9, describe_mods(def), colors.text)
			local m = dbil.mastery.get(player, tf.mastery_key(id))
			out[#out + 1] = line(0.8, y + 1.4, ("Ki %.1f/s  •  Transformação %.1fs  •  Maestria %d/%d"):format(
				def.drain.ki, def.transform_time, m.level, def.mastery.max_level), colors.text_dim)
			if unlocked then
				out[#out + 1] = bar(9.5, y + 1.3, 3, 0.2,
					m.level >= def.mastery.max_level and 1 or m.xp / dbil.mastery.xp_to_next(m.level), def.color)
			else
				local _, reason = tf.meets_requirements(char, def)
				out[#out + 1] = line(9.5, y + 0.9, "Bloqueada" .. (reason and (": " .. reason) or " (desbloqueio pela história)"), colors.cooldown)
			end
			y = y + 2.3
		end
	end
	if not any then
		out[#out + 1] = line(0.5, 1.6, "Nenhuma transformação conhecida para a sua raça... ainda.", colors.text_dim)
	end
	return table.concat(out)
end

dbil.ui.register_sheet_tab("transformations", "Transformações", build, nil, 30)
