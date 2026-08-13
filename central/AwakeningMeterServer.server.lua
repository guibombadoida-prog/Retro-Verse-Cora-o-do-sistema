-- ============================================
-- AWAKENING METER SERVER V2
-- ============================================
-- (V2) A BARRA NÃO APARECIA — duas causas somadas:
--
-- 1. O PACOTE INICIAL SE PERDIA. O servidor só empurrava o estado
--    quando algo MUDAVA. O pacote com ativo=true saía assim que a
--    definição era resolvida, mas nesse instante o cliente ainda estava
--    no WaitForChild esperando o remote aparecer. O pacote se perdia,
--    nada mais mudava, nenhum outro saía — e a barra ficava invisível
--    para sempre. Agora existe o remote GetAwakeningMeter, que o cliente
--    PUXA ao conectar, mais um batimento de 2 em 2 segundos.
--
-- 2. (No HealthDisplay) a barra estava posicionada em cima do texto de
--    energia e passando do fim do container. Virou faixa própria logo
--    abaixo do container.
--
-- _G.DebugAwakeningMeter() agora diz POR QUE a barra está escondida.
-- Coloque em ServerScriptService
-- Nome: "AwakeningMeterServer"
-- ============================================
-- A BARRA DE DESPERTAR — o Despertar deixa de ser um personagem
-- separado e vira uma FORMA TEMPORÁRIA do personagem normal.
--
-- COMO FUNCIONA
--   1. O jogador equipa o personagem normal, com as Tools normais.
--   2. Batendo e apanhando, a barra sobe.
--   3. Barra cheia -> as Tools normais SAEM e as do Despertar ENTRAM.
--   4. Passado o tempo da forma, as Tools voltam a ser as normais.
--   5. Começa o cooldown: durante ele a barra não sobe.
--
--   Morrer desperto encerra a forma e ZERA a barra.
--
-- POR QUE O HOOK É NO HealthChanged
-- O dano no projeto sai de vários lugares: NucleoCombate_V2,
-- StatusEffectServer, PassiveSystemServer (reverso), NPCs e Tools de
-- toolbox. Enganchar em cada um seria frágil e exigiria editar o núcleo
-- de combate. HealthChanged pega TODOS, venha de onde vier, e o
-- _G.DamageAttribution já sabe dizer quem bateu.
--
-- DEPENDE DE:
--   • _G.PlayerDataManager    (DataManager)
--   • _G.AwakeningSystem      (AwakeningSystemServer — definições)
--   • _G.DamageAttribution    (quem causou o dano)
--   • _G.GameManagerConfig    (reapplyEquippedTools — troca as Tools)
--
-- PUBLICA:
--   • _G.AwakeningMeter       (estaDesperto / getEstado / forcar)
--   • _G.DebugAwakeningMeter
--
-- ⚠️ O GameManager precisa consultar _G.AwakeningMeter.estaDesperto()
--    para decidir de qual pasta tirar as Tools. Sem essa linha lá, a
--    barra enche e nada acontece.
-- ============================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

repeat
	task.wait()
until _G.PlayerDataManager and _G.AwakeningSystem

-- =====================================
-- CONFIGURAÇÃO PADRÃO
-- =====================================

-- Cada Despertar pode sobrescrever isto pela definição do admin
-- (campos medidorMax, duracao, cooldown, ganhoDano, ganhoRecebido).
local CONFIG = {
	MEDIDOR_MAX = 100,

	-- Quanto de barra cada ponto de dano vale.
	-- Bater rende mais do que apanhar: quem foge de briga não desperta.
	GANHO_POR_DANO_CAUSADO = 0.35,
	GANHO_POR_DANO_RECEBIDO = 0.20,

	DURACAO = 20, -- segundos desperto
	COOLDOWN = 45, -- segundos sem poder encher

	-- Trava anti-abuso: dano de um golpe só não pode encher a barra
	-- inteira. Sem isso, uma Tool com dano altíssimo desperta de
	-- primeira e o medidor perde a função.
	GANHO_MAXIMO_POR_GOLPE = 25,

	INTERVALO_SYNC = 0.25, -- com que frequência o cliente é avisado
	BATIMENTO = 2, -- reenvia o estado a cada N segundos mesmo parado
}

-- =====================================
-- REMOTE
-- =====================================

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

local meterUpdate = ensureRemote("AwakeningMeterUpdate", "RemoteEvent")

