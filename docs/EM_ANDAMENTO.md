# Em andamento — quem está mexendo em quê

Arquivo de coordenação entre os agentes que trabalham neste repositório.
**Leia antes de editar qualquer script**, e atualize ao começar ou terminar.

Existe porque já houve colisão: Claude e Codex reescreveram
`HealthDisplay.client.lua` ao mesmo tempo, cada um sem saber do outro, e um
dos dois trabalhos teve de ser descartado.

## Regras

**Código atualizado não é jogo atualizado.** Commit, push e PR são *"código
atualizado"*. Só depois de um `publicar` terminar bem é que se diz *"jogo
atualizado"* — e aí a publicação vai para o chat e para
[`PUBLICACOES.md`](PUBLICACOES.md). Detalhe no [`AGENTS.md`](../AGENTS.md).

Antes de editar um arquivo listado abaixo como ocupado, escolha outro ou
combine com o dono. Ao terminar, tire a linha.

## Ocupado agora

| Arquivo | Agente | PR | Situação |
| --- | --- | --- | --- |
| `tasks/apply_code_payload.luau` | Claude | #5 | pipeline de publicação |
| `AGENTS.md`, `CLAUDE.md`, `docs/ADICIONAR_SCRIPT.md` | Claude | #5 | instruções de agente |
| `src/ReplicatedFirst/LoadingScreen.client.lua` | Claude | #5 | **PRONTO** — V3, preload + botão de pular |
| `src/ServerScriptService/SpawnSystem.server.lua` | Claude | #5 | **PRONTO** — V9, base da zona segura |
| `src/ServerScriptService/DuelSystemServer.server.lua` | Claude | #5 | **PRONTO** — V3, arena + arquibancada |
| `src/StarterPlayer/StarterPlayerScripts/HealthDisplay.client.lua` | ~~Codex~~ livre | ~~#7~~ mesclado | Entrada velha: o PR #7 foi mesclado em 02/09. O Claude fez o V9 (HUD pequeno no canto superior direito) direto na main. |
| `src/ServerScriptService/EnergySystemServer.server.lua` | Codex | #7 | física de energia |
| `src/ServerScriptService/Adonis_Loader/**`, `docs/ADONIS.md`, `tools/test_adonis.py`, `tests/adonis_settings_harness.luau` | Claude | direto na main | **PRONTO** — Adonis instalado e endurecido. Ver o recado ao Codex abaixo. |
| `.github/workflows/*`, `tools/run_code_publish.py` | Codex | #6 | Environments e trava de main |
| `.github/workflows/validate-code.yml` (etapa de testes) | Claude | direto na main | ⚠️ Conferido antes de mexer: o PR #6 altera este arquivo mas **não toca a etapa de testes** — só o `find` e o bloco reutilizável. A etapa passou a rodar os três testes do repositório. Se o #6 for mesclado, os dois trechos convivem. |

> Os oito scripts que rodavam no place sem cópia no repositório agora são
> **seis**: `dmgindi` e `dmgindicator` viraram `DamageIndicatorServer` e
> `DamageIndicatorClient`, versionados e registrados em `LEGACY_NAMES`. Faltam
> `BossConfigServer`, `Boss_CatalogGate_V1`, `Death`, `PassiveVFXServer`,
> `PassiveVFXClient` e `SystemDiagnostic`.

## Recado ao Codex — Adonis (lido antes de mexer, por favor)

O **Adonis** entrou em `src/ServerScriptService/Adonis_Loader/`, endurecido.
Decisões e justificativas: [`ADONIS.md`](ADONIS.md). O que te afeta:

1. **`tools/validar.sh` ganhou uma área de terceiros** (`TERCEIROS`), que tira
   aquela pasta das checagens 1, 2, 3, 5, 6 e 7. Não é preguiça: o
   `Descriptions.lua` do Adonis cita `_G.Adonis` dentro de uma string `[[ ]]`
   (que o `somente_codigo` não corta, porque não é comentário) e o `Loader` usa
   backtick e anotação de tipo, que o `luac` do Lua 5.4 não parseia. A sintoma
   fica coberta pelo `luau-compile --only-parse` do CI. Se o #6 tocar o
   `validar.sh`, esses dois trechos precisam conviver.

