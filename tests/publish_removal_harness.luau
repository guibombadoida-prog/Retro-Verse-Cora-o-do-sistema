--!nocheck
-- Testes da REMOÇÃO de instâncias em tasks/apply_code_payload.luau.
--
-- Por que este teste existe, e por que ele é o mais importante do
-- repositório: a remoção é a única coisa que a publicação faz que **não
-- tem desfazer** do lado do jogo. Um erro aqui apaga script de uma place
-- de produção. As outras operações sobrescrevem `Source`, e o histórico de
-- versões do Creator Dashboard devolve.
--
-- Ele roda a TAREFA DE VERDADE — o mesmo arquivo que a Open Cloud executa —
-- dentro de um Roblox falso, em modo `check` (que devolve antes de qualquer
-- escrita). O que está pinado:
--
--   1. O caminho pedido é resolvido e contado como remoção.
--   2. Caminho que JÁ NÃO EXISTE não é problema — a entrada fica inerte
--      depois da primeira publicação, igual às de LEGACY_NAMES.
--   3. CLASSE DIFERENTE da esperada vira PROBLEMA. É a trava contra erro de
--      digitação: um caminho que caia sobre um Script em vez de uma Folder
--      bloqueia a publicação inteira em vez de apagar a coisa errada.
--   4. NOME DUPLICADO no caminho vira problema, em vez de escolher um.
--   5. Problema > 0 impede a publicação (o `assert` do modo publish).
--
-- Roda sem Roblox e sem rede. Chamado por tools/test_publish.py, que
-- injeta o corpo da tarefa (o sandbox do luau não tem `io`).

local checados = 0
local function conferir(valor, mensagem)
	assert(valor, mensagem)
	checados += 1
end

-- ============================================
-- Roblox falso
-- ============================================

local function novaInstancia(classe, nome, pai)
	local self
	self = {
		ClassName = classe,
		Name = nome,
		Parent = nil,
		Source = "",
		_filhos = {},
		GetChildren = function(este)
			local copia = {}
			for _, f in este._filhos do
				table.insert(copia, f)
			end
			return copia
		end,
		GetDescendants = function(este)
			local todos = {}
			local function desce(no)
				for _, f in no._filhos do
					table.insert(todos, f)
					desce(f)
				end
			end
			desce(este)
			return todos
		end,
		IsA = function(este, classe2)
			return este.ClassName == classe2
		end,
	}
	if pai then
		self.Parent = pai
		table.insert(pai._filhos, self)
	end
	return self
end

-- Monta uma place falsa com o mínimo que a tarefa toca, mais o que o teste
-- do caso quiser. `adonis` diz o que existe em ServerScriptService com o
-- nome Adonis_Loader: "pasta", "script", "duplicado" ou nil.
local function novaPlace(adonis)
	local jogo = novaInstancia("DataModel", "Game")
	jogo.GameId = 7188115274
	jogo.PlaceId = 133619220682618

	local sss = novaInstancia("ServerScriptService", "ServerScriptService", jogo)
	-- Um script que o pacote reivindica, para a tarefa ter o que comparar.
	local existente = novaInstancia("Script", "AdminSystemServer", sss)
	existente.Source = "-- igual"

	if adonis == "pasta" then
		local pasta = novaInstancia("Folder", "Adonis_Loader", sss)
		local loader = novaInstancia("Folder", "Loader", pasta)
		novaInstancia("Script", "Loader", loader)
		local config = novaInstancia("Folder", "Config", pasta)
		novaInstancia("ModuleScript", "General", config)
	elseif adonis == "script" then
		novaInstancia("Script", "Adonis_Loader", sss)
	elseif adonis == "duplicado" then
		novaInstancia("Folder", "Adonis_Loader", sss)
		novaInstancia("Folder", "Adonis_Loader", sss)
	end

	local servicos = {
		SerializationService = {
			DeserializeInstancesAsync = function()
				-- Pacote com UM script, de caminho já existente, para que a
				-- tarefa não precise planejar pasta nenhuma.
				local raiz = novaInstancia("Folder", "RetroVerseCodePayload")
				local c = novaInstancia("Folder", "ServerScriptService", raiz)
				local s = novaInstancia("Script", "AdminSystemServer", c)
				s.Source = "-- igual"
				return { raiz }
			end,
		},
		AssetService = {
			SavePlaceAsync = function() end,
		},
	}
	jogo.GetService = function(_, nome)
		return servicos[nome]
	end
	return jogo
end

-- ============================================
-- Roda a tarefa de verdade, em modo check
-- ============================================