-- ⚠️ ESTE REMOTE EXISTE POR UM MOTIVO ESPECÍFICO.
--
-- O servidor só empurrava o estado quando algo MUDAVA. Só que o cliente
-- leva um tempo para conectar o OnClientEvent (ele espera a pasta
-- Remotes e o próprio remote aparecerem), e nesse meio-tempo o pacote
-- inicial já tinha passado. Depois disso nada mudava, então nenhum outro
-- pacote saía — e a barra ficava invisível para sempre.
--
-- Com isto o cliente PUXA o estado assim que estiver pronto, em vez de
-- torcer para ter chegado a tempo.
local getMeterState = ensureRemote("GetAwakeningMeter", "RemoteFunction")

-- =====================================
-- ESTADO
-- =====================================

-- estado[player] = {
--   valor, max, desperto, terminaEm, cooldownAte, personagem, sujo
-- }
local estado = {}
local montarPacote -- definida abaixo, usada pelo laço de sync

local function novoEstado()
	return {
		valor = 0,
		max = CONFIG.MEDIDOR_MAX,
		desperto = false,
		terminaEm = 0,
		cooldownAte = 0,
		personagem = nil,
		def = nil, -- definição do Despertar em cache (ver resolverDefinicao)
		sujo = true,
	}
end

local function getEstado(player)
	if not estado[player] then
		estado[player] = novoEstado()
	end
	return estado[player]
end

-- =====================================
-- DEFINIÇÃO DO DESPERTAR DO PERSONAGEM EQUIPADO
-- =====================================

-- ⚠️ NÃO LEIA `data.equippedCharacter` AQUI.
--
-- O savePlayerData do DataManager faz `data.equippedCharacter = nil` no
-- cache VIVO antes de gravar (de propósito: equipar não persiste entre
-- sessões), e o autosave roda a cada 30 segundos. Quem lê esse campo vê
-- o jogador como "sem personagem" a cada meio minuto.
--
-- Foi exatamente isso que fazia a barra SUMIR sozinha: o laço de troca
-- de personagem via `nil ~= nome`, achava que o jogador tinha trocado,
-- zerava a barra e marcava ativo = false. E o definicaoAtiva também
-- passava a devolver nil, então a barra parava de encher.
--
-- A fonte viva é o GameManager, que guarda o equipado em memória.
local function personagemEquipado(player)
	if _G.GameManagerConfig and _G.GameManagerConfig.getEquippedCharacter then
		local ok, nome = pcall(_G.GameManagerConfig.getEquippedCharacter, player)
		if ok and type(nome) == "string" and nome ~= "" then
			return nome
		end
		-- GameManager presente e sem personagem equipado: é nil de verdade
		if ok then
			return nil
		end
	end

	-- Reserva, só se o GameManager não estiver disponível
	local dados = _G.PlayerDataManager.getPlayerData(player)
	return dados and dados.equippedCharacter or nil
end

-- Declarada aqui porque atualizarPersonagem precisa dela e a definição
-- real vem mais abaixo, junto com o resto da troca de forma.
local remontarTools

local function configDe(def, chave, padrao)
	local v = def and tonumber(def[chave])
	if v and v > 0 then
		return v
	end
	return padrao
end

-- ⚠️ ESTA FUNÇÃO FAZ CHAMADA WEB (UserHasBadgeAsync). Nunca chame por
-- golpe nem no laço de sync — o resultado fica no cache do jogador
-- (e.def), renovado só quando o personagem equipado muda.
local function resolverDefinicao(player, nome)
	if not nome then
		return nil
	end

	local def = _G.AwakeningSystem.getDefinition(nome)
	if not def then
		return nil
	end

	-- (V5 do AwakeningSystemServer) O Badge virou OPCIONAL: se o admin
	-- configurou um, ele gateia; se deixou em branco, o Despertar é de
	-- quem tem o personagem.
	local badgeId = tonumber(def.badgeId)
	if badgeId and badgeId > 0 then
		local ok, tem = pcall(function()
			return game:GetService("BadgeService"):UserHasBadgeAsync(player.UserId, badgeId)
		end)
		if not ok or not tem then
			return nil
		end
	end

	return def
end

-- Lê do cache. É isto que o resto do script usa.
local function definicaoAtiva(player)
	local e = estado[player]
	if not e then
		return nil
	end
	return e.def, e.personagem
end

