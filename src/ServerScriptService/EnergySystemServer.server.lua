-- ============================================
-- ENERGY SYSTEM SERVER V1 — ENERGIA POR USO DE TOOL
-- Coloque em ServerScriptService
-- Nome: "EnergySystemServer"
-- DEPENDE DE: DataManager V7, CharacterLevelServer V1
-- SCRIPT NOVO — não substitui nada
-- ============================================
-- FUNÇÃO:
-- • Cada ativação de Tool consome ENERGIA. Zerou, a Tool trava até
--   regenerar. É o custo que faz as passivas terem preço — sem isso
--   toda passiva vira só bônus.
-- • Energia MÁXIMA e REGENERAÇÃO vêm do nível do personagem
--   equipado (_G.CharacterLevel.getEnergyMax / getEnergyRegen).
--   É assim que subir de nível dá vantagem SEM dar dano bruto.
--
-- COMO A TOOL TRAVA (detalhe importante):
-- • Não dá pra "cancelar" um Tool.Activated que já disparou. Então o
--   bloqueio é PREVENTIVO: quando a energia fica abaixo do custo, a
--   Tool recebe Enabled = false e o Activated nem chega a rodar.
-- • O debounce oficial das Tools do projeto também mexe em Enabled
--   (diretriz de Tools, seção 8). Por isso este script SEGURA o
--   Enabled via GetPropertyChangedSignal: se a Tool tentar se
--   reabilitar enquanto o jogador está sem energia, ele força de
--   volta pra false. Quando a energia volta, ele solta.
-- • ⚠️ Consequência conhecida: enquanto o jogador está sem energia,
--   o cooldown próprio da Tool fica "mascarado". Ao liberar, a Tool
--   volta habilitada mesmo que o cooldown dela ainda estivesse
--   correndo. Na prática não abre exploit (a energia é o gargalo,
--   e ela é mais lenta que o cooldown), mas está documentado.
--
-- CUSTO POR TOOL:
-- • Padrão: CONFIG.DEFAULT_COST
-- • Por Tool: coloque um NumberValue chamado "EnergyCost" dentro da
--   Tool (funciona pra Tools carregadas por InsertService também,
--   sem precisar editar script nenhum)
-- • Por código: _G.EnergySystem.setToolCost("NomeDaTool", 30)
--
-- REUTILIZAÇÃO (nada criado do zero):
-- • Varredura de Backpack + Character e reação a ChildAdded ->
--   padrão do RetroHotbarClient V2 (collectTools/refresh)
-- • Guarda de morte -> compatível com AntiToolSystem V2
-- • ensureRemote / banner / _G API -> padrão geral do projeto
-- ============================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

repeat
	task.wait()
until _G.PlayerDataManager and _G.CharacterLevel

-- =====================================
-- CONFIGURAÇÃO
-- =====================================

local CONFIG = {
	DEFAULT_COST = 15, -- custo padrão por ativação
	MIN_COST = 1,
	MAX_COST = 500,

	TICK = 0.25, -- intervalo do loop de regeneração
	REFILL_ON_SPAWN = true, -- nasce com energia cheia

	-- Bateria Fria e afins: velocidade abaixo disso conta como "parado"
	IDLE_SPEED_THRESHOLD = 2,
}

-- =====================================
-- REMOTES
-- =====================================

local remotes = ReplicatedStorage:FindFirstChild("Remotes")
if not remotes then
	remotes = Instance.new("Folder")
	remotes.Name = "Remotes"
	remotes.Parent = ReplicatedStorage
end

local function ensureRemote(name, className)
	local remote = remotes:FindFirstChild(name)
	if remote and not remote:IsA(className) then
		remote.Parent = nil -- regra do projeto: sem :Destroy()
		remote = nil
	end
	if not remote then
		remote = Instance.new(className)
		remote.Name = name
		remote.Parent = remotes
	end
	return remote
end

local energyUpdate = ensureRemote("EnergyUpdate", "RemoteEvent") -- server -> client
local energyDepleted = ensureRemote("EnergyDepleted", "RemoteEvent") -- aviso de "sem energia"

-- =====================================
-- ESTADO
-- =====================================

-- [player] = {
--   current, max, regen,
--   modifiers = {costMult, regenMult, maxMult, idleOnlyRegen, idleBonus},
--   heldTools = { [tool] = connection },
--   toolConnections = { [tool] = connection },
-- }
local energyState = {}
local customToolCost = {} -- [toolName] = custo

