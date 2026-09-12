-- ============================================
-- ADMIN SYSTEM SERVER V9 — CONSOLE RETRO COM TABELA DE COMANDOS
-- Coloque em ServerScriptService
-- Nome: "AdminSystemServer"
-- SUBSTITUI: AdminSystemServer V8 (ou V7/V6/V5, se não instalados)
-- REMOVER:   AdminSystemServer V8 / V7 / V6 / V5
-- DEPENDE DE: AdminRegistryServer_V1 (ServerScriptService)
--             RetroCommands (ModuleScript, ServerScriptService) ← NOVO
-- ============================================
-- (V9) A CADEIA DE `elseif` VIROU TABELA DE COMANDOS
--
-- A cadeia do V8 tinha quatro defeitos que não eram de estilo:
--
--   1. SILÊNCIO. `Players:FindFirstChild(args[2])` devolvendo nil caía no
--      fim do `if` e NADA acontecia — nem erro, nem aviso. O admin não
--      sabia se errou o nome, se o jogador saiu, ou se o comando existe.
--   2. NOME EXATO OBRIGATÓRIO. Sem `me`, `all`, `others` ou prefixo
--      parcial. O dono joga no CELULAR: digitar o username inteiro com a
--      capitalização certa é a diferença entre o comando existir e não.
--   3. `;help` IMPRIMIA NO CONSOLE (F9). No celular não há F9 — a lista
--      de comandos era invisível para quem mais precisava dela.
--   4. COMANDO ERA CÓDIGO, não dado. O painel não tinha como listar o
--      que existe, então a lista vivia duplicada à mão aqui e no client.
--
-- Agora os comandos moram em `RetroCommands` (tabela + dispatcher), e
-- este script só monta o contexto e entrega o resultado na tela. Todo
-- caminho devolve mensagem: é o contrato que mata o defeito 1.
--
-- O formato "comando como dado, com nível e argumentos" vem do Adonis
-- (docs/ADONIS.md); o código e os comandos são do RetroVerse.
--
-- COMPATIBILIDADE: os 10 comandos do V8 continuam com o mesmo nome e o
-- mesmo efeito. Nada que você já digitava parou de funcionar.
-- ============================================
-- (V8) ALTERAÇÕES:
-- • LISTA "ADMIN_IDS" REMOVIDA DO CÓDIGO: quem é admin agora vem
--   do _G.AdminRegistry (AdminRegistryServer_V1) — o ÚNICO id no
--   Studio é o do DONO (1595442496); todos os outros são
--   adicionados dentro do jogo e ficam salvos no DataStore.
-- • NOVOS comandos de chat (só admins):
--   ;addadmin [username ou id] → vira admin em TODOS os servidores
--   ;deladmin [username ou id] → remove (o DONO é irremovível)
--   ;admins                    → lista os admins no console (F9)
-- • Comandos de chat agora funcionam pra admins adicionados COM O
--   JOGADOR JÁ DENTRO do servidor (sem precisar relogar): o
--   listener de chat conecta pra todo mundo e a checagem de admin
--   acontece na hora da mensagem.
-- ============================================
-- MANTIDO DO V7:
-- • Zero personagens no código — "Dar Todos"/";allchars" concedem
--   SOMENTE o catálogo dinâmico; catálogo vazio avisa o admin
-- MANTIDO DO V5:
-- • task.wait()/task.spawn(); nomes preservam capitalização;
--   getPlayerList retorna kills e inventário completo
-- ============================================
-- REUTILIZADO:
-- • _G.AdminRegistry (isAdmin/addAdmin/removeAdmin/listAll)
--   ......................... AdminRegistryServer_V1
-- • _G.CharacterCatalog.listAll() ... CharacterCatalogServer_V4
-- • notifyAdmin / logAction / remotes ... AdminSystemServer_V5/V6/V7
-- ============================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

repeat
	task.wait()
until _G.PlayerDataManager

print([[
╔════════════════════════════════════════════╗
║   ADMIN SYSTEM SERVER V9 - CARREGADO      ║
╚════════════════════════════════════════════╝
]])

-- =====================================
-- (V8) ADMINS: VIA _G.AdminRegistry
-- Fallback de segurança: se o AdminRegistryServer_V1 não estiver
-- instalado, só o DONO é admin (mesmo id do registry).
-- =====================================

