-- ============================================
-- STAT SERVICE V4 — VIDA DO DESPERTAR SEGUE A FORMA
-- ============================================
-- (V4) A vida do Despertar deixou de ser permanente.
-- Era decidida por `_G.PlayerDataManager.hasAwakening`, que respondia
-- true para sempre depois do desbloqueio: quem tinha o Despertar andava
-- com a vida dele o tempo todo, mesmo sem estar desperto. Agora segue
-- `_G.AwakeningMeter.estaDesperto` — sobe quando a forma dispara, volta
-- quando ela acaba.
-- ============================================
-- (V3) ATRIBUTOS CENTRALIZADOS
-- Coloque em ServerScriptService
-- Nome: "StatService"
-- DEPENDE DE: DataManager V7
-- SUBSTITUI: StatService V2
-- REMOVER:   StatService V2
-- ============================================
-- (V3) POR QUE OS ATRIBUTOS DE PERSONAGEM NÃO FUNCIONAVAM
--
-- Auditando o GameManager V9 linha por linha, apareceram DOIS
-- problemas — e os dois eram meus, não do projeto.
--
-- 🐛 PROBLEMA 1 — AS FONTES NÃO SE ATUALIZAVAM AO EQUIPAR.
--    O jogador NASCE sem personagem equipado (`unequipCharacter`
--    zera `equippedCharacter` toda vez que ele morre). Só depois,
--    pelo menu, ele equipa — e aí o `equipCharacter` faz:
--        linha 300: humanoid.MaxHealth = health   (valor CRU)
--        linha 347: _G.OnCharacterSelected(...)
--    O StatService recalculava nesse hook, mas o
--    CharacterStatsServer (arquétipo) e o PassiveSystemServer
--    (passivas) só aplicavam 1,4s e 1,6s depois do SPAWN — momento
--    em que não havia personagem equipado nenhum.
--    Resultado: o StatService recalculava com as fontes VAZIAS.
--    MaxHealth = base × 1 = valor cru. Nenhum atributo aparecia.
--    ✅ Agora o hook manda as fontes se atualizarem ANTES de
--       recalcular.
--
-- 🐛 PROBLEMA 2 — MEU WRAPPER PODIA SER APAGADO.
--    O SpawnSystem (linha 1043) faz ATRIBUIÇÃO DIRETA:
--        _G.OnCharacterSelected = function(...) ... end
--    Se ele carregar depois do StatService, ele SOBRESCREVE o meu
--    wrapper e some com ele — sem erro, sem aviso. A ordem de
--    carregamento de Scripts no ServerScriptService não é garantida,
--    então isso podia funcionar num teste e falhar no seguinte.
--    ✅ Agora existe um vigia: a cada poucos segundos ele confere
--       se o wrapper ainda está no lugar e reinstala se alguém
--       tiver sobrescrito. Sem quebrar quem sobrescreveu — o
--       original continua sendo chamado.
-- ============================================
-- (V2) CORREÇÕES DE BUGS REAIS:
--
-- • 🐛 PULO NÃO FUNCIONAVA. O V1 só escrevia em `JumpPower`, dentro
--   de um `if humanoid.UseJumpPower then`. Só que o Roblox moderno
--   nasce com UseJumpPower = FALSE — o personagem usa `JumpHeight`.
--   Resultado: o `if` era falso, o código nunca rodava e o atributo
--   de pulo era 100% morto, em silêncio.
--   Agora escreve nos DOIS: JumpPower ou JumpHeight, conforme o que
--   o Humanoid estiver usando de verdade.
--
-- • 🐛 VELOCIDADE APLICAVA NA BASE ERRADA. O V1 guardava a
--   velocidade base na PRIMEIRA vez que aplicava. Se nesse momento
--   o Humanoid já estivesse com a velocidade modificada (respawn
--   rápido, buff temporário ativo), aquele valor virava a "base" e
--   o cálculo saía errado pra sempre daquele spawn.
--   Agora a base vem do StarterPlayer (a mesma que o Roblox usa),
--   e só cai no valor atual do Humanoid como último recurso.
--
-- • 🐛 TIMING FRÁGIL. O V1 usava `task.wait(1.5)` e torcia pro
--   GameManager já ter terminado de equipar. O GameManager V9 chama
--   `_G.OnCharacterSelected(player, nome)` na linha 347 toda vez que
--   alguém equipa — o sinal certo sempre existiu e eu não usava.
--   O V2 se pendura nesse hook (sem substituir quem já usa) e
--   recalcula na hora exata. O delay continua como rede de
--   segurança, não como mecanismo principal.
--
-- • 🆕 `_G.DebugMovement("Nome")` mostra base, multiplicador e valor
--   final de velocidade/pulo, pra nunca mais ter que adivinhar.
-- ============================================
-- O QUE É:
-- Um único lugar que junta TODOS os atributos de um jogador, venham
-- de onde vierem (personagem base, nível, passiva, gear, Despertar,
-- buff temporário), e aplica o resultado no Humanoid.
--
-- POR QUE ISSO EXISTE:
-- Antes, cada sistema aplicava efeito direto no Humanoid por conta
-- própria. Com 2 sistemas já dava conflito (o PassiveSystemServer
-- recalculava MaxHealth por cima do que o GameManager tinha acabado
-- de definir). Com 23 atributos e gear entrando na conta, isso seria
-- impossível de depurar: ninguém saberia QUEM aplicou o quê.
-- Agora cada sistema só DECLARA seus números; quem aplica é aqui.
--
-- ============================================
-- COMO USAR (é só isto)
-- ============================================
--   _G.StatService.setSource(player, "passives", { DamageBoost = 0.15 })
--   _G.StatService.setSource(player, "gear",     { HPFlat = 50 })
--   _G.StatService.clearSource(player, "gear")
--
-- Cada sistema é dono de UMA fonte e só mexe na dele. Nenhum sistema
-- precisa saber da existência dos outros.
--
-- Porcentagem é SEMPRE decimal: 0.15 = +15%. Nunca 15.
--
-- ============================================
-- ORDEM DA FÓRMULA DE DANO (fixada agora, de propósito)
-- ============================================
-- Com 23 atributos, se a ordem não for travada no primeiro dia o
-- balanceamento vira chute. A ordem é:
--
--   1. dano base da gear
--   2. x (1 + DamageBoost + BoostDaClasse)          <- atacante
--   3. x (1 - resistência efetiva)                  <- vítima
--   4. teto por golpe (MAX_HIT_PERCENT da vida máx do alvo)
--
-- Três decisões dentro disso, e o motivo de cada uma:
--
-- • PIERCE É MULTIPLICATIVO, NUNCA SUBTRAÇÃO.
--   `resist - pierce` pode ficar NEGATIVO e virar amplificação de
--   dano sem querer (60% resist - 80% pierce = -20% = leva 20% a
--   mais). Aqui é `resist x (1 - pierce)`, que no pior caso zera.
--
-- • TETO DE RESISTÊNCIA (RESIST_CAP).
--   Sem teto, empilhar resistências vira imunidade e a luta trava
--   sem ninguém morrer. Vale nos dois sentidos: também limita o
--   quanto o Vidro Trincado pode te machucar.
--
-- • DEFENSE (FLAT) VIRA % COM RETORNO DECRESCENTE.
--   Subtração flat mata gear de dano baixo e rápido (5 de dano
--   contra 20 de defesa = 0, a gear vira inútil). A conversão
--   `def*0.25 / (def*0.25 + K)` nunca chega a 100% e nunca zera
--   ataque nenhum. O 0.25 é o "25% Multiplier" do documento.
--
-- ⚠️ AS 5 CLASSES ESTÃO TODAS AQUI (Melee/Ranged/Magic/Summon/
--    Debuff) porque registrar atributo é só dado, custa zero. Mas
--    BALANCEIE 3 PRIMEIRO (Melee/Ranged/Magic): são 9 números em vez
--    de 15, e as outras 2 entram depois sem retrabalho nenhum.
--
-- ⚠️ ESCOPO: este script NÃO aplica dano. Ele só CALCULA e guarda.
--    Quem vai chamar `computeDamage` é o DamageService, que ainda
--    não existe. Até lá, o PassiveSystemServer V3 usa essas contas
--    no lugar das dele.
--
-- REUTILIZAÇÃO (nada criado do zero):
-- • Vida base do personagem + Despertar .... GameManager V9 (linha ~290)
-- • ensureRemote / _G API / banner ......... padrão geral do projeto
-- • Parent = nil no lugar de :Destroy() .... regra do projeto
-- ============================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer") -- (V2) base de movimento

