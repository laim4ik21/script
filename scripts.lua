--[[
	============================================================
	Obsidian UI
	Вкладки: Visuals · Combat · Misc · UI Settings
	Библиотека: github.com/deividcomsono/Obsidian
	Доки:       https://docs.mspaint.cc/obsidian
	============================================================
]]

--// ---------------- Services ----------------
local Players          = game:GetService("Players")
local Workspace        = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")
local RunService       = game:GetService("RunService")
local PathfindingService = game:GetService("PathfindingService")

-- в обычном Roblox такого сервиса нет, он есть только в исполнителях
local okVim, vimService = pcall(function()
	return game:GetService("VirtualInputManager")
end)
local VirtualInputManager = okVim and vimService or nil

local LocalPlayer = Players.LocalPlayer

local function GetCamera()
	return Workspace.CurrentCamera
end

local HAS_DRAWING = (type(Drawing) == "table")

-- Заполняются после загрузки библиотеки (см. ниже). Объявлены заранее, чтобы
-- функции модулей захватывали эти локальные переменные, а не глобалы.
local Options, Toggles

--// ---------------- Config ----------------
local CFG = {
	ChamsColor       = Color3.fromRGB(255, 0, 0),    -- цвет чамсов
	OutlineColor     = Color3.fromRGB(255, 255, 255),
	FillTransparency = 0.5,
	NameTextColor    = Color3.fromRGB(255, 255, 255),
	DoorColor        = Color3.fromRGB(255, 140, 0),
	DoorTextColor    = Color3.fromRGB(255, 50, 50),
	ReadyColor       = Color3.fromRGB(80, 255, 80),
	LockedColor      = Color3.fromRGB(255, 50, 50),
	PromptDistance   = 50,                           -- MaxActivationDistance в режиме instant
	DoorEspDistance  = 500,
	TimerColor       = Color3.fromRGB(255, 200, 60),  -- цвет отсчёта таймера дверей
	FlySpeedMax      = 100,   -- максимальная скорость флая, одна для всех
	TeleportBehind   = 3.5,   -- сколько студов за спиной цели
	TeleportSpeed    = 55,    -- студов в секунду при плавном перемещении
	TeleportRange    = 250,   -- макс. дистанция до цели
	-- Подмена ника в ESP: видят все юзеры скрипта. Настоящий ник/DisplayName в Roblox не меняются.
	-- Пример: DisplayNames = { ["x1x1x1x281"] = "новый ник" }
	DisplayNames     = {},
}

--// ---------------- Модуль: чамсы + ники ----------------
local Esp = {
	chams    = false,
	names    = false,
	registry = {},   -- [player] = entry
	conns    = {},
}

-- Ник в нижний регистр: string.lower не трогает кириллицу, поэтому руками (А-Я -> а-я, Ё -> ё)
local function normName(value)
	if type(value) ~= "string" then return "" end

	local name = value:gsub("^%s+", ""):gsub("%s+$", ""):lower()
	name = name:gsub("\208([\144-\175])", function(b)
		local n = b:byte()
		if n < 160 then
			return "\208" .. string.char(n + 32)
		end
		return "\209" .. string.char(n - 32)
	end)
	name = name:gsub("\208\129", "\209\145")

	return name
end

-- Ник для ESP: сначала подмена из CFG.DisplayNames, иначе обычный DisplayName
local function displayNameOf(player)
	if not player then return "" end

	for _, candidate in ipairs({ player.Name, player.DisplayName }) do
		local key = normName(candidate)
		for real, shown in pairs(CFG.DisplayNames) do
			if key ~= "" and key == normName(real) then
				return shown
			end
		end
	end

	local shown = player.DisplayName
	return (shown ~= nil and shown ~= "") and shown or player.Name
end

-- Ограничение скорости одно для всех, никаких привилегий по нику
local FLY_SPEED_MAX = CFG.FlySpeedMax

local function ensureEntry(player)
	local entry = Esp.registry[player]
	if entry then return entry end

	entry = { player = player, highlight = nil, drawing = nil }

	if HAS_DRAWING then
		local text = Drawing.new("Text")
		text.Visible = false
		text.Size = 16
		text.Center = true
		text.Outline = true
		text.Color = CFG.NameTextColor
		entry.drawing = text
	end

	Esp.registry[player] = entry
	return entry
end

local function destroyHighlight(entry)
	if entry.highlight then
		if entry.highlight.Parent then
			entry.highlight:Destroy()
		end
		entry.highlight = nil
	end
end

local function setupHighlight(entry)
	destroyHighlight(entry)
	if not Esp.chams then return end

	local character = entry.player.Character
	if not character then return end
	if not character:FindFirstChildOfClass("Humanoid") then return end

	local highlight = Instance.new("Highlight")
	highlight.Name = "ObsidianChams"
	highlight.Adornee = character
	highlight.FillColor = CFG.ChamsColor
	highlight.OutlineColor = CFG.OutlineColor
	highlight.FillTransparency = CFG.FillTransparency
	highlight.OutlineTransparency = 0
	highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	highlight.Parent = character

	entry.highlight = highlight
end

local function syncChams()
	if not Esp.chams then return end

	for _, entry in pairs(Esp.registry) do
		local character = entry.player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")

		if character and humanoid and humanoid.Health > 0 then
			local highlight = entry.highlight
			if not highlight or not highlight.Parent or highlight.Adornee ~= character then
				setupHighlight(entry)
			end
		elseif entry.highlight then
			destroyHighlight(entry)
		end
	end
end

local function bindPlayer(player)
	if player == LocalPlayer then return end

	local entry = ensureEntry(player)

	if not entry.charConn then
		entry.charConn = player.CharacterAdded:Connect(function()
			setupHighlight(entry)
		end)
	end
	if not entry.removeConn then
		entry.removeConn = player.CharacterRemoving:Connect(function()
			destroyHighlight(entry)
		end)
	end

	setupHighlight(entry)
end

local function unbindPlayer(player)
	local entry = Esp.registry[player]
	if not entry then return end

	if entry.charConn then entry.charConn:Disconnect() end
	if entry.removeConn then entry.removeConn:Disconnect() end

	destroyHighlight(entry)
	if entry.drawing then
		entry.drawing:Remove()
	end

	Esp.registry[player] = nil
end

local function updateNames()
	if not Esp.names then return end

	local camera = GetCamera()
	if not camera then return end

	for player, entry in pairs(Esp.registry) do
		local text = entry.drawing
		if text then
			local character = player.Character
			local head = character and character:FindFirstChild("Head")
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")

			if head and humanoid and humanoid.Health > 0 then
				local screenPos, onScreen = camera:WorldToViewportPoint(head.Position + Vector3.new(0, 1.2, 0))
				if onScreen then
					text.Visible = true
					text.Text = ("%s [%dHP]"):format(displayNameOf(player), math.floor(humanoid.Health))
					text.Position = Vector2.new(screenPos.X, screenPos.Y)
				else
					text.Visible = false
				end
			else
				text.Visible = false
			end
		end
	end
