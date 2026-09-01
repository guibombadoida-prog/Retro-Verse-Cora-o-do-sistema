-- Nome: "PassiveCatalog"
--[[
════════════════════════════════════════════════════════════════
	PASSIVE CATALOG V1 — CATÁLOGO DE HABILIDADES PASSIVAS
	ModuleScript
	Coloque em: ServerScriptService > PassiveCatalog
	Lido por: PassiveSystemServer V7

	Separado do PassiveSystemServer de propósito: o servidor tem a
	LÓGICA, este arquivo tem o CONTEÚDO. Adicionar passiva nova é
	mexer só aqui, sem risco de quebrar o sistema.
════════════════════════════════════════════════════════════════

	ESCALA POR NÍVEL — 1 a 10
	─────────────────────────────────────────────────────────
	Cada passiva declara valores POR NÍVEL. O valor final é
	`base × nivel`. Nível 10 = dez vezes o valor base.

	Isso é intencionalmente forte: no nível 10 uma Couraça dá
	+50% de resistência e tira 40% da velocidade. É pra ser
	estranhamente poderoso — e a desvantagem cresce junto, então
	continua sendo escolha, não upgrade grátis.

	Os tetos que impedem o absurdo já existem e são de outro lugar:
	  resistência .. 90%  (REGRA 12)
	  aumento ...... 300% (REGRA 12)
	  vida ......... piso de 25% da base (StatService)

	DOIS TIPOS
	─────────────────────────────────────────────────────────
	tipo = "permanente"
	    Vale o tempo todo, desde equipar até morrer ou trocar de
	    personagem. Não tem ativação, não tem recarga.

	tipo = "temporario"
	    Fica dormindo. Um GATILHO acorda ela, ela vale por
	    `duracao` segundos, e depois entra em `recarga`.
	    Gatilhos: "combate", "levar_dano", "causar_dano",
	              "abate", "vida_baixa"

	CAMPOS
	─────────────────────────────────────────────────────────
	stats      -> atributos do StatService (multiplicados pelo nível)
	special    -> comportamento condicional (ver PassiveSystemServer)
	chance     -> probabilidade por nível (Negador, Reverso)
	exclusivo  -> ocupa TODOS os slots; não combina com nenhuma outra
	vfx        -> efeito visual retrô (autoral, ver PassiveVFX)
════════════════════════════════════════════════════════════════
]]

local Catalogo = {}

Catalogo.MAX_NIVEL = 10

-- Custo em moedas para subir do nível N para N+1.
-- Cresce rápido de propósito: nível 10 tem que ser conquista.
Catalogo.CUSTO_BASE = 150
Catalogo.CUSTO_EXPOENTE = 1.6

function Catalogo.custoDoNivel(nivel)
	nivel = math.max(1, math.floor(tonumber(nivel) or 1))
	if nivel >= Catalogo.MAX_NIVEL then
		return nil -- já no máximo
	end
	return math.floor(Catalogo.CUSTO_BASE * (nivel ^ Catalogo.CUSTO_EXPOENTE))
end

--[[
════════════════════════════════════════════════════════════════
	AS PASSIVAS
════════════════════════════════════════════════════════════════
]]

