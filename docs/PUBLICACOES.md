# Publicações — o que já entrou no jogo

Registro de toda publicação feita na place de produção (`133619220682618`).

**Anotar aqui é obrigatório.** Uma publicação muda o jogo para todo mundo e
muda a base de comparação do `verificar`: o agente seguinte que rodar o
workflow vai comparar o repositório contra um jogo que alguém alterou. Sem
este registro, ele não tem como saber quando nem por quê.

Entrada nova vai no topo. Copie os números da linha `[PUBLICAÇÃO]` do log.

---

## 2026-09-12 19:32 UTC — Adonis REMOVIDO do jogo

`[PUBLICAÇÃO] 0 atualizados, 0 renomeados, 0 criados, 0 pastas criadas, 1 removidos`
Retorno: `["published", 62, 62, 0, 0, 0, 0]` — execução #52, `main` em `6365087`

`Resumo: 62 scripts; 62 iguais; 0 diferentes; 0 renomeados; 0 novos; 0 pastas
novas; 1 removidos; 9 só no place; 0 problemas`

Merge do PR #15. **Primeira publicação da história do projeto que REMOVE uma
instância.** `ServerScriptService > Adonis_Loader` saiu, com os 4 descendentes
diretos e tudo abaixo. Nenhum script do jogo foi tocado — **0 atualizados**.

> A contagem de remoções **não aparece no `Retorno`**, só na linha
> `[PUBLICAÇÃO]` e no `Resumo`. A tupla de retorno tem aridade fixa e o cliente
> Python confere o formato; mexer nela por causa disto não pagava o risco.

### Só tirar os arquivos do `src/` NÃO removeria nada

A publicação fazia rename, criava pasta, criava script e trocava `Source` —
**nunca apagava**. E o `Adonis_Loader` é uma `Folder`, então nem apareceria na
lista `?`, que só lista scripts. O Adonis continuaria **rodando no jogo e
invisível nos dois relatórios**.

### A lista `REMOVER`, e as quatro travas

`tasks/apply_code_payload.luau` ganhou uma lista explícita de remoção:

1. **Por caminho completo, com a classe esperada.** Nunca "apague o que não está
   no repositório": há 9 scripts legítimos só no place (`PlayerModule`,
   `RbxCharacterSounds`, `BossConfigServer`…) e uma regra automática levaria
   todos.
2. **A classe é conferida antes de remover.** Caminho que caia sobre outra coisa
   vira **problema** e bloqueia a publicação inteira. É a única defesa contra
   erro de digitação numa place de produção.
3. **A remoção acontece por último**, depois de todas as outras escritas darem
   certo, e entra no mesmo rollback. Remover primeiro e falhar depois deixaria o
   place sem o objeto mesmo com a publicação abortada.
4. **Caminho que já não existe não é problema** — fica inerte, igual às entradas
   de `LEGACY_NAMES`. Esta entrada já está inerte a partir de agora.

Remover uma pasta leva os descendentes: o Adonis inteiro foi **uma linha** em vez
de dezessete.

### Teste, porque remoção não tem desfazer

É a **única** operação da publicação sem desfazer do lado do jogo. As outras
sobrescrevem `Source`, e o histórico de versões do Creator Dashboard devolve.

`tools/test_publish.py` (novo, no CI) roda a tarefa **real** num Roblox falso, em
modo `check`, e cobre os quatro desfechos de um caminho de remoção — existe, já
não existe, classe diferente, nome duplicado — mais a ordem das escritas. **27
verificações.** Verificado contra quatro regressões plantadas: sem a trava de
classe, com caminho ausente virando problema, com duplicidade escolhendo o
primeiro, e com a remoção antes das criações. **Reprovou todas as quatro.**

### O que o jogo perdeu

Ban que persiste entre sessões, mute, slowmode, log de comandos no DataStore e
comandos entre servidores. O console do RetroVerse
([`CONSOLE_ADMIN.md`](CONSOLE_ADMIN.md)) não faz nada disso, e **não há comando
para expulsar ninguém** — `;kick` não existe.

### Saiu junto

Os 17 arquivos, o `tools/test_adonis.py` e o `tests/adonis_settings_harness.luau`;
a linha deles no `validate-code.yml` foi trocada pela do `test_publish.py`. A
mecânica de "área de terceiros" do `validar.sh` ficou no lugar apontando para uma
pasta que não existe, de propósito: o motivo de cada exclusão foi caro de
descobrir e vale para o próximo código de terceiros. [`ADONIS.md`](ADONIS.md)
virou histórico — as restrições do pipeline que ele revelou continuam valendo
para qualquer `Model` de terceiros.


## 2026-09-12 19:18 UTC — console de comandos retro

`[PUBLICAÇÃO] 2 atualizados, 0 renomeados, 1 criados, 0 pastas criadas`
Retorno: `["published", 79, 76, 2, 0, 1, 0]` — execução #50, `main` em `bc60ef9`

`Resumo: 79 scripts; 76 iguais; 2 diferentes; 0 renomeados; 1 novos; 0 pastas
novas; 9 só no place; 0 problemas`

Merge do PR #14. Motor de comandos próprio do RetroVerse, formato inspirado no
Adonis. Decisões: [`CONSOLE_ADMIN.md`](CONSOLE_ADMIN.md).

- **`RetroCommands`** (novo, ModuleScript) — tabela de 34 comandos + dispatcher.
- **`AdminSystemServer`** V8 → **V9** — monta o contexto, resolve o nível,
  entrega o resultado na tela.
- **`AdminMenuClient`** V12 → **V13** — aba CONSOLE.

Os três foram publicados **juntos de propósito**: o V13 usa os remotes
`AdminListCommands` e `AdminRunCommand`, que só existem no V9. O client degrada
com aviso na tela se o servidor for antigo; o contrário não.

### Os quatro defeitos do V8 que isto conserta

