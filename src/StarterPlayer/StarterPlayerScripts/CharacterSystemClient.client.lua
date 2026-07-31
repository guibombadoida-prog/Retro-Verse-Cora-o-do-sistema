-- ============================================
-- CHARACTER SYSTEM CLIENT V8 — DESPERTAR VISÍVEL E DESBLOQUEÁVEL
-- Coloque em StarterPlayer > StarterPlayerScripts
-- Nome: "CharacterSystemClient"
-- SUBSTITUI: CharacterSystemClient V7
-- REMOVER:   CharacterSystemClient V7
-- ============================================
-- (V8) DOIS DEFEITOS DO DESPERTAR NO CARD
--
-- 🐛 O BOTÃO NÃO DAVA PARA VER.
--    Ficava em y=0.915 com altura 0.07 — os últimos 15px de um card de
--    220px, POR CIMA da borda de 3px do próprio card. A linha de botões
--    do card termina em 0.85, então havia espaço livre logo abaixo que
--    ninguém estava usando.
--    ✅ Agora tem faixa própria: y=0.865, altura 0.09, largura cheia.
--
-- 🐛 O BOTÃO NÃO "EQUIPAVA" — porque nunca foi equipar.
--    O remote EquipAwakening chama `addAwakenedCharacter` no servidor,
--    que só DESBLOQUEIA (grava em data.awakenedCharacters). Quem equipa
--    é o SelectCharacter normal: uma vez desbloqueado, equipar o
--    ORIGINAL já entrega a forma desperta (GameManager_V9,
--    `usingAwakened`). Não existe "equipar desperto" separado.
--    O V7 disparava o remote e anunciava "Despertar equipado!" sem
--    atualizar nada na tela — parecia que o clique não fazia efeito.
--    ✅ O botão agora se chama DESBLOQUEAR, e depois do clique o
--       inventário recarrega para o card da forma desperta aparecer.
--
-- ✅ CARD SEPARADO DA FORMA DESPERTA NO INVENTÁRIO (novo)
--    O Despertar não vive em ownedCharacters — o servidor guarda numa
--    lista à parte. Por isso ele nunca aparecia no inventário, que só
--    lê ownedCharacters. Agora cada desbloqueio ganha o card dele, com
--    o displayName do Despertar e raridade AWAKENED. O card equipa pelo
--    nome do original, porque é assim que o servidor funciona.
--    Não tem botão de vender: Despertar não é item, é desbloqueio
--    permanente em cima do original.
--
-- ✅ ESTADOS EXPLÍCITOS no lugar de "VER" / "INFO", que não diziam nada:
--       ⚡ DESPERTO ................. já desbloqueado
--       🔓 DESBLOQUEAR DESPERTAR .... tem o original + o emblema
--       🔒 FALTA O EMBLEMA .......... tem o original, falta o requisito
--       🔒 PRECISA DO ORIGINAL ...... não tem o personagem base
--    O pulso de destaque agora só acontece quando há ação a tomar.
-- ============================================
-- (V8) POPUP DE HABILIDADES MOSTRA AS FERRAMENTAS
--
-- Os ATRIBUTOS do popup só existem para admin (vêm do
-- CharacterStatsServer). Para o público, o popup só tinha HP e
-- descrição — não dizia o que o personagem faz.
--
-- ✅ Nova seção "🛠️ FERRAMENTAS CARREGADAS (n)", que aparece SEMPRE,
--    inclusive quando não há atributos:
--      ⚔️ Tools normais, em ordem
--      ⚡ Tools da forma desperta, em magenta e marcadas "(desperta)"
--
--    A leitura é DIRETA de ReplicatedStorage.Characters[nome] e
--    .AwakenedForm, que já são replicados ao cliente — nenhum remote
--    novo. E é de propósito: mostra o que está REALMENTE carregado, não
--    o que o catálogo diz que deveria estar. Se um Model ID falhou, a
--    Tool não aparece na lista, e essa é justamente a informação útil
--    para diagnosticar.
--
-- ✅ Título "📊 ATRIBUTOS" separando as duas listas, que antes viravam
--    um bloco só. E o popup ficou mais alto (0.78 desktop / 0.88 mobile)
--    para as quatro seções caberem sem apertar nenhuma.
-- ============================================
-- (V7) ALTERAÇÕES — EDIÇÃO CIRÚRGICA, DE PROPÓSITO:
-- Só UMA função mudou: `createAbilitiesPopup`. Todo o resto do
-- arquivo (Loja, Inventário, Despertar, Venda, Lore, abas, cards)
-- está IDÊNTICO ao V6, byte a byte. Isso foi intencional: o arquivo
-- tem ~1700 linhas e funciona, então reescrever tudo pra adicionar
-- uma lista de atributos seria trocar risco alto por ganho pequeno.
--
-- O QUE MUDOU:
-- • O popup de HABILIDADES mostrava só "❤️ HP: 300". Agora mostra
--   também o ARQUÉTIPO do personagem (Tanque, Assassino, Mago...) e
--   a lista de ATRIBUTOS que ele concede, com bônus em VERDE e
--   penalidade em VERMELHO.
-- • Os dados vêm do remote `GetCharacterStatsInfo`
--   (CharacterStatsServer V1).
--
-- ⚠️ DEGRADA COM ELEGÂNCIA: se o CharacterStatsServer V1 não estiver
--    instalado, ou se o personagem não tiver arquétipo configurado,
--    o popup volta a mostrar exatamente o que o V6 mostrava. Nada
--    quebra, nada some.
--
-- REUTILIZAÇÃO: o popup inteiro (fundo, header, botão X, clique fora
-- pra fechar) é o mesmo do V6 — só o miolo entre o header e a
-- descrição foi reorganizado.
-- ============================================
-- (V6) ALTERAÇÕES:
-- • ABA "GRÁTIS" REMOVIDA DA LOJA: com o CharacterCatalogServer_V4,
--   personagens Mandatory (Grátis) são concedidos automaticamente
--   e vão DIRETO pro Inventário de todos — a aba na loja ficava
--   sempre vazia. A loja agora tem 4 abas:
--   LOJA / RECOMPENSA / GAMEPASS / EMBLEMA.
--   Personagens Mandatory (e Trade) NUNCA aparecem na loja.
-- • MENSAGENS REAIS DO SERVIDOR: os remotes SelectCharacter e
--   PurchaseCharacter retornam (sucesso, mensagem) — agora a
--   mensagem do servidor ("Você precisa morrer para trocar...",
--   "Moedas insuficientes...", "Você precisa de X de bounty!") é
--   exibida na notificação, em vez de erro genérico.
-- • DEFEITO CORRIGIDO: notificações disparadas antes do menu
--   existir (ex.: aviso do catálogo logo no login) eram criadas
--   como Frame solto no PlayerGui e NÃO renderizavam — agora usam
--   um ScreenGui temporário.
-- • Categoria vazia mostra aviso na loja em vez de tela em branco.
-- ============================================
-- MANTIDO DO V5 (catálogo dinâmico):
-- • ZERO personagem fixo no código — tabelas "characterData" e
--   "characterInfo" NÃO existem. Tudo vem do remote público
--   GetCatalogCharacters (CharacterCatalogServer_V4).
-- • Botão de ação por categoria:
--   Shop = 💰 COMPRAR (moedas) | Gamepass = 🎫 GAMEPASS
--   (PromptGamePassPurchase) | Reward/Badge = 🔓 LIBERAR (o
--   servidor decide se o requisito foi cumprido e concede).
-- • Escuta o remote "CatalogAnnouncement" — mostra o aviso global
--   de add/remove de personagem e atualiza Loja/Inventário na hora.
-- • Popups de Habilidades/Lore leem description/lore/health direto
--   do catálogo.
-- • Mantém: venda 25%, Despertar (CheckAwakening/EquipAwakening),
--   metadados V4, UI responsiva Mobile/Tablet/PC, Menu Unificado.
-- ============================================
-- REUTILIZADO:
-- • GetCatalogCharacters / CatalogAnnouncement .. CharacterCatalogServer_V4
-- • SelectCharacter / PurchaseCharacter ........ GameManager_V9
-- • Venda (SellCharacter + metadados) .......... DataManager_V6
-- • CheckAwakening / EquipAwakening ............ AwakeningSystemServer_V1
-- • Estrutura de UI, cards, sons e popups ...... CharacterSystemClient_V4
-- • _G.RegisterMenuCategory .................... UnifiedMenuClient
-- ============================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local MarketplaceService = game:GetService("MarketplaceService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

print("[CHAR SYSTEM V7] Inicializando sistema 100% catálogo (sem aba Grátis)...")

-- =====================================
-- DETECÇÃO DE PLATAFORMA
-- =====================================

local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
local isTablet = isMobile and (workspace.CurrentCamera.ViewportSize.X > 600)

-- =====================================
-- AGUARDAR REMOTES
-- =====================================

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local selectCharacterRemote = remotes:WaitForChild("SelectCharacter")
local purchaseCharacterRemote = remotes:WaitForChild("PurchaseCharacter")
local getPlayerDataRemote = remotes:WaitForChild("GetPlayerData")
local checkAwakeningRemote = remotes:WaitForChild("CheckAwakening", 10)
local equipAwakeningRemote = remotes:WaitForChild("EquipAwakening", 10)
local syncCharacterStateRemote = remotes:WaitForChild("SyncCharacterState", 10)
local sellCharacterRemote = remotes:WaitForChild("SellCharacter", 10)

-- (V5) Remotes do catálogo dinâmico (CharacterCatalogServer_V4)
local getCatalogCharactersRemote = remotes:WaitForChild("GetCatalogCharacters", 15)
local catalogAnnouncementRemote = remotes:WaitForChild("CatalogAnnouncement", 15)

-- (V7) Atributos por personagem. Opcional: se o CharacterStatsServer
-- V1 não estiver instalado, isto fica nil e o popup usa o modo V6.
local getCharacterStatsInfo = remotes:WaitForChild("GetCharacterStatsInfo", 10)

if not getCatalogCharactersRemote then
	warn("[CHAR SYSTEM V7] GetCatalogCharacters não encontrado — o CharacterCatalogServer_V4 está no ServerScriptService?")
end

-- =====================================
-- SONS
-- =====================================

local sounds = {
	hover = "rbxassetid://12846056",
	click = "rbxassetid://156785206",
	purchase = "rbxassetid://5031873608",
	error = "rbxassetid://2865228021",
	open = "rbxassetid://157167203",
	close = "rbxassetid://157167205",
	info = "rbxassetid://156785206",
	awakening = "rbxassetid://5031873608",
	sell = "rbxassetid://5031873608",
}

local function playSound(soundId)
	pcall(function()
		local sound = Instance.new("Sound")
		sound.SoundId = soundId
		sound.Volume = 0.5
		sound.Parent = SoundService
		sound:Play()
		sound.Ended:Connect(function()
			sound.Parent = nil
		end)
	end)
end

-- =====================================
-- SISTEMA DE TAMANHOS
-- =====================================

local UI_SIZES = { SMALL = "Pequeno", MEDIUM = "Médio", LARGE = "Grande" }
local currentUISize = UI_SIZES.MEDIUM

local function getUIScale()
	local viewport = workspace.CurrentCamera.ViewportSize
	local baseScale

	if isTablet then
		baseScale = {
			menu = { small = 0.75, medium = 0.85, large = 0.95 },
			button = { small = 0.10, medium = 0.12, large = 0.14 },
			card = {
				width = { small = 140, medium = 160, large = 180 },
				height = { small = 240, medium = 260, large = 280 },
				columns = 3,
				spacing = { small = 8, medium = 10, large = 12 },
			},
		}
	elseif isMobile then
		baseScale = {
			menu = { small = 0.85, medium = 0.92, large = 0.98 },
			button = { small = 0.12, medium = 0.15, large = 0.18 },
			card = {
				width = {
					small = math.floor(viewport.X * 0.40),
					medium = math.floor(viewport.X * 0.45),
					large = math.floor(viewport.X * 0.48),
				},
				height = { small = 220, medium = 240, large = 260 },
				columns = 2,
				spacing = { small = 8, medium = 10, large = 15 },
			},
		}
	else
		baseScale = {
			menu = { small = 0.65, medium = 0.75, large = 0.85 },
			button = { small = 0.08, medium = 0.10, large = 0.12 },
			card = {
				width = { small = 110, medium = 130, large = 150 },
				height = { small = 220, medium = 240, large = 260 },
				columns = 4,
				spacing = { small = 6, medium = 8, large = 10 },
			},
		}
	end

	local size = currentUISize == UI_SIZES.SMALL and "small"
		or (currentUISize == UI_SIZES.LARGE and "large" or "medium")

	return {
		menu = UDim2.new(baseScale.menu[size], 0, baseScale.menu[size], 0),
		button = UDim2.new(baseScale.button[size], 0, baseScale.button[size] * 0.65, 0),
		card = {
			width = baseScale.card.width[size],
			height = baseScale.card.height[size],
			columns = baseScale.card.columns,
			spacing = baseScale.card.spacing[size],
		},
	}
end

local uiScale = getUIScale()

-- =====================================
-- RARIDADES
-- =====================================

local rarities = {
	ROBLOXIANOS = { color = Color3.fromRGB(100, 100, 100), order = 1 },
	HEROXIANOS = { color = Color3.fromRGB(0, 170, 255), order = 2 },
	NULLXIANOS = { color = Color3.fromRGB(170, 0, 170), order = 3 },
	BTUDIOS = { color = Color3.fromRGB(255, 170, 0), order = 4 },
	BOSSXIANOS = { color = Color3.fromRGB(255, 0, 0), order = 5 },
	SUPREMO = { color = Color3.fromRGB(255, 215, 0), order = 6, glow = true },
	AWAKENED = { color = Color3.fromRGB(255, 0, 255), order = 7, glow = true, special = true },
}

-- =====================================
-- CATÁLOGO DINÂMICO (V5)
-- ZERO personagem fixo — tudo vem do GetCatalogCharacters
-- =====================================

local catalogCharacters = {} -- lista pública vinda do servidor
local catalogByName = {} -- índice por nome

-- (V6) Abas da loja — SEM "GRÁTIS": Mandatory vai direto pro
-- Inventário (CharacterCatalogServer_V4) e Trade só entra por troca.
local SHOP_TABS = {
	{ key = "Shop", label = "LOJA" },
	{ key = "Reward", label = "RECOMPENSA" },
	{ key = "Gamepass", label = "GAMEPASS" },
	{ key = "Badge", label = "EMBLEMA" },
}

local function refreshCatalogCharacters()
	if not getCatalogCharactersRemote then
		return
	end
	local ok, list = pcall(function()
		return getCatalogCharactersRemote:InvokeServer()
	end)
	if ok and type(list) == "table" then
		catalogCharacters = list
		catalogByName = {}
		for _, def in ipairs(list) do
			if type(def) == "table" and type(def.name) == "string" then
				catalogByName[def.name] = def
			end
		end
	end
end

local function getCatalogDef(characterName)
	return catalogByName[characterName]
end

-- Personagens de uma categoria da loja, ordenados por raridade
local function getCharactersForCategory(categoryKey)
	local result = {}
	for _, def in ipairs(catalogCharacters) do
		if type(def) == "table" and def.category == categoryKey then
			table.insert(result, def)
		end
	end
	table.sort(result, function(a, b)
		local ra = rarities[a.rarity] and rarities[a.rarity].order or 0
		local rb = rarities[b.rarity] and rarities[b.rarity].order or 0
		if ra == rb then
			return (a.name or "") < (b.name or "")
		end
		return ra < rb
	end)
	return result
end

-- =====================================
-- SISTEMA DE IMAGENS
-- =====================================

local CharacterImages = ReplicatedStorage:WaitForChild("CharacterImages", 10)
if not CharacterImages then
	CharacterImages = Instance.new("Folder")
	CharacterImages.Name = "CharacterImages"
	CharacterImages.Parent = ReplicatedStorage
end

local function getCharacterImageId(characterName)
	if CharacterImages then
		local obj = CharacterImages:FindFirstChild(characterName)
		if obj and obj:IsA("ImageLabel") then
			return obj.Image
		end
		if obj and obj:IsA("StringValue") then
			return obj.Value
		end
	end

	-- (V5) Fallback: imageId público do catálogo
	local def = getCatalogDef(characterName)
	if def and tonumber(def.imageId) and tonumber(def.imageId) > 0 then
		return "rbxassetid://" .. tostring(def.imageId)
	end

	return nil
end

local function createCharacterImage(characterName, parentFrame)
	local container = Instance.new("Frame")
	container.Size = UDim2.new(1, 0, 1, 0)
	container.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
	container.BorderSizePixel = 0
	container.ClipsDescendants = true
	container.Parent = parentFrame

	local imageId = getCharacterImageId(characterName)

	if imageId and imageId ~= "" then
		local img = Instance.new("ImageLabel")
		img.Size = UDim2.new(1, 0, 1, 0)
		img.BackgroundTransparency = 1
		img.Image = imageId
		img.ScaleType = Enum.ScaleType.Fit
		img.Parent = container
	else
		local placeholder = Instance.new("TextLabel")
		placeholder.Size = UDim2.new(1, 0, 0.75, 0)
		placeholder.BackgroundTransparency = 1
		placeholder.Text = "?"
		placeholder.TextColor3 = Color3.fromRGB(100, 100, 100)
		placeholder.TextScaled = true
		placeholder.Font = Enum.Font.Arcade
		placeholder.Parent = container
	end

	return container
end

-- =====================================
-- VARIÁVEIS
-- =====================================

-- (V5) Inventário inicial VAZIO — nada de "Noob" hardcoded
local playerData = {
	coins = 0,
	ownedCharacters = {},
	ownedCharactersDetailed = {}, -- lista com metadados (V4)
	awakenedCharacters = {},
	equippedCharacter = nil,
	stats = { bounty = 0, deaths = 0 },
}

local systemGui = nil
local mainFrame = nil
local contentFrame = nil
local invFrame = nil
local invScroll = nil

local isMenuOpen = false
local isInvOpen = false
local selectedCategory = "Shop" -- chave da categoria (SHOP_TABS)

-- Forward declarations
local createSystem
local updatePlayerData
local createCharacterCard

-- =====================================
-- NOTIFICAÇÃO
-- (V6) CORREÇÃO: antes do menu existir, um Frame solto no PlayerGui
-- não renderiza — usa ScreenGui temporário nesse caso.
-- =====================================

local function notify(message, isSuccess)
	playSound(isSuccess and sounds.purchase or sounds.error)

	local host = systemGui
	local tempGui = nil
	if not host or not host.Parent then
		tempGui = Instance.new("ScreenGui")
		tempGui.Name = "CharSystemNotify"
		tempGui.ResetOnSpawn = false
		tempGui.DisplayOrder = 120
		tempGui.Parent = playerGui
		host = tempGui
	end

	local notification = Instance.new("Frame")
	notification.Size = isMobile and UDim2.new(0.8, 0, 0.12, 0) or UDim2.new(0.4, 0, 0.08, 0)
	notification.Position = isMobile and UDim2.new(0.1, 0, 0.05, 0) or UDim2.new(0.3, 0, 0.05, 0)
	notification.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
	notification.BorderColor3 = isSuccess and Color3.new(0, 1, 0) or Color3.new(1, 0, 0)
	notification.BorderSizePixel = 3
	notification.ZIndex = 50
	notification.Parent = host

	local text = Instance.new("TextLabel")
	text.Size = UDim2.new(1, 0, 1, 0)
	text.BackgroundTransparency = 1
	text.Text = message
	text.TextColor3 = Color3.new(1, 1, 1)
	text.TextScaled = true
	text.Font = Enum.Font.Arcade
	text.ZIndex = 50
	text.Parent = notification

	task.delay(3, function()
		if notification.Parent then
			notification.Parent = nil
		end
		if tempGui and tempGui.Parent then
			tempGui.Parent = nil
		end
	end)
end

-- =====================================
-- REFRESH DAS TELAS ABERTAS
-- (padrão reutilizado do V4, centralizado numa função só)
-- =====================================

local function refreshOpenFrames()
	if not systemGui then
		return
	end
	local f = systemGui:FindFirstChild("RefreshCategory", true)
	if f and f:IsA("BindableFunction") then
		pcall(function()
			f:Invoke()
		end)
	end
	local g = systemGui:FindFirstChild("RefreshInventory", true)
	if g and g:IsA("BindableFunction") then
		pcall(function()
			g:Invoke()
		end)
	end
end

-- =====================================
-- ATUALIZAR DADOS DO JOGADOR
-- =====================================

updatePlayerData = function()
	pcall(function()
		local data = getPlayerDataRemote:InvokeServer()
		if data then
			playerData.coins = data.coins or 0
			playerData.ownedCharacters = data.ownedCharacters or {}
			playerData.ownedCharactersDetailed = data.ownedCharactersDetailed or {}
			playerData.awakenedCharacters = data.awakenedCharacters or {}
			playerData.stats = data.stats or { bounty = 0, deaths = 0 }
			playerData.equippedCharacter = data.equippedCharacter
		end
	end)
end

-- (V5) Sem "Noob" hardcoded — posse vem só dos dados reais
local function playerOwnsCharacter(characterName)
	return table.find(playerData.ownedCharacters, characterName) ~= nil
end

-- =====================================
-- FUNÇÕES DE METADADOS V4
-- =====================================

-- Buscar metadados detalhados de um personagem
local function getCharacterDetails(characterName)
	for _, charObj in ipairs(playerData.ownedCharactersDetailed) do
		if type(charObj) == "table" and charObj.name == characterName then
			return charObj
		end
	end
	return nil
end

-- Verificar se pode vender
local function canSellCharacter(characterName)
	local details = getCharacterDetails(characterName)
	if not details then
		return false, nil, "Dados não encontrados"
	end
	if not details.sellable then
		return false, nil, "Não vendável"
	end
	if not details.originalPrice or details.originalPrice <= 0 then
		return false, nil, "Sem valor"
	end
	if playerData.equippedCharacter == characterName then
		return false, nil, "Equipado"
	end
	local sellPrice = math.floor(details.originalPrice * 0.25)
	return true, sellPrice, details.id
end

-- =====================================
-- SINCRONIZAÇÃO DO SERVIDOR
-- =====================================

if syncCharacterStateRemote then
	syncCharacterStateRemote.OnClientEvent:Connect(function(characterName, isEquipped)
		if isEquipped then
			playerData.equippedCharacter = characterName
		else
			playerData.equippedCharacter = nil
		end
		if (mainFrame and mainFrame.Visible) or (invFrame and invFrame.Visible) then
			refreshOpenFrames()
		end
	end)
end

player.CharacterAdded:Connect(function(character)
	local humanoid = character:WaitForChild("Humanoid")
	humanoid.Died:Connect(function()
		playerData.equippedCharacter = nil
		task.wait(1)
		updatePlayerData()
		refreshOpenFrames()
	end)
end)

-- =====================================
-- EQUIPAR / LIBERAR (V6)
-- O servidor (GameManager_V9) decide: se for Recompensa/Emblema e o
-- requisito foi cumprido, ele concede e equipa; senão devolve a
-- mensagem real do porquê ("Você precisa de X de bounty!" etc.)
-- =====================================

local function tryEquipCharacter(characterName)
	local ok, success, message = pcall(function()
		return selectCharacterRemote:InvokeServer(characterName)
	end)

	if ok and success then
		notify("✅ " .. characterName .. " equipado!", true)
		task.wait(0.5)
		updatePlayerData()
		refreshOpenFrames()
		return true
	end

	local errMsg = (type(message) == "string" and message) or "Erro ao equipar!"
	notify("❌ " .. errMsg, false)
	return false
end

-- =====================================
-- ANÚNCIO GLOBAL DO CATÁLOGO (V5)
-- "Fulano adicionou/removeu o personagem X" em todos os servidores
-- =====================================

if catalogAnnouncementRemote then
	catalogAnnouncementRemote.OnClientEvent:Connect(function(message, isPositive)
		if type(message) == "string" and message ~= "" then
			notify(message, isPositive and true or false)
		end
		task.spawn(function()
			refreshCatalogCharacters()
			updatePlayerData() -- remoção pode devolver moedas / limpar inventário
			refreshOpenFrames()
		end)
	end)
end

-- =====================================
-- GAMEPASS COMPRADO EM TEMPO REAL (V5)
-- Após o prompt, tenta liberar o personagem correspondente — o
-- servidor valida a posse do gamepass e concede.
-- =====================================

MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(plr, gamePassId, wasPurchased)
	if plr ~= player or not wasPurchased then
		return
	end

	task.wait(1) -- dá tempo do Roblox registrar a compra

	for _, def in ipairs(catalogCharacters) do
		if def.category == "Gamepass" and tonumber(def.gamepassId) == tonumber(gamePassId) then
			task.spawn(tryEquipCharacter, def.name)
			return
		end
	end

	updatePlayerData()
	refreshOpenFrames()
end)

