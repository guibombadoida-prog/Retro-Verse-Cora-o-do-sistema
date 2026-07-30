-- ============================================
-- SISTEMA DE SINCRONIZAÇÃO GLOBAL V2
-- Coloque em ServerScriptService
-- Nome: "GlobalSync"
-- SUBSTITUI: GlobalSync V1
-- ============================================
-- (V2) ALTERAÇÕES:
-- • DONO ÚNICO da sincronização periódica de UpdateStats
--   (o loop duplicado foi REMOVIDO do MainSystemInitializer_V2 —
--   antes o UpdateStats disparava 2x a cada 5s)
-- • DONO ÚNICO dos comandos: _G.DebugPlayerStatus,
--   _G.TeleportToSafeZone e _G.ForceSelectCharacter
--   (as cópias duplicadas foram REMOVIDAS do MainSystemInitializer_V2)
-- • wait()/spawn() -> task.wait()/task.spawn() (conformidade)
-- • Esperas com TIMEOUT (não trava o boot para sempre)
-- • Teleporte da zona segura padronizado em Y = 505 (lobby oficial)
-- • DebugPlayerStatus enriquecido (REUTILIZADO do
--   MainSystemInitializer V1: HP/Speed/Jump/Posição)
-- ============================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- =====================================
-- ESPERA DOS SISTEMAS (com timeout)
-- =====================================

local function waitForGlobal(name, timeout, optional)
	local t = 0
	while not _G[name] and t < timeout do
		task.wait(0.2)
		t += 0.2
	end
	if _G[name] then
		print("[SYNC V2] ✓ Sistema carregado: " .. name)
		return true
	end
	if optional then
		warn("[SYNC V2] ⚠️ Sistema opcional ausente: " .. name)
	else
		warn("[SYNC V2] ❌ Sistema obrigatório ausente: " .. name)
	end
	return false
end

waitForGlobal("PlayerDataManager", 30, false)
waitForGlobal("SetSpectatorMode", 10, true)
waitForGlobal("GetPlayerTeam", 10, true)

-- =====================================
-- REMOTES
-- =====================================

local remotes = ReplicatedStorage:FindFirstChild("Remotes")
if not remotes then
	remotes = Instance.new("Folder")
	remotes.Name = "Remotes"
	remotes.Parent = ReplicatedStorage
end

local updateStatsRemote = remotes:FindFirstChild("UpdateStats")
if not updateStatsRemote then
	updateStatsRemote = Instance.new("RemoteEvent")
	updateStatsRemote.Name = "UpdateStats"
	updateStatsRemote.Parent = remotes
end

-- =====================================
-- SINCRONIZAÇÃO (núcleo)
-- =====================================

local function buildPlayerPayload(player)
	if not _G.PlayerDataManager then
		return nil
	end
	local data = _G.PlayerDataManager.getPlayerData(player)
	if not data then
		return nil
	end

	-- Informações extras de time (se o sistema existir)
	if _G.GetPlayerTeam then
		local ok, team = pcall(_G.GetPlayerTeam, player)
		if ok and team then
			data.currentTeam = {
				name = team.name,
				color = team.color,
				members = #team.members,
				isLeader = team.leader == player,
			}
		end
	end

	return data
end

local function syncPlayer(player)
	pcall(function()
		local data = buildPlayerPayload(player)
		if data then
			updateStatsRemote:FireClient(player, data)
		end
	end)
end

local function syncAllPlayerData()
	for _, player in pairs(Players:GetPlayers()) do
		syncPlayer(player)
	end
end

-- Loop ÚNICO de sincronização periódica (a cada 5 segundos)
task.spawn(function()
	while true do
		task.wait(5)
		syncAllPlayerData()
	end
end)

-- =====================================
-- SYNC REATIVO (leaderstats mudou)
-- =====================================

local function onPlayerDataChanged(player)
	task.wait(0.1)
	syncPlayer(player)
end

