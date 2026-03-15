if not game:IsLoaded() then game.Loaded:Wait() end

-- ============================================================
-- SERVICES
-- ============================================================
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

-- ============================================================
-- CONFIG
-- ============================================================
local Config = {
    FastSpeed           = 54,
    FastSpeedKey        = Enum.KeyCode.T,
    CarrySpeed          = 29,
    BatDist             = 0,
    AutoBatKey          = Enum.KeyCode.V,
    AutoBatSpeed        = 58,
    GrabSpeed           = 0,
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
    PositionsLocked     = false,
    GuiOpen             = true,
    DropPopX     = nil, DropPopY     = nil, DropPopW     = nil, DropPopH     = nil,
    AutoPlayPopX = nil, AutoPlayPopY = nil, AutoPlayPopW = nil, AutoPlayPopH = nil,
    AutoBatPopX  = nil, AutoBatPopY  = nil, AutoBatPopW  = nil, AutoBatPopH  = nil,
    FloatPopX    = nil, FloatPopY    = nil, FloatPopW    = nil, FloatPopH    = nil,
    OpenerX      = nil, OpenerY      = nil,
}

local KEYBIND_DEFAULTS = {
    FastSpeedKey = Enum.KeyCode.T,
    AutoBatKey   = Enum.KeyCode.V,
    FloatKey     = Enum.KeyCode.F,
    Float2Key    = Enum.KeyCode.J,
    AutoTPKey    = Enum.KeyCode.G,
    AutoPlayKey  = Enum.KeyCode.H,
}

local ConfigFile = "adv1se_mobile_config.json"

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
    Config.BatDist      = 0
    Config.Step2Delay   = 0.05
    Config.FloatHeight  = 18
    Config.FloatSpeed   = 85
    Config.Float2Speed  = 45
    Config.AutoBatSpeed = 58
end
LoadConfig()
for k, default in pairs(KEYBIND_DEFAULTS) do
    if typeof(Config[k]) ~= "EnumItem" then Config[k] = default end
end
local sharedSide = Config.AutoPlaySide == "R" and "R" or "L"

-- ============================================================
-- RUNTIME STATE
-- ============================================================
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
local wasAutoPlaying          = false
local ragdollOccurred         = false
local lastRagdollTick         = 0
local ragdollTPCooldown       = false
local pendingRagdollTP        = false
local ragdollTPToken          = 0
local MobileJumpHeld          = false
local MobileJumpActive        = false

-- ============================================================
-- DAO BAT ACTIVATOR
-- ============================================================
do
    local function startBatLoop(character, tool)
        if not (tool:IsA("Tool") and tool.Name:lower() == "bat") then return end
        tool.RequiresHandle = false
        task.spawn(function()
            while tool.Parent == character and AutoBatEnabled do
                pcall(function() tool:Activate() end)
                task.wait(0.1)
            end
        end)
    end

    local function hookCharacter(character)
        character.ChildAdded:Connect(function(child)
            if AutoBatEnabled then startBatLoop(character, child) end
        end)
        local existing = character:FindFirstChildOfClass("Tool")
        if existing and AutoBatEnabled then startBatLoop(character, existing) end
    end

    local initChar = Player.Character or Player.CharacterAdded:Wait()
    hookCharacter(initChar)
    Player.CharacterAdded:Connect(hookCharacter)
end

local FastSpeedSetState    = nil
local autoPlaySetState     = nil
local dropBrainrotSetState = nil
local float2SetState       = nil
local ragdollTPSetState    = nil

local _sideRowRefs = {}
local TitlePills   = { setL = nil, setR = nil }

-- ============================================================
-- MOBILE INFINITE JUMP
-- ============================================================
local function setupInfJump()
    UIS.JumpRequest:Connect(function()
        if not Config.InfJumpEnabled then return end
        local hum = Player.Character and Player.Character:FindFirstChildOfClass("Humanoid")
        if not hum or hum.Health <= 0 then return end
        MobileJumpActive = true
        task.delay(0.05, function() MobileJumpActive = false end)
    end)

    task.spawn(function()
        local pg      = Player.PlayerGui
        local touchGui = pg:WaitForChild("TouchGui", 15)
        if not touchGui then return end
        local frame   = touchGui:WaitForChild("TouchControlFrame", 10)
        if not frame then return end
        local jumpBtn = frame:WaitForChild("JumpButton", 10)
        if not jumpBtn then return end

        local jumpTouchId = nil

        jumpBtn.InputBegan:Connect(function(i)
            if i.UserInputType == Enum.UserInputType.Touch
            and i.UserInputState == Enum.UserInputState.Begin
            and Config.InfJumpEnabled then
                jumpTouchId    = i
                MobileJumpHeld = true
            end
        end)

        jumpBtn.InputEnded:Connect(function(i)
            if i.UserInputType == Enum.UserInputType.Touch then
                if i == jumpTouchId then
                    jumpTouchId    = nil
                    MobileJumpHeld = false
                end
            end
        end)

        UIS.InputEnded:Connect(function(i)
            if i.UserInputType == Enum.UserInputType.Touch and i == jumpTouchId then
                jumpTouchId    = nil
                MobileJumpHeld = false
            end
        end)

        RunService.Heartbeat:Connect(function()
            if MobileJumpHeld and not Config.InfJumpEnabled then
                jumpTouchId    = nil
                MobileJumpHeld = false
            end
        end)
    end)
end
setupInfJump()

-- ============================================================
-- GAME DATA
-- ============================================================
local PromptCache     = {}
local PromptCacheTime = 0
local CACHE_TTL       = 2

local TP_SIDES = {
    R = { Step1 = Vector3.new(-473.42,-7.30,22.15),  Step2 = Vector3.new(-483.69,-5.20,25.19)  },
    L = { Step1 = Vector3.new(-470.56,-7.30,100.08), Step2 = Vector3.new(-484.26,-5.20,100.14) },
}
local AutoTPRunning = false

local AutoPlayStepsL = {
    Vector3.new(-475.60,-7.20,93.74), Vector3.new(-482.68,-5.34,94.92),
    Vector3.new(-476.66,-6.69,92.92), Vector3.new(-476.44,-6.75,27.55),
    Vector3.new(-485.52,-5.05,27.29),
}
local AutoPlayStepsR = {
    Vector3.new(-475.59,-7.30,27.76), Vector3.new(-482.40,-5.34,27.23),
    Vector3.new(-476.48,-6.76,28.86), Vector3.new(-476.68,-6.59,94.13),
    Vector3.new(-484.26,-5.35,94.00),
}

local ZoneDefs = {
    Left  = { pos = Vector3.new(-496.2,-5.1,100.1), size = Vector3.new(32,6,18) },
    Right = { pos = Vector3.new(-496.7,-5.3, 21.6), size = Vector3.new(32,6,18) },
}

local function isInZone(pos, zone)
    local d = pos - zone.pos
    return math.abs(d.X) < zone.size.X/2 and math.abs(d.Z) < zone.size.Z/2
end

local function getGroundHeight(rootPos)
    local origin = rootPos + Vector3.new(0,-0.5,0)
    local params = RaycastParams.new()
    local excluded = {}
    if Player.Character then table.insert(excluded, Player.Character) end
    for _, p in pairs(Players:GetPlayers()) do
        if p ~= Player and p.Character then table.insert(excluded, p.Character) end
    end
    params.FilterDescendantsInstances = excluded
    params.FilterType = Enum.RaycastFilterType.Exclude
    local remaining = 500
    local cur = origin
    while remaining > 0 do
        local result = workspace:Raycast(cur, Vector3.new(0,-remaining,0), params)
        if not result then break end
        if result.Instance and result.Instance.CanCollide then return result.Position.Y end
        local newO = result.Position + Vector3.new(0,-0.05,0)
        remaining  = remaining - (cur.Y - newO.Y)
        cur        = newO
    end
    return rootPos.Y - 500
end

-- ============================================================
-- THEME — ARCTIC / BLACK
-- ============================================================
local T = {
    bg0     = Color3.fromRGB(4,   6,   10),   -- deepest black
    bg1     = Color3.fromRGB(10,  15,  22),   -- panel background
    bg2     = Color3.fromRGB(16,  24,  36),   -- tab bar / rows
    bg3     = Color3.fromRGB(28,  42,  62),   -- active tab / highlights
    text    = Color3.fromRGB(220, 240, 255),  -- bright arctic white
    textMid = Color3.fromRGB(130, 185, 220),  -- mid ice blue
    textLo  = Color3.fromRGB(45,  80,  115),  -- dim faded blue
    ice     = Color3.fromRGB(110, 200, 255),  -- accent cyan/ice
    green   = Color3.fromRGB(90,  220, 195),  -- success teal
    dotOn   = Color3.fromRGB(90,  195, 255),  -- toggle on — bright ice
    dotOff  = Color3.fromRGB(20,  38,  58),   -- toggle off — dark
    trackBg = Color3.fromRGB(14,  24,  38),   -- toggle track
    popOff  = Color3.fromRGB(5,   7,   12),   -- popout inactive
    popOn   = Color3.fromRGB(8,   50,  100),  -- popout active — deep arctic blue
}

-- ============================================================
-- UI HELPERS
-- ============================================================
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
    l.TextSize       = size or 10
    l.TextScaled     = false
    l.RichText       = false
    l.TextXAlignment = xalign or Enum.TextXAlignment.Left
    return l
end

local function tw(obj, t, props)
    TweenService:Create(obj, TweenInfo.new(t, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), props):Play()
end

