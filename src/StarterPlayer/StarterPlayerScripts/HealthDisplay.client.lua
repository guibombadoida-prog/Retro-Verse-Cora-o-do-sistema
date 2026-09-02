-- ============================================
-- HEALTH DISPLAY V8.5 - HUD RESPONSIVO E ANIMADO
-- Coloque em StarterPlayer > StarterPlayerScripts
-- Nome: "HealthDisplay"
-- SUBSTITUI: HealthDisplay V7
-- ============================================
-- V8:
-- • layout único em pixels lógicos, redimensionado por UIScale para celular,
--   tablet e desktop sem deformar nem separar a barra de Despertar;
-- • respeita o inset superior mesmo com IgnoreGuiInset habilitado;
-- • cancela tweens antigos e atrasos de dano obsoletos;
-- • uma única animação coordena flashes, alertas e pulsos de borda;
-- • desconecta o Humanoid anterior ao renascer;
-- • puxa o estado inicial de Energia e Despertar depois de conectar aos remotes.
-- ============================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local GuiService = game:GetService("GuiService")
local Workspace = game:GetService("Workspace")

local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")

local COLORS = {
	background = Color3.fromRGB(0, 0, 0),
	border = Color3.fromRGB(255, 255, 255),
	healthHigh = Color3.fromRGB(0, 255, 0),
	healthMid = Color3.fromRGB(255, 255, 0),
	healthLow = Color3.fromRGB(255, 100, 0),
	healthCritical = Color3.fromRGB(255, 0, 0),
	barBackground = Color3.fromRGB(40, 40, 40),
	textGlow = Color3.fromRGB(0, 255, 255),
	energyHigh = Color3.fromRGB(0, 200, 255),
	energyLow = Color3.fromRGB(255, 140, 0),
	energyEmpty = Color3.fromRGB(120, 40, 40),
	awakening = Color3.fromRGB(180, 90, 255),
	awakened = Color3.fromRGB(255, 210, 70),
}

local LOW_ENERGY_THRESHOLD = 15
local HUD_WIDTH = 420
local MAIN_HEIGHT = 118
local AWAKEN_HEIGHT = 28
local HUD_GAP = 8
local HUD_HEIGHT = MAIN_HEIGHT + HUD_GAP + AWAKEN_HEIGHT

-- (V8.2) O tamanho do HUD virou constante com nome, porque é a coisa que
-- mais se ajusta neste arquivo e estava enterrada numa conta lá embaixo.
--
-- FRACAO_LARGURA e FRACAO_ALTURA são quanto da tela o HUD pode ocupar em
-- cada eixo. Quem manda é o menor dos dois, então o HUD encolhe pelo eixo
-- mais apertado em vez de estourar num deles.
--
-- Com estes valores ele fica entre 19% e 25% da largura, do celular
-- pequeno ao desktop. O V8.1 deixava entre 26% e 30%, que ainda era
-- grande demais para uma barra de vida: HUD é canto de tela, não painel.
--
-- Para deixar menor, baixe FRACAO_ALTURA — é ela que costuma limitar em
-- celular deitado. Não desça o piso de ESCALA_MIN muito abaixo de 0.46:
-- o texto tem UITextSizeConstraint com mínimo de 8 a 9 px e para de
-- caber.
local FRACAO_LARGURA = 0.23
local FRACAO_ALTURA = 0.16
local ESCALA_MIN = 0.46
local ESCALA_MAX = 0.85


-- Evita HUD duplicado quando o script é recarregado durante um teste.
local previousGui = PlayerGui:FindFirstChild("RetroHealthDisplay")
if previousGui then
	previousGui.Parent = nil
end

local HealthGui = Instance.new("ScreenGui")
HealthGui.Name = "RetroHealthDisplay"
HealthGui.ResetOnSpawn = false
HealthGui.IgnoreGuiInset = true
HealthGui.DisplayOrder = 5
HealthGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
HealthGui.Parent = PlayerGui

