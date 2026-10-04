-- Target frame (top center): name, HP and Power Level of the opponent the
-- player is fighting. Appears on hits given or taken and fades after a while.

local ui = dbil.ui
local cfg = dbil.config.hud
local colors = dbil.config.theme.colors
local actors = dbil.actors
local now = dbil.util.now

local TOP = { x = 0.5, y = 0 }
local WIDTH = 260

local function show(player, target)
	local state = dbil.players.get_state(player)
	if not state or not state.ready then
		return
	end
	state.target_frame = state.target_frame or {}
	local tf = state.target_frame
	tf.obj = target
	tf.expires = now() + cfg.target_frame_time
	if not tf.bar then
		tf.name = ui.new_text(player, { position = TOP, offset = { x = 0, y = 28 }, style = 1, z = 50 })
		tf.bar = ui.new_bar(player, { position = TOP, x = -WIDTH / 2, y = 50, width = WIDTH, height = 10, color = colors.enemy, z = 50 })
		tf.info = ui.new_text(player, { position = TOP, offset = { x = 0, y = 70 }, z = 50 })
	end
end

local function hide(state)
	local tf = state.target_frame
	if tf and tf.bar then
		tf.name:remove()
		tf.bar:remove()
		tf.info:remove()
	end
	state.target_frame = nil
end

dbil.events.on("damage_dealt", function(info)
	local attacker, target = info.attacker, info.target
	if attacker and attacker:is_player() and target and not target:is_player() then
		show(attacker, target)
	elseif target and target:is_player() and attacker and not attacker:is_player() then
		show(target, attacker)
	end
end)

dbil.players.register_tick("target_frame", 0.15, function(player, state)
	local tf = state.target_frame
	if not tf then
		return
	end
	local obj = tf.obj
	if now() > tf.expires or not obj or not obj:is_valid() or not actors.is_alive(obj) then
		hide(state)
		return
	end
	local hp, max = actors.get_hp(obj), actors.get_max_hp(obj)
	tf.name:set(core.colorize(colors.enemy, actors.get_name(obj)))
	tf.bar:set(hp / max)
	local reading = dbil.power.get_perceived(obj, player)
	tf.info:set(core.colorize(colors.text_dim, ("Vida %d/%d   "):format(math.ceil(hp), max))
		.. core.colorize(colors.power, "PL " .. dbil.power.format(reading)))
end, 810)

dbil.events.on("character_leaving", function(player, char, state)
	hide(state)
end)
