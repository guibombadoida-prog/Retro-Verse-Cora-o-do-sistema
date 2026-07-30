-- ============================================
-- BOSS CONFIG SERVER V1 — CONFIG DE CHEFÃO SEM ABRIR O STUDIO
-- Coloque em ServerScriptService (PLACE DO CHEFÃO)
-- Nome: "BossConfigServer"
-- SCRIPT NOVO — não substitui nada
-- DEPENDE DE: DataManager (cópia local, mesmo DATASTORE_NAME),
--             AdminRegistryServer (cópia local, para _G.AdminRegistry)
-- ============================================
-- REGRA 12 das Diretrizes: no Studio só nasce a estrutura; os VALORES de
-- cada chefe são editados em jogo e salvos em DataStore próprio,
-- sincronizados entre servidores por MessagingService.
--
-- É um ConfigServer ÚNICO para todos os chefes, não um por chefe — a
-- própria diretriz permite ("ou um BossConfigServer único"), e é o mesmo
-- desenho por `id` que o CharacterCatalogServer e o
-- AchievementSystemServer já usam. Um script por chefe significaria
-- copiar esta lógica inteira a cada chefe novo, e a primeira cópia que
-- divergisse viraria bug silencioso.
--
-- O QUE FICA CONFIGURÁVEL POR CHEFE (regras 10, 6, 4 e 7):
--   hpBase / hpPorJogador ... escala de vida travada no spawn (regra 10)
--   recompensa .............. personagem-prêmio e/ou badgeId (regra 7)
--   musicas ................. faixa por evento (regra 6)
--   dialogo ................. passos da caixa de regras (regra 4)
--
-- REUTILIZADO (nada criado do zero):
-- • Guarda de JobId no MessagingService .... CharacterCatalogServer_V5
-- • ensureRemote / banner / _G API ......... padrão geral do projeto
-- • isAdmin com fallback pro DONO .......... AwakeningSystemServer_V2
-- • Parent = nil no lugar de :Destroy() .... regra do projeto
-- ============================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")
local MessagingService = game:GetService("MessagingService")

local FALLBACK_OWNER_ID = 1595442496

local CONFIG = {
	-- DataStore PRÓPRIO do sistema de chefões. Não é o do jogador —
	-- aqui vive a configuração dos chefes, não progresso de ninguém.
	STORE_NAME = "RVBossConfigV1",
	SYNC_TOPIC = "RVBossConfigSync",

	-- Valores usados quando um chefe ainda não tem config salva.
	-- Existem para a place nunca subir sem HP nenhum (a regra do projeto
	-- proíbe deixar o chefe no 100 de NPC comum).
	PADRAO = {
		hpBase = 5000,
		hpPorJogador = 2500,
		recompensaPersonagem = "",
		recompensaBadgeId = 0,
		musicas = {},
		dialogo = {},
	},
}

local store = DataStoreService:GetDataStore(CONFIG.STORE_NAME)

-- =====================================
-- ADMIN
-- =====================================

local function isAdmin(player)
	if _G.AdminRegistry then
		return _G.AdminRegistry.isAdmin(player)
	end
	-- Sem o AdminRegistryServer copiado para esta place, só o DONO edita.
	-- Preferir isso a liberar para todos, obviamente.
	return player ~= nil and player.UserId == FALLBACK_OWNER_ID
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

local remoteGetConfig = ensureRemote("BossGetConfig", "RemoteFunction")
local remoteAdminSet = ensureRemote("BossAdminSetConfig", "RemoteFunction")
local remoteAdminList = ensureRemote("BossAdminListConfigs", "RemoteFunction")
local remoteAdminRemove = ensureRemote("BossAdminRemoveConfig", "RemoteFunction")

-- =====================================
-- ESTADO
-- =====================================

local configs = {} -- [bossId] = config

-- =====================================
-- DATASTORE
-- =====================================

local function chaveDe(bossId)
	return "boss_" .. tostring(bossId)
end

local function salvarIndice()
	local ids = {}
	for id in pairs(configs) do
		table.insert(ids, id)
	end
	table.sort(ids)
	pcall(function()
		store:SetAsync("index", ids)
	end)
end

local function carregarIndice()
	local ok, lista = pcall(function()
		return store:GetAsync("index")
	end)
	if ok and type(lista) == "table" then
		return lista
	end
	return {}
end

local function salvarConfig(cfg)
	pcall(function()
		store:SetAsync(chaveDe(cfg.bossId), cfg)
	end)
	salvarIndice()