-- Renova o cache quando o personagem equipado muda. Chamada pelo laço
-- de 1 em 1 segundo e no spawn.
local function atualizarPersonagem(player)
	local e = getEstado(player)
	local atual = personagemEquipado(player)

	if atual == e.personagem then
		return
	end

	-- Trocou de personagem de verdade
	local estavaDesperto = e.desperto

	if e.desperto then
		e.desperto = false
		e.terminaEm = 0
	end

	e.personagem = atual
	e.valor = 0
	e.def = nil
	e.sujo = true

	-- Trocar de personagem ENQUANTO DESPERTO deixaria o jogador com as
	-- Tools despertadas do personagem novo: no momento do equipar o
	-- estaDesperto ainda respondia true, e o GameManager tirou as Tools
	-- da pasta AwakenedForm. Como a forma acabou de ser encerrada aqui,
	-- remontar devolve as Tools normais.
	if estavaDesperto and atual and remontarTools then
		remontarTools(player)
	end

	if atual then
		-- pcall + task.spawn: a checagem de Badge é web e pode demorar
		task.spawn(function()
			local def = resolverDefinicao(player, atual)
			local atualDepois = estado[player]
			-- Se o jogador trocou de personagem enquanto a checagem
			-- rodava, este resultado é velho: descarta.
			if atualDepois and atualDepois.personagem == atual then
				atualDepois.def = def
				atualDepois.max = configDe(def, "medidorMax", CONFIG.MEDIDOR_MAX)
				atualDepois.sujo = true
			end
		end)
	end
end

-- =====================================
-- SYNC COM O CLIENTE
-- =====================================

local function marcarSujo(player)
	local e = estado[player]
	if e then
		e.sujo = true
	end
end

-- Monta o que o cliente recebe. Um lugar só, usado pelo empurrão e pela
-- puxada.
function montarPacote(e)
	local agora = os.clock()
	return {
		valor = e.valor,
		max = e.max,
		desperto = e.desperto,
		restante = e.desperto and math.max(0, e.terminaEm - agora) or 0,
		cooldown = math.max(0, e.cooldownAte - agora),
		-- ativo = o personagem equipado TEM Despertar que este jogador
		-- pode usar. Personagem sem forma despertada não mostra barra.
		ativo = e.def ~= nil,
	}
end

getMeterState.OnServerInvoke = function(player)
	local e = estado[player]
	if not e then
		return { ativo = false }
	end
	return montarPacote(e)
end

local ultimoEnvio = {}

task.spawn(function()
	while true do
		task.wait(CONFIG.INTERVALO_SYNC)
		local agora = os.clock()

		for _, player in ipairs(Players:GetPlayers()) do
			local e = estado[player]

			-- Enquanto desperto ou em recarga a tela mostra um contador em
			-- segundos, e contador precisa de pacote a cada tique. Sem
			-- isto o número congelaria: o `sujo` só liga quando algum
			-- valor muda, e o tempo passando não muda valor nenhum.
			if e and (e.desperto or e.cooldownAte > agora) then
				e.sujo = true
			end

			-- BATIMENTO. Rede de segurança para o cliente que conectou
			-- tarde e perdeu o pacote inicial: de 2 em 2 segundos o estado
			-- vai de novo, mesmo sem nada ter mudado.
			if e and (agora - (ultimoEnvio[player] or 0)) >= CONFIG.BATIMENTO then
				e.sujo = true
			end

			if e and e.sujo then
				e.sujo = false
				ultimoEnvio[player] = agora
				meterUpdate:FireClient(player, montarPacote(e))
			end
		end
	end
end)

-- =====================================
-- TROCA DE FORMA
-- =====================================

-- O GameManager é quem monta a backpack. Aqui só avisamos que o estado
-- mudou e pedimos que ele remonte — assim a lógica de Tools continua
-- num lugar só.
function remontarTools(player)
	if _G.GameManagerConfig and _G.GameManagerConfig.reapplyEquippedTools then
		local ok = pcall(_G.GameManagerConfig.reapplyEquippedTools, player)
		if not ok then
			warn("[AWAKEN METER V2] ⚠️ Falha ao remontar as Tools de " .. player.Name)
		end
	else
		warn("[AWAKEN METER V2] ⚠️ _G.GameManagerConfig.reapplyEquippedTools ausente")
	end
end

local function encerrarDespertar(player, zerarBarra)
	local e = estado[player]
	if not e or not e.desperto then
		return
	end

	local def = definicaoAtiva(player)

	e.desperto = false
	e.terminaEm = 0
	e.valor = 0
	e.cooldownAte = os.clock() + configDe(def, "cooldown", CONFIG.COOLDOWN)
	e.sujo = true

	if zerarBarra then
		e.valor = 0
	end

	remontarTools(player)
	print(string.format("[AWAKEN METER V2] ⏹️ %s voltou ao normal", player.Name))
end

