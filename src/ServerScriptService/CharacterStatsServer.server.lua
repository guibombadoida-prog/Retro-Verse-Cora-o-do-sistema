-- ============================================
-- CHARACTER STATS SERVER V2 — ATRIBUTOS POR PERSONAGEM
-- Coloque em ServerScriptService
-- Nome: "CharacterStatsServer"
-- DEPENDE DE: DataManager V7, StatService V2, AdminRegistryServer V1
-- SUBSTITUI: CharacterStatsServer V1
-- REMOVER:   CharacterStatsServer V1
-- ============================================
-- (V2) CORREÇÃO DO BUG DE DATASTORE:
--
-- No seu log apareceu isto, repetido:
--   ⚠️ DataStore request was added to queue ... Key = definitions
--
-- Causa: o V1 gravava a tabela INTEIRA na mesma chave a cada clique
-- em SALVAR, sem nenhuma proteção. O Roblox limita gravação na mesma
-- chave a cada ~6 segundos. Como o botão não travava, você tocou
-- várias vezes (justo, já que nada dava sinal de vida) e cada toque
-- virou um SetAsync. Se a fila enche, gravações são DESCARTADAS em
-- silêncio — você acha que salvou e não salvou.
--
-- ✅ Agora existe uma janela de agrupamento: várias mudanças em
--    sequência viram UMA gravação só, respeitando o intervalo
--    mínimo. A mudança vale na memória e sincroniza NA HORA (o
--    jogador vê o efeito imediatamente); só a gravação em disco é
--    que espera a janela.
--
-- ✅ Também grava o que estiver pendente quando o servidor fecha
--    (BindToClose), pra não perder a última edição.
-- ============================================
-- O BURACO QUE ISTO FECHA:
-- Hoje um personagem só se diferencia por VIDA e TOOLS. Dois
-- personagens com 300 HP e a mesma arma são idênticos jogando —
-- muda só o visual. Com o StatService no ar, dá pra dar identidade
-- de verdade: um é lento e duro, outro é rápido e frágil.
--
-- ============================================
-- POR QUE ISTO É UM SCRIPT SEPARADO
-- ============================================
-- O caminho óbvio seria colocar `stats` dentro do
-- CharacterCatalogServer V6. Não fiz, por dois motivos:
--
-- 1. RISCO. O catálogo tem 974 linhas e funciona. O painel admin
--    tem 1697. Mexer nos dois pra adicionar atributos significa
--    arriscar Loja, Gamepass, Badge, Bounty e sincronização entre
--    servidores — tudo isso pra ganhar um campo novo.
--
-- 2. UX. 23 atributos = 23 campos de texto no wizard do admin. Num
--    celular isso é impraticável. A saída é o sistema de ARQUÉTIPO
--    abaixo: UM dropdown em vez de 23 caixas.
--
-- É o mesmo padrão do PassiveMenuClient: script separado, arquivo
-- que funciona fica intocado. Quando/se quiser juntar no wizard
-- depois, é só chamar `_G.CharacterStats.set` de lá.
--
-- ⚠️ CharacterCatalogServer V6 e AdminMenuClient V9 ficam INTOCADOS.
--
-- ============================================
-- ARQUÉTIPOS — 1 ESCOLHA EM VEZ DE 23
-- ============================================
-- Cada personagem recebe um arquétipo (Tanque, Assassino, Mago...)
-- que já vem com um conjunto de atributos coerente. Isso resolve 90%
-- dos casos com uma escolha só.
-- Pra afinar um personagem específico, dá pra somar atributos
-- avulsos por cima (campo `custom`), sem perder o arquétipo.
--
-- ⚠️ Personagem SEM configuração continua exatamente como está hoje
--    (zero atributo extra). Nada muda até você configurar.
--
-- REUTILIZAÇÃO (nada criado do zero):
-- • DataStore + MessagingService + isAdmin + publishSync ...
--   CharacterCatalogServer V6 (mesmo desenho, tópico próprio)
-- • Registro de fonte de atributos ... StatService V1
-- • ensureRemote / banner / _G API ... padrão geral do projeto
-- ============================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")
local MessagingService = game:GetService("MessagingService")

repeat
	task.wait()
until _G.PlayerDataManager and _G.StatService

-- =====================================
-- CONFIGURAÇÃO
-- =====================================

