-- Nome: "NucleoCombate_V2"
--[[
════════════════════════════════════════════════════════════════
	NÚCLEO DE COMBATE V2 — REGRA 12
	ModuleScript
	Local OBRIGATÓRIO: ServerScriptService > RetroVerse > NucleoCombate_V2
	Consumo: require(ServerScriptService.RetroVerse.NucleoCombate_V2)
	SUBSTITUI: NucleoCombate_V1
	REMOVER:   NucleoCombate_V1

	────────────────────────────────────────────────────────────
	(V2) MODIFICADORES DINÂMICOS — EMBUTIDOS, NÃO INDIVIDUAIS
	────────────────────────────────────────────────────────────
	Três passivas não cabiam no pipeline do V1 porque dependem de
	uma RELAÇÃO entre atacante e alvo, e não de um número fixo:

	  • Frenesi  — depende da vida ATUAL do atacante
	  • Duelista — compara o NÍVEL de quem bate com o de quem apanha
	  • Vampírico— precisa do dano FINAL, depois de tudo aplicado

	A saída errada seria cada Tool resolver isso por conta. Aí
	toda Tool nova teria que lembrar de chamar Frenesi, Duelista e
	Vampírico — e a primeira que esquecesse criaria um buraco de
	balanceamento silencioso.

	A saída certa, e a adotada aqui: o Núcleo ganha DOIS pontos de
	extensão, e quem registra neles são os SISTEMAS (não as Tools).
	Uma Tool nova continua chamando só `aplicarDano` e ganha todas
	as passivas de graça, sem uma linha a mais.

	  Nucleo.registrarModificador(nome, funcao)  -> ajusta o dano
	  Nucleo.aoAplicarDano(callback)             -> avisa o resultado

	⚠️ IMPORTANTE — POR QUE O MODIFICADOR SOMA E NÃO MULTIPLICA:
	   A função devolve uma CONTRIBUIÇÃO DE AUMENTO (0.25 = +25%),
	   que entra no mesmo grupo aditivo do §12.5 e respeita o mesmo
	   teto de 300%. Se cada modificador multiplicasse por fora, um
	   Frenesi + Duelista + fraqueza elemental empilhariam e
	   matariam um chefe num golpe.
════════════════════════════════════════════════════════════════

	ESCRITO DO ZERO, NO PADRÃO DO PROJETO.
	Nenhuma linha do Gear Manager foi reaproveitada — apenas o
	desenho da API, conforme §12.0.

	────────────────────────────────────────────────────────────
	COMO ISTO CONVERSA COM O StatService (leia antes de mexer)
	────────────────────────────────────────────────────────────
	O projeto tem DOIS lugares que sabiam calcular dano:

	  • REGRA 12 (este Núcleo) — redução, aumento e escudo vindos
	    das habilidades das Tools.
	  • StatService V2 — DamageBoost, DamageResistance, Defense,
	    boost por classe, pierce e Shield vindos do arquétipo do
	    personagem, das passivas e do nível.

	Se os dois calcularem, o dano é aplicado duas vezes e o
	resultado fica imprevisível — foi exatamente esse tipo de
	duplicação que quebrou o sistema antes.

	DECISÃO: a REGRA 12 é a autoridade. Este Núcleo é a porta
	única (§12.5). O StatService vira FONTE: o Núcleo pergunta a
	ele os números permanentes do personagem e junta com os
	temporários das Tools. O StatService continua dono de
	MaxHealth, WalkSpeed e Jump — isso não muda.

	⚠️ CONSEQUÊNCIA OBRIGATÓRIA: o PassiveSystemServer NÃO pode
	   mais interceptar HealthChanged pra corrigir dano. Enquanto
	   ele fizer isso, o dano é corrigido duas vezes. Use o
	   PassiveSystemServer V5 ou superior junto deste Núcleo.

	────────────────────────────────────────────────────────────
	DIVERGÊNCIAS RESOLVIDAS (§12.5 venceu)
	────────────────────────────────────────────────────────────
	  Redução ....... multiplicativa, teto 90%   (o StatService
	                  usava aditiva com teto 75%)
	  Aumento ....... aditivo, teto 300%
	  Escudo ........ consumido ANTES do Humanoid (o
	                  PassiveSystemServer devolvia vida DEPOIS,
	                  o que fazia a barra piscar)

	A resistência que vem do StatService entra como UM fator de
	redução e é combinada multiplicativamente com as das Tools.

	────────────────────────────────────────────────────────────
	EXTENSÃO PROPOSTA PARA A §12 V2
	────────────────────────────────────────────────────────────
	`aplicarDano` ganhou um 6º parâmetro OPCIONAL: `classe`
	("Melee", "Ranged", "Magic", "Summon", "Debuff"). Sem ele, o
	boost por classe do StatService fica inerte — foi assim que
	o arquétipo "Lutador (Melee)" não fazia nada.
	É retrocompatível: quem não passar nada continua funcionando.
════════════════════════════════════════════════════════════════
]]