local DEFAULT_MODIFIERS = {
	costMult = 1,
	regenMult = 1,
	maxMult = 1,
	idleOnlyRegen = false, -- Bateria Fria: só regenera parado
	idleBonus = 0, -- bônus de regen quando parado
}

local function copyModifiers(source)
	local result = {}
	for key, value in pairs(DEFAULT_MODIFIERS) do
		result[key] = value
	end
	if type(source) == "table" then
		for key, value in pairs(source) do
			if result[key] ~= nil then
				result[key] = value
			end
		end
	end
	return result
end

local function getState(player)
	return energyState[player]
end

-- =====================================
-- CÁLCULO DE MÁXIMO / REGEN (vem do nível)
-- =====================================

local function recalcLimits(player)
	local state = energyState[player]
	if not state then
		return
	end

	local data = _G.PlayerDataManager.getPlayerData(player)
	local equipped = data and data.equippedCharacter

	local level = 1
	if equipped then
		local progress = _G.PlayerDataManager.getCharacterProgress(player, equipped)
		if progress then
			level = progress.level
		end
	end

	local mods = state.modifiers
	state.max = math.max(1, math.floor(_G.CharacterLevel.getEnergyMax(level) * mods.maxMult))
	state.regen = _G.CharacterLevel.getEnergyRegen(level) * mods.regenMult
	state.level = level

	if state.current > state.max then
		state.current = state.max
	end
end

local function pushUpdate(player)
	local state = energyState[player]
	if not state then
		return
	end
	energyUpdate:FireClient(player, {
		current = math.floor(state.current),
		max = state.max,
		regen = state.regen,
		level = state.level,
	})
end

-- =====================================
-- TRAVA DE TOOL POR FALTA DE ENERGIA
-- =====================================

local function getToolCost(player, tool)
	local cost = CONFIG.DEFAULT_COST

	-- 1) NumberValue "EnergyCost" dentro da Tool (config sem código)
	local valueObject = tool:FindFirstChild("EnergyCost")
	if valueObject and valueObject:IsA("NumberValue") and valueObject.Value > 0 then
		cost = valueObject.Value
	elseif customToolCost[tool.Name] then
		-- 2) custo registrado por código
		cost = customToolCost[tool.Name]
	end

	local state = energyState[player]
	if state then
		cost = cost * state.modifiers.costMult
	end

	return math.clamp(math.floor(cost + 0.5), CONFIG.MIN_COST, CONFIG.MAX_COST)
end

local function releaseTool(player, tool)
	local state = energyState[player]
	if not state then
		return
	end

	local held = state.heldTools[tool]
	if not held then
		return
	end

	pcall(function()
		held:Disconnect()
	end)
	state.heldTools[tool] = nil

	if tool.Parent then
		tool.Enabled = true
	end
end

local function holdTool(player, tool)
	local state = energyState[player]
	if not state or state.heldTools[tool] then
		return
	end

	tool.Enabled = false

	-- Se a Tool tentar se reabilitar sozinha (debounce próprio dela),
	-- força de volta enquanto a energia não voltar
	state.heldTools[tool] = tool:GetPropertyChangedSignal("Enabled"):Connect(function()
		if tool.Enabled and energyState[player] and energyState[player].heldTools[tool] then
			tool.Enabled = false
		end
	end)
end

local function collectTools(player)
	local tools = {}

	local backpack = player:FindFirstChildOfClass("Backpack")
	if backpack then
		for _, item in ipairs(backpack:GetChildren()) do
			if item:IsA("Tool") then
				table.insert(tools, item)
			end
		end
	end

	local character = player.Character
	if character then
		for _, item in ipairs(character:GetChildren()) do
			if item:IsA("Tool") then
				table.insert(tools, item)
			end
		end
	end

	return tools
end

local function refreshToolGates(player)
	local state = energyState[player]
	if not state then
		return
	end

	for _, tool in ipairs(collectTools(player)) do
		local cost = getToolCost(player, tool)
		if state.current < cost then
			holdTool(player, tool)
		else
			releaseTool(player, tool)
		end
	end
end

-- =====================================
-- CONSUMO
-- =====================================