2. **`validate-code.yml` ganhou uma linha** na etapa "Rodar os testes do
   repositório": `python3 tools/test_adonis.py --luau luau`. É o mesmo arquivo
   que o #6 altera — mas o #6 **não** toca essa etapa (só o `find` e o bloco
   reutilizável), então convivem, igual ao que já aconteceu com a etapa de
   testes.

3. **Não ligue o Adonis no `_G.AdminRegistry`.** Parece uma boa integração e
   não é: hoje admin de funcionalidade (painéis, catálogo, conquistas) e admin
   de moderação (`:kick`, `:ban`, `:shutdown`) são listas separadas. Unir faria
   `;addadmin` entregar `:shutdown` de brinde. `tools/test_adonis.py` trava
   isso de propósito.

4. **Não "limpe" o `Themes/README` nem os plugins de exemplo.** Parecem
   arquivos inúteis e são o que mantém as pastas `Themes/` e `Plugins/`
   existindo: a publicação só cria pasta no caminho de um script, e o
   carregador indexa as duas **direto**, sem `FindFirstChild`. Pasta ausente é
   erro na hora de subir o servidor.

5. **Anti-exploit fica DESLIGADO.** `AntiSpeed`/`AntiNoclip` num jogo com dash
   e Despertar mata jogador legítimo. O aviso é do próprio autor do Adonis.

### Pendência que é boa para você, se quiser

Tirar a `DataStoreKey` do repositório. Hoje ela é uma string sorteada e
comitada, e o repositório é **público** — o que é aceitável (ela é só o sal do
DataStore do Adonis, não dá acesso a nada, e abusar dela exigiria já ter acesso
de leitura ao DataStore), mas dá para fazer melhor: a publicação substituir um
marcador pelo valor de um GitHub Secret ao montar o pacote. Não fiz agora
justamente porque o #6 está mexendo nos arquivos do pipeline e eu ia colidir
com você. Se pegar, cuidado com o caso do segredo ausente — o marcador não
pode ir ao ar literal e em silêncio.

## Livre e com trabalho pendente

Os cinco menus abaixo

têm o mesmo problema de animação que o `HealthDisplay` tinha — tween criado sem
cancelar o anterior — e ninguém está neles:

- `src/StarterPlayer/StarterPlayerScripts/UnifiedMenuClient.client.lua`
- `src/StarterPlayer/StarterPlayerScripts/TeamMenuClient_V2.client.lua`
- `src/StarterPlayer/StarterPlayerScripts/RetroHotbarClient.client.lua`
- `src/StarterPlayer/StarterPlayerScripts/MissionsMenuClient.client.lua`
- `src/StarterPlayer/StarterPlayerScripts/TradeMenuClient.client.lua`

O padrão a seguir está na seção *Padrão de qualidade* do
[`AGENTS.md`](../AGENTS.md).

## Pendências sem dono

- **Oito scripts rodam no jogo e não estão no repositório**: `BossConfigServer`,
  `Boss_CatalogGate_V1`, `Death`, `PassiveVFXServer`, `PassiveVFXClient`,
  `SystemDiagnostic`, `dmgindi`, `dmgindicator`. Aparecem com `?` no
  `verificar`. Ninguém consegue editá-los e não há cópia versionada. Puxar o
  `Source` de cada um para dentro de `src/` é trabalho que cabe a qualquer
  agente.
- **Chefão** (`boss-place/`): parado. Há uma pergunta de projeto aberta com o
  dono — como o Despertar deve se comportar numa luta de grupo.
- `AntiLag.server.lua:56` usa `:Destroy()` contra a regra do projeto. Está
  registrado em `EXCECOES_DESTROY` no `validar.sh` à espera de decisão do dono.

## Ordem de merge combinada

1. **#5** primeiro — é o que faz a publicação funcionar. Depois do #6, publicar
   de branch fica proibido, então o #5 precisa estar na `main` antes.
2. **Criar os Environments** `roblox-test` e `roblox-production` no GitHub e
   cadastrar a chave no `roblox-production`. Sem isso o #6 quebra a publicação
   com chave vazia.
3. **#6** — vai conflitar com o #5 em `README.md` e `docs/SEM_PC_ANDROID.md`.
4. **#7** — não conflita com nenhum dos outros.
