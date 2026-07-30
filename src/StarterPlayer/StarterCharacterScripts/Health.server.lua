-- ============================================
-- HEALTH V1 — BLOQUEIO DA REGENERAÇÃO PADRÃO DO ROBLOX
-- Coloque em StarterPlayer > StarterCharacterScripts
-- Nome do objeto no Studio: "Health"  (EXATAMENTE ISSO)
-- Tipo: Script  (NÃO LocalScript — ver aviso abaixo)
-- SCRIPT NOVO — não substitui nada
-- ============================================
-- COMO O BLOQUEIO FUNCIONA:
-- A regeneração automática do Roblox não vem do Humanoid — vem de um
-- Script chamado "Health" que o motor insere dentro do personagem a
-- cada spawn. O motor SÓ insere esse script se ainda não existir um
-- chamado "Health" no personagem. Ou seja: colocar um Script com esse
-- nome exato em StarterCharacterScripts faz o motor não inserir o
-- dele — o nosso ocupa a vaga.
--
-- ⚠️ POR ISSO O NOME NÃO PODE MUDAR. Se renomear pra
--    "HealthRegen", "Health_V1" ou qualquer outra coisa, o Roblox
--    insere o script padrão de volta e a cura automática volta junto.
--    O nome do ARQUIVO aqui é Health_V1.lua só por versionamento; o
--    nome do OBJETO no Studio tem que ser "Health".
--
-- ⚠️ TEM QUE SER UM Script, NÃO UM LocalScript. Dois motivos:
--    1. Vida é decisão de servidor (cliente curando a si mesmo é
--       exploit na hora);
--    2. O PassiveSystemServer V1 procura por
--       `regenScript:IsA("Script")` — e LocalScript NÃO passa nesse
--       teste (LocalScript não herda de Script no Roblox).
--
-- LIGAÇÃO COM AS PASSIVAS:
-- • O PassiveSystemServer V1 já liga/desliga este script pelo campo
--   `Disabled` sempre que a build muda:
--       regenScript.Disabled = effects.noRegen
--   Hoje quem ativa isso é CASCA DURA e VAMPÍRICO — as duas passivas
--   cujo malefício é justamente "sem regeneração natural".
-- • Além disso, este script LÊ `_G.PassiveSystem.getEffects()` a cada
--   tick. Isso é redundância proposital: se a build mudar sem que o
--   Disabled seja atualizado (troca de personagem, respawn no meio
--   da troca), a regeneração ainda respeita a passiva.
-- • Também já lê um campo `healthRegenMult` que AINDA NÃO EXISTE em
--   nenhuma passiva. É preparo: quando você quiser uma passiva de
--   "+X% regeneração", basta adicionar o campo no catálogo do
--   PassiveSystemServer — este script pega sozinho, sem edição.
--
-- DIFERENÇA PRA REGENERAÇÃO PADRÃO DO ROBLOX:
-- • Roblox: 1% da vida máxima por segundo, SEMPRE, inclusive levando
--   dano — o que empata luta e premia quem foge.
-- • Aqui: mesma taxa, mas só FORA DE COMBATE (padrão: 8s sem tomar
--   dano). Tudo configurável no CONFIG abaixo.
--
-- REUTILIZAÇÃO:
-- • Guarda de morte e leitura de Humanoid ..... GameManager V9 / AntiToolSystem V2
-- • Padrão de _G com espera por timeout ....... geral do projeto
-- • Nenhum :Destroy(), nenhum math.random ..... regra do projeto
-- ============================================

local Players = game:GetService("Players")

local character = script.Parent
local humanoid = character:WaitForChild("Humanoid", 10)

if not humanoid then
	warn("[HEALTH V1] Humanoid não encontrado — regeneração não iniciada")
	return
end

local player = Players:GetPlayerFromCharacter(character)

-- =====================================
-- CONFIGURAÇÃO
-- =====================================

local CONFIG = {
	-- false = ninguém regenera nunca (bloqueio total, sem substituto)
	REGEN_ENABLED = true,

	-- Fração da vida MÁXIMA curada por tick.
	-- 0.01 + TICK 1 = mesma taxa do Roblox (1%/s).
	REGEN_PERCENT = 0.01,
	TICK = 1,

	-- Segundos sem TOMAR dano antes da regeneração voltar.
	-- Coloque 0 pra regenerar mesmo em combate (comportamento Roblox).
	COMBAT_DELAY = 8,

	-- Cura mínima por tick (evita regen imperceptível em personagem
	-- de vida baixa)
	MIN_REGEN = 1,
}