local FALLBACK_OWNER_ID = 1595442496

do
	local waited = 0
	while not _G.AdminRegistry and waited < 15 do
		task.wait(0.5)
		waited += 0.5
	end
	if not _G.AdminRegistry then
		warn("[ADMIN V8] ⚠️ AdminRegistryServer_V1 não encontrado — só o DONO será admin!")
	end
end

local function isAdmin(player)
	if _G.AdminRegistry then
		return _G.AdminRegistry.isAdmin(player)
	end
	return player ~= nil and player.UserId == FALLBACK_OWNER_ID
end

-- =====================================
-- (V7) PERSONAGENS: SOMENTE DO CATÁLOGO DINÂMICO
-- =====================================

local function getAllCharacterNames()
	local names = {}

	if _G.CharacterCatalog and _G.CharacterCatalog.listAll then
		local ok, defs = pcall(_G.CharacterCatalog.listAll)
		if ok and type(defs) == "table" then
			for name in pairs(defs) do
				if type(name) == "string" then
					table.insert(names, name)
				end
			end
		end
	end

	table.sort(names)
	return names
end

-- =====================================
-- CRIAR REMOTES
-- =====================================

local remotes = ReplicatedStorage:WaitForChild("Remotes")

local function getOrCreateRemote(name, remoteType)
	local remote = remotes:FindFirstChild(name)
	if not remote then
		if remoteType == "Event" then
			remote = Instance.new("RemoteEvent")
		else
			remote = Instance.new("RemoteFunction")
		end
		remote.Name = name
		remote.Parent = remotes
	end
	return remote
end

local adminGiveCoins = getOrCreateRemote("AdminGiveCoins", "Event")
local adminGiveBounty = getOrCreateRemote("AdminGiveBounty", "Event")
local adminGiveCharacter = getOrCreateRemote("AdminGiveCharacter", "Event")
local adminGiveAllCharacters = getOrCreateRemote("AdminGiveAllCharacters", "Event")
local adminResetData = getOrCreateRemote("AdminResetData", "Event")
local adminTeleport = getOrCreateRemote("AdminTeleport", "Event")
local adminKill = getOrCreateRemote("AdminKill", "Event")
local adminKick = getOrCreateRemote("AdminKick", "Event")
local getPlayerList = getOrCreateRemote("GetPlayerList", "Function")

-- =====================================
-- FUNCOES AUXILIARES
-- =====================================

local function logAction(admin, action, target, details)
	print(
		string.format(
			"[ADMIN V8] %s executou %s em %s - %s",
			admin.Name,
			action,
			target and target.Name or "N/A",
			details or ""
		)
	)
end

local function notifyAdmin(admin, message, isSuccess)
	local gui = admin:FindFirstChild("PlayerGui")
	if not gui then
		return
	end

	local notification = Instance.new("ScreenGui")
	notification.Name = "AdminNotification"
	notification.DisplayOrder = 200
	notification.Parent = gui

	local frame = Instance.new("Frame")
	frame.Size = UDim2.new(0.35, 0, 0.08, 0)
	frame.Position = UDim2.new(0.325, 0, 0.05, 0)
	frame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
	frame.BorderColor3 = isSuccess and Color3.fromRGB(0, 220, 0) or Color3.fromRGB(220, 0, 0)
	frame.BorderSizePixel = 3
	frame.Parent = notification

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = frame

	local text = Instance.new("TextLabel")
	text.Size = UDim2.new(1, -10, 1, 0)
	text.Position = UDim2.new(0, 5, 0, 0)
	text.BackgroundTransparency = 1
	text.Text = message
	text.TextColor3 = Color3.new(1, 1, 1)
	text.TextScaled = true
	text.Font = Enum.Font.Arcade
	text.Parent = frame

	game:GetService("Debris"):AddItem(notification, 3)
end

-- =====================================
-- HANDLERS DE COMANDOS REMOTOS
-- =====================================

