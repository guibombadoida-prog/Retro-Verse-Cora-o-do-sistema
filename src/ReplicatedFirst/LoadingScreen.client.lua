-- ============================================
-- TELA DE CARREGAMENTO RETRO ARCADE V3 (CLIENT)
-- ReplicatedFirst > LoadingScreen (LocalScript)
-- Nome: "LoadingScreen"
-- SUBSTITUI: LoadingScreen V2
-- ============================================
-- (V3) DUAS MUDANÇAS:
--
-- 1. ESPERA OS ASSETS DE VERDADE. O V2 saía quando game:IsLoaded()
--    ficava true, mas isso só diz que o DataModel replicou — não que
--    textura, som e malha terminaram de baixar. O jogador entrava e via
--    o mapa cinza se montando na frente dele. Agora a tela chama
--    ContentProvider:PreloadAsync sobre o conteúdo real do jogo, em
--    lotes, e a barra passa a mostrar quanto já baixou de fato.
--
-- 2. BOTÃO DE PULAR. Preload honesto custa tempo, e em rede ruim pode
--    custar muito. O botão aparece depois de alguns segundos e deixa o
--    jogador entrar quando quiser, sem esperar o download acabar.
--    Aparece por BOTÃO, nunca por tecla — regra de GUI do projeto.
-- ============================================
-- (V2) ALTERAÇÕES — ESTILO RETRO TOTAL:
-- • Grid synthwave no horizonte (linhas + raios em perspectiva)
-- • Scanlines densas + vinheta + flicker de CRT
-- • Título com aberração cromática (ghost ciano/magenta) e
--   glitch DETERMINÍSTICO em ciclos fixos (sem Randomize)
-- • Barra de progresso PIXELADA em 20 blocos segmentados
-- • Status com efeito TYPEWRITER + cursor "_" piscando
-- • Dicas do jogo em rotação SEQUENCIAL
-- • Rodapé "INSERT COIN" piscando estilo fliperama
-- • Limpeza final sem :Destroy() (desconecta conexões e
--   usa gui.Parent = nil — conformidade do projeto)
-- REUTILIZADO da LoadingScreen V1: handshake server+client
-- (LoadingStage/LoadingReady/QueryLoadingReady), tempo mínimo,
-- suavização da barra e fade de saída.
-- REUTILIZADO do HealthDisplay V2: paleta neon retro.
-- ============================================

local ReplicatedFirst = game:GetService("ReplicatedFirst")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ContentProvider = game:GetService("ContentProvider")

print("[LOADING V3] script iniciado")

pcall(function()
	ReplicatedFirst:RemoveDefaultLoadingScreen()
end)

local MIN_DISPLAY = 4 -- segundos mínimos visíveis
local SEGMENTOS = 20 -- blocos da barra pixelada

-- (V3) Preload
local SKIP_APOS = 5 -- segundos até o botão de pular aparecer
local LOTE_ASSETS = 32 -- itens por chamada de PreloadAsync
local VARREDURAS_ESTAVEIS = 2 -- alcança conteúdo inserido durante o boot

-- LocalPlayer (sem travar)
local player = Players.LocalPlayer
if not player then
	Players:GetPropertyChangedSignal("LocalPlayer"):Wait()
	player = Players.LocalPlayer
end
local playerGui = player:WaitForChild("PlayerGui")

local startTime = os.clock()

-- ===================== PALETA RETRO =====================
local COR_FUNDO = Color3.fromRGB(8, 6, 20)
local COR_FUNDO2 = Color3.fromRGB(24, 10, 44)
local COR_NEON = Color3.fromRGB(0, 255, 170) -- verde neon
local COR_NEON2 = Color3.fromRGB(255, 0, 120) -- magenta
local COR_CIANO = Color3.fromRGB(0, 200, 255)
local COR_AMARELO = Color3.fromRGB(255, 200, 0) -- INSERT COIN
local COR_TEXTO = Color3.fromRGB(235, 235, 245)
local COR_BLOCO_OFF = Color3.fromRGB(35, 30, 62)

-- ===================== GUI BASE =====================
local gui = Instance.new("ScreenGui")
gui.Name = "LoadingScreen"
gui.IgnoreGuiInset = true
gui.DisplayOrder = 2147483647
gui.ResetOnSpawn = false
gui.Enabled = true
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = playerGui

