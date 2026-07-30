# 📘 DIRETRIZES FORMAIS - SISTEMA DE CHEFÃO (BOSS)
## Retro - Verse / Studios Project | Roblox Studio

**Baseado em:** Documentação Oficial do Roblox Engine (Model / Humanoid / Tool)
**+ Análise do modelo de referência:** `bOSS FIGHT RETRO.rbxmx`
**Versão:** 5.0
**Plataforma:** Roblox Studio

> Este documento é a REGRA BASE para criar qualquer chefão novo no projeto.
> A partir de agora, para criar um chefão novo, basta seguir esta diretriz — não é
> necessário recriar regras do zero a cada vez. Alterações pontuais podem ser
> pedidas depois e serão versionadas (V1 → V2...) dentro deste próprio documento.

### 🕘 Histórico de Versões deste Documento
- **V1:** Estrutura base do chefão (fases, ataques, IA, HP bar, restrições gerais)
  a partir da análise do `bOSS FIGHT RETRO.rbxmx`.
- **V2:** Adicionadas regras absolutas de fluxo de sessão da place do chefe:
  bloqueio total de PvP, personagem fixo até morrer, gate de carregamento antes
  da GUI de inventário, caixa de diálogo de regras (reuso do Tutorial System),
  uma Tool por vez no chefe (habilidades extras nativas), trilha sonora por
  evento, e teleporte forçado de saída com checagem de entrega de
  recompensa/emblema antes do teleporte.
- **V3:** Definido o ID da place principal para o teleporte forçado
  (`133619220682618`). Fechadas as regras de desconexão (quem sai não recebe
  recompensa, os demais continuam a luta), de derrota total (todos mortos =
  expulsão em grupo para a place principal, sem recompensa), de escala de vida
  do chefe por quantidade de jogadores na sessão, e confirmado que **não** haverá
  sistema anti-AFK (decisão intencional, para não atrapalhar gravações). Também
  documentado o padrão de configuração de recompensas/loot via API (criar no
  Studio, editar depois em jogo, sem reabrir o Studio).
- **V4:** Fechado o comportamento do HP do chefe: o valor é **travado no momento
  do spawn**, calculado pela quantidade de jogadores presentes naquele instante
  (solo = 1 jogador, ou o valor cheio se entrarem vários) — desconexões no meio
  da luta **não recalculam** o HP pra baixo. Também definido que a sessão/servidor
  do chefe é **de uso único e não retornável**: uma vez iniciado, não existe
  volta para o mesmo servidor — ele só termina quando o jogador morre ou
  completa a missão do chefe.
- **V5:** Documentados os **scripts obrigatórios de bridge cross-place** — como a
  place do chefe é separada da place principal, ela precisa de cópias locais de
  `DataManager`, `AdminRegistryServer`, `CharacterCatalogServer`,
  `AchievementSystemServer`, `TeamDamageProtection`, `LoadingScreenServer` e
  `MusicPlayerClient`, todas apontando para os mesmos nomes de DataStore/tópicos
  de `MessagingService` da place principal, além dos scripts novos exclusivos do
  sistema de chefão (`TeleportDataReceiver`, `SessionReadyGate`, `ConfigStore`,
  `NoPvpProtection`, `ExitTeleport`).

---

## 🎯 DEFINIÇÃO OFICIAL DE "CHEFÃO" NO PROJETO

Um **Chefão (Boss)** é um `Model` com `Humanoid`, posicionado em Workspace, que:
- Persegue e ataca jogadores automaticamente (IA própria, sem controle de jogador);
- Possui vida (HP) exibida para os jogadores;
- Possui um ou mais **padrões de ataque** (perto/melee, longe/ranged, área/AOE);
- Pode ter **fases** (formas diferentes que se revezam quando a vida cai);
- Opcionalmente empunha **Tools próprias** (armas do chefe, não pegáveis por jogador).

### Hierarquia de Classes Envolvidas
```
Model (Chefão)
 ├─ Humanoid          -> vida, velocidade, animações
 ├─ HumanoidRootPart  -> referência de posição para IA
 ├─ Partes do corpo (Part/MeshPart) + Motor6D/Weld
 ├─ Scripts de IA, ataque, dano e fases
 └─ (opcional) Tools equipadas via script (nunca pelo Backpack do jogador)
```

---

## ⛔ REGRAS ABSOLUTAS DE SESSÃO DA PLACE DO CHEFE (V2)

Estas regras são **inegociáveis** e valem para TODO chefão novo, além das
restrições gerais do projeto.

### 1. PROIBIDO PVP — só existe Jogador vs Boss
- Motivo do projeto: jogador contra NPC **não é** PvP entre jogadores, então dano
  jogador→jogador dentro da place do chefe é sempre bloqueado.
