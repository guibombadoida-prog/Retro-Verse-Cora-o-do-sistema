-- ============================================
-- WANTED SYSTEM SERVER V2 — CAÇADA + NÍVEIS (ESTRELAS)
-- Coloque em ServerScriptService
-- Nome: "WantedSystemServer"
-- SUBSTITUI: WantedSystemServer V1
-- ============================================
-- (V2) EVOLUÇÕES sobre o V1:
-- • NÍVEIS DE "PROCURADO" (estrelas, tipo GTA): a faixa de bounty
--   define de 1 a 5 estrelas, e mais estrelas = recompensa maior
--   pra quem caçar (rewardPercent sobe por nível).
-- • O payload agora manda "stars" pro cliente (banner + a bússola
--   client-side usam isso).
-- • A bússola/seta que aponta o alvo é 100% no cliente (ele já
--   sabe o NOME do alvo e acha o personagem replicado) — então o
--   servidor não precisa mandar posição.
--
-- MANTÉM do V1: maior bounty vira alvo; lastDamager (Handle.Touched)
-- do GameManager_V6 só pra atribuir quem matou; bônus ADICIONAL ao
-- kill normal; API do DataManager_V4.
-- ============================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CONFIG = {
	WANTED_REFRESH = 20, -- segundos entre recálculos do alvo
	MIN_BOUNTY = 50, -- bounty mínimo para virar alvo
	MIN_REWARD = 100, -- bônus mínimo ao caçar o alvo
	DAMAGE_MEMORY = 10, -- segundos que o lastDamager é lembrado
}

-- (V2) Níveis de "procurado" por faixa de bounty.
-- Mais estrelas = recompensa maior pra quem caçar.
local WANTED_LEVELS = {
	{ minBounty = 50, stars = 1, rewardPercent = 40 },
	{ minBounty = 150, stars = 2, rewardPercent = 50 },
	{ minBounty = 300, stars = 3, rewardPercent = 60 },
	{ minBounty = 600, stars = 4, rewardPercent = 75 },
	{ minBounty = 1000, stars = 5, rewardPercent = 100 },
}

local function getWantedLevel(bounty)
	local stars, pct = 0, 0
	for _, lvl in ipairs(WANTED_LEVELS) do
		if bounty >= lvl.minBounty then
			stars = lvl.stars
			pct = lvl.rewardPercent
		end
	end
	return stars, pct
end

repeat
	task.wait()
until _G.PlayerDataManager

local PDM = _G.PlayerDataManager

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

local wantedUpdateRemote = ensureRemote("WantedUpdate", "RemoteEvent")
local wantedKillRemote = ensureRemote("WantedKill", "RemoteEvent")

-- =====================================
-- ESTADO
-- =====================================

local lastDamager = {} -- [victim] = attacker (padrão do GameManager_V6)
local currentTarget = nil
local currentReward = 0
local currentStars = 0

-- =====================================
-- HELPERS
-- =====================================

local function getBounty(plr)
	local data = PDM.getPlayerData(plr)
	if data and data.stats then
		return data.stats.bounty or 0
	end
	return 0
end

local function rewardFor(bounty)
	local _, pct = getWantedLevel(bounty)
	return math.max(CONFIG.MIN_REWARD, math.floor(bounty * pct / 100))
end

local function buildTargetPayload()
	if currentTarget and currentTarget.Parent then
		return {
			name = currentTarget.Name,
			bounty = getBounty(currentTarget),
			reward = currentReward,
			stars = currentStars,
		}
	end
	return nil
end

local function broadcastTarget()
	local payload = buildTargetPayload()
	for _, p in ipairs(Players:GetPlayers()) do
		wantedUpdateRemote:FireClient(p, payload)
	end
end

local function refreshRewardStars()
	if currentTarget then
		local b = getBounty(currentTarget)
		currentStars = select(1, getWantedLevel(b))
		currentReward = rewardFor(b)
	else
		currentStars = 0
		currentReward = 0
	end
end

local function setTarget(player)
	if currentTarget == player then
		refreshRewardStars()
		broadcastTarget()
		return
	end

	currentTarget = player
	refreshRewardStars()
	broadcastTarget()

	if player then
		print(string.format("[WANTED V2] Novo alvo: %s (%d⭐, recompensa %d)", player.Name, currentStars, currentReward))
	else
		print("[WANTED V2] Sem alvo no momento")
	end
end

