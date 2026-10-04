# Estado atual, limitações e próximos passos

Versão **0.1.0 — vertical slice**. Testada com Luanti 5.17.0 (servidor + clientes reais em Linux, inclusive com a interface de toque ligada). **Ainda não foi testada num aparelho Android físico.**

## Critérios da primeira versão

| # | Critério | Situação | Como foi verificado |
| --- | --- | --- | --- |
| 1 | Abrir o projeto no Luanti | ✅ | jogo `dbil` aparece e carrega sem erros |
| 2 | Entrar em um mundo | ✅ | mundo novo gera biomas e a arena |
| 3 | Criar personagem | ✅ | tela de criação; validação no servidor (nome, raça) |
| 4 | Escolher Humano ou Saiyajin | ✅ | raças registradas com atributos, crescimento e traços diferentes |
| 5 | Ver Vida/Ki/Stamina | ✅ | HUD (também verificado no modo toque) |
| 6 | Carregar Ki | ✅ | tecla real (E) e botão Aux1 no modo toque |
| 7 | Ativar voo | ✅ | item Voo e pulo duplo com teclas reais |
| 8 | Voar corretamente | ✅ | subir/descer, seguir a câmera, voo rápido, gasto de Ki, pouso |
| 9 | Atacar fisicamente | ✅ | clique real → golpe rápido com combo |
| 10 | Ataque pesado | ✅ | clique direito real → dano maior e knockback |
| 11 | Técnica de Ki | ✅ | Rajada de Ki (instantânea) e Onda de Energia (carregável, segurando o botão) |
| 12 | Lutar contra um NPC | ✅ | Saibaman com IA (persegue, prepara golpe, atira em quem voa, autodestruição) |
| 13 | Derrotá-lo | ✅ | morte, efeito, remoção |
| 14 | Receber recompensa/progresso | ✅ | XP compartilhada, nível, drop de Senzu, missões |
| 15-17 | Sair, voltar e continuar | ✅ | teste: P1 sai e volta; servidor reinicia; dados idênticos |
| 18 | Segundo jogador | ✅ | dois clientes reais no mesmo servidor |
| 19 | Sistemas simultâneos | ✅ | técnicas simultâneas, crédito dos dois no mesmo inimigo, IA escolhendo alvos |
| 20 | Sem erros graves no servidor | ✅ | teste de integração exige zero erros no log |

Também implementados além do mínimo: defesa com quebra de guarda, dash com invulnerabilidade, corrida, treino por atributo com limites, maestria de técnicas e transformações, Zenkai, Kaioken (Humano, nível 5), Super Saiyajin **experimental** (Saiyajin, desbloqueio por flag de história), missões tutoriais, Senzu, ficha do personagem com abas, comandos de debug, colisão entre projéteis de times diferentes.

## Limitações reais atuais

- **Android:** a interface de toque foi validada no cliente Linux com `touch_controls = true` (sem sobreposição com joystick/botões, rastreador de missão se ajusta), mas desempenho e conforto em celular de verdade ainda precisam ser testados.
- **Arte e som são temporários** (gerados por script). O Saibaman usa o mesmo modelo humanoide com outra textura; todos os personagens têm o mesmo cabelo espetado (a cor muda por raça/transformação).
- **Lock-on:** a API existe (`dbil.combat.set_lock/get_lock`), o combate já usa o alvo travado, mas ainda não há botão nem assistência de câmera.
- **Técnicas:** só existe a forma "esfera" (inclui rajadas múltiplas via `count`). Feixes contínuos (Kamehameha de verdade), discos e explosões em área ainda não.
- **Beam Clash:** hoje dois projéteis de times diferentes se anulam pela força (o mais forte continua enfraquecido). O choque de feixes com disputa ainda não existe; o ponto de extensão (`register_clash_resolver`) está pronto.
- **IA:** inimigos andam e pulam (não voam, não nadam, sem pathfinding). Contra quem voa alto eles atiram e mantêm distância.
- **Voo:** o controle vertical é feito pelo servidor; com latência muito alta (> ~250 ms) a subida/descida responde com atraso (o horizontal é previsto pelo cliente e sempre é suave).
- **Mira em 3ª pessoa:** as técnicas saem do olho do personagem, não da câmera; a mira assistida compensa.
- **Mundo:** região de testes (arena + biomas); o terreno não pode ser cavado/construído por design.
- **Morte:** respawn na arena, sem penalidade e sem Outro Mundo ainda (as regras de dimensão/respawn já permitem).
- **Personagens:** o formato do save suporta vários por jogador, mas a interface usa um só.
- **PvP:** só liga/desliga global (`/dbil pvp on` ou `dbil.combat.pvp`).
- **Debug:** baixar o nível com `/dbil level` não desfaz o crescimento de atributos.

## Bugs conhecidos / pontos de atenção

- Se dois jogadores estiverem exatamente no mesmo lugar, a câmera em 3ª pessoa entra no modelo do outro (comportamento do engine).
- Saibamen que caem na água afundam e ficam presos até sumirem (60 s sem jogadores perto).
- Mensagens de dica aparecem a cada 90 s até o nível 5 (podem ser desligadas na aba Opções).

## Próximos passos recomendados

1. **Testar no Android** (os dois jogando), ajustar tamanhos de HUD/ficha e medir desempenho.
2. **Combate 2.0:** botão de lock-on com assistência de câmera, Vanish (gasta Stamina), launcher + perseguição aérea, contra-ataque.
3. **Forma "feixe"** (Kamehameha, Galick Gun, Masenko) e o **Beam Clash** com disputa por Ki/controle.
4. **Primeiro mestre:** região da Kame House com Mestre Kame ensinando o Kamehameha via cadeia de missões (o sistema de missões já suporta).
5. **Scouter** (item) usando `dbil.power.get_perceived` + supressão de Ki.
6. **Namekuseijin** como próxima raça (regeneração, braços elásticos) — só dados + ganchos.
7. **Arte de verdade:** modelo com proporções melhores e estilos de cabelo, modelo próprio do Saibaman, auras animadas, sons.
8. **Outro Mundo** ao morrer e **Esferas do Dragão** com desejos.
9. Seleção de múltiplos personagens na interface.
10. Rodada de balanceamento com partidas reais (todos os números estão em `dbil_core/config`).
