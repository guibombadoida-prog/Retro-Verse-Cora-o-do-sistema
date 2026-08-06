# Arquitetura — RetroVerse

Inventário completo dos scripts do repositório, com a versão que está no cabeçalho
de cada arquivo e o mapa de dependências entre eles.

> A coluna **Nome no Studio** é o nome que o objeto precisa ter dentro do Roblox
> Studio. Onde ela difere do nome do arquivo, o cabeçalho do próprio script exige
> aquele nome específico.

---

## 1. `ServerScriptService` — Scripts de servidor

| Arquivo | Nome no Studio | Ver. | Função |
|---|---|:--:|---|
| `AchievementSystemServer.server.lua` | `AchievementSystemServer` | V3 | Conquistas dinâmicas (criadas em jogo, sem Studio) |
| `AdminRegistryServer.server.lua` | `AdminRegistryServer` | V1 | Registro único de admins no DataStore — fonte da verdade de `_G.AdminRegistry` |
| `AdminSystemServer.server.lua` | `AdminSystemServer` | V8 | Comandos e ações de admin |
| `AntiLag.server.lua` | *(não declarado)* | V2 | Varre a Workspace e remove objetos de lag sem tocar em materiais/VFX |
| `AntiToolSystem.server.lua` | `AntiToolSystem` | V2 | Bloqueio de ferramentas indevidas |
| `AwakeningSystemServer.server.lua` | `AwakeningSystemServer` | V2 | Sistema de Despertar (personagens evoluídos). ⚠️ **V3 em `central/`, aguardando instalação** — corrige a criação de Despertar sem personagem original |
| `BossRaidServer.server.lua` | `BossRaidServer` | V2 | Catálogo de bosses via DataStore + teleporte para a *place* do chefe |
| `CharacterCatalogServer.server.lua` | `CharacterCatalogServer` | V6 | Catálogo de personagens 100% dinâmico |
| `CharacterLevelServer.server.lua` | `CharacterLevelServer` | V1 | Nível **por personagem** (1–30): curva de XP, slots de passiva e energia |
| `CharacterStatsServer.server.lua` | `CharacterStatsServer` | V2 | Atributos por personagem |
| `DailyRewardsServer.server.lua` | `DailyRewardsServer` | V6 | Recompensas diárias e recuperação de dia perdido. O V6 tirou o personagem-fantasma "Daily Champion" do bônus do dia 6 |
| `DamageAttribution.server.lua` | `DamageAttribution` | V4 | Atribui a autoria de cada dano — base do sistema de kill |
| `DataManager.server.lua` | `DataManager` | V8 | DataStore, moedas, bounty, inventário. **Dono de `_G.PlayerDataManager`** |
| `DuelSystemServer.server.lua` | `DuelSystemServer` | V2 | Duelos 1v1 |
| `EnergySystemServer.server.lua` | `EnergySystemServer` | V1 | Energia/stamina para habilidades |
| `GameManager.server.lua` | `GameManager` | V9 | Preços, vida e seleção de personagem |
| `GlobalSync.server.lua` | `GlobalSync` | V2 | Dono único do sync periódico de `UpdateStats` |
| `LoadingScreenServer.server.lua` | `LoadingScreenServer` | V2 | Lado servidor do *handshake* da tela de carregamento |
| `MainSystemInitializer.server.lua` | `MainSystemInitializer` | V2 | Cria pastas e Remotes, conecta sistemas, monitora |
| `MissionSystemServer.server.lua` | `MissionSystemServer` | V2 | Missões |
| `RecruitJourneyServer.server.lua` | `RecruitJourneyServer` | V2 | Jornada do Recruta: capítulos de onboarding, com DataStore próprio (`RVRecruitJourneyV1`) |
| `NPC_Server_V2.server.lua` | `NPC_Server_V2` | V2 | NPCs com recompensa proporcional à vida máxima |
| `NpcPassiveBridge.server.lua` | `NpcPassiveBridge` | V2 | Faz as passivas do jogador valerem contra NPCs |
| `PassiveSystemServer.server.lua` | `PassiveSystemServer` | V8 | Sistema de passivas |
| `SpawnSystem.server.lua` | `SpawnSystem` | V8 | Lobby, zona segura, spawn no mapa, modo espectador |
| `StatService.server.lua` | `StatService` | V3 | **Dono único** de MaxHealth/WalkSpeed/Jump. Agrega os 23 atributos por fonte e resolve a fórmula de dano |
| `StatusEffectServer.server.lua` | `StatusEffectServer` | V1 | Efeitos temporários de status |
| `TeamDamageProtection.server.lua` | `TeamDamageProtection` | V4 | Bloqueia dano entre membros do mesmo time |
| `TeamSystemServer.server.lua` | `TeamSystemServer` | V4 | Times e convites |
| `TradeSystemServer.server.lua` | `TradeSystemServer` | V1 | Trocas entre jogadores |
| `TutorialSystemServer.server.lua` | `TutorialSystemServer` | V3 | Tutorial em passos |
| `WantedSystemServer.server.lua` | `WantedSystemServer` | V2 | Bounty / procurado |

