-- ============================================
-- DAMAGE ATTRIBUTION V4 — QUEM BATEU EM QUEM
-- Coloque em ServerScriptService
-- Nome: "DamageAttribution"
-- SUBSTITUI: DamageAttribution V3
-- REMOVER:   DamageAttribution V3
-- ============================================
-- (V4) JANELA DE ATAQUE — ATRIBUIÇÃO SEM MEXER EM NENHUMA TOOL
--
-- O motor do Roblox NÃO diz quem causou dano. Isso foi pedido à
-- Roblox em 2014 (`TakeDamage(dano, jogadorAtacante)`, justamente
-- para substituir o "confuso e não confiável" sistema de tag
-- creator) e nunca foi implementado. Também não dá para
-- sobrescrever `TakeDamage`: métodos de Instance não são
-- substituíveis em Luau.
--
-- MAS duas coisas SÃO possíveis de fora da Tool:
--   1. Escutar `Tool.Activated` de TODAS as Tools, sem editar
--      nenhuma (basta achar as Tools na Backpack e no Character).
--   2. Escutar a vida de todos os Humanoids.
--
-- Juntando as duas: se alguém perde vida logo depois de um jogador
-- ter ATIVADO uma Tool perto dele, foi esse jogador.
--
-- POR QUE ISSO É MUITO MELHOR QUE A PROXIMIDADE DO V3:
--   • exige ATAQUE de verdade — quem está parado do lado sem usar
--     nada nunca recebe crédito (era o furo do V3, que podia
--     culpar um aliado por dano de queda);
--   • sabe QUAL Tool foi usada, então o `DamageClass` sai da
--     própria Tool, sem etiquetar nada na mão;
--   • funciona com qualquer gear, inclusive as carregadas por
--     InsertService, sem editar uma linha delas.
--
-- ORDEM DE CONFIANÇA:
--   1. tag `creator`        (exato — escreve em LastAttacker)
--   2. _G.RegisterAttack    (exato — escreve em LastAttacker)
--   3. janela de ataque     (forte — palpite interno)
--   4. proximidade pura     (fraco — palpite interno, desligável)
--
-- Os níveis 3 e 4 NÃO escrevem em `LastAttacker`, pra não fazer o
-- TeamDamageProtection desfazer dano de queda achando que foi fogo
-- amigo. Quem quiser o palpite pede por getAttacker().
-- ============================================
-- (V3) A MUDANÇA QUE FAZ O BUFF DE DANO FUNCIONAR:
--
-- Suas Tools não usam a tag `creator` (confirmado no log: creator=0).
-- Sem atacante identificado, TODO buff de dano fica morto — só a
-- defesa da vítima entrava na conta. Era por isso que "defesa sim,
-- dano não".
--
-- O V2 tinha o fallback de proximidade, mas DESLIGADO, porque ligar
-- ele criava um problema pior: a proximidade escrevia na tag
-- `LastAttacker`, e o TeamDamageProtection lê essa tag. Levar dano
-- de queda perto de um aliado faria o sistema achar que foi fogo
-- amigo e DESFAZER o seu dano de queda.
--
-- ✅ SOLUÇÃO DO V3 — DUAS PISTAS SEPARADAS:
--   • ALTA CONFIANÇA (tag `creator`, `_G.RegisterAttack`): continua
--     escrevendo em `LastAttacker`, porque é confiável e o
--     TeamDamageProtection pode usar sem medo.
--   • PALPITE (proximidade): fica numa tabela INTERNA deste script.
--     Nunca toca no `LastAttacker`.
--
-- Quem quiser o palpite pede por `_G.DamageAttribution.getAttacker()`
-- — é o que o PassiveSystemServer V4 faz. Assim o buff de dano volta
-- a funcionar SEM arriscar o fogo amigo.
--
-- Por isso a proximidade agora vem LIGADA por padrão: ela ficou
-- segura.
-- ============================================
-- (V2) ALTERAÇÕES — CORREÇÃO DE DIAGNÓSTICO FALSO:
-- O V1 avisava "NENHUMA fonte identificou o atacante" assim que
-- houvesse 1 dano sem atacante. Isso estava ERRADO: dano de QUEDA,
-- de NPC, de lava e de kill por comando NÃO TÊM atacante jogador —
-- contar isso como falha é falso alarme. Pior: com 1 jogador sozinho
-- no servidor não existe PvP nenhum pra medir, então o aviso
-- disparava sempre.
-- Agora o aviso só sai quando:
--   • havia 2+ jogadores no servidor no momento do dano, E
--   • já houve pelo menos MIN_SAMPLE danos sem fonte, E
--   • nenhuma fonte confiável funcionou nenhuma vez.
-- Danos sem atacante com 1 jogador só são contados à parte, como
-- "ambiente", que é o comportamento CORRETO.
-- ============================================
-- O PROBLEMA:
-- O TeamDamageProtection V3 (linhas 269-271) CRIA a tag
-- `LastAttacker` dentro de cada personagem... e nunca preenche o
-- `.Value` dela. Nenhum outro script do projeto preenche também
-- (verificado com busca em todos os arquivos). Resultado: a tag
-- existe, mas está sempre vazia.
--
-- O QUE ISSO QUEBRA HOJE (tudo isso lê essa tag):
--   • TeamDamageProtection V3 — a restauração de dano de ALIADO
--     nunca dispara, porque `attacker` é sempre nil. Ou seja, hoje
--     você provavelmente CONSEGUE matar seu próprio time.
--   • CharacterLevelServer V1 — XP por dano em PvP nunca conta.
--   • PassiveSystemServer V2 — Vidro Trincado, Couraça, Vampírico,
--     Frenesi e Duelista não fazem efeito entre jogadores.
--
-- ⚠️ Nada disso é culpa dos scripts novos: a tag já era vazia antes.
--
-- ============================================
-- COMO ESTE SCRIPT DESCOBRE O ATACANTE
-- ============================================
-- Nenhum script do projeto aplica dano em jogador — o dano vem das
-- Tools, que são carregadas por InsertService e não dá pra ler o
-- código delas daqui. Então o script tenta 3 fontes, em ordem de
-- confiança, e AVISA NO OUTPUT qual delas funcionou:
--
-- 1) TAG `creator` (recomendada, precisa de zero configuração)
--    É a convenção clássica do Roblox: a arma cria um ObjectValue
--    chamado "creator" dentro do Humanoid da vítima ANTES de chamar
--    TakeDamage. Praticamente toda Tool de toolbox/free model faz
--    isso (a espada clássica faz). Como a tag é criada ANTES do
--    dano, não existe corrida de eventos: quando o dano acontece, o
--    LastAttacker já está preenchido.
--
-- 2) `_G.RegisterAttack` (se algum dia for instalado)
--    O projeto já espera essa função (MainSystemInitializer linha
--    147, marcada como opcional) e o TeamSystemServer linha 629 já
--    usa o padrão de embrulhar ela. Hoje ela NÃO existe no seu jogo
--    (você confirmou que o Output não mostra "kill detection
--    conectado"), mas se um dia for instalada, este script pega
--    sozinho, sem edição.
--
-- 3) PROXIMIDADE (desligada por padrão — leia o aviso)
--    Último recurso: credita o jogador vivo mais próximo no momento
--    do dano, igual à heurística que o NpcSystem V2 usa pra NPC.
--    ⚠️ SÓ LIGUE SE A OPÇÃO 1 NÃO FUNCIONAR. Ela chuta: se você
--    levar dano de queda perto de um aliado, o aliado pode ser
--    creditado — e aí o TeamDamageProtection DESFAZ o seu dano de
--    queda achando que foi fogo amigo.
--
-- ============================================
-- EXPIRAÇÃO DA TAG (importante)
-- ============================================
-- A tag é limpa depois de ATTRIBUTION_TIMEOUT segundos sem dano.
-- Sem isso, uma tag velha faria o jogo tratar dano de queda (ou de
-- NPC) como PvP minutos depois — dando lifesteal e XP pra alguém que
-- não encostou em você.
--
-- REUTILIZAÇÃO (nada criado do zero):
-- • Padrão de embrulho do _G.RegisterAttack ...... TeamSystemServer V3 (linha 629)
-- • Heurística do atacante mais próximo .......... NpcSystem V2
-- • Tag LastAttacker (nome e local) .............. TeamDamageProtection V3
-- ============================================

