-- ============================================
-- CHARACTER LEVEL SERVER V1 — NÍVEL POR PERSONAGEM
-- Coloque em ServerScriptService
-- Nome: "CharacterLevelServer"
-- DEPENDE DE: DataManager V7 (_G.PlayerDataManager)
-- SCRIPT NOVO — não substitui nada
-- ============================================
-- FUNÇÃO:
-- • É o DONO da curva de XP, do teto de nível e de quantos slots de
--   passiva cada nível libera. O DataManager V7 só ARMAZENA
--   (mesma divisão que já existe entre MissionSystemServer e
--   DataManager: lá as missões, aqui o nível).
-- • Nível é POR PERSONAGEM (decisão fechada) — o XP sempre vai pro
--   personagem EQUIPADO no momento.
--
-- FONTES DE XP (decisão fechada: kills/duelos + chefão/missões + dano):
--   1. Kills e duelos      -> leitura de stats (kills_total, duels_won)
--   2. Chefão e missões    -> stats (missions_completed, hunts) + API
--   3. Dano causado        -> monitor de HealthChanged + LastAttacker
--
-- REUTILIZAÇÃO (nada criado do zero):
-- • Polling de stats com diff -> padrão do MissionSystemServer V2
--   (ele já varre os stats a cada 3s e compara assinatura)
-- • Atribuição de dano via tag LastAttacker + HealthChanged ->
--   padrão do TeamDamageProtection V3 (protectHumanoid). Por isso
--   NÃO é preciso editar nenhuma Tool pra ganhar XP de dano.
-- • ensureRemote / banner / _G API -> padrão geral do projeto
--
-- ⚠️ NÃO dá dano nem vida direto. Nível concede ENERGIA e SLOTS de
--    passiva — quem aplica efeito é o PassiveSystemServer_V1 (próximo
--    script). Isso é proposital: nível dando dano bruto quebraria o
--    PvP contra quem entrou hoje.
-- ============================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Esperar o DataManager V7
repeat
	task.wait()
until _G.PlayerDataManager and _G.PlayerDataManager.getCharacterProgress

-- =====================================
-- CONFIGURAÇÃO (balanceamento)
-- =====================================

local CONFIG = {
	MAX_LEVEL = 30,

	-- Curva: XP necessário pra sair do nível N -> N+1
	-- XP_BASE + (nivel - 1) * XP_STEP
	XP_BASE = 100,
	XP_STEP = 50,

	-- Níveis que liberam slot de passiva (3 slots no total —
	-- de propósito: com mais que isso o malefício vira decoração)
	SLOT_UNLOCKS = { 1, 10, 20 },

	-- Energia (consumida por uso de Tool no EnergySystemServer_V1)
	ENERGY_BASE = 100,
	ENERGY_PER_LEVEL = 5,
	ENERGY_REGEN_BASE = 5, -- por segundo
	ENERGY_REGEN_PER_LEVEL = 0.15,

	-- XP por evento
	XP_PER_KILL = 25,
	XP_PER_DUEL_WIN = 60,
	XP_PER_MISSION = 40,
	XP_PER_HUNT = 35,

	-- XP por dano causado
	DAMAGE_PER_XP = 20, -- 20 de dano = 1 XP
	DAMAGE_XP_CAP_PER_MIN = 60, -- teto anti-farm
	SAME_TARGET_WINDOW = 60, -- segundos
	SAME_TARGET_SOFT_CAP = 200, -- dano no mesmo alvo antes de reduzir
	SAME_TARGET_PENALTY = 0.25, -- multiplicador após o soft cap

	POLL_INTERVAL = 3, -- igual ao MissionSystemServer
}

-- Stats que viram XP automaticamente (nome do stat -> XP por ponto)
local STAT_XP_SOURCES = {
	kills_total = CONFIG.XP_PER_KILL,
	duels_won = CONFIG.XP_PER_DUEL_WIN,
	missions_completed = CONFIG.XP_PER_MISSION,
	hunts = CONFIG.XP_PER_HUNT,
}

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

