-- ============================================
-- BOSS EXIT TELEPORT V1 — RECOMPENSA ANTES DO TELEPORTE, SEMPRE
-- Coloque em ServerScriptService (PLACE DO CHEFÃO)
-- Nome: "Boss_ExitTeleport"
-- SCRIPT NOVO — não substitui nada
-- DEPENDE DE: Boss_TeleportDataReceiver_V1 (_G.BossSession),
--             BossConfigServer_V1 (_G.BossConfig),
--             DataManager (cópia local, mesmo DATASTORE_NAME)
-- OPCIONAL:   CharacterCatalogServer (valida o personagem-prêmio)
-- ============================================
-- REGRAS 7, 9 e 13 das Diretrizes.
--
-- ⚠️ A ORDEM É O CORAÇÃO DESTE SCRIPT, e ela é INEGOCIÁVEL:
--      1. já entreguei a recompensa a este jogador?
--      2. se não, entregar AGORA
--      3. confirmar que a entrega PERSISTIU (savePlayerData)
--      4. só então teleportar
--
--    Nunca teleportar primeiro e conceder depois. Se o servidor cair
--    entre os dois passos, o jogador perde o prêmio que ganhou — e como
--    a sessão é de uso único (regra 13), ele não tem como voltar para
--    tentar de novo. O prejuízo é permanente.
--
-- VITÓRIA (regra 7): checa → entrega → confirma → teleporta, por jogador.
-- DERROTA TOTAL (regra 9): expulsão em grupo, SEM recompensa. A checagem
--   de entrega é PULADA de propósito: não há o que confirmar.
-- MORTE INDIVIDUAL (regra 7): o jogador que morre volta sozinho, sem
--   recompensa, e a luta continua para os demais (regra 8).
--
-- Anti-duplicata: `jaProcessado` impede que o mesmo jogador entre duas
-- vezes na sequência. Sem isso, morrer no mesmo instante em que o chefe
-- cai dispararia vitória e derrota juntas para a mesma pessoa.
--
-- REUTILIZADO (nada criado do zero):
-- • Concessão que não duplica prêmio ... AchievementSystemServer_V3
--   (checa "já possui?" antes de conceder)
-- • addCharacterToInventory / savePlayerData ... DataManager
-- • BadgeService:AwardBadge ............ GameManager_V9
-- • TeleportAsync com lista de jogadores BossRaidServer_V2
-- ============================================

local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local BadgeService = game:GetService("BadgeService")

repeat
	task.wait()
until _G.PlayerDataManager and _G.BossSession

local CONFIG = {
	-- Place principal, fixada na V3 das Diretrizes (regra 7)
	PLACE_PRINCIPAL = 133619220682618,

	-- Segundos entre a entrega e o teleporte. Dá folga para a escrita do
	-- DataStore assentar antes de o jogador trocar de servidor.
	FOLGA_APOS_SALVAR = 1.5,

	-- Tentativas de teleporte. Teleporte falha por rede; sem retry o
	-- jogador ficaria preso numa place de uso único, sem saída.
	TENTATIVAS_TELEPORTE = 3,

	-- Segundos mostrando o resultado antes de tirar o jogador da place
	VITRINE_VITORIA = 5,
	VITRINE_DERROTA = 3,
}

-- =====================================
-- ESTADO
-- =====================================

local jaProcessado = {} -- [userId] = "vitoria" | "derrota"
local sessaoEncerrada = false

-- =====================================
-- ENTREGA DA RECOMPENSA (PASSOS 1, 2 e 3)
-- =====================================