local Players = game:GetService("Players")

-- =====================================
-- CONFIGURAÇÃO
-- =====================================

local CONFIG = {
	-- Segundos que a atribuição vale. Depois disso a tag é limpa.
	ATTRIBUTION_TIMEOUT = 10,

	-- (V3) Agora LIGADO por padrão: o palpite de proximidade não
	-- escreve mais em `LastAttacker`, então não tem como causar o
	-- fogo amigo falso que travava isso no V2.
	USE_PROXIMITY_FALLBACK = true,
	PROXIMITY_RADIUS = 15,

	-- Quanto tempo um palpite de proximidade vale
	GUESS_TIMEOUT = 5,

	-- (V4) JANELA DE ATAQUE
	-- Quanto tempo depois de ativar uma Tool o jogador ainda é
	-- candidato a ter causado dano. Curto demais perde projétil
	-- lento; longo demais culpa quem já parou de atacar.
	ATTACK_WINDOW = 1.5,

	-- Distância máxima entre quem ativou a Tool e quem levou o dano.
	-- Generoso de propósito: arma de longo alcance existe.
	ATTACK_RANGE = 250,

	-- Imprime no Output cada atribuição e de qual fonte veio.
	-- Deixe LIGADO até descobrir o que suas Tools usam, depois
	-- desligue pra não poluir o log.
	DIAGNOSTIC_MODE = true,
	DIAGNOSTIC_INTERVAL = 30, -- resumo periódico no Output

	-- (V2) Quantos danos PvP sem fonte antes de reclamar. Evita o
	-- falso alarme que o V1 dava com 1 ou 2 quedas.
	MIN_SAMPLE = 8,
}