repeat
	task.wait()
until _G.PlayerDataManager

-- =====================================
-- CONFIGURAÇÃO
-- =====================================

local CONFIG = {
	-- Teto de resistência, nos dois sentidos.
	-- 0.75 = no máximo 75% de redução, e no máximo 75% a mais de dano.
	RESIST_CAP = 0.75,

	-- Defense (flat) -> %. Multiplicador do documento.
	DEFENSE_MULTIPLIER = 0.25,
	-- Constante do retorno decrescente. Defense 400 -> 400*0.25=100
	-- -> 100/(100+100) = 50% de redução.
	DEFENSE_CONSTANT = 100,

	-- Teto de dano por golpe, em fração da vida máxima do alvo.
	-- Rede de segurança: impede que qualquer combinação futura de
	-- boost + fraqueza + measure mate alguém de um golpe.
	MAX_HIT_PERCENT = 0.40,

	-- Piso de dano: nenhum golpe é totalmente anulado
	MIN_DAMAGE = 1,

	-- Limites de sanidade dos atributos finais
	MIN_WALKSPEED = 4,
	MAX_WALKSPEED = 120,
	MIN_JUMP = 10,
	MAX_JUMP = 300,

	-- (V2) O Roblox moderno usa JumpHeight, não JumpPower.
	-- Escalas completamente diferentes: JumpPower ~50, JumpHeight ~7.
	MIN_JUMP_HEIGHT = 2,
	MAX_JUMP_HEIGHT = 50,
	DEFAULT_JUMP_HEIGHT = 7.2, -- padrão do Roblox

	MIN_HEALTH = 1,

	-- Piso do multiplicador de vida. Sem isto, acumular vários
	-- redutores de HP% (Frenesi + Sobrecarga + gear futura) poderia
	-- deixar o jogador com vida quase zero e um golpe qualquer
	-- mataria. 0.25 = no mínimo 25% da vida base.
	MIN_HP_MULT = 0.25,

	DEFAULT_WALKSPEED = 16,
	DEFAULT_JUMP = 50,
}

