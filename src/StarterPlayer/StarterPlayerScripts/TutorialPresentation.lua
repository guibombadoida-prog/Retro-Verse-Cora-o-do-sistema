-- Nome: TutorialPresentation
-- Coloque em: StarterPlayer > StarterPlayerScripts (ModuleScript)
-- V1 — matemática/paginação pura do tutorial; sem estado global ou rede.

local Presentation = {}

-- Solução analítica da mola criticamente amortecida: estável mesmo com FPS baixo.
function Presentation.spring(position, velocity, target, frequency, dt)
	dt = math.max(dt, 0)
	local offset = position - target
	local decay = math.exp(-frequency * dt)
	local impulse = velocity + frequency * offset
	return target + (offset + impulse * dt) * decay,
		(velocity - frequency * impulse * dt) * decay
end

function Presentation.layout(width, height)
	width, height = math.max(width, 1), math.max(height, 1)
	local portrait = width / height < 1.15
	return {
		portrait = portrait,
		width = portrait and 0.94 or math.clamp(1000 / width, 0.62, 0.92),
		height = portrait and 0.44 or math.clamp(280 / height, 0.34, 0.54),
		bottom = 0.97,
		-- Páginas curtas mantêm o Code legível sem reduzir o texto a poucos pixels.
		pageLimit = portrait and 140 or 180,
	}
end

-- Nunca corta bytes de uma palavra ou de um emoji. Parágrafos viram páginas
-- independentes; textos longos quebram somente nos espaços entre palavras.
function Presentation.pages(text, limit)
	limit = math.max(1, limit)
	local pages = {}
	for paragraph in (text .. "\n"):gmatch("([^\n]+)\n") do
		local current, length = "", 0
		for word in paragraph:gmatch("%S+") do
			local wordLength = utf8.len(word) or #word
			if length > 0 and length + 1 + wordLength > limit then
				table.insert(pages, current)
				current, length = "", 0
			end
			current = current == "" and word or current .. " " .. word
			length = (utf8.len(current) or #current)
		end
		if current ~= "" then
			table.insert(pages, current)
		end
	end
	if #pages == 0 then
		pages[1] = ""
	end
	return pages
end

function Presentation.characterDelay(grapheme, fast)
	local base = fast and 0.012 or 0.025
	if grapheme:match("[.!?]$") then
		return base + 0.17
	elseif grapheme:match("[,;:]$") then
		return base + 0.08
	end
	return base
end

-- Decisão testável: câmera cinematográfica é opcional e só assume no lobby.
function Presentation.canTakeCamera(state)
	return state.open and state.alive and state.safe and state.cameraAvailable
		and not state.foreignOwner and not state.scriptable
		and not state.reducedMotion and not state.vr
end

return Presentation
