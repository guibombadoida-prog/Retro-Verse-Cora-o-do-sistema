-- ============================================
-- PASSIVE MENU CLIENT V3 — EDIÇÃO COM PERSONAGEM DESEQUIPADO
-- Coloque em StarterPlayer > StarterPlayerScripts
-- Nome: "PassiveMenuClient"
-- DEPENDE DE: PassiveSystemServer V8, UnifiedMenuClient V3
-- SUBSTITUI: PassiveMenuClient V2
-- REMOVER:   PassiveMenuClient V2
-- ============================================
-- (V3) NOVA REGRA: SÓ EDITA DESEQUIPADO
--
-- Equipar, melhorar ou mexer na build agora exige que o jogador
-- esteja SEM personagem equipado. Isso mudou duas coisas na tela:
--
--  1. SELETOR DE PERSONAGEM. Antes a tela editava "o equipado".
--     Agora não existe equipado — então ela lista os personagens
--     que você tem e você escolhe qual editar.
--
--  2. ESTADO BLOQUEADO. Com personagem equipado, a tela abre em
--     modo leitura: dá pra ver tudo, mas os botões ficam travados
--     com o aviso de desequipar. Preferi isso a esconder a tela —
--     ver o que existe é metade da graça de planejar a build.
--
-- ============================================
-- (V2) POR QUE FOI REESCRITO E NÃO REMENDADO:
-- O V1 foi feito para 3 ranks fixos, escritos à mão. O V7 do
-- servidor trabalha com 10 níveis calculados por fórmula, custo em
-- moedas, 5 categorias, passiva exclusiva, tipo temporário com
-- gatilho e recarga, e slots vindos de gamepass. Praticamente todo
-- card e toda ação mudaram — remendar sairia mais confuso que
-- reescrever.
--
-- ============================================
-- DUAS AÇÕES DIFERENTES (é a parte que confunde)
-- ============================================
-- EQUIPAR/REMOVER é uma edição LOCAL. Você monta a build, e só ao
-- apertar SALVAR ela vai pro servidor (e o respec é cobrado ali).
--
-- MELHORAR é IMEDIATO. Cobra moedas na hora e só funciona em
-- passiva JÁ SALVA — porque o servidor precisa dela existindo pra
-- subir o nível. Por isso o botão MELHORAR fica travado enquanto a
-- passiva estiver só no rascunho.
--
-- ⚠️ REGRAS DE GUI RESPEITADAS: sem keybind (só botão), UDim2 em
--    scale, TextScaled, ResetOnSpawn = false, IgnoreGuiInset = true,
--    limpeza com Parent = nil (nunca :Destroy()).
-- ============================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local SoundService = game:GetService("SoundService")
local MarketplaceService = game:GetService("MarketplaceService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

-- =====================================
-- VISUAL
-- =====================================

local COR = {
	fundo = Color3.fromRGB(20, 20, 20),
	painel = Color3.fromRGB(30, 30, 30),
	cabecalho = Color3.fromRGB(40, 40, 40),
	destaque = Color3.fromRGB(0, 200, 255),
	bom = Color3.fromRGB(0, 220, 0),
	ruim = Color3.fromRGB(220, 60, 60),
	aviso = Color3.fromRGB(255, 200, 0),
	desativado = Color3.fromRGB(100, 100, 100),
	texto = Color3.fromRGB(255, 255, 255),
	textoFraco = Color3.fromRGB(170, 170, 170),
	ouro = Color3.fromRGB(255, 200, 60),
	roxo = Color3.fromRGB(180, 90, 255),
	nivelBarra = Color3.fromRGB(160, 80, 255),
}

local SONS = {
	clique = "rbxassetid://156785206",
	compra = "rbxassetid://5031873608",
	erro = "rbxassetid://2865228021",
	abrir = "rbxassetid://157167203",
	fechar = "rbxassetid://157167205",
}

local function tocar(id)
	local som = Instance.new("Sound")
	som.SoundId = id
	som.Volume = 0.5
	som.Parent = SoundService
	som:Play()
	task.delay(3, function()
		som.Parent = nil -- regra do projeto: sem :Destroy()
	end)
end

local CATEGORIAS = { "Defesa", "Ataque", "Utilidade", "Chance", "Temporária" }
local ICONE_CATEGORIA = {
	Defesa = "🛡️",
	Ataque = "⚔️",
	Utilidade = "🔧",
	Chance = "🎲",
	["Temporária"] = "⏱️",
}

-- =====================================
-- REMOTES
-- =====================================

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local remoteCatalogo = remotes:WaitForChild("GetPassiveCatalog", 20)
local remoteEquipar = remotes:WaitForChild("SetCharacterPassives", 20)
local remoteUpgrade = remotes:WaitForChild("UpgradePassive", 20)

if not remoteCatalogo then
	warn("[PASSIVE MENU V3] GetPassiveCatalog não encontrado — PassiveSystemServer V7 instalado?")
	return
end

-- =====================================
-- ESTADO
-- =====================================

local dados = nil -- resposta completa do servidor
local categoriaAtual = "Defesa"
local rascunho = {} -- build sendo montada (ainda não salva)
local aberto = false
local personagemAtual = nil -- (V3) qual personagem está sendo editado

local gui, listaPassivas, barraInfo, rotuloStatus, abasFrame, botaoGamepass
local seletorFrame, avisoBloqueio, botaoSalvar

-- =====================================
-- HELPERS
-- =====================================

local function limpar(container)
	for _, filho in ipairs(container:GetChildren()) do
		if not filho:IsA("UIListLayout") and not filho:IsA("UIPadding") then
			filho.Parent = nil -- regra do projeto: sem :Destroy()
		end
	end
end

local function copiar(lista)
	local saida = {}
	for _, entrada in ipairs(lista or {}) do
		table.insert(saida, { id = entrada.id, rank = entrada.rank })
	end
	return saida
end

local function noRascunho(id)
	for _, entrada in ipairs(rascunho) do
		if entrada.id == id then
			return entrada
		end
	end
	return nil
end

-- (V3) Dados do personagem escolhido dentro da lista do servidor
local function personagemEscolhido()
	if not dados or not dados.personagens then
		return nil
	end
	for _, p in ipairs(dados.personagens) do
		if p.nome == personagemAtual then
			return p
		end
	end
	return nil
end

local function slotsAtuais()
	local p = personagemEscolhido()
	return p and p.slots or 0
end

-- Está salva no servidor? Só assim dá pra melhorar.
local function salvaNoServidor(id)
	local p = personagemEscolhido()
	if not p then
		return nil
	end
	for _, entrada in ipairs(p.passivas or {}) do
		if entrada.id == id then
			return entrada
		end
	end
	return nil
end

-- (V3) Botões travados quando há personagem equipado
local function bloqueado()
	return dados ~= nil and dados.podeEditar == false
end

local function status(texto, cor)
	if rotuloStatus then
		rotuloStatus.Text = texto or ""
		rotuloStatus.TextColor3 = cor or COR.textoFraco
	end
end

local function buscar()
	local ok, resultado = pcall(function()
		return remoteCatalogo:InvokeServer()
	end)

	if ok and type(resultado) == "table" and resultado.catalogo then
		dados = resultado
		return true
	end

	warn("[PASSIVE MENU V3] Falha ao buscar catálogo")
	return false
end

-- =====================================
-- CARD DE PASSIVA
-- =====================================

local renderizar

local function montarCard(passiva, ordem)
	local noRasc = noRascunho(passiva.id)
	local salva = salvaNoServidor(passiva.id)
	local equipada = noRasc ~= nil
	local nivel = (noRasc and noRasc.rank) or 1
	local maxNivel = dados.maxNivel or 10

	local card = Instance.new("Frame")
	card.Size = UDim2.new(1, 0, 0.42, 0)
	card.BackgroundColor3 = equipada and COR.cabecalho or COR.painel
	card.BorderColor3 = equipada and COR.destaque or COR.desativado
	card.BorderSizePixel = equipada and 3 or 1
	card.LayoutOrder = ordem
	card.Parent = listaPassivas

	-- ---------- TÍTULO ----------
	local titulo = Instance.new("TextLabel")
	titulo.Size = UDim2.new(0.62, 0, 0.15, 0)
	titulo.Position = UDim2.new(0.02, 0, 0.03, 0)
	titulo.BackgroundTransparency = 1
	titulo.Text = passiva.icone .. " " .. passiva.nome
	titulo.TextColor3 = equipada and COR.destaque or COR.texto
	titulo.TextScaled = true
	titulo.Font = Enum.Font.GothamBold
	titulo.TextXAlignment = Enum.TextXAlignment.Left
	titulo.Parent = card

	-- ---------- SELO DE TIPO ----------
	local selo = Instance.new("TextLabel")
	selo.Size = UDim2.new(0.34, 0, 0.13, 0)
	selo.Position = UDim2.new(0.64, 0, 0.04, 0)
	selo.BackgroundColor3 = passiva.tipo == "temporario" and COR.roxo or COR.fundo
	selo.BorderSizePixel = 0
	selo.Text = passiva.exclusivo and "EXCLUSIVA"
		or (passiva.tipo == "temporario" and "TEMPORÁRIA" or "PERMANENTE")
	selo.TextColor3 = passiva.exclusivo and COR.aviso or COR.texto
	selo.TextScaled = true
	selo.Font = Enum.Font.GothamBold
	selo.Parent = card

	-- ---------- BENEFÍCIO / MALEFÍCIO ----------
	local bom = Instance.new("TextLabel")
	bom.Size = UDim2.new(0.96, 0, 0.11, 0)
	bom.Position = UDim2.new(0.02, 0, 0.19, 0)
	bom.BackgroundTransparency = 1
	bom.Text = "＋ " .. (passiva.beneficio or "")
	bom.TextColor3 = COR.bom
	bom.TextScaled = true
	bom.Font = Enum.Font.Gotham
	bom.TextXAlignment = Enum.TextXAlignment.Left
	bom.Parent = card

	local ruim = Instance.new("TextLabel")
	ruim.Size = UDim2.new(0.96, 0, 0.11, 0)
	ruim.Position = UDim2.new(0.02, 0, 0.31, 0)
	ruim.BackgroundTransparency = 1
	ruim.Text = "－ " .. (passiva.malefico or "")
	ruim.TextColor3 = COR.ruim
	ruim.TextScaled = true
	ruim.Font = Enum.Font.Gotham
	ruim.TextXAlignment = Enum.TextXAlignment.Left
	ruim.Parent = card

	-- ---------- NÍVEL E BARRA ----------
	local infoNivel = Instance.new("TextLabel")
	infoNivel.Size = UDim2.new(0.30, 0, 0.11, 0)
	infoNivel.Position = UDim2.new(0.02, 0, 0.44, 0)
	infoNivel.BackgroundTransparency = 1
	infoNivel.Text = string.format("Nível %d/%d", nivel, maxNivel)
	infoNivel.TextColor3 = nivel >= maxNivel and COR.ouro or COR.aviso
	infoNivel.TextScaled = true
	infoNivel.Font = Enum.Font.GothamBold
	infoNivel.TextXAlignment = Enum.TextXAlignment.Left
	infoNivel.Parent = card

	local barraFundo = Instance.new("Frame")
	barraFundo.Size = UDim2.new(0.64, 0, 0.05, 0)
	barraFundo.Position = UDim2.new(0.34, 0, 0.47, 0)
	barraFundo.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
	barraFundo.BorderSizePixel = 0
	barraFundo.Parent = card

	local barraCheia = Instance.new("Frame")
	barraCheia.Size = UDim2.new(nivel / maxNivel, 0, 1, 0)
	barraCheia.BackgroundColor3 = nivel >= maxNivel and COR.ouro or COR.nivelBarra
	barraCheia.BorderSizePixel = 0
	barraCheia.Parent = barraFundo

	-- ---------- EFEITO NO NÍVEL ATUAL ----------
	local descricao = Instance.new("TextLabel")
	descricao.Size = UDim2.new(0.96, 0, 0.16, 0)
	descricao.Position = UDim2.new(0.02, 0, 0.56, 0)
	descricao.BackgroundColor3 = COR.fundo
	descricao.BorderSizePixel = 0
	descricao.Text = passiva.niveis[nivel] and passiva.niveis[nivel].desc or ""
	descricao.TextColor3 = COR.aviso
	descricao.TextScaled = true
	descricao.Font = Enum.Font.Code
	descricao.TextWrapped = true
	descricao.Parent = card

	-- ---------- BOTÕES ----------
	local botaoEquipar = Instance.new("TextButton")
	botaoEquipar.Size = UDim2.new(0.46, 0, 0.16, 0)
	botaoEquipar.Position = UDim2.new(0.02, 0, 0.76, 0)
	botaoEquipar.BackgroundColor3 = equipada and COR.ruim or COR.bom
	botaoEquipar.BorderSizePixel = 0
	botaoEquipar.Text = equipada and "REMOVER" or "EQUIPAR"
	botaoEquipar.TextColor3 = COR.texto
	botaoEquipar.TextScaled = true
	botaoEquipar.Font = Enum.Font.GothamBold
	botaoEquipar.Parent = card

	if bloqueado() then
		botaoEquipar.BackgroundColor3 = COR.desativado
		botaoEquipar.Text = "🔒 DESEQUIPE"
		botaoEquipar.TextColor3 = COR.textoFraco
	end

	botaoEquipar.MouseButton1Click:Connect(function()
		if bloqueado() then
			tocar(SONS.erro)
			status(dados.motivoBloqueio or "Desequipe seu personagem.", COR.ruim)
			return
		end
		if not personagemAtual then
			tocar(SONS.erro)
			status("Escolha um personagem acima.", COR.aviso)
			return
		end

		if equipada then
			for i, entrada in ipairs(rascunho) do
				if entrada.id == passiva.id then
					table.remove(rascunho, i)
					break
				end
			end
			tocar(SONS.clique)
			status("")
		else
			-- Exclusiva ocupa tudo
			if passiva.exclusivo and #rascunho > 0 then
				tocar(SONS.erro)
				status("Essa passiva é exclusiva — remova as outras primeiro.", COR.ruim)
				return
			end

			-- Já tem exclusiva equipada?
			for _, entrada in ipairs(rascunho) do
				for _, p in ipairs(dados.catalogo) do
					if p.id == entrada.id and p.exclusivo then
						tocar(SONS.erro)
						status("Você tem uma exclusiva equipada — remova antes.", COR.ruim)
						return
					end
				end
			end

			if #rascunho >= slotsAtuais() then
				tocar(SONS.erro)
				status(string.format("Sem slot livre (%d).", slotsAtuais()), COR.ruim)
				return
			end

			-- Se já estava salva, preserva o nível conquistado
			local anterior = salvaNoServidor(passiva.id)
			table.insert(rascunho, { id = passiva.id, rank = anterior and anterior.rank or 1 })
			tocar(SONS.clique)
			status("")
		end

		renderizar()
	end)

	-- ---------- MELHORAR ----------
	local custo = passiva.niveis[nivel] and passiva.niveis[nivel].custo
	local podeMelhorar = equipada
		and salva ~= nil
		and nivel < maxNivel
		and custo ~= nil
		and not bloqueado()
	local temMoeda = podeMelhorar and (dados.moedas or 0) >= custo

	local botaoMelhorar = Instance.new("TextButton")
	botaoMelhorar.Size = UDim2.new(0.50, 0, 0.16, 0)
	botaoMelhorar.Position = UDim2.new(0.48, 0, 0.76, 0)
	botaoMelhorar.BorderSizePixel = 0
	botaoMelhorar.TextScaled = true
	botaoMelhorar.Font = Enum.Font.GothamBold
	botaoMelhorar.TextColor3 = COR.texto
	botaoMelhorar.Parent = card

	if bloqueado() then
		botaoMelhorar.BackgroundColor3 = COR.desativado
		botaoMelhorar.Text = "🔒 desequipe para melhorar"
		botaoMelhorar.TextColor3 = COR.textoFraco
	elseif nivel >= maxNivel and equipada then
		botaoMelhorar.BackgroundColor3 = COR.ouro
		botaoMelhorar.Text = "★ NÍVEL MÁXIMO"
		botaoMelhorar.TextColor3 = COR.fundo
	elseif not equipada then
		botaoMelhorar.BackgroundColor3 = COR.desativado
		botaoMelhorar.Text = "equipe para melhorar"
		botaoMelhorar.TextColor3 = COR.textoFraco
	elseif not salva then
		-- Está no rascunho mas ainda não foi salva
		botaoMelhorar.BackgroundColor3 = COR.desativado
		botaoMelhorar.Text = "salve antes de melhorar"
		botaoMelhorar.TextColor3 = COR.textoFraco
	else
		botaoMelhorar.BackgroundColor3 = temMoeda and COR.destaque or COR.desativado
		botaoMelhorar.Text = string.format("⬆ %d 🪙", custo)
		botaoMelhorar.TextColor3 = temMoeda and COR.fundo or COR.textoFraco
	end

	botaoMelhorar.MouseButton1Click:Connect(function()
		if bloqueado() then
			tocar(SONS.erro)
			status(dados.motivoBloqueio or "Desequipe seu personagem.", COR.ruim)
			return
		end
		if not podeMelhorar then
			tocar(SONS.erro)
			if equipada and not salva then
				status("Aperte SALVAR BUILD antes de melhorar.", COR.aviso)
			end
			return
		end

		local ok, mensagem = remoteUpgrade:InvokeServer(personagemAtual, passiva.id)
		tocar(ok and SONS.compra or SONS.erro)
		status(mensagem or "", ok and COR.bom or COR.ruim)

		if ok then
			buscar()
			local p = personagemEscolhido()
			rascunho = copiar(p and p.passivas)
			renderizar()
		end
	end)
end

-- =====================================
-- RENDERIZAÇÃO
-- =====================================

renderizar = function()
	if not gui or not dados then
		return
	end

	-- ---------- AVISO DE BLOQUEIO ----------
	if bloqueado() then
		avisoBloqueio.Visible = true
		avisoBloqueio.Text = "🔒 " .. (dados.motivoBloqueio or "Desequipe seu personagem para editar.")
	else
		avisoBloqueio.Visible = false
	end

	-- ---------- SELETOR DE PERSONAGEM ----------
	limpar(seletorFrame)
	local personagens = dados.personagens or {}

	if #personagens == 0 then
		local vazio = Instance.new("TextLabel")
		vazio.Size = UDim2.new(1, 0, 1, 0)
		vazio.BackgroundTransparency = 1
		vazio.Text = "Você não tem personagens."
		vazio.TextColor3 = COR.textoFraco
		vazio.TextScaled = true
		vazio.Font = Enum.Font.Gotham
		vazio.Parent = seletorFrame
	else
		for indice, p in ipairs(personagens) do
			local ativo = (p.nome == personagemAtual)

			local botao = Instance.new("TextButton")
			botao.Size = UDim2.new(0.31, 0, 1, 0)
			botao.BackgroundColor3 = ativo and COR.destaque or COR.painel
			botao.BorderColor3 = ativo and COR.texto or COR.desativado
			botao.BorderSizePixel = 2
			botao.Text = string.format("%s\nNv %d • %d slots", p.nome, p.nivel, p.slots)
			botao.TextColor3 = ativo and COR.fundo or COR.textoFraco
			botao.TextScaled = true
			botao.Font = Enum.Font.GothamBold
			botao.LayoutOrder = indice
			botao.Parent = seletorFrame

			botao.MouseButton1Click:Connect(function()
				tocar(SONS.clique)
				personagemAtual = p.nome
				rascunho = copiar(p.passivas)
				status("")
				renderizar()
			end)
		end
	end

	-- ---------- BARRA DE INFO ----------
	local extras = dados.temGamepass and (" +" .. (dados.slotsExtras or 3) .. " gamepass") or ""
	barraInfo.Text = string.format(
		"%s   •   Slots %d/%d%s   •   %d 🪙",
		personagemAtual or "ESCOLHA UM PERSONAGEM",
		#rascunho,
		slotsAtuais(),
		extras,
		dados.moedas or 0
	)
	barraInfo.TextColor3 = personagemAtual and COR.texto or COR.aviso

	-- ---------- ABAS ----------
	limpar(abasFrame)
	for indice, categoria in ipairs(CATEGORIAS) do
		local ativa = (categoria == categoriaAtual)

		local aba = Instance.new("TextButton")
		aba.Size = UDim2.new(0.19, 0, 1, 0)
		aba.Position = UDim2.new((indice - 1) * 0.202, 0, 0, 0)
		aba.BackgroundColor3 = ativa and COR.destaque or COR.painel
		aba.BorderColor3 = ativa and COR.texto or COR.desativado
		aba.BorderSizePixel = 2
		aba.Text = ICONE_CATEGORIA[categoria] .. "\n" .. categoria
		aba.TextColor3 = ativa and COR.fundo or COR.textoFraco
		aba.TextScaled = true
		aba.Font = Enum.Font.GothamBold
		aba.Parent = abasFrame

		aba.MouseButton1Click:Connect(function()
			tocar(SONS.clique)
			categoriaAtual = categoria
			renderizar()
		end)
	end

	-- ---------- LISTA ----------
	limpar(listaPassivas)

	if not personagemAtual then
		local aviso = Instance.new("TextLabel")
		aviso.Size = UDim2.new(1, 0, 0.25, 0)
		aviso.BackgroundTransparency = 1
		aviso.Text = "Escolha um personagem acima\npara ver e montar a build dele."
		aviso.TextColor3 = COR.aviso
		aviso.TextScaled = true
		aviso.TextWrapped = true
		aviso.Font = Enum.Font.GothamBold
		aviso.Parent = listaPassivas
		return
	end

	local ordem = 0
	for _, passiva in ipairs(dados.catalogo) do
		if passiva.categoria == categoriaAtual then
			ordem = ordem + 1
			montarCard(passiva, ordem)
		end
	end

	if ordem == 0 then
		local vazio = Instance.new("TextLabel")
		vazio.Size = UDim2.new(1, 0, 0.2, 0)
		vazio.BackgroundTransparency = 1
		vazio.Text = "Nenhuma passiva nesta categoria."
		vazio.TextColor3 = COR.textoFraco
		vazio.TextScaled = true
		vazio.Font = Enum.Font.Gotham
		vazio.Parent = listaPassivas
	end

	-- ---------- GAMEPASS ----------
	botaoGamepass.Visible = not dados.temGamepass

	if botaoSalvar then
		if bloqueado() then
			botaoSalvar.BackgroundColor3 = COR.desativado
			botaoSalvar.Text = "🔒 DESEQUIPE PARA SALVAR"
		else
			botaoSalvar.BackgroundColor3 = COR.bom
			botaoSalvar.Text = "💾 SALVAR BUILD"
		end
	end
end

-- =====================================
-- INTERFACE
-- =====================================

local function criarInterface()
	gui = Instance.new("ScreenGui")
	gui.Name = "PassiveMenuGui"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 45
	gui.Enabled = false
	gui.Parent = playerGui

	local principal = Instance.new("Frame")
	principal.Size = UDim2.new(isMobile and 0.95 or 0.8, 0, isMobile and 0.92 or 0.85, 0)
	principal.Position = UDim2.new(0.5, 0, 0.5, 0)
	principal.AnchorPoint = Vector2.new(0.5, 0.5)
	principal.BackgroundColor3 = COR.fundo
	principal.BorderColor3 = COR.destaque
	principal.BorderSizePixel = 4
	principal.Parent = gui

	-- CABEÇALHO
	local cabecalho = Instance.new("Frame")
	cabecalho.Size = UDim2.new(1, 0, 0.09, 0)
	cabecalho.BackgroundColor3 = COR.cabecalho
	cabecalho.BorderSizePixel = 0
	cabecalho.Parent = principal

	local titulo = Instance.new("TextLabel")
	titulo.Size = UDim2.new(0.6, 0, 1, 0)
	titulo.Position = UDim2.new(0.02, 0, 0, 0)
	titulo.BackgroundTransparency = 1
	titulo.Text = "🧬 HABILIDADES PASSIVAS"
	titulo.TextColor3 = COR.destaque
	titulo.TextScaled = true
	titulo.Font = Enum.Font.GothamBold
	titulo.TextXAlignment = Enum.TextXAlignment.Left
	titulo.Parent = cabecalho

	local fechar = Instance.new("TextButton")
	fechar.Size = UDim2.new(0.08, 0, 0.7, 0)
	fechar.Position = UDim2.new(0.9, 0, 0.15, 0)
	fechar.BackgroundColor3 = COR.ruim
	fechar.BorderSizePixel = 0
	fechar.Text = "✕"
	fechar.TextColor3 = COR.texto
	fechar.TextScaled = true
	fechar.Font = Enum.Font.GothamBold
	fechar.Parent = cabecalho

	-- (V3) AVISO DE BLOQUEIO
	avisoBloqueio = Instance.new("TextLabel")
	avisoBloqueio.Size = UDim2.new(0.96, 0, 0.05, 0)
	avisoBloqueio.Position = UDim2.new(0.02, 0, 0.095, 0)
	avisoBloqueio.BackgroundColor3 = COR.ruim
	avisoBloqueio.BorderSizePixel = 0
	avisoBloqueio.Text = ""
	avisoBloqueio.TextColor3 = COR.texto
	avisoBloqueio.TextScaled = true
	avisoBloqueio.Font = Enum.Font.GothamBold
	avisoBloqueio.Visible = false
	avisoBloqueio.Parent = principal

	-- (V3) SELETOR DE PERSONAGEM
	local rotuloSeletor = Instance.new("TextLabel")
	rotuloSeletor.Size = UDim2.new(0.96, 0, 0.035, 0)
	rotuloSeletor.Position = UDim2.new(0.02, 0, 0.15, 0)
	rotuloSeletor.BackgroundTransparency = 1
	rotuloSeletor.Text = "PERSONAGEM"
	rotuloSeletor.TextColor3 = COR.textoFraco
	rotuloSeletor.TextScaled = true
	rotuloSeletor.Font = Enum.Font.GothamBold
	rotuloSeletor.TextXAlignment = Enum.TextXAlignment.Left
	rotuloSeletor.Parent = principal

	seletorFrame = Instance.new("ScrollingFrame")
	seletorFrame.Size = UDim2.new(0.96, 0, 0.085, 0)
	seletorFrame.Position = UDim2.new(0.02, 0, 0.185, 0)
	seletorFrame.BackgroundColor3 = COR.fundo
	seletorFrame.BorderSizePixel = 0
	seletorFrame.ScrollBarThickness = 5
	seletorFrame.ScrollingDirection = Enum.ScrollingDirection.X
	seletorFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
	seletorFrame.AutomaticCanvasSize = Enum.AutomaticSize.X
	seletorFrame.Parent = principal

	local layoutSeletor = Instance.new("UIListLayout")
	layoutSeletor.FillDirection = Enum.FillDirection.Horizontal
	layoutSeletor.Padding = UDim.new(0.008, 0)
	layoutSeletor.Parent = seletorFrame

	-- INFO
	barraInfo = Instance.new("TextLabel")
	barraInfo.Size = UDim2.new(0.96, 0, 0.05, 0)
	barraInfo.Position = UDim2.new(0.02, 0, 0.28, 0)
	barraInfo.BackgroundColor3 = COR.painel
	barraInfo.BorderSizePixel = 0
	barraInfo.Text = ""
	barraInfo.TextColor3 = COR.texto
	barraInfo.TextScaled = true
	barraInfo.Font = Enum.Font.GothamBold
	barraInfo.Parent = principal

	-- ABAS
	abasFrame = Instance.new("Frame")
	abasFrame.Size = UDim2.new(0.96, 0, 0.07, 0)
	abasFrame.Position = UDim2.new(0.02, 0, 0.34, 0)
	abasFrame.BackgroundTransparency = 1
	abasFrame.Parent = principal

	-- LISTA
	listaPassivas = Instance.new("ScrollingFrame")
	listaPassivas.Size = UDim2.new(0.96, 0, 0.41, 0)
	listaPassivas.Position = UDim2.new(0.02, 0, 0.42, 0)
	listaPassivas.BackgroundColor3 = COR.painel
	listaPassivas.BorderColor3 = COR.desativado
	listaPassivas.BorderSizePixel = 2
	listaPassivas.ScrollBarThickness = 8
	listaPassivas.CanvasSize = UDim2.new(0, 0, 0, 0)
	listaPassivas.AutomaticCanvasSize = Enum.AutomaticSize.Y
	listaPassivas.Parent = principal

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0.015, 0)
	layout.Parent = listaPassivas

	-- STATUS
	rotuloStatus = Instance.new("TextLabel")
	rotuloStatus.Size = UDim2.new(0.96, 0, 0.045, 0)
	rotuloStatus.Position = UDim2.new(0.02, 0, 0.835, 0)
	rotuloStatus.BackgroundTransparency = 1
	rotuloStatus.Text = ""
	rotuloStatus.TextColor3 = COR.textoFraco
	rotuloStatus.TextScaled = true
	rotuloStatus.Font = Enum.Font.Gotham
	rotuloStatus.Parent = principal

	-- SALVAR
	local salvar = Instance.new("TextButton")
	botaoSalvar = salvar
	salvar.Size = UDim2.new(0.46, 0, 0.07, 0)
	salvar.Position = UDim2.new(0.02, 0, 0.885, 0)
	salvar.BackgroundColor3 = COR.bom
	salvar.BorderSizePixel = 0
	salvar.Text = "💾 SALVAR BUILD"
	salvar.TextColor3 = COR.texto
	salvar.TextScaled = true
	salvar.Font = Enum.Font.GothamBold
	salvar.Parent = principal

	-- GAMEPASS
	botaoGamepass = Instance.new("TextButton")
	botaoGamepass.Size = UDim2.new(0.50, 0, 0.07, 0)
	botaoGamepass.Position = UDim2.new(0.48, 0, 0.885, 0)
	botaoGamepass.BackgroundColor3 = COR.roxo
	botaoGamepass.BorderColor3 = COR.ouro
	botaoGamepass.BorderSizePixel = 2
	botaoGamepass.Text = "⭐ +3 SLOTS"
	botaoGamepass.TextColor3 = COR.texto
	botaoGamepass.TextScaled = true
	botaoGamepass.Font = Enum.Font.GothamBold
	botaoGamepass.Visible = false
	botaoGamepass.Parent = principal

	-- ---------- AÇÕES ----------
	fechar.MouseButton1Click:Connect(function()
		tocar(SONS.fechar)
		if _G.ClosePassiveMenu then
			_G.ClosePassiveMenu()
		end
	end)

	local salvando = false
	salvar.MouseButton1Click:Connect(function()
		if salvando then
			return -- trava contra toque repetido
		end
		if bloqueado() then
			tocar(SONS.erro)
			status(dados.motivoBloqueio or "Desequipe seu personagem.", COR.ruim)
			return
		end
		if not personagemAtual then
			tocar(SONS.erro)
			status("Escolha um personagem primeiro.", COR.aviso)
			return
		end

		salvando = true
		salvar.Text = "⏳ SALVANDO..."
		salvar.BackgroundColor3 = COR.desativado

		local pcallOk, ok, mensagem = pcall(function()
			return remoteEquipar:InvokeServer(personagemAtual, rascunho)
		end)

		if not pcallOk then
			ok, mensagem = false, "Erro de conexão."
		end

		salvar.Text = "💾 SALVAR BUILD"
		salvar.BackgroundColor3 = COR.bom
		salvando = false

		tocar(ok and SONS.compra or SONS.erro)
		status(mensagem or "", ok and COR.bom or COR.ruim)

		if ok then
			buscar()
			local p = personagemEscolhido()
			rascunho = copiar(p and p.passivas)
			renderizar()
		end
	end)

	botaoGamepass.MouseButton1Click:Connect(function()
		if not dados or not dados.gamepassId then
			return
		end
		tocar(SONS.clique)
		pcall(function()
			MarketplaceService:PromptGamePassPurchase(player, dados.gamepassId)
		end)
	end)
