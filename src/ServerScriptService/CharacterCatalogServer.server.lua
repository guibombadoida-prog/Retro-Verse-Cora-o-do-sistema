-- ============================================
-- CHARACTER CATALOG SERVER V6 — GAMEPASS AUTOMÁTICO NO INVENTÁRIO
-- Coloque em ServerScriptService
-- Nome: "CharacterCatalogServer"
-- SUBSTITUI: CharacterCatalogServer V5
-- REMOVER:   CharacterCatalogServer V5
-- DEPENDE DE: AdminRegistryServer_V1
-- ============================================
-- (V6) ALTERAÇÕES — DEFEITO CORRIGIDO:
-- • PERSONAGEM DE GAMEPASS NÃO APARECIA NO INVENTÁRIO de quem já
--   tinha a gamepass. Causa: o checkGamepasses do GameManager_V9
--   roda 2s após o login, ANTES do catálogo terminar de carregar
--   do DataStore — a tabela gamepassCharacters ainda estava vazia
--   e o loop não concedia nada. E comprar a gamepass DENTRO do
--   jogo não concedia nada, pois nenhum servidor escutava
--   PromptGamePassPurchaseFinished.
-- • AGORA o próprio catálogo concede (mesmo fluxo do Grátis):
--   1) NO LOGIN: depois que o catálogo termina de carregar
--      (bootCompleted), verifica UserOwnsGamePassAsync de cada
--      personagem Gamepass e adiciona os que faltam no inventário.
--   2) COMPRA EM JOGO: PromptGamePassPurchaseFinished concede o
--      personagem NA HORA, com aviso pessoal — sem relogar.
--   3) ADMIN ADICIONA/EDITA personagem Gamepass: todos os online
--      (em TODOS os servidores, via sync) são verificados na hora.
-- • O checkGamepasses do GameManager_V9 continua existindo como
--   redundância inofensiva (a checagem "já possui?" impede
--   duplicata) — NÃO precisa mexer no GameManager.
-- ============================================
-- MANTIDO DO V5:
-- • ADMIN_IDS via _G.AdminRegistry (AdminRegistryServer_V1)
-- • Edição reconhecida ("✏️ atualizou" quando o nome já existe)
-- MANTIDO DO V4:
-- • MANDATORY (GRÁTIS) direto no inventário de todos (no add, no
--   login e no boot)
-- • Remoção pelo admin em todos os servidores: equipado morre na
--   hora (+1 Deaths, sem creditar kill), Loja devolve 100% do
--   preço pago, inventário limpo + aviso pessoal; offline = prune
--   seguro no próximo login (só se o índice carregou com sucesso)
-- • Guarda de JobId no MessagingService
--
-- REUTILIZADO:
-- • Padrão UserOwnsGamePassAsync + "não possui? → adicionar"
--   ................................. checkGamepasses do GameManager_V9
-- • Fluxo grantMandatoriesToPlayer (base do grant de Gamepass)
--   ................................. CharacterCatalogServer_V5 (este)
-- • _G.AdminRegistry.isAdmin ....... AdminRegistryServer_V1
-- • ensureRemote ................... MissionSystemServer_V2
-- • removeCharacterByName / getCharacterByName / updateCoins /
--   addCharacterToInventory / savePlayerData / ownsCharacter
--   ................................. DataManager_V6
-- • getEquippedCharacter (pra matar quem está equipado) GameManager_V9
-- • Regras de Tool ................. roblox-tool-info-rules
-- ============================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")
local MessagingService = game:GetService("MessagingService")
local InsertService = game:GetService("InsertService")
local MarketplaceService = game:GetService("MarketplaceService") -- (V6)

-- =====================================
-- CONFIGURAÇÃO
-- =====================================

-- Fallback de segurança: se o AdminRegistryServer_V1 não
-- estiver instalado, só o DONO é admin (mesmo id do registry).
local FALLBACK_OWNER_ID = 1595442496

local CONFIG = {
	MAX_TOOLS_PER_CHARACTER = 7,
	CATALOG_STORE_NAME = "RVCharacterCatalogV1",
	SYNC_TOPIC = "RVCharacterCatalogSync",
	LOAD_RETRIES = 2,
}

local VALID_CATEGORIES = {
	Shop = true,
	Reward = true,
	Gamepass = true,
	Badge = true,
	Mandatory = true,
	Trade = true,
}

