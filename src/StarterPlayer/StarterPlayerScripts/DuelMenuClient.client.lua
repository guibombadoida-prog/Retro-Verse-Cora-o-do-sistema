-- ============================================
-- DUEL MENU CLIENT V3 — ARENA AO VIVO + ESPECTADORES
-- Coloque em StarterPlayer > StarterPlayerScripts
-- Nome: "DuelMenuClient"
-- SUBSTITUI: DuelMenuClient V2
-- ============================================
-- (V3) Card de arena ao vivo, entrada/saída da arquibancada em desktop,
-- controle e mobile, e overlay animado com fase e lotação.
--
-- (V2) EVOLUÇÕES sobre o V1:
-- • Campo de APOSTA na lista (caixa + atalhos 0/50/100); o
--   DESAFIAR envia o valor apostado.
-- • Popup de desafio mostra a aposta.
-- • Tela de resultado mostra o pote ganho / aposta perdida.
--
-- REUTILIZADO (igual V1): paleta COLORS, sons + playSound,
-- showNotification, makeButton/makeLabel, popup de convite com
-- timer, contagem 3-2-1-LUTE, _G.RegisterMenuCategory do
-- UnifiedMenuClient_V3 (categoria "DUELO" ⚔️), fontes retro.
-- ============================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

-- =====================================
-- REMOTES
-- =====================================

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local requestDuelRemote = remotes:WaitForChild("RequestDuel", 15)
local duelInviteRemote = remotes:WaitForChild("DuelInvite", 15)
local respondToDuelRemote = remotes:WaitForChild("RespondToDuel", 15)
local duelCountdownRemote = remotes:WaitForChild("DuelCountdown", 15)
local duelResultRemote = remotes:WaitForChild("DuelResult", 15)
local spectateRemote = remotes:WaitForChild("DuelSpectate", 15)
local getArenaStatusRemote = remotes:WaitForChild("GetDuelArenaStatus", 15)
local spectatorStateRemote = remotes:WaitForChild("DuelSpectatorState", 15)

if not requestDuelRemote then
	warn("[DUEL CLIENT V3] Remotes de duelo ausentes — DuelSystemServer está no ServerScriptService?")
	return
end

-- =====================================
-- SONS / CORES (REUTILIZADOS do TradeMenuClient_V1)
-- =====================================

