# Arquitetura

Dragon Ball: Infinite Legacy é um **jogo Luanti** (`dbil/`) dividido em mods pequenos com responsabilidades claras. Todos compartilham o namespace global `dbil`. O servidor é a autoridade de tudo que importa (dano, Ki, progressão, recompensas); o cliente só envia controles e cliques.

## Princípios

- **Dados declarativos + sistemas genéricos.** Raças, técnicas, inimigos, transformações e missões são *definições* registradas e validadas por schema. Adicionar conteúdo não exige mexer nos sistemas.
- **Nenhum número de gameplay espalhado.** Tudo em `dbil_core/config/*.lua`, sobrescrevível pelo `minetest.conf` (`dbil.<seção>.<chave>`).
- **Apresentação separada da lógica.** O código pede efeitos por *significado* (`dbil.fx.burst("hit_heavy", pos)`); texturas, cores, sons e quadros de animação estão em `config/theme.lua`.
- **Eventos em vez de dependências cruzadas.** Sistemas anunciam o que aconteceu (`dbil.events.emit`) e outros reagem (progressão ouve combate, missões ouvem tudo, a UI atualiza).
- **Atores.** Jogadores e NPCs são "atores" com a mesma interface, então o pipeline de dano, o alvo e as técnicas servem para os dois.

## Módulos e dependências

```
dbil_core ─┬─ dbil_character ─┬─ dbil_races
           │                  ├─ dbil_input ─┬─ dbil_ki ── dbil_movement ── dbil_combat ─┐
           │                  ├─ dbil_progression ───────────────────────────────────────┼─ dbil_techniques ── dbil_enemies
           │                  └─ dbil_items                                               │
           └─ dbil_world (opcional: character, enemies)                                   │
dbil_ui (depende dos sistemas que exibe) ── dbil_transformations, dbil_quests ── dbil_debug
```

| Mod | Responsabilidade |
| --- | --- |
| `dbil_core` | `dbil.include`, log (`dbil.log.protect`), util, `dbil.schema`, `dbil.config` (+ overrides), `dbil.events`, `dbil.scheduler` (um único globalstep), `dbil.storage` (mod storage serializado), `dbil.registry`, `dbil.fx` |
| `dbil_character` | `dbil.races` (registro), `dbil.model` (estrutura do save, versão, migrações), `dbil.accounts` (load/save/backup), `dbil.players` (sessões e estado em tempo de execução), `dbil.physics` (camadas), `dbil.stats` (atributos + modificadores), `dbil.resources` (Vida/Ki/Stamina), `dbil.power` (Poder de Luta), `dbil.actors`, `dbil.appearance`, `dbil.animation` |
| `dbil_races` | definições (`races/human.lua`, `races/saiyan.lua` com Zenkai) |
| `dbil_input` | leitura de controles → *intenções*; `dbil.input.trigger` (ações validadas); itens do kit da hotbar e slots extras |
| `dbil_ki` | `dbil.ki` (custo com eficiência, gasto) e carregamento |
| `dbil_movement` | `dbil.flight`, dash, corrida, invulnerabilidade |
| `dbil_combat` | `dbil.combat.deal_damage` (pipeline), modificadores de dano, alvo/lock-on, golpes, defesa, morte, escala de dano ambiental |
| `dbil_techniques` | registro de técnicas, formas ("shapes"), conjuração/carga, `dbil.projectiles` (motor de projéteis + colisão entre projéteis) |
| `dbil_progression` | XP/níveis, treino por atributo com limites, `dbil.mastery` genérica |
| `dbil_enemies` | registro de inimigos, entidade genérica (ator), cérebros de IA, geradores |
| `dbil_items` | Senzu e coleta automática |
| `dbil_transformations` | registro, ativação/manutenção/reversão, maestria, item e aba da ficha |
| `dbil_quests` | missões com objetivos por evento, recompensas, cadeia tutorial, rastreador |
| `dbil_world` | nós, biomas, arena de testes, `dbil.world` (dimensões, resolvedores de respawn) |
| `dbil_ui` | HUD, notificações, quadro do alvo, criação de personagem, ficha com abas registráveis |
| `dbil_debug` | `/dbil ...` |

## Ciclo de vida do jogador

```
joinplayer → accounts.load (migra + repara; backup se corrompido)
   ├─ sem personagem → evento character_required → tela de criação (servidor valida)
   └─ com personagem → evento character_ready → cada sistema inicializa seu estado
                         (stats 10, recursos 20, aparência 30, técnicas 140, kit 150, HUD 200...)
durante o jogo: ticks por jogador (scheduler), ações (input.trigger), eventos
autosave (só contas alteradas) | save imediato em criação/level up/missão
leaveplayer / shutdown → character_leaving (sistemas devolvem valores) → accounts.save
```

**Dados persistentes** ficam em `state.account` / `state.char` (formato em `dbil_character/src/model.lua`, `model.FORMAT = 1`). **Estado de tempo de execução** (voo, cooldowns, HUD, modificadores ativos...) fica em outros campos de `state` e nunca é salvo — transformações e voo recomeçam desligados.

## Fluxo de uma ação

```
cliente: tecla/clique ──► servidor
  get_player_control() a cada passo ──► state.intent (charge, block, sprint, boost, ascend, descend, dash)
  clique em item do kit ──► dbil.input.trigger(player, "light_attack" | "use_technique" | "toggle_flight" ...)
                               valida: vivo, não atordoado (locks), ação registrada
  sistemas leem intenções nos seus ticks (Ki, voo, defesa, corrida) ou tratam a ação
  ──► dbil.combat.deal_damage(info) ──► modificadores (defesa...) ──► aplica, knockback, hitstun, efeitos
  ──► eventos: damage_dealt, player_damaged, actor_killed, enemy_killed ──► progressão, missões, UI
```