local fundo = Instance.new("Frame")
fundo.Name = "Fundo"
fundo.Size = UDim2.fromScale(1, 1)
fundo.BackgroundColor3 = COR_FUNDO
fundo.BorderSizePixel = 0
fundo.Active = true
fundo.ZIndex = 1
fundo.Parent = gui

-- Gradiente animado de fundo (REUTILIZADO da V1)
local grad = Instance.new("UIGradient")
grad.Rotation = 90
grad.Color = ColorSequence.new(COR_FUNDO, COR_FUNDO2)
grad.Parent = fundo

-- ===================== GRID SYNTHWAVE =====================
local gridArea = Instance.new("Frame")
gridArea.Name = "GridSynthwave"
gridArea.AnchorPoint = Vector2.new(0.5, 1)
gridArea.Position = UDim2.fromScale(0.5, 1)
gridArea.Size = UDim2.fromScale(1, 0.32)
gridArea.BackgroundTransparency = 1
gridArea.ClipsDescendants = true
gridArea.ZIndex = 2
gridArea.Parent = fundo

-- Brilho do horizonte
local horizonteGlow = Instance.new("Frame")
horizonteGlow.AnchorPoint = Vector2.new(0.5, 0)
horizonteGlow.Position = UDim2.fromScale(0.5, 0)
horizonteGlow.Size = UDim2.fromScale(1, 0.12)
horizonteGlow.BackgroundColor3 = COR_NEON2
horizonteGlow.BorderSizePixel = 0
horizonteGlow.ZIndex = 2
horizonteGlow.Parent = gridArea
local glowGrad = Instance.new("UIGradient")
glowGrad.Rotation = 90
glowGrad.Transparency = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0.55),
	NumberSequenceKeypoint.new(1, 1),
})
glowGrad.Parent = horizonteGlow

-- Linha do horizonte
local horizonte = Instance.new("Frame")
horizonte.AnchorPoint = Vector2.new(0.5, 0)
horizonte.Position = UDim2.fromScale(0.5, 0)
horizonte.Size = UDim2.new(1, 0, 0, 3)
horizonte.BackgroundColor3 = COR_NEON2
horizonte.BorderSizePixel = 0
horizonte.ZIndex = 3
horizonte.Parent = gridArea

-- Linhas horizontais em perspectiva (posições FIXAS pré-definidas)
local linhasH = { 0.06, 0.14, 0.24, 0.36, 0.5, 0.66, 0.84 }
for i, frac in ipairs(linhasH) do
	local linha = Instance.new("Frame")
	linha.AnchorPoint = Vector2.new(0.5, 0)
	linha.Position = UDim2.fromScale(0.5, frac)
	linha.Size = UDim2.new(1, 0, 0, math.min(1 + math.floor(i / 3), 3))
	linha.BackgroundColor3 = COR_NEON2
	linha.BackgroundTransparency = 0.45
	linha.BorderSizePixel = 0
	linha.ZIndex = 2
	linha.Parent = gridArea
end

-- Raios verticais convergindo no horizonte (rotações FIXAS)
for rot = -72, 72, 12 do
	local raio = Instance.new("Frame")
	raio.AnchorPoint = Vector2.new(0.5, 0.5)
	raio.Position = UDim2.fromScale(0.5, 0)
	raio.Size = UDim2.new(0, 2, 2.4, 0)
	raio.Rotation = rot
	raio.BackgroundColor3 = COR_NEON2
	raio.BackgroundTransparency = 0.6
	raio.BorderSizePixel = 0
	raio.ZIndex = 2
	raio.Parent = gridArea
end

-- ===================== CONTEÚDO =====================
-- Marca do estúdio
local marca = Instance.new("TextLabel")
marca.Name = "Marca"
marca.AnchorPoint = Vector2.new(0.5, 0.5)
marca.Position = UDim2.fromScale(0.5, 0.1)
marca.Size = UDim2.fromScale(0.8, 0.04)
marca.BackgroundTransparency = 1
marca.Font = Enum.Font.Code
marca.Text = "R E T R O - V E R S E  /  S T U D I O S"
marca.TextScaled = true
marca.TextColor3 = COR_CIANO
marca.TextTransparency = 0.25
marca.ZIndex = 5
marca.Parent = fundo

-- Título com aberração cromática: 2 ghosts + principal
local function criarTitulo(nome, cor, transp, z)
	local t = Instance.new("TextLabel")
	t.Name = nome
	t.AnchorPoint = Vector2.new(0.5, 0.5)
	t.Position = UDim2.fromScale(0.5, 0.3)
	t.Size = UDim2.fromScale(0.9, 0.16)
	t.BackgroundTransparency = 1
	t.Font = Enum.Font.Arcade
	t.Text = "CAMPO DE BATALHA / DO CHAOS REVERSO"
	t.TextScaled = true
	t.TextColor3 = cor
	t.TextTransparency = transp
	t.ZIndex = z
	t.Parent = fundo
	return t
