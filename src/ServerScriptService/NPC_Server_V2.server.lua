-- ============================================
-- NPC SERVER V2 — RECOMPENSA POR % DA VIDA DO NPC
-- Coloque em ServerScriptService
-- Nome: "NPC_Server_V2"
-- SUBSTITUI: NPC_Server_V1
-- ============================================
-- (V2) ALTERAÇÕES:
-- • RECOMPENSA AGORA DEPENDE DA VIDA (MaxHealth) DO NPC, em %:
--     - Drop no chão  = DROP_HP_PERCENT   % da vida máxima
--     - Moedas diretas = KILL_COIN_PERCENT % da vida máxima
--     - Bounty         = BOUNTY_HP_PERCENT % da vida máxima
--   (antes era fixo + AttackDamage; agora qualquer NPC paga
--    proporcional à própria "dureza", e não depende de um
--    Configurations/AttackDamage que muitos NPCs não têm)
-- • math.random REMOVIDO do posicionamento do drop -> offset
--   FIXO Vector3.new(2, 1.5, 2) (regra do projeto: sem Randomize)
--   — padrão REUTILIZADO do CoinDrop_V2
-- • Enum.Font.SourceSansBold -> Enum.Font.Code (estilo retro)
-- • DETECÇÃO ROBUSTA: pega NPC em QUALQUER profundidade do
--   Workspace (escuta Humanoid sendo adicionado) + suporte a
--   CollectionService tag "NPC"; os 2 ChildAdded duplicados
--   da V1 foram unificados
-- • SEM VAZAMENTO: conexões por NPC são guardadas e
--   desconectadas no death/cleanup, evitando recompensa dupla
--   quando o MESMO NPC ressuscita
--
-- REUTILIZADO:
-- • CoinDrop_V2 ......... padrão de drop (Clone do DropCash,
--                        AmountOfCash, ProximityPrompt, offset
--                        fixo) e Debris:AddItem para sumir
-- • DataManager_V4 ...... updateCoins / updateBounty /
--                        savePlayerData / getPlayerData
-- • Kill system ......... _G.RegisterAttack (crédito de kill)
--
-- NÃO deleta humanoides nem o NPC (o respawn é do ZombieScript).
-- ============================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")
local CollectionService = game:GetService("CollectionService")

-- Aguardar sistemas essenciais (REUTILIZADO do CoinDrop_V2)
repeat
	task.wait()
until _G.PlayerDataManager

print([[╔══════════════════════════════════════════╗
║   NPC SERVER V2 — INICIALIZANDO         ║
╚══════════════════════════════════════════╝]])

-- =====================================
-- CONFIGURAÇÕES
-- =====================================

local CONFIG = {
	-- (V2) Recompensa proporcional à VIDA MÁXIMA do NPC, em %
	DROP_HP_PERCENT = 50, -- moedas no chão  = 50% da vida máxima
	KILL_COIN_PERCENT = 50, -- moedas ao matar = 50% da vida máxima
	BOUNTY_HP_PERCENT = 10, -- bounty          = 10% da vida máxima

	-- Pisos mínimos (NPC fraquinho ainda paga algo)
	MIN_DROP = 10,
	MIN_COIN = 10,
	MIN_BOUNTY = 1,

	DAMAGE_TIMEOUT = 15, -- segundos p/ resetar atribuição de dano
	DROP_LIFETIME = 60, -- segundos antes do drop sumir
	REREGISTER_DELAY = 8, -- tempo > RespawnWaitTime do ZombieScript (5s)
	NOTIF_DURATION = 3.5, -- duração da notificação na tela
}

-- Tag opcional do CollectionService p/ marcar NPCs manualmente
local NPC_TAG = "NPC"

-- =====================================
-- ESTADO
-- =====================================

local registeredNPCs = {} -- [model]    = true
local npcConnections = {} -- [model]    = { RBXScriptConnection, ... }
local damageTracking = {} -- [humanoid] = { [player] = dano, nearestPlayer, ... }

-- =====================================
-- FUNÇÕES AUXILIARES
-- =====================================

local function isPlayerInSafeZone(player)
	if not player.Character then
		return true
	end
	return player.Character:FindFirstChild("InSafeZone") ~= nil