local getCharacterProgressRemote = ensureRemote("GetCharacterProgress", "RemoteFunction")
local characterLevelUp = ensureRemote("CharacterLevelUp", "RemoteEvent")
local characterXpGained = ensureRemote("CharacterXpGained", "RemoteEvent")

-- =====================================
-- ESTADO EM MEMÓRIA
-- =====================================

local statBaseline = {} -- [player][statName] = último valor lido
local pendingXp = {} -- XP ganho sem personagem equipado (fica guardado)
local damageXpMinute = {} -- [player] = {amount = n, resetAt = t}
local recentTargets = {} -- [player][victimUserId] = {damage = n, expiry = t}
local damageConnections = {} -- [player] = RBXScriptConnection

-- =====================================
-- CURVA DE NÍVEL
-- =====================================

local function getXpForLevel(level)
	level = math.max(1, math.floor(tonumber(level) or 1))
	if level >= CONFIG.MAX_LEVEL then
		return math.huge -- nível máximo não acumula mais
	end
	return CONFIG.XP_BASE + (level - 1) * CONFIG.XP_STEP
end

local function getSlotCount(level)
	level = math.max(1, math.floor(tonumber(level) or 1))
	local slots = 0
	for _, unlockLevel in ipairs(CONFIG.SLOT_UNLOCKS) do
		if level >= unlockLevel then
			slots = slots + 1
		end
	end
	return slots
end

local function getEnergyMax(level)
	level = math.max(1, math.floor(tonumber(level) or 1))
	return CONFIG.ENERGY_BASE + (level - 1) * CONFIG.ENERGY_PER_LEVEL
end

local function getEnergyRegen(level)
	level = math.max(1, math.floor(tonumber(level) or 1))
	return CONFIG.ENERGY_REGEN_BASE + (level - 1) * CONFIG.ENERGY_REGEN_PER_LEVEL
end

-- Próximo nível de desbloqueio de slot (pra GUI mostrar "faltam X")
local function getNextSlotLevel(level)
	for _, unlockLevel in ipairs(CONFIG.SLOT_UNLOCKS) do
		if level < unlockLevel then
			return unlockLevel
		end
	end
	return nil
end

-- =====================================
-- CONCESSÃO DE XP
-- =====================================

local function buildProgress(player, characterName)
	local raw = _G.PlayerDataManager.getCharacterProgress(player, characterName)
	if not raw then
		return nil
	end

	local needed = getXpForLevel(raw.level)
	local isMax = raw.level >= CONFIG.MAX_LEVEL

	return {
		name = raw.name,
		level = raw.level,
		xp = raw.xp,
		xpNeeded = isMax and 0 or needed,
		progress = isMax and 1 or math.clamp(raw.xp / needed, 0, 1),
		isMax = isMax,
		slots = getSlotCount(raw.level),
		nextSlotLevel = getNextSlotLevel(raw.level),
		energyMax = getEnergyMax(raw.level),
		energyRegen = getEnergyRegen(raw.level),
		passives = raw.passives,
		loadouts = raw.loadouts,
	}
end

