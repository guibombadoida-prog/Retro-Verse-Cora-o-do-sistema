# central/ — aguardando instalação no Studio

**O que está nesta pasta ainda NÃO está rodando no jogo.**

É a sua lista de pendências: script entregue, revisado, mas que ainda precisa
ser colado no Roblox Studio.

## A regra que isto garante

**`src/` espelha o que está rodando no Studio agora. `central/` é o que falta subir.**

`central/` vazia (só este arquivo) = repositório e Studio em sincronia, nada pendente.

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

Nenhum arquivo existe nos dois lugares ao mesmo tempo — é isso que mata a
duplicação. Cada versão está em `central/` **ou** em `src/`, nunca nos dois.

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

⚠️ **Rode o `promover.sh` só DEPOIS de colar no Studio.** Antes disso o `src/`
estaria mentindo sobre o que está no ar.

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
