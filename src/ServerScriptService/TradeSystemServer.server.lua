-- ============================================
-- TRADE SYSTEM SERVER V1 — TROCAS + DOAÇÕES
-- Coloque em ServerScriptService
-- Nome: "TradeSystemServer"
-- ============================================
-- SISTEMA NOVO construído 100% sobre código existente:
-- • REUTILIZADO do TeamSystemServer_V4: fluxo de convite com
--   pendingInvites + GUID + timeout + RespondTo (aceitar/recusar)
-- • REUTILIZADO do MissionSystemServer_V2: padrão ensureRemote
--   e espera do _G.PlayerDataManager
-- • REUTILIZADO do DataManager_V4 (API já preparada p/ trocas):
--   getTradeableCharacters, getCharacterById, addCharacter,
--   removeCharacterById, updateCoins, incrementStat,
--   addTradeToHistory, savePlayerData, ownsCharacter
-- • REUTILIZADO do GameManager_V6: _G.GameManagerConfig
--   .isCharacterEquipped (bloqueio igual ao da VENDA)
--
-- REGRAS DO SISTEMA:
-- • Só personagens da CATEGORIA LOJA podem ser trocados
--   (source "Shop", ou "Trade" = item que veio da loja em
--   troca anterior). Reward/Gamepass/Badge/Mandatory: NUNCA.
-- • SISTEMA DE VALOR: cada lado mostra o valor total
--   (preço original de loja dos personagens + moedas).
-- • DOAÇÕES: moedas podem ir só para um lado (oferta vazia
--   do outro) — doar dinheiro é permitido.
-- • Personagem EQUIPADO não pode ser oferecido (mesma regra
--   da venda do GameManager_V6).
-- • Qualquer mudança de oferta RESETA o "PRONTO" dos dois.
-- ============================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local CONFIG = {
	REQUEST_TIMEOUT = 20, -- igual ao INVITE_TIMEOUT do TeamSystem
	MAX_CHARS_PER_SIDE = 4,
	TRADE_COOLDOWN = 5, -- segundos entre trocas concluídas
}

-- Aguardar o gerenciador de dados (REUTILIZADO do MissionSystemServer_V2)
repeat
	task.wait()
until _G.PlayerDataManager

local PDM = _G.PlayerDataManager

-- =====================================
-- REMOTES (padrão REUTILIZADO do MissionSystemServer_V2)
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

local requestTradeRemote = ensureRemote("RequestTrade", "RemoteFunction") -- client -> server
local getTradeDataRemote = ensureRemote("GetTradeData", "RemoteFunction") -- client -> server
local tradeInviteRemote = ensureRemote("TradeInvite", "RemoteEvent") -- server -> client
local respondToTradeRemote = ensureRemote("RespondToTrade", "RemoteEvent") -- client -> server
local updateTradeOfferRemote = ensureRemote("UpdateTradeOffer", "RemoteEvent") -- client -> server
local tradeStateRemote = ensureRemote("TradeStateUpdate", "RemoteEvent") -- server -> client
local tradeResultRemote = ensureRemote("TradeResult", "RemoteEvent") -- server -> client

-- =====================================
-- ESTADO
-- =====================================

local pendingRequests = {} -- [id] = { from, to, expires }
local activeTrades = {} -- [player] = session
local tradeCooldown = {} -- [player] = os.time()

-- =====================================
-- HELPERS DE VALIDAÇÃO (sistema de valor da LOJA)
-- =====================================

-- Só categoria LOJA: "Shop" direto, ou "Trade" (veio da loja
-- numa troca anterior — DataManager_V4 mantém tradeable = true)
local function isShopOrigin(charObj)
	return charObj
		and charObj.tradeable == true
		and (charObj.source == "Shop" or charObj.source == "Trade")
end

local function isEquipped(player, characterName)
	local gmc = _G.GameManagerConfig
	if gmc and gmc.isCharacterEquipped then
		return gmc.isCharacterEquipped(player, characterName)
	end
	local data = PDM.getPlayerData(player)
	return data ~= nil and data.equippedCharacter == characterName
end

-- Lista enviada ao client: só o que PODE ser oferecido agora
local function getOfferableCharacters(player)
	local result = {}
	local tradeables = PDM.getTradeableCharacters(player) or {}
	for _, charObj in ipairs(tradeables) do
		if isShopOrigin(charObj) and not isEquipped(player, charObj.name) then
			table.insert(result, {
				id = charObj.id,
				name = charObj.name,
				price = charObj.originalPrice or 0,
			})
		end
	end
	return result