- Implementação: **reutilizar o padrão do `TeamDamageProtection`**, mas adaptado
  para bloquear dano entre **qualquer par de jogadores**, e não apenas mesmo time
  — dentro da place do chefe todos os jogadores estão "no mesmo lado".
- Só passam pelo bloqueio: dano do Boss → Jogador, e dano do Jogador → Boss
  (Humanoid do chefão). Todo dano Jogador → Jogador é cancelado silenciosamente
  (sem matar a Tool, só anular o dano, igual ao `_G.CanDamagePlayer`).
- Script novo sugerido: `Boss_[Nome]_NoPvpProtection_V1.lua` (Script, dentro da
  place/pasta do chefe), construído em cima do `_G.CanDamagePlayer` /
  `_G.CreateTeamBlockEffect` já existentes no `TeamDamageProtection`.

### 2. Personagem fixo até morrer
- Ao entrar na place do chefe, o jogador **não pode trocar de personagem**
  (o menu de seleção/loja de personagens deve ficar bloqueado/oculto).
- Reutilizar a trava que já existe no fluxo de troca de personagem
  (`CharacterCatalogServer`/`CharacterSystemClient`: mensagem "Você precisa
  morrer para trocar..."), mas tornando-a **permanente durante toda a sessão do
  chefe**, não só um cooldown.
- Só existem 2 saídas do personagem fixo: (a) o jogador **morre** na luta, ou
  (b) o **chefe morre** e a sessão termina — em ambos os casos o jogador é
  teleportado para a place principal (ver regra 6).

### 3. GUI de inventário só aparece após TODOS carregarem
- Ao entrar na place, nenhuma GUI de personagens/tools aparece de imediato.
- Reutilizar o handshake do `LoadingScreenServer`/`LoadingScreen` (estágios +
  `LoadingReady`), mas com uma barreira adicional: o servidor só libera a GUI de
  inventário (que usa a mesma API de personagens/tools do catálogo,
  `GetCatalogCharacters` etc.) **quando todos os jogadores da sessão** estiverem
  prontos — não apenas o jogador individual.
- Script novo sugerido: `Boss_[Nome]_SessionReadyGate_V1.lua` — conta jogadores
  prontos vs. total da sessão e só então dispara o remote que libera a GUI.

### 4. Caixa de diálogo explicando o Boss (reuso do Tutorial System)
- Antes da luta começar, mostrar uma caixa de diálogo (não uma GUI completa nova)
  explicando mecânicas do chefe (fases, ataques, o que fazer).
- Reutilizar o **padrão de passos/diálogo do `TutorialSystemServer` +
  `TutorialMenuClient`** (mesmo estilo visual e fluxo "avançar passo a passo"),
  adaptando o conteúdo dos passos para as regras daquele chefe específico.
- Avisar no chat que a caixa de diálogo foi reutilizada do Tutorial System.

### 5. Uma Tool por vez — habilidades extras são do Boss, não da Tool
- O chefe nunca deve estar com mais de uma Tool equipada ao mesmo tempo.
- Habilidades "extras" (ataques especiais, AOE, fases) são implementadas
  **diretamente nos scripts do Model do chefe** (ex.: `AllDamage`, módulos
  `gen[Nome]`), e não como uma segunda Tool adicional.
- Troca de Tool do chefe (se houver mais de uma arma possível) deve ser
  sequencial: desequipar a atual antes de equipar a próxima, nunca as duas juntas.

### 6. Trilha sonora por evento
- Cada evento do chefe tem sua própria música: diálogo inicial, fase 1, transição
  de fase, fase 2, fase 3, vitória, derrota.
- Reutilizar o padrão de troca de faixa do `MusicPlayerClient` (fade
  in/out ao trocar de `SoundId`), disparado por `RemoteEvent` quando o evento
  correspondente ocorre no servidor (ex.: ao entrar na fase 2).
- Nomeação sugerida do remote: `Boss_[Nome]_MusicEvent` com um parâmetro
  string identificando o evento (`"dialogo"`, `"fase2"`, `"vitoria"`, etc.).

### 7. Teleporte forçado de saída — só após checar recompensa/emblema
- Ao final da luta (chefe derrotado OU jogador morto), o jogador é **sempre**
  forçado de volta à place principal — ele não escolhe ficar.
- **Place principal (destino do teleporte):** `133619220682618`. Usar
  `TeleportService:TeleportAsync(133619220682618, {jogador})` (ou
  `Teleport`/`TeleportPartyAsync` se for teleportar o grupo inteiro de uma vez,
  ex.: no caso de derrota total — ver regra 9).
- Ordem obrigatória de execução (nessa sequência, nunca invertida):
  1. Verificar se a recompensa/emblema já foi entregue a esse jogador;
  2. Se não foi, **entregar agora** (reutilizar o padrão de concessão de prêmio do
     `AchievementSystemServer`, que valida o prêmio antes de conceder e evita
     duplicar caso o jogador já possua);
  3. Confirmar (ex.: `DataStore`/callback de sucesso) que a entrega foi
     persistida;
  4. **Só então** teleportar o jogador para a place `133619220682618`.
- Nunca teleportar primeiro e conceder depois — se o servidor cair entre os dois
  passos, o jogador perde a recompensa.

### 8. Jogador que desconecta durante a luta
- Se um jogador sair (desconectar) no meio da sessão do chefe, ele **não recebe
  a recompensa/emblema** (nunca chegou a completar).
- A sessão **continua normalmente** para quem ainda está na place — a saída de
  um jogador não cancela nem pausa a luta dos demais.
- Implementação: conectar `Players.PlayerRemoving` dentro da sessão do chefe
  apenas para remover o jogador das listas de controle (ex.: contagem de
  "prontos" da regra 3, HP scaling da regra 10) — sem nenhuma ação de
  cancelamento da luta em si.

### 9. Derrota total (todos os jogadores mortos)
- Se todos os jogadores da sessão morrerem antes do chefe, é uma **expulsão em
  grupo**: todos são forçados a voltar para a place principal (`133619220682618`),
  igual a uma derrota individual, mas disparada em conjunto.
- **Sem recompensa/emblema** nesse caso — a checagem de entrega da regra 7 só
  roda para vitória; em derrota total ela é pulada (não há o que confirmar).
- Detecção: contar jogadores vivos na sessão a cada morte (`Humanoid.Died`); ao
  chegar a zero vivos, disparar o teleporte de grupo.

### 10. Vida do chefe escala com quantidade de jogadores (valor travado no spawn)
- Não existe limite de jogadores por sessão (isso é controlado por outro sistema,
  fora desta diretriz).
- `Humanoid.MaxHealth`/`Health` do chefe é calculado **uma única vez, no momento
  do spawn do chefe**, com base no número de jogadores presentes na sessão
  naquele instante (ex.: `HP_BASE + (HP_POR_JOGADOR * quantidadeDeJogadoresNoSpawn)`).
  Se o jogador estiver sozinho, é o valor solo; se entrarem vários, é o valor
  cheio correspondente.
- **Esse valor fica travado.** Uma desconexão no meio da luta (regra 8) **não
  recalcula** o HP máximo para baixo — o chefe continua com o HP definido no
  spawn até ser derrotado.
- Cada chefe pode definir seus próprios `HP_BASE`/`HP_POR_JOGADOR` (parte da
  configuração daquele chefe específico, ver regra 12 sobre configuração via API).

### 11. Sem sistema anti-AFK
- Decisão intencional: **não implementar** nenhum anti-AFK na place do chefe
  (bom para gravações/replays). Não incluir esse item em nenhum checklist futuro
  a menos que essa decisão seja revertida explicitamente.

### 12. Recompensas/loot configuráveis via API (mesmo padrão do catálogo)
- Sim, é possível: seguir o mesmo padrão já usado por `CharacterCatalogServer` e
  `AchievementSystemServer` no projeto.
- **No Studio:** só a estrutura base é criada uma vez (pastas, `RemoteEvent`s,
  o "molde" de configuração do chefe).
- **Em jogo (via API/painel admin), sem reabrir o Studio:** os valores
  específicos de cada chefe (recompensa/emblema associado, `HP_BASE`/
  `HP_POR_JOGADOR` da regra 10, faixas de música por evento, textos da caixa de
  diálogo) ficam salvos em `DataStore` próprio do sistema de chefões e são
  editados por remotes admin (`Set`/`Remove`), sincronizados entre servidores via
  `MessagingService` — igual ao fluxo de `AdminAchievementSet`/
  `applyRemoteChange` do `AchievementSystemServer`.
- Script novo sugerido: `Boss_[Nome]_ConfigStore_V1.lua` (ou um
  `BossConfigServer` único para todos os chefes, reutilizando a definição por
  `id` como o catálogo de personagens/conquistas já faz).

### 13. Servidor da luta é de uso único (sem retorno)
- Uma vez que o servidor da sessão do chefe é iniciado, **não existe volta para
  esse mesmo servidor** — nem para o jogador que desconectou (regra 8), nem para
  ninguém.
- O servidor daquela sessão só termina de duas formas: o(s) jogador(es)
  morre(m) (derrota, regra 9) ou completam a missão do chefe (vitória, regra 7).
  Não há pausa, reconexão ou retomada de uma sessão anterior.
- Isso reforça a regra 8: quem desconecta simplesmente perde a sessão em
  definitivo (e a recompensa junto) — ao voltar a jogar, ele inicia uma sessão
  **nova**, do zero, não retoma a antiga.

---

## 📦 SCRIPTS OBRIGATÓRIOS DE BRIDGE (CROSS-PLACE) — V5

**Por que isso existe:** a place do chefe é uma **Place separada** da place
principal (`133619220682618`). Cada Place tem seu próprio DataModel — os
`_G.PlayerDataManager`, `_G.CharacterCatalog`, `_G.AdminRegistry` etc. que
existem na place principal **não existem automaticamente** na place do chefe.
Pra place do chefe conseguir "falar" com a mesma API (mesmas moedas, mesmos
personagens, mesmo status de admin, mesma conquista/emblema), ela precisa rodar
**cópias locais** desses scripts-base, sempre apontando para:
- o **mesmo `DATASTORE_NAME`** do sistema correspondente na place principal
  (ex.: `DataManager` da place do chefe deve usar exatamente
  `"RetroVerseDataV3_Awakening"`, igual ao da place principal — DataStores são
  compartilhados entre todas as places da mesma Experience/universo);
- o **mesmo `SYNC_TOPIC` do `MessagingService`** dos sistemas correspondentes
  (ex.: `CharacterCatalogServer`/`AchievementSystemServer`), já que
  `MessagingService` também é compartilhado entre places da mesma Experience.

**Nunca duplicar com nomes de DataStore diferentes** — isso criaria dados
"paralelos" desincronizados da place principal.

### Lista de scripts obrigatórios em toda place de chefe

| Script (copiar/adaptar da place principal) | Tipo | Função na place do chefe |
|---|---|---|
| `MainSystemInitializer` (adaptado) | Script | Cria as pastas base em `ReplicatedStorage` (`Remotes`, `Events`, `Characters`, `Assets`, `Modules`) — sem isso os outros scripts quebram esperando essas pastas |
| `DataManager` (mesmo `DATASTORE_NAME`) | Script | Dá acesso a `_G.PlayerDataManager` (moedas, personagens, stats, `claimedAchievements`) — necessário pra HP scaling (regra 10), GUI de inventário (regra 3) e entrega de recompensa (regra 7) |
| `AdminRegistryServer` (cópia) | Script | Restaura `_G.AdminRegistry.isAdmin` — necessário pra qualquer comando admin dentro da place do chefe e pra validar quem pode editar a config do chefe via API (regra 12) |
| `CharacterCatalogServer` (cópia, ou uma versão só-leitura) | Script | Popula `ReplicatedStorage.Characters` com as definições reais — sem isso a GUI de inventário (regra 3) não tem o que mostrar |
| `AchievementSystemServer` (cópia, ou fatia específica de emblema do chefe) | Script | Concede/checa a recompensa do chefe (regra 7) usando o mesmo fluxo de validação que evita duplicar prêmio |
| `TeamDamageProtection` (adaptado p/ bloqueio total, regra 1) | Script | Garante o "sem PvP" na place do chefe |
| `LoadingScreenServer` + `LoadingScreen` (client) | Script + LocalScript | Handshake de carregamento — base do gate da regra 3 |
| `MusicPlayerClient` (adaptado) | LocalScript | Troca de faixa por evento (regra 6) |
| `TutorialMenuClient` (reaproveitado só o componente visual) | LocalScript | Renderiza a caixa de diálogo de regras do chefe (regra 4) — não precisa da parte de progresso salvo do `TutorialSystemServer`, só o componente de exibição passo-a-passo |

### Scripts novos, exclusivos do sistema de chefão (não existem na place principal)

| Script | Tipo | Função |
|---|---|---|
| `Boss_TeleportDataReceiver_V1` | Script | Lê `player:GetJoinData().TeleportData` assim que o jogador chega na place do chefe — é assim que a place do chefe sabe quem entrou, em qual sessão/grupo, e qual personagem estava equipado (necessário pra regra 2, personagem fixo) |
| `Boss_[Nome]_SessionReadyGate_V1` | Script | Conta jogadores prontos vs. total da sessão antes de liberar a GUI de inventário (regra 3) |
| `Boss_[Nome]_ConfigStore_V1` (ou `BossConfigServer` único) | Script | Lê a config daquele chefe (HP por jogador, recompensa, faixas de música, textos de diálogo) do DataStore próprio, editável via API (regra 12) |
| `Boss_[Nome]_NoPvpProtection_V1` | Script | Especialização do `TeamDamageProtection` só pra essa place (ver tabela acima) |
| `Boss_[Nome]_ExitTeleport_V1` | Script | Executa a sequência da regra 7/9/13: checa recompensa → entrega → confirma → `TeleportService:TeleportAsync(133619220682618, {...})` |

> ⚠️ Na **place principal**, também é necessário um script (fora do escopo deste
> documento de chefão, pertence ao fluxo de entrada) que chama
> `TeleportService:TeleportAsync` com `TeleportData` contendo a sessão/grupo e o
> personagem equipado de cada jogador, para a place do chefe conseguir ler isso
> no `Boss_TeleportDataReceiver_V1`.

---

## 🏗️ ESTRUTURA HIERÁRQUICA PADRÃO (baseada no modelo de referência)

Essa foi a estrutura identificada no arquivo de referência `bOSS FIGHT RETRO` e deve
servir de esqueleto para todo chefão novo:

```
[Pasta do Chefão]  (Folder, nome = nome do chefão)
├─ BossWaypoints (Folder)
│   └─ SpawnLocation(s)        -> pontos de spawn/arena do chefe
│
├─ BossTools (Folder)
│   └─ Tool(s) do chefe        -> armas próprias, nunca vão pro Backpack de jogador
│
├─ [NomeDoChefe] (Model)                <- MODEL PRINCIPAL DO CHEFÃO
│   ├─ Humanoid
│   ├─ HumanoidRootPart, Head, Torso, membros...
│   ├─ AnimSaves (Model/Folder)         -> guarda Animations/KeyframeSequences do chefe
│   ├─ Pathfinding (Script)             -> IA de perseguição
│   ├─ ChatScript (Script)              -> falas/provocações do chefe
│   ├─ todamage (Script)                -> dano de contato (melee)
│   ├─ AllDamage (Script)               -> ataque em área (AOE), controlado por Value
│   ├─ genBolt / genLazer / genSkyLauncher (ModuleScript) -> geradores de projétil/feixe
│   ├─ EverySpawnIn (Script)            -> entrega a BossHp GUI para cada jogador que entra
│   ├─ BossHp (ScreenGui/BillboardGui)  -> barra de vida do chefe (ver seção GUI)
│   └─ Values de controle (BoolValue/NumberValue/StringValue/ObjectValue)
│
├─ [NomeDoChefe]_Fase2, _Fase3... (Model)   <- fases alternativas (opcional, ver seção Fases)
│
└─ Remotes específicos do chefe (RemoteEvent)
    -> Padrão de nomes: Spawn, Shoot, Throw, Barrage, Emote
    -> Ficam dentro do Model do chefe ou de sua pasta, não em ReplicatedStorage.Remotes
       global (para não conflitar com os remotes dos outros sistemas do jogo)
```

**Reutilização confirmada a partir do modelo de referência:**
- Padrão de `BossWaypoints` + `SpawnLocation` para arena/spawn do chefe.
- Padrão de fases múltiplas usando Models irmãos (`Angel`, `Angel2`, `Angel3` no
  modelo original) com a mesma estrutura interna repetida.
- Padrão de ataque à distância via `ModuleScript` gerador (`genBolt`, `genLazer`,
  `genSkyLauncher`) chamado por um `Script` de disparo.
- Padrão de HP visível ao jogador via GUI clonada no `PlayerGui` (`EverySpawnIn` +
  `BossHp`).
- Padrão de falas automáticas do chefe via `ChatScript`.

---

## 📋 PROPRIEDADES OBRIGATÓRIAS DO HUMANOID DO CHEFÃO

| Propriedade | Valor / Regra |
|---|---|
| `MaxHealth` / `Health` | Definido por fase de dificuldade (ver tabela de fases). Nunca deixar no padrão 100 de um NPC comum. |
| `WalkSpeed` | Ajustado à identidade do chefe (não pode ser 0, exceto chefes "estacionários" propositais). |
| `DisplayName` / `Name` | Nome do chefe, usado nas falas, na GUI de HP e no anúncio de spawn. |
| `BreakJointsOnDeath` | Manter `true` (padrão) — usar apenas quando o chefe realmente morre, nunca forçado via `Destroy()`. |
| `RequiresNeck` etc. | Padrão do Roblox, não alterar manualmente. |

---

## ⚔️ SISTEMA DE ATAQUES (3 categorias obrigatórias de referência)

### 1. Ataque de Contato / Melee (`todamage`)
- Script conectado ao `Touched` da parte do chefe (mão, corpo, etc.);
- Deve ter **debounce** e verificar `FindFirstChild("Humanoid")` antes de aplicar dano;
- Dano aplicado via `Humanoid:TakeDamage(valor)` — **NUNCA** zerar `Health` diretamente
  como atalho para matar (ver seção de Restrições);
- Modelo de referência:
```lua
-- MODELO BASE (reutilizar/adaptar) - dano por toque
local parteDoChefe = script.Parent
local dano = 10 -- ajustar por chefe
local cooldown = 0.5
local debounce = false

parteDoChefe.Touched:Connect(function(outraParte)
    if debounce then return end
    local personagem = outraParte.Parent
    local humanoid = personagem and personagem:FindFirstChildOfClass("Humanoid")
    if humanoid and humanoid.Parent ~= script.Parent.Parent then
        debounce = true
        humanoid:TakeDamage(dano)
        task.wait(cooldown)
        debounce = false
    end
end)
```

### 2. Ataque à Distância / Ranged (padrão `genBolt` / `genLazer` / `genSkyLauncher`)
- Cada tipo de projétil vira um `ModuleScript` gerador (`gen[NomeDoAtaque]`), chamado
  por um `Script` de disparo (`require(script.Parent.gen...)`);
- O `Script` de disparo decide alvo (jogador mais próximo, aleatório dentre os
  presentes, etc.) e frequência do ataque;
- Reaproveitar os módulos `genBolt`, `genLazer` e `genSkyLauncher` do modelo de
  referência sempre que o novo chefe precisar de um efeito parecido — **avisar no
  chat que o módulo foi reutilizado do "bOSS FIGHT RETRO"**.

### 3. Ataque em Área / AOE (padrão `AllDamage`)
- Controlado por `Value`s de estado (ex.: `AllDamageType`, `DoneAllAttack`) para
  evitar que o ataque dispare mais de uma vez ao mesmo tempo;
- Aplica dano a **todos os jogadores presentes no mapa** (usar função utilitária
  tipo `getAllHumanoids(workspace)` do modelo de referência);
- Sempre acompanhar de uma animação/telegraph (aviso visual/sonoro) antes do dano
  cair, para dar chance de esquiva ao jogador.

---

## 🩸 BARRA DE VIDA DO CHEFE (GUI) — EXCEÇÃO CONTROLADA

A diretriz geral do projeto proíbe criar Hubs/GUIs completas. Para chefões, existe
**uma única exceção permitida**: a **barra de vida (HP) do chefe**, por ser
informativa (não interativa) e essencial para o combate.

**Regras da exceção:**
- Permitido: `ScreenGui`/`BillboardGui` somente com `Frame` + `TextLabel`/barra de
  progresso mostrando `Humanoid.Health / Humanoid.MaxHealth`;
- Proibido: botões extras, menus, abas ou qualquer elemento interativo dentro dessa
  GUI (a única exceção a botão continua sendo a regra geral: botão de habilidade
  Extra de uma Tool, não da GUI do chefe);
- Entrega ao jogador: clonar a GUI para o `PlayerGui` de cada jogador que entra na
  área (padrão `EverySpawnIn` do modelo de referência), nunca para todos os
  jogadores do servidor sem estarem na luta;
- A GUI deve se autodestruir/limpar apenas quando o **próprio chefe morrer**
  (checar `Humanoid.Health == 0`), nunca via `Destroy()` de partes do jogo.

---

## 🔄 SISTEMA DE FASES (opcional, multi-forma)

Baseado no padrão `Angel` → `Angel2` → `Angel3` do modelo de referência:

- Cada fase é um **Model separado**, com a mesma estrutura interna (Humanoid,
  Pathfinding, scripts de ataque, `AnimSaves` próprio);
- Transição de fase ocorre por **threshold de vida** (ex.: fase 2 ativa quando
  `Health <= MaxHealth * 0.66`, fase 3 quando `<= 0.33`), nunca por `Randomize`;
- Ao trocar de fase: desabilitar/parar os scripts da fase anterior (`Script.Disabled
  = true` ou parar a IA), NUNCA usar `:Destroy()` no Model da fase anterior —
  apenas tornar invisível/`Transparency = 1` + `CanCollide = false` ou mover
  (`Parent = nil`/pasta de "inativos"), conforme a restrição geral do projeto;
- Cada fase pode ter falas próprias no `ChatScript` (ex.: fase 3 mais agressiva).

---

## 🗨️ SISTEMA DE FALAS (`ChatScript`)

- Lista fixa de falas por chefe (não gerar texto aleatório de fora da lista);
- Sorteio apenas **entre as falas já definidas** (`math.random(1, quantidadeDeFalas)`
  é permitido aqui — não é a `Randomize` proibida de posição/objeto, é apenas
  escolha de índice de texto);
- Intervalo mínimo entre falas (ex.: `task.wait(10)`) para não poluir o chat;
- Reutilizar o padrão do modelo de referência (`game:GetService("Chat"):Chat(...)`
  ou o sistema de chat em bolha atual do jogo, o que estiver ativo no projeto).

---

## 🧭 SISTEMA DE IA / PERSEGUIÇÃO (`Pathfinding`)

- Busca o jogador vivo mais próximo (`Humanoid.Health > 0`) dentro de
  `SearchDistance`;
- Usa `Ray`/`PathfindingService` para verificar linha de visão antes de perseguir;
- Nunca usar `Destroy()` no jogador, na parte encontrada ou em qualquer objeto do
  mapa durante a busca — a função apenas **lê** posições;
- Debounce de recálculo de rota (não recalcular a cada frame sem `wait()`).

---

## 🧰 TOOLS DO CHEFE (`BossTools`)

Armas que o próprio chefe "usa" (não vão para o Backpack de jogador). Seguem a
mesma diretriz geral de Tools do projeto, com ajustes:

| Propriedade | Valor |
|---|---|
| `CanBeDropped` | `false` (igual à regra geral) |
| `RequiresHandle` | `true`, Handle com nome exato `"Handle"` |
| `ManualActivationOnly` | `true` recomendado — ativação é feita via script de IA (`Tool:Activate()`), não por clique de jogador |
| Localização | Dentro da pasta `BossTools`, equipada via script ao `Humanoid` do chefe, nunca via `Player.Backpack` |
| Quantidade equipada | **Sempre 1 por vez.** Habilidades extras do chefe NÃO viram uma segunda Tool — ficam em scripts do próprio Model (regra absoluta 5, veja acima) |

---

## 🔒 RESTRIÇÕES DO PROJETO APLICADAS A CHEFÕES

As mesmas proibições absolutas do projeto valem integralmente para o sistema de
Chefão:

- ❌ **Nunca usar `:Destroy()`** em partes, GUIs, ou no próprio Model do chefe —
  usar `Transparency = 1`, `CanCollide = false` ou `Parent = nil`;
- ❌ **Nunca usar `math.random` para posição/objeto** (Randomize de posição,
  aparência, drops) — `math.random` só é permitido para **escolher entre falas
  pré-definidas** ou **variações de padrão de ataque pré-definidas** (ex.: sortear
  qual dos 3 ataques já programados vem a seguir), nunca para gerar posição/objeto
  aleatório;
- ❌ **Nunca deletar o Humanoid** de jogador ou NPC (`:Destroy()` no Humanoid) —
  matar é sempre via `Health = 0` ou `TakeDamage`, deixando o sistema de
  morte/respawn padrão do jogo agir;
- ❌ **Nunca criar Hub/GUI completa** — exceção única e controlada é a barra de
  vida do chefe (ver seção específica acima);
- ⚠️ **Atenção ao reaproveitar o modelo de referência `bOSS FIGHT RETRO`:** os
  scripts originais (`KillScript`, `Delete`) contêm padrões que **violam** estas
  regras (`a:BreakJoints()` + `Humanoid.Health = 0` como insta-kill, e um script
  `Delete` que roda `script.Parent:Destroy()` após 5 segundos). **Esses dois
  padrões NÃO devem ser copiados** para chefes novos — usar `TakeDamage` com dano
  balanceado e nunca scripts de autodestruição.

---

## 📝 CONVENÇÕES DE NOMENCLATURA

- **Model do chefe:** `Boss_[Nome]` (ex.: `Boss_Angel`)
- **Fases:** `Boss_[Nome]_Fase2`, `Boss_[Nome]_Fase3`...
- **Scripts:** `Boss_[Nome]_[Função]_V[Versão].lua`
  - Exemplos: `Boss_Angel_Pathfinding_V1.lua`, `Boss_Angel_AllDamage_V1.lua`,
    `Boss_Angel_ChatScript_V1.lua`
- **Remotes do chefe:** `Boss_[Nome]_[Ação]` (ex.: `Boss_Angel_Shoot`,
  `Boss_Angel_Barrage`) — evita colisão de nome com remotes de outros sistemas
- **Versionamento:** sequencial V1 → V2 → V3, igual à regra geral do projeto

---

## ✅ CHECKLIST DE CONFORMIDADE (Chefão)

- [ ] Model principal com `Humanoid` configurado (Health/WalkSpeed adequados à fase)
- [ ] `BossWaypoints` com `SpawnLocation`(s) definidos
- [ ] Ataque de contato (`todamage`) com debounce e `TakeDamage`
- [ ] Pelo menos 1 ataque à distância (`gen[Nome]` + Script de disparo)
- [ ] Ataque de área opcional com `Value`s de controle e telegraph visual
- [ ] `Pathfinding`/IA de perseguição sem deletar nada
- [ ] `ChatScript` com falas fixas e intervalo mínimo
- [ ] Barra de vida (GUI) apenas informativa, entregue via clone no `PlayerGui`
- [ ] Fases (se houver) trocando por threshold de vida, sem `Destroy()`
- [ ] `BossTools` (se houver) com `CanBeDropped = false` e `RequiresHandle = true`
- [ ] Nenhum uso de `Destroy()` em Parts/Humanoid/GUI, nenhum `Randomize` de
      posição/objeto, nenhuma GUI completa fora da exceção da barra de vida
- [ ] Nomenclatura e versionamento aplicados corretamente
- [ ] Reutilizações do modelo de referência (ou de outros chefes) avisadas no chat
- [ ] PvP totalmente bloqueado na place do chefe (só dano Jogador↔Boss)
- [ ] Personagem travado (sem troca) durante toda a sessão até morrer
- [ ] GUI de inventário só libera após todos os jogadores da sessão carregarem
- [ ] Caixa de diálogo de regras do chefe exibida antes da luta (reuso Tutorial)
- [ ] Apenas 1 Tool equipada no chefe por vez; extras são scripts do Model
- [ ] Música trocando por evento (diálogo/fase/vitória/derrota)
- [ ] Recompensa/emblema confirmadamente entregue **antes** do teleporte forçado
      de volta à place principal (`133619220682618`) (nunca depois)
- [ ] Desconexão de jogador não cancela a sessão dos demais, e quem saiu não
      recebe recompensa
- [ ] Derrota total (0 jogadores vivos) expulsa todos em grupo para a place
      principal, sem recompensa
- [ ] `MaxHealth` do chefe calculado uma única vez no spawn, pela quantidade de
      jogadores naquele instante (não é valor fixo do Studio, e não recalcula
      se alguém desconectar depois)
- [ ] Nenhum sistema anti-AFK implementado (decisão intencional do projeto)
- [ ] Configurações do chefe (recompensa, HP por jogador, música, diálogo)
      editáveis via API/painel admin após a criação inicial no Studio
- [ ] Servidor da sessão é de uso único — sem reconexão/retomada para quem sai
- [ ] `DataManager`/`AdminRegistryServer`/`CharacterCatalogServer`/
      `AchievementSystemServer`/`TeamDamageProtection`/`LoadingScreenServer`/
      `MusicPlayerClient` presentes na place do chefe, com os MESMOS nomes de
      DataStore/`SYNC_TOPIC` da place principal
- [ ] `Boss_TeleportDataReceiver_V1` lendo `TeleportData` ao entrar na place
- [ ] `Boss_[Nome]_SessionReadyGate_V1`, `Boss_[Nome]_ConfigStore_V1`,
      `Boss_[Nome]_NoPvpProtection_V1` e `Boss_[Nome]_ExitTeleport_V1` presentes

---

## 🔖 FORMATO DE ENTREGA (igual ao padrão geral do projeto)

```markdown
## Scripts Entregues - Chefão [Nome]

### Versão Atual: V[X]

**Scripts Novos:**
1. Boss_[Nome]_[Função]_V[X].lua - [Função]

**Scripts Modificados:**
1. Boss_[Nome]_[Função]_V[X-1].lua → Boss_[Nome]_[Função]_V[X].lua
   - Mudanças: [Descrição]

**Scripts Substituídos:**
1. Boss_[Nome]_[Função]_V[X-1].lua
   - Substituído por: Boss_[Nome]_[Função]_V[X].lua
   - Remover: Boss_[Nome]_[Função]_V[X-1].lua

**Scripts/Padrões Reutilizados:**
1. [Padrão/Módulo] - Origem: bOSS FIGHT RETRO (referência) ou outro chefe existente
   - Efeito/Função: [Descrição]
```

---

## 📚 REFERÊNCIAS

- Documentação oficial: `Model`, `Humanoid`, `Tool`, `PathfindingService`
  (https://create.roblox.com/docs)
- Diretriz geral de Tools do projeto (documento-base: "Diretrizes do Projeto -
  Roblox Studio")
- Modelo de referência analisado: `bOSS FIGHT RETRO.rbxmx`
- Sistemas do projeto reutilizados nas regras V2: `TeamDamageProtection`
  (bloqueio de dano), `CharacterCatalogServer`/`CharacterSystemClient` (trava de
  personagem), `LoadingScreenServer`/`LoadingScreen` (gate de carregamento),
  `TutorialSystemServer`/`TutorialMenuClient` (caixa de diálogo),
  `MusicPlayerClient` (troca de trilha), `AchievementSystemServer` (entrega
  validada de recompensa/emblema)

---

**⚠️ REGRA ABSOLUTA MANTIDA DO PROJETO:** nunca criar sistema do zero — sempre
partir de um chefe/padrão já existente (deste documento ou de chefes anteriores) e
adaptar. Avisar no chat qual chefe/padrão foi reutilizado como base.

**📌 LEMBRETE FINAL:** *"PARAR O CHAT QUANDO OS SCRIPTS ESTIVEREM 100% FINALIZADOS"*

**FIM DO DOCUMENTO**
