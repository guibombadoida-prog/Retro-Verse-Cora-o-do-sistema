-- ============================================
-- MUSIC CATALOG SERVER V2
-- Coloque em ServerScriptService
-- Nome: "MusicCatalogServer"
-- ============================================
-- Catálogo de músicas em DataStore, editável DENTRO do jogo.
--
-- POR QUE EXISTE
-- Até agora as faixas eram objetos `Sound` colocados à mão dentro de
-- `workspace.MusicHolder`, pelo Studio. Trocar a trilha exigia abrir o
-- Studio, criar Sound, colar o ID e publicar o jogo inteiro.
--
-- Este script faz com a música o mesmo que o CharacterCatalogServer faz
-- com os personagens: os IDs ficam num DataStore, um admin adiciona e
-- remove pela GUI dentro do jogo, e todos os servidores da experiência
-- recebem a mudança na hora via MessagingService.
--
-- DEPENDE DE:
--   • AdminRegistryServer  -> _G.AdminRegistry.isAdmin
--
-- PUBLICA:
--   • _G.MusicCatalog      -> listar / getById / isReady
--   • _G.DebugMusicCatalog
--
-- MESMO PADRÃO DO CATÁLOGO DE PERSONAGENS:
--   • DataStore próprio, nome fixo (não mudar depois de publicado)
--   • MessagingService com guarda de JobId (a origem não reprocessa a
--     própria mensagem)
--   • Remotes de admin protegidos por isAdmin, com Kick em tentativa
--     não autorizada
-- ============================================
-- (V2) O ID NÃO CHEGAVA NOS OUTROS SERVIDORES — três causas somadas:
--
-- 1. INSCRIÇÃO FALHANDO EM SILÊNCIO. O SubscribeAsync estava dentro de
--    um pcall que engolia o erro. Ele é chamada de rede e falha de vez
--    em quando no boot; quando falhava, o servidor nunca ficava
--    inscrito e não havia uma linha no log dizendo isso. Agora tenta
--    seis vezes com espera crescente e grita se desistir.
--
-- 2. CACHE DE LEITURA DO DATASTORE. GetAsync guarda cache de 4 segundos
--    por chave. Como a mensagem de sync chega em menos de um segundo
--    depois da escrita, a releitura podia devolver a lista de ANTES da
--    gravação — o servidor "sincronizava" para o catálogo velho. Agora
--    a leitura usa DataStoreGetOptions com UseCache = false.
--
-- 3. MENSAGEM PERDIDA = CATÁLOGO VELHO PARA SEMPRE. O MessagingService
--    é entrega de melhor esforço, não garante entrega. Não havia nada
--    para consertar uma mensagem perdida. Agora existe uma releitura
--    periódica (INTERVALO_RECONCILIA) que conserta sozinha.
--
-- Diagnóstico: _G.DebugMusicCatalog() agora diz se este servidor está
-- inscrito no sync.
-- ============================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")
local MessagingService = game:GetService("MessagingService")
local MarketplaceService = game:GetService("MarketplaceService")

local CONFIG = {
	-- ⚠️ NÃO MUDAR depois de publicado: o catálogo inteiro some.
	STORE_NAME = "RVMusicCatalogV1",
	SYNC_TOPIC = "RVMusicCatalogSync",
	CHAVE = "tracks",

	-- De quanto em quanto tempo o servidor relê o catálogo do DataStore,
	-- por segurança. O MessagingService é entrega de melhor esforço: se
	-- uma mensagem se perder, é esta releitura que conserta.
	INTERVALO_RECONCILIA = 60,

	MAX_FAIXAS = 200,
	MAX_TAMANHO_NOME = 60,
	MAX_TAMANHO_ARTISTA = 40,
}

-- Se o AdminRegistryServer não tiver carregado, só o DONO edita.
local FALLBACK_OWNER_ID = game.CreatorId

local musicStore = DataStoreService:GetDataStore(CONFIG.STORE_NAME)

local function isAdmin(player)
	if _G.AdminRegistry then
		return _G.AdminRegistry.isAdmin(player)
	end
	return player ~= nil and player.UserId == FALLBACK_OWNER_ID
end

-- =====================================
-- REMOTES
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

local getMusicCatalog = ensureRemote("GetMusicCatalog", "RemoteFunction") -- público
local adminMusicAdd = ensureRemote("AdminMusicAdd", "RemoteFunction")
local adminMusicRemove = ensureRemote("AdminMusicRemove", "RemoteFunction")
local adminMusicUpdate = ensureRemote("AdminMusicUpdate", "RemoteFunction")
local musicCatalogSync = ensureRemote("MusicCatalogSync", "RemoteEvent")

-- =====================================
-- ESTADO
-- =====================================