### ModuleScripts

| Arquivo | Nome no Studio | Local | Ver. | Função |
|---|---|---|:--:|---|
| `PassiveCatalog.lua` | `PassiveCatalog` | `ServerScriptService` | V1 | **Conteúdo** das 27 passivas (stats, gatilhos, custo por nível, vfx). Separado de propósito: o servidor tem a lógica, este arquivo tem os dados |
| `RetroVerse/NucleoCombate_V2.lua` | `NucleoCombate_V2` | `ServerScriptService > RetroVerse` | V2 | Pipeline único de cálculo de dano (Regra 12) |

`PassiveCatalog` é carregado por `PassiveSystemServer` via
`ServerScriptService:WaitForChild("PassiveCatalog", 30)` — precisa estar na **raiz**
de `ServerScriptService`, não dentro da pasta `RetroVerse`. Adicionar passiva nova é
mexer só nele.

`NucleoCombate_V2` é consumido por
`require(ServerScriptService.RetroVerse.NucleoCombate_V2)`. O nome com `_V2` é
**obrigatório**: o caminho do `require` é literal, então renomear o objeto quebra
todas as Tools que consomem o núcleo.

---

## 2. `StarterPlayer > StarterPlayerScripts` — LocalScripts

| Arquivo | Nome no Studio | Ver. | Função |
|---|---|:--:|---|
| `AchievementMenuClient.client.lua` | `AchievementMenuClient` | V2 | Menu de conquistas + gerenciador para admin |
| `AdminMenuClient.client.lua` | `AdminMenuClient` | V9 | Painel de admin |
| `BossRaidClient.client.lua` | `BossRaidClient` | V2 | Menu de raids de boss |
| `CharacterStatsAdminClient.client.lua` | `CharacterStatsAdminClient` | V2 | Edição de atributos em jogo (admin) |
| `CharacterSystemClient.client.lua` | `CharacterSystemClient` | V7 | Loja e inventário de personagens, com atributos |
| `ClientSync.client.lua` | `ClientSync` | — | Cache local de dados; expõe `_G.updatePlayerData` |
| `DailyRewardsClient.client.lua` | `DailyRewardsClient` | V1 | GUI da recompensa diária |
| `DuelMenuClient.client.lua` | `DuelMenuClient` | V2 | Menu de duelos |
| `HealthDisplay.client.lua` | `HealthDisplay` | V4 | Barra de vida + barra de energia (estilo retro) |
| `MissionsMenuClient.client.lua` | `MissionsMenuClient` | V2 | Menu de missões |
| `RecruitJourneyClient.client.lua` | `RecruitJourneyClient` | V2 | Menu da Jornada do Recruta (categoria `RECRUTA`, ordem 3) |
| `MusicPlayerClient_V2.client.lua` | `MusicPlayerClient_V2` | V5 | Player de música (abre só pelo menu unificado) |
| `PassiveMenuClient.client.lua` | `PassiveMenuClient` | V3 | Menu de passivas |
| `RetroHotbarClient.client.lua` | `RetroHotbarClient` | V2 | Hotbar/backpack retrô, com perfis por dispositivo |
| `TeamMenuClient_V2.client.lua` | `TeamMenuClient_V2` | V6 | Interface de times |
| `TradeMenuClient.client.lua` | `TradeMenuClient` | V1 | Interface de trocas |
| `TutorialMenuClient_V2.client.lua` | `TutorialMenuClient_V2` | V6 | Tutorial interativo |
| `UnifiedMenuClient.client.lua` | `UnifiedMenuClient` | V3 | **Menu ☰ central.** Dono de `_G.RegisterMenuCategory` |
| `WantedClient.client.lua` | `WantedClient` | V2 | HUD de procurado |

