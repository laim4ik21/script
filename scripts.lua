local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local Lighting = game:GetService("Lighting") 
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

local Config = {
    Aimbot = {
        Enabled = false, 
        Fov = 150, 
        Smooth = 0.2, 
        TargetPart = "Head", 
        MaxDist = 500,
        SilentMode = false 
    },
    Visuals = {Enabled = true, Chams = true, Color = Color3.fromRGB(180, 100, 255), R = 180, G = 100, B = 255},
    Friends = {List = {}, QuickBind = Enum.KeyCode.Y},
    Misc = {
        FlyEnabled = false, 
        FlySpeed = 50, 
        NoSlow = false,
        FreeCam = false,
        FreeCamSpeed = 0.5,
        ClickTP = true,
        NoFOV = false,      -- Фиксация FOV камеры
        DefaultFOV = 70,    -- Значение FOV камеры
        HideAimbotFov = false -- НОВОЕ: Скрыть круг аимбота
    },
    Shaders = { 
        ActiveProfile = "None"
    },
    Settings = {
        MenuTransparency = 0,
        MenuR = 15, MenuG = 15, MenuB = 15,
        TextR = 255, TextG = 255, TextB = 255,
        MenuKey = Enum.KeyCode.T,
        SelectedFont = Enum.Font.GothamBold 
    }
}

-- Визуальная метка для ТП
local TPMarker = Instance.new("Part")
TPMarker.Name = "TP_Indicator"
TPMarker.Shape = Enum.PartType.Ball
TPMarker.Size = Vector3.new(2, 2, 2)
TPMarker.Color = Color3.fromRGB(255, 0, 0)
TPMarker.Material = Enum.Material.Neon
TPMarker.Anchored = true
TPMarker.CanCollide = false
TPMarker.Transparency = 1
TPMarker.Parent = workspace

local Bloom = Lighting:FindFirstChild("GeminiBloom") or Instance.new("BloomEffect", Lighting)
Bloom.Name = "GeminiBloom"
local ColorCorr = Lighting:FindFirstChild("GeminiCorr") or Instance.new("ColorCorrectionEffect", Lighting)
ColorCorr.Name = "GeminiCorr"

local lockedTarget = nil
local flyVelocity = nil
local listeningForKey = false
local listeningForFriendKey = false
local freeCamRotX, freeCamRotY = 0, 0

local Gui = Instance.new("ScreenGui", LocalPlayer:WaitForChild("PlayerGui"))
Gui.Name = "Gemini_V51_SilentLock"
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
    Shaders = Instance.new("ScrollingFrame", Container), 
    Settings = Instance.new("ScrollingFrame", Container)
}

for name, p in pairs(Pages) do
    p.Size = UDim2.new(1, 0, 1, 0) 
    p.BackgroundTransparency = 1 
    p.Visible = (name == "Aimbot") 
    p.ScrollBarThickness = 2 
    p.CanvasSize = (name == "Settings") and UDim2.new(0, 0, 5, 0) or UDim2.new(0, 0, 2.5, 0)
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
            v.Font = Config.Settings.SelectedFont 
            v.RichText = true
            if v:IsA("TextButton") then
                if v.Name == "Toggle_Active" or v.Name == "Part_Selected" or v.Name == "Shader_Active" or v.Name == "Font_Active" then 
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
        if v:IsA("Frame") and v.Name == "Slider_Bar" then v.BackgroundColor3 = accentCol v.BackgroundTransparency = trans end
    end
end

local function AddToggle(page, text, tbl, key, y)
    local btn = Instance.new("TextButton", page)
    btn.Size = UDim2.new(1, -10, 0, 40) btn.Position = UDim2.new(0, 5, 0, y) 
    btn.Name = tbl[key] and "Toggle_Active" or "Toggle_Idle"
    btn.Text = text btn.TextSize = 13
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
    tl.Size = UDim2.new(1, -10, 0, 25) tl.Position = UDim2.new(0, 5, 0, y) tl.Text = text .. ": " .. tostring(tbl[key]) 
    tl.BackgroundTransparency = 1 tl.TextSize = 13 tl.TextXAlignment = Enum.TextXAlignment.Left
    local sld = Instance.new("TextButton", page) sld.Size = UDim2.new(1, -10, 0, 14) sld.Position = UDim2.new(0, 5, 0, y+28) sld.Text = "" sld.BackgroundColor3 = Color3.fromRGB(45, 45, 45) sld.AutoButtonColor = false
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
    return y + 60
end