-- As duas faixas ficam no mesmo root. Assim o mesmo UIScale mantém largura,
-- alinhamento e espaçamento idênticos em qualquer proporção de tela.
local HudRoot = Instance.new("Frame")
HudRoot.Name = "HudRoot"
HudRoot.AnchorPoint = Vector2.new(0.5, 0)
HudRoot.Size = UDim2.fromOffset(HUD_WIDTH, HUD_HEIGHT)
HudRoot.BackgroundTransparency = 1
HudRoot.Parent = HealthGui

local ResponsiveScale = Instance.new("UIScale")
ResponsiveScale.Name = "ResponsiveScale"
ResponsiveScale.Scale = 1
ResponsiveScale.Parent = HudRoot

local MainContainer = Instance.new("Frame")
MainContainer.Name = "MainContainer"
MainContainer.Size = UDim2.fromOffset(HUD_WIDTH, MAIN_HEIGHT)
MainContainer.BackgroundColor3 = COLORS.background
MainContainer.BackgroundTransparency = 0.05
MainContainer.BorderSizePixel = 0
MainContainer.Parent = HudRoot

local MainStroke = Instance.new("UIStroke")
MainStroke.Name = "AnimatedStroke"
MainStroke.Color = COLORS.border
MainStroke.Thickness = 3
MainStroke.Parent = MainContainer

local HeaderBar = Instance.new("Frame")
HeaderBar.Name = "Header"
HeaderBar.Size = UDim2.new(1, 0, 0.2, 0)
HeaderBar.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
HeaderBar.BorderColor3 = COLORS.border
HeaderBar.BorderSizePixel = 2
HeaderBar.Parent = MainContainer

local TitleLabel = Instance.new("TextLabel")
TitleLabel.Name = "Title"
TitleLabel.Size = UDim2.fromScale(1, 1)
TitleLabel.BackgroundTransparency = 1
TitleLabel.Text = "[ HP ]"
TitleLabel.TextColor3 = COLORS.textGlow
TitleLabel.TextScaled = true
TitleLabel.Font = Enum.Font.Arcade
TitleLabel.TextStrokeTransparency = 0.5
TitleLabel.TextStrokeColor3 = COLORS.background
TitleLabel.Parent = HeaderBar

local TitleConstraint = Instance.new("UITextSizeConstraint")
TitleConstraint.MinTextSize = 10
TitleConstraint.MaxTextSize = 18
TitleConstraint.Parent = TitleLabel

local BarBackground = Instance.new("Frame")
BarBackground.Name = "BarBackground"
BarBackground.Size = UDim2.new(0.95, 0, 0.22, 0)
BarBackground.Position = UDim2.new(0.025, 0, 0.23, 0)
BarBackground.BackgroundColor3 = COLORS.barBackground
BarBackground.BorderColor3 = COLORS.border
BarBackground.BorderSizePixel = 2
BarBackground.ClipsDescendants = true
BarBackground.Parent = MainContainer

local LostHealthBar = Instance.new("Frame")
LostHealthBar.Name = "LostHealthBar"
LostHealthBar.Size = UDim2.fromScale(1, 1)
LostHealthBar.BackgroundColor3 = Color3.fromRGB(150, 0, 0)
LostHealthBar.BorderSizePixel = 0
LostHealthBar.ZIndex = 1
LostHealthBar.Parent = BarBackground

local HealthBar = Instance.new("Frame")
HealthBar.Name = "HealthBar"
HealthBar.Size = UDim2.fromScale(1, 1)
HealthBar.BackgroundColor3 = COLORS.healthHigh
HealthBar.BorderSizePixel = 0
HealthBar.ZIndex = 2
HealthBar.Parent = BarBackground

local HealthText = Instance.new("TextLabel")
HealthText.Name = "HealthText"
HealthText.Size = UDim2.new(1, 0, 0.16, 0)
HealthText.Position = UDim2.new(0, 0, 0.455, 0)
HealthText.BackgroundTransparency = 1
HealthText.Text = "100/100"
HealthText.TextColor3 = COLORS.textGlow
HealthText.TextScaled = true
HealthText.Font = Enum.Font.Arcade
HealthText.TextStrokeTransparency = 0.5
HealthText.TextStrokeColor3 = COLORS.background
HealthText.Parent = MainContainer

