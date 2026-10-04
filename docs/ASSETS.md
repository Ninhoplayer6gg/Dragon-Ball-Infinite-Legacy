# Assets temporários

Todos os gráficos e sons atuais são **temporários e gerados por script** (pixel art procedural, modelo de blocos e sons sintetizados). Eles existem para os sistemas poderem ser testados de verdade; foram feitos para serem trocados sem mexer no código.

| Tipo | Arquivos | Gerador | Onde o código referencia |
| --- | --- | --- | --- |
| Terreno e arena | `dbil_world/textures/dbil_*.png` | `tools/assets/gen_textures.py` | definições de nós em `dbil_world/src/nodes.lua` |
| HUD e painéis | `dbil_ui/textures/dbil_hud_*.png`, `dbil_ui_panel.png` | idem | `config/theme.lua` (`textures`) |
| Efeitos (Ki, aura, faíscas, fumaça) | `dbil_core/textures/dbil_fx_*.png` | idem | `config/theme.lua` (`textures`, `particles`) |
| Itens e ícones de técnicas | `dbil_input`, `dbil_items`, `dbil_techniques`, `dbil_transformations` `/textures` | idem | definições de itens/técnicas (`icon`) |
| Skins | `dbil_character/textures/dbil_skin_*.png`, `dbil_hair_*.png`; `dbil_enemies/textures/dbil_enemy_*.png` | idem | raças (`appearance`), inimigos (`visual`), transformações (`appearance`) |
| Modelo 3D + animações | `dbil_character/models/dbil_character.b3d` | `tools/assets/gen_model.py` | raças/inimigos (`mesh`), quadros em `config/theme.lua` (`animations`) |
| Sons | `dbil_core/sounds/dbil_*.ogg` | `tools/assets/gen_sounds.py` | `config/theme.lua` (`sounds`) |
| Menu | `dbil/menu/icon.png`, `header.png`, `dbil/screenshot.png` | `gen_textures.py` / captura real | menu principal do Luanti |

## Como trocar

- **Mesma função, arte nova:** substitua o arquivo mantendo o nome (ex.: um `dbil_fx_ki_ball.png` desenhado à mão).
- **Arquivo com outro nome:** mude só a entrada correspondente em `dbil_core/config/theme.lua` ou na definição de conteúdo.
- **Skins:** layout clássico 64x32 (cabeça 8x8x8 em (0,0), corpo em (16,16), braço em (40,16), perna em (0,16)); o cabelo é um segundo material com textura própria, o que permite mudar o cabelo nas transformações (ex.: `dbil_hair_gold.png` no Super Saiyajin).
- **Modelo:** qualquer `.b3d`/`.gltf` com os mesmos materiais (1 = pele, 2 = cabelo) funciona; ajuste os intervalos de quadros em `theme.animations`. Convenção de rotação do B3D documentada em `gen_model.py`.

## Regerar

```
pip install pillow numpy          # e o pacote vorbis-tools (oggenc) para os sons
python3 tools/assets/gen_textures.py
python3 tools/assets/gen_model.py
python3 tools/assets/gen_sounds.py
```

Os scripts são determinísticos (sementes fixas).
