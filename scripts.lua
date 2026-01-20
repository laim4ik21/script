local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

local Config = {
    Aimbot = {Enabled = false, Fov = 150, Smooth = 0.2, TargetPart = "Head", MaxDist = 500},
    Visuals = {Enabled = true, Chams = true, Color = Color3.fromRGB(180, 100, 255), R = 180, G = 100, B = 255},
    Friends = {},
    Misc = {FlyEnabled = false, FlySpeed = 50},
    MenuKey = Enum.KeyCode.T,
    AimKey = Enum.KeyCode.Z
}

local currentTarget = nil
local flyVelocity = nil

local Gui = Instance.new("ScreenGui", LocalPlayer:WaitForChild("PlayerGui"))
Gui.Name = "Gemini_V32_Fixed"
Gui.ResetOnSpawn = false

local Main = Instance.new("Frame", Gui)
Main.Size = UDim2.new(0, 550, 0, 480)
Main.Position = UDim2.new(0.5, -275, 0.5, -240)
Main.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
Main.BorderSizePixel = 0
Main.Active = true
Instance.new("UICorner", Main).CornerRadius = UDim.new(0, 12)

local UIStroke = Instance.new("UIStroke", Main)
UIStroke.Thickness = 3
UIStroke.Color = Config.Visuals.Color
UIStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

-- [ DRAG FIX ]
local dragging, dragInput, dragStart, startPos
Main.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = true dragStart = input.Position startPos = Main.Position
    end
end)
Main.InputChanged:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseMovement then dragInput = input end end)
UserInputService.InputEnded:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end end)

RunService.RenderStepped:Connect(function()
    if dragging and dragInput then
        local delta = dragInput.Position - dragStart
        Main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)

local Sidebar = Instance.new("Frame", Main)
Sidebar.Size = UDim2.new(0, 140, 1, 0)
Sidebar.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
Sidebar.BorderSizePixel = 0
Instance.new("UICorner", Sidebar).CornerRadius = UDim.new(0, 12)

local Container = Instance.new("Frame", Main)
Container.Position = UDim2.new(0, 150, 0, 15)
Container.Size = UDim2.new(1, -165, 1, -30)
Container.BackgroundTransparency = 1

local Pages = { 
    Aimbot = Instance.new("ScrollingFrame", Container), 
    Visuals = Instance.new("ScrollingFrame", Container),
    Friends = Instance.new("ScrollingFrame", Container),
    Misc = Instance.new("ScrollingFrame", Container)
}

for name, p in pairs(Pages) do
    p.Size = UDim2.new(1, 0, 1, 0) p.BackgroundTransparency = 1 p.Visible = (name == "Aimbot") p.ScrollBarThickness = 4 p.CanvasSize = UDim2.new(0, 0, 1.5, 0)
end

local function UpdateInterface()
    Config.Visuals.Color = Color3.fromRGB(Config.Visuals.R, Config.Visuals.G, Config.Visuals.B)
    UIStroke.Color = Config.Visuals.Color
    for _, v in pairs(Main:GetDescendants()) do
        if v:IsA("TextButton") then
            if v.Name == "Toggle_Active" then v.BackgroundColor3 = Config.Visuals.Color end
            if v.Name == "Part_Selected" then v.BackgroundColor3 = Config.Visuals.Color end
        end
        if v:IsA("Frame") and v.Name == "Slider_Bar" then v.BackgroundColor3 = Config.Visuals.Color end
    end
end

local function CreateTab(name, y)
    local b = Instance.new("TextButton", Sidebar)
    b.Size = UDim2.new(1, -10, 0, 50) b.Position = UDim2.new(0, 5, 0, y + 5) 
    b.BackgroundColor3 = Color3.fromRGB(30, 30, 30) 
    b.Text = name:upper() b.TextColor3 = Color3.new(1, 1, 1) b.Font = Enum.Font.GothamBold b.TextSize = 18
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 8)
    b.MouseButton1Click:Connect(function() for n, p in pairs(Pages) do p.Visible = (n == name) end end)
