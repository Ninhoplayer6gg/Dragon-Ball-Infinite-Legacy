# Testes

Três níveis, todos rodam em Linux sem tela.

## 1. Unitários (LuaJIT, sem engine)

```
luajit tests/unit/run.lua
```

Carrega **todos os 16 mods** contra um `core` simulado (`tests/unit/mock_core.lua`) — isso valida todas as definições de conteúdo pelos schemas — e testa: overrides de config, utilitários, schemas (reparo e validação), eventos (prioridade e falha isolada), registros, criação de personagem, reparo de save corrompido, migrações de formato, save/load com recuperação por backup, fórmulas (atributos derivados, Poder de Luta, dano, curva de XP, maestria), requisitos de técnicas e transformações e a geometria de colisão de projéteis.

## 2. Boot do servidor

```
LUANTI_SERVER=/caminho/luantiserver tools/boot_test.sh [segundos] [pasta_do_mundo]
```

Sobe um servidor real com o jogo, gera a arena e falha se aparecer qualquer erro Lua no log.

## 3. Integração com clientes reais (2 jogadores)

Requer um build do Luanti (cliente + servidor), `Xvfb`, `xdotool` e ImageMagick.

```
LUANTI_BIN=/caminho/luanti/bin python3 tests/run_integration.py /tmp/saida
```

- Sobe o servidor e **dois clientes reais** (P1 e P2) em telas virtuais.
- **Fase API** (`tests/mods/dbil_testtools/scenarios/integration.lua`, mod só do mundo de teste): ~100 verificações com os objetos reais dos jogadores — criação (inclusive entradas inválidas), estado inicial, kit, Ki e eficiência, golpes leve/pesado, knockback, técnica, cooldown, projétil atingindo, morte do inimigo e recompensas, level up e limite de nível, treino e limite anti-macro, voo (gravidade, gasto de Ki, queda quando o Ki acaba), Kaioken (desbloqueio automático, multiplicador, desgaste de vida, reversão), IA atacando, Saibaman atirando em quem voa, autodestruição, técnicas simultâneas dos dois jogadores e XP compartilhada, PvP desligado/ligado, defesa e quebra de guarda, morte/respawn, Onda de Energia com tempo de conjuração, Senzu (coleta automática e uso), Super Saiyajin (flag, desbloqueio, cabelo dourado, multiplicador), todos os comandos `/dbil` e privilégio, save/load e saves corrompidos.
- **Fase de entrada real** (xdotool no cliente do P1): segurar E carrega Ki, pular duas vezes voa, segurar Espaço sobe, item Voo desliga, clique = golpe rápido, botão direito = golpe pesado, técnica com clique, **segurar o clique carrega a Onda de Energia até 2x**, Z defende, E + direção dá dash, I abre a ficha.
- **Persistência:** P1 sai e volta; depois o servidor inteiro reinicia e os dois voltam — os dados precisam ser idênticos.
- Termina com código 0 só se tudo passou e o servidor não registrou nenhum erro. Screenshots ficam na pasta de saída.

## QA visual

```
python3 tests/run_visual.py poses /tmp/saida          # todas as animações do modelo
python3 tests/run_showcase.py /tmp/saida [raça] [touch] # 3ª pessoa: aura, rajada, voo; "touch" liga a interface de celular
python3 tests/run_sheet.py /tmp/saida                 # todas as abas da ficha
```
