-- ============================================
-- HEALTH DISPLAY V3 - RETRO STYLE
-- (V3) ALTERAÇÕES: wait() -> task.wait() (conformidade)
-- Coloque em StarterPlayer > StarterPlayerScripts
-- Nome: "HealthDisplay"
-- SUBSTITUI: HealthDisplay V1
-- ============================================

local Players = game:GetService("Players")
local Player = Players.LocalPlayer
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

-- =====================================
-- CONFIGURAÇÃO DE CORES RETRO
-- =====================================

local COLORS = {
	background = Color3.fromRGB(0, 0, 0),
	border = Color3.fromRGB(255, 255, 255),
	healthHigh = Color3.fromRGB(0, 255, 0), -- Verde neon
	healthMid = Color3.fromRGB(255, 255, 0), -- Amarelo neon
	healthLow = Color3.fromRGB(255, 100, 0), -- Laranja
	healthCritical = Color3.fromRGB(255, 0, 0), -- Vermelho neon
	barBackground = Color3.fromRGB(40, 40, 40),
	textGlow = Color3.fromRGB(0, 255, 255), -- Ciano neon
}

-- =====================================
-- CRIAR SCREENGUI
-- =====================================

local HealthGui = Instance.new("ScreenGui")
HealthGui.Name = "RetroHealthDisplay"
HealthGui.ResetOnSpawn = false
HealthGui.DisplayOrder = 5
HealthGui.Parent = Player.PlayerGui

-- =====================================
-- CONTAINER PRINCIPAL
-- =====================================

local MainContainer = Instance.new("Frame")
MainContainer.Name = "MainContainer"
MainContainer.Size = UDim2.new(0.25, 0, 0.08, 0)
MainContainer.Position = UDim2.new(0.375, 0, 0.05, 0)
MainContainer.BackgroundColor3 = COLORS.background
MainContainer.BorderColor3 = COLORS.border
MainContainer.BorderSizePixel = 3
MainContainer.Parent = HealthGui

-- =====================================
-- HEADER (TÍTULO)
-- =====================================

local HeaderBar = Instance.new("Frame")
HeaderBar.Name = "Header"
HeaderBar.Size = UDim2.new(1, 0, 0.3, 0)
HeaderBar.Position = UDim2.new(0, 0, 0, 0)
HeaderBar.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
HeaderBar.BorderColor3 = COLORS.border
HeaderBar.BorderSizePixel = 2
HeaderBar.Parent = MainContainer

local TitleLabel = Instance.new("TextLabel")
TitleLabel.Name = "Title"
TitleLabel.Size = UDim2.new(1, 0, 1, 0)
TitleLabel.BackgroundTransparency = 1
TitleLabel.Text = "[ HP ]"
TitleLabel.TextColor3 = COLORS.textGlow
TitleLabel.TextScaled = true
TitleLabel.Font = Enum.Font.Arcade
TitleLabel.TextStrokeTransparency = 0.5
TitleLabel.TextStrokeColor3 = COLORS.background
TitleLabel.Parent = HeaderBar

-- =====================================
-- BARRA DE VIDA - BACKGROUND
-- =====================================

local BarBackground = Instance.new("Frame")
BarBackground.Name = "BarBackground"
BarBackground.Size = UDim2.new(0.95, 0, 0.35, 0)
BarBackground.Position = UDim2.new(0.025, 0, 0.4, 0)
BarBackground.BackgroundColor3 = COLORS.barBackground
BarBackground.BorderColor3 = COLORS.border
BarBackground.BorderSizePixel = 2
BarBackground.Parent = MainContainer

-- =====================================
-- BARRA DE VIDA - PREENCHIMENTO
-- =====================================

local HealthBar = Instance.new("Frame")
HealthBar.Name = "HealthBar"
HealthBar.Size = UDim2.new(1, 0, 1, 0)
HealthBar.Position = UDim2.new(0, 0, 0, 0)
HealthBar.BackgroundColor3 = COLORS.healthHigh
HealthBar.BorderSizePixel = 0
HealthBar.Parent = BarBackground

-- =====================================
-- EFEITO DE BARRA PERDIDA (DELAY)
-- =====================================