`UnifiedMenuClient` é o hub: todos os outros menus se registram nele via
`_G.RegisterMenuCategory(nome, ícone, abrir, fechar, ordem)` em vez de criar botão
flutuante próprio. Sem ele nenhum menu tem como ser aberto.

---

## 3. `StarterPlayer > StarterCharacterScripts`

| Arquivo | Nome no Studio | Classe | Ver. | Função |
|---|---|---|:--:|---|
| `Health.server.lua` | `Health` | `Script` | V1 | Bloqueia a regeneração automática do Roblox |
| `SimpleCharacterCoinDrop.server.lua` | `SimpleCharacterCoinDrop` | `Script` | V2 | Dropa 10% das moedas ao morrer |

⚠️ **`Health` precisa ter esse nome exato.** O motor do Roblox injeta um `Script`
chamado `Health` no personagem a cada spawn, mas só se ainda não existir um com esse
nome. Nosso script ocupa a vaga — renomear reativa a regeneração padrão.

---

## 4. `ReplicatedFirst`

| Arquivo | Nome no Studio | Classe | Ver. | Função |
|---|---|---|:--:|---|
| `LoadingScreen.client.lua` | `LoadingScreen` | `LocalScript` | V2 | Tela de carregamento retro arcade |

Trabalha em par com `LoadingScreenServer` (V2) via os remotes `LoadingStage`,
`LoadingReady` e `QueryLoadingReady`, com trava anti-congelamento
(`MIN_DISPLAY` / `MAX_WAIT`).

---

## 5. Mapa de dependências `_G`

O projeto não usa `require` entre sistemas de servidor — a comunicação é por
tabelas e funções publicadas em `_G`. Cada API tem **um dono único**.

### APIs de servidor