adminGiveCoins.OnServerEvent:Connect(function(admin, targetName, amount)
	if not isAdmin(admin) then
		admin:Kick("Tentativa nao autorizada de uso de comandos admin")
		return
	end

	local target = Players:FindFirstChild(targetName)
	if not target then
		notifyAdmin(admin, "Jogador nao encontrado!", false)
		return
	end

	amount = tonumber(amount) or 0
	if amount == 0 then
		notifyAdmin(admin, "Quantidade invalida!", false)
		return
	end

	_G.PlayerDataManager.updateCoins(target, amount)
	_G.PlayerDataManager.savePlayerData(target)

	logAction(admin, "GiveCoins", target, tostring(amount))
	notifyAdmin(admin, string.format("Deu %d moedas para %s", amount, target.Name), true)
end)

adminGiveBounty.OnServerEvent:Connect(function(admin, targetName, amount)
	if not isAdmin(admin) then
		admin:Kick("Tentativa nao autorizada de uso de comandos admin")
		return
	end

	local target = Players:FindFirstChild(targetName)
	if not target then
		notifyAdmin(admin, "Jogador nao encontrado!", false)
		return
	end

	amount = tonumber(amount) or 0
	if amount == 0 then
		notifyAdmin(admin, "Quantidade invalida!", false)
		return
	end

	_G.PlayerDataManager.updateBounty(target, amount)
	_G.PlayerDataManager.savePlayerData(target)

	logAction(admin, "GiveBounty", target, tostring(amount))
	notifyAdmin(admin, string.format("Deu %d bounty para %s", amount, target.Name), true)
end)

adminGiveCharacter.OnServerEvent:Connect(function(admin, targetName, characterName)
	if not isAdmin(admin) then
		admin:Kick("Tentativa nao autorizada de uso de comandos admin")
		return
	end

	local target = Players:FindFirstChild(targetName)
	if not target then
		notifyAdmin(admin, "Jogador nao encontrado!", false)
		return
	end

	if not characterName or characterName == "" then
		notifyAdmin(admin, "Nome de personagem invalido!", false)
		return
	end

	local success = _G.PlayerDataManager.addCharacterToInventory(target, characterName)
	if success then
		_G.PlayerDataManager.savePlayerData(target)
		logAction(admin, "GiveCharacter", target, characterName)
		notifyAdmin(admin, string.format("Deu %s para %s", characterName, target.Name), true)
	else
		notifyAdmin(admin, "Jogador ja possui este personagem!", false)
	end
end)

adminGiveAllCharacters.OnServerEvent:Connect(function(admin, targetName)
	if not isAdmin(admin) then
		admin:Kick("Tentativa nao autorizada de uso de comandos admin")
		return
	end

	local target = Players:FindFirstChild(targetName)
	if not target then
		notifyAdmin(admin, "Jogador nao encontrado!", false)
		return
	end

	-- (V7) Somente personagens do catálogo dinâmico
	local allNames = getAllCharacterNames()
	if #allNames == 0 then
		notifyAdmin(admin, "Catalogo vazio! Adicione personagens pelo painel primeiro.", false)
		return
	end

	local addedCount = 0
	for _, charName in ipairs(allNames) do
		if _G.PlayerDataManager.addCharacterToInventory(target, charName) then
			addedCount = addedCount + 1
		end
	end

	_G.PlayerDataManager.savePlayerData(target)
	logAction(admin, "GiveAllCharacters", target, addedCount .. " personagens (catalogo)")
	notifyAdmin(admin, string.format("Deu %d personagens para %s", addedCount, target.Name), true)
end)

adminResetData.OnServerEvent:Connect(function(admin, targetName)
	if not isAdmin(admin) then
		admin:Kick("Tentativa nao autorizada de uso de comandos admin")
		return
	end

	local target = Players:FindFirstChild(targetName)
	if not target then
		notifyAdmin(admin, "Jogador nao encontrado!", false)
		return
	end

	_G.PlayerDataManager.resetPlayerData(target)
	logAction(admin, "ResetData", target, "Dados resetados")
	notifyAdmin(admin, string.format("Resetou dados de %s", target.Name), true)
end)

