--!nocheck
-- Harness de asserção da instalação do Adonis.
--
-- Roda os módulos de Config/Settings do Adonis DE VERDADE, do mesmo jeito
-- que o carregador roda (require de cada um, mesclando as chaves numa tabela
-- só), e trava as decisões de segurança que docs/ADONIS.md justifica.
--
-- Por que existe: essas configurações são linhas soltas num arquivo de
-- terceiros. Qualquer atualização do Adonis, ou um merge distraído, devolve
-- os padrões do autor sem quebrar nada visível — o jogo sobe igual, só menos
-- seguro. Teste é o único jeito de isso doer na hora.
--
-- Chamado por tools/test_adonis.py, que passa os fontes já lidos do disco.

local function fakeGame()
	local services = {}
	return {
		GetService = function(_, nome)
			if not services[nome] then
				services[nome] = { Name = nome, __fakeService = true }
			end
			return services[nome]
		end,
	}
end

return function(moduleSources, pluginSources)
	local falhas = {}
	local checagens = 0

	local function conferir(condicao, mensagem)
		checagens += 1
		if not condicao then
			table.insert(falhas, mensagem)
		end
	end

	-- O carregador roda cada módulo e mescla as chaves numa tabela só.
	-- Se dois módulos declarassem a mesma chave, o último ganharia e o
	-- efeito seria invisível — então isso também é conferido.
	local Settings = {}
	local origem = {}
	local game = fakeGame()

	for _, entrada in moduleSources do
		local nome, fonte = entrada.name, entrada.source
		local carregar = loadstring(fonte, nome)
		conferir(carregar ~= nil, `Settings.{nome}: não compila`)
		if carregar then
			local ambiente = setmetatable({ game = game }, { __index = getfenv(0) })
			setfenv(carregar, ambiente)
			local ok, tabela = pcall(carregar)
			conferir(ok, `Settings.{nome}: erro ao rodar — {tostring(tabela)}`)
			conferir(
				ok and type(tabela) == "table",
				`Settings.{nome}: devolveu {typeof(tabela)}, esperado table`
			)
			if ok and type(tabela) == "table" then
				for chave, valor in tabela do
					conferir(
						origem[chave] == nil,
						`chave "{chave}" declarada em Settings.{origem[chave]} E em Settings.{nome} — uma apaga a outra`
					)
					origem[chave] = nome
					Settings[chave] = valor
				end
			end
		end
	end

	local function vazia(valor, rotulo)
		conferir(type(valor) == "table", `{rotulo}: esperado table, veio {typeof(valor)}`)
		if type(valor) == "table" then
			conferir(next(valor) == nil, `{rotulo}: precisa estar VAZIA, tem {#valor} item(ns)`)
		end
	end

	----------------------------------------------------------------
	-- 1. O que impede a publicação de apagar o Adonis
	----------------------------------------------------------------
	-- tasks/apply_code_payload.luau chama AssetService:SavePlaceAsync. Com
	-- HideScript = true o Adonis faz `model.Parent = nil` ao subir, e um
	-- salvamento nesse estado gravaria a place SEM o Adonis. O próprio autor
	-- manda desligar quando o jogo usa SavePlaceAsync.
	conferir(
		Settings.HideScript == false,
		"General.HideScript precisa ser false — a publicação usa AssetService:SavePlaceAsync"
	)

	----------------------------------------------------------------
	-- 2. Segredos e chaves
	----------------------------------------------------------------
	conferir(
		Settings.DataStoreKey ~= "CHANGE_THIS",
		'General.DataStoreKey ainda é o padrão "CHANGE_THIS"'
	)
	conferir(
		type(Settings.DataStoreKey) == "string" and #Settings.DataStoreKey >= 16,
		"General.DataStoreKey: esperada string sorteada de 16+ caracteres"
	)

	-- Trello sai da caixa desligado e TEM DE FICAR. O repositório é público:
	-- AppKey e Token do Trello são credenciais de verdade e nunca podem ser
	-- escritas aqui. Se um dia o Trello for usado, os valores vão nos
	-- segredos da experiência (HttpService:GetSecret), como o próprio
	-- comentário do módulo Trello.lua ensina.
	conferir(Settings.Trello_Enabled == false, "Trello_Enabled precisa ser false")
	conferir(Settings.Trello_AppKey == "", "Trello_AppKey precisa estar VAZIA — é credencial")
	conferir(Settings.Trello_Token == "", "Trello_Token precisa estar VAZIO — é credencial")
	conferir(Settings.Trello_Primary == "", "Trello_Primary precisa estar vazio")
	vazia(Settings.Trello_Secondary, "Trello_Secondary")

	conferir(
		Settings.G_Access_Key ~= "Example_Key",
		'_GAPI.G_Access_Key ainda é o padrão "Example_Key"'
	)

	----------------------------------------------------------------
	-- 3. Menor privilégio
	----------------------------------------------------------------
	-- CodeExecution liga :s / :ls — execução de código arbitrário por
	-- comando. Num jogo com economia e DataStore isso é a chave da casa.
	conferir(Settings.CodeExecution == false, "General.CodeExecution precisa ser false")
	conferir(Settings.G_API == false, "_GAPI.G_API precisa ser false — o jogo não usa _G.Adonis")
	conferir(Settings.G_Access == false, "_GAPI.G_Access precisa ser false")
	conferir(Settings.Console_AdminsOnly == true, "General.Console_AdminsOnly precisa ser true")

	for _, alvo in { "Client", "Settings", "DataStore", "Core", "Admin", "HTTP", "Anti", "Remote" } do
		conferir(
			Settings.Allowed_API_Calls ~= nil and Settings.Allowed_API_Calls[alvo] == false,
			`_GAPI.Allowed_API_Calls.{alvo} precisa ser false`
		)
	end

	-- Listas que rodam comando sozinhas. Vazias, sempre: uma linha aqui é
	-- execução automática em todo jogador que entra ou renasce.
	vazia(Settings.OnStartup, "General.OnStartup")
	vazia(Settings.OnJoin, "General.OnJoin")
	vazia(Settings.OnSpawn, "General.OnSpawn")

	----------------------------------------------------------------
	-- 4. Anti-exploit: DESLIGADO de propósito
	----------------------------------------------------------------
	-- O RetroVerse é jogo de combate: dash, habilidades e Despertar movem o
	-- personagem rápido e às vezes o teleportam. O anti-speed/anti-noclip do
	-- Adonis leria isso como exploit e mataria ou kickaria quem joga certo.
	-- O aviso é do próprio autor, no topo de AntiExploit.lua.
	for _, chave in { "AntiNoclip", "AntiSpeed", "AntiGod", "AntiMultiTool", "AntiRootJointDeletion", "AntiBuildingTools", "AntiAntiIdle", "Detection", "AllowClientAntiExploit" } do
		conferir(
			Settings[chave] == false,
			`AntiExploit.{chave} precisa ser false — falso positivo em dash/Despertar mata jogador legítimo`
		)
	end

	----------------------------------------------------------------
	-- 5. Não atropelar a UI do jogo
	----------------------------------------------------------------
	-- O HUD de HP (HealthDisplay V9) vive no canto superior direito, e as
	-- notificações do Adonis nascem na borda de cima.
	conferir(Settings.TopBarShift == true, "General.TopBarShift precisa ser true — senão cobre o HUD de HP")
	conferir(Settings.HelpButton == false, "General.HelpButton precisa ser false — nasce sobre a UI do jogo")
	conferir(Settings.DonorCapes == false, "Donor.DonorCapes precisa ser false")
	conferir(Settings.DonorCommands == false, "Donor.DonorCommands precisa ser false")
	-- AutoClean varre o workspace. O jogo dropa moeda no chão
	-- (SimpleCharacterCoinDrop) — varrer isso apagaria recompensa de jogador.
	conferir(Settings.AutoClean == false, "General.AutoClean precisa ser false — o jogo dropa moeda no chão")

	----------------------------------------------------------------
	-- 6. Quem é admin
	----------------------------------------------------------------
	local DONO = 1595442496 -- mesmo OWNER_ID de AdminRegistryServer.server.lua
	local ranks = Settings.Ranks
	conferir(type(ranks) == "table", "Ranks: esperado table")
	if type(ranks) == "table" then
		local creators = ranks.Creators
		conferir(type(creators) == "table", "Ranks.Creators: esperado table")
		if type(creators) == "table" then
			local achou = false
			for _, id in creators.Users or {} do
				if id == DONO then
					achou = true
				end
			end
			conferir(achou, `Ranks.Creators precisa conter o dono ({DONO})`)
			conferir(
				#(creators.Users or {}) == 1,
				"Ranks.Creators: só o dono no código; os outros entram por :admin dentro do jogo"
			)
		end
		-- Os demais ranks ficam vazios: admin novo entra por comando, que
		-- persiste no DataStore do Adonis e não exige publicação.
		for _, rank in { "Moderators", "Admins", "HeadAdmins" } do
			conferir(
				type(ranks[rank]) == "table" and next(ranks[rank].Users or {}) == nil,
				`Ranks.{rank}.Users precisa estar vazio — use :admin dentro do jogo`
			)
		end
	end

	vazia(Settings.Banned, "General.Banned")
	vazia(Settings.Muted, "General.Muted")
	vazia(Settings.Blacklist, "General.Blacklist")
	vazia(Settings.Whitelist, "General.Whitelist")
	conferir(Settings.WhitelistEnabled == false, "General.WhitelistEnabled precisa ser false — senão o jogo fecha")

	----------------------------------------------------------------
	-- 7. Plugins não podem dar comando a jogador comum
	----------------------------------------------------------------
	-- O plugin de exemplo do autor registrava :example com
	-- AdminLevel = "Players", ou seja, qualquer jogador. Aqui o plugin roda
	-- de verdade contra um Vargs falso e o teste exige que ele não registre
	-- comando nenhum.
	for _, entrada in pluginSources do
		local nome, fonte = entrada.name, entrada.source
		local carregar = loadstring(fonte, nome)
		conferir(carregar ~= nil, `Plugin {nome}: não compila`)
		if carregar then
			local ok, plugin = pcall(carregar)
			conferir(ok and type(plugin) == "function", `Plugin {nome}: precisa devolver function`)
			if ok and type(plugin) == "function" then
				local comandos = {}
				local eventos = setmetatable({}, {
					__index = function()
						return { Connect = function() end }
					end,
				})
				local vargs = {
					Server = { Commands = comandos, Settings = Settings },
					Client = { UI = { Make = function() end } },
					Service = { Events = eventos },
				}
				local rodou, erro = pcall(plugin, vargs)
				conferir(rodou, `Plugin {nome}: erro ao rodar — {tostring(erro)}`)
				conferir(
					next(comandos) == nil,
					`Plugin {nome}: registrou comando. Comando de plugin precisa de revisão de nível de admin`
				)
			end
		end
	end

	if #falhas > 0 then
		print(`\n{#falhas} falha(s) na instalação do Adonis:\n`)
		for _, f in falhas do
			print(`  x {f}`)
		end
		error(`instalação do Adonis reprovada em {#falhas} de {checagens} checagens`, 0)
	end

	print(`Adonis: {checagens} checagens de instalação e segurança passaram`)
end