local CONFIG = {
	-- DataStore PRÓPRIO. Não mexe no do catálogo, então não há risco
	-- de corromper as definições de personagem que já existem.
	DATASTORE_NAME = "RVCharacterStatsV1",
	DATASTORE_KEY = "definitions",

	-- Tópico próprio, mesmo padrão do catálogo
	SYNC_TOPIC = "RVCharacterStatsSync",

	SOURCE_NAME = "character", -- nome da fonte no StatService

	-- Limites de sanidade. Impede que um admin digite 999 sem querer
	-- e quebre o jogo inteiro.
	MAX_PERCENT = 3.0, -- +300%
	MIN_PERCENT = -0.90, -- -90%
	MAX_FLAT = 5000,
	MIN_FLAT = -5000,

	APPLY_DELAY = 1.4, -- entra antes do StatService recalcular (1.5s)

	-- (V2) Intervalo mínimo entre gravações na mesma chave.
	-- O limite do Roblox é ~6s; 7 dá folga.
	SAVE_INTERVAL = 7,
}

-- =====================================
-- ARQUÉTIPOS
-- =====================================
-- Todo arquétipo tem vantagem E desvantagem, mesma regra das
-- passivas: nenhum pode ser só melhor que outro.

local ARCHETYPES = {
	{
		id = "equilibrado",
		name = "Equilibrado",
		icon = "⚪",
		desc = "Sem bônus nem penalidade (padrão)",
		stats = {},
	},
	{
		id = "tanque",
		name = "Tanque",
		icon = "🛡️",
		desc = "+25% vida, +8% resistência / -12% velocidade",
		stats = { HPPercent = 0.25, DamageResistance = 0.08, WalkSpeedPercent = -0.12 },
	},
	{
		id = "assassino",
		name = "Assassino",
		icon = "🗡️",
		desc = "+18% dano, +12% velocidade / -15% vida",
		stats = { DamageBoost = 0.18, WalkSpeedPercent = 0.12, HPPercent = -0.15 },
	},
	{
		id = "bruiser",
		name = "Brigão",
		icon = "🥊",
		desc = "+12% vida, +8% dano / -5% velocidade",
		stats = { HPPercent = 0.12, DamageBoost = 0.08, WalkSpeedPercent = -0.05 },
	},
	{
		id = "agil",
		name = "Ágil",
		icon = "💨",
		desc = "+20% velocidade, +20% pulo / -10% vida",
		stats = { WalkSpeedPercent = 0.20, JumpPercent = 0.20, HPPercent = -0.10 },
	},
	{
		id = "lutador",
		name = "Lutador (Melee)",
		icon = "⚔️",
		desc = "+20% dano corpo a corpo / -10% resistência a distância",
		stats = { MeleeBoost = 0.20, RangedResist = -0.10 },
	},
	{
		id = "atirador",
		name = "Atirador (Ranged)",
		icon = "🏹",
		desc = "+20% dano à distância / -12% resistência corpo a corpo",
		stats = { RangedBoost = 0.20, MeleeResist = -0.12 },
	},
	{
		id = "mago",
		name = "Mago (Magic)",
		icon = "🔮",
		desc = "+22% dano mágico / -12% vida",
		stats = { MagicBoost = 0.22, HPPercent = -0.12 },
	},
	{
		id = "suporte",
		name = "Suporte",
		icon = "💚",
		desc = "+25% cura dada, +10% cura recebida / -12% dano",
		stats = { OutgoingHealing = 0.25, IncomingHealing = 0.10, DamageBoost = -0.12 },
	},
	{
		id = "fortificado",
		name = "Fortificado",
		icon = "🏰",
		desc = "+150 Defense, +40 Escudo / -8% velocidade",
		stats = { DefenseFlat = 150, Shield = 40, WalkSpeedPercent = -0.08 },
	},
}

local archetypeById = {}
for _, archetype in ipairs(ARCHETYPES) do
	archetypeById[archetype.id] = archetype
end

-- =====================================
-- ESTADO
-- =====================================

-- [characterName] = { archetype = "tanque", custom = {...}, editedBy, editedAt }
local definitions = {}

local dataStore = nil
local pcallOk = pcall(function()
	dataStore = DataStoreService:GetDataStore(CONFIG.DATASTORE_NAME)
end)
if not pcallOk then
	warn("[CHAR STATS V2] DataStore indisponível — rodando só em memória")
end

-- =====================================
-- ADMIN (mesmo padrão do catálogo)
-- =====================================

local function isAdmin(player)
	if _G.AdminRegistry and _G.AdminRegistry.isAdmin then
		return _G.AdminRegistry.isAdmin(player)
	end
	return false
end

