-- ============================================
-- ADMIN MENU CLIENT V12 — WIZARD DO DESPERTAR EM ETAPAS
-- Coloque em StarterPlayer > StarterPlayerScripts
-- Nome: "AdminMenuClient"
-- SUBSTITUI: AdminMenuClient V11
-- ============================================
-- (V12) DOIS PROBLEMAS DO PAINEL DE DESPERTAR:
--
-- 1. TUDO NUMA TELA SÓ. Personagem, badge, nome, imagem, vida, história
--    e os sete campos de Tool disputavam o mesmo espaço vertical, e com
--    a história somada os campos ficaram colados. Agora são 3 etapas,
--    no mesmo desenho do wizard de personagem normal:
--      1/3 PERSONAGEM  — base, nome de exibição, badge
--      2/3 APARÊNCIA   — imagem, vida, história
--      3/3 HABILIDADES — as 7 Tools e o salvar
--
-- 2. O BADGE AINDA ERA OBRIGATÓRIO AQUI. Ele virou opcional no
--    AwakeningSystemServer V5, mas o botão de salvar continuava barrando
--    sem ele — dava para configurar no servidor e não conseguir salvar
--    pelo painel. Agora só o personagem base é exigido.
-- ============================================
-- ============================================
-- (V11) CAMPO HISTÓRIA no wizard de Despertar.
-- O card do Despertar mostra imagem, nome, história e as Tools. O
-- payload deste wizard é montado explicitamente, então sem um campo aqui
-- a história do servidor ficaria sempre vazia por mais que a definição
-- aceitasse o dado.
-- REMOVER:   AdminMenuClient V9
-- ============================================
-- (V10) ALTERAÇÃO ÚNICA — TEXTO, NENHUMA LÓGICA
-- O AwakeningSystemServer_V4 e o CharacterCatalogServer_V7 passaram a
-- aceitar UM ID de Model com várias Tools dentro, no lugar de um ID por
-- Tool. A lógica do painel já funcionava para isso sem mudar nada (é o
-- mesmo campo de ID), mas o recurso ficava invisível — ninguém
-- adivinharia que pode pôr um Model naquele campo.
--
-- Os DOIS formulários receberam a dica:
--   • PASSO 2/3 do wizard (personagem NORMAL): "máx. 7 no TOTAL", o
--     aviso agora diz "UM Model com várias Tools dentro vale por
--     todas", e o primeiro campo virou "ID de uma Tool OU de um Model
--     com várias".
--   • Formulário de DESPERTAR: "máx. 7 no TOTAL — 1 ID de Model com
--     Tools dentro vale por todas", primeiro campo "Tool ou Model".
--
-- O "no TOTAL" também corrige o sentido: o teto agora é sobre a
-- quantidade de Tools, não de IDs.
--
-- Instalar isto é OPCIONAL — sem o V10 o Model funciona igual, você só
-- não vê a dica no painel.
-- ============================================
-- DEPENDE DE: AdminRegistryServer_V1 (novo, no ServerScriptService)
--             CharacterCatalogServer_V7 / AwakeningSystemServer_V4
-- ============================================
-- (V9) ALTERAÇÕES:
-- • LISTA "ADMIN_IDS" REMOVIDA DO CÓDIGO: o painel agora pergunta
--   ao servidor (remote IsAdminCheck do AdminRegistryServer_V1) se
--   você é admin. Quem NÃO é admin re-checa a cada 30s — então se
--   o dono te adicionar (;addadmin ou aba ADMINS) com o servidor
--   aberto, o painel aparece SEM precisar relogar.
-- • ✏️ EDITAR PERSONAGEM: cada personagem da lista do catálogo
--   ganhou o botão EDITAR — abre o wizard de 3 passos JÁ
--   PREENCHIDO com os dados atuais (Image ID, HP, categoria,
--   valor, as 7 Tools, lore, descrição, raridade). O nome fica
--   TRAVADO na edição (mudar o nome criaria um personagem novo).
--   Publicar sobrescreve em todos os servidores — o
--   CharacterCatalogServer_V5 anuncia "✏️ atualizou".
-- • ✏️ EDITAR DESPERTAR: mesma coisa pros Despertares configurados
--   (formulário pré-preenchido, personagem base travado).
-- • NOVA ABA "ADMINS": adicionar admin por USERNAME ou ID (salvo
--   no DataStore, vale em todos os servidores, sem Studio), lista
--   dos admins atuais com quem adicionou, e REMOVER com dupla
--   confirmação. O DONO aparece com 🔑 e não pode ser removido.
-- • Agora são 6 abas: Moedas / Personagens / Catálogo / Admins /
--   Jogadores / Ações.
-- ============================================
-- CORRECOES V5 (mantidas):
-- • REMOVIDO UserInputService / KeyCode.F9
-- • selectButton na aba Jogadores atualiza TODOS os inputs
-- • Interface criada UMA VEZ apenas
-- ============================================
-- REUTILIZADO:
-- • IsAdminCheck / AdminRegistryAdd/Remove/List .. AdminRegistryServer_V1
-- • Wizard 3 passos, helpers label/button/textBox e dupla
--   confirmação de REMOVER ...................... AdminMenuClient_V8
-- • Upsert do catálogo (mesmo nome = edita) ..... CharacterCatalogServer_V5
-- • Upsert do Despertar ......................... AwakeningSystemServer_V2
-- ============================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- =====================================
-- (V9) VERIFICAÇÃO DE ADMIN — VIA SERVIDOR (SEM LISTA NO CÓDIGO)
-- Quem decide é o AdminRegistryServer_V1 (remote IsAdminCheck).
-- O servidor SEMPRE revalida cada ação de qualquer jeito — isto
-- aqui só controla a exibição do painel.
-- =====================================

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local isAdminCheck = remotes:WaitForChild("IsAdminCheck", 30)

if not isAdminCheck then
	warn("[ADMIN MENU V9] IsAdminCheck não encontrado — AdminRegistryServer_V1 está no ServerScriptService?")
	return
end

local function checkIsAdmin()
	local ok, result = pcall(function()
		return isAdminCheck:InvokeServer()
	end)
	return ok and result == true
end

if not checkIsAdmin() then
	-- Não é admin agora. Re-checa a cada 30s: se o dono te adicionar
	-- (;addadmin ou aba ADMINS) com o servidor aberto, o painel
	-- aparece SEM precisar relogar.
	while true do
		task.wait(30)
		if checkIsAdmin() then
			break
		end
	end
end

-- =====================================
-- AGUARDAR REMOTES
-- =====================================

local adminGiveCoins = remotes:WaitForChild("AdminGiveCoins")
local adminGiveBounty = remotes:WaitForChild("AdminGiveBounty")
local adminGiveCharacter = remotes:WaitForChild("AdminGiveCharacter")
local adminGiveAllCharacters = remotes:WaitForChild("AdminGiveAllCharacters")
local adminResetData = remotes:WaitForChild("AdminResetData")
local adminTeleport = remotes:WaitForChild("AdminTeleport")
local adminKill = remotes:WaitForChild("AdminKill")
local adminKick = remotes:WaitForChild("AdminKick")
local getPlayerList = remotes:WaitForChild("GetPlayerList")

-- Remotes do catálogo e do despertar
local adminCatalogAdd = remotes:WaitForChild("AdminCatalogAddCharacter")
local adminCatalogRemove = remotes:WaitForChild("AdminCatalogRemoveCharacter")
local adminCatalogList = remotes:WaitForChild("AdminCatalogListCharacters")
local adminSetAwakening = remotes:WaitForChild("AdminSetAwakening")
local adminRemoveAwakening = remotes:WaitForChild("AdminRemoveAwakening")
local adminListAwakenings = remotes:WaitForChild("AdminListAwakenings")

-- (V9) Remotes do registro de admins (AdminRegistryServer_V1)
local adminRegistryAdd = remotes:WaitForChild("AdminRegistryAdd", 10)
local adminRegistryRemove = remotes:WaitForChild("AdminRegistryRemove", 10)
local adminRegistryList = remotes:WaitForChild("AdminRegistryList", 10)

-- =====================================
-- SONS
-- =====================================

