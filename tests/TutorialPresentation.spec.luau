local P = require("../src/StarterPlayer/StarterPlayerScripts/TutorialPresentation")
local checked = 0
local function check(value, message)
	assert(value, message)
	checked = checked + 1
end
local function near(a, b)
	return math.abs(a - b) < 0.00001
end

for _, fps in ipairs({ 15, 30, 60, 120, 240 }) do
	local x, v = 0.94, 0
	for _ = 1, fps do
		x, v = P.spring(x, v, 1, 16, 1 / fps)
		check(x == x and v == v, "mola finita")
	end
	local directX, directV = P.spring(0.94, 0, 1, 16, 1)
	check(near(x, directX) and near(v, directV), "mola independente de FPS")
end
local x, v = P.spring(1, 2, 1, 16, 8)
check(near(x, 1) and near(v, 0), "recuperação após frame muito longo")
local still, velocity = P.spring(0.9, 0.1, 1, 16, -1)
check(near(still, 0.9) and near(velocity, 0.1), "dt negativo não volta no tempo")

for _, size in ipairs({ { 360, 800 }, { 800, 360 }, { 640, 360 }, { 2048, 921 }, { 768, 1024 }, { 320, 568 }, { 1, 1 } }) do
	local l = P.layout(size[1], size[2])
	check(l.width > 0 and l.width <= 0.94, "painel dentro da largura")
	check(l.height > 0 and l.height < l.bottom, "painel dentro da altura")
	check(l.bottom < 1, "margem inferior preservada")
end

local input = "Olá, criação! 😮‍💨\n\nGuia: ação, defesa e energia.\nAcento combinado: á. Mais um texto para dividir."
local pages = P.pages(input, 24)
check(#pages > 2, "paginação de texto longo")
check(table.concat(pages, " "):gsub("%s+", " ") == input:gsub("%s+", " "), "nenhuma palavra perdida")
for _, page in ipairs(pages) do
	check(utf8.len(page) ~= nil, "nenhum UTF-8 cortado")
	check(utf8.len(page) <= 24, "limite de página respeitado")
end
check(#P.pages("", 10) == 1, "texto vazio produz página segura")
check(P.pages("😮‍💨", 1)[1] == "😮‍💨", "emoji longo não é cortado")
check(P.characterDelay(".", false) > P.characterDelay("a", false), "pausa em pontuação")
check(P.characterDelay("a", true) < P.characterDelay("a", false), "velocidade rápida")

local state = { open = true, alive = true, safe = true, cameraAvailable = true,
	foreignOwner = false, scriptable = false, reducedMotion = false, vr = false }
check(P.canTakeCamera(state), "câmera assume somente no caso seguro")
for _, flag in ipairs({ "open", "alive", "safe", "cameraAvailable" }) do
	state[flag] = false
	check(not P.canTakeCamera(state), "câmera recusada: " .. flag)
	state[flag] = true
end
for _, flag in ipairs({ "foreignOwner", "scriptable", "reducedMotion", "vr" }) do
	state[flag] = true
	check(not P.canTakeCamera(state), "câmera respeita: " .. flag)
	state[flag] = false
end
print(string.format("TutorialPresentation: %d verificações passaram", checked))