-- Devolve: entregou (bool), detalhe (string)
-- `entregou == true` significa que a recompensa está PERSISTIDA, não
-- apenas escrita em memória. Só com true na mão é que se teleporta.
local function entregarRecompensa(player)
	local bossId = _G.BossSession.getBossId()
	if not bossId then
		return false, "sessão sem bossId — nada a entregar"
	end

	local cfg = _G.BossConfig and _G.BossConfig.obter(bossId)
	if not cfg then
		return false, "sem BossConfigServer — nada a entregar"
	end

	local entregouAlgo = false
	local detalhes = {}

	-- ---------- PERSONAGEM-PRÊMIO ----------
	if cfg.recompensaPersonagem and cfg.recompensaPersonagem ~= "" then
		local nome = cfg.recompensaPersonagem

		-- PASSO 1: já possui? Mesmo padrão do AchievementSystemServer:
		-- checar antes de conceder é o que evita prêmio duplicado.
		local jaTem = false
		if _G.PlayerDataManager.ownsCharacter then
			local ok, possui = pcall(_G.PlayerDataManager.ownsCharacter, player, nome)
			jaTem = ok and possui or false
		end

		if jaTem then
			table.insert(detalhes, string.format("já possuía '%s'", nome))
			entregouAlgo = true -- nada a fazer, mas o requisito está cumprido
		else
			-- Se o catálogo estiver nesta place, confere se o prêmio
			-- existe. Conceder um nome que não existe no catálogo criaria
			-- um personagem fantasma no inventário — o mesmo problema que
			-- o AwakeningSystemServer_V3 fechou.
			local existeNoCatalogo = true
			if _G.CharacterCatalog and _G.CharacterCatalog.getDefinition then
				local ok, def = pcall(_G.CharacterCatalog.getDefinition, nome)
				existeNoCatalogo = ok and def ~= nil
			end

			if not existeNoCatalogo then
				warn(string.format(
					"[BOSS EXIT V1] ⚠️ Prêmio '%s' do chefe '%s' NÃO existe no catálogo — não concedido a %s",
					nome, bossId, player.Name
				))
				table.insert(detalhes, string.format("prêmio '%s' fora do catálogo", nome))
			else
				-- PASSO 2: entregar
				-- Assinatura conferida no DataManager:
				-- addCharacterToInventory(player, characterName) — dois
				-- argumentos, sem parâmetro de origem.
				local ok = false
				if _G.PlayerDataManager.addCharacterToInventory then
					ok = select(1, pcall(_G.PlayerDataManager.addCharacterToInventory, player, nome))
				end
				if ok then
					entregouAlgo = true
					table.insert(detalhes, string.format("personagem '%s' concedido", nome))
				else
					table.insert(detalhes, string.format("FALHA ao conceder '%s'", nome))
				end
			end
		end
	end

	-- ---------- BADGE ----------
	-- O Badge é do Roblox, não do nosso DataStore: AwardBadge já é
	-- idempotente (não dá duas vezes), então não precisa de checagem
	-- prévia como o personagem.
	if cfg.recompensaBadgeId and cfg.recompensaBadgeId > 0 then
		local ok, concedido = pcall(function()
			return BadgeService:AwardBadge(player.UserId, cfg.recompensaBadgeId)
		end)
		if ok and concedido then
			entregouAlgo = true
			table.insert(detalhes, string.format("badge %d concedido", cfg.recompensaBadgeId))
		elseif ok then
			entregouAlgo = true
			table.insert(detalhes, "já tinha o badge")
		else
			table.insert(detalhes, "FALHA no badge")
		end
	end

	if #detalhes == 0 then
		return false, "chefe sem recompensa configurada"
	end

	-- PASSO 3: confirmar que persistiu. É este save que transforma
	-- "escrevi na memória" em "está no DataStore".
	local salvou = false
	if _G.PlayerDataManager.savePlayerData then
		salvou = select(1, pcall(_G.PlayerDataManager.savePlayerData, player))
	end

	if not salvou then
		warn(string.format(
			"[BOSS EXIT V1] ⚠️ savePlayerData FALHOU para %s — teleporte adiado, tentando de novo",
			player.Name
		))
		task.wait(2)
		salvou = select(1, pcall(_G.PlayerDataManager.savePlayerData, player))
	end

	return (entregouAlgo and salvou), table.concat(detalhes, ", ")
end

-- =====================================
-- TELEPORTE (PASSO 4)
-- =====================================