-- =====================================
-- ESTADO
-- =====================================

local attributionTime = {} -- [character] = os.clock() da última atribuição
local connections = {} -- [player] = { conexões }

-- (V3) PISTA INTERNA. Palpite de proximidade mora AQUI e nunca vai
-- pra tag `LastAttacker`. É isso que impede o TeamDamageProtection
-- de desfazer dano de queda achando que foi fogo amigo.
local guessAttacker = {} -- [character] = player
local guessTime = {} -- [character] = os.clock()

-- (V2) 'environment' = dano legítimo sem atacante (queda, NPC, lava).
-- 'none' = dano que DEVERIA ter atacante (havia 2+ jogadores) e não teve.
local stats = { creator = 0, registerAttack = 0, janela = 0, proximity = 0, none = 0, environment = 0 }
local sourcesSeen = {}

-- =====================================
-- TAG
-- =====================================

local function getTag(character)
	if not character then
		return nil
	end

	-- O TeamDamageProtection já cria essa tag. Reaproveita a dele em
	-- vez de criar uma segunda com o mesmo nome (dois objetos com o
	-- mesmo nome quebrariam o FindFirstChild dos outros sistemas).
	local tag = character:FindFirstChild("LastAttacker")
	if tag and tag:IsA("ObjectValue") then
		return tag
	end

	if not tag then
		tag = Instance.new("ObjectValue")
		tag.Name = "LastAttacker"
		tag.Parent = character
		return tag
	end

	return nil -- existe algo com esse nome que não é ObjectValue
end

local function setAttacker(victimCharacter, attacker, source)
	if not victimCharacter or not attacker then
		return false
	end
	if typeof(attacker) ~= "Instance" or not attacker:IsA("Player") then
		return false
	end

	-- Não creditar a própria vítima
	if attacker.Character == victimCharacter then
		return false
	end

	local tag = getTag(victimCharacter)
	if not tag then
		return false
	end

	tag.Value = attacker
	attributionTime[victimCharacter] = os.clock()

	stats[source] = (stats[source] or 0) + 1
	sourcesSeen[source] = true

	if CONFIG.DIAGNOSTIC_MODE then
		local victimPlayer = Players:GetPlayerFromCharacter(victimCharacter)
		print(
			string.format(
				"[ATTRIBUTION V4] %s -> %s (fonte: %s)",
				attacker.Name,
				victimPlayer and victimPlayer.Name or victimCharacter.Name,
				source
			)
		)
	end

	return true
end

local function isFresh(character)
	local time = attributionTime[character]
	if not time then
		return false
	end
	return (os.clock() - time) <= CONFIG.ATTRIBUTION_TIMEOUT
end

-- =====================================
-- FONTE 1: TAG `creator` (convenção clássica do Roblox)
-- =====================================
-- A arma faz: cria "creator" no Humanoid -> chama TakeDamage.
-- Como o ChildAdded dispara na hora em que a tag é parenteada, o
-- LastAttacker já está pronto quando o dano cai. Sem corrida.