-- =====================================
-- POPUP - CONFIRMAÇÃO DE VENDA
-- =====================================

local function createSellConfirmPopup(characterName, sellPrice, charId)
	playSound(sounds.info)

	local sellGui = Instance.new("ScreenGui")
	sellGui.Name = "SellConfirmPopup"
	sellGui.DisplayOrder = 150
	sellGui.Parent = playerGui

	local background = Instance.new("Frame")
	background.Size = UDim2.new(1, 0, 1, 0)
	background.BackgroundColor3 = Color3.new(0, 0, 0)
	background.BackgroundTransparency = 0.5
	background.Parent = sellGui

	local popup = Instance.new("Frame")
	popup.Size = isMobile and UDim2.new(0.85, 0, 0.4, 0) or UDim2.new(0.4, 0, 0.35, 0)
	popup.Position = UDim2.new(0.5, 0, 0.5, 0)
	popup.AnchorPoint = Vector2.new(0.5, 0.5)
	popup.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
	popup.BorderColor3 = Color3.fromRGB(255, 200, 0)
	popup.BorderSizePixel = 4
	popup.Parent = sellGui

	-- Header
	local header = Instance.new("Frame")
	header.Size = UDim2.new(1, 0, 0.2, 0)
	header.BackgroundColor3 = Color3.fromRGB(200, 100, 0)
	header.BorderSizePixel = 0
	header.Parent = popup

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Size = UDim2.new(1, 0, 1, 0)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Text = "💰 VENDER PERSONAGEM"
	titleLabel.TextColor3 = Color3.new(1, 1, 1)
	titleLabel.TextScaled = true
	titleLabel.Font = Enum.Font.Arcade
	titleLabel.Parent = header

	-- Conteúdo
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size = UDim2.new(0.9, 0, 0.15, 0)
	nameLabel.Position = UDim2.new(0.05, 0, 0.25, 0)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = "Vender " .. characterName .. "?"
	nameLabel.TextColor3 = Color3.new(1, 1, 1)
	nameLabel.TextScaled = true
	nameLabel.Font = Enum.Font.Arcade
	nameLabel.Parent = popup

	local priceLabel = Instance.new("TextLabel")
	priceLabel.Size = UDim2.new(0.9, 0, 0.15, 0)
	priceLabel.Position = UDim2.new(0.05, 0, 0.42, 0)
	priceLabel.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
	priceLabel.BorderSizePixel = 0
	priceLabel.Text = "Você receberá: 💰 " .. sellPrice .. " moedas (25%)"
	priceLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
	priceLabel.TextScaled = true
	priceLabel.Font = Enum.Font.Arcade
	priceLabel.Parent = popup

	local warningLabel = Instance.new("TextLabel")
	warningLabel.Size = UDim2.new(0.9, 0, 0.1, 0)
	warningLabel.Position = UDim2.new(0.05, 0, 0.58, 0)
	warningLabel.BackgroundTransparency = 1
	warningLabel.Text = "Esta ação é irreversível!"
	warningLabel.TextColor3 = Color3.fromRGB(255, 80, 80)
	warningLabel.TextScaled = true
	warningLabel.Font = Enum.Font.Code
	warningLabel.Parent = popup

	-- Botão Confirmar
	local confirmButton = Instance.new("TextButton")
	confirmButton.Size = UDim2.new(0.4, 0, 0.15, 0)
	confirmButton.Position = UDim2.new(0.05, 0, 0.72, 0)
	confirmButton.BackgroundColor3 = Color3.fromRGB(0, 150, 0)
	confirmButton.BorderSizePixel = 0
	confirmButton.Text = "✅ CONFIRMAR"
	confirmButton.TextColor3 = Color3.new(1, 1, 1)
	confirmButton.TextScaled = true
	confirmButton.Font = Enum.Font.Arcade
	confirmButton.Parent = popup

	-- Botão Cancelar
	local cancelButton = Instance.new("TextButton")
	cancelButton.Size = UDim2.new(0.4, 0, 0.15, 0)
	cancelButton.Position = UDim2.new(0.55, 0, 0.72, 0)
	cancelButton.BackgroundColor3 = Color3.fromRGB(150, 0, 0)
	cancelButton.BorderSizePixel = 0
	cancelButton.Text = "❌ CANCELAR"
	cancelButton.TextColor3 = Color3.new(1, 1, 1)
	cancelButton.TextScaled = true
	cancelButton.Font = Enum.Font.Arcade
	cancelButton.Parent = popup

	local processing = false

	confirmButton.MouseButton1Click:Connect(function()
		if processing then
			return
		end
		processing = true
		confirmButton.Text = "..."

		if sellCharacterRemote then
			local ok, success, message = pcall(function()
				return sellCharacterRemote:InvokeServer(charId)
			end)

			if ok and success then
				playSound(sounds.sell)
				notify("✅ " .. (message or "Vendido com sucesso!"), true)
				task.wait(0.3)
				updatePlayerData()
				refreshOpenFrames()
			else
				local errMsg = (type(message) == "string" and message) or "Erro na venda"
				notify("❌ " .. errMsg, false)
			end
		else
			notify("❌ Sistema de venda indisponível!", false)
		end

		sellGui.Parent = nil
	end)

	cancelButton.MouseButton1Click:Connect(function()
		playSound(sounds.close)
		sellGui.Parent = nil
	end)

	background.InputBegan:Connect(function(input)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			playSound(sounds.close)
			sellGui.Parent = nil
		end
	end)