-- =====================================
-- NEUTRALIZAR UM "Health" PADRÃO CONCORRENTE
-- =====================================
-- Cenário raro: se por algum motivo o motor (ou outro script) inserir
-- um segundo "Health" no personagem, ficariam DOIS objetos com o
-- mesmo nome. Aí `character:FindFirstChild("Health")` — que é o que o
-- PassiveSystemServer usa — poderia pegar o errado, e a passiva
-- Casca Dura desligaria o script que não é o nosso.
--
-- Solução: renomear e desligar o intruso (nunca :Destroy(), regra do
-- projeto). Depois disso, FindFirstChild("Health") sempre acha este.

local function neutralizeForeignHealthScripts()
	for _, child in ipairs(character:GetChildren()) do
		if child ~= script and child.Name == "Health" and child:IsA("BaseScript") then
			child.Disabled = true
			child.Name = "Health_Padrao_Desativado"
			print("[HEALTH V1] Script de regeneração padrão do Roblox neutralizado")
		end
	end
end

neutralizeForeignHealthScripts()

-- Se aparecer depois do spawn, pega também
character.ChildAdded:Connect(function(child)
	if child ~= script and child.Name == "Health" and child:IsA("BaseScript") then
		task.wait() -- deixa o objeto terminar de ser criado
		if child.Parent then
			child.Disabled = true
			child.Name = "Health_Padrao_Desativado"
			print("[HEALTH V1] Script de regeneração padrão neutralizado (pós-spawn)")
		end
	end
end)

-- =====================================
-- DETECÇÃO DE COMBATE
-- =====================================

local lastDamageTime = 0
local lastHealth = humanoid.Health

humanoid.HealthChanged:Connect(function(health)
	-- Só QUEDA de vida conta como combate.
	-- Subida pode ser: esta própria regeneração, o lifesteal do
	-- Vampírico, ou a devolução de dano da Couraça (o
	-- PassiveSystemServer corrige o dano SUBINDO a vida de volta).
	-- Nenhuma dessas deve reiniciar o timer de combate.
	if health < lastHealth then
		lastDamageTime = os.clock()
	end
	lastHealth = health
end)

-- =====================================
-- LEITURA DAS PASSIVAS
-- =====================================

local function getPassiveEffects()
	if not player or not _G.PassiveSystem or not _G.PassiveSystem.getEffects then
		return nil
	end

	local ok, effects = pcall(_G.PassiveSystem.getEffects, player)
	if ok and type(effects) == "table" then
		return effects
	end
	return nil
end

-- =====================================
-- LOOP DE REGENERAÇÃO
-- =====================================
-- Observação: quando o PassiveSystemServer faz `Disabled = true`
-- (Casca Dura / Vampírico), o motor PARA este script inteiro — o loop
-- nem chega a rodar. Quando volta pra false, o script reinicia do
-- topo e reconecta tudo. É por isso que todo o estado fica aqui em
-- cima, sem depender de nada persistido.

if not CONFIG.REGEN_ENABLED then
	print("[HEALTH V1] Regeneração DESLIGADA por configuração — só cura por passiva/item")
	return
end

while true do
	task.wait(CONFIG.TICK)

	-- Morto não regenera (deixa o respawn padrão agir)
	if humanoid.Health <= 0 then
		lastDamageTime = os.clock()
	elseif humanoid.Health < humanoid.MaxHealth then
		local effects = getPassiveEffects()

		-- Passiva que proíbe regeneração natural (Casca Dura / Vampírico)
		local blocked = effects and effects.noRegen or false

		-- Campo preparado pro futuro: hoje nenhuma passiva define
		-- healthRegenMult, então isso é sempre 1
		local multiplier = 1
		if effects and type(effects.healthRegenMult) == "number" then
			multiplier = math.max(0, effects.healthRegenMult)
		end

		local outOfCombat = (os.clock() - lastDamageTime) >= CONFIG.COMBAT_DELAY

		if not blocked and multiplier > 0 and outOfCombat then
			local amount = math.max(
				CONFIG.MIN_REGEN,
				humanoid.MaxHealth * CONFIG.REGEN_PERCENT * multiplier
			)

			local newHealth = math.min(humanoid.MaxHealth, humanoid.Health + amount)
			humanoid.Health = newHealth
			lastHealth = newHealth -- não deixa a própria cura virar "dano"
		end
	end
end
