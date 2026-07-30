-- ============================================
-- MISSIONS MENU CLIENT V2
-- (V2) ALTERAÇÕES: :Destroy() -> .Parent = nil; fontes retro (Arcade)
-- StarterPlayer > StarterPlayerScripts > MissionsMenuClient
-- ============================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

local remotes = ReplicatedStorage:WaitForChild("Remotes")

local function waitForRemoteFunction(name, timeout)
	local elapsed = 0
	while elapsed < timeout do
		local remote = remotes:FindFirstChild(name)
		if remote and remote:IsA("RemoteFunction") then
			return remote
		end
		task.wait(0.2)
		elapsed += 0.2
	end
	return nil
end

local getMissionStatus = waitForRemoteFunction("GetMissionStatus", 10)
local claimMissionReward = waitForRemoteFunction("ClaimMissionReward", 10)

local COLORS = {
	bg = Color3.fromRGB(15, 15, 20),
	panel = Color3.fromRGB(25, 28, 36),
	header = Color3.fromRGB(45, 60, 90),
	border = Color3.fromRGB(0, 200, 255),
	text = Color3.fromRGB(235, 235, 245),
	muted = Color3.fromRGB(160, 165, 180),
	green = Color3.fromRGB(0, 180, 95),
	gold = Color3.fromRGB(255, 205, 70),
	red = Color3.fromRGB(190, 45, 45),
	barBg = Color3.fromRGB(45, 45, 55),
}

local SFX = {
	open = "rbxassetid://157167203",
	close = "rbxassetid://157167205",
	click = "rbxassetid://156785206",
	reward = "rbxassetid://5031873608",
	error = "rbxassetid://2865228021",
}

local missionGui = nil
local mainFrame = nil
local scrollFrame = nil
local progressLabel = nil
local isOpen = false
local currentPayload = nil

local function playSound(id)
	pcall(function()
		local sound = Instance.new("Sound")
		sound.SoundId = id
		sound.Volume = 0.5
		sound.Parent = SoundService
		sound:Play()
		sound.Ended:Connect(function()
			sound.Parent = nil
		end)
	end)
end

local function notify(message, success)
	local toast = Instance.new("Frame")
	toast.Size = isMobile and UDim2.new(0.82, 0, 0.09, 0) or UDim2.new(0.36, 0, 0.07, 0)
	toast.Position = isMobile and UDim2.new(0.09, 0, 0.06, 0) or UDim2.new(0.32, 0, 0.05, 0)
	toast.BackgroundColor3 = COLORS.bg
	toast.BorderColor3 = success and COLORS.green or COLORS.red
	toast.BorderSizePixel = 3
	toast.ZIndex = 80
	toast.Parent = missionGui or playerGui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = toast

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(0.94, 0, 0.9, 0)
	label.Position = UDim2.new(0.03, 0, 0.05, 0)
	label.BackgroundTransparency = 1
	label.Text = message
	label.TextColor3 = COLORS.text
	label.TextScaled = true
	label.TextWrapped = true
	label.Font = Enum.Font.Arcade
	label.ZIndex = 81
	label.Parent = toast

	playSound(success and SFX.reward or SFX.error)
	task.delay(2.5, function()
		if toast and toast.Parent then
			toast.Parent = nil
		end
	end)
end

local function rewardText(rewards)
	rewards = rewards or {}
	local parts = {}
	if (rewards.coins or 0) > 0 then
		table.insert(parts, "+" .. rewards.coins .. " moedas")
	end
	if (rewards.bounty or 0) > 0 then
		table.insert(parts, "+" .. rewards.bounty .. " bounty")
	end
	if #parts == 0 then
		return "Sem recompensa"
	end
	return table.concat(parts, " | ")
end

local function setMissionNotification(payload)
	if not _G.SetMenuNotification or not payload or not payload.missions then
		return
	end
	local hasClaimable = false
	for _, mission in ipairs(payload.missions) do
		if mission.canClaim then
			hasClaimable = true
			break
		end
	end
	_G.SetMenuNotification("MISSÕES", hasClaimable)
end

local function clearCards()
	if not scrollFrame then
		return
	end
	for _, child in ipairs(scrollFrame:GetChildren()) do
		if child:IsA("Frame") or child:IsA("TextLabel") then
			child.Parent = nil
		end
	end
end