local HealthTextConstraint = Instance.new("UITextSizeConstraint")
HealthTextConstraint.MinTextSize = 9
HealthTextConstraint.MaxTextSize = 17
HealthTextConstraint.Parent = HealthText

-- (V8.1) O indicador ficava POR CIMA da barra de vida.
--
-- Ele ocupava X de 0.005 a 0.065 e a barra começa em 0.025, com o
-- indicador em ZIndex 3 contra o ZIndex 2 da barra — daí o quadradinho
-- colado na ponta esquerda do verde. A sobreposição vinha desde o V7 e
-- só ficou evidente quando o HUD passou a ser desenhado grande.
--
-- Ele foi para dentro do cabeçalho, à esquerda do título, onde havia
-- espaço vazio e onde um indicador de estado se lê melhor.
local StatusIndicator = Instance.new("Frame")
StatusIndicator.Name = "StatusIndicator"
StatusIndicator.Size = UDim2.new(0.05, 0, 0.55, 0)
StatusIndicator.Position = UDim2.new(0.02, 0, 0.225, 0)
StatusIndicator.BackgroundColor3 = COLORS.healthHigh
StatusIndicator.BorderColor3 = COLORS.border
StatusIndicator.BorderSizePixel = 1
StatusIndicator.ZIndex = 3
StatusIndicator.Parent = HeaderBar

-- Quadrado em qualquer proporção de tela, como manda o padrão do projeto.
local StatusRatio = Instance.new("UIAspectRatioConstraint")
StatusRatio.AspectRatio = 1
StatusRatio.DominantAxis = Enum.DominantAxis.Height
StatusRatio.Parent = StatusIndicator

local EnergyBackground = Instance.new("Frame")
EnergyBackground.Name = "EnergyBackground"
EnergyBackground.Size = UDim2.new(0.95, 0, 0.2, 0)
EnergyBackground.Position = UDim2.new(0.025, 0, 0.63, 0)
EnergyBackground.BackgroundColor3 = COLORS.barBackground
EnergyBackground.BorderSizePixel = 0
EnergyBackground.ClipsDescendants = true
EnergyBackground.Visible = false
EnergyBackground.Parent = MainContainer

local EnergyStroke = Instance.new("UIStroke")
EnergyStroke.Name = "AnimatedStroke"
EnergyStroke.Color = COLORS.border
EnergyStroke.Thickness = 2
EnergyStroke.Parent = EnergyBackground

local EnergyBar = Instance.new("Frame")
EnergyBar.Name = "EnergyBar"
EnergyBar.Size = UDim2.fromScale(1, 1)
EnergyBar.BackgroundColor3 = COLORS.energyHigh
EnergyBar.BorderSizePixel = 0
EnergyBar.Parent = EnergyBackground

local EnergyText = Instance.new("TextLabel")
EnergyText.Name = "EnergyText"
EnergyText.Size = UDim2.new(1, 0, 0.15, 0)
EnergyText.Position = UDim2.new(0, 0, 0.845, 0)
EnergyText.BackgroundTransparency = 1
EnergyText.Text = ""
EnergyText.TextColor3 = COLORS.energyHigh
EnergyText.TextScaled = true
EnergyText.Font = Enum.Font.Arcade
EnergyText.TextStrokeTransparency = 0.5
EnergyText.TextStrokeColor3 = COLORS.background
EnergyText.Visible = false
EnergyText.Parent = MainContainer

local EnergyTextConstraint = Instance.new("UITextSizeConstraint")
EnergyTextConstraint.MinTextSize = 8
EnergyTextConstraint.MaxTextSize = 15
EnergyTextConstraint.Parent = EnergyText

local AwakenBackground = Instance.new("Frame")
AwakenBackground.Name = "AwakenBackground"
AwakenBackground.Size = UDim2.fromOffset(HUD_WIDTH, AWAKEN_HEIGHT)
AwakenBackground.Position = UDim2.fromOffset(0, MAIN_HEIGHT + HUD_GAP)
AwakenBackground.BackgroundColor3 = COLORS.barBackground
AwakenBackground.BorderSizePixel = 0
AwakenBackground.ClipsDescendants = true
AwakenBackground.Visible = false
AwakenBackground.Parent = HudRoot

