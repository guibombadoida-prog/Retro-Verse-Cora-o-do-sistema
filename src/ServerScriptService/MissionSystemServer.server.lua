-- ============================================
-- MISSION SYSTEM SERVER V2
-- Nome: "MissionSystemServer"
-- (V2) ALTERAÇÕES: :Destroy() -> .Parent = nil (conformidade)
-- ServerScriptService > MissionSystemServer
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

local getMissionStatus = ensureRemote("GetMissionStatus", "RemoteFunction")
local claimMissionReward = ensureRemote("ClaimMissionReward", "RemoteFunction")
local missionUpdate = ensureRemote("MissionUpdate", "RemoteEvent") -- server -> client (ao vivo)

local MISSIONS = {
	{
		id = "first_kill",
		title = "PRIMEIRO ABATE",
		description = "Elimine 1 jogador.",
		stat = "kills_total",
		goal = 1,
		rewards = { coins = 100, bounty = 5 },
	},
	{
		id = "hunter_rookie",
		title = "CACADOR INICIANTE",
		description = "Acumule 5 eliminacoes.",
		stat = "kills_total",
		goal = 5,
		rewards = { coins = 250, bounty = 20 },
	},
	{
		id = "coin_collector",
		title = "BOLSO CHEIO",
		description = "Ganhe 500 moedas no total.",
		stat = "coins_earned_total",
		goal = 500,
		rewards = { coins = 150, bounty = 0 },
	},
	{
		id = "bounty_hunter",
		title = "CACADOR DE BOUNTY",
		description = "Alcance 100 de bounty.",
		stat = "bounty",
		goal = 100,
		rewards = { coins = 300, bounty = 25 },
	},
	{
		id = "first_purchase",
		title = "NOVO PERSONAGEM",
		description = "Compre 1 personagem na loja.",
		stat = "characters_bought",
		goal = 1,
		rewards = { coins = 120, bounty = 10 },
	},
	{
		id = "market_move",
		title = "NEGOCIANTE",
		description = "Venda 1 personagem do inventario.",
		stat = "characters_sold",
		goal = 1,
		rewards = { coins = 120, bounty = 10 },
	},
}

local missionById = {}
for _, mission in ipairs(MISSIONS) do
	missionById[mission.id] = mission
end

local function getStatValue(data, statName)
	if statName == "coins" then
		return data.coins or 0
	end

	local stats = data.stats or {}
	return stats[statName] or 0
end

local function getClaimedTable(data)
	if type(data.claimedMissions) ~= "table" then
		data.claimedMissions = {}
	end
	return data.claimedMissions
end

local function buildMissionPayload(player)
	local data = _G.PlayerDataManager.getPlayerData(player)
	if not data then
		return { missions = {}, completed = 0, claimed = 0, total = #MISSIONS }
	end

	local claimedMissions = getClaimedTable(data)
	local payload = {}
	local completedCount = 0
	local claimedCount = 0

	for _, mission in ipairs(MISSIONS) do
		local current = getStatValue(data, mission.stat)
		local progress = math.clamp(current / mission.goal, 0, 1)
		local claimed = claimedMissions[mission.id] ~= nil
		local complete = current >= mission.goal

		if complete then
			completedCount += 1
		end
		if claimed then
			claimedCount += 1
		end

		table.insert(payload, {
			id = mission.id,
			title = mission.title,
			description = mission.description,
			current = current,
			goal = mission.goal,
			progress = progress,
			complete = complete,
			claimed = claimed,
			canClaim = complete and not claimed,
			rewards = mission.rewards,
		})
	end

	return {
		missions = payload,
		completed = completedCount,
		claimed = claimedCount,
		total = #MISSIONS,
	}
end

getMissionStatus.OnServerInvoke = function(player)
	return buildMissionPayload(player)
end

claimMissionReward.OnServerInvoke = function(player, missionId)
	if type(missionId) ~= "string" then
		return false, "Missao invalida.", buildMissionPayload(player)
	end

	local mission = missionById[missionId]
	if not mission then
		return false, "Missao nao encontrada.", buildMissionPayload(player)
	end

	local data = _G.PlayerDataManager.getPlayerData(player)
	if not data then
		return false, "Dados nao carregados.", buildMissionPayload(player)
	end

	local claimedMissions = getClaimedTable(data)
	if claimedMissions[mission.id] then
		return false, "Recompensa ja resgatada.", buildMissionPayload(player)
	end

	local current = getStatValue(data, mission.stat)
	if current < mission.goal then
		return false, "Missao ainda incompleta.", buildMissionPayload(player)
	end

	claimedMissions[mission.id] = os.time()

	local rewards = mission.rewards or {}
	if (rewards.coins or 0) > 0 then
		_G.PlayerDataManager.updateCoins(player, rewards.coins)
	end
	if (rewards.bounty or 0) > 0 then
		_G.PlayerDataManager.updateBounty(player, rewards.bounty)
	end
	if _G.PlayerDataManager.incrementStat then
		_G.PlayerDataManager.incrementStat(player, "missions_completed", 1)
	end
	_G.PlayerDataManager.savePlayerData(player)

	local payload = buildMissionPayload(player)
	missionUpdate:FireClient(player, payload) -- atualiza o menu ao vivo
	return true, "Recompensa resgatada!", payload
end

-- ============================================
-- MONITOR: empurra atualização ao vivo quando o estado das missões muda
-- (ex: o jogador progrediu uma missão e agora pode resgatar)
-- ============================================
local lastSignature = {}

local function signature(payload)
	local parts = {}
	for _, m in ipairs(payload.missions) do
		local mark = m.claimed and "C" or (m.canClaim and "R" or tostring(m.current))
		table.insert(parts, m.id .. ":" .. mark)
	end
	return table.concat(parts, "|")
end

task.spawn(function()
	while true do
		task.wait(3)
		for _, player in ipairs(Players:GetPlayers()) do
			local ok, payload = pcall(buildMissionPayload, player)
			if ok and payload then
				local sig = signature(payload)
				if lastSignature[player] ~= sig then
					lastSignature[player] = sig
					missionUpdate:FireClient(player, payload)
				end
			end
		end
	end
end)

Players.PlayerRemoving:Connect(function(p)
	lastSignature[p] = nil
end)

print("[MISSIONS V1] Sistema de missoes carregado")
