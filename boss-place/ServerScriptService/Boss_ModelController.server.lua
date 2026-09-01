-- ============================================
-- BOSS MODEL CONTROLLER V1 — CÉREBRO DO CHEFE
-- Coloque DENTRO do Model do chefe (não em ServerScriptService)
-- Nome: "Boss_ModelController"
-- SCRIPT NOVO — não substitui nada do nosso lado
-- ============================================
-- ⚠️ SUBSTITUI, NO MODELO BAIXADO: KillScript (+ Delete), Pathfinding,
--    AI e AInot. APAGUE OS QUATRO. Rodar qualquer um deles junto com
--    este script significa dois cérebros disputando o mesmo Humanoid.
--
-- Por que substituir em vez de remendar (ver
-- docs/Auditoria_Modelo_Boss_Angel.md):
--
--   • O KillScript matava com `Humanoid.Health = 0`, o que as Diretrizes
--     proíbem e o que pula TODO o nosso pipeline: _G.CanDamagePlayer, o
--     Boss_NoPvpProtection, o StatService, as passivas de Negação e
--     Reverso, e o DamageAttribution. Não dava para consertar por cima —
--     o modo de matar era o problema.
--   • A condição de alvo dele estava quebrada de um jeito que fazia o
--     chefe poder matar a si mesmo (o `FindFirstChild("")` sempre nil
--     anulava as checagens de Model e de "não sou eu").
--   • O Pathfinding não usava PathfindingService: era MoveTo em linha
--     reta, com Ray de comprimento infinito e a API depreciada
--     FindPartOnRayWithIgnoreList, varrendo a Workspace inteira todo
--     frame.
--
-- O QUE ESTE SCRIPT FAZ:
--   1. espera o gate da sessão (regra 3) antes de o chefe existir
--   2. trava o HP no spawn pela contagem de jogadores (regra 10)
--   3. persegue com PathfindingService de verdade, ignorando quem está
--      na zona segura
--   4. dá dano por TakeDamage, com cooldown e teto por golpe
--   5. ao morrer, chama _G.BossExit.vitoria() (regra 7)
--
-- O QUE ELE **NÃO** FAZ, de propósito: animação, som e projétil. Isso
-- continua com os scripts do modelo (AnimateSauce, ChatScript,
-- AttackScript, gen*), que são a parte boa do que veio pronto.
--
-- DEPENDE DE: Boss_TeleportDataReceiver_V1 (_G.BossSession),
--             BossConfigServer_V1 (_G.BossConfig),
--             Boss_SessionReadyGate_V1 (_G.BossGate),
--             Boss_ExitTeleport_V1 (_G.BossExit)
-- ============================================

local Players = game:GetService("Players")
local PathfindingService = game:GetService("PathfindingService")
local RunService = game:GetService("RunService")

local chefe = script.Parent
local humanoid = chefe:WaitForChild("Humanoid", 15)
local raiz = chefe:WaitForChild("HumanoidRootPart", 15)

if not humanoid or not raiz then
	warn("[BOSS CTRL V1] Model sem Humanoid ou HumanoidRootPart — controlador desligado")
	return
end

local CONFIG = {
	-- Alcance do golpe de contato. O KillScript usava 10 studs, mas como
	-- morte instantânea; aqui é dano com cooldown.
	ALCANCE_MELEE = 10,
	DANO_MELEE = 45,
	COOLDOWN_MELEE = 1.2,

	-- Teto por golpe, em fração da vida MÁXIMA do alvo. Mesma ideia do
	-- MAX_HIT_PERCENT do StatService: impede que qualquer combinação
	-- futura mate alguém de um golpe só.
	TETO_POR_GOLPE = 0.40,

	-- De quanto em quanto tempo reprocura alvo. NÃO é por frame: o
	-- modelo original varria a Workspace inteira a cada `wait()`, e isso
	-- é custo puro o tempo todo.
	INTERVALO_ALVO = 0.5,

	-- Recalcular rota é caro. Só refaz se o alvo andou mais que isto.
	DISTANCIA_RECALCULO = 8,

	ALCANCE_BUSCA = 300,

	AGENTE = {
		AgentRadius = 3,
		AgentHeight = 6,
		AgentCanJump = true,
	},
}

-- =====================================
-- ESPERA DAS DEPENDÊNCIAS
-- =====================================

