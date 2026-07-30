-- ============================================
-- AWAKENING SYSTEM SERVER V2 — DESPERTAR (SEM STUDIO)
-- Coloque em ServerScriptService
-- Nome: "AwakeningSystemServer"
-- SUBSTITUI: AwakeningSystemServer V1
-- REMOVER:   AwakeningSystemServer V1
-- DEPENDE DE: AdminRegistryServer_V1 (novo, no ServerScriptService)
--             GameManager_V9 (usa AwakenedForm)
-- ============================================
-- (V2) ALTERAÇÕES:
-- • LISTA "ADMIN_IDS" REMOVIDA DO CÓDIGO (o V1 tinha só
--   { 1595442496 }, dessincronizada dos outros scripts): quem é
--   admin agora vem do _G.AdminRegistry (AdminRegistryServer_V1).
--   O ÚNICO id no Studio é o do DONO; os outros são adicionados
--   dentro do jogo e valem em TODOS os servidores.
-- • GUARDA DE JobId no MessagingService: o servidor que fez a
--   mudança não processa a própria mensagem — antes ele
--   reconstruía as Tools e anunciava DUAS vezes na mesma sala
--   (mesma correção já aplicada no CharacterCatalogServer_V4 e no
--   AchievementSystemServer_V2).
-- • EDIÇÃO RECONHECIDA: salvar um Despertar de um personagem que
--   já tinha um configurado agora anuncia "✏️ atualizou o
--   Despertar" e devolve "Despertar ATUALIZADO..." pro painel
--   (usado pelo botão ✏️ EDITAR do AdminMenuClient_V9).
-- ============================================
-- MANTIDO DO V1:
-- • Condição de desbloqueio SEMPRE Badge: possuir o personagem
--   original + ter o Badge configurado pelo admin
-- • Até 7 Tools na forma despertada, via Model ID (InsertService)
-- • Persistência em DataStore próprio + sync entre servidores
-- • Contrato dos remotes CheckAwakening/EquipAwakening intacto
--
-- REUTILIZADO:
-- • _G.AdminRegistry.isAdmin ................ AdminRegistryServer_V1
-- • Guarda de JobId ......................... CharacterCatalogServer_V4/V5
-- • ensureRemote / InsertService / Messaging  CharacterCatalogServer_V5
-- • addAwakenedCharacter / hasAwakening ..... DataManager_V6
-- • CatalogAnnouncement (mesmo remote de aviso) CharacterCatalogServer_V5
-- • Regras de Tool .......................... roblox-tool-info-rules
-- ============================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")
local MessagingService = game:GetService("MessagingService")
local InsertService = game:GetService("InsertService")
local BadgeService = game:GetService("BadgeService")

repeat
	task.wait()
until _G.PlayerDataManager

-- =====================================
-- CONFIGURAÇÃO
-- =====================================

-- (V2) Fallback de segurança: se o AdminRegistryServer_V1 não
-- estiver instalado, só o DONO é admin (mesmo id do registry).
local FALLBACK_OWNER_ID = 1595442496

local CONFIG = {
	MAX_TOOLS_PER_CHARACTER = 7, -- mesma regra do catálogo normal
	STORE_NAME = "RVAwakeningCatalogV1",
	SYNC_TOPIC = "RVAwakeningSync",
	LOAD_RETRIES = 2,
}

-- (V2) Admin dinâmico via registro central
local function isAdmin(player)
	if _G.AdminRegistry then
		return _G.AdminRegistry.isAdmin(player)
	end
	return player ~= nil and player.UserId == FALLBACK_OWNER_ID
end

-- =====================================
-- DATASTORE
-- =====================================

local awakeningStore = DataStoreService:GetDataStore(CONFIG.STORE_NAME)

-- =====================================
-- PASTAS DE DESTINO
-- =====================================

local charactersFolder = ReplicatedStorage:WaitForChild("Characters")
local imagesFolder = ReplicatedStorage:WaitForChild("CharacterImages")

-- =====================================
-- REMOTES
-- =====================================

local remotes = ReplicatedStorage:FindFirstChild("Remotes")
if not remotes then
	remotes = Instance.new("Folder")
	remotes.Name = "Remotes"
	remotes.Parent = ReplicatedStorage