local function AddPartSelector(page, y)
    local parts = {["Head"]="Head", ["Torso"]="UpperTorso", ["Root"]="HumanoidRootPart", ["Arms"]="RightUpperArm", ["Legs"]="RightUpperLeg"}
    local ly = y
    local label = Instance.new("TextLabel", page)
    label.Size = UDim2.new(1,-10,0,25) label.Position = UDim2.new(0,5,0,ly) label.Text = "TARGET PART:" label.BackgroundTransparency = 1 label.TextSize = 13
    ly = ly + 30
    for dName, rName in pairs(parts) do
        local b = Instance.new("TextButton", page)
        b.Size = UDim2.new(1, -10, 0, 35) b.Position = UDim2.new(0, 5, 0, ly)
        b.Text = dName b.TextSize = 13
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
    local bBtn = Instance.new("TextButton", Pages.Friends)
    bBtn.Size = UDim2.new(1, -10, 0, 40) bBtn.Position = UDim2.new(0, 5, 0, fy)
    bBtn.Text = "Quick Friend Bind: " .. Config.Friends.QuickBind.Name
    bBtn.TextSize = 13 Instance.new("UICorner", bBtn).CornerRadius = UDim.new(0, 10)
    bBtn.MouseButton1Click:Connect(function() listeningForFriendKey = true bBtn.Text = "..." end)
    fy = 45
    for _, p in pairs(Players:GetPlayers()) do
        if p == LocalPlayer then continue end
        local isF = table.find(Config.Friends.List, p.Name)
        local btn = Instance.new("TextButton", Pages.Friends)
        btn.Size = UDim2.new(1, -10, 0, 35) btn.Position = UDim2.new(0, 5, 0, fy)
        btn.Name = isF and "Friend_Active" or "Friend_Idle"
        btn.Text = p.Name btn.TextSize = 13 Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 10)
        btn.MouseButton1Click:Connect(function()
            local idx = table.find(Config.Friends.List, p.Name)
            if idx then table.remove(Config.Friends.List, idx) else table.insert(Config.Friends.List, p.Name) end
            RefreshFriends()
        end)
        fy = fy + 40
    end
    UpdateInterface()
end
Players.PlayerAdded:Connect(RefreshFriends) Players.PlayerRemoving:Connect(RefreshFriends) RefreshFriends()

local function CreateTab(name, y)
    local b = Instance.new("TextButton", Sidebar)
    b.Name = "Tab_Button"
    b.Size = UDim2.new(1, -10, 0, 45) b.Position = UDim2.new(0, 5, 0, y + 5) 
    b.Text = name:upper() b.TextSize = 13 Instance.new("UICorner", b).CornerRadius = UDim.new(0, 8)
    b.MouseButton1Click:Connect(function() for n, p in pairs(Pages) do p.Visible = (n == name) end end)
end

CreateTab("Aimbot", 0) CreateTab("Visuals", 50) CreateTab("Friends", 100) CreateTab("Misc", 150) CreateTab("Shaders", 200) CreateTab("Settings", 250)

local ay = 0
ay = AddToggle(Pages.Aimbot, "Aimbot Enabled [Z]", Config.Aimbot, "Enabled", ay)
ay = AddToggle(Pages.Aimbot, "Character Look Only", Config.Aimbot, "SilentMode", ay)
ay = AddSlider(Pages.Aimbot, "FOV", Config.Aimbot, "Fov", ay, 10, 800)
ay = AddSlider(Pages.Aimbot, "Smooth", Config.Aimbot, "Smooth", ay, 0.01, 1)
ay = AddSlider(Pages.Aimbot, "Max Dist", Config.Aimbot, "MaxDist", ay, 50, 2000)
ay = AddPartSelector(Pages.Aimbot, ay)

local vy = 0
vy = AddToggle(Pages.Visuals, "Chams", Config.Visuals, "Chams", vy)
vy = AddSlider(Pages.Visuals, "Accent R", Config.Visuals, "R", vy, 0, 255)
vy = AddSlider(Pages.Visuals, "Accent G", Config.Visuals, "G", vy, 0, 255)
vy = AddSlider(Pages.Visuals, "Accent B", Config.Visuals, "B", vy, 0, 255)