-- =====================================
-- REGISTRO DE ATRIBUTOS
-- =====================================
-- kind: "flat" soma direto | "percent" soma como decimal
-- Tudo que não estiver aqui é IGNORADO ao registrar uma fonte —
-- assim um erro de digitação não vira atributo fantasma.

local DAMAGE_CLASSES = { "Melee", "Ranged", "Magic", "Summon", "Debuff" }

local STAT_DEFS = {
	-- Vida
	HPFlat = { kind = "flat", default = 0 },
	HPPercent = { kind = "percent", default = 0 },

	-- Dano e defesa gerais
	DamageBoost = { kind = "percent", default = 0 },
	DamageResistance = { kind = "percent", default = 0 },
	DefenseFlat = { kind = "flat", default = 0 },

	-- Movimento
	WalkSpeedFlat = { kind = "flat", default = 0 },
	WalkSpeedPercent = { kind = "percent", default = 0 },
	JumpFlat = { kind = "flat", default = 0 },
	JumpPercent = { kind = "percent", default = 0 },

	-- Cura
	IncomingHealing = { kind = "percent", default = 0 },
	OutgoingHealing = { kind = "percent", default = 0 },

	-- Diversos
	FlightSpeed = { kind = "percent", default = 0 },
	InterruptResist = { kind = "percent", default = 0 },
	Shield = { kind = "flat", default = 0 },
}

-- Gera Boost / Resist / Pierce das 5 classes sem repetir código
for _, class in ipairs(DAMAGE_CLASSES) do
	STAT_DEFS[class .. "Boost"] = { kind = "percent", default = 0 }
	STAT_DEFS[class .. "Resist"] = { kind = "percent", default = 0 }
	STAT_DEFS[class .. "Pierce"] = { kind = "percent", default = 0 }
end

local function isValidClass(class)
	if type(class) ~= "string" then
		return false
	end
	for _, name in ipairs(DAMAGE_CLASSES) do
		if name == class then
			return true
		end
	end
	return false
end

-- =====================================
-- ESTADO
-- =====================================

local sources = {} -- [player][sourceName] = { stats }
local computed = {} -- [player] = { stats finais }
local shieldPool = {} -- [player] = escudo atual (o stat Shield é o máximo)
local baseMovement = {} -- [player] = { walkSpeed, jump }
local changeCallbacks = {} -- funções avisadas quando os stats mudam

-- =====================================
-- VIDA BASE (mesma lógica do GameManager V9)
-- =====================================
-- Este é o ÚNICO lugar do projeto que calcula vida base agora.
-- O PassiveSystemServer V3 não faz mais essa conta — ele só declara
-- HPPercent e deixa o resultado com quem entende do assunto.

local function getBaseHealth(player)
	local data = _G.PlayerDataManager.getPlayerData(player)
	local equipped = data and data.equippedCharacter

	local baseHealth = nil

	if equipped and _G.GameManagerConfig and _G.GameManagerConfig.getCharacterHealth then
		local ok, health = pcall(_G.GameManagerConfig.getCharacterHealth, equipped)
		if ok and type(health) == "number" and health > 0 then
			baseHealth = health
		end
	end

	-- (V4) A VIDA DO DESPERTAR SÓ VALE ENQUANTO A FORMA ESTÁ ATIVA.
	--
	-- Antes esta checagem era `_G.PlayerDataManager.hasAwakening`, que
	-- respondia true para sempre depois de desbloquear — quem tinha o
	-- Despertar andava com a vida dele o tempo todo, mesmo sem estar
	-- desperto.
	--
	-- Agora o Despertar é uma forma temporária disparada pela barra do
	-- AwakeningMeterServer, então a vida acompanha a forma: sobe quando
	-- desperta, volta quando acaba.
	if
		equipped
		and _G.AwakeningMeter
		and _G.AwakeningMeter.estaDesperto
		and _G.AwakeningSystem
		and _G.AwakeningSystem.getDefinition
	then
		local ok, desperto = pcall(_G.AwakeningMeter.estaDesperto, player)
		if ok and desperto then
			local okDef, def = pcall(_G.AwakeningSystem.getDefinition, equipped)
			if okDef and type(def) == "table" and type(def.health) == "number" then
				baseHealth = def.health
			end
		end
	end

	if baseHealth then
		return baseHealth
	end

	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	return humanoid and humanoid.MaxHealth or 100
