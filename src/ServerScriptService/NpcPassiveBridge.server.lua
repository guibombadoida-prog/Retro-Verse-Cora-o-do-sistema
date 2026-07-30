-- ============================================
-- NPC PASSIVE BRIDGE V2 — PASSIVAS E XP CONTRA NPC
-- Coloque em ServerScriptService
-- Nome: "NpcPassiveBridge"
-- DEPENDE DE: DataManager V7, CharacterLevelServer V1,
--             PassiveSystemServer V3, StatService V1,
--             EnergySystemServer V1
-- SUBSTITUI: NpcPassiveBridge V1
-- REMOVER:   NpcPassiveBridge V1
-- ============================================
-- (V2) ALTERAÇÕES — A DETECÇÃO MELHOROU:
--
-- • 🆕 TAG `creator` VIROU A FONTE PRINCIPAL. O V1 só sabia
--   adivinhar por proximidade ("quem estava mais perto quando o NPC
--   perdeu vida"), que é justamente a detecção ruim de que você
--   reclamou. Agora o script lê primeiro a tag `creator` que a arma
--   coloca no Humanoid do NPC — igual ao DamageAttribution V2 faz
--   com jogador. Isso é EXATO: não chuta, não confunde dois
--   jogadores lado a lado, e funciona a qualquer distância.
--   A proximidade virou só o plano B, quando não há tag nenhuma.
--
-- • 🆕 A conta de dano agora usa `StatService.computeDamage`, então
--   dano contra NPC respeita as mesmas regras do resto do jogo
--   (boost por classe, teto de resistência, teto por golpe) em vez
--   da conta paralela que o V1 tinha.
--
-- • 🆕 Lifesteal passa por `StatService.computeHealing`, então
--   Cura Recebida/Dada afeta o Vampírico contra NPC também.
--
-- ⚠️ NPC AINDA NÃO TEM ATRIBUTOS PRÓPRIOS. Ele não tem ficha no
--    StatService, então não tem resistência nem classe. Isso é o que
--    a ficha de NPC (tier, elemento, bonds) vai resolver quando o
--    mundo principal estiver pronto. Até lá, o NPC leva o dano
--    calculado só pelos atributos do ATACANTE.
-- ============================================
-- O PROBLEMA QUE ESTE SCRIPT RESOLVE:
-- O PassiveSystemServer e o CharacterLevelServer só enxergam
-- personagens de JOGADOR (ambos ligam em `player.CharacterAdded`).
-- NPC não é jogador, então até agora:
--   • matar/bater em NPC não dava XP nenhum;
--   • Vidro Trincado, Frenesi e Vampírico não faziam efeito em NPC;
--   • a Adrenalina não disparava ao matar NPC.
-- Este script é a ponte que liga os dois mundos.
--
-- ⚠️ ATRIBUIÇÃO DE DANO EM NPC — LEIA ISTO:
-- NPC não tem tag `LastAttacker` preenchida. O NpcSystem V2 resolve
-- isso com uma HEURÍSTICA: no momento em que o NPC perde vida, quem
-- levou o crédito é o jogador vivo MAIS PRÓXIMO dentro de um raio.
-- Este script REUTILIZA exatamente a mesma heurística, com o mesmo
-- raio (20 studs), pra que o crédito de XP bata com o crédito de
-- moedas/bounty que o NpcSystem já dá. Não é perfeito — dois
-- jogadores colados no mesmo NPC podem trocar de crédito — mas é
-- consistente com o que o jogo já faz hoje.
--
-- O QUE SE APLICA CONTRA NPC:
--   ✅ Vidro Trincado  -> +dano causado
--   ✅ Frenesi         -> +dano com pouca vida
--   ✅ Vampírico       -> cura ao bater no NPC
--   ✅ Adrenalina      -> dispara ao MATAR o NPC
--   ✅ Couraça / Vidro Trincado (defesa) -> dano do NPC no jogador
--      (isso é feito pelo PassiveSystemServer V2, não aqui)
--   ❌ Duelista        -> compara NÍVEL dos dois lados, e NPC não
--      tem nível. Fica neutro contra NPC, de propósito.
--
-- REUTILIZAÇÃO (nada criado do zero):
-- • isNPC / detecção por Workspace + CollectionService "NPC" /
--   heurística do atacante mais próximo / re-registro após respawn
--   ................................ NpcSystem V2
-- • Guarda `adjusting` contra laço de HealthChanged ... PassiveSystemServer V1
-- • awardXp / anti-farm por minuto ................... CharacterLevelServer V1
-- ============================================

local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")

repeat
	task.wait()
until _G.PlayerDataManager and _G.CharacterLevel and _G.PassiveSystem and _G.StatService

-- =====================================
-- CONFIGURAÇÃO
-- =====================================

local CONFIG = {
	-- Raio de atribuição: IGUAL ao do NpcSystem V2, pra o crédito de
	-- XP bater com o crédito de moedas
	ATTACK_RADIUS = 20,

	-- XP por dano causado ao NPC (mesma taxa do dano em jogador)
	DAMAGE_PER_XP = 20,

	-- XP ao MATAR o NPC = % da vida máxima dele.
	-- Segue a mesma filosofia do NpcSystem V2: NPC mais duro paga
	-- mais. NPC de 200 de vida = 20 XP de bônus.
	KILL_XP_HP_PERCENT = 10,
	MIN_KILL_XP = 5,

	-- ANTI-FARM: NPC respawna, então sem teto dá pra ficar num canto
	-- matando o mesmo zumbi fraco pra sempre.
	XP_CAP_PER_MIN = 90,

	-- Retorno decrescente no MESMO NPC dentro da janela
	SAME_NPC_WINDOW = 60,
	SAME_NPC_SOFT_CAP = 3, -- kills no mesmo NPC antes de reduzir
	SAME_NPC_PENALTY = 0.3,

	NPC_TAG = "NPC", -- mesma tag opcional que o NpcSystem V2 usa
}

-- =====================================
-- ESTADO
-- =====================================

local trackedNPCs = {} -- [model] = true
local npcConnections = {} -- [model] = { conexões }
local adjusting = {} -- [humanoid] = true (guarda de reentrância)
local xpMinute = {} -- [player] = {amount, resetAt}
local npcKillHistory = {} -- [player] = { [npcName] = {count, expiry} }
local attributionStats = {} -- (V2) conta de onde veio cada crédito

-- =====================================
-- ANTI-FARM
-- =====================================

local function getXpRoom(player)
	local now = os.time()
	local entry = xpMinute[player]

	if not entry or now >= entry.resetAt then
		entry = { amount = 0, resetAt = now + 60 }
		xpMinute[player] = entry
	end

	return math.max(0, CONFIG.XP_CAP_PER_MIN - entry.amount), entry
end

local function grantXp(player, amount, reason)
	amount = math.floor(tonumber(amount) or 0)
	if amount <= 0 then
		return 0
	end

	local room, entry = getXpRoom(player)
	if room <= 0 then
		return 0
	end

	amount = math.min(amount, room)
	entry.amount = entry.amount + amount

	_G.CharacterLevel.awardXp(player, amount, reason or "npc")
	return amount
end

-- Penalidade por matar o MESMO tipo de NPC repetidamente
local function getKillMultiplier(player, npcName)
	local now = os.time()
	npcKillHistory[player] = npcKillHistory[player] or {}

	local entry = npcKillHistory[player][npcName]
	if not entry or now >= entry.expiry then
		entry = { count = 0, expiry = now + CONFIG.SAME_NPC_WINDOW }
		npcKillHistory[player][npcName] = entry
	end

	entry.count = entry.count + 1

	if entry.count > CONFIG.SAME_NPC_SOFT_CAP then
		return CONFIG.SAME_NPC_PENALTY
	end
	return 1
end

-- =====================================
-- DETECÇÃO DE NPC (padrão do NpcSystem V2)
-- =====================================

local function isNPC(model)
	if typeof(model) ~= "Instance" then
		return false
	end
	if not model:IsA("Model") then
		return false
	end
	if Players:GetPlayerFromCharacter(model) then
		return false -- personagem de jogador
	end
	if not model:FindFirstChildWhichIsA("Humanoid") then
		return false
	end
	return true
end

local function isPlayerInSafeZone(player)
	if not player.Character then
		return true
	end
	return player.Character:FindFirstChild("InSafeZone") ~= nil
end

-- Jogador vivo mais próximo do NPC (heurística do NpcSystem V2)
local function findNearestAttacker(npcModel)
	local hrp = npcModel:FindFirstChild("HumanoidRootPart")
	if not hrp then
		return nil
	end

	local closest = nil
	local closestDist = CONFIG.ATTACK_RADIUS

	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		if character and not isPlayerInSafeZone(player) then
			local playerHrp = character:FindFirstChild("HumanoidRootPart")
			local playerHum = character:FindFirstChildOfClass("Humanoid")

			if playerHrp and playerHum and playerHum.Health > 0 then
				local dist = (playerHrp.Position - hrp.Position).Magnitude
				if dist <= closestDist then
					closest = player
					closestDist = dist
				end
			end
		end
	end

	return closest
end

-- =====================================
-- (V2) FONTE PRINCIPAL: TAG `creator`
-- =====================================
-- A convenção clássica do Roblox: a arma cria um ObjectValue
-- chamado "creator" dentro do Humanoid do alvo ANTES de aplicar o
-- dano. Isso é EXATO — não depende de distância nem de chute.
-- Mesmo mecanismo que o DamageAttribution V2 usa pra jogador.

local function readCreatorTag(humanoid)
	local tag = humanoid:FindFirstChild("creator")
	if not tag or not tag:IsA("ObjectValue") then
		return nil
	end

	local value = tag.Value
	if value and typeof(value) == "Instance" and value:IsA("Player") and value.Parent then
		return value
	end

	return nil
end

-- Decide quem levou o crédito: tag primeiro, proximidade depois
local function resolveAttacker(npcModel, humanoid)
	local fromTag = readCreatorTag(humanoid)
	if fromTag then
		return fromTag, "creator"
	end

	local nearest = findNearestAttacker(npcModel)
	if nearest then
		return nearest, "proximidade"
	end

	return nil, nil
end

-- =====================================
-- TAG DE ATACANTE NO NPC
-- =====================================
-- Deixa o NPC com o mesmo `LastAttacker` que os personagens de
-- jogador têm. Padroniza o NPC com o resto do jogo.

local function setLastAttacker(npcModel, player)
	local tag = npcModel:FindFirstChild("LastAttacker")
	if not tag then
		tag = Instance.new("ObjectValue")
		tag.Name = "LastAttacker"
		tag.Parent = npcModel
	end
	tag.Value = player
end

-- =====================================
-- APLICAÇÃO DAS PASSIVAS NO DANO AO NPC
-- =====================================
-- (V2) Só calcula o multiplicador CONDICIONAL aqui (Frenesi).
-- O resto (DamageBoost, boost por classe, tetos) é do StatService.

local function getConditionalMultiplier(attacker)
	local effects = _G.PassiveSystem.getEffects(attacker)
	if not effects then
		return 1, 0
	end

	local multiplier = 1

	-- Frenesi: bate mais com pouca vida
	if (effects.lowHpDamage or 0) > 0 then
		local character = attacker.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid and humanoid.MaxHealth > 0 then
			local ratio = humanoid.Health / humanoid.MaxHealth
			if ratio <= (effects.lowHpThreshold or 0.3) then
				multiplier = multiplier * (1 + effects.lowHpDamage)
			end
		end
	end

	-- Duelista NÃO entra: NPC não tem nível pra comparar

	return multiplier, effects.lifesteal or 0
end

local function applyLifesteal(attacker, damage, lifesteal)
	if lifesteal <= 0 or damage <= 0 then
		return
	end

	local character = attacker.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return
	end

	-- (V2) Passa pela conta oficial de cura, então Cura Recebida/Dada
	-- afeta o Vampírico contra NPC também
	local heal = _G.StatService.computeHealing(attacker, attacker, damage * lifesteal)
	humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + heal)
