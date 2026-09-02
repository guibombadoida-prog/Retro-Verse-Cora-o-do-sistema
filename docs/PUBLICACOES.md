# Publicações — o que já entrou no jogo

Registro de toda publicação feita na place de produção (`133619220682618`).

**Anotar aqui é obrigatório.** Uma publicação muda o jogo para todo mundo e
muda a base de comparação do `verificar`: o agente seguinte que rodar o
workflow vai comparar o repositório contra um jogo que alguém alterou. Sem
este registro, ele não tem como saber quando nem por quê.

Entrada nova vai no topo. Copie os números da linha `[PUBLICAÇÃO]` do log.

---

## 2026-09-02 05:32 UTC — HUD do HP de volta à posição original

`[PUBLICAÇÃO] 1 atualizados, 0 renomeados, 0 criados, 0 pastas criadas`
Retorno: `["published", 58, 57, 1, 0, 0, 0]` — execução #18, `main` em `036f41c`

**`HealthDisplay` V8.5** — o dono pediu a posição exatamente como estava antes
das alterações, e é isso que esta publicação faz: desfaz as duas mudanças de
posição das 05:24 e das 05:28 e deixa o HUD onde o V8.2 o tinha.

```lua
HudRoot.AnchorPoint = Vector2.new(0.5, 0)
HudRoot.Position = UDim2.new(0.5, 0, 0, getTopInset() + 8)
```

O original foi lido do git (`74322fe`, o V8.2, e `dd9ef69`, o V8 do Codex),
não da memória — as duas revisões têm as quatro propriedades do `HudRoot`
byte a byte iguais a esta. A constante `MARGEM_TOPO` saiu junto; o recuo
voltou a ser o literal `+ 8` sobre o `GetGuiInset`.

**O tamanho continua corrigido.** Só a posição voltou. O HUD segue entre 18.6%
e 24.2% da largura (era 54% no print do dono) e o `StatusIndicator` continua no
`HeaderBar`, fora da barra de vida.

## 2026-09-02 05:28 UTC — HUD do HP no topo colado

`[PUBLICAÇÃO] 1 atualizados, 0 renomeados, 0 criados, 0 pastas criadas`
Retorno: `["published", 58, 57, 1, 0, 0, 0]` — execução #17, `main` em `813c17f`

**`HealthDisplay` V8.4** — o canto superior direito das 05:24 não agradou; o
pedido virou "centralizado, o mais para cima possível". A âncora voltou para
`(0.5, 0)` e o recuo do topo caiu de 8 px para `MARGEM_TOPO = 2`, ainda somando
o `GetGuiInset` para não entrar embaixo da barra do Roblox.

> Desfeito pelo V8.5 quatro minutos depois. Fica registrado porque chegou a
> rodar no jogo: quem comparar o place com o repositório neste intervalo vai
> encontrar esta versão.

## 2026-09-02 05:24 UTC — HUD do HP no canto superior direito

`[PUBLICAÇÃO] 1 atualizados, 0 renomeados, 0 criados, 0 pastas criadas`
Retorno: `["published", 58, 57, 1, 0, 0, 0]` — execução #16, `main` em `d684d2e`

**`HealthDisplay` V8.3** — o HUD estava ancorado no topo centralizado, e
centralizado no topo é o meio da tela em celular deitado: ficava por cima do
personagem e disputava espaço com o aviso de alvo, que também é centralizado.

A âncora passou de `(0.5, 0)` para `(1, 0)` e a posição para a borda direita
menos a margem. A âncora no canto importa por causa do `UIScale`: ele encolhe
o HUD em direção ao ponto ancorado, então o canto superior direito fica parado
em qualquer escala, em vez de a caixa deslizar conforme o aparelho. O recuo do
topo continua somando o `GetGuiInset` para não entrar embaixo da barra do
Roblox.

## 2026-09-02 05:18 UTC — HUD do HP no tamanho certo

`[PUBLICAÇÃO] 1 atualizados, 0 renomeados, 0 criados, 0 pastas criadas`
Retorno: `["published", 58, 57, 1, 0, 0, 0]` — execução #15, `main` em `74322fe`

**`HealthDisplay` V8.2** — a correção das 01:10 tirou o HUD do tamanho máximo
mas parou em 26% a 30% da largura, e o dono pediu de novo que diminuísse.
Agora fica entre 18.6% e 24.2%, do celular pequeno ao desktop:

| aparelho | original | V8.1 | V8.2 |
| --- | --- | --- | --- |
| celular pequeno | 30% | 30.4% | 24.2% |
| celular do print | 54% | 27.0% | 19.6% |
| tablet | 26% | 26.2% | 22.3% |
| desktop | 22% | 21.9% | 18.6% |

As frações viraram constantes com nome no topo do arquivo — `FRACAO_LARGURA`,
`FRACAO_ALTURA`, `ESCALA_MIN`, `ESCALA_MAX` — para o próximo ajuste ser de uma
linha. `ESCALA_MIN` ficou em 0.46 porque abaixo disso o texto, que tem mínimo
de 8 a 9 px por `UITextSizeConstraint`, para de caber.

## 2026-09-02 01:10 UTC — correções da publicação anterior + menu com busca

