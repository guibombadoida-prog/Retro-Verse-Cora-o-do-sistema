-- ============================================
-- AWAKENING SYSTEM SERVER V7 — NOME DO ORIGINAL ACEITA ESPAÇO E CAIXA
-- ============================================
-- (V7) "Personagem não existe no catálogo" com o nome escrito certo.
-- A checagem só fazia lookup por chave EXATA e desistia quando dava nil,
-- sem consultar a pasta replicada nem tentar sem diferenciar maiúscula.
-- Um espaço invisível no fim do nome já reprovava. Agora a busca tem
-- quatro degraus e o nome é normalizado para a grafia do catálogo antes
-- de salvar.
-- ============================================
-- (V6) INFORMAÇÃO COMPLETA NO CARD
-- ============================================
-- (V6) O card do Despertar mostra imagem, nome, história e as Tools.
-- Para isso a definição ganhou `lore` e `description`, e o CheckAwakening
-- passou a devolver imageId, lore, description e health junto.
-- Coloque em ServerScriptService
-- Nome: "AwakeningSystemServer"
-- SUBSTITUI: AwakeningSystemServer V4
-- ============================================
-- (V5) A MUDANÇA DE CONCEITO
--
-- O Despertar deixou de ser um personagem separado que se desbloqueia e
-- se equipa. Agora ele é uma FORMA TEMPORÁRIA do personagem normal:
--
--   • No catálogo o Despertar é SÓ INFORMAÇÃO — imagem, nome e como
--     liberar. Não tem botão de equipar, porque ele já vem junto com o
--     personagem normal.
--   • Em combate, a barra do AwakeningMeterServer enche batendo e
--     apanhando. Cheia, as Tools normais saem e as do Despertar entram.
--   • Passado o tempo, volta ao normal e começa o cooldown.
--
-- O QUE MUDOU NESTE SCRIPT
--   • BADGE VIROU OPCIONAL. Era obrigatório porque era a condição de
--     desbloqueio. Agora, em branco, o Despertar é de quem tem o
--     personagem; preenchido, ele gateia a forma.
--   • CheckAwakening não devolve mais `canEquip` — devolve
--     `somenteInfo`, `exigeBadge`, `temBadge` e `liberado`.
--   • EquipAwakening foi DESATIVADO. Ele gravava addAwakenedCharacter e
--     fazia o personagem nascer desperto para sempre. O remote continua
--     existindo só para não quebrar cliente antigo, mas não concede
--     mais nada.
--   • Campos novos de ajuste por personagem: medidorMax, duracao,
--     cooldown, ganhoDano, ganhoRecebido. Em branco, valem os padrões
--     do AwakeningMeterServer.
--
-- ⚠️ Este script sozinho não desperta ninguém. Ele guarda a DEFINIÇÃO.
--    Quem dispara é o AwakeningMeterServer, e quem troca as Tools é o
--    GameManager V10.
-- ============================================
-- (V4) UM ID DE MODEL PODE TRAZER AS 7 TOOLS (mantido)
-- DEPENDE DE: AdminRegistryServer_V1, GameManager_V9 (usa AwakenedForm),
--             CharacterCatalogServer_V6 (_G.CharacterCatalog — desde o V3)
-- ============================================
-- (V4) UM ID DE MODEL PODE TRAZER AS 7 TOOLS
--
-- Antes cada Tool exigia um asset e um ID próprios: 7 Tools = 7 uploads
-- e 7 campos preenchidos no painel. Agora dá para juntar as Tools todas
-- dentro de UM Model, subir esse Model uma vez, e usar só o ID dele.
--
-- O que o V4 aceita em cada campo de ID:
--   • Tool sozinha ................. 1 Tool  (igual ao V3, nada muda)
--   • Model com N Tools dentro ..... N Tools (o caso novo)
--   • Model > Folder > Tools ....... funciona, a busca é recursiva
--   • Várias Tools na raiz do asset  todas elas
--
-- Ordem: profundidade na ordem dos filhos. A ordem que você vê no
-- Explorer do Studio é a ordem que vai para a hotbar.
--
-- 🐛 DE QUEBRA, UM BUG DE PERDA SILENCIOSA:
--    O V3 fazia `container:GetChildren()[1]` ao carregar o asset, ou
--    seja, ficava só com o PRIMEIRO objeto. Um asset com 7 Tools na
--    raiz perdia 6 sem avisar nada. Agora o container inteiro é varrido.
--
-- ⚠️ O TETO DE 7 AGORA É SOBRE O TOTAL, não sobre a quantidade de IDs.
--    O V3 contava IDs (`if i > MAX then break`), o que deixaria de
--    proteger o limite: 7 IDs de Model com 7 Tools cada dariam 49.
--    Quando o teto é atingido as extras são ignoradas COM aviso no
--    painel, nunca em silêncio.
-- ============================================
-- (V3) BUG GRAVE CORRIGIDO — DESPERTAR SOLTO, SEM ORIGINAL
--
-- Um Despertar existe SEMPRE em cima de um personagem que já existe.
-- No V2 dava para criar um Despertar do nada, e o resultado era um
-- personagem destravado só por Badge — ou seja, um personagem de
-- emblema comum, criado pela porta errada.
--
-- 🐛 CAUSA 1 — VALIDAÇÃO NÃO OLHAVA O CATÁLOGO.
--    `validatePayload` conferia tamanho do nome e Badge ID, e nada
--    mais. Digitar "Gokú" (ou qualquer nome inventado, ou um nome
--    certo com erro de digitação) passava direto.
--
-- 🐛 CAUSA 2 — A CONSTRUÇÃO CRIAVA O PERSONAGEM FANTASMA.
--    `buildAwakenedAssets` fazia:
--        if not baseFolder then ... baseFolder.Parent = charactersFolder
--    Ou seja: personagem não existia, então ele CRIAVA a pasta em
--    ReplicatedStorage.Characters. Isso dava ao fantasma a mesma
--    estrutura de um personagem de verdade, e é por isso que ele
--    "virava um personagem de emblema normal".
--
--    Efeito colateral cruel: como `ownsCharacter(player, fantasma)`
--    é sempre falso, NINGUÉM conseguia desbloquear aquele Despertar.
--    Era configuração morta sujando o ReplicatedStorage e a lista do
--    painel admin, sem nenhum erro no Output.
--
-- ✅ CORREÇÃO:
--    • `validatePayload` agora exige que o personagem exista no
--      catálogo (_G.CharacterCatalog.getDefinition). Sem original,
--      o painel recebe "Personagem 'X' não existe no catálogo".
--    • `buildAwakenedAssets` NUNCA cria a pasta base. Se ela não
--      existe, ele recusa e devolve erro.
--    • `bootLoadAwakenings` espera o catálogo carregar antes de
--      reconstruir (senão a checagem acusaria falso negativo na
--      corrida de boot) e agora ACUSA os Despertares órfãos que o
--      V2 já pode ter salvo, em vez de recriar o fantasma.
--    • `_G.DebugAwakening()` marca os órfãos com ⚠️ e explica como
--      limpar.
-- ============================================
-- (V2) ALTERAÇÕES:
-- • LISTA "ADMIN_IDS" REMOVIDA DO CÓDIGO (o V1 tinha só
--   { 1595442496 }, dessincronizada dos outros scripts): quem é
--   admin agora vem do _G.AdminRegistry (AdminRegistryServer_V1).
--   O ÚNICO id no Studio é o do DONO; os outros são adicionados
--   dentro do jogo e valem em TODOS os servidores.
-- • GUARDA DE JobId no MessagingService: o servidor que fez a
--   mudança não processa a própria mensagem — antes ele
--   reconstruía as Tools e anunciava DUAS vezes na mesma sala
--   (mesma correção já aplicada no CharacterCatalogServer_V4 e no
--   AchievementSystemServer_V2).
-- • EDIÇÃO RECONHECIDA: salvar um Despertar de um personagem que
--   já tinha um configurado agora anuncia "✏️ atualizou o
--   Despertar" e devolve "Despertar ATUALIZADO..." pro painel
--   (usado pelo botão ✏️ EDITAR do AdminMenuClient_V9).
-- ============================================
-- MANTIDO DO V1:
-- • Condição de desbloqueio SEMPRE Badge: possuir o personagem
--   original + ter o Badge configurado pelo admin
-- • Até 7 Tools na forma despertada, via Model ID (InsertService)
-- • Persistência em DataStore próprio + sync entre servidores
-- • Contrato dos remotes CheckAwakening/EquipAwakening intacto
--
-- REUTILIZADO:
-- • _G.AdminRegistry.isAdmin ................ AdminRegistryServer_V1
-- • Guarda de JobId ......................... CharacterCatalogServer_V4/V5
-- • ensureRemote / InsertService / Messaging  CharacterCatalogServer_V5
-- • addAwakenedCharacter / hasAwakening ..... DataManager_V6
-- • CatalogAnnouncement (mesmo remote de aviso) CharacterCatalogServer_V5
-- • Regras de Tool .......................... roblox-tool-info-rules
-- ============================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")
local MessagingService = game:GetService("MessagingService")
local InsertService = game:GetService("InsertService")
local BadgeService = game:GetService("BadgeService")