local sounds = {
	click = "rbxassetid://156785206",
	purchase = "rbxassetid://5031873608",
	error = "rbxassetid://2865228021",
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

local COLORS = {
	background = Color3.fromRGB(20, 20, 20),
	panel = Color3.fromRGB(30, 30, 30),
	header = Color3.fromRGB(40, 40, 40),
	border = Color3.fromRGB(255, 255, 255),
	success = Color3.fromRGB(0, 200, 0),
	error = Color3.fromRGB(200, 0, 0),
	warning = Color3.fromRGB(255, 200, 0),
	disabled = Color3.fromRGB(100, 100, 100),
	duel = Color3.fromRGB(255, 80, 0),
	coin = Color3.fromRGB(255, 200, 0),
}

local function showNotification(message, isSuccess)
	playSound(isSuccess and sounds.purchase or sounds.error)
	local notification = Instance.new("ScreenGui")
	notification.Name = "DuelNotification"
	notification.ResetOnSpawn = false
	notification.DisplayOrder = 120
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
	text.TextWrapped = true
	text.Font = Enum.Font.Arcade
	text.Parent = frame

	task.spawn(function()
		task.wait(3)
		notification.Parent = nil
	end)
end

local function makeButton(parent, text, color, size, pos)
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
	btn.Activated:Connect(function()
		playSound(sounds.click)
	end)
	return btn
end

local function makeLabel(parent, text, size, pos, color, font)
	local lbl = Instance.new("TextLabel")
	lbl.Size = size
	lbl.Position = pos
	lbl.BackgroundTransparency = 1
	lbl.Text = text
	lbl.TextColor3 = color or Color3.new(1, 1, 1)
	lbl.TextScaled = true
	lbl.TextWrapped = true
	lbl.Font = font or Enum.Font.Code
	lbl.Parent = parent
	return lbl
end

-- =====================================
-- OVERLAY DA ARQUIBANCADA (V3)
-- =====================================

local spectatorGui = nil
local spectatorInfo = nil
local isSpectating = false
local spectatorStrokeTween = nil
local spectatorViewportConn = nil

local function spectatorText(status)
	if type(status) ~= "table" then
		return "ARENA AO VIVO"
	end
	return string.format(
		"%s  VS  %s   •   %s   •   TORCIDA %d/%d",
		status.playerA ~= "" and status.playerA or "?",
		status.playerB ~= "" and status.playerB or "?",
		status.phase or "AO VIVO",
		tonumber(status.spectators) or 0,
		tonumber(status.capacity) or 0
	)
end

local function closeSpectatorOverlay()
	isSpectating = false
	if spectatorStrokeTween then
		spectatorStrokeTween:Cancel()
		spectatorStrokeTween = nil
	end
	if spectatorViewportConn then
		spectatorViewportConn:Disconnect()
		spectatorViewportConn = nil
	end
	if spectatorGui then
		spectatorGui.Parent = nil
		spectatorGui = nil
		spectatorInfo = nil
	end
end

local function showSpectatorOverlay(status)
	closeSpectatorOverlay()
	isSpectating = true

	local gui = Instance.new("ScreenGui")
	gui.Name = "DuelSpectatorGui"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 125
	gui.Parent = playerGui
	spectatorGui = gui

	local frame = Instance.new("Frame")
	frame.AnchorPoint = Vector2.new(0.5, 0)
	frame.Position = isMobile and UDim2.fromScale(0.5, 0.025) or UDim2.fromScale(0.5, 0.035)
	frame.Size = isMobile and UDim2.fromScale(0.92, 0.14) or UDim2.fromScale(0.58, 0.105)
	frame.BackgroundColor3 = COLORS.background
	frame.BackgroundTransparency = 0.08
	frame.BorderSizePixel = 0
	frame.Parent = gui

	local frameRatio = Instance.new("UIAspectRatioConstraint")
	frameRatio.Parent = frame
	local camera = workspace.CurrentCamera
	local function updateOverlayAspect()
		local viewport = camera and camera.ViewportSize or Vector2.new(1280, 720)
		local portrait = viewport.Y > viewport.X
		frameRatio.AspectRatio = portrait and 4.2 or 7.5
		frameRatio.DominantAxis = portrait and Enum.DominantAxis.Width or Enum.DominantAxis.Height
	end
	updateOverlayAspect()
	if camera then
		spectatorViewportConn = camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateOverlayAspect)
	end

	local stroke = Instance.new("UIStroke")
	stroke.Color = COLORS.duel
	stroke.Thickness = 3
	stroke.Parent = frame
	spectatorStrokeTween = TweenService:Create(
		stroke,
		TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ Transparency = 0.55, Color = COLORS.warning }
	)
	spectatorStrokeTween:Play()

	makeLabel(
		frame,
		"👁 ARQUIBANCADA AO VIVO",
		UDim2.new(0.96, 0, 0.34, 0),
		UDim2.new(0.02, 0, 0.04, 0),
		COLORS.duel,
		Enum.Font.Arcade
	)
	spectatorInfo = makeLabel(
		frame,
		spectatorText(status),
		UDim2.new(0.68, 0, 0.48, 0),
		UDim2.new(0.02, 0, 0.43, 0),
		Color3.new(1, 1, 1),
		Enum.Font.Code
	)

	local exitBtn = makeButton(
		frame,
		"SAIR",
		COLORS.error,
		UDim2.new(0.25, 0, 0.42, 0),
		UDim2.new(0.73, 0, 0.47, 0)
	)
	local exitRatio = Instance.new("UIAspectRatioConstraint")
	exitRatio.AspectRatio = 3
	exitRatio.DominantAxis = Enum.DominantAxis.Height
	exitRatio.Parent = exitBtn
	exitBtn.Activated:Connect(function()
		exitBtn.Active = false
		exitBtn.Text = "VOLTANDO..."
		local ok, success, message = pcall(function()
			return spectateRemote:InvokeServer(false)
		end)
		if not ok or success ~= true then
			exitBtn.Active = true
			exitBtn.Text = "SAIR"
			showNotification(message or "Não foi possível sair da arquibancada.", false)
		end
	end)

	-- Backup do RemoteEvent: atualiza fase/lotação enquanto o overlay existe.
	task.spawn(function()
		while spectatorGui == gui and gui.Parent and isSpectating do
			local ok, current = pcall(function()
				return getArenaStatusRemote:InvokeServer()
			end)
			if ok and type(current) == "table" and current.busy and spectatorInfo then
				spectatorInfo.Text = spectatorText(current)
			end
			task.wait(1.5)
		end
	end)