local Players = game:GetService("Players")
local Debris = game:GetService("Debris")
local Workspace = game:GetService("Workspace")

local Nucleo = {}

--[[
════════════════════════════════════════════════════════════════
	CONFIGURAÇÃO INTERNA
	Estes são TETOS DE SEGURANÇA, não balanceamento.
	Balanceamento (dano, raio, recarga) fica no CFG de cada Tool
	(§12.10). Nada disso aqui é número de gameplay.
════════════════════════════════════════════════════════════════
]]

local LIMITES = {
	RAIO_MAXIMO = 512, -- §12.4: teto de raio
	ALVOS_MAXIMO = 100, -- §12.4: teto de alvos
	REDUCAO_MAXIMA = 0.90, -- §12.5: teto de redução
	AUMENTO_MAXIMO = 3.00, -- §12.5: teto de aumento (300%)
	CREDITO_PADRAO = 2, -- segundos da tag creator
	DANO_MINIMO = 0, -- dano nunca fica negativo
}

local CLASSES_VALIDAS = {
	Melee = true,
	Ranged = true,
	Magic = true,
	Summon = true,
	Debuff = true,
}

--[[
════════════════════════════════════════════════════════════════
	REGISTROS — CHAVES FRACAS (§12.6)
	Quando o personagem sai do jogo, o coletor de lixo remove a
	entrada sozinho. Nenhum AncestryChanged, nenhum Folder de
	NumberValue, nenhuma varredura de limpeza.
════════════════════════════════════════════════════════════════
]]

local registroReducao = setmetatable({}, { __mode = "k" })
local registroAumento = setmetatable({}, { __mode = "k" })
local registroEscudo = setmetatable({}, { __mode = "k" })
local registroRecarga = setmetatable({}, { __mode = "k" })

--[[
════════════════════════════════════════════════════════════════
	UTILITÁRIOS BÁSICOS
════════════════════════════════════════════════════════════════
]]

function Nucleo.obterHumanoide(instancia)
	if typeof(instancia) ~= "Instance" then
		return nil
	end

	-- Sobe a hierarquia até achar um Humanoid (a parte tocada
	-- costuma ser neta do Model)
	local atual = instancia
	local profundidade = 0

	while atual and atual ~= Workspace and profundidade < 5 do
		local humanoide = atual:FindFirstChildOfClass("Humanoid")
		if humanoide then
			return humanoide
		end
		atual = atual.Parent
		profundidade = profundidade + 1
	end

	return nil
end

function Nucleo.estaVivo(humanoide)
	return humanoide ~= nil
		and typeof(humanoide) == "Instance"
		and humanoide:IsA("Humanoid")
		and humanoide.Parent ~= nil
		and humanoide.Health > 0
end

function Nucleo.mesmoTime(jogadorA, jogadorB)
	if not jogadorA or not jogadorB then
		return false
	end
	if jogadorA == jogadorB then
		return true
	end
	if jogadorA.Neutral or jogadorB.Neutral then
		return false
	end
	return jogadorA.TeamColor == jogadorB.TeamColor
end

