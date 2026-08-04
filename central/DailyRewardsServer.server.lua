-- ============================================
-- SISTEMA DE RECOMPENSAS DIÁRIAS - SERVIDOR V6
-- Coloque em ServerScriptService
-- Nome: "DailyRewardsServer"
-- SUBSTITUI: DailyRewardsServer V5
-- ============================================
-- (V6) CORREÇÕES — o "personagem vazio" do dia 6:
-- • FIX personagem fantasma: o V5 dava "Daily Champion" como bônus do
--   dia 6. Esse nome NÃO existe no catálogo, e o
--   addCharacterToInventory não valida nada — ele caía no ramo final
--   (source = "Shop") e inseria um personagem SEM definição. Resultado:
--   um card vazio no inventário, impossível de equipar.
-- • FIX o fantasma era permanente: a remoção depois de 24h usava
--   table.find(ownedCharacters, "Daily Champion") — mas ownedCharacters
--   é lista de OBJETOS desde o V4 do DataManager, não de strings. O
--   table.find nunca casava, index era sempre nil, e o fantasma ficava
--   para sempre. O bloco inteiro do "TempCharacter" foi removido.
-- • FIX o fantasma era vendável e trocável: source = "Shop" dá
--   tradeable = true e sellable = true (SOURCE_PERMISSIONS no
--   DataManager). Dava para vender por moedas e passar adiante um
--   personagem que não existe.
-- • LIMPEZA retroativa: quem já tem o "Daily Champion" preso no
--   inventário perde ele no próximo login (limparPersonagemFantasma).
--   Se estiver equipado, é desequipado antes.
-- • O bônus do dia 6 agora só entrega personagem REAL, conferido no
--   _G.CharacterCatalog. Configure em PERSONAGEM_BONUS_DIA_6. Vazio ou
--   inexistente = paga a compensação em moedas/bounty e não inventa
--   nada.
-- • Logs atualizados para [DAILY V6].
-- (V5) CORREÇÕES:
-- • FIX ciclo de 6 dias: o reset do streak agora acontece ANTES do
--   saveDailyData (no V4 salvava streak=6 e resetava depois — se o
--   servidor caísse, o jogador ficava preso no streak 6).
-- • FIX recuperação "de graça": quando o streak seria quebrado mas o
--   jogador tinha canRecoverDay, o V4 protegia o streak SEM consumir a
--   recuperação. Agora a recuperação é consumida automaticamente
--   (canRecoverDay = false + lastRecoveryUse marcado) quando protege
--   um streak na coleta.
-- • Logs atualizados para [DAILY V5].
-- (V4) wait()/spawn() -> task.wait()/task.spawn() (conformidade)
-- (V3) Missões diárias, recompensas progressivas, bônus de fim de
--   semana, sistema de recuperação, logs, notificações, estatísticas.
-- ============================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")

-- DataStore para recompensas diárias (MESMO nome do V3/V4 — não mudar,
-- senão os streaks de todo mundo resetam)
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
		print("[DAILY V6] ✓ Remote criado: " .. name)
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

-- (V6) Personagem do bônus do dia 6.
-- Precisa ser um nome que EXISTE no catálogo (_G.CharacterCatalog).
-- Deixe "" para desligar o bônus de personagem — nesse caso o dia 6
-- paga COMPENSACAO_SEM_PERSONAGEM em moedas/bounty no lugar.
-- ⚠️ NÃO invente nome aqui. Nome fora do catálogo = card vazio no
-- inventário, que foi exatamente o bug do V5.
local PERSONAGEM_BONUS_DIA_6 = ""

-- Pago no dia 6 quando não há personagem válido configurado
local COMPENSACAO_SEM_PERSONAGEM = { coins = 150, bounty = 50 }

-- (V6) Nome do fantasma que o V5 criava. Mantido só para a limpeza
-- retroativa de quem já tem ele preso no inventário.
local PERSONAGEM_FANTASMA_V5 = "Daily Champion"

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
		bonus = "Personagem Exclusivo",
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
				"[DAILY V6] ✓ Dados carregados: %s (Streak: %d)",
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
		print(string.format("[DAILY V6] ✓ Dados padrão criados: %s", player.Name))
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
		print(string.format("[DAILY V6] ✓ Dados salvos: %s", player.Name))
	else
		warn(string.format("[DAILY V6] ❌ Erro ao salvar: %s - %s", player.Name, tostring(err)))
	end
end

-- =====================================
-- VERIFICAR SE PODE COLETAR
-- =====================================

