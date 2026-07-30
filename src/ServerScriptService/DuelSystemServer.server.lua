-- ============================================
-- DUEL SYSTEM SERVER V2 — ARENA + APOSTA + ISOLAMENTO
-- Coloque em ServerScriptService
-- Nome: "DuelSystemServer"
-- SUBSTITUI: DuelSystemServer V1
-- ============================================
-- (V2) EVOLUÇÕES sobre o V1:
-- • ARENA DEDICADA: os dois são teleportados para uma plataforma
--   com paredes (não dá pra cair/sair). Construída 1x.
-- • ISOLAMENTO DE DANO: só os dois se machucam. Rastreio os
--   toques do OPONENTE (Handle.Touched) e, no HealthChanged,
--   RESTAURO qualquer dano que não veio do oponente — mesmo
--   mecanismo REUTILIZADO do TeamDamageProtection_V4, escopado
--   ao duelo (não toca no combate dos outros).
-- • APOSTA DE MOEDAS: no aceite, a aposta sai dos dois (escrow);
--   o vencedor leva o pote. Empate/cancelar/sair-antes = REEMBOLSO.
--   (manuseio de moedas REUTILIZADO do TradeSystemServer_V1)
-- • Só duela quem está FORA da zona segura (com personagem
--   equipado) — usa a tag "InSafeZone" do SpawnSystem_V8.
-- • Sobreviventes voltam à posição que estavam antes do duelo.
--
-- MANTÉM do V1: convite (pendingRequests+GUID+timeout), contagem
-- 3-2-1-LUTE, primeiro a morrer perde, empate por tempo, sair =
-- derrota, bloqueio de duelo entre colegas (_G.IsTeammate),
-- ensureRemote, e a API do DataManager_V4.
-- ============================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local CONFIG = {
	DUEL_REQUEST_TIMEOUT = 20,
	DUEL_TIME = 120,
	DUEL_COOLDOWN = 5,
	WIN_BOUNTY = 15, -- bounty ao vencer (sempre)
	WIN_COINS = 100, -- moedas ao vencer SEM aposta
	MAX_BET = 100000,
	ISOLATION_WINDOW = 1.5, -- s: janela p/ considerar um golpe do oponente
	ARENA_CENTER = Vector3.new(0, 2000, 0), -- bem acima de tudo
	ARENA_HALF = 30, -- meia-largura do piso
	ARENA_WALL_H = 40, -- altura das paredes
}

repeat
	task.wait()
until _G.PlayerDataManager

local PDM = _G.PlayerDataManager

-- =====================================
-- REMOTES (padrão REUTILIZADO do TradeSystemServer_V1)
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

local requestDuelRemote = ensureRemote("RequestDuel", "RemoteFunction")
local duelInviteRemote = ensureRemote("DuelInvite", "RemoteEvent")
local respondToDuelRemote = ensureRemote("RespondToDuel", "RemoteEvent")
local duelCountdownRemote = ensureRemote("DuelCountdown", "RemoteEvent")
local duelResultRemote = ensureRemote("DuelResult", "RemoteEvent")

-- =====================================
-- ARENA (construída 1x)
-- =====================================

local arenaSpawnA, arenaSpawnB

