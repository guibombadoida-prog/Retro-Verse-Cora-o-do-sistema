-- ============================================
-- PASSIVE SYSTEM SERVER V8 — EDIÇÃO SÓ COM PERSONAGEM DESEQUIPADO
-- Coloque em ServerScriptService
-- Nome: "PassiveSystemServer"
-- DEPENDE DE: DataManager V8, StatService V3,
--             PassiveCatalog (ModuleScript), CharacterLevelServer V1
-- OPCIONAL:   NucleoCombate V2, EnergySystemServer V1, PassiveVFX
-- SUBSTITUI: PassiveSystemServer V7
-- REMOVER:   PassiveSystemServer V7
-- ============================================
-- (V8) NOVA REGRA: SÓ EDITA COM O PERSONAGEM DESEQUIPADO
--
-- Equipar, melhorar ou mexer na build agora exige que o jogador
-- NÃO esteja com personagem equipado. É a mesma lógica da troca de
-- personagem: não se troca a build no meio da briga.
--
-- ⚠️ ISSO INVERTEU O V7, QUE EXIGIA O CONTRÁRIO. E quebrou uma
--    coisa que não era óbvia: o cálculo de slots.
--
--    O V7 fazia `_G.CharacterLevel.getEquippedSlots(player)` — que
--    lê o nível do personagem EQUIPADO. Sem nenhum equipado isso
--    devolve 0, e nenhuma passiva caberia em lugar nenhum.
--    ✅ Agora os slots são calculados a partir do nível do
--       personagem ESCOLHIDO na tela, não do equipado.
--
--    Também mudou quem o cliente edita: como não há "equipado", o
--    `GetPassiveCatalog` passou a devolver a LISTA de personagens
--    que o jogador possui, cada um com seu nível, slots e passivas.
--    A tela escolhe qual editar.
--
-- ⚠️ O QUE **NÃO** MUDOU: a APLICAÇÃO continua valendo pro
--    personagem equipado. Você edita desequipado, equipa, e as
--    passivas daquele personagem entram. O vigia cuida disso.
--
-- ============================================
-- (V7) O QUE MUDOU
--
-- 1. APLICAÇÃO AO VIVO — a correção que fez tudo funcionar.
--    Da V1 à V6 as passivas eram aplicadas UMA vez, ~1,6s depois do
--    spawn. Só que o jogador NASCE sem personagem equipado (o
--    `unequipCharacter` do GameManager zera isso a cada morte). Ele
--    equipa depois, pelo menu — quando aquela aplicação já passou.
--    Qualquer lag, troca de personagem ou ordem de carregamento
--    matava as passivas em silêncio, sem erro nenhum.
--    ✅ Agora um VIGIA confere a cada 2s se o que está aplicado bate
--       com as passivas do personagem equipado AGORA. Não existe
--       mais "a janela certa" — não tem janela. É o mesmo princípio
--       que fez o StatusEffectServer funcionar de primeira.
--
-- 2. NÍVEIS 1 a 10 com custo em MOEDAS (PassiveCatalog).
--    Vantagem E desvantagem crescem juntas: continua sendo escolha,
--    não upgrade grátis.
--
-- 3. TEMPORÁRIAS com gatilho e recarga.
--    Gatilhos: combate, levar_dano, causar_dano, abate, vida_baixa.
--
-- 4. NEGADOR (anula o dano) e REVERSO (devolve ao agressor).
--    ⚠️ Estas precisam INTERCEPTAR o dano, então usam monitor de
--       vida. Isso NÃO conflita com o NucleoCombate: o Núcleo
--       ESCALA o dano (multiplica), estas DESFAZEM (devolvem vida).
--       Operações diferentes, sem dupla aplicação.
--
-- 5. SLOTS POR GAMEPASS — um gamepass libera os 3 extras.
--
-- 6. EXCLUSIVIDADE — o Reverso ocupa TODOS os slots.
-- ============================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local MarketplaceService = game:GetService("MarketplaceService")

repeat
	task.wait()
until _G.PlayerDataManager and _G.CharacterLevel and _G.StatService

local moduloCatalogo = ServerScriptService:WaitForChild("PassiveCatalog", 30)
if not moduloCatalogo then
	warn("[PASSIVE V8] PassiveCatalog não encontrado em ServerScriptService — sistema NÃO vai funcionar")
	return
end

local Catalogo = require(moduloCatalogo)

-- =====================================
-- CONFIGURAÇÃO
-- =====================================

local CONFIG = {
	FONTE_PERMANENTE = "passivas",
	FONTE_TEMPORARIA = "passiva_temp",
	FONTE_RECARGA = "passiva_recarga",

	GAMEPASS_SLOTS = 1928341936,
	SLOTS_EXTRAS = 3,

	CUSTO_RESPEC = 250,
	PRIMEIRA_GRATIS = true,

	VIGIA_INTERVALO = 2,
	COMBATE_JANELA = 5,

	TETO_CHANCE = 0.60, -- acima disso o combate vira loteria
}

