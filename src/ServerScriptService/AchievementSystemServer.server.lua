-- ============================================
-- ACHIEVEMENT SYSTEM SERVER V3 — CONQUISTAS DINÂMICAS (SEM STUDIO)
-- Coloque em ServerScriptService
-- Nome: "AchievementSystemServer"
-- SUBSTITUI: AchievementSystemServer V2
-- REMOVER:   AchievementSystemServer V2
-- DEPENDE DE: AdminRegistryServer_V1 (novo, no ServerScriptService)
-- ============================================
-- (V3) ALTERAÇÕES:
-- • LISTA "ADMIN_IDS" REMOVIDA DO CÓDIGO: quem é admin agora vem
--   do _G.AdminRegistry (AdminRegistryServer_V1) — o ÚNICO id no
--   Studio é o do DONO (1595442496); os outros são adicionados
--   dentro do jogo (;addadmin ou aba ADMINS do painel V9), ficam
--   salvos no DataStore e valem em TODOS os servidores.
--   Fim das listas dessincronizadas entre scripts.
-- ============================================
-- MANTIDO DO V2 (tudo):
-- • Prêmio validado contra o catálogo dinâmico antes de conceder
--   (fim do bug do personagem fantasma do V1)
-- • Conquistas dinâmicas: AdminAchievementSet/Remove/List, salvas
--   no DataStore "RVAchievementsV1", sync entre servidores
-- • As 8 conquistas padrão como BASE, sem personagem-prêmio
--   (mesmo nome = sobrescreve; tombstone remove até as padrão)
-- • Guarda de JobId no MessagingService
--
-- REUTILIZADO:
-- • _G.AdminRegistry.isAdmin ....... AdminRegistryServer_V1
-- • addCharacter(source "Badge") / ownsCharacter / getPlayerData /
--   savePlayerData / claimedAchievements no save ... DataManager_V6
-- • ensureRemote / espera do _G.PlayerDataManager .. MissionSystemServer_V2
-- • DataStore índice+defs / MessagingService / kick de
--   não-autorizado / CatalogAnnouncement ......... CharacterCatalogServer_V5
-- • BadgeService (Badge real opcional) ........... GameManager_V9
-- • Stats lidos: kills_total (GameManager), duels_won (DuelSystem),
--   hunts (WantedSystem), trades_completed (TradeSystem), etc.
-- ============================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")
local MessagingService = game:GetService("MessagingService")
local BadgeService = game:GetService("BadgeService")

-- =====================================
-- CONFIGURAÇÃO
-- =====================================

-- (V3) Fallback de segurança: se o AdminRegistryServer_V1 não
-- estiver instalado, só o DONO é admin (mesmo id do registry).
local FALLBACK_OWNER_ID = 1595442496

local CONFIG = {
	STORE_NAME = "RVAchievementsV1",
	SYNC_TOPIC = "RVAchievementSync",
	CHECK_INTERVAL = 10, -- segundos entre verificações automáticas
}

-- Stats válidos (gravados pelos sistemas existentes no DataManager)
local VALID_STATS = {
	kills_total = "Kills (total)",
	deaths = "Mortes",
	duels_won = "Duelos vencidos",
	hunts = "Caçadas (Wanted)",
	trades_completed = "Trocas completadas",
	coins_earned_total = "Moedas ganhas (total)",
	characters_bought = "Personagens comprados",
	characters_sold = "Personagens vendidos",
	bounty = "Bounty atual",
}

-- (V3) Admin dinâmico via registro central
local function isAdmin(player)
	if _G.AdminRegistry then
		return _G.AdminRegistry.isAdmin(player)
	end
	return player ~= nil and player.UserId == FALLBACK_OWNER_ID
end

-- =====================================
-- CONQUISTAS PADRÃO (BASE)
-- rewardCharacter = "" de propósito: o V1 apontava para
-- personagens inexistentes. Configure os prêmios pelo painel
-- admin com nomes REAIS do catálogo — editar pelo painel usando
-- o mesmo nome sobrescreve estas.
-- =====================================

