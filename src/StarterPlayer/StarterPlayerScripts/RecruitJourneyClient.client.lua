-- ============================================
-- RECRUIT JOURNEY CLIENT V1
-- StarterPlayer > StarterPlayerScripts > RecruitJourneyClient
-- Menu da Jornada do Recruta no hub unificado
-- ============================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
local remotes = ReplicatedStorage:WaitForChild("Remotes")

local function waitForRemote(name, className, timeout)
	local elapsed = 0
	while elapsed < timeout do
		local remote = remotes:FindFirstChild(name)
		if remote and remote:IsA(className) then
			return remote
		end
		task.wait(0.2)
		elapsed += 0.2
	end
	return nil
end

local getRecruitJourney = waitForRemote("GetRecruitJourney", "RemoteFunction", 10)
local claimRecruitJourney = waitForRemote("ClaimRecruitJourney", "RemoteFunction", 10)
local recruitJourneyUpdate = waitForRemote("RecruitJourneyUpdate", "RemoteEvent", 10)

if not getRecruitJourney or not claimRecruitJourney then
	warn("[RECRUIT JOURNEY V1] Remotes não encontrados")
	return
end

local C = {
	bg = Color3.fromRGB(12, 12, 18),
	panel = Color3.fromRGB(24, 28, 38),
	header = Color3.fromRGB(70, 40, 120),
	border = Color3.fromRGB(0, 220, 255),
	gold = Color3.fromRGB(255, 210, 70),
	green = Color3.fromRGB(0, 200, 100),
	red = Color3.fromRGB(210, 45, 45),
	text = Color3.fromRGB(245, 245, 255),
	muted = Color3.fromRGB(170, 175, 195),
	barBg = Color3.fromRGB(48, 48, 62),
}

local SFX = {
	open = "rbxassetid://157167203",
	close = "rbxassetid://157167205",
	click = "rbxassetid://156785206",
	reward = "rbxassetid://5031873608",
	error = "rbxassetid://2865228021",
}

local gui = nil
local frame = nil
local list = nil
local summary = nil
local currentPayload = nil
local isOpen = false

