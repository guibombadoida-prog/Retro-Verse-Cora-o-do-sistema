-- ============================================
-- PROTEÇÃO DE DANO ENTRE MEMBROS DO TIME V4
-- (V4) ALTERAÇÕES: wait()/spawn() -> task.wait()/task.spawn() (conformidade)
-- Coloque em ServerScriptService
-- Nome: "TeamDamageProtection"
-- SUBSTITUI: TeamDamageProtection V2
-- ============================================
-- CORREÇÕES V3.1:
-- • Removido uso de getconnections (função não padrão)
-- • Implementado sistema de rastreamento de conexões
-- • Adicionada limpeza automática de conexões
-- • Memory leak prevenido
-- ============================================
-- CORREÇÕES V3:
-- • Sistema funciona SEM TAGs (removidas)
-- • Proteção direta via verificação de time
-- • Efeitos visuais sem depender de TAGs
-- • Performance otimizada
-- ============================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

-- Aguardar sistemas carregarem
repeat
	task.wait()
until _G.IsTeammate
print("[TEAM PROTECTION V3] Sistema de times detectado")

-- =====================================
-- CONFIGURAÇÃO
-- =====================================

local CONFIG = {
	DAMAGE_COOLDOWN = 0.1,
	EFFECT_DURATION = 0.5,
	SOUND_VOLUME = 0.3,
}

-- Cache de últimos danos processados
local recentDamageBlocks = {}

-- =====================================
-- SONS
-- =====================================

local sounds = {
	block = "rbxassetid://130113322",
}

local function playSound(soundId, parent)
	pcall(function()
		local sound = Instance.new("Sound")
		sound.SoundId = soundId
		sound.Volume = CONFIG.SOUND_VOLUME
		sound.Parent = parent or SoundService
		sound:Play()
		game:GetService("Debris"):AddItem(sound, 1)
	end)
end

-- =====================================
-- FUNÇÕES DE EFEITOS VISUAIS
-- =====================================

local function createBlockEffect(character)
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then
		return
	end

	-- Criar partícula de bloqueio
	local attachment = Instance.new("Attachment")
	attachment.Parent = hrp

	local particle = Instance.new("ParticleEmitter")
	particle.Texture = "rbxasset://textures/particles/smoke_main.dds"
	particle.Color = ColorSequence.new(Color3.fromRGB(0, 255, 255))
	particle.Size = NumberSequence.new(2, 0)
	particle.Transparency = NumberSequence.new(0.3, 1)
	particle.Lifetime = NumberRange.new(0.5)
	particle.Rate = 50
	particle.Speed = NumberRange.new(5)
	particle.SpreadAngle = Vector2.new(180, 180)
	particle.Parent = attachment

	particle.Enabled = true
	task.wait(0.2)
	particle.Enabled = false

	game:GetService("Debris"):AddItem(attachment, 1)

	-- Som de bloqueio
	playSound(sounds.block, hrp)
end

-- =====================================
-- SISTEMA DE PROTEÇÃO POR TOOL
-- =====================================

-- Tabela para rastrear conexões de ferramentas
local toolConnections = {}

local function setupToolProtection(tool, wielder)
	if not tool:IsA("Tool") then
		return
	end
	if not wielder then
		return
	end

	local handle = tool:FindFirstChild("Handle")
	if not handle then
		return
	end

	-- Desconectar listener antigo se existir
	local toolId = tostring(tool:GetFullName())
	if toolConnections[toolId] then
		pcall(function()
			toolConnections[toolId]:Disconnect()
		end)
		toolConnections[toolId] = nil
	end

	-- Criar novo listener
	local connection = handle.Touched:Connect(function(hit)
		if not hit or not hit.Parent then
			return
		end

		local hitHumanoid = hit.Parent:FindFirstChild("Humanoid")
		if not hitHumanoid then
			return
		end

		-- Obter jogadores
		local attacker = Players:GetPlayerFromCharacter(wielder.Parent)
		local victim = Players:GetPlayerFromCharacter(hit.Parent)

		if not attacker or not victim then
			return
		end
		if attacker == victim then
			return
		end

		-- Verificar cooldown
		local damageKey = attacker.UserId .. "_" .. victim.UserId
		if recentDamageBlocks[damageKey] then
			if tick() - recentDamageBlocks[damageKey] < CONFIG.DAMAGE_COOLDOWN then
				return
			end
		end

		-- VERIFICAR SE SÃO DO MESMO TIME (SEM TAG)
		if _G.IsTeammate(attacker, victim) then
			-- Registrar bloqueio
			recentDamageBlocks[damageKey] = tick()

			print(
				string.format(
					"[TEAM PROTECTION V3] Dano bloqueado: %s -> %s (mesmo time)",
					attacker.Name,
					victim.Name
				)
			)

			-- Efeito visual
			createBlockEffect(victim.Character)

			-- Desconectar temporariamente para evitar dano
			handle.CanCollide = false
			handle.CanTouch = false
			task.wait(0.1)
			handle.CanCollide = true
			handle.CanTouch = true

			return
		end
	end)

	-- Armazenar conexão
	toolConnections[toolId] = connection

	-- Limpar quando ferramenta for destruída
	tool.AncestryChanged:Connect(function()
		if not tool.Parent then
			if toolConnections[toolId] then
				pcall(function()
					toolConnections[toolId]:Disconnect()
				end)
				toolConnections[toolId] = nil
			end
		end
	end)
