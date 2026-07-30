-- ============================================
-- SISTEMA DE TIMES V4 - GRANDE RETRABALHADO
-- (V4) ALTERAÇÕES: wait()/spawn() -> task.*; :Destroy() -> .Parent = nil; fontes retro (Arcade/Code)
-- Coloque em ServerScriptService
-- Nome: "TeamSystemServer"
-- SUBSTITUI: TeamSystemServer V2
-- ============================================
-- CORREÇÕES V3:
-- • Time é DELETADO quando líder sai (bug corrigido)
-- • Sistema de TAG REMOVIDO (não atravessa mais parede)
-- • Transferência de liderança robusta
-- • Sistema de limpeza automático aprimorado
-- • Integrado com sistema de seleção de personagens
-- ============================================

local Players = game:GetService("Players")
local Teams = game:GetService("Teams")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

-- Aguardar sistemas essenciais
repeat
	task.wait()
until _G.PlayerDataManager
task.wait(1)

print([[
╔════════════════════════════════════════════╗
║   SISTEMA DE TIMES V3 - INICIANDO         ║
╚════════════════════════════════════════════╝
]])

-- =====================================
-- CONFIGURAÇÃO
-- =====================================

local CONFIG = {
	MAX_TEAM_SIZE = 4,
	INVITE_TIMEOUT = 20,
	MAX_TEAM_NAME_LENGTH = 20,
	MIN_TEAM_NAME_LENGTH = 3,
	TEAM_PREFIX = "[TEAM] ",
	MAX_TEAMS = 15,

	-- 15 cores únicas disponíveis
	COLORS = {
		{ name = "Vermelho", color = Color3.fromRGB(255, 0, 0) },
		{ name = "Azul", color = Color3.fromRGB(0, 100, 255) },
		{ name = "Verde", color = Color3.fromRGB(0, 200, 0) },
		{ name = "Amarelo", color = Color3.fromRGB(255, 200, 0) },
		{ name = "Roxo", color = Color3.fromRGB(180, 0, 255) },
		{ name = "Laranja", color = Color3.fromRGB(255, 150, 0) },
		{ name = "Ciano", color = Color3.fromRGB(0, 255, 255) },
		{ name = "Rosa", color = Color3.fromRGB(255, 100, 200) },
		{ name = "Lima", color = Color3.fromRGB(150, 255, 0) },
		{ name = "Magenta", color = Color3.fromRGB(255, 0, 150) },
		{ name = "Turquesa", color = Color3.fromRGB(0, 200, 200) },
		{ name = "Dourado", color = Color3.fromRGB(255, 215, 0) },
		{ name = "Prata", color = Color3.fromRGB(192, 192, 192) },
		{ name = "Bronze", color = Color3.fromRGB(205, 127, 50) },
		{ name = "Índigo", color = Color3.fromRGB(75, 0, 130) },
	},
}

-- =====================================
-- CRIAR/VERIFICAR REMOTES
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
		print("  ✓ Remote criado: " .. name)
	end
	return remote
end

local createTeamRemote = getOrCreateRemote("CreateTeam", "Function")
local inviteToTeamRemote = getOrCreateRemote("InviteToTeam", "Event")
local respondToInviteRemote = getOrCreateRemote("RespondToInvite", "Event")
local leaveTeamRemote = getOrCreateRemote("LeaveTeam", "Event")
local updateTeamListRemote = getOrCreateRemote("UpdateTeamList", "Event")
local kickFromTeamRemote = getOrCreateRemote("KickFromTeam", "Event")
local promoteLeaderRemote = getOrCreateRemote("PromoteLeader", "Event")
local getAvailableColorsRemote = getOrCreateRemote("GetAvailableColors", "Function")

-- =====================================
-- DADOS GLOBAIS
-- =====================================

local customTeams = {}
local playerTeams = {}
local pendingInvites = {}
local teamObjects = {}
local usedColors = {}

-- =====================================
-- FUNÇÕES DE CORES
-- =====================================

local function isColorAvailable(color)
	for usedColor, teamId in pairs(usedColors) do
		if usedColor == color then
			if customTeams[teamId] then
				return false, "Esta cor já está sendo usada por outro time!"
			else
				usedColors[usedColor] = nil
				return true
			end
		end
	end
	return true