local LostHealthBar = Instance.new("Frame")
LostHealthBar.Name = "LostHealthBar"
LostHealthBar.Size = UDim2.new(1, 0, 1, 0)
LostHealthBar.Position = UDim2.new(0, 0, 0, 0)
LostHealthBar.BackgroundColor3 = Color3.fromRGB(150, 0, 0)
LostHealthBar.BorderSizePixel = 0
LostHealthBar.ZIndex = BarBackground.ZIndex - 1
LostHealthBar.Parent = BarBackground

-- =====================================
-- TEXTO DE VIDA (VALOR NUMÉRICO)
-- =====================================

local HealthText = Instance.new("TextLabel")
HealthText.Name = "HealthText"
HealthText.Size = UDim2.new(1, 0, 0.3, 0)
HealthText.Position = UDim2.new(0, 0, 0.8, 0)
HealthText.BackgroundTransparency = 1
HealthText.Text = "100/100"
HealthText.TextColor3 = COLORS.textGlow
HealthText.TextScaled = true
HealthText.Font = Enum.Font.Arcade
HealthText.TextStrokeTransparency = 0.5
HealthText.TextStrokeColor3 = COLORS.background
HealthText.Parent = MainContainer

-- =====================================
-- INDICADOR DE STATUS (PIXEL ART)
-- =====================================

local StatusIndicator = Instance.new("Frame")
StatusIndicator.Name = "StatusIndicator"
StatusIndicator.Size = UDim2.new(0.08, 0, 0.25, 0)
StatusIndicator.Position = UDim2.new(0.01, 0, 0.425, 0)
StatusIndicator.BackgroundColor3 = COLORS.healthHigh
StatusIndicator.BorderColor3 = COLORS.border
StatusIndicator.BorderSizePixel = 1
StatusIndicator.Parent = MainContainer

-- =====================================
-- VARIÁVEIS DE CONTROLE
-- =====================================

local lastHealth = 100
local isBlinking = false

-- =====================================
-- FUNÇÃO: OBTER COR BASEADA NA VIDA
-- =====================================

local function getHealthColor(healthPercent)
	if healthPercent >= 0.75 then
		return COLORS.healthHigh
	elseif healthPercent >= 0.5 then
		return COLORS.healthMid
	elseif healthPercent >= 0.25 then
		return COLORS.healthLow
	else
		return COLORS.healthCritical
	end
end

-- =====================================
-- FUNÇÃO: EFEITO DE DANO (FLASH)
-- =====================================

local function createDamageFlash()
	-- Flash vermelho no container
	local originalBorder = MainContainer.BorderColor3
	MainContainer.BorderColor3 = COLORS.healthCritical

	task.wait(0.1)
	MainContainer.BorderColor3 = originalBorder
end

-- =====================================
-- FUNÇÃO: EFEITO DE CURA (FLASH VERDE)
-- =====================================

local function createHealFlash()
	local originalBorder = MainContainer.BorderColor3
	MainContainer.BorderColor3 = COLORS.healthHigh

	task.wait(0.1)
	MainContainer.BorderColor3 = originalBorder
end

-- =====================================
-- FUNÇÃO: PISCAR VIDA CRÍTICA
-- =====================================

local function startCriticalBlink()
	if isBlinking then
		return
	end
	isBlinking = true

	task.spawn(function()
		while isBlinking do
			-- Piscar borda
			MainContainer.BorderColor3 = COLORS.healthCritical
			StatusIndicator.BackgroundColor3 = COLORS.healthCritical
			task.wait(0.3)

			if not isBlinking then
				break
			end

			MainContainer.BorderColor3 = COLORS.border
			StatusIndicator.BackgroundColor3 = COLORS.barBackground
			task.wait(0.3)
		end
	end)
end

local function stopCriticalBlink()
	if not isBlinking then
		return
	end
	isBlinking = false

	MainContainer.BorderColor3 = COLORS.border
end

-- =====================================
-- FUNÇÃO PRINCIPAL: ATUALIZAR VIDA
-- =====================================

