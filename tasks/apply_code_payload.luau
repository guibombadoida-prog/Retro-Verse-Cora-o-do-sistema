--!nocheck
-- Executada somente pela Open Cloud Luau Execution.
-- O cliente Python acrescenta RETROVERSE_MODE e os IDs esperados no início
-- deste mesmo chunk antes de enviá-lo à Roblox.

local SCRIPT_CLASSES = {
	Script = true,
	LocalScript = true,
	ModuleScript = true,
}

-- Nomes que o mesmo script já teve dentro do place. Quando o nome canônico do
-- repositório não existe ali mas o antigo existe, a publicação renomeia a
-- instância em vez de criar uma segunda cópia rodando em paralelo. Cada entrada
-- foi confirmada por tamanho idêntico do Source ou pelo cabeçalho "-- Nome:"
-- lido do próprio script no place. Depois da primeira publicação a entrada
-- deixa de casar com qualquer coisa e fica inerte.
local LEGACY_NAMES = {
	["ServerScriptService > AntiLag"] = "Anti-Anti-Lag Script",
	["StarterPlayer > StarterCharacterScripts > Health"] = "Heatlh",
	["StarterPlayer > StarterCharacterScripts > SimpleCharacterCoinDrop"] = "Simple Character Coin Drop",
	["StarterPlayer > StarterPlayerScripts > ClientSync"] = "Client Sync",
	["StarterPlayer > StarterPlayerScripts > MissionsMenuClient"] = "MISSIONS MENU CLIENT",
	["StarterPlayer > StarterPlayerScripts > MusicPlayerClient_V2"] = "MusicPlayerClient",
	["StarterPlayer > StarterPlayerScripts > RetroHotbarClient"] = "RetroHotbarClient_V1",
	["StarterPlayer > StarterPlayerScripts > TeamMenuClient_V2"] = "TeamMenuClient",
	["StarterPlayer > StarterPlayerScripts > TutorialMenuClient_V2"] = "TutorialMenuClient",
	["ServerScriptService > DamageIndicatorServer"] = "dmgindi",
	["StarterPlayer > StarterPlayerScripts > DamageIndicatorClient"] = "dmgindicator",
}

local runArguments = ({ ... })[1]
assert(type(runArguments) == "table" and runArguments.BinaryInput, "pacote binário de código ausente")
assert(RETROVERSE_MODE == "check" or RETROVERSE_MODE == "publish", "modo inválido")
assert(tonumber(EXPECTED_UNIVERSE_ID) == game.GameId, "Universe ID não corresponde ao place carregado")
assert(tonumber(EXPECTED_PLACE_ID) == game.PlaceId, "Place ID não corresponde ao place carregado")

local SerializationService = game:GetService("SerializationService")
local AssetService = game:GetService("AssetService")