end

local function getDropCashModel()
	return ReplicatedStorage:FindFirstChild("DropCash")
end

-- Posição confiável do NPC (com fallbacks p/ qualquer NPC)
local function getModelPosition(model, humanoid)
	local hrp = model:FindFirstChild("HumanoidRootPart")
	if hrp and hrp:IsA("BasePart") then
		return hrp.Position
	end
	if humanoid and humanoid.RootPart then
		return humanoid.RootPart.Position
	end
	local ok, pivot = pcall(function()
		return model:GetPivot()
	end)
	if ok then
		return pivot.Position
	end
	return Vector3.new(0, 0, 0)
end

-- Notificação de kill de NPC para o jogador
local function showKillNotification(player, npcName, coins, bounty)
	local gui = player:FindFirstChild("PlayerGui")
	if not gui then
		return
	end

	local screen = Instance.new("ScreenGui")
	screen.Name = "NpcKillNotif"
	screen.DisplayOrder = 45
	screen.ResetOnSpawn = false
	screen.Parent = gui

	local frame = Instance.new("Frame")
	frame.Size = UDim2.new(0.3, 0, 0.11, 0)
	frame.Position = UDim2.new(0.35, 0, 0.06, 0)
	frame.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
	frame.BorderColor3 = Color3.fromRGB(255, 100, 0)
	frame.BorderSizePixel = 3
	frame.Parent = screen

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = frame

	local titleLbl = Instance.new("TextLabel")
	titleLbl.Size = UDim2.new(1, 0, 0.42, 0)
	titleLbl.BackgroundTransparency = 1
	titleLbl.Text = "☠️ NPC " .. (npcName or "Inimigo") .. " eliminado!"
	titleLbl.TextColor3 = Color3.fromRGB(255, 120, 0)
	titleLbl.TextScaled = true
	titleLbl.Font = Enum.Font.Arcade
	titleLbl.Parent = frame

	local rewardLbl = Instance.new("TextLabel")
	rewardLbl.Size = UDim2.new(1, 0, 0.35, 0)
	rewardLbl.Position = UDim2.new(0, 0, 0.42, 0)
	rewardLbl.BackgroundTransparency = 1
	rewardLbl.Text = string.format("+%d 💰  +%d ⚔️ Bounty", coins, bounty)
	rewardLbl.TextColor3 = Color3.fromRGB(255, 215, 0)
	rewardLbl.TextScaled = true
	rewardLbl.Font = Enum.Font.Code -- (V2) era SourceSansBold
	rewardLbl.Parent = frame

	Debris:AddItem(screen, CONFIG.NOTIF_DURATION)
end

