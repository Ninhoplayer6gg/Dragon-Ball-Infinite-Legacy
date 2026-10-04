-- Small HUD building blocks that only send changes to the client.

local ui = dbil.ui
local theme = dbil.config.theme

local Bar = {}
Bar.__index = Bar

local FILL_TEXTURE_HEIGHT = 16 -- dbil_hud_bar_fill.png is 1x16

--- Creates a horizontal bar. def: position, x, y (left edge, vertical
-- center), width, height, color, label (bool), z
function ui.new_bar(player, def)
	local self = setmetatable({ player = player, def = def, last_w = -1, last_label = nil, last_color = nil }, Bar)
	local z = def.z or 0
	self.back = player:hud_add({
		type = "image",
		position = def.position,
		offset = { x = def.x - 2, y = def.y },
		alignment = { x = 1, y = 0 },
		scale = { x = def.width + 4, y = def.height + 4 },
		text = theme.textures.bar_back,
		z_index = z,
	})
	self.fill = player:hud_add({
		type = "image",
		position = def.position,
		offset = { x = def.x, y = def.y },
		alignment = { x = 1, y = 0 },
		scale = { x = 0, y = def.height / FILL_TEXTURE_HEIGHT },
		text = theme.textures.bar_fill .. "^[multiply:" .. def.color,
		z_index = z + 1,
	})
	if def.label then
		self.text = player:hud_add({
			type = "text",
			position = def.position,
			offset = { x = def.x + def.width / 2, y = def.y },
			alignment = { x = 0, y = 0 },
			text = "",
			number = 0xFFFFFF,
			z_index = z + 2,
			style = 1,
		})
	end
	self.last_color = def.color
	return self
end

function Bar:set(ratio, label, color)
	local w = math.floor(math.max(0, math.min(1, ratio)) * self.def.width + 0.5)
	if w ~= self.last_w then
		self.last_w = w
		self.player:hud_change(self.fill, "scale", { x = w, y = self.def.height / FILL_TEXTURE_HEIGHT })
	end
	if color and color ~= self.last_color then
		self.last_color = color
		self.player:hud_change(self.fill, "text", theme.textures.bar_fill .. "^[multiply:" .. color)
	end
	if self.text and label ~= self.last_label then
		self.last_label = label
		self.player:hud_change(self.text, "text", label or "")
	end
end

function Bar:remove()
	self.player:hud_remove(self.back)
	self.player:hud_remove(self.fill)
	if self.text then
		self.player:hud_remove(self.text)
	end
end

local Text = {}
Text.__index = Text

--- Text element. def: position, offset, alignment, color (hex), z, size
function ui.new_text(player, def)
	local self = setmetatable({ player = player, last = "" }, Text)
	self.id = player:hud_add({
		type = "text",
		position = def.position,
		offset = def.offset or { x = 0, y = 0 },
		alignment = def.alignment or { x = 0, y = 0 },
		text = "",
		number = dbil.util.color_to_int(def.color or "#ffffff"),
		size = def.size,
		style = def.style or 0,
		z_index = def.z or 0,
	})
	return self
end

function Text:set(text)
	text = text or ""
	if text ~= self.last then
		self.last = text
		self.player:hud_change(self.id, "text", text)
	end
end

function Text:set_offset(offset)
	self.player:hud_change(self.id, "offset", offset)
end

function Text:remove()
	self.player:hud_remove(self.id)
end

--- True when the player's client uses touchscreen controls (Luanti 5.9+
-- clients report it; older ones are treated as keyboard/mouse).
function ui.is_touch(player)
	local info = core.get_player_window_information and core.get_player_window_information(player:get_player_name())
	return info ~= nil and info.touch_controls == true
end
