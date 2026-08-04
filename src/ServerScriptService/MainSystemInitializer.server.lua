-- ============================================
-- SISTEMA PRINCIPAL DE INICIALIZAÇÃO E CONEXÃO V2
-- Coloque em ServerScriptService
-- Nome: "MainSystemInitializer"
-- SUBSTITUI: MainSystemInitializer V1
-- ============================================
-- (V2) ALTERAÇÕES:
-- • REMOVIDO o loop duplicado de sincronização (setupGlobalSync) —
--   agora o ÚNICO dono do sync de UpdateStats é o GlobalSync_V2
--   (antes o UpdateStats era disparado 2x a cada 5s)
-- • REMOVIDAS as cópias duplicadas de _G.DebugPlayerStatus,
--   _G.TeleportToSafeZone e _G.ForceSelectCharacter
--   (donos agora: GlobalSync_V2) e de _G.ListAllPlayers
--   (dono: SpawnSystem_V7) — fim da disputa por ordem de load
-- • Proteção contra DUPLO EMBRULHO de _G.SelectCharacterFunction
--   (o monitor reconectava e embrulhava a função de novo,
--   fazendo OnCharacterSelected disparar 2x)
-- • wait()/spawn() -> task.wait()/task.spawn() (conformidade)
-- • Mantido aqui (dono único): _G.ResetPlayerBarrier
-- ============================================

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Players = game:GetService("Players")

print([[
╔════════════════════════════════════════════╗
║   INICIALIZANDO SISTEMA PRINCIPAL V2      ║
╚════════════════════════════════════════════╝
]])

-- =====================================
-- CRIAR ESTRUTURA DE PASTAS
-- =====================================

local function createFolderStructure()
	print("[INIT V2] Criando estrutura de pastas...")

	local folders = {
		-- ReplicatedStorage
		{ parent = ReplicatedStorage, name = "Remotes" },
		{ parent = ReplicatedStorage, name = "Events" },
		{ parent = ReplicatedStorage, name = "Characters" },
		{ parent = ReplicatedStorage, name = "Assets" },
		{ parent = ReplicatedStorage, name = "Modules" },

		-- ServerStorage
		{ parent = ServerStorage, name = "ServerAssets" },
		{ parent = ServerStorage, name = "ServerModules" },
		{ parent = ServerStorage, name = "PlayerData" },
		{ parent = ServerStorage, name = "TeamData" },
	}

	for _, folderInfo in ipairs(folders) do
		local folder = folderInfo.parent:FindFirstChild(folderInfo.name)
		if not folder then
			folder = Instance.new("Folder")
			folder.Name = folderInfo.name
			folder.Parent = folderInfo.parent
			print("  ✓ Pasta criada: " .. folderInfo.name)
		end
	end

	return true
end

-- =====================================
-- CRIAR TODOS OS REMOTES
-- =====================================

