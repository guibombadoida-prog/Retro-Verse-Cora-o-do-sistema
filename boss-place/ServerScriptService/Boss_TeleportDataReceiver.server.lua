-- ============================================
-- BOSS TELEPORT DATA RECEIVER V1 — QUEM ENTROU E EM QUAL SESSÃO
-- Coloque em ServerScriptService (PLACE DO CHEFÃO)
-- Nome: "Boss_TeleportDataReceiver"
-- SCRIPT NOVO — não substitui nada
-- DEPENDE DE: DataManager (cópia local, mesmo DATASTORE_NAME)
-- ============================================
-- Este é o PRIMEIRO script da cadeia do chefão. Sem ele nada nesta place
-- sabe qual chefe é a luta, quem faz parte da sessão, nem qual
-- personagem cada jogador trouxe.
--
-- O BossRaidServer_V2 da place principal já manda, via
-- options:SetTeleportData(...):
--     raidId, bossId, bossName, leaderUserId
--
-- ⚠️ O QUE ELE **NÃO** MANDA: o personagem equipado. A regra 2 (personagem
--    fixo até morrer) precisa dessa informação, e ela não vem no pacote.
--    Duas saídas, e usamos as duas em ordem:
--      1. se o TeleportData trouxer `personagens[userId]`, usa (é o que o
--         BossRaidServer_V3 passa a mandar);
--      2. senão, LÊ do DataStore local — o `equippedCharacter` está
--         salvo, porque o BossRaidServer chama savePlayerData em todos
--         os membros logo antes de teleportar.
--    A segunda saída é o que faz isto funcionar mesmo com a place
--    principal ainda no V2, sem exigir instalação sincronizada.
--
-- REGRA 8: quem desconhecer sai das listas de controle, e a sessão
-- CONTINUA. Nada aqui cancela a luta por saída de jogador.
--
-- REGRA 13: sessão de uso único. Não existe retomar — quem sai, sai.
-- Por isso `saiuDaSessao` é registrado e nunca limpo: se a mesma pessoa
-- reaparecer nesta place (só aconteceria por um teleporte novo), ela é
-- tratada como sessão nova, não como retorno.
--
-- REUTILIZADO:
-- • GetJoinData().TeleportData ..... padrão do próprio Roblox
-- • getPlayerData / savePlayerData . DataManager (cópia local)
-- • banner / _G API ................ padrão geral do projeto
-- ============================================

local Players = game:GetService("Players")

repeat
	task.wait()
until _G.PlayerDataManager

local CONFIG = {
	-- Segundos esperando os dados do jogador carregarem do DataStore
	-- antes de desistir e usar o que houver. Sem teto isso poderia
	-- pendurar a entrada de alguém para sempre.
	ESPERA_DADOS = 20,
}

-- =====================================
-- ESTADO DA SESSÃO
-- =====================================

local sessao = {
	bossId = nil,
	bossName = nil,
	raidId = nil,
	leaderUserId = 0,
	iniciadaEm = os.time(),
}

local membros = {} -- [player] = { personagemFixo, entrouEm }
local saiuDaSessao = {} -- [userId] = true (regra 13: nunca volta)

-- =====================================
-- LEITURA DO TELEPORT DATA
-- =====================================

local function lerTeleportData(player)
	local ok, dados = pcall(function()
		return player:GetJoinData().TeleportData
	end)
	if ok and type(dados) == "table" then
		return dados
	end
	return nil
end

-- A sessão é definida pelo PRIMEIRO jogador que chega com dados válidos.
-- Os seguintes não sobrescrevem: numa reserva de servidor todos vêm com o
-- mesmo pacote, e se um chegasse com dado corrompido não pode trocar o
-- chefe da luta no meio.
local function registrarSessao(dados)
	if sessao.bossId or not dados then
		return
	end
	if type(dados.bossId) ~= "string" and type(dados.bossId) ~= "number" then
		return
	end

	sessao.bossId = tostring(dados.bossId)
	sessao.bossName = tostring(dados.bossName or dados.bossId)
	sessao.raidId = dados.raidId and tostring(dados.raidId) or nil
	sessao.leaderUserId = tonumber(dados.leaderUserId) or 0

	print(string.format(
		"[BOSS RECEIVER V1] Sessão definida: chefe '%s' (id %s), raid %s",
		sessao.bossName,
		sessao.bossId,
		tostring(sessao.raidId)
	))
end

-- =====================================
-- PERSONAGEM FIXO (REGRA 2)
-- =====================================

local function esperarDados(player)
	local esperou = 0
	while not _G.PlayerDataManager.getPlayerData(player) and esperou < CONFIG.ESPERA_DADOS do
		task.wait(0.5)
		esperou += 0.5
	end
	return _G.PlayerDataManager.getPlayerData(player)
end

local function descobrirPersonagemFixo(player, dados)
	-- 1ª fonte: o pacote do teleporte (BossRaidServer_V3)
	if dados and type(dados.personagens) == "table" then
		local nome = dados.personagens[tostring(player.UserId)]
		if type(nome) == "string" and #nome > 0 then
			return nome, "TeleportData"
		end
	end

	-- 2ª fonte: DataStore compartilhado. Funciona porque o
	-- BossRaidServer salva todos os membros antes de teleportar.
	local playerData = esperarDados(player)
	local equipado = playerData and playerData.equippedCharacter
	if type(equipado) == "string" and #equipado > 0 then
		return equipado, "DataStore"
	end

	return nil, "nenhuma"
