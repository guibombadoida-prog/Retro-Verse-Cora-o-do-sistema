-- ============================================
-- AWAKENING SYSTEM SERVER V3 — DESPERTAR (SEM STUDIO)
-- Coloque em ServerScriptService
-- Nome: "AwakeningSystemServer"
-- SUBSTITUI: AwakeningSystemServer V2
-- REMOVER:   AwakeningSystemServer V2
-- DEPENDE DE: AdminRegistryServer_V1, GameManager_V9 (usa AwakenedForm),
--             CharacterCatalogServer_V6 (_G.CharacterCatalog — NOVO no V3)
-- ============================================
-- (V3) BUG GRAVE CORRIGIDO — DESPERTAR SOLTO, SEM ORIGINAL
--
-- Um Despertar existe SEMPRE em cima de um personagem que já existe.
-- No V2 dava para criar um Despertar do nada, e o resultado era um
-- personagem destravado só por Badge — ou seja, um personagem de
-- emblema comum, criado pela porta errada.
--
-- 🐛 CAUSA 1 — VALIDAÇÃO NÃO OLHAVA O CATÁLOGO.
--    `validatePayload` conferia tamanho do nome e Badge ID, e nada
--    mais. Digitar "Gokú" (ou qualquer nome inventado, ou um nome
--    certo com erro de digitação) passava direto.
--
-- 🐛 CAUSA 2 — A CONSTRUÇÃO CRIAVA O PERSONAGEM FANTASMA.
--    `buildAwakenedAssets` fazia:
--        if not baseFolder then ... baseFolder.Parent = charactersFolder
--    Ou seja: personagem não existia, então ele CRIAVA a pasta em
--    ReplicatedStorage.Characters. Isso dava ao fantasma a mesma
--    estrutura de um personagem de verdade, e é por isso que ele
--    "virava um personagem de emblema normal".
--
--    Efeito colateral cruel: como `ownsCharacter(player, fantasma)`
--    é sempre falso, NINGUÉM conseguia desbloquear aquele Despertar.
--    Era configuração morta sujando o ReplicatedStorage e a lista do
--    painel admin, sem nenhum erro no Output.
--
-- ✅ CORREÇÃO:
--    • `validatePayload` agora exige que o personagem exista no
--      catálogo (_G.CharacterCatalog.getDefinition). Sem original,
--      o painel recebe "Personagem 'X' não existe no catálogo".
--    • `buildAwakenedAssets` NUNCA cria a pasta base. Se ela não
--      existe, ele recusa e devolve erro.
--    • `bootLoadAwakenings` espera o catálogo carregar antes de
--      reconstruir (senão a checagem acusaria falso negativo na
--      corrida de boot) e agora ACUSA os Despertares órfãos que o
--      V2 já pode ter salvo, em vez de recriar o fantasma.
--    • `_G.DebugAwakening()` marca os órfãos com ⚠️ e explica como
--      limpar.
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
	-- (V3) Segundos de espera pelo catálogo no boot antes de reconstruir
	-- os Despertares. Sem essa espera, a checagem de personagem original
	-- rodaria com o catálogo vazio e marcaria tudo como órfão.
	CATALOG_WAIT = 30,
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

-- (V3) Despertares salvos cujo personagem original não existe. Ficam
-- FORA de awakenDefs (não são construídos nem ficam equipáveis), mas
-- são guardados aqui para aparecerem na lista do painel admin — senão
-- o admin não teria como removê-los.
local orphanDefs = {} -- [characterName] = definição
local orphanNames = {} -- ordem de descoberta, para a mensagem de boot

-- =====================================
-- (V3) O ORIGINAL EXISTE?
-- =====================================
-- Um Despertar é uma FORMA de um personagem existente, nunca um
-- personagem por conta própria. Esta é a única função que responde
-- isso, e todo caminho de criação passa por ela.
--
-- A autoridade é o catálogo (_G.CharacterCatalog, respaldado por
-- DataStore), não a pasta em ReplicatedStorage — a pasta é efeito,
-- não causa. Se o catálogo não estiver instalado, cai para a pasta
-- como último recurso, mas nunca dá o "sim" de graça.

local function originalExists(name)
	if type(name) ~= "string" or #name < 2 then
		return false
	end

	if _G.CharacterCatalog and _G.CharacterCatalog.getDefinition then
		local ok, def = pcall(_G.CharacterCatalog.getDefinition, name)
		if ok then
			return def ~= nil
		end
	end

	-- Sem catálogo disponível: a pasta é o que sobra para consultar
	return charactersFolder:FindFirstChild(name) ~= nil
end

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
				"[AWAKENING V3] ⚠️ Tool '%s' carregada SEM Handle — não vai funcionar até corrigir o modelo de origem.",
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