-- =====================================
-- VALIDAÇÃO
-- =====================================
-- Só deixa passar atributo que EXISTE no StatService. Nome digitado
-- errado é rejeitado com aviso, em vez de virar atributo fantasma
-- que ninguém descobre por meses.

local function sanitizeCustom(raw)
	local clean = {}
	local rejected = {}

	if type(raw) ~= "table" then
		return clean, rejected
	end

	local defs = _G.StatService.STAT_DEFS

	for name, value in pairs(raw) do
		local def = defs[name]
		if not def then
			table.insert(rejected, tostring(name))
		elseif type(value) ~= "number" or value ~= value then
			table.insert(rejected, tostring(name) .. " (não é número)")
		else
			if def.kind == "percent" then
				clean[name] = math.clamp(value, CONFIG.MIN_PERCENT, CONFIG.MAX_PERCENT)
			else
				clean[name] = math.clamp(value, CONFIG.MIN_FLAT, CONFIG.MAX_FLAT)
			end
		end
	end

	return clean, rejected
end

-- =====================================
-- CÁLCULO FINAL DE UM PERSONAGEM
-- =====================================

local function buildStats(characterName)
	local definition = definitions[characterName]
	if not definition then
		return {} -- personagem sem config = zero atributo extra
	end

	local stats = {}

	-- 1) arquétipo
	local archetype = archetypeById[definition.archetype or "equilibrado"]
	if archetype then
		for name, value in pairs(archetype.stats) do
			stats[name] = (stats[name] or 0) + value
		end
	end

	-- 2) ajustes avulsos por cima
	if definition.custom then
		for name, value in pairs(definition.custom) do
			stats[name] = (stats[name] or 0) + value
		end
	end

	return stats
end

-- =====================================
-- APLICAÇÃO
-- =====================================

local function applyToPlayer(player)
	if not player or not player.Parent then
		return
	end

	local data = _G.PlayerDataManager.getPlayerData(player)
	local equipped = data and data.equippedCharacter

	if not equipped then
		_G.StatService.clearSource(player, CONFIG.SOURCE_NAME)
		return
	end

	local stats = buildStats(equipped)
	_G.StatService.setSource(player, CONFIG.SOURCE_NAME, stats)
end

local function reapplyToAll()
	for _, player in ipairs(Players:GetPlayers()) do
		pcall(applyToPlayer, player)
	end
end

-- =====================================
-- PERSISTÊNCIA
-- =====================================

local function loadDefinitions()
	if not dataStore then
		return
	end

	local ok, result = pcall(function()
		return dataStore:GetAsync(CONFIG.DATASTORE_KEY)
	end)

	if ok and type(result) == "table" then
		for name, definition in pairs(result) do
			if type(name) == "string" and type(definition) == "table" then
				local custom = sanitizeCustom(definition.custom)
				definitions[name] = {
					archetype = archetypeById[definition.archetype] and definition.archetype or "equilibrado",
					custom = custom,
					editedBy = definition.editedBy,
					editedAt = definition.editedAt,
				}
			end
		end

		local count = 0
		for _ in pairs(definitions) do
			count = count + 1
		end
		print(string.format("[CHAR STATS V2] %d personagem(ns) com atributos carregados", count))
	elseif not ok then
		warn("[CHAR STATS V2] Falha ao carregar: " .. tostring(result))
	end
end

-- (V2) GRAVAÇÃO COM AGRUPAMENTO
-- `saveDefinitions` não grava mais na hora: ele MARCA que há algo
-- pendente. Um laço grava no máximo uma vez por SAVE_INTERVAL.
-- Assim 10 cliques seguidos viram 1 gravação, e a fila do DataStore
-- nunca enche.

local savePending = false
local lastSaveTime = 0

local function writeNow()
	if not dataStore or not savePending then
		return false
	end

	savePending = false
	lastSaveTime = os.clock()

	local ok, err = pcall(function()
		dataStore:SetAsync(CONFIG.DATASTORE_KEY, definitions)
	end)

	if not ok then
		warn("[CHAR STATS V2] Falha ao salvar: " .. tostring(err))
		savePending = true -- tenta de novo na próxima janela
	end

	return ok
end

local function saveDefinitions()
	savePending = true
	return true
end

task.spawn(function()
	while true do
		task.wait(1)
		if savePending and (os.clock() - lastSaveTime) >= CONFIG.SAVE_INTERVAL then
			writeNow()
		end
	end
end)

-- Não perde a última edição se o servidor fechar antes da janela
game:BindToClose(function()
	if savePending then
		writeNow()
	end
end)

