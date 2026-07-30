-- ============================================
-- DAILY REWARDS CLIENT V1 — GUI DE RECOMPENSA DIÁRIA
-- Coloque em StarterPlayer > StarterPlayerScripts
-- Nome: "DailyRewardsClient"
-- SUBSTITUI: (nenhum — script novo, a GUI não existia)
-- ============================================
-- REUTILIZADO:
-- • ClaimDailyReward / GetDailyRewardStatus /
--   RecoverLostDay ............................ DailyRewardsServer_V5
-- • _G.RegisterMenuCategory /
--   _G.SetMenuNotification .................... UnifiedMenuClient (V3)
-- • Estilo retro (Arcade/Code, bordas, sons) ... padrão dos menus do projeto
--   (TutorialMenuClient / AchievementMenuClient)
-- ============================================
-- REGRAS DO PROJETO RESPEITADAS:
-- • Sem botão próprio na tela — abre só pelo Menu Unificado (☰)
-- • Tamanhos em Scale, TextScaled = true, ResetOnSpawn = false
-- • Sem :Destroy() — usa Parent = nil
-- • Sem lógica de economia no client (só exibe / invoca remotes)
-- ============================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

print("[DAILY CLIENT V1] Inicializando...")

-- =====================================
-- REMOTES (criados pelo DailyRewardsServer)
-- =====================================

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local claimDailyReward = remotes:WaitForChild("ClaimDailyReward", 15)
local getDailyRewardStatus = remotes:WaitForChild("GetDailyRewardStatus", 15)
local recoverLostDay = remotes:WaitForChild("RecoverLostDay", 15)

if not claimDailyReward or not getDailyRewardStatus then
	warn("[DAILY CLIENT V1] ⚠️ Remotes de daily não encontrados — DailyRewardsServer está no ServerScriptService?")
	return
end

-- =====================================
-- CORES / ESTILO RETRO (padrão do projeto)
-- =====================================

local COLORS = {
	bg = Color3.fromRGB(15, 15, 25),
	panel = Color3.fromRGB(25, 25, 40),
	card = Color3.fromRGB(35, 35, 55),
	cardClaimed = Color3.fromRGB(20, 45, 25),
	cardNext = Color3.fromRGB(55, 45, 15),
	border = Color3.fromRGB(0, 255, 200),
	text = Color3.fromRGB(235, 235, 235),
	textDim = Color3.fromRGB(150, 150, 170),
	gold = Color3.fromRGB(255, 200, 40),
	green = Color3.fromRGB(60, 220, 90),
	red = Color3.fromRGB(230, 70, 70),
	purple = Color3.fromRGB(170, 90, 255),
}

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

local SOUND_OPEN = "rbxassetid://157167203"
local SOUND_CLAIM = "rbxassetid://157167205"

-- =====================================
-- HELPERS DE UI (Scale + TextScaled)
-- =====================================

local function makeLabel(parent, text, size, pos, color, font)
	local l = Instance.new("TextLabel")
	l.Size = size
	l.Position = pos
	l.BackgroundTransparency = 1
	l.Text = text
	l.TextScaled = true
	l.TextColor3 = color or COLORS.text
	l.Font = font or Enum.Font.Code
	l.Parent = parent
	return l
end

local function makeButton(parent, text, size, pos, bgColor)
	local b = Instance.new("TextButton")
	b.Size = size
	b.Position = pos
	b.BackgroundColor3 = bgColor or COLORS.border
	b.BorderSizePixel = 0
	b.Text = text
	b.TextScaled = true
	b.TextColor3 = Color3.fromRGB(10, 10, 15)
	b.Font = Enum.Font.Arcade
	b.AutoButtonColor = true
	b.Parent = parent
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0.2, 0)
	c.Parent = b
	return b
end

local function formatTime(seconds)
	seconds = math.max(0, math.floor(seconds))
	local h = math.floor(seconds / 3600)
	local m = math.floor((seconds % 3600) / 60)
	local s = seconds % 60
	return string.format("%02d:%02d:%02d", h, m, s)
end

-- =====================================
-- GUI PRINCIPAL
-- =====================================

local gui = nil
local mainFrame = nil
local isOpen = false
local countdownConn = nil

local function stopCountdown()
	if countdownConn then
		pcall(task.cancel, countdownConn)
		countdownConn = nil
	end
end