-- Devolve: lista de avisos, erro (string) ou nil
-- Erro não-nil significa que NADA foi construído.
local function buildAwakenedAssets(def)
	-- (V3) NUNCA criar a pasta base aqui. O V2 criava, e era isso que
	-- transformava um nome inventado num personagem de aparência
	-- legítima em ReplicatedStorage.Characters. A pasta base é
	-- responsabilidade exclusiva do CharacterCatalogServer.
	local baseFolder = charactersFolder:FindFirstChild(def.characterName)
	if not baseFolder then
		return {}, string.format(
			"Personagem '%s' não existe — o Despertar precisa de um personagem original. Crie o personagem no catálogo primeiro.",
			def.characterName
		)
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

	return warnings, nil
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

	-- (V3) A REGRA QUE FALTAVA: sem personagem original, não há
	-- Despertar. Um Despertar destravado só por Badge, sem original,
	-- é um personagem de emblema comum criado pela porta errada.
	if not originalExists(payload.characterName) then
		return false,
			string.format(
				"Personagem '%s' não existe no catálogo! O Despertar é uma FORMA de um personagem que já existe — crie o personagem primeiro na aba CATÁLOGO. (Confira também se o nome está escrito exatamente igual.)",
				payload.characterName
			)
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
			-- (V3) Se o original não existe neste servidor, não constrói
			-- nem registra. Antes isso criava o fantasma aqui também,
			-- espalhando o problema para toda a frota de servidores.
			local warnings, err = buildAwakenedAssets(def)
			if err then
				warn("[AWAKENING V3] Sync de '" .. name .. "' ignorado: " .. err)
				return
			end
			awakenDefs[name] = def
			broadcastAnnouncementLocally(setAnnouncementText(adminName, name, isUpdate), true)
			if #warnings > 0 then
				warn("[AWAKENING V3] Avisos ao sincronizar '" .. name .. "': " .. table.concat(warnings, " | "))
			end
		end
	elseif action == "remove" then
		removeAwakenedAssets(name)
		awakenDefs[name] = nil
		orphanDefs[name] = nil -- (V3)
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

	-- (V3) Segunda barreira, de propósito. O validatePayload já barrou
	-- o caso normal; esta pega a corrida em que o personagem é apagado
	-- do catálogo entre a validação e a construção. Nada é salvo nem
	-- propagado se a construção recusar.
	local warnings, err = buildAwakenedAssets(def)
	if err then
		return false, err
	end

	awakenDefs[def.characterName] = def
	orphanDefs[def.characterName] = nil -- (V3) deixou de ser órfão
	saveDefinition(def)

	publishSync("set", def.characterName, player.Name, isUpdate)
	broadcastAnnouncementLocally(setAnnouncementText(player.Name, def.characterName, isUpdate), true)

	print(
		string.format(
			"[AWAKENING V3] %s %s Despertar de '%s'",
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
	orphanDefs[characterName] = nil -- (V3) limpar órfão também
	deleteDefinition(characterName)

	publishSync("remove", characterName, player.Name)
	broadcastAnnouncementLocally(
		string.format("🗑️ %s removeu o Despertar de '%s'!", player.Name, characterName),
		false
	)

	print(string.format("[AWAKENING V3] %s removeu Despertar de '%s'", player.Name, characterName))
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

	-- (V3) Os órfãos TAMBÉM entram na lista. Eles não estão em
	-- awakenDefs porque não foram construídos, mas se ficarem fora
	-- daqui o admin não tem como clicar em 🗑️ para limpá-los — a
	-- correção viraria um beco sem saída.
	--
	-- O aviso vai no displayName porque é o campo que o painel já
	-- mostra: aparece sem precisar mexer no AdminMenuClient. A cópia
	-- é rasa e descartável, então o displayName salvo não é tocado.
	for _, def in pairs(orphanDefs) do
		local copia = {}
		for k, v in pairs(def) do
			copia[k] = v
		end
		copia.isOrphan = true
		copia.displayName = "⚠️ ÓRFÃO (sem personagem original) — " .. tostring(def.displayName or def.characterName)
		table.insert(list, copia)
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

	print(string.format("[AWAKENING V3] %s desbloqueou o Despertar de '%s'", player.Name, characterName))
end)

-- =====================================
-- BOOT: RECONSTRUIR TUDO A PARTIR DO DATASTORE
-- =====================================

local function bootLoadAwakenings()
	-- (V3) Esperar o catálogo. Sem isso a checagem de original daria
	-- falso negativo na corrida de boot e TODO Despertar legítimo
	-- seria marcado como órfão.
	if _G.CharacterCatalog and _G.CharacterCatalog.isReady then
		local esperou = 0
		while not _G.CharacterCatalog.isReady() and esperou < CONFIG.CATALOG_WAIT do
			task.wait(0.5)
			esperou += 0.5
		end
		if not _G.CharacterCatalog.isReady() then
			warn(
				string.format(
					"[AWAKENING V3] Catálogo não ficou pronto em %ds — seguindo com a pasta Characters como referência",
					CONFIG.CATALOG_WAIT
				)
			)
		end
	end

	print("[AWAKENING V3] Carregando configurações de Despertar salvas...")
	local index = loadIndex()
	local loaded = 0

	for _, name in ipairs(index) do
		local def = loadDefinition(name)
		if def then
			-- (V3) Órfão NÃO é reconstruído. Antes o buildAwakenedAssets
			-- recriava a pasta do personagem inexistente a cada boot,
			-- ressuscitando o fantasma para sempre.
			local warnings, err = buildAwakenedAssets(def)
			if err then
				orphanDefs[name] = def
				table.insert(orphanNames, name)
				warn(string.format("[AWAKENING V3] ⚠️ Despertar ÓRFÃO ignorado: '%s' — %s", name, err))
			else
				awakenDefs[name] = def
				loaded += 1
				if #warnings > 0 then
					warn("[AWAKENING V3] Avisos ao carregar '" .. name .. "': " .. table.concat(warnings, " | "))
				end
			end
		end
	end

	print(string.format("[AWAKENING V3] ✓ %d Despertar(es) carregado(s)", loaded))

	if #orphanNames > 0 then
		warn(
			string.format(
				"[AWAKENING V3] ⚠️ %d Despertar(es) ÓRFÃO(S) encontrado(s): %s\n"
					.. "  Foram criados sem personagem original (bug do V2) e NUNCA poderiam ser\n"
					.. "  desbloqueados, porque ninguém pode possuir um personagem que não existe.\n"
					.. "  Para resolver, escolha um caminho por nome:\n"
					.. "    (a) criar o personagem original na aba CATÁLOGO com esse nome exato, ou\n"
					.. "    (b) remover o Despertar pelo botão 🗑️ do painel admin.\n"
					.. "  Veja a lista a qualquer momento com _G.DebugAwakening()",
				#orphanNames,
				table.concat(orphanNames, ", ")
			)
		)
	end
end

task.spawn(bootLoadAwakenings)

-- =====================================
-- DEBUG
-- =====================================

_G.DebugAwakening = function()
	print("\n========== DEBUG AWAKENING V3 ==========")

	local algum = false
	for name, def in pairs(awakenDefs) do
		algum = true
		print(
			string.format(
				"  ✓ %s → %s | Badge: %d | Tools: %d",
				name,
				def.displayName,
				def.badgeId,
				#(def.toolIds or {})
			)
		)
	end
	if not algum then
		print("  (nenhum Despertar ativo)")
	end

	-- (V3) Órfãos: existem no DataStore, mas o personagem original não
	-- existe. Nunca foram desbloqueáveis, porque ninguém pode possuir
	-- um personagem que não existe.
	local qtdOrfaos = 0
	for _ in pairs(orphanDefs) do
		qtdOrfaos += 1
	end

	if qtdOrfaos > 0 then
		print(string.format("\n  ⚠️ %d ÓRFÃO(S) — sem personagem original:", qtdOrfaos))
		for name, def in pairs(orphanDefs) do
			print(string.format("     %s (Badge: %s)", name, tostring(def.badgeId)))
		end
		print("\n  Como resolver, por nome:")
		print("    (a) criar o personagem original na aba CATÁLOGO com o nome EXATO, ou")
		print("    (b) remover o Despertar pelo botão 🗑️ do painel admin")
		print("        (os órfãos aparecem na lista marcados com ⚠️ ÓRFÃO)")
	end

	print("=========================================\n")
end

print([[
╔════════════════════════════════════════════════════╗
║  ⚡ AWAKENING SYSTEM SERVER V3 CARREGADO           ║
╠════════════════════════════════════════════════════╣
║  SUBSTITUI: AwakeningSystemServer V2               ║
║  REMOVER:   AwakeningSystemServer V2               ║
║  DEPENDE DE: AdminRegistryServer_V1, GameManager_V9║
║              CharacterCatalogServer_V6 (NOVO)      ║
╠════════════════════════════════════════════════════╣
║  (V3) NÃO dá mais para criar Despertar solto:      ║
║       exige personagem original no catálogo        ║
║  (V3) Nunca cria pasta de personagem fantasma      ║
║  (V3) Despertar órfão é acusado, não reconstruído  ║
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
