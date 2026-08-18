-- ============================================
-- DATA MANAGER SERVER V9 — O SAVE PARA DE APAGAR O EQUIPADO
-- Coloque em ServerScriptService
-- Nome: "DataManager"
-- SUBSTITUI: DataManager V8
-- ============================================
-- (V9) O BUG MAIS CARO DO PROJETO, CORRIGIDO NA ORIGEM.
--
-- O savePlayerData fazia `data.equippedCharacter = nil` no CACHE VIVO
-- antes de gravar. A intenção é certa — equipar não deve persistir entre
-- sessões — mas apagar do cache vivo, e não da cópia serializada, fazia
-- com que TODO script que lê esse campo visse `nil` a cada autosave, ou
-- seja, de 30 em 30 segundos, com o jogador tendo personagem equipado.
--
-- São 16 leitores no projeto, e o estrago aparecia longe daqui:
--   • BossRaidServer dizia "equipe um personagem" para quem já tinha;
--   • o mesmo BossRaidServer salvava e LOGO DEPOIS lia o campo para
--     montar o TeleportData do chefão — a lista de personagens do raid
--     saía SEMPRE vazia, que era justamente a razão de existir o V3 dele;
--   • a barra de Despertar sumia da tela sozinha;
--   • o capítulo 1 da Jornada do Recruta zerava sozinho.
--
-- Cada um desses foi remendado no seu próprio arquivo ao longo do tempo.
-- Agora a limpeza acontece numa CÓPIA RASA feita só para a serialização,
-- o cache vivo não é tocado, e os 16 leitores passam a ver a verdade.
--
-- O `playtime` seguiu o mesmo caminho: sai da cópia, fica no cache.
-- ============================================
-- (V8) DUAS CONSTANTES, MAS SEM ELAS NADA DO RESTO FUNCIONA:
--
-- • MAX_PASSIVE_RANK: 3 -> 10
--   As passivas passaram de 3 ranks para 10 níveis. Com o limite
--   antigo, qualquer nível acima de 3 era CORTADO no salvamento —
--   o jogador pagaria 20 mil moedas pelo nível 10 e o save
--   guardaria 3, em silêncio.
--
-- • MAX_PASSIVE_SLOTS: 3 -> 6
--   3 slots vêm do nível do personagem; o gamepass libera mais 3.
--   Com o teto antigo, os slots do gamepass seriam descartados na
--   hora de salvar.
--
-- ⚠️ Estes são limites de ARMAZENAMENTO (anti-exploit). Quem decide
--    quantos slots o jogador REALMENTE tem continua sendo o
--    CharacterLevelServer + gamepass, e quem valida é o
--    PassiveSystemServer. Aqui só deixamos de cortar o que é legítimo.
--
-- ⚠️ MIGRAÇÃO: saves antigos continuam válidos. Passiva salva no
--    rank 3 permanece no nível 3 — não vira 10 sozinha.
-- ============================================
-- (V7) ALTERAÇÕES:
-- • 🆕 PROGRESSÃO POR PERSONAGEM: cada objeto de ownedCharacters
--   agora carrega 4 campos novos:
--     level    = 1   -> nível daquele personagem
--     xp       = 0   -> XP acumulado no nível atual
--     passives = {}  -> slots ativos { {id="couraca", rank=1}, ... }
--     loadouts = {}  -> builds salvas { {name="PvP", passives={...}} }
--   Nível é POR PERSONAGEM (decisão fechada) — por isso mora dentro
--   do charObj, e não em stats.
-- • ⚠️ MIGRAÇÃO AUTOMÁTICA E SEGURA: save antigo (sem esses campos)
--   entra como level=1 / xp=0 / listas vazias. NENHUM save quebra,
--   NENHUM personagem é perdido. Quem já jogou continua com tudo.
-- • 🆕 API DE PROGRESSÃO (seção "PROGRESSÃO" no _G.PlayerDataManager):
--     getCharacterProgress / setCharacterProgress
--     addCharacterXp / setCharacterLevel
--     getCharacterPassives / setCharacterPassives
--     getLoadouts / saveLoadout / applyLoadout
--     getEquippedCharacterObj
--   O DataManager só ARMAZENA. Quem sabe a curva de XP, quantos
--   slots cada nível dá e o que cada passiva faz é o
--   CharacterLevelServer_V1 / PassiveSystemServer_V1 (mesma divisão
--   que já existe com o MissionSystemServer: ele tem as missões, o
--   DataManager só guarda claimedMissions).
-- • Sanitização: passivas e loadouts são validados na entrada e no
--   carregamento (máx. 3 slots, máx. 3 loadouts, rank 1-3) — save
--   corrompido ou exploit não passa.
-- • getClientSafeData NÃO mudou de forma: ownedCharactersDetailed
--   já era enviado, então nível/XP/passivas chegam no cliente SEM
--   remote novo.
-- • ⚠️ DATASTORE_NAME e DATA_VERSION INTACTOS — saves continuam
--   válidos, inclusive na place do Chefão (mesmo DataStore).
-- ============================================
-- (V6) ALTERAÇÕES:
-- • 🧹 ZERO PERSONAGENS NO CÓDIGO:
--   - getDefaultData: jogador novo começa com inventário VAZIO
--     (o "Noob" automático foi removido — quem concede o primeiro
--     personagem é o CharacterCatalogServer_V4 via categoria GRÁTIS)
--   - validateData: removido o bloco que FORÇAVA o "Noob" em todo
--     save carregado
--   - MIGRATION_CONFIG: todas as tabelas ("Noob", "Guest",
--     "Danilo", "Gui Bomba", "Dark Jc", "Shushuhus8", gamepasses
--     "Faker Gui"/"Alma Perdida") foram ESVAZIADAS — a estrutura
--     fica só pra migração de saves V3 antigos (que agora migram
--     como Shop/preço 0 e serão limpos pelo prune do catálogo V4)
--   - removeCharacterByName: removida a trava que impedia remover
--     o "Noob" — NECESSÁRIO pro fluxo de remoção do
--     CharacterCatalogServer_V4 (admin remove → sai do inventário
--     de todos, seja qual for o nome)
-- • ⚠️ DATASTORE_NAME e DATA_VERSION INTACTOS (iguais ao V4/V5) —
--   os saves dos jogadores continuam válidos.
-- • Todo o resto (migração V3→V4, venda, troca, despertar, API)
--   segue idêntico ao V5, incluindo o addCharacterToInventory
--   ciente do catálogo dinâmico.
-- ============================================

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