end

-- =====================================
-- REGISTRO DE NPC
-- =====================================

local registerNPC

local function unregisterNPC(model)
	if npcConnections[model] then
		for _, connection in ipairs(npcConnections[model]) do
			pcall(function()
				connection:Disconnect()
			end)
		end
	end
	npcConnections[model] = nil
	trackedNPCs[model] = nil
end

registerNPC = function(npcModel)
	if trackedNPCs[npcModel] then
		return
	end
	if not isNPC(npcModel) then
		return
	end

	local humanoid = npcModel:FindFirstChildWhichIsA("Humanoid")
	if not humanoid then
		return
	end

	trackedNPCs[npcModel] = true
	npcConnections[npcModel] = {}

	local lastHealth = humanoid.Health

	-- ---------- DANO NO NPC ----------
	table.insert(
		npcConnections[npcModel],
		humanoid.HealthChanged:Connect(function(health)
			-- Ignora a própria correção deste script
			if adjusting[humanoid] then
				lastHealth = health
				return
			end

			if health >= lastHealth then
				lastHealth = health
				return
			end

			local rawDamage = lastHealth - health
			lastHealth = health

			-- (V2) tag `creator` primeiro, proximidade só como plano B
			local attacker, source = resolveAttacker(npcModel, humanoid)
			if not attacker then
				return
			end

			attributionStats[source] = (attributionStats[source] or 0) + 1
			setLastAttacker(npcModel, attacker)

			local conditional, lifesteal = getConditionalMultiplier(attacker)

			-- (V2) Conta oficial. victim = nil porque NPC ainda não tem
			-- ficha de atributos — só o lado do atacante entra.
			local finalDamage = _G.StatService.computeDamage(
				attacker,
				nil,
				rawDamage * conditional,
				nil
			)

			-- Teto por golpe, medido na vida do NPC (o StatService não
			-- consegue fazer isso sozinho sem ficha do alvo)
			local cap = humanoid.MaxHealth * _G.StatService.CONFIG.MAX_HIT_PERCENT
			finalDamage = math.min(finalDamage, cap)

			local correction = rawDamage - finalDamage

			if math.abs(correction) > 0.01 then
				adjusting[humanoid] = true
				humanoid.Health = math.clamp(health + correction, 0, humanoid.MaxHealth)
				adjusting[humanoid] = false
				lastHealth = humanoid.Health
			end

			applyLifesteal(attacker, finalDamage, lifesteal)

			-- XP por dano
			local xp = math.floor(finalDamage / CONFIG.DAMAGE_PER_XP)
			if xp > 0 then
				grantXp(attacker, xp, "dano_npc")
			end
		end)
	)

	-- ---------- MORTE DO NPC ----------
	table.insert(
		npcConnections[npcModel],
		humanoid.Died:Connect(function()
			local npcMaxHealth = humanoid.MaxHealth
			local npcName = npcModel.Name

			-- (V2) Quem matou: tag `creator` do golpe final se existir,
			-- senão o último atacante que registramos
			local killer = readCreatorTag(humanoid)
			if not killer then
				local tag = npcModel:FindFirstChild("LastAttacker")
				killer = tag and tag.Value
			end

			if killer and typeof(killer) == "Instance" and killer:IsA("Player") and killer.Parent then
				local penalty = getKillMultiplier(killer, npcName)

				local killXp = math.max(
					CONFIG.MIN_KILL_XP,
					math.floor(npcMaxHealth * (CONFIG.KILL_XP_HP_PERCENT / 100))
				)
				killXp = math.floor(killXp * penalty)

				local granted = grantXp(killer, killXp, "kill_npc")

				-- Adrenalina: mesmo buff de matar jogador
				pcall(_G.PassiveSystem.triggerKillBuff, killer)

				if granted > 0 then
					print(
						string.format(
							"[NPC BRIDGE V2] %s matou '%s' -> +%d XP%s",
							killer.Name,
							npcName,
							granted,
							penalty < 1 and " (reduzido por repetição)" or ""
						)
					)
				end
			end

			unregisterNPC(npcModel)

			-- Re-registrar após respawn (padrão do NpcSystem V2).
			-- 9s > REREGISTER_DELAY do NpcSystem (8s), pra este script
			-- registrar depois que o NPC já voltou.
			task.delay(9, function()
				if npcModel.Parent then
					registerNPC(npcModel)
				end
			end)
		end)
	)
