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
| `AwakeningSystemServer.server.lua` | `AwakeningSystemServer` | V2 | Sistema de Despertar (personagens evoluídos) |
| `BossRaidServer.server.lua` | `BossRaidServer` | V2 | Catálogo de bosses via DataStore + teleporte para a *place* do chefe |
| `CharacterCatalogServer.server.lua` | `CharacterCatalogServer` | V6 | Catálogo de personagens 100% dinâmico |
| `CharacterStatsServer.server.lua` | `CharacterStatsServer` | V2 | Atributos por personagem |
| `DailyRewardsServer.server.lua` | `DailyRewardsServer` | V5 | Recompensas diárias e recuperação de dia perdido |
| `DamageAttribution.server.lua` | `DamageAttribution` | V4 | Atribui a autoria de cada dano — base do sistema de kill |
| `DataManager.server.lua` | `DataManager` | V8 | DataStore, moedas, bounty, inventário. **Dono de `_G.PlayerDataManager`** |
| `DuelSystemServer.server.lua` | `DuelSystemServer` | V2 | Duelos 1v1 |
| `EnergySystemServer.server.lua` | `EnergySystemServer` | V1 | Energia/stamina para habilidades |
| `GameManager.server.lua` | `GameManager` | V9 | Preços, vida e seleção de personagem |
| `GlobalSync.server.lua` | `GlobalSync` | V2 | Dono único do sync periódico de `UpdateStats` |
| `LoadingScreenServer.server.lua` | `LoadingScreenServer` | V2 | Lado servidor do *handshake* da tela de carregamento |
| `MainSystemInitializer.server.lua` | `MainSystemInitializer` | V2 | Cria pastas e Remotes, conecta sistemas, monitora |
| `MissionSystemServer.server.lua` | `MissionSystemServer` | V2 | Missões |
| `NPC_Server_V2.server.lua` | `NPC_Server_V2` | V2 | NPCs com recompensa proporcional à vida máxima |
| `NpcPassiveBridge.server.lua` | `NpcPassiveBridge` | V2 | Faz as passivas do jogador valerem contra NPCs |
| `PassiveSystemServer.server.lua` | `PassiveSystemServer` | V8 | Sistema de passivas |
| `SpawnSystem.server.lua` | `SpawnSystem` | V8 | Lobby, zona segura, spawn no mapa, modo espectador |
| `StatusEffectServer.server.lua` | `StatusEffectServer` | V1 | Efeitos temporários de status |
| `TeamDamageProtection.server.lua` | `TeamDamageProtection` | V4 | Bloqueia dano entre membros do mesmo time |
| `TeamSystemServer.server.lua` | `TeamSystemServer` | V4 | Times e convites |
| `TradeSystemServer.server.lua` | `TradeSystemServer` | V1 | Trocas entre jogadores |
| `TutorialSystemServer.server.lua` | `TutorialSystemServer` | V3 | Tutorial em passos |
| `WantedSystemServer.server.lua` | `WantedSystemServer` | V2 | Bounty / procurado |

### `ServerScriptService > RetroVerse` — ModuleScript

| Arquivo | Nome no Studio | Ver. | Função |
|---|---|:--:|---|
| `RetroVerse/NucleoCombate_V2.lua` | `NucleoCombate_V2` | V2 | Pipeline único de cálculo de dano (Regra 12). Consumido por `require(ServerScriptService.RetroVerse.NucleoCombate_V2)` |

