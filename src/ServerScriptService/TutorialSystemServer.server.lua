-- ============================================
-- TUTORIAL SYSTEM SERVER V3
-- (V3) ALTERAÇÕES: fontes unificadas em estilo retro (Arcade)
-- Coloque em ServerScriptService
-- Nome: "TutorialSystemServer"
-- SUBSTITUI: TutorialSystemServer V1
-- REMOVER:   TutorialSystemServer V1
-- ============================================
-- NOVIDADES V2:
-- • 15 passos interativos (era 10 slides estáticos)
-- • Dados do tutorial agora no client (V4)
-- • Server gerencia apenas progresso/DataStore
-- • Recompensa mantida em 100 moedas
-- • Novo remote: GetTutorialStepCount
-- ============================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")

repeat
	task.wait()
until _G.PlayerDataManager

print([[
╔════════════════════════════════════════════╗
║   TUTORIAL SYSTEM SERVER V2 - CARREGADO   ║
╚════════════════════════════════════════════╝
]])

-- =====================================
-- DATASTORE
-- =====================================

local tutorialDataStore = DataStoreService:GetDataStore("TutorialProgressV1")
local tutorialProgress = {}

-- =====================================
-- PASSOS DO TUTORIAL (títulos/ícones)
-- O conteúdo interativo completo está no CLIENT V4
-- =====================================

local TUTORIAL_STEPS = {
	{ title = "🎮 BEM-VINDO AO RETRO-VERSE!", icon = "🌟" },
	{ title = "🛡️ A ZONA SEGURA", icon = "🛡️" },
	{ title = "☰ O MENU PRINCIPAL", icon = "☰" },
	{ title = "🎭 PERSONAGENS DO JOGO", icon = "🎭" },
	{ title = "🛒 A LOJA — COMPRE COM MOEDAS", icon = "🛒" },
	{ title = "📦 INVENTÁRIO — EQUIPE SEU HERÓI", icon = "📦" },
	{ title = "🗺️ INDO PARA O MAPA", icon = "🗺️" },
	{ title = "⚔️ O COMBATE", icon = "⚔️" },
	{ title = "💰 RECOMPENSAS POR ELIMINAR", icon = "💰" },
	{ title = "💀 DROP DE MOEDAS NA MORTE", icon = "💀" },
	{ title = "🏆 PERSONAGENS DE BOUNTY", icon = "🏆" },
	{ title = "👥 SISTEMA DE TIMES", icon = "👥" },
	{ title = "🎁 RECOMPENSAS DIÁRIAS", icon = "🎁" },
	{ title = "⚡ SISTEMA DE DESPERTAR", icon = "⚡" },
	{ title = "✅ TUTORIAL COMPLETO!", icon = "🏆" },
}

-- =====================================
-- CRIAR REMOTES
-- =====================================

local remotes = ReplicatedStorage:WaitForChild("Remotes")

local function getOrCreateRemote(name, remoteType)
	local remote = remotes:FindFirstChild(name)
	if not remote then
		remote = Instance.new(remoteType == "Event" and "RemoteEvent" or "RemoteFunction")
		remote.Name = name
		remote.Parent = remotes
		print("[TUTORIAL V2] ✓ Remote criado: " .. name)
	end
	return remote
end

local getTutorialProgress = getOrCreateRemote("GetTutorialProgress", "Function")
local completeTutorial = getOrCreateRemote("CompleteTutorial", "Event")
local getTutorialSlides = getOrCreateRemote("GetTutorialSlides", "Function")
local getTutorialStepCount = getOrCreateRemote("GetTutorialStepCount", "Function")

-- =====================================
-- FUNÇÕES DE DADOS
-- =====================================