local function buildArena()
	local center = CONFIG.ARENA_CENTER
	local half = CONFIG.ARENA_HALF

	local old = workspace:FindFirstChild("DuelArena")
	if old then
		old.Parent = nil
	end

	local model = Instance.new("Model")
	model.Name = "DuelArena"
	model.Parent = workspace

	-- Piso
	local floor = Instance.new("Part")
	floor.Name = "ArenaFloor"
	floor.Size = Vector3.new(half * 2, 2, half * 2)
	floor.Position = center
	floor.Anchored = true
	floor.Material = Enum.Material.Neon
	floor.Color = Color3.fromRGB(20, 10, 30)
	floor.TopSurface = Enum.SurfaceType.Smooth
	floor.Parent = model

	local glow = Instance.new("PointLight")
	glow.Brightness = 2
	glow.Range = 60
	glow.Color = Color3.fromRGB(255, 80, 0)
	glow.Parent = floor

	-- Paredes (ForceField, sólidas, altas o bastante p/ não pular fora)
	local wallDefs = {
		{ pos = Vector3.new(0, CONFIG.ARENA_WALL_H / 2, half), size = Vector3.new(half * 2, CONFIG.ARENA_WALL_H, 2) },
		{ pos = Vector3.new(0, CONFIG.ARENA_WALL_H / 2, -half), size = Vector3.new(half * 2, CONFIG.ARENA_WALL_H, 2) },
		{ pos = Vector3.new(half, CONFIG.ARENA_WALL_H / 2, 0), size = Vector3.new(2, CONFIG.ARENA_WALL_H, half * 2) },
		{ pos = Vector3.new(-half, CONFIG.ARENA_WALL_H / 2, 0), size = Vector3.new(2, CONFIG.ARENA_WALL_H, half * 2) },
	}
	for i, def in ipairs(wallDefs) do
		local wall = Instance.new("Part")
		wall.Name = "ArenaWall" .. i
		wall.Size = def.size
		wall.Position = center + def.pos
		wall.Anchored = true
		wall.CanCollide = true
		wall.Transparency = 0.4
		wall.Material = Enum.Material.ForceField
		wall.Color = Color3.fromRGB(255, 80, 0)
		wall.Parent = model
	end

	-- Pontos de spawn (lados opostos, virados um pro outro)
	local posA = center + Vector3.new(0, 5, half - 8)
	local posB = center + Vector3.new(0, 5, -(half - 8))
	arenaSpawnA = CFrame.lookAt(posA, Vector3.new(center.X, posA.Y, center.Z))
	arenaSpawnB = CFrame.lookAt(posB, Vector3.new(center.X, posB.Y, center.Z))

	print("[DUEL V2] ✓ Arena construída em " .. tostring(center))
end

buildArena()

-- =====================================
-- ESTADO
-- =====================================

local pendingRequests = {} -- [id]     = { from, to, expires, bet }
local activeDuels = {} -- [player] = session
local duelCooldown = {} -- [player] = os.time()

-- =====================================
-- HELPERS
-- =====================================

local function getLivingHumanoid(plr)
	local char = plr and plr.Character
	if not char then
		return nil
	end
	local hum = char:FindFirstChildOfClass("Humanoid")
	if hum and hum.Health > 0 then
		return hum
	end
	return nil
end

local function isInSafeZone(plr)
	return plr.Character ~= nil and plr.Character:FindFirstChild("InSafeZone") ~= nil
end

local function getCoins(plr)
	local d = PDM.getPlayerData(plr)
	return d and d.coins or 0
end

local function otherDuelist(session, player)
	return (session.a == player) and session.b or session.a
end

local function getHRP(plr)
	return plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
end

local function disconnectSession(session)
	if session.conns then
		for _, c in ipairs(session.conns) do
			pcall(function()
				c:Disconnect()
			end)
		end
	end
	session.conns = {}
end

local function clearDuel(session)
	disconnectSession(session)
	activeDuels[session.a] = nil
	activeDuels[session.b] = nil
	session.active = false
	session.aborted = true
end

-- Aposta: liquida (vencedor leva o pote) ou reembolsa (winner = nil)
local function settleBets(session, winner)
	if session.betsSettled then
		return
	end
	session.betsSettled = true
	if session.bet <= 0 then
		return
	end
	if winner then
		if winner.Parent then
			PDM.updateCoins(winner, session.pot)
			PDM.savePlayerData(winner)
		end
	else
		for _, p in ipairs({ session.a, session.b }) do
			if p.Parent then
				PDM.updateCoins(p, session.bet)
				PDM.savePlayerData(p)
			end
		end
	end
end

local function returnHome(session, plr)
	local cf = session.returnCFrame[plr]
	local hrp = getHRP(plr)
	if cf and hrp and getLivingHumanoid(plr) then
		hrp.CFrame = cf
		hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
	end
end

-- =====================================
-- FIM / CANCELAMENTO
-- =====================================