end

-- =====================================
-- POPUPS - HABILIDADES / LORE
-- (V5) Lêem direto do catálogo (description/lore/health), sem
-- tabela fixa local
-- =====================================

-- (V8) DETECÇÃO DE TOOLS DO PERSONAGEM
-- =====================================
-- As Tools montadas pelo CharacterCatalogServer ficam em
-- ReplicatedStorage.Characters[nome], e a forma desperta em
-- .AwakenedForm. Isso é replicado ao cliente, então dá para listar sem
-- remote nenhum — é leitura direta do que REALMENTE está carregado, não
-- do que o catálogo diz que deveria estar. Se um ID falhou ao carregar,
-- a Tool não aparece aqui, e é exatamente essa a informação útil.
local function collectCharacterTools(characterName)
	local normais, despertas = {}, {}

	local pasta = ReplicatedStorage:FindFirstChild("Characters")
	pasta = pasta and pasta:FindFirstChild(characterName)
	if not pasta then
		return normais, despertas
	end

	for _, item in ipairs(pasta:GetChildren()) do
		if item:IsA("Tool") then
			table.insert(normais, item.Name)
		end
	end

	local formaDesperta = pasta:FindFirstChild("AwakenedForm")
	if formaDesperta then
		for _, item in ipairs(formaDesperta:GetChildren()) do
			if item:IsA("Tool") then
				table.insert(despertas, item.Name)
			end
		end
	end

	return normais, despertas
