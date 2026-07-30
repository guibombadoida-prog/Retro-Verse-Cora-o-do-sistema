-- ============================================
-- SISTEMA DE RECOMPENSAS DIÁRIAS - SERVIDOR V4
-- (V4) ALTERAÇÕES: wait()/spawn() -> task.wait()/task.spawn() (conformidade)
-- Coloque em ServerScriptService
-- Nome: "DailyRewardsServer"
-- SUBSTITUI: DailyRewardsServer V2
-- ============================================
-- NOVIDADES V3:
-- • Sistema de Missões Diárias (3 missões por dia)
-- • Recompensas Progressivas (aumentam com streak)
-- • Bônus de Final de Semana (recompensas dobradas)
-- • Sistema de Recuperação (pode recuperar 1 dia perdido)
-- • Logs detalhados para debug
-- • Notificações automáticas aos jogadores
-- • Sistema de estatísticas melhorado
-- ============================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")

-- DataStore para recompensas diárias
local dailyRewardsStore = DataStoreService:GetDataStore("DailyRewardsDataV3_Enhanced")

-- Aguardar sistema de dados
repeat
	task.wait()
until _G.PlayerDataManager

-- =====================================
-- CRIAR REMOTES
-- =====================================

local remotes = ReplicatedStorage:WaitForChild("Remotes")

local function getOrCreateRemote(name, remoteType)
	local remote = remotes:FindFirstChild(name)
	if not remote then
		if remoteType == "Function" then
			remote = Instance.new("RemoteFunction")
		else
			remote = Instance.new("RemoteEvent")
		end
		remote.Name = name
		remote.Parent = remotes
		print("[DAILY V3] ✓ Remote criado: " .. name)
	end
	return remote
end

local claimDailyReward = getOrCreateRemote("ClaimDailyReward", "Function")
local getDailyRewardStatus = getOrCreateRemote("GetDailyRewardStatus", "Function")
-- ClaimMissionReward/GetMissionStatus pertencem ao MissionSystemServer (nao criar aqui)
local recoverLostDay = getOrCreateRemote("RecoverLostDay", "Function")

-- =====================================
-- CONFIGURAÇÃO DAS RECOMPENSAS (6 DIAS)
-- =====================================

local dailyRewards = {
	{ day = 1, coins = 20, bounty = 3, bonus = nil, description = "Iniciante" },
	{ day = 2, coins = 40, bounty = 10, bonus = nil, description = "Dedicado" },
	{ day = 3, coins = 70, bounty = 25, bonus = nil, description = "Persistente" },
	{ day = 4, coins = 90, bounty = 31, bonus = nil, description = "Veterano" },
	{ day = 5, coins = 100, bounty = 40, bonus = "2x Coins por 1 hora", description = "Elite" },
	{
		day = 6,
		coins = 110,
		bounty = 70,
		bonus = "Personagem Exclusivo Temporário",
		description = "Lendário",
	},
}

-- =====================================
-- SISTEMA DE MISSÕES DIÁRIAS
-- =====================================

local dailyMissions = {
	{
		id = "kills",
		name = "Elimine 5 jogadores",
		description = "Elimine 5 jogadores em combate",
		target = 5,
		reward = { coins = 50, bounty = 10 },
		icon = "⚔️",
	},
	{
		id = "coins",
		name = "Colete 500 moedas",
		description = "Acumule 500 moedas",
		target = 500,
		reward = { coins = 100, bounty = 5 },
		icon = "💰",
	},
	{
		id = "playtime",
		name = "Jogue por 30 minutos",
		description = "Passe 30 minutos online",
		target = 1800, -- segundos
		reward = { coins = 75, bounty = 15 },
		icon = "⏰",
	},
}

-- Cache de dados dos jogadores
local playerDailyData = {}
local playerMissionProgress = {}

-- =====================================
-- FUNÇÕES AUXILIARES
-- =====================================

local function getDayTimestamp()
	local date = os.date("*t")
	date.hour = 0
	date.min = 0
	date.sec = 0
	return os.time(date)
end

local function isWeekend()
	local date = os.date("*t")
	return date.wday == 1 or date.wday == 7 -- Domingo ou Sábado