local function createAllRemotes()
	print("[INIT V2] Criando RemoteEvents e RemoteFunctions...")

	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local events = ReplicatedStorage:WaitForChild("Events")

	local remoteList = {
		-- RemoteFunctions (para requisições com resposta)
		{ type = "RemoteFunction", name = "SelectCharacter", parent = remotes },
		{ type = "RemoteFunction", name = "GetPlayerData", parent = remotes },
		{ type = "RemoteFunction", name = "CreateTeam", parent = remotes },
		{ type = "RemoteFunction", name = "ClaimDailyReward", parent = remotes },
		{ type = "RemoteFunction", name = "GetDailyRewardStatus", parent = remotes },
		{ type = "RemoteFunction", name = "CheckBadge", parent = remotes },
		{ type = "RemoteFunction", name = "GetRecruitJourney", parent = remotes },
		{ type = "RemoteFunction", name = "ClaimRecruitJourney", parent = remotes },

		-- RemoteEvents (para comunicação unidirecional)
		{ type = "RemoteEvent", name = "PurchaseCharacter", parent = remotes },
		{ type = "RemoteEvent", name = "UpdateStats", parent = remotes },
		{ type = "RemoteEvent", name = "SyncCharacterState", parent = remotes },
		{ type = "RemoteEvent", name = "SpectatorMode", parent = remotes },
		{ type = "RemoteEvent", name = "ToggleSpectator", parent = remotes },
		{ type = "RemoteEvent", name = "UpdateCharacterState", parent = remotes },
		{ type = "RemoteEvent", name = "InviteToTeam", parent = remotes },
		{ type = "RemoteEvent", name = "RespondToInvite", parent = remotes },
		{ type = "RemoteEvent", name = "LeaveTeam", parent = remotes },
		{ type = "RemoteEvent", name = "UpdateTeamList", parent = remotes },
		{ type = "RemoteEvent", name = "TutorialComplete", parent = remotes },
		{ type = "RemoteEvent", name = "ForceSpawn", parent = remotes },
		{ type = "RemoteEvent", name = "RedeemGamepassCharacter", parent = remotes },
		{ type = "RemoteEvent", name = "RecruitJourneyUpdate", parent = remotes },

		-- Events (para eventos do jogo)
		{ type = "RemoteEvent", name = "PlayerKilled", parent = events },
		{ type = "RemoteEvent", name = "ShowNotification", parent = events },
		{ type = "RemoteEvent", name = "GameStateChanged", parent = events },

		-- Admin Remotes
		{ type = "RemoteEvent", name = "AdminGiveCoins", parent = remotes },
		{ type = "RemoteEvent", name = "AdminGiveBounty", parent = remotes },
		{ type = "RemoteEvent", name = "AdminGiveCharacter", parent = remotes },
		{ type = "RemoteEvent", name = "AdminGiveAllCharacters", parent = remotes },
		{ type = "RemoteEvent", name = "AdminResetData", parent = remotes },
		{ type = "RemoteEvent", name = "AdminTeleport", parent = remotes },
	}

	local createdCount = 0
	for _, remoteInfo in ipairs(remoteList) do
		local remote = remoteInfo.parent:FindFirstChild(remoteInfo.name)
		if not remote then
			if remoteInfo.type == "RemoteFunction" then
				remote = Instance.new("RemoteFunction")
			else
				remote = Instance.new("RemoteEvent")
			end
			remote.Name = remoteInfo.name
			remote.Parent = remoteInfo.parent
			createdCount = createdCount + 1
			print("  ✓ Remote criado: " .. remoteInfo.name)
		end
	end

	print("  Total de remotes criados: " .. createdCount)
	return true
end

-- =====================================
-- VERIFICAR SISTEMAS CARREGADOS
-- =====================================

local function waitForSystems()
	print("[INIT V2] Aguardando sistemas carregarem...")

	local systems = {
		{ name = "PlayerDataManager" },
		{ name = "SetSpectatorMode", optional = true },
		{ name = "OnCharacterSelected", optional = true },
		{ name = "GetPlayerTeam", optional = true },
		{ name = "RegisterAttack", optional = true },
	}

	for _, system in ipairs(systems) do
		local startTime = tick()
		local timeout = system.optional and 5 or 30

		while not _G[system.name] do
			task.wait(0.1)
			if tick() - startTime > timeout then
				if system.optional then
					print("  ⚠️ Sistema opcional não encontrado: " .. system.name)
					break
				else
					warn("  ❌ ERRO: Sistema obrigatório não carregou: " .. system.name)
					return false
				end
			end
		end

		if _G[system.name] then
			print("  ✓ Sistema carregado: " .. system.name)
		end
	end

	return true
end

-- =====================================
-- CONECTAR SISTEMAS
-- =====================================

-- (V2) Guarda contra duplo embrulho: o monitor pode chamar
-- connectSystems() de novo e, sem isso, OnCharacterSelected
-- passava a disparar 2x por seleção.
local selectCharacterWrapped = false

local function connectSystems()
	print("[INIT V2] Conectando sistemas...")

	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	remotes:WaitForChild("SelectCharacter")

	-- Conectar seleção de personagem com zona segura (UMA vez só)
	if _G.SelectCharacterFunction and _G.OnCharacterSelected and not selectCharacterWrapped then
		selectCharacterWrapped = true
		local originalSelect = _G.SelectCharacterFunction

		_G.SelectCharacterFunction = function(player, characterName)
			-- Chamar função original (do GAME_MANAGER)
			local success, result = originalSelect(player, characterName)

			if success then
				-- Notificar zona segura
				if _G.OnCharacterSelected then
					_G.OnCharacterSelected(player, characterName)
				end

				-- Atualizar estado do jogador
				if _G.SetSpectatorMode then
					_G.SetSpectatorMode(player, false)
				end

				print("  [CONNECT] " .. player.Name .. " selecionou " .. characterName)
			end

			return success, result
		end

		print("  ✓ Sistema de personagens conectado com zona segura")
	elseif selectCharacterWrapped then
		print("  ✓ Sistema de personagens já estava conectado (sem duplo embrulho)")
	end

	-- Conectar sistema de kill com registro de ataques
	if _G.RegisterAttack then
		print("  ✓ Sistema de kill detection conectado")
	end

	-- Conectar sistema de times
	if _G.GetPlayerTeam then
		print("  ✓ Sistema de times conectado")
	end

	return true