1. **Silêncio.** `Players:FindFirstChild(args[2])` devolvendo `nil` caía no fim
   do `if` e **nada acontecia** — nem erro, nem aviso. O admin não distinguia
   "errei o nome" de "o jogador saiu" de "esse comando não existe".
2. **Nome exato obrigatório.** Sem `me`, `all`, `others` nem prefixo parcial. O
   dono joga no celular: digitar o username inteiro com a capitalização certa
   era a diferença entre o comando existir e não existir.
3. **`;help` imprimia no F9.** No celular não há F9 — a lista de comandos era
   invisível justamente para quem mais precisava dela.
4. **Comando era código.** O painel não podia listar o que existe, então a lista
   vivia duplicada à mão nos dois lados.

O contrato central: **todo caminho do dispatcher devolve mensagem.** O teste
roda os 34 comandos sem argumento e depois todos com alvo inexistente, cobrando
mensagem não vazia em cada um. Alvo ambíguo é **recusado** com a lista de quem
casou, nunca resolvido por conta própria — escolher errado num `;kill` é pior do
que não fazer nada.

### Mudança de permissão, uma só

**`;reset` subiu para DONO.** Apaga dados sem desfazer, e no V8 qualquer admin
rodava em qualquer conta. `addadmin`/`deladmin` ficaram em CHEFE por paridade
com o V8 e com a aba ADMINS do painel. Admin do `_G.AdminRegistry` entra como
CHEFE, então **todo comando que ele já tinha continua na mão dele**.

### Bug de UI achado no caminho

A régua das abas do painel era fixa (`tabStep = 0.165`). Com a sétima aba,
7 × 0.165 = 1.155 — ela **sairia do painel**. Passou a ser derivada de
`#tabNames`, então a oitava não quebra.

### O `verificar` de novo foi o que deu a garantia

Execução #49, na branch: `["check", 79, 76, 2, 0, 1, 0]` — 1 novo, 2 diferentes,
**0 renomeados, 0 problemas**, e os 9 scripts que só existem no place seguem os
mesmos nove, nenhum parecido com o console. Depois do merge, `git diff` provou
que o `src/` da `main` era idêntico ao que a #49 aprovou, antes de publicar.

### Duas coisas aprendidas quebrando

Registradas no `AGENTS.md`:

- **Backtick não passa em `src/`.** A checagem 7 do `validar.sh` usa o `luac` do
  Lua 5.4, que não parseia interpolação Luau. Todo backtick que existe em `src/`
  está dentro de comentário, e é por isso.
- `string.format("achei "%s" aqui", x)` — aspas internas sem escape — **passa**
  pelo `luac`, porque lê como `"achei " % s("aqui")`: sintaxe válida, erro em
  runtime. O validador aprovou; **quem pegou foi o teste.**

### Rede de proteção

`tests/RetroCommands.spec.luau`, ligado no CI: **876 verificações, 34 comandos.**
Verificado contra quatro regressões plantadas — ambiguidade escolhendo o
primeiro, `;reset` rebaixado, comando voltando calado e `listarPara` vazando a
função — e reprovou todas. A terceira só reprovou depois de fechar um buraco no
próprio teste: nenhum comando real devolve mensagem vazia, então o caminho do
fallback nunca era exercido.


## 2026-09-12 17:00 UTC — Adonis admin no jogo

`[PUBLICAÇÃO] 0 atualizados, 0 renomeados, 17 criados, 7 pastas criadas`
Retorno: `["published", 78, 61, 0, 0, 17, 0]` — execução #48, `main` em `e01b55a`

`Resumo: 78 scripts; 61 iguais; 0 diferentes; 0 renomeados; 17 novos; 7 pastas
novas; 9 só no place; 0 problemas`

**Adonis** (carregador oficial, asset `7510622625`) em
`ServerScriptService > Adonis_Loader`. Merge do PR #13. Decisões, justificativas
e como atualizar: [`ADONIS.md`](ADONIS.md).

Nenhum script existente foi tocado — **0 atualizados**. As 7 pastas criadas são
exatamente as que o carregador exige: `Adonis_Loader`, `Config`,
`Config/Settings`, `Config/Plugins`, `Config/Themes`,
`Config/InGameSettingsEditorSettings` e `Loader`.

### O `verificar` foi o que garantiu que não nasceu um Adonis duplicado

Execução #47, na branch: `["check", 78, 61, 0, 0, 17, 0]` — 17 novos, **0
diferentes, 0 renomeados, 0 problemas**. O `0 diferentes` é a prova: se já
houvesse um carregador do Adonis nesses caminhos, ele casaria por nome e
apareceria como igual ou diferente, nunca como novo.

Nessa execução o log da tarefa Roblox veio "(nenhuma mensagem)" e a lista `?`
não chegou item por item — cruzei com a da execução #44. A publicação trouxe a
lista completa e confirmou: os 9 scripts que só existem no place seguem sendo
`BossConfigServer`, `Boss_CatalogGate_V1`, `Death`, `PassiveVFXServer`,
`SystemDiagnostic`, `PassiveVFXClient`, `PlayerModule`, `PlayerScriptsLoader` e
`RbxCharacterSounds`. Nenhum é Adonis.

### Remontado como pastas porque o Model não passa pelo pipeline

O modelo do autor é `Model` → `Configuration` → `Folder`, com um `NumberValue` e
uma `Camera`. A publicação só leva `Script`, `LocalScript`, `ModuleScript` e as
`Folder` do caminho. Funciona porque o carregador nunca usa nada específico de
`Model`: navega por `script.Parent.Parent` e só faz operações de `Instance`.

Consequência aceita: `LoaderVersion` fica `nil`, porque `Version` é um
`NumberValue`. O Adonis perde só o aviso de "carregador desatualizado".

### O que foi endurecido antes de subir

Cada desvio está marcado com `[RETROVERSE]` no código. Os que mais importam:

- **`HideScript` `true` → `false`.** O autor manda desligar quando o jogo usa
  `AssetService:SavePlaceAsync()`, e é o que esta publicação faz. Com `true`, o
  Adonis faz `model.Parent = nil` ao subir, e um salvamento nesse estado
  gravaria a place **sem** o Adonis.
- **`DataStoreKey` sorteada** (era `"CHANGE_THIS"`). O repositório é público,
  então a chave é pública — ela é só o sal do DataStore do Adonis, não dá acesso
  a nada, e abusar dela exigiria já ter acesso de leitura ao DataStore.
- **`TopBarShift` → `true`**: as notificações do Adonis nasciam na borda de
  cima, onde mora o HUD de HP do `HealthDisplay` V9.
- **`HelpButton` → `false`**: nascia no canto inferior direito, sobre a UI do
  jogo.
- **`Console_AdminsOnly` → `true`**, **`G_API` → `false`**, `G_Access_Key`
  sorteada, `WarnDangerousCommand` → `true`, capas e comandos de doador
  desligados.
- **Plugin de exemplo do servidor**: registrava `:example` com
  `AdminLevel = "Players"` — qualquer jogador rodava e cada uso imprimia no
  Output. Comentado.
- **`Ranks.Creators`** recebe `1595442496`, o mesmo `OWNER_ID` de
  `AdminRegistryServer`. Os outros ranks ficam vazios: admin novo entra por
  `:admin` dentro do jogo, que persiste no DataStore e **não exige publicação**.

**Anti-exploit ficou todo desligado**, que é o padrão do autor e tem de
continuar: `AntiSpeed`/`AntiNoclip` num jogo com dash e Despertar matariam
jogador legítimo. O aviso está em caixa alta no topo do `AntiExploit.lua`.
`CodeExecution` e `AutoClean` também seguem `false`.

### O Adonis não está no repositório

O que foi publicado é o carregador, 12 KB. O Adonis de verdade é baixado da
Roblox a cada início de servidor (`require(7510592873)`, com dois fallbacks).
Auditar o repositório garante a **configuração**, não o código que roda. O dono
foi informado e decidiu seguir.

### Rede de proteção

`tools/test_adonis.py`, ligado no CI: estrutura da árvore (9 arquivos
obrigatórios, 4 pastas indexadas direto sem `FindFirstChild`) e 188 checagens
que rodam os módulos de `Settings` de verdade no Luau. Verificado contra seis
regressões plantadas e reprovou todas.


## 2026-09-12 16:50 UTC — tutorial V8.3: câmera e movimento