-- Random.new() em vez de math.random: a regra do projeto restringe
-- math.random, e este é o gerador moderno e isolado do Roblox.
local sorteio = Random.new()

-- =====================================
-- ESTADO
-- =====================================

local aplicado = {} -- [player] = assinatura do que está aplicado
local cacheEspecial = {}
local temporarias = {} -- [player][id] = { ativaAte, recargaAte }
local ultimoDano = {}
local monitorConexoes = {}
local temGamepass = {}
local ajustando = {} -- guarda de reentrância

-- =====================================
-- GAMEPASS
-- =====================================
-- UserOwnsGamePassAsync é chamada de rede: consultada uma vez ao
-- entrar e guardada. Nunca dentro de laço.

local function consultarGamepass(player)
	if temGamepass[player] ~= nil then
		return temGamepass[player]
	end

	local ok, possui = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(player.UserId, CONFIG.GAMEPASS_SLOTS)
	end)

	if not ok then
		-- Falha de rede não pode virar "não tem" definitivo:
		-- deixa nil para tentar de novo depois
		warn("[PASSIVE V8] Falha ao consultar gamepass de " .. player.Name)
		return false
	end

	temGamepass[player] = possui and true or false
	return temGamepass[player]
end

-- (V8) Slots do personagem ESCOLHIDO, não do equipado.
-- Sem nomePersonagem, cai no equipado (compatibilidade).
local function slotsDoPersonagem(player, nomePersonagem)
	local base = 0

	if nomePersonagem then
		local progresso = _G.PlayerDataManager.getCharacterProgress(player, nomePersonagem)
		if progresso then
			base = _G.CharacterLevel.getSlotCount(progresso.level) or 0
		end
	else
		base = _G.CharacterLevel.getEquippedSlots(player) or 0
	end

	if consultarGamepass(player) then
		base = base + CONFIG.SLOTS_EXTRAS
	end

	return base
end

-- Mantido pro resto do script e pra quem já chamava de fora
local function slotsDisponiveis(player)
	return slotsDoPersonagem(player, nil)
end

-- (V8) Porta única da regra nova: com personagem equipado, não edita
local function podeEditar(player)
	local dados = _G.PlayerDataManager.getPlayerData(player)
	if dados and dados.equippedCharacter then
		return false, "Desequipe seu personagem para mexer nas passivas."
	end
	return true
end

-- =====================================
-- LEITURA
-- =====================================

local function passivasEquipadas(player)
	local dados = _G.PlayerDataManager.getPlayerData(player)
	local equipado = dados and dados.equippedCharacter
	if not equipado then
		return {}, nil
	end
	return _G.PlayerDataManager.getCharacterPassives(player, equipado), equipado
end

-- Muda se qualquer coisa relevante mudou. É o que o vigia compara.
local function assinatura(player)
	local lista, equipado = passivasEquipadas(player)
	if not equipado then
		return "sem_personagem"
	end

	local partes = { equipado }
	for _, entrada in ipairs(lista) do
		table.insert(partes, entrada.id .. ":" .. tostring(entrada.rank))
	end
	table.sort(partes)
	return table.concat(partes, "|")
end

-- =====================================
-- AGREGAÇÃO
-- =====================================

local function vazioEspecial()
	return {
		lifesteal = 0,
		noRegen = false,
		lowHpDamage = 0,
		lowHpThreshold = 0.35,
		vsHigher = 0,
		vsLower = 0,
		vsFerido = 0,
		feridoThreshold = 0.40,
		vsCheio = 0,
		killEnergy = 0,
		xpLoss = 0,
		drenoPorSeg = 0,
		chanceNegar = 0,
		chanceReverter = 0,
		reverterFracao = 0.10,
		energia = {
			costMult = 1,
			regenMult = 1,
			maxMult = 1,
			idleOnlyRegen = false,
			idleBonus = 0,
		},
	}
end

