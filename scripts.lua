local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

local Config = {
    Aimbot = {Enabled = false, Fov = 150, Smooth = 0.2, TargetPart = "Head", MaxDist = 150},
    Visuals = {Enabled = true, Chams = true, Color = Color3.fromRGB(180, 100, 255), R = 180, G = 100, B = 255},
    Friends = {},
    MenuKey = Enum.KeyCode.T,
    AimKey = Enum.KeyCode.Z
}

local currentTarget = nil

local Gui = Instance.new("ScreenGui", LocalPlayer:WaitForChild("PlayerGui"))
Gui.Name = "Gemini_V27"
Gui.ResetOnSpawn = false

local Main = Instance.new("Frame", Gui)
Main.Size = UDim2.new(0, 550, 0, 480)
Main.Position = UDim2.new(0.5, -275, 0.5, -240)
Main.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
Main.BorderSizePixel = 0
Main.Active = true

local MainCorner = Instance.new("UICorner", Main)
MainCorner.CornerRadius = UDim.new(0, 12)

local UIStroke = Instance.new("UIStroke", Main)
UIStroke.Thickness = 3
UIStroke.Color = Config.Visuals.Color
UIStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

local dragging, dragInput, dragStart, startPos
Main.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = true dragStart = input.Position startPos = Main.Position
        input.Changed:Connect(function() if input.UserInputState == Enum.UserInputState.End then dragging = false end end)
    end
end)
Main.InputChanged:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseMovement then dragInput = input end end)
local dragConn = RunService.RenderStepped:Connect(function()
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
    p.Size = UDim2.new(1, 0, 1, 0) p.BackgroundTransparency = 1 p.Visible = (name == "Aimbot") p.ScrollBarThickness = 4 p.CanvasSize = UDim2.new(0, 0, 2, 0)
end

local function UpdateInterface()
    if not Main then return end
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

local function AddSlider(page, text, tbl, key, y, min, max)
    local tl = Instance.new("TextLabel", page) tl.Size = UDim2.new(1, -10, 0, 30) tl.Position = UDim2.new(0, 5, 0, y) tl.Text = text .. ": " .. tbl[key] tl.BackgroundTransparency = 1 tl.TextColor3 = Color3.new(1, 1, 1) tl.Font = Enum.Font.GothamBold tl.TextSize = 16 tl.TextXAlignment = Enum.TextXAlignment.Left
    local sld = Instance.new("TextButton", page) sld.Size = UDim2.new(1, -10, 0, 16) sld.Position = UDim2.new(0, 5, 0, y+32) sld.Text = "" sld.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
    Instance.new("UICorner", sld).CornerRadius = UDim.new(0, 8)
    local bar = Instance.new("Frame", sld) bar.Name = "Slider_Bar" bar.Size = UDim2.new((tbl[key]-min)/(max-min), 0, 1, 0) bar.BackgroundColor3 = Config.Visuals.Color bar.BorderSizePixel = 0
    Instance.new("UICorner", bar).CornerRadius = UDim.new(0, 8)
    sld.MouseButton1Down:Connect(function()
        local c; c = RunService.RenderStepped:Connect(function()
            local r = math.clamp((UserInputService:GetMouseLocation().X - sld.AbsolutePosition.X)/sld.AbsoluteSize.X, 0, 1)
            local v = math.floor((min+(max-min)*r)*100)/100 tbl[key] = v bar.Size = UDim2.new(r, 0, 1, 0) tl.Text = text .. ": " .. v
        end)
        UserInputService.InputEnded:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then c:Disconnect() end end)
    end)
    return y + 65
end

local function AddPartSelector(page, y)
    local parts = {"Head", "UpperTorso", "HumanoidRootPart", "LeftHand", "RightHand"}
    local ly = y
    for _, pName in pairs(parts) do
        local b = Instance.new("TextButton", page)
        b.Size = UDim2.new(1, -10, 0, 40) b.Position = UDim2.new(0, 5, 0, ly)
        b.Text = "Target: " .. pName b.Font = Enum.Font.GothamBold b.TextColor3 = Color3.new(1,1,1) b.TextSize = 16
        b.Name = (Config.Aimbot.TargetPart == pName) and "Part_Selected" or "Part_Idle"
        b.BackgroundColor3 = (Config.Aimbot.TargetPart == pName) and Config.Visuals.Color or Color3.fromRGB(35,35,35)
        Instance.new("UICorner", b).CornerRadius = UDim.new(0, 10)
        b.MouseButton1Click:Connect(function()
            Config.Aimbot.TargetPart = pName
            for _, v in pairs(page:GetChildren()) do if v:IsA("TextButton") and v.Text:find("Target:") then v.BackgroundColor3 = Color3.fromRGB(35,35,35) v.Name = "Part_Idle" end end
            b.BackgroundColor3 = Config.Visuals.Color b.Name = "Part_Selected"
        end)
        ly = ly + 45
    end
    return ly
end