end

local function getAvailableColors()
	local available = {}

	for _, colorData in ipairs(CONFIG.COLORS) do
		local isAvailable, reason = isColorAvailable(colorData.color)

		table.insert(available, {
			name = colorData.name,
			color = colorData.color,
			available = isAvailable,
		})
	end

	return available
end

local function releaseColor(teamId)
	for color, id in pairs(usedColors) do
		if id == teamId then
			usedColors[color] = nil
			print(string.format("[TEAM COLORS V3] Cor liberada do time %s", teamId))
			break
		end
	end
end

local function reserveColor(color, teamId)
	usedColors[color] = teamId
	print(string.format("[TEAM COLORS V3] Cor reservada para time %s", teamId))
end

-- =====================================
-- FUNÇÕES AUXILIARES
-- =====================================

local function broadcastTeamUpdate()
	local teamsList = {}

	for teamId, teamData in pairs(customTeams) do
		table.insert(teamsList, {
			id = teamData.id,
			name = teamData.name,
			leader = teamData.leader,
			members = teamData.members,
			color = teamData.color,
			stats = teamData.stats,
		})
	end

	updateTeamListRemote:FireAllClients(teamsList)

	for _, player in pairs(Players:GetPlayers()) do
		pcall(function()
			local availableColors = getAvailableColors()
			local updateColorsRemote = remotes:FindFirstChild("UpdateAvailableColors")
			if updateColorsRemote then
				updateColorsRemote:FireClient(player, availableColors)
			end
		end)
	end
end

local function isValidTeamName(name)
	if #name < CONFIG.MIN_TEAM_NAME_LENGTH or #name > CONFIG.MAX_TEAM_NAME_LENGTH then
		return false,
		string.format(
			"Nome deve ter entre %d e %d caracteres",
			CONFIG.MIN_TEAM_NAME_LENGTH,
			CONFIG.MAX_TEAM_NAME_LENGTH
		)
	end

	if name:match("[^%w%s%-_]") then
		return false, "Nome contém caracteres inválidos"
	end

	for _, team in pairs(customTeams) do
		if team.name:lower() == name:lower() then
			return false, "Nome de time já existe"
		end
	end

	return true, "Válido"
end

local function isValidColor(color)
	for _, validColor in ipairs(CONFIG.COLORS) do
		if validColor.color == color then
			return true
		end
	end
	return false
end

-- =====================================
-- GERENCIAMENTO DE TIMES ROBLOX
-- =====================================

local function createRobloxTeam(teamData)
	if teamObjects[teamData.id] then
		teamObjects[teamData.id].Parent = nil
	end

	local team = Instance.new("Team")
	team.Name = CONFIG.TEAM_PREFIX .. teamData.name
	team.TeamColor = BrickColor.new(teamData.color)
	team.AutoAssignable = false
	team.Parent = Teams

	teamObjects[teamData.id] = team

	print(string.format("[TEAM V3] Time Roblox criado: %s", team.Name))
	return team
end

local function assignPlayerToTeam(player, teamData)
	if not teamData then
		player.Team = nil
		player.Neutral = true
		return
	end

	local teamObj = teamObjects[teamData.id]
	if teamObj then
		player.Team = teamObj
		player.Neutral = false
		print(string.format("[TEAM V3] %s atribuído ao time %s", player.Name, teamData.name))
	end
end

-- =====================================
-- CORREÇÃO V3: DELETAR TIME COMPLETO
-- =====================================