-- DataStore (MESMO nome para manter dados existentes)
local DATASTORE_NAME = "RetroVerseDataV3_Awakening"
local DATA_VERSION = "V4_Metadata"
local playerDataStore = DataStoreService:GetDataStore(DATASTORE_NAME)

-- Cache
local playerDataCache = {}
local isSaving = {}

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
-- CONFIGURAÇÃO DE SOURCES
-- =====================================

local SOURCE_PERMISSIONS = {
	Mandatory = { tradeable = false, sellable = false },
	Shop = { tradeable = true, sellable = true },
	Reward = { tradeable = true, sellable = false },
	Gamepass = { tradeable = false, sellable = false },
	Badge = { tradeable = false, sellable = false },
	Trade = { tradeable = true, sellable = true },
	Awakened = { tradeable = false, sellable = false },
}

-- (V6) ZERADO — estrutura mantida só pra migração de saves V3.
-- NÃO adicione personagens aqui! O catálogo dinâmico
-- (CharacterCatalogServer_V4) é a única fonte de personagens.
local MIGRATION_CONFIG = {
	mandatoryCharacters = {},
	characterPrices = {},
	bountyCharacters = {},
	gamepassCharacters = {},
	badgeCharacters = {},
}

-- =====================================
-- (V7) LIMITES DE PROGRESSÃO
-- Só limites de ARMAZENAMENTO (anti-exploit / anti-save corrompido).
-- O balanceamento real (curva de XP, quantos slots por nível, o que
-- cada passiva faz) é do CharacterLevelServer_V1.
-- =====================================

local PROGRESSION_LIMITS = {
	MAX_LEVEL = 100, -- teto duro de storage; o teto de jogo (30) é do CharacterLevelServer
	-- (V8) 3 do nível do personagem + 3 do gamepass
	MAX_PASSIVE_SLOTS = 6,
	-- (V8) passivas agora vão até o nível 10
	MAX_PASSIVE_RANK = 10,
	MAX_LOADOUTS = 3, -- builds salvas por personagem
	MAX_LOADOUT_NAME = 16,
}

-- =====================================
-- ESTRUTURA PADRÃO
-- =====================================

local function createDefaultCharacter(name, source, price)
	local perms = SOURCE_PERMISSIONS[source] or { tradeable = false, sellable = false }
	return {
		id = HttpService:GenerateGUID(false),
		name = name,
		source = source,
		acquiredAt = os.time(),
		originalPrice = price or 0,
		tradeable = perms.tradeable,
		sellable = perms.sellable,

		-- (V7) PROGRESSÃO — nível é por personagem
		level = 1,
		xp = 0,
		passives = {}, -- { {id = "couraca", rank = 1}, ... }
		loadouts = {}, -- { {name = "PvP", passives = { ... }}, ... }
	}
end

local function getDefaultData()
	return {
		coins = 0,
		-- (V6) Inventário começa VAZIO — sem "Noob" automático.
		-- O primeiro personagem vem do catálogo (categoria GRÁTIS).
		ownedCharacters = {},
		equippedCharacter = nil,
		awakenedCharacters = {},
		stats = {
			bounty = 0,
			deaths = 0,
			kills = 0,
			kills_total = 0,
			coins_earned_total = 0,
			trades_completed = 0,
			characters_bought = 0,
			characters_sold = 0,
		},
		tradeHistory = {},
		claimedMissions = {},
		version = DATA_VERSION,
	}
end

-- =====================================
-- FUNÇÕES UTILITÁRIAS
-- =====================================

local function deepCopy(original)
	if type(original) ~= "table" then
		return original
	end
	local copy = {}
	for key, value in pairs(original) do
		copy[key] = deepCopy(value)
	end
	return copy
end

local function isOldFormat(ownedCharacters)
	if not ownedCharacters or #ownedCharacters == 0 then
		return true
	end
	return type(ownedCharacters[1]) == "string"