end

if spectatorStateRemote then
	spectatorStateRemote.OnClientEvent:Connect(function(active, payload)
		if active == true then
			if isSpectating and spectatorInfo then
				spectatorInfo.Text = spectatorText(payload)
			else
				showSpectatorOverlay(payload)
			end
		else
			closeSpectatorOverlay()
			if type(payload) == "string" and payload ~= "" then
				showNotification(payload, true)
			end
		end
	end)
end

-- =====================================
-- TELA 1: LISTA DE JOGADORES + APOSTA (DuelPlayerList)
-- =====================================

local currentBet = 0

local function openDuelPlayerList()
	local old = playerGui:FindFirstChild("DuelPlayerList")
	if old then
		old.Parent = nil
	end

	playSound(sounds.open)

	local gui = Instance.new("ScreenGui")
	gui.Name = "DuelPlayerList"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 60
	gui.Parent = playerGui

	local mainFrame = Instance.new("Frame")
	mainFrame.Size = isMobile and UDim2.new(0.88, 0, 0.78, 0) or UDim2.new(0.42, 0, 0.66, 0)
	mainFrame.Position = isMobile and UDim2.new(0.06, 0, 0.11, 0) or UDim2.new(0.29, 0, 0.17, 0)
	mainFrame.BackgroundColor3 = COLORS.background
	mainFrame.BorderColor3 = COLORS.border
	mainFrame.BorderSizePixel = 3
	mainFrame.Parent = gui

	local header = Instance.new("Frame")
	header.Size = UDim2.new(1, 0, 0.1, 0)
	header.BackgroundColor3 = COLORS.header
	header.BorderSizePixel = 0
	header.Parent = mainFrame

	makeLabel(header, "⚔️ DUELO 1v1", UDim2.new(0.7, 0, 1, 0), UDim2.new(0.02, 0, 0, 0), COLORS.duel, Enum.Font.Arcade)

	local closeBtn = makeButton(header, "X", COLORS.error, UDim2.new(0.1, 0, 0.8, 0), UDim2.new(0.88, 0, 0.1, 0))
	closeBtn.MouseButton1Click:Connect(function()
		playSound(sounds.close)
		gui.Parent = nil
	end)

	makeLabel(
		mainFrame,
		"Quem morrer primeiro perde! É preciso estar no MAPA.",
		UDim2.new(0.96, 0, 0.06, 0),
		UDim2.new(0.02, 0, 0.11, 0),
		COLORS.warning,
		Enum.Font.Code
	)

	-- (V2) BARRA DE APOSTA
	local betBar = Instance.new("Frame")
	betBar.Size = UDim2.new(0.96, 0, 0.09, 0)
	betBar.Position = UDim2.new(0.02, 0, 0.18, 0)
	betBar.BackgroundColor3 = COLORS.header
	betBar.BorderColor3 = COLORS.coin
	betBar.BorderSizePixel = 2
	betBar.Parent = mainFrame

	makeLabel(betBar, "APOSTA 💰", UDim2.new(0.26, 0, 1, 0), UDim2.new(0.01, 0, 0, 0), COLORS.coin, Enum.Font.Arcade)

	local betBox = Instance.new("TextBox")
	betBox.Size = UDim2.new(0.24, 0, 0.7, 0)
	betBox.Position = UDim2.new(0.28, 0, 0.15, 0)
	betBox.BackgroundColor3 = COLORS.background
	betBox.BorderColor3 = COLORS.coin
	betBox.BorderSizePixel = 2
	betBox.Text = tostring(currentBet)
	betBox.PlaceholderText = "0"
	betBox.TextColor3 = COLORS.coin
	betBox.TextScaled = true
	betBox.Font = Enum.Font.Code
	betBox.ClearTextOnFocus = false
	betBox.Parent = betBar

	local function setBet(v)
		currentBet = math.max(0, math.floor(v))
		betBox.Text = tostring(currentBet)
	end

	betBox.FocusLost:Connect(function()
		setBet(tonumber(betBox.Text) or 0)
	end)

	local p0 = makeButton(betBar, "0", COLORS.panel, UDim2.new(0.14, 0, 0.7, 0), UDim2.new(0.54, 0, 0.15, 0))
	local p50 = makeButton(betBar, "50", COLORS.panel, UDim2.new(0.14, 0, 0.7, 0), UDim2.new(0.69, 0, 0.15, 0))
	local p100 = makeButton(betBar, "100", COLORS.panel, UDim2.new(0.14, 0, 0.7, 0), UDim2.new(0.84, 0, 0.15, 0))
	p0.MouseButton1Click:Connect(function()
		setBet(0)
	end)
	p50.MouseButton1Click:Connect(function()
		setBet(50)
	end)
	p100.MouseButton1Click:Connect(function()
		setBet(100)
	end)

	local listScroll = Instance.new("ScrollingFrame")
	listScroll.Size = UDim2.new(0.96, 0, 0.47, 0)
	listScroll.Position = UDim2.new(0.02, 0, 0.29, 0)
	listScroll.BackgroundColor3 = COLORS.panel
	listScroll.BorderColor3 = COLORS.border
	listScroll.BorderSizePixel = 2
	listScroll.ScrollBarThickness = 6
	listScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
	listScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	listScroll.Parent = mainFrame

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 4)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = listScroll

	local function refreshList()
		for _, child in pairs(listScroll:GetChildren()) do
			if child:IsA("Frame") then
				child.Parent = nil
			end
		end

		local others = 0
		for _, p in ipairs(Players:GetPlayers()) do
			if p ~= player then
				others += 1
				local row = Instance.new("Frame")
				row.Size = UDim2.new(1, -8, 0, isMobile and 52 or 42)
				row.BackgroundColor3 = COLORS.header
				row.BorderColor3 = COLORS.border
				row.BorderSizePixel = 1
				row.Parent = listScroll

				makeLabel(row, p.Name, UDim2.new(0.6, 0, 1, 0), UDim2.new(0.02, 0, 0, 0), Color3.new(1, 1, 1), Enum.Font.Code)

				local duelBtn = makeButton(row, "DESAFIAR", COLORS.duel, UDim2.new(0.32, 0, 0.74, 0), UDim2.new(0.65, 0, 0.13, 0))
				duelBtn.MouseButton1Click:Connect(function()
					local ok, success, message = pcall(function()
						return requestDuelRemote:InvokeServer(p.Name, currentBet)
					end)
					if ok then
						showNotification(message or "Desafio enviado!", success == true)
					else
						showNotification("Erro ao enviar desafio!", false)
					end
				end)
			end
		end

		if others == 0 then
			local empty = Instance.new("Frame")
			empty.Size = UDim2.new(1, -8, 0, 60)
			empty.BackgroundTransparency = 1
			empty.Parent = listScroll
			makeLabel(empty, "Nenhum outro jogador no servidor...", UDim2.new(1, 0, 1, 0), UDim2.new(0, 0, 0, 0), COLORS.disabled, Enum.Font.Code)
		end
	end

	local latestArenaStatus = nil
	local arenaBtn = makeButton(
		mainFrame,
		"⌛ CONSULTANDO ARENA...",
		COLORS.disabled,
		UDim2.new(0.96, 0, 0.075, 0),
		UDim2.new(0.02, 0, 0.79, 0)
	)
	local arenaButtonRatio = Instance.new("UIAspectRatioConstraint")
	arenaButtonRatio.AspectRatio = isMobile and 7 or 10
	arenaButtonRatio.DominantAxis = Enum.DominantAxis.Height
	arenaButtonRatio.Parent = arenaBtn
	arenaBtn.Active = false

	local function refreshArenaStatus()
		if not getArenaStatusRemote or not spectateRemote then
			arenaBtn.Text = "MODO ESPECTADOR INDISPONÍVEL"
			arenaBtn.BackgroundColor3 = COLORS.disabled
			arenaBtn.Active = false
			return
		end
		local ok, status = pcall(function()
			return getArenaStatusRemote:InvokeServer()
		end)
		if not gui.Parent then
			return
		end
		if not ok or type(status) ~= "table" then
			arenaBtn.Text = "⚠ FALHA AO CONSULTAR ARENA"
			arenaBtn.BackgroundColor3 = COLORS.error
			arenaBtn.Active = false
			return
		end

		latestArenaStatus = status
		if status.busy then
			arenaBtn.Text = string.format(
				"👁 ASSISTIR %s VS %s  [%d/%d]",
				status.playerA or "?",
				status.playerB or "?",
				tonumber(status.spectators) or 0,
				tonumber(status.capacity) or 0
			)
			arenaBtn.BackgroundColor3 = COLORS.duel
			arenaBtn.Active = true
		else
			arenaBtn.Text = "ARENA LIVRE — INICIE UM DESAFIO"
			arenaBtn.BackgroundColor3 = COLORS.success
			arenaBtn.Active = false
		end
	end

	arenaBtn.Activated:Connect(function()
		if not latestArenaStatus or not latestArenaStatus.busy or not arenaBtn.Active then
			return
		end
		arenaBtn.Active = false
		arenaBtn.Text = "ENTRANDO NA ARQUIBANCADA..."
		local ok, success, message, status = pcall(function()
			return spectateRemote:InvokeServer(true)
		end)
		if not ok or success ~= true then
			showNotification(message or "Não foi possível entrar na arquibancada.", false)
			refreshArenaStatus()
			return
		end
		gui.Parent = nil
		if not isSpectating and type(status) == "table" then
			showSpectatorOverlay(status)
		end
	end)

	local refreshBtn = makeButton(mainFrame, "↻ ATUALIZAR LISTA", COLORS.header, UDim2.new(0.96, 0, 0.075, 0), UDim2.new(0.02, 0, 0.89, 0))
	refreshBtn.MouseButton1Click:Connect(refreshList)

	refreshList()
	refreshArenaStatus()
	task.spawn(function()
		while gui.Parent do
			task.wait(2)
			if gui.Parent then
				refreshArenaStatus()
			end
		end
	end)