local function createMissionCard(mission)
	local card = Instance.new("Frame")
	card.Size = UDim2.new(1, -12, 0, isMobile and 150 or 130)
	card.BackgroundColor3 = mission.claimed and Color3.fromRGB(25, 45, 35) or COLORS.panel
	card.BorderColor3 = mission.canClaim and COLORS.gold
		or (mission.claimed and COLORS.green or Color3.fromRGB(80, 90, 110))
	card.BorderSizePixel = mission.canClaim and 3 or 2
	card.Parent = scrollFrame

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = card

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(0.62, 0, 0.2, 0)
	title.Position = UDim2.new(0.03, 0, 0.06, 0)
	title.BackgroundTransparency = 1
	title.Text = mission.title or "MISSÃO"
	title.TextColor3 = mission.canClaim and COLORS.gold or COLORS.text
	title.TextScaled = true
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Font = Enum.Font.Arcade
	title.Parent = card

	local status = Instance.new("TextLabel")
	status.Size = UDim2.new(0.28, 0, 0.18, 0)
	status.Position = UDim2.new(0.69, 0, 0.07, 0)
	status.BackgroundTransparency = 1
	status.Text = mission.claimed and "RESGATADA"
		or (mission.canClaim and "PRONTA" or "EM PROGRESSO")
	status.TextColor3 = mission.claimed and COLORS.green
		or (mission.canClaim and COLORS.gold or COLORS.muted)
	status.TextScaled = true
	status.Font = Enum.Font.Arcade
	status.Parent = card

	local desc = Instance.new("TextLabel")
	desc.Size = UDim2.new(0.94, 0, 0.18, 0)
	desc.Position = UDim2.new(0.03, 0, 0.28, 0)
	desc.BackgroundTransparency = 1
	desc.Text = mission.description or ""
	desc.TextColor3 = COLORS.muted
	desc.TextScaled = true
	desc.TextWrapped = true
	desc.TextXAlignment = Enum.TextXAlignment.Left
	desc.Font = Enum.Font.Arcade
	desc.Parent = card

	local barBg = Instance.new("Frame")
	barBg.Size = UDim2.new(0.64, 0, 0.12, 0)
	barBg.Position = UDim2.new(0.03, 0, 0.52, 0)
	barBg.BackgroundColor3 = COLORS.barBg
	barBg.BorderSizePixel = 0
	barBg.Parent = card

	local barBgCorner = Instance.new("UICorner")
	barBgCorner.CornerRadius = UDim.new(1, 0)
	barBgCorner.Parent = barBg

	local fill = Instance.new("Frame")
	fill.Size = UDim2.new(math.clamp(mission.progress or 0, 0, 1), 0, 1, 0)
	fill.BackgroundColor3 = mission.claimed and COLORS.green
		or (mission.canClaim and COLORS.gold or COLORS.border)
	fill.BorderSizePixel = 0
	fill.Parent = barBg

	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(1, 0)
	fillCorner.Parent = fill

	local progress = Instance.new("TextLabel")
	progress.Size = UDim2.new(0.28, 0, 0.14, 0)
	progress.Position = UDim2.new(0.69, 0, 0.51, 0)
	progress.BackgroundTransparency = 1
	progress.Text = tostring(math.floor(mission.current or 0))
		.. " / "
		.. tostring(mission.goal or 0)
	progress.TextColor3 = COLORS.text
	progress.TextScaled = true
	progress.Font = Enum.Font.Arcade
	progress.Parent = card

	local reward = Instance.new("TextLabel")
	reward.Size = UDim2.new(0.62, 0, 0.16, 0)
	reward.Position = UDim2.new(0.03, 0, 0.72, 0)
	reward.BackgroundTransparency = 1
	reward.Text = rewardText(mission.rewards)
	reward.TextColor3 = COLORS.gold
	reward.TextScaled = true
	reward.TextXAlignment = Enum.TextXAlignment.Left
	reward.Font = Enum.Font.Arcade
	reward.Parent = card

	local button = Instance.new("TextButton")
	button.Size = UDim2.new(0.28, 0, 0.22, 0)
	button.Position = UDim2.new(0.69, 0, 0.70, 0)
	button.BackgroundColor3 = mission.claimed and Color3.fromRGB(55, 80, 65)
		or (mission.canClaim and COLORS.green or Color3.fromRGB(70, 70, 80))
	button.BorderSizePixel = 0
	button.Text = mission.claimed and "OK" or (mission.canClaim and "RESGATAR" or "BLOQUEADA")
	button.TextColor3 = COLORS.text
	button.TextScaled = true
	button.Font = Enum.Font.Arcade
	button.AutoButtonColor = mission.canClaim
	button.Parent = card

	local buttonCorner = Instance.new("UICorner")
	buttonCorner.CornerRadius = UDim.new(0, 6)
	buttonCorner.Parent = button

	button.MouseButton1Click:Connect(function()
		if not mission.canClaim or not claimMissionReward then
			return
		end
		playSound(SFX.click)

		local ok, success, message, payload = pcall(function()
			return claimMissionReward:InvokeServer(mission.id)
		end)

		if not ok then
			notify("Erro ao resgatar missão.", false)
			return
		end

		notify(
			message or (success and "Recompensa resgatada!" or "Não foi possível resgatar."),
			success
		)
		if payload then
			currentPayload = payload
			task.defer(function()
				if _G.RefreshMissionsMenu then
					_G.RefreshMissionsMenu()
				end
			end)
		end
	end)
