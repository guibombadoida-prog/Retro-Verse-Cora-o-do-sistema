-- Executa o LocalScript real com dublês de serviços. Não simula renderização 3D.
-- CFrame simplificado testa posse/restauração, não valida enquadramento visual.
return function(source, presentation)
	local checks = 0
	local function check(value, message)
		assert(value, message)
		checks = checks + 1
	end
	local function signal()
		local slots = {}
		return {
			Connect = function(_, callback)
				local c = { Connected = true, callback = callback }
				function c:Disconnect() self.Connected = false end
				table.insert(slots, c)
				return c
			end,
			Fire = function(_, ...)
				for _, c in ipairs(table.clone(slots)) do if c.Connected then c.callback(...) end end
			end,
			Count = function()
				local n = 0
				for _, c in ipairs(slots) do if c.Connected then n = n + 1 end end
				return n
			end,
		}
	end
	local vec = {}
	local function vector(x, y, z) return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0 }, vec) end
	function vec.__add(a, b) return vector(a.X + b.X, a.Y + b.Y, a.Z + b.Z) end
	function vec.__sub(a, b) return vector(a.X - b.X, a.Y - b.Y, a.Z - b.Z) end
	function vec.__mul(a, b) return vector(a.X * b, a.Y * b, a.Z * b) end
	function vec.__index(v, k)
		if k == "Magnitude" then return math.sqrt(v.X ^ 2 + v.Y ^ 2 + v.Z ^ 2) end
		if k == "Lerp" then return function(a, b, t) return a + (b - a) * t end end
	end
	local cf = {}
	local function cframe(x, y, z)
		return setmetatable({ Position = type(x) == "table" and x or vector(x, y, z) }, cf)
	end
	function cf.__sub(a, b) return cframe(a.Position - b) end
	function cf.__mul(a, b) return cframe(a.Position + b.Position) end
	function cf.__index(_, k)
		if k == "VectorToWorldSpace" then return function(_, v) return v end end
		if k == "Lerp" then return function(a, b, t) return cframe(a.Position:Lerp(b.Position, t)) end end
	end
	local enums = setmetatable({}, { __index = function(t, k)
		local group = setmetatable({}, { __index = function(g, key)
			local v = { Name = key, Value = 100 }; rawset(g, key, v); return v
		end })
		rawset(t, k, group); return group
	end })
	local instanceMethods = {}
	local eventNames = { Activated = true, InputBegan = true, InputEnded = true, MouseEnter = true,
		MouseLeave = true, SelectionGained = true, SelectionLost = true, AncestryChanged = true,
		Died = true, CharacterAdded = true, CharacterRemoving = true, MenuOpened = true }
	local function create(class)
		local object = { _props = { ClassName = class, Name = class, Visible = true, Enabled = true,
			AbsoluteSize = vector(1280, 720), AbsolutePosition = vector(0, 0) },
			_children = {}, _attributes = {}, _signals = {} }
		return setmetatable(object, {
			__index = function(t, k)
				if instanceMethods[k] then return instanceMethods[k] end
				if eventNames[k] then
					if not t._signals[k] then t._signals[k] = signal() end
					return t._signals[k]
				end
				return t._props[k]
			end,
			__newindex = function(t, k, v)
				local old = t._props[k]
				if k == "Parent" and old ~= v then
					if old then
						local index = table.find(old._children, t)
						if index then table.remove(old._children, index) end
					end
					if v then table.insert(v._children, t) end
				end
				t._props[k] = v
				if old ~= v and t._signals[k .. "Changed"] then t._signals[k .. "Changed"]:Fire() end
				if k == "Parent" and old ~= v and t._signals.AncestryChanged then t._signals.AncestryChanged:Fire(t, v) end
			end,
		})
	end
	function instanceMethods:IsA(class)
		return self.ClassName == class or (class == "GuiObject" and
			(self.ClassName == "Frame" or self.ClassName == "TextLabel" or self.ClassName == "TextButton"))
	end
	function instanceMethods:FindFirstChild(name)
		for _, child in ipairs(self._children) do if child.Name == name then return child end end
	end
	function instanceMethods:WaitForChild(name) return self:FindFirstChild(name) end
	function instanceMethods:FindFirstChildOfClass(class)
		for _, child in ipairs(self._children) do if child:IsA(class) then return child end end
	end
	function instanceMethods:IsDescendantOf(parent)
		local current = self.Parent
		while current do if current == parent then return true end; current = current.Parent end
		return false
	end
	function instanceMethods:GetPropertyChangedSignal(key)
		local name = key .. "Changed"
		if not self._signals[name] then self._signals[name] = signal() end
		return self._signals[name]
	end
	function instanceMethods:SetAttribute(key, value) self._attributes[key] = value end
	function instanceMethods:GetAttribute(key) return self._attributes[key] end
	function instanceMethods:Play() self.Played = (self.Played or 0) + 1 end
	function instanceMethods:Stop() self.Stopped = true end
	local function child(parent, class, name)
		local object = create(class); object.Name = name; object.Parent = parent; return object
	end
	local function setup(options)
		options = options or {}
		local world = create("Workspace")
		local game = create("DataModel")
		world.Parent = game
		local player = child(game, "Player", "LocalPlayer")
		local gui = child(player, "PlayerGui", "PlayerGui")
		local scripts = child(player, "PlayerScripts", "PlayerScripts")
		local script = child(scripts, "LocalScript", "TutorialMenuClient_V2")
		child(scripts, "ModuleScript", "TutorialPresentation")
		local character = child(world, "Model", "Character")
		local humanoid = child(character, "Humanoid", "Humanoid"); humanoid.Health = 100
		local root = child(character, "Part", "HumanoidRootPart")
		root.Position, root.CFrame = vector(0, 10, 0), cframe(0, 10, 0)
		local tag = child(character, "BoolValue", "InSafeZone")
		if options.unsafe then tag.Parent = nil end
		player.Character = character
		local camera = child(world, "Camera", "Camera")
		camera.CFrame, camera.Focus = cframe(0, 14, 18), cframe(0, 10, 0)
		camera.CameraType, camera.CameraSubject = enums.CameraType.Custom, humanoid
		camera.ViewportSize, camera.FieldOfView = vector(1280, 720), 73
		if options.scriptable then camera.CameraType = enums.CameraType.Scriptable end
		world.CurrentCamera = camera
		local rep = child(game, "ReplicatedStorage", "ReplicatedStorage")
		local remotes = child(rep, "Folder", "Remotes")
		local progress = child(remotes, "RemoteFunction", "GetTutorialProgress")
		local complete = child(remotes, "RemoteEvent", "CompleteTutorial")
		local completed = 0
		complete.FireServer = function() completed = completed + 1 end
		progress.InvokeServer = function() return { shouldAutoShow = options.auto == true } end
		local callbacks, actions, timers, now = {}, {}, {}, 0
		local run = { Heartbeat = signal() }
		function run:BindToRenderStep(name, _, callback) callbacks[name] = callback end
		function run:UnbindFromRenderStep(name) callbacks[name] = nil end
		local input = { TouchEnabled = true, KeyboardEnabled = false, GamepadEnabled = false }
		local gs = create("GuiService"); gs.ReducedMotionEnabled = options.reduced == true; gs.MenuIsOpen = false
		local vr = create("VRService"); vr.VREnabled = false
		local context = {}
		function context:BindActionAtPriority(name, callback) actions[name] = callback end
		function context:UnbindAction(name) actions[name] = nil end
		local cancelled, rays = 0, 0
		local tween = {}
		function tween:Create(object, _, props)
			return { Play = function() for k, v in pairs(props) do object[k] = v end end,
				Cancel = function() cancelled = cancelled + 1 end }
		end
		world.Raycast = function() rays = rays + 1; return nil end
		local services = { Players = { LocalPlayer = player }, ReplicatedStorage = rep, TweenService = tween,
			RunService = run, UserInputService = input, GuiService = gs, ContextActionService = context,
			SoundService = child(game, "SoundService", "SoundService"), VRService = vr }
		game.GetService = function(_, name) return assert(services[name], name) end
		game.IsLoaded = function() return true end
		local function schedule(delay, callback)
			table.insert(timers, { at = now + delay, thread = coroutine.create(callback) })
		end
		local env = setmetatable({
			game = game, workspace = world, script = script, _G = { RegisterMenuCategory = function() end },
			Instance = { new = create }, Enum = enums, Vector2 = { new = vector }, Vector3 = { new = vector },
			CFrame = { new = cframe, lookAt = function(position) return cframe(position) end },
			Color3 = { new = vector, fromRGB = vector }, RaycastParams = { new = function() return {} end },
			UDim2 = { fromScale = function(x, y) return { X = { Scale = x, Offset = 0 }, Y = { Scale = y, Offset = 0 } } end },
			UDim = { new = function(scale, offset) return { Scale = scale, Offset = offset } end },
			TweenInfo = { new = function() return {} end }, require = function() return presentation end,
			os = { clock = function() return now end },
			task = { spawn = function(f) schedule(0, f) end, delay = schedule,
				wait = function(delay) return coroutine.yield(delay or 0.03) end },
			print = function() end, warn = function() end,
		}, { __index = getfenv() })
		-- Luau CLI não inclui utf8.graphemes, que é uma extensão do motor Roblox.
		-- Dublê por codepoint verifica texto imutável; Unicode real é validado no motor.
		local u8 = table.clone(utf8)
		u8.graphemes = function(str)
			local positions = {}
			for byte in utf8.codes(str) do table.insert(positions, byte) end
			local i = 0
			return function()
				i = i + 1
				if positions[i] then return positions[i], (positions[i + 1] or (#str + 1)) - 1 end
			end
		end
		env.utf8 = u8
		local client = assert(loadstring(source, "TutorialMenuClient_V2"))
		setfenv(client, env)
		client()
		local function step(dt)
			now = now + dt
			for i = #timers, 1, -1 do
				local t = timers[i]
				if t.at <= now then
					table.remove(timers, i)
					local ok, delay = coroutine.resume(t.thread)
					assert(ok, delay)
					if coroutine.status(t.thread) ~= "dead" then
						t.at = now + (delay or 0.03); table.insert(timers, t)
					end
				end
			end
			for _, callback in pairs(table.clone(callbacks)) do callback(dt) end
			run.Heartbeat:Fire(dt)
		end
		local function find(name)
			local function walk(object)
				if object.Name == name then return object end
				for _, c in ipairs(object._children) do local found = walk(c); if found then return found end end
			end
			return assert(walk(gui), "GUI não encontrada: " .. name)
		end
		return { env = env, camera = camera, world = world, player = player, humanoid = humanoid, root = root,
			step = step, find = find, tag = tag, gs = gs, script = script,
			stats = function() return completed, run.Heartbeat.Count(), next(callbacks) ~= nil, next(actions) ~= nil, cancelled, rays end }
	end
	local t = setup()
	local originalFrame, originalFocus = t.camera.CFrame, t.camera.Focus
	t.env._G.OpenTutorialMenu()
	t.step(1 / 60)
	local completed, heartbeat, rendering, locked, cancelled, rays = t.stats()
	check(rendering and locked and heartbeat == 1, "uma câmera e um loop ao abrir")
	check(rays > 0, "enquadramento usa raycast")
	check(t.camera.CameraType == enums.CameraType.Scriptable, "câmera cinematográfica")
	local dialogue = t.find("DialogText")
	local entireText = dialogue.Text
	for _ = 1, 12 do t.step(1 / 60) end
	check(dialogue.Text == entireText and dialogue.MaxVisibleGraphemes > 0, "typewriter mantém texto/layout inteiros")
	t.find("Next").Activated:Fire()
	check(dialogue.Text == entireText and dialogue.MaxVisibleGraphemes == -1, "primeiro avanço revela sem pular")
	t.find("Next").Activated:Fire()
	check(dialogue.Text ~= entireText, "segundo avanço troca página")
	t.env._G.CloseTutorialMenu()
	check(t.camera.CameraType == enums.CameraType.Custom and t.camera.FieldOfView == 73, "tipo/FOV restaurados")
	check(t.camera.CFrame == originalFrame and t.camera.Focus == originalFocus, "CFrame/Focus restaurados")
	local _, h, render, lock = t.stats()
	check(h == 0 and not render and not lock, "fechar remove loops e bloqueios")
	t.env._G.OpenTutorialMenu()
	t.step(0.4)
	check(t.find("TutorialMenuV4").Enabled, "close antigo não esconde reabertura")
	for _ = 1, 20 do t.env._G.CloseTutorialMenu(); t.env._G.OpenTutorialMenu() end
	local _, h2 = t.stats()
	check(h2 == 1, "20 reaberturas não duplicam Heartbeat")
	t.find("Motion").Activated:Fire()
	local _, _, render2, lock2 = t.stats()
	check(not render2 and not lock2, "movimento reduzido devolve câmera")
	t.find("Motion").Activated:Fire()
	t.tag.Parent = nil
	t.step(1 / 60)
	local _, _, render3, lock3 = t.stats()
	check(not render3 and not lock3, "sair da zona segura devolve câmera")
	t.find("Skip").Activated:Fire(); t.find("Skip").Activated:Fire()
	check(t.stats() == 1, "conclusão enviada uma vez")
	t.env._G.OpenTutorialMenu()
	t.find("TutorialMenuV4").Enabled = false
	local _, _, render4, lock4 = t.stats()
	check(not render4 and not lock4, "GUI desabilitada não prende câmera")
	t.env._G.OpenTutorialMenu()
	t.script.Parent = nil
	check(t.env._G.OpenTutorialMenu == nil, "teardown limpa API própria")
	check(t.stats() == 1, "teardown não concede recompensa")
	local _, _, _, _, cancelledTotal = t.stats()
	check(cancelledTotal > 0, "tweens anteriores cancelados")

	for _, options in ipairs({ { unsafe = true }, { reduced = true }, { scriptable = true } }) do
		local isolated = setup(options)
		isolated.env._G.OpenTutorialMenu(); isolated.step(0.02)
		local _, _, takesCamera, takesControls = isolated.stats()
		check(not takesCamera and not takesControls, "recusa câmera insegura/reduzida/ocupada")
		isolated.env._G.CloseTutorialMenu(true)
	end
	local dying = setup(); dying.env._G.OpenTutorialMenu()
	dying.humanoid.Health = 0; dying.humanoid.Died:Fire()
	local _, _, deathCamera, deathControls = dying.stats()
	check(not deathCamera and not deathControls, "morte libera câmera e controles")
	local foreign = setup(); foreign.env._G.OpenTutorialMenu()
	foreign.camera:SetAttribute("RetroVerseCameraOwner", "OutraCutscene")
	foreign.camera.FieldOfView = 82; foreign.step(0.02)
	check(foreign.camera.FieldOfView == 82, "não sobrescreve outra cutscene")
	local loading = setup({ auto = true })
	local pg = loading.player:FindFirstChild("PlayerGui")
	local screen = child(pg, "ScreenGui", "LoadingScreen")
	loading.step(0.02)
	check(not loading.find("TutorialMenuV4").Enabled, "auto-show espera LoadingScreen")
	screen.Parent = nil; loading.step(0.4)
	check(loading.find("TutorialMenuV4").Enabled, "auto-show após carregamento")
	loading.env._G.CloseTutorialMenu(true)
	local tour = setup(); tour.env._G.OpenTutorialMenu()
	local firstPage = tour.find("DialogText").Text
	tour.camera.ViewportSize = vector(360, 800)
	check(tour.find("DialogText").Text == firstPage, "rotação preserva página")
	check(tour.find("DialogFrame").Size.X.Scale <= 0.94, "retrato preserva margens")
	local visits, clicks = {}, 0
	while tour.find("TutorialMenuV4").Enabled and clicks < 400 do
		visits[tour.find("StepCounter").Text] = true
		tour.find("Next").Activated:Fire()
		tour.step(0.3)
		clicks = clicks + 1
	end
	local total = 0
	for _ in pairs(visits) do total = total + 1 end
	check(total == 24, "24 etapas alcançáveis sem texto vazio")
	check(tour.stats() == 1 and clicks < 400, "tour completo conclui uma vez")
	local replaced = setup(); replaced.env._G.OpenTutorialMenu()
	local replacement = child(replaced.world, "Camera", "Replacement")
	replacement.ViewportSize = vector(800, 360)
	replacement.CameraType, replacement.FieldOfView = enums.CameraType.Custom, 81
	replaced.world.CurrentCamera = replacement
	local _, _, replaceRender, replaceLock = replaced.stats()
	check(not replaceRender and not replaceLock, "troca de câmera remove render e trava")
	check(replacement.FieldOfView == 81, "nova câmera permanece intacta")
	print(string.format("TutorialMenuClient V8: %d regressões de ciclo de vida passaram", checks))
end
