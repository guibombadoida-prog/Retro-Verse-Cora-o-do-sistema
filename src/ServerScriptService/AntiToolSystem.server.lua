-- ============================================
-- ANTI-TOOL SYSTEM V2
-- (V2) ALTERAÇÕES: spawn() -> task.spawn() (conformidade do projeto)
-- Coloque em ServerScriptService
-- Nome: "AntiToolSystem"
-- ============================================
-- FUNÇÃO:
-- • Impede jogadores de equiparem Tools após morrer
-- • Bloqueia forcedamente até o próximo respawn
-- • Libera automaticamente ao renascer
-- ============================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

print([[
╔════════════════════════════════════════════╗
║   ANTI-TOOL SYSTEM V1 - INICIALIZANDO     ║
╚════════════════════════════════════════════╝
]])

-- =====================================
-- VARIÁVEIS DE CONTROLE
-- =====================================

local deadPlayers = {}
local toolConnections = {}

-- =====================================
-- FUNÇÕES DE BLOQUEIO
-- =====================================

local function forceUnequipAll(player)
	if not player.Character then
		return
	end

	local character = player.Character

	-- Desequipar todas as ferramentas do personagem
	for _, item in pairs(character:GetChildren()) do
		if item:IsA("Tool") then
			item.Parent = player.Backpack
		end
	end
end

local function blockToolEquip(player)
	local backpack = player:FindFirstChild("Backpack")
	if not backpack then
		return
	end

	-- Limpar conexões antigas
	if toolConnections[player] then
		for _, connection in pairs(toolConnections[player]) do
			pcall(function()
				connection:Disconnect()
			end)
		end
		toolConnections[player] = {}
	else
		toolConnections[player] = {}
	end

	-- Monitorar todas as ferramentas no backpack
	for _, tool in pairs(backpack:GetChildren()) do
		if tool:IsA("Tool") then
			local connection = tool.Equipped:Connect(function()
				if deadPlayers[player] then
					-- Forçar desequipar
					task.wait()
					tool.Parent = backpack

					print(
						string.format(
							"[ANTI-TOOL V1] 🚫 Bloqueou equipamento de %s para %s (morto)",
							tool.Name,
							player.Name
						)
					)
				end
			end)

			table.insert(toolConnections[player], connection)
		end
	end

	-- Monitorar novas ferramentas adicionadas
	local childAddedConnection = backpack.ChildAdded:Connect(function(tool)
		if tool:IsA("Tool") and deadPlayers[player] then
			task.wait(0.1)

			local connection = tool.Equipped:Connect(function()
				if deadPlayers[player] then
					task.wait()
					tool.Parent = backpack

					print(
						string.format(
							"[ANTI-TOOL V1] 🚫 Bloqueou equipamento de %s para %s (morto)",
							tool.Name,
							player.Name
						)
					)
				end
			end)

			table.insert(toolConnections[player], connection)
		end
	end)

	table.insert(toolConnections[player], childAddedConnection)
end

local function unblockToolEquip(player)
	-- Remover do registro de mortos
	deadPlayers[player] = nil

	-- Desconectar todos os listeners
	if toolConnections[player] then
		for _, connection in pairs(toolConnections[player]) do
			pcall(function()
				connection:Disconnect()
			end)
		end
		toolConnections[player] = nil
	end

	print(string.format("[ANTI-TOOL V1] ✅ Desbloqueou ferramentas para %s", player.Name))
end

-- =====================================
-- MONITORAMENTO DE MORTE/RESPAWN
-- =====================================

local function onCharacterAdded(character)
	local player = Players:GetPlayerFromCharacter(character)
	if not player then
		return
	end

	local humanoid = character:WaitForChild("Humanoid", 5)
	if not humanoid then
		return
	end

	-- Desbloquear ao spawnar (mesmo se estava morto antes)
	unblockToolEquip(player)

	print(string.format("[ANTI-TOOL V1] 🔄 %s spawnou - Ferramentas liberadas", player.Name))

	-- Monitorar morte
	humanoid.Died:Connect(function()
		print(string.format("[ANTI-TOOL V1] 💀 %s morreu - Bloqueando ferramentas", player.Name))

		-- Marcar como morto
		deadPlayers[player] = true

		-- Forçar desequipar imediatamente
		forceUnequipAll(player)

		-- Bloquear equipamento futuro
		task.wait(0.1)
		blockToolEquip(player)

		-- Loop de segurança: força desequipar a cada 0.1s enquanto morto
		task.spawn(function()
			while deadPlayers[player] and player.Parent do
				forceUnequipAll(player)
				task.wait(0.1)
			end
		end)
	end)
