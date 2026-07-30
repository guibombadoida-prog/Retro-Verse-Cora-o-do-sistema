-- ============================================
-- SISTEMA DE BOSS RAID V2 (SERVIDOR)
-- Coloque em ServerScriptService
-- Nome: "BossRaidServer"
-- SUBSTITUI: BossRaidServer_V1  ⚠️ REMOVER V1
-- ============================================
-- (V2) ALTERAÇÕES:
-- • Catálogo de Bosses DINÂMICO via DataStore
--   (registre Place IDs pelo jogo, sem abrir o Studio)
-- • MODO EDITOR ADMIN: adicionar/editar/remover bosses
--   e configurar requisitos (via _G.AdminRegistry.isAdmin)
-- • Requisito global: PERSONAGEM EQUIPADO para criar/entrar
-- • Bounty NÃO é mais obrigatório (configurável por boss)
-- • Requisitos por boss: minCoins, minBounty, requiredCharacter
-- • Sync entre servidores via MessagingService
-- ============================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")
local DataStoreService = game:GetService("DataStoreService")
local MessagingService = game:GetService("MessagingService")
local HttpService = game:GetService("HttpService")

-- Aguardar sistemas essenciais
repeat
	task.wait()
until _G.PlayerDataManager
task.wait(1)

print([[
╔════════════════════════════════════════════╗
║   SISTEMA DE BOSS RAID V2 - INICIANDO     ║
╚════════════════════════════════════════════╝
]])

-- =====================================
-- CONFIGURAÇÃO
-- =====================================

local CONFIG = {
	COUNTDOWN_SECONDS = 15,
	MAX_RAID_SIZE = 6,
	INVITE_TIMEOUT = 20,
	USE_RESERVED_SERVER = true,
	CATALOG_STORE_NAME = "RetroVerse_BossRaidCatalog_V1",
	CATALOG_KEY = "BossCatalog",
	MESSAGING_TOPIC = "BossCatalogUpdate",
	REQUIRE_EQUIPPED_CHARACTER = true, -- exige personagem equipado p/ criar/entrar
}

-- =====================================
-- ADMIN CHECK (AdminRegistryServer)
-- =====================================

local function isAdmin(player)
	if _G.AdminRegistry then
		return _G.AdminRegistry.isAdmin(player)
	end
	return false
end

-- =====================================
-- CATÁLOGO DINÂMICO DE BOSSES
-- =====================================

local catalogStore = DataStoreService:GetDataStore(CONFIG.CATALOG_STORE_NAME)

-- bossCatalog = { [bossId] = {
--   id, name, icon, placeId, description, enabled,
--   requirements = { minCoins, minBounty, requiredCharacter, minMembers }
-- } }
local bossCatalog = {}

local function loadCatalog()
	local success, data = pcall(function()
		return catalogStore:GetAsync(CONFIG.CATALOG_KEY)
	end)

	if success and data then
		bossCatalog = data
		local count = 0
		for _ in pairs(bossCatalog) do
			count = count + 1
		end
		print("[RAID V2] Catálogo carregado: " .. count .. " bosses")
	else
		bossCatalog = {}
		print("[RAID V2] Catálogo vazio — registre bosses pelo Editor Admin")
	end
end

local function saveCatalog()
	local success, err = pcall(function()
		catalogStore:SetAsync(CONFIG.CATALOG_KEY, bossCatalog)
	end)

	if not success then
		warn("[RAID V2] Falha ao salvar catálogo: " .. tostring(err))
		return false
	end

	-- Avisar outros servidores
	pcall(function()
		MessagingService:PublishAsync(CONFIG.MESSAGING_TOPIC, { serverId = game.JobId })
	end)

	return true
end

-- Recarregar quando outro servidor editar
pcall(function()
	MessagingService:SubscribeAsync(CONFIG.MESSAGING_TOPIC, function(message)
		if message.Data and message.Data.serverId ~= game.JobId then
			print("[RAID V2] Catálogo atualizado por outro servidor — recarregando")
			loadCatalog()
		end
	end)
end)

loadCatalog()

local function getBossConfig(bossId)
	return bossCatalog[bossId]
end

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
	end
	return remote
end

