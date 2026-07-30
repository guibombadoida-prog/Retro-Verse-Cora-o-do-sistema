-- ============================================
-- RETRO HOTBAR CLIENT V2 — BACKPACK RETRÔ
-- (V2) ALTERAÇÕES:
--   1. Emoji ⚔ removido — NOME da Tool exposto em destaque no slot
--   2. Slots/botões MAIORES em todos os dispositivos
--   3. Perfis proporcionais por dispositivo: PC / MOBILE / CONSOLE
--      (Console detectado via GuiService:IsTenFootInterface())
--   4. CORREÇÃO: o header [ PERSONAGEM ] entrava na fila do
--      UIListLayout junto com os slots (aparecia deslocado no
--      print) — agora é filho do ScreenGui, acima da hotbar
--   5. Console/Gamepad: L1/R1 ciclam as Tools (padrão Roblox)
-- Coloque em StarterPlayer > StarterPlayerScripts (LocalScript)
-- Nome: "RetroHotbarClient"
-- SUBSTITUI: RetroHotbarClient_V1
-- REMOVER:   RetroHotbarClient_V1
-- ============================================
-- FUNÇÃO:
-- • Desativa o Backpack padrão do Roblox (CoreGui)
-- • Hotbar retrô com 7 slots (limite do projeto: 7 Tools/personagem)
-- • Teclas 1–7 (PC), toque no slot (Mobile), L1/R1 (Console)
-- • Borda VERDE NEON = Tool equipada
-- • Slot escurecido = cooldown (lê Tool.Enabled — padrão de
--   debounce oficial das Tools do projeto)
-- • ToolTip da Tool aparece ao passar o mouse no slot (PC)
-- • Header mostra o personagem equipado (Remote SyncCharacterState)
-- • Auto-oculta quando não há Tools (Lobby / Zona Segura)
-- REUTILIZAÇÃO:
-- • Paleta neon + Enum.Font.Arcade — HealthDisplay V3 (COLORS)
--   e UnifiedMenuClient V3 (bordas/estilo)
-- • Detecção mobile — UnifiedMenuClient V3
-- • Remote SyncCharacterState — GameManager (equipCharacter)
-- • Compatível com AntiToolSystem V2 (guard de morte no cliente)
-- ============================================

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local StarterGui = game:GetService("StarterGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GuiService = game:GetService("GuiService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

print("[RETRO HOTBAR V2] Inicializando...")

-- =====================================
-- DETECÇÃO DE DISPOSITIVO
-- =====================================

local isConsole = GuiService:IsTenFootInterface()
local isMobile = not isConsole
	and UserInputService.TouchEnabled
	and not UserInputService.KeyboardEnabled

-- Perfis proporcionais (tudo em Scale)
local PROFILE
if isConsole then
	PROFILE = {
		deviceName = "CONSOLE",
		slotHeight = 0.12,  -- altura do slot (fração da tela)
		bottomY    = 0.95,  -- borda inferior da hotbar
		headerW    = 0.34,  -- largura do header
	}
elseif isMobile then
	PROFILE = {
		deviceName = "MOBILE",
		slotHeight = 0.15,
		bottomY    = 0.93,
		headerW    = 0.4,
	}
else
	PROFILE = {
		deviceName = "PC",
		slotHeight = 0.105,
		bottomY    = 0.985,
		headerW    = 0.3,
	}
end

-- =====================================
-- CONFIGURAÇÃO
-- =====================================

local MAX_SLOTS = 7 -- Regra do projeto: máximo 7 Tools por personagem

local COLORS = {
	background   = Color3.fromRGB(0, 0, 0),
	slotBg       = Color3.fromRGB(12, 12, 18),
	slotBgHover  = Color3.fromRGB(25, 25, 35),
	border       = Color3.fromRGB(255, 255, 255),
	borderEquip  = Color3.fromRGB(0, 255, 0),   -- Verde neon (equipada)
	borderHover  = Color3.fromRGB(0, 200, 255), -- Ciano (hover)
	textGlow     = Color3.fromRGB(0, 255, 255), -- Ciano neon
	text         = Color3.fromRGB(255, 255, 255),
	numberBg     = Color3.fromRGB(30, 30, 40),
	cooldown     = Color3.fromRGB(0, 0, 0),
}

local SLOT_KEYS = {
	Enum.KeyCode.One,
	Enum.KeyCode.Two,
	Enum.KeyCode.Three,
	Enum.KeyCode.Four,
	Enum.KeyCode.Five,
	Enum.KeyCode.Six,
	Enum.KeyCode.Seven,
}

-- =====================================
-- DESATIVAR BACKPACK PADRÃO (CoreGui)
-- =====================================

task.spawn(function()
	for _ = 1, 10 do
		local ok = pcall(function()
			StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
		end)
		if ok then
			print("[RETRO HOTBAR V2] Backpack padrão do Roblox desativado")
			return
		end
		task.wait(0.5)
	end
	warn("[RETRO HOTBAR V2] Não foi possível desativar o Backpack padrão")
end)

-- =====================================
-- GUI BASE
-- =====================================

local hotbarGui = Instance.new("ScreenGui")
hotbarGui.Name = "RetroHotbar"
hotbarGui.ResetOnSpawn = false
hotbarGui.DisplayOrder = 10 -- HealthDisplay=5 / UnifiedMenu=50
hotbarGui.Parent = playerGui

-- Container dos slots (só os slots — header fica FORA do layout)
local container = Instance.new("Frame")
container.Name = "HotbarContainer"
container.AnchorPoint = Vector2.new(0.5, 1)
container.Position = UDim2.new(0.5, 0, PROFILE.bottomY, 0)
container.Size = UDim2.new(0.94, 0, PROFILE.slotHeight, 0)
container.BackgroundTransparency = 1
container.Visible = false
container.Parent = hotbarGui

local layout = Instance.new("UIListLayout")
layout.FillDirection = Enum.FillDirection.Horizontal
layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
layout.VerticalAlignment = Enum.VerticalAlignment.Bottom
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Padding = UDim.new(0.006, 0)
layout.Parent = container

-- Header: nome do personagem equipado (API do jogo)
-- (V2) FIX: filho do ScreenGui — fora do UIListLayout dos slots
local headerLabel = Instance.new("TextLabel")
headerLabel.Name = "CharacterHeader"
headerLabel.AnchorPoint = Vector2.new(0.5, 1)
headerLabel.Position = UDim2.new(0.5, 0, PROFILE.bottomY - PROFILE.slotHeight - 0.012, 0)
headerLabel.Size = UDim2.new(PROFILE.headerW, 0, PROFILE.slotHeight * 0.3, 0)
headerLabel.BackgroundColor3 = COLORS.slotBg
headerLabel.BackgroundTransparency = 0.25
headerLabel.BorderSizePixel = 2
headerLabel.BorderColor3 = COLORS.textGlow
headerLabel.Text = ""
headerLabel.TextColor3 = COLORS.textGlow
headerLabel.TextScaled = true
headerLabel.Font = Enum.Font.Arcade
headerLabel.TextStrokeTransparency = 0.5
headerLabel.TextStrokeColor3 = COLORS.background
headerLabel.Visible = false
headerLabel.Parent = hotbarGui

-- =====================================
-- ESTADO
-- =====================================

local slots = {}
local equippedName = nil
local refreshQueued = false

-- Declarações antecipadas (usadas dentro de createSlot)
local toggleSlot
local updateSlotVisual

-- =====================================
-- HEADER
-- =====================================

local function updateHeader()
	if equippedName and container.Visible then
		headerLabel.Text = "[ " .. string.upper(equippedName) .. " ]"
		headerLabel.Visible = true
	else
		headerLabel.Text = ""
		headerLabel.Visible = false
	end
end

-- =====================================
-- VISUAL DO SLOT
-- =====================================

updateSlotVisual = function(index)
	local data = slots[index]
	if not data then
		return
	end

	local slot = data.frame
	local tool = data.tool

	if not tool or not tool.Parent then
		slot.Visible = false
		return
	end

	slot.Visible = true
	data.nameLabel.Text = tool.Name

	-- (V2) NOME EXPOSTO: sem emoji placeholder.
	-- Com TextureId → ícone em cima + nome na faixa inferior.
	-- Sem TextureId → nome ocupa o corpo do slot em destaque.
	if tool.TextureId ~= "" then
		data.icon.Image = tool.TextureId
		data.icon.Visible = true
		data.nameLabel.Position = UDim2.new(0, 0, 0.7, 0)
		data.nameLabel.Size = UDim2.new(1, 0, 0.3, 0)
		data.nameLabel.BackgroundTransparency = 0.35
	else
		data.icon.Visible = false
		data.nameLabel.Position = UDim2.new(0.02, 0, 0.3, 0)
		data.nameLabel.Size = UDim2.new(0.96, 0, 0.66, 0)
		data.nameLabel.BackgroundTransparency = 1
	end

	-- Destaque de equipada (verde neon)
	local character = player.Character
	local equipped = character ~= nil and tool.Parent == character
	slot.BorderColor3 = equipped and COLORS.borderEquip or COLORS.border
	slot.BorderSizePixel = equipped and 3 or 2
	data.numberLabel.TextColor3 = equipped and COLORS.borderEquip or COLORS.textGlow

	-- Cooldown: padrão Tool.Enabled do projeto
	data.cooldownOverlay.Visible = not tool.Enabled
end

-- =====================================
-- ALOCAÇÃO DE SLOTS
-- =====================================

local function clearSlot(index)
	local data = slots[index]
	if not data then
		return
	end

	if data.enabledConn then
		pcall(function()
			data.enabledConn:Disconnect()
		end)
		data.enabledConn = nil
	end

	data.tool = nil
	data.tooltip.Visible = false
	data.frame.Visible = false
end

local function assignSlot(index, tool)
	local data = slots[index]
	data.tool = tool

	-- Reagir ao debounce da Tool (Enabled = false durante cooldown)
	data.enabledConn = tool:GetPropertyChangedSignal("Enabled"):Connect(function()
		data.cooldownOverlay.Visible = not tool.Enabled
	end)

	updateSlotVisual(index)
end

-- =====================================
-- REFRESH (Backpack + Personagem)
-- =====================================

local function collectTools()
	local list = {}

	local backpack = player:FindFirstChildOfClass("Backpack")
	if backpack then
		for _, item in ipairs(backpack:GetChildren()) do
			if item:IsA("Tool") then
				table.insert(list, item)
			end
		end
	end

	local character = player.Character
	if character then
		for _, item in ipairs(character:GetChildren()) do
			if item:IsA("Tool") then
				table.insert(list, item)
			end
		end
	end

	return list
end

local function refresh()
	local tools = collectTools()

	local present = {}
	for _, tool in ipairs(tools) do
		present[tool] = true
	end

	-- Limpar slots de Tools que saíram do inventário
	for i = 1, MAX_SLOTS do
		if slots[i].tool and not present[slots[i].tool] then
			clearSlot(i)
		end
	end

	-- Tools já alocadas mantêm o slot (não embaralha ao equipar)
	local assigned = {}
	for i = 1, MAX_SLOTS do
		if slots[i].tool then
			assigned[slots[i].tool] = true
		end
	end

	-- Alocar Tools novas no primeiro slot livre
	for _, tool in ipairs(tools) do
		if not assigned[tool] then
			local placed = false
			for i = 1, MAX_SLOTS do
				if not slots[i].tool then
					assignSlot(i, tool)
					assigned[tool] = true
					placed = true
					break
				end
			end
			if not placed then
				warn("[RETRO HOTBAR V2] Limite de " .. MAX_SLOTS .. " slots excedido: " .. tool.Name)
			end
		end
	end

	-- Atualizar visual e visibilidade geral
	local hasTool = false
	for i = 1, MAX_SLOTS do
		updateSlotVisual(i)
		if slots[i].tool then
			hasTool = true
		end
	end

	container.Visible = hasTool
	updateHeader()
end

local function scheduleRefresh()
	if refreshQueued then
		return
	end
	refreshQueued = true
	task.defer(function()
		refreshQueued = false
		refresh()
	end)
end

-- =====================================
-- EQUIPAR / DESEQUIPAR
-- =====================================

toggleSlot = function(index)
	local data = slots[index]
	if not data or not data.tool then
		return
	end

	local character = player.Character
	if not character then
		return
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return -- Morto não equipa (compatível com AntiToolSystem V2)
	end

	local tool = data.tool
	if tool.Parent == character then
		humanoid:UnequipTools()
	else
		humanoid:EquipTool(tool)
	end
end

-- =====================================
-- CICLO DE TOOLS (CONSOLE / GAMEPAD)
-- L1 = anterior | R1 = próxima (padrão Roblox)
-- =====================================

local function getEquippedSlotIndex()
	local character = player.Character
	if not character then
		return nil
	end
	for i = 1, MAX_SLOTS do
		local tool = slots[i].tool
		if tool and tool.Parent == character then
			return i
		end
	end
	return nil
end

local function cycleTool(direction)
	local occupied = {}
	for i = 1, MAX_SLOTS do
		if slots[i].tool then
			table.insert(occupied, i)
		end
	end
	if #occupied == 0 then
		return
	end

	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return -- Morto não equipa (compatível com AntiToolSystem V2)
	end

	local equippedIdx = getEquippedSlotIndex()

	-- Nada equipado: começa pela ponta
	if not equippedIdx then
		local slotIndex = (direction > 0) and occupied[1] or occupied[#occupied]
		humanoid:EquipTool(slots[slotIndex].tool)
		return
	end

	-- Posição atual na lista de slots ocupados
	local pos = nil
	for p, idx in ipairs(occupied) do
		if idx == equippedIdx then
			pos = p
			break
		end
	end
	if not pos then
		return
	end

	local nextPos = pos + direction
	if nextPos < 1 or nextPos > #occupied then
		humanoid:UnequipTools() -- Passou da ponta → desequipa (padrão Roblox)
	else
		humanoid:EquipTool(slots[occupied[nextPos]].tool)
	end
end

-- =====================================
-- CRIAÇÃO DOS SLOTS
-- =====================================

local function createSlot(index)
	local slot = Instance.new("TextButton")
	slot.Name = "Slot" .. index
	slot.LayoutOrder = index
	slot.Size = UDim2.new(1, 0, 1, 0)
	slot.BackgroundColor3 = COLORS.slotBg
	slot.BackgroundTransparency = 0.2
	slot.BorderSizePixel = 2
	slot.BorderColor3 = COLORS.border
	slot.AutoButtonColor = false
	slot.Text = ""
	slot.Visible = false
	slot.Parent = container

	local aspect = Instance.new("UIAspectRatioConstraint")
	aspect.AspectRatio = 1
	aspect.DominantAxis = Enum.DominantAxis.Height
	aspect.Parent = slot

	-- Número do slot (tecla 1-7)
	local numberLabel = Instance.new("TextLabel")
	numberLabel.Name = "SlotNumber"
	numberLabel.Size = UDim2.new(0.26, 0, 0.24, 0)
	numberLabel.Position = UDim2.new(0, 0, 0, 0)
	numberLabel.BackgroundColor3 = COLORS.numberBg
	numberLabel.BackgroundTransparency = 0.15
	numberLabel.BorderSizePixel = 0
	numberLabel.Text = tostring(index)
	numberLabel.TextColor3 = COLORS.textGlow
	numberLabel.TextScaled = true
	numberLabel.Font = Enum.Font.Arcade
	numberLabel.ZIndex = 3
	numberLabel.Parent = slot

	-- Ícone da Tool (só aparece se a Tool tiver TextureId)
	local icon = Instance.new("ImageLabel")
	icon.Name = "ToolIcon"
	icon.Size = UDim2.new(0.6, 0, 0.6, 0)
	icon.Position = UDim2.new(0.2, 0, 0.05, 0)
	icon.BackgroundTransparency = 1
	icon.ScaleType = Enum.ScaleType.Fit
	icon.Visible = false
	icon.Parent = slot

	-- Nome da Tool (V2: exposto em destaque, sem emoji)
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "ToolName"
	nameLabel.Size = UDim2.new(0.96, 0, 0.66, 0)
	nameLabel.Position = UDim2.new(0.02, 0, 0.3, 0)
	nameLabel.BackgroundColor3 = COLORS.background
	nameLabel.BackgroundTransparency = 1
	nameLabel.BorderSizePixel = 0
	nameLabel.Text = ""
	nameLabel.TextColor3 = COLORS.text
	nameLabel.TextScaled = true
	nameLabel.Font = Enum.Font.Arcade
	nameLabel.TextStrokeTransparency = 0.4
	nameLabel.TextStrokeColor3 = COLORS.background
	nameLabel.ZIndex = 2
	nameLabel.Parent = slot

	-- Overlay de cooldown
	local cooldownOverlay = Instance.new("Frame")
	cooldownOverlay.Name = "CooldownOverlay"
	cooldownOverlay.Size = UDim2.new(1, 0, 1, 0)
	cooldownOverlay.BackgroundColor3 = COLORS.cooldown
	cooldownOverlay.BackgroundTransparency = 0.45
	cooldownOverlay.BorderSizePixel = 0
	cooldownOverlay.Visible = false
	cooldownOverlay.ZIndex = 4
	cooldownOverlay.Parent = slot

	-- ToolTip (acima do slot — hover no PC)
	local tooltip = Instance.new("TextLabel")
	tooltip.Name = "Tooltip"
	tooltip.AnchorPoint = Vector2.new(0.5, 1)
	tooltip.Position = UDim2.new(0.5, 0, -0.12, 0)
	tooltip.Size = UDim2.new(2.2, 0, 0.3, 0)
	tooltip.BackgroundColor3 = COLORS.slotBg
	tooltip.BackgroundTransparency = 0.1
	tooltip.BorderSizePixel = 2
	tooltip.BorderColor3 = COLORS.borderHover
	tooltip.Text = ""
	tooltip.TextColor3 = COLORS.textGlow
	tooltip.TextScaled = true
	tooltip.Font = Enum.Font.Arcade
	tooltip.Visible = false
	tooltip.ZIndex = 5
	tooltip.Parent = slot

	local data = {
		frame = slot,
		tool = nil,
		enabledConn = nil,
		icon = icon,
		nameLabel = nameLabel,
		numberLabel = numberLabel,
		cooldownOverlay = cooldownOverlay,
		tooltip = tooltip,
	}
	slots[index] = data

	-- Clique / toque (PC, Mobile e Console)
	slot.Activated:Connect(function()
		toggleSlot(index)
	end)

	-- Hover (PC): destaque + ToolTip
	slot.MouseEnter:Connect(function()
		if not data.tool then
			return
		end
		slot.BackgroundColor3 = COLORS.slotBgHover
		if data.tool.Parent ~= player.Character then
			slot.BorderColor3 = COLORS.borderHover
		end
		local tip = data.tool.ToolTip
		if tip ~= "" then
			tooltip.Text = tip
			tooltip.Visible = true
		end
	end)

	slot.MouseLeave:Connect(function()
		slot.BackgroundColor3 = COLORS.slotBg
		tooltip.Visible = false
		updateSlotVisual(index)
	end)
end

for i = 1, MAX_SLOTS do
	createSlot(i)
end

-- =====================================
-- INPUT: TECLAS 1–7 (PC) + L1/R1 (CONSOLE)
-- =====================================

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end

	-- Console / Gamepad: ciclar Tools
	if input.KeyCode == Enum.KeyCode.ButtonR1 then
		cycleTool(1)
		return
	end
	if input.KeyCode == Enum.KeyCode.ButtonL1 then
		cycleTool(-1)
		return
	end

	if input.UserInputType ~= Enum.UserInputType.Keyboard then
		return
	end

	for index, keyCode in ipairs(SLOT_KEYS) do
		if input.KeyCode == keyCode then
			toggleSlot(index)
			return
		end
	end
end)

-- =====================================
-- MONITORAR BACKPACK E PERSONAGEM
-- =====================================

local backpackConns = {}
local characterConns = {}

local function disconnectAll(list)
	for _, conn in ipairs(list) do
		pcall(function()
			conn:Disconnect()
		end)
	end
	table.clear(list)
end

local function bindBackpack(backpack)
	disconnectAll(backpackConns)

	table.insert(backpackConns, backpack.ChildAdded:Connect(function(child)
		if child:IsA("Tool") then
			scheduleRefresh()
		end
	end))

	table.insert(backpackConns, backpack.ChildRemoved:Connect(function(child)
		if child:IsA("Tool") then
			scheduleRefresh()
		end
	end))

	scheduleRefresh()
end

local function bindCharacter(character)
	disconnectAll(characterConns)

	table.insert(characterConns, character.ChildAdded:Connect(function(child)
		if child:IsA("Tool") then
			scheduleRefresh()
		end
	end))

	table.insert(characterConns, character.ChildRemoved:Connect(function(child)
		if child:IsA("Tool") then
			scheduleRefresh()
		end
	end))

	scheduleRefresh()
end

-- Backpack é recriado a cada respawn — monitorar via ChildAdded
player.ChildAdded:Connect(function(child)
	if child:IsA("Backpack") then
		bindBackpack(child)
	end
end)

player.CharacterAdded:Connect(function(character)
	bindCharacter(character)
end)

-- Estado inicial
local initialBackpack = player:FindFirstChildOfClass("Backpack")
if initialBackpack then
	bindBackpack(initialBackpack)
end
if player.Character then
	bindCharacter(player.Character)
end

-- =====================================
-- API DO JOGO: SyncCharacterState
-- (GameManager envia nome + estado ao equipar/desequipar)
-- =====================================

task.spawn(function()
	local remotes = ReplicatedStorage:WaitForChild("Remotes", 10)
	if not remotes then
		warn("[RETRO HOTBAR V2] Pasta Remotes não encontrada — header sem nome do personagem")
		return
	end

	local syncRemote = remotes:WaitForChild("SyncCharacterState", 10)
	if not syncRemote then
		warn("[RETRO HOTBAR V2] Remote SyncCharacterState não encontrado")
		return
	end

	syncRemote.OnClientEvent:Connect(function(characterName, isEquipped)
		if isEquipped and characterName then
			equippedName = characterName
		else
			equippedName = nil
		end
		updateHeader()
	end)

	print("[RETRO HOTBAR V2] Conectado ao SyncCharacterState (API do jogo)")
end)

print(string.format([[
╔════════════════════════════════════════════════════╗
║  ✅ RETRO HOTBAR V2 CARREGADO                      ║
╠════════════════════════════════════════════════════╣
║  Dispositivo: %s
║  • Backpack padrão do Roblox: DESATIVADO           ║
║  • 7 slots retrô MAIORES (proporcional/dispositivo)║
║  • Nome da Tool EXPOSTO no slot (sem emoji)        ║
║  • PC: teclas 1-7 | Mobile: toque | Console: L1/R1 ║
║  • Verde neon = equipada | Escuro = cooldown       ║
║  • Header com personagem equipado (API do jogo)    ║
╚════════════════════════════════════════════════════╝
]], PROFILE.deviceName))