end

CreateTab("Aimbot", 0) CreateTab("Visuals", 55) CreateTab("Friends", 110) CreateTab("Misc", 165)

local function AddToggle(page, text, tbl, key, y)
    local btn = Instance.new("TextButton", page)
    btn.Size = UDim2.new(1, -10, 0, 45) btn.Position = UDim2.new(0, 5, 0, y) 
    btn.BackgroundColor3 = tbl[key] and Config.Visuals.Color or Color3.fromRGB(35, 35, 35)
    btn.Name = tbl[key] and "Toggle_Active" or "Toggle_Idle"
    btn.Font = Enum.Font.GothamBold btn.TextColor3 = Color3.new(1, 1, 1) btn.Text = text btn.TextSize = 18
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 10)
    btn.MouseButton1Click:Connect(function()
        tbl[key] = not tbl[key]
        btn.Name = tbl[key] and "Toggle_Active" or "Toggle_Idle"
        btn.BackgroundColor3 = tbl[key] and Config.Visuals.Color or Color3.fromRGB(35, 35, 35)
        UpdateInterface()
    end)
    return y + 50
end

-- [ SLIDER FIX: Переписан расчет позиции ]
local function AddSlider(page, text, tbl, key, y, min, max)
    local tl = Instance.new("TextLabel", page) 
    tl.Size = UDim2.new(1, -10, 0, 30) tl.Position = UDim2.new(0, 5, 0, y) 
    tl.Text = text .. ": " .. tostring(tbl[key]) 
    tl.BackgroundTransparency = 1 tl.TextColor3 = Color3.new(1, 1, 1) 
    tl.Font = Enum.Font.GothamBold tl.TextSize = 16 tl.TextXAlignment = Enum.TextXAlignment.Left

    local sld = Instance.new("TextButton", page) 
    sld.Size = UDim2.new(1, -10, 0, 16) sld.Position = UDim2.new(0, 5, 0, y+32) 
    sld.Text = "" sld.BackgroundColor3 = Color3.fromRGB(45, 45, 45) sld.AutoButtonColor = false
    Instance.new("UICorner", sld).CornerRadius = UDim.new(0, 8)

    local bar = Instance.new("Frame", sld) 
    bar.Name = "Slider_Bar" 
    bar.Size = UDim2.new(math.clamp((tbl[key] - min) / (max - min), 0, 1), 0, 1, 0) 
    bar.BackgroundColor3 = Config.Visuals.Color bar.BorderSizePixel = 0
    Instance.new("UICorner", bar).CornerRadius = UDim.new(0, 8)

    local function updateSlider()
        local mousePos = UserInputService:GetMouseLocation().X
        local sliderPos = sld.AbsolutePosition.X
        local sliderWidth = sld.AbsoluteSize.X
        local ratio = math.clamp((mousePos - sliderPos) / sliderWidth, 0, 1)
        
        local value = min + (max - min) * ratio
        if max > 10 then value = math.floor(value) else value = math.floor(value * 100) / 100 end
        
        tbl[key] = value
        bar.Size = UDim2.new(ratio, 0, 1, 0)
        tl.Text = text .. ": " .. tostring(value)
        UpdateInterface()
    end

    sld.MouseButton1Down:Connect(function()
        local moveConn
        moveConn = RunService.RenderStepped:Connect(updateSlider)
        local releaseConn
        releaseConn = UserInputService.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                moveConn:Disconnect()
                releaseConn:Disconnect()
            end
        end)
    end)
    return y + 65
end