local function watchCreatorTag(character, humanoid)
	local function handleCreator(child)
		if child.Name ~= "creator" or not child:IsA("ObjectValue") then
			return
		end

		-- O Value pode ser preenchido depois do Parent, dependendo da
		-- ordem da arma — então escuta a mudança também
		if child.Value then
			setAttacker(character, child.Value, "creator")
		end

		child:GetPropertyChangedSignal("Value"):Connect(function()
			if child.Value then
				setAttacker(character, child.Value, "creator")
			end
		end)
	end

	-- Tag que já exista no momento da conexão
	for _, child in ipairs(humanoid:GetChildren()) do
		handleCreator(child)
	end

	return humanoid.ChildAdded:Connect(handleCreator)
end

-- =====================================
-- FONTE 3: PROXIMIDADE (fallback opcional)
-- =====================================

local function findNearestPlayer(victimCharacter, victimPlayer)
	local hrp = victimCharacter:FindFirstChild("HumanoidRootPart")
	if not hrp then
		return nil
	end

	local closest = nil
	local closestDist = CONFIG.PROXIMITY_RADIUS

	for _, other in ipairs(Players:GetPlayers()) do
		if other ~= victimPlayer and other.Character then
			local otherHrp = other.Character:FindFirstChild("HumanoidRootPart")
			local otherHum = other.Character:FindFirstChildOfClass("Humanoid")

			if otherHrp and otherHum and otherHum.Health > 0 then
				local dist = (otherHrp.Position - hrp.Position).Magnitude
				if dist <= closestDist then
					closest = other
					closestDist = dist
				end
			end
		end
	end

	return closest
end

-- =====================================
-- (V4) RASTREIO UNIVERSAL DE TOOLS
-- =====================================
-- Nenhuma Tool é editada. O script encontra as Tools na Backpack e
-- no Character e se conecta ao `Activated` delas de fora — é o
-- mesmo mecanismo que o EnergySystemServer já usa pra cobrar
-- energia. Funciona com gear carregada por InsertService também.

local ultimoAtaque = {} -- [player] = { tool = Tool, tempo = os.clock() }
local toolConexoes = {} -- [player] = { [tool] = conexão }

local function registrarAtaque(player, tool)
	ultimoAtaque[player] = {
		tool = tool,
		tempo = os.clock(),
	}
end

local function ligarTool(player, tool)
	toolConexoes[player] = toolConexoes[player] or {}
	if toolConexoes[player][tool] then
		return
	end

	toolConexoes[player][tool] = tool.Activated:Connect(function()
		registrarAtaque(player, tool)
	end)
end

local function desligarTools(player)
	local mapa = toolConexoes[player]
	if not mapa then
		return
	end
	for _, conexao in pairs(mapa) do
		pcall(function()
			conexao:Disconnect()
		end)
	end
	toolConexoes[player] = nil
end

local function vigiarContainer(player, container)
	if not container then
		return
	end

	for _, item in ipairs(container:GetChildren()) do
		if item:IsA("Tool") then
			ligarTool(player, item)
		end
	end

	container.ChildAdded:Connect(function(item)
		if item:IsA("Tool") then
			ligarTool(player, item)
		end
	end)
end

-- Quem atacou há pouco tempo E está no alcance?
-- Entre vários candidatos, ganha o que atacou MAIS RECENTEMENTE.
local function candidatoPorJanela(victimCharacter, victimPlayer)
	local raizVitima = victimCharacter and victimCharacter:FindFirstChild("HumanoidRootPart")
	if not raizVitima then
		return nil
	end

	local agora = os.clock()
	local melhor = nil
	local melhorTempo = -1

	for outro, dados in pairs(ultimoAtaque) do
		if outro ~= victimPlayer and outro.Parent and dados.tempo > melhorTempo then
			if (agora - dados.tempo) <= CONFIG.ATTACK_WINDOW then
				local personagem = outro.Character
				local raiz = personagem and personagem:FindFirstChild("HumanoidRootPart")
				local humanoide = personagem and personagem:FindFirstChildOfClass("Humanoid")

				if raiz and humanoide and humanoide.Health > 0 then
					local distancia = (raiz.Position - raizVitima.Position).Magnitude
					if distancia <= CONFIG.ATTACK_RANGE then
						melhor = outro
						melhorTempo = dados.tempo
					end
				end
			end
		end
	end

	return melhor