end

-- =====================================
-- ENTRADA E SAÍDA
-- =====================================

local function onPlayerAdded(player)
	local dados = lerTeleportData(player)
	registrarSessao(dados)

	if not dados then
		-- Entrou sem passar pelo fluxo de raid (teste no Studio, ou
		-- alguém caindo direto na place). Não é erro fatal: entra na
		-- sessão sem personagem fixo, e os outros scripts tratam isso.
		warn(string.format(
			"[BOSS RECEIVER V1] %s entrou SEM TeleportData — provável teste direto na place",
			player.Name
		))
	end

	task.spawn(function()
		local personagemFixo, fonte = descobrirPersonagemFixo(player, dados)

		membros[player] = {
			personagemFixo = personagemFixo,
			entrouEm = os.time(),
		}

		print(string.format(
			"[BOSS RECEIVER V1] %s entrou na sessão | personagem fixo: %s (fonte: %s)",
			player.Name,
			personagemFixo or "NENHUM",
			fonte
		))

		if not personagemFixo then
			warn(string.format(
				"[BOSS RECEIVER V1] ⚠️ %s sem personagem equipado — a regra 2 (personagem fixo) não tem o que travar",
				player.Name
			))
		end
	end)
end

-- REGRA 8: só limpa as listas. NENHUMA ação de cancelar a luta.
local function onPlayerRemoving(player)
	if membros[player] then
		print(string.format(
			"[BOSS RECEIVER V1] %s saiu da sessão — sem recompensa (regra 8). A luta continua.",
			player.Name
		))
	end
	membros[player] = nil
	saiuDaSessao[player.UserId] = true
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)

-- Quem já estava aqui quando este script subiu
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, player)
end

-- =====================================
-- API GLOBAL
-- =====================================

_G.BossSession = {
	-- Qual chefe é esta luta. Nil só se ninguém chegou com TeleportData.
	getBossId = function()
		return sessao.bossId
	end,
	getBossName = function()
		return sessao.bossName
	end,
	getRaidId = function()
		return sessao.raidId
	end,
	getInfo = function()
		return {
			bossId = sessao.bossId,
			bossName = sessao.bossName,
			raidId = sessao.raidId,
			leaderUserId = sessao.leaderUserId,
			iniciadaEm = sessao.iniciadaEm,
		}
	end,

	-- Jogadores que fazem parte da sessão E ainda estão aqui
	getPlayers = function()
		local lista = {}
		for player in pairs(membros) do
			if player.Parent then
				table.insert(lista, player)
			end
		end
		return lista
	end,
	contar = function()
		local n = 0
		for player in pairs(membros) do
			if player.Parent then
				n += 1
			end
		end
		return n
	end,
	estaNaSessao = function(player)
		return membros[player] ~= nil
	end,

	-- REGRA 2: personagem travado até morrer ou a luta acabar
	getPersonagemFixo = function(player)
		local m = membros[player]
		return m and m.personagemFixo or nil
	end,

	-- REGRA 13: já saiu uma vez = não retoma
	jaSaiu = function(userId)
		return saiuDaSessao[userId] == true
	end,
}

-- =====================================
-- DEBUG
-- =====================================

_G.DebugBossSession = function()
	print("\n========== DEBUG BOSS SESSION V1 ==========")
	print(string.format("Chefe: %s (id %s)", tostring(sessao.bossName), tostring(sessao.bossId)))
	print(string.format("Raid: %s | líder: %d", tostring(sessao.raidId), sessao.leaderUserId))
	print(string.format("Jogadores na sessão: %d", _G.BossSession.contar()))
	for player, m in pairs(membros) do
		print(string.format("  %s | personagem fixo: %s", player.Name, m.personagemFixo or "NENHUM"))
	end
	local saiu = 0
	for _ in pairs(saiuDaSessao) do
		saiu += 1
	end
	print(string.format("Saíram (não voltam, regra 13): %d", saiu))
	print("=========================================\n")
end

print([[
╔════════════════════════════════════════════════════╗
║  📥 BOSS TELEPORT DATA RECEIVER V1 CARREGADO       ║
╠════════════════════════════════════════════════════╣
║  SCRIPT NOVO (place do CHEFÃO)                     ║
║  Primeiro da cadeia: define a sessão e o roster    ║
╠════════════════════════════════════════════════════╣
║  Personagem fixo (regra 2) vem, em ordem:          ║
║   1. TeleportData.personagens (BossRaidServer V3)  ║
║   2. equippedCharacter do DataStore (fallback)     ║
║  O fallback faz funcionar mesmo com a place        ║
║  principal ainda no BossRaidServer V2              ║
╠════════════════════════════════════════════════════╣
║  REGRA 8: saída limpa listas, NÃO cancela a luta   ║
║  REGRA 13: quem sai não retoma a sessão            ║
╠════════════════════════════════════════════════════╣
║  DEBUG: _G.DebugBossSession()                       ║
╚════════════════════════════════════════════════════╝
]])
