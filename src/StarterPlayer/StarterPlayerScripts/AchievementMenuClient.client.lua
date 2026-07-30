-- ============================================
-- ACHIEVEMENT MENU CLIENT V2 — CONQUISTAS (RETRO)
-- Coloque em StarterPlayer > StarterPlayerScripts
-- Nome: "AchievementMenuClient"
-- SUBSTITUI: AchievementMenuClient V1
-- REMOVER:   AchievementMenuClient V1
-- ============================================
-- (V2) CORREÇÕES E ATUALIZAÇÕES:
-- • CORRIGIDO: a linha de prêmio mostrava "Prêmio: nil" quando a
--   conquista não tinha personagem-prêmio — agora só aparece se
--   houver prêmio configurado.
-- • NOVO botão "🔄" no cabeçalho pra atualizar o progresso sem
--   fechar e abrir o menu.
-- • Popup de desbloqueio agora trata os 3 casos do servidor V2:
--   ganhou o personagem / já possuía / prêmio configurado não
--   existe no catálogo (avisa pra chamar um admin).
-- • NOVO (só admins): botão "⚙️" abre o GERENCIADOR DE CONQUISTAS
--   — lista com REMOVER (dupla confirmação) + formulário pra
--   criar/editar (mesmo nome = edita): Nome, Descrição, Ícone,
--   Stat (botões), Meta, Personagem-prêmio (opcional, nome do
--   catálogo) e Badge ID real (opcional). Tudo pelo jogo, sem
--   Studio, sincronizado em todos os servidores pelo
--   AchievementSystemServer_V2.
--
-- REUTILIZADO:
-- • COLORS, sons+playSound, makeButton/makeLabel, showNotification,
--   detecção mobile, popup de resultado ...... TradeMenuClient_V1 / DuelMenuClient_V1
-- • label/button/textBox do formulário admin + dupla confirmação
--   de REMOVER ................................ AdminMenuClient_V8 (aba Catálogo)
-- • _G.RegisterMenuCategory / _G.SetMenuNotification .. UnifiedMenuClient_V3
-- • ADMIN_IDS ................................. AdminSystemServer_V6
-- ============================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

-- ⚠️ Mesma lista do AdminSystemServer_V6 — só controla a EXIBIÇÃO do
-- botão ⚙️; o servidor revalida e kicka não-autorizados de qualquer jeito
local ADMIN_IDS = { 1595442496, 5267573066,1090315746 }
local isAdminUser = table.find(ADMIN_IDS, player.UserId) ~= nil

-- =====================================
-- REMOTES
-- =====================================

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local getAchievementsRemote = remotes:WaitForChild("GetAchievements", 15)
local achievementUnlockedRemote = remotes:WaitForChild("AchievementUnlocked", 15)
-- (V2) remotes admin
local adminAchSet = remotes:WaitForChild("AdminAchievementSet", 15)
local adminAchRemove = remotes:WaitForChild("AdminAchievementRemove", 15)
local adminAchList = remotes:WaitForChild("AdminAchievementList", 15)

if not getAchievementsRemote then
	warn("[ACHIEVEMENT CLIENT V2] Remotes ausentes — AchievementSystemServer V2 está no ServerScriptService?")
	return
end

-- =====================================
-- SONS (REUTILIZADOS do DuelMenuClient_V1)
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

-- =====================================
-- CORES (REUTILIZADAS do TradeMenuClient_V1)
-- =====================================

local COLORS = {
	background = Color3.fromRGB(20, 20, 20),
	panel = Color3.fromRGB(30, 30, 30),
	header = Color3.fromRGB(40, 40, 40),
	border = Color3.fromRGB(255, 255, 255),
	success = Color3.fromRGB(0, 200, 0),
	error = Color3.fromRGB(200, 0, 0),
	gold = Color3.fromRGB(255, 200, 0),
	locked = Color3.fromRGB(90, 90, 90),
	progress = Color3.fromRGB(0, 255, 170),
	admin = Color3.fromRGB(0, 130, 200),
}