-- ============================================================
-- SIDE SWITCHER
-- ============================================================
local function switchSide(side)
    sharedSide = side
    Config.AutoPlaySide = side
    if side == "R" then
        AutoTPREnabled = true;  AutoTPLEnabled = false
        Config.AutoTPRState = true; Config.AutoTPLState = false
    else
        AutoTPLEnabled = true;  AutoTPREnabled = false
        Config.AutoTPLState = true; Config.AutoTPRState = false
    end
    if side == "L" then Config.StopOnLeft = true; Config.StopOnRight = false
    else Config.StopOnRight = true; Config.StopOnLeft = false end
    for _, ref in ipairs(_sideRowRefs) do
        if ref.setSide then ref.setSide(side) end
    end
    if TitlePills.setL and TitlePills.setR then
        if side == "L" then TitlePills.setL(true); TitlePills.setR(false)
        else TitlePills.setR(true); TitlePills.setL(false) end
    end
    if AutoPlayEnabled then AutoPlayRunning = false end
    SaveConfig()
end

-- ============================================================
-- SCREENGUI
-- ============================================================
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name         = "adv1se_GUI"
ScreenGui.Parent       = PlayerGui
ScreenGui.ResetOnSpawn = false

-- ============================================================
-- STEAL BAR
-- ============================================================
local vp        = Camera.ViewportSize
local STEAL_W   = math.floor(vp.X * 0.38)

local StealBarOuter = Instance.new("Frame", ScreenGui)
StealBarOuter.Size                   = UDim2.new(0, STEAL_W + 16, 0, 26)
StealBarOuter.Position               = UDim2.new(0.5, -(STEAL_W + 16)/2, 0, 10)
StealBarOuter.BackgroundColor3       = Color3.fromRGB(6, 8, 14)
StealBarOuter.BackgroundTransparency = 0.45
StealBarOuter.BorderSizePixel        = 0
StealBarOuter.ZIndex                 = 20
corner(StealBarOuter, 6)
local _barStroke = Instance.new("UIStroke", StealBarOuter)
_barStroke.Color     = Color3.fromRGB(25, 55, 90)
_barStroke.Thickness = 1

local PillTrack = Instance.new("Frame", StealBarOuter)
PillTrack.Size             = UDim2.new(1, 0, 0, 6)
PillTrack.Position         = UDim2.new(0, 0, 0, 0)
PillTrack.BackgroundColor3 = Color3.fromRGB(18, 30, 48)
PillTrack.BorderSizePixel  = 0
PillTrack.ZIndex           = 21
corner(PillTrack, 99)

local PillFill = Instance.new("Frame", PillTrack)
PillFill.Size             = UDim2.new(0, 0, 1, 0)
PillFill.BackgroundColor3 = T.ice
PillFill.BorderSizePixel  = 0
PillFill.ZIndex           = 22
corner(PillFill, 99)

local BarPctLbl = lbl(StealBarOuter, "0", 14, T.text, Enum.Font.GothamBlack, Enum.TextXAlignment.Left)
BarPctLbl.Size     = UDim2.new(0, 40, 0, 18)
BarPctLbl.Position = UDim2.new(0, 4, 0, 0)
BarPctLbl.ZIndex   = 22

local BarBrandLbl = lbl(StealBarOuter, "https://discord.gg/mHkpd2DAnQ", 14, T.text, Enum.Font.GothamBlack, Enum.TextXAlignment.Center)
BarBrandLbl.Size     = UDim2.new(1, 0, 0, 18)
BarBrandLbl.Position = UDim2.new(0, 0, 1, -18)
BarBrandLbl.ZIndex   = 22

-- ============================================================
-- MAIN PANEL
-- ============================================================
local W, H = 310, 240

local MainFrame = Instance.new("Frame", ScreenGui)
MainFrame.Name                   = "MainFrame"
MainFrame.BackgroundColor3       = T.bg0
MainFrame.BackgroundTransparency = 0
MainFrame.Position               = UDim2.new(0.5, -W/2, 0.5, -H/2)
MainFrame.Size                   = UDim2.new(0, W, 0, H)
MainFrame.BorderSizePixel        = 0
MainFrame.Active                 = true
MainFrame.Draggable              = false
MainFrame.Visible                = Config.GuiOpen ~= false
corner(MainFrame, 8)

-- ============================================================
-- TITLE BAR
-- ============================================================
local TITLE_H = 30

local TitleBar = Instance.new("Frame", MainFrame)
TitleBar.Size                   = UDim2.new(1, 0, 0, TITLE_H)
TitleBar.BackgroundColor3       = T.bg1
TitleBar.BackgroundTransparency = 0
TitleBar.BorderSizePixel        = 0
TitleBar.ZIndex                 = 2
corner(TitleBar, 8)

local TitleMask = Instance.new("Frame", TitleBar)
TitleMask.Size             = UDim2.new(1, 0, 0.5, 0)
TitleMask.Position         = UDim2.new(0, 0, 0.5, 0)
TitleMask.BackgroundColor3 = T.bg1
TitleMask.BorderSizePixel  = 0
TitleMask.Active           = false

-- Drag via title bar
do
    local dragging, dragStart, startPos = false, nil, nil
    TitleBar.InputBegan:Connect(function(i, sunk)
        if sunk then return end
        if i.UserInputType == Enum.UserInputType.MouseButton1
        or i.UserInputType == Enum.UserInputType.Touch then
            dragging = true; dragStart = i.Position; startPos = MainFrame.Position
        end
    end)
    TitleBar.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1
        or i.UserInputType == Enum.UserInputType.Touch then dragging = false end
    end)
    UIS.InputChanged:Connect(function(i)
        if not dragging then return end
        if i.UserInputType == Enum.UserInputType.MouseMovement
        or i.UserInputType == Enum.UserInputType.Touch then
            local d = i.Position - dragStart
            MainFrame.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + d.X,
                startPos.Y.Scale, startPos.Y.Offset + d.Y)
        end
    end)
end

-- Dot accent
local TitleDot = Instance.new("Frame", TitleBar)
TitleDot.Size             = UDim2.new(0, 4, 0, 4)
TitleDot.Position         = UDim2.new(0, 8, 0.5, -2)
TitleDot.BackgroundColor3 = T.ice
TitleDot.BorderSizePixel  = 0
corner(TitleDot, 10)

-- Name
local NameTag = lbl(TitleBar, "TRIDENT", 13, T.text, Enum.Font.GothamBlack)
NameTag.Size           = UDim2.new(0, 70, 1, 0)
NameTag.Position       = UDim2.new(0, 16, 0, 0)
NameTag.TextXAlignment = Enum.TextXAlignment.Left
NameTag.ZIndex         = 3

-- FPS/Ping label
local FPSPingLbl = lbl(TitleBar, "FPS:00 PING:00ms", 8, T.textLo, Enum.Font.GothamBold, Enum.TextXAlignment.Center)
FPSPingLbl.Size     = UDim2.new(0, 110, 1, 0)
FPSPingLbl.Position = UDim2.new(0.5, -55, 0, 0)
FPSPingLbl.ZIndex   = 3

task.spawn(function()
    while task.wait(0.6) do
        FPSPingLbl.Text = string.format("FPS:%d PING:%dms",
            math.floor(Stats.Workspace.Heartbeat:GetValue()),
            math.floor(Player:GetNetworkPing() * 1000))
    end
end)

-- L / R side pills
local function makeTitleSidePill(label, xOff, active)
    local btn = Instance.new("TextButton", TitleBar)
    btn.Size             = UDim2.new(0, 32, 0, 22)
    btn.Position         = UDim2.new(1, xOff, 0.5, -9)
    btn.Font             = Enum.Font.GothamBlack
    btn.TextSize         = 14
    btn.TextScaled       = false
    btn.Text             = label
    btn.BorderSizePixel  = 0
    btn.ZIndex           = 4
    corner(btn, 4)
    local function setActive(v)
        btn.BackgroundColor3 = v and T.bg3  or T.bg2
        btn.TextColor3       = v and T.text or T.textLo
    end
    setActive(active)
    btn.MouseButton1Click:Connect(function() switchSide(label) end)
    return setActive
end

local titleSetL = makeTitleSidePill("L", -76, sharedSide == "L")
local titleSetR = makeTitleSidePill("R", -50, sharedSide == "R")
TitlePills.setL = titleSetL
TitlePills.setR = titleSetR

-- Close button
local CloseBtn = Instance.new("TextButton", TitleBar)
CloseBtn.Size             = UDim2.new(0, 22, 0, 18)
CloseBtn.Position         = UDim2.new(1, -26, 0.5, -9)
CloseBtn.BackgroundColor3 = T.bg3
CloseBtn.BorderSizePixel  = 0
CloseBtn.Text             = "—"
CloseBtn.TextColor3       = T.textMid
CloseBtn.Font             = Enum.Font.GothamBold
CloseBtn.TextSize         = 10
CloseBtn.TextScaled       = false
CloseBtn.ZIndex           = 4
corner(CloseBtn, 4)

-- ============================================================
-- TABS
-- ============================================================
local TAB_H    = 22
local TAB_TOP  = TITLE_H + 3
local PAGE_TOP = TAB_TOP + TAB_H + 3
local PAGE_H   = H - PAGE_TOP - 6