end

-- =====================================
-- AGREGAÇÃO
-- =====================================

local function emptyStats()
	local stats = {}
	for name, def in pairs(STAT_DEFS) do
		stats[name] = def.default
	end
	return stats
end

-- Só deixa passar atributo que existe no registro e que é número.
-- Erro de digitação some aqui em vez de virar bug silencioso.
local function sanitizeStats(raw)
	local clean = {}
	if type(raw) ~= "table" then
		return clean
	end

	for name, value in pairs(raw) do
		if STAT_DEFS[name] and type(value) == "number" and value == value then
			clean[name] = value
		end
	end

	return clean
end

local function aggregate(player)
	local total = emptyStats()
	local playerSources = sources[player]

	if playerSources then
		for _, statTable in pairs(playerSources) do
			for name, value in pairs(statTable) do
				if total[name] then
					total[name] = total[name] + value
				else
					total[name] = value
				end
			end
		end
	end

	computed[player] = total
	return total
end

local function getStats(player)
	return computed[player] or aggregate(player)
end

-- =====================================
-- APLICAÇÃO NO HUMANOID
-- =====================================

local applying = {} -- [humanoid] = true (evita reentrância)

local function applyToCharacter(player, fillHealth)
	local character = player.Character
	if not character then
		return
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return
	end

	local stats = getStats(player)

	-- ---------- VIDA ----------
	local baseHealth = getBaseHealth(player)
	local hpMult = math.max(CONFIG.MIN_HP_MULT, 1 + stats.HPPercent)
	local newMax = (baseHealth + stats.HPFlat) * hpMult
	newMax = math.max(CONFIG.MIN_HEALTH, math.floor(newMax))

	local ratio = 1
	if humanoid.MaxHealth > 0 then
		ratio = math.clamp(humanoid.Health / humanoid.MaxHealth, 0, 1)
	end

	applying[humanoid] = true
	humanoid.MaxHealth = newMax
	-- Mantém a PROPORÇÃO de vida ao recalcular. Sem isso, equipar uma
	-- passiva de +HP no meio da luta curaria de graça, e tirar
	-- mataria na hora.
	humanoid.Health = fillHealth and newMax or math.clamp(newMax * ratio, 1, newMax)
	applying[humanoid] = false

	-- ---------- MOVIMENTO ----------
	-- (V2) A base vem do StarterPlayer, que é a MESMA fonte que o
	-- Roblox usa ao criar o personagem. Ler do Humanoid como base é
	-- perigoso: se ele já estivesse modificado, o valor modificado
	-- viraria "base" e o cálculo saía errado pra sempre.
	if not baseMovement[player] then
		local baseWalk = CONFIG.DEFAULT_WALKSPEED
		local baseJumpPower = CONFIG.DEFAULT_JUMP
		local baseJumpHeight = CONFIG.DEFAULT_JUMP_HEIGHT

		local ok = pcall(function()
			if StarterPlayer.CharacterWalkSpeed > 0 then
				baseWalk = StarterPlayer.CharacterWalkSpeed
			end
			if StarterPlayer.CharacterJumpPower > 0 then
				baseJumpPower = StarterPlayer.CharacterJumpPower
			end
			if StarterPlayer.CharacterJumpHeight > 0 then
				baseJumpHeight = StarterPlayer.CharacterJumpHeight
			end
		end)

		if not ok then
			warn("[STAT V3] Não consegui ler o StarterPlayer — usando padrões do Roblox")
		end

		baseMovement[player] = {
			walkSpeed = baseWalk,
			jumpPower = baseJumpPower,
			jumpHeight = baseJumpHeight,
		}
	end

	local base = baseMovement[player]

	humanoid.WalkSpeed = math.clamp(
		(base.walkSpeed + stats.WalkSpeedFlat) * (1 + stats.WalkSpeedPercent),
		CONFIG.MIN_WALKSPEED,
		CONFIG.MAX_WALKSPEED
	)

	-- (V2) O BUG DO PULO ESTAVA AQUI.
	-- O Roblox moderno nasce com UseJumpPower = false e usa
	-- JumpHeight. O V1 só escrevia em JumpPower dentro de um `if
	-- UseJumpPower`, então em jogo nenhum o pulo mudava.
	-- Agora escreve no que o Humanoid realmente estiver usando.
	if humanoid.UseJumpPower then
		humanoid.JumpPower = math.clamp(
			(base.jumpPower + stats.JumpFlat) * (1 + stats.JumpPercent),
			CONFIG.MIN_JUMP,
			CONFIG.MAX_JUMP
		)
	else
		-- JumpFlat é medido em "unidades de JumpPower"; converte pra
		-- altura na mesma proporção, senão +10 de JumpFlat viraria um
		-- pulo absurdo (JumpHeight anda na casa de 7, não de 50).
		local flatAsHeight = stats.JumpFlat * (CONFIG.DEFAULT_JUMP_HEIGHT / CONFIG.DEFAULT_JUMP)
		humanoid.JumpHeight = math.clamp(
			(base.jumpHeight + flatAsHeight) * (1 + stats.JumpPercent),
			CONFIG.MIN_JUMP_HEIGHT,
			CONFIG.MAX_JUMP_HEIGHT
		)
	end

	-- ---------- ESCUDO ----------
	-- O stat Shield é a CAPACIDADE. A poça atual nunca passa dela.
	local maxShield = math.max(0, stats.Shield)
	local current = shieldPool[player] or 0
	shieldPool[player] = math.min(current, maxShield)

	if fillHealth then
		shieldPool[player] = maxShield
	end