local function consume(player, amount, reason)
	local state = energyState[player]
	if not state then
		return false
	end

	amount = math.max(0, tonumber(amount) or 0)
	if amount <= 0 then
		return true
	end

	if state.current < amount then
		return false
	end

	state.current = state.current - amount
	pushUpdate(player)
	refreshToolGates(player)

	if state.current <= 0 then
		energyDepleted:FireClient(player, reason or "tool")
	end

	return true
end

local function restore(player, amount)
	local state = energyState[player]
	if not state then
		return
	end

	state.current = math.clamp(state.current + (tonumber(amount) or 0), 0, state.max)
	pushUpdate(player)
	refreshToolGates(player)
end

-- =====================================
-- HOOK DAS TOOLS
-- =====================================

local function hookTool(player, tool)
	local state = energyState[player]
	if not state or state.toolConnections[tool] then
		return
	end

	state.toolConnections[tool] = tool.Activated:Connect(function()
		local currentState = energyState[player]
		if not currentState then
			return
		end

		-- Guarda de morte (mesma regra do AntiToolSystem V2)
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not humanoid or humanoid.Health <= 0 then
			return
		end

		local cost = getToolCost(player, tool)
		if not consume(player, cost, tool.Name) then
			holdTool(player, tool)
		end
	end)

	-- Já nasce travada se não houver energia
	if state.current < getToolCost(player, tool) then
		holdTool(player, tool)
	end
end

local function unhookTool(player, tool)
	local state = energyState[player]
	if not state then
		return
	end

	local connection = state.toolConnections[tool]
	if connection then
		pcall(function()
			connection:Disconnect()
		end)
		state.toolConnections[tool] = nil
	end

	local held = state.heldTools[tool]
	if held then
		pcall(function()
			held:Disconnect()
		end)
		state.heldTools[tool] = nil
	end
end

local function watchContainer(player, container)
	if not container then
		return
	end

	for _, item in ipairs(container:GetChildren()) do
		if item:IsA("Tool") then
			hookTool(player, item)
		end
	end

	container.ChildAdded:Connect(function(item)
		if item:IsA("Tool") then
			hookTool(player, item)
		end
	end)
end

-- =====================================
-- LOOP DE REGENERAÇÃO
-- =====================================

