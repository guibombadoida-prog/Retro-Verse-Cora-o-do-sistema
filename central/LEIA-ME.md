# central/ — área de trânsito

Esta pasta é **passagem, não depósito**. O normal é ela estar vazia.

## Para que serve

Uma versão nova de script chega aqui, é promovida para a pasta ativa em `src/`, e
a pasta volta a ficar vazia. Nada mora aqui permanentemente.

```
        versão nova chega
               ↓
          central/  ←──── área de trânsito (esta pasta)
               ↓  tools/promover.sh
   src/<local do Studio>/  ←── pasta específica: a versão ATIVA
               ↓
      versão antiga é APAGADA
   (fica no histórico do Git, recuperável)
```

## A regra que isto garante

**Existe exatamente uma versão de cada script no repositório: a atual.**

Sem cópia de segurança em pasta paralela, sem `_V6` ao lado de `_V8`, sem dúvida
sobre qual arquivo é o que está no jogo. O que está em `src/` é o que está valendo.

O histórico faz o papel de arquivo morto — é para isso que ele existe:

```bash
# ver como o DataManager era antes
git log --oneline -- src/ServerScriptService/DataManager.server.lua

# recuperar uma versão apagada
git show <commit>:src/ServerScriptService/DataManager.server.lua > recuperado.lua
```

## Como usar

```bash
# 1. coloque a versão nova aqui, com a versão no nome
#    central/SpawnSystem_V9.server.lua

# 2. promova
tools/promover.sh SpawnSystem_V9.server.lua

# ou promova tudo que estiver aqui de uma vez
tools/promover.sh --todos

# 3. confira
tools/validar.sh
```

O `promover.sh` **não adivinha** o destino: ele lê `-- Nome:` e `-- Coloque em ...`
do cabeçalho do próprio script. Se o cabeçalho estiver no padrão do projeto, o
arquivo vai para o lugar certo sozinho.

## Nome do arquivo aqui

Use `NomeDoScript_V<n>` + o sufixo de classe:

| Classe no Studio | Sufixo |
|---|---|
| `Script` | `.server.lua` |
| `LocalScript` | `.client.lua` |
| `ModuleScript` | `.lua` |

Exemplos: `SpawnSystem_V9.server.lua` · `HealthDisplay_V5.client.lua` ·
`PassiveCatalog_V2.lua`

O `_V<n>` existe só aqui, para você saber o que está promovendo. Ao entrar em
`src/` o arquivo assume o nome do objeto no Studio, sem versão — porque é aquele
nome que o Studio precisa ver.