Catalogo.LISTA = {

	-- ═══════════ DEFESA (permanentes) ═══════════

	{
		id = "couraca",
		nome = "Couraça",
		icone = "🛡️",
		categoria = "Defesa",
		tipo = "permanente",
		beneficio = "Reduz o dano recebido",
		malefico = "Reduz sua velocidade",
		vfx = "BRILHO_METALICO",
		stats = { DamageResistance = 0.05, WalkSpeedPercent = -0.04 },
	},
	{
		id = "casca_dura",
		nome = "Casca Dura",
		icone = "🪨",
		categoria = "Defesa",
		tipo = "permanente",
		beneficio = "Aumenta muito a vida máxima",
		malefico = "Desliga a regeneração natural",
		vfx = "POEIRA_PEDRA",
		stats = { HPPercent = 0.06 },
		special = { noRegen = true },
	},
	{
		id = "muralha",
		nome = "Muralha",
		icone = "🧱",
		categoria = "Defesa",
		tipo = "permanente",
		beneficio = "Ganha Defesa plana",
		malefico = "Fica mais lento e pula menos",
		vfx = "BRILHO_METALICO",
		stats = { DefenseFlat = 45, WalkSpeedPercent = -0.03, JumpPercent = -0.05 },
	},
	{
		id = "pele_ferro",
		nome = "Pele de Ferro",
		icone = "⛓️",
		categoria = "Defesa",
		tipo = "permanente",
		beneficio = "Resiste a golpes corpo a corpo",
		malefico = "Fica frágil contra magia",
		vfx = "BRILHO_METALICO",
		stats = { MeleeResist = 0.07, MagicResist = -0.05 },
	},
	{
		id = "barreira",
		nome = "Barreira",
		icone = "🔷",
		categoria = "Defesa",
		tipo = "permanente",
		beneficio = "Ganha Escudo, que absorve antes da vida",
		malefico = "Reduz a vida máxima",
		vfx = "ESCUDO_HEXAGONAL",
		stats = { Shield = 18, HPPercent = -0.03 },
	},

	-- ═══════════ ATAQUE (permanentes) ═══════════

	{
		id = "vidro_trincado",
		nome = "Vidro Trincado",
		icone = "💥",
		categoria = "Ataque",
		tipo = "permanente",
		beneficio = "Aumenta muito o dano causado",
		malefico = "Aumenta muito o dano recebido",
		vfx = "RACHADURA",
		stats = { DamageBoost = 0.06, DamageResistance = -0.06 },
	},
	{
		id = "frenesi",
		nome = "Frenesi",
		icone = "🔥",
		categoria = "Ataque",
		tipo = "permanente",
		beneficio = "Dano extra quando está com pouca vida",
		malefico = "Reduz a vida máxima",
		vfx = "CHAMA_RETRO",
		stats = { HPPercent = -0.02 },
		special = { lowHpDamage = 0.05, lowHpThreshold = 0.35 },
	},
	{
		id = "vampirico",
		nome = "Vampírico",
		icone = "🩸",
		categoria = "Ataque",
		tipo = "permanente",
		beneficio = "Cura parte do dano que causa",
		malefico = "Desliga a regeneração natural",
		vfx = "GOTA_SANGUE",
		special = { lifesteal = 0.02, noRegen = true },
	},
	{
		id = "duelista",
		nome = "Duelista",
		icone = "⚔️",
		categoria = "Ataque",
		tipo = "permanente",
		beneficio = "Dano extra contra nível MAIOR que o seu",
		malefico = "Dano reduzido contra nível MENOR",
		vfx = "FAISCA_LAMINA",
		special = { vsHigher = 0.06, vsLower = -0.04 },
	},
	{
		id = "executor",
		nome = "Executor",
		icone = "🪓",
		categoria = "Ataque",
		tipo = "permanente",
		beneficio = "Dano extra contra alvo ferido",
		malefico = "Dano reduzido contra alvo com vida cheia",
		vfx = "CORTE_VERMELHO",
		special = { vsFerido = 0.07, feridoThreshold = 0.40, vsCheio = -0.04 },
	},
	{
		id = "brutamontes",
		nome = "Brutamontes",
		icone = "🥊",
		categoria = "Ataque",
		tipo = "permanente",
		beneficio = "Muito mais dano corpo a corpo",
		malefico = "Muito menos dano à distância",
		vfx = "IMPACTO_PESADO",
		stats = { MeleeBoost = 0.08, RangedBoost = -0.06 },
	},
	{
		id = "arcanista",
		nome = "Arcanista",
		icone = "🔮",
		categoria = "Ataque",
		tipo = "permanente",
		beneficio = "Muito mais dano mágico",
		malefico = "Reduz a vida máxima",
		vfx = "RUNA_ROXA",
		stats = { MagicBoost = 0.08, HPPercent = -0.03 },
	},
	{
		id = "perfurante",
		nome = "Perfurante",
		icone = "🏹",
		categoria = "Ataque",
		tipo = "permanente",
		beneficio = "Ignora parte da resistência do alvo",
		malefico = "Reduz o dano bruto",
		vfx = "FLECHA_LUZ",
		stats = { MeleePierce = 0.05, RangedPierce = 0.05, DamageBoost = -0.02 },
	},

	-- ═══════════ UTILIDADE (permanentes) ═══════════

	{
		id = "sobrecarga",
		nome = "Sobrecarga",
		icone = "⚡",
		categoria = "Utilidade",
		tipo = "permanente",
		beneficio = "Regenera energia muito mais rápido",
		malefico = "Reduz a vida máxima",
		vfx = "RAIO_ELETRICO",
		stats = { HPPercent = -0.03 },
		special = { energyRegen = 0.10 },
	},
	{
		id = "bateria_fria",
		nome = "Bateria Fria",
		icone = "❄️",
		categoria = "Utilidade",
		tipo = "permanente",
		beneficio = "Regenera muita energia parado",
		malefico = "Não regenera nada em movimento",
		vfx = "CRISTAL_GELO",
		special = { idleBonus = 1.6, idleOnly = true },
	},
	{
		id = "reserva",
		nome = "Reserva Profunda",
		icone = "🔋",
		categoria = "Utilidade",
		tipo = "permanente",
		beneficio = "Aumenta muito a energia máxima",
		malefico = "Reduz a velocidade de regeneração",
		vfx = "PULSO_AZUL",
		special = { energyMax = 0.12, energyRegen = -0.05 },
	},
	{
		id = "leveza",
		nome = "Leveza",
		icone = "💨",
		categoria = "Utilidade",
		tipo = "permanente",
		beneficio = "Muito mais rápido e pula muito mais alto",
		malefico = "Reduz a vida máxima",
		vfx = "RASTRO_VENTO",
		stats = { WalkSpeedPercent = 0.05, JumpPercent = 0.06, HPPercent = -0.04 },
	},
	{
		id = "curandeiro",
		nome = "Curandeiro",
		icone = "💚",
		categoria = "Utilidade",
		tipo = "permanente",
		beneficio = "Recebe e dá muito mais cura",
		malefico = "Reduz o dano causado",
		vfx = "FOLHA_VERDE",
		stats = { IncomingHealing = 0.08, OutgoingHealing = 0.08, DamageBoost = -0.04 },
	},
	{
		id = "inabalavel",
		nome = "Inabalável",
		icone = "🗿",
		categoria = "Utilidade",
		tipo = "permanente",
		beneficio = "Resiste a ser desarmado e a efeitos",
		malefico = "Fica mais lento",
		vfx = "AURA_PEDRA",
		stats = { InterruptResist = 0.09, WalkSpeedPercent = -0.03 },
	},

	-- ═══════════ CHANCE (permanentes) ═══════════

	{
		id = "negador",
		nome = "Negador",
		icone = "🚫",
		categoria = "Chance",
		tipo = "permanente",
		beneficio = "Chance de ANULAR o dano por completo",
		malefico = "Reduz a vida máxima",
		vfx = "NEGACAO_BRANCA",
		chance = 0.03, -- por nível: 3% -> 30% no nível 10
		stats = { HPPercent = -0.03 },
		special = { negar = true },
	},
	{
		id = "reverso",
		nome = "Reverso",
		icone = "🔄",
		categoria = "Chance",
		tipo = "permanente",
		exclusivo = true, -- ocupa TODOS os slots
		beneficio = "Chance de DEVOLVER o dano ao agressor",
		malefico = "Ocupa todos os slots e reduz sua resistência",
		vfx = "ESPELHO_INVERTIDO",
		chance = 0.025, -- por nível: 2,5% -> 25% no nível 10
		stats = { DamageResistance = -0.03 },
		special = { reverter = true, reverterFracao = 0.10 },
	},

	-- ═══════════ TEMPORÁRIAS (com gatilho e recarga) ═══════════

	{
		id = "surto",
		nome = "Surto",
		icone = "🌀",
		categoria = "Temporária",
		tipo = "temporario",
		gatilho = "combate",
		duracao = 6,
		recarga = 26,
		beneficio = "Ao entrar em combate, ganha dano por alguns segundos",
		malefico = "Fica fraco enquanto recarrega",
		vfx = "ESPIRAL_CIANO",
		stats = { DamageBoost = 0.09 },
		statsRecarga = { DamageBoost = -0.02 },
	},
	{
		id = "ultimo_folego",
		nome = "Último Fôlego",
		icone = "💗",
		categoria = "Temporária",
		tipo = "temporario",
		gatilho = "vida_baixa",
		gatilhoThreshold = 0.25,
		duracao = 5,
		recarga = 60,
		beneficio = "Com vida crítica, fica quase imune por instantes",
		malefico = "Recarga muito longa",
		vfx = "CORACAO_DOURADO",
		stats = { DamageResistance = 0.07, WalkSpeedPercent = 0.03 },
	},
	{
		id = "contra_ataque",
		nome = "Contra-Ataque",
		icone = "↩️",
		categoria = "Temporária",
		tipo = "temporario",
		gatilho = "levar_dano",
		duracao = 3,
		recarga = 14,
		beneficio = "Ao levar dano, revida com força por 3s",
		malefico = "Fica exposto enquanto recarrega",
		vfx = "FLASH_LARANJA",
		stats = { DamageBoost = 0.11 },
		statsRecarga = { DamageResistance = -0.02 },
	},
	{
		id = "sede_sangue",
		nome = "Sede de Sangue",
		icone = "🍷",
		categoria = "Temporária",
		tipo = "temporario",
		gatilho = "causar_dano",
		duracao = 8,
		recarga = 10,
		beneficio = "Ao acertar, cresce em dano e velocidade",
		malefico = "Perde vida enquanto está ativa",
		vfx = "AURA_CARMESIM",
		stats = { DamageBoost = 0.05, WalkSpeedPercent = 0.03 },
		special = { drenoPorSeg = 0.4 },
	},
	{
		id = "adrenalina",
		nome = "Adrenalina",
		icone = "💉",
		categoria = "Temporária",
		tipo = "temporario",
		gatilho = "abate",
		duracao = 8,
		recarga = 4,
		beneficio = "Ao eliminar alguém, dispara velocidade e energia",
		malefico = "Ao morrer, perde XP do nível atual",
		vfx = "PULSO_AMARELO",
		stats = { WalkSpeedPercent = 0.05 },
		special = { killEnergy = 9, xpLoss = 0.03 },
	},
	{
		id = "fuga",
		nome = "Instinto de Fuga",
		icone = "🏃",
		categoria = "Temporária",
		tipo = "temporario",
		gatilho = "vida_baixa",
		gatilhoThreshold = 0.35,
		duracao = 5,
		recarga = 35,
		beneficio = "Com vida baixa, dispara em velocidade",
		malefico = "Causa muito menos dano enquanto foge",
		vfx = "RASTRO_VENTO",
		stats = { WalkSpeedPercent = 0.09, JumpPercent = 0.06, DamageBoost = -0.05 },
	},
}