end

local function ensureRemote(name, className)
	local remote = remotes:FindFirstChild(name)
	if remote and not remote:IsA(className) then
		remote.Parent = nil
		remote = nil
	end
	if not remote then
		remote = Instance.new(className)
		remote.Name = name
		remote.Parent = remotes
	end
	return remote
end

local adminSetAwakening = ensureRemote("AdminSetAwakening", "RemoteFunction")
local adminRemoveAwakening = ensureRemote("AdminRemoveAwakening", "RemoteFunction")
local adminListAwakenings = ensureRemote("AdminListAwakenings", "RemoteFunction")
local checkAwakeningRemote = ensureRemote("CheckAwakening", "RemoteFunction") -- esperado pelo CharacterSystemClient
local equipAwakeningRemote = ensureRemote("EquipAwakening", "RemoteEvent") -- esperado pelo CharacterSystemClient
local catalogAnnouncement = ensureRemote("CatalogAnnouncement", "RemoteEvent") -- REUTILIZADO do CharacterCatalogServer

-- =====================================
-- ESTADO EM MEMÓRIA + API GLOBAL
-- =====================================

local awakenDefs = {} -- [characterName] = definição

_G.AwakeningSystem = {
	getDefinition = function(name)
		return awakenDefs[name]
	end,
	listAll = function()
		return awakenDefs
	end,
}

-- =====================================
-- HELPERS: InsertService (carregar Tools por ID)
-- =====================================

local function extractLoadedContent(container)
	if not container then
		return nil
	end
	local first = container:GetChildren()[1]
	return first or container
end

local function loadAssetSafe(assetId)
	assetId = tonumber(assetId)
	if not assetId or assetId <= 0 then
		return nil, "ID inválido"
	end

	local lastErr = nil
	for attempt = 1, CONFIG.LOAD_RETRIES do
		local ok, result = pcall(function()
			return InsertService:LoadAsset(assetId)
		end)
		if ok and result then
			return extractLoadedContent(result), nil
		end
		lastErr = result
		task.wait(0.5)
	end

	return nil, "Falha ao carregar asset " .. tostring(assetId) .. ": " .. tostring(lastErr)
end

local function enforceToolRules(tool)
	if not tool:IsA("Tool") then
		return
	end
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	if not tool:FindFirstChild("Handle") then
		warn(
			string.format(
				"[AWAKENING V2] ⚠️ Tool '%s' carregada SEM Handle — não vai funcionar até corrigir o modelo de origem.",
				tool.Name
			)
		)
	end
end

-- =====================================
-- CONSTRUÇÃO DA FORMA DESPERTADA
-- Characters[Nome].AwakenedForm fica com as Tools despertas — o
-- GameManager_V9 já sabe procurar aqui quando hasAwakening é true.
-- =====================================

local function buildAwakenedAssets(def)
	local baseFolder = charactersFolder:FindFirstChild(def.characterName)
	if not baseFolder then
		baseFolder = Instance.new("Folder")
		baseFolder.Name = def.characterName
		baseFolder.Parent = charactersFolder
	end

	local oldAwakened = baseFolder:FindFirstChild("AwakenedForm")
	if oldAwakened then
		oldAwakened.Parent = nil -- regra do projeto: sem :Destroy()
	end

	local awakenedFolder = Instance.new("Folder")
	awakenedFolder.Name = "AwakenedForm"
	awakenedFolder.Parent = baseFolder

	local warnings = {}

	for i, toolId in ipairs(def.toolIds or {}) do
		if i > CONFIG.MAX_TOOLS_PER_CHARACTER then
			break
		end
		local loaded, err = loadAssetSafe(toolId)
		if loaded and loaded:IsA("Tool") then
			enforceToolRules(loaded)
			loaded.Parent = awakenedFolder
		elseif loaded then
			table.insert(
				warnings,
				string.format("Tool ID %s não é um Tool válido (era %s)", tostring(toolId), loaded.ClassName)
			)
		else
			table.insert(warnings, "Tool " .. tostring(toolId) .. ": " .. tostring(err))
		end
	end

	local oldImg = imagesFolder:FindFirstChild(def.characterName .. "_Awakened")
	if oldImg then
		oldImg.Parent = nil
	end
	if def.imageId and def.imageId > 0 then
		local img = Instance.new("ImageLabel")
		img.Name = def.characterName .. "_Awakened"
		img.Image = "rbxassetid://" .. tostring(def.imageId)
		img.Size = UDim2.new(1, 0, 1, 0)
		img.BackgroundTransparency = 1
		img.Parent = imagesFolder
	else
		table.insert(warnings, "Sem Image ID — forma despertada ficará sem aparência própria")
	end

	return warnings