local my = 0
my = AddToggle(Pages.Misc, "Fly", Config.Misc, "FlyEnabled", my)
my = AddSlider(Pages.Misc, "Fly Speed", Config.Misc, "FlySpeed", my, 10, 300)
my = AddToggle(Pages.Misc, "Free Cam", Config.Misc, "FreeCam", my)
my = AddSlider(Pages.Misc, "Cam Speed", Config.Misc, "FreeCamSpeed", my, 0.1, 10)
my = AddToggle(Pages.Misc, "No Slowdown", Config.Misc, "NoSlow", my)
my = AddToggle(Pages.Misc, "Control Click TP", Config.Misc, "ClickTP", my)
my = AddToggle(Pages.Misc, "No FOV Change", Config.Misc, "NoFOV", my) -- Камера
my = AddSlider(Pages.Misc, "Custom FOV", Config.Misc, "DefaultFOV", my, 30, 120)
my = AddToggle(Pages.Misc, "Hide Aimbot FOV", Config.Misc, "HideAimbotFov", my) -- АИМБОТ КРУГ

local function AddShaderBtn(name, prof, y)
    local b = Instance.new("TextButton", Pages.Shaders)
    b.Size = UDim2.new(1, -10, 0, 40) b.Position = UDim2.new(0, 5, 0, y)
    b.Text = name b.Name = (Config.Shaders.ActiveProfile == prof) and "Shader_Active" or "Shader_Idle"
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 10)
    b.MouseButton1Click:Connect(function()
        Config.Shaders.ActiveProfile = prof
        for _, v in pairs(Pages.Shaders:GetChildren()) do if v:IsA("TextButton") then v.Name = "Shader_Idle" end end
        b.Name = "Shader_Active" UpdateInterface()
    end)
    return y + 45
end
local shy = 0
shy = AddShaderBtn("RESET", "None", shy)
shy = AddShaderBtn("SPRING V2", "SpringV2", shy)
shy = AddShaderBtn("SOVA", "SovA", shy)
shy = AddShaderBtn("VELORA", "Velora", shy)

local sy = 0
sy = AddSlider(Pages.Settings, "Transparency", Config.Settings, "MenuTransparency", sy, 0, 1)
sy = AddSlider(Pages.Settings, "Menu R", Config.Settings, "MenuR", sy, 0, 255)
sy = AddSlider(Pages.Settings, "Menu G", Config.Settings, "MenuG", sy, 0, 255)
sy = AddSlider(Pages.Settings, "Menu B", Config.Settings, "MenuB", sy, 0, 255)
sy = AddSlider(Pages.Settings, "Text R", Config.Settings, "TextR", sy, 0, 255)
sy = AddSlider(Pages.Settings, "Text G", Config.Settings, "TextG", sy, 0, 255)
sy = AddSlider(Pages.Settings, "Text B", Config.Settings, "TextB", sy, 0, 255)

local function AddFontBtn(font, y)
    local b = Instance.new("TextButton", Pages.Settings)
    b.Size = UDim2.new(1, -10, 0, 30) b.Position = UDim2.new(0, 5, 0, y)
    b.Text = "FONT: " .. font.Name b.Name = (Config.Settings.SelectedFont == font) and "Font_Active" or "Font_Idle"
    b.TextSize = 12
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 5)
    b.MouseButton1Click:Connect(function()
        Config.Settings.SelectedFont = font
        for _, v in pairs(Pages.Settings:GetChildren()) do if v.Name:find("Font") then v.Name = "Font_Idle" end end
        b.Name = "Font_Active" UpdateInterface()
    end)
    return y + 35
end

local allFonts = Enum.Font:GetEnumItems()
table.sort(allFonts, function(a,b) return a.Name < b.Name end)
for _, font in pairs(allFonts) do
    sy = AddFontBtn(font, sy)
end

local mBtn = Instance.new("TextButton", Pages.Settings)
mBtn.Size = UDim2.new(1, -10, 0, 40) mBtn.Position = UDim2.new(0, 5, 0, sy)
mBtn.Text = "Menu Key: " .. Config.Settings.MenuKey.Name
mBtn.TextSize = 13 Instance.new("UICorner", mBtn).CornerRadius = UDim.new(0, 10)
mBtn.MouseButton1Click:Connect(function() listeningForKey = true mBtn.Text = "..." end)

local FOV_Circle = Drawing.new("Circle")
FOV_Circle.Thickness = 2 FOV_Circle.NumSides = 60

local function IsValidTarget(part)
    if not part or not part.Parent then return false end
    local hum = part.Parent:FindFirstChildOfClass("Humanoid")
    return hum and hum.Health > 0
end