end

local function notifyChange(player)
	for _, callback in ipairs(changeCallbacks) do
		pcall(callback, player, computed[player])
	end
end

local function recompute(player, fillHealth)
	if not player or not player.Parent then
		return
	end
	aggregate(player)
	applyToCharacter(player, fillHealth)
	notifyChange(player)
end

-- =====================================
-- CONTAS DE DANO
-- =====================================
-- Ainda não são chamadas por ninguém em combate — o DamageService
-- que vai usar isto não existe. Estão prontas pra ele.

local function getDamageMultiplier(player, class)
	local stats = getStats(player)
	local boost = stats.DamageBoost

	if isValidClass(class) then
		boost = boost + stats[class .. "Boost"]
	end

	-- Não deixa boost negativo virar cura
	return math.max(0, 1 + boost)
end

local function defenseToPercent(defenseFlat)
	if defenseFlat <= 0 then
		return 0
	end
	local scaled = defenseFlat * CONFIG.DEFENSE_MULTIPLIER
	return scaled / (scaled + CONFIG.DEFENSE_CONSTANT)
end

-- Resistência efetiva da VÍTIMA contra uma classe, já descontando o
-- pierce do ATACANTE. Retorna decimal (0.30 = leva 30% menos dano).
local function getEffectiveResistance(victim, class, attacker)
	local stats = getStats(victim)

	local resist = stats.DamageResistance + defenseToPercent(stats.DefenseFlat)

	if isValidClass(class) then
		resist = resist + stats[class .. "Resist"]
	end

	-- Pierce MULTIPLICA (nunca subtrai — ver cabeçalho)
	if attacker and isValidClass(class) then
		local attackerStats = getStats(attacker)
		local pierce = math.clamp(attackerStats[class .. "Pierce"], 0, 1)
		resist = resist * (1 - pierce)
	end

	return math.clamp(resist, -CONFIG.RESIST_CAP, CONFIG.RESIST_CAP)
end

-- Conta completa: dano bruto -> dano final
local function computeDamage(attacker, victim, rawDamage, class)
	rawDamage = tonumber(rawDamage) or 0
	if rawDamage <= 0 then
		return 0
	end

	local damage = rawDamage

	if attacker then
		damage = damage * getDamageMultiplier(attacker, class)
	end

	if victim then
		damage = damage * (1 - getEffectiveResistance(victim, class, attacker))

		-- Teto por golpe: rede de segurança contra combinação exagerada
		local character = victim.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid and humanoid.MaxHealth > 0 then
			damage = math.min(damage, humanoid.MaxHealth * CONFIG.MAX_HIT_PERCENT)
		end
	end

	return math.max(CONFIG.MIN_DAMAGE, damage)
end

local function computeHealing(healer, target, rawAmount)
	rawAmount = tonumber(rawAmount) or 0
	if rawAmount <= 0 then
		return 0
	end

	local amount = rawAmount

	if healer then
		amount = amount * math.max(0, 1 + getStats(healer).OutgoingHealing)
	end
	if target then
		amount = amount * math.max(0, 1 + getStats(target).IncomingHealing)
	end

	return amount
end

-- =====================================
-- ESCUDO
-- =====================================

local function consumeShield(player, damage)
	local current = shieldPool[player] or 0
	if current <= 0 then
		return damage, 0
	end

	local absorbed = math.min(current, damage)
	shieldPool[player] = current - absorbed

	return damage - absorbed, absorbed
end

-- =====================================
-- FONTES TEMPORÁRIAS
-- =====================================

local tempTokens = {} -- [player][name] = token, pra cancelar buff antigo

