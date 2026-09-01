# boss-place/ — scripts da Place do Chefão

⚠️ **Esta pasta NÃO vai na place principal.** É uma **Place separada** do Roblox.

O CI analisa a sintaxe destes arquivos, mas os workflows de publicação e bootstrap
atuais empacotam apenas `src/`. Isso é intencional: a Place do chefe precisa de uma
seleção de scripts compartilhados e o `Boss_ModelController` mora dentro do Model
3D. Ela só ganhará automação quando existir um manifesto de caminhos explícito;
não aponte o pacote principal para a Place do chefe.

A place principal é `133619220682618`. A place do chefe é outra, com seu próprio
DataModel — os `_G.PlayerDataManager`, `_G.CharacterCatalog`, `_G.AdminRegistry`
etc. **não existem lá automaticamente**.

Regras completas: [`../docs/Diretrizes_Sistema_Chefao_Boss.md`](../docs/Diretrizes_Sistema_Chefao_Boss.md)

---

## 1. Scripts exclusivos do chefão (só existem aqui)

Todos em `ServerScriptService` da place do chefe:

| Arquivo | Nome no Studio | Regra | Função |
|---|---|:--:|---|
| `Boss_TeleportDataReceiver.server.lua` | `Boss_TeleportDataReceiver` | 2, 8, 13 | **Primeiro da cadeia.** Lê o `TeleportData`, define a sessão e o roster, descobre o personagem fixo de cada jogador |
| `BossConfigServer.server.lua` | `BossConfigServer` | 12 | Config de cada chefe (HP, recompensa, músicas, diálogo) em DataStore próprio, editável em jogo |
| `Boss_SessionReadyGate.server.lua` | `Boss_SessionReadyGate` | 3 | Só libera a GUI de inventário quando **todos** da sessão estiverem prontos |
| `Boss_NoPvpProtection.server.lua` | `Boss_NoPvpProtection` | 1 | Anula dano jogador→jogador. **Substitui** o `TeamDamageProtection` aqui |
| `Boss_ExitTeleport.server.lua` | `Boss_ExitTeleport` | 7, 9, 13 | Recompensa → confirma → teleporta. Nunca o contrário |

### E um que vai DENTRO do Model do chefe

| Arquivo | Nome no Studio | Onde | Função |
|---|---|---|---|
| `Boss_ModelController.server.lua` | `Boss_ModelController` | **dentro do Model do chefe** | Cérebro: gate → HP travado → perseguição → dano → morte |

⚠️ Ele **substitui** quatro scripts do modelo baixado: `KillScript` (+ `Delete`),
`Pathfinding`, `AI` e `AInot`. **Apague os quatro** — rodar qualquer um junto
significa dois cérebros disputando o mesmo `Humanoid`.

O motivo de substituir em vez de remendar está em
[`../docs/Auditoria_Modelo_Boss_Angel.md`](../docs/Auditoria_Modelo_Boss_Angel.md):
o `KillScript` matava com `Humanoid.Health = 0`, que as Diretrizes proíbem e que
pula o pipeline inteiro (`_G.CanDamagePlayer`, `Boss_NoPvpProtection`,
`StatService`, passivas de Negação/Reverso, `DamageAttribution`).

### Ordem de dependência

```
Boss_TeleportDataReceiver   →  _G.BossSession   (quem está na luta)
BossConfigServer            →  _G.BossConfig    (HP, prêmio, música, diálogo)
        ↓                          ↓
Boss_SessionReadyGate       →  _G.BossGate      (libera a GUI)
Boss_ExitTeleport           →  _G.BossExit      (saída com recompensa)
Boss_NoPvpProtection        →  _G.CanDamagePlayer (independente dos outros)
```

Cada um espera pelas dependências via `repeat task.wait() until _G.X`, então a
ordem de carga do Roblox não importa — só não pode **faltar** ninguém.

---

## 2. Scripts que você instala AQUI TAMBÉM, vindos de `src/`

Estes **não estão duplicados neste repositório de propósito**. São os mesmos
arquivos de `src/`, instalados uma segunda vez na place do chefe. Duplicar o
conteúdo aqui criaria duas versões da mesma coisa para divergirem — exatamente o
que o fluxo de versão única existe para impedir.

| Copie de | Para | Por quê |
|---|---|---|
| `src/ServerScriptService/MainSystemInitializer.server.lua` | `ServerScriptService` | Cria as pastas de `ReplicatedStorage` que todo o resto espera |
| `src/ServerScriptService/DataManager.server.lua` | `ServerScriptService` | `_G.PlayerDataManager` — HP scaling, GUI, recompensa |
| `src/ServerScriptService/AdminRegistryServer.server.lua` | `ServerScriptService` | `_G.AdminRegistry.isAdmin` — sem ele só o DONO edita a config |
| `src/ServerScriptService/CharacterCatalogServer.server.lua` | `ServerScriptService` | Popula `ReplicatedStorage.Characters` — sem ele a GUI não tem o que mostrar |
| `src/ServerScriptService/AchievementSystemServer.server.lua` | `ServerScriptService` | Fluxo de prêmio que não duplica |
| `src/ServerScriptService/LoadingScreenServer.server.lua` | `ServerScriptService` | Base do gate da regra 3 |
| `src/ReplicatedFirst/LoadingScreen.client.lua` | `ReplicatedFirst` | Par cliente do handshake |
| `src/StarterPlayer/StarterPlayerScripts/MusicPlayerClient_V2.client.lua` | `StarterPlayerScripts` | Troca de faixa por evento (regra 6) |
| `src/StarterPlayer/StarterPlayerScripts/TutorialMenuClient_V2.client.lua` | `StarterPlayerScripts` | Só o componente visual da caixa de diálogo (regra 4) |