repeat
	task.wait()
until _G.PlayerDataManager

-- =====================================
-- CONFIGURAÇÃO
-- =====================================

-- (V2) Fallback de segurança: se o AdminRegistryServer_V1 não
-- estiver instalado, só o DONO é admin (mesmo id do registry).
local FALLBACK_OWNER_ID = 1595442496

local CONFIG = {
	MAX_TOOLS_PER_CHARACTER = 7, -- mesma regra do catálogo normal
	STORE_NAME = "RVAwakeningCatalogV1",
	SYNC_TOPIC = "RVAwakeningSync",
	LOAD_RETRIES = 2,
	-- (V3) Segundos de espera pelo catálogo no boot antes de reconstruir
	-- os Despertares. Sem essa espera, a checagem de personagem original
	-- rodaria com o catálogo vazio e marcaria tudo como órfão.
	CATALOG_WAIT = 30,
}

-- (V2) Admin dinâmico via registro central
local function isAdmin(player)
	if _G.AdminRegistry then
		return _G.AdminRegistry.isAdmin(player)
	end
	return player ~= nil and player.UserId == FALLBACK_OWNER_ID
end

-- =====================================
-- DATASTORE
-- =====================================

local awakeningStore = DataStoreService:GetDataStore(CONFIG.STORE_NAME)

-- =====================================
-- PASTAS DE DESTINO
-- =====================================

local charactersFolder = ReplicatedStorage:WaitForChild("Characters")
local imagesFolder = ReplicatedStorage:WaitForChild("CharacterImages")

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