local function deleteTeam(teamId, reason)
	local team = customTeams[teamId]
	if not team then
		return
	end

	print(string.format("[TEAM V3] Deletando time '%s' - Razão: %s", team.name, reason))

	-- Notificar todos os membros
	for _, member in pairs(team.members) do
		if member and member.Parent then
			playerTeams[member] = nil
			member.Team = nil
			member.Neutral = true

			-- Notificar membro
			local gui = member:FindFirstChild("PlayerGui")
			if gui then
				local notification = Instance.new("ScreenGui")
				notification.Name = "TeamDeletedNotification"
				notification.Parent = gui

				local frame = Instance.new("Frame")
				frame.Size = UDim2.new(0.4, 0, 0.12, 0)
				frame.Position = UDim2.new(0.3, 0, 0.45, 0)
				frame.BackgroundColor3 = Color3.fromRGB(150, 0, 0)
				frame.BorderSizePixel = 3
				frame.BorderColor3 = Color3.new(1, 1, 1)
				frame.Parent = notification

				local text = Instance.new("TextLabel")
				text.Size = UDim2.new(1, 0, 1, 0)
				text.BackgroundTransparency = 1
				text.Text = "⚠️ Time '" .. team.name .. "' foi dissolvido!"
				text.TextColor3 = Color3.new(1, 1, 1)
				text.TextScaled = true
				text.Font = Enum.Font.Arcade
				text.Parent = frame

				game:GetService("Debris"):AddItem(notification, 5)
			end
		end
	end

	-- Deletar time Roblox
	if teamObjects[teamId] then
		teamObjects[teamId].Parent = nil
		teamObjects[teamId] = nil
	end

	-- Liberar cor
	releaseColor(teamId)

	-- Remover time da lista
	customTeams[teamId] = nil

	-- Broadcast
	broadcastTeamUpdate()
end

-- =====================================
-- FUNÇÕES PRINCIPAIS DO SISTEMA
-- =====================================

local function createTeam(leader, teamName, teamColor)
	if playerTeams[leader] then
		return false, "Você já está em um time!"
	end

	local teamCount = 0
	for _ in pairs(customTeams) do
		teamCount = teamCount + 1
	end

	if teamCount >= CONFIG.MAX_TEAMS then
		return false, "Limite máximo de times atingido!"
	end

	local valid, message = isValidTeamName(teamName)
	if not valid then
		return false, message
	end

	if not isValidColor(teamColor) then
		teamColor = CONFIG.COLORS[1].color
	end

	local colorAvailable, colorMessage = isColorAvailable(teamColor)
	if not colorAvailable then
		return false, colorMessage
	end

	local teamId = HttpService:GenerateGUID(false)
	local teamData = {
		id = teamId,
		name = teamName,
		leader = leader,
		members = { leader },
		color = teamColor,
		createdAt = os.time(),
		stats = {
			kills = 0,
			wins = 0,
		},
	}

	customTeams[teamId] = teamData
	playerTeams[leader] = teamId

	reserveColor(teamColor, teamId)
	createRobloxTeam(teamData)
	assignPlayerToTeam(leader, teamData)

	broadcastTeamUpdate()

	print(string.format("[TEAM V3] Time '%s' criado por %s", teamName, leader.Name))
	return true, teamId
end

local function inviteToTeam(leader, targetPlayerName)
	local targetPlayer = Players:FindFirstChild(targetPlayerName)
	if not targetPlayer then
		return false, "Jogador não encontrado!"
	end

	if targetPlayer == leader then
		return false, "Você não pode convidar a si mesmo!"
	end

	local teamId = playerTeams[leader]
	if not teamId then
		return false, "Você não está em um time!"
	end

	local team = customTeams[teamId]
	if not team then
		return false, "Time inválido!"
	end

	if team.leader ~= leader then
		return false, "Apenas o líder pode convidar!"
	end

	if #team.members >= CONFIG.MAX_TEAM_SIZE then
		return false, string.format("Time cheio! (Máximo: %d jogadores)", CONFIG.MAX_TEAM_SIZE)
	end

	if playerTeams[targetPlayer] then
		return false, "Jogador já está em um time!"
	end

	for id, invite in pairs(pendingInvites) do
		if invite.to == targetPlayer and invite.teamId == teamId then
			return false, "Convite já enviado!"
		end
	end

	local inviteId = HttpService:GenerateGUID(false)
	pendingInvites[inviteId] = {
		from = leader,
		to = targetPlayer,
		teamId = teamId,
		expires = os.time() + CONFIG.INVITE_TIMEOUT,
	}

	inviteToTeamRemote:FireClient(targetPlayer, team.name, leader.Name, team.color)

	task.spawn(function()
		task.wait(CONFIG.INVITE_TIMEOUT)
		if pendingInvites[inviteId] then
			pendingInvites[inviteId] = nil
			print(
				string.format(
					"[TEAM V3] Convite expirado: %s -> %s",
					leader.Name,
					targetPlayer.Name
				)
			)
		end
	end)

	print(
		string.format(
			"[TEAM V3] Convite enviado: %s -> %s (%s)",
			leader.Name,
			targetPlayer.Name,
			team.name
		)
	)
	return true, "Convite enviado!"