-- Aplica a curva depois que o XP bruto entrou. Sobe quantos níveis
-- forem necessários, carregando a sobra pro próximo.
local function resolveLevelUps(player, characterName)
	local raw = _G.PlayerDataManager.getCharacterProgress(player, characterName)
	if not raw then
		return
	end

	local level = raw.level
	local xp = raw.xp
	local leveledUp = false
	local slotsBefore = getSlotCount(level)

	-- Já está no teto: zera o XP sobrando pra não inflar o save à toa
	if level >= CONFIG.MAX_LEVEL then
		if xp > 0 then
			_G.PlayerDataManager.setCharacterLevel(player, characterName, CONFIG.MAX_LEVEL, 0)
		end
		return false
	end

	while level < CONFIG.MAX_LEVEL do
		local needed = getXpForLevel(level)
		if xp < needed then
			break
		end
		xp = xp - needed
		level = level + 1
		leveledUp = true
	end

	if level >= CONFIG.MAX_LEVEL then
		level = CONFIG.MAX_LEVEL
		xp = 0
	end

	if not leveledUp then
		return false
	end

	_G.PlayerDataManager.setCharacterLevel(player, characterName, level, xp)

	local slotsAfter = getSlotCount(level)
	local newSlot = slotsAfter > slotsBefore

	characterLevelUp:FireClient(player, {
		characterName = characterName,
		level = level,
		newSlot = newSlot,
		slots = slotsAfter,
		energyMax = getEnergyMax(level),
	})

	print(
		string.format(
			"[LEVEL V1] %s subiu %s para o nível %d%s",
			player.Name,
			characterName,
			level,
			newSlot and " (+1 SLOT DE PASSIVA)" or ""
		)
	)

	-- Aviso no menu unificado: tem slot pra gastar
	if newSlot then
		task.spawn(function()
			_G.PlayerDataManager.savePlayerData(player)
		end)
	end

	return true
end

local function awardXpTo(player, characterName, amount, reason)
	amount = math.floor(tonumber(amount) or 0)
	if amount <= 0 or not characterName then
		return false
	end

	local ok = _G.PlayerDataManager.addCharacterXp(player, characterName, amount)
	if not ok then
		return false
	end

	characterXpGained:FireClient(player, {
		characterName = characterName,
		amount = amount,
		reason = reason or "combate",
	})

	resolveLevelUps(player, characterName)
	return true
end

-- XP vai sempre pro personagem EQUIPADO. Sem personagem equipado
-- (jogador no lobby), o XP fica guardado e entra ao equipar.
local function awardXp(player, amount, reason)
	amount = math.floor(tonumber(amount) or 0)
	if amount <= 0 then
		return false
	end

	local data = _G.PlayerDataManager.getPlayerData(player)
	local equipped = data and data.equippedCharacter

	if not equipped then
		pendingXp[player] = (pendingXp[player] or 0) + amount
		return false
	end

	return awardXpTo(player, equipped, amount, reason)
end

local function flushPendingXp(player)
	local amount = pendingXp[player]
	if not amount or amount <= 0 then
		return
	end

	local data = _G.PlayerDataManager.getPlayerData(player)
	if not data or not data.equippedCharacter then
		return
	end

	pendingXp[player] = nil
	awardXpTo(player, data.equippedCharacter, amount, "acumulado")
end

-- =====================================
-- FONTE 1 e 2: STATS (kills, duelos, missões, caçadas)
-- Padrão de polling com diff — reaproveitado do MissionSystemServer
-- =====================================

local function snapshotStats(player)
	local data = _G.PlayerDataManager.getPlayerData(player)
	if not data or not data.stats then
		return
	end

	statBaseline[player] = statBaseline[player] or {}
	for statName in pairs(STAT_XP_SOURCES) do
		statBaseline[player][statName] = data.stats[statName] or 0
	end
end

local function pollStats(player)
	local data = _G.PlayerDataManager.getPlayerData(player)
	if not data or not data.stats then
		return
	end

	local baseline = statBaseline[player]
	if not baseline then
		snapshotStats(player)
		return
	end

	for statName, xpPerPoint in pairs(STAT_XP_SOURCES) do
		local current = data.stats[statName] or 0
		local previous = baseline[statName] or 0
		local delta = current - previous

		if delta > 0 then
			baseline[statName] = current
			awardXp(player, delta * xpPerPoint, statName)
		elseif delta < 0 then
			-- Stat foi resetado (admin) — realinha sem dar XP
			baseline[statName] = current
		end
	end
end

-- =====================================
-- FONTE 3: DANO CAUSADO
-- Reaproveita a tag LastAttacker criada pelo TeamDamageProtection V3
-- =====================================

