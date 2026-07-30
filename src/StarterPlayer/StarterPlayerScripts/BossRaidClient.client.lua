-- ============================================
-- MENU DE BOSS RAID V2 (CLIENTE)
-- Coloque em StarterPlayer > StarterPlayerScripts
-- Nome: "BossRaidClient"
-- SUBSTITUI: BossRaidClient_V1  ⚠️ REMOVER V1
-- ============================================
-- (V2) ALTERAÇÕES:
-- • MODO EDITOR ADMIN: registrar Place IDs e configurar
--   requisitos das raids pelo jogo (sem Studio)
-- • Aviso quando o jogador não tem personagem equipado
-- • Bosses agora vêm do catálogo dinâmico do servidor
-- ============================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local getBossListRemote = remotes:WaitForChild("GetBossList")
local createRaidRemote = remotes:WaitForChild("CreateRaid")
local startRaidRemote = remotes:WaitForChild("StartRaidCountdown")
local cancelRaidRemote = remotes:WaitForChild("CancelRaid")
local leaveRaidRemote = remotes:WaitForChild("LeaveRaid")
local inviteToRaidRemote = remotes:WaitForChild("InviteToRaid")
local respondRaidInviteRemote = remotes:WaitForChild("RespondRaidInvite")
local requestJoinRaidRemote = remotes:WaitForChild("RequestJoinRaid")
local respondJoinRequestRemote = remotes:WaitForChild("RespondJoinRequest")
local raidStateUpdateRemote = remotes:WaitForChild("RaidStateUpdate")
local raidNotifyRemote = remotes:WaitForChild("RaidNotify")
local adminSaveBossRemote = remotes:WaitForChild("AdminSaveBoss")
local adminRemoveBossRemote = remotes:WaitForChild("AdminRemoveBoss")
local adminGetBossCatalogRemote = remotes:WaitForChild("AdminGetBossCatalog")

-- =====================================
-- ESTADO LOCAL
-- =====================================

local currentData = nil
local menuOpen = false
local viewMode = "player" -- "player" | "editor" | "editForm"
local editingBoss = nil -- boss em edição no formulário (nil = novo)

-- =====================================
-- CORES / ESTILO RETRO
-- =====================================

local COLORS = {
	BG = Color3.fromRGB(20, 20, 30),
	PANEL = Color3.fromRGB(35, 35, 50),
	ACCENT = Color3.fromRGB(255, 80, 80),
	GREEN = Color3.fromRGB(0, 200, 100),
	RED = Color3.fromRGB(220, 60, 60),
	YELLOW = Color3.fromRGB(255, 200, 0),
	BLUE = Color3.fromRGB(80, 80, 160),
	TEXT = Color3.fromRGB(255, 255, 255),
	TEXT_DIM = Color3.fromRGB(180, 180, 190),
}

-- =====================================
-- GUI BASE
-- =====================================

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "BossRaidMenu"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Enabled = false
screenGui.Parent = playerGui

local mainFrame = Instance.new("Frame")
mainFrame.Name = "MainFrame"
mainFrame.Size = UDim2.new(0.6, 0, 0.72, 0)
mainFrame.Position = UDim2.new(0.2, 0, 0.14, 0)
mainFrame.BackgroundColor3 = COLORS.BG
mainFrame.BorderSizePixel = 0
mainFrame.Parent = screenGui

local mainCorner = Instance.new("UICorner")
mainCorner.CornerRadius = UDim.new(0.02, 0)
mainCorner.Parent = mainFrame

local title = Instance.new("TextLabel")
title.Size = UDim2.new(0.6, 0, 0.1, 0)
title.Position = UDim2.new(0.02, 0, 0, 0)
title.BackgroundTransparency = 1
title.Text = "👹 BOSS RAID"
title.TextColor3 = COLORS.ACCENT
title.Font = Enum.Font.Arcade
title.TextScaled = true
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = mainFrame

