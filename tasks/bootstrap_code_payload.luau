--!nocheck
-- Prepara SOMENTE uma experience privada de teste com a árvore de scripts.
-- O cliente Python injeta RETROVERSE_MODE, os IDs esperados e os IDs de
-- produção proibidos no início deste chunk.

local SCRIPT_CLASSES = {
	Script = true,
	LocalScript = true,
	ModuleScript = true,
}

local ALLOWED_ROOTS = {
	ReplicatedFirst = true,
	ServerScriptService = true,
	StarterPlayer = true,
}

local ALLOWED_STARTER_CONTAINERS = {
	StarterCharacterScripts = true,
	StarterPlayerScripts = true,
}

local KNOWN_PRODUCTION_PLACE_IDS = {
	[133619220682618] = true,
}

local MAX_SCRIPTS = 200
local MAX_FOLDERS = 100
local MAX_SOURCE_BYTES = 500000

local runArguments = ({ ... })[1]
assert(type(runArguments) == "table" and runArguments.BinaryInput, "pacote binário de código ausente")
assert(
	RETROVERSE_MODE == "bootstrap-check" or RETROVERSE_MODE == "bootstrap",
	"modo de bootstrap inválido"
)

local expectedUniverseId = tonumber(EXPECTED_UNIVERSE_ID)
local expectedPlaceId = tonumber(EXPECTED_PLACE_ID)
local forbiddenUniverseId = tonumber(FORBIDDEN_PRODUCTION_UNIVERSE_ID)
local forbiddenPlaceId = tonumber(FORBIDDEN_PRODUCTION_PLACE_ID)

assert(expectedUniverseId and expectedUniverseId == game.GameId, "Universe ID não corresponde ao place carregado")
assert(expectedPlaceId and expectedPlaceId == game.PlaceId, "Place ID não corresponde ao place carregado")
assert(forbiddenUniverseId, "Universe ID de produção proibido não foi informado")
assert(forbiddenPlaceId, "Place ID de produção proibido não foi informado")
assert(game.GameId ~= forbiddenUniverseId, "BOOTSTRAP RECUSADO: esta é a experience de produção")
assert(game.PlaceId ~= forbiddenPlaceId, "BOOTSTRAP RECUSADO: este é o place de produção")
assert(not KNOWN_PRODUCTION_PLACE_IDS[game.PlaceId], "BOOTSTRAP RECUSADO: Place ID público conhecido")

local SerializationService = game:GetService("SerializationService")
local AssetService = game:GetService("AssetService")