`[PUBLICAÇÃO] 3 atualizados, 0 renomeados, 0 criados, 0 pastas criadas`
Retorno: `["published", 58, 55, 3, 0, 0, 0]` — execução #14, `main` em `20e283d`

Duas correções de defeitos que o dono viu no jogo depois da publicação das
00:59, mais o menu de personagens.

- **`SpawnSystem` V9.1** — as duas placas da zona segura mostravam o verso.
  Ambas usavam `Face = Back`, a face +Z local: a da borda +Z apontava para
  fora, e a da borda -Z era girada 180°, o que também a virava para fora. A
  rotação saiu e cada placa passou a declarar a face voltada ao centro.
- **`HealthDisplay` V8.1** — o HUD saía no tamanho máximo em qualquer tela
  grande. A escala usava `viewport.X - 24`, ou seja, a tela inteira como
  espaço do HUD, então a largura nunca limitava e o valor batia no teto de
  1.15. Numa viewport de 900x400 ocupava 54% da largura; agora ocupa 27%.
  Junto, o `StatusIndicator` saiu de cima da barra de vida — sobreposição que
  existia desde o V7 e só ficou visível com o HUD grande.
- **`CharacterSystemClient` V11** — barra de pesquisa na loja e no inventário,
  grade por `UIGridLayout` recalculada quando a `ViewportSize` muda (antes o
  `getUIScale()` rodava uma vez só e girar o celular não refazia nada), e
  cards agrupados em seções por raridade.

## 2026-09-02 00:59 UTC — três sistemas novos + HUD do Codex

`[PUBLICAÇÃO] 5 atualizados, 0 renomeados, 0 criados, 0 pastas criadas`
Retorno: `["published", 58, 53, 5, 0, 0, 0]` — execução #13, a partir da `main`
em `6fc10e0` (PRs #5 e #7 mesclados)

- **`LoadingScreen` V3** — passa a esperar os assets baixarem de fato, via
  `ContentProvider:PreloadAsync` em lotes, em vez de sair no `game:IsLoaded()`;
  a barra mostra o download real; botão PULAR aparece após 5s.
- **`SpawnSystem` V9** — base da zona segura detalhada, com faixa visível
  marcando o limite (que antes só se descobria ao levar dano) e placas
  identificando a área sem PvP.
- **`DuelSystemServer` V3** — arena de 60x60 para 110x110 studs, arquibancada de
  48 assentos em quatro lados, remotes `DuelSpectate` e `DuelSpectators`.
  Nenhum cliente chama esses remotes ainda: a arquibancada existe e ninguém
  consegue subir nela.
- **`HealthDisplay` V8** (Codex, PR #7) — HUD responsivo por `UIScale`, reage a
  `ViewportSize`, desconecta o Humanoid anterior, escuta `MaxHealth`. Substituiu
  o V8 que eu havia publicado às 20:22.
- **`EnergySystemServer`** (Codex, PR #7) — física de energia.

## 2026-09-01 20:22 UTC — HealthDisplay V8

`[PUBLICAÇÃO] 1 atualizados, 0 renomeados, 0 criados, 0 pastas criadas`
Retorno: `["published", 58, 57, 1, 0, 0, 0]` — execução #10

Camada de animação do HUD reescrita: vazamento do pulso de borda, borda que
travava na cor de um flash, barra de vida perdida tremendo em combate e
indicador de status deformando por proporção de tela.

> Substituído depois pelo V8 do Codex (PR #7), que resolve os mesmos defeitos
> e ainda desconecta o Humanoid anterior e reage a `ViewportSize`.

## 2026-09-01 19:57 UTC — primeira publicação sem PC

`[PUBLICAÇÃO] 23 atualizados, 9 renomeados, 1 criados, 1 pastas criadas`
Retorno: `["published", 58, 28, 23, 9, 1, 0]` — execução #8

Primeiro deploy do projeto feito inteiro pelo celular, sem Roblox Studio.

Atualizou 23 scripts, entre eles `AwakeningMeterServer`, `AwakeningSystemServer`,
`DailyRewardsServer`, `DataManager`, `StatService`, `CharacterSystemClient`,
`BossRaidServer` e `MusicCatalogServer`.

Renomeou 9 instâncias para o nome canônico do repositório: `Anti-Anti-Lag Script`
→ `AntiLag`, `Heatlh` → `Health`, `Client Sync` → `ClientSync`,
`MISSIONS MENU CLIENT` → `MissionsMenuClient`, `Simple Character Coin Drop` →
`SimpleCharacterCoinDrop`, `MusicPlayerClient` → `MusicPlayerClient_V2`,
`RetroHotbarClient_V1` → `RetroHotbarClient`, `TeamMenuClient` →
`TeamMenuClient_V2`, `TutorialMenuClient` → `TutorialMenuClient_V2`.

Criou `ServerScriptService > RetroVerse > NucleoCombate_V2` e a pasta
`RetroVerse`.

O caso `Heatlh` → `Health` consertou um bug de produção: `PassiveSystemServer`
faz `FindFirstChild("Health")` para desligar a regeneração na passiva Casca
Dura, e como nada em `StarterCharacterScripts` se chamava `Health`, o Roblox
injetava o script padrão dele no personagem. Rodavam duas regenerações e a
passiva desligava a errada.