local function AddPartSelector(page, y)
    local parts = {["Head"]="Head", ["Torso"]="UpperTorso", ["Root"]="HumanoidRootPart", ["Arms"]="RightUpperArm", ["Legs"]="RightUpperLeg"}
    local ly = y
    local label = Instance.new("TextLabel", page)
    label.Size = UDim2.new(1,-10,0,30) label.Position = UDim2.new(0,5,0,ly) label.Text = "TARGET PART:" label.BackgroundTransparency = 1 label.TextColor3 = Color3.new(1,1,1) label.Font = Enum.Font.GothamBold label.TextSize = 14 label.TextXAlignment = Enum.TextXAlignment.Left
    ly = ly + 35
    for dName, rName in pairs(parts) do
        local b = Instance.new("TextButton", page)
        b.Size = UDim2.new(1, -10, 0, 35) b.Position = UDim2.new(0, 5, 0, ly)
        b.Text = dName b.Font = Enum.Font.GothamBold b.TextColor3 = Color3.new(1,1,1) b.TextSize = 14
        b.Name = (Config.Aimbot.TargetPart == rName) and "Part_Selected" or "Part_Idle"
        b.BackgroundColor3 = (Config.Aimbot.TargetPart == rName) and Config.Visuals.Color or Color3.fromRGB(35,35,35)
        Instance.new("UICorner", b).CornerRadius = UDim.new(0, 8)
        b.MouseButton1Click:Connect(function()
            Config.Aimbot.TargetPart = rName
            for _, v in pairs(page:GetChildren()) do if v:IsA("TextButton") and (v.Name == "Part_Selected" or v.Name == "Part_Idle") then v.BackgroundColor3 = Color3.fromRGB(35,35,35) v.Name = "Part_Idle" end end
            b.BackgroundColor3 = Config.Visuals.Color b.Name = "Part_Selected"
        end)
        ly = ly + 40
    end
    return ly
end

local ay = 0
ay = AddToggle(Pages.Aimbot, "Aimbot [Z]", Config.Aimbot, "Enabled", ay)
ay = AddSlider(Pages.Aimbot, "Field of View", Config.Aimbot, "Fov", ay, 10, 800)
ay = AddSlider(Pages.Aimbot, "Smooth Speed", Config.Aimbot, "Smooth", ay, 0.01, 1)
ay = AddSlider(Pages.Aimbot, "Max Distance", Config.Aimbot, "MaxDist", ay, 10, 2000)
ay = AddPartSelector(Pages.Aimbot, ay)

local vy = 0
vy = AddToggle(Pages.Visuals, "Enable Chams", Config.Visuals, "Chams", vy)
vy = AddSlider(Pages.Visuals, "Color Red", Config.Visuals, "R", vy, 0, 255)
vy = AddSlider(Pages.Visuals, "Color Green", Config.Visuals, "G", vy, 0, 255)
vy = AddSlider(Pages.Visuals, "Color Blue", Config.Visuals, "B", vy, 0, 255)

local function RefreshFriends()
    Pages.Friends:ClearAllChildren()
    local fy = 0
    for _, p in pairs(Players:GetPlayers()) do
        if p == LocalPlayer then continue end
        local btn = Instance.new("TextButton", Pages.Friends)
        btn.Size = UDim2.new(1, -10, 0, 40) btn.Position = UDim2.new(0, 5, 0, fy)
        local isF = table.find(Config.Friends, p.Name)
        btn.BackgroundColor3 = isF and Color3.fromRGB(0, 120, 255) or Color3.fromRGB(40, 40, 40)
        btn.Text = p.Name btn.TextColor3 = Color3.new(1, 1, 1) btn.Font = Enum.Font.GothamBold btn.TextSize = 16
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 10)
        btn.MouseButton1Click:Connect(function()
            local idx = table.find(Config.Friends, p.Name)
            if idx then table.remove(Config.Friends, idx) else table.insert(Config.Friends, p.Name) end
            RefreshFriends()
        end)
        fy = fy + 45
    end
end
Players.PlayerAdded:Connect(RefreshFriends) RefreshFriends()

local my = 0
my = AddToggle(Pages.Misc, "Fly Mode", Config.Misc, "FlyEnabled", my)
my = AddSlider(Pages.Misc, "Fly Speed", Config.Misc, "FlySpeed", my, 10, 300)

local FOV = Drawing.new("Circle") 
FOV.Thickness = 2.5 FOV.NumSides = 90 _G.GeminiActive = true

