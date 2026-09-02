-- ============================================
-- UNIFIED MENU CLIENT V4 — MENU UNIFICADO ANIMADO
-- Coloque em StarterPlayer > StarterPlayerScripts
-- Nome: "UnifiedMenuClient"
-- SUBSTITUI: UnifiedMenuClient V3
-- ============================================
-- (V4) O menu não animava nada que desse para ver no celular.
--
--   1. HUB APARECIA SECO. Abrir e fechar era Visible = true/false, em
--      seis pontos diferentes do arquivo. Agora passa por abrirHub() e
--      fecharHub(), com mola amortecida integrada no Heartbeat.
--   2. REAÇÃO SÓ DE MOUSE. O único retorno visual dos cards era
--      MouseEnter/MouseLeave, que não dispara em toque. Em celular o
--      menu era completamente inerte. Trocado por InputBegan/InputEnded,
--      que cobrem toque e mouse, com o hover mantido por cima no desktop.
--   3. TWEEN EM LAÇO. A pulsação do botão ☰ rodava dentro de um
--      `while ... task.wait(1.5)` criando dois tweens por volta, para
--      sempre. Virou um tween só com RepeatCount = -1 e Reverses = true.
--   4. CARDS DEFORMAVAM. Nenhum UIAspectRatioConstraint no arquivo
--      inteiro; a célula mudava de proporção a cada tela. Agora é fixa.
--
-- Os cards entram escalonados pelo DelayTime do próprio TweenInfo, sem
-- task.spawn e sem task.wait — nada de thread por card disputando a UI.
--
-- Mesmo idioma de animação do CharacterSystemClient V12: contexto dono
-- das conexões e dos tweens, um tween por chave com o anterior
-- cancelado. Os dois menus se comportam igual.
-- ============================================
-- (V3) fontes unificadas em estilo retro (Arcade)
-- ============================================
-- V2: Categorias usam _G functions dos sistemas reais.
-- MÚSICA adicionada. ÚNICO botão na tela.
-- ============================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

print("[UNIFIED MENU V1] Inicializando...")

-- =====================================
-- SONS
-- =====================================

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

-- =====================================
-- (V4) CAMADA DE ANIMAÇÃO
-- =====================================
-- O V3 não animava nada que o dono conseguisse ver. Dos cinco tweens do
-- arquivo, dois eram MouseEnter/MouseLeave — que NÃO disparam em toque,
-- então em celular nunca rodavam — e dois viviam dentro de um
-- `while ... task.wait(1.5)`, criando um tween novo a cada volta pela
-- sessão inteira. O hub abria e fechava com Visible = true/false, seco.
--
-- Aqui entra o mesmo idioma do CharacterSystemClient V12, para os dois
-- menus se comportarem igual: um contexto dono das conexões e dos
-- tweens, um tween por chave com o anterior cancelado, e mola amortecida
-- integrada no Heartbeat para abrir e fechar.

local RunService = game:GetService("RunService")

local animContext = nil

local function novoContexto()
	return { alive = true, connections = {}, tweens = {} }
end

local function limparContexto(context)
	if not context then
		return
	end
	context.alive = false
	for _, connection in ipairs(context.connections) do
		connection:Disconnect()
	end
	for _, tween in pairs(context.tweens) do
		tween:Cancel()
	end
	table.clear(context.connections)
	table.clear(context.tweens)
end

local function conectarContexto(context, signal, callback)
	local connection = signal:Connect(callback)
	if context and context.alive then
		table.insert(context.connections, connection)
	end
	return connection
end

-- Um tween por chave. O anterior é cancelado antes do novo nascer, que é
-- o que impede dois tweens de brigarem pela mesma propriedade e deixarem
-- a cor ou o tamanho presos num valor de meio de caminho.
local function tocarTween(context, key, instance, tweenInfo, properties)
	if not context or not context.alive or not instance or not instance.Parent then
		return nil
	end
	local previous = context.tweens[key]
	if previous then
		previous:Cancel()
	end
	local tween = TweenService:Create(instance, tweenInfo, properties)
	context.tweens[key] = tween
	tween:Play()
	return tween
end

