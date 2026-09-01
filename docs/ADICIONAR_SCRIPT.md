# Adicionar um script novo ao RetroVerse

Procedimento único para pessoas e para agentes (Claude Code, Codex, qualquer outro).
Se você veio parar aqui por causa do `AGENTS.md` ou do `CLAUDE.md`, é este o
documento que vale.

## A mudança que torna este guia necessário

O dono do projeto **não tem PC Windows** e não consegue abrir o Roblox Studio.

Isso aposenta, para os quatro contêineres da lista abaixo, o fluxo antigo de
`central/` → colar no Studio → `tools/promover.sh`. Aquele ciclo existia porque
uma pessoa precisava colar o script no Studio; hoje o workflow **Publicar somente
código** cria o script direto no jogo.

> **Nunca entregue um script novo desses contêineres pedindo que alguém cole no
> Studio.** O pedido não tem como ser atendido, e o script fica parado.

## O que o pipeline alcança

| Caminho no repositório | Vira no Studio |
| --- | --- |
| `src/ReplicatedFirst/` | `ReplicatedFirst` |
| `src/ServerScriptService/` | `ServerScriptService` |
| `src/StarterPlayer/StarterCharacterScripts/` | `StarterPlayer > StarterCharacterScripts` |
| `src/StarterPlayer/StarterPlayerScripts/` | `StarterPlayer > StarterPlayerScripts` |

Subpasta funciona: `src/ServerScriptService/RetroVerse/Nucleo.lua` cria a pasta
`RetroVerse` se ela ainda não existir.

O pacote leva **somente `Script`, `LocalScript`, `ModuleScript` e as `Folder` do
caminho**. Fora do alcance: `ReplicatedStorage`, `StarterGui`, `Workspace`,
`Lighting`, qualquer `RemoteEvent`, `Model`, `Sound` ou `ScreenGui` como
instância, e a place do chefão (`boss-place/`, outro DataModel).

Na prática isso quase nunca trava nada, porque o projeto **cria essas coisas em
tempo de execução**: o `MainSystemInitializer` monta as pastas de
`ReplicatedStorage` e todos os Remotes, e as GUIs são construídas por código. Um
script novo que precise de um Remote deve criá-lo pelo `MainSystemInitializer`,
não pedir que alguém crie à mão.

## Passo a passo

### 1. Escolha o caminho e a extensão

O sufixo declara a classe, e o caminho declara o lugar. Não há adivinhação.

| Sufixo | Classe |
| --- | --- |
| `.server.lua` | `Script` |
| `.client.lua` | `LocalScript` |
| `.lua` | `ModuleScript` |

### 2. Escreva o cabeçalho

O `-- Nome:` precisa estar **nas 20 primeiras linhas** e bater exatamente com o
nome do arquivo sem o sufixo. O `tools/validar.sh` falha se divergir, e o
`tools/promover.sh` lê a mesma linha.

```lua
-- Nome: MeuSistemaServer
-- Coloque em: ServerScriptService
-- V1 — o que este script faz, em uma linha
```

Um bloco de comentário longo antes dessa linha empurra o `-- Nome:` para fora da
janela de 20 linhas e o nome deixa de ser verificável. Cabeçalho primeiro,
explicação depois.

### 3. Respeite as regras de código

- `task.wait()` / `task.spawn()` — nunca `wait()` / `spawn()`
- `objeto.Parent = nil` — nunca `:Destroy()` sem autorização
- Nenhuma lógica de economia ou DataStore em `LocalScript`
- GUI abre por botão, nunca por keybind
- Tamanhos de GUI em `Scale`, textos com `TextScaled = true`
- `ResetOnSpawn = false` em `ScreenGui` persistente
- Nunca dois scripts da mesma família ativos ao mesmo tempo

### 4. Feche as dependências `_G`

O `validar.sh` **falha** se o script consumir um `_G.X` que nenhum script define.
Cada API `_G` tem um dono só. Se o seu script for o dono, defina-a; se for
consumidor, espere por ela:

```lua
repeat task.wait() until _G.PlayerDataManager
```

Uma barreira dessas apontando para uma API sem dono espera **para sempre, sem
erro no Output**. É a falha mais difícil de achar no projeto, e por isso o
validador a trata como erro e não como aviso.

### 5. Valide

```bash
tools/validar.sh
```

Sete checagens, entre elas duplicata de família, barreiras `_G`, nome × cabeçalho
e sintaxe. Sai com código 1 se achar erro. Não siga adiante com o validador
vermelho.

### 6. Rode o `verificar` — e leia as duas listas

Actions → **Publicar somente código** → `verificar`. Ele não escreve nada.

O script novo deve aparecer como:

```
+ ServerScriptService > MeuSistemaServer (script novo)
```

**Agora confira a lista `?` do mesmo log**, que mostra o que existe no jogo e não
no repositório, com o cabeçalho `-- Nome:` e o tamanho de cada um.

Se algum `?` for o mesmo sistema salvo com outro nome — tamanho igual, ou
cabeçalho declarando o nome do seu arquivo — **ele não é novo**. Publicar assim
cria uma segunda cópia, e as duas rodam juntas. Registre o nome antigo em
`LEGACY_NAMES`, no topo de `tasks/apply_code_payload.luau`, e rode o `verificar`
de novo até o `+` virar `>`:

```lua
["StarterPlayer > StarterPlayerScripts > TeamMenuClient_V2"] = "TeamMenuClient",
```

Foi assim que nove scripts deixaram de ser duplicados na primeira publicação.

### 7. Publique

Actions → **Publicar somente código** → `publicar` + confirmação `PUBLICAR`.

Confirme no log a linha `[PUBLICAÇÃO]` e depois o histórico de versões no Creator
Dashboard. Reverter é por lá.

## Quando `central/` ainda vale

Só para o que o pipeline não alcança e que **realmente** exige o Studio:
instância 3D, `Model`, objeto em `Workspace` ou `StarterGui`, e a place do
chefão. Para esses, o fluxo antigo continua: `central/` → Studio →
`tools/promover.sh`.

Para os quatro contêineres da tabela, `central/` está aposentada.

## Checklist

- [ ] Caminho em `src/` espelha o contêiner do Studio
- [ ] Sufixo bate com a classe pretendida
- [ ] `-- Nome:` nas 20 primeiras linhas, igual ao nome do arquivo
- [ ] Sem `wait()`, `spawn()` ou `:Destroy()`
- [ ] Toda `_G` consumida tem dono
- [ ] `tools/validar.sh` sem erro
- [ ] `verificar` mostra `+` e nenhum `?` equivalente
- [ ] `publicar` confirmado no histórico de versões