-- (V5) Retorna um terceiro valor: needsRecovery (true quando o streak só
-- sobrevive se a recuperação for consumida na coleta)
local function canClaimReward(player)
	local data = playerDailyData[player]
	if not data then
		return false, "Dados não carregados", false
	end

	local currentDay = getDayTimestamp()
	local lastClaimDay = data.lastClaim

	if lastClaimDay >= currentDay then
		local hoursUntilReset = math.ceil((currentDay + 86400 - os.time()) / 3600)
		return false, "Já coletado hoje! Volta em " .. hoursUntilReset .. " horas", false
	end

	-- Verificar se quebrou a sequência
	if lastClaimDay > 0 and currentDay - lastClaimDay > 86400 then
		-- (V5) Se pode recuperar, o streak sobrevive MAS a recuperação
		-- será consumida no momento da coleta
		if data.canRecoverDay then
			return true, "Pode recuperar o dia perdido", true
		end

		data.currentStreak = 0
		print(string.format("[DAILY V6] ⚠️ Streak resetado: %s", player.Name))
	end

	return true, "Pode coletar", false
end

-- =====================================
-- APLICAR BÔNUS
-- =====================================

-- (V6) O personagem só é entregue se existir DE VERDADE no catálogo.
-- Sem catálogo carregado, ou nome fora dele, devolve nil — e o dia 6
-- cai na compensação em moedas.
local function personagemBonusValido()
	if PERSONAGEM_BONUS_DIA_6 == "" then
		return nil
	end

	if not (_G.CharacterCatalog and _G.CharacterCatalog.getDefinition) then
		warn("[DAILY V6] ⚠️ Catálogo indisponível — bônus do dia 6 vira compensação")
		return nil
	end

	local ok, definicao = pcall(_G.CharacterCatalog.getDefinition, PERSONAGEM_BONUS_DIA_6)
	if not ok or definicao == nil then
		warn(
			string.format(
				"[DAILY V6] ⚠️ '%s' não está no catálogo — bônus do dia 6 vira compensação",
				PERSONAGEM_BONUS_DIA_6
			)
		)
		return nil
	end

	return PERSONAGEM_BONUS_DIA_6
end

-- Devolve: moedasExtra, bountyExtra, textoDoBonus
-- O texto volta para o cliente, então precisa refletir o que REALMENTE
-- aconteceu — não o que estava planejado.
local function applyBonus(player, bonus)
	local data = playerDailyData[player]

	if bonus == "2x Coins por 1 hora" then
		data.bonusActive = "2xCoins"
		data.bonusExpiry = os.time() + 3600

		if _G.SetCoinMultiplier then
			_G.SetCoinMultiplier(player, 2, 3600)
		end

		print(string.format("[DAILY V6] ✅ Bônus 2x Coins ativado: %s", player.Name))
		return 0, 0, bonus
	elseif bonus == "Personagem Exclusivo" then
		local nome = personagemBonusValido()

		if nome and _G.PlayerDataManager then
			if _G.PlayerDataManager.ownsCharacter(player, nome) then
				print(
					string.format("[DAILY V6] ℹ️ %s já tem '%s' — pagando compensação", player.Name, nome)
				)
			elseif _G.PlayerDataManager.addCharacterToInventory(player, nome) then
				print(string.format("[DAILY V6] ✅ Personagem '%s' entregue: %s", nome, player.Name))
				return 0, 0, "Personagem: " .. nome
			else
				warn(string.format("[DAILY V6] ⚠️ Falha ao entregar '%s' a %s", nome, player.Name))
			end
		end

		-- Sem personagem válido: paga em moedas em vez de inventar um
		-- personagem que não existe.
		return COMPENSACAO_SEM_PERSONAGEM.coins,
			COMPENSACAO_SEM_PERSONAGEM.bounty,
			string.format(
				"Bônus Lendário (+%d 💰 +%d ⚔️)",
				COMPENSACAO_SEM_PERSONAGEM.coins,
				COMPENSACAO_SEM_PERSONAGEM.bounty
			)
	end

	return 0, 0, bonus
end

-- (V6) LIMPEZA RETROATIVA
-- O V5 enfiava "Daily Champion" no inventário e a remoção dele estava
-- quebrada (table.find de string numa lista de objetos). Quem coletou o
-- dia 6 carrega esse card vazio até hoje, e ele é vendável/trocável.
-- Some com ele no login.
local function limparPersonagemFantasma(player)
	if not (_G.PlayerDataManager and _G.PlayerDataManager.getPlayerData) then
		return
	end

	local dados = _G.PlayerDataManager.getPlayerData(player)
	if not dados then
		return
	end

	if not _G.PlayerDataManager.ownsCharacter(player, PERSONAGEM_FANTASMA_V5) then
		return
	end

	-- Se estiver equipado, desequipa antes de sumir com ele
	if dados.equippedCharacter == PERSONAGEM_FANTASMA_V5 then
		dados.equippedCharacter = nil
	end

	local removido = _G.PlayerDataManager.removeCharacterByName(player, PERSONAGEM_FANTASMA_V5)
	if removido then
		_G.PlayerDataManager.savePlayerData(player)
		print(
			string.format(
				"[DAILY V6] 🧹 Personagem fantasma '%s' removido de %s",
				PERSONAGEM_FANTASMA_V5,
				player.Name
			)
		)
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
		print("[DAILY V6] 🎉 BÔNUS DE FINAL DE SEMANA APLICADO!")
	end

	return coins, bounty