local DEFAULT_ACHIEVEMENTS = {
	{ id = "first_blood", name = "PRIMEIRO SANGUE", desc = "Elimine 1 jogador", icon = "🩸", stat = "kills_total", amount = 1, rewardCharacter = "", realBadgeId = 0 },
	{ id = "hunter_25", name = "CAÇADOR NATO", desc = "Elimine 25 jogadores", icon = "🔪", stat = "kills_total", amount = 25, rewardCharacter = "", realBadgeId = 0 },
	{ id = "exterminator", name = "EXTERMINADOR", desc = "Elimine 100 jogadores", icon = "💀", stat = "kills_total", amount = 100, rewardCharacter = "", realBadgeId = 0 },
	{ id = "duelist_1", name = "DUELISTA", desc = "Vença 1 duelo 1v1", icon = "⚔️", stat = "duels_won", amount = 1, rewardCharacter = "", realBadgeId = 0 },
	{ id = "gladiator_10", name = "GLADIADOR", desc = "Vença 10 duelos 1v1", icon = "🏟️", stat = "duels_won", amount = 10, rewardCharacter = "", realBadgeId = 0 },
	{ id = "bounty_hunter", name = "CAÇA-RECOMPENSAS", desc = "Cace o ALVO procurado 1 vez", icon = "🎯", stat = "hunts", amount = 1, rewardCharacter = "", realBadgeId = 0 },
	{ id = "tycoon", name = "MAGNATA", desc = "Acumule 10.000 moedas ganhas", icon = "💰", stat = "coins_earned_total", amount = 10000, rewardCharacter = "", realBadgeId = 0 },
	{ id = "trader_5", name = "COMERCIANTE", desc = "Complete 5 trocas", icon = "🤝", stat = "trades_completed", amount = 5, rewardCharacter = "", realBadgeId = 0 },
}

-- Aguardar o gerenciador de dados (REUTILIZADO do MissionSystemServer_V2)
repeat
	task.wait()
until _G.PlayerDataManager

local PDM = _G.PlayerDataManager

-- =====================================
-- DATASTORE
-- =====================================

local achStore = DataStoreService:GetDataStore(CONFIG.STORE_NAME)

-- =====================================
-- REMOTES (padrão REUTILIZADO do MissionSystemServer_V2)
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

local getAchievementsRemote = ensureRemote("GetAchievements", "RemoteFunction") -- client -> server (todos)
local achievementUnlockedRemote = ensureRemote("AchievementUnlocked", "RemoteEvent") -- server -> client
local adminAchSet = ensureRemote("AdminAchievementSet", "RemoteFunction") -- admin
local adminAchRemove = ensureRemote("AdminAchievementRemove", "RemoteFunction") -- admin
local adminAchList = ensureRemote("AdminAchievementList", "RemoteFunction") -- admin
local catalogAnnouncement = ensureRemote("CatalogAnnouncement", "RemoteEvent") -- REUTILIZADO do CharacterCatalogServer_V5

-- =====================================
-- ESTADO EM MEMÓRIA
-- dynamicDefs[id] = definição OU tombstone {id, removed=true}
-- =====================================

local dynamicDefs = {}

-- Lista final: padrões (sobrescritos/removidos pelos dinâmicos de
-- mesmo id) + dinâmicos extras em ordem de criação
local function getMergedAchievements()
	local merged = {}
	local seen = {}

	for _, ach in ipairs(DEFAULT_ACHIEVEMENTS) do
		seen[ach.id] = true
		local dyn = dynamicDefs[ach.id]
		if dyn then
			if not dyn.removed then
				table.insert(merged, dyn)
			end
		else
			table.insert(merged, ach)
		end
	end

	local extras = {}
	for id, def in pairs(dynamicDefs) do
		if not seen[id] and not def.removed then
			table.insert(extras, def)
		end
	end
	table.sort(extras, function(a, b)
		return (a.addedAt or 0) < (b.addedAt or 0)
	end)
	for _, def in ipairs(extras) do
		table.insert(merged, def)
	end

	return merged
end

local function findAchievementById(achId)
	for _, ach in ipairs(getMergedAchievements()) do
		if ach.id == achId then
			return ach
		end
	end
	return nil
end

-- =====================================
-- DATASTORE: SALVAR / CARREGAR (mesmo padrão do CharacterCatalogServer_V5)
-- =====================================

local function saveIndex(index)
	pcall(function()
		achStore:SetAsync("Index", index)
	end)
end

local function loadIndex()
	local ok, result = pcall(function()
		return achStore:GetAsync("Index")
	end)
	if ok and type(result) == "table" then
		return result
	end
	return {}
end

local function saveDefinition(def)
	pcall(function()
		achStore:SetAsync("Ach_" .. def.id, def)
	end)
	local index = loadIndex()
	if not table.find(index, def.id) then
		table.insert(index, def.id)
		saveIndex(index)
	end
end

local function loadDefinition(achId)
	local ok, result = pcall(function()
		return achStore:GetAsync("Ach_" .. achId)
	end)
	if ok then
		return result
	end
	return nil