end

_G.OpenDuelPlayerList = openDuelPlayerList

-- =====================================
-- TELA 2: POPUP DE DESAFIO (REUTILIZADO do TradeMenuClient_V1 + aposta)
-- =====================================

local function createDuelInvitePopup(fromName, bet)
	bet = tonumber(bet) or 0
	local old = playerGui:FindFirstChild("DuelInviteGui")
	if old then
		old.Parent = nil
	end

	playSound(sounds.open)
	if _G.SetMenuNotification then
		_G.SetMenuNotification("DUELO", true)
	end

	local inviteGui = Instance.new("ScreenGui")
	inviteGui.Name = "DuelInviteGui"
	inviteGui.ResetOnSpawn = false
	inviteGui.DisplayOrder = 110
	inviteGui.Parent = playerGui

	local popup = Instance.new("Frame")
	popup.Size = isMobile and UDim2.new(0.8, 0, 0.34, 0) or UDim2.new(0.34, 0, 0.28, 0)
	popup.Position = isMobile and UDim2.new(0.1, 0, 0.3, 0) or UDim2.new(0.33, 0, 0.33, 0)
	popup.BackgroundColor3 = COLORS.background
	popup.BorderColor3 = COLORS.duel
	popup.BorderSizePixel = 3
	popup.Parent = inviteGui

	makeLabel(popup, "⚔️ DESAFIO DE DUELO", UDim2.new(1, 0, 0.2, 0), UDim2.new(0, 0, 0.03, 0), COLORS.duel, Enum.Font.Arcade)
	makeLabel(
		popup,
		fromName .. " te desafiou para um duelo 1v1!",
		UDim2.new(0.9, 0, 0.22, 0),
		UDim2.new(0.05, 0, 0.24, 0),
		Color3.new(1, 1, 1),
		Enum.Font.Code
	)

	local betText = bet > 0 and ("💰 APOSTA: " .. bet .. " moedas (vencedor leva " .. (bet * 2) .. ")") or "Sem aposta"
	makeLabel(popup, betText, UDim2.new(0.9, 0, 0.14, 0), UDim2.new(0.05, 0, 0.45, 0), COLORS.coin, Enum.Font.Code)

	local timerLabel = makeLabel(popup, "Expira em: 20s", UDim2.new(1, 0, 0.12, 0), UDim2.new(0, 0, 0.6, 0), COLORS.warning, Enum.Font.Code)

	local buttonFrame = Instance.new("Frame")
	buttonFrame.Size = UDim2.new(0.9, 0, 0.2, 0)
	buttonFrame.Position = UDim2.new(0.05, 0, 0.76, 0)
	buttonFrame.BackgroundTransparency = 1
	buttonFrame.Parent = popup

	local acceptBtn = makeButton(buttonFrame, "⚔️ ACEITAR", COLORS.success, UDim2.new(0.48, 0, 1, 0), UDim2.new(0, 0, 0, 0))
	local declineBtn = makeButton(buttonFrame, "❌ RECUSAR", COLORS.error, UDim2.new(0.48, 0, 1, 0), UDim2.new(0.52, 0, 0, 0))

	local timeLeft = 20
	task.spawn(function()
		while timeLeft > 0 and inviteGui.Parent do
			task.wait(1)
			timeLeft -= 1
			if timerLabel.Parent then
				timerLabel.Text = "Expira em: " .. timeLeft .. "s"
			end
		end
		if inviteGui.Parent then
			respondToDuelRemote:FireServer(false)
			inviteGui.Parent = nil
		end
	end)

	local function close()
		inviteGui.Parent = nil
		if _G.SetMenuNotification then
			_G.SetMenuNotification("DUELO", false)
		end
	end

	acceptBtn.MouseButton1Click:Connect(function()
		respondToDuelRemote:FireServer(true)
		close()
	end)
	declineBtn.MouseButton1Click:Connect(function()
		respondToDuelRemote:FireServer(false)
		close()
	end)
