# Console de comandos do RetroVerse

Sistema de comandos de admin próprio do jogo. Formato inspirado no Adonis
(ver [`ADONIS.md`](ADONIS.md)), comandos e código do RetroVerse.

| Peça | Papel |
| --- | --- |
| `src/ServerScriptService/RetroCommands.lua` | A tabela de comandos e o dispatcher. Não fala com o Roblox. |
| `src/ServerScriptService/AdminSystemServer.server.lua` (V9) | Monta o contexto, resolve o nível e entrega o resultado na tela. |
| `src/StarterPlayer/StarterPlayerScripts/AdminMenuClient.client.lua` (V13) | Aba **CONSOLE**: lista e linha de comando. |
| `tests/RetroCommands.spec.luau` | 876 verificações, ligadas no CI. |

---

## Os quatro defeitos que motivaram isto

O V8 tinha os comandos numa cadeia de `elseif`. Os problemas não eram de
estilo:

1. **Silêncio.** `Players:FindFirstChild(args[2])` devolvendo `nil` caía no fim
   do `if` e **nada acontecia** — nem erro, nem aviso. O admin não tinha como
   distinguir "errei o nome", "o jogador saiu" e "esse comando não existe".
2. **Nome exato obrigatório.** Sem `me`, `all`, `others` nem prefixo parcial. O
   dono joga no **celular**: digitar o username inteiro, com a capitalização
   certa, é a diferença entre o comando existir e não existir.
3. **`;help` imprimia no console (F9).** No celular não há F9. A lista de
   comandos era invisível justamente para quem mais precisava dela.
4. **Comando era código, não dado.** O painel não tinha como listar o que
   existe, então a lista vivia duplicada à mão nos dois lados e desencontrava a
   cada comando novo.

---

## O contrato que mata o silêncio

**Todo caminho do dispatcher devolve mensagem.** Comando inexistente, nível
insuficiente, argumento errado, alvo não encontrado, alvo ambíguo, API fora do
ar e erro de runtime — todos viram texto na tela do admin.

Isso não é promessa de comentário: `tests/RetroCommands.spec.luau` roda **todos
os 34 comandos** sem argumento nenhum, e depois todos com um alvo inexistente,
cobrando mensagem não vazia em cada um. Um comando novo que fique calado
reprova o CI.

## Alvos

| Escreve | Pega |
| --- | --- |
| `me` / `eu` | você |
| `all` / `todos` | todos no servidor |
| `others` / `outros` | todos menos você |
| `Maria` | quem se chama Maria |
| `mar` | quem começa com "mar", **se for só um** |

Prefixo que casa com **dois ou mais** jogadores é **recusado**, com a lista de
quem casou — não escolhe por conta própria. Escolher errado num `;kill` ou num
`;reset` é pior do que não fazer nada. Nome exato ganha do prefixo: com "Gui" e
"GuiBomba" no servidor, `Gui` acerta o "Gui".

## Níveis

| Nível | Quem é |
| --- | --- |
| `JOGADOR` (0) | todo mundo — só alcança `;cmds` |
| `MODERADOR` (100) | reservado para rank futuro |
| `ADMIN` (200) | reservado para rank futuro |
| `CHEFE` (300) | **admin do `_G.AdminRegistry`** |
| `DONO` (900) | o `OWNER_ID` |

O mapeamento é conservador para **não rebaixar quem já era admin**: com CHEFE,
todo comando que um admin tinha no V8 continua na mão dele.

> **Mudança de comportamento, uma só:** `;reset` subiu para **DONO**. Ele apaga
> os dados do jogador e não tem desfazer, e "qualquer admin apaga qualquer
> conta" é poder demais para um atalho de chat. `;addadmin` e `;deladmin`
> ficaram em CHEFE de propósito, por paridade com o V8 e com a aba ADMINS do
> painel — deixar o chat mais restrito que o painel seria incoerência que
> confunde sem proteger nada.

`MODERADOR` e `ADMIN` existem na escala mas ninguém cai neles hoje: o
`_G.AdminRegistry` é uma lista plana. Quando ele ganhar ranks, é só mudar
`nivelDe` no `AdminSystemServer` — os comandos já estão etiquetados.

---

## A aba CONSOLE

A lista de comandos **não está escrita no client**. Ela é pedida ao servidor
(`AdminListCommands`), que a devolve da **mesma tabela que executa**, já
filtrada pelo seu nível. Daí o "100% conectado": não há como o painel mostrar
comando que não existe, esconder comando novo, ou oferecer botão que o servidor
vai recusar.