end

function Esp:SetChams(state)
	self.chams = state
	for _, entry in pairs(self.registry) do
		if state then
			setupHighlight(entry)
		else
			destroyHighlight(entry)
		end
	end
end

function Esp:SetNames(state)
	self.names = state
	if not state then
		for _, entry in pairs(self.registry) do
			if entry.drawing then
				entry.drawing.Visible = false
			end
		end
	end
end

function Esp:Start()
	for _, player in ipairs(Players:GetPlayers()) do
		bindPlayer(player)
	end

	table.insert(self.conns, Players.PlayerAdded:Connect(bindPlayer))
	table.insert(self.conns, Players.PlayerRemoving:Connect(unbindPlayer))

	self.renderConn = RunService.RenderStepped:Connect(updateNames)

	self.active = true
	task.spawn(function()
		while Esp.active do
			task.wait(0.5)
			syncChams()
		end
	end)
end

function Esp:Stop()
	self.active = false
	self.chams = false
	self.names = false

	for _, conn in ipairs(self.conns) do
		if conn and conn.Connected then conn:Disconnect() end
	end
	table.clear(self.conns)

	if self.renderConn then
		self.renderConn:Disconnect()
		self.renderConn = nil
	end

	for player in pairs(self.registry) do
		unbindPlayer(player)
	end
end

local Teleport   -- модуль телепорта объявлен ниже: аимботу нужен его флаг busy

--// ---------------- Модуль: аимбот ----------------
local Aimbot = {
	enabled    = false,
	fov        = 150,
	yOffset    = 28,
	smoothness = 45,    -- 0 = мгновенное прилипание, 95 = очень плавно
	strength   = 100,   -- сколько процентов пути к цели доводит аим
	target     = nil,
	lastTarget = nil,   -- последняя цель: её держит телепорт-следование
	circle     = nil,
	conn       = nil,
}

local function getAimPoint()
	local mouse = UserInputService:GetMouseLocation()
	return Vector2.new(mouse.X, mouse.Y + Aimbot.yOffset)
end

local function isValidTarget(player)
	if not player or player == LocalPlayer then return false end

	local character = player.Character
	if not character then return false end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root then return false end

	return humanoid.Health > 0
end

local function findClosestTarget(centre)
	local camera = GetCamera()
	if not camera then return nil end

	local best, bestDistance = nil, Aimbot.fov

	for _, player in ipairs(Players:GetPlayers()) do
		if isValidTarget(player) then
			local screenPos, onScreen = camera:WorldToViewportPoint(player.Character.HumanoidRootPart.Position)
			if onScreen then
				local distance = (Vector2.new(screenPos.X, screenPos.Y) - centre).Magnitude
				if distance <= bestDistance then
					best, bestDistance = player, distance
				end
			end
		end
	end

	return best
end

local function aimStep()
	-- во время телепорта не трогаем CFrame: две записи в один кадр дерутся между собой
	if Teleport and Teleport.busy then return end

	local centre = getAimPoint()

	if Aimbot.circle then
		Aimbot.circle.Position = centre
		Aimbot.circle.Radius = Aimbot.fov
		Aimbot.circle.Visible = Aimbot.enabled
	end

	if not Aimbot.enabled then
		Aimbot.target = nil
		return
	end

	local holding = Options.AimKey and Options.AimKey:GetState()
	if not holding then
		Aimbot.target = nil
		return
	end

	if not isValidTarget(Aimbot.target) then
		Aimbot.target = findClosestTarget(centre)
	end

	local target = Aimbot.target
	if not target then return end

	-- залипание: пока цель жива, аим её не меняет; запоминаем её для телепорта
	Aimbot.lastTarget = target

	local character = LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then return end

	local targetPos = target.Character.HumanoidRootPart.Position
	local lookPos = Vector3.new(targetPos.X, root.Position.Y, targetPos.Z)
	-- плавность: при smoothness = 0 ведёт себя как раньше, мгновенно
	local alpha = math.clamp(1 - Aimbot.smoothness / 100, 0.02, 1)

	-- сила считается от взгляда камеры (мыши), а не от текущего CFrame: иначе
	-- поворот каждый кадр подтягивался бы до полного наведения сам по себе
	local camera = GetCamera()
	local basePoint = camera and (camera.CFrame.Position + camera.CFrame.LookVector * 50) or lookPos
	local aimPoint = basePoint:Lerp(lookPos, Aimbot.strength / 100)

	root.CFrame = root.CFrame:Lerp(CFrame.lookAt(root.Position, aimPoint), alpha)
end

function Aimbot:Init()
	if HAS_DRAWING then
		local circle = Drawing.new("Circle")
		circle.Visible = false
		circle.Radius = self.fov
		circle.Thickness = 3
		circle.Color = Color3.fromRGB(255, 255, 255)
		circle.Filled = false
		circle.Transparency = 1
		self.circle = circle
	end

	self.conn = RunService.RenderStepped:Connect(aimStep)
end

function Aimbot:SetEnabled(state)
	self.enabled = state
	if not state then
		self.target = nil
	end
end

function Aimbot:Stop()
	self.enabled = false
	self.target = nil

	if self.conn then
		self.conn:Disconnect()
		self.conn = nil
	end

	if self.circle then
		self.circle:Remove()
		self.circle = nil
	end
end

--// ---------------- Модуль: промпты и двери ----------------
local Prompts = {
	instant = false,
	esp     = false,
	cache   = {},   -- [prompt] = { hold, distance, lineOfSight, visual }
	conn    = nil,
}

local function isDoorName(target, model)
	local name = string.lower(target.Name)
	if model then
		name = name .. " " .. string.lower(model.Name)
	end

	return string.find(name, "door") ~= nil
		or string.find(name, "trick") ~= nil
		or string.find(name, "treat") ~= nil
end

local function resolveDoorTarget(prompt)
	local parent = prompt.Parent
	if not parent then return nil end

	local model = parent:IsA("Model") and parent or parent:FindFirstAncestorOfClass("Model")
	local target = model or parent

	if target:FindFirstChildWhichIsA("Humanoid") then return nil end
	if not isDoorName(target, model) then return nil end

	return target
end

local function createDoorVisual(target)
	local highlight = Instance.new("Highlight")
	highlight.Name = "ObsidianDoorESP"
	highlight.Adornee = target
	highlight.FillColor = CFG.DoorColor
	highlight.FillTransparency = 0.5
	highlight.OutlineColor = CFG.DoorColor
	highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	highlight.Parent = target

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "ObsidianDoorLabel"
	billboard.Adornee = target
	billboard.Size = UDim2.new(0, 150, 0, 50)
	billboard.StudsOffset = Vector3.new(0, 4, 0)
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = CFG.DoorEspDistance
	billboard.Parent = target

	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.TextColor3 = CFG.DoorTextColor
	label.Font = Enum.Font.GothamBold
	label.TextSize = 24
	label.TextStrokeTransparency = 0
	label.Text = ""
	label.Parent = billboard

	return { highlight = highlight, billboard = billboard, label = label }