end

-- =====================================
-- ABRIR / FECHAR
-- =====================================

_G.OpenPassiveMenu = function()
	if not gui then
		return
	end

	if buscar() then
		-- (V3) Escolhe sozinho: o que estava equipado por último, ou
		-- o primeiro da lista. Poupa um toque na maioria das vezes.
		if not personagemAtual or not personagemEscolhido() then
			personagemAtual = dados.equipado
			if not personagemEscolhido() and dados.personagens and #dados.personagens > 0 then
				personagemAtual = dados.personagens[1].nome
			end
		end

		local p = personagemEscolhido()
		rascunho = copiar(p and p.passivas)
	end

	status("")
	renderizar()

	gui.Enabled = true
	aberto = true
	tocar(SONS.abrir)
end

_G.ClosePassiveMenu = function()
	if gui then
		gui.Enabled = false
	end
	aberto = false
end

-- =====================================
-- COMPRA DO GAMEPASS
-- =====================================
-- O servidor só relê o gamepass quando o jogador entra. Depois de
-- comprar no meio da sessão, precisamos reabrir os dados — por isso
-- o refresh aqui.

MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(comprador, idGamepass, comprou)
	if comprador ~= player or not comprou then
		return
	end
	if dados and idGamepass == dados.gamepassId then
		task.wait(2) -- deixa o Roblox propagar a posse
		buscar()
		renderizar()
		status("Slots extras liberados!", COR.bom)
		tocar(SONS.compra)
	end
