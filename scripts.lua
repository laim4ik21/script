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
    Settings = {
        MenuTransparency = 0,
        MenuR = 15, MenuG = 15, MenuB = 15,
        TextR = 255, TextG = 255, TextB = 255,
        MenuKey = Enum.KeyCode.T
    }
}

local lockedTarget = nil
local flyVelocity = nil
local listeningForKey = false

local Gui = Instance.new("ScreenGui", LocalPlayer:WaitForChild("PlayerGui"))
Gui.Name = "Gemini_V44_Restored"
Gui.ResetOnSpawn = false

local Main = Instance.new("Frame", Gui)
Main.Size = UDim2.new(0, 550, 0, 550)
Main.Position = UDim2.new(0.5, -275, 0.5, -275)
Main.BorderSizePixel = 0
Main.Active = true
Instance.new("UICorner", Main).CornerRadius = UDim.new(0, 12)

local UIStroke = Instance.new("UIStroke", Main)
UIStroke.Thickness = 3
UIStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

local Sidebar = Instance.new("Frame", Main)
Sidebar.Size = UDim2.new(0, 140, 1, 0)
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
    Misc = Instance.new("ScrollingFrame", Container),
    Settings = Instance.new("ScrollingFrame", Container)
}

for name, p in pairs(Pages) do
    p.Size = UDim2.new(1, 0, 1, 0) p.BackgroundTransparency = 1 p.Visible = (name == "Aimbot") p.ScrollBarThickness = 2 p.CanvasSize = UDim2.new(0, 0, 2.5, 0)
end

local function UpdateInterface()
    local mainCol = Color3.fromRGB(Config.Settings.MenuR, Config.Settings.MenuG, Config.Settings.MenuB)
    local textCol = Color3.fromRGB(Config.Settings.TextR, Config.Settings.TextG, Config.Settings.TextB)
    local accentCol = Color3.fromRGB(Config.Visuals.R, Config.Visuals.G, Config.Visuals.B)
    local trans = Config.Settings.MenuTransparency
    
    UIStroke.Color = accentCol
    Main.BackgroundColor3 = mainCol
    Main.BackgroundTransparency = trans
    Sidebar.BackgroundColor3 = mainCol
    Sidebar.BackgroundTransparency = trans
    
    for _, v in pairs(Main:GetDescendants()) do
        if v:IsA("TextLabel") or v:IsA("TextButton") then
            v.TextColor3 = textCol
            if v:IsA("TextButton") then
                if v.Name == "Toggle_Active" or v.Name == "Part_Selected" then 
                    v.BackgroundColor3 = accentCol
                    v.BackgroundTransparency = trans
                elseif v.Name == "Friend_Active" then
                    v.BackgroundColor3 = Color3.fromRGB(0, 120, 255)
                    v.BackgroundTransparency = trans
                elseif v.Name == "Tab_Button" then
                    v.BackgroundTransparency = 1
                else
                    v.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
                    v.BackgroundTransparency = math.clamp(trans + 0.1, 0, 1)
                end
            end
        end
        if v:IsA("Frame") and v.Name == "Slider_Bar" then 
            v.BackgroundColor3 = accentCol 
            v.BackgroundTransparency = trans
        end
    end
end

local function AddToggle(page, text, tbl, key, y)
    local btn = Instance.new("TextButton", page)
    btn.Size = UDim2.new(1, -10, 0, 40) btn.Position = UDim2.new(0, 5, 0, y) 
    btn.Name = tbl[key] and "Toggle_Active" or "Toggle_Idle"
    btn.Font = Enum.Font.GothamBold btn.Text = text btn.TextSize = 14
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 10)
    btn.MouseButton1Click:Connect(function()
        tbl[key] = not tbl[key]
        btn.Name = tbl[key] and "Toggle_Active" or "Toggle_Idle"
        UpdateInterface()
    end)
    return y + 45
end