end

local function createAbilitiesPopup(characterName)
	playSound(sounds.info)
	local def = getCatalogDef(characterName)
	local healthText = "❤️ HP: " .. tostring(def and def.health or 100)
	local descText = (def and def.description ~= nil and def.description ~= "" and def.description)
		or "Sem descrição cadastrada."

	local infoGui = Instance.new("ScreenGui")
	infoGui.Name = "AbilitiesPopup"
	infoGui.DisplayOrder = 100
	infoGui.Parent = playerGui

	local background = Instance.new("Frame")
	background.Size = UDim2.new(1, 0, 1, 0)
	background.BackgroundColor3 = Color3.new(0, 0, 0)
	background.BackgroundTransparency = 0.5
	background.Parent = infoGui

	local popup = Instance.new("Frame")
	-- (V8) Mais alto que o V7: agora cabe HP + FERRAMENTAS + atributos +
	-- descrição sem apertar nenhuma seção.
	popup.Size = isMobile and UDim2.new(0.92, 0, 0.88, 0) or UDim2.new(0.55, 0, 0.78, 0)
	popup.Position = UDim2.new(0.5, 0, 0.5, 0)
	popup.AnchorPoint = Vector2.new(0.5, 0.5)
	popup.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
	popup.BorderColor3 = Color3.fromRGB(0, 200, 0)
	popup.BorderSizePixel = 4
	popup.Parent = infoGui

	local header = Instance.new("Frame")
	header.Size = UDim2.new(1, 0, 0.12, 0)
	header.BackgroundColor3 = Color3.fromRGB(0, 150, 0)
	header.BorderSizePixel = 0
	header.Parent = popup

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Size = UDim2.new(0.85, 0, 1, 0)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Text = "⚔️ " .. characterName:upper() .. " — HABILIDADES"
	titleLabel.TextColor3 = Color3.new(1, 1, 1)
	titleLabel.TextScaled = true
	titleLabel.Font = Enum.Font.Arcade
	titleLabel.Parent = header

	local closeButton = Instance.new("TextButton")
	closeButton.Size = UDim2.new(0.1, 0, 0.8, 0)
	closeButton.Position = UDim2.new(0.88, 0, 0.1, 0)
	closeButton.BackgroundColor3 = Color3.fromRGB(150, 0, 0)
	closeButton.BorderSizePixel = 0
	closeButton.Text = "X"
	closeButton.TextColor3 = Color3.new(1, 1, 1)
	closeButton.TextScaled = true
	closeButton.Font = Enum.Font.Arcade
	closeButton.Parent = header

	-- (V7) ARQUÉTIPO + ATRIBUTOS
	-- Busca no CharacterStatsServer V1. Se não existir, statsInfo
	-- fica nil e o popup se comporta igual ao V6.
	local statsInfo = nil
	if getCharacterStatsInfo then
		local ok, result = pcall(function()
			return getCharacterStatsInfo:InvokeServer(characterName)
		end)
		if ok and type(result) == "table" then
			statsInfo = result
		end
	end

	-- Nome do arquétipo, pra mostrar ao lado do HP
	local archetypeText = ""
	if statsInfo and statsInfo.archetypes then
		for _, archetype in ipairs(statsInfo.archetypes) do
			if archetype.id == statsInfo.archetype then
				if archetype.id ~= "equilibrado" then
					archetypeText = "   " .. archetype.icon .. " " .. archetype.name
				end
				break
			end
		end
	end

	local statsLabel = Instance.new("TextLabel")
	statsLabel.Size = UDim2.new(0.96, 0, 0.10, 0)
	statsLabel.Position = UDim2.new(0.02, 0, 0.14, 0)
	statsLabel.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
	statsLabel.BorderSizePixel = 0
	statsLabel.Text = healthText .. archetypeText
	statsLabel.TextColor3 = Color3.fromRGB(255, 255, 0)
	statsLabel.TextScaled = true
	statsLabel.Font = Enum.Font.Arcade
	statsLabel.Parent = popup

	-- Monta a lista de atributos (só os que não são zero)
	local statLines = {}
	if statsInfo and type(statsInfo.finalStats) == "table" then
		-- Nomes legíveis. O que não estiver aqui aparece com a chave
		-- crua — melhor mostrar do que esconder um atributo novo.
		local LABELS = {
			HPFlat = "Vida",
			HPPercent = "Vida",
			DamageBoost = "Dano",
			DamageResistance = "Resistência",
			DefenseFlat = "Defesa",
			WalkSpeedFlat = "Velocidade",
			WalkSpeedPercent = "Velocidade",
			JumpFlat = "Pulo",
			JumpPercent = "Pulo",
			IncomingHealing = "Cura recebida",
			OutgoingHealing = "Cura dada",
			FlightSpeed = "Voo",
			InterruptResist = "Resist. interrupção",
			Shield = "Escudo",
			MeleeBoost = "Dano corpo a corpo",
			RangedBoost = "Dano à distância",
			MagicBoost = "Dano mágico",
			SummonBoost = "Dano de invocação",
			DebuffBoost = "Dano de debuff",
			MeleeResist = "Resist. corpo a corpo",
			RangedResist = "Resist. à distância",
			MagicResist = "Resist. mágica",
			SummonResist = "Resist. invocação",
			DebuffResist = "Resist. debuff",
			MeleePierce = "Perfura corpo a corpo",
			RangedPierce = "Perfura à distância",
			MagicPierce = "Perfura mágica",
			SummonPierce = "Perfura invocação",
			DebuffPierce = "Perfura debuff",
		}

		-- Atributo terminado em "Percent", ou que não é Flat/Shield,
		-- é porcentagem
		local FLAT_STATS = {
			HPFlat = true,
			DefenseFlat = true,
			WalkSpeedFlat = true,
			JumpFlat = true,
			Shield = true,
		}

		for name, value in pairs(statsInfo.finalStats) do
			if type(value) == "number" and value ~= 0 then
				local label = LABELS[name] or name
				local shown
				if FLAT_STATS[name] then
					shown = string.format("%+d", math.floor(value))
				else
					shown = string.format("%+.0f%%", value * 100)
				end
				table.insert(statLines, {
					text = label .. ": " .. shown,
					positive = value > 0,
				})
			end
		end

		table.sort(statLines, function(a, b)
			return a.text < b.text
		end)
	end

	-- =====================================
	-- (V8) FERRAMENTAS CARREGADAS NO PERSONAGEM
	-- =====================================
	-- Os ATRIBUTOS só existem para quem é admin (vêm do
	-- CharacterStatsServer). As Tools, não: elas são o que o público
	-- precisa ver para saber o que o personagem faz. Por isso esta seção
	-- aparece SEMPRE, inclusive quando statsInfo é nil.
	local toolsNormais, toolsDespertas = collectCharacterTools(characterName)
	local totalTools = #toolsNormais + #toolsDespertas

	local toolsTitle = Instance.new("TextLabel")
	toolsTitle.Size = UDim2.new(0.96, 0, 0.055, 0)
	toolsTitle.Position = UDim2.new(0.02, 0, 0.30, 0)
	toolsTitle.BackgroundTransparency = 1
	toolsTitle.Text = string.format("🛠️ FERRAMENTAS CARREGADAS (%d)", totalTools)
	toolsTitle.TextColor3 = Color3.fromRGB(0, 220, 255)
	toolsTitle.TextScaled = true
	toolsTitle.Font = Enum.Font.Arcade
	toolsTitle.TextXAlignment = Enum.TextXAlignment.Left
	toolsTitle.Parent = popup

	local toolsFrame = Instance.new("ScrollingFrame")
	toolsFrame.Size = UDim2.new(0.96, 0, 0.20, 0)
	toolsFrame.Position = UDim2.new(0.02, 0, 0.36, 0)
	toolsFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
	toolsFrame.BorderSizePixel = 0
	toolsFrame.ScrollBarThickness = 5
	toolsFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
	toolsFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
	toolsFrame.Parent = popup

	local toolsLayout = Instance.new("UIListLayout")
	toolsLayout.Padding = UDim.new(0.02, 0)
	toolsLayout.Parent = toolsFrame

	local function linhaTool(texto, cor, ordem)
		local entry = Instance.new("TextLabel")
		entry.Size = UDim2.new(0.96, 0, 0.3, 0)
		entry.BackgroundTransparency = 1
		entry.Text = texto
		entry.TextColor3 = cor
		entry.TextScaled = true
		entry.Font = Enum.Font.Code
		entry.TextXAlignment = Enum.TextXAlignment.Left
		entry.LayoutOrder = ordem
		entry.Parent = toolsFrame
	end

	local ordemTool = 0
	for _, nome in ipairs(toolsNormais) do
		ordemTool = ordemTool + 1
		linhaTool(ordemTool .. ". ⚔️ " .. nome, Color3.fromRGB(220, 220, 220), ordemTool)
	end
	for _, nome in ipairs(toolsDespertas) do
		ordemTool = ordemTool + 1
		-- Magenta é a cor de AWAKENED no resto da tela; mantém a leitura
		linhaTool(ordemTool .. ". ⚡ " .. nome .. "  (desperta)", Color3.fromRGB(255, 100, 255), ordemTool)
	end

	if totalTools == 0 then
		linhaTool("Nenhuma ferramenta carregada neste personagem.", Color3.fromRGB(150, 150, 150), 1)
	end

	-- Com atributos, a descrição divide espaço com eles.
	-- Sem atributos, a descrição ocupa o que sobra abaixo das Tools.
	local hasStats = #statLines > 0
	local descHeight = hasStats and 0.16 or 0.38
	local descY = hasStats and 0.81 or 0.58

	if hasStats then
		-- (V8) Título para separar visualmente o que é público (as Tools)
		-- do que é de arquétipo/admin (os atributos). Sem ele as duas
		-- listas viravam um bloco só e ninguém sabia o que estava lendo.
		local attrTitle = Instance.new("TextLabel")
		attrTitle.Size = UDim2.new(0.96, 0, 0.05, 0)
		attrTitle.Position = UDim2.new(0.02, 0, 0.575, 0)
		attrTitle.BackgroundTransparency = 1
		attrTitle.Text = "📊 ATRIBUTOS"
		attrTitle.TextColor3 = Color3.fromRGB(255, 255, 0)
		attrTitle.TextScaled = true
		attrTitle.Font = Enum.Font.Arcade
		attrTitle.TextXAlignment = Enum.TextXAlignment.Left
		attrTitle.Parent = popup

		local statsFrame = Instance.new("ScrollingFrame")
		statsFrame.Size = UDim2.new(0.96, 0, 0.17, 0)
		statsFrame.Position = UDim2.new(0.02, 0, 0.625, 0)
		statsFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
		statsFrame.BorderSizePixel = 0
		statsFrame.ScrollBarThickness = 5
		statsFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
		statsFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
		statsFrame.Parent = popup

		local statsLayout = Instance.new("UIListLayout")
		statsLayout.Padding = UDim.new(0.02, 0)
		statsLayout.Parent = statsFrame

		for index, line in ipairs(statLines) do
			local entry = Instance.new("TextLabel")
			entry.Size = UDim2.new(0.96, 0, 0.24, 0)
			entry.BackgroundTransparency = 1
			-- Bônus em verde, penalidade em vermelho: dá pra ler o
			-- personagem inteiro de relance
			entry.Text = (line.positive and "＋ " or "－ ") .. line.text
			entry.TextColor3 = line.positive and Color3.fromRGB(0, 220, 0)
				or Color3.fromRGB(220, 60, 60)
			entry.TextScaled = true
			entry.Font = Enum.Font.Code
			entry.TextXAlignment = Enum.TextXAlignment.Left
			entry.LayoutOrder = index
			entry.Parent = statsFrame
		end
	end

	local descFrame = Instance.new("Frame")
	descFrame.Size = UDim2.new(0.96, 0, descHeight, 0)
	descFrame.Position = UDim2.new(0.02, 0, descY, 0)
	descFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
	descFrame.BorderSizePixel = 0
	descFrame.Parent = popup

	local descLabel = Instance.new("TextLabel")
	descLabel.Size = UDim2.new(0.94, 0, 0.9, 0)
	descLabel.Position = UDim2.new(0.03, 0, 0.05, 0)
	descLabel.BackgroundTransparency = 1
	descLabel.Text = descText
	descLabel.TextColor3 = Color3.new(1, 1, 1)
	descLabel.TextScaled = true
	descLabel.TextWrapped = true
	descLabel.Font = Enum.Font.Code
	descLabel.TextYAlignment = Enum.TextYAlignment.Top
	descLabel.Parent = descFrame

	closeButton.MouseButton1Click:Connect(function()
		playSound(sounds.close)
		infoGui.Parent = nil
	end)
	background.InputBegan:Connect(function(input)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			infoGui.Parent = nil
		end
	end)