end

local function removeAwakenedAssets(name)
	local baseFolder = charactersFolder:FindFirstChild(name)
	if baseFolder then
		local awakenedFolder = baseFolder:FindFirstChild("AwakenedForm")
		if awakenedFolder then
			awakenedFolder.Parent = nil
		end
	end
	local img = imagesFolder:FindFirstChild(name .. "_Awakened")
	if img then
		img.Parent = nil
	end
end

-- =====================================
-- DATASTORE: SALVAR / CARREGAR ÍNDICE
-- =====================================

local function saveIndex(index)
	pcall(function()
		awakeningStore:SetAsync("Index", index)
	end)
end

local function loadIndex()
	local ok, result = pcall(function()
		return awakeningStore:GetAsync("Index")
	end)
	if ok and type(result) == "table" then
		return result
	end
	return {}
end

local function saveDefinition(def)
	pcall(function()
		awakeningStore:SetAsync("Awaken_" .. def.characterName, def)
	end)
	local index = loadIndex()
	if not table.find(index, def.characterName) then
		table.insert(index, def.characterName)
		saveIndex(index)
	end
end

local function loadDefinition(name)
	local ok, result = pcall(function()
		return awakeningStore:GetAsync("Awaken_" .. name)
	end)
	if ok then
		return result
	end
	return nil
end

local function deleteDefinition(name)
	pcall(function()
		awakeningStore:RemoveAsync("Awaken_" .. name)
	end)
	local index = loadIndex()
	local i = table.find(index, name)
	if i then
		table.remove(index, i)
		saveIndex(index)
	end
end

-- =====================================
-- VALIDAÇÃO
-- =====================================

local function validatePayload(payload)
	if type(payload) ~= "table" then
		return false, "Dados inválidos!"
	end
	if type(payload.characterName) ~= "string" or #payload.characterName < 2 then
		return false, "Nome de personagem inválido!"
	end
	local badgeId = tonumber(payload.badgeId)
	if not badgeId or badgeId <= 0 then
		return false, "Badge ID é obrigatório para o Despertar!"
	end
	if payload.toolIds and #payload.toolIds > CONFIG.MAX_TOOLS_PER_CHARACTER then
		return false, "Máximo de " .. CONFIG.MAX_TOOLS_PER_CHARACTER .. " Tools na forma despertada!"
	end
	return true, "OK"
end

-- =====================================
-- SINCRONIZAÇÃO ENTRE TODOS OS SERVIDORES
-- (V2) com guarda de JobId + distinção set/update
-- =====================================

local function broadcastAnnouncementLocally(text, isSuccess)
	for _, p in ipairs(Players:GetPlayers()) do
		catalogAnnouncement:FireClient(p, text, isSuccess)
	end
end

local function publishSync(action, name, adminName, isUpdate)
	pcall(function()
		MessagingService:PublishAsync(CONFIG.SYNC_TOPIC, {
			action = action,
			name = name,
			admin = adminName,
			isUpdate = isUpdate or false,
			jobId = game.JobId,
		})
	end)
end

local function setAnnouncementText(adminName, name, isUpdate)
	if isUpdate then
		return string.format("✏️ %s atualizou o Despertar de '%s'!", adminName or "Um admin", name)
	end
	return string.format("⚡ %s configurou o Despertar de '%s'!", adminName or "Um admin", name)
end