--[[
	§12.3 — PORTA ÚNICA DE PERMISSÃO
	Substitui o canDamage() que cada Tool reimplementava.

	Reaproveita `_G.CanDamagePlayer` do TeamDamageProtection V3
	quando ele existe, pra não criar uma SEGUNDA regra de fogo
	amigo concorrendo com a que já está no projeto.
]]
function Nucleo.podeCausarDano(jogadorDono, humanoideAlvo, humanoideDono)
	if not Nucleo.estaVivo(humanoideAlvo) then
		return false
	end

	-- Nunca em si mesmo
	if humanoideDono and humanoideAlvo == humanoideDono then
		return false
	end

	-- ForceField protege (o TakeDamage respeita, mas evita
	-- gastar processamento e efeito à toa)
	local personagemAlvo = humanoideAlvo.Parent
	if personagemAlvo and personagemAlvo:FindFirstChildOfClass("ForceField") then
		return false
	end

	local jogadorAlvo = personagemAlvo and Players:GetPlayerFromCharacter(personagemAlvo)

	-- Alvo é NPC: sempre pode
	if not jogadorAlvo then
		return true
	end

	if not jogadorDono then
		return true
	end

	if jogadorAlvo == jogadorDono then
		return false
	end

	-- A regra de fogo amigo do projeto tem prioridade
	if _G.CanDamagePlayer then
		local ok, permitido = pcall(_G.CanDamagePlayer, jogadorDono, jogadorAlvo)
		if ok then
			return permitido == true
		end
	end

	return not Nucleo.mesmoTime(jogadorDono, jogadorAlvo)
end

--[[
════════════════════════════════════════════════════════════════
	§12.4 — DETECÇÃO EM ÁREA
	Substituto canônico de Instance.new("Explosion") e de
	varredura por GetChildren()/GetDescendants().
════════════════════════════════════════════════════════════════
]]

local function posicaoDe(origem)
	local tipo = typeof(origem)

	if tipo == "Vector3" then
		return origem
	elseif tipo == "CFrame" then
		return origem.Position
	elseif tipo == "Instance" and origem:IsA("BasePart") then
		return origem.Position
	end

	return nil
end