local function AddSlider(page, text, tbl, key, y, min, max)
    local tl = Instance.new("TextLabel", page) 
    tl.Size = UDim2.new(1, -10, 0, 30) tl.Position = UDim2.new(0, 5, 0, y) tl.Text = text .. ": " .. tostring(tbl[key]) 
    tl.BackgroundTransparency = 1 tl.Font = Enum.Font.GothamBold tl.TextSize = 14 tl.TextXAlignment = Enum.TextXAlignment.Left
    local sld = Instance.new("TextButton", page) sld.Size = UDim2.new(1, -10, 0, 16) sld.Position = UDim2.new(0, 5, 0, y+32) sld.Text = "" sld.BackgroundColor3 = Color3.fromRGB(45, 45, 45) sld.AutoButtonColor = false
    Instance.new("UICorner", sld).CornerRadius = UDim.new(0, 8)
    local bar = Instance.new("Frame", sld) bar.Name = "Slider_Bar" bar.Size = UDim2.new(math.clamp((tbl[key] - min) / (max - min), 0, 1), 0, 1, 0) bar.BorderSizePixel = 0
    Instance.new("UICorner", bar).CornerRadius = UDim.new(0, 8)
    sld.MouseButton1Down:Connect(function()
        local moveConn = RunService.RenderStepped:Connect(function()
            local ratio = math.clamp((UserInputService:GetMouseLocation().X - sld.AbsolutePosition.X) / sld.AbsoluteSize.X, 0, 1)
            local value = min + (max - min) * ratio
            value = max > 10 and math.floor(value) or math.floor(value * 100) / 100
            tbl[key] = value bar.Size = UDim2.new(ratio, 0, 1, 0) tl.Text = text .. ": " .. tostring(value) UpdateInterface()
        end)
        local releaseConn; releaseConn = UserInputService.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then moveConn:Disconnect() releaseConn:Disconnect() end
        end)
    end)
    return y + 65
end

local function AddPartSelector(page, y)
    local parts = {["Head"]="Head", ["Torso"]="UpperTorso", ["Root"]="HumanoidRootPart", ["Arms"]="RightUpperArm", ["Legs"]="RightUpperLeg"}
    local ly = y
    local label = Instance.new("TextLabel", page)
    label.Size = UDim2.new(1,-10,0,30) label.Position = UDim2.new(0,5,0,ly) label.Text = "TARGET PART:" label.BackgroundTransparency = 1 label.Font = Enum.Font.GothamBold label.TextSize = 14
    ly = ly + 35
    for dName, rName in pairs(parts) do
        local b = Instance.new("TextButton", page)
        b.Size = UDim2.new(1, -10, 0, 35) b.Position = UDim2.new(0, 5, 0, ly)
        b.Text = dName b.Font = Enum.Font.GothamBold b.TextSize = 14
        b.Name = (Config.Aimbot.TargetPart == rName) and "Part_Selected" or "Part_Idle"
        Instance.new("UICorner", b).CornerRadius = UDim.new(0, 8)
        b.MouseButton1Click:Connect(function()
            Config.Aimbot.TargetPart = rName
            for _, v in pairs(page:GetChildren()) do if v.Name == "Part_Selected" or v.Name == "Part_Idle" then v.Name = "Part_Idle" end end
            b.Name = "Part_Selected" UpdateInterface()
        end)
        ly = ly + 40
    end
    return ly
end

local function RefreshFriends()
    Pages.Friends:ClearAllChildren()
    local fy = 0
    for _, p in pairs(Players:GetPlayers()) do
        if p == LocalPlayer then continue end
        local isF = table.find(Config.Friends, p.Name)
        local btn = Instance.new("TextButton", Pages.Friends)
        btn.Size = UDim2.new(1, -10, 0, 40) btn.Position = UDim2.new(0, 5, 0, fy)
        btn.Name = isF and "Friend_Active" or "Friend_Idle"
        btn.Text = p.Name btn.Font = Enum.Font.GothamBold btn.TextSize = 16
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 10)
        btn.MouseButton1Click:Connect(function()
            local idx = table.find(Config.Friends, p.Name)
            if idx then table.remove(Config.Friends, idx) else table.insert(Config.Friends, p.Name) end
            RefreshFriends()
        end)
        fy = fy + 45
    end
    UpdateInterface()
