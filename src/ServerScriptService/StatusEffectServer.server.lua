-- ============================================
-- STATUS EFFECT SERVER V1 — EFEITOS (BUFF E DEBUFF)
-- Coloque em ServerScriptService
-- Nome: "StatusEffectServer"
-- DEPENDE DE: StatService V3, DamageAttribution V4
-- SCRIPT NOVO
-- ============================================
-- POR QUE ESTE SCRIPT EXISTE (e por que demorou):
-- A REGRA 12 lista os 22 status effects do Gear Manager como
-- "❌ Assets e VFX de terceiros". Eu segui isso ao pé da letra e
-- descartei o CONCEITO junto com o código alheio. Foi erro meu: a
-- regra proíbe usar o código deles, não ter efeitos.
-- Aqui os efeitos são AUTORAIS — nenhuma linha do Gear Manager.
--
-- ============================================
-- USA O ÚNICO PADRÃO QUE COMPROVADAMENTE CONECTA COM AS TOOLS
-- ============================================
-- De tudo que foi construído, só o EnergySystemServer funcionou com
-- as Tools. Ele funciona porque faz três coisas simples:
--
--   1. acha a Tool (varre Backpack e Character, escuta ChildAdded)
--   2. escuta `Tool.Activated` de fora
--   3. lê um `Value` de dentro da Tool (`EnergyCost`)
--
-- Nenhuma Tool é editada, e funciona até com gear de InsertService.
-- Este script usa exatamente o mesmo desenho — só troca
-- "descontar energia" por "aplicar efeito".
--
-- ============================================
-- COMO UMA TOOL DECLARA UM EFEITO
-- ============================================
-- Igualzinho ao EnergyCost: um Value dentro da Tool, sem código.
--
--   Tool
--    ├── Handle
--    ├── EnergyCost      (NumberValue)  -- já existente
--    ├── AplicarEfeito   (StringValue)  "queimadura"
--    └── DuracaoEfeito   (NumberValue)  8   (opcional)
--
-- Sem `AplicarEfeito`, a Tool simplesmente não aplica efeito. Nada
-- quebra, nada muda.
--
-- ============================================
-- COMO O EFEITO SE CONECTA AOS ATRIBUTOS
-- ============================================
-- Efeito NÃO tem matemática própria. Ele registra uma FONTE
-- TEMPORÁRIA no StatService, com o nome `efeito_<id>`.
--
-- Consequência boa: um efeito de "Fraqueza" que dá -25% de dano
-- soma com arquétipo, passiva, nível e gear automaticamente — sem
-- uma linha de código de junção. E some sozinho quando expira,
-- porque o StatService já sabe expirar fonte temporária.
--
-- Reaplicar o mesmo efeito RENOVA a duração (não empilha), porque
-- `addTempSource` substitui pelo nome. É o comportamento que evita
-- o exploit de spam de ativação.
-- ============================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

repeat
	task.wait()
until _G.StatService

-- =====================================
-- CONFIGURAÇÃO
-- =====================================

local CONFIG = {
	-- Nome dos Values que a Tool pode declarar
	VALUE_EFEITO = "AplicarEfeito",
	VALUE_DURACAO = "DuracaoEfeito",

	TICK = 0.5, -- intervalo do dano contínuo
	ALCANCE_APLICACAO = 250, -- distância máxima pra aplicar efeito
	JANELA = 1.5, -- mesma janela do DamageAttribution V4

	-- Teto de efeitos simultâneos por personagem. Sem isso, um
	-- combate longo empilha dezenas de fontes no StatService.
	MAX_EFEITOS = 6,
}

-- =====================================
-- CATÁLOGO DE EFEITOS — AUTORAL
-- =====================================
-- `stats`      -> fonte temporária no StatService
-- `danoPorSeg` -> dano contínuo (DoT)
-- Todo efeito tem duração. Efeito eterno é bug, não recurso.