-- Jogador
local getBossListRemote = getOrCreateRemote("GetBossList", "Function")
local createRaidRemote = getOrCreateRemote("CreateRaid", "Function")
local startRaidRemote = getOrCreateRemote("StartRaidCountdown", "Function")
local cancelRaidRemote = getOrCreateRemote("CancelRaid", "Event")
local leaveRaidRemote = getOrCreateRemote("LeaveRaid", "Event")
local inviteToRaidRemote = getOrCreateRemote("InviteToRaid", "Event")
local respondRaidInviteRemote = getOrCreateRemote("RespondRaidInvite", "Event")
local requestJoinRaidRemote = getOrCreateRemote("RequestJoinRaid", "Event")
local respondJoinRequestRemote = getOrCreateRemote("RespondJoinRequest", "Event")
local raidStateUpdateRemote = getOrCreateRemote("RaidStateUpdate", "Event")
local raidNotifyRemote = getOrCreateRemote("RaidNotify", "Event")

-- Admin (Editor de Bosses)
local adminSaveBossRemote = getOrCreateRemote("AdminSaveBoss", "Function")
local adminRemoveBossRemote = getOrCreateRemote("AdminRemoveBoss", "Function")
local adminGetBossCatalogRemote = getOrCreateRemote("AdminGetBossCatalog", "Function")

-- =====================================
-- ESTADO DAS RAIDS
-- =====================================

local raids = {}
local playerRaid = {} -- [player] = raidId
local raidCounter = 0

local function notify(player, message, success)
	pcall(function()
		raidNotifyRemote:FireClient(player, message, success and true or false)
	end)
end

local function serializeRaid(raid)
	local memberNames = {}
	for _, m in ipairs(raid.members) do
		table.insert(memberNames, m.Name)
	end

	local requestNames = {}
	for p in pairs(raid.pendingRequests) do
		if p.Parent then
			table.insert(requestNames, p.Name)
		end
	end

	local boss = getBossConfig(raid.bossId)

	return {
		id = raid.id,
		bossId = raid.bossId,
		bossName = boss and boss.name or "???",
		bossIcon = boss and boss.icon or "❔",
		leader = raid.leader and raid.leader.Name or "???",
		members = memberNames,
		requests = requestNames,
		state = raid.state,
		countdownEndsAt = raid.countdownEndsAt,
		maxSize = CONFIG.MAX_RAID_SIZE,
	}
end

local function broadcastRaid(raid)
	local data = serializeRaid(raid)
	for _, p in ipairs(Players:GetPlayers()) do
		pcall(function()
			raidStateUpdateRemote:FireClient(p, data)
		end)
	end
end

local function broadcastRaidRemoved(raidId)
	for _, p in ipairs(Players:GetPlayers()) do
		pcall(function()
			raidStateUpdateRemote:FireClient(p, { id = raidId, removed = true })
		end)
	end
end

-- =====================================
-- VERIFICAÇÃO DE REQUISITOS
-- =====================================

-- Requisito GLOBAL: personagem equipado
local function hasEquippedCharacter(player)
	if not CONFIG.REQUIRE_EQUIPPED_CHARACTER then
		return true
	end
	local data = _G.PlayerDataManager.getPlayerData(player)
	return data ~= nil and data.equippedCharacter ~= nil
end

-- Requisitos configuráveis por boss (retorna ok, mensagemDeErro)
local function checkBossRequirements(player, boss)
	if not hasEquippedCharacter(player) then
		return false, "⚔️ Equipe um personagem antes de entrar em uma raid!"
	end

	local req = boss.requirements or {}
	local data = _G.PlayerDataManager.getPlayerData(player)
	if not data then
		return false, "Dados não carregados, tente novamente."
	end

	if req.minCoins and req.minCoins > 0 then
		local coins = data.coins or 0
		if coins < req.minCoins then
			return false, string.format("Requer %d moedas (você tem %d)", req.minCoins, coins)
		end
	end

	if req.minBounty and req.minBounty > 0 then
		local bounty = data.stats and data.stats.bounty or 0
		if bounty < req.minBounty then
			return false, string.format("Requer bounty %d (você tem %d)", req.minBounty, bounty)
		end
	end

	if req.requiredCharacter and req.requiredCharacter ~= "" then
		if not _G.PlayerDataManager.ownsCharacter(player, req.requiredCharacter) then
			return false, "Requer o personagem: " .. req.requiredCharacter
		end
	end

	return true, nil