end
Players.PlayerAdded:Connect(RefreshFriends) Players.PlayerRemoving:Connect(RefreshFriends)

local function CreateTab(name, y)
    local b = Instance.new("TextButton", Sidebar)
    b.Name = "Tab_Button"
    b.Size = UDim2.new(1, -10, 0, 45) b.Position = UDim2.new(0, 5, 0, y + 5) 
    b.Text = name:upper() b.Font = Enum.Font.GothamBold b.TextSize = 13
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 8)
    b.MouseButton1Click:Connect(function() 
        for n, p in pairs(Pages) do p.Visible = (n == name) end 
        if name == "Friends" then RefreshFriends() end
    end)
end

CreateTab("Aimbot", 0) CreateTab("Visuals", 50) CreateTab("Friends", 100) CreateTab("Misc", 150) CreateTab("Settings", 200)

local ay = 0
ay = AddToggle(Pages.Aimbot, "Aimbot [Z]", Config.Aimbot, "Enabled", ay)
ay = AddSlider(Pages.Aimbot, "FOV", Config.Aimbot, "Fov", ay, 10, 800)
ay = AddSlider(Pages.Aimbot, "Smooth", Config.Aimbot, "Smooth", ay, 0.01, 1)
ay = AddSlider(Pages.Aimbot, "Max Distance", Config.Aimbot, "MaxDist", ay, 10, 2000)
ay = AddPartSelector(Pages.Aimbot, ay)

local vy = 0
vy = AddToggle(Pages.Visuals, "Chams", Config.Visuals, "Chams", vy)
vy = AddSlider(Pages.Visuals, "Accent R", Config.Visuals, "R", vy, 0, 255)
vy = AddSlider(Pages.Visuals, "Accent G", Config.Visuals, "G", vy, 0, 255)
vy = AddSlider(Pages.Visuals, "Accent B", Config.Visuals, "B", vy, 0, 255)

local sy = 0
sy = AddSlider(Pages.Settings, "Transparency", Config.Settings, "MenuTransparency", sy, 0, 1)
sy = AddSlider(Pages.Settings, "Menu R", Config.Settings, "MenuR", sy, 0, 255)
sy = AddSlider(Pages.Settings, "Menu G", Config.Settings, "MenuG", sy, 0, 255)
sy = AddSlider(Pages.Settings, "Menu B", Config.Settings, "MenuB", sy, 0, 255)
sy = AddSlider(Pages.Settings, "Text R", Config.Settings, "TextR", sy, 0, 255)
sy = AddSlider(Pages.Settings, "Text G", Config.Settings, "TextG", sy, 0, 255)
sy = AddSlider(Pages.Settings, "Text B", Config.Settings, "TextB", sy, 0, 255)

local function CreateBind(page, y)
    local btn = Instance.new("TextButton", page)
    btn.Size = UDim2.new(1, -10, 0, 45) btn.Position = UDim2.new(0, 5, 0, y)
    btn.Text = "Menu Key: " .. Config.Settings.MenuKey.Name
    btn.Font = Enum.Font.GothamBold btn.TextSize = 14
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 10)
    btn.MouseButton1Click:Connect(function() listeningForKey = true btn.Text = "..." end)
    UserInputService.InputBegan:Connect(function(i)
        if listeningForKey and i.UserInputType == Enum.UserInputType.Keyboard then
            Config.Settings.MenuKey = i.KeyCode btn.Text = "Menu Key: " .. i.KeyCode.Name listeningForKey = false
        end
    end)
    return y + 50
end
sy = CreateBind(Pages.Settings, sy)

local my = 0
my = AddToggle(Pages.Misc, "Fly", Config.Misc, "FlyEnabled", my)
my = AddSlider(Pages.Misc, "Fly Speed", Config.Misc, "FlySpeed", my, 10, 300)

