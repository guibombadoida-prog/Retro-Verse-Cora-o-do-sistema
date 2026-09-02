-- ============================================
-- SPAWN SYSTEM V9.1 - BASE DA ZONA SEGURA DETALHADA
-- Coloque em ServerScriptService
-- Nome: "SpawnSystem"
-- SUBSTITUI: SpawnSystem V9
-- ============================================
-- (V9) A base ganhou grade neon no piso, totens de canto que respiram,
--      emblema central e placas de sinalização. Duas adições resolvem
--      problema de verdade, não só visual:
--
--      • FAIXA DO LIMITE. A zona segura real inclui SAFE_ZONE.MARGIN e
--        era invisível — o jogador só descobria que tinha saído quando
--        levava dano. Agora a fronteira tem cor.
--      • PLACAS. A base não se identificava como zona sem PvP.
--
--      Nada disso entra no cálculo da zona: getSafeZoneBounds() deriva
--      os limites de LOBBY.SIZE e LOBBY.POSITION, que são constantes.
--      As peças são CanCollide/CanTouch/CanQuery false, exceto a base
--      dos totens, para não interferirem em raycast nem em detecção.
-- ============================================
-- (V8) ALTERAÇÕES — ULTRA AVANÇADO:
-- • ZONA SEGURA por DETECÇÃO GEOMÉTRICA contínua: a tag
--   "InSafeZone" passa a refletir a POSIÇÃO REAL do jogador
--   (dentro do lobby = protegido; fora = desprotegido), com
--   eventos de entrada/saída por borda e auto-correção de escape.
--   Vira a fonte ÚNICA de verdade que TeamDamageProtection /
--   GameManager / NPC / CoinDrop já leem.
-- • EQUIPAR QUALQUER PERSONAGEM mais robusto: além do
--   _G.OnCharacterSelected (instantâneo), o auto-sync detecta
--   qualquer MUDANÇA de equippedCharacter (até trocar de
--   personagem), com guarda anti-reentrância (isProcessing).
-- • TP SPAWN com pouso seguro: raycast acha o CHÃO real,
--   preserva a rotação da part de PlayerTp, ignora os outros
--   jogadores e os marcadores, e VALIDA o pouso (1 retry) —
--   nunca spawna dentro de peça nem no ar.
-- • Mantém tudo do V7 (sem math.random / sem :Destroy() /
--   task.*) e o lobby centralizado sobre "MapaPrincipal".
-- ============================================
-- NOVIDADES V6:
-- • Lobby posicionado automaticamente acima do modelo "MapaPrincipal"
-- • Spawn points do mapa lidos da pasta "PlayerTp" (workspace)
-- • teleportToMapSpawn usa o CFrame exato das partes de PlayerTp
-- • Fallback robusto caso MapaPrincipal ou PlayerTp não existam
-- ============================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

print([[
╔════════════════════════════════════════════════════╗
║   🚀 SPAWN SYSTEM V8 - PLAYERTP + MAPAPRINCIPAL   ║
╚════════════════════════════════════════════════════╝
]])

-- =====================================
-- INICIALIZAÇÃO
-- =====================================

local isSystemReady = false
local initializationAttempts = 0
local MAX_INIT_ATTEMPTS = 10

-- (V7) Distribuição DETERMINÍSTICA de spawn (regra do projeto: sem Randomize)
local lobbySpawnSlot = 0 -- slot sequencial em círculo no lobby
local LOBBY_SPAWN_SLOTS = 12 -- posições fixas ao redor do centro
local mapSpawnIndex = 0 -- round-robin dos pontos de PlayerTp

local function waitForSystems()
	print("[SPAWN V8] Aguardando sistemas...")

	local timeout = 0
	while not _G.PlayerDataManager and timeout < 30 do
		task.wait(0.5)
		timeout = timeout + 0.5
	end

	if not _G.PlayerDataManager then
		warn("[SPAWN V8] ❌ PlayerDataManager não encontrado!")
		return false
	end

	print("[SPAWN V8] ✓ PlayerDataManager carregado")

	-- (V7) Cria a pasta Remotes se ainda não existir
	-- (padrão REUTILIZADO do DataManager_Server_V4 — evita falha de ordem de boot)
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	if not remotes then
		remotes = Instance.new("Folder")
		remotes.Name = "Remotes"
		remotes.Parent = ReplicatedStorage
		print("[SPAWN V8] ✓ Pasta Remotes criada")
	end

	print("[SPAWN V8] ✓ Remotes prontos")
	return true
end

local function initializeSystem()
	initializationAttempts = initializationAttempts + 1
	print(string.format("[SPAWN V8] Inicialização #%d", initializationAttempts))

	if not waitForSystems() then
		if initializationAttempts < MAX_INIT_ATTEMPTS then
			print("[SPAWN V8] Tentando novamente em 3s...")
			task.wait(3)
			return initializeSystem()
		else
			error("[SPAWN V8] ❌ FALHA CRÍTICA: sistemas não carregaram!")
		end
	end

	isSystemReady = true
	print("[SPAWN V8] ✅ Sistema inicializado!")
	return true
end

if not initializeSystem() then
	error("[SPAWN V8] Sistema não inicializado!")
end

-- =====================================
-- DETECTAR POSIÇÃO DO LOBBY (V6 NOVO)
-- Lê o bounding box do modelo MapaPrincipal e
-- posiciona o lobby centralizado acima dele.
-- =====================================

local LOBBY_HEIGHT_OFFSET = 60 -- studs acima do topo do MapaPrincipal

local function getLobbyPosition()
	local mapa = workspace:FindFirstChild("MapaPrincipal")

	if mapa then
		-- GetBoundingBox retorna (CFrame do centro, Vector3 do tamanho)
		local ok, cf, size = pcall(function()
			return mapa:GetBoundingBox()
		end)

		if ok and cf then
			local centerX = cf.Position.X
			local centerZ = cf.Position.Z
			local topY = cf.Position.Y + (size.Y / 2)

			local lobbyY = topY + LOBBY_HEIGHT_OFFSET

			print(
				string.format(
					"[SPAWN V8] ✓ MapaPrincipal encontrado — Centro: (%.1f, %.1f, %.1f) | Topo: %.1f | Lobby Y: %.1f",
					centerX,
					cf.Position.Y,
					centerZ,
					topY,
					lobbyY
				)
			)

			return Vector3.new(centerX, lobbyY, centerZ)
		else
			warn("[SPAWN V8] ⚠️ Falha ao obter bounding box do MapaPrincipal, usando fallback")
		end
	else
		warn(
			"[SPAWN V8] ⚠️ Modelo 'MapaPrincipal' não encontrado no Workspace! Usando posição fallback."
		)
		warn("[SPAWN V8]    Certifique-se de que o modelo se chama exatamente 'MapaPrincipal'.")
	end

	-- Fallback
	return Vector3.new(0, 505, 0)
