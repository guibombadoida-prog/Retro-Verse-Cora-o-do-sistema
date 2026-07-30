-- ============================================
-- UNIFIED MENU CLIENT V3 — MENU UNIFICADO
-- (V3) ALTERAÇÕES: fontes unificadas em estilo retro (Arcade)
-- Coloque em StarterPlayer > StarterPlayerScripts
-- Nome: "UnifiedMenuClient"
-- SUBSTITUI: UnifiedMenu_Client_V1
-- ============================================
-- V2: Categorias usam _G functions dos sistemas reais.
-- MÚSICA adicionada. ÚNICO botão na tela.
-- ============================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

print("[UNIFIED MENU V1] Inicializando...")

-- =====================================
-- SONS
-- =====================================

local function playSound(id)
	pcall(function()
		local s = Instance.new("Sound")
		s.SoundId = id
		s.Volume = 0.5
		s.Parent = SoundService
		s:Play()
		s.Ended:Connect(function()
			s.Parent = nil
		end)
	end)
end

-- =====================================
-- TAMANHOS
-- =====================================

local SIZE_MODES = { "P", "M", "G" }
local currentSizeIndex = 2 -- Médio

local GRID_SIZES = {
	P = { cols = 3, cellW = 0.28, cellH = 0.13, gap = 0.02, hubScale = 0.55 },
	M = { cols = 3, cellW = 0.28, cellH = 0.15, gap = 0.025, hubScale = 0.65 },
	G = { cols = 3, cellW = 0.28, cellH = 0.17, gap = 0.03, hubScale = 0.75 },
}

local function getGridConfig()
	return GRID_SIZES[SIZE_MODES[currentSizeIndex]]
end

-- =====================================
-- REGISTRO DE CATEGORIAS
-- =====================================

local categories = {}
local hubOpen = false
local menuGui = nil
local hubFrame = nil
local mainButton = nil
local notifDot = nil
local activeSubmenu = nil -- Nome do submenu ativo

-- Estrutura de cada categoria:
-- {name, icon, openFunc, closeFunc, hasNotification, order}

_G.RegisterMenuCategory = function(name, icon, openFunc, closeFunc, order)
	-- Evitar duplicatas
	for i, cat in ipairs(categories) do
		if cat.name == name then
			categories[i] = {
				name = name,
				icon = icon,
				openFunc = openFunc,
				closeFunc = closeFunc,
				hasNotification = false,
				order = order or 99,
			}
			return
		end
	end

	table.insert(categories, {
		name = name,
		icon = icon,
		openFunc = openFunc,
		closeFunc = closeFunc,
		hasNotification = false,
		order = order or 99,
	})

	-- Ordenar
	table.sort(categories, function(a, b)
		return a.order < b.order
	end)
end

_G.SetMenuNotification = function(categoryName, hasNotif)
	for _, cat in ipairs(categories) do
		if cat.name == categoryName then
			cat.hasNotification = hasNotif
			break
		end
	end
	-- Atualizar dot
	updateNotifDot()
end

-- =====================================
-- CATEGORIAS PADRÃO
-- =====================================