local function applyRemoteChange(action, name, adminName, isUpdate)
	if action == "set" then
		local def = loadDefinition(name)
		if def then
			local warnings = buildAwakenedAssets(def)
			awakenDefs[name] = def
			broadcastAnnouncementLocally(setAnnouncementText(adminName, name, isUpdate), true)
			if #warnings > 0 then
				warn("[AWAKENING V2] Avisos ao sincronizar '" .. name .. "': " .. table.concat(warnings, " | "))
			end
		end
	elseif action == "remove" then
		removeAwakenedAssets(name)
		awakenDefs[name] = nil
		broadcastAnnouncementLocally(
			string.format("🗑️ %s removeu o Despertar de '%s'!", adminName or "Um admin", name),
			false
		)
	end
end

pcall(function()
	MessagingService:SubscribeAsync(CONFIG.SYNC_TOPIC, function(message)
		local data = message.Data
		-- (V2) guarda de JobId: não processa o próprio eco
		if type(data) == "table" and data.jobId ~= game.JobId then
			applyRemoteChange(data.action, data.name, data.admin, data.isUpdate)
		end
	end)
end)

-- =====================================
-- REMOTES: ADMIN (CONFIGURAR/EDITAR / REMOVER / LISTAR)
-- =====================================

adminSetAwakening.OnServerInvoke = function(player, payload)
	if not isAdmin(player) then
		player:Kick("Tentativa não autorizada de uso de comandos admin")
		return false, "Sem permissão!"
	end

	local ok, msg = validatePayload(payload)
	if not ok then
		return false, msg
	end

	-- (V2) Despertar já existente pra esse personagem = EDIÇÃO
	local isUpdate = awakenDefs[payload.characterName] ~= nil

	local def = {
		characterName = payload.characterName,
		badgeId = tonumber(payload.badgeId),
		imageId = tonumber(payload.imageId) or 0,
		toolIds = payload.toolIds or {},
		health = tonumber(payload.health) or nil,
		displayName = tostring(payload.displayName or (payload.characterName .. " (Despertado)")),
		addedBy = player.Name,
		addedAt = os.time(),
	}

	local warnings = buildAwakenedAssets(def)
	awakenDefs[def.characterName] = def
	saveDefinition(def)

	publishSync("set", def.characterName, player.Name, isUpdate)
	broadcastAnnouncementLocally(setAnnouncementText(player.Name, def.characterName, isUpdate), true)

	print(
		string.format(
			"[AWAKENING V2] %s %s Despertar de '%s'",
			player.Name,
			isUpdate and "atualizou" or "configurou",
			def.characterName
		)
	)

	if #warnings > 0 then
		return true, (isUpdate and "Atualizado" or "Configurado") .. " com avisos: " .. table.concat(warnings, " | ")
	end
	if isUpdate then
		return true, "Despertar ATUALIZADO em todos os servidores!"
	end
	return true, "Despertar configurado em todos os servidores!"
end

adminRemoveAwakening.OnServerInvoke = function(player, characterName)
	if not isAdmin(player) then
		player:Kick("Tentativa não autorizada de uso de comandos admin")
		return false, "Sem permissão!"
	end
	if type(characterName) ~= "string" then
		return false, "Nome inválido!"
	end

	removeAwakenedAssets(characterName)
	awakenDefs[characterName] = nil
	deleteDefinition(characterName)

	publishSync("remove", characterName, player.Name)
	broadcastAnnouncementLocally(
		string.format("🗑️ %s removeu o Despertar de '%s'!", player.Name, characterName),
		false
	)

	print(string.format("[AWAKENING V2] %s removeu Despertar de '%s'", player.Name, characterName))
	return true, "Despertar removido em todos os servidores!"
end

adminListAwakenings.OnServerInvoke = function(player)
	if not isAdmin(player) then
		return {}
	end
	local list = {}
	for _, def in pairs(awakenDefs) do
		table.insert(list, def)
	end
	return list
end

-- =====================================
-- REMOTES: JOGADOR (CHECAR / DESBLOQUEAR)
-- =====================================