local function teleportar(jogadores, rotulo)
	local validos = {}
	for _, p in ipairs(jogadores) do
		if p and p.Parent then
			table.insert(validos, p)
		end
	end
	if #validos == 0 then
		return
	end

	for tentativa = 1, CONFIG.TENTATIVAS_TELEPORTE do
		local ok, err = pcall(function()
			TeleportService:TeleportAsync(CONFIG.PLACE_PRINCIPAL, validos)
		end)
		if ok then
			print(string.format(
				"[BOSS EXIT V1] %s: %d jogador(es) enviado(s) para a place principal",
				rotulo,
				#validos
			))
			return
		end
		warn(string.format(
			"[BOSS EXIT V1] Teleporte falhou (tentativa %d/%d): %s",
			tentativa,
			CONFIG.TENTATIVAS_TELEPORTE,
			tostring(err)
		))
		task.wait(2 ^ tentativa)
	end

	-- Esgotou. A place é de uso único (regra 13), então ficar aqui é um
	-- beco sem saída — o Kick pelo menos devolve o jogador ao menu do
	-- Roblox, de onde ele entra na place principal normalmente.
	warn("[BOSS EXIT V1] ⚠️ Teleporte esgotou as tentativas — expulsando para o jogador não ficar preso")
	for _, p in ipairs(validos) do
		pcall(function()
			p:Kick("Não foi possível voltar automaticamente. Entre no jogo novamente — sua recompensa já foi salva.")
		end)
	end
end

-- =====================================
-- SAÍDAS
-- =====================================