local adminSetAwakening = ensureRemote("AdminSetAwakening", "RemoteFunction")
local adminRemoveAwakening = ensureRemote("AdminRemoveAwakening", "RemoteFunction")
local adminListAwakenings = ensureRemote("AdminListAwakenings", "RemoteFunction")
local checkAwakeningRemote = ensureRemote("CheckAwakening", "RemoteFunction") -- esperado pelo CharacterSystemClient
local equipAwakeningRemote = ensureRemote("EquipAwakening", "RemoteEvent") -- esperado pelo CharacterSystemClient
local catalogAnnouncement = ensureRemote("CatalogAnnouncement", "RemoteEvent") -- REUTILIZADO do CharacterCatalogServer

-- =====================================
-- ESTADO EM MEMÓRIA + API GLOBAL
-- =====================================

local awakenDefs = {} -- [characterName] = definição

-- (V3) Despertares salvos cujo personagem original não existe. Ficam
-- FORA de awakenDefs (não são construídos nem ficam equipáveis), mas
-- são guardados aqui para aparecerem na lista do painel admin — senão
-- o admin não teria como removê-los.
local orphanDefs = {} -- [characterName] = definição
local orphanNames = {} -- ordem de descoberta, para a mensagem de boot

-- =====================================
-- (V3) O ORIGINAL EXISTE?
-- =====================================
-- Um Despertar é uma FORMA de um personagem existente, nunca um
-- personagem por conta própria. Esta é a única função que responde
-- isso, e todo caminho de criação passa por ela.
--
-- A autoridade é o catálogo (_G.CharacterCatalog, respaldado por
-- DataStore), não a pasta em ReplicatedStorage — a pasta é efeito,
-- não causa. Se o catálogo não estiver instalado, cai para a pasta
-- como último recurso, mas nunca dá o "sim" de graça.

-- (V7) RESOLVE O NOME DO PERSONAGEM ORIGINAL.
--
-- O que existia antes era um `originalExists` que só fazia lookup por
-- CHAVE EXATA no catálogo (`GCC.catalogByName[name]`) e, quando isso
-- devolvia nil, retornava false SEM tentar mais nada. Resultado: um
-- espaço invisível no fim do nome, ou uma letra maiúscula diferente,
-- reprovava um personagem que existe — e o admin via "não existe no
-- catálogo" com o nome escrito certo na frente dele.
--
-- Agora a busca tem quatro degraus e devolve o nome CANÔNICO, para o
-- Despertar ser gravado com a mesma grafia que o resto do sistema usa.
local function resolverNomeOriginal(name)
	if type(name) ~= "string" then
		return nil
	end

	-- 1. Tira espaços das pontas — a causa mais comum, e invisível
	name = name:match("^%s*(.-)%s*$") or ""
	if #name < 2 then
		return nil
	end

	-- 2. Chave exata no catálogo
	if _G.CharacterCatalog and _G.CharacterCatalog.getDefinition then
		local ok, def = pcall(_G.CharacterCatalog.getDefinition, name)
		if ok and def ~= nil then
			return name
		end
	end

	-- 3. A pasta replicada. NÃO era consultada quando o catálogo
	--    respondia nil, só quando ele estava ausente.
	local naPasta = charactersFolder:FindFirstChild(name)
	if naPasta then
		return naPasta.Name
	end

	-- 4. Último recurso: varredura sem diferenciar maiúscula de minúscula
	local alvo = name:lower()

	if _G.CharacterCatalog and _G.CharacterCatalog.listAll then
		local ok, todos = pcall(_G.CharacterCatalog.listAll)
		if ok and type(todos) == "table" then
			for nomeCatalogo in pairs(todos) do
				if type(nomeCatalogo) == "string" and nomeCatalogo:lower() == alvo then
					return nomeCatalogo
				end
			end
		end
	end

	for _, filho in ipairs(charactersFolder:GetChildren()) do
		if filho.Name:lower() == alvo then
			return filho.Name
		end
	end

	return nil
end

local function originalExists(name)
	return resolverNomeOriginal(name) ~= nil
end

_G.AwakeningSystem = {
	getDefinition = function(name)
		return awakenDefs[name]
	end,
	listAll = function()
		return awakenDefs
	end,
}

-- =====================================
-- HELPERS: InsertService (carregar Tools por ID)
-- =====================================

-- (V4) Devolve o CONTAINER cru do LoadAsset, sem escolher filho.
-- O V3 fazia `container:GetChildren()[1]`, o que jogava fora tudo que
-- não fosse o primeiro objeto — se o asset tivesse 7 Tools na raiz,
-- 6 desapareciam em silêncio. Quem decide o que aproveitar agora é o
-- collectTools, que varre o container inteiro.
local function loadAssetSafe(assetId)
	assetId = tonumber(assetId)
	if not assetId or assetId <= 0 then
		return nil, "ID inválido"
	end

	local lastErr = nil
	for attempt = 1, CONFIG.LOAD_RETRIES do
		local ok, result = pcall(function()
			return InsertService:LoadAsset(assetId)
		end)
		if ok and result then
			return result, nil
		end
		lastErr = result
		task.wait(0.5)
	end

	return nil, "Falha ao carregar asset " .. tostring(assetId) .. ": " .. tostring(lastErr)
end

-- (V4) UM ID PODE TRAZER VÁRIAS TOOLS
-- =====================================
-- Aceita qualquer formato de asset e devolve a lista de Tools que
-- existirem dentro dele:
--   • Tool sozinha ................ 1 Tool   (como era no V3)
--   • Model com 7 Tools dentro .... 7 Tools  (1 ID só)
--   • Model > Folder > Tools ...... funciona, a busca é recursiva
--   • 7 Tools na raiz do asset .... 7 Tools
--
-- A ordem é a de profundidade (depth-first) na ordem dos filhos, ou
-- seja: a ordem que você vê no Explorer do Studio é a ordem que vai
-- para a hotbar. Sem sort, de propósito — reordenar aqui faria a
-- hotbar não bater com o modelo.
local function collectTools(container)
	if not container then
		return {}
	end
	if container:IsA("Tool") then
		return { container }
	end

	local encontradas = {}
	for _, descendente in ipairs(container:GetDescendants()) do
		if descendente:IsA("Tool") then
			table.insert(encontradas, descendente)
		end
	end
	return encontradas