-- O sandbox do `luau` não tem `io`, então o corpo da tarefa é injetado por
-- tools/test_publish.py, mesmo padrão de tools/test_tutorial.py.
local CORPO = ...
assert(type(CORPO) == "string" and #CORPO > 0, "o corpo da tarefa não chegou")

local function rodarCheck(jogo)
	-- Mesmo cabeçalho que tools/run_code_publish.py prepende.
	local fonte = table.concat({
		'local RETROVERSE_MODE = "check"',
		'local EXPECTED_UNIVERSE_ID = "7188115274"',
		'local EXPECTED_PLACE_ID = "133619220682618"',
		CORPO,
	}, "\n")

	local saida = {}
	local ambiente = setmetatable({
		game = jogo,
		print = function(...)
			local partes = {}
			for i = 1, select("#", ...) do
				table.insert(partes, tostring((select(i, ...))))
			end
			table.insert(saida, table.concat(partes, " "))
		end,
		Instance = {
			new = function(classe)
				return novaInstancia(classe, classe)
			end,
		},
	}, { __index = getfenv(0) })

	local chunk = assert(loadstring(fonte, "tarefa"))
	setfenv(chunk, ambiente)
	local resultados = table.pack(pcall(chunk, { BinaryInput = "falso" }))
	return {
		ok = resultados[1],
		valores = resultados,
		saida = saida,
		texto = table.concat(saida, "\n"),
	}
end

local function acha(texto, agulha)
	return string.find(texto, agulha, 1, true) ~= nil
end

-- ============================================
-- 1. A pasta existe: é contada como remoção
-- ============================================

local comPasta = rodarCheck(novaPlace("pasta"))
conferir(comPasta.ok, "a tarefa rodou: " .. tostring(comPasta.valores[2]))
conferir(acha(comPasta.texto, "SERÁ REMOVIDO"), "remoção é anunciada no log")
conferir(acha(comPasta.texto, "ServerScriptService > Adonis_Loader"), "o log diz o caminho")
conferir(acha(comPasta.texto, "1 removidos"), "o resumo conta a remoção")
conferir(acha(comPasta.texto, "0 problemas"), "remoção legítima não é problema")
-- 4 descendentes: Loader/, Loader/Loader, Config/, Config/General.
conferir(acha(comPasta.texto, "4 descendente"), "o log avisa quantos descendentes vão junto")
conferir(acha(comPasta.texto, "nenhuma alteração foi salva"), "modo check não escreve")

-- ============================================
-- 2. Já não existe: inerte, não problema
-- ============================================

local semPasta = rodarCheck(novaPlace(nil))
conferir(semPasta.ok, "a tarefa rodou sem a pasta")
conferir(acha(semPasta.texto, "já não existe no place"), "caminho ausente é dito no log")
conferir(acha(semPasta.texto, "0 removidos"), "nada a remover não conta remoção")
conferir(acha(semPasta.texto, "0 problemas"), "caminho ausente NÃO é problema")
conferir(not acha(semPasta.texto, "SERÁ REMOVIDO"), "nada é marcado para remoção")

-- ============================================
-- 3. Classe diferente: PROBLEMA (a trava)
-- ============================================
-- Se alguém escrever na lista um caminho que cai sobre um Script, a
-- publicação inteira tem de parar. Esta é a única defesa contra um erro de
-- digitação apagar a coisa errada de uma place de produção.

local classeErrada = rodarCheck(novaPlace("script"))
conferir(classeErrada.ok, "a tarefa rodou com a classe errada")
conferir(acha(classeErrada.texto, "a lista de remoção espera Folder"), "classe divergente é explicada")
conferir(acha(classeErrada.texto, "no place é Script"), "o log diz a classe encontrada")
conferir(not acha(classeErrada.texto, "SERÁ REMOVIDO"), "classe errada NÃO é marcada para remoção")
conferir(acha(classeErrada.texto, "1 problemas"), "classe errada conta como problema")

-- ============================================
-- 4. Nome duplicado: problema, não escolha
-- ============================================

local duplicado = rodarCheck(novaPlace("duplicado"))
conferir(duplicado.ok, "a tarefa rodou com nome duplicado")
conferir(acha(duplicado.texto, "objetos chamados Adonis_Loader"), "duplicidade é explicada")
conferir(not acha(duplicado.texto, "SERÁ REMOVIDO"), "duplicidade NÃO escolhe um para remover")
conferir(acha(duplicado.texto, "1 problemas"), "duplicidade conta como problema")

-- ============================================
-- 5. Problema bloqueia a publicação
-- ============================================
-- Em modo check a tarefa devolve antes do assert. Aqui se confere que o
-- assert existe e cita os problemas — é ele que impede que uma classe
-- divergente siga para a escrita.

conferir(
	acha(CORPO, "problema(s) impedem a publicação; nada foi alterado"),
	"a tarefa tem assert que bloqueia a publicação quando há problema"
)
conferir(
	acha(CORPO, "#changes == 0 and #creations == 0 and #renames == 0 and #removals == 0"),
	"uma publicação que SÓ remove não pode sair como \"nada mudou\""
)
conferir(acha(CORPO, "previous.instance.Parent = previous.parent"), "o rollback devolve o pai do que foi removido")
-- A ordem importa: remover por último deixa o rollback rodar com tudo no
-- lugar se uma escrita anterior falhar.
local posRemocao = string.find(CORPO, "removal.instance.Parent = nil", 1, true)
local posSalvar = string.find(CORPO, "SavePlaceAsync({ SaveWithoutPublish = false })", 1, true)
local posCriar = string.find(CORPO, "novo.Parent = creation.parent", 1, true)
conferir(posRemocao ~= nil and posSalvar ~= nil and posCriar ~= nil, "achei os três pontos de escrita")
conferir(posCriar < posRemocao, "a remoção acontece DEPOIS das criações")
conferir(posRemocao < posSalvar, "a remoção acontece ANTES do salvamento")

print(`publish_removal: {checados} verificações passaram`)
