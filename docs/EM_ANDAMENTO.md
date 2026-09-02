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
| `src/StarterPlayer/StarterPlayerScripts/HealthDisplay.client.lua` | Codex | #7 | V8, HUD responsivo |
| `src/ServerScriptService/EnergySystemServer.server.lua` | Codex | #7 | física de energia |
| `.github/workflows/*`, `tools/run_code_publish.py` | Codex | #6 | Environments e trava de main |

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