end

-- =====================================
-- VARREDURA E ESCUTA (padrão do NpcSystem V2)
-- =====================================

for _, model in ipairs(workspace:GetDescendants()) do
	if isNPC(model) then
		registerNPC(model)
	end
end

workspace.DescendantAdded:Connect(function(instance)
	if instance:IsA("Humanoid") then
		task.wait(0.5) -- deixa o Model terminar de montar
		local model = instance.Parent
		if model and isNPC(model) then
			registerNPC(model)
		end
	end
end)

-- Suporte à tag opcional do CollectionService (igual ao NpcSystem V2)
for _, model in ipairs(CollectionService:GetTagged(CONFIG.NPC_TAG)) do
	if isNPC(model) then
		registerNPC(model)
	end
end

CollectionService:GetInstanceAddedSignal(CONFIG.NPC_TAG):Connect(function(model)
	if isNPC(model) then
		registerNPC(model)
	end
end)

-- =====================================
-- LIMPEZA
-- =====================================

Players.PlayerRemoving:Connect(function(player)
	xpMinute[player] = nil
	npcKillHistory[player] = nil
end)

-- =====================================
-- API GLOBAL
-- =====================================

_G.NpcPassiveBridge = {
	CONFIG = CONFIG,

	registerNPC = function(model)
		registerNPC(model)
	end,

	getCount = function()
		local count = 0
		for _ in pairs(trackedNPCs) do
			count = count + 1
		end
		return count
	end,
}