end

-- Qual Tool o atacante usou. Serve pro PassiveSystemServer ler o
-- DamageClass da Tool CERTA, e não da que está na mão agora.
local function toolDoAtaque(player)
	local dados = ultimoAtaque[player]
	if not dados then
		return nil
	end
	if (os.clock() - dados.tempo) > CONFIG.ATTACK_WINDOW then
		return nil
	end
	return dados.tool
end

-- =====================================
-- (V3) PALPITE (NÃO ESCREVE NA TAG)
-- =====================================

local function setGuess(victimCharacter, attacker, fonte)
	fonte = fonte or "proximity"
	if not victimCharacter or not attacker then
		return false
	end
	if typeof(attacker) ~= "Instance" or not attacker:IsA("Player") then
		return false
	end
	if attacker.Character == victimCharacter then
		return false
	end

	guessAttacker[victimCharacter] = attacker
	guessTime[victimCharacter] = os.clock()

	stats[fonte] = (stats[fonte] or 0) + 1

	if CONFIG.DIAGNOSTIC_MODE then
		local victimPlayer = Players:GetPlayerFromCharacter(victimCharacter)
		print(
			string.format(
				"[ATTRIBUTION V4] %s -> %s (palpite: %s)",
				attacker.Name,
				victimPlayer and victimPlayer.Name or victimCharacter.Name,
				fonte
			)
		)
	end

	return true
end

-- Melhor informação disponível: tag confiável primeiro, palpite depois
local function getBestAttacker(character)
	if not character then
		return nil, nil
	end

	if isFresh(character) then
		local tag = character:FindFirstChild("LastAttacker")
		local value = tag and tag.Value
		if value and typeof(value) == "Instance" and value:IsA("Player") then
			return value, "confiavel"
		end
	end

	local guess = guessAttacker[character]
	local time = guessTime[character]
	if guess and time and (os.clock() - time) <= CONFIG.GUESS_TIMEOUT then
		if guess.Parent then
			return guess, "palpite"
		end
	end

	return nil, nil
end

-- =====================================
-- MONITOR DE DANO (só pra diagnóstico e fallback)
-- =====================================

local function watchDamage(character, humanoid, player)
	local lastHealth = humanoid.Health

	return humanoid.HealthChanged:Connect(function(health)
		if health >= lastHealth then
			lastHealth = health
			return
		end
		lastHealth = health

		-- Já foi atribuído por uma fonte confiável há pouco tempo
		if isFresh(character) then
			return
		end

		-- (V4) JANELA DE ATAQUE — antes da proximidade pura.
		-- Exige que alguém tenha ATIVADO uma Tool há pouco, perto.
		local porJanela = candidatoPorJanela(character, player)
		if porJanela then
			setGuess(character, porJanela, "janela")
			return
		end

		if CONFIG.USE_PROXIMITY_FALLBACK then
			local nearest = findNearestPlayer(character, player)
			if nearest then
				-- PALPITE, não atribuição: fica na tabela interna
				-- e NÃO escreve em LastAttacker
				setGuess(character, nearest, "proximity")
				return
			end
		end

		-- (V2) Sozinho no servidor não existe PvP: qualquer dano aqui
		-- é ambiente (queda, NPC, lava) e NÃO é falha de atribuição.
		if #Players:GetPlayers() < 2 then
			stats.environment = stats.environment + 1
		else
			stats.none = stats.none + 1
		end
	end)
end

-- =====================================
-- LIMPEZA DE TAG VELHA
-- =====================================
-- Sem isso, dano de queda 5 minutos depois de uma luta seria tratado
-- como PvP (com lifesteal e XP pro cara errado).

task.spawn(function()
	while true do
		task.wait(1)

		for _, player in ipairs(Players:GetPlayers()) do
			local character = player.Character
			if character and not isFresh(character) then
				local tag = character:FindFirstChild("LastAttacker")
				if tag and tag:IsA("ObjectValue") and tag.Value ~= nil then
					tag.Value = nil
					attributionTime[character] = nil
				end
			end
		end
	end
end)

-- =====================================
-- FONTE 2: EMBRULHO DO _G.RegisterAttack
-- =====================================
-- Padrão REUTILIZADO do TeamSystemServer V3 (linha 629).
-- Hoje essa função não existe no seu jogo; o loop abaixo espera um
-- pouco caso ela seja instalada depois.

