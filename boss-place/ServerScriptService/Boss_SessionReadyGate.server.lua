-- ============================================
-- BOSS SESSION READY GATE V1 — GUI SÓ QUANDO TODOS CARREGAREM
-- Coloque em ServerScriptService (PLACE DO CHEFÃO)
-- Nome: "Boss_SessionReadyGate"
-- SCRIPT NOVO — não substitui nada
-- DEPENDE DE: Boss_TeleportDataReceiver_V1 (_G.BossSession),
--             DataManager (cópia local), LoadingScreenServer (cópia local)
-- ============================================
-- REGRA 3 das Diretrizes: ao entrar na place do chefe, nenhuma GUI de
-- personagens/tools aparece de imediato. O servidor só libera quando
-- TODOS os jogadores da sessão estiverem prontos — não apenas o
-- indivíduo.
--
-- Por que a barreira é do GRUPO e não de cada um: se cada jogador
-- liberasse ao próprio carregar, quem entrasse rápido já estaria mexendo
-- no inventário enquanto os outros ainda veem tela de carregamento. A
-- luta começaria desalinhada.
--
-- ⚠️ ISTO NÃO É O LoadingScreenServer, É UMA CAMADA ACIMA DELE.
--    O LoadingScreenServer resolve "ESTE jogador está pronto?" (dados
--    carregados + personagem existe) e some a tela dele. Aqui a pergunta
--    é outra: "TODOS já estão prontos?". Reaproveitamos o mesmo sinal de
--    prontidão individual e só somamos.
--
-- ANTI-TRAVA, e é a parte que importa: sem teto, um jogador com internet
-- ruim (ou que fechou o Roblox no meio do carregamento sem o servidor ter
-- percebido ainda) prenderia a sessão inteira para sempre, sem erro
-- nenhum no Output. Por isso existe TEMPO_MAXIMO: estourado o limite, o
-- gate libera com quem tem, e avisa quem faltou.
--
-- REGRA 8: se um jogador sai antes de ficar pronto, ele apenas sai da
-- conta de "total" — a sessão não trava esperando um ausente.
--
-- REUTILIZADO:
-- • Handshake de prontidão (LoadingStage/LoadingReady)
--   .................................. LoadingScreenServer_V2
-- • ensureRemote ..................... padrão geral do projeto
-- • Espera de dados do jogador ....... LoadingScreenServer_V2
-- ============================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

repeat
	task.wait()
until _G.PlayerDataManager

-- O receiver define quem faz parte da sessão. Sem ele não há "total" para
-- comparar, então esperamos por ele antes de qualquer conta.
repeat
	task.wait()
until _G.BossSession

local CONFIG = {
	-- Teto anti-trava. Passado isso, libera com quem estiver pronto.
	TEMPO_MAXIMO = 45,

	-- De quanto em quanto tempo reconfere. O gate é event-driven (libera
	-- assim que o último fica pronto); este laço existe só para o teto e
	-- para o caso de um evento se perder.
	INTERVALO = 1,

	-- Segundos esperando os dados de UM jogador antes de considerá-lo
	-- pronto de qualquer forma. Mesmo espírito do LoadingScreenServer.
	ESPERA_DADOS = 20,
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

-- Disparado UMA vez, para todos, quando a sessão está liberada.
-- O cliente (GUI de inventário) só se mostra ao receber isto.
local remoteSessaoLiberada = ensureRemote("BossSessionReady", "RemoteEvent")
-- Progresso ("2/4 prontos"), para a tela de carregamento contar
local remoteProgresso = ensureRemote("BossSessionProgress", "RemoteEvent")
-- O cliente pergunta se já liberou — cobre quem entrou depois do disparo
local remoteConsultar = ensureRemote("BossSessionQuery", "RemoteFunction")

-- =====================================
-- ESTADO
-- =====================================

local prontos = {} -- [player] = true
local liberado = false
local iniciadoEm = os.clock()

-- =====================================
-- PRONTIDÃO INDIVIDUAL
-- =====================================
-- Mesmo critério do LoadingScreenServer: dados carregados E personagem
-- existindo. "Pronto" aqui não é um timer, é estado real.

local function estaProntoDeVerdade(player)
	if not player.Parent then
		return false
	end
	if not _G.PlayerDataManager.getPlayerData(player) then
		return false
	end
	return player.Character ~= nil
end

local function marcarPronto(player)
	if prontos[player] then
		return
	end
	prontos[player] = true

	local n, total = 0, _G.BossSession.contar()
	for _ in pairs(prontos) do
		n += 1
	end

	print(string.format("[BOSS GATE V1] %s pronto (%d/%d)", player.Name, n, total))

	for _, p in ipairs(Players:GetPlayers()) do
		remoteProgresso:FireClient(p, n, total)
	end
end

local function aguardarProntidao(player)
	local esperou = 0
	while esperou < CONFIG.ESPERA_DADOS do
		if not player.Parent then
			return -- saiu; regra 8 cuida do resto
		end
		if estaProntoDeVerdade(player) then
			marcarPronto(player)
			return
		end
		task.wait(0.5)
		esperou += 0.5
	end

	-- Estourou a espera individual. Marca pronto de qualquer forma: é
	-- melhor liberar alguém sem dados completos do que travar a sessão
	-- toda por um jogador. O LoadingScreenServer segue o mesmo princípio.
	if player.Parent then
		warn(string.format(
			"[BOSS GATE V1] %s estourou a espera de dados (%ds) — marcado pronto para não travar a sessão",
			player.Name,
			CONFIG.ESPERA_DADOS
		))
		marcarPronto(player)
	end
end

-- =====================================
-- LIBERAÇÃO DA SESSÃO
-- =====================================

local function liberar(motivo, faltando)
	if liberado then
		return
	end
	liberado = true

	if faltando and #faltando > 0 then
		warn(string.format(
			"[BOSS GATE V1] Liberado por %s — NÃO ficaram prontos: %s",
			motivo,
			table.concat(faltando, ", ")
		))
	else
		print(string.format("[BOSS GATE V1] ✓ Sessão liberada (%s)", motivo))
	end

	for _, player in ipairs(Players:GetPlayers()) do
		remoteSessaoLiberada:FireClient(player)
	end
end

local function todosProntos()
	local total = _G.BossSession.contar()
	if total <= 0 then
		return false, {}
	end

	local faltando = {}
	for _, player in ipairs(_G.BossSession.getPlayers()) do
		if not prontos[player] then
			table.insert(faltando, player.Name)
		end
	end
	return #faltando == 0, faltando
end

-- =====================================
-- LAÇO DO GATE
-- =====================================

task.spawn(function()
	while not liberado do
		task.wait(CONFIG.INTERVALO)

		local ok, faltando = todosProntos()
		if ok then
			liberar("todos prontos", nil)
			break
		end

		if (os.clock() - iniciadoEm) >= CONFIG.TEMPO_MAXIMO then
			liberar(string.format("teto de %ds (anti-trava)", CONFIG.TEMPO_MAXIMO), faltando)
			break
		end
	end
end)

-- =====================================
-- EVENTOS DE JOGADOR
-- =====================================

local function onPlayerAdded(player)
	task.spawn(aguardarProntidao, player)

	player.CharacterAdded:Connect(function()
		-- Renascer não desfaz a prontidão: quem já entrou na luta
		-- continua liberado. Isto só cobre o primeiro spawn de quem
		-- ainda não estava pronto.
		if not prontos[player] and estaProntoDeVerdade(player) then
			marcarPronto(player)
		end
	end)
end

-- REGRA 8: sair só tira da conta. A sessão não espera ausente.
local function onPlayerRemoving(player)
	prontos[player] = nil
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)