end

local function destroyDoorVisual(visual)
	if visual.highlight and visual.highlight.Parent then
		visual.highlight:Destroy()
	end
	if visual.billboard and visual.billboard.Parent then
		visual.billboard:Destroy()
	end
end

local TIME_WORDS  = { "cool", "timer", "countdown", "remain", "wait", "timeleft" }
local TIME_SKIP_WORDS = { "duration", "total", "max", "min", "count", "amount", "used", "length", "speed", "delay", "interval", "rate" }
local READY_WORDS = { "unlock", "ready", "avail", "open" }
local LOCKED_WORDS = { "lock", "used", "busy", "block" }
local TEXT_LOCK_WORDS = { "lock", "wait", "cool", "later" }

local function matchAny(text, list)
	for _, word in ipairs(list) do
		if string.find(text, word, 1, true) then
			return true
		end
	end
	return false
end

local function formatTime(seconds)
	seconds = math.floor(seconds + 0.5)
	if seconds >= 60 then
		return ("WAIT %d:%02d"):format(math.floor(seconds / 60), seconds % 60)
	end
	return ("WAIT %ds"):format(seconds)
end

-- Приводим значение к секундам: число, "12", "0:12", "12s"
local function toSeconds(value)
	if typeof(value) == "number" then
		return value
	end

	if typeof(value) == "string" then
		local minutes, secs = string.match(value, "(%d+):(%d%d)")
		if minutes then
			return tonumber(minutes) * 60 + tonumber(secs)
		end
		return tonumber(string.match(value, "^%s*(%d+%.?%d*)"))
	end

	return nil
end

-- Берём значение, которое РЕАЛЬНО уменьшается, а не статичное Cooldown/Duration
local function chooseSeconds(entry, candidates)
	local ticking, smallest = nil, nil

	for name, value in pairs(candidates) do
		if value > 0 then
			local previous = entry.timerMemory and entry.timerMemory[name]
			if previous and value < previous - 0.01 then
				if not ticking or value < ticking then
					ticking = value
				end
			end
			if not smallest or value < smallest then
				smallest = value
			end
		end
	end

	entry.timerMemory = candidates

	return ticking or smallest
end

-- Состояние двери: таймер / флаг блокировки / текст промпта / сам промпт
local function doorStatus(entry, prompt, target)
	local candidates, boolValue, boolReady = {}, nil, nil

	local function readValue(name, value, prefix)
		local key = string.lower(name)

		if typeof(value) == "boolean" then
			if matchAny(key, READY_WORDS) then
				boolValue, boolReady = value, true
			elseif matchAny(key, LOCKED_WORDS) then
				boolValue, boolReady = value, false
			end
			return
		end

		if matchAny(key, TIME_SKIP_WORDS) or not matchAny(key, TIME_WORDS) then
			return
		end

		local value_seconds = toSeconds(value)
		if value_seconds then
			candidates[prefix .. key] = value_seconds
		end
	end

	for _, holder in ipairs({ prompt, target }) do
		if holder then
			for name, value in pairs(holder:GetAttributes()) do
				readValue(name, value, "a:")
			end

			-- Вложенные значения: Door/Cooldown, Door/Values/Time и т.п. (до 3 уровней)
			local queue = { { holder, 0 } }
			while #queue > 0 do
				local item = table.remove(queue, 1)
				local node, depth = item[1], item[2]

				for _, child in ipairs(node:GetChildren()) do
					if child:IsA("NumberValue") or child:IsA("IntValue") or child:IsA("StringValue") or child:IsA("BoolValue") then
						readValue(child.Name, child.Value, "v:")
					elseif (child:IsA("Model") or child:IsA("Folder")) and depth < 2 then
						table.insert(queue, { child, depth + 1 })
					end
				end
			end
		end
	end

	-- Таймер, который игра сама рисует на двери (TextLabel "0:12" / "12")
	if target and not prompt.Enabled then
		for _, obj in ipairs(target:GetDescendants()) do
			if obj:IsA("TextLabel") and obj.Visible then
				local text = obj.Text
				local minutes, secs = string.match(text, "(%d+):(%d%d)")
				local value

				if minutes then
					value = tonumber(minutes) * 60 + tonumber(secs)
				elseif string.find(text, "^%s*%d+%s*$") then
					value = tonumber(text)
				end

				if value and value > 0 then
					candidates.gui = math.max(candidates.gui or 0, value)
				end
			end
		end
	end

	-- Текст самой игры ("0:52") точнее любезно лежащих в атрибутах статичных 90
	local seconds = candidates.gui or chooseSeconds(entry, candidates) or 0

	if seconds > 0 then
		return formatTime(seconds), CFG.LockedColor, seconds
	end

	if boolValue ~= nil then
		if boolReady then
			return boolValue and "READY" or "LOCKED", boolValue and CFG.ReadyColor or CFG.LockedColor, 0
		end
		return boolValue and "LOCKED" or "READY", boolValue and CFG.LockedColor or CFG.ReadyColor, 0
	end

	local hint = string.lower(tostring(prompt.ActionText or "") .. " " .. tostring(prompt.ObjectText or ""))
	if matchAny(hint, TEXT_LOCK_WORDS) then
		return "LOCKED", CFG.LockedColor, 0
	end

	if prompt.Enabled then
		return "READY", CFG.ReadyColor, 0
	end

	return "LOCKED", CFG.LockedColor, 0
end

local function refreshDoorLabels()
	for prompt, entry in pairs(Prompts.cache) do
		-- pcall: удалённая дверь/промпт иначе убивает весь цикл обновления (метка «замирала»)
		pcall(function()
			local visual, target = entry.visual, entry.target
			if not visual or not target or not visual.label or not visual.label.Parent then
				return
			end

			local text, color = doorStatus(entry, prompt, target)
			if visual.label.Text ~= text then
				visual.label.Text = text
			end
			if visual.label.TextColor3 ~= color then
				visual.label.TextColor3 = color
			end
		end)
	end
end

local function applyPrompt(prompt)
	if not prompt.Parent then
		Prompts.cache[prompt] = nil
		return
	end

	local entry = Prompts.cache[prompt]
	if not entry then
		entry = {
			hold        = prompt.HoldDuration,
			distance    = prompt.MaxActivationDistance,
			lineOfSight = prompt.RequiresLineOfSight,
		}
		Prompts.cache[prompt] = entry
	end

	if Prompts.instant then
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = CFG.PromptDistance
		prompt.RequiresLineOfSight = false
	else
		prompt.HoldDuration = entry.hold
		prompt.MaxActivationDistance = entry.distance
		prompt.RequiresLineOfSight = entry.lineOfSight
	end

	local target = resolveDoorTarget(prompt)
	if not target then return end

	if Prompts.esp then
		if not entry.visual then
			entry.visual = createDoorVisual(target)
		end
		entry.target = target
		entry.visual.highlight.Enabled = true
		entry.visual.billboard.Enabled = true
	elseif entry.visual then
		entry.visual.highlight.Enabled = false
		entry.visual.billboard.Enabled = false
	end