end

local function offerTotalValue(offer)
	local total = offer.coins or 0
	for _, item in ipairs(offer.chars) do
		total += item.price or 0
	end
	return total
end

-- =====================================
-- SESSÃO DE TROCA
-- =====================================

local function otherPlayer(session, player)
	return (session.a == player) and session.b or session.a
end

local function newSession(a, b)
	return {
		id = HttpService:GenerateGUID(false),
		a = a,
		b = b,
		offers = {
			[a] = { chars = {}, coins = 0 },
			[b] = { chars = {}, coins = 0 },
		},
		ready = { [a] = false, [b] = false },
	}
end

local function buildSideInfo(session, player)
	local offer = session.offers[player]
	return {
		name = player.Name,
		chars = offer.chars,
		coins = offer.coins,
		ready = session.ready[player],
		total = offerTotalValue(offer),
	}
end

local function broadcastState(session)
	for _, p in ipairs({ session.a, session.b }) do
		local o = otherPlayer(session, p)
		tradeStateRemote:FireClient(p, {
			tradeId = session.id,
			you = buildSideInfo(session, p),
			other = buildSideInfo(session, o),
			maxChars = CONFIG.MAX_CHARS_PER_SIDE,
		})
	end
end

local function resetReady(session)
	session.ready[session.a] = false
	session.ready[session.b] = false
end

local function endSession(session)
	activeTrades[session.a] = nil
	activeTrades[session.b] = nil
end

local function cancelSession(session, message)
	endSession(session)
	for _, p in ipairs({ session.a, session.b }) do
		if p.Parent then
			tradeResultRemote:FireClient(p, false, message)
		end
	end
	print("[TRADE V1] Troca cancelada: " .. message)
end

-- =====================================
-- PEDIDO DE TROCA (fluxo REUTILIZADO do TeamSystemServer_V4)
-- =====================================

local function requestTrade(player, targetName)
	local target = Players:FindFirstChild(tostring(targetName))

	if not target then
		return false, "Jogador não encontrado!"
	end
	if target == player then
		return false, "Você não pode trocar consigo mesmo!"
	end
	if activeTrades[player] then
		return false, "Você já está em uma troca!"
	end
	if activeTrades[target] then
		return false, target.Name .. " já está em uma troca!"
	end
	if not PDM.getPlayerData(player) or not PDM.getPlayerData(target) then
		return false, "Dados ainda carregando, tente de novo!"
	end

	local now = os.time()
	if tradeCooldown[player] and now - tradeCooldown[player] < CONFIG.TRADE_COOLDOWN then
		return false, "Aguarde alguns segundos para trocar de novo!"
	end

	for _, req in pairs(pendingRequests) do
		if req.from == player and req.to == target and req.expires > now then
			return false, "Pedido já enviado!"
		end
	end

	local requestId = HttpService:GenerateGUID(false)
	pendingRequests[requestId] = {
		from = player,
		to = target,
		expires = now + CONFIG.REQUEST_TIMEOUT,
	}

	tradeInviteRemote:FireClient(target, player.Name)

	-- Expiração (REUTILIZADO do TeamSystemServer_V4)
	task.spawn(function()
		task.wait(CONFIG.REQUEST_TIMEOUT)
		if pendingRequests[requestId] then
			pendingRequests[requestId] = nil
			if player.Parent then
				tradeResultRemote:FireClient(
					player,
					false,
					"Pedido de troca para " .. target.Name .. " expirou."
				)
			end
			print(string.format("[TRADE V1] Pedido expirado: %s -> %s", player.Name, target.Name))
		end
	end)

	print(string.format("[TRADE V1] Pedido enviado: %s -> %s", player.Name, target.Name))
	return true, "Pedido de troca enviado para " .. target.Name .. "!"
end

requestTradeRemote.OnServerInvoke = requestTrade

getTradeDataRemote.OnServerInvoke = function(player)
	local data = PDM.getPlayerData(player)
	return {
		tradeables = getOfferableCharacters(player),
		coins = data and data.coins or 0,
	}
end