local FOV = Drawing.new("Circle")
FOV.Thickness = 4 FOV.NumSides = 60

local function GetNewTarget()
    local mousePos = UserInputService:GetMouseLocation()
    local target, minWorldDist = nil, math.huge
    for _, p in pairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and not table.find(Config.Friends, p.Name) and p.Character then
            local part = p.Character:FindFirstChild(Config.Aimbot.TargetPart) or p.Character:FindFirstChild("HumanoidRootPart")
            if part and p.Character:FindFirstChildOfClass("Humanoid") and p.Character:FindFirstChildOfClass("Humanoid").Health > 0 then
                local vpos, vis = Camera:WorldToViewportPoint(part.Position)
                if vis then
                    local screenDist = (Vector2.new(vpos.X, vpos.Y) - mousePos).Magnitude
                    if screenDist < Config.Aimbot.Fov then
                        local worldDist = (part.Position - (LocalPlayer.Character and LocalPlayer.Character.HumanoidRootPart.Position or Vector3.zero)).Magnitude
                        if worldDist < minWorldDist then minWorldDist = worldDist target = part end
                    end
                end
            end
        end
    end
    return target
end

RunService.RenderStepped:Connect(function()
    FOV.Visible = Config.Aimbot.Enabled FOV.Radius = Config.Aimbot.Fov FOV.Position = UserInputService:GetMouseLocation() FOV.Color = Config.Visuals.Color
    if Config.Aimbot.Enabled then
        if not (lockedTarget and lockedTarget.Parent and lockedTarget.Parent:FindFirstChildOfClass("Humanoid") and lockedTarget.Parent:FindFirstChildOfClass("Humanoid").Health > 0) then
            lockedTarget = GetNewTarget()
        end
        if lockedTarget then
            Camera.CFrame = Camera.CFrame:Lerp(CFrame.new(Camera.CFrame.Position, lockedTarget.Position), Config.Aimbot.Smooth)
        end
    else lockedTarget = nil end

    if Config.Visuals.Chams then
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Character then
                local h = p.Character:FindFirstChild("GeminiCham") or Instance.new("Highlight", p.Character)
                h.Name = "GeminiCham"
                h.FillColor = (Config.Aimbot.Enabled and lockedTarget and p.Character == lockedTarget.Parent) and Color3.new(1,0,0) or (table.find(Config.Friends, p.Name) and Color3.fromRGB(0, 120, 255) or Config.Visuals.Color)
                h.Enabled = true
            end
        end
    end

    if Config.Misc.FlyEnabled and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
        local root = LocalPlayer.Character.HumanoidRootPart
        if not flyVelocity then flyVelocity = Instance.new("BodyVelocity", root) flyVelocity.MaxForce = Vector3.new(1,1,1) * 10^6 end
        local md = LocalPlayer.Character.Humanoid.MoveDirection
        local up = (UserInputService:IsKeyDown(Enum.KeyCode.Space) and 1 or 0) - (UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) and 1 or 0)
        flyVelocity.Velocity = (md * Config.Misc.FlySpeed) + (Vector3.new(0,1,0) * up * Config.Misc.FlySpeed)
        root.AssemblyLinearVelocity = Vector3.zero
    elseif flyVelocity then flyVelocity:Destroy() flyVelocity = nil end
end)

local dragging, dragInput, dragStart, startPos
Main.InputBegan:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = true dragStart = input.Position startPos = Main.Position end end)
Main.InputChanged:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseMovement then dragInput = input end end)
UserInputService.InputEnded:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end end)
RunService.RenderStepped:Connect(function() if dragging and dragInput then local delta = dragInput.Position - dragStart Main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y) end end)

UserInputService.InputBegan:Connect(function(i, gpe)
    if not gpe then
        if i.KeyCode == Config.Settings.MenuKey then Main.Visible = not Main.Visible end
        if i.KeyCode == Enum.KeyCode.Z then Config.Aimbot.Enabled = not Config.Aimbot.Enabled UpdateInterface() end
    end
end)

UpdateInterface()