local TabBar = Instance.new("Frame", MainFrame)
TabBar.Size                   = UDim2.new(1, -10, 0, TAB_H)
TabBar.Position               = UDim2.new(0, 5, 0, TAB_TOP)
TabBar.BackgroundColor3       = T.bg2
TabBar.BackgroundTransparency = 0
TabBar.BorderSizePixel        = 0
corner(TabBar, 5)

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
    btn.TextSize               = 9
    btn.TextScaled             = false
    btn.Text                   = name
    btn.TextColor3             = T.textLo
    btn.LayoutOrder            = order
    corner(btn, 5)

    local page = Instance.new("ScrollingFrame", MainFrame)
    page.BackgroundTransparency = 1
    page.Position               = UDim2.new(0, 5, 0, PAGE_TOP)
    page.Size                   = UDim2.new(1, -10, 0, PAGE_H)
    page.CanvasSize             = UDim2.new(0, 0, 0, 0)
    page.AutomaticCanvasSize    = Enum.AutomaticSize.Y
    page.ScrollBarThickness     = 2
    page.ScrollBarImageColor3   = Color3.fromRGB(30, 60, 90)
    page.BorderSizePixel        = 0
    page.ScrollingDirection     = Enum.ScrollingDirection.Y
    page.ClipsDescendants       = true
    page.Visible                = (name == ActiveTab)

    local layout = Instance.new("UIListLayout", page)
    layout.Padding             = UDim.new(0, 2)
    layout.SortOrder           = Enum.SortOrder.LayoutOrder
    layout.FillDirection       = Enum.FillDirection.Horizontal
    layout.Wraps               = true
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Left

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

-- ============================================================
-- KATANA OPENER
-- ============================================================
local vp2 = Camera.ViewportSize
local OPENER_SIZE = 52

local openerDefaultX = (Config.OpenerX and tonumber(Config.OpenerX)) or (vp2.X - OPENER_SIZE - 10)
local openerDefaultY = (Config.OpenerY and tonumber(Config.OpenerY)) or (vp2.Y - OPENER_SIZE - 80)

local OpenerFrame = Instance.new("Frame", ScreenGui)
OpenerFrame.Name             = "KatanaOpener"
OpenerFrame.Size             = UDim2.new(0, OPENER_SIZE, 0, OPENER_SIZE)
OpenerFrame.Position         = UDim2.new(0, openerDefaultX, 0, openerDefaultY)
OpenerFrame.BackgroundColor3 = Color3.fromRGB(4, 6, 10)
OpenerFrame.BorderSizePixel  = 0
OpenerFrame.Active           = true
OpenerFrame.ZIndex           = 30
OpenerFrame.Visible          = not (Config.GuiOpen ~= false)
corner(OpenerFrame, 8)

local OpenerStroke = Instance.new("UIStroke", OpenerFrame)
OpenerStroke.Color     = Color3.fromRGB(30, 90, 155)
OpenerStroke.Thickness = 1.5

local KatanaLbl = Instance.new("TextLabel", OpenerFrame)
KatanaLbl.Size                   = UDim2.new(1, 0, 0, 30)
KatanaLbl.Position               = UDim2.new(0, 0, 0, 4)
KatanaLbl.BackgroundTransparency = 1
KatanaLbl.Text                   = "🗡"
KatanaLbl.TextColor3             = Color3.fromRGB(80, 175, 235)
KatanaLbl.Font                   = Enum.Font.GothamBold
KatanaLbl.TextSize               = 24
KatanaLbl.TextScaled             = false
KatanaLbl.TextXAlignment         = Enum.TextXAlignment.Center
KatanaLbl.ZIndex                 = 31

local OpenerNameLbl = Instance.new("TextLabel", OpenerFrame)
OpenerNameLbl.Size                   = UDim2.new(1, 0, 0, 12)
OpenerNameLbl.Position               = UDim2.new(0, 0, 1, -14)
OpenerNameLbl.BackgroundTransparency = 1
OpenerNameLbl.Text                   = "TRIDENT"
OpenerNameLbl.TextColor3             = Color3.fromRGB(60, 145, 205)
OpenerNameLbl.Font                   = Enum.Font.GothamBlack
OpenerNameLbl.TextSize               = 8
OpenerNameLbl.TextScaled             = false
OpenerNameLbl.TextXAlignment         = Enum.TextXAlignment.Center
OpenerNameLbl.ZIndex                 = 31

do
    local opDragging = false
    local opDragStart, opDragStartPos = nil, nil
    local opMoved = false

    OpenerFrame.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.Touch
        or i.UserInputType == Enum.UserInputType.MouseButton1 then
            if Config.PositionsLocked then return end
            opDragging    = true
            opMoved       = false
            opDragStart   = i.Position
            opDragStartPos = OpenerFrame.Position
        end
    end)
    OpenerFrame.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.Touch
        or i.UserInputType == Enum.UserInputType.MouseButton1 then
            opDragging = false
            if not opMoved then
                MainFrame.Visible   = true
                OpenerFrame.Visible = false
                Config.GuiOpen      = true
                SaveConfig()
            else
                Config.OpenerX = OpenerFrame.Position.X.Offset
                Config.OpenerY = OpenerFrame.Position.Y.Offset
                SaveConfig()
            end
        end
    end)
    UIS.InputChanged:Connect(function(i)
        if not opDragging then return end
        if Config.PositionsLocked then opDragging = false; return end
        if i.UserInputType == Enum.UserInputType.Touch
        or i.UserInputType == Enum.UserInputType.MouseMovement then
            local delta = i.Position - opDragStart
            if delta.Magnitude > 2 then opMoved = true end
            OpenerFrame.Position = UDim2.new(
                0, opDragStartPos.X.Offset + delta.X,
                0, opDragStartPos.Y.Offset + delta.Y)
        end
    end)
end

CloseBtn.MouseButton1Click:Connect(function()
    MainFrame.Visible   = false
    OpenerFrame.Visible = true
    Config.GuiOpen      = false
    SaveConfig()
end)

-- ============================================================
-- AUTO TP
-- ============================================================
local function doAutoTP(side)
    if AutoTPRunning then return end
    AutoTPRunning = true
    local data = TP_SIDES[side]
    task.spawn(function()
        local root = Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
        if root then root.CFrame = CFrame.new(data.Step1) end
        task.wait(0.2)
        root = Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
        if root then root.CFrame = CFrame.new(data.Step2 + Vector3.new(0,6,0)) end
        AutoTPRunning = false
        task.wait(0.05)
        root = Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
        if root and AutoPlayEnabled then
            local zone = Config.StopOnLeft and ZoneDefs.Left or Config.StopOnRight and ZoneDefs.Right
            if zone and isInZone(root.Position, zone) then AutoPlayRunning = false end
        end
    end)
end

-- ============================================================
-- DROP BRAINROT
-- ============================================================
local function handleBrainrotToggle(s, setStateFn)
    BrainrotSequenceRunning = false
    FloatEnabled            = false
    FloatTargetY            = nil
    FloatActiveSpeed        = nil
    FloatDescending         = false
    FloatDescendingStarted  = false
    Config.FloatState       = false

    if not s then return end

    task.wait(0.03)

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
        if not r then BrainrotSequenceRunning = false; if setStateFn then setStateFn(false) end; return end

        local groundY = getGroundHeight(r.Position)
        local targetY = groundY + Config.FloatHeight

        if r.Position.Y < targetY - 0.5 then
            local prevY, stuckFrames = r.Position.Y, 0
            while not aborted() do
                r = getRoot(); if not r then break end
                if r.Position.Y >= targetY - 0.5 then break end
                if math.abs(r.Position.Y - prevY) < 0.02 then
                    stuckFrames += 1; if stuckFrames >= 4 then break end
                else stuckFrames = 0 end
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
            if r.Position.Y - getGroundHeight(r.Position) <= 3 then break end
            if tick() - descentStart > 2 then break end
            r.AssemblyLinearVelocity = Vector3.new(r.AssemblyLinearVelocity.X, -200, r.AssemblyLinearVelocity.Z)
            task.wait(0.03)
        end
        if aborted() then return end

        BrainrotSequenceRunning = false
        FloatEnabled = false; Config.FloatState = false; FloatTargetY = nil; FloatActiveSpeed = nil
        r = getRoot()
        if r then r.AssemblyLinearVelocity = Vector3.new(r.AssemblyLinearVelocity.X, 0, r.AssemblyLinearVelocity.Z) end
        if setStateFn then setStateFn(false) end

        if float2WasActive then
            r = getRoot()
            Float2Enabled = true; Config.Float2State = true
            Float2TargetY = r and (r.Position.Y + Config.Float2Height) or nil
            if float2SetState then float2SetState(true) end
        end
    end)
end

-- ============================================================
-- FLOAT
-- ============================================================
local function handleFloat2Toggle(s, _)
    Float2Enabled = s; Config.Float2State = s
    if not s then Float2TargetY = nil end
end

-- ============================================================
-- RAGDOLL
-- ============================================================
local RAGDOLL_STEP2 = {
    R = Vector3.new(-484.67,-5.40, 21.92),
    L = Vector3.new(-484.86,-5.35,100.63),
}

local function tryPendingRagdollTP()
    if pendingRagdollTP and (tick() - lastRagdollTick < 3) then
        pendingRagdollTP = false
        task.spawn(function()
            local tpSide = sharedSide or "L"
            local root   = Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
            if not root then return end
            root.CFrame = CFrame.new(TP_SIDES[tpSide].Step1)
            task.wait(0.2)
            root = Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
            if not root then return end
            root.CFrame = CFrame.new(RAGDOLL_STEP2[tpSide])
            task.wait(0.15); AutoPlayStartStep = 2
        end)
        return true
    end
    pendingRagdollTP = false
    return false
end