Tocar num comando da lista preenche a linha com o nome dele, para o admin editar
em cima em vez de digitar tudo no celular. O resultado de cada execução aparece
na tela.

Detalhes que vieram das armadilhas do projeto:

- **Nada preso a `MouseEnter`/`MouseLeave`** — não existem no toque.
- **Régua das abas derivada de `#tabNames`.** Com os `0.155`/`0.165` fixos do
  V9, a sétima aba passava de `1.0` (7 × 0.165 = 1.155) e saía do painel. Quem
  adicionar a oitava não precisa lembrar de recalcular.
- **Teto de 40 linhas na saída**, com `.Parent = nil`. Sem isso uma sessão longa
  deixa milhares de `TextLabel` vivos no `ScrollingFrame`.
- **Os remotes do console são opcionais no client.** Se o servidor ainda estiver
  no V8, o painel abre, as outras seis abas funcionam, e a aba CONSOLE explica
  na tela o que falta — em vez de morrer num `WaitForChild` sem fim e levar o
  painel inteiro.

O remote `AdminRunCommand` é público, como qualquer remote. O nível é conferido
**no servidor** pelo dispatcher, e há um freio de 0,25 s por jogador para que a
recusa barata não vire laço de log.

---

## Comandos

34 no total. `;cmds` lista o que o seu nível alcança.

| Categoria | Comandos |
| --- | --- |
| ECONOMIA | `coins` `bounty` |
| PERSONAGEM | `char` `unchar` `allchars` `catalogo` |
| COMBATE | `kill` `heal` `escudo` `stats` `dano` `efeito` `limpaefeito` `efeitos` `energia` |
| DESPERTAR | `desperto` `despertares` |
| PROGRESSO | `xp` `reset` `tutorial` `conquistas` |
| PASSIVA | `passivas` `repassiva` |
| MUNDO | `tp` `tpme` `zonasegura` `espectador` `time` `procurado` `recarregaspawn` |
| ADMIN | `addadmin` `deladmin` `admins` `cmds` |

Os 10 comandos do V8 continuam com o mesmo nome e o mesmo efeito. Nada que você
já digitava parou de funcionar.

---

## Comando novo

`RetroCommands.registrar` é público — é o gancho de "plugin" do Adonis. Comando
registrado de fora entra no **mesmo** índice, então `;cmds` e o painel enxergam
na hora.

```lua
RetroCommands.registrar({
	nome = "exemplo",
	apelidos = { "ex" },
	argumentos = "<jogador> <quantia>",
	descricao = "Uma linha, aparece no painel.",
	categoria = "COMBATE",
	nivel = RetroCommands.NIVEIS.ADMIN,
	executar = function(ctx, argumentos)
		-- SEMPRE devolva ok, mensagem — nos dois casos.
		return true, "feito"
	end,
})
```

Regras que o teste cobra:

- Nome em minúscula, sem repetir nome nem apelido de outro comando.
- `nivel` da escala `RetroCommands.NIVEIS`.
- `categoria` em MAIÚSCULA.
- Se a descrição fala de "alvo", `argumentos` tem de declarar `<jogador>` —
  senão o painel mostra um campo a menos do que o comando exige.
- Nada destrutivo abaixo de `CHEFE`.

Peça API do jogo por `ctx.api.NomeDaApi`, nunca por `_G` direto: assim o
comando avisa "X não está carregado" em vez de estourar. E se usar uma API nova,
declare-a em `DEPENDENCIAS`, no `AdminSystemServer` — é aquela tabela que
mantém a checagem 3 do `tools/validar.sh` funcionando e alimenta o diagnóstico
de boot.

---

## Nota sobre backtick

`RetroCommands.lua` usa `string.format`, não interpolação com backtick, e isso é
regra da casa e não gosto: **o `luac` do Lua 5.4 usado na checagem 7 do
`tools/validar.sh` não parseia interpolação Luau.** Todo backtick que existe em
`src/` está dentro de comentário.

E vale registrar o que apareceu ao converter: `string.format("achei "%s" aqui",
x)` — com as aspas internas sem escape — **passa** pelo `luac`, porque em Lua
aquilo lê como `"achei " % s("aqui")`, que é sintaxe válida e erro em runtime. O
validador aprovou; quem pegou foi o teste. É um bom lembrete de que a checagem
de sintaxe não substitui teste.