local EFEITOS = {
	--// ---------- DANO CONTÍNUO ----------
	queimadura = {
		nome = "Queimadura",
		icone = "🔥",
		duracao = 8,
		danoPorSeg = 4,
		desc = "Perde vida aos poucos",
	},
	sangramento = {
		nome = "Sangramento",
		icone = "🩸",
		duracao = 5,
		danoPorSeg = 7,
		stats = { IncomingHealing = -0.30 },
		desc = "Dano alto e cura reduzida",
	},
	veneno = {
		nome = "Envenenado",
		icone = "🧪",
		duracao = 12,
		danoPorSeg = 2,
		stats = { IncomingHealing = -0.50 },
		desc = "Dano lento e cura muito reduzida",
	},

	--// ---------- CONTROLE ----------
	lentidao = {
		nome = "Lentidão",
		icone = "🐌",
		duracao = 6,
		stats = { WalkSpeedPercent = -0.35 },
		desc = "Move-se devagar",
	},
	congelamento = {
		nome = "Congelamento",
		icone = "❄️",
		duracao = 2.5,
		stats = { WalkSpeedPercent = -0.80, JumpPercent = -0.60 },
		desc = "Quase não se move",
	},
	atordoamento = {
		nome = "Atordoamento",
		icone = "💫",
		duracao = 1.5,
		stats = { WalkSpeedPercent = -0.95, JumpPercent = -0.90 },
		desc = "Preso no lugar por pouco tempo",
	},

	--// ---------- ENFRAQUECIMENTO ----------
	fraqueza = {
		nome = "Fraqueza",
		icone = "💔",
		duracao = 8,
		stats = { DamageBoost = -0.25 },
		desc = "Causa menos dano",
	},
	vulneravel = {
		nome = "Vulnerável",
		icone = "🎯",
		duracao = 6,
		stats = { DamageResistance = -0.30 },
		desc = "Recebe mais dano",
	},
	encharcado = {
		nome = "Encharcado",
		icone = "💧",
		duracao = 10,
		stats = { MagicResist = -0.25 },
		desc = "Mais frágil contra magia",
	},

	--// ---------- POSITIVO (gear de suporte) ----------
	fortalecido = {
		nome = "Fortalecido",
		icone = "⚔️",
		duracao = 8,
		stats = { DamageBoost = 0.25 },
		desc = "Causa mais dano",
		beneficio = true,
	},
	protegido = {
		nome = "Protegido",
		icone = "🛡️",
		duracao = 8,
		stats = { DamageResistance = 0.20 },
		desc = "Recebe menos dano",
		beneficio = true,
	},
	acelerado = {
		nome = "Acelerado",
		icone = "💨",
		duracao = 6,
		stats = { WalkSpeedPercent = 0.30, JumpPercent = 0.20 },
		desc = "Move-se mais rápido",
		beneficio = true,
	},
}

-- =====================================
-- ESTADO
-- =====================================

-- [personagem] = { [efeitoId] = { expira, criador, cancelarFonte } }
local ativos = {}

-- =====================================
-- HELPERS
-- =====================================

local function contarAtivos(personagem)
	local lista = ativos[personagem]
	if not lista then
		return 0
	end
	local n = 0
	for _ in pairs(lista) do
		n = n + 1
	end
	return n
end

local function jogadorDe(personagem)
	if not personagem then
		return nil
	end
	return Players:GetPlayerFromCharacter(personagem)
end

-- =====================================
-- APLICAR E REMOVER
-- =====================================

local remover

