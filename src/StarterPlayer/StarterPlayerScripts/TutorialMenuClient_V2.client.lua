-- ============================================
-- TUTORIAL MENU CLIENT V6 — INTERATIVO
-- (V6) ALTERAÇÕES: fontes unificadas em estilo retro (Arcade/Code)
-- Coloque em StarterPlayer > StarterPlayerScripts
-- Nome: "TutorialMenuClient_V2"
-- SUBSTITUI: TutorialMenuClient (V4)  →  REMOVER o antigo
-- ============================================
-- CORREÇÃO V5 (bug):
-- • Typewriter tinha RACE CONDITION (flag 'isTyping' compartilhada +
--   'typeConn' nunca usado) — ao avançar passo rápido, o texto antigo
--   "ressuscitava" e embaralhava com o novo. Agora usa TOKEN de geração:
--   cada digitação tem ID único e a anterior é cancelada de verdade.
-- ============================================
-- Mantém: mascote RPG, 15 passos, setas, barra de progresso,
--         auto-show p/ novos jogadores, sem botão próprio (menu unificado).
-- ============================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")
local GuiService = game:GetService("GuiService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- =====================================
-- DETECÇÃO DE PLATAFORMA
-- =====================================

local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
local isTablet = isMobile and (workspace.CurrentCamera.ViewportSize.X > 600)

-- =====================================
-- SONS
-- =====================================

local function playSound(id)
	pcall(function()
		local s = Instance.new("Sound")
		s.SoundId = id
		s.Volume = 0.45
		s.Parent = SoundService
		s:Play()
		s.Ended:Connect(function()
			s.Parent = nil
		end)
	end)
end

local SFX = {
	click = "rbxassetid://156785206",
	open = "rbxassetid://157167203",
	close = "rbxassetid://157167205",
	next = "rbxassetid://156785206",
	complete = "rbxassetid://5031873608",
	type_char = "rbxassetid://9118416910",
}

-- =====================================
-- AGUARDAR REMOTES
-- =====================================

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local getTutorialProgress = remotes:WaitForChild("GetTutorialProgress", 10)
local completeTutorial = remotes:WaitForChild("CompleteTutorial", 10)

if not getTutorialProgress or not completeTutorial then
	warn("[TUTORIAL V4] ❌ Remotes não encontrados!")
	return
end

-- =====================================
-- CORES
-- =====================================

local C = {
	bg = Color3.fromRGB(12, 12, 18),
	panel = Color3.fromRGB(22, 22, 32),
	border = Color3.fromRGB(255, 255, 255),
	gold = Color3.fromRGB(255, 215, 0),
	cyan = Color3.fromRGB(0, 200, 255),
	green = Color3.fromRGB(0, 220, 100),
	red = Color3.fromRGB(220, 40, 40),
	purple = Color3.fromRGB(180, 0, 220),
	orange = Color3.fromRGB(255, 140, 0),
	dimText = Color3.fromRGB(180, 180, 200),
	white = Color3.new(1, 1, 1),
}

-- =====================================
-- 15 PASSOS DO TUTORIAL
-- arrowX / arrowY  = posição Scale da seta na tela
-- arrowDir         = direção para onde a seta aponta (up/down/left/right)
-- arrowText        = texto sobre a seta
-- mascotColor      = cor do header do mascote neste passo
-- =====================================

local STEPS = {
	-- ── PASSO 1 ───────────────────────────────────────────────
	{
		title = "🎮 BEM-VINDO AO RETRO-VERSE!",
		mascot = "😁",
		mascotColor = C.cyan,
		dialogue = "Olá, guerreiro! Eu sou o NOOB GUIA e vou te mostrar tudo sobre o jogo!\n\nAqui no RetroVerse você escolhe personagens épicos e batalha contra outros jogadores pelo mapa. Vamos começar?",
		arrow = false,
	},
	-- ── PASSO 2 ───────────────────────────────────────────────
	{
		title = "🛡️ A ZONA SEGURA",
		mascot = "😌",
		mascotColor = C.green,
		dialogue = "Você SEMPRE começa na ZONA SEGURA! Percebe o escudo azul ao seu redor? Aqui você está 100% protegido — nenhum inimigo pode te machucar.\n\nUse a zona segura para preparar seu personagem antes de entrar em batalha!",
		arrow = true,
		arrowX = 0.50,
		arrowY = 0.34,
		arrowXM = 0.50,
		arrowYM = 0.30,
		arrowDir = "down",
		arrowText = "📍 VOCÊ ESTÁ NA ZONA SEGURA!",
	},
	-- ── PASSO 3 ───────────────────────────────────────────────
	{
		title = "☰ O MENU PRINCIPAL",
		mascot = "👆",
		mascotColor = C.gold,
		dialogue = "Vê esse botão ☰ no lado ESQUERDO da tela? É o seu MENU PRINCIPAL!\n\nClique nele para abrir o hub com todos os sistemas: Loja, Inventário, Times, Música, Tutorial e muito mais!",
		arrow = true,
		arrowX = 0.13,
		arrowY = 0.37,
		arrowXM = 0.20,
		arrowYM = 0.41,
		arrowDir = "left",
		arrowText = "☰ CLIQUE AQUI!",
	},
	-- ── PASSO 4 ───────────────────────────────────────────────
	{
		title = "🎭 PERSONAGENS DO JOGO",
		mascot = "🤩",
		mascotColor = C.purple,
		dialogue = "O jogo tem VÁRIOS personagens para desbloquear, cada um com habilidades únicas e HP diferente!\n\nExistem 4 tipos:\n• 🛒 LOJA — Compre com Moedas\n• 🏆 BOUNTY — Desbloqueie pela sua Fama\n• 💎 GAMEPASS — Compre com Robux\n• 🎯 INICIAL — Você já possui (Noob)!",
		arrow = false,
	},
	-- ── PASSO 5 ───────────────────────────────────────────────
	{
		title = "🛒 A LOJA — COMPRE COM MOEDAS",
		mascot = "💰",
		mascotColor = C.gold,
		dialogue = "Abra o Menu ☰ e vá em LOJA 🛒!\n\nLá você encontra personagens para comprar com suas MOEDAS 💰. Quanto mais raro o personagem, mais caro ele é. Comece pelo Noob (gratuito) e junte moedas para desbloquear os mais poderosos!",
		arrow = true,
		arrowX = 0.13,
		arrowY = 0.37,
		arrowXM = 0.20,
		arrowYM = 0.41,
		arrowDir = "left",
		arrowText = "☰ → LOJA!",
	},
	-- ── PASSO 6 ───────────────────────────────────────────────
	{
		title = "📦 INVENTÁRIO — EQUIPE SEU HERÓI",
		mascot = "⚔️",
		mascotColor = Color3.fromRGB(0, 200, 150),
		dialogue = "No Menu ☰ vá em INVENTÁRIO 📦!\n\nLá estão TODOS os personagens que você possui. Selecione um e clique em ▶ EQUIPAR para preparar seu herói.\n\n💡 Você também pode VENDER personagens de loja pelo botão 💰 — recebe 25% do preço original de volta!",
		arrow = true,
		arrowX = 0.13,
		arrowY = 0.37,
		arrowXM = 0.20,
		arrowYM = 0.41,
		arrowDir = "left",
		arrowText = "☰ → INVENTÁRIO!",
	},
	-- ── PASSO 7 ───────────────────────────────────────────────
	{
		title = "🗺️ EQUIPAR = IR PARA O MAPA!",
		mascot = "🚀",
		mascotColor = C.orange,
		dialogue = "Quando você EQUIPA um personagem acontece algo incrível...\n\nVocê é teleportado AUTOMATICAMENTE para o mapa de batalha! 🗺️\n\nPara voltar à Zona Segura, você precisa ser eliminado em combate. Escolha bem seu personagem antes de sair!",
		arrow = false,
	},
	-- ── PASSO 8 ───────────────────────────────────────────────
	{
		title = "⚔️ O COMBATE",
		mascot = "💥",
		mascotColor = C.red,
		dialogue = "No mapa, você tem FERRAMENTAS (armas) no Backpack — elas aparecem na parte inferior da tela!\n\nEquipe sua arma clicando nela e ataque outros jogadores. Cada personagem vem com ferramentas EXCLUSIVAS.\n\nFique de olho no HP no topo da tela — se chegar a ZERO você é eliminado!",
		arrow = false,
	},
	-- ── PASSO 9 ───────────────────────────────────────────────
	{
		title = "💰 RECOMPENSAS POR ELIMINAR",
		mascot = "🏆",
		mascotColor = C.gold,
		dialogue = "Eliminou um inimigo? PARABÉNS, guerreiro!\n\nVocê ganha automaticamente:\n• 💰 +50 MOEDAS por kill\n• ⚔️ +BOUNTY baseado na vítima\n\nO BOUNTY é sua FAMA no jogo — quanto mais kills, mais bounty você acumula. Use as moedas para comprar personagens melhores!",
		arrow = false,
	},
	-- ── PASSO 10 ──────────────────────────────────────────────
	{
		title = "💀 DROP DE MOEDAS NA MORTE",
		mascot = "😱",
		mascotColor = C.red,
		dialogue = "⚠️ ATENÇÃO! Quando você MORRE, 10% das suas moedas caem no chão como um COFRE!\n\nOutros jogadores podem ROUBAR suas moedas coletando o cofre.\n\n💡 Mas você também pode COLETAR as moedas de quem você eliminar! Nunca fique com muito dinheiro no bolso antes de uma batalha!",
		arrow = false,
	},
	-- ── PASSO 11 ──────────────────────────────────────────────
	{
		title = "🏆 PERSONAGENS DE BOUNTY",
		mascot = "⭐",
		mascotColor = Color3.fromRGB(255, 100, 200),
		dialogue = "Além da Loja, no Menu ☰ → INVENTÁRIO → aba RECOMPENSA existem personagens especiais!\n\nEsses personagens são desbloqueados pelo seu BOUNTY (fama). Quanto mais jogadores você eliminar, mais bounty ganha — e mais personagens exclusivos você pode usar no combate!",
		arrow = true,
		arrowX = 0.13,
		arrowY = 0.37,
		arrowXM = 0.20,
		arrowYM = 0.41,
		arrowDir = "left",
		arrowText = "☰ → LOJA → RECOMPENSA",
	},
	-- ── PASSO 12 ──────────────────────────────────────────────
	{
		title = "👥 SISTEMA DE TIMES",
		mascot = "🤝",
		mascotColor = Color3.fromRGB(0, 100, 255),
		dialogue = "Você pode criar ou entrar em um TIME 👥!\n\nVá em Menu ☰ → TIMES. Com aliados você batalha em equipe e o melhor: membros do mesmo time NÃO se machucam entre si!\n\n• Crie um time e escolha uma cor\n• Convide amigos clicando em ✉️\n• Times são desfeitos quando o líder sai",
		arrow = true,
		arrowX = 0.13,
		arrowY = 0.37,
		arrowXM = 0.20,
		arrowYM = 0.41,
		arrowDir = "left",
		arrowText = "☰ → TIMES!",
	},
	-- ── PASSO 13 ──────────────────────────────────────────────
	{
		title = "🎁 RECOMPENSAS DIÁRIAS",
		mascot = "🎁",
		mascotColor = C.orange,
		dialogue = "Todo dia você pode coletar RECOMPENSAS DIÁRIAS 🎁!\n\nVá em Menu ☰ → DAILY. Quanto mais dias seguidos você jogar (STREAK 🔥), maior a recompensa!\n\n• Após 3 dias seguidos: desbloqueie RECUPERAÇÃO\n• Final de semana: RECOMPENSA DOBRADA!\n• Dia 6: Personagem exclusivo temporário!",
		arrow = false,
	},
	-- ── PASSO 14 ──────────────────────────────────────────────
	{
		title = "⚡ SISTEMA DE DESPERTAR",
		mascot = "⚡",
		mascotColor = C.purple,
		dialogue = "Alguns personagens podem DESPERTAR ⚡!\n\nDespertares são formas EVOLUÍDAS com poderes maiores e aparência diferente. Para despertar você precisa:\n\n1️⃣ Possuir o personagem original\n2️⃣ Ter o Badge OU Gamepass especial\n\nProcure o botão ⚡ DESPERTAR nos cards de personagem no Inventário!",
		arrow = false,
	},
	-- ── PASSO 15 ──────────────────────────────────────────────
	{
		title = "✅ TUTORIAL COMPLETO — BOA SORTE!",
		mascot = "🏆",
		mascotColor = C.green,
		dialogue = "PARABÉNS! Você completou o tutorial e ganhou 💰 100 MOEDAS de bônus!\n\nO ciclo do RetroVerse é simples:\n🛡️ Zona Segura → 🎭 Escolher Personagem → ⚔️ Batalhar → 💰 Ganhar Moedas → 🛒 Comprar Mais!\n\nAté em breve, guerreiro! Use o Menu ☰ sempre que precisar de ajuda. 🎮",
		arrow = false,
		isLast = true,
	},
}

-- =====================================
-- VARIÁVEIS DE ESTADO
-- =====================================

local tutorialGui = nil
local isOpen = false
local currentStep = 1
local isTyping = false
local typeToken = 0 -- ID de geração do typewriter (cancela o anterior de verdade)
local arrowToken = 0 -- geração do loop da seta (cancela o anterior sem :Disconnect)

-- =====================================
-- CRIAR INTERFACE
-- =====================================

local function createTutorialInterface()
	if tutorialGui then
		tutorialGui.Parent = nil
	end

	tutorialGui = Instance.new("ScreenGui")
	tutorialGui.Name = "TutorialMenuV4"
	tutorialGui.ResetOnSpawn = false
	tutorialGui.IgnoreGuiInset = true
	tutorialGui.DisplayOrder = 205 -- acima dos menus normais (50) mas abaixo de notificações admin (300)
	tutorialGui.Parent = playerGui

	-- =====================================
	-- 1. SETA ANIMADA
	-- =====================================

	local arrowContainer = Instance.new("Frame")
	arrowContainer.Name = "ArrowContainer"
	arrowContainer.Size = UDim2.new(0, isMobile and 160 or 180, 0, isMobile and 70 or 80)
	arrowContainer.AnchorPoint = Vector2.new(0.5, 0.5)
	arrowContainer.BackgroundColor3 = Color3.fromRGB(15, 15, 22)
	arrowContainer.BorderColor3 = C.gold
	arrowContainer.BorderSizePixel = 3
	arrowContainer.Visible = false
	arrowContainer.ZIndex = 20
	arrowContainer.Parent = tutorialGui

	local arrowCorner = Instance.new("UICorner")
	arrowCorner.CornerRadius = UDim.new(0.15, 0)
	arrowCorner.Parent = arrowContainer

	-- Símbolo grande de direção
	local arrowSymbol = Instance.new("TextLabel")
	arrowSymbol.Name = "ArrowSymbol"
	arrowSymbol.Size = UDim2.new(0.28, 0, 1, 0)
	arrowSymbol.BackgroundTransparency = 1
	arrowSymbol.Text = "⬅"
	arrowSymbol.TextColor3 = C.gold
	arrowSymbol.TextScaled = true
	arrowSymbol.Font = Enum.Font.Arcade
	arrowSymbol.ZIndex = 21
	arrowSymbol.Parent = arrowContainer

	-- Texto de dica
	local arrowHint = Instance.new("TextLabel")
	arrowHint.Name = "ArrowHint"
	arrowHint.Size = UDim2.new(0.70, 0, 1, 0)
	arrowHint.Position = UDim2.new(0.28, 0, 0, 0)
	arrowHint.BackgroundTransparency = 1
	arrowHint.Text = "CLIQUE AQUI!"
	arrowHint.TextColor3 = C.white
	arrowHint.TextScaled = true
	arrowHint.Font = Enum.Font.Arcade
	arrowHint.TextWrapped = true
	arrowHint.ZIndex = 21
	arrowHint.Parent = arrowContainer

	-- =====================================
	-- 2. CAIXA DE DIÁLOGO (parte inferior)
	-- =====================================

	local dialogH = isMobile and 0.30 or 0.27
	local dialogFrame = Instance.new("Frame")
	dialogFrame.Name = "DialogFrame"
	dialogFrame.Size = UDim2.new(isMobile and 0.96 or 0.88, 0, dialogH, 0)
	dialogFrame.Position = UDim2.new(0.5, 0, 1.4, 0) -- começa fora da tela
	dialogFrame.AnchorPoint = Vector2.new(0.5, 1)
	dialogFrame.BackgroundColor3 = C.bg
	dialogFrame.BorderColor3 = C.cyan
	dialogFrame.BorderSizePixel = 3
	dialogFrame.Visible = false
	dialogFrame.ZIndex = 15
	dialogFrame.Parent = tutorialGui

	local dialogCorner = Instance.new("UICorner")
	dialogCorner.CornerRadius = UDim.new(0.025, 0)
	dialogCorner.Parent = dialogFrame

	-- ── Header: mascote + nome + step counter ──────────────────

	local headerH = isMobile and 0.22 or 0.20
	local headerBar = Instance.new("Frame")
	headerBar.Size = UDim2.new(1, 0, headerH, 0)
	headerBar.BackgroundColor3 = C.cyan -- será atualizado por passo
	headerBar.BorderSizePixel = 0
	headerBar.ZIndex = 16
	headerBar.Parent = dialogFrame

	local headerCorner = Instance.new("UICorner")
	headerCorner.CornerRadius = UDim.new(0.05, 0)
	headerCorner.Parent = headerBar

	-- Mascote (emoji)
	local mascotLabel = Instance.new("TextLabel")
	mascotLabel.Name = "MascotLabel"
	mascotLabel.Size = UDim2.new(0.09, 0, 1.0, 0)
	mascotLabel.Position = UDim2.new(0.01, 0, 0, 0)
	mascotLabel.BackgroundTransparency = 1
	mascotLabel.Text = "😁"
	mascotLabel.TextScaled = true
	mascotLabel.Font = Enum.Font.Arcade
	mascotLabel.ZIndex = 17
	mascotLabel.Parent = headerBar

	-- Nome do mascote
	local mascotName = Instance.new("TextLabel")
	mascotName.Name = "MascotName"
	mascotName.Size = UDim2.new(0.40, 0, 0.55, 0)
	mascotName.Position = UDim2.new(0.11, 0, 0.05, 0)
	mascotName.BackgroundTransparency = 1
	mascotName.Text = "NOOB GUIA"
	mascotName.TextColor3 = C.bg
	mascotName.TextScaled = true
	mascotName.Font = Enum.Font.Arcade
	mascotName.TextXAlignment = Enum.TextXAlignment.Left
	mascotName.ZIndex = 17
	mascotName.Parent = headerBar

	-- Título do passo
	local stepTitleLabel = Instance.new("TextLabel")
	stepTitleLabel.Name = "StepTitle"
	stepTitleLabel.Size = UDim2.new(0.40, 0, 0.45, 0)
	stepTitleLabel.Position = UDim2.new(0.11, 0, 0.52, 0)
	stepTitleLabel.BackgroundTransparency = 1
	stepTitleLabel.Text = ""
	stepTitleLabel.TextColor3 = C.bg
	stepTitleLabel.TextScaled = true
	stepTitleLabel.Font = Enum.Font.Arcade
	stepTitleLabel.TextXAlignment = Enum.TextXAlignment.Left
	stepTitleLabel.ZIndex = 17
	stepTitleLabel.Parent = headerBar

	-- Contador passo X/15
	local stepCounter = Instance.new("TextLabel")
	stepCounter.Name = "StepCounter"
	stepCounter.Size = UDim2.new(0.20, 0, 0.55, 0)
	stepCounter.Position = UDim2.new(0.62, 0, 0.05, 0)
	stepCounter.BackgroundTransparency = 1
	stepCounter.Text = "1 / 15"
	stepCounter.TextColor3 = C.bg
	stepCounter.TextScaled = true
	stepCounter.Font = Enum.Font.Arcade
	stepCounter.TextXAlignment = Enum.TextXAlignment.Right
	stepCounter.ZIndex = 17
	stepCounter.Parent = headerBar

	-- Barra de progresso (dentro do header à direita)
	local progressBG = Instance.new("Frame")
	progressBG.Size = UDim2.new(0.16, 0, 0.28, 0)
	progressBG.Position = UDim2.new(0.63, 0, 0.62, 0)
	progressBG.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	progressBG.BackgroundTransparency = 0.5
	progressBG.BorderSizePixel = 0
	progressBG.ZIndex = 17
	progressBG.Parent = headerBar

	local progressFill = Instance.new("Frame")
	progressFill.Name = "ProgressFill"
	progressFill.Size = UDim2.new(0, 0, 1, 0)
	progressFill.BackgroundColor3 = C.bg
	progressFill.BackgroundTransparency = 0.15
	progressFill.BorderSizePixel = 0
	progressFill.ZIndex = 18
	progressFill.Parent = progressBG

	-- Botão fechar (X)
	local closeBtn = Instance.new("TextButton")
	closeBtn.Size = UDim2.new(0.06, 0, 0.80, 0)
	closeBtn.Position = UDim2.new(0.93, 0, 0.10, 0)
	closeBtn.BackgroundColor3 = C.red
	closeBtn.BorderSizePixel = 0
	closeBtn.Text = "X"
	closeBtn.TextColor3 = C.white
	closeBtn.TextScaled = true
	closeBtn.Font = Enum.Font.Arcade
	closeBtn.ZIndex = 17
	closeBtn.Parent = headerBar

	local closeBtnCorner = Instance.new("UICorner")
	closeBtnCorner.CornerRadius = UDim.new(0.3, 0)
	closeBtnCorner.Parent = closeBtn

	-- ── Área do diálogo ────────────────────────────────────────

	local dialogTextArea = Instance.new("Frame")
	dialogTextArea.Size = UDim2.new(0.97, 0, 0.52, 0)
	dialogTextArea.Position = UDim2.new(0.015, 0, headerH + 0.01, 0)
	dialogTextArea.BackgroundColor3 = C.panel
	dialogTextArea.BorderColor3 = Color3.fromRGB(60, 60, 80)
	dialogTextArea.BorderSizePixel = 1
	dialogTextArea.ZIndex = 16
	dialogTextArea.Parent = dialogFrame

	local dialogTextCorner = Instance.new("UICorner")
	dialogTextCorner.CornerRadius = UDim.new(0.04, 0)
	dialogTextCorner.Parent = dialogTextArea

	local dialogTextLabel = Instance.new("TextLabel")
	dialogTextLabel.Name = "DialogText"
	dialogTextLabel.Size = UDim2.new(0.96, 0, 0.94, 0)
	dialogTextLabel.Position = UDim2.new(0.02, 0, 0.03, 0)
	dialogTextLabel.BackgroundTransparency = 1
	dialogTextLabel.Text = ""
	dialogTextLabel.TextColor3 = C.white
	dialogTextLabel.TextSize = isMobile and 13 or 15
	dialogTextLabel.Font = Enum.Font.Code
	dialogTextLabel.TextWrapped = true
	dialogTextLabel.TextXAlignment = Enum.TextXAlignment.Left
	dialogTextLabel.TextYAlignment = Enum.TextYAlignment.Top
	dialogTextLabel.ZIndex = 17
	dialogTextLabel.Parent = dialogTextArea

	-- "pressione para avançar" hint (piscante)
	local pressHint = Instance.new("TextLabel")
	pressHint.Name = "PressHint"
	pressHint.Size = UDim2.new(0.40, 0, 0.85, 0)
	pressHint.Position = UDim2.new(0.59, 0, 0.08, 0)
	pressHint.BackgroundTransparency = 1
	pressHint.Text = "▶ clique para avançar"
	pressHint.TextColor3 = C.dimText
	pressHint.TextSize = isMobile and 11 or 12
	pressHint.Font = Enum.Font.Code
	pressHint.TextXAlignment = Enum.TextXAlignment.Right
	pressHint.TextYAlignment = Enum.TextYAlignment.Bottom
	pressHint.Visible = false
	pressHint.ZIndex = 17
	pressHint.Parent = dialogTextArea

	-- piscar hint quando digitação acabar
	task.spawn(function()
		while pressHint.Parent do
			TweenService:Create(
				pressHint,
				TweenInfo.new(0.9, Enum.EasingStyle.Sine),
				{ TextTransparency = 0.5 }
			):Play()
			task.wait(0.9)
			TweenService
				:Create(
					pressHint,
					TweenInfo.new(0.9, Enum.EasingStyle.Sine),
					{ TextTransparency = 0 }
				)
				:Play()
			task.wait(0.9)
		end
	end)

	-- ── Navegação ──────────────────────────────────────────────

	local navY = headerH + 0.01 + 0.52 + 0.02
	local navFrame = Instance.new("Frame")
	navFrame.Size = UDim2.new(0.97, 0, 1 - navY - 0.01, 0)
	navFrame.Position = UDim2.new(0.015, 0, navY, 0)
	navFrame.BackgroundTransparency = 1
	navFrame.ZIndex = 16
	navFrame.Parent = dialogFrame

	local prevBtn = Instance.new("TextButton")
	prevBtn.Name = "PrevBtn"
	prevBtn.Size = UDim2.new(0.24, 0, 1, 0)
	prevBtn.Position = UDim2.new(0, 0, 0, 0)
	prevBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 70)
	prevBtn.BorderColor3 = Color3.fromRGB(100, 100, 140)
	prevBtn.BorderSizePixel = 2
	prevBtn.Text = "◀ VOLTAR"
	prevBtn.TextColor3 = C.dimText
	prevBtn.TextScaled = true
	prevBtn.Font = Enum.Font.Arcade
	prevBtn.ZIndex = 17
	prevBtn.Parent = navFrame

	local prevCorner = Instance.new("UICorner")
	prevCorner.CornerRadius = UDim.new(0.25, 0)
	prevCorner.Parent = prevBtn

	local nextBtn = Instance.new("TextButton")
	nextBtn.Name = "NextBtn"
	nextBtn.Size = UDim2.new(0.38, 0, 1, 0)
	nextBtn.Position = UDim2.new(0.31, 0, 0, 0)
	nextBtn.BackgroundColor3 = C.green
	nextBtn.BorderSizePixel = 0
	nextBtn.Text = "AVANÇAR ▶"
	nextBtn.TextColor3 = C.bg
	nextBtn.TextScaled = true
	nextBtn.Font = Enum.Font.Arcade
	nextBtn.ZIndex = 17
	nextBtn.Parent = navFrame

	local nextCorner = Instance.new("UICorner")
	nextCorner.CornerRadius = UDim.new(0.25, 0)
	nextCorner.Parent = nextBtn

	local skipBtn = Instance.new("TextButton")
	skipBtn.Name = "SkipBtn"
	skipBtn.Size = UDim2.new(0.26, 0, 1, 0)
	skipBtn.Position = UDim2.new(0.74, 0, 0, 0)
	skipBtn.BackgroundColor3 = Color3.fromRGB(45, 45, 60)
	skipBtn.BorderColor3 = Color3.fromRGB(80, 80, 100)
	skipBtn.BorderSizePixel = 1
	skipBtn.Text = "PULAR"
	skipBtn.TextColor3 = C.dimText
	skipBtn.TextScaled = true
	skipBtn.Font = Enum.Font.Code
	skipBtn.ZIndex = 17
	skipBtn.Parent = navFrame

	local skipCorner = Instance.new("UICorner")
	skipCorner.CornerRadius = UDim.new(0.25, 0)
	skipCorner.Parent = skipBtn

	-- =====================================
	-- FUNÇÕES DE CONTROLE
	-- =====================================

	-- Mapeia direção → símbolo Unicode
	local DIR_SYMBOL = {
		left = "⬅",
		right = "➡",
		up = "⬆",
		down = "⬇",
		none = "🎯",
	}

	-- Posiciona e configura a seta
	local function setArrow(step)
		-- Para o bounce anterior incrementando o token (o loop antigo sai sozinho).
		-- BUGFIX: antes usava arrowBounceConn:Disconnect() numa THREAD (task.spawn),
		-- o que causava "attempt to index thread with 'Disconnect'".
		arrowToken = arrowToken + 1
		local myToken = arrowToken

		if not step.arrow then
			arrowContainer.Visible = false
			return
		end

		-- Posição (mobile vs PC)
		local ax = (isMobile and step.arrowXM) or step.arrowX or 0.5
		local ay = (isMobile and step.arrowYM) or step.arrowY or 0.3

		arrowContainer.Position = UDim2.new(ax, 0, ay, 0)
		arrowSymbol.Text = DIR_SYMBOL[step.arrowDir or "left"]
		arrowHint.Text = step.arrowText or "CLIQUE AQUI!"
		arrowContainer.Visible = true

		-- Animação bounce — pulso de cor na borda
		task.spawn(function()
			while
				arrowContainer
				and arrowContainer.Parent
				and arrowContainer.Visible
				and myToken == arrowToken
			do
				TweenService:Create(
					arrowContainer,
					TweenInfo.new(0.5, Enum.EasingStyle.Sine),
					{ BorderColor3 = Color3.fromRGB(255, 255, 100) }
				):Play()
				task.wait(0.5)
				TweenService:Create(
					arrowContainer,
					TweenInfo.new(0.5, Enum.EasingStyle.Sine),
					{ BorderColor3 = C.gold }
				):Play()
				TweenService:Create(
					arrowSymbol,
					TweenInfo.new(0.5, Enum.EasingStyle.Sine),
					{ TextTransparency = 0.3 }
				):Play()
				task.wait(0.5)
				TweenService:Create(
					arrowSymbol,
					TweenInfo.new(0.5, Enum.EasingStyle.Sine),
					{ TextTransparency = 0 }
				):Play()
			end
		end)
	end

	-- Efeito typewriter no diálogo
	local function typeText(fullText, onDone)
		-- Cancela qualquer typewriter anterior gerando um novo token.
		typeToken = typeToken + 1
		local myToken = typeToken
		isTyping = true
		pressHint.Visible = false
		dialogTextLabel.Text = ""

		task.spawn(function()
			local i = 0
			-- Só continua enquanto ESTE typewriter for o atual (sem race condition).
			while i < #fullText and myToken == typeToken do
				i = i + 1
				dialogTextLabel.Text = string.sub(fullText, 1, i)
				task.wait(0.022)
			end
			-- Se foi substituído por outro passo, não toca em mais nada.
			if myToken ~= typeToken then
				return
			end
			-- garantir texto completo
			dialogTextLabel.Text = fullText
			isTyping = false
			pressHint.Visible = true
			if onDone then
				onDone()
			end
		end)
	end

	-- Atualiza a interface para o passo atual
	local function showStep(n)
		local step = STEPS[n]
		if not step then
			return
		end

		-- Parar typewriter em andamento (incrementa token = cancela na hora)
		typeToken = typeToken + 1
		isTyping = false

		-- Atualizar header
		TweenService:Create(headerBar, TweenInfo.new(0.3), { BackgroundColor3 = step.mascotColor })
			:Play()

		mascotLabel.Text = step.mascot
		stepTitleLabel.Text = step.title
		stepCounter.Text = string.format("%d / %d", n, #STEPS)

		-- Progresso
		local pct = (n - 1) / (#STEPS - 1)
		TweenService:Create(
			progressFill,
			TweenInfo.new(0.4, Enum.EasingStyle.Quad),
			{ Size = UDim2.new(pct, 0, 1, 0) }
		):Play()

		-- Seta
		setArrow(step)

		-- Botão VOLTAR
		prevBtn.Visible = n > 1

		-- Botão AVANÇAR / CONCLUIR
		if step.isLast then
			nextBtn.Text = "✅ CONCLUIR"
			nextBtn.BackgroundColor3 = C.gold
			nextBtn.TextColor3 = C.bg
		else
			nextBtn.Text = "AVANÇAR ▶"
			nextBtn.BackgroundColor3 = C.green
			nextBtn.TextColor3 = C.bg
		end

		-- Pular fica invisível no último passo
		skipBtn.Visible = not step.isLast

		-- Texto com typewriter
		typeText(step.dialogue)

		playSound(SFX.next)
	end

	-- Abrir / fechar (slide in/out)
	local function openTutorial()
		if isOpen then
			return
		end
		isOpen = true
		currentStep = 1

		dialogFrame.Visible = true
		dialogFrame.Position = UDim2.new(0.5, 0, 1.4, 0)

		TweenService:Create(
			dialogFrame,
			TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
			{ Position = UDim2.new(0.5, 0, 0.995, 0) }
		):Play()

		playSound(SFX.open)
		showStep(currentStep)
	end

	local function closeTutorial()
		if not isOpen then
			return
		end
		isOpen = false
		isTyping = false

		-- Esconder seta (para o bounce via token, sem :Disconnect numa thread)
		arrowContainer.Visible = false
		arrowToken = arrowToken + 1

		TweenService:Create(
			dialogFrame,
			TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{ Position = UDim2.new(0.5, 0, 1.4, 0) }
		):Play()

		task.delay(0.35, function()
			if not isOpen and dialogFrame.Parent then
				dialogFrame.Visible = false
			end
		end)

		playSound(SFX.close)
	end

	local function completeTutorialAction()
		closeTutorial()
		completeTutorial:FireServer()
		playSound(SFX.complete)
	end

	-- ── Avançar passo (clique em qualquer lugar da área de texto)
	local function advanceOrSkipType()
		if isTyping then
			-- Mostrar texto completo imediatamente (para o typewriter via token)
			typeToken = typeToken + 1
			isTyping = false
			local step = STEPS[currentStep]
			if step then
				dialogTextLabel.Text = step.dialogue
				pressHint.Visible = true
			end
		end
	end

	dialogTextArea.InputBegan:Connect(function(input)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			advanceOrSkipType()
		end
	end)

	-- ── Botão AVANÇAR
	nextBtn.MouseButton1Click:Connect(function()
		playSound(SFX.click)
		if STEPS[currentStep] and STEPS[currentStep].isLast then
			completeTutorialAction()
			return
		end
		currentStep = math.min(currentStep + 1, #STEPS)
		showStep(currentStep)
	end)

	-- ── Botão VOLTAR
	prevBtn.MouseButton1Click:Connect(function()
		playSound(SFX.click)
		currentStep = math.max(currentStep - 1, 1)
		showStep(currentStep)
	end)

	-- ── Botão PULAR
	skipBtn.MouseButton1Click:Connect(function()
		playSound(SFX.click)
		completeTutorialAction()
	end)

	-- ── Botão X (fechar sem concluir)
	closeBtn.MouseButton1Click:Connect(function()
		closeTutorial()
	end)

	-- ── Hover PC nos botões de navegação
	if not isMobile then
		local function addHover(btn, baseColor, hoverColor)
			btn.MouseEnter:Connect(function()
				TweenService:Create(btn, TweenInfo.new(0.12), { BackgroundColor3 = hoverColor })
					:Play()
			end)
			btn.MouseLeave:Connect(function()
				TweenService:Create(btn, TweenInfo.new(0.12), { BackgroundColor3 = baseColor })
					:Play()
			end)
		end
		addHover(prevBtn, Color3.fromRGB(50, 50, 70), Color3.fromRGB(70, 70, 100))
		addHover(nextBtn, C.green, Color3.fromRGB(0, 255, 130))
		addHover(skipBtn, Color3.fromRGB(45, 45, 60), Color3.fromRGB(65, 65, 85))
		addHover(closeBtn, C.red, Color3.fromRGB(255, 70, 70))
	end

	-- =====================================
	-- EXPOR FUNÇÕES GLOBAIS
	-- =====================================

	_G.OpenTutorialMenu = function()
		openTutorial()
	end

	_G.CloseTutorialMenu = function()
		closeTutorial()
	end

	-- =====================================
	-- CARREGAR PROGRESSO E AUTO-SHOW
	-- =====================================

	task.spawn(function()
		task.wait(2) -- aguardar carregamento da UI principal

		local ok, progress = pcall(function()
			return getTutorialProgress:InvokeServer()
		end)

		if ok and progress then
			-- Auto-show para quem nunca completou
			if progress.shouldAutoShow then
				task.wait(1.5) -- aguardar outros sistemas abrirem
				openTutorial()
			end
		else
			warn("[TUTORIAL V4] ❌ Erro ao carregar progresso")
		end
	end)
end

-- =====================================
-- INICIALIZAÇÃO AO ENTRAR/RESPAWNAR
-- =====================================

player.CharacterAdded:Connect(function()
	task.wait(2)
	if not tutorialGui or not tutorialGui.Parent then
		createTutorialInterface()
	end
end)

if player.Character then
	createTutorialInterface()
else
	task.spawn(function()
		task.wait(1)
		createTutorialInterface()
	end)
end

-- =====================================
-- REGISTRAR NO MENU UNIFICADO
-- =====================================

task.spawn(function()
	local timeout = 0
	while not _G.RegisterMenuCategory and timeout < 15 do
		task.wait(0.5)
		timeout = timeout + 0.5
	end

	if _G.RegisterMenuCategory then
		_G.RegisterMenuCategory("TUTORIAL", "❓", function()
			if _G.OpenTutorialMenu then
				_G.OpenTutorialMenu()
			end
		end, function()
			if _G.CloseTutorialMenu then
				_G.CloseTutorialMenu()
			end
		end, 8)

		print("[TUTORIAL V4] ✓ Registrado no Menu Unificado: TUTORIAL")
	else
		warn("[TUTORIAL V4] ⚠️ Menu Unificado não encontrado — RegisterMenuCategory ausente")
	end
end)

print([[
╔════════════════════════════════════════════════════╗
║  ✅ TUTORIAL MENU CLIENT V4 CARREGADO             ║
╠════════════════════════════════════════════════════╣
║  SUBSTITUI: TUTORIAL_MENU_CLIENT_V3               ║
║  REMOVER:   TUTORIAL_MENU_CLIENT_V3               ║
╠════════════════════════════════════════════════════╣
║  NOVIDADES V4:                                     ║
║  • 15 passos interativos cobrindo todos sistemas  ║
║  • Mascote NOOB GUIA com caixa de diálogo RPG     ║
║  • Efeito typewriter (texto digitado na tela)     ║
║  • Seta animada apontando para elementos da UI    ║
║  • Barra de progresso visual (0% → 100%)          ║
║  • Slide-in / Slide-out suave na caixa            ║
║  • Auto-show para novos jogadores                 ║
║  • Sem botão próprio — usa Menu Unificado (☰)     ║
╠════════════════════════════════════════════════════╣
║  PASSOS COBERTOS:                                  ║
║  1  Bem-vindo        9  Recomp. por kill          ║
║  2  Zona Segura     10  Drop de moedas            ║
║  3  Botão ☰         11  Personagens Bounty        ║
║  4  Personagens     12  Sistema de Times          ║
║  5  Loja            13  Recompensas Diárias       ║
║  6  Inventário      14  Despertar                 ║
║  7  Ir ao Mapa      15  Conclusão (+100 moedas)   ║
║  8  Combate                                        ║
╠════════════════════════════════════════════════════╣
║  API Global:                                       ║
║  • _G.OpenTutorialMenu()                          ║
║  • _G.CloseTutorialMenu()                         ║
╚════════════════════════════════════════════════════╝
]])
