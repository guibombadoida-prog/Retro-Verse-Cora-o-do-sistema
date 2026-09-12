# Adonis — instalado e removido

> ## ⚠️ REMOVIDO DO JOGO
>
> O Adonis entrou na publicação **#48** (12/09/2026 17:00 UTC) e saiu na
> publicação **#51**. O dono pediu a remoção depois de o console próprio do
> RetroVerse entrar no ar — ver [`CONSOLE_ADMIN.md`](CONSOLE_ADMIN.md).
>
> **O que se perdeu com ele:** ban que persiste entre sessões, mute, slowmode,
> log de comandos no DataStore e comandos entre servidores. O console do
> RetroVerse não faz nada disso. `;kick` não existe: para expulsar alguém hoje
> não há comando.
>
> **Como ele saiu, já que a publicação não apagava nada:** a tarefa
> `tasks/apply_code_payload.luau` ganhou uma lista `REMOVER` — caminhos
> explícitos, com a classe esperada conferida antes de remover. Nunca "apague o
> que não está no repositório": há 9 scripts legítimos que só existem no place.
> A remoção é a única operação da publicação sem desfazer do lado do jogo, e por
> isso é o único caminho com teste de integração dedicado
> (`tools/test_publish.py`, que roda a tarefa real num Roblox falso).
>
> **O resto deste documento é histórico**, e vale ler antes de vendorizar
> qualquer outro código de terceiros: as restrições do pipeline que ele
> descobriu continuam valendo.

---

## Leia isto primeiro: o Adonis não estava neste repositório

O que ficou versionado aqui foi o **carregador**, 12 KB. O Adonis de verdade era
baixado da Roblox a cada início de servidor:

```lua
ModuleID = 7510592873;
local success, module = pcall(require, moduleId)
```

Com dois fallbacks em cascata (`:LoadAsset` no mesmo ID e um MainModule de
backup, `17438792001`) — três assets remotos, não um.

Consequência que vale para o próximo: **auditar o repositório garante a
configuração, não o código que roda.** Cada servidor que subia confiava na Epix
Incorporated e em quem controla aqueles assets.


## Por que virou pasta, e não o Model original

*Esta é a parte reaproveitável: vale para qualquer `Model` de terceiros que
precise entrar pelo pipeline.*

O modelo do autor é `Model` → `Configuration` → `Folder`, e traz um
`NumberValue` chamado `Version` e uma `Camera` de miniatura.

A publicação "somente código" leva **apenas** `Script`, `LocalScript`,
`ModuleScript` e as `Folder` do caminho (ver
[`ADICIONAR_SCRIPT.md`](ADICIONAR_SCRIPT.md)). Como o dono não tem PC Windows,
não existe o caminho "abrir o Studio e arrastar o modelo". Então a árvore foi
remontada com o que o pipeline alcança:

```
ServerScriptService
└── Adonis_Loader          (Folder — era Model)
    ├── Config             (Folder — era Configuration)
    │   ├── API            (ModuleScript, só documentação)
    │   ├── InGameSettingsEditorSettings/  Descriptions, Order
    │   ├── Plugins/                       Client-ExamplePlugin, Server-ExamplePlugin
    │   ├── Settings/                      os 10 módulos de configuração
    │   └── Themes/                        README
    └── Loader
        └── Loader         (Script)
```

Isso funciona porque o carregador nunca usa nada específico de `Model` ou de
`Configuration`. Ele navega por `script.Parent.Parent` e só faz operações de
`Instance`: `:Clone()`, `.Name`, `.Parent`, `:FindFirstChild()`, indexação por
nome.

### Três coisas que quebram o Adonis se alguém "limpar" a pasta

1. **`Config.Settings` tem de ser uma `Folder`.** O carregador testa
   `settingsFolder:IsA("Folder")`. Se não for, ele cai no caminho de "módulo de
   settings legado" e lê tudo errado — sem erro no Output.
2. **Pasta vazia não chega ao jogo.** O `apply_code_payload.luau` só cria pasta
   que está no caminho de um script (`resolveParent`). E o carregador indexa
   `configFolder.Plugins` e `configFolder.Themes` **direto, sem
   `FindFirstChild`** — pasta ausente é erro na hora de subir. É por isso que o
   `Themes/README` e os plugins de exemplo **não são arquivo inútil**: são o que
   mantém aquelas pastas existindo.
3. **`Loader` tem de ser `Script`** (`Loader.server.lua`). Como `ModuleScript`
   ele nunca roda, e o jogo sobe sem admin nenhum, silenciosamente.