end

duelInviteRemote.OnClientEvent:Connect(createDuelInvitePopup)

-- =====================================
-- TELA 3: CONTAGEM 3-2-1-LUTE
-- =====================================

local function showCountdown(n, opponentName)
	local gui = playerGui:FindFirstChild("DuelCountdownGui")
	if not gui then
		gui = Instance.new("ScreenGui")
		gui.Name = "DuelCountdownGui"
		gui.ResetOnSpawn = false
		gui.DisplayOrder = 130
		gui.IgnoreGuiInset = true
		gui.Parent = playerGui

		local vsLbl = Instance.new("TextLabel")
		vsLbl.Name = "VS"
		vsLbl.AnchorPoint = Vector2.new(0.5, 0.5)
		vsLbl.Position = UDim2.fromScale(0.5, 0.35)
		vsLbl.Size = UDim2.fromScale(0.8, 0.1)
		vsLbl.BackgroundTransparency = 1
		vsLbl.Text = "VS " .. (opponentName or "?")
		vsLbl.TextColor3 = COLORS.duel
		vsLbl.TextScaled = true
		vsLbl.Font = Enum.Font.Arcade
		vsLbl.Parent = gui

		local numLbl = Instance.new("TextLabel")
		numLbl.Name = "Num"
		numLbl.AnchorPoint = Vector2.new(0.5, 0.5)
		numLbl.Position = UDim2.fromScale(0.5, 0.5)
		numLbl.Size = UDim2.fromScale(0.5, 0.25)
		numLbl.BackgroundTransparency = 1
		numLbl.Text = ""
		numLbl.TextColor3 = Color3.new(1, 1, 1)
		numLbl.TextScaled = true
		numLbl.Font = Enum.Font.Arcade
		numLbl.Parent = gui
	end

	local numLbl = gui:FindFirstChild("Num")
	if numLbl then
		numLbl.Text = (n > 0) and tostring(n) or "LUTE!"
		numLbl.TextColor3 = (n > 0) and COLORS.warning or COLORS.success
		numLbl.TextTransparency = 0
		numLbl.Size = UDim2.fromScale(0.35, 0.18)
		TweenService:Create(numLbl, TweenInfo.new(0.8), {
			Size = UDim2.fromScale(0.55, 0.28),
			TextTransparency = 0.3,
		}):Play()
	end

	if n <= 0 then
		task.delay(1, function()
			if gui and gui.Parent then
				gui.Parent = nil
			end
		end)
	end