-- CLICK TP
UserInputService.InputBegan:Connect(function(input, gpe)
    if not gpe and Config.Misc.ClickTP and input.UserInputType == Enum.UserInputType.MouseButton1 and UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
        local mousePos = UserInputService:GetMouseLocation()
        local ray = Camera:ViewportPointToRay(mousePos.X, mousePos.Y)
        local raycastResult = workspace:Raycast(ray.Origin, ray.Direction * 2000)
        
        if raycastResult and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
            local root = LocalPlayer.Character.HumanoidRootPart
            local targetPos = raycastResult.Position + Vector3.new(0, 3, 0)
            
            TPMarker.Position = raycastResult.Position
            TPMarker.Transparency = 0
            task.delay(0.5, function() TPMarker.Transparency = 1 end)
            
            local function TeleportWithCheck()
                root.CFrame = CFrame.new(targetPos)
                task.wait(0.1)
                if (root.Position - targetPos).Magnitude > 5 then
                    root.CFrame = CFrame.new(targetPos)
                end
            end
            TeleportWithCheck()
        end
    end
end)

RunService:BindToRenderStep("FreeCam_Logic", Enum.RenderPriority.Camera.Value + 1, function(dt)
    if Config.Misc.FreeCam then
        Camera.CameraType = Enum.CameraType.Scriptable
        local look = Vector3.new()
        local right = Vector3.new()
        local up = Vector3.new()
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then look = Camera.CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then look = -Camera.CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then right = Camera.CFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then right = -Camera.CFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.E) then up = Vector3.new(0,1,0) end
        if UserInputService:IsKeyDown(Enum.KeyCode.Q) then up = Vector3.new(0,-1,0) end
        local move = (look + right + up)
        if move.Magnitude > 0 then
            Camera.CFrame = Camera.CFrame + (move.Unit * Config.Misc.FlySpeed * Config.Misc.FreeCamSpeed * dt)
        end
        if UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then
            local delta = UserInputService:GetMouseDelta()
            freeCamRotX = freeCamRotX - delta.Y * 0.15
            freeCamRotY = freeCamRotY - delta.X * 0.15
            Camera.CFrame = CFrame.new(Camera.CFrame.Position) * CFrame.Angles(0, math.rad(freeCamRotY), 0) * CFrame.Angles(math.rad(freeCamRotX), 0, 0)
            UserInputService.MouseBehavior = Enum.MouseBehavior.LockCurrentPosition
        else
            UserInputService.MouseBehavior = Enum.MouseBehavior.Default
        end
    end
end)