end

local function createLorePopup(characterName)
	playSound(sounds.info)
	local def = getCatalogDef(characterName)
	local loreString = (def and def.lore ~= nil and def.lore ~= "" and def.lore)
		or "Sem lore cadastrada."

	local infoGui = Instance.new("ScreenGui")
	infoGui.Name = "LorePopup"
	infoGui.DisplayOrder = 100
	infoGui.Parent = playerGui

	local background = Instance.new("Frame")
	background.Size = UDim2.new(1, 0, 1, 0)
	background.BackgroundColor3 = Color3.new(0, 0, 0)
	background.BackgroundTransparency = 0.5
	background.Parent = infoGui

	local popup = Instance.new("Frame")
	popup.Size = isMobile and UDim2.new(0.9, 0, 0.5, 0) or UDim2.new(0.5, 0, 0.4, 0)
	popup.Position = UDim2.new(0.5, 0, 0.5, 0)
	popup.AnchorPoint = Vector2.new(0.5, 0.5)
	popup.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
	popup.BorderColor3 = Color3.fromRGB(200, 150, 0)
	popup.BorderSizePixel = 4
	popup.Parent = infoGui

	local header = Instance.new("Frame")
	header.Size = UDim2.new(1, 0, 0.2, 0)
	header.BackgroundColor3 = Color3.fromRGB(150, 100, 0)
	header.BorderSizePixel = 0
	header.Parent = popup

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Size = UDim2.new(0.85, 0, 1, 0)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Text = "📖 " .. characterName:upper()
	titleLabel.TextColor3 = Color3.new(1, 1, 1)
	titleLabel.TextScaled = true
	titleLabel.Font = Enum.Font.Arcade
	titleLabel.Parent = header

	local closeButton = Instance.new("TextButton")
	closeButton.Size = UDim2.new(0.12, 0, 0.75, 0)
	closeButton.Position = UDim2.new(0.86, 0, 0.125, 0)
	closeButton.BackgroundColor3 = Color3.fromRGB(150, 0, 0)
	closeButton.BorderSizePixel = 0
	closeButton.Text = "X"
	closeButton.TextColor3 = Color3.new(1, 1, 1)
	closeButton.TextScaled = true
	closeButton.Font = Enum.Font.Arcade
	closeButton.Parent = header

	local loreText = Instance.new("TextLabel")
	loreText.Size = UDim2.new(0.9, 0, 0.7, 0)
	loreText.Position = UDim2.new(0.05, 0, 0.25, 0)
	loreText.BackgroundTransparency = 1
	loreText.Text = loreString
	loreText.TextColor3 = Color3.new(1, 1, 1)
	loreText.TextScaled = true
	loreText.Font = Enum.Font.Code
	loreText.TextWrapped = true
	loreText.Parent = popup

	closeButton.MouseButton1Click:Connect(function()
		playSound(sounds.close)
		infoGui.Parent = nil
	end)
	background.InputBegan:Connect(function(input)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			infoGui.Parent = nil
		end
	end)
end

-- =====================================
-- BOTÃO DE DESPERTAR
-- (reutilizado — AwakeningSystemServer_V1)
-- =====================================

-- (V8) O BOTÃO É DE DESBLOQUEIO, NÃO DE EQUIPAR.
--
-- Dois defeitos do V7 corrigidos aqui:
--
-- 🐛 NÃO DAVA PARA VER. Ficava em y=0.915 com altura 0.07, ou seja nos
--    últimos 15px de um card de 220px, POR CIMA da borda de 3px do card.
--    Agora tem faixa própria (y=0.865, altura 0.09, largura cheia), que
--    sobra abaixo da linha de botões do card (que termina em 0.85).
--
-- 🐛 NÃO DAVA PARA "EQUIPAR" porque nunca foi equipar. O remote
--    EquipAwakening chama `addAwakenedCharacter` no servidor, que só
--    DESBLOQUEIA (grava em data.awakenedCharacters). Quem equipa é o
--    SelectCharacter normal: uma vez desbloqueado, equipar o original já
--    entrega a forma desperta (GameManager_V9, `usingAwakened`).
--    O V7 disparava o remote e dizia "Despertar equipado!" sem atualizar
--    nada na tela — parecia que o clique não fazia efeito.
--    Agora o texto diz DESBLOQUEAR, e depois do clique o inventário é
--    recarregado para o card da forma desperta aparecer na hora.
local function createAwakeningButton(charData, card)
	if not checkAwakeningRemote then
		return
	end
	-- O card da própria forma desperta não ganha este botão de novo
	if charData.isAwakenedCard then
		return
	end

	local success, awakeningInfo = pcall(function()
		return checkAwakeningRemote:InvokeServer(charData.name)
	end)
	if not success or not awakeningInfo or not awakeningInfo.exists then
		return
	end

	local jaDesbloqueado = table.find(playerData.awakenedCharacters or {}, charData.name) ~= nil
	local nomeDesperto = (awakeningInfo.awakening and awakeningInfo.awakening.displayName)
		or (charData.name .. " (Despertado)")

	local awakeningButton = Instance.new("TextButton")
	awakeningButton.Size = UDim2.new(0.96, 0, 0.09, 0)
	awakeningButton.Position = UDim2.new(0.02, 0, 0.865, 0)
	awakeningButton.BorderColor3 = Color3.fromRGB(255, 0, 255)
	awakeningButton.BorderSizePixel = 2
	awakeningButton.TextScaled = true
	awakeningButton.Font = Enum.Font.Arcade
	awakeningButton.ZIndex = 10
	awakeningButton.Parent = card

	-- Estados: cada um diz exatamente o que falta, em vez de "VER"/"INFO"
	local podeDesbloquear = false

	if jaDesbloqueado then
		awakeningButton.Text = "⚡ DESPERTO"
		awakeningButton.BackgroundColor3 = Color3.fromRGB(80, 0, 120)
		awakeningButton.TextColor3 = Color3.fromRGB(255, 100, 255)
	elseif awakeningInfo.canEquip then
		-- canEquip = tem o original + tem o emblema/requisito
		awakeningButton.Text = "🔓 DESBLOQUEAR DESPERTAR"
		awakeningButton.BackgroundColor3 = Color3.fromRGB(120, 0, 160)
		awakeningButton.TextColor3 = Color3.fromRGB(255, 255, 0)
		podeDesbloquear = true
	elseif awakeningInfo.hasOriginal then
		awakeningButton.Text = "🔒 FALTA O EMBLEMA"
		awakeningButton.BackgroundColor3 = Color3.fromRGB(60, 0, 60)
		awakeningButton.TextColor3 = Color3.fromRGB(170, 170, 170)
	else
		awakeningButton.Text = "🔒 PRECISA DO ORIGINAL"
		awakeningButton.BackgroundColor3 = Color3.fromRGB(60, 0, 60)
		awakeningButton.TextColor3 = Color3.fromRGB(170, 170, 170)
	end

	awakeningButton.MouseButton1Click:Connect(function()
		playSound(sounds.awakening)

		if jaDesbloqueado then
			notify("⚡ " .. nomeDesperto .. " já está no seu inventário!", true)
			return
		end

		if not podeDesbloquear then
			if awakeningInfo.hasOriginal then
				notify("🔒 " .. nomeDesperto .. " — falta o emblema para desbloquear.", false)
			else
				notify("🔒 Você precisa ter " .. charData.name .. " para desbloquear o Despertar.", false)
			end
			return
		end

		if not equipAwakeningRemote then
			notify("❌ Remote de Despertar indisponível!", false)
			return
		end

		-- O servidor revalida original + emblema antes de conceder
		equipAwakeningRemote:FireServer(charData.name)

		-- O FireServer não devolve resposta, então dá um instante para o
		-- servidor gravar e sincronizar antes de redesenhar.
		task.spawn(function()
			task.wait(0.4)
			updatePlayerData()
			refreshOpenFrames()
			notify("⚡ " .. nomeDesperto .. " desbloqueado! Está no seu inventário.", true)
		end)
	end)

	-- Pulsa só quando há ação a tomar. No V7 pulsava sempre que tinha o
	-- original, inclusive quando não dava para fazer nada.
	if podeDesbloquear then
		task.spawn(function()
			while awakeningButton.Parent do
				TweenService:Create(
					awakeningButton,
					TweenInfo.new(1, Enum.EasingStyle.Sine),
					{ BackgroundColor3 = Color3.fromRGB(190, 0, 240) }
				):Play()
				task.wait(1)
				TweenService:Create(
					awakeningButton,
					TweenInfo.new(1, Enum.EasingStyle.Sine),
					{ BackgroundColor3 = Color3.fromRGB(120, 0, 160) }
				):Play()
				task.wait(1)
			end
		end)
	end