| API `_G` | Dono | Consumido por |
|---|---|---|
| `PlayerDataManager` | `DataManager` | 25 scripts — é a base de tudo |
| `GameContentConfig` | `DataManager` | `CharacterCatalogServer`, `GameManager` |
| `StatService` | `StatService` | `PassiveSystemServer`, `NpcPassiveBridge`, `StatusEffectServer`, `CharacterStatsServer`, `NucleoCombate_V2` |
| `CharacterLevel` | `CharacterLevelServer` | `PassiveSystemServer`, `NpcPassiveBridge`, `EnergySystemServer` |
| `AdminRegistry` | `AdminRegistryServer` | `AchievementSystemServer`, `AdminSystemServer`, `AwakeningSystemServer`, `BossRaidServer`, `CharacterCatalogServer`, `CharacterStatsServer` |
| `CharacterCatalog` | `CharacterCatalogServer` | `AchievementSystemServer`, `AdminSystemServer` |
| `GameManagerConfig` | `GameManager` | `AwakeningSystemServer`, `CharacterCatalogServer`, `TradeSystemServer`, `StatService` |
| `SelectCharacterFunction` | `GameManager` (embrulhado por `MainSystemInitializer`) | `MainSystemInitializer` |
| `OnCharacterSelected` | `SpawnSystem` (embrulhado por `StatService`, com vigia) | `GameManager`, `GlobalSync`, `MainSystemInitializer` |
| `SetSpectatorMode`, `ReloadMapSpawnPoints`, `DebugSpawnState`, `ListAllPlayers` | `SpawnSystem` | `MainSystemInitializer` |
| `DebugPlayerStatus`, `TeleportToSafeZone`, `ForceSelectCharacter` | `GlobalSync` | `MainSystemInitializer` |
| `ResetPlayerBarrier` | `MainSystemInitializer` | — (debug manual) |
| `RegisterAttack`, `DamageAttribution` | `DamageAttribution` | `NPC_Server_V2`, `TeamSystemServer`, `PassiveSystemServer`, `StatusEffectServer`, `NucleoCombate_V2` |
| `CanDamagePlayer`, `CreateTeamBlockEffect` | `TeamDamageProtection` | `NucleoCombate_V2` |
| `GetPlayerTeam`, `IsTeammate`, `GetAllTeams`, `GetTeamMembers`, `GetAvailableTeamColors` | `TeamSystemServer` | `BossRaidServer`, `DuelSystemServer`, `GlobalSync`, `TeamDamageProtection`, `MainSystemInitializer` |
| `AwakeningSystem` | `AwakeningSystemServer` | `GameManager`, `StatService` |
| `PassiveSystem` | `PassiveSystemServer` | `NpcPassiveBridge`, `Health`, `StatService` |
| `EnergySystem` | `EnergySystemServer` | `PassiveSystemServer` |
| `StatusEffect` | `StatusEffectServer` | — |
| `CharacterStats` | `CharacterStatsServer` | `StatService` (chama `.refresh` ao equipar). O `CharacterStatsAdminClient` fala por Remote, não por `_G` |
| `DailyRewards` | `DailyRewardsServer` | — |
| `RecruitJourney` | `RecruitJourneyServer` | — |
| `BossRaid` | `BossRaidServer` | — |
| `WantedSystem` | `WantedSystemServer` | — |
| `NpcSystem` | `NPC_Server_V2` | — |
| `NpcPassiveBridge` | `NpcPassiveBridge` | — |
| `CheckAchievements` | `AchievementSystemServer` | — |
| `ForceUnblockTools` | `AntiToolSystem` | — |
| `ResetTutorial` | `TutorialSystemServer` | — |

### APIs de cliente

| API `_G` | Dono | Consumido por |
|---|---|---|
| `RegisterMenuCategory`, `SetMenuNotification`, `UnifiedMenu` | `UnifiedMenuClient` | todos os menus de cliente |
| `updatePlayerData`, `GetCachedPlayerData`, `ForceUpdateStats` | `ClientSync` | `TradeMenuClient` |
| `Open*` / `Close*` (Shop, Inventory, AdminMenu, TutorialMenu, TeamMenu, MusicPlayer, DailyRewards, PassiveMenu, MissionsMenu, CharacterStatsAdmin, AchievementList, TradePlayerList, DuelPlayerList) | cada menu registra o seu par | `UnifiedMenuClient` |

### Comandos de diagnóstico

Cada sistema expõe seu próprio `_G.Debug*` para uso no console do servidor:
`DebugAchievements`, `DebugAdmins`, `DebugAntiTool`, `DebugAttribution`,
`DebugAwakening`, `DebugCatalog`, `DebugCharacterLevel`, `DebugCharacterStats`,
`DebugDailyRewards`, `DebugEfeitos`, `DebugEnergy`, `DebugGameManager`,
`DebugMovement`, `DebugNpcBridge`, `DebugNucleo`, `DebugPassives`,
`DebugPlayerStatus`, `DebugRecruitJourney`, `DebugSpawnState`, `DebugStats`,
`DebugTeams`, `DebugTutorial`.