local function esperarPor(nome, segundos)
	local esperou = 0
	while not _G[nome] and esperou < segundos do
		task.wait(0.25)
		esperou += 0.25
	end
	return _G[nome] ~= nil
end

-- =====================================
-- ALVOS
-- =====================================

-- Só jogador conta como alvo, e só fora da zona segura.
--
-- O modelo original mirava em qualquer Model com Humanoid — o que
-- incluía outros NPCs, as fases irmãs do próprio chefe, e (por causa do
-- bug da condição) o próprio chefe.
local function alvoValido(player)
	local personagem = player.Character
	if not personagem then
		return nil
	end

	local hum = personagem:FindFirstChildOfClass("Humanoid")
	local hrp = personagem:FindFirstChild("HumanoidRootPart")
	if not hum or not hrp or hum.Health <= 0 then
		return nil
	end

	-- Zona segura: mesma tag que o resto do projeto respeita
	if personagem:FindFirstChild("InSafeZone") then
		return nil
	end

	return hrp, hum
end

local function acharAlvo()
	local melhorHrp, melhorHum, melhorDist = nil, nil, CONFIG.ALCANCE_BUSCA

	-- Se o receiver da sessão existe, só quem está NA SESSÃO é alvo.
	-- Sem ele (teste solto no Studio), cai para todos os jogadores.
	local candidatos = Players:GetPlayers()
	if _G.BossSession and _G.BossSession.getPlayers then
		local daSessao = _G.BossSession.getPlayers()
		if #daSessao > 0 then
			candidatos = daSessao
		end
	end

	for _, player in ipairs(candidatos) do
		local hrp, hum = alvoValido(player)
		if hrp then
			local dist = (hrp.Position - raiz.Position).Magnitude
			if dist < melhorDist then
				melhorHrp, melhorHum, melhorDist = hrp, hum, dist
			end
		end
	end

	return melhorHrp, melhorHum, melhorDist
end

-- =====================================
-- DANO
-- =====================================

local ultimoGolpe = 0

-- Sempre TakeDamage, nunca Health = 0. É o que mantém o chefe dentro do
-- pipeline: as passivas de Negação/Reverso e o DamageAttribution
-- escutam variação de vida, e zerar direto passaria por cima delas.
local function bater(hum)
	local agora = os.clock()
	if agora - ultimoGolpe < CONFIG.COOLDOWN_MELEE then
		return
	end
	ultimoGolpe = agora

	local dano = CONFIG.DANO_MELEE
	if hum.MaxHealth > 0 then
		dano = math.min(dano, hum.MaxHealth * CONFIG.TETO_POR_GOLPE)
	end

	hum:TakeDamage(dano)
end

-- =====================================
-- PERSEGUIÇÃO COM PATHFINDING DE VERDADE
-- =====================================

local caminho = PathfindingService:CreatePath(CONFIG.AGENTE)
local waypoints = {}
local indiceWaypoint = 1
local ultimaPosAlvo = nil

local function recalcular(destino)
	local ok = pcall(function()
		caminho:ComputeAsync(raiz.Position, destino)
	end)

	if not ok or caminho.Status ~= Enum.PathStatus.Success then
		-- Rota falhou (alvo em cima de vazio, por exemplo). Anda na
		-- direção dele mesmo assim, em vez de congelar.
		humanoid:MoveTo(destino)
		waypoints = {}
		return false
	end

	waypoints = caminho:GetWaypoints()
	indiceWaypoint = 2 -- 1 é a posição atual
	ultimaPosAlvo = destino
	return true
end

local function seguir()
	if #waypoints == 0 or indiceWaypoint > #waypoints then
		return
	end

	local wp = waypoints[indiceWaypoint]
	if wp.Action == Enum.PathWaypointAction.Jump then
		humanoid.Jump = true
	end
	humanoid:MoveTo(wp.Position)
end

humanoid.MoveToFinished:Connect(function(chegou)
	if chegou and indiceWaypoint < #waypoints then
		indiceWaypoint += 1
		seguir()
	end
end)

caminho.Blocked:Connect(function(bloqueado)
	if bloqueado >= indiceWaypoint and ultimaPosAlvo then
		recalcular(ultimaPosAlvo)
		seguir()
	end
end)

-- =====================================
-- MORTE DO CHEFE (REGRA 7)
-- =====================================

local morreu = false