end

local function renderMissions(payload)
	clearCards()

	if not payload or not payload.missions then
		if progressLabel then
			progressLabel.Text = "Missões indisponíveis"
		end
		local msg = Instance.new("TextLabel")
		msg.Size = UDim2.new(1, -12, 0, 120)
		msg.BackgroundColor3 = COLORS.panel
		msg.BorderColor3 = COLORS.red
		msg.BorderSizePixel = 2
		msg.Text = "Sistema de missões não encontrado."
		msg.TextColor3 = COLORS.text
		msg.TextScaled = true
		msg.TextWrapped = true
		msg.Font = Enum.Font.Arcade
		msg.Parent = scrollFrame
		return
	end

	if progressLabel then
		progressLabel.Text = string.format(
			"%d/%d concluídas | %d resgatadas",
			payload.completed or 0,
			payload.total or 0,
			payload.claimed or 0
		)
	end

	for _, mission in ipairs(payload.missions) do
		createMissionCard(mission)
	end

	setMissionNotification(payload)
end

local function refreshMissions()
	if not getMissionStatus then
		renderMissions(nil)
		return
	end

	local ok, payload = pcall(function()
		return getMissionStatus:InvokeServer()
	end)

	if ok then
		currentPayload = payload
		renderMissions(payload)
	else
		renderMissions(nil)
	end
end