end

local function joinTeam(player, teamId)
	local team = customTeams[teamId]
	if not team then
		return false, "Time não encontrado!"
	end

	if #team.members >= CONFIG.MAX_TEAM_SIZE then
		return false, "Time cheio!"
	end

	if playerTeams[player] then
		return false, "Você já está em um time!"
	end

	table.insert(team.members, player)
	playerTeams[player] = teamId

	assignPlayerToTeam(player, team)

	-- Notificar membros do time
	for _, member in pairs(team.members) do
		if member ~= player and member.Parent then
			local gui = member:FindFirstChild("PlayerGui")
			if gui then
				local notification = Instance.new("ScreenGui")
				notification.Name = "TeamNotification"
				notification.Parent = gui

				local frame = Instance.new("Frame")
				frame.Size = UDim2.new(0.4, 0, 0.1, 0)
				frame.Position = UDim2.new(0.3, 0, 0.1, 0)
				frame.BackgroundColor3 = team.color
				frame.BorderSizePixel = 3
				frame.BorderColor3 = Color3.new(1, 1, 1)
				frame.Parent = notification

				local text = Instance.new("TextLabel")
				text.Size = UDim2.new(1, 0, 1, 0)
				text.BackgroundTransparency = 1
				text.Text = "✅ " .. player.Name .. " entrou no time!"
				text.TextColor3 = Color3.new(1, 1, 1)
				text.TextScaled = true
				text.Font = Enum.Font.Arcade
				text.Parent = frame

				game:GetService("Debris"):AddItem(notification, 3)
			end
		end
	end

	broadcastTeamUpdate()

	print(string.format("[TEAM V3] %s entrou no time '%s'", player.Name, team.name))
	return true, "Entrou no time!"
end

local function leaveTeam(player)
	local teamId = playerTeams[player]
	if not teamId then
		return false, "Você não está em um time!"
	end

	local team = customTeams[teamId]
	if not team then
		return false, "Time inválido!"
	end

	-- Remover do time
	for i, member in pairs(team.members) do
		if member == player then
			table.remove(team.members, i)
			break
		end
	end

	playerTeams[player] = nil

	player.Team = nil
	player.Neutral = true

	-- CORREÇÃO V3: Se era o líder, DELETAR time completamente
	if team.leader == player then
		deleteTeam(teamId, "Líder saiu do jogo")
		return true, "Time dissolvido!"
	end

	-- Se não era líder e time ficou vazio, deletar
	if #team.members == 0 then
		deleteTeam(teamId, "Time ficou vazio")
	end

	broadcastTeamUpdate()

	print(string.format("[TEAM V3] %s saiu do time '%s'", player.Name, team.name))
	return true, "Saiu do time!"
end

local function kickFromTeam(leader, targetPlayerName)
	local targetPlayer = Players:FindFirstChild(targetPlayerName)
	if not targetPlayer then
		return false, "Jogador não encontrado!"
	end

	local teamId = playerTeams[leader]
	if not teamId then
		return false, "Você não está em um time!"
	end

	local team = customTeams[teamId]
	if team.leader ~= leader then
		return false, "Apenas o líder pode expulsar membros!"
	end

	if targetPlayer == leader then
		return false, "Você não pode se expulsar!"
	end

	if playerTeams[targetPlayer] ~= teamId then
		return false, "Jogador não está no seu time!"
	end

	for i, member in pairs(team.members) do
		if member == targetPlayer then
			table.remove(team.members, i)
			break
		end
	end

	playerTeams[targetPlayer] = nil

	targetPlayer.Team = nil
	targetPlayer.Neutral = true

	local gui = targetPlayer:FindFirstChild("PlayerGui")
	if gui then
		local notification = Instance.new("ScreenGui")
		notification.Name = "KickNotification"
		notification.Parent = gui

		local frame = Instance.new("Frame")
		frame.Size = UDim2.new(0.4, 0, 0.1, 0)
		frame.Position = UDim2.new(0.3, 0, 0.45, 0)
		frame.BackgroundColor3 = Color3.fromRGB(200, 0, 0)
		frame.BorderSizePixel = 3
		frame.BorderColor3 = Color3.new(1, 1, 1)
		frame.Parent = notification

		local text = Instance.new("TextLabel")
		text.Size = UDim2.new(1, 0, 1, 0)
		text.BackgroundTransparency = 1
		text.Text = "❌ Você foi expulso do time!"
		text.TextColor3 = Color3.new(1, 1, 1)
		text.TextScaled = true
		text.Font = Enum.Font.Arcade
		text.Parent = frame

		game:GetService("Debris"):AddItem(notification, 5)
	end

	broadcastTeamUpdate()

	print(string.format("[TEAM V3] %s foi expulso por %s", targetPlayer.Name, leader.Name))
	return true, "Jogador expulso!"