As três estão travadas em `tools/test_adonis.py`.

### Limitação conhecida e aceita

`LoaderVersion` fica `nil`. O carregador lê `model.Version.Value`, um
`NumberValue`, que o pipeline não cria. O efeito é só o Adonis perder o aviso
de "carregador desatualizado". Preferiu-se aceitar isso a remendar o código do
autor — o valor de vendorizar é o arquivo ser igual ao dele.

---

## O que foi mudado da configuração original (histórico)

Todo desvio está marcado no código com `[RETROVERSE]` e um comentário
explicando. Assim uma atualização do Adonis é um diff legível, não uma
arqueologia. **O `Loader.server.lua` é verbatim** — só ganhou um cabeçalho de
comentário.

| Configuração | Autor | Aqui | Por quê |
| --- | --- | --- | --- |
| `HideScript` | `true` | **`false`** | O autor manda desligar quando o jogo usa `AssetService:SavePlaceAsync()`, e é exatamente o que a publicação faz (`tasks/apply_code_payload.luau:364`). Com `true`, o Adonis faz `model.Parent = nil` ao subir; um salvamento nesse estado gravaria a place **sem** o Adonis. |
| `DataStoreKey` | `"CHANGE_THIS"` | sorteada | Instrução explícita do autor. Veja a ressalva abaixo. |
| `WarnDangerousCommand` | `false` | **`true`** | O dono joga no celular, onde toque errado acontece. `:shutdown` e `:ban` não têm desfazer. |
| `TopBarShift` | `false` | **`true`** | As notificações do Adonis nascem na borda de cima — onde mora o HUD de HP (`HealthDisplay` V9, canto superior direito). |
| `HelpButton` | `true` | **`false`** | Nasce no canto inferior direito, por cima da UI do jogo. No celular não há espaço sobrando. O `!help` continua pelo chat. |
| `Console_AdminsOnly` | `false` | **`true`** | Menor privilégio. Também: o console abre por tecla (`ConsoleKeyCode`), e a regra do projeto é "GUI abre por botão, nunca por keybind". |
| `G_API` | `true` | **`false`** | Nenhum script do RetroVerse consome `_G.Adonis`. Sem isso o Adonis não publica nada no ambiente global. |
| `G_Access_Key` | `"Example_Key"` | sorteada | Defesa em profundidade: um padrão conhecido não deve ficar num repositório público esperando que alguém ligue o `G_Access` sem trocar a chave. |
| `DonorCapes` / `DonorCommands` | `true` | **`false`** | Cosmético concedido por compra externa aparecendo em jogador que não é admin, num jogo de combate que tem os próprios cosméticos. |
| `Ranks.Creators` | vazio | o dono | Ver *Quem é admin*. |
| Plugin `Server-Example` | registra `:example` | comentado | Vinha com `AdminLevel = "Players"`: **qualquer** jogador rodava, e cada uso imprimia duas linhas no Output. Torneira de log aberta. O código segue no arquivo, como modelo. |

### A ressalva da `DataStoreKey`

**Este repositório é público, então essa chave é pública.** Vale entender o que
isso significa e o que não significa:

- Ela **não dá acesso a nada**. É o sal que embaralha as entradas do DataStore
  do Adonis.
- Para abusar dela, alguém precisaria **já ter** acesso de leitura ao DataStore
  — chave de Open Cloud ou script rodando no servidor.
- Trocar depois **apaga** os dados salvos do Adonis (bans e admins criados por
  `:admin`).

O jeito de tirá-la do repositório de vez seria a publicação injetar o valor de
um GitHub Secret na hora de montar o pacote. Isso é possível e está anotado
como pendência para o Codex em [`EM_ANDAMENTO.md`](EM_ANDAMENTO.md) — não foi
feito agora porque o PR #6 está mexendo justamente nos arquivos do pipeline.

### O que NÃO foi mudado, de propósito

**Todo o anti-exploit continua desligado** — `AntiSpeed`, `AntiNoclip`,
`AntiGod`, `AntiMultiTool`, `Detection`, `AllowClientAntiExploit`. Esse é o
padrão do autor e tem de continuar assim: o RetroVerse é jogo de combate, com
dash, habilidades e Despertar movendo o personagem rápido e às vezes o
teleportando. O anti-speed leria isso como exploit e **mataria ou kickaria quem
está jogando certo**. O próprio autor avisa, em caixa alta, no topo do
`AntiExploit.lua`.

`CodeExecution` também segue `false` (padrão do autor), o que desliga `:s` e
`:ls`. Num jogo com economia e DataStore, execução de código arbitrário por
comando é a chave da casa.