respondToTradeRemote.OnServerEvent:Connect(function(player, accepted)
	-- Varredura igual ao RespondToInvite do TeamSystemServer_V4
	local validRequest = nil
	for id, req in pairs(pendingRequests) do
		if req.to == player and req.expires > os.time() then
			validRequest = req
			pendingRequests[id] = nil
			break
		end
	end

	if not validRequest then
		return
	end

	local from = validRequest.from
	if not accepted then
		if from.Parent then
			tradeResultRemote:FireClient(from, false, player.Name .. " recusou a troca.")
		end
		print(string.format("[TRADE V1] %s recusou troca de %s", player.Name, from.Name))
		return
	end

	if not from.Parent or activeTrades[from] or activeTrades[player] then
		tradeResultRemote:FireClient(player, false, "A troca não está mais disponível.")
		return
	end

	local session = newSession(from, player)
	activeTrades[from] = session
	activeTrades[player] = session
	broadcastState(session)
	print(string.format("[TRADE V1] Troca iniciada: %s <-> %s", from.Name, player.Name))
end)

-- =====================================
-- VALIDAÇÃO DE ITENS DA OFERTA
-- =====================================

local function canOfferCharacter(player, receiver, charId)
	local charObj = PDM.getCharacterById(player, charId)
	if not charObj then
		return false, "Personagem não encontrado!"
	end
	if not isShopOrigin(charObj) then
		return false, charObj.name .. " não é da categoria LOJA — não pode ser trocado!"
	end
	if isEquipped(player, charObj.name) then
		return false, "Desequipe " .. charObj.name .. " antes de oferecer!"
	end
	if PDM.ownsCharacter(receiver, charObj.name) then
		return false, receiver.Name .. " já possui " .. charObj.name .. "!"
	end
	return true, charObj
end

local function validateWholeOffer(session, player)
	local receiver = otherPlayer(session, player)
	local offer = session.offers[player]

	for _, item in ipairs(offer.chars) do
		local ok, result = canOfferCharacter(player, receiver, item.id)
		if not ok then
			return false, player.Name .. ": " .. result
		end
	end

	local data = PDM.getPlayerData(player)
	if not data then
		return false, "Dados de " .. player.Name .. " indisponíveis!"
	end
	if (offer.coins or 0) > data.coins then
		return false, player.Name .. " não tem moedas suficientes!"
	end

	return true
end

-- =====================================
-- EXECUÇÃO DA TROCA (com rollback)
-- =====================================

local function executeTrade(session)
	-- Bloquear troca completamente vazia
	local totalA = offerTotalValue(session.offers[session.a])
	local totalB = offerTotalValue(session.offers[session.b])
	if totalA == 0 and totalB == 0 then
		resetReady(session)
		broadcastState(session)
		for _, q in ipairs({ session.a, session.b }) do
			tradeResultRemote:FireClient(q, false, "Troca vazia! Ofereça algo ou doe moedas.")
		end
		return
	end

	-- Revalidação atômica dos dois lados
	for _, p in ipairs({ session.a, session.b }) do
		local ok, err = validateWholeOffer(session, p)
		if not ok then
			resetReady(session)
			broadcastState(session)
			for _, q in ipairs({ session.a, session.b }) do
				tradeResultRemote:FireClient(q, false, "Troca bloqueada: " .. err)
			end
			return
		end
	end

	-- Transferência de personagens (DataManager_V4)
	local moved = {} -- para rollback: { fromPlayer, toPlayer, charObj, added }
	for _, giver in ipairs({ session.a, session.b }) do
		local receiver = otherPlayer(session, giver)
		for _, item in ipairs(session.offers[giver].chars) do
			local removed, charObj = PDM.removeCharacterById(giver, item.id)
			if not removed then
				-- Rollback do que já foi movido
				for _, m in ipairs(moved) do
					if m.added then
						local back = PDM.getCharacterByName
							and select(1, PDM.getCharacterByName(m.toPlayer, m.charObj.name))
						if back then
							PDM.removeCharacterById(m.toPlayer, back.id)
						end
					end
					PDM.addCharacter(m.fromPlayer, m.charObj.name, m.charObj.source, m.charObj.originalPrice)
				end
				cancelSession(session, "Falha ao transferir personagem — troca revertida.")
				return
			end

			-- Recebido vira source "Trade" (continua trocável — origem LOJA)
			local addedOk = PDM.addCharacter(receiver, charObj.name, "Trade", charObj.originalPrice)
			table.insert(moved, {
				fromPlayer = giver,
				toPlayer = receiver,
				charObj = charObj,
				added = addedOk == true,
			})

			if not addedOk then
				for _, m in ipairs(moved) do
					if m.added then
						local back = select(1, PDM.getCharacterByName(m.toPlayer, m.charObj.name))
						if back then
							PDM.removeCharacterById(m.toPlayer, back.id)
						end
					end
					PDM.addCharacter(m.fromPlayer, m.charObj.name, m.charObj.source, m.charObj.originalPrice)
				end
				cancelSession(session, "Falha ao entregar personagem — troca revertida.")
				return
			end
		end
	end

	-- Transferência de moedas (DOAÇÕES incluídas) — saldo líquido
	local coinsA = session.offers[session.a].coins or 0
	local coinsB = session.offers[session.b].coins or 0
	if coinsA ~= coinsB then
		PDM.updateCoins(session.a, coinsB - coinsA)
		PDM.updateCoins(session.b, coinsA - coinsB)
	end

	-- Histórico e stats (campos já preparados no DataManager_V4)
	for _, p in ipairs({ session.a, session.b }) do
		PDM.incrementStat(p, "trades_completed", 1)
		if PDM.addTradeToHistory then
			PDM.addTradeToHistory(p, session.id)
		end
		PDM.savePlayerData(p)
	end

	local resumoA = string.format(
		"Troca concluída com %s! Enviou %d item(ns) + %d moedas.",
		session.b.Name,
		#session.offers[session.a].chars,
		coinsA
	)
	local resumoB = string.format(
		"Troca concluída com %s! Enviou %d item(ns) + %d moedas.",
		session.a.Name,
		#session.offers[session.b].chars,
		coinsB
	)
	tradeResultRemote:FireClient(session.a, true, resumoA)
	tradeResultRemote:FireClient(session.b, true, resumoB)

	tradeCooldown[session.a] = os.time()
	tradeCooldown[session.b] = os.time()
	endSession(session)

	print(string.format("[TRADE V1] ✅ Troca concluída: %s <-> %s (id %s)", session.a.Name, session.b.Name, session.id))