local function buildGui()
	if gui and gui.Parent then
		return
	end

	gui = Instance.new("ScreenGui")
	gui.Name = "DailyRewardsMenu"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 120
	gui.IgnoreGuiInset = false
	gui.Enabled = false
	gui.Parent = playerGui

	-- Fundo escurecido
	local bg = Instance.new("Frame")
	bg.Name = "Background"
	bg.Size = UDim2.fromScale(1, 1)
	bg.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	bg.BackgroundTransparency = 0.45
	bg.BorderSizePixel = 0
	bg.Parent = gui

	-- Janela principal
	mainFrame = Instance.new("Frame")
	mainFrame.Name = "MainFrame"
	mainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	mainFrame.Position = UDim2.fromScale(0.5, 0.5)
	mainFrame.Size = isMobile and UDim2.fromScale(0.92, 0.82) or UDim2.fromScale(0.62, 0.74)
	mainFrame.BackgroundColor3 = COLORS.bg
	mainFrame.BorderSizePixel = 3
	mainFrame.BorderColor3 = COLORS.border
	mainFrame.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.02, 0)
	corner.Parent = mainFrame

	-- Título
	makeLabel(
		mainFrame,
		"🎁 RECOMPENSA DIÁRIA",
		UDim2.fromScale(0.7, 0.08),
		UDim2.fromScale(0.05, 0.02),
		COLORS.gold,
		Enum.Font.Arcade
	)

	-- Botão fechar
	local closeBtn = makeButton(mainFrame, "X", UDim2.fromScale(0.07, 0.07), UDim2.fromScale(0.9, 0.02), COLORS.red)
	closeBtn.TextColor3 = COLORS.text
	closeBtn.MouseButton1Click:Connect(function()
		if _G.CloseDailyRewards then
			_G.CloseDailyRewards()
		end
	end)

	-- Banner de fim de semana (visível só quando ativo)
	local weekendBanner = makeLabel(
		mainFrame,
		"🎉 FIM DE SEMANA: RECOMPENSAS 2X!",
		UDim2.fromScale(0.9, 0.05),
		UDim2.fromScale(0.05, 0.105),
		COLORS.purple,
		Enum.Font.Arcade
	)
	weekendBanner.Name = "WeekendBanner"
	weekendBanner.Visible = false

	-- Linha de status (streak / total)
	local statusLabel = makeLabel(
		mainFrame,
		"",
		UDim2.fromScale(0.9, 0.05),
		UDim2.fromScale(0.05, 0.16),
		COLORS.textDim,
		Enum.Font.Code
	)
	statusLabel.Name = "StatusLabel"

	-- Área dos cards (6 dias em grade 3x2)
	local cardsHolder = Instance.new("Frame")
	cardsHolder.Name = "CardsHolder"
	cardsHolder.Size = UDim2.fromScale(0.9, 0.46)
	cardsHolder.Position = UDim2.fromScale(0.05, 0.225)
	cardsHolder.BackgroundTransparency = 1
	cardsHolder.Parent = mainFrame

	-- Mensagem (pode coletar / tempo restante)
	local messageLabel = makeLabel(
		mainFrame,
		"",
		UDim2.fromScale(0.9, 0.055),
		UDim2.fromScale(0.05, 0.70),
		COLORS.text,
		Enum.Font.Code
	)
	messageLabel.Name = "MessageLabel"

	-- Botão COLETAR
	local claimBtn = makeButton(
		mainFrame,
		"COLETAR",
		UDim2.fromScale(0.42, 0.1),
		UDim2.fromScale(0.05, 0.78),
		COLORS.green
	)
	claimBtn.Name = "ClaimButton"

	-- Botão RECUPERAR DIA
	local recoverBtn = makeButton(
		mainFrame,
		"🔄 RECUPERAR DIA",
		UDim2.fromScale(0.42, 0.1),
		UDim2.fromScale(0.53, 0.78),
		COLORS.gold
	)
	recoverBtn.Name = "RecoverButton"

	-- Rodapé
	makeLabel(
		mainFrame,
		"STREAK: +5% POR DIA CONSECUTIVO · RECUPERAÇÃO: 1X POR SEMANA",
		UDim2.fromScale(0.9, 0.035),
		UDim2.fromScale(0.05, 0.905),
		COLORS.textDim,
		Enum.Font.Code
	)
end

-- =====================================
-- RENDERIZAR STATUS
-- =====================================

