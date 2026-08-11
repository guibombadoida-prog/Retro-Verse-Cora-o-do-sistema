-- ============================================
-- AWAKENING METER SERVER V1
-- Coloque em ServerScriptService
-- Nome: "AwakeningMeterServer"
-- ============================================
-- A BARRA DE DESPERTAR — o Despertar deixa de ser um personagem
-- separado e vira uma FORMA TEMPORÁRIA do personagem normal.
--
-- COMO FUNCIONA
--   1. O jogador equipa o personagem normal, com as Tools normais.
--   2. Batendo e apanhando, a barra sobe.
--   3. Barra cheia -> as Tools normais SAEM e as do Despertar ENTRAM.
--   4. Passado o tempo da forma, as Tools voltam a ser as normais.
--   5. Começa o cooldown: durante ele a barra não sobe.
--
--   Morrer desperto encerra a forma e ZERA a barra.
--
-- POR QUE O HOOK É NO HealthChanged
-- O dano no projeto sai de vários lugares: NucleoCombate_V2,
-- StatusEffectServer, PassiveSystemServer (reverso), NPCs e Tools de
-- toolbox. Enganchar em cada um seria frágil e exigiria editar o núcleo
-- de combate. HealthChanged pega TODOS, venha de onde vier, e o
-- _G.DamageAttribution já sabe dizer quem bateu.
--
-- DEPENDE DE:
--   • _G.PlayerDataManager    (DataManager)
--   • _G.AwakeningSystem      (AwakeningSystemServer — definições)
--   • _G.DamageAttribution    (quem causou o dano)
--   • _G.GameManagerConfig    (reapplyEquippedTools — troca as Tools)
--
-- PUBLICA:
--   • _G.AwakeningMeter       (estaDesperto / getEstado / forcar)
--   • _G.DebugAwakeningMeter
--
-- ⚠️ O GameManager precisa consultar _G.AwakeningMeter.estaDesperto()
--    para decidir de qual pasta tirar as Tools. Sem essa linha lá, a
--    barra enche e nada acontece.
-- ============================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

repeat
	task.wait()
until _G.PlayerDataManager and _G.AwakeningSystem

-- =====================================
-- CONFIGURAÇÃO PADRÃO
-- =====================================

-- Cada Despertar pode sobrescrever isto pela definição do admin
-- (campos medidorMax, duracao, cooldown, ganhoDano, ganhoRecebido).
local CONFIG = {
	MEDIDOR_MAX = 100,

	-- Quanto de barra cada ponto de dano vale.
	-- Bater rende mais do que apanhar: quem foge de briga não desperta.
	GANHO_POR_DANO_CAUSADO = 0.35,
	GANHO_POR_DANO_RECEBIDO = 0.20,

	DURACAO = 20, -- segundos desperto
	COOLDOWN = 45, -- segundos sem poder encher

	-- Trava anti-abuso: dano de um golpe só não pode encher a barra
	-- inteira. Sem isso, uma Tool com dano altíssimo desperta de
	-- primeira e o medidor perde a função.
	GANHO_MAXIMO_POR_GOLPE = 25,

	INTERVALO_SYNC = 0.25, -- com que frequência o cliente é avisado
}

-- =====================================
-- REMOTE
-- =====================================

local remotes = ReplicatedStorage:FindFirstChild("Remotes")
if not remotes then
	remotes = Instance.new("Folder")
	remotes.Name = "Remotes"
	remotes.Parent = ReplicatedStorage
end

local function ensureRemote(name, className)
	local remote = remotes:FindFirstChild(name)
	if remote and not remote:IsA(className) then
		remote.Parent = nil
		remote = nil
	end
	if not remote then
		remote = Instance.new(className)
		remote.Name = name
		remote.Parent = remotes
	end
	return remote
end

local meterUpdate = ensureRemote("AwakeningMeterUpdate", "RemoteEvent")

-- =====================================
-- ESTADO
-- =====================================

-- estado[player] = {
--   valor, max, desperto, terminaEm, cooldownAte, personagem, sujo
-- }
local estado = {}

local function novoEstado()
	return {
		valor = 0,
		max = CONFIG.MEDIDOR_MAX,
		desperto = false,
		terminaEm = 0,
		cooldownAte = 0,
		personagem = nil,
		sujo = true,
	}
end

local function getEstado(player)
	if not estado[player] then
		estado[player] = novoEstado()
	end
	return estado[player]
end

-- =====================================
-- DEFINIÇÃO DO DESPERTAR DO PERSONAGEM EQUIPADO
-- =====================================

local function personagemEquipado(player)
	local dados = _G.PlayerDataManager.getPlayerData(player)
	return dados and dados.equippedCharacter or nil
end

