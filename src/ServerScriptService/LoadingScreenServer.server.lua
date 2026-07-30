-- ============================================================================
-- LoadingScreenServer V2  ·  ServerScriptService
-- (V2) ALTERAÇÕES: :Destroy() -> .Parent = nil; estágios com texto RETRO ARCADE
-- ============================================================================
-- Parte SERVIDOR da tela de carregamento (arquitetura server + client).
-- Avisa o cliente quando o jogador está 100% PRONTO de verdade:
--   • dados carregados (_G.PlayerDataManager.getPlayerData)
--   • personagem existente
-- O cliente (ReplicatedFirst/LoadingScreen) só some quando recebe esse sinal
-- (ou quando estoura o limite anti-trava). Assim a tela cobre o carregamento
-- REAL, não só um timer.
-- ============================================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local remotes = ReplicatedStorage:FindFirstChild("Remotes")
if not remotes then
	remotes = Instance.new("Folder")
	remotes.Name = "Remotes"
	remotes.Parent = ReplicatedStorage
end

local function ensureRemote(name, className)
	local remote = remotes:FindFirstChild(name)
	if remote and not remote:IsA(className) then
		remote.Parent = nil
		remote = nil
	end
	if not remote then
		remote = Instance.new(className)
		remote.Name = name
		remote.Parent = remotes
	end
	return remote
end

local loadingReady = ensureRemote("LoadingReady", "RemoteEvent") -- server -> client (pronto!)
local queryLoadingReady = ensureRemote("QueryLoadingReady", "RemoteFunction") -- client -> server (poll)
local loadingStage = ensureRemote("LoadingStage", "RemoteEvent") -- server -> client (estagio atual)

local ready = {} -- [player] = true

queryLoadingReady.OnServerInvoke = function(player)
	return ready[player] == true
end

local function setStage(player, stage, fraction)
	loadingStage:FireClient(player, stage, fraction)
end

local function markReady(player)
	if ready[player] then
		return
	end
	ready[player] = true
	loadingReady:FireClient(player)
end

-- Sequência de "prontidão" do jogador, com limites anti-trava.
local function prepare(player)
	-- 1) Espera o gerenciador de dados existir
	setStage(player, "CONECTANDO AO SERVIDOR...", 0.15)
	local t = 0
	while not _G.PlayerDataManager and t < 30 do
		task.wait(0.2)
		t += 0.2
	end

	-- 2) Espera os dados do jogador carregarem
	setStage(player, "CARREGANDO SAVE DO PLAYER...", 0.45)
	t = 0
	while t < 30 do
		local okData = _G.PlayerDataManager and _G.PlayerDataManager.getPlayerData(player)
		if okData then
			break
		end
		task.wait(0.2)
		t += 0.2
	end

	-- 3) Espera o personagem aparecer
	setStage(player, "RENDERIZANDO O MUNDO...", 0.8)
	if not player.Character then
		local done = false
		local conn = player.CharacterAdded:Connect(function()
			done = true
		end)
		local t2 = 0
		while not done and not player.Character and t2 < 20 do
			task.wait(0.2)
			t2 += 0.2
		end
		if conn.Connected then
			conn:Disconnect()
		end
	end

	-- 4) Pronto!
	setStage(player, "READY!", 1)
	markReady(player)
	print(string.format("[LOADING SERVER V2] %s pronto", player.Name))
end

Players.PlayerAdded:Connect(function(player)
	task.spawn(function()
		prepare(player)
	end)
end)

for _, p in ipairs(Players:GetPlayers()) do
	task.spawn(function()
		prepare(p)
	end)
end

Players.PlayerRemoving:Connect(function(p)
	ready[p] = nil
end)

print("[LOADING SERVER V2] carregado")