local VALID_RARITIES = {
	ROBLOXIANOS = true,
	HEROXIANOS = true,
	NULLXIANOS = true,
	BTUDIOS = true,
	BOSSXIANOS = true,
	SUPREMO = true,
	AWAKENED = true,
}

-- Admin dinâmico via registro central
local function isAdmin(player)
	if _G.AdminRegistry then
		return _G.AdminRegistry.isAdmin(player)
	end
	return player ~= nil and player.UserId == FALLBACK_OWNER_ID
end

-- =====================================
-- DATASTORE
-- =====================================

local catalogStore = DataStoreService:GetDataStore(CONFIG.CATALOG_STORE_NAME)

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

local adminCatalogAdd = ensureRemote("AdminCatalogAddCharacter", "RemoteFunction")
local adminCatalogRemove = ensureRemote("AdminCatalogRemoveCharacter", "RemoteFunction")
local adminCatalogList = ensureRemote("AdminCatalogListCharacters", "RemoteFunction")
local getCatalogCharactersRemote = ensureRemote("GetCatalogCharacters", "RemoteFunction") -- público
local catalogAnnouncement = ensureRemote("CatalogAnnouncement", "RemoteEvent")

-- =====================================
-- ESTADO EM MEMÓRIA + API GLOBAL (_G)
-- =====================================

_G.GameContentConfig = _G.GameContentConfig
	or {
		characterPrices = {},
		bountyCharacters = {},
		gamepassCharacters = {},
		badgeCharacters = {},
		characterHealth = {},
		characterRarity = {},
		characterLore = {},
		characterDescription = {},
		mandatoryCharacters = {},
		catalogByName = {},
	}

local GCC = _G.GameContentConfig

-- Flags de segurança pro prune de login
local bootCompleted = false
local indexLoadOk = false

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
				"[CATALOG V6] ⚠️ Tool '%s' carregada SEM Handle — não vai funcionar até corrigir o modelo de origem.",
				tool.Name
			)
		)
	end
end

-- =====================================
-- CONSTRUÇÃO DA PASTA DO PERSONAGEM
-- =====================================

local function clearOldFolder(name)
	local old = charactersFolder:FindFirstChild(name)
	if old then
		old.Parent = nil -- regra do projeto: sem :Destroy()
	end
	local oldImg = imagesFolder:FindFirstChild(name)
	if oldImg then
		oldImg.Parent = nil
	end
end

local function buildCharacterAssets(def)
	clearOldFolder(def.name)

	local folder = Instance.new("Folder")
	folder.Name = def.name
	folder.Parent = charactersFolder

	local warnings = {}

	for i, toolId in ipairs(def.toolIds or {}) do
		if i > CONFIG.MAX_TOOLS_PER_CHARACTER then
			break
		end
		local loaded, err = loadAssetSafe(toolId)
		if loaded and loaded:IsA("Tool") then
			enforceToolRules(loaded)
			loaded.Parent = folder
		elseif loaded then
			table.insert(
				warnings,
				string.format("Tool ID %s não é um Tool válido (era %s)", tostring(toolId), loaded.ClassName)
			)
		else
			table.insert(warnings, "Tool " .. tostring(toolId) .. ": " .. tostring(err))
		end
	end

	if def.imageId and def.imageId > 0 then
		local img = Instance.new("ImageLabel")
		img.Name = def.name
		img.Image = "rbxassetid://" .. tostring(def.imageId)
		img.Size = UDim2.new(1, 0, 1, 0)
		img.BackgroundTransparency = 1
		img.Parent = imagesFolder
	else
		table.insert(warnings, "Sem Image ID — personagem ficará sem aparência na loja")
	end

	return warnings
end

-- =====================================
-- ATUALIZA A TABELA _G.GameContentConfig
-- =====================================