end

local function serializeData(data)
	local cleanData = {
		lastClaim = tonumber(data.lastClaim) or 0,
		currentStreak = tonumber(data.currentStreak) or 0,
		totalDaysClaimed = tonumber(data.totalDaysClaimed) or 0,
		bonusActive = data.bonusActive and tostring(data.bonusActive) or "",
		bonusExpiry = tonumber(data.bonusExpiry) or 0,
		canRecoverDay = data.canRecoverDay and true or false,
		lastRecoveryUse = tonumber(data.lastRecoveryUse) or 0,
		missionsCompleted = tonumber(data.missionsCompleted) or 0,
	}

	return cleanData
end

local function deserializeData(data)
	if not data then
		return nil
	end

	return {
		lastClaim = tonumber(data.lastClaim) or 0,
		currentStreak = tonumber(data.currentStreak) or 0,
		totalDaysClaimed = tonumber(data.totalDaysClaimed) or 0,
		bonusActive = (data.bonusActive ~= "" and data.bonusActive) or nil,
		bonusExpiry = tonumber(data.bonusExpiry) or 0,
		canRecoverDay = data.canRecoverDay or false,
		lastRecoveryUse = tonumber(data.lastRecoveryUse) or 0,
		missionsCompleted = tonumber(data.missionsCompleted) or 0,
	}
end

-- =====================================
-- CARREGAR/SALVAR DADOS
-- =====================================

local function loadDailyData(player)
	local userId = tostring(player.UserId)
	local success, data = pcall(function()
		return dailyRewardsStore:GetAsync(userId)
	end)

	if success and data then
		playerDailyData[player] = deserializeData(data)
		print(
			string.format(
				"[DAILY V3] ✓ Dados carregados: %s (Streak: %d)",
				player.Name,
				playerDailyData[player].currentStreak
			)
		)
	else
		playerDailyData[player] = {
			lastClaim = 0,
			currentStreak = 0,
			totalDaysClaimed = 0,
			bonusActive = nil,
			bonusExpiry = 0,
			canRecoverDay = false,
			lastRecoveryUse = 0,
			missionsCompleted = 0,
		}
		print(string.format("[DAILY V3] ✓ Dados padrão criados: %s", player.Name))
	end

	return playerDailyData[player]
end

local function saveDailyData(player)
	local userId = tostring(player.UserId)
	local data = playerDailyData[player]

	if not data then
		return
	end

	local cleanData = serializeData(data)

	local success, err = pcall(function()
		dailyRewardsStore:SetAsync(userId, cleanData)
	end)

	if success then
		print(string.format("[DAILY V3] ✓ Dados salvos: %s", player.Name))
	else
		warn(string.format("[DAILY V3] ❌ Erro ao salvar: %s - %s", player.Name, tostring(err)))
	end
end

-- =====================================
-- VERIFICAR SE PODE COLETAR
-- =====================================

local function canClaimReward(player)
	local data = playerDailyData[player]
	if not data then
		return false, "Dados não carregados"
	end

	local currentDay = getDayTimestamp()
	local lastClaimDay = data.lastClaim

	if lastClaimDay >= currentDay then
		local hoursUntilReset = math.ceil((currentDay + 86400 - os.time()) / 3600)
		return false, "Já coletado hoje! Volta em " .. hoursUntilReset .. " horas"
	end

	-- Verificar se quebrou a sequência
	if lastClaimDay > 0 and currentDay - lastClaimDay > 86400 then
		-- Se pode recuperar, não resetar ainda
		if data.canRecoverDay then
			return true, "Pode recuperar o dia perdido"
		end

		data.currentStreak = 0
		print(string.format("[DAILY V3] ⚠️ Streak resetado: %s", player.Name))
	end

	return true, "Pode coletar"
end

-- =====================================
-- APLICAR BÔNUS
-- =====================================