-- Botão de alternar EDITOR (só visível para admins)
local editorToggleBtn = Instance.new("TextButton")
editorToggleBtn.Size = UDim2.new(0.3, 0, 0.07, 0)
editorToggleBtn.Position = UDim2.new(0.66, 0, 0.015, 0)
editorToggleBtn.BackgroundColor3 = COLORS.BLUE
editorToggleBtn.Text = "⚙️ EDITOR"
editorToggleBtn.TextColor3 = COLORS.TEXT
editorToggleBtn.Font = Enum.Font.Arcade
editorToggleBtn.TextScaled = true
editorToggleBtn.Visible = false
editorToggleBtn.Parent = mainFrame

local togCorner = Instance.new("UICorner")
togCorner.CornerRadius = UDim.new(0.2, 0)
togCorner.Parent = editorToggleBtn

local contentFrame = Instance.new("ScrollingFrame")
contentFrame.Name = "Content"
contentFrame.Size = UDim2.new(0.94, 0, 0.86, 0)
contentFrame.Position = UDim2.new(0.03, 0, 0.11, 0)
contentFrame.BackgroundTransparency = 1
contentFrame.BorderSizePixel = 0
contentFrame.ScrollBarThickness = 6
contentFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
contentFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
contentFrame.Parent = mainFrame

local listLayout = Instance.new("UIListLayout")
listLayout.Padding = UDim.new(0.01, 0)
listLayout.SortOrder = Enum.SortOrder.LayoutOrder
listLayout.Parent = contentFrame

-- =====================================
-- CONTAGEM REGRESSIVA (tela)
-- =====================================

local countdownGui = Instance.new("ScreenGui")
countdownGui.Name = "RaidCountdownGui"
countdownGui.ResetOnSpawn = false
countdownGui.Enabled = false
countdownGui.Parent = playerGui

local countdownLabel = Instance.new("TextLabel")
countdownLabel.Size = UDim2.new(0.5, 0, 0.15, 0)
countdownLabel.Position = UDim2.new(0.25, 0, 0.08, 0)
countdownLabel.BackgroundColor3 = COLORS.BG
countdownLabel.BackgroundTransparency = 0.3
countdownLabel.Text = ""
countdownLabel.TextColor3 = COLORS.YELLOW
countdownLabel.Font = Enum.Font.Arcade
countdownLabel.TextScaled = true
countdownLabel.Parent = countdownGui

local cdCorner = Instance.new("UICorner")
cdCorner.CornerRadius = UDim.new(0.1, 0)
cdCorner.Parent = countdownLabel

local countdownActive = false

local function runCountdownDisplay(endsAt, bossName)
	if countdownActive then
		return
	end
	countdownActive = true
	countdownGui.Enabled = true

	task.spawn(function()
		while countdownActive do
			local remaining = math.ceil(endsAt - os.clock())
			if remaining <= 0 then
				countdownLabel.Text = "👹 ENTRANDO NA RAID..."
				task.wait(3)
				break
			end
			countdownLabel.Text = string.format("⏱️ %s — %d", bossName or "RAID", remaining)
			task.wait(0.2)
		end
		countdownActive = false
		countdownGui.Enabled = false
	end)
end

local function stopCountdownDisplay()
	countdownActive = false
	countdownGui.Enabled = false
end

-- =====================================
-- NOTIFICAÇÕES
-- =====================================

local notifyGui = Instance.new("ScreenGui")
notifyGui.Name = "RaidNotifyGui"
notifyGui.ResetOnSpawn = false
notifyGui.Parent = playerGui

local function showNotification(message, success)
	local frame = Instance.new("TextLabel")
	frame.Size = UDim2.new(0.4, 0, 0.06, 0)
	frame.Position = UDim2.new(0.3, 0, -0.1, 0)
	frame.BackgroundColor3 = success and COLORS.GREEN or COLORS.RED
	frame.Text = message
	frame.TextColor3 = COLORS.TEXT
	frame.Font = Enum.Font.Code
	frame.TextScaled = true
	frame.Parent = notifyGui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.2, 0)
	corner.Parent = frame

	TweenService:Create(frame, TweenInfo.new(0.3), { Position = UDim2.new(0.3, 0, 0.03, 0) }):Play()

	task.delay(4, function()
		local tweenOut = TweenService:Create(frame, TweenInfo.new(0.3), { Position = UDim2.new(0.3, 0, -0.1, 0) })
		tweenOut:Play()
		tweenOut.Completed:Wait()
		frame.Parent = nil
	end)
