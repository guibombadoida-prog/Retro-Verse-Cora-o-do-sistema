-- ============================================
-- RECRUIT JOURNEY SERVER V2
-- Coloque em ServerScriptService
-- Nome: "RecruitJourneyServer"
-- SUBSTITUI: RecruitJourneyServer V1
-- ============================================
-- Jornada do Recruta: onboarding progressivo para novos jogadores
-- ============================================
-- (V2) CORREÇÕES:
-- • FIX farm infinito de recompensa: o V1 guardava o registro de
--   resgate em data.recruitJourney, dentro do blob do DataManager. Mas
--   o validateData do DataManager reconstrói os dados a partir de
--   getDefaultData() e só copia campos de uma lista fixa —
--   recruitJourney não está nela, então era descartado a cada login.
--   Deslogar zerava os resgates e o jogador coletava os 3 capítulos de
--   novo, sem limite (500 moedas + 15 bounty por relog).
--   Agora a jornada tem DataStore próprio (RVRecruitJourneyV1), como o
--   DailyRewardsServer faz. Nenhuma alteração no DataManager.
-- • FIX capítulo 1 zerava a cada 30s: ele media data.equippedCharacter,
--   e o savePlayerData do DataManager faz equippedCharacter = nil no
--   cache VIVO (de propósito — equipar não persiste entre sessões). Com
--   o autosave de 30s, o botão voltava de RESGATAR para BLOQUEADO
--   sozinho. Agora o progresso é travado (latch): quando a meta é
--   atingida uma vez, fica atingida.
-- • FIX ordem 3 no menu unificado — a ordem 2 já é do INVENTÁRIO
--   (CharacterSystemClient), e quem ficava na frente dependia da ordem
--   de carga.
-- • Descrição do capítulo 2 agora diz "jogadores": o stat kills_total
--   só sobe via incrementStat(killer, "kills") no GameManager, e o
--   NPC_Server_V2 não incrementa nada. Kill de NPC não conta.
-- • Cabeçalho no padrão do projeto (-- Nome:).
-- ============================================

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")

repeat
	task.wait()
until _G.PlayerDataManager

-- (V2) DataStore próprio. O blob do DataManager descarta campos que
-- não estão na lista do validateData — ver o cabeçalho.
local journeyStore = DataStoreService:GetDataStore("RVRecruitJourneyV1")

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

local getRecruitJourney = ensureRemote("GetRecruitJourney", "RemoteFunction")
local claimRecruitJourney = ensureRemote("ClaimRecruitJourney", "RemoteFunction")
local recruitJourneyUpdate = ensureRemote("RecruitJourneyUpdate", "RemoteEvent")

local CHAPTERS = {
	{
		id = "first_character",
		title = "CHEGADA AO LOBBY",
		description = "Escolha e equipe seu primeiro personagem.",
		goal = 1,
		rewards = { coins = 100 },
	},
	{
		id = "first_combat",
		title = "PRIMEIRO COMBATE",
		-- (V2) kills_total só sobe com kill de JOGADOR — o NPC_Server_V2
		-- não incrementa stat nenhum. A descrição precisa dizer isso.
		description = "Elimine 3 jogadores para aprender o ritmo da batalha.",
		goal = 3,
		rewards = { coins = 150, bounty = 5 },
	},
	{
		id = "first_level",
		title = "PRIMEIRA EVOLUÇÃO",
		description = "Suba qualquer personagem para o nível 2.",
		goal = 2,
		rewards = { coins = 250, bounty = 10, title = "Recruta Formado" },
	},
}

local chapterById = {}
for _, chapter in ipairs(CHAPTERS) do
	chapterById[chapter.id] = chapter
end

-- =====================================
-- (V2) PERSISTÊNCIA PRÓPRIA
-- =====================================

local journeyCache = {}

local function novaJornada()
	return {
		startedAt = os.time(),
		claimed = {}, -- [chapterId] = os.time() do resgate
		reached = {}, -- [chapterId] = maior progresso já visto (latch)
		completedAt = 0,
		title = nil,
	}
end

-- O DataStore devolve tabelas soltas; nunca confie no formato de volta.
local function sanear(bruto)
	local limpa = novaJornada()
	if type(bruto) ~= "table" then
		return limpa
	end

	limpa.startedAt = tonumber(bruto.startedAt) or limpa.startedAt
	limpa.completedAt = tonumber(bruto.completedAt) or 0
	limpa.title = type(bruto.title) == "string" and bruto.title or nil

	if type(bruto.claimed) == "table" then
		for id, quando in pairs(bruto.claimed) do
			if chapterById[id] and tonumber(quando) then
				limpa.claimed[id] = tonumber(quando)
			end
		end
	end

	if type(bruto.reached) == "table" then
		for id, valor in pairs(bruto.reached) do
			if chapterById[id] and tonumber(valor) then
				limpa.reached[id] = math.max(0, tonumber(valor))
			end
		end
	end

	return limpa