end

local function refreshAllPrompts()
	for prompt in pairs(Prompts.cache) do
		applyPrompt(prompt)
	end
end

function Prompts:SetInstant(state)
	self.instant = state
	refreshAllPrompts()
end

function Prompts:SetEsp(state)
	self.esp = state
	refreshAllPrompts()
end

function Prompts:Start()
	for _, descendant in ipairs(Workspace:GetDescendants()) do
		if descendant:IsA("ProximityPrompt") then
			applyPrompt(descendant)
		end
	end

	self.conn = Workspace.DescendantAdded:Connect(function(descendant)
		if descendant:IsA("ProximityPrompt") then
			task.defer(applyPrompt, descendant)
		end
	end)

	self.active = true
	task.spawn(function()
		while Prompts.active do
			task.wait(0.25)
			if Prompts.esp then
				pcall(refreshDoorLabels)
			end
		end
	end)
end

function Prompts:Stop()
	self.active = false
	self.instant = false
	self.esp = false

	if self.conn then
		self.conn:Disconnect()
		self.conn = nil
	end

	for prompt in pairs(self.cache) do
		applyPrompt(prompt)
	end

	for _, entry in pairs(self.cache) do
		if entry.visual then
			destroyDoorVisual(entry.visual)
			entry.visual = nil
		end
	end

	table.clear(self.cache)
end

--// ---------------- Модуль: таймеры дверей ----------------
-- Дверь во время кулдауна остаётся на месте и сама пишет на себе «0:52».
-- Модуль читает этот таймер и показывает его крупно над дверью, чтобы были
-- видны секунды до открытия, а не только метка WAIT.
local DoorTimers = {
	enabled = false,
	active  = false,
	entries = {},   -- [prompt] = { pos, readyAt, timerMemory, text }
	conn    = nil,
}

local function makeDoorTimerText()
	if not HAS_DRAWING then return nil end

	local text = Drawing.new("Text")
	text.Visible = false
	text.Size = 16
	text.Center = true
	text.Outline = true
	text.Color = CFG.TimerColor

	return text
end

local function destroyDoorTimerText(entry)
	if entry.text then
		if entry.text.Remove then
			entry.text:Remove()
		end
		entry.text = nil
	end
end

-- Раз в 0.5 с читаем таймер у каждой двери: игра сама пишет на ней «0:52»,
-- берём именно это значение, а не статичный Cooldown из атрибутов
local function scanDoorTimers()
	local now = Workspace:GetServerTimeNow()
	local seen = {}

	for _, object in ipairs(Workspace:GetDescendants()) do
		if object:IsA("ProximityPrompt") and object.Parent then
			local okTarget, target = pcall(resolveDoorTarget, object)

			if okTarget and target and target.Parent then
				local entry = DoorTimers.entries[object]
				if not entry then
					entry = { timerMemory = {} }
					DoorTimers.entries[object] = entry
				end

				local okStatus, _, _, seconds = pcall(doorStatus, entry, object, target)

				entry.pos = target:GetPivot().Position
				entry.readyAt = (okStatus and seconds and seconds > 0) and (now + seconds) or nil
				seen[object] = true
			end
		end
	end

	for prompt, entry in pairs(DoorTimers.entries) do
		if not seen[prompt] then
			destroyDoorTimerText(entry)
			DoorTimers.entries[prompt] = nil
		end
	end
end

local function updateDoorTimers()
	local camera = GetCamera()
	local now = Workspace:GetServerTimeNow()

	for _, entry in pairs(DoorTimers.entries) do
		if not entry.text then
			entry.text = makeDoorTimerText()
		end

		local text = entry.text
		if text then
			local remaining = (entry.readyAt or 0) - now
			local screen, onScreen = nil, false

			if camera and remaining > 0 then
				screen, onScreen = camera:WorldToViewportPoint(entry.pos + Vector3.new(0, 4, 0))
			end

			if onScreen then
				local seconds = math.max(0, math.ceil(remaining))
				text.Text = ("%d:%02d"):format(math.floor(seconds / 60), seconds % 60)
				text.Position = Vector2.new(screen.X, screen.Y)
				text.Visible = true
			else
				text.Visible = false
			end
		end
	end
end

function DoorTimers:SetEnabled(state)
	self.enabled = state

	if not state then
		self.active = false
		for _, entry in pairs(self.entries) do
			destroyDoorTimerText(entry)
		end
		table.clear(self.entries)

		if self.conn then
			self.conn:Disconnect()
			self.conn = nil
		end
		return
	end

	if self.conn then return end

	self.conn = RunService.RenderStepped:Connect(function()
		if DoorTimers.enabled then
			updateDoorTimers()
		end
	end)

	self.active = true
	task.spawn(function()
		while DoorTimers.active do
			pcall(scanDoorTimers)
			task.wait(0.5)
		end
	end)
end

function DoorTimers:Stop()
	self:SetEnabled(false)
end

--// ---------------- Модуль: флай ----------------
local Fly = {
	enabled  = false,
	speed    = 50,
	bv       = nil,
	humanoid = nil,
	conn     = nil,
}

local function clearFly()
	if Fly.bv then
		Fly.bv:Destroy()
		Fly.bv = nil
	end

	if Fly.humanoid then
		if Fly.humanoid.Parent then
			Fly.humanoid.PlatformStand = false
		end
		Fly.humanoid = nil
	end
end

local function flyStep()
	if not Fly.enabled then return end

	local character = LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")

	if not root or not humanoid or humanoid.Health <= 0 then
		clearFly()
		return
	end

	if Fly.humanoid ~= humanoid then
		if Fly.humanoid and Fly.humanoid.Parent then
			Fly.humanoid.PlatformStand = false
		end
		Fly.humanoid = humanoid
	end

	humanoid.PlatformStand = true

	if not Fly.bv or Fly.bv.Parent ~= root then
		if Fly.bv then Fly.bv:Destroy() end

		local bv = Instance.new("BodyVelocity")
		bv.Name = "ObsidianFly"
		bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
		bv.Velocity = Vector3.zero
		bv.Parent = root

		Fly.bv = bv
	end

	local camera = GetCamera()
	local look = camera and camera.CFrame.LookVector or Vector3.new(0, 0, -1)

	local flat = Vector3.new(look.X, 0, look.Z)
	if flat.Magnitude < 0.001 then
		flat = Vector3.new(0, 0, -1)
	end
	flat = flat.Unit

	local right = flat:Cross(Vector3.yAxis)

	local move = Vector3.zero
	if UserInputService:IsKeyDown(Enum.KeyCode.W) then move += flat end
	if UserInputService:IsKeyDown(Enum.KeyCode.S) then move -= flat end
	if UserInputService:IsKeyDown(Enum.KeyCode.D) then move += right end
	if UserInputService:IsKeyDown(Enum.KeyCode.A) then move -= right end
	if UserInputService:IsKeyDown(Enum.KeyCode.Space) then move += Vector3.yAxis end
	if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then move -= Vector3.yAxis end

	if move.Magnitude > 0 then
		move = move.Unit * Fly.speed
	end

	Fly.bv.Velocity = move
