# API interna e eventos

Referência rápida das funções públicas mais usadas. Cada arquivo-fonte também documenta sua API no cabeçalho. Tudo roda no servidor.

## Núcleo (`dbil_core`)

| Função | Descrição |
| --- | --- |
| `dbil.include(caminho)` | executa um arquivo relativo ao mod que está carregando |
| `dbil.log.info/warn/error(fmt, ...)`, `dbil.log.protect(rótulo, fn, ...)` | log com prefixo; chamada protegida que registra o erro com traceback |
| `dbil.config.<seção>.<chave>` | configuração central (sobrescreva com `dbil.<seção>.<chave>` no `minetest.conf`) |
| `dbil.config.register_section(nome, tabela)` | seção de configuração de um mod novo |
| `dbil.events.on(nome, fn, prioridade)`, `emit(nome, ...)`, `ask(nome, ...)` | barramento de eventos (`ask` permite veto com `false`) |
| `dbil.scheduler.every(nome, intervalo, fn(dt), prioridade)` | tarefa periódica no globalstep único |
| `dbil.schema.sanitize(valor, schema)` / `check(def, schema, contexto)` | repara dados / valida definições |
| `dbil.registry.new(tipo, { schema })` → `:register`, `:get`, `:iter` | registros nomeados |
| `dbil.storage.load_table/save_table/get_raw/set_raw` | persistência no mod storage |
| `dbil.fx.burst(tipo, pos, opções)`, `fx.attach(tipo, objeto)`, `fx.stop(handle)`, `fx.sound(nome, alvo)`, `fx.texture(nome, cor)` | efeitos por significado (ver `config/theme.lua`) |
| `dbil.util.*` | `clamp`, `now`, `deep_copy`, `format_int`, `yaw_dir`, `clean_name`... |

## Personagem (`dbil_character`)

| Função | Descrição |
| --- | --- |
| `dbil.players.get_state(p)`, `get_character(p)`, `is_ready(p)`, `is_alive(p)` | sessão do jogador |
| `dbil.players.create_character(p, nome, raça)`, `reset_character(p)`, `save(p)`, `mark_dirty(p)` | criação e salvamento |
| `dbil.players.register_tick(nome, intervalo, fn(player, state, dt), prioridade)` | tick por jogador com personagem |
| `dbil.races.register(id, def)`, `get`, `playable()`, `on(raça, evento, fn)` | raças |
| `dbil.model.FORMAT`, `model.migrations[n]`, `model.new_character`, `model.sanitize_account` | formato do save |
| `dbil.stats.get(p, atributo)`, `derived(p)`, `set_modifier(p, fonte, mods)`, `clear_modifier`, `add_base`, `set_base`, `recalculate` | atributos |
| `dbil.resources.get/get_max/set/add/ratio(p, "hp"|"ki"|"stamina")`, `can_spend`, `spend`, `drain`, `fill`, `block_regen`, `mark_combat` | recursos |
| `dbil.power.get_base(p)`, `get_current(p)`, `get_perceived(alvo, observador, sensor)`, `compute_base`, `format`, `register_state_factor` | Poder de Luta |
| `dbil.actors.*` | `is_alive`, `get_name`, `get_team`, `get_power`, `get_derived`, `get_hp`, `get_center`, `get_eye_pos`, `get_look_dir`, `are_hostile`, `in_radius`, `track/untrack` |
| `dbil.physics.set(p, camada, valores)`, `clear(p, camada)`, `reset(p)` | física em camadas |
| `dbil.appearance.push(p, fonte, camada, prioridade)`, `pop`, `refresh` | aparência |
| `dbil.animation.set(obj, nome)`, `action(obj, nome, duração)`, `register_pose(prioridade, fn)` | animações |

## Sistemas