local function startAntiRagdoll()
    if AntiRagdollConnection then return end
    AntiRagdollConnection = RunService.Heartbeat:Connect(function()
        local char = Player.Character; if not char then return end
        local root = char:FindFirstChild("HumanoidRootPart")
        local hum  = char:FindFirstChildOfClass("Humanoid")
        if hum then
            local s = hum:GetState()
            if s == Enum.HumanoidStateType.Physics
            or s == Enum.HumanoidStateType.Ragdoll
            or s == Enum.HumanoidStateType.FallingDown then
                lastRagdollTick = tick(); ragdollOccurred = true
                AutoPlayEnabled = false; AutoPlayRunning = false; Config.AutoPlayState = false
                if autoPlaySetState then autoPlaySetState(false) end
                hum:ChangeState(Enum.HumanoidStateType.Running)
                workspace.CurrentCamera.CameraSubject = hum
                pcall(function()
                    local pm = Player.PlayerScripts:FindFirstChild("PlayerModule")
                    if pm then require(pm:FindFirstChild("ControlModule")):Enable() end
                end)
                if root then root.Velocity = Vector3.new(0,0,0); root.RotVelocity = Vector3.new(0,0,0) end
                if false and Config.RagdollAutoTP and wasAutoPlaying and not ragdollTPCooldown then
                    ragdollTPCooldown = true
                    local side = sharedSide or "L"
                    task.spawn(function()
                        task.wait(0.08)
                        local r = Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
                        if r then r.CFrame = CFrame.new(TP_SIDES[side].Step1) end
                        task.wait(0.2)
                        r = Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
                        local rs2 = side == "R" and Vector3.new(-484.67,-5.40,21.92) or Vector3.new(-484.86,-5.35,100.63)
                        if r then r.CFrame = CFrame.new(rs2 + Vector3.new(0,3,0)) end
                        task.wait(0.2); AutoPlayStartStep = 3
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

-- ============================================================
-- ESP
-- ============================================================
local function applyESPToChar(plr, char)
    if not char then return end
    local root = char:WaitForChild("HumanoidRootPart", 10)
    if not root or root:FindFirstChild("ESP_NameTag") then return end
    local bill = Instance.new("BillboardGui")
    bill.Name = "ESP_NameTag"; bill.AlwaysOnTop = true
    bill.Size = UDim2.new(0,80,0,18); bill.StudsOffset = Vector3.new(0,3,0)
    bill.Enabled = Config.ESPEnabled; bill.Parent = root
    local l = Instance.new("TextLabel", bill)
    l.Size = UDim2.new(1,0,1,0); l.BackgroundTransparency = 1
    l.Text = plr.DisplayName; l.TextColor3 = Color3.fromRGB(180,230,255)
    l.TextStrokeTransparency = 0; l.TextStrokeColor3 = Color3.fromRGB(0,0,0)
    l.Font = Enum.Font.GothamBold; l.TextSize = 11; l.TextScaled = false
end

local function setupESP(plr)
    if plr == Player then return end
    local line = Drawing.new("Line")
    line.Thickness = 2; line.Color = Color3.fromRGB(110, 200, 255)
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

RunService.RenderStepped:Connect(function()
    if not Config.ESPEnabled then return end
    for plr, line in pairs(ESPTracers) do
        if plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") then
            local pos, onScreen = Camera:WorldToViewportPoint(plr.Character.HumanoidRootPart.Position)
            line.Visible = onScreen
            if onScreen then
                line.From = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y)
                line.To   = Vector2.new(pos.X, pos.Y)
            end
        else line.Visible = false end
    end
end)

-- ============================================================
-- NOCLIP PLAYERS
-- ============================================================
RunService.Stepped:Connect(function()
    if not NoclipPlayersEnabled then return end
    local char = Player.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then return end
    for _, p in pairs(Players:GetPlayers()) do
        if p ~= Player and p.Character then
            local pRoot = p.Character:FindFirstChild("HumanoidRootPart")
            if pRoot and (root.Position - pRoot.Position).Magnitude <= 15 then
                for _, part in pairs(p.Character:GetDescendants()) do
                    if part:IsA("BasePart") then part.CanCollide = false end
                end
            end
        end
    end
end)

-- ============================================================
-- GRAB / PROXIMITY PROMPT
-- ============================================================
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
    local data = InternalCache[prompt]; if not data then return false end
    for _, fn in ipairs(data.holdCallbacks)    do task.spawn(fn) end
    task.wait(duration)
    for _, fn in ipairs(data.triggerCallbacks) do task.spawn(fn) end
    return true
end

local function removePromptCooldown(obj)
    if not obj:IsA("ProximityPrompt") or obj.ActionText ~= "Steal" then return end
    obj.Enabled = true
    obj:GetPropertyChangedSignal("Enabled"):Connect(function()
        if not obj.Enabled then obj.Enabled = true end
    end)
end

for _, v in pairs(workspace:GetDescendants()) do removePromptCooldown(v) end
workspace.DescendantAdded:Connect(removePromptCooldown)

local function rebuildPromptCache()
    PromptCache = {}
    for _, v in pairs(workspace:GetDescendants()) do
        if v:IsA("ProximityPrompt") then table.insert(PromptCache, v) end
    end
    PromptCacheTime = tick()
end

task.spawn(function()
    while true do
        task.wait(0.05)
        if not GrabActive or Interacting then continue end
        local char = Player.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        if not root then continue end
        if tick() - PromptCacheTime > CACHE_TTL then rebuildPromptCache() end
        local target, closest = nil, Config.GrabRange
        for _, v in pairs(PromptCache) do
            if v and v.Parent and v.Enabled and v.ActionText == "Steal" then
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
            PillFill.Size = UDim2.new(0,0,1,0); BarPctLbl.Text = "0"
            TweenService:Create(PillFill, TweenInfo.new(dur, Enum.EasingStyle.Linear), {Size = UDim2.new(1,0,1,0)}):Play()
            task.spawn(function()
                local elapsed = 0
                while elapsed < dur and Interacting do
                    elapsed = elapsed + task.wait(0.05)
                    BarPctLbl.Text = tostring(math.clamp(math.floor((elapsed/dur)*100),1,100))
                end
            end)
            if InternalCache[target] then executeSteal(target, dur)
            else task.wait(dur); fireproximityprompt(target) end
            task.wait(0.1)
            PillFill.Size = UDim2.new(0,0,1,0); BarPctLbl.Text = "0"
            Interacting = false; PromptCacheTime = 0
        end
    end
end)

-- ============================================================
-- SPEED BILLBOARD
-- ============================================================
local SpeedLabel = nil
local function setupSpeedBillboard(char)
    local root = char:WaitForChild("HumanoidRootPart", 10)
    if not root then return end
    local old = root:FindFirstChild("MySpeedBill"); if old then old:Destroy() end
    local bill = Instance.new("BillboardGui")
    bill.Name = "MySpeedBill"; bill.AlwaysOnTop = true
    bill.Size = UDim2.new(0,140,0,24); bill.StudsOffset = Vector3.new(0,3.8,0); bill.Parent = root
    local l = Instance.new("TextLabel", bill)
    l.Size = UDim2.new(1,0,1,0); l.BackgroundTransparency = 1
    l.TextColor3 = Color3.fromRGB(80,185,235); l.TextStrokeTransparency = 0
    l.TextStrokeColor3 = Color3.fromRGB(0,0,0)
    l.Font = Enum.Font.GothamBold; l.TextSize = 26; l.TextScaled = false
    l.TextXAlignment = Enum.TextXAlignment.Center; l.Text = "Speed: 0.00"
    SpeedLabel = l
end
if Player.Character then task.spawn(setupSpeedBillboard, Player.Character) end
Player.CharacterAdded:Connect(function(char) task.wait(0.5); setupSpeedBillboard(char) end)

-- ============================================================
-- AUTO PLAY LOOP
-- ============================================================
local function stopAutoPlay()
    AutoPlayEnabled = false; AutoPlayRunning = false; Config.AutoPlayState = false
    AutoPlayStartStep = 1
    ragdollTPToken = ragdollTPToken + 1
    if not AutoPlayRestarting and autoPlaySetState then autoPlaySetState(false) end
end

local function walkToPosition(root, targetPos, speed, arriveDistance)
    speed = speed or Config.CarrySpeed
    if type(arriveDistance) ~= "number" then arriveDistance = 1 end
    while AutoPlayEnabled do
        local flat = Vector3.new(targetPos.X - root.Position.X, 0, targetPos.Z - root.Position.Z)
        if flat.Magnitude <= arriveDistance then break end
        local dir = flat.Unit
        root.AssemblyLinearVelocity = Vector3.new(dir.X*speed, root.AssemblyLinearVelocity.Y, dir.Z*speed)
        RunService.Heartbeat:Wait()
    end
    root.AssemblyLinearVelocity = Vector3.new(0, root.AssemblyLinearVelocity.Y, 0)
end

task.spawn(function()
    while true do
        task.wait(0.05)
        if not AutoPlayEnabled or AutoPlayRunning then continue end
        AutoPlayRunning = true; wasAutoPlaying = true
        local char = Player.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        if not root then stopAutoPlay(); continue end
        local steps     = Config.AutoPlaySide == "R" and AutoPlayStepsR or AutoPlayStepsL
        local zone      = Config.StopOnLeft and ZoneDefs.Left or Config.StopOnRight and ZoneDefs.Right
        local startStep = AutoPlayStartStep; AutoPlayStartStep = 1

        if startStep == 1 then
            if not (zone and isInZone(root.Position, zone)) then
                if FastSpeedSetState then FastSpeedSetState(true) end
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
        wasAutoPlaying = false; stopAutoPlay()
    end
end)

-- ============================================================
-- MAIN HEARTBEAT
-- ============================================================
local lastClick = 0
RunService.Heartbeat:Connect(function()
    local char = Player.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    local hum  = char and char:FindFirstChildOfClass("Humanoid")
    if not root or not hum then return end

    if not AutoPlayEnabled and not AutoBatEnabled and hum.MoveDirection.Magnitude > 0 then
        local spd = FastSpeedEnabled and Config.FastSpeed or Config.CarrySpeed
        root.AssemblyLinearVelocity = Vector3.new(
            hum.MoveDirection.X * spd, root.AssemblyLinearVelocity.Y, hum.MoveDirection.Z * spd)
    end

    if Player:GetAttribute("Stealing") == true and hum.MoveDirection.Magnitude > 0 then
        root.AssemblyLinearVelocity = Vector3.new(
            hum.MoveDirection.X * Config.CarrySpeed, root.AssemblyLinearVelocity.Y, hum.MoveDirection.Z * Config.CarrySpeed)
    end

    if AutoBatEnabled then
        local target, dMin = nil, 1000
        for _, p in pairs(Players:GetPlayers()) do
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
            local tRoot  = target.Character.HumanoidRootPart
            local dest   = tRoot.Position + tRoot.CFrame.LookVector * Config.BatDist
            local diff   = dest - root.Position
            root.AssemblyAngularVelocity = root.CFrame.LookVector:Cross(tRoot.CFrame.LookVector) * 20
            local batVel = diff.Magnitude > 1 and diff.Unit * Config.AutoBatSpeed or tRoot.AssemblyLinearVelocity
            local yVel   = batVel.Y
            if Float2Enabled then
                local floatTarget = getGroundHeight(root.Position) + Config.Float2Height
                yVel = math.clamp((floatTarget - root.Position.Y) * Config.Float2Speed, -Config.Float2Speed, Config.Float2Speed)
            end
            root.AssemblyLinearVelocity = Vector3.new(batVel.X, yVel, batVel.Z)
            local tool = char:FindFirstChildOfClass("Tool")
            if tool and tool.Name:lower() == "bat" then
                tool.RequiresHandle = false
                if tick() - lastClick > 0.1 then
                    pcall(function() tool:Activate() end)
                    lastClick = tick()
                end
            end
        end
    end

    local jumpFiring     = Config.InfJumpEnabled and (UIS:IsKeyDown(Enum.KeyCode.Space) or MobileJumpHeld or MobileJumpActive)
    local jumpSuppressed = Config.InfJumpEnabled and (UIS:IsKeyDown(Enum.KeyCode.Space) or MobileJumpHeld)

    if jumpFiring and hum.Health > 0 then
        root.AssemblyLinearVelocity = Vector3.new(
            root.AssemblyLinearVelocity.X, math.random(42,48), root.AssemblyLinearVelocity.Z)
    end

    if Float2Enabled and not jumpSuppressed then
        Float2TargetY = getGroundHeight(root.Position) + Config.Float2Height
        local diff = Float2TargetY - root.Position.Y
        root.AssemblyLinearVelocity = Vector3.new(
            root.AssemblyLinearVelocity.X,
            math.clamp(diff * Config.Float2Speed, -Config.Float2Speed, Config.Float2Speed),
            root.AssemblyLinearVelocity.Z)
    elseif FloatEnabled and FloatTargetY and not jumpSuppressed and not BrainrotSequenceRunning then
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
        local TARGET_LOOK = Vector3.new(-0.999996305,0,0.00272039836)
        local cross       = root.CFrame.LookVector:Cross(TARGET_LOOK)
        root.AssemblyAngularVelocity = cross.Magnitude > 0.001
            and Vector3.new(0, cross.Y * 15, 0) or Vector3.new(0,0,0)
    end

    if SpeedLabel then
        local v = root.AssemblyLinearVelocity
        SpeedLabel.Text = string.format("Speed: %.2f", Vector3.new(v.X,0,v.Z).Magnitude)
    end
end)

-- ============================================================
-- NO ANIMATION
-- ============================================================
local noAnimConn, noAnimHbConn = nil, nil

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
            if noAnimHbConn then noAnimHbConn:Disconnect(); noAnimHbConn = nil end; return
        end
        if Player.Character then freezePose(Player.Character) end
    end)