local function getDamageMultiplier(player, victimPlayer, damage)
	local now = os.time()

	-- Teto por minuto
	local minuteData = damageXpMinute[player]
	if not minuteData or now >= minuteData.resetAt then
		minuteData = { amount = 0, resetAt = now + 60 }
		damageXpMinute[player] = minuteData
	end
	if minuteData.amount >= CONFIG.DAMAGE_XP_CAP_PER_MIN then
		return 0
	end

	-- Retorno decrescente no mesmo alvo
	recentTargets[player] = recentTargets[player] or {}
	local key = victimPlayer.UserId
	local entry = recentTargets[player][key]

	if not entry or now >= entry.expiry then
		entry = { damage = 0, expiry = now + CONFIG.SAME_TARGET_WINDOW }
		recentTargets[player][key] = entry
	end

	entry.damage = entry.damage + damage

	if entry.damage > CONFIG.SAME_TARGET_SOFT_CAP then
		return CONFIG.SAME_TARGET_PENALTY
	end
	return 1
end

local function registerDamage(attacker, victimPlayer, damage)
	if not attacker or not victimPlayer or attacker == victimPlayer then
		return
	end
	damage = tonumber(damage) or 0
	if damage <= 0 then
		return
	end

	local multiplier = getDamageMultiplier(attacker, victimPlayer, damage)
	if multiplier <= 0 then
		return
	end

	local xp = math.floor((damage / CONFIG.DAMAGE_PER_XP) * multiplier)
	if xp <= 0 then
		return
	end

	local minuteData = damageXpMinute[attacker]
	if minuteData then
		local room = CONFIG.DAMAGE_XP_CAP_PER_MIN - minuteData.amount
		xp = math.min(xp, room)
		if xp <= 0 then
			return
		end
		minuteData.amount = minuteData.amount + xp
	end

	awardXp(attacker, xp, "dano")
end

local function monitorDamage(player, character)
	if damageConnections[player] then
		pcall(function()
			damageConnections[player]:Disconnect()
		end)
		damageConnections[player] = nil
	end

	local humanoid = character:WaitForChild("Humanoid", 10)
	if not humanoid then
		return
	end

	local lastHealth = humanoid.Health

	damageConnections[player] = humanoid.HealthChanged:Connect(function(health)
		-- Só conta QUEDA de vida (restauração do TeamDamageProtection
		-- é subida, então é ignorada automaticamente)
		if health >= lastHealth then
			lastHealth = health
			return
		end

		local damage = lastHealth - health
		lastHealth = health

		local tag = character:FindFirstChild("LastAttacker")
		local attacker = tag and tag.Value

		if attacker and attacker:IsA("Player") and attacker ~= player then
			registerDamage(attacker, player, damage)
		end
	end)
end

-- =====================================
-- EVENTOS DE JOGADOR
-- =====================================

local function onPlayerAdded(player)
	-- Espera os dados carregarem antes de tirar a foto dos stats,
	-- senão o baseline sai zerado e o jogador ganharia XP retroativo
	task.spawn(function()
		local timeout = 0
		while not _G.PlayerDataManager.getPlayerData(player) and timeout < 20 do
			task.wait(0.5)
			timeout = timeout + 0.5
		end
		snapshotStats(player)
	end)

	player.CharacterAdded:Connect(function(character)
		monitorDamage(player, character)
		task.wait(1)
		flushPendingXp(player)
	end)

	if player.Character then
		monitorDamage(player, player.Character)
	end
end

local function onPlayerRemoving(player)
	if damageConnections[player] then
		pcall(function()
			damageConnections[player]:Disconnect()
		end)
	end
	damageConnections[player] = nil
	statBaseline[player] = nil
	pendingXp[player] = nil
	damageXpMinute[player] = nil
	recentTargets[player] = nil
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)

for _, player in ipairs(Players:GetPlayers()) do
	onPlayerAdded(player)
end

-- =====================================
-- LOOP DE POLLING
-- =====================================

task.spawn(function()
	while true do
		task.wait(CONFIG.POLL_INTERVAL)
		for _, player in ipairs(Players:GetPlayers()) do
			pcall(pollStats, player)
			pcall(flushPendingXp, player)
		end
	end
end)

