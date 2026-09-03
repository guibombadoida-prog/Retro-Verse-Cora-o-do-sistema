-- ============================================
-- CHARACTER SYSTEM CLIENT V14 — CINCO ABAS DE DETALHES VISÍVEIS
-- Coloque em StarterPlayer > StarterPlayerScripts
-- Nome: "CharacterSystemClient"
-- SUBSTITUI: CharacterSystemClient V13
-- ============================================
-- (V14) Corrige o conteúdo invisível do modal publicado na V13. O ScreenGui
-- usava ZIndexBehavior.Global: painel e rolagem estavam nas camadas 10/12,
-- mas as seções internas continuavam na camada padrão 1 e eram desenhadas
-- atrás do painel. O modal agora usa Sibling, preservando a hierarquia real.
--
-- O conteúdo foi separado em cinco abas: Informações, Lore, Habilidades,
-- Atributos e Despertar. Habilidades lê as Tools realmente replicadas e os
-- metadados que elas publicam; Atributos lê HP, arquétipo, bônus e penalidades
-- do CharacterStatsServer. Um UIGridLayout distribui as cinco abas sem
-- posições manuais e usa rótulos curtos no celular em retrato.
-- ============================================
-- (V13) Informações, Lore e Despertar agora dividem um modal único,
-- responsivo e navegável por abas. A entrada usa mola amortecida, cada
-- seção entra em cascata e os textos são revelados progressivamente com
-- opção de mostrar tudo. A aba de Despertar exibe requisitos, forma,
-- métricas, habilidades e história sem alterar a regra de combate.
--
-- O conteúdo usa alturas em pixels calculadas pelo viewport para não
-- criar realimentação entre Size.Scale e AutomaticCanvasSize no celular.
-- Ao girar a tela, a aba aberta é reconstruída e mantém sua seleção.
-- ============================================
-- (V12) Redesign completo da loja e do inventário, inspirado no HUD
-- retro-neon do próprio jogo: painéis escuros, contornos brancos/ciano,
-- informação em blocos e cores fortes por raridade.
--
-- • Corrige o tamanho de verdade: janela e cards reagem a retrato,
--   paisagem, tablet e desktop; cards recebem UIAspectRatioConstraint.
-- • Busca por nome, descrição, raridade, categoria e ID de emblema.
-- • Cards mostram selo de origem (loja, recompensa, gamepass, emblema),
--   emblema de raridade e estados ADQUIRIDO/EQUIPADO sem ambiguidade.
-- • Entrada/saída usa mola amortecida calculada no Heartbeat: animação
--   com física visual, sem BodyMovers e sem threads disputando a UI.
-- • Brilhos repetidos usam um tween guardado e cancelável; conexões e
--   tweens de cada render são limpos antes de filtrar ou reconstruir.
-- • A busca é desacelerada por geração e atualiza somente a tela aberta.
--
-- Mantém toda decisão de compra, venda, emblema e equipamento no servidor.
-- O cliente apenas apresenta e solicita as ações existentes.
-- ============================================
-- (V11) Três problemas do mesmo lugar: o layout da grade.
--
--   1. TAMANHO ERRADO. Cada card era posicionado por conta de col/row em
--      PIXELS ABSOLUTOS, e getUIScale() rodava UMA VEZ na carga do
--      script. Girar o celular não refazia nada — a grade continuava com
--      a largura da orientação anterior, com coluna sobrando ou faltando.
--      Agora quem posiciona é UIGridLayout, a altura do conteúdo é
--      AutomaticCanvasSize, e a escala é recalculada no evento de
--      ViewportSize (adiado com task.defer, porque a rotação dispara
--      várias mudanças seguidas e remontar em cada uma faria piscar).
--
--   2. SEM BUSCA. Achar um personagem era rolar até encontrar. Loja e
--      inventário ganharam barra de pesquisa que filtra a cada tecla —
--      esperar o Enter faz a busca parecer quebrada.
--
--   3. TUDO NUM MONTE SÓ. Os cards saíam numa grade única sem divisão.
--      Agora vêm em seções por raridade, na ordem declarada em
--      `rarities`, com cabeçalho colorido.
--
-- O aviso de lista vazia passou a distinguir "não tem nada nesta
-- categoria" de "sua busca não achou nada" — são situações diferentes e
-- pedem ações diferentes de quem está lendo.
-- ============================================
-- (V10) O botão VOLTOU, abrindo informação em vez de equipar.
-- O V9 tirou o botão inteiro e deixou só um rótulo com o nome — longe
-- demais: sumiam a imagem, a história e as habilidades da forma. Agora
-- "VER DESPERTAR" abre um painel com imagem, nome, história, HP e a
-- lista de Tools despertas (lidas do que está REALMENTE carregado em
-- ReplicatedStorage, não do que o catálogo diz que deveria estar).
-- Equipar continua não existindo: a forma é conquistada em combate.
-- ============================================
-- (V9) O card do Despertar não tem mais botão.
--
-- Até o V8 o card trazia "🔓 DESBLOQUEAR DESPERTAR", que gravava o
-- Despertar no save e fazia o personagem nascer desperto para sempre.
--
-- Agora o Despertar é uma FORMA TEMPORÁRIA do personagem normal: já vem
-- junto com ele, e quem dispara é a barra do AwakeningMeterServer, que
-- enche batendo e apanhando no combate. O card virou o que o desenho
-- pede — imagem, nome e o que falta para liberar. Nada de equipar.
-- ============================================
-- (V8) DESPERTAR VISÍVEL E DESBLOQUEÁVEL (histórico)
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
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

print("[CHAR SYSTEM V13] Inicializando menus e detalhes animados...")

-- =====================================
-- DETECÇÃO DE PLATAFORMA
-- =====================================

local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

-- =====================================
-- AGUARDAR REMOTES
-- =====================================

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local selectCharacterRemote = remotes:WaitForChild("SelectCharacter")
local purchaseCharacterRemote = remotes:WaitForChild("PurchaseCharacter")
local getPlayerDataRemote = remotes:WaitForChild("GetPlayerData")
local checkAwakeningRemote = remotes:WaitForChild("CheckAwakening", 10)
-- (V9) EquipAwakening não é mais usado: o Despertar deixou de ser algo
-- que se desbloqueia e se equipa. Mantido só como referência histórica.
-- local equipAwakeningRemote = remotes:WaitForChild("EquipAwakening", 10)
local syncCharacterStateRemote = remotes:WaitForChild("SyncCharacterState", 10)
local sellCharacterRemote = remotes:WaitForChild("SellCharacter", 10)

-- (V5) Remotes do catálogo dinâmico (CharacterCatalogServer_V4)
local getCatalogCharactersRemote = remotes:WaitForChild("GetCatalogCharacters", 15)
local catalogAnnouncementRemote = remotes:WaitForChild("CatalogAnnouncement", 15)

-- (V7) Atributos por personagem. Opcional: se o CharacterStatsServer
-- V1 não estiver instalado, isto fica nil e o popup usa o modo V6.
local getCharacterStatsInfo = remotes:WaitForChild("GetCharacterStatsInfo", 10)

if not getCatalogCharactersRemote then
	warn("[CHAR SYSTEM V13] GetCatalogCharacters não encontrado — o CharacterCatalogServer_V4 está no ServerScriptService?")
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
local CARD_ASPECT_RATIO = 0.68

local function getViewportSize()
	local camera = workspace.CurrentCamera
	return camera and camera.ViewportSize or Vector2.new(1280, 720)
end

local function getUIScale()
	local viewport = getViewportSize()
	local portrait = viewport.Y > viewport.X
	local shortSide = math.min(viewport.X, viewport.Y)
	local menuWidth
	local menuHeight
	local columns

	if isMobile then
		if portrait then
			menuWidth = 0.94
			menuHeight = 0.88
			columns = shortSide < 440 and 2 or 3
		else
			menuWidth = 0.92
			menuHeight = 0.84
			columns = viewport.X >= 1450 and 5 or 4
		end
	elseif viewport.X < 900 then
		menuWidth = 0.9
		menuHeight = 0.86
		columns = portrait and 2 or 3
	else
		menuWidth = 0.78
		menuHeight = 0.82
		columns = viewport.X >= 1500 and 6 or 5
	end

	local sizeFactor = currentUISize == UI_SIZES.SMALL and 0.9
		or (currentUISize == UI_SIZES.LARGE and 1.08 or 1)
	local spacing = math.floor(math.clamp(shortSide * 0.012, 6, 14))
	local contentWidth = viewport.X * menuWidth * 0.96 - spacing * (columns + 1)
	local cardWidth = math.max(92, math.floor((contentWidth / columns) * sizeFactor))
	local cardHeight = math.floor(cardWidth / CARD_ASPECT_RATIO)
	local maxCardHeight = math.floor(viewport.Y * menuHeight * (portrait and 0.58 or 0.7))
	if cardHeight > maxCardHeight then
		cardHeight = maxCardHeight
		cardWidth = math.floor(cardHeight * CARD_ASPECT_RATIO)
	end

	return {
		menu = UDim2.fromScale(menuWidth, menuHeight),
		panelAspect = (viewport.X * menuWidth) / math.max(1, viewport.Y * menuHeight),
		portrait = portrait,
		card = {
			width = cardWidth,
			height = cardHeight,
			columns = columns,
			spacing = spacing,
			aspect = CARD_ASPECT_RATIO,
			sectionHeader = math.floor(math.clamp(shortSide * 0.05, 24, 40)),
		},
	}
end

local uiScale = getUIScale()

-- (V13.1) ARMADILHA: `uiScale` NÃO é um número.
--
-- O nome engana. Desde a V12 getUIScale() devolve uma TABELA de
-- configuração responsiva — { menu, panelAspect, portrait, card } — e não
-- o fator de escala que o nome sugere. Escrever `16 * uiScale` compila,
-- passa no Rojo e no luau-compile, e só quebra quando o jogador abre o
-- painel: "attempt to perform arithmetic (mul) on number and table".
--
-- Foi exatamente esse o erro que derrubou a Lore na publicação das 20:08.
-- Quem precisa de um ESCALAR de tela usa esta função, não a tabela.
local function escalaPorTela(base, minimo, maximo)
	local viewport = getViewportSize()
	local ladoCurto = math.min(viewport.X, viewport.Y)
	-- 640 é o lado curto de referência: perto de um celular deitado
	-- grande. Acima disso o texto cresce até o teto, abaixo encolhe até
	-- o piso, e o clamp garante que nenhum aparelho saia da faixa legível.
	return math.clamp(math.floor(base * ladoCurto / 640), minimo, maximo)
end

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

local COLORS = {
	background = Color3.fromRGB(7, 9, 16),
	panel = Color3.fromRGB(15, 18, 28),
	panelRaised = Color3.fromRGB(27, 31, 43),
	ink = Color3.fromRGB(238, 247, 255),
	muted = Color3.fromRGB(138, 153, 171),
	cyan = Color3.fromRGB(0, 225, 255),
	blue = Color3.fromRGB(0, 125, 220),
	yellow = Color3.fromRGB(255, 215, 0),
	orange = Color3.fromRGB(255, 145, 30),
	green = Color3.fromRGB(40, 230, 115),
	red = Color3.fromRGB(225, 55, 70),
	magenta = Color3.fromRGB(255, 45, 225),
	white = Color3.fromRGB(245, 250, 255),
}

local CATEGORY_META = {
	Shop = { icon = "💰", label = "LOJA", color = COLORS.yellow },
	Reward = { icon = "🏆", label = "RECOMPENSA", color = Color3.fromRGB(255, 145, 30) },
	Gamepass = { icon = "🎫", label = "GAMEPASS", color = Color3.fromRGB(45, 155, 255) },
	Badge = { icon = "🏅", label = "EMBLEMA", color = Color3.fromRGB(45, 235, 170) },
	Mandatory = { icon = "🎁", label = "GRÁTIS", color = COLORS.green },
	Trade = { icon = "🔁", label = "TROCA", color = COLORS.magenta },
}

local RARITY_EMBLEMS = {
	ROBLOXIANOS = "R",
	HEROXIANOS = "H",
	NULLXIANOS = "N",
	BTUDIOS = "B",
	BOSSXIANOS = "X",
	SUPREMO = "S",
	AWAKENED = "⚡",
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

-- Contextos separam conexões/tweens do sistema, da loja e do inventário.
-- Filtrar uma lista limpa apenas o render dela; remontar a UI limpa tudo.
local systemContext = nil
local shopRenderContext = nil
local inventoryRenderContext = nil
local mainPanelMotion = nil
local inventoryPanelMotion = nil
local backdrop = nil
local mainAspectConstraint = nil
local inventoryAspectConstraint = nil
local mainCloseAspectConstraint = nil
local inventoryCloseAspectConstraint = nil
local mainTitleLabel = nil
local inventoryTitleLabel = nil
local inventoryHintLabel = nil
local categoryTabButtons = {}

local function novoContexto()
	return {
		alive = true,
		connections = {},
		tweens = {},
	}
end

local function limparContexto(context)
	if not context then
		return
	end
	context.alive = false
	for _, connection in ipairs(context.connections) do
		connection:Disconnect()
	end
	for _, tween in pairs(context.tweens) do
		tween:Cancel()
	end
	table.clear(context.connections)
	table.clear(context.tweens)
end

local function conectarContexto(context, signal, callback)
	local connection = signal:Connect(callback)
	if context and context.alive then
		table.insert(context.connections, connection)
	end
	return connection
end

local function tocarTween(context, key, instance, tweenInfo, properties)
	if not context or not context.alive or not instance or not instance.Parent then
		return nil
	end
	local previous = context.tweens[key]
	if previous then
		previous:Cancel()
	end
	local tween = TweenService:Create(instance, tweenInfo, properties)
	context.tweens[key] = tween
	tween:Play()
	return tween
end

local function limitarTexto(label, minSize, maxSize)
	local constraint = Instance.new("UITextSizeConstraint")
	constraint.MinTextSize = minSize or 10
	constraint.MaxTextSize = maxSize or 24
	constraint.Parent = label
	return constraint
end

local function prepararBotaoAnimado(context, button)
	button.AutoButtonColor = false
	local scale = Instance.new("UIScale")
	scale.Scale = 1
	scale.Parent = button

	local function irPara(value, duration)
		tocarTween(
			context,
			scale,
			scale,
			TweenInfo.new(duration or 0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Scale = value }
		)
	end

	conectarContexto(context, button.MouseEnter, function()
		irPara(1.035)
	end)
	conectarContexto(context, button.MouseLeave, function()
		irPara(1)
	end)
	conectarContexto(context, button.MouseButton1Down, function()
		irPara(0.96, 0.07)
	end)
	conectarContexto(context, button.MouseButton1Up, function()
		irPara(1.02, 0.1)
	end)

	return scale
end

-- Mola amortecida para entrada/saída. É física visual de UI: posição,
-- escala e rotação são integradas no Heartbeat; nenhuma força toca o avatar.
local function criarMolaPainel(context, frame, aoEsconder)
	local scale = Instance.new("UIScale")
	scale.Scale = 0.86
	scale.Parent = frame

	local state = {
		position = 0.86,
		velocity = 0,
		target = 0.86,
		active = false,
		closing = false,
	}

	local controller = {}

	function controller.open()
		if not frame.Parent then
			return
		end
		frame.Visible = true
		state.position = math.min(state.position, 0.9)
		state.velocity = 0
		state.target = 1
		state.closing = false
		state.active = true
	end

	function controller.close()
		if not frame.Visible then
			return
		end
		state.target = 0.86
		state.closing = true
		state.active = true
	end

	function controller.hide()
		state.position = 0.86
		state.velocity = 0
		state.target = 0.86
		state.active = false
		state.closing = false
		scale.Scale = 0.86
		frame.Rotation = 0
		frame.Visible = false
	end

	conectarContexto(context, RunService.Heartbeat, function(deltaTime)
		if not state.active or not frame.Parent then
			return
		end

		local dt = math.min(deltaTime, 1 / 30)
		local stiffness = 230
		local damping = 25
		local acceleration = (state.target - state.position) * stiffness - state.velocity * damping
		state.velocity += acceleration * dt
		state.position += state.velocity * dt
		state.position = math.clamp(state.position, 0.82, 1.06)

		scale.Scale = state.position
		frame.Rotation = math.clamp((1 - state.position) * -8, -2.2, 1.2)

		if math.abs(state.target - state.position) < 0.002 and math.abs(state.velocity) < 0.02 then
			state.position = state.target
			state.velocity = 0
			scale.Scale = state.target
			frame.Rotation = 0
			state.active = false
			if state.closing then
				state.closing = false
				frame.Visible = false
				if aoEsconder then
					aoEsconder()
				end
			end
		end
	end)

	return controller
end

-- =====================================
-- (V13) ANIMAÇÃO DE TEXTO E PAINEL MODAL
-- =====================================
-- Os painéis de lore e de Despertar eram os dois únicos do arquivo sem
-- nenhuma animação: nasciam prontos com Parent = playerGui e sumiam com
-- Parent = nil. E os dois liam texto longo com TextScaled, que encolhe a
-- fonte até tudo caber — uma lore de cinco linhas virava letra miúda
-- ilegível no celular.

-- Máquina de escrever por MaxVisibleGraphemes.
--
-- A forma ingênua seria cortar a string e reatribuir Text a cada quadro.
-- Isso remede o texto e recalcula a quebra de linha em toda letra: com
-- TextWrapped a última palavra fica pulando de linha enquanto digita.
-- MaxVisibleGraphemes esconde o final SEM mexer no Text, então a quebra
-- de linha é a final desde o primeiro quadro e nada se move na tela.
--
-- Grafema, e não byte: "ç" e "ã" ocupam dois bytes, e emoji ocupa mais.
-- Contar bytes cortaria um caractere no meio e mostraria lixo.
local function maquinaDeEscrever(context, chave, label, texto, porSegundo, atraso)
	label.Text = texto
	local total = utf8.len(texto) or #texto
	label.MaxVisibleGraphemes = 0

	local estado = { visiveis = 0, espera = atraso or 0, completo = false }
	local velocidade = porSegundo or 55

	local function completar()
		estado.completo = true
		estado.visiveis = total
		label.MaxVisibleGraphemes = -1
	end

	if total <= 0 then
		completar()
		return {
			completar = completar,
			terminou = function()
				return true
			end,
		}
	end

	-- O atraso inicial mora aqui dentro, e não num task.wait antes de
	-- chamar: assim ele vive no mesmo contexto do painel e morre junto
	-- se o jogador fechar antes de a digitação começar.
	local conexao
	conexao = conectarContexto(context, RunService.Heartbeat, function(deltaTime)
		if estado.completo or not label.Parent then
			return
		end

		local passo = math.min(deltaTime, 1 / 20)
		if estado.espera > 0 then
			estado.espera -= passo
			return
		end

		estado.visiveis += passo * velocidade
		if estado.visiveis >= total then
			completar()
			if conexao then
				conexao:Disconnect()
			end
		else
			label.MaxVisibleGraphemes = math.floor(estado.visiveis)
		end
	end)

	return {
		completar = completar,
		terminou = function()
			return estado.completo
		end,
	}
end

-- Casca comum dos dois painéis: fundo escuro que entra em fade, moldura
-- com mola, fechar por botão, por toque no fundo e por ESC, e saída
-- animada em vez de sumiço seco.
local function criarModal(largura, altura, corBorda)
	local context = novoContexto()

	local gui = Instance.new("ScreenGui")
	gui.Name = "CharModal"
	gui.DisplayOrder = 100
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.Parent = playerGui

	local fundo = Instance.new("TextButton")
	fundo.Size = UDim2.new(1, 0, 1, 0)
	fundo.BackgroundColor3 = Color3.new(0, 0, 0)
	fundo.BackgroundTransparency = 1
	fundo.AutoButtonColor = false
	fundo.Text = ""
	fundo.Parent = gui

	local painel = Instance.new("Frame")
	painel.AnchorPoint = Vector2.new(0.5, 0.5)
	painel.Position = UDim2.new(0.5, 0, 0.5, 0)
	painel.Size = UDim2.new(largura, 0, altura, 0)
	painel.BackgroundColor3 = COLORS.panel
	painel.BorderColor3 = corBorda
	painel.BorderSizePixel = 3
	painel.Visible = false
	painel.Parent = gui

	local canto = Instance.new("UICorner")
	canto.CornerRadius = UDim.new(0.02, 0)
	canto.Parent = painel

	local fechando = false
	local mola = criarMolaPainel(context, painel, function()
		limparContexto(context)
		gui.Parent = nil
	end)

	local function fechar()
		if fechando then
			return
		end
		fechando = true
		playSound(sounds.close)
		tocarTween(
			context,
			"fundoModal",
			fundo,
			TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ BackgroundTransparency = 1 }
		)
		mola.close()
	end

	tocarTween(
		context,
		"fundoModal",
		fundo,
		TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ BackgroundTransparency = 0.45 }
	)
	mola.open()

	conectarContexto(context, fundo.MouseButton1Click, fechar)
	conectarContexto(context, UserInputService.InputBegan, function(input, processado)
		if not processado and input.KeyCode == Enum.KeyCode.Escape then
			fechar()
		end
	end)

	return {
		context = context,
		gui = gui,
		painel = painel,
		fechar = fechar,
	}
