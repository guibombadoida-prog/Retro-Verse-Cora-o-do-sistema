-- Nome: RetroCommands
-- Coloque em: ServerScriptService
-- V1 — motor de comandos do RetroVerse: tabela de comandos, níveis e alvos
--
-- ============================================
-- POR QUE ESTE MÓDULO EXISTE
-- ============================================
-- O AdminSystemServer V8 tinha os comandos numa cadeia de `elseif` com
-- quatro defeitos reais, não estéticos:
--
--   1. SILÊNCIO. `Players:FindFirstChild(args[2])` devolvendo nil caía no
--      fim do `if` e NADA acontecia — nem erro, nem aviso. O admin não
--      tinha como saber se errou o nome, se o jogador saiu, ou se o
--      comando não existe. Era o pior defeito: um comando que não faz
--      nada e não diz nada.
--   2. NOME EXATO OBRIGATÓRIO. Sem `me`, sem `all`, sem prefixo parcial.
--      O dono joga no CELULAR — digitar "xXGuiBombadoXx" inteiro, com a
--      capitalização certa, é a diferença entre o comando existir e não
--      existir.
--   3. `;help` IMPRIMIA NO CONSOLE (F9). No celular não há F9. A lista de
--      comandos era invisível para quem mais precisava dela.
--   4. COMANDO ERA CÓDIGO, não dado. O painel client não tinha como
--      listar o que existe, então a lista vivia duplicada à mão em dois
--      arquivos e desencontrava a cada comando novo.
--
-- A ideia da tabela de comandos vem do Adonis (ver docs/ADONIS.md). O que
-- foi aproveitado é o FORMATO — comando como dado, com nível, argumentos
-- e descrição — não o código dele. Os comandos aqui são do RetroVerse e
-- falam com os sistemas do jogo pelas APIs `_G`.
--
-- ============================================
-- TESTÁVEL FORA DO ROBLOX, DE PROPÓSITO
-- ============================================
-- Nada aqui chama `game:GetService` nem toca em `_G` no momento do
-- require. Tudo entra por um `ctx` (contexto) que o AdminSystemServer
-- monta. Assim `tests/RetroCommands.spec.luau` roda o parser, o
-- casamento de alvos e as permissões num Luau puro — que é justamente
-- onde moram os defeitos 1 e 2 acima.
-- ============================================

local RetroCommands = {}

RetroCommands.VERSAO = "V1"
RetroCommands.PREFIXO = ";"

-- Níveis no mesmo espírito do Adonis: número, para dar ordem, com folga
-- entre eles para caber rank novo no meio sem renumerar nada.
RetroCommands.NIVEIS = {
	JOGADOR = 0,
	MODERADOR = 100,
	ADMIN = 200,
	CHEFE = 300,
	DONO = 900,
}

RetroCommands.NOME_DO_NIVEL = {
	[0] = "JOGADOR",
	[100] = "MODERADOR",
	[200] = "ADMIN",
	[300] = "CHEFE",
	[900] = "DONO",
}

local N = RetroCommands.NIVEIS

-- ============================================
-- PARSE
-- ============================================