-- Devolve a definição do Despertar SE o personagem equipado tiver uma
-- e o jogador puder usá-la. Senão devolve nil — e sem definição a barra
-- simplesmente não existe para aquele personagem.
local function definicaoAtiva(player)
	local nome = personagemEquipado(player)
	if not nome then
		return nil
	end

	local def = _G.AwakeningSystem.getDefinition(nome)
	if not def then
		return nil
	end

	-- (V5 do AwakeningSystemServer) O Badge virou OPCIONAL: se o admin
	-- configurou um, ele gateia; se deixou em branco, o Despertar é de
	-- quem tem o personagem.
	local badgeId = tonumber(def.badgeId)
	if badgeId and badgeId > 0 then
		local ok, tem = pcall(function()
			return game:GetService("BadgeService"):UserHasBadgeAsync(player.UserId, badgeId)
		end)
		if not ok or not tem then
			return nil
		end
	end

	return def, nome
end

local function configDe(def, chave, padrao)
	local v = def and tonumber(def[chave])
	if v and v > 0 then
		return v
	end
	return padrao
end

-- =====================================
-- SYNC COM O CLIENTE
-- =====================================

local function marcarSujo(player)
	local e = estado[player]
	if e then
		e.sujo = true
	end
end

task.spawn(function()
	while true do
		task.wait(CONFIG.INTERVALO_SYNC)
		local agora = os.clock()

		for _, player in ipairs(Players:GetPlayers()) do
			local e = estado[player]
			if e and e.sujo then
				e.sujo = false
				meterUpdate:FireClient(player, {
					valor = e.valor,
					max = e.max,
					desperto = e.desperto,
					restante = e.desperto and math.max(0, e.terminaEm - agora) or 0,
					cooldown = math.max(0, e.cooldownAte - agora),
					ativo = e.personagem ~= nil,
				})
			end
		end
	end
end)

-- =====================================
-- TROCA DE FORMA
-- =====================================

-- O GameManager é quem monta a backpack. Aqui só avisamos que o estado
-- mudou e pedimos que ele remonte — assim a lógica de Tools continua
-- num lugar só.
local function remontarTools(player)
	if _G.GameManagerConfig and _G.GameManagerConfig.reapplyEquippedTools then
		local ok = pcall(_G.GameManagerConfig.reapplyEquippedTools, player)
		if not ok then
			warn("[AWAKEN METER V1] ⚠️ Falha ao remontar as Tools de " .. player.Name)
		end
	else
		warn("[AWAKEN METER V1] ⚠️ _G.GameManagerConfig.reapplyEquippedTools ausente")
	end
end

local function encerrarDespertar(player, zerarBarra)
	local e = estado[player]
	if not e or not e.desperto then
		return
	end

	local def = definicaoAtiva(player)

	e.desperto = false
	e.terminaEm = 0
	e.valor = 0
	e.cooldownAte = os.clock() + configDe(def, "cooldown", CONFIG.COOLDOWN)
	e.sujo = true

	if zerarBarra then
		e.valor = 0
	end

	remontarTools(player)
	print(string.format("[AWAKEN METER V1] ⏹️ %s voltou ao normal", player.Name))
end

local function dispararDespertar(player, def)
	local e = getEstado(player)
	if e.desperto then
		return
	end

	local duracao = configDe(def, "duracao", CONFIG.DURACAO)

	e.desperto = true
	e.valor = e.max
	e.terminaEm = os.clock() + duracao
	e.sujo = true

	-- A troca de Tools acontece aqui: o GameManager vê estaDesperto()
	-- verdadeiro e passa a tirar as Tools de characterFolder.AwakenedForm
	remontarTools(player)

	print(
		string.format(
			"[AWAKEN METER V1] ⚡ %s DESPERTOU (%s) por %ds",
			player.Name,
			tostring(def.displayName or "?"),
			duracao
		)
	)

	task.delay(duracao, function()
		local atual = estado[player]
		-- Só encerra se for ESTE despertar: se o jogador morreu e
		-- despertou de novo no meio, este timer não pode cortar o novo.
		if atual and atual.desperto and os.clock() >= atual.terminaEm - 0.1 then
			encerrarDespertar(player, true)
		end
	end)
end

-- =====================================
-- GANHO DE BARRA
-- =====================================

local function encher(player, quantidade)
	if quantidade <= 0 then
		return
	end

	local def, nome = definicaoAtiva(player)
	if not def then
		return -- personagem sem Despertar: barra não existe
	end

	local e = getEstado(player)
	e.personagem = nome
	e.max = configDe(def, "medidorMax", CONFIG.MEDIDOR_MAX)

	if e.desperto then
		return -- desperto não enche
	end

	local agora = os.clock()
	if agora < e.cooldownAte then
		return -- em cooldown
	end

	local ganho = math.min(quantidade, CONFIG.GANHO_MAXIMO_POR_GOLPE)
	e.valor = math.clamp(e.valor + ganho, 0, e.max)
	e.sujo = true

	if e.valor >= e.max then
		dispararDespertar(player, def)
	end
end

-- =====================================
-- HOOK DE DANO
-- =====================================

