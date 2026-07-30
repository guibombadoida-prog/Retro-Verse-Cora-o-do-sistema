-- ============================================
-- WANTED CLIENT V2 — HUD + BÚSSOLA (RETRO)
-- Coloque em StarterPlayer > StarterPlayerScripts
-- Nome: "WantedClient"
-- SUBSTITUI: WantedClient V1
-- ============================================
-- (V2) EVOLUÇÕES sobre o V1:
-- • BÚSSOLA/SETA que aponta a direção do ALVO + distância, em
--   tempo real (RenderStepped). É 100% no cliente: ele já recebe
--   o NOME do alvo e acha o personagem replicado; a direção sai
--   de camera.CFrame:PointToObjectSpace (não precisa do servidor).
-- • Banner mostra as ESTRELAS do nível de procurado (1–5).
-- • Se VOCÊ é o alvo: a seta some e o aviso vira "FUJA!".
--
-- REUTILIZADO (igual V1): HUD retro do HealthDisplay_V3, paleta
-- e banner temporário do TradeMenuClient_V1, fontes Arcade/Code.
-- Continua sendo só HUD (sem menu/hub).
-- ============================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local camera = workspace.CurrentCamera

-- =====================================
-- REMOTES
-- =====================================

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local wantedUpdateRemote = remotes:WaitForChild("WantedUpdate", 15)
local wantedKillRemote = remotes:WaitForChild("WantedKill", 15)

if not wantedUpdateRemote then
	warn("[WANTED CLIENT V2] Remotes ausentes — WantedSystemServer está no ServerScriptService?")
	return
end

-- =====================================
-- CORES (REUTILIZADAS do HealthDisplay_V3 / TradeMenuClient_V1)
-- =====================================

local COLORS = {
	background = Color3.fromRGB(20, 12, 12),
	wanted = Color3.fromRGB(255, 40, 40),
	you = Color3.fromRGB(255, 200, 0),
	coin = Color3.fromRGB(255, 215, 0),
	star = Color3.fromRGB(255, 215, 0),
	text = Color3.fromRGB(245, 235, 235),
}

-- =====================================
-- HUD FIXO (banner do topo)
-- =====================================

local gui = Instance.new("ScreenGui")
gui.Name = "WantedHUD"
gui.ResetOnSpawn = false
gui.DisplayOrder = 47
gui.IgnoreGuiInset = true
gui.Parent = playerGui

local banner = Instance.new("Frame")
banner.Name = "Banner"
banner.AnchorPoint = Vector2.new(0.5, 0)
banner.Position = UDim2.fromScale(0.5, 0.02)
banner.Size = UDim2.fromScale(0.44, 0.07)
banner.BackgroundColor3 = COLORS.background
banner.BorderColor3 = COLORS.wanted
banner.BorderSizePixel = 3
banner.Visible = false
banner.Parent = gui

local title = Instance.new("TextLabel")
title.Name = "Title"
title.Size = UDim2.fromScale(1, 0.4)
title.BackgroundTransparency = 1
title.Text = "🎯 PROCURADO"
title.TextColor3 = COLORS.wanted
title.TextScaled = true
title.Font = Enum.Font.Arcade
title.Parent = banner

local starsLabel = Instance.new("TextLabel")
starsLabel.Name = "Stars"
starsLabel.Position = UDim2.fromScale(0, 0.4)
starsLabel.Size = UDim2.fromScale(1, 0.28)
starsLabel.BackgroundTransparency = 1
starsLabel.Text = ""
starsLabel.TextColor3 = COLORS.star
starsLabel.TextScaled = true
starsLabel.Font = Enum.Font.Code
starsLabel.Parent = banner

local sub = Instance.new("TextLabel")
sub.Name = "Sub"
sub.Position = UDim2.fromScale(0, 0.68)
sub.Size = UDim2.fromScale(1, 0.32)
sub.BackgroundTransparency = 1
sub.Text = ""
sub.TextColor3 = COLORS.coin
sub.TextScaled = true
sub.Font = Enum.Font.Code
sub.Parent = banner

-- =====================================
-- BÚSSOLA / SETA (aponta o alvo)
-- =====================================

local compass = Instance.new("Frame")
compass.Name = "Compass"
compass.AnchorPoint = Vector2.new(0.5, 0)
compass.Position = UDim2.fromScale(0.5, 0.11)
compass.Size = UDim2.fromScale(0.1, 0.1)
compass.BackgroundTransparency = 1
compass.Visible = false
compass.Parent = gui

local arrow = Instance.new("TextLabel")
arrow.Name = "Arrow"
arrow.AnchorPoint = Vector2.new(0.5, 0.5)
arrow.Position = UDim2.fromScale(0.5, 0.42)
arrow.Size = UDim2.fromScale(1, 0.7)
arrow.BackgroundTransparency = 1
arrow.Text = "▲"
arrow.TextColor3 = COLORS.wanted
arrow.TextScaled = true
arrow.Font = Enum.Font.Arcade
arrow.Parent = compass