local function applyBonus(player, bonus)
	local data = playerDailyData[player]

	if bonus == "2x Coins por 1 hora" then
		data.bonusActive = "2xCoins"
		data.bonusExpiry = os.time() + 3600

		if _G.SetCoinMultiplier then
			_G.SetCoinMultiplier(player, 2, 3600)
		end

		print(string.format("[DAILY V3] ✅ Bônus 2x Coins ativado: %s", player.Name))
	elseif bonus == "Personagem Exclusivo Temporário" then
		local tempCharacter = "Daily Champion"

		if _G.PlayerDataManager then
			_G.PlayerDataManager.addCharacterToInventory(player, tempCharacter)
			data.bonusActive = "TempCharacter"
			data.bonusExpiry = os.time() + 86400

			print(string.format("[DAILY V3] ✅ Personagem temporário dado: %s", player.Name))
		end
	end
end

-- =====================================
-- CALCULAR RECOMPENSAS (COM BÔNUS)
-- =====================================

local function calculateRewards(reward, streak)
	local coins = reward.coins
	local bounty = reward.bounty

	-- Bônus de streak (5% a mais por dia consecutivo)
	local streakMultiplier = 1 + (streak * 0.05)
	coins = math.floor(coins * streakMultiplier)
	bounty = math.floor(bounty * streakMultiplier)

	-- Bônus de final de semana (2x)
	if isWeekend() then
		coins = coins * 2
		bounty = bounty * 2
		print("[DAILY V3] 🎉 BÔNUS DE FINAL DE SEMANA APLICADO!")
	end

	return coins, bounty
end

-- =====================================
-- COLETAR RECOMPENSA
-- =====================================

claimDailyReward.OnServerInvoke = function(player)
	local canClaim, message = canClaimReward(player)

	if not canClaim then
		return false, message
	end

	local data = playerDailyData[player]
	data.currentStreak = data.currentStreak + 1
	data.lastClaim = getDayTimestamp()
	data.totalDaysClaimed = data.totalDaysClaimed + 1

	-- Ativar recuperação de dia após 3 dias consecutivos
	if data.currentStreak >= 3 then
		data.canRecoverDay = true
	end

	-- Pegar recompensa do dia atual
	local rewardDay = math.min(data.currentStreak, 6)
	local reward = dailyRewards[rewardDay]

	-- Calcular recompensas com bônus
	local coins, bounty = calculateRewards(reward, data.currentStreak)

	-- Dar recompensas
	if _G.PlayerDataManager then
		_G.PlayerDataManager.updateCoins(player, coins)
		_G.PlayerDataManager.updateBounty(player, bounty)

		-- Aplicar bônus se houver
		if reward.bonus then
			applyBonus(player, reward.bonus)
		end

		_G.PlayerDataManager.savePlayerData(player)
	end

	-- Salvar dados de daily
	saveDailyData(player)

	-- Se completou o ciclo de 6 dias, resetar
	if data.currentStreak >= 6 then
		data.currentStreak = 0
		print(string.format("[DAILY V3] 🎊 %s completou o ciclo de 6 dias!", player.Name))
	end

	print(
		string.format(
			"[DAILY V3] ✅ %s coletou Dia %d: %d moedas + %d bounty",
			player.Name,
			rewardDay,
			coins,
			bounty
		)
	)

	-- Notificar jogador
	local notifyRemote = remotes:FindFirstChild("ShowNotification")
	if notifyRemote then
		notifyRemote:FireClient(player, {
			title = "🎁 Recompensa Coletada!",
			message = string.format("+%d Moedas\n+%d Bounty", coins, bounty),
			duration = 3,
		})
	end

	return true,
	{
		coins = coins,
		bounty = bounty,
		bonus = reward.bonus,
		streak = data.currentStreak,
		nextDay = rewardDay < 6 and rewardDay + 1 or 1,
		isWeekend = isWeekend(),
	}
end

-- =====================================
-- OBTER STATUS
-- =====================================