local roots = SerializationService:DeserializeInstancesAsync(runArguments.BinaryInput)
assert(#roots == 1, `esperado 1 objeto raiz no pacote, encontrados {#roots}`)

local payload = roots[1]
assert(payload:IsA("Folder"), "a raiz do pacote precisa ser Folder")
assert(payload.Name == "RetroVerseCodePayload", "nome inesperado na raiz do pacote")

local function pathFromPayload(instance)
	local parts = {}
	local current = instance
	while current and current ~= payload do
		table.insert(parts, 1, current.Name)
		current = current.Parent
	end
	assert(current == payload, "instância fora da raiz do pacote")
	return parts
end

local function displayPath(parts)
	return table.concat(parts, " > ")
end

-- Todo script do projeto começa com um cabeçalho `-- Nome: X`. Ler esse campo
-- identifica um script do place com muito mais segurança do que o nome da
-- instância, que já foi cortado e reescrito por versões antigas do promover.sh.
local function headerName(source)
	local line = 0
	for text in string.gmatch(source, "[^\r\n]+") do
		line += 1
		if line > 25 then
			break
		end
		local nome = string.match(text, "^%s*%-%-%s*Nome:%s*(.-)%s*$")
		if nome and nome ~= "" then
			return nome
		end
	end
	return nil
end

local function findChildrenByName(parent, name)
	local found = {}
	for _, child in parent:GetChildren() do
		if child.Name == name then
			table.insert(found, child)
		end
	end
	return found
end

local scripts = {}
for _, instance in payload:GetDescendants() do
	if SCRIPT_CLASSES[instance.ClassName] then
		table.insert(scripts, instance)
	end
end

table.sort(scripts, function(left, right)
	return displayPath(pathFromPayload(left)) < displayPath(pathFromPayload(right))
end)
assert(#scripts > 0, "nenhum script foi encontrado no pacote")

local unchanged = 0
local changes = {}
local creations = {}
local renames = {}
local problems = {}

-- Contêineres que ainda não existem no place. A chave é o caminho completo, para
-- que dois scripts irmãos não peçam a mesma pasta duas vezes.
local plannedFolders = {}

-- Cada contêiner tocado pelo pacote, com os nomes que o repositório reivindica
-- ali. O que sobrar são scripts que só existem no place.
local containers = {}
local containerOrder = {}

-- Resolve os contêineres do caminho (tudo menos a folha). Quando uma pasta não
-- existe no place, ela é planejada aqui mesmo e só vai ao ar no modo publicar.
-- Devolve o pai a usar, ou nil mais a explicação do que impede a resolução.
local function resolveParent(parts)
	local current = game
	for index = 1, #parts - 1 do
		local partial = table.concat(parts, " > ", 1, index)
		local planned = plannedFolders[partial]
		if planned then
			current = planned.instance
		else
			local found = findChildrenByName(current, parts[index])
			if #found > 1 then
				return nil, `há {#found} objetos chamados {parts[index]} em {partial}`
			elseif #found == 1 then
				current = found[1]
			else
				local folder = Instance.new("Folder")
				folder.Name = parts[index]
				plannedFolders[partial] = { instance = folder, parent = current, path = partial }
				print(`+ {partial} (pasta nova)`)
				current = folder
			end
		end
	end
	return current, nil
end

-- Primeiro classifica tudo. Nenhuma escrita começa antes do relatório completo,
-- para que um caminho errado não deixe o place pela metade.
for _, sourceScript in scripts do
	local parts = pathFromPayload(sourceScript)
	local path = displayPath(parts)
	local parent, impedimento = resolveParent(parts)

	if impedimento then
		table.insert(problems, `{path}: {impedimento}`)
		print(`! {path} — {impedimento}`)
	else
		local containerPath = table.concat(parts, " > ", 1, #parts - 1)
		local container = containers[containerPath]
		if not container then
			container = { instance = parent, claimed = {} }
			containers[containerPath] = container
			table.insert(containerOrder, containerPath)
		end
		container.claimed[parts[#parts]] = true

		local found = findChildrenByName(parent, parts[#parts])
		if #found > 1 then
			local detalhe = `há {#found} objetos chamados {parts[#parts]} em {path}`
			table.insert(problems, `{path}: {detalhe}`)
			print(`! {path} — {detalhe}`)
		elseif #found == 0 then
			local legacy = LEGACY_NAMES[path]
			local legacyFound = legacy and findChildrenByName(parent, legacy) or {}
			if #legacyFound > 1 then
				local detalhe = `há {#legacyFound} objetos chamados {legacy} em {containerPath}`
				table.insert(problems, `{path}: {detalhe}`)
				print(`! {path} — {detalhe}`)
			elseif #legacyFound == 1 and legacyFound[1].ClassName ~= sourceScript.ClassName then
				local detalhe = `{legacy} é {legacyFound[1].ClassName}, pacote exige {sourceScript.ClassName}`
				table.insert(problems, `{path}: {detalhe}`)
				print(`! {path} — {detalhe}`)
			elseif #legacyFound == 1 then
				local targetScript = legacyFound[1]
				-- Reivindica o nome antigo para que ele não seja listado como órfão.
				container.claimed[legacy] = true
				table.insert(renames, {
					path = path,
					target = targetScript,
					oldName = legacy,
					newName = parts[#parts],
				})
				if targetScript.Source == sourceScript.Source then
					print(`> {path} — renomeia "{legacy}"; código já igual`)
				else
					table.insert(changes, {
						path = path,
						target = targetScript,
						oldSource = targetScript.Source,
						newSource = sourceScript.Source,
					})
					print(`> {path} — renomeia "{legacy}" e atualiza o código`)
				end
			else
				table.insert(creations, { path = path, parent = parent, source = sourceScript })
				print(`+ {path} (script novo)`)
			end
		else
			local targetScript = found[1]
			if targetScript.ClassName ~= sourceScript.ClassName then
				local detalhe =
					`classe no place é {targetScript.ClassName}, pacote exige {sourceScript.ClassName}`
				table.insert(problems, `{path}: {detalhe}`)
				print(`! {path} — {detalhe}`)
			elseif targetScript.Source == sourceScript.Source then
				unchanged += 1
				print(`= {path}`)
			else
				table.insert(changes, {
					path = path,
					target = targetScript,
					oldSource = targetScript.Source,
					newSource = sourceScript.Source,
				})
				print(`~ {path}`)
			end
		end
	end
end

local plannedFolderCount = 0
for _ in plannedFolders do
	plannedFolderCount += 1
end

-- Scripts que existem no place e não no repositório. Quase sempre são o mesmo
-- sistema salvo com outro nome: cruzar esta lista com as linhas + revela se um
-- "script novo" na verdade já está no jogo e seria duplicado.
local orphans = {}
for _, containerPath in containerOrder do
	local container = containers[containerPath]
	if not plannedFolders[containerPath] then
		for _, child in container.instance:GetChildren() do
			if SCRIPT_CLASSES[child.ClassName] and not container.claimed[child.Name] then
				local nome = headerName(child.Source)
				local etiqueta = nome and `cabeçalho "{nome}"` or "sem cabeçalho"
				table.insert(
					orphans,
					`{containerPath} > {child.Name} ({child.ClassName}) — {etiqueta}, {#child.Source} bytes`
				)
			end
		end
	end
end
table.sort(orphans)

if #orphans > 0 then
	print(`Scripts no place que não existem no repositório ({#orphans}):`)
	for _, orphan in orphans do
		print(`  ? {orphan}`)
	end
end

print(
	`Resumo: {#scripts} scripts; {unchanged} iguais; {#changes} diferentes; `
		.. `{#renames} renomeados; {#creations} novos; {plannedFolderCount} pastas novas; `
		.. `{#orphans} só no place; {#problems} problemas`
)

if #problems > 0 then
	print("Problemas encontrados:")
	for _, problem in problems do
		print(`  ! {problem}`)
	end
end

if RETROVERSE_MODE == "check" then
	print("[VERIFICAÇÃO] nenhuma alteração foi salva")
	return "check", #scripts, unchanged, #changes, #renames, #creations, #problems
end

assert(
	#problems == 0,
	`{#problems} problema(s) impedem a publicação; nada foi alterado (veja as linhas com !)`
)

if #changes == 0 and #creations == 0 and #renames == 0 then
	print("[PUBLICAÇÃO] nada mudou; nenhuma versão nova foi criada")
	return "unchanged", #scripts, unchanged, 0, 0, 0, 0
end

-- Tudo o que for criado ou alterado entra nesta lista para poder ser desfeito
-- caso alguma escrita seguinte falhe.
local applied = {}

local function rollback()
	for index = #applied, 1, -1 do
		local previous = applied[index]
		pcall(function()
			if previous.created then
				previous.instance.Parent = nil
			elseif previous.renamed then
				previous.target.Name = previous.oldName
			else
				previous.target.Source = previous.oldSource
			end
		end)
	end
end

for _, rename in renames do
	local ok, problem = pcall(function()
		rename.target.Name = rename.newName
	end)
	if not ok then
		rollback()
		error(`falha ao renomear {rename.oldName}; alterações desta tarefa foram revertidas: {problem}`)
	end
	table.insert(applied, { renamed = true, target = rename.target, oldName = rename.oldName })
end

for _, planned in plannedFolders do
	local ok, problem = pcall(function()
		planned.instance.Parent = planned.parent
	end)
	if not ok then
		rollback()
		error(`falha ao criar a pasta {planned.path}; alterações desta tarefa foram revertidas: {problem}`)
	end
	table.insert(applied, { created = true, instance = planned.instance })
end

for _, creation in creations do
	local ok, problem = pcall(function()
		local novo = Instance.new(creation.source.ClassName)
		novo.Name = creation.source.Name
		novo.Source = creation.source.Source
		-- RunContext só existe em Script/LocalScript; ignorado onde não se aplica.
		pcall(function()
			novo.RunContext = creation.source.RunContext
		end)
		novo.Parent = creation.parent
		table.insert(applied, { created = true, instance = novo })
	end)
	if not ok then
		rollback()
		error(`falha ao criar {creation.path}; alterações desta tarefa foram revertidas: {problem}`)
	end
end

for _, change in changes do
	local ok, problem = pcall(function()
		change.target.Source = change.newSource
	end)
	if not ok then
		rollback()
		error(`falha ao alterar {change.path}; alterações desta tarefa foram revertidas: {problem}`)
	end
	table.insert(applied, { created = false, target = change.target, oldSource = change.oldSource })
end

local saved, saveProblem = pcall(function()
	-- false publica uma nova versão jogável. O place carregado é a versão atual;
	-- somente os Source acima foram tocados, então mapa e demais instâncias ficam.
	AssetService:SavePlaceAsync({ SaveWithoutPublish = false })
end)
assert(saved, `SavePlaceAsync falhou: {saveProblem}`)

print(
	`[PUBLICAÇÃO] {#changes} atualizados, {#renames} renomeados, {#creations} criados, `
		.. `{plannedFolderCount} pastas criadas`
)
return "published", #scripts, unchanged, #changes, #renames, #creations, 0