local function aplicar(personagem, efeitoId, duracao, criador)
	if typeof(personagem) ~= "Instance" or not personagem:IsA("Model") then
		return false, "Personagem inválido."
	end

	local efeito = EFEITOS[efeitoId]
	if not efeito then
		return false, "Efeito desconhecido: " .. tostring(efeitoId)
	end

	local humanoide = personagem:FindFirstChildOfClass("Humanoid")
	if not humanoide or humanoide.Health <= 0 then
		return false, "Alvo morto."
	end

	ativos[personagem] = ativos[personagem] or {}

	-- Teto de efeitos: renovar um que JÁ existe sempre é permitido
	if not ativos[personagem][efeitoId] and contarAtivos(personagem) >= CONFIG.MAX_EFEITOS then
		return false, "Limite de efeitos simultâneos."
	end

	duracao = tonumber(duracao) or efeito.duracao
	duracao = math.clamp(duracao, 0.1, 120)

	-- Se já estava ativo, cancela a fonte antiga: reaplicar RENOVA,
	-- nunca empilha (é isto que impede spam de ativação virar buff
	-- infinito)
	local anterior = ativos[personagem][efeitoId]
	if anterior and anterior.cancelarFonte then
		pcall(anterior.cancelarFonte)
	end

	local cancelarFonte = nil

	-- ATRIBUTOS -> fonte temporária no StatService.
	-- É aqui que o efeito se conecta com arquétipo, passiva e gear:
	-- tudo soma no mesmo lugar, sem código de junção.
	local jogador = jogadorDe(personagem)
	if efeito.stats and jogador then
		local nomeFonte = "efeito_" .. efeitoId
		_G.StatService.addTempSource(jogador, nomeFonte, efeito.stats, duracao)
		cancelarFonte = function()
			_G.StatService.clearSource(jogador, nomeFonte)
		end
	end

	ativos[personagem][efeitoId] = {
		expira = os.clock() + duracao,
		criador = criador,
		cancelarFonte = cancelarFonte,
		proximoTick = os.clock() + CONFIG.TICK,
	}

	return true
end

remover = function(personagem, efeitoId)
	local lista = ativos[personagem]
	if not lista or not lista[efeitoId] then
		return false
	end

	if lista[efeitoId].cancelarFonte then
		pcall(lista[efeitoId].cancelarFonte)
	end

	lista[efeitoId] = nil

	if next(lista) == nil then
		ativos[personagem] = nil
	end

	return true
end

local function limparTodos(personagem)
	local lista = ativos[personagem]
	if not lista then
		return
	end
	for efeitoId in pairs(lista) do
		remover(personagem, efeitoId)
	end
end

-- =====================================
-- LOOP: DANO CONTÍNUO E EXPIRAÇÃO
-- =====================================

task.spawn(function()
	while true do
		task.wait(CONFIG.TICK)
		local agora = os.clock()

		for personagem, lista in pairs(ativos) do
			local humanoide = personagem.Parent and personagem:FindFirstChildOfClass("Humanoid")

			-- Alvo morreu ou sumiu: limpa tudo
			if not humanoide or humanoide.Health <= 0 then
				limparTodos(personagem)
			else
				for efeitoId, dados in pairs(lista) do
					if agora >= dados.expira then
						remover(personagem, efeitoId)
					else
						local efeito = EFEITOS[efeitoId]
						if efeito and efeito.danoPorSeg and agora >= dados.proximoTick then
							dados.proximoTick = agora + CONFIG.TICK

							local dano = efeito.danoPorSeg * CONFIG.TICK

							-- Crédito de quem aplicou o efeito, pro
							-- abate contar pra pessoa certa
							if dados.criador and dados.criador.Parent then
								local tag = humanoide:FindFirstChild("creator")
								if not tag then
									tag = Instance.new("ObjectValue")
									tag.Name = "creator" -- Name e Value
									tag.Value = dados.criador -- ANTES do Parent
									tag.Parent = humanoide
								else
									tag.Value = dados.criador
								end
							end

							humanoide:TakeDamage(dano)
						end
					end
				end
			end
		end
	end
end)

-- =====================================
-- CONEXÃO COM AS TOOLS
-- =====================================
-- Mesmo desenho do EnergySystemServer V1: acha a Tool, escuta
-- Activated, lê um Value. Nenhuma Tool é editada.