local function renderStatus()
	if not mainFrame then
		return
	end

	local ok, status = pcall(function()
		return getDailyRewardStatus:InvokeServer()
	end)

	if not ok or not status then
		mainFrame.MessageLabel.Text = "⚠️ Não foi possível carregar o status. Tente de novo."
		return
	end

	-- Banner de fim de semana
	mainFrame.WeekendBanner.Visible = status.isWeekend and true or false

	-- Status geral
	mainFrame.StatusLabel.Text = string.format(
		"🔥 Streak atual: %d dia(s)   |   📅 Total coletado: %d dia(s)",
		status.currentStreak or 0,
		status.totalDaysClaimed or 0
	)

	-- Limpar cards antigos (Parent = nil, nunca Destroy)
	local holder = mainFrame.CardsHolder
	for _, child in ipairs(holder:GetChildren()) do
		child.Parent = nil
	end

	-- Dia que será coletado a seguir (streak+1, máx 6)
	local nextDay = math.min((status.currentStreak or 0) + 1, 6)

	-- Grade 3x2 de cards
	local cols, rows = 3, 2
	local gapX, gapY = 0.02, 0.04
	local cardW = (1 - gapX * (cols - 1)) / cols
	local cardH = (1 - gapY * (rows - 1)) / rows

	for i, reward in ipairs(status.rewards or {}) do
		local col = (i - 1) % cols
		local row = math.floor((i - 1) / cols)

		local card = Instance.new("Frame")
		card.Name = "Day" .. reward.day
		card.Size = UDim2.fromScale(cardW, cardH)
		card.Position = UDim2.fromScale(col * (cardW + gapX), row * (cardH + gapY))
		card.BorderSizePixel = 2
		card.Parent = holder

		local cc = Instance.new("UICorner")
		cc.CornerRadius = UDim.new(0.08, 0)
		cc.Parent = card

		local claimed = reward.day <= (status.currentStreak or 0)
		local isNext = (reward.day == nextDay) and status.canClaim

		if claimed then
			card.BackgroundColor3 = COLORS.cardClaimed
			card.BorderColor3 = COLORS.green
		elseif isNext then
			card.BackgroundColor3 = COLORS.cardNext
			card.BorderColor3 = COLORS.gold
		else
			card.BackgroundColor3 = COLORS.card
			card.BorderColor3 = COLORS.textDim
		end

		-- Cabeçalho do card
		makeLabel(
			card,
			string.format("DIA %d — %s", reward.day, reward.description or ""),
			UDim2.fromScale(0.9, 0.28),
			UDim2.fromScale(0.05, 0.05),
			isNext and COLORS.gold or COLORS.text,
			Enum.Font.Arcade
		)

		-- Recompensas
		makeLabel(
			card,
			string.format("💰 %d  |  🎯 %d", reward.coins or 0, reward.bounty or 0),
			UDim2.fromScale(0.9, 0.24),
			UDim2.fromScale(0.05, 0.38),
			COLORS.text,
			Enum.Font.Code
		)

		-- Bônus especial (dias 5 e 6) ou status
		local footerText = ""
		local footerColor = COLORS.textDim
		if claimed then
			footerText = "✅ COLETADO"
			footerColor = COLORS.green
		elseif reward.bonus then
			footerText = "⭐ " .. reward.bonus
			footerColor = COLORS.purple
		elseif isNext then
			footerText = "👉 PRÓXIMO"
			footerColor = COLORS.gold
		end
		makeLabel(card, footerText, UDim2.fromScale(0.9, 0.24), UDim2.fromScale(0.05, 0.68), footerColor, Enum.Font.Code)

		-- Pulso na borda do próximo dia
		if isNext then
			task.spawn(function()
				while card.Parent and isOpen do
					TweenService:Create(card, TweenInfo.new(0.5), { BorderColor3 = Color3.fromRGB(255, 255, 255) }):Play()
					task.wait(0.5)
					if not card.Parent then
						break
					end
					TweenService:Create(card, TweenInfo.new(0.5), { BorderColor3 = COLORS.gold }):Play()
					task.wait(0.5)
				end
			end)
		end
	end

	-- Botões
	local claimBtn = mainFrame.ClaimButton
	local recoverBtn = mainFrame.RecoverButton

	if status.canClaim then
		claimBtn.Text = "COLETAR DIA " .. nextDay
		claimBtn.BackgroundColor3 = COLORS.green
		claimBtn.Active = true
		claimBtn.AutoButtonColor = true
		mainFrame.MessageLabel.Text = status.isWeekend and "Recompensa disponível (valores 2x de fim de semana)!"
			or "Recompensa disponível!"
		mainFrame.MessageLabel.TextColor3 = COLORS.green
		stopCountdown()
	else
		claimBtn.Text = "JÁ COLETADO"
		claimBtn.BackgroundColor3 = COLORS.card
		claimBtn.Active = false
		claimBtn.AutoButtonColor = false
		mainFrame.MessageLabel.TextColor3 = COLORS.textDim

		-- Contagem regressiva ao vivo
		stopCountdown()
		local remaining = status.timeUntilNext or 0
		countdownConn = task.spawn(function()
			while remaining > 0 and isOpen and mainFrame and mainFrame.Parent do
				mainFrame.MessageLabel.Text = "⏰ Próxima recompensa em: " .. formatTime(remaining)
				task.wait(1)
				remaining = remaining - 1
			end
			if remaining <= 0 and isOpen then
				renderStatus() -- virou o dia com o menu aberto
			end
		end)
	end

	recoverBtn.Visible = status.canRecover and true or false