local function finishDuel(session, winner, loser, reason)
	if session.finished then
		return
	end
	session.finished = true
	clearDuel(session)
	duelCooldown[session.a] = os.time()
	duelCooldown[session.b] = os.time()

	-- Empate
	if not winner then
		settleBets(session, nil) -- reembolsa
		for _, p in ipairs({ session.a, session.b }) do
			if p.Parent then
				PDM.incrementStat(p, "duels_played", 1)
				PDM.savePlayerData(p)
				returnHome(session, p)
				local msg = session.bet > 0 and ("Aposta de " .. session.bet .. " devolvida.") or ""
				duelResultRemote:FireClient(p, "draw", otherDuelist(session, p).Name, msg)
			end
		end
		print(string.format("[DUEL V2] Empate: %s vs %s (%s)", session.a.Name, session.b.Name, reason or ""))
		return
	end

	-- Vitória
	settleBets(session, winner) -- vencedor leva o pote
	if winner.Parent then
		PDM.updateBounty(winner, CONFIG.WIN_BOUNTY)
		if session.bet <= 0 then
			PDM.updateCoins(winner, CONFIG.WIN_COINS)
		end
		PDM.incrementStat(winner, "duels_won", 1)
		PDM.incrementStat(winner, "duels_played", 1)
		PDM.savePlayerData(winner)
		returnHome(session, winner)

		local reward = session.bet > 0 and string.format("+%d 💰 (pote)  +%d ⚔️", session.pot, CONFIG.WIN_BOUNTY)
			or string.format("+%d 💰  +%d ⚔️", CONFIG.WIN_COINS, CONFIG.WIN_BOUNTY)
		duelResultRemote:FireClient(winner, "win", loser and loser.Name or "?", reward)
	end
	if loser and loser.Parent then
		PDM.incrementStat(loser, "duels_played", 1)
		PDM.savePlayerData(loser)
		local msg = session.bet > 0 and ("Você perdeu a aposta de " .. session.bet .. " 💰.") or ""
		duelResultRemote:FireClient(loser, "lose", winner.Name, msg)
	end

	print(string.format("[DUEL V2] %s venceu %s (%s)", winner.Name, loser and loser.Name or "?", reason or ""))
end

local function cancelDuel(session, message)
	if session.finished then
		return
	end
	session.finished = true
	clearDuel(session)
	settleBets(session, nil) -- reembolsa a aposta
	for _, p in ipairs({ session.a, session.b }) do
		if p.Parent then
			returnHome(session, p)
			duelResultRemote:FireClient(p, "cancel", "", message)
		end
	end
	print("[DUEL V2] Duelo cancelado: " .. tostring(message))
end

-- =====================================
-- ISOLAMENTO DE DANO (escopado ao duelo)
-- REUTILIZA o mecanismo do TeamDamageProtection_V4 (restaurar HP),
-- mas só restaura dano que NÃO veio do oponente.
-- =====================================

local function hookIsolation(session, defender, attacker)
	local dChar = defender.Character
	local aChar = attacker.Character
	if not dChar or not aChar then
		return
	end
	local dHum = dChar:FindFirstChildOfClass("Humanoid")
	if not dHum then
		return
	end

	session.lastHealth[defender] = dHum.Health
	session.lastOppHit[defender] = 0

	-- Marca quando o OPONENTE (attacker) acerta o defender
	local function markIfHitsDefender(hit)
		if hit and hit:IsDescendantOf(dChar) then
			session.lastOppHit[defender] = os.clock()
		end
	end

	local function hookTool(tool)
		if tool:IsA("Tool") then
			local handle = tool:FindFirstChild("Handle")
			if handle then
				table.insert(session.conns, handle.Touched:Connect(markIfHitsDefender))
			end
		end
	end

	for _, child in ipairs(aChar:GetChildren()) do
		hookTool(child)
	end
	table.insert(session.conns, aChar.ChildAdded:Connect(hookTool))

	-- Restaura dano que não veio do oponente
	table.insert(
		session.conns,
		dHum.HealthChanged:Connect(function(newHealth)
			if not session.active then
				return
			end
			local prev = session.lastHealth[defender] or newHealth
			if newHealth < prev then
				local fromOpponent = (os.clock() - (session.lastOppHit[defender] or 0)) <= CONFIG.ISOLATION_WINDOW
				if fromOpponent then
					session.lastHealth[defender] = newHealth -- golpe válido do oponente
				else
					dHum.Health = prev -- dano externo/ambiente -> anula
				end
			else
				session.lastHealth[defender] = newHealth
			end
		end)
	)
end

-- =====================================
-- INICIAR DUELO
-- =====================================