end

local function carregarJornada(player)
	local ok, bruto = pcall(function()
		return journeyStore:GetAsync(tostring(player.UserId))
	end)

	if not ok then
		warn(string.format("[RECRUIT JOURNEY V2] ⚠️ Falha ao carregar %s — usando jornada nova", player.Name))
	end

	journeyCache[player] = sanear(ok and bruto or nil)
	return journeyCache[player]
end

local function salvarJornada(player)
	local jornada = journeyCache[player]
	if not jornada then
		return
	end

	local ok = pcall(function()
		journeyStore:SetAsync(tostring(player.UserId), jornada)
	end)

	if not ok then
		warn(string.format("[RECRUIT JOURNEY V2] ⚠️ Falha ao salvar %s", player.Name))
	end
end

local function getJourneyData(player)
	return journeyCache[player]
end

-- =====================================
-- PROGRESSO
-- =====================================

local function getHighestCharacterLevel(data)
	local highest = 0
	for _, charObj in ipairs(data.ownedCharacters or {}) do
		highest = math.max(highest, charObj.level or 1)
	end
	return highest
end

-- Leitura crua do estado atual, sem memória.
local function lerProgressoCru(data, chapterId)
	if chapterId == "first_character" then
		return data.equippedCharacter and 1 or 0
	end
	if chapterId == "first_combat" then
		return (data.stats and data.stats.kills_total) or 0
	end
	if chapterId == "first_level" then
		return getHighestCharacterLevel(data)
	end
	return 0
end

-- (V2) LATCH — o progresso nunca anda para trás.
-- Sem isso o capítulo 1 zerava a cada autosave: o savePlayerData do
-- DataManager faz equippedCharacter = nil no cache vivo, então a
-- leitura crua vira 0 de 30 em 30 segundos.
local function getChapterCurrent(data, journey, chapterId)
	local cru = lerProgressoCru(data, chapterId)
	local guardado = (journey and journey.reached and journey.reached[chapterId]) or 0

	if cru > guardado and journey and journey.reached then
		journey.reached[chapterId] = cru
		return cru
	end

	return math.max(cru, guardado)
end

