-- ============================================
-- HEALTH DISPLAY V4 - RETRO STYLE + BARRA DE ENERGIA
-- Coloque em StarterPlayer > StarterPlayerScripts
-- Nome: "HealthDisplay"
-- SUBSTITUI: HealthDisplay V3
-- REMOVER:   HealthDisplay V3
-- ============================================
-- (V4) ALTERAÇÕES:
-- • 🆕 BARRA DE ENERGIA colada embaixo do HP. Energia é informação
--   de COMBATE (o jogador precisa ver na hora de atacar), então não
--   pode ficar atrás de dois cliques no menu — fica no HUD, do lado
--   da vida, usando a mesma paleta neon.
-- • Escuta o remote "EnergyUpdate" (EnergySystemServer V1). Se o
--   remote não existir, a barra simplesmente NÃO aparece e o HP
--   funciona igual ao V3 — o script não quebra sem o sistema novo.
-- • Pisca em laranja quando a energia está baixa demais pra usar
--   Tool, e mostra "SEM ENERGIA" quando zera (remote EnergyDepleted).
-- • Container ficou mais alto (0.08 -> 0.12) pra caber a 2ª barra.
-- • ⚠️ CORREÇÃO DO V3: createDamageFlash/createHealFlash usavam
--   task.wait() DENTRO do handler de HealthChanged, o que segurava
--   o evento por 0.1s a cada dano. Agora rodam em task.spawn.
--
-- REUTILIZAÇÃO: toda a estrutura de barra, cores neon, tween e
-- efeito de piscar vem do próprio HealthDisplay V3.
-- ============================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
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
	-- (V4) energia
	energyHigh = Color3.fromRGB(0, 200, 255), -- Azul neon
	energyLow = Color3.fromRGB(255, 140, 0), -- Laranja (não dá pra atacar)
	energyEmpty = Color3.fromRGB(120, 40, 40), -- Vermelho escuro
}

-- (V4) Abaixo disso a maioria das Tools já não ativa (custo padrão 15)
local LOW_ENERGY_THRESHOLD = 15

-- =====================================
-- CRIAR SCREENGUI
-- =====================================

local HealthGui = Instance.new("ScreenGui")
HealthGui.Name = "RetroHealthDisplay"
HealthGui.ResetOnSpawn = false
HealthGui.IgnoreGuiInset = true -- (V4) regra de GUI do projeto
HealthGui.DisplayOrder = 5
HealthGui.Parent = Player.PlayerGui

-- =====================================
-- CONTAINER PRINCIPAL
-- =====================================

local MainContainer = Instance.new("Frame")
MainContainer.Name = "MainContainer"
MainContainer.Size = UDim2.new(0.25, 0, 0.12, 0) -- (V4) era 0.08
-- (V4) Y = 0.06: com IgnoreGuiInset = true a tela passa a incluir a
-- barra superior do Roblox, então desce um pouco pra não ficar
-- embaixo dela. Ajuste fino aqui se ficar alto/baixo demais.
MainContainer.Position = UDim2.new(0.375, 0, 0.06, 0)
MainContainer.BackgroundColor3 = COLORS.background
MainContainer.BorderColor3 = COLORS.border
MainContainer.BorderSizePixel = 3
MainContainer.Parent = HealthGui

-- =====================================
-- HEADER (TÍTULO)
-- =====================================

local HeaderBar = Instance.new("Frame")
HeaderBar.Name = "Header"
HeaderBar.Size = UDim2.new(1, 0, 0.2, 0) -- (V4) reposicionado
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
BarBackground.Size = UDim2.new(0.95, 0, 0.22, 0)
BarBackground.Position = UDim2.new(0.025, 0, 0.23, 0) -- (V4)
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
HealthText.Size = UDim2.new(1, 0, 0.16, 0)
HealthText.Position = UDim2.new(0, 0, 0.455, 0) -- (V4)
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
StatusIndicator.Size = UDim2.new(0.06, 0, 0.16, 0)
StatusIndicator.Position = UDim2.new(0.005, 0, 0.26, 0) -- (V4)
StatusIndicator.BackgroundColor3 = COLORS.healthHigh
StatusIndicator.BorderColor3 = COLORS.border
StatusIndicator.BorderSizePixel = 1
StatusIndicator.Parent = MainContainer

-- =====================================
-- (V4) BARRA DE ENERGIA
-- =====================================

local EnergyBackground = Instance.new("Frame")
EnergyBackground.Name = "EnergyBackground"
EnergyBackground.Size = UDim2.new(0.95, 0, 0.2, 0)
EnergyBackground.Position = UDim2.new(0.025, 0, 0.63, 0)
EnergyBackground.BackgroundColor3 = COLORS.barBackground
EnergyBackground.BorderColor3 = COLORS.border
EnergyBackground.BorderSizePixel = 2
EnergyBackground.Visible = false -- só aparece quando o servidor mandar dados
EnergyBackground.Parent = MainContainer

local EnergyBar = Instance.new("Frame")
EnergyBar.Name = "EnergyBar"
EnergyBar.Size = UDim2.new(1, 0, 1, 0)
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