getDailyRewardStatus.OnServerInvoke = function(player)
	local data = playerDailyData[player]
	if not data then
		data = loadDailyData(player)
	end

	local canClaim, message = canClaimReward(player)
	local currentDay = getDayTimestamp()

	-- Calcular tempo até próxima recompensa
	local timeUntilNext = 0
	if data.lastClaim >= currentDay then
		timeUntilNext = (currentDay + 86400) - os.time()
	end

	-- Verificar bônus ativo
	local bonusStatus = nil
	if data.bonusActive and data.bonusExpiry > os.time() then
		bonusStatus = {
			type = data.bonusActive,
			timeLeft = data.bonusExpiry - os.time(),
		}
	end

	-- Adicionar informação de bônus de final de semana às recompensas
	local enhancedRewards = {}
	for i, reward in ipairs(dailyRewards) do
		local coins, bounty = calculateRewards(reward, data.currentStreak)

		table.insert(enhancedRewards, {
			day = reward.day,
			coins = coins,
			bounty = bounty,
			bonus = reward.bonus,
			description = reward.description,
			isWeekend = isWeekend(),
		})
	end

	return {
		canClaim = canClaim,
		message = message or "",
		currentStreak = data.currentStreak or 0,
		totalDaysClaimed = data.totalDaysClaimed or 0,
		timeUntilNext = timeUntilNext,
		bonusActive = bonusStatus,
		rewards = enhancedRewards,
		canRecover = data.canRecoverDay or false,
		missionsCompleted = data.missionsCompleted or 0,
		isWeekend = isWeekend(),
	}
end

-- =====================================
-- SISTEMA DE RECUPERAÇÃO
-- =====================================

recoverLostDay.OnServerInvoke = function(player)
	local data = playerDailyData[player]
	if not data then
		return false, "Dados não encontrados"
	end

	if not data.canRecoverDay then
		return false, "Você ainda não desbloqueou a recuperação de dias"
	end

	local currentDay = getDayTimestamp()

	-- Verificar se já usou recuperação recentemente (1 por semana)
	if data.lastRecoveryUse > 0 then
		local daysSinceLastUse = (currentDay - data.lastRecoveryUse) / 86400
		if daysSinceLastUse < 7 then
			local msg = string.format(
				"Você pode recuperar apenas 1 dia por semana! Aguarde %.0f dias",
				7 - daysSinceLastUse
			)
			return false, msg
		end
	end

	-- Recuperar o dia
	data.currentStreak = data.currentStreak + 1
	data.lastRecoveryUse = currentDay
	data.canRecoverDay = false

	saveDailyData(player)

	print(string.format("[DAILY V3] 🔄 %s recuperou um dia perdido", player.Name))

	return true, "Dia recuperado com sucesso!"
end

-- =====================================
-- EVENTOS DE JOGADOR
-- =====================================

Players.PlayerAdded:Connect(function(player)
	loadDailyData(player)

	-- Inicializar progresso de missões
	playerMissionProgress[player] = {}
	for _, mission in ipairs(dailyMissions) do
		playerMissionProgress[player][mission.id] = 0
	end

	-- Verificar bônus expirados
	task.spawn(function()
		while player.Parent do
			local data = playerDailyData[player]
			if data and data.bonusActive and data.bonusExpiry <= os.time() then
				-- Remover bônus expirado
				if data.bonusActive == "TempCharacter" then
					if _G.PlayerDataManager then
						local playerData = _G.PlayerDataManager.getPlayerData(player)
						if playerData then
							local index = table.find(playerData.ownedCharacters, "Daily Champion")
							if index then
								table.remove(playerData.ownedCharacters, index)
							end
						end
					end
				elseif data.bonusActive == "2xCoins" then
					if _G.SetCoinMultiplier then
						_G.SetCoinMultiplier(player, 1, 0)
					end
				end

				data.bonusActive = nil
				data.bonusExpiry = 0
				saveDailyData(player)

				print(string.format("[DAILY V3] ⏰ Bônus expirado: %s", player.Name))
			end
			task.wait(60)
		end
	end)
end)

Players.PlayerRemoving:Connect(function(player)
	saveDailyData(player)
	playerDailyData[player] = nil
	playerMissionProgress[player] = nil
end)

-- =====================================
-- AUTO-SAVE PERIÓDICO
-- =====================================

task.spawn(function()
	while true do
		task.wait(300) -- A cada 5 minutos

		local count = 0
		for player, _ in pairs(playerDailyData) do
			if player.Parent then
				saveDailyData(player)
				count = count + 1
			end
		end

		if count > 0 then
			print(string.format("[DAILY V3] 💾 Auto-save: %d jogadores", count))
		end
	end
end)

