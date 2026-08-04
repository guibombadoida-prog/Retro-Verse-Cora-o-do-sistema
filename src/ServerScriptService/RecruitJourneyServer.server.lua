-- ============================================
-- RECRUIT JOURNEY SERVER V1
-- ServerScriptService > RecruitJourneyServer
-- Jornada do Recruta: onboarding progressivo para novos jogadores
-- ============================================

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

repeat
	task.wait()
until _G.PlayerDataManager

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
		description = "Consiga 3 eliminações para aprender o ritmo da batalha.",
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

local function getJourneyData(data)
	if type(data.recruitJourney) ~= "table" then
		data.recruitJourney = {
			startedAt = os.time(),
			claimed = {},
			completedAt = 0,
		}
	end
	if type(data.recruitJourney.claimed) ~= "table" then
		data.recruitJourney.claimed = {}
	end
	return data.recruitJourney
end

local function getHighestCharacterLevel(data)
	local highest = 0
	for _, charObj in ipairs(data.ownedCharacters or {}) do
		highest = math.max(highest, charObj.level or 1)
	end
	return highest
end

local function getChapterCurrent(data, chapterId)
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

local function buildPayload(player)
	local data = _G.PlayerDataManager.getPlayerData(player)
	if not data then
		return { chapters = {}, completed = 0, claimed = 0, total = #CHAPTERS, isComplete = false }
	end

	local journey = getJourneyData(data)
	local payload = {}
	local completedCount = 0
	local claimedCount = 0

	for index, chapter in ipairs(CHAPTERS) do
		local current = getChapterCurrent(data, chapter.id)
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

	local journey = getJourneyData(data)
	if journey.claimed[chapter.id] then
		return false, "Recompensa já resgatada.", buildPayload(player)
	end

	if getChapterCurrent(data, chapter.id) < chapter.goal then
		return false, "Capítulo ainda incompleto.", buildPayload(player)
	end

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

	_G.PlayerDataManager.savePlayerData(player)
	recruitJourneyUpdate:FireClient(player, payload)
	notify(player, "Jornada do Recruta: recompensa resgatada!")
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

Players.PlayerRemoving:Connect(function(player)
	lastSignature[player] = nil
end)

_G.RecruitJourney = {
	getStatus = buildPayload,
	chapters = CHAPTERS,
}

print("[RECRUIT JOURNEY V1] Sistema Jornada do Recruta carregado")
