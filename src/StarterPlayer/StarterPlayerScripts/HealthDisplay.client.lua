-- ============================================
-- HEALTH DISPLAY V8 - VIDA + ENERGIA + BARRA DE DESPERTAR
-- Coloque em StarterPlayer > StarterPlayerScripts
-- Nome: "HealthDisplay"
-- SUBSTITUI: HealthDisplay (V7)
-- (V8) Camada de animação reescrita. Quatro defeitos:
--      1. VAZAMENTO: borderPulseEffect criava 2 tweens a cada 3s num
--         laço `while` sem fim — e o ScreenGui tem ResetOnSpawn = false,
--         então nunca acabava. Virou 1 tween com RepeatCount = -1.
--      2. BORDA PRESA: 5 funções escreviam em BorderColor3 salvando e
--         restaurando a cor. Dois flashes em menos de 0.1s faziam o
--         segundo salvar a cor do primeiro como "original" e a borda
--         ficava presa. Agora só atualizarBorda() escreve nela.
--      3. BARRA TREMENDO: a vida perdida animava dentro de task.spawn
--         com task.wait(0.3). Cada golpe abria uma thread e todas
--         disputavam a mesma barra. O atraso agora é DelayTime do
--         TweenInfo, sem thread.
--      4. FORMA DEFORMADA: o indicador de status é pixel art definida
--         só em Scale, virando retângulo em cada proporção de celular.
--         Ganhou UIAspectRatioConstraint.
--      A barra de Despertar deixou de depender do número fixo Y 0.187 e
--      passou a ser filha do MainContainer, ancorada abaixo dele.
-- (V7) Mostra a janela de TRANSFORMANDO: o jogador fica desarmado por
--      alguns segundos enquanto a forma troca, nos dois sentidos. Sem
--      indicação na tela isso parece travamento.
-- (V6) A BARRA DE DESPERTAR NÃO APARECIA. Duas causas:
--      1. Ela estava dentro do MainContainer, em Y 0.845 com altura
--         0.2 — exatamente em cima do EnergyText (0.845 a 0.995) e
--         passando de 1.0, ou seja, metade fora do container. Virou
--         faixa própria logo abaixo dele.
--      2. O cliente só ESCUTAVA o estado. O pacote inicial do servidor
--         saía enquanto este script ainda esperava o remote aparecer, se
--         perdia, e depois nada mais mudava — nenhum outro pacote vinha.
--         Agora ele PUXA o estado (GetAwakeningMeter) assim que conecta.
-- (V5) BARRA DE DESPERTAR: enche batendo e apanhando; cheia, troca as
--      Tools para a forma despertada por um tempo. Números vindos do
--      AwakeningMeterServer.
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
-- (V8) GERENCIADOR DE TWEENS
-- =====================================
-- O V7 criava um tween novo a cada evento e nunca cancelava nenhum. Em
-- combate, uma sequência de golpes deixava vários tweens vivos disputando
-- a mesma barra, e ela tremia em vez de deslizar.
--
-- Aqui cada alvo animável tem uma CHAVE. Só existe um tween por chave: o
-- anterior é cancelado antes do novo nascer.
local tweensAtivos = {}

local function animar(chave, objeto, info, propriedades)
	local anterior = tweensAtivos[chave]
	if anterior then
		anterior:Cancel()
	end
	local tween = TweenService:Create(objeto, info, propriedades)
	tweensAtivos[chave] = tween
	tween:Play()
	return tween
end

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

-- (V8) O indicador é pixel art: precisa ser QUADRADO. Definido só em
-- Scale (0.06 x 0.16 do container), ele virava um retângulo diferente em
-- cada proporção de celular. A constraint trava a forma e deixa a altura
-- mandar na largura.
local StatusRatio = Instance.new("UIAspectRatioConstraint")
StatusRatio.AspectRatio = 1
StatusRatio.DominantAxis = Enum.DominantAxis.Height
StatusRatio.Parent = StatusIndicator

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
-- (V5) BARRA DE DESPERTAR
-- =====================================
-- Enche batendo e apanhando. Cheia, o personagem troca para a forma
-- despertada por um tempo; depois volta ao normal e entra em cooldown.
-- Quem manda os números é o AwakeningMeterServer.
--
-- Só aparece quando o personagem equipado TEM Despertar — personagem
-- sem forma despertada não mostra barra nenhuma.

