# RetroVerse — Coração do Sistema

Repositório de código-fonte dos scripts do **RetroVerse** (jogo de combate no Roblox),
da Retro-Verse Studios.

O projeto tem **duas Places** do Roblox: a principal (`133619220682618`) em `src/`,
e a Place do Chefão em `boss-place/`. Cada uma tem seu próprio DataModel.

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
| `src/ServerScriptService/` | `ServerScriptService` | 34 `Script` de servidor + 1 `ModuleScript` (`PassiveCatalog`) |
| `src/ServerScriptService/RetroVerse/` | `ServerScriptService > RetroVerse` | 1 `ModuleScript` (Núcleo de Combate) |
| `src/StarterPlayer/StarterPlayerScripts/` | `StarterPlayer > StarterPlayerScripts` | 19 `LocalScript` de interface/cliente |
| `src/StarterPlayer/StarterCharacterScripts/` | `StarterPlayer > StarterCharacterScripts` | 2 `Script` que acompanham o personagem |
| `src/ReplicatedFirst/` | `ReplicatedFirst` | 1 `LocalScript` (tela de carregamento) |
| `docs/` | — | Diretrizes formais e mapa da arquitetura |
| `boss-place/` | **outra Place do Roblox** | Scripts exclusivos da Place do Chefão — ver `boss-place/LEIA-ME.md` |
| `central/` | — | Alterações estruturais aguardando instalação manual no Studio |
| `tools/` | — | `promover.sh` (confirma instalação no Studio) e `validar.sh` (7 checagens) |

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
`DataManager.server.lua` acompanha o `DataManager` do Studio de V6 até V9 sem
quebrar nenhuma referência.

**Cinco exceções**, onde o próprio cabeçalho manda que o objeto no Studio se chame
com sufixo de versão — o nome do arquivo respeita isso:

- `MusicPlayerClient_V2.client.lua` (código na V6)
- `TeamMenuClient_V2.client.lua` (código na V6)
- `TutorialMenuClient_V2.client.lua` (código na V7)
- `NPC_Server_V2.server.lua` (código na V2)
- `RetroVerse/NucleoCombate_V2.lua` (exigido pelo `require`)

---

## 🔄 Fluxos de atualização de script

O repositório agora aceita dois caminhos, sem misturá-los:

1. **Mudança somente de código (`Source`)** — altere `src/` em uma branch, passe
   pelo CI, mescle em `main`, rode **verificar** e só então **publicar**. Nesse
   caminho, `src/` é o código aprovado para implantação; mesclar não significa que
   ele já está no ar. O workflow e o histórico de versões do Creator Hub registram
   qual commit foi realmente publicado.
2. **Mudança estrutural que ainda exige Studio** — coloque a entrega versionada em
   `central/`, instale manualmente e use `tools/promover.sh`. `central/` vazia
   significa apenas que não há instalação manual pendente.

Em `src/` continua existindo exatamente um arquivo ativo por sistema. Nada de
`_V6` ao lado de `_V8`: o histórico do Git guarda as versões anteriores.

### Mudança estrutural/manual

```
   script alterado / novo
            ↓
       central/          ←── ENTREGUE, mas ainda não está no jogo
            ↓  você cola no Studio
            ↓  tools/promover.sh   ("já instalei")
 src/<local do Studio>/  ←── o que está REALMENTE rodando
            ↓
   versão anterior APAGADA
   (fica no histórico do Git)
```

### Na prática

```bash
# 1. veja o que está pendente de instalação
tools/validar.sh
#    → AGUARDA INSTALAÇÃO NO STUDIO: AwakeningSystemServer_V3.server.lua
#      (substitui V2 que está no ar)

# 2. cole no Studio, no local e nome que o cabeçalho manda,
#    apagando a versão anterior

# 3. confirme que instalou
tools/promover.sh AwakeningSystemServer_V3.server.lua

# 4. comite
git add -A && git commit -m "AwakeningSystemServer V2 -> V3 instalado"
```

⚠️ **`promover.sh` só depois de colar no Studio.** Antes disso o repositório
perderia a informação de que aquela instalação estrutural continua pendente.

O `promover.sh` não adivinha nada: o destino sai do `-- Nome:` e do
`-- Coloque em ...` do cabeçalho do próprio script. Ele também **se recusa** a
apagar um arquivo que ainda não foi comitado, porque aí a versão antiga seria
perdida de verdade em vez de ir para o histórico.

### Cabeçalho de entrega

Toda alteração de script vem acompanhada disto, no chat:

```
## Scripts Entregues — [Sistema]
Scripts Novos:        [Nome_V1] — o que faz
Scripts Modificados:  [Nome_V1] → [Nome_V2] — o que mudou
Scripts Substituídos: ⚠️ REMOVER [Nome_V1]
```

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
| 4 | Pendências em `central/` | Lista o que ainda exige instalação manual e qual versão substitui |
| 5 | `wait()` / `spawn()` / `:Destroy()` | As regras de código do projeto, ignorando comentário e bloco `--[[ ]]` |
| 6 | Nome do arquivo × `-- Nome:` | O caminho do arquivo é a instrução de instalação; divergência faz colar no lugar errado |
| 7 | Sintaxe (`src/` + `central/` + `boss-place/`) | Pega erro de estrutura antes de você colar no Studio |

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
- [`docs/SEM_PC_ANDROID.md`](docs/SEM_PC_ANDROID.md) — editar no Android, validar no GitHub, executar headless e publicar somente código via Open Cloud

### Fluxo sem Roblox Studio

O projeto inclui projetos Rojo e quatro automações com travas de segurança:

- validação de sintaxe, teste puro e build de um place sem 3D;
- execução de uma tarefa Luau dentro do motor Roblox pela Open Cloud;
- publicação manual somente do `Source` de scripts que já existam em um place,
  preservando o mapa e criando uma versão recuperável no histórico.
- bootstrap separado que pode criar a árvore de scripts **somente** em uma
  experience privada de teste, nunca na experience de produção.

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
