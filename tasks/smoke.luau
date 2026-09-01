-- Esta tarefa roda dentro do motor Roblox pela API Luau Execution.
-- Não cria jogador, não renderiza 3D e não toca em DataStore.

local ServerScriptService = game:GetService("ServerScriptService")

local CatalogoScript = ServerScriptService:FindFirstChild("PassiveCatalog")
local RetroVerse = ServerScriptService:FindFirstChild("RetroVerse")
local NucleoScript = RetroVerse and RetroVerse:FindFirstChild("NucleoCombate_V2")

assert(CatalogoScript and CatalogoScript:IsA("ModuleScript"), "PassiveCatalog não encontrado")
assert(RetroVerse and RetroVerse:IsA("Folder"), "pasta RetroVerse não encontrada")
assert(NucleoScript and NucleoScript:IsA("ModuleScript"), "NucleoCombate_V2 não encontrado")

local Catalogo = require(CatalogoScript)
local Nucleo = require(NucleoScript)

assert(type(Catalogo.contar) == "function", "PassiveCatalog não carregou corretamente")
assert(type(Nucleo.aplicarDano) == "function", "Núcleo de Combate não carregou corretamente")
assert(type(Nucleo.registrarModificador) == "function", "API de modificadores ausente")

local totais = {
	Script = 0,
	LocalScript = 0,
	ModuleScript = 0,
}

for _, instancia in game:GetDescendants() do
	if totais[instancia.ClassName] ~= nil then
		totais[instancia.ClassName] += 1
	end
end

print("[HEADLESS] RetroVerse carregado dentro do motor Roblox")
print(`[HEADLESS] PassiveCatalog: {Catalogo.contar()} passivas`)
print(
	`[HEADLESS] Scripts: {totais.Script} servidor, {totais.LocalScript} cliente, {totais.ModuleScript} módulos`
)

return Catalogo.contar(), totais.Script, totais.LocalScript, totais.ModuleScript