end

-- =====================================
-- GERENCIAMENTO DE RAID
-- =====================================

local function createRaid(leader, bossId)
	local boss = getBossConfig(bossId)
	if not boss then
		return false, "Boss inválido!"
	end
	if not boss.enabled then
		return false, "Este boss está desativado!"
	end
	if not boss.placeId or boss.placeId == 0 then
		return false, "Boss ainda não configurado (sem Place ID)!"
	end
	if playerRaid[leader] then
		return false, "Você já está em uma raid!"
	end

	local ok, errMsg = checkBossRequirements(leader, boss)
	if not ok then
		return false, errMsg
	end

	raidCounter = raidCounter + 1
	local raidId = "raid_" .. raidCounter .. "_" .. HttpService:GenerateGUID(false)

	local raid = {
		id = raidId,
		bossId = bossId,
		leader = leader,
		members = { leader },
		pendingInvites = {},
		pendingRequests = {},
		state = "lobby",
		countdownEndsAt = nil,
	}

	raids[raidId] = raid
	playerRaid[leader] = raidId

	-- Membros do TIME do líder recebem convite automático
	if _G.GetPlayerTeam and _G.GetTeamMembers then
		local teamId = _G.GetPlayerTeam(leader)
		if teamId then
			local teamMembers = _G.GetTeamMembers(teamId)
			if teamMembers then
				for _, member in ipairs(teamMembers) do
					if member ~= leader and not playerRaid[member] then
						raid.pendingInvites[member] = true
						notify(member, string.format("%s iniciou a raid %s %s! Aceite no menu Boss Raid.", leader.Name, boss.icon or "👹", boss.name), true)
						pcall(function()
							raidStateUpdateRemote:FireClient(member, serializeRaid(raid))
						end)
					end
				end
			end
		end
	end

	print(string.format("[RAID V2] %s criou raid %s (%s)", leader.Name, raidId, boss.name))
	broadcastRaid(raid)
	return true, raidId
end

local function removeMember(raid, player, reason)
	for i, m in ipairs(raid.members) do
		if m == player then
			table.remove(raid.members, i)
			break
		end
	end
	playerRaid[player] = nil

	if raid.leader == player then
		for _, m in ipairs(raid.members) do
			playerRaid[m] = nil
			notify(m, "A raid foi desfeita (líder saiu).", false)
		end
		raids[raid.id] = nil
		broadcastRaidRemoved(raid.id)
	else
		if reason then
			notify(player, reason, false)
		end
		broadcastRaid(raid)
	end
end

local function disbandRaid(raid, message)
	for _, m in ipairs(raid.members) do
		playerRaid[m] = nil
		if message then
			notify(m, message, false)
		end
	end
	raids[raid.id] = nil
	broadcastRaidRemoved(raid.id)
end

-- =====================================
-- CONTAGEM E TELEPORTE
-- =====================================

local function teleportRaid(raid)
	local boss = getBossConfig(raid.bossId)
	if not boss or not boss.placeId or boss.placeId == 0 then
		disbandRaid(raid, "⚠️ Place ID do boss não configurado!")
		return
	end

	raid.state = "teleporting"
	broadcastRaid(raid)

	local validMembers = {}
	for _, m in ipairs(raid.members) do
		if m.Parent then
			table.insert(validMembers, m)
		end
	end

	if #validMembers == 0 then
		raids[raid.id] = nil
		broadcastRaidRemoved(raid.id)
		return
	end

	-- Salvar dados antes do teleporte (DataStore compartilhado)
	for _, m in ipairs(validMembers) do
		pcall(function()
			_G.PlayerDataManager.savePlayerData(m)
		end)
	end
	task.wait(1)

	local teleportData = {
		raidId = raid.id,
		bossId = raid.bossId,
		bossName = boss.name,
		leaderUserId = raid.leader and raid.leader.UserId or 0,
	}

	local success, err = pcall(function()
		local options = Instance.new("TeleportOptions")
		if CONFIG.USE_RESERVED_SERVER then
			options.ReservedServerAccessCode = TeleportService:ReserveServer(boss.placeId)
		end
		options:SetTeleportData(teleportData)
		TeleportService:TeleportAsync(boss.placeId, validMembers, options)
	end)

	if not success then
		warn("[RAID V2] Falha no teleporte: " .. tostring(err))
		for _, m in ipairs(validMembers) do
			notify(m, "⚠️ Falha no teleporte! Verifique se a place está no mesmo universo. (Não funciona no Studio)", false)
		end
		raid.state = "lobby"
		raid.countdownEndsAt = nil
		broadcastRaid(raid)
		return
	end

	task.wait(5)
	if raids[raid.id] then
		disbandRaid(raid, nil)
	end