local function createInterface()
	if missionGui and missionGui.Parent then
		return
	end

	missionGui = Instance.new("ScreenGui")
	missionGui.Name = "MissionsMenu"
	missionGui.ResetOnSpawn = false
	missionGui.IgnoreGuiInset = true
	missionGui.DisplayOrder = 49
	missionGui.Parent = playerGui

	mainFrame = Instance.new("Frame")
	mainFrame.Name = "MainFrame"
	mainFrame.Size = isMobile and UDim2.new(0.92, 0, 0.82, 0) or UDim2.new(0.58, 0, 0.72, 0)
	mainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
	mainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	mainFrame.BackgroundColor3 = COLORS.bg
	mainFrame.BorderColor3 = COLORS.border
	mainFrame.BorderSizePixel = 4
	mainFrame.Visible = false
	mainFrame.Parent = missionGui

	local mainCorner = Instance.new("UICorner")
	mainCorner.CornerRadius = UDim.new(0, 8)
	mainCorner.Parent = mainFrame

	local header = Instance.new("Frame")
	header.Size = UDim2.new(1, 0, 0.13, 0)
	header.BackgroundColor3 = COLORS.header
	header.BorderSizePixel = 0
	header.Parent = mainFrame

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(0.62, 0, 0.55, 0)
	title.Position = UDim2.new(0.03, 0, 0.08, 0)
	title.BackgroundTransparency = 1
	title.Text = "MISSÕES"
	title.TextColor3 = COLORS.text
	title.TextScaled = true
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Font = Enum.Font.Arcade
	title.Parent = header

	progressLabel = Instance.new("TextLabel")
	progressLabel.Size = UDim2.new(0.62, 0, 0.32, 0)
	progressLabel.Position = UDim2.new(0.03, 0, 0.62, 0)
	progressLabel.BackgroundTransparency = 1
	progressLabel.Text = "Carregando..."
	progressLabel.TextColor3 = COLORS.gold
	progressLabel.TextScaled = true
	progressLabel.TextXAlignment = Enum.TextXAlignment.Left
	progressLabel.Font = Enum.Font.Arcade
	progressLabel.Parent = header

	local refreshBtn = Instance.new("TextButton")
	refreshBtn.Size = UDim2.new(0.10, 0, 0.58, 0)
	refreshBtn.Position = UDim2.new(0.73, 0, 0.21, 0)
	refreshBtn.BackgroundColor3 = Color3.fromRGB(0, 110, 160)
	refreshBtn.BorderSizePixel = 0
	refreshBtn.Text = "↻"
	refreshBtn.TextColor3 = COLORS.text
	refreshBtn.TextScaled = true
	refreshBtn.Font = Enum.Font.Arcade
	refreshBtn.Parent = header

	local refreshCorner = Instance.new("UICorner")
	refreshCorner.CornerRadius = UDim.new(0, 6)
	refreshCorner.Parent = refreshBtn

	local closeBtn = Instance.new("TextButton")
	closeBtn.Size = UDim2.new(0.10, 0, 0.58, 0)
	closeBtn.Position = UDim2.new(0.87, 0, 0.21, 0)
	closeBtn.BackgroundColor3 = COLORS.red
	closeBtn.BorderSizePixel = 0
	closeBtn.Text = "X"
	closeBtn.TextColor3 = COLORS.text
	closeBtn.TextScaled = true
	closeBtn.Font = Enum.Font.Arcade
	closeBtn.Parent = header

	local closeCorner = Instance.new("UICorner")
	closeCorner.CornerRadius = UDim.new(0, 6)
	closeCorner.Parent = closeBtn

	scrollFrame = Instance.new("ScrollingFrame")
	scrollFrame.Name = "MissionList"
	scrollFrame.Size = UDim2.new(0.94, 0, 0.82, 0)
	scrollFrame.Position = UDim2.new(0.03, 0, 0.16, 0)
	scrollFrame.BackgroundTransparency = 1
	scrollFrame.BorderSizePixel = 0
	scrollFrame.ScrollBarThickness = isMobile and 8 or 10
	scrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
	scrollFrame.Parent = mainFrame

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 10)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = scrollFrame

	layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		scrollFrame.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 16)
	end)

	refreshBtn.MouseButton1Click:Connect(function()
		playSound(SFX.click)
		refreshMissions()
	end)

	closeBtn.MouseButton1Click:Connect(function()
		playSound(SFX.close)
		isOpen = false
		mainFrame.Visible = false
	end)
end

_G.RefreshMissionsMenu = function()
	if not missionGui or not missionGui.Parent then
		createInterface()
	end
	refreshMissions()
end

_G.OpenMissionsMenu = function()
	if not missionGui or not missionGui.Parent then
		createInterface()
	end
	isOpen = true
	mainFrame.Visible = true
	playSound(SFX.open)
	refreshMissions()
end

_G.CloseMissionsMenu = function()
	isOpen = false
	if mainFrame then
		mainFrame.Visible = false
	end
end

createInterface()

-- Atualização AO VIVO vinda do servidor (Remotes.MissionUpdate)
task.spawn(function()
	local updateEvent
	local elapsed = 0
	while elapsed < 12 do
		local r = remotes:FindFirstChild("MissionUpdate")
		if r and r:IsA("RemoteEvent") then
			updateEvent = r
			break
		end
		task.wait(0.3)
		elapsed += 0.3
	end
	if updateEvent then
		updateEvent.OnClientEvent:Connect(function(payload)
			currentPayload = payload
			setMissionNotification(payload)
			if isOpen and missionGui and missionGui.Parent then
				renderMissions(payload)
			end
		end)
	end
end)

-- Registrar no Menu Unificado
task.spawn(function()
	local timeout = 0
	while not _G.RegisterMenuCategory and timeout < 15 do
		task.wait(0.5)
		timeout += 0.5
	end

	if _G.RegisterMenuCategory then
		_G.RegisterMenuCategory("MISSÕES", "📋", function()
			if _G.OpenMissionsMenu then
				_G.OpenMissionsMenu()
			end
		end, function()
			if _G.CloseMissionsMenu then
				_G.CloseMissionsMenu()
			end
		end, 5)
		print("[MISSIONS V1] Registrado no Menu Unificado")
	end

	task.wait(1)
	refreshMissions()
end)

player.CharacterAdded:Connect(function()
	task.wait(1)
	if not missionGui or not missionGui.Parent then
		createInterface()
	end
end)

print("[MISSIONS V1] Menu de missoes carregado")