O nome com `_V2` é **obrigatório** aqui: o caminho do `require` é literal, então
renomear o objeto quebra todas as Tools que consomem o núcleo.

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
| `PlayerDataManager` | `DataManager` | 23 scripts — é a base de tudo |
| `GameContentConfig` | `DataManager` | `CharacterCatalogServer`, `GameManager` |
| `AdminRegistry` | `AdminRegistryServer` | `AchievementSystemServer`, `AdminSystemServer`, `AwakeningSystemServer`, `BossRaidServer`, `CharacterCatalogServer`, `CharacterStatsServer` |
| `CharacterCatalog` | `CharacterCatalogServer` | `AchievementSystemServer`, `AdminSystemServer` |
| `GameManagerConfig` | `GameManager` | `AwakeningSystemServer`, `CharacterCatalogServer`, `TradeSystemServer` |
| `SelectCharacterFunction` | `GameManager` (embrulhado por `MainSystemInitializer`) | `MainSystemInitializer` |
| `OnCharacterSelected` | `SpawnSystem` | `GameManager`, `GlobalSync`, `MainSystemInitializer` |
| `SetSpectatorMode`, `ReloadMapSpawnPoints`, `DebugSpawnState`, `ListAllPlayers` | `SpawnSystem` | `MainSystemInitializer` |
| `DebugPlayerStatus`, `TeleportToSafeZone`, `ForceSelectCharacter` | `GlobalSync` | `MainSystemInitializer` |
| `ResetPlayerBarrier` | `MainSystemInitializer` | — (debug manual) |
| `RegisterAttack`, `DamageAttribution` | `DamageAttribution` | `NPC_Server_V2`, `TeamSystemServer`, `PassiveSystemServer`, `StatusEffectServer`, `NucleoCombate_V2` |
| `CanDamagePlayer`, `CreateTeamBlockEffect` | `TeamDamageProtection` | `NucleoCombate_V2` |
| `GetPlayerTeam`, `IsTeammate`, `GetAllTeams`, `GetTeamMembers`, `GetAvailableTeamColors` | `TeamSystemServer` | `BossRaidServer`, `DuelSystemServer`, `GlobalSync`, `TeamDamageProtection`, `MainSystemInitializer` |
| `AwakeningSystem` | `AwakeningSystemServer` | `GameManager` |
| `PassiveSystem` | `PassiveSystemServer` | `NpcPassiveBridge`, `Health` |
| `EnergySystem` | `EnergySystemServer` | `PassiveSystemServer` |
| `StatusEffect` | `StatusEffectServer` | — |
| `CharacterStats` | `CharacterStatsServer` | — (só servidor; o `CharacterStatsAdminClient` fala com ele por Remote, não por `_G`) |
| `DailyRewards` | `DailyRewardsServer` | — |
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
`DebugAwakening`, `DebugCatalog`, `DebugCharacterStats`, `DebugDailyRewards`,
`DebugEfeitos`, `DebugEnergy`, `DebugGameManager`, `DebugNpcBridge`, `DebugNucleo`,
`DebugPassives`, `DebugPlayerStatus`, `DebugSpawnState`, `DebugTeams`, `DebugTutorial`.

---

## 6. ⚠️ Dependências ausentes

Três arquivos consumidos pelo código **não estão no repositório**:

| Falta | Tipo / Local | Expõe |
|---|---|---|
| `StatService` (V3) | `Script` · ServerScriptService | `_G.StatService` |
| `CharacterLevelServer` (V1) | `Script` · ServerScriptService | `_G.CharacterLevel` |
| `PassiveCatalog` | `ModuleScript` · ServerScriptService | tabela de passivas (via `require`) |

### Impacto

| Script afetado | Linha | Comportamento sem a dependência |
|---|---|---|
| `PassiveSystemServer.server.lua` | 75 | `repeat` infinito — passivas nunca iniciam, sem erro no Output |
| `NpcPassiveBridge.server.lua` | 78 | `repeat` infinito — passivas não valem contra NPC |
| `StatusEffectServer.server.lua` | 64 | `repeat` infinito — efeitos de status nunca iniciam |
| `PassiveSystemServer.server.lua` | 77-81 | `WaitForChild("PassiveCatalog", 30)` expira → `warn` e `return` |

Só o último caso avisa no Output. Os três `repeat` falham em **silêncio**, o que
faz o sintoma parecer "a passiva não funciona" em vez de "falta um script".

### Opcionais (não travam nada)

Protegidas por `if`, então a ausência só desliga o recurso:

| API | Consumidor | O que se perde |
|---|---|---|
| `_G.PassiveVFX` | `PassiveSystemServer` (linhas 430, 511, 536) | Efeitos visuais das passivas |
| `_G.SetCoinMultiplier` | `DailyRewardsServer` (linhas 268, 529) | Multiplicador de moedas da recompensa diária |

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