-- =====================================
-- DEBUG
-- =====================================

_G.DebugNpcBridge = function(playerName)
	print("\n========== DEBUG NPC BRIDGE V2 ==========")
	print(string.format("NPCs monitorados: %d", _G.NpcPassiveBridge.getCount()))
	print(string.format(
		"Crédito de dano: creator=%d | proximidade=%d",
		attributionStats.creator or 0,
		attributionStats["proximidade"] or 0
	))
	if (attributionStats.creator or 0) == 0 and (attributionStats["proximidade"] or 0) > 0 then
		print("  (suas armas não usam a tag 'creator' contra NPC — está no plano B)")
	end

	if playerName then
		local player = Players:FindFirstChild(playerName)
		if player then
			local room = getXpRoom(player)
			print(string.format("%s | XP de NPC disponível neste minuto: %d", player.Name, room))

			local history = npcKillHistory[player]
			if history then
				for npcName, entry in pairs(history) do
					print(string.format("  '%s': %d kill(s) na janela", npcName, entry.count))
				end
			end
		end
	end
	print("=====================================\n")
end

print([[
╔══════════════════════════════════════════════════════╗
║  NPC PASSIVE BRIDGE V2 — CARREGADO                  ║
╠══════════════════════════════════════════════════════╣
║  SUBSTITUI: NpcPassiveBridge V1                      ║
║  REMOVER:   NpcPassiveBridge V1                      ║
║  NpcSystem V2 continua INTOCADO                      ║
║  DEPENDE DE: PassiveSystemServer V3 + StatService    ║
╠══════════════════════════════════════════════════════╣
║  * XP por dano E por kill de NPC                     ║
║  * XP de kill = 10% da vida máxima do NPC            ║
║  * Crédito pela tag 'creator' (exato), não por chute ║
║  * Vidro Trincado / Frenesi / Vampírico contra NPC   ║
║  * Adrenalina dispara ao matar NPC                   ║
║  * Duelista fica neutro (NPC não tem nível)          ║
║  * Anti-farm: 90 XP/min + penalidade por repetição   ║
╠══════════════════════════════════════════════════════╣
║  DEBUG: _G.DebugNpcBridge("NomeJogador")             ║
╚══════════════════════════════════════════════════════╝
]])