-- Dropa moedas no chão na posição da morte do NPC
-- (padrão REUTILIZADO do CoinDrop_V2)
local function dropCoinsAtPosition(position, amount)
	if amount <= 0 then
		return
	end

	local template = getDropCashModel()
	if not template then
		warn("[NPC V2] DropCash não encontrado em ReplicatedStorage!")
		return
	end

	local drop = template:Clone()

	-- NPCs não têm dono — qualquer jogador pode coletar
	local ownerTag = Instance.new("ObjectValue")
	ownerTag.Name = "OriginalOwner"
	ownerTag.Value = nil
	ownerTag.Parent = drop

	local amtValue = drop:FindFirstChild("AmountOfCash")
	if amtValue then
		amtValue.Value = amount
	end

	-- Billboard (procura genérica — funciona com label "amount" do CoinDrop)
	local bb = drop:FindFirstChildWhichIsA("BillboardGui", true)
	if bb then
		local lbl = bb:FindFirstChildWhichIsA("TextLabel")
		if lbl then
			lbl.Text = amount .. "$"
		end
	end

	-- ProximityPrompt — qualquer jogador coleta (sem restrição de dono)
	local prompt = drop:FindFirstChildWhichIsA("ProximityPrompt", true)
	if prompt then
		prompt.ObjectText = "Moedas NPC"
		prompt.Triggered:Connect(function(collector)
			if not drop or not drop.Parent then
				return
			end
			prompt.Enabled = false

			_G.PlayerDataManager.updateCoins(collector, amount)
			_G.PlayerDataManager.savePlayerData(collector)

			-- Atualizar leaderstats do coletor (igual ao CoinDrop_V2)
			local collectorData = _G.PlayerDataManager.getPlayerData(collector)
			if collectorData and collector:FindFirstChild("leaderstats") then
				local coins = collector.leaderstats:FindFirstChild("Coins")
				if coins then
					coins.Value = collectorData.coins
				end
			end

			-- Mini notificação de coleta
			local cGui = collector:FindFirstChild("PlayerGui")
			if cGui then
				local s = Instance.new("ScreenGui")
				s.Name = "CoinPickup"
				s.DisplayOrder = 44
				s.ResetOnSpawn = false
				s.Parent = cGui
				local lbl = Instance.new("TextLabel")
				lbl.Size = UDim2.new(0.3, 0, 0.06, 0)
				lbl.Position = UDim2.new(0.35, 0, 0.88, 0)
				lbl.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
				lbl.BackgroundTransparency = 0.2
				lbl.BorderSizePixel = 0
				lbl.Text = "+" .. amount .. " 💰 moedas!"
				lbl.TextColor3 = Color3.fromRGB(255, 215, 0)
				lbl.TextScaled = true
				lbl.Font = Enum.Font.Arcade
				lbl.Parent = s
				Debris:AddItem(s, 2)
			end

			drop.Parent = nil
		end)
	end

	-- Posicionar no mundo — (V2) offset FIXO (sem math.random)
	local rootPart = drop:IsA("BasePart") and drop or drop:FindFirstChildWhichIsA("BasePart")
	if rootPart then
		rootPart.Position = position + Vector3.new(2, 1.5, 2)
	end

	drop.Parent = workspace
	Debris:AddItem(drop, CONFIG.DROP_LIFETIME)
end

-- Processa a morte do NPC: recompensa por % da vida + drop
local function processNpcDeath(npcModel, killerPlayer, deathPosition, npcMaxHealth)
	if not killerPlayer or not killerPlayer.Parent then
		return
	end
	if isPlayerInSafeZone(killerPlayer) then
		return
	end

	local npcName = npcModel and npcModel.Name or "Inimigo"

	-- (V2) Tudo proporcional à VIDA MÁXIMA do NPC
	local hp = math.max(1, math.floor(npcMaxHealth or 0))
	local coinReward = math.max(CONFIG.MIN_COIN, math.floor(hp * CONFIG.KILL_COIN_PERCENT / 100))
	local bountyReward = math.max(CONFIG.MIN_BOUNTY, math.floor(hp * CONFIG.BOUNTY_HP_PERCENT / 100))
	local dropAmount = math.max(CONFIG.MIN_DROP, math.floor(hp * CONFIG.DROP_HP_PERCENT / 100))

	-- Dar recompensas ao matador (DataManager_V4)
	_G.PlayerDataManager.updateCoins(killerPlayer, coinReward)
	_G.PlayerDataManager.updateBounty(killerPlayer, bountyReward)
	_G.PlayerDataManager.savePlayerData(killerPlayer)

	-- Notificação na tela
	showKillNotification(killerPlayer, npcName, coinReward, bountyReward)

	-- Drop no chão (qualquer jogador coleta)
	dropCoinsAtPosition(deathPosition, dropAmount)

	print(
		string.format(
			"[NPC V2] %s matou '%s' (vida %d) → +%d moedas +%d bounty | drop: %d",
			killerPlayer.Name,
			npcName,
			hp,
			coinReward,
			bountyReward,
			dropAmount
		)
	)
end

-- =====================================
-- LIMPEZA DE CONEXÕES (evita recompensa dupla em respawn)
-- =====================================

local function disconnectModel(model)
	local conns = npcConnections[model]
	if conns then
		for _, c in ipairs(conns) do
			pcall(function()
				c:Disconnect()
			end)
		end
		npcConnections[model] = nil
	end
end

-- =====================================
-- VALIDAÇÃO DE NPC
-- =====================================

local function isNPC(model)
	if typeof(model) ~= "Instance" then
		return false
	end
	if not model:IsA("Model") then
		return false
	end
	if Players:GetPlayerFromCharacter(model) then
		return false -- é personagem de jogador
	end
	if not model:FindFirstChildWhichIsA("Humanoid") then
		return false
	end
	return true
