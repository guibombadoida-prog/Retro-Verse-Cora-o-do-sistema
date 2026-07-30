-- ============================================
-- BOSS NO-PVP PROTECTION V1 — JOGADOR NUNCA DANIFICA JOGADOR
-- Coloque em ServerScriptService (PLACE DO CHEFÃO)
-- Nome: "Boss_NoPvpProtection"
-- SCRIPT NOVO — não substitui nada
-- SUBSTITUI, NESTA PLACE: o TeamDamageProtection (não instale os dois)
-- ============================================
-- REGRA 1 das Diretrizes: na place do chefe existe só Jogador vs Boss.
-- Dano jogador→jogador é sempre bloqueado, não importa o time.
--
-- É a especialização do TeamDamageProtection: aquele bloqueia dano entre
-- MESMO TIME; aqui todos os jogadores estão do mesmo lado, então o
-- bloqueio é entre QUALQUER par de jogadores.
--
-- ⚠️ NÃO INSTALE O TeamDamageProtection NESTA PLACE junto com este script.
--    Os dois definem _G.CanDamagePlayer, e o último a carregar ganharia —
--    ordem de carga no ServerScriptService não é garantida, então o
--    resultado seria diferente a cada teste. Este substitui aquele aqui.
--
-- O QUE PASSA:
--   • dano do Boss → Jogador   (o chefe precisa poder matar)
--   • dano do Jogador → Boss   (a luta precisa acontecer)
-- O QUE É ANULADO, em silêncio:
--   • dano Jogador → Jogador   (sem matar a Tool, só anulando o dano)
--
-- "Em silêncio" é intencional e vem do TeamDamageProtection: a Tool
-- continua funcionando normalmente, dispara animação e efeito, só não
-- tira vida. Quebrar a Tool no meio de um golpe deixaria o jogador
-- travado sem entender.
--
-- COMO O DANO É DETECTADO: monitor de HealthChanged + tag LastAttacker,
-- exatamente o padrão do TeamDamageProtection_V4. É o que permite
-- funcionar com QUALQUER Tool, inclusive gear de InsertService, sem
-- editar uma linha delas.
--
-- REUTILIZADO (nada criado do zero):
-- • protectHumanoid / LastAttacker / restauração de vida
--   ................................. TeamDamageProtection_V4
-- • createBlockEffect (aviso visual) . TeamDamageProtection_V4
-- • Parent = nil no lugar de :Destroy() regra do projeto
-- ============================================

local Players = game:GetService("Players")

local CONFIG = {
	-- Quanto tempo a marca de "quem bateu por último" vale. Igual ao do
	-- TeamDamageProtection: depois disso o dano é considerado de outra
	-- origem (queda, ambiente) e não é restaurado.
	JANELA_ATAQUE = 5,
}

-- =====================================
-- EFEITO VISUAL DE BLOQUEIO
-- =====================================
-- Mesmo efeito do TeamDamageProtection, para o jogador entender que o
-- dano foi anulado de propósito e não que a Tool falhou.

local function createBlockEffect(character)
	if not character then
		return
	end
	local raiz = character:FindFirstChild("HumanoidRootPart")
	if not raiz then
		return
	end

	local existente = raiz:FindFirstChild("BossNoPvpBlock")
	if existente then
		return -- já tem um piscando, não empilha
	end

	local aviso = Instance.new("BillboardGui")
	aviso.Name = "BossNoPvpBlock"
	aviso.Size = UDim2.new(0, 140, 0, 34)
	aviso.StudsOffset = Vector3.new(0, 3, 0)
	aviso.AlwaysOnTop = true
	aviso.Parent = raiz

	local texto = Instance.new("TextLabel")
	texto.Size = UDim2.new(1, 0, 1, 0)
	texto.BackgroundTransparency = 1
	texto.Text = "🛡️ SEM PVP AQUI"
	texto.TextColor3 = Color3.fromRGB(0, 220, 255)
	texto.TextStrokeTransparency = 0
	texto.TextScaled = true
	texto.Font = Enum.Font.Arcade
	texto.Parent = aviso

	task.delay(1.2, function()
		aviso.Parent = nil -- regra do projeto: sem :Destroy()
	end)
end

-- =====================================
-- É JOGADOR?
-- =====================================
-- O chefe é um Model com Humanoid, igual a um personagem de jogador.
-- A única diferença confiável é ter um Player associado — por isso a
-- checagem é sempre por Players:GetPlayerFromCharacter, nunca por nome
-- ou por pasta.

local function playerDoPersonagem(character)
	if not character then
		return nil
	end
	return Players:GetPlayerFromCharacter(character)
end

-- =====================================
-- MONITOR DE VIDA
-- =====================================

local conexoes = {} -- [player] = RBXScriptConnection

