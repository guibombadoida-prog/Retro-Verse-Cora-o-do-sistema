-- ============================================
-- TRADE MENU CLIENT V1 — TROCAS + DOAÇÕES (RETRO)
-- Coloque em StarterPlayer > StarterPlayerScripts
-- Nome: "TradeMenuClient"
-- ============================================
-- SISTEMA NOVO construído 100% sobre código existente:
-- • REUTILIZADO do TeamMenuClient_V6: paleta COLORS, sons +
--   playSound, showNotification, popup de convite com timer,
--   listas com UIListLayout e detecção mobile
-- • REUTILIZADO do UnifiedMenuClient_V3: integração pronta —
--   categoria "TROCAS" 🔄 já chama _G.OpenTradePlayerList e
--   fecha a GUI "TradePlayerList"; usa _G.SetMenuNotification
-- • Fontes retro do projeto: Arcade (títulos/botões) e Code
--   (textos), igual aos demais menus
--
-- TELAS:
-- 1) TradePlayerList — lista de jogadores p/ enviar pedido
-- 2) TradeInviteGui — popup ACEITAR/RECUSAR (timer 20s)
-- 3) TradeWindow — mesa de trocas: suas ofertas x dele,
--    DOAÇÃO de moedas, SISTEMA DE VALOR por lado e PRONTO
-- ============================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local SoundService = game:GetService("SoundService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

-- =====================================
-- REMOTES
-- =====================================

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local requestTradeRemote = remotes:WaitForChild("RequestTrade", 15)
local getTradeDataRemote = remotes:WaitForChild("GetTradeData", 15)
local tradeInviteRemote = remotes:WaitForChild("TradeInvite", 15)
local respondToTradeRemote = remotes:WaitForChild("RespondToTrade", 15)
local updateTradeOfferRemote = remotes:WaitForChild("UpdateTradeOffer", 15)
local tradeStateRemote = remotes:WaitForChild("TradeStateUpdate", 15)
local tradeResultRemote = remotes:WaitForChild("TradeResult", 15)

if not requestTradeRemote then
	warn("[TRADE CLIENT V1] Remotes de troca não encontrados — TradeSystemServer está no ServerScriptService?")
	return
end

-- =====================================
-- SONS (REUTILIZADOS do TeamMenuClient_V6)
-- =====================================

local sounds = {
	hover = "rbxassetid://12846056",
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

-- =====================================
-- CORES (REUTILIZADAS do TeamMenuClient_V6)
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
	coin = Color3.fromRGB(255, 200, 0),
	value = Color3.fromRGB(0, 255, 170),
}

-- =====================================
-- NOTIFICAÇÃO (REUTILIZADA do TeamMenuClient_V6)
-- =====================================

local function showNotification(message, isSuccess)
	playSound(isSuccess and sounds.purchase or sounds.error)

	local notification = Instance.new("ScreenGui")
	notification.Name = "TradeNotification"
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

-- =====================================
-- FÁBRICA DE ELEMENTOS RETRO
-- =====================================

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
	btn.MouseButton1Click:Connect(function()
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
-- TELA 1: LISTA DE JOGADORES (TradePlayerList)
-- Nome exato esperado pelo UnifiedMenuClient_V3
-- =====================================

local function openTradePlayerList()
	local old = playerGui:FindFirstChild("TradePlayerList")
	if old then
		old.Parent = nil
	end

	playSound(sounds.open)

	local gui = Instance.new("ScreenGui")
	gui.Name = "TradePlayerList"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 60
	gui.Parent = playerGui

	local mainFrame = Instance.new("Frame")
	mainFrame.Size = isMobile and UDim2.new(0.85, 0, 0.7, 0) or UDim2.new(0.4, 0, 0.6, 0)
	mainFrame.Position = isMobile and UDim2.new(0.075, 0, 0.15, 0) or UDim2.new(0.3, 0, 0.2, 0)
	mainFrame.BackgroundColor3 = COLORS.background
	mainFrame.BorderColor3 = COLORS.border
	mainFrame.BorderSizePixel = 3
	mainFrame.Parent = gui

	local header = Instance.new("Frame")
	header.Size = UDim2.new(1, 0, 0.12, 0)
	header.BackgroundColor3 = COLORS.header
	header.BorderSizePixel = 0
	header.Parent = mainFrame

	makeLabel(header, "🔄 TROCAS", UDim2.new(0.7, 0, 1, 0), UDim2.new(0.02, 0, 0, 0), COLORS.warning, Enum.Font.Arcade)

	local closeBtn = makeButton(header, "X", COLORS.error, UDim2.new(0.12, 0, 0.8, 0), UDim2.new(0.86, 0, 0.1, 0))
	closeBtn.MouseButton1Click:Connect(function()
		playSound(sounds.close)
		gui.Parent = nil
	end)

	makeLabel(
		mainFrame,
		"Apenas personagens da LOJA podem ser trocados. Doações de moedas são permitidas!",
		UDim2.new(0.96, 0, 0.1, 0),
		UDim2.new(0.02, 0, 0.13, 0),
		COLORS.value,
		Enum.Font.Code
	)

	local listScroll = Instance.new("ScrollingFrame")
	listScroll.Size = UDim2.new(0.96, 0, 0.62, 0)
	listScroll.Position = UDim2.new(0.02, 0, 0.25, 0)
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

				local tradeBtn = makeButton(row, "TROCAR", COLORS.success, UDim2.new(0.32, 0, 0.74, 0), UDim2.new(0.65, 0, 0.13, 0))
				tradeBtn.MouseButton1Click:Connect(function()
					-- RequestTrade retorna (sucesso, mensagem)
					local ok, success, message = pcall(function()
						return requestTradeRemote:InvokeServer(p.Name)
					end)
					if ok then
						showNotification(message or "Pedido enviado!", success == true)
					else
						showNotification("Erro ao enviar pedido de troca!", false)
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

	local refreshBtn = makeButton(mainFrame, "↻ ATUALIZAR LISTA", COLORS.header, UDim2.new(0.96, 0, 0.09, 0), UDim2.new(0.02, 0, 0.89, 0))
	refreshBtn.MouseButton1Click:Connect(refreshList)

	refreshList()
end

_G.OpenTradePlayerList = openTradePlayerList

-- =====================================
-- TELA 2: POPUP DE PEDIDO (REUTILIZADO do TeamMenuClient_V6)
-- =====================================

local function createTradeInvitePopup(fromName)
	local old = playerGui:FindFirstChild("TradeInviteGui")
	if old then
		old.Parent = nil
	end

	playSound(sounds.open)
	if _G.SetMenuNotification then
		_G.SetMenuNotification("TROCAS", true)
	end

	local inviteGui = Instance.new("ScreenGui")
	inviteGui.Name = "TradeInviteGui"
	inviteGui.ResetOnSpawn = false
	inviteGui.DisplayOrder = 110
	inviteGui.Parent = playerGui

	local popup = Instance.new("Frame")
	popup.Size = isMobile and UDim2.new(0.8, 0, 0.32, 0) or UDim2.new(0.34, 0, 0.26, 0)
	popup.Position = isMobile and UDim2.new(0.1, 0, 0.3, 0) or UDim2.new(0.33, 0, 0.33, 0)
	popup.BackgroundColor3 = COLORS.background
	popup.BorderColor3 = COLORS.warning
	popup.BorderSizePixel = 3
	popup.Parent = inviteGui

	makeLabel(popup, "🔄 PEDIDO DE TROCA", UDim2.new(1, 0, 0.22, 0), UDim2.new(0, 0, 0.03, 0), COLORS.warning, Enum.Font.Arcade)
	makeLabel(
		popup,
		fromName .. " quer trocar com você!",
		UDim2.new(0.9, 0, 0.3, 0),
		UDim2.new(0.05, 0, 0.27, 0),
		Color3.new(1, 1, 1),
		Enum.Font.Code
	)

	local timerLabel = makeLabel(popup, "Expira em: 20s", UDim2.new(1, 0, 0.13, 0), UDim2.new(0, 0, 0.58, 0), COLORS.warning, Enum.Font.Code)

	local buttonFrame = Instance.new("Frame")
	buttonFrame.Size = UDim2.new(0.9, 0, 0.22, 0)
	buttonFrame.Position = UDim2.new(0.05, 0, 0.74, 0)
	buttonFrame.BackgroundTransparency = 1
	buttonFrame.Parent = popup

	local acceptBtn = makeButton(buttonFrame, "✅ ACEITAR", COLORS.success, UDim2.new(0.48, 0, 1, 0), UDim2.new(0, 0, 0, 0))
	local declineBtn = makeButton(buttonFrame, "❌ RECUSAR", COLORS.error, UDim2.new(0.48, 0, 1, 0), UDim2.new(0.52, 0, 0, 0))

	-- Timer (REUTILIZADO do popup de convite do TeamMenuClient_V6)
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
			respondToTradeRemote:FireServer(false)
			inviteGui.Parent = nil
		end
	end)

	acceptBtn.MouseButton1Click:Connect(function()
		respondToTradeRemote:FireServer(true)
		inviteGui.Parent = nil
		if _G.SetMenuNotification then
			_G.SetMenuNotification("TROCAS", false)
		end
	end)

	declineBtn.MouseButton1Click:Connect(function()
		respondToTradeRemote:FireServer(false)
		inviteGui.Parent = nil
		if _G.SetMenuNotification then
			_G.SetMenuNotification("TROCAS", false)
		end
	end)
end

tradeInviteRemote.OnClientEvent:Connect(createTradeInvitePopup)

-- =====================================
-- TELA 3: MESA DE TROCAS (TradeWindow)
-- =====================================

local tradeUI = nil -- referências da janela ativa

local function closeTradeWindow()
	if tradeUI and tradeUI.gui then
		tradeUI.gui.Parent = nil
	end
	tradeUI = nil
end

local function buildTradeWindow()
	closeTradeWindow()
	playSound(sounds.open)

	local gui = Instance.new("ScreenGui")
	gui.Name = "TradeWindow"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 90
	gui.Parent = playerGui

	local mainFrame = Instance.new("Frame")
	mainFrame.Size = isMobile and UDim2.new(0.96, 0, 0.88, 0) or UDim2.new(0.7, 0, 0.78, 0)
	mainFrame.Position = isMobile and UDim2.new(0.02, 0, 0.06, 0) or UDim2.new(0.15, 0, 0.11, 0)
	mainFrame.BackgroundColor3 = COLORS.background
	mainFrame.BorderColor3 = COLORS.border
	mainFrame.BorderSizePixel = 3
	mainFrame.Parent = gui

	local header = Instance.new("Frame")
	header.Size = UDim2.new(1, 0, 0.09, 0)
	header.BackgroundColor3 = COLORS.header
	header.BorderSizePixel = 0
	header.Parent = mainFrame

	local title = makeLabel(header, "🔄 MESA DE TROCAS", UDim2.new(0.7, 0, 1, 0), UDim2.new(0.02, 0, 0, 0), COLORS.warning, Enum.Font.Arcade)

	local cancelBtn = makeButton(header, "CANCELAR", COLORS.error, UDim2.new(0.18, 0, 0.8, 0), UDim2.new(0.8, 0, 0.1, 0))
	cancelBtn.MouseButton1Click:Connect(function()
		updateTradeOfferRemote:FireServer("cancel")
	end)

	-- Painel genérico de oferta
	local function buildOfferPanel(xPos, headerText, headerColor)
		local panel = Instance.new("Frame")
		panel.Size = UDim2.new(0.47, 0, 0.46, 0)
		panel.Position = UDim2.new(xPos, 0, 0.1, 0)
		panel.BackgroundColor3 = COLORS.panel
		panel.BorderColor3 = COLORS.border
		panel.BorderSizePixel = 2
		panel.Parent = mainFrame

		local pTitle = makeLabel(panel, headerText, UDim2.new(0.7, 0, 0.13, 0), UDim2.new(0.02, 0, 0.01, 0), headerColor, Enum.Font.Arcade)

		local readyDot = makeLabel(panel, "⏳", UDim2.new(0.25, 0, 0.13, 0), UDim2.new(0.73, 0, 0.01, 0), COLORS.disabled, Enum.Font.Code)

		local list = Instance.new("ScrollingFrame")
		list.Size = UDim2.new(0.96, 0, 0.56, 0)
		list.Position = UDim2.new(0.02, 0, 0.15, 0)
		list.BackgroundColor3 = COLORS.background
		list.BorderColor3 = COLORS.border
		list.BorderSizePixel = 1
		list.ScrollBarThickness = 5
		list.AutomaticCanvasSize = Enum.AutomaticSize.Y
		list.CanvasSize = UDim2.new(0, 0, 0, 0)
		list.Parent = panel

		local lay = Instance.new("UIListLayout")
		lay.Padding = UDim.new(0, 3)
		lay.Parent = list

		local coinsLabel = makeLabel(panel, "💰 DOAÇÃO: 0", UDim2.new(0.96, 0, 0.12, 0), UDim2.new(0.02, 0, 0.72, 0), COLORS.coin, Enum.Font.Code)
		local valueLabel = makeLabel(panel, "VALOR TOTAL: 0", UDim2.new(0.96, 0, 0.12, 0), UDim2.new(0.02, 0, 0.85, 0), COLORS.value, Enum.Font.Arcade)

		return {
			panel = panel,
			title = pTitle,
			readyDot = readyDot,
			list = list,
			coinsLabel = coinsLabel,
			valueLabel = valueLabel,
		}
	end

	local mySide = buildOfferPanel(0.02, "VOCÊ", COLORS.value)
	local otherSide = buildOfferPanel(0.51, "...", Color3.new(1, 1, 1))

	-- Controles de DOAÇÃO de moedas (só no seu lado)
	local coinBar = Instance.new("Frame")
	coinBar.Size = UDim2.new(0.47, 0, 0.08, 0)
	coinBar.Position = UDim2.new(0.02, 0, 0.57, 0)
	coinBar.BackgroundColor3 = COLORS.header
	coinBar.BorderColor3 = COLORS.border
	coinBar.BorderSizePixel = 2
	coinBar.Parent = mainFrame

	local coinBox = Instance.new("TextBox")
	coinBox.Size = UDim2.new(0.34, 0, 0.74, 0)
	coinBox.Position = UDim2.new(0.02, 0, 0.13, 0)
	coinBox.BackgroundColor3 = COLORS.background
	coinBox.BorderColor3 = COLORS.coin
	coinBox.BorderSizePixel = 2
	coinBox.PlaceholderText = "0"
	coinBox.Text = ""
	coinBox.TextColor3 = COLORS.coin
	coinBox.TextScaled = true
	coinBox.Font = Enum.Font.Code
	coinBox.ClearTextOnFocus = false
	coinBox.Parent = coinBar

	local function sendCoins(amount)
		updateTradeOfferRemote:FireServer("setCoins", amount)
	end

	coinBox.FocusLost:Connect(function()
		sendCoins(math.floor(tonumber(coinBox.Text) or 0))
	end)

	local mais50 = makeButton(coinBar, "+50", COLORS.panel, UDim2.new(0.18, 0, 0.74, 0), UDim2.new(0.38, 0, 0.13, 0))
	local mais500 = makeButton(coinBar, "+500", COLORS.panel, UDim2.new(0.18, 0, 0.74, 0), UDim2.new(0.58, 0, 0.13, 0))
	local zerar = makeButton(coinBar, "ZERAR", COLORS.error, UDim2.new(0.2, 0, 0.74, 0), UDim2.new(0.78, 0, 0.13, 0))

	local currentMyCoins = 0
	mais50.MouseButton1Click:Connect(function()
		sendCoins(currentMyCoins + 50)
	end)
	mais500.MouseButton1Click:Connect(function()
		sendCoins(currentMyCoins + 500)
	end)
	zerar.MouseButton1Click:Connect(function()
		sendCoins(0)
	end)

	-- Botão PRONTO
	local readyBtn = makeButton(mainFrame, "✔ PRONTO", COLORS.header, UDim2.new(0.47, 0, 0.08, 0), UDim2.new(0.51, 0, 0.57, 0))
	local iAmReady = false
	readyBtn.MouseButton1Click:Connect(function()
		updateTradeOfferRemote:FireServer("ready", not iAmReady)
	end)

	-- Inventário: SEUS PERSONAGENS DA LOJA
	makeLabel(mainFrame, "SEUS PERSONAGENS DA LOJA (clique para oferecer):", UDim2.new(0.96, 0, 0.05, 0), UDim2.new(0.02, 0, 0.66, 0), COLORS.warning, Enum.Font.Code)

	local invScroll = Instance.new("ScrollingFrame")
	invScroll.Size = UDim2.new(0.96, 0, 0.26, 0)
	invScroll.Position = UDim2.new(0.02, 0, 0.715, 0)
	invScroll.BackgroundColor3 = COLORS.panel
	invScroll.BorderColor3 = COLORS.border
	invScroll.BorderSizePixel = 2
	invScroll.ScrollBarThickness = 6
	invScroll.AutomaticCanvasSize = Enum.AutomaticSize.X
	invScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
	invScroll.ScrollingDirection = Enum.ScrollingDirection.X
	invScroll.Parent = mainFrame

	local invLayout = Instance.new("UIListLayout")
	invLayout.FillDirection = Enum.FillDirection.Horizontal
	invLayout.Padding = UDim.new(0, 5)
	invLayout.Parent = invScroll

	local function refreshInventory()
		for _, child in pairs(invScroll:GetChildren()) do
			if child:IsA("TextButton") then
				child.Parent = nil
			end
		end

		local ok, data = pcall(function()
			return getTradeDataRemote:InvokeServer()
		end)
		if not ok or not data then
			return
		end

		for _, charInfo in ipairs(data.tradeables or {}) do
			local chip = Instance.new("TextButton")
			chip.Size = UDim2.new(0, isMobile and 150 or 130, 0.92, 0)
			chip.BackgroundColor3 = COLORS.header
			chip.BorderColor3 = COLORS.value
			chip.BorderSizePixel = 2
			chip.Text = charInfo.name .. "\n💰 " .. charInfo.price
			chip.TextColor3 = Color3.new(1, 1, 1)
			chip.TextScaled = true
			chip.Font = Enum.Font.Code
			chip.Parent = invScroll
			chip.MouseButton1Click:Connect(function()
				playSound(sounds.click)
				updateTradeOfferRemote:FireServer("addChar", charInfo.id)
			end)
		end
	end

	tradeUI = {
		gui = gui,
		title = title,
		mySide = mySide,
		otherSide = otherSide,
		coinBox = coinBox,
		readyBtn = readyBtn,
		refreshInventory = refreshInventory,
		setReadyState = function(state)
			iAmReady = state
		end,
		setMyCoins = function(n)
			currentMyCoins = n
		end,
	}

	refreshInventory()
	return tradeUI
end

-- Renderizar um lado da mesa
local function renderSide(side, info, removable)
	side.title.Text = info.name
	side.readyDot.Text = info.ready and "✅ PRONTO" or "⏳"
	side.readyDot.TextColor3 = info.ready and COLORS.success or COLORS.disabled
	side.coinsLabel.Text = "💰 DOAÇÃO: " .. tostring(info.coins or 0)
	side.valueLabel.Text = "VALOR TOTAL: " .. tostring(info.total or 0)

	for _, child in pairs(side.list:GetChildren()) do
		if child:IsA("TextButton") or child:IsA("TextLabel") then
			child.Parent = nil
		end
	end

	for _, item in ipairs(info.chars or {}) do
		if removable then
			local row = Instance.new("TextButton")
			row.Size = UDim2.new(1, -8, 0, 30)
			row.BackgroundColor3 = COLORS.header
			row.BorderColor3 = COLORS.border
			row.BorderSizePixel = 1
			row.Text = item.name .. "  (💰" .. item.price .. ")  ✖"
			row.TextColor3 = Color3.new(1, 1, 1)
			row.TextScaled = true
			row.Font = Enum.Font.Code
			row.Parent = side.list
			row.MouseButton1Click:Connect(function()
				playSound(sounds.click)
				updateTradeOfferRemote:FireServer("removeChar", item.id)
			end)
		else
			local row = Instance.new("TextLabel")
			row.Size = UDim2.new(1, -8, 0, 30)
			row.BackgroundColor3 = COLORS.header
			row.BorderColor3 = COLORS.border
			row.BorderSizePixel = 1
			row.Text = item.name .. "  (💰" .. item.price .. ")"
			row.TextColor3 = Color3.new(1, 1, 1)
			row.TextScaled = true
			row.Font = Enum.Font.Code
			row.Parent = side.list
		end
	end
end

-- =====================================
-- EVENTOS DO SERVIDOR
-- =====================================

tradeStateRemote.OnClientEvent:Connect(function(state)
	if not state or not state.you then
		return
	end

	if not tradeUI or not tradeUI.gui or not tradeUI.gui.Parent then
		buildTradeWindow()
		-- Fechar a lista de jogadores ao entrar na mesa
		local list = playerGui:FindFirstChild("TradePlayerList")
		if list then
			list.Parent = nil
		end
	end

	tradeUI.title.Text = "🔄 TROCAS: VOCÊ ⇄ " .. state.other.name
	renderSide(tradeUI.mySide, state.you, true)
	renderSide(tradeUI.otherSide, state.other, false)

	tradeUI.setMyCoins(state.you.coins or 0)
	tradeUI.setReadyState(state.you.ready == true)
	tradeUI.readyBtn.Text = state.you.ready and "✖ CANCELAR PRONTO" or "✔ PRONTO"
	tradeUI.readyBtn.BackgroundColor3 = state.you.ready and COLORS.success or COLORS.header
end)

tradeResultRemote.OnClientEvent:Connect(function(success, message)
	closeTradeWindow()
	showNotification(message, success == true)
	if _G.SetMenuNotification then
		_G.SetMenuNotification("TROCAS", false)
	end
	-- Atualizar o menu de personagens após uma troca concluída
	if success and _G.updatePlayerData then
		task.spawn(_G.updatePlayerData)
	end
end)

print([[
╔════════════════════════════════════════════════════╗
║   🔄 TRADE MENU CLIENT V1 — TROCAS + DOAÇÕES      ║
╠════════════════════════════════════════════════════╣
║  Integrado ao UnifiedMenu (categoria TROCAS 🔄)   ║
║  Só personagens da LOJA | Sistema de VALOR        ║
╚════════════════════════════════════════════════════╝
]])