local function playSound(id)
	pcall(function()
		local sound = Instance.new("Sound")
		sound.SoundId = id
		sound.Volume = 0.45
		sound.Parent = SoundService
		sound:Play()
		sound.Ended:Connect(function()
			sound.Parent = nil
		end)
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
	if rewards.title then
		table.insert(parts, "título " .. rewards.title)
	end
	return #parts > 0 and table.concat(parts, " | ") or "Recompensa surpresa"
end

local function notify(message, success)
	local toast = Instance.new("Frame")
	toast.Size = isMobile and UDim2.new(0.84, 0, 0.09, 0) or UDim2.new(0.38, 0, 0.07, 0)
	toast.Position = isMobile and UDim2.new(0.08, 0, 0.06, 0) or UDim2.new(0.31, 0, 0.05, 0)
	toast.BackgroundColor3 = C.bg
	toast.BorderColor3 = success and C.green or C.red
	toast.BorderSizePixel = 3
	toast.ZIndex = 90
	toast.Parent = gui or playerGui

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(0.94, 0, 0.9, 0)
	label.Position = UDim2.new(0.03, 0, 0.05, 0)
	label.BackgroundTransparency = 1
	label.Text = message
	label.TextColor3 = C.text
	label.TextScaled = true
	label.TextWrapped = true
	label.Font = Enum.Font.Arcade
	label.ZIndex = 91
	label.Parent = toast

	playSound(success and SFX.reward or SFX.error)
	task.delay(2.5, function()
		if toast and toast.Parent then
			toast.Parent = nil
		end
	end)
end

local function setNotification(payload)
	if not _G.SetMenuNotification or not payload or not payload.chapters then
		return
	end
	local hasClaimable = false
	for _, chapter in ipairs(payload.chapters) do
		if chapter.canClaim then
			hasClaimable = true
			break
		end
	end
	_G.SetMenuNotification("RECRUTA", hasClaimable)
end

local function clearList()
	if not list then
		return
	end
	for _, child in ipairs(list:GetChildren()) do
		if child:IsA("Frame") then
			child.Parent = nil
		end
	end
end

local function createChapterCard(chapter)
	local card = Instance.new("Frame")
	card.Size = UDim2.new(1, -12, 0, isMobile and 154 or 132)
	card.BackgroundColor3 = chapter.claimed and Color3.fromRGB(24, 48, 36) or C.panel
	card.BorderColor3 = chapter.canClaim and C.gold or (chapter.claimed and C.green or Color3.fromRGB(85, 95, 120))
	card.BorderSizePixel = chapter.canClaim and 3 or 2
	card.Parent = list

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(0.62, 0, 0.2, 0)
	title.Position = UDim2.new(0.03, 0, 0.06, 0)
	title.BackgroundTransparency = 1
	title.Text = string.format("%d. %s", chapter.index or 1, chapter.title or "CAPÍTULO")
	title.TextColor3 = chapter.canClaim and C.gold or C.text
	title.TextScaled = true
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Font = Enum.Font.Arcade
	title.Parent = card

	local status = Instance.new("TextLabel")
	status.Size = UDim2.new(0.28, 0, 0.18, 0)
	status.Position = UDim2.new(0.69, 0, 0.07, 0)
	status.BackgroundTransparency = 1
	status.Text = chapter.claimed and "RESGATADO" or (chapter.canClaim and "PRONTO" or "EM ANDAMENTO")
	status.TextColor3 = chapter.claimed and C.green or (chapter.canClaim and C.gold or C.muted)
	status.TextScaled = true
	status.Font = Enum.Font.Arcade
	status.Parent = card

	local desc = Instance.new("TextLabel")
	desc.Size = UDim2.new(0.94, 0, 0.18, 0)
	desc.Position = UDim2.new(0.03, 0, 0.28, 0)
	desc.BackgroundTransparency = 1
	desc.Text = chapter.description or ""
	desc.TextColor3 = C.muted
	desc.TextScaled = true
	desc.TextWrapped = true
	desc.TextXAlignment = Enum.TextXAlignment.Left
	desc.Font = Enum.Font.Arcade
	desc.Parent = card

	local barBg = Instance.new("Frame")
	barBg.Size = UDim2.new(0.64, 0, 0.12, 0)
	barBg.Position = UDim2.new(0.03, 0, 0.52, 0)
	barBg.BackgroundColor3 = C.barBg
	barBg.BorderSizePixel = 0
	barBg.Parent = card

	local fill = Instance.new("Frame")
	fill.Size = UDim2.new(math.clamp(chapter.progress or 0, 0, 1), 0, 1, 0)
	fill.BackgroundColor3 = chapter.claimed and C.green or (chapter.canClaim and C.gold or C.border)
	fill.BorderSizePixel = 0
	fill.Parent = barBg

	local progress = Instance.new("TextLabel")
	progress.Size = UDim2.new(0.26, 0, 0.13, 0)
	progress.Position = UDim2.new(0.70, 0, 0.51, 0)
	progress.BackgroundTransparency = 1
	progress.Text = string.format("%d/%d", chapter.current or 0, chapter.goal or 1)
	progress.TextColor3 = C.text
	progress.TextScaled = true
	progress.Font = Enum.Font.Arcade
	progress.Parent = card

	local reward = Instance.new("TextLabel")
	reward.Size = UDim2.new(0.60, 0, 0.18, 0)
	reward.Position = UDim2.new(0.03, 0, 0.73, 0)
	reward.BackgroundTransparency = 1
	reward.Text = "🎁 " .. rewardText(chapter.rewards)
	reward.TextColor3 = C.gold
	reward.TextScaled = true
	reward.TextWrapped = true
	reward.TextXAlignment = Enum.TextXAlignment.Left
	reward.Font = Enum.Font.Arcade
	reward.Parent = card

	local button = Instance.new("TextButton")
	button.Size = UDim2.new(0.27, 0, 0.2, 0)
	button.Position = UDim2.new(0.70, 0, 0.72, 0)
	button.BackgroundColor3 = chapter.claimed and C.green or (chapter.canClaim and C.gold or Color3.fromRGB(70, 70, 82))
	button.BorderColor3 = C.text
	button.BorderSizePixel = 2
	button.Text = chapter.claimed and "OK" or (chapter.canClaim and "RESGATAR" or "BLOQUEADO")
	button.TextColor3 = C.bg
	button.TextScaled = true
	button.Font = Enum.Font.Arcade
	button.AutoButtonColor = chapter.canClaim
	button.Parent = card

	button.MouseButton1Click:Connect(function()
		if not chapter.canClaim then
			playSound(SFX.click)
			return
		end
		local ok, success, message, payload = pcall(function()
			return claimRecruitJourney:InvokeServer(chapter.id)
		end)
		if ok then
			notify(message or "Jornada atualizada.", success)
			if payload then
				currentPayload = payload
				setNotification(payload)
				clearList()
				for _, item in ipairs(payload.chapters or {}) do
					createChapterCard(item)
				end
			end
		else
			notify("Erro ao resgatar recompensa.", false)
		end
	end)
end

local function render(payload)
	if not payload or not list then
		return
	end
	clearList()
	summary.Text = string.format("%d/%d capítulos concluídos • %d recompensas resgatadas", payload.completed or 0, payload.total or 0, payload.claimed or 0)
	for _, chapter in ipairs(payload.chapters or {}) do
		createChapterCard(chapter)
	end
	list.CanvasSize = UDim2.new(0, 0, 0, #payload.chapters * (isMobile and 164 or 142))
end

local function createGui()
	if gui and gui.Parent then
		return
	end

	gui = Instance.new("ScreenGui")
	gui.Name = "RecruitJourneyGui"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 70
	gui.Enabled = false
	gui.Parent = playerGui

	frame = Instance.new("Frame")
	frame.Size = isMobile and UDim2.new(0.94, 0, 0.82, 0) or UDim2.new(0.58, 0, 0.72, 0)
	frame.Position = isMobile and UDim2.new(0.03, 0, 0.09, 0) or UDim2.new(0.21, 0, 0.14, 0)
	frame.BackgroundColor3 = C.bg
	frame.BorderColor3 = C.border
	frame.BorderSizePixel = 4
	frame.Parent = gui

	local header = Instance.new("TextLabel")
	header.Size = UDim2.new(1, 0, 0.12, 0)
	header.BackgroundColor3 = C.header
	header.BorderSizePixel = 0
	header.Text = "🎮 JORNADA DO RECRUTA"
	header.TextColor3 = C.text
	header.TextScaled = true
	header.Font = Enum.Font.Arcade
	header.Parent = frame

	local close = Instance.new("TextButton")
	close.Size = UDim2.new(0.08, 0, 0.08, 0)
	close.Position = UDim2.new(0.90, 0, 0.02, 0)
	close.BackgroundColor3 = C.red
	close.BorderColor3 = C.text
	close.Text = "X"
	close.TextColor3 = C.text
	close.TextScaled = true
	close.Font = Enum.Font.Arcade
	close.Parent = frame
	close.MouseButton1Click:Connect(function()
		_G.CloseRecruitJourney()
	end)

	summary = Instance.new("TextLabel")
	summary.Size = UDim2.new(0.92, 0, 0.08, 0)
	summary.Position = UDim2.new(0.04, 0, 0.14, 0)
	summary.BackgroundTransparency = 1
	summary.TextColor3 = C.gold
	summary.TextScaled = true
	summary.TextWrapped = true
	summary.Font = Enum.Font.Arcade
	summary.Parent = frame

	list = Instance.new("ScrollingFrame")
	list.Size = UDim2.new(0.94, 0, 0.72, 0)
	list.Position = UDim2.new(0.03, 0, 0.24, 0)
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 8
	list.Parent = frame

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 10)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list
end

local function refresh()
	local ok, payload = pcall(function()
		return getRecruitJourney:InvokeServer()
	end)
	if ok and payload then
		currentPayload = payload
		setNotification(payload)
		if isOpen then
			render(payload)
		end
	end
end

_G.OpenRecruitJourney = function()
	createGui()
	gui.Enabled = true
	isOpen = true
	playSound(SFX.open)
	refresh()
	render(currentPayload)
end

_G.CloseRecruitJourney = function()
	if gui then
		gui.Enabled = false
	end
	isOpen = false
	playSound(SFX.close)
end

if recruitJourneyUpdate then
	recruitJourneyUpdate.OnClientEvent:Connect(function(payload)
		currentPayload = payload
		setNotification(payload)
		if isOpen then
			render(payload)
		end
	end)
end

task.spawn(function()
	local timeout = 0
	while not _G.RegisterMenuCategory and timeout < 15 do
		task.wait(0.5)
		timeout += 0.5
	end
	if _G.RegisterMenuCategory then
		_G.RegisterMenuCategory("RECRUTA", "🎮", function()
			_G.OpenRecruitJourney()
		end, function()
			_G.CloseRecruitJourney()
		end, 2)
		print("[RECRUIT JOURNEY V1] Registrado no Menu Unificado")
	end
	task.wait(1)
	refresh()
end)

player.CharacterAdded:Connect(function()
	task.wait(1)
	createGui()
	refresh()
end)

print("[RECRUIT JOURNEY V1] Menu Jornada do Recruta carregado")