local function hookLeaderstats(player)
	task.wait(2)

	local leaderstats = player:WaitForChild("leaderstats", 10)
	if leaderstats then
		for _, stat in pairs(leaderstats:GetChildren()) do
			if stat:IsA("IntValue") or stat:IsA("NumberValue") then
				stat.Changed:Connect(function()
					onPlayerDataChanged(player)
				end)
			end
		end
	end

	-- Sincronizar dados iniciais
	onPlayerDataChanged(player)
end

Players.PlayerAdded:Connect(function(player)
	task.spawn(hookLeaderstats, player)
end)

-- Jogadores que já estavam no servidor quando o script subiu
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(hookLeaderstats, player)
end

-- =====================================
-- COMANDOS DE DEBUG (dono único: GlobalSync V2)
-- =====================================

_G.DebugPlayerStatus = function(playerName)
	local player = Players:FindFirstChild(playerName)
	if not player then
		print("❌ Jogador não encontrado: " .. tostring(playerName))
		return
	end

	print("\n========== DEBUG: " .. playerName .. " ==========")

	-- Dados do jogador
	if _G.PlayerDataManager then
		local data = _G.PlayerDataManager.getPlayerData(player)
		if data then
			print("💰 Moedas: " .. tostring(data.coins))
			print("⚔️ Bounty: " .. tostring(data.stats and data.stats.bounty or 0))
			print("💀 Mortes: " .. tostring(data.stats and data.stats.deaths or 0))
			print("🎮 Personagem: " .. tostring(data.equippedCharacter or "Nenhum"))
			print("📦 Inventário: " .. table.concat(data.ownedCharacters or {}, ", "))
		end
	end

	-- Time
	if _G.GetPlayerTeam then
		local ok, team = pcall(_G.GetPlayerTeam, player)
		if ok and team then
			print("👥 Time: " .. team.name)
			print("   Líder: " .. team.leader.Name)
			print("   Membros: " .. #team.members)
		else
			print("👥 Time: Nenhum")
		end
	end

	-- Estado do personagem (REUTILIZADO do MainSystemInitializer V1)
	if player.Character then
		local humanoid = player.Character:FindFirstChild("Humanoid")
		if humanoid then
			print("❤️ HP: " .. humanoid.Health .. "/" .. humanoid.MaxHealth)
			print("🏃 Speed: " .. humanoid.WalkSpeed)
			print("⬆️ Jump: " .. humanoid.JumpPower)
		end

		local inSafeZone = player.Character:FindFirstChild("InSafeZone")
		print("🛡️ Zona Segura: " .. (inSafeZone and "Sim" or "Não"))

		local hrp = player.Character:FindFirstChild("HumanoidRootPart")
		if hrp then
			print("📍 Posição: " .. string.format(
				"%.1f, %.1f, %.1f",
				hrp.Position.X,
				hrp.Position.Y,
				hrp.Position.Z
				))
		end
	end

	print("=====================================\n")
end

_G.TeleportToSafeZone = function(playerName)
	local player = Players:FindFirstChild(playerName)
	if player and player.Character then
		local hrp = player.Character:FindFirstChild("HumanoidRootPart")
		if hrp then
			hrp.CFrame = CFrame.new(0, 505, 0) -- (V2) Y=505 = lobby oficial
			print("✓ " .. playerName .. " teleportado para zona segura")
		end
	else
		print("❌ Erro ao teleportar " .. tostring(playerName))
	end
end

_G.ForceSelectCharacter = function(playerName, characterName)
	local player = Players:FindFirstChild(playerName)
	if player then
		if _G.OnCharacterSelected then
			_G.OnCharacterSelected(player, characterName)
			print("✓ " .. playerName .. " forçado a equipar " .. characterName)
		end
	else
		print("❌ Jogador não encontrado")
	end
end

print([[
╔════════════════════════════════════════════╗
║     SINCRONIZAÇÃO GLOBAL V2 ATIVA         ║
╠════════════════════════════════════════════╣
║  Dono único do sync de UpdateStats (5s)   ║
║  Comandos de Debug (donos aqui):          ║
║  _G.DebugPlayerStatus("Nome")              ║
║  _G.TeleportToSafeZone("Nome")            ║
║  _G.ForceSelectCharacter("Nome", "Char")  ║
╚════════════════════════════════════════════╝
]])