-- Recalcula o alvo = maior bounty acima do mínimo
local function recomputeTarget()
	local best = nil
	local bestBounty = -1
	for _, p in ipairs(Players:GetPlayers()) do
		local b = getBounty(p)
		if b >= CONFIG.MIN_BOUNTY and b > bestBounty then
			best = p
			bestBounty = b
		end
	end
	setTarget(best)
end

-- =====================================
-- CAÇADA CONCLUÍDA (alvo morreu)
-- =====================================

local function onTargetKilled(target)
	local hunter = lastDamager[target]
	local reward = currentReward
	local stars = currentStars

	-- Limpar alvo já (evita duplo processamento)
	setTarget(nil)

	if hunter and hunter ~= target and hunter.Parent then
		-- Bônus ADICIONAL (DataManager_V4)
		PDM.updateCoins(hunter, reward)
		PDM.incrementStat(hunter, "hunts", 1)
		PDM.savePlayerData(hunter)

		-- Anunciar para todos
		for _, p in ipairs(Players:GetPlayers()) do
			wantedKillRemote:FireClient(p, {
				hunter = hunter.Name,
				target = target.Name,
				reward = reward,
				stars = stars,
			})
		end

		print(string.format("[WANTED V2] %s caçou %s (%d⭐) → +%d moedas", hunter.Name, target.Name, stars, reward))
	end

	-- Escolher novo alvo logo em seguida
	task.delay(2, recomputeTarget)
end

-- =====================================
-- RASTREIO DE DANO + MORTE (padrão REUTILIZADO do GameManager_V6)
-- =====================================

local function hookCharacter(player, character)
	local humanoid = character:WaitForChild("Humanoid", 10)
	if not humanoid then
		return
	end

	-- Morte: se o morto é o ALVO, processa a caçada
	humanoid.Died:Connect(function()
		if currentTarget == player then
			onTargetKilled(player)
		end
		lastDamager[player] = nil
	end)

	-- Detector de dano: registra o último atacante (igual GameManager_V6)
	character.ChildAdded:Connect(function(tool)
		if tool:IsA("Tool") then
			local handle = tool:FindFirstChild("Handle")
			if handle then
				handle.Touched:Connect(function(hit)
					if hit and hit.Parent then
						local hitHumanoid = hit.Parent:FindFirstChild("Humanoid")
						if hitHumanoid and hit.Parent ~= character then
							local victim = Players:GetPlayerFromCharacter(hit.Parent)
							if victim and victim ~= player then
								lastDamager[victim] = player
								task.wait(CONFIG.DAMAGE_MEMORY)
								if lastDamager[victim] == player then
									lastDamager[victim] = nil
								end
							end
						end
					end
				end)
			end
		end
	end)
end

local function hookPlayer(player)
	player.CharacterAdded:Connect(function(character)
		hookCharacter(player, character)
	end)
	if player.Character then
		hookCharacter(player, player.Character)
	end

	-- Mandar o estado atual do alvo para quem acabou de entrar
	task.delay(3, function()
		if player.Parent then
			wantedUpdateRemote:FireClient(player, buildTargetPayload())
		end
	end)
end

Players.PlayerAdded:Connect(hookPlayer)
for _, p in ipairs(Players:GetPlayers()) do
	hookPlayer(p)
end

Players.PlayerRemoving:Connect(function(player)
	lastDamager[player] = nil
	for victim, attacker in pairs(lastDamager) do
		if attacker == player then
			lastDamager[victim] = nil
		end
	end
	if currentTarget == player then
		setTarget(nil)
		task.delay(2, recomputeTarget)
	end
end)

-- =====================================
-- LOOP DE RECÁLCULO DO ALVO
-- =====================================

task.spawn(function()
	while true do
		task.wait(CONFIG.WANTED_REFRESH)
		recomputeTarget()
	end
end)

-- =====================================
-- API GLOBAL
-- =====================================

_G.WantedSystem = {
	getTarget = function()
		return currentTarget
	end,
	getStars = function()
		return currentStars
	end,
	forceRecompute = function()
		recomputeTarget()
	end,
}

print([[
╔════════════════════════════════════════════════════╗
║   🎯 WANTED SYSTEM SERVER V2 — CAÇADA + ESTRELAS  ║
╠════════════════════════════════════════════════════╣
║  * Maior bounty vira o ALVO "PROCURADO"           ║
║  * Níveis 1–5 estrelas por faixa de bounty        ║
║  * Mais estrelas = recompensa maior               ║
║  * Bússola que aponta o alvo é no cliente         ║
╚════════════════════════════════════════════════════╝
]])