local faixas = {}
local pronto = false

local function copiar(lista)
	local saida = {}
	for i, f in ipairs(lista) do
		saida[i] = {
			id = f.id,
			nome = f.nome,
			artista = f.artista,
			addedBy = f.addedBy,
			addedAt = f.addedAt,
		}
	end
	return saida
end

local function indiceDe(lista, id)
	for i, f in ipairs(lista) do
		if f.id == id then
			return i
		end
	end
	return nil
end

-- O DataStore devolve tabela solta; nunca confiar no formato de volta.
local function sanear(bruto)
	local limpa = {}
	if type(bruto) ~= "table" then
		return limpa
	end

	for _, f in ipairs(bruto) do
		local id = tonumber(f and f.id)
		if id and id > 0 and not indiceDe(limpa, id) then
			table.insert(limpa, {
				id = id,
				nome = type(f.nome) == "string" and f.nome or ("Faixa " .. id),
				artista = type(f.artista) == "string" and f.artista or "",
				addedBy = type(f.addedBy) == "string" and f.addedBy or "",
				addedAt = tonumber(f.addedAt) or 0,
			})
		end
		if #limpa >= CONFIG.MAX_FAIXAS then
			break
		end
	end

	return limpa
end

-- =====================================
-- VALIDAÇÃO DO ID PELA API DO ROBLOX
-- =====================================

-- É aqui que o "via API" acontece: em vez de o admin digitar nome e ID
-- na mão, o servidor pergunta ao Roblox o que é aquele ID. Se não for
-- áudio, recusa — assim não entra ID de imagem ou de modelo na trilha.
local function consultarAsset(id)
	local ok, info = pcall(function()
		return MarketplaceService:GetProductInfo(id, Enum.InfoType.Asset)
	end)

	if not ok or type(info) ~= "table" then
		return nil, "Não consegui consultar esse ID no Roblox."
	end

	-- AssetTypeId 3 = Audio
	if info.AssetTypeId ~= 3 then
		return nil, "Esse ID não é de áudio (tipo " .. tostring(info.AssetTypeId) .. ")."
	end

	return {
		nome = info.Name or ("Faixa " .. id),
		artista = (info.Creator and info.Creator.Name) or "",
	}
end

-- =====================================
-- PERSISTÊNCIA
-- =====================================

-- ⚠️ GetAsync GUARDA CACHE DE 4 SEGUNDOS por chave.
--
-- Quando a mensagem de sync chega logo depois da escrita — que é o caso
-- normal, ela chega em menos de um segundo — um GetAsync comum pode
-- devolver a lista de ANTES da gravação, e o servidor aplicaria o
-- catálogo velho achando que sincronizou.
--
-- DataStoreGetOptions com UseCache = false força a leitura real.
local opcoesLeitura = Instance.new("DataStoreGetOptions")
opcoesLeitura.UseCache = false