end

local function startCountdown(raid)
	raid.state = "countdown"
	raid.countdownEndsAt = os.clock() + CONFIG.COUNTDOWN_SECONDS
	raid.pendingInvites = {}
	raid.pendingRequests = {}
	broadcastRaid(raid)

	for _, m in ipairs(raid.members) do
		notify(m, string.format("⏱️ Raid começando em %d segundos!", CONFIG.COUNTDOWN_SECONDS), true)
	end

	task.spawn(function()
		while raids[raid.id] and raid.state == "countdown" do
			if os.clock() >= raid.countdownEndsAt then
				teleportRaid(raid)
				break
			end
			task.wait(0.25)
		end
	end)
end

-- =====================================
-- HANDLERS — JOGADOR
-- =====================================

local function serializeBossPublic(boss)
	local req = boss.requirements or {}
	return {
		id = boss.id,
		name = boss.name,
		icon = boss.icon or "👹",
		description = boss.description or "",
		enabled = boss.enabled and true or false,
		configured = boss.placeId ~= nil and boss.placeId ~= 0,
		minCoins = req.minCoins or 0,
		minBounty = req.minBounty or 0,
		requiredCharacter = req.requiredCharacter,
	}
end

getBossListRemote.OnServerInvoke = function(player)
	local bossList = {}
	for _, boss in pairs(bossCatalog) do
		if boss.enabled then
			table.insert(bossList, serializeBossPublic(boss))
		end
	end
	table.sort(bossList, function(a, b)
		return a.name < b.name
	end)

	local openRaids = {}
	for _, raid in pairs(raids) do
		if raid.state == "lobby" then
			table.insert(openRaids, serializeRaid(raid))
		end
	end

	local myRaidId = playerRaid[player]
	local myRaid = myRaidId and raids[myRaidId] and serializeRaid(raids[myRaidId]) or nil

	local myInvites = {}
	for _, raid in pairs(raids) do
		if raid.pendingInvites[player] then
			table.insert(myInvites, serializeRaid(raid))
		end
	end

	return {
		bosses = bossList,
		openRaids = openRaids,
		myRaid = myRaid,
		myInvites = myInvites,
		isAdmin = isAdmin(player),
		hasEquipped = hasEquippedCharacter(player),
	}
end

createRaidRemote.OnServerInvoke = function(player, bossId)
	local ok, result = createRaid(player, tostring(bossId))
	if not ok then
		notify(player, result, false)
	end
	return ok, result
end

startRaidRemote.OnServerInvoke = function(player)
	local raidId = playerRaid[player]
	local raid = raidId and raids[raidId]
	if not raid then
		return false, "Você não está em uma raid!"
	end
	if raid.leader ~= player then
		return false, "Apenas o líder pode iniciar!"
	end
	if raid.state ~= "lobby" then
		return false, "Raid já iniciada!"
	end

	startCountdown(raid)
	return true, "Contagem iniciada!"
end

cancelRaidRemote.OnServerEvent:Connect(function(player)
	local raidId = playerRaid[player]
	local raid = raidId and raids[raidId]
	if not raid or raid.leader ~= player or raid.state == "teleporting" then
		return
	end
	disbandRaid(raid, "Raid cancelada pelo líder.")
end)

leaveRaidRemote.OnServerEvent:Connect(function(player)
	local raidId = playerRaid[player]
	local raid = raidId and raids[raidId]
	if not raid or raid.state == "teleporting" then
		return
	end
	removeMember(raid, player, "Você saiu da raid.")
end)