--[[
════════════════════════════════════════════════════════════════
	FUNÇÕES DE CONSULTA
════════════════════════════════════════════════════════════════
]]

local porId = {}
for _, passiva in ipairs(Catalogo.LISTA) do
	porId[passiva.id] = passiva
end

function Catalogo.obter(id)
	return porId[id]
end

-- Valores JÁ multiplicados pelo nível
function Catalogo.statsNoNivel(id, nivel)
	local passiva = porId[id]
	if not passiva or not passiva.stats then
		return {}
	end

	nivel = math.clamp(math.floor(tonumber(nivel) or 1), 1, Catalogo.MAX_NIVEL)

	local resultado = {}
	for nome, valor in pairs(passiva.stats) do
		resultado[nome] = valor * nivel
	end
	return resultado
end

function Catalogo.statsRecargaNoNivel(id, nivel)
	local passiva = porId[id]
	if not passiva or not passiva.statsRecarga then
		return {}
	end

	nivel = math.clamp(math.floor(tonumber(nivel) or 1), 1, Catalogo.MAX_NIVEL)

	local resultado = {}
	for nome, valor in pairs(passiva.statsRecarga) do
		resultado[nome] = valor * nivel
	end
	return resultado
end

function Catalogo.specialNoNivel(id, nivel)
	local passiva = porId[id]
	if not passiva or not passiva.special then
		return {}
	end

	nivel = math.clamp(math.floor(tonumber(nivel) or 1), 1, Catalogo.MAX_NIVEL)

	local resultado = {}
	for nome, valor in pairs(passiva.special) do
		if type(valor) == "number" then
			-- Limiares NÃO escalam: "abaixo de 35% de vida" continua
			-- sendo 35% no nível 10. Escalar isso viraria "sempre ativo".
			if nome:find("Threshold") then
				resultado[nome] = valor
			else
				resultado[nome] = valor * nivel
			end
		else
			resultado[nome] = valor
		end
	end
	return resultado
