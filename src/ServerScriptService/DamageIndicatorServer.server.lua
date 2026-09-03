-- ============================================
-- DAMAGE INDICATOR SERVER V1 — NÚMEROS DE DANO
-- Coloque em ServerScriptService
-- Nome: "DamageIndicatorServer"
-- SUBSTITUI: dmgindi
-- REMOVER:   dmgindi
-- ============================================
-- Quem decide QUANTO apareceu na tela é o servidor. O cliente só
-- desenha. Deixar o cliente ler a vida alheia e inventar o número
-- daria a ele a chance de mostrar dano que não aconteceu, e o número
-- ficaria fora de sincronia com o HealthDisplay.
--
-- TRÊS DECISÕES QUE DEFINEM ESTE SCRIPT
--
-- 1. ACUMULA ANTES DE MANDAR. Dano contínuo (queimadura, veneno,
--    metralhadora) chega em fatias de 1 ou 2 de vida por tique. Um
--    número por tique enche a tela de "1" e esconde a luta. As fatias
--    do mesmo alvo somam dentro de uma janela curta e saem como um
--    número só.
--
-- 2. SÓ VÊ QUEM ESTÁ PERTO. FireAllClients mandaria todo golpe do mapa
--    para todo mundo — banda desperdiçada em número que ninguém vê,
--    porque está a 500 studs atrás de uma parede. O servidor escolhe
--    os destinatários por distância.
--
-- 3. QUEM BATEU RECEBE MARCADO. O DamageAttribution já sabe quem
--    causou o dano; esse dado vai junto para o cliente do atacante
--    desenhar o próprio acerto maior e mais forte que o dos outros.
--
-- REUTILIZADO: padrão de ensureRemote do DuelSystemServer V3, e a
-- atribuição de dano do DamageAttribution V4.
-- ============================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CONFIG = {
	-- Distância máxima entre a câmera de quem assiste e o alvo. Acima
	-- disso o número sairia menor que um pixel de qualquer jeito.
	RAIO_VISIVEL = 140,

	-- Janela de acúmulo. Curta o bastante para o número ainda parecer
	-- resposta ao golpe, longa o bastante para juntar as fatias de um
	-- dano contínuo.
	JANELA = 0.12,

	-- Abaixo disso não vale poluir a tela.
	DANO_MINIMO = 1,

	-- Teto por vítima em um envio. Protege contra um bug de outro
	-- sistema virar enxurrada de RemoteEvent.
	MAX_POR_SEGUNDO = 12,

	-- Fração da vida máxima que conta como golpe pesado. O cliente
	-- desenha esse caso maior e em outra cor.
	FRACAO_PESADO = 0.12,

	MOSTRAR_CURA = true,
}

local remotes = ReplicatedStorage:FindFirstChild("Remotes")
if not remotes then
	remotes = Instance.new("Folder")
	remotes.Name = "Remotes"
	remotes.Parent = ReplicatedStorage
end

local function ensureRemote(name, className)
	local remote = remotes:FindFirstChild(name)
	if remote and not remote:IsA(className) then
		remote.Parent = nil
		remote = nil
	end
	if not remote then
		remote = Instance.new(className)
		remote.Name = name
		remote.Parent = remotes
	end
	return remote
end

local hitRemote = ensureRemote("DamageIndicatorHit", "RemoteEvent")

-- =====================================
-- ACÚMULO POR VÍTIMA
-- =====================================

-- [character] = { total, cura, ultimoEnvio, agendado, enviosNoSegundo, janelaSegundo }
local pendentes = {}

local function posicaoDoAlvo(character)
	local raiz = character:FindFirstChild("HumanoidRootPart")
		or character:FindFirstChild("Head")
	if raiz and raiz:IsA("BasePart") then
		-- Um pouco acima do peito: na cabeça o número briga com o
		-- nome do jogador, e no meio do corpo some atrás dele.
		return raiz.Position + Vector3.new(0, 2.4, 0)
	end
	return nil
end

local function destinatarios(posicao)
	local lista = {}
	for _, player in ipairs(Players:GetPlayers()) do
		local personagem = player.Character
		local raiz = personagem and personagem:FindFirstChild("HumanoidRootPart")
		if raiz and raiz:IsA("BasePart") then
			if (raiz.Position - posicao).Magnitude <= CONFIG.RAIO_VISIVEL then
				table.insert(lista, player)
			end
		end
	end
	return lista
end