end

-- =====================================
-- REGISTRO DE NPC (rastreia dano + detecta morte)
-- =====================================

local registerNPC -- forward declaration (re-registro após morte)

registerNPC = function(npcModel)
	if registeredNPCs[npcModel] then
		return
	end

	local humanoid = npcModel:FindFirstChildWhichIsA("Humanoid")
	if not humanoid then
		return
	end
	if Players:GetPlayerFromCharacter(npcModel) then
		return
	end

	registeredNPCs[npcModel] = true
	damageTracking[humanoid] = {}
	npcConnections[npcModel] = {}

	print(string.format("[NPC V2] Registrado: '%s' (vida máx %d)", npcModel.Name, humanoid.MaxHealth))

	local lastHealth = humanoid.MaxHealth

	-- Heurística de atribuição de dano: jogador mais próximo no tick
	local function trackNearbyAttacker()
		if not npcModel.Parent then
			return
		end
		local hrp = npcModel:FindFirstChild("HumanoidRootPart")
		if not hrp then
			return
		end

		for _, player in pairs(Players:GetPlayers()) do
			if player.Character and not isPlayerInSafeZone(player) then
				local pHrp = player.Character:FindFirstChild("HumanoidRootPart")
				local pHum = player.Character:FindFirstChild("Humanoid")
				if pHrp and pHum and pHum.Health > 0 then
					local dist = (pHrp.Position - hrp.Position).Magnitude
					if dist <= 20 then -- dentro de 20 studs = potencial atacante
						damageTracking[humanoid].nearestPlayer = player
						damageTracking[humanoid].nearestDist = dist
					end
				end
			end
		end
	end

	-- Monitorar variação de HP
	table.insert(
		npcConnections[npcModel],
		humanoid.HealthChanged:Connect(function(newHealth)
			if not damageTracking[humanoid] then
				return
			end

			if newHealth < lastHealth then
				trackNearbyAttacker()
				local nearest = damageTracking[humanoid].nearestPlayer
				if nearest then
					damageTracking[humanoid].lastAttacker = nearest
					damageTracking[humanoid].lastDamageTime = tick()

					local dmg = lastHealth - newHealth
					damageTracking[humanoid][nearest] = (damageTracking[humanoid][nearest] or 0) + dmg

					-- Crédito de kill (REUTILIZADO do kill system)
					if _G.RegisterAttack and nearest.Character then
						local dummyVictim = { Character = npcModel }
						pcall(function()
							_G.RegisterAttack(nearest, dummyVictim)
						end)
					end
				end
			end

			lastHealth = newHealth
		end)
	)

	-- Detectar morte
	table.insert(
		npcConnections[npcModel],
		humanoid.Died:Connect(function()
			if not damageTracking[humanoid] then
				return
			end

			-- (V2) Vida máxima capturada no momento da morte
			local npcMaxHealth = humanoid.MaxHealth

			-- Jogador que causou mais dano (dentro do timeout)
			local killer = nil
			local maxDamage = 0
			local now = tick()

			for player, dmg in pairs(damageTracking[humanoid]) do
				if type(player) == "userdata" then -- chave = Player
					local lastTime = damageTracking[humanoid].lastDamageTime or 0
					if now - lastTime <= CONFIG.DAMAGE_TIMEOUT and dmg > maxDamage then
						killer = player
						maxDamage = dmg
					end
				end
			end

			-- Fallback: último atacante registrado
			if not killer then
				killer = damageTracking[humanoid].lastAttacker
			end

			local deathPos = getModelPosition(npcModel, humanoid)

			if killer then
				processNpcDeath(npcModel, killer, deathPos, npcMaxHealth)
			end

			-- Limpeza (desconecta TODAS as conexões deste NPC)
			damageTracking[humanoid] = nil
			registeredNPCs[npcModel] = nil
			disconnectModel(npcModel)

			-- Re-registrar após respawn (mesmo NPC ressuscitado)
			task.delay(CONFIG.REREGISTER_DELAY, function()
				if npcModel.Parent then
					registerNPC(npcModel)
				end
			end)
		end)
	)

	-- Compatibilidade: BindableEvent "Died" do ZombieScript
	-- (só garante re-registro; a recompensa vem do humanoid.Died)
	local diedEvent = npcModel:FindFirstChild("Died")
	if diedEvent and diedEvent:IsA("BindableEvent") then
		table.insert(
			npcConnections[npcModel],
			diedEvent.Event:Connect(function()
				task.delay(CONFIG.REREGISTER_DELAY, function()
					if npcModel.Parent then
						registerNPC(npcModel)
					end
				end)
			end)
		)
	end