inviteToRaidRemote.OnServerEvent:Connect(function(player, targetName)
	local raidId = playerRaid[player]
	local raid = raidId and raids[raidId]
	if not raid or raid.leader ~= player or raid.state ~= "lobby" then
		return
	end

	local target = Players:FindFirstChild(tostring(targetName))
	if not target then
		notify(player, "Jogador não encontrado!", false)
		return
	end
	if playerRaid[target] then
		notify(player, target.Name .. " já está em uma raid!", false)
		return
	end
	if #raid.members >= CONFIG.MAX_RAID_SIZE then
		notify(player, "Raid cheia!", false)
		return
	end

	raid.pendingInvites[target] = true
	local boss = getBossConfig(raid.bossId)
	notify(target, string.format("%s convidou você para a raid %s %s!", player.Name, boss.icon or "👹", boss.name), true)
	notify(player, "Convite enviado para " .. target.Name, true)

	pcall(function()
		raidStateUpdateRemote:FireClient(target, serializeRaid(raid))
	end)

	task.delay(CONFIG.INVITE_TIMEOUT, function()
		if raids[raidId] and raid.pendingInvites[target] then
			raid.pendingInvites[target] = nil
		end
	end)
end)

respondRaidInviteRemote.OnServerEvent:Connect(function(player, raidId, accepted)
	local raid = raids[tostring(raidId)]
	if not raid or not raid.pendingInvites[player] then
		return
	end

	raid.pendingInvites[player] = nil

	if not accepted then
		notify(raid.leader, player.Name .. " recusou o convite.", false)
		return
	end

	if raid.state ~= "lobby" then
		notify(player, "A raid já começou!", false)
		return
	end
	if playerRaid[player] then
		notify(player, "Você já está em uma raid!", false)
		return
	end
	if #raid.members >= CONFIG.MAX_RAID_SIZE then
		notify(player, "Raid cheia!", false)
		return
	end

	-- Requisito global + requisitos do boss valem para ENTRAR também
	local boss = getBossConfig(raid.bossId)
	local ok, errMsg = checkBossRequirements(player, boss)
	if not ok then
		notify(player, errMsg, false)
		return
	end

	table.insert(raid.members, player)
	playerRaid[player] = raid.id
	notify(player, "Você entrou na raid!", true)
	notify(raid.leader, player.Name .. " entrou na raid!", true)
	broadcastRaid(raid)
end)

requestJoinRaidRemote.OnServerEvent:Connect(function(player, raidId)
	local raid = raids[tostring(raidId)]
	if not raid or raid.state ~= "lobby" then
		notify(player, "Raid indisponível!", false)
		return
	end
	if playerRaid[player] then
		notify(player, "Você já está em uma raid!", false)
		return
	end
	if raid.pendingRequests[player] then
		notify(player, "Pedido já enviado, aguarde o líder.", false)
		return
	end
	if #raid.members >= CONFIG.MAX_RAID_SIZE then
		notify(player, "Raid cheia!", false)
		return
	end

	-- Checar requisitos ANTES de incomodar o líder
	local boss = getBossConfig(raid.bossId)
	local ok, errMsg = checkBossRequirements(player, boss)
	if not ok then
		notify(player, errMsg, false)
		return
	end

	raid.pendingRequests[player] = true
	notify(player, "Pedido enviado! Aguardando aprovação do líder.", true)
	notify(raid.leader, player.Name .. " pediu para entrar na raid. Aprove no menu!", true)
	broadcastRaid(raid)
end)

respondJoinRequestRemote.OnServerEvent:Connect(function(player, targetName, accepted)
	local raidId = playerRaid[player]
	local raid = raidId and raids[raidId]
	if not raid or raid.leader ~= player then
		return
	end

	local target = Players:FindFirstChild(tostring(targetName))
	if not target or not raid.pendingRequests[target] then
		return
	end

	raid.pendingRequests[target] = nil

	if not accepted then
		notify(target, "Seu pedido de entrada foi recusado.", false)
		broadcastRaid(raid)
		return
	end

	if raid.state ~= "lobby" or playerRaid[target] or #raid.members >= CONFIG.MAX_RAID_SIZE then
		notify(target, "Não foi possível entrar na raid.", false)
		broadcastRaid(raid)
		return
	end

	table.insert(raid.members, target)
	playerRaid[target] = raid.id
	notify(target, "Pedido aceito! Você entrou na raid!", true)
	broadcastRaid(raid)
end)

-- =====================================
-- HANDLERS — EDITOR ADMIN
-- =====================================