local sounds = {
	hover = "rbxassetid://12846056",
	click = "rbxassetid://156785206",
	open = "rbxassetid://157167203",
	close = "rbxassetid://157167205",
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
-- CORES
-- =====================================

local COLORS = {
	background = Color3.fromRGB(20, 20, 20),
	panel = Color3.fromRGB(30, 30, 30),
	header = Color3.fromRGB(139, 0, 0),
	border = Color3.fromRGB(255, 255, 255),
	success = Color3.fromRGB(0, 200, 0),
	error = Color3.fromRGB(200, 0, 0),
	warning = Color3.fromRGB(255, 200, 0),
	catalog = Color3.fromRGB(0, 130, 200),
	awaken = Color3.fromRGB(150, 0, 200),
}

-- =====================================
-- TOAST DE RESULTADO (catálogo/despertar/admins)
-- =====================================

local function showToast(message, isSuccess)
	local notification = Instance.new("ScreenGui")
	notification.Name = "AdminCatalogToast"
	notification.DisplayOrder = 210
	notification.Parent = playerGui

	local frame = Instance.new("Frame")
	frame.Size = UDim2.new(0.4, 0, 0.09, 0)
	frame.Position = UDim2.new(0.3, 0, 0.14, 0)
	frame.BackgroundColor3 = COLORS.background
	frame.BorderColor3 = isSuccess and COLORS.success or COLORS.error
	frame.BorderSizePixel = 3
	frame.Parent = notification

	local text = Instance.new("TextLabel")
	text.Size = UDim2.new(1, -10, 1, 0)
	text.Position = UDim2.new(0, 5, 0, 0)
	text.BackgroundTransparency = 1
	text.Text = message
	text.TextColor3 = Color3.new(1, 1, 1)
	text.TextScaled = true
	text.TextWrapped = true
	text.Font = Enum.Font.Arcade
	text.Parent = frame

	task.delay(3.5, function()
		if notification.Parent then
			notification.Parent = nil
		end
	end)
end

-- =====================================
-- INTERFACE
-- =====================================

local isOpen = false
local screenGui = nil
local mainFrame = nil

local playerInput = nil
local charPlayerInput = nil
local actionsPlayerInput = nil

local function createAdminInterface()
	if screenGui then
		screenGui.Parent = nil
	end

	screenGui = Instance.new("ScreenGui")
	screenGui.Name = "AdminMenuV9"
	screenGui.ResetOnSpawn = false
	screenGui.DisplayOrder = 100
	screenGui.Parent = playerGui

	mainFrame = Instance.new("Frame")
	mainFrame.Size = UDim2.new(0.6, 0, 0.82, 0)
	mainFrame.Position = UDim2.new(0.2, 0, 0.09, 0)
	mainFrame.BackgroundColor3 = COLORS.background
	mainFrame.BorderColor3 = COLORS.border
	mainFrame.BorderSizePixel = 4
	mainFrame.Visible = false
	mainFrame.Parent = screenGui

	local mainCorner = Instance.new("UICorner")
	mainCorner.CornerRadius = UDim.new(0, 6)
	mainCorner.Parent = mainFrame

	-- Header
	local header = Instance.new("Frame")
	header.Size = UDim2.new(1, 0, 0.08, 0)
	header.BackgroundColor3 = COLORS.header
	header.BorderSizePixel = 0
	header.Parent = mainFrame

	local headerCorner = Instance.new("UICorner")
	headerCorner.CornerRadius = UDim.new(0, 6)
	headerCorner.Parent = header

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(0.82, 0, 1, 0)
	title.Position = UDim2.new(0.02, 0, 0, 0)
	title.BackgroundTransparency = 1
	title.Text = "PAINEL ADMINISTRATIVO"
	title.TextColor3 = COLORS.border
	title.TextScaled = true
	title.Font = Enum.Font.Arcade
	title.Parent = header

	local closeButton = Instance.new("TextButton")
	closeButton.Size = UDim2.new(0.05, 0, 0.8, 0)
	closeButton.Position = UDim2.new(0.94, 0, 0.1, 0)
	closeButton.BackgroundColor3 = COLORS.error
	closeButton.BorderSizePixel = 0
	closeButton.Text = "X"
	closeButton.TextColor3 = COLORS.border
	closeButton.TextScaled = true
	closeButton.Font = Enum.Font.Arcade
	closeButton.Parent = header

	-- Tabs
	local tabsFrame = Instance.new("Frame")
	tabsFrame.Size = UDim2.new(1, 0, 0.07, 0)
	tabsFrame.Position = UDim2.new(0, 0, 0.08, 0)
	tabsFrame.BackgroundColor3 = COLORS.panel
	tabsFrame.BorderSizePixel = 0
	tabsFrame.Parent = mainFrame

	local contentFrame = Instance.new("Frame")
	contentFrame.Size = UDim2.new(0.98, 0, 0.84, 0)
	contentFrame.Position = UDim2.new(0.01, 0, 0.15, 0)
	contentFrame.BackgroundColor3 = COLORS.panel
	contentFrame.BorderColor3 = COLORS.border
	contentFrame.BorderSizePixel = 2
	contentFrame.Parent = mainFrame

	local contentCorner = Instance.new("UICorner")
	contentCorner.CornerRadius = UDim.new(0, 4)
	contentCorner.Parent = contentFrame

	-- (V9) 6 abas agora
	local tabNames = { "Moedas", "Personagens", "Catalogo", "Admins", "Jogadores", "Acoes" }
	local tabContents = {}
	local tabButtons = {}
	local activeTab = 1
	local tabWidth = 0.155
	local tabStep = 0.165

	local function setActiveTab(index)
		activeTab = index
		for i, btn in ipairs(tabButtons) do
			btn.BackgroundColor3 = i == index and COLORS.warning or COLORS.panel
			btn.TextColor3 = i == index and COLORS.background or COLORS.border
		end
		for i, cont in ipairs(tabContents) do
			cont.Visible = i == index
		end
	end

	for i, tabName in ipairs(tabNames) do
		local tabButton = Instance.new("TextButton")
		tabButton.Size = UDim2.new(tabWidth, 0, 0.9, 0)
		tabButton.Position = UDim2.new(0.005 + (i - 1) * tabStep, 0, 0.05, 0)
		tabButton.BackgroundColor3 = i == 1 and COLORS.warning or COLORS.panel
		tabButton.BorderColor3 = COLORS.border
		tabButton.BorderSizePixel = 1
		tabButton.Text = tabName:upper()
		tabButton.TextColor3 = i == 1 and COLORS.background or COLORS.border
		tabButton.TextScaled = true
		tabButton.Font = Enum.Font.Arcade
		tabButton.Parent = tabsFrame

		tabButtons[i] = tabButton

		local content = Instance.new("Frame")
		content.Size = UDim2.new(1, 0, 1, 0)
		content.BackgroundTransparency = 1
		content.Visible = i == 1
		content.Parent = contentFrame
		tabContents[i] = content

		local capturedIndex = i
		tabButton.MouseButton1Click:Connect(function()
			playSound(sounds.click)
			setActiveTab(capturedIndex)
		end)
	end

	-- ============================
	-- TAB 1: MOEDAS (idêntico ao V8)
	-- ============================

	local coinsContent = tabContents[1]

	local coinsTitle = Instance.new("TextLabel")
	coinsTitle.Size = UDim2.new(1, 0, 0.08, 0)
	coinsTitle.BackgroundTransparency = 1
	coinsTitle.Text = "[ GERENCIAR MOEDAS E BOUNTY ]"
	coinsTitle.TextColor3 = COLORS.warning
	coinsTitle.TextScaled = true
	coinsTitle.Font = Enum.Font.Arcade
	coinsTitle.Parent = coinsContent

	local playerLabel = Instance.new("TextLabel")
	playerLabel.Size = UDim2.new(0.2, 0, 0.08, 0)
	playerLabel.Position = UDim2.new(0.05, 0, 0.12, 0)
	playerLabel.BackgroundTransparency = 1
	playerLabel.Text = "JOGADOR:"
	playerLabel.TextColor3 = COLORS.border
	playerLabel.TextScaled = true
	playerLabel.Font = Enum.Font.Arcade
	playerLabel.Parent = coinsContent

	playerInput = Instance.new("TextBox")
	playerInput.Size = UDim2.new(0.7, 0, 0.08, 0)
	playerInput.Position = UDim2.new(0.26, 0, 0.12, 0)
	playerInput.BackgroundColor3 = COLORS.background
	playerInput.BorderColor3 = COLORS.border
	playerInput.BorderSizePixel = 2
	playerInput.Text = ""
	playerInput.PlaceholderText = "Nome do jogador..."
	playerInput.TextColor3 = COLORS.border
	playerInput.PlaceholderColor3 = Color3.fromRGB(150, 150, 150)
	playerInput.TextScaled = true
	playerInput.Font = Enum.Font.Arcade
	playerInput.Parent = coinsContent

	local amountLabel = Instance.new("TextLabel")
	amountLabel.Size = UDim2.new(0.2, 0, 0.08, 0)
	amountLabel.Position = UDim2.new(0.05, 0, 0.23, 0)
	amountLabel.BackgroundTransparency = 1
	amountLabel.Text = "QTDE:"
	amountLabel.TextColor3 = COLORS.border
	amountLabel.TextScaled = true
	amountLabel.Font = Enum.Font.Arcade
	amountLabel.Parent = coinsContent

	local amountInput = Instance.new("TextBox")
	amountInput.Size = UDim2.new(0.7, 0, 0.08, 0)
	amountInput.Position = UDim2.new(0.26, 0, 0.23, 0)
	amountInput.BackgroundColor3 = COLORS.background
	amountInput.BorderColor3 = COLORS.border
	amountInput.BorderSizePixel = 2
	amountInput.Text = ""
	amountInput.PlaceholderText = "Numero..."
	amountInput.TextColor3 = COLORS.border
	amountInput.PlaceholderColor3 = Color3.fromRGB(150, 150, 150)
	amountInput.TextScaled = true
	amountInput.Font = Enum.Font.Arcade
	amountInput.Parent = coinsContent

	local giveCoinsBtn = Instance.new("TextButton")
	giveCoinsBtn.Size = UDim2.new(0.42, 0, 0.11, 0)
	giveCoinsBtn.Position = UDim2.new(0.04, 0, 0.35, 0)
	giveCoinsBtn.BackgroundColor3 = COLORS.success
	giveCoinsBtn.BorderColor3 = COLORS.border
	giveCoinsBtn.BorderSizePixel = 2
	giveCoinsBtn.Text = "+ MOEDAS"
	giveCoinsBtn.TextColor3 = COLORS.background
	giveCoinsBtn.TextScaled = true
	giveCoinsBtn.Font = Enum.Font.Arcade
	giveCoinsBtn.Parent = coinsContent

	local giveBountyBtn = Instance.new("TextButton")
	giveBountyBtn.Size = UDim2.new(0.42, 0, 0.11, 0)
	giveBountyBtn.Position = UDim2.new(0.54, 0, 0.35, 0)
	giveBountyBtn.BackgroundColor3 = Color3.fromRGB(255, 140, 0)
	giveBountyBtn.BorderColor3 = COLORS.border
	giveBountyBtn.BorderSizePixel = 2
	giveBountyBtn.Text = "+ BOUNTY"
	giveBountyBtn.TextColor3 = COLORS.background
	giveBountyBtn.TextScaled = true
	giveBountyBtn.Font = Enum.Font.Arcade
	giveBountyBtn.Parent = coinsContent

	giveCoinsBtn.MouseButton1Click:Connect(function()
		playSound(sounds.click)
		local name = playerInput.Text
		local amount = tonumber(amountInput.Text)
		if name ~= "" and amount then
			adminGiveCoins:FireServer(name, amount)
			amountInput.Text = ""
		end
	end)

	giveBountyBtn.MouseButton1Click:Connect(function()
		playSound(sounds.click)
		local name = playerInput.Text
		local amount = tonumber(amountInput.Text)
		if name ~= "" and amount then
			adminGiveBounty:FireServer(name, amount)
			amountInput.Text = ""
		end
	end)

	-- ============================
	-- TAB 2: PERSONAGENS (idêntico ao V8 — dar personagem a um jogador)
	-- ============================

	local charsContent = tabContents[2]

	local charsTitle = Instance.new("TextLabel")
	charsTitle.Size = UDim2.new(1, 0, 0.08, 0)
	charsTitle.BackgroundTransparency = 1
	charsTitle.Text = "[ DAR PERSONAGEM A UM JOGADOR ]"
	charsTitle.TextColor3 = COLORS.warning
	charsTitle.TextScaled = true
	charsTitle.Font = Enum.Font.Arcade
	charsTitle.Parent = charsContent

	local charPlayerLabel = Instance.new("TextLabel")
	charPlayerLabel.Size = UDim2.new(0.2, 0, 0.08, 0)
	charPlayerLabel.Position = UDim2.new(0.05, 0, 0.12, 0)
	charPlayerLabel.BackgroundTransparency = 1
	charPlayerLabel.Text = "JOGADOR:"
	charPlayerLabel.TextColor3 = COLORS.border
	charPlayerLabel.TextScaled = true
	charPlayerLabel.Font = Enum.Font.Arcade
	charPlayerLabel.Parent = charsContent

	charPlayerInput = Instance.new("TextBox")
	charPlayerInput.Size = UDim2.new(0.7, 0, 0.08, 0)
	charPlayerInput.Position = UDim2.new(0.26, 0, 0.12, 0)
	charPlayerInput.BackgroundColor3 = COLORS.background
	charPlayerInput.BorderColor3 = COLORS.border
	charPlayerInput.BorderSizePixel = 2
	charPlayerInput.Text = ""
	charPlayerInput.PlaceholderText = "Nome do jogador..."
	charPlayerInput.TextColor3 = COLORS.border
	charPlayerInput.PlaceholderColor3 = Color3.fromRGB(150, 150, 150)
	charPlayerInput.TextScaled = true
	charPlayerInput.Font = Enum.Font.Arcade
	charPlayerInput.Parent = charsContent

	local charNameLabel = Instance.new("TextLabel")
	charNameLabel.Size = UDim2.new(0.2, 0, 0.08, 0)
	charNameLabel.Position = UDim2.new(0.05, 0, 0.23, 0)
	charNameLabel.BackgroundTransparency = 1
	charNameLabel.Text = "PERSONAGEM:"
	charNameLabel.TextColor3 = COLORS.border
	charNameLabel.TextScaled = true
	charNameLabel.Font = Enum.Font.Arcade
	charNameLabel.Parent = charsContent

	local charNameInput = Instance.new("TextBox")
	charNameInput.Size = UDim2.new(0.7, 0, 0.08, 0)
	charNameInput.Position = UDim2.new(0.26, 0, 0.23, 0)
	charNameInput.BackgroundColor3 = COLORS.background
	charNameInput.BorderColor3 = COLORS.border
	charNameInput.BorderSizePixel = 2
	charNameInput.Text = ""
	charNameInput.PlaceholderText = "Nome exato do personagem..."
	charNameInput.TextColor3 = COLORS.border
	charNameInput.PlaceholderColor3 = Color3.fromRGB(150, 150, 150)
	charNameInput.TextScaled = true
	charNameInput.Font = Enum.Font.Arcade
	charNameInput.Parent = charsContent

	local giveCharBtn = Instance.new("TextButton")
	giveCharBtn.Size = UDim2.new(0.42, 0, 0.11, 0)
	giveCharBtn.Position = UDim2.new(0.04, 0, 0.35, 0)
	giveCharBtn.BackgroundColor3 = COLORS.success
	giveCharBtn.BorderColor3 = COLORS.border
	giveCharBtn.BorderSizePixel = 2
	giveCharBtn.Text = "DAR PERSONAGEM"
	giveCharBtn.TextColor3 = COLORS.background
	giveCharBtn.TextScaled = true
	giveCharBtn.Font = Enum.Font.Arcade
	giveCharBtn.Parent = charsContent

	local giveAllBtn = Instance.new("TextButton")
	giveAllBtn.Size = UDim2.new(0.42, 0, 0.11, 0)
	giveAllBtn.Position = UDim2.new(0.54, 0, 0.35, 0)
	giveAllBtn.BackgroundColor3 = Color3.fromRGB(0, 100, 200)
	giveAllBtn.BorderColor3 = COLORS.border
	giveAllBtn.BorderSizePixel = 2
	giveAllBtn.Text = "DAR TODOS"
	giveAllBtn.TextColor3 = COLORS.border
	giveAllBtn.TextScaled = true
	giveAllBtn.Font = Enum.Font.Arcade
	giveAllBtn.Parent = charsContent

	giveCharBtn.MouseButton1Click:Connect(function()
		playSound(sounds.click)
		local name = charPlayerInput.Text
		local charName = charNameInput.Text
		if name ~= "" and charName ~= "" then
			adminGiveCharacter:FireServer(name, charName)
			charNameInput.Text = ""
		end
	end)

	giveAllBtn.MouseButton1Click:Connect(function()
		playSound(sounds.click)
		local name = charPlayerInput.Text
		if name ~= "" then
			adminGiveAllCharacters:FireServer(name)
		end
	end)

	-- ============================
	-- TAB 3: CATÁLOGO — WIZARD DE 3 PASSOS + DESPERTAR
	-- (V9) agora com botão ✏️ EDITAR nos dois
	-- ============================

	local catalogContent = tabContents[3]

	local wizardDraft = {}
	local awakenDraft = {}
	local currentView = "list" -- list | step1 | step2 | step3 | awaken

	local function resetWizardDraft()
		wizardDraft = {
			editing = false, -- (V9)
			name = "",
			imageId = "",
			health = "",
			category = "Shop",
			value = "",
			gamepassId = "",
			badgeId = "",
			toolIds = { "", "", "", "", "", "", "" },
			lore = "",
			description = "",
			rarity = "ROBLOXIANOS",
		}
	end

	local function resetAwakenDraft()
		awakenDraft = {
			editing = false, -- (V9)
			characterName = "",
			badgeId = "",
			imageId = "",
			displayName = "",
			health = "",
			lore = "",
			toolIds = { "", "", "", "", "", "", "" },
		}
	end

	resetWizardDraft()
	resetAwakenDraft()

	-- (V9) Carrega uma definição existente no rascunho do wizard
	-- (usado pelo botão ✏️ EDITAR — nome fica travado)
	local function loadDefIntoWizard(def)
		resetWizardDraft()
		wizardDraft.editing = true
		wizardDraft.name = def.name or ""
		wizardDraft.imageId = (tonumber(def.imageId) and tonumber(def.imageId) > 0) and tostring(def.imageId) or ""
		wizardDraft.health = def.health and tostring(def.health) or ""
		wizardDraft.category = def.category or "Shop"
		wizardDraft.value = (tonumber(def.value) and tonumber(def.value) ~= 0) and tostring(def.value) or ""
		wizardDraft.gamepassId = (tonumber(def.gamepassId) and tonumber(def.gamepassId) > 0) and tostring(def.gamepassId) or ""
		wizardDraft.badgeId = (tonumber(def.badgeId) and tonumber(def.badgeId) > 0) and tostring(def.badgeId) or ""
		for i = 1, 7 do
			local id = def.toolIds and def.toolIds[i]
			wizardDraft.toolIds[i] = id and tostring(id) or ""
		end
		wizardDraft.lore = def.lore or ""
		wizardDraft.description = def.description or ""
		wizardDraft.rarity = def.rarity or "ROBLOXIANOS"
	end

	-- (V9) Mesma coisa pro formulário de Despertar
	local function loadDefIntoAwaken(def)
		resetAwakenDraft()
		awakenDraft.editing = true
		awakenDraft.characterName = def.characterName or ""
		awakenDraft.badgeId = def.badgeId and tostring(def.badgeId) or ""
		awakenDraft.imageId = (tonumber(def.imageId) and tonumber(def.imageId) > 0) and tostring(def.imageId) or ""
		awakenDraft.displayName = def.displayName or ""
		awakenDraft.health = def.health and tostring(def.health) or ""
		awakenDraft.lore = def.lore or ""
		for i = 1, 7 do
			local id = def.toolIds and def.toolIds[i]
			awakenDraft.toolIds[i] = id and tostring(id) or ""
		end
	end

	local renderCatalogView -- forward declaration

	local function clearCatalog()
		for _, child in pairs(catalogContent:GetChildren()) do
			child.Parent = nil
		end
	end

	-- ---------- helpers de UI ----------

	local function label(parent, text, size, pos, color)
		local lbl = Instance.new("TextLabel")
		lbl.Size = size
		lbl.Position = pos
		lbl.BackgroundTransparency = 1
		lbl.Text = text
		lbl.TextColor3 = color or COLORS.border
		lbl.TextScaled = true
		lbl.Font = Enum.Font.Arcade
		lbl.TextXAlignment = Enum.TextXAlignment.Left
		lbl.Parent = parent
		return lbl
	end

	local function button(parent, text, color, size, pos)
		local btn = Instance.new("TextButton")
		btn.Size = size
		btn.Position = pos
		btn.BackgroundColor3 = color
		btn.BorderColor3 = COLORS.border
		btn.BorderSizePixel = 2
		btn.Text = text
		btn.TextColor3 = Color3.new(1, 1, 1)
		btn.TextScaled = true
		btn.Font = Enum.Font.Arcade
		btn.Parent = parent
		btn.MouseButton1Click:Connect(function()
			playSound(sounds.click)
		end)
		return btn
	end

	local function textBox(parent, placeholder, size, pos, default)
		local box = Instance.new("TextBox")
		box.Size = size
		box.Position = pos
		box.BackgroundColor3 = COLORS.background
		box.BorderColor3 = COLORS.border
		box.BorderSizePixel = 2
		box.PlaceholderText = placeholder
		box.Text = default or ""
		box.TextColor3 = COLORS.border
		box.PlaceholderColor3 = Color3.fromRGB(140, 140, 140)
		box.TextScaled = true
		box.Font = Enum.Font.Code
		box.ClearTextOnFocus = false
		box.Parent = parent
		return box
	end

	-- ---------- VIEW: LISTA DO CATÁLOGO ----------

	local function renderList()
		label(catalogContent, "[ CATÁLOGO DE PERSONAGENS ]", UDim2.new(1, 0, 0.07, 0), UDim2.new(0, 0, 0, 0), COLORS.warning)

		local newBtn = button(catalogContent, "+ NOVO PERSONAGEM", COLORS.success, UDim2.new(0.47, 0, 0.08, 0), UDim2.new(0.02, 0, 0.08, 0))
		newBtn.MouseButton1Click:Connect(function()
			resetWizardDraft()
			currentView = "step1"
			renderCatalogView()
		end)

		local awakenBtn = button(catalogContent, "⚡ CONFIGURAR DESPERTAR", COLORS.awaken, UDim2.new(0.47, 0, 0.08, 0), UDim2.new(0.51, 0, 0.08, 0))
		awakenBtn.MouseButton1Click:Connect(function()
			resetAwakenDraft()
			currentView = "awaken"
			renderCatalogView()
		end)

		local listScroll = Instance.new("ScrollingFrame")
		listScroll.Size = UDim2.new(0.98, 0, 0.8, 0)
		listScroll.Position = UDim2.new(0.01, 0, 0.18, 0)
		listScroll.BackgroundColor3 = COLORS.background
		listScroll.BorderColor3 = COLORS.border
		listScroll.BorderSizePixel = 2
		listScroll.ScrollBarThickness = 8
		listScroll.Parent = catalogContent

		-- Personagens do catálogo
		local ok, list = pcall(function()
			return adminCatalogList:InvokeServer()
		end)

		-- Despertares configurados
		local okA, awakenList = pcall(function()
			return adminListAwakenings:InvokeServer()
		end)

		local yPos = 5

		if ok and type(list) == "table" and #list > 0 then
			for _, def in ipairs(list) do
				local row = Instance.new("Frame")
				row.Size = UDim2.new(0.97, 0, 0, 44)
				row.Position = UDim2.new(0.015, 0, 0, yPos)
				row.BackgroundColor3 = COLORS.panel
				row.BorderColor3 = COLORS.border
				row.BorderSizePixel = 1
				row.Parent = listScroll

				label(
					row,
					string.format("%s [%s] valor=%s | %s", def.name, def.category, tostring(def.value), def.rarity or "?"),
					UDim2.new(0.49, 0, 1, 0),
					UDim2.new(0.02, 0, 0, 0),
					COLORS.border
				)

				-- (V9) EDITAR: abre o wizard já preenchido com os dados atuais
				local editBtn = button(row, "✏️ EDITAR", COLORS.catalog, UDim2.new(0.17, 0, 0.8, 0), UDim2.new(0.52, 0, 0.1, 0))
				editBtn.MouseButton1Click:Connect(function()
					loadDefIntoWizard(def)
					currentView = "step1"
					renderCatalogView()
				end)

				local removeBtn = button(row, "REMOVER", COLORS.error, UDim2.new(0.27, 0, 0.8, 0), UDim2.new(0.71, 0, 0.1, 0))
				local confirming = false
				removeBtn.MouseButton1Click:Connect(function()
					if not confirming then
						confirming = true
						removeBtn.Text = "CONFIRMAR?"
						task.delay(3, function()
							if removeBtn.Parent and confirming then
								confirming = false
								removeBtn.Text = "REMOVER"
							end
						end)
						return
					end
					local okr, success, msg = pcall(function()
						return adminCatalogRemove:InvokeServer(def.name)
					end)
					showToast(okr and (msg or "Removido!") or "Erro ao remover!", okr and success)
					currentView = "list"
					renderCatalogView()
				end)

				yPos = yPos + 48
			end
		else
			label(listScroll, "Nenhum personagem no catálogo ainda. Clique em + NOVO PERSONAGEM!", UDim2.new(0.95, 0, 0, 30), UDim2.new(0.02, 0, 0, yPos), Color3.fromRGB(150, 150, 150))
			yPos = yPos + 40
		end

		-- Seção de Despertares configurados
		if okA and type(awakenList) == "table" and #awakenList > 0 then
			label(listScroll, "⚡ DESPERTARES CONFIGURADOS:", UDim2.new(0.95, 0, 0, 26), UDim2.new(0.02, 0, 0, yPos + 6), COLORS.awaken)
			yPos = yPos + 36

			for _, def in ipairs(awakenList) do
				local row = Instance.new("Frame")
				row.Size = UDim2.new(0.97, 0, 0, 40)
				row.Position = UDim2.new(0.015, 0, 0, yPos)
				row.BackgroundColor3 = Color3.fromRGB(40, 20, 50)
				row.BorderColor3 = COLORS.awaken
				row.BorderSizePixel = 1
				row.Parent = listScroll

				label(
					row,
					string.format("%s → %s | Badge: %s", def.characterName, def.displayName or "?", tostring(def.badgeId)),
					UDim2.new(0.49, 0, 1, 0),
					UDim2.new(0.02, 0, 0, 0),
					Color3.fromRGB(220, 180, 255)
				)

				-- (V9) EDITAR Despertar: formulário pré-preenchido
				local editBtn = button(row, "✏️ EDITAR", COLORS.awaken, UDim2.new(0.17, 0, 0.8, 0), UDim2.new(0.52, 0, 0.1, 0))
				editBtn.MouseButton1Click:Connect(function()
					loadDefIntoAwaken(def)
					currentView = "awaken"
					renderCatalogView()
				end)

				local removeBtn = button(row, "REMOVER", COLORS.error, UDim2.new(0.27, 0, 0.8, 0), UDim2.new(0.71, 0, 0.1, 0))
				local confirming = false
				removeBtn.MouseButton1Click:Connect(function()
					if not confirming then
						confirming = true
						removeBtn.Text = "CONFIRMAR?"
						task.delay(3, function()
							if removeBtn.Parent and confirming then
								confirming = false
								removeBtn.Text = "REMOVER"
							end
						end)
						return
					end
					local okr, success, msg = pcall(function()
						return adminRemoveAwakening:InvokeServer(def.characterName)
					end)
					showToast(okr and (msg or "Removido!") or "Erro ao remover!", okr and success)
					currentView = "list"
					renderCatalogView()
				end)

				yPos = yPos + 44
			end
		end

		listScroll.CanvasSize = UDim2.new(0, 0, 0, yPos + 10)
	end

	-- ---------- VIEW: PASSO 1 — APARÊNCIA + CATEGORIA + VALOR ----------

	local CATEGORY_OPTIONS = {
		{ key = "Shop", label = "LOJA" },
		{ key = "Reward", label = "RECOMPENSA" },
		{ key = "Gamepass", label = "GAMEPASS" },
		{ key = "Badge", label = "EMBLEMA" },
		{ key = "Mandatory", label = "GRÁTIS" },
	}

	local function renderStep1()
		label(
			catalogContent,
			wizardDraft.editing and ("[ ✏️ EDITANDO '" .. wizardDraft.name .. "' — PASSO 1/3 ]")
				or "[ PASSO 1/3 — APARÊNCIA E CATEGORIA ]",
			UDim2.new(1, 0, 0.06, 0),
			UDim2.new(0, 0, 0, 0),
			COLORS.catalog
		)

		label(catalogContent, wizardDraft.editing and "NOME (travado):" or "NOME:", UDim2.new(0.18, 0, 0.06, 0), UDim2.new(0.02, 0, 0.08, 0))
		local nameBox = textBox(catalogContent, "Nome do personagem...", UDim2.new(0.78, 0, 0.06, 0), UDim2.new(0.2, 0, 0.08, 0), wizardDraft.name)
		if wizardDraft.editing then
			-- (V9) Em edição o nome fica TRAVADO: mudar o nome criaria
			-- um personagem NOVO em vez de editar o existente
			nameBox.TextEditable = false
			nameBox.TextColor3 = Color3.fromRGB(150, 150, 150)
		end
		nameBox:GetPropertyChangedSignal("Text"):Connect(function()
			wizardDraft.name = nameBox.Text
		end)

		label(catalogContent, "IMAGE ID:", UDim2.new(0.18, 0, 0.06, 0), UDim2.new(0.02, 0, 0.16, 0))
		local imgBox = textBox(catalogContent, "Ex: 123456789 (só números)", UDim2.new(0.78, 0, 0.06, 0), UDim2.new(0.2, 0, 0.16, 0), wizardDraft.imageId)
		imgBox:GetPropertyChangedSignal("Text"):Connect(function()
			wizardDraft.imageId = imgBox.Text
		end)

		label(catalogContent, "VIDA (HP):", UDim2.new(0.18, 0, 0.06, 0), UDim2.new(0.02, 0, 0.24, 0))
		local hpBox = textBox(catalogContent, "Ex: 200 (vazio = 100)", UDim2.new(0.78, 0, 0.06, 0), UDim2.new(0.2, 0, 0.24, 0), wizardDraft.health)
		hpBox:GetPropertyChangedSignal("Text"):Connect(function()
			wizardDraft.health = hpBox.Text
		end)

		label(catalogContent, "CATEGORIA:", UDim2.new(0.3, 0, 0.05, 0), UDim2.new(0.02, 0, 0.33, 0))
		local catW = 0.196
		for i, opt in ipairs(CATEGORY_OPTIONS) do
			local btn = button(
				catalogContent,
				opt.label,
				wizardDraft.category == opt.key and COLORS.catalog or COLORS.panel,
				UDim2.new(catW - 0.01, 0, 0.07, 0),
				UDim2.new(0.01 + (i - 1) * catW, 0, 0.39, 0)
			)
			btn.MouseButton1Click:Connect(function()
				wizardDraft.category = opt.key
				renderCatalogView()
			end)
		end

		-- Campo de valor, condicional à categoria escolhida
		local valueY = 0.5
		if wizardDraft.category == "Shop" then
			label(catalogContent, "PREÇO (moedas):", UDim2.new(0.32, 0, 0.06, 0), UDim2.new(0.02, 0, valueY, 0))
			local valBox = textBox(catalogContent, "Ex: 300", UDim2.new(0.62, 0, 0.06, 0), UDim2.new(0.36, 0, valueY, 0), wizardDraft.value)
			valBox:GetPropertyChangedSignal("Text"):Connect(function()
				wizardDraft.value = valBox.Text
			end)
		elseif wizardDraft.category == "Reward" then
			label(catalogContent, "BOUNTY NECESSÁRIO:", UDim2.new(0.32, 0, 0.06, 0), UDim2.new(0.02, 0, valueY, 0))
			local valBox = textBox(catalogContent, "Ex: 2500", UDim2.new(0.62, 0, 0.06, 0), UDim2.new(0.36, 0, valueY, 0), wizardDraft.value)
			valBox:GetPropertyChangedSignal("Text"):Connect(function()
				wizardDraft.value = valBox.Text
			end)
		elseif wizardDraft.category == "Gamepass" then
			label(catalogContent, "GAMEPASS ID:", UDim2.new(0.32, 0, 0.06, 0), UDim2.new(0.02, 0, valueY, 0))
			local gpBox = textBox(catalogContent, "Ex: 1247245466 (crie no site do Roblox)", UDim2.new(0.62, 0, 0.06, 0), UDim2.new(0.36, 0, valueY, 0), wizardDraft.gamepassId)
			gpBox:GetPropertyChangedSignal("Text"):Connect(function()
				wizardDraft.gamepassId = gpBox.Text
			end)
		elseif wizardDraft.category == "Badge" then
			label(catalogContent, "BADGE ID:", UDim2.new(0.32, 0, 0.06, 0), UDim2.new(0.02, 0, valueY, 0))
			local bBox = textBox(catalogContent, "Ex: 123456 (crie no site do Roblox)", UDim2.new(0.62, 0, 0.06, 0), UDim2.new(0.36, 0, valueY, 0), wizardDraft.badgeId)
			bBox:GetPropertyChangedSignal("Text"):Connect(function()
				wizardDraft.badgeId = bBox.Text
			end)
		else
			label(catalogContent, "Categoria GRÁTIS: sem valor — todo jogador recebe automaticamente.", UDim2.new(0.95, 0, 0.08, 0), UDim2.new(0.02, 0, valueY, 0), Color3.fromRGB(0, 255, 0))
		end

		local cancelBtn = button(catalogContent, "CANCELAR", COLORS.error, UDim2.new(0.3, 0, 0.08, 0), UDim2.new(0.02, 0, 0.88, 0))
		cancelBtn.MouseButton1Click:Connect(function()
			currentView = "list"
			renderCatalogView()
		end)

		local nextBtn = button(catalogContent, "AVANÇAR ▶ (2/3)", COLORS.success, UDim2.new(0.4, 0, 0.08, 0), UDim2.new(0.58, 0, 0.88, 0))
		nextBtn.MouseButton1Click:Connect(function()
			if wizardDraft.name == "" then
				showToast("Digite um nome!", false)
				return
			end
			if wizardDraft.imageId == "" or not tonumber(wizardDraft.imageId) then
				showToast("Digite um Image ID válido (só números)!", false)
				return
			end
			if wizardDraft.category == "Gamepass" and not tonumber(wizardDraft.gamepassId) then
				showToast("Digite o Gamepass ID!", false)
				return
			end
			if wizardDraft.category == "Badge" and not tonumber(wizardDraft.badgeId) then
				showToast("Digite o Badge ID!", false)
				return
			end
			currentView = "step2"
			renderCatalogView()
		end)
	end

	-- ---------- VIEW: PASSO 2 — TOOLS (até 7) ----------

	local function renderStep2()
		label(catalogContent, "[ PASSO 2/3 — HABILIDADES (TOOLS) — máx. 7 no TOTAL ]", UDim2.new(1, 0, 0.06, 0), UDim2.new(0, 0, 0, 0), COLORS.catalog)
		-- (V10) A dica do Model entrou no aviso que já existia aqui, sem
		-- elemento novo: as 7 linhas de campo ocupam de 0.13 a 0.70 em
		-- Scale e outra linha empurraria os botões.
		label(
			catalogContent,
			"Cole o Model ID de cada Tool. UM Model com várias Tools dentro vale por todas. Vazio = não usa.",
			UDim2.new(0.96, 0, 0.05, 0),
			UDim2.new(0.02, 0, 0.06, 0),
			Color3.fromRGB(180, 180, 180)
		)

		for i = 1, 7 do
			local rowY = 0.13 + (i - 1) * 0.095
			label(catalogContent, "TOOL " .. i .. ":", UDim2.new(0.15, 0, 0.06, 0), UDim2.new(0.02, 0, rowY, 0))
			local box = textBox(
				catalogContent,
				-- (V10) O primeiro campo é onde se põe o Model único
				i == 1 and "ID de uma Tool OU de um Model com várias" or "Model ID da Tool (opcional)",
				UDim2.new(0.8, 0, 0.06, 0),
				UDim2.new(0.18, 0, rowY, 0),
				wizardDraft.toolIds[i]
			)
			box:GetPropertyChangedSignal("Text"):Connect(function()
				wizardDraft.toolIds[i] = box.Text
			end)
		end

		local backBtn = button(catalogContent, "◀ VOLTAR", COLORS.panel, UDim2.new(0.3, 0, 0.08, 0), UDim2.new(0.02, 0, 0.88, 0))
		backBtn.MouseButton1Click:Connect(function()
			currentView = "step1"
			renderCatalogView()
		end)

		local nextBtn = button(catalogContent, "AVANÇAR ▶ (3/3)", COLORS.success, UDim2.new(0.4, 0, 0.08, 0), UDim2.new(0.58, 0, 0.88, 0))
		nextBtn.MouseButton1Click:Connect(function()
			currentView = "step3"
			renderCatalogView()
		end)
	end

	-- ---------- VIEW: PASSO 3 — LORE + RARIDADE + PUBLICAR ----------

	-- (V10) "AWAKENED" SAIU DAQUI.
	-- Despertar não é uma raridade que se escolhe ao criar personagem
	-- normal: ele tem formulário próprio (botão ⚡ CONFIGURAR DESPERTAR)
	-- e depende SEMPRE de um personagem original já existente. Ter a
	-- opção aqui deixava criar um "personagem de raridade AWAKENED" solto,
	-- que é um personagem comum pintado de despertado — a mesma confusão
	-- que o AwakeningSystemServer_V3 fechou do lado do servidor.
	-- A largura dos botões é 1/#RARITY_OPTIONS, então a linha se reajusta
	-- sozinha para 6 opções.
	local RARITY_OPTIONS = { "ROBLOXIANOS", "HEROXIANOS", "NULLXIANOS", "BTUDIOS", "BOSSXIANOS", "SUPREMO" }

	local function renderStep3()
		label(
			catalogContent,
			wizardDraft.editing and ("[ ✏️ EDITANDO '" .. wizardDraft.name .. "' — PASSO 3/3 ]")
				or "[ PASSO 3/3 — LORE E RARIDADE ]",
			UDim2.new(1, 0, 0.06, 0),
			UDim2.new(0, 0, 0, 0),
			COLORS.catalog
		)

		label(catalogContent, "DESCRIÇÃO CURTA:", UDim2.new(0.4, 0, 0.05, 0), UDim2.new(0.02, 0, 0.08, 0))
		local descBox = textBox(catalogContent, "Ex: Personagem do escudo protetor", UDim2.new(0.96, 0, 0.08, 0), UDim2.new(0.02, 0, 0.13, 0), wizardDraft.description)
		descBox:GetPropertyChangedSignal("Text"):Connect(function()
			wizardDraft.description = descBox.Text
		end)

		label(catalogContent, "LORE (HISTÓRIA):", UDim2.new(0.4, 0, 0.05, 0), UDim2.new(0.02, 0, 0.24, 0))
		local loreBox = textBox(catalogContent, "Conte a história deste personagem...", UDim2.new(0.96, 0, 0.2, 0), UDim2.new(0.02, 0, 0.29, 0), wizardDraft.lore)
		loreBox.TextWrapped = true
		loreBox.MultiLine = true
		loreBox.TextYAlignment = Enum.TextYAlignment.Top
		loreBox:GetPropertyChangedSignal("Text"):Connect(function()
			wizardDraft.lore = loreBox.Text
		end)

		label(catalogContent, "RARIDADE: " .. wizardDraft.rarity, UDim2.new(0.6, 0, 0.05, 0), UDim2.new(0.02, 0, 0.52, 0))
		local rw = 1 / #RARITY_OPTIONS
		for i, rarity in ipairs(RARITY_OPTIONS) do
			local btn = button(
				catalogContent,
				rarity:sub(1, 5),
				wizardDraft.rarity == rarity and COLORS.catalog or COLORS.panel,
				UDim2.new(rw - 0.008, 0, 0.06, 0),
				UDim2.new(0.004 + (i - 1) * rw, 0, 0.58, 0)
			)
			btn.MouseButton1Click:Connect(function()
				wizardDraft.rarity = rarity
				renderCatalogView()
			end)
		end

		local backBtn = button(catalogContent, "◀ VOLTAR", COLORS.panel, UDim2.new(0.3, 0, 0.08, 0), UDim2.new(0.02, 0, 0.88, 0))
		backBtn.MouseButton1Click:Connect(function()
			currentView = "step2"
			renderCatalogView()
		end)

		-- (V9) Texto muda quando é edição
		local publishBtn = button(
			catalogContent,
			wizardDraft.editing and "✅ SALVAR EDIÇÃO" or "✅ PUBLICAR",
			COLORS.success,
			UDim2.new(0.4, 0, 0.08, 0),
			UDim2.new(0.58, 0, 0.88, 0)
		)
		local publishing = false
		publishBtn.MouseButton1Click:Connect(function()
			if publishing then
				return
			end
			publishing = true
			publishBtn.Text = wizardDraft.editing and "SALVANDO..." or "PUBLICANDO..."

			local toolIds = {}
			for _, idStr in ipairs(wizardDraft.toolIds) do
				local n = tonumber(idStr)
				if n and n > 0 then
					table.insert(toolIds, n)
				end
			end

			local payload = {
				name = wizardDraft.name,
				category = wizardDraft.category,
				value = tonumber(wizardDraft.value) or 0,
				gamepassId = tonumber(wizardDraft.gamepassId) or 0,
				badgeId = tonumber(wizardDraft.badgeId) or 0,
				imageId = tonumber(wizardDraft.imageId) or 0,
				health = tonumber(wizardDraft.health) or 100,
				toolIds = toolIds,
				rarity = wizardDraft.rarity,
				description = wizardDraft.description,
				lore = wizardDraft.lore,
			}

			task.spawn(function()
				local ok, success, msg = pcall(function()
					return adminCatalogAdd:InvokeServer(payload)
				end)

				showToast(ok and (msg or "Publicado!") or "Erro de comunicação com o servidor!", ok and success)
				publishing = false

				if ok and success then
					currentView = "list"
				end
				renderCatalogView()
			end)
		end)
	end

	-- ---------- VIEW: DESPERTAR ----------

	-- =====================================
	-- (V12) WIZARD DO DESPERTAR EM 3 ETAPAS
	-- =====================================
	-- Antes era tudo numa tela só: personagem, badge, nome, imagem, vida,
	-- história e os 7 campos de Tool disputando o mesmo espaço vertical.
	-- Com a história somada, os campos ficaram colados uns nos outros.
	--
	-- Agora segue o mesmo desenho do wizard de personagem normal
	-- (step1/step2/step3): cada etapa cuida de um assunto e tem espaço
	-- para respirar.

	local function cabecalhoAwaken(etapa, titulo)
		label(
			catalogContent,
			string.format(
				"[ ⚡ DESPERTAR — ETAPA %d/3: %s ]%s",
				etapa,
				titulo,
				awakenDraft.editing and ("  ✏️ " .. awakenDraft.characterName) or ""
			),
			UDim2.new(1, 0, 0.06, 0),
			UDim2.new(0, 0, 0, 0),
			COLORS.awaken
		)
	end

	local renderAwaken1, renderAwaken2, renderAwaken3

	-- ETAPA 1 — de quem é a forma
	function renderAwaken1()
		cabecalhoAwaken(1, "PERSONAGEM")

		label(catalogContent, awakenDraft.editing and "PERSONAGEM (travado):" or "PERSONAGEM BASE:", UDim2.new(0.32, 0, 0.06, 0), UDim2.new(0.02, 0, 0.12, 0))
		local nameBox = textBox(catalogContent, "Nome exato de um personagem existente", UDim2.new(0.62, 0, 0.06, 0), UDim2.new(0.36, 0, 0.12, 0), awakenDraft.characterName)
		if awakenDraft.editing then
			nameBox.TextEditable = false
			nameBox.TextColor3 = Color3.fromRGB(150, 150, 150)
		end
		nameBox:GetPropertyChangedSignal("Text"):Connect(function()
			awakenDraft.characterName = nameBox.Text
		end)

		label(catalogContent, "NOME DE EXIBIÇÃO:", UDim2.new(0.32, 0, 0.06, 0), UDim2.new(0.02, 0, 0.24, 0))
		local dispBox = textBox(catalogContent, "Ex: Danilo Despertado", UDim2.new(0.62, 0, 0.06, 0), UDim2.new(0.36, 0, 0.24, 0), awakenDraft.displayName)
		dispBox:GetPropertyChangedSignal("Text"):Connect(function()
			awakenDraft.displayName = dispBox.Text
		end)

		-- (V12) O Badge deixou de ser obrigatório no AwakeningSystemServer
		-- V5, mas este painel continuava exigindo. Agora o rótulo e a
		-- validação dizem a verdade.
		label(catalogContent, "BADGE ID (opcional):", UDim2.new(0.32, 0, 0.06, 0), UDim2.new(0.02, 0, 0.36, 0))
		local badgeBox = textBox(catalogContent, "Vazio = liberado para quem tem o personagem", UDim2.new(0.62, 0, 0.06, 0), UDim2.new(0.36, 0, 0.36, 0), awakenDraft.badgeId)
		badgeBox:GetPropertyChangedSignal("Text"):Connect(function()
			awakenDraft.badgeId = badgeBox.Text
		end)

		label(
			catalogContent,
			"O Despertar é uma FORMA do personagem, conquistada em combate pela barra. Não é um personagem separado.",
			UDim2.new(0.95, 0, 0.12, 0),
			UDim2.new(0.02, 0, 0.5, 0),
			COLORS.warning
		)

		local backBtn = button(catalogContent, "◀ VOLTAR", COLORS.panel, UDim2.new(0.3, 0, 0.08, 0), UDim2.new(0.02, 0, 0.88, 0))
		backBtn.MouseButton1Click:Connect(function()
			currentView = "list"
			renderCatalogView()
		end)

		local nextBtn = button(catalogContent, "PRÓXIMO ▶", COLORS.success, UDim2.new(0.4, 0, 0.08, 0), UDim2.new(0.58, 0, 0.88, 0))
		nextBtn.MouseButton1Click:Connect(function()
			if awakenDraft.characterName:match("^%s*(.-)%s*$") == "" then
				showToast("Diga de qual personagem é esta forma!", false)
				return
			end
			currentView = "awaken2"
			renderCatalogView()
		end)
	end

	-- ETAPA 2 — como ela se apresenta
	function renderAwaken2()
		cabecalhoAwaken(2, "APARÊNCIA E HISTÓRIA")

		label(catalogContent, "IMAGE ID:", UDim2.new(0.32, 0, 0.06, 0), UDim2.new(0.02, 0, 0.12, 0))
		local imgBox = textBox(catalogContent, "Aparece no card do Despertar", UDim2.new(0.62, 0, 0.06, 0), UDim2.new(0.36, 0, 0.12, 0), awakenDraft.imageId)
		imgBox:GetPropertyChangedSignal("Text"):Connect(function()
			awakenDraft.imageId = imgBox.Text
		end)

		label(catalogContent, "VIDA (opcional):", UDim2.new(0.32, 0, 0.06, 0), UDim2.new(0.02, 0, 0.24, 0))
		local hpBox = textBox(catalogContent, "Vazio = mantém a vida normal", UDim2.new(0.62, 0, 0.06, 0), UDim2.new(0.36, 0, 0.24, 0), awakenDraft.health)
		hpBox:GetPropertyChangedSignal("Text"):Connect(function()
			awakenDraft.health = hpBox.Text
		end)

		label(catalogContent, "HISTÓRIA:", UDim2.new(0.32, 0, 0.06, 0), UDim2.new(0.02, 0, 0.36, 0))
		local loreBox = textBox(catalogContent, "Texto que aparece no card do Despertar", UDim2.new(0.62, 0, 0.2, 0), UDim2.new(0.36, 0, 0.36, 0), awakenDraft.lore)
		loreBox.TextWrapped = true
		loreBox.TextYAlignment = Enum.TextYAlignment.Top
		loreBox.ClearTextOnFocus = false
		loreBox:GetPropertyChangedSignal("Text"):Connect(function()
			awakenDraft.lore = loreBox.Text
		end)

		local backBtn = button(catalogContent, "◀ VOLTAR", COLORS.panel, UDim2.new(0.3, 0, 0.08, 0), UDim2.new(0.02, 0, 0.88, 0))
		backBtn.MouseButton1Click:Connect(function()
			currentView = "awaken1"
			renderCatalogView()
		end)

		local nextBtn = button(catalogContent, "PRÓXIMO ▶", COLORS.success, UDim2.new(0.4, 0, 0.08, 0), UDim2.new(0.58, 0, 0.88, 0))
		nextBtn.MouseButton1Click:Connect(function()
			currentView = "awaken3"
			renderCatalogView()
		end)
	end

	-- ETAPA 3 — as habilidades e o salvar
	function renderAwaken3()
		cabecalhoAwaken(3, "HABILIDADES")

		label(
			catalogContent,
			"TOOLS DESPERTAS (máx. 7 no TOTAL) — 1 ID de Model com as Tools dentro vale por todas:",
			UDim2.new(0.95, 0, 0.09, 0),
			UDim2.new(0.02, 0, 0.1, 0)
		)

		for i = 1, 7 do
			local col = (i - 1) % 4
			local row = math.floor((i - 1) / 4)
			local box = textBox(
				catalogContent,
				i == 1 and "Tool ou Model" or ("Tool " .. i),
				UDim2.new(0.23, 0, 0.07, 0),
				UDim2.new(0.02 + col * 0.245, 0, 0.24 + row * 0.11, 0),
				awakenDraft.toolIds[i]
			)
			box:GetPropertyChangedSignal("Text"):Connect(function()
				awakenDraft.toolIds[i] = box.Text
			end)
		end

		label(
			catalogContent,
			"A forma dura um tempo e depois volta ao normal. A barra enche batendo, apanhando e usando habilidade.",
			UDim2.new(0.95, 0, 0.1, 0),
			UDim2.new(0.02, 0, 0.5, 0),
			COLORS.warning
		)

		local backBtn = button(catalogContent, "◀ VOLTAR", COLORS.panel, UDim2.new(0.3, 0, 0.08, 0), UDim2.new(0.02, 0, 0.88, 0))
		backBtn.MouseButton1Click:Connect(function()
			currentView = "awaken2"
			renderCatalogView()
		end)

		local saveBtn = button(
			catalogContent,
			awakenDraft.editing and "✅ SALVAR EDIÇÃO" or "✅ SALVAR DESPERTAR",
			COLORS.success,
			UDim2.new(0.4, 0, 0.08, 0),
			UDim2.new(0.58, 0, 0.88, 0)
		)
		local saving = false
		saveBtn.MouseButton1Click:Connect(function()
			if saving then
				return
			end

			-- (V12) Só o personagem base é obrigatório. O Badge virou
			-- opcional no AwakeningSystemServer V5 e este painel continuava
			-- barrando o salvamento sem ele.
			if awakenDraft.characterName:match("^%s*(.-)%s*$") == "" then
				showToast("Personagem base é obrigatório!", false)
				currentView = "awaken1"
				renderCatalogView()
				return
			end

			saving = true
			saveBtn.Text = "SALVANDO..."

			local toolIds = {}
			for _, idStr in ipairs(awakenDraft.toolIds) do
				local n = tonumber(idStr)
				if n and n > 0 then
					table.insert(toolIds, n)
				end
			end

			local payload = {
				characterName = awakenDraft.characterName,
				badgeId = tonumber(awakenDraft.badgeId),
				imageId = tonumber(awakenDraft.imageId) or 0,
				displayName = awakenDraft.displayName ~= "" and awakenDraft.displayName or nil,
				health = tonumber(awakenDraft.health),
				lore = awakenDraft.lore ~= "" and awakenDraft.lore or nil,
				toolIds = toolIds,
			}

			task.spawn(function()
				local ok, success, msg = pcall(function()
					return adminSetAwakening:InvokeServer(payload)
				end)

				showToast(ok and (msg or "Salvo!") or "Erro de comunicação com o servidor!", ok and success)
				saving = false

				if ok and success then
					currentView = "list"
				end
				renderCatalogView()
			end)
		end)
	end

	renderCatalogView = function()
		clearCatalog()
		if currentView == "list" then
			renderList()
		elseif currentView == "step1" then
			renderStep1()
		elseif currentView == "step2" then
			renderStep2()
		elseif currentView == "step3" then
			renderStep3()
		elseif currentView == "awaken" or currentView == "awaken1" then
			renderAwaken1()
		elseif currentView == "awaken2" then
			renderAwaken2()
		elseif currentView == "awaken3" then
			renderAwaken3()
		end
	end

	renderCatalogView()

	-- ============================
	-- (V9) TAB 4: ADMINS — GERENCIAR SEM STUDIO
	-- Adicionar por username ou ID, listar e remover (dono é 🔑
	-- irremovível). Tudo salvo no DataStore pelo AdminRegistryServer_V1
	-- e valendo em TODOS os servidores.
	-- ============================

	local adminsContent = tabContents[4]
	local renderAdminsTab

	local function clearAdminsTab()
		for _, child in pairs(adminsContent:GetChildren()) do
			child.Parent = nil
		end
	end

	renderAdminsTab = function()
		clearAdminsTab()

		label(adminsContent, "[ GERENCIAR ADMINS — SEM STUDIO ]", UDim2.new(1, 0, 0.06, 0), UDim2.new(0, 0, 0, 0), COLORS.warning)

		if not (adminRegistryAdd and adminRegistryRemove and adminRegistryList) then
			label(
				adminsContent,
				"⚠️ AdminRegistryServer_V1 não está instalado no ServerScriptService!",
				UDim2.new(0.96, 0, 0.12, 0),
				UDim2.new(0.02, 0, 0.1, 0),
				COLORS.error
			)
			return
		end

		label(adminsContent, "USERNAME OU ID:", UDim2.new(0.3, 0, 0.055, 0), UDim2.new(0.02, 0, 0.08, 0))
		local userBox = textBox(adminsContent, "Ex: NomeExato ou 123456789", UDim2.new(0.64, 0, 0.055, 0), UDim2.new(0.34, 0, 0.08, 0), "")

		local busy = false

		local addBtn = button(adminsContent, "➕ ADICIONAR ADMIN", COLORS.success, UDim2.new(0.47, 0, 0.08, 0), UDim2.new(0.02, 0, 0.16, 0))
		addBtn.MouseButton1Click:Connect(function()
			if busy or userBox.Text == "" then
				return
			end
			busy = true
			addBtn.Text = "ADICIONANDO..."
			local input = userBox.Text
			task.spawn(function()
				local ok, success, msg = pcall(function()
					return adminRegistryAdd:InvokeServer(input)
				end)
				showToast(ok and (msg or "Feito!") or "Erro de comunicação com o servidor!", ok and success)
				busy = false
				renderAdminsTab()
			end)
		end)

		local refreshAdminsBtn = button(adminsContent, "🔄 ATUALIZAR LISTA", COLORS.panel, UDim2.new(0.47, 0, 0.08, 0), UDim2.new(0.51, 0, 0.16, 0))
		refreshAdminsBtn.MouseButton1Click:Connect(function()
			renderAdminsTab()
		end)

		label(adminsContent, "ADMINS ATUAIS (valem em TODOS os servidores):", UDim2.new(0.96, 0, 0.045, 0), UDim2.new(0.02, 0, 0.26, 0), Color3.fromRGB(180, 180, 180))

		local listScroll = Instance.new("ScrollingFrame")
		listScroll.Size = UDim2.new(0.96, 0, 0.66, 0)
		listScroll.Position = UDim2.new(0.02, 0, 0.32, 0)
		listScroll.BackgroundColor3 = COLORS.background
		listScroll.BorderColor3 = COLORS.border
		listScroll.BorderSizePixel = 2
		listScroll.ScrollBarThickness = 8
		listScroll.Parent = adminsContent

		local ok, list = pcall(function()
			return adminRegistryList:InvokeServer()
		end)

		local yPos = 5
		if ok and type(list) == "table" and #list > 0 then
			for _, entry in ipairs(list) do
				local row = Instance.new("Frame")
				row.Size = UDim2.new(0.97, 0, 0, 44)
				row.Position = UDim2.new(0.015, 0, 0, yPos)
				row.BackgroundColor3 = entry.isOwner and Color3.fromRGB(50, 40, 10) or COLORS.panel
				row.BorderColor3 = entry.isOwner and COLORS.warning or COLORS.border
				row.BorderSizePixel = 1
				row.Parent = listScroll

				label(
					row,
					string.format("%s | ID: %d | por: %s", entry.name or "?", entry.userId or 0, entry.addedBy or "?"),
					UDim2.new(0.65, 0, 1, 0),
					UDim2.new(0.02, 0, 0, 0),
					entry.isOwner and COLORS.warning or COLORS.border
				)

				if entry.isOwner then
					label(row, "🔑 DONO", UDim2.new(0.3, 0, 0.8, 0), UDim2.new(0.68, 0, 0.1, 0), COLORS.warning)
				else
					-- Dupla confirmação (mesmo padrão do REMOVER do catálogo)
					local removeBtn = button(row, "REMOVER", COLORS.error, UDim2.new(0.3, 0, 0.8, 0), UDim2.new(0.68, 0, 0.1, 0))
					local confirming = false
					removeBtn.MouseButton1Click:Connect(function()
						if not confirming then
							confirming = true
							removeBtn.Text = "CONFIRMAR?"
							task.delay(3, function()
								if removeBtn.Parent and confirming then
									confirming = false
									removeBtn.Text = "REMOVER"
								end
							end)
							return
						end
						local okr, success, msg = pcall(function()
							return adminRegistryRemove:InvokeServer(tostring(entry.userId))
						end)
						showToast(okr and (msg or "Removido!") or "Erro ao remover!", okr and success)
						renderAdminsTab()
					end)
				end

				yPos = yPos + 48
			end
		else
			label(listScroll, "Não foi possível carregar a lista de admins.", UDim2.new(0.95, 0, 0, 30), UDim2.new(0.02, 0, 0, yPos), Color3.fromRGB(150, 150, 150))
			yPos = yPos + 40
		end

		listScroll.CanvasSize = UDim2.new(0, 0, 0, yPos + 10)
	end

	renderAdminsTab()

	-- ============================
	-- TAB 5: JOGADORES (idêntico ao V8, renumerado)
	-- ============================

	local playersContent = tabContents[5]

	local playersTitle = Instance.new("TextLabel")
	playersTitle.Size = UDim2.new(0.7, 0, 0.08, 0)
	playersTitle.BackgroundTransparency = 1
	playersTitle.Text = "[ JOGADORES ONLINE ]"
	playersTitle.TextColor3 = COLORS.warning
	playersTitle.TextScaled = true
	playersTitle.Font = Enum.Font.Arcade
	playersTitle.Parent = playersContent

	local refreshBtn = Instance.new("TextButton")
	refreshBtn.Size = UDim2.new(0.18, 0, 0.07, 0)
	refreshBtn.Position = UDim2.new(0.8, 0, 0.005, 0)
	refreshBtn.BackgroundColor3 = COLORS.panel
	refreshBtn.BorderColor3 = COLORS.border
	refreshBtn.BorderSizePixel = 2
	refreshBtn.Text = "ATUALIZAR"
	refreshBtn.TextColor3 = COLORS.warning
	refreshBtn.TextScaled = true
	refreshBtn.Font = Enum.Font.Arcade
	refreshBtn.Parent = playersContent

	local playersList = Instance.new("ScrollingFrame")
	playersList.Size = UDim2.new(0.98, 0, 0.88, 0)
	playersList.Position = UDim2.new(0.01, 0, 0.1, 0)
	playersList.BackgroundColor3 = COLORS.background
	playersList.BorderColor3 = COLORS.border
	playersList.BorderSizePixel = 2
	playersList.ScrollBarThickness = 8
	playersList.ScrollBarImageColor3 = COLORS.border
	playersList.Parent = playersContent

	local function updatePlayersList()
		for _, child in pairs(playersList:GetChildren()) do
			if child:IsA("Frame") then
				child.Parent = nil
			end
		end

		local ok, playerData = pcall(function()
			return getPlayerList:InvokeServer()
		end)

		if not ok or not playerData then
			return
		end

		local yPos = 5
		for _, data in ipairs(playerData) do
			local card = Instance.new("Frame")
			card.Size = UDim2.new(0.95, 0, 0, 60)
			card.Position = UDim2.new(0.025, 0, 0, yPos)
			card.BackgroundColor3 = COLORS.panel
			card.BorderColor3 = COLORS.border
			card.BorderSizePixel = 2
			card.Parent = playersList

			local cardCorner = Instance.new("UICorner")
			cardCorner.CornerRadius = UDim.new(0, 4)
			cardCorner.Parent = card

			local nameLabel = Instance.new("TextLabel")
			nameLabel.Size = UDim2.new(0.28, 0, 0.5, 0)
			nameLabel.Position = UDim2.new(0.01, 0, 0, 0)
			nameLabel.BackgroundTransparency = 1
			nameLabel.Text = data.name
			nameLabel.TextColor3 = COLORS.border
			nameLabel.TextScaled = true
			nameLabel.Font = Enum.Font.Arcade
			nameLabel.Parent = card

			local statsLine1 = Instance.new("TextLabel")
			statsLine1.Size = UDim2.new(0.5, 0, 0.45, 0)
			statsLine1.Position = UDim2.new(0.3, 0, 0, 0)
			statsLine1.BackgroundTransparency = 1
			statsLine1.Text =
				string.format("$ %d | B %d | K %d", data.coins, data.bounty, data.kills)
			statsLine1.TextColor3 = COLORS.warning
			statsLine1.TextScaled = true
			statsLine1.Font = Enum.Font.Arcade
			statsLine1.Parent = card

			local statsLine2 = Instance.new("TextLabel")
			statsLine2.Size = UDim2.new(0.5, 0, 0.45, 0)
			statsLine2.Position = UDim2.new(0.3, 0, 0.5, 0)
			statsLine2.BackgroundTransparency = 1
			statsLine2.Text = string.format(
				"Char: %s | Inv: %d",
				data.equippedChar or "Nenhum",
				data.ownedCount or 0
			)
			statsLine2.TextColor3 = Color3.fromRGB(180, 180, 180)
			statsLine2.TextScaled = true
			statsLine2.Font = Enum.Font.Arcade
			statsLine2.Parent = card

			local selectBtn = Instance.new("TextButton")
			selectBtn.Size = UDim2.new(0.13, 0, 0.7, 0)
			selectBtn.Position = UDim2.new(0.85, 0, 0.15, 0)
			selectBtn.BackgroundColor3 = COLORS.success
			selectBtn.BorderColor3 = COLORS.border
			selectBtn.BorderSizePixel = 1
			selectBtn.Text = "USAR"
			selectBtn.TextColor3 = COLORS.background
			selectBtn.TextScaled = true
			selectBtn.Font = Enum.Font.Arcade
			selectBtn.Parent = card

			local capturedName = data.name
			selectBtn.MouseButton1Click:Connect(function()
				playSound(sounds.click)
				playerInput.Text = capturedName
				charPlayerInput.Text = capturedName
				actionsPlayerInput.Text = capturedName
			end)

			yPos = yPos + 65
		end

		playersList.CanvasSize = UDim2.new(0, 0, 0, yPos + 5)
	end

	refreshBtn.MouseButton1Click:Connect(function()
		playSound(sounds.click)
		updatePlayersList()
	end)

	-- ============================
	-- TAB 6: AÇÕES (idêntico ao V8, renumerado)
	-- ============================

	local actionsContent = tabContents[6]

	local actionsTitle = Instance.new("TextLabel")
	actionsTitle.Size = UDim2.new(1, 0, 0.08, 0)
	actionsTitle.BackgroundTransparency = 1
	actionsTitle.Text = "[ ACOES RAPIDAS ]"
	actionsTitle.TextColor3 = COLORS.warning
	actionsTitle.TextScaled = true
	actionsTitle.Font = Enum.Font.Arcade
	actionsTitle.Parent = actionsContent

	local actionsPlayerLabel = Instance.new("TextLabel")
	actionsPlayerLabel.Size = UDim2.new(0.2, 0, 0.08, 0)
	actionsPlayerLabel.Position = UDim2.new(0.05, 0, 0.12, 0)
	actionsPlayerLabel.BackgroundTransparency = 1
	actionsPlayerLabel.Text = "JOGADOR:"
	actionsPlayerLabel.TextColor3 = COLORS.border
	actionsPlayerLabel.TextScaled = true
	actionsPlayerLabel.Font = Enum.Font.Arcade
	actionsPlayerLabel.Parent = actionsContent

	actionsPlayerInput = Instance.new("TextBox")
	actionsPlayerInput.Size = UDim2.new(0.7, 0, 0.08, 0)
	actionsPlayerInput.Position = UDim2.new(0.26, 0, 0.12, 0)
	actionsPlayerInput.BackgroundColor3 = COLORS.background
	actionsPlayerInput.BorderColor3 = COLORS.border
	actionsPlayerInput.BorderSizePixel = 2
	actionsPlayerInput.Text = ""
	actionsPlayerInput.PlaceholderText = "Nome do jogador..."
	actionsPlayerInput.TextColor3 = COLORS.border
	actionsPlayerInput.PlaceholderColor3 = Color3.fromRGB(150, 150, 150)
	actionsPlayerInput.TextScaled = true
	actionsPlayerInput.Font = Enum.Font.Arcade
	actionsPlayerInput.Parent = actionsContent

	local actions = {
		{
			text = "KILL",
			color = COLORS.error,
			pos = UDim2.new(0.04, 0, 0.28, 0),
			cmd = function()
				if actionsPlayerInput.Text ~= "" then
					adminKill:FireServer(actionsPlayerInput.Text)
				end
			end,
		},
		{
			text = "KICK",
			color = Color3.fromRGB(150, 0, 0),
			pos = UDim2.new(0.54, 0, 0.28, 0),
			cmd = function()
				if actionsPlayerInput.Text ~= "" then
					adminKick:FireServer(actionsPlayerInput.Text, "Expulso por admin")
				end
			end,
		},
		{
			text = "TP SAFEZONE",
			color = Color3.fromRGB(0, 100, 200),
			pos = UDim2.new(0.04, 0, 0.44, 0),
			cmd = function()
				if actionsPlayerInput.Text ~= "" then
					adminTeleport:FireServer(actionsPlayerInput.Text, "SafeZone")
				end
			end,
		},
		{
			text = "TP SPAWN",
			color = Color3.fromRGB(0, 80, 160),
			pos = UDim2.new(0.54, 0, 0.44, 0),
			cmd = function()
				if actionsPlayerInput.Text ~= "" then
					adminTeleport:FireServer(actionsPlayerInput.Text, "Spawn")
				end
			end,
		},
		{
			text = "RESET DADOS",
			color = COLORS.error,
			pos = UDim2.new(0.04, 0, 0.60, 0),
			cmd = function()
				if actionsPlayerInput.Text ~= "" then
					adminResetData:FireServer(actionsPlayerInput.Text)
				end
			end,
		},
	}

	for _, action in ipairs(actions) do
		local actionButton = Instance.new("TextButton")
		actionButton.Size = UDim2.new(0.4, 0, 0.12, 0)
		actionButton.Position = action.pos
		actionButton.BackgroundColor3 = action.color
		actionButton.BorderColor3 = COLORS.border
		actionButton.BorderSizePixel = 2
		actionButton.Text = action.text
		actionButton.TextColor3 = COLORS.border
		actionButton.TextScaled = true
		actionButton.Font = Enum.Font.Arcade
		actionButton.Parent = actionsContent

		local actionCorner = Instance.new("UICorner")
		actionCorner.CornerRadius = UDim.new(0, 4)
		actionCorner.Parent = actionButton

		local capturedCmd = action.cmd
		actionButton.MouseButton1Click:Connect(function()
			playSound(sounds.click)
			capturedCmd()
		end)
	end

	-- ============================
	-- LOGICA DE ABRIR/FECHAR
	-- ============================

	local function toggleMenu()
		isOpen = not isOpen
		mainFrame.Visible = isOpen
		playSound(isOpen and sounds.open or sounds.close)
		if isOpen then
			task.spawn(updatePlayersList)
		end
	end

	closeButton.MouseButton1Click:Connect(toggleMenu)

	task.spawn(function()
		while screenGui and screenGui.Parent do
			task.wait(5)
			if isOpen then
				pcall(updatePlayersList)
			end
		end
	end)

	task.spawn(updatePlayersList)
end

createAdminInterface()

-- =====================================
-- ABRIR/FECHAR VIA MENU UNIFICADO
-- =====================================

_G.OpenAdminMenu = function()
	if not screenGui or not screenGui.Parent then
		createAdminInterface()
	end
	if mainFrame then
		mainFrame.Visible = true
		isOpen = true
	end
end

_G.CloseAdminMenu = function()
	if mainFrame then
		mainFrame.Visible = false
		isOpen = false
	end
end

task.spawn(function()
	local timeout = 0
	while not _G.RegisterMenuCategory and timeout < 15 do
		task.wait(0.5)
		timeout = timeout + 0.5
	end
	if _G.RegisterMenuCategory then
		_G.RegisterMenuCategory("ADMIN", "⚙️", function()
			if _G.OpenAdminMenu then
				_G.OpenAdminMenu()
			end
		end, function()
			if _G.CloseAdminMenu then
				_G.CloseAdminMenu()
			end
		end, 9)
		print("[ADMIN V9] Registrado no Menu Unificado: ADMIN")
	end
end)

print([[
╔════════════════════════════════════════════════════╗
║  ✅ ADMIN MENU CLIENT V9 CARREGADO                ║
╠════════════════════════════════════════════════════╣
║  SUBSTITUI: AdminMenuClient V8                    ║
║  REMOVER:   AdminMenuClient V8                    ║
║  DEPENDE DE: AdminRegistryServer_V1               ║
╠════════════════════════════════════════════════════╣
║  NOVIDADES V9:                                     ║
║  • ADMIN_IDS removida → IsAdminCheck (servidor)    ║
║    Admin novo vê o painel SEM relogar              ║
║  • ✏️ EDITAR personagem: wizard pré-preenchido     ║
║    (nome travado) — sobrescreve em todos os        ║
║    servidores ("✏️ atualizou")                     ║
║  • ✏️ EDITAR Despertar: formulário pré-preenchido  ║
║  • Nova aba ADMINS: add por username/ID, lista e   ║
║    REMOVER (dono 🔑 irremovível)                   ║
║  • 6 abas: Moedas/Personagens/Catálogo/Admins/     ║
║    Jogadores/Ações                                 ║
╚════════════════════════════════════════════════════╝
]])