end

-- =====================================
-- CONFIGURAÇÃO DO LOBBY
-- POSITION é calculado dinamicamente no initializeSystem
-- =====================================

local LOBBY = {
	POSITION = Vector3.new(0, 505, 0), -- será sobrescrito abaixo
	SIZE = Vector3.new(150, 60, 150),
	SPAWN_RADIUS = 30,
	FLOOR_HEIGHT = 4,
	WALL_HEIGHT = 50,
	WALL_THICKNESS = 2,
}

-- Calcular posição real antes de criar qualquer estrutura
LOBBY.POSITION = getLobbyPosition()
print(
	string.format(
		"[SPAWN V8] 📍 Lobby posicionado em: (%.1f, %.1f, %.1f)",
		LOBBY.POSITION.X,
		LOBBY.POSITION.Y,
		LOBBY.POSITION.Z
	)
)

local CONFIG = {
	CHECK_INTERVAL = 0.3, -- (V8) mais responsivo p/ detecção geométrica
	TELEPORT_COOLDOWN = 2,
	MAX_DETECTION_RETRIES = 5,
}

-- =====================================
-- (V8) DETECÇÃO GEOMÉTRICA DA ZONA SEGURA + TP COM CHÃO
-- =====================================

local SAFE_ZONE = {
	MARGIN = 6, -- tolerância nas bordas (studs)
	Y_BELOW = 12, -- folga abaixo do piso do lobby
	Y_ABOVE = 72, -- folga acima (cobre paredes/teto)
}

-- Limites do retângulo da zona segura (em torno do lobby)
local function getSafeZoneBounds()
	local half = LOBBY.SIZE / 2
	local minX = LOBBY.POSITION.X - half.X - SAFE_ZONE.MARGIN
	local maxX = LOBBY.POSITION.X + half.X + SAFE_ZONE.MARGIN
	local minZ = LOBBY.POSITION.Z - half.Z - SAFE_ZONE.MARGIN
	local maxZ = LOBBY.POSITION.Z + half.Z + SAFE_ZONE.MARGIN
	local minY = LOBBY.POSITION.Y - SAFE_ZONE.Y_BELOW
	local maxY = LOBBY.POSITION.Y + SAFE_ZONE.Y_ABOVE
	return minX, maxX, minY, maxY, minZ, maxZ
end

-- Está fisicamente dentro da zona segura?
local function isInSafeZoneRegion(pos)
	local minX, maxX, minY, maxY, minZ, maxZ = getSafeZoneBounds()
	return pos.X >= minX
		and pos.X <= maxX
		and pos.Y >= minY
		and pos.Y <= maxY
		and pos.Z >= minZ
		and pos.Z <= maxZ
end

-- Personagens de todos os jogadores (p/ ignorar no raycast)
local function getAllPlayerCharacters()
	local list = {}
	for _, p in pairs(Players:GetPlayers()) do
		if p.Character then
			table.insert(list, p.Character)
		end
	end
	return list
end

-- (V8) Acha o chão abaixo de um CFrame e devolve um CFrame seguro,
-- preservando a rotação original. Evita spawnar dentro de peças.
local function findSafeGroundCFrame(baseCFrame, extraIgnore)
	local ignore = getAllPlayerCharacters()
	if extraIgnore then
		for _, inst in ipairs(extraIgnore) do
			table.insert(ignore, inst)
		end
	end

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	params.IgnoreWater = true

	local origin = baseCFrame.Position + Vector3.new(0, 10, 0)
	local result = workspace:Raycast(origin, Vector3.new(0, -150, 0), params)

	local rotation = baseCFrame - baseCFrame.Position
	if result then
		return CFrame.new(result.Position + Vector3.new(0, 3.5, 0)) * rotation
	end
	-- Fallback: usa o próprio ponto com offset
	return CFrame.new(baseCFrame.Position + Vector3.new(0, 3, 0)) * rotation
end

-- =====================================
-- REMOTES
-- =====================================

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local spectatorModeRemote = remotes:WaitForChild("SpectatorMode", 10)
local syncCharacterStateRemote = remotes:WaitForChild("SyncCharacterState", 10)

if not spectatorModeRemote then
	spectatorModeRemote = Instance.new("RemoteEvent")
	spectatorModeRemote.Name = "SpectatorMode"
	spectatorModeRemote.Parent = remotes
end

if not syncCharacterStateRemote then
	syncCharacterStateRemote = Instance.new("RemoteEvent")
	syncCharacterStateRemote.Name = "SyncCharacterState"
	syncCharacterStateRemote.Parent = remotes
end

-- =====================================
-- VARIÁVEIS GLOBAIS
-- =====================================

local playerStates = {}
local lobbyModel = nil
local lobbySpawnLocation = nil
local exitBarriers = {}
local mapSpawnPoints = {} -- lista de CFrames das partes de PlayerTp

-- =====================================
-- COLETAR SPAWN POINTS — PASTA PlayerTp (V6 NOVO)
-- Lê todas as BaseParts dentro de workspace.PlayerTp
-- e armazena seus CFrames para uso no teleporte.
-- =====================================