local function setSource(player, sourceName, statTable)
	if not player or type(sourceName) ~= "string" then
		return false
	end

	sources[player] = sources[player] or {}
	sources[player][sourceName] = sanitizeStats(statTable)

	recompute(player, false)
	return true
end

local function clearSource(player, sourceName)
	if not player or not sources[player] then
		return false
	end

	sources[player][sourceName] = nil
	recompute(player, false)
	return true
end

local function addTempSource(player, sourceName, statTable, duration)
	setSource(player, sourceName, statTable)

	duration = tonumber(duration) or 0
	if duration <= 0 then
		return
	end

	tempTokens[player] = tempTokens[player] or {}
	local token = os.clock()
	tempTokens[player][sourceName] = token

	task.delay(duration, function()
		if tempTokens[player] and tempTokens[player][sourceName] == token then
			tempTokens[player][sourceName] = nil
			clearSource(player, sourceName)
		end
	end)
end

-- =====================================
-- EVENTOS DE JOGADOR
-- =====================================

local function onCharacterAdded(player, character)
	baseMovement[player] = nil

	local humanoid = character:WaitForChild("Humanoid", 10)
	if not humanoid then
		return
	end

	-- Espera o GameManager equipar personagem e definir a vida base
	task.wait(1.5)
	recompute(player, true)
end

local function onPlayerAdded(player)
	sources[player] = {}
	shieldPool[player] = 0

	player.CharacterAdded:Connect(function(character)
		task.spawn(onCharacterAdded, player, character)
	end)

	if player.Character then
		task.spawn(onCharacterAdded, player, player.Character)
	end
end

local function onPlayerRemoving(player)
	sources[player] = nil
	computed[player] = nil
	shieldPool[player] = nil
	baseMovement[player] = nil
	tempTokens[player] = nil
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)

for _, player in ipairs(Players:GetPlayers()) do
	onPlayerAdded(player)
end

-- =====================================
-- =====================================
-- (V3) HOOK DE TROCA DE PERSONAGEM — COM VIGIA
-- =====================================
-- O GameManager V9 (linha 347) chama `_G.OnCharacterSelected` toda
-- vez que alguém equipa. É o único momento confiável pra recalcular:
-- no SPAWN não há personagem equipado (o `unequipCharacter` zera
-- isso a cada morte), então recalcular no spawn conta com fonte
-- vazia e o atributo some.
--
-- ⚠️ DOIS CUIDADOS QUE O V2 NÃO TINHA:
--
-- 1. O SpawnSystem (linha 1043) faz `_G.OnCharacterSelected = ...`
--    por ATRIBUIÇÃO DIRETA. Se carregar depois de nós, apaga nosso
--    wrapper em silêncio. Como a ordem de carregamento no
--    ServerScriptService não é garantida, isso podia funcionar num
--    teste e falhar no seguinte. Daí o vigia.
--
-- 2. Recalcular sozinho não basta: as FONTES precisam se atualizar
--    para o personagem NOVO antes da conta, senão o StatService
--    soma o arquétipo do personagem anterior — ou nada.

local nossoHook = nil

local function recalcularAoEquipar(player)
	task.spawn(function()
		-- Deixa o GameManager terminar (ele define MaxHealth e
		-- equippedCharacter ANTES de chamar o hook)
		task.wait(0.15)

		if not player or not player.Parent then
			return
		end

		baseMovement[player] = nil -- personagem novo, base nova

		-- Manda as FONTES se atualizarem para o personagem novo.
		-- Cada uma chama setSource, que já dispara recompute.
		if _G.CharacterStats and _G.CharacterStats.refresh then
			pcall(_G.CharacterStats.refresh, player)
		end
		if _G.PassiveSystem and _G.PassiveSystem.reapply then
			pcall(_G.PassiveSystem.reapply, player, true)
		end

		-- Conta final, já com tudo no lugar
		recompute(player, true)
	end)
end

local function instalarHook()
	local anterior = _G.OnCharacterSelected

	if anterior == nossoHook then
		return false -- já é o nosso
	end

	nossoHook = function(player, characterName)
		-- Chama quem estava antes (SpawnSystem etc.) sem quebrar
		local resultado
		if anterior then
			local ok, r = pcall(anterior, player, characterName)
			if ok then
				resultado = r
			end
		end

		recalcularAoEquipar(player)
		return resultado
	end

	_G.OnCharacterSelected = nossoHook
	return true
end

task.spawn(function()
	-- Espera os outros instalarem os deles primeiro
	task.wait(5)
	instalarHook()
	print("[STAT V3] Hook _G.OnCharacterSelected instalado")

	-- VIGIA: reinstala se alguém sobrescrever depois
	while true do
		task.wait(10)
		if instalarHook() then
			warn("[STAT V3] _G.OnCharacterSelected foi sobrescrito — reinstalado por cima")
		end
	end
end)

-- =====================================
-- REMOTE (leitura pelo cliente)
-- =====================================