end

-- =====================================
-- (V7) SANITIZAÇÃO DE PROGRESSÃO
-- Roda no carregamento E na escrita — save corrompido, save de
-- versão antiga e payload de exploit caem todos aqui.
-- =====================================

local function sanitizePassives(rawPassives)
	local clean = {}
	if type(rawPassives) ~= "table" then
		return clean
	end

	local seen = {}
	for _, entry in ipairs(rawPassives) do
		if #clean >= PROGRESSION_LIMITS.MAX_PASSIVE_SLOTS then
			break
		end
		if type(entry) == "table" and type(entry.id) == "string" and #entry.id > 0 and #entry.id <= 32 then
			-- Sem passiva repetida em dois slots
			if not seen[entry.id] then
				seen[entry.id] = true
				table.insert(clean, {
					id = entry.id,
					rank = math.clamp(tonumber(entry.rank) or 1, 1, PROGRESSION_LIMITS.MAX_PASSIVE_RANK),
				})
			end
		end
	end

	return clean
end

local function sanitizeLoadouts(rawLoadouts)
	local clean = {}
	if type(rawLoadouts) ~= "table" then
		return clean
	end

	for _, entry in ipairs(rawLoadouts) do
		if #clean >= PROGRESSION_LIMITS.MAX_LOADOUTS then
			break
		end
		if type(entry) == "table" and type(entry.name) == "string" then
			local name = entry.name:sub(1, PROGRESSION_LIMITS.MAX_LOADOUT_NAME)
			if #name > 0 then
				table.insert(clean, {
					name = name,
					passives = sanitizePassives(entry.passives),
				})
			end
		end
	end

	return clean
end

-- Garante que um charObj tem os campos de progressão (migração
-- silenciosa de save V6 → V7, sem perder nada)
local function ensureProgressionFields(charObj)
	charObj.level = math.clamp(tonumber(charObj.level) or 1, 1, PROGRESSION_LIMITS.MAX_LEVEL)
	charObj.xp = math.max(0, math.floor(tonumber(charObj.xp) or 0))
	charObj.passives = sanitizePassives(charObj.passives)
	charObj.loadouts = sanitizeLoadouts(charObj.loadouts)
	return charObj
end

-- =====================================
-- MIGRAÇÃO V3 → V4
-- =====================================

local function migrateCharacterList(oldList)
	local newList = {}
	local cfg = MIGRATION_CONFIG

	for _, name in ipairs(oldList) do
		if type(name) ~= "string" then
			continue
		end

		local source = "Shop"
		local price = 0

		if table.find(cfg.mandatoryCharacters, name) then
			source = "Mandatory"
			price = 0
		elseif cfg.bountyCharacters[name] then
			source = "Reward"
			price = 0
		elseif cfg.gamepassCharacters[name] then
			source = "Gamepass"
			price = 0
		elseif cfg.badgeCharacters[name] then
			source = "Badge"
			price = 0
		else
			price = cfg.characterPrices[name] or 0
		end

		table.insert(newList, createDefaultCharacter(name, source, price))
	end

	return newList
end

-- =====================================
-- VALIDAÇÃO DE DADOS
-- =====================================