-- =====================================
-- (V2) STATS DISPONÍVEIS pro formulário admin
-- (mesmas chaves do VALID_STATS do AchievementSystemServer_V2)
-- =====================================

local STAT_OPTIONS = {
	{ key = "kills_total", label = "Kills" },
	{ key = "deaths", label = "Mortes" },
	{ key = "duels_won", label = "Duelos" },
	{ key = "hunts", label = "Caçadas" },
	{ key = "trades_completed", label = "Trocas" },
	{ key = "coins_earned_total", label = "Moedas" },
	{ key = "characters_bought", label = "Compras" },
	{ key = "characters_sold", label = "Vendas" },
	{ key = "bounty", label = "Bounty" },
}

-- =====================================
-- NOTIFICAÇÃO + FÁBRICAS (REUTILIZADAS do DuelMenuClient_V1 / AdminMenuClient_V8)
-- =====================================

local function showNotification(message, isSuccess)
	playSound(isSuccess and sounds.purchase or sounds.error)
	local notification = Instance.new("ScreenGui")
	notification.Name = "AchievementNotification"
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

local function makeTextBox(parent, placeholder, size, pos, default)
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

-- =====================================
-- TELA 1: LISTA DE CONQUISTAS (AchievementList)
-- =====================================

local openAchievementAdmin -- forward declaration (V2)

local function buildAchievementRow(parent, ach)
	local claimed = ach.claimed == true
	local current = math.min(ach.current or 0, ach.amount)
	local pct = math.clamp((ach.current or 0) / ach.amount, 0, 1)

	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, -8, 0, isMobile and 96 or 80)
	row.BackgroundColor3 = COLORS.header
	row.BorderColor3 = claimed and COLORS.gold or COLORS.border
	row.BorderSizePixel = claimed and 2 or 1
	row.Parent = parent

	-- Ícone + nome
	makeLabel(
		row,
		(ach.icon or "🏆") .. " " .. ach.name,
		UDim2.new(0.7, 0, 0.32, 0),
		UDim2.new(0.02, 0, 0.04, 0),
		claimed and COLORS.gold or Color3.new(1, 1, 1),
		Enum.Font.Arcade
	)

	-- Status
	makeLabel(
		row,
		claimed and "✅ DESBLOQUEADA" or "🔒 BLOQUEADA",
		UDim2.new(0.28, 0, 0.3, 0),
		UDim2.new(0.7, 0, 0.04, 0),
		claimed and COLORS.success or COLORS.locked,
		Enum.Font.Code
	)

	-- (V2) Descrição + prêmio SÓ quando existe prêmio configurado
	local rewardTxt = ""
	if ach.rewardCharacter and ach.rewardCharacter ~= "" then
		rewardTxt = "  •  Prêmio: " .. ach.rewardCharacter
	end
	makeLabel(
		row,
		ach.desc .. rewardTxt,
		UDim2.new(0.96, 0, 0.26, 0),
		UDim2.new(0.02, 0, 0.38, 0),
		Color3.fromRGB(200, 200, 200),
		Enum.Font.Code
	)

	-- Barra de progresso
	local barBg = Instance.new("Frame")
	barBg.Size = UDim2.new(0.72, 0, 0.18, 0)
	barBg.Position = UDim2.new(0.02, 0, 0.72, 0)
	barBg.BackgroundColor3 = COLORS.panel
	barBg.BorderColor3 = COLORS.border
	barBg.BorderSizePixel = 1
	barBg.Parent = row

	local barFill = Instance.new("Frame")
	barFill.Size = UDim2.new(pct, 0, 1, 0)
	barFill.BackgroundColor3 = claimed and COLORS.gold or COLORS.progress
	barFill.BorderSizePixel = 0
	barFill.Parent = barBg

	makeLabel(
		row,
		current .. " / " .. ach.amount,
		UDim2.new(0.22, 0, 0.18, 0),
		UDim2.new(0.76, 0, 0.72, 0),
		Color3.new(1, 1, 1),
		Enum.Font.Code
	)

	return row