-- Mola amortecida para abrir e fechar. É física visual: aceleração,
-- velocidade e posição integradas por quadro. Nenhuma força toca o
-- personagem — nada de BodyVelocity aqui.
local function criarMolaPainel(context, frame, aoEsconder)
	local scale = Instance.new("UIScale")
	scale.Scale = 0.86
	scale.Parent = frame

	local state = {
		position = 0.86,
		velocity = 0,
		target = 0.86,
		active = false,
		closing = false,
	}

	local controller = {}

	function controller.open()
		if not frame.Parent then
			return
		end
		frame.Visible = true
		state.position = math.min(state.position, 0.9)
		state.velocity = 0
		state.target = 1
		state.closing = false
		state.active = true
	end

	function controller.close()
		if not frame.Visible then
			return
		end
		state.target = 0.86
		state.closing = true
		state.active = true
	end

	function controller.hide()
		state.position = 0.86
		state.velocity = 0
		state.target = 0.86
		state.active = false
		state.closing = false
		scale.Scale = 0.86
		frame.Rotation = 0
		frame.Visible = false
	end

	conectarContexto(context, RunService.Heartbeat, function(deltaTime)
		if not state.active or not frame.Parent then
			return
		end

		-- dt limitado: numa queda de FPS um passo grande faria a mola
		-- estourar em vez de assentar.
		local dt = math.min(deltaTime, 1 / 30)
		local stiffness = 230
		local damping = 25
		local acceleration = (state.target - state.position) * stiffness - state.velocity * damping
		state.velocity += acceleration * dt
		state.position += state.velocity * dt
		state.position = math.clamp(state.position, 0.82, 1.06)

		scale.Scale = state.position
		frame.Rotation = math.clamp((1 - state.position) * -8, -2.2, 1.2)

		if math.abs(state.target - state.position) < 0.002 and math.abs(state.velocity) < 0.02 then
			state.position = state.target
			state.velocity = 0
			scale.Scale = state.target
			frame.Rotation = 0
			state.active = false
			if state.closing then
				state.closing = false
				frame.Visible = false
				if aoEsconder then
					aoEsconder()
				end
			end
		end
	end)

	return controller
end

-- Reação de toque. MouseEnter/MouseLeave não existem no celular, então
-- o afundar do card é ligado em InputBegan/InputEnded, que cobrem toque
-- e mouse pelo mesmo caminho.
local function reagirAoToque(context, button, chave, escalaNormal, escalaPress)
	local uiScale = button:FindFirstChildOfClass("UIScale")
	if not uiScale then
		uiScale = Instance.new("UIScale")
		uiScale.Scale = escalaNormal
		uiScale.Parent = button
	end

	local function pressionar()
		tocarTween(
			context,
			chave,
			uiScale,
			TweenInfo.new(0.09, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Scale = escalaPress }
		)
	end

	local function soltar()
		tocarTween(
			context,
			chave,
			uiScale,
			TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
			{ Scale = escalaNormal }
		)
	end

	conectarContexto(context, button.InputBegan, function(input)
		if
			input.UserInputType == Enum.UserInputType.Touch
			or input.UserInputType == Enum.UserInputType.MouseButton1
		then
			pressionar()
		end
	end)

	conectarContexto(context, button.InputEnded, function(input)
		if
			input.UserInputType == Enum.UserInputType.Touch
			or input.UserInputType == Enum.UserInputType.MouseButton1
		then
			soltar()
		end
	end)

	return uiScale
end

-- =====================================
-- TAMANHOS
-- =====================================

local SIZE_MODES = { "P", "M", "G" }
local currentSizeIndex = 2 -- Médio

local GRID_SIZES = {
	P = { cols = 3, cellW = 0.28, cellH = 0.13, gap = 0.02, hubScale = 0.55 },
	M = { cols = 3, cellW = 0.28, cellH = 0.15, gap = 0.025, hubScale = 0.65 },
	G = { cols = 3, cellW = 0.28, cellH = 0.17, gap = 0.03, hubScale = 0.75 },
}

local function getGridConfig()
	return GRID_SIZES[SIZE_MODES[currentSizeIndex]]
end

-- =====================================
-- REGISTRO DE CATEGORIAS
-- =====================================

local categories = {}
local hubOpen = false
local menuGui = nil
local hubFrame = nil
local mainButton = nil
local notifDot = nil
local activeSubmenu = nil -- Nome do submenu ativo
local hubMotion = nil -- controlador da mola do hub (V4)

-- (V4) Caminho único para mostrar e esconder o hub. Enquanto isso era
-- Visible = true/false solto em seis lugares, qualquer animação teria de
-- ser repetida em seis lugares — e foi por isso que nunca teve nenhuma.
local function abrirHub()
	hubOpen = true
	if hubMotion then
		hubMotion.open()
	elseif hubFrame then
		hubFrame.Visible = true
	end
