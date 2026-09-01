--!nocheck
-- Executada somente pela Open Cloud Luau Execution.
-- O cliente Python acrescenta RETROVERSE_MODE e os IDs esperados no início
-- deste mesmo chunk antes de enviá-lo à Roblox.

local SCRIPT_CLASSES = {
	Script = true,
	LocalScript = true,
	ModuleScript = true,
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

local function findUniqueChild(parent, name, fullPath)
	local match = nil
	local count = 0
	for _, child in parent:GetChildren() do
		if child.Name == name then
			match = child
			count += 1
		end
	end
	assert(count == 1, `{fullPath}: esperado 1 objeto chamado {name}, encontrados {count}`)
	return match
end

local function resolveTarget(parts)
	local current = game
	for index, name in parts do
		local partial = table.concat(parts, " > ", 1, index)
		current = findUniqueChild(current, name, partial)
	end
	return current
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

-- Primeiro resolve e compara tudo. Se um caminho ou uma classe estiver errado,
-- nenhuma escrita é iniciada.
for _, sourceScript in scripts do
	local parts = pathFromPayload(sourceScript)
	local path = displayPath(parts)
	local targetScript = resolveTarget(parts)
	assert(
		targetScript.ClassName == sourceScript.ClassName,
		`{path}: classe no place é {targetScript.ClassName}, pacote exige {sourceScript.ClassName}`
	)

	if targetScript.Source == sourceScript.Source then
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

print(`Resumo: {#scripts} scripts; {unchanged} iguais; {#changes} diferentes`)

if RETROVERSE_MODE == "check" then
	print("[VERIFICAÇÃO] nenhuma alteração foi salva")
	return "check", #scripts, unchanged, #changes
end

if #changes == 0 then
	print("[PUBLICAÇÃO] nada mudou; nenhuma versão nova foi criada")
	return "unchanged", #scripts, unchanged, 0
end

local applied = {}
for _, change in changes do
	local ok, problem = pcall(function()
		change.target.Source = change.newSource
	end)
	if not ok then
		for index = #applied, 1, -1 do
			local previous = applied[index]
			pcall(function()
				previous.target.Source = previous.oldSource
			end)
		end
		error(`falha ao alterar {change.path}; alterações desta tarefa foram revertidas: {problem}`)
	end
	table.insert(applied, change)
end

local saved, saveProblem = pcall(function()
	-- false publica uma nova versão jogável. O place carregado é a versão atual;
	-- somente os Source acima foram tocados, então mapa e demais instâncias ficam.
	AssetService:SavePlaceAsync({ SaveWithoutPublish = false })
end)
assert(saved, `SavePlaceAsync falhou: {saveProblem}`)

print(`[PUBLICAÇÃO] nova versão criada com {#changes} Source alterados`)
return "published", #scripts, unchanged, #changes