end

-- =====================================
-- HELPERS (mantidos do V1/V2)
-- =====================================

local function getStat(player, statName)
	local data = PDM.getPlayerData(player)
	if data and data.stats then
		return data.stats[statName] or 0
	end
	return 0
end

local function isClaimed(player, achId)
	local data = PDM.getPlayerData(player)
	if data and data.claimedAchievements then
		return data.claimedAchievements[achId] == true
	end
	return false
end

local function markClaimed(player, achId)
	local data = PDM.getPlayerData(player)
	if not data then
		return
	end
	-- Mesmo padrão de claimedMissions / tradeHistory (persiste no save)
	data.claimedAchievements = data.claimedAchievements or {}
	data.claimedAchievements[achId] = true
end

-- Prêmio só vale se o personagem existir de verdade:
-- no catálogo dinâmico OU na pasta ReplicatedStorage.Characters
local function rewardCharacterExists(name)
	if type(name) ~= "string" or name == "" then
		return false
	end
	if _G.CharacterCatalog and _G.CharacterCatalog.getDefinition(name) then
		return true
	end
	local cf = ReplicatedStorage:FindFirstChild("Characters")
	if cf and cf:FindFirstChild(name) then
		return true
	end
	return false
end

-- =====================================
-- DESBLOQUEAR CONQUISTA
-- =====================================

local function unlock(player, ach)
	markClaimed(player, ach.id)

	local gotCharacter = false
	local rewardMissing = false

	-- Valida o personagem-prêmio antes de conceder
	if ach.rewardCharacter and ach.rewardCharacter ~= "" then
		if rewardCharacterExists(ach.rewardCharacter) then
			if not PDM.ownsCharacter(player, ach.rewardCharacter) then
				-- REUTILIZADO: addCharacter source "Badge" (não vende/não troca)
				local ok = PDM.addCharacter(player, ach.rewardCharacter, "Badge", 0)
				gotCharacter = ok == true
			end
		else
			rewardMissing = true
			warn(
				string.format(
					"[ACHIEVEMENT V3] ⚠️ Conquista '%s' premia '%s', que NÃO existe no catálogo — prêmio ignorado. Corrija pelo painel admin.",
					ach.name,
					tostring(ach.rewardCharacter)
				)
			)
		end
	end

	-- Badge real do Roblox (opcional) — REUTILIZADO: BadgeService
	if ach.realBadgeId and ach.realBadgeId > 0 then
		task.spawn(function()
			pcall(function()
				if not BadgeService:UserHasBadgeAsync(player.UserId, ach.realBadgeId) then
					BadgeService:AwardBadgeAsync(player.UserId, ach.realBadgeId)
				end
			end)
		end)
	end

	PDM.savePlayerData(player)

	achievementUnlockedRemote:FireClient(player, {
		id = ach.id,
		name = ach.name,
		desc = ach.desc,
		icon = ach.icon,
		rewardCharacter = ach.rewardCharacter,
		gotCharacter = gotCharacter,
		rewardMissing = rewardMissing,
	})

	print(
		string.format(
			"[ACHIEVEMENT V3] %s desbloqueou '%s'%s",
			player.Name,
			ach.name,
			gotCharacter and (" → personagem '" .. ach.rewardCharacter .. "'") or ""
		)
	)
end

-- =====================================
-- VERIFICAÇÃO
-- =====================================

local function checkAchievements(player)
	if not PDM.getPlayerData(player) then
		return
	end
	for _, ach in ipairs(getMergedAchievements()) do
		if not isClaimed(player, ach.id) then
			if getStat(player, ach.stat) >= ach.amount then
				unlock(player, ach)
			end
		end
	end
end

-- Outros sistemas podem chamar isto logo após dar um stat (mantido)
_G.CheckAchievements = function(player)
	checkAchievements(player)
end

local function checkAllPlayers()
	for _, player in ipairs(Players:GetPlayers()) do
		checkAchievements(player)
	end
end

-- =====================================
-- REMOTE: lista com progresso (para o menu — todos os jogadores)
-- =====================================

getAchievementsRemote.OnServerInvoke = function(player)
	local result = {}
	for _, ach in ipairs(getMergedAchievements()) do
		table.insert(result, {
			id = ach.id,
			name = ach.name,
			desc = ach.desc,
			icon = ach.icon,
			amount = ach.amount,
			current = getStat(player, ach.stat),
			rewardCharacter = ach.rewardCharacter,
			claimed = isClaimed(player, ach.id),
		})
	end
	return result