end

-- =====================================
-- COMANDOS DE DEBUG (dono único: ResetPlayerBarrier)
-- =====================================
-- Os demais comandos moraram aqui na V1 e foram MOVIDOS:
--   _G.DebugPlayerStatus / _G.TeleportToSafeZone /
--   _G.ForceSelectCharacter -> GlobalSync_V2
--   _G.ListAllPlayers -> SpawnSystem_V7
-- =====================================

local function setupDebugCommands()
	print("[INIT V2] Configurando comandos de debug...")

	-- Resetar barreira (dono único: MainSystemInitializer_V2)
	_G.ResetPlayerBarrier = function(playerName)
		local player = Players:FindFirstChild(playerName)
		if player then
			if _G.SetSpectatorMode then
				_G.SetSpectatorMode(player, true)
				task.wait(0.5)
				_G.SetSpectatorMode(player, false)
				print("✓ Barreira resetada para " .. playerName)
			end
		end
	end

	print("  ✓ Comandos de debug configurados")
	return true
end

-- =====================================
-- MONITORAR CONEXÕES
-- =====================================

local function monitorConnections()
	task.spawn(function()
		while true do
			task.wait(10)

			-- Verificar se sistemas ainda estão ativos
			local systemsOk = true

			if not _G.PlayerDataManager then
				warn("[MONITOR V2] ⚠️ PlayerDataManager desconectado!")
				systemsOk = false
			end

			if not systemsOk then
				print("[MONITOR V2] Tentando reconectar sistemas...")
				waitForSystems()
				connectSystems()
			end
		end
	end)
end

-- =====================================
-- INICIALIZAÇÃO PRINCIPAL
-- =====================================

local function initialize()
	local startTime = tick()

	print("\n🚀 INICIANDO SISTEMA PRINCIPAL V2...")

	-- Passo 1: Criar estrutura
	if not createFolderStructure() then
		warn("❌ ERRO: Falha ao criar estrutura de pastas")
		return
	end

	-- Passo 2: Criar remotes
	if not createAllRemotes() then
		warn("❌ ERRO: Falha ao criar remotes")
		return
	end

	-- Passo 3: Aguardar sistemas
	task.wait(2) -- Dar tempo para outros scripts carregarem
	if not waitForSystems() then
		warn("❌ ERRO: Sistemas obrigatórios não carregaram")
		return
	end

	-- Passo 4: Conectar sistemas
	if not connectSystems() then
		warn("❌ ERRO: Falha ao conectar sistemas")
		return
	end

	-- Passo 5: Configurar debug
	if not setupDebugCommands() then
		warn("❌ ERRO: Falha ao configurar debug")
		return
	end

	-- Passo 6: Iniciar monitoramento
	monitorConnections()

	-- (V2) A sincronização periódica de UpdateStats agora é
	-- responsabilidade EXCLUSIVA do GlobalSync_V2.

	local loadTime = tick() - startTime

	print(string.format(
		[[
╔════════════════════════════════════════════════════╗
║     ✅ SISTEMA PRINCIPAL V2 CARREGADO             ║
╠════════════════════════════════════════════════════╣
║  Tempo de carregamento: %.2f segundos             ║
╠════════════════════════════════════════════════════╣
║  DEBUG AQUI:                                      ║
║  • _G.ResetPlayerBarrier("Nome")                  ║
║  DEBUG NO GlobalSync_V2:                          ║
║  • _G.DebugPlayerStatus / _G.TeleportToSafeZone   ║
║  • _G.ForceSelectCharacter                        ║
║  DEBUG NO SpawnSystem_V7:                         ║
║  • _G.ListAllPlayers / _G.DebugSpawnState         ║
╚════════════════════════════════════════════════════╝
]],
		loadTime
		))
end

-- Iniciar
initialize()