-- =====================================
-- REMOTE: CONSULTA DE PROGRESSO
-- =====================================

getCharacterProgressRemote.OnServerInvoke = function(player, characterName)
	-- Sem nome = devolve o progresso de TODOS os personagens do
	-- jogador (é assim que a aba do inventário vai montar a lista)
	if type(characterName) ~= "string" then
		local data = _G.PlayerDataManager.getPlayerData(player)
		if not data then
			return {}
		end

		local list = {}
		for _, charObj in ipairs(data.ownedCharacters) do
			local progress = buildProgress(player, charObj.name)
			if progress then
				table.insert(list, progress)
			end
		end
		return list
	end

	return buildProgress(player, characterName)
end

-- =====================================
-- API GLOBAL
-- =====================================

_G.CharacterLevel = {
	CONFIG = CONFIG,

	getXpForLevel = getXpForLevel,
	getSlotCount = getSlotCount,
	getEnergyMax = getEnergyMax,
	getEnergyRegen = getEnergyRegen,

	getProgress = buildProgress,

	-- Usado por qualquer sistema: chefão, conquistas, eventos
	-- Ex.: _G.CharacterLevel.awardXp(player, 500, "chefao")
	awardXp = awardXp,
	awardXpTo = awardXpTo,

	-- Usado por Tools que queiram creditar dano manualmente
	registerDamage = registerDamage,

	-- Quantos slots o personagem equipado tem agora (o
	-- PassiveSystemServer_V1 usa isto pra validar a escolha)
	getEquippedSlots = function(player)
		local data = _G.PlayerDataManager.getPlayerData(player)
		if not data or not data.equippedCharacter then
			return 0
		end
		local raw = _G.PlayerDataManager.getCharacterProgress(player, data.equippedCharacter)
		if not raw then
			return 0
		end
		return getSlotCount(raw.level)
	end,
}

-- =====================================
-- DEBUG
-- =====================================

_G.DebugCharacterLevel = function(playerName)
	local player = Players:FindFirstChild(playerName)
	if not player then
		print("❌ Jogador não encontrado")
		return
	end

	local data = _G.PlayerDataManager.getPlayerData(player)
	if not data then
		print("❌ Dados não carregados")
		return
	end

	print("\n========== DEBUG CHARACTER LEVEL V1 ==========")
	print(string.format("Jogador: %s", player.Name))
	print(string.format("Equipado: %s", data.equippedCharacter or "Nenhum"))
	print(string.format("XP pendente: %d", pendingXp[player] or 0))

	for _, charObj in ipairs(data.ownedCharacters) do
		local p = buildProgress(player, charObj.name)
		if p then
			print(
				string.format(
					"  %s | Nv %d | XP %d/%s | Slots %d | Energia %d",
					p.name,
					p.level,
					p.xp,
					p.isMax and "MAX" or tostring(p.xpNeeded),
					p.slots,
					p.energyMax
				)
			)
		end
	end
	print("=====================================\n")
end

print([[
╔══════════════════════════════════════════════════════╗
║  CHARACTER LEVEL SERVER V1 — CARREGADO              ║
╠══════════════════════════════════════════════════════╣
║  SCRIPT NOVO (não substitui nada)                    ║
║  DEPENDE DE: DataManager V7                          ║
╠══════════════════════════════════════════════════════╣
║  * Nível POR PERSONAGEM (1 a 30)                     ║
║  * Curva: 100 + (nivel-1)*50                         ║
║  * Slots de passiva liberados nos níveis 1 / 10 / 20 ║
║  * XP: kills, duelos, missões, caçadas e DANO        ║
║  * Anti-farm: teto de 60 XP/min por dano +           ║
║    retorno decrescente no mesmo alvo (60s)           ║
║  * Nível NÃO dá dano — dá energia e slots            ║
╠══════════════════════════════════════════════════════╣
║  DEBUG: _G.DebugCharacterLevel("NomeJogador")        ║
╚══════════════════════════════════════════════════════╝
]])