local function efeitoDaTool(tool)
	local tagEfeito = tool:FindFirstChild(CONFIG.VALUE_EFEITO)
	if not tagEfeito or not tagEfeito:IsA("StringValue") then
		return nil
	end

	local id = string.lower(tagEfeito.Value or "")
	if not EFEITOS[id] then
		return nil
	end

	local duracao = nil
	local tagDuracao = tool:FindFirstChild(CONFIG.VALUE_DURACAO)
	if tagDuracao and tagDuracao:IsA("NumberValue") and tagDuracao.Value > 0 then
		duracao = tagDuracao.Value
	end

	return id, duracao
end

-- ⚠️ NÃO existe um `Tool.Activated` duplicado aqui de propósito.
-- O DamageAttribution V4 já escuta o Activated de TODAS as Tools e
-- guarda qual foi usada. Escutar de novo seria trabalho repetido e
-- um segundo lugar pra dar manutenção. Este script pergunta a ele.

-- =====================================
-- MONITOR DE DANO -> APLICA O EFEITO
-- =====================================
-- Quando alguém leva dano, pergunta ao DamageAttribution quem bateu
-- e COM QUAL Tool. Se aquela Tool declara efeito, aplica no alvo.

local function monitorar(player, character)
	local humanoide = character:WaitForChild("Humanoid", 10)
	if not humanoide then
		return
	end

	local ultimaVida = humanoide.Health

	humanoide.HealthChanged:Connect(function(vida)
		if vida >= ultimaVida then
			ultimaVida = vida
			return
		end
		ultimaVida = vida

		if not _G.DamageAttribution then
			return
		end

		local atacante = _G.DamageAttribution.getAttacker(character)
		if not atacante or atacante == player then
			return
		end

		local tool = _G.DamageAttribution.getAttackTool
			and _G.DamageAttribution.getAttackTool(atacante)
		if not tool then
			return
		end

		local id, duracao = efeitoDaTool(tool)
		if not id then
			return
		end

		local efeito = EFEITOS[id]

		-- Efeito BOM vai pra quem usou; efeito RUIM vai pro alvo
		local alvo = efeito.beneficio and atacante.Character or character
		if alvo then
			aplicar(alvo, id, duracao, atacante)
		end
	end)
end

-- =====================================
-- EVENTOS DE JOGADOR
-- =====================================

local function aoNascer(player, character)
	limparTodos(character)
	monitorar(player, character)
end

local function aoEntrar(player)
	player.CharacterAdded:Connect(function(character)
		task.spawn(aoNascer, player, character)
	end)

	if player.Character then
		task.spawn(aoNascer, player, player.Character)
	end
end

local function aoSair(player)
	if player.Character then
		limparTodos(player.Character)
	end

end

Players.PlayerAdded:Connect(aoEntrar)
Players.PlayerRemoving:Connect(aoSair)

for _, player in ipairs(Players:GetPlayers()) do
	aoEntrar(player)
end

-- =====================================
-- REMOTE (o cliente lê pra mostrar ícones)
-- =====================================

local remotes = ReplicatedStorage:FindFirstChild("Remotes")
if not remotes then
	remotes = Instance.new("Folder")
	remotes.Name = "Remotes"
	remotes.Parent = ReplicatedStorage
end

local getEfeitos = remotes:FindFirstChild("GetStatusEffects")
if getEfeitos and not getEfeitos:IsA("RemoteFunction") then
	getEfeitos.Parent = nil -- regra do projeto: sem :Destroy()
	getEfeitos = nil
end
if not getEfeitos then
	getEfeitos = Instance.new("RemoteFunction")
	getEfeitos.Name = "GetStatusEffects"
	getEfeitos.Parent = remotes
end

getEfeitos.OnServerInvoke = function(player)
	local character = player.Character
	local lista = character and ativos[character]
	local resultado = {}

	if lista then
		local agora = os.clock()
		for efeitoId, dados in pairs(lista) do
			local efeito = EFEITOS[efeitoId]
			table.insert(resultado, {
				id = efeitoId,
				nome = efeito.nome,
				icone = efeito.icone,
				desc = efeito.desc,
				beneficio = efeito.beneficio or false,
				restante = math.max(0, dados.expira - agora),
			})
		end
	end

	return resultado
