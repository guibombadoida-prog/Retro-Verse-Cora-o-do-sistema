-- ============================================
-- CHARACTER STATS ADMIN CLIENT V2 — EDIÇÃO EM JOGO
-- Coloque em StarterPlayer > StarterPlayerScripts
-- Nome: "CharacterStatsAdminClient"
-- DEPENDE DE: CharacterStatsServer V2, AdminRegistryServer V1,
--             CharacterCatalogServer V6, UnifiedMenuClient V3
-- SUBSTITUI: CharacterStatsAdminClient V1
-- REMOVER:   CharacterStatsAdminClient V1
-- ============================================
-- (V2) CORREÇÃO:
-- No V1 o botão SALVAR não dava nenhum sinal de que estava
-- trabalhando, e não travava. Resultado no seu log: cinco
-- 'Dark Jc agora é Lutador' em dois segundos, com aviso de fila do
-- DataStore. Você tocou várias vezes porque a tela não respondia —
-- e cada toque virou uma gravação.
-- Agora o botão trava, escreve "SALVANDO...", e só volta quando o
-- servidor responde. Um toque = uma gravação.
-- ============================================
-- O QUE FALTAVA:
-- O CharacterStatsServer V1 já tinha os remotes de admin, o
-- DataStore e a sincronização entre servidores — mas não tinha TELA.
-- Sem tela, o único jeito de configurar era digitar
-- `_G.CharacterStats.set(...)` no console, o que quebra a regra do
-- projeto: TUDO que envolve personagem se edita EM JOGO, pelo
-- painel, sem reabrir o Studio.
-- E como nenhum personagem estava configurado, o popup de
-- habilidades não tinha atributo nenhum pra mostrar. Os dois
-- problemas eram o mesmo problema.
--
-- ============================================
-- POR QUE É UM SCRIPT SEPARADO
-- ============================================
-- O AdminMenuClient V9 tem 1697 linhas e já cuida de moedas,
-- bounty, catálogo, despertar, registro de admin e teleporte.
-- Enfiar mais uma aba lá dentro significa arriscar tudo isso.
-- Este script aparece como uma categoria PRÓPRIA no mesmo menu ☰,
-- só pra quem é admin — mesmo padrão que o AdminMenuClient usa pra
-- se registrar.
-- ⚠️ AdminMenuClient V9 e CharacterCatalogServer V6: INTOCADOS.
--
-- REUTILIZAÇÃO (nada criado do zero):
-- • checkIsAdmin + re-checagem a cada 30s ... AdminMenuClient V9
-- • AdminCatalogListCharacters (lista real do catálogo) ...
--   CharacterCatalogServer V6 — o admin escolhe da MESMA lista que
--   já usa pra editar personagem, não digita nome na mão
-- • _G.RegisterMenuCategory .................. UnifiedMenuClient V3
-- • Estrutura de popup, cores e sons ......... CharacterSystemClient V6
-- ============================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local SoundService = game:GetService("SoundService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- =====================================
-- CHECAGEM DE ADMIN (padrão do AdminMenuClient V9)
-- =====================================
-- Isto só controla a EXIBIÇÃO. O servidor revalida cada ação de
-- qualquer jeito — quem não é admin não consegue salvar nada, mesmo
-- forçando o remote.

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local isAdminCheck = remotes:WaitForChild("IsAdminCheck", 30)

if not isAdminCheck then
	warn("[STATS ADMIN V2] IsAdminCheck não encontrado — AdminRegistryServer V1 está instalado?")
	return
end

local function checkIsAdmin()
	local ok, result = pcall(function()
		return isAdminCheck:InvokeServer()
	end)
	return ok and result == true
end

-- =====================================
-- REMOTES
-- =====================================

local getCharacterStatsInfo = remotes:WaitForChild("GetCharacterStatsInfo", 20)
local adminSetStats = remotes:WaitForChild("AdminSetCharacterStats", 20)
local adminRemoveStats = remotes:WaitForChild("AdminRemoveCharacterStats", 20)
local adminCatalogList = remotes:WaitForChild("AdminCatalogListCharacters", 20)

if not getCharacterStatsInfo or not adminSetStats then
	warn("[STATS ADMIN V2] Remotes de atributos não encontrados — CharacterStatsServer V1 está instalado?")
	return
end

-- =====================================
-- VISUAL (paleta do projeto)
-- =====================================

local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

local COLORS = {
	background = Color3.fromRGB(20, 20, 20),
	panel = Color3.fromRGB(30, 30, 30),
	header = Color3.fromRGB(40, 40, 40),
	accent = Color3.fromRGB(255, 170, 0), -- laranja = admin
	success = Color3.fromRGB(0, 200, 0),
	error = Color3.fromRGB(200, 60, 60),
	disabled = Color3.fromRGB(100, 100, 100),
	text = Color3.fromRGB(255, 255, 255),
	textDim = Color3.fromRGB(170, 170, 170),
}

local SOUND_IDS = {
	click = "rbxassetid://156785206",
	save = "rbxassetid://5031873608",
	error = "rbxassetid://2865228021",
	open = "rbxassetid://157167203",
	close = "rbxassetid://157167205",
}

local function playSound(id)
	local sound = Instance.new("Sound")
	sound.SoundId = id
	sound.Volume = 0.5
	sound.Parent = SoundService
	sound:Play()
	task.delay(3, function()
		sound.Parent = nil -- regra do projeto: sem :Destroy()
	end)
end

-- =====================================
-- ESTADO
-- =====================================

local gui, characterList, archetypeList, statusLabel, headerLabel
local characters = {} -- lista do catálogo
local archetypes = {} -- lista vinda do servidor
local selectedCharacter = nil
local selectedArchetype = "equilibrado"
local currentStats = {}
local isOpen = false

-- =====================================
-- HELPERS
-- =====================================

local function clearChildren(container)
	for _, child in ipairs(container:GetChildren()) do
		if not child:IsA("UIListLayout") and not child:IsA("UIPadding") then
			child.Parent = nil -- regra do projeto: sem :Destroy()
		end
	end
end

local function setStatus(text, color)
	if statusLabel then
		statusLabel.Text = text or ""
		statusLabel.TextColor3 = color or COLORS.textDim
	end
end

local function fetchCharacters()
	if not adminCatalogList then
		return
	end
	local ok, result = pcall(function()
		return adminCatalogList:InvokeServer()
	end)
	if ok and type(result) == "table" then
		characters = result
		table.sort(characters, function(a, b)
			return tostring(a.name) < tostring(b.name)
		end)
	end
end

local function fetchStatsInfo(characterName)
	local ok, result = pcall(function()
		return getCharacterStatsInfo:InvokeServer(characterName)
	end)
	if ok and type(result) == "table" then
		if result.archetypes then
			archetypes = result.archetypes
		end
		if characterName then
			selectedArchetype = result.archetype or "equilibrado"
			currentStats = result.finalStats or {}
		end
		return true
	end
	return false
end

-- =====================================
-- RENDERIZAÇÃO
-- =====================================

local refreshAll

local function buildCharacterRow(def, index)
	local isSelected = (def.name == selectedCharacter)

	local row = Instance.new("TextButton")
	row.Size = UDim2.new(1, 0, 0.16, 0)
	row.BackgroundColor3 = isSelected and COLORS.header or COLORS.panel
	row.BorderColor3 = isSelected and COLORS.accent or COLORS.disabled
	row.BorderSizePixel = isSelected and 3 or 1
	row.Text = ""
	row.AutoButtonColor = false
	row.LayoutOrder = index
	row.Parent = characterList

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size = UDim2.new(0.95, 0, 0.55, 0)
	nameLabel.Position = UDim2.new(0.025, 0, 0.08, 0)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = def.name
	nameLabel.TextColor3 = isSelected and COLORS.accent or COLORS.text
	nameLabel.TextScaled = true
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.Parent = row

	local infoLabel = Instance.new("TextLabel")
	infoLabel.Size = UDim2.new(0.95, 0, 0.35, 0)
	infoLabel.Position = UDim2.new(0.025, 0, 0.6, 0)
	infoLabel.BackgroundTransparency = 1
	infoLabel.Text = string.format("%d HP  •  %s", def.health or 100, def.rarity or "—")
	infoLabel.TextColor3 = COLORS.textDim
	infoLabel.TextScaled = true
	infoLabel.Font = Enum.Font.Gotham
	infoLabel.TextXAlignment = Enum.TextXAlignment.Left
	infoLabel.Parent = row

	row.MouseButton1Click:Connect(function()
		playSound(SOUND_IDS.click)
		selectedCharacter = def.name
		fetchStatsInfo(def.name)
		setStatus("")
		refreshAll()
	end)
end

local function buildArchetypeRow(archetype, index)
	local isSelected = (archetype.id == selectedArchetype)

	local row = Instance.new("TextButton")
	row.Size = UDim2.new(1, 0, 0.17, 0)
	row.BackgroundColor3 = isSelected and COLORS.header or COLORS.panel
	row.BorderColor3 = isSelected and COLORS.accent or COLORS.disabled
	row.BorderSizePixel = isSelected and 3 or 1
	row.Text = ""
	row.AutoButtonColor = false
	row.LayoutOrder = index
	row.Parent = archetypeList

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(0.95, 0, 0.45, 0)
	title.Position = UDim2.new(0.025, 0, 0.08, 0)
	title.BackgroundTransparency = 1
	title.Text = archetype.icon .. " " .. archetype.name
	title.TextColor3 = isSelected and COLORS.accent or COLORS.text
	title.TextScaled = true
	title.Font = Enum.Font.GothamBold
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = row

	local desc = Instance.new("TextLabel")
	desc.Size = UDim2.new(0.95, 0, 0.42, 0)
	desc.Position = UDim2.new(0.025, 0, 0.53, 0)
	desc.BackgroundTransparency = 1
	desc.Text = archetype.desc
	desc.TextColor3 = COLORS.textDim
	desc.TextScaled = true
	desc.Font = Enum.Font.Gotham
	desc.TextXAlignment = Enum.TextXAlignment.Left
	desc.TextWrapped = true
	desc.Parent = row

	row.MouseButton1Click:Connect(function()
		if not selectedCharacter then
			playSound(SOUND_IDS.error)
			setStatus("Escolha um personagem primeiro.", COLORS.error)
			return
		end
		playSound(SOUND_IDS.click)
		selectedArchetype = archetype.id
		refreshAll()
	end)
end

refreshAll = function()
	if not gui then
		return
	end

	-- Lista de personagens
	clearChildren(characterList)
	if #characters == 0 then
		local empty = Instance.new("TextLabel")
		empty.Size = UDim2.new(1, 0, 0.2, 0)
		empty.BackgroundTransparency = 1
		empty.Text = "Nenhum personagem no catálogo."
		empty.TextColor3 = COLORS.textDim
		empty.TextScaled = true
		empty.TextWrapped = true
		empty.Font = Enum.Font.Gotham
		empty.Parent = characterList
	else
		for index, def in ipairs(characters) do
			buildCharacterRow(def, index)
		end
	end

	-- Cabeçalho
	if selectedCharacter then
		headerLabel.Text = "Editando: " .. selectedCharacter
		headerLabel.TextColor3 = COLORS.accent
	else
		headerLabel.Text = "Escolha um personagem à esquerda"
		headerLabel.TextColor3 = COLORS.textDim
	end

	-- Lista de arquétipos
	clearChildren(archetypeList)
	for index, archetype in ipairs(archetypes) do
		buildArchetypeRow(archetype, index)
	end
end

-- =====================================
-- INTERFACE
-- =====================================

local function createInterface()
	gui = Instance.new("ScreenGui")
	gui.Name = "CharacterStatsAdminGui"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 46
	gui.Enabled = false
	gui.Parent = playerGui

	local mainFrame = Instance.new("Frame")
	mainFrame.Size = UDim2.new(isMobile and 0.95 or 0.8, 0, isMobile and 0.9 or 0.8, 0)
	mainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
	mainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	mainFrame.BackgroundColor3 = COLORS.background
	mainFrame.BorderColor3 = COLORS.accent
	mainFrame.BorderSizePixel = 4
	mainFrame.Parent = gui

	-- HEADER
	local header = Instance.new("Frame")
	header.Size = UDim2.new(1, 0, 0.1, 0)
	header.BackgroundColor3 = COLORS.header
	header.BorderSizePixel = 0
	header.Parent = mainFrame

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(0.6, 0, 1, 0)
	title.Position = UDim2.new(0.02, 0, 0, 0)
	title.BackgroundTransparency = 1
	title.Text = "⚗️ ATRIBUTOS DOS PERSONAGENS"
	title.TextColor3 = COLORS.accent
	title.TextScaled = true
	title.Font = Enum.Font.GothamBold
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = header

	local closeButton = Instance.new("TextButton")
	closeButton.Size = UDim2.new(0.08, 0, 0.7, 0)
	closeButton.Position = UDim2.new(0.9, 0, 0.15, 0)
	closeButton.BackgroundColor3 = COLORS.error
	closeButton.BorderSizePixel = 0
	closeButton.Text = "✕"
	closeButton.TextColor3 = COLORS.text
	closeButton.TextScaled = true
	closeButton.Font = Enum.Font.GothamBold
	closeButton.Parent = header

	-- SUBCABEÇALHO
	headerLabel = Instance.new("TextLabel")
	headerLabel.Size = UDim2.new(0.96, 0, 0.06, 0)
	headerLabel.Position = UDim2.new(0.02, 0, 0.11, 0)
	headerLabel.BackgroundColor3 = COLORS.panel
	headerLabel.BorderSizePixel = 0
	headerLabel.Text = "Escolha um personagem à esquerda"
	headerLabel.TextColor3 = COLORS.textDim
	headerLabel.TextScaled = true
	headerLabel.Font = Enum.Font.GothamBold
	headerLabel.Parent = mainFrame

	-- COLUNA ESQUERDA: PERSONAGENS DO CATÁLOGO
	local leftTitle = Instance.new("TextLabel")
	leftTitle.Size = UDim2.new(0.32, 0, 0.05, 0)
	leftTitle.Position = UDim2.new(0.02, 0, 0.18, 0)
	leftTitle.BackgroundTransparency = 1
	leftTitle.Text = "PERSONAGENS"
	leftTitle.TextColor3 = COLORS.textDim
	leftTitle.TextScaled = true
	leftTitle.Font = Enum.Font.GothamBold
	leftTitle.TextXAlignment = Enum.TextXAlignment.Left
	leftTitle.Parent = mainFrame

	characterList = Instance.new("ScrollingFrame")
	characterList.Size = UDim2.new(0.32, 0, 0.6, 0)
	characterList.Position = UDim2.new(0.02, 0, 0.235, 0)
	characterList.BackgroundColor3 = COLORS.panel
	characterList.BorderColor3 = COLORS.disabled
	characterList.BorderSizePixel = 2
	characterList.ScrollBarThickness = 6
	characterList.CanvasSize = UDim2.new(0, 0, 0, 0)
	characterList.AutomaticCanvasSize = Enum.AutomaticSize.Y
	characterList.Parent = mainFrame

	local charLayout = Instance.new("UIListLayout")
	charLayout.Padding = UDim.new(0.015, 0)
	charLayout.Parent = characterList

	-- COLUNA DIREITA: ARQUÉTIPOS
	local rightTitle = Instance.new("TextLabel")
	rightTitle.Size = UDim2.new(0.62, 0, 0.05, 0)
	rightTitle.Position = UDim2.new(0.36, 0, 0.18, 0)
	rightTitle.BackgroundTransparency = 1
	rightTitle.Text = "ARQUÉTIPO"
	rightTitle.TextColor3 = COLORS.textDim
	rightTitle.TextScaled = true
	rightTitle.Font = Enum.Font.GothamBold
	rightTitle.TextXAlignment = Enum.TextXAlignment.Left
	rightTitle.Parent = mainFrame

	archetypeList = Instance.new("ScrollingFrame")
	archetypeList.Size = UDim2.new(0.62, 0, 0.6, 0)
	archetypeList.Position = UDim2.new(0.36, 0, 0.235, 0)
	archetypeList.BackgroundColor3 = COLORS.panel
	archetypeList.BorderColor3 = COLORS.disabled
	archetypeList.BorderSizePixel = 2
	archetypeList.ScrollBarThickness = 6
	archetypeList.CanvasSize = UDim2.new(0, 0, 0, 0)
	archetypeList.AutomaticCanvasSize = Enum.AutomaticSize.Y
	archetypeList.Parent = mainFrame

	local archLayout = Instance.new("UIListLayout")
	archLayout.Padding = UDim.new(0.015, 0)
	archLayout.Parent = archetypeList

	-- STATUS
	statusLabel = Instance.new("TextLabel")
	statusLabel.Size = UDim2.new(0.96, 0, 0.05, 0)
	statusLabel.Position = UDim2.new(0.02, 0, 0.845, 0)
	statusLabel.BackgroundTransparency = 1
	statusLabel.Text = ""
	statusLabel.TextColor3 = COLORS.textDim
	statusLabel.TextScaled = true
	statusLabel.Font = Enum.Font.Gotham
	statusLabel.Parent = mainFrame

	-- BOTÕES
	local saveButton = Instance.new("TextButton")
	saveButton.Size = UDim2.new(0.46, 0, 0.08, 0)
	saveButton.Position = UDim2.new(0.02, 0, 0.9, 0)
	saveButton.BackgroundColor3 = COLORS.success
	saveButton.BorderSizePixel = 0
	saveButton.Text = "💾 SALVAR"
	saveButton.TextColor3 = COLORS.text
	saveButton.TextScaled = true
	saveButton.Font = Enum.Font.GothamBold
	saveButton.Parent = mainFrame

	local removeButton = Instance.new("TextButton")
	removeButton.Size = UDim2.new(0.46, 0, 0.08, 0)
	removeButton.Position = UDim2.new(0.52, 0, 0.9, 0)
	removeButton.BackgroundColor3 = COLORS.header
	removeButton.BorderColor3 = COLORS.error
	removeButton.BorderSizePixel = 2
	removeButton.Text = "🗑️ LIMPAR"
	removeButton.TextColor3 = COLORS.error
	removeButton.TextScaled = true
	removeButton.Font = Enum.Font.GothamBold
	removeButton.Parent = mainFrame

	-- AÇÕES
	closeButton.MouseButton1Click:Connect(function()
		playSound(SOUND_IDS.close)
		if _G.CloseCharacterStatsAdmin then
			_G.CloseCharacterStatsAdmin()
		end
	end)

	-- (V2) Trava contra toque repetido. Sem isto, cada toque virava
	-- uma gravação de DataStore e a fila enchia.
	local isSaving = false

	saveButton.MouseButton1Click:Connect(function()
		if isSaving then
			return -- já está gravando; ignora o toque
		end

		if not selectedCharacter then
			playSound(SOUND_IDS.error)
			setStatus("Escolha um personagem primeiro.", COLORS.error)
			return
		end

		isSaving = true
		saveButton.Text = "⏳ SALVANDO..."
		saveButton.BackgroundColor3 = COLORS.disabled
		setStatus("Gravando...", COLORS.textDim)

		-- custom fica vazio: o ajuste fino por atributo avulso
		-- continua disponível pela API, mas a tela trabalha só com
		-- arquétipo (1 escolha em vez de 23 campos)
		-- ⚠️ UMA chamada só. O pcall devolve (pcallOk, retorno1,
		-- retorno2), então dá pra pegar os dois valores do remote sem
		-- invocar de novo.
		local pcallOk, success, serverMessage = pcall(function()
			return adminSetStats:InvokeServer(selectedCharacter, selectedArchetype, {})
		end)

		if not pcallOk then
			success = false
			serverMessage = "Erro de conexão com o servidor."
		end

		saveButton.Text = "💾 SALVAR"
		saveButton.BackgroundColor3 = COLORS.success
		isSaving = false

		playSound(success and SOUND_IDS.save or SOUND_IDS.error)
		setStatus(serverMessage or (success and "Salvo!" or "Falhou."), success and COLORS.success or COLORS.error)

		if success then
			fetchStatsInfo(selectedCharacter)
			refreshAll()
		end
	end)

	removeButton.MouseButton1Click:Connect(function()
		if not selectedCharacter then
			playSound(SOUND_IDS.error)
			setStatus("Escolha um personagem primeiro.", COLORS.error)
			return
		end

		local ok, message = adminRemoveStats:InvokeServer(selectedCharacter)
		playSound(ok and SOUND_IDS.click or SOUND_IDS.error)
		setStatus(message or "", ok and COLORS.success or COLORS.error)

		if ok then
			selectedArchetype = "equilibrado"
			fetchStatsInfo(selectedCharacter)
			refreshAll()
		end
	end)
end

-- =====================================
-- ABRIR / FECHAR
-- =====================================

_G.OpenCharacterStatsAdmin = function()
	if not gui then
		return
	end

	fetchCharacters()
	fetchStatsInfo(selectedCharacter)
	setStatus("")
	refreshAll()

	gui.Enabled = true
	isOpen = true
	playSound(SOUND_IDS.open)
end

_G.CloseCharacterStatsAdmin = function()
	if gui then
		gui.Enabled = false
	end
	isOpen = false
end

-- =====================================
-- INICIALIZAÇÃO (só pra admin)
-- =====================================

local function initialize()
	createInterface()

	task.spawn(function()
		task.wait(3)
		fetchStatsInfo(nil) -- carrega a lista de arquétipos
		fetchCharacters()
	end)

	task.spawn(function()
		local timeout = 0
		while not _G.RegisterMenuCategory and timeout < 15 do
			task.wait(0.5)
			timeout = timeout + 0.5
		end

		if _G.RegisterMenuCategory then
			_G.RegisterMenuCategory("ATRIBUTOS", "⚗️", function()
				if _G.OpenCharacterStatsAdmin then
					_G.OpenCharacterStatsAdmin()
				end
			end, function()
				if _G.CloseCharacterStatsAdmin then
					_G.CloseCharacterStatsAdmin()
				end
			end, 10) -- 9 é PASSIVAS

			print("[STATS ADMIN V2] Registrado no Menu Unificado")
		end
	end)

	print([[
╔══════════════════════════════════════════════════════╗
║  CHARACTER STATS ADMIN V2 — CARREGADO               ║
╠══════════════════════════════════════════════════════╣
║  SUBSTITUI: CharacterStatsAdminClient V1             ║
║  REMOVER:   CharacterStatsAdminClient V1             ║
║  AdminMenuClient V9 continua INTOCADO                ║
╠══════════════════════════════════════════════════════╣
║  * Aparece no ☰ como "ATRIBUTOS" (só admin)          ║
║  * Lista os personagens do catálogo de verdade       ║
║  * Escolhe arquétipo e salva EM JOGO                 ║
║  * Sincroniza entre servidores na hora               ║
╚══════════════════════════════════════════════════════╝
]])
end

-- Mesmo padrão do AdminMenuClient: se não é admin agora, re-checa
-- a cada 30s (o dono pode te promover com o jogo rodando)
if checkIsAdmin() then
	initialize()
else
	task.spawn(function()
		while true do
			task.wait(30)
			if checkIsAdmin() then
				initialize()
				break
			end
		end
	end)
end