local function applyDefinitionToConfig(def)
	GCC.characterPrices[def.name] = nil
	GCC.bountyCharacters[def.name] = nil
	GCC.gamepassCharacters[def.name] = nil
	GCC.badgeCharacters[def.name] = nil
	local mi = table.find(GCC.mandatoryCharacters, def.name)
	if mi then
		table.remove(GCC.mandatoryCharacters, mi)
	end

	if def.category == "Shop" then
		GCC.characterPrices[def.name] = def.value or 0
	elseif def.category == "Reward" then
		GCC.bountyCharacters[def.name] = def.value or 0
	elseif def.category == "Gamepass" then
		GCC.gamepassCharacters[def.name] = def.gamepassId or 0
	elseif def.category == "Badge" then
		GCC.badgeCharacters[def.name] = def.badgeId or 0
	elseif def.category == "Mandatory" then
		table.insert(GCC.mandatoryCharacters, def.name)
	end

	GCC.characterHealth[def.name] = def.health or 100
	GCC.characterRarity[def.name] = def.rarity or "ROBLOXIANOS"
	GCC.characterLore[def.name] = def.lore or ""
	GCC.characterDescription[def.name] = def.description or ""
	GCC.catalogByName[def.name] = def
end

local function removeDefinitionFromConfig(name)
	GCC.characterPrices[name] = nil
	GCC.bountyCharacters[name] = nil
	GCC.gamepassCharacters[name] = nil
	GCC.badgeCharacters[name] = nil
	GCC.characterHealth[name] = nil
	GCC.characterRarity[name] = nil
	GCC.characterLore[name] = nil
	GCC.characterDescription[name] = nil
	GCC.catalogByName[name] = nil
	local mi = table.find(GCC.mandatoryCharacters, name)
	if mi then
		table.remove(GCC.mandatoryCharacters, mi)
	end
end

-- =====================================
-- DATASTORE: SALVAR / CARREGAR ÍNDICE
-- =====================================

local function saveIndex(index)
	pcall(function()
		catalogStore:SetAsync("Index", index)
	end)
end

-- devolve também se a leitura deu certo (trava do prune)
local function loadIndex()
	local ok, result = pcall(function()
		return catalogStore:GetAsync("Index")
	end)
	if ok then
		if type(result) == "table" then
			return result, true
		end
		return {}, true -- leu com sucesso, só não existe ainda
	end
	return {}, false
end

local function saveDefinition(def)
	pcall(function()
		catalogStore:SetAsync("Char_" .. def.name, def)
	end)
	local index = loadIndex()
	if not table.find(index, def.name) then
		table.insert(index, def.name)
		saveIndex(index)
	end
end

local function loadDefinition(name)
	local ok, result = pcall(function()
		return catalogStore:GetAsync("Char_" .. name)
	end)
	if ok then
		return result
	end
	return nil
end

local function deleteDefinition(name)
	pcall(function()
		catalogStore:RemoveAsync("Char_" .. name)
	end)
	local index = loadIndex()
	local i = table.find(index, name)
	if i then
		table.remove(index, i)
		saveIndex(index)
	end
end

-- =====================================
-- VALIDAÇÃO DO PAYLOAD
-- =====================================

local function validatePayload(payload)
	if type(payload) ~= "table" then
		return false, "Dados inválidos!"
	end
	if type(payload.name) ~= "string" or #payload.name < 2 or #payload.name > 24 then
		return false, "Nome inválido (2-24 caracteres)!"
	end
	if not VALID_CATEGORIES[payload.category] then
		return false, "Categoria inválida!"
	end
	if payload.rarity and not VALID_RARITIES[payload.rarity] then
		return false, "Raridade inválida!"
	end
	if payload.toolIds and #payload.toolIds > CONFIG.MAX_TOOLS_PER_CHARACTER then
		return false, "Máximo de " .. CONFIG.MAX_TOOLS_PER_CHARACTER .. " Tools por personagem!"
	end
	if payload.category == "Gamepass" and (not payload.gamepassId or payload.gamepassId <= 0) then
		return false, "Categoria Gamepass exige um Gamepass ID válido!"
	end
	if payload.category == "Badge" and (not payload.badgeId or payload.badgeId <= 0) then
		return false, "Categoria Badge exige um Badge ID válido!"
	end
	return true, "OK"
end

-- =====================================
-- CONCESSÃO AUTOMÁTICA DE MANDATORY (GRÁTIS → INVENTÁRIO)
-- =====================================

local function grantMandatoriesToPlayer(player)
	if not _G.PlayerDataManager then
		return
	end
	local granted = false
	for _, name in ipairs(GCC.mandatoryCharacters) do
		if not _G.PlayerDataManager.ownsCharacter(player, name) then
			if _G.PlayerDataManager.addCharacterToInventory(player, name) then
				granted = true
			end
		end
	end
	if granted then
		_G.PlayerDataManager.savePlayerData(player)
	end