`AutoClean` segue `false`: ele varre o workspace, e o jogo dropa moeda no chão
(`SimpleCharacterCoinDrop`).

---

## Quem era admin

Só o dono, `1595442496` — o mesmo `OWNER_ID` de
`AdminRegistryServer.server.lua:47`. Não é segredo; é um UserId público da
Roblox, já versionado.

Ele está escrito em `Ranks.Creators` de propósito, mesmo o Adonis reconhecendo
o dono da place sozinho: se a place um dia passar para um grupo, essa detecção
muda de regra. Com o ID na lista, o acesso não depende de como a place é dona
de si.

**Os outros ranks ficam vazios.** Para dar admin a alguém, use o comando dentro
do jogo:

```
:admin fulano        -- Moderators
:headadmin fulano    -- HeadAdmins
```

Com `SaveAdmins = true` isso persiste no DataStore do Adonis. **Não precisa de
Studio nem de publicação** — que é exatamente o ponto, já que o dono não tem PC.

### Os dois sistemas de admin são separados de propósito

O RetroVerse já tinha o seu, e eles **não** foram ligados:

| | O que é |
| --- | --- |
| `_G.AdminRegistry` | Admin de **funcionalidade**: painéis do jogo, catálogo de personagem, conquistas. |
| Adonis | Admin de **moderação**: `:kick`, `:ban`, `:shutdown`. |

Unir os dois faria um `;addadmin` no painel do jogo entregar `:ban` e
`:shutdown` de brinde. Quem precisa dos dois entra nas duas listas,
explicitamente. `tools/test_adonis.py` trava isso.

---

## Como ele ficava fora das regras do projeto

`tools/validar.sh` trata `src/ServerScriptService/Adonis_Loader/` como **área de
terceiros** e o anuncia na saída (exclusão silenciosa é como um validador perde
a confiança de quem lê). Ele sai das checagens 1, 2, 3, 5, 6 e 7, cada uma por
um motivo diferente:

- **Estilo (5) e cabeçalho (6):** reescrever para o padrão do RetroVerse
  transformaria cada atualização do Adonis num merge manual.
- **`_G` (2, 3):** o `Descriptions.lua` documenta `_G.Adonis` dentro de uma
  string `[[ ]]`, que não é comentário — o `somente_codigo` não corta, e viraria
  "API `_G` consumida sem dono" para um texto de ajuda.
- **Família (1):** o Adonis traz dois módulos chamados `README`, em pastas
  diferentes. No jogo convivem; no validador bateriam como duplicata. (O
  `README` de topo, que é só documentação e nunca é carregado, foi descartado
  na vendorização; ficou só o de `Themes`, que é obrigatório.)
- **Sintaxe (7):** o `luac` do Lua 5.4 não parseia Luau, e o `Loader` usa
  interpolação com backtick e anotação de tipo. **Isso não fica sem rede:** o CI
  roda `luau-compile --only-parse` em todo `.lua` de `src/`, com o parser Luau
  de verdade.

O que substitui essas checagens é `tools/test_adonis.py`, ligado no CI: 9
arquivos obrigatórios, 4 pastas indexadas direto e 188 checagens que rodam os
módulos de `Settings` **de verdade** no Luau e travam cada decisão da tabela
acima. Ele foi verificado contra seis regressões plantadas — `HideScript` de
volta a `true`, `DataStoreKey` de volta ao padrão, `AntiSpeed` ligado, o
`Themes/README` apagado, o plugin voltando a registrar comando para jogador
comum, e o dono saindo dos Creators — e reprovou todas.

---

## Se algum dia voltar (ou entrar outro código de terceiros)

1. Baixe o carregador novo do autor e extraia os fontes.
2. Substitua os arquivos que **não** têm `[RETROVERSE]` no diff — eles são
   verbatim.
3. Nos que têm, aplique a versão nova e reponha cada desvio marcado.
4. `tools/validar.sh` e `python3 tools/test_adonis.py --luau luau`. O teste
   acusa se uma configuração de segurança voltou ao padrão do autor.
5. `verificar` e depois `publicar`, como qualquer script — ver
   [`ADICIONAR_SCRIPT.md`](ADICIONAR_SCRIPT.md).

**Nunca** escreva `Trello_AppKey` ou `Trello_Token` neste repositório. São
credenciais de verdade e o repositório é público. Se o Trello for usado algum
dia, os valores vão nos segredos da experiência
(`HttpService:GetSecret`), como o comentário do `Trello.lua` ensina. O teste
exige que os dois estejam vazios.