local distLabel = Instance.new("TextLabel")
distLabel.Name = "Dist"
distLabel.AnchorPoint = Vector2.new(0.5, 1)
distLabel.Position = UDim2.fromScale(0.5, 1)
distLabel.Size = UDim2.fromScale(1.6, 0.28)
distLabel.BackgroundTransparency = 1
distLabel.Text = ""
distLabel.TextColor3 = COLORS.coin
distLabel.TextScaled = true
distLabel.Font = Enum.Font.Code
distLabel.Parent = compass

-- =====================================
-- ESTADO + PULSAÇÃO
-- =====================================

local currentTargetName = nil
local amTarget = false

task.spawn(function()
	while banner and banner.Parent do
		if banner.Visible then
			TweenService:Create(banner, TweenInfo.new(0.7), { BorderColor3 = Color3.fromRGB(120, 0, 0) }):Play()
			task.wait(0.7)
			TweenService:Create(banner, TweenInfo.new(0.7), { BorderColor3 = amTarget and COLORS.you or COLORS.wanted }):Play()
			task.wait(0.7)
		else
			task.wait(0.5)
		end
	end
end)

-- Bússola em tempo real (client-side: acha o alvo pelo nome)
RunService.RenderStepped:Connect(function()
	if not currentTargetName or amTarget then
		compass.Visible = false
		return
	end

	local tp = Players:FindFirstChild(currentTargetName)
	local tChar = tp and tp.Character
	local tHrp = tChar and tChar:FindFirstChild("HumanoidRootPart")
	local myChar = player.Character
	local myHrp = myChar and myChar:FindFirstChild("HumanoidRootPart")

	if not tHrp or not myHrp then
		compass.Visible = false
		return
	end

	compass.Visible = true

	-- Direção relativa à câmera (▲ = alvo à frente)
	local relative = camera.CFrame:PointToObjectSpace(tHrp.Position)
	arrow.Rotation = math.deg(math.atan2(relative.X, -relative.Z))

	local dist = (tHrp.Position - myHrp.Position).Magnitude
	distLabel.Text = math.floor(dist) .. "m"
end)

-- =====================================
-- ATUALIZAR O ALVO
-- =====================================

wantedUpdateRemote.OnClientEvent:Connect(function(state)
	if not state then
		currentTargetName = nil
		amTarget = false
		banner.Visible = false
		compass.Visible = false
		return
	end

	currentTargetName = state.name
	amTarget = (state.name == player.Name)
	banner.Visible = true

	local stars = tonumber(state.stars) or 0
	starsLabel.Text = stars > 0 and string.rep("⭐", stars) or ""

	if amTarget then
		title.Text = "⚠️ VOCÊ É O ALVO — FUJA!"
		title.TextColor3 = COLORS.you
		banner.BorderColor3 = COLORS.you
		starsLabel.TextColor3 = COLORS.you
		sub.Text = "Recompensa pela sua cabeça: " .. tostring(state.reward) .. " 💰"
		sub.TextColor3 = COLORS.you
		compass.Visible = false
	else
		title.Text = "🎯 PROCURADO: " .. tostring(state.name)
		title.TextColor3 = COLORS.wanted
		banner.BorderColor3 = COLORS.wanted
		starsLabel.TextColor3 = COLORS.star
		sub.Text = "Bounty " .. tostring(state.bounty) .. "  •  Recompensa " .. tostring(state.reward) .. " 💰"
		sub.TextColor3 = COLORS.coin
	end
end)

-- =====================================
-- ANÚNCIO DE CAÇADA (banner central temporário)
-- =====================================

wantedKillRemote.OnClientEvent:Connect(function(info)
	if not info then
		return
	end

	local announce = Instance.new("ScreenGui")
	announce.Name = "WantedKillAnnounce"
	announce.ResetOnSpawn = false
	announce.DisplayOrder = 125
	announce.IgnoreGuiInset = true
	announce.Parent = playerGui

	local frame = Instance.new("Frame")
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(0.5, 0.28)
	frame.Size = UDim2.fromScale(0.55, 0.09)
	frame.BackgroundColor3 = COLORS.background
	frame.BorderColor3 = COLORS.wanted
	frame.BorderSizePixel = 3
	frame.Parent = announce

	local stars = tonumber(info.stars) or 0
	local starTxt = stars > 0 and (" " .. string.rep("⭐", stars)) or ""

	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.fromScale(1, 0.6)
	lbl.BackgroundTransparency = 1
	lbl.Text = "🎯 " .. tostring(info.hunter) .. " CAÇOU " .. tostring(info.target) .. "!" .. starTxt
	lbl.TextColor3 = COLORS.wanted
	lbl.TextScaled = true
	lbl.Font = Enum.Font.Arcade
	lbl.Parent = frame

	local rew = Instance.new("TextLabel")
	rew.Position = UDim2.fromScale(0, 0.6)
	rew.Size = UDim2.fromScale(1, 0.4)
	rew.BackgroundTransparency = 1
	rew.Text = "+" .. tostring(info.reward) .. " 💰 de recompensa"
	rew.TextColor3 = COLORS.coin
	rew.TextScaled = true
	rew.Font = Enum.Font.Code
	rew.Parent = frame

	task.delay(4, function()
		if announce and announce.Parent then
			announce.Parent = nil
		end
	end)
end)

print("[WANTED CLIENT V2] 🎯 HUD + bússola carregados")