local function startDuel(session)
	-- Ambos vivos e fora da zona segura (combate liberado)
	if not getLivingHumanoid(session.a) or not getLivingHumanoid(session.b) then
		cancelDuel(session, "Duelo cancelado: alguém não estava pronto.")
		return
	end

	-- Guardar posição de origem p/ voltar depois
	for _, p in ipairs({ session.a, session.b }) do
		local hrp = getHRP(p)
		session.returnCFrame[p] = hrp and hrp.CFrame or nil
	end

	-- Teleportar para a arena (lados opostos)
	local hrpA = getHRP(session.a)
	local hrpB = getHRP(session.b)
	if hrpA then
		hrpA.CFrame = arenaSpawnA
		hrpA.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
	end
	if hrpB then
		hrpB.CFrame = arenaSpawnB
		hrpB.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
	end

	-- Contagem 3-2-1-LUTE
	task.spawn(function()
		for _, n in ipairs({ 3, 2, 1, 0 }) do
			if session.aborted then
				return
			end
			for _, p in ipairs({ session.a, session.b }) do
				if p.Parent then
					duelCountdownRemote:FireClient(p, n, otherDuelist(session, p).Name)
				end
			end
			task.wait(1)
		end

		if session.aborted then
			return
		end
		if not getLivingHumanoid(session.a) or not getLivingHumanoid(session.b) then
			cancelDuel(session, "Duelo cancelado: alguém não estava pronto.")
			return
		end

		session.active = true

		-- Isolamento de dano (cada um protegido de todos menos do oponente)
		hookIsolation(session, session.a, session.b)
		hookIsolation(session, session.b, session.a)

		-- Vitória: primeiro a morrer perde
		for _, duelist in ipairs({ session.a, session.b }) do
			local hum = getLivingHumanoid(duelist)
			if hum then
				table.insert(
					session.conns,
					hum.Died:Connect(function()
						if not session.active then
							return
						end
						finishDuel(session, otherDuelist(session, duelist), duelist, "morte")
					end)
				)
			end
		end

		-- Tempo limite -> empate
		task.delay(CONFIG.DUEL_TIME, function()
			if session.active and not session.finished then
				finishDuel(session, nil, nil, "tempo esgotado")
			end
		end)
	end)
end

-- =====================================
-- PEDIDO DE DUELO (REUTILIZADO do TradeSystemServer_V1 + aposta)
-- =====================================

local function requestDuel(player, targetName, betAmount)
	local target = Players:FindFirstChild(tostring(targetName))
	local bet = math.clamp(math.floor(tonumber(betAmount) or 0), 0, CONFIG.MAX_BET)

	if not target then
		return false, "Jogador não encontrado!"
	end
	if target == player then
		return false, "Você não pode duelar consigo mesmo!"
	end
	if activeDuels[player] then
		return false, "Você já está em um duelo!"
	end
	if activeDuels[target] then
		return false, target.Name .. " já está em um duelo!"
	end
	if _G.IsTeammate and _G.IsTeammate(player, target) then
		return false, "Você não pode duelar um colega de time!"
	end

	-- (V2) Precisam estar no MAPA (fora da zona segura) p/ poder lutar
	if isInSafeZone(player) or not getLivingHumanoid(player) then
		return false, "Equipe um personagem e vá ao mapa para duelar!"
	end
	if isInSafeZone(target) or not getLivingHumanoid(target) then
		return false, target.Name .. " não está no mapa pronto para duelar!"
	end

	-- (V2) Aposta: os dois precisam ter moedas suficientes
	if bet > 0 then
		if getCoins(player) < bet then
			return false, "Você não tem " .. bet .. " moedas para apostar!"
		end
		if getCoins(target) < bet then
			return false, target.Name .. " não tem " .. bet .. " moedas para essa aposta!"
		end
	end

	local now = os.time()
	if duelCooldown[player] and now - duelCooldown[player] < CONFIG.DUEL_COOLDOWN then
		return false, "Aguarde alguns segundos antes de duelar de novo!"
	end

	for _, req in pairs(pendingRequests) do
		if req.from == player and req.to == target and req.expires > now then
			return false, "Desafio já enviado!"
		end
	end

	local requestId = HttpService:GenerateGUID(false)
	pendingRequests[requestId] = {
		from = player,
		to = target,
		expires = now + CONFIG.DUEL_REQUEST_TIMEOUT,
		bet = bet,
	}

	duelInviteRemote:FireClient(target, player.Name, bet)

	task.spawn(function()
		task.wait(CONFIG.DUEL_REQUEST_TIMEOUT)
		if pendingRequests[requestId] then
			pendingRequests[requestId] = nil
			if player.Parent then
				duelResultRemote:FireClient(player, "cancel", "", "Desafio para " .. target.Name .. " expirou.")
			end
		end
	end)

	local betTxt = bet > 0 and (" (aposta " .. bet .. " 💰)") or ""
	print(string.format("[DUEL V2] Desafio: %s -> %s%s", player.Name, target.Name, betTxt))
	return true, "Desafio enviado para " .. target.Name .. "!" .. betTxt
