-- Visual check of the character model: one model per animation, in a row,
-- in front of the first player that joins.

core.register_entity("dbil_testtools:model", {
	initial_properties = {
		visual = "mesh",
		mesh = "dbil_character.b3d",
		textures = { "dbil_skin_saiyan.png", "dbil_hair_saiyan.png" },
		visual_size = { x = 1, y = 1, z = 1 },
		use_texture_alpha = true,
		backface_culling = false,
		physical = false,
		static_save = false,
	},
})

local POSES = { "stand", "walk", "light", "heavy", "block", "charge", "fly", "hover", "fire", "hurt", "dead" }
local FRAME_OF = { walk = 50, light = 83, heavy = 118, fly = 180, fire = 235, hurt = 253, charge = 145, hover = 210 }

core.register_on_joinplayer(function(player)
	core.after(1.5, function()
		if not dbil.players.is_ready(player) then
			dbil.players.create_character(player, "Tester", "saiyan")
		end
		local spawn = dbil.world.get_spawn() or player:get_pos()
		local base = vector.add(spawn, vector.new(-10, 0, -4))
		local yaw_rot = tonumber(core.settings:get("dbil_test.model_yaw") or "0")
		for i, name in ipairs(POSES) do
			local pos = vector.add(base, vector.new((i - 1) * 2, 0, 0))
			local obj = core.add_entity(pos, "dbil_testtools:model")
			local anim = dbil.config.theme.animations[name]
			local f = FRAME_OF[name] or anim.x
			obj:set_animation({ x = f, y = f }, 1, 0, true)
			obj:set_yaw(yaw_rot)
			obj:set_properties({ nametag = name })
		end
		local view = core.settings:get("dbil_test.view") or "front"
		local cam
		if view == "front" then
			cam = vector.add(base, vector.new(10, 0.2, 9))
			player:set_look_horizontal(math.pi)
		elseif view == "side" then
			cam = vector.add(base, vector.new(21, 0.5, 0))
			player:set_look_horizontal(math.pi / 2)
		else
			cam = vector.add(base, vector.new(10, 0.2, -9))
			player:set_look_horizontal(0)
		end
		player:set_pos(cam)
		player:set_look_vertical(0.05)
		dbil.log.info("poses scene ready")
	end)
end)