end

-- ============================================================
-- FPS BOOST
-- ============================================================
local FPSBoostLocalConn, FPSBoostCharConn = nil, nil

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

-- ============================================================
-- ROW BUILDERS
-- ============================================================
local ROW_W  = 150
local ROW_H  = 26

local function FeatSectionHeader(text, order)
    local row = Instance.new("Frame", FeatPage)
    row.Size                   = UDim2.new(1, -4, 0, 16)
    row.BackgroundTransparency = 1
    row.BorderSizePixel        = 0
    row.LayoutOrder            = order
    local l = lbl(row, text, 8, T.textLo, Enum.Font.GothamBold)
    l.Size = UDim2.new(1, -4, 1, 0); l.Position = UDim2.new(0, 2, 0, 0)
end

local function FeatToggle(text, order, onToggle)
    local state = false
    local Frame = Instance.new("Frame", FeatPage)
    Frame.Size                   = UDim2.new(0, ROW_W, 0, ROW_H)
    Frame.BackgroundColor3       = T.bg1
    Frame.BackgroundTransparency = 0
    Frame.BorderSizePixel        = 0
    Frame.LayoutOrder            = order
    corner(Frame, 5)
    local TextLbl = lbl(Frame, text, 9, T.textMid, Enum.Font.GothamBold)
    TextLbl.Size     = UDim2.new(1, -46, 1, 0)
    TextLbl.Position = UDim2.new(0, 6, 0, 0)
    local Track = Instance.new("Frame", Frame)
    Track.Size             = UDim2.new(0, 34, 0, 18)
    Track.Position         = UDim2.new(1, -38, 0.5, -9)
    Track.BackgroundColor3 = T.trackBg
    Track.BorderSizePixel  = 0
    corner(Track, 9)
    local Dot = Instance.new("Frame", Track)
    Dot.Size             = UDim2.new(0, 12, 0, 12)
    Dot.Position         = UDim2.new(0, 3, 0.5, -6)
    Dot.BackgroundColor3 = T.dotOff
    Dot.BorderSizePixel  = 0
    corner(Dot, 7)
    local Btn = Instance.new("TextButton", Frame)
    Btn.Size                   = UDim2.new(1,0,1,0)
    Btn.BackgroundTransparency = 1
    Btn.BorderSizePixel        = 0
    Btn.Text                   = ""
    local function refresh()
        if state then tw(Dot, 0.22, { BackgroundColor3 = T.dotOn,  Position = UDim2.new(0,19,0.5,-6) })
        else           tw(Dot, 0.22, { BackgroundColor3 = T.dotOff, Position = UDim2.new(0,3, 0.5,-6) }) end
    end
    refresh()
    Btn.MouseButton1Click:Connect(function() state = not state; refresh(); onToggle(state) end)
    return Btn, function(s) state = s; refresh() end
end

local function FeatToggleWithSide(baseText, order, initialSide, onToggle, onSideSwap)
    local state = false
    local side  = initialSide or "L"
    local Frame = Instance.new("Frame", FeatPage)
    Frame.Size                   = UDim2.new(0, ROW_W, 0, ROW_H)
    Frame.BackgroundColor3       = T.bg1
    Frame.BackgroundTransparency = 0
    Frame.BorderSizePixel        = 0
    Frame.LayoutOrder            = order
    corner(Frame, 5)
    local TextLbl = lbl(Frame, baseText.." "..side, 9, T.textMid, Enum.Font.GothamBold)
    TextLbl.Size     = UDim2.new(1, -46, 1, 0)
    TextLbl.Position = UDim2.new(0, 6, 0, 0)
    local Track = Instance.new("Frame", Frame)
    Track.Size             = UDim2.new(0, 34, 0, 18)
    Track.Position         = UDim2.new(1, -38, 0.5, -9)
    Track.BackgroundColor3 = T.trackBg
    Track.BorderSizePixel  = 0
    corner(Track, 9)
    local Dot = Instance.new("Frame", Track)
    Dot.Size             = UDim2.new(0, 12, 0, 12)
    Dot.Position         = UDim2.new(0, 3, 0.5, -6)
    Dot.BackgroundColor3 = T.dotOff
    Dot.BorderSizePixel  = 0
    corner(Dot, 7)
    local Btn = Instance.new("TextButton", Frame)
    Btn.Size                   = UDim2.new(1,0,1,0)
    Btn.BackgroundTransparency = 1
    Btn.BorderSizePixel        = 0
    Btn.Text                   = ""
    local function refresh()
        TextLbl.Text = baseText.." "..side
        if state then tw(Dot, 0.22, { BackgroundColor3 = T.dotOn,  Position = UDim2.new(0,19,0.5,-6) })
        else           tw(Dot, 0.22, { BackgroundColor3 = T.dotOff, Position = UDim2.new(0,3, 0.5,-6) }) end
    end
    refresh()
    Btn.MouseButton1Click:Connect(function() state = not state; refresh(); onToggle(state, side) end)
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
    row.Size                   = UDim2.new(1, -4, 0, 16)
    row.BackgroundTransparency = 1
    row.BorderSizePixel        = 0
    row.LayoutOrder            = order
    local l = lbl(row, text, 8, T.textLo, Enum.Font.GothamBold)
    l.Size = UDim2.new(1,-4,1,0); l.Position = UDim2.new(0,2,0,0)
end

local function SetInputRow(text, configKey, order)
    local Frame = Instance.new("Frame", SetPage)
    Frame.Size                   = UDim2.new(0, ROW_W, 0, ROW_H)
    Frame.BackgroundColor3       = T.bg1
    Frame.BackgroundTransparency = 0
    Frame.BorderSizePixel        = 0
    Frame.LayoutOrder            = order
    corner(Frame, 5)
    local l = lbl(Frame, text, 9, T.textMid, Enum.Font.GothamBold)
    l.Size = UDim2.new(0.54,-4,1,0); l.Position = UDim2.new(0,6,0,0)
    local Input = Instance.new("TextBox", Frame)
    Input.Size                   = UDim2.new(0.42,0,0,18)
    Input.Position               = UDim2.new(0.56,0,0.5,-9)
    Input.BackgroundColor3       = T.bg3
    Input.BorderSizePixel        = 0
    Input.Text                   = tostring(Config[configKey])
    Input.TextColor3             = T.text
    Input.Font                   = Enum.Font.GothamBold
    Input.TextSize               = 9
    Input.TextScaled             = false
    Input.TextXAlignment         = Enum.TextXAlignment.Center
    corner(Input, 4)
    Input.Focused:Connect(function()   tw(Input, 0.12, {BackgroundColor3 = T.bg2}) end)
    Input.FocusLost:Connect(function()
        tw(Input, 0.12, {BackgroundColor3 = T.bg3})
        local n = tonumber(Input.Text)
        if n then Config[configKey] = n; SaveConfig() end
        Input.Text = tostring(Config[configKey])
    end)