end

local function grantMandatoriesToAll()
	for _, p in ipairs(Players:GetPlayers()) do
		task.spawn(grantMandatoriesToPlayer, p)
	end
end

-- =====================================
-- (V6) CONCESSÃO AUTOMÁTICA DE GAMEPASS → INVENTÁRIO
-- Reutiliza o padrão do checkGamepasses (GameManager_V9), mas
-- rodando AQUI, onde o catálogo já sabe quando terminou de carregar.
-- =====================================

local function playerHasGamepass(player, gamepassId)
	if not gamepassId or gamepassId <= 0 then
		return false
	end
	local ok, has = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(player.UserId, gamepassId)
	end)
	return ok and has == true
end

local function grantGamepassCharactersToPlayer(player)
	if not _G.PlayerDataManager then
		return
	end
	local granted = {}
	for charName, gpId in pairs(GCC.gamepassCharacters) do
		if not _G.PlayerDataManager.ownsCharacter(player, charName) then
			if playerHasGamepass(player, gpId) then
				if _G.PlayerDataManager.addCharacterToInventory(player, charName) then
					table.insert(granted, charName)
				end
			end
		end
	end
	if #granted > 0 then
		_G.PlayerDataManager.savePlayerData(player)
		for _, charName in ipairs(granted) do
			catalogAnnouncement:FireClient(
				player,
				string.format("🎟️ Personagem '%s' liberado no seu inventário (Gamepass)!", charName),
				true
			)
			print(string.format("[CATALOG V6] Gamepass: '%s' concedido a %s", charName, player.Name))
		end
	end
end

local function grantGamepassesToAll()
	for _, p in ipairs(Players:GetPlayers()) do
		task.spawn(grantGamepassCharactersToPlayer, p)
	end
end

-- (V6) COMPRA DENTRO DO JOGO: concede NA HORA, sem relogar.
-- O CharacterSystemClient_V6 abre o PromptGamePassPurchase; quando
-- a compra termina, este handler entrega o personagem.
MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, gamePassId, wasPurchased)
	if not wasPurchased then
		return
	end
	if not _G.PlayerDataManager then
		return
	end
	for charName, gpId in pairs(GCC.gamepassCharacters) do
		if gpId == gamePassId then
			if not _G.PlayerDataManager.ownsCharacter(player, charName) then
				if _G.PlayerDataManager.addCharacterToInventory(player, charName) then
					_G.PlayerDataManager.savePlayerData(player)
					catalogAnnouncement:FireClient(
						player,
						string.format("🎟️ Compra confirmada! Personagem '%s' adicionado ao seu inventário!", charName),
						true
					)
					print(
						string.format(
							"[CATALOG V6] Compra em jogo: '%s' concedido a %s (gamepass %d)",
							charName,
							player.Name,
							gamePassId
						)
					)
				end
			end
		end
	end
end)

-- =====================================
-- LIMPEZA QUANDO UM PERSONAGEM É REMOVIDO
-- Mata quem está equipado (+1 Deaths pelo fluxo normal),
-- devolve 100% do preço se for da Loja, remove do inventário.
-- =====================================