end

local function fecharHub()
	hubOpen = false
	if hubMotion then
		hubMotion.close()
	elseif hubFrame then
		hubFrame.Visible = false
	end
end

-- Estrutura de cada categoria:
-- {name, icon, openFunc, closeFunc, hasNotification, order}

_G.RegisterMenuCategory = function(name, icon, openFunc, closeFunc, order)
	-- Evitar duplicatas
	for i, cat in ipairs(categories) do
		if cat.name == name then
			categories[i] = {
				name = name,
				icon = icon,
				openFunc = openFunc,
				closeFunc = closeFunc,
				hasNotification = false,
				order = order or 99,
			}
			return
		end
	end

	table.insert(categories, {
		name = name,
		icon = icon,
		openFunc = openFunc,
		closeFunc = closeFunc,
		hasNotification = false,
		order = order or 99,
	})

	-- Ordenar
	table.sort(categories, function(a, b)
		return a.order < b.order
	end)
end

_G.SetMenuNotification = function(categoryName, hasNotif)
	for _, cat in ipairs(categories) do
		if cat.name == categoryName then
			cat.hasNotification = hasNotif
			break
		end
	end
	-- Atualizar dot
	updateNotifDot()
end

-- =====================================
-- CATEGORIAS PADRÃO
-- =====================================

local function registerDefaults()
	-- Cada sistema se registra sozinho via _G.RegisterMenuCategory
	-- Estes defaults são fallbacks caso o sistema ainda não tenha carregado

	_G.RegisterMenuCategory("LOJA", "🛒", function()
		if _G.OpenCharacterShop then
			_G.OpenCharacterShop()
		else
			local g = playerGui:FindFirstChild("CharacterSystemV3")
			if g then
				local f = g:FindFirstChild("MainFrame")
				if f then
					f.Visible = true
				end
			end
		end
	end, function()
		if _G.CloseCharacterShop then
			_G.CloseCharacterShop()
		else
			local g = playerGui:FindFirstChild("CharacterSystemV3")
			if g then
				local f = g:FindFirstChild("MainFrame")
				if f then
					f.Visible = false
				end
			end
		end
	end, 1)

	_G.RegisterMenuCategory("INVENTÁRIO", "📦", function()
		if _G.OpenCharacterInventory then
			_G.OpenCharacterInventory()
		else
			local g = playerGui:FindFirstChild("CharacterSystemV3")
			if g then
				local f = g:FindFirstChild("InventoryFrame")
				if f then
					f.Visible = true
				end
			end
		end
	end, function()
		if _G.CloseCharacterInventory then
			_G.CloseCharacterInventory()
		else
			local g = playerGui:FindFirstChild("CharacterSystemV3")
			if g then
				local f = g:FindFirstChild("InventoryFrame")
				if f then
					f.Visible = false
				end
			end
		end
	end, 2)

	_G.RegisterMenuCategory("TIMES", "👥", function()
		if _G.OpenTeamMenu then
			_G.OpenTeamMenu()
		else
			local g = playerGui:FindFirstChild("TeamMenuGui")
			if g then
				local bg = g:FindFirstChild("Background")
				if bg then
					bg.Visible = true
				end
				local mf = g:FindFirstChild("MainFrame")
				if mf then
					mf.Visible = true
				end
			end
		end
	end, function()
		if _G.CloseTeamMenu then
			_G.CloseTeamMenu()
		else
			local g = playerGui:FindFirstChild("TeamMenuGui")
			if g then
				local bg = g:FindFirstChild("Background")
				if bg then
					bg.Visible = false
				end
				local mf = g:FindFirstChild("MainFrame")
				if mf then
					mf.Visible = false
				end
			end
		end
	end, 3)

	_G.RegisterMenuCategory("TROCAS", "🔄", function()
		if _G.OpenTradePlayerList then
			_G.OpenTradePlayerList()
		end
	end, function()
		local g = playerGui:FindFirstChild("TradePlayerList")
		if g then
			g.Parent = nil
		end
	end, 4)

	_G.RegisterMenuCategory("MISSÕES", "📋", function()
		if _G.OpenMissionsMenu then
			_G.OpenMissionsMenu()
		end
	end, function()
		local g = playerGui:FindFirstChild("MissionsMenu")
		if g then
			g.Parent = nil
		end
	end, 5)

	_G.RegisterMenuCategory("MÚSICA", "🎵", function()
		if _G.OpenMusicPlayer then
			_G.OpenMusicPlayer()
		else
			local g = playerGui:FindFirstChild("MusicPlayerV4")
			if g then
				local bg = g:FindFirstChild("Background")
				if bg then
					bg.Visible = true
				end
				local mw = g:FindFirstChild("MainWindow")
				if mw then
					mw.Visible = true
				end
			end
		end
	end, function()
		if _G.CloseMusicPlayer then
			_G.CloseMusicPlayer()
		else
			local g = playerGui:FindFirstChild("MusicPlayerV4")
			if g then
				local bg = g:FindFirstChild("Background")
				if bg then
					bg.Visible = false
				end
				local mw = g:FindFirstChild("MainWindow")
				if mw then
					mw.Visible = false
				end
			end
		end
	end, 6)

	_G.RegisterMenuCategory("TUTORIAL", "❓", function()
		if _G.OpenTutorialMenu then
			_G.OpenTutorialMenu()
		else
			local g = playerGui:FindFirstChild("TutorialMenuV3")
			if g then
				local bg = g:FindFirstChild("Background")
				if bg then
					bg.Visible = true
				end
				local mw = g:FindFirstChild("MainWindow")
				if mw then
					mw.Visible = true
				end
			end
		end
	end, function()
		if _G.CloseTutorialMenu then
			_G.CloseTutorialMenu()
		else
			local g = playerGui:FindFirstChild("TutorialMenuV3")
			if g then
				local bg = g:FindFirstChild("Background")
				if bg then
					bg.Visible = false
				end
				local mw = g:FindFirstChild("MainWindow")
				if mw then
					mw.Visible = false
				end
			end
		end
	end, 7)

	-- ADMIN: só registra se o jogador for admin
	local ADMIN_IDS = { 1595442496, 8833465560, 1832521992 }
	if table.find(ADMIN_IDS, player.UserId) then
		_G.RegisterMenuCategory("ADMIN", "⚙️", function()
			if _G.OpenAdminMenu then
				_G.OpenAdminMenu()
			else
				local g = playerGui:FindFirstChild("AdminMenuV6")
				if g then
					local mf = g:FindFirstChild("MainFrame")
					if mf then
						mf.Visible = true
					end
				end
			end
		end, function()
			if _G.CloseAdminMenu then
				_G.CloseAdminMenu()
			else
				local g = playerGui:FindFirstChild("AdminMenuV6")
				if g then
					local mf = g:FindFirstChild("MainFrame")
					if mf then
						mf.Visible = false
					end
				end
			end
		end, 8)
	end -- if admin
