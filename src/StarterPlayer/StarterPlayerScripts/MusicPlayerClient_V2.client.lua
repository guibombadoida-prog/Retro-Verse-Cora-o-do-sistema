-- ============================================
-- MUSIC PLAYER CLIENT V6 — CATÁLOGO EM DATASTORE + VISUALIZER DE GRAVE
-- Coloque em: StarterPlayer > StarterPlayerScripts
-- Nome: "MusicPlayerClient_V2"
-- SUBSTITUI: MusicPlayerClient_V2 (V5)
-- ============================================
-- (V6) MUDANÇAS:
-- • AS FAIXAS SAÍRAM DO STUDIO. Até o V5 cada música era um objeto
--   Sound criado à mão dentro de workspace.MusicHolder — trocar a
--   trilha exigia abrir o Studio e publicar o jogo inteiro. Agora quem
--   manda é o MusicCatalogServer: os IDs ficam num DataStore
--   (RVMusicCatalogV1) e este cliente monta os Sound em tempo de
--   execução, do mesmo jeito que o CharacterCatalogServer faz com os
--   personagens.
-- • PAINEL DE ADMIN embutido: cola o ID, o servidor pergunta ao Roblox
--   se aquilo é áudio (MarketplaceService), preenche nome e autor
--   sozinho e grava. Aparece só para quem o AdminRegistryServer
--   reconhece.
-- • SYNC ENTRE SERVIDORES: adicionou numa partida, entra em todas —
--   MessagingService com guarda de JobId, igual ao catálogo.
-- • VISUALIZER DE GRAVE no painel NOW PLAYING (ver a nota sobre o
--   limite da plataforma na seção do visualizer).
--
-- DEPENDE DE: MusicCatalogServer (novo) e AdminRegistryServer
-- ============================================
-- (V5) :Destroy() -> .Parent = nil; shuffle aleatório -> sequencial
--   (Randomize proibido); fontes retro
-- ============================================
-- NOVIDADES V4:
-- • BOTÃO FLUTUANTE PRÓPRIO REMOVIDO (só abre pelo menu unificado ☰)
-- • Expõe _G.OpenMusicPlayer / _G.CloseMusicPlayer
-- • INTERFACE MELHORADA: cantos arredondados (UICorner), borda neon que
--   "respira" (UIStroke animado) e fundo em gradiente (UIGradient)
-- • CORREÇÃO DE BUG: clicar no fundo p/ fechar dava erro
--   (closeBtn.Activated:Fire() — RBXScriptSignal não tem :Fire()).
--   Agora usa uma função closeWindow() de verdade.
-- ============================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local SoundService = game:GetService("SoundService")
local GuiService = game:GetService("GuiService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- =====================================
-- DETECÇÃO DE PLATAFORMA
-- =====================================

local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
local isTablet = isMobile and (workspace.CurrentCamera.ViewportSize.X > 600)
local isConsole = GuiService:IsTenFootInterface()

print(
	string.format(
		"[MUSIC PLAYER V3] Plataforma: %s",
		isMobile and (isTablet and "Tablet" or "Mobile") or (isConsole and "Console" or "PC")
	)
)

-- =====================================
-- SONS (REUTILIZADOS DO PROJETO)
-- =====================================

local sounds = {
	click = "rbxassetid://156785206",
	open = "rbxassetid://157167203",
	close = "rbxassetid://157167205",
	hover = "rbxassetid://12846056",
}

local function playSound(soundId)
	pcall(function()
		local s = Instance.new("Sound")
		s.SoundId = soundId
		s.Volume = 0.5
		s.Parent = SoundService
		s:Play()
		s.Ended:Connect(function()
			s.Parent = nil
		end)
	end)
end

-- =====================================
-- INTEGRAÇÃO COM SISTEMA PRINCIPAL
-- =====================================

local ShowNotification = nil
pcall(function()
	local events = ReplicatedStorage:WaitForChild("Events", 5)
	if events then
		ShowNotification = events:FindFirstChild("ShowNotification")
	end
end)

local function notify(message, isSuccess)
	playSound(isSuccess ~= false and sounds.click or sounds.close)
	local notification = Instance.new("Frame")
	notification.Size = isMobile and UDim2.new(0.8, 0, 0.10, 0) or UDim2.new(0.4, 0, 0.07, 0)
	notification.Position = isMobile and UDim2.new(0.1, 0, 0.04, 0) or UDim2.new(0.3, 0, 0.04, 0)
	notification.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
	notification.BorderColor3 = isSuccess ~= false and Color3.fromRGB(0, 200, 150)
		or Color3.fromRGB(200, 0, 0)
	notification.BorderSizePixel = 3
	notification.ZIndex = 50
	notification.Parent = playerGui
	local text = Instance.new("TextLabel")
	text.Size = UDim2.new(1, 0, 1, 0)
	text.BackgroundTransparency = 1
	text.Text = message
	text.TextColor3 = Color3.fromRGB(255, 255, 255)
	text.TextScaled = true
	text.Font = Enum.Font.Arcade
	text.Parent = notification
	if ShowNotification then
		pcall(function()
			ShowNotification:FireServer(message)
		end)
	end
	task.wait(3)
	notification.Parent = nil
end

-- =====================================
-- SISTEMA DE TAMANHOS (SINCRONIZADO)
-- =====================================

local UI_SIZES = { SMALL = "Pequeno", MEDIUM = "Médio", LARGE = "Grande" }

local function detectCharacterMenuSize()
	local charMenuGui = playerGui:FindFirstChild("CharacterMenuV13")
		or playerGui:FindFirstChild("CharacterMenuV12")
		or playerGui:FindFirstChild("CharacterMenuV11")
	if not charMenuGui then
		return UI_SIZES.MEDIUM
	end
	local mainFrame = charMenuGui:FindFirstChild("MainFrame")
	if not mainFrame then
		return UI_SIZES.MEDIUM
	end
	local size = mainFrame.Size.X.Scale
	if isTablet then
		if size <= 0.75 then
			return UI_SIZES.SMALL
		elseif size >= 0.95 then
			return UI_SIZES.LARGE
		else
			return UI_SIZES.MEDIUM
		end
	elseif isMobile then
		if size <= 0.85 then
			return UI_SIZES.SMALL
		elseif size >= 0.98 then
			return UI_SIZES.LARGE
		else
			return UI_SIZES.MEDIUM
		end
	else
		if size <= 0.65 then
			return UI_SIZES.SMALL
		elseif size >= 0.85 then
			return UI_SIZES.LARGE
		else
			return UI_SIZES.MEDIUM
		end
	end
end

local currentUISize = detectCharacterMenuSize()

local function getUIScale()
	local baseScale
	if isTablet then
		baseScale = {
			menu = { small = 0.75, medium = 0.85, large = 0.95 },
			button = { small = 0.10, medium = 0.12, large = 0.14 },
		}
	elseif isMobile then
		baseScale = {
			menu = { small = 0.88, medium = 0.93, large = 0.98 },
			button = { small = 0.12, medium = 0.15, large = 0.18 },
		}
	else
		baseScale = {
			menu = { small = 0.65, medium = 0.75, large = 0.85 },
			button = { small = 0.08, medium = 0.10, large = 0.12 },
		}
	end
	local s = currentUISize == UI_SIZES.SMALL and "small"
		or (currentUISize == UI_SIZES.LARGE and "large" or "medium")
	return {
		menu = UDim2.new(baseScale.menu[s], 0, baseScale.menu[s] * 0.85, 0),
		button = UDim2.new(baseScale.button[s], 0, baseScale.button[s] * 0.65, 0),
	}
end

local uiScale = getUIScale()

-- =====================================
-- CORES (PADRÃO DO PROJETO)
-- =====================================

local COLORS = {
	background = Color3.fromRGB(20, 20, 20),
	panel = Color3.fromRGB(30, 30, 30),
	header = Color3.fromRGB(40, 40, 40),
	border = Color3.fromRGB(255, 255, 255),
	music = Color3.fromRGB(0, 200, 150), -- cor do music player
	progress = Color3.fromRGB(0, 200, 150),
	disabled = Color3.fromRGB(100, 100, 100),
	danger = Color3.fromRGB(200, 0, 0),
	warning = Color3.fromRGB(255, 200, 0),
	text = Color3.fromRGB(255, 255, 255),
	textDim = Color3.fromRGB(180, 180, 180),
}

-- =====================================
-- MUSIC HOLDER
-- =====================================

-- (V6) O Holder deixou de ser preenchido no Studio.
-- Antes as faixas eram objetos Sound criados à mão dentro de
-- workspace.MusicHolder, então trocar a trilha exigia abrir o Studio e
-- publicar o jogo. Agora o MusicCatalogServer guarda os IDs num
-- DataStore e este cliente monta os Sound em tempo de execução.
-- O Holder continua existindo porque o resto deste script trabalha em
-- cima dele — o que mudou é QUEM o preenche.
local Holder = workspace:FindFirstChild("MusicHolder")
if not Holder then
	Holder = Instance.new("Folder")
	Holder.Name = "MusicHolder"
	Holder.Parent = workspace
end

for _, obj in pairs(Holder:GetChildren()) do
	if not obj:IsA("Sound") then
		obj.Parent = nil
		warn("[MUSIC V6] Objeto inválido removido: " .. obj.Name)
	end
end

-- =====================================
-- (V6) CATÁLOGO DE MÚSICAS VINDO DO SERVIDOR
-- =====================================

local remotesFolder = ReplicatedStorage:WaitForChild("Remotes", 20)
local getMusicCatalog = remotesFolder and remotesFolder:WaitForChild("GetMusicCatalog", 20)
local musicCatalogSync = remotesFolder and remotesFolder:FindFirstChild("MusicCatalogSync")

local catalogoAtual = {}

-- Guarda de quem está tocando para não derrubar a faixa atual quando um
-- admin mexe no catálogo durante a reprodução.
local function faixaEmUso(sound)
	return sound ~= nil and sound.IsPlaying
end

local function popularHolder(lista)
	if type(lista) ~= "table" then
		return
	end
	catalogoAtual = lista

	local querido = {}
	for _, faixa in ipairs(lista) do
		if tonumber(faixa.id) then
			querido["rbxassetid://" .. tostring(faixa.id)] = faixa
		end
	end

	-- Tira o que saiu do catálogo (menos o que está tocando agora)
	for _, som in ipairs(Holder:GetChildren()) do
		if som:IsA("Sound") and not querido[som.SoundId] and not faixaEmUso(som) then
			som.Parent = nil
		end
	end

	-- Põe o que entrou e atualiza nome de quem já estava
	local existentes = {}
	for _, som in ipairs(Holder:GetChildren()) do
		if som:IsA("Sound") then
			existentes[som.SoundId] = som
		end
	end

	for _, faixa in ipairs(lista) do
		local assetId = "rbxassetid://" .. tostring(faixa.id)
		local som = existentes[assetId]

		if not som then
			som = Instance.new("Sound")
			som.SoundId = assetId
			som.Volume = 0.5
			som.Looped = false
			som.Parent = Holder
		end

		som.Name = faixa.nome or ("Faixa " .. tostring(faixa.id))

		if not som:FindFirstChild("Artista") then
			local a = Instance.new("StringValue")
			a.Name = "Artista"
			a.Parent = som
		end
		som.Artista.Value = faixa.artista or ""
	end

	-- Renumera na ordem do catálogo (o player usa Number para o "próxima")
	for indice, faixa in ipairs(lista) do
		local som = Holder:FindFirstChild(faixa.nome or "")
		if som and som:IsA("Sound") then
			local n = som:FindFirstChild("Number")
			if not n then
				n = Instance.new("IntValue")
				n.Name = "Number"
				n.Parent = som
			end
			n.Value = indice
		end
	end

	print(string.format("[MUSIC V6] ♪ Catálogo carregado: %d faixa(s)", #lista))
end

if musicCatalogSync then
	musicCatalogSync.OnClientEvent:Connect(popularHolder)
end

task.spawn(function()
	if not getMusicCatalog then
		warn("[MUSIC V6] ⚠️ GetMusicCatalog não encontrado — o MusicCatalogServer está instalado?")
		return
	end
	local ok, lista = pcall(function()
		return getMusicCatalog:InvokeServer()
	end)
	if ok and type(lista) == "table" then
		popularHolder(lista)
	end
end)

-- =====================================
-- VARIÁVEIS DO PLAYER
-- =====================================

local musicGui = nil
local isMenuOpen = false
local CurrentSong = nil
local SongStatus = "Playing"
local SoundEndConn = nil
local PlayerVolume = 1.0
local CurrentSpeed = 1.0
local CurrentPitch = 1.0
local PitchEffect = nil
local ReverbEffect = nil
local ReverbEnabled = false
local BassEffect = nil
local Debounce = false

-- =====================================
-- (V6) VISUALIZER DE GRAVE
-- =====================================
-- ⚠️ LIMITE DA PLATAFORMA: o Roblox NÃO expõe FFT/espectro. A única
-- leitura de áudio disponível é Sound.PlaybackLoudness (0 a 1000), que
-- é o nível geral da faixa, não por frequência.
--
-- Para isolar o grave, o truque é uma SONDA: um segundo Sound tocando a
-- mesma faixa, inaudível, com um EqualizerSoundEffect que derruba médio
-- e agudo no mínimo (-80 dB) e deixa o grave passar. O PlaybackLoudness
-- dessa sonda responde basicamente ao baixo e ao bumbo.
--
-- Se a sonda não responder (o comportamento do PlaybackLoudness com
-- volume zerado varia entre versões do motor), o visualizer cai para o
-- nível geral da faixa com ataque/queda lentos, que visualmente ainda lê
-- como pulso de grave. Ou seja: degrada, não quebra.

local VisualizerBarras = {}
local VisualizerSonda = nil
local VisualizerGrupo = nil
local VisualizerConn = nil
local VisualizerNiveis = {}

local VIS_BARRAS = 24
local VIS_SUAVIZA_SUBIDA = 0.55 -- quanto maior, mais rápido sobe
local VIS_SUAVIZA_DESCIDA = 0.12 -- quanto menor, mais devagar cai

local function CriarVisualizer(pai)
	VisualizerBarras = {}
	VisualizerNiveis = {}

	local faixa = Instance.new("Frame")
	faixa.Name = "Visualizer"
	faixa.Size = UDim2.new(1, -16, 0, isMobile and 30 or 36)
	faixa.Position = UDim2.new(0, 8, 1, isMobile and -42 or -50)
	faixa.BackgroundTransparency = 1
	faixa.BorderSizePixel = 0
	faixa.ZIndex = 1
	faixa.Parent = pai

	local largura = 1 / VIS_BARRAS

	for i = 1, VIS_BARRAS do
		local barra = Instance.new("Frame")
		barra.Name = "Bar" .. i
		barra.AnchorPoint = Vector2.new(0, 1)
		barra.Position = UDim2.new((i - 1) * largura, 0, 1, 0)
		barra.Size = UDim2.new(largura * 0.7, 0, 0, 2)
		barra.BackgroundColor3 = COLORS.music
		barra.BorderSizePixel = 0
		barra.ZIndex = 1
		barra.Parent = faixa

		VisualizerBarras[i] = barra
		VisualizerNiveis[i] = 0
	end

	return faixa
end

-- Monta a sonda de grave em cima da faixa que está tocando
local function PrepararSonda(sound)
	if VisualizerSonda then
		VisualizerSonda.Parent = nil
		VisualizerSonda = nil
	end

	if not sound then
		return
	end

	if not VisualizerGrupo then
		VisualizerGrupo = Instance.new("SoundGroup")
		VisualizerGrupo.Name = "VisualizerMudo"
		VisualizerGrupo.Volume = 0
		VisualizerGrupo.Parent = SoundService
	end

	local sonda = Instance.new("Sound")
	sonda.Name = "BassProbe"
	sonda.SoundId = sound.SoundId
	sonda.Volume = 1 -- o silêncio vem do SoundGroup, não daqui
	sonda.SoundGroup = VisualizerGrupo
	sonda.Looped = false

	local eq = Instance.new("EqualizerSoundEffect")
	eq.LowGain = 0
	eq.MidGain = -80
	eq.HighGain = -80
	eq.Parent = sonda

	sonda.Parent = SoundService
	VisualizerSonda = sonda

	task.spawn(function()
		local ok = pcall(function()
			sonda.TimePosition = sound.TimePosition
			sonda:Play()
		end)
		if not ok then
			sonda.Parent = nil
			if VisualizerSonda == sonda then
				VisualizerSonda = nil
			end
		end
	end)
end

local function PararSonda()
	if VisualizerSonda then
		pcall(function()
			VisualizerSonda:Stop()
		end)
		VisualizerSonda.Parent = nil
		VisualizerSonda = nil
	end
end

-- =====================================
-- (V6) PAINEL DE ADMIN DO CATÁLOGO
-- =====================================
-- É por aqui que o ID entra no jogo, sem Studio: cola o ID, o servidor
-- pergunta ao Roblox se aquilo é áudio, preenche nome e autor sozinho e
-- grava no DataStore. Todos os servidores recebem na hora.

-- ⚠️ ORDEM IMPORTA AQUI.
-- createMusicInterface() roda na CARGA do script, mas descobrir se o
-- jogador é admin é assíncrono (WaitForChild + InvokeServer). Se o
-- painel só fosse criado quando ehAdmin já fosse true, ele nunca
-- existiria: a interface é montada antes da resposta chegar, e não
-- havia nova tentativa.
--
-- Por isso o painel é SEMPRE construído, porém invisível, e só é
-- revelado quando a resposta chega. Quem não é admin nunca vê nada — e
-- mesmo que forjasse a chamada, o MusicCatalogServer recusa e dá Kick.
local ehAdmin = false
local PainelAdmin = nil
local AreaConteudo = nil
local AlturaPainelAdmin = 0

local painelJaRevelado = false

local function revelarPainelAdmin()
	if painelJaRevelado or not (ehAdmin and PainelAdmin) then
		return
	end
	-- Guarda: a revelação pode ser disparada por dois caminhos (a
	-- resposta do IsAdminCheck e a criação do painel). Sem isso a área
	-- de conteúdo encolheria duas vezes.
	painelJaRevelado = true

	PainelAdmin.Visible = true

	-- Encolhe a área de conteúdo para o painel não cobrir a playlist
	if AreaConteudo and AlturaPainelAdmin > 0 then
		local s = AreaConteudo.Size
		AreaConteudo.Size = UDim2.new(s.X.Scale, s.X.Offset, s.Y.Scale, s.Y.Offset - AlturaPainelAdmin - 6)
	end
end

task.spawn(function()
	local rem = ReplicatedStorage:WaitForChild("Remotes", 30)
	local check = rem and rem:WaitForChild("IsAdminCheck", 30)
	if not check then
		return
	end
	local ok, resultado = pcall(function()
		return check:InvokeServer()
	end)
	ehAdmin = ok and resultado == true

	if ehAdmin then
		print("[MUSIC V6] Admin reconhecido — painel de ID liberado")
		revelarPainelAdmin()
	end
end)

local function CriarPainelAdmin(pai)
	local adminRemotes = ReplicatedStorage:WaitForChild("Remotes", 10)
	local addRemote = adminRemotes and adminRemotes:WaitForChild("AdminMusicAdd", 10)
	local removeRemote = adminRemotes and adminRemotes:FindFirstChild("AdminMusicRemove")
	if not addRemote then
		warn("[MUSIC V6] ⚠️ AdminMusicAdd não encontrado — o MusicCatalogServer está instalado?")
		return
	end

	local painel = Instance.new("Frame")
	painel.Name = "AdminMusica"
	painel.Size = UDim2.new(1, -16, 0, isMobile and 62 or 54)
	painel.Position = UDim2.new(0, 8, 1, isMobile and -70 or -62)
	painel.BackgroundColor3 = COLORS.panel
	painel.BorderColor3 = COLORS.warning
	painel.BorderSizePixel = 2
	painel.ZIndex = 6
	painel.Visible = false -- revelado só quando o servidor confirma admin
	painel.Parent = pai

	PainelAdmin = painel
	AlturaPainelAdmin = isMobile and 62 or 54

	-- Se a resposta do IsAdminCheck já tiver chegado, revela agora
	if ehAdmin then
		task.defer(revelarPainelAdmin)
	end

	local titulo = Instance.new("TextLabel")
	titulo.Size = UDim2.new(0.3, 0, 0, 16)
	titulo.Position = UDim2.new(0, 6, 0, 3)
	titulo.BackgroundTransparency = 1
	titulo.Text = "ADMIN — ADICIONAR ID"
	titulo.TextColor3 = COLORS.warning
	titulo.Font = Enum.Font.Arcade
	titulo.TextSize = isMobile and 10 or 12
	titulo.TextXAlignment = Enum.TextXAlignment.Left
	titulo.ZIndex = 7
	titulo.Parent = painel

	local caixaId = Instance.new("TextBox")
	caixaId.Size = UDim2.new(0.34, 0, 0, isMobile and 24 or 22)
	caixaId.Position = UDim2.new(0, 6, 0, isMobile and 24 or 22)
	caixaId.BackgroundColor3 = COLORS.background
	caixaId.BorderColor3 = COLORS.border
	caixaId.BorderSizePixel = 1
	caixaId.PlaceholderText = "ID da música"
	caixaId.Text = ""
	caixaId.ClearTextOnFocus = false
	caixaId.TextColor3 = COLORS.text
	caixaId.Font = Enum.Font.Code
	caixaId.TextSize = isMobile and 11 or 12
	caixaId.ZIndex = 7
	caixaId.Parent = painel

	local caixaNome = Instance.new("TextBox")
	caixaNome.Size = UDim2.new(0.32, 0, 0, isMobile and 24 or 22)
	caixaNome.Position = UDim2.new(0.36, 4, 0, isMobile and 24 or 22)
	caixaNome.BackgroundColor3 = COLORS.background
	caixaNome.BorderColor3 = COLORS.border
	caixaNome.BorderSizePixel = 1
	caixaNome.PlaceholderText = "Nome (opcional)"
	caixaNome.Text = ""
	caixaNome.ClearTextOnFocus = false
	caixaNome.TextColor3 = COLORS.text
	caixaNome.Font = Enum.Font.Code
	caixaNome.TextSize = isMobile and 11 or 12
	caixaNome.ZIndex = 7
	caixaNome.Parent = painel

	local function botao(texto, posX, largura, cor)
		local b = Instance.new("TextButton")
		b.Size = UDim2.new(largura, 0, 0, isMobile and 24 or 22)
		b.Position = UDim2.new(posX, 4, 0, isMobile and 24 or 22)
		b.BackgroundColor3 = cor
		b.BorderColor3 = COLORS.border
		b.BorderSizePixel = 1
		b.Text = texto
		b.TextColor3 = COLORS.text
		b.Font = Enum.Font.Arcade
		b.TextSize = isMobile and 10 or 12
		b.ZIndex = 7
		b.Parent = painel
		return b
	end

	local btnAdd = botao("+ ADD", 0.69, 0.14, COLORS.header)
	local btnDel = botao("REMOVER", 0.84, 0.15, COLORS.danger)

	local ocupado = false

	btnAdd.Activated:Connect(function()
		if ocupado then
			return
		end
		local id = tonumber(caixaId.Text)
		if not id then
			notify("ID inválido", false)
			return
		end

		ocupado = true
		btnAdd.Text = "..."

		local ok, sucesso, mensagem = pcall(function()
			return addRemote:InvokeServer(id, caixaNome.Text, "")
		end)

		ocupado = false
		btnAdd.Text = "+ ADD"

		if ok then
			notify(mensagem or "Pronto", sucesso == true)
			if sucesso then
				caixaId.Text = ""
				caixaNome.Text = ""
			end
		else
			notify("Erro ao adicionar", false)
		end
	end)

	btnDel.Activated:Connect(function()
		if ocupado or not removeRemote then
			return
		end
		local id = tonumber(caixaId.Text)
		if not id then
			notify("Cole o ID que quer remover", false)
			return
		end

		ocupado = true
		local ok, sucesso, mensagem = pcall(function()
			return removeRemote:InvokeServer(id)
		end)
		ocupado = false

		if ok then
			notify(mensagem or "Pronto", sucesso == true)
			if sucesso then
				caixaId.Text = ""
			end
		else
			notify("Erro ao remover", false)
		end
	end)
end

-- Refs para UI (preenchidas ao criar interface)
local MusicName, SoundID, TimerLabel
local ProgressFill
local VolumeSlider, VolumeFill, VolumePercent
local BassSlider, BassKnob
local ReverbToggleBG, ReverbToggleBtn
local SpeedValue, PitchValue
local PlaylistScroll, QueueScroll
local PlayBtn, PauseBtn, SkipBtn
local SpeedMinus, SpeedPlus, PitchMinus, PitchPlus

-- =====================================
-- HELPERS DE UI (ESTILO DO PROJETO)
-- =====================================

local function makeHeader(parent, text, color)
	local h = Instance.new("Frame")
	h.Size = UDim2.new(1, 0, 0, isMobile and 32 or 36)
	h.BackgroundColor3 = color or COLORS.music
	h.BorderSizePixel = 0
	h.Parent = parent
	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.new(1, 0, 1, 0)
	lbl.BackgroundTransparency = 1
	lbl.Text = text
	lbl.TextColor3 = COLORS.text
	lbl.TextScaled = true
	lbl.Font = Enum.Font.Arcade
	lbl.Parent = h
	return h
end

local function makeButton(parent, text, color, size, pos)
	local btn = Instance.new("TextButton")
	btn.Size = size
	btn.Position = pos
	btn.BackgroundColor3 = color
	btn.BorderColor3 = COLORS.border
	btn.BorderSizePixel = 2
	btn.Text = text
	btn.TextColor3 = COLORS.background
	btn.TextScaled = true
	btn.Font = Enum.Font.Arcade
	btn.AutoButtonColor = false
	btn.Parent = parent
	-- hover PC
	if not isMobile then
		btn.MouseEnter:Connect(function()
			TweenService
				:Create(btn, TweenInfo.new(0.12), { BackgroundColor3 = Color3.new(1, 1, 1) })
				:Play()
		end)
		btn.MouseLeave:Connect(function()
			TweenService:Create(btn, TweenInfo.new(0.12), { BackgroundColor3 = color }):Play()
		end)
	end
	return btn
end

local function makePanel(parent, size, pos, color)
	local f = Instance.new("Frame")
	f.Size = size
	f.Position = pos
	f.BackgroundColor3 = color or COLORS.panel
	f.BorderColor3 = COLORS.border
	f.BorderSizePixel = 2
	f.Parent = parent
	return f
end

local function makeLabel(parent, text, size, pos, font, color, scaled)
	local lbl = Instance.new("TextLabel")
	lbl.Size = size
	lbl.Position = pos
	lbl.BackgroundTransparency = 1
	lbl.Text = text
	lbl.TextColor3 = color or COLORS.text
	lbl.Font = font or Enum.Font.Code
	lbl.TextScaled = scaled or false
	if not scaled then
		lbl.TextSize = isMobile and 14 or 16
	end
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.Parent = parent
	return lbl
end

-- =====================================
-- CRIAR INTERFACE PRINCIPAL
-- =====================================

local function createMusicInterface()
	if musicGui then
		musicGui.Parent = nil
	end

	musicGui = Instance.new("ScreenGui")
	musicGui.Name = "MusicPlayerV3"
	musicGui.ResetOnSpawn = false
	musicGui.DisplayOrder = 15
	musicGui.Parent = playerGui

	-- =====================================
	-- (BOTÃO FLUTUANTE PRÓPRIO REMOVIDO — abre só pelo menu unificado ☰)
	-- =====================================

	-- =====================================
	-- FUNDO ESCURO
	-- =====================================

	local background = Instance.new("Frame")
	background.Name = "Background"
	background.Size = UDim2.new(1, 0, 1, 0)
	background.BackgroundColor3 = Color3.new(0, 0, 0)
	background.BackgroundTransparency = 0.5
	background.BorderSizePixel = 0
	background.Visible = false
	background.Parent = musicGui

	-- =====================================
	-- JANELA PRINCIPAL
	-- =====================================

	local mainWindow = Instance.new("Frame")
	mainWindow.Name = "MainWindow"
	mainWindow.Size = uiScale.menu
	mainWindow.Position = UDim2.new(0.5, 0, 0.5, 0)
	mainWindow.AnchorPoint = Vector2.new(0.5, 0.5)
	mainWindow.BackgroundColor3 = COLORS.background
	mainWindow.BorderSizePixel = 0
	mainWindow.ClipsDescendants = true
	mainWindow.Visible = false
	mainWindow.Parent = musicGui

	-- ===== MELHORIA VISUAL (V4): cantos arredondados + brilho neon + gradiente =====
	local mwCorner = Instance.new("UICorner")
	mwCorner.CornerRadius = UDim.new(0, 12)
	mwCorner.Parent = mainWindow

	local mwGradient = Instance.new("UIGradient")
	mwGradient.Rotation = 90
	mwGradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(28, 30, 42)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(13, 14, 20)),
	})
	mwGradient.Parent = mainWindow

	local mwStroke = Instance.new("UIStroke")
	mwStroke.Color = COLORS.music
	mwStroke.Thickness = 2
	mwStroke.Transparency = 0.1
	mwStroke.Parent = mainWindow

	-- Brilho "respirando" na borda (efeito retro, sem random)
	task.spawn(function()
		while mwStroke.Parent do
			TweenService:Create(mwStroke, TweenInfo.new(1.4, Enum.EasingStyle.Sine), {
				Transparency = 0.55,
			}):Play()
			task.wait(1.4)
			TweenService:Create(mwStroke, TweenInfo.new(1.4, Enum.EasingStyle.Sine), {
				Transparency = 0.1,
			}):Play()
			task.wait(1.4)
		end
	end)

	-- Header da janela
	local windowHeader = makeHeader(mainWindow, "♪  MUSIC PLAYER", COLORS.music)
	windowHeader.Size = UDim2.new(1, 0, 0, isMobile and 36 or 40)

	-- Título
	local windowTitle = windowHeader:FindFirstChildOfClass("TextLabel")
	windowTitle.Size = UDim2.new(0.75, 0, 1, 0)
	windowTitle.TextXAlignment = Enum.TextXAlignment.Left
	windowTitle.TextScaled = true

	local titlePad = Instance.new("UIPadding", windowTitle)
	titlePad.PaddingLeft = UDim.new(0, 8)

	-- Botão fechar (no header)
	local closeBtn = Instance.new("TextButton")
	closeBtn.Size = UDim2.new(0, isMobile and 36 or 40, 1, -4)
	closeBtn.Position = UDim2.new(1, -(isMobile and 40 or 44), 0, 2)
	closeBtn.BackgroundColor3 = COLORS.danger
	closeBtn.BorderColor3 = COLORS.border
	closeBtn.BorderSizePixel = 2
	closeBtn.Text = "X"
	closeBtn.TextColor3 = COLORS.text
	closeBtn.TextScaled = true
	closeBtn.Font = Enum.Font.Arcade
	closeBtn.Parent = windowHeader

	-- =====================================
	-- NOW PLAYING PANEL
	-- =====================================

	local headerH = isMobile and 36 or 40
	local nowPanel = makePanel(
		mainWindow,
		UDim2.new(1, -16, 0, isMobile and 80 or 90),
		UDim2.new(0, 8, 0, headerH + 6),
		COLORS.panel
	)

	local nowHeader = makeHeader(nowPanel, "NOW PLAYING", COLORS.header)
	nowHeader.Size = UDim2.new(1, 0, 0, isMobile and 22 or 24)

	MusicName = Instance.new("TextLabel")
	MusicName.Name = "MusicName"
	MusicName.Size = UDim2.new(0.65, 0, 0, isMobile and 22 or 26)
	MusicName.Position = UDim2.new(0, 8, 0, isMobile and 24 or 26)
	MusicName.BackgroundTransparency = 1
	MusicName.Text = "-- NENHUMA MUSICA --"
	MusicName.TextColor3 = COLORS.music
	MusicName.Font = Enum.Font.Arcade
	MusicName.TextSize = isMobile and 12 or 14
	MusicName.TextXAlignment = Enum.TextXAlignment.Left
	MusicName.TextTruncate = Enum.TextTruncate.AtEnd
	MusicName.Parent = nowPanel

	SoundID = Instance.new("TextLabel")
	SoundID.Size = UDim2.new(0.5, 0, 0, isMobile and 14 or 16)
	SoundID.Position = UDim2.new(0, 8, 0, isMobile and 48 or 54)
	SoundID.BackgroundTransparency = 1
	SoundID.Text = "ID: 000000000"
	SoundID.TextColor3 = COLORS.textDim
	SoundID.Font = Enum.Font.Code
	SoundID.TextSize = isMobile and 11 or 12
	SoundID.TextXAlignment = Enum.TextXAlignment.Left
	SoundID.Parent = nowPanel

	TimerLabel = Instance.new("TextLabel")
	TimerLabel.Name = "Timer"
	TimerLabel.Size = UDim2.new(0, isMobile and 110 or 130, 0, isMobile and 22 or 26)
	TimerLabel.Position = UDim2.new(1, -(isMobile and 115 or 135), 0, isMobile and 24 or 26)
	TimerLabel.BackgroundTransparency = 1
	TimerLabel.Text = "0:00 / 0:00"
	TimerLabel.TextColor3 = COLORS.warning
	TimerLabel.Font = Enum.Font.Arcade
	TimerLabel.TextSize = isMobile and 13 or 15
	TimerLabel.TextXAlignment = Enum.TextXAlignment.Right
	TimerLabel.Parent = nowPanel

	-- Barra de progresso
	local progressBG = Instance.new("Frame")
	progressBG.Size = UDim2.new(1, -16, 0, isMobile and 6 or 8)
	progressBG.Position = UDim2.new(0, 8, 1, isMobile and -10 or -12)
	progressBG.BackgroundColor3 = COLORS.header
	progressBG.BorderColor3 = COLORS.border
	progressBG.BorderSizePixel = 1
	progressBG.Parent = nowPanel

	ProgressFill = Instance.new("Frame")
	ProgressFill.Size = UDim2.new(0, 0, 1, 0)
	ProgressFill.BackgroundColor3 = COLORS.progress
	ProgressFill.BorderSizePixel = 0
	ProgressFill.Parent = progressBG

	-- =====================================
	-- (V6) VISUALIZER DE GRAVE
	-- =====================================
	-- Barras atrás do texto, subindo do fundo do painel. ZIndex baixo
	-- para não cobrir nome, ID e tempo.
	CriarVisualizer(nowPanel)

	-- =====================================
	-- ÁREA DE CONTEÚDO
	-- =====================================

	local nowH = isMobile and 80 or 90
	local contentY = headerH + 6 + nowH + 8
	local contentH_raw = 1

	-- Conteúdo scrollable mobile ou fixo PC
	local contentArea
	if isMobile then
		contentArea = Instance.new("ScrollingFrame")
		contentArea.ScrollBarThickness = 6
		contentArea.ScrollBarImageColor3 = COLORS.music
		contentArea.CanvasSize = UDim2.new(0, 0, 0, 900)
	else
		contentArea = Instance.new("Frame")
	end
	contentArea.Name = "ContentArea"
	contentArea.Size = UDim2.new(1, -16, 1, -(contentY + 8))
	contentArea.Position = UDim2.new(0, 8, 0, contentY)
	contentArea.BackgroundTransparency = 1
	contentArea.BorderSizePixel = 0
	contentArea.Parent = mainWindow

	-- =====================================
	-- (V6) PAINEL DE ADMIN — ADICIONAR MÚSICA POR ID
	-- =====================================
	-- Vem DEPOIS da contentArea de propósito: ao ser revelado, o painel
	-- encolhe a área de conteúdo para não cobrir a playlist, e para isso
	-- precisa que ela já exista.
	AreaConteudo = contentArea
	-- task.spawn: o CriarPainelAdmin espera o remote AdminMusicAdd
	-- aparecer, e sem isso a montagem inteira da GUI ficaria travada
	-- por até 10s quando o MusicCatalogServer não estivesse instalado.
	task.spawn(CriarPainelAdmin, mainWindow)

	-- =====================================
	-- LAYOUT PC (3 COLUNAS)
	-- =====================================

	if not isMobile then
		-- ─── COLUNA ESQUERDA: PLAYLIST ───
		local plPanel = makePanel(contentArea, UDim2.new(0.28, -4, 1, 0), UDim2.new(0, 0, 0, 0))

		makeHeader(plPanel, "PLAYLIST", COLORS.header)

		local searchBox = Instance.new("TextBox")
		searchBox.Size = UDim2.new(1, -12, 0, 28)
		searchBox.Position = UDim2.new(0, 6, 0, isMobile and 26 or 42)
		searchBox.BackgroundColor3 = COLORS.background
		searchBox.BorderColor3 = COLORS.border
		searchBox.BorderSizePixel = 1
		searchBox.PlaceholderText = "Buscar..."
		searchBox.PlaceholderColor3 = COLORS.disabled
		searchBox.Text = ""
		searchBox.TextColor3 = COLORS.text
		searchBox.Font = Enum.Font.Code
		searchBox.TextSize = 13
		searchBox.TextXAlignment = Enum.TextXAlignment.Left
		searchBox.Parent = plPanel
		local plPad = Instance.new("UIPadding", searchBox)
		plPad.PaddingLeft = UDim.new(0, 6)

		PlaylistScroll = Instance.new("ScrollingFrame")
		PlaylistScroll.Name = "PlaylistScroll"
		PlaylistScroll.Size = UDim2.new(1, -12, 1, -78)
		PlaylistScroll.Position = UDim2.new(0, 6, 0, 76)
		PlaylistScroll.BackgroundTransparency = 1
		PlaylistScroll.BorderSizePixel = 0
		PlaylistScroll.ScrollBarThickness = 4
		PlaylistScroll.ScrollBarImageColor3 = COLORS.music
		PlaylistScroll.Parent = plPanel

		local plLayout = Instance.new("UIListLayout", PlaylistScroll)
		plLayout.SortOrder = Enum.SortOrder.LayoutOrder
		plLayout.Padding = UDim.new(0, 5)

		-- ─── COLUNA CENTRAL: PLAYER ───
		local midPanel = makePanel(contentArea, UDim2.new(0.44, -8, 1, 0), UDim2.new(0.28, 4, 0, 0))

		makeHeader(midPanel, "PLAYER", COLORS.header)

		-- Artwork
		local artwork = makePanel(
			midPanel,
			UDim2.new(1, -20, 0, 140),
			UDim2.new(0, 10, 0, 44),
			COLORS.background
		)
		artwork.BorderColor3 = COLORS.music
		artwork.BorderSizePixel = 2

		local artLabel = Instance.new("TextLabel")
		artLabel.Size = UDim2.new(1, 0, 1, 0)
		artLabel.BackgroundTransparency = 1
		artLabel.Text = "♪"
		artLabel.TextColor3 = COLORS.disabled
		artLabel.TextScaled = true
		artLabel.Font = Enum.Font.Arcade
		artLabel.Parent = artwork

		-- Controles de playback
		local ctrlFrame = Instance.new("Frame")
		ctrlFrame.Size = UDim2.new(1, -20, 0, 44)
		ctrlFrame.Position = UDim2.new(0, 10, 0, 194)
		ctrlFrame.BackgroundTransparency = 1
		ctrlFrame.Parent = midPanel

		PlayBtn = makeButton(
			ctrlFrame,
			"▶ PLAY",
			COLORS.music,
			UDim2.new(0.32, -2, 1, 0),
			UDim2.new(0, 0, 0, 0)
		)
		PauseBtn = makeButton(
			ctrlFrame,
			"⏸ PAUSE",
			COLORS.header,
			UDim2.new(0.32, -2, 1, 0),
			UDim2.new(0.34, 0, 0, 0)
		)
		SkipBtn = makeButton(
			ctrlFrame,
			"⏭ SKIP",
			COLORS.header,
			UDim2.new(0.32, -2, 1, 0),
			UDim2.new(0.68, 0, 0, 0)
		)
		PauseBtn.TextColor3 = COLORS.text
		SkipBtn.TextColor3 = COLORS.text

		-- Volume
		local volSep = Instance.new("Frame")
		volSep.Size = UDim2.new(1, -20, 0, 1)
		volSep.Position = UDim2.new(0, 10, 0, 246)
		volSep.BackgroundColor3 = COLORS.header
		volSep.BorderSizePixel = 0
		volSep.Parent = midPanel

		local volLabel = makeLabel(
			midPanel,
			"VOLUME",
			UDim2.new(0, 70, 0, 20),
			UDim2.new(0, 10, 0, 255),
			Enum.Font.Arcade,
			COLORS.textDim
		)
		volLabel.TextSize = 12
		volLabel.TextScaled = false

		VolumeSlider = makePanel(
			midPanel,
			UDim2.new(1, -110, 0, 10),
			UDim2.new(0, 80, 0, 258),
			COLORS.background
		)
		VolumeSlider.Name = "VolumeSlider"
		VolumeSlider.BorderColor3 = COLORS.border
		VolumeSlider.BorderSizePixel = 1

		VolumeFill = Instance.new("Frame")
		VolumeFill.Size = UDim2.new(1, 0, 1, 0)
		VolumeFill.BackgroundColor3 = COLORS.music
		VolumeFill.BorderSizePixel = 0
		VolumeFill.Parent = VolumeSlider

		VolumePercent = Instance.new("TextLabel")
		VolumePercent.Name = "Percent"
		VolumePercent.Size = UDim2.new(0, 40, 0, 20)
		VolumePercent.Position = UDim2.new(1, -50, 0, 255)
		VolumePercent.BackgroundTransparency = 1
		VolumePercent.Text = "100%"
		VolumePercent.TextColor3 = COLORS.music
		VolumePercent.Font = Enum.Font.Arcade
		VolumePercent.TextSize = 13
		VolumePercent.TextXAlignment = Enum.TextXAlignment.Right
		VolumePercent.Parent = midPanel

		-- Speed / Pitch
		local spSep = Instance.new("Frame")
		spSep.Size = UDim2.new(1, -20, 0, 1)
		spSep.Position = UDim2.new(0, 10, 0, 282)
		spSep.BackgroundColor3 = COLORS.header
		spSep.BorderSizePixel = 0
		spSep.Parent = midPanel

		-- Speed control
		local speedPanel = makePanel(
			midPanel,
			UDim2.new(0.47, -4, 0, 60),
			UDim2.new(0, 10, 0, 290),
			COLORS.background
		)
		makeHeader(speedPanel, "SPEED", COLORS.header).Size = UDim2.new(1, 0, 0, 20)

		SpeedValue = Instance.new("TextLabel")
		SpeedValue.Size = UDim2.new(1, 0, 0, 22)
		SpeedValue.Position = UDim2.new(0, 0, 0, 20)
		SpeedValue.BackgroundTransparency = 1
		SpeedValue.Text = "1.00x"
		SpeedValue.TextColor3 = COLORS.music
		SpeedValue.Font = Enum.Font.Arcade
		SpeedValue.TextScaled = true
		SpeedValue.Parent = speedPanel

		SpeedMinus = makeButton(
			speedPanel,
			"-",
			COLORS.header,
			UDim2.new(0.45, 0, 0, 18),
			UDim2.new(0, 4, 1, -22)
		)
		SpeedPlus = makeButton(
			speedPanel,
			"+",
			COLORS.header,
			UDim2.new(0.45, 0, 0, 18),
			UDim2.new(0.55, -4, 1, -22)
		)
		SpeedMinus.TextColor3 = COLORS.text
		SpeedPlus.TextColor3 = COLORS.text

		-- Pitch control
		local pitchPanel = makePanel(
			midPanel,
			UDim2.new(0.47, -4, 0, 60),
			UDim2.new(0.53, -4, 0, 290),
			COLORS.background
		)
		makeHeader(pitchPanel, "PITCH", COLORS.header).Size = UDim2.new(1, 0, 0, 20)

		PitchValue = Instance.new("TextLabel")
		PitchValue.Size = UDim2.new(1, 0, 0, 22)
		PitchValue.Position = UDim2.new(0, 0, 0, 20)
		PitchValue.BackgroundTransparency = 1
		PitchValue.Text = "1.00x"
		PitchValue.TextColor3 = COLORS.music
		PitchValue.Font = Enum.Font.Arcade
		PitchValue.TextScaled = true
		PitchValue.Parent = pitchPanel

		PitchMinus = makeButton(
			pitchPanel,
			"-",
			COLORS.header,
			UDim2.new(0.45, 0, 0, 18),
			UDim2.new(0, 4, 1, -22)
		)
		PitchPlus = makeButton(
			pitchPanel,
			"+",
			COLORS.header,
			UDim2.new(0.45, 0, 0, 18),
			UDim2.new(0.55, -4, 1, -22)
		)
		PitchMinus.TextColor3 = COLORS.text
		PitchPlus.TextColor3 = COLORS.text

		-- FX: Reverb e Bass
		local fxSep = Instance.new("Frame")
		fxSep.Size = UDim2.new(1, -20, 0, 1)
		fxSep.Position = UDim2.new(0, 10, 0, 358)
		fxSep.BackgroundColor3 = COLORS.header
		fxSep.BorderSizePixel = 0
		fxSep.Parent = midPanel

		-- Reverb
		local reverbPanel = makePanel(
			midPanel,
			UDim2.new(0.47, -4, 0, 55),
			UDim2.new(0, 10, 0, 366),
			COLORS.background
		)
		makeHeader(reverbPanel, "REVERB", COLORS.header).Size = UDim2.new(1, 0, 0, 20)

		ReverbToggleBG = Instance.new("Frame")
		ReverbToggleBG.Size = UDim2.new(0, 60, 0, 22)
		ReverbToggleBG.Position = UDim2.new(0.5, -30, 0, 24)
		ReverbToggleBG.BackgroundColor3 = COLORS.background
		ReverbToggleBG.BorderColor3 = COLORS.border
		ReverbToggleBG.BorderSizePixel = 1
		ReverbToggleBG.Parent = reverbPanel

		ReverbToggleBtn = Instance.new("TextButton")
		ReverbToggleBtn.Size = UDim2.new(0, 26, 0, 18)
		ReverbToggleBtn.Position = UDim2.new(0, 2, 0, 2)
		ReverbToggleBtn.BackgroundColor3 = COLORS.disabled
		ReverbToggleBtn.BorderSizePixel = 0
		ReverbToggleBtn.Text = "OFF"
		ReverbToggleBtn.TextColor3 = COLORS.text
		ReverbToggleBtn.Font = Enum.Font.Arcade
		ReverbToggleBtn.TextScaled = true
		ReverbToggleBtn.Parent = ReverbToggleBG

		-- Bass
		local bassPanel = makePanel(
			midPanel,
			UDim2.new(0.47, -4, 0, 55),
			UDim2.new(0.53, -4, 0, 366),
			COLORS.background
		)
		makeHeader(bassPanel, "BASS", COLORS.header).Size = UDim2.new(1, 0, 0, 20)

		BassSlider = makePanel(
			bassPanel,
			UDim2.new(0.75, 0, 0, 8),
			UDim2.new(0.125, 0, 0, 28),
			COLORS.background
		)
		BassSlider.Name = "BassSlider"
		BassSlider.BorderColor3 = COLORS.border
		BassSlider.BorderSizePixel = 1

		BassKnob = Instance.new("TextButton")
		BassKnob.Name = "BassKnob"
		BassKnob.Size = UDim2.new(0, 16, 0, 16)
		BassKnob.Position = UDim2.new(0.5, -8, 0.5, -8)
		BassKnob.BackgroundColor3 = COLORS.music
		BassKnob.BorderColor3 = COLORS.border
		BassKnob.BorderSizePixel = 1
		BassKnob.Text = ""
		BassKnob.Parent = BassSlider

		-- ─── COLUNA DIREITA: QUEUE ───
		local queuePanel =
			makePanel(contentArea, UDim2.new(0.28, -4, 1, 0), UDim2.new(0.72, 4, 0, 0))

		makeHeader(queuePanel, "QUEUE LIST", COLORS.header)

		QueueScroll = Instance.new("ScrollingFrame")
		QueueScroll.Name = "QueueScroll"
		QueueScroll.Size = UDim2.new(1, -12, 1, (isMobile and 36 or 40) * -1 - 6)
		QueueScroll.Position = UDim2.new(0, 6, 0, (isMobile and 36 or 40) + 4)
		QueueScroll.BackgroundTransparency = 1
		QueueScroll.BorderSizePixel = 0
		QueueScroll.ScrollBarThickness = 4
		QueueScroll.ScrollBarImageColor3 = COLORS.music
		QueueScroll.Parent = queuePanel

		local qLayout = Instance.new("UIListLayout", QueueScroll)
		qLayout.SortOrder = Enum.SortOrder.LayoutOrder
		qLayout.Padding = UDim.new(0, 4)

		-- =====================================
		-- LAYOUT MOBILE / TABLET
		-- =====================================
	else
		-- PLAYER
		local playerPanel = makePanel(contentArea, UDim2.new(1, 0, 0, 240), UDim2.new(0, 0, 0, 0))

		makeHeader(playerPanel, "PLAYER", COLORS.header)

		local artwork = makePanel(
			playerPanel,
			UDim2.new(0.85, 0, 0, 100),
			UDim2.new(0.075, 0, 0, isMobile and 30 or 36),
			COLORS.background
		)
		artwork.BorderColor3 = COLORS.music
		artwork.BorderSizePixel = 2

		local artLabel = Instance.new("TextLabel")
		artLabel.Size = UDim2.new(1, 0, 1, 0)
		artLabel.BackgroundTransparency = 1
		artLabel.Text = "♪"
		artLabel.TextColor3 = COLORS.disabled
		artLabel.TextScaled = true
		artLabel.Font = Enum.Font.Arcade
		artLabel.Parent = artwork

		local ctrlFrame = Instance.new("Frame")
		ctrlFrame.Size = UDim2.new(1, -12, 0, 38)
		ctrlFrame.Position = UDim2.new(0, 6, 0, 140)
		ctrlFrame.BackgroundTransparency = 1
		ctrlFrame.Parent = playerPanel

		PlayBtn = makeButton(
			ctrlFrame,
			"▶ PLAY",
			COLORS.music,
			UDim2.new(0.32, -2, 1, 0),
			UDim2.new(0, 0, 0, 0)
		)
		PauseBtn = makeButton(
			ctrlFrame,
			"⏸",
			COLORS.header,
			UDim2.new(0.32, -2, 1, 0),
			UDim2.new(0.34, 0, 0, 0)
		)
		SkipBtn = makeButton(
			ctrlFrame,
			"⏭ SKIP",
			COLORS.header,
			UDim2.new(0.32, -2, 1, 0),
			UDim2.new(0.68, 0, 0, 0)
		)
		PauseBtn.TextColor3 = COLORS.text
		SkipBtn.TextColor3 = COLORS.text

		-- Volume
		local volFrame = Instance.new("Frame")
		volFrame.Size = UDim2.new(1, -12, 0, 24)
		volFrame.Position = UDim2.new(0, 6, 0, 186)
		volFrame.BackgroundTransparency = 1
		volFrame.Parent = playerPanel

		local volLabel = makeLabel(
			volFrame,
			"VOL",
			UDim2.new(0, 38, 1, 0),
			UDim2.new(0, 0, 0, 0),
			Enum.Font.Arcade,
			COLORS.textDim
		)
		volLabel.TextSize = 11

		VolumeSlider = makePanel(
			volFrame,
			UDim2.new(1, -84, 0, 8),
			UDim2.new(0, 40, 0.5, -4),
			COLORS.background
		)
		VolumeSlider.Name = "VolumeSlider"
		VolumeSlider.BorderColor3 = COLORS.border
		VolumeSlider.BorderSizePixel = 1

		VolumeFill = Instance.new("Frame")
		VolumeFill.Size = UDim2.new(1, 0, 1, 0)
		VolumeFill.BackgroundColor3 = COLORS.music
		VolumeFill.BorderSizePixel = 0
		VolumeFill.Parent = VolumeSlider

		VolumePercent = Instance.new("TextLabel")
		VolumePercent.Name = "Percent"
		VolumePercent.Size = UDim2.new(0, 42, 1, 0)
		VolumePercent.Position = UDim2.new(1, -42, 0, 0)
		VolumePercent.BackgroundTransparency = 1
		VolumePercent.Text = "100%"
		VolumePercent.TextColor3 = COLORS.music
		VolumePercent.Font = Enum.Font.Arcade
		VolumePercent.TextSize = 12
		VolumePercent.TextXAlignment = Enum.TextXAlignment.Right
		VolumePercent.Parent = volFrame

		-- Speed / Pitch row
		local spRow = Instance.new("Frame")
		spRow.Size = UDim2.new(1, -12, 0, 54)
		spRow.Position = UDim2.new(0, 6, 0, 214)
		spRow.BackgroundTransparency = 1
		spRow.Parent = playerPanel

		local speedF =
			makePanel(spRow, UDim2.new(0.48, -2, 1, 0), UDim2.new(0, 0, 0, 0), COLORS.background)
		makeHeader(speedF, "SPEED", COLORS.header).Size = UDim2.new(1, 0, 0, 18)
		SpeedValue = Instance.new("TextLabel")
		SpeedValue.Size = UDim2.new(1, 0, 0, 18)
		SpeedValue.Position = UDim2.new(0, 0, 0, 18)
		SpeedValue.BackgroundTransparency = 1
		SpeedValue.Text = "1.00x"
		SpeedValue.TextColor3 = COLORS.music
		SpeedValue.Font = Enum.Font.Arcade
		SpeedValue.TextScaled = true
		SpeedValue.Parent = speedF
		SpeedMinus = makeButton(
			speedF,
			"-",
			COLORS.header,
			UDim2.new(0.45, 0, 0, 16),
			UDim2.new(0, 3, 1, -20)
		)
		SpeedPlus = makeButton(
			speedF,
			"+",
			COLORS.header,
			UDim2.new(0.45, 0, 0, 16),
			UDim2.new(0.55, -3, 1, -20)
		)
		SpeedMinus.TextColor3 = COLORS.text
		SpeedPlus.TextColor3 = COLORS.text

		local pitchF =
			makePanel(spRow, UDim2.new(0.48, -2, 1, 0), UDim2.new(0.52, 2, 0, 0), COLORS.background)
		makeHeader(pitchF, "PITCH", COLORS.header).Size = UDim2.new(1, 0, 0, 18)
		PitchValue = Instance.new("TextLabel")
		PitchValue.Size = UDim2.new(1, 0, 0, 18)
		PitchValue.Position = UDim2.new(0, 0, 0, 18)
		PitchValue.BackgroundTransparency = 1
		PitchValue.Text = "1.00x"
		PitchValue.TextColor3 = COLORS.music
		PitchValue.Font = Enum.Font.Arcade
		PitchValue.TextScaled = true
		PitchValue.Parent = pitchF
		PitchMinus = makeButton(
			pitchF,
			"-",
			COLORS.header,
			UDim2.new(0.45, 0, 0, 16),
			UDim2.new(0, 3, 1, -20)
		)
		PitchPlus = makeButton(
			pitchF,
			"+",
			COLORS.header,
			UDim2.new(0.45, 0, 0, 16),
			UDim2.new(0.55, -3, 1, -20)
		)
		PitchMinus.TextColor3 = COLORS.text
		PitchPlus.TextColor3 = COLORS.text

		-- FX Row
		local fxRow = Instance.new("Frame")
		fxRow.Size = UDim2.new(1, 0, 0, 52)
		fxRow.Position = UDim2.new(0, 0, 0, 276)
		fxRow.BackgroundTransparency = 1
		fxRow.Parent = contentArea

		local reverbF =
			makePanel(fxRow, UDim2.new(0.48, -2, 1, 0), UDim2.new(0, 0, 0, 0), COLORS.background)
		makeHeader(reverbF, "REVERB", COLORS.header).Size = UDim2.new(1, 0, 0, 18)

		ReverbToggleBG = Instance.new("Frame")
		ReverbToggleBG.Size = UDim2.new(0, 58, 0, 20)
		ReverbToggleBG.Position = UDim2.new(0.5, -29, 0, 22)
		ReverbToggleBG.BackgroundColor3 = COLORS.background
		ReverbToggleBG.BorderColor3 = COLORS.border
		ReverbToggleBG.BorderSizePixel = 1
		ReverbToggleBG.Parent = reverbF

		ReverbToggleBtn = Instance.new("TextButton")
		ReverbToggleBtn.Size = UDim2.new(0, 26, 0, 16)
		ReverbToggleBtn.Position = UDim2.new(0, 1, 0, 2)
		ReverbToggleBtn.BackgroundColor3 = COLORS.disabled
		ReverbToggleBtn.BorderSizePixel = 0
		ReverbToggleBtn.Text = "OFF"
		ReverbToggleBtn.TextColor3 = COLORS.text
		ReverbToggleBtn.Font = Enum.Font.Arcade
		ReverbToggleBtn.TextScaled = true
		ReverbToggleBtn.Parent = ReverbToggleBG

		local bassF =
			makePanel(fxRow, UDim2.new(0.48, -2, 1, 0), UDim2.new(0.52, 2, 0, 0), COLORS.background)
		makeHeader(bassF, "BASS", COLORS.header).Size = UDim2.new(1, 0, 0, 18)

		BassSlider = makePanel(
			bassF,
			UDim2.new(0.75, 0, 0, 8),
			UDim2.new(0.125, 0, 0, 26),
			COLORS.background
		)
		BassSlider.Name = "BassSlider"
		BassSlider.BorderColor3 = COLORS.border
		BassSlider.BorderSizePixel = 1

		BassKnob = Instance.new("TextButton")
		BassKnob.Name = "BassKnob"
		BassKnob.Size = UDim2.new(0, 14, 0, 14)
		BassKnob.Position = UDim2.new(0.5, -7, 0.5, -7)
		BassKnob.BackgroundColor3 = COLORS.music
		BassKnob.BorderColor3 = COLORS.border
		BassKnob.BorderSizePixel = 1
		BassKnob.Text = ""
		BassKnob.Parent = BassSlider

		-- PLAYLIST
		local plPanel = makePanel(contentArea, UDim2.new(1, 0, 0, 200), UDim2.new(0, 0, 0, 336))

		makeHeader(plPanel, "PLAYLIST", COLORS.header)

		local searchBox = Instance.new("TextBox")
		searchBox.Size = UDim2.new(1, -12, 0, 24)
		searchBox.Position = UDim2.new(0, 6, 0, (isMobile and 36 or 40) + 4)
		searchBox.BackgroundColor3 = COLORS.background
		searchBox.BorderColor3 = COLORS.border
		searchBox.BorderSizePixel = 1
		searchBox.PlaceholderText = "Buscar..."
		searchBox.PlaceholderColor3 = COLORS.disabled
		searchBox.Text = ""
		searchBox.TextColor3 = COLORS.text
		searchBox.Font = Enum.Font.Code
		searchBox.TextSize = 12
		searchBox.TextXAlignment = Enum.TextXAlignment.Left
		searchBox.Parent = plPanel
		local plPad = Instance.new("UIPadding", searchBox)
		plPad.PaddingLeft = UDim.new(0, 6)

		PlaylistScroll = Instance.new("ScrollingFrame")
		PlaylistScroll.Name = "PlaylistScroll"
		PlaylistScroll.Size = UDim2.new(1, -12, 1, -70)
		PlaylistScroll.Position = UDim2.new(0, 6, 0, 68)
		PlaylistScroll.BackgroundTransparency = 1
		PlaylistScroll.BorderSizePixel = 0
		PlaylistScroll.ScrollBarThickness = 4
		PlaylistScroll.ScrollBarImageColor3 = COLORS.music
		PlaylistScroll.Parent = plPanel

		local plLayout = Instance.new("UIListLayout", PlaylistScroll)
		plLayout.SortOrder = Enum.SortOrder.LayoutOrder
		plLayout.Padding = UDim.new(0, 4)

		-- QUEUE
		local qPanel = makePanel(contentArea, UDim2.new(1, 0, 0, 240), UDim2.new(0, 0, 0, 544))

		makeHeader(qPanel, "QUEUE LIST", COLORS.header)

		QueueScroll = Instance.new("ScrollingFrame")
		QueueScroll.Name = "QueueScroll"
		QueueScroll.Size = UDim2.new(1, -12, 1, (isMobile and 36 or 40) * -1 - 6)
		QueueScroll.Position = UDim2.new(0, 6, 0, (isMobile and 36 or 40) + 4)
		QueueScroll.BackgroundTransparency = 1
		QueueScroll.BorderSizePixel = 0
		QueueScroll.ScrollBarThickness = 4
		QueueScroll.ScrollBarImageColor3 = COLORS.music
		QueueScroll.Parent = qPanel

		local qLayout = Instance.new("UIListLayout", QueueScroll)
		qLayout.SortOrder = Enum.SortOrder.LayoutOrder
		qLayout.Padding = UDim.new(0, 4)

		contentArea.CanvasSize = UDim2.new(0, 0, 0, 792)
	end

	-- =====================================
	-- EVENTOS DO BOTÃO PRINCIPAL
	-- =====================================

	-- Abertura/fechamento pelo MENU UNIFICADO (sem botão flutuante próprio)
	local function openWindow()
		if isMenuOpen then
			return
		end
		playSound(sounds.open)
		isMenuOpen = true
		background.Visible = true
		mainWindow.Visible = true
		mainWindow.Position = UDim2.new(0.5, 0, 0.6, 0)
		TweenService:Create(
			mainWindow,
			TweenInfo.new(0.25, Enum.EasingStyle.Back),
			{ Position = UDim2.new(0.5, 0, 0.5, 0) }
		):Play()
	end

	local function closeWindow()
		if not isMenuOpen then
			return
		end
		playSound(sounds.close)
		isMenuOpen = false
		background.Visible = false
		TweenService:Create(
			mainWindow,
			TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{ Position = UDim2.new(0.5, 0, 0.6, 0) }
		):Play()
		task.delay(0.2, function()
			if not isMenuOpen then
				mainWindow.Visible = false
			end
		end)
	end

	_G.OpenMusicPlayer = openWindow
	_G.CloseMusicPlayer = closeWindow

	closeBtn.Activated:Connect(closeWindow)

	background.InputBegan:Connect(function(input)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			-- corrige bug: RBXScriptSignal não tem :Fire()
			closeWindow()
		end
	end)

	return mainWindow