end

function Fly:Init()
	self.conn = RunService.RenderStepped:Connect(flyStep)
end

function Fly:SetEnabled(state)
	self.enabled = state
	if not state then
		clearFly()
	end
end

function Fly:SetSpeed(value)
	self.speed = math.clamp(value, 1, FLY_SPEED_MAX)
end

function Fly:Stop()
	self.enabled = false
	clearFly()

	if self.conn then
		self.conn:Disconnect()
		self.conn = nil
	end
end

--// ---------------- Библиотека ----------------
local repo = "https://raw.githubusercontent.com/deividcomsono/Obsidian/main/"
local Library      = loadstring(game:HttpGet(repo .. "Library.lua"))()
local ThemeManager = loadstring(game:HttpGet(repo .. "addons/ThemeManager.lua"))()
local SaveManager  = loadstring(game:HttpGet(repo .. "addons/SaveManager.lua"))()

Options = Library.Options
Toggles = Library.Toggles

--// ---------------- Window ----------------
local Window = Library:CreateWindow({
	Title = "Buffy Hub",
	Footer = "v1.2.0 · no-main build",
	Icon = 6031075931,          -- иконка окна (глаз), можно вписать другой rbxassetid
	NotifySide = "Right",
	ShowCustomCursor = false,   -- обычный курсор Roblox
	Center = true,
	AutoShow = true,
})

local Tabs = {
	Visuals  = Window:AddTab("Visuals", "eye"),
	Combat   = Window:AddTab("Combat", "crosshair"),
	Misc     = Window:AddTab("Misc", "wrench"),
	Settings = Window:AddTab("UI Settings", "settings"),
}

--// ---------------- Общие функции ----------------
local Features = {}

function Features.Notify(title, text)
	Library:Notify({ Title = title, Description = text, Time = 4 })
end

--// ---------------- Модуль: плавный телепорт за спину ----------------
Teleport = {
	busy      = false,
	following = false,
}

local TP_RAY = RaycastParams.new()
TP_RAY.FilterType = Enum.RaycastFilterType.Exclude

local function teleportTarget()
	-- приоритет: текущая цель аима, затем последняя, с которой он работал
	if isValidTarget(Aimbot.target) then
		return Aimbot.target
	end

	if isValidTarget(Aimbot.lastTarget) then
		return Aimbot.lastTarget
	end

	local camera = GetCamera()
	local character = LocalPlayer.Character
	local myRoot = character and character:FindFirstChild("HumanoidRootPart")
	if not camera or not myRoot then return nil end

	local origin = myRoot.Position
	local look = camera.CFrame.LookVector
	local best, bestScore = nil, math.huge

	for _, player in ipairs(Players:GetPlayers()) do
		if isValidTarget(player) then
			local offset = player.Character.HumanoidRootPart.Position - origin
			local distance = offset.Magnitude

			if distance <= CFG.TeleportRange and distance > 0.1 then
				-- ближе к центру взгляда — выше приоритет
				local score = distance * (1 + (1 - offset.Unit:Dot(look)) * 2)
				if score < bestScore then
					best, bestScore = player, score
				end
			end
		end
	end

	return best
end

function Teleport:Behind()
	if self.busy then return end

	local character = LocalPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not humanoid or humanoid.Health <= 0 then
		return
	end

	local target = teleportTarget()
	if not target then
		Features.Notify("Teleport", "Нет цели в радиусе " .. CFG.TeleportRange .. " studs")
		return
	end

	local targetRoot = target.Character and target.Character:FindFirstChild("HumanoidRootPart")
	if not targetRoot then
		Features.Notify("Teleport", "У цели нет HumanoidRootPart")
		return
	end

	local targetPos = targetRoot.Position

	-- персонаж в Roblox смотрит в -Z, значит за спиной смещение в +Z
	local point = (targetRoot.CFrame * CFrame.new(0, 0, CFG.TeleportBehind)).Position
	TP_RAY.FilterDescendantsInstances = { character }

	-- ищем пол под точкой приземления, чтобы не зависнуть в воздухе и не провалиться
	local floor = Workspace:Raycast(point + Vector3.new(0, 4, 0), Vector3.new(0, -12, 0), TP_RAY)
	if floor then
		point = Vector3.new(point.X, floor.Position.Y + 3.2, point.Z)
	end

	local startPos = root.Position
	local goal = (point - startPos).Magnitude
	if goal < 0.5 then return end

	local speed = math.clamp(CFG.TeleportSpeed, 10, 400)
	local stepSize = math.clamp(speed / 60, 0.4, 10)   -- шаг за кадр: больше шаг — выше шанс флага

	self.busy = true

	local travelled = 0
	while travelled < goal do
		character = LocalPlayer.Character
		root = character and character:FindFirstChild("HumanoidRootPart")
		humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not root or not humanoid or humanoid.Health <= 0 then break end

		travelled = math.min(travelled + stepSize, goal)
		local pos = startPos:Lerp(point, travelled / goal)

		root.CFrame = CFrame.lookAt(pos, Vector3.new(targetPos.X, pos.Y, targetPos.Z))
		-- гасим инерцию: иначе физика дёргает персонажа и его возвращает назад
		root.AssemblyLinearVelocity = Vector3.zero
		root.AssemblyAngularVelocity = Vector3.zero

		RunService.Heartbeat:Wait()
	end

	if root and root.Parent then
		root.AssemblyLinearVelocity = Vector3.zero
	end

	self.busy = false
end

-- Точка за спиной цели с поправкой на пол
local function desiredPoint(target)
	local targetRoot = target.Character and target.Character:FindFirstChild("HumanoidRootPart")
	local character = LocalPlayer.Character
	if not targetRoot or not character then return nil end

	TP_RAY.FilterDescendantsInstances = { character }

	local point = (targetRoot.CFrame * CFrame.new(0, 0, CFG.TeleportBehind)).Position
	local floor = Workspace:Raycast(point + Vector3.new(0, 4, 0), Vector3.new(0, -12, 0), TP_RAY)
	if floor then
		point = Vector3.new(point.X, floor.Position.Y + 3.2, point.Z)
	end

	return point
end

