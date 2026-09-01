local Catalogo = require("../src/ServerScriptService/PassiveCatalog")

assert(type(Catalogo) == "table", "PassiveCatalog deve retornar uma tabela")
assert(Catalogo.MAX_NIVEL == 10, "MAX_NIVEL inesperado")
assert(type(Catalogo.LISTA) == "table", "LISTA deve ser uma tabela")
assert(Catalogo.contar() == #Catalogo.LISTA, "contar() diverge de LISTA")
assert(#Catalogo.LISTA > 0, "o catálogo não pode ficar vazio")

local ids = {}

for indice, passiva in ipairs(Catalogo.LISTA) do
	assert(type(passiva.id) == "string" and passiva.id ~= "", `passiva {indice} sem id`)
	assert(not ids[passiva.id], `id duplicado: {passiva.id}`)
	assert(type(passiva.nome) == "string" and passiva.nome ~= "", `passiva {passiva.id} sem nome`)
	assert(passiva.tipo == "permanente" or passiva.tipo == "temporario", `tipo inválido: {passiva.id}`)
	ids[passiva.id] = true
end

assert(type(Catalogo.custoDoNivel(1)) == "number", "nível 1 precisa ter custo")
assert(Catalogo.custoDoNivel(Catalogo.MAX_NIVEL) == nil, "nível máximo não pode ter próximo custo")

print(`[TESTE PURO] PassiveCatalog válido: {Catalogo.contar()} passivas`)