local function registerDefaults()
	-- Cada sistema se registra sozinho via _G.RegisterMenuCategory
	-- Estes defaults são fallbacks caso o sistema ainda não tenha carregado

	_G.RegisterMenuCategory("LOJA", "🛒", function()
		if _G.OpenCharacterShop then
			_G.OpenCharacterShop()
		else
			local g = playerGui:FindFirstChild("CharacterSystemV3")
			if g then
				local f = g:FindFirstChild("MainFrame")
				if f then
					f.Visible = true
				end
			end
		end
	end, function()
		if _G.CloseCharacterShop then
			_G.CloseCharacterShop()
		else
			local g = playerGui:FindFirstChild("CharacterSystemV3")
			if g then
				local f = g:FindFirstChild("MainFrame")
				if f then
					f.Visible = false
				end
			end
		end
	end, 1)

	_G.RegisterMenuCategory("INVENTÁRIO", "📦", function()
		if _G.OpenCharacterInventory then
			_G.OpenCharacterInventory()
		else
			local g = playerGui:FindFirstChild("CharacterSystemV3")
			if g then
				local f = g:FindFirstChild("InventoryFrame")
				if f then
					f.Visible = true
				end
			end
		end
	end, function()
		if _G.CloseCharacterInventory then
			_G.CloseCharacterInventory()
		else
			local g = playerGui:FindFirstChild("CharacterSystemV3")
			if g then
				local f = g:FindFirstChild("InventoryFrame")
				if f then
					f.Visible = false
				end
			end
		end
	end, 2)

	_G.RegisterMenuCategory("TIMES", "👥", function()
		if _G.OpenTeamMenu then
			_G.OpenTeamMenu()
		else
			local g = playerGui:FindFirstChild("TeamMenuGui")
			if g then
				local bg = g:FindFirstChild("Background")
				if bg then
					bg.Visible = true
				end
				local mf = g:FindFirstChild("MainFrame")
				if mf then
					mf.Visible = true
				end
			end
		end
	end, function()
		if _G.CloseTeamMenu then
			_G.CloseTeamMenu()
		else
			local g = playerGui:FindFirstChild("TeamMenuGui")
			if g then
				local bg = g:FindFirstChild("Background")
				if bg then
					bg.Visible = false
				end
				local mf = g:FindFirstChild("MainFrame")
				if mf then
					mf.Visible = false
				end
			end
		end
	end, 3)

	_G.RegisterMenuCategory("TROCAS", "🔄", function()
		if _G.OpenTradePlayerList then
			_G.OpenTradePlayerList()
		end
	end, function()
		local g = playerGui:FindFirstChild("TradePlayerList")
		if g then
			g.Parent = nil
		end
	end, 4)

	_G.RegisterMenuCategory("MISSÕES", "📋", function()
		if _G.OpenMissionsMenu then
			_G.OpenMissionsMenu()
		end
	end, function()
		local g = playerGui:FindFirstChild("MissionsMenu")
		if g then
			g.Parent = nil
		end
	end, 5)

	_G.RegisterMenuCategory("MÚSICA", "🎵", function()
		if _G.OpenMusicPlayer then
			_G.OpenMusicPlayer()
		else
			local g = playerGui:FindFirstChild("MusicPlayerV4")
			if g then
				local bg = g:FindFirstChild("Background")
				if bg then
					bg.Visible = true
				end
				local mw = g:FindFirstChild("MainWindow")
				if mw then
					mw.Visible = true
				end
			end
		end
	end, function()
		if _G.CloseMusicPlayer then
			_G.CloseMusicPlayer()
		else
			local g = playerGui:FindFirstChild("MusicPlayerV4")
			if g then
				local bg = g:FindFirstChild("Background")
				if bg then
					bg.Visible = false
				end
				local mw = g:FindFirstChild("MainWindow")
				if mw then
					mw.Visible = false
				end
			end
		end
	end, 6)

	_G.RegisterMenuCategory("TUTORIAL", "❓", function()
		if _G.OpenTutorialMenu then
			_G.OpenTutorialMenu()
		else
			local g = playerGui:FindFirstChild("TutorialMenuV3")
			if g then
				local bg = g:FindFirstChild("Background")
				if bg then
					bg.Visible = true
				end
				local mw = g:FindFirstChild("MainWindow")
				if mw then
					mw.Visible = true
				end
			end
		end
	end, function()
		if _G.CloseTutorialMenu then
			_G.CloseTutorialMenu()
		else
			local g = playerGui:FindFirstChild("TutorialMenuV3")
			if g then
				local bg = g:FindFirstChild("Background")
				if bg then
					bg.Visible = false
				end
				local mw = g:FindFirstChild("MainWindow")
				if mw then
					mw.Visible = false
				end
			end
		end
	end, 7)

	-- ADMIN: só registra se o jogador for admin
	local ADMIN_IDS = { 1595442496, 8833465560, 1832521992 }
	if table.find(ADMIN_IDS, player.UserId) then
		_G.RegisterMenuCategory("ADMIN", "⚙️", function()
			if _G.OpenAdminMenu then
				_G.OpenAdminMenu()
			else
				local g = playerGui:FindFirstChild("AdminMenuV6")
				if g then
					local mf = g:FindFirstChild("MainFrame")
					if mf then
						mf.Visible = true
					end
				end
			end
		end, function()
			if _G.CloseAdminMenu then
				_G.CloseAdminMenu()
			else
				local g = playerGui:FindFirstChild("AdminMenuV6")
				if g then
					local mf = g:FindFirstChild("MainFrame")
					if mf then
						mf.Visible = false
					end
				end
			end
		end, 8)
	end -- if admin
end

registerDefaults()

-- =====================================
-- ATUALIZAR INDICADOR DE NOTIFICAÇÃO
-- =====================================