-- Непрерывное следование: каждый кадр шаг к точке за спиной, пока тоггл включён
function Teleport:SetFollowing(state)
	self.following = state

	-- корутина прошлого запуска могла ещё не завершиться — тогда второй цикл не нужен
	local running = self.followConn and coroutine.status(self.followConn) ~= "dead"
	if not state or running then return end

	self.followConn = task.spawn(function()
		while Teleport.following do
			local character = LocalPlayer.Character
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			local root = character and character:FindFirstChild("HumanoidRootPart")

			if root and humanoid and humanoid.Health > 0 then
				local target = teleportTarget()
				local point = target and desiredPoint(target)

				if point then
					local delta = point - root.Position
					local distance = delta.Magnitude

					if distance > 1.2 then
						local speed = math.clamp(CFG.TeleportSpeed, 10, 400)
						local stepSize = math.clamp(speed / 60, 0.4, 10)
						local nextPos = root.Position + delta.Unit * math.min(stepSize, distance)

						-- трогаем только позицию: поворот остаётся аиму, чтобы можно было стрелять на ходу
						root.CFrame = CFrame.new(nextPos) * root.CFrame.Rotation
						root.AssemblyLinearVelocity = Vector3.zero
						root.AssemblyAngularVelocity = Vector3.zero
					end
				end
			end

			RunService.Heartbeat:Wait()
		end

		Teleport.followConn = nil
	end)
end

--// ---------------- Модуль: авто-фарм дверей ----------------
local Farm = {
	running  = false,
	phase    = "IDLE",
	speed    = 120,
	range    = 2000,     -- в каком радиусе вообще искать цели
	visited  = {},       -- [модель] = true, сбрасывается при перезапуске
	cache    = {},       -- [модель] = BasePart
	waypoints = {},
	wpIndex  = 1,
	target   = nil,
	timer    = 0,
	stuck    = 0,
	openTimer = 0,
	cacheTimer = 0,
	sightTimer = 0,
	repathTimer = 0,
	retargetTimer = 0,
	clear    = false,
	lastPos  = Vector3.zero,
	conn     = nil,
}

local FARM_KEYWORDS = { "door", "trick", "treat" }
local FARM_PATH = {
	AgentRadius = 2,
	AgentHeight = 5,
	AgentCanJump = true,
	AgentCanClimb = true,
	WaypointSpacing = 6,
	Costs = { Water = 20, Climb = 5 },
}

local function isFarmTarget(name)
	name = string.lower(name)
	for _, word in ipairs(FARM_KEYWORDS) do
		if string.find(name, word, 1, true) then
			return true
		end
	end
	return false
end

-- Полный обход Workspace раз в полсекунды, а не каждый кадр
local function refreshFarmCache()
	local list = {}

	for _, object in ipairs(Workspace:GetDescendants()) do
		if object:IsA("ProximityPrompt") or object:IsA("ClickDetector") then
			local model = object:FindFirstAncestorOfClass("Model")
			if model and not model:FindFirstChildWhichIsA("Humanoid") and isFarmTarget(model.Name) then
				local part = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
				if part then
					list[model] = part
				end
			end
		end
	end

	Farm.cache = list
end

local function nearestFarmDoor(root)
	local best, bestPart, bestDist = nil, nil, math.huge
	local origin = root.Position
	local rangeSq = Farm.range * Farm.range

	for model, part in pairs(Farm.cache) do
		if part.Parent and not Farm.visited[model] then
			local offset = part.Position - origin
			local distanceSq = offset.X * offset.X + offset.Y * offset.Y + offset.Z * offset.Z
			if distanceSq <= rangeSq and distanceSq < bestDist then
				best, bestPart, bestDist = model, part, distanceSq
			end
		end
	end

	return best, bestPart
end

-- Прямая видимость двери: если по линии ничего нет, петли pathfinding не нужны
local function clearSight(from, to, ignoreModel)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { LocalPlayer.Character, ignoreModel }
	params.IgnoreWater = true

	return Workspace:Raycast(from, to - from, params) == nil
end

local function buildFarmPath(root, part)
	local path = PathfindingService:CreatePath(FARM_PATH)
	local ok = pcall(function()
		path:ComputeAsync(root.Position, part.Position)
	end)

	if ok and path.Status == Enum.PathStatus.Success then
		Farm.waypoints = path:GetWaypoints()
		Farm.wpIndex = 1
		return true
	end

	return false
end

local function openFarmDoor(model)
	for _, object in ipairs(model:GetDescendants()) do
		if object:IsA("ProximityPrompt") then
			if fireproximityprompt then
				pcall(fireproximityprompt, object)
			elseif VirtualInputManager then
				pcall(function()
					VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.E, false, game)
				end)
			end
		elseif object:IsA("ClickDetector") and fireclickdetector then
			pcall(fireclickdetector, object)
		end
	end
end

-- Шаг к точке: не больше бюджета за кадр и без перелёта. Возвращает остаток
-- бюджета и оставшуюся дистанцию: на высокой скорости точки не проскакивают.
local function stepTo(root, point, budget)
	local delta = point - root.Position
	local distance = delta.Magnitude
	if distance < 0.001 or budget <= 0 then
		return budget, distance
	end

	local step = math.min(budget, distance)
	local nextPos = root.Position + delta.Unit * step

	root.CFrame = CFrame.lookAt(nextPos, nextPos + delta.Unit)
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero

	return budget - step, distance - step
end

function Farm:SetRunning(state)
	self.running = state
	self.phase = "IDLE"
	self.target = nil
	self.waypoints = {}
	self.wpIndex = 1
	self.timer, self.stuck, self.openTimer = 0, 0, 0
	self.lastPos = Vector3.zero

	if state then
		self.visited = {}
		self.cacheTimer = 0
	end

	return state
end