local function loadTutorialProgress(player)
	local userId = tostring(player.UserId)
	local success, data = pcall(function()
		return tutorialDataStore:GetAsync(userId)
	end)

	if success and data then
		tutorialProgress[player] = {
			completed = data.completed or false,
			completedAt = data.completedAt or 0,
			timesViewed = data.timesViewed or 0,
			lastStep = data.lastStep or 0,
		}
		print(
			string.format(
				"[TUTORIAL V2] ✓ Carregado: %s (Completo: %s)",
				player.Name,
				tostring(tutorialProgress[player].completed)
			)
		)
	else
		tutorialProgress[player] = {
			completed = false,
			completedAt = 0,
			timesViewed = 0,
			lastStep = 0,
		}
		print(string.format("[TUTORIAL V2] ✓ Novo jogador: %s", player.Name))
	end

	return tutorialProgress[player]
end

local function saveTutorialProgress(player)
	local userId = tostring(player.UserId)
	local data = tutorialProgress[player]
	if not data then
		return
	end

	local ok, err = pcall(function()
		tutorialDataStore:SetAsync(userId, {
			completed = data.completed,
			completedAt = data.completedAt,
			timesViewed = data.timesViewed,
			lastStep = data.lastStep or 0,
		})
	end)

	if ok then
		print(string.format("[TUTORIAL V2] ✓ Salvo: %s", player.Name))
	else
		warn(
			string.format("[TUTORIAL V2] ❌ Erro ao salvar: %s — %s", player.Name, tostring(err))
		)
	end
end

-- =====================================
-- REMOTE HANDLERS
-- =====================================

-- Progresso do jogador
getTutorialProgress.OnServerInvoke = function(player)
	local progress = tutorialProgress[player]
	if not progress then
		progress = loadTutorialProgress(player)
	end
	return {
		completed = progress.completed,
		completedAt = progress.completedAt,
		timesViewed = progress.timesViewed,
		lastStep = progress.lastStep or 0,
		shouldAutoShow = not progress.completed,
	}
end

-- Slides (retrocompatibilidade — V4 client usa dados próprios)
getTutorialSlides.OnServerInvoke = function(player)
	return TUTORIAL_STEPS
end

-- Contagem de passos
getTutorialStepCount.OnServerInvoke = function(player)
	return #TUTORIAL_STEPS
end

-- Concluir tutorial
completeTutorial.OnServerEvent:Connect(function(player)
	local progress = tutorialProgress[player]
	if not progress then
		return
	end

	progress.timesViewed = progress.timesViewed + 1

	if not progress.completed then
		progress.completed = true
		progress.completedAt = os.time()
		saveTutorialProgress(player)

		print(string.format("[TUTORIAL V2] ✅ %s completou o tutorial!", player.Name))

		-- Recompensa: 100 moedas
		if _G.PlayerDataManager then
			_G.PlayerDataManager.updateCoins(player, 100)
			_G.PlayerDataManager.savePlayerData(player)
		end

		-- Notificação via GUI (server-side)
		local gui = player:FindFirstChild("PlayerGui")
		if gui then
			local screen = Instance.new("ScreenGui")
			screen.Name = "TutorialRewardNotif"
			screen.DisplayOrder = 300
			screen.Parent = gui

			local frame = Instance.new("Frame")
			frame.Size = UDim2.new(0.4, 0, 0.15, 0)
			frame.Position = UDim2.new(0.3, 0, 0.38, 0)
			frame.BackgroundColor3 = Color3.fromRGB(0, 130, 0)
			frame.BorderColor3 = Color3.fromRGB(255, 255, 255)
			frame.BorderSizePixel = 4
			frame.Parent = screen

			local corner = Instance.new("UICorner")
			corner.CornerRadius = UDim.new(0.05, 0)
			corner.Parent = frame

			local titleL = Instance.new("TextLabel")
			titleL.Size = UDim2.new(1, 0, 0.45, 0)
			titleL.BackgroundTransparency = 1
			titleL.Text = "🎉 TUTORIAL COMPLETO!"
			titleL.TextColor3 = Color3.new(1, 1, 1)
			titleL.TextScaled = true
			titleL.Font = Enum.Font.Arcade
			titleL.Parent = frame

			local rewardL = Instance.new("TextLabel")
			rewardL.Size = UDim2.new(1, 0, 0.45, 0)
			rewardL.Position = UDim2.new(0, 0, 0.5, 0)
			rewardL.BackgroundTransparency = 1
			rewardL.Text = "💰 +100 MOEDAS DE BÔNUS!"
			rewardL.TextColor3 = Color3.fromRGB(255, 255, 0)
			rewardL.TextScaled = true
			rewardL.Font = Enum.Font.Arcade
			rewardL.Parent = frame

			game:GetService("Debris"):AddItem(screen, 5)
		end
	else
		-- Já completou antes — só registrar visualização
		saveTutorialProgress(player)
	end
end)

