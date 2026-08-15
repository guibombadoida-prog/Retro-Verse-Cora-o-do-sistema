-- ============================================
-- GAME MANAGER V10 — DESPERTAR VIRA FORMA TEMPORÁRIA
-- Coloque em ServerScriptService
-- Nome: "GameManager"
-- SUBSTITUI: GameManager V9
-- ============================================
-- (V10) ALTERAÇÕES:
-- • O DESPERTAR NÃO É MAIS PERMANENTE. Até o V9 a forma despertada era
--   decidida por `_G.PlayerDataManager.hasAwakening`, ou seja, quem
--   tinha o Despertar desbloqueado nascia desperto e ficava assim o
--   tempo todo. Agora quem decide é o AwakeningMeterServer: a barra
--   enche batendo e apanhando, dispara a forma, ela dura um tempo e
--   volta ao normal. Esta função é chamada de novo a cada troca de
--   forma, via _G.GameManagerConfig.reapplyEquippedTools.
-- • 🐞 CURA DE GRAÇA EVITADA: equipCharacter faz `humanoid.Health =
--   health`. Como o medidor chama esta função no meio da luta, despertar
--   curaria o jogador por completo — bastava despertar para apagar todo
--   o dano recebido. Agora, quando é REMONTAGEM (mesmo personagem já
--   equipado), a proporção de vida é mantida: muda o teto, não o quanto
--   o jogador está ferido.
-- ============================================
-- (V9) ALTERAÇÕES:
-- • 🐞 BUG CRÍTICO CORRIGIDO (o motivo do "não dá para equipar de
--   jeito nenhum"): playerOwnsCharacter fazia
--   `return _G.PlayerDataManager.ownsCharacter(...)` na PRIMEIRA
--   linha — retorno imediato mesmo quando era false. Toda a lógica
--   de desbloqueio abaixo (Grátis/Bounty/Gamepass/Badge) era código
--   MORTO desde o V6 original: nunca executava. Agora só retorna
--   cedo quando o jogador JÁ possui; senão, segue pras condições
--   de desbloqueio. Isso conserta Grátis, Bounty e Badge via loja.
-- • 🧹 ZERO PERSONAGENS NO CÓDIGO: todas as tabelas fixas foram
--   REMOVIDAS (preços, bounty, gamepasses "Faker Gui"/"Alma
--   Perdida", badges, vidas, e o "Noob" especial). O catálogo
--   dinâmico (_G.GameContentConfig, do CharacterCatalogServer_V4)
--   é a ÚNICA fonte de personagens do jogo.
-- • checkGamepasses agora varre SÓ o catálogo.
-- • Desbloqueio por Bounty agora também grava no inventário
--   (source "Reward" via DataManager_V6) — antes equipava mas não
--   aparecia no menu Inventário.
-- • Mantido do V8: Despertar (AwakenedForm + hasAwakening) e
--   _G.GameManagerConfig.reapplyEquippedTools.
-- ============================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BadgeService = game:GetService("BadgeService")
local MarketplaceService = game:GetService("MarketplaceService")
local Debris = game:GetService("Debris")

-- Aguardar sistemas
repeat
	task.wait()
until _G.PlayerDataManager
if _G.AwakeningSystem then
	print("[GAME MGR V9] Sistema de despertar detectado")
end

print([[
╔══════════════════════════════════════════════╗
║     GAME MANAGER V9 - INICIALIZANDO          ║
╚══════════════════════════════════════════════╝
]])

-- =====================================
-- REMOTES
-- =====================================

local remotes = ReplicatedStorage:FindFirstChild("Remotes")
if not remotes then
	remotes = Instance.new("Folder")
	remotes.Name = "Remotes"
	remotes.Parent = ReplicatedStorage
end

local charactersFolder = ReplicatedStorage:FindFirstChild("Characters")
if not charactersFolder then
	charactersFolder = Instance.new("Folder")
	charactersFolder.Name = "Characters"
	charactersFolder.Parent = ReplicatedStorage
end

local characterImages = ReplicatedStorage:FindFirstChild("CharacterImages")
if not characterImages then
	characterImages = Instance.new("Folder")
	characterImages.Name = "CharacterImages"
	characterImages.Parent = ReplicatedStorage
	print("[GAME MGR V9] Pasta 'CharacterImages' criada")
end

local function ensureRemoteType(name, requiredType)
	local existing = remotes:FindFirstChild(name)

	if existing then
		if requiredType == "RemoteFunction" and not existing:IsA("RemoteFunction") then
			existing.Parent = nil
			existing = nil
		elseif requiredType == "RemoteEvent" and not existing:IsA("RemoteEvent") then
			existing.Parent = nil
			existing = nil
		end
	end

	if not existing then
		existing = Instance.new(requiredType)
		existing.Name = name
		existing.Parent = remotes
		print(string.format("[GAME MGR V9] Remote criado: %s (%s)", name, requiredType))
	end

	return existing
end

local selectCharacter = ensureRemoteType("SelectCharacter", "RemoteFunction")
local purchaseCharacter = ensureRemoteType("PurchaseCharacter", "RemoteFunction")
local getPlayerData = ensureRemoteType("GetPlayerData", "RemoteFunction")
local syncCharacterState = ensureRemoteType("SyncCharacterState", "RemoteEvent")
local sellCharacter = ensureRemoteType("SellCharacter", "RemoteFunction")

-- =====================================
-- (V9) ZERO PERSONAGENS NO CÓDIGO
-- Tabelas mantidas VAZIAS só por compatibilidade com scripts que
-- leem _G.GameManagerConfig — NÃO adicione personagens aqui!
-- Personagens são adicionados APENAS pelo painel admin no jogo
-- (CharacterCatalogServer_V4).
-- =====================================

local characterPrices = {}
local bountyCharacters = {}
local gamepassCharacters = {}
local badgeIds = {}
local characterHealth = {}

-- =====================================
-- CATÁLOGO DINÂMICO — fonte ÚNICA (CharacterCatalogServer_V4)
-- =====================================

local function getCatalogTable(tableName)
	if _G.GameContentConfig then
		return _G.GameContentConfig[tableName] or {}
	end
	return {}
end

local function getCharacterPrice(characterName)
	return getCatalogTable("characterPrices")[characterName]
end

local function getCharacterHealth(characterName)
	return getCatalogTable("characterHealth")[characterName] or 100
end

local function getBountyRequirement(characterName)
	return getCatalogTable("bountyCharacters")[characterName]
end

local function getGamepassId(characterName)
	return getCatalogTable("gamepassCharacters")[characterName]
end

local function getBadgeId(characterName)
	return getCatalogTable("badgeCharacters")[characterName]
end

local function isMandatoryCatalogCharacter(characterName)
	return table.find(getCatalogTable("mandatoryCharacters"), characterName) ~= nil
end

-- =====================================
-- SELL CONFIG
-- =====================================

local SELL_PERCENTAGE = 0.25 -- 25%

-- =====================================
-- VARIÁVEIS
-- =====================================

local equippedCharacters = {}
local lastDamager = {}
local characterDeathConnections = {}
local sellCooldowns = {}

-- =====================================
-- (V9) POSSE + DESBLOQUEIO — BUG DO RETORNO ANTECIPADO CORRIGIDO
-- =====================================

local function playerOwnsCharacter(player, characterName)
	-- Já está no inventário? → possui
	if _G.PlayerDataManager.ownsCharacter(player, characterName) then
		return true
	end

	-- (V9) ANTES: aqui existia `return ownsCharacter(...)` que
	-- devolvia FALSE direto e nunca deixava o código abaixo rodar.
	-- AGORA: continua para as condições de desbloqueio.

	-- Grátis (Mandatory do catálogo) — rede de segurança; o
	-- CharacterCatalogServer_V4 já concede no login e no add
	if isMandatoryCatalogCharacter(characterName) then
		_G.PlayerDataManager.addCharacterToInventory(player, characterName)
		_G.PlayerDataManager.savePlayerData(player)
		return true
	end

	-- Bounty (Reward): atingiu o requisito → entra no inventário
	local bountyNeeded = getBountyRequirement(characterName)
	if bountyNeeded then
		local bounty = 0
		local ls = player:FindFirstChild("leaderstats")
		if ls then
			local bv = ls:FindFirstChild("Bounty")
			if bv then
				bounty = bv.Value
			end
		end
		if bounty >= bountyNeeded then
			-- (V9) grava no inventário (source Reward via DataManager_V6)
			_G.PlayerDataManager.addCharacterToInventory(player, characterName)
			_G.PlayerDataManager.savePlayerData(player)
			return true
		end
		return false
	end

	-- Gamepass
	local gpId = getGamepassId(characterName)
	if gpId and gpId > 0 then
		local ok, has = pcall(function()
			return MarketplaceService:UserOwnsGamePassAsync(player.UserId, gpId)
		end)
		if ok and has then
			_G.PlayerDataManager.addCharacterToInventory(player, characterName)
			_G.PlayerDataManager.savePlayerData(player)
			return true
		end
		return false
	end

	-- Badge (Emblema)
	local bid = getBadgeId(characterName)
	if bid and bid > 0 then
		local ok, has = pcall(function()
			return BadgeService:UserHasBadgeAsync(player.UserId, bid)
		end)
		if ok and has then
			_G.PlayerDataManager.addCharacterToInventory(player, characterName)
			_G.PlayerDataManager.savePlayerData(player)
			return true
		end
		return false
	end

	return false
end

-- =====================================
-- DESEQUIPAR PERSONAGEM
-- =====================================

local function unequipCharacter(player)
	if not equippedCharacters[player] then
		return
	end

	local characterName = equippedCharacters[player]
	print(string.format("[GAME MGR V9] Desequipando %s de %s", characterName, player.Name))

	equippedCharacters[player] = nil

	local playerData = _G.PlayerDataManager.getPlayerData(player)
	if playerData then
		playerData.equippedCharacter = nil
	end

	pcall(function()
		syncCharacterState:FireClient(player, nil, false)
	end)

	if characterDeathConnections[player] then
		pcall(function()
			characterDeathConnections[player]:Disconnect()
		end)
		characterDeathConnections[player] = nil
	end
end

-- =====================================
-- EQUIPAR PERSONAGEM (mantido do V8, com Despertar)
-- =====================================

local function equipCharacter(player, characterName)
	if not player or not player.Character then
		return false
	end

	local character = player.Character
	local humanoid = character:FindFirstChild("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return false
	end

	-- =====================================
	-- (V10) DESPERTAR: FORMA TEMPORÁRIA, NÃO POSSE PERMANENTE
	-- =====================================
	-- Até o V9 o Despertar era decidido por `hasAwakening`, ou seja,
	-- quem tinha o Despertar desbloqueado ficava desperto O TEMPO TODO,
	-- desde o spawn. Agora o Despertar é uma forma temporária: a barra
	-- do AwakeningMeterServer enche batendo e apanhando, dispara, dura
	-- um tempo e volta ao normal.
	--
	-- Esta função é chamada de novo pelo medidor (via
	-- _G.GameManagerConfig.reapplyEquippedTools) toda vez que a forma
	-- muda, e é o `estaDesperto` abaixo que decide de qual pasta as
	-- Tools saem: `characterFolder` ou `characterFolder.AwakenedForm`.
	local usingAwakened = false
	local health = getCharacterHealth(characterName)

	local awakenedDef = _G.AwakeningSystem and _G.AwakeningSystem.getDefinition(characterName)

	if awakenedDef and _G.AwakeningMeter and _G.AwakeningMeter.estaDesperto then
		usingAwakened = _G.AwakeningMeter.estaDesperto(player) == true
	end

	if usingAwakened and awakenedDef then
		health = awakenedDef.health or health
	end

	-- (V10) A vida só é ENCHIDA num equipar de verdade.
	-- Quando o medidor remonta as Tools no meio da luta (despertou ou
	-- voltou ao normal), encher aqui daria cura total de graça: bastava
	-- despertar para zerar o dano recebido. Nesse caso a PROPORÇÃO de
	-- vida é mantida — muda o teto, não o quanto o jogador está ferido.
	local remontagem = equippedCharacters[player] == characterName
	local proporcao = 1

	if remontagem and humanoid.MaxHealth > 0 then
		proporcao = math.clamp(humanoid.Health / humanoid.MaxHealth, 0, 1)
	end

	humanoid.MaxHealth = health
	humanoid.Health = remontagem and math.max(1, health * proporcao) or health

	-- Limpar ferramentas
	local backpack = player:FindFirstChild("Backpack")
	if not backpack then
		backpack = Instance.new("Backpack")
		backpack.Parent = player
	end

	for _, tool in pairs(backpack:GetChildren()) do
		if tool:IsA("Tool") then
			tool.Parent = nil
		end
	end
	for _, tool in pairs(character:GetChildren()) do
		if tool:IsA("Tool") then
			tool.Parent = nil
		end
	end

	-- Dar ferramentas (da forma despertada, se desbloqueada)
	local characterFolder = charactersFolder:FindFirstChild(characterName)
	if characterFolder then
		local toolsSource = characterFolder
		if usingAwakened then
			local awakenedFolder = characterFolder:FindFirstChild("AwakenedForm")
			if awakenedFolder then
				toolsSource = awakenedFolder
			end
		end
		for _, item in pairs(toolsSource:GetChildren()) do
			if item:IsA("Tool") then
				item:Clone().Parent = backpack
			end
		end
	end

	equippedCharacters[player] = characterName

	local playerData = _G.PlayerDataManager.getPlayerData(player)
	if playerData then
		playerData.equippedCharacter = characterName
	end

	syncCharacterState:FireClient(player, characterName, true)

	if _G.OnCharacterSelected then
		_G.OnCharacterSelected(player, characterName)
	end

	print(
		string.format(
			"[GAME MGR V9] %s equipou %s (%d HP)%s",
			player.Name,
			characterName,
			health,
			usingAwakened and " [DESPERTO]" or ""
		)
	)
	return true
end

-- =====================================
-- REMOTE: SELECIONAR PERSONAGEM
-- =====================================

local function handleSelectCharacter(player, characterName)
	if type(characterName) ~= "string" then
		return false, "Dados inválidos!"
	end

	local character = player.Character
	if character then
		local humanoid = character:FindFirstChild("Humanoid")
		if equippedCharacters[player] and humanoid and humanoid.Health > 0 then
			return false, "Você precisa morrer para trocar de personagem!"
		end
	end

	if not playerOwnsCharacter(player, characterName) then
		local bountyNeeded = getBountyRequirement(characterName)
		if bountyNeeded then
			return false, "Você precisa de " .. bountyNeeded .. " de bounty!"
		elseif getGamepassId(characterName) then
			return false, "Você precisa comprar o gamepass!"
		elseif getBadgeId(characterName) then
			return false, "Você precisa conquistar o emblema!"
		end
		return false, "Você não possui este personagem!"
	end

	local success = equipCharacter(player, characterName)
	if success then
		return true, characterName
	else
		return false, "Erro ao equipar personagem!"
	end
end

selectCharacter.OnServerInvoke = handleSelectCharacter
_G.SelectCharacterFunction = handleSelectCharacter

-- =====================================
-- REMOTE: COMPRAR PERSONAGEM
-- =====================================

purchaseCharacter.OnServerInvoke = function(player, characterName)
	if type(characterName) ~= "string" then
		return false, "Dados inválidos!"
	end

	local playerData = _G.PlayerDataManager.getPlayerData(player)
	if not playerData then
		return false, "Erro ao carregar dados!"
	end

	if _G.PlayerDataManager.ownsCharacter(player, characterName) then
		return false, "Você já possui este personagem!"
	end

	local price = getCharacterPrice(characterName)
	if not price then
		return false, "Personagem não encontrado na loja!"
	end

	if playerData.coins < price then
		return false, "Moedas insuficientes! Precisa de " .. price
	end

	_G.PlayerDataManager.updateCoins(player, -price)
	local success, charId = _G.PlayerDataManager.addCharacter(player, characterName, "Shop", price)

	if not success then
		_G.PlayerDataManager.updateCoins(player, price)
		return false, "Erro ao adicionar personagem!"
	end

	_G.PlayerDataManager.savePlayerData(player)

	print(string.format("[GAME MGR V9] %s comprou %s por %d moedas", player.Name, characterName, price))
	return true, "Personagem comprado com sucesso!"
end

-- =====================================
-- REMOTE: OBTER DADOS DO JOGADOR
-- =====================================

getPlayerData.OnServerInvoke = function(player)
	if _G.PlayerDataManager.getClientData then
		local data = _G.PlayerDataManager.getClientData(player)
		if data and equippedCharacters[player] then
			data.equippedCharacter = equippedCharacters[player]
		end
		return data
	end

	local data = _G.PlayerDataManager.getPlayerData(player)
	if data and equippedCharacters[player] then
		data.equippedCharacter = equippedCharacters[player]
	end
	return data
end

-- =====================================
-- SISTEMA DE VENDA DE PERSONAGENS (mantido do V8)
-- =====================================

local function calculateSellPrice(charObj)
	if not charObj then
		return 0
	end

	if charObj.source == "Reward" then
		return 0
	end

	if not charObj.originalPrice or charObj.originalPrice <= 0 then
		return 0
	end

	return math.floor(charObj.originalPrice * SELL_PERCENTAGE)
end

sellCharacter.OnServerInvoke = function(player, charId)
	if type(charId) ~= "string" then
		return false, "Dados inválidos!", 0
	end

	if #charId > 100 then
		return false, "Dados inválidos!", 0
	end

	local now = tick()
	if sellCooldowns[player] and now - sellCooldowns[player] < 1 then
		return false, "Aguarde antes de vender novamente!", 0
	end
	sellCooldowns[player] = now

	local playerData = _G.PlayerDataManager.getPlayerData(player)
	if not playerData then
		return false, "Erro ao carregar dados!", 0
	end

	local charObj, charIndex = _G.PlayerDataManager.getCharacterById(player, charId)
	if not charObj then
		return false, "Personagem não encontrado no seu inventário!", 0
	end

	if equippedCharacters[player] == charObj.name then
		return false, "Desequipe o personagem antes de vender! (Morra primeiro)", 0
	end

	if not charObj.sellable then
		local reasons = {
			Mandatory = "Personagens obrigatórios não podem ser vendidos!",
			Gamepass = "Personagens de Gamepass não podem ser vendidos!",
			Badge = "Personagens de Badge não podem ser vendidos!",
			Reward = "Personagens de Recompensa (Bounty) não podem ser vendidos!",
			Awakened = "Personagens Despertados não podem ser vendidos!",
		}
		local reason = reasons[charObj.source] or "Este personagem não pode ser vendido!"
		return false, reason, 0
	end

	local sellPrice = calculateSellPrice(charObj)
	if sellPrice <= 0 then
		return false, "Este personagem não tem valor de venda!", 0
	end

	local removed, removedObj = _G.PlayerDataManager.removeCharacterById(player, charId)
	if not removed then
		return false, "Erro ao remover personagem!", 0
	end

	_G.PlayerDataManager.updateCoins(player, sellPrice)

	playerData.stats.characters_sold = (playerData.stats.characters_sold or 0) + 1

	_G.PlayerDataManager.savePlayerData(player)

	print(
		string.format(
			"[GAME MGR V9] %s vendeu %s por %d moedas (25%% de %d)",
			player.Name,
			charObj.name,
			sellPrice,
			charObj.originalPrice
		)
	)

	return true, string.format("Vendeu %s por %d moedas!", charObj.name, sellPrice), sellPrice
end

-- =====================================
-- SISTEMA DE KILL / DEATH (mantido do V8)
-- =====================================

local function onCharacterAdded(character)
	local humanoid = character:WaitForChild("Humanoid")
	local player = Players:GetPlayerFromCharacter(character)
	if not player then
		return
	end

	if characterDeathConnections[player] then
		pcall(function()
			characterDeathConnections[player]:Disconnect()
		end)
	end

	characterDeathConnections[player] = humanoid.Died:Connect(function()
		unequipCharacter(player)
		_G.PlayerDataManager.incrementStat(player, "deaths", 1)

		local killer = lastDamager[player]
		if killer and killer ~= player and killer.Parent then
			_G.PlayerDataManager.updateCoins(killer, 50)
			_G.PlayerDataManager.updateBounty(killer, 10)
			_G.PlayerDataManager.incrementStat(killer, "kills", 1)

			local gui = killer:FindFirstChild("PlayerGui")
			if gui then
				local notification = Instance.new("ScreenGui")
				notification.Name = "KillNotification"
				notification.Parent = gui

				local frame = Instance.new("Frame")
				frame.Size = UDim2.new(0.3, 0, 0.1, 0)
				frame.Position = UDim2.new(0.35, 0, 0.05, 0)
				frame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
				frame.BorderColor3 = Color3.fromRGB(255, 0, 0)
				frame.BorderSizePixel = 3
				frame.Parent = notification

				local text = Instance.new("TextLabel")
				text.Size = UDim2.new(1, 0, 1, 0)
				text.BackgroundTransparency = 1
				text.Text = "ELIMINASTE " .. player.Name:upper() .. "! +$50 +10B"
				text.TextColor3 = Color3.new(1, 1, 1)
				text.TextScaled = true
				text.Font = Enum.Font.Arcade
				text.Parent = frame

				Debris:AddItem(notification, 3)
			end
		end

		lastDamager[player] = nil
	end)

	character.ChildAdded:Connect(function(tool)
		if tool:IsA("Tool") then
			local handle = tool:FindFirstChild("Handle")
			if handle then
				handle.Touched:Connect(function(hit)
					if hit and hit.Parent then
						local hitHumanoid = hit.Parent:FindFirstChild("Humanoid")
						if hitHumanoid and hitHumanoid.Parent ~= character then
							local victim = Players:GetPlayerFromCharacter(hit.Parent)
							if victim then
								lastDamager[victim] = player
								task.wait(10)
								if lastDamager[victim] == player then
									lastDamager[victim] = nil
								end
							end
						end
					end
				end)
			end
		end
	end)
end

-- =====================================
-- VERIFICAR GAMEPASSES (V9: só catálogo)
-- =====================================

local function checkGamepasses(player)
	task.wait(2)

	for charName, gpId in pairs(getCatalogTable("gamepassCharacters")) do
		if gpId and gpId > 0 then
			local ok, has = pcall(function()
				return MarketplaceService:UserOwnsGamePassAsync(player.UserId, gpId)
			end)
			if ok and has then
				if not _G.PlayerDataManager.ownsCharacter(player, charName) then
					_G.PlayerDataManager.addCharacterToInventory(player, charName)
					print(string.format("[GAME MGR V9] Auto-adicionado %s para %s", charName, player.Name))
				end
			end
		end
	end

	_G.PlayerDataManager.savePlayerData(player)
end

-- =====================================
-- EVENTOS DE JOGADOR
-- =====================================

Players.PlayerAdded:Connect(function(player)
	print(string.format("[GAME MGR V9] %s entrou no jogo", player.Name))

	task.spawn(function()
		checkGamepasses(player)
	end)

	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(character)
	end)

	player.CharacterRemoving:Connect(function()
		lastDamager[player] = nil
		if characterDeathConnections[player] then
			pcall(function()
				characterDeathConnections[player]:Disconnect()
			end)
			characterDeathConnections[player] = nil
		end
	end)
end)

Players.PlayerRemoving:Connect(function(player)
	unequipCharacter(player)
	lastDamager[player] = nil
	sellCooldowns[player] = nil

	local playerData = _G.PlayerDataManager.getPlayerData(player)
	if playerData then
		playerData.equippedCharacter = nil
		_G.PlayerDataManager.savePlayerData(player)
	end
end)

-- =====================================
-- EXPORTAR CONFIG PARA OUTROS SISTEMAS
-- (tabelas vazias mantidas só por compatibilidade — use os getters!)
-- =====================================

_G.GameManagerConfig = {
	characterPrices = characterPrices,
	bountyCharacters = bountyCharacters,
	gamepassCharacters = gamepassCharacters,
	badgeIds = badgeIds,
	characterHealth = characterHealth,
	SELL_PERCENTAGE = SELL_PERCENTAGE,
	getEquippedCharacter = function(player)
		return equippedCharacters[player]
	end,
	isCharacterEquipped = function(player, characterName)
		return equippedCharacters[player] == characterName
	end,
	getCharacterPrice = getCharacterPrice,
	getCharacterHealth = getCharacterHealth,
	getBountyRequirement = getBountyRequirement,
	getGamepassId = getGamepassId,
	getBadgeId = getBadgeId,
	-- Usado pelo AwakeningSystemServer_V1 e pelo CharacterCatalogServer_V4
	reapplyEquippedTools = function(player)
		local characterName = equippedCharacters[player]
		if not characterName then
			return false
		end
		return equipCharacter(player, characterName)
	end,
}

-- =====================================
-- DEBUG
-- =====================================

_G.DebugGameManager = function(playerName)
	local player = Players:FindFirstChild(playerName)
	if not player then
		print("Jogador não encontrado")
		return
	end

	print("\n========== DEBUG GAME MANAGER V9 ==========")
	print(string.format("Jogador: %s", player.Name))
	print(string.format("Equipado: %s", equippedCharacters[player] or "Nenhum"))

	local playerData = _G.PlayerDataManager.getPlayerData(player)
	if playerData then
		print("\n--- PERSONAGENS ---")
		for i, charObj in ipairs(playerData.ownedCharacters) do
			local sellPrice = calculateSellPrice(charObj)
			print(
				string.format(
					"  %d. %s [%s] | Preço: %d | Venda: %s | Trade: %s",
					i,
					charObj.name,
					charObj.source,
					charObj.originalPrice or 0,
					charObj.sellable and (sellPrice .. " moedas") or "N/A",
					charObj.tradeable and "Sim" or "Não"
				)
			)
		end
	end

	print("=====================================\n")
end

print([[
╔══════════════════════════════════════════════════════╗
║  GAME MANAGER V9 — ZERO PERSONAGENS + FIX EQUIPAR   ║
╠══════════════════════════════════════════════════════╣
║  SUBSTITUI: GAME_MANAGER_V8                          ║
║  REMOVER:   GAME_MANAGER_V8                          ║
╠══════════════════════════════════════════════════════╣
║  🐞 FIX: retorno antecipado em playerOwnsCharacter   ║
║     tornava morta a lógica de desbloqueio — Grátis/  ║
║     Bounty/Badge não equipavam. Corrigido.           ║
║  🧹 Tabelas fixas ZERADAS (sem Noob/Faker Gui/etc)  ║
║     — catálogo é a fonte única de personagens        ║
║  * Bounty desbloqueado agora entra no inventário     ║
║  * checkGamepasses varre só o catálogo               ║
╠══════════════════════════════════════════════════════╣
║  DEBUG: _G.DebugGameManager("NomeJogador")           ║
╚══════════════════════════════════════════════════════╝
]])