### ⚡ E o Despertar? Sem estes, ele NÃO funciona na luta

O Despertar é a mecânica de destaque do combate, e a luta contra o chefe é
exatamente onde ela deveria brilhar. Só que ela vive em scripts da place
principal: sem copiá-los, `_G.AwakeningMeter` não existe aqui, a barra nunca
aparece e a forma nunca dispara. E falha em **silêncio** — o `GameManager` e o
`StatService` consultam o medidor protegidos por `if`, então nada dá erro, o
Despertar simplesmente não acontece.

| Copie de | Para | Por quê |
|---|---|---|
| `src/ServerScriptService/GameManager.server.lua` | `ServerScriptService` | É quem troca as Tools entre a forma normal e a desperta |
| `src/ServerScriptService/AwakeningSystemServer.server.lua` | `ServerScriptService` | As DEFINIÇÕES de Despertar. **Mesmo nome de DataStore** da principal |
| `src/ServerScriptService/AwakeningMeterServer.server.lua` | `ServerScriptService` | A barra: enche com dano e uso de habilidade, dispara a forma |
| `src/ServerScriptService/DamageAttribution.server.lua` | `ServerScriptService` | Sem ele o medidor não sabe QUEM bateu, e só a parte de "apanhar" enche |
| `src/ServerScriptService/StatService.server.lua` | `ServerScriptService` | Atributos e a vida da forma desperta |
| `src/ServerScriptService/CharacterLevelServer.server.lua` | `ServerScriptService` | O `StatService` depende dele para energia e atributos por nível |
| `src/ServerScriptService/EnergySystemServer.server.lua` | `ServerScriptService` | Custo de energia das habilidades |
| `src/StarterPlayer/StarterPlayerScripts/HealthDisplay.client.lua` | `StarterPlayerScripts` | Vida, energia e a barra de Despertar na tela |
| `src/StarterPlayer/StarterPlayerScripts/RetroHotbarClient.client.lua` | `StarterPlayerScripts` | A hotbar, que precisa refletir a troca de Tools |

⚠️ O `AwakeningMeterServer` chama `_G.GameManagerConfig.reapplyEquippedTools`
para trocar as Tools. Sem o `GameManager` aqui, a barra enche, dispara e **nada
acontece** — ele avisa no log, mas o jogador só vê a barra encher em vão.

### ⛔ NÃO instale aqui

**`TeamDamageProtection`** — o `Boss_NoPvpProtection` faz o papel dele nesta place.
Os dois definem `_G.CanDamagePlayer`, e como a ordem de carga em
`ServerScriptService` não é garantida, o resultado mudaria a cada teste.

### ⚠️ DataStore e MessagingService: os MESMOS nomes

As cópias precisam apontar para os mesmos nomes da place principal, senão você
cria dados paralelos dessincronizados:

- `DataManager` → `RetroVerseDataV3_Awakening`
- `CharacterCatalogServer` → `RVCharacterCatalogV1` / tópico `RVCharacterCatalogSync`
- `AchievementSystemServer` → mesmo store e tópico da principal

DataStore e MessagingService são compartilhados entre places da mesma Experience,
então nada precisa ser sincronizado à mão — só usar o mesmo nome.

---

## 3. O que ainda falta (não é código de script)

Os cinco scripts acima são a **infraestrutura da sessão**: quem entrou, config,
gate, sem-PvP e saída com recompensa. O que falta é o **chefe em si**, que é
trabalho de Model no Studio, não de script solto:

- O `Model` do chefe com `Humanoid`, membros, `AnimSaves`
- `ChatScript` (falas); a perseguição fica no `Boss_ModelController`
- `todamage` (contato), `AllDamage` (AOE), `gen*` (projéteis)
- `BossWaypoints` + `BossTools`
- `BossHp` (a GUI de barra de vida — única GUI permitida pela exceção)
- Fases como Models irmãos (`_Fase2`, `_Fase3`)

Os ganchos para o Model usar já estão prontos:

```lua
-- no spawn do chefe (regra 10: HP travado no spawn)
_G.BossGate.aguardar()                    -- espera todos ficarem prontos
local n = _G.BossSession.contar()
local hp = _G.BossConfig.calcularHp(_G.BossSession.getBossId(), n)
humanoid.MaxHealth = hp
humanoid.Health = hp

-- quando o chefe morrer (regra 7)
_G.BossExit.vitoria()
```

A derrota (individual e total) já é detectada sozinha pelo `Boss_ExitTeleport` —
o Model não precisa chamar nada.

---

## 4. Diagnóstico no console do servidor

```lua
_G.DebugBossSession()   -- sessão, roster, personagem fixo de cada um
_G.DebugBossConfig()    -- config de cada chefe (ou o padrão)
_G.DebugBossGate()      -- prontos vs total, quem falta, tempo até o teto
_G.DebugBossExit()      -- vivos, quem já foi processado, destino
_G.DebugNoPvp()         -- quem está sendo monitorado
```
