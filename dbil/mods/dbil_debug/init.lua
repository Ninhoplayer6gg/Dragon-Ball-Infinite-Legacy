-- Developer commands: /dbil <subcommand> [args]
-- Every subcommand that changes game state requires the dbil_admin privilege
-- (granted automatically in singleplayer and to the server admin).

core.register_privilege("dbil_admin", {
	description = "Dragon Ball: Infinite Legacy — comandos de desenvolvimento",
	give_to_singleplayer = true,
	give_to_admin = true,
})

local commands = {}
local order = {}

local function register(name, def)
	commands[name] = def
	order[#order + 1] = name
end

local function target_player(name, arg)
	local target = arg and arg ~= "" and arg or name
	local player = core.get_player_by_name(target)
	if not player then
		return nil, "Jogador não encontrado: " .. target
	end
	if not dbil.players.is_ready(player) then
		return nil, target .. " ainda não criou um personagem."
	end
	return player
end

local function fmt(n)
	return dbil.util.format_int(n)
end

register("help", {
	params = "",
	description = "Lista os comandos",
	admin = false,
	func = function()
		local lines = { "Comandos /dbil:" }
		for _, cmd in ipairs(order) do
			local def = commands[cmd]
			lines[#lines + 1] = ("  %s %s — %s"):format(cmd, def.params, def.description)
		end
		return true, table.concat(lines, "\n")
	end,
})

register("info", {
	params = "[jogador]",
	description = "Mostra atributos, recursos e Poder de Luta",
	admin = false,
	func = function(name, args)
		local player, err = target_player(name, args[1])
		if not player then return false, err end
		local state = dbil.players.get_state(player)
		local char, d = state.char, state.derived
		local lines = {
			("%s (%s) — %s, nível %d, XP %d/%d"):format(char.name, player:get_player_name(), char.race, char.level,
				math.floor(char.xp), dbil.progression.xp_to_next(char.level)),
			("PL base %s | PL atual %s"):format(fmt(dbil.power.get_base(player)), fmt(dbil.power.get_current(player))),
			("Vida %d/%d | Ki %.1f/%d | Stamina %.1f/%d"):format(player:get_hp(), d.max_hp, dbil.ki.get(player), d.max_ki,
				dbil.resources.get(player, "stamina"), d.max_stamina),
		}
		local attrs = {}
		for _, attr in ipairs(dbil.ATTRIBUTES) do
			attrs[#attrs + 1] = ("%s %.1f"):format(dbil.ATTRIBUTE_INFO[attr].short, state.attributes[attr])
		end
		lines[#lines + 1] = table.concat(attrs, " | ")
		lines[#lines + 1] = ("Dano x%.2f | Ki x%.2f | Defesa %d%% | Custo Ki %d%%"):format(d.melee_mult, d.ki_mult,
			d.defense * 100, d.ki_cost_mult * 100)
		local form = dbil.transformations.get_active(player)
		if form then
			lines[#lines + 1] = "Transformação ativa: " .. form.name
		end
		return true, table.concat(lines, "\n")
	end,
})

register("pl", {
	params = "[jogador]",
	description = "Mostra o Poder de Luta (base e atual)",
	admin = false,
	func = function(name, args)
		local player, err = target_player(name, args[1])
		if not player then return false, err end
		return true, ("PL base: %s | PL atual: %s"):format(fmt(dbil.power.get_base(player)), fmt(dbil.power.get_current(player)))
	end,
})

register("heal", {
	params = "[jogador]",
	description = "Restaura Vida, Ki e Stamina",
	func = function(name, args)
		local player, err = target_player(name, args[1])
		if not player then return false, err end
		dbil.resources.fill(player)
		return true, "Restaurado."
	end,
})

for _, kind in ipairs({ "ki", "hp", "stamina" }) do
	register(kind, {
		params = "<valor|max> [jogador]",
		description = "Define " .. kind,
		func = function(name, args)
			local player, err = target_player(name, args[2])
			if not player then return false, err end
			local value = args[1] == "max" and dbil.resources.get_max(player, kind) or tonumber(args[1])
			if not value then return false, "Valor inválido." end
			dbil.resources.set(player, kind, value, "debug")
			return true, ("%s = %s"):format(kind, tostring(dbil.resources.get(player, kind)))
		end,
	})
end

register("xp", {
	params = "<quantidade> [jogador]",
	description = "Dá experiência",
	func = function(name, args)
		local player, err = target_player(name, args[2])
		if not player then return false, err end
		local amount = tonumber(args[1])
		if not amount then return false, "Quantidade inválida." end
		local gained = dbil.progression.add_xp(player, amount, "debug")
		return true, ("+%.0f XP (nível %d)"):format(gained, dbil.players.get_character(player).level)
	end,
})

register("level", {
	params = "<nível> [jogador]",
	description = "Define o nível (subir aplica o crescimento racial)",
	func = function(name, args)
		local player, err = target_player(name, args[2])
		if not player then return false, err end
		local level = tonumber(args[1])
		if not level then return false, "Nível inválido." end
		dbil.progression.set_level(player, level)
		return true, "Nível " .. dbil.players.get_character(player).level
	end,
})

register("attr", {
	params = "<atributo> <valor> [jogador]",
	description = "Define um atributo base (strength, resistance, speed, ki_control, ki_capacity)",
	func = function(name, args)
		local player, err = target_player(name, args[3])
		if not player then return false, err end
		local value = tonumber(args[2])
		if not dbil.ATTRIBUTE_INFO[args[1] or ""] or not value then
			return false, "Uso: attr <atributo> <valor>"
		end
		dbil.stats.set_base(player, args[1], value)
		return true, ("%s = %.1f"):format(args[1], dbil.stats.get(player, args[1]))
	end,
})

register("learn", {
	params = "<técnica> [jogador]",
	description = "Aprende uma técnica (ignora requisitos)",
	func = function(name, args)
		local player, err = target_player(name, args[2])
		if not player then return false, err end
		local ok, msg = dbil.techniques.learn(player, args[1] or "", { force = true })
		return ok, ok and "Técnica aprendida." or msg
	end,
})

register("forget", {
	params = "<técnica> [jogador]",
	description = "Esquece uma técnica",
	func = function(name, args)
		local player, err = target_player(name, args[2])
		if not player then return false, err end
		return dbil.techniques.forget(player, args[1] or ""), "Feito."
	end,
})

register("techniques", {
	params = "",
	description = "Lista as técnicas registradas",
	admin = false,
	func = function()
		local ids = {}
		for id, def in dbil.techniques.iter() do
			ids[#ids + 1] = id .. " (" .. def.name .. ")"
		end
		return true, table.concat(ids, ", ")
	end,
})

register("mastery", {
	params = "<chave> <nível> [jogador]",
	description = "Define maestria (ex.: technique:ki_blast 5, transformation:kaioken 3)",
	func = function(name, args)
		local player, err = target_player(name, args[3])
		if not player then return false, err end
		local level = tonumber(args[2])
		if not args[1] or not level then return false, "Uso: mastery <chave> <nível>" end
		dbil.mastery.set_level(player, args[1], level)
		return true, "Maestria definida."
	end,
})

register("unlock", {
	params = "<transformação> [jogador]",
	description = "Desbloqueia uma transformação (ignora requisitos)",
	func = function(name, args)
		local player, err = target_player(name, args[2])
		if not player then return false, err end
		local ok, msg = dbil.transformations.unlock(player, args[1] or "", { force = true })
		return ok, ok and "Desbloqueada." or msg
	end,
})

register("lock", {
	params = "<transformação> [jogador]",
	description = "Bloqueia uma transformação",
	func = function(name, args)
		local player, err = target_player(name, args[2])
		if not player then return false, err end
		dbil.transformations.deactivate(player, "debug")
		return dbil.transformations.lock(player, args[1] or ""), "Feito."
	end,
})

register("transform", {
	params = "<transformação|off>",
	description = "Transforma (ou volta ao normal)",
	func = function(name, args)
		local player, err = target_player(name)
		if not player then return false, err end
		if args[1] == "off" then
			return dbil.transformations.deactivate(player, "debug"), "Forma normal."
		end
		return dbil.transformations.activate(player, args[1] or "")
	end,
})

register("flag", {
	params = "<flag> [on|off] [jogador]",
	description = "Define uma flag de história (ex.: ssj_awakened)",
	func = function(name, args)
		local player, err = target_player(name, args[3])
		if not player then return false, err end
		local char = dbil.players.get_character(player)
		if not args[1] then return false, "Uso: flag <flag> [on|off]" end
		char.flags[args[1]] = args[2] ~= "off" or nil
		dbil.players.mark_dirty(player)
		return true, args[1] .. " = " .. tostring(char.flags[args[1]])
	end,
})

register("fly", {
	params = "",
	description = "Liga/desliga o voo",
	func = function(name)
		local player, err = target_player(name)
		if not player then return false, err end
		dbil.flight.toggle(player)
		return true, dbil.flight.is_flying(player) and "Voando." or "Voo desligado."
	end,
})

register("god", {
	params = "",
	description = "Invulnerabilidade por 10 minutos (repita para desligar)",
	func = function(name)
		local player, err = target_player(name)
		if not player then return false, err end
		local state = dbil.players.get_state(player)
		if dbil.movement.is_invulnerable(player) then
			state.invulnerable_until = 0
			return true, "Invulnerabilidade desligada."
		end
		dbil.movement.set_invulnerable(player, 600)
		return true, "Invulnerável por 10 minutos."
	end,
})

register("spawn", {
	params = "<inimigo> [quantidade]",
	description = "Cria inimigos à sua frente (ex.: saibaman, training_dummy)",
	func = function(name, args)
		local player, err = target_player(name)
		if not player then return false, err end
		local id = args[1] or "saibaman"
		if not dbil.enemies.get(id) then
			return false, "Inimigo desconhecido: " .. id
		end
		local count = math.max(1, math.min(10, tonumber(args[2]) or 1))
		local dir = dbil.util.yaw_dir(player:get_look_horizontal())
		for i = 1, count do
			local pos = vector.add(player:get_pos(), vector.multiply(dir, 4 + i))
			pos.y = pos.y + 0.5
			dbil.enemies.spawn(id, pos)
		end
		return true, ("%d x %s"):format(count, id)
	end,
})

register("killall", {
	params = "[raio] [todos]",
	description = "Remove inimigos próximos (bonecos de treino só com 'todos')",
	func = function(name, args)
		local player, err = target_player(name)
		if not player then return false, err end
		local radius = tonumber(args[1]) or 40
		local everything = args[2] == "todos"
		local n = 0
		for _, obj in ipairs(core.get_objects_inside_radius(player:get_pos(), radius)) do
			local ent = obj:get_luaentity()
			if ent and ent._dbil_actor and (everything or not ent._def.passive) then
				obj:remove()
				n = n + 1
			end
		end
		return true, n .. " removidos."
	end,
})

register("quest", {
	params = "<start|complete|abandon> <missão> [jogador]",
	description = "Controla missões",
	func = function(name, args)
		local player, err = target_player(name, args[3])
		if not player then return false, err end
		local action, id = args[1], args[2] or ""
		if action == "start" then
			return dbil.quests.start(player, id)
		elseif action == "complete" then
			return dbil.quests.complete(player, id), "Feito."
		elseif action == "abandon" then
			return dbil.quests.abandon(player, id), "Feito."
		end
		return false, "Uso: quest <start|complete|abandon> <missão>"
	end,
})

register("pvp", {
	params = "<on|off>",
	description = "Liga/desliga dano entre jogadores (sparring)",
	func = function(name, args)
		dbil.config.combat.pvp = args[1] == "on"
		core.chat_send_all("[DBIL] PvP " .. (dbil.config.combat.pvp and "ligado" or "desligado"))
		return true
	end,
})

register("spawnpoint", {
	params = "",
	description = "Teleporta para a arena",
	func = function(name)
		local player, err = target_player(name)
		if not player then return false, err end
		local spawn = dbil.world.get_spawn()
		if not spawn then return false, "Arena ainda não gerada." end
		player:set_pos(spawn)
		return true, "Teleportado."
	end,
})

register("save", {
	params = "",
	description = "Salva todos os personagens agora",
	func = function()
		local n = 0
		for _, player in ipairs(core.get_connected_players()) do
			if dbil.players.save(player) then
				n = n + 1
			end
		end
		return true, n .. " contas salvas."
	end,
})

register("reset", {
	params = "confirmar [jogador]",
	description = "APAGA o personagem e volta para a criação",
	func = function(name, args)
		if args[1] ~= "confirmar" then
			return false, "Isso apaga o personagem. Use: /dbil reset confirmar [jogador]"
		end
		local target = core.get_player_by_name(args[2] or name)
		if not target then return false, "Jogador não encontrado." end
		dbil.transformations.deactivate(target, "reset")
		dbil.flight.stop(target, "reset")
		dbil.players.reset_character(target)
		return true, "Personagem apagado."
	end,
})

register("status", {
	params = "",
	description = "Estado do servidor (atores, projéteis)",
	admin = false,
	func = function()
		return true, ("Atores NPC rastreados: %d | Projéteis ativos: %d | Jogadores: %d"):format(
			dbil.actors.tracked_count(), dbil.projectiles.active_count(), #core.get_connected_players())
	end,
})

core.register_chatcommand("dbil", {
	params = "<comando> [args]",
	description = "Ferramentas de desenvolvimento de Dragon Ball: Infinite Legacy (/dbil help)",
	func = function(name, param)
		local args = param:split(" ")
		local cmd = table.remove(args, 1) or "help"
		local def = commands[cmd]
		if not def then
			return false, "Comando desconhecido. Use /dbil help"
		end
		if def.admin ~= false and not core.check_player_privs(name, { dbil_admin = true }) then
			return false, "Requer o privilégio dbil_admin."
		end
		local ok, result, extra = pcall(def.func, name, args)
		if not ok then
			dbil.log.error("/dbil %s failed: %s", cmd, tostring(result))
			return false, "Erro: " .. tostring(result)
		end
		if type(result) == "boolean" and extra then
			return result, extra
		end
		return result ~= false, extra or (type(result) == "string" and result) or nil
	end,
})
