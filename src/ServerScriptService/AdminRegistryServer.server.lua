-- ============================================
-- ADMIN REGISTRY SERVER V1 — ADMINS SEM STUDIO
-- Coloque em ServerScriptService
-- Nome: "AdminRegistryServer"
-- SCRIPT NOVO — não substitui nenhum
-- ============================================
-- O QUE ESSE SCRIPT FAZ:
-- • ÚNICO ID no código: o DONO (1595442496) — imutável e
--   irremovível. TODOS os outros admins são adicionados DENTRO
--   do jogo, por USERNAME ou USERID, sem abrir o Studio.
-- • Salva a lista no DataStore "RVAdminsV1" (sobrevive a restart).
-- • Sincroniza ADD/REMOVE em TODOS os servidores ativos via
--   MessagingService (com guarda de JobId — sem eco duplicado).
-- • Expõe a API global _G.AdminRegistry pros outros sistemas
--   (AdminSystemServer_V8 já usa; CharacterCatalogServer,
--   AwakeningSystemServer e AchievementSystemServer usarão nas
--   próximas versões).
--
-- REMOTES CRIADOS:
-- • AdminRegistryAdd(usernameOuId)    → só admins
-- • AdminRegistryRemove(usernameOuId) → só admins (dono irremovível)
-- • AdminRegistryList()               → só admins
-- • IsAdminCheck()                    → PÚBLICO: o próprio jogador
--   pergunta "eu sou admin?" — usado pelos menus client pra decidir
--   se mostram o painel (AdminMenuClient V9 / AchievementMenuClient V3)
--
-- REUTILIZADO:
-- • Padrão DataStore + MessagingService + guarda de JobId
--   .............. CharacterCatalogServer_V4 / AchievementSystemServer_V2
-- • Padrão ensureRemote .......... CharacterCatalogServer / MissionSystemServer_V2
-- ============================================
-- ⚠️ Em Game Settings → Security, "Allow Studio Access to API
-- Services" precisa estar ATIVO pra testar no Studio.
-- ============================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")
local MessagingService = game:GetService("MessagingService")

-- =====================================
-- CONFIGURAÇÃO
-- =====================================

-- 🔑 ÚNICO ID QUE FICA NO STUDIO — o dono do jogo.
-- Nunca pode ser removido, nem por outro admin.
local OWNER_ID = 1595442496

local CONFIG = {
	STORE_NAME = "RVAdminsV1",
	STORE_KEY = "AdminList",
	SYNC_TOPIC = "RVAdminSync",
	LOAD_RETRIES = 3,
}

local adminStore = DataStoreService:GetDataStore(CONFIG.STORE_NAME)

-- Estado em memória: { [userId número] = { name, addedBy, addedAt } }
local dynamicAdmins = {}
local storeLoadedOk = false

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

local adminRegistryAdd = ensureRemote("AdminRegistryAdd", "RemoteFunction")
local adminRegistryRemove = ensureRemote("AdminRegistryRemove", "RemoteFunction")
local adminRegistryList = ensureRemote("AdminRegistryList", "RemoteFunction")
local isAdminCheck = ensureRemote("IsAdminCheck", "RemoteFunction") -- público

-- =====================================
-- FUNÇÕES BASE
-- =====================================

local function isAdminUserId(userId)
	userId = tonumber(userId)
	if not userId then
		return false
	end
	if userId == OWNER_ID then
		return true
	end
	return dynamicAdmins[userId] ~= nil
end

local function isAdmin(player)
	return player ~= nil and isAdminUserId(player.UserId)
end

-- =====================================
-- DATASTORE (salvar / carregar)
-- Chaves de tabela viram string no DataStore
-- =====================================

local function saveAdmins()
	local toSave = {}
	for id, info in pairs(dynamicAdmins) do
		toSave[tostring(id)] = {
			name = info.name or "?",
			addedBy = info.addedBy or "?",
			addedAt = info.addedAt or os.time(),
		}
	end

	local ok, err = pcall(function()
		adminStore:SetAsync(CONFIG.STORE_KEY, toSave)
	end)
	if not ok then
		warn("[ADMIN REGISTRY V1] Falha ao salvar admins: " .. tostring(err))
	end
	return ok
end