function Nucleo.detectarHumanoides(origem, raio, ignorar, jogador, humanoideDono, limite)
	local posicao = posicaoDe(origem)
	if not posicao then
		warn("[NUCLEO] detectarHumanoides: origem inválida")
		return false, {}
	end

	raio = math.clamp(tonumber(raio) or 0, 0, LIMITES.RAIO_MAXIMO)
	if raio <= 0 then
		return false, {}
	end

	limite = math.clamp(math.floor(tonumber(limite) or LIMITES.ALVOS_MAXIMO), 1, LIMITES.ALVOS_MAXIMO)

	local parametros = OverlapParams.new()
	parametros.FilterType = Enum.RaycastFilterType.Exclude
	parametros.FilterDescendantsInstances = (typeof(ignorar) == "table") and ignorar or {}
	parametros.MaxParts = 0 -- sem teto de partes; o teto real é de ALVOS

	local partes = Workspace:GetPartBoundsInRadius(posicao, raio, parametros)

	local alvos = {}
	local vistos = {} -- deduplicação: um alvo de 15 partes conta UMA vez

	for indice = 1, #partes do
		if #alvos >= limite then
			break
		end

		local humanoide = Nucleo.obterHumanoide(partes[indice])

		if humanoide and not vistos[humanoide] then
			vistos[humanoide] = true

			if Nucleo.podeCausarDano(jogador, humanoide, humanoideDono) then
				table.insert(alvos, humanoide)
			end
		end
	end

	-- Libera as referências de parte ao fim do laço (§12.4)
	partes = nil
	vistos = nil

	return (#alvos > 0), alvos
end

--[[
════════════════════════════════════════════════════════════════
	§12.6 — MODIFICADORES COM CANCELAMENTO POR CLOSURE
	Cada registro devolve a própria função de cancelamento.
	Sem :Destroy(), sem AncestryChanged, sem Folder de NumberValue.
════════════════════════════════════════════════════════════════
]]

local function registrar(tabela, personagem, valor, duracao)
	if not personagem or typeof(personagem) ~= "Instance" then
		return function() end
	end

	valor = tonumber(valor)
	if not valor or valor ~= valor then -- rejeita nil e NaN
		return function() end
	end

	tabela[personagem] = tabela[personagem] or {}

	local entrada = { valor = valor, ativo = true }
	table.insert(tabela[personagem], entrada)

	local function cancelar()
		if not entrada.ativo then
			return false -- já cancelado; chamar de novo é inofensivo
		end
		entrada.ativo = false

		local lista = tabela[personagem]
		if lista then
			for indice = #lista, 1, -1 do
				if lista[indice] == entrada then
					table.remove(lista, indice)
					break
				end
			end
			if #lista == 0 then
				tabela[personagem] = nil
			end
		end

		return true
	end

	duracao = tonumber(duracao)
	if duracao and duracao > 0 then
		task.delay(duracao, cancelar)
	end

	return cancelar
end

function Nucleo.registrarReducao(personagem, percentual, duracao)
	return registrar(registroReducao, personagem, percentual, duracao)
end

function Nucleo.registrarAumento(personagem, percentual, duracao)
	return registrar(registroAumento, personagem, percentual, duracao)
end

function Nucleo.registrarEscudo(personagem, pontos, duracao)
	return registrar(registroEscudo, personagem, pontos, duracao)
end

--[[
════════════════════════════════════════════════════════════════
	LEITURA DE MODIFICADORES
	É aqui que o StatService entra como FONTE.
════════════════════════════════════════════════════════════════
]]

local function jogadorDe(personagem)
	if not personagem or typeof(personagem) ~= "Instance" then
		return nil
	end
	return Players:GetPlayerFromCharacter(personagem)
end

-- Resistência permanente do personagem (arquétipo + passivas +
-- nível + Defense flat), já como fração 0..1
local function reducaoDoStatService(personagem, classe)
	if not _G.StatService then
		return 0
	end

	local jogador = jogadorDe(personagem)
	if not jogador then
		return 0 -- NPC ainda não tem ficha de atributos
	end

	local ok, resistencia = pcall(
		_G.StatService.getEffectiveResistance,
		jogador,
		classe,
		nil
	)

	if ok and type(resistencia) == "number" and resistencia == resistencia then
		return math.clamp(resistencia, -LIMITES.REDUCAO_MAXIMA, LIMITES.REDUCAO_MAXIMA)
	end

	return 0
end

-- Aumento permanente do atacante (DamageBoost + boost da classe)
local function aumentoDoStatService(personagem, classe)
	if not _G.StatService then
		return 0
	end

	local jogador = jogadorDe(personagem)
	if not jogador then
		return 0
	end

	local ok, multiplicador = pcall(_G.StatService.getDamageMultiplier, jogador, classe)

	if ok and type(multiplicador) == "number" and multiplicador == multiplicador then
		return multiplicador - 1 -- vira "aumento" (0.30 = +30%)
	end

	return 0
end

--[[
	§12.5 — REDUÇÃO EMPILHA MULTIPLICATIVAMENTE
	Três reduções de 40% dão 78,4%, nunca 120%. Imunidade total é
	impossível por acidente.
	A resistência do StatService entra como MAIS UM fator.
]]
function Nucleo.obterReducao(personagem, classe)
	local restante = 1.0

	local doStat = reducaoDoStatService(personagem, classe)
	restante = restante * (1 - doStat)

	local lista = registroReducao[personagem]
	if lista then
		for indice = 1, #lista do
			local entrada = lista[indice]
			if entrada.ativo then
				restante = restante * (1 - entrada.valor)
			end
		end
	end

	local reducao = 1 - restante
	return math.clamp(reducao, -LIMITES.REDUCAO_MAXIMA, LIMITES.REDUCAO_MAXIMA)
end

--[[
	§12.5 — AUMENTO EMPILHA ADITIVAMENTE, COM TETO
	Buffs somam de forma legível pelo jogador, mas não explodem.
]]
function Nucleo.obterAumento(personagem, classe)
	local total = aumentoDoStatService(personagem, classe)

	local lista = registroAumento[personagem]
	if lista then
		for indice = 1, #lista do
			local entrada = lista[indice]
			if entrada.ativo then
				total = total + entrada.valor
			end
		end
	end

	return math.clamp(total, -0.90, LIMITES.AUMENTO_MAXIMO)
end

function Nucleo.obterEscudo(personagem)
	local total = 0

	local lista = registroEscudo[personagem]
	if lista then
		for indice = 1, #lista do
			local entrada = lista[indice]
			if entrada.ativo then
				total = total + math.max(0, entrada.valor)
			end
		end
	end

	-- Escudo vindo do atributo Shield (arquétipo / passiva / gear)
	if _G.StatService then
		local jogador = jogadorDe(personagem)
		if jogador then
			local ok, pontos = pcall(_G.StatService.getShield, jogador)
			if ok and type(pontos) == "number" then
				total = total + math.max(0, pontos)
			end
		end
	end

	return total
end

--[[
	Consome escudo NA ORDEM em que foi registrado.
	Devolve quanto de dano SOBROU pra vida.
]]
function Nucleo.consumirEscudo(personagem, dano)
	dano = math.max(0, tonumber(dano) or 0)
	if dano <= 0 then
		return 0
	end

	local lista = registroEscudo[personagem]
	if lista then
		for indice = 1, #lista do
			if dano <= 0 then
				break
			end
			local entrada = lista[indice]
			if entrada.ativo and entrada.valor > 0 then
				local absorvido = math.min(entrada.valor, dano)
				entrada.valor = entrada.valor - absorvido
				dano = dano - absorvido
			end
		end
	end

	-- Depois, o escudo vindo do atributo Shield (StatService)
	if dano > 0 and _G.StatService and _G.StatService.consumeShield then
		local jogador = jogadorDe(personagem)
		if jogador then
			local ok, restante = pcall(_G.StatService.consumeShield, jogador, dano)
			if ok and type(restante) == "number" then
				dano = restante
			end
		end
	end

	return dano
end

--[[
════════════════════════════════════════════════════════════════
	§12.3 — CRÉDITO DE ABATE
	A tag `creator`, do jeito certo.

	⚠️ ORDEM DAS PROPRIEDADES É CRÍTICA.
	Auditando o Gear Manager, os dois TagHumanoid dele definem o
	Parent ANTES do Name e do Value (um usa Instance.new(cls, pai),
	o outro percorre a tabela com pairs(), que não tem ordem
	garantida). Quando isso acontece, quem escuta ChildAdded no
	Humanoid vê um objeto ainda chamado "Value" e vazio — e ignora.
	Aqui Name e Value vêm SEMPRE antes do Parent.
════════════════════════════════════════════════════════════════
]]

function Nucleo.marcarCredito(humanoide, jogador, duracao)
	if not humanoide or typeof(humanoide) ~= "Instance" or not humanoide:IsA("Humanoid") then
		return
	end
	if not jogador or typeof(jogador) ~= "Instance" or not jogador:IsA("Player") then
		return
	end

	-- Remove crédito anterior (sem :Destroy(), regra do projeto)
	for _, filho in ipairs(humanoide:GetChildren()) do
		if filho:IsA("ObjectValue") and filho.Name == "creator" then
			filho.Parent = nil
		end
	end

	local credito = Instance.new("ObjectValue")
	credito.Name = "creator" -- 1º
	credito.Value = jogador -- 2º
	credito.Parent = humanoide -- 3º, sempre por último

	duracao = tonumber(duracao)
	Debris:AddItem(credito, (duracao and duracao > 0) and duracao or LIMITES.CREDITO_PADRAO)

	-- Avisa o sistema de atribuição do projeto, se existir
	if _G.DamageAttribution and _G.DamageAttribution.register then
		local personagemAlvo = humanoide.Parent
		if personagemAlvo then
			pcall(_G.DamageAttribution.register, jogador, personagemAlvo)
		end
	end
end

function Nucleo.limparCredito(humanoide)
	if not humanoide or typeof(humanoide) ~= "Instance" then
		return
	end
	for _, filho in ipairs(humanoide:GetChildren()) do
		if filho:IsA("ObjectValue") and filho.Name == "creator" then
			filho.Parent = nil
		end
	end
end

--[[
════════════════════════════════════════════════════════════════
	(V2) PONTOS DE EXTENSÃO — USADOS POR SISTEMAS, NÃO POR TOOLS

	Uma Tool NUNCA registra aqui. Quem registra é sistema:
	PassiveSystemServer, sistema de fraqueza elemental, evento
	sazonal. A Tool só chama `aplicarDano` e recebe tudo pronto.
════════════════════════════════════════════════════════════════
]]

local modificadores = {} -- { {nome, funcao}, ... }
local ouvintesDano = {} -- { funcao, ... }

--[[
	Registra um ajuste de dano que depende da RELAÇÃO atacante×alvo.

	A função recebe um contexto e devolve uma CONTRIBUIÇÃO DE
	AUMENTO (número). 0.25 = +25%. Devolver 0 ou nil = sem efeito.

	contexto = {
		jogadorDono, personagemDono,
		humanoideAlvo, personagemAlvo, jogadorAlvo,
		dano,      -- dano base, antes de qualquer conta
		classe,    -- "Melee" / "Ranged" / ... ou nil
	}

	Exemplo (Frenesi):
		Nucleo.registrarModificador("Frenesi", function(ctx)
			local hum = ctx.personagemDono
				and ctx.personagemDono:FindFirstChildOfClass("Humanoid")
			if hum and hum.MaxHealth > 0
				and (hum.Health / hum.MaxHealth) <= 0.30 then
				return 0.25
			end
			return 0
		end)
]]
function Nucleo.registrarModificador(nome, funcao)
	if type(nome) ~= "string" or #nome == 0 then
		warn("[NUCLEO] registrarModificador: nome inválido")
		return function() end
	end
	if type(funcao) ~= "function" then
		warn("[NUCLEO] registrarModificador: precisa de uma função")
		return function() end
	end

	-- Substitui se já existir com o mesmo nome, pra recarregar o
	-- script do sistema não empilhar duplicata
	for indice = #modificadores, 1, -1 do
		if modificadores[indice].nome == nome then
			table.remove(modificadores, indice)
		end
	end

	local entrada = { nome = nome, funcao = funcao }
	table.insert(modificadores, entrada)

	return function()
		for indice = #modificadores, 1, -1 do
			if modificadores[indice] == entrada then
				table.remove(modificadores, indice)
				return true
			end
		end
		return false
	end
end

--[[
	Avisa DEPOIS que o dano foi aplicado, com o valor final.
	Para Vampírico, XP por dano, contadores, telemetria.

	callback(contexto, danoFinal)
]]
function Nucleo.aoAplicarDano(callback)
	if type(callback) ~= "function" then
		return function() end
	end

	table.insert(ouvintesDano, callback)

	return function()
		for indice = #ouvintesDano, 1, -1 do
			if ouvintesDano[indice] == callback then
				table.remove(ouvintesDano, indice)
				return true
			end
		end
		return false
	end
end

-- Soma a contribuição de todos os modificadores registrados.
-- Um modificador que der erro é isolado: ele não derruba o golpe.
local function somarModificadores(contexto)
	local total = 0

	for indice = 1, #modificadores do
		local entrada = modificadores[indice]
		local ok, valor = pcall(entrada.funcao, contexto)

		if not ok then
			warn(string.format("[NUCLEO] modificador '%s' deu erro: %s", entrada.nome, tostring(valor)))
		elseif type(valor) == "number" and valor == valor then
			total = total + valor
		end
	end

	return total
end

local function avisarOuvintes(contexto, danoFinal)
	for indice = 1, #ouvintesDano do
		local ok, erro = pcall(ouvintesDano[indice], contexto, danoFinal)
		if not ok then
			warn("[NUCLEO] ouvinte de dano deu erro: " .. tostring(erro))
		end
	end
end

--[[
════════════════════════════════════════════════════════════════
	§12.5 — PIPELINE DE DANO — PORTA ÚNICA

	  dano base
	    → × (1 + aumento + modificadores)  [aditivo, teto 300%]
	    → × (1 − redução do alvo)          [multiplicativo, teto 90%]
	    → − escudo do alvo                 [consome pontos, em ordem]
	    → marcarCredito(creator)
	    → Humanoid:TakeDamage(final)
	    → avisa os ouvintes (Vampírico, XP...)

	Usa TakeDamage, NUNCA Health = Health - dano: TakeDamage
	respeita ForceField nativo.
════════════════════════════════════════════════════════════════
]]

function Nucleo.aplicarDano(humanoideAlvo, dano, jogadorDono, personagemDono, ignorarReducao, classe)
	if not Nucleo.estaVivo(humanoideAlvo) then
		return 0
	end

	dano = tonumber(dano)
	if not dano or dano ~= dano or dano <= 0 then
		return 0
	end

	if classe ~= nil and not CLASSES_VALIDAS[classe] then
		classe = nil
	end

	local personagemAlvo = humanoideAlvo.Parent
	if not personagemAlvo then
		return 0
	end

	-- (V2) Contexto montado uma vez e reaproveitado
	local contexto = {
		jogadorDono = jogadorDono,
		personagemDono = personagemDono,
		humanoideAlvo = humanoideAlvo,
		personagemAlvo = personagemAlvo,
		jogadorAlvo = Players:GetPlayerFromCharacter(personagemAlvo),
		dano = dano,
		classe = classe,
	}

	-- 1) AUMENTO DO ATACANTE + MODIFICADORES DINÂMICOS
	-- Os dois entram no MESMO grupo aditivo e no mesmo teto.
	local aumento = 0
	if personagemDono then
		aumento = Nucleo.obterAumento(personagemDono, classe)
	end
	aumento = math.clamp(aumento + somarModificadores(contexto), -0.90, LIMITES.AUMENTO_MAXIMO)
	dano = dano * (1 + aumento)

	-- 2) REDUÇÃO DO ALVO
	if not ignorarReducao then
		local reducao = Nucleo.obterReducao(personagemAlvo, classe)
		dano = dano * (1 - reducao)
	end

	-- 3) ESCUDO (antes de chegar ao Humanoid — §12.5)
	if not ignorarReducao then
		dano = Nucleo.consumirEscudo(personagemAlvo, dano)
	end

	dano = math.max(LIMITES.DANO_MINIMO, dano)

	if dano <= 0 then
		return 0 -- absorvido por completo
	end

	-- 4) CRÉDITO, antes do dano (pra quem escuta Died já ter a tag)
	if jogadorDono then
		Nucleo.marcarCredito(humanoideAlvo, jogadorDono, LIMITES.CREDITO_PADRAO)
	end

	-- 5) DANO
	humanoideAlvo:TakeDamage(dano)

	-- 6) (V2) AVISA OS OUVINTES (Vampírico, XP, telemetria)
	avisarOuvintes(contexto, dano)

	return dano
