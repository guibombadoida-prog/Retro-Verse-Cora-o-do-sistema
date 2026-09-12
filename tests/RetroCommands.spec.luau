-- Testes do motor de comandos do RetroVerse.
--
-- O que estes testes protegem, em ordem de importância:
--
--   1. O CONTRATO DO SILÊNCIO. O defeito que motivou o módulo era comando
--      que não fazia nada e não dizia nada. Aqui TODO caminho do
--      dispatcher é exercido e cobrado uma mensagem não vazia: comando
--      inexistente, nível insuficiente, argumento errado, alvo não
--      encontrado, alvo ambíguo, API fora do ar e erro de runtime.
--   2. CASAMENTO DE ALVOS. `me`, `all`, `others`, prefixo parcial, e o
--      caso que importa de verdade: prefixo que casa com dois jogadores
--      tem de RECUSAR, não escolher. Escolher errado num ;kill ou num
--      ;reset é pior do que não fazer nada.
--   3. PERMISSÃO. Nível de cada comando é respeitado, e ninguém sobe de
--      nível por apelido.
--
-- Roda sem Roblox: o módulo recebe tudo por ctx, de propósito.

local R = require("../src/ServerScriptService/RetroCommands")

local checados = 0
local function conferir(valor, mensagem)
	assert(valor, mensagem)
	checados += 1
end

local N = R.NIVEIS

-- ============================================
-- Mundo falso
-- ============================================

local function jogador(nome)
	return { Name = nome }
end

local GUI = jogador("GuiBombado")
local GUIZAO = jogador("GuiZao")
local MARIA = jogador("Maria")
local TODOS = { GUI, GUIZAO, MARIA }

-- Registra o que as APIs receberam, para os testes cobrarem efeito e não
-- só a mensagem de volta.
local function mundo(nivel, jogadores)
	local diario = {}
	local function anotar(o)
		table.insert(diario, o)
	end
	local ctx
	ctx = {
		autor = GUI,
		nivel = nivel or N.DONO,
		jogadores = jogadores or TODOS,
		diario = diario,
		personagemDe = function(p)
			return { __personagem = p.Name }
		end,
		humanoideDe = function(p)
			return { Health = 100, __de = p.Name }
		end,
		raizDe = function(p)
			return { CFrame = `cframe-de-{p.Name}` }
		end,
		api = {
			PlayerDataManager = {
				updateCoins = function(p, q)
					anotar({ o = "coins", quem = p.Name, quanto = q })
				end,
				updateBounty = function(p, q)
					anotar({ o = "bounty", quem = p.Name, quanto = q })
				end,
				savePlayerData = function(p)
					anotar({ o = "save", quem = p.Name })
				end,
				addCharacterToInventory = function(p, c)
					anotar({ o = "char", quem = p.Name, char = c })
				end,
				removeCharacterByName = function(p, c)
					anotar({ o = "unchar", quem = p.Name, char = c })
					return c == "Gui Bomba"
				end,
				resetPlayerData = function(p)
					anotar({ o = "reset", quem = p.Name })
				end,
			},
			CharacterCatalog = {
				listAll = function()
					return { { name = "Gui Bomba" }, { name = "Retro Kid" } }
				end,
			},
			StatService = {
				getStat = function(_, chave)
					return chave == "damage" and 42 or nil
				end,
				getShield = function()
					return 7
				end,
				recompute = function(p, encher)
					anotar({ o = "heal", quem = p.Name, encher = encher })
				end,
				restoreShield = function(p, q)
					anotar({ o = "escudo", quem = p.Name, quanto = q })
				end,
			},
			StatusEffect = {
				CATALOGO = { queimadura = {}, lentidao = {} },
				aplicar = function(personagem, id, dur)
					anotar({ o = "efeito", em = personagem.__personagem, id = id, dur = dur })
				end,
				limparTodos = function(personagem)
					anotar({ o = "limpaefeito", em = personagem.__personagem })
				end,
			},
			AdminRegistry = {
				addAdmin = function()
					return true, "adicionado"
				end,
				removeAdmin = function()
					return false, "o dono é irremovível"
				end,
				listAll = function()
					return { { name = "GuiBombado", isOwner = true } }
				end,
			},
			SimulateDamage = function(a, v, q)
				anotar({ o = "dano", a = a, v = v, q = q })
			end,
			-- Um comando que estoura, para provar que o pcall do
			-- dispatcher isola e o listener de chat sobrevive.
			ExplodePropositalmente = function()
				error("boom")
			end,
		},
	}
	return ctx