-- VITÓRIA (regra 7): recompensa por jogador, na ordem certa, e só então
-- o teleporte do grupo.
local function saidaVitoria()
	if sessaoEncerrada then
		return
	end
	sessaoEncerrada = true

	local jogadores = _G.BossSession.getPlayers()
	print(string.format("[BOSS EXIT V1] 🏆 VITÓRIA — processando %d jogador(es)", #jogadores))

	local prontos = {}
	for _, player in ipairs(jogadores) do
		if not jaProcessado[player.UserId] then
			jaProcessado[player.UserId] = "vitoria"

			local entregou, detalhe = entregarRecompensa(player)
			if entregou then
				print(string.format("[BOSS EXIT V1] ✓ %s: %s", player.Name, detalhe))
			else
				warn(string.format("[BOSS EXIT V1] %s SEM recompensa: %s", player.Name, detalhe))
			end
			table.insert(prontos, player)
		end
	end

	task.wait(CONFIG.FOLGA_APOS_SALVAR)
	task.wait(CONFIG.VITRINE_VITORIA)
	teleportar(prontos, "VITÓRIA")
end

-- DERROTA TOTAL (regra 9): expulsão em grupo, SEM recompensa.
local function saidaDerrotaTotal()
	if sessaoEncerrada then
		return
	end
	sessaoEncerrada = true

	local jogadores = _G.BossSession.getPlayers()
	print(string.format("[BOSS EXIT V1] 💀 DERROTA TOTAL — %d jogador(es), sem recompensa", #jogadores))

	for _, player in ipairs(jogadores) do
		jaProcessado[player.UserId] = "derrota"
	end

	task.wait(CONFIG.VITRINE_DERROTA)
	teleportar(jogadores, "DERROTA TOTAL")
end

-- MORTE INDIVIDUAL (regra 7 + 8): volta sozinho, sem recompensa, e a
-- luta segue para os outros.
local function saidaMorteIndividual(player)
	if jaProcessado[player.UserId] then
		return
	end
	jaProcessado[player.UserId] = "derrota"

	print(string.format("[BOSS EXIT V1] ☠️ %s morreu — volta sem recompensa. A luta continua.", player.Name))

	task.wait(CONFIG.VITRINE_DERROTA)
	teleportar({ player }, "MORTE de " .. player.Name)
end

-- =====================================
-- DETECÇÃO DE DERROTA TOTAL
-- =====================================
-- Regra 9: contar vivos a cada morte; zero vivos = expulsão em grupo.

local function contarVivos()
	local vivos = 0
	for _, player in ipairs(_G.BossSession.getPlayers()) do
		local personagem = player.Character
		local humanoid = personagem and personagem:FindFirstChildOfClass("Humanoid")
		if humanoid and humanoid.Health > 0 then
			vivos += 1
		end
	end
	return vivos
end

local function acompanharMorte(player, personagem)
	local humanoid = personagem:WaitForChild("Humanoid", 10)
	if not humanoid then
		return
	end

	humanoid.Died:Connect(function()
		if sessaoEncerrada then
			return
		end

		-- Deixa o estado assentar antes de contar: o Humanoid que acabou
		-- de morrer ainda pode aparecer com Health > 0 neste instante.
		task.wait(0.5)

		if contarVivos() <= 0 then
			task.spawn(saidaDerrotaTotal)
		else
			task.spawn(saidaMorteIndividual, player)
		end
	end)
end

local function onPlayerAdded(player)
	player.CharacterAdded:Connect(function(personagem)
		acompanharMorte(player, personagem)
	end)
	if player.Character then
		acompanharMorte(player, player.Character)
	end
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in ipairs(Players:GetPlayers()) do
	onPlayerAdded(player)
end

-- =====================================
-- API GLOBAL
-- =====================================
-- É isto que o script de morte do chefe chama quando o Humanoid do chefe
-- morre. Fica aqui e não no Model do chefe de propósito: a sequência de
-- recompensa é a mesma para todo chefe, e duplicá-la em cada Model seria
-- convite a uma cópia esquecer o passo 3.

_G.BossExit = {
	CONFIG = CONFIG,

	-- Chame quando o CHEFE morrer
	vitoria = function()
		task.spawn(saidaVitoria)
	end,

	-- Chame se precisar encerrar em derrota fora do fluxo de morte
	derrotaTotal = function()
		task.spawn(saidaDerrotaTotal)
	end,

	encerrada = function()
		return sessaoEncerrada
	end,
}

_G.DebugBossExit = function()
	print("\n========== DEBUG BOSS EXIT V1 ==========")
	print(string.format("Sessão encerrada: %s", tostring(sessaoEncerrada)))
	print(string.format("Place de destino: %d", CONFIG.PLACE_PRINCIPAL))
	print(string.format("Vivos agora: %d de %d", contarVivos(), _G.BossSession.contar()))
	local n = 0
	for userId, resultado in pairs(jaProcessado) do
		n += 1
		print(string.format("  userId %d -> %s", userId, resultado))
	end
	if n == 0 then
		print("  (ninguém processado ainda)")
	end
	print("=========================================\n")
end

print([[
╔════════════════════════════════════════════════════╗
║  🚪 BOSS EXIT TELEPORT V1 CARREGADO                ║
╠════════════════════════════════════════════════════╣
║  SCRIPT NOVO (place do CHEFÃO)                     ║
║  DEPENDE DE: Boss_TeleportDataReceiver_V1 +        ║
║              BossConfigServer_V1 + DataManager     ║
╠════════════════════════════════════════════════════╣
║  ORDEM INEGOCIÁVEL (regra 7):                      ║
║   1. já entreguei?  2. entregar  3. CONFIRMAR      ║
║   4. só então teleportar                           ║
║  Teleportar antes de confirmar pode custar o        ║
║  prêmio do jogador para sempre (regra 13)          ║
╠════════════════════════════════════════════════════╣
║  Vitória: recompensa + teleporte do grupo          ║
║  Derrota total: grupo volta SEM recompensa         ║
║  Morte individual: volta só ela, luta continua     ║
╠════════════════════════════════════════════════════╣
║  O Model do chefe chama _G.BossExit.vitoria()      ║
║  quando o Humanoid dele morrer                     ║
╠════════════════════════════════════════════════════╣
║  DEBUG: _G.DebugBossExit()                          ║
╚════════════════════════════════════════════════════╝
]])