local function calcular(player)
	local stats = {}
	local especial = vazioEspecial()

	local lista = passivasEquipadas(player)

	for _, entrada in ipairs(lista) do
		local passiva = Catalogo.obter(entrada.id)
		if passiva then
			local nivel = entrada.rank or 1
			local sp = Catalogo.specialNoNivel(entrada.id, nivel)

			-- Atributos: só das PERMANENTES.
			-- As temporárias entram por fonte separada, e só
			-- enquanto estão ativas.
			if passiva.tipo == "permanente" then
				for nome, valor in pairs(Catalogo.statsNoNivel(entrada.id, nivel)) do
					stats[nome] = (stats[nome] or 0) + valor
				end

				if sp.lifesteal then
					especial.lifesteal = especial.lifesteal + sp.lifesteal
				end
				if sp.noRegen then
					especial.noRegen = true
				end
				if sp.lowHpDamage then
					especial.lowHpDamage = especial.lowHpDamage + sp.lowHpDamage
					especial.lowHpThreshold = sp.lowHpThreshold or especial.lowHpThreshold
				end
				if sp.vsHigher then
					especial.vsHigher = especial.vsHigher + sp.vsHigher
				end
				if sp.vsLower then
					especial.vsLower = especial.vsLower + sp.vsLower
				end
				if sp.vsFerido then
					especial.vsFerido = especial.vsFerido + sp.vsFerido
					especial.feridoThreshold = sp.feridoThreshold or especial.feridoThreshold
				end
				if sp.vsCheio then
					especial.vsCheio = especial.vsCheio + sp.vsCheio
				end
				if sp.energyRegen then
					especial.energia.regenMult = especial.energia.regenMult + sp.energyRegen
				end
				if sp.energyMax then
					especial.energia.maxMult = especial.energia.maxMult + sp.energyMax
				end
				if sp.idleBonus then
					especial.energia.idleBonus = especial.energia.idleBonus + sp.idleBonus
				end
				if sp.idleOnly then
					especial.energia.idleOnlyRegen = true
				end
				if sp.negar then
					especial.chanceNegar = especial.chanceNegar + Catalogo.chanceNoNivel(entrada.id, nivel)
				end
				if sp.reverter then
					especial.chanceReverter = especial.chanceReverter
						+ Catalogo.chanceNoNivel(entrada.id, nivel)
					especial.reverterFracao = math.max(especial.reverterFracao, sp.reverterFracao or 0.10)
				end
			else
				-- Especiais que valem mesmo estando a passiva dormindo
				if sp.killEnergy then
					especial.killEnergy = especial.killEnergy + sp.killEnergy
				end
				if sp.xpLoss then
					especial.xpLoss = math.max(especial.xpLoss, sp.xpLoss)
				end
				if sp.drenoPorSeg then
					especial.drenoPorSeg = especial.drenoPorSeg + sp.drenoPorSeg
				end
			end
		end
	end

	especial.energia.regenMult = math.max(0.20, especial.energia.regenMult)
	especial.energia.maxMult = math.max(0.40, especial.energia.maxMult)
	especial.energia.costMult = math.max(0.30, especial.energia.costMult)

	especial.chanceNegar = math.min(CONFIG.TETO_CHANCE, especial.chanceNegar)
	especial.chanceReverter = math.min(CONFIG.TETO_CHANCE, especial.chanceReverter)

	return stats, especial
end

local function especialDe(player)
	if cacheEspecial[player] then
		return cacheEspecial[player]
	end
	local _, especial = calcular(player)
	cacheEspecial[player] = especial
	return especial
end

-- =====================================
-- APLICAÇÃO
-- =====================================

local function aplicar(player)
	if not player or not player.Parent then
		return
	end

	local stats, especial = calcular(player)
	cacheEspecial[player] = especial

	_G.StatService.setSource(player, CONFIG.FONTE_PERMANENTE, stats)

	local personagem = player.Character
	if personagem then
		local scriptRegen = personagem:FindFirstChild("Health")
		if scriptRegen and scriptRegen:IsA("Script") then
			scriptRegen.Disabled = especial.noRegen
		end
	end

	if _G.EnergySystem then
		_G.EnergySystem.setModifiers(player, especial.energia)
	end

	aplicado[player] = assinatura(player)
end

-- =====================================
-- VIGIA — o que fez funcionar
-- =====================================

task.spawn(function()
	while true do
		task.wait(CONFIG.VIGIA_INTERVALO)
		for _, player in ipairs(Players:GetPlayers()) do
			if aplicado[player] ~= assinatura(player) then
				pcall(aplicar, player)
			end
		end
	end
end)

-- =====================================
-- TEMPORÁRIAS
-- =====================================

local function ativarTemporaria(player, entrada, passiva)
	temporarias[player] = temporarias[player] or {}
	local estado = temporarias[player][entrada.id]
	local agora = os.clock()

	if estado then
		if estado.ativaAte and agora < estado.ativaAte then
			return false -- já ativa
		end
		if estado.recargaAte and agora < estado.recargaAte then
			return false -- recarregando
		end
	end

	local nivel = entrada.rank or 1

	_G.StatService.addTempSource(
		player,
		CONFIG.FONTE_TEMPORARIA .. "_" .. entrada.id,
		Catalogo.statsNoNivel(entrada.id, nivel),
		passiva.duracao
	)

	temporarias[player][entrada.id] = {
		ativaAte = agora + passiva.duracao,
		recargaAte = agora + passiva.duracao + passiva.recarga,
	}

	-- Penalidade durante a recarga, se houver
	local statsRecarga = Catalogo.statsRecargaNoNivel(entrada.id, nivel)
	if next(statsRecarga) ~= nil then
		task.delay(passiva.duracao, function()
			if player and player.Parent then
				_G.StatService.addTempSource(
					player,
					CONFIG.FONTE_RECARGA .. "_" .. entrada.id,
					statsRecarga,
					passiva.recarga
				)
			end
		end)
	end

	if _G.PassiveVFX and _G.PassiveVFX.disparar then
		pcall(_G.PassiveVFX.disparar, player, passiva.vfx, passiva.duracao)
	end

	print(string.format("[PASSIVE V8] %s ativou %s (%ds)", player.Name, passiva.nome, passiva.duracao))
	return true