| Função | Descrição |
| --- | --- |
| `dbil.input.trigger(p, ação, params)`, `register_action`, `lock(p, fonte, s)`, `can_act`, `move_direction`, `refresh_kit`, `register_kit_slot` | entrada e ações |
| `dbil.ki.get/get_max/set/add/ratio`, `cost(p, base)`, `try_spend(p, base, motivo)`, `is_charging`, `stop_charging`, `charge_rate` | Ki |
| `dbil.flight.start(p)`, `stop(p, motivo)`, `toggle(p)`, `is_flying(p)` | voo |
| `dbil.movement.on_ground(p)`, `set_invulnerable(p, s)`, `is_invulnerable(p)` | movimento |
| `dbil.combat.deal_damage(info)`, `compute_damage(...)`, `power_ratio_factor`, `knockback`, `register_modifier`, `resolve_target`, `find_in_cone`, `set_lock/get_lock/clear_lock`, `is_guarding`, `perform_melee` | combate |
| `dbil.techniques.register(id, def)`, `register_shape`, `learn(p, id)`, `forget`, `equip(p, slot, id)`, `get_equipped`, `knows`, `meets_requirements`, `compute(def, maestria, carga)`, `cooldown_remaining`, `is_casting`, `cast_npc(obj, id, {target})` | técnicas |
| `dbil.projectiles.spawn(spec)`, `register_clash_resolver(fn)`, `active_count`, `count_by_owner` | projéteis |
| `dbil.progression.add_xp(p, n, fonte)`, `set_level`, `xp_to_next`, `add_training(p, atributo, pontos)`, `training_cap`, `kill_xp_mult` | progressão |
| `dbil.mastery.get(p, chave)`, `get_level`, `add_xp(p, chave, n, max)`, `set_level` | maestria (`technique:<id>`, `transformation:<id>`...) |
| `dbil.enemies.register(id, def)`, `register_brain`, `spawn(id, pos)`, `get` | inimigos |
| `dbil.transformations.register`, `unlock(p, id)`, `lock`, `activate(p, id)`, `deactivate(p, motivo)`, `get_active`, `next_form`, `meets_requirements` | transformações |
| `dbil.quests.register`, `start(p, id)`, `complete`, `abandon`, `progress(p, id)`, `is_active`, `is_completed` | missões |
| `dbil.world.get_spawn()`, `ensure_arena(cb)`, `register_dimension`, `get_dimension(pos)`, `register_respawn_resolver(fn, prioridade)`, `surface_level` | mundo |
| `dbil.ui.notify(p, texto, tipo)`, `register_sheet_tab`, `refresh_sheet`, `new_bar`, `new_text`, `is_touch(p)` | interface |

## Tabela `info` de dano (`dbil.combat.deal_damage`)

```lua
{
	attacker = obj,            -- opcional
	target = obj,              -- obrigatório (ator vivo)
	amount = 20,               -- dano base
	kind = "melee" | "ki" | "true",
	source = "heavy",          -- id do golpe/técnica
	knockback = 8, lift = 3, direction = vetor, hitstun = 0.5,
	can_block = true, fx = "hit_heavy", sound = "punch_heavy", pos = vetor,
	attacker_power = n, attacker_derived = t, -- snapshots (projéteis)
	ignore_teams = false,
}
-- retorna dano_final, resultado ("hit" | "blocked" | "guard_break" | "immune" | "invalid")
-- após os modificadores, info.damage / info.result ficam preenchidos
```

## Eventos

| Evento | Argumentos | Emitido quando |
| --- | --- | --- |
| `player_joined` | player, state | jogador conectou (antes do personagem) |
| `character_required` | player, state | não há personagem — UI abre a criação |
| `character_created` | player, char, state | personagem criado |
| `character_ready` | player, char, state | personagem ativo — sistemas inicializam |
| `character_saving` | player, char, state | antes de serializar (sistemas devolvem valores) |
| `character_leaving` | player, char, state | saída/desligamento |
| `character_reset` | player, state | personagem apagado (debug) |
| `stats_changed` | player, derived, state | atributos recalculados |
| `resource_spent` | player, tipo, quantidade, motivo | Ki/Stamina gastos |
| `charge_started` / `charge_stopped` | player / player, motivo (`full`, `released`, `interrupted`...) | carregar Ki |
| `flight_started` / `flight_stopped` | player / player, motivo (`manual`, `no_ki`, `landed`, `died`...) | voo |
| `dash` | player | dash |
| `guard_started` / `guard_stopped` | player | defesa |
| `damage_dealt` | info | qualquer dano aplicado |
| `player_damaged` | { player, amount, attacker, kind, source } | jogador perdeu vida |
| `attack_dodged` | info | alvo invulnerável (dash) |
| `actor_killed` | info | um ator morreu pelo pipeline |
| `enemy_killed` | { id, name, xp, power, pos, contributors = { [nome] = dano }, killer } | inimigo derrotado |
| `player_died` / `player_respawned` | { player, reason } / player | morte e respawn |
| `technique_learned` / `techniques_changed` | player, id / player | técnicas |
| `technique_cast_started` / `technique_cast_cancelled` | player, id [, motivo] | conjuração com tempo |
| `technique_used` | conjurador, id, { charge_mult } | técnica disparada |
| `projectile_impact` | spec, ponto, alvo | projétil atingiu algo |
| `projectile_clash` | vencedor, perdedor | projéteis colidiram |
| `xp_gained` / `level_up` | player, n, fonte / player, nível, nível_anterior | progressão |
| `training` | player, fonte, unidades | ação que treina (ver `config/progression.lua`) |
| `attribute_trained` | player, atributo, total | +1 por treino |
| `mastery_level_up` | player, chave, nível | maestria |
| `zenkai` | player | Zenkai Saiyajin |
| `transformation_unlocked` / `_locked` / `_started` | player, id | transformações |
| `transformed` / `reverted` | player, id, anterior / player, id, motivo | transformações |
| `quest_started` / `quest_progress` / `quest_completed` | player, id | missões |
| `item_used` / `item_picked_up` | player, item [, quantidade] | itens |
| `lock_changed` | player, alvo | lock-on |
| `notify` | player, texto, tipo | mensagem na tela |