local roots = SerializationService:DeserializeInstancesAsync(runArguments.BinaryInput)
assert(#roots == 1, `esperado 1 objeto raiz no pacote, encontrados {#roots}`)

local payload = roots[1]
assert(payload:IsA("Folder"), "a raiz do pacote precisa ser Folder")
assert(payload.Name == "RetroVerseCodePayload", "nome inesperado na raiz do pacote")

local foldersToCreate = {}
local scriptsToCreate = {}
local scriptsToUpdate = {}
local scriptCount = 0

local function cloneParts(parts)
	local result = {}
	for index, value in parts do
		result[index] = value
	end
	return result
end

local function appendPart(parts, value)
	local result = cloneParts(parts)
	table.insert(result, value)
	return result
end

local function pathText(parts)
	return table.concat(parts, " > ")
end

local function findUniqueChildOrNil(parent, name, fullPath)
	local match = nil
	local count = 0
	for _, child in parent:GetChildren() do
		if child.Name == name then
			match = child
			count += 1
		end
	end
	assert(count <= 1, `{fullPath}: encontrados {count} objetos chamados {name}`)
	return match
end

local function targetRoot(name)
	assert(ALLOWED_ROOTS[name], `raiz não permitida no pacote: {name}`)
	return game:GetService(name)
end

local function inspectFolder(payloadFolder, targetFolder, parts)
	local payloadNames = {}
	for _, child in payloadFolder:GetChildren() do
		assert(child.Name ~= "", `{pathText(parts)}: objeto sem nome no pacote`)
		assert(not payloadNames[child.Name], `{pathText(parts)}: nome duplicado no pacote: {child.Name}`)
		payloadNames[child.Name] = true

		local childParts = appendPart(parts, child.Name)
		local childPath = pathText(childParts)
		if child:IsA("Folder") then
			local targetChild = nil
			if targetFolder then
				targetChild = findUniqueChildOrNil(targetFolder, child.Name, childPath)
				if targetChild then
					assert(targetChild:IsA("Folder"), `{childPath}: esperado Folder, encontrado {targetChild.ClassName}`)
				end
			end
			if not targetChild then
				table.insert(foldersToCreate, {
					parts = childParts,
					path = childPath,
				})
			end
			inspectFolder(child, targetChild, childParts)
		elseif SCRIPT_CLASSES[child.ClassName] then
			scriptCount += 1
			assert(#child.Source <= MAX_SOURCE_BYTES, `{childPath}: Source excede o limite de segurança`)
			local targetScript = nil
			if targetFolder then
				targetScript = findUniqueChildOrNil(targetFolder, child.Name, childPath)
			end

			if targetScript then
				assert(
					targetScript.ClassName == child.ClassName,
					`{childPath}: classe existente é {targetScript.ClassName}, pacote exige {child.ClassName}`
				)
				if targetScript.Source == child.Source then
					print(`= {childPath}`)
				else
					table.insert(scriptsToUpdate, {
						path = childPath,
						target = targetScript,
						oldSource = targetScript.Source,
						newSource = child.Source,
					})
					print(`~ {childPath}`)
				end
			else
				table.insert(scriptsToCreate, {
					parts = childParts,
					path = childPath,
					source = child,
				})
				print(`+ {childPath} ({child.ClassName})`)
			end
		else
			error(`{childPath}: classe não permitida no pacote: {child.ClassName}`)
		end
	end
end

local seenRoots = {}
for _, payloadRoot in payload:GetChildren() do
	assert(payloadRoot:IsA("Folder"), `raiz {payloadRoot.Name} precisa ser Folder`)
	assert(ALLOWED_ROOTS[payloadRoot.Name], `raiz não permitida: {payloadRoot.Name}`)
	assert(not seenRoots[payloadRoot.Name], `raiz duplicada: {payloadRoot.Name}`)
	seenRoots[payloadRoot.Name] = true

	if payloadRoot.Name == "StarterPlayer" then
		local seenContainers = {}
		local starterPlayer = targetRoot("StarterPlayer")
		for _, payloadContainer in payloadRoot:GetChildren() do
			assert(payloadContainer:IsA("Folder"), `StarterPlayer > {payloadContainer.Name}: esperado Folder no pacote`)
			assert(
				ALLOWED_STARTER_CONTAINERS[payloadContainer.Name],
				`container StarterPlayer não permitido: {payloadContainer.Name}`
			)
			assert(not seenContainers[payloadContainer.Name], `container duplicado: {payloadContainer.Name}`)
			seenContainers[payloadContainer.Name] = true

			local containerPath = `StarterPlayer > {payloadContainer.Name}`
			local targetContainer = findUniqueChildOrNil(starterPlayer, payloadContainer.Name, containerPath)
			assert(targetContainer, `{containerPath}: container padrão ausente no place`)
			inspectFolder(payloadContainer, targetContainer, { "StarterPlayer", payloadContainer.Name })
		end
		for containerName in ALLOWED_STARTER_CONTAINERS do
			assert(seenContainers[containerName], `container ausente no pacote: StarterPlayer > {containerName}`)
		end
	else
		inspectFolder(payloadRoot, targetRoot(payloadRoot.Name), { payloadRoot.Name })
	end
end

for rootName in ALLOWED_ROOTS do
	assert(seenRoots[rootName], `raiz obrigatória ausente no pacote: {rootName}`)
end
assert(scriptCount > 0, "nenhum script encontrado no pacote")
assert(scriptCount <= MAX_SCRIPTS, `pacote tem {scriptCount} scripts; limite é {MAX_SCRIPTS}`)
assert(#foldersToCreate <= MAX_FOLDERS, `pacote criaria {#foldersToCreate} pastas; limite é {MAX_FOLDERS}`)

print(
	`Resumo bootstrap: {scriptCount} scripts; `
		.. `{#foldersToCreate} pastas novas; {#scriptsToCreate} scripts novos; `
		.. `{#scriptsToUpdate} Sources diferentes`
)

if RETROVERSE_MODE == "bootstrap-check" then
	print("[PLANEJAMENTO] nenhuma instância foi criada e nada foi salvo")
	return "bootstrap-check", scriptCount, #foldersToCreate, #scriptsToCreate, #scriptsToUpdate
end

if #foldersToCreate == 0 and #scriptsToCreate == 0 and #scriptsToUpdate == 0 then
	print("[BOOTSTRAP] tudo já está igual; nenhuma versão nova foi criada")
	return "unchanged", scriptCount, 0, 0, 0
end

local function resolvePath(parts)
	local current = targetRoot(parts[1])
	for index = 2, #parts do
		local partial = table.concat(parts, " > ", 1, index)
		current = findUniqueChildOrNil(current, parts[index], partial)
		assert(current, `{partial}: caminho não existe durante aplicação`)
	end
	return current
end

local function parentParts(parts)
	local result = {}
	for index = 1, #parts - 1 do
		result[index] = parts[index]
	end
	return result
end

table.sort(foldersToCreate, function(left, right)
	if #left.parts ~= #right.parts then
		return #left.parts < #right.parts
	end
	return left.path < right.path
end)
table.sort(scriptsToCreate, function(left, right)
	return left.path < right.path
end)
table.sort(scriptsToUpdate, function(left, right)
	return left.path < right.path
end)

local created = {}
local createdBaseScripts = {}
local updated = {}

local function rollback()
	for index = #updated, 1, -1 do
		local change = updated[index]
		pcall(function()
			change.target.Source = change.oldSource
		end)
	end
	for index = #created, 1, -1 do
		pcall(function()
			created[index].Parent = nil
		end)
	end
end

local applied, applyProblem = pcall(function()
	for _, folderChange in foldersToCreate do
		local parent = resolvePath(parentParts(folderChange.parts))
		local folder = Instance.new("Folder")
		folder.Name = folderChange.parts[#folderChange.parts]
		folder.Parent = parent
		table.insert(created, folder)
	end

	for _, scriptChange in scriptsToCreate do
		local parent = resolvePath(parentParts(scriptChange.parts))
		local sourceScript = scriptChange.source
		local newScript = Instance.new(sourceScript.ClassName)
		newScript.Name = sourceScript.Name
		if newScript:IsA("BaseScript") then
			newScript.Disabled = true
		end
		newScript.Source = sourceScript.Source
		newScript.Parent = parent
		table.insert(created, newScript)
		if newScript:IsA("BaseScript") then
			table.insert(createdBaseScripts, {
				target = newScript,
				disabled = sourceScript.Disabled,
			})
		end
	end

	for _, sourceChange in scriptsToUpdate do
		sourceChange.target.Source = sourceChange.newSource
		table.insert(updated, sourceChange)
	end

	-- Todos os caminhos e Sources já existem antes de qualquer Script novo
	-- ser habilitado. LocalScripts não executam sem jogador nesta tarefa.
	for _, baseScript in createdBaseScripts do
		baseScript.target.Disabled = baseScript.disabled
	end
end)

if not applied then
	rollback()
	error(`bootstrap falhou; alterações em memória revertidas: {applyProblem}`)
end

local saved, saveProblem = pcall(function()
	AssetService:SavePlaceAsync({ SaveWithoutPublish = false })
end)
if not saved then
	rollback()
	error(`SavePlaceAsync falhou; alterações em memória revertidas: {saveProblem}`)
end

print(
	`[BOOTSTRAP] versão privada criada: {#foldersToCreate} pastas, `
		.. `{#scriptsToCreate} scripts novos e {#scriptsToUpdate} Sources atualizados`
)
return "bootstrapped", scriptCount, #foldersToCreate, #scriptsToCreate, #scriptsToUpdate
