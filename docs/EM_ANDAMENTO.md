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
| `src/ServerScriptService/RetroCommands.lua` (novo), `src/ServerScriptService/AdminSystemServer.server.lua` (V9), `src/StarterPlayer/StarterPlayerScripts/AdminMenuClient.client.lua` (V13) | Claude | ~~#14~~ mesclado | **NO AR** — console publicado na execução #50 (2 atualizados, 1 criado). Ver o recado abaixo. Doc: [`CONSOLE_ADMIN.md`](CONSOLE_ADMIN.md). |
| `tasks/apply_code_payload.luau` | Claude | #5 | pipeline de publicação |
| `AGENTS.md`, `CLAUDE.md`, `docs/ADICIONAR_SCRIPT.md` | Claude | #5 | instruções de agente |
| `src/ReplicatedFirst/LoadingScreen.client.lua` | Claude | #5 | **PRONTO** — V3, preload + botão de pular |
| `src/ServerScriptService/SpawnSystem.server.lua` | Claude | #5 | **PRONTO** — V9, base da zona segura |
| `src/ServerScriptService/DuelSystemServer.server.lua` | Claude | #5 | **PRONTO** — V3, arena + arquibancada |
| `src/StarterPlayer/StarterPlayerScripts/HealthDisplay.client.lua` | ~~Codex~~ livre | ~~#7~~ mesclado | Entrada velha: o PR #7 foi mesclado em 02/09. O Claude fez o V9 (HUD pequeno no canto superior direito) direto na main. |
| `src/ServerScriptService/EnergySystemServer.server.lua` | Codex | #7 | física de energia |
| `tasks/apply_code_payload.luau` (lista `REMOVER`), `tools/test_publish.py`, `tests/publish_removal_harness.luau` | Claude | direto na main | **PRONTO** — a publicação aprendeu a REMOVER instância, com lista explícita e teste de integração. Foi o que permitiu tirar o Adonis. |
| `.github/workflows/*`, `tools/run_code_publish.py` | Codex | #6 | Environments e trava de main |
| `.github/workflows/validate-code.yml` (etapa de testes) | Claude | direto na main | ⚠️ Conferido antes de mexer: o PR #6 altera este arquivo mas **não toca a etapa de testes** — só o `find` e o bloco reutilizável. A etapa passou a rodar os três testes do repositório. Se o #6 for mesclado, os dois trechos convivem. |

> Os oito scripts que rodavam no place sem cópia no repositório agora são
> **seis**: `dmgindi` e `dmgindicator` viraram `DamageIndicatorServer` e
> `DamageIndicatorClient`, versionados e registrados em `LEGACY_NAMES`. Faltam
> `BossConfigServer`, `Boss_CatalogGate_V1`, `Death`, `PassiveVFXServer`,
> `PassiveVFXClient` e `SystemDiagnostic`.

## Recado ao Codex — console de comandos (V9 / V13)

O admin do jogo ganhou motor de comandos próprio:
[`CONSOLE_ADMIN.md`](CONSOLE_ADMIN.md). O que te afeta:

1. **`AdminSystemServer` foi para V9 e `AdminMenuClient` para V13.** Eles agora
   dependem um do outro: o V13 usa os remotes `AdminListCommands` e
   `AdminRunCommand`, que só existem no V9. **Publique os dois juntos.** O
   client degrada com aviso na tela se o servidor for antigo, mas não o
   contrário.

2. **A cadeia de `elseif` do V8 não existe mais.** Comando novo vai em
   `RetroCommands.lua`, na tabela, via `RetroCommands.registrar` — que é
   público de propósito e é o gancho de plugin. Não recrie o `elseif`: o painel
   lê a lista **do servidor**, então comando fora da tabela fica invisível no
   painel mesmo funcionando no chat.