end

duelCountdownRemote.OnClientEvent:Connect(showCountdown)

-- =====================================
-- TELA 4: RESULTADO (VITÓRIA / DERROTA / EMPATE)
-- =====================================

local function showResult(outcome, opponentName, rewardText)
	if outcome == "cancel" then
		showNotification(rewardText ~= "" and rewardText or "Duelo cancelado.", false)
		if _G.SetMenuNotification then
			_G.SetMenuNotification("DUELO", false)
		end
		return
	end

	local cd = playerGui:FindFirstChild("DuelCountdownGui")
	if cd then
		cd.Parent = nil
	end

	local titles = {
		win = { txt = "VITÓRIA!", color = COLORS.success },
		lose = { txt = "DERROTA", color = COLORS.error },
		draw = { txt = "EMPATE", color = COLORS.warning },
	}
	local info = titles[outcome] or titles.draw

	playSound(outcome == "win" and sounds.purchase or sounds.close)

	local gui = Instance.new("ScreenGui")
	gui.Name = "DuelResultGui"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 131
	gui.IgnoreGuiInset = true
	gui.Parent = playerGui

	local frame = Instance.new("Frame")
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(0.5, 0.4)
	frame.Size = isMobile and UDim2.fromScale(0.8, 0.3) or UDim2.fromScale(0.4, 0.28)
	frame.BackgroundColor3 = COLORS.background
	frame.BorderColor3 = info.color
	frame.BorderSizePixel = 4
	frame.Parent = gui

	makeLabel(frame, info.txt, UDim2.fromScale(1, 0.4), UDim2.fromScale(0, 0.08), info.color, Enum.Font.Arcade)
	makeLabel(
		frame,
		(outcome == "win" and "Você venceu " or outcome == "lose" and "Você perdeu para " or "Duelo contra ")
			.. (opponentName or "?"),
		UDim2.fromScale(0.9, 0.18),
		UDim2.fromScale(0.05, 0.5),
		Color3.new(1, 1, 1),
		Enum.Font.Code
	)
	if rewardText and rewardText ~= "" then
		makeLabel(frame, rewardText, UDim2.fromScale(0.9, 0.16), UDim2.fromScale(0.05, 0.7), COLORS.coin, Enum.Font.Arcade)
	end

	if _G.SetMenuNotification then
		_G.SetMenuNotification("DUELO", false)
	end

	task.delay(4, function()
		if gui and gui.Parent then
			gui.Parent = nil
		end
	end)
end

duelResultRemote.OnClientEvent:Connect(showResult)

-- =====================================
-- REGISTRO NO MENU (REUTILIZADO: _G.RegisterMenuCategory)
-- =====================================

task.spawn(function()
	local t = 0
	while not _G.RegisterMenuCategory and t < 20 do
		task.wait(0.3)
		t += 0.3
	end
	if _G.RegisterMenuCategory then
		_G.RegisterMenuCategory("DUELO", "⚔️", function()
			openDuelPlayerList()
		end, function()
			local g = playerGui:FindFirstChild("DuelPlayerList")
			if g then
				g.Parent = nil
			end
		end, 4.5)
		print("[DUEL CLIENT V3] Categoria DUELO registrada no menu")
	end
end)

print("[DUEL CLIENT V3] ⚔️ Cliente de duelo (arena ao vivo + torcida) carregado")