end

local function dispararGatilho(player, gatilho)
	if not player or not player.Parent then
		return
	end

	local lista = passivasEquipadas(player)

	for _, entrada in ipairs(lista) do
		local passiva = Catalogo.obter(entrada.id)
		if passiva and passiva.tipo == "temporario" and passiva.gatilho == gatilho then
			local pode = true

			if gatilho == "vida_baixa" then
				local personagem = player.Character
				local humanoide = personagem and personagem:FindFirstChildOfClass("Humanoid")
				if not humanoide or humanoide.MaxHealth <= 0 then
					pode = false
				else
					pode = (humanoide.Health / humanoide.MaxHealth) <= (passiva.gatilhoThreshold or 0.30)
				end
			end

			if pode then
				ativarTemporaria(player, entrada, passiva)
			end
		end
	end
end

-- =====================================
-- MONITOR DE VIDA
-- =====================================
-- Três funções: gatilhos, Negador e Reverso.
-- Não conflita com o Núcleo (ele escala, este desfaz).

local function monitorar(player, personagem)
	local humanoide = personagem:WaitForChild("Humanoid", 10)
	if not humanoide then
		return
	end

	local ultimaVida = humanoide.Health

	if monitorConexoes[player] then
		pcall(function()
			monitorConexoes[player]:Disconnect()
		end)
	end

	monitorConexoes[player] = humanoide.HealthChanged:Connect(function(vida)
		if ajustando[humanoide] then
			ultimaVida = vida
			return
		end

		if vida >= ultimaVida then
			ultimaVida = vida
			return
		end

		local dano = ultimaVida - vida
		ultimaVida = vida
		ultimoDano[player] = os.clock()

		local especial = especialDe(player)

		-- ---------- NEGADOR ----------
		if especial.chanceNegar > 0 and sorteio:NextNumber() < especial.chanceNegar then
			ajustando[humanoide] = true
			humanoide.Health = math.min(humanoide.MaxHealth, vida + dano)
			ajustando[humanoide] = false
			ultimaVida = humanoide.Health

			if _G.PassiveVFX and _G.PassiveVFX.disparar then
				pcall(_G.PassiveVFX.disparar, player, "NEGACAO_BRANCA", 0.6)
			end

			print(string.format("[PASSIVE V8] %s NEGOU %.0f de dano", player.Name, dano))
			return -- negou: não dispara mais nada
		end

		-- ---------- REVERSO ----------
		if especial.chanceReverter > 0 and sorteio:NextNumber() < especial.chanceReverter then
			local agressor = _G.DamageAttribution
				and _G.DamageAttribution.getAttacker
				and _G.DamageAttribution.getAttacker(personagem)

			if agressor and agressor ~= player and agressor.Character then
				local humAgressor = agressor.Character:FindFirstChildOfClass("Humanoid")
				if humAgressor and humAgressor.Health > 0 then
					-- Fração < 1 de propósito: devolver 100% faria
					-- dois Reversos se matarem em looping
					local devolvido = dano * especial.reverterFracao

					ajustando[humAgressor] = true
					humAgressor:TakeDamage(devolvido)
					ajustando[humAgressor] = false

					if _G.PassiveVFX and _G.PassiveVFX.disparar then
						pcall(_G.PassiveVFX.disparar, player, "ESPELHO_INVERTIDO", 0.8)
					end

					print(
						string.format(
							"[PASSIVE V8] %s REVERTEU %.0f em %s",
							player.Name,
							devolvido,
							agressor.Name
						)
					)
				end
			end
		end

		-- ---------- GATILHOS ----------
		dispararGatilho(player, "levar_dano")
		dispararGatilho(player, "combate")
		dispararGatilho(player, "vida_baixa")

		local agressor = _G.DamageAttribution
			and _G.DamageAttribution.getAttacker
			and _G.DamageAttribution.getAttacker(personagem)

		if agressor and agressor ~= player then
			ultimoDano[agressor] = os.clock()
			dispararGatilho(agressor, "causar_dano")
			dispararGatilho(agressor, "combate")
		end
	end)
end

-- =====================================
-- MORTE
-- =====================================