local AwakenStroke = Instance.new("UIStroke")
AwakenStroke.Name = "AnimatedStroke"
AwakenStroke.Color = COLORS.border
AwakenStroke.Thickness = 2
AwakenStroke.Parent = AwakenBackground

local AwakenBar = Instance.new("Frame")
AwakenBar.Name = "AwakenBar"
AwakenBar.Size = UDim2.new(0, 0, 1, 0)
AwakenBar.BackgroundColor3 = COLORS.awakening
AwakenBar.BorderSizePixel = 0
AwakenBar.Parent = AwakenBackground

local AwakenText = Instance.new("TextLabel")
AwakenText.Name = "AwakenText"
AwakenText.Size = UDim2.fromScale(1, 1)
AwakenText.BackgroundTransparency = 1
AwakenText.Text = ""
AwakenText.TextColor3 = Color3.fromRGB(255, 255, 255)
AwakenText.TextScaled = true
AwakenText.Font = Enum.Font.Arcade
AwakenText.TextStrokeTransparency = 0.4
AwakenText.TextStrokeColor3 = COLORS.background
AwakenText.ZIndex = 3
AwakenText.Parent = AwakenBackground

local AwakenTextConstraint = Instance.new("UITextSizeConstraint")
AwakenTextConstraint.MinTextSize = 8
AwakenTextConstraint.MaxTextSize = 14
AwakenTextConstraint.Parent = AwakenText

-- =====================================
-- CICLO DE VIDA E TWEENS CANCELÁVEIS
-- =====================================

local alive = true
local connections = {}
local activeTweens = {}
local disconnectHumanoid

local function track(connection)
	table.insert(connections, connection)
	return connection
end

local function playTween(key, target, info, properties)
	local previous = activeTweens[key]
	if previous then
		previous:Cancel()
	end

	local tween = TweenService:Create(target, info, properties)
	activeTweens[key] = tween
	tween:Play()
	return tween
end

local function cleanup()
	if not alive then
		return
	end
	alive = false
	if disconnectHumanoid then
		disconnectHumanoid()
	end

	for _, connection in ipairs(connections) do
		connection:Disconnect()
	end
	table.clear(connections)

	for _, tween in pairs(activeTweens) do
		tween:Cancel()
	end
	table.clear(activeTweens)
end

track(HealthGui.AncestryChanged:Connect(function(_, parent)
	if parent == nil then
		cleanup()
	end
end))

-- =====================================
-- LAYOUT RESPONSIVO
-- =====================================

local viewportConnection

local function getTopInset()
	local ok, inset = pcall(function()
		local topLeftInset = GuiService:GetGuiInset()
		return topLeftInset
	end)
	if ok and typeof(inset) == "Vector2" then
		return inset.Y
	end
	return 0
end

local function applyResponsiveLayout()
	local camera = Workspace.CurrentCamera
	local viewport = camera and camera.ViewportSize or Vector2.new(1280, 720)

	-- Cada eixo recebe uma fração da tela e vale a menor das duas escalas,
	-- para o HUD encolher pelo eixo mais apertado em vez de estourar nele.
	--
	-- A conta original era `viewport.X - 24`, que tratava a tela INTEIRA
	-- como espaço do HUD: em celular deitado isso nunca limitava nada, o
	-- min() caía sempre na altura e o resultado batia no teto, saindo no
	-- tamanho máximo em todo aparelho grande.
	local widthScale = math.max(1, viewport.X * FRACAO_LARGURA) / HUD_WIDTH
	local heightScale = math.max(1, viewport.Y * FRACAO_ALTURA) / HUD_HEIGHT
	ResponsiveScale.Scale =
		math.clamp(math.min(widthScale, heightScale), ESCALA_MIN, ESCALA_MAX)
	HudRoot.Position = UDim2.new(0.5, 0, 0, getTopInset() + 8)
end