end

-- Entrada escalonada de uma seção do painel. O atraso é DelayTime do
-- próprio TweenInfo: nenhuma thread por seção, então as seções não
-- disputam a UI entre si nem sobrevivem ao fechamento do painel.
-- `alvos` diz quais transparências animar até 0 (texto, fundo, imagem).
local function entrarEmSequencia(context, objeto, chave, ordem, alvos)
	local posicaoFinal = objeto.Position
	objeto.Position = posicaoFinal + UDim2.new(0, 0, 0.035, 0)
	for propriedade in pairs(alvos) do
		objeto[propriedade] = 1
	end

	local atraso = 0.06 + ordem * 0.05
	tocarTween(
		context,
		chave .. "Pos",
		objeto,
		TweenInfo.new(0.42, Enum.EasingStyle.Quint, Enum.EasingDirection.Out, 0, false, atraso),
		{ Position = posicaoFinal }
	)
	tocarTween(
		context,
		chave .. "Fade",
		objeto,
		TweenInfo.new(0.34, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, atraso),
		alvos
	)
	return atraso
end

-- Cabeçalho padrão dos dois painéis, com botão de fechar já animado.
local function criarCabecalhoModal(modal, texto, corFundo, corTexto)
	local header = Instance.new("Frame")
	header.Size = UDim2.new(1, 0, 0.12, 0)
	header.BackgroundColor3 = corFundo
	header.BorderSizePixel = 0
	header.Parent = modal.painel

	local headerCanto = Instance.new("UICorner")
	headerCanto.CornerRadius = UDim.new(0.12, 0)
	headerCanto.Parent = header

	local titulo = Instance.new("TextLabel")
	titulo.Size = UDim2.new(0.82, 0, 1, 0)
	titulo.Position = UDim2.new(0.03, 0, 0, 0)
	titulo.BackgroundTransparency = 1
	titulo.Text = texto
	titulo.TextColor3 = corTexto
	titulo.TextScaled = true
	titulo.TextXAlignment = Enum.TextXAlignment.Left
	titulo.Font = Enum.Font.Arcade
	titulo.Parent = header
	limitarTexto(titulo, 12, 30)

	local fecharBtn = Instance.new("TextButton")
	fecharBtn.Size = UDim2.new(0.1, 0, 0.72, 0)
	fecharBtn.Position = UDim2.new(0.87, 0, 0.14, 0)
	fecharBtn.BackgroundColor3 = COLORS.red
	fecharBtn.BorderSizePixel = 0
	fecharBtn.Text = "X"
	fecharBtn.TextColor3 = COLORS.white
	fecharBtn.TextScaled = true
	fecharBtn.Font = Enum.Font.Arcade
	fecharBtn.Parent = header

	local proporcao = Instance.new("UIAspectRatioConstraint")
	proporcao.AspectRatio = 1
	proporcao.DominantAxis = Enum.DominantAxis.Height
	proporcao.Parent = fecharBtn

	local fecharCanto = Instance.new("UICorner")
	fecharCanto.CornerRadius = UDim.new(0.2, 0)
	fecharCanto.Parent = fecharBtn

	prepararBotaoAnimado(modal.context, fecharBtn)
	conectarContexto(modal.context, fecharBtn.MouseButton1Click, modal.fechar)

	return header, titulo
end

-- Área de texto longo com rolagem. Texto de lore NÃO pode usar
-- TextScaled: ele encolhe a fonte até a última palavra caber, então
-- quanto mais história o personagem tem, menor fica a letra. Aqui o
-- tamanho é fixo e sobra rolagem, que é o contrário do que era.
local function criarAreaDeTexto(pai, posicao, tamanho, corMoldura)
	local moldura = Instance.new("Frame")
	moldura.Position = posicao
	moldura.Size = tamanho
	moldura.BackgroundColor3 = COLORS.panelRaised
	moldura.BorderColor3 = corMoldura
	moldura.BorderSizePixel = 2
	moldura.Parent = pai

	local molduraCanto = Instance.new("UICorner")
	molduraCanto.CornerRadius = UDim.new(0.06, 0)
	molduraCanto.Parent = moldura

	local rolagem = Instance.new("ScrollingFrame")
	rolagem.Size = UDim2.new(1, -10, 1, -10)
	rolagem.Position = UDim2.new(0, 5, 0, 5)
	rolagem.BackgroundTransparency = 1
	rolagem.BorderSizePixel = 0
	rolagem.ScrollBarThickness = 5
	rolagem.ScrollBarImageColor3 = corMoldura
	rolagem.CanvasSize = UDim2.new()
	rolagem.AutomaticCanvasSize = Enum.AutomaticSize.Y
	rolagem.Parent = moldura

	local corpo = Instance.new("TextLabel")
	corpo.Size = UDim2.new(1, -8, 0, 0)
	corpo.AutomaticSize = Enum.AutomaticSize.Y
	corpo.BackgroundTransparency = 1
	corpo.TextColor3 = COLORS.ink
	corpo.TextSize = escalaPorTela(16, 13, 19)
	corpo.TextWrapped = true
	corpo.RichText = false
	corpo.Font = Enum.Font.Code
	corpo.TextXAlignment = Enum.TextXAlignment.Left
	corpo.TextYAlignment = Enum.TextYAlignment.Top
	corpo.Text = ""
	corpo.Parent = rolagem

	return moldura, corpo
end

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
	local f = isMenuOpen and systemGui:FindFirstChild("RefreshCategory", true) or nil
	if f and f:IsA("BindableFunction") then
		pcall(function()
			f:Invoke()
		end)
	end
	local g = isInvOpen and systemGui:FindFirstChild("RefreshInventory", true) or nil
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