end

-- =====================================
-- VALIDAÇÃO DO PAYLOAD ADMIN
-- =====================================

local function makeId(name)
	return name:lower():gsub("%s+", "_"):gsub("[^%w_]", "")
end

local function validatePayload(payload)
	if type(payload) ~= "table" then
		return false, "Dados inválidos!"
	end
	if type(payload.name) ~= "string" or #payload.name < 2 or #payload.name > 40 then
		return false, "Nome inválido (2-40 caracteres)!"
	end
	if makeId(payload.name) == "" then
		return false, "Nome precisa conter letras ou números!"
	end
	if type(payload.desc) ~= "string" or #payload.desc < 2 or #payload.desc > 120 then
		return false, "Descrição inválida (2-120 caracteres)!"
	end
	if not VALID_STATS[payload.stat] then
		return false, "Stat inválido!"
	end
	local amount = tonumber(payload.amount)
	if not amount or amount < 1 then
		return false, "Meta deve ser um número maior que 0!"
	end
	if payload.icon and #tostring(payload.icon) > 16 then
		return false, "Ícone muito longo (use 1 emoji)!"
	end
	if payload.rewardCharacter and #tostring(payload.rewardCharacter) > 24 then
		return false, "Nome do personagem-prêmio muito longo!"
	end
	return true, "OK"
end

-- =====================================
-- SINCRONIZAÇÃO ENTRE SERVIDORES
-- Guarda de JobId: o servidor de origem não processa a própria
-- mensagem (sem anúncio duplicado)
-- =====================================

local function broadcastAnnouncementLocally(text, isSuccess)
	for _, p in ipairs(Players:GetPlayers()) do
		catalogAnnouncement:FireClient(p, text, isSuccess)
	end
end

local function publishSync(action, achId, achName, adminName)
	pcall(function()
		MessagingService:PublishAsync(CONFIG.SYNC_TOPIC, {
			action = action,
			id = achId,
			name = achName,
			admin = adminName,
			jobId = game.JobId,
		})
	end)
end

local function applyRemoteChange(data)
	local def = loadDefinition(data.id)
	if def then
		dynamicDefs[data.id] = def
	end

	if data.action == "set" then
		broadcastAnnouncementLocally(
			string.format("🏆 %s adicionou/atualizou a conquista '%s'!", data.admin or "Um admin", data.name),
			true
		)
		task.spawn(checkAllPlayers) -- alguém pode já ter batido a meta
	elseif data.action == "remove" then
		broadcastAnnouncementLocally(
			string.format("🗑️ %s removeu a conquista '%s'!", data.admin or "Um admin", data.name),
			false
		)
	end
end

pcall(function()
	MessagingService:SubscribeAsync(CONFIG.SYNC_TOPIC, function(message)
		local data = message.Data
		if type(data) == "table" and data.jobId ~= game.JobId then
			applyRemoteChange(data)
		end
	end)
end)

-- =====================================
-- REMOTES ADMIN: CRIAR/EDITAR, REMOVER, LISTAR
-- =====================================

adminAchSet.OnServerInvoke = function(player, payload)
	if not isAdmin(player) then
		player:Kick("Tentativa não autorizada de uso de comandos admin")
		return false, "Sem permissão!"
	end

	local ok, msg = validatePayload(payload)
	if not ok then
		return false, msg
	end

	local def = {
		id = makeId(payload.name),
		name = payload.name,
		desc = payload.desc,
		icon = tostring(payload.icon or "🏆"),
		stat = payload.stat,
		amount = math.floor(tonumber(payload.amount)),
		rewardCharacter = tostring(payload.rewardCharacter or ""),
		realBadgeId = tonumber(payload.realBadgeId) or 0,
		addedBy = player.Name,
		addedAt = os.time(),
	}

	dynamicDefs[def.id] = def
	saveDefinition(def)

	publishSync("set", def.id, def.name, player.Name)
	broadcastAnnouncementLocally(
		string.format("🏆 %s adicionou/atualizou a conquista '%s'!", player.Name, def.name),
		true
	)
	task.spawn(checkAllPlayers)

	print(string.format("[ACHIEVEMENT V3] %s salvou a conquista '%s' (%s >= %d)", player.Name, def.name, def.stat, def.amount))

	-- Avisar se o prêmio configurado (opcional) não existe ainda
	if def.rewardCharacter ~= "" and not rewardCharacterExists(def.rewardCharacter) then
		return true, "Salva, mas ATENÇÃO: o personagem '" .. def.rewardCharacter .. "' não existe no catálogo!"
	end
	return true, "Conquista salva em todos os servidores!"
