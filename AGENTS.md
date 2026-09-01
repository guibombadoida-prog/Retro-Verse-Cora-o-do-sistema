# Instruções para agentes — RetroVerse

Valem para qualquer agente que trabalhe neste repositório: Claude Code, Codex ou
outro. O `CLAUDE.md` aponta para cá; este é o arquivo canônico.

## O fato que muda tudo

**O dono do projeto não tem PC Windows e não consegue abrir o Roblox Studio.**

Nunca termine uma entrega pedindo que ele cole um script no Studio, arraste um
objeto, ou confira algo na árvore do Explorer. Ele não tem como fazer. Uma
entrega que depende disso não é uma entrega — é um script parado.

O caminho do repositório até o jogo é o workflow **Publicar somente código**
(`.github/workflows/publish-code-only.yml`), que compara, renomeia e cria scripts
direto na place de produção pela Open Cloud.

## Adicionar ou alterar script

O procedimento completo está em [`docs/ADICIONAR_SCRIPT.md`](docs/ADICIONAR_SCRIPT.md).
Leia antes de criar arquivo em `src/`. O resumo:

1. `src/<Contêiner>/<Nome>.<sufixo>.lua` — o caminho é o lugar no Studio
2. Cabeçalho `-- Nome: X` nas **20 primeiras linhas**, igual ao nome do arquivo
3. `tools/validar.sh` sem erro
4. Workflow em `verificar` — leia as listas `+` e `?` antes de publicar
5. Workflow em `publicar` com confirmação `PUBLICAR`

**Não coloque script novo em `central/`** quando ele for para `ReplicatedFirst`,
`ServerScriptService` ou os dois contêineres de `StarterPlayer`. O pipeline
publica esses direto. `central/` só serve para o que exige Studio de verdade:
3D, `Model`, `Workspace`, `StarterGui` e a place do chefão.

## Antes de publicar: o risco de duplicar

O `verificar` marca com `+` o que não existe no jogo e com `?` o que existe no
jogo e não no repositório. Um script salvo na place com nome diferente aparece
como `+` — publicar assim cria uma **segunda cópia rodando em paralelo**.

Compare tamanho e cabeçalho entre as duas listas. Quando forem o mesmo script,
registre o nome antigo em `LEGACY_NAMES`, no topo de
`tasks/apply_code_payload.luau`, e confirme que o `+` virou `>`.

## Regras de código

- `task.wait()` / `task.spawn()` — nunca `wait()` / `spawn()`
- `objeto.Parent = nil` — nunca `:Destroy()` sem autorização
- Nenhuma lógica de economia ou DataStore em `LocalScript`
- GUI abre por botão, nunca por keybind
- GUI com tamanhos em `Scale` e `TextScaled = true`
- `ResetOnSpawn = false` em `ScreenGui` persistente
- Nunca dois scripts da mesma família ativos ao mesmo tempo
- Cada API `_G` tem um dono só; consumidor espera com
  `repeat task.wait() until _G.X`

`tools/validar.sh` confere isso e mais a sintaxe. Sai com 1 se achar erro.

## Luau, não Lua 5.1

O jogo roda Luau: `+=`, `continue`, interpolação com crase e anotações de tipo
são válidos. O `validar.sh` usa `luac` como aproximação e traduz `+=` e
`continue` antes de checar, então **anotação de tipo pode gerar erro falso ali**.
A verificação real de sintaxe é o `luau-compile --only-parse` do workflow
**Validar código sem PC**.

## Chaves e segredos

A chave da Open Cloud vive **apenas** em GitHub Secrets. Nunca peça que ela seja
colada no chat, nunca a escreva em arquivo, nunca a inclua em log ou commit. Se o
usuário oferecer, recuse e explique onde ela deve ficar.

## Comunicação

O usuário trabalha pelo celular. Cite sempre o nome exato dos scripts alterados
no chat, no formato:

```
## Scripts Entregues — [Sistema]
Scripts Novos:        [Nome] — o que faz
Scripts Modificados:  [Nome] — o que mudou
Scripts Substituídos: ⚠️ REMOVER [Nome]
```

Responda em português.