-- =====================================
-- (V13) PAINEL DO DESPERTAR
-- =====================================
-- Imagem, estado, HP, habilidades e história da forma desperta. Não tem
-- botão de equipar de propósito: o Despertar é conquistado em combate
-- pela barra, não escolhido no menu. Este painel mostra o que existe e
-- o que falta para liberar.
--
-- (V13) O V12 desenhava tudo de uma vez e lia a história com TextScaled.
-- Agora as seções entram escalonadas, a história é digitada, a moldura
-- pulsa em magenta enquanto está bloqueada e a lista de habilidades
-- entra linha a linha.
local function createAwakeningPopup(characterName, info)
	playSound(sounds.info)

	local aw = (info and info.awakening) or {}
	local nomeDesperto = aw.displayName or (characterName .. " (Despertado)")
	local _, toolsDespertas = collectCharacterTools(characterName)
	local liberado = info and info.liberado

	local modal = criarModal(isMobile and 0.94 or 0.6, isMobile and 0.9 or 0.84, COLORS.magenta)
	local context = modal.context
	local painel = modal.painel

	criarCabecalhoModal(modal, "⚡ " .. nomeDesperto:upper(), COLORS.magenta, COLORS.background)

	-- A moldura respira enquanto o Despertar está trancado e fica parada
	-- quando está liberado. É o estado do personagem virando movimento:
	-- de longe já dá para saber sem ler o selo.
	if not liberado then
		local contorno = Instance.new("UIStroke")
		contorno.Color = COLORS.magenta
		contorno.Thickness = 3
		contorno.Parent = painel
		tocarTween(
			context,
			"contornoPainel",
			contorno,
			TweenInfo.new(1.3, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
			{ Transparency = 0.7 }
		)
	end

	-- RETRATO DA FORMA DESPERTA
	local retrato = Instance.new("Frame")
	retrato.Size = UDim2.new(0.3, 0, 0.26, 0)
	retrato.Position = UDim2.new(0.04, 0, 0.15, 0)
	retrato.BackgroundColor3 = COLORS.panelRaised
	retrato.BorderColor3 = COLORS.magenta
	retrato.BorderSizePixel = 2
	retrato.ClipsDescendants = true
	retrato.Parent = painel

	local retratoProporcao = Instance.new("UIAspectRatioConstraint")
	retratoProporcao.AspectRatio = 1
	retratoProporcao.DominantAxis = Enum.DominantAxis.Height
	retratoProporcao.Parent = retrato

	local imageId = tonumber(aw.imageId) or 0
	if imageId > 0 then
		local img = Instance.new("ImageLabel")
		img.Size = UDim2.new(1, 0, 1, 0)
		img.BackgroundTransparency = 1
		img.Image = "rbxassetid://" .. tostring(imageId)
		img.ScaleType = Enum.ScaleType.Fit
		img.ImageTransparency = 1
		img.Parent = retrato
		tocarTween(
			context,
			"retratoFade",
			img,
			TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, 0.1),
			{ ImageTransparency = liberado and 0 or 0.45 }
		)
	else
		local semImg = Instance.new("TextLabel")
		semImg.Size = UDim2.new(1, 0, 1, 0)
		semImg.BackgroundTransparency = 1
		semImg.Text = "SEM\nIMAGEM"
		semImg.TextColor3 = COLORS.muted
		semImg.TextScaled = true
		semImg.Font = Enum.Font.Arcade
		semImg.Parent = retrato
	end

	entrarEmSequencia(context, retrato, "retrato", 0, { BackgroundTransparency = 0 })

	-- ESTADO
	local estado = Instance.new("TextLabel")
	estado.Size = UDim2.new(0.54, 0, 0.07, 0)
	estado.Position = UDim2.new(0.38, 0, 0.16, 0)
	estado.BackgroundTransparency = 1
	estado.TextScaled = true
	estado.TextWrapped = true
	estado.Font = Enum.Font.Arcade
	estado.TextXAlignment = Enum.TextXAlignment.Left
	estado.Parent = painel
	limitarTexto(estado, 10, 22)

	if liberado then
		estado.Text = "✅ LIBERADO"
		estado.TextColor3 = COLORS.green
	elseif info and not info.hasOriginal then
		estado.Text = "🔒 PRECISA DO ORIGINAL"
		estado.TextColor3 = COLORS.red
	else
		estado.Text = "🔒 FALTA O EMBLEMA"
		estado.TextColor3 = COLORS.yellow
	end
	entrarEmSequencia(context, estado, "estado", 1, { TextTransparency = 0 })

	local hp = Instance.new("TextLabel")
	hp.Size = UDim2.new(0.54, 0, 0.06, 0)
	hp.Position = UDim2.new(0.38, 0, 0.245, 0)
	hp.BackgroundTransparency = 1
	hp.Text = "❤️ HP: " .. tostring(aw.health or "—")
	hp.TextColor3 = COLORS.ink
	hp.TextScaled = true
	hp.Font = Enum.Font.Code
	hp.TextXAlignment = Enum.TextXAlignment.Left
	hp.Parent = painel
	limitarTexto(hp, 9, 18)
	entrarEmSequencia(context, hp, "hp", 2, { TextTransparency = 0 })

	local como = Instance.new("TextLabel")
	como.Size = UDim2.new(0.54, 0, 0.09, 0)
	como.Position = UDim2.new(0.38, 0, 0.315, 0)
	como.BackgroundTransparency = 1
	como.Text = aw.duracao and string.format("Enche em combate • dura %ds", aw.duracao)
		or "Enche em combate"
	como.TextColor3 = COLORS.muted
	como.TextScaled = true
	como.TextWrapped = true
	como.Font = Enum.Font.Code
	como.TextXAlignment = Enum.TextXAlignment.Left
	como.Parent = painel
	limitarTexto(como, 8, 15)
	entrarEmSequencia(context, como, "como", 3, { TextTransparency = 0 })

	-- HABILIDADES
	local toolsTitulo = Instance.new("TextLabel")
	toolsTitulo.Size = UDim2.new(0.92, 0, 0.055, 0)
	toolsTitulo.Position = UDim2.new(0.04, 0, 0.44, 0)
	toolsTitulo.BackgroundTransparency = 1
	toolsTitulo.Text = string.format("⚔️ HABILIDADES DESPERTAS (%d)", #toolsDespertas)
	toolsTitulo.TextColor3 = COLORS.yellow
	toolsTitulo.TextScaled = true
	toolsTitulo.Font = Enum.Font.Arcade
	toolsTitulo.TextXAlignment = Enum.TextXAlignment.Left
	toolsTitulo.Parent = painel
	limitarTexto(toolsTitulo, 10, 20)
	entrarEmSequencia(context, toolsTitulo, "toolsTitulo", 4, { TextTransparency = 0 })

	local toolsMoldura = Instance.new("Frame")
	toolsMoldura.Size = UDim2.new(0.92, 0, 0.17, 0)
	toolsMoldura.Position = UDim2.new(0.04, 0, 0.5, 0)
	toolsMoldura.BackgroundColor3 = COLORS.panelRaised
	toolsMoldura.BorderColor3 = Color3.fromRGB(120, 60, 160)
	toolsMoldura.BorderSizePixel = 2
	toolsMoldura.Parent = painel

	local toolsCanto = Instance.new("UICorner")
	toolsCanto.CornerRadius = UDim.new(0.08, 0)
	toolsCanto.Parent = toolsMoldura

	local toolsScroll = Instance.new("ScrollingFrame")
	toolsScroll.Size = UDim2.new(1, -10, 1, -10)
	toolsScroll.Position = UDim2.new(0, 5, 0, 5)
	toolsScroll.BackgroundTransparency = 1
	toolsScroll.BorderSizePixel = 0
	toolsScroll.ScrollBarThickness = 5
	toolsScroll.ScrollBarImageColor3 = COLORS.magenta
	-- O V12 calculava CanvasSize à mão com #tools * 26 + 6, número que
	-- só valia para a altura de linha daquele momento. AutomaticCanvasSize
	-- mede o conteúdo de verdade.
	toolsScroll.CanvasSize = UDim2.new()
	toolsScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	toolsScroll.Parent = toolsMoldura

	local listaLayout = Instance.new("UIListLayout")
	listaLayout.Padding = UDim.new(0, 3)
	listaLayout.SortOrder = Enum.SortOrder.LayoutOrder
	listaLayout.Parent = toolsScroll

	entrarEmSequencia(context, toolsMoldura, "toolsMoldura", 5, { BackgroundTransparency = 0 })

	local alturaLinha = escalaPorTela(24, 18, 32)

	if #toolsDespertas == 0 then
		local vazio = Instance.new("TextLabel")
		vazio.Size = UDim2.new(1, -8, 0, alturaLinha)
		vazio.BackgroundTransparency = 1
		vazio.Text = "Nenhuma Tool carregada nesta forma."
		vazio.TextColor3 = COLORS.muted
		vazio.TextScaled = true
		vazio.Font = Enum.Font.Code
		vazio.Parent = toolsScroll
		limitarTexto(vazio, 9, 16)
	else
		for i, nome in ipairs(toolsDespertas) do
			local linha = Instance.new("TextLabel")
			linha.Size = UDim2.new(1, -8, 0, alturaLinha)
			linha.LayoutOrder = i
			linha.BackgroundTransparency = 1
			linha.Text = string.format("  %d. %s", i, nome)
			linha.TextColor3 = Color3.fromRGB(230, 210, 255)
			linha.TextTransparency = 1
			linha.TextScaled = true
			linha.Font = Enum.Font.Code
			linha.TextXAlignment = Enum.TextXAlignment.Left
			linha.Parent = toolsScroll
			limitarTexto(linha, 9, 17)

			-- Cada linha aparece um pouco depois da anterior. O atraso é
			-- do TweenInfo; a lista pode ter 20 itens sem virar 20 threads.
			tocarTween(
				context,
				"linhaTool" .. i,
				linha,
				TweenInfo.new(
					0.3,
					Enum.EasingStyle.Quad,
					Enum.EasingDirection.Out,
					0,
					false,
					0.36 + math.min(i * 0.05, 0.5)
				),
				{ TextTransparency = 0 }
			)
		end
	end

	-- HISTÓRIA, digitada
	local historiaTitulo = Instance.new("TextLabel")
	historiaTitulo.Size = UDim2.new(0.92, 0, 0.05, 0)
	historiaTitulo.Position = UDim2.new(0.04, 0, 0.69, 0)
	historiaTitulo.BackgroundTransparency = 1
	historiaTitulo.Text = "📖 HISTÓRIA"
	historiaTitulo.TextColor3 = COLORS.cyan
	historiaTitulo.TextScaled = true
	historiaTitulo.Font = Enum.Font.Arcade
	historiaTitulo.TextXAlignment = Enum.TextXAlignment.Left
	historiaTitulo.Parent = painel
	limitarTexto(historiaTitulo, 10, 20)
	entrarEmSequencia(context, historiaTitulo, "historiaTitulo", 6, { TextTransparency = 0 })

	local historiaTexto = (aw.lore ~= nil and aw.lore ~= "" and aw.lore)
		or (aw.description ~= nil and aw.description ~= "" and aw.description)
		or "Sem história cadastrada para esta forma."

	local historiaMoldura, historiaCorpo = criarAreaDeTexto(
		painel,
		UDim2.new(0.04, 0, 0.745, 0),
		UDim2.new(0.92, 0, 0.2, 0),
		COLORS.cyan
	)
	entrarEmSequencia(context, historiaMoldura, "historiaMoldura", 7, { BackgroundTransparency = 0 })

	local maquina = maquinaDeEscrever(context, "historia", historiaCorpo, historiaTexto, 62, 0.5)

	local pular = Instance.new("TextButton")
	pular.Size = UDim2.new(1, 0, 1, 0)
	pular.BackgroundTransparency = 1
	pular.Text = ""
	pular.ZIndex = 5
	pular.Parent = historiaMoldura

	conectarContexto(context, pular.MouseButton1Click, function()
		if not maquina.terminou() then
			maquina.completar()
		end
	end)
end

-- =====================================
-- (V13) PAINEL DE LORE
-- =====================================
-- O que havia antes: uma caixa que nascia pronta, sem imagem do
-- personagem, sem raridade, e com a lore inteira num TextLabel
-- TextScaled — ou seja, quanto mais história o personagem tivesse,
-- menor a fonte, até virar letra miúda. Nenhum tween, nenhum scroll.
local function createLorePopup(characterName)
	playSound(sounds.info)

	local def = getCatalogDef(characterName)
	local loreString = (def and def.lore ~= nil and def.lore ~= "" and def.lore)
		or (def and def.description ~= nil and def.description ~= "" and def.description)
		or "Sem lore cadastrada."

	local raridade = def and def.rarity
	local infoRaridade = raridade and rarities[raridade]
	local corRaridade = (infoRaridade and infoRaridade.color) or COLORS.yellow

	local modal = criarModal(isMobile and 0.94 or 0.62, isMobile and 0.82 or 0.74, corRaridade)
	local context = modal.context
	local painel = modal.painel

	criarCabecalhoModal(modal, "📖 " .. characterName:upper(), corRaridade, COLORS.background)

	-- RETRATO. A lore ganhou a cara do personagem: ler a história de
	-- alguém sem ver quem é foi sempre o pior detalhe deste painel.
	local retrato = Instance.new("Frame")
	retrato.Size = UDim2.new(0.3, 0, 0.3, 0)
	retrato.Position = UDim2.new(0.04, 0, 0.16, 0)
	retrato.BackgroundColor3 = COLORS.panelRaised
	retrato.BorderColor3 = corRaridade
	retrato.BorderSizePixel = 2
	retrato.Parent = painel

	local retratoProporcao = Instance.new("UIAspectRatioConstraint")
	retratoProporcao.AspectRatio = 1
	retratoProporcao.DominantAxis = Enum.DominantAxis.Height
	retratoProporcao.Parent = retrato

	createCharacterImage(characterName, retrato)
	entrarEmSequencia(context, retrato, "retrato", 0, { BackgroundTransparency = 0 })

	-- SELO DE RARIDADE, pulsando devagar num tween só.
	local selo = Instance.new("TextLabel")
	selo.Size = UDim2.new(0.5, 0, 0.07, 0)
	selo.Position = UDim2.new(0.4, 0, 0.17, 0)
	selo.BackgroundColor3 = corRaridade
	selo.BorderSizePixel = 0
	selo.Text = string.format(
		"%s  %s",
		RARITY_EMBLEMS[raridade or ""] or "•",
		raridade or "SEM RARIDADE"
	)
	selo.TextColor3 = COLORS.background
	selo.TextScaled = true
	selo.Font = Enum.Font.Arcade
	selo.Parent = painel
	limitarTexto(selo, 10, 20)

	local seloCanto = Instance.new("UICorner")
	seloCanto.CornerRadius = UDim.new(0.3, 0)
	seloCanto.Parent = selo

	entrarEmSequencia(context, selo, "selo", 1, { TextTransparency = 0 })

	if infoRaridade and infoRaridade.glow then
		-- (V14.1) Border, não Contextual. O comentário acima promete um
		-- brilho em volta do selo, mas sem declarar o modo o traço ia nas
		-- letras — franja colorida no texto escuro, não glow na caixa.
		local seloBrilho = Instance.new("UIStroke")
		seloBrilho.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		seloBrilho.Color = corRaridade
		seloBrilho.Thickness = 2
		seloBrilho.Parent = selo
		tocarTween(
			context,
			"brilhoSelo",
			seloBrilho,
			TweenInfo.new(1.1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
			{ Transparency = 0.75 }
		)
	end

	local dica = Instance.new("TextLabel")
	dica.Size = UDim2.new(0.5, 0, 0.055, 0)
	dica.Position = UDim2.new(0.4, 0, 0.27, 0)
	dica.BackgroundTransparency = 1
	dica.Text = "toque no texto para revelar tudo"
	dica.TextColor3 = COLORS.muted
	dica.TextScaled = true
	dica.Font = Enum.Font.Code
	dica.TextXAlignment = Enum.TextXAlignment.Left
	dica.Parent = painel
	limitarTexto(dica, 8, 14)
	entrarEmSequencia(context, dica, "dica", 2, { TextTransparency = 0 })

	-- CORPO DA LORE
	local moldura, corpo = criarAreaDeTexto(
		painel,
		UDim2.new(0.04, 0, 0.5, 0),
		UDim2.new(0.92, 0, 0.44, 0),
		corRaridade
	)
	entrarEmSequencia(context, moldura, "moldura", 3, { BackgroundTransparency = 0 })

	-- A digitação começa depois de a moldura assentar; a espera é
	-- contada dentro da própria máquina, no mesmo contexto do painel.
	local maquina = maquinaDeEscrever(context, "lore", corpo, loreString, 60, 0.34)

	-- Tocar no texto pula a digitação. Quem já leu não fica esperando a
	-- máquina terminar, e quem só quer conferir a raridade também não.
	local pular = Instance.new("TextButton")
	pular.Size = UDim2.new(1, 0, 1, 0)
	pular.BackgroundTransparency = 1
	pular.Text = ""
	pular.ZIndex = 5
	pular.Parent = moldura

	conectarContexto(context, pular.MouseButton1Click, function()
		if not maquina.terminou() then
			maquina.completar()
			dica.Text = ""
		else
			-- Segundo toque fecha: o painel de lore é de leitura, então
			-- depois de revelado não há mais nada para fazer nele.
			modal.fechar()
		end
	end)
end

-- =====================================
-- (V14) DETALHES UNIFICADOS E ANIMADOS
-- =====================================
-- As implementações V12 acima ficam como histórico da evolução do arquivo.
-- A partir daqui, os pontos de entrada abrem o MESMO modal com cinco abas.
-- Informações, Lore, Habilidades, Atributos e Despertar compartilham tamanho,
-- mola, navegação, limpeza de conexões e linguagem visual.

local activeDetailsGui = nil
local activeDetailsContext = nil
local activeDetailsRenderContext = nil
local activeDetailsOpenGeneration = 0

local DETAIL_TABS = {
	{ key = "INFO", icon = "◈", label = "INFORMAÇÕES", shortLabel = "INFO", color = COLORS.cyan },
	{ key = "LORE", icon = "📖", label = "LORE", shortLabel = "LORE", color = COLORS.yellow },
	{ key = "ABILITIES", icon = "⚔", label = "HABILIDADES", shortLabel = "HABIL.", color = COLORS.green },
	{ key = "STATS", icon = "▥", label = "ATRIBUTOS", shortLabel = "ATRIB.", color = COLORS.orange },
	{ key = "AWAKENING", icon = "⚡", label = "DESPERTAR", shortLabel = "DESP.", color = COLORS.magenta },
}

local DETAIL_STAT_LABELS = {
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

local DETAIL_FLAT_STATS = {
	HPFlat = true,
	DefenseFlat = true,
	WalkSpeedFlat = true,
	JumpFlat = true,
	Shield = true,
}

local DETAIL_ABILITY_FIELDS = {
	{ keys = { "Damage", "BaseDamage", "Dano" }, label = "DANO" },
	{ keys = { "Cooldown", "Recarga" }, label = "RECARGA", seconds = true },
	{ keys = { "EnergyCost", "Energy", "CustoEnergia" }, label = "ENERGIA" },
	{ keys = { "StaminaCost", "Stamina", "CustoStamina" }, label = "STAMINA" },
	{ keys = { "Range", "Alcance" }, label = "ALCANCE" },
	{ keys = { "Duration", "Duracao" }, label = "DURAÇÃO", seconds = true },
	{ keys = { "Keybind", "Key", "Tecla" }, label = "TECLA" },
}

local function readAbilityValue(tool, keys)
	local attributes = tool:GetAttributes()
	for _, key in ipairs(keys) do
		local value = attributes[key]
		if value ~= nil then
			return value
		end
		local child = tool:FindFirstChild(key)
		if child
			and (
				child:IsA("StringValue")
				or child:IsA("NumberValue")
				or child:IsA("IntValue")
				or child:IsA("BoolValue")
			)
		then
			return child.Value
		end
	end
	return nil
end

local function formatAbilityValue(value, seconds)
	if type(value) == "number" then
		local rounded = math.floor(value)
		local shown = math.abs(value - rounded) < 0.001 and tostring(rounded)
			or string.format("%.1f", value)
		return seconds and (shown .. "s") or shown
	elseif type(value) == "boolean" then
		return value and "SIM" or "NÃO"
	elseif type(value) == "string" and value ~= "" then
		return value
	end
	return nil
end

local function getAbilityDetails(tool)
	local description = tool.ToolTip ~= "" and tool.ToolTip or nil
	if not description then
		local value = readAbilityValue(tool, { "Description", "Descricao" })
		description = type(value) == "string" and value ~= "" and value or nil
	end

	local metrics = {}
	for _, field in ipairs(DETAIL_ABILITY_FIELDS) do
		local shown = formatAbilityValue(readAbilityValue(tool, field.keys), field.seconds)
		if shown then
			table.insert(metrics, field.label .. ": " .. shown)
		end
	end

	return description, metrics
end

local function collectCharacterAbilityDetails(characterName)
	local normalAbilities = {}
	local awakenedAbilities = {}
	local charactersFolder = ReplicatedStorage:FindFirstChild("Characters")
	local characterFolder = charactersFolder and charactersFolder:FindFirstChild(characterName)
	if not characterFolder then
		return normalAbilities, awakenedAbilities
	end

	local function appendTools(folder, target)
		if not folder then
			return
		end
		for _, item in ipairs(folder:GetChildren()) do
			if item:IsA("Tool") then
				local description, metrics = getAbilityDetails(item)
				table.insert(target, {
					name = item.Name,
					description = description,
					metrics = metrics,
				})
			end
		end
		table.sort(target, function(a, b)
			return string.lower(a.name) < string.lower(b.name)
		end)
	end

	appendTools(characterFolder, normalAbilities)
	appendTools(characterFolder:FindFirstChild("AwakenedForm"), awakenedAbilities)
	return normalAbilities, awakenedAbilities
end

local function getDetailLayout()
	local viewport = getViewportSize()
	local portrait = viewport.Y > viewport.X
	local width
	local height

	if isMobile then
		width = portrait and 0.94 or 0.86
		height = portrait and 0.84 or 0.88
	else
		width = portrait and 0.82 or 0.66
		height = portrait and 0.8 or 0.82
	end

	return {
		portrait = portrait,
		size = UDim2.fromScale(width, height),
		aspect = (viewport.X * width) / math.max(1, viewport.Y * height),
		contentHeight = math.max(260, viewport.Y * height * 0.765),
	}
end

local function createDetailSection(parent, context, order, height, accent, title)
	local sectionHeight = math.max(44, math.floor(getDetailLayout().contentHeight * height))
	local section = Instance.new("Frame")
	section.Name = "Section_" .. tostring(order)
	section.Size = UDim2.new(1, 0, 0, sectionHeight)
	section.BackgroundColor3 = COLORS.panelRaised
	section.BackgroundTransparency = 0.46
	section.BorderSizePixel = 0
	section.LayoutOrder = order
	section.Parent = parent

	local stroke = Instance.new("UIStroke")
	stroke.Color = accent
	stroke.Thickness = 2
	stroke.Transparency = 0.38
	stroke.Parent = section

	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, COLORS.panelRaised:Lerp(accent, 0.13)),
		ColorSequenceKeypoint.new(1, COLORS.background),
	})
	gradient.Rotation = 90
	gradient.Parent = section

	local scale = Instance.new("UIScale")
	scale.Scale = 0.84
	scale.Parent = section
	tocarTween(
		context,
		scale,
		scale,
		TweenInfo.new(
			0.34,
			Enum.EasingStyle.Back,
			Enum.EasingDirection.Out,
			0,
			false,
			math.min((order - 1) * 0.045, 0.27)
		),
		{ Scale = 1 }
	)

	if title and title ~= "" then
		local titleLabel = Instance.new("TextLabel")
		titleLabel.Position = UDim2.fromScale(0.025, 0.035)
		titleLabel.Size = UDim2.fromScale(0.95, 0.17)
		titleLabel.BackgroundTransparency = 1
		titleLabel.Text = title
		titleLabel.TextColor3 = accent
		titleLabel.TextScaled = true
		titleLabel.Font = Enum.Font.Arcade
		titleLabel.TextXAlignment = Enum.TextXAlignment.Left
		titleLabel.Parent = section
		limitarTexto(titleLabel, 9, 20)
	end

	return section
end