for _, player in ipairs(Players:GetPlayers()) do
	onPlayerAdded(player)
end

-- Quem consultar depois da liberação recebe `true` na hora. Sem isto,
-- um cliente que entrasse tarde (ou perdesse o FireClient) ficaria com a
-- GUI escondida para sempre.
remoteConsultar.OnServerInvoke = function()
	return liberado
end

-- =====================================
-- API GLOBAL
-- =====================================
-- É isto que o script de spawn do chefe deve consultar antes de nascer:
-- a regra 10 manda travar o HP com a contagem de jogadores do instante do
-- spawn, e o spawn só deve acontecer depois do gate.

_G.BossGate = {
	estaLiberado = function()
		return liberado
	end,
	contarProntos = function()
		local n = 0
		for _ in pairs(prontos) do
			n += 1
		end
		return n
	end,
	-- Bloqueia até liberar (ou até o teto). Para o script de spawn do
	-- chefe chamar antes de instanciar o Model.
	aguardar = function()
		while not liberado do
			task.wait(0.25)
		end
		return true
	end,
}

_G.DebugBossGate = function()
	local ok, faltando = todosProntos()
	print("\n========== DEBUG BOSS GATE V1 ==========")
	print(string.format("Liberado: %s", tostring(liberado)))
	print(string.format("Prontos: %d / %d", _G.BossGate.contarProntos(), _G.BossSession.contar()))
	if not ok and #faltando > 0 then
		print("Faltando: " .. table.concat(faltando, ", "))
	end
	print(string.format("Tempo desde o início: %.1fs (teto %ds)", os.clock() - iniciadoEm, CONFIG.TEMPO_MAXIMO))
	print("=========================================\n")
end

print([[
╔════════════════════════════════════════════════════╗
║  🚪 BOSS SESSION READY GATE V1 CARREGADO           ║
╠════════════════════════════════════════════════════╣
║  SCRIPT NOVO (place do CHEFÃO)                     ║
║  DEPENDE DE: Boss_TeleportDataReceiver_V1          ║
╠════════════════════════════════════════════════════╣
║  REGRA 3: GUI de inventário só quando TODOS os     ║
║  jogadores da sessão estiverem prontos             ║
║  • Camada ACIMA do LoadingScreenServer: ele cuida  ║
║    do indivíduo, este soma o grupo                 ║
║  • Anti-trava de 45s: um jogador com internet ruim ║
║    não prende a sessão inteira                     ║
╠════════════════════════════════════════════════════╣
║  Spawn do chefe deve chamar _G.BossGate.aguardar() ║
║  antes de nascer (regra 10 trava o HP no spawn)    ║
╠════════════════════════════════════════════════════╣
║  DEBUG: _G.DebugBossGate()                          ║
╚════════════════════════════════════════════════════╝
]])