end

-- =====================================
-- COLETAR RECOMPENSA
-- =====================================

claimDailyReward.OnServerInvoke = function(player)
	local canClaim, message, needsRecovery = canClaimReward(player)

	if not canClaim then
		return false, message
	end

	local data = playerDailyData[player]

	-- (V5) Consumir a recuperação quando ela protegeu o streak
	if needsRecovery then
		data.canRecoverDay = false
		data.lastRecoveryUse = getDayTimestamp()
		print(string.format("[DAILY V6] 🔄 Recuperação consumida automaticamente: %s", player.Name))
	end

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

	-- Streak exibido ao jogador (antes do possível reset de ciclo)
	local displayStreak = data.currentStreak

	-- (V6) O bônus pode devolver moedas/bounty extra (dia 6 sem
	-- personagem configurado) e o texto do que de fato aconteceu.
	local bonusTexto = reward.bonus

	-- Dar recompensas
	if _G.PlayerDataManager then
		-- Aplicar bônus se houver, ANTES de creditar, para o total
		-- mostrado ao jogador já incluir o extra
		if reward.bonus then
			local moedasExtra, bountyExtra, texto = applyBonus(player, reward.bonus)
			coins = coins + (moedasExtra or 0)
			bounty = bounty + (bountyExtra or 0)
			bonusTexto = texto or reward.bonus
		end

		_G.PlayerDataManager.updateCoins(player, coins)
		_G.PlayerDataManager.updateBounty(player, bounty)

		_G.PlayerDataManager.savePlayerData(player)
	end

	-- (V5 FIX) Se completou o ciclo de 6 dias, resetar ANTES de salvar —
	-- no V4 o save vinha antes do reset e podia persistir streak=6
	if data.currentStreak >= 6 then
		data.currentStreak = 0
		print(string.format("[DAILY V6] 🎊 %s completou o ciclo de 6 dias!", player.Name))
	end

	-- Salvar dados de daily (já com o estado final correto)
	saveDailyData(player)

	print(
		string.format(
			"[DAILY V6] ✅ %s coletou Dia %d: %d moedas + %d bounty",
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
		bonus = bonusTexto,
		streak = displayStreak,
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

	print(string.format("[DAILY V6] 🔄 %s recuperou um dia perdido", player.Name))

	return true, "Dia recuperado com sucesso!"
end

-- =====================================
-- EVENTOS DE JOGADOR
-- =====================================

Players.PlayerAdded:Connect(function(player)
	loadDailyData(player)

	-- (V6) Some com o "Daily Champion" que o V5 deixou preso no
	-- inventário. Espera os dados do jogador carregarem primeiro.
	task.spawn(function()
		local espera = 0
		while not _G.PlayerDataManager.getPlayerData(player) and espera < 15 do
			task.wait(0.5)
			espera = espera + 0.5
		end
		limparPersonagemFantasma(player)
	end)

	-- Inicializar progresso de missões
	playerMissionProgress[player] = {}
	for _, mission in ipairs(dailyMissions) do
		playerMissionProgress[player][mission.id] = 0
	end

	-- Verificar bônus expirados
	-- (V6) O ramo "TempCharacter" saiu junto com o personagem fantasma.
	-- Só o multiplicador de moedas expira.
	task.spawn(function()
		while player.Parent do
			local data = playerDailyData[player]
			if data and data.bonusActive and data.bonusExpiry <= os.time() then
				if data.bonusActive == "2xCoins" then
					if _G.SetCoinMultiplier then
						_G.SetCoinMultiplier(player, 1, 0)
					end
				end

				data.bonusActive = nil
				data.bonusExpiry = 0
				saveDailyData(player)

				print(string.format("[DAILY V6] ⏰ Bônus expirado: %s", player.Name))
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
			print(string.format("[DAILY V6] 💾 Auto-save: %d jogadores", count))
		end
	end
end)

-- =====================================
-- SALVAR AO FECHAR SERVIDOR
-- =====================================

game:BindToClose(function()
	print("[DAILY V6] 🔒 Servidor fechando, salvando dados...")

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
	print("[DAILY V6] ✓ Shutdown save completo")
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
║  ✅ DAILY REWARDS SERVER V5 CARREGADO             ║
╠════════════════════════════════════════════════════╣
║  SUBSTITUI: DailyRewardsServer V4                 ║
║  REMOVER:   DailyRewardsServer V4                 ║
╠════════════════════════════════════════════════════╣
║  CORREÇÕES V5:                                     ║
║  • Ciclo de 6 dias: reset salvo corretamente      ║
║  • Recuperação consumida ao proteger o streak     ║
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