local function animateTypedText(context, label, fullText, skipButton, delay)
	fullText = tostring(fullText or "")
	label.Text = fullText
	label.MaxVisibleGraphemes = 0
	local total = utf8.len(fullText) or #fullText
	local visible = 0
	-- O atraso é dado em segundos; o acumulador trabalha em grafemas.
	local accumulator = -(delay or 0) * 72
	local finished = false
	local heartbeatConnection = nil

	local function finish()
		if finished then
			return
		end
		finished = true
		label.MaxVisibleGraphemes = -1
		if skipButton and skipButton.Parent then
			skipButton.Text = "✓ TEXTO COMPLETO"
			skipButton.TextColor3 = COLORS.green
		end
		if heartbeatConnection then
			heartbeatConnection:Disconnect()
			heartbeatConnection = nil
		end
	end

	if total == 0 then
		finish()
		return finish
	end

	heartbeatConnection = conectarContexto(context, RunService.Heartbeat, function(deltaTime)
		if finished or not label.Parent then
			finish()
			return
		end
		accumulator += deltaTime * 72
		if accumulator < 0 then
			return
		end
		local nextVisible = math.min(total, math.floor(accumulator))
		if nextVisible ~= visible then
			visible = nextVisible
			label.MaxVisibleGraphemes = visible
		end
		if visible >= total then
			finish()
		end
	end)

	if skipButton then
		conectarContexto(context, skipButton.Activated, finish)
	end

	return finish
end

local function createTypedSection(parent, context, order, height, accent, title, text)
	local fullText = tostring(text or "")
	local textLength = utf8.len(fullText) or #fullText
	local portrait = getDetailLayout().portrait
	local charactersPerSection = portrait and 1050 or 1450
	local adaptiveHeight = math.clamp(0.2 + textLength / charactersPerSection, height, 1.3)
	local section = createDetailSection(parent, context, order, adaptiveHeight, accent, title)

	local skipButton = Instance.new("TextButton")
	skipButton.Name = "ShowFullText"
	skipButton.AnchorPoint = Vector2.new(1, 0)
	skipButton.Position = UDim2.fromScale(0.97, 0.035)
	skipButton.Size = UDim2.fromScale(0.28, 0.15)
	skipButton.BackgroundColor3 = COLORS.background
	skipButton.BorderSizePixel = 0
	skipButton.Text = "» MOSTRAR TUDO"
	skipButton.TextColor3 = accent
	skipButton.TextScaled = true
	skipButton.Font = Enum.Font.Arcade
	skipButton.Parent = section
	limitarTexto(skipButton, 8, 14)
	prepararBotaoAnimado(context, skipButton)

	local textLabel = Instance.new("TextLabel")
	textLabel.Position = UDim2.fromScale(0.03, 0.23)
	textLabel.Size = UDim2.fromScale(0.94, 0.72)
	textLabel.BackgroundTransparency = 1
	textLabel.Text = ""
	textLabel.TextColor3 = COLORS.ink
	textLabel.TextScaled = true
	textLabel.TextWrapped = true
	textLabel.Font = Enum.Font.Code
	textLabel.TextXAlignment = Enum.TextXAlignment.Left
	textLabel.TextYAlignment = Enum.TextYAlignment.Top
	textLabel.Parent = section
	limitarTexto(textLabel, 11, 21)

	animateTypedText(context, textLabel, fullText, skipButton, math.min(order * 0.045, 0.22))
	return section
end

local function createDetailRow(parent, context, order, icon, text, color)
	local row = createDetailSection(parent, context, order, 0.095, color, nil)
	local label = Instance.new("TextLabel")
	label.Position = UDim2.fromScale(0.025, 0.12)
	label.Size = UDim2.fromScale(0.95, 0.76)
	label.BackgroundTransparency = 1
	label.Text = icon .. "  " .. text
	label.TextColor3 = color
	label.TextScaled = true
	label.TextWrapped = true
	label.Font = Enum.Font.Code
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = row
	limitarTexto(label, 10, 18)
	return row
end

local function createAbilityCard(parent, context, order, ability, awakened)
	local accent = awakened and COLORS.magenta or COLORS.green
	local icon = awakened and "⚡" or "⚔"
	local detailParts = {}
	if ability.description then
		table.insert(detailParts, ability.description)
	end
	if #ability.metrics > 0 then
		table.insert(detailParts, table.concat(ability.metrics, "  •  "))
	end
	local details = table.concat(detailParts, "\n")
	if details == "" then
		details = "Tool carregada. Esta habilidade não publica descrição ou métricas adicionais."
	end

	local section = createDetailSection(
		parent,
		context,
		order,
		#detailParts > 0 and 0.17 or 0.12,
		accent,
		icon .. " " .. ability.name:upper()
	)
	local detailLabel = Instance.new("TextLabel")
	detailLabel.Position = UDim2.fromScale(0.03, 0.27)
	detailLabel.Size = UDim2.fromScale(0.94, 0.65)
	detailLabel.BackgroundTransparency = 1
	detailLabel.Text = details
	detailLabel.TextColor3 = awakened and COLORS.magenta:Lerp(COLORS.white, 0.42) or COLORS.ink
	detailLabel.TextScaled = true
	detailLabel.TextWrapped = true
	detailLabel.Font = Enum.Font.Code
	detailLabel.TextXAlignment = Enum.TextXAlignment.Left
	detailLabel.TextYAlignment = Enum.TextYAlignment.Top
	detailLabel.Parent = section
	limitarTexto(detailLabel, 9, 17)
	return section
end

local function loadDetailStats(characterName)
	if not getCharacterStatsInfo then
		return nil, {}, "INDISPONÍVEL"
	end
	local ok, statsInfo = pcall(function()
		return getCharacterStatsInfo:InvokeServer(characterName)
	end)
	if not ok or type(statsInfo) ~= "table" then
		return nil, {}, "INDISPONÍVEL"
	end

	local archetypeName = "EQUILIBRADO"
	if type(statsInfo.archetypes) == "table" then
		for _, archetype in ipairs(statsInfo.archetypes) do
			if archetype.id == statsInfo.archetype then
				archetypeName = (archetype.icon or "◆") .. " " .. (archetype.name or archetype.id)
				break
			end
		end
	end

	local lines = {}
	if type(statsInfo.finalStats) == "table" then
		for name, value in pairs(statsInfo.finalStats) do
			if type(value) == "number" and value ~= 0 then
				local shown = DETAIL_FLAT_STATS[name] and string.format("%+d", math.floor(value))
					or string.format("%+.0f%%", value * 100)
				table.insert(lines, {
					text = (DETAIL_STAT_LABELS[name] or name) .. ": " .. shown,
					positive = value > 0,
				})
			end
		end
		table.sort(lines, function(a, b)
			return a.text < b.text
		end)
	end

	return statsInfo, lines, archetypeName
end