end

adminAchRemove.OnServerInvoke = function(player, achId)
	if not isAdmin(player) then
		player:Kick("Tentativa não autorizada de uso de comandos admin")
		return false, "Sem permissão!"
	end
	if type(achId) ~= "string" or achId == "" then
		return false, "ID inválido!"
	end

	local existing = findAchievementById(achId)
	if not existing then
		return false, "Conquista não encontrada!"
	end
	local achName = existing.name

	-- Tombstone: funciona tanto pra dinâmicas quanto pras padrão
	local tombstone = { id = achId, removed = true, addedAt = os.time() }
	dynamicDefs[achId] = tombstone
	saveDefinition(tombstone)

	publishSync("remove", achId, achName, player.Name)
	broadcastAnnouncementLocally(
		string.format("🗑️ %s removeu a conquista '%s'!", player.Name, achName),
		false
	)

	print(string.format("[ACHIEVEMENT V3] %s removeu a conquista '%s'", player.Name, achName))
	return true, "Conquista removida em todos os servidores!"
end

adminAchList.OnServerInvoke = function(player)
	if not isAdmin(player) then
		return {}
	end
	local list = {}
	for _, ach in ipairs(getMergedAchievements()) do
		table.insert(list, {
			id = ach.id,
			name = ach.name,
			desc = ach.desc,
			icon = ach.icon,
			stat = ach.stat,
			amount = ach.amount,
			rewardCharacter = ach.rewardCharacter,
			realBadgeId = ach.realBadgeId,
		})
	end
	return list
end

-- =====================================
-- GATILHOS (mantidos)
-- =====================================

local function onPlayerAdded(player)
	task.spawn(function()
		local t = 0
		while not PDM.getPlayerData(player) and t < 30 do
			task.wait(0.5)
			t += 0.5
		end
		task.wait(3) -- dar tempo dos outros sistemas subirem
		checkAchievements(player)
	end)
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, p in ipairs(Players:GetPlayers()) do
	onPlayerAdded(p)
end

-- Verificação periódica de todos (pega mudança de stat de qualquer sistema)
task.spawn(function()
	while true do
		task.wait(CONFIG.CHECK_INTERVAL)
		checkAllPlayers()
	end
end)

-- =====================================
-- BOOT: CARREGAR CONQUISTAS DINÂMICAS DO DATASTORE
-- =====================================

task.spawn(function()
	print("[ACHIEVEMENT V3] Carregando conquistas salvas...")
	local index = loadIndex()
	local loaded = 0
	for _, achId in ipairs(index) do
		local def = loadDefinition(achId)
		if def then
			dynamicDefs[achId] = def
			if not def.removed then
				loaded += 1
			end
		end
	end
	print(string.format("[ACHIEVEMENT V3] ✓ %d conquista(s) dinâmica(s) carregada(s)", loaded))
end)

-- =====================================
-- DEBUG
-- =====================================

_G.DebugAchievements = function()
	print("\n========== DEBUG ACHIEVEMENTS V3 ==========")
	for _, ach in ipairs(getMergedAchievements()) do
		print(
			string.format(
				"  %s %s | %s >= %d | prêmio: %s%s",
				ach.icon,
				ach.name,
				ach.stat,
				ach.amount,
				ach.rewardCharacter ~= "" and ach.rewardCharacter or "(nenhum)",
				(ach.rewardCharacter ~= "" and not rewardCharacterExists(ach.rewardCharacter)) and " ⚠️NÃO EXISTE" or ""
			)
		)
	end
	print("============================================\n")
end

print([[
╔════════════════════════════════════════════════════╗
║  🏆 ACHIEVEMENT SYSTEM SERVER V3 — DINÂMICO       ║
╠════════════════════════════════════════════════════╣
║  SUBSTITUI: AchievementSystemServer V2             ║
║  REMOVER:   AchievementSystemServer V2             ║
║  DEPENDE DE: AdminRegistryServer_V1                ║
╠════════════════════════════════════════════════════╣
║  (V3) ADMIN_IDS removida → _G.AdminRegistry        ║
║  * Conquistas criadas/removidas pelo painel admin  ║
║    (sem Studio) — DataStore + sync entre servidores║
║  * Prêmio validado contra o catálogo               ║
║  * API: _G.CheckAchievements(player)               ║
║  * DEBUG: _G.DebugAchievements()                   ║
╚════════════════════════════════════════════════════╝
]])