function updateNotifDot()
	if not notifDot then
		return
	end
	local hasAny = false
	for _, cat in ipairs(categories) do
		if cat.hasNotification then
			hasAny = true
			break
		end
	end
	notifDot.Visible = hasAny
end

-- =====================================
-- FECHAR SUBMENU ATIVO
-- =====================================

local function closeActiveSubmenu()
	if activeSubmenu then
		for _, cat in ipairs(categories) do
			if cat.name == activeSubmenu and cat.closeFunc then
				pcall(cat.closeFunc)
			end
		end
		activeSubmenu = nil
	end
end

-- =====================================
-- CRIAR HUB
-- =====================================

local function buildMenu()
	if menuGui then
		menuGui.Parent = nil
	end

	menuGui = Instance.new("ScreenGui")
	menuGui.Name = "UnifiedMenuV1"
	menuGui.ResetOnSpawn = false
	menuGui.IgnoreGuiInset = true
	menuGui.DisplayOrder = 50
	menuGui.Parent = playerGui

	-- ===== BOTÃO PRINCIPAL (☰) =====
	local btnSize = isMobile and UDim2.new(0.12, 0, 0.06, 0) or UDim2.new(0.06, 0, 0.06, 0)

	mainButton = Instance.new("TextButton")
	mainButton.Name = "MenuButton"
	mainButton.Size = btnSize
	mainButton.Position = isMobile and UDim2.new(0.01, 0, 0.4, 0) or UDim2.new(0.01, 0, 0.35, 0)
	mainButton.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
	mainButton.BorderColor3 = Color3.fromRGB(0, 200, 255)
	mainButton.BorderSizePixel = 3
	mainButton.Text = "☰"
	mainButton.TextColor3 = Color3.new(1, 1, 1)
	mainButton.TextScaled = true
	mainButton.Font = Enum.Font.Arcade
	mainButton.Parent = menuGui

	-- Notificação ponto vermelho
	notifDot = Instance.new("Frame")
	notifDot.Size = UDim2.new(0.3, 0, 0.3, 0)
	notifDot.Position = UDim2.new(0.75, 0, -0.05, 0)
	notifDot.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
	notifDot.BorderSizePixel = 0
	notifDot.Visible = false
	notifDot.Parent = mainButton

	local notifCorner = Instance.new("UICorner")
	notifCorner.CornerRadius = UDim.new(1, 0)
	notifCorner.Parent = notifDot

	-- Pulsação do botão principal
	task.spawn(function()
		while mainButton and mainButton.Parent do
			TweenService:Create(mainButton, TweenInfo.new(1.5, Enum.EasingStyle.Sine), {
				BorderColor3 = Color3.fromRGB(0, 150, 200),
			}):Play()
			task.wait(1.5)
			TweenService:Create(mainButton, TweenInfo.new(1.5, Enum.EasingStyle.Sine), {
				BorderColor3 = Color3.fromRGB(0, 200, 255),
			}):Play()
			task.wait(1.5)
		end
	end)

	-- ===== HUB FRAME =====
	local gc = getGridConfig()

	hubFrame = Instance.new("Frame")
	hubFrame.Name = "HubFrame"
	hubFrame.Size = UDim2.new(gc.hubScale, 0, gc.hubScale, 0)
	hubFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
	hubFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	hubFrame.BackgroundColor3 = Color3.fromRGB(12, 12, 18)
	hubFrame.BorderColor3 = Color3.fromRGB(0, 200, 255)
	hubFrame.BorderSizePixel = 4
	hubFrame.Visible = false
	hubFrame.Parent = menuGui

	local hubCorner = Instance.new("UICorner")
	hubCorner.CornerRadius = UDim.new(0.02, 0)
	hubCorner.Parent = hubFrame

	-- Header do HUB
	local hubHeader = Instance.new("Frame")
	hubHeader.Size = UDim2.new(1, 0, 0.1, 0)
	hubHeader.BackgroundColor3 = Color3.fromRGB(0, 60, 90)
	hubHeader.BorderSizePixel = 0
	hubHeader.Parent = hubFrame

	local hubHeaderCorner = Instance.new("UICorner")
	hubHeaderCorner.CornerRadius = UDim.new(0.02, 0)
	hubHeaderCorner.Parent = hubHeader

	local hubTitle = Instance.new("TextLabel")
	hubTitle.Size = UDim2.new(0.55, 0, 1, 0)
	hubTitle.Position = UDim2.new(0.02, 0, 0, 0)
	hubTitle.BackgroundTransparency = 1
	hubTitle.Text = "██ RETRO-VERSE ██"
	hubTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
	hubTitle.TextScaled = true
	hubTitle.Font = Enum.Font.Arcade
	hubTitle.Parent = hubHeader

	-- Forward declaration
	local buildGrid

	-- Botão resize
	local sizeBtn = Instance.new("TextButton")
	sizeBtn.Size = UDim2.new(0.08, 0, 0.7, 0)
	sizeBtn.Position = UDim2.new(0.72, 0, 0.15, 0)
	sizeBtn.BackgroundColor3 = Color3.fromRGB(0, 100, 150)
	sizeBtn.BorderSizePixel = 0
	sizeBtn.Text = SIZE_MODES[currentSizeIndex]
	sizeBtn.TextColor3 = Color3.new(1, 1, 1)
	sizeBtn.TextScaled = true
	sizeBtn.Font = Enum.Font.Arcade
	sizeBtn.Parent = hubHeader

	sizeBtn.MouseButton1Click:Connect(function()
		playSound("rbxassetid://156785206")
		currentSizeIndex = currentSizeIndex % #SIZE_MODES + 1
		sizeBtn.Text = SIZE_MODES[currentSizeIndex]
		-- Rebuild grid
		buildGrid()
		-- Resize hub
		local newGc = getGridConfig()
		TweenService:Create(hubFrame, TweenInfo.new(0.3), {
			Size = UDim2.new(newGc.hubScale, 0, newGc.hubScale, 0),
		}):Play()
	end)

	-- Botão fechar
	local closeBtn = Instance.new("TextButton")
	closeBtn.Size = UDim2.new(0.08, 0, 0.7, 0)
	closeBtn.Position = UDim2.new(0.88, 0, 0.15, 0)
	closeBtn.BackgroundColor3 = Color3.fromRGB(150, 0, 0)
	closeBtn.BorderSizePixel = 0
	closeBtn.Text = "X"
	closeBtn.TextColor3 = Color3.new(1, 1, 1)
	closeBtn.TextScaled = true
	closeBtn.Font = Enum.Font.Arcade
	closeBtn.Parent = hubHeader

	closeBtn.MouseButton1Click:Connect(function()
		playSound("rbxassetid://157167205")
		hubOpen = false
		hubFrame.Visible = false
	end)

	-- ===== GRID DE CATEGORIAS =====
	local gridContainer = Instance.new("Frame")
	gridContainer.Name = "GridContainer"
	gridContainer.Size = UDim2.new(0.94, 0, 0.85, 0)
	gridContainer.Position = UDim2.new(0.03, 0, 0.12, 0)
	gridContainer.BackgroundTransparency = 1
	gridContainer.Parent = hubFrame

	buildGrid = function()
		-- Limpar grid
		for _, child in ipairs(gridContainer:GetChildren()) do
			if child:IsA("TextButton") then
				child.Parent = nil
			end
		end

		local gc = getGridConfig()
		local cols = gc.cols

		for i, cat in ipairs(categories) do
			local col = (i - 1) % cols
			local row = math.floor((i - 1) / cols)

			local xPos = col * (gc.cellW + gc.gap) + gc.gap * 0.5
			local yPos = row * (gc.cellH + gc.gap) + gc.gap

			local catBtn = Instance.new("TextButton")
			catBtn.Name = "Cat_" .. cat.name
			catBtn.Size = UDim2.new(gc.cellW, 0, gc.cellH, 0)
			catBtn.Position = UDim2.new(xPos, 0, yPos, 0)
			catBtn.BackgroundColor3 = Color3.fromRGB(25, 30, 40)
			catBtn.BorderColor3 = Color3.fromRGB(80, 80, 120)
			catBtn.BorderSizePixel = 2
			catBtn.Text = ""
			catBtn.Parent = gridContainer

			local catCorner = Instance.new("UICorner")
			catCorner.CornerRadius = UDim.new(0.08, 0)
			catCorner.Parent = catBtn

			-- Ícone
			local iconLbl = Instance.new("TextLabel")
			iconLbl.Size = UDim2.new(1, 0, 0.55, 0)
			iconLbl.BackgroundTransparency = 1
			iconLbl.Text = cat.icon
			iconLbl.TextScaled = true
			iconLbl.Font = Enum.Font.Arcade
			iconLbl.Parent = catBtn

			-- Nome
			local nameLbl = Instance.new("TextLabel")
			nameLbl.Size = UDim2.new(0.9, 0, 0.35, 0)
			nameLbl.Position = UDim2.new(0.05, 0, 0.58, 0)
			nameLbl.BackgroundTransparency = 1
			nameLbl.Text = cat.name
			nameLbl.TextColor3 = Color3.fromRGB(200, 200, 220)
			nameLbl.TextScaled = true
			nameLbl.Font = Enum.Font.Arcade
			nameLbl.Parent = catBtn

			-- Indicador de notificação
			if cat.hasNotification then
				local catDot = Instance.new("Frame")
				catDot.Size = UDim2.new(0.15, 0, 0.15, 0)
				catDot.Position = UDim2.new(0.85, 0, 0, 0)
				catDot.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
				catDot.BorderSizePixel = 0
				catDot.Parent = catBtn
				local dc = Instance.new("UICorner")
				dc.CornerRadius = UDim.new(1, 0)
				dc.Parent = catDot
			end

			-- Hover effect
			catBtn.MouseEnter:Connect(function()
				TweenService:Create(catBtn, TweenInfo.new(0.15), {
					BackgroundColor3 = Color3.fromRGB(40, 50, 70),
					BorderColor3 = Color3.fromRGB(0, 200, 255),
				}):Play()
			end)
			catBtn.MouseLeave:Connect(function()
				TweenService:Create(catBtn, TweenInfo.new(0.15), {
					BackgroundColor3 = Color3.fromRGB(25, 30, 40),
					BorderColor3 = Color3.fromRGB(80, 80, 120),
				}):Play()
			end)

			-- Click → abre submenu
			catBtn.MouseButton1Click:Connect(function()
				playSound("rbxassetid://157167203")

				-- Fechar hub
				hubOpen = false
				hubFrame.Visible = false

				-- Fechar submenu anterior
				closeActiveSubmenu()

				-- Abrir novo submenu
				activeSubmenu = cat.name
				if cat.openFunc then
					pcall(cat.openFunc)
				end
			end)
		end
	end

	buildGrid()
	updateNotifDot()

	-- ===== CONEXÃO DO BOTÃO PRINCIPAL =====
	mainButton.MouseButton1Click:Connect(function()
		if hubOpen then
			-- Fechar tudo
			playSound("rbxassetid://157167205")
			hubOpen = false
			hubFrame.Visible = false
			closeActiveSubmenu()
		else
			-- Fechar submenu se aberto, senão abrir hub
			if activeSubmenu then
				closeActiveSubmenu()
				-- Reabrir hub
				playSound("rbxassetid://157167203")
				hubOpen = true
				hubFrame.Visible = true
				buildGrid() -- Refresh
			else
				playSound("rbxassetid://157167203")
				hubOpen = true
				hubFrame.Visible = true
				buildGrid() -- Refresh
			end
		end
	end)