end

local function SetKeybindRow(text, configKey, order)
    local Frame = Instance.new("Frame", SetPage)
    Frame.Size                   = UDim2.new(0, ROW_W, 0, ROW_H)
    Frame.BackgroundColor3       = T.bg1
    Frame.BackgroundTransparency = 0
    Frame.BorderSizePixel        = 0
    Frame.LayoutOrder            = order
    corner(Frame, 5)
    local l = lbl(Frame, text, 9, T.textMid, Enum.Font.GothamBold)
    l.Size = UDim2.new(0.54,-4,1,0); l.Position = UDim2.new(0,6,0,0)
    local BindBtn = Instance.new("TextButton", Frame)
    BindBtn.Size                   = UDim2.new(0.42,0,0,18)
    BindBtn.Position               = UDim2.new(0.56,0,0.5,-9)
    BindBtn.BackgroundColor3       = T.bg3
    BindBtn.BorderSizePixel        = 0
    BindBtn.Text                   = Config[configKey].Name
    BindBtn.TextColor3             = T.ice
    BindBtn.Font                   = Enum.Font.GothamBold
    BindBtn.TextSize               = 9
    BindBtn.TextScaled             = false
    BindBtn.TextXAlignment         = Enum.TextXAlignment.Center
    corner(BindBtn, 4)
    BindBtn.MouseButton1Click:Connect(function()
        BindBtn.Text = "..."; BindBtn.TextColor3 = T.textLo
        local conn
        conn = UIS.InputBegan:Connect(function(i, p)
            if not p and i.UserInputType == Enum.UserInputType.Keyboard then
                Config[configKey] = i.KeyCode
                BindBtn.Text = i.KeyCode.Name; BindBtn.TextColor3 = T.ice
                SaveConfig(); conn:Disconnect()
            end
        end)
    end)
end

local function SetToggleRow(text, order, onToggle, initState)
    local state = initState or false
    local Frame = Instance.new("Frame", SetPage)
    Frame.Size                   = UDim2.new(0, ROW_W, 0, ROW_H)
    Frame.BackgroundColor3       = T.bg1
    Frame.BackgroundTransparency = 0
    Frame.BorderSizePixel        = 0
    Frame.LayoutOrder            = order
    corner(Frame, 5)
    local TextLbl = lbl(Frame, text, 9, T.textMid, Enum.Font.GothamBold)
    TextLbl.Size     = UDim2.new(1,-46,1,0)
    TextLbl.Position = UDim2.new(0,6,0,0)
    local Track = Instance.new("Frame", Frame)
    Track.Size             = UDim2.new(0,34,0,18)
    Track.Position         = UDim2.new(1,-38,0.5,-9)
    Track.BackgroundColor3 = T.trackBg
    Track.BorderSizePixel  = 0
    corner(Track, 9)
    local Dot = Instance.new("Frame", Track)
    Dot.Size             = UDim2.new(0,12,0,12)
    Dot.Position         = UDim2.new(0,3,0.5,-6)
    Dot.BackgroundColor3 = T.dotOff
    Dot.BorderSizePixel  = 0
    corner(Dot, 7)
    local Btn = Instance.new("TextButton", Frame)
    Btn.Size = UDim2.new(1,0,1,0); Btn.BackgroundTransparency = 1
    Btn.BorderSizePixel = 0; Btn.Text = ""
    local function refresh()
        if state then tw(Dot, 0.22, {BackgroundColor3 = T.dotOn,  Position = UDim2.new(0,19,0.5,-6)})
        else           tw(Dot, 0.22, {BackgroundColor3 = T.dotOff, Position = UDim2.new(0,3, 0.5,-6)}) end
    end
    refresh()
    Btn.MouseButton1Click:Connect(function() state = not state; refresh(); onToggle(state) end)
    return function(s) state = s; refresh() end
end

-- Save button
do
    local Frame = Instance.new("Frame", SetPage)
    Frame.Size             = UDim2.new(0, ROW_W, 0, ROW_H)
    Frame.BackgroundColor3 = T.bg1
    Frame.BorderSizePixel  = 0
    Frame.LayoutOrder      = 0
    corner(Frame, 5)
    local SaveBtn = Instance.new("TextButton", Frame)
    SaveBtn.Size             = UDim2.new(1,-10,0,18)
    SaveBtn.Position         = UDim2.new(0,5,0.5,-9)
    SaveBtn.BackgroundColor3 = T.bg3
    SaveBtn.BorderSizePixel  = 0
    SaveBtn.Text             = "Save Config"
    SaveBtn.TextColor3       = T.textMid
    SaveBtn.Font             = Enum.Font.GothamBold
    SaveBtn.TextSize         = 9
    SaveBtn.TextScaled       = false
    corner(SaveBtn, 4)
    SaveBtn.MouseButton1Click:Connect(function()
        SaveConfig()
        SaveBtn.Text = "✓ Saved"; SaveBtn.TextColor3 = T.green
        task.wait(1.2)
        SaveBtn.Text = "Save Config"; SaveBtn.TextColor3 = T.textMid
    end)
end

-- ============================================================
-- FEATURES PAGE
-- ============================================================
FeatSectionHeader("SPEED / MOVEMENT", 1)

do
    local Frame = Instance.new("Frame", FeatPage)
    Frame.Size             = UDim2.new(0, ROW_W, 0, ROW_H)
    Frame.BackgroundColor3 = T.bg1
    Frame.BorderSizePixel  = 0
    Frame.LayoutOrder      = 2
    corner(Frame, 5)
    local statusLbl = lbl(Frame, "Status", 9, T.textMid, Enum.Font.GothamBold)
    statusLbl.Size = UDim2.new(0.5,-4,1,0); statusLbl.Position = UDim2.new(0,6,0,0)
    local valueLbl = lbl(Frame, "CARRY", 9, T.textLo, Enum.Font.GothamBold, Enum.TextXAlignment.Right)
    valueLbl.Size = UDim2.new(0.46,-4,1,0); valueLbl.Position = UDim2.new(0.54,0,0,0)
    FastSpeedSetState = function(s)
        FastSpeedEnabled = s; Config.FastSpeedState = s
        if s then valueLbl.Text = "FAST"; valueLbl.TextColor3 = T.text
        else      valueLbl.Text = "CARRY"; valueLbl.TextColor3 = T.textLo end
    end
    FastSpeedSetState(FastSpeedEnabled)
end

local _, autoBatSetState = FeatToggle("Auto Bat", 3, function(s)
    AutoBatEnabled = s; Config.AutoBatState = s
    if s then
        if Float2Enabled then
            AutoBat_Float2WasActive = true; handleFloat2Toggle(false, nil)
            if float2SetState then float2SetState(false) end
        else AutoBat_Float2WasActive = false end
        if FloatEnabled then
            AutoBat_Float2WasActive = true; BrainrotSequenceRunning = false
            FloatEnabled = false; FloatTargetY = nil; FloatActiveSpeed = nil
            FloatDescending = false; FloatDescendingStarted = false; Config.FloatState = false
            if dropBrainrotSetState then dropBrainrotSetState(false) end
        end
    else
        if AutoBat_Float2WasActive then
            AutoBat_Float2WasActive = false; handleFloat2Toggle(true, nil)
            if float2SetState then float2SetState(true) end
        end
    end
end)

local _, _apSetState, _apSetSide = FeatToggleWithSide("Auto Play", 4, sharedSide,
    function(s, side)
        AutoPlayEnabled = s; Config.AutoPlayState = s; Config.AutoPlaySide = side
        if not s then AutoPlayRunning = false; AutoPlayStartStep = 1; ragdollTPToken = ragdollTPToken + 1
        else
            if AutoBatEnabled then
                AutoBatEnabled = false; Config.AutoBatState = false
                if _batPopSetFn then _batPopSetFn(false) end
                if autoBatSetState then autoBatSetState(false) end
                if AutoBat_Float2WasActive then
                    AutoBat_Float2WasActive = false; handleFloat2Toggle(true, nil)
                    if float2SetState then float2SetState(true) end
                end
            end
            if ragdollOccurred and not ragdollTPCooldown and (tick()-lastRagdollTick < 3) then
                ragdollOccurred = false; ragdollTPCooldown = true
                local sd = sharedSide or "L"; local myToken = ragdollTPToken
                task.spawn(function()
                    task.wait(0.08)
                    local r = Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
                    if r then r.CFrame = CFrame.new(TP_SIDES[sd].Step1) end
                    task.wait(0.2)
                    r = Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
                    local rs2 = sd=="R" and Vector3.new(-484.67,-5.40,21.92) or Vector3.new(-484.86,-5.35,100.63)
                    if r then r.CFrame = CFrame.new(rs2+Vector3.new(0,3,0)) end
                    task.wait(0.15); AutoPlayStartStep = 3
task.wait(0.15)
                    if myToken ~= ragdollTPToken then ragdollTPCooldown = false; return end
                    AutoPlayStartStep = 3
                    AutoPlayEnabled = true; AutoPlayRunning = false
                    task.wait(2.5); ragdollTPCooldown = false
                end)
            end
        end
    end,
    function(side) switchSide(side) end
)
table.insert(_sideRowRefs, { setSide = _apSetSide, setState = _apSetState })
autoPlaySetState = _apSetState