end

-- =====================================
-- MONITORAMENTO DE FERRAMENTAS
-- =====================================

local function onCharacterAdded(character)
	local player = Players:GetPlayerFromCharacter(character)
	if not player then
		return
	end

	-- Monitorar ferramentas adicionadas ao personagem
	character.ChildAdded:Connect(function(child)
		if child:IsA("Tool") then
			task.wait(0.1)
			setupToolProtection(child, character)
		end
	end)

	-- Configurar ferramentas já existentes
	for _, child in pairs(character:GetChildren()) do
		if child:IsA("Tool") then
			setupToolProtection(child, character)
		end
	end
end

-- Conectar eventos
Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(onCharacterAdded)

	if player.Character then
		onCharacterAdded(player.Character)
	end

	-- Monitorar backpack
	local backpack = player:WaitForChild("Backpack")
	backpack.ChildAdded:Connect(function(tool)
		if tool:IsA("Tool") then
			tool.Equipped:Connect(function()
				setupToolProtection(tool, player.Character)
			end)
		end
	end)
end)

-- Limpar conexões quando jogador sair
Players.PlayerRemoving:Connect(function(player)
	-- Limpar todas as conexões de ferramentas do jogador
	for toolId, connection in pairs(toolConnections) do
		if toolId:find(player.Name) then
			pcall(function()
				connection:Disconnect()
			end)
			toolConnections[toolId] = nil
		end
	end
end)

-- =====================================
-- PROTEÇÃO ADICIONAL VIA HUMANOID
-- =====================================

local function protectHumanoid(humanoid, character)
	local player = Players:GetPlayerFromCharacter(character)
	if not player then
		return
	end

	-- Criar tag para último atacante
	local lastAttackerTag = character:FindFirstChild("LastAttacker") or Instance.new("ObjectValue")
	lastAttackerTag.Name = "LastAttacker"
	lastAttackerTag.Parent = character

	-- Registrar última vida
	local lastHealth = humanoid.Health

	humanoid.HealthChanged:Connect(function(health)
		if health < lastHealth then
			local attacker = lastAttackerTag.Value
			if attacker and attacker:IsA("Player") then
				-- Verificar se é aliado (SEM TAG)
				if _G.IsTeammate(attacker, player) then
					-- Restaurar vida
					local damageAmount = lastHealth - health
					humanoid.Health = math.min(humanoid.MaxHealth, health + damageAmount)

					print(
						string.format(
							"[TEAM PROTECTION V3] Dano de aliado restaurado: %s -> %s",
							attacker.Name,
							player.Name
						)
					)

					-- Efeito visual
					createBlockEffect(character)
				end
			end
		end
		lastHealth = health
	end)
end

-- Aplicar proteção a todos os personagens
Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function(character)
		local humanoid = character:WaitForChild("Humanoid")
		protectHumanoid(humanoid, character)
	end)
end)

-- =====================================
-- API PARA FERRAMENTAS PERSONALIZADAS
-- =====================================

-- Função que ferramentas podem chamar antes de causar dano
_G.CanDamagePlayer = function(attacker, victim)
	if not attacker or not victim then
		return false
	end
	if attacker == victim then
		return false
	end

	-- Verificar se são do mesmo time (SEM TAG)
	if _G.IsTeammate(attacker, victim) then
		-- Criar efeito de bloqueio
		if victim.Character then
			createBlockEffect(victim.Character)
		end

		return false
	end

	return true
end

-- Exportar função de efeito
_G.CreateTeamBlockEffect = createBlockEffect

-- =====================================
-- LIMPEZA PERIÓDICA DO CACHE
-- =====================================

task.spawn(function()
	while true do
		task.wait(5)

		local currentTime = tick()
		for key, timestamp in pairs(recentDamageBlocks) do
			if currentTime - timestamp > 1 then
				recentDamageBlocks[key] = nil
			end
		end
	end
end)

print([[
╔════════════════════════════════════════════════════╗
║  ✅ PROTEÇÃO DE DANO ENTRE TIMES V3.1 ATIVADA     ║
╠════════════════════════════════════════════════════╣
║  SUBSTITUI: TeamDamageProtection V2               ║
╠════════════════════════════════════════════════════╣
║  CORREÇÕES V3.1:                                   ║
║  • Removido uso de getconnections ✅              ║
║  • Sistema de rastreamento de conexões            ║
║  • Limpeza automática implementada                ║
║  • Memory leak prevenido                          ║
╠════════════════════════════════════════════════════╣
║  CORREÇÕES V3:                                     ║
║  • Funciona SEM sistema de TAG                    ║
║  • Verificação direta de time                     ║
║  • Efeitos visuais independentes                  ║
║  • Cache de danos para performance                ║
║  • Sons de bloqueio integrados                    ║
╠════════════════════════════════════════════════════╣
║  API Exportada:                                    ║
║  • _G.CanDamagePlayer(attacker, victim)           ║
║  • _G.CreateTeamBlockEffect(character)            ║
╠════════════════════════════════════════════════════╣
║  FEATURES:                                         ║
║  • Proteção automática de ferramentas             ║
║  • Proteção de dano direto ao Humanoid            ║
║  • Sistema sem Raycast (otimizado)                ║
║  • Efeitos visuais de bloqueio                    ║
║  • Sistema de cooldown para evitar spam           ║
╚════════════════════════════════════════════════════╝
]])
