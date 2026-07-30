-- ============================================
-- ADMIN SYSTEM SERVER V8 — ADMINS DINÂMICOS (SEM STUDIO)
-- Coloque em ServerScriptService
-- Nome: "AdminSystemServer"
-- SUBSTITUI: AdminSystemServer V7 (ou V6/V5, se não instalados)
-- REMOVER:   AdminSystemServer V7 / V6 / V5
-- DEPENDE DE: AdminRegistryServer_V1 (novo, no ServerScriptService)
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
║   ADMIN SYSTEM SERVER V8 - CARREGADO      ║
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
-- COMANDOS DE CHAT
-- (V8) Conecta pra TODO jogador e checa admin NA HORA da mensagem —
-- assim, quem virar admin com o servidor já aberto usa os comandos
-- sem precisar relogar.
-- (mantido V5: não lowercasear nome do jogador/personagem)
-- =====================================

local function onPlayerChatted(player, message)
	if not isAdmin(player) then
		return
	end

	-- Dividir sem forcar lowercase no comando inteiro
	local args = string.split(message, " ")
	local cmd = args[1] and args[1]:lower() or ""

	if cmd == ";coins" and args[2] and args[3] then
		local target = Players:FindFirstChild(args[2])
		local amount = tonumber(args[3])
		if target and amount then
			_G.PlayerDataManager.updateCoins(target, amount)
			_G.PlayerDataManager.savePlayerData(target)
			logAction(player, "ChatCmd:Coins", target, tostring(amount))
		end
	elseif cmd == ";bounty" and args[2] and args[3] then
		local target = Players:FindFirstChild(args[2])
		local amount = tonumber(args[3])
		if target and amount then
			_G.PlayerDataManager.updateBounty(target, amount)
			_G.PlayerDataManager.savePlayerData(target)
			logAction(player, "ChatCmd:Bounty", target, tostring(amount))
		end
	elseif cmd == ";char" and args[2] and args[3] then
		-- Nome do personagem preserva capitalização original (ex: "Gui Bomba")
		local target = Players:FindFirstChild(args[2])
		local charName = table.concat(args, " ", 3)
		if target and charName ~= "" then
			_G.PlayerDataManager.addCharacterToInventory(target, charName)
			_G.PlayerDataManager.savePlayerData(target)
			logAction(player, "ChatCmd:Character", target, charName)
		end
	elseif cmd == ";allchars" and args[2] then
		local target = Players:FindFirstChild(args[2])
		if target then
			-- (V7) Somente personagens do catálogo dinâmico
			local allNames = getAllCharacterNames()
			if #allNames == 0 then
				print("[ADMIN V8] Catalogo vazio — nada para conceder.")
				notifyAdmin(player, "Catalogo vazio! Adicione personagens pelo painel primeiro.", false)
			else
				for _, charName in ipairs(allNames) do
					_G.PlayerDataManager.addCharacterToInventory(target, charName)
				end
				_G.PlayerDataManager.savePlayerData(target)
				logAction(player, "ChatCmd:AllChars", target, #allNames .. " do catalogo")
			end
		end
	elseif cmd == ";addadmin" and args[2] then
		-- (V8) Novo admin por username ou id — salvo no DataStore e
		-- sincronizado em todos os servidores (AdminRegistryServer_V1)
		if _G.AdminRegistry then
			local input = table.concat(args, " ", 2)
			local ok, msg = _G.AdminRegistry.addAdmin(player, input)
			notifyAdmin(player, msg, ok)
			logAction(player, "ChatCmd:AddAdmin", nil, input .. " → " .. tostring(msg))
		else
			notifyAdmin(player, "AdminRegistryServer_V1 nao instalado!", false)
		end
	elseif cmd == ";deladmin" and args[2] then
		if _G.AdminRegistry then
			local input = table.concat(args, " ", 2)
			local ok, msg = _G.AdminRegistry.removeAdmin(player, input)
			notifyAdmin(player, msg, ok)
			logAction(player, "ChatCmd:DelAdmin", nil, input .. " → " .. tostring(msg))
		else
			notifyAdmin(player, "AdminRegistryServer_V1 nao instalado!", false)
		end
	elseif cmd == ";admins" then
		if _G.AdminRegistry then
			local list = _G.AdminRegistry.listAll()
			print("\n[ADMIN V8] LISTA DE ADMINS:")
			for _, entry in ipairs(list) do
				print(
					string.format(
						"  %s | ID: %d | por: %s%s",
						entry.name,
						entry.userId,
						entry.addedBy,
						entry.isOwner and " | 🔑 DONO" or ""
					)
				)
			end
			notifyAdmin(player, #list .. " admin(s) — lista no console (F9)", true)
		else
			notifyAdmin(player, "AdminRegistryServer_V1 nao instalado!", false)
		end
	elseif cmd == ";reset" and args[2] then
		local target = Players:FindFirstChild(args[2])
		if target then
			_G.PlayerDataManager.resetPlayerData(target)
			logAction(player, "ChatCmd:Reset", target, "Resetado")
		end
	elseif cmd == ";kill" and args[2] then
		local target = Players:FindFirstChild(args[2])
		if target and target.Character then
			local humanoid = target.Character:FindFirstChild("Humanoid")
			if humanoid then
				humanoid.Health = 0
				logAction(player, "ChatCmd:Kill", target, "Eliminado")
			end
		end
	elseif cmd == ";tp" and args[2] then
		local target = Players:FindFirstChild(args[2])
		if target and target.Character and player.Character then
			local hrp = target.Character:FindFirstChild("HumanoidRootPart")
			local adminHrp = player.Character:FindFirstChild("HumanoidRootPart")
			if hrp and adminHrp then
				hrp.CFrame = adminHrp.CFrame
				logAction(player, "ChatCmd:Teleport", target, "Para admin")
			end
		end
	elseif cmd == ";help" then
		print("\n[ADMIN V8 COMMANDS]")
		print("  ;coins [jogador] [quantidade]")
		print("  ;bounty [jogador] [quantidade]")
		print("  ;char [jogador] [personagem]")
		print("  ;allchars [jogador]  (somente catalogo)")
		print("  ;addadmin [username ou id]  (salvo sem Studio)")
		print("  ;deladmin [username ou id]  (dono e irremovivel)")
		print("  ;admins  (lista no console)")
		print("  ;reset [jogador]")
		print("  ;kill [jogador]")
		print("  ;tp [jogador]")
	end
end

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