-- =====================================
-- SINCRONIZAÇÃO ENTRE SERVIDORES
-- =====================================
-- Mesmo desenho do CharacterCatalogServer: edita num servidor,
-- todos os outros recebem sem reiniciar.

local function publishSync(action, characterName, adminName)
	pcall(function()
		MessagingService:PublishAsync(CONFIG.SYNC_TOPIC, {
			action = action,
			name = characterName,
			admin = adminName,
			jobId = game.JobId,
		})
	end)
end

pcall(function()
	MessagingService:SubscribeAsync(CONFIG.SYNC_TOPIC, function(message)
		local data = message.Data
		if type(data) ~= "table" or data.jobId == game.JobId then
			return -- ignora o eco do próprio servidor
		end

		-- Recarrega do DataStore (fonte da verdade) e reaplica
		loadDefinitions()
		reapplyToAll()

		print(
			string.format(
				"[CHAR STATS V2] Sincronizado: %s em '%s' por %s",
				tostring(data.action),
				tostring(data.name),
				tostring(data.admin)
			)
		)
	end)
end)

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
		remote.Parent = nil -- regra do projeto: sem :Destroy()
		remote = nil
	end
	if not remote then
		remote = Instance.new(className)
		remote.Name = name
		remote.Parent = remotes
	end
	return remote
end

local getCharacterStats = ensureRemote("GetCharacterStatsInfo", "RemoteFunction")
local adminSetStats = ensureRemote("AdminSetCharacterStats", "RemoteFunction")
local adminRemoveStats = ensureRemote("AdminRemoveCharacterStats", "RemoteFunction")

-- Leitura: qualquer jogador pode ver (é informação de jogo)
getCharacterStats.OnServerInvoke = function(_, characterName)
	local archetypeList = {}
	for _, archetype in ipairs(ARCHETYPES) do
		table.insert(archetypeList, {
			id = archetype.id,
			name = archetype.name,
			icon = archetype.icon,
			desc = archetype.desc,
		})
	end

	if type(characterName) ~= "string" then
		return { archetypes = archetypeList }
	end

	local definition = definitions[characterName]

	return {
		archetypes = archetypeList,
		characterName = characterName,
		archetype = definition and definition.archetype or "equilibrado",
		custom = definition and definition.custom or {},
		finalStats = buildStats(characterName),
	}
end

-- Escrita: só admin
adminSetStats.OnServerInvoke = function(player, characterName, archetypeId, customStats)
	if not isAdmin(player) then
		return false, "Sem permissão."
	end

	if type(characterName) ~= "string" or #characterName < 2 then
		return false, "Nome de personagem inválido."
	end

	if archetypeId ~= nil and not archetypeById[archetypeId] then
		return false, "Arquétipo inválido."
	end

	local custom, rejected = sanitizeCustom(customStats)

	definitions[characterName] = {
		archetype = archetypeId or "equilibrado",
		custom = custom,
		editedBy = player.Name,
		editedAt = os.time(),
	}

	saveDefinitions()
	reapplyToAll()
	publishSync("set", characterName, player.Name)

	local message = string.format(
		"'%s' agora é %s.",
		characterName,
		archetypeById[definitions[characterName].archetype].name
	)

	if #rejected > 0 then
		message = message .. " ⚠️ Ignorados: " .. table.concat(rejected, ", ")
	end

	print("[CHAR STATS V2] " .. player.Name .. ": " .. message)
	return true, message
end

adminRemoveStats.OnServerInvoke = function(player, characterName)
	if not isAdmin(player) then
		return false, "Sem permissão."
	end

	if not definitions[characterName] then
		return false, "Esse personagem não tem atributos configurados."
	end

	definitions[characterName] = nil

	saveDefinitions()
	reapplyToAll()
	publishSync("remove", characterName, player.Name)

	return true, string.format("Atributos de '%s' removidos.", characterName)
end

-- =====================================
-- EVENTOS DE JOGADOR
-- =====================================

local function onCharacterAdded(player)
	task.wait(CONFIG.APPLY_DELAY) -- depois do GameManager equipar
	applyToPlayer(player)
end

local function onPlayerAdded(player)
	player.CharacterAdded:Connect(function()
		task.spawn(onCharacterAdded, player)
	end)

	if player.Character then
		task.spawn(onCharacterAdded, player)
	end
end

Players.PlayerAdded:Connect(onPlayerAdded)

for _, player in ipairs(Players:GetPlayers()) do
	onPlayerAdded(player)
end

-- =====================================
-- INICIALIZAÇÃO
-- =====================================