end

-- =====================================
-- EVENTOS DE JOGADOR
-- =====================================

Players.PlayerAdded:Connect(function(player)
	print(string.format("[ANTI-TOOL V1] 👤 %s conectou", player.Name))

	-- Conectar ao CharacterAdded
	player.CharacterAdded:Connect(onCharacterAdded)

	-- Se já tem personagem
	if player.Character then
		onCharacterAdded(player.Character)
	end
end)

Players.PlayerRemoving:Connect(function(player)
	print(string.format("[ANTI-TOOL V1] 👋 %s desconectou", player.Name))

	-- Limpar dados
	unblockToolEquip(player)
	deadPlayers[player] = nil
end)

-- =====================================
-- INICIALIZAÇÃO PARA JOGADORES EXISTENTES
-- =====================================

for _, player in pairs(Players:GetPlayers()) do
	if player.Character then
		onCharacterAdded(player.Character)
	end

	player.CharacterAdded:Connect(onCharacterAdded)
end

-- =====================================
-- SISTEMA DE MONITORAMENTO CONTÍNUO
-- =====================================

task.spawn(function()
	while true do
		task.wait(0.2)

		-- Verificar todos os jogadores mortos
		for player, isDead in pairs(deadPlayers) do
			if isDead and player.Parent then
				-- Forçar desequipar constantemente
				forceUnequipAll(player)
			end
		end
	end
end)

-- =====================================
-- DEBUG
-- =====================================

_G.DebugAntiTool = function(playerName)
	local player = Players:FindFirstChild(playerName)
	if not player then
		print("❌ Jogador não encontrado")
		return
	end

	print("\n========== DEBUG ANTI-TOOL ==========")
	print(string.format("Jogador: %s", player.Name))
	print(string.format("Está Morto: %s", deadPlayers[player] and "Sim" or "Não"))
	print(
		string.format(
			"Conexões Ativas: %d",
			toolConnections[player] and #toolConnections[player] or 0
		)
	)

	if player.Character then
		local equippedTools = 0
		for _, item in pairs(player.Character:GetChildren()) do
			if item:IsA("Tool") then
				equippedTools = equippedTools + 1
				print(string.format("  Tool Equipada: %s", item.Name))
			end
		end
		print(string.format("Tools Equipadas: %d", equippedTools))
	end

	local backpack = player:FindFirstChild("Backpack")
	if backpack then
		local backpackTools = 0
		for _, item in pairs(backpack:GetChildren()) do
			if item:IsA("Tool") then
				backpackTools = backpackTools + 1
			end
		end
		print(string.format("Tools no Backpack: %d", backpackTools))
	end

	print("=====================================\n")
end

_G.ForceUnblockTools = function(playerName)
	local player = Players:FindFirstChild(playerName)
	if not player then
		print("❌ Jogador não encontrado")
		return
	end

	unblockToolEquip(player)
	print(string.format("✅ Ferramentas forçadamente desbloqueadas para %s", player.Name))
end

print([[
╔════════════════════════════════════════════════════╗
║  ✅ ANTI-TOOL SYSTEM V1 CARREGADO                 ║
╠════════════════════════════════════════════════════╣
║  FUNCIONAMENTO:                                    ║
║  • Jogador morre → Ferramentas bloqueadas 🚫      ║
║  • Jogador spawna → Ferramentas liberadas ✅       ║
║  • Bloqueio forçado e contínuo enquanto morto     ║
╠════════════════════════════════════════════════════╣
║  CARACTERÍSTICAS:                                  ║
║  • Desequipa automaticamente ao morrer            ║
║  • Impede equipar qualquer Tool após morte        ║
║  • Loop de segurança a cada 0.1s                  ║
║  • Sistema de conexões otimizado                  ║
║  • Libera automaticamente ao respawn              ║
╠════════════════════════════════════════════════════╣
║  DEBUG:                                            ║
║  • _G.DebugAntiTool("NomeJogador")                ║
║  • _G.ForceUnblockTools("NomeJogador")            ║
╚════════════════════════════════════════════════════╝
]])