end

-- =====================================
-- DETECÇÃO: qualquer NPC, em qualquer lugar do Workspace
-- =====================================

-- 1) NPCs já presentes (varre descendentes — pega NPC aninhado)
for _, descendant in ipairs(workspace:GetDescendants()) do
	if descendant:IsA("Humanoid") then
		local model = descendant.Parent
		if model and isNPC(model) then
			registerNPC(model)
		end
	end
end

-- 2) Novos NPCs: dispara quando um Humanoid é adicionado em qualquer lugar
workspace.DescendantAdded:Connect(function(descendant)
	if descendant:IsA("Humanoid") then
		task.wait(0.1) -- aguardar o resto do modelo carregar
		local model = descendant.Parent
		if model and isNPC(model) then
			registerNPC(model)
		end
	end
end)

-- 3) Suporte a CollectionService tag "NPC" (registro manual opt-in)
for _, model in ipairs(CollectionService:GetTagged(NPC_TAG)) do
	if isNPC(model) then
		registerNPC(model)
	end
end

CollectionService:GetInstanceAddedSignal(NPC_TAG):Connect(function(model)
	task.wait(0.1)
	if isNPC(model) then
		registerNPC(model)
	end
end)

-- =====================================
-- API GLOBAL
-- =====================================

_G.NpcSystem = {
	-- Forçar registro manual de um NPC específico
	registerNPC = function(model)
		registerNPC(model)
	end,

	-- Quantos NPCs estão sendo monitorados
	getCount = function()
		local n = 0
		for _ in pairs(registeredNPCs) do
			n += 1
		end
		return n
	end,

	-- (V2) Ajustar as PORCENTAGENS de recompensa em runtime
	setRewardPercents = function(dropPct, killCoinPct, bountyPct)
		CONFIG.DROP_HP_PERCENT = dropPct or CONFIG.DROP_HP_PERCENT
		CONFIG.KILL_COIN_PERCENT = killCoinPct or CONFIG.KILL_COIN_PERCENT
		CONFIG.BOUNTY_HP_PERCENT = bountyPct or CONFIG.BOUNTY_HP_PERCENT
		print(
			string.format(
				"[NPC V2] Percentuais → drop %d%% | moedas %d%% | bounty %d%%",
				CONFIG.DROP_HP_PERCENT,
				CONFIG.KILL_COIN_PERCENT,
				CONFIG.BOUNTY_HP_PERCENT
			)
		)
	end,
}

-- =====================================
-- LOOP DE SAÚDE
-- =====================================

task.spawn(function()
	while true do
		task.wait(30)
		print(string.format("[NPC V2] NPCs monitorados: %d", _G.NpcSystem.getCount()))
	end
end)

print([[╔══════════════════════════════════════════════════════╗
║  ✅ NPC SERVER V2 CARREGADO                         ║
╠══════════════════════════════════════════════════════╣
║  RECOMPENSA POR % DA VIDA DO NPC:                   ║
║  • Drop no chão  = % da vida máxima (config)        ║
║  • Moedas + bounty diretos = % da vida máxima       ║
║  • Detecta NPC em qualquer lugar do Workspace       ║
║  • Suporta tag "NPC" do CollectionService           ║
║  • Ignora jogadores na SafeZone                     ║
║  • Re-registra NPC após respawn (sem reward duplo)  ║
╠══════════════════════════════════════════════════════╣
║  API: _G.NpcSystem.registerNPC(model)               ║
║       _G.NpcSystem.getCount()                       ║
║       _G.NpcSystem.setRewardPercents(d, c, b)       ║
╚══════════════════════════════════════════════════════╝]])
