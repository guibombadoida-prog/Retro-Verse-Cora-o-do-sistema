# Desenvolver o RetroVerse sem PC Windows

O Roblox Studio não possui versão oficial para Android nem versão web. Como o
objetivo deste repositório é trabalhar somente com scripts, dá para substituir o
Studio por um fluxo de código:

1. editar no navegador do Android;
2. validar e montar o projeto em máquinas do GitHub;
3. executar testes dentro do motor Roblox pela Open Cloud;
4. preparar uma experience privada de teste somente com scripts, se necessário;
5. publicar **somente mudanças de `Source`** em scripts existentes da produção;
6. entrar no teste pelo aplicativo Roblox no Android para testar GUI e toque.

## Fluxo recomendado

1. Abra [`github.dev`](https://github.dev/guibombadoida-prog/Retro-Verse-Cora-o-do-sistema)
   no Chrome ou Firefox do Android.
2. Para mudanças somente de código, crie uma branch, altere os arquivos em `src/`,
   faça commit e abra um pull request. Use `central/` apenas quando a produção
   ainda exigir instalação estrutural pelo Studio.
3. O workflow **Validar código sem PC** verifica sintaxe, executa lógica pura e monta
   dois artifacts Rojo.
4. O workflow **Executar no Roblox sem Studio** testa um place descartável, somente
   de código, dentro do motor Roblox e mostra os `print()` nos logs.
5. Se a experience privada ainda não tiver os scripts, use **Preparar place privada
   de código** primeiro em modo `planejar` e depois `criar`.
6. O workflow **Publicar somente código** abre o place atual, compara os scripts e,
   com confirmação manual, cria uma versão jogável alterando somente `Source`.
7. Abra o place privado no aplicativo Roblox para Android.

Esses workflows manuais só aparecem na aba Actions depois que os arquivos estiverem
na branch padrão do repositório. Os três workflows que usam Roblox recusam qualquer
referência que não seja `main`.

## Proteção das chaves no GitHub

Crie dois Environments em **Settings → Environments**:

- `roblox-test` — chave de uma experience privada, separada da produção, com
  deploy permitido somente a partir de `main`;
- `roblox-production` — chave do jogo real, permitindo deploy somente de `main`
  e, quando possível, exigindo aprovação manual.

Guarde `ROBLOX_TEST_API_KEY` e `ROBLOX_PUBLISH_API_KEY` como secrets dos
respectivos Environments. Cadastre os quatro IDs como **Repository variables**,
pois o bootstrap de teste precisa enxergar também os IDs proibidos de produção.
O código faz as verificações de branch e IDs; o Environment acrescenta uma
segunda trava fora do Git.

## 1. Validação sem conta Roblox nem segredo

`.github/workflows/validate-code.yml` roda automaticamente em pull requests e em
pushes para `main`. Ele usa versões e hashes fixos das ferramentas:

- Luau CLI para analisar todos os `.lua` e `.luau`;
- Luau CLI para executar `tests/PassiveCatalog.spec.luau` fora do motor;
- Rojo para montar `default.project.json` em `build/RetroVerse.rbxl`;
- Rojo para montar `code-payload.project.json` em um `.rbxm` que contém só scripts;
- artifacts disponíveis por 7 dias na página da execução.

O `.rbxl` é deliberadamente um place sem mapa. Ele serve para o teste headless;
**não o publique sobre um place com cenário**, pois publicar um place inteiro
substituiria seu conteúdo.

## 2. Execução headless no motor Roblox

Use uma **experience privada separada**, criada somente para testes. Não use apenas
outra Place dentro da experience pública, porque DataStores são compartilhados
entre Places da mesma experience. Cadastre:

| Tipo | Nome | Valor |
|---|---|---|
| Repository variable | `ROBLOX_TEST_UNIVERSE_ID` | ID numérico da experiência de teste |
| Repository variable | `ROBLOX_TEST_PLACE_ID` | ID numérico do place de teste |
| Secret de `roblox-test` | `ROBLOX_TEST_API_KEY` | chave Open Cloud exclusiva para teste |

Crie a chave no Creator Dashboard, limite-a ao único place de teste e conceda
`universe-places:write` e `luau-execution-sessions:write`, conforme o `rocale-cli`
oficial. Prefira validade curta. Nunca coloque a chave em arquivo, commit, issue,
print de tela ou conversa.

Depois abra **Actions → Executar no Roblox sem Studio → Run workflow**, digite
`TESTE` e execute. A automação:

1. monta o projeto de código com Rojo;
2. carrega essa cópia isolada no ambiente Luau Execution;
3. executa `tasks/smoke.luau` no motor;
4. mostra nos logs quantos scripts e passivas foram carregados.

Esse teste não cria jogador nem renderiza GUI. Ele é útil para módulos, catálogos,
combate, validações e código de servidor.

## 3. Bootstrap de uma experience privada sem Studio

O workflow **Preparar place privada de código** resolve o primeiro uso: o publicador
normal só atualiza scripts que já existem, mas uma experience nova ainda não possui
a árvore do RetroVerse.

**Pré-requisito:** a experience privada e seu primeiro place já precisam existir.
A Open Cloud atual não expõe uma operação para criar uma nova Universe do zero; o
fluxo oficial ainda começa no Roblox Studio. Se você ainda não possui uma experience
de teste separada, continue usando validação e execução headless, sem chamar
`criar`, até conseguir fazer essa criação inicial uma única vez em Windows ou macOS
suportado. Não substitua esse requisito pela experience pública.

Ele usa o mesmo RBXM somente de scripts e aceita duas opções:

1. `planejar` — lista pastas, scripts novos e `Source` diferentes sem alterar nada;
2. `criar` — exige `CRIAR_SCRIPTS_TESTE`, cria apenas `Folder`, `Script`,
   `LocalScript` e `ModuleScript` nas raízes de código permitidas e salva uma versão.

Travas aplicadas pelo workflow e novamente dentro da tarefa Roblox:

- roda somente a partir de `main` e depois da validação completa do mesmo commit;
- exige que Universe ID de teste seja diferente do Universe ID de produção;
- recusa o Place ID de produção configurado e o Place ID público conhecido;
- não cria, altera ou remove nada em `Workspace`, `Lighting` ou outras áreas 3D;
- não apaga nem renomeia instâncias existentes;
- resolve todos os conflitos de caminho e classe antes da primeira escrita;
- reverte em memória as criações e os `Source` se a aplicação ou o save falhar.

Configure também `ROBLOX_PUBLISH_UNIVERSE_ID` e `ROBLOX_PUBLISH_PLACE_ID`, mesmo
antes da primeira publicação real: no bootstrap eles funcionam como lista de
produção **proibida**.

Depois de `planejar`, confira os caminhos nos logs. Só então rode `criar`, entre na
experience privada pelo aplicativo Android e teste. A primeira execução real ainda
é experimental e deve permanecer nesse ambiente isolado.

## 4. Publicar só código, preservando o mapa

Esta é a "gambiarra correta" para chegar ao Android. O Rojo monta um RBXM cujo
objeto raiz contém apenas a árvore de scripts. `tools/run_code_publish.py` envia
esse arquivo como entrada binária de uma tarefa Luau Execution. Dentro da cópia da
versão atual do place, `tasks/apply_code_payload.luau`:

- encontra cada script pelo caminho e pela classe;
- interrompe antes de escrever se algum objeto estiver ausente ou incompatível;
- não cria, apaga, move nem renomeia instâncias;
- altera somente propriedades `Source` diferentes;
- chama `AssetService:SavePlaceAsync({ SaveWithoutPublish = false })` apenas no modo
  de publicação e apenas quando houve mudança.

Como a tarefa começa no place atual e não remonta o DataModel, cenário, iluminação,
modelos, sons e demais propriedades são preservados.

### Preparar um place privado

Faça a primeira tentativa em uma cópia privada do jogo, nunca diretamente no place
público. No Creator Hub desse place:

1. abra **Permissions**;
2. habilite **Allow place to be updated using Save Place API**;
3. garanta que não exista uma sessão Team Create ativa durante a publicação.

Cadastre para o alvo de produção:

| Tipo | Nome | Valor |
|---|---|---|
| Repository variable | `ROBLOX_PUBLISH_UNIVERSE_ID` | ID numérico da experiência alvo |
| Repository variable | `ROBLOX_PUBLISH_PLACE_ID` | ID numérico do place alvo |
| Secret de `roblox-production` | `ROBLOX_PUBLISH_API_KEY` | chave separada para publicação |

Restrinja essa chave ao place privado e conceda somente
`luau-execution-sessions:write` e `universe-places:write`.

### Verificar e publicar

1. Abra **Actions → Publicar somente código → Run workflow** e selecione `main`.
2. Escolha `verificar`. A tarefa mostra `=` para código igual e `~` para diferente,
   mas não salva nada.
3. Confira o Place ID exibido na configuração da execução e os caminhos nos logs.
4. Rode novamente, escolha `publicar` e digite exatamente `PUBLICAR`.
5. Confirme no histórico de versões do Creator Dashboard que surgiu uma versão nova.
6. Entre no place privado usando o aplicativo Roblox no Android.

O workflow não reinicia servidores automaticamente. Se algo ficar errado, publique
uma versão anterior pelo histórico do place e corrija o código no Git.
Se a execução perder conexão depois de criar a tarefa, confira o histórico antes de
rodá-la novamente: a tarefa pode ter terminado mesmo sem o GitHub receber a resposta.

## O que cada opção testa

| Opção | Motor Roblox | Cliente Android | Preserva o 3D | Uso principal |
|---|---:|---:|---:|---|
| Luau CLI no Actions | Não | Não | Sim | sintaxe e lógica pura |
| Luau Execution headless | Sim | Não | usa cópia isolada | módulos e servidor |
| Bootstrap privado + app | Sim | Sim | place de teste sem 3D | primeira instalação dos scripts |
| Publicação de `Source` + app | Sim | Sim | Sim | GUI, toque e integração em scripts existentes |
| Winlator + Studio | incerto | incerto | — | experimento não suportado |

Winlator não é a base deste fluxo. O Studio depende de Windows/macOS, GPU, WebView
e atualizações frequentes, sem suporte oficial a Android/ARM. Mesmo que algum
instalador abra, isso tende a quebrar e ainda exige renderizar o editor 3D que não é
necessário para este projeto.

## Segurança e limites

- mantenha publicação e teste headless manuais;
- use chaves diferentes, limitadas a um place privado e com validade curta;
- use uma experience de teste separada para isolar DataStores da produção;
- nunca envie a chave a outra pessoa; GitHub Secrets já a oculta dos arquivos;
- restrinja `roblox-production` à branch `main` e aprove cada implantação;
- o publicador só atualiza scripts que **já existem** no place com mesmo caminho e
  mesma classe;
- o bootstrap cria scripts somente no alvo de teste e recusa os IDs de produção;
- `SavePlaceAsync` pode falhar se a permissão do place estiver desligada ou se Team
  Create estiver ativo;
- valide primeiro e consulte o histórico de versões depois de cada publicação;
- nenhum desses recursos substitui o Studio para construir cenário 3D.

## Referências oficiais

- [Instalação e sistemas suportados pelo Roblox Studio](https://create.roblox.com/docs/tutorials/curriculums/studio/install-studio)
- [Criação e gerenciamento de projetos Roblox](https://create.roblox.com/docs/projects)
- [Editor web github.dev](https://docs.github.com/en/codespaces/the-githubdev-web-based-editor)
- [Formato de projeto do Rojo](https://rojo.space/docs/v7/project-format/)
- [Luau Execution na Open Cloud](https://create.roblox.com/docs/cloud/reference/features/luau-execution)
- [`SavePlaceAsync` no `AssetService`](https://create.roblox.com/docs/reference/engine/classes/AssetService/SavePlaceAsync)
- [`rocale-cli` oficial da Roblox](https://github.com/Roblox/rocale-cli)
- [Exemplo oficial de entrada binária](https://github.com/Roblox/open-cloud-execution-binary-payloads-example)