-- ⚠️ FICA FORA DO MainContainer, DE PROPÓSITO.
--
-- O container já está lotado: HealthText em 0.455, StatusIndicator em
-- 0.26, EnergyBackground em 0.63 e EnergyText de 0.845 a 0.995. A
-- primeira versão desta barra ficou em 0.845 com altura 0.2, ou seja,
-- exatamente por cima do texto de energia e passando de 1.0 — metade
-- dela caía fora do container.
--
-- Aqui ela vira uma faixa própria logo abaixo do container.
--
-- (V8) Ela era filha do ScreenGui, na posição fixa Y 0.187 — número
-- calculado à mão a partir do MainContainer (0.06 + 0.12 = 0.18). Qualquer
-- ajuste no container desgrudava as duas em silêncio, e foi assim que a
-- barra sumiu no V5.
--
-- Agora ela é FILHA do container, ancorada logo abaixo dele: 1 = a base do
-- pai, mais 4px de respiro. Mexer no container leva a barra junto.
-- As medidas equivalem exatamente às antigas — largura 0.25 da tela é 1.0
-- de um pai que mede 0.25; altura 0.028 da tela é 0.2333 de um pai que
-- mede 0.12.
local AwakenBackground = Instance.new("Frame")
AwakenBackground.Name = "AwakenBackground"
AwakenBackground.Size = UDim2.new(1, 0, 0.2333, 0)
AwakenBackground.Position = UDim2.new(0, 0, 1, 4)
AwakenBackground.BackgroundColor3 = COLORS.barBackground
AwakenBackground.BorderColor3 = COLORS.border
AwakenBackground.BorderSizePixel = 2
AwakenBackground.Visible = false
AwakenBackground.Parent = MainContainer

local AwakenBar = Instance.new("Frame")
AwakenBar.Name = "AwakenBar"
AwakenBar.Size = UDim2.new(0, 0, 1, 0)
AwakenBar.BackgroundColor3 = Color3.fromRGB(180, 90, 255)
AwakenBar.BorderSizePixel = 0
AwakenBar.Parent = AwakenBackground

local AwakenText = Instance.new("TextLabel")
AwakenText.Name = "AwakenText"
AwakenText.Size = UDim2.new(1, 0, 1, 0)
AwakenText.BackgroundTransparency = 1
AwakenText.Text = ""
-- (V8) Era `COLORS.text or ...`, e COLORS.text nunca existiu nesta
-- tabela — o texto vinha branco pelo fallback, por acidente.
AwakenText.TextColor3 = COLORS.textGlow
AwakenText.TextScaled = true
AwakenText.Font = Enum.Font.Arcade
AwakenText.TextStrokeTransparency = 0.4
AwakenText.TextStrokeColor3 = COLORS.background
AwakenText.ZIndex = 3
AwakenText.Parent = AwakenBackground

