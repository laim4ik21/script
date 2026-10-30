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
	SpecialName      = "redix31",                    -- ник с особым цветом
	ChamsColor       = Color3.fromRGB(255, 0, 0),    -- цвет чамсов
	SpecialColor     = Color3.fromRGB(0, 255, 0),    -- цвет чамсов особого игрока
	OutlineColor     = Color3.fromRGB(255, 255, 255),
	FillTransparency = 0.5,
	NameTextColor    = Color3.fromRGB(255, 255, 255),
	DoorColor        = Color3.fromRGB(255, 140, 0),
	DoorTextColor    = Color3.fromRGB(255, 50, 50),
	ReadyColor       = Color3.fromRGB(80, 255, 80),
	LockedColor      = Color3.fromRGB(255, 50, 50),
	PromptDistance   = 50,                           -- MaxActivationDistance в режиме instant
	DoorEspDistance  = 500,
}

--// ---------------- Модуль: чамсы + ники ----------------
local Esp = {
	chams    = false,
	names    = false,
	registry = {},   -- [player] = entry
	conns    = {},
}

local function playerColor(player)
	return (player.Name == CFG.SpecialName) and CFG.SpecialColor or CFG.ChamsColor
end

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
		text.Color = (player.Name == CFG.SpecialName) and CFG.SpecialColor or CFG.NameTextColor
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
	highlight.FillColor = playerColor(entry.player)
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
					text.Text = ("%s [%dHP]"):format(player.Name, math.floor(humanoid.Health))
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

--// ---------------- Модуль: аимбот ----------------
local Aimbot = {
	enabled = false,
	fov     = 150,
	yOffset = 28,
	target  = nil,
	circle  = nil,
	conn    = nil,
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

	local character = LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then return end

	local targetPos = target.Character.HumanoidRootPart.Position
	local lookPos = Vector3.new(targetPos.X, root.Position.Y, targetPos.Z)
	root.CFrame = CFrame.new(root.Position, lookPos)
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

	local seconds = chooseSeconds(entry, candidates) or 0

	if seconds > 0 then
		return formatTime(seconds), CFG.LockedColor
	end

	if boolValue ~= nil then
		if boolReady then
			return boolValue and "READY" or "LOCKED", boolValue and CFG.ReadyColor or CFG.LockedColor
		end
		return boolValue and "LOCKED" or "READY", boolValue and CFG.LockedColor or CFG.ReadyColor
	end

	local hint = string.lower(tostring(prompt.ActionText or "") .. " " .. tostring(prompt.ObjectText or ""))
	if matchAny(hint, TEXT_LOCK_WORDS) then
		return "LOCKED", CFG.LockedColor
	end

	if prompt.Enabled then
		return "READY", CFG.ReadyColor
	end

	return "LOCKED", CFG.LockedColor
end

local function refreshDoorLabels()
	for prompt, entry in pairs(Prompts.cache) do
		local visual = entry.visual
		local target = entry.target

		if prompt.Parent and visual and target and visual.label and visual.label.Parent then
			local text, color = doorStatus(entry, prompt, target)
			if visual.label.Text ~= text then
				visual.label.Text = text
			end
			if visual.label.TextColor3 ~= color then
				visual.label.TextColor3 = color
			end
		end
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
				refreshDoorLabels()
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
	self.speed = value
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
	Title = "КОЧ ГАЛДА Hub",
	Footer = "v1.2.0 · no-main build",
	Icon = 95816097006870,      -- lucide имя иконки или rbxassetid
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

PlayersBox:AddDivider()
PlayersBox:AddLabel(("Особый цвет для: %s"):format(CFG.SpecialName), true)

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
	Mode = "Hold",           -- зажал клавишу — аим работает
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
	Text = "Fly speed",
	Default = 50, Min = 10, Max = 300, Rounding = 0,
	Callback = function(value)
		Fly:SetSpeed(value)
	end,
})
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

Esp:SetChams(true)
Esp:SetNames(true)
Prompts:SetEsp(true)
Prompts:SetInstant(true)

Library:OnUnload(function()
	Esp:Stop()
	Aimbot:Stop()
	Prompts:Stop()
	Fly:Stop()
	print("Unloaded")
end)