end)

-- =====================================
-- INICIALIZAÇÃO
-- =====================================

criarInterface()

task.spawn(function()
	task.wait(3)
	buscar()
end)

task.spawn(function()
	local esperou = 0
	while not _G.RegisterMenuCategory and esperou < 15 do
		task.wait(0.5)
		esperou = esperou + 0.5
	end

	if _G.RegisterMenuCategory then
		_G.RegisterMenuCategory("PASSIVAS", "🧬", function()
			if _G.OpenPassiveMenu then
				_G.OpenPassiveMenu()
			end
		end, function()
			if _G.ClosePassiveMenu then
				_G.ClosePassiveMenu()
			end
		end, 9)

		print("[PASSIVE MENU V3] Registrado no Menu Unificado")
	else
		warn("[PASSIVE MENU V3] UnifiedMenuClient não encontrado")
	end
end)

print([[
╔══════════════════════════════════════════════════════╗
║  PASSIVE MENU CLIENT V3 — CARREGADO                 ║
╠══════════════════════════════════════════════════════╣
║  SUBSTITUI: PassiveMenuClient V2                     ║
║  REMOVER:   PassiveMenuClient V2                     ║
║  * Seletor de personagem (edição é DESEQUIPADO)      ║
╠══════════════════════════════════════════════════════╣
║  * 5 categorias em abas                              ║
║  * Nível 1-10 com barra e custo em moedas            ║
║  * EQUIPAR é rascunho; MELHORAR é imediato           ║
║  * Selo de EXCLUSIVA e TEMPORÁRIA                    ║
║  * Botão do gamepass (+3 slots) quando não tem       ║
╚══════════════════════════════════════════════════════╝
]])