function Farm:Init()
	if self.conn then return end

	self.conn = RunService.Heartbeat:Connect(function(dt)
		if not Farm.running then return end

		local character = LocalPlayer.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not root or not humanoid or humanoid.Health <= 0 then return end

		Farm.cacheTimer = Farm.cacheTimer - dt
		-- обход Workspace дорогой: обновляем кэш только когда стоим без цели
		if Farm.phase == "IDLE" and Farm.cacheTimer <= 0 then
			Farm.cacheTimer = 1
			refreshFarmCache()
		end

		Farm.sightTimer = Farm.sightTimer - dt
		Farm.repathTimer = Farm.repathTimer - dt
		Farm.retargetTimer = Farm.retargetTimer - dt

		if Farm.phase == "IDLE" then
			local model, part = nearestFarmDoor(root)
			if model then
				Farm.target = model
				Farm.timer = 0
				Farm.bestDist, Farm.progressTimer = math.huge, 0
				Farm.waypoints, Farm.wpIndex = {}, 1
				Farm.phase = buildFarmPath(root, part) and "PATH" or "DIRECT"
			end

		elseif Farm.phase == "PATH" or Farm.phase == "DIRECT" then
			Farm.timer = Farm.timer + dt

			local model = Farm.target
			local part = model and (model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true))

			if not part or not part.Parent then
				Farm.phase = "IDLE"
			else
				local distance = (part.Position - root.Position).Magnitude
				-- бюджет скорости за кадр: скачок dt (лаг) не должен телепортировать
				-- персонажа через полкарты и сбивать путь
				local budget = math.clamp(Farm.speed, 10, 400) * math.min(dt, 1 / 30)
				local arrive = math.max(5, budget + 2)

				if distance < arrive then
					Farm.phase = "OPEN"
					Farm.openTimer = 0.4
				else
					-- прогресс к цели вместо счётчика кадров: если дистанция не
					-- уменьшается — упёрлись, и неважно, какая скорость
					if distance < Farm.bestDist - 0.5 then
						Farm.bestDist = distance
						Farm.progressTimer = 0
					else
						Farm.progressTimer = Farm.progressTimer + dt
					end

					if Farm.progressTimer > 1.5 then
						Farm.progressTimer = 0
						Farm.bestDist = distance
						Farm.phase = buildFarmPath(root, part) and "PATH" or "DIRECT"
					end

					-- раз в 0.25 с смотрим, видно ли дверь напрямую
					if Farm.sightTimer <= 0 then
						Farm.sightTimer = 0.25
						Farm.clear = clearSight(root.Position, part.Position, model)
					end

					if Farm.clear then
						-- прямая свободна: летим по прямой, крюки вокруг блоков не нужны
						if Farm.phase ~= "DIRECT" then
							Farm.phase = "DIRECT"
							Farm.timer = 0
						end
					elseif Farm.phase == "DIRECT" then
						-- стена на линии: пробуем вернуться на путь, а не лететь сквозь неё
						if Farm.repathTimer <= 0 then
							Farm.repathTimer = 2
							if buildFarmPath(root, part) then
								Farm.phase = "PATH"
								Farm.timer = 0
							end
						end
					end

					if Farm.phase == "PATH" then
						-- за кадр проходим столько путевых точек, сколько влезает в
						-- бюджет: иначе на 150+ перелетаем точку и летим назад
						while budget > 0 do
							local waypoint = Farm.waypoints[Farm.wpIndex]
							if not waypoint then
								if not buildFarmPath(root, part) then
									Farm.phase = "DIRECT"
								end
								break
							end

							local left
							budget, left = stepTo(root, waypoint.Position, budget)

							if left > 0.5 then
								break
							end

							if waypoint.Action == Enum.PathWaypointAction.Jump then
								humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
							end
							Farm.wpIndex = Farm.wpIndex + 1
						end
					else
						stepTo(root, part.Position, budget)
					end

					-- рядом появилась другая дверь — переключаемся, чтобы не лететь назад
					if Farm.retargetTimer <= 0 then
						Farm.retargetTimer = 2
						local nearModel, nearPart = nearestFarmDoor(root)
						if nearModel and nearModel ~= model then
							if (nearPart.Position - root.Position).Magnitude < distance * 0.5 then
								Farm.target = nearModel
								Farm.timer = 0
								Farm.bestDist, Farm.progressTimer = math.huge, 0
								Farm.phase = buildFarmPath(root, nearPart) and "PATH" or "DIRECT"
							end
						end
					end

					-- сдаёмся только если не доехали за двойное расчётное время
					if Farm.target == model and Farm.timer > (distance / math.max(Farm.speed, 10)) * 2.5 + 6 then
						Farm.visited[model] = true
						Farm.phase = "IDLE"
					end
				end
			end

		elseif Farm.phase == "OPEN" then
			Farm.openTimer = Farm.openTimer - dt
			if Farm.openTimer <= 0 then
				if Farm.target then
					openFarmDoor(Farm.target)
					Farm.visited[Farm.target] = true
				end

				Farm.target = nil
				Farm.waypoints = {}
				Farm.wpIndex = 1
				Farm.phase = "IDLE"
			end
		end
	end)
end

function Farm:Stop()
	if self.conn then
		self.conn:Disconnect()
		self.conn = nil
	end

	self.running = false
	self.phase = "IDLE"
end

--// Сборка UI: ошибка в одной секции не должна ронять остальные вкладки
local BuildErrors = {}

local function Build(Section, Func)
	local ok, err = pcall(Func)
	if not ok then
		table.insert(BuildErrors, Section .. " -> " .. tostring(err))
		warn(("[Obsidian] секция '%s' упала: %s"):format(Section, tostring(err)))
	end
	return ok
end

--// ================= VISUALS / Players =================
Build("Visuals", function()
local PlayersBox = Tabs.Visuals:AddGroupbox({
	Side = "Left",
	Name = "Players",
	IconName = "users",
})

PlayersBox:AddToggle("PlayerChams", {
	Text = "Player chams",
	Default = true,
	Tooltip = "Highlight на игроках (видно сквозь стены)",
	Callback = function(state)
		Esp:SetChams(state)
	end,
})

PlayersBox:AddToggle("NameESP", {
	Text = "Name + HP",
	Default = true,
	Tooltip = "Ник и здоровье над головой",
	Callback = function(state)
		Esp:SetNames(state)
	end,
})


--// ================= VISUALS / Doors =================
local DoorsBox = Tabs.Visuals:AddGroupbox({
	Side = "Right",
	Name = "Doors",
	IconName = "door-open",
})

DoorsBox:AddToggle("DoorESP", {
	Text = "Door ESP",
	Default = true,
	Tooltip = "Подсветка дверей и метка READY",
	Callback = function(state)
		Prompts:SetEsp(state)
	end,
})

DoorsBox:AddToggle("DoorTimerESP", {
	Text = "Door respawn timer",
	Default = true,
	Tooltip = "Секунды до открытия двери, крупно над дверью",
	Callback = function(state)
		DoorTimers:SetEnabled(state)
	end,
})
end)

--// ================= COMBAT / Aim =================
Build("Combat", function()
local AimBox = Tabs.Combat:AddGroupbox({
	Side = "Left",
	Name = "Aim assist",
	IconName = "crosshair",
})

AimBox:AddToggle("AimEnabled", {
	Text = "Aim assist",
	Default = false,
	Tooltip = "Кружок FOV + доводка на цель",
	Callback = function(state)
		Aimbot:SetEnabled(state)
	end,
})

AimBox:AddLabel("Aim key"):AddKeyPicker("AimKey", {
	Default = "E",
	Mode = "Toggle",         -- нажал — аим включён, нажал ещё раз — выключен
	Text = "Aim assist",
	NoUI = false,
})

AimBox:AddSlider("AimFOV", {
	Text = "FOV radius",
	Default = 150, Min = 30, Max = 400, Rounding = 0,
	Callback = function(value)
		Aimbot.fov = value
	end,
})

AimBox:AddSlider("AimYOffset", {
	Text = "Cursor Y offset",
	Default = 28, Min = 0, Max = 60, Rounding = 0,
	Tooltip = "Смещение под верхнюю панель Roblox",
	Callback = function(value)
		Aimbot.yOffset = value
	end,
})

AimBox:AddSlider("AimSmooth", {
	Text = "Smoothness",
	Default = 45, Min = 0, Max = 95, Rounding = 0,
	Tooltip = "0 — мгновенное прилипание, больше — плавнее",
	Callback = function(value)
		Aimbot.smoothness = value
	end,
})

AimBox:AddSlider("AimStrength", {
	Text = "Strength",
	Default = 100, Min = 10, Max = 100, Rounding = 0,
	Tooltip = "Сколько процентов пути к цели доводит аим",
	Callback = function(value)
		Aimbot.strength = value
	end,
})
end)