local function createCharacterDetailsPopup(characterName, initialTab, suppliedAwakeningInfo)
	activeDetailsOpenGeneration += 1
	local openGeneration = activeDetailsOpenGeneration
	playSound(sounds.info)

	if activeDetailsGui then
		limparContexto(activeDetailsRenderContext)
		limparContexto(activeDetailsContext)
		activeDetailsGui.Parent = nil
		activeDetailsGui = nil
		activeDetailsContext = nil
		activeDetailsRenderContext = nil
	end

	local def = getCatalogDef(characterName) or {
		name = characterName,
		description = "Sem descrição cadastrada.",
		lore = "Sem lore cadastrada.",
		health = 100,
		rarity = "ROBLOXIANOS",
		category = "Especial",
	}
	local _, toolsDespertas = collectCharacterTools(characterName)
	local normalAbilities, awakenedAbilities = collectCharacterAbilityDetails(characterName)
	local statsInfo, statLines, archetypeName = loadDetailStats(characterName)
	if openGeneration ~= activeDetailsOpenGeneration then
		return
	end
	local awakeningInfo = suppliedAwakeningInfo
	local awakeningLoaded = suppliedAwakeningInfo ~= nil
	local awakeningLoading = false
	local selectedTab = initialTab or "INFO"
	local closing = false

	activeDetailsContext = novoContexto()
	activeDetailsRenderContext = nil
	local context = activeDetailsContext

	local infoGui = Instance.new("ScreenGui")
	infoGui.Name = "CharacterDetailsV14"
	infoGui.DisplayOrder = 160
	infoGui.ResetOnSpawn = false
	infoGui.IgnoreGuiInset = true
	infoGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	infoGui.Parent = playerGui
	activeDetailsGui = infoGui

	local backdropButton = Instance.new("TextButton")
	backdropButton.Name = "Backdrop"
	backdropButton.Size = UDim2.fromScale(1, 1)
	backdropButton.BackgroundColor3 = Color3.fromRGB(0, 2, 8)
	backdropButton.BackgroundTransparency = 1
	backdropButton.BorderSizePixel = 0
	backdropButton.Text = ""
	backdropButton.AutoButtonColor = false
	backdropButton.ZIndex = 1
	backdropButton.Parent = infoGui

	local detailLayout = getDetailLayout()
	local popup = Instance.new("Frame")
	popup.Name = "DetailsPanel"
	popup.Size = detailLayout.size
	popup.Position = UDim2.fromScale(0.5, 0.5)
	popup.AnchorPoint = Vector2.new(0.5, 0.5)
	popup.BackgroundColor3 = COLORS.background
	popup.BorderSizePixel = 0
	popup.ClipsDescendants = true
	popup.ZIndex = 10
	popup.Parent = infoGui

	local popupAspect = Instance.new("UIAspectRatioConstraint")
	popupAspect.AspectRatio = detailLayout.aspect
	popupAspect.DominantAxis = detailLayout.portrait and Enum.DominantAxis.Width
		or Enum.DominantAxis.Height
	popupAspect.Parent = popup

	local popupStroke = Instance.new("UIStroke")
	popupStroke.Color = COLORS.white
	popupStroke.Thickness = 4
	popupStroke.Parent = popup

	local popupGradient = Instance.new("UIGradient")
	popupGradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(24, 30, 45)),
		ColorSequenceKeypoint.new(0.52, COLORS.background),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(2, 7, 14)),
	})
	popupGradient.Rotation = 90
	popupGradient.Parent = popup

	local panelMotion = criarMolaPainel(context, popup, function()
		limparContexto(activeDetailsRenderContext)
		limparContexto(context)
		if infoGui.Parent then
			infoGui.Parent = nil
		end
		if activeDetailsGui == infoGui then
			activeDetailsGui = nil
			activeDetailsContext = nil
			activeDetailsRenderContext = nil
		end
	end)

	local header = Instance.new("Frame")
	header.Size = UDim2.fromScale(1, 0.105)
	header.BackgroundColor3 = COLORS.panelRaised
	header.BorderSizePixel = 0
	header.ZIndex = 12
	header.Parent = popup

	local headerLine = Instance.new("Frame")
	headerLine.AnchorPoint = Vector2.new(0, 1)
	headerLine.Position = UDim2.fromScale(0, 1)
	headerLine.Size = UDim2.fromScale(1, 0.055)
	headerLine.BackgroundColor3 = COLORS.cyan
	headerLine.BorderSizePixel = 0
	headerLine.ZIndex = 13
	headerLine.Parent = header

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Position = UDim2.fromScale(0.025, 0.06)
	titleLabel.Size = UDim2.fromScale(0.78, 0.84)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Text = "[ " .. characterName:upper() .. " ]"
	titleLabel.TextColor3 = COLORS.white
	titleLabel.TextScaled = true
	titleLabel.Font = Enum.Font.Arcade
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.ZIndex = 14
	titleLabel.Parent = header
	limitarTexto(titleLabel, 11, 27)

	local titleGradient = Instance.new("UIGradient")
	titleGradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, COLORS.cyan),
		ColorSequenceKeypoint.new(0.5, COLORS.white),
		ColorSequenceKeypoint.new(1, COLORS.magenta),
	})
	titleGradient.Offset = Vector2.new(-1, 0)
	titleGradient.Parent = titleLabel
	tocarTween(
		context,
		titleGradient,
		titleGradient,
		TweenInfo.new(2.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ Offset = Vector2.new(1, 0) }
	)

	local closeButton = Instance.new("TextButton")
	closeButton.Name = "CloseDetails"
	closeButton.Position = UDim2.fromScale(0.9, 0.15)
	closeButton.Size = UDim2.fromScale(0.07, 0.68)
	closeButton.BackgroundColor3 = COLORS.red
	closeButton.BorderSizePixel = 0
	closeButton.Text = "X"
	closeButton.TextColor3 = COLORS.white
	closeButton.TextScaled = true
	closeButton.Font = Enum.Font.Arcade
	closeButton.ZIndex = 15
	closeButton.Parent = header
	limitarTexto(closeButton, 12, 22)
	prepararBotaoAnimado(context, closeButton)

	local closeAspect = Instance.new("UIAspectRatioConstraint")
	closeAspect.AspectRatio = 1
	closeAspect.DominantAxis = detailLayout.portrait and Enum.DominantAxis.Width
		or Enum.DominantAxis.Height
	closeAspect.Parent = closeButton

	local tabsFrame = Instance.new("Frame")
	tabsFrame.Position = UDim2.fromScale(0, 0.105)
	tabsFrame.Size = UDim2.fromScale(1, 0.085)
	tabsFrame.BackgroundColor3 = COLORS.panel
	tabsFrame.BorderSizePixel = 0
	tabsFrame.ZIndex = 12
	tabsFrame.Parent = popup
	local tabsGrid = Instance.new("UIGridLayout")
	tabsGrid.CellPadding = UDim2.fromScale(0, 0)
	tabsGrid.CellSize = UDim2.fromScale(1 / #DETAIL_TABS, 1)
	tabsGrid.FillDirection = Enum.FillDirection.Horizontal
	tabsGrid.FillDirectionMaxCells = #DETAIL_TABS
	tabsGrid.HorizontalAlignment = Enum.HorizontalAlignment.Center
	tabsGrid.SortOrder = Enum.SortOrder.LayoutOrder
	tabsGrid.Parent = tabsFrame

	local content = Instance.new("ScrollingFrame")
	content.Name = "TabContent"
	content.Position = UDim2.fromScale(0.02, 0.21)
	content.Size = UDim2.fromScale(0.96, 0.765)
	content.BackgroundTransparency = 1
	content.BorderSizePixel = 0
	content.CanvasSize = UDim2.new()
	content.AutomaticCanvasSize = Enum.AutomaticSize.Y
	content.ScrollBarThickness = isMobile and 7 or 10
	content.ScrollBarImageColor3 = COLORS.cyan
	content.ScrollBarImageTransparency = 0.18
	content.ZIndex = 12
	content.Parent = popup

	local contentLayout = Instance.new("UIListLayout")
	contentLayout.Padding = UDim.new(0, math.floor(detailLayout.contentHeight * 0.018))
	contentLayout.SortOrder = Enum.SortOrder.LayoutOrder
	contentLayout.Parent = content

	local contentPadding = Instance.new("UIPadding")
	contentPadding.PaddingTop = UDim.new(0, 8)
	contentPadding.PaddingBottom = UDim.new(0, 20)
	contentPadding.PaddingLeft = UDim.new(0, 8)
	contentPadding.PaddingRight = UDim.new(0, 8)
	contentPadding.Parent = content

	local tabButtons = {}
	local renderSelectedTab
	local detailRenderGeneration = 0

	local function closeDetails()
		if closing then
			return
		end
		closing = true
		playSound(sounds.close)
		tocarTween(
			context,
			"details_backdrop",
			backdropButton,
			TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ BackgroundTransparency = 1 }
		)
		panelMotion.close()
	end

	local function addSummary(order)
		local rarityColor = rarities[def.rarity] and rarities[def.rarity].color or COLORS.muted
		local section = createDetailSection(
			content,
			activeDetailsRenderContext,
			order,
			0.18,
			rarityColor,
			"◆ VISÃO GERAL"
		)

		local summary = {
			{ "❤️ HP", tostring(def.health or 100), COLORS.green },
			{ "◆ RARIDADE", tostring(def.rarity or "—"), rarityColor },
			{ "◈ ORIGEM", (CATEGORY_META[def.category] and CATEGORY_META[def.category].label)
				or tostring(def.category or "ESPECIAL"), COLORS.cyan },
			{ "⚙ ARQUÉTIPO", archetypeName, COLORS.yellow },
		}
		for i, item in ipairs(summary) do
			local col = (i - 1) % 2
			local row = math.floor((i - 1) / 2)
			local label = Instance.new("TextLabel")
			label.Position = UDim2.fromScale(0.025 + col * 0.49, 0.27 + row * 0.34)
			label.Size = UDim2.fromScale(0.46, 0.28)
			label.BackgroundColor3 = COLORS.background
			label.BackgroundTransparency = 0.18
			label.BorderSizePixel = 0
			label.Text = item[1] .. ":  " .. item[2]
			label.TextColor3 = item[3]
			label.TextScaled = true
			label.TextWrapped = true
			label.Font = Enum.Font.Code
			label.Parent = section
			limitarTexto(label, 9, 17)
		end
	end

	local function renderInfo()
		local order = 1
		addSummary(order)
		order += 1

		createTypedSection(
			content,
			activeDetailsRenderContext,
			order,
			0.27,
			COLORS.cyan,
			"▣ DESCRIÇÃO",
			(def.description ~= nil and def.description ~= "" and def.description)
				or "Sem descrição cadastrada."
		)
	end

	local function renderAbilities()
		local order = 1
		local total = #normalAbilities + #awakenedAbilities
		createDetailRow(
			content,
			activeDetailsRenderContext,
			order,
			"⚔",
			string.format("HABILIDADES CARREGADAS (%d)", total),
			COLORS.green
		)
		order += 1

		if total == 0 then
			createTypedSection(
				content,
				activeDetailsRenderContext,
				order,
				0.28,
				COLORS.muted,
				"◇ NENHUMA HABILIDADE REPLICADA",
				"Nenhuma Tool deste personagem foi carregada em ReplicatedStorage."
			)
			return
		end

		if #normalAbilities > 0 then
			createDetailRow(content, activeDetailsRenderContext, order, "◈", "FORMA NORMAL", COLORS.green)
			order += 1
			for _, ability in ipairs(normalAbilities) do
				createAbilityCard(content, activeDetailsRenderContext, order, ability, false)
				order += 1
			end
		end

		if #awakenedAbilities > 0 then
			createDetailRow(content, activeDetailsRenderContext, order, "⚡", "FORMA DESPERTA", COLORS.magenta)
			order += 1
			for _, ability in ipairs(awakenedAbilities) do
				createAbilityCard(content, activeDetailsRenderContext, order, ability, true)
				order += 1
			end
		end
	end

	local function renderStats()
		local order = 1
		createDetailRow(
			content,
			activeDetailsRenderContext,
			order,
			"❤️",
			"VIDA BASE: " .. tostring(def.health or 100),
			COLORS.green
		)
		order += 1
		createDetailRow(
			content,
			activeDetailsRenderContext,
			order,
			"⚙",
			"ARQUÉTIPO: " .. archetypeName,
			statsInfo and COLORS.orange or COLORS.muted
		)
		order += 1

		if statsInfo == nil then
			createTypedSection(
				content,
				activeDetailsRenderContext,
				order,
				0.3,
				COLORS.muted,
				"◇ SERVIÇO DE ATRIBUTOS INDISPONÍVEL",
				"O servidor não retornou os atributos deste personagem. Tente abrir esta aba novamente."
			)
			return
		end

		local archetypeDescription = nil
		if type(statsInfo.archetypes) == "table" then
			for _, archetype in ipairs(statsInfo.archetypes) do
				if archetype.id == statsInfo.archetype then
					archetypeDescription = archetype.desc
					break
				end
			end
		end
		if archetypeDescription and archetypeDescription ~= "" then
			createDetailRow(
				content,
				activeDetailsRenderContext,
				order,
				"▣",
				archetypeDescription,
				COLORS.orange
			)
			order += 1
		end

		if #statLines == 0 then
			createTypedSection(
				content,
				activeDetailsRenderContext,
				order,
				0.28,
				COLORS.cyan,
				"▥ SEM MODIFICADORES EXTRAS",
				"Este personagem usa os valores padrão e não possui bônus ou penalidades adicionais."
			)
			return
		end

		createDetailRow(content, activeDetailsRenderContext, order, "▥", "BÔNUS E PENALIDADES", COLORS.yellow)
		order += 1
		for _, line in ipairs(statLines) do
			createDetailRow(
				content,
				activeDetailsRenderContext,
				order,
				line.positive and "＋" or "－",
				line.text,
				line.positive and COLORS.green or COLORS.red
			)
			order += 1
		end
	end

	local function renderLore()
		local rarityColor = rarities[def.rarity] and rarities[def.rarity].color or COLORS.yellow
		local meta = CATEGORY_META[def.category]
		createDetailRow(
			content,
			activeDetailsRenderContext,
			1,
			RARITY_EMBLEMS[def.rarity] or "◆",
			string.format(
				"%s  •  %s",
				tostring(def.rarity or "SEM RARIDADE"),
				meta and meta.label or tostring(def.category or "ESPECIAL")
			),
			rarityColor
		)
		createTypedSection(
			content,
			activeDetailsRenderContext,
			2,
			0.62,
			COLORS.yellow,
			"📖 ARQUIVO DE LORE",
			(def.lore ~= nil and def.lore ~= "" and def.lore) or "Sem lore cadastrada."
		)
		createTypedSection(
			content,
			activeDetailsRenderContext,
			3,
			0.28,
			COLORS.cyan,
			"▣ RESUMO DO PERSONAGEM",
			(def.description ~= nil and def.description ~= "" and def.description)
				or "Sem descrição cadastrada."
		)
	end

	local function getAwakeningInfo()
		if awakeningLoaded then
			return awakeningInfo
		end
		if awakeningLoading then
			return nil
		end
		awakeningLoading = true
		if not checkAwakeningRemote then
			awakeningInfo = { exists = false }
			awakeningLoading = false
			awakeningLoaded = true
			return awakeningInfo
		end
		local ok, result = pcall(function()
			return checkAwakeningRemote:InvokeServer(characterName)
		end)
		awakeningInfo = ok and type(result) == "table" and result or { exists = false }
		awakeningLoading = false
		awakeningLoaded = true
		return awakeningInfo
	end

	local function renderAwakening()
		local requestedContext = activeDetailsRenderContext
		local requestedGeneration = detailRenderGeneration
		local info = getAwakeningInfo()
		if requestedContext ~= activeDetailsRenderContext
			or requestedGeneration ~= detailRenderGeneration
			or selectedTab ~= "AWAKENING"
		then
			if awakeningLoaded and selectedTab == "AWAKENING" and context.alive then
				task.defer(function()
					if context.alive and selectedTab == "AWAKENING" then
						renderSelectedTab("AWAKENING")
					end
				end)
			end
			return
		end
		if not info and awakeningLoading then
			createTypedSection(
				content,
				activeDetailsRenderContext,
				1,
				0.3,
				COLORS.magenta,
				"⚡ CARREGANDO DESPERTAR",
				"Consultando requisitos, forma e habilidades no servidor..."
			)
			return
		end
		if not info or not info.exists then
			createTypedSection(
				content,
				activeDetailsRenderContext,
				1,
				0.46,
				COLORS.magenta,
				"⚡ DESPERTAR NÃO CONFIGURADO",
				"Este personagem ainda não possui uma forma de Despertar cadastrada."
			)
			return
		end

		local aw = info.awakening or {}
		local statusText
		local statusColor
		local accessFraction
		if not info.hasOriginal then
			statusText = "🔒 PRECISA DO PERSONAGEM ORIGINAL"
			statusColor = COLORS.red
			accessFraction = 0.16
		elseif info.exigeBadge and not info.temBadge then
			statusText = "🏅 FALTA O EMBLEMA NECESSÁRIO"
			statusColor = COLORS.yellow
			accessFraction = 0.52
		else
			statusText = "✅ LIBERADO — ENCHA A BARRA EM COMBATE"
			statusColor = COLORS.green
			accessFraction = 1
		end

		local statusSection = createDetailSection(
			content,
			activeDetailsRenderContext,
			1,
			0.2,
			statusColor,
			"⚡ " .. tostring(aw.displayName or (characterName .. " DESPERTADO")):upper()
		)
		local statusLabel = Instance.new("TextLabel")
		statusLabel.Position = UDim2.fromScale(0.03, 0.27)
		statusLabel.Size = UDim2.fromScale(0.94, 0.26)
		statusLabel.BackgroundTransparency = 1
		statusLabel.Text = statusText
		statusLabel.TextColor3 = statusColor
		statusLabel.TextScaled = true
		statusLabel.TextWrapped = true
		statusLabel.Font = Enum.Font.Arcade
		statusLabel.Parent = statusSection
		limitarTexto(statusLabel, 9, 19)

		local accessBack = Instance.new("Frame")
		accessBack.Position = UDim2.fromScale(0.03, 0.62)
		accessBack.Size = UDim2.fromScale(0.94, 0.18)
		accessBack.BackgroundColor3 = COLORS.background
		accessBack.BorderSizePixel = 0
		accessBack.ClipsDescendants = true
		accessBack.Parent = statusSection

		local accessFill = Instance.new("Frame")
		accessFill.Size = UDim2.fromScale(0, 1)
		accessFill.BackgroundColor3 = statusColor
		accessFill.BorderSizePixel = 0
		accessFill.Parent = accessBack
		tocarTween(
			activeDetailsRenderContext,
			accessFill,
			accessFill,
			TweenInfo.new(0.62, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, 0.12),
			{ Size = UDim2.fromScale(accessFraction, 1) }
		)

		if info.liberado then
			tocarTween(
				activeDetailsRenderContext,
				statusSection,
				statusSection:FindFirstChildOfClass("UIStroke"),
				TweenInfo.new(1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
				{ Transparency = 0.72, Color = COLORS.white }
			)
		end

		local visualSection = createDetailSection(
			content,
			activeDetailsRenderContext,
			2,
			0.36,
			COLORS.magenta,
			"◈ FORMA DESPERTA"
		)

		local imageFrame = Instance.new("Frame")
		imageFrame.Position = UDim2.fromScale(0.03, 0.23)
		imageFrame.Size = UDim2.fromScale(0.28, 0.68)
		imageFrame.BackgroundColor3 = COLORS.background
		imageFrame.BorderSizePixel = 0
		imageFrame.ClipsDescendants = true
		imageFrame.Parent = visualSection
		local imageAspect = Instance.new("UIAspectRatioConstraint")
		imageAspect.AspectRatio = 1
		imageAspect.DominantAxis = Enum.DominantAxis.Height
		imageAspect.Parent = imageFrame

		local imageId = tonumber(aw.imageId) or 0
		if imageId > 0 then
			local image = Instance.new("ImageLabel")
			image.Size = UDim2.fromScale(1, 1)
			image.BackgroundTransparency = 1
			image.Image = "rbxassetid://" .. tostring(imageId)
			image.ScaleType = Enum.ScaleType.Fit
			image.Parent = imageFrame
		else
			local noImage = Instance.new("TextLabel")
			noImage.Size = UDim2.fromScale(1, 1)
			noImage.BackgroundTransparency = 1
			noImage.Text = "SEM\nIMAGEM"
			noImage.TextColor3 = COLORS.muted
			noImage.TextScaled = true
			noImage.Font = Enum.Font.Arcade
			noImage.Parent = imageFrame
		end

		local metrics = {
			"❤️ HP: " .. tostring(aw.health or "—"),
			"⏱ DURAÇÃO: " .. (aw.duracao and (tostring(aw.duracao) .. "s") or "PADRÃO"),
			"⌛ RECARGA: " .. (aw.cooldown and (tostring(aw.cooldown) .. "s") or "PADRÃO"),
			info.exigeBadge and (info.temBadge and "🏅 EMBLEMA: POSSUI" or "🏅 EMBLEMA: PENDENTE")
				or "🏅 EMBLEMA: NÃO EXIGIDO",
		}
		for i, metric in ipairs(metrics) do
			local metricLabel = Instance.new("TextLabel")
			metricLabel.Position = UDim2.fromScale(0.35, 0.23 + (i - 1) * 0.17)
			metricLabel.Size = UDim2.fromScale(0.61, 0.14)
			metricLabel.BackgroundColor3 = COLORS.background
			metricLabel.BackgroundTransparency = 0.18
			metricLabel.BorderSizePixel = 0
			metricLabel.Text = metric
			metricLabel.TextColor3 = i == 4 and statusColor or COLORS.ink
			metricLabel.TextScaled = true
			metricLabel.TextWrapped = true
			metricLabel.Font = Enum.Font.Code
			metricLabel.TextXAlignment = Enum.TextXAlignment.Left
			metricLabel.Parent = visualSection
			limitarTexto(metricLabel, 9, 17)
		end

		local order = 3
		createDetailRow(
			content,
			activeDetailsRenderContext,
			order,
			"⚔️",
			string.format("HABILIDADES DESPERTAS (%d)", #toolsDespertas),
			COLORS.magenta
		)
		order += 1
		if #toolsDespertas == 0 then
			createDetailRow(content, activeDetailsRenderContext, order, "—", "Nenhuma Tool carregada nesta forma.", COLORS.muted)
			order += 1
		else
			for _, toolName in ipairs(toolsDespertas) do
				createDetailRow(content, activeDetailsRenderContext, order, "⚡", toolName, COLORS.magenta)
				order += 1
			end
		end

		createTypedSection(
			content,
			activeDetailsRenderContext,
			order,
			0.42,
			COLORS.magenta,
			"📖 HISTÓRIA DO DESPERTAR",
			(aw.lore ~= nil and aw.lore ~= "" and aw.lore)
				or (aw.description ~= nil and aw.description ~= "" and aw.description)
				or "Sem história cadastrada para esta forma."
		)
	end

	renderSelectedTab = function(tabKey)
		selectedTab = tabKey
		detailRenderGeneration += 1
		limparContexto(activeDetailsRenderContext)
		activeDetailsRenderContext = novoContexto()
		for _, child in ipairs(content:GetChildren()) do
			if child:IsA("GuiObject") then
				child.Parent = nil
			end
		end
		content.CanvasPosition = Vector2.new(0, 0)

		for _, tab in ipairs(DETAIL_TABS) do
			local button = tabButtons[tab.key]
			local selected = tab.key == tabKey
			tocarTween(
				context,
				"tab_color_" .. tab.key,
				button,
				TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{
					BackgroundColor3 = selected and tab.color or COLORS.panelRaised,
					TextColor3 = selected and COLORS.background or tab.color,
				}
			)
		end

		if tabKey == "LORE" then
			renderLore()
		elseif tabKey == "ABILITIES" then
			renderAbilities()
		elseif tabKey == "STATS" then
			renderStats()
		elseif tabKey == "AWAKENING" then
			renderAwakening()
		else
			renderInfo()
		end
	end

	for index, tab in ipairs(DETAIL_TABS) do
		local tabButton = Instance.new("TextButton")
		tabButton.Name = "Tab_" .. tab.key
		tabButton.LayoutOrder = index
		tabButton.BackgroundColor3 = COLORS.panelRaised
		tabButton.BorderSizePixel = 0
		tabButton.Text = detailLayout.portrait and (tab.icon .. "\n" .. tab.shortLabel)
			or (tab.icon .. " " .. tab.label)
		tabButton.TextColor3 = tab.color
		tabButton.TextScaled = true
		tabButton.TextWrapped = true
		tabButton.Font = Enum.Font.Arcade
		tabButton.ZIndex = 14
		tabButton.Parent = tabsFrame
		limitarTexto(tabButton, 7, 16)
		prepararBotaoAnimado(context, tabButton)
		tabButtons[tab.key] = tabButton
		conectarContexto(context, tabButton.Activated, function()
			playSound(sounds.click)
			renderSelectedTab(tab.key)
		end)
	end

	conectarContexto(context, closeButton.Activated, closeDetails)
	conectarContexto(context, backdropButton.Activated, closeDetails)
	conectarContexto(context, UserInputService.InputBegan, function(input, processado)
		if not processado and input.KeyCode == Enum.KeyCode.Escape then
			closeDetails()
		end
	end)
	conectarContexto(context, infoGui.AncestryChanged, function(_, parent)
		if parent == nil and context.alive then
			limparContexto(activeDetailsRenderContext)
			limparContexto(context)
		end
	end)

	local resizeGeneration = 0
	local lastViewport = getViewportSize()
	local viewportConnection = nil
	local function applyDetailLayout()
		resizeGeneration += 1
		local generation = resizeGeneration
		task.delay(0.12, function()
			if not context.alive or generation ~= resizeGeneration then
				return
			end
			local layout = getDetailLayout()
			local viewport = getViewportSize()
			local viewportChanged = math.abs(viewport.X - lastViewport.X) > 2
				or math.abs(viewport.Y - lastViewport.Y) > 2
			lastViewport = viewport
			popup.Size = layout.size
			popupAspect.AspectRatio = layout.aspect
			popupAspect.DominantAxis = layout.portrait and Enum.DominantAxis.Width
				or Enum.DominantAxis.Height
			closeAspect.DominantAxis = layout.portrait and Enum.DominantAxis.Width
				or Enum.DominantAxis.Height
			contentLayout.Padding = UDim.new(0, math.floor(layout.contentHeight * 0.018))
			for _, tab in ipairs(DETAIL_TABS) do
				local button = tabButtons[tab.key]
				button.Text = layout.portrait and (tab.icon .. "\n" .. tab.shortLabel)
					or (tab.icon .. " " .. tab.label)
			end
			if viewportChanged then
				renderSelectedTab(selectedTab)
			end
		end)
	end

	local function bindDetailCamera()
		if viewportConnection then
			viewportConnection:Disconnect()
			viewportConnection = nil
		end
		local camera = workspace.CurrentCamera
		if camera then
			viewportConnection = conectarContexto(
				context,
				camera:GetPropertyChangedSignal("ViewportSize"),
				applyDetailLayout
			)
		end
		applyDetailLayout()
	end
	conectarContexto(context, workspace:GetPropertyChangedSignal("CurrentCamera"), bindDetailCamera)
	bindDetailCamera()

	backdropButton.BackgroundTransparency = 1
	tocarTween(
		context,
		"details_backdrop",
		backdropButton,
		TweenInfo.new(0.24, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ BackgroundTransparency = 0.28 }
	)
	panelMotion.open()
	renderSelectedTab(selectedTab)
end

-- Os pontos de entrada antigos continuam existindo para os cards e para
-- qualquer outro sistema, mas agora só escolhem qual aba o modal V14 abre.
createAbilitiesPopup = function(characterName)
	createCharacterDetailsPopup(characterName, "ABILITIES", nil)
end

createLorePopup = function(characterName)
	createCharacterDetailsPopup(characterName, "LORE", nil)
end

createAwakeningPopup = function(characterName, info)
	createCharacterDetailsPopup(characterName, "AWAKENING", info)
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
local function createAwakeningButton(charData, card, context)
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

	-- (V10) O BOTÃO VOLTOU — mas ele ABRE INFORMAÇÃO, não equipa.
	--
	-- No V8 este botão desbloqueava o Despertar e o personagem passava a
	-- nascer desperto para sempre. No V9 eu tirei o botão inteiro e
	-- deixei só um rótulo com o nome, o que foi longe demais: some a
	-- imagem, a história e as habilidades da forma.
	--
	-- Agora ele é um botão de VER: abre o painel com imagem, nome,
	-- história e as Tools despertas. Equipar continua não existindo,
	-- porque o Despertar é conquistado em combate pela barra.
	local nomeDesperto = (awakeningInfo.awakening and awakeningInfo.awakening.displayName)
		or (charData.name .. " (Despertado)")

	local awakeningButton = Instance.new("TextButton")
	awakeningButton.Name = "AwakeningButton"
	awakeningButton.Size = UDim2.new(0.96, 0, 0.09, 0)
	awakeningButton.Position = UDim2.new(0.02, 0, 0.865, 0)
	awakeningButton.BorderColor3 = Color3.fromRGB(255, 0, 255)
	awakeningButton.BorderSizePixel = 2
	awakeningButton.TextScaled = true
	awakeningButton.Font = Enum.Font.Arcade
	awakeningButton.ZIndex = 10
	awakeningButton.Parent = card
	limitarTexto(awakeningButton, 8, 18)
	prepararBotaoAnimado(context, awakeningButton)

	if awakeningInfo.liberado then
		awakeningButton.Text = "⚡ ABA DESPERTAR"
		awakeningButton.BackgroundColor3 = Color3.fromRGB(120, 0, 160)
		awakeningButton.TextColor3 = Color3.fromRGB(255, 255, 0)
	elseif not awakeningInfo.hasOriginal then
		awakeningButton.Text = "🔒 ABA DESPERTAR"
		awakeningButton.BackgroundColor3 = Color3.fromRGB(60, 0, 60)
		awakeningButton.TextColor3 = Color3.fromRGB(190, 190, 190)
	else
		awakeningButton.Text = "🔒 ABA DESPERTAR"
		awakeningButton.BackgroundColor3 = Color3.fromRGB(60, 0, 60)
		awakeningButton.TextColor3 = Color3.fromRGB(190, 190, 190)
	end

	-- Clicar SEMPRE abre o painel, mesmo bloqueado: é assim que o jogador
	-- descobre o que existe e o que precisa fazer para liberar.
	conectarContexto(context, awakeningButton.Activated, function()
		playSound(sounds.awakening)
		createAwakeningPopup(charData.name, awakeningInfo)
	end)

	-- Um único tween repetido e registrado: ao filtrar/remontar, ele é
	-- cancelado junto com o card em vez de deixar threads antigas vivas.
	if awakeningInfo.liberado then
		tocarTween(
			context,
			awakeningButton,
			awakeningButton,
			TweenInfo.new(1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
			{ BackgroundColor3 = Color3.fromRGB(190, 0, 240) }
		)
	end
end

-- =====================================
-- CARD DE PERSONAGEM (V6)
-- charData = definição pública do catálogo:
-- { name, category, value, gamepassId, badgeId, imageId, rarity,
--   description, lore, health }
-- =====================================

createCharacterCard = function(charData, parentFrame, cardConfig, isInventoryMode, context)
	local card = Instance.new("Frame")
	card.Size = UDim2.new(0, cardConfig.width, 0, cardConfig.height)
	card.BackgroundColor3 = COLORS.panel
	card.BorderSizePixel = 0
	card.ClipsDescendants = true
	card.Parent = parentFrame

	local rarityColor = rarities[charData.rarity] and rarities[charData.rarity].color
		or Color3.fromRGB(100, 100, 100)

	local cardAspect = Instance.new("UIAspectRatioConstraint")
	cardAspect.AspectRatio = cardConfig.aspect or CARD_ASPECT_RATIO
	cardAspect.DominantAxis = Enum.DominantAxis.Width
	cardAspect.Parent = card

	local cardStroke = Instance.new("UIStroke")
	cardStroke.Color = rarityColor
	cardStroke.Thickness = 3
	cardStroke.Transparency = 0.05
	cardStroke.Parent = card

	local cardGradient = Instance.new("UIGradient")
	cardGradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, COLORS.panelRaised),
		ColorSequenceKeypoint.new(0.55, COLORS.panel),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(7, 8, 14)),
	})
	cardGradient.Rotation = 90
	cardGradient.Parent = card

	local cardScale = Instance.new("UIScale")
	cardScale.Scale = 0.9
	cardScale.Parent = card
	tocarTween(
		context,
		cardScale,
		cardScale,
		TweenInfo.new(0.32, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Scale = 1 }
	)
	conectarContexto(context, card.MouseEnter, function()
		tocarTween(
			context,
			cardScale,
			cardScale,
			TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Scale = 1.025 }
		)
	end)
	conectarContexto(context, card.MouseLeave, function()
		tocarTween(
			context,
			cardScale,
			cardScale,
			TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Scale = 1 }
		)
	end)

	-- Efeito raro: um tween reversível guardado no contexto do render.
	if rarities[charData.rarity] and rarities[charData.rarity].glow then
		tocarTween(
			context,
			cardStroke,
			cardStroke,
			TweenInfo.new(1.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
			{ Transparency = 0.55, Color = COLORS.white }
		)
	end

	-- Header
	local header = Instance.new("Frame")
	header.Size = UDim2.new(1, 0, 0.15, 0)
	header.BackgroundColor3 = COLORS.panelRaised:Lerp(rarityColor, 0.28)
	header.BorderSizePixel = 0
	header.Parent = card

	local headerLine = Instance.new("Frame")
	headerLine.AnchorPoint = Vector2.new(0, 1)
	headerLine.Position = UDim2.fromScale(0, 1)
	headerLine.Size = UDim2.fromScale(1, 0.08)
	headerLine.BackgroundColor3 = rarityColor
	headerLine.BorderSizePixel = 0
	headerLine.Parent = header

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
	limitarTexto(nameLabel, 9, 22)

	-- Imagem
	local imageContainer = Instance.new("Frame")
	imageContainer.Size = UDim2.new(0.96, 0, 0.38, 0)
	imageContainer.Position = UDim2.new(0.02, 0, 0.17, 0)
	imageContainer.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
	imageContainer.BorderSizePixel = 0
	imageContainer.ClipsDescendants = true
	imageContainer.Parent = card

	local imageStroke = Instance.new("UIStroke")
	imageStroke.Color = COLORS.white
	imageStroke.Thickness = 2
	imageStroke.Transparency = 0.45
	imageStroke.Parent = imageContainer

	createCharacterImage(charData.name, imageContainer)

	local categoryMeta = CATEGORY_META[charData.category]
		or { icon = "◆", label = tostring(charData.category or "ESPECIAL"), color = COLORS.cyan }
	local categoryBadge = Instance.new("TextLabel")
	categoryBadge.Name = "CategoryBadge"
	categoryBadge.Position = UDim2.fromScale(0.04, 0.19)
	categoryBadge.Size = UDim2.fromScale(0.48, 0.07)
	categoryBadge.BackgroundColor3 = COLORS.background
	categoryBadge.BackgroundTransparency = 0.08
	categoryBadge.BorderSizePixel = 0
	categoryBadge.Text = categoryMeta.icon .. " " .. categoryMeta.label
	categoryBadge.TextColor3 = categoryMeta.color
	categoryBadge.TextScaled = true
	categoryBadge.Font = Enum.Font.Arcade
	categoryBadge.ZIndex = 6
	categoryBadge.Parent = card
	limitarTexto(categoryBadge, 8, 16)

	-- (V14.1) ApplyStrokeMode EXPLÍCITO. O padrão é Contextual, e em
	-- TextLabel isso põe o traço nas LETRAS, não na borda da caixa.
	-- Como a cor do traço aqui é a mesma do texto, cada letra ganhava um
	-- halo sólido de 2 px da própria cor: o dobro de massa colorida no
	-- mesmo glifo, que é o que deixava o card saturado.
	-- O selo tem fundo próprio, então o contorno é da CAIXA.
	local categoryStroke = Instance.new("UIStroke")
	categoryStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	categoryStroke.Color = categoryMeta.color
	categoryStroke.Thickness = 1
	categoryStroke.Transparency = 0.35
	categoryStroke.Parent = categoryBadge

	local rarityBadge = Instance.new("TextLabel")
	rarityBadge.Name = "RarityEmblem"
	rarityBadge.AnchorPoint = Vector2.new(1, 0)
	rarityBadge.Position = UDim2.fromScale(0.96, 0.19)
	rarityBadge.Size = UDim2.fromScale(0.15, 0.08)
	rarityBadge.BackgroundColor3 = rarityColor
	rarityBadge.BorderSizePixel = 0
	rarityBadge.Text = RARITY_EMBLEMS[charData.rarity] or "?"
	rarityBadge.TextColor3 = COLORS.white
	rarityBadge.TextScaled = true
	rarityBadge.Font = Enum.Font.Arcade
	rarityBadge.ZIndex = 6
	rarityBadge.Parent = card
	limitarTexto(rarityBadge, 9, 18)

	local rarityAspect = Instance.new("UIAspectRatioConstraint")
	rarityAspect.AspectRatio = 1
	rarityAspect.DominantAxis = Enum.DominantAxis.Height
	rarityAspect.Parent = rarityBadge

	-- Mesmo caso: texto branco com traço branco de 2 px virava borrão.
	local rarityStroke = Instance.new("UIStroke")
	rarityStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	rarityStroke.Color = COLORS.white
	rarityStroke.Thickness = 1
	rarityStroke.Transparency = 0.4
	rarityStroke.Parent = rarityBadge

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
	descLabel.TextWrapped = true
	descLabel.Parent = card
	limitarTexto(descLabel, 8, 16)

	-- Raridade
	local rarityLabel = Instance.new("TextLabel")
	rarityLabel.Size = UDim2.new(0.96, 0, 0.05, 0)
	rarityLabel.Position = UDim2.new(0.02, 0, 0.64, 0)
	rarityLabel.BackgroundTransparency = 1
	rarityLabel.Text = "[ " .. (charData.rarity or "?") .. " ]"
	rarityLabel.TextColor3 = rarityColor
	rarityLabel.TextScaled = true
	rarityLabel.Font = Enum.Font.Arcade
	rarityLabel.Parent = card
	limitarTexto(rarityLabel, 8, 15)

	-- Status / Requisito (V6: por categoria)
	local statusLabel = Instance.new("TextLabel")
	statusLabel.Size = UDim2.new(0.96, 0, 0.06, 0)
	statusLabel.Position = UDim2.new(0.02, 0, 0.70, 0)
	statusLabel.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
	statusLabel.BorderSizePixel = 0
	statusLabel.TextScaled = true
	statusLabel.Font = Enum.Font.Arcade
	statusLabel.Parent = card
	limitarTexto(statusLabel, 8, 16)

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
		local badgeId = tonumber(charData.badgeId) or 0
		statusLabel.Text = badgeId > 0 and ("🏅 EMBLEMA #" .. badgeId) or "🏅 EMBLEMA"
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
	limitarTexto(actionButton, 8, 16)
	prepararBotaoAnimado(context, actionButton)

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

	conectarContexto(context, actionButton.Activated, function()
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
		limitarTexto(sellButton, 8, 15)
		prepararBotaoAnimado(context, sellButton)

		if canSell and sellPrice and sellPrice > 0 then
			sellButton.Text = "💰 " .. sellPrice
			sellButton.BackgroundColor3 = Color3.fromRGB(200, 150, 0)
			sellButton.TextColor3 = Color3.new(1, 1, 1)

			conectarContexto(context, sellButton.Activated, function()
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
		prepararBotaoAnimado(context, infoButton)

		conectarContexto(context, infoButton.Activated, function()
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
		prepararBotaoAnimado(context, loreButton)

		conectarContexto(context, loreButton.Activated, function()
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
		prepararBotaoAnimado(context, infoButton)

		conectarContexto(context, infoButton.Activated, function()
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
		prepararBotaoAnimado(context, loreButton)

		conectarContexto(context, loreButton.Activated, function()
			createLorePopup(charData.name)
		end)
	end

	-- Despertar
	createAwakeningButton(charData, card, context)

	return card
end

-- =====================================
-- (V11) BUSCA, GRADE RESPONSIVA E SEÇÕES
-- =====================================
-- Até o V10 os dois grids posicionavam cada card com conta de col/row em
-- PIXELS ABSOLUTOS, e o uiScale era calculado UMA VEZ no carregamento do
-- script. Duas consequências: em cada aparelho o card saía de um tamanho
-- diferente do pretendido, e girar o celular não refazia nada — a grade
-- continuava com a largura da orientação anterior.
--
-- Agora quem posiciona é UIGridLayout, quem limita a forma do card é
-- UIAspectRatioConstraint, e a escala é recalculada quando a ViewportSize
-- muda. Ninguém mais faz conta de posição à mão.

local buscaLoja = ""
local buscaInventario = ""

local function combinaBusca(charData, termo)
	local query = string.lower(tostring(termo or ""))
	if query == "" then
		return true
	end
	local meta = CATEGORY_META[charData.category]
	local haystack = string.lower(table.concat({
		tostring(charData.name or ""),
		tostring(charData.displayName or ""),
		tostring(charData.description or ""),
		tostring(charData.rarity or ""),
		tostring(charData.category or ""),
		meta and meta.label or "",
		tostring(charData.badgeId or ""),
	}, " "))
	for token in string.gmatch(query, "%S+") do
		if not string.find(haystack, token, 1, true) then
			return false
		end
	end
	return true
end

-- Barra de pesquisa no padrão retro do HUD. O debounce por geração evita
-- reconstruir dezenas de cards para cada tecla de uma digitação rápida.
local function criarBarraPesquisa(context, pai, posicao, tamanho, accentColor, initialText, aoMudar)
	local moldura = Instance.new("Frame")
	moldura.Name = "BarraPesquisa"
	moldura.Position = posicao
	moldura.Size = tamanho
	moldura.BackgroundColor3 = COLORS.panelRaised
	moldura.BorderSizePixel = 0
	moldura.Parent = pai

	local searchStroke = Instance.new("UIStroke")
	searchStroke.Color = accentColor
	searchStroke.Thickness = 2
	searchStroke.Transparency = 0.15
	searchStroke.Parent = moldura

	local searchAccent = Instance.new("Frame")
	searchAccent.Size = UDim2.fromScale(0.012, 1)
	searchAccent.BackgroundColor3 = accentColor
	searchAccent.BorderSizePixel = 0
	searchAccent.Parent = moldura

	local lupa = Instance.new("TextLabel")
	lupa.Position = UDim2.fromScale(0.02, 0)
	lupa.Size = UDim2.fromScale(0.07, 1)
	lupa.BackgroundTransparency = 1
	lupa.Text = "🔍"
	lupa.TextScaled = true
	lupa.Font = Enum.Font.Arcade
	lupa.TextColor3 = accentColor
	lupa.Parent = moldura
	limitarTexto(lupa, 12, 24)

	local caixa = Instance.new("TextBox")
	caixa.Name = "Campo"
	caixa.Position = UDim2.fromScale(0.1, 0.1)
	caixa.Size = UDim2.fromScale(0.62, 0.8)
	caixa.BackgroundTransparency = 1
	caixa.Text = initialText or ""
	caixa.PlaceholderText = isMobile and "Buscar personagem..." or "Pesquisar nome, raridade ou emblema..."
	caixa.PlaceholderColor3 = COLORS.muted
	caixa.TextColor3 = COLORS.ink
	caixa.TextScaled = true
	caixa.Font = Enum.Font.Code
	caixa.TextXAlignment = Enum.TextXAlignment.Left
	caixa.ClearTextOnFocus = false
	caixa.Parent = moldura
	limitarTexto(caixa, 11, 22)

	local counter = Instance.new("TextLabel")
	counter.Name = "Counter"
	counter.Position = UDim2.fromScale(0.73, 0.15)
	counter.Size = UDim2.fromScale(0.16, 0.7)
	counter.BackgroundColor3 = COLORS.background
	counter.BorderSizePixel = 0
	counter.Text = "0 RESULTADOS"
	counter.TextColor3 = COLORS.muted
	counter.TextScaled = true
	counter.Font = Enum.Font.Arcade
	counter.Parent = moldura
	limitarTexto(counter, 8, 15)

	local limpar = Instance.new("TextButton")
	limpar.Name = "Limpar"
	limpar.Position = UDim2.fromScale(0.91, 0.15)
	limpar.Size = UDim2.fromScale(0.07, 0.7)
	limpar.BackgroundColor3 = COLORS.red
	limpar.BorderSizePixel = 0
	limpar.Text = "X"
	limpar.TextColor3 = COLORS.white
	limpar.TextScaled = true
	limpar.Font = Enum.Font.Arcade
	limpar.Visible = caixa.Text ~= ""
	limpar.Parent = moldura
	limitarTexto(limpar, 10, 18)
	prepararBotaoAnimado(context, limpar)

	local generation = 0
	conectarContexto(context, caixa:GetPropertyChangedSignal("Text"), function()
		limpar.Visible = caixa.Text ~= ""
		generation += 1
		local expectedGeneration = generation
		task.delay(0.12, function()
			if context.alive and expectedGeneration == generation then
				aoMudar(caixa.Text)
			end
		end)
	end)

	conectarContexto(context, limpar.Activated, function()
		caixa.Text = ""
	end)

	return caixa, counter
end

-- Prepara um ScrollingFrame para receber seções empilhadas.
local function prepararLista(scroll)
	local lista = scroll:FindFirstChildOfClass("UIListLayout")
	if not lista then
		lista = Instance.new("UIListLayout")
		lista.SortOrder = Enum.SortOrder.LayoutOrder
		lista.Padding = UDim.new(0, 10)
		lista.Parent = scroll

		local respiro = Instance.new("UIPadding")
		respiro.PaddingTop = UDim.new(0, 8)
		respiro.PaddingBottom = UDim.new(0, 8)
		respiro.PaddingLeft = UDim.new(0, 8)
		respiro.PaddingRight = UDim.new(0, 8)
		respiro.Parent = scroll
	end
	-- A altura do conteúdo passa a ser do próprio layout: sem isso seria
	-- preciso recalcular CanvasSize a cada filtro da busca.
	scroll.CanvasSize = UDim2.new()
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.ScrollBarImageColor3 = COLORS.cyan
	scroll.ScrollBarImageTransparency = 0.15
	return lista
end

-- Uma seção = cabeçalho de raridade + grade daquela raridade, como no
-- layout de referência ("Starter", "Intermediate").
local function criarSecao(scroll, titulo, cor, ordem, cardConfig, total, context)
	local secao = Instance.new("Frame")
	secao.Name = "Secao_" .. titulo
	secao.BackgroundTransparency = 1
	secao.Size = UDim2.new(1, 0, 0, 0)
	secao.AutomaticSize = Enum.AutomaticSize.Y
	secao.LayoutOrder = ordem
	secao.Parent = scroll

	local pilha = Instance.new("UIListLayout")
	pilha.SortOrder = Enum.SortOrder.LayoutOrder
	pilha.Padding = UDim.new(0, 6)
	pilha.Parent = secao

	local cabecalho = Instance.new("Frame")
	cabecalho.Name = "Cabecalho"
	cabecalho.Size = UDim2.new(1, 0, 0, cardConfig.sectionHeader)
	cabecalho.BackgroundColor3 = COLORS.panelRaised
	cabecalho.BackgroundTransparency = 0.2
	cabecalho.BorderSizePixel = 0
	cabecalho.LayoutOrder = 1
	cabecalho.Parent = secao

	local accent = Instance.new("Frame")
	accent.Size = UDim2.fromScale(0.012, 1)
	accent.BackgroundColor3 = cor
	accent.BorderSizePixel = 0
	accent.Parent = cabecalho

	local sectionTitle = Instance.new("TextLabel")
	sectionTitle.Position = UDim2.fromScale(0.03, 0)
	sectionTitle.Size = UDim2.fromScale(0.72, 1)
	sectionTitle.BackgroundTransparency = 1
	sectionTitle.Text = "◆ " .. titulo
	sectionTitle.TextColor3 = cor
	sectionTitle.TextScaled = true
	sectionTitle.Font = Enum.Font.Arcade
	sectionTitle.TextXAlignment = Enum.TextXAlignment.Left
	sectionTitle.Parent = cabecalho
	limitarTexto(sectionTitle, 10, 22)

	local sectionCount = Instance.new("TextLabel")
	sectionCount.AnchorPoint = Vector2.new(1, 0.5)
	sectionCount.Position = UDim2.fromScale(0.98, 0.5)
	sectionCount.Size = UDim2.fromScale(0.2, 0.7)
	sectionCount.BackgroundTransparency = 1
	sectionCount.Text = tostring(total) .. (total == 1 and " PERSONAGEM" or " PERSONAGENS")
	sectionCount.TextColor3 = COLORS.muted
	sectionCount.TextScaled = true
	sectionCount.Font = Enum.Font.Code
	sectionCount.TextXAlignment = Enum.TextXAlignment.Right
	sectionCount.Parent = cabecalho
	limitarTexto(sectionCount, 9, 17)

	local grade = Instance.new("Frame")
	grade.Name = "Grade"
	grade.BackgroundTransparency = 1
	grade.Size = UDim2.new(1, 0, 0, 0)
	grade.AutomaticSize = Enum.AutomaticSize.Y
	grade.LayoutOrder = 2
	grade.Parent = secao

	local layout = Instance.new("UIGridLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.CellSize = UDim2.new(0, cardConfig.width, 0, cardConfig.height)
	layout.CellPadding = UDim2.new(0, cardConfig.spacing, 0, cardConfig.spacing)
	layout.FillDirectionMaxCells = cardConfig.columns
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Parent = grade

	local function atualizarAlturaGrade()
		if grade.Parent then
			grade.Size = UDim2.new(1, 0, 0, layout.AbsoluteContentSize.Y)
		end
	end
	conectarContexto(context, layout:GetPropertyChangedSignal("AbsoluteContentSize"), atualizarAlturaGrade)
	task.defer(function()
		if context.alive then
			atualizarAlturaGrade()
		end
	end)

	return grade
end

-- =====================================
-- CRIAR SISTEMA UNIFICADO (V6)
-- =====================================

createSystem = function()
	limparContexto(shopRenderContext)
	limparContexto(inventoryRenderContext)
	limparContexto(systemContext)
	shopRenderContext = nil
	inventoryRenderContext = nil
	systemContext = novoContexto()
	table.clear(categoryTabButtons)
	mainTitleLabel = nil
	inventoryTitleLabel = nil
	inventoryHintLabel = nil
	mainCloseAspectConstraint = nil
	inventoryCloseAspectConstraint = nil

	if systemGui then
		systemGui.Parent = nil
	end

	systemGui = Instance.new("ScreenGui")
	systemGui.Name = "CharacterSystemV13"
	systemGui.ResetOnSpawn = false
	systemGui.IgnoreGuiInset = true
	systemGui.DisplayOrder = 112
	systemGui.ZIndexBehavior = Enum.ZIndexBehavior.Global
	systemGui.Parent = playerGui

	backdrop = Instance.new("Frame")
	backdrop.Name = "Backdrop"
	backdrop.Size = UDim2.fromScale(1, 1)
	backdrop.BackgroundColor3 = Color3.fromRGB(0, 2, 8)
	backdrop.BackgroundTransparency = 0.28
	backdrop.BorderSizePixel = 0
	backdrop.Active = true
	backdrop.Visible = false
	backdrop.ZIndex = 0
	backdrop.Parent = systemGui

	-- ─────────────────────────────────────
	-- FRAME PRINCIPAL - LOJA
	-- ─────────────────────────────────────

	mainFrame = Instance.new("Frame")
	mainFrame.Name = "MainFrame"
	mainFrame.Size = uiScale.menu
	mainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
	mainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	mainFrame.BackgroundColor3 = COLORS.background
	mainFrame.BorderSizePixel = 0
	mainFrame.ClipsDescendants = true
	mainFrame.Visible = false
	mainFrame.Parent = systemGui

	mainAspectConstraint = Instance.new("UIAspectRatioConstraint")
	mainAspectConstraint.AspectRatio = uiScale.panelAspect
	mainAspectConstraint.DominantAxis = Enum.DominantAxis.Width
	mainAspectConstraint.Parent = mainFrame

	local mainStroke = Instance.new("UIStroke")
	mainStroke.Color = COLORS.white
	mainStroke.Thickness = 4
	mainStroke.Parent = mainFrame

	local mainGradient = Instance.new("UIGradient")
	mainGradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(22, 28, 42)),
		ColorSequenceKeypoint.new(0.55, COLORS.background),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(2, 8, 15)),
	})
	mainGradient.Rotation = 90
	mainGradient.Parent = mainFrame

	mainPanelMotion = criarMolaPainel(systemContext, mainFrame, function()
		if not isMenuOpen and not isInvOpen and backdrop then
			backdrop.Visible = false
		end
	end)

	local menuHeader = Instance.new("Frame")
	menuHeader.Size = UDim2.fromScale(1, 0.105)
	menuHeader.BackgroundColor3 = COLORS.panelRaised
	menuHeader.BorderSizePixel = 0
	menuHeader.Parent = mainFrame

	local menuHeaderLine = Instance.new("Frame")
	menuHeaderLine.AnchorPoint = Vector2.new(0, 1)
	menuHeaderLine.Position = UDim2.fromScale(0, 1)
	menuHeaderLine.Size = UDim2.fromScale(1, 0.06)
	menuHeaderLine.BackgroundColor3 = COLORS.cyan
	menuHeaderLine.BorderSizePixel = 0
	menuHeaderLine.Parent = menuHeader

	local menuTitle = Instance.new("TextLabel")
	menuTitle.Position = UDim2.fromScale(0.03, 0.05)
	menuTitle.Size = UDim2.fromScale(0.58, 0.9)
	menuTitle.BackgroundTransparency = 1
	menuTitle.Text = uiScale.portrait and "[ LOJA ]" or "[ PERSONAGENS ]  LOJA"
	menuTitle.TextColor3 = COLORS.cyan
	menuTitle.TextScaled = true
	menuTitle.Font = Enum.Font.Arcade
	menuTitle.TextXAlignment = Enum.TextXAlignment.Left
	menuTitle.Parent = menuHeader
	limitarTexto(menuTitle, 9, 28)
	mainTitleLabel = menuTitle

	local coinsLabel = Instance.new("TextLabel")
	coinsLabel.Name = "CoinsLabel"
	coinsLabel.Size = UDim2.fromScale(0.22, 0.72)
	coinsLabel.Position = UDim2.fromScale(0.68, 0.14)
	coinsLabel.BackgroundColor3 = COLORS.background
	coinsLabel.BorderSizePixel = 0
	coinsLabel.Text = "💰 " .. playerData.coins
	coinsLabel.TextColor3 = COLORS.yellow
	coinsLabel.TextScaled = true
	coinsLabel.Font = Enum.Font.Arcade
	coinsLabel.Parent = menuHeader
	limitarTexto(coinsLabel, 10, 21)

	-- Mesmo defeito do card, no contador de moedas do cabeçalho: amarelo
	-- sobre amarelo. Fica junto porque aparece na mesma tela.
	local coinsStroke = Instance.new("UIStroke")
	coinsStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	coinsStroke.Color = COLORS.yellow
	coinsStroke.Thickness = 1
	coinsStroke.Transparency = 0.35
	coinsStroke.Parent = coinsLabel

	local menuClose = Instance.new("TextButton")
	menuClose.Size = UDim2.fromScale(0.065, 0.72)
	menuClose.Position = UDim2.fromScale(0.92, 0.14)
	menuClose.BackgroundColor3 = COLORS.red
	menuClose.BorderSizePixel = 0
	menuClose.Text = "X"
	menuClose.TextColor3 = COLORS.white
	menuClose.TextScaled = true
	menuClose.Font = Enum.Font.Arcade
	menuClose.Parent = menuHeader
	limitarTexto(menuClose, 12, 22)
	prepararBotaoAnimado(systemContext, menuClose)

	mainCloseAspectConstraint = Instance.new("UIAspectRatioConstraint")
	mainCloseAspectConstraint.AspectRatio = 1
	mainCloseAspectConstraint.DominantAxis = uiScale.portrait and Enum.DominantAxis.Width
		or Enum.DominantAxis.Height
	mainCloseAspectConstraint.Parent = menuClose

	-- Tabs de categoria (V6: 4 abas — SEM GRÁTIS)
	local tabFrame = Instance.new("Frame")
	tabFrame.Size = UDim2.fromScale(1, 0.08)
	tabFrame.Position = UDim2.fromScale(0, 0.105)
	tabFrame.BackgroundColor3 = COLORS.panel
	tabFrame.BorderSizePixel = 0
	tabFrame.Parent = mainFrame

	local tabWidth = 1 / #SHOP_TABS

	local _, shopCounter = criarBarraPesquisa(
		systemContext,
		mainFrame,
		UDim2.fromScale(0.015, 0.195),
		UDim2.fromScale(0.97, 0.07),
		COLORS.cyan,
		buscaLoja,
		function(texto)
			buscaLoja = texto
			refreshOpenFrames()
		end
	)

	contentFrame = Instance.new("ScrollingFrame")
	contentFrame.Size = UDim2.fromScale(0.97, 0.705)
	contentFrame.Position = UDim2.fromScale(0.015, 0.28)
	contentFrame.BackgroundColor3 = Color3.fromRGB(5, 8, 14)
	contentFrame.BackgroundTransparency = 0.08
	contentFrame.BorderSizePixel = 0
	contentFrame.ScrollBarThickness = isMobile and 8 or 12
	contentFrame.Parent = mainFrame

	local contentStroke = Instance.new("UIStroke")
	contentStroke.Color = COLORS.cyan
	contentStroke.Thickness = 2
	contentStroke.Transparency = 0.55
	contentStroke.Parent = contentFrame

	for i, tab in ipairs(SHOP_TABS) do
		local tabMeta = CATEGORY_META[tab.key]
			or { icon = "◆", label = tab.label, color = COLORS.cyan }
		local tabButton = Instance.new("TextButton")
		tabButton.Size = UDim2.new(tabWidth, 0, 1, 0)
		tabButton.Position = UDim2.new((i - 1) * tabWidth, 0, 0, 0)
		tabButton.BackgroundColor3 = selectedCategory == tab.key and tabMeta.color or COLORS.panelRaised
		tabButton.BorderSizePixel = 0
		tabButton.Text = uiScale.portrait and (tabMeta.icon .. "\n" .. tabMeta.label)
			or (tabMeta.icon .. " " .. tabMeta.label)
		tabButton.TextColor3 = selectedCategory == tab.key and COLORS.background or tabMeta.color
		tabButton.TextScaled = true
		tabButton.TextWrapped = true
		tabButton.Font = Enum.Font.Arcade
		tabButton.Parent = tabFrame
		tabButton:SetAttribute("CategoryKey", tab.key)
		tabButton:SetAttribute("CategoryIcon", tabMeta.icon)
		tabButton:SetAttribute("CategoryLabel", tabMeta.label)
		tabButton:SetAttribute("AccentR", tabMeta.color.R)
		tabButton:SetAttribute("AccentG", tabMeta.color.G)
		tabButton:SetAttribute("AccentB", tabMeta.color.B)
		limitarTexto(tabButton, 9, 18)
		prepararBotaoAnimado(systemContext, tabButton)
		table.insert(categoryTabButtons, tabButton)

		conectarContexto(systemContext, tabButton.Activated, function()
			playSound(sounds.click)
			selectedCategory = tab.key
			for _, btn in pairs(tabFrame:GetChildren()) do
				if btn:IsA("TextButton") then
					local btnColor = Color3.new(
						btn:GetAttribute("AccentR") or 0,
						btn:GetAttribute("AccentG") or 0.88,
						btn:GetAttribute("AccentB") or 1
					)
					btn.BackgroundColor3 = COLORS.panelRaised
					btn.TextColor3 = btnColor
				end
			end
			tabButton.BackgroundColor3 = tabMeta.color
			tabButton.TextColor3 = COLORS.background
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
		limparContexto(shopRenderContext)
		shopRenderContext = novoContexto()
		for _, child in pairs(contentFrame:GetChildren()) do
			if child:IsA("Frame") or child:IsA("TextLabel") then
				child.Parent = nil
			end
		end

		updatePlayerData()
		coinsLabel.Text = "💰 " .. playerData.coins

		-- (V6) Personagens vêm SÓ do catálogo, filtrados pela aba
		-- (V11) e pelo texto da busca, agrupados por raridade em seções.
		local chars = getCharactersForCategory(selectedCategory)
		local cardConfig = uiScale.card
		prepararLista(contentFrame)

		local porRaridade = {}
		local index = 0
		for _, charDef in ipairs(chars) do
			if not playerOwnsCharacter(charDef.name) and combinaBusca(charDef, buscaLoja) then
				local chave = charDef.rarity or "ROBLOXIANOS"
				porRaridade[chave] = porRaridade[chave] or {}
				table.insert(porRaridade[chave], charDef)
				index = index + 1
			end
		end

		-- Ordem das seções segue a ordem declarada das raridades, para o
		-- comum vir antes do raro em vez de sair na ordem do dicionário.
		local chaves = {}
		for chave in pairs(porRaridade) do
			table.insert(chaves, chave)
		end
		table.sort(chaves, function(a, b)
			local ra = rarities[a] and rarities[a].order or 99
			local rb = rarities[b] and rarities[b].order or 99
			if ra == rb then
				return a < b
			end
			return ra < rb
		end)

		for ordem, chave in ipairs(chaves) do
			local info = rarities[chave]
			local grade = criarSecao(
				contentFrame,
				chave,
				info and info.color or Color3.fromRGB(200, 200, 200),
				ordem,
				cardConfig,
				#porRaridade[chave],
				shopRenderContext
			)
			for i, charDef in ipairs(porRaridade[chave]) do
				local card = createCharacterCard(charDef, grade, cardConfig, false, shopRenderContext)
				card.LayoutOrder = i
			end
		end

		shopCounter.Text = (isMobile or uiScale.portrait) and tostring(index)
			or (tostring(index) .. (index == 1 and " RESULTADO" or " RESULTADOS"))
		shopCounter.TextColor3 = index > 0 and COLORS.cyan or COLORS.red

		-- (V6) Categoria vazia → aviso em vez de tela em branco
		-- (V11) A mensagem distingue categoria vazia de busca sem resultado:
		-- "não tem nada aqui" e "sua busca não achou nada" pedem ações
		-- diferentes do jogador.
		if index == 0 then
			local emptyLabel = Instance.new("TextLabel")
			emptyLabel.Size = UDim2.new(1, 0, 0, 60)
			emptyLabel.BackgroundTransparency = 1
			emptyLabel.Text = buscaLoja ~= ""
					and ('Nenhum personagem encontrado para "' .. buscaLoja .. '".')
				or "Nenhum personagem disponível nesta categoria no momento."
			emptyLabel.TextColor3 = COLORS.muted
			emptyLabel.TextScaled = true
			emptyLabel.TextWrapped = true
			emptyLabel.Font = Enum.Font.Code
			emptyLabel.Parent = contentFrame
		end

		-- (V11) A altura do conteúdo é do UIListLayout via
		-- AutomaticCanvasSize. O cálculo manual antigo dependia de `rows` e
		-- `spacing`, que a grade por seções aposentou.
	end

	-- ─────────────────────────────────────
	-- FRAME INVENTÁRIO
	-- ─────────────────────────────────────

	invFrame = Instance.new("Frame")
	invFrame.Name = "InventoryFrame"
	invFrame.Size = uiScale.menu
	invFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
	invFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	invFrame.BackgroundColor3 = COLORS.background
	invFrame.BorderSizePixel = 0
	invFrame.ClipsDescendants = true
	invFrame.Visible = false
	invFrame.Parent = systemGui

	inventoryAspectConstraint = Instance.new("UIAspectRatioConstraint")
	inventoryAspectConstraint.AspectRatio = uiScale.panelAspect
	inventoryAspectConstraint.DominantAxis = Enum.DominantAxis.Width
	inventoryAspectConstraint.Parent = invFrame

	local invStroke = Instance.new("UIStroke")
	invStroke.Color = COLORS.white
	invStroke.Thickness = 4
	invStroke.Parent = invFrame

	local invGradient = Instance.new("UIGradient")
	invGradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(20, 32, 48)),
		ColorSequenceKeypoint.new(0.55, COLORS.background),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(3, 8, 16)),
	})
	invGradient.Rotation = 90
	invGradient.Parent = invFrame

	inventoryPanelMotion = criarMolaPainel(systemContext, invFrame, function()
		if not isMenuOpen and not isInvOpen and backdrop then
			backdrop.Visible = false
		end
	end)

	local invHeader = Instance.new("Frame")
	invHeader.Size = UDim2.fromScale(1, 0.105)
	invHeader.BackgroundColor3 = COLORS.panelRaised
	invHeader.BorderSizePixel = 0
	invHeader.Parent = invFrame

	local invHeaderLine = Instance.new("Frame")
	invHeaderLine.AnchorPoint = Vector2.new(0, 1)
	invHeaderLine.Position = UDim2.fromScale(0, 1)
	invHeaderLine.Size = UDim2.fromScale(1, 0.06)
	invHeaderLine.BackgroundColor3 = COLORS.blue
	invHeaderLine.BorderSizePixel = 0
	invHeaderLine.Parent = invHeader

	local invTitle = Instance.new("TextLabel")
	invTitle.Position = UDim2.fromScale(0.03, 0.05)
	invTitle.Size = UDim2.fromScale(0.58, 0.9)
	invTitle.BackgroundTransparency = 1
	invTitle.Text = uiScale.portrait and "[ INVENTÁRIO ]" or "[ PERSONAGENS ]  INVENTÁRIO"
	invTitle.TextColor3 = COLORS.cyan
	invTitle.TextScaled = true
	invTitle.Font = Enum.Font.Arcade
	invTitle.TextXAlignment = Enum.TextXAlignment.Left
	invTitle.Parent = invHeader
	limitarTexto(invTitle, 9, 28)
	inventoryTitleLabel = invTitle

	local invHint = Instance.new("TextLabel")
	invHint.Position = UDim2.fromScale(0.6, 0.15)
	invHint.Size = UDim2.fromScale(0.29, 0.7)
	invHint.BackgroundTransparency = 1
	invHint.Text = "💰 PREÇO = VENDER"
	invHint.TextColor3 = COLORS.yellow
	invHint.TextScaled = true
	invHint.Font = Enum.Font.Code
	invHint.Parent = invHeader
	limitarTexto(invHint, 9, 17)
	inventoryHintLabel = invHint

	local invClose = Instance.new("TextButton")
	invClose.Size = UDim2.fromScale(0.065, 0.72)
	invClose.Position = UDim2.fromScale(0.92, 0.14)
	invClose.BackgroundColor3 = COLORS.red
	invClose.BorderSizePixel = 0
	invClose.Text = "X"
	invClose.TextColor3 = COLORS.white
	invClose.TextScaled = true
	invClose.Font = Enum.Font.Arcade
	invClose.Parent = invHeader
	limitarTexto(invClose, 12, 22)
	prepararBotaoAnimado(systemContext, invClose)

	inventoryCloseAspectConstraint = Instance.new("UIAspectRatioConstraint")
	inventoryCloseAspectConstraint.AspectRatio = 1
	inventoryCloseAspectConstraint.DominantAxis = uiScale.portrait and Enum.DominantAxis.Width
		or Enum.DominantAxis.Height
	inventoryCloseAspectConstraint.Parent = invClose

	-- (V11) Mesma barra no inventário: com muitos personagens, rolar até
	-- achar o certo era o gargalo.
	local _, inventoryCounter = criarBarraPesquisa(
		systemContext,
		invFrame,
		UDim2.fromScale(0.015, 0.125),
		UDim2.fromScale(0.97, 0.07),
		COLORS.blue,
		buscaInventario,
		function(texto)
			buscaInventario = texto
			refreshOpenFrames()
		end
	)

	invScroll = Instance.new("ScrollingFrame")
	invScroll.Size = UDim2.fromScale(0.97, 0.775)
	invScroll.Position = UDim2.fromScale(0.015, 0.21)
	invScroll.BackgroundColor3 = Color3.fromRGB(5, 8, 14)
	invScroll.BackgroundTransparency = 0.08
	invScroll.BorderSizePixel = 0
	invScroll.ScrollBarThickness = isMobile and 8 or 12
	invScroll.Parent = invFrame

	local invScrollStroke = Instance.new("UIStroke")
	invScrollStroke.Color = COLORS.blue
	invScrollStroke.Thickness = 2
	invScrollStroke.Transparency = 0.5
	invScrollStroke.Parent = invScroll

	-- Refresh inventário
	local refreshInventory = Instance.new("BindableFunction")
	refreshInventory.Name = "RefreshInventory"
	refreshInventory.Parent = systemGui

	refreshInventory.OnInvoke = function()
		limparContexto(inventoryRenderContext)
		inventoryRenderContext = novoContexto()
		for _, child in pairs(invScroll:GetChildren()) do
			if child:IsA("Frame") or child:IsA("TextLabel") then
				child.Parent = nil
			end
		end

		updatePlayerData()

		local cardConfig = uiScale.card
		prepararLista(invScroll)
		local porRaridadeInv = {}
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

			-- (V11) Busca também no inventário: com muitos personagens,
			-- rolar até achar o certo era o gargalo.
			if combinaBusca(charInfo, buscaInventario) then
				local chave = charInfo.rarity or "ROBLOXIANOS"
				porRaridadeInv[chave] = porRaridadeInv[chave] or {}
				table.insert(porRaridadeInv[chave], charInfo)
				index = index + 1
			end
		end

		local chavesInv = {}
		for chave in pairs(porRaridadeInv) do
			table.insert(chavesInv, chave)
		end
		table.sort(chavesInv, function(a, b)
			local ra = rarities[a] and rarities[a].order or 99
			local rb = rarities[b] and rarities[b].order or 99
			if ra == rb then
				return a < b
			end
			return ra < rb
		end)

		for ordem, chave in ipairs(chavesInv) do
			local info = rarities[chave]
			local grade = criarSecao(
				invScroll,
				chave,
				info and info.color or Color3.fromRGB(200, 200, 200),
				ordem,
				cardConfig,
				#porRaridadeInv[chave],
				inventoryRenderContext
			)
			for i, charInfo in ipairs(porRaridadeInv[chave]) do
				local card = createCharacterCard(charInfo, grade, cardConfig, true, inventoryRenderContext)
				card.LayoutOrder = i
			end
		end

		inventoryCounter.Text = (isMobile or uiScale.portrait) and tostring(index)
			or (tostring(index) .. (index == 1 and " PERSONAGEM" or " PERSONAGENS"))
		inventoryCounter.TextColor3 = index > 0 and COLORS.blue or COLORS.red

		if index == 0 then
			local vazio = Instance.new("TextLabel")
			vazio.Size = UDim2.new(1, 0, 0, 60)
			vazio.BackgroundTransparency = 1
			vazio.Text = buscaInventario ~= ""
					and ('Nenhum personagem seu combina com "' .. buscaInventario .. '".')
				or "Seu inventário está vazio. Personagens GRÁTIS chegam aqui automaticamente!"
			vazio.TextColor3 = COLORS.muted
			vazio.TextScaled = true
			vazio.TextWrapped = true
			vazio.Font = Enum.Font.Code
			vazio.Parent = invScroll
		end
		-- (V9) OS CARDS DE FORMA DESPERTA FORAM REMOVIDOS.
		--
		-- Até o V8 cada Despertar desbloqueado virava um card separado no
		-- inventário, gerado a partir de data.awakenedCharacters. Isso
		-- fazia sentido quando o Despertar era uma posse permanente que
		-- se equipava.
		--
		-- Agora o Despertar é uma FORMA TEMPORÁRIA do personagem normal,
		-- disparada pela barra do AwakeningMeterServer em combate. Não há
		-- o que equipar, então o card não tem função — ele só confundiria,
		-- mostrando algo clicável que não faz nada.
		--
		-- A informação do Despertar continua visível: aparece no card do
		-- personagem NORMAL, como faixa de informação.
		--
		-- A lista data.awakenedCharacters de quem jogou no sistema antigo
		-- é limpa no login pelo AwakeningSystemServer V5.

		-- (V11) O aviso de vazio agora é emitido logo após montar as seções,
		-- distinguindo inventário vazio de busca sem resultado. O bloco que
		-- ficava aqui dizia sempre "inventário vazio", o que seria mentira
		-- quando o jogador tem personagens e só filtrou por um nome.
	end

	-- ─────────────────────────────────────
	-- FUNÇÕES DE ABERTURA (chamadas pelo Menu Unificado)
	-- ─────────────────────────────────────

	_G.OpenCharacterShop = function()
		if isInvOpen then
			isInvOpen = false
			inventoryPanelMotion.hide()
		end
		isMenuOpen = true
		backdrop.Visible = true
		mainPanelMotion.open()
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
		mainPanelMotion.hide()
		if not isInvOpen then
			backdrop.Visible = false
		end
	end

	_G.OpenCharacterInventory = function()
		if isMenuOpen then
			isMenuOpen = false
			mainPanelMotion.hide()
		end
		isInvOpen = true
		backdrop.Visible = true
		inventoryPanelMotion.open()
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
		inventoryPanelMotion.hide()
		if not isMenuOpen then
			backdrop.Visible = false
		end
	end

	conectarContexto(systemContext, menuClose.Activated, function()
		playSound(sounds.close)
		isMenuOpen = false
		mainPanelMotion.close()
	end)

	conectarContexto(systemContext, invClose.Activated, function()
		playSound(sounds.close)
		isInvOpen = false
		inventoryPanelMotion.close()
	end)

	conectarContexto(systemContext, backdrop.InputBegan, function(input)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			playSound(sounds.close)
			if isMenuOpen then
				isMenuOpen = false
				mainPanelMotion.close()
			elseif isInvOpen then
				isInvOpen = false
				inventoryPanelMotion.close()
			end
		end
	end)
