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

## Padrão de qualidade ao consertar ou atualizar script

Boa parte do trabalho aqui é **arrumar script bugado**, não escrever do zero. O
resultado tem que sair melhor do que entrou em três eixos: UI dinâmica, animação
e física. Corrigir o bug e devolver a tela travada de antes não conta como
correção.

Os números abaixo saíram de varredura no `src/` e dizem onde o projeto já está
bem e onde ele quebra.

### UI dinâmica

A base já é boa: `UDim2.fromScale` em 112 lugares, `TextScaled` em 253,
`ResetOnSpawn = false` em 40. Mantenha assim.

O buraco é a **proporção de tela**. Só existe **1** `UIAspectRatioConstraint` no
projeto inteiro, e o jogo é jogado no celular, onde a proporção varia muito
(18:9, 20:9, tablet, e o giro para paisagem). Um painel definido só em Scale vira
uma forma diferente em cada aparelho: o que é um quadrado num celular é um
retângulo achatado no outro.

- Todo painel com forma que importa (card, ícone, botão redondo, avatar) leva
  `UIAspectRatioConstraint`
- `Size` e `Position` em Scale; offset absoluto só para espessura de borda e
  espaçamento de 1 a 4 px — existem 17 usos de offset em `Size` que são dívida,
  não exemplo a seguir
- Lista e grade com `UIListLayout` / `UIGridLayout` e `AutomaticSize`, nunca
  posição calculada à mão
- Testar mentalmente em retrato **e** paisagem antes de entregar

### Animação

**58 tweens são criados no projeto e nenhum é cancelado.** Zero `:Cancel()`. Esse
é o padrão de bug mais comum aqui.

Toda animação disparada por evento repetível — dano, cura, energia, troca de
personagem — precisa guardar a referência e cancelar a anterior:

```lua
-- errado: cada HealthChanged cria mais um tween disputando a mesma barra
TweenService:Create(barra, info, { Size = novoTamanho }):Play()

-- certo: um tween por alvo, o anterior morre antes do novo nascer
if tweenBarra then
    tweenBarra:Cancel()
end
tweenBarra = TweenService:Create(barra, info, { Size = novoTamanho })
tweenBarra:Play()
```

Pior ainda é animar dentro de `task.spawn` com `task.wait` antes: em combate, uma
sequência de golpes dispara várias threads que acordam juntas e brigam pelo mesmo
objeto. O resultado é a barra tremendo em vez de deslizar.
`HealthDisplay.client.lua`, na barra de vida perdida, faz exatamente isso e é o
exemplo a **não** copiar.

Use a paleta de easing que o projeto já tem, em vez de inventar:

| Situação | Easing |
| --- | --- |
| Movimento e pulso contínuo | `Sine` |
| Barra reagindo a valor | `Quad` `Out` |
| Entrada de painel e botão | `Back` `Out` |
| Impacto e recompensa | `Bounce` `Out` |

Animação some junto com o dono: laço `while` de animação termina quando a GUI sai
(`while gui.Parent do`), e conexão de `RunService` é desconectada. O projeto usa
`Heartbeat` (4) e `RenderStepped` (3) — `RenderStepped` só para o que precisa
acompanhar a câmera; o resto é `Heartbeat`.

### Física avançada

Aqui o projeto **já está certo e não pode regredir**: zero `BodyVelocity`,
`BodyPosition` e `BodyGyro` em todo o `src/`. Eles estão obsoletos há anos e não
devem voltar por conveniência.

- Movimento por constraint: `LinearVelocity` (8 usos), `AngularVelocity` (2),
  `AlignPosition`, `AlignOrientation`, `VectorForce` — sempre com `Attachment`
- Empurrão instantâneo: `AssemblyLinearVelocity` (8 usos) ou `ApplyImpulse`,
  nunca escrever `Velocity` de peça solta
- Detecção por `Raycast` com `RaycastParams` e `FilterType.Exclude`, como o
  `NucleoCombate_V2` faz — nunca `Touched` para acerto de golpe, que perde hit em
  velocidade alta e dispara duas vezes parado
- Constraint criada por habilidade é removida quando a habilidade acaba, com
  `.Parent = nil`; constraint esquecida deixa o jogador voando
- Dano e knockback decididos **no servidor**. O cliente pede e mostra; nunca
  decide

### Antes de dizer que está pronto

- [ ] O bug relatado foi reproduzido no código antes de ser corrigido
- [ ] Nenhum tween novo sem `:Cancel()` do anterior
- [ ] Painel com forma tem `UIAspectRatioConstraint`
- [ ] Nenhum `BodyVelocity` / `BodyPosition` / `BodyGyro` introduzido
- [ ] Conexões e constraints criadas têm ponto de saída
- [ ] `tools/validar.sh` sem erro

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