local function carregar()
	local ok, bruto = pcall(function()
		return musicStore:GetAsync(CONFIG.CHAVE, opcoesLeitura)
	end)

	-- Roblox antigo não conhece DataStoreGetOptions: cai no GetAsync
	-- comum em vez de deixar o catálogo sem carregar.
	if not ok then
		ok, bruto = pcall(function()
			return musicStore:GetAsync(CONFIG.CHAVE)
		end)
	end

	if not ok then
		warn("[MUSIC CATALOG V2] ⚠️ Falha ao carregar — começando vazio")
		faixas = {}
	else
		faixas = sanear(bruto)
	end

	pronto = true
	print(string.format("[MUSIC CATALOG V2] ✓ %d faixa(s) carregada(s)", #faixas))
end

-- UpdateAsync em vez de SetAsync: dois admins em servidores diferentes
-- podem adicionar ao mesmo tempo, e o SetAsync faria um sobrescrever o
-- outro.
local function gravar(transformar)
	local resultado, erro

	local ok, err = pcall(function()
		musicStore:UpdateAsync(CONFIG.CHAVE, function(atual)
			local lista = sanear(atual)
			local nova, problema = transformar(lista)
			if not nova then
				erro = problema
				return nil -- aborta a escrita
			end
			resultado = nova
			return nova
		end)
	end)

	if not ok then
		return nil, "Erro ao salvar: " .. tostring(err)
	end
	if erro then
		return nil, erro
	end

	if resultado then
		faixas = resultado
	end
	return faixas
end

-- =====================================
-- SINCRONIZAÇÃO ENTRE SERVIDORES
-- =====================================

local function avisarClientesLocais()
	local lista = copiar(faixas)
	for _, p in ipairs(Players:GetPlayers()) do
		musicCatalogSync:FireClient(p, lista)
	end
end

local function publicarSync(acao, nomeAdmin, titulo)
	pcall(function()
		MessagingService:PublishAsync(CONFIG.SYNC_TOPIC, {
			acao = acao,
			admin = nomeAdmin,
			titulo = titulo,
			jobId = game.JobId,
		})
	end)
end

-- ⚠️ O SubscribeAsync PODE FALHAR, e falhar aqui é invisível.
--
-- Era isto que fazia a música não chegar nos outros servidores: a
-- inscrição estava dentro de um pcall que engolia o erro em silêncio.
-- SubscribeAsync é chamada de rede e falha de vez em quando no boot —
-- quando falhava, o servidor simplesmente nunca ficava inscrito, sem uma
-- linha no log. O admin adicionava numa partida e as outras nunca
-- ficavam sabendo.
--
-- Agora ele tenta várias vezes, com espera crescente, e grita se
-- desistir.

local inscrito = false

local function tratarMensagem(data)
	-- Guarda de JobId: quem publicou já aplicou localmente
	if type(data) ~= "table" or data.jobId == game.JobId then
		return
	end

	carregar()
	avisarClientesLocais()

	print(
		string.format(
			"[MUSIC CATALOG V2] ↻ Sync de outro servidor: %s (%s)",
			tostring(data.acao),
			tostring(data.titulo)
		)
	)
end

task.spawn(function()
	local espera = 2

	for tentativa = 1, 6 do
		local ok, err = pcall(function()
			MessagingService:SubscribeAsync(CONFIG.SYNC_TOPIC, function(message)
				tratarMensagem(message.Data)
			end)
		end)

		if ok then
			inscrito = true
			print("[MUSIC CATALOG V2] ✓ Inscrito no sync entre servidores")
			return
		end

		warn(
			string.format(
				"[MUSIC CATALOG V2] ⚠️ Tentativa %d de inscrever no sync falhou: %s",
				tentativa,
				tostring(err)
			)
		)
		task.wait(espera)
		espera = math.min(espera * 2, 30)
	end

	warn(
		"[MUSIC CATALOG V2] ❌ NÃO consegui inscrever no MessagingService. "
			.. "Este servidor só verá músicas novas pela releitura periódica "
			.. "(até "
			.. CONFIG.INTERVALO_RECONCILIA
			.. "s de atraso)."
	)
end)

-- REDE DE SEGURANÇA: releitura periódica.
-- O MessagingService é entrega de melhor esforço — ele NÃO garante que
-- a mensagem chegue. Uma mensagem perdida deixaria este servidor com o
-- catálogo velho para sempre. Reler de tempos em tempos conserta isso
-- sozinho, e também cobre o caso da inscrição ter falhado de vez.
task.spawn(function()
	while true do
		task.wait(CONFIG.INTERVALO_RECONCILIA)

		local antes = #faixas
		carregar()

		if #faixas ~= antes then
			avisarClientesLocais()
			print(
				string.format(
					"[MUSIC CATALOG V2] ↻ Releitura periódica: %d → %d faixa(s)",
					antes,
					#faixas
				)
			)
		end
	end
end)

-- =====================================
-- REMOTES DE ADMIN
-- =====================================

local function recusarNaoAdmin(player)
	player:Kick("Tentativa não autorizada de uso de comandos admin")
end

adminMusicAdd.OnServerInvoke = function(player, idBruto, nomeManual, artistaManual)
	if not isAdmin(player) then
		recusarNaoAdmin(player)
		return false, "Sem permissão!"
	end

	local id = tonumber(idBruto)
	if not id or id <= 0 or id ~= math.floor(id) then
		return false, "ID inválido."
	end

	if indiceDe(faixas, id) then
		return false, "Essa música já está no catálogo."
	end

	if #faixas >= CONFIG.MAX_FAIXAS then
		return false, "Catálogo cheio (" .. CONFIG.MAX_FAIXAS .. " faixas)."
	end

	-- Pergunta ao Roblox o que é esse ID antes de aceitar
	local info, problema = consultarAsset(id)
	if not info then
		return false, problema
	end

	local nome = nomeManual
	if type(nome) ~= "string" or nome:gsub("%s", "") == "" then
		nome = info.nome
	end
	nome = string.sub(nome, 1, CONFIG.MAX_TAMANHO_NOME)

	local artista = artistaManual
	if type(artista) ~= "string" or artista:gsub("%s", "") == "" then
		artista = info.artista
	end
	artista = string.sub(artista, 1, CONFIG.MAX_TAMANHO_ARTISTA)

	local nova, erro = gravar(function(lista)
		if indiceDe(lista, id) then
			return nil, "Essa música já está no catálogo."
		end
		if #lista >= CONFIG.MAX_FAIXAS then
			return nil, "Catálogo cheio."
		end
		table.insert(lista, {
			id = id,
			nome = nome,
			artista = artista,
			addedBy = player.Name,
			addedAt = os.time(),
		})
		return lista
	end)

	if not nova then
		return false, erro
	end

	avisarClientesLocais()
	publicarSync("add", player.Name, nome)
	print(string.format("[MUSIC CATALOG V2] ✅ %s adicionou '%s' (%d)", player.Name, nome, id))

	return true, "Música adicionada: " .. nome, copiar(faixas)
end

adminMusicRemove.OnServerInvoke = function(player, idBruto)
	if not isAdmin(player) then
		recusarNaoAdmin(player)
		return false, "Sem permissão!"
	end

	local id = tonumber(idBruto)
	if not id then
		return false, "ID inválido."
	end

	local indice = indiceDe(faixas, id)
	if not indice then
		return false, "Essa música não está no catálogo."
	end

	local titulo = faixas[indice].nome

	local nova, erro = gravar(function(lista)
		local i = indiceDe(lista, id)
		if not i then
			return nil, "Essa música não está no catálogo."
		end
		table.remove(lista, i)
		return lista
	end)

	if not nova then
		return false, erro
	end

	avisarClientesLocais()
	publicarSync("remove", player.Name, titulo)
	print(string.format("[MUSIC CATALOG V2] 🗑️ %s removeu '%s' (%d)", player.Name, titulo, id))

	return true, "Música removida: " .. titulo, copiar(faixas)
end

adminMusicUpdate.OnServerInvoke = function(player, idBruto, nomeNovo, artistaNovo)
	if not isAdmin(player) then
		recusarNaoAdmin(player)
		return false, "Sem permissão!"
	end

	local id = tonumber(idBruto)
	if not id or not indiceDe(faixas, id) then
		return false, "Essa música não está no catálogo."
	end

	local nova, erro = gravar(function(lista)
		local i = indiceDe(lista, id)
		if not i then
			return nil, "Essa música não está no catálogo."
		end
		if type(nomeNovo) == "string" and nomeNovo:gsub("%s", "") ~= "" then
			lista[i].nome = string.sub(nomeNovo, 1, CONFIG.MAX_TAMANHO_NOME)
		end
		if type(artistaNovo) == "string" then
			lista[i].artista = string.sub(artistaNovo, 1, CONFIG.MAX_TAMANHO_ARTISTA)
		end
		return lista
	end)

	if not nova then
		return false, erro
	end

	avisarClientesLocais()
	publicarSync("update", player.Name, nomeNovo)
	print(string.format("[MUSIC CATALOG V2] ✏️ %s editou a faixa %d", player.Name, id))

	return true, "Faixa atualizada.", copiar(faixas)
end

-- =====================================
-- REMOTE PÚBLICO
-- =====================================

getMusicCatalog.OnServerInvoke = function()
	-- Espera o boot para o cliente não receber lista vazia por engano
	local espera = 0
	while not pronto and espera < 10 do
		task.wait(0.2)
		espera = espera + 0.2
	end
	return copiar(faixas)
end

-- Manda a lista assim que o jogador entra, sem ele precisar pedir
Players.PlayerAdded:Connect(function(player)
	task.spawn(function()
		local espera = 0
		while not pronto and espera < 15 do
			task.wait(0.3)
			espera = espera + 0.3
		end
		musicCatalogSync:FireClient(player, copiar(faixas))
	end)
end)

-- =====================================
-- API GLOBAL
-- =====================================

_G.MusicCatalog = {
	listar = function()
		return copiar(faixas)
	end,

	getById = function(id)
		local i = indiceDe(faixas, tonumber(id) or -1)
		return i and copiar(faixas)[i] or nil
	end,

	isReady = function()
		return pronto
	end,

	contar = function()
		return #faixas
	end,
}

_G.DebugMusicCatalog = function()
	print("\n========== DEBUG MUSIC CATALOG V1 ==========")
	print("  DataStore:", CONFIG.STORE_NAME, "| pronto:", pronto)
	print("  sync entre servidores:", inscrito and "INSCRITO ✓" or "NÃO INSCRITO ✗ (só releitura periódica)")
	print("  faixas:", #faixas, "de", CONFIG.MAX_FAIXAS)
	for i, f in ipairs(faixas) do
		print(
			string.format(
				"   %2d. %s — %s | id=%d | por %s",
				i,
				f.nome,
				f.artista ~= "" and f.artista or "?",
				f.id,
				f.addedBy ~= "" and f.addedBy or "?"
			)
		)
	end
	print("===========================================\n")
end

carregar()

print("[MUSIC CATALOG V2] Sistema de catálogo de músicas carregado")