end

-- =====================================
-- AÇÕES NA MESA DE TROCA
-- =====================================

updateTradeOfferRemote.OnServerEvent:Connect(function(player, action, value)
	local session = activeTrades[player]
	if not session then
		return
	end
	local offer = session.offers[player]
	local receiver = otherPlayer(session, player)

	if action == "addChar" then
		if #offer.chars >= CONFIG.MAX_CHARS_PER_SIDE then
			tradeResultRemote:FireClient(player, false, "Máximo de " .. CONFIG.MAX_CHARS_PER_SIDE .. " personagens por lado!")
			return
		end
		for _, item in ipairs(offer.chars) do
			if item.id == value then
				return -- já está na oferta
			end
		end
		local ok, result = canOfferCharacter(player, receiver, value)
		if not ok then
			tradeResultRemote:FireClient(player, false, result)
			return
		end
		table.insert(offer.chars, {
			id = result.id,
			name = result.name,
			price = result.originalPrice or 0,
		})
		resetReady(session)
		broadcastState(session)
	elseif action == "removeChar" then
		for i, item in ipairs(offer.chars) do
			if item.id == value then
				table.remove(offer.chars, i)
				break
			end
		end
		resetReady(session)
		broadcastState(session)
	elseif action == "setCoins" then
		local amount = math.floor(tonumber(value) or 0)
		local data = PDM.getPlayerData(player)
		if not data then
			return
		end
		offer.coins = math.clamp(amount, 0, data.coins)
		resetReady(session)
		broadcastState(session)
	elseif action == "ready" then
		session.ready[player] = (value == true)
		broadcastState(session)
		if session.ready[session.a] and session.ready[session.b] then
			executeTrade(session)
		end
	elseif action == "cancel" then
		cancelSession(session, player.Name .. " cancelou a troca.")
	end
end)

-- =====================================
-- SAÍDA DE JOGADOR (REUTILIZADO do TeamSystemServer_V4)
-- =====================================

Players.PlayerRemoving:Connect(function(player)
	for id, req in pairs(pendingRequests) do
		if req.from == player or req.to == player then
			pendingRequests[id] = nil
		end
	end

	local session = activeTrades[player]
	if session then
		local other = otherPlayer(session, player)
		endSession(session)
		if other.Parent then
			tradeResultRemote:FireClient(other, false, player.Name .. " saiu — troca cancelada.")
		end
	end

	tradeCooldown[player] = nil
end)

print([[
╔════════════════════════════════════════════════════╗
║   🔄 TRADE SYSTEM SERVER V1 — TROCAS + DOAÇÕES    ║
╠════════════════════════════════════════════════════╣
║  * Só personagens da categoria LOJA (Shop/Trade)  ║
║  * Sistema de VALOR (preço da loja + moedas)      ║
║  * Doações de dinheiro permitidas                 ║
║  * Equipado não troca | Pronto reseta na mudança  ║
╚════════════════════════════════════════════════════╝
]])