local function collectMapSpawnPoints()
	mapSpawnPoints = {}

	print("[SPAWN V8] Coletando spawn points da pasta 'PlayerTp'...")

	local folder = workspace:FindFirstChild("PlayerTp")

	if not folder then
		warn("[SPAWN V8] ⚠️ Pasta 'PlayerTp' não encontrada no Workspace!")
		warn("[SPAWN V8]    Crie uma Folder chamada 'PlayerTp' e coloque Parts dentro.")
		-- Fallback: posições padrão
		mapSpawnPoints = {
			CFrame.new(200, 10, 200),
			CFrame.new(-200, 10, 200),
			CFrame.new(200, 10, -200),
			CFrame.new(-200, 10, -200),
		}
		warn("[SPAWN V8] ⚠️ Usando 4 posições de fallback.")
		return
	end

	for _, part in pairs(folder:GetChildren()) do
		if part:IsA("BasePart") then
			-- Guarda o CFrame completo (inclui rotação da part)
			table.insert(mapSpawnPoints, part.CFrame)
			print(
				string.format(
					"[SPAWN V8]   ✓ Spawn point: %s em (%.1f, %.1f, %.1f)",
					part.Name,
					part.Position.X,
					part.Position.Y,
					part.Position.Z
				)
			)
		end
	end

	if #mapSpawnPoints == 0 then
		warn("[SPAWN V8] ⚠️ Pasta 'PlayerTp' está vazia! Adicione Parts dentro dela.")
		mapSpawnPoints = { CFrame.new(200, 10, 200) }
		warn("[SPAWN V8] ⚠️ Usando 1 posição de fallback.")
		return
	end

	print(
		string.format("[SPAWN V8] ✓ %d spawn point(s) coletado(s) de 'PlayerTp'", #mapSpawnPoints)
	)
end

-- =====================================
-- CRIAR ESTRUTURA DO LOBBY
-- (1 único SpawnLocation — igual ao V5)
-- =====================================

-- =====================================
-- (V9) DETALHAMENTO DA BASE DA ZONA SEGURA
-- =====================================
-- Tudo aqui é decoração e sinalização: nenhuma peça entra no cálculo da
-- zona segura. getSafeZoneBounds() deriva os limites de LOBBY.SIZE e
-- LOBBY.POSITION, que são constantes — então detalhe novo não move a
-- fronteira nem quebra isInSafeZoneRegion.
--
-- Duas coisas que este detalhamento resolve de verdade, além do visual:
-- o jogador não tinha como ver ONDE a zona segura termina, e a base não
-- se identificava como zona sem PvP.

local DETALHE = {
	LINHAS_GRADE = 7, -- linhas de grade por eixo
	ESPESSURA = 0.4,
	ALTURA_TOTEM = 16,
	COR_NEON = Color3.fromRGB(0, 255, 200),
	COR_AVISO = Color3.fromRGB(255, 180, 0),
	COR_MAGENTA = Color3.fromRGB(255, 0, 130),
}

-- Um tween por alvo, guardado para poder ser cancelado. Mesma regra do
-- resto do projeto: nada de laço criando tween a cada volta.
local tweensLobby = {}

local function pulsar(chave, objeto, duracao, propriedades)
	local anterior = tweensLobby[chave]
	if anterior then
		anterior:Cancel()
	end
	local tween = TweenService:Create(
		objeto,
		TweenInfo.new(duracao, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		propriedades
	)
	tweensLobby[chave] = tween
	tween:Play()
	return tween
end

local function novaPeca(pai, nome, tamanho, posicao, cor, material)
	local peca = Instance.new("Part")
	peca.Name = nome
	peca.Size = tamanho
	peca.Position = posicao
	peca.Anchored = true
	peca.CanCollide = false
	peca.CanTouch = false
	peca.CanQuery = false
	peca.Material = material or Enum.Material.Neon
	peca.Color = cor
	peca.TopSurface = Enum.SurfaceType.Smooth
	peca.BottomSurface = Enum.SurfaceType.Smooth
	peca.Parent = pai
	return peca
end

local function createLobbyDetails(pai)
	local topoPiso = LOBBY.POSITION.Y + LOBBY.FLOOR_HEIGHT / 2
	local metadeX = LOBBY.SIZE.X / 2
	local metadeZ = LOBBY.SIZE.Z / 2

	-- 1. GRADE NEON NO PISO
	-- Dá escala e direção ao chão: sem ela o piso é uma laje lisa e o
	-- jogador não percebe o próprio deslocamento dentro da base.
	local grade = Instance.new("Folder")
	grade.Name = "GradeNeon"
	grade.Parent = pai

	for i = 1, DETALHE.LINHAS_GRADE do
		local t = (i / (DETALHE.LINHAS_GRADE + 1)) * 2 - 1 -- -1 .. 1
		novaPeca(
			grade,
			"LinhaX" .. i,
			Vector3.new(LOBBY.SIZE.X, 0.1, DETALHE.ESPESSURA),
			LOBBY.POSITION + Vector3.new(0, LOBBY.FLOOR_HEIGHT / 2 + 0.06, t * metadeZ),
			DETALHE.COR_NEON
		).Transparency = 0.35
		novaPeca(
			grade,
			"LinhaZ" .. i,
			Vector3.new(DETALHE.ESPESSURA, 0.1, LOBBY.SIZE.Z),
			LOBBY.POSITION + Vector3.new(t * metadeX, LOBBY.FLOOR_HEIGHT / 2 + 0.06, 0),
			DETALHE.COR_NEON
		).Transparency = 0.35
	end

	-- 2. FAIXA DO LIMITE DA ZONA SEGURA
	-- A fronteira real inclui SAFE_ZONE.MARGIN, e até agora era invisível:
	-- o jogador só descobria que saiu quando levava dano. Agora ela tem cor.
	local limite = Instance.new("Folder")
	limite.Name = "LimiteZonaSegura"
	limite.Parent = pai

	local limX = metadeX + SAFE_ZONE.MARGIN
	local limZ = metadeZ + SAFE_ZONE.MARGIN
	local faixas = {
		{ Vector3.new(limX * 2, 0.3, 1.2), Vector3.new(0, 0, limZ) },
		{ Vector3.new(limX * 2, 0.3, 1.2), Vector3.new(0, 0, -limZ) },
		{ Vector3.new(1.2, 0.3, limZ * 2), Vector3.new(limX, 0, 0) },
		{ Vector3.new(1.2, 0.3, limZ * 2), Vector3.new(-limX, 0, 0) },
	}
	for i, def in ipairs(faixas) do
		local faixa = novaPeca(
			limite,
			"Faixa" .. i,
			def[1],
			Vector3.new(LOBBY.POSITION.X, topoPiso + 0.15, LOBBY.POSITION.Z) + def[2],
			DETALHE.COR_AVISO
		)
		faixa.Transparency = 0.25
	end

	local luzLimite = Instance.new("PointLight")
	luzLimite.Brightness = 1
	luzLimite.Range = 24
	luzLimite.Color = DETALHE.COR_AVISO
	luzLimite.Parent = limite:FindFirstChild("Faixa1")

	-- 3. TOTENS DE CANTO
	local totens = Instance.new("Folder")
	totens.Name = "Totens"
	totens.Parent = pai

	local cantos = {
		Vector3.new(metadeX - 6, 0, metadeZ - 6),
		Vector3.new(-metadeX + 6, 0, metadeZ - 6),
		Vector3.new(metadeX - 6, 0, -metadeZ + 6),
		Vector3.new(-metadeX + 6, 0, -metadeZ + 6),
	}
	for i, canto in ipairs(cantos) do
		local base = novaPeca(
			totens,
			"TotemBase" .. i,
			Vector3.new(3, 1.2, 3),
			LOBBY.POSITION + canto + Vector3.new(0, LOBBY.FLOOR_HEIGHT / 2 + 0.6, 0),
			Color3.fromRGB(40, 40, 70),
			Enum.Material.SmoothPlastic
		)
		base.CanCollide = true

		local haste = novaPeca(
			totens,
			"TotemLuz" .. i,
			Vector3.new(1, DETALHE.ALTURA_TOTEM, 1),
			LOBBY.POSITION + canto + Vector3.new(0, topoPiso - LOBBY.POSITION.Y + DETALHE.ALTURA_TOTEM / 2 + 1.2, 0),
			i % 2 == 0 and DETALHE.COR_MAGENTA or DETALHE.COR_NEON
		)

		local luz = Instance.new("PointLight")
		luz.Brightness = 2.5
		luz.Range = 26
		luz.Color = haste.Color
		luz.Parent = haste

		-- Respiração lenta e dessincronizada entre os quatro.
		pulsar("totem" .. i, haste, 1.6 + i * 0.25, { Transparency = 0.55 })
	end

	-- 4. EMBLEMA CENTRAL
	local emblema = novaPeca(
		pai,
		"EmblemaZonaSegura",
		Vector3.new(18, 0.2, 18),
		LOBBY.POSITION + Vector3.new(0, topoPiso - LOBBY.POSITION.Y + 0.1, 0),
		DETALHE.COR_NEON
	)
	emblema.Transparency = 0.5
	pulsar("emblema", emblema, 2.4, { Transparency = 0.85 })

	-- 5. PLACAS
	-- Sinalização escrita: a base agora se apresenta como zona sem PvP,
	-- em vez de o jogador ter que descobrir isso apanhando lá fora.
	local placas = Instance.new("Folder")
	placas.Name = "Placas"
	placas.Parent = pai

	-- (V9.1) As duas placas ficavam de costas para quem está na base.
	--
	-- Ambas usavam Face = Back, que é a face +Z LOCAL da peça. A placa da
	-- borda +Z mostrava o texto para fora da zona; a da borda -Z era
	-- girada 180°, o que leva o +Z local para o -Z do mundo — também para
	-- fora. Das duas o jogador via o verso.
	--
	-- A rotação saiu de cena: sem ela não há como o texto sair espelhado.
	-- Cada placa agora declara a face que aponta para o CENTRO da base:
	-- Front é -Z local, Back é +Z local.
	local ladosPlaca = {
		{ deslocamento = Vector3.new(0, 0, metadeZ - 2), face = Enum.NormalId.Front },
		{ deslocamento = Vector3.new(0, 0, -metadeZ + 2), face = Enum.NormalId.Back },
	}
	for i, def in ipairs(ladosPlaca) do
		local placa = novaPeca(
			placas,
			"Placa" .. i,
			Vector3.new(40, 8, 0.5),
			LOBBY.POSITION + def.deslocamento + Vector3.new(0, topoPiso - LOBBY.POSITION.Y + 9, 0),
			Color3.fromRGB(14, 12, 30),
			Enum.Material.SmoothPlastic
		)

		local borda = Instance.new("SurfaceGui")
		borda.Face = def.face
		borda.AlwaysOnTop = false
		borda.CanvasSize = Vector2.new(800, 160)
		borda.Parent = placa

		local texto = Instance.new("TextLabel")
		texto.Size = UDim2.fromScale(1, 1)
		texto.BackgroundTransparency = 1
		texto.Text = "ZONA SEGURA  •  SEM PVP"
		texto.TextColor3 = DETALHE.COR_NEON
		texto.TextScaled = true
		texto.Font = Enum.Font.Arcade
		texto.Parent = borda
	end

	print("[SPAWN V9] ✓ Base da zona segura detalhada")
end

local function createLobbyStructure()
	print("[SPAWN V8] Criando estrutura do lobby...")

	-- Remover estruturas antigas
	local oldLobby = workspace:FindFirstChild("LobbyStructure")
	if oldLobby then
		oldLobby.Parent = nil
	end

	local oldSafeZone = workspace:FindFirstChild("SafeZone")
	if oldSafeZone then
		oldSafeZone.Parent = nil
	end

	-- Modelo principal
	lobbyModel = Instance.new("Model")
	lobbyModel.Name = "LobbyStructure"
	lobbyModel:SetAttribute("StructureVersion", 9)
	lobbyModel:SetAttribute("SafeZoneCenter", LOBBY.POSITION)
	lobbyModel:SetAttribute("SafeZoneSize", LOBBY.SIZE)
	lobbyModel.Parent = workspace

	-- 1. PISO
	local floor = Instance.new("Part")
	floor.Name = "LobbyFloor"
	floor.Size = Vector3.new(LOBBY.SIZE.X, LOBBY.FLOOR_HEIGHT, LOBBY.SIZE.Z)
	floor.Position = LOBBY.POSITION
	floor.Anchored = true
	floor.Material = Enum.Material.SmoothPlastic
	floor.Color = Color3.fromRGB(30, 30, 50)
	floor.TopSurface = Enum.SurfaceType.Smooth
	floor.BottomSurface = Enum.SurfaceType.Smooth
	floor.Parent = lobbyModel

	local floorLight = Instance.new("PointLight")
	floorLight.Brightness = 1.5
	floorLight.Range = 60
	floorLight.Color = Color3.fromRGB(0, 170, 255)
	floorLight.Parent = floor

	-- 2. PLATAFORMA DE SPAWN CENTRAL
	local spawnPlatform = Instance.new("Part")
	spawnPlatform.Name = "SpawnPlatform"
	spawnPlatform.Size = Vector3.new(15, 2, 15)
	spawnPlatform.Position = LOBBY.POSITION + Vector3.new(0, LOBBY.FLOOR_HEIGHT / 2 + 1, 0)
	spawnPlatform.Anchored = true
	spawnPlatform.Material = Enum.Material.ForceField
	spawnPlatform.Color = Color3.fromRGB(255, 255, 0)
	spawnPlatform.Parent = lobbyModel

	local platformLight = Instance.new("PointLight")
	platformLight.Brightness = 3
	platformLight.Range = 40
	platformLight.Color = Color3.fromRGB(255, 255, 0)
	platformLight.Parent = spawnPlatform

	-- Um único tween repetido. O código antigo criava outro tween infinito
	-- a cada segundo e acumulava animações na mesma plataforma.
	pulsar("plataformaSpawn", spawnPlatform, 1, { Transparency = 0.3 })

	-- 3. SPAWN LOCATION DO LOBBY (único)
	lobbySpawnLocation = Instance.new("SpawnLocation")
	lobbySpawnLocation.Name = "LobbySpawn"
	lobbySpawnLocation.Size = Vector3.new(8, 1, 8)
	lobbySpawnLocation.Position = LOBBY.POSITION + Vector3.new(0, LOBBY.FLOOR_HEIGHT / 2 + 3, 0)
	lobbySpawnLocation.Anchored = true
	lobbySpawnLocation.Transparency = 1
	lobbySpawnLocation.CanCollide = false
	lobbySpawnLocation.TopSurface = Enum.SurfaceType.Smooth
	lobbySpawnLocation.Enabled = true
	lobbySpawnLocation.Neutral = true
	lobbySpawnLocation.AllowTeamChangeOnTouch = false
	lobbySpawnLocation.Duration = 0
	lobbySpawnLocation.Parent = lobbyModel

	print("[SPAWN V8] ✓ SpawnLocation único do lobby criado")

	-- 4. PAREDES
	local wallPositions = {
		{
			pos = Vector3.new(0, LOBBY.WALL_HEIGHT / 2, LOBBY.SIZE.Z / 2),
			size = Vector3.new(LOBBY.SIZE.X, LOBBY.WALL_HEIGHT, LOBBY.WALL_THICKNESS),
		},
		{
			pos = Vector3.new(0, LOBBY.WALL_HEIGHT / 2, -LOBBY.SIZE.Z / 2),
			size = Vector3.new(LOBBY.SIZE.X, LOBBY.WALL_HEIGHT, LOBBY.WALL_THICKNESS),
		},
		{
			pos = Vector3.new(LOBBY.SIZE.X / 2, LOBBY.WALL_HEIGHT / 2, 0),
			size = Vector3.new(LOBBY.WALL_THICKNESS, LOBBY.WALL_HEIGHT, LOBBY.SIZE.Z),
		},
		{
			pos = Vector3.new(-LOBBY.SIZE.X / 2, LOBBY.WALL_HEIGHT / 2, 0),
			size = Vector3.new(LOBBY.WALL_THICKNESS, LOBBY.WALL_HEIGHT, LOBBY.SIZE.Z),
		},
	}

	for i, wallData in ipairs(wallPositions) do
		local wall = Instance.new("Part")
		wall.Name = "Wall" .. i
		wall.Size = wallData.size
		wall.Position = LOBBY.POSITION + wallData.pos
		wall.Anchored = true
		wall.Transparency = 0.2
		wall.Material = Enum.Material.ForceField
		wall.Color = Color3.fromRGB(0, 255, 255)
		wall.CanCollide = true
		wall.Parent = lobbyModel

		local particles = Instance.new("ParticleEmitter")
		particles.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		particles.Color = ColorSequence.new(Color3.fromRGB(0, 255, 255))
		particles.Size = NumberSequence.new(0.5)
		particles.Transparency = NumberSequence.new(0.5, 1)
		particles.Lifetime = NumberRange.new(2)
		particles.Rate = 10
		particles.Speed = NumberRange.new(2)
		particles.Parent = wall
	end

	-- 5. TETO
	local ceiling = Instance.new("Part")
	ceiling.Name = "LobbyCeiling"
	ceiling.Size = Vector3.new(LOBBY.SIZE.X, LOBBY.WALL_THICKNESS, LOBBY.SIZE.Z)
	ceiling.Position = LOBBY.POSITION
		+ Vector3.new(0, LOBBY.WALL_HEIGHT + LOBBY.WALL_THICKNESS / 2, 0)
	ceiling.Anchored = true
	ceiling.Transparency = 0.5
	ceiling.Material = Enum.Material.Glass
	ceiling.Color = Color3.fromRGB(100, 200, 255)
	ceiling.CanCollide = true
	ceiling.Parent = lobbyModel

	-- 6. PILARES
	local pillarOffsets = {
		Vector3.new(LOBBY.SIZE.X / 2 - 10, LOBBY.WALL_HEIGHT / 2, LOBBY.SIZE.Z / 2 - 10),
		Vector3.new(-LOBBY.SIZE.X / 2 + 10, LOBBY.WALL_HEIGHT / 2, LOBBY.SIZE.Z / 2 - 10),
		Vector3.new(LOBBY.SIZE.X / 2 - 10, LOBBY.WALL_HEIGHT / 2, -LOBBY.SIZE.Z / 2 + 10),
		Vector3.new(-LOBBY.SIZE.X / 2 + 10, LOBBY.WALL_HEIGHT / 2, -LOBBY.SIZE.Z / 2 + 10),
	}

	for i, offset in ipairs(pillarOffsets) do
		local pillar = Instance.new("Part")
		pillar.Name = "Pillar" .. i
		pillar.Size = Vector3.new(8, LOBBY.WALL_HEIGHT, 8)
		pillar.Position = LOBBY.POSITION + offset
		pillar.Anchored = true
		pillar.Material = Enum.Material.Marble
		pillar.Color = Color3.fromRGB(220, 220, 220)
		pillar.Parent = lobbyModel

		local pLight = Instance.new("PointLight")
		pLight.Brightness = 2
		pLight.Range = 30
		pLight.Color = Color3.fromRGB(255, 255, 255)
		pLight.Parent = pillar
	end

	-- (V9) Detalhamento visual e sinalização da base
	createLobbyDetails(lobbyModel)

	-- Referência SafeZone para compatibilidade com outros sistemas
	local safeZoneRef = Instance.new("Model")
	safeZoneRef.Name = "SafeZone"
	safeZoneRef:SetAttribute("Version", 9)
	safeZoneRef:SetAttribute("Center", LOBBY.POSITION)
	safeZoneRef:SetAttribute("Size", LOBBY.SIZE)
	safeZoneRef.Parent = workspace

	local refPart = Instance.new("Part")
	refPart.Name = "Reference"
	refPart.Size = Vector3.new(1, 1, 1)
	refPart.Position = LOBBY.POSITION
	refPart.Anchored = true
	refPart.Transparency = 1
	refPart.CanCollide = false
	refPart.CanTouch = false
	refPart.CanQuery = false
	refPart.Parent = safeZoneRef
	safeZoneRef.PrimaryPart = refPart

	print("[SPAWN V9] ✓ Estrutura detalhada do lobby completa")
end

-- =====================================
-- TELEPORTES
-- =====================================

local function teleportToLobby(character)
	if not character then
		return false
	end
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then
		return false
	end

	-- (V7) Slot sequencial determinístico ao redor do centro (sem random)
	lobbySpawnSlot = (lobbySpawnSlot % LOBBY_SPAWN_SLOTS) + 1
	local angle = (lobbySpawnSlot - 1) * ((math.pi * 2) / LOBBY_SPAWN_SLOTS)
	local radius = math.max(5, LOBBY.SPAWN_RADIUS * 0.6)

	local targetPosition = LOBBY.POSITION
		+ Vector3.new(math.cos(angle) * radius, LOBBY.FLOOR_HEIGHT + 5, math.sin(angle) * radius)

	-- (V8) Snap no piso do lobby + zera velocidade
	local targetCFrame = findSafeGroundCFrame(CFrame.new(targetPosition), { character })
	hrp.CFrame = targetCFrame
	hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
	hrp.AssemblyAngularVelocity = Vector3.new(0, 0, 0)

	-- (V8) Valida o pouso e tenta de novo 1x (anti queda/stuck)
	task.wait(0.05)
	if hrp.Parent and (hrp.Position - targetCFrame.Position).Magnitude > 12 then
		hrp.CFrame = targetCFrame
		hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
	end
	return true
end

-- (V6) Usa o CFrame das partes de PlayerTp diretamente.
-- O jogador aparece exatamente onde a part está (com 3 studs de offset Y).
local function teleportToMapSpawn(character)
	if not character or #mapSpawnPoints == 0 then
		return false
	end

	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then
		return false
	end

	-- (V7) Round-robin determinístico pelos pontos de PlayerTp (sem random)
	mapSpawnIndex = (mapSpawnIndex % #mapSpawnPoints) + 1
	local chosenCFrame = mapSpawnPoints[mapSpawnIndex]

	-- (V8) Ignora os personagens dos jogadores E os próprios marcadores
	-- PlayerTp para achar o CHÃO real; preserva a rotação da part.
	local ignoreExtra = { character }
	local tpFolder = workspace:FindFirstChild("PlayerTp")
	if tpFolder then
		table.insert(ignoreExtra, tpFolder)
	end

	local targetCFrame = findSafeGroundCFrame(chosenCFrame, ignoreExtra)
	hrp.CFrame = targetCFrame
	hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
	hrp.AssemblyAngularVelocity = Vector3.new(0, 0, 0)

	-- (V8) Valida o pouso e tenta de novo 1x
	task.wait(0.05)
	if hrp.Parent and (hrp.Position - targetCFrame.Position).Magnitude > 15 then
		hrp.CFrame = targetCFrame
		hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
	end
	return true
end

-- =====================================
-- EFEITOS DA SAFE ZONE
-- =====================================

local function applyZoneSafeEffects(character)
	if not character then
		return
	end

	local oldFF = character:FindFirstChild("SafeZoneProtection")
	if oldFF then
		oldFF.Parent = nil
	end

	local oldTag = character:FindFirstChild("InSafeZone")
	if oldTag then
		oldTag.Parent = nil
	end

	local ff = Instance.new("ForceField")
	ff.Name = "SafeZoneProtection"
	ff.Visible = true
	ff.Parent = character

	local tag = Instance.new("BoolValue")
	tag.Name = "InSafeZone"
	tag.Value = true
	tag.Parent = character
end

local function removeZoneSafeEffects(character)
	if not character then
		return
	end

	local ff = character:FindFirstChild("SafeZoneProtection")
	if ff then
		ff.Parent = nil
	end

	local tag = character:FindFirstChild("InSafeZone")
	if tag then
		tag.Parent = nil
	end
end

-- (V8) Tag/efeito idempotentes (entra/sai por BORDA, sem recriar)
local function isTaggedSafe(character)
	return character ~= nil and character:FindFirstChild("InSafeZone") ~= nil
end

local function setSafeState(character, makeSafe)
	if not character then
		return false
	end
	local tagged = isTaggedSafe(character)
	if makeSafe and not tagged then
		applyZoneSafeEffects(character)
		return true
	elseif (not makeSafe) and tagged then
		removeZoneSafeEffects(character)
		return true
	end
	return false
end

-- =====================================
-- BARREIRA DO JOGADOR
-- =====================================

local function createPlayerBarrier(player)
	if exitBarriers[player] then
		exitBarriers[player].Parent = nil
	end

	local barrier = Instance.new("Part")
	barrier.Name = "PlayerBarrier_" .. player.Name
	barrier.Size = Vector3.new(20, 20, 5)
	barrier.Position = LOBBY.POSITION + Vector3.new(0, 10, -LOBBY.SIZE.Z / 2 + 2)
	barrier.Anchored = true
	barrier.Transparency = 0.8
	barrier.Material = Enum.Material.ForceField
	barrier.Color = Color3.fromRGB(255, 0, 0)
	barrier.CanCollide = true
	barrier.Parent = lobbyModel

	exitBarriers[player] = barrier
end

local function removePlayerBarrier(player)
	if exitBarriers[player] then
		local barrier = exitBarriers[player]

		TweenService:Create(barrier, TweenInfo.new(0.5), {
			Transparency = 1,
			Size = Vector3.new(20, 20, 0.1),
		}):Play()

		task.wait(0.5)
		if barrier and barrier.Parent then
			barrier.Parent = nil
		end
		exitBarriers[player] = nil
	end
end

-- =====================================
-- RESPAWN LOCATION DINÂMICO
-- =====================================

local function updateRespawnLocation(player, hasCharacter)
	if hasCharacter then
		player.RespawnLocation = nil
		print(string.format("[SPAWN V8] %s → RespawnLocation: MAPA (PlayerTp)", player.Name))
	else
		player.RespawnLocation = lobbySpawnLocation
		print(string.format("[SPAWN V8] %s → RespawnLocation: LOBBY", player.Name))
	end
end

-- =====================================
-- CLASSE DE ESTADO DO JOGADOR
-- =====================================

local PlayerState = {}
PlayerState.__index = PlayerState

function PlayerState.new(player)
	local self = setmetatable({}, PlayerState)

	self.player = player
	self.hasCharacter = false
	self.isInSafeZone = true
	self.isDead = false
	self.equippedCharacter = nil
	self.lastTeleportTime = 0
	self.detectionActive = false
	self.isProcessing = false
	self.detectionRetries = 0

	return self
end

function PlayerState:log(message)
	print(string.format("[%s] %s", self.player.Name, message))
end

function PlayerState:canTeleport()
	return (tick() - self.lastTeleportTime) >= CONFIG.TELEPORT_COOLDOWN
end

function PlayerState:startDetection()
	if self.detectionActive then
		self:log("⚠️ Detecção já ativa")
		return
	end

	self.detectionActive = true
	self.detectionRetries = 0
	self:log("🔍 Detecção ATIVADA — aguardando personagem ser equipado")

	task.spawn(function()
		while self.detectionActive and self.player.Parent do
			if self.isInSafeZone and self.player.Character then
				local humanoid = self.player.Character:FindFirstChild("Humanoid")
				local hrp = self.player.Character:FindFirstChild("HumanoidRootPart")

				if humanoid and humanoid.Health > 0 and hrp then
					local success, data = pcall(function()
						return _G.PlayerDataManager.getPlayerData(self.player)
					end)

					if
						success
						and data
						and data.equippedCharacter
						and not self.hasCharacter
						and not self.isProcessing
					then
						self:log(string.format("✅ DETECTADO: %s", data.equippedCharacter))
						self:handleEquipment(data.equippedCharacter)
					elseif not success then
						self.detectionRetries = self.detectionRetries + 1
						self:log(
							string.format(
								"⚠️ Erro ao obter dados (%d/%d)",
								self.detectionRetries,
								CONFIG.MAX_DETECTION_RETRIES
							)
						)

						if self.detectionRetries >= CONFIG.MAX_DETECTION_RETRIES then
							self:log("❌ Detecção falhou após muitas tentativas")
							self:stopDetection()
						end
					end

					-- Anti-escape: força volta ao lobby se saiu sem personagem
					local distance = (hrp.Position - LOBBY.POSITION).Magnitude
					if distance > LOBBY.SIZE.X / 2 + 10 and not self.hasCharacter then
						self:log("⚠️ Tentativa de escape bloqueada — teleportando de volta")
						teleportToLobby(self.player.Character)
					end
				end
			else
				break
			end

			task.wait(CONFIG.CHECK_INTERVAL)
		end

		self:log("🛑 Loop de detecção finalizado")
	end)
end

function PlayerState:stopDetection()
	if not self.detectionActive then
		return
	end

	self.detectionActive = false
	self.detectionRetries = 0
	self:log("🛑 Detecção DESATIVADA")
end

function PlayerState:handleEquipment(characterName)
	if self.isProcessing or not self:canTeleport() then
		return
	end

	self.isProcessing = true
	self:log(string.format("⚙️ Equipando: %s → teleportando para mapa", characterName))

	self.hasCharacter = true
	self.equippedCharacter = characterName
	self.isInSafeZone = false
	self.lastTeleportTime = tick()

	updateRespawnLocation(self.player, true)
	self:stopDetection()
	removePlayerBarrier(self.player)

	task.wait(0.5)

	if self.player.Character then
		removeZoneSafeEffects(self.player.Character)
		task.wait(0.3)

		local success = teleportToMapSpawn(self.player.Character)
		if success then
			self:log(string.format("✅ %s teleportado para mapa via PlayerTp!", characterName))
		else
			self:log("⚠️ Falha ao teleportar — PlayerTp pode estar vazio")
		end

		pcall(function()
			if syncCharacterStateRemote then
				syncCharacterStateRemote:FireClient(self.player, characterName, true)
			end
		end)

		pcall(function()
			if spectatorModeRemote then
				spectatorModeRemote:FireClient(self.player, false, {})
			end
		end)
	end

	self.isProcessing = false
end

function PlayerState:handleSpawn()
	if self.isProcessing then
		self:log("⚠️ Já processando spawn, ignorando")
		return
	end

	self.isProcessing = true
	self:log("🔄 Processando spawn...")

	local character = self.player.Character
	if not character then
		self.isProcessing = false
		return
	end

	local humanoid = character:WaitForChild("Humanoid", 5)
	if not humanoid then
		self:log("❌ Humanoid não encontrado")
		self.isProcessing = false
		return
	end

	if self.isDead or not self.hasCharacter then
		-- SEM PERSONAGEM → SPAWN NO LOBBY
		self:log("🛡️ SPAWN NO LOBBY (sem personagem equipado)")

		updateRespawnLocation(self.player, false)
		task.wait(0.2)

		-- Duplo teleporte para garantir posição
		teleportToLobby(character)
		task.wait(0.1)
		teleportToLobby(character)

		applyZoneSafeEffects(character)
		createPlayerBarrier(self.player)

		self.isDead = false
		self.isInSafeZone = true
		self.hasCharacter = false
		self.equippedCharacter = nil

		pcall(function()
			local data = _G.PlayerDataManager.getPlayerData(self.player)
			if data then
				data.equippedCharacter = nil
			end
		end)

		task.wait(0.5)
		self:startDetection()

		pcall(function()
			if syncCharacterStateRemote then
				syncCharacterStateRemote:FireClient(self.player, nil, false)
			end
		end)

		pcall(function()
			if spectatorModeRemote then
				local activePlayers = {}
				for _, p in pairs(Players:GetPlayers()) do
					local state = playerStates[p]
					if state and state.hasCharacter and p.Character then
						table.insert(activePlayers, p)
					end
				end
				spectatorModeRemote:FireClient(self.player, true, activePlayers)
			end
		end)
	else
		-- COM PERSONAGEM → SPAWN NO MAPA
		self:log(
			string.format("⚔️ SPAWN NO MAPA (%s) — usando PlayerTp", self.equippedCharacter)
		)

		updateRespawnLocation(self.player, true)
		task.wait(0.2)

		removeZoneSafeEffects(character)
		removePlayerBarrier(self.player)

		self.isInSafeZone = false
		self:stopDetection()

		pcall(function()
			if spectatorModeRemote then
				spectatorModeRemote:FireClient(self.player, false, {})
			end
		end)
	end

	-- Detectar morte
	pcall(function()
		humanoid.Died:Connect(function()
			self:log("💀 Morte detectada — voltando para lobby no próximo spawn")
			self.isDead = true
			self.hasCharacter = false
			self.equippedCharacter = nil
			self:stopDetection()
			removePlayerBarrier(self.player)
			updateRespawnLocation(self.player, false)
		end)
	end)

	self.isProcessing = false
end

-- =====================================
-- EVENTOS DE JOGADOR
-- =====================================

Players.PlayerAdded:Connect(function(player)
	if not isSystemReady then
		warn("[SPAWN V8] ⚠️ Sistema não pronto, aguardando...")
		while not isSystemReady do
			task.wait(0.5)
		end
	end

	local state = PlayerState.new(player)
	playerStates[player] = state

	state:log("✅ Conectado")

	updateRespawnLocation(player, false)

	player.CharacterAdded:Connect(function(character)
		task.wait(0.5)
		pcall(function()
			state:handleSpawn()
		end)
	end)

	player.CharacterRemoving:Connect(function()
		pcall(function()
			state:stopDetection()
			removePlayerBarrier(player)
		end)
	end)

	task.wait(1)
	-- (V8 fix) LoadCharacter está depreciado -> LoadCharacterAsync (yield, em pcall)
	pcall(function()
		player:LoadCharacterAsync()
	end)
end)

Players.PlayerRemoving:Connect(function(player)
	local state = playerStates[player]
	if state then
		state:log("👋 Desconectando")
		pcall(function()
			state:stopDetection()
		end)
	end
	pcall(function()
		removePlayerBarrier(player)
	end)
	playerStates[player] = nil
end)

-- =====================================
-- FUNÇÕES GLOBAIS
-- =====================================

_G.OnCharacterSelected = function(player, characterName)
	local state = playerStates[player]
	if state and state.isInSafeZone then
		pcall(function()
			state:handleEquipment(characterName)
		end)
	end
end

_G.SetSpectatorMode = function(player, enabled)
	local state = playerStates[player]
	if not state then
		return
	end

	pcall(function()
		if enabled then
			state.hasCharacter = false
			state.isInSafeZone = true

			updateRespawnLocation(player, false)

			if player.Character then
				teleportToLobby(player.Character)
				applyZoneSafeEffects(player.Character)
			end

			createPlayerBarrier(player)
			state:startDetection()
		end
	end)
end

-- =====================================
-- DEBUG
-- =====================================

_G.DebugSpawnState = function(playerName)
	local player = Players:FindFirstChild(playerName)
	if not player then
		print("❌ Jogador não encontrado")
		return
	end

	local state = playerStates[player]
	if not state then
		print("❌ Estado não encontrado")
		return
	end

	print(
		"\n═══════════════════════════════════════"
	)
	print(string.format("DEBUG SPAWN V8: %s", playerName))
	print(
		"═══════════════════════════════════════"
	)
	print("hasCharacter:      ", state.hasCharacter)
	print("isInSafeZone:      ", state.isInSafeZone)
	print("isDead:            ", state.isDead)
	print("equippedCharacter: ", state.equippedCharacter or "Nenhum")
	print("detectionActive:   ", state.detectionActive)
	print(
		"RespawnLocation:   ",
		player.RespawnLocation and player.RespawnLocation.Name or "MAPA (nil)"
	)
	print("Lobby Position:    ", tostring(LOBBY.POSITION))
	print("Map Spawn Points:  ", #mapSpawnPoints)
	print(
		"═══════════════════════════════════════\n"
	)
end

_G.ListAllPlayers = function()
	print("\n═══ JOGADORES ONLINE (SPAWN V8) ═══")
	for player, state in pairs(playerStates) do
		local location = state.hasCharacter and "⚔️ MAPA" or "🛡️ LOBBY"
		local respawnLoc = player.RespawnLocation and "Lobby" or "Mapa (PlayerTp)"
		print(string.format("  %s: %s | Next spawn: %s", player.Name, location, respawnLoc))
	end
	print(
		"═══════════════════════════════════\n"
	)
end

-- Recarregar spawn points em runtime (útil se PlayerTp mudar)
_G.ReloadMapSpawnPoints = function()
	collectMapSpawnPoints()
	print(string.format("[SPAWN V8] ✓ Spawn points recarregados: %d pontos", #mapSpawnPoints))
end

-- =====================================
-- INICIALIZAÇÃO FINAL
-- =====================================

-- 1. Coletar spawn points da pasta PlayerTp
collectMapSpawnPoints()

-- 2. Criar estrutura do lobby (centralizada sobre MapaPrincipal)
createLobbyStructure()

-- 3. Configurar jogadores já presentes
for _, player in pairs(Players:GetPlayers()) do
	updateRespawnLocation(player, false)
	print(string.format("[SPAWN V8] ✓ RespawnLocation configurado: %s", player.Name))
end

-- 4. Auto-sync (detecta personagem equipado enquanto no lobby)
task.spawn(function()
	while true do
		task.wait(2)

		for player, state in pairs(playerStates) do
			if player.Parent then
				pcall(function()
					local data = _G.PlayerDataManager.getPlayerData(player)

					if
						data
						and data.equippedCharacter
						and data.equippedCharacter ~= state.equippedCharacter
						and state.isInSafeZone
						and not state.hasCharacter
						and not state.isProcessing
					then
						state:log("🔄 Auto-sync detectado (equipou/trocou personagem)")
						state:handleEquipment(data.equippedCharacter)
					end
				end)
			end
		end
	end
end)

-- 4b. (V8) DETECTOR GEOMÉTRICO CONTÍNUO DA ZONA SEGURA
-- Fonte ÚNICA de verdade para a tag InSafeZone: vale a POSIÇÃO real.
-- • Dentro do lobby ........ protegido (tag + ForceField)
-- • Fora, com personagem ... sem proteção (está no mapa)
-- • Fora, sem personagem ... escapou: volta pro lobby e protege
-- (pula quem está em transição de equip — isProcessing)
task.spawn(function()
	while true do
		task.wait(CONFIG.CHECK_INTERVAL)
		for player, state in pairs(playerStates) do
			if player.Parent and player.Character and not state.isProcessing then
				local hrp = player.Character:FindFirstChild("HumanoidRootPart")
				local hum = player.Character:FindFirstChild("Humanoid")
				if hrp and hum and hum.Health > 0 then
					local inside = isInSafeZoneRegion(hrp.Position)

					if inside then
						-- Fisicamente na zona segura -> garante proteção
						if setSafeState(player.Character, true) then
							state.isInSafeZone = true
							pcall(function()
								if syncCharacterStateRemote then
									syncCharacterStateRemote:FireClient(
										player,
										state.equippedCharacter,
										state.hasCharacter
									)
								end
							end)
						end
					else
						if state.hasCharacter then
							-- No mapa -> remove proteção
							if setSafeState(player.Character, false) then
								state.isInSafeZone = false
							end
						else
							-- Sem personagem e fora = escape -> volta e protege
							if state:canTeleport() then
								state.lastTeleportTime = tick()
								local char = player.Character
								task.spawn(function()
									teleportToLobby(char)
									setSafeState(char, true)
								end)
								state.isInSafeZone = true
							end
						end
					end
				end
			end
		end
	end
end)

-- 5. Monitor de saúde
task.spawn(function()
	while true do
		task.wait(60)

		local inLobby, inMap = 0, 0

		for player, state in pairs(playerStates) do
			if player.Parent then
				if state.hasCharacter then
					inMap = inMap + 1
				else
					inLobby = inLobby + 1
				end
			end
		end

		print(
			string.format(
				"[SPAWN V8 HEALTH] Lobby: %d | Mapa: %d | Spawns: %d",
				inLobby,
				inMap,
				#mapSpawnPoints
			)
		)
	end
end)

print([[
╔════════════════════════════════════════════════════╗
║  ✅ SPAWN SYSTEM V8 CARREGADO                     ║
╠════════════════════════════════════════════════════╣
║  SUBSTITUI: SpawnSystem V7                        ║
║  ⚠️  REMOVER: SpawnSystem V7                      ║
╠════════════════════════════════════════════════════╣
║  NOVIDADES V6:                                     ║
║  • Lobby centralizado sobre "MapaPrincipal" ✓     ║
║  • Spawn points lidos de workspace.PlayerTp ✓     ║
║  • teleportToMapSpawn usa CFrame das Parts ✓      ║
║  • 1 único SpawnLocation no lobby (mantido) ✓     ║
╠════════════════════════════════════════════════════╣
║  SETUP NECESSÁRIO NO STUDIO:                       ║
║  • Modelo do mapa: nome exato "MapaPrincipal"     ║
║  • Pasta de spawns: workspace > "PlayerTp"        ║
║    └─ Adicione Parts onde os jogadores aparecem   ║
╠════════════════════════════════════════════════════╣
║  DEBUG:                                            ║
║  • _G.DebugSpawnState("Nome")                     ║
║  • _G.ListAllPlayers()                            ║
║  • _G.ReloadMapSpawnPoints() — recarrega PlayerTp ║
╚════════════════════════════════════════════════════╝
]])