local function aoMorrer(player, personagem)
	local especial = especialDe(player)

	if especial.xpLoss > 0 then
		local dados = _G.PlayerDataManager.getPlayerData(player)
		local equipado = dados and dados.equippedCharacter
		if equipado then
			local progresso = _G.PlayerDataManager.getCharacterProgress(player, equipado)
			if progresso and progresso.xp > 0 then
				local perdido = math.floor(progresso.xp * especial.xpLoss)
				if perdido > 0 then
					_G.PlayerDataManager.setCharacterLevel(
						player,
						equipado,
						progresso.level,
						math.max(0, progresso.xp - perdido)
					)
				end
			end
		end
	end

	local matador = _G.DamageAttribution
		and _G.DamageAttribution.getAttacker
		and _G.DamageAttribution.getAttacker(personagem)

	if matador and matador ~= player and matador.Parent then
		dispararGatilho(matador, "abate")

		local especialMatador = especialDe(matador)
		if especialMatador.killEnergy > 0 and _G.EnergySystem then
			_G.EnergySystem.restore(matador, especialMatador.killEnergy)
		end
	end

	temporarias[player] = nil
end

-- =====================================
-- MODIFICADORES NO NÚCLEO
-- =====================================
-- Frenesi, Duelista e Executor dependem da RELAÇÃO atacante×alvo.
-- Registrados uma vez: toda Tool que use o Núcleo recebe de graça.

local function nivelDoPersonagem(player)
	local dados = _G.PlayerDataManager.getPlayerData(player)
	local equipado = dados and dados.equippedCharacter
	if not equipado then
		return 1
	end
	local progresso = _G.PlayerDataManager.getCharacterProgress(player, equipado)
	return progresso and progresso.level or 1
end

local function registrarNoNucleo(Nucleo)
	Nucleo.registrarModificador("Passiva_Frenesi", function(ctx)
		if not ctx.jogadorDono then
			return 0
		end
		local especial = especialDe(ctx.jogadorDono)
		if especial.lowHpDamage <= 0 then
			return 0
		end
		local hum = ctx.personagemDono and ctx.personagemDono:FindFirstChildOfClass("Humanoid")
		if hum and hum.MaxHealth > 0 and (hum.Health / hum.MaxHealth) <= especial.lowHpThreshold then
			return especial.lowHpDamage
		end
		return 0
	end)

	Nucleo.registrarModificador("Passiva_Duelista", function(ctx)
		if not ctx.jogadorDono or not ctx.jogadorAlvo then
			return 0
		end
		local especial = especialDe(ctx.jogadorDono)
		if especial.vsHigher == 0 and especial.vsLower == 0 then
			return 0
		end

		local meu = nivelDoPersonagem(ctx.jogadorDono)
		local dele = nivelDoPersonagem(ctx.jogadorAlvo)

		if dele > meu then
			return especial.vsHigher
		elseif dele < meu then
			return especial.vsLower
		end
		return 0
	end)

	Nucleo.registrarModificador("Passiva_Executor", function(ctx)
		if not ctx.jogadorDono then
			return 0
		end
		local especial = especialDe(ctx.jogadorDono)
		if especial.vsFerido == 0 and especial.vsCheio == 0 then
			return 0
		end

		local hum = ctx.humanoideAlvo
		if not hum or hum.MaxHealth <= 0 then
			return 0
		end

		local proporcao = hum.Health / hum.MaxHealth
		if proporcao <= especial.feridoThreshold then
			return especial.vsFerido
		elseif proporcao >= 0.95 then
			return especial.vsCheio
		end
		return 0
	end)

	Nucleo.aoAplicarDano(function(ctx, danoFinal)
		if not ctx.jogadorDono or danoFinal <= 0 then
			return
		end
		local especial = especialDe(ctx.jogadorDono)
		if especial.lifesteal <= 0 then
			return
		end
		local hum = ctx.personagemDono and ctx.personagemDono:FindFirstChildOfClass("Humanoid")
		if hum and hum.Health > 0 then
			local cura = _G.StatService.computeHealing(
				ctx.jogadorDono,
				ctx.jogadorDono,
				danoFinal * especial.lifesteal
			)
			ajustando[hum] = true
			hum.Health = math.min(hum.MaxHealth, hum.Health + cura)
			ajustando[hum] = false
		end
	end)

	print("[PASSIVE V8] Frenesi, Duelista, Executor e Vampírico registrados no Núcleo")
end

task.spawn(function()
	local esperou = 0
	local pasta = ServerScriptService:FindFirstChild("RetroVerse")
	while not pasta and esperou < 30 do
		task.wait(1)
		esperou = esperou + 1
		pasta = ServerScriptService:FindFirstChild("RetroVerse")
	end

	local modulo = pasta and pasta:FindFirstChild("NucleoCombate_V2")
	if not modulo then
		warn("[PASSIVE V8] NucleoCombate_V2 ausente — Frenesi, Duelista, Executor e Vampírico ficam INERTES")
		return
	end

	local ok, Nucleo = pcall(require, modulo)
	if ok and type(Nucleo) == "table" then
		registrarNoNucleo(Nucleo)
	end
end)

-- =====================================
-- DRENO (Sede de Sangue)
-- =====================================