end

raidNotifyRemote.OnClientEvent:Connect(showNotification)

-- =====================================
-- HELPERS DE UI
-- =====================================

local function clearContent()
	for _, child in ipairs(contentFrame:GetChildren()) do
		if child:IsA("Frame") then
			child.Parent = nil
		end
	end
end

local function makePanel(heightScale, order)
	local panel = Instance.new("Frame")
	panel.Size = UDim2.new(1, 0, heightScale, 0)
	panel.BackgroundColor3 = COLORS.PANEL
	panel.BorderSizePixel = 0
	panel.LayoutOrder = order or 0
	panel.Parent = contentFrame

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.05, 0)
	corner.Parent = panel

	return panel
end

local function makeButton(parent, text, color, size, pos)
	local btn = Instance.new("TextButton")
	btn.Size = size
	btn.Position = pos
	btn.BackgroundColor3 = color
	btn.Text = text
	btn.TextColor3 = COLORS.TEXT
	btn.Font = Enum.Font.Arcade
	btn.TextScaled = true
	btn.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.2, 0)
	corner.Parent = btn

	return btn
end

local function makeLabel(parent, text, size, pos, color, font)
	local lbl = Instance.new("TextLabel")
	lbl.Size = size
	lbl.Position = pos
	lbl.BackgroundTransparency = 1
	lbl.Text = text
	lbl.TextColor3 = color or COLORS.TEXT
	lbl.Font = font or Enum.Font.Code
	lbl.TextScaled = true
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.Parent = parent
	return lbl
end

local function makeTextBox(parent, placeholder, text, size, pos)
	local box = Instance.new("TextBox")
	box.Size = size
	box.Position = pos
	box.BackgroundColor3 = COLORS.BG
	box.PlaceholderText = placeholder
	box.Text = text or ""
	box.TextColor3 = COLORS.TEXT
	box.Font = Enum.Font.Code
	box.TextScaled = true
	box.ClearTextOnFocus = false
	box.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.15, 0)
	corner.Parent = box

	return box
end

-- =====================================
-- FETCH
-- =====================================

local refreshMenu -- forward declaration

local function fetchData()
	local success, data = pcall(function()
		return getBossListRemote:InvokeServer()
	end)
	if success and data then
		currentData = data
	end
	return currentData
end

-- =====================================
-- VISÃO DO JOGADOR
-- =====================================