## Atributos, Poder de Luta e modificadores

- Atributos base: Força, Resistência, Velocidade, Controle de Ki, Capacidade de Ki (`char.attributes`).
- `dbil.stats.set_modifier(player, fonte, { strength = { mul = 1.5 }, power_mult = { mul = 2 }, max_ki = { add = 50 } })` — raças, transformações e futuros buffs usam a mesma API. Valores derivados (vida/Ki/Stamina máximos, multiplicadores de dano, defesa, eficiência de Ki, velocidade) são recalculados e cacheados.
- `power_base` = fórmula multi-fator dos atributos base × raça × bônus de maestria total. `power_current` = atributos modificados × `power_mult` × fator de Ki disponível × fator de vida × fatores de estado (carregando Ki, futuros: liberar/esconder Ki). `dbil.power.get_perceived` já existe para o Scouter (supressão e limite do sensor).

## Como estender

### Nova raça
Crie `dbil_races/races/namekian.lua` com `dbil.races.register("namekian", {...})` (atributos iniciais, crescimento por nível, traços, aparência, textos) e inclua no `init.lua`. Mecânicas próprias via `dbil.races.on("namekian", "evento", fn)` (veja o Zenkai em `saiyan.lua`).

### Nova técnica
```lua
dbil.techniques.register("kamehameha", {
	name = "Kamehameha", shape = "ball", damage = 60, ki_cost = 40,
	charge_time = 1.0, max_charge_time = 3.0, max_charge_mult = 2.5, cooldown = 8,
	speed = 26, range = 90, size = 0.9, knockback = 12,
	properties = { explosion_radius = 3, piercing = false },
	requirements = { level = 10, races = nil }, learn = { auto = false }, -- ensinada por um mestre
	visual = { color = "#5fc8ff", texture = "wave_core" },
})
```
Formas novas (feixe contínuo, disco, rajada múltipla, explosão em área) são registradas com `dbil.techniques.register_shape(id, { fire = function(caster, def, params) ... end })`. O motor de projéteis registra todos os projéteis ativos e chama **resolvedores de colisão** (`dbil.projectiles.register_clash_resolver`) quando dois de times diferentes se encontram — é ali que entra o futuro **Beam Clash**. Técnicas personalizadas pelo jogador serão definições geradas a partir de forma + propriedades + visual, no mesmo formato.

### Novo inimigo
`dbil.enemies.register("raditz", { name, power, hp, attack, defense, speed, ranged = {...}, brain = "brawler", visual = {...}, drops = {...} })`. Comportamentos novos: `dbil.enemies.register_brain("boss", { init, think, step, on_damaged })`. NPCs usam técnicas com `dbil.techniques.cast_npc`.

### Nova transformação
`dbil.transformations.register("ssj2", { from = { "super_saiyan" }, races = { "saiyan" }, paths = { "classic" }, requirements = {...}, modifiers = {...}, drain = {...}, transform_time = ..., mastery = {...}, appearance = { hair = "..." }, aura = {...} })`. Caminhos são tags livres e requisitos podem citar qualquer forma, flag ou maestria — não há árvore fixa nem `if race == ...` no código.

### Nova missão / mestre
`dbil.quests.register(id, { title, description, objectives = { { event = "enemy_killed", count = 5, text = "...", progress = function(player, info) ... end } }, rewards = { xp, items, techniques, flags }, next = ..., giver = "mestre_kame" })`. Treinos de mestres são missões com objetivos especiais e recompensas como técnicas e flags de história.

### Outros pontos de extensão
- `dbil.ui.register_sheet_tab(id, título, build, on_fields, ordem)` — novas abas na ficha.
- `dbil.input.register_kit_slot(7|8, item, condição)` — novos itens no kit.
- `dbil.input.register_action(nome, { handler = ... })` — novas ações (ex.: lock-on, Vanish).
- `dbil.combat.register_modifier(fn, prioridade)` — regras de dano (resistências, combos cooperativos...).
- `dbil.animation.register_pose(prioridade, fn)` — poses contínuas.
- `dbil.power.register_state_factor(nome, fn)` — liberar/esconder Ki.
- `dbil.world.register_dimension` / `register_respawn_resolver` — Outro Mundo, Namek, planetas.
- `dbil.config.register_section(nome, tabela)` — configuração de um módulo novo.
- `dbil.model.migrations[n] = function(acc) ... end` + aumentar `model.FORMAT` quando o save mudar.

## Desempenho

- Um único globalstep (`dbil.scheduler`) com intervalos por tarefa; tarefas pesadas rodam a 0,1–0,5 s.
- Leitura de controles uma vez por passo por jogador; HUD só envia o que mudou; a ficha só é reenviada quando o conteúdo muda.
- Inimigos pensam a cada 0,2 s, procuram alvos a cada 0,5 s e só olham a lista de jogadores (sem buscas de objetos em áreas grandes). Geradores usam timers de nó (só rodam perto de jogadores).
- Atores NPC ficam num registro (`dbil.actors`), então alvos e projéteis não varrem o mapa.
- Projéteis não são salvos no mapa, têm alcance e tempo de vida máximos e limite por conjurador.
- Partículas usam spawners curtos; auras são divididas (completas para os outros, discretas para o dono).