O `StatService` traz também `_G.SimulateDamage("Atacante", "Vítima", 50, "Melee")`,
que roda a fórmula de dano inteira e imprime cada etapa — dá para conferir
balanceamento sem bater em ninguém.

### ⚠️ `_G.OnCharacterSelected` tem três donos

Esse é o ponto mais frágil da arquitetura, e é intencionalmente documentado assim
no cabeçalho do `StatService` V3:

- `SpawnSystem` (linha 1043) faz **atribuição direta**: `_G.OnCharacterSelected = function...`
- `StatService` (V3) **embrulha** o anterior e chama quem estava antes
- `MainSystemInitializer` faz o mesmo com `_G.SelectCharacterFunction`

Como a ordem de carga de `Script` em `ServerScriptService` não é garantida, o
`SpawnSystem` pode carregar **depois** do `StatService` e apagar o wrapper em
silêncio. Por isso o `StatService` tem um **vigia** que reconfere a cada 10s e
reinstala o wrapper por cima, sem quebrar quem sobrescreveu. Se você ver
`[STAT V3] _G.OnCharacterSelected foi sobrescrito — reinstalado por cima` no Output,
é esse mecanismo funcionando — não é erro.

Consequência prática: **qualquer script novo que precise reagir ao equipar deve
embrulhar, nunca sobrescrever** `_G.OnCharacterSelected`.

---

## 6. Barreiras de espera e o que ainda falta

### Cadeia bloqueante — fechada ✅

São **22 barreiras** `repeat task.wait() until ...` no projeto. Se a dependência não
existir, elas esperam **para sempre, sem erro no Output** — daí a importância de
conferir esta lista antes de remover qualquer script de `ServerScriptService`.

Todas estão hoje satisfeitas. As de dependência composta (número = linha do `until`):

| Script | Linha | Espera por | Atendido por |
|---|:--:|---|---|
| `PassiveSystemServer` | 75 | `PlayerDataManager` + `CharacterLevel` + `StatService` | `DataManager`, `CharacterLevelServer`, `StatService` |
| `PassiveSystemServer` | 77 | `WaitForChild("PassiveCatalog", 30)` | `PassiveCatalog.lua` |
| `NpcPassiveBridge` | 78 | `PlayerDataManager` + `CharacterLevel` + `PassiveSystem` + `StatService` | idem + `PassiveSystemServer` |
| `CharacterStatsServer` | 83 | `PlayerDataManager` + `StatService` | `DataManager`, `StatService` |
| `EnergySystemServer` | 50 | `PlayerDataManager` + `CharacterLevel` | `DataManager`, `CharacterLevelServer` |
| `CharacterLevelServer` | 41 | `PlayerDataManager.getCharacterProgress` | `DataManager` V8 |
| `StatusEffectServer` | 64 | `StatService` | `StatService` |
| `TeamDamageProtection` | 28 | `IsTeammate` | `TeamSystemServer` |

As outras 15 esperam **só** por `_G.PlayerDataManager`, ou seja, todas dependem do
`DataManager` estar presente: `AchievementSystemServer`:101 · `AdminSystemServer`:42 ·
`AwakeningSystemServer`:51 · `BossRaidServer`:28 · `DailyRewardsServer`:34 ·
`DuelSystemServer`:47 · `GameManager`:39 · `MissionSystemServer`:12 ·
`NPC_Server_V2`:46 · `SimpleCharacterCoinDrop`:20 · `StatService`:146 ·
`TeamSystemServer`:24 · `TradeSystemServer`:44 · `TutorialSystemServer`:23 ·
`WantedSystemServer`:55

