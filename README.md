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
| `legacy/` | — | Versões **substituídas**, guardadas só como histórico |

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
- [`docs/SEM_PC_ANDROID.md`](docs/SEM_PC_ANDROID.md) — editar no Android, validar no GitHub, executar headless e publicar somente código via Open Cloud

### Fluxo sem Roblox Studio

O projeto inclui projetos Rojo e três automações com travas de segurança:

- validação de sintaxe, teste puro e build de um place sem 3D;
- execução de uma tarefa Luau dentro do motor Roblox pela Open Cloud;
- publicação manual somente do `Source` de scripts que já existam em um place,
  preservando o mapa e criando uma versão recuperável no histórico.

As chaves da Roblox ficam em GitHub Secrets e nunca fazem parte do repositório. Veja
o guia acima antes de apontar qualquer workflow para um place.

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

## 💾 DataStore

- **Nome:** `RetroVerseDataV3_Awakening`
- **Versão dos dados:** `V4_Metadata`
- **Auto-save:** a cada 30 segundos
- Compartilhado com a *place* separada do Boss Fight