end

-- =====================================
-- INICIALIZAÇÃO
-- =====================================

-- =====================================
-- (V11) RESPONSIVO DE VERDADE
-- =====================================
-- getUIScale() lê a ViewportSize, mas o V10 chamava a função uma vez só,
-- na carga do script. Quem entrasse em retrato e girasse para paisagem
-- continuava com a grade calculada para a orientação antiga: cards
-- estreitos demais, colunas sobrando ou faltando.
--
-- Aqui a escala é recalculada quando a ViewportSize muda, e as telas
-- abertas se remontam. O refresh é adiado para o fim do quadro porque a
-- rotação dispara várias mudanças seguidas — remontar em cada uma
-- deixaria o menu piscando.
do
	local viewportConnection = nil
	local resizeGeneration = 0

	local function aoMudarViewport()
		resizeGeneration += 1
		local expectedGeneration = resizeGeneration
		task.delay(0.12, function()
			if expectedGeneration ~= resizeGeneration then
				return
			end
			uiScale = getUIScale()

			if mainFrame then
				mainFrame.Size = uiScale.menu
			end
			if mainAspectConstraint then
				mainAspectConstraint.AspectRatio = uiScale.panelAspect
				mainAspectConstraint.DominantAxis = uiScale.portrait and Enum.DominantAxis.Width
					or Enum.DominantAxis.Height
			end
			if invFrame then
				invFrame.Size = uiScale.menu
			end
			if inventoryAspectConstraint then
				inventoryAspectConstraint.AspectRatio = uiScale.panelAspect
				inventoryAspectConstraint.DominantAxis = uiScale.portrait and Enum.DominantAxis.Width
					or Enum.DominantAxis.Height
			end
			if mainCloseAspectConstraint then
				mainCloseAspectConstraint.DominantAxis = uiScale.portrait and Enum.DominantAxis.Width
					or Enum.DominantAxis.Height
			end
			if inventoryCloseAspectConstraint then
				inventoryCloseAspectConstraint.DominantAxis = uiScale.portrait and Enum.DominantAxis.Width
					or Enum.DominantAxis.Height
			end
			if mainTitleLabel then
				mainTitleLabel.Text = uiScale.portrait and "[ LOJA ]" or "[ PERSONAGENS ]  LOJA"
			end
			if inventoryTitleLabel then
				inventoryTitleLabel.Text = uiScale.portrait and "[ INVENTÁRIO ]"
					or "[ PERSONAGENS ]  INVENTÁRIO"
			end
			if inventoryHintLabel then
				inventoryHintLabel.Text = uiScale.portrait and "💰 VENDER" or "💰 PREÇO = VENDER"
			end
			for _, tabButton in ipairs(categoryTabButtons) do
				if tabButton.Parent then
					local icon = tabButton:GetAttribute("CategoryIcon") or "◆"
					local label = tabButton:GetAttribute("CategoryLabel") or ""
					tabButton.Text = uiScale.portrait and (icon .. "\n" .. label)
						or (icon .. " " .. label)
				end
			end

			refreshOpenFrames()
		end)
	end

	local function ligarCamera()
		if viewportConnection then
			viewportConnection:Disconnect()
			viewportConnection = nil
		end
		local camera = workspace.CurrentCamera
		if camera then
			viewportConnection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(aoMudarViewport)
			aoMudarViewport()
		end
	end

	ligarCamera()
	workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(ligarCamera)
end

task.spawn(refreshCatalogCharacters)

player.CharacterAdded:Connect(function()
	task.wait(1)
	updatePlayerData()
	refreshOpenFrames()
end)

createSystem()
task.spawn(updatePlayerData)

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

		print("[CHAR SYSTEM V13] Registrado no Menu Unificado: LOJA + INVENTÁRIO")
	end
end)

print([[
╔══════════════════════════════════════════════════════╗
║  CHARACTER SYSTEM CLIENT V13 — CARREGADO            ║
╠══════════════════════════════════════════════════════╣
║  SUBSTITUI: CharacterSystemClient V12                ║
╠══════════════════════════════════════════════════════╣
║  * Loja e inventário redesenhados em retro-neon      ║
║  * Busca: nome/descrição/raridade/categoria/emblema   ║
║  * Cards proporcionais por orientação e viewport     ║
║  * Selos de origem + emblemas de raridade            ║
║  * Entrada e saída com mola amortecida                ║
║  * Tweens e conexões limpos em cada render            ║
║  * Informações, Lore e Despertar em abas animadas      ║
║  * Texto progressivo com opção de revelar tudo         ║
╚══════════════════════════════════════════════════════╝
]])