end

local function openAchievementList()
	local old = playerGui:FindFirstChild("AchievementList")
	if old then
		old.Parent = nil
	end

	playSound(sounds.open)

	local gui = Instance.new("ScreenGui")
	gui.Name = "AchievementList"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 60
	gui.Parent = playerGui

	local mainFrame = Instance.new("Frame")
	mainFrame.Size = isMobile and UDim2.new(0.92, 0, 0.8, 0) or UDim2.new(0.5, 0, 0.7, 0)
	mainFrame.Position = isMobile and UDim2.new(0.04, 0, 0.1, 0) or UDim2.new(0.25, 0, 0.15, 0)
	mainFrame.BackgroundColor3 = COLORS.background
	mainFrame.BorderColor3 = COLORS.border
	mainFrame.BorderSizePixel = 3
	mainFrame.Parent = gui

	local header = Instance.new("Frame")
	header.Size = UDim2.new(1, 0, 0.1, 0)
	header.BackgroundColor3 = COLORS.header
	header.BorderSizePixel = 0
	header.Parent = mainFrame

	makeLabel(header, "🏆 CONQUISTAS", UDim2.new(0.5, 0, 1, 0), UDim2.new(0.02, 0, 0, 0), COLORS.gold, Enum.Font.Arcade)

	-- (V2) botão ⚙️ só para admins — abre o gerenciador
	if isAdminUser then
		local adminBtn = makeButton(header, "⚙️", COLORS.admin, UDim2.new(0.1, 0, 0.8, 0), UDim2.new(0.54, 0, 0.1, 0))
		adminBtn.MouseButton1Click:Connect(function()
			gui.Parent = nil
			openAchievementAdmin()
		end)
	end

	-- (V2) botão 🔄 atualizar
	local refreshBtn = makeButton(header, "🔄", COLORS.panel, UDim2.new(0.1, 0, 0.8, 0), UDim2.new(0.66, 0, 0.1, 0))

	local closeBtn = makeButton(header, "X", COLORS.error, UDim2.new(0.1, 0, 0.8, 0), UDim2.new(0.88, 0, 0.1, 0))
	closeBtn.MouseButton1Click:Connect(function()
		playSound(sounds.close)
		gui.Parent = nil
	end)

	local countLabel = makeLabel(
		mainFrame,
		"Carregando...",
		UDim2.new(0.96, 0, 0.06, 0),
		UDim2.new(0.02, 0, 0.11, 0),
		COLORS.progress,
		Enum.Font.Code
	)

	local listScroll = Instance.new("ScrollingFrame")
	listScroll.Size = UDim2.new(0.96, 0, 0.8, 0)
	listScroll.Position = UDim2.new(0.02, 0, 0.18, 0)
	listScroll.BackgroundColor3 = COLORS.panel
	listScroll.BorderColor3 = COLORS.border
	listScroll.BorderSizePixel = 2
	listScroll.ScrollBarThickness = 6
	listScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
	listScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	listScroll.Parent = mainFrame

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = listScroll

	local function loadList()
		for _, child in pairs(listScroll:GetChildren()) do
			if child:IsA("Frame") then
				child.Parent = nil
			end
		end

		local ok, list = pcall(function()
			return getAchievementsRemote:InvokeServer()
		end)

		if not ok or type(list) ~= "table" then
			countLabel.Text = "Erro ao carregar conquistas."
			return
		end

		local unlocked = 0
		for _, ach in ipairs(list) do
			if ach.claimed then
				unlocked += 1
			end
			buildAchievementRow(listScroll, ach)
		end

		countLabel.Text = string.format("Desbloqueadas: %d / %d", unlocked, #list)
	end

	refreshBtn.MouseButton1Click:Connect(loadList)
	loadList()
end

_G.OpenAchievementList = openAchievementList

-- =====================================
-- (V2) TELA ADMIN: GERENCIADOR DE CONQUISTAS
-- (padrão de lista+REMOVER+formulário REUTILIZADO do AdminMenuClient_V8)
-- =====================================

openAchievementAdmin = function()
	local old = playerGui:FindFirstChild("AchievementAdmin")
	if old then
		old.Parent = nil
	end

	playSound(sounds.open)

	local gui = Instance.new("ScreenGui")
	gui.Name = "AchievementAdmin"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 65
	gui.Parent = playerGui

	local mainFrame = Instance.new("Frame")
	mainFrame.Size = isMobile and UDim2.new(0.94, 0, 0.85, 0) or UDim2.new(0.55, 0, 0.78, 0)
	mainFrame.Position = isMobile and UDim2.new(0.03, 0, 0.07, 0) or UDim2.new(0.225, 0, 0.11, 0)
	mainFrame.BackgroundColor3 = COLORS.background
	mainFrame.BorderColor3 = COLORS.admin
	mainFrame.BorderSizePixel = 3
	mainFrame.Parent = gui

	local header = Instance.new("Frame")
	header.Size = UDim2.new(1, 0, 0.1, 0)
	header.BackgroundColor3 = COLORS.header
	header.BorderSizePixel = 0
	header.Parent = mainFrame

	makeLabel(header, "⚙️ GERENCIAR CONQUISTAS", UDim2.new(0.7, 0, 1, 0), UDim2.new(0.02, 0, 0, 0), COLORS.admin, Enum.Font.Arcade)

	local closeBtn = makeButton(header, "X", COLORS.error, UDim2.new(0.1, 0, 0.8, 0), UDim2.new(0.88, 0, 0.1, 0))
	closeBtn.MouseButton1Click:Connect(function()
		playSound(sounds.close)
		gui.Parent = nil
		openAchievementList()
	end)

	local content = Instance.new("Frame")
	content.Size = UDim2.new(0.98, 0, 0.88, 0)
	content.Position = UDim2.new(0.01, 0, 0.11, 0)
	content.BackgroundTransparency = 1
	content.Parent = mainFrame

	local currentView = "list" -- list | form
	local formDraft = {}
	local renderView -- forward declaration

	local function resetDraft()
		formDraft = {
			name = "",
			desc = "",
			icon = "🏆",
			stat = "kills_total",
			amount = "",
			rewardCharacter = "",
			realBadgeId = "",
		}
	end
	resetDraft()

	local function clearContent()
		for _, child in pairs(content:GetChildren()) do
			child.Parent = nil
		end
	end

	-- ---------- VIEW: LISTA ----------

	local function renderList()
		local newBtn = makeButton(content, "+ NOVA / EDITAR CONQUISTA", COLORS.success, UDim2.new(0.96, 0, 0.08, 0), UDim2.new(0.02, 0, 0, 0))
		newBtn.MouseButton1Click:Connect(function()
			resetDraft()
			currentView = "form"
			renderView()
		end)

		makeLabel(content, "Usar o MESMO NOME de uma existente = editar.", UDim2.new(0.96, 0, 0.045, 0), UDim2.new(0.02, 0, 0.09, 0), Color3.fromRGB(170, 170, 170))

		local listScroll = Instance.new("ScrollingFrame")
		listScroll.Size = UDim2.new(0.96, 0, 0.84, 0)
		listScroll.Position = UDim2.new(0.02, 0, 0.15, 0)
		listScroll.BackgroundColor3 = COLORS.panel
		listScroll.BorderColor3 = COLORS.border
		listScroll.BorderSizePixel = 2
		listScroll.ScrollBarThickness = 8
		listScroll.Parent = content

		local ok, list = pcall(function()
			return adminAchList:InvokeServer()
		end)

		local yPos = 5
		if ok and type(list) == "table" and #list > 0 then
			for _, ach in ipairs(list) do
				local row = Instance.new("Frame")
				row.Size = UDim2.new(0.97, 0, 0, 46)
				row.Position = UDim2.new(0.015, 0, 0, yPos)
				row.BackgroundColor3 = COLORS.header
				row.BorderColor3 = COLORS.border
				row.BorderSizePixel = 1
				row.Parent = listScroll

				local rewardTxt = (ach.rewardCharacter ~= "" and (" | 🎖️ " .. ach.rewardCharacter)) or ""
				makeLabel(
					row,
					string.format("%s %s (%s ≥ %d)%s", ach.icon or "🏆", ach.name, ach.stat, ach.amount, rewardTxt),
					UDim2.new(0.65, 0, 1, 0),
					UDim2.new(0.02, 0, 0, 0),
					Color3.new(1, 1, 1),
					Enum.Font.Code
				)

				-- Dupla confirmação (padrão REUTILIZADO do AdminMenuClient_V8)
				local removeBtn = makeButton(row, "REMOVER", COLORS.error, UDim2.new(0.3, 0, 0.8, 0), UDim2.new(0.68, 0, 0.1, 0))
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
						return adminAchRemove:InvokeServer(ach.id)
					end)
					showNotification(okr and (msg or "Removida!") or "Erro ao remover!", okr and success)
					renderView()
				end)

				yPos = yPos + 50
			end
		else
			makeLabel(listScroll, "Nenhuma conquista encontrada.", UDim2.new(0.9, 0, 0, 30), UDim2.new(0.02, 0, 0, 5), Color3.fromRGB(150, 150, 150))
			yPos = 40
		end

		listScroll.CanvasSize = UDim2.new(0, 0, 0, yPos + 10)
	end

	-- ---------- VIEW: FORMULÁRIO ----------

	local function renderForm()
		makeLabel(content, "[ NOVA / EDITAR CONQUISTA ]", UDim2.new(1, 0, 0.055, 0), UDim2.new(0, 0, 0, 0), COLORS.admin, Enum.Font.Arcade)

		makeLabel(content, "NOME:", UDim2.new(0.2, 0, 0.05, 0), UDim2.new(0.02, 0, 0.07, 0))
		local nameBox = makeTextBox(content, "Ex: LENDÁRIO", UDim2.new(0.74, 0, 0.05, 0), UDim2.new(0.24, 0, 0.07, 0), formDraft.name)
		nameBox:GetPropertyChangedSignal("Text"):Connect(function()
			formDraft.name = nameBox.Text
		end)

		makeLabel(content, "DESCRIÇÃO:", UDim2.new(0.2, 0, 0.05, 0), UDim2.new(0.02, 0, 0.14, 0))
		local descBox = makeTextBox(content, "Ex: Elimine 500 jogadores", UDim2.new(0.74, 0, 0.05, 0), UDim2.new(0.24, 0, 0.14, 0), formDraft.desc)
		descBox:GetPropertyChangedSignal("Text"):Connect(function()
			formDraft.desc = descBox.Text
		end)

		makeLabel(content, "ÍCONE:", UDim2.new(0.2, 0, 0.05, 0), UDim2.new(0.02, 0, 0.21, 0))
		local iconBox = makeTextBox(content, "1 emoji (ex: 👑)", UDim2.new(0.3, 0, 0.05, 0), UDim2.new(0.24, 0, 0.21, 0), formDraft.icon)
		iconBox:GetPropertyChangedSignal("Text"):Connect(function()
			formDraft.icon = iconBox.Text
		end)

		makeLabel(content, "META:", UDim2.new(0.12, 0, 0.05, 0), UDim2.new(0.58, 0, 0.21, 0))
		local amountBox = makeTextBox(content, "Ex: 500", UDim2.new(0.27, 0, 0.05, 0), UDim2.new(0.71, 0, 0.21, 0), formDraft.amount)
		amountBox:GetPropertyChangedSignal("Text"):Connect(function()
			formDraft.amount = amountBox.Text
		end)

		makeLabel(content, "STAT (o que a meta conta):", UDim2.new(0.7, 0, 0.045, 0), UDim2.new(0.02, 0, 0.29, 0))
		for i, opt in ipairs(STAT_OPTIONS) do
			local col = (i - 1) % 3
			local row = math.floor((i - 1) / 3)
			local btn = makeButton(
				content,
				opt.label,
				formDraft.stat == opt.key and COLORS.admin or COLORS.panel,
				UDim2.new(0.3, 0, 0.055, 0),
				UDim2.new(0.02 + col * 0.325, 0, 0.35 + row * 0.07, 0)
			)
			btn.MouseButton1Click:Connect(function()
				formDraft.stat = opt.key
				renderView()
			end)
		end

		makeLabel(content, "PERSONAGEM-PRÊMIO (opcional):", UDim2.new(0.55, 0, 0.045, 0), UDim2.new(0.02, 0, 0.58, 0))
		local rewardBox = makeTextBox(content, "Nome exato do catálogo (vazio = sem prêmio)", UDim2.new(0.96, 0, 0.05, 0), UDim2.new(0.02, 0, 0.63, 0), formDraft.rewardCharacter)
		rewardBox:GetPropertyChangedSignal("Text"):Connect(function()
			formDraft.rewardCharacter = rewardBox.Text
		end)

		makeLabel(content, "BADGE ID REAL (opcional):", UDim2.new(0.5, 0, 0.045, 0), UDim2.new(0.02, 0, 0.7, 0))
		local badgeBox = makeTextBox(content, "0 = não premiar Badge do Roblox", UDim2.new(0.44, 0, 0.05, 0), UDim2.new(0.54, 0, 0.7, 0), formDraft.realBadgeId)
		badgeBox:GetPropertyChangedSignal("Text"):Connect(function()
			formDraft.realBadgeId = badgeBox.Text
		end)

		local backBtn = makeButton(content, "◀ VOLTAR", COLORS.panel, UDim2.new(0.3, 0, 0.08, 0), UDim2.new(0.02, 0, 0.88, 0))
		backBtn.MouseButton1Click:Connect(function()
			currentView = "list"
			renderView()
		end)

		local saveBtn = makeButton(content, "✅ SALVAR", COLORS.success, UDim2.new(0.4, 0, 0.08, 0), UDim2.new(0.58, 0, 0.88, 0))
		local saving = false
		saveBtn.MouseButton1Click:Connect(function()
			if saving then
				return
			end
			if formDraft.name == "" or formDraft.desc == "" then
				showNotification("Nome e descrição são obrigatórios!", false)
				return
			end
			if not tonumber(formDraft.amount) or tonumber(formDraft.amount) < 1 then
				showNotification("Meta deve ser um número maior que 0!", false)
				return
			end

			saving = true
			saveBtn.Text = "SALVANDO..."

			local payload = {
				name = formDraft.name,
				desc = formDraft.desc,
				icon = formDraft.icon ~= "" and formDraft.icon or "🏆",
				stat = formDraft.stat,
				amount = tonumber(formDraft.amount),
				rewardCharacter = formDraft.rewardCharacter,
				realBadgeId = tonumber(formDraft.realBadgeId) or 0,
			}

			task.spawn(function()
				local ok, success, msg = pcall(function()
					return adminAchSet:InvokeServer(payload)
				end)

				showNotification(ok and (msg or "Salva!") or "Erro de comunicação com o servidor!", ok and success)
				saving = false

				if ok and success then
					currentView = "list"
				end
				renderView()
			end)
		end)
	end

	renderView = function()
		clearContent()
		if currentView == "list" then
			renderList()
		else
			renderForm()
		end
	end

	renderView()