adminTeleport.OnServerEvent:Connect(function(admin, targetName, destination)
	if not isAdmin(admin) then
		admin:Kick("Tentativa nao autorizada de uso de comandos admin")
		return
	end

	local target = Players:FindFirstChild(targetName)
	if not target or not target.Character then
		notifyAdmin(admin, "Jogador nao encontrado!", false)
		return
	end

	local hrp = target.Character:FindFirstChild("HumanoidRootPart")
	if not hrp then
		notifyAdmin(admin, "Personagem invalido!", false)
		return
	end

	local destinations = {
		SafeZone = Vector3.new(0, 503, 0),
		Spawn = Vector3.new(200, 10, 200),
	}

	local pos = destinations[destination]
	if pos then
		hrp.CFrame = CFrame.new(pos)
		logAction(admin, "Teleport", target, destination)
		notifyAdmin(admin, string.format("Teleportou %s para %s", target.Name, destination), true)
	else
		notifyAdmin(admin, "Destino invalido!", false)
	end
end)

adminKill.OnServerEvent:Connect(function(admin, targetName)
	if not isAdmin(admin) then
		admin:Kick("Tentativa nao autorizada de uso de comandos admin")
		return
	end

	local target = Players:FindFirstChild(targetName)
	if not target or not target.Character then
		notifyAdmin(admin, "Jogador nao encontrado!", false)
		return
	end

	local humanoid = target.Character:FindFirstChild("Humanoid")
	if humanoid then
		humanoid.Health = 0
		logAction(admin, "Kill", target, "Eliminado")
		notifyAdmin(admin, string.format("Eliminou %s", target.Name), true)
	end
end)

adminKick.OnServerEvent:Connect(function(admin, targetName, reason)
	if not isAdmin(admin) then
		admin:Kick("Tentativa nao autorizada de uso de comandos admin")
		return
	end

	local target = Players:FindFirstChild(targetName)
	if not target then
		notifyAdmin(admin, "Jogador nao encontrado!", false)
		return
	end

	reason = reason or "Expulso por um administrador"
	target:Kick(reason)
	logAction(admin, "Kick", target, reason)
	notifyAdmin(admin, string.format("Expulsou %s", target.Name), true)
end)

-- Retorna lista completa de jogadores para o painel admin
getPlayerList.OnServerInvoke = function(admin)
	if not isAdmin(admin) then
		return {}
	end

	local playerList = {}
	for _, player in pairs(Players:GetPlayers()) do
		local data = _G.PlayerDataManager.getPlayerData(player)
		table.insert(playerList, {
			name = player.Name,
			userId = player.UserId,
			coins = data and data.coins or 0,
			bounty = data and data.stats and data.stats.bounty or 0,
			deaths = data and data.stats and data.stats.deaths or 0,
			kills = data and data.stats and data.stats.kills or 0,
			equippedChar = data and data.equippedCharacter or "Nenhum",
			ownedCount = data and data.ownedCharacters and #data.ownedCharacters or 0,
		})
	end
	return playerList
end

-- =====================================
-- (V9) COMANDOS: TABELA + DISPATCHER
-- =====================================

local RetroCommands = require(script.Parent:WaitForChild("RetroCommands"))

-- NÍVEIS
-- O V8 era binário: ou você era admin e podia tudo, ou não era nada.
-- Agora há escala. O mapeamento é conservador de propósito, para NÃO
-- rebaixar quem já era admin:
--
--   dono (OWNER_ID)          -> DONO  (900)
--   admin do _G.AdminRegistry -> CHEFE (300)
--   resto                     -> JOGADOR (0)
--
-- Com CHEFE, todo comando que um admin já tinha no V8 continua na mão
-- dele. A ÚNICA restrição nova é `;reset`, que subiu para DONO: ele apaga
-- os dados do jogador e não tem desfazer, e "qualquer admin apaga
-- qualquer conta" é poder demais para um atalho de chat.
local function nivelDe(player)
	if player == nil then
		return RetroCommands.NIVEIS.JOGADOR
	end
	if player.UserId == FALLBACK_OWNER_ID then
		return RetroCommands.NIVEIS.DONO
	end
	if isAdmin(player) then
		return RetroCommands.NIVEIS.CHEFE
	end
	return RetroCommands.NIVEIS.JOGADOR
end