end

local function enforceToolRules(tool)
	if not tool:IsA("Tool") then
		return
	end
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	if not tool:FindFirstChild("Handle") then
		warn(
			string.format(
				"[AWAKENING V4] ⚠️ Tool '%s' carregada SEM Handle — não vai funcionar até corrigir o modelo de origem.",
				tool.Name
			)
		)
	end
end

-- =====================================
-- CONSTRUÇÃO DA FORMA DESPERTADA
-- Characters[Nome].AwakenedForm fica com as Tools despertas — o
-- GameManager_V9 já sabe procurar aqui quando hasAwakening é true.
-- =====================================

-- Devolve: lista de avisos, erro (string) ou nil
-- Erro não-nil significa que NADA foi construído.
local function buildAwakenedAssets(def)
	-- (V3) NUNCA criar a pasta base aqui. O V2 criava, e era isso que
	-- transformava um nome inventado num personagem de aparência
	-- legítima em ReplicatedStorage.Characters. A pasta base é
	-- responsabilidade exclusiva do CharacterCatalogServer.
	local baseFolder = charactersFolder:FindFirstChild(def.characterName)
	if not baseFolder then
		local msg = string.format(
			"Personagem '%s' não existe — o Despertar precisa de um personagem original. Crie o personagem no catálogo primeiro.",
			tostring(def.characterName)
		)
		return {}, msg
	end

	local oldAwakened = baseFolder:FindFirstChild("AwakenedForm")
	if oldAwakened then
		oldAwakened.Parent = nil -- regra do projeto: sem :Destroy()
	end

	local awakenedFolder = Instance.new("Folder")
	awakenedFolder.Name = "AwakenedForm"
	awakenedFolder.Parent = baseFolder

	local warnings = {}

	-- (V4) O teto agora é sobre o TOTAL de Tools instaladas, não sobre a
	-- quantidade de IDs. Um único ID de Model pode trazer as 7 de uma vez,
	-- então contar IDs (como o V3 fazia) deixaria de proteger o limite.
	local totalTools = 0

	for _, toolId in ipairs(def.toolIds or {}) do
		if totalTools >= CONFIG.MAX_TOOLS_PER_CHARACTER then
			table.insert(
				warnings,
				string.format(
					"Teto de %d Tools atingido — ID %s e os seguintes foram ignorados",
					CONFIG.MAX_TOOLS_PER_CHARACTER,
					tostring(toolId)
				)
			)
			break
		end

		local loaded, err = loadAssetSafe(toolId)
		if not loaded then
			table.insert(warnings, "Tool " .. tostring(toolId) .. ": " .. tostring(err))
			continue
		end

		local tools = collectTools(loaded)

		if #tools == 0 then
			table.insert(
				warnings,
				string.format(
					"ID %s não tem nenhuma Tool dentro (era %s) — suba uma Tool, ou um Model com Tools dentro",
					tostring(toolId),
					loaded.ClassName
				)
			)
			continue
		end

		local espaco = CONFIG.MAX_TOOLS_PER_CHARACTER - totalTools
		if #tools > espaco then
			table.insert(
				warnings,
				string.format(
					"ID %s traz %d Tools, mas só cabiam %d (teto de %d no total) — as extras foram ignoradas",
					tostring(toolId),
					#tools,
					espaco,
					CONFIG.MAX_TOOLS_PER_CHARACTER
				)
			)
		end

		for i = 1, math.min(#tools, espaco) do
			local tool = tools[i]
			enforceToolRules(tool)
			-- Reparentar tira a Tool de dentro do Model; o GameManager_V9
			-- só olha os filhos DIRETOS de AwakenedForm, então elas têm
			-- que subir um nível aqui.
			tool.Parent = awakenedFolder
			totalTools += 1
		end

		if #tools > 1 then
			print(
				string.format(
					"[AWAKENING V4] ID %s rendeu %d Tools para '%s' (Model com várias)",
					tostring(toolId),
					math.min(#tools, espaco),
					def.characterName
				)
			)
		end
	end

	-- O container do LoadAsset e o Model vazio sobram na memória sem pai;
	-- o coletor do Roblox cuida deles. Nada de :Destroy() aqui (regra do
	-- projeto), e nada de .Parent = nil porque eles nunca tiveram pai no
	-- DataModel.

	if totalTools == 0 and #(def.toolIds or {}) > 0 then
		table.insert(warnings, "Nenhuma Tool foi instalada — confira os IDs")
	end

	local oldImg = imagesFolder:FindFirstChild(def.characterName .. "_Awakened")
	if oldImg then
		oldImg.Parent = nil
	end
	if def.imageId and def.imageId > 0 then
		local img = Instance.new("ImageLabel")
		img.Name = def.characterName .. "_Awakened"
		img.Image = "rbxassetid://" .. tostring(def.imageId)
		img.Size = UDim2.new(1, 0, 1, 0)
		img.BackgroundTransparency = 1
		img.Parent = imagesFolder
	else
		table.insert(warnings, "Sem Image ID — forma despertada ficará sem aparência própria")
	end

	return warnings, nil
end

local function removeAwakenedAssets(name)
	local baseFolder = charactersFolder:FindFirstChild(name)
	if baseFolder then
		local awakenedFolder = baseFolder:FindFirstChild("AwakenedForm")
		if awakenedFolder then
			awakenedFolder.Parent = nil
		end
	end
	local img = imagesFolder:FindFirstChild(name .. "_Awakened")
	if img then
		img.Parent = nil
	end
end

-- =====================================
-- DATASTORE: SALVAR / CARREGAR ÍNDICE
-- =====================================

local function saveIndex(index)
	pcall(function()
		awakeningStore:SetAsync("Index", index)
	end)
end

local function loadIndex()
	local ok, result = pcall(function()
		return awakeningStore:GetAsync("Index")
	end)
	if ok and type(result) == "table" then
		return result
	end
	return {}
end

local function saveDefinition(def)
	pcall(function()
		awakeningStore:SetAsync("Awaken_" .. def.characterName, def)
	end)
	local index = loadIndex()
	if not table.find(index, def.characterName) then
		table.insert(index, def.characterName)
		saveIndex(index)
	end
end

local function loadDefinition(name)
	local ok, result = pcall(function()
		return awakeningStore:GetAsync("Awaken_" .. name)
	end)
	if ok then
		return result
	end
	return nil
end

local function deleteDefinition(name)
	pcall(function()
		awakeningStore:RemoveAsync("Awaken_" .. name)
	end)
	local index = loadIndex()
	local i = table.find(index, name)
	if i then
		table.remove(index, i)
		saveIndex(index)
	end
end

-- =====================================
-- VALIDAÇÃO
-- =====================================

local function validatePayload(payload)
	if type(payload) ~= "table" then
		return false, "Dados inválidos!"
	end
	if type(payload.characterName) ~= "string" or #payload.characterName < 2 then
		return false, "Nome de personagem inválido!"
	end

	-- (V7) NORMALIZA para a grafia canônica do catálogo. Sem isto, um
	-- nome com espaço sobrando entraria assim no DataStore e o Despertar
	-- nunca casaria com o personagem em lugar nenhum do sistema.
	local canonico = resolverNomeOriginal(payload.characterName)
	if canonico then
		payload.characterName = canonico
	end
	-- (V5) BADGE VIROU OPCIONAL.
	-- Até o V4 o Badge era a condição de desbloqueio, porque o Despertar
	-- era um personagem separado que o jogador destravava e equipava.
	-- Agora ele é uma FORMA TEMPORÁRIA do personagem normal, disparada
	-- pela barra do AwakeningMeterServer — quem tem o personagem tem a
	-- forma. O Badge continua aceito para quem quiser gatear um
	-- Despertar específico; em branco, é livre.
	local badgeId = tonumber(payload.badgeId)
	if badgeId and badgeId < 0 then
		return false, "Badge ID inválido!"
	end
	if payload.toolIds and #payload.toolIds > CONFIG.MAX_TOOLS_PER_CHARACTER then
		return false, "Máximo de " .. CONFIG.MAX_TOOLS_PER_CHARACTER .. " Tools na forma despertada!"
	end

	-- (V3) A REGRA QUE FALTAVA: sem personagem original, não há
	-- Despertar. Um Despertar destravado só por Badge, sem original,
	-- é um personagem de emblema comum criado pela porta errada.
	if not originalExists(payload.characterName) then
		-- tostring: o analisador do Luau não consegue estreitar o tipo de
		-- payload.characterName aqui (o payload vem do cliente, sem tipo),
		-- e reclamava do 2º argumento do string.format.
		local msg = string.format(
			"Personagem '%s' não existe no catálogo! O Despertar é uma FORMA de um personagem que já existe — crie o personagem primeiro na aba CATÁLOGO. (Confira também se o nome está escrito exatamente igual.)",
			tostring(payload.characterName)
		)
		return false, msg
	end

	return true, "OK"
end

-- =====================================
-- SINCRONIZAÇÃO ENTRE TODOS OS SERVIDORES
-- (V2) com guarda de JobId + distinção set/update
-- =====================================

local function broadcastAnnouncementLocally(text, isSuccess)
	for _, p in ipairs(Players:GetPlayers()) do
		catalogAnnouncement:FireClient(p, text, isSuccess)
	end
end

local function publishSync(action, name, adminName, isUpdate)
	pcall(function()
		MessagingService:PublishAsync(CONFIG.SYNC_TOPIC, {
			action = action,
			name = name,
			admin = adminName,
			isUpdate = isUpdate or false,
			jobId = game.JobId,
		})
	end)
end

local function setAnnouncementText(adminName, name, isUpdate)
	if isUpdate then
		return string.format("✏️ %s atualizou o Despertar de '%s'!", adminName or "Um admin", name)
	end
	return string.format("⚡ %s configurou o Despertar de '%s'!", adminName or "Um admin", name)
end

local function applyRemoteChange(action, name, adminName, isUpdate)
	if action == "set" then
		local def = loadDefinition(name)
		if def then
			-- (V3) Se o original não existe neste servidor, não constrói
			-- nem registra. Antes isso criava o fantasma aqui também,
			-- espalhando o problema para toda a frota de servidores.
			local warnings, err = buildAwakenedAssets(def)
			if err then
				warn("[AWAKENING V4] Sync de '" .. name .. "' ignorado: " .. err)
				return
			end
			awakenDefs[name] = def
			broadcastAnnouncementLocally(setAnnouncementText(adminName, name, isUpdate), true)
			if #warnings > 0 then
				warn("[AWAKENING V4] Avisos ao sincronizar '" .. name .. "': " .. table.concat(warnings, " | "))
			end
		end
	elseif action == "remove" then
		removeAwakenedAssets(name)
		awakenDefs[name] = nil
		orphanDefs[name] = nil -- (V3)
		broadcastAnnouncementLocally(
			string.format("🗑️ %s removeu o Despertar de '%s'!", adminName or "Um admin", name),
			false
		)
	end
end

pcall(function()
	MessagingService:SubscribeAsync(CONFIG.SYNC_TOPIC, function(message)
		local data = message.Data
		-- (V2) guarda de JobId: não processa o próprio eco
		if type(data) == "table" and data.jobId ~= game.JobId then
			applyRemoteChange(data.action, data.name, data.admin, data.isUpdate)
		end
	end)
end)

-- =====================================
-- REMOTES: ADMIN (CONFIGURAR/EDITAR / REMOVER / LISTAR)
-- =====================================

adminSetAwakening.OnServerInvoke = function(player, payload)
	if not isAdmin(player) then
		player:Kick("Tentativa não autorizada de uso de comandos admin")
		return false, "Sem permissão!"
	end

	local ok, msg = validatePayload(payload)
	if not ok then
		return false, msg
	end

	-- (V2) Despertar já existente pra esse personagem = EDIÇÃO
	local isUpdate = awakenDefs[payload.characterName] ~= nil

	local def = {
		characterName = payload.characterName,
		badgeId = tonumber(payload.badgeId),
		imageId = tonumber(payload.imageId) or 0,
		toolIds = payload.toolIds or {},
		health = tonumber(payload.health) or nil,
		displayName = tostring(payload.displayName or (payload.characterName .. " (Despertado)")),

		-- (V6) Texto do card de informação do Despertar. O card mostra
		-- imagem, nome, história e as Tools — e a história precisava de
		-- um lugar para morar.
		lore = type(payload.lore) == "string" and payload.lore or nil,
		description = type(payload.description) == "string" and payload.description or nil,

		-- (V5) AJUSTE DA BARRA, por personagem.
		-- Em branco, o AwakeningMeterServer usa o padrão dele. Servem
		-- para um Despertar forte ser mais caro de carregar que um fraco.
		medidorMax = tonumber(payload.medidorMax) or nil,
		duracao = tonumber(payload.duracao) or nil,
		cooldown = tonumber(payload.cooldown) or nil,
		ganhoDano = tonumber(payload.ganhoDano) or nil,
		ganhoRecebido = tonumber(payload.ganhoRecebido) or nil,

		addedBy = player.Name,
		addedAt = os.time(),
	}

	-- (V3) Segunda barreira, de propósito. O validatePayload já barrou
	-- o caso normal; esta pega a corrida em que o personagem é apagado
	-- do catálogo entre a validação e a construção. Nada é salvo nem
	-- propagado se a construção recusar.
	local warnings, err = buildAwakenedAssets(def)
	if err then
		return false, err
	end

	awakenDefs[def.characterName] = def
	orphanDefs[def.characterName] = nil -- (V3) deixou de ser órfão
	saveDefinition(def)

	publishSync("set", def.characterName, player.Name, isUpdate)
	broadcastAnnouncementLocally(setAnnouncementText(player.Name, def.characterName, isUpdate), true)

	print(
		string.format(
			"[AWAKENING V4] %s %s Despertar de '%s'",
			player.Name,
			isUpdate and "atualizou" or "configurou",
			def.characterName
		)
	)

	if #warnings > 0 then
		return true, (isUpdate and "Atualizado" or "Configurado") .. " com avisos: " .. table.concat(warnings, " | ")
	end
	if isUpdate then
		return true, "Despertar ATUALIZADO em todos os servidores!"
	end
	return true, "Despertar configurado em todos os servidores!"
end

adminRemoveAwakening.OnServerInvoke = function(player, characterName)
	if not isAdmin(player) then
		player:Kick("Tentativa não autorizada de uso de comandos admin")
		return false, "Sem permissão!"
	end
	if type(characterName) ~= "string" then
		return false, "Nome inválido!"
	end

	removeAwakenedAssets(characterName)
	awakenDefs[characterName] = nil
	orphanDefs[characterName] = nil -- (V3) limpar órfão também
	deleteDefinition(characterName)

	publishSync("remove", characterName, player.Name)
	broadcastAnnouncementLocally(
		string.format("🗑️ %s removeu o Despertar de '%s'!", player.Name, characterName),
		false
	)

	print(string.format("[AWAKENING V4] %s removeu Despertar de '%s'", player.Name, characterName))
	return true, "Despertar removido em todos os servidores!"
end

adminListAwakenings.OnServerInvoke = function(player)
	if not isAdmin(player) then
		return {}
	end
	local list = {}
	for _, def in pairs(awakenDefs) do
		table.insert(list, def)
	end

	-- (V3) Os órfãos TAMBÉM entram na lista. Eles não estão em
	-- awakenDefs porque não foram construídos, mas se ficarem fora
	-- daqui o admin não tem como clicar em 🗑️ para limpá-los — a
	-- correção viraria um beco sem saída.
	--
	-- O aviso vai no displayName porque é o campo que o painel já
	-- mostra: aparece sem precisar mexer no AdminMenuClient. A cópia
	-- é rasa e descartável, então o displayName salvo não é tocado.
	for _, def in pairs(orphanDefs) do
		local copia = {}
		for k, v in pairs(def) do
			copia[k] = v
		end
		copia.isOrphan = true
		copia.displayName = "⚠️ ÓRFÃO (sem personagem original) — " .. tostring(def.displayName or def.characterName)
		table.insert(list, copia)
	end

	return list
end

-- =====================================
-- REMOTES: JOGADOR (CHECAR / DESBLOQUEAR)
-- =====================================

-- Contrato mantido igual ao que o CharacterSystemClient já espera:
-- exists / hasAwakening / hasOriginal / canEquip / awakening.displayName
checkAwakeningRemote.OnServerInvoke = function(player, characterName)
	if type(characterName) ~= "string" then
		return { exists = false }
	end

	local def = awakenDefs[characterName]
	if not def then
		return { exists = false }
	end

	local hasOriginal = _G.PlayerDataManager.ownsCharacter and _G.PlayerDataManager.ownsCharacter(player, characterName)
		or false

	-- (V5) Badge virou OPCIONAL: em branco, o Despertar é de quem tem o
	-- personagem. Com Badge, ele gateia a forma.
	local badgeId = tonumber(def.badgeId)
	local exigeBadge = badgeId ~= nil and badgeId > 0
	local hasBadge = not exigeBadge

	if exigeBadge then
		local ok, has = pcall(function()
			return BadgeService:UserHasBadgeAsync(player.UserId, badgeId)
		end)
		hasBadge = ok and has or false
	end

	-- (V5) canEquip SAIU. O Despertar não é mais um personagem que se
	-- equipa: ele é uma forma temporária que a barra do
	-- AwakeningMeterServer dispara em combate. O card no catálogo é só
	-- informação — imagem, nome e como liberar.
	return {
		exists = true,
		hasAwakening = true,
		hasOriginal = hasOriginal,
		somenteInfo = true,
		exigeBadge = exigeBadge,
		temBadge = hasBadge,
		liberado = hasOriginal and hasBadge,
		awakening = {
			displayName = def.displayName,
			imageId = def.imageId,
			lore = def.lore,
			description = def.description,
			health = def.health,
			duracao = def.duracao,
			cooldown = def.cooldown,
		},
	}
end

equipAwakeningRemote.OnServerEvent:Connect(function(player, characterName)
	if type(characterName) ~= "string" then
		return
	end

	local def = awakenDefs[characterName]
	if not def then
		return
	end

	-- (V5) NÃO FAZ MAIS NADA — de propósito.
	--
	-- Até o V4 este evento DESBLOQUEAVA o Despertar: gravava
	-- addAwakenedCharacter no save e o personagem passava a nascer
	-- desperto para sempre. Agora o Despertar é uma forma temporária,
	-- conquistada em combate pela barra do AwakeningMeterServer — não
	-- há nada para destravar nem para equipar.
	--
	-- O remote continua existindo só para não quebrar clientes antigos
	-- que ainda o disparem: em vez de conceder, ele avisa e ignora.
	-- Quando todos os clientes estiverem no V9+, dá para remover.
	warn(
		string.format(
			"[AWAKENING V7] %s disparou EquipAwakening ('%s'), que foi desativado no V5 — cliente desatualizado?",
			player.Name,
			characterName
		)
	)
end)

-- =====================================
-- BOOT: RECONSTRUIR TUDO A PARTIR DO DATASTORE
-- =====================================

local function bootLoadAwakenings()
	-- (V3) Esperar o catálogo. Sem isso a checagem de original daria
	-- falso negativo na corrida de boot e TODO Despertar legítimo
	-- seria marcado como órfão.
	if _G.CharacterCatalog and _G.CharacterCatalog.isReady then
		local esperou = 0
		while not _G.CharacterCatalog.isReady() and esperou < CONFIG.CATALOG_WAIT do
			task.wait(0.5)
			esperou += 0.5
		end
		if not _G.CharacterCatalog.isReady() then
			warn(
				string.format(
					"[AWAKENING V4] Catálogo não ficou pronto em %ds — seguindo com a pasta Characters como referência",
					CONFIG.CATALOG_WAIT
				)
			)
		end
	end

	print("[AWAKENING V4] Carregando configurações de Despertar salvas...")
	local index = loadIndex()
	local loaded = 0

	for _, name in ipairs(index) do
		local def = loadDefinition(name)
		if def then
			-- (V3) Órfão NÃO é reconstruído. Antes o buildAwakenedAssets
			-- recriava a pasta do personagem inexistente a cada boot,
			-- ressuscitando o fantasma para sempre.
			local warnings, err = buildAwakenedAssets(def)
			if err then
				orphanDefs[name] = def
				table.insert(orphanNames, name)
				warn(string.format("[AWAKENING V4] ⚠️ Despertar ÓRFÃO ignorado: '%s' — %s", name, err))
			else
				awakenDefs[name] = def
				loaded += 1
				if #warnings > 0 then
					warn("[AWAKENING V4] Avisos ao carregar '" .. name .. "': " .. table.concat(warnings, " | "))
				end
			end
		end
	end

	print(string.format("[AWAKENING V4] ✓ %d Despertar(es) carregado(s)", loaded))

	if #orphanNames > 0 then
		warn(
			string.format(
				"[AWAKENING V4] ⚠️ %d Despertar(es) ÓRFÃO(S) encontrado(s): %s\n"
					.. "  Foram criados sem personagem original (bug do V2) e NUNCA poderiam ser\n"
					.. "  desbloqueados, porque ninguém pode possuir um personagem que não existe.\n"
					.. "  Para resolver, escolha um caminho por nome:\n"
					.. "    (a) criar o personagem original na aba CATÁLOGO com esse nome exato, ou\n"
					.. "    (b) remover o Despertar pelo botão 🗑️ do painel admin.\n"
					.. "  Veja a lista a qualquer momento com _G.DebugAwakening()",
				#orphanNames,
				table.concat(orphanNames, ", ")
			)
		)
	end
end

task.spawn(bootLoadAwakenings)

-- =====================================
-- DEBUG
-- =====================================

_G.DebugAwakening = function()
	print("\n========== DEBUG AWAKENING V4 ==========")

	local algum = false
	for name, def in pairs(awakenDefs) do
		algum = true
		print(
			string.format(
				"  ✓ %s → %s | Badge: %d | Tools: %d",
				name,
				def.displayName,
				def.badgeId,
				#(def.toolIds or {})
			)
		)
	end
	if not algum then
		print("  (nenhum Despertar ativo)")
	end

	-- (V3) Órfãos: existem no DataStore, mas o personagem original não
	-- existe. Nunca foram desbloqueáveis, porque ninguém pode possuir
	-- um personagem que não existe.
	local qtdOrfaos = 0
	for _ in pairs(orphanDefs) do
		qtdOrfaos += 1
	end

	if qtdOrfaos > 0 then
		print(string.format("\n  ⚠️ %d ÓRFÃO(S) — sem personagem original:", qtdOrfaos))
		for name, def in pairs(orphanDefs) do
			print(string.format("     %s (Badge: %s)", name, tostring(def.badgeId)))
		end
		print("\n  Como resolver, por nome:")
		print("    (a) criar o personagem original na aba CATÁLOGO com o nome EXATO, ou")
		print("    (b) remover o Despertar pelo botão 🗑️ do painel admin")
		print("        (os órfãos aparecem na lista marcados com ⚠️ ÓRFÃO)")
	end

	print("=========================================\n")
end


-- =====================================
-- (V5) LIMPEZA DO SISTEMA ANTIGO
-- =====================================
-- Quem jogou antes do V5 tem nomes gravados em data.awakenedCharacters:
-- era assim que o Despertar ficava desbloqueado para sempre. Essa lista
-- não manda mais em nada — o GameManager V10 decide a forma pelo
-- medidor, não por ela.
--
-- Deixá-la lá não é inofensivo: o `hasAwakening` do DataManager continua
-- respondendo true, e qualquer script antigo que ainda consulte isso
-- passaria a ver o jogador como permanentemente desperto. Some com ela
-- no login.
--
-- Isso NÃO tira nada de valor do jogador: o Despertar agora vem junto
-- com o personagem normal, então quem tinha desbloqueado continua tendo
-- acesso — e quem não tinha, ganhou.

local function limparDespertarAntigo(player)
	if not (_G.PlayerDataManager and _G.PlayerDataManager.getPlayerData) then
		return
	end

	local dados = _G.PlayerDataManager.getPlayerData(player)
	if not dados then
		return
	end

	local lista = dados.awakenedCharacters
	if type(lista) ~= "table" or #lista == 0 then
		return
	end

	local quantos = #lista
	dados.awakenedCharacters = {}

	if _G.PlayerDataManager.savePlayerData then
		_G.PlayerDataManager.savePlayerData(player)
	end

	print(
		string.format(
			"[AWAKENING V7] 🧹 %s: %d desbloqueio(s) do sistema antigo limpo(s) — o Despertar agora vem junto com o personagem",
			player.Name,
			quantos
		)
	)
end

local function aoEntrar(player)
	task.spawn(function()
		-- Espera os dados do jogador carregarem
		local espera = 0
		while not _G.PlayerDataManager.getPlayerData(player) and espera < 15 do
			task.wait(0.5)
			espera = espera + 0.5
		end
		limparDespertarAntigo(player)
	end)
end

Players.PlayerAdded:Connect(aoEntrar)

-- Quem já estava no servidor quando este script carregou
for _, player in ipairs(Players:GetPlayers()) do
	aoEntrar(player)
end

print([[
╔════════════════════════════════════════════════════╗
║  ⚡ AWAKENING SYSTEM SERVER V4 CARREGADO           ║
╠════════════════════════════════════════════════════╣
║  SUBSTITUI: AwakeningSystemServer V3               ║
║  REMOVER:   AwakeningSystemServer V3               ║
║  DEPENDE DE: AdminRegistryServer_V1, GameManager_V9║
║              CharacterCatalogServer_V6 (NOVO)      ║
╠════════════════════════════════════════════════════╣
║  (V4) 1 ID de Model pode trazer as 7 Tools         ║
║  (V4) Teto de 7 agora é sobre o TOTAL de Tools     ║
╠════════════════════════════════════════════════════╣
║  (V3) NÃO dá mais para criar Despertar solto:      ║
║       exige personagem original no catálogo        ║
║  (V3) Nunca cria pasta de personagem fantasma      ║
║  (V3) Despertar órfão é acusado, não reconstruído  ║
╠════════════════════════════════════════════════════╣
║  (V2) ADMIN_IDS removida → _G.AdminRegistry        ║
║  (V2) Guarda de JobId (sem anúncio duplicado)      ║
║  (V2) Edição reconhecida: "✏️ atualizou"           ║
║  • Condição fixa: possuir o original + Badge       ║
║  • Até 7 Tools no total na forma despertada        ║
╠════════════════════════════════════════════════════╣
║  DEBUG: _G.DebugAwakening()                         ║
╚════════════════════════════════════════════════════╝
]])