RunService.RenderStepped:Connect(function()
    local prof = Config.Shaders.ActiveProfile
    if prof == "None" then
        Bloom.Enabled = false ColorCorr.Enabled = false
    elseif prof == "SpringV2" then
        Bloom.Enabled = true Bloom.Intensity = 2.5 Bloom.Threshold = 0.5 ColorCorr.Enabled = true ColorCorr.Contrast = 0.1 ColorCorr.Saturation = 0.5
    elseif prof == "SovA" then
        Bloom.Enabled = true Bloom.Intensity = 0.6 Bloom.Threshold = 1 ColorCorr.Enabled = true ColorCorr.Contrast = 0.3 ColorCorr.Saturation = -0.2 ColorCorr.TintColor = Color3.fromRGB(220, 240, 255)
    elseif prof == "Velora" then
        Bloom.Enabled = true Bloom.Intensity = 1.2 Bloom.Threshold = 0.8 ColorCorr.Enabled = true ColorCorr.Contrast = 0.5 ColorCorr.Saturation = 0.3
    end

    local accent = Color3.fromRGB(Config.Visuals.R, Config.Visuals.G, Config.Visuals.B)
    
    -- ЛОГИКА КРУГА FOV АИМБОТА
    if Config.Aimbot.Enabled and not Config.Misc.HideAimbotFov then
        FOV_Circle.Visible = true
        FOV_Circle.Radius = Config.Aimbot.Fov
        FOV_Circle.Position = UserInputService:GetMouseLocation()
        FOV_Circle.Color = accent
    else
        FOV_Circle.Visible = false
    end
    
    -- ФИКСАЦИЯ FOV КАМЕРЫ
    if Config.Misc.NoFOV then
        Camera.FieldOfView = Config.Misc.DefaultFOV
    end

    if Config.Aimbot.Enabled then
        if lockedTarget and not IsValidTarget(lockedTarget) then lockedTarget = nil end
        if not lockedTarget then
            local mouse = UserInputService:GetMouseLocation()
            local bestTarget, minDist = nil, math.huge
            for _, p in pairs(Players:GetPlayers()) do
                if p ~= LocalPlayer and p.Character and not table.find(Config.Friends.List, p.Name) then
                    local part = p.Character:FindFirstChild(Config.Aimbot.TargetPart) or p.Character:FindFirstChild("HumanoidRootPart")
                    if part and p.Character.Humanoid.Health > 0 then
                        local vpos, vis = Camera:WorldToViewportPoint(part.Position)
                        if vis then
                            local d = (Vector2.new(vpos.X, vpos.Y) - mouse).Magnitude
                            local worldDist = (part.Position - Camera.CFrame.Position).Magnitude
                            if d < Config.Aimbot.Fov and worldDist < Config.Aimbot.MaxDist and d < minDist then
                                minDist = d bestTarget = part
                            end
                        end
                    end
                end
            end
            lockedTarget = bestTarget
        end
        if lockedTarget and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then 
            local root = LocalPlayer.Character.HumanoidRootPart
            if Config.Aimbot.SilentMode then
                local targetPos = Vector3.new(lockedTarget.Position.X, root.Position.Y, lockedTarget.Position.Z)
                root.CFrame = root.CFrame:Lerp(CFrame.lookAt(root.Position, targetPos), Config.Aimbot.Smooth)
            else
                Camera.CFrame = Camera.CFrame:Lerp(CFrame.new(Camera.CFrame.Position, lockedTarget.Position), Config.Aimbot.Smooth)
            end
        end
    else 
        lockedTarget = nil 
    end

    for _, p in pairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and p.Character then
            local h = p.Character:FindFirstChild("GeminiCham") or Instance.new("Highlight", p.Character)
            h.Name = "GeminiCham"
            h.Enabled = Config.Visuals.Chams
            h.OutlineTransparency = 0 h.FillTransparency = 0.5
            if lockedTarget and p.Character == lockedTarget.Parent then h.FillColor = Color3.new(1, 0, 0)
            elseif table.find(Config.Friends.List, p.Name) then h.FillColor = Color3.fromRGB(0, 120, 255)
            else h.FillColor = accent end
        end
    end

    local char = LocalPlayer.Character
    if char and char:FindFirstChild("Humanoid") then
        local hum = char.Humanoid
        local root = char:FindFirstChild("HumanoidRootPart")
        if Config.Misc.NoSlow then
            if hum.WalkSpeed < 16 then hum.WalkSpeed = 16 end
            if hum.JumpPower < 50 then hum.JumpPower = 50 end
        end
        if Config.Misc.FlyEnabled and root and not Config.Misc.FreeCam then
            if not flyVelocity then flyVelocity = Instance.new("BodyVelocity", root) flyVelocity.MaxForce = Vector3.new(1,1,1)*10^6 end
            local md = hum.MoveDirection
            local up = (UserInputService:IsKeyDown(Enum.KeyCode.Space) and 1 or 0) - (UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) and 1 or 0)
            flyVelocity.Velocity = (md * Config.Misc.FlySpeed) + (Vector3.new(0,1,0) * up * Config.Misc.FlySpeed)
            root.AssemblyLinearVelocity = Vector3.zero
        elseif flyVelocity then flyVelocity:Destroy() flyVelocity = nil end
    end
end)

UserInputService.InputBegan:Connect(function(i, gpe)
    if listeningForKey then Config.Settings.MenuKey = i.KeyCode listeningForKey = false UpdateInterface() return end
    if listeningForFriendKey then Config.Friends.QuickBind = i.KeyCode listeningForFriendKey = false RefreshFriends() return end
    if not gpe then
        if i.KeyCode == Config.Settings.MenuKey then Main.Visible = not Main.Visible end
        if i.KeyCode == Enum.KeyCode.Z then Config.Aimbot.Enabled = not Config.Aimbot.Enabled UpdateInterface() end
        if i.KeyCode == Config.Friends.QuickBind then
            local mouse = UserInputService:GetMouseLocation()
            local friendCandidate, shortestUIdist = nil, 60
            for _, p in pairs(Players:GetPlayers()) do
                if p ~= LocalPlayer and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
                    local vpos, vis = Camera:WorldToViewportPoint(p.Character.HumanoidRootPart.Position)
                    local screenDist = (Vector2.new(vpos.X, vpos.Y) - mouse).Magnitude
                    if screenDist < shortestUIdist then shortestUIdist = screenDist friendCandidate = p end
                end
            end
            if friendCandidate then
                local idx = table.find(Config.Friends.List, friendCandidate.Name)
                if idx then table.remove(Config.Friends.List, idx) else table.insert(Config.Friends.List, friendCandidate.Name) end
                RefreshFriends()
            end
        end
    end
end)

local dragging, dragInput, dragStart, startPos
Main.InputBegan:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = true dragStart = input.Position startPos = Main.Position end end)
Main.InputChanged:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseMovement then dragInput = input end end)
UserInputService.InputEnded:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end end)
RunService.RenderStepped:Connect(function() if dragging and dragInput then local delta = dragInput.Position - dragStart Main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y) end end)

UpdateInterface()