-- =====================================
-- VARIÁVEIS DE CONTROLE
-- =====================================

local lastHealth = 100
local isBlinking = false
local energyBlinking = false

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
	-- (V4) task.spawn: antes o task.wait segurava o HealthChanged
	task.spawn(function()
		local originalBorder = MainContainer.BorderColor3
		MainContainer.BorderColor3 = COLORS.healthCritical
		task.wait(0.1)
		if not isBlinking then
			MainContainer.BorderColor3 = originalBorder
		end
	end)
end

-- =====================================
-- FUNÇÃO: EFEITO DE CURA (FLASH VERDE)
-- =====================================

local function createHealFlash()
	-- (V4) task.spawn: antes o task.wait segurava o HealthChanged
	task.spawn(function()
		local originalBorder = MainContainer.BorderColor3
		MainContainer.BorderColor3 = COLORS.healthHigh
		task.wait(0.1)
		if not isBlinking then
			MainContainer.BorderColor3 = originalBorder
		end
	end)
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
-- (V4) ENERGIA
-- =====================================

local function getEnergyColor(current, max)
	if current <= 0 then
		return COLORS.energyEmpty
	elseif current < LOW_ENERGY_THRESHOLD then
		return COLORS.energyLow
	end
	return COLORS.energyHigh
end

local function startEnergyBlink()
	if energyBlinking then
		return
	end
	energyBlinking = true

	task.spawn(function()
		while energyBlinking do
			EnergyBackground.BorderColor3 = COLORS.energyLow
			task.wait(0.35)
			if not energyBlinking then
				break
			end
			EnergyBackground.BorderColor3 = COLORS.border
			task.wait(0.35)
		end
		EnergyBackground.BorderColor3 = COLORS.border
	end)
end

local function stopEnergyBlink()
	if not energyBlinking then
		return
	end
	energyBlinking = false
	EnergyBackground.BorderColor3 = COLORS.border
end

local function updateEnergy(payload)
	if type(payload) ~= "table" then
		return
	end

	local current = tonumber(payload.current) or 0
	local max = math.max(1, tonumber(payload.max) or 100)
	local percent = math.clamp(current / max, 0, 1)

	-- Primeira atualização: revela a barra
	if not EnergyBackground.Visible then
		EnergyBackground.Visible = true
		EnergyText.Visible = true
	end

	local color = getEnergyColor(current, max)

	TweenService:Create(
		EnergyBar,
		TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{
			Size = UDim2.new(percent, 0, 1, 0),
			BackgroundColor3 = color,
		}
	):Play()

	if current <= 0 then
		EnergyText.Text = "SEM ENERGIA"
	else
		EnergyText.Text = string.format("EN %d/%d", math.floor(current), math.floor(max))
	end
	EnergyText.TextColor3 = color

	-- Pisca enquanto não dá pra usar Tool
	if current < LOW_ENERGY_THRESHOLD then
		startEnergyBlink()
	else
		stopEnergyBlink()
	end
end

-- Conexão com o EnergySystemServer V1.
-- Se o sistema não estiver instalado, a barra não aparece e o HP
-- continua funcionando normalmente (compatível com o V3).
task.spawn(function()
	local remotes = ReplicatedStorage:WaitForChild("Remotes", 20)
	if not remotes then
		warn("[HEALTH V4] Pasta Remotes não encontrada — barra de energia desativada")
		return
	end

	local energyUpdate = remotes:WaitForChild("EnergyUpdate", 20)
	if not energyUpdate then
		warn("[HEALTH V4] EnergyUpdate não encontrado — EnergySystemServer V1 está instalado?")
		return
	end

	energyUpdate.OnClientEvent:Connect(updateEnergy)

	local energyDepleted = remotes:WaitForChild("EnergyDepleted", 10)
	if energyDepleted then
		energyDepleted.OnClientEvent:Connect(function()
			-- Flash laranja na borda ao esgotar
			task.spawn(function()
				local original = MainContainer.BorderColor3
				MainContainer.BorderColor3 = COLORS.energyLow
				task.wait(0.15)
				if not isBlinking then
					MainContainer.BorderColor3 = original
				end
			end)
		end)
	end

	print("[HEALTH V4] Barra de energia conectada")
end)

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
║  ✅ HEALTH DISPLAY V4 (HP + ENERGIA) CARREGADO    ║
╠════════════════════════════════════════════════════╣
║  SUBSTITUI: HealthDisplay V3                       ║
║  REMOVER:   HealthDisplay V3                       ║
╠════════════════════════════════════════════════════╣
║  NOVO NO V4:                                       ║
║  • Barra de ENERGIA abaixo do HP                  ║
║  • Pisca laranja com energia baixa                ║
║  • "SEM ENERGIA" quando zera                      ║
║  • Sem EnergySystemServer, a barra some e o HP    ║
║    funciona igual ao V3                           ║
║  • Correção: flash de dano não segura mais o      ║
║    evento HealthChanged                           ║
╠════════════════════════════════════════════════════╣
║  MANTIDO DO V3:                                    ║
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