end

local tituloGhostC = criarTitulo("TituloGhostCiano", COR_CIANO, 0.6, 4)
local tituloGhostM = criarTitulo("TituloGhostMagenta", COR_NEON2, 0.6, 4)
local titulo = criarTitulo("Titulo", COR_NEON, 0, 5)

local tituloStroke = Instance.new("UIStroke")
tituloStroke.Color = COR_NEON2
tituloStroke.Thickness = 2
tituloStroke.Parent = titulo

-- Spinner (REUTILIZADO da V1)
local spinner = Instance.new("TextLabel")
spinner.Name = "Spinner"
spinner.AnchorPoint = Vector2.new(0.5, 0.5)
spinner.Position = UDim2.fromScale(0.5, 0.45)
spinner.Size = UDim2.fromScale(0.1, 0.07)
spinner.BackgroundTransparency = 1
spinner.Font = Enum.Font.Code
spinner.Text = "◜"
spinner.TextScaled = true
spinner.TextColor3 = COR_NEON
spinner.ZIndex = 5
spinner.Parent = fundo

-- Status (typewriter + cursor)
local status = Instance.new("TextLabel")
status.Name = "Status"
status.AnchorPoint = Vector2.new(0.5, 0.5)
status.Position = UDim2.fromScale(0.5, 0.55)
status.Size = UDim2.fromScale(0.8, 0.05)
status.BackgroundTransparency = 1
status.Font = Enum.Font.Code
status.Text = ""
status.TextScaled = true
status.TextColor3 = COR_TEXTO
status.ZIndex = 5
status.Parent = fundo

-- Trilho da barra pixelada
local trilho = Instance.new("Frame")
trilho.Name = "Trilho"
trilho.AnchorPoint = Vector2.new(0.5, 0.5)
trilho.Position = UDim2.fromScale(0.5, 0.66)
trilho.Size = UDim2.fromScale(0.6, 0.045)
trilho.BackgroundColor3 = Color3.fromRGB(18, 14, 36)
trilho.BorderSizePixel = 0
trilho.ZIndex = 4
trilho.Parent = fundo

local trilhoStroke = Instance.new("UIStroke")
trilhoStroke.Color = COR_NEON
trilhoStroke.Thickness = 2
trilhoStroke.Parent = trilho

-- Blocos pixelados (cores pré-calculadas: verde -> magenta)
local blocos = {}
for i = 1, SEGMENTOS do
	local alpha = (i - 1) / (SEGMENTOS - 1)
	local bloco = Instance.new("Frame")
	bloco.Name = "Bloco" .. i
	bloco.Position = UDim2.fromScale((i - 1) / SEGMENTOS + 0.004, 0.14)
	bloco.Size = UDim2.fromScale(1 / SEGMENTOS - 0.008, 0.72)
	bloco.BackgroundColor3 = COR_BLOCO_OFF
	bloco.BorderSizePixel = 0
	bloco.ZIndex = 5
	bloco.Parent = trilho
	blocos[i] = {
		frame = bloco,
		corLigada = COR_NEON:Lerp(COR_NEON2, alpha),
	}
end

-- Porcentagem estilo arcade
local porcento = Instance.new("TextLabel")
porcento.Name = "Porcento"
porcento.AnchorPoint = Vector2.new(0.5, 0.5)
porcento.Position = UDim2.fromScale(0.5, 0.73)
porcento.Size = UDim2.fromScale(0.4, 0.045)
porcento.BackgroundTransparency = 1
porcento.Font = Enum.Font.Arcade
porcento.Text = "LOADING 000%"
porcento.TextScaled = true
porcento.TextColor3 = COR_NEON
porcento.ZIndex = 5
porcento.Parent = fundo