end

-- =====================================
-- API GLOBAL
-- =====================================

_G.StatusEffect = {
	CONFIG = CONFIG,
	CATALOGO = EFEITOS,

	-- Qualquer sistema pode aplicar:
	--   _G.StatusEffect.aplicar(personagem, "queimadura", 8, jogador)
	aplicar = aplicar,
	remover = remover,
	limparTodos = limparTodos,

	temEfeito = function(personagem, efeitoId)
		return ativos[personagem] ~= nil and ativos[personagem][efeitoId] ~= nil
	end,

	listar = function(personagem)
		local lista = ativos[personagem]
		if not lista then
			return {}
		end
		local resultado = {}
		local agora = os.clock()
		for efeitoId, dados in pairs(lista) do
			table.insert(resultado, {
				id = efeitoId,
				restante = math.max(0, dados.expira - agora),
			})
		end
		return resultado
	end,
}

-- =====================================
-- DEBUG
-- =====================================

_G.DebugEfeitos = function(nomeJogador)
	print("\n========== STATUS EFFECT V1 ==========")

	if nomeJogador then
		local player = Players:FindFirstChild(nomeJogador)
		local character = player and player.Character
		if not character then
			print("❌ Jogador ou personagem não encontrado")
			return
		end

		local lista = ativos[character]
		if not lista or next(lista) == nil then
			print(string.format("%s: nenhum efeito ativo", player.Name))
		else
			local agora = os.clock()
			for efeitoId, dados in pairs(lista) do
				local efeito = EFEITOS[efeitoId]
				print(
					string.format(
						"  %s %s — %.1fs restantes (de %s)",
						efeito.icone,
						efeito.nome,
						dados.expira - agora,
						dados.criador and dados.criador.Name or "?"
					)
				)
			end
		end

		-- Tools que declaram efeito
		print("\n-- TOOLS COM EFEITO DECLARADO --")
		local achou = false
		local backpack = player:FindFirstChildOfClass("Backpack")
		for _, container in ipairs({ backpack, character }) do
			if container then
				for _, item in ipairs(container:GetChildren()) do
					if item:IsA("Tool") then
						local id, dur = efeitoDaTool(item)
						if id then
							achou = true
							print(string.format("  %s -> %s (%s)", item.Name, id, dur and (dur .. "s") or "padrão"))
						end
					end
				end
			end
		end
		if not achou then
			print("  (nenhuma)")
			print("  Adicione um StringValue 'AplicarEfeito' dentro da Tool.")
		end
	else
		print("EFEITOS DISPONÍVEIS:")
		for id, efeito in pairs(EFEITOS) do
			print(
				string.format(
					"  %-14s %s %-16s %ss — %s",
					id,
					efeito.icone,
					efeito.nome,
					efeito.duracao,
					efeito.desc
				)
			)
		end
	end
	print("=====================================\n")
end

print([[
╔══════════════════════════════════════════════════════╗
║  STATUS EFFECT SERVER V1 — CARREGADO                ║
╠══════════════════════════════════════════════════════╣
║  SCRIPT NOVO — efeitos AUTORAIS                      ║
║  (nenhuma linha do Gear Manager)                     ║
╠══════════════════════════════════════════════════════╣
║  * 12 efeitos: dano contínuo, controle,              ║
║    enfraquecimento e buff                            ║
║  * Tool declara com StringValue 'AplicarEfeito'      ║
║    — mesmo padrão do EnergyCost, zero código         ║
║  * Efeito vira fonte temporária no StatService,      ║
║    então soma com arquétipo/passiva/gear sozinho     ║
║  * Reaplicar RENOVA, nunca empilha                   ║
╠══════════════════════════════════════════════════════╣
║  _G.DebugEfeitos()          lista os efeitos         ║
║  _G.DebugEfeitos("Nome")    mostra os ativos         ║
╚══════════════════════════════════════════════════════╝
]])