local function isIdle(player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return true
	end
	return root.AssemblyLinearVelocity.Magnitude < CONFIG.IDLE_SPEED_THRESHOLD
end

task.spawn(function()
	while true do
		task.wait(CONFIG.TICK)

		for _, player in ipairs(Players:GetPlayers()) do
			local state = energyState[player]
			if state and state.current < state.max then
				local character = player.Character
				local humanoid = character and character:FindFirstChildOfClass("Humanoid")

				-- Morto não regenera
				if humanoid and humanoid.Health > 0 then
					local mods = state.modifiers
					local idle = isIdle(player)
					local regen = state.regen

					if mods.idleOnlyRegen and not idle then
						regen = 0
					elseif idle then
						regen = regen + mods.idleBonus
					end

					if regen > 0 then
						local before = state.current
						state.current = math.min(state.max, state.current + regen * CONFIG.TICK)

						-- Só avisa o cliente quando cruza um ponto inteiro
						if math.floor(state.current) ~= math.floor(before) then
							pushUpdate(player)
							refreshToolGates(player)
						end
					end
				end
			end
		end
	end
end)

-- =====================================
-- EVENTOS DE JOGADOR
-- =====================================

local function setupPlayer(player)
	energyState[player] = {
		current = 0,
		max = 100,
		regen = 5,
		level = 1,
		modifiers = copyModifiers(nil),
		heldTools = {},
		toolConnections = {},
	}

	recalcLimits(player)
	energyState[player].current = energyState[player].max
	pushUpdate(player)

	local backpack = player:FindFirstChildOfClass("Backpack")
	if backpack then
		watchContainer(player, backpack)
	end

	player.ChildAdded:Connect(function(child)
		if child:IsA("Backpack") then
			watchContainer(player, child)
		end
	end)

	player.CharacterAdded:Connect(function(character)
		task.wait(1) -- deixa o GameManager entregar as Tools primeiro
		recalcLimits(player)
		if CONFIG.REFILL_ON_SPAWN then
			energyState[player].current = energyState[player].max
		end
		watchContainer(player, character)
		watchContainer(player, player:FindFirstChildOfClass("Backpack"))
		pushUpdate(player)
		refreshToolGates(player)
	end)

	if player.Character then
		watchContainer(player, player.Character)
	end
end

local function cleanupPlayer(player)
	local state = energyState[player]
	if state then
		for tool in pairs(state.toolConnections) do
			unhookTool(player, tool)
		end
	end
	energyState[player] = nil
end

Players.PlayerAdded:Connect(setupPlayer)
Players.PlayerRemoving:Connect(cleanupPlayer)

for _, player in ipairs(Players:GetPlayers()) do
	setupPlayer(player)
end

-- =====================================
-- API GLOBAL
-- =====================================

_G.EnergySystem = {
	CONFIG = CONFIG,

	getEnergy = function(player)
		local state = energyState[player]
		if not state then
			return nil
		end
		return {
			current = math.floor(state.current),
			max = state.max,
			regen = state.regen,
			level = state.level,
		}
	end,

	consume = consume,
	restore = restore,

	-- Chamado pelo PassiveSystemServer_V1 quando a build muda
	setModifiers = function(player, modifiers)
		local state = energyState[player]
		if not state then
			return false
		end
		state.modifiers = copyModifiers(modifiers)
		recalcLimits(player)
		pushUpdate(player)
		refreshToolGates(player)
		return true
	end,

	clearModifiers = function(player)
		local state = energyState[player]
		if not state then
			return false
		end
		state.modifiers = copyModifiers(nil)
		recalcLimits(player)
		pushUpdate(player)
		refreshToolGates(player)
		return true
	end,

	-- Recalcula ao trocar de personagem (o GameManager pode chamar)
	refresh = function(player)
		recalcLimits(player)
		pushUpdate(player)
		refreshToolGates(player)
	end,

	setToolCost = function(toolName, cost)
		if type(toolName) ~= "string" then
			return false
		end
		customToolCost[toolName] = math.clamp(
			math.floor(tonumber(cost) or CONFIG.DEFAULT_COST),
			CONFIG.MIN_COST,
			CONFIG.MAX_COST
		)
		return true
	end,

	getToolCost = getToolCost,
}

-- =====================================
-- DEBUG
-- =====================================

_G.DebugEnergy = function(playerName)
	local player = Players:FindFirstChild(playerName)
	if not player then
		print("❌ Jogador não encontrado")
		return
	end

	local state = energyState[player]
	if not state then
		print("❌ Sem estado de energia")
		return
	end

	print("\n========== DEBUG ENERGY V1 ==========")
	print(string.format("Jogador: %s (nível do personagem: %d)", player.Name, state.level))
	print(string.format("Energia: %.1f / %d | Regen: %.2f/s", state.current, state.max, state.regen))
	print(
		string.format(
			"Modificadores: custo x%.2f | regen x%.2f | max x%.2f | soParado=%s",
			state.modifiers.costMult,
			state.modifiers.regenMult,
			state.modifiers.maxMult,
			tostring(state.modifiers.idleOnlyRegen)
		)
	)

	for _, tool in ipairs(collectTools(player)) do
		print(
			string.format(
				"  %s | custo %d | %s",
				tool.Name,
				getToolCost(player, tool),
				state.heldTools[tool] and "TRAVADA (sem energia)" or "liberada"
			)
		)
	end
	print("=====================================\n")
end

print([[
╔══════════════════════════════════════════════════════╗
║  ENERGY SYSTEM SERVER V1 — CARREGADO                ║
╠══════════════════════════════════════════════════════╣
║  SCRIPT NOVO (não substitui nada)                    ║
║  DEPENDE DE: DataManager V7 + CharacterLevelServer   ║
╠══════════════════════════════════════════════════════╣
║  * Cada Tool.Activated consome energia               ║
║  * Sem energia -> Tool.Enabled = false (segurado)    ║
║  * Máximo/regen vêm do NÍVEL do personagem           ║
║  * Custo por Tool: NumberValue "EnergyCost" dentro   ║
║    da Tool, ou _G.EnergySystem.setToolCost(nome, n)  ║
║  * Nenhuma Tool precisa ser editada                  ║
╠══════════════════════════════════════════════════════╣
║  DEBUG: _G.DebugEnergy("NomeJogador")                ║
╚══════════════════════════════════════════════════════╝
]])