-- DEPENDÊNCIAS `_G` DOS COMANDOS
-- Escritas uma por uma, como código, de propósito. O contexto lê `_G` na
-- HORA do comando (via metatable, mais abaixo) porque a ordem de carga
-- dos scripts não é garantida — um snapshot no boot pegaria nil e ficaria
-- nil para sempre. Mas indexação dinâmica é invisível para a checagem 3
-- do `tools/validar.sh`, que é quem garante que nenhuma API `_G` é
-- consumida sem dono. Esta tabela devolve a checagem: os nomes aparecem
-- literalmente, e ainda servem para o diagnóstico de boot logo abaixo.
local DEPENDENCIAS = {
	PlayerDataManager = function()
		return _G.PlayerDataManager
	end,
	CharacterCatalog = function()
		return _G.CharacterCatalog
	end,
	AwakeningSystem = function()
		return _G.AwakeningSystem
	end,
	AwakeningMeter = function()
		return _G.AwakeningMeter
	end,
	CharacterLevel = function()
		return _G.CharacterLevel
	end,
	StatService = function()
		return _G.StatService
	end,
	StatusEffect = function()
		return _G.StatusEffect
	end,
	EnergySystem = function()
		return _G.EnergySystem
	end,
	PassiveSystem = function()
		return _G.PassiveSystem
	end,
	WantedSystem = function()
		return _G.WantedSystem
	end,
	AdminRegistry = function()
		return _G.AdminRegistry
	end,
	SimulateDamage = function()
		return _G.SimulateDamage
	end,
	ResetTutorial = function()
		return _G.ResetTutorial
	end,
	CheckAchievements = function()
		return _G.CheckAchievements
	end,
	TeleportToSafeZone = function()
		return _G.TeleportToSafeZone
	end,
	SetSpectatorMode = function()
		return _G.SetSpectatorMode
	end,
	GetPlayerTeam = function()
		return _G.GetPlayerTeam
	end,
	ReloadMapSpawnPoints = function()
		return _G.ReloadMapSpawnPoints
	end,
}

-- Leitura tardia: o comando pede `ctx.api.X` e recebe o valor de agora.
local APIS_AO_VIVO = setmetatable({}, {
	__index = function(_, nome)
		local buscar = DEPENDENCIAS[nome]
		return buscar and buscar() or nil
	end,
})

local function contextoDe(player)
	return {
		autor = player,
		nivel = nivelDe(player),
		jogadores = Players:GetPlayers(),
		api = APIS_AO_VIVO,
		personagemDe = function(alvo)
			return alvo and alvo.Character or nil
		end,
		humanoideDe = function(alvo)
			local personagem = alvo and alvo.Character
			return personagem and personagem:FindFirstChildOfClass("Humanoid") or nil
		end,
		raizDe = function(alvo)
			local personagem = alvo and alvo.Character
			return personagem and personagem:FindFirstChild("HumanoidRootPart") or nil
		end,
	}
end

-- Uma execução só, usada pelo chat E pelo console do painel — para as
-- duas portas não divergirem em permissão nem em mensagem.
local function executarComando(player, texto)
	local resultado = RetroCommands.executar(texto, contextoDe(player))
	if resultado == nil then
		return nil
	end

	-- Jogador comum que acerta um comando por acaso não recebe aula de
	-- quais comandos existem: silêncio no chat, sem vazar a lista.
	if resultado.negado and nivelDe(player) <= RetroCommands.NIVEIS.JOGADOR then
		return { ok = false, mensagem = "" }
	end

	notifyAdmin(player, resultado.mensagem, resultado.ok)
	logAction(
		player,
		"Cmd:" .. tostring(resultado.comando),
		nil,
		string.format("%s — %s", resultado.ok and "ok" or "falhou", resultado.mensagem)
	)
	return resultado
end

-- =====================================
-- (V9) REMOTES DO CONSOLE DO PAINEL
-- =====================================
-- A lista de comandos vem DO SERVIDOR, da mesma tabela que executa. É o
-- que impede o painel de mostrar comando que não existe mais, ou de
-- esconder comando novo — o defeito 4 do V8 era justamente a lista
-- duplicada à mão nos dois lados.
local listarComandos = getOrCreateRemote("AdminListCommands", "Function")
local rodarComando = getOrCreateRemote("AdminRunCommand", "Function")