local function cleanupRemovedFromPlayer(player, characterName)
	local PDM = _G.PlayerDataManager
	if not PDM then
		return
	end

	local charObj = PDM.getCharacterByName and PDM.getCharacterByName(player, characterName)
	if not charObj then
		return
	end

	-- Devolução: só categoria Loja, 100% do preço pago
	local refund = 0
	if charObj.source == "Shop" and (charObj.originalPrice or 0) > 0 then
		refund = charObj.originalPrice
	end

	-- Se está equipado com ele agora → morre (fluxo normal cuida do
	-- desequipar e do +1 em Deaths via o handler Died do GameManager)
	local wasEquipped = false
	if _G.GameManagerConfig and _G.GameManagerConfig.getEquippedCharacter then
		if _G.GameManagerConfig.getEquippedCharacter(player) == characterName then
			wasEquipped = true
			local character = player.Character
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			if humanoid and humanoid.Health > 0 then
				humanoid.Health = 0
			end
		end
	end

	-- Remover do inventário
	if PDM.removeCharacterByName then
		PDM.removeCharacterByName(player, characterName)
	end

	-- Limpar Despertar órfão desse personagem
	local data = PDM.getPlayerData(player)
	if data and data.awakenedCharacters then
		local ai = table.find(data.awakenedCharacters, characterName)
		if ai then
			table.remove(data.awakenedCharacters, ai)
		end
	end

	-- Devolver moedas
	if refund > 0 then
		PDM.updateCoins(player, refund)
	end

	PDM.savePlayerData(player)

	-- Aviso pessoal
	local msg = string.format("🗑️ Seu personagem '%s' foi removido do jogo", characterName)
	if refund > 0 then
		msg = msg .. string.format(" — 💰 %d moedas devolvidas!", refund)
	end
	if wasEquipped then
		msg = msg .. " (você foi desequipado)"
	end
	catalogAnnouncement:FireClient(player, msg, refund > 0)

	print(
		string.format(
			"[CATALOG V6] Limpeza de '%s' em %s | devolvido: %d | equipado: %s",
			characterName,
			player.Name,
			refund,
			tostring(wasEquipped)
		)
	)
end

local function cleanupRemovedFromAllPlayers(characterName)
	for _, p in ipairs(Players:GetPlayers()) do
		task.spawn(cleanupRemovedFromPlayer, p, characterName)
	end
end

-- =====================================
-- SINCRONIZAÇÃO ENTRE TODOS OS SERVIDORES
-- Guarda de JobId — origem não processa a própria mensagem
-- O sync carrega isUpdate pra distinguir add de edição
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

local function addAnnouncementText(adminName, name, isUpdate)
	if isUpdate then
		return string.format("✏️ %s atualizou o personagem '%s'!", adminName or "Um admin", name)
	end
	return string.format("✅ %s adicionou o personagem '%s' ao jogo!", adminName or "Um admin", name)
end

local function applyRemoteChange(action, name, adminName, isUpdate)
	if action == "add" then
		local def = loadDefinition(name)
		if def then
			local warnings = buildCharacterAssets(def)
			applyDefinitionToConfig(def)
			broadcastAnnouncementLocally(addAnnouncementText(adminName, name, isUpdate), true)
			if def.category == "Mandatory" then
				grantMandatoriesToAll()
			end
			-- (V6) Personagem Gamepass novo/editado → checar os online deste servidor
			if def.category == "Gamepass" then
				grantGamepassesToAll()
			end
			if #warnings > 0 then
				warn("[CATALOG V6] Avisos ao sincronizar '" .. name .. "': " .. table.concat(warnings, " | "))
			end
		end
	elseif action == "remove" then
		clearOldFolder(name)
		removeDefinitionFromConfig(name)
		broadcastAnnouncementLocally(
			string.format("🗑️ %s removeu o personagem '%s' do jogo!", adminName or "Um admin", name),
			false
		)
		cleanupRemovedFromAllPlayers(name)
	end
end

pcall(function()
	MessagingService:SubscribeAsync(CONFIG.SYNC_TOPIC, function(message)
		local data = message.Data
		if type(data) == "table" and data.jobId ~= game.JobId then
			applyRemoteChange(data.action, data.name, data.admin, data.isUpdate)
		end
	end)
end)

-- =====================================
-- REMOTES: ADICIONAR/EDITAR / REMOVER / LISTAR (ADMIN)
-- =====================================