local function bindViewport()
	if viewportConnection then
		viewportConnection:Disconnect()
		viewportConnection = nil
	end

	local camera = Workspace.CurrentCamera
	if camera then
		viewportConnection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(applyResponsiveLayout)
		table.insert(connections, viewportConnection)
	end
	applyResponsiveLayout()
end

track(Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(bindViewport))
bindViewport()

-- =====================================
-- ESTADO VISUAL E ANIMAÇÃO COORDENADA
-- =====================================

local healthCritical = false
local healthColor = COLORS.healthHigh
local energyWarning = false
local energyRegenerating = false
local energyColor = COLORS.energyHigh
local awakenMode = "hidden"
local mainFlashColor
local mainFlashUntil = 0

local function flashMain(color, duration)
	mainFlashColor = color
	mainFlashUntil = os.clock() + duration
end

track(RunService.RenderStepped:Connect(function()
	local now = os.clock()
	local slowPulse = 0.5 + 0.5 * math.sin(now * 2.8)
	local fastPulse = 0.5 + 0.5 * math.sin(now * 8)

	MainContainer.BackgroundTransparency = 0.04 + slowPulse * 0.08

	if mainFlashColor and now < mainFlashUntil then
		MainStroke.Color = mainFlashColor
		MainStroke.Thickness = 4
	elseif healthCritical then
		MainStroke.Color = COLORS.border:Lerp(COLORS.healthCritical, fastPulse)
		MainStroke.Thickness = 3 + fastPulse
	else
		mainFlashColor = nil
		MainStroke.Color = COLORS.border:Lerp(COLORS.textGlow, slowPulse * 0.18)
		MainStroke.Thickness = 3
	end

	if healthCritical then
		StatusIndicator.BackgroundColor3 = COLORS.barBackground:Lerp(healthColor, fastPulse)
	else
		StatusIndicator.BackgroundColor3 = healthColor
	end

	if energyWarning then
		EnergyStroke.Color = COLORS.border:Lerp(COLORS.energyLow, fastPulse)
		EnergyStroke.Transparency = 0.05 + (1 - fastPulse) * 0.2
	else
		EnergyStroke.Color = COLORS.border:Lerp(COLORS.energyHigh, energyRegenerating and slowPulse * 0.55 or 0)
		EnergyStroke.Transparency = 0
	end
	EnergyBar.BackgroundTransparency = energyRegenerating and (0.02 + slowPulse * 0.12) or 0

	if awakenMode == "transforming" then
		AwakenStroke.Color = COLORS.border:Lerp(COLORS.textGlow, fastPulse)
		AwakenBar.BackgroundTransparency = 0.05 + fastPulse * 0.2
	elseif awakenMode == "awakened" then
		AwakenStroke.Color = COLORS.border:Lerp(COLORS.awakened, fastPulse)
		AwakenBar.BackgroundTransparency = 0.02 + slowPulse * 0.12
	elseif awakenMode == "charging" then
		AwakenStroke.Color = COLORS.border:Lerp(COLORS.awakening, slowPulse * 0.45)
		AwakenBar.BackgroundTransparency = 0
	else
		AwakenStroke.Color = COLORS.border
		AwakenBar.BackgroundTransparency = 0
	end
end))

-- =====================================
-- VIDA
-- =====================================

local function getHealthColor(percent)
	if percent >= 0.75 then
		return COLORS.healthHigh
	elseif percent >= 0.5 then
		return COLORS.healthMid
	elseif percent >= 0.25 then
		return COLORS.healthLow
	end
	return COLORS.healthCritical
end

local currentHumanoid
local healthConnection
local maxHealthConnection
local bindGeneration = 0
local healthRevision = 0
local lastHealth

disconnectHumanoid = function()
	bindGeneration += 1
	healthRevision += 1
	currentHumanoid = nil
	lastHealth = nil
	healthCritical = false

	if healthConnection then
		healthConnection:Disconnect()
		healthConnection = nil
	end
	if maxHealthConnection then
		maxHealthConnection:Disconnect()
		maxHealthConnection = nil
	end
end