-- Dicas em rotação SEQUENCIAL (conteúdo dos sistemas reais do jogo)
local DICAS = {
	"DICA: O LOBBY É ZONA SEGURA — NINGUÉM TE DANIFICA LÁ",
	"DICA: EQUIPE UM PERSONAGEM NO MENU PARA IR AO MAPA",
	"DICA: VOCÊ DROPA 10% DAS SUAS MOEDAS QUANDO MORRE",
	"DICA: MEMBROS DO MESMO TIME NÃO SE MACHUCAM",
	"DICA: VOLTE TODO DIA PARA PEGAR A RECOMPENSA DIÁRIA",
}
local dica = Instance.new("TextLabel")
dica.Name = "Dica"
dica.AnchorPoint = Vector2.new(0.5, 0.5)
dica.Position = UDim2.fromScale(0.5, 0.8)
dica.Size = UDim2.fromScale(0.85, 0.04)
dica.BackgroundTransparency = 1
dica.Font = Enum.Font.Code
dica.Text = DICAS[1]
dica.TextScaled = true
dica.TextColor3 = COR_CIANO
dica.TextTransparency = 0.2
dica.ZIndex = 5
dica.Parent = fundo

-- Rodapé estilo fliperama
local rodape = Instance.new("TextLabel")
rodape.Name = "Rodape"
rodape.AnchorPoint = Vector2.new(0.5, 0.5)
rodape.Position = UDim2.fromScale(0.35, 0.93)
rodape.Size = UDim2.fromScale(0.5, 0.032)
rodape.BackgroundTransparency = 1
rodape.Font = Enum.Font.Code
rodape.Text = "(C) 2026 RETRO-VERSE STUDIOS"
rodape.TextScaled = true
rodape.TextColor3 = COR_TEXTO
rodape.TextTransparency = 0.4
rodape.ZIndex = 5
rodape.Parent = fundo

local insertCoin = Instance.new("TextLabel")
insertCoin.Name = "InsertCoin"
insertCoin.AnchorPoint = Vector2.new(0.5, 0.5)
insertCoin.Position = UDim2.fromScale(0.78, 0.93)
insertCoin.Size = UDim2.fromScale(0.25, 0.035)
insertCoin.BackgroundTransparency = 1
insertCoin.Font = Enum.Font.Arcade
insertCoin.Text = "INSERT COIN"
insertCoin.TextScaled = true
insertCoin.TextColor3 = COR_AMARELO
insertCoin.ZIndex = 5
insertCoin.Parent = fundo

-- ===================== CAMADAS CRT =====================
-- Scanlines densas
local scan = Instance.new("Frame")
scan.Name = "Scanlines"
scan.Size = UDim2.fromScale(1, 1)
scan.BackgroundTransparency = 1
scan.ZIndex = 8
scan.Parent = fundo
for i = 1, 50 do
	local line = Instance.new("Frame")
	line.Size = UDim2.new(1, 0, 0, 1)
	line.Position = UDim2.fromScale(0, i / 50)
	line.BackgroundColor3 = Color3.new(0, 0, 0)
	line.BackgroundTransparency = 0.86
	line.BorderSizePixel = 0
	line.ZIndex = 8
	line.Parent = scan
end

-- Vinheta (4 bordas escurecidas)
local function criarVinheta(pos, size, rotacao)
	local v = Instance.new("Frame")
	v.AnchorPoint = Vector2.new(0.5, 0.5)
	v.Position = pos
	v.Size = size
	v.BackgroundColor3 = Color3.new(0, 0, 0)
	v.BorderSizePixel = 0
	v.ZIndex = 9
	v.Parent = fundo
	local g = Instance.new("UIGradient")
	g.Rotation = rotacao
	g.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.35),
		NumberSequenceKeypoint.new(1, 1),
	})
	g.Parent = v
	return v
end
criarVinheta(UDim2.fromScale(0.5, 0.07), UDim2.fromScale(1, 0.14), 90) -- topo
criarVinheta(UDim2.fromScale(0.5, 0.93), UDim2.fromScale(1, 0.14), -90) -- base
criarVinheta(UDim2.fromScale(0.09, 0.5), UDim2.fromScale(0.18, 1), 0) -- esquerda
criarVinheta(UDim2.fromScale(0.91, 0.5), UDim2.fromScale(0.18, 1), 180) -- direita

-- Flicker de CRT (transparência oscilando por seno — determinístico)
local flicker = Instance.new("Frame")
flicker.Name = "Flicker"
flicker.Size = UDim2.fromScale(1, 1)
flicker.BackgroundColor3 = Color3.new(0, 0, 0)
flicker.BackgroundTransparency = 0.97
flicker.BorderSizePixel = 0
flicker.ZIndex = 10
flicker.Parent = fundo