local function dispararDespertar(player, def)
	local e = getEstado(player)
	if e.desperto then
		return
	end

	local duracao = configDe(def, "duracao", CONFIG.DURACAO)

	e.desperto = true
	e.valor = e.max
	e.terminaEm = os.clock() + duracao
	e.sujo = true

	-- A troca de Tools acontece aqui: o GameManager vê estaDesperto()
	-- verdadeiro e passa a tirar as Tools de characterFolder.AwakenedForm
	remontarTools(player)

	print(
		string.format(
			"[AWAKEN METER V2] ⚡ %s DESPERTOU (%s) por %ds",
			player.Name,
			tostring(def.displayName or "?"),
			duracao
		)
	)

	task.delay(duracao, function()
		local atual = estado[player]
		-- Só encerra se for ESTE despertar: se o jogador morreu e
		-- despertou de novo no meio, este timer não pode cortar o novo.
		if atual and atual.desperto and os.clock() >= atual.terminaEm - 0.1 then
			encerrarDespertar(player, true)
		end
	end)
end

-- =====================================
-- GANHO DE BARRA
-- =====================================

local function encher(player, quantidade)
	if quantidade <= 0 then
		return
	end

	local def = definicaoAtiva(player)
	if not def then
		return -- personagem sem Despertar: barra não existe
	end

	-- personagem e max são mantidos pelo atualizarPersonagem; aqui só se
	-- enche. Antes esta função também os escrevia, e por isso a barra só
	-- passava a existir depois do primeiro golpe.
	local e = getEstado(player)

	if e.desperto then
		return -- desperto não enche
	end

	local agora = os.clock()
	if agora < e.cooldownAte then
		return -- em cooldown
	end

	local ganho = math.min(quantidade, CONFIG.GANHO_MAXIMO_POR_GOLPE)
	e.valor = math.clamp(e.valor + ganho, 0, e.max)
	e.sujo = true

	if e.valor >= e.max then
		dispararDespertar(player, def)
	end
end

-- =====================================
-- HOOK DE DANO
-- =====================================

-- Um HealthChanged por personagem. A queda de vida vira ganho de barra
-- para quem apanhou e para quem bateu.
local function acompanharPersonagem(player, character)
	local humanoid = character:WaitForChild("Humanoid", 10)
	if not humanoid then
		return
	end

	local vidaAnterior = humanoid.Health

	humanoid.HealthChanged:Connect(function(vidaAtual)
		local perda = vidaAnterior - vidaAtual
		vidaAnterior = vidaAtual

		-- Cura ou reset de respawn não enchem nada
		if perda <= 0 then
			return
		end

		-- Quem apanhou
		local def = definicaoAtiva(player)
		if def then
			encher(player, perda * configDe(def, "ganhoRecebido", CONFIG.GANHO_POR_DANO_RECEBIDO))
		end

		-- Quem bateu
		if _G.DamageAttribution and _G.DamageAttribution.getAttacker then
			local ok, atacante = pcall(_G.DamageAttribution.getAttacker, character)
			if ok and atacante and atacante ~= player and atacante.Parent then
				local defA = definicaoAtiva(atacante)
				if defA then
					encher(atacante, perda * configDe(defA, "ganhoDano", CONFIG.GANHO_POR_DANO_CAUSADO))
				end
			end
		end
	end)

	humanoid.Died:Connect(function()
		local e = estado[player]
		if not e then
			return
		end

		-- Morreu desperto: acaba a forma e a barra ZERA (decisão do
		-- projeto). O cooldown corre normalmente.
		if e.desperto then
			e.desperto = false
			e.terminaEm = 0
			local def = definicaoAtiva(player)
			e.cooldownAte = os.clock() + configDe(def, "cooldown", CONFIG.COOLDOWN)
			print(string.format("[AWAKEN METER V2] 💀 %s morreu desperto — forma perdida", player.Name))
		end

		e.valor = 0
		e.sujo = true
	end)
end

-- =====================================
-- CICLO DO JOGADOR
-- =====================================

local function entrou(player)
	estado[player] = novoEstado()

	player.CharacterAdded:Connect(function(character)
		local e = getEstado(player)
		e.desperto = false
		e.terminaEm = 0
		e.valor = 0
		e.sujo = true
		-- `def` e `personagem` NÃO são limpos aqui de propósito: renascer
		-- não é trocar de personagem, e limpar faria a barra piscar para
		-- fora da tela a cada morte até o laço de 1s reencontrar tudo.

		task.spawn(acompanharPersonagem, player, character)
	end)

	if player.Character then
		task.spawn(acompanharPersonagem, player, player.Character)
	end

	-- Resolve o personagem equipado já na entrada, para a barra aparecer
	-- sem esperar o laço de 1 em 1 segundo.
	task.spawn(function()
		local espera = 0
		while not _G.PlayerDataManager.getPlayerData(player) and espera < 15 do
			task.wait(0.5)
			espera = espera + 0.5
		end
		atualizarPersonagem(player)
	end)