task.spawn(function()
	while true do
		task.wait(1)
		for _, player in ipairs(Players:GetPlayers()) do
			local especial = cacheEspecial[player]
			local ativa = temporarias[player] and temporarias[player]["sede_sangue"]

			if especial and especial.drenoPorSeg > 0 and ativa and ativa.ativaAte then
				if os.clock() < ativa.ativaAte then
					local personagem = player.Character
					local humanoide = personagem and personagem:FindFirstChildOfClass("Humanoid")
					if humanoide and humanoide.Health > especial.drenoPorSeg then
						ajustando[humanoide] = true
						humanoide.Health = humanoide.Health - especial.drenoPorSeg
						ajustando[humanoide] = false
					end
				end
			end
		end
	end
end)

-- =====================================
-- EVENTOS DE JOGADOR
-- =====================================

local function aoNascer(player, personagem)
	cacheEspecial[player] = nil
	aplicado[player] = nil
	temporarias[player] = nil

	monitorar(player, personagem)

	local humanoide = personagem:FindFirstChildOfClass("Humanoid")
	if humanoide then
		humanoide.Died:Connect(function()
			pcall(aoMorrer, player, personagem)
		end)
	end

	task.wait(1.5)
	aplicar(player)
end

local function aoEntrar(player)
	task.spawn(consultarGamepass, player)

	player.CharacterAdded:Connect(function(personagem)
		task.spawn(aoNascer, player, personagem)
	end)

	if player.Character then
		task.spawn(aoNascer, player, player.Character)
	end
end

local function aoSair(player)
	if monitorConexoes[player] then
		pcall(function()
			monitorConexoes[player]:Disconnect()
		end)
	end
	monitorConexoes[player] = nil
	cacheEspecial[player] = nil
	aplicado[player] = nil
	temporarias[player] = nil
	ultimoDano[player] = nil
	temGamepass[player] = nil
end

Players.PlayerAdded:Connect(aoEntrar)
Players.PlayerRemoving:Connect(aoSair)

for _, player in ipairs(Players:GetPlayers()) do
	aoEntrar(player)
end

-- =====================================
-- REMOTES
-- =====================================

local remotes = ReplicatedStorage:FindFirstChild("Remotes")
if not remotes then
	remotes = Instance.new("Folder")
	remotes.Name = "Remotes"
	remotes.Parent = ReplicatedStorage
end

local function garantirRemote(nome, classe)
	local r = remotes:FindFirstChild(nome)
	if r and not r:IsA(classe) then
		r.Parent = nil -- regra do projeto: sem :Destroy()
		r = nil
	end
	if not r then
		r = Instance.new(classe)
		r.Name = nome
		r.Parent = remotes
	end
	return r
end

local remoteCatalogo = garantirRemote("GetPassiveCatalog", "RemoteFunction")
local remoteEquipar = garantirRemote("SetCharacterPassives", "RemoteFunction")
local remoteUpgrade = garantirRemote("UpgradePassive", "RemoteFunction")

remoteCatalogo.OnServerInvoke = function(player)
	local lista = {}

	for _, passiva in ipairs(Catalogo.LISTA) do
		local niveis = {}
		for n = 1, Catalogo.MAX_NIVEL do
			table.insert(niveis, {
				nivel = n,
				desc = Catalogo.descricaoNoNivel(passiva.id, n),
				custo = Catalogo.custoDoNivel(n),
			})
		end

		table.insert(lista, {
			id = passiva.id,
			nome = passiva.nome,
			icone = passiva.icone,
			categoria = passiva.categoria,
			tipo = passiva.tipo,
			beneficio = passiva.beneficio,
			malefico = passiva.malefico,
			exclusivo = passiva.exclusivo or false,
			niveis = niveis,
		})
	end

	local dados = _G.PlayerDataManager.getPlayerData(player)
	local equipado = dados and dados.equippedCharacter
	local liberado, motivo = podeEditar(player)

	-- (V8) Como a edição é feita DESEQUIPADO, a tela precisa saber
	-- quais personagens existem pra poder escolher um.
	local personagens = {}
	if dados and dados.ownedCharacters then
		for _, charObj in ipairs(dados.ownedCharacters) do
			local progresso = _G.PlayerDataManager.getCharacterProgress(player, charObj.name)
			if progresso then
				table.insert(personagens, {
					nome = charObj.name,
					nivel = progresso.level,
					slots = slotsDoPersonagem(player, charObj.name),
					passivas = progresso.passives,
				})
			end
		end

		table.sort(personagens, function(a, b)
			return a.nome < b.nome
		end)
	end

	return {
		catalogo = lista,
		maxNivel = Catalogo.MAX_NIVEL,
		custoRespec = CONFIG.CUSTO_RESPEC,

		-- (V8) estado da regra nova
		podeEditar = liberado,
		motivoBloqueio = motivo,
		equipado = equipado,

		personagens = personagens,
		slotsExtras = CONFIG.SLOTS_EXTRAS,
		temGamepass = consultarGamepass(player),
		gamepassId = CONFIG.GAMEPASS_SLOTS,
		moedas = dados and dados.coins or 0,
	}