--// ================= COMBAT / Teleport behind =================
Build("Combat / Teleport", function()
local TpBox = Tabs.Combat:AddGroupbox({
	Side = "Left",
	Name = "Teleport",
	IconName = "move",
})

TpBox:AddButton({
	Text = "Behind target",
	Func = function()
		Teleport:Behind()
	end,
})

TpBox:AddToggle("TpFollow", {
	Text = "Follow behind",
	Default = false,
	Tooltip = "Летит за спиной цели (последняя цель аима), пока не выключишь",
	Callback = function(state)
		Teleport:SetFollowing(state)
	end,
}):AddKeyPicker("TpFollowBind", {
	Default = "Y",
	Mode = "Toggle",
	SyncToggleState = true,
	Text = "Follow behind",
	NoUI = false,
})

TpBox:AddSlider("TpSpeed", {
	Text = "Teleport speed",
	Default = 55, Min = 15, Max = 200, Rounding = 0,
	Tooltip = "Студов в секунду: меньше — плавнее, но дольше",
	Callback = function(value)
		CFG.TeleportSpeed = value
	end,
})

TpBox:AddLabel("Идёт мелкими шагами по кадру (примерно 1 студ за кадр). Если игра всё равно дёргает назад — снизь скорость.", true)
end)

--// ================= MISC / Interaction =================
Build("Misc", function()
local InteractBox = Tabs.Misc:AddGroupbox({
	Side = "Left",
	Name = "Interaction",
	IconName = "hand",
})

InteractBox:AddToggle("InstantPrompts", {
	Text = "Instant interact",
	Default = true,
	Tooltip = "HoldDuration = 0, дистанция больше",
	Callback = function(state)
		Prompts:SetInstant(state)
	end,
})

InteractBox:AddDivider()
InteractBox:AddLabel(
	"При выключении тоггла исходные значения промптов (HoldDuration / дистанция / LineOfSight) восстанавливаются.",
	true
)

--// ================= MISC / Movement =================
local MoveBox = Tabs.Misc:AddGroupbox({
	Side = "Right",
	Name = "Movement",
	IconName = "wind",
})

local FlyToggle = MoveBox:AddToggle("Fly", {
	Text = "Fly",
	Default = false,
	Tooltip = "WASD относительно камеры, Space вверх, LeftCtrl вниз",
	Callback = function(state)
		Fly:SetEnabled(state)
	end,
})

-- Бинд на флай: любую клавишу можно назначить в этом пикере
FlyToggle:AddKeyPicker("FlyBind", {
	Default = "X",
	Mode = "Toggle",
	SyncToggleState = true,
	Text = "Fly",
	NoUI = false,
})

MoveBox:AddSlider("FlySpeed", {
	Text = ("Fly speed (макс. %d)"):format(FLY_SPEED_MAX),
	Default = math.min(50, FLY_SPEED_MAX), Min = 10, Max = FLY_SPEED_MAX, Rounding = 0,
	Callback = function(value)
		Fly:SetSpeed(value)
	end,
})

--// ================= MISC / Auto farm =================
local FarmBox = Tabs.Misc:AddGroupbox({
	Side = "Right",
	Name = "Auto farm",
	IconName = "route",
})

local FarmToggle = FarmBox:AddToggle("AutoFarm", {
	Text = "Auto farm doors",
	Default = false,
	Tooltip = "Ищет двери и сундуки, летит по пути и открывает промпты",
	Callback = function(state)
		Farm:SetRunning(state)
	end,
})

FarmToggle:AddKeyPicker("FarmBind", {
	Default = "K",
	Mode = "Toggle",
	SyncToggleState = true,
	Text = "Auto farm",
	NoUI = false,
})

FarmBox:AddSlider("FarmSpeed", {
	Text = "Farm speed",
	Default = 120, Min = 40, Max = 400, Rounding = 0,
	Tooltip = "Студов в секунду",
	Callback = function(value)
		Farm.speed = value
	end,
})

FarmBox:AddSlider("FarmRange", {
	Text = "Search radius",
	Default = 2000, Min = 200, Max = 10000, Rounding = 0,
	Tooltip = "В каком радиусе искать цели",
	Callback = function(value)
		Farm.range = value
	end,
})

FarmBox:AddLabel("Клик по бинду — назначить свою клавишу. Путь строится PathfindingService, при прямой видимости — полёт по прямой. Посещённые двери запоминаются до перезапуска тоггла.", true)
end)

--// ================= UI Settings =================
Build("UI Settings", function()
local Menu = Tabs.Settings:AddGroupbox({ Side = "Left", Name = "Menu", IconName = "wrench" })

Menu:AddToggle("KeybindMenuOpen", {
	Text = "Keybind menu",
	Default = Library.KeybindFrame.Visible,
	Callback = function(v) Library.KeybindFrame.Visible = v end,
})

Menu:AddDropdown("NotificationSide", {
	Text = "Notification side",
	Values = { "Left", "Right" },
	Default = "Right",
	Callback = function(v) Library:SetNotifySide(v) end,
})

Menu:AddSlider("UICornerSlider", {
	Text = "Corner radius",
	Default = Library.CornerRadius, Min = 0, Max = 20, Rounding = 0,
	Callback = function(v) Window:SetCornerRadius(v) end,
})

Menu:AddDivider()
Menu:AddLabel("Menu bind"):AddKeyPicker("MenuKeybind", {
	Default = "RightShift",
	Text = "Menu keybind",
	NoUI = true,
})

Menu:AddButton({ Text = "Unload", Func = function() Library:Unload() end })
end)

if Options.MenuKeybind then
	Library.ToggleKeybind = Options.MenuKeybind
end

--// ---------------- Addons ----------------
ThemeManager:SetLibrary(Library)
SaveManager:SetLibrary(Library)
SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({ "MenuKeybind" })

ThemeManager:SetFolder("BuffyHub")
SaveManager:SetFolder("BuffyHub/main")

SaveManager:BuildConfigSection(Tabs.Settings)
ThemeManager:ApplyToTab(Tabs.Settings)

SaveManager:LoadAutoloadConfig()

--// ---------------- Отчёт о сборке ----------------
if #BuildErrors > 0 then
	local Report = table.concat(BuildErrors, " | ")
	print("[Obsidian] ошибки сборки: " .. Report)
	Library:Notify({
		Title = "UI: ошибка",
		Description = Report,
		Time = 12,
	})
else
	print("[Obsidian] UI собран без ошибок")
end

--// ---------------- Запуск модулей ----------------
Esp:Start()
Prompts:Start()
Aimbot:Init()
Fly:Init()
Farm:Init()

Esp:SetChams(true)
Esp:SetNames(true)
Prompts:SetEsp(true)
Prompts:SetInstant(true)
DoorTimers:SetEnabled(true)

Library:OnUnload(function()
	Esp:Stop()
	Aimbot:Stop()
	Prompts:Stop()
	DoorTimers:Stop()
	Farm:Stop()
	Fly:Stop()
	print("Unloaded")
end)