3. **Se usar API `_G` nova num comando, declare em `DEPENDENCIAS`** (no
   `AdminSystemServer`). O contexto lê `_G` na hora do comando via metatable,
   porque a ordem de carga não é garantida — mas indexação dinâmica é invisível
   para a checagem 3 do `validar.sh`. Aquela tabela devolve a checagem e ainda
   alimenta o diagnóstico de boot que diz quais APIs não subiram.

4. **Nada de backtick em `src/`.** Descobri isso quebrando: o `luac` da checagem
   7 não parseia interpolação Luau, e todo backtick que existe em `src/` hoje
   está dentro de comentário. Pior: `string.format("achei "%s" aqui", x)` com
   aspas sem escape **passa** pelo `luac` (lê como `"achei " % s("aqui")`) e
   estoura em runtime. Quem pegou foi o teste, não o validador.

5. **`;reset` subiu para DONO.** É a única mudança de permissão; está
   justificada no doc. `addadmin`/`deladmin` ficaram em CHEFE por paridade com
   o V8 e com a aba ADMINS.

6. **`validate-code.yml` ganhou `luau tests/RetroCommands.spec.luau`** na etapa
   de testes — a terceira linha que eu adiciono nesse arquivo, e o PR #6
   continua não tocando essa etapa.

O Adonis foi **removido do jogo** na publicação #51. O que veio dele para o
console próprio é o **formato** (comando como dado, com nível, argumentos e
descrição), não o código. Histórico e armadilhas: [`ADONIS.md`](ADONIS.md).

## Recado ao Codex — a publicação agora REMOVE instância

O dono pediu para tirar o Adonis do jogo. A publicação não sabia apagar nada
(fazia rename, criava pasta, criava script e trocava `Source`), e o
`Adonis_Loader` é uma `Folder` — então nem apareceria na lista `?`, que só lista
scripts. Tirar os arquivos do `src/` deixaria o Adonis **rodando e invisível nos
dois relatórios**.

Então `tasks/apply_code_payload.luau` ganhou a lista **`REMOVER`**. O que você
precisa saber antes de tocar nela:

1. **É lista explícita, por caminho completo, com a classe esperada.** Nunca
   "apague o que não está no repositório": há 9 scripts legítimos que só existem
   no place (`PlayerModule`, `RbxCharacterSounds`, `BossConfigServer`...) e uma
   regra automática levaria todos.

2. **A classe é conferida antes de remover.** Um caminho que caia sobre outra
   coisa vira **problema** e bloqueia a publicação inteira, em vez de apagar o
   objeto errado. É a única defesa contra erro de digitação numa place de
   produção.

3. **A remoção acontece por último**, depois de todas as outras escritas darem
   certo, e entra no mesmo rollback. Remover primeiro e falhar depois deixaria o
   place sem o objeto mesmo com a publicação abortada.

4. **Caminho que já não existe NÃO é problema** — a entrada fica inerte depois
   da primeira publicação, igual às de `LEGACY_NAMES`.

5. **É a única operação da publicação sem desfazer do lado do jogo.** As outras
   sobrescrevem `Source`, e o histórico de versões do Creator Dashboard devolve.
   Por isso é o único caminho com teste de integração dedicado:
   `tools/test_publish.py` roda a tarefa **real** num Roblox falso, em modo
   `check`, e cobre os quatro desfechos de um caminho de remoção (existe, já não
   existe, classe diferente, nome duplicado) mais a ordem das escritas.
   Verificado contra quatro regressões plantadas. **Se mexer na remoção, rode
   esse teste.**

O `tools/test_adonis.py` e o `tests/adonis_settings_harness.luau` saíram junto
com o Adonis, e a linha deles no `validate-code.yml` foi trocada pela do
`test_publish.py`. A mecânica de "área de terceiros" do `validar.sh` ficou no
lugar, apontando para uma pasta que não existe, de propósito — o motivo de cada
exclusão está lá e vai valer para o próximo código de terceiros.

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