local function buildPayload(player)
	local data = _G.PlayerDataManager.getPlayerData(player)
	local journey = getJourneyData(player)

	-- (V2) Sem dados do jogador OU sem a jornada carregada do DataStore,
	-- devolve vazio. Nunca criar jornada aqui — se criasse, um
	-- GetRecruitJourney chegando antes do carregamento sobrescreveria o
	-- registro de resgate com uma jornada zerada.
	if not data or not journey then
		return { chapters = {}, completed = 0, claimed = 0, total = #CHAPTERS, isComplete = false }
	end

	local payload = {}
	local completedCount = 0
	local claimedCount = 0

	for index, chapter in ipairs(CHAPTERS) do
		local current = getChapterCurrent(data, journey, chapter.id)
		local complete = current >= chapter.goal
		local claimed = journey.claimed[chapter.id] ~= nil
		if complete then
			completedCount += 1
		end
		if claimed then
			claimedCount += 1
		end
		table.insert(payload, {
			id = chapter.id,
			index = index,
			title = chapter.title,
			description = chapter.description,
			current = math.min(current, chapter.goal),
			goal = chapter.goal,
			progress = math.clamp(current / chapter.goal, 0, 1),
			complete = complete,
			claimed = claimed,
			canClaim = complete and not claimed,
			rewards = chapter.rewards,
		})
	end

	return {
		chapters = payload,
		completed = completedCount,
		claimed = claimedCount,
		total = #CHAPTERS,
		isComplete = claimedCount >= #CHAPTERS,
		startedAt = journey.startedAt,
		completedAt = journey.completedAt or 0,
	}
end

local function notify(player, text)
	local events = ReplicatedStorage:FindFirstChild("Events")
	local showNotification = events and events:FindFirstChild("ShowNotification")
	if showNotification then
		showNotification:FireClient(player, text)
	end
end

getRecruitJourney.OnServerInvoke = function(player)
	return buildPayload(player)
end

-- (V2) Trava por jogador: o InvokeServer é assíncrono e o botão aceita
-- clique repetido. Sem isso, dois cliques no mesmo frame passam os dois
-- pela checagem de "já resgatado" antes de qualquer um marcar.
local resgatando = {}

claimRecruitJourney.OnServerInvoke = function(player, chapterId)
	if type(chapterId) ~= "string" then
		return false, "Capítulo inválido.", buildPayload(player)
	end

	local chapter = chapterById[chapterId]
	if not chapter then
		return false, "Capítulo não encontrado.", buildPayload(player)
	end

	local data = _G.PlayerDataManager.getPlayerData(player)
	if not data then
		return false, "Dados ainda não carregados.", buildPayload(player)
	end

	local journey = getJourneyData(player)
	if not journey then
		return false, "Jornada ainda carregando. Tente de novo.", buildPayload(player)
	end

	if resgatando[player] then
		return false, "Aguarde o resgate anterior.", buildPayload(player)
	end

	if journey.claimed[chapter.id] then
		return false, "Recompensa já resgatada.", buildPayload(player)
	end

	if getChapterCurrent(data, journey, chapter.id) < chapter.goal then
		return false, "Capítulo ainda incompleto.", buildPayload(player)
	end

	resgatando[player] = true

	-- Marca ANTES de creditar. Se algo falhar no meio, o pior caso é o
	-- jogador não receber — não receber duas vezes.
	journey.claimed[chapter.id] = os.time()

	local rewards = chapter.rewards or {}
	if (rewards.coins or 0) > 0 then
		_G.PlayerDataManager.updateCoins(player, rewards.coins)
	end
	if (rewards.bounty or 0) > 0 then
		_G.PlayerDataManager.updateBounty(player, rewards.bounty)
	end
	if rewards.title then
		journey.title = rewards.title
	end
	if _G.PlayerDataManager.incrementStat then
		_G.PlayerDataManager.incrementStat(player, "recruit_journey_claimed", 1)
	end

	local payload = buildPayload(player)
	if payload.claimed >= payload.total and (journey.completedAt or 0) == 0 then
		journey.completedAt = os.time()
		payload.completedAt = journey.completedAt
	end

	-- (V2) Dois destinos diferentes: moedas/bounty vão no blob do
	-- DataManager, o registro de resgate vai no DataStore da jornada.
	_G.PlayerDataManager.savePlayerData(player)
	salvarJornada(player)

	resgatando[player] = nil

	recruitJourneyUpdate:FireClient(player, payload)
	notify(player, "Jornada do Recruta: recompensa resgatada!")
	print(string.format("[RECRUIT JOURNEY V2] ✅ %s resgatou '%s'", player.Name, chapter.id))
	return true, "Recompensa resgatada!", payload
end

local lastSignature = {}
local function signature(payload)
	local parts = {}
	for _, chapter in ipairs(payload.chapters) do
		table.insert(parts, chapter.id .. ":" .. tostring(chapter.current) .. ":" .. tostring(chapter.claimed))
	end
	return table.concat(parts, "|")
end

task.spawn(function()
	while true do
		task.wait(3)
		for _, player in ipairs(Players:GetPlayers()) do
			local ok, payload = pcall(buildPayload, player)
			if ok and payload then
				local sig = signature(payload)
				if lastSignature[player] ~= sig then
					lastSignature[player] = sig
					recruitJourneyUpdate:FireClient(player, payload)
				end
			end
		end
	end
end)

-- =====================================
-- (V2) CICLO DE VIDA DO JOGADOR
-- =====================================

local function entrou(player)
	carregarJornada(player)

	local jornada = journeyCache[player]
	if jornada then
		print(
			string.format(
				"[RECRUIT JOURNEY V2] ✓ Jornada carregada: %s (%d resgatados)",
				player.Name,
				(function()
					local n = 0
					for _ in pairs(jornada.claimed) do
						n = n + 1
					end
					return n
				end)()
			)
		)
	end
end

Players.PlayerAdded:Connect(entrou)

-- Quem já estava no servidor quando o script carregou
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(entrou, player)
end

Players.PlayerRemoving:Connect(function(player)
	-- Salva o latch de progresso, não só os resgates: sem isso o
	-- capítulo 1 volta a 0 no próximo login (equippedCharacter é
	-- zerado pelo DataManager ao salvar).
	salvarJornada(player)
	journeyCache[player] = nil
	lastSignature[player] = nil
	resgatando[player] = nil
end)

game:BindToClose(function()
	for _, player in ipairs(Players:GetPlayers()) do
		salvarJornada(player)
	end
end)

_G.RecruitJourney = {
	getStatus = buildPayload,
	chapters = CHAPTERS,
}

_G.DebugRecruitJourney = function()
	print("\n========== DEBUG JORNADA DO RECRUTA V2 ==========")
	for _, player in ipairs(Players:GetPlayers()) do
		local jornada = journeyCache[player]
		if not jornada then
			print(string.format("  %s | jornada AINDA NÃO CARREGADA", player.Name))
		else
			local resgates = {}
			for id in pairs(jornada.claimed) do
				table.insert(resgates, id)
			end
			print(
				string.format(
					"  %s | resgatados: %s | latch: %s",
					player.Name,
					#resgates > 0 and table.concat(resgates, ", ") or "nenhum",
					(function()
						local partes = {}
						for id, valor in pairs(jornada.reached) do
							table.insert(partes, id .. "=" .. tostring(valor))
						end
						return #partes > 0 and table.concat(partes, ", ") or "vazio"
					end)()
				)
			)
		end
	end
	print("================================================\n")
end

print("[RECRUIT JOURNEY V2] Sistema Jornada do Recruta carregado")
