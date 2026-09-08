-- Nome: TutorialMenuClient_V2
-- Coloque em: StarterPlayer > StarterPlayerScripts
-- V8.1 — tutorial cinematográfico retrô, responsivo, com 24 etapas.
--
-- (V8.1) A CÂMERA NUNCA ASSUMIA E O BOTÃO PARECIA MORTO — uma causa só.
-- startCamera() rodava UMA VEZ, na abertura. A guarda exige a tag
-- `InSafeZone`, que quem põe no personagem é o servidor (SpawnSystem):
-- abrir o tutorial um segundo cedo demais, ou de fora do lobby, fazia a
-- recusa valer para a sessão inteira, em silêncio. E o botão MOV. só
-- chamava a mesma startCamera(), que recusava de novo — daí a impressão
-- de botão sem função. Agora ele tenta de novo a cada 0,5 s enquanto o
-- tutorial está aberto, então a cena assume sozinha assim que o jogador
-- entra na base, e o botão mostra o MOTIVO da recusa em vez de um
-- "CÂMERA: LIVRE" que não explicava nada.
--
-- Junto vai uma garantia: sem cena em andamento, o bloqueio de movimento
-- é desfeito todo quadro. Travar o personagem é o pior estrago que este
-- script consegue causar, e não vale depender de um único caminho de
-- saída para desfazer isso.
-- Atualiza o MESMO LocalScript V7; mantém as APIs do menu unificado e os remotes.
-- Câmera apenas na zona segura, com devolução no fechamento/respawn/interrupção.
-- Typewriter por grafemas, páginas legíveis e animações canceláveis.
-- Economia e conclusão continuam exclusivamente no TutorialSystemServer.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local ContextActionService = game:GetService("ContextActionService")
local SoundService = game:GetService("SoundService")
local VRService = game:GetService("VRService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local module = script.Parent:WaitForChild("TutorialPresentation", 20)
if not module then
	warn("[TUTORIAL V8] TutorialPresentation ausente; publique o pacote completo.")
	return
end
local Presentation = require(module)
local remotes = ReplicatedStorage:WaitForChild("Remotes", 30)
local getTutorialProgress = remotes and remotes:WaitForChild("GetTutorialProgress", 15)
local completeTutorial = remotes and remotes:WaitForChild("CompleteTutorial", 15)
if not getTutorialProgress or not completeTutorial then
	warn("[TUTORIAL V8] Remotes não encontrados.")
	return
end

local C = {
	bg = Color3.fromRGB(12, 12, 18),
	panel = Color3.fromRGB(22, 22, 32),
	gold = Color3.fromRGB(255, 215, 0),
	cyan = Color3.fromRGB(0, 200, 255),
	green = Color3.fromRGB(0, 220, 100),
	red = Color3.fromRGB(220, 40, 40),
	purple = Color3.fromRGB(180, 0, 220),
	orange = Color3.fromRGB(255, 140, 0),
	dimText = Color3.fromRGB(180, 180, 200),
	white = Color3.new(1, 1, 1),
}

local STEPS = {
	-- ── PASSO 1 ───────────────────────────────────────────────
	{
		title = "🎮 BEM-VINDO AO RETRO-VERSE!",
		mascot = "😁",
		mascotColor = C.cyan,
		dialogue = "Olá, guerreiro! Eu sou o NOOB GUIA.\n\nO RetroVerse tem MUITA coisa: personagens, passivas, níveis, despertar, chefões, times, trocas e mais. Vou te mostrar tudo, na ordem.\n\nUse ◀ ▶ para navegar. Bora?",
		arrow = false,
	},
	-- ── PASSO 2 ───────────────────────────────────────────────
	{
		title = "🛡️ A ZONA SEGURA",
		mascot = "😌",
		mascotColor = C.green,
		dialogue = "Você SEMPRE nasce na ZONA SEGURA. Aqui ninguém te machuca.\n\nEla não é só um abrigo: é o único lugar (junto de estar desequipado) onde você pode MEXER NAS SUAS PASSIVAS. Guarde isso, volto nesse assunto.",
		arrow = true,
	},
	-- ── PASSO 3 ───────────────────────────────────────────────
	{
		title = "☰ O MENU PRINCIPAL",
		mascot = "🤓",
		mascotColor = C.gold,
		dialogue = "Tudo se abre pelo botão ☰.\n\nLoja, Inventário, Passivas, Missões, Conquistas, Times, Duelos, Trocas, Diárias, Jornada do Recruta, Chefão e Música. Nenhuma tela tem botão próprio flutuando na sua frente.",
		arrow = true,
	},
	-- ── PASSO 4 ───────────────────────────────────────────────
	{
		title = "🎭 OS PERSONAGENS",
		mascot = "🦸",
		mascotColor = C.purple,
		dialogue = "Cada personagem tem VIDA própria, ATRIBUTOS próprios e até 7 HABILIDADES (Tools).\n\nEles vêm de categorias diferentes: GRÁTIS, LOJA (moedas), BOUNTY (reputação), GAMEPASS e EMBLEMA.",
		arrow = false,
	},
	-- ── PASSO 5 ───────────────────────────────────────────────
	{
		title = "🛒 A LOJA",
		mascot = "🤑",
		mascotColor = C.gold,
		dialogue = "Na Loja você compra personagens com MOEDAS 💰.\n\nGanha moedas eliminando jogadores, derrotando NPCs, completando missões e coletando a recompensa diária. Se vender um personagem, recebe 25% de volta.",
		arrow = true,
	},
	-- ── PASSO 6 ───────────────────────────────────────────────
	{
		title = "📦 INVENTÁRIO — EQUIPAR",
		mascot = "😎",
		mascotColor = C.cyan,
		dialogue = "No Inventário estão os seus personagens.\n\nClicar em EQUIPAR troca sua vida, seus atributos e suas habilidades para as daquele personagem — e te manda para o mapa.\n\n⚠️ Equipado = fora da proteção. Prepare-se antes.",
		arrow = true,
	},
	-- ── PASSO 7 ───────────────────────────────────────────────
	{
		title = "⚔️ O COMBATE",
		mascot = "😤",
		mascotColor = C.red,
		dialogue = "O dano não é um número solto: ele passa por ATAQUE, DEFESA, CRÍTICO e RESISTÊNCIA.\n\nSeu personagem, seu nível e suas passivas mexem nesses números. Dois personagens com a mesma Tool batem diferente.",
		arrow = false,
	},
	-- ── PASSO 8 ───────────────────────────────────────────────
	{
		title = "⚡ ENERGIA",
		mascot = "😮‍💨",
		mascotColor = C.cyan,
		dialogue = "Cada uso de habilidade gasta ENERGIA (a barra abaixo da vida).\n\nZerou, a habilidade TRAVA até regenerar. É isso que dá preço às passivas — sem energia, não existiria escolha.\n\nEnergia máxima e regeneração sobem com o NÍVEL do personagem.",
		arrow = true,
	},
	-- ── PASSO 9 ───────────────────────────────────────────────
	{
		title = "🎒 A HOTBAR",
		mascot = "🕹️",
		mascotColor = C.orange,
		dialogue = "Suas habilidades ficam na hotbar retrô, embaixo da tela.\n\nNo PC use as teclas 1-7. No celular e no console os botões se ajustam sozinhos ao seu aparelho.",
		arrow = true,
	},
	-- ── PASSO 10 ───────────────────────────────────────────────
	{
		title = "📈 NÍVEL POR PERSONAGEM",
		mascot = "🧗",
		mascotColor = C.green,
		dialogue = "O nível é DE CADA PERSONAGEM, não seu.\n\nUsar um personagem em combate dá XP a ELE. Subir de nível aumenta atributos, energia máxima, regeneração e o número de espaços de passiva.\n\nOu seja: vale a pena escolher um favorito.",
		arrow = false,
	},
	-- ── PASSO 11 ───────────────────────────────────────────────
	{
		title = "🧬 PASSIVAS",
		mascot = "🧠",
		mascotColor = C.purple,
		dialogue = "Passivas são efeitos permanentes que você encaixa nos espaços do personagem.\n\n⚠️ REGRA IMPORTANTE: com o personagem EQUIPADO fora da zona segura, você NÃO pode trocá-las. Só desequipado ou dentro do lobby.\n\nÉ o que impede trocar passiva no meio da briga.",
		arrow = true,
	},
	-- ── PASSO 12 ───────────────────────────────────────────────
	{
		title = "⚡ O DESPERTAR — COMO FUNCIONA",
		mascot = "😲",
		mascotColor = C.purple,
		dialogue = "O Despertar NÃO é um personagem separado e NÃO se equipa.\n\nEle já vem junto com o personagem normal: é uma FORMA TEMPORÁRIA que você conquista LUTANDO.\n\nRepare na barra roxa embaixo da energia — é ela que manda.",
		arrow = true,
	},
	-- ── PASSO 13 ───────────────────────────────────────────────
	{
		title = "🔥 ENCHENDO A BARRA",
		mascot = "😡",
		mascotColor = C.red,
		dialogue = "A barra sobe quando você DÁ DANO, LEVA DANO e USA HABILIDADE.\n\nBater rende mais que apanhar, e nenhum golpe sozinho enche tudo. Quem foge da briga não desperta.\n\nCheia: transformação!",
		arrow = false,
	},
	-- ── PASSO 14 ───────────────────────────────────────────────
	{
		title = "💥 A TRANSFORMAÇÃO",
		mascot = "⚡",
		mascotColor = C.gold,
		dialogue = "Ao encher, você fica 3 SEGUNDOS DESARMADO — é a transformação, e vale nos dois sentidos.\n\nDepois suas habilidades normais SOMEM e entram as DESPERTAS, por 3 minutos e meio.\n\nAcabou o tempo: outros 3 segundos e você volta ao normal.\n\nMorrer desperto CANCELA a forma e ZERA a barra.",
		arrow = true,
	},
	-- ── PASSO 15 ───────────────────────────────────────────────
	{
		title = "📖 VENDO O DESPERTAR",
		mascot = "🔎",
		mascotColor = C.cyan,
		dialogue = "Abra os detalhes do personagem e escolha a aba DESPERTAR.\n\nEle NÃO equipa nada — abre a imagem, o nome, a história, o HP e as habilidades da forma desperta. Funciona mesmo bloqueado, para você saber o que existe e o que falta.",
		arrow = true,
	},
	-- ── PASSO 16 ───────────────────────────────────────────────
	{
		title = "💰 RECOMPENSAS E MORTE",
		mascot = "😱",
		mascotColor = C.gold,
		dialogue = "Eliminar rende moedas e reputação. Derrotar NPC rende proporcional à vida dele.\n\nMas ao MORRER você derruba parte das suas moedas no chão — e qualquer um pode pegar. Quanto mais você carrega, mais arrisca.",
		arrow = false,
	},
	-- ── PASSO 17 ───────────────────────────────────────────────
	{
		title = "🏆 BOUNTY E PROCURADO",
		mascot = "😈",
		mascotColor = C.orange,
		dialogue = "Eliminar jogadores sobe seu BOUNTY.\n\nBounty alto libera personagens exclusivos — mas também te coloca na lista de PROCURADOS, visível para todo mundo. Fama tem preço.",
		arrow = true,
	},
	-- ── PASSO 18 ───────────────────────────────────────────────
	{
		title = "🎯 JORNADA DO RECRUTA",
		mascot = "🐣",
		mascotColor = C.green,
		dialogue = "Começando agora? A JORNADA DO RECRUTA te guia.\n\nSão capítulos curtos: equipar o primeiro personagem, entrar no combate, subir de nível. Cada um paga moedas e bounty na hora.\n\nEstá no menu ☰, aba RECRUTA.",
		arrow = true,
	},
	-- ── PASSO 19 ───────────────────────────────────────────────
	{
		title = "📜 MISSÕES E CONQUISTAS",
		mascot = "🗒️",
		mascotColor = C.cyan,
		dialogue = "MISSÕES são objetivos que renovam e pagam moedas.\n\nCONQUISTAS são marcos permanentes — algumas dão personagens exclusivos e emblemas de verdade.\n\nOs dois ficam no menu ☰.",
		arrow = false,
	},
	-- ── PASSO 20 ───────────────────────────────────────────────
	{
		title = "🎁 RECOMPENSAS DIÁRIAS",
		mascot = "🥳",
		mascotColor = C.gold,
		dialogue = "Entre todo dia e colete. A sequência aumenta o prêmio a cada dia seguido.\n\nSe perder um dia, dá para recuperar depois de 3 dias consecutivos. Fim de semana paga em dobro.",
		arrow = true,
	},
	-- ── PASSO 21 ───────────────────────────────────────────────
	{
		title = "👥 TIMES, DUELOS E TROCAS",
		mascot = "🤝",
		mascotColor = C.green,
		dialogue = "TIMES: aliados não se machucam entre si.\nDUELOS: desafie alguém para um 1x1 combinado.\nTROCAS: negocie personagens com outro jogador, com as duas partes confirmando.\n\nPersonagem de emblema e gamepass não é trocável.",
		arrow = true,
	},
	-- ── PASSO 22 ───────────────────────────────────────────────
	{
		title = "👹 O CHEFÃO",
		mascot = "😨",
		mascotColor = C.red,
		dialogue = "O CHEFÃO acontece em um LUGAR SEPARADO.\n\nVocê entra em grupo, e a vida dele cresce conforme o número de jogadores. Lá não existe dano entre jogadores — é todo mundo contra ele.\n\nO prêmio só sai depois de confirmado, antes de te trazer de volta.",
		arrow = true,
	},
	-- ── PASSO 23 ───────────────────────────────────────────────
	{
		title = "🎵 A MÚSICA",
		mascot = "🎧",
		mascotColor = C.purple,
		dialogue = "O player de música fica no menu ☰.\n\nDá para tocar, pausar, pular faixa, mexer no volume e ver o VISUALIZER DE GRAVE reagindo à batida.\n\nA trilha é atualizada pelos admins dentro do jogo — sem precisar derrubar o servidor.",
		arrow = false,
	},
	-- ── PASSO 24 ───────────────────────────────────────────────
	{
		title = "✅ TUTORIAL COMPLETO!",
		mascot = "🏆",
		mascotColor = C.green,
		dialogue = "PARABÉNS! Conclua para solicitar ao servidor o bônus de 100 moedas, disponível apenas na primeira conclusão.\n\nO ciclo é este:\n🛡️ Preparar → 🎭 Equipar → ⚔️ Lutar → ⚡ Despertar → 💰 Ganhar → 📈 Evoluir\n\nO menu ☰ tem tudo, e este tutorial fica lá para reler quando quiser. Boa sorte, guerreiro! 🎮",
		arrow = false,
		isLast = true,
	},
}

-- Cada capítulo tem um enquadramento; o alvo da UI é resolvido por instâncias
-- reais, nunca por uma seta fixa que promete "clique aqui" no vazio.
local SCENES = {
	{ shot = "wide", hint = "NOOB GUIA // INICIANDO TRANSMISSÃO" },
	{ shot = "lobby", hint = "ZONA SEGURA // PREPARE SEU PERSONAGEM" },
	{ target = "menu", hint = "MENU PRINCIPAL // TODOS OS SISTEMAS" },
	{ shot = "hero", hint = "PERSONAGENS // CADA UM TEM SEU ESTILO" },
	{ target = "menu", hint = "MENU > LOJA" },
	{ target = "menu", hint = "MENU > INVENTÁRIO" },
	{ shot = "hero", hint = "COMBATE // ATAQUE, DEFESA E RESISTÊNCIA" },
	{ target = "energy", hint = "ENERGIA // ABAIXO DA VIDA" },
	{ target = "hotbar", hint = "HABILIDADES // VISÍVEIS QUANDO EQUIPADAS" },
	{ shot = "hero", hint = "EVOLUÇÃO // NÍVEL INDIVIDUAL" },
	{ target = "menu", hint = "MENU > PASSIVAS" },
	{ target = "awaken", hint = "DESPERTAR // BARRA ROXA DO HUD" },
	{ target = "awaken", hint = "DESPERTAR // CARGA EM COMBATE" },
	{ shot = "hero", hint = "DESPERTAR // FORMA TEMPORÁRIA" },
	{ target = "menu", hint = "PERSONAGEM > DETALHES > DESPERTAR" },
	{ shot = "wide", hint = "RECOMPENSAS // PLANEJE SEU PRÓXIMO PASSO" },
	{ target = "menu", hint = "BOUNTY // SUA REPUTAÇÃO" },
	{ target = "menu", hint = "MENU > RECRUTA" },
	{ target = "menu", hint = "MENU > MISSÕES E CONQUISTAS" },
	{ target = "menu", hint = "MENU > DIÁRIAS" },
	{ shot = "lobby", hint = "MENU > TIMES, DUELOS E TROCAS" },
	{ target = "menu", hint = "MENU > CHEFÃO" },
	{ target = "menu", hint = "MENU > MÚSICA" },
	{ shot = "hero", hint = "TRANSMISSÃO CONCLUÍDA // SUA JORNADA COMEÇA" },
}
local TARGETS = {
	menu = { "UnifiedMenuV1", "MenuButton" },
	energy = { "RetroHealthDisplay", "HudRoot", "MainContainer", "EnergyBackground" },
	awaken = { "RetroHealthDisplay", "HudRoot", "MainContainer", "AwakenBackground" },
	hotbar = { "RetroHotbar", "HotbarContainer" },
}
local CAMERA_OWNER = "TutorialV8"
local CAMERA_BIND = "RetroVerseTutorialCamera"
local CONTROL_BIND = "RetroVerseTutorialMovement"
local state = {
	open = false, alive = true, interacted = false, generation = 0,
	step = 1, page = 1, pages = {}, typing = false, glyphs = {},
	revealed = 0, textClock = 0, elapsed = 0, scanClock = 0,
	reducedMotion = false, fastText = false, sound = true,
	mascotPosition = 1, mascotVelocity = 0, completionSent = false,
}
local ui, connections, tweens, buttonScales = {}, {}, {}, {}
local lease, viewportConnection, characterConnection = nil, nil, nil
local heartbeatConnection = nil
local layout = Presentation.layout(1280, 720)

local function track(connection)
	table.insert(connections, connection)
	return connection
end

local function motionReduced()
	return state.reducedMotion or GuiService.ReducedMotionEnabled or VRService.VREnabled
end


-- Une référence par canal; un nouveau mouvement annule son prédécesseur.
local function animate(key, object, properties, duration, style)
	local old = tweens[key]
	if old then
		old:Cancel()
		tweens[key] = nil
	end
	if motionReduced() then
		for name, value in pairs(properties) do
			object[name] = value
		end
		return nil
	end
	local tween = TweenService:Create(object,
		TweenInfo.new(duration or 0.22, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		properties)
	tweens[key] = tween
	tween:Play()
	return tween
end

local function cancelAnimations()
	for key, tween in pairs(tweens) do
		tween:Cancel()
		tweens[key] = nil
	end
end

local function make(class, parent, name, properties)
	local object = Instance.new(class)
	object.Name = name
	for key, value in pairs(properties or {}) do
		object[key] = value
	end
	object.Parent = parent
	return object
end

local function frame(parent, name, size, position, color)
	return make("Frame", parent, name, {
		Size = size, Position = position or UDim2.fromScale(0, 0),
		BackgroundColor3 = color or C.panel, BorderSizePixel = 0,
	})
end

local function text(parent, name, value, size, position, maxSize)
	local label = make("TextLabel", parent, name, {
		Size = size, Position = position, BackgroundTransparency = 1,
		Text = value, TextColor3 = C.white, Font = Enum.Font.Code,
		TextScaled = true, TextWrapped = true,
	})
	make("UITextSizeConstraint", label, "Legibility", { MinTextSize = 10, MaxTextSize = maxSize or 24 })
	return label
end

local function border(object, color, thickness)
	return make("UIStroke", object, "RetroBorder", {
		Color = color, Thickness = thickness or 2, Transparency = 0.15,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

local function square(object)
	make("UIAspectRatioConstraint", object, "Square", {
		AspectRatio = 1, DominantAxis = Enum.DominantAxis.Height,
	})
end

local function button(parent, name, label, width, color)
	local object = make("TextButton", parent, name, {
		Size = UDim2.fromScale(width, 1), BackgroundColor3 = color or C.panel,
		BorderSizePixel = 0, AutoButtonColor = false, Text = label,
		TextColor3 = C.white, TextScaled = true, Font = Enum.Font.Code,
		Selectable = true,
	})
	make("UITextSizeConstraint", object, "Legibility", { MinTextSize = 10, MaxTextSize = 21 })
	border(object, C.cyan, 1)
	local scale = make("UIScale", object, "PressSpring", { Scale = 1 })
	local motion = { scale = scale, x = 1, v = 0, target = 1 }
	table.insert(buttonScales, motion)
	local function press(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
			or input.KeyCode == Enum.KeyCode.ButtonA then
			motion.target = 0.94
			if motionReduced() then scale.Scale = 0.97 end
		end
	end
	track(object.InputBegan:Connect(press))
	track(object.InputEnded:Connect(function()
		motion.target = 1
		if motionReduced() then scale.Scale = 1 end
	end))
	track(object.MouseEnter:Connect(function() motion.target = 1.025 end))
	track(object.MouseLeave:Connect(function() motion.target = 1 end))
	track(object.SelectionGained:Connect(function() motion.target = 1.025 end))
	track(object.SelectionLost:Connect(function() motion.target = 1 end))
	return object
end

-- Sons reutilizados: digitar não cria um Sound por letra. Falha no asset é inofensiva.
local clickSound = make("Sound", SoundService, "TutorialClickV8", {
	SoundId = "rbxassetid://156785206", Volume = 0.18,
})
local typeSound = make("Sound", SoundService, "TutorialVoiceV8", {
	SoundId = "rbxassetid://9118416910", Volume = 0.08, PlaybackSpeed = 1.25,
})
local function click()
	if state.sound then clickSound:Play() end
end

local previousGui = playerGui:FindFirstChild("TutorialMenuV4")
if previousGui then previousGui.Parent = nil end
ui.gui = make("ScreenGui", playerGui, "TutorialMenuV4", {
	ResetOnSpawn = false, IgnoreGuiInset = false, Enabled = false,
	DisplayOrder = 205, ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
})
ui.root = frame(ui.gui, "SafeRoot", UDim2.fromScale(1, 1))
ui.root.BackgroundTransparency = 1
ui.shade = frame(ui.root, "ScreenShade", UDim2.fromScale(1, 1), nil, C.bg)
ui.shade.BackgroundTransparency = 1
ui.topBar = frame(ui.root, "CinemaTop", UDim2.fromScale(1, 0), nil, C.bg)
ui.bottomBar = frame(ui.root, "CinemaBottom", UDim2.fromScale(1, 0), UDim2.fromScale(0, 1), C.bg)
ui.bottomBar.AnchorPoint = Vector2.new(0, 1)
ui.caption = text(ui.root, "SceneCaption", "", UDim2.fromScale(0.72, 0.055), UDim2.fromScale(0.14, 0.11), 19)
ui.caption.TextColor3 = C.cyan
ui.caption.TextTransparency = 1

ui.target = frame(ui.root, "LiveTarget", UDim2.fromScale(0, 0))
ui.target.BackgroundTransparency = 1
ui.target.Visible = false
ui.targetBorder = border(ui.target, C.gold, 3)

ui.panel = frame(ui.root, "DialogFrame", UDim2.fromScale(0.9, 0.4), UDim2.fromScale(0.5, 1.6), C.bg)
ui.panel.AnchorPoint = Vector2.new(0.5, 1)
ui.panel.Active = true
ui.panel.ZIndex = 5
ui.panelBorder = border(ui.panel, C.cyan)
ui.panelScale = make("UIScale", ui.panel, "EntranceScale", { Scale = 0.96 })
ui.accent = frame(ui.panel, "ChapterAccent", UDim2.fromScale(1, 0.015), nil, C.cyan)

ui.header = frame(ui.panel, "Header", UDim2.fromScale(0.96, 0.18), UDim2.fromScale(0.02, 0.03))
ui.header.BackgroundTransparency = 1
ui.speaker = text(ui.header, "Speaker", "NOOB GUIA", UDim2.fromScale(0.59, 0.48), UDim2.fromScale(0, 0), 22)
ui.speaker.Font = Enum.Font.Arcade
ui.speaker.TextColor3 = C.cyan
ui.speaker.TextXAlignment = Enum.TextXAlignment.Left
ui.title = text(ui.header, "StepTitle", "", UDim2.fromScale(0.72, 0.46), UDim2.fromScale(0, 0.52), 18)
ui.title.TextXAlignment = Enum.TextXAlignment.Left
ui.counter = text(ui.header, "StepCounter", "", UDim2.fromScale(0.15, 0.48), UDim2.fromScale(0.72, 0), 19)
ui.close = button(ui.header, "Close", "X", 0.07, C.red)
ui.close.AnchorPoint = Vector2.new(1, 0)
ui.close.Position = UDim2.fromScale(1, 0)
square(ui.close)

ui.body = frame(ui.panel, "DialogueBody", UDim2.fromScale(0.96, 0.43), UDim2.fromScale(0.02, 0.235))
border(ui.body, Color3.fromRGB(55, 65, 85), 1)
ui.mascot = frame(ui.body, "PixelNoob", UDim2.fromScale(0.15, 0.74), UDim2.fromScale(0.095, 0.5), C.bg)
ui.mascot.AnchorPoint = Vector2.new(0.5, 0.5)
square(ui.mascot)
ui.mascotScale = make("UIScale", ui.mascot, "SpeechSpring", { Scale = 1 })
border(ui.mascot, C.gold, 1)
ui.face = frame(ui.mascot, "Face", UDim2.fromScale(0.76, 0.76), UDim2.fromScale(0.12, 0.12), C.gold)
ui.eyeL = frame(ui.face, "EyeLeft", UDim2.fromScale(0.12, 0.18), UDim2.fromScale(0.22, 0.24), C.bg)
ui.eyeR = frame(ui.face, "EyeRight", UDim2.fromScale(0.12, 0.18), UDim2.fromScale(0.66, 0.24), C.bg)
ui.mouth = frame(ui.face, "Mouth", UDim2.fromScale(0.40, 0.07), UDim2.fromScale(0.3, 0.65), C.bg)
ui.dialogue = make("TextButton", ui.body, "DialogText", {
	Size = UDim2.fromScale(0.77, 0.86), Position = UDim2.fromScale(0.21, 0.07),
	BackgroundTransparency = 1, AutoButtonColor = false, Text = "",
	TextColor3 = C.white, Font = Enum.Font.Code, TextScaled = true, TextWrapped = true,
	TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Center,
	MaxVisibleGraphemes = -1, Selectable = false,
})
make("UITextSizeConstraint", ui.dialogue, "Legibility", { MinTextSize = 12, MaxTextSize = 25 })

ui.hint = text(ui.panel, "ReadingHint", "", UDim2.fromScale(0.96, 0.07), UDim2.fromScale(0.02, 0.68), 15)
ui.hint.TextColor3 = C.dimText
ui.nav = frame(ui.panel, "Navigation", UDim2.fromScale(0.96, 0.18), UDim2.fromScale(0.02, 0.77))
ui.nav.BackgroundTransparency = 1
make("UIListLayout", ui.nav, "Buttons", {
	FillDirection = Enum.FillDirection.Horizontal, SortOrder = Enum.SortOrder.LayoutOrder,
	VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0.025, 0),
})
ui.prev = button(ui.nav, "Previous", "< VOLTAR", 0.23)
ui.next = button(ui.nav, "Next", "LER TUDO >", 0.44, Color3.fromRGB(0, 93, 117))
ui.skip = button(ui.nav, "Skip", "PULAR", 0.28)
ui.prev.LayoutOrder, ui.next.LayoutOrder, ui.skip.LayoutOrder = 1, 2, 3

ui.progressBG = frame(ui.panel, "ProgressTrack", UDim2.fromScale(1, 0.015), UDim2.fromScale(0, 0.985), C.panel)
ui.progress = frame(ui.progressBG, "ProgressFill", UDim2.fromScale(0, 1), nil, C.cyan)
ui.wipe = frame(ui.panel, "ChapterSweep", UDim2.fromScale(0.2, 0.015), nil, C.white)
ui.wipe.BackgroundTransparency = 1

ui.options = frame(ui.root, "Options", UDim2.fromScale(0.55, 0.06), UDim2.fromScale(0.98, 0.025))
ui.options.AnchorPoint = Vector2.new(1, 0)
ui.options.BackgroundTransparency = 1
ui.options.ZIndex = 6
make("UIListLayout", ui.options, "Buttons", {
	FillDirection = Enum.FillDirection.Horizontal, SortOrder = Enum.SortOrder.LayoutOrder,
	Padding = UDim.new(0.02, 0),
})
ui.motion = button(ui.options, "Motion", "CÂMERA: ON", 0.38)
ui.speed = button(ui.options, "TextSpeed", "TEXTO: NORMAL", 0.36)
ui.sound = button(ui.options, "Voice", "SOM: ON", 0.22)
ui.motion.LayoutOrder, ui.speed.LayoutOrder, ui.sound.LayoutOrder = 1, 2, 3

local function livingCharacter()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if humanoid and root and humanoid.Health > 0 then
		return character, humanoid, root
	end
	return nil
end
-- (V8.1) POR QUE A CÂMERA NÃO ASSUMIU.
--
-- O V8 chamava startCamera() uma vez só, ao abrir, e a guarda exige a tag
-- `InSafeZone` — que quem põe no personagem é o SERVIDOR, pelo SpawnSystem.
-- Se o tutorial abrisse antes de a tag chegar, ou com o jogador fora do
-- lobby, a câmera era recusada e NUNCA mais tentava: ficava livre a sessão
-- inteira, sem uma palavra explicando. E o botão parecia morto, porque
-- apertá-lo só chamava a mesma startCamera() que recusava de novo.
--
-- Agora a recusa tem nome, e o nome vai para o botão.
local function cameraBlockReason()
	if motionReduced() then
		return VRService.VREnabled and "vr"
			or (GuiService.ReducedMotionEnabled and "sistema" or "desligado")
	end
	if not state.open then
		return "fechado"
	end
	local character = livingCharacter()
	if not character then
		return "sem personagem"
	end
	if not character:FindFirstChild("InSafeZone") then
		return "fora da base"
	end
	local camera = workspace.CurrentCamera
	if not camera then
		return "sem camera"
	end
	if camera:GetAttribute("RetroVerseCameraOwner") ~= nil then
		return "outro sistema"
	end
	if camera.CameraType == Enum.CameraType.Scriptable then
		return "camera ocupada"
	end
	return nil
end

local function releaseCamera(restore)
	local old = lease
	lease = nil
	RunService:UnbindFromRenderStep(CAMERA_BIND)
	ContextActionService:UnbindAction(CONTROL_BIND)
	if not old then return end
	local camera = old.camera
	-- Só restauramos o que ainda é nosso. Outro sistema pode ter iniciado uma cutscene.
	if camera.Parent and camera:GetAttribute("RetroVerseCameraOwner") == CAMERA_OWNER then
		camera:SetAttribute("RetroVerseCameraOwner", nil)
		if restore and camera.CameraType == Enum.CameraType.Scriptable then
			camera.FieldOfView = old.fov
			if old.subject and old.subject.Parent then
				camera.CameraSubject = old.subject
			end
			camera.CFrame = old.cframe
			camera.Focus = old.focus
			camera.CameraType = old.kind
		end
	end
end

local function findTarget()
	local path = TARGETS[(SCENES[state.step] or {}).target]
	if not path then return nil end
	local target = playerGui
	for _, name in ipairs(path) do
		target = target:FindFirstChild(name)
		if not target then return nil end
	end
	local ancestor = target
	while ancestor and ancestor ~= playerGui do
		if ancestor:IsA("GuiObject") and not ancestor.Visible then return nil end
		if ancestor:IsA("ScreenGui") and not ancestor.Enabled then return nil end
		ancestor = ancestor.Parent
	end
	return target:IsA("GuiObject") and target or nil
end

local function updateHighlight()
	local target = findTarget()
	if not target or ui.root.AbsoluteSize.X < 1 or ui.root.AbsoluteSize.Y < 1 then
		ui.target.Visible = false
		return
	end
	local size, position = target.AbsoluteSize, target.AbsolutePosition - ui.root.AbsolutePosition
	local viewport = ui.root.AbsoluteSize
	local panelTop = ui.panel.AbsolutePosition.Y - ui.root.AbsolutePosition.Y
	local panelBottom = panelTop + ui.panel.AbsoluteSize.Y
	if size.X < 1 or size.Y < 1 or position.Y < 0
		or position.Y + size.Y > viewport.Y
		or (position.Y < panelBottom and position.Y + size.Y > panelTop) then
		ui.target.Visible = false
		return
	end
	ui.target.Position = UDim2.fromScale(position.X / viewport.X, position.Y / viewport.Y)
	ui.target.Size = UDim2.fromScale(size.X / viewport.X, size.Y / viewport.Y)
	ui.target.Visible = true
end

local function startCamera()
	if lease then return end
	local camera = workspace.CurrentCamera
	local character, humanoid, root = livingCharacter()
	if not Presentation.canTakeCamera({
		open = state.open, alive = character ~= nil,
		safe = character ~= nil and character:FindFirstChild("InSafeZone") ~= nil,
		cameraAvailable = camera ~= nil,
		foreignOwner = camera and camera:GetAttribute("RetroVerseCameraOwner") ~= nil,
		scriptable = camera and camera.CameraType == Enum.CameraType.Scriptable,
		reducedMotion = motionReduced(), vr = VRService.VREnabled,
	}) then return end
	local saved = {
		camera = camera, kind = camera.CameraType, subject = camera.CameraSubject,
		cframe = camera.CFrame, focus = camera.Focus, fov = camera.FieldOfView,
		character = character, root = root, heading = root.CFrame - root.Position,
		lastHealth = humanoid.Health, elapsed = 0, rootStart = root.Position, angle = 0.35,
	}
	lease = saved
	camera:SetAttribute("RetroVerseCameraOwner", CAMERA_OWNER)
	camera.CameraType = Enum.CameraType.Scriptable
	-- Bloqueia só as ações de movimento deste tutorial; não altera WalkSpeed,
	-- Anchored ou PlayerModule e não dá proteção fora do servidor.
	ContextActionService:BindActionAtPriority(CONTROL_BIND, function()
		return Enum.ContextActionResult.Sink
	end, false, Enum.ContextActionPriority.High.Value,
		Enum.PlayerActions.CharacterForward, Enum.PlayerActions.CharacterBackward,
		Enum.PlayerActions.CharacterLeft, Enum.PlayerActions.CharacterRight, Enum.PlayerActions.CharacterJump)
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = { character }
	rayParams.RespectCanCollide = true
	local function collisionSafe(focus, wanted)
		local delta = wanted - focus
		if delta.Magnitude < 0.01 then return wanted end
		local hit = workspace:Raycast(focus, delta, rayParams)
		return hit and hit.Position + hit.Normal * 1.2 or wanted
	end
	RunService:BindToRenderStep(CAMERA_BIND, Enum.RenderPriority.Camera.Value + 1, function(dt)
		if not state.open or not state.alive or not ui.gui.Parent
			or workspace.CurrentCamera ~= camera or not root.Parent
			or not character:FindFirstChild("InSafeZone") or humanoid.Health <= 0
			or motionReduced() then
			releaseCamera(true)
			return
		end
		if camera:GetAttribute("RetroVerseCameraOwner") ~= CAMERA_OWNER
			or camera.CameraType ~= Enum.CameraType.Scriptable
			or camera.CameraSubject ~= saved.subject then
			releaseCamera(false)
			return
		end
		-- Ataque/teleporte interrompe a câmera; não manter uma cutscene no combate.
		if humanoid.Health < saved.lastHealth or (root.Position - saved.rootStart).Magnitude > 30 then
			releaseCamera(true)
			return
		end
		saved.lastHealth = humanoid.Health
		saved.elapsed = saved.elapsed + math.min(dt, 0.1)
		local shot = (SCENES[state.step] or {}).shot or "wide"
		local focus = root.Position + Vector3.new(0, 1.5, 0)
		local distance, elevation, fov = 15, 6, 64
		if shot == "hero" then
			distance, elevation, fov = 11, 3, 58
		elseif shot == "lobby" then
			local lobby = workspace:FindFirstChild("LobbyStructure")
			local center = lobby and lobby:GetAttribute("SafeZoneCenter")
			if typeof(center) == "Vector3" and (center - root.Position).Magnitude < 96 then
				focus = center + Vector3.new(0, 5, 0)
			end
			distance, elevation, fov = 38, 21, 68
		end
		local targetAngle = (shot == "hero" and 2.7 or 0.35) + math.sin(saved.elapsed * 0.22) * 0.09
		saved.angle = saved.angle + (targetAngle - saved.angle) * (1 - math.exp(-2 * math.min(dt, 0.1)))
		local angle = saved.angle
		local offset = saved.heading:VectorToWorldSpace(Vector3.new(math.sin(angle) * distance, elevation, math.cos(angle) * distance))
		local wanted = collisionSafe(focus, focus + offset)
		local alpha = 1 - math.exp(-3.5 * math.min(dt, 0.1))
		local blended = camera.CFrame.Position:Lerp(wanted, alpha)
		blended = collisionSafe(focus, blended)
		if (blended - focus).Magnitude > 0.1 then
			local destination = CFrame.lookAt(blended, focus)
			-- Recalcula a posição depois do Lerp: a câmera também respeita paredes na transição.
			local rotated = camera.CFrame:Lerp(destination, alpha)
			camera.CFrame = CFrame.new(blended) * (rotated - rotated.Position)
		end
		camera.Focus = CFrame.new(focus)
		camera.FieldOfView = camera.FieldOfView + (fov - camera.FieldOfView) * alpha
	end)
end

local function panelPosition()
	-- A hotbar fica livre durante sua explicação.
	return UDim2.fromScale(0.5, state.step == 9 and math.min(0.74, 0.18 + layout.height) or layout.bottom)
end

local function updateLayout()
	local camera = workspace.CurrentCamera
	local size = camera and camera.ViewportSize or Vector2.new(1280, 720)
	layout = Presentation.layout(size.X, size.Y)
	ui.panel.Size = UDim2.fromScale(layout.width, layout.height)
	if state.open then animate("panelPosition", ui.panel, { Position = panelPosition() }, 0.25) end
	ui.mascot.Visible = not layout.portrait
	ui.dialogue.Size = UDim2.fromScale(layout.portrait and 0.94 or 0.77, 0.86)
	ui.dialogue.Position = UDim2.fromScale(layout.portrait and 0.03 or 0.21, 0.07)
	ui.options.Size = UDim2.fromScale(layout.portrait and 0.94 or 0.59, math.clamp(44 / math.max(1, size.Y), 0.045, 0.13))
	updateHighlight()
end

local function updateNavigation()
	local lastPage = state.page == #state.pages
	ui.counter.Text = string.format("%02d / %02d", state.step, #STEPS)
	ui.hint.Text = string.format("%d/%d • %s", state.page, #state.pages,
		state.typing and "Toque no texto para revelar tudo" or "Toque no texto ou em AVANÇAR")
	ui.next.Text = state.typing and "LER TUDO >"
		or (not lastPage and "CONTINUAR >" or (STEPS[state.step].isLast and "CONCLUIR" or "AVANÇAR >"))
	ui.prev.TextTransparency = (state.step == 1 and state.page == 1) and 0.55 or 0
	ui.prev.Selectable = state.step > 1 or state.page > 1
	ui.skip.Text = STEPS[state.step].isLast and "FECHAR" or "PULAR"
	-- (V8.1) "CÂMERA: LIVRE" não dizia nada: o jogador via o mesmo texto
	-- estando fora da base, sem personagem ou com a câmera tomada por
	-- outro sistema. Agora o botão mostra o motivo real da recusa.
	if motionReduced() then
		ui.motion.Text = "MOV.: OFF"
	elseif lease then
		ui.motion.Text = "CÂMERA: ON"
	else
		local motivo = cameraBlockReason()
		ui.motion.Text = motivo and ("CÂMERA: " .. string.upper(motivo)) or "CÂMERA: LIVRE"
	end
end

local function revealAll()
	state.typing = false
	state.revealed = #state.glyphs
	ui.dialogue.MaxVisibleGraphemes = -1
	typeSound:Stop()
	updateNavigation()
end

local function showPage()
	state.generation = state.generation + 1
	state.glyphs = {}
	state.revealed, state.textClock = 0, 0
	local pageText = state.pages[state.page] or ""
	-- Text fica completo desde o começo, mantendo layout/tamanho constantes.
	-- utf8.graphemes também preserva emojis unidos por ZWJ e acentos combinados.
	for first, last in utf8.graphemes(pageText) do
		table.insert(state.glyphs, pageText:sub(first, last))
	end
	ui.dialogue.Text = pageText
	ui.dialogue.MaxVisibleGraphemes = 0
	state.typing = #state.glyphs > 0
	state.mascotVelocity = 1.1
	ui.dialogue.TextTransparency = motionReduced() and 0 or 0.4
	animate("dialogueFade", ui.dialogue, { TextTransparency = 0 }, 0.24)
	if motionReduced() then revealAll() end
	updateNavigation()
end

local function showStep(index)
	state.step = math.clamp(index, 1, #STEPS)
	state.page = 1
	-- Limite fixado na abertura: girar o aparelho não reinicia nem perde a página.
	state.pages = Presentation.pages(STEPS[state.step].dialogue, state.pageLimit or 140)
	local step = STEPS[state.step]
	ui.title.Text = step.title
	ui.caption.Text = SCENES[state.step].hint
	ui.speaker.TextColor3 = step.mascotColor
	animate("accent", ui.accent, { BackgroundColor3 = step.mascotColor }, 0.3)
	animate("border", ui.panelBorder, { Color = step.mascotColor }, 0.3)
	animate("progress", ui.progress, {
		Size = UDim2.fromScale((state.step - 1) / (#STEPS - 1), 1),
		BackgroundColor3 = step.mascotColor,
	}, 0.35)
	animate("panelPosition", ui.panel, { Position = panelPosition() }, 0.3)
	ui.wipe.Position = UDim2.fromScale(0, 0)
	ui.wipe.BackgroundTransparency = motionReduced() and 1 or 0.15
	animate("chapterSweep", ui.wipe, { Position = UDim2.fromScale(0.8, 0), BackgroundTransparency = 1 }, 0.6, Enum.EasingStyle.Sine)
	showPage()
	updateHighlight()
end

local closeTutorial
local function runAnimation(dt)
	if not state.alive or not ui.gui.Parent then return end
	state.elapsed = state.elapsed + dt

	-- (V8.1) RETENTATIVA. O V8 tentava tomar a câmera uma vez só, no
	-- instante da abertura. A guarda exige a tag `InSafeZone`, que quem
	-- põe é o servidor: abrir o tutorial um segundo cedo demais, ou de
	-- fora do lobby, recusava para sempre. Aqui ele tenta de novo, de
	-- meio em meio segundo, enquanto o tutorial estiver aberto e a
	-- câmera livre — então assim que o jogador entra na base a cena
	-- assume sozinha, sem precisar fechar e reabrir.
	if not lease then
		-- Sem cena em andamento, o bloqueio de movimento não pode existir.
		-- É barato reafirmar isso todo quadro, e fecha de vez a classe de
		-- bug em que o jogador fica preso porque o desbind se perdeu num
		-- caminho de saída que ninguém previu — travar o personagem é o
		-- pior estrago que este script consegue fazer.
		ContextActionService:UnbindAction(CONTROL_BIND)

		if state.open then
			state.cameraRetry = (state.cameraRetry or 0) + dt
			if state.cameraRetry >= 0.5 then
				state.cameraRetry = 0
				startCamera()
				updateNavigation()
			end
		end
	end
	if state.typing then
		state.textClock = state.textClock + dt
		local emitted = 0
		while state.revealed < #state.glyphs and emitted < 12 do
			local delay = Presentation.characterDelay(state.glyphs[state.revealed + 1], state.fastText)
			if state.textClock < delay then break end
			state.textClock = state.textClock - delay
			state.revealed = state.revealed + 1
			emitted = emitted + 1
		end
		ui.dialogue.MaxVisibleGraphemes = state.revealed
		if state.sound and emitted > 0 and state.elapsed - (state.lastVoice or 0) > 0.085 then
			state.lastVoice = state.elapsed
			typeSound:Play()
		end
		if state.revealed >= #state.glyphs then revealAll() end
	end
	if not motionReduced() then
		local target = state.typing and (1.02 + math.sin(state.elapsed * 10) * 0.015) or 1
		state.mascotPosition, state.mascotVelocity = Presentation.spring(state.mascotPosition, state.mascotVelocity, target, 16, dt)
		ui.mascotScale.Scale = state.mascotPosition
		ui.mascot.Rotation = math.sin(state.elapsed * 1.5) * 1.3
		ui.mouth.Size = UDim2.fromScale(0.4, state.typing and (0.08 + math.abs(math.sin(state.elapsed * 16)) * 0.16) or 0.07)
		local blink = state.elapsed % 4.7 > 4.56
		ui.eyeL.Size = UDim2.fromScale(0.12, blink and 0.035 or 0.18)
		ui.eyeR.Size = ui.eyeL.Size
		ui.targetBorder.Transparency = 0.12 + (math.sin(state.elapsed * 3) + 1) * 0.12
		for _, motion in ipairs(buttonScales) do
			motion.x, motion.v = Presentation.spring(motion.x, motion.v, motion.target, 24, dt)
			motion.scale.Scale = motion.x
		end
	end
	state.scanClock = state.scanClock + dt
	if state.scanClock >= 0.25 then
		state.scanClock = 0
		updateHighlight()
		updateNavigation()
	end
end

local function openTutorial()
	state.interacted = true
	if not state.alive or state.open then return end
	state.generation = state.generation + 1
	state.open = true
	state.completionSent = false
	ui.gui.Enabled = true
	ui.panel.Position = UDim2.fromScale(0.5, 1.6)
	ui.panelScale.Scale = 0.96
	updateLayout()
	-- Páginas conservadoras também para quem girar para uma tela estreita depois.
	state.pageLimit = math.min(layout.pageLimit, 140)
	showStep(1)
	startCamera()
	updateNavigation()
	animate("panelPosition", ui.panel, { Position = panelPosition() }, 0.45, Enum.EasingStyle.Back)
	animate("panelScale", ui.panelScale, { Scale = 1 }, 0.38, Enum.EasingStyle.Back)
	animate("shade", ui.shade, { BackgroundTransparency = 0.88 }, 0.3, Enum.EasingStyle.Sine)
	animate("caption", ui.caption, { TextTransparency = 0 }, 0.35)
	animate("topBar", ui.topBar, { Size = UDim2.fromScale(1, 0.018) }, 0.35)
	animate("bottomBar", ui.bottomBar, { Size = UDim2.fromScale(1, 0.018) }, 0.35)
	if heartbeatConnection then heartbeatConnection:Disconnect() end
	heartbeatConnection = RunService.Heartbeat:Connect(runAnimation)
	if UserInputService.GamepadEnabled then
		state.previousSelection = GuiService.SelectedObject
		GuiService.SelectedObject = ui.next
	end
	click()
end

closeTutorial = function(immediate)
	if not state.open then return end
	state.open = false
	state.generation = state.generation + 1
	local generation = state.generation
	state.typing = false
	typeSound:Stop()
	if heartbeatConnection then heartbeatConnection:Disconnect(); heartbeatConnection = nil end
	releaseCamera(true)
	ui.target.Visible = false
	if GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(ui.gui) then
		local previous = state.previousSelection
		GuiService.SelectedObject = previous and previous.Parent and previous or nil
	end
	cancelAnimations()
	if immediate or motionReduced() then
		ui.gui.Enabled = false
		return
	end
	animate("panelPosition", ui.panel, { Position = UDim2.fromScale(0.5, 1.6) }, 0.26)
	animate("shade", ui.shade, { BackgroundTransparency = 1 }, 0.26)
	animate("caption", ui.caption, { TextTransparency = 1 }, 0.2)
	animate("topBar", ui.topBar, { Size = UDim2.fromScale(1, 0) }, 0.25)
	animate("bottomBar", ui.bottomBar, { Size = UDim2.fromScale(1, 0) }, 0.25)
	task.delay(0.28, function()
		if state.alive and not state.open and state.generation == generation then
			ui.gui.Enabled = false
			cancelAnimations()
		end
	end)
end

local function complete()
	if not state.open or state.completionSent then return end
	state.completionSent = true
	-- A UI não concede moedas nem presume que ganhou ao reler.
	completeTutorial:FireServer()
	closeTutorial()
end

local function nextPage()
	if not state.open then return end
	click()
	if state.typing then
		revealAll()
	elseif state.page < #state.pages then
		state.page = state.page + 1
		showPage()
	elseif STEPS[state.step].isLast then
		complete()
	else
		showStep(state.step + 1)
	end
end

track(ui.dialogue.Activated:Connect(nextPage))
track(ui.next.Activated:Connect(nextPage))
track(ui.prev.Activated:Connect(function()
	if not state.open then return end
	click()
	if state.page > 1 then
		state.page = state.page - 1
		showPage()
	elseif state.step > 1 then
		showStep(state.step - 1)
	end
end))
track(ui.close.Activated:Connect(function() click(); closeTutorial() end))
track(ui.skip.Activated:Connect(function()
	click()
	if STEPS[state.step].isLast then closeTutorial() else complete() end
end))
local function applyMotionPreference()
	if motionReduced() then
		releaseCamera(true)
		cancelAnimations()
		ui.mascotScale.Scale, ui.mascot.Rotation = 1, 0
		ui.mouth.Size = UDim2.fromScale(0.4, 0.07)
		ui.wipe.BackgroundTransparency = 1
		for _, motion in ipairs(buttonScales) do motion.scale.Scale = 1 end
		if state.open then
			ui.panel.Position = panelPosition()
			ui.panelScale.Scale = 1
			ui.dialogue.TextTransparency = 0
			revealAll()
		end
	elseif state.open then
		startCamera()
	end
	updateNavigation()
end
track(ui.motion.Activated:Connect(function()
	state.reducedMotion = not state.reducedMotion
	applyMotionPreference()
end))
track(GuiService:GetPropertyChangedSignal("ReducedMotionEnabled"):Connect(applyMotionPreference))
track(VRService:GetPropertyChangedSignal("VREnabled"):Connect(applyMotionPreference))
track(ui.speed.Activated:Connect(function()
	state.fastText = not state.fastText
	ui.speed.Text = state.fastText and "TEXTO: RÁPIDO" or "TEXTO: NORMAL"
end))
track(ui.sound.Activated:Connect(function()
	state.sound = not state.sound
	ui.sound.Text = state.sound and "SOM: ON" or "SOM: OFF"
	if not state.sound then typeSound:Stop(); clickSound:Stop() end
end))

local function bindViewport()
	if viewportConnection then viewportConnection:Disconnect() end
	releaseCamera(true)
	local camera = workspace.CurrentCamera
	viewportConnection = camera and camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateLayout) or nil
	updateLayout()
	-- Uma câmera recém-substituída pode pertencer a outra cutscene. Não tomar posse automaticamente.
end
track(workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(bindViewport))
local function bindCharacter(character)
	if characterConnection then characterConnection:Disconnect() end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		characterConnection = humanoid.Died:Connect(function() closeTutorial(true) end)
	end
end
track(player.CharacterRemoving:Connect(function() closeTutorial(true) end))
track(player.CharacterAdded:Connect(function(character)
	closeTutorial(true)
	bindCharacter(character)
end))
track(GuiService.MenuOpened:Connect(function() closeTutorial(true) end))
if player.Character then bindCharacter(player.Character) end
bindViewport()

_G.OpenTutorialMenu = openTutorial
_G.CloseTutorialMenu = closeTutorial

local function cleanup()
	if not state.alive then return end
	closeTutorial(true)
	state.alive = false
	releaseCamera(true)
	cancelAnimations()
	if heartbeatConnection then heartbeatConnection:Disconnect() end
	if viewportConnection then viewportConnection:Disconnect() end
	if characterConnection then characterConnection:Disconnect() end
	for _, connection in ipairs(connections) do connection:Disconnect() end
	table.clear(connections)
	clickSound:Stop()
	typeSound:Stop()
	clickSound.Parent, typeSound.Parent = nil, nil
	if _G.OpenTutorialMenu == openTutorial then _G.OpenTutorialMenu = nil end
	if _G.CloseTutorialMenu == closeTutorial then _G.CloseTutorialMenu = nil end
	ui.gui.Parent = nil
end
track(ui.gui.AncestryChanged:Connect(function()
	if not ui.gui:IsDescendantOf(playerGui) then cleanup() end
end))
track(ui.gui:GetPropertyChangedSignal("Enabled"):Connect(function()
	if state.open and not ui.gui.Enabled then closeTutorial(true) end
end))
track(script.AncestryChanged:Connect(function()
	if not script:IsDescendantOf(game) then cleanup() end
end))

task.spawn(function()
	local deadline = os.clock() + 30
	while state.alive and not _G.RegisterMenuCategory and os.clock() < deadline do task.wait(0.25) end
	if state.alive and _G.RegisterMenuCategory then
		_G.RegisterMenuCategory("TUTORIAL", "❓", openTutorial, closeTutorial, 8)
	end
end)

task.spawn(function()
	local ok, progress = pcall(function() return getTutorialProgress:InvokeServer() end)
	if not ok or type(progress) ~= "table" then
		warn("[TUTORIAL V8] Progresso indisponível; o tutorial continua acessível pelo menu.")
		return
	end
	if not progress.shouldAutoShow then return end
	-- Espera o carregamento REAL; não cobre a LoadingScreen nem rouba a câmera dela.
	local deadline = os.clock() + 90
	while state.alive and not state.interacted and os.clock() < deadline do
		local loading = playerGui:FindFirstChild("LoadingScreen")
		local character = livingCharacter()
		local menu = playerGui:FindFirstChild("UnifiedMenuV1")
		local hub = menu and menu:FindFirstChild("HubFrame")
		local loadingDone = game:IsLoaded() and (not loading or not loading.Enabled)
		if loadingDone and character and character:FindFirstChild("InSafeZone")
			and not GuiService.MenuIsOpen and not (hub and hub.Visible) then
			openTutorial()
			return
		end
		task.wait(0.3)
	end
end)

print("[TUTORIAL V8] Câmera dinâmica + diálogo por grafemas + 24 etapas. Use o menu TUTORIAL.")