end

-- =====================================
-- CARD DE PERSONAGEM (V6)
-- charData = definição pública do catálogo:
-- { name, category, value, gamepassId, badgeId, imageId, rarity,
--   description, lore, health }
-- =====================================

createCharacterCard = function(charData, parentFrame, cardConfig, isInventoryMode)
	local card = Instance.new("Frame")
	card.Size = UDim2.new(0, cardConfig.width, 0, cardConfig.height)
	card.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
	card.Parent = parentFrame

	local rarityColor = rarities[charData.rarity] and rarities[charData.rarity].color
		or Color3.fromRGB(100, 100, 100)
	card.BorderColor3 = rarityColor
	card.BorderSizePixel = 3

	-- Efeito AWAKENED
	if charData.rarity == "AWAKENED" then
		task.spawn(function()
			while card.Parent do
				TweenService:Create(
					card,
					TweenInfo.new(1.5, Enum.EasingStyle.Sine),
					{ BorderColor3 = Color3.fromRGB(200, 0, 200) }
				):Play()
				task.wait(1.5)
				TweenService:Create(
					card,
					TweenInfo.new(1.5, Enum.EasingStyle.Sine),
					{ BorderColor3 = Color3.fromRGB(255, 0, 255) }
				):Play()
				task.wait(1.5)
			end
		end)
	end

	-- Header
	local header = Instance.new("Frame")
	header.Size = UDim2.new(1, 0, 0.15, 0)
	header.BackgroundColor3 = rarityColor
	header.BorderSizePixel = 0
	header.Parent = card

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size = UDim2.new(1, 0, 1, 0)
	nameLabel.BackgroundTransparency = 1
	-- (V8) displayName permite que o card da forma DESPERTA mostre o nome
	-- dela ("X (Despertado)") mesmo equipando pelo nome do original — que
	-- é como o servidor funciona.
	nameLabel.Text = (charData.displayName or charData.name):upper()
	nameLabel.TextColor3 = Color3.new(1, 1, 1)
	nameLabel.TextScaled = true
	nameLabel.Font = Enum.Font.Arcade
	nameLabel.Parent = header

	-- Imagem
	local imageContainer = Instance.new("Frame")
	imageContainer.Size = UDim2.new(0.96, 0, 0.38, 0)
	imageContainer.Position = UDim2.new(0.02, 0, 0.17, 0)
	imageContainer.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
	imageContainer.BorderSizePixel = 0
	imageContainer.ClipsDescendants = true
	imageContainer.Parent = card

	createCharacterImage(charData.name, imageContainer)

	-- Descrição
	local descText = charData.description
	if descText == nil or descText == "" then
		descText = "—"
	end

	local descLabel = Instance.new("TextLabel")
	descLabel.Size = UDim2.new(0.96, 0, 0.07, 0)
	descLabel.Position = UDim2.new(0.02, 0, 0.56, 0)
	descLabel.BackgroundTransparency = 1
	descLabel.Text = descText
	descLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
	descLabel.TextScaled = true
	descLabel.Font = Enum.Font.Code
	descLabel.Parent = card

	-- Raridade
	local rarityLabel = Instance.new("TextLabel")
	rarityLabel.Size = UDim2.new(0.96, 0, 0.05, 0)
	rarityLabel.Position = UDim2.new(0.02, 0, 0.64, 0)
	rarityLabel.BackgroundTransparency = 1
	rarityLabel.Text = charData.rarity or "?"
	rarityLabel.TextColor3 = rarityColor
	rarityLabel.TextScaled = true
	rarityLabel.Font = Enum.Font.Arcade
	rarityLabel.Parent = card

	-- Status / Requisito (V6: por categoria)
	local statusLabel = Instance.new("TextLabel")
	statusLabel.Size = UDim2.new(0.96, 0, 0.06, 0)
	statusLabel.Position = UDim2.new(0.02, 0, 0.70, 0)
	statusLabel.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
	statusLabel.BorderSizePixel = 0
	statusLabel.TextScaled = true
	statusLabel.Font = Enum.Font.Arcade
	statusLabel.Parent = card

	local isOwned = playerOwnsCharacter(charData.name)
	local isEquipped = playerData.equippedCharacter == charData.name

	if isInventoryMode then
		statusLabel.Text = "✅ ADQUIRIDO"
		statusLabel.TextColor3 = Color3.fromRGB(0, 255, 0)
	elseif charData.category == "Shop" then
		statusLabel.Text = "💰 " .. (charData.value or 0)
		statusLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
	elseif charData.category == "Reward" then
		statusLabel.Text = "🏆 " .. (charData.value or 0) .. " BOUNTY"
		statusLabel.TextColor3 = Color3.fromRGB(255, 150, 0)
	elseif charData.category == "Gamepass" then
		statusLabel.Text = "🎫 GAMEPASS"
		statusLabel.TextColor3 = Color3.fromRGB(0, 200, 255)
	elseif charData.category == "Badge" then
		statusLabel.Text = "🏅 EMBLEMA"
		statusLabel.TextColor3 = Color3.fromRGB(0, 255, 150)
	else
		statusLabel.Text = "💰 " .. (charData.value or 0)
		statusLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
	end

	-- ========== BOTÕES DE AÇÃO ==========

	local isEquippedNow = isEquipped

	-- Botão EQUIPAR / COMPRAR / GAMEPASS / LIBERAR
	local actionButton = Instance.new("TextButton")
	actionButton.Size = UDim2.new(0.44, 0, 0.07, 0)
	actionButton.Position = UDim2.new(0.02, 0, 0.78, 0)
	actionButton.TextScaled = true
	actionButton.Font = Enum.Font.Arcade
	actionButton.BorderSizePixel = 0
	actionButton.Parent = card

	if isEquippedNow then
		actionButton.Text = "✅ EQUIPADO"
		actionButton.BackgroundColor3 = Color3.fromRGB(0, 100, 0)
		actionButton.TextColor3 = Color3.new(1, 1, 1)
	elseif isOwned or isInventoryMode then
		actionButton.Text = "▶ EQUIPAR"
		actionButton.BackgroundColor3 = Color3.fromRGB(0, 150, 0)
		actionButton.TextColor3 = Color3.new(1, 1, 1)
	elseif charData.category == "Gamepass" then
		actionButton.Text = "🎫 GAMEPASS"
		actionButton.BackgroundColor3 = Color3.fromRGB(0, 100, 200)
		actionButton.TextColor3 = Color3.new(1, 1, 1)
	elseif charData.category == "Shop" then
		actionButton.Text = "💰 COMPRAR"
		actionButton.BackgroundColor3 = Color3.fromRGB(200, 100, 0)
		actionButton.TextColor3 = Color3.new(1, 1, 1)
	else
		-- Reward / Badge: o servidor valida o requisito e concede
		actionButton.Text = "🔓 LIBERAR"
		actionButton.BackgroundColor3 = Color3.fromRGB(120, 60, 200)
		actionButton.TextColor3 = Color3.new(1, 1, 1)
	end

	actionButton.MouseButton1Click:Connect(function()
		playSound(sounds.click)
		if isEquippedNow then
			return
		end

		if isOwned or isInventoryMode then
			tryEquipCharacter(charData.name)
		elseif charData.category == "Gamepass" then
			local gpId = tonumber(charData.gamepassId)
			if gpId and gpId > 0 then
				pcall(function()
					MarketplaceService:PromptGamePassPurchase(player, gpId)
				end)
			else
				notify("❌ Gamepass não configurado neste personagem!", false)
			end
		elseif charData.category == "Shop" then
			local ok, success, message = pcall(function()
				return purchaseCharacterRemote:InvokeServer(charData.name)
			end)
			if ok and success then
				notify("✅ " .. charData.name .. " comprado!", true)
				updatePlayerData()
				refreshOpenFrames()
			else
				local errMsg = (type(message) == "string" and message) or "Erro na compra"
				notify("❌ " .. errMsg, false)
			end
		else
			-- Reward / Badge: tenta liberar — o servidor (GameManager_V9)
			-- checa bounty/emblema e concede automaticamente
			tryEquipCharacter(charData.name)
		end
	end)

	-- ========== BOTÃO VENDER ==========
	-- Só aparece no inventário

	-- (V8) Forma desperta não se vende: ela não é um item do inventário,
	-- é um desbloqueio permanente em cima do original.
	if isInventoryMode and sellCharacterRemote and not charData.isAwakenedCard then
		local canSell, sellPrice, charId = canSellCharacter(charData.name)

		local sellButton = Instance.new("TextButton")
		sellButton.Size = UDim2.new(0.25, 0, 0.07, 0)
		sellButton.Position = UDim2.new(0.48, 0, 0.78, 0)
		sellButton.TextScaled = true
		sellButton.Font = Enum.Font.Arcade
		sellButton.BorderSizePixel = 0
		sellButton.Parent = card

		if canSell and sellPrice and sellPrice > 0 then
			sellButton.Text = "💰 " .. sellPrice
			sellButton.BackgroundColor3 = Color3.fromRGB(200, 150, 0)
			sellButton.TextColor3 = Color3.new(1, 1, 1)

			sellButton.MouseButton1Click:Connect(function()
				playSound(sounds.click)
				createSellConfirmPopup(charData.name, sellPrice, charId)
			end)
		else
			sellButton.Text = "🔒"
			sellButton.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
			sellButton.TextColor3 = Color3.fromRGB(100, 100, 100)
			-- Sem ação — não vendável
		end

		-- Botões ⚔️ e 📖 compactos para dar espaço ao vender
		local infoButton = Instance.new("TextButton")
		infoButton.Size = UDim2.new(0.12, 0, 0.07, 0)
		infoButton.Position = UDim2.new(0.75, 0, 0.78, 0)
		infoButton.BackgroundColor3 = Color3.fromRGB(0, 100, 200)
		infoButton.BorderSizePixel = 0
		infoButton.Text = "⚔️"
		infoButton.TextScaled = true
		infoButton.Font = Enum.Font.Arcade
		infoButton.Parent = card

		infoButton.MouseButton1Click:Connect(function()
			createAbilitiesPopup(charData.name)
		end)

		local loreButton = Instance.new("TextButton")
		loreButton.Size = UDim2.new(0.12, 0, 0.07, 0)
		loreButton.Position = UDim2.new(0.87, 0, 0.78, 0)
		loreButton.BackgroundColor3 = Color3.fromRGB(150, 100, 0)
		loreButton.BorderSizePixel = 0
		loreButton.Text = "📖"
		loreButton.TextScaled = true
		loreButton.Font = Enum.Font.Arcade
		loreButton.Parent = card

		loreButton.MouseButton1Click:Connect(function()
			createLorePopup(charData.name)
		end)
	else
		-- Layout padrão (loja) — sem botão vender
		local infoButton = Instance.new("TextButton")
		infoButton.Size = UDim2.new(0.2, 0, 0.07, 0)
		infoButton.Position = UDim2.new(0.52, 0, 0.78, 0)
		infoButton.BackgroundColor3 = Color3.fromRGB(0, 100, 200)
		infoButton.BorderSizePixel = 0
		infoButton.Text = "⚔️"
		infoButton.TextScaled = true
		infoButton.Font = Enum.Font.Arcade
		infoButton.Parent = card

		infoButton.MouseButton1Click:Connect(function()
			createAbilitiesPopup(charData.name)
		end)

		local loreButton = Instance.new("TextButton")
		loreButton.Size = UDim2.new(0.2, 0, 0.07, 0)
		loreButton.Position = UDim2.new(0.75, 0, 0.78, 0)
		loreButton.BackgroundColor3 = Color3.fromRGB(150, 100, 0)
		loreButton.BorderSizePixel = 0
		loreButton.Text = "📖"
		loreButton.TextScaled = true
		loreButton.Font = Enum.Font.Arcade
		loreButton.Parent = card

		loreButton.MouseButton1Click:Connect(function()
			createLorePopup(charData.name)
		end)
	end

	-- Despertar
	createAwakeningButton(charData, card)

	return card
