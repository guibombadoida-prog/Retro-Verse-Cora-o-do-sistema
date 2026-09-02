# Publicações — o que já entrou no jogo

Registro de toda publicação feita na place de produção (`133619220682618`).

**Anotar aqui é obrigatório.** Uma publicação muda o jogo para todo mundo e
muda a base de comparação do `verificar`: o agente seguinte que rodar o
workflow vai comparar o repositório contra um jogo que alguém alterou. Sem
este registro, ele não tem como saber quando nem por quê.

Entrada nova vai no topo. Copie os números da linha `[PUBLICAÇÃO]` do log.

---

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