end

function Catalogo.chanceNoNivel(id, nivel)
	local passiva = porId[id]
	if not passiva or not passiva.chance then
		return 0
	end
	nivel = math.clamp(math.floor(tonumber(nivel) or 1), 1, Catalogo.MAX_NIVEL)
	-- Teto de 50%: acima disso o combate vira loteria
	return math.min(0.50, passiva.chance * nivel)
end

-- Texto pronto pra tela, já no nível certo
function Catalogo.descricaoNoNivel(id, nivel)
	local passiva = porId[id]
	if not passiva then
		return ""
	end

	nivel = math.clamp(math.floor(tonumber(nivel) or 1), 1, Catalogo.MAX_NIVEL)

	local partes = {}

	local ROTULOS = {
		HPPercent = "Vida",
		HPFlat = "Vida",
		DamageBoost = "Dano",
		DamageResistance = "Resistência",
		DefenseFlat = "Defesa",
		WalkSpeedPercent = "Velocidade",
		JumpPercent = "Pulo",
		Shield = "Escudo",
		IncomingHealing = "Cura recebida",
		OutgoingHealing = "Cura dada",
		InterruptResist = "Resist. interrupção",
		MeleeBoost = "Dano corpo a corpo",
		RangedBoost = "Dano à distância",
		MagicBoost = "Dano mágico",
		MeleeResist = "Resist. corpo a corpo",
		MagicResist = "Resist. mágica",
		MeleePierce = "Perfuração",
		RangedPierce = "Perfuração",
	}

	local PLANOS = { DefenseFlat = true, Shield = true, HPFlat = true }

	for nome, valor in pairs(Catalogo.statsNoNivel(id, nivel)) do
		local rotulo = ROTULOS[nome] or nome
		if PLANOS[nome] then
			table.insert(partes, string.format("%s %+d", rotulo, math.floor(valor)))
		else
			table.insert(partes, string.format("%s %+.0f%%", rotulo, valor * 100))
		end
	end

	if passiva.chance then
		table.insert(partes, string.format("Chance %.0f%%", Catalogo.chanceNoNivel(id, nivel) * 100))
	end

	local especial = Catalogo.specialNoNivel(id, nivel)
	if especial.lifesteal then
		table.insert(partes, string.format("Roubo de vida %.0f%%", especial.lifesteal * 100))
	end
	if especial.lowHpDamage then
		table.insert(partes, string.format("Dano ferido %+.0f%%", especial.lowHpDamage * 100))
	end
	if especial.vsHigher then
		table.insert(partes, string.format("vs nível maior %+.0f%%", especial.vsHigher * 100))
	end
	if especial.energyRegen then
		table.insert(partes, string.format("Regen energia %+.0f%%", especial.energyRegen * 100))
	end
	if especial.energyMax then
		table.insert(partes, string.format("Energia máx %+.0f%%", especial.energyMax * 100))
	end

	table.sort(partes)

	local texto = table.concat(partes, " • ")

	if passiva.tipo == "temporario" then
		texto = string.format("%s  |  %ds ativo, %ds recarga", texto, passiva.duracao, passiva.recarga)
	end

	return texto
end

function Catalogo.contar()
	return #Catalogo.LISTA
end

return Catalogo