task.spawn(function()
	local waited = 0
	while not _G.RegisterAttack and waited < 20 do
		task.wait(0.5)
		waited = waited + 0.5
	end

	if not _G.RegisterAttack then
		print("[ATTRIBUTION V4] _G.RegisterAttack não existe neste jogo — usando tag 'creator'")
		return
	end

	local original = _G.RegisterAttack

	_G.RegisterAttack = function(attacker, victim)
		local victimCharacter = victim and victim.Character
		if victimCharacter and attacker then
			setAttacker(victimCharacter, attacker, "registerAttack")
		end
		return original(attacker, victim)
	end

	print("[ATTRIBUTION V4] _G.RegisterAttack embrulhado com sucesso")
end)

-- =====================================
-- EVENTOS DE JOGADOR
-- =====================================

local function cleanupPlayer(player)
	desligarTools(player)
	ultimoAtaque[player] = nil
	local character = player.Character
	if character then
		guessAttacker[character] = nil
		guessTime[character] = nil
	end
	if connections[player] then
		for _, connection in ipairs(connections[player]) do
			pcall(function()
				connection:Disconnect()
			end)
		end
	end
	connections[player] = nil
end

local function onCharacterAdded(player, character)
	cleanupPlayer(player)
	connections[player] = {}

	local humanoid = character:WaitForChild("Humanoid", 10)
	if not humanoid then
		return
	end

	-- Garante que a tag exista mesmo se o TeamDamageProtection ainda
	-- não tiver criado
	getTag(character)

	table.insert(connections[player], watchCreatorTag(character, humanoid))
	table.insert(connections[player], watchDamage(character, humanoid, player))

	-- (V4) Liga nas Tools SEM editar nenhuma delas
	desligarTools(player)
	vigiarContainer(player, player:FindFirstChildOfClass("Backpack"))
	vigiarContainer(player, character)
end

local function onPlayerAdded(player)
	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(player, character)
	end)

	if player.Character then
		onCharacterAdded(player, player.Character)
	end
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(cleanupPlayer)

for _, player in ipairs(Players:GetPlayers()) do
	onPlayerAdded(player)
end

-- =====================================
-- DIAGNÓSTICO PERIÓDICO
-- =====================================

task.spawn(function()
	while CONFIG.DIAGNOSTIC_MODE do
		task.wait(CONFIG.DIAGNOSTIC_INTERVAL)

		local total = stats.creator + stats.registerAttack + (stats.janela or 0) + stats.proximity
		if total > 0 or stats.none > 0 or stats.environment > 0 then
			print(
				string.format(
					"[ATTRIBUTION V4] Resumo: creator=%d | registerAttack=%d | janela=%d | proximidade=%d "
						.. "|| ambiente(ok)=%d | PvP sem fonte=%d",
					stats.creator,
					stats.registerAttack,
					stats.janela or 0,
					stats.proximity,
					stats.environment,
					stats.none
				)
			)

			-- (V2) Só reclama com amostra REAL de PvP. Dano de queda /
			-- NPC / lava não conta como falha.
			if total == 0 and stats.none >= CONFIG.MIN_SAMPLE then
				warn(
					"[ATTRIBUTION V4] "
						.. stats.none
						.. " danos entre jogadores sem atacante identificado. "
						.. "Suas Tools não usam a tag 'creator'. "
						.. "Ligue USE_PROXIMITY_FALLBACK = true no CONFIG, ou me avise."
				)
			elseif total == 0 and stats.environment > 0 and stats.none == 0 then
				print(
					"[ATTRIBUTION V4] Só houve dano de ambiente até agora (queda/NPC). "
						.. "Isso é NORMAL. O teste de PvP precisa de 2 jogadores se batendo."
				)
			end
		end
	end
end)

-- =====================================
-- API GLOBAL
-- =====================================