end

requestDuelRemote.OnServerInvoke = requestDuel

respondToDuelRemote.OnServerEvent:Connect(function(player, accepted)
	local validRequest = nil
	for id, req in pairs(pendingRequests) do
		if req.to == player and req.expires > os.time() then
			validRequest = req
			pendingRequests[id] = nil
			break
		end
	end

	if not validRequest then
		return
	end

	local from = validRequest.from
	local bet = validRequest.bet or 0

	if not accepted then
		if from.Parent then
			duelResultRemote:FireClient(from, "cancel", "", player.Name .. " recusou o duelo.")
		end
		return
	end

	if not from.Parent or activeDuels[from] or activeDuels[player] then
		duelResultRemote:FireClient(player, "cancel", "", "O duelo não está mais disponível.")
		return
	end

	-- (V2) Revalidar prontidão e moedas no aceite
	if isInSafeZone(from) or not getLivingHumanoid(from) or isInSafeZone(player) or not getLivingHumanoid(player) then
		duelResultRemote:FireClient(player, "cancel", "", "Alguém não está mais pronto para o duelo.")
		duelResultRemote:FireClient(from, "cancel", "", "Alguém não está mais pronto para o duelo.")
		return
	end
	if bet > 0 and (getCoins(from) < bet or getCoins(player) < bet) then
		duelResultRemote:FireClient(player, "cancel", "", "Moedas insuficientes para a aposta.")
		duelResultRemote:FireClient(from, "cancel", "", "Moedas insuficientes para a aposta.")
		return
	end

	local session = {
		id = HttpService:GenerateGUID(false),
		a = from,
		b = player,
		active = false,
		finished = false,
		aborted = false,
		conns = {},
		bet = bet,
		pot = bet * 2,
		betsSettled = false,
		returnCFrame = {},
		lastHealth = {},
		lastOppHit = {},
	}
	activeDuels[from] = session
	activeDuels[player] = session

	-- (V2) ESCROW: tira a aposta dos dois agora
	if bet > 0 then
		PDM.updateCoins(from, -bet)
		PDM.updateCoins(player, -bet)
		PDM.savePlayerData(from)
		PDM.savePlayerData(player)
	end

	print(string.format("[DUEL V2] Duelo aceito: %s vs %s (pote %d)", from.Name, player.Name, session.pot))
	startDuel(session)
end)

-- =====================================
-- SAÍDA DE JOGADOR
-- =====================================

Players.PlayerRemoving:Connect(function(player)
	for id, req in pairs(pendingRequests) do
		if req.from == player or req.to == player then
			pendingRequests[id] = nil
		end
	end

	local session = activeDuels[player]
	if session then
		local other = otherDuelist(session, player)
		if session.active and not session.finished then
			-- Sair valendo = derrota; o outro vence (e leva o pote)
			finishDuel(session, other, player, "desistência")
		else
			-- Saiu antes de começar -> cancela e reembolsa
			cancelDuel(session, player.Name .. " saiu — duelo cancelado.")
		end
	end

	duelCooldown[player] = nil
end)

print([[
╔════════════════════════════════════════════════════╗
║   ⚔️ DUEL SYSTEM SERVER V2 — ARENA + APOSTA       ║
╠════════════════════════════════════════════════════╣
║  * Arena dedicada com paredes (1x)                ║
║  * Só os dois se machucam (isolamento de dano)    ║
║  * Aposta de moedas (escrow + reembolso)          ║
║  * Só duela fora da zona segura | sair = derrota  ║
╚════════════════════════════════════════════════════╝
]])