local function despachar(character)
	local dados = pendentes[character]
	if not dados then
		return
	end
	dados.agendado = false

	local posicao = posicaoDoAlvo(character)
	if not posicao then
		pendentes[character] = nil
		return
	end

	local agora = os.clock()
	if agora - dados.janelaSegundo >= 1 then
		dados.janelaSegundo = agora
		dados.enviosNoSegundo = 0
	end
	if dados.enviosNoSegundo >= CONFIG.MAX_POR_SEGUNDO then
		dados.total = 0
		dados.cura = 0
		return
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local vidaMaxima = humanoid and humanoid.MaxHealth or 100
	local vitima = Players:GetPlayerFromCharacter(character)

	local envios = {}
	if dados.total >= CONFIG.DANO_MINIMO then
		table.insert(envios, {
			valor = math.floor(dados.total + 0.5),
			tipo = dados.total >= vidaMaxima * CONFIG.FRACAO_PESADO and "pesado" or "dano",
		})
	end
	if CONFIG.MOSTRAR_CURA and dados.cura >= CONFIG.DANO_MINIMO then
		table.insert(envios, { valor = math.floor(dados.cura + 0.5), tipo = "cura" })
	end

	dados.total = 0
	dados.cura = 0

	if #envios == 0 then
		return
	end

	-- Quem bateu, para o cliente dele desenhar o próprio acerto com
	-- mais peso. É palpite do DamageAttribution, então pode vir nil —
	-- e nesse caso ninguém recebe destaque, que é o certo.
	local atacante = nil
	if _G.DamageAttribution and _G.DamageAttribution.getAttacker then
		local ok, resultado = pcall(_G.DamageAttribution.getAttacker, character)
		if ok then
			atacante = resultado
		end
	end

	dados.enviosNoSegundo += 1

	for _, envio in ipairs(envios) do
		for _, player in ipairs(destinatarios(posicao)) do
			hitRemote:FireClient(player, {
				posicao = posicao,
				valor = envio.valor,
				tipo = envio.tipo,
				meu = atacante ~= nil and player == atacante,
				emMim = vitima ~= nil and player == vitima,
			})
		end
	end
end

local function acumular(character, dano, cura)
	local dados = pendentes[character]
	if not dados then
		dados = {
			total = 0,
			cura = 0,
			agendado = false,
			enviosNoSegundo = 0,
			janelaSegundo = os.clock(),
		}
		pendentes[character] = dados
	end

	dados.total += dano
	dados.cura += cura

	if dados.agendado then
		return
	end
	dados.agendado = true

	-- Um task.delay por janela, não por tique de dano: é o que torna o
	-- acúmulo barato mesmo com dano contínuo em vários alvos.
	task.delay(CONFIG.JANELA, function()
		despachar(character)
	end)
end

-- =====================================
-- VIGIA DA VIDA
-- =====================================

local function vigiar(character)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
		or character:WaitForChild("Humanoid", 10)
	if not humanoid or not humanoid:IsA("Humanoid") then
		return
	end

	local ultimaVida = humanoid.Health

	local conexao
	conexao = humanoid.HealthChanged:Connect(function(vida)
		local diferenca = ultimaVida - vida
		ultimaVida = vida

		if humanoid.Health <= 0 then
			return
		end

		if diferenca > 0 then
			acumular(character, diferenca, 0)
		elseif diferenca < 0 then
			acumular(character, 0, -diferenca)
		end
	end)

	-- Sem isto, cada respawn deixaria a conexão anterior viva e o
	-- personagem antigo nunca sairia de `pendentes`.
	humanoid.Died:Connect(function()
		conexao:Disconnect()
		pendentes[character] = nil
	end)

	character.AncestryChanged:Connect(function(_, parent)
		if not parent then
			conexao:Disconnect()
			pendentes[character] = nil
		end
	end)
end

local function ligarJogador(player)
	if player.Character then
		task.spawn(vigiar, player.Character)
	end
	player.CharacterAdded:Connect(function(character)
		task.spawn(vigiar, character)
	end)
end

for _, player in ipairs(Players:GetPlayers()) do
	ligarJogador(player)
end
Players.PlayerAdded:Connect(ligarJogador)

Players.PlayerRemoving:Connect(function(player)
	if player.Character then
		pendentes[player.Character] = nil
	end
end)

-- NPCs e chefões: qualquer Model com Humanoid que não seja de jogador
-- também merece número. É o mesmo vigia, só que descoberto pelo
-- workspace em vez de pelo Players.
local function vigiarNaoJogador(instancia)
	if not instancia:IsA("Model") then
		return
	end
	if Players:GetPlayerFromCharacter(instancia) then
		return
	end
	local humanoid = instancia:FindFirstChildOfClass("Humanoid")
	if humanoid then
		task.spawn(vigiar, instancia)
	end
end

for _, instancia in ipairs(workspace:GetChildren()) do
	vigiarNaoJogador(instancia)
end
workspace.ChildAdded:Connect(function(instancia)
	task.defer(vigiarNaoJogador, instancia)
end)

-- =====================================
-- API PARA OUTROS SISTEMAS
-- =====================================
-- Um sistema que aplique dano por conta própria (habilidade, passiva,
-- chefão) pode pedir o número na hora, sem esperar o HealthChanged.
_G.DamageIndicator = {
	mostrar = function(character, valor, tipo)
		if typeof(character) ~= "Instance" or not character:IsA("Model") then
			return false
		end
		local numero = tonumber(valor)
		if not numero or numero < CONFIG.DANO_MINIMO then
			return false
		end
		if tipo == "cura" then
			acumular(character, 0, numero)
		else
			acumular(character, numero, 0)
		end
		return true
	end,
}

print("[DAMAGE INDICATOR SERVER V1] ✓ pronto — remote DamageIndicatorHit")