end

-- =====================================
-- AÇÕES DOS BOTÕES
-- =====================================

local claiming = false

local function connectButtons()
	mainFrame.ClaimButton.MouseButton1Click:Connect(function()
		if claiming or not mainFrame.ClaimButton.Active then
			return
		end
		claiming = true

		local ok, success, result = pcall(function()
			return claimDailyReward:InvokeServer()
		end)

		if ok and success and typeof(result) == "table" then
			playSound(SOUND_CLAIM)
			mainFrame.MessageLabel.Text = string.format(
				"🎉 +%d moedas  +%d bounty%s",
				result.coins or 0,
				result.bounty or 0,
				result.bonus and ("  ⭐ " .. result.bonus) or ""
			)
			mainFrame.MessageLabel.TextColor3 = COLORS.gold
			if _G.SetMenuNotification then
				_G.SetMenuNotification("DIÁRIA", false)
			end
			task.wait(1.5)
			renderStatus()
		else
			local msg = (ok and typeof(result) == "string" and result) or "Não foi possível coletar agora."
			mainFrame.MessageLabel.Text = "⚠️ " .. tostring(msg)
			mainFrame.MessageLabel.TextColor3 = COLORS.red
		end

		claiming = false
	end)

	mainFrame.RecoverButton.MouseButton1Click:Connect(function()
		local ok, success, msg = pcall(function()
			return recoverLostDay:InvokeServer()
		end)

		if ok and success then
			playSound(SOUND_CLAIM)
			mainFrame.MessageLabel.Text = "🔄 " .. tostring(msg or "Dia recuperado!")
			mainFrame.MessageLabel.TextColor3 = COLORS.gold
			task.wait(1)
			renderStatus()
		else
			mainFrame.MessageLabel.Text = "⚠️ " .. tostring(msg or "Não foi possível recuperar.")
			mainFrame.MessageLabel.TextColor3 = COLORS.red
		end
	end)
end

-- =====================================
-- ABRIR / FECHAR (via Menu Unificado)
-- =====================================

_G.OpenDailyRewards = function()
	buildGui()
	if not mainFrame:FindFirstChild("__connected") then
		local mark = Instance.new("BoolValue")
		mark.Name = "__connected"
		mark.Parent = mainFrame
		connectButtons()
	end
	isOpen = true
	gui.Enabled = true
	playSound(SOUND_OPEN)
	renderStatus()
end

_G.CloseDailyRewards = function()
	isOpen = false
	stopCountdown()
	if gui then
		gui.Enabled = false
	end
end

-- =====================================
-- NOTIFICAÇÃO NO MENU (🔴 quando pode coletar)
-- =====================================

task.spawn(function()
	while true do
		local ok, status = pcall(function()
			return getDailyRewardStatus:InvokeServer()
		end)
		if ok and status and _G.SetMenuNotification then
			_G.SetMenuNotification("DIÁRIA", status.canClaim and true or false)
		end
		task.wait(60)
	end
end)

-- =====================================
-- REGISTRAR NO MENU UNIFICADO (REUTILIZADO)
-- =====================================

task.spawn(function()
	local t = 0
	while not _G.RegisterMenuCategory and t < 20 do
		task.wait(0.3)
		t += 0.3
	end
	if _G.RegisterMenuCategory then
		_G.RegisterMenuCategory("DIÁRIA", "🎁", function()
			_G.OpenDailyRewards()
		end, function()
			_G.CloseDailyRewards()
		end, 4.5)
		print("[DAILY CLIENT V1] ✓ Categoria DIÁRIA registrada no Menu Unificado")
	else
		warn("[DAILY CLIENT V1] ⚠️ Menu Unificado não encontrado — RegisterMenuCategory ausente")
	end
end)

print([[
╔════════════════════════════════════════════════════╗
║  🎁 DAILY REWARDS CLIENT V1 CARREGADO             ║
╠════════════════════════════════════════════════════╣
║  SCRIPT NOVO — a GUI de daily não existia          ║
╠════════════════════════════════════════════════════╣
║  • Grade de 6 dias com estado (coletado/próximo)  ║
║  • Botão COLETAR + contagem regressiva ao vivo    ║
║  • Botão RECUPERAR DIA (quando desbloqueado)      ║
║  • Banner de fim de semana (2x)                   ║
║  • 🔴 Notificação no ☰ quando há coleta pendente  ║
║  • Sem botão próprio — abre pelo Menu Unificado   ║
╠════════════════════════════════════════════════════╣
║  API Global:                                       ║
║  • _G.OpenDailyRewards()                          ║
║  • _G.CloseDailyRewards()                         ║
╚════════════════════════════════════════════════════╝
]])