end

--[[
════════════════════════════════════════════════════════════════
	§12.7 — RECARGA GLOBAL (ANTI-EXPLOIT DE CLONES)
	Tool.Enabled é por instância. Três cópias da mesma Tool na
	mochila disparam a habilidade três vezes. A recarga aqui é
	registrada no JOGADOR, por chave nomeada.

	Usa os.clock(), que é monotônico. Isto NÃO revoga a proibição
	de tick() nem substitui acumulador dt em animação (§10.11.7).
════════════════════════════════════════════════════════════════
]]

function Nucleo.recargaGlobal(jogador, chave, tempo)
	if not jogador or typeof(jogador) ~= "Instance" or not jogador:IsA("Player") then
		return false, 0
	end
	if type(chave) ~= "string" or #chave == 0 then
		return false, 0
	end

	tempo = tonumber(tempo) or 0

	registroRecarga[jogador] = registroRecarga[jogador] or {}
	local tabela = registroRecarga[jogador]

	local agora = os.clock()
	local liberaEm = tabela[chave]

	if liberaEm and agora < liberaEm then
		return false, liberaEm - agora
	end

	tabela[chave] = agora + tempo
	return true, 0
end

function Nucleo.tempoRestante(jogador, chave)
	local tabela = registroRecarga[jogador]
	if not tabela or not tabela[chave] then
		return 0
	end
	return math.max(0, tabela[chave] - os.clock())