end

-- =====================================
-- CRIAR SISTEMA UNIFICADO (V6)
-- =====================================

createSystem = function()
	if systemGui then
		systemGui.Parent = nil
	end

	systemGui = Instance.new("ScreenGui")
	systemGui.Name = "CharacterSystemV6"
	systemGui.ResetOnSpawn = false
	systemGui.IgnoreGuiInset = true
	systemGui.Parent = playerGui

	-- ─────────────────────────────────────
	-- FRAME PRINCIPAL - LOJA
	-- ─────────────────────────────────────

	mainFrame = Instance.new("Frame")
	mainFrame.Name = "MainFrame"
	mainFrame.Size = uiScale.menu
	mainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
	mainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	mainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
	mainFrame.BorderColor3 = Color3.fromRGB(255, 255, 255)
	mainFrame.BorderSizePixel = 4
	mainFrame.Visible = false
	mainFrame.Parent = systemGui

	local menuHeader = Instance.new("Frame")
	menuHeader.Size = UDim2.new(1, 0, 0.08, 0)
	menuHeader.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
	menuHeader.BorderSizePixel = 0
	menuHeader.Parent = mainFrame

	local menuTitle = Instance.new("TextLabel")
	menuTitle.Size = UDim2.new(0.7, 0, 1, 0)
	menuTitle.BackgroundTransparency = 1
	menuTitle.Text = "🧑 MENU DE PERSONAGENS"
	menuTitle.TextColor3 = Color3.fromRGB(255, 215, 0)
	menuTitle.TextScaled = true
	menuTitle.Font = Enum.Font.Arcade
	menuTitle.Parent = menuHeader

	local coinsLabel = Instance.new("TextLabel")
	coinsLabel.Name = "CoinsLabel"
	coinsLabel.Size = UDim2.new(0.2, 0, 0.8, 0)
	coinsLabel.Position = UDim2.new(0.70, 0, 0.1, 0)
	coinsLabel.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
	coinsLabel.BorderSizePixel = 0
	coinsLabel.Text = "💰 " .. playerData.coins
	coinsLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
	coinsLabel.TextScaled = true
	coinsLabel.Font = Enum.Font.Arcade
	coinsLabel.Parent = menuHeader

	local menuClose = Instance.new("TextButton")
	menuClose.Size = UDim2.new(0.08, 0, 0.8, 0)
	menuClose.Position = UDim2.new(0.91, 0, 0.1, 0)
	menuClose.BackgroundColor3 = Color3.fromRGB(150, 0, 0)
	menuClose.BorderSizePixel = 0
	menuClose.Text = "X"
	menuClose.TextColor3 = Color3.new(1, 1, 1)
	menuClose.TextScaled = true
	menuClose.Font = Enum.Font.Arcade
	menuClose.Parent = menuHeader

	-- Tabs de categoria (V6: 4 abas — SEM GRÁTIS)
	local tabFrame = Instance.new("Frame")
	tabFrame.Size = UDim2.new(1, 0, 0.06, 0)
	tabFrame.Position = UDim2.new(0, 0, 0.08, 0)
	tabFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
	tabFrame.BorderSizePixel = 0
	tabFrame.Parent = mainFrame

	local tabWidth = 1 / #SHOP_TABS

	contentFrame = Instance.new("ScrollingFrame")
	contentFrame.Size = UDim2.new(0.98, 0, 0.84, 0)
	contentFrame.Position = UDim2.new(0.01, 0, 0.15, 0)
	contentFrame.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
	contentFrame.BorderColor3 = Color3.fromRGB(100, 100, 100)
	contentFrame.BorderSizePixel = 2
	contentFrame.ScrollBarThickness = isMobile and 8 or 12
	contentFrame.Parent = mainFrame

	for i, tab in ipairs(SHOP_TABS) do
		local tabButton = Instance.new("TextButton")
		tabButton.Size = UDim2.new(tabWidth, 0, 1, 0)
		tabButton.Position = UDim2.new((i - 1) * tabWidth, 0, 0, 0)
		tabButton.BackgroundColor3 = selectedCategory == tab.key and Color3.fromRGB(200, 150, 0)
			or Color3.fromRGB(40, 40, 40)
		tabButton.BorderSizePixel = 0
		tabButton.Text = tab.label
		tabButton.TextColor3 = selectedCategory == tab.key and Color3.fromRGB(20, 20, 20)
			or Color3.new(1, 1, 1)
		tabButton.TextScaled = true
		tabButton.Font = Enum.Font.Arcade
		tabButton.Parent = tabFrame

		tabButton.MouseButton1Click:Connect(function()
			playSound(sounds.click)
			selectedCategory = tab.key
			for _, btn in pairs(tabFrame:GetChildren()) do
				if btn:IsA("TextButton") then
					btn.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
					btn.TextColor3 = Color3.new(1, 1, 1)
				end
			end
			tabButton.BackgroundColor3 = Color3.fromRGB(200, 150, 0)
			tabButton.TextColor3 = Color3.fromRGB(20, 20, 20)
			local f = systemGui:FindFirstChild("RefreshCategory")
			if f and f:IsA("BindableFunction") then
				pcall(function()
					f:Invoke()
				end)
			end
		end)
	end

	-- Refresh loja
	local refreshCategory = Instance.new("BindableFunction")
	refreshCategory.Name = "RefreshCategory"
	refreshCategory.Parent = systemGui

	refreshCategory.OnInvoke = function()
		for _, child in pairs(contentFrame:GetChildren()) do
			if child:IsA("Frame") or child:IsA("TextLabel") then
				child.Parent = nil
			end
		end

		updatePlayerData()
		coinsLabel.Text = "💰 " .. playerData.coins

		-- (V6) Personagens vêm SÓ do catálogo, filtrados pela aba
		local chars = getCharactersForCategory(selectedCategory)
		local cardConfig = uiScale.card
		local spacing = cardConfig.spacing
		local index = 0

		for _, charDef in ipairs(chars) do
			if not playerOwnsCharacter(charDef.name) then
				local col = index % cardConfig.columns
				local row = math.floor(index / cardConfig.columns)
				local card = createCharacterCard(charDef, contentFrame, cardConfig, false)
				card.Position = UDim2.new(
					0,
					spacing + col * (cardConfig.width + spacing),
					0,
					spacing + row * (cardConfig.height + spacing)
				)
				index = index + 1
			end
		end

		-- (V6) Categoria vazia → aviso em vez de tela em branco
		if index == 0 then
			local emptyLabel = Instance.new("TextLabel")
			emptyLabel.Size = UDim2.new(0.9, 0, 0.2, 0)
			emptyLabel.Position = UDim2.new(0.05, 0, 0.1, 0)
			emptyLabel.BackgroundTransparency = 1
			emptyLabel.Text = "Nenhum personagem disponível nesta categoria no momento."
			emptyLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
			emptyLabel.TextScaled = true
			emptyLabel.TextWrapped = true
			emptyLabel.Font = Enum.Font.Code
			emptyLabel.Parent = contentFrame
		end

		local rows = math.ceil(index / cardConfig.columns)
		contentFrame.CanvasSize = UDim2.new(0, 0, 0, rows * (cardConfig.height + spacing) + spacing)
	end

	-- ─────────────────────────────────────
	-- FRAME INVENTÁRIO
	-- ─────────────────────────────────────

	invFrame = Instance.new("Frame")
	invFrame.Name = "InventoryFrame"
	invFrame.Size = isMobile and UDim2.new(0.95, 0, 0.85, 0) or UDim2.new(0.7, 0, 0.75, 0)
	invFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
	invFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	invFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
	invFrame.BorderColor3 = Color3.fromRGB(255, 255, 255)
	invFrame.BorderSizePixel = 4
	invFrame.Visible = false
	invFrame.Parent = systemGui

	local invHeader = Instance.new("Frame")
	invHeader.Size = UDim2.new(1, 0, 0.08, 0)
	invHeader.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
	invHeader.BorderSizePixel = 0
	invHeader.Parent = invFrame

	local invTitle = Instance.new("TextLabel")
	invTitle.Size = UDim2.new(0.9, 0, 1, 0)
	invTitle.BackgroundTransparency = 1
	invTitle.Text = "📦 INVENTÁRIO — 💰 Clique no preço para vender"
	invTitle.TextColor3 = Color3.fromRGB(100, 200, 255)
	invTitle.TextScaled = true
	invTitle.Font = Enum.Font.Arcade
	invTitle.Parent = invHeader

	local invClose = Instance.new("TextButton")
	invClose.Size = UDim2.new(0.08, 0, 0.8, 0)
	invClose.Position = UDim2.new(0.91, 0, 0.1, 0)
	invClose.BackgroundColor3 = Color3.fromRGB(150, 0, 0)
	invClose.BorderSizePixel = 0
	invClose.Text = "X"
	invClose.TextColor3 = Color3.new(1, 1, 1)
	invClose.TextScaled = true
	invClose.Font = Enum.Font.Arcade
	invClose.Parent = invHeader

	invScroll = Instance.new("ScrollingFrame")
	invScroll.Size = UDim2.new(0.98, 0, 0.9, 0)
	invScroll.Position = UDim2.new(0.01, 0, 0.09, 0)
	invScroll.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
	invScroll.BorderColor3 = Color3.fromRGB(100, 100, 100)
	invScroll.BorderSizePixel = 2
	invScroll.ScrollBarThickness = isMobile and 8 or 12
	invScroll.Parent = invFrame

	-- Refresh inventário
	local refreshInventory = Instance.new("BindableFunction")
	refreshInventory.Name = "RefreshInventory"
	refreshInventory.Parent = systemGui

	refreshInventory.OnInvoke = function()
		for _, child in pairs(invScroll:GetChildren()) do
			if child:IsA("Frame") or child:IsA("TextLabel") then
				child.Parent = nil
			end
		end

		updatePlayerData()

		local cardConfig = uiScale.card
		local spacing = cardConfig.spacing
		local index = 0

		for _, characterName in ipairs(playerData.ownedCharacters) do
			-- (V5) Definição vem do catálogo; fora do catálogo = card genérico
			-- (ex.: personagem removido aguardando prune no próximo login)
			local charInfo = getCatalogDef(characterName)
			if not charInfo then
				charInfo = {
					name = characterName,
					category = "Shop",
					value = 0,
					description = "Personagem especial",
					rarity = "AWAKENED",
				}
			end

			local col = index % cardConfig.columns
			local row = math.floor(index / cardConfig.columns)
			local card = createCharacterCard(charInfo, invScroll, cardConfig, true)
			card.Position = UDim2.new(
				0,
				spacing + col * (cardConfig.width + spacing),
				0,
				spacing + row * (cardConfig.height + spacing)
			)
			index = index + 1
		end

		-- (V8) CARDS DAS FORMAS DESPERTAS
		-- O Despertar não vive em ownedCharacters: o servidor grava numa
		-- lista à parte (data.awakenedCharacters, via addAwakenedCharacter).
		-- Por isso ele nunca aparecia no inventário — o loop acima só lê
		-- ownedCharacters. Aqui cada desbloqueio ganha o card dele.
		--
		-- O card equipa pelo nome do ORIGINAL de propósito: é assim que o
		-- servidor funciona. Uma vez desbloqueado, o SelectCharacter do
		-- original já entrega a forma desperta (GameManager_V9,
		-- `usingAwakened`) — não existe um "equipar desperto" separado.
		for _, originalName in ipairs(playerData.awakenedCharacters or {}) do
			local nomeDesperto = originalName .. " (Despertado)"
			if checkAwakeningRemote then
				local ok, info = pcall(function()
					return checkAwakeningRemote:InvokeServer(originalName)
				end)
				if ok and info and info.awakening and info.awakening.displayName then
					nomeDesperto = info.awakening.displayName
				end
			end

			local baseDef = getCatalogDef(originalName)
			local awakenedInfo = {
				name = originalName, -- equipar usa o nome do original
				displayName = nomeDesperto,
				isAwakenedCard = true,
				category = "Reward",
				value = 0,
				rarity = "AWAKENED",
				health = baseDef and baseDef.health or nil,
				description = "Forma desperta de " .. originalName .. ". Equipar o original já usa esta forma.",
			}

			local col = index % cardConfig.columns
			local row = math.floor(index / cardConfig.columns)
			local card = createCharacterCard(awakenedInfo, invScroll, cardConfig, true)
			card.Position = UDim2.new(
				0,
				spacing + col * (cardConfig.width + spacing),
				0,
				spacing + row * (cardConfig.height + spacing)
			)
			index = index + 1
		end

		-- Inventário vazio → aviso
		if index == 0 then
			local emptyLabel = Instance.new("TextLabel")
			emptyLabel.Size = UDim2.new(0.9, 0, 0.2, 0)
			emptyLabel.Position = UDim2.new(0.05, 0, 0.1, 0)
			emptyLabel.BackgroundTransparency = 1
			emptyLabel.Text = "Seu inventário está vazio. Personagens GRÁTIS chegam aqui automaticamente!"
			emptyLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
			emptyLabel.TextScaled = true
			emptyLabel.TextWrapped = true
			emptyLabel.Font = Enum.Font.Code
			emptyLabel.Parent = invScroll
		end

		local rows = math.ceil(index / cardConfig.columns)
		invScroll.CanvasSize = UDim2.new(0, 0, 0, rows * (cardConfig.height + spacing) + spacing)
	end

	-- ─────────────────────────────────────
	-- FUNÇÕES DE ABERTURA (chamadas pelo Menu Unificado)
	-- ─────────────────────────────────────

	_G.OpenCharacterShop = function()
		if isInvOpen then
			isInvOpen = false
			invFrame.Visible = false
		end
		isMenuOpen = true
		mainFrame.Visible = true
		playSound(sounds.open)
		refreshCatalogCharacters() -- (V5) busca personagens novos ao abrir
		local f = systemGui:FindFirstChild("RefreshCategory")
		if f and f:IsA("BindableFunction") then
			pcall(function()
				f:Invoke()
			end)
		end
	end

	_G.CloseCharacterShop = function()
		isMenuOpen = false
		mainFrame.Visible = false
	end

	_G.OpenCharacterInventory = function()
		if isMenuOpen then
			isMenuOpen = false
			mainFrame.Visible = false
		end
		isInvOpen = true
		invFrame.Visible = true
		playSound(sounds.open)
		refreshCatalogCharacters() -- (V5) garante defs pros cards
		local f = systemGui:FindFirstChild("RefreshInventory")
		if f and f:IsA("BindableFunction") then
			pcall(function()
				f:Invoke()
			end)
		end
	end

	_G.CloseCharacterInventory = function()
		isInvOpen = false
		invFrame.Visible = false
	end

	menuClose.MouseButton1Click:Connect(function()
		playSound(sounds.close)
		isMenuOpen = false
		mainFrame.Visible = false
	end)

	invClose.MouseButton1Click:Connect(function()
		playSound(sounds.close)
		isInvOpen = false
		invFrame.Visible = false
	end)