-- =====================================
-- EVENTOS DE JOGADOR
-- =====================================

Players.PlayerAdded:Connect(function(player)
	task.wait(1)
	loadTutorialProgress(player)
end)

Players.PlayerRemoving:Connect(function(player)
	saveTutorialProgress(player)
	tutorialProgress[player] = nil
end)

-- =====================================
-- AUTO-SAVE PERIÓDICO
-- =====================================

task.spawn(function()
	while true do
		task.wait(300)
		for player, _ in pairs(tutorialProgress) do
			if player.Parent then
				saveTutorialProgress(player)
			end
		end
	end
end)

-- =====================================
-- SALVAR AO FECHAR
-- =====================================

game:BindToClose(function()
	print("[TUTORIAL V2] 🔒 Salvando antes de fechar...")
	for player, _ in pairs(tutorialProgress) do
		saveTutorialProgress(player)
	end
	task.wait(1)
	print("[TUTORIAL V2] ✓ Shutdown save completo")
end)

-- =====================================
-- DEBUG
-- =====================================

_G.DebugTutorial = function(playerName)
	local player = Players:FindFirstChild(playerName)
	if not player then
		print("❌ Jogador não encontrado")
		return
	end

	local progress = tutorialProgress[player]
	if not progress then
		print("❌ Progresso não carregado")
		return
	end

	print("\n========== DEBUG TUTORIAL V2 ==========")
	print(string.format("Jogador:       %s", player.Name))
	print(string.format("Completo:      %s", tostring(progress.completed)))
	print(string.format("Último Passo:  %d / %d", progress.lastStep or 0, #TUTORIAL_STEPS))
	print(
		string.format(
			"Concluído em:  %s",
			progress.completedAt > 0 and os.date("%d/%m/%Y %H:%M", progress.completedAt)
				or "Não completado"
		)
	)
	print(string.format("Vezes Visto:   %d", progress.timesViewed))
	print("========================================\n")
end

_G.ResetTutorial = function(playerName)
	local player = Players:FindFirstChild(playerName)
	if not player then
		print("❌ Jogador não encontrado")
		return
	end
	local progress = tutorialProgress[player]
	if progress then
		progress.completed = false
		progress.completedAt = 0
		progress.lastStep = 0
		saveTutorialProgress(player)
		print(string.format("✅ Tutorial resetado para %s", player.Name))
	end
end

print([[
╔════════════════════════════════════════════════════╗
║  ✅ TUTORIAL SYSTEM SERVER V2 CARREGADO           ║
╠════════════════════════════════════════════════════╣
║  SUBSTITUI: TutorialSystemServer V1               ║
║  REMOVER:   TutorialSystemServer V1               ║
╠════════════════════════════════════════════════════╣
║  NOVIDADES V2:                                     ║
║  • 15 passos interativos (era 10 slides)          ║
║  • Conteúdo interativo agora no CLIENT V4         ║
║  • Remote GetTutorialStepCount adicionado         ║
║  • Campo lastStep salvo no DataStore              ║
╠════════════════════════════════════════════════════╣
║  REMOTES:                                          ║
║  • GetTutorialProgress  → RemoteFunction          ║
║  • CompleteTutorial     ← RemoteEvent             ║
║  • GetTutorialSlides    → RemoteFunction (compat) ║
║  • GetTutorialStepCount → RemoteFunction (novo)   ║
╠════════════════════════════════════════════════════╣
║  DEBUG:                                            ║
║  • _G.DebugTutorial("NomeJogador")                ║
║  • _G.ResetTutorial("NomeJogador")                ║
╚════════════════════════════════════════════════════╝
]])