end

-- =====================================
-- TELA 2: POPUP "CONQUISTA DESBLOQUEADA!"
-- (mesma estrutura da tela de resultado do DuelMenuClient_V1)
-- =====================================

local function showUnlockPopup(info)
	if not info then
		return
	end

	playSound(sounds.purchase)
	if _G.SetMenuNotification then
		_G.SetMenuNotification("CONQUISTAS", true)
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = "AchievementUnlockGui"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 131
	gui.IgnoreGuiInset = true
	gui.Parent = playerGui

	local frame = Instance.new("Frame")
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(0.5, 0.3)
	frame.Size = isMobile and UDim2.fromScale(0.85, 0.26) or UDim2.fromScale(0.45, 0.24)
	frame.BackgroundColor3 = COLORS.background
	frame.BorderColor3 = COLORS.gold
	frame.BorderSizePixel = 4
	frame.Parent = gui

	makeLabel(frame, "🏆 CONQUISTA DESBLOQUEADA!", UDim2.fromScale(1, 0.26), UDim2.fromScale(0, 0.06), COLORS.gold, Enum.Font.Arcade)
	makeLabel(
		frame,
		(info.icon or "") .. " " .. (info.name or ""),
		UDim2.fromScale(0.9, 0.22),
		UDim2.fromScale(0.05, 0.34),
		Color3.new(1, 1, 1),
		Enum.Font.Arcade
	)

	-- (V2) Trata os 3 casos do servidor
	local rewardText
	local rewardColor = COLORS.progress
	if info.gotCharacter then
		rewardText = "Personagem desbloqueado: " .. tostring(info.rewardCharacter) .. " 🎖️"
	elseif info.rewardMissing then
		rewardText = "⚠️ Prêmio '" .. tostring(info.rewardCharacter) .. "' não está no catálogo — avise um admin!"
		rewardColor = COLORS.gold
	elseif info.rewardCharacter and info.rewardCharacter ~= "" then
		rewardText = "Prêmio: " .. tostring(info.rewardCharacter) .. " (já estava no seu inventário)"
	else
		rewardText = info.desc or ""
	end
	makeLabel(frame, rewardText, UDim2.fromScale(0.9, 0.2), UDim2.fromScale(0.05, 0.58), rewardColor, Enum.Font.Code)

	-- Brilho pulsante na borda
	task.spawn(function()
		for _ = 1, 6 do
			if not frame.Parent then
				break
			end
			TweenService:Create(frame, TweenInfo.new(0.4), { BorderColor3 = Color3.fromRGB(255, 255, 255) }):Play()
			task.wait(0.4)
			TweenService:Create(frame, TweenInfo.new(0.4), { BorderColor3 = COLORS.gold }):Play()
			task.wait(0.4)
		end
	end)

	task.delay(5, function()
		if gui and gui.Parent then
			gui.Parent = nil
		end
		if _G.SetMenuNotification then
			_G.SetMenuNotification("CONQUISTAS", false)
		end
	end)
end

achievementUnlockedRemote.OnClientEvent:Connect(showUnlockPopup)

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
		_G.RegisterMenuCategory("CONQUISTAS", "🏆", function()
			openAchievementList()
		end, function()
			local g = playerGui:FindFirstChild("AchievementList")
			if g then
				g.Parent = nil
			end
			local a = playerGui:FindFirstChild("AchievementAdmin")
			if a then
				a.Parent = nil
			end
		end, 5.5)
		print("[ACHIEVEMENT CLIENT V2] Categoria CONQUISTAS registrada no menu")
	end
end)

print([[
╔════════════════════════════════════════════════════╗
║  🏆 ACHIEVEMENT MENU CLIENT V2 CARREGADO          ║
╠════════════════════════════════════════════════════╣
║  SUBSTITUI: AchievementMenuClient V1               ║
║  REMOVER:   AchievementMenuClient V1               ║
╠════════════════════════════════════════════════════╣
║  * Fix "Prêmio: nil" • botão 🔄 atualizar          ║
║  * Popup trata prêmio ganho/já possuído/ausente    ║
║  * ⚙️ (só admin): criar/editar/remover conquistas  ║
║    pelo jogo, sem Studio                           ║
╚════════════════════════════════════════════════════╝
]])