local function bindCharacter(character)
	disconnectHumanoid()
	local generation = bindGeneration
	local humanoid = character:WaitForChild("Humanoid", 5)

	if not alive or not humanoid or generation ~= bindGeneration or Player.Character ~= character then
		return
	end

	currentHumanoid = humanoid
	lastHealth = humanoid.Health

	local function updateHealthBar(skipEffects)
		if humanoid ~= currentHumanoid then
			return
		end

		local newHealth = math.max(0, tonumber(humanoid.Health) or 0)
		local maxHealth = math.max(1, tonumber(humanoid.MaxHealth) or 1)
		local percent = math.clamp(newHealth / maxHealth, 0, 1)
		local wasHealed = not skipEffects and lastHealth ~= nil and newHealth > lastHealth
		local wasDamaged = not skipEffects and lastHealth ~= nil and newHealth < lastHealth

		healthRevision += 1
		local revision = healthRevision
		healthColor = getHealthColor(percent)
		healthCritical = percent <= 0.2 and newHealth > 0

		if wasHealed then
			flashMain(COLORS.healthHigh, 0.14)
		elseif wasDamaged then
			flashMain(COLORS.healthCritical, 0.16)
		end

		if wasDamaged then
			task.delay(0.28, function()
				if alive and humanoid == currentHumanoid and revision == healthRevision then
					playTween(
						"lostHealth",
						LostHealthBar,
						TweenInfo.new(0.55, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
						{ Size = UDim2.new(percent, 0, 1, 0) }
					)
				end
			end)
		else
			local oldLostTween = activeTweens.lostHealth
			if oldLostTween then
				oldLostTween:Cancel()
			end
			LostHealthBar.Size = UDim2.new(percent, 0, 1, 0)
		end

		playTween(
			"healthBar",
			HealthBar,
			TweenInfo.new(0.2, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
			{
				Size = UDim2.new(percent, 0, 1, 0),
				BackgroundColor3 = healthColor,
			}
		)

		HealthText.Text = string.format("%d/%d", math.floor(newHealth), math.floor(maxHealth))
		HealthText.TextColor3 = healthColor
		lastHealth = newHealth
	end

	healthConnection = humanoid.HealthChanged:Connect(function()
		updateHealthBar(false)
	end)
	maxHealthConnection = humanoid:GetPropertyChangedSignal("MaxHealth"):Connect(function()
		updateHealthBar(true)
	end)
	updateHealthBar(true)
end

track(Player.CharacterAdded:Connect(function(character)
	task.defer(bindCharacter, character)
end))

track(Player.CharacterRemoving:Connect(function(character)
	if currentHumanoid and currentHumanoid:IsDescendantOf(character) then
		disconnectHumanoid()
	end
end))

if Player.Character then
	task.defer(bindCharacter, Player.Character)
end

-- =====================================
-- ENERGIA
-- =====================================

local function getEnergyColor(current)
	if current <= 0 then
		return COLORS.energyEmpty
	elseif current < LOW_ENERGY_THRESHOLD then
		return COLORS.energyLow
	end
	return COLORS.energyHigh
end

local function updateEnergy(payload)
	if type(payload) ~= "table" then
		return
	end

	local current = math.max(0, tonumber(payload.current) or 0)
	local maxValue = math.max(1, tonumber(payload.max) or 100)
	local percent = math.clamp(current / maxValue, 0, 1)
	local effectiveRegen = math.max(0, tonumber(payload.effectiveRegen) or 0)

	EnergyBackground.Visible = true
	EnergyText.Visible = true
	energyColor = getEnergyColor(current)
	energyWarning = current < LOW_ENERGY_THRESHOLD
	energyRegenerating = payload.regenerating == true and current < maxValue

	playTween(
		"energyBar",
		EnergyBar,
		TweenInfo.new(0.24, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
		{
			Size = UDim2.new(percent, 0, 1, 0),
			BackgroundColor3 = energyColor,
		}
	)

	if current <= 0 then
		EnergyText.Text = "SEM ENERGIA"
	elseif energyRegenerating and effectiveRegen > 0 then
		EnergyText.Text = string.format(
			"EN %d/%d  +%.1f/s",
			math.floor(current),
			math.floor(maxValue),
			effectiveRegen
		)
	else
		EnergyText.Text = string.format("EN %d/%d", math.floor(current), math.floor(maxValue))
	end
	EnergyText.TextColor3 = energyColor
end

task.spawn(function()
	local remotes = ReplicatedStorage:WaitForChild("Remotes", 20)
	if not remotes or not alive then
		warn("[HEALTH V8] Pasta Remotes não encontrada — energia desativada")
		return
	end

	local energyUpdate = remotes:WaitForChild("EnergyUpdate", 20)
	if not energyUpdate or not alive then
		warn("[HEALTH V8] EnergyUpdate não encontrado — energia desativada")
		return
	end

	track(energyUpdate.OnClientEvent:Connect(updateEnergy))

	-- O primeiro FireClient pode ocorrer antes deste LocalScript carregar.
	-- Puxa o snapshot depois de já estar escutando para fechar essa janela.
	local getEnergyState = remotes:FindFirstChild("GetEnergyState")
	if getEnergyState and getEnergyState:IsA("RemoteFunction") then
		for _ = 1, 4 do
			local ok, snapshot = pcall(function()
				return getEnergyState:InvokeServer()
			end)
			if ok and type(snapshot) == "table" then
				updateEnergy(snapshot)
				break
			end
			task.wait(0.25)
		end
	end

	local energyDepleted = remotes:FindFirstChild("EnergyDepleted")
	if energyDepleted and energyDepleted:IsA("RemoteEvent") then
		track(energyDepleted.OnClientEvent:Connect(function()
			flashMain(COLORS.energyLow, 0.2)
		end))
	end
end)

-- =====================================
-- DESPERTAR
-- =====================================

local function updateAwakening(data)
	if type(data) ~= "table" then
		return
	end

	if not data.ativo then
		awakenMode = "hidden"
		AwakenBackground.Visible = false
		return
	end

	AwakenBackground.Visible = true
	local maxValue = math.max(1, tonumber(data.max) or 100)
	local fraction = math.clamp((tonumber(data.valor) or 0) / maxValue, 0, 1)
	local targetSize = fraction
	local targetColor = COLORS.awakening

	if data.transformando then
		awakenMode = "transforming"
		targetSize = 1
		targetColor = Color3.fromRGB(255, 255, 255)
		AwakenText.Text = string.format(
			"TRANSFORMANDO  %.1fs",
			math.max(0, tonumber(data.transformandoRestante) or 0)
		)
	elseif data.desperto then
		awakenMode = "awakened"
		targetSize = 1
		targetColor = COLORS.awakened
		AwakenText.Text = string.format("DESPERTO  %.0fs", math.max(0, tonumber(data.restante) or 0))
	elseif (tonumber(data.cooldown) or 0) > 0 then
		awakenMode = "cooldown"
		targetSize = 0
		AwakenText.Text = string.format("RECARGA  %.0fs", math.max(0, tonumber(data.cooldown) or 0))
	else
		awakenMode = "charging"
		targetColor = fraction >= 1 and COLORS.awakened or COLORS.awakening
		AwakenText.Text = string.format("DESPERTAR  %d%%", math.floor(fraction * 100))
	end

	playTween(
		"awakenBar",
		AwakenBar,
		TweenInfo.new(0.25, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
		{
			Size = UDim2.new(targetSize, 0, 1, 0),
			BackgroundColor3 = targetColor,
		}
	)
end

task.spawn(function()
	local remotes = ReplicatedStorage:WaitForChild("Remotes", 30)
	local meterUpdate = remotes and remotes:WaitForChild("AwakeningMeterUpdate", 30)
	if not meterUpdate or not alive then
		warn("[HEALTH V8] AwakeningMeterUpdate não encontrado — Despertar desativado")
		return
	end

	track(meterUpdate.OnClientEvent:Connect(updateAwakening))

	local pull = remotes:FindFirstChild("GetAwakeningMeter")
	if pull and pull:IsA("RemoteFunction") then
		local ok, snapshot = pcall(function()
			return pull:InvokeServer()
		end)
		if ok then
			updateAwakening(snapshot)
		end
	end
end)

print("[HEALTH V8] HUD responsivo de vida, energia e Despertar carregado")