-- Corta a mensagem em comando + argumentos. Não faz lowercase no resto:
-- nome de personagem preserva capitalização ("Gui Bomba"), que era um
-- cuidado do V5 e continua valendo.
function RetroCommands.parse(mensagem)
	if type(mensagem) ~= "string" then
		return nil
	end
	local texto = string.match(mensagem, "^%s*(.-)%s*$")
	if texto == "" then
		return nil
	end
	if string.sub(texto, 1, #RetroCommands.PREFIXO) ~= RetroCommands.PREFIXO then
		return nil
	end

	local partes = {}
	for pedaco in string.gmatch(texto, "%S+") do
		table.insert(partes, pedaco)
	end
	if #partes == 0 then
		return nil
	end

	local nome = string.lower(string.sub(partes[1], #RetroCommands.PREFIXO + 1))
	if nome == "" then
		return nil
	end

	local argumentos = {}
	for i = 2, #partes do
		table.insert(argumentos, partes[i])
	end

	return { nome = nome, argumentos = argumentos }
end

-- ============================================
-- ALVOS
-- ============================================
-- `ctx.jogadores` é uma lista de objetos com `.Name` — em produção vem de
-- Players:GetPlayers(), no teste vem de uma tabela. `ctx.autor` é quem
-- digitou.
--
-- Aceita: me / eu, all / todos, others / outros, e prefixo parcial
-- case-insensitive. O prefixo parcial só resolve quando casa com UM
-- jogador; com dois ou mais devolve erro dizendo quais, em vez de
-- escolher por conta própria (escolher errado num `;kill` é pior do que
-- não fazer nada).
function RetroCommands.resolverAlvos(texto, ctx)
	local jogadores = ctx.jogadores or {}
	local autor = ctx.autor

	if texto == nil or texto == "" then
		return nil, "falta dizer o jogador"
	end

	local chave = string.lower(texto)

	if chave == "me" or chave == "eu" then
		if not autor then
			return nil, "não há quem seja 'me' aqui"
		end
		return { autor }
	end

	if chave == "all" or chave == "todos" then
		if #jogadores == 0 then
			return nil, "não há ninguém no servidor"
		end
		local todos = {}
		for _, j in jogadores do
			table.insert(todos, j)
		end
		return todos
	end

	if chave == "others" or chave == "outros" then
		local outros = {}
		for _, j in jogadores do
			if j ~= autor then
				table.insert(outros, j)
			end
		end
		if #outros == 0 then
			return nil, "não há mais ninguém além de você"
		end
		return outros
	end

	-- Nome exato primeiro: se alguém se chama "Gui" e outro "GuiBomba",
	-- digitar "Gui" tem de acertar o "Gui", não dar ambiguidade.
	for _, j in jogadores do
		if string.lower(j.Name) == chave then
			return { j }
		end
	end

	local achados = {}
	for _, j in jogadores do
		if string.sub(string.lower(j.Name), 1, #chave) == chave then
			table.insert(achados, j)
		end
	end

	if #achados == 1 then
		return achados
	end

	if #achados == 0 then
		return nil, string.format("ninguém chamado \"%s\" no servidor", tostring(texto))
	end

	local nomes = {}
	for _, j in achados do
		table.insert(nomes, j.Name)
	end
	return nil, string.format("\"%s\" casa com %s: %s — escreva mais letras", tostring(texto), tostring(#achados), tostring(table.concat(nomes, ", ")))
end

-- ============================================
-- ARGUMENTOS
-- ============================================

function RetroCommands.numero(texto, rotulo)
	local valor = tonumber(texto)
	if valor == nil then
		return nil, string.format("%s precisa ser número, veio \"%s\"", tostring(rotulo or "valor"), tostring(tostring(texto)))
	end
	return valor
end

local LIGADO = { ["on"] = true, ["sim"] = true, ["true"] = true, ["1"] = true, ["ligar"] = true }
local DESLIGADO = { ["off"] = true, ["nao"] = true, ["não"] = true, ["false"] = true, ["0"] = true, ["desligar"] = true }

function RetroCommands.booleano(texto, rotulo)
	local chave = string.lower(tostring(texto))
	if LIGADO[chave] then
		return true
	end
	if DESLIGADO[chave] then
		return false
	end
	return nil, string.format("%s precisa ser on/off, veio \"%s\"", tostring(rotulo or "valor"), tostring(tostring(texto)))
end

-- Junta os argumentos a partir de `de` numa string só, preservando a
-- capitalização. É o que faz `;char fulano Gui Bomba` funcionar.
function RetroCommands.juntar(argumentos, de)
	if #argumentos < de then
		return ""
	end
	return table.concat(argumentos, " ", de, #argumentos)
end

-- ============================================
-- CATÁLOGO DE COMANDOS
-- ============================================
-- Cada comando é DADO:
--   nome         chave no prefixo (;coins)
--   apelidos     nomes alternativos
--   argumentos   texto de ajuda, mostrado no painel e no ;cmds
--   descricao    uma linha, mostrada no painel
--   categoria    agrupa no painel retro
--   nivel        nível mínimo
--   executar     function(ctx, argumentos) -> ok, mensagem
--
-- `executar` SEMPRE devolve mensagem, no sucesso e na falha. É o contrato
-- que mata o defeito do silêncio: o dispatcher garante que algo volta
-- para a tela do admin em todo caminho.

local COMANDOS = {}
local porNome = {}

-- Público de propósito, por dois motivos:
--
--   • É o gancho de "plugin" que o Adonis tem: comando novo entra sem
--     mexer neste arquivo. Quem registrar de fora entra no MESMO índice,
--     então o ;cmds e o painel enxergam na hora.
--   • Torna o dispatcher testável nos cantos. Sem isto não havia como
--     exercitar "comando devolve ok sem mensagem" — e essa era
--     exatamente a regressão que o teste deixava passar.
function RetroCommands.registrar(def)
	assert(type(def) == "table", "comando precisa ser tabela")
	assert(type(def.nome) == "string" and def.nome ~= "", "comando sem nome")
	assert(def.nome == string.lower(def.nome), string.format("comando %s precisa ser minúsculo", tostring(def.nome)))
	assert(type(def.executar) == "function", string.format("comando %s sem executar", tostring(def.nome)))
	assert(type(def.nivel) == "number", string.format("comando %s sem nivel", tostring(def.nome)))
	assert(porNome[def.nome] == nil, string.format("comando duplicado: %s", tostring(def.nome)))

	def.apelidos = def.apelidos or {}
	def.argumentos = def.argumentos or ""
	def.descricao = def.descricao or ""
	def.categoria = def.categoria or "GERAL"

	table.insert(COMANDOS, def)
	porNome[def.nome] = def
	for _, apelido in def.apelidos do
		assert(porNome[apelido] == nil, string.format("apelido duplicado: %s (de %s)", tostring(apelido), tostring(def.nome)))
		porNome[apelido] = def
	end
	return def
end

-- Só para o teste desfazer o que registrou. Não use em produção: comando
-- que aparece e desaparece deixa o painel do admin mentindo.
function RetroCommands.esquecer(nome)
	local def = porNome[nome]
	if not def then
		return false
	end
	porNome[nome] = nil
	for _, apelido in def.apelidos do
		porNome[apelido] = nil
	end
	for i, atual in COMANDOS do
		if atual == def then
			table.remove(COMANDOS, i)
			break
		end
	end
	return true
end

local registrar = RetroCommands.registrar

-- Atalho para o padrão "resolve alvos, roda em cada um, conta o resultado".
-- Existe porque esse laço repetido à mão em 30 comandos é onde o
-- tratamento de erro se perde.
local function porAlvo(ctx, texto, acao)
	local alvos, erro = RetroCommands.resolverAlvos(texto, ctx)
	if not alvos then
		return false, erro
	end
	local feitos, falhas = {}, {}
	for _, alvo in alvos do
		local ok, detalhe = acao(alvo)
		if ok then
			table.insert(feitos, detalhe or alvo.Name)
		else
			table.insert(falhas, string.format("%s: %s", tostring(alvo.Name), tostring(detalhe or "falhou")))
		end
	end
	if #feitos == 0 then
		return false, table.concat(falhas, " | ")
	end
	local mensagem = table.concat(feitos, ", ")
	if #falhas > 0 then
		mensagem = mensagem .. string.format(" (falhou em %s: %s)", tostring(#falhas), tostring(table.concat(falhas, " | ")))
	end
	return true, mensagem
end

-- Pede uma API `_G` e explica direito quando ela não existe, em vez de
-- estourar "attempt to index nil".
local function api(ctx, nome)
	local tabela = ctx.api and ctx.api[nome]
	if tabela == nil then
		return nil, string.format("%s não está carregado neste servidor", tostring(nome))
	end
	return tabela
end

-- ---------- ECONOMIA ----------

registrar({
	nome = "coins",
	apelidos = { "moedas" },
	argumentos = "<jogador> <quantia>",
	descricao = "Dá (ou tira, com número negativo) moedas.",
	categoria = "ECONOMIA",
	nivel = N.ADMIN,
	executar = function(ctx, argumentos)
		local dados, faltou = api(ctx, "PlayerDataManager")
		if not dados then
			return false, faltou
		end
		local quantia, erro = RetroCommands.numero(argumentos[2], "quantia")
		if not quantia then
			return false, erro
		end
		return porAlvo(ctx, argumentos[1], function(alvo)
			dados.updateCoins(alvo, quantia)
			dados.savePlayerData(alvo)
			return true, string.format("%s %s%s", tostring(alvo.Name), tostring(quantia >= 0 and "+" or ""), tostring(quantia))
		end)
	end,
})

registrar({
	nome = "bounty",
	apelidos = { "recompensa" },
	argumentos = "<jogador> <quantia>",
	descricao = "Altera a recompensa pela cabeça do jogador.",
	categoria = "ECONOMIA",
	nivel = N.ADMIN,
	executar = function(ctx, argumentos)
		local dados, faltou = api(ctx, "PlayerDataManager")
		if not dados then
			return false, faltou
		end
		local quantia, erro = RetroCommands.numero(argumentos[2], "quantia")
		if not quantia then
			return false, erro
		end
		return porAlvo(ctx, argumentos[1], function(alvo)
			dados.updateBounty(alvo, quantia)
			dados.savePlayerData(alvo)
			return true, string.format("%s %s%s", tostring(alvo.Name), tostring(quantia >= 0 and "+" or ""), tostring(quantia))
		end)
	end,
})

-- ---------- PERSONAGEM ----------

registrar({
	nome = "char",
	apelidos = { "personagem" },
	argumentos = "<jogador> <personagem>",
	descricao = "Põe um personagem no inventário. Nome com espaço funciona.",
	categoria = "PERSONAGEM",
	nivel = N.ADMIN,
	executar = function(ctx, argumentos)
		local dados, faltou = api(ctx, "PlayerDataManager")
		if not dados then
			return false, faltou
		end
		local personagem = RetroCommands.juntar(argumentos, 2)
		if personagem == "" then
			return false, "falta o nome do personagem"
		end
		return porAlvo(ctx, argumentos[1], function(alvo)
			dados.addCharacterToInventory(alvo, personagem)
			dados.savePlayerData(alvo)
			return true, string.format("%s ganhou %s", tostring(alvo.Name), tostring(personagem))
		end)
	end,
})

registrar({
	nome = "unchar",
	argumentos = "<jogador> <personagem>",
	descricao = "Tira um personagem do inventário.",
	categoria = "PERSONAGEM",
	nivel = N.CHEFE,
	executar = function(ctx, argumentos)
		local dados, faltou = api(ctx, "PlayerDataManager")
		if not dados then
			return false, faltou
		end
		local personagem = RetroCommands.juntar(argumentos, 2)
		if personagem == "" then
			return false, "falta o nome do personagem"
		end
		return porAlvo(ctx, argumentos[1], function(alvo)
			local ok = dados.removeCharacterByName(alvo, personagem)
			if not ok then
				return false, string.format("não tem %s", tostring(personagem))
			end
			dados.savePlayerData(alvo)
			return true, string.format("%s perdeu %s", tostring(alvo.Name), tostring(personagem))
		end)
	end,
})

registrar({
	nome = "allchars",
	apelidos = { "todoschars" },
	argumentos = "<jogador>",
	descricao = "Dá TODOS os personagens do catálogo. Catálogo vazio avisa.",
	categoria = "PERSONAGEM",
	nivel = N.CHEFE,
	executar = function(ctx, argumentos)
		local dados, faltou = api(ctx, "PlayerDataManager")
		if not dados then
			return false, faltou
		end
		local catalogo, faltou2 = api(ctx, "CharacterCatalog")
		if not catalogo then
			return false, faltou2
		end
		local nomes = {}
		for _, def in catalogo.listAll() or {} do
			local nome = type(def) == "table" and (def.name or def.Name or def.nome) or def
			if type(nome) == "string" and nome ~= "" then
				table.insert(nomes, nome)
			end
		end
		if #nomes == 0 then
			return false, "catálogo vazio — cadastre personagens no painel primeiro"
		end
		return porAlvo(ctx, argumentos[1], function(alvo)
			for _, nome in nomes do
				dados.addCharacterToInventory(alvo, nome)
			end
			dados.savePlayerData(alvo)
			return true, string.format("%s ganhou %s", tostring(alvo.Name), tostring(#nomes))
		end)
	end,
})

registrar({
	nome = "catalogo",
	apelidos = { "chars" },
	descricao = "Lista os personagens do catálogo dinâmico.",
	categoria = "PERSONAGEM",
	nivel = N.MODERADOR,
	executar = function(ctx)
		local catalogo, faltou = api(ctx, "CharacterCatalog")
		if not catalogo then
			return false, faltou
		end
		local nomes = {}
		for _, def in catalogo.listAll() or {} do
			local nome = type(def) == "table" and (def.name or def.Name or def.nome) or def
			if type(nome) == "string" then
				table.insert(nomes, nome)
			end
		end
		if #nomes == 0 then
			return false, "catálogo vazio"
		end
		return true, string.format("%s: %s", tostring(#nomes), tostring(table.concat(nomes, ", ")))
	end,
})

-- ---------- COMBATE ----------

registrar({
	nome = "kill",
	apelidos = { "matar" },
	argumentos = "<jogador>",
	descricao = "Zera a vida do alvo.",
	categoria = "COMBATE",
	nivel = N.MODERADOR,
	executar = function(ctx, argumentos)
		return porAlvo(ctx, argumentos[1], function(alvo)
			local humanoide = ctx.humanoideDe and ctx.humanoideDe(alvo)
			if not humanoide then
				return false, "sem personagem vivo"
			end
			humanoide.Health = 0
			return true, alvo.Name
		end)
	end,
})

registrar({
	nome = "heal",
	apelidos = { "curar", "vida" },
	argumentos = "<jogador>",
	descricao = "Enche a vida recalculando os atributos do personagem.",
	categoria = "COMBATE",
	nivel = N.MODERADOR,
	executar = function(ctx, argumentos)
		local stats, faltou = api(ctx, "StatService")
		if not stats then
			return false, faltou
		end
		return porAlvo(ctx, argumentos[1], function(alvo)
			stats.recompute(alvo, true)
			return true, alvo.Name
		end)
	end,
})

registrar({
	nome = "escudo",
	argumentos = "<jogador> <quantia>",
	descricao = "Devolve escudo ao alvo.",
	categoria = "COMBATE",
	nivel = N.ADMIN,
	executar = function(ctx, argumentos)
		local stats, faltou = api(ctx, "StatService")
		if not stats then
			return false, faltou
		end
		local quantia, erro = RetroCommands.numero(argumentos[2], "quantia")
		if not quantia then
			return false, erro
		end
		return porAlvo(ctx, argumentos[1], function(alvo)
			stats.restoreShield(alvo, quantia)
			return true, string.format("%s +%s", tostring(alvo.Name), tostring(quantia))
		end)
	end,
})

registrar({
	nome = "stats",
	apelidos = { "atributos" },
	argumentos = "<jogador>",
	descricao = "Mostra os atributos calculados e o escudo.",
	categoria = "COMBATE",
	nivel = N.MODERADOR,
	executar = function(ctx, argumentos)
		local stats, faltou = api(ctx, "StatService")
		if not stats then
			return false, faltou
		end
		local alvos, erro = RetroCommands.resolverAlvos(argumentos[1], ctx)
		if not alvos then
			return false, erro
		end
		local alvo = alvos[1]
		local partes = {}
		for _, chave in { "maxHealth", "damage", "speed", "defense" } do
			local valor = stats.getStat(alvo, chave)
			if valor ~= nil then
				table.insert(partes, string.format("%s=%s", tostring(chave), tostring(valor)))
			end
		end
		local escudo = stats.getShield and stats.getShield(alvo)
		if escudo ~= nil then
			table.insert(partes, string.format("escudo=%s", tostring(escudo)))
		end
		if #partes == 0 then
			return false, string.format("%s sem atributos calculados ainda", tostring(alvo.Name))
		end
		return true, string.format("%s: %s", tostring(alvo.Name), tostring(table.concat(partes, " ")))
	end,
})

registrar({
	nome = "dano",
	argumentos = "<atacante> <vitima> <quantia>",
	descricao = "Simula um golpe passando pelo núcleo de combate.",
	categoria = "COMBATE",
	nivel = N.CHEFE,
	executar = function(ctx, argumentos)
		local simular, faltou = api(ctx, "SimulateDamage")
		if not simular then
			return false, faltou
		end
		local atacantes, erroA = RetroCommands.resolverAlvos(argumentos[1], ctx)
		if not atacantes then
			return false, string.format("atacante: %s", tostring(erroA))
		end
		local vitimas, erroV = RetroCommands.resolverAlvos(argumentos[2], ctx)
		if not vitimas then
			return false, string.format("vítima: %s", tostring(erroV))
		end
		local quantia, erro = RetroCommands.numero(argumentos[3], "quantia")
		if not quantia then
			return false, erro
		end
		simular(atacantes[1].Name, vitimas[1].Name, quantia)
		return true, string.format("%s -> %s (%s)", tostring(atacantes[1].Name), tostring(vitimas[1].Name), tostring(quantia))
	end,
})

registrar({
	nome = "efeito",
	argumentos = "<jogador> <efeito> [duracao]",
	descricao = "Aplica efeito de status. Use ;efeitos para ver a lista.",
	categoria = "COMBATE",
	nivel = N.ADMIN,
	executar = function(ctx, argumentos)
		local efeitos, faltou = api(ctx, "StatusEffect")
		if not efeitos then
			return false, faltou
		end
		local id = argumentos[2]
		if not id or id == "" then
			return false, "falta o efeito — veja ;efeitos"
		end
		if efeitos.CATALOGO and efeitos.CATALOGO[id] == nil then
			return false, string.format("efeito \"%s\" não existe — veja ;efeitos", tostring(id))
		end
		local duracao = argumentos[3] and tonumber(argumentos[3]) or nil
		return porAlvo(ctx, argumentos[1], function(alvo)
			local personagem = ctx.personagemDe and ctx.personagemDe(alvo)
			if not personagem then
				return false, "sem personagem vivo"
			end
			efeitos.aplicar(personagem, id, duracao, alvo)
			return true, string.format("%s <- %s", tostring(alvo.Name), tostring(id))
		end)
	end,
})

registrar({
	nome = "limpaefeito",
	apelidos = { "semefeito" },
	argumentos = "<jogador>",
	descricao = "Remove todos os efeitos de status do alvo.",
	categoria = "COMBATE",
	nivel = N.MODERADOR,
	executar = function(ctx, argumentos)
		local efeitos, faltou = api(ctx, "StatusEffect")
		if not efeitos then
			return false, faltou
		end
		return porAlvo(ctx, argumentos[1], function(alvo)
			local personagem = ctx.personagemDe and ctx.personagemDe(alvo)
			if not personagem then
				return false, "sem personagem vivo"
			end
			efeitos.limparTodos(personagem)
			return true, alvo.Name
		end)
	end,
})

registrar({
	nome = "efeitos",
	descricao = "Lista os efeitos de status que existem.",
	categoria = "COMBATE",
	nivel = N.MODERADOR,
	executar = function(ctx)
		local efeitos, faltou = api(ctx, "StatusEffect")
		if not efeitos then
			return false, faltou
		end
		local ids = {}
		for id in efeitos.CATALOGO or {} do
			table.insert(ids, id)
		end
		if #ids == 0 then
			return false, "nenhum efeito cadastrado"
		end
		table.sort(ids)
		return true, table.concat(ids, ", ")
	end,
})

registrar({
	nome = "energia",
	argumentos = "<jogador>",
	descricao = "Mostra a energia atual do alvo.",
	categoria = "COMBATE",
	nivel = N.MODERADOR,
	executar = function(ctx, argumentos)
		local energia, faltou = api(ctx, "EnergySystem")
		if not energia then
			return false, faltou
		end
		local alvos, erro = RetroCommands.resolverAlvos(argumentos[1], ctx)
		if not alvos then
			return false, erro
		end
		local valor = energia.getEnergy(alvos[1])
		if valor == nil then
			return false, string.format("%s sem energia registrada", tostring(alvos[1].Name))
		end
		return true, string.format("%s: %s", tostring(alvos[1].Name), tostring(valor))
	end,
})

-- ---------- DESPERTAR ----------

registrar({
	nome = "desperto",
	argumentos = "<jogador>",
	descricao = "Diz se o alvo está desperto e quanto tem de medidor.",
	categoria = "DESPERTAR",
	nivel = N.MODERADOR,
	executar = function(ctx, argumentos)
		local medidor, faltou = api(ctx, "AwakeningMeter")
		if not medidor then
			return false, faltou
		end
		local alvos, erro = RetroCommands.resolverAlvos(argumentos[1], ctx)
		if not alvos then
			return false, erro
		end
		local alvo = alvos[1]
		local estado = medidor.getEstado(alvo)
		if not estado then
			return false, string.format("%s sem medidor ainda", tostring(alvo.Name))
		end
		local ligado = medidor.estaDesperto(alvo) and "SIM" or "não"
		return true, string.format("%s: desperto=%s medidor=%s/%s", tostring(alvo.Name), tostring(ligado), tostring(estado.valor), tostring(estado.max))
	end,
})

registrar({
	nome = "despertares",
	descricao = "Lista os Despertares cadastrados.",
	categoria = "DESPERTAR",
	nivel = N.MODERADOR,
	executar = function(ctx)
		local sistema, faltou = api(ctx, "AwakeningSystem")
		if not sistema then
			return false, faltou
		end
		local nomes = {}
		for chave, def in sistema.listAll() or {} do
			local nome = type(def) == "table" and (def.name or def.nome) or nil
			table.insert(nomes, tostring(nome or chave))
		end
		if #nomes == 0 then
			return false, "nenhum Despertar cadastrado"
		end
		table.sort(nomes)
		return true, string.format("%s: %s", tostring(#nomes), tostring(table.concat(nomes, ", ")))
	end,
})

-- ---------- PROGRESSO ----------

registrar({
	nome = "xp",
	argumentos = "<jogador> <quantia> [personagem]",
	descricao = "Dá XP. Sem personagem, usa o equipado.",
	categoria = "PROGRESSO",
	nivel = N.ADMIN,
	executar = function(ctx, argumentos)
		local nivel, faltou = api(ctx, "CharacterLevel")
		if not nivel then
			return false, faltou
		end
		local quantia, erro = RetroCommands.numero(argumentos[2], "quantia")
		if not quantia then
			return false, erro
		end
		local personagem = RetroCommands.juntar(argumentos, 3)
		return porAlvo(ctx, argumentos[1], function(alvo)
			if personagem ~= "" then
				nivel.awardXpTo(alvo, personagem, quantia, "admin")
			else
				nivel.awardXp(alvo, quantia, "admin")
			end
			return true, string.format("%s +%s", tostring(alvo.Name), tostring(quantia))
		end)
	end,
})

registrar({
	nome = "reset",
	argumentos = "<jogador>",
	descricao = "APAGA os dados do jogador. Não tem desfazer.",
	categoria = "PROGRESSO",
	nivel = N.DONO,
	executar = function(ctx, argumentos)
		local dados, faltou = api(ctx, "PlayerDataManager")
		if not dados then
			return false, faltou
		end
		return porAlvo(ctx, argumentos[1], function(alvo)
			dados.resetPlayerData(alvo)
			return true, string.format("%s zerado", tostring(alvo.Name))
		end)
	end,
})

registrar({
	nome = "tutorial",
	argumentos = "<jogador>",
	descricao = "Faz o tutorial rodar de novo para o alvo.",
	categoria = "PROGRESSO",
	nivel = N.MODERADOR,
	executar = function(ctx, argumentos)
		local resetar, faltou = api(ctx, "ResetTutorial")
		if not resetar then
			return false, faltou
		end
		return porAlvo(ctx, argumentos[1], function(alvo)
			resetar(alvo.Name)
			return true, alvo.Name
		end)
	end,
})

registrar({
	nome = "conquistas",
	argumentos = "<jogador>",
	descricao = "Reconfere as conquistas do alvo agora.",
	categoria = "PROGRESSO",
	nivel = N.MODERADOR,
	executar = function(ctx, argumentos)
		local conferir, faltou = api(ctx, "CheckAchievements")
		if not conferir then
			return false, faltou
		end
		return porAlvo(ctx, argumentos[1], function(alvo)
			conferir(alvo)
			return true, alvo.Name
		end)
	end,
})

-- ---------- PASSIVA ----------

registrar({
	nome = "passivas",
	argumentos = "<jogador>",
	descricao = "Mostra os slots de passiva do alvo.",
	categoria = "PASSIVA",
	nivel = N.MODERADOR,
	executar = function(ctx, argumentos)
		local passiva, faltou = api(ctx, "PassiveSystem")
		if not passiva then
			return false, faltou
		end
		local alvos, erro = RetroCommands.resolverAlvos(argumentos[1], ctx)
		if not alvos then
			return false, erro
		end
		local alvo = alvos[1]
		local slots = passiva.slots and passiva.slots(alvo)
		if slots == nil then
			return false, string.format("%s sem slots", tostring(alvo.Name))
		end
		if type(slots) == "table" then
			local lista = {}
			for _, v in slots do
				table.insert(lista, tostring(v))
			end
			return true, string.format("%s: %s", tostring(alvo.Name), tostring(#lista > 0 and table.concat(lista, ", ") or "vazio"))
		end
		return true, string.format("%s: %s", tostring(alvo.Name), tostring(tostring(slots)))
	end,
})

registrar({
	nome = "repassiva",
	argumentos = "<jogador>",
	descricao = "Reaplica as passivas do alvo (útil depois de editar).",
	categoria = "PASSIVA",
	nivel = N.ADMIN,
	executar = function(ctx, argumentos)
		local passiva, faltou = api(ctx, "PassiveSystem")
		if not passiva then
			return false, faltou
		end
		return porAlvo(ctx, argumentos[1], function(alvo)
			passiva.reapply(alvo)
			return true, alvo.Name
		end)
	end,
})

-- ---------- MUNDO ----------

registrar({
	nome = "tp",
	apelidos = { "trazer" },
	argumentos = "<jogador>",
	descricao = "Traz o alvo até você.",
	categoria = "MUNDO",
	nivel = N.MODERADOR,
	executar = function(ctx, argumentos)
		local minha = ctx.raizDe and ctx.raizDe(ctx.autor)
		if not minha then
			return false, "você precisa estar vivo para trazer alguém"
		end
		return porAlvo(ctx, argumentos[1], function(alvo)
			if alvo == ctx.autor then
				return false, "você já está onde está"
			end
			local raiz = ctx.raizDe and ctx.raizDe(alvo)
			if not raiz then
				return false, "sem personagem vivo"
			end
			raiz.CFrame = minha.CFrame
			return true, alvo.Name
		end)
	end,
})

registrar({
	nome = "tpme",
	apelidos = { "irpara" },
	argumentos = "<jogador>",
	descricao = "Leva você até o alvo.",
	categoria = "MUNDO",
	nivel = N.MODERADOR,
	executar = function(ctx, argumentos)
		local minha = ctx.raizDe and ctx.raizDe(ctx.autor)
		if not minha then
			return false, "você precisa estar vivo"
		end
		local alvos, erro = RetroCommands.resolverAlvos(argumentos[1], ctx)
		if not alvos then
			return false, erro
		end
		local alvo = alvos[1]
		if alvo == ctx.autor then
			return false, "você já está onde está"
		end
		local raiz = ctx.raizDe and ctx.raizDe(alvo)
		if not raiz then
			return false, string.format("%s sem personagem vivo", tostring(alvo.Name))
		end
		minha.CFrame = raiz.CFrame
		return true, string.format("você foi até %s", tostring(alvo.Name))
	end,
})

registrar({
	nome = "zonasegura",
	apelidos = { "lobby" },
	argumentos = "<jogador>",
	descricao = "Manda o alvo para a zona segura.",
	categoria = "MUNDO",
	nivel = N.MODERADOR,
	executar = function(ctx, argumentos)
		local mandar, faltou = api(ctx, "TeleportToSafeZone")
		if not mandar then
			return false, faltou
		end
		return porAlvo(ctx, argumentos[1], function(alvo)
			mandar(alvo.Name)
			return true, alvo.Name
		end)
	end,
})

registrar({
	nome = "espectador",
	argumentos = "<jogador> <on|off>",
	descricao = "Liga ou desliga o modo espectador.",
	categoria = "MUNDO",
	nivel = N.ADMIN,
	executar = function(ctx, argumentos)
		local definir, faltou = api(ctx, "SetSpectatorMode")
		if not definir then
			return false, faltou
		end
		local ligado, erro = RetroCommands.booleano(argumentos[2], "modo")
		if ligado == nil then
			return false, erro
		end
		return porAlvo(ctx, argumentos[1], function(alvo)
			definir(alvo, ligado)
			return true, string.format("%s %s", tostring(alvo.Name), tostring(ligado and "ON" or "OFF"))
		end)
	end,
})

registrar({
	nome = "time",
	apelidos = { "equipe" },
	argumentos = "<jogador>",
	descricao = "Diz em que time o alvo está.",
	categoria = "MUNDO",
	nivel = N.MODERADOR,
	executar = function(ctx, argumentos)
		local pegar, faltou = api(ctx, "GetPlayerTeam")
		if not pegar then
			return false, faltou
		end
		local alvos, erro = RetroCommands.resolverAlvos(argumentos[1], ctx)
		if not alvos then
			return false, erro
		end
		local time = pegar(alvos[1])
		if time == nil then
			return false, string.format("%s sem time", tostring(alvos[1].Name))
		end
		local nome = type(time) == "table" and (time.name or time.nome or time.id) or time
		return true, string.format("%s: %s", tostring(alvos[1].Name), tostring(tostring(nome)))
	end,
})

registrar({
	nome = "procurado",
	apelidos = { "wanted" },
	descricao = "Mostra quem é o procurado do servidor e quantas estrelas.",
	categoria = "MUNDO",
	nivel = N.MODERADOR,
	executar = function(ctx)
		local sistema, faltou = api(ctx, "WantedSystem")
		if not sistema then
			return false, faltou
		end
		local alvo = sistema.getTarget()
		if alvo == nil then
			return true, "ninguém procurado agora"
		end
		local nome = type(alvo) == "table" and (alvo.Name or alvo.name) or alvo
		return true, string.format("%s — %s estrela(s)", tostring(tostring(nome)), tostring(tostring(sistema.getStars())))
	end,
})

registrar({
	nome = "recarregaspawn",
	descricao = "Relê os pontos de nascimento do mapa.",
	categoria = "MUNDO",
	nivel = N.CHEFE,
	executar = function(ctx)
		local recarregar, faltou = api(ctx, "ReloadMapSpawnPoints")
		if not recarregar then
			return false, faltou
		end
		recarregar()
		return true, "pontos de nascimento recarregados"
	end,
})

-- ---------- ADMIN ----------
-- addadmin/deladmin ficam em CHEFE, não em DONO, por PARIDADE: no V8
-- qualquer admin podia usá-los, e a aba ADMINS do painel continua
-- permitindo. Deixar o chat mais restrito que o painel seria incoerência
-- que confunde sem proteger nada.

registrar({
	nome = "addadmin",
	argumentos = "<username ou id>",
	descricao = "Vira admin em TODOS os servidores. Salva sem Studio.",
	categoria = "ADMIN",
	nivel = N.CHEFE,
	executar = function(ctx, argumentos)
		local registro, faltou = api(ctx, "AdminRegistry")
		if not registro then
			return false, faltou
		end
		local entrada = RetroCommands.juntar(argumentos, 1)
		if entrada == "" then
			return false, "falta o username ou id"
		end
		local ok, msg = registro.addAdmin(ctx.autor, entrada)
		return ok, tostring(msg)
	end,
})

registrar({
	nome = "deladmin",
	argumentos = "<username ou id>",
	descricao = "Remove um admin. O dono é irremovível.",
	categoria = "ADMIN",
	nivel = N.CHEFE,
	executar = function(ctx, argumentos)
		local registro, faltou = api(ctx, "AdminRegistry")
		if not registro then
			return false, faltou
		end
		local entrada = RetroCommands.juntar(argumentos, 1)
		if entrada == "" then
			return false, "falta o username ou id"
		end
		local ok, msg = registro.removeAdmin(ctx.autor, entrada)
		return ok, tostring(msg)
	end,
})

registrar({
	nome = "admins",
	descricao = "Lista quem é admin.",
	categoria = "ADMIN",
	nivel = N.MODERADOR,
	executar = function(ctx)
		local registro, faltou = api(ctx, "AdminRegistry")
		if not registro then
			return false, faltou
		end
		local lista = registro.listAll() or {}
		if #lista == 0 then
			return true, "nenhum admin registrado"
		end
		local partes = {}
		for _, e in lista do
			table.insert(partes, string.format("%s%s", tostring(e.name), tostring(e.isOwner and " (DONO)" or "")))
		end
		return true, string.format("%s: %s", tostring(#lista), tostring(table.concat(partes, ", ")))
	end,
})

registrar({
	nome = "cmds",
	apelidos = { "help", "ajuda", "comandos" },
	descricao = "Lista os comandos que VOCÊ pode usar, na tela.",
	categoria = "ADMIN",
	nivel = N.JOGADOR,
	executar = function(ctx)
		local lista = RetroCommands.listarPara(ctx.nivel or 0)
		if #lista == 0 then
			return false, "você não tem comando nenhum disponível"
		end
		local nomes = {}
		for _, def in lista do
			table.insert(nomes, RetroCommands.PREFIXO .. def.nome)
		end
		return true, string.format("%s comandos — abra o painel na aba CONSOLE para ver com descrição: %s", tostring(#lista), tostring(table.concat(nomes, " ")))
	end,
})

-- ============================================
-- ÍNDICE E CONSULTA
-- ============================================

RetroCommands.COMANDOS = COMANDOS

function RetroCommands.achar(nome)
	if type(nome) ~= "string" then
		return nil
	end
	return porNome[string.lower(nome)]
end

-- O que o painel client pede. Devolve só o que o nível alcança, para o
-- admin não ver botão que vai recusar — e sem `executar`, que é função e
-- não atravessa remote.
function RetroCommands.listarPara(nivel)
	nivel = tonumber(nivel) or 0
	local lista = {}
	for _, def in COMANDOS do
		if nivel >= def.nivel then
			table.insert(lista, {
				nome = def.nome,
				apelidos = def.apelidos,
				argumentos = def.argumentos,
				descricao = def.descricao,
				categoria = def.categoria,
				nivel = def.nivel,
				nivelNome = RetroCommands.NOME_DO_NIVEL[def.nivel] or tostring(def.nivel),
			})
		end
	end
	table.sort(lista, function(a, b)
		if a.categoria ~= b.categoria then
			return a.categoria < b.categoria
		end
		return a.nome < b.nome
	end)
	return lista
end

function RetroCommands.categorias(nivel)
	local vistas, ordem = {}, {}
	for _, def in RetroCommands.listarPara(nivel) do
		if not vistas[def.categoria] then
			vistas[def.categoria] = true
			table.insert(ordem, def.categoria)
		end
	end
	return ordem
end

-- ============================================
-- DISPATCHER
-- ============================================
-- O contrato que mata o defeito do silêncio: TODO caminho daqui devolve
-- `ok, mensagem`. Comando que não existe, nível insuficiente, argumento
-- errado, alvo não encontrado, API fora do ar e erro de runtime — todos
-- viram texto que o AdminSystemServer mostra na tela do admin.
function RetroCommands.executar(mensagem, ctx)
	local pedido = RetroCommands.parse(mensagem)
	if not pedido then
		return nil -- não era comando; o chat segue normal
	end

	local def = RetroCommands.achar(pedido.nome)
	if not def then
		return { ok = false, mensagem = string.format("comando \"%s%s\" não existe — use ;cmds", tostring(RetroCommands.PREFIXO), tostring(pedido.nome)), comando = pedido.nome }
	end

	local nivel = tonumber(ctx.nivel) or 0
	if nivel < def.nivel then
		local preciso = RetroCommands.NOME_DO_NIVEL[def.nivel] or tostring(def.nivel)
		return {
			ok = false,
			mensagem = string.format("%s%s exige %s", tostring(RetroCommands.PREFIXO), tostring(def.nome), tostring(preciso)),
			comando = def.nome,
			negado = true,
		}
	end

	-- pcall para que um erro dentro de um comando não derrube o listener de
	-- chat do servidor inteiro — sem isso, um comando com bug mataria TODOS
	-- os comandos até o servidor reiniciar.
	local sucesso, ok, texto = pcall(def.executar, ctx, pedido.argumentos)
	if not sucesso then
		return { ok = false, mensagem = string.format("%s deu erro: %s", tostring(def.nome), tostring(tostring(ok))), comando = def.nome, erro = true }
	end

	return {
		ok = ok and true or false,
		mensagem = tostring(texto or (ok and "feito" or "não deu")),
		comando = def.nome,
		argumentos = pedido.argumentos,
	}
end

return RetroCommands