end

function Nucleo.limparRecarga(jogador, chave)
	local tabela = registroRecarga[jogador]
	if not tabela then
		return false
	end
	if chave then
		tabela[chave] = nil
	else
		registroRecarga[jogador] = nil
	end
	return true
end

--[[
════════════════════════════════════════════════════════════════
	RAYCAST PADRONIZADO
════════════════════════════════════════════════════════════════
]]

function Nucleo.raio(origem, direcao, ignorar, ignorarAgua)
	local posicao = posicaoDe(origem)
	if not posicao or typeof(direcao) ~= "Vector3" then
		return nil
	end

	local parametros = RaycastParams.new()
	parametros.FilterType = Enum.RaycastFilterType.Exclude
	parametros.FilterDescendantsInstances = (typeof(ignorar) == "table") and ignorar or {}
	parametros.IgnoreWater = (ignorarAgua ~= false)

	return Workspace:Raycast(posicao, direcao, parametros)
end

--[[
════════════════════════════════════════════════════════════════
	§12.8 — VFX: O SERVIDOR TRANSMITE, NUNCA EMITE
	Payload é DADO, nunca Instance — mandar Instance força
	replicação e anula o ganho.
════════════════════════════════════════════════════════════════
]]

function Nucleo.transmitirVFX(remote, tipo, dados)
	if not remote or typeof(remote) ~= "Instance" or not remote:IsA("RemoteEvent") then
		warn("[NUCLEO] transmitirVFX: remote inválido")
		return false
	end

	if type(tipo) ~= "string" or #tipo == 0 then
		warn("[NUCLEO] transmitirVFX: tipo deve ser string")
		return false
	end

	-- Rejeita Instance no payload
	if type(dados) == "table" then
		for chave, valor in pairs(dados) do
			if typeof(valor) == "Instance" then
				warn(
					string.format(
						"[NUCLEO] transmitirVFX: '%s' contém Instance em '%s' — envie dados puros",
						tipo,
						tostring(chave)
					)
				)
				return false
			end
		end
	end

	remote:FireAllClients(tipo, dados)
	return true