Note que `PassiveCatalog` é o único caso que **avisa** quando falta: o
`WaitForChild` expira em 30s, emite `warn` e faz `return`. Os 22 `repeat` falham
calados.

### Compatibilidade verificada

O `CharacterLevelServer` exige cinco funções do `DataManager`, todas presentes na V8:
`getCharacterProgress`, `addCharacterXp`, `setCharacterLevel`, `getPlayerData`,
`savePlayerData`. Os cabeçalhos do `StatService` e do `CharacterLevelServer` dizem
"DEPENDE DE: DataManager V7" — a V8 é compatível, apenas ampliou os limites de passiva.

O `PassiveSystemServer` consome dez APIs do `PassiveCatalog` (`LISTA`, `MAX_NIVEL`,
`obter`, `custoDoNivel`, `contar`, `statsNoNivel`, `statsRecargaNoNivel`,
`specialNoNivel`, `chanceNoNivel`, `descricaoNoNivel`) — todas existem na V1 do catálogo.

### ⚠️ Ainda ausente (opcional, não trava)

Duas APIs são consumidas mas não têm dono no repositório. As duas estão protegidas
por `if`, então só desligam o recurso:

| API | Consumidor | O que se perde |
|---|---|---|
| `_G.PassiveVFX` | `PassiveSystemServer` (linhas 430, 511, 536) | Efeitos visuais das passivas |
| `_G.SetCoinMultiplier` | `DailyRewardsServer` (linhas 268, 529) | Multiplicador de moedas da recompensa diária |

As 27 passivas do `PassiveCatalog` já declaram seu campo `vfx` (`BRILHO_METALICO`,
`ESPELHO_INVERTIDO`, `CHAMA_RETRO`, `NEGACAO_BRANCA`…), e o `PassiveSystemServer`
chama `_G.PassiveVFX.disparar(player, passiva.vfx, duracao)`. O contrato está
definido dos dois lados — falta só o script que implementa.

### Escopo declarado do `StatService`

O cabeçalho do `StatService` V3 avisa que ele **não aplica dano** — só calcula e
guarda. Quem deveria chamar `computeDamage` é um `DamageService` que não existe. Na
prática, hoje quem faz essa conta em combate é o `NucleoCombate_V2`, que consome
`_G.StatService.getEffectiveResistance` / `getDamageMultiplier` diretamente
(linhas 392-426) e degrada com aviso se o `StatService` não estiver carregado.

---

## 7. Boss Fight — *place* separada

A luta contra chefão roda em uma **place diferente**, compartilhando o mesmo
DataStore (`RetroVerseDataV3_Awakening`). Regras completas em
[`Diretrizes_Sistema_Chefao_Boss.md`](Diretrizes_Sistema_Chefao_Boss.md).

Segundo a V5 daquele documento, a place do chefe precisa de **cópias locais** destes
scripts (todos já presentes neste repositório), apontando para os mesmos nomes de
DataStore e tópicos de `MessagingService` da place principal:

`DataManager` · `AdminRegistryServer` · `CharacterCatalogServer` ·
`AchievementSystemServer` · `TeamDamageProtection` · `LoadingScreenServer` ·
`MusicPlayerClient`

E mais cinco scripts exclusivos do sistema de chefão, que **ainda não existem** neste
repositório:

| Script | Papel |
|---|---|
| `TeleportDataReceiver` | Recebe os dados enviados no teleporte da place principal |
| `SessionReadyGate` | Só libera a GUI de inventário quando **todos** da sessão carregarem |
| `ConfigStore` | Configuração de recompensas/loot editável em jogo |
| `NoPvpProtection` | Bloqueia dano jogador→jogador (adaptação do `TeamDamageProtection`) |
| `ExitTeleport` | Teleporte forçado de saída para a place `133619220682618` |

O par `BossRaidServer` / `BossRaidClient` (V2), na place principal, é a porta de
entrada: catálogo de bosses via DataStore e o teleporte para essas places.