-- Retorna catálogo COMPLETO (inclusive desativados/sem placeId)
adminGetBossCatalogRemote.OnServerInvoke = function(player)
	if not isAdmin(player) then
		player:Kick("Tentativa nao autorizada de uso de comandos admin")
		return nil
	end

	local list = {}
	for _, boss in pairs(bossCatalog) do
		local entry = serializeBossPublic(boss)
		entry.placeId = boss.placeId or 0
		table.insert(list, entry)
	end
	table.sort(list, function(a, b)
		return a.name < b.name
	end)
	return list
end

-- Criar OU editar boss. bossInfo = { id (nil=novo), name, icon, placeId,
--   description, enabled, minCoins, minBounty, requiredCharacter }
adminSaveBossRemote.OnServerInvoke = function(player, bossInfo)
	if not isAdmin(player) then
		player:Kick("Tentativa nao autorizada de uso de comandos admin")
		return false, "Não autorizado"
	end

	if type(bossInfo) ~= "table" then
		return false, "Dados inválidos!"
	end

	local name = tostring(bossInfo.name or "")
	if #name < 2 or #name > 30 then
		return false, "Nome deve ter entre 2 e 30 caracteres!"
	end

	local placeId = tonumber(bossInfo.placeId) or 0
	if placeId < 0 then
		placeId = 0
	end

	local bossId = bossInfo.id
	if not bossId or bossId == "" or not bossCatalog[bossId] then
		bossId = "boss_" .. HttpService:GenerateGUID(false)
	end

	bossCatalog[bossId] = {
		id = bossId,
		name = name,
		icon = tostring(bossInfo.icon or "👹"),
		placeId = placeId,
		description = tostring(bossInfo.description or ""),
		enabled = bossInfo.enabled and true or false,
		requirements = {
			minCoins = math.max(0, tonumber(bossInfo.minCoins) or 0),
			minBounty = math.max(0, tonumber(bossInfo.minBounty) or 0),
			requiredCharacter = (bossInfo.requiredCharacter ~= "" and bossInfo.requiredCharacter) or nil,
		},
	}

	if not saveCatalog() then
		return false, "Falha ao salvar no DataStore!"
	end

	print(string.format("[RAID V2] Admin %s salvou boss: %s (place %d)", player.Name, name, placeId))
	return true, bossId
end

adminRemoveBossRemote.OnServerInvoke = function(player, bossId)
	if not isAdmin(player) then
		player:Kick("Tentativa nao autorizada de uso de comandos admin")
		return false, "Não autorizado"
	end

	bossId = tostring(bossId)
	if not bossCatalog[bossId] then
		return false, "Boss não encontrado!"
	end

	-- Desfazer raids ativas deste boss
	for _, raid in pairs(raids) do
		if raid.bossId == bossId and raid.state ~= "teleporting" then
			disbandRaid(raid, "Raid cancelada: boss removido por um admin.")
		end
	end

	local name = bossCatalog[bossId].name
	bossCatalog[bossId] = nil

	if not saveCatalog() then
		return false, "Falha ao salvar no DataStore!"
	end

	print(string.format("[RAID V2] Admin %s removeu boss: %s", player.Name, name))
	return true, "Removido"
end

-- =====================================
-- LIMPEZA AO SAIR
-- =====================================

Players.PlayerRemoving:Connect(function(player)
	local raidId = playerRaid[player]
	if raidId and raids[raidId] then
		removeMember(raids[raidId], player, nil)
	end

	for _, raid in pairs(raids) do
		raid.pendingInvites[player] = nil
		if raid.pendingRequests[player] then
			raid.pendingRequests[player] = nil
			broadcastRaid(raid)
		end
	end
end)

-- =====================================
-- API GLOBAL
-- =====================================

_G.BossRaid = {
	getPlayerRaid = function(player)
		local raidId = playerRaid[player]
		return raidId and raids[raidId] or nil
	end,
	getBossConfig = getBossConfig,
	reloadCatalog = loadCatalog,
}

print([[
╔════════════════════════════════════════════╗
║   ✅ BOSS RAID V2 CARREGADO               ║
║   • Catálogo dinâmico via DataStore       ║
║   • Editor Admin habilitado               ║
║   • Requisito: personagem equipado        ║
╚════════════════════════════════════════════╝
]])