end

local function carregarConfig(bossId)
	local ok, cfg = pcall(function()
		return store:GetAsync(chaveDe(bossId))
	end)
	if ok and type(cfg) == "table" then
		return cfg
	end
	return nil
end

-- =====================================
-- NORMALIZAÇÃO
-- =====================================
-- Config vinda do painel é dado de cliente: nada entra sem passar por
-- aqui. Campo faltando cai no padrão em vez de virar nil no meio de uma
-- conta de HP.

local function normalizar(bruto, bossId)
	bruto = type(bruto) == "table" and bruto or {}
	local p = CONFIG.PADRAO

	local hpBase = tonumber(bruto.hpBase) or p.hpBase
	local hpPorJogador = tonumber(bruto.hpPorJogador) or p.hpPorJogador

	local musicas = {}
	if type(bruto.musicas) == "table" then
		-- Só eventos conhecidos, e só id numérico: entrada errada aqui
		-- viraria SoundId inválido tocando silêncio sem erro nenhum.
		for _, evento in ipairs({ "dialogo", "fase1", "transicao", "fase2", "fase3", "vitoria", "derrota" }) do
			local id = tonumber(bruto.musicas[evento])
			if id and id > 0 then
				musicas[evento] = id
			end
		end
	end

	local dialogo = {}
	if type(bruto.dialogo) == "table" then
		for _, passo in ipairs(bruto.dialogo) do
			if type(passo) == "string" and #passo > 0 then
				table.insert(dialogo, passo)
			end
		end
	end

	return {
		bossId = tostring(bossId),
		nome = tostring(bruto.nome or bossId),
		-- Piso de 1 para o chefe nunca nascer com HP zero ou negativo
		hpBase = math.max(1, math.floor(hpBase)),
		hpPorJogador = math.max(0, math.floor(hpPorJogador)),
		recompensaPersonagem = tostring(bruto.recompensaPersonagem or p.recompensaPersonagem),
		recompensaBadgeId = math.max(0, math.floor(tonumber(bruto.recompensaBadgeId) or 0)),
		musicas = musicas,
		dialogo = dialogo,
		editadoPor = bruto.editadoPor or "?",
		editadoEm = bruto.editadoEm or os.time(),
	}
end

-- =====================================
-- SYNC ENTRE SERVIDORES
-- =====================================

local function publicar(acao, bossId, adminName)
	pcall(function()
		MessagingService:PublishAsync(CONFIG.SYNC_TOPIC, {
			acao = acao,
			bossId = bossId,
			admin = adminName,
			jobId = game.JobId, -- guarda contra processar o próprio eco
		})
	end)
end

pcall(function()
	MessagingService:SubscribeAsync(CONFIG.SYNC_TOPIC, function(mensagem)
		local d = mensagem.Data
		if type(d) ~= "table" or d.jobId == game.JobId then
			return
		end
		if d.acao == "set" then
			local cfg = carregarConfig(d.bossId)
			if cfg then
				configs[d.bossId] = cfg
			end
		elseif d.acao == "remove" then
			configs[d.bossId] = nil
		end
	end)
end)

-- =====================================
-- API GLOBAL
-- =====================================

-- A config NUNCA volta nil: sem nada salvo, devolve o padrão. Os scripts
-- que consomem (HP no spawn, música, diálogo, recompensa) não precisam
-- ter caminho de erro para "chefe sem config".
local function obter(bossId)
	bossId = tostring(bossId or "")
	if configs[bossId] then
		return configs[bossId]
	end
	return normalizar(nil, bossId)
end

_G.BossConfig = {
	CONFIG = CONFIG,
	obter = obter,
	listar = function()
		return configs
	end,

	-- REGRA 10: o HP é calculado UMA vez, no spawn, com a quantidade de
	-- jogadores daquele instante — e fica travado. Quem chama isto é o
	-- script de spawn do chefe, uma única vez.
	calcularHp = function(bossId, quantidadeJogadores)
		local cfg = obter(bossId)
		local n = math.max(1, math.floor(tonumber(quantidadeJogadores) or 1))
		return cfg.hpBase + (cfg.hpPorJogador * n), cfg
	end,
}

-- =====================================
-- REMOTES: LEITURA (público) E ADMIN
-- =====================================