end

--[[
════════════════════════════════════════════════════════════════
	DEPURAÇÃO
════════════════════════════════════════════════════════════════
]]

function Nucleo.inspecionar(personagem)
	local resultado = {
		reducao = Nucleo.obterReducao(personagem),
		aumento = Nucleo.obterAumento(personagem),
		escudo = Nucleo.obterEscudo(personagem),
		registrosReducao = registroReducao[personagem] and #registroReducao[personagem] or 0,
		registrosAumento = registroAumento[personagem] and #registroAumento[personagem] or 0,
		registrosEscudo = registroEscudo[personagem] and #registroEscudo[personagem] or 0,
	}

	local jogador = jogadorDe(personagem)
	resultado.jogador = jogador and jogador.Name or "NPC"
	resultado.temStatService = _G.StatService ~= nil

	-- (V2) modificadores dinâmicos ativos
	resultado.modificadores = {}
	for indice = 1, #modificadores do
		table.insert(resultado.modificadores, modificadores[indice].nome)
	end
	resultado.ouvintesDano = #ouvintesDano

	return resultado
end

_G.DebugNucleo = function(nomeJogador)
	local jogador = Players:FindFirstChild(nomeJogador)
	if not jogador or not jogador.Character then
		print("❌ Jogador ou personagem não encontrado")
		return
	end

	local dados = Nucleo.inspecionar(jogador.Character)

	print("\n========== NÚCLEO DE COMBATE V1 ==========")
	print(string.format("Jogador: %s", dados.jogador))
	print(string.format("StatService presente: %s", tostring(dados.temStatService)))
	print(string.format("Redução total: %.1f%% (%d registro(s) de Tool)", dados.reducao * 100, dados.registrosReducao))
	print(string.format("Aumento total: %.1f%% (%d registro(s) de Tool)", dados.aumento * 100, dados.registrosAumento))
	print(string.format("Escudo: %.0f pontos (%d registro(s) de Tool)", dados.escudo, dados.registrosEscudo))
	print(string.format(
		"Modificadores dinâmicos: %s",
		#dados.modificadores > 0 and table.concat(dados.modificadores, ", ") or "(nenhum)"
	))
	print(string.format("Ouvintes de dano: %d", dados.ouvintesDano))

	-- Simulação de 100 de dano
	local aumento = dados.aumento
	local reducao = dados.reducao
	print(string.format("\n100 de dano base contra este personagem:"))
	print(string.format("  como ALVO   -> %.1f (redução %.1f%%)", 100 * (1 - reducao), reducao * 100))
	print(string.format("  como DONO   -> %.1f (aumento %.1f%%)", 100 * (1 + aumento), aumento * 100))
	print("=====================================\n")
end

print("[NÚCLEO DE COMBATE V2] Carregado — porta única de dano + modificadores embutidos (REGRA 12)")

return Nucleo