local function loadAdmins()
	for attempt = 1, CONFIG.LOAD_RETRIES do
		local ok, data = pcall(function()
			return adminStore:GetAsync(CONFIG.STORE_KEY)
		end)

		if ok then
			dynamicAdmins = {}
			if type(data) == "table" then
				for idStr, info in pairs(data) do
					local id = tonumber(idStr)
					if id and type(info) == "table" then
						dynamicAdmins[id] = {
							name = info.name or "?",
							addedBy = info.addedBy or "?",
							addedAt = info.addedAt or 0,
						}
					end
				end
			end
			storeLoadedOk = true
			return true
		end

		warn("[ADMIN REGISTRY V1] Tentativa " .. attempt .. " de carregar admins falhou")
		task.wait(2)
	end

	warn("[ADMIN REGISTRY V1] ⚠️ DataStore indisponível — só o DONO é admin nesta sessão")
	return false
end

-- =====================================
-- RESOLVER USERNAME OU ID → (userId, nome)
-- =====================================

local function resolveUser(input)
	if type(input) ~= "string" or input == "" then
		return nil, nil
	end

	-- Número puro = UserId direto
	local asNumber = tonumber(input)
	if asNumber and asNumber > 0 then
		asNumber = math.floor(asNumber)
		local displayName = "ID:" .. asNumber

		local onlinePlayer = Players:GetPlayerByUserId(asNumber)
		if onlinePlayer then
			displayName = onlinePlayer.Name
		else
			pcall(function()
				displayName = Players:GetNameFromUserIdAsync(asNumber)
			end)
		end
		return asNumber, displayName
	end

	-- Username: primeiro procura online (exato), depois pergunta à API
	local onlinePlayer = Players:FindFirstChild(input)
	if onlinePlayer then
		return onlinePlayer.UserId, onlinePlayer.Name
	end

	local resolvedId = nil
	local ok = pcall(function()
		resolvedId = Players:GetUserIdFromNameAsync(input)
	end)
	if ok and resolvedId then
		return resolvedId, input
	end

	return nil, nil
end

-- =====================================
-- SYNC ENTRE SERVIDORES (MessagingService)
-- Guarda de JobId: o servidor de origem não processa o próprio eco
-- =====================================

local function publishSync(action, userId, name, byName)
	pcall(function()
		MessagingService:PublishAsync(CONFIG.SYNC_TOPIC, {
			jobId = game.JobId,
			action = action, -- "add" | "remove"
			userId = userId,
			name = name,
			by = byName,
		})
	end)
end

pcall(function()
	MessagingService:SubscribeAsync(CONFIG.SYNC_TOPIC, function(message)
		local data = message.Data
		if type(data) ~= "table" then
			return
		end
		if data.jobId == game.JobId then
			return -- eco do próprio servidor
		end

		local userId = tonumber(data.userId)
		if not userId then
			return
		end

		if data.action == "add" then
			dynamicAdmins[userId] = {
				name = data.name or "?",
				addedBy = data.by or "?",
				addedAt = os.time(),
			}
			print(string.format("[ADMIN REGISTRY V1] (sync) %s virou admin (por %s)", tostring(data.name), tostring(data.by)))
		elseif data.action == "remove" then
			dynamicAdmins[userId] = nil
			print(string.format("[ADMIN REGISTRY V1] (sync) %s deixou de ser admin (por %s)", tostring(data.name), tostring(data.by)))
		end
	end)
end)

-- =====================================
-- AÇÕES (add / remove / list)
-- =====================================

local function addAdmin(requester, input)
	local requesterName = (typeof(requester) == "Instance" and requester.Name) or tostring(requester)

	local userId, displayName = resolveUser(tostring(input or ""))
	if not userId then
		return false, "Jogador não encontrado! Use o username exato ou o UserId."
	end

	if isAdminUserId(userId) then
		return false, displayName .. " já é admin!"
	end

	dynamicAdmins[userId] = {
		name = displayName,
		addedBy = requesterName,
		addedAt = os.time(),
	}

	if not saveAdmins() then
		dynamicAdmins[userId] = nil
		return false, "Falha ao salvar no DataStore — tente de novo."
	end

	publishSync("add", userId, displayName, requesterName)
	print(string.format("[ADMIN REGISTRY V1] %s adicionou %s (ID %d) como admin", requesterName, displayName, userId))
	return true, displayName .. " agora é ADMIN em todos os servidores!"
end