-- Um HealthChanged por personagem. A queda de vida vira ganho de barra
-- para quem apanhou e para quem bateu.
local function acompanharPersonagem(player, character)
	local humanoid = character:WaitForChild("Humanoid", 10)
	if not humanoid then
		return
	end

	local vidaAnterior = humanoid.Health

	humanoid.HealthChanged:Connect(function(vidaAtual)
		local perda = vidaAnterior - vidaAtual
		vidaAnterior = vidaAtual

		-- Cura ou reset de respawn não enchem nada
		if perda <= 0 then
			return
		end

		-- Quem apanhou
		local def = definicaoAtiva(player)
		if def then
			encher(player, perda * configDe(def, "ganhoRecebido", CONFIG.GANHO_POR_DANO_RECEBIDO))
		end

		-- Quem bateu
		if _G.DamageAttribution and _G.DamageAttribution.getAttacker then
			local ok, atacante = pcall(_G.DamageAttribution.getAttacker, character)
			if ok and atacante and atacante ~= player and atacante.Parent then
				local defA = definicaoAtiva(atacante)
				if defA then
					encher(atacante, perda * configDe(defA, "ganhoDano", CONFIG.GANHO_POR_DANO_CAUSADO))
				end
			end
		end
	end)

	humanoid.Died:Connect(function()
		local e = estado[player]
		if not e then
			return
		end

		-- Morreu desperto: acaba a forma e a barra ZERA (decisão do
		-- projeto). O cooldown corre normalmente.
		if e.desperto then
			e.desperto = false
			e.terminaEm = 0
			local def = definicaoAtiva(player)
			e.cooldownAte = os.clock() + configDe(def, "cooldown", CONFIG.COOLDOWN)
			print(string.format("[AWAKEN METER V1] 💀 %s morreu desperto — forma perdida", player.Name))
		end

		e.valor = 0
		e.sujo = true
	end)
end

-- =====================================
-- CICLO DO JOGADOR
-- =====================================

local function entrou(player)
	estado[player] = novoEstado()

	player.CharacterAdded:Connect(function(character)
		local e = getEstado(player)
		e.desperto = false
		e.terminaEm = 0
		e.valor = 0
		e.sujo = true

		task.spawn(acompanharPersonagem, player, character)
	end)

	if player.Character then
		task.spawn(acompanharPersonagem, player, player.Character)
	end
end

Players.PlayerAdded:Connect(entrou)
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(entrou, player)
end

Players.PlayerRemoving:Connect(function(player)
	estado[player] = nil
end)

-- Trocou de personagem: a barra é por personagem, então zera
task.spawn(function()
	while true do
		task.wait(1)
		for _, player in ipairs(Players:GetPlayers()) do
			local e = estado[player]
			if e then
				local atual = personagemEquipado(player)
				if atual ~= e.personagem then
					if e.desperto then
						encerrarDespertar(player, true)
					end
					e.personagem = atual
					e.valor = 0
					e.sujo = true
				end
			end
		end
	end
end)

-- =====================================
-- API GLOBAL
-- =====================================

_G.AwakeningMeter = {
	CONFIG = CONFIG,

	-- É ISTO que o GameManager consulta para saber de qual pasta tirar
	-- as Tools (normal ou AwakenedForm).
	estaDesperto = function(player)
		local e = estado[player]
		return e ~= nil and e.desperto == true
	end,

	getEstado = function(player)
		local e = estado[player]
		if not e then
			return nil
		end
		local agora = os.clock()
		return {
			valor = e.valor,
			max = e.max,
			desperto = e.desperto,
			restante = e.desperto and math.max(0, e.terminaEm - agora) or 0,
			cooldown = math.max(0, e.cooldownAte - agora),
			personagem = e.personagem,
		}
	end,

	-- Para teste no console do servidor
    forcar = function(player)
		local def = definicaoAtiva(player)
		if not def then
			return false, "Personagem equipado não tem Despertar (ou falta o Badge)."
		end
		dispararDespertar(player, def)
		return true
	end,

	encerrar = function(player)
		encerrarDespertar(player, true)
		return true
	end,
}

_G.DebugAwakeningMeter = function()
	print("\n========== DEBUG AWAKENING METER V1 ==========")
	for _, player in ipairs(Players:GetPlayers()) do
		local e = estado[player]
		if not e then
			print(string.format("  %s | sem estado", player.Name))
		else
			local agora = os.clock()
			print(
				string.format(
					"  %s | %s | barra %.1f/%.0f | %s | cooldown %.1fs",
					player.Name,
					tostring(e.personagem or "sem personagem"),
					e.valor,
					e.max,
					e.desperto and string.format("DESPERTO (%.1fs)", math.max(0, e.terminaEm - agora)) or "normal",
					math.max(0, e.cooldownAte - agora)
				)
			)
		end
	end
	print("=============================================\n")
end

print("[AWAKEN METER V1] Barra de Despertar carregada")