loadDefinitions()
reapplyToAll()

-- =====================================
-- API GLOBAL
-- =====================================

_G.CharacterStats = {
	CONFIG = CONFIG,
	ARCHETYPES = ARCHETYPES,

	-- Configura um personagem por código (o CharacterCatalogServer
	-- pode chamar isto se um dia você quiser juntar no wizard):
	--   _G.CharacterStats.set("Noob", "tanque")
	--   _G.CharacterStats.set("Noob", "tanque", { MeleeBoost = 0.10 })
	set = function(characterName, archetypeId, customStats, adminName)
		if type(characterName) ~= "string" then
			return false, "Nome inválido."
		end
		if archetypeId ~= nil and not archetypeById[archetypeId] then
			return false, "Arquétipo inválido."
		end

		local custom = sanitizeCustom(customStats)

		definitions[characterName] = {
			archetype = archetypeId or "equilibrado",
			custom = custom,
			editedBy = adminName or "script",
			editedAt = os.time(),
		}

		saveDefinitions()
		reapplyToAll()
		publishSync("set", characterName, adminName or "script")
		return true
	end,

	remove = function(characterName)
		if not definitions[characterName] then
			return false
		end
		definitions[characterName] = nil
		saveDefinitions()
		reapplyToAll()
		publishSync("remove", characterName, "script")
		return true
	end,

	getStats = buildStats,

	getDefinition = function(characterName)
		return definitions[characterName]
	end,

	getArchetypes = function()
		return ARCHETYPES
	end,

	refresh = function(player)
		applyToPlayer(player)
	end,

	refreshAll = reapplyToAll,
}

-- =====================================
-- DEBUG
-- =====================================

_G.DebugCharacterStats = function(characterName)
	print("\n========== DEBUG CHARACTER STATS V1 ==========")

	if characterName then
		local definition = definitions[characterName]
		if not definition then
			print(string.format("'%s' não tem atributos configurados (usa o padrão).", characterName))
		else
			local archetype = archetypeById[definition.archetype]
			print(string.format("Personagem: %s", characterName))
			print(string.format("Arquétipo: %s %s", archetype and archetype.icon or "?", archetype and archetype.name or "?"))
			print(string.format("Editado por: %s", definition.editedBy or "?"))

			print("\n-- ATRIBUTOS FINAIS --")
			for name, value in pairs(buildStats(characterName)) do
				local def = _G.StatService.STAT_DEFS[name]
				local shown = def and def.kind == "percent" and string.format("%.1f%%", value * 100)
					or string.format("%.0f", value)
				print(string.format("  %-20s %s", name, shown))
			end
		end
	else
		local count = 0
		for name, definition in pairs(definitions) do
			count = count + 1
			local archetype = archetypeById[definition.archetype]
			print(string.format("  %-20s %s %s", name, archetype and archetype.icon or "?", archetype and archetype.name or "?"))
		end
		if count == 0 then
			print("Nenhum personagem configurado ainda.")
			print("\nArquétipos disponíveis:")
			for _, archetype in ipairs(ARCHETYPES) do
				print(string.format("  %-14s %s %s", archetype.id, archetype.icon, archetype.desc))
			end
			print("\nExemplo: _G.CharacterStats.set(\"Noob\", \"tanque\")")
		end
	end
	print("=====================================\n")
end

print([[
╔══════════════════════════════════════════════════════╗
║  CHARACTER STATS SERVER V2 — CARREGADO              ║
╠══════════════════════════════════════════════════════╣
║  SUBSTITUI: CharacterStatsServer V1                  ║
║  REMOVER:   CharacterStatsServer V1                  ║
║  CharacterCatalogServer V6 e AdminMenuClient V9      ║
║  ficam INTOCADOS                                     ║
╠══════════════════════════════════════════════════════╣
║  * 10 arquétipos (Tanque, Assassino, Mago...)        ║
║  * 1 escolha em vez de 23 campos de texto            ║
║  * Ajuste fino por atributo avulso, se quiser        ║
║  * DataStore e tópico PRÓPRIOS (não toca no catálogo)║
║  * Sincroniza entre servidores, sem reabrir o Studio ║
║  * Personagem sem config = igual está hoje           ║
║  * (V2) Gravação agrupada: acabou o aviso de fila    ║
╠══════════════════════════════════════════════════════╣
║  _G.CharacterStats.set("Noob", "tanque")             ║
║  DEBUG: _G.DebugCharacterStats()                     ║
╚══════════════════════════════════════════════════════╝
]])