adminCatalogAdd.OnServerInvoke = function(player, payload)
	if not isAdmin(player) then
		player:Kick("Tentativa não autorizada de uso de comandos admin")
		return false, "Sem permissão!"
	end

	local ok, msg = validatePayload(payload)
	if not ok then
		return false, msg
	end

	-- Nome já existente no catálogo = EDIÇÃO (upsert)
	local isUpdate = GCC.catalogByName[payload.name] ~= nil

	local def = {
		name = payload.name,
		category = payload.category,
		value = tonumber(payload.value) or 0,
		gamepassId = tonumber(payload.gamepassId) or 0,
		badgeId = tonumber(payload.badgeId) or 0,
		imageId = tonumber(payload.imageId) or 0,
		toolIds = payload.toolIds or {},
		health = tonumber(payload.health) or 100,
		rarity = payload.rarity or "ROBLOXIANOS",
		lore = tostring(payload.lore or ""),
		description = tostring(payload.description or ""),
		addedBy = player.Name,
		addedAt = os.time(),
	}

	local warnings = buildCharacterAssets(def)
	applyDefinitionToConfig(def)
	saveDefinition(def)

	publishSync("add", def.name, player.Name, isUpdate)
	broadcastAnnouncementLocally(addAnnouncementText(player.Name, def.name, isUpdate), true)

	-- Grátis vai direto pro inventário de todos os online
	if def.category == "Mandatory" then
		grantMandatoriesToAll()
	end

	-- (V6) Gamepass: quem JÁ tem a gamepass recebe o personagem na hora
	if def.category == "Gamepass" then
		grantGamepassesToAll()
	end

	print(
		string.format(
			"[CATALOG V6] %s %s '%s' (%s)",
			player.Name,
			isUpdate and "atualizou" or "adicionou",
			def.name,
			def.category
		)
	)

	if #warnings > 0 then
		return true, (isUpdate and "Atualizado" or "Adicionado") .. " com avisos: " .. table.concat(warnings, " | ")
	end
	if isUpdate then
		return true, "Personagem ATUALIZADO em todos os servidores!"
	end
	return true, "Personagem adicionado em todos os servidores!"
end

adminCatalogRemove.OnServerInvoke = function(player, characterName)
	if not isAdmin(player) then
		player:Kick("Tentativa não autorizada de uso de comandos admin")
		return false, "Sem permissão!"
	end
	if type(characterName) ~= "string" then
		return false, "Nome inválido!"
	end

	clearOldFolder(characterName)
	removeDefinitionFromConfig(characterName)
	deleteDefinition(characterName)

	publishSync("remove", characterName, player.Name)
	broadcastAnnouncementLocally(
		string.format("🗑️ %s removeu o personagem '%s' do jogo!", player.Name, characterName),
		false
	)

	-- Limpa o personagem de todos os jogadores DESTE servidor
	-- (os outros servidores fazem o mesmo ao receber o sync)
	cleanupRemovedFromAllPlayers(characterName)

	print(string.format("[CATALOG V6] %s removeu '%s'", player.Name, characterName))
	return true, "Personagem removido em todos os servidores!"
end

adminCatalogList.OnServerInvoke = function(player)
	if not isAdmin(player) then
		return {}
	end
	local list = {}
	for _, def in pairs(GCC.catalogByName) do
		table.insert(list, def)
	end
	return list
end

-- =====================================
-- REMOTE PÚBLICO: LISTAR PARA LOJA/INVENTÁRIO
-- =====================================

getCatalogCharactersRemote.OnServerInvoke = function(player)
	local list = {}
	for _, def in pairs(GCC.catalogByName) do
		table.insert(list, {
			name = def.name,
			category = def.category,
			value = def.value,
			gamepassId = def.category == "Gamepass" and def.gamepassId or nil,
			badgeId = def.category == "Badge" and def.badgeId or nil,
			imageId = def.imageId,
			rarity = def.rarity,
			description = def.description,
			lore = def.lore,
			health = def.health,
		})
	end
	return list
end

-- =====================================
-- LOGIN: CONCEDER GRÁTIS + GAMEPASS + PRUNE DE REMOVIDOS
-- =====================================

local function onPlayerAdded(player)
	task.spawn(function()
		-- Esperar dados do jogador
		local t = 0
		while not (_G.PlayerDataManager and _G.PlayerDataManager.getPlayerData(player)) and t < 30 do
			task.wait(0.5)
			t += 0.5
		end
		if not (_G.PlayerDataManager and _G.PlayerDataManager.getPlayerData(player)) then
			return
		end

		-- Esperar o catálogo terminar de carregar
		t = 0
		while not bootCompleted and t < 45 do
			task.wait(0.5)
			t += 0.5
		end

		-- 1) Grátis direto pro inventário
		grantMandatoriesToPlayer(player)

		-- 2) (V6) Gamepass: quem já tem a gamepass recebe o personagem
		-- AQUI, DEPOIS do catálogo carregar — corrige o defeito do
		-- checkGamepasses (GameManager) que rodava com a tabela vazia.
		grantGamepassCharactersToPlayer(player)

		-- 3) Prune: remover do inventário o que não existe mais no
		-- catálogo (com devolução se era da Loja). Só roda se o
		-- índice do catálogo carregou COM SUCESSO — nunca apaga
		-- inventário por falha de DataStore.
		if bootCompleted and indexLoadOk then
			local data = _G.PlayerDataManager.getPlayerData(player)
			if data and data.ownedCharacters then
				local toRemove = {}
				for _, charObj in ipairs(data.ownedCharacters) do
					if type(charObj) == "table" and charObj.name then
						if not GCC.catalogByName[charObj.name] then
							table.insert(toRemove, charObj.name)
						end
					end
				end
				for _, name in ipairs(toRemove) do
					cleanupRemovedFromPlayer(player, name)
				end
				if #toRemove > 0 then
					print(
						string.format(
							"[CATALOG V6] Prune de login em %s: %d personagem(ns) removido(s)",
							player.Name,
							#toRemove
						)
					)
				end
			end
		end
	end)
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, p in ipairs(Players:GetPlayers()) do
	onPlayerAdded(p)