local _, _ragTPSetState = FeatToggle("TP Ragdoll", 5, function(s) Config.RagdollAutoTP = s end)
ragdollTPSetState = _ragTPSetState

local _float2InMenuSet
_, _float2InMenuSet = FeatToggle("Float", 6, function(s)
    handleFloat2Toggle(s, nil)
    if float2SetState then float2SetState(s) end
end)

local _dropInMenuSet
_, _dropInMenuSet = FeatToggle("Drop", 7, function(s)
    handleBrainrotToggle(s, _dropInMenuSet)
end)

FeatSectionHeader("DYNAMICS", 8)

local _, noAnimSetState = FeatToggle("No Anim", 9, function(s)
    NoAnimEnabled = s; Config.NoAnimState = s; SaveConfig()
    if noAnimConn   then noAnimConn:Disconnect();   noAnimConn   = nil end
    if noAnimHbConn then noAnimHbConn:Disconnect(); noAnimHbConn = nil end
    if s then
        task.spawn(applyNoAnim, Player.Character)
        noAnimConn = Player.CharacterAdded:Connect(function(c) task.spawn(applyNoAnim, c) end)
    else
        local char = Player.Character
        local a = char and char:FindFirstChild("Animate"); if a then a.Disabled = false end
    end
end)

local _, fpsSetState = FeatToggle("FPS Boost", 10, function(s)
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

local _, espSetState = FeatToggle("ESP", 11, function(s)
    Config.ESPEnabled = s
    for plr in pairs(ESPTracers) do
        if plr.Character then
            local r = plr.Character:FindFirstChild("HumanoidRootPart")
            if r then local tag = r:FindFirstChild("ESP_NameTag"); if tag then tag.Enabled = s end end
        end
    end
    if not s then for _, line in pairs(ESPTracers) do line.Visible = false end end
end)

local _, ragdollSetState = FeatToggle("No Ragdoll", 12, function(s)
    Config.AntiRagdollEnabled = s
    if s then startAntiRagdoll() else stopAntiRagdoll() end
end)

local _, grabSetState = FeatToggle("Grab", 13, function(s)
    GrabActive = s; Config.GrabState = s
    if not s then Interacting = false; PillFill.Size = UDim2.new(0,0,1,0); BarPctLbl.Text = "0" end
end)

local _, infJumpSetState = FeatToggle("Inf Jump", 14, function(s)
    Config.InfJumpEnabled = s
    if not s then MobileJumpHeld = false end
end)

local _, noclipSetState = FeatToggle("Noclip", 15, function(s)
    NoclipPlayersEnabled = s; Config.NoclipPlayersState = s; SaveConfig()
end)

-- ============================================================
-- SETTINGS PAGE
-- ============================================================
SetSectionHeader("VALUES", 4)
SetInputRow("Speed",        "FastSpeed",    5)
SetInputRow("Carry Speed",  "CarrySpeed",   6)
SetInputRow("Float Height", "Float2Height", 7)
SetInputRow("Grab Speed",   "GrabSpeed",    8)
SetInputRow("Grab Range",   "GrabRange",    9)

SetSectionHeader("LAYOUT", 10)
SetToggleRow("Lock Positions", 11, function(s)
    Config.PositionsLocked = s; SaveConfig()
end, Config.PositionsLocked)

-- ============================================================
-- POPOUT BUILDER
-- ============================================================
local MIN_POP_W = 50
local MIN_POP_H = 24

local function makePopout(label, cfgX, cfgY, cfgW, cfgH, defaultX, defaultY)
    local initW = (Config[cfgW] and tonumber(Config[cfgW])) or 90
    local initH = (Config[cfgH] and tonumber(Config[cfgH])) or 30
    local initX = (Config[cfgX] and tonumber(Config[cfgX])) or defaultX
    local initY = (Config[cfgY] and tonumber(Config[cfgY])) or defaultY

    local Container = Instance.new("Frame", ScreenGui)
    Container.Size             = UDim2.new(0, initW, 0, initH)
    Container.Position         = UDim2.new(0, initX, 0, initY)
    Container.BackgroundColor3 = T.popOff
    Container.BorderSizePixel  = 0
    Container.Active           = true
    Container.ZIndex           = 10
    corner(Container, 7)

    local stroke = Instance.new("UIStroke", Container)
    stroke.Color = Color3.fromRGB(20, 45, 75); stroke.Thickness = 1

    local Btn = Instance.new("TextButton", Container)
    Btn.Size                   = UDim2.new(1, -8, 1, -4)
    Btn.Position               = UDim2.new(0, 4, 0, 2)
    Btn.BackgroundTransparency = 1
    Btn.BorderSizePixel        = 0
    Btn.Text                   = label
    Btn.TextColor3             = Color3.fromRGB(80, 140, 180)
    Btn.Font                   = Enum.Font.GothamBlack
    Btn.TextSize               = 10
    Btn.TextScaled             = false
    Btn.TextXAlignment         = Enum.TextXAlignment.Center
    Btn.TextYAlignment         = Enum.TextYAlignment.Center
    Btn.ZIndex                 = 11

    local RH = Instance.new("TextButton", Container)
    RH.Size             = UDim2.new(0, 10, 0, 10)
    RH.Position         = UDim2.new(1, -10, 1, -10)
    RH.BackgroundColor3 = Color3.fromRGB(14, 24, 38)
    RH.BorderSizePixel  = 0; RH.Text = ""; RH.ZIndex = 12
    corner(RH, 3)

    local isActive = false
    local function setState(v)
        isActive = v
        tw(Container, 0.16, { BackgroundColor3 = v and T.popOn or T.popOff })
        Btn.TextColor3 = v and Color3.fromRGB(130, 210, 255) or Color3.fromRGB(80, 140, 180)
    end

    local dragging     = false
    local dragStart    = nil
    local dragStartPos = nil
    local dragMoved    = false

    Btn.InputBegan:Connect(function(i)
        if Config.PositionsLocked then return end
        if i.UserInputType ~= Enum.UserInputType.Touch
        and i.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
        dragging     = true
        dragMoved    = false
        dragStart    = i.Position
        dragStartPos = Container.Position
    end)

    UIS.InputChanged:Connect(function(i)
        if not dragging then return end
        if Config.PositionsLocked then dragging = false; return end
        if i.UserInputType ~= Enum.UserInputType.Touch
        and i.UserInputType ~= Enum.UserInputType.MouseMovement then return end
        local delta = i.Position - dragStart
        if delta.Magnitude > 5 then dragMoved = true end
        if dragMoved then
            Container.Position = UDim2.new(
                0, dragStartPos.X.Offset + delta.X,
                0, dragStartPos.Y.Offset + delta.Y)
        end
    end)

    UIS.InputEnded:Connect(function(i)
        if not dragging then return end
        if i.UserInputType ~= Enum.UserInputType.Touch
        and i.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
        dragging = false
        if dragMoved then
            Config[cfgX] = Container.Position.X.Offset
            Config[cfgY] = Container.Position.Y.Offset
            SaveConfig()
        end
        task.defer(function() dragMoved = false end)
    end)

    local function getDragMoved() return dragMoved end

    local resizing    = false
    local resizeStart = nil
    local rsW, rsH    = initW, initH

    RH.InputBegan:Connect(function(i)
        if Config.PositionsLocked then return end
        if i.UserInputType ~= Enum.UserInputType.Touch
        and i.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
        resizing    = true
        resizeStart = i.Position
        rsW = Container.Size.X.Offset
        rsH = Container.Size.Y.Offset
        dragging = false; dragMoved = false
    end)

    UIS.InputChanged:Connect(function(i)
        if not resizing then return end
        if Config.PositionsLocked then resizing = false; return end
        if i.UserInputType ~= Enum.UserInputType.Touch
        and i.UserInputType ~= Enum.UserInputType.MouseMovement then return end
        local delta = i.Position - resizeStart
        Container.Size = UDim2.new(
            0, math.max(MIN_POP_W, rsW + delta.X),
            0, math.max(MIN_POP_H, rsH + delta.Y))
    end)

    UIS.InputEnded:Connect(function(i)
        if not resizing then return end
        if i.UserInputType ~= Enum.UserInputType.Touch
        and i.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
        resizing = false
        Config[cfgW] = Container.Size.X.Offset
        Config[cfgH] = Container.Size.Y.Offset
        SaveConfig()
    end)

    return Container, setState, Btn, getDragMoved
end

-- ============================================================
-- CREATE POPOUTS
-- ============================================================
local vp3    = Camera.ViewportSize
local centerX = math.floor(vp3.X/2) - 45
local centerY = math.floor(vp3.Y/2)

local _dropCont,  _dropPopSetFn,  _dropBtn,  _dropDragMoved  = makePopout("DROP",      "DropPopX",    "DropPopY",    "DropPopW",    "DropPopH",    centerX, centerY - 60)
local _apCont,    _apPopSetFn,    _apBtn,    _apDragMoved    = makePopout("AUTO PLAY", "AutoPlayPopX","AutoPlayPopY","AutoPlayPopW","AutoPlayPopH",centerX, centerY - 24)
local _batCont,   _batPopSetFn,   _batBtn,   _batDragMoved   = makePopout("AUTO BAT",  "AutoBatPopX", "AutoBatPopY", "AutoBatPopW", "AutoBatPopH", centerX, centerY + 12)
local _floatCont, _floatPopSetFn, _floatBtn, _floatDragMoved = makePopout("FLOAT",     "FloatPopX",   "FloatPopY",   "FloatPopW",   "FloatPopH",   centerX, centerY + 48)

-- Wire DROP
dropBrainrotSetState = function(s)
    _dropPopSetFn(s)
    if _dropInMenuSet then _dropInMenuSet(s) end
end
_dropBtn.MouseButton1Click:Connect(function()
    if _dropDragMoved() then return end
    local newState = not (_dropCont.BackgroundColor3 == T.popOn)
    dropBrainrotSetState(newState)
    handleBrainrotToggle(newState, dropBrainrotSetState)
end)

-- Wire AUTO PLAY
autoPlaySetState = function(s)
    _apPopSetFn(s)
    if _apSetState then _apSetState(s) end
end
_apBtn.MouseButton1Click:Connect(function()
    if _apDragMoved() then return end
    AutoPlayEnabled = not AutoPlayEnabled
    Config.AutoPlayState = AutoPlayEnabled; Config.AutoPlaySide = sharedSide
    if not AutoPlayEnabled then AutoPlayRunning = false; AutoPlayStartStep = 1; ragdollTPToken = ragdollTPToken + 1
    else
        if AutoBatEnabled then
            AutoBatEnabled = false; Config.AutoBatState = false
            if _batPopSetFn then _batPopSetFn(false) end
            if autoBatSetState then autoBatSetState(false) end
            if AutoBat_Float2WasActive then
                AutoBat_Float2WasActive = false; handleFloat2Toggle(true, nil)
                if float2SetState then float2SetState(true) end
            end
        end
        if ragdollOccurred and not ragdollTPCooldown then
            ragdollOccurred = false; ragdollTPCooldown = true
            local sd = sharedSide or "L"; local myToken = ragdollTPToken
            task.spawn(function()
                task.wait(0.08)
                local r = Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
                if r then r.CFrame = CFrame.new(TP_SIDES[sd].Step1) end
                task.wait(0.2)
                r = Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
                local rs2 = sd=="R" and Vector3.new(-484.67,-5.40,21.92) or Vector3.new(-484.86,-5.35,100.63)
                if r then r.CFrame = CFrame.new(rs2+Vector3.new(0,3,0)) end
                task.wait(0.15)
                if myToken ~= ragdollTPToken then ragdollTPCooldown = false; return end
                AutoPlayStartStep = 3
                AutoPlayRunning = false
                task.wait(2.5); ragdollTPCooldown = false
            end)
        end
    end
    autoPlaySetState(AutoPlayEnabled)
end)
table.insert(_sideRowRefs, { setSide = function(side) sharedSide = side end, setState = _apPopSetFn })

-- Wire AUTO BAT
_batBtn.MouseButton1Click:Connect(function()
    if _batDragMoved() then return end
    AutoBatEnabled = not AutoBatEnabled; Config.AutoBatState = AutoBatEnabled
    _batPopSetFn(AutoBatEnabled); autoBatSetState(AutoBatEnabled)
    if AutoBatEnabled then
        if Float2Enabled then
            AutoBat_Float2WasActive = true; handleFloat2Toggle(false, nil)
            if float2SetState then float2SetState(false) end
        else AutoBat_Float2WasActive = false end
    else
        if AutoBat_Float2WasActive then
            AutoBat_Float2WasActive = false; handleFloat2Toggle(true, nil)
            if float2SetState then float2SetState(true) end
        end
    end
end)

-- Wire FLOAT
float2SetState = function(s)
    _floatPopSetFn(s)
    if _float2InMenuSet then _float2InMenuSet(s) end
end
_floatBtn.MouseButton1Click:Connect(function()
    if _floatDragMoved() then return end
    local newState = not Float2Enabled
    handleFloat2Toggle(newState, nil)
    float2SetState(newState)
    SaveConfig()
end)

-- ============================================================
-- APPLY LOADED CONFIG
-- ============================================================
do
    Config.BatDist = 0; Config.Step2Delay = 0.05; Config.FloatHeight = 18
    Config.FloatSpeed = 85; Config.Float2Speed = 45; Config.AutoBatSpeed = 58

    if Config.FastSpeedState     then FastSpeedSetState(true)                                          end
    if Config.AutoBatState       then AutoBatEnabled = true; autoBatSetState(true); _batPopSetFn(true) end
    if Config.GrabState          then GrabActive = true; grabSetState(true)                            end
    if Config.AntiRagdollEnabled then ragdollSetState(true); startAntiRagdoll()                        end
    if Config.RagdollAutoTP      then if ragdollTPSetState then ragdollTPSetState(true) end             end
    if Config.NoclipPlayersState then NoclipPlayersEnabled = true; noclipSetState(true)                end
    if Config.InfJumpEnabled     then infJumpSetState(true)                                            end
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
        handleFloat2Toggle(true, nil)
        if float2SetState then float2SetState(true) end
    end
    if Config.FpsBoostState then
        fpsSetState(true)
        task.spawn(function()
            task.wait(1); if not Config.FpsBoostState then return end
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
    if Config.AutoPlayState then
        AutoPlayEnabled = true
        if autoPlaySetState then autoPlaySetState(true) end
    end
    if _apSetSide then _apSetSide(Config.AutoPlaySide or "L") end

    local showPop = Config.ShowPopouts ~= false
    _dropCont.Visible  = showPop
    _apCont.Visible    = showPop
    _batCont.Visible   = showPop
    _floatCont.Visible = showPop
end

-- ============================================================
-- KEYBINDS
-- ============================================================
UIS.InputBegan:Connect(function(i, p)
    if p then return end

    if i.KeyCode == Enum.KeyCode.Space and Config.InfJumpEnabled then
        local char = Player.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        local hum  = char and char:FindFirstChildOfClass("Humanoid")
        if root and hum and hum.Health > 0 then
            root.AssemblyLinearVelocity = Vector3.new(
                root.AssemblyLinearVelocity.X, math.random(42,48), root.AssemblyLinearVelocity.Z)
        end
    end

    if i.KeyCode == Config.FastSpeedKey then
        if FastSpeedSetState then FastSpeedSetState(not FastSpeedEnabled) end

    elseif i.KeyCode == Config.AutoBatKey then
        AutoBatEnabled = not AutoBatEnabled; Config.AutoBatState = AutoBatEnabled
        _batPopSetFn(AutoBatEnabled); autoBatSetState(AutoBatEnabled)
        if AutoBatEnabled then
            if Float2Enabled then
                AutoBat_Float2WasActive = true; handleFloat2Toggle(false, nil)
                if float2SetState then float2SetState(false) end
            else AutoBat_Float2WasActive = false end
            if FloatEnabled then
                AutoBat_Float2WasActive = true; BrainrotSequenceRunning = false
                FloatEnabled = false; FloatTargetY = nil; FloatActiveSpeed = nil
                FloatDescending = false; FloatDescendingStarted = false; Config.FloatState = false
                if dropBrainrotSetState then dropBrainrotSetState(false) end
            end
        else
            if AutoBat_Float2WasActive then
                AutoBat_Float2WasActive = false; handleFloat2Toggle(true, nil)
                if float2SetState then float2SetState(true) end
            end
        end

    elseif i.KeyCode == Config.AutoTPKey then
        local side = AutoTPREnabled and "R" or AutoTPLEnabled and "L"
                  or Config.AutoTPRState and "R" or Config.AutoTPLState and "L"
        if side then doAutoTP(side) end

    elseif i.KeyCode == Config.FloatKey then
        local s = not FloatEnabled
        if _dropInMenuSet then _dropInMenuSet(s) end
        handleBrainrotToggle(s, dropBrainrotSetState)

    elseif i.KeyCode == Config.Float2Key then
        local s = not Float2Enabled
        handleFloat2Toggle(s, nil)
        if float2SetState then float2SetState(s) end
        SaveConfig()

    elseif i.KeyCode == Config.AutoPlayKey then
        AutoPlayEnabled = not AutoPlayEnabled; Config.AutoPlayState = AutoPlayEnabled
        if not AutoPlayEnabled then AutoPlayRunning = false; AutoPlayStartStep = 1; ragdollTPToken = ragdollTPToken + 1
        else
            tryPendingRagdollTP()
            if ragdollOccurred and not ragdollTPCooldown and (tick()-lastRagdollTick < 3) then
                ragdollOccurred = false; ragdollTPCooldown = true
                local sd = sharedSide or "L"; local myToken = ragdollTPToken
                task.spawn(function()
                    AutoPlayEnabled = false; AutoPlayRunning = false
                    if autoPlaySetState then autoPlaySetState(false) end
                    task.wait(0.08)
                    local r = Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
                    if r then r.CFrame = CFrame.new(TP_SIDES[sd].Step1) end
                    task.wait(0.2)
                    r = Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
                    local rs2 = sd=="R" and Vector3.new(-484.67,-5.40,21.92) or Vector3.new(-484.86,-5.35,100.63)
                    if r then r.CFrame = CFrame.new(rs2+Vector3.new(0,3,0)) end
                    task.wait(0.15)
                    if myToken ~= ragdollTPToken then ragdollTPCooldown = false; return end
                    AutoPlayStartStep = 3
                    AutoPlayEnabled = true; AutoPlayRunning = false
                    if autoPlaySetState then autoPlaySetState(true) end
                    task.wait(2.5); ragdollTPCooldown = false
                end)
            end
        end
        if AutoPlayEnabled and AutoBatEnabled then
            AutoBatEnabled = false; Config.AutoBatState = false
            if _batPopSetFn then _batPopSetFn(false) end
            if autoBatSetState then autoBatSetState(false) end
            if AutoBat_Float2WasActive then
                AutoBat_Float2WasActive = false; handleFloat2Toggle(true, nil)
                if float2SetState then float2SetState(true) end
            end
        end
        if autoPlaySetState then autoPlaySetState(AutoPlayEnabled) end
    end
end)