-- task.spawn: os WaitForChild abaixo esperam até 60s somados. Sem
-- isolar, a barra de VIDA (o resto deste script) ficaria travada esse
-- tempo todo quando o AwakeningMeterServer não estivesse instalado.
task.spawn(function()
	local remotes = ReplicatedStorage:WaitForChild("Remotes", 30)
	local meterUpdate = remotes and remotes:WaitForChild("AwakeningMeterUpdate", 30)

	if meterUpdate then
		local piscando = false

		local function aplicar(dados)
			if type(dados) ~= "table" then
				return
			end

			-- Personagem sem Despertar: some com a barra
			if not dados.ativo then
				AwakenBackground.Visible = false
				return
			end

			AwakenBackground.Visible = true

			local max = math.max(1, dados.max or 100)
			local fracao = math.clamp((dados.valor or 0) / max, 0, 1)

			-- (V7) Janela de transformação: o jogador fica desarmado por
			-- alguns segundos enquanto a forma troca, nos dois sentidos.
			-- Precisa aparecer, senão parece que o jogo travou.
			if dados.transformando then
				piscando = false
				AwakenBar.Size = UDim2.new(1, 0, 1, 0)
				AwakenBar.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
				AwakenBackground.BorderColor3 = Color3.fromRGB(255, 255, 255)
				AwakenText.Text = string.format(
					"TRANSFORMANDO  %.1fs",
					dados.transformandoRestante or 0
				)
			elseif dados.desperto then
				-- Desperto: a barra vira contagem regressiva da forma
				AwakenBar.Size = UDim2.new(1, 0, 1, 0)
				AwakenBar.BackgroundColor3 = Color3.fromRGB(255, 210, 70)
				AwakenText.Text = string.format("DESPERTO  %.0fs", dados.restante or 0)

				if not piscando then
					piscando = true
					task.spawn(function()
						while AwakenBackground.Visible and piscando do
							AwakenBackground.BorderColor3 = Color3.fromRGB(255, 210, 70)
							task.wait(0.25)
							AwakenBackground.BorderColor3 = COLORS.border
							task.wait(0.25)
						end
					end)
				end
			elseif (dados.cooldown or 0) > 0 then
				piscando = false
				AwakenBackground.BorderColor3 = COLORS.border
				AwakenBar.Size = UDim2.new(0, 0, 1, 0)
				AwakenText.Text = string.format("RECARGA  %.0fs", dados.cooldown)
			else
				piscando = false
				AwakenBackground.BorderColor3 = COLORS.border
				AwakenBar.Size = UDim2.new(fracao, 0, 1, 0)
				AwakenBar.BackgroundColor3 = fracao >= 1 and Color3.fromRGB(255, 210, 70)
					or Color3.fromRGB(180, 90, 255)
				AwakenText.Text = string.format("DESPERTAR  %d%%", math.floor(fracao * 100))
			end
		end

		meterUpdate.OnClientEvent:Connect(aplicar)

		-- PUXA o estado agora que já estamos escutando.
		--
		-- O servidor só empurrava quando algo mudava, e o pacote inicial
		-- saía enquanto este script ainda esperava o remote aparecer. O
		-- pacote se perdia, nada mais mudava, e a barra ficava invisível
		-- para sempre. Esta chamada fecha essa janela.
		local pull = remotes:FindFirstChild("GetAwakeningMeter")
		if pull then
			local ok, estadoAtual = pcall(function()
				return pull:InvokeServer()
			end)
			if ok and type(estadoAtual) == "table" then
				aplicar(estadoAtual)
			end
		end
	else
		warn("[HEALTH V7] AwakeningMeterUpdate não encontrado — barra de Despertar desligada")
	end
end)

-- =====================================
-- VARIÁVEIS DE CONTROLE
-- =====================================

local lastHealth = 100
local isBlinking = false
local energyBlinking = false

-- =====================================
-- (V8) DONO ÚNICO DA COR DA BORDA
-- =====================================
-- Cinco lugares escreviam em MainContainer.BorderColor3 com o padrão
-- "salva o valor atual, muda, restaura depois de 0.1s". Dois flashes em
-- menos de 0.1s faziam o segundo capturar a cor do primeiro como
-- "original" — e a borda ficava presa naquela cor para sempre.
--
-- Agora ninguém escreve na borda direto. Cada efeito declara seu estado e
-- esta função decide, por prioridade, qual cor vale agora.
local flashAtual = nil -- cor do flash momentâneo, ou nil
local piscaCritica = false -- fase do piscar de vida crítica

local function atualizarBorda()
	if flashAtual then
		MainContainer.BorderColor3 = flashAtual
	elseif isBlinking then
		MainContainer.BorderColor3 = piscaCritica and COLORS.healthCritical or COLORS.border
	else
		MainContainer.BorderColor3 = COLORS.border
	end
end

-- Cada flash tem um número. Só o mais recente pode se apagar, então um
-- flash antigo terminando não limpa o flash que começou depois dele.
local flashSequencia = 0

local function flashBorda(cor, duracao)
	flashSequencia += 1
	local meu = flashSequencia
	flashAtual = cor
	atualizarBorda()

	task.delay(duracao, function()
		if flashSequencia == meu then
			flashAtual = nil
			atualizarBorda()
		end
	end)
end

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
	-- (V8) Não salva nem restaura mais: só declara o flash. Quem decide a
	-- cor da borda é atualizarBorda().
	flashBorda(COLORS.healthCritical, 0.1)
end

-- =====================================
-- FUNÇÃO: EFEITO DE CURA (FLASH VERDE)
-- =====================================