end

-- =====================================
-- BOOT: RECONSTRUIR TUDO A PARTIR DO DATASTORE
-- =====================================

local function bootLoadCatalog()
	print("[CATALOG V6] Carregando catálogo salvo...")
	local index, okIndex = loadIndex()
	indexLoadOk = okIndex
	local loaded = 0

	for _, name in ipairs(index) do
		local def = loadDefinition(name)
		if def then
			local warnings = buildCharacterAssets(def)
			applyDefinitionToConfig(def)
			loaded += 1
			if #warnings > 0 then
				warn("[CATALOG V6] Avisos ao carregar '" .. name .. "': " .. table.concat(warnings, " | "))
			end
		end
	end

	bootCompleted = true
	grantMandatoriesToAll()

	-- (V6) Boot terminou → checar gamepasses de todos que já
	-- estão online (cobre quem entrou antes do catálogo carregar)
	grantGamepassesToAll()

	print(
		string.format(
			"[CATALOG V6] ✓ %d personagem(ns) carregado(s) | índice ok: %s",
			loaded,
			tostring(indexLoadOk)
		)
	)
	if not indexLoadOk then
		warn("[CATALOG V6] ⚠️ Índice do catálogo falhou ao carregar — prune de login DESATIVADO nesta sessão.")
	end
end

task.spawn(bootLoadCatalog)

-- =====================================
-- API GLOBAL EXTRA
-- =====================================

_G.CharacterCatalog = {
	getDefinition = function(name)
		return GCC.catalogByName[name]
	end,
	listAll = function()
		return GCC.catalogByName
	end,
	-- (V6) outros sistemas podem perguntar se o catálogo já carregou
	isReady = function()
		return bootCompleted
	end,
	-- (V6) reprocessar gamepasses de um jogador sob demanda
	recheckGamepasses = function(player)
		task.spawn(grantGamepassCharactersToPlayer, player)
	end,
}

_G.DebugCatalog = function()
	print("\n========== DEBUG CATALOG V6 ==========")
	for name, def in pairs(GCC.catalogByName) do
		print(
			string.format(
				"  %s | %s | valor=%s | tools=%d | raridade=%s",
				name,
				def.category,
				tostring(def.value),
				#(def.toolIds or {}),
				def.rarity
			)
		)
	end
	print("=======================================\n")
end

print([[
╔════════════════════════════════════════════════════╗
║  ✅ CHARACTER CATALOG SERVER V6 CARREGADO          ║
╠════════════════════════════════════════════════════╣
║  SUBSTITUI: CharacterCatalogServer V5               ║
║  DEPENDE DE: AdminRegistryServer_V1                 ║
╠════════════════════════════════════════════════════╣
║  (V6) GAMEPASS AUTOMÁTICO:                          ║
║  • Login: concede após o catálogo carregar          ║
║  • Compra em jogo: concede NA HORA (Prompt          ║
║    GamePassPurchaseFinished) — sem relogar          ║
║  • Admin adiciona personagem Gamepass: todos os     ║
║    online são verificados (todos os servidores)     ║
║  (V5) _G.AdminRegistry + edição reconhecida         ║
║  (V4) Grátis no inventário + remoção segura         ║
╠════════════════════════════════════════════════════╣
║  DEBUG: _G.DebugCatalog()                           ║
╚════════════════════════════════════════════════════╝
]])