local function renderMyRaid(raid, order)
	local isLeader = (raid.leader == player.Name)
	local requestCount = #raid.requests
	local heightScale = 0.42 + (isLeader and requestCount * 0.07 or 0)
	local panel = makePanel(heightScale, order)

	makeLabel(panel, string.format("%s SUA RAID: %s", raid.bossIcon, raid.bossName), UDim2.new(0.9, 0, 0.14, 0), UDim2.new(0.05, 0, 0.02, 0), COLORS.YELLOW, Enum.Font.Arcade)
	makeLabel(panel, string.format("Líder: %s  |  Membros (%d/%d): %s", raid.leader, #raid.members, raid.maxSize, table.concat(raid.members, ", ")), UDim2.new(0.9, 0, 0.12, 0), UDim2.new(0.05, 0, 0.17, 0), COLORS.TEXT_DIM)

	if isLeader and raid.state == "lobby" then
		local inviteInput = makeTextBox(panel, "Nome do jogador para convidar...", "", UDim2.new(0.55, 0, 0.13, 0), UDim2.new(0.05, 0, 0.32, 0))

		local inviteBtn = makeButton(panel, "CONVIDAR", COLORS.BLUE, UDim2.new(0.3, 0, 0.13, 0), UDim2.new(0.63, 0, 0.32, 0))
		inviteBtn.MouseButton1Click:Connect(function()
			if inviteInput.Text ~= "" then
				inviteToRaidRemote:FireServer(inviteInput.Text)
				inviteInput.Text = ""
			end
		end)

		local yOffset = 0.48
		for _, requestName in ipairs(raid.requests) do
			makeLabel(panel, "📥 " .. requestName .. " pediu para entrar", UDim2.new(0.5, 0, 0.1, 0), UDim2.new(0.05, 0, yOffset, 0), COLORS.YELLOW)

			local acceptBtn = makeButton(panel, "✔", COLORS.GREEN, UDim2.new(0.12, 0, 0.1, 0), UDim2.new(0.6, 0, yOffset, 0))
			acceptBtn.MouseButton1Click:Connect(function()
				respondJoinRequestRemote:FireServer(requestName, true)
			end)

			local denyBtn = makeButton(panel, "✖", COLORS.RED, UDim2.new(0.12, 0, 0.1, 0), UDim2.new(0.75, 0, yOffset, 0))
			denyBtn.MouseButton1Click:Connect(function()
				respondJoinRequestRemote:FireServer(requestName, false)
			end)

			yOffset = yOffset + 0.12
		end

		local startBtn = makeButton(panel, "▶ INICIAR RAID (15s)", COLORS.GREEN, UDim2.new(0.55, 0, 0.15, 0), UDim2.new(0.05, 0, 0.82, 0))
		startBtn.MouseButton1Click:Connect(function()
			pcall(function()
				startRaidRemote:InvokeServer()
			end)
		end)

		local cancelBtn = makeButton(panel, "CANCELAR", COLORS.RED, UDim2.new(0.3, 0, 0.15, 0), UDim2.new(0.63, 0, 0.82, 0))
		cancelBtn.MouseButton1Click:Connect(function()
			cancelRaidRemote:FireServer()
			task.wait(0.3)
			refreshMenu()
		end)
	elseif raid.state == "countdown" then
		makeLabel(panel, "⏱️ CONTAGEM EM ANDAMENTO — Prepare-se!", UDim2.new(0.9, 0, 0.15, 0), UDim2.new(0.05, 0, 0.45, 0), COLORS.YELLOW, Enum.Font.Arcade)
		if isLeader then
			local cancelBtn = makeButton(panel, "CANCELAR", COLORS.RED, UDim2.new(0.4, 0, 0.15, 0), UDim2.new(0.3, 0, 0.75, 0))
			cancelBtn.MouseBut1Click = nil
			cancelBtn.MouseButton1Click:Connect(function()
				cancelRaidRemote:FireServer()
				stopCountdownDisplay()
				task.wait(0.3)
				refreshMenu()
			end)
		end
	else
		local leaveBtn = makeButton(panel, "SAIR DA RAID", COLORS.RED, UDim2.new(0.4, 0, 0.15, 0), UDim2.new(0.05, 0, 0.8, 0))
		leaveBtn.MouseButton1Click:Connect(function()
			leaveRaidRemote:FireServer()
			task.wait(0.3)
			refreshMenu()
		end)
	end
end

local function renderInvite(raid, order)
	local panel = makePanel(0.16, order)
	makeLabel(panel, string.format("✉️ Convite: %s %s (líder: %s)", raid.bossIcon, raid.bossName, raid.leader), UDim2.new(0.6, 0, 0.5, 0), UDim2.new(0.03, 0, 0.25, 0), COLORS.YELLOW)

	local acceptBtn = makeButton(panel, "ACEITAR", COLORS.GREEN, UDim2.new(0.15, 0, 0.6, 0), UDim2.new(0.65, 0, 0.2, 0))
	acceptBtn.MouseButton1Click:Connect(function()
		respondRaidInviteRemote:FireServer(raid.id, true)
		task.wait(0.4)
		refreshMenu()
	end)

	local denyBtn = makeButton(panel, "RECUSAR", COLORS.RED, UDim2.new(0.15, 0, 0.6, 0), UDim2.new(0.82, 0, 0.2, 0))
	denyBtn.MouseButton1Click:Connect(function()
		respondRaidInviteRemote:FireServer(raid.id, false)
		task.wait(0.4)
		refreshMenu()
	end)
end

local function buildReqText(boss)
	local parts = {}
	if boss.minCoins and boss.minCoins > 0 then
		table.insert(parts, "💰 " .. boss.minCoins .. " moedas")
	end
	if boss.minBounty and boss.minBounty > 0 then
		table.insert(parts, "🎯 Bounty " .. boss.minBounty)
	end
	if boss.requiredCharacter then
		table.insert(parts, "🎭 " .. boss.requiredCharacter)
	end
	if #parts == 0 then
		return "Requisito: personagem equipado"
	end
	return "Requisitos: " .. table.concat(parts, "  |  ")
end

local function renderBoss(boss, canCreate, order)
	local panel = makePanel(0.22, order)

	makeLabel(panel, boss.icon .. " " .. boss.name, UDim2.new(0.6, 0, 0.3, 0), UDim2.new(0.03, 0, 0.05, 0), COLORS.TEXT, Enum.Font.Arcade)
	makeLabel(panel, boss.description, UDim2.new(0.6, 0, 0.2, 0), UDim2.new(0.03, 0, 0.38, 0), COLORS.TEXT_DIM)
	makeLabel(panel, buildReqText(boss), UDim2.new(0.6, 0, 0.18, 0), UDim2.new(0.03, 0, 0.62, 0), COLORS.YELLOW)

	if not boss.configured then
		makeLabel(panel, "⚠️ EM BREVE", UDim2.new(0.3, 0, 0.3, 0), UDim2.new(0.67, 0, 0.35, 0), COLORS.RED, Enum.Font.Arcade)
		return
	end

	if canCreate then
		local createBtn = makeButton(panel, "CRIAR RAID", COLORS.ACCENT, UDim2.new(0.28, 0, 0.4, 0), UDim2.new(0.68, 0, 0.3, 0))
		createBtn.MouseButton1Click:Connect(function()
			pcall(function()
				createRaidRemote:InvokeServer(boss.id)
			end)
			task.wait(0.4)
			refreshMenu()
		end)
	end
end

local function renderOpenRaid(raid, order)
	local panel = makePanel(0.16, order)
	makeLabel(panel, string.format("%s %s — Líder: %s (%d/%d)", raid.bossIcon, raid.bossName, raid.leader, #raid.members, raid.maxSize), UDim2.new(0.62, 0, 0.5, 0), UDim2.new(0.03, 0, 0.25, 0), COLORS.TEXT)

	local joinBtn = makeButton(panel, "PEDIR ENTRADA", COLORS.BLUE, UDim2.new(0.3, 0, 0.6, 0), UDim2.new(0.67, 0, 0.2, 0))
	joinBtn.MouseButton1Click:Connect(function()
		requestJoinRaidRemote:FireServer(raid.id)
	end)
end

local function renderPlayerView(data)
	local order = 0
	local inRaid = data.myRaid ~= nil

	-- Aviso: sem personagem equipado
	if not data.hasEquipped then
		order = order + 1
		local panel = makePanel(0.12, order)
		panel.BackgroundColor3 = Color3.fromRGB(70, 40, 40)
		makeLabel(panel, "⚔️ Equipe um personagem para participar de raids!", UDim2.new(0.94, 0, 0.6, 0), UDim2.new(0.03, 0, 0.2, 0), COLORS.YELLOW, Enum.Font.Arcade)
	end

	if data.myRaid then
		order = order + 1
		renderMyRaid(data.myRaid, order)
	end

	if data.myInvites and not inRaid then
		for _, invite in ipairs(data.myInvites) do
			order = order + 1
			renderInvite(invite, order)
		end
	end

	if #data.bosses == 0 then
		order = order + 1
		local panel = makePanel(0.15, order)
		makeLabel(panel, "Nenhum boss disponível no momento.", UDim2.new(0.94, 0, 0.6, 0), UDim2.new(0.03, 0, 0.2, 0), COLORS.TEXT_DIM)
	end

	for _, boss in ipairs(data.bosses) do
		order = order + 1
		renderBoss(boss, not inRaid and data.hasEquipped, order)
	end

	if not inRaid and data.openRaids then
		for _, raid in ipairs(data.openRaids) do
			if raid.leader ~= player.Name then
				order = order + 1
				renderOpenRaid(raid, order)
			end
		end
	end
end

-- =====================================
-- VISÃO DO EDITOR (ADMIN)
-- =====================================

local function renderEditorList()
	local success, catalog = pcall(function()
		return adminGetBossCatalogRemote:InvokeServer()
	end)

	local order = 0

	-- Botão: novo boss
	order = order + 1
	local newPanel = makePanel(0.12, order)
	local newBtn = makeButton(newPanel, "➕ REGISTRAR NOVO BOSS", COLORS.GREEN, UDim2.new(0.9, 0, 0.7, 0), UDim2.new(0.05, 0, 0.15, 0))
	newBtn.MouseButton1Click:Connect(function()
		editingBoss = nil
		viewMode = "editForm"
		refreshMenu()
	end)

	if not success or not catalog then
		order = order + 1
		local panel = makePanel(0.12, order)
		makeLabel(panel, "Erro ao carregar catálogo.", UDim2.new(0.9, 0, 0.6, 0), UDim2.new(0.05, 0, 0.2, 0), COLORS.RED)
		return
	end

	for _, boss in ipairs(catalog) do
		order = order + 1
		local panel = makePanel(0.18, order)

		local statusIcon = boss.enabled and "🟢" or "🔴"
		local placeText = boss.placeId ~= 0 and ("Place: " .. boss.placeId) or "⚠️ SEM PLACE ID"
		makeLabel(panel, string.format("%s %s %s", statusIcon, boss.icon, boss.name), UDim2.new(0.55, 0, 0.35, 0), UDim2.new(0.03, 0, 0.08, 0), COLORS.TEXT, Enum.Font.Arcade)
		makeLabel(panel, placeText .. "  |  " .. buildReqText(boss), UDim2.new(0.55, 0, 0.3, 0), UDim2.new(0.03, 0, 0.5, 0), COLORS.TEXT_DIM)

		local editBtn = makeButton(panel, "✏️ EDITAR", COLORS.BLUE, UDim2.new(0.17, 0, 0.5, 0), UDim2.new(0.6, 0, 0.25, 0))
		editBtn.MouseButton1Click:Connect(function()
			editingBoss = boss
			viewMode = "editForm"
			refreshMenu()
		end)

		local removeBtn = makeButton(panel, "🗑️", COLORS.RED, UDim2.new(0.12, 0, 0.5, 0), UDim2.new(0.8, 0, 0.25, 0))
		removeBtn.MouseButton1Click:Connect(function()
			-- Confirmação simples: dois cliques
			if removeBtn.Text == "🗑️" then
				removeBtn.Text = "CONFIRMA?"
				task.delay(3, function()
					if removeBtn.Parent then
						removeBtn.Text = "🗑️"
					end
				end)
			else
				pcall(function()
					adminRemoveBossRemote:InvokeServer(boss.id)
				end)
				task.wait(0.3)
				refreshMenu()
			end
		end)
	end
end

local function renderEditorForm()
	local boss = editingBoss
	local panel = makePanel(1.4, 1)

	makeLabel(panel, boss and ("✏️ EDITANDO: " .. boss.name) or "➕ NOVO BOSS", UDim2.new(0.9, 0, 0.06, 0), UDim2.new(0.05, 0, 0.01, 0), COLORS.YELLOW, Enum.Font.Arcade)

	-- Campos do formulário
	makeLabel(panel, "Nome do Boss:", UDim2.new(0.4, 0, 0.04, 0), UDim2.new(0.05, 0, 0.08, 0), COLORS.TEXT_DIM)
	local nameBox = makeTextBox(panel, "Ex: Dragão Sombrio", boss and boss.name, UDim2.new(0.6, 0, 0.06, 0), UDim2.new(0.05, 0, 0.12, 0))

	makeLabel(panel, "Ícone (emoji):", UDim2.new(0.25, 0, 0.04, 0), UDim2.new(0.68, 0, 0.08, 0), COLORS.TEXT_DIM)
	local iconBox = makeTextBox(panel, "👹", boss and boss.icon, UDim2.new(0.15, 0, 0.06, 0), UDim2.new(0.68, 0, 0.12, 0))

	makeLabel(panel, "Place ID da experiência do Boss:", UDim2.new(0.6, 0, 0.04, 0), UDim2.new(0.05, 0, 0.2, 0), COLORS.TEXT_DIM)
	local placeBox = makeTextBox(panel, "Ex: 123456789", boss and boss.placeId ~= 0 and tostring(boss.placeId) or "", UDim2.new(0.9, 0, 0.06, 0), UDim2.new(0.05, 0, 0.24, 0))

	makeLabel(panel, "Descrição:", UDim2.new(0.4, 0, 0.04, 0), UDim2.new(0.05, 0, 0.32, 0), COLORS.TEXT_DIM)
	local descBox = makeTextBox(panel, "Ex: Boss de fogo. Recomendado 3+ jogadores.", boss and boss.description, UDim2.new(0.9, 0, 0.06, 0), UDim2.new(0.05, 0, 0.36, 0))

	makeLabel(panel, "── REQUISITOS (0 ou vazio = sem requisito) ──", UDim2.new(0.9, 0, 0.04, 0), UDim2.new(0.05, 0, 0.45, 0), COLORS.YELLOW)

	makeLabel(panel, "Moedas mínimas:", UDim2.new(0.4, 0, 0.04, 0), UDim2.new(0.05, 0, 0.5, 0), COLORS.TEXT_DIM)
	local coinsBox = makeTextBox(panel, "0", boss and boss.minCoins > 0 and tostring(boss.minCoins) or "", UDim2.new(0.4, 0, 0.06, 0), UDim2.new(0.05, 0, 0.54, 0))

	makeLabel(panel, "Bounty mínimo:", UDim2.new(0.4, 0, 0.04, 0), UDim2.new(0.53, 0, 0.5, 0), COLORS.TEXT_DIM)
	local bountyBox = makeTextBox(panel, "0", boss and boss.minBounty > 0 and tostring(boss.minBounty) or "", UDim2.new(0.4, 0, 0.06, 0), UDim2.new(0.53, 0, 0.54, 0))

	makeLabel(panel, "Personagem obrigatório (vazio = qualquer):", UDim2.new(0.9, 0, 0.04, 0), UDim2.new(0.05, 0, 0.62, 0), COLORS.TEXT_DIM)
	local charBox = makeTextBox(panel, "Ex: Noob Despertado", boss and boss.requiredCharacter, UDim2.new(0.9, 0, 0.06, 0), UDim2.new(0.05, 0, 0.66, 0))

	-- Toggle ativado
	local enabled = boss and boss.enabled or (boss == nil) -- novo boss = ativado
	local enabledBtn = makeButton(panel, enabled and "🟢 ATIVADO" or "🔴 DESATIVADO", enabled and COLORS.GREEN or COLORS.RED, UDim2.new(0.4, 0, 0.06, 0), UDim2.new(0.05, 0, 0.75, 0))
	enabledBtn.MouseButton1Click:Connect(function()
		enabled = not enabled
		enabledBtn.Text = enabled and "🟢 ATIVADO" or "🔴 DESATIVADO"
		enabledBtn.BackgroundColor3 = enabled and COLORS.GREEN or COLORS.RED
	end)

	-- Salvar / Voltar
	local saveBtn = makeButton(panel, "💾 SALVAR", COLORS.GREEN, UDim2.new(0.42, 0, 0.08, 0), UDim2.new(0.05, 0, 0.86, 0))
	saveBtn.MouseButton1Click:Connect(function()
		local bossInfo = {
			id = boss and boss.id or nil,
			name = nameBox.Text,
			icon = iconBox.Text ~= "" and iconBox.Text or "👹",
			placeId = tonumber(placeBox.Text) or 0,
			description = descBox.Text,
			enabled = enabled,
			minCoins = tonumber(coinsBox.Text) or 0,
			minBounty = tonumber(bountyBox.Text) or 0,
			requiredCharacter = charBox.Text,
		}

		local success, ok, result = pcall(function()
			return adminSaveBossRemote:InvokeServer(bossInfo)
		end)

		if success and ok then
			showNotification("Boss salvo com sucesso!", true)
			viewMode = "editor"
			editingBoss = nil
			refreshMenu()
		else
			showNotification(tostring(result or "Erro ao salvar!"), false)
		end
	end)

	local backBtn = makeButton(panel, "← VOLTAR", COLORS.PANEL, UDim2.new(0.42, 0, 0.08, 0), UDim2.new(0.53, 0, 0.86, 0))
	backBtn.BackgroundColor3 = Color3.fromRGB(80, 80, 100)
	backBtn.MouseButton1Click:Connect(function()
		viewMode = "editor"
		editingBoss = nil
		refreshMenu()
	end)
end

-- =====================================
-- REFRESH PRINCIPAL
-- =====================================

refreshMenu = function()
	if not menuOpen then
		return
	end

	clearContent()

	if viewMode == "editForm" then
		title.Text = "⚙️ EDITOR DE BOSS"
		editorToggleBtn.Text = "👹 RAIDS"
		renderEditorForm()
		return
	end

	local data = fetchData()
	if not data then
		return
	end

	editorToggleBtn.Visible = data.isAdmin and true or false

	if viewMode == "editor" and data.isAdmin then
		title.Text = "⚙️ EDITOR DE BOSS"
		editorToggleBtn.Text = "👹 RAIDS"
		renderEditorList()
	else
		viewMode = "player"
		title.Text = "👹 BOSS RAID"
		editorToggleBtn.Text = "⚙️ EDITOR"
		renderPlayerView(data)
	end
end

editorToggleBtn.MouseButton1Click:Connect(function()
	if viewMode == "player" then
		viewMode = "editor"
	else
		viewMode = "player"
		editingBoss = nil
	end
	refreshMenu()
end)

-- =====================================
-- ATUALIZAÇÕES EM TEMPO REAL
-- =====================================

raidStateUpdateRemote.OnClientEvent:Connect(function(raidData)
	if raidData.removed then
		stopCountdownDisplay()
		if menuOpen and viewMode == "player" then
			refreshMenu()
		end
		return
	end

	local isMember = false
	for _, name in ipairs(raidData.members) do
		if name == player.Name then
			isMember = true
			break
		end
	end

	if isMember and raidData.state == "countdown" and raidData.countdownEndsAt then
		runCountdownDisplay(raidData.countdownEndsAt, raidData.bossIcon .. " " .. raidData.bossName)
	elseif raidData.state == "lobby" then
		stopCountdownDisplay()
	end

	if menuOpen and viewMode == "player" then
		refreshMenu()
	end
end)

-- =====================================
-- REGISTRO NO UNIFIED MENU
-- =====================================

local function openMenu()
	menuOpen = true
	viewMode = "player"
	screenGui.Enabled = true
	refreshMenu()
end

local function closeMenu()
	menuOpen = false
	editingBoss = nil
	screenGui.Enabled = false
end

task.spawn(function()
	local timeout = 0
	while not _G.RegisterMenuCategory and timeout < 30 do
		task.wait(0.5)
		timeout = timeout + 0.5
	end

	if _G.RegisterMenuCategory then
		_G.RegisterMenuCategory("BOSS RAID", "👹", openMenu, closeMenu, 8)
		print("[RAID CLIENT V2] Registrado no UnifiedMenu")
	else
		warn("[RAID CLIENT V2] UnifiedMenu não encontrado — criando botão próprio")

		local fallbackBtn = Instance.new("TextButton")
		fallbackBtn.Size = UDim2.new(0.08, 0, 0.05, 0)
		fallbackBtn.Position = UDim2.new(0.91, 0, 0.4, 0)
		fallbackBtn.BackgroundColor3 = COLORS.ACCENT
		fallbackBtn.Text = "👹 RAID"
		fallbackBtn.TextColor3 = COLORS.TEXT
		fallbackBtn.Font = Enum.Font.Arcade
		fallbackBtn.TextScaled = true
		fallbackBtn.Parent = notifyGui

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.2, 0)
		corner.Parent = fallbackBtn

		fallbackBtn.MouseButton1Click:Connect(function()
			if menuOpen then
				closeMenu()
			else
				openMenu()
			end
		end)
	end
end)

print("[RAID CLIENT V2] ✅ Carregado")