local ay = 0
ay = AddToggle(Pages.Aimbot, "Aimbot [Z]", Config.Aimbot, "Enabled", ay)
ay = AddSlider(Pages.Aimbot, "Field of View", Config.Aimbot, "Fov", ay, 10, 800)
ay = AddSlider(Pages.Aimbot, "Smooth Speed", Config.Aimbot, "Smooth", ay, 0.01, 1)
ay = AddSlider(Pages.Aimbot, "Max Distance", Config.Aimbot, "MaxDist", ay, 10, 1000)
ay = AddPartSelector(Pages.Aimbot, ay)

local vy = 0
vy = AddToggle(Pages.Visuals, "Enable Chams", Config.Visuals, "Chams", vy)

local unl = Instance.new("TextButton", Pages.Misc)
unl.Size = UDim2.new(1, -10, 0, 55) unl.Position = UDim2.new(0, 5, 0, 0)
unl.BackgroundColor3 = Color3.fromRGB(200, 40, 40) unl.Text = "UNLOAD SCRIPT" unl.TextColor3 = Color3.new(1, 1, 1) unl.Font = Enum.Font.GothamBold unl.TextSize = 20
Instance.new("UICorner", unl).CornerRadius = UDim.new(0, 12)
unl.MouseButton1Click:Connect(function() _G.GeminiActive = false Gui:Destroy() dragConn:Disconnect() end)

local function RefreshFriends()
    if not Pages.Friends then return end
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
task.spawn(function() while task.wait(5) do if Gui and Gui.Parent then RefreshFriends() end end end)
RefreshFriends()

-- [ ЖИРНЫЙ FOV ]
local FOV = Drawing.new("Circle") 
FOV.Thickness = 2.5 -- Жирность увеличена
FOV.NumSides = 90 
FOV.Filled = false
_G.GeminiActive = true

local function GetTarget()
    local mousePos = UserInputService:GetMouseLocation()
    if currentTarget then
        local char = currentTarget.Parent
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if not char or not hum or hum.Health <= 0 or not Config.Aimbot.Enabled then
            currentTarget = nil
        else
            local vpos, vis = Camera:WorldToViewportPoint(currentTarget.Position)
            local screenDist = (Vector2.new(vpos.X, vpos.Y) - mousePos).Magnitude
            local worldDist = (currentTarget.Position - LocalPlayer.Character.HumanoidRootPart.Position).Magnitude
            if screenDist < (Config.Aimbot.Fov * 1.5) and worldDist <= Config.Aimbot.MaxDist then
                return currentTarget
            else
                currentTarget = nil 
            end
        end
    end
    local target = nil
    local minWorldDist = math.huge
    for _, p in pairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and not table.find(Config.Friends, p.Name) and p.Character then
            local part = p.Character:FindFirstChild(Config.Aimbot.TargetPart) or p.Character:FindFirstChild("HumanoidRootPart")
            local hum = p.Character:FindFirstChildOfClass("Humanoid")
            if part and hum and hum.Health > 0 then
                local vpos, vis = Camera:WorldToViewportPoint(part.Position)
                local screenDist = (Vector2.new(vpos.X, vpos.Y) - mousePos).Magnitude
                local worldDist = (part.Position - LocalPlayer.Character.HumanoidRootPart.Position).Magnitude
                if (screenDist < Config.Aimbot.Fov and worldDist <= Config.Aimbot.MaxDist) or screenDist < 20 then
                    if worldDist < minWorldDist then
                        minWorldDist = worldDist
                        target = part
                    end
                end
            end
        end
    end
    currentTarget = target
    return target
end

RunService.RenderStepped:Connect(function()
    if not _G.GeminiActive then FOV.Visible = false return end
    FOV.Visible = Config.Aimbot.Enabled 
    FOV.Radius = Config.Aimbot.Fov 
    FOV.Position = UserInputService:GetMouseLocation() 
    FOV.Color = Config.Visuals.Color
    
    if Config.Aimbot.Enabled then
        local t = GetTarget()
        if t then 
            Camera.CFrame = Camera.CFrame:Lerp(CFrame.new(Camera.CFrame.Position, t.Position), Config.Aimbot.Smooth) 
        end
    else
        currentTarget = nil 
    end

    for _, p in pairs(Players:GetPlayers()) do
        if p == LocalPlayer then continue end
        local char = p.Character
        if char and char:FindFirstChild("Humanoid") then
            local cham = char:FindFirstChild("GeminiCham")
            if Config.Visuals.Enabled and Config.Visuals.Chams and char.Humanoid.Health > 0 then
                if not cham then cham = Instance.new("Highlight", char) cham.Name = "GeminiCham" end
                local isF = table.find(Config.Friends, p.Name)
                cham.FillColor = isF and Color3.fromRGB(0, 150, 255) or Config.Visuals.Color
                cham.Enabled = true
            elseif cham then cham.Enabled = false end
        end
    end
end)

UserInputService.InputBegan:Connect(function(i, gpe)
    if not gpe then
        if i.KeyCode == Config.MenuKey then Main.Visible = not Main.Visible end
        if i.KeyCode == Config.AimKey then 
            Config.Aimbot.Enabled = not Config.Aimbot.Enabled 
            UpdateInterface()
        end
    end
end)