end

-- =====================================
-- INICIALIZAÇÃO
-- =====================================

-- Esperar outros sistemas carregarem
task.spawn(function()
	task.wait(3)
	buildMenu()
end)

-- Rebuild ao respawnar
player.CharacterAdded:Connect(function()
	task.wait(2)
	if not menuGui or not menuGui.Parent then
		buildMenu()
	end
end)

-- =====================================
-- API PÚBLICA
-- =====================================

_G.UnifiedMenu = {
	rebuild = function()
		buildMenu()
	end,
	isOpen = function()
		return hubOpen
	end,
	close = function()
		hubOpen = false
		if hubFrame then
			hubFrame.Visible = false
		end
		closeActiveSubmenu()
	end,
	openCategory = function(categoryName)
		for _, cat in ipairs(categories) do
			if cat.name == categoryName and cat.openFunc then
				closeActiveSubmenu()
				activeSubmenu = cat.name
				pcall(cat.openFunc)
				return true
			end
		end
		return false
	end,
}

print([[
╔══════════════════════════════════════════════════════╗
║  UNIFIED MENU CLIENT V2 — CARREGADO                 ║
╠══════════════════════════════════════════════════════╣
║  SUBSTITUI: UnifiedMenu_Client_V1                    ║
║  REMOVER:   UnifiedMenu_Client_V1                    ║
╠══════════════════════════════════════════════════════╣
║  ÚNICO BOTÃO NA TELA (☰)                            ║
║  Todos os outros sistemas SEM botão próprio          ║
╠══════════════════════════════════════════════════════╣
║  CATEGORIAS:                                         ║
║  LOJA | INVENTÁRIO | TIMES | TROCAS                  ║
║  MISSÕES | MÚSICA | TUTORIAL | ADMIN                 ║
╚══════════════════════════════════════════════════════╝
]])