end

-- =====================================
-- LÓGICA DO PLAYER
-- =====================================

local function GetSoundCount()
	local n = 0
	for _, v in pairs(Holder:GetChildren()) do
		if v:IsA("Sound") then
			n += 1
		end
	end
	return n
end

local function AssignNumbers()
	local list = {}
	for _, v in pairs(Holder:GetChildren()) do
		if v:IsA("Sound") then
			table.insert(list, v)
		end
	end
	for i, v in ipairs(list) do
		if not v:FindFirstChild("Number") then
			local n = Instance.new("IntValue", v)
			n.Name = "Number"
			n.Value = i
		end
		if not v:FindFirstChild("BaseVolume") then
			local bv = Instance.new("NumberValue", v)
			bv.Name = "BaseVolume"
			bv.Value = math.max(v.Volume, 0.5)
		end
	end
end

-- (V5) Seleção SEQUENCIAL de faixa (regra do projeto: sem Randomize)
local sequentialPick = 0
local function ReturnSequential()
	local list = {}
	for _, v in pairs(Holder:GetChildren()) do
		if v:IsA("Sound") then
			table.insert(list, v)
		end
	end
	if #list == 0 then
		return nil
	end
	sequentialPick = (sequentialPick % #list) + 1
	return list[sequentialPick]
end

local function ReturnNext()
	if not CurrentSong then
		return ReturnSequential()
	end
	local cur = CurrentSong:FindFirstChild("Number") and CurrentSong.Number.Value or 1
	local nxt = cur + 1
	local cnt = GetSoundCount()
	if nxt > cnt then
		nxt = 1
	end
	for _, v in pairs(Holder:GetChildren()) do
		if v:IsA("Sound") and v:FindFirstChild("Number") and v.Number.Value == nxt then
			return v
		end
	end
	return ReturnSequential()
end

local function FadeStop(sound, pause)
	if not sound then
		return
	end

	-- (V6) a sonda de grave morre junto com a faixa
	PararSonda()

	local tw = TweenService:Create(sound, TweenInfo.new(0.6), { Volume = 0 })
	tw.Completed:Connect(function()
		if pause then
			sound:Pause()
		else
			sound:Stop()
		end
	end)
	tw:Play()
end

-- =====================================
-- (V6) LAÇO DO VISUALIZER
-- =====================================
-- Um laço só, ligado o tempo todo. Ele sai cedo quando a janela está
-- fechada, então não custa nada com o menu escondido.
task.spawn(function()
	local semSonda = 0

	VisualizerConn = RunService.RenderStepped:Connect(function()
		if not isMenuOpen or #VisualizerBarras == 0 then
			return
		end

		local tocando = CurrentSong and CurrentSong.IsPlaying

		-- Nível bruto: sonda de grave, com o nível geral como reserva
		local nivel = 0
		if tocando then
			if VisualizerSonda and VisualizerSonda.IsPlaying then
				nivel = VisualizerSonda.PlaybackLoudness

				-- A sonda muda ficou muda de verdade nesta versão do
				-- motor: cai para o nível geral em vez de travar em zero.
				if nivel <= 0 then
					semSonda = semSonda + 1
					if semSonda > 60 then
						nivel = CurrentSong.PlaybackLoudness * 0.6
					end
				else
					semSonda = 0
				end
			else
				nivel = CurrentSong.PlaybackLoudness * 0.6
			end
		end

		-- PlaybackLoudness vai de 0 a 1000
		local alvo = math.clamp(nivel / 420, 0, 1)

		local meio = (#VisualizerBarras + 1) / 2
		for i, barra in ipairs(VisualizerBarras) do
			-- Barras do centro respondem mais: grave no meio, corpo nas
			-- pontas. Sem FFT, o formato é o que dá a leitura de "grave".
			local distancia = math.abs(i - meio) / meio
			local peso = 1 - (distancia * 0.65)
			local alvoBarra = alvo * peso

			local atual = VisualizerNiveis[i] or 0
			local taxa = alvoBarra > atual and VIS_SUAVIZA_SUBIDA or VIS_SUAVIZA_DESCIDA
			atual = atual + (alvoBarra - atual) * taxa
			VisualizerNiveis[i] = atual

			barra.Size = UDim2.new(barra.Size.X.Scale, 0, math.max(atual, 0.04), 0)

			-- Estoura para a cor de destaque no pico
			barra.BackgroundColor3 = atual > 0.72 and COLORS.progress or COLORS.music
		end
	end)
end)

local function PlaySong(sound)
	if not sound then
		return
	end
	if SoundEndConn then
		SoundEndConn:Disconnect()
		SoundEndConn = nil
	end

	local waited = 0
	while waited < 8 do
		if sound.TimeLength > 0.1 then
			break
		end
		task.wait(1)
		waited += 1
	end

	if sound.TimeLength <= 0.1 then
		warn("[MUSIC V5] " .. sound.Name .. " não carregou, pulando...")
		CurrentSong = ReturnNext()
		PlaySong(CurrentSong)
		return
	end

	local totalTime = math.floor(sound.TimeLength + 0.5)

	if MusicName then
		MusicName.Text = sound.Name
	end
	if SoundID then
		SoundID.Text = "ID: " .. (sound.SoundId:match("%d+") or "???")
	end

	SoundEndConn = RunService.RenderStepped:Connect(function()
		if SongStatus ~= "Playing" then
			return
		end
		local elapsed = math.floor(sound.TimePosition + 0.5)
		local timeLeft = totalTime - elapsed

		if TimerLabel then
			TimerLabel.Text = string.format(
				"%i:%02i / %i:%02i",
				elapsed / 60,
				elapsed % 60,
				totalTime / 60,
				totalTime % 60
			)
		end

		if ProgressFill then
			local pct = math.clamp(elapsed / math.max(totalTime, 1), 0, 1)
			TweenService
				:Create(ProgressFill, TweenInfo.new(0.1), { Size = UDim2.new(pct, 0, 1, 0) })
				:Play()
		end

		if timeLeft <= 0 and elapsed > 0 then
			SoundEndConn:Disconnect()
			SoundEndConn = nil
			CurrentSong = ReturnNext()
			PlaySong(CurrentSong)
		end
	end)

	if SongStatus == "Paused" then
		sound:Resume()
	else
		sound:Play()
	end

	sound.Volume = 0
	local base = sound:FindFirstChild("BaseVolume") and sound.BaseVolume.Value or 0.5
	TweenService:Create(sound, TweenInfo.new(0.8), { Volume = base * PlayerVolume }):Play()

	-- (V6) sonda de grave acompanha a faixa que acabou de entrar
	PrepararSonda(sound)

	notify("♪ " .. sound.Name, true)
end

-- =====================================
-- PLAYLIST ITEMS
-- =====================================

local function CreatePlaylistItem(name, songCount, color)
	if not PlaylistScroll then
		return
	end

	local item = Instance.new("TextButton")
	item.Size = UDim2.new(1, 0, 0, isMobile and 44 or 52)
	item.BackgroundColor3 = COLORS.panel
	item.BorderColor3 = color
	item.BorderSizePixel = 2
	item.Text = ""
	item.AutoButtonColor = false
	item.Parent = PlaylistScroll

	-- Faixa colorida lateral
	local bar = Instance.new("Frame", item)
	bar.Size = UDim2.new(0, 4, 1, 0)
	bar.BackgroundColor3 = color
	bar.BorderSizePixel = 0

	local nameL = Instance.new("TextLabel", item)
	nameL.Size = UDim2.new(1, -80, 0, isMobile and 18 or 22)
	nameL.Position = UDim2.new(0, 12, 0, isMobile and 6 or 8)
	nameL.BackgroundTransparency = 1
	nameL.Text = name
	nameL.TextColor3 = COLORS.text
	nameL.Font = Enum.Font.Arcade
	nameL.TextSize = isMobile and 11 or 13
	nameL.TextXAlignment = Enum.TextXAlignment.Left
	nameL.TextTruncate = Enum.TextTruncate.AtEnd

	local countL = Instance.new("TextLabel", item)
	countL.Size = UDim2.new(1, -80, 0, isMobile and 14 or 16)
	countL.Position = UDim2.new(0, 12, 0, isMobile and 26 or 30)
	countL.BackgroundTransparency = 1
	countL.Text = tostring(songCount) .. " faixas"
	countL.TextColor3 = COLORS.textDim
	countL.Font = Enum.Font.Code
	countL.TextSize = isMobile and 11 or 12
	countL.TextXAlignment = Enum.TextXAlignment.Left

	if not isMobile then
		item.MouseEnter:Connect(function()
			TweenService:Create(item, TweenInfo.new(0.1), { BackgroundColor3 = COLORS.header })
				:Play()
		end)
		item.MouseLeave:Connect(function()
			TweenService:Create(item, TweenInfo.new(0.1), { BackgroundColor3 = COLORS.panel })
				:Play()
		end)
	end
end

-- =====================================
-- QUEUE LIST
-- =====================================

local function UpdateQueue()
	if not QueueScroll then
		return
	end
	for _, c in pairs(QueueScroll:GetChildren()) do
		if not c:IsA("UIListLayout") then
			c.Parent = nil
		end
	end

	local list = {}
	for _, v in pairs(Holder:GetChildren()) do
		if v:IsA("Sound") then
			table.insert(list, v)
		end
	end
	table.sort(list, function(a, b)
		return (a:FindFirstChild("Number") and a.Number.Value or 0)
			< (b:FindFirstChild("Number") and b.Number.Value or 0)
	end)

	for i, sound in ipairs(list) do
		local isPlaying = (sound == CurrentSong)

		local item = Instance.new("Frame")
		item.Size = UDim2.new(1, 0, 0, isMobile and 40 or 46)
		item.BackgroundColor3 = isPlaying and COLORS.music or COLORS.panel
		item.BorderColor3 = isPlaying and COLORS.music or COLORS.header
		item.BorderSizePixel = isPlaying and 2 or 1
		item.Parent = QueueScroll

		local numL = Instance.new("TextLabel", item)
		numL.Size = UDim2.new(0, 22, 1, 0)
		numL.Position = UDim2.new(0, 5, 0, 0)
		numL.BackgroundTransparency = 1
		numL.Text = isPlaying and "►" or tostring(i)
		numL.TextColor3 = isPlaying and COLORS.background or COLORS.disabled
		numL.Font = Enum.Font.Arcade
		numL.TextScaled = true

		local nameL = Instance.new("TextLabel", item)
		nameL.Size = UDim2.new(1, -(isMobile and 75 or 85), 0, isMobile and 18 or 22)
		nameL.Position = UDim2.new(0, 32, 0, isMobile and 4 or 6)
		nameL.BackgroundTransparency = 1
		nameL.Text = sound.Name
		nameL.TextColor3 = isPlaying and COLORS.background or COLORS.text
		nameL.Font = Enum.Font.Arcade
		nameL.TextSize = isMobile and 12 or 13
		nameL.TextXAlignment = Enum.TextXAlignment.Left
		nameL.TextTruncate = Enum.TextTruncate.AtEnd

		local dur = math.floor(sound.TimeLength + 0.5)
		local timeL = Instance.new("TextLabel", item)
		timeL.Size = UDim2.new(1, -(isMobile and 75 or 85), 0, isMobile and 14 or 16)
		timeL.Position = UDim2.new(0, 32, 0, isMobile and 24 or 28)
		timeL.BackgroundTransparency = 1
		timeL.Text = string.format("%i:%02i", dur / 60, dur % 60)
		timeL.TextColor3 = isPlaying and COLORS.background or COLORS.textDim
		timeL.Font = Enum.Font.Code
		timeL.TextSize = isMobile and 11 or 12
		timeL.TextXAlignment = Enum.TextXAlignment.Left

		local clickBtn = Instance.new("TextButton", item)
		clickBtn.Size = UDim2.new(1, 0, 1, 0)
		clickBtn.BackgroundTransparency = 1
		clickBtn.Text = ""
		clickBtn.Activated:Connect(function()
			if Debounce then
				return
			end
			Debounce = true
			FadeStop(CurrentSong, false)
			CurrentSong = sound
			SongStatus = "Playing"
			PlaySong(CurrentSong)
			UpdateQueue()
			task.wait(0.3)
			Debounce = false
		end)
	end

	local lay = QueueScroll:FindFirstChildOfClass("UIListLayout")
	if lay then
		QueueScroll.CanvasSize = UDim2.new(0, 0, 0, lay.AbsoluteContentSize.Y + 10)
	end
end

-- =====================================
-- INICIALIZAR INTERFACE
-- =====================================

createMusicInterface()
AssignNumbers()

-- Preencher playlist
local soundCount = GetSoundCount()
CreatePlaylistItem("TODAS AS FAIXAS", soundCount, COLORS.music)
CreatePlaylistItem("OPM FAVORITES", 0, Color3.fromRGB(147, 51, 234))
CreatePlaylistItem("BUDOTS REMIX", 2, Color3.fromRGB(251, 146, 60))
CreatePlaylistItem("GENGGENG", 1, Color3.fromRGB(6, 182, 212))
CreatePlaylistItem("KOREAN HITS", 3, Color3.fromRGB(239, 68, 68))

if PlaylistScroll then
	local lay = PlaylistScroll:FindFirstChildOfClass("UIListLayout")
	if lay then
		PlaylistScroll.CanvasSize = UDim2.new(0, 0, 0, lay.AbsoluteContentSize.Y + 10)
		lay:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
			PlaylistScroll.CanvasSize = UDim2.new(0, 0, 0, lay.AbsoluteContentSize.Y + 10)
		end)
	end
end

-- Iniciar player
if GetSoundCount() > 0 then
	CurrentSong = ReturnSequential()
	if CurrentSong then
		PlaySong(CurrentSong)
	end
end

UpdateQueue()

-- Monitorar troca de música
local LastTracked = CurrentSong
RunService.Heartbeat:Connect(function()
	if CurrentSong ~= LastTracked then
		LastTracked = CurrentSong
		UpdateQueue()
	end
end)

-- =====================================
-- CONECTAR BOTÕES DE PLAYBACK
-- =====================================

if PlayBtn then
	PlayBtn.Activated:Connect(function()
		if Debounce then
			return
		end
		Debounce = true
		playSound(sounds.click)
		if SongStatus == "Paused" and CurrentSong then
			SongStatus = "Playing"
			PlaySong(CurrentSong)
		elseif not CurrentSong then
			CurrentSong = ReturnSequential()
			SongStatus = "Playing"
			if CurrentSong then
				PlaySong(CurrentSong)
			end
		end
		task.wait(0.3)
		Debounce = false
	end)
end

if PauseBtn then
	PauseBtn.Activated:Connect(function()
		if Debounce then
			return
		end
		Debounce = true
		playSound(sounds.click)
		if SongStatus == "Playing" then
			SongStatus = "Paused"
			FadeStop(CurrentSong, true)
		end
		task.wait(0.3)
		Debounce = false
	end)
end

if SkipBtn then
	SkipBtn.Activated:Connect(function()
		if Debounce then
			return
		end
		Debounce = true
		playSound(sounds.click)
		FadeStop(CurrentSong, false)
		SongStatus = "Playing"
		CurrentSong = ReturnNext()
		if CurrentSong then
			PlaySong(CurrentSong)
		end
		task.wait(0.3)
		Debounce = false
	end)
end

-- =====================================
-- CONTROLES DE ÁUDIO
-- =====================================

-- Speed
if SpeedMinus then
	SpeedMinus.Activated:Connect(function()
		CurrentSpeed = math.max(math.round((CurrentSpeed - 0.25) * 100) / 100, 0.25)
		if CurrentSong then
			CurrentSong.PlaybackSpeed = CurrentSpeed
		end
		if SpeedValue then
			SpeedValue.Text = string.format("%.2fx", CurrentSpeed)
		end
	end)
end
if SpeedPlus then
	SpeedPlus.Activated:Connect(function()
		CurrentSpeed = math.min(math.round((CurrentSpeed + 0.25) * 100) / 100, 3.0)
		if CurrentSong then
			CurrentSong.PlaybackSpeed = CurrentSpeed
		end
		if SpeedValue then
			SpeedValue.Text = string.format("%.2fx", CurrentSpeed)
		end
	end)
end

-- Pitch
local function EnsurePitch()
	if CurrentSong then
		if not PitchEffect or not PitchEffect.Parent then
			PitchEffect = Instance.new("PitchShiftSoundEffect", CurrentSong)
			PitchEffect.Octave = CurrentPitch
		end
	end
end

if PitchMinus then
	PitchMinus.Activated:Connect(function()
		CurrentPitch = math.max(math.round((CurrentPitch - 0.25) * 100) / 100, 0.5)
		EnsurePitch()
		if PitchEffect then
			PitchEffect.Octave = CurrentPitch
		end
		if PitchValue then
			PitchValue.Text = string.format("%.2fx", CurrentPitch)
		end
	end)
end
if PitchPlus then
	PitchPlus.Activated:Connect(function()
		CurrentPitch = math.min(math.round((CurrentPitch + 0.25) * 100) / 100, 2.0)
		EnsurePitch()
		if PitchEffect then
			PitchEffect.Octave = CurrentPitch
		end
		if PitchValue then
			PitchValue.Text = string.format("%.2fx", CurrentPitch)
		end
	end)
end

-- Reverb
if ReverbToggleBtn and ReverbToggleBG then
	ReverbToggleBtn.Activated:Connect(function()
		playSound(sounds.click)
		ReverbEnabled = not ReverbEnabled
		if ReverbEnabled then
			TweenService
				:Create(ReverbToggleBG, TweenInfo.new(0.15), { BackgroundColor3 = COLORS.music })
				:Play()
			TweenService:Create(ReverbToggleBtn, TweenInfo.new(0.15), {
				Position = UDim2.new(1, -(ReverbToggleBtn.Size.X.Offset + 2), 0, 2),
				BackgroundColor3 = COLORS.background,
			}):Play()
			ReverbToggleBtn.Text = "ON"
			if CurrentSong and (not ReverbEffect or not ReverbEffect.Parent) then
				ReverbEffect = Instance.new("ReverbSoundEffect", CurrentSong)
				ReverbEffect.DryLevel = -6
				ReverbEffect.WetLevel = 0
			end
		else
			TweenService
				:Create(
					ReverbToggleBG,
					TweenInfo.new(0.15),
					{ BackgroundColor3 = COLORS.background }
				)
				:Play()
			TweenService:Create(
				ReverbToggleBtn,
				TweenInfo.new(0.15),
				{ Position = UDim2.new(0, 1, 0, 2), BackgroundColor3 = COLORS.disabled }
			):Play()
			ReverbToggleBtn.Text = "OFF"
			if ReverbEffect and ReverbEffect.Parent then
				ReverbEffect.Parent = nil
				ReverbEffect = nil
			end
		end
	end)
end

-- Bass (drag)
local DraggingBass = false
if BassKnob and BassSlider then
	BassKnob.MouseButton1Down:Connect(function()
		DraggingBass = true
	end)
	if isMobile then
		BassKnob.TouchTap:Connect(function()
			DraggingBass = true
		end)
	end

	UserInputService.InputEnded:Connect(function(input)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			DraggingBass = false
		end
	end)

	UserInputService.InputChanged:Connect(function(input)
		if not DraggingBass then
			return
		end
		if
			input.UserInputType ~= Enum.UserInputType.MouseMovement
			and input.UserInputType ~= Enum.UserInputType.Touch
		then
			return
		end
		local posX = UserInputService:GetMouseLocation().X
		local sPos = BassSlider.AbsolutePosition.X
		local sSize = BassSlider.AbsoluteSize.X
		local pct = math.clamp((posX - sPos) / sSize, 0, 1)
		TweenService:Create(BassKnob, TweenInfo.new(0.05), {
			Position = UDim2.new(
				pct,
				-BassKnob.Size.X.Offset / 2,
				0.5,
				-BassKnob.Size.Y.Offset / 2
			),
		}):Play()
		if CurrentSong then
			if not BassEffect or not BassEffect.Parent then
				BassEffect = Instance.new("EqualizerSoundEffect", CurrentSong)
			end
			BassEffect.LowGain = -20 + (pct * 40)
		end
	end)
end

-- Volume (click + drag)
local DraggingVol = false
local function UpdateVolume(posX)
	if not VolumeSlider or not VolumeFill or not VolumePercent then
		return
	end
	local pct =
		math.clamp((posX - VolumeSlider.AbsolutePosition.X) / VolumeSlider.AbsoluteSize.X, 0, 1)
	PlayerVolume = pct
	TweenService:Create(VolumeFill, TweenInfo.new(0.1), { Size = UDim2.new(pct, 0, 1, 0) }):Play()
	VolumePercent.Text = math.floor(pct * 100) .. "%"
	if CurrentSong then
		local base = CurrentSong:FindFirstChild("BaseVolume") and CurrentSong.BaseVolume.Value
			or 0.5
		CurrentSong.Volume = pct * base
	end
end

if VolumeSlider then
	VolumeSlider.InputBegan:Connect(function(input)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			DraggingVol = true
			UpdateVolume(input.Position.X)
		end
	end)
	VolumeSlider.InputEnded:Connect(function(input)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			DraggingVol = false
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if not DraggingVol then
			return
		end
		if
			input.UserInputType == Enum.UserInputType.MouseMovement
			or input.UserInputType == Enum.UserInputType.Touch
		then
			UpdateVolume(input.Position.X)
		end
	end)
end

-- =====================================
-- LOG
-- =====================================

print(
	[[
╔══════════════════════════════════════════╗
║   MUSIC PLAYER V3 CARREGADO             ║
╠══════════════════════════════════════════╣
║  Estilo: Padrão do Projeto              ║
║  Botão:  Retangular | Y=0.94 (< TUTOR) ║
╚══════════════════════════════════════════╝]]
)
print("  Plataforma: " .. (isMobile and (isTablet and "Tablet" or "Mobile") or "PC"))
print("  Músicas detectadas: " .. GetSoundCount())
