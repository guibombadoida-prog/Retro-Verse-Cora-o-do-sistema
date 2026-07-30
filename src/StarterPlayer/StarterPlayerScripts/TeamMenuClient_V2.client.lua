-- ============================================
-- INTERFACE DE TIMES V6 - SEM BOTÃO PRÓPRIO (MENU UNIFICADO)
-- (V6) ALTERAÇÕES: wait() -> task.wait(); :Destroy() -> .Parent = nil; fontes retro (Arcade/Code)
-- Coloque em StarterPlayer > StarterPlayerScripts
-- Nome: "TeamMenuClient_V2"
-- SUBSTITUI: TeamMenuClient (V4)  →  REMOVER o antigo
-- ============================================
-- NOVIDADES V5:
-- • BOTÃO FLUTUANTE PRÓPRIO REMOVIDO (só abre pelo menu unificado ☰)
-- • Expõe _G.OpenTeamMenu / _G.CloseTeamMenu (usados pelo UnifiedMenu)
-- • Mantém _G.ToggleTeamMenu (usado internamente no resize)
-- • Resto da UI 100% preservado (responsiva Mobile/Tablet/PC)
-- ============================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local GuiService = game:GetService("GuiService")
local SoundService = game:GetService("SoundService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- =====================================
-- DETECÇÃO DE PLATAFORMA
-- =====================================

local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
local isTablet = isMobile and (workspace.CurrentCamera.ViewportSize.X > 600)
local isConsole = GuiService:IsTenFootInterface()

print(
	string.format(
		"[TEAM UI V4] Plataforma: %s",
		isMobile and (isTablet and "Tablet" or "Mobile") or (isConsole and "Console" or "PC")
	)
)

-- =====================================
-- SONS (REUTILIZADOS DO MENU)
-- =====================================

local sounds = {
	hover = "rbxassetid://12846056",
	click = "rbxassetid://156785206",
	purchase = "rbxassetid://5031873608",
	error = "rbxassetid://2865228021",
	open = "rbxassetid://157167203",
	close = "rbxassetid://157167205",
	info = "rbxassetid://156785206",
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
-- SISTEMA DE TAMANHOS (SINCRONIZADO)
-- =====================================

local UI_SIZES = {
	SMALL = "Pequeno",
	MEDIUM = "Médio",
	LARGE = "Grande",
}

-- DETECTAR TAMANHO DO CHARACTER MENU
local function detectCharacterMenuSize()
	local charMenuGui = playerGui:FindFirstChild("CharacterMenuV13")
		or playerGui:FindFirstChild("CharacterMenuV12")
	if not charMenuGui then
		return UI_SIZES.MEDIUM -- Padrão se não encontrar
	end

	local mainFrame = charMenuGui:FindFirstChild("MainFrame")
	if not mainFrame then
		return UI_SIZES.MEDIUM
	end

	-- Detectar pelo tamanho do frame
	local size = mainFrame.Size.X.Scale

	if isTablet then
		if size <= 0.75 then
			return UI_SIZES.SMALL
		elseif size >= 0.95 then
			return UI_SIZES.LARGE
		else
			return UI_SIZES.MEDIUM
		end
	elseif isMobile then
		if size <= 0.85 then
			return UI_SIZES.SMALL
		elseif size >= 0.98 then
			return UI_SIZES.LARGE
		else
			return UI_SIZES.MEDIUM
		end
	else
		if size <= 0.65 then
			return UI_SIZES.SMALL
		elseif size >= 0.85 then
			return UI_SIZES.LARGE
		else
			return UI_SIZES.MEDIUM
		end
	end
end

local currentUISize = detectCharacterMenuSize()

local function getUIScale()
	local baseScale

	if isTablet then
		baseScale = {
			menu = { small = 0.75, medium = 0.85, large = 0.95 },
			button = { small = 0.10, medium = 0.12, large = 0.14 },
			buttonSpacing = { small = 0.11, medium = 0.13, large = 0.15 },
		}
	elseif isMobile then
		baseScale = {
			menu = { small = 0.85, medium = 0.92, large = 0.98 },
			button = { small = 0.12, medium = 0.15, large = 0.18 },
			buttonSpacing = { small = 0.13, medium = 0.16, large = 0.19 },
		}
	else
		baseScale = {
			menu = { small = 0.65, medium = 0.75, large = 0.85 },
			button = { small = 0.08, medium = 0.10, large = 0.12 },
			buttonSpacing = { small = 0.09, medium = 0.11, large = 0.13 },
		}
	end

	local size = currentUISize == UI_SIZES.SMALL and "small"
		or (currentUISize == UI_SIZES.LARGE and "large" or "medium")

	return {
		menu = UDim2.new(baseScale.menu[size], 0, baseScale.menu[size], 0),
		button = UDim2.new(baseScale.button[size], 0, baseScale.button[size] * 0.65, 0),
		buttonSpacing = baseScale.buttonSpacing[size],
	}
end

local uiScale = getUIScale()

-- =====================================
-- AGUARDAR REMOTES
-- =====================================

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local createTeamRemote = remotes:WaitForChild("CreateTeam")
local inviteToTeamRemote = remotes:WaitForChild("InviteToTeam")
local respondToInviteRemote = remotes:WaitForChild("RespondToInvite")
local leaveTeamRemote = remotes:WaitForChild("LeaveTeam")
local updateTeamListRemote = remotes:WaitForChild("UpdateTeamList")
local kickFromTeamRemote = remotes:WaitForChild("KickFromTeam")
local getAvailableColorsRemote = remotes:WaitForChild("GetAvailableColors")

local updateColorsRemote = remotes:FindFirstChild("UpdateAvailableColors")
if not updateColorsRemote then
	updateColorsRemote = Instance.new("RemoteEvent")
	updateColorsRemote.Name = "UpdateAvailableColors"
	updateColorsRemote.Parent = remotes
end

-- =====================================
-- VARIÁVEIS
-- =====================================

local teamMenuGui = nil
local currentTeams = {}
local availableColors = {}
local isMenuOpen = false

-- =====================================
-- CORES DA INTERFACE
-- =====================================

local COLORS = {
	background = Color3.fromRGB(20, 20, 20),
	panel = Color3.fromRGB(30, 30, 30),
	header = Color3.fromRGB(40, 40, 40),
	border = Color3.fromRGB(255, 255, 255),
	success = Color3.fromRGB(0, 200, 0),
	error = Color3.fromRGB(200, 0, 0),
	warning = Color3.fromRGB(255, 200, 0),
	disabled = Color3.fromRGB(100, 100, 100),
}

-- =====================================
-- FUNÇÕES DE NOTIFICAÇÃO
-- =====================================

local function showNotification(message, isSuccess)
	playSound(isSuccess and sounds.purchase or sounds.error)

	local notification = Instance.new("ScreenGui")
	notification.Name = "TeamNotification"
	notification.ResetOnSpawn = false
	notification.DisplayOrder = 100
	notification.Parent = playerGui

	local frame = Instance.new("Frame")
	frame.Size = isMobile and UDim2.new(0.8, 0, 0.12, 0) or UDim2.new(0.4, 0, 0.08, 0)
	frame.Position = isMobile and UDim2.new(0.1, 0, 0.05, 0) or UDim2.new(0.3, 0, 0.05, 0)
	frame.BackgroundColor3 = COLORS.background
	frame.BorderColor3 = isSuccess and COLORS.success or COLORS.error
	frame.BorderSizePixel = 3
	frame.Parent = notification

	local text = Instance.new("TextLabel")
	text.Size = UDim2.new(1, 0, 1, 0)
	text.BackgroundTransparency = 1
	text.Text = message
	text.TextColor3 = Color3.new(1, 1, 1)
	text.TextScaled = true
	text.Font = Enum.Font.Arcade
	text.Parent = frame

	task.wait(3)
	notification.Parent = nil
end

-- =====================================
-- ATUALIZAR CORES DISPONÍVEIS
-- =====================================

local function updateAvailableColors()
	local success, colors = pcall(function()
		return getAvailableColorsRemote:InvokeServer()
	end)

	if success and colors then
		availableColors = colors
	end
end

-- =====================================
-- CRIAR MENU PRINCIPAL
-- =====================================

local function createTeamMenu()
	if teamMenuGui then
		teamMenuGui.Parent = nil
	end

	teamMenuGui = Instance.new("ScreenGui")
	teamMenuGui.Name = "TeamMenuGui"
	teamMenuGui.ResetOnSpawn = false
	teamMenuGui.DisplayOrder = 50
	teamMenuGui.Parent = playerGui

	-- =====================================
	-- (BOTÃO FLUTUANTE PRÓPRIO REMOVIDO — abre só pelo menu unificado ☰)
	-- =====================================

	-- Fundo escuro
	local background = Instance.new("TextButton")
	background.Name = "Background"
	background.Size = UDim2.new(1, 0, 1, 0)
	background.BackgroundColor3 = Color3.new(0, 0, 0)
	background.BackgroundTransparency = 0.5
	background.BorderSizePixel = 0
	background.Text = ""
	background.AutoButtonColor = false
	background.Visible = false
	background.Parent = teamMenuGui

	-- Menu principal
	local mainFrame = Instance.new("Frame")
	mainFrame.Name = "MainFrame"
	mainFrame.Size = uiScale.menu
	mainFrame.Position =
		UDim2.new((1 - uiScale.menu.X.Scale) / 2, 0, (1 - uiScale.menu.Y.Scale) / 2, 0)
	mainFrame.BackgroundColor3 = COLORS.background
	mainFrame.BorderColor3 = COLORS.border
	mainFrame.BorderSizePixel = 4
	mainFrame.Visible = false
	mainFrame.Parent = teamMenuGui

	-- Header
	local header = Instance.new("Frame")
	header.Size = UDim2.new(1, 0, 0.12, 0)
	header.BackgroundColor3 = COLORS.header
	header.BorderSizePixel = 0
	header.Parent = mainFrame

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(0.85, 0, 1, 0)
	title.BackgroundTransparency = 1
	title.Text = "👥 SISTEMA DE TIMES"
	title.TextColor3 = COLORS.warning
	title.TextScaled = true
	title.Font = Enum.Font.Arcade
	title.Parent = header

	local closeButton = Instance.new("TextButton")
	closeButton.Size = UDim2.new(0.1, 0, 0.7, 0)
	closeButton.Position = UDim2.new(0.88, 0, 0.15, 0)
	closeButton.BackgroundColor3 = COLORS.error
	closeButton.BorderSizePixel = 0
	closeButton.Text = "X"
	closeButton.TextColor3 = Color3.new(1, 1, 1)
	closeButton.TextScaled = true
	closeButton.Font = Enum.Font.Arcade
	closeButton.Parent = header

	-- Container com scroll
	local contentScroll = Instance.new("ScrollingFrame")
	contentScroll.Size = UDim2.new(0.98, 0, 0.86, 0)
	contentScroll.Position = UDim2.new(0.01, 0, 0.13, 0)
	contentScroll.BackgroundColor3 = COLORS.panel
	contentScroll.BorderColor3 = COLORS.border
	contentScroll.BorderSizePixel = 2
	contentScroll.ScrollBarThickness = isMobile and 8 or 12
	contentScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
	contentScroll.Parent = mainFrame

	-- =====================================
	-- SEÇÃO: CRIAR TIME
	-- =====================================

	local createSection = Instance.new("Frame")
	createSection.Size = UDim2.new(0.96, 0, 0, isMobile and 240 or 200)
	createSection.Position = UDim2.new(0.02, 0, 0, 10)
	createSection.BackgroundColor3 = COLORS.header
	createSection.BorderColor3 = COLORS.border
	createSection.BorderSizePixel = 2
	createSection.Parent = contentScroll

	local createTitle = Instance.new("TextLabel")
	createTitle.Size = UDim2.new(1, 0, 0, 30)
	createTitle.BackgroundTransparency = 1
	createTitle.Text = "🏆 CRIAR NOVO TIME"
	createTitle.TextColor3 = COLORS.success
	createTitle.TextScaled = true
	createTitle.Font = Enum.Font.Arcade
	createTitle.Parent = createSection

	local nameInput = Instance.new("TextBox")
	nameInput.Size = UDim2.new(isMobile and 0.9 or 0.6, 0, 0, 35)
	nameInput.Position = UDim2.new(0.05, 0, 0, 40)
	nameInput.BackgroundColor3 = COLORS.panel
	nameInput.BorderColor3 = COLORS.border
	nameInput.BorderSizePixel = 2
	nameInput.PlaceholderText = "Nome do Time (3-20)"
	nameInput.Text = ""
	nameInput.TextColor3 = Color3.new(1, 1, 1)
	nameInput.TextSize = 18
	nameInput.Font = Enum.Font.Code
	nameInput.ClearTextOnFocus = false
	nameInput.Parent = createSection

	local colorLabel = Instance.new("TextLabel")
	colorLabel.Size = UDim2.new(0.9, 0, 0, 25)
	colorLabel.Position = UDim2.new(0.05, 0, 0, 85)
	colorLabel.BackgroundTransparency = 1
	colorLabel.Text = "ESCOLHA UMA COR:"
	colorLabel.TextColor3 = Color3.new(1, 1, 1)
	colorLabel.TextScaled = true
	colorLabel.Font = Enum.Font.Code
	colorLabel.TextXAlignment = Enum.TextXAlignment.Left
	colorLabel.Parent = createSection

	local colorScroll = Instance.new("ScrollingFrame")
	colorScroll.Size = UDim2.new(0.9, 0, 0, 80)
	colorScroll.Position = UDim2.new(0.05, 0, 0, 115)
	colorScroll.BackgroundColor3 = COLORS.panel
	colorScroll.BorderColor3 = COLORS.border
	colorScroll.BorderSizePixel = 1
	colorScroll.ScrollBarThickness = 6
	colorScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
	colorScroll.Parent = createSection

	local selectedColor = nil
	local colorButtons = {}

	local function refreshColorButtons()
		for _, btn in pairs(colorButtons) do
			btn.Parent = nil
		end
		colorButtons = {}

		local cols = isMobile and 5 or 8
		local buttonSize = 30
		local spacing = 5

		for i, colorData in ipairs(availableColors) do
			local col = (i - 1) % cols
			local row = math.floor((i - 1) / cols)

			local colorButton = Instance.new("TextButton")
			colorButton.Size = UDim2.new(0, buttonSize, 0, buttonSize)
			colorButton.Position =
				UDim2.new(0, 5 + col * (buttonSize + spacing), 0, 5 + row * (buttonSize + spacing))
			colorButton.BackgroundColor3 = colorData.color
			colorButton.BorderColor3 = COLORS.border
			colorButton.BorderSizePixel = selectedColor == colorData.color and 4 or 2
			colorButton.Text = colorData.available and "" or "✗"
			colorButton.TextColor3 = Color3.new(1, 1, 1)
			colorButton.TextScaled = true
			colorButton.Font = Enum.Font.Arcade
			colorButton.Parent = colorScroll

			if not colorData.available then
				colorButton.BackgroundTransparency = 0.5
			end

			colorButton.MouseButton1Click:Connect(function()
				if not colorData.available then
					showNotification("Esta cor já está sendo usada por outro time!", false)
					return
				end

				playSound(sounds.click)
				selectedColor = colorData.color
				refreshColorButtons()
			end)

			table.insert(colorButtons, colorButton)
		end

		local rows = math.ceil(#availableColors / cols)
		colorScroll.CanvasSize = UDim2.new(0, 0, 0, rows * (buttonSize + spacing) + 10)
	end

	local createButton = Instance.new("TextButton")
	createButton.Size = UDim2.new(isMobile and 0.9 or 0.3, 0, 0, 35)
	createButton.Position = isMobile and UDim2.new(0.05, 0, 0, 205) or UDim2.new(0.68, 0, 0, 40)
	createButton.BackgroundColor3 = COLORS.success
	createButton.BorderColor3 = COLORS.border
	createButton.BorderSizePixel = 2
	createButton.Text = "✓ CRIAR TIME"
	createButton.TextColor3 = Color3.new(1, 1, 1)
	createButton.TextScaled = true
	createButton.Font = Enum.Font.Arcade
	createButton.Parent = createSection

	-- =====================================
	-- SEÇÃO: TIMES EXISTENTES
	-- =====================================

	local teamsSection = Instance.new("Frame")
	teamsSection.Size = UDim2.new(0.96, 0, 0, 60)
	teamsSection.Position = UDim2.new(0.02, 0, 0, isMobile and 260 or 220)
	teamsSection.BackgroundTransparency = 1
	teamsSection.Parent = contentScroll

	local teamsTitle = Instance.new("TextLabel")
	teamsTitle.Size = UDim2.new(1, 0, 0, 40)
	teamsTitle.BackgroundColor3 = COLORS.header
	teamsTitle.BorderSizePixel = 0
	teamsTitle.Text = "📋 TIMES EXISTENTES"
	teamsTitle.TextColor3 = COLORS.warning
	teamsTitle.TextScaled = true
	teamsTitle.Font = Enum.Font.Arcade
	teamsTitle.Parent = teamsSection

	local teamsList = Instance.new("Frame")
	teamsList.Size = UDim2.new(1, 0, 0, 0)
	teamsList.Position = UDim2.new(0, 0, 0, 50)
	teamsList.BackgroundTransparency = 1
	teamsList.Parent = teamsSection

	-- =====================================
	-- SEÇÃO: CONVIDAR JOGADORES
	-- =====================================

	local inviteSection = Instance.new("Frame")
	inviteSection.Name = "InviteSection"
	inviteSection.Size = UDim2.new(0.96, 0, 0, isMobile and 350 or 300)
	inviteSection.Position = UDim2.new(0.02, 0, 0, 0)
	inviteSection.BackgroundColor3 = COLORS.header
	inviteSection.BorderColor3 = COLORS.border
	inviteSection.BorderSizePixel = 2
	inviteSection.Visible = false
	inviteSection.Parent = contentScroll

	local inviteTitle = Instance.new("TextLabel")
	inviteTitle.Size = UDim2.new(1, 0, 0, 40)
	inviteTitle.BackgroundTransparency = 1
	inviteTitle.Text = "📧 CONVIDAR JOGADORES"
	inviteTitle.TextColor3 = COLORS.success
	inviteTitle.TextScaled = true
	inviteTitle.Font = Enum.Font.Arcade
	inviteTitle.Parent = inviteSection

	local playerListScroll = Instance.new("ScrollingFrame")
	playerListScroll.Size = UDim2.new(0.96, 0, 0, isMobile and 290 or 240)
	playerListScroll.Position = UDim2.new(0.02, 0, 0, 50)
	playerListScroll.BackgroundColor3 = COLORS.panel
	playerListScroll.BorderColor3 = COLORS.border
	playerListScroll.BorderSizePixel = 2
	playerListScroll.ScrollBarThickness = 6
	playerListScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
	playerListScroll.Parent = inviteSection

	-- =====================================
	-- FUNÇÕES DE ATUALIZAÇÃO
	-- =====================================

	local function updatePlayersList()
		for _, child in pairs(playerListScroll:GetChildren()) do
			if child:IsA("Frame") then
				child.Parent = nil
			end
		end

		local myTeam = nil
		for _, team in ipairs(currentTeams) do
			for _, member in pairs(team.members) do
				if member == player then
					myTeam = team
					break
				end
			end
			if myTeam then
				break
			end
		end

		if not myTeam or myTeam.leader ~= player then
			return
		end

		local yPos = 5
		local itemHeight = isMobile and 50 or 45

		for _, targetPlayer in pairs(Players:GetPlayers()) do
			if targetPlayer ~= player then
				local isInTeam = false
				for _, team in ipairs(currentTeams) do
					for _, member in pairs(team.members) do
						if member == targetPlayer then
							isInTeam = true
							break
						end
					end
					if isInTeam then
						break
					end
				end

				local playerFrame = Instance.new("Frame")
				playerFrame.Size = UDim2.new(0.98, 0, 0, itemHeight)
				playerFrame.Position = UDim2.new(0.01, 0, 0, yPos)
				playerFrame.BackgroundColor3 = COLORS.background
				playerFrame.BorderColor3 = COLORS.border
				playerFrame.BorderSizePixel = 1
				playerFrame.Parent = playerListScroll

				local nameLabel = Instance.new("TextLabel")
				nameLabel.Size = UDim2.new(isMobile and 0.55 or 0.5, 0, 1, 0)
				nameLabel.Position = UDim2.new(0.05, 0, 0, 0)
				nameLabel.BackgroundTransparency = 1
				nameLabel.Text = targetPlayer.Name
				nameLabel.TextColor3 = Color3.new(1, 1, 1)
				nameLabel.TextScaled = true
				nameLabel.Font = Enum.Font.Code
				nameLabel.TextXAlignment = Enum.TextXAlignment.Left
				nameLabel.Parent = playerFrame

				local statusLabel = Instance.new("TextLabel")
				statusLabel.Size = UDim2.new(isMobile and 0.25 or 0.25, 0, 0.8, 0)
				statusLabel.Position = UDim2.new(isMobile and 0.35 or 0.55, 0, 0.1, 0)
				statusLabel.BackgroundTransparency = 1
				statusLabel.Text = isInTeam and "Em Time" or "Livre"
				statusLabel.TextColor3 = isInTeam and COLORS.error or COLORS.success
				statusLabel.TextScaled = true
				statusLabel.Font = Enum.Font.Code
				statusLabel.Parent = playerFrame

				if not isInTeam then
					local inviteButton = Instance.new("TextButton")
					inviteButton.Size = UDim2.new(isMobile and 0.18 or 0.15, 0, 0.8, 0)
					inviteButton.Position = UDim2.new(isMobile and 0.78 or 0.83, 0, 0.1, 0)
					inviteButton.BackgroundColor3 = Color3.fromRGB(0, 150, 255)
					inviteButton.BorderSizePixel = 1
					inviteButton.BorderColor3 = COLORS.border
					inviteButton.Text = "✉️"
					inviteButton.TextColor3 = Color3.new(1, 1, 1)
					inviteButton.TextScaled = true
					inviteButton.Font = Enum.Font.Arcade
					inviteButton.Parent = playerFrame

					inviteButton.MouseButton1Click:Connect(function()
						playSound(sounds.click)
						inviteToTeamRemote:FireServer(targetPlayer.Name)
						inviteButton.BackgroundColor3 = COLORS.header
						inviteButton.Text = "✓"
						task.wait(2)
						if inviteButton.Parent then
							inviteButton.BackgroundColor3 = Color3.fromRGB(0, 150, 255)
							inviteButton.Text = "✉️"
						end
					end)
				end

				yPos = yPos + itemHeight + 5
			end
		end

		playerListScroll.CanvasSize = UDim2.new(0, 0, 0, yPos)
	end

	local function updateTeamsList()
		for _, child in pairs(teamsList:GetChildren()) do
			child.Parent = nil
		end

		local yPos = 0
		local myTeam = nil
		local itemHeight = isMobile and 90 or 80

		for _, team in ipairs(currentTeams) do
			for _, member in pairs(team.members) do
				if member == player then
					myTeam = team
					break
				end
			end
			if myTeam then
				break
			end
		end

		for i, team in ipairs(currentTeams) do
			local teamCard = Instance.new("Frame")
			teamCard.Size = UDim2.new(1, 0, 0, itemHeight)
			teamCard.Position = UDim2.new(0, 0, 0, yPos)
			teamCard.BackgroundColor3 = COLORS.background
			teamCard.BorderColor3 = team.color
			teamCard.BorderSizePixel = 3
			teamCard.Parent = teamsList

			local teamNameLabel = Instance.new("TextLabel")
			teamNameLabel.Size = UDim2.new(isMobile and 0.5 or 0.4, 0, 0.35, 0)
			teamNameLabel.Position = UDim2.new(0.05, 0, 0.1, 0)
			teamNameLabel.BackgroundTransparency = 1
			teamNameLabel.Text = team.name
			teamNameLabel.TextColor3 = team.color
			teamNameLabel.TextScaled = true
			teamNameLabel.Font = Enum.Font.Arcade
			teamNameLabel.TextXAlignment = Enum.TextXAlignment.Left
			teamNameLabel.Parent = teamCard

			local memberCount = Instance.new("TextLabel")
			memberCount.Size = UDim2.new(isMobile and 0.25 or 0.2, 0, 0.25, 0)
			memberCount.Position = UDim2.new(0.05, 0, 0.5, 0)
			memberCount.BackgroundTransparency = 1
			memberCount.Text = "👥 " .. #team.members .. "/4"
			memberCount.TextColor3 = Color3.new(1, 1, 1)
			memberCount.TextScaled = true
			memberCount.Font = Enum.Font.Code
			memberCount.TextXAlignment = Enum.TextXAlignment.Left
			memberCount.Parent = teamCard

			local leaderLabel = Instance.new("TextLabel")
			leaderLabel.Size = UDim2.new(isMobile and 0.45 or 0.4, 0, 0.25, 0)
			leaderLabel.Position = UDim2.new(isMobile and 0.32 or 0.3, 0, 0.5, 0)
			leaderLabel.BackgroundTransparency = 1
			leaderLabel.Text = "👑 " .. team.leader.Name
			leaderLabel.TextColor3 = COLORS.warning
			leaderLabel.TextScaled = true
			leaderLabel.Font = Enum.Font.Code
			leaderLabel.TextXAlignment = Enum.TextXAlignment.Left
			leaderLabel.Parent = teamCard

			local isMyTeam = myTeam and myTeam.id == team.id
			if isMyTeam then
				local actionButton = Instance.new("TextButton")
				actionButton.Size = UDim2.new(isMobile and 0.25 or 0.2, 0, 0.4, 0)
				actionButton.Position = UDim2.new(isMobile and 0.7 or 0.75, 0, 0.3, 0)
				actionButton.BackgroundColor3 = COLORS.error
				actionButton.BorderColor3 = COLORS.border
				actionButton.BorderSizePixel = 2
				actionButton.Text = "SAIR"
				actionButton.TextColor3 = Color3.new(1, 1, 1)
				actionButton.TextScaled = true
				actionButton.Font = Enum.Font.Arcade
				actionButton.Parent = teamCard

				actionButton.MouseButton1Click:Connect(function()
					playSound(sounds.click)
					leaveTeamRemote:FireServer()
				end)
			end

			yPos = yPos + itemHeight + 5
		end

		teamsSection.Size = UDim2.new(0.96, 0, 0, math.max(100, yPos + 60))
		teamsList.Size = UDim2.new(1, 0, 0, yPos)

		inviteSection.Position =
			UDim2.new(0.02, 0, 0, teamsSection.Position.Y.Offset + teamsSection.Size.Y.Offset + 10)
		inviteSection.Visible = myTeam and myTeam.leader == player or false

		if inviteSection.Visible then
			updatePlayersList()
		end

		local totalHeight = teamsSection.Position.Y.Offset
			+ teamsSection.Size.Y.Offset
			+ (inviteSection.Visible and inviteSection.Size.Y.Offset + 20 or 10)
		contentScroll.CanvasSize = UDim2.new(0, 0, 0, totalHeight)
	end

	-- =====================================
	-- EVENTOS
	-- =====================================

	createButton.MouseButton1Click:Connect(function()
		local teamName = nameInput.Text

		if teamName == "" then
			showNotification("Digite um nome para o time!", false)
			return
		end

		if #teamName < 3 or #teamName > 20 then
			showNotification("Nome deve ter 3-20 caracteres!", false)
			return
		end

		if not selectedColor then
			showNotification("Selecione uma cor para o time!", false)
			return
		end

		playSound(sounds.click)

		local success, result = createTeamRemote:InvokeServer(teamName, selectedColor)

		if success then
			showNotification("Time '" .. teamName .. "' criado!", true)
			nameInput.Text = ""
			selectedColor = nil
			updateAvailableColors()
			refreshColorButtons()
		else
			showNotification(result or "Erro ao criar time!", false)
		end
	end)

	local function toggleMenu()
		isMenuOpen = not isMenuOpen
		background.Visible = isMenuOpen
		mainFrame.Visible = isMenuOpen

		playSound(isMenuOpen and sounds.open or sounds.close)

		if isMenuOpen then
			updateAvailableColors()
			refreshColorButtons()
			updateTeamsList()
		end
	end

	_G.ToggleTeamMenu = toggleMenu

	-- Abertura/fechamento pelo MENU UNIFICADO (sem botão flutuante próprio)
	_G.OpenTeamMenu = function()
		if not isMenuOpen then
			toggleMenu()
		end
	end
	_G.CloseTeamMenu = function()
		if isMenuOpen then
			toggleMenu()
		end
	end

	closeButton.MouseButton1Click:Connect(toggleMenu)
	background.MouseButton1Click:Connect(toggleMenu)

	updateTeamListRemote.OnClientEvent:Connect(function(teams)
		currentTeams = teams
		if isMenuOpen then
			updateTeamsList()
		end
	end)

	updateColorsRemote.OnClientEvent:Connect(function(colors)
		availableColors = colors
		if isMenuOpen then
			refreshColorButtons()
		end
	end)

	updateAvailableColors()
	refreshColorButtons()
end

-- =====================================
-- SISTEMA DE CONVITES
-- =====================================

local function createInvitePopup(teamName, inviterName, teamColor)
	playSound(sounds.info)

	local inviteGui = Instance.new("ScreenGui")
	inviteGui.Name = "InvitePopup"
	inviteGui.ResetOnSpawn = false
	inviteGui.DisplayOrder = 100
	inviteGui.Parent = playerGui

	local popup = Instance.new("Frame")
	popup.Size = isMobile and UDim2.new(0.85, 0, 0.35, 0) or UDim2.new(0.4, 0, 0.25, 0)
	popup.Position = UDim2.new(0.5, 0, -0.5, 0)
	popup.AnchorPoint = Vector2.new(0.5, 0.5)
	popup.BackgroundColor3 = COLORS.background
	popup.BorderColor3 = teamColor
	popup.BorderSizePixel = 4
	popup.Parent = inviteGui

	TweenService:Create(popup, TweenInfo.new(0.5, Enum.EasingStyle.Bounce), {
		Position = UDim2.new(0.5, 0, 0.3, 0),
	}):Play()

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0.25, 0)
	title.BackgroundColor3 = COLORS.header
	title.BorderSizePixel = 0
	title.Text = "📨 CONVITE DE TIME!"
	title.TextColor3 = COLORS.warning
	title.TextScaled = true
	title.Font = Enum.Font.Arcade
	title.Parent = popup

	local message = Instance.new("TextLabel")
	message.Size = UDim2.new(0.9, 0, 0.35, 0)
	message.Position = UDim2.new(0.05, 0, 0.3, 0)
	message.BackgroundTransparency = 1
	message.Text = inviterName .. " convidou você para:\n" .. teamName
	message.TextColor3 = Color3.new(1, 1, 1)
	message.TextScaled = true
	message.Font = Enum.Font.Code
	message.TextWrapped = true
	message.Parent = popup

	local buttonFrame = Instance.new("Frame")
	buttonFrame.Size = UDim2.new(0.9, 0, 0.25, 0)
	buttonFrame.Position = UDim2.new(0.05, 0, 0.7, 0)
	buttonFrame.BackgroundTransparency = 1
	buttonFrame.Parent = popup

	local acceptButton = Instance.new("TextButton")
	acceptButton.Size = UDim2.new(0.48, 0, 1, 0)
	acceptButton.BackgroundColor3 = COLORS.success
	acceptButton.BorderColor3 = COLORS.border
	acceptButton.BorderSizePixel = 2
	acceptButton.Text = "✅ ACEITAR"
	acceptButton.TextColor3 = Color3.new(1, 1, 1)
	acceptButton.TextScaled = true
	acceptButton.Font = Enum.Font.Arcade
	acceptButton.Parent = buttonFrame

	local declineButton = Instance.new("TextButton")
	declineButton.Size = UDim2.new(0.48, 0, 1, 0)
	declineButton.Position = UDim2.new(0.52, 0, 0, 0)
	declineButton.BackgroundColor3 = COLORS.error
	declineButton.BorderColor3 = COLORS.border
	declineButton.BorderSizePixel = 2
	declineButton.Text = "❌ RECUSAR"
	declineButton.TextColor3 = Color3.new(1, 1, 1)
	declineButton.TextScaled = true
	declineButton.Font = Enum.Font.Arcade
	declineButton.Parent = buttonFrame

	local timerLabel = Instance.new("TextLabel")
	timerLabel.Size = UDim2.new(1, 0, 0.15, 0)
	timerLabel.Position = UDim2.new(0, 0, 0.65, 0)
	timerLabel.BackgroundTransparency = 1
	timerLabel.Text = "Expira em: 20s"
	timerLabel.TextColor3 = COLORS.warning
	timerLabel.TextScaled = true
	timerLabel.Font = Enum.Font.Code
	timerLabel.Parent = popup

	local timeLeft = 20
	task.spawn(function()
		while timeLeft > 0 and inviteGui.Parent do
			task.wait(1)
			timeLeft = timeLeft - 1
			if timerLabel.Parent then
				timerLabel.Text = "Expira em: " .. timeLeft .. "s"
			end
		end
		if inviteGui.Parent then
			respondToInviteRemote:FireServer(false)
			inviteGui.Parent = nil
		end
	end)

	acceptButton.MouseButton1Click:Connect(function()
		playSound(sounds.purchase)
		respondToInviteRemote:FireServer(true)
		inviteGui.Parent = nil
	end)

	declineButton.MouseButton1Click:Connect(function()
		playSound(sounds.error)
		respondToInviteRemote:FireServer(false)
		inviteGui.Parent = nil
	end)
end

inviteToTeamRemote.OnClientEvent:Connect(function(teamName, inviterName, teamColor)
	createInvitePopup(teamName, inviterName, teamColor)
end)

-- =====================================
-- MONITORAR MUDANÇAS DE TAMANHO
-- =====================================

-- Função para detectar mudanças no Character Menu
local function monitorCharacterMenuSize()
	task.spawn(function()
		while task.wait(1) do
			local newSize = detectCharacterMenuSize()
			if newSize ~= currentUISize then
				print(
					string.format(
						"[TEAM UI V4] 📏 Tamanho alterado: %s → %s",
						currentUISize,
						newSize
					)
				)
				currentUISize = newSize

				local wasOpen = isMenuOpen
				uiScale = getUIScale()
				createTeamMenu()

				if wasOpen then
					_G.ToggleTeamMenu()
				end
			end
		end
	end)
end

-- =====================================
-- DETECÇÃO DE ROTAÇÃO
-- =====================================

if isMobile then
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
		task.wait(0.5)

		isTablet = workspace.CurrentCamera.ViewportSize.X > 600
		currentUISize = detectCharacterMenuSize()
		uiScale = getUIScale()

		if teamMenuGui then
			local wasOpen = isMenuOpen
			createTeamMenu()
			if wasOpen then
				_G.ToggleTeamMenu()
			end
		end
	end)
end

-- =====================================
-- INICIALIZAÇÃO
-- =====================================

player.CharacterAdded:Connect(function()
	task.wait(1)
	createTeamMenu()
	monitorCharacterMenuSize()
end)

if player.Character then
	createTeamMenu()
	monitorCharacterMenuSize()
end

print([[
╔════════════════════════════════════════════════════╗
║  ✅ INTERFACE DE TIMES V5 CARREGADA               ║
╠════════════════════════════════════════════════════╣
║  SUBSTITUI: TeamMenuClient (V4)                   ║
║  REMOVER:   TeamMenuClient (V4)                   ║
╠════════════════════════════════════════════════════╣
║  NOVIDADES V5:                                     ║
║  • BOTÃO FLUTUANTE PRÓPRIO REMOVIDO ✓            ║
║  • Abre SÓ pelo menu unificado (☰) ✓            ║
║  • _G.OpenTeamMenu / _G.CloseTeamMenu ✓          ║
║  • UI 100% RESPONSIVA (Mobile/Tablet/PC) ✓        ║
╚════════════════════════════════════════════════════╝
]])