`[PUBLICAÇÃO] 1 atualizados, 0 renomeados, 0 criados, 0 pastas criadas`
Retorno: `["published", 61, 60, 1, 0, 0, 0]` — execução [#46](https://github.com/guibombadoida-prog/Retro-Verse-Cora-o-do-sistema/actions/runs/34706417880), `main` em `6a00d54`.

**`TutorialMenuClient_V2` V8.2 → V8.3**, pela [PR #12](https://github.com/guibombadoida-prog/Retro-Verse-Cora-o-do-sistema/pull/12).

- A câmera não é retomada automaticamente após dano, movimento, teleporte, troca de câmera ou saída da base. A retentativa de 0,5 s atende somente um pedido pendente, inclusive enquanto a tag `InSafeZone` inicial ainda não chegou.
- O tutorial não consome mais os comandos de andar/pular. Mover o personagem devolve a câmera normal.
- `CÂMERA` liga/desliga somente a cena, preservando texto animado e efeitos. `ANIM.` controla a redução de movimento; os motivos de indisponibilidade aparecem abaixo das opções.
- Mantidos a espera pela zona segura da V8.1 e o `CFrame.lookAt` direto da V8.2 do Claude.

**Validação:** retomada após dano reproduzida no código antes da correção; 54 regressões do LocalScript em ambiente simulado, 520 verificações de apresentação, parser Luau, build Rojo e CI aprovados. Não houve validação visual ou de toque no cliente Roblox neste ambiente.

**Comparação prévia:** execução #45 retornou `["check", 61, 60, 1, 0, 0, 0]` (um diferente, zero renomeações/criações/problemas); o serviço não devolveu as mensagens detalhadas nessa execução. A execução #46 confirmou no log que somente `TutorialMenuClient_V2` foi atualizado.

**Coordenação:** revisão concluída pelo Codex sobre a V8.2 publicada pelo Claude. A reserva foi liberada; os testes novos já rodam no CI existente. Detalhes em `docs/TUTORIAL_V8.md`.

## 2026-09-10 22:06 UTC — câmera do tutorial parou de tremer

`[PUBLICAÇÃO] 1 atualizados, 0 renomeados, 0 criados, 0 pastas criadas`
Retorno: `["published", 61, 60, 1, 0, 0, 0]` — execução #44, `main` em `8b9d1eb`

**`TutorialMenuClient_V2` V8.1 → V8.2.** O dono relatou a câmera dinâmica de
movimentação bugada no tutorial.

### A rotação era suavizada duas vezes

Cada quadro fazia, nesta ordem:

```
blended = lerp(posição atual, posição desejada, alpha)   -- posição suavizada
destino = lookAt(blended, focus)                          -- rotação CERTA
rotated = lerp(rotação atual, destino, alpha)             -- suavizada DE NOVO
```

A câmera acabava **na posição nova olhando para uma direção entre a antiga e a
nova**. O atraso dependia de `alpha`, que vem do `dt`; num celular com FPS
variável o `dt` varia a cada quadro, então o atraso variava junto e o
personagem balançava dentro do quadro em vez de ficar parado no centro.

A posição já é suavizada pelo `blended`. Aplicar o `lerp` de novo na rotação
suaviza um valor que já estava suavizado. O V8.2 aponta direto:

```lua
camera.CFrame = CFrame.lookAt(blended, focus)
```

### Verificação

- `tools/test_tutorial.py` — 31 regressões de ciclo de vida passaram. Esse teste
  carrega o LocalScript de verdade, então confirma que a câmera continua sendo
  devolvida em toda saída.
- `TutorialPresentation.spec.luau` — 520 verificações passaram.
- `verificar` (execução #43): 1 diferente, 0 novos, 0 renomeados, 0 problemas.

## 2026-09-10 22:02 UTC — HUD do HP pequeno no canto superior direito

`[PUBLICAÇÃO] 1 atualizados, 0 renomeados, 0 criados, 0 pastas criadas`
Retorno: `["published", 61, 60, 1, 0, 0, 0]` — execução #42, `main` em `da7a976`

**`HealthDisplay` V8.5 → V9.** O dono pediu a UI inteira pequena e no canto
superior direito.

### Quem mandava no celular era o piso, não as frações

Medido antes de mexer: em **todo** aparelho de celular o HUD estava travado no
piso `ESCALA_MIN = 0.46`. O resultado de `min(largura, altura)` caía abaixo de
0.46 e o clamp puxava de volta.

Ou seja, baixar `FRACAO_ALTURA` sozinho — que é exatamente o que o comentário
do V8.2 mandava fazer — **não mudaria nada** no celular. Isso também explica
por que os acertos do V8.1 e do V8.2 renderam menos do que os números
prometiam: eles mexeram nas frações, e no celular quem decidia era o piso.

Para encolher de verdade é preciso baixar as frações **e** o piso juntos, e
junto deles os mínimos do `UITextSizeConstraint` — senão a caixa encolhe, o
texto bate no próprio mínimo e transborda.

| tela | antes | agora |
| --- | --- | --- |
| celular deitado | 193 px — 25.4% | **126 px — 16.6%** |
| celular do print | 193 px — 21.5% | **126 px — 14.0%** |
| tablet | 274 px — 23.0% | **185 px — 15.5%** |
| desktop | 357 px — 18.6% | **231 px — 12.0%** |

### Posição

Âncora `(0.5, 0)` → `(1, 0)`, posição na borda direita menos a margem. A
âncora no canto importa por causa do `UIScale`: ele encolhe o HUD **em direção
ao ponto ancorado**, então o canto superior direito fica parado em qualquer
escala, em vez de a caixa deslizar de aparelho para aparelho.

De quebra o HUD sai de cima do aviso de alvo do `WantedClient`, que é
centralizado no topo — a sobreposição registrada no V8.4 como efeito colateral
conhecido deixa de existir.

> O comentário de afinação foi reescrito. Ele dizia para **não** descer o piso
> abaixo de 0.46, orientação que agora está errada e faria o próximo agente
> desfazer esta mudança achando que estava consertando algo.

## 2026-09-08 22:24 UTC — HOTFIX: câmera do tutorial nunca assumia

`[PUBLICAÇÃO] 1 atualizados, 0 renomeados, 0 criados, 0 pastas criadas`
Retorno: `["published", 61, 60, 1, 0, 0, 0]` — execução #40, `main` em `b23f21b`

**`TutorialMenuClient_V2` V8 → V8.1.** O dono relatou logo depois da
publicação #38: *"o movimento e o botão da câmera não funciona"*.

### Uma causa, dois sintomas

`startCamera()` rodava **uma vez**, no instante da abertura. A guarda
`canTakeCamera` exige a tag `InSafeZone` — que quem põe no personagem é o
**servidor**, pelo `SpawnSystem`. Abrir o tutorial um segundo cedo demais,
antes de a tag replicar, ou estando fora do lobby, fazia a recusa valer para a
**sessão inteira**. Sem retentativa e sem uma palavra explicando.

O botão MOV. parecia morto pela mesma razão: apertá-lo alternava
`state.reducedMotion` e chamava a mesma `startCamera()`, que recusava de novo
pela mesma guarda. Nada mudava na tela.

### O que entra

- **Retentativa** a cada 0,5 s dentro do `Heartbeat` que já existia, enquanto o
  tutorial está aberto e a câmera livre. A cena assume sozinha assim que o
  jogador entra na base, sem precisar fechar e reabrir.
- **Motivo no botão.** `"CÂMERA: LIVRE"` era o mesmo texto para estar fora da
  base, sem personagem, com a câmera tomada por outro sistema ou já
  `Scriptable`. Agora o botão diz qual é.
- **Garantia de movimento.** Sem cena em andamento, o bloqueio de movimento é
  desfeito todo quadro. Travar o personagem é o pior estrago que este script
  consegue causar, e não vale depender de um único caminho de saída.

> **Armadilha de Lua que quase passou:** `cameraBlockReason()` nasceu na linha
> 312 mas chama `livingCharacter()`, declarado só na 546. Isso não é erro de
> sintaxe — vira leitura de um global inexistente e quebra em tempo de
> execução. O `validar.sh` não pega esse tipo de defeito. Movido para depois
> da dependência antes de publicar.

> **Colisão de agente:** o Codex tinha reservado este mesmo arquivo para esta
> mesma correção em `EM_ANDAMENTO.md`, e o Claude mexeu sem ler a tabela antes
> — que é justamente o que o `AGENTS.md` manda fazer. A tabela foi atualizada
> avisando que o hotfix já está na `main`, para ele revisar em vez de refazer.

## 2026-09-08 16:19 UTC — tutorial V8 cinematográfico

`[PUBLICAÇÃO] 1 atualizados, 0 renomeados, 1 criados, 0 pastas criadas`
Retorno: `["published", 61, 59, 1, 0, 1, 0]` — execução #38, `main` em `c941c8c`

Merge da PR #11 do Codex, **auditado antes de publicar**. O código estava na
`main` desde 13:12 mas a execução #37 tinha sido `[VERIFICAÇÃO]`, não
publicação — o jogo continuava com o tutorial antigo até agora.

**`TutorialMenuClient_V2` V8** — câmera com enquadramento de personagem e
lobby, órbita discreta, FOV suavizado e raycast para não atravessar parede. A
câmera é devolvida ao fechar, pular, morrer, sair do lobby, tomar dano,
teleportar, abrir o menu do Roblox ou remover a GUI; outro dono de câmera não
é sobrescrito, e VR ou a preferência de movimento reduzido desligam a parte
cinematográfica.

**`TutorialPresentation` (criado)** — ModuleScript com a matemática pura de
mola e paginação, separada do resto justamente para poder ser testada sem o
jogo rodando. É o `1 criados` desta publicação.

### Auditoria antes de publicar

O Codex evitou as cinco armadilhas do projeto:

| | resultado |
| --- | --- |
| `TweenService:Create` / `:Cancel()` | 1 (no gerenciador) / 2 |
| toque | `InputBegan`/`InputEnded`; `MouseEnter` só como extra |
| `ZIndexBehavior` | `Sibling` |
| aritmética com `uiScale` | nenhuma |
| `BodyVelocity` / `:Destroy()` | zero |

Os quatro laços `while` do arquivo são legítimos — subida de ancestrais,
revelação de texto limitada a 12 glifos por quadro e duas esperas com prazo.
Nenhum cria tween. `validar.sh` limpo, 67 scripts no repositório.

> **Pendência conhecida:** a PR trouxe `tests/TutorialPresentation.spec.luau`,
> `tests/tutorial_client_harness.luau` e `tools/test_tutorial.py`, mas o
> `validate-code.yml` só executa `tests/PassiveCatalog.spec.luau`. Os testes
> novos **não rodam em lugar nenhum** e vão apodrecer se ninguém os ligar ao
> CI. Reportado ao dono; ele decidiu publicar primeiro.

## 2026-09-04 22:54 UTC — sistema de música: servidor robusto, cliente animado

`[PUBLICAÇÃO] 2 atualizados, 0 renomeados, 0 criados, 0 pastas criadas`
Retorno: `["published", 60, 58, 2, 0, 0, 0]` — execução #36, `main` em `769ca93`

### `MusicCatalogServer` V2 → V3

**O defeito grave: falha de rede apagava a trilha de todo mundo.**
`carregar()` fazia `faixas = {}` quando o `GetAsync` falhava, e o laço de
reconciliação chama `carregar()` de 60 em 60 segundos. Uma única falha
passageira do DataStore zerava a lista em memória e o servidor **mandava a
lista vazia para todos os clientes** — a música parava na partida inteira, sem
nada no log dizendo o motivo. Falha de leitura e catálogo vazio eram a mesma
coisa para o código.

Agora a leitura tenta três vezes com espera crescente e, ao desistir,
**preserva** a lista anterior e devolve `false`. `pronto` só vira `true` numa
leitura que deu certo.

Mais quatro pontos de robustez:

- **Edição sumia.** A reconciliação comparava só `#faixas`. Renomear uma faixa
  não muda a contagem, então quando a mensagem do `MessagingService` se perdia
  o servidor lia a lista nova, via o mesmo número e não avisava ninguém — os
  jogadores ficavam com o título velho para sempre. Agora compara uma
  assinatura do conteúdo.
- **Escrita sem segunda chance.** Um throttle passageiro virava "Erro ao
  salvar" e a faixa recém-digitada se perdia. Agora repete — e distingue
  recusa de regra (lista cheia, ID repetido), que não repete, de falha de rede.
- **Orçamento ignorado.** A reconciliação consulta
  `GetRequestBudgetForRequestType` e pula a volta quando está no fim. Perder
  uma releitura periódica é barato; entupir a fila do DataStore atrasa até a
  gravação do admin.
- **Admin sem freio.** Segurar o botão gastava cota de `MessagingService`, que
  é por servidor e, estourada, derruba o sync para **todos**. Intervalo mínimo
  por admin.

### `MusicPlayerClient_V2` V6 → V7

O arquivo tinha 13 `TweenService:Create` e **nenhum** `:Cancel()`.

- **Nada reagia no celular.** Todo o retorno visual dos botões e das faixas
  estava dentro de `if not isMobile`, preso a `MouseEnter`/`MouseLeave` — que
  não disparam em toque. No aparelho do dono o player era inerte: nem apertar
  mostrava que tinha apertado. Agora é `InputBegan`/`InputEnded`.
- **O marcador corria atrás do dedo.** Volume e grave criavam um tween de
  0,05 s a cada quadro de arrasto: cem animações por segundo na mesma
  propriedade. Arrasto virou posição direta; tween é para transição.
- **A música parava sozinha.** Pausar e retomar depressa deixava o fade-out
  antigo terminar *depois* do play e pausar a faixa recém-retomada — parecia
  bug do botão. Entrada e saída agora dividem a chave de tween e carregam uma
  geração.
- **Vazamento na borda.** O brilho rodava `while` criando dois tweens a cada
  2,8 s para sempre, porque o `ScreenGui` tem `ResetOnSpawn = false`.

A janela abre e fecha por mola no `Heartbeat`, o mesmo idioma dos outros
menus. O fechamento dependia de `task.delay(0.2)` para esconder o frame:
reabrir dentro desses 0,2 s fazia o delay velho esconder a janela
recém-aberta.

| | antes | agora |
| --- | --- | --- |
| `TweenService:Create` | 13 | 1 (no gerenciador) |
| `:Cancel()` | 0 | 2 |
| laços `while` | 2 | 1 (espera de `TimeLength`, não cria tween) |
| `MouseEnter` | 2 | 0 |

## 2026-09-03 15:24 UTC — traço do texto do card

`[PUBLICAÇÃO] 1 atualizados, 0 renomeados, 0 criados, 0 pastas criadas`
Retorno: `["published", 60, 59, 1, 0, 0, 0]` — execução #34, `main` em `95bc36f`

**`CharacterSystemClient` V14 → V14.1.** O dono viu no jogo: o texto do card
de personagem estava saturado.

### A causa

`UIStroke.ApplyStrokeMode` tem padrão `Contextual`, e em **TextLabel** isso
aplica o traço nas **letras**, não na borda da caixa. Três selos criavam o
stroke sem declarar o modo — e nos três a cor do traço era **idêntica à cor
do texto**, com 2 px e sem transparência:

| elemento | texto | traço |
| --- | --- | --- |
| `categoryBadge` | `categoryMeta.color` | `categoryMeta.color` |
| `rarityBadge` | branco | branco |
| `coinsLabel` | amarelo | amarelo |

Cada letra ganhava um halo sólido de 2 px da própria cor, o que dobra a massa
colorida dentro do mesmo glifo — é exatamente isso que se lê como saturado.

O que denuncia a intenção original: todo o resto do card usa stroke como
borda de moldura (`card`, `imageContainer`), e os dois selos têm fundo
próprio. O contorno sempre foi para ser da **caixa**.

### A correção

`ApplyStrokeMode.Border` explícito nos três, espessura de 2 para 1 e
transparência entre 0.35 e 0.4, para o contorno acompanhar a paleta do card
em vez de competir com o texto.

Junto foi um defeito do V13: o brilho do selo de raridade no painel de
detalhe tinha o mesmo problema. O comentário promete "brilho pulsante" em
volta do selo, mas sem declarar o modo o tween pulsava uma franja colorida
nas letras escuras. Também virou `Border`.

Auditados os 14 `UIStroke` do arquivo: os **4 que ficam em TextLabel** agora
declaram `Border`; os 10 restantes estão em `Frame`, onde `Contextual` já
significa borda, e não foram tocados.

> Armadilha para o próximo: `UIStroke` num `TextLabel` contorna o **glifo**,
> não a caixa, a menos que `ApplyStrokeMode` seja declarado. Nenhuma
> validação do repositório pega isso.

## 2026-09-03 02:27 UTC — detalhes de personagem V14 publicados

`[PUBLICAÇÃO] 1 atualizados, 0 renomeados, 0 criados, 0 pastas criadas`
Retorno: `["published", 60, 59, 1, 0, 0, 0]` — execução #32, `main` em `4c324c0`

**`CharacterSystemClient` V14 — merge da PR #10.** O conteúdo das abas
Informações, Lore e Despertar volta a aparecer: o modal agora usa
`ZIndexBehavior.Sibling`, impedindo que as seções internas sejam desenhadas
atrás do painel.

O mesmo modal ganhou as abas **Habilidades** e **Atributos**. Habilidades lê as
`Tool`s das formas normal e desperta e mostra os metadados disponíveis;
Atributos mostra vida base, arquétipo, bônus e penalidades do
`CharacterStatsServer`. As cinco abas usam distribuição responsiva e rótulos
curtos no celular em retrato.

A verificação anterior, execução #31, encontrou exatamente 1 script diferente,
0 renomeados, 0 novos e 0 problemas.

## 2026-09-03 00:39 UTC — números de dano retro, versionados

`[PUBLICAÇÃO] 2 atualizados, 2 renomeados, 0 criados, 0 pastas criadas`
Retorno: `["published", 60, 58, 2, 2, 0, 0]` — execução #30, `main` em `68e67ba`

O jogo já mostrava número de dano, por dois scripts que rodavam no place
**sem cópia no repositório**: `dmgindi` (servidor, 1499 bytes) e
`dmgindicator` (cliente, 5783 bytes). Sem versão, ninguém podia corrigir nem
melhorar nenhum dos dois.

**Os dois renomeados, não duplicados.** `LEGACY_NAMES` ganhou o par, e o
`verificar` da execução #29 confirmou antes de publicar: `2 renomeados,
0 novos`. Sem esse registro a publicação teria criado uma segunda cópia de
cada um, e cada golpe sairia com dois números na tela.

A lista de scripts que só existem no place caiu de **11 para 9**.

### `DamageIndicatorServer`

Quem decide quanto apareceu é o servidor; o cliente só desenha. Deixar o
cliente ler a vida alheia daria a ele a chance de mostrar dano que não houve.

- **Acumula antes de mandar.** Dano contínuo chega em fatias de 1 ou 2 por
  tique; um número por tique encheria a tela de "1" e esconderia a luta. As
  fatias do mesmo alvo somam numa janela de 0,12 s e saem como um número só.
- **Só vê quem está perto.** `FireAllClients` mandaria todo golpe do mapa para
  todo mundo. Destinatários escolhidos por distância, raio de 140 studs.
- **Quem bateu recebe marcado.** O `DamageAttribution` V4 já sabe quem causou
  o dano; o dado vai junto e o cliente do atacante desenha o próprio acerto
  diferente do dos outros.
- Teto de 12 envios por segundo por vítima; vigia NPC e chefão também;
  `_G.DamageIndicator.mostrar()` para quem aplica dano por conta própria.

### `DamageIndicatorClient`

- **Pool de 28**, sem criar e destruir. Em luta boa saem vários números por
  segundo, e criar `BillboardGui` + `TextLabel` + `Part` por golpe vira lixo
  para o coletor bem no momento em que o quadro não pode cair. Estourando o
  pool, o mais velho é reciclado — perder número antigo é melhor que perder
  quadro.
- **Um `Heartbeat` para todos.** Um tween por número seria 28 disputando o
  mesmo orçamento, e tween não faz arco: interpola em linha reta. O movimento
  é balístico de verdade — velocidade inicial para cima e para o lado,
  gravidade e arrasto integrados por quadro. Nada de `BodyVelocity`.
- Fonte Arcade, contorno preto de pixel art, paleta do `HealthDisplay`. Cor
  por caso: dano comum, golpe pesado, cura, o **seu** acerto, e o dano que
  você tomou.
- Espalhamento lateral aleatório, senão dois golpes seguidos no mesmo alvo
  sobem na mesma linha e um esconde o outro. Some só no terço final, porque
  apagar desde o começo tira o tempo de leitura.

## 2026-09-02 21:56 UTC — modal unificado de detalhes publicado

`[PUBLICAÇÃO] 1 atualizados, 0 renomeados, 0 criados, 0 pastas criadas`
Retorno: `["published", 58, 57, 1, 0, 0, 0]` — execução #28, `main` em `7111daa`

**`CharacterSystemClient` — merge da PR #9.** Informações, Lore e Despertar
agora dividem um modal responsivo com três abas. A tela ganhou entrada por mola
amortecida, transição entre abas, seções em cascata, texto progressivo e
reconstrução ao girar o celular sem perder a aba selecionada.

O hotfix publicado às 21:07 foi preservado durante o merge:
`escalaPorTela()` continua sendo usado tanto no corpo da Lore quanto na altura
das habilidades de Despertar, evitando novamente a multiplicação de número por
`uiScale`, que é uma tabela.

A validação da `main` (execução #32) passou. A verificação anterior à
publicação (execução #27) encontrou exatamente 1 script diferente, 0 renomeados,
0 novos, 0 pastas novas e 0 problemas — o único alterado foi
`StarterPlayer > StarterPlayerScripts > CharacterSystemClient`.

## 2026-09-02 21:07 UTC — HOTFIX: a Lore estava quebrada no jogo

`[PUBLICAÇÃO] 1 atualizados, 0 renomeados, 0 criados, 0 pastas criadas`
Retorno: `["published", 58, 57, 1, 0, 0, 0]` — execução #26, `main` em `d77eb4a`

**`CharacterSystemClient` V13 → V13.1.** A publicação das 20:08 subiu com um
erro de runtime que derrubava o painel de Lore. O Codex confirmou com print
do celular e avisou pela PR #9:

```
CharacterSystemClient:994: attempt to perform arithmetic (mul) on number and table
```

### O nome enganou

Desde a V12, `getUIScale()` devolve uma **tabela** de configuração responsiva
— `{ menu, panelAspect, portrait, card }` — e não o fator de escala que o
nome `uiScale` sugere. O V13 escreveu `16 * uiScale` como se fosse número.

Isso **compila**. Passa no `luau-compile`, no Rojo e no `validar.sh`, porque
nenhum deles checa tipo. Só quebra quando o jogador abre o painel — e foi
assim que chegou à produção.

### Dois lugares, não um

O Codex reportou a linha 994, em `criarAreaDeTexto`, que é a do print e
derruba a Lore. A mesma multiplicação estava na 1909, em `alturaLinha`, e
derrubava a lista de habilidades do painel de Despertar. Os dois corrigidos.

### A correção

`escalaPorTela(base, minimo, maximo)` deriva um escalar de verdade do lado
curto do viewport, com 640 de referência e clamp nas pontas:

| tela | lado curto | texto | altura de linha |
| --- | --- | --- | --- |
| celular deitado | 360–500 | 13 | 18 |
| tablet | 834 | 19 | 31 |
| desktop | 1080 | 19 | 32 |

O comentário no topo da função registra a armadilha, porque o nome `uiScale`
vai continuar convidando ao mesmo erro.

> **Sobre a PR #9:** ela diagnosticou o defeito corretamente no comentário,
> mas **não o corrigiu** — as duas linhas quebradas estão idênticas na
> branch. Mesclar a #9 não teria consertado o jogo. Este hotfix é
> independente dela e a #9 continua aberta, aguardando decisão do dono.

## 2026-09-02 20:08 UTC — lore e Despertar com texto digitado

`[PUBLICAÇÃO] 1 atualizados, 0 renomeados, 0 criados, 0 pastas criadas`
Retorno: `["published", 58, 57, 1, 0, 0, 0]` — execução #24, `main` em `19b36a6`

**`CharacterSystemClient` V12 → V13.** Os painéis de lore e de Despertar eram
os dois últimos do arquivo sem animação nenhuma: nasciam prontos com
`Parent = playerGui` e sumiam com `Parent = nil`.

### O defeito que mais atrapalhava a leitura

Os dois liam texto longo com `TextScaled`, que encolhe a fonte até a última
palavra caber na caixa. Quanto **mais** história o personagem tivesse,
**menor** ficava a letra — um personagem bem escrito era punido com texto
ilegível no celular. Agora a fonte tem tamanho fixo derivado do `uiScale`,
com `UITextSizeConstraint`, dentro de `ScrollingFrame` com
`AutomaticCanvasSize`. Texto grande rola em vez de encolher.

### Animação de texto

`maquinaDeEscrever()` revela a história letra a letra por
`MaxVisibleGraphemes`. Duas decisões que valem registro:

- **Não reatribui `Text` a cada quadro.** Cortar a string e reescrever
  recalcula a quebra de linha em toda letra, e com `TextWrapped` a última
  palavra fica pulando de linha enquanto digita. `MaxVisibleGraphemes` esconde
  o final sem tocar em `Text`, então a quebra é a final desde o primeiro
  quadro e nada se move na tela.
- **Conta grafema, não byte.** "ç" e "ã" ocupam dois bytes e emoji ocupa mais;
  cortar por byte mostraria meio caractere.

O atraso inicial vive dentro da própria máquina, no `Heartbeat`, em vez de um
`task.wait` antes de chamar — assim morre junto do contexto se o jogador
fechar o painel antes de a digitação começar. Tocar no texto revela tudo.

### Painel de lore

Ganhou o retrato do personagem — ler a história de alguém sem ver quem é era
o pior detalhe daquela tela —, selo de raridade na cor da raridade com brilho
pulsante nas que têm `glow`, e a lore num corpo rolável e digitado.

### Aba de Despertar

Seções entram escalonadas pelo `DelayTime` do `TweenInfo`, a lista de
habilidades aparece linha a linha, e a moldura respira em magenta enquanto o
Despertar está trancado, parando quando está liberado — o estado vira
movimento, dá para saber de longe sem ler o selo. O retrato entra com
transparência 0.45 quando bloqueado e 0 quando liberado. A `CanvasSize` da
lista era calculada à mão com `#tools * 26 + 6`, número válido só para a
altura de linha daquele momento; virou `AutomaticCanvasSize`.

Os dois passam a dividir `criarModal()`: fundo em fade, mola amortecida na
entrada e na saída, fechar por botão, por toque no fundo e por ESC.

O arquivo continua com **um único** `TweenService:Create`, dentro do
gerenciador, e agora com 11 `UIAspectRatioConstraint`.

## 2026-09-02 19:54 UTC — animação nos dois menus

`[PUBLICAÇÃO] 2 atualizados, 0 renomeados, 0 criados, 0 pastas criadas`
Retorno: `["published", 58, 56, 2, 0, 0, 0]` — execução #22, `main` em `f16ea09`

O dono perguntou onde estavam as animações dinâmicas. A resposta honesta é que
no menu unificado não havia nenhuma que ele conseguisse ver, e as do menu de
personagens estavam em branch não mesclada.

**`CharacterSystemClient` V11 → V12** (merge da branch `codex/redesign-character-menus`).
Contexto dono das conexões e dos tweens, abrir/fechar por mola amortecida no
Heartbeat, `UIAspectRatioConstraint` de 1 para 8. O arquivo tinha 4 tweens e
nenhum `:Cancel()`. A busca, as seções por raridade e a grade responsiva do
V11 continuam inteiras.

**`UnifiedMenuClient` V3 → V4.** Este era o pior caso do repositório, e o
motivo de o dono não ver nada:

- Dos 5 tweens, **2 eram `MouseEnter`/`MouseLeave`**, que não disparam em
  toque. No celular dele nunca rodaram.
- **2 viviam num `while ... task.wait(1.5)`** pulsando a borda do botão ☰,
  criando tween novo a cada volta pela sessão inteira.
- O hub abria e fechava com `Visible = true/false` **em seis pontos
  diferentes do arquivo** — que é justamente por que nunca ganhou transição:
  animar exigiria repetir o efeito seis vezes.

Agora: `abrirHub()`/`fecharHub()` como caminho único com a mesma mola do V12,
cards entrando escalonados pelo `DelayTime` do `TweenInfo` (sem `task.spawn`,
sem thread por card), `InputBegan`/`InputEnded` cobrindo toque e mouse pelo
mesmo caminho, `UIAspectRatioConstraint` nos cards e no ponto de notificação,
e a grade reconstruída ao girar o celular.

Os dois menus passam a usar o mesmo idioma de animação, então quem mexer num
reconhece o outro.

| | Unified | CharSys |
| --- | --- | --- |
| `TweenService:Create` | 5 → 1 | 4 → 1 |
| `:Cancel()` | 0 → 2 | 0 → 2 |
| laços `while` | 1 → 0 | 4 → 2 |
| `UIAspectRatioConstraint` | 0 → 4 | 1 → 8 |

> Armadilha que quase passou: no card, a entrada e o toque animam o `Scale` do
> **mesmo** `UIScale`. Com chaves de tween diferentes eles não se cancelariam e
> brigariam pela propriedade se o jogador tocasse antes de a entrada terminar.
> Compartilham a chave `"escala"..i` de propósito.

## 2026-09-02 15:45 UTC — arquibancada de duelo acessível

`[PUBLICAÇÃO] 5 atualizados, 0 renomeados, 0 criados, 0 pastas criadas`
Retorno: `["published", 58, 53, 5, 0, 0, 0]` — execução #20, `main` em `c8735b7`

Merge da branch `codex/review-claude-upgrades` do Codex. O `verificar` da
execução #19, no mesmo commit, saiu `58 scripts; 53 iguais; 5 diferentes;
0 renomeados; 0 novos; 0 problemas` — os cinco diferentes são exatamente os
cinco arquivos do merge, nenhuma cópia duplicada.

**`DuelMenuClient`** — o botão de assistir duelo que faltava. `DuelSystemServer`
V3 expunha `DuelSpectate` desde a publicação de 01/09 e nenhum cliente chamava:
a arquibancada de 48 assentos existia no jogo e ninguém conseguia subir nela.
Agora o menu mostra `👁 ASSISTIR A VS B [n/24]` quando há luta, ou "ARENA LIVRE"
quando não há, e durante a partida um overlay traz placar, fase e lotação com
botão de sair.

**`DuelSystemServer`** — guarda-corpo nos quatro lados da arquibancada, que fica
a 2000 studs de altura e não tinha nada segurando quem escorregasse. Remotes
`GetDuelArenaStatus` e `DuelSpectatorState`, e tratamento de espectador que
morre ou desconecta no meio do duelo.

**`LoadingScreen`** — a lista de classes com conteúdo passou de 15 para 21
(entrou `MaterialVariant`, `SurfaceAppearance`, `WrapLayer`, `VideoFrame`,
`AudioPlayer`, `CharacterMesh`), cada lote falho é repetido uma vez, e a
varredura se repete para pegar o que o servidor insere durante o boot.

**`LoadingScreenServer`** — para de esperar dados de quem já saiu do jogo e
escreve "USE PULAR" na tela quando o servidor de dados não responde em 30s.

**`SpawnSystem`** — a plataforma de spawn criava um tween infinito por segundo
dentro de um `while`, acumulando animação na mesma peça pela sessão inteira.
Virou uma chamada de `pulsar()`. Defeito que passou batido na revisão do V9.

> **Mudança de comportamento:** o Codex removeu o `MAX_WAIT` de 120 s da tela de
> carregamento. O argumento dele é que teto artificial vira sucesso falso — o
> preload só termina quando os assets replicados retornam `Success`. Na prática,
> se o preload travar não existe mais saída automática: a única é o jogador
> tocar em **PULAR**, que aparece aos 5 s. Publicado com o dono ciente disso.

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
