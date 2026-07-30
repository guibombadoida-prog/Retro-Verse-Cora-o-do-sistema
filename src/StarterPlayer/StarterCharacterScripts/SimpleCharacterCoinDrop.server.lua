-- Script: Simple Character Coin Drop V2
-- (V2) ALTERAÇÕES: wait() -> task.wait(); :Destroy() -> .Parent = nil; posição do drop sem math.random (offset fixo); fonte retro
-- Coloque este script em StarterPlayer > StarterCharacterScripts

local Character = script.Parent
local Humanoid = Character:WaitForChild("Humanoid")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")

-- Configurações
local DROP_PERCENTAGE = 0.1 -- 10% das moedas
local MIN_DROP = 10
local MAX_DROP = 5000
local DROP_LIFETIME = 60

-- Aguardar sistema estar pronto
repeat
	task.wait()
until _G.PlayerDataManager

-- Obter remotes
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local updateCoinsRemote = remotes:FindFirstChild("UpdateCoinsDisplay")
if not updateCoinsRemote then
	updateCoinsRemote = Instance.new("RemoteEvent")
	updateCoinsRemote.Name = "UpdateCoinsDisplay"
	updateCoinsRemote.Parent = remotes
end

Humanoid.Died:Connect(function()
	-- Obter jogador
	local player = Players:GetPlayerFromCharacter(Character)
	if not player then
		return
	end

	-- Obter dados do jogador
	local playerData = _G.PlayerDataManager.getPlayerData(player)
	if not playerData then
		return
	end

	local currentCoins = playerData.coins or 0

	-- Verificar se tem moedas suficientes
	if currentCoins < MIN_DROP then
		return
	end

	-- Calcular quantidade
	local dropAmount = math.floor(currentCoins * DROP_PERCENTAGE)
	dropAmount = math.max(MIN_DROP, math.min(dropAmount, MAX_DROP))

	-- Verificar se o modelo existe
	local DropCash = ReplicatedStorage:FindFirstChild("DropCash")
	if not DropCash then
		warn("Modelo DropCash não encontrado!")
		return
	end

	-- Criar o drop
	local drop = DropCash:Clone()

	-- Armazenar o dono original
	local ownerValue = Instance.new("ObjectValue")
	ownerValue.Name = "OriginalOwner"
	ownerValue.Value = player
	ownerValue.Parent = drop

	-- Configurar quantidade
	if drop:FindFirstChild("AmountOfCash") then
		drop.AmountOfCash.Value = dropAmount
	end

	-- Configurar visual
	if drop:FindFirstChild("BillboardGui") and drop.BillboardGui:FindFirstChild("amount") then
		drop.BillboardGui.amount.Text = dropAmount .. "$"
	end

	-- Configurar ProximityPrompt
	if drop:FindFirstChild("ProximityPrompt") then
		drop.ProximityPrompt.ObjectText = player.Name .. "'s Cash"

		-- Conectar evento de coleta
		drop.ProximityPrompt.Triggered:Connect(function(collector)
			-- Verificar se ainda existe
			if not drop or not drop.Parent then
				return
			end

			-- Impedir que o próprio jogador pegue
			if collector == player then
				-- Mostrar mensagem
				local gui = collector:FindFirstChild("PlayerGui")
				if gui then
					local message = Instance.new("ScreenGui")
					message.Name = "CoinMessage"
					message.Parent = gui

					local label = Instance.new("TextLabel")
					label.Size = UDim2.new(0.4, 0, 0.1, 0)
					label.Position = UDim2.new(0.3, 0, 0.8, 0)
					label.BackgroundColor3 = Color3.new(0, 0, 0)
					label.BackgroundTransparency = 0.3
					label.Text = "Você não pode pegar suas próprias moedas!"
					label.TextColor3 = Color3.new(1, 0, 0)
					label.TextScaled = true
					label.Font = Enum.Font.Arcade
					label.Parent = message

					game:GetService("Debris"):AddItem(message, 2)
				end
				return
			end

			-- Desabilitar prompt para evitar múltiplas coletas
			drop.ProximityPrompt.Enabled = false

			-- Adicionar moedas ao coletor
			_G.PlayerDataManager.updateCoins(collector, dropAmount)

			-- Atualizar leaderstats do coletor
			local collectorData = _G.PlayerDataManager.getPlayerData(collector)
			if collectorData and collector:FindFirstChild("leaderstats") then
				local coins = collector.leaderstats:FindFirstChild("Coins")
				if coins then
					coins.Value = collectorData.coins
				end
			end

			-- Notificar cliente para atualizar menu
			updateCoinsRemote:FireClient(collector, collectorData.coins)

			-- Destruir drop
			drop.Parent = nil
		end)
	end

	-- Posicionar drop
	if Character:FindFirstChild("HumanoidRootPart") then
		-- (V2) Offset FIXO pré-definido (regra do projeto: sem Randomize)
		drop.Position = Character.HumanoidRootPart.Position
			+ Vector3.new(2, 1, 2)
	end

	-- Adicionar ao workspace
	drop.Parent = workspace

	-- Remover moedas do jogador que morreu
	_G.PlayerDataManager.updateCoins(player, -dropAmount)

	-- Atualizar leaderstats
	if player:FindFirstChild("leaderstats") then
		local coins = player.leaderstats:FindFirstChild("Coins")
		if coins then
			coins.Value = playerData.coins
		end
	end

	-- Notificar cliente
	updateCoinsRemote:FireClient(player, playerData.coins)

	-- Auto destruir
	Debris:AddItem(drop, DROP_LIFETIME)

	print(player.Name .. " dropou " .. dropAmount .. " moedas!")
end)