local function GetTarget()
    local mousePos = UserInputService:GetMouseLocation()
    if currentTarget then
        local char = currentTarget.Parent
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if not char or not hum or hum.Health <= 0 or not Config.Aimbot.Enabled then currentTarget = nil
        else
            local vpos, vis = Camera:WorldToViewportPoint(currentTarget.Position)
            local screenDist = (Vector2.new(vpos.X, vpos.Y) - mousePos).Magnitude
            if screenDist < (Config.Aimbot.Fov * 1.5) then return currentTarget else currentTarget = nil end
        end
    end
    local target, minWorldDist = nil, math.huge
    for _, p in pairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and not table.find(Config.Friends, p.Name) and p.Character then
            local part = p.Character:FindFirstChild(Config.Aimbot.TargetPart) or p.Character:FindFirstChild("HumanoidRootPart")
            if part and p.Character:FindFirstChildOfClass("Humanoid") and p.Character:FindFirstChildOfClass("Humanoid").Health > 0 then
                local vpos, vis = Camera:WorldToViewportPoint(part.Position)
                local screenDist = (Vector2.new(vpos.X, vpos.Y) - mousePos).Magnitude
                local worldDist = (part.Position - LocalPlayer.Character.HumanoidRootPart.Position).Magnitude
                if screenDist < Config.Aimbot.Fov and worldDist <= Config.Aimbot.MaxDist then
                    if worldDist < minWorldDist then minWorldDist = worldDist target = part end
                end
            end
        end
    end
    currentTarget = target return target
end

RunService.RenderStepped:Connect(function()
    if not _G.GeminiActive then FOV.Visible = false return end
    FOV.Visible = Config.Aimbot.Enabled FOV.Radius = Config.Aimbot.Fov FOV.Position = UserInputService:GetMouseLocation() FOV.Color = Config.Visuals.Color
    local t = GetTarget()
    if Config.Aimbot.Enabled and t then Camera.CFrame = Camera.CFrame:Lerp(CFrame.new(Camera.CFrame.Position, t.Position), Config.Aimbot.Smooth) end

    if Config.Visuals.Chams then
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Character then
                local cham = p.Character:FindFirstChild("GeminiCham")
                if p.Character:FindFirstChild("Humanoid") and p.Character.Humanoid.Health > 0 then
                    if not cham then cham = Instance.new("Highlight", p.Character) cham.Name = "GeminiCham" end
                    if Config.Aimbot.Enabled and t and p.Character == t.Parent then cham.FillColor = Color3.fromRGB(255, 0, 0)
                    elseif table.find(Config.Friends, p.Name) then cham.FillColor = Color3.fromRGB(0, 150, 255)
                    else cham.FillColor = Config.Visuals.Color end
                    cham.Enabled = true
                elseif cham then cham.Enabled = false end
            end
        end
    end
    
    if Config.Misc.FlyEnabled then
        local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if root then
            if not flyVelocity then flyVelocity = Instance.new("BodyVelocity", root) flyVelocity.MaxForce = Vector3.new(1,1,1)*math.huge end
            local md = LocalPlayer.Character.Humanoid.MoveDirection
            local v = Vector3.new(0, 0.05, 0)
            if UserInputService:IsKeyDown(Enum.KeyCode.Space) then v = v + Vector3.new(0,1,0) end
            if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then v = v + Vector3.new(0,-1,0) end
            flyVelocity.Velocity = (md * Config.Misc.FlySpeed) + (v * Config.Misc.FlySpeed)
            root.AssemblyLinearVelocity = Vector3.new(0,0,0)
        end
    elseif flyVelocity then flyVelocity:Destroy() flyVelocity = nil end
end)

UserInputService.InputBegan:Connect(function(i, gpe)
    if not gpe then
        if i.KeyCode == Config.MenuKey then Main.Visible = not Main.Visible end
        if i.KeyCode == Config.AimKey then Config.Aimbot.Enabled = not Config.Aimbot.Enabled UpdateInterface() end
    end
end)