-- ===================== (V3) BOTÃO DE PULAR =====================
-- Fica escondido no começo: mostrar "pular" antes de a tela sequer
-- desenhar convida a pular sempre, e aí o preload nunca serve para nada.
-- Aparece depois de SKIP_APOS segundos.
local btnPular = Instance.new("TextButton")
btnPular.Name = "BotaoPular"
btnPular.AnchorPoint = Vector2.new(0.5, 0.5)
btnPular.Position = UDim2.fromScale(0.5, 0.93)
btnPular.Size = UDim2.fromScale(0.22, 0.055)
btnPular.BackgroundColor3 = COR_FUNDO2
btnPular.BorderSizePixel = 0
btnPular.Text = "PULAR  ▶"
btnPular.TextColor3 = COR_AMARELO
btnPular.TextScaled = true
btnPular.Font = Enum.Font.Arcade
btnPular.AutoButtonColor = false
btnPular.Visible = false
btnPular.BackgroundTransparency = 1
btnPular.TextTransparency = 1
btnPular.ZIndex = 50
btnPular.Parent = fundo

local btnBorda = Instance.new("UIStroke")
btnBorda.Color = COR_AMARELO
btnBorda.Thickness = 2
btnBorda.Transparency = 1
btnBorda.Parent = btnPular

-- Mantém a forma do botão em qualquer proporção de tela.
local btnRatio = Instance.new("UIAspectRatioConstraint")
btnRatio.AspectRatio = 4
btnRatio.DominantAxis = Enum.DominantAxis.Height
btnRatio.Parent = btnPular

local btnPad = Instance.new("UIPadding")
btnPad.PaddingLeft = UDim.new(0, 6)
btnPad.PaddingRight = UDim.new(0, 6)
btnPad.Parent = btnPular

print("[LOADING V3] tela retro criada e exibida")

-- ===================== ESTADO =====================
local rodando = true
local gameLoaded = game:IsLoaded()
local serverReady = false
local serverFraction = 0 -- progresso reportado pelo servidor (0..1)
local serverStatus = "CONECTANDO AO SERVIDOR..."
local mostrado = 0 -- progresso exibido (suavizado)

-- (V3) Preload e pulo
local pulou = false -- jogador apertou PULAR
local assetsProntos = false -- PreloadAsync terminou (ou não havia o que baixar)
local assetsFeitos = 0
local assetsTotal = 0
local falhasAssets = 0
local preloadIniciado = false

local statusAlvo = "INICIALIZANDO SISTEMA..."
local statusDigitado = ""
local cursorLigado = true

-- ===================== (V3) PULAR =====================
btnPular.Activated:Connect(function()
	if not rodando then
		return
	end
	pulou = true
	btnPular.Text = "ENTRANDO..."
	btnPular.Active = false
end)

-- Revela o botão depois de SKIP_APOS. Um tween só, com alvo final —
-- nada de laço criando tween a cada volta.
task.delay(SKIP_APOS, function()
	if not rodando then
		return
	end
	btnPular.Visible = true
	TweenService:Create(btnPular, TweenInfo.new(0.5, Enum.EasingStyle.Quad), {
		BackgroundTransparency = 0.35,
		TextTransparency = 0,
	}):Play()
	TweenService:Create(btnBorda, TweenInfo.new(0.5, Enum.EasingStyle.Quad), {
		Transparency = 0,
	}):Play()
end)

-- ===================== (V3) PRELOAD DOS ASSETS =====================
-- Não existe teto artificial: o caminho normal só termina depois de todos
-- os portadores replicados terem retornado Success. Falhas são repetidas;
-- um asset inválido deixa PULAR disponível, mas nunca vira sucesso falso.
local COM_CONTEUDO = {
	Animation = true,
	AudioPlayer = true,
	Beam = true,
	CharacterMesh = true,
	Decal = true,
	ImageButton = true,
	ImageLabel = true,
	MaterialVariant = true,
	MeshPart = true,
	Pants = true,
	ParticleEmitter = true,
	Shirt = true,
	ShirtGraphic = true,
	Sky = true,
	Sound = true,
	SpecialMesh = true,
	SurfaceAppearance = true,
	Texture = true,
	Trail = true,
	VideoFrame = true,
	WrapLayer = true,
}

local function coletarNovosAssets(vistos)
	local novos = {}
	for _, item in ipairs(game:GetDescendants()) do
		if COM_CONTEUDO[item.ClassName] and not vistos[item] then
			vistos[item] = true
			table.insert(novos, item)
		end
	end
	return novos
end