local function validateData(data)
	if not data then
		return getDefaultData()
	end

	local validated = getDefaultData()

	-- Migrar coins
	validated.coins = type(data.coins) == "number" and math.max(0, data.coins) or 0

	-- Migrar ownedCharacters (V3 strings → V4 objetos)
	if data.ownedCharacters then
		if isOldFormat(data.ownedCharacters) then
			print("[DATA V9] Migrando ownedCharacters de V3 (strings) para V4 (objetos)...")
			validated.ownedCharacters = migrateCharacterList(data.ownedCharacters)
			print("[DATA V9] Migração concluída: " .. #validated.ownedCharacters .. " personagens")
		else
			validated.ownedCharacters = {}
			for _, charObj in ipairs(data.ownedCharacters) do
				if type(charObj) == "table" and type(charObj.name) == "string" then
					local perms = SOURCE_PERMISSIONS[charObj.source]
						or { tradeable = false, sellable = false }
					-- (V7) ensureProgressionFields: save V6 (sem level/xp)
					-- entra como level 1 / xp 0 / listas vazias.
					table.insert(
						validated.ownedCharacters,
						ensureProgressionFields({
							id = charObj.id or HttpService:GenerateGUID(false),
							name = charObj.name,
							source = charObj.source or "Shop",
							acquiredAt = charObj.acquiredAt or os.time(),
							originalPrice = charObj.originalPrice or 0,
							tradeable = perms.tradeable,
							sellable = perms.sellable,
							level = charObj.level,
							xp = charObj.xp,
							passives = charObj.passives,
							loadouts = charObj.loadouts,
						})
					)
				end
			end
		end
	end

	-- (V6) REMOVIDO: bloco que forçava o "Noob" em todo save.
	-- Personagens vêm exclusivamente do catálogo dinâmico.

	-- Migrar equippedCharacter
	validated.equippedCharacter = data.equippedCharacter

	-- Migrar awakenedCharacters
	if type(data.awakenedCharacters) == "table" then
		validated.awakenedCharacters = deepCopy(data.awakenedCharacters)
	end

	-- Migrar stats (merge com defaults)
	if type(data.stats) == "table" then
		for key, value in pairs(data.stats) do
			if key ~= "playtime" and type(value) == "number" then
				validated.stats[key] = value
			end
		end
		if not data.stats.kills_total and data.stats.kills then
			validated.stats.kills_total = data.stats.kills
		end
	end

	-- Migrar tradeHistory
	if type(data.tradeHistory) == "table" then
		validated.tradeHistory = data.tradeHistory
	end

	-- Preservar missões já resgatadas
	if type(data.claimedMissions) == "table" then
		validated.claimedMissions = data.claimedMissions
	end

	-- Preservar conquistas já resgatadas (AchievementSystemServer_V2)
	if type(data.claimedAchievements) == "table" then
		validated.claimedAchievements = data.claimedAchievements
	end

	validated.version = DATA_VERSION

	return validated
end

-- =====================================
-- SYNC COM CLIENT (RETROCOMPATÍVEL)
-- =====================================

local function getClientSafeData(data)
	if not data then
		return nil
	end

	local simpleNames = {}
	for _, charObj in ipairs(data.ownedCharacters) do
		table.insert(simpleNames, charObj.name)
	end

	return {
		coins = data.coins,
		ownedCharacters = simpleNames,
		ownedCharactersDetailed = data.ownedCharacters,
		equippedCharacter = data.equippedCharacter,
		awakenedCharacters = data.awakenedCharacters,
		stats = data.stats,
		tradeHistory = data.tradeHistory,
		claimedMissions = data.claimedMissions or {},
		version = data.version,
	}
end

local function syncDataWithClient(player)
	local data = playerDataCache[player]
	if data then
		updateStatsRemote:FireClient(player, getClientSafeData(data))
	end
end

-- =====================================
-- CARREGAR DADOS
-- =====================================

local function loadPlayerData(player)
	local userId = tostring(player.UserId)
	local attempts = 0
	local maxAttempts = 3

	while attempts < maxAttempts do
		attempts = attempts + 1

		local success, result = pcall(function()
			return playerDataStore:GetAsync(userId)
		end)

		if success then
			local data = validateData(result)
			playerDataCache[player] = data

			if result and isOldFormat(result.ownedCharacters) then
				print("[DATA V9] Salvando dados migrados de " .. player.Name)
				task.spawn(function()
					local ok, err = pcall(function()
						playerDataStore:SetAsync(userId, data)
					end)
					if ok then
						print("[DATA V9] Dados migrados salvos: " .. player.Name)
					else
						warn("[DATA V9] Erro ao salvar migração: " .. tostring(err))
					end
				end)
			end

			print(
				"[DATA V9] Dados carregados: "
					.. player.Name
					.. " ("
					.. #data.ownedCharacters
					.. " personagens)"
			)
			return data
		else
			warn(
				"[DATA V9] Erro ao carregar dados de "
					.. player.Name
					.. " (tentativa "
					.. attempts
					.. "): "
					.. tostring(result)
			)
			if attempts < maxAttempts then
				task.wait(2)
			end
		end
	end

	playerDataCache[player] = getDefaultData()
	warn("[DATA V9] Usando dados padrão para " .. player.Name)
	return playerDataCache[player]
end

-- =====================================
-- SALVAR DADOS
-- =====================================

local function savePlayerData(player, isLeaving)
	if isSaving[player] then
		if not isLeaving then
			return
		end
		local timeout = 0
		while isSaving[player] and timeout < 5 do
			task.wait(0.1)
			timeout = timeout + 0.1
		end
	end

	isSaving[player] = true

	local userId = tostring(player.UserId)
	local data = playerDataCache[player]

	if not data then
		isSaving[player] = false
		return false
	end

	-- (V9) ⚠️ O BUG MAIS CARO DESTE ARQUIVO, CORRIGIDO.
	--
	-- Estas duas linhas apagavam `equippedCharacter` e `playtime` do
	-- CACHE VIVO, não da cópia que vai para o DataStore. A intenção é
	-- certa (equipar não deve persistir entre sessões), mas o efeito
	-- colateral era enorme: como o autosave roda a cada 30 segundos, TODO
	-- script que lê data.equippedCharacter via `nil` de meio em meio
	-- minuto, com o jogador tendo um personagem equipado na tela.
	--
	-- São 16 leitores no projeto, e o estrago aparecia longe daqui:
	--   • BossRaidServer dizia "equipe um personagem" para quem já tinha;
	--   • o mesmo BossRaidServer salvava e LOGO DEPOIS lia o campo para
	--     montar o TeleportData — ou seja, a lista de personagens do raid
	--     saía sempre vazia, e era justamente o motivo de existir o V3;
	--   • a barra de Despertar sumia da tela sozinha;
	--   • o capítulo 1 da Jornada do Recruta zerava sozinho.
	--
	-- Agora a limpeza acontece numa CÓPIA RASA, só para a serialização. O
	-- cache vivo não é tocado, e os 16 leitores passam a ver a verdade.
	local paraSalvar = {}
	for chave, valor in pairs(data) do
		paraSalvar[chave] = valor
	end

	paraSalvar.equippedCharacter = nil

	if data.stats then
		local statsCopia = {}
		for chave, valor in pairs(data.stats) do
			statsCopia[chave] = valor
		end
		statsCopia.playtime = nil
		paraSalvar.stats = statsCopia
	end

	local attempts = 0
	local maxAttempts = isLeaving and 5 or 3

	while attempts < maxAttempts do
		attempts = attempts + 1

		local success, err = pcall(function()
			playerDataStore:SetAsync(userId, paraSalvar)
		end)

		if success then
			print("[DATA V9] Dados salvos: " .. player.Name)
			isSaving[player] = false
			return true
		else
			warn(
				"[DATA V9] Erro ao salvar "
					.. player.Name
					.. " (tentativa "
					.. attempts
					.. "): "
					.. tostring(err)
			)
			if attempts < maxAttempts then
				task.wait(1)
			end
		end
	end

	isSaving[player] = false
	return false
end

-- =====================================
-- FUNÇÕES DE BUSCA DE PERSONAGENS
-- =====================================

local function findCharacterByName(playerData, characterName)
	if not playerData or not playerData.ownedCharacters then
		return nil, nil
	end
	for i, charObj in ipairs(playerData.ownedCharacters) do
		if charObj.name == characterName then
			return charObj, i
		end
	end
	return nil, nil
end

local function findCharacterById(playerData, charId)
	if not playerData or not playerData.ownedCharacters then
		return nil, nil
	end
	for i, charObj in ipairs(playerData.ownedCharacters) do
		if charObj.id == charId then
			return charObj, i
		end
	end
	return nil, nil
end

local function playerOwnsCharacterByName(playerData, characterName)
	local charObj = findCharacterByName(playerData, characterName)
	return charObj ~= nil
end

local function getTradeableCharacters(playerData)
	local result = {}
	if not playerData or not playerData.ownedCharacters then
		return result
	end
	for _, charObj in ipairs(playerData.ownedCharacters) do
		if charObj.tradeable then
			table.insert(result, charObj)
		end
	end
	return result
end

local function getSellableCharacters(playerData)
	local result = {}
	if not playerData or not playerData.ownedCharacters then
		return result
	end
	for _, charObj in ipairs(playerData.ownedCharacters) do
		if charObj.sellable and charObj.originalPrice > 0 then
			table.insert(result, charObj)
		end
	end
	return result
end

-- =====================================
-- EVENTOS DE JOGADOR
-- =====================================

local function onPlayerAdded(player)
	local playerData = loadPlayerData(player)

	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	leaderstats.Parent = player

	local coins = Instance.new("IntValue")
	coins.Name = "Coins"
	coins.Value = playerData.coins
	coins.Parent = leaderstats

	local bounty = Instance.new("IntValue")
	bounty.Name = "Bounty"
	bounty.Value = playerData.stats.bounty or 0
	bounty.Parent = leaderstats

	local deaths = Instance.new("IntValue")
	deaths.Name = "Deaths"
	deaths.Value = playerData.stats.deaths or 0
	deaths.Parent = leaderstats

	task.wait(1)
	syncDataWithClient(player)
end

local function onPlayerRemoving(player)
	savePlayerData(player, true)
	playerDataCache[player] = nil
	isSaving[player] = nil
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)

