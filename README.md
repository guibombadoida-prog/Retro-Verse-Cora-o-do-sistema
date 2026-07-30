# RetroVerse — Coração do Sistema

Repositório de código-fonte dos scripts do **RetroVerse** (jogo de combate no Roblox),
da Retro-Verse Studios.

A árvore de pastas em `src/` **espelha exatamente a hierarquia do Roblox Studio**.
O caminho do arquivo é o lugar onde o script vive no Studio — não existe adivinhação:

```
src/ServerScriptService/DataManager.server.lua
     └── ServerScriptService > DataManager   (Script)
```

---

## 📁 Estrutura

| Pasta | Corresponde no Studio a | Conteúdo |
|---|---|---|
| `src/ServerScriptService/` | `ServerScriptService` | 31 `Script` de servidor + 1 `ModuleScript` (`PassiveCatalog`) |
| `src/ServerScriptService/RetroVerse/` | `ServerScriptService > RetroVerse` | 1 `ModuleScript` (Núcleo de Combate) |
| `src/StarterPlayer/StarterPlayerScripts/` | `StarterPlayer > StarterPlayerScripts` | 18 `LocalScript` de interface/cliente |
| `src/StarterPlayer/StarterCharacterScripts/` | `StarterPlayer > StarterCharacterScripts` | 2 `Script` que acompanham o personagem |
| `src/ReplicatedFirst/` | `ReplicatedFirst` | 1 `LocalScript` (tela de carregamento) |
| `docs/` | — | Diretrizes formais e mapa da arquitetura |
| `central/` | — | Área de **trânsito** para versão nova. Normalmente vazia |
| `tools/` | — | `promover.sh` (troca de versão) e `validar.sh` (conferência) |

### Convenção de extensão

O sufixo do arquivo declara a **classe do objeto** no Studio:

| Sufixo | Classe no Studio |
|---|---|
| `.server.lua` | `Script` (roda no servidor) |
| `.client.lua` | `LocalScript` (roda no cliente) |
| `.lua` | `ModuleScript` (consumido via `require`) |

### Convenção de nome

O nome do arquivo é o **nome exato do objeto no Studio**, sem o número de versão —
a versão vive no cabeçalho do script e no histórico do Git. Assim o arquivo
`DataManager.server.lua` acompanha o `DataManager` do Studio de V6 até V8 sem
quebrar nenhuma referência.

**Cinco exceções**, onde o próprio cabeçalho manda que o objeto no Studio se chame
com sufixo de versão — o nome do arquivo respeita isso:

- `MusicPlayerClient_V2.client.lua` (código na V5)
- `TeamMenuClient_V2.client.lua` (código na V6)
- `TutorialMenuClient_V2.client.lua` (código na V6)
- `NPC_Server_V2.server.lua` (código na V2)
- `RetroVerse/NucleoCombate_V2.lua` (exigido pelo `require`)

---

## 🔄 Fluxo de atualização de script

**A regra: existe exatamente uma versão de cada script no repositório — a atual.**

Não há pasta de versões antigas em paralelo. Nada de `_V6` ao lado de `_V8`, nada de
dúvida sobre qual arquivo é o que está no jogo. O que está em `src/` é o que está
valendo. O histórico do Git faz o papel de arquivo morto.

```
      versão nova chega
             ↓
        central/  ←──── trânsito (normalmente vazia)
             ↓  tools/promover.sh
 src/<local do Studio>/  ←── pasta específica: a versão ATIVA
             ↓
    versão antiga APAGADA
 (fica no histórico do Git)
```

### Na prática

```bash
# 1. ponha a versão nova em central/, com a versão no nome
#    central/SpawnSystem_V9.server.lua

# 2. promova — apaga a V8 ativa e põe a V9 no lugar exato
tools/promover.sh SpawnSystem_V9.server.lua

# 3. confira que nada duplicou nem quebrou
tools/validar.sh
```

O `promover.sh` não adivinha nada: o destino sai do `-- Nome:` e do
`-- Coloque em ...` do cabeçalho do próprio script. Ele também **se recusa** a
apagar um arquivo que ainda não foi comitado, porque aí a versão antiga seria
perdida de verdade em vez de ir para o histórico.

### Recuperar uma versão apagada

Apagar não perde nada — só sai do caminho:

```bash
git log --oneline -- src/ServerScriptService/DataManager.server.lua
git show <commit>:src/ServerScriptService/DataManager.server.lua > recuperado.lua
```

### O que o `validar.sh` confere

| # | Checagem | Por que importa |
|:--:|---|---|
| 1 | Duplicata de família em `src/` | É a regra "nunca dois scripts da mesma família rodando ao mesmo tempo", virando checagem em vez de disciplina |
| 2 | Barreiras `repeat ... until _G.X` | Se a dependência não existir, o script espera **para sempre sem erro no Output** — a falha mais difícil de achar no projeto |
| 3 | APIs `_G` sem dono | Pega dependência quebrada antes de virar bug em jogo |
| 4 | `central/` vazia | Avisa se sobrou promoção pendente |
| 5 | `wait()` / `spawn()` / `:Destroy()` | As regras de código do projeto, ignorando comentário e bloco `--[[ ]]` |
| 6 | Nome do arquivo × `-- Nome:` | O caminho do arquivo é a instrução de instalação; divergência faz colar no lugar errado |