local function UpdateHealth()
	local character = Player.Character
	if not character then
		return
	end

	local humanoid = character:WaitForChild("Humanoid", 5)
	if not humanoid then
		return
	end

	local function updateHealthBar()
		local newHealth = humanoid.Health
		local maxHealth = humanoid.MaxHealth
		local healthPercent = newHealth / maxHealth

		-- Detectar mudança
		local wasHealed = newHealth > lastHealth
		local wasDamaged = newHealth < lastHealth

		-- Efeitos visuais
		if wasHealed then
			createHealFlash()
		elseif wasDamaged then
			createDamageFlash()
		end

		-- Obter cor baseada na vida
		local healthColor = getHealthColor(healthPercent)

		-- Animar barra de vida perdida (efeito de delay)
		if wasDamaged then
			task.spawn(function()
				task.wait(0.3) -- Delay antes de seguir a barra principal
				local lostTween = TweenService:Create(
					LostHealthBar,
					TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
					{ Size = UDim2.new(healthPercent, 0, 1, 0) }
				)
				lostTween:Play()
			end)
		else
			-- Se curou, atualizar imediatamente
			LostHealthBar.Size = UDim2.new(healthPercent, 0, 1, 0)
		end

		-- Animar barra principal
		local barTween = TweenService:Create(
			HealthBar,
			TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{
				Size = UDim2.new(healthPercent, 0, 1, 0),
				BackgroundColor3 = healthColor,
			}
		)
		barTween:Play()

		-- Atualizar indicador de status
		StatusIndicator.BackgroundColor3 = healthColor

		-- Atualizar texto
		HealthText.Text = string.format("%d/%d", math.floor(newHealth), math.floor(maxHealth))
		HealthText.TextColor3 = healthColor

		-- Sistema de piscar em vida crítica
		if healthPercent <= 0.2 then
			startCriticalBlink()
		else
			stopCriticalBlink()
		end

		-- Atualizar última vida
		lastHealth = newHealth
	end

	-- Conectar ao evento de mudança de vida
	humanoid.HealthChanged:Connect(updateHealthBar)

	-- Atualização inicial
	updateHealthBar()
end

-- =====================================
-- EFEITO DE PULSO NA BORDA (SEMPRE ATIVO)
-- =====================================

local function borderPulseEffect()
	task.spawn(function()
		local baseTransparency = 0
		local pulseTransparency = 0.3

		while HealthGui.Parent do
			-- Pulso sutil
			TweenService:Create(
				MainContainer,
				TweenInfo.new(1.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
				{ BackgroundTransparency = pulseTransparency }
			):Play()

			task.wait(1.5)

			TweenService:Create(
				MainContainer,
				TweenInfo.new(1.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
				{ BackgroundTransparency = baseTransparency }
			):Play()

			task.wait(1.5)
		end
	end)
end

-- =====================================
-- INICIALIZAÇÃO
-- =====================================

-- Iniciar efeito de pulso
borderPulseEffect()

-- Conectar ao personagem
Player.CharacterAdded:Connect(function(character)
	task.wait(0.5)
	UpdateHealth()
end)

-- Aplicar se personagem já existe
if Player.Character then
	UpdateHealth()
end

print([[
╔════════════════════════════════════════════════════╗
║  ✅ HEALTH DISPLAY V2 (RETRO STYLE) CARREGADO     ║
╠════════════════════════════════════════════════════╣
║  MUDANÇAS V2:                                      ║
║  • Visual 100% retro estilo anos 80/90           ║
║  • Fonte Arcade em todos os elementos             ║
║  • Bordas grossas (3px)                           ║
║  • Cores neon vibrantes                           ║
║  • Efeito de piscar em vida crítica               ║
║  • Barra de delay no dano (efeito visual)         ║
║  • Indicador de status por cor                    ║
║  • Flash de dano/cura                             ║
║  • Pulso sutil na borda                           ║
╠════════════════════════════════════════════════════╣
║  CORES POR NÍVEL DE VIDA:                         ║
║  • 100-75%: Verde Neon                            ║
║  • 74-50%:  Amarelo Neon                          ║
║  • 49-25%:  Laranja                               ║
║  • 24-0%:   Vermelho Neon (com piscar)           ║
╠════════════════════════════════════════════════════╣
║  EFEITOS:                                          ║
║  • Vida crítica (<20%): Borda pisca vermelho      ║
║  • Dano recebido: Flash vermelho                  ║
║  • Cura recebida: Flash verde                     ║
║  • Barra de delay mostra dano gradualmente        ║
╚════════════════════════════════════════════════════╝
]])