local remotes = ReplicatedStorage:FindFirstChild("Remotes")
if not remotes then
	remotes = Instance.new("Folder")
	remotes.Name = "Remotes"
	remotes.Parent = ReplicatedStorage
end

local getPlayerStats = remotes:FindFirstChild("GetPlayerStats")
if getPlayerStats and not getPlayerStats:IsA("RemoteFunction") then
	getPlayerStats.Parent = nil -- regra do projeto: sem :Destroy()
	getPlayerStats = nil
end
if not getPlayerStats then
	getPlayerStats = Instance.new("RemoteFunction")
	getPlayerStats.Name = "GetPlayerStats"
	getPlayerStats.Parent = remotes
end

getPlayerStats.OnServerInvoke = function(player)
	local stats = getStats(player)
	local copy = {}
	for name, value in pairs(stats) do
		copy[name] = value
	end
	copy._shield = shieldPool[player] or 0
	return copy
end

-- =====================================
-- API GLOBAL
-- =====================================

_G.StatService = {
	CONFIG = CONFIG,
	STAT_DEFS = STAT_DEFS,
	DAMAGE_CLASSES = DAMAGE_CLASSES,

	-- Declaração de fontes (é isto que os outros sistemas usam)
	setSource = setSource,
	clearSource = clearSource,
	addTempSource = addTempSource,

	getStats = getStats,
	getStat = function(player, statName)
		local stats = getStats(player)
		return stats[statName] or 0
	end,

	recompute = function(player, fillHealth)
		recompute(player, fillHealth)
	end,

	getBaseHealth = getBaseHealth,

	-- Contas (prontas para o DamageService)
	computeDamage = computeDamage,
	computeHealing = computeHealing,
	getDamageMultiplier = getDamageMultiplier,
	getEffectiveResistance = getEffectiveResistance,
	defenseToPercent = defenseToPercent,

	-- Escudo
	getShield = function(player)
		return shieldPool[player] or 0
	end,
	consumeShield = consumeShield,
	restoreShield = function(player, amount)
		local stats = getStats(player)
		local maxShield = math.max(0, stats.Shield)
		shieldPool[player] = math.clamp((shieldPool[player] or 0) + (amount or 0), 0, maxShield)
		return shieldPool[player]
	end,

	-- Avisado sempre que os atributos de alguém mudarem
	onChanged = function(callback)
		if type(callback) == "function" then
			table.insert(changeCallbacks, callback)
		end
	end,

	isValidClass = isValidClass,
}

-- =====================================
-- DEBUG
-- =====================================

_G.DebugStats = function(playerName)
	local player = Players:FindFirstChild(playerName)
	if not player then
		print("❌ Jogador não encontrado")
		return
	end

	local stats = getStats(player)

	print("\n========== DEBUG STAT SERVICE V1 ==========")
	print(string.format("Jogador: %s", player.Name))
	print(string.format("Vida base (personagem/Despertar): %d", getBaseHealth(player)))

	-- (V3) A causa nº1 de "atributo não funciona"
	local dados = _G.PlayerDataManager.getPlayerData(player)
	local equipado = dados and dados.equippedCharacter
	if not equipado then
		print("⚠️ NENHUM PERSONAGEM EQUIPADO — nenhum atributo pode aplicar.")
		print("   O jogador nasce sem personagem; ele precisa equipar no menu.")
	else
		print(string.format("Personagem equipado: %s", equipado))
	end

	print(string.format(
		"Hook de equipar instalado: %s",
		tostring(_G.OnCharacterSelected == nossoHook)
	))

	print("\n-- FONTES REGISTRADAS --")
	local playerSources = sources[player] or {}
	local anySource = false
	for sourceName, statTable in pairs(playerSources) do
		local parts = {}
		for name, value in pairs(statTable) do
			table.insert(parts, string.format("%s=%.2f", name, value))
		end
		if #parts > 0 then
			anySource = true
			print(string.format("  [%s] %s", sourceName, table.concat(parts, ", ")))
		end
	end
	if not anySource then
		print("  (nenhuma)")
	end

	print("\n-- ATRIBUTOS FINAIS (só o que não é zero) --")
	local names = {}
	for name in pairs(STAT_DEFS) do
		table.insert(names, name)
	end
	table.sort(names)

	for _, name in ipairs(names) do
		local value = stats[name]
		if value ~= 0 then
			local suffix = STAT_DEFS[name].kind == "percent"
					and string.format("%.1f%%", value * 100)
				or string.format("%.1f", value)
			print(string.format("  %-20s %s", name, suffix))
		end
	end

	print(string.format("\nEscudo: %.0f", shieldPool[player] or 0))

	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		print(
			string.format(
				"Humanoid: %.0f/%.0f HP | %.1f WalkSpeed | %.0f Jump",
				humanoid.Health,
				humanoid.MaxHealth,
				humanoid.WalkSpeed,
				humanoid.JumpPower
			)
		)
	end
	print("=====================================\n")