end

Players.PlayerAdded:Connect(entrou)
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(entrou, player)
end

Players.PlayerRemoving:Connect(function(player)
	estado[player] = nil
	ultimoEnvio[player] = nil
end)

-- Vigia a troca de personagem. A barra é por personagem, então trocar
-- zera. É também aqui que o cache da definição é renovado — e por isso
-- a barra aparece assim que o jogador equipa, sem esperar o primeiro
-- golpe.
task.spawn(function()
	while true do
		task.wait(1)
		for _, player in ipairs(Players:GetPlayers()) do
			if estado[player] then
				atualizarPersonagem(player)
			end
		end
	end
end)

-- =====================================
-- API GLOBAL
-- =====================================

_G.AwakeningMeter = {
	CONFIG = CONFIG,

	-- É ISTO que o GameManager consulta para saber de qual pasta tirar
	-- as Tools (normal ou AwakenedForm).
	estaDesperto = function(player)
		local e = estado[player]
		return e ~= nil and e.desperto == true
	end,

	getEstado = function(player)
		local e = estado[player]
		if not e then
			return nil
		end
		local agora = os.clock()
		return {
			valor = e.valor,
			max = e.max,
			desperto = e.desperto,
			restante = e.desperto and math.max(0, e.terminaEm - agora) or 0,
			cooldown = math.max(0, e.cooldownAte - agora),
			personagem = e.personagem,
		}
	end,

	-- Para teste no console do servidor
    forcar = function(player)
		local def = definicaoAtiva(player)
		if not def then
			return false, "Personagem equipado não tem Despertar (ou falta o Badge)."
		end
		dispararDespertar(player, def)
		return true
	end,

	encerrar = function(player)
		encerrarDespertar(player, true)
		return true
	end,
}

-- Diz POR QUE a barra não está aparecendo, em vez de só despejar
-- números. "não aparece" tem quatro causas possíveis e este comando
-- separa as quatro.
_G.DebugAwakeningMeter = function()
	print("\n========== DEBUG AWAKENING METER V2 ==========")

	local defs = _G.AwakeningSystem and _G.AwakeningSystem.listAll and _G.AwakeningSystem.listAll() or {}
	local quantasDefs = 0
	for _ in pairs(defs) do
		quantasDefs = quantasDefs + 1
	end
	print("  Despertares cadastrados no jogo:", quantasDefs)
	if quantasDefs == 0 then
		print("  ⚠️ NENHUM. Sem definição, a barra fica escondida de propósito.")
		print("     Crie um Despertar no painel admin para o personagem equipado.")
	end

	print("  GameManagerConfig:", _G.GameManagerConfig and "OK" or "AUSENTE ✗")
	print("  DamageAttribution:", _G.DamageAttribution and "OK" or "AUSENTE ✗ (barra não enche)")

	for _, player in ipairs(Players:GetPlayers()) do
		local e = estado[player]
		if not e then
			print(string.format("  %s | SEM ESTADO ✗", player.Name))
		else
			local agora = os.clock()
			local equipado = personagemEquipado(player)

			local motivo
			if not equipado then
				motivo = "nenhum personagem equipado"
			elseif not (_G.AwakeningSystem.getDefinition(equipado)) then
				motivo = "'" .. equipado .. "' não tem Despertar cadastrado"
			elseif not e.def then
				motivo = "Badge exigido e o jogador não tem (ou o cache ainda não resolveu)"
			end

			print(
				string.format(
					"  %s | equipado: %s | barra %.1f/%.0f | %s | cooldown %.1fs",
					player.Name,
					tostring(equipado or "-"),
					e.valor,
					e.max,
					e.desperto and string.format("DESPERTO (%.1fs)", math.max(0, e.terminaEm - agora)) or "normal",
					math.max(0, e.cooldownAte - agora)
				)
			)
			print(
				string.format(
					"      cliente recebe ativo=%s%s",
					tostring(e.def ~= nil),
					motivo and ("  ← BARRA ESCONDIDA: " .. motivo) or ""
				)
			)
		end
	end
	print("=============================================\n")
end

print("[AWAKEN METER V2] Barra de Despertar carregada")