-- =====================================
-- SALVAR AO FECHAR SERVIDOR
-- =====================================

game:BindToClose(function()
	print("[DAILY V3] 🔒 Servidor fechando, salvando dados...")

	local players = Players:GetPlayers()
	local saveThreads = {}

	for _, player in ipairs(players) do
		table.insert(
			saveThreads,
			task.spawn(function()
				saveDailyData(player)
			end)
		)
	end

	task.wait(3)
	print("[DAILY V3] ✓ Shutdown save completo")
end)

-- =====================================
-- FUNÇÕES GLOBAIS EXPORTADAS
-- =====================================

_G.DailyRewards = {
	getPlayerData = function(player)
		return playerDailyData[player]
	end,

	grantBonus = function(player, bonusType, duration)
		local data = playerDailyData[player]
		if data then
			data.bonusActive = bonusType
			data.bonusExpiry = os.time() + duration
			saveDailyData(player)
		end
	end,

	resetStreak = function(player)
		local data = playerDailyData[player]
		if data then
			data.currentStreak = 0
			saveDailyData(player)
		end
	end,

	addStreakDay = function(player)
		local data = playerDailyData[player]
		if data then
			data.currentStreak = data.currentStreak + 1
			saveDailyData(player)
		end
	end,
}

-- =====================================
-- DEBUG
-- =====================================

_G.DebugDailyRewards = function(playerName)
	local player = Players:FindFirstChild(playerName)
	if not player then
		print("❌ Jogador não encontrado")
		return
	end

	local data = playerDailyData[player]
	if not data then
		print("❌ Dados não encontrados")
		return
	end

	print("\n========== DEBUG DAILY REWARDS ==========")
	print(string.format("Jogador: %s", player.Name))
	print(string.format("Streak Atual: %d dias", data.currentStreak))
	print(string.format("Total Coletado: %d dias", data.totalDaysClaimed))
	print(string.format("Última Coleta: %s", os.date("%d/%m/%Y", data.lastClaim)))
	print(string.format("Pode Recuperar: %s", data.canRecoverDay and "Sim" or "Não"))
	print(string.format("Bônus Ativo: %s", data.bonusActive or "Nenhum"))

	if data.bonusActive then
		print(string.format("Expira em: %d segundos", data.bonusExpiry - os.time()))
	end

	print(string.format("Final de Semana: %s", isWeekend() and "Sim (2x recompensas)" or "Não"))
	print("=====================================\n")
end

print([[
╔════════════════════════════════════════════════════╗
║  ✅ DAILY REWARDS SERVER V3 CARREGADO             ║
╠════════════════════════════════════════════════════╣
║  SUBSTITUI: DailyRewardsServer V2                 ║
╠════════════════════════════════════════════════════╣
║  NOVIDADES V3:                                     ║
║  • Sistema de Missões Diárias (preparado)         ║
║  • Recompensas Progressivas (5% por dia)          ║
║  • Bônus de Final de Semana (2x recompensas)     ║
║  • Sistema de Recuperação (1 dia por semana)      ║
║  • Logs detalhados de todas as ações              ║
║  • Auto-save a cada 5 minutos                     ║
║  • Notificações automáticas integradas            ║
╠════════════════════════════════════════════════════╣
║  SISTEMA DE BÔNUS:                                 ║
║  • Streak: +5% por dia consecutivo                ║
║  • Final de Semana: 2x moedas e bounty           ║
║  • Recuperação: 1x por semana (após 3 dias)      ║
╠════════════════════════════════════════════════════╣
║  API Global:                                       ║
║  • _G.DailyRewards.getPlayerData(player)          ║
║  • _G.DailyRewards.grantBonus(player, type, dur)  ║
║  • _G.DailyRewards.resetStreak(player)            ║
║  • _G.DailyRewards.addStreakDay(player)           ║
║  • _G.DebugDailyRewards("NomeJogador")            ║
╚════════════════════════════════════════════════════╝
]])
