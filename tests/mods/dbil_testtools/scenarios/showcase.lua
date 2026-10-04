-- Visual QA scene: one player with a character, Saibamen standing in front,
-- used with third-person screenshots driven by tests/run_showcase.py.

core.register_on_joinplayer(function(player)
	local name = player:get_player_name()
	core.after(2, function()
		local p = core.get_player_by_name(name)
		if not p then return end
		local race = core.settings:get("dbil_test.race") or "saiyan"
		if not dbil.players.is_ready(p) then
			dbil.players.create_character(p, "Shiro", race)
		end
		local spawn = dbil.world.get_spawn()
		p:set_pos(spawn)
		p:set_look_horizontal(0)
		p:set_look_vertical(0.15)
		if core.settings:get_bool("dbil_test.third_person", true) then
			p:set_camera({ mode = "third" })
		end
		dbil.ki.set(p, dbil.ki.get_max(p) * 0.25)
		for i = -1, 1 do
			local e = dbil.enemies.spawn("saibaman", vector.add(spawn, vector.new(i * 2.5, 0.3, 9)))
			local ent = e and e:get_luaentity()
			if ent then
				ent._stunned_until = dbil.util.now() + 600
			end
		end
		core.log("action", "[dbil-test] scene ready")
	end)
end)

-- Optional: cycle the character sheet tabs (the open inventory formspec is
-- updated live), so the harness can screenshot every tab.
if core.settings:get_bool("dbil_test.cycle_tabs", false) then
	local tab, elapsed = 1, -12
	core.register_globalstep(function(dtime)
		elapsed = elapsed + dtime
		if elapsed < 2.5 then
			return
		end
		elapsed = 0
		for _, p in ipairs(core.get_connected_players()) do
			local state = dbil.players.get_state(p)
			if state and state.ready then
				state.sheet_tab = tab
				dbil.ui.refresh_sheet(p)
				core.log("action", "[dbil-test] sheet tab " .. tab)
			end
		end
		tab = tab % 6 + 1
	end)
end