local function carregarLote(lote)
	local falhasFinais = 0
	for tentativa = 1, 2 do
		local falhas = 0
		local ok = pcall(function()
			ContentProvider:PreloadAsync(lote, function(_, fetchStatus)
				if fetchStatus ~= Enum.AssetFetchStatus.Success then
					falhas += 1
				end
			end)
		end)
		if not ok then
			falhas = math.max(falhas, #lote)
		end
		falhasFinais = falhas
		if ok and falhas == 0 then
			break
		end
		if tentativa < 2 then
			task.wait(0.2)
		end
	end
	return falhasFinais
end

task.spawn(function()
	if not gameLoaded then
		game.Loaded:Wait()
		gameLoaded = true
	end
	if not rodando then
		return
	end

	preloadIniciado = true
	local vistos = {}
	local lotesParaRepetir = {}
	local varredurasVazias = 0

	while rodando and not pulou do
		local novos = coletarNovosAssets(vistos)
		if #novos > 0 then
			varredurasVazias = 0
			assetsTotal += #novos

			for primeiro = 1, #novos, LOTE_ASSETS do
				if not rodando or pulou then
					return
				end
				local lote = {}
				local ultimo = math.min(primeiro + LOTE_ASSETS - 1, #novos)
				for indice = primeiro, ultimo do
					table.insert(lote, novos[indice])
				end

				statusAlvo = string.format("BAIXANDO ASSETS... %d/%d", assetsFeitos, assetsTotal)
				local falhas = carregarLote(lote)
				if falhas > 0 then
					falhasAssets += falhas
					table.insert(lotesParaRepetir, lote)
				end
				assetsFeitos += #lote
			end
		elseif serverReady and ContentProvider.RequestQueueSize <= 0 then
			varredurasVazias += 1
			if varredurasVazias >= VARREDURAS_ESTAVEIS then
				if #lotesParaRepetir == 0 then
					break
				end

				statusAlvo = string.format(
					"REPETINDO %d LOTE(S) COM FALHA — OU USE PULAR...",
					#lotesParaRepetir
				)
				task.wait(1)
				local aindaFalhando = {}
				local falhasRestantes = 0
				for _, lote in ipairs(lotesParaRepetir) do
					if not rodando or pulou then
						return
					end
					local falhas = carregarLote(lote)
					if falhas > 0 then
						falhasRestantes += falhas
						table.insert(aindaFalhando, lote)
					end
				end
				lotesParaRepetir = aindaFalhando
				falhasAssets = falhasRestantes
				varredurasVazias = 0
			end
		end
		task.wait(0.5)
	end

	if rodando and not pulou then
		assetsProntos = true
		falhasAssets = 0
		statusAlvo = "TODOS OS ASSETS CARREGADOS!"
	end
end)

-- ===================== ANIMAÇÕES (todas determinísticas) =====================
-- Spinner girando (REUTILIZADO da V1)
task.spawn(function()
	local frames = { "◜", "◝", "◞", "◟" }
	local i = 1
	while rodando do
		spinner.Text = frames[i]
		i = (i % #frames) + 1
		task.wait(0.12)
	end
end)

-- Gradiente do fundo respirando (REUTILIZADO da V1)
task.spawn(function()
	while rodando do
		TweenService:Create(grad, TweenInfo.new(2), { Offset = Vector2.new(0, 0.15) }):Play()
		task.wait(2)
		TweenService:Create(grad, TweenInfo.new(2), { Offset = Vector2.new(0, -0.15) }):Play()
		task.wait(2)
	end
end)

-- Pulso de brilho no título (REUTILIZADO da V1)
task.spawn(function()
	while rodando do
		TweenService:Create(tituloStroke, TweenInfo.new(0.8), { Thickness = 4 }):Play()
		task.wait(0.8)
		TweenService:Create(tituloStroke, TweenInfo.new(0.8), { Thickness = 2 }):Play()
		task.wait(0.8)
	end
end)

-- Glitch de aberração cromática (ciclo FIXO, sem Randomize)
task.spawn(function()
	local base = UDim2.fromScale(0.5, 0.3)
	local padrao = {
		{ c = Vector2.new(-8, 4), m = Vector2.new(8, -4) },
		{ c = Vector2.new(6, -3), m = Vector2.new(-6, 3) },
		{ c = Vector2.new(-4, -2), m = Vector2.new(4, 2) },
	}
	while rodando do
		-- repouso: deslocamento sutil constante
		tituloGhostC.Position = base + UDim2.fromOffset(-2, 1)
		tituloGhostM.Position = base + UDim2.fromOffset(2, -1)
		task.wait(2.6)
		-- rajada de glitch (3 passos fixos)
		for _, passo in ipairs(padrao) do
			if not rodando then
				break
			end
			tituloGhostC.Position = base + UDim2.fromOffset(passo.c.X, passo.c.Y)
			tituloGhostM.Position = base + UDim2.fromOffset(passo.m.X, passo.m.Y)
			task.wait(0.06)
		end
	end
end)

-- Typewriter do status
task.spawn(function()
	local alvoAtual = ""
	while rodando do
		if statusAlvo ~= alvoAtual then
			alvoAtual = statusAlvo
			statusDigitado = ""
		end
		if #statusDigitado < #alvoAtual then
			statusDigitado = string.sub(alvoAtual, 1, #statusDigitado + 1)
		end
		task.wait(0.02)
	end
end)

-- Cursor piscando
task.spawn(function()
	while rodando do
		cursorLigado = not cursorLigado
		task.wait(0.35)
	end
end)

-- INSERT COIN piscando
task.spawn(function()
	while rodando do
		insertCoin.TextTransparency = 0
		task.wait(0.55)
		insertCoin.TextTransparency = 1
		task.wait(0.45)
	end
end)

-- Dicas em rotação SEQUENCIAL
task.spawn(function()
	local idx = 1
	while rodando do
		task.wait(4)
		if not rodando then
			break
		end
		idx = (idx % #DICAS) + 1
		dica.Text = DICAS[idx]
	end
end)

-- Atualização por frame: barra pixelada + status + flicker
local heartbeatConn
heartbeatConn = RunService.Heartbeat:Connect(function(deltaTime)
	if not rodando then
		return
	end
	local agora = os.clock()

	-- Progresso real: replicação (8%), servidor (22%) e assets (70%).
	-- Nunca chega a 100% sem as três condições ou o pedido manual de pulo.
	local fracaoAssets = assetsProntos and 1
		or (assetsTotal > 0 and math.clamp(assetsFeitos / assetsTotal, 0, 1) or 0)
	local alvo = (gameLoaded and 0.08 or 0) + serverFraction * 0.22 + fracaoAssets * 0.7
	local prontoTudo = gameLoaded and serverReady and assetsProntos
	if prontoTudo or pulou then
		alvo = 1
	else
		alvo = math.min(alvo, 0.99)
	end
	local suavizacao = 1 - math.exp(-8 * math.max(deltaTime, 0))
	-- Assets que aparecem durante o boot aumentam o total; a barra não volta.
	mostrado += math.max(0, alvo - mostrado) * suavizacao
	local f = math.clamp(mostrado, 0, 1)

	if pulou then
		statusAlvo = "PULANDO — ASSETS RESTANTES CARREGARÃO DEPOIS..."
	elseif preloadIniciado and assetsFeitos < assetsTotal then
		statusAlvo = string.format("BAIXANDO ASSETS... %d/%d", assetsFeitos, assetsTotal)
	elseif not serverReady then
		statusAlvo = serverStatus
	elseif falhasAssets > 0 then
		-- A tarefa de preload escreve a quantidade de lotes em repetição.
	elseif not assetsProntos then
		statusAlvo = "VERIFICANDO NOVOS ASSETS..."
	else
		statusAlvo = "TODOS OS ASSETS CARREGADOS!"
	end

	-- Blocos pixelados
	local acesos = math.floor(f * SEGMENTOS)
	for i = 1, SEGMENTOS do
		local b = blocos[i]
		if i <= acesos then
			b.frame.BackgroundColor3 = b.corLigada
			b.frame.BackgroundTransparency = 0
		elseif i == acesos + 1 then
			-- bloco ativo pisca (seno determinístico)
			b.frame.BackgroundColor3 = b.corLigada
			b.frame.BackgroundTransparency = 0.25 + 0.45 * math.abs(math.sin(agora * 6))
		else
			b.frame.BackgroundColor3 = COR_BLOCO_OFF
			b.frame.BackgroundTransparency = 0
		end
	end

	porcento.Text = string.format("LOADING %03d%%", math.floor(f * 100))

	-- Status com cursor
	status.Text = statusDigitado .. (cursorLigado and "_" or " ")

	-- Flicker de CRT sutil
	flicker.BackgroundTransparency = 0.95 + 0.035 * math.sin(agora * 9)
end)

-- ===================== HANDSHAKE COM O SERVIDOR =====================
-- Falha do servidor mantém a tela aberta; PULAR é a saída manual.
local stageConn, readyConn

task.spawn(function()
	local remotes = ReplicatedStorage:WaitForChild("Remotes", 12)
	if not remotes then
		serverStatus = "SERVIDOR NÃO RESPONDEU — USE PULAR"
		warn("[LOADING V3] Remotes não encontrado; aguardando PULAR")
		return
	end

	local stageEvent = remotes:FindFirstChild("LoadingStage")
	if stageEvent and stageEvent:IsA("RemoteEvent") then
		stageConn = stageEvent.OnClientEvent:Connect(function(texto, fracao)
			if type(texto) == "string" then
				serverStatus = texto
			end
			if type(fracao) == "number" then
				serverFraction = math.clamp(fracao, 0, 1)
			end
		end)
	end

	local readyEvent = remotes:FindFirstChild("LoadingReady")
	if readyEvent and readyEvent:IsA("RemoteEvent") then
		readyConn = readyEvent.OnClientEvent:Connect(function()
			serverReady = true
			serverFraction = 1
			serverStatus = "SERVIDOR PRONTO!"
		end)
	end

	-- Poll de segurança (caso o evento tenha disparado antes de conectarmos)
	local queryFn = remotes:FindFirstChild("QueryLoadingReady")
	if queryFn and queryFn:IsA("RemoteFunction") then
		while not serverReady and rodando do
			local ok, res = pcall(function()
				return queryFn:InvokeServer()
			end)
			if ok and res == true then
				serverReady = true
				serverFraction = 1
				serverStatus = "SERVIDOR PRONTO!"
				break
			end
			task.wait(0.3)
		end
	end
end)

-- ===================== ESPERA PRINCIPAL =====================
-- Só o caminho completo ou a escolha explícita PULAR fecham a tela.
local concluiuNormalmente = false
while rodando do
	local elapsed = os.clock() - startTime
	concluiuNormalmente = gameLoaded and serverReady and assetsProntos and elapsed >= MIN_DISPLAY
	if concluiuNormalmente or pulou then
		break
	end
	task.wait(0.1)
end

-- ===================== FINAL =====================
serverFraction = 1
mostrado = 1
statusAlvo = concluiuNormalmente and "TODOS OS ASSETS CARREGADOS — READY!" or "PULANDO..."

-- O botão some junto com a tela; deixá-lo clicável durante o fade só
-- geraria clique sem efeito.
btnPular.Active = false
task.wait(0.45)

-- Pisca final dos blocos (2 piscadas fixas, estilo arcade)
for pisca = 1, 2 do
	for i = 1, SEGMENTOS do
		blocos[i].frame.BackgroundColor3 = COR_NEON2
	end
	task.wait(0.08)
	for i = 1, SEGMENTOS do
		blocos[i].frame.BackgroundColor3 = blocos[i].corLigada
	end
	task.wait(0.08)
end

rodando = false

print(
	string.format(
		"[LOADING V3] sumindo — assets %d/%d, pulou=%s",
		assetsFeitos,
		assetsTotal,
		tostring(pulou)
	)
)

-- Desconectar conexões antes da limpeza (sem vazamentos)
if heartbeatConn then
	heartbeatConn:Disconnect()
end
if stageConn then
	stageConn:Disconnect()
end
if readyConn then
	readyConn:Disconnect()
end

-- Fade de saída (REUTILIZADO da V1)
local fade = TweenService:Create(fundo, TweenInfo.new(0.8, Enum.EasingStyle.Quad), {
	BackgroundTransparency = 1,
})
for _, item in fundo:GetDescendants() do
	if item:IsA("TextLabel") then
		TweenService:Create(item, TweenInfo.new(0.8), { TextTransparency = 1 }):Play()
	elseif item:IsA("TextButton") then
		TweenService:Create(item, TweenInfo.new(0.8), {
			TextTransparency = 1,
			BackgroundTransparency = 1,
		}):Play()
	elseif item:IsA("Frame") then
		TweenService:Create(item, TweenInfo.new(0.8), { BackgroundTransparency = 1 }):Play()
	elseif item:IsA("UIStroke") then
		TweenService:Create(item, TweenInfo.new(0.8), { Transparency = 1 }):Play()
	end
end
fade:Play()
fade.Completed:Wait()

-- (V2) Limpeza conforme regra do projeto: sem :Destroy()
gui.Enabled = false
gui.Parent = nil
