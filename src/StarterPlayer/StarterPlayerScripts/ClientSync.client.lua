-- Client Sync Script APRIMORADO
-- Coloque este script em StarterPlayer > StarterPlayerScripts

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer

-- Aguardar remotes
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local updateStatsRemote = remotes:WaitForChild("UpdateStats")
local getPlayerDataRemote = remotes:WaitForChild("GetPlayerData", 10)

-- Variáveis de controle
local lastUpdateTime = 0
local updateCooldown = 0.5
local playerData = nil

-- Função global para atualizar dados
_G.updatePlayerData = function()
	if not getPlayerDataRemote then
		return
	end

	local success, data = pcall(function()
		return getPlayerDataRemote:InvokeServer()
	end)

	if success and data then
		playerData = data

		-- Atualizar todas as interfaces
		local playerGui = player:WaitForChild("PlayerGui")

		-- Atualizar menu de personagens
		local charMenu = playerGui:FindFirstChild("RetroCharacterMenu")
		if charMenu then
			local refreshFunc = charMenu:FindFirstChild("RefreshCategory")
			if refreshFunc and refreshFunc:IsA("BindableFunction") then
				pcall(function()
					refreshFunc:Invoke()
				end)
			end
		end

		-- Atualizar menu admin
		local adminMenu = playerGui:FindFirstChild("AdminMenuRetro")
		if adminMenu then
			local updateFunc = adminMenu:FindFirstChild("UpdatePlayersList")
			if updateFunc and updateFunc:IsA("BindableFunction") then
				pcall(function()
					updateFunc:Invoke()
				end)
			end
		end

		return data
	end

	return nil
end

-- Conectar ao evento de atualização do servidor
updateStatsRemote.OnClientEvent:Connect(function(data)
	-- Verificar cooldown
	local currentTime = tick()
	if currentTime - lastUpdateTime < updateCooldown then
		return
	end
	lastUpdateTime = currentTime

	-- Processar notificações admin
	if data.adminNotification then
		print("[ADMIN]", data.adminNotification)
		data.adminNotification = nil
	end

	-- Atualizar dados locais
	playerData = data

	-- Forçar atualização das interfaces
	task.spawn(function()
		_G.updatePlayerData()
	end)

	print("[SYNC] Dados sincronizados com o servidor")
end)

-- Função global para forçar atualização
_G.ForceUpdateStats = function()
	return _G.updatePlayerData()
end

-- Função global para obter dados cached
_G.GetCachedPlayerData = function()
	return playerData
end

-- Monitorar mudanças no leaderstats
local function monitorLeaderstats()
	local leaderstats = player:WaitForChild("leaderstats", 10)
	if not leaderstats then
		return
	end

	local debounce = {}

	-- Função para criar listener com debounce
	local function createListener(statName)
		local stat = leaderstats:FindFirstChild(statName)
		if stat then
			stat.Changed:Connect(function()
				if debounce[statName] then
					return
				end
				debounce[statName] = true

				task.wait(0.5)
				_G.updatePlayerData()
				debounce[statName] = false
			end)
		end
	end

	-- Criar listeners para cada stat
	createListener("Coins")
	createListener("Bounty")
	createListener("Deaths")
end

-- Conectar quando spawnar
player.CharacterAdded:Connect(function()
	task.wait(1)
	monitorLeaderstats()
	_G.updatePlayerData()
end)

-- Se já tem personagem
if player.Character then
	task.spawn(function()
		monitorLeaderstats()
		_G.updatePlayerData()
	end)
end

-- Sincronização periódica inteligente
task.spawn(function()
	while true do
		task.wait(15) -- A cada 15 segundos

		-- Só atualizar se alguma interface estiver aberta
		local playerGui = player:WaitForChild("PlayerGui")
		local hasOpenMenu = false

		local charMenu = playerGui:FindFirstChild("RetroCharacterMenu")
		if charMenu then
			local mainFrame = charMenu:FindFirstChild("Frame")
			if mainFrame and mainFrame.Visible then
				hasOpenMenu = true
			end
		end

		local adminMenu = playerGui:FindFirstChild("AdminMenuRetro")
		if adminMenu then
			local mainFrame = adminMenu:FindFirstChild("Frame")
			if mainFrame and mainFrame.Visible then
				hasOpenMenu = true
			end
		end

		if hasOpenMenu then
			_G.updatePlayerData()
		end
	end
end)

-- Criar conexão heartbeat para updates críticos
local lastHeartbeat = 0
RunService.Heartbeat:Connect(function()
	local now = tick()
	if now - lastHeartbeat > 1 then
		lastHeartbeat = now

		-- Verificar se há dados pendentes
		if not playerData then
			task.spawn(function()
				_G.updatePlayerData()
			end)
		end
	end
end)

print("[CLIENT SYNC] Sistema de sincronização aprimorado carregado!")
print("[SYNC] Funções disponíveis:")
print("  _G.updatePlayerData() - Atualizar dados")
print("  _G.ForceUpdateStats() - Forçar atualização")
print("  _G.GetCachedPlayerData() - Obter dados cached")