Sai com código 1 se achar erro, então dá para usar como *gate* antes de comitar.

---

## 🚀 Ordem de instalação no Studio

Cada script sobe sozinho e espera pelas suas dependências via `_G`
(`repeat task.wait() until _G.X`), então a ordem de *carga* do Roblox não é crítica —
o que importa é **não faltar ninguém na pasta**:

1. **Base** — `DataManager` (dono de `_G.PlayerDataManager`), `AdminRegistryServer`
2. **Serviços de stats** — `StatService`, `CharacterLevelServer`, `PassiveCatalog`
3. **Catálogo e jogo** — `CharacterCatalogServer`, `GameManager`, `SpawnSystem`
4. **Combate** — `DamageAttribution`, `RetroVerse/NucleoCombate_V2`, `StatusEffectServer`, `EnergySystemServer`, `PassiveSystemServer`, `TeamDamageProtection`
5. **Demais sistemas de servidor** — o resto de `ServerScriptService`
6. **Cliente** — `UnifiedMenuClient` é o dono de `_G.RegisterMenuCategory`; os outros
   menus se registram nele, então ele precisa estar presente para qualquer menu aparecer
7. **`MainSystemInitializer`** — orquestrador: cria as pastas de `ReplicatedStorage`,
   cria todos os Remotes, embrulha `_G.SelectCharacterFunction`, expõe
   `_G.ResetPlayerBarrier` e monitora as conexões. Não é opcional

---

## ⚠️ Dependências ainda ausentes

A cadeia `_G` está **fechada** para tudo que bloqueia: nenhuma barreira de espera
(`repeat task.wait() until _G.X`) depende de script que não esteja aqui.

Restam duas APIs consumidas mas **não definidas** em nenhum script do repositório.
As duas estão protegidas por `if`, então a ausência só desliga o recurso — não trava
sistema nenhum:

| API | Consumidor | O que se perde |
|---|---|---|
| `_G.PassiveVFX` | `PassiveSystemServer` (linhas 430, 511, 536) | Efeitos visuais das passivas (`vfx` do `PassiveCatalog` fica sem dono) |
| `_G.SetCoinMultiplier` | `DailyRewardsServer` (linhas 268, 529) | Multiplicador de moedas da recompensa diária |

Cada passiva do `PassiveCatalog` já declara seu `vfx` (`BRILHO_METALICO`,
`ESPELHO_INVERTIDO`, `CHAMA_RETRO`…), então o catálogo está pronto para o
`PassiveVFX` no dia em que ele existir — nada precisa mudar aqui quando entrar.

---

## 📖 Documentação

- [`docs/ARQUITETURA.md`](docs/ARQUITETURA.md) — inventário completo dos scripts, versões e mapa de dependências `_G`
- [`docs/Diretrizes_Sistema_Chefao_Boss.md`](docs/Diretrizes_Sistema_Chefao_Boss.md) — regras formais (V5) para criar chefões

---

## 🔒 Regras de código do projeto

Válidas para qualquer script novo ou alterado:

- `task.wait()` / `task.spawn()` — **nunca** `wait()` / `spawn()`
- `objeto.Parent = nil` — **nunca** `:Destroy()` sem autorização
- Nenhuma lógica de economia ou DataStore em `LocalScript`
- GUI abre só por botão, nunca por keybind
- Tamanhos de GUI em `Scale`, textos com `TextScaled = true`
- `ResetOnSpawn = false` em `ScreenGui` persistente
- Nunca dois scripts da mesma família rodando ao mesmo tempo — ao subir uma versão
  nova, o cabeçalho informa qual remover

O `tools/validar.sh` confere as três primeiras automaticamente.

### ⚠️ Uma exceção pendente de decisão

`src/ServerScriptService/AntiLag.server.lua:56` usa `obj:Destroy()`, contra a regra.
É código anterior a esta organização e **não foi alterado** — a regra diz "nunca
`:Destroy()` **sem autorização**", e trocar por `.Parent = nil` num script cuja
função é justamente remover objetos de lag é decisão sua, não automática.

Está registrado em `EXCECOES_DESTROY`, no topo do `validar.sh`, e aparece como aviso
em toda execução — para não sumir de vista nem deixar o validador vermelho para
sempre. Ao decidir, tire da lista.

Vale notar que os outros 29 casos de `:Destroy()` no repositório são todos
comentários do tipo `-- regra do projeto: sem :Destroy()`. Só este é código de verdade.

## 💾 DataStore

- **Nome:** `RetroVerseDataV3_Awakening`
- **Versão dos dados:** `V4_Metadata`
- **Auto-save:** a cada 30 segundos
- Compartilhado com a *place* separada do Boss Fight