remoteGetConfig.OnServerInvoke = function(_, bossId)
	local cfg = obter(bossId)
	-- O cliente recebe só o que a tela usa. hpBase/hpPorJogador ficam de
	-- fora de propósito: é informação de balanceamento, não de interface.
	return {
		bossId = cfg.bossId,
		nome = cfg.nome,
		musicas = cfg.musicas,
		dialogo = cfg.dialogo,
	}
end

remoteAdminSet.OnServerInvoke = function(player, bossId, bruto)
	if not isAdmin(player) then
		player:Kick("Tentativa não autorizada de uso de comandos admin")
		return false, "Sem permissão!"
	end
	if type(bossId) ~= "string" or #bossId < 1 then
		return false, "ID do chefe inválido!"
	end

	local cfg = normalizar(bruto, bossId)
	cfg.editadoPor = player.Name
	cfg.editadoEm = os.time()

	configs[cfg.bossId] = cfg
	salvarConfig(cfg)
	publicar("set", cfg.bossId, player.Name)

	print(string.format("[BOSS CONFIG V1] %s salvou a config de '%s' (HP %d + %d/jogador)",
		player.Name, cfg.bossId, cfg.hpBase, cfg.hpPorJogador))

	return true, "Config salva em todos os servidores!"
end

remoteAdminRemove.OnServerInvoke = function(player, bossId)
	if not isAdmin(player) then
		player:Kick("Tentativa não autorizada de uso de comandos admin")
		return false, "Sem permissão!"
	end
	if type(bossId) ~= "string" then
		return false, "ID inválido!"
	end

	configs[bossId] = nil
	pcall(function()
		store:RemoveAsync(chaveDe(bossId))
	end)
	salvarIndice()
	publicar("remove", bossId, player.Name)

	return true, "Config removida. O chefe volta a usar os valores padrão."
end

remoteAdminList.OnServerInvoke = function(player)
	if not isAdmin(player) then
		return {}
	end
	local lista = {}
	for _, cfg in pairs(configs) do
		table.insert(lista, cfg)
	end
	return lista
end

-- =====================================
-- BOOT
-- =====================================

task.spawn(function()
	local ids = carregarIndice()
	local carregadas = 0
	for _, id in ipairs(ids) do
		local cfg = carregarConfig(id)
		if cfg then
			configs[tostring(id)] = cfg
			carregadas += 1
		end
	end
	print(string.format("[BOSS CONFIG V1] ✓ %d config(s) de chefe carregada(s)", carregadas))
end)

-- =====================================
-- DEBUG
-- =====================================

_G.DebugBossConfig = function()
	print("\n========== DEBUG BOSS CONFIG V1 ==========")
	local algum = false
	for id, cfg in pairs(configs) do
		algum = true
		print(string.format(
			"  %s | HP %d + %d/jogador | prêmio: %s | badge: %d | músicas: %d | diálogo: %d passo(s)",
			id,
			cfg.hpBase,
			cfg.hpPorJogador,
			cfg.recompensaPersonagem ~= "" and cfg.recompensaPersonagem or "(nenhum)",
			cfg.recompensaBadgeId,
			#(function()
				local t = {}
				for _ in pairs(cfg.musicas) do
					table.insert(t, 1)
				end
				return t
			end)(),
			#cfg.dialogo
		))
	end
	if not algum then
		print("  (nenhuma config salva — todos os chefes usam o padrão)")
		print(string.format("  padrão: HP %d + %d/jogador", CONFIG.PADRAO.hpBase, CONFIG.PADRAO.hpPorJogador))
	end
	print("=========================================\n")
end

print([[
╔════════════════════════════════════════════════════╗
║  ⚙️ BOSS CONFIG SERVER V1 CARREGADO                ║
╠════════════════════════════════════════════════════╣
║  SCRIPT NOVO (place do CHEFÃO)                     ║
║  DEPENDE DE: DataManager + AdminRegistryServer     ║
║              (cópias locais nesta place)           ║
╠════════════════════════════════════════════════════╣
║  REGRA 12: config em jogo, sem abrir o Studio      ║
║  • hpBase / hpPorJogador (regra 10)                ║
║  • recompensa: personagem e/ou badge (regra 7)     ║
║  • músicas por evento (regra 6)                    ║
║  • passos da caixa de diálogo (regra 4)            ║
║  Um ConfigServer para TODOS os chefes, por id      ║
╠════════════════════════════════════════════════════╣
║  DEBUG: _G.DebugBossConfig()                        ║
╚════════════════════════════════════════════════════╝
]])