local function removeAdmin(requester, input)
	local requesterName = (typeof(requester) == "Instance" and requester.Name) or tostring(requester)
	local requesterId = (typeof(requester) == "Instance" and requester.UserId) or nil

	local userId, displayName = resolveUser(tostring(input or ""))
	if not userId then
		return false, "Jogador não encontrado! Use o username exato ou o UserId."
	end

	if userId == OWNER_ID then
		return false, "O DONO do jogo não pode ser removido!"
	end

	if requesterId and userId == requesterId then
		return false, "Você não pode remover a si mesmo!"
	end

	if not dynamicAdmins[userId] then
		return false, displayName .. " não é admin."
	end

	local backup = dynamicAdmins[userId]
	dynamicAdmins[userId] = nil

	if not saveAdmins() then
		dynamicAdmins[userId] = backup
		return false, "Falha ao salvar no DataStore — tente de novo."
	end

	publishSync("remove", userId, displayName, requesterName)
	print(string.format("[ADMIN REGISTRY V1] %s removeu %s (ID %d) dos admins", requesterName, displayName, userId))
	return true, displayName .. " não é mais admin (em todos os servidores)."
end

local function listAdmins()
	local list = {
		{
			userId = OWNER_ID,
			name = "DONO",
			addedBy = "Studio",
			addedAt = 0,
			isOwner = true,
		},
	}

	-- Tenta mostrar o nome real do dono
	local ownerOnline = Players:GetPlayerByUserId(OWNER_ID)
	if ownerOnline then
		list[1].name = ownerOnline.Name .. " (DONO)"
	end

	for userId, info in pairs(dynamicAdmins) do
		table.insert(list, {
			userId = userId,
			name = info.name or "?",
			addedBy = info.addedBy or "?",
			addedAt = info.addedAt or 0,
			isOwner = false,
		})
	end

	table.sort(list, function(a, b)
		if a.isOwner ~= b.isOwner then
			return a.isOwner
		end
		return (a.name or "") < (b.name or "")
	end)

	return list
end

-- =====================================
-- HANDLERS DOS REMOTES
-- =====================================

adminRegistryAdd.OnServerInvoke = function(player, input)
	if not isAdmin(player) then
		player:Kick("Tentativa não autorizada de uso de comandos admin")
		return false, "Sem permissão!"
	end
	return addAdmin(player, input)
end

adminRegistryRemove.OnServerInvoke = function(player, input)
	if not isAdmin(player) then
		player:Kick("Tentativa não autorizada de uso de comandos admin")
		return false, "Sem permissão!"
	end
	return removeAdmin(player, input)
end

adminRegistryList.OnServerInvoke = function(player)
	if not isAdmin(player) then
		return {}
	end
	return listAdmins()
end

-- PÚBLICO: cada jogador só consegue perguntar sobre SI MESMO
isAdminCheck.OnServerInvoke = function(player)
	return isAdmin(player)
end

-- =====================================
-- API GLOBAL (_G) PROS OUTROS SISTEMAS
-- =====================================

_G.AdminRegistry = {
	isAdmin = isAdmin,
	isAdminUserId = isAdminUserId,
	listAll = listAdmins,
	addAdmin = addAdmin,
	removeAdmin = removeAdmin,
	OWNER_ID = OWNER_ID,
}

_G.DebugAdmins = function()
	print("\n========== DEBUG ADMIN REGISTRY V1 ==========")
	for _, entry in ipairs(listAdmins()) do
		print(
			string.format(
				"  %s | ID: %d | por: %s%s",
				entry.name,
				entry.userId,
				entry.addedBy,
				entry.isOwner and " | 🔑 DONO (Studio)" or ""
			)
		)
	end
	print("=============================================\n")
end

-- =====================================
-- BOOT
-- =====================================

loadAdmins()

local dynamicCount = 0
for _ in pairs(dynamicAdmins) do
	dynamicCount += 1
end

print(string.format(
	"[ADMIN REGISTRY V1] ✓ Carregado — DONO (%d) + %d admin(s) dinâmico(s)%s",
	OWNER_ID,
	dynamicCount,
	storeLoadedOk and "" or " ⚠️ (DataStore falhou)"
	))

print([[
╔════════════════════════════════════════════════════╗
║  🔑 ADMIN REGISTRY SERVER V1 CARREGADO            ║
╠════════════════════════════════════════════════════╣
║  SCRIPT NOVO — não substitui nenhum                ║
╠════════════════════════════════════════════════════╣
║  • ÚNICO ID no Studio: o DONO (irremovível)        ║
║  • Demais admins: dentro do jogo, por username/ID  ║
║  • Persistente (DataStore RVAdminsV1)              ║
║  • Sincroniza em TODOS os servidores (Messaging)   ║
║  • API: _G.AdminRegistry | DEBUG: _G.DebugAdmins() ║
╚════════════════════════════════════════════════════╝
]])