end

local function rodar(texto, ctx)
	return R.executar(texto, ctx or mundo())
end

-- ============================================
-- 1. Parse
-- ============================================

conferir(R.parse("oi pessoal") == nil, "texto normal não é comando")
conferir(R.parse(":kill me") == nil, "prefixo do Adonis não é o nosso")
conferir(R.parse(";") == nil, "prefixo sozinho não é comando")
conferir(R.parse("") == nil, "vazio não é comando")
conferir(R.parse(nil) == nil, "nil não derruba o parse")

local p = R.parse("  ;COINS  GuiBombado   500  ")
conferir(p ~= nil and p.nome == "coins", "nome do comando vem em minúscula")
conferir(#p.argumentos == 2 and p.argumentos[1] == "GuiBombado", "argumento preserva capitalização")
conferir(p.argumentos[2] == "500", "espaço extra não cria argumento vazio")

local comEspaco = R.parse(";char Maria Gui Bomba")
conferir(R.juntar(comEspaco.argumentos, 2) == "Gui Bomba", "nome com espaço é remontado")
conferir(R.juntar(comEspaco.argumentos, 9) == "", "juntar além do fim devolve vazio")

-- ============================================
-- 2. Casamento de alvos
-- ============================================

local ctx = mundo()

local alvos = R.resolverAlvos("me", ctx)
conferir(alvos and #alvos == 1 and alvos[1] == GUI, "me é o autor")
conferir(R.resolverAlvos("eu", ctx)[1] == GUI, "eu funciona igual a me")

conferir(#R.resolverAlvos("all", ctx) == 3, "all pega todo mundo")
conferir(#R.resolverAlvos("todos", ctx) == 3, "todos funciona igual a all")

local outros = R.resolverAlvos("others", ctx)
conferir(#outros == 2, "others exclui o autor")
for _, o in outros do
	conferir(o ~= GUI, "autor não está em others")
end

conferir(R.resolverAlvos("maria", ctx)[1] == MARIA, "prefixo é case-insensitive")
conferir(R.resolverAlvos("mar", ctx)[1] == MARIA, "prefixo parcial resolve quando é único")

-- O caso que mais importa: "gui" casa com GuiBombado E GuiZao.
local ambiguo, erroAmbiguo = R.resolverAlvos("gui", ctx)
conferir(ambiguo == nil, "prefixo ambíguo RECUSA em vez de escolher")
conferir(
	string.find(erroAmbiguo, "GuiBombado") ~= nil and string.find(erroAmbiguo, "GuiZao") ~= nil,
	"erro de ambiguidade diz QUAIS jogadores casaram"
)

-- Nome exato vence a ambiguidade: existe alguém chamado exatamente assim.
local exato = { jogador("Gui"), jogador("GuiBomba") }
conferir(
	R.resolverAlvos("Gui", { jogadores = exato })[1].Name == "Gui",
	"nome exato vence o prefixo parcial"
)

local semNinguem, erroSem = R.resolverAlvos("Fulano", ctx)
conferir(semNinguem == nil and string.find(erroSem, "Fulano") ~= nil, "alvo inexistente diz o nome tentado")
conferir(select(2, R.resolverAlvos("", ctx)) ~= nil, "alvo vazio tem erro")
conferir(select(2, R.resolverAlvos(nil, ctx)) ~= nil, "alvo nil tem erro")
conferir(select(2, R.resolverAlvos("others", { autor = GUI, jogadores = { GUI } })) ~= nil, "others sozinho avisa")

-- ============================================
-- 3. O contrato do silêncio
-- ============================================

local inexistente = rodar(";naoexisteesse")
conferir(inexistente ~= nil and inexistente.ok == false, "comando inexistente é falha")
conferir(#inexistente.mensagem > 0, "comando inexistente TEM mensagem")
conferir(string.find(inexistente.mensagem, "cmds") ~= nil, "comando inexistente aponta o ;cmds")

conferir(rodar("oi") == nil, "texto normal devolve nil e o chat segue")

-- Todo comando, exercido sem argumento nenhum, com o nível máximo:
-- nenhum pode devolver mensagem vazia, e nenhum pode estourar.
for _, def in R.COMANDOS do
	local r = rodar(R.PREFIXO .. def.nome, mundo(N.DONO))
	conferir(r ~= nil, `{def.nome} devolveu nil`)
	conferir(type(r.mensagem) == "string" and #r.mensagem > 0, `{def.nome} sem mensagem`)
	conferir(r.erro ~= true, `{def.nome} estourou sem argumentos: {r.mensagem}`)
end

-- E com um alvo que não existe: também tem de falar.
for _, def in R.COMANDOS do
	if string.find(def.argumentos, "<jogador>") then
		local r = rodar(`{R.PREFIXO}{def.nome} Fulano 1`, mundo(N.DONO))
		conferir(r.ok == false, `{def.nome} deveria falhar com alvo inexistente`)
		conferir(#r.mensagem > 0, `{def.nome} silencioso com alvo inexistente`)
		conferir(r.erro ~= true, `{def.nome} estourou com alvo inexistente: {r.mensagem}`)
	end
end

-- Erro dentro de um comando é isolado pelo pcall: sem isso, um comando
-- com bug mataria o listener de chat e TODOS os comandos junto, até o
-- servidor reiniciar.
R.registrar({
	nome = "__teste_explode",
	nivel = N.JOGADOR,
	descricao = "só teste",
	executar = function()
		error("boom de propósito")
	end,
})
local estourado = R.executar(";__teste_explode", mundo())
conferir(estourado.ok == false, "comando que estoura é falha")
conferir(estourado.erro == true, "erro de runtime é marcado como erro")
conferir(string.find(estourado.mensagem, "boom") ~= nil, "mensagem de erro carrega a causa")
conferir(R.esquecer("__teste_explode"), "teste limpa o comando que registrou")
conferir(R.achar("__teste_explode") == nil, "comando esquecido sai do índice")

-- Comando MUDO: devolve ok/false sem mensagem. Nenhum comando real faz
-- isso hoje, e é justamente por isso que o teste precisa forçar — foi a
-- regressão que passou batida na primeira versão deste arquivo.
R.registrar({
	nome = "__teste_mudo_ok",
	nivel = N.JOGADOR,
	descricao = "só teste",
	executar = function()
		return true
	end,
})
R.registrar({
	nome = "__teste_mudo_falha",
	nivel = N.JOGADOR,
	descricao = "só teste",
	executar = function()
		return false
	end,
})
local mudoOk = R.executar(";__teste_mudo_ok", mundo())
conferir(mudoOk.ok == true, "comando mudo que deu certo continua ok")
conferir(type(mudoOk.mensagem) == "string" and #mudoOk.mensagem > 0, "sucesso sem mensagem ganha texto do dispatcher")
local mudoFalha = R.executar(";__teste_mudo_falha", mundo())
conferir(mudoFalha.ok == false, "comando mudo que falhou continua falha")
conferir(type(mudoFalha.mensagem) == "string" and #mudoFalha.mensagem > 0, "falha sem mensagem ganha texto do dispatcher")
R.esquecer("__teste_mudo_ok")
R.esquecer("__teste_mudo_falha")

-- Registro recusa nome repetido, para dois comandos não brigarem pela
-- mesma tecla em silêncio.
conferir(pcall(R.registrar, { nome = "coins", nivel = 0, executar = function() end }) == false, "nome duplicado é recusado")
conferir(pcall(R.registrar, { nome = "SEMMINUSCULA", nivel = 0, executar = function() end }) == false, "nome maiúsculo é recusado")
conferir(pcall(R.registrar, { nome = "__x", nivel = 0 }) == false, "comando sem executar é recusado")
conferir(pcall(R.registrar, { nome = "__x", executar = function() end }) == false, "comando sem nivel é recusado")
conferir(R.achar("__x") == nil, "comando recusado não fica no índice")

-- API ausente não estoura: avisa qual falta.
local semApi = mundo(N.DONO)
semApi.api = {}
local r = R.executar(";coins me 10", semApi)
conferir(r.ok == false, "sem API o comando falha")
conferir(string.find(r.mensagem, "PlayerDataManager") ~= nil, "erro nomeia a API que falta")
conferir(r.erro ~= true, "API ausente é falha tratada, não erro de runtime")

-- Argumento errado é dito com clareza.
local naoNumero = R.executar(";coins me abc", mundo())
conferir(naoNumero.ok == false and string.find(naoNumero.mensagem, "número") ~= nil, "quantia não numérica é explicada")

-- ============================================
-- 4. Permissão
-- ============================================

local moderador = mundo(N.MODERADOR)
local negado = R.executar(";reset me", moderador)
conferir(negado.ok == false and negado.negado == true, "moderador não reseta dados")
conferir(string.find(negado.mensagem, "DONO") ~= nil, "recusa diz o nível necessário")

conferir(R.executar(";kill me", moderador).ok ~= nil, "moderador alcança ;kill")
conferir(R.executar(";coins me 1", moderador).negado == true, ";coins exige ADMIN")

-- Apelido não é porta dos fundos para um nível maior.
for _, def in R.COMANDOS do
	for _, apelido in def.apelidos or {} do
		local achado = R.achar(apelido)
		conferir(achado ~= nil and achado.nivel == def.nivel, `apelido {apelido} muda o nível`)
	end
end

-- listarPara nunca entrega comando acima do nível.
for _, nivel in { N.JOGADOR, N.MODERADOR, N.ADMIN, N.CHEFE, N.DONO } do
	local lista = R.listarPara(nivel)
	for _, def in lista do
		conferir(def.nivel <= nivel, `listarPara({nivel}) vazou {def.nome}`)
		conferir(def.executar == nil, "listarPara não manda função pelo remote")
		conferir(type(def.descricao) == "string" and #def.descricao > 0, `{def.nome} sem descrição`)
		conferir(type(def.nivelNome) == "string", `{def.nome} sem nome de nível`)
	end
end
conferir(#R.listarPara(N.DONO) > #R.listarPara(N.MODERADOR), "dono vê mais que moderador")
conferir(#R.listarPara(N.JOGADOR) >= 1, "jogador comum ainda tem ;cmds")
conferir(#R.categorias(N.DONO) >= 5, "dono vê várias categorias")

-- ============================================
-- 5. Efeito de verdade
-- ============================================

local c = mundo()
R.executar(";coins Maria 500", c)
conferir(c.diario[1].o == "coins" and c.diario[1].quem == "Maria" and c.diario[1].quanto == 500, "coins chega na API")
conferir(c.diario[2].o == "save", "coins salva depois de dar")

c = mundo()
R.executar(";coins all 10", c)
local deuCoins = 0
for _, e in c.diario do
	if e.o == "coins" then
		deuCoins += 1
	end
end
conferir(deuCoins == 3, "all aplica nos três")

c = mundo()
R.executar(";coins me -50", c)
conferir(c.diario[1].quanto == -50, "quantia negativa passa (tirar moedas)")

c = mundo()
local rChar = R.executar(";char Maria Gui Bomba", c)
conferir(rChar.ok and c.diario[1].char == "Gui Bomba", "personagem com espaço chega inteiro")

c = mundo()
local rUnchar = R.executar(";unchar Maria Nao Tenho", c)
conferir(rUnchar.ok == false and string.find(rUnchar.mensagem, "não tem") ~= nil, "remover o que não tem avisa")

c = mundo()
local rAll = R.executar(";allchars Maria", c)
conferir(rAll.ok and string.find(rAll.mensagem, "2") ~= nil, "allchars usa o catálogo dinâmico")

local vazio = mundo()
vazio.api.CharacterCatalog.listAll = function()
	return {}
end
local rVazio = R.executar(";allchars Maria", vazio)
conferir(rVazio.ok == false and string.find(rVazio.mensagem, "vazio") ~= nil, "catálogo vazio avisa em vez de fingir")

c = mundo()
conferir(R.executar(";heal me", c).ok and c.diario[1].encher == true, "heal recalcula enchendo a vida")

c = mundo()
local rEfeito = R.executar(";efeito Maria queimadura 8", c)
conferir(rEfeito.ok and c.diario[1].id == "queimadura" and c.diario[1].dur == 8, "efeito aplica com duração")
local rEfeitoRuim = R.executar(";efeito Maria naoexiste", mundo())
conferir(rEfeitoRuim.ok == false and string.find(rEfeitoRuim.mensagem, "não existe") ~= nil, "efeito inválido é recusado antes de aplicar")

c = mundo()
conferir(R.executar(";dano Maria GuiZao 30", c).ok and c.diario[1].q == 30, "dano simulado chega ao núcleo")
conferir(R.executar(";dano Fulano GuiZao 30", mundo()).ok == false, "dano com atacante inexistente falha")

local rStats = R.executar(";stats me", mundo())
conferir(rStats.ok and string.find(rStats.mensagem, "damage=42") ~= nil, "stats mostra o que existe")
conferir(string.find(rStats.mensagem, "escudo=7") ~= nil, "stats mostra o escudo")

local rTpEuMesmo = R.executar(";tp me", mundo())
conferir(rTpEuMesmo.ok == false, "trazer a si mesmo é recusado com explicação")

local rAdmins = R.executar(";admins", mundo())
conferir(rAdmins.ok and string.find(rAdmins.mensagem, "DONO") ~= nil, "admins marca o dono")

local rDel = R.executar(";deladmin 123", mundo())
conferir(rDel.ok == false and string.find(rDel.mensagem, "irremovível") ~= nil, "a recusa do registry é repassada")

local rCmds = R.executar(";cmds", mundo(N.MODERADOR))
conferir(rCmds.ok and string.find(rCmds.mensagem, "CONSOLE") ~= nil, ";cmds manda para o painel, não para o F9")

-- ============================================
-- 6. Integridade do catálogo
-- ============================================

local nomesVistos = {}
for _, def in R.COMANDOS do
	conferir(type(def.nome) == "string" and def.nome == string.lower(def.nome), `{def.nome} não está em minúscula`)
	conferir(nomesVistos[def.nome] == nil, `nome repetido: {def.nome}`)
	nomesVistos[def.nome] = true
	conferir(R.NOME_DO_NIVEL[def.nivel] ~= nil, `{def.nome} usa nível fora da escala`)
	conferir(type(def.categoria) == "string" and def.categoria == string.upper(def.categoria), `{def.nome} categoria fora do padrão`)
	-- Comando que recebe jogador tem de declarar isso na ajuda, senão o
	-- painel mostra um campo a menos do que o comando exige.
	local usaAlvo = string.find(def.descricao, "alvo") ~= nil
	if usaAlvo then
		conferir(string.find(def.argumentos, "<jogador>") ~= nil, `{def.nome} fala de alvo mas não declara <jogador>`)
	end
end

-- Nada destrutivo pode ficar abaixo de ADMIN.
local DESTRUTIVOS = { reset = true, unchar = true, addadmin = true, deladmin = true }
for _, def in R.COMANDOS do
	if DESTRUTIVOS[def.nome] then
		conferir(def.nivel >= N.CHEFE, `{def.nome} é destrutivo e está abaixo de CHEFE`)
	end
end
conferir(R.achar("reset").nivel == N.DONO, ";reset é só do dono")

print(`RetroCommands: {checados} verificações passaram ({#R.COMANDOS} comandos)`)