-- =====================================
-- AUTO-SAVE
-- =====================================

task.spawn(function()
	while true do
		task.wait(30)
		local players = Players:GetPlayers()
		for _, player in ipairs(players) do
			task.spawn(function()
				savePlayerData(player, false)
			end)
		end
		if #players > 0 then
			print("[DATA V9] Auto-save: " .. #players .. " jogadores")
		end
	end
end)

-- =====================================
-- BIND TO CLOSE
-- =====================================

game:BindToClose(function()
	print("[DATA V9] Servidor fechando, salvando todos os dados...")
	local players = Players:GetPlayers()

	for _, player in ipairs(players) do
		task.spawn(function()
			savePlayerData(player, true)
		end)
	end

	local timeout = 0
	while timeout < 30 do
		local allDone = true
		for _, player in ipairs(players) do
			if isSaving[player] then
				allDone = false
				break
			end
		end
		if allDone then
			break
		end
		task.wait(0.1)
		timeout = timeout + 0.1
	end

	print("[DATA V9] Shutdown save completo")
end)

-- =====================================
-- API PÚBLICA
-- =====================================

_G.PlayerDataManager = {
	getPlayerData = function(player)
		return playerDataCache[player]
	end,

	getClientData = function(player)
		return getClientSafeData(playerDataCache[player])
	end,

	savePlayerData = function(player)
		task.spawn(function()
			savePlayerData(player, false)
			syncDataWithClient(player)
		end)
	end,

	syncWithClient = function(player)
		syncDataWithClient(player)
	end,

	-- ========== MOEDAS ==========

	updateCoins = function(player, amount)
		local data = playerDataCache[player]
		if not data then
			return
		end

		data.coins = math.max(0, data.coins + amount)

		if amount > 0 then
			data.stats.coins_earned_total = (data.stats.coins_earned_total or 0) + amount
		end

		local leaderstats = player:FindFirstChild("leaderstats")
		if leaderstats then
			local c = leaderstats:FindFirstChild("Coins")
			if c then
				c.Value = data.coins
			end
		end

		syncDataWithClient(player)
	end,

	-- ========== BOUNTY ==========

	updateBounty = function(player, amount)
		local data = playerDataCache[player]
		if not data then
			return
		end

		data.stats.bounty = math.max(0, (data.stats.bounty or 0) + amount)

		local leaderstats = player:FindFirstChild("leaderstats")
		if leaderstats then
			local b = leaderstats:FindFirstChild("Bounty")
			if b then
				b.Value = data.stats.bounty
			end
		end

		syncDataWithClient(player)
	end,

	-- ========== STATS ==========

	incrementStat = function(player, statName, amount)
		local data = playerDataCache[player]
		if not data or not data.stats then
			return
		end
		if statName == "playtime" then
			return
		end

		data.stats[statName] = (data.stats[statName] or 0) + amount

		if statName == "kills" then
			data.stats.kills_total = (data.stats.kills_total or 0) + amount
		end

		local leaderstats = player:FindFirstChild("leaderstats")
		if leaderstats then
			local capitalized = statName:gsub("^%l", string.upper)
			local stat = leaderstats:FindFirstChild(capitalized)
			if stat then
				stat.Value = data.stats[statName]
			end
		end

		syncDataWithClient(player)
	end,

	-- ========== PERSONAGENS ==========

	addCharacter = function(player, characterName, source, originalPrice)
		local data = playerDataCache[player]
		if not data then
			return false
		end

		if playerOwnsCharacterByName(data, characterName) then
			return false
		end

		local charObj = createDefaultCharacter(characterName, source or "Shop", originalPrice or 0)
		table.insert(data.ownedCharacters, charObj)

		if source == "Shop" then
			data.stats.characters_bought = (data.stats.characters_bought or 0) + 1
		end

		syncDataWithClient(player)
		return true, charObj.id
	end,

	-- Retrocompatível: consulta o catálogo dinâmico
	-- (CharacterCatalogServer_V4) antes do MIGRATION_CONFIG (vazio)
	addCharacterToInventory = function(player, characterName)
		local data = playerDataCache[player]
		if not data then
			return false
		end

		if playerOwnsCharacterByName(data, characterName) then
			return false
		end

		local cfg = MIGRATION_CONFIG
		local catalog = _G.GameContentConfig

		local isCatalogMandatory = catalog
			and catalog.mandatoryCharacters
			and table.find(catalog.mandatoryCharacters, characterName)
		local catalogBounty = catalog and catalog.bountyCharacters and catalog.bountyCharacters[characterName]
		local catalogGamepass = catalog and catalog.gamepassCharacters and catalog.gamepassCharacters[characterName]
		local catalogBadge = catalog and catalog.badgeCharacters and catalog.badgeCharacters[characterName]
		local catalogPrice = catalog and catalog.characterPrices and catalog.characterPrices[characterName]

		local source = "Shop"
		local price = 0

		if isCatalogMandatory or table.find(cfg.mandatoryCharacters, characterName) then
			source = "Mandatory"
		elseif catalogBounty ~= nil or cfg.bountyCharacters[characterName] then
			source = "Reward"
		elseif catalogGamepass ~= nil or cfg.gamepassCharacters[characterName] then
			source = "Gamepass"
		elseif catalogBadge ~= nil or cfg.badgeCharacters[characterName] then
			source = "Badge"
		else
			price = catalogPrice or cfg.characterPrices[characterName] or 0
			source = "Shop"
		end

		local charObj = createDefaultCharacter(characterName, source, price)
		table.insert(data.ownedCharacters, charObj)
		syncDataWithClient(player)
		return true
	end,

	removeCharacterById = function(player, charId)
		local data = playerDataCache[player]
		if not data then
			return false
		end

		local charObj, index = findCharacterById(data, charId)
		if not charObj then
			return false
		end

		table.remove(data.ownedCharacters, index)
		syncDataWithClient(player)
		return true, charObj
	end,

	-- (V6) Sem trava de nome — o CharacterCatalogServer_V4 usa isto
	-- pra limpar QUALQUER personagem removido do catálogo
	removeCharacterByName = function(player, characterName)
		local data = playerDataCache[player]
		if not data then
			return false
		end

		local charObj, index = findCharacterByName(data, characterName)
		if not charObj then
			return false
		end

		table.remove(data.ownedCharacters, index)
		syncDataWithClient(player)
		return true, charObj
	end,

	-- ========== CONSULTAS ==========

	ownsCharacter = function(player, characterName)
		local data = playerDataCache[player]
		if not data then
			return false
		end
		return playerOwnsCharacterByName(data, characterName)
	end,

	getCharacterByName = function(player, characterName)
		local data = playerDataCache[player]
		if not data then
			return nil
		end
		return findCharacterByName(data, characterName)
	end,

	getCharacterById = function(player, charId)
		local data = playerDataCache[player]
		if not data then
			return nil
		end
		return findCharacterById(data, charId)
	end,

	getTradeableCharacters = function(player)
		local data = playerDataCache[player]
		if not data then
			return {}
		end
		return getTradeableCharacters(data)
	end,

	getSellableCharacters = function(player)
		local data = playerDataCache[player]
		if not data then
			return {}
		end
		return getSellableCharacters(data)
	end,

	-- ========== DESPERTAR ==========

	addAwakenedCharacter = function(player, originalName)
		local data = playerDataCache[player]
		if not data then
			return false
		end
		if not data.awakenedCharacters then
			data.awakenedCharacters = {}
		end
		if table.find(data.awakenedCharacters, originalName) then
			return false
		end
		table.insert(data.awakenedCharacters, originalName)
		syncDataWithClient(player)
		return true
	end,

	hasAwakening = function(player, originalName)
		local data = playerDataCache[player]
		if data and data.awakenedCharacters then
			return table.find(data.awakenedCharacters, originalName) ~= nil
		end
		return false
	end,

	-- ========== TROCAS ==========

	addTradeToHistory = function(player, tradeId)
		local data = playerDataCache[player]
		if not data then
			return
		end
		if not data.tradeHistory then
			data.tradeHistory = {}
		end
		table.insert(data.tradeHistory, 1, tradeId)
		while #data.tradeHistory > 50 do
			table.remove(data.tradeHistory)
		end
		data.stats.trades_completed = (data.stats.trades_completed or 0) + 1
	end,

	-- ========== (V7) PROGRESSÃO ==========
	-- O DataManager só ARMAZENA. A curva de XP, o teto de nível e o
	-- efeito de cada passiva são do CharacterLevelServer_V1 /
	-- PassiveSystemServer_V1.

	getEquippedCharacterObj = function(player)
		local data = playerDataCache[player]
		if not data or not data.equippedCharacter then
			return nil
		end
		return findCharacterByName(data, data.equippedCharacter)
	end,

	getCharacterProgress = function(player, characterName)
		local data = playerDataCache[player]
		if not data then
			return nil
		end

		local charObj = findCharacterByName(data, characterName)
		if not charObj then
			return nil
		end

		ensureProgressionFields(charObj)
		return {
			name = charObj.name,
			level = charObj.level,
			xp = charObj.xp,
			passives = deepCopy(charObj.passives),
			loadouts = deepCopy(charObj.loadouts),
		}
	end,

	-- Soma XP BRUTO. Não sobe de nível sozinho de propósito — quem
	-- decide isso é o CharacterLevelServer (que conhece a curva).
	addCharacterXp = function(player, characterName, amount)
		local data = playerDataCache[player]
		if not data then
			return false
		end

		amount = math.floor(tonumber(amount) or 0)
		if amount <= 0 then
			return false
		end

		local charObj = findCharacterByName(data, characterName)
		if not charObj then
			return false
		end

		ensureProgressionFields(charObj)

		if charObj.level >= PROGRESSION_LIMITS.MAX_LEVEL then
			return false, charObj.xp
		end

		charObj.xp = charObj.xp + amount
		syncDataWithClient(player)
		return true, charObj.xp
	end,

	-- Chamado pelo CharacterLevelServer quando a curva confirma o
	-- level up. carryOverXp = XP que sobrou pro próximo nível.
	setCharacterLevel = function(player, characterName, level, carryOverXp)
		local data = playerDataCache[player]
		if not data then
			return false
		end

		local charObj = findCharacterByName(data, characterName)
		if not charObj then
			return false
		end

		ensureProgressionFields(charObj)
		charObj.level = math.clamp(math.floor(tonumber(level) or 1), 1, PROGRESSION_LIMITS.MAX_LEVEL)
		charObj.xp = math.max(0, math.floor(tonumber(carryOverXp) or 0))

		syncDataWithClient(player)
		return true, charObj.level
	end,

	getCharacterPassives = function(player, characterName)
		local data = playerDataCache[player]
		if not data then
			return {}
		end

		local charObj = findCharacterByName(data, characterName)
		if not charObj then
			return {}
		end

		ensureProgressionFields(charObj)
		return deepCopy(charObj.passives)
	end,

	-- maxSlots vem do CharacterLevelServer (depende do nível). Se não
	-- vier, usa o teto de storage.
	setCharacterPassives = function(player, characterName, passives, maxSlots)
		local data = playerDataCache[player]
		if not data then
			return false, "Dados não carregados."
		end

		local charObj = findCharacterByName(data, characterName)
		if not charObj then
			return false, "Você não possui este personagem."
		end

		local clean = sanitizePassives(passives)
		local limit = math.clamp(
			math.floor(tonumber(maxSlots) or PROGRESSION_LIMITS.MAX_PASSIVE_SLOTS),
			0,
			PROGRESSION_LIMITS.MAX_PASSIVE_SLOTS
		)

		if #clean > limit then
			return false, "Slots de passiva insuficientes para este nível."
		end

		charObj.passives = clean
		syncDataWithClient(player)
		return true, deepCopy(charObj.passives)
	end,

	-- ========== (V7) LOADOUTS (BUILDS SALVAS) ==========

	getLoadouts = function(player, characterName)
		local data = playerDataCache[player]
		if not data then
			return {}
		end

		local charObj = findCharacterByName(data, characterName)
		if not charObj then
			return {}
		end

		ensureProgressionFields(charObj)
		return deepCopy(charObj.loadouts)
	end,

	-- Salva a build ATUAL do personagem com um nome. Se o nome já
	-- existir, sobrescreve (mesmo padrão de edição do catálogo).
	saveLoadout = function(player, characterName, loadoutName)
		local data = playerDataCache[player]
		if not data then
			return false, "Dados não carregados."
		end

		local charObj = findCharacterByName(data, characterName)
		if not charObj then
			return false, "Você não possui este personagem."
		end

		ensureProgressionFields(charObj)

		if type(loadoutName) ~= "string" or #loadoutName == 0 then
			return false, "Nome da build inválido."
		end
		loadoutName = loadoutName:sub(1, PROGRESSION_LIMITS.MAX_LOADOUT_NAME)

		for _, entry in ipairs(charObj.loadouts) do
			if entry.name == loadoutName then
				entry.passives = deepCopy(charObj.passives)
				syncDataWithClient(player)
				return true, "Build atualizada!"
			end
		end

		if #charObj.loadouts >= PROGRESSION_LIMITS.MAX_LOADOUTS then
			return false, "Limite de " .. PROGRESSION_LIMITS.MAX_LOADOUTS .. " builds atingido."
		end

		table.insert(charObj.loadouts, {
			name = loadoutName,
			passives = deepCopy(charObj.passives),
		})

		syncDataWithClient(player)
		return true, "Build salva!"
	end,

	applyLoadout = function(player, characterName, loadoutName, maxSlots)
		local data = playerDataCache[player]
		if not data then
			return false, "Dados não carregados."
		end

		local charObj = findCharacterByName(data, characterName)
		if not charObj then
			return false, "Você não possui este personagem."
		end

		ensureProgressionFields(charObj)

		local limit = math.clamp(
			math.floor(tonumber(maxSlots) or PROGRESSION_LIMITS.MAX_PASSIVE_SLOTS),
			0,
			PROGRESSION_LIMITS.MAX_PASSIVE_SLOTS
		)

		for _, entry in ipairs(charObj.loadouts) do
			if entry.name == loadoutName then
				local clean = sanitizePassives(entry.passives)
				if #clean > limit then
					return false, "Esta build precisa de mais slots do que o nível atual permite."
				end
				charObj.passives = clean
				syncDataWithClient(player)
				return true, deepCopy(charObj.passives)
			end
		end

		return false, "Build não encontrada."
	end,

	deleteLoadout = function(player, characterName, loadoutName)
		local data = playerDataCache[player]
		if not data then
			return false
		end

		local charObj = findCharacterByName(data, characterName)
		if not charObj then
			return false
		end

		ensureProgressionFields(charObj)

		for i, entry in ipairs(charObj.loadouts) do
			if entry.name == loadoutName then
				table.remove(charObj.loadouts, i)
				syncDataWithClient(player)
				return true
			end
		end

		return false
	end,

	-- ========== RESET ==========

	resetPlayerData = function(player)
		local data = getDefaultData()
		playerDataCache[player] = data

		local leaderstats = player:FindFirstChild("leaderstats")
		if leaderstats then
			local c = leaderstats:FindFirstChild("Coins")
			if c then
				c.Value = 0
			end
			local b = leaderstats:FindFirstChild("Bounty")
			if b then
				b.Value = 0
			end
			local d = leaderstats:FindFirstChild("Deaths")
			if d then
				d.Value = 0
			end
		end

		syncDataWithClient(player)
		savePlayerData(player, false)
	end,

	-- ========== CONFIGURAÇÃO ==========

	SOURCE_PERMISSIONS = SOURCE_PERMISSIONS,
	MIGRATION_CONFIG = MIGRATION_CONFIG,
	createDefaultCharacter = createDefaultCharacter,
	PROGRESSION_LIMITS = PROGRESSION_LIMITS,
}

print([[
╔══════════════════════════════════════════════════════╗
║  DATA MANAGER SERVER V8 — LIMITES AMPLIADOS         ║
╠══════════════════════════════════════════════════════╣
║  SUBSTITUI: DataManager V7                           ║
║  REMOVER:   DataManager V7                           ║
║  * Nível de passiva até 10 (era 3)                   ║
║  * Até 6 slots (era 3) — gamepass libera os extras   ║
╠══════════════════════════════════════════════════════╣
║  NOVO NO V7:                                         ║
║  * level / xp / passives / loadouts por personagem   ║
║  * Migração automática: save V6 entra como nível 1   ║
║    (nenhum personagem ou moeda é perdido)            ║
║  * API: getCharacterProgress / addCharacterXp /      ║
║    setCharacterLevel / setCharacterPassives /        ║
║    saveLoadout / applyLoadout / deleteLoadout        ║
║  * Sanitização anti-exploit (3 slots, rank 1-3)      ║
║  * DATASTORE_NAME/DATA_VERSION intactos — saves OK   ║
╠══════════════════════════════════════════════════════╣
║  MANTIDO DO V6:                                      ║
║  * Inventário novo começa VAZIO (sem Noob forçado)   ║
║  * MIGRATION_CONFIG zerado                           ║
║  * removeCharacterByName sem trava de nome           ║
║  * claimedAchievements preservado no validate        ║
╚══════════════════════════════════════════════════════╝
]])