end

-- =====================================
-- INICIALIZAÇÃO
-- =====================================

task.spawn(refreshCatalogCharacters)

player.CharacterAdded:Connect(function()
	task.wait(1)
	createSystem()
	updatePlayerData()
end)

if player.Character then
	createSystem()
	updatePlayerData()
end

-- Sync periódico
task.spawn(function()
	while true do
		task.wait(5)
		if systemGui and systemGui.Parent then
			updatePlayerData()
		end
	end
end)

-- Registrar no Menu Unificado
task.spawn(function()
	local timeout = 0
	while not _G.RegisterMenuCategory and timeout < 15 do
		task.wait(0.5)
		timeout = timeout + 0.5
	end

	if _G.RegisterMenuCategory then
		_G.RegisterMenuCategory("LOJA", "🛒", function()
			if _G.OpenCharacterShop then
				_G.OpenCharacterShop()
			end
		end, function()
			if _G.CloseCharacterShop then
				_G.CloseCharacterShop()
			end
		end, 1)

		_G.RegisterMenuCategory("INVENTÁRIO", "📦", function()
			if _G.OpenCharacterInventory then
				_G.OpenCharacterInventory()
			end
		end, function()
			if _G.CloseCharacterInventory then
				_G.CloseCharacterInventory()
			end
		end, 2)

		print("[CHAR SYSTEM V7] Registrado no Menu Unificado: LOJA + INVENTÁRIO")
	end
end)

print([[
╔══════════════════════════════════════════════════════╗
║  CHARACTER SYSTEM CLIENT V8 — CARREGADO             ║
╠══════════════════════════════════════════════════════╣
║  SUBSTITUI: CharacterSystemClient V7                 ║
║  REMOVER:   CharacterSystemClient V7                 ║
╠══════════════════════════════════════════════════════╣
║  V8 MUDANÇAS (DESPERTAR):                            ║
║  * Botão saiu de cima da borda do card (dava pra     ║
║    ver, agora dá) — faixa própria em y=0.865         ║
║  * Botão é DESBLOQUEAR, não equipar: o remote só     ║
║    concede; equipar o original já usa a forma        ║
║  * Card separado da forma desperta no INVENTÁRIO     ║
║  * Estados claros: DESPERTO / DESBLOQUEAR / FALTA    ║
║    O EMBLEMA / PRECISA DO ORIGINAL                   ║
║  * Popup de habilidades lista as FERRAMENTAS         ║
║    carregadas (normais + despertas), lendo direto    ║
║    de ReplicatedStorage.Characters — sem remote      ║
╠══════════════════════════════════════════════════════╣
║  V6 MUDANÇAS:                                        ║
║  * ABA GRÁTIS REMOVIDA (Mandatory vai direto pro     ║
║    Inventário via CatalogServer V4)                  ║
║  * 4 abas: LOJA/RECOMPENSA/GAMEPASS/EMBLEMA          ║
║  * Mensagens de erro reais do servidor               ║
║  * Notificação pré-menu corrigida (ScreenGui temp)   ║
║  MANTIDO DO V5:                                      ║
║  * ZERO personagem fixo — tudo do catálogo           ║
║  * Escuta CatalogAnnouncement (aviso global)         ║
║  * Popups/venda 25%/Despertar/UI responsiva          ║
╚══════════════════════════════════════════════════════╝
]])