-- Contrato mantido igual ao que o CharacterSystemClient já espera:
-- exists / hasAwakening / hasOriginal / canEquip / awakening.displayName
checkAwakeningRemote.OnServerInvoke = function(player, characterName)
	if type(characterName) ~= "string" then
		return { exists = false }
	end

	local def = awakenDefs[characterName]
	if not def then
		return { exists = false }
	end

	local hasOriginal = _G.PlayerDataManager.ownsCharacter and _G.PlayerDataManager.ownsCharacter(player, characterName)
		or false

	local hasBadge = false
	local ok, has = pcall(function()
		return BadgeService:UserHasBadgeAsync(player.UserId, def.badgeId)
	end)
	if ok then
		hasBadge = has
	end

	return {
		exists = true,
		hasAwakening = true,
		hasOriginal = hasOriginal,
		canEquip = hasOriginal and hasBadge,
		awakening = {
			displayName = def.displayName,
		},
	}
end

equipAwakeningRemote.OnServerEvent:Connect(function(player, characterName)
	if type(characterName) ~= "string" then
		return
	end

	local def = awakenDefs[characterName]
	if not def then
		return
	end

	-- Nunca confiar no client: revalida tudo aqui
	local hasOriginal = _G.PlayerDataManager.ownsCharacter and _G.PlayerDataManager.ownsCharacter(player, characterName)
	if not hasOriginal then
		return
	end

	local ok, hasBadge = pcall(function()
		return BadgeService:UserHasBadgeAsync(player.UserId, def.badgeId)
	end)
	if not ok or not hasBadge then
		return
	end

	if _G.PlayerDataManager.addAwakenedCharacter then
		_G.PlayerDataManager.addAwakenedCharacter(player, characterName)
		_G.PlayerDataManager.savePlayerData(player)
	end

	-- Se o personagem já está equipado agora, atualiza as Tools na
	-- hora (sem precisar morrer) — reutiliza o GameManager_V9
	if _G.GameManagerConfig and _G.GameManagerConfig.isCharacterEquipped(player, characterName) then
		if _G.GameManagerConfig.reapplyEquippedTools then
			_G.GameManagerConfig.reapplyEquippedTools(player)
		end
	end

	print(string.format("[AWAKENING V2] %s desbloqueou o Despertar de '%s'", player.Name, characterName))
end)

-- =====================================
-- BOOT: RECONSTRUIR TUDO A PARTIR DO DATASTORE
-- =====================================

local function bootLoadAwakenings()
	print("[AWAKENING V2] Carregando configurações de Despertar salvas...")
	local index = loadIndex()
	local loaded = 0

	for _, name in ipairs(index) do
		local def = loadDefinition(name)
		if def then
			local warnings = buildAwakenedAssets(def)
			awakenDefs[name] = def
			loaded += 1
			if #warnings > 0 then
				warn("[AWAKENING V2] Avisos ao carregar '" .. name .. "': " .. table.concat(warnings, " | "))
			end
		end
	end

	print(string.format("[AWAKENING V2] ✓ %d Despertar(es) carregado(s)", loaded))
end

task.spawn(bootLoadAwakenings)

-- =====================================
-- DEBUG
-- =====================================

_G.DebugAwakening = function()
	print("\n========== DEBUG AWAKENING V2 ==========")
	for name, def in pairs(awakenDefs) do
		print(
			string.format(
				"  %s → %s | Badge: %d | Tools: %d",
				name,
				def.displayName,
				def.badgeId,
				#(def.toolIds or {})
			)
		)
	end
	print("=========================================\n")
end

print([[
╔════════════════════════════════════════════════════╗
║  ⚡ AWAKENING SYSTEM SERVER V2 CARREGADO           ║
╠════════════════════════════════════════════════════╣
║  SUBSTITUI: AwakeningSystemServer V1               ║
║  REMOVER:   AwakeningSystemServer V1               ║
║  DEPENDE DE: AdminRegistryServer_V1 + GameManager_V9║
╠════════════════════════════════════════════════════╣
║  (V2) ADMIN_IDS removida → _G.AdminRegistry        ║
║  (V2) Guarda de JobId (sem anúncio duplicado)      ║
║  (V2) Edição reconhecida: "✏️ atualizou"           ║
║  • Condição fixa: possuir o original + Badge       ║
║  • Até 7 Tools na forma despertada, via Model ID   ║
╠════════════════════════════════════════════════════╣
║  DEBUG: _G.DebugAwakening()                         ║
╚════════════════════════════════════════════════════╝
]])