end

remoteEquipar.OnServerInvoke = function(player, nomePersonagem, passivas)
	if type(nomePersonagem) ~= "string" or type(passivas) ~= "table" then
		return false, "Dados inválidos."
	end

	-- (V8) REGRA NOVA: não edita com personagem equipado
	local liberado, motivo = podeEditar(player)
	if not liberado then
		return false, motivo
	end

	if not _G.PlayerDataManager.ownsCharacter(player, nomePersonagem) then
		return false, "Você não possui este personagem."
	end

	local progresso = _G.PlayerDataManager.getCharacterProgress(player, nomePersonagem)
	if not progresso then
		return false, "Personagem não encontrado."
	end

	local limpo = {}
	local temExclusivo = false

	for _, entrada in ipairs(passivas) do
		if type(entrada) == "table" then
			local passiva = Catalogo.obter(entrada.id)
			if passiva then
				if passiva.exclusivo then
					temExclusivo = true
				end
				table.insert(limpo, {
					id = entrada.id,
					rank = math.clamp(math.floor(tonumber(entrada.rank) or 1), 1, Catalogo.MAX_NIVEL),
				})
			end
		end
	end

	if temExclusivo and #limpo > 1 then
		return false, "Essa passiva é exclusiva — não combina com nenhuma outra."
	end

	local slots = slotsDoPersonagem(player, nomePersonagem)
	if #limpo > slots then
		return false, string.format("%s tem %d slot(s).", nomePersonagem, slots)
	end

	-- Respec: cobra só por passiva REMOVIDA ou rebaixada
	local mudancas = 0
	for _, antiga in ipairs(progresso.passives) do
		local continua = false
		for _, nova in ipairs(limpo) do
			if nova.id == antiga.id and nova.rank >= antiga.rank then
				continua = true
				break
			end
		end
		if not continua then
			mudancas = mudancas + 1
		end
	end

	local custo = 0
	if mudancas > 0 and not (CONFIG.PRIMEIRA_GRATIS and #progresso.passives == 0) then
		custo = CONFIG.CUSTO_RESPEC * mudancas
		local dados = _G.PlayerDataManager.getPlayerData(player)
		if not dados or dados.coins < custo then
			return false,
				string.format("Respec custa %d moedas (você tem %d).", custo, dados and dados.coins or 0)
		end
		_G.PlayerDataManager.updateCoins(player, -custo)
	end

	local ok, resultado = _G.PlayerDataManager.setCharacterPassives(player, nomePersonagem, limpo, slots)
	if not ok then
		return false, resultado or "Não foi possível salvar."
	end

	aplicar(player)
	_G.PlayerDataManager.savePlayerData(player)

	if custo > 0 then
		return true, string.format("Build salva! (-%d moedas)", custo)
	end
	return true, "Build salva!"
end

remoteUpgrade.OnServerInvoke = function(player, nomePersonagem, idPassiva)
	if type(nomePersonagem) ~= "string" or type(idPassiva) ~= "string" then
		return false, "Dados inválidos."
	end

	-- (V8) REGRA NOVA: não melhora com personagem equipado
	local liberado, motivo = podeEditar(player)
	if not liberado then
		return false, motivo
	end

	local passiva = Catalogo.obter(idPassiva)
	if not passiva then
		return false, "Passiva desconhecida."
	end

	local progresso = _G.PlayerDataManager.getCharacterProgress(player, nomePersonagem)
	if not progresso then
		return false, "Personagem não encontrado."
	end

	local atual = nil
	for _, entrada in ipairs(progresso.passives) do
		if entrada.id == idPassiva then
			atual = entrada
			break
		end
	end

	if not atual then
		return false, "Equipe a passiva antes de melhorar."
	end

	if atual.rank >= Catalogo.MAX_NIVEL then
		return false, "Já está no nível máximo."
	end

	local custo = Catalogo.custoDoNivel(atual.rank)
	local dados = _G.PlayerDataManager.getPlayerData(player)

	if not dados or dados.coins < custo then
		return false, string.format("Custa %d moedas (você tem %d).", custo, dados and dados.coins or 0)
	end

	_G.PlayerDataManager.updateCoins(player, -custo)

	local nova = {}
	for _, entrada in ipairs(progresso.passives) do
		table.insert(nova, {
			id = entrada.id,
			rank = (entrada.id == idPassiva) and (entrada.rank + 1) or entrada.rank,
		})
	end

	local ok = _G.PlayerDataManager.setCharacterPassives(
		player,
		nomePersonagem,
		nova,
		slotsDoPersonagem(player, nomePersonagem)
	)

	if not ok then
		_G.PlayerDataManager.updateCoins(player, custo) -- devolve
		return false, "Não foi possível salvar."
	end

	aplicar(player)
	_G.PlayerDataManager.savePlayerData(player)

	local novoNivel = atual.rank + 1
	return true, string.format("%s subiu para o nível %d! (-%d moedas)", passiva.nome, novoNivel, custo), novoNivel
end

-- =====================================
-- API GLOBAL
-- =====================================

_G.PassiveSystem = {
	CONFIG = CONFIG,
	Catalogo = Catalogo,

	getEffects = especialDe, -- compatibilidade com scripts antigos
	reapply = function(player)
		aplicar(player)
	end,
	slots = slotsDisponiveis,
	slotsDoPersonagem = slotsDoPersonagem,
	podeEditar = podeEditar,

	emCombate = function(player)
		local t = ultimoDano[player]
		return t ~= nil and (os.clock() - t) <= CONFIG.COMBATE_JANELA
	end,
}

-- =====================================
-- DEBUG
-- =====================================

_G.DebugPassives = function(nomeJogador)
	local player = Players:FindFirstChild(nomeJogador)
	if not player then
		print("❌ Jogador não encontrado")
		return
	end

	local lista, equipado = passivasEquipadas(player)
	local stats, especial = calcular(player)

	print("\n========== PASSIVE SYSTEM V7 ==========")
	print(string.format("Jogador: %s | Personagem: %s", player.Name, equipado or "NENHUM"))
	print(
		string.format(
			"Slots: %d  (base %d + gamepass %s)",
			slotsDisponiveis(player),
			_G.CharacterLevel.getEquippedSlots(player) or 0,
			consultarGamepass(player) and ("+" .. CONFIG.SLOTS_EXTRAS) or "não possui"
		)
	)

	if not equipado then
		print("⚠️ SEM PERSONAGEM EQUIPADO — nenhuma passiva pode aplicar.")
		print("=====================================\n")
		return
	end

	print("\n-- EQUIPADAS --")
	if #lista == 0 then
		print("  (nenhuma)")
	end
	for _, entrada in ipairs(lista) do
		local p = Catalogo.obter(entrada.id)
		if p then
			print(
				string.format(
					"  %s %s — nível %d/%d [%s]",
					p.icone,
					p.nome,
					entrada.rank,
					Catalogo.MAX_NIVEL,
					p.tipo
				)
			)
			print(string.format("     %s", Catalogo.descricaoNoNivel(entrada.id, entrada.rank)))
			local proximo = Catalogo.custoDoNivel(entrada.rank)
			print(string.format("     %s", proximo and (proximo .. " moedas p/ o próximo") or "NÍVEL MÁXIMO"))
		end
	end

	print("\n-- ATRIBUTOS GERADOS --")
	local algum = false
	for nome, valor in pairs(stats) do
		algum = true
		print(string.format("  %-20s %+.2f", nome, valor))
	end
	if not algum then
		print("  (nenhum)")
	end

	if especial.chanceNegar > 0 or especial.chanceReverter > 0 then
		print("\n-- CHANCE --")
		print(string.format("  Negar dano ....... %.0f%%", especial.chanceNegar * 100))
		print(string.format("  Reverter dano .... %.0f%%", especial.chanceReverter * 100))
	end

	local temp = temporarias[player]
	if temp and next(temp) then
		print("\n-- TEMPORÁRIAS --")
		local agora = os.clock()
		for id, estado in pairs(temp) do
			local p = Catalogo.obter(id)
			if p then
				if estado.ativaAte and agora < estado.ativaAte then
					print(string.format("  %s ATIVA (%.1fs)", p.nome, estado.ativaAte - agora))
				elseif estado.recargaAte and agora < estado.recargaAte then
					print(string.format("  %s recarregando (%.1fs)", p.nome, estado.recargaAte - agora))
				end
			end
		end
	end

	print("=====================================\n")
end

print(string.format([[
╔══════════════════════════════════════════════════════╗
║  PASSIVE SYSTEM SERVER V8 — CARREGADO               ║
╠══════════════════════════════════════════════════════╣
║  SUBSTITUI: PassiveSystemServer V7                   ║
║  REMOVER:   PassiveSystemServer V7                   ║
║  * Só edita/melhora com personagem DESEQUIPADO       ║
║  DEPENDE DE: DataManager V8 + PassiveCatalog         ║
╠══════════════════════════════════════════════════════╣
║  * %2d passivas, níveis 1 a 10                        ║
║  * Upgrade por MOEDAS                                ║
║  * Temporárias com gatilho e recarga                 ║
║  * Negador (anula) e Reverso (devolve, exclusivo)    ║
║  * Gamepass %d -> +%d slots            ║
║  * VIGIA reaplica sozinho — sem "janela certa"       ║
╠══════════════════════════════════════════════════════╣
║  DEBUG: _G.DebugPassives("Nome")                     ║
╚══════════════════════════════════════════════════════╝
]], Catalogo.contar(), CONFIG.GAMEPASS_SLOTS, CONFIG.SLOTS_EXTRAS))
