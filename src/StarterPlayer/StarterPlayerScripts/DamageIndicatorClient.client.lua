-- ============================================
-- DAMAGE INDICATOR CLIENT V1 — NÚMEROS DE DANO RETRO
-- Coloque em StarterPlayer > StarterPlayerScripts
-- Nome: "DamageIndicatorClient"
-- SUBSTITUI: dmgindicator
-- REMOVER:   dmgindicator
-- ============================================
-- Números de dano no estilo do resto do jogo: fonte Arcade, contorno
-- preto grosso de pixel art e a mesma paleta neon do HealthDisplay e
-- dos menus.
--
-- POR QUE POOL E NÃO CRIAR/DESTRUIR
--
-- Em luta boa saem vários números por segundo. Criar um BillboardGui,
-- um TextLabel e uma Part por golpe e jogar fora depois é lixo para o
-- coletor bem no momento em que o quadro não pode cair. Aqui existem
-- MAX_NUMEROS conjuntos, criados uma vez, reaproveitados em rodízio.
-- Quando estouram, o mais velho é reciclado — perder o número antigo é
-- melhor que perder quadro.
--
-- POR QUE UM Heartbeat SÓ
--
-- Um tween por número seria 28 tweens simultâneos disputando o mesmo
-- orçamento. E tween não faz arco: interpola em linha reta entre dois
-- pontos. O movimento aqui é balístico de verdade — velocidade inicial
-- para cima e para o lado, gravidade e arrasto integrados por quadro,
-- num único laço que atende todos os números vivos. Nada de
-- BodyVelocity: isto é UI, não corpo físico.
--
-- REUTILIZADO: paleta e fonte do HealthDisplay V8, o padrão de
-- integração por Heartbeat do CharacterSystemClient V12.
-- ============================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer

local CONFIG = {
	MAX_NUMEROS = 28,
	VIDA = 1.15, -- segundos que o número fica na tela

	-- Balística. GRAVIDADE é bem menor que a do mundo de propósito: com
	-- 196 studs/s² o número cai antes de dar tempo de ler.
	VELOCIDADE_SUBIDA = 11,
	ESPALHAMENTO = 4.5,
	GRAVIDADE = 26,
	ARRASTO = 1.6,

	-- Estouro de escala no nascimento, que é o que dá o "soco" do
	-- número aparecendo.
	PICO_ESCALA = 1.45,
	TEMPO_PICO = 0.09,
}

local CORES = {
	dano = Color3.fromRGB(255, 245, 200),
	pesado = Color3.fromRGB(255, 150, 30),
	cura = Color3.fromRGB(40, 230, 115),
	meu = Color3.fromRGB(0, 225, 255),
	emMim = Color3.fromRGB(225, 55, 70),
}

local remotes = ReplicatedStorage:WaitForChild("Remotes", 30)
local hitRemote = remotes and remotes:WaitForChild("DamageIndicatorHit", 30)
if not hitRemote then
	warn("[DAMAGE INDICATOR V1] DamageIndicatorHit ausente — o servidor está no place?")
	return
end

-- =====================================
-- POOL
-- =====================================

local pasta = Instance.new("Folder")
pasta.Name = "RetroDamageNumbers"
pasta.Parent = workspace

local pool = {}
local ativos = {}
local proximoLivre = 1

local function novoSlot(indice)
	-- A âncora existe só para o BillboardGui ter onde morar no mundo.
	-- Ela é local do cliente: não replica, não colide, não entra em
	-- raycast e o servidor nunca a enxerga.
	local ancora = Instance.new("Part")
	ancora.Name = "Ancora" .. indice
	ancora.Size = Vector3.new(0.2, 0.2, 0.2)
	ancora.Transparency = 1
	ancora.Anchored = true
	ancora.CanCollide = false
	ancora.CanQuery = false
	ancora.CanTouch = false
	ancora.Locked = true
	ancora.CastShadow = false
	ancora.Parent = pasta

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "Numero"
	billboard.Size = UDim2.fromScale(4, 2)
	billboard.AlwaysOnTop = true
	billboard.LightInfluence = 0
	billboard.MaxDistance = 150
	billboard.Enabled = false
	billboard.Parent = ancora

	local escala = Instance.new("UIScale")
	escala.Scale = 1
	escala.Parent = billboard

	local rotulo = Instance.new("TextLabel")
	rotulo.Size = UDim2.fromScale(1, 1)
	rotulo.BackgroundTransparency = 1
	rotulo.Font = Enum.Font.Arcade
	rotulo.TextScaled = true
	rotulo.Text = ""
	-- O contorno preto é o que dá a leitura de pixel art e o que faz o
	-- número continuar legível contra céu claro e contra parede escura.
	rotulo.TextStrokeColor3 = Color3.new(0, 0, 0)
	rotulo.TextStrokeTransparency = 0
	rotulo.Parent = billboard

	return {
		ancora = ancora,
		billboard = billboard,
		escala = escala,
		rotulo = rotulo,
		vivo = false,
	}
end

for i = 1, CONFIG.MAX_NUMEROS do
	pool[i] = novoSlot(i)
end

local function soltarSlot(slot)
	slot.vivo = false
	slot.billboard.Enabled = false
	ativos[slot] = nil
end