listarComandos.OnServerInvoke = function(player)
	local nivel = nivelDe(player)
	return {
		nivel = nivel,
		nivelNome = RetroCommands.NOME_DO_NIVEL[nivel] or tostring(nivel),
		prefixo = RetroCommands.PREFIXO,
		comandos = RetroCommands.listarPara(nivel),
	}
end

-- Freio simples: o remote é público (qualquer cliente chama), e a recusa
-- por nível é barata mas não é de graça. Sem freio, um cliente hostil
-- transforma isto num laço de log no servidor.
local ultimoUso = {}
local INTERVALO_MINIMO = 0.25

Players.PlayerRemoving:Connect(function(player)
	ultimoUso[player] = nil
end)

rodarComando.OnServerInvoke = function(player, texto)
	if type(texto) ~= "string" or #texto > 300 then
		return { ok = false, mensagem = "comando inválido" }
	end

	local agora = os.clock()
	local anterior = ultimoUso[player]
	if anterior and agora - anterior < INTERVALO_MINIMO then
		return { ok = false, mensagem = "devagar" }
	end
	ultimoUso[player] = agora

	-- O painel manda sem prefixo ("coins me 100"); o chat manda com.
	-- Normaliza aqui para o dispatcher ver sempre a mesma coisa.
	local normalizado = texto
	if string.sub(texto, 1, #RetroCommands.PREFIXO) ~= RetroCommands.PREFIXO then
		normalizado = RetroCommands.PREFIXO .. texto
	end

	local resultado = executarComando(player, normalizado)
	if resultado == nil then
		return { ok = false, mensagem = "não é um comando" }
	end
	return { ok = resultado.ok, mensagem = resultado.mensagem }
end

-- =====================================
-- COMANDOS DE CHAT
-- (V8) Conecta pra TODO jogador e checa o nível NA HORA da mensagem —
-- assim, quem virar admin com o servidor já aberto usa os comandos sem
-- precisar relogar.
-- =====================================

local function onPlayerChatted(player, message)
	executarComando(player, message)
end

-- Diagnóstico de boot: diz quais APIs de comando não subiram neste
-- servidor. Sem isto, a primeira notícia de que um sistema não carregou
-- seria um comando respondendo "X não está carregado" no meio de uma
-- partida.
task.spawn(function()
	task.wait(10)
	local ausentes = {}
	for nome, buscar in DEPENDENCIAS do
		if buscar() == nil then
			table.insert(ausentes, nome)
		end
	end
	if #ausentes > 0 then
		table.sort(ausentes)
		warn(
			string.format(
				"[ADMIN V9] %d API(s) de comando fora do ar: %s — os comandos que dependem delas vão avisar em vez de falhar calados.",
				#ausentes,
				table.concat(ausentes, ", ")
			)
		)
	else
		print(string.format("[ADMIN V9] %d comandos prontos, todas as APIs no ar.", #RetroCommands.COMANDOS))
	end
end)

Players.PlayerAdded:Connect(function(player)
	if isAdmin(player) then
		print("[ADMIN V8] Admin conectado:", player.Name)
	end

	player.Chatted:Connect(function(message)
		onPlayerChatted(player, message)
	end)
end)

-- Cobre jogadores que já estavam no servidor quando o script subiu
for _, player in ipairs(Players:GetPlayers()) do
	player.Chatted:Connect(function(message)
		onPlayerChatted(player, message)
	end)
end

print([[
╔════════════════════════════════════════════════════╗
║  ✅ ADMIN SYSTEM SERVER V8 CARREGADO              ║
╠════════════════════════════════════════════════════╣
║  SUBSTITUI: AdminSystemServer V7 / V6 / V5        ║
║  DEPENDE DE: AdminRegistryServer_V1               ║
╠════════════════════════════════════════════════════╣
║  (V8) MUDANÇAS:                                    ║
║  • ADMIN_IDS removida → _G.AdminRegistry           ║
║  • ;addadmin / ;deladmin / ;admins (sem Studio)    ║
║  • Admin novo usa comandos sem relogar             ║
║  (V7) Dar Todos/;allchars = SÓ catálogo dinâmico   ║
╚════════════════════════════════════════════════════╝
]])
