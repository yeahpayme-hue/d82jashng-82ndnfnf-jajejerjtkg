if not game:IsLoaded() then game.Loaded:Wait() end
    pcall(function()
        for _, v in pairs(workspace:GetDescendants()) do
            if v.Name == "Slope" and v:IsA("BasePart") then
                v.CanCollide = false
            end
        end
    end)
    local Players      = game:GetService("Players")
    local RunService   = game:GetService("RunService")
    local UIS          = game:GetService("UserInputService")
    local TweenService = game:GetService("TweenService")
    local Lighting     = game:GetService("Lighting")
    local HttpService  = game:GetService("HttpService")
    local Stats        = game:GetService("Stats")
    local Player    = Players.LocalPlayer
    local Camera    = workspace.CurrentCamera
    local PlayerGui = (gethui and gethui()) or Player:WaitForChild("PlayerGui")
    local Config = {
        FastSpeed           = 54,
        FastSpeedKey        = Enum.KeyCode.T,
        CarrySpeed          = 29,
        BatDist             = 0,
        AutoBatKey          = Enum.KeyCode.V,
        AutoBatSpeed        = 58,
        GrabSpeed           = 0.1,
        GrabRange           = 30,
        ESPEnabled          = false,
        InfJumpEnabled      = false,
        AntiRagdollEnabled  = false,
        RagdollAutoTP       = false,
        FastSpeedState      = false,
        AutoBatState        = false,
        GrabState           = false,
        FpsBoostState       = false,
        NoAnimState         = false,
        FloatHeight         = 18,
        FloatSpeed          = 85,
        FloatState          = false,
        FloatKey            = Enum.KeyCode.F,
        Float2Height        = 10,
        Float2Speed         = 45,
        Float2State         = false,
        Float2Key           = Enum.KeyCode.J,
        NoclipPlayersState  = false,
        AutoTPRState        = false,
        AutoTPLState        = false,
        AutoTPKey           = Enum.KeyCode.G,
        StopOnLeft          = true,
        StopOnRight         = true,
        AutoPlayState       = false,
        AutoPlayKey         = Enum.KeyCode.H,
        AutoPlaySide        = "L",
        Step2Delay          = 0.05,
    }
    local KEYBIND_DEFAULTS = {
        FastSpeedKey = Enum.KeyCode.T,
        AutoBatKey   = Enum.KeyCode.V,
        FloatKey     = Enum.KeyCode.F,
        Float2Key    = Enum.KeyCode.J,
        AutoTPKey    = Enum.KeyCode.G,
        AutoPlayKey  = Enum.KeyCode.H,
    }
    local ConfigFile = "adv1se_final_config.json"
    local function SaveConfig()
        if not writefile then return end
        local data = {}
        for k, v in pairs(Config) do
            data[k] = typeof(v) == "EnumItem" and tostring(v) or v
        end
        writefile(ConfigFile, HttpService:JSONEncode(data))
    end
    local function LoadConfig()
        if not isfile or not isfile(ConfigFile) then return end
        local ok, data = pcall(function() return HttpService:JSONDecode(readfile(ConfigFile)) end)
        if not ok or not data then return end
        for k, v in pairs(data) do
            if KEYBIND_DEFAULTS[k] then
                local name = tostring(v):gsub("Enum.KeyCode.", "")
                Config[k] = Enum.KeyCode[name] or KEYBIND_DEFAULTS[k]
            else
                Config[k] = v
            end
        end
        Config.BatDist        = 0
        Config.Step2Delay     = 0.05
        Config.FloatHeight    = 18
        Config.FloatSpeed     = 85
        Config.Float2Speed    = 45
        Config.AutoBatSpeed   = 58
    end
    LoadConfig()
    for k, default in pairs(KEYBIND_DEFAULTS) do
        if typeof(Config[k]) ~= "EnumItem" then Config[k] = default end
    end
    local sharedSide = Config.AutoPlaySide == "R" and "R" or "L"
    local FastSpeedEnabled        = false
    local AutoBatEnabled          = false
    local GrabActive              = false
    local FloatEnabled            = false
    local FloatTargetY            = nil
    local FloatActiveSpeed        = nil
    local FloatDescending         = false
    local FloatDescendingStarted  = false
    local BrainrotSequenceRunning = false
    local Float2Enabled           = false
    local Float2TargetY           = nil
    local AutoBat_Float2WasActive = false
    local Interacting             = false
    local NoclipPlayersEnabled    = false
    local AutoTPREnabled          = false
    local AutoTPLEnabled          = false
    local AutoPlayEnabled         = false
    local AutoPlayRunning         = false
    local AutoPlayRestarting      = false
    local AutoPlayStartStep       = 1
    local NoAnimEnabled           = false
    local ESPTracers              = {}
    local InternalCache           = {}
    local AntiRagdollConnection   = nil
    local FastSpeedSetState    = nil
    local autoPlaySetState     = nil
    local dropBrainrotSetState = nil
    local float2SetState       = nil
    local _sideRowRefs = {}
    local TitlePills = { setL = nil, setR = nil }
    local PromptCache = {}
    local TP_SIDES = {
        R = { Step1 = Vector3.new(-473.42, -7.30, 22.15),  Step2 = Vector3.new(-482.89, -5.09, 26.45)  },
        L = { Step1 = Vector3.new(-470.56, -7.30, 100.08), Step2 = Vector3.new(-482.86, -5.09, 95.34) },
    }
    local AutoTPRunning = false
    local AutoPlayStepsL = {
        Vector3.new(-475.60, -7.20, 93.74),
        Vector3.new(-482.86, -5.09, 95.34),
        Vector3.new(-476.66, -6.69, 92.92),
        Vector3.new(-476.44, -6.75, 27.55),
        Vector3.new(-485.52, -5.05, 27.29),
    }
    local AutoPlayStepsR = {
        Vector3.new(-476.89, -6.99, 26.26),
        Vector3.new(-482.89, -5.09, 26.45),
        Vector3.new(-476.48, -6.76, 28.86),
        Vector3.new(-476.68, -6.59, 94.13),
        Vector3.new(-484.26, -5.35, 94.00),
    }
    local ZoneDefs = {
        Left  = { pos = Vector3.new(-496.2, -5.1, 100.1), size = Vector3.new(32, 6, 18) },
        Right = { pos = Vector3.new(-496.7, -5.3,  21.6), size = Vector3.new(32, 6, 18) },
    }
    local function isInZone(pos, zone)
        local d = pos - zone.pos
        return math.abs(d.X) < zone.size.X / 2 and math.abs(d.Z) < zone.size.Z / 2
    end
    local _groundCache = { y = 0, lastX = 0, lastZ = 0, lastTick = 0 }
    local function getGroundHeight(rootPos)
        local now = tick()
        local dx = math.abs(rootPos.X - _groundCache.lastX)
        local dz = math.abs(rootPos.Z - _groundCache.lastZ)
        if now - _groundCache.lastTick < 0.1 and dx < 2 and dz < 2 then
            return _groundCache.y
        end
        local origin = rootPos + Vector3.new(0, -0.5, 0)
        local params = RaycastParams.new()
        local excluded = {}
        if Player.Character then table.insert(excluded, Player.Character) end
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= Player and p.Character then table.insert(excluded, p.Character) end
        end
        params.FilterDescendantsInstances = excluded
        params.FilterType = Enum.RaycastFilterType.Exclude
        local remaining = 500
        local currentOrigin = origin
        while remaining > 0 do
            local result = workspace:Raycast(currentOrigin, Vector3.new(0, -remaining, 0), params)
            if not result then break end
            local part = result.Instance
            if part and part.CanCollide then
                _groundCache.y = result.Position.Y
                _groundCache.lastX = rootPos.X
                _groundCache.lastZ = rootPos.Z
                _groundCache.lastTick = now
                return result.Position.Y
            end
            local newOrigin = result.Position + Vector3.new(0, -0.05, 0)
            remaining = remaining - (currentOrigin.Y - newOrigin.Y)
            currentOrigin = newOrigin
        end
        return rootPos.Y - 500
    end
    local T = {
        bg0     = Color3.fromRGB(5,   8,   14),
        bg1     = Color3.fromRGB(10,  16,  26),
        bg2     = Color3.fromRGB(16,  26,  40),
        bg3     = Color3.fromRGB(24,  40,  60),
        text    = Color3.fromRGB(220, 235, 250),
        textMid = Color3.fromRGB(140, 180, 220),
        textLo  = Color3.fromRGB(55,  90,  130),
        ice     = Color3.fromRGB(160, 210, 240),
        green   = Color3.fromRGB(120, 200, 180),
        dotOn   = Color3.fromRGB(160, 210, 240),
        dotOff  = Color3.fromRGB(30,  55,  85),
        trackBg = Color3.fromRGB(20,  36,  54),
    }
    local function corner(p, r)
        local c = Instance.new("UICorner", p)
        c.CornerRadius = UDim.new(0, r or 6)
        return c
    end
    local function lbl(parent, text, size, col, font, xalign)
        local l = Instance.new("TextLabel", parent)
        l.BackgroundTransparency = 1
        l.Text           = text
        l.TextColor3     = col or T.text
        l.Font           = font or Enum.Font.GothamBold
        l.TextSize       = size or 12
        l.TextScaled     = false
        l.RichText       = false
        l.TextXAlignment = xalign or Enum.TextXAlignment.Left
        return l
    end
    local function tween(obj, t, props)
        TweenService:Create(obj, TweenInfo.new(t, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), props):Play()
    end
    local function switchSide(side)
        sharedSide = side
        Config.AutoPlaySide = side
        if side == "R" then
            AutoTPREnabled = true;  AutoTPLEnabled = false
            Config.AutoTPRState = true;  Config.AutoTPLState = false
        else
            AutoTPLEnabled = true;  AutoTPREnabled = false
            Config.AutoTPLState = true;  Config.AutoTPRState = false
        end
        if side == "L" then Config.StopOnLeft = true;  Config.StopOnRight = false
        else                Config.StopOnRight = true; Config.StopOnLeft  = false end
        for _, ref in ipairs(_sideRowRefs) do
            if ref.setSide then ref.setSide(side) end
        end
        if TitlePills.setL and TitlePills.setR then
            if side == "L" then TitlePills.setL(true); TitlePills.setR(false)
            else                TitlePills.setR(true); TitlePills.setL(false) end
        end
        if AutoPlayEnabled then AutoPlayRunning = false end
        SaveConfig()
    end
    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name         = "adv1se_GUI"
    ScreenGui.Parent       = PlayerGui
    ScreenGui.ResetOnSpawn = false
    local W, H = 300, 600
    local MainFrame = Instance.new("Frame", ScreenGui)
    MainFrame.Name                   = "MainFrame"
    MainFrame.BackgroundColor3       = T.bg0
    MainFrame.BackgroundTransparency = 0
    MainFrame.Position               = UDim2.new(0.5, -W/2, 0.04, 0)
    MainFrame.Size                   = UDim2.new(0, W, 0, H)
    MainFrame.BorderSizePixel        = 0
    MainFrame.Active                 = true
    MainFrame.Draggable              = false
    corner(MainFrame, 10)
    local TitleBar = Instance.new("Frame", MainFrame)
    TitleBar.Size                   = UDim2.new(1, 0, 0, 52)
    TitleBar.BackgroundColor3       = T.bg1
    TitleBar.BackgroundTransparency = 0
    TitleBar.BorderSizePixel        = 0
    TitleBar.ZIndex                 = 2
    corner(TitleBar, 10)
    local TitleMask = Instance.new("Frame", TitleBar)
    TitleMask.Size                   = UDim2.new(1, 0, 0.5, 0)
    TitleMask.Position               = UDim2.new(0, 0, 0.5, 0)
    TitleMask.BackgroundColor3       = T.bg1
    TitleMask.BackgroundTransparency = 0
    TitleMask.BorderSizePixel        = 0
    TitleMask.Active                 = false
    do
        local dragging, dragStart, startPos = false, nil, nil
        TitleBar.InputBegan:Connect(function(i, sunk)
            if sunk then return end
            if i.UserInputType == Enum.UserInputType.MouseButton1 then
                dragging = true; dragStart = i.Position; startPos = MainFrame.Position
            end
        end)
        TitleBar.InputEnded:Connect(function(i)
            if i.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
        end)
        UIS.InputChanged:Connect(function(i)
            if dragging and i.UserInputType == Enum.UserInputType.MouseMovement then
                local delta = i.Position - dragStart
                MainFrame.Position = UDim2.new(
                    startPos.X.Scale, startPos.X.Offset + delta.X,
                    startPos.Y.Scale, startPos.Y.Offset + delta.Y)
            end
        end)
    end
    local TitleDot = Instance.new("Frame", TitleBar)
    TitleDot.Size             = UDim2.new(0, 5, 0, 5)
    TitleDot.Position         = UDim2.new(0, 14, 0.5, -2)
    TitleDot.BackgroundColor3 = T.ice
    TitleDot.BorderSizePixel  = 0
    corner(TitleDot, 10)
    local TitleSmall = lbl(TitleBar, "", 10, T.textLo, Enum.Font.GothamBlack)
    TitleSmall.Size     = UDim2.new(0, 60, 0, 14)
    TitleSmall.Position = UDim2.new(0, 22, 0.5, -7)
    TitleSmall.ZIndex   = 3
    local NameTag = lbl(TitleBar, "TRIDENT", 20, T.text, Enum.Font.GothamBlack)
    NameTag.Size           = UDim2.new(1, 0, 1, 0)
    NameTag.Position       = UDim2.new(0, 0, 0, 0)
    NameTag.TextXAlignment = Enum.TextXAlignment.Center
    NameTag.ZIndex         = 3
    local TITLE_H  = 52
    local TAB_H    = 30
    local TAB_TOP  = TITLE_H + 6
    local PAGE_TOP = TAB_TOP + TAB_H + 6
    local BOT_H    = 52
    local TabBar = Instance.new("Frame", MainFrame)
    TabBar.Size                   = UDim2.new(1, -16, 0, TAB_H)
    TabBar.Position               = UDim2.new(0, 8, 0, TAB_TOP)
    TabBar.BackgroundColor3       = T.bg2
    TabBar.BackgroundTransparency = 0
    TabBar.BorderSizePixel        = 0
    corner(TabBar, 7)
    local TabLayout = Instance.new("UIListLayout", TabBar)
    TabLayout.FillDirection       = Enum.FillDirection.Horizontal
    TabLayout.Padding             = UDim.new(0, 0)
    TabLayout.SortOrder           = Enum.SortOrder.LayoutOrder
    TabLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
    local ActiveTab = "FEATURES"
    local TabPages  = {}
    local TabBtns   = {}
    local function makeTab(name, order)
        local btn = Instance.new("TextButton", TabBar)
        btn.Size                   = UDim2.new(0.5, 0, 1, 0)
        btn.BackgroundColor3       = T.bg2
        btn.BackgroundTransparency = 0
        btn.BorderSizePixel        = 0
        btn.Font                   = Enum.Font.GothamBold
        btn.TextSize               = 11
        btn.TextScaled             = false
        btn.Text                   = name
        btn.TextColor3             = T.textLo
        btn.LayoutOrder            = order
        corner(btn, 7)
        local page = Instance.new("ScrollingFrame", MainFrame)
        page.BackgroundTransparency = 1
        page.Position               = UDim2.new(0, 8, 0, PAGE_TOP)
        page.Size                   = UDim2.new(1, -16, 0, H - PAGE_TOP - BOT_H)
        page.CanvasSize             = UDim2.new(0, 0, 0, 0)
        page.AutomaticCanvasSize    = Enum.AutomaticSize.Y
        page.ScrollBarThickness     = 2
        page.ScrollBarImageColor3   = Color3.fromRGB(30, 55, 85)
        page.BorderSizePixel        = 0
        page.ScrollingDirection     = Enum.ScrollingDirection.Y
        page.ClipsDescendants       = true
        page.Visible                = (name == ActiveTab)
        local layout = Instance.new("UIListLayout", page)
        layout.Padding   = UDim.new(0, 2)
        layout.SortOrder = Enum.SortOrder.LayoutOrder
        TabPages[name] = page
        TabBtns[name]  = btn
        btn.MouseButton1Click:Connect(function()
            ActiveTab = name
            for n, p in pairs(TabPages) do
                p.Visible                   = (n == name)
                TabBtns[n].TextColor3       = n == name and T.text or T.textLo
                TabBtns[n].BackgroundColor3 = n == name and T.bg3  or T.bg2
            end
        end)
        if name == ActiveTab then
            btn.TextColor3       = T.text
            btn.BackgroundColor3 = T.bg3
        end
        return page
    end
    local FeatPage = makeTab("FEATURES", 1)
    local SetPage  = makeTab("SETTINGS",  2)
    local BottomHUD = Instance.new("Frame", MainFrame)
    BottomHUD.Size                   = UDim2.new(1, -16, 0, 42)
    BottomHUD.Position               = UDim2.new(0, 8, 1, -48)
    BottomHUD.BackgroundColor3       = T.bg1
    BottomHUD.BackgroundTransparency = 0
    BottomHUD.BorderSizePixel        = 0
    corner(BottomHUD, 8)
    local FPSPingLbl = lbl(BottomHUD, "FPS: 00  |  PING: 00ms", 9, T.textLo, Enum.Font.GothamBold, Enum.TextXAlignment.Center)
    FPSPingLbl.Size     = UDim2.new(1, 0, 0, 16)
    FPSPingLbl.Position = UDim2.new(0, 0, 0, 4)
    local HUDSep = Instance.new("Frame", BottomHUD)
    HUDSep.Size             = UDim2.new(1, -16, 0, 1)
    HUDSep.Position         = UDim2.new(0, 8, 0, 22)
    HUDSep.BackgroundColor3 = T.bg3
    HUDSep.BorderSizePixel  = 0
    local ChooseSideLbl = lbl(BottomHUD, "Choose Side", 9, T.textLo, Enum.Font.GothamBold, Enum.TextXAlignment.Right)
    ChooseSideLbl.Size     = UDim2.new(0, 70, 0, 14)
    ChooseSideLbl.Position = UDim2.new(1, -172, 0, 25)
    local SaveBtn = Instance.new("TextButton", BottomHUD)
    SaveBtn.Size             = UDim2.new(0, 54, 0, 14)
    SaveBtn.Position         = UDim2.new(0, 8, 0, 25)
    SaveBtn.BackgroundColor3 = T.bg3
    SaveBtn.BorderSizePixel  = 0
    SaveBtn.Text             = "Save"
    SaveBtn.TextColor3       = T.textMid
    SaveBtn.Font             = Enum.Font.GothamBold
    SaveBtn.TextSize         = 10
    SaveBtn.TextScaled       = false
    corner(SaveBtn, 4)
    SaveBtn.MouseButton1Click:Connect(function()
        SaveConfig()
        SaveBtn.Text = "✓"; SaveBtn.TextColor3 = T.green
        task.wait(1.2)
        SaveBtn.Text = "Save"; SaveBtn.TextColor3 = T.textMid
    end)
    local function makeBottomSidePill(label, xOff, active)
        local btn = Instance.new("TextButton", BottomHUD)
        btn.Size             = UDim2.new(0, 36, 0, 14)
        btn.Position         = UDim2.new(1, xOff, 0, 25)
        btn.Font             = Enum.Font.GothamBlack
        btn.TextSize         = 11
        btn.TextScaled       = false
        btn.Text             = label
        btn.BorderSizePixel  = 0
        corner(btn, 4)
        local function setActive(v)
            btn.BackgroundColor3 = v and T.bg3  or T.bg2
            btn.TextColor3       = v and T.text or T.textLo
        end
        setActive(active)
        btn.MouseButton1Click:Connect(function() switchSide(label) end)
        return setActive
    end
    local bottomSetL = makeBottomSidePill("L", -90, sharedSide == "L")
    local bottomSetR = makeBottomSidePill("R", -50, sharedSide == "R")
    TitlePills.setL = bottomSetL
    TitlePills.setR = bottomSetR
    task.spawn(function()
        while task.wait(0.6) do
            FPSPingLbl.Text = string.format("FPS: %d  |  PING: %dms",
                math.floor(Stats.Workspace.Heartbeat:GetValue()),
                math.floor(Player:GetNetworkPing() * 1000))
        end
    end)
    local StealBarOuter = Instance.new("Frame", ScreenGui)
    StealBarOuter.Size                   = UDim2.new(0, 320, 0, 76)
    StealBarOuter.Position               = UDim2.new(0.5, -160, 1, -168)
    StealBarOuter.BackgroundColor3       = Color3.fromRGB(8, 12, 20)
    StealBarOuter.BackgroundTransparency = 0
    StealBarOuter.BorderSizePixel        = 0
    StealBarOuter.ZIndex                 = 20
    StealBarOuter.Visible                = true
    corner(StealBarOuter, 10)
    local PillTrack = Instance.new("Frame", StealBarOuter)
    PillTrack.Size             = UDim2.new(1, -20, 0, 10)
    PillTrack.Position         = UDim2.new(0, 10, 0, 10)
    PillTrack.BackgroundColor3 = Color3.fromRGB(20, 36, 54)
    PillTrack.BorderSizePixel  = 0
    PillTrack.ZIndex           = 21
    corner(PillTrack, 99)
    local PillFill = Instance.new("Frame", PillTrack)
    PillFill.Size             = UDim2.new(0, 0, 1, 0)
    PillFill.BackgroundColor3 = T.ice
    PillFill.BorderSizePixel  = 0
    PillFill.ZIndex           = 22
    corner(PillFill, 99)
    local BarPctLbl = lbl(StealBarOuter, "0", 12, T.textMid, Enum.Font.GothamBold, Enum.TextXAlignment.Center)
    BarPctLbl.Size     = UDim2.new(1, 0, 0, 16)
    BarPctLbl.Position = UDim2.new(0, 0, 0, 22)
    BarPctLbl.ZIndex   = 22
    local BarSep = Instance.new("Frame", StealBarOuter)
    BarSep.Size             = UDim2.new(1, -20, 0, 1)
    BarSep.Position         = UDim2.new(0, 10, 0, 42)
    BarSep.BackgroundColor3 = Color3.fromRGB(24, 40, 60)
    BarSep.BorderSizePixel  = 0
    BarSep.ZIndex           = 21
    local function makeBarInput(labelText, xPos, configKey)
        local l = lbl(StealBarOuter, labelText, 11, T.textMid, Enum.Font.GothamBold)
        l.Size = UDim2.new(0, 34, 0, 18); l.Position = UDim2.new(0, xPos, 0, 48); l.ZIndex = 22
        local box = Instance.new("TextBox", StealBarOuter)
        box.Size             = UDim2.new(0, 46, 0, 18)
        box.Position         = UDim2.new(0, xPos + 36, 0, 48)
        box.BackgroundColor3 = Color3.fromRGB(14, 22, 36)
        box.BorderSizePixel  = 0
        box.TextColor3       = T.text
        box.Text             = tostring(Config[configKey])
        box.Font             = Enum.Font.GothamBold
        box.TextSize         = 11
        box.TextScaled       = false
        box.TextXAlignment   = Enum.TextXAlignment.Center
        box.ZIndex           = 22
        corner(box, 4)
        box.FocusLost:Connect(function()
            local n = tonumber(box.Text)
            if n then Config[configKey] = n; SaveConfig() end
            box.Text = tostring(Config[configKey])
        end)
    end
    makeBarInput("Spd",   10,  "GrabSpeed")
    makeBarInput("Range", 170, "GrabRange")
    local function doAutoTP(side)
        if AutoTPRunning then return end
        local data = TP_SIDES[side]
        AutoTPRunning = true
        task.spawn(function()
            local root = Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
            if root then root.CFrame = CFrame.new(data.Step1) end
            task.wait(0.2)
            root = Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
            if root then root.CFrame = CFrame.new(data.Step2 + Vector3.new(0, 6, 0)) end
            AutoTPRunning = false
            task.wait(0.05)
            root = Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
            if root and AutoPlayEnabled then
                local zone = Config.StopOnLeft and ZoneDefs.Left or Config.StopOnRight and ZoneDefs.Right
                if zone and isInZone(root.Position, zone) then AutoPlayRunning = false end
            end
        end)
    end
    local function restartAutoPlay(startStep)
        AutoPlayRestarting = true
        if autoPlaySetState then autoPlaySetState(true) end
        AutoPlayEnabled = false; AutoPlayRunning = false
        task.wait(0.25)
        AutoPlayStartStep  = startStep
        AutoPlayEnabled    = true; AutoPlayRunning = false
        AutoPlayRestarting = false
        if autoPlaySetState then autoPlaySetState(true) end
    end
    local function handleBrainrotToggle(s, setStateFn)
        BrainrotSequenceRunning = false
        FloatEnabled            = false
        FloatTargetY            = nil
        FloatActiveSpeed        = nil
        FloatDescending         = false
        FloatDescendingStarted  = false
        Config.FloatState       = false
        if not s then return end
        local float2WasActive = Float2Enabled
        Float2Enabled      = false
        Float2TargetY      = nil
        Config.Float2State = false
        if float2SetState then float2SetState(false) end
        if AutoPlayEnabled then
            AutoPlayEnabled = false; AutoPlayRunning = false; Config.AutoPlayState = false
            if autoPlaySetState then autoPlaySetState(false) end
        end
        BrainrotSequenceRunning = true
        task.spawn(function()
            local function getRoot()
                return Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
            end
            local function aborted() return not BrainrotSequenceRunning end
            local r = getRoot()
            if not r then
                BrainrotSequenceRunning = false
                if setStateFn then setStateFn(false) end
                return
            end
            local groundY = getGroundHeight(r.Position)
            local targetY = groundY + Config.FloatHeight
            if r.Position.Y < targetY - 0.5 then
                local prevY = r.Position.Y
                local stuckFrames = 0
                while not aborted() do
                    r = getRoot(); if not r then break end
                    if r.Position.Y >= targetY - 0.5 then break end
                    if math.abs(r.Position.Y - prevY) < 0.02 then
                        stuckFrames = stuckFrames + 1
                        if stuckFrames >= 4 then break end
                    else
                        stuckFrames = 0
                    end
                    prevY = r.Position.Y
                    local diff = targetY - r.Position.Y
                    local spd  = Config.FloatSpeed
                    r.AssemblyLinearVelocity = Vector3.new(
                        r.AssemblyLinearVelocity.X,
                        math.clamp(diff * spd * 0.5, 1, spd),
                        r.AssemblyLinearVelocity.Z)
                    task.wait(0.03)
                end
                if aborted() then return end
                r = getRoot()
                if r then r.AssemblyLinearVelocity = Vector3.new(r.AssemblyLinearVelocity.X, 0, r.AssemblyLinearVelocity.Z) end
                task.wait(0.05)
            end
            local descentStart = tick()
            while not aborted() do
                r = getRoot(); if not r then break end
                local gY = getGroundHeight(r.Position)
                if r.Position.Y - gY <= 3 then break end
                if tick() - descentStart > 2 then break end
                r.AssemblyLinearVelocity = Vector3.new(
                    r.AssemblyLinearVelocity.X, -200, r.AssemblyLinearVelocity.Z)
                task.wait(0.03)
            end
            if aborted() then return end
            BrainrotSequenceRunning = false
            FloatEnabled            = false
            Config.FloatState       = false
            FloatTargetY            = nil
            FloatActiveSpeed        = nil
            r = getRoot()
            if r then r.AssemblyLinearVelocity = Vector3.new(r.AssemblyLinearVelocity.X, 0, r.AssemblyLinearVelocity.Z) end
            if setStateFn then setStateFn(false) end
            if float2WasActive then
                r = getRoot()
                Float2Enabled      = true
                Config.Float2State = true
                Float2TargetY      = r and (r.Position.Y + Config.Float2Height) or nil
                if float2SetState then float2SetState(true) end
            end
        end)
    end
    local function handleFloat2Toggle(s, setStateFn)
        Float2Enabled      = s
        Config.Float2State = s
        if not s then Float2TargetY = nil end
    end
    local ragdollTPCooldown = false
    local ragdollTPSetState = nil
    local pendingRagdollTP  = false
    local lastRagdollTick   = 0
    local ragdollOccurred   = false
    local RAGDOLL_STEP2 = {
        R = Vector3.new(-482.89, -5.09, 26.45),
        L = Vector3.new(-482.86, -5.09, 95.34),
    }
    local function tryPendingRagdollTP()
        if pendingRagdollTP and (tick() - lastRagdollTick < 3) then
            pendingRagdollTP = false
            task.spawn(function()
                local tpSide = sharedSide or "L"
                local tpData = TP_SIDES[tpSide]
                local char   = Player.Character
                local root   = char and char:FindFirstChild("HumanoidRootPart")
                if not root then return end
                root.CFrame = CFrame.new(tpData.Step1)
                task.wait(0.2)
                root = Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
                if not root then return end
                root.CFrame = CFrame.new(RAGDOLL_STEP2[tpSide])
                task.wait(0.15)
                AutoPlayStartStep = 2
            end)
            return true
        end
        pendingRagdollTP = false
        return false
    end
    local function startAntiRagdoll()
        if AntiRagdollConnection then return end
        AntiRagdollConnection = RunService.Heartbeat:Connect(function()
            local char = Player.Character
            if not char then return end
            local root = char:FindFirstChild("HumanoidRootPart")
            local hum  = char:FindFirstChildOfClass("Humanoid")
            if hum then
                local s = hum:GetState()
                if s == Enum.HumanoidStateType.Physics
                or s == Enum.HumanoidStateType.Ragdoll
                or s == Enum.HumanoidStateType.FallingDown then
                    lastRagdollTick = tick()
                    ragdollOccurred = true
                    AutoPlayEnabled = false; AutoPlayRunning = false; Config.AutoPlayState = false
                    if autoPlaySetState then autoPlaySetState(false) end
                    hum:ChangeState(Enum.HumanoidStateType.Running)
                    workspace.CurrentCamera.CameraSubject = hum
                    pcall(function()
                        local pm = Player.PlayerScripts:FindFirstChild("PlayerModule")
                        if pm then require(pm:FindFirstChild("ControlModule")):Enable() end
                    end)
                    if root then root.Velocity = Vector3.new(0,0,0); root.RotVelocity = Vector3.new(0,0,0) end
                    if Config.RagdollAutoTP and not ragdollTPCooldown then
                        pendingRagdollTP  = false
                        ragdollTPCooldown = true
                        local side = sharedSide or (Config.AutoTPRState and "R") or "L"
                        task.spawn(function()
                            task.wait(0.08)
                            local data = TP_SIDES[side]
                            local r = Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
                            if r then r.CFrame = CFrame.new(data.Step1) end
                            task.wait(0.2)
                            r = Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
                            local ragStep2 = side == "R" and Vector3.new(-482.89, -5.09, 26.45) or Vector3.new(-482.86, -5.09, 95.34)
                            if r then r.CFrame = CFrame.new(ragStep2 + Vector3.new(0, 3, 0)) end
                            task.wait(0.2)
                            AutoPlayStartStep = 3
                            AutoPlayEnabled = true; AutoPlayRunning = false
                            if autoPlaySetState then autoPlaySetState(true) end
                            task.wait(2.5); ragdollTPCooldown = false
                        end)
                    end
                end
            end
            for _, obj in ipairs(char:GetDescendants()) do
                if obj:IsA("Motor6D") and not obj.Enabled then obj.Enabled = true end
            end
        end)
    end
    local function stopAntiRagdoll()
        if AntiRagdollConnection then AntiRagdollConnection:Disconnect(); AntiRagdollConnection = nil end
    end
    local function applyESPToChar(plr, char)
        if not char then return end
        local root = char:WaitForChild("HumanoidRootPart", 10)
        if not root or root:FindFirstChild("ESP_NameTag") then return end
        local bill = Instance.new("BillboardGui")
        bill.Name = "ESP_NameTag"; bill.AlwaysOnTop = true
        bill.Size = UDim2.new(0, 100, 0, 20); bill.StudsOffset = Vector3.new(0, 3, 0)
        bill.Enabled = Config.ESPEnabled; bill.Parent = root
        local l = Instance.new("TextLabel", bill)
        l.Size = UDim2.new(1, 0, 1, 0); l.BackgroundTransparency = 1
        l.Text = plr.DisplayName; l.TextColor3 = Color3.fromRGB(255, 255, 255)
        l.TextStrokeTransparency = 0; l.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
        l.Font = Enum.Font.GothamBold; l.TextSize = 13; l.TextScaled = false
    end
    local function setupESP(plr)
        if plr == Player then return end
        local line = Drawing.new("Line")
        line.Thickness = 2; line.Color = Color3.fromRGB(255, 255, 255)
        line.Transparency = 0; line.Visible = false
        ESPTracers[plr] = line
        if plr.Character then task.spawn(applyESPToChar, plr, plr.Character) end
        plr.CharacterAdded:Connect(function(char) task.wait(1); applyESPToChar(plr, char) end)
    end
    Players.PlayerAdded:Connect(setupESP)
    Players.PlayerRemoving:Connect(function(p)
        if ESPTracers[p] then ESPTracers[p]:Remove(); ESPTracers[p] = nil end
    end)
    for _, p in pairs(Players:GetPlayers()) do setupESP(p) end
    local _espFrame = 0
    RunService.RenderStepped:Connect(function()
        if not Config.ESPEnabled then return end
        _espFrame = _espFrame + 1
        if _espFrame % 3 ~= 0 then return end
        for plr, line in pairs(ESPTracers) do
            if plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") then
                local pos, onScreen = Camera:WorldToViewportPoint(plr.Character.HumanoidRootPart.Position)
                line.Visible = onScreen
                if onScreen then
                    line.From = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y)
                    line.To   = Vector2.new(pos.X, pos.Y)
                end
            else
                line.Visible = false
            end
        end
    end)
    RunService.Stepped:Connect(function()
        if not NoclipPlayersEnabled then return end
        local char = Player.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        if not root then return end
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= Player and p.Character then
                local pRoot = p.Character:FindFirstChild("HumanoidRootPart")
                if pRoot and (root.Position - pRoot.Position).Magnitude <= 8 then
                    for _, part in pairs(p.Character:GetDescendants()) do
                        if part:IsA("BasePart") then part.CanCollide = false end
                    end
                end
            end
        end
    end)
    local function buildCallbacks(prompt)
        if InternalCache[prompt] then return end
        local data = { holdCallbacks = {}, triggerCallbacks = {} }
        local ok1, c1 = pcall(getconnections, prompt.PromptButtonHoldBegan)
        if ok1 and type(c1) == "table" then
            for _, c in ipairs(c1) do
                if type(c.Function) == "function" then table.insert(data.holdCallbacks, c.Function) end
            end
        end
        local ok2, c2 = pcall(getconnections, prompt.Triggered)
        if ok2 and type(c2) == "table" then
            for _, c in ipairs(c2) do
                if type(c.Function) == "function" then table.insert(data.triggerCallbacks, c.Function) end
            end
        end
        if #data.holdCallbacks > 0 or #data.triggerCallbacks > 0 then InternalCache[prompt] = data end
    end
    local function executeSteal(prompt, duration)
        local data = InternalCache[prompt]
        if not data then return false end
        for _, fn in ipairs(data.holdCallbacks)    do task.spawn(fn) end
        task.wait(duration)
        for _, fn in ipairs(data.triggerCallbacks) do task.spawn(fn) end
        return true
    end
    local function rebuildPromptCache()
        PromptCache = {}
        for _, v in pairs(workspace:GetDescendants()) do
            if v:IsA("ProximityPrompt") then table.insert(PromptCache, v) end
        end
    end
    workspace.DescendantAdded:Connect(function(v)
        if v:IsA("ProximityPrompt") then table.insert(PromptCache, v) end
    end)
    workspace.DescendantRemoving:Connect(function(v)
        if v:IsA("ProximityPrompt") then
            for i, p in ipairs(PromptCache) do
                if p == v then table.remove(PromptCache, i); break end
            end
        end
    end)
    rebuildPromptCache()
    local function lockCooldown(prompt)
        pcall(function()
            prompt.Cooldown = 0
            prompt:GetPropertyChangedSignal("Cooldown"):Connect(function()
                pcall(function() prompt.Cooldown = 0 end)
            end)
        end)
    end
    for _, v in ipairs(workspace:GetDescendants()) do
        if v:IsA("ProximityPrompt") then lockCooldown(v) end
    end
    workspace.DescendantAdded:Connect(function(v)
        if v:IsA("ProximityPrompt") then lockCooldown(v) end
    end)
    task.spawn(function()
        while true do
            task.wait()
            if not GrabActive or Interacting then continue end
            local char = Player.Character
            local root = char and char:FindFirstChild("HumanoidRootPart")
            if not root then continue end
            local target, closest = nil, Config.GrabRange
            for _, v in pairs(PromptCache) do
                if v and v.Parent and v.ActionText == "Steal" then
                    local pPos = v.Parent:IsA("Attachment") and v.Parent.WorldPosition
                            or v.Parent:IsA("BasePart")   and v.Parent.Position
                            or v.Parent:GetPivot().Position
                    local d = (root.Position - pPos).Magnitude
                    if d < closest then closest = d; target = v end
                end
            end
            if target then
                Interacting = true
                buildCallbacks(target)
                local dur = target.HoldDuration * Config.GrabSpeed
                PillFill.Size  = UDim2.new(0, 0, 1, 0)
                BarPctLbl.Text = "0"
                TweenService:Create(PillFill, TweenInfo.new(dur, Enum.EasingStyle.Linear), { Size = UDim2.new(1, 0, 1, 0) }):Play()
                task.spawn(function()
                    local elapsed = 0
                    while elapsed < dur and Interacting do
                        elapsed = elapsed + task.wait(0.05)
                        local pct = math.clamp(math.floor((elapsed / dur) * 100), 1, 100)
                        BarPctLbl.Text = tostring(pct)
                    end
                end)
                if InternalCache[target] then executeSteal(target, dur)
                else task.wait(dur); fireproximityprompt(target) end
                task.wait(0.1)
                PillFill.Size  = UDim2.new(0, 0, 1, 0)
                BarPctLbl.Text = "0"
                Interacting = false
            end
        end
    end)
    local SpeedLabel = nil
    local function setupSpeedBillboard(char)
        local root = char:WaitForChild("HumanoidRootPart", 10)
        if not root then return end
        local old = root:FindFirstChild("MySpeedBill")
        if old then old:Destroy() end
        local bill = Instance.new("BillboardGui")
        bill.Name = "MySpeedBill"; bill.AlwaysOnTop = true
        bill.Size = UDim2.new(0, 160, 0, 28); bill.StudsOffset = Vector3.new(0, 3.8, 0); bill.Parent = root
        local l = Instance.new("TextLabel", bill)
        l.Size = UDim2.new(1, 0, 1, 0); l.BackgroundTransparency = 1
        l.TextColor3             = Color3.fromRGB(120, 190, 230)
        l.TextStrokeTransparency = 0
        l.TextStrokeColor3       = Color3.fromRGB(0, 0, 0)
        l.Font                   = Enum.Font.GothamBold
        l.TextSize               = 30; l.TextScaled = false
        l.TextXAlignment         = Enum.TextXAlignment.Center
        l.Text = "Speed: 0.00"
        SpeedLabel = l
    end
    if Player.Character then task.spawn(setupSpeedBillboard, Player.Character) end
    Player.CharacterAdded:Connect(function(char) task.wait(0.5); setupSpeedBillboard(char) end)
    local function stopAutoPlay()
        AutoPlayEnabled = false; AutoPlayRunning = false; Config.AutoPlayState = false
        if not AutoPlayRestarting and autoPlaySetState then autoPlaySetState(false) end
    end
    local function walkToPosition(root, targetPos, speed, arriveDistance)
        speed = speed or Config.CarrySpeed
        if type(arriveDistance) ~= "number" then arriveDistance = 1 end
        while AutoPlayEnabled do
            local flat = Vector3.new(targetPos.X - root.Position.X, 0, targetPos.Z - root.Position.Z)
            if flat.Magnitude <= arriveDistance then break end
            local dir = flat.Unit
            root.AssemblyLinearVelocity = Vector3.new(dir.X * speed, root.AssemblyLinearVelocity.Y, dir.Z * speed)
            RunService.Heartbeat:Wait()
        end
        root.AssemblyLinearVelocity = Vector3.new(0, root.AssemblyLinearVelocity.Y, 0)
    end
    task.spawn(function()
        while true do
            task.wait(0.05)
            if not AutoPlayEnabled or AutoPlayRunning then continue end
            AutoPlayRunning = true
            local char = Player.Character
            local root = char and char:FindFirstChild("HumanoidRootPart")
            if not root then stopAutoPlay(); continue end
            local steps = Config.AutoPlaySide == "R" and AutoPlayStepsR or AutoPlayStepsL
            local zone  = Config.StopOnLeft and ZoneDefs.Left or Config.StopOnRight and ZoneDefs.Right
            local startStep = AutoPlayStartStep; AutoPlayStartStep = 1
            if startStep == 1 then
                if not (zone and isInZone(root.Position, zone)) then
                    walkToPosition(root, steps[1], Config.FastSpeed)
                    if not AutoPlayEnabled then AutoPlayRunning = false; continue end
                end
                if FastSpeedEnabled then
                    FastSpeedEnabled = false; Config.FastSpeedState = false
                    if FastSpeedSetState then FastSpeedSetState(false) end
                end
                walkToPosition(root, steps[2], Config.FastSpeed, true)
                task.wait(Config.Step2Delay)
                if not AutoPlayEnabled then AutoPlayRunning = false; continue end
            else
                root.AssemblyLinearVelocity = Vector3.new(0, root.AssemblyLinearVelocity.Y, 0)
                task.wait(0.1)
                if not AutoPlayEnabled then AutoPlayRunning = false; continue end
            end
            root = Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
            if root then walkToPosition(root, steps[3], Config.CarrySpeed, false) end
            if not AutoPlayEnabled then AutoPlayRunning = false; continue end
            root = Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
            if root then walkToPosition(root, steps[4], Config.CarrySpeed, false) end
            if not AutoPlayEnabled then AutoPlayRunning = false; continue end
            root = Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
            if root then walkToPosition(root, steps[5], Config.CarrySpeed, true) end
            stopAutoPlay()
        end
    end)
    local _playerCache = {}
    local _playerCacheTick = 0
    local function getCachedPlayers()
        local now = tick()
        if now - _playerCacheTick > 1 then
            _playerCache = Players:GetPlayers()
            _playerCacheTick = now
        end
        return _playerCache
    end
    Players.PlayerAdded:Connect(function() _playerCacheTick = 0 end)
    Players.PlayerRemoving:Connect(function() _playerCacheTick = 0 end)
    local lastClick = 0
    RunService.Heartbeat:Connect(function()
        local char = Player.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        local hum  = char and char:FindFirstChildOfClass("Humanoid")
        if not root or not hum then return end
        if not AutoPlayEnabled and not AutoBatEnabled and hum.MoveDirection.Magnitude > 0 then
            local spd = FastSpeedEnabled and Config.FastSpeed or Config.CarrySpeed
            root.AssemblyLinearVelocity = Vector3.new(
                hum.MoveDirection.X * spd,
                root.AssemblyLinearVelocity.Y,
                hum.MoveDirection.Z * spd)
        end
        if Player:GetAttribute("Stealing") == true and hum.MoveDirection.Magnitude > 0 then
            root.AssemblyLinearVelocity = Vector3.new(
                hum.MoveDirection.X * Config.CarrySpeed,
                root.AssemblyLinearVelocity.Y,
                hum.MoveDirection.Z * Config.CarrySpeed)
        end
        if AutoBatEnabled then
            local target, dMin = nil, 1000
            for _, p in pairs(getCachedPlayers()) do
                if p ~= Player and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
                    local d = (root.Position - p.Character.HumanoidRootPart.Position).Magnitude
                    if d < dMin then target = p; dMin = d end
                end
            end
            if target and target.Character then
                for _, part in pairs(target.Character:GetDescendants()) do
                    if part:IsA("BasePart") then part.CanCollide = false end
                end
            end
            if target then
                local tRoot = target.Character.HumanoidRootPart
                local dest  = tRoot.Position + tRoot.CFrame.LookVector * Config.BatDist
                local diff  = dest - root.Position
                root.AssemblyAngularVelocity = root.CFrame.LookVector:Cross(tRoot.CFrame.LookVector) * 20
                local batVel = diff.Magnitude > 1 and diff.Unit * Config.AutoBatSpeed or tRoot.AssemblyLinearVelocity
                local yVel = batVel.Y
                if Float2Enabled then
                    local surfaceY = getGroundHeight(root.Position)
                    local floatTarget = surfaceY + Config.Float2Height
                    yVel = math.clamp((floatTarget - root.Position.Y) * Config.Float2Speed, -Config.Float2Speed, Config.Float2Speed)
                end
                root.AssemblyLinearVelocity = Vector3.new(batVel.X, yVel, batVel.Z)
                local tool = char:FindFirstChildOfClass("Tool")
                if tool and tool.Name:lower() == "bat" and tick() - lastClick > 0.1 then
                    pcall(mouse1click); lastClick = tick()
                end
            end
        end
        local spaceHeld = Config.InfJumpEnabled and UIS:IsKeyDown(Enum.KeyCode.Space)
        if Float2Enabled and not spaceHeld then
            local surfaceY = getGroundHeight(root.Position)
            Float2TargetY  = surfaceY + Config.Float2Height
            local fspeed   = Config.Float2Speed
            local diff     = Float2TargetY - root.Position.Y
            root.AssemblyLinearVelocity = Vector3.new(
                root.AssemblyLinearVelocity.X,
                math.clamp(diff * fspeed, -fspeed, fspeed),
                root.AssemblyLinearVelocity.Z)
        elseif FloatEnabled and FloatTargetY and not spaceHeld and not BrainrotSequenceRunning then
            local fspeed = FloatActiveSpeed or Config.FloatSpeed
            local diff   = FloatTargetY - root.Position.Y
            root.AssemblyLinearVelocity = Vector3.new(
                root.AssemblyLinearVelocity.X,
                math.clamp(diff * fspeed, -fspeed, fspeed),
                root.AssemblyLinearVelocity.Z)
        elseif FloatDescending and not FloatEnabled and not BrainrotSequenceRunning then
            if FloatDescendingStarted and root.AssemblyLinearVelocity.Y >= -2 then
                FloatDescending = false; FloatDescendingStarted = false
            else
                root.AssemblyLinearVelocity = Vector3.new(
                    root.AssemblyLinearVelocity.X, -Config.FloatSpeed, root.AssemblyLinearVelocity.Z)
                FloatDescendingStarted = true
            end
        end
        if AutoPlayEnabled then
            local targetLook = Vector3.new(-0.9999873042106628, 0, 0.005038774572312832).Unit
            local currentLook = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
            if currentLook.Magnitude > 0.01 then
                local cross = currentLook.Unit:Cross(targetLook)
                root.AssemblyAngularVelocity = Vector3.new(0, cross.Y * 15, 0)
            end
        end
        if SpeedLabel then
            local v = root.AssemblyLinearVelocity
            SpeedLabel.Text = string.format("Speed: %.2f", Vector3.new(v.X, 0, v.Z).Magnitude)
        end
    end)
    local noAnimConn   = nil
    local noAnimHbConn = nil
    local function freezePose(char)
        for _, m in ipairs(char:GetDescendants()) do
            if m:IsA("Motor6D") then
                m.CurrentAngle = 0; m.DesiredAngle = 0; m.MaxVelocity = 0; m.Transform = CFrame.new()
            end
        end
    end
    local function applyNoAnim(char)
        if not char then return end
        local animScript = char:WaitForChild("Animate", 15)
        if not NoAnimEnabled then return end
        if animScript then animScript.Disabled = true end
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then for _, t in ipairs(hum:GetPlayingAnimationTracks()) do pcall(t.Stop, t, 0) end end
        if noAnimHbConn then noAnimHbConn:Disconnect(); noAnimHbConn = nil end
        noAnimHbConn = RunService.Heartbeat:Connect(function()
            if not NoAnimEnabled then
                if noAnimHbConn then noAnimHbConn:Disconnect(); noAnimHbConn = nil end
                return
            end
            if Player.Character then freezePose(Player.Character) end
        end)
    end
    local FPSBoostLocalConn = nil
    local FPSBoostCharConn  = nil
    local function applyFPSBoostCharacter(char)
        if not char then return end
        pcall(function()
            for _, v in ipairs(char:GetDescendants()) do
                if v:IsA("Accessory") or v:IsA("Shirt") or v:IsA("Pants")
                or v:IsA("ShirtGraphic") or v:IsA("BodyColors") then v:Destroy() end
            end
        end)
        char.DescendantAdded:Connect(function(v)
            if not Config.FpsBoostState then return end
            if v:IsA("Accessory") or v:IsA("Shirt") or v:IsA("Pants")
            or v:IsA("ShirtGraphic") or v:IsA("BodyColors") then pcall(function() v:Destroy() end) end
        end)
    end
    local function applyFPSBoostWorld()
        for _, v in pairs(workspace:GetDescendants()) do
            pcall(function()
                if v:IsA("BasePart") then v.CastShadow = false; v.Material = Enum.Material.Plastic
                elseif v:IsA("Decal") then v.Transparency = 1
                elseif v:IsA("ParticleEmitter") then v.Enabled = false end
            end)
        end
        Lighting.GlobalShadows = false
    end
    local ROW_H = 36
    local function FeatSectionHeader(text, order)
        local row = Instance.new("Frame", FeatPage)
        row.Size                   = UDim2.new(1, 0, 0, 22)
        row.BackgroundTransparency = 1
        row.BorderSizePixel        = 0
        row.LayoutOrder            = order
        local l = lbl(row, text, 9, T.textLo, Enum.Font.GothamBold)
        l.Size     = UDim2.new(1, -8, 1, 0)
        l.Position = UDim2.new(0, 4, 0, 0)
    end
    local function FeatToggle(text, order, onToggle)
        local state = false
        local Frame = Instance.new("Frame", FeatPage)
        Frame.Size                   = UDim2.new(1, 0, 0, ROW_H)
        Frame.BackgroundColor3       = T.bg1
        Frame.BackgroundTransparency = 0
        Frame.BorderSizePixel        = 0
        Frame.LayoutOrder            = order
        corner(Frame, 6)
        local TextLbl = lbl(Frame, text, 12, T.textMid, Enum.Font.GothamBold)
        TextLbl.Size       = UDim2.new(1, -70, 1, 0)
        TextLbl.Position   = UDim2.new(0, 14, 0, 0)
        TextLbl.TextScaled = false
        local Track = Instance.new("Frame", Frame)
        Track.Size             = UDim2.new(0, 44, 0, 24)
        Track.Position         = UDim2.new(1, -54, 0.5, -12)
        Track.BackgroundColor3 = T.trackBg
        Track.BorderSizePixel  = 0
        corner(Track, 12)
        local Dot = Instance.new("Frame", Track)
        Dot.Size             = UDim2.new(0, 18, 0, 18)
        Dot.Position         = UDim2.new(0, 3, 0.5, -9)
        Dot.BackgroundColor3 = T.dotOff
        Dot.BorderSizePixel  = 0
        corner(Dot, 10)
        local Btn = Instance.new("TextButton", Frame)
        Btn.Size                   = UDim2.new(1, 0, 1, 0)
        Btn.BackgroundTransparency = 1
        Btn.BorderSizePixel        = 0
        Btn.Text                   = ""
        Btn.TextScaled             = false
        local function refresh()
            if state then
                tween(Dot, 0.3, { BackgroundColor3 = T.dotOn,  Position = UDim2.new(0, 23, 0.5, -9) })
            else
                tween(Dot, 0.3, { BackgroundColor3 = T.dotOff, Position = UDim2.new(0, 3,  0.5, -9) })
            end
        end
        refresh()
        Btn.MouseButton1Click:Connect(function()
            state = not state; refresh(); onToggle(state)
        end)
        return Btn, function(s) state = s; refresh() end
    end
    local function FeatToggleWithSide(baseText, order, initialSide, onToggle, onSideSwap)
        local state = false
        local side  = initialSide or "L"
        local Frame = Instance.new("Frame", FeatPage)
        Frame.Size                   = UDim2.new(1, 0, 0, ROW_H)
        Frame.BackgroundColor3       = T.bg1
        Frame.BackgroundTransparency = 0
        Frame.BorderSizePixel        = 0
        Frame.LayoutOrder            = order
        corner(Frame, 6)
        local TextLbl = lbl(Frame, baseText .. " " .. side, 12, T.textMid, Enum.Font.GothamBold)
        TextLbl.Size       = UDim2.new(1, -70, 1, 0)
        TextLbl.Position   = UDim2.new(0, 14, 0, 0)
        TextLbl.TextScaled = false
        local Track = Instance.new("Frame", Frame)
        Track.Size             = UDim2.new(0, 44, 0, 24)
        Track.Position         = UDim2.new(1, -54, 0.5, -12)
        Track.BackgroundColor3 = T.trackBg
        Track.BorderSizePixel  = 0
        corner(Track, 12)
        local Dot = Instance.new("Frame", Track)
        Dot.Size             = UDim2.new(0, 18, 0, 18)
        Dot.Position         = UDim2.new(0, 3, 0.5, -9)
        Dot.BackgroundColor3 = T.dotOff
        Dot.BorderSizePixel  = 0
        corner(Dot, 10)
        local Btn = Instance.new("TextButton", Frame)
        Btn.Size                   = UDim2.new(1, 0, 1, 0)
        Btn.BackgroundTransparency = 1
        Btn.BorderSizePixel        = 0
        Btn.Text                   = ""
        Btn.TextScaled             = false
        local function refresh()
            TextLbl.Text = baseText .. " " .. side
            if state then
                tween(Dot, 0.3, { BackgroundColor3 = T.dotOn,  Position = UDim2.new(0, 23, 0.5, -9) })
            else
                tween(Dot, 0.3, { BackgroundColor3 = T.dotOff, Position = UDim2.new(0, 3,  0.5, -9) })
            end
        end
        refresh()
        Btn.MouseButton1Click:Connect(function()
            state = not state; refresh(); onToggle(state, side)
        end)
        Btn.MouseButton2Click:Connect(function()
            side = side == "L" and "R" or "L"; refresh()
            if onSideSwap then onSideSwap(side) end
        end)
        return Btn,
            function(s) state = s; refresh() end,
            function(s) side  = s; refresh() end
    end
    local function SetSectionHeader(text, order)
        local row = Instance.new("Frame", SetPage)
        row.Size                   = UDim2.new(1, 0, 0, 22)
        row.BackgroundTransparency = 1
        row.BorderSizePixel        = 0
        row.LayoutOrder            = order
        local l = lbl(row, text, 9, T.textLo, Enum.Font.GothamBold)
        l.Size = UDim2.new(1, -8, 1, 0); l.Position = UDim2.new(0, 4, 0, 0)
    end
    local function SetInputRow(text, configKey, order)
        local Frame = Instance.new("Frame", SetPage)
        Frame.Size                   = UDim2.new(1, 0, 0, 34)
        Frame.BackgroundColor3       = T.bg1
        Frame.BackgroundTransparency = 0
        Frame.BorderSizePixel        = 0
        Frame.LayoutOrder            = order
        corner(Frame, 6)
        local l = lbl(Frame, text, 12, T.textMid, Enum.Font.GothamBold)
        l.Size = UDim2.new(0.58, -8, 1, 0); l.Position = UDim2.new(0, 14, 0, 0)
        local Input = Instance.new("TextBox", Frame)
        Input.Size                   = UDim2.new(0.36, 0, 0, 22)
        Input.Position               = UDim2.new(0.62, 0, 0.5, -11)
        Input.BackgroundColor3       = T.bg3
        Input.BackgroundTransparency = 0
        Input.BorderSizePixel        = 0
        Input.Text                   = tostring(Config[configKey])
        Input.TextColor3             = T.text
        Input.Font                   = Enum.Font.GothamBold
        Input.TextSize               = 11
        Input.TextScaled             = false
        Input.TextXAlignment         = Enum.TextXAlignment.Center
        corner(Input, 5)
        Input.Focused:Connect(function()  tween(Input, 0.12, { BackgroundColor3 = T.bg2 }) end)
        Input.FocusLost:Connect(function()
            tween(Input, 0.12, { BackgroundColor3 = T.bg3 })
            local n = tonumber(Input.Text)
            if n then Config[configKey] = n; SaveConfig() end
            Input.Text = tostring(Config[configKey])
        end)
    end
    local function SetKeybindRow(text, configKey, order)
        local Frame = Instance.new("Frame", SetPage)
        Frame.Size                   = UDim2.new(1, 0, 0, 34)
        Frame.BackgroundColor3       = T.bg1
        Frame.BackgroundTransparency = 0
        Frame.BorderSizePixel        = 0
        Frame.LayoutOrder            = order
        corner(Frame, 6)
        local l = lbl(Frame, text, 12, T.textMid, Enum.Font.GothamBold)
        l.Size = UDim2.new(0.58, -8, 1, 0); l.Position = UDim2.new(0, 14, 0, 0)
        local BindBtn = Instance.new("TextButton", Frame)
        BindBtn.Size                   = UDim2.new(0.36, 0, 0, 22)
        BindBtn.Position               = UDim2.new(0.62, 0, 0.5, -11)
        BindBtn.BackgroundColor3       = T.bg3
        BindBtn.BackgroundTransparency = 0
        BindBtn.BorderSizePixel        = 0
        BindBtn.Text                   = Config[configKey].Name
        BindBtn.TextColor3             = T.ice
        BindBtn.Font                   = Enum.Font.GothamBold
        BindBtn.TextSize               = 10
        BindBtn.TextScaled             = false
        BindBtn.TextXAlignment         = Enum.TextXAlignment.Center
        corner(BindBtn, 5)
        BindBtn.MouseButton1Click:Connect(function()
            BindBtn.Text = "..."; BindBtn.TextColor3 = T.textLo
            local conn
            conn = UIS.InputBegan:Connect(function(i, p)
                if not p and i.UserInputType == Enum.UserInputType.Keyboard then
                    Config[configKey] = i.KeyCode
                    BindBtn.Text       = i.KeyCode.Name
                    BindBtn.TextColor3 = T.ice
                    SaveConfig(); conn:Disconnect()
                end
            end)
        end)
    end
    local function FeatKeybindRow(text, configKey, order)
        local Frame = Instance.new("Frame", FeatPage)
        Frame.Size                   = UDim2.new(1, 0, 0, ROW_H)
        Frame.BackgroundColor3       = T.bg1
        Frame.BackgroundTransparency = 0
        Frame.BorderSizePixel        = 0
        Frame.LayoutOrder            = order
        corner(Frame, 6)
        local l = lbl(Frame, text, 12, T.textMid, Enum.Font.GothamBold)
        l.Size = UDim2.new(0.58, -8, 1, 0); l.Position = UDim2.new(0, 14, 0, 0)
        local BindBtn = Instance.new("TextButton", Frame)
        BindBtn.Size                   = UDim2.new(0.36, 0, 0, 22)
        BindBtn.Position               = UDim2.new(0.62, 0, 0.5, -11)
        BindBtn.BackgroundColor3       = T.bg3
        BindBtn.BackgroundTransparency = 0
        BindBtn.BorderSizePixel        = 0
        BindBtn.Text                   = Config[configKey].Name
        BindBtn.TextColor3             = T.ice
        BindBtn.Font                   = Enum.Font.GothamBold
        BindBtn.TextSize               = 10
        BindBtn.TextScaled             = false
        BindBtn.TextXAlignment         = Enum.TextXAlignment.Center
        corner(BindBtn, 5)
        BindBtn.MouseButton1Click:Connect(function()
            BindBtn.Text = "..."; BindBtn.TextColor3 = T.textLo
            local conn
            conn = UIS.InputBegan:Connect(function(i, p)
                if not p and i.UserInputType == Enum.UserInputType.Keyboard then
                    Config[configKey] = i.KeyCode
                    BindBtn.Text       = i.KeyCode.Name
                    BindBtn.TextColor3 = T.ice
                    SaveConfig(); conn:Disconnect()
                end
            end)
        end)
    end
    local function FeatInputRow(text, configKey, order)
        local Frame = Instance.new("Frame", FeatPage)
        Frame.Size                   = UDim2.new(1, 0, 0, ROW_H)
        Frame.BackgroundColor3       = T.bg1
        Frame.BackgroundTransparency = 0
        Frame.BorderSizePixel        = 0
        Frame.LayoutOrder            = order
        corner(Frame, 6)
        local l = lbl(Frame, text, 12, T.textMid, Enum.Font.GothamBold)
        l.Size = UDim2.new(0.58, -8, 1, 0); l.Position = UDim2.new(0, 14, 0, 0)
        local Input = Instance.new("TextBox", Frame)
        Input.Size                   = UDim2.new(0.36, 0, 0, 22)
        Input.Position               = UDim2.new(0.62, 0, 0.5, -11)
        Input.BackgroundColor3       = T.bg3
        Input.BackgroundTransparency = 0
        Input.BorderSizePixel        = 0
        Input.Text                   = tostring(Config[configKey])
        Input.TextColor3             = T.text
        Input.Font                   = Enum.Font.GothamBold
        Input.TextSize               = 11
        Input.TextScaled             = false
        Input.TextXAlignment         = Enum.TextXAlignment.Center
        corner(Input, 5)
        Input.Focused:Connect(function()  tween(Input, 0.12, { BackgroundColor3 = T.bg2 }) end)
        Input.FocusLost:Connect(function()
            tween(Input, 0.12, { BackgroundColor3 = T.bg3 })
            local n = tonumber(Input.Text)
            if n then Config[configKey] = n; SaveConfig() end
            Input.Text = tostring(Config[configKey])
        end)
    end
    FeatSectionHeader("SPEED", 1)
    do
        local Frame = Instance.new("Frame", FeatPage)
        Frame.Size                   = UDim2.new(1, 0, 0, ROW_H)
        Frame.BackgroundColor3       = T.bg1
        Frame.BackgroundTransparency = 0
        Frame.BorderSizePixel        = 0
        Frame.LayoutOrder            = 2
        corner(Frame, 6)
        local statusLbl = lbl(Frame, "Status", 12, T.textMid, Enum.Font.GothamBold)
        statusLbl.Size     = UDim2.new(0.5, -8, 1, 0)
        statusLbl.Position = UDim2.new(0, 14, 0, 0)
        local valueLbl = lbl(Frame, "CARRY", 12, T.textLo, Enum.Font.GothamBold, Enum.TextXAlignment.Right)
        valueLbl.Size     = UDim2.new(0.45, -14, 1, 0)
        valueLbl.Position = UDim2.new(0.55, 0, 0, 0)
        FastSpeedSetState = function(s)
            FastSpeedEnabled      = s
            Config.FastSpeedState = s
            if s then
                valueLbl.Text       = "FAST"
                valueLbl.TextColor3 = T.text
            else
                valueLbl.Text       = "CARRY"
                valueLbl.TextColor3 = T.textLo
            end
        end
        FastSpeedSetState(FastSpeedEnabled)
    end
    FeatKeybindRow("Speed Key",  "FastSpeedKey", 3)
    FeatInputRow("Carry Speed",  "CarrySpeed",   4)
    FeatSectionHeader("MOVEMENT", 5)
    local _, autoBatSetState = FeatToggle("Auto Bat", 6, function(s)
        AutoBatEnabled = s; Config.AutoBatState = s
        if s then
            if Float2Enabled then
                AutoBat_Float2WasActive = true
                handleFloat2Toggle(false, nil)
                if float2SetState then float2SetState(false) end
            else
                AutoBat_Float2WasActive = false
            end
            if FloatEnabled then
                AutoBat_Float2WasActive = true
                BrainrotSequenceRunning = false
                FloatEnabled = false; FloatTargetY = nil; FloatActiveSpeed = nil
                FloatDescending = false; FloatDescendingStarted = false
                Config.FloatState = false
                if dropBrainrotSetState then dropBrainrotSetState(false) end
            end
        else
            if AutoBat_Float2WasActive then
                AutoBat_Float2WasActive = false
                handleFloat2Toggle(true, nil)
                if float2SetState then float2SetState(true) end
            end
        end
    end)
    local _, _apSetState, _apSetSide = FeatToggleWithSide("Auto Play", 8,
        sharedSide,
        function(s, side)
            AutoPlayEnabled = s; Config.AutoPlayState = s; Config.AutoPlaySide = side
            if not s then AutoPlayRunning = false
            else
                tryPendingRagdollTP()
                if ragdollOccurred and not ragdollTPCooldown and (tick() - lastRagdollTick < 3) then
                    ragdollOccurred = false
                    ragdollTPCooldown = true
                    local side2 = sharedSide or "L"
                    local data = TP_SIDES[side2]
                    task.spawn(function()
                        AutoPlayEnabled = false; AutoPlayRunning = false
                        if autoPlaySetState then autoPlaySetState(false) end
                        task.wait(0.08)
                        local r = Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
                        if r then r.CFrame = CFrame.new(data.Step1) end
                        task.wait(0.2)
                        r = Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
                        local ragStep2 = side2 == "R" and Vector3.new(-482.89, -5.09, 26.45) or Vector3.new(-482.86, -5.09, 95.34)
                        if r then r.CFrame = CFrame.new(ragStep2 + Vector3.new(0, 3, 0)) end
                        task.wait(0.15)
                        AutoPlayStartStep = 3
                        AutoPlayEnabled = true; AutoPlayRunning = false
                        if autoPlaySetState then autoPlaySetState(true) end
                        task.wait(2.5); ragdollTPCooldown = false
                    end)
                end
            end
        end,
        function(side) switchSide(side) end
    )
    table.insert(_sideRowRefs, { setSide = _apSetSide, setState = _apSetState })
    autoPlaySetState = _apSetState
    local _; _, ragdollTPSetState = FeatToggle("TP on Ragdoll", 9, function(s)
        Config.RagdollAutoTP = s
    end)
    local _, _float2Set = FeatToggle("Float", 10, function(s)
        handleFloat2Toggle(s, nil)
    end)
    float2SetState = _float2Set
    local _, _dropSet = FeatToggle("Drop Brainrot", 11, function(s)
        handleBrainrotToggle(s, _dropSet)
    end)
    dropBrainrotSetState = _dropSet
    FeatSectionHeader("DYNAMICS", 12)
    local _, noAnimSetState = FeatToggle("No Animation", 13, function(s)
        NoAnimEnabled = s; Config.NoAnimState = s; SaveConfig()
        if noAnimConn   then noAnimConn:Disconnect();   noAnimConn   = nil end
        if noAnimHbConn then noAnimHbConn:Disconnect(); noAnimHbConn = nil end
        if s then
            task.spawn(applyNoAnim, Player.Character)
            noAnimConn = Player.CharacterAdded:Connect(function(c) task.spawn(applyNoAnim, c) end)
        else
            local char = Player.Character
            local a = char and char:FindFirstChild("Animate")
            if a then a.Disabled = false end
        end
    end)
    local _, fpsSetState = FeatToggle("FPS Boost", 15, function(s)
        Config.FpsBoostState = s
        if s then
            applyFPSBoostWorld()
            for _, p in pairs(Players:GetPlayers()) do applyFPSBoostCharacter(p.Character) end
            if FPSBoostLocalConn then FPSBoostLocalConn:Disconnect() end
            FPSBoostLocalConn = Player.CharacterAdded:Connect(function(c)
                if Config.FpsBoostState then task.wait(0.3); applyFPSBoostCharacter(c) end
            end)
            if FPSBoostCharConn then FPSBoostCharConn:Disconnect() end
            FPSBoostCharConn = Players.PlayerAdded:Connect(function(p)
                p.CharacterAdded:Connect(function(c)
                    if Config.FpsBoostState then task.wait(0.3); applyFPSBoostCharacter(c) end
                end)
            end)
            SaveConfig()
        else
            if FPSBoostLocalConn then FPSBoostLocalConn:Disconnect(); FPSBoostLocalConn = nil end
            if FPSBoostCharConn  then FPSBoostCharConn:Disconnect();  FPSBoostCharConn  = nil end
            SaveConfig()
        end
    end)
    local _, espSetState = FeatToggle("ESP", 16, function(s)
        Config.ESPEnabled = s
        for plr in pairs(ESPTracers) do
            if plr.Character then
                local r = plr.Character:FindFirstChild("HumanoidRootPart")
                if r then local tag = r:FindFirstChild("ESP_NameTag"); if tag then tag.Enabled = s end end
            end
        end
        if not s then for _, line in pairs(ESPTracers) do line.Visible = false end end
    end)
    local _, ragdollSetState = FeatToggle("No Ragdoll", 17, function(s)
        Config.AntiRagdollEnabled = s
        if s then startAntiRagdoll() else stopAntiRagdoll() end
    end)
    local _, grabSetState = FeatToggle("Grab", 18, function(s)
        GrabActive = s; Config.GrabState = s
        if not s then Interacting = false; PillFill.Size = UDim2.new(0, 0, 1, 0); BarPctLbl.Text = "0" end
    end)
    local _, infJumpSetState = FeatToggle("Infinite Jump", 19, function(s)
        Config.InfJumpEnabled = s
    end)
    local _, noclipSetState = FeatToggle("Noclip Players", 20, function(s)
        NoclipPlayersEnabled = s; Config.NoclipPlayersState = s; SaveConfig()
    end)
    SetSectionHeader("KEYBINDS", 1)
    SetKeybindRow("Drop Key",  "FloatKey",    2)
    SetKeybindRow("Float Key", "Float2Key",   3)
    SetKeybindRow("Auto Bat",  "AutoBatKey",  4)
    SetKeybindRow("Auto TP",   "AutoTPKey",   5)
    SetKeybindRow("Auto Play", "AutoPlayKey", 6)
    SetSectionHeader("VALUES", 7)
    SetInputRow("Speed",        "FastSpeed",    8)
    SetInputRow("Float Height", "Float2Height", 9)
    do
        Config.BatDist        = 0
        Config.Step2Delay     = 0.05
        Config.FloatHeight    = 18
        Config.FloatSpeed     = 85
        Config.Float2Speed    = 45
        Config.AutoBatSpeed   = 58
        if Config.FastSpeedState     then FastSpeedSetState(true)                              end
        if Config.AutoBatState       then AutoBatEnabled = true;       autoBatSetState(true)   end
        if Config.GrabState          then GrabActive = true;           grabSetState(true)      end
        if Config.AntiRagdollEnabled then ragdollSetState(true);       startAntiRagdoll()      end
        if Config.RagdollAutoTP      then ragdollTPSetState(true)                              end
        if Config.NoclipPlayersState then NoclipPlayersEnabled = true; noclipSetState(true)    end
        if Config.InfJumpEnabled     then infJumpSetState(true)                                end
        if Config.ESPEnabled then
            espSetState(true)
            for plr in pairs(ESPTracers) do
                if plr.Character then
                    local r = plr.Character:FindFirstChild("HumanoidRootPart")
                    if r then local t = r:FindFirstChild("ESP_NameTag"); if t then t.Enabled = true end end
                end
            end
        end
        local savedSide = Config.AutoPlaySide or "L"
        switchSide(savedSide)
        AutoTPREnabled = savedSide == "R"; AutoTPLEnabled = savedSide == "L"
        Config.AutoTPRState = AutoTPREnabled; Config.AutoTPLState = AutoTPLEnabled
        if savedSide == "L" then Config.StopOnLeft = true; Config.StopOnRight = false
        else Config.StopOnRight = true; Config.StopOnLeft = false end
        if Config.Float2State then
            _float2Set(true)
            handleFloat2Toggle(true, nil)
        end
        if Config.FpsBoostState then
            fpsSetState(true)
            task.spawn(function()
                task.wait(1)
                if not Config.FpsBoostState then return end
                applyFPSBoostWorld()
                for _, p in pairs(Players:GetPlayers()) do applyFPSBoostCharacter(p.Character) end
            end)
        end
        if Config.NoAnimState then
            task.spawn(function()
                NoAnimEnabled = true; noAnimSetState(true)
                noAnimConn = Player.CharacterAdded:Connect(function(c) task.spawn(applyNoAnim, c) end)
                applyNoAnim(Player.Character or Player.CharacterAdded:Wait())
            end)
        end
        if _apSetSide then _apSetSide(Config.AutoPlaySide or "L") end
    end
    UIS.InputBegan:Connect(function(i, p)
        if p then return end
        if i.KeyCode == Enum.KeyCode.Space and Config.InfJumpEnabled then
            task.spawn(function()
                while UIS:IsKeyDown(Enum.KeyCode.Space) and Config.InfJumpEnabled do
                    local char = Player.Character
                    local root = char and char:FindFirstChild("HumanoidRootPart")
                    local hum  = char and char:FindFirstChildOfClass("Humanoid")
                    if root and hum and hum.Health > 0 then
                        root.AssemblyLinearVelocity = Vector3.new(
                            root.AssemblyLinearVelocity.X, math.random(42, 48), root.AssemblyLinearVelocity.Z)
                    end
                    task.wait(0.05)
                end
            end)
        end
        if i.KeyCode == Config.FastSpeedKey then
            if FastSpeedSetState then FastSpeedSetState(not FastSpeedEnabled) end
        elseif i.KeyCode == Config.AutoBatKey then
            AutoBatEnabled = not AutoBatEnabled; Config.AutoBatState = AutoBatEnabled
            if AutoBatEnabled then
                if Float2Enabled then
                    AutoBat_Float2WasActive = true
                    handleFloat2Toggle(false, nil)
                    if float2SetState then float2SetState(false) end
                else
                    AutoBat_Float2WasActive = false
                end
                if FloatEnabled then
                    AutoBat_Float2WasActive = true
                    BrainrotSequenceRunning = false
                    FloatEnabled = false; FloatTargetY = nil; FloatActiveSpeed = nil
                    FloatDescending = false; FloatDescendingStarted = false
                    Config.FloatState = false
                    if dropBrainrotSetState then dropBrainrotSetState(false) end
                end
            else
                if AutoBat_Float2WasActive then
                    AutoBat_Float2WasActive = false
                    handleFloat2Toggle(true, nil)
                    if float2SetState then float2SetState(true) end
                end
            end
            autoBatSetState(AutoBatEnabled)
        elseif i.KeyCode == Config.AutoTPKey then
            local side = AutoTPREnabled and "R" or AutoTPLEnabled and "L"
                    or Config.AutoTPRState and "R" or Config.AutoTPLState and "L"
            if side then doAutoTP(side) end
        elseif i.KeyCode == Config.FloatKey then
            local s = not FloatEnabled
            if _dropSet then _dropSet(s) end
            handleBrainrotToggle(s, _dropSet)
        elseif i.KeyCode == Config.Float2Key then
            local s = not Float2Enabled
            handleFloat2Toggle(s, nil)
            if _float2Set then _float2Set(s) end
            SaveConfig()
        elseif i.KeyCode == Config.AutoPlayKey then
            AutoPlayEnabled = not AutoPlayEnabled; Config.AutoPlayState = AutoPlayEnabled
            if not AutoPlayEnabled then
                AutoPlayRunning = false
            else
                tryPendingRagdollTP()
                if ragdollOccurred and not ragdollTPCooldown and (tick() - lastRagdollTick < 3) then
                    ragdollOccurred = false
                    ragdollTPCooldown = true
                    local side2 = sharedSide or "L"
                    local data = TP_SIDES[side2]
                    task.spawn(function()
                        AutoPlayEnabled = false; AutoPlayRunning = false
                        if autoPlaySetState then autoPlaySetState(false) end
                        task.wait(0.08)
                        local r = Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
                        if r then r.CFrame = CFrame.new(data.Step1) end
                        task.wait(0.2)
                        r = Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
                        local ragStep2 = side2 == "R" and Vector3.new(-482.89, -5.09, 26.45) or Vector3.new(-482.86, -5.09, 95.34)
                        if r then r.CFrame = CFrame.new(ragStep2 + Vector3.new(0, 3, 0)) end
                        task.wait(0.15)
                        AutoPlayStartStep = 3
                        AutoPlayEnabled = true; AutoPlayRunning = false
                        if autoPlaySetState then autoPlaySetState(true) end
                        task.wait(2.5); ragdollTPCooldown = false
                    end)
                end
            end
            if autoPlaySetState then autoPlaySetState(AutoPlayEnabled) end
        end
    end)