end

-- (V2) Diagnóstico de movimento: mostra base, multiplicador e final.
-- Serve pra nunca mais precisar adivinhar se velocidade/pulo pegou.
_G.DebugMovement = function(playerName)
	local player = Players:FindFirstChild(playerName)
	if not player then
		print("❌ Jogador não encontrado")
		return
	end

	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		print("❌ Sem Humanoid")
		return
	end

	local stats = getStats(player)
	local base = baseMovement[player]

	print("\n========== DEBUG MOVIMENTO V2 ==========")
	print(string.format("Jogador: %s", player.Name))

	if not base then
		print("⚠️ Base ainda não capturada (o personagem acabou de nascer?)")
	else
		print(string.format("Base do StarterPlayer: %.1f walk | %.1f jumpPower | %.1f jumpHeight",
			base.walkSpeed, base.jumpPower, base.jumpHeight))
	end

	print(string.format("WalkSpeedFlat %+.1f | WalkSpeedPercent %+.0f%%",
		stats.WalkSpeedFlat, stats.WalkSpeedPercent * 100))
	print(string.format("JumpFlat %+.1f | JumpPercent %+.0f%%",
		stats.JumpFlat, stats.JumpPercent * 100))

	print(string.format("\nHumanoid AGORA: WalkSpeed %.2f", humanoid.WalkSpeed))
	if humanoid.UseJumpPower then
		print(string.format("Modo de pulo: JumpPower (%.2f)", humanoid.JumpPower))
	else
		print(string.format("Modo de pulo: JumpHeight (%.2f)", humanoid.JumpHeight))
		print("  (era ESTE o motivo do pulo não funcionar no V1)")
	end
	print("=====================================\n")
end

-- Simulador de dano: confere a fórmula sem precisar bater em ninguém
_G.SimulateDamage = function(attackerName, victimName, rawDamage, class)
	local attacker = Players:FindFirstChild(attackerName)
	local victim = Players:FindFirstChild(victimName)
	if not attacker or not victim then
		print("❌ Jogador não encontrado")
		return
	end

	rawDamage = tonumber(rawDamage) or 10

	local boost = getDamageMultiplier(attacker, class)
	local resist = getEffectiveResistance(victim, class, attacker)
	local final = computeDamage(attacker, victim, rawDamage, class)

	print("\n========== SIMULAÇÃO DE DANO ==========")
	print(string.format("%s -> %s | classe: %s", attacker.Name, victim.Name, tostring(class or "nenhuma")))
	print(string.format("  Dano base ............ %.1f", rawDamage))
	print(string.format("  x Boost do atacante .. %.3f", boost))
	print(string.format("  x (1 - resistência) .. %.3f  (resist %.1f%%)", 1 - resist, resist * 100))
	print(string.format("  = DANO FINAL ......... %.1f", final))
	print("=====================================\n")
end

print([[
╔══════════════════════════════════════════════════════╗
║  STAT SERVICE V2 — CARREGADO                        ║
╠══════════════════════════════════════════════════════╣
║  SUBSTITUI: StatService V1                           ║
║  REMOVER:   StatService V1                           ║
╠══════════════════════════════════════════════════════╣
║  * 23 atributos do documento, num lugar só           ║
║  * 5 classes de dano (Boost/Resist/Pierce)           ║
║  * Pierce MULTIPLICA (nunca vira amplificação)       ║
║  * Teto de resistência: 75%                          ║
║  * Defense flat -> % com retorno decrescente         ║
║  * Teto de 40% da vida máx por golpe                 ║
║  * Único dono de MaxHealth/WalkSpeed/Jump            ║
╠══════════════════════════════════════════════════════╣
║  CORRIGIDO NO V3:                                    ║
║  * Fontes (arquétipo/passiva) agora se atualizam ao  ║
║    EQUIPAR, não só no spawn — no spawn não há        ║
║    personagem equipado e a conta saía vazia          ║
║  * Vigia reinstala o hook se o SpawnSystem (ou       ║
║    outro) sobrescrever _G.OnCharacterSelected        ║
╠══════════════════════════════════════════════════════╣
║  CORRIGIDO NO V2:                                    ║
║  * Pulo (usava JumpPower; o Roblox usa JumpHeight)   ║
║  * Base de velocidade vinha do Humanoid, agora vem   ║
║    do StarterPlayer                                  ║
║  * Recalcula no _G.OnCharacterSelected, sem depender ║
║    de delay mágico                                   ║
╠══════════════════════════════════════════════════════╣
║  DEBUG: _G.DebugStats("Nome")                        ║
║         _G.DebugMovement("Nome")                     ║
║         _G.SimulateDamage("A","B",50,"Melee")        ║
╚══════════════════════════════════════════════════════╝
]])