end

registerDefaults()

-- =====================================
-- ATUALIZAR INDICADOR DE NOTIFICAÇÃO
-- =====================================

function updateNotifDot()
	if not notifDot then
		return
	end
	local hasAny = false
	for _, cat in ipairs(categories) do
		if cat.hasNotification then
			hasAny = true
			break
		end
	end
	notifDot.Visible = hasAny
end

-- =====================================
-- FECHAR SUBMENU ATIVO
-- =====================================

local function closeActiveSubmenu()
	if activeSubmenu then
		for _, cat in ipairs(categories) do
			if cat.name == activeSubmenu and cat.closeFunc then
				pcall(cat.closeFunc)
			end
		end
		activeSubmenu = nil
	end
end

-- =====================================
-- CRIAR HUB
-- =====================================

local function buildMenu()
	if menuGui then
		menuGui.Parent = nil
	end

	-- (V4) buildMenu() é chamado de novo no respawn e pelo _G.UnifiedMenu.
	-- Sem desfazer o contexto anterior, cada reconstrução deixaria para
	-- trás as conexões de Heartbeat e os tweens da versão antiga.
	limparContexto(animContext)
	animContext = novoContexto()
	hubMotion = nil

	menuGui = Instance.new("ScreenGui")
	menuGui.Name = "UnifiedMenuV1"
	menuGui.ResetOnSpawn = false
	menuGui.IgnoreGuiInset = true
	menuGui.DisplayOrder = 50
	menuGui.Parent = playerGui

	-- ===== BOTÃO PRINCIPAL (☰) =====
	local btnSize = isMobile and UDim2.new(0.12, 0, 0.06, 0) or UDim2.new(0.06, 0, 0.06, 0)

	mainButton = Instance.new("TextButton")
	mainButton.Name = "MenuButton"
	mainButton.Size = btnSize
	mainButton.Position = isMobile and UDim2.new(0.01, 0, 0.4, 0) or UDim2.new(0.01, 0, 0.35, 0)
	mainButton.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
	mainButton.BorderColor3 = Color3.fromRGB(0, 200, 255)
	mainButton.BorderSizePixel = 3
	mainButton.Text = "☰"
	mainButton.TextColor3 = Color3.new(1, 1, 1)
	mainButton.TextScaled = true
	mainButton.Font = Enum.Font.Arcade
	mainButton.Parent = menuGui

	-- Notificação ponto vermelho
	notifDot = Instance.new("Frame")
	notifDot.Size = UDim2.new(0.3, 0, 0.3, 0)
	notifDot.Position = UDim2.new(0.75, 0, -0.05, 0)
	notifDot.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
	notifDot.BorderSizePixel = 0
	notifDot.Visible = false
	notifDot.Parent = mainButton

	local notifCorner = Instance.new("UICorner")
	notifCorner.CornerRadius = UDim.new(1, 0)
	notifCorner.Parent = notifDot

	-- (V4) O ponto vermelho aparecia e ficava parado. Um aviso que não se
	-- mexe some no meio do resto da tela. Um tween repetido resolve, e o
	-- ponto é redondo por UICorner: precisa continuar quadrado para não
	-- virar elipse quando o botão muda de proporção.
	local notifRatio = Instance.new("UIAspectRatioConstraint")
	notifRatio.AspectRatio = 1
	notifRatio.DominantAxis = Enum.DominantAxis.Height
	notifRatio.Parent = notifDot

	local notifScale = Instance.new("UIScale")
	notifScale.Scale = 1
	notifScale.Parent = notifDot

	tocarTween(
		animContext,
		"pulsoNotif",
		notifScale,
		TweenInfo.new(0.7, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ Scale = 1.35 }
	)

	-- (V4) Pulsação do botão principal em UM tween.
	-- O laço antigo criava dois tweens a cada 3s e nunca parava: o
	-- ScreenGui tem ResetOnSpawn = false, então rodava a sessão inteira,
	-- deixando cerca de 40 objetos de tween abandonados por minuto.
	-- RepeatCount = -1 com Reverses = true dá o mesmo vai-e-volta com um
	-- objeto só, e ele morre junto do contexto.
	tocarTween(
		animContext,
		"pulsoBotao",
		mainButton,
		TweenInfo.new(1.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ BorderColor3 = Color3.fromRGB(0, 150, 200) }
	)

	-- O botão também afunda ao toque, não só no mouse.
	reagirAoToque(animContext, mainButton, "pressBotao", 1, 0.9)

	-- ===== HUB FRAME =====
	local gc = getGridConfig()

	hubFrame = Instance.new("Frame")
	hubFrame.Name = "HubFrame"
	hubFrame.Size = UDim2.new(gc.hubScale, 0, gc.hubScale, 0)
	hubFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
	hubFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	hubFrame.BackgroundColor3 = Color3.fromRGB(12, 12, 18)
	hubFrame.BorderColor3 = Color3.fromRGB(0, 200, 255)
	hubFrame.BorderSizePixel = 4
	hubFrame.Visible = false
	hubFrame.Parent = menuGui

	-- (V4) A mola vive no hubFrame. abrirHub()/fecharHub() são os únicos
	-- caminhos daqui em diante; antes havia seis atribuições soltas de
	-- Visible espalhadas pelo arquivo, e por isso nenhuma delas animava.
	hubMotion = criarMolaPainel(animContext, hubFrame)

	local hubCorner = Instance.new("UICorner")
	hubCorner.CornerRadius = UDim.new(0.02, 0)
	hubCorner.Parent = hubFrame

	-- Header do HUB
	local hubHeader = Instance.new("Frame")
	hubHeader.Size = UDim2.new(1, 0, 0.1, 0)
	hubHeader.BackgroundColor3 = Color3.fromRGB(0, 60, 90)
	hubHeader.BorderSizePixel = 0
	hubHeader.Parent = hubFrame

	local hubHeaderCorner = Instance.new("UICorner")
	hubHeaderCorner.CornerRadius = UDim.new(0.02, 0)
	hubHeaderCorner.Parent = hubHeader

	local hubTitle = Instance.new("TextLabel")
	hubTitle.Size = UDim2.new(0.55, 0, 1, 0)
	hubTitle.Position = UDim2.new(0.02, 0, 0, 0)
	hubTitle.BackgroundTransparency = 1
	hubTitle.Text = "██ RETRO-VERSE ██"
	hubTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
	hubTitle.TextScaled = true
	hubTitle.Font = Enum.Font.Arcade
	hubTitle.Parent = hubHeader

	-- Forward declaration
	local buildGrid

	-- Botão resize
	local sizeBtn = Instance.new("TextButton")
	sizeBtn.Size = UDim2.new(0.08, 0, 0.7, 0)
	sizeBtn.Position = UDim2.new(0.72, 0, 0.15, 0)
	sizeBtn.BackgroundColor3 = Color3.fromRGB(0, 100, 150)
	sizeBtn.BorderSizePixel = 0
	sizeBtn.Text = SIZE_MODES[currentSizeIndex]
	sizeBtn.TextColor3 = Color3.new(1, 1, 1)
	sizeBtn.TextScaled = true
	sizeBtn.Font = Enum.Font.Arcade
	sizeBtn.Parent = hubHeader

	sizeBtn.MouseButton1Click:Connect(function()
		playSound("rbxassetid://156785206")
		currentSizeIndex = currentSizeIndex % #SIZE_MODES + 1
		sizeBtn.Text = SIZE_MODES[currentSizeIndex]
		-- Rebuild grid
		buildGrid()
		-- Resize hub
		local newGc = getGridConfig()
		-- (V4) Pelo gerenciador: apertar P/M/G rápido cancelava mal o
		-- tween anterior e o hub podia parar num tamanho intermediário.
		tocarTween(
			animContext,
			"tamanhoHub",
			hubFrame,
			TweenInfo.new(0.3, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
			{ Size = UDim2.new(newGc.hubScale, 0, newGc.hubScale, 0) }
		)
	end)

	-- Botão fechar
	local closeBtn = Instance.new("TextButton")
	closeBtn.Size = UDim2.new(0.08, 0, 0.7, 0)
	closeBtn.Position = UDim2.new(0.88, 0, 0.15, 0)
	closeBtn.BackgroundColor3 = Color3.fromRGB(150, 0, 0)
	closeBtn.BorderSizePixel = 0
	closeBtn.Text = "X"
	closeBtn.TextColor3 = Color3.new(1, 1, 1)
	closeBtn.TextScaled = true
	closeBtn.Font = Enum.Font.Arcade
	closeBtn.Parent = hubHeader

	closeBtn.MouseButton1Click:Connect(function()
		playSound("rbxassetid://157167205")
		fecharHub()
	end)

	-- ===== GRID DE CATEGORIAS =====
	local gridContainer = Instance.new("Frame")
	gridContainer.Name = "GridContainer"
	gridContainer.Size = UDim2.new(0.94, 0, 0.85, 0)
	gridContainer.Position = UDim2.new(0.03, 0, 0.12, 0)
	gridContainer.BackgroundTransparency = 1
	gridContainer.Parent = hubFrame

	buildGrid = function()
		-- Limpar grid
		for _, child in ipairs(gridContainer:GetChildren()) do
			if child:IsA("TextButton") then
				child.Parent = nil
			end
		end

		local gc = getGridConfig()
		local cols = gc.cols

		for i, cat in ipairs(categories) do
			local col = (i - 1) % cols
			local row = math.floor((i - 1) / cols)

			local xPos = col * (gc.cellW + gc.gap) + gc.gap * 0.5
			local yPos = row * (gc.cellH + gc.gap) + gc.gap

			local catBtn = Instance.new("TextButton")
			catBtn.Name = "Cat_" .. cat.name
			catBtn.Size = UDim2.new(gc.cellW, 0, gc.cellH, 0)
			catBtn.Position = UDim2.new(xPos, 0, yPos, 0)
			catBtn.BackgroundColor3 = Color3.fromRGB(25, 30, 40)
			catBtn.BorderColor3 = Color3.fromRGB(80, 80, 120)
			catBtn.BorderSizePixel = 2
			catBtn.Text = ""
			catBtn.Parent = gridContainer

			local catCorner = Instance.new("UICorner")
			catCorner.CornerRadius = UDim.new(0.08, 0)
			catCorner.Parent = catBtn

			-- (V4) A célula é ícone em cima e nome embaixo: proporção
			-- importa. Sem isto ela virava um retângulo diferente em cada
			-- tela, e o ícone esticava junto. Não havia um único
			-- UIAspectRatioConstraint no arquivo.
			local catRatio = Instance.new("UIAspectRatioConstraint")
			catRatio.AspectRatio = 1.15
			catRatio.DominantAxis = Enum.DominantAxis.Width
			catRatio.Parent = catBtn

			-- Ícone
			local iconLbl = Instance.new("TextLabel")
			iconLbl.Size = UDim2.new(1, 0, 0.55, 0)
			iconLbl.BackgroundTransparency = 1
			iconLbl.Text = cat.icon
			iconLbl.TextScaled = true
			iconLbl.Font = Enum.Font.Arcade
			iconLbl.Parent = catBtn

			-- Nome
			local nameLbl = Instance.new("TextLabel")
			nameLbl.Size = UDim2.new(0.9, 0, 0.35, 0)
			nameLbl.Position = UDim2.new(0.05, 0, 0.58, 0)
			nameLbl.BackgroundTransparency = 1
			nameLbl.Text = cat.name
			nameLbl.TextColor3 = Color3.fromRGB(200, 200, 220)
			nameLbl.TextScaled = true
			nameLbl.Font = Enum.Font.Arcade
			nameLbl.Parent = catBtn

			-- Indicador de notificação
			if cat.hasNotification then
				local catDot = Instance.new("Frame")
				catDot.Size = UDim2.new(0.15, 0, 0.15, 0)
				catDot.Position = UDim2.new(0.85, 0, 0, 0)
				catDot.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
				catDot.BorderSizePixel = 0
				catDot.Parent = catBtn
				local dc = Instance.new("UICorner")
				dc.CornerRadius = UDim.new(1, 0)
				dc.Parent = catDot
			end

			-- (V4) ENTRADA ESCALONADA. Cada card nasce menor e
			-- transparente e assenta no lugar com um atraso proporcional
			-- à sua posição na grade, o que dá a sensação de a grade se
			-- montar em vez de piscar pronta. O atraso é o DelayTime do
			-- próprio TweenInfo — sem task.spawn e sem task.wait, então
			-- não existe uma thread por card acordando para disputar a UI.
			local entradaScale = Instance.new("UIScale")
			entradaScale.Scale = 0.7
			entradaScale.Parent = catBtn
			catBtn.BackgroundTransparency = 1
			iconLbl.TextTransparency = 1
			nameLbl.TextTransparency = 1

			local atraso = math.min(i * 0.035, 0.32)
			local infoEntrada =
				TweenInfo.new(0.34, Enum.EasingStyle.Back, Enum.EasingDirection.Out, 0, false, atraso)
			local infoFade =
				TweenInfo.new(0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, atraso)

			-- A chave é "escala"..i, a MESMA que reagirAoToque usa logo
			-- abaixo, e isso é de propósito: os dois animam o Scale deste
			-- mesmo UIScale. Com chaves diferentes eles não se cancelariam
			-- e ficariam brigando pela propriedade se o jogador tocasse no
			-- card antes de a entrada terminar. Compartilhando a chave, o
			-- toque cancela a entrada e assume — que é o que se espera.
			tocarTween(animContext, "escala" .. i, entradaScale, infoEntrada, { Scale = 1 })
			tocarTween(animContext, "fundo" .. i, catBtn, infoFade, { BackgroundTransparency = 0 })
			tocarTween(animContext, "icone" .. i, iconLbl, infoFade, { TextTransparency = 0 })
			tocarTween(animContext, "nome" .. i, nameLbl, infoFade, { TextTransparency = 0 })

			-- (V4) REAÇÃO QUE FUNCIONA NO CELULAR. MouseEnter/MouseLeave
			-- não disparam em toque: no aparelho do dono o card era
			-- inerte. InputBegan/InputEnded cobrem toque e mouse pelo
			-- mesmo caminho, então o card afunda ao encostar o dedo.
			reagirAoToque(animContext, catBtn, "escala" .. i, 1, 0.93)

			-- Realce por cor: no desktop segue o cursor, no celular
			-- acompanha o toque. Mesma chave de tween nos dois, então um
			-- estado cancela o outro em vez de empilhar.
			local function realcar()
				tocarTween(animContext, "realce" .. i, catBtn, TweenInfo.new(0.15), {
					BackgroundColor3 = Color3.fromRGB(40, 50, 70),
					BorderColor3 = Color3.fromRGB(0, 200, 255),
				})
			end

			local function apagar()
				tocarTween(animContext, "realce" .. i, catBtn, TweenInfo.new(0.15), {
					BackgroundColor3 = Color3.fromRGB(25, 30, 40),
					BorderColor3 = Color3.fromRGB(80, 80, 120),
				})
			end

			conectarContexto(animContext, catBtn.InputBegan, function(input)
				if
					input.UserInputType == Enum.UserInputType.Touch
					or input.UserInputType == Enum.UserInputType.MouseMovement
					or input.UserInputType == Enum.UserInputType.MouseButton1
				then
					realcar()
				end
			end)

			conectarContexto(animContext, catBtn.InputEnded, function(input)
				if
					input.UserInputType == Enum.UserInputType.Touch
					or input.UserInputType == Enum.UserInputType.MouseMovement
					or input.UserInputType == Enum.UserInputType.MouseButton1
				then
					apagar()
				end
			end)

			-- Click → abre submenu
			catBtn.MouseButton1Click:Connect(function()
				playSound("rbxassetid://157167203")

				-- Fechar hub
				fecharHub()

				-- Fechar submenu anterior
				closeActiveSubmenu()

				-- Abrir novo submenu
				activeSubmenu = cat.name
				if cat.openFunc then
					pcall(cat.openFunc)
				end
			end)
		end
	end

	buildGrid()
	updateNotifDot()

	-- (V4) Girar o celular não refazia a grade. As células são medidas em
	-- Scale, então a proporção da tela muda e a grade fica com coluna
	-- sobrando ou faltando até alguém apertar P/M/G. Reconstrói na virada,
	-- com task.defer para o sinal disparar uma vez só na rotação em vez de
	-- uma vez por quadro da animação de giro.
	local camera = workspace.CurrentCamera
	if camera then
		local reconstruindo = false
		conectarContexto(animContext, camera:GetPropertyChangedSignal("ViewportSize"), function()
			if reconstruindo or not hubFrame or not hubFrame.Parent then
				return
			end
			reconstruindo = true
			task.defer(function()
				reconstruindo = false
				if hubFrame and hubFrame.Parent then
					buildGrid()
				end
			end)
		end)
	end

	-- ===== CONEXÃO DO BOTÃO PRINCIPAL =====
	mainButton.MouseButton1Click:Connect(function()
		if hubOpen then
			-- Fechar tudo
			playSound("rbxassetid://157167205")
			fecharHub()
			closeActiveSubmenu()
		else
			-- Fechar submenu se aberto, senão abrir hub
			if activeSubmenu then
				closeActiveSubmenu()
				-- Reabrir hub
				playSound("rbxassetid://157167203")
				abrirHub()
				buildGrid() -- Refresh
			else
				playSound("rbxassetid://157167203")
				abrirHub()
				buildGrid() -- Refresh
			end
		end
	end)
end

-- =====================================
-- INICIALIZAÇÃO
-- =====================================

-- Esperar outros sistemas carregarem
task.spawn(function()
	task.wait(3)
	buildMenu()
end)

-- Rebuild ao respawnar
player.CharacterAdded:Connect(function()
	task.wait(2)
	if not menuGui or not menuGui.Parent then
		buildMenu()
	end
end)

-- =====================================
-- API PÚBLICA
-- =====================================

_G.UnifiedMenu = {
	rebuild = function()
		buildMenu()
	end,
	isOpen = function()
		return hubOpen
	end,
	close = function()
		fecharHub()
		closeActiveSubmenu()
	end,
	openCategory = function(categoryName)
		for _, cat in ipairs(categories) do
			if cat.name == categoryName and cat.openFunc then
				closeActiveSubmenu()
				activeSubmenu = cat.name
				pcall(cat.openFunc)
				return true
			end
		end
		return false
	end,
}

print([[
╔══════════════════════════════════════════════════════╗
║  UNIFIED MENU CLIENT V2 — CARREGADO                 ║
╠══════════════════════════════════════════════════════╣
║  SUBSTITUI: UnifiedMenu_Client_V1                    ║
║  REMOVER:   UnifiedMenu_Client_V1                    ║
╠══════════════════════════════════════════════════════╣
║  ÚNICO BOTÃO NA TELA (☰)                            ║
║  Todos os outros sistemas SEM botão próprio          ║
╠══════════════════════════════════════════════════════╣
║  CATEGORIAS:                                         ║
║  LOJA | INVENTÁRIO | TIMES | TROCAS                  ║
║  MISSÕES | MÚSICA | TUTORIAL | ADMIN                 ║
╚══════════════════════════════════════════════════════╝
]])