_G.DamageAttribution = {
	CONFIG = CONFIG,

	-- Uma Tool ou sistema pode creditar dano manualmente:
	-- _G.DamageAttribution.register(atacante, personagemDaVitima)
	register = function(attacker, victimCharacter)
		return setAttacker(victimCharacter, attacker, "registerAttack")
	end,

	-- (V3) Devolve a MELHOR informação: tag confiável ou palpite.
	-- É isto que o PassiveSystemServer V4 usa pra aplicar buff de
	-- dano mesmo sem a tag `creator`.
	getAttacker = function(character)
		local attacker = getBestAttacker(character)
		return attacker
	end,

	-- Igual, mas diz TAMBÉM de onde veio ("confiavel" ou "palpite"),
	-- pra quem precisar decidir se confia
	getAttackerWithSource = getBestAttacker,

	-- (V4) Qual Tool o jogador acabou de usar. O
	-- PassiveSystemServer usa isto pra ler o DamageClass da Tool
	-- CERTA — e não da que estiver na mão no momento da conta.
	getAttackTool = toolDoAtaque,

	-- (V4) Registro manual de ataque, se alguma gear quiser avisar
	registerAttack = function(player, tool)
		if player and typeof(player) == "Instance" and player:IsA("Player") then
			registrarAtaque(player, tool)
			return true
		end
		return false
	end,

	-- Só a informação CONFIÁVEL (o que está na tag). Use isto pra
	-- decisões sensíveis, tipo desfazer fogo amigo.
	getTrustedAttacker = function(character)
		if not character or not isFresh(character) then
			return nil
		end
		local tag = character:FindFirstChild("LastAttacker")
		return tag and tag.Value or nil
	end,

	getStats = function()
		return {
			creator = stats.creator,
			registerAttack = stats.registerAttack,
			janela = stats.janela or 0,
			proximity = stats.proximity,
			none = stats.none,
			environment = stats.environment,
		}
	end,
}

_G.DebugAttribution = function()
	print("\n========== DEBUG DAMAGE ATTRIBUTION V2 ==========")
	print(string.format("Jogadores no servidor . %d", #Players:GetPlayers()))
	print(string.format("Tag 'creator' ......... %d atribuições", stats.creator))
	print(string.format("_G.RegisterAttack ..... %d atribuições", stats.registerAttack))
	print(string.format("Janela de ataque ...... %d atribuições  <- não precisa editar Tool", stats.janela or 0))
	print(string.format("Proximidade ........... %d atribuições", stats.proximity))
	print(string.format("Ambiente (normal) ..... %d  <- queda/NPC/lava, sem atacante", stats.environment))
	print(string.format("PvP sem fonte ......... %d  <- este é o número que importa", stats.none))
	print(string.format("Fallback de proximidade: %s", CONFIG.USE_PROXIMITY_FALLBACK and "LIGADO" or "desligado"))

	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		if character then
			local tag = character:FindFirstChild("LastAttacker")
			local value = tag and tag.Value
			print(
				string.format(
					"  %s <- %s%s",
					player.Name,
					value and value.Name or "(ninguém)",
					isFresh(character) and "" or " [expirado]"
				)
			)
		end
	end
	print("=====================================\n")
end

print([[
╔══════════════════════════════════════════════════════╗
║  DAMAGE ATTRIBUTION V4 — CARREGADO                  ║
╠══════════════════════════════════════════════════════╣
║  SUBSTITUI: DamageAttribution V3                     ║
║  REMOVER:   DamageAttribution V3                     ║
╠══════════════════════════════════════════════════════╣
║  NOVO NO V4 — JANELA DE ATAQUE:                      ║
║  * Escuta Activated de TODAS as Tools, sem editar    ║
║    nenhuma (nem as de InsertService)                 ║
║  * Quem ativou Tool há <1.5s e está no alcance leva  ║
║    o crédito — parado do lado NÃO conta              ║
║  * Sabe QUAL Tool foi usada -> DamageClass sai dela  ║
╠══════════════════════════════════════════════════════╣
║  Ordem: creator > RegisterAttack > janela > proximo  ║
╠══════════════════════════════════════════════════════╣
║  Preenche a tag LastAttacker, que hoje fica sempre   ║
║  VAZIA no projeto. Sem ela não funciona:             ║
║   * restauração de dano de aliado (TeamDamage V3)    ║
║   * XP por dano em PvP (CharacterLevel V1)           ║
║   * passivas de dano em PvP (PassiveSystem V2)       ║
╠══════════════════════════════════════════════════════╣
║  MODO DIAGNÓSTICO LIGADO — o Output vai mostrar de   ║
║  onde veio cada atribuição. Veja o resumo a cada 30s.║
╠══════════════════════════════════════════════════════╣
║  DEBUG: _G.DebugAttribution()                        ║
╚══════════════════════════════════════════════════════╝
]])