end

-- =====================================
-- PROTEÇÃO CONTRA DANO ENTRE ALIADOS
-- =====================================

local function areTeammates(player1, player2)
	if not player1 or not player2 then
		return false
	end

	local team1 = playerTeams[player1]
	local team2 = playerTeams[player2]

	return team1 and team2 and team1 == team2
end

if _G.RegisterAttack then
	local originalRegisterAttack = _G.RegisterAttack

	_G.RegisterAttack = function(attacker, victim)
		if areTeammates(attacker, victim) then
			return false
		end

		return originalRegisterAttack(attacker, victim)
	end

	print("[TEAM V3] Sistema de proteção de aliados ativado")
end

-- =====================================
-- CONECTAR REMOTES
-- =====================================

createTeamRemote.OnServerInvoke = function(player, teamName, teamColor)
	return createTeam(player, teamName, teamColor)
end

inviteToTeamRemote.OnServerEvent:Connect(function(player, targetName)
	inviteToTeam(player, targetName)
end)

respondToInviteRemote.OnServerEvent:Connect(function(player, accepted)
	if not accepted then
		print(string.format("[TEAM V3] %s recusou convite", player.Name))
		return
	end

	local validInvite = nil
	for id, invite in pairs(pendingInvites) do
		if invite.to == player and invite.expires > os.time() then
			validInvite = invite
			pendingInvites[id] = nil
			break
		end
	end

	if validInvite then
		joinTeam(player, validInvite.teamId)
	else
		print(string.format("[TEAM V3] Convite expirado para %s", player.Name))
	end
end)

leaveTeamRemote.OnServerEvent:Connect(function(player)
	leaveTeam(player)
end)

kickFromTeamRemote.OnServerEvent:Connect(function(leader, targetName)
	kickFromTeam(leader, targetName)
end)

promoteLeaderRemote.OnServerEvent:Connect(function(currentLeader, newLeaderName)
	local newLeader = Players:FindFirstChild(newLeaderName)
	if not newLeader then
		return
	end

	local teamId = playerTeams[currentLeader]
	if not teamId then
		return
	end

	local team = customTeams[teamId]
	if team.leader ~= currentLeader then
		return
	end

	if playerTeams[newLeader] ~= teamId then
		return
	end

	team.leader = newLeader

	broadcastTeamUpdate()

	print(
		string.format(
			"[TEAM V3] Liderança transferida: %s -> %s",
			currentLeader.Name,
			newLeader.Name
		)
	)
end)

getAvailableColorsRemote.OnServerInvoke = function(player)
	return getAvailableColors()
end

-- =====================================
-- EVENTOS DE JOGADOR
-- =====================================

Players.PlayerAdded:Connect(function(player)
	task.wait(2)

	local teamsList = {}
	for teamId, teamData in pairs(customTeams) do
		table.insert(teamsList, {
			id = teamData.id,
			name = teamData.name,
			leader = teamData.leader,
			members = teamData.members,
			color = teamData.color,
			stats = teamData.stats,
		})
	end

	updateTeamListRemote:FireClient(player, teamsList)

	local availableColors = getAvailableColors()
	local updateColorsRemote = remotes:FindFirstChild("UpdateAvailableColors")
		or Instance.new("RemoteEvent")
	updateColorsRemote.Name = "UpdateAvailableColors"
	updateColorsRemote.Parent = remotes
	updateColorsRemote:FireClient(player, availableColors)
end)