local function pegarSlot()
	-- Primeiro passe: um slot livre.
	for _ = 1, CONFIG.MAX_NUMEROS do
		local slot = pool[proximoLivre]
		proximoLivre = proximoLivre % CONFIG.MAX_NUMEROS + 1
		if not slot.vivo then
			return slot
		end
	end

	-- Todos ocupados: recicla o mais velho. Em tela cheia de números,
	-- o que está sumindo é o que menos falta faz.
	local maisVelho, idadeMaior = nil, -1
	for slot, estado in pairs(ativos) do
		if estado.idade > idadeMaior then
			idadeMaior = estado.idade
			maisVelho = slot
		end
	end
	if maisVelho then
		soltarSlot(maisVelho)
	end
	return maisVelho or pool[1]
end

-- =====================================
-- NASCIMENTO DE UM NÚMERO
-- =====================================

local function estiloDe(dados)
	if dados.tipo == "cura" then
		return CORES.cura, "+" .. tostring(dados.valor), 1
	end
	if dados.emMim then
		return CORES.emMim, "-" .. tostring(dados.valor), 1.15
	end
	if dados.meu and dados.tipo == "pesado" then
		return CORES.pesado, tostring(dados.valor) .. "!", 1.35
	end
	if dados.meu then
		return CORES.meu, tostring(dados.valor), 1.1
	end
	if dados.tipo == "pesado" then
		return CORES.pesado, tostring(dados.valor) .. "!", 1.2
	end
	return CORES.dano, tostring(dados.valor), 1
end

local function nascer(dados)
	local slot = pegarSlot()
	if not slot then
		return
	end

	local cor, texto, peso = estiloDe(dados)

	slot.rotulo.Text = texto
	slot.rotulo.TextColor3 = cor
	slot.rotulo.TextTransparency = 0
	slot.rotulo.TextStrokeTransparency = 0
	slot.escala.Scale = 0.4
	slot.billboard.Size = UDim2.fromScale(4 * peso, 2 * peso)
	slot.ancora.Position = dados.posicao
	slot.billboard.Enabled = true
	slot.vivo = true

	-- Espalhamento lateral aleatório: sem ele, dois golpes seguidos no
	-- mesmo alvo sobem exatamente na mesma linha e um esconde o outro.
	local angulo = math.random() * math.pi * 2
	local forca = CONFIG.ESPALHAMENTO * (0.4 + math.random() * 0.6)

	ativos[slot] = {
		posicao = dados.posicao,
		velocidade = Vector3.new(
			math.cos(angulo) * forca,
			CONFIG.VELOCIDADE_SUBIDA * (0.85 + math.random() * 0.3),
			math.sin(angulo) * forca
		),
		idade = 0,
		peso = peso,
	}
end

-- =====================================
-- UM LAÇO PARA TODOS
-- =====================================

RunService.Heartbeat:Connect(function(deltaTime)
	-- dt limitado: numa queda de FPS um passo grande jogaria o número
	-- para fora da tela antes de ele ser lido.
	local dt = math.min(deltaTime, 1 / 20)

	for slot, estado in pairs(ativos) do
		estado.idade += dt

		if estado.idade >= CONFIG.VIDA or not slot.ancora.Parent then
			soltarSlot(slot)
		else
			-- Balística: gravidade puxa, arrasto freia, posição integra.
			estado.velocidade = Vector3.new(
				estado.velocidade.X * (1 - CONFIG.ARRASTO * dt),
				estado.velocidade.Y - CONFIG.GRAVIDADE * dt,
				estado.velocidade.Z * (1 - CONFIG.ARRASTO * dt)
			)
			estado.posicao += estado.velocidade * dt
			slot.ancora.Position = estado.posicao

			-- Escala: sobe rápido até o pico e assenta. É o "soco".
			local escala
			if estado.idade < CONFIG.TEMPO_PICO then
				local t = estado.idade / CONFIG.TEMPO_PICO
				escala = 0.4 + (CONFIG.PICO_ESCALA - 0.4) * t
			else
				local t = math.min(
					(estado.idade - CONFIG.TEMPO_PICO) / (CONFIG.VIDA - CONFIG.TEMPO_PICO),
					1
				)
				escala = CONFIG.PICO_ESCALA + (1 - CONFIG.PICO_ESCALA) * t
			end
			slot.escala.Scale = escala

			-- Some só no terço final: apagar desde o começo tira tempo
			-- de leitura, que é o que o número existe para dar.
			local fracao = estado.idade / CONFIG.VIDA
			local alfa = fracao <= 0.66 and 0 or (fracao - 0.66) / 0.34
			slot.rotulo.TextTransparency = alfa
			slot.rotulo.TextStrokeTransparency = alfa
		end
	end
end)

hitRemote.OnClientEvent:Connect(function(dados)
	if type(dados) ~= "table" then
		return
	end
	if typeof(dados.posicao) ~= "Vector3" or type(dados.valor) ~= "number" then
		return
	end
	nascer(dados)
end)

-- O ScreenGui do jogo não reseta no respawn, mas a pasta no workspace
-- não sobrevive a um troca de mapa; se sumir, os slots são refeitos.
pasta.AncestryChanged:Connect(function(_, parent)
	if not parent then
		for slot in pairs(ativos) do
			soltarSlot(slot)
		end
	end
end)

print("[DAMAGE INDICATOR CLIENT V1] ✓ pronto —", CONFIG.MAX_NUMEROS, "slots")