local function protegerHumanoid(player, character)
	local humanoid = character:WaitForChild("Humanoid", 10)
	if not humanoid then
		return
	end

	-- Tag de quem bateu por último. O mesmo nome do
	-- TeamDamageProtection: outros sistemas (CharacterLevelServer,
	-- DamageAttribution) já leem "LastAttacker", então reaproveitar o
	-- nome mantém tudo funcionando nesta place.
	local tag = character:FindFirstChild("LastAttacker")
	if not tag then
		tag = Instance.new("ObjectValue")
		tag.Name = "LastAttacker"
		tag.Parent = character
	end

	local marcadoEm = 0
	tag.Changed:Connect(function()
		marcadoEm = os.clock()
	end)

	local vidaAnterior = humanoid.Health

	if conexoes[player] then
		pcall(function()
			conexoes[player]:Disconnect()
		end)
	end

	conexoes[player] = humanoid.HealthChanged:Connect(function(vida)
		-- Só queda de vida interessa. Subida é cura (ou a própria
		-- restauração daqui) e é ignorada automaticamente.
		if vida >= vidaAnterior then
			vidaAnterior = vida
			return
		end

		local dano = vidaAnterior - vida
		vidaAnterior = vida

		local atacante = tag.Value
		local recente = (os.clock() - marcadoEm) <= CONFIG.JANELA_ATAQUE

		-- Sem atacante marcado, ou marca velha: dano do chefe, de queda
		-- ou de ambiente. Passa.
		if not atacante or not recente then
			return
		end

		-- Só bloqueia se quem bateu é OUTRO JOGADOR.
		if atacante:IsA("Player") and atacante ~= player then
			humanoid.Health = math.min(humanoid.MaxHealth, vida + dano)
			vidaAnterior = humanoid.Health
			createBlockEffect(character)
			tag.Value = nil
		end
	end)
end

local function onCharacterAdded(player, character)
	task.spawn(protegerHumanoid, player, character)
end

local function onPlayerAdded(player)
	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(player, character)
	end)
	if player.Character then
		onCharacterAdded(player, player.Character)
	end
end

local function onPlayerRemoving(player)
	if conexoes[player] then
		pcall(function()
			conexoes[player]:Disconnect()
		end)
	end
	conexoes[player] = nil
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)

for _, player in ipairs(Players:GetPlayers()) do
	onPlayerAdded(player)
end

-- =====================================
-- API GLOBAL
-- =====================================
-- Mesmo contrato do TeamDamageProtection, de propósito: qualquer Tool ou
-- sistema que já consultava _G.CanDamagePlayer funciona aqui sem mudar
-- nada — só que a resposta para jogador→jogador é sempre `false`.

_G.CanDamagePlayer = function(atacante, vitima)
	if not atacante or not vitima then
		return false
	end
	-- REGRA 1: qualquer par de jogadores é bloqueado, inclusive ele mesmo
	if atacante:IsA("Player") and vitima:IsA("Player") then
		if vitima.Character then
			createBlockEffect(vitima.Character)
		end
		return false
	end
	return true
end

_G.CreateTeamBlockEffect = createBlockEffect

-- Nesta place não há times: todos estão do mesmo lado. Responder assim
-- evita que um sistema copiado da place principal (que consulta
-- _G.IsTeammate) quebre por a função não existir aqui.
if not _G.IsTeammate then
	_G.IsTeammate = function(a, b)
		return a ~= nil and b ~= nil
	end
end

_G.DebugNoPvp = function()
	print("\n========== DEBUG BOSS NO-PVP V1 ==========")
	local n = 0
	for player in pairs(conexoes) do
		n += 1
		print("  monitorando: " .. player.Name)
	end
	if n == 0 then
		print("  (ninguém sendo monitorado)")
	end
	print("  _G.CanDamagePlayer sempre nega jogador → jogador")
	print("=========================================\n")
end

print([[
╔════════════════════════════════════════════════════╗
║  🛡️ BOSS NO-PVP PROTECTION V1 CARREGADO            ║
╠════════════════════════════════════════════════════╣
║  SCRIPT NOVO (place do CHEFÃO)                     ║
║  ⚠️ NÃO instale o TeamDamageProtection nesta place ║
║     junto: os dois definem _G.CanDamagePlayer      ║
╠════════════════════════════════════════════════════╣
║  REGRA 1: só Jogador vs Boss                       ║
║  • Boss → Jogador ....... passa                    ║
║  • Jogador → Boss ....... passa                    ║
║  • Jogador → Jogador .... anulado em silêncio      ║
║  Funciona com qualquer Tool (inclusive gear de     ║
║  InsertService) — monitor de vida, não edita Tool  ║
╠════════════════════════════════════════════════════╣
║  DEBUG: _G.DebugNoPvp()                             ║
╚════════════════════════════════════════════════════╝
]])