local function createHealFlash()
	flashBorda(COLORS.healthHigh, 0.1)
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
			piscaCritica = true
			StatusIndicator.BackgroundColor3 = COLORS.healthCritical
			atualizarBorda()
			task.wait(0.3)

			if not isBlinking then
				break
			end

			piscaCritica = false
			StatusIndicator.BackgroundColor3 = COLORS.barBackground
			atualizarBorda()
			task.wait(0.3)
		end
		piscaCritica = false
		atualizarBorda()
	end)
end

local function stopCriticalBlink()
	if not isBlinking then
		return
	end
	isBlinking = false
	piscaCritica = false
	atualizarBorda()
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
		--
		-- (V8) O V7 fazia task.spawn + task.wait(0.3) aqui. Cada golpe
		-- criava uma thread; numa sequência elas acordavam juntas e cada
		-- uma puxava a mesma barra para um tamanho já vencido, então ela
		-- tremia em vez de deslizar. O atraso agora é o DelayTime do
		-- próprio TweenInfo, sem thread nenhuma, e só existe um tween por
		-- barra: o anterior é cancelado.
		if wasDamaged then
			animar(
				"vidaPerdida",
				LostHealthBar,
				TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.Out, 0, false, 0.3),
				{ Size = UDim2.new(healthPercent, 0, 1, 0) }
			)
		else
			-- Se curou, atualizar imediatamente
			local pendente = tweensAtivos.vidaPerdida
			if pendente then
				pendente:Cancel()
			end
			LostHealthBar.Size = UDim2.new(healthPercent, 0, 1, 0)
		end

		-- Animar barra principal
		animar("vida", HealthBar, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = UDim2.new(healthPercent, 0, 1, 0),
			BackgroundColor3 = healthColor,
		})

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
	-- (V8) O V7 rodava um laço `while` criando DOIS tweens a cada 3
	-- segundos, para sempre — e como o ScreenGui tem ResetOnSpawn = false,
	-- ele nunca termina. Eram cerca de 40 objetos de tween por minuto
	-- abandonados, pela sessão inteira.
	--
	-- O mesmo efeito cabe em um único tween que se repete sozinho:
	-- RepeatCount = -1 (infinito) e Reverses = true (vai e volta).
	MainContainer.BackgroundTransparency = 0
	animar(
		"pulsoBorda",
		MainContainer,
		TweenInfo.new(1.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ BackgroundTransparency = 0.3 }
	)
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

	animar("energia", EnergyBar, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = UDim2.new(percent, 0, 1, 0),
		BackgroundColor3 = color,
	})

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
			flashBorda(COLORS.energyLow, 0.15)
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
	-- (V8) Sem isto, lastHealth guardava a vida baixa de antes de morrer e
	-- o primeiro update do personagem novo era lido como CURA, disparando
	-- um flash verde a cada renascimento.
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	lastHealth = humanoid and humanoid.MaxHealth or 100
	UpdateHealth()
end)

-- Aplicar se personagem já existe
if Player.Character then
	UpdateHealth()
end

print([[
╔════════════════════════════════════════════════════╗
║  ✅ HEALTH DISPLAY V8 CARREGADO                    ║
╠════════════════════════════════════════════════════╣
║  SUBSTITUI: HealthDisplay V7                       ║
║  REMOVER:   HealthDisplay V7                       ║
╠════════════════════════════════════════════════════╣
║  CORRIGIDO NO V8:                                  ║
║  • Pulso da borda vazava ~40 tweens por minuto    ║
║    pela sessão inteira — agora é 1 tween          ║
║  • Borda podia ficar presa na cor de um flash     ║
║  • Barra de vida perdida tremia em combate        ║
║  • Indicador de status deformava por proporção    ║
║  • Barra de Despertar colada ao container         ║
║  • Flash verde falso ao renascer                  ║
╠════════════════════════════════════════════════════╣
║  MANTIDO:                                          ║
║  • Visual retro, fonte Arcade, bordas 3px         ║
║  • HP + ENERGIA + DESPERTAR no HUD                ║
║  • Piscar em vida crítica e energia baixa         ║
║  • Janela de TRANSFORMANDO do Despertar           ║
║  • Sem EnergySystemServer / AwakeningMeterServer, ║
║    as barras somem e o HP continua igual          ║
╚════════════════════════════════════════════════════╝
]])
