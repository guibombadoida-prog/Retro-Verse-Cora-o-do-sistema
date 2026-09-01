# central/ — aguardando instalação manual no Studio

**O que está nesta pasta ainda NÃO está rodando no jogo.**

É a lista de mudanças **estruturais** que ainda precisam ser instaladas no
Roblox Studio: script novo na produção, mudança de classe/local ou qualquer
alteração que o publicador seguro de `Source` não possa fazer.

## O que esta pasta garante

Mudanças somente no conteúdo de scripts existentes são feitas diretamente em
`src/` e publicadas pelo workflow Open Cloud. Elas não passam por esta pasta.

`central/` vazia (só este arquivo) significa: **nenhuma instalação manual
pendente**. Para saber se o `Source` de `src/` já está no ar, rode o modo
`verificar` do workflow **Publicar somente código**.

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

Em `src/` existe uma única versão ativa de cada sistema. O arquivo versionado em
`central/` representa a próxima instalação manual; depois de promovido, ele
substitui o arquivo ativo e sai daqui.

## Seu ciclo de trabalho

```bash
# 1. veja o que está pendente
tools/validar.sh
#    → AGUARDA INSTALAÇÃO NO STUDIO: AwakeningSystemServer_V3.server.lua
#      (substitui V2 que está no ar)

# 2. cole o script no Studio, no local e nome que o cabeçalho manda,
#    apagando a versão anterior

# 3. confirme que instalou
tools/promover.sh AwakeningSystemServer_V3.server.lua

# 4. comite
git add -A && git commit -m "AwakeningSystemServer V2 -> V3 instalado"
```

⚠️ **Rode o `promover.sh` só DEPOIS de colar no Studio.** Antes disso o
repositório perderia o registro da instalação manual pendente.

## Cabeçalho de entrega

Toda alteração vem acompanhada de:

```
## Scripts Entregues — [Sistema]
Scripts Novos:        [Nome_V1] — o que faz
Scripts Modificados:  [Nome_V1] → [Nome_V2] — o que mudou
Scripts Substituídos: ⚠️ REMOVER [Nome_V1]
```

Se um script aparecer aqui sem esse cabeçalho no chat, cobre.

## Nome do arquivo aqui

`NomeDoScript_V<n>` + o sufixo de classe:

| Classe no Studio | Sufixo |
|---|---|
| `Script` | `.server.lua` |
| `LocalScript` | `.client.lua` |
| `ModuleScript` | `.lua` |

Exemplos: `AwakeningSystemServer_V3.server.lua` · `HealthDisplay_V5.client.lua` ·
`PassiveCatalog_V2.lua`

O `_V<n>` existe só aqui, para você saber o que está instalando. Ao entrar em
`src/` o arquivo assume o nome do objeto no Studio, sem versão — porque é aquele
nome que o Studio precisa ver.

O `promover.sh` não adivinha o destino: lê `-- Nome:` e `-- Coloque em ...` do
cabeçalho do próprio script.

## Recuperar uma versão anterior

Apagar não perde nada:

```bash
git log --oneline -- src/ServerScriptService/AwakeningSystemServer.server.lua
git show <commit>:src/ServerScriptService/AwakeningSystemServer.server.lua > antiga.lua
```