humanoid.Died:Connect(function()
	if morreu then
		return
	end
	morreu = true

	print("[BOSS CTRL V1] 🏆 Chefe derrotado — acionando a saída com recompensa")

	if _G.BossExit and _G.BossExit.vitoria then
		_G.BossExit.vitoria()
	else
		warn("[BOSS CTRL V1] ⚠️ Boss_ExitTeleport ausente — ninguém vai receber recompensa nem voltar")
	end
end)

-- =====================================
-- BOOT
-- =====================================

task.spawn(function()
	-- REGRA 3: o chefe não nasce antes de todos estarem prontos
	if esperarPor("BossGate", 60) then
		_G.BossGate.aguardar()
	else
		warn("[BOSS CTRL V1] Boss_SessionReadyGate ausente — seguindo sem o gate")
	end

	-- REGRA 10: HP travado no spawn, pela contagem DAQUELE instante.
	-- Desconexão no meio da luta não recalcula para baixo, porque isto
	-- roda uma vez só.
	local jogadores = 1
	if _G.BossSession and _G.BossSession.contar then
		jogadores = math.max(1, _G.BossSession.contar())
	end

	if esperarPor("BossConfig", 30) then
		local bossId = _G.BossSession and _G.BossSession.getBossId() or "desconhecido"
		local hp = _G.BossConfig.calcularHp(bossId, jogadores)
		humanoid.MaxHealth = hp
		humanoid.Health = hp
		print(string.format(
			"[BOSS CTRL V1] HP travado em %d para %d jogador(es) — chefe '%s'",
			hp, jogadores, tostring(bossId)
		))
	else
		warn("[BOSS CTRL V1] ⚠️ BossConfigServer ausente — HP fica como está no Model")
	end

	-- ---------- LAÇO PRINCIPAL ----------
	-- Não é por frame: o modelo original rodava `while wait() do` com uma
	-- varredura da Workspace inteira dentro, e isso é custo constante.
	while not morreu and chefe.Parent do
		task.wait(CONFIG.INTERVALO_ALVO)

		if humanoid.Health <= 0 then
			break
		end

		local hrp, hum, dist = acharAlvo()

		if not hrp then
			-- Ninguém alcançável (todos na zona segura, ou mortos)
			humanoid:MoveTo(raiz.Position)
			waypoints = {}
		elseif dist <= CONFIG.ALCANCE_MELEE then
			bater(hum)
			humanoid:MoveTo(hrp.Position)
		else
			-- Só recalcula se o alvo realmente andou. Recalcular a cada
			-- meio segundo sem necessidade é o que deixa a IA cara.
			if not ultimaPosAlvo or (hrp.Position - ultimaPosAlvo).Magnitude > CONFIG.DISTANCIA_RECALCULO then
				recalcular(hrp.Position)
			end
			seguir()
		end
	end
end)

-- =====================================
-- DEBUG
-- =====================================

_G.DebugBossCtrl = function()
	local hrp, _, dist = acharAlvo()
	print("\n========== DEBUG BOSS CONTROLLER V1 ==========")
	print(string.format("Chefe: %s | HP %.0f/%.0f", chefe.Name, humanoid.Health, humanoid.MaxHealth))
	print(string.format("Morreu: %s", tostring(morreu)))
	if hrp then
		print(string.format("Alvo atual: %s a %.1f studs", hrp.Parent.Name, dist))
	else
		print("Alvo atual: nenhum (todos na zona segura, mortos ou fora de alcance)")
	end
	print(string.format("Waypoints na rota: %d (no %d)", #waypoints, indiceWaypoint))
	print("=========================================\n")
end

print([[
╔════════════════════════════════════════════════════╗
║  🧠 BOSS MODEL CONTROLLER V1 CARREGADO             ║
╠════════════════════════════════════════════════════╣
║  ⚠️ APAGUE do modelo baixado: KillScript (+Delete),║
║     Pathfinding, AI e AInot — este substitui os 4  ║
╠════════════════════════════════════════════════════╣
║  • Dano por TakeDamage, NUNCA Health = 0           ║
║  • Só mira JOGADOR, e nunca quem está na zona      ║
║    segura (tag InSafeZone)                         ║
║  • PathfindingService de verdade, com recálculo    ║
║    só quando o alvo anda                           ║
║  • HP travado no spawn pela contagem (regra 10)    ║
║  • Ao morrer chama _G.BossExit.vitoria() (regra 7) ║
╠════════════════════════════════════════════════════╣
║  DEBUG: _G.DebugBossCtrl()                          ║
╚════════════════════════════════════════════════════╝
]])