Players.PlayerRemoving:Connect(function(player)
	-- CORREÇÃO V3: Deletar time se era líder
	local teamId = playerTeams[player]
	if teamId then
		local team = customTeams[teamId]
		if team and team.leader == player then
			deleteTeam(teamId, "Líder saiu do jogo")
		else
			leaveTeam(player)
		end
	end

	-- Limpar convites pendentes
	for id, invite in pairs(pendingInvites) do
		if invite.from == player or invite.to == player then
			pendingInvites[id] = nil
		end
	end
end)

-- =====================================
-- FUNÇÕES GLOBAIS EXPORTADAS
-- =====================================

_G.GetPlayerTeam = function(player)
	local teamId = playerTeams[player]
	return teamId and customTeams[teamId]
end

_G.GetTeamMembers = function(teamId)
	local team = customTeams[teamId]
	return team and team.members or {}
end

_G.IsTeammate = function(player1, player2)
	return areTeammates(player1, player2)
end

_G.GetAllTeams = function()
	return customTeams
end

_G.GetAvailableTeamColors = function()
	return getAvailableColors()
end

-- =====================================
-- LIMPEZA PERIÓDICA
-- =====================================

task.spawn(function()
	while true do
		task.wait(30)

		local currentTime = os.time()
		for id, invite in pairs(pendingInvites) do
			if invite.expires < currentTime then
				pendingInvites[id] = nil
			end
		end

		for id, team in pairs(customTeams) do
			if #team.members == 0 then
				deleteTeam(id, "Time vazio detectado")
			end
		end

		for color, teamId in pairs(usedColors) do
			if not customTeams[teamId] then
				usedColors[color] = nil
				print("[TEAM V3] Cor órfã liberada")
			end
		end
	end
end)

-- =====================================
-- DEBUG
-- =====================================

_G.DebugTeams = function()
	print("\n========== DEBUG TEAMS V3 ==========")
	print(string.format("Total de times: %d", #customTeams))
	print(string.format("Cores em uso: %d/%d", #usedColors, CONFIG.MAX_TEAMS))

	for teamId, team in pairs(customTeams) do
		print(string.format("\n[%s] %s", teamId, team.name))
		print(string.format("  Líder: %s", team.leader.Name))
		print(string.format("  Membros (%d):", #team.members))

		for _, member in pairs(team.members) do
			print(string.format("    - %s", member.Name))
		end

		local teamObj = teamObjects[teamId]
		print(string.format("  Time Roblox: %s", teamObj and teamObj.Name or "Não criado"))
		print(string.format("  Cor: %s", tostring(team.color)))
	end

	print("\n--- Cores Disponíveis ---")
	local available = getAvailableColors()
	for _, colorData in ipairs(available) do
		print(
			string.format(
				"%s: %s",
				colorData.name,
				colorData.available and "✓ Disponível" or "✗ Em uso"
			)
		)
	end

	print("=================================\n")
end

print([[
╔════════════════════════════════════════════════════╗
║  ✅ SISTEMA DE TIMES V3 CARREGADO                  
╠════════════════════════════════════════════════════╣
║  SUBSTITUI: TeamSystemServer V2                   ║
╠════════════════════════════════════════════════════╣
║  CORREÇÕES V3:                                     ║
║  • Time DELETADO quando líder sai (bug corrigido) ║
║  • Sistema de TAG REMOVIDO completamente          ║
║  • Notificações melhoradas                        ║
║  • Sistema de limpeza robusto                     ║
║  • Integração com seleção de personagens          ║
╠════════════════════════════════════════════════════╣
║  Funções Globais:                                  ║
║  • _G.GetPlayerTeam(player)                       ║
║  • _G.GetTeamMembers(teamId)                      ║
║  • _G.IsTeammate(player1, player2)                ║
║  • _G.GetAllTeams()                               ║
║  • _G.GetAvailableTeamColors()                    ║
║  • _G.DebugTeams()                                ║
╚════════════════════════════════════════════════════╝
]])
