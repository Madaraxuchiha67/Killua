local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

repeat task.wait() until Players.LocalPlayer

local player = Players.LocalPlayer
local success, result = pcall(function()
    return player:GetMouse()
end)

local mouse = success and result or nil

-- ============================================================
--  OBSIDIAN UI (deividcomsono/Obsidian)
--  A small helper layer below maps Tabs.X:AddToggle / AddSlider /
--  AddDropdown ... onto Obsidian groupboxes.
-- ============================================================
local repo         = "https://raw.githubusercontent.com/deividcomsono/Obsidian/main/"
local Library      = loadstring(game:HttpGet(repo .. "Library.lua"))()
local ThemeManager = loadstring(game:HttpGet(repo .. "addons/ThemeManager.lua"))()
local SaveManager  = loadstring(game:HttpGet(repo .. "addons/SaveManager.lua"))()

local ObsidianWindow = Library:CreateWindow({
    Title = "Aotr:update5",
    Footer = "Attack on Titan: Revolution",
    NotifySide = "Right",
    ShowCustomCursor = false,
    Size = UDim2.fromOffset(640, 480),
    Center = true,
    AutoShow = true,
})

local Notifier = {}
function Notifier:Notify(o)
    pcall(function()
        Library:Notify({
            Title = o.Title or "",
            Description = o.Content or "",
            Time = o.Duration or 4,
        })
    end)
end

-- Tab wrapper -> Obsidian tab. Each AddSection() starts a new groupbox,
-- alternating left/right. Controls added before any section go in a groupbox
-- named after the tab.
local function MakeTab(rawTab, title)
    local tab = { _tab = rawTab, _count = 0, _box = nil }

    local function newBox(name)
        tab._count += 1
        if tab._count % 2 == 1 then
            tab._box = rawTab:AddLeftGroupbox(name)
        else
            tab._box = rawTab:AddRightGroupbox(name)
        end
        return tab._box
    end
    local function box() return tab._box or newBox(title) end
    local function note(o)
        if o.Description and o.Description ~= "" then box():AddLabel(o.Description, true) end
    end

    function tab:AddSection(name) newBox(name) end

    function tab:AddToggle(idx, o)
        local t = box():AddToggle(idx, { Text = o.Title, Default = o.Default or false, Callback = o.Callback })
        note(o)
        return t
    end

    function tab:AddSlider(idx, o)
        local s = box():AddSlider(idx, {
            Text = o.Title, Default = o.Default, Min = o.Min, Max = o.Max,
            Rounding = o.Rounding or 0, Callback = o.Callback,
        })
        note(o)
        return s
    end

    function tab:AddDropdown(idx, o)
        local multi = o.Multi == true
        local info = { Text = o.Title, Values = o.Values or {}, Multi = multi, Callback = o.Callback }
        if not multi then info.Default = o.Default end
        local dd = box():AddDropdown(idx, info)
        if multi and type(o.Default) == "table" then
            local map = {}
            for k, v in pairs(o.Default) do
                if type(k) == "number" then map[v] = true elseif v then map[k] = true end
            end
            if next(map) then pcall(function() dd:SetValue(map) end) end
        end
        note(o)
        return dd
    end

    function tab:AddInput(idx, o)
        return box():AddInput(idx, {
            Text = o.Title, Default = o.Default or "", Placeholder = o.Placeholder or "",
            Numeric = o.Numeric or false, Finished = o.Finished or false, Callback = o.Callback,
        })
    end

    function tab:AddButton(o)
        local b = box():AddButton({ Text = o.Title, Func = o.Callback })
        note(o)
        return b
    end

    function tab:AddColorpicker(idx, o)
        local lbl = box():AddLabel(o.Title or "Color")
        local picker = lbl:AddColorPicker(idx, { Default = o.Default or Color3.new(1, 1, 1), Title = o.Title })
        local wrap = { _p = picker }
        function wrap:OnChanged(fn)
            pcall(function() picker:OnChanged(fn) end)
        end
        function wrap:SetValueRGB(c)
            local ok = pcall(function() picker:SetValueRGB(c) end)
            if not ok then
                pcall(function() picker:SetValue({ Color3.toHSV(c) }) end)
            end
        end
        return wrap
    end

    -- Paragraph -> wrapped label (keeps :SetDesc / .DescLabel for the Account tab).
    function tab:AddParagraph(o)
        local ttl, content = o.Title or "", o.Content or ""
        local function render(c)
            if ttl == "" then return c end
            if c:find("\n") or #c > 40 then return ttl .. "\n" .. c end
            return ttl .. ": " .. c
        end
        local lbl = box():AddLabel(render(content), true)
        local p = { DescLabel = lbl and lbl.TextLabel }
        function p:SetDesc(c) pcall(function() lbl:SetText(render(tostring(c))) end) end
        function p:SetTitle(t) ttl = t end
        return p
    end

    return tab
end

local Window = {}
Window.Root = setmetatable({}, {
    __index = function(_, k) if k == "Visible" then return Library.Toggled end end,
    __newindex = function(_, k, v)
        if k == "Visible" and Library.Toggled ~= v then pcall(function() Library:Toggle() end) end
    end,
})
function Window:AddTab(o)
    local raw
    local icon = (o.Icon and o.Icon ~= "") and o.Icon or nil
    local ok = pcall(function() raw = ObsidianWindow:AddTab(o.Title, icon) end)
    if not ok or not raw then raw = ObsidianWindow:AddTab(o.Title) end
    return MakeTab(raw, o.Title)
end
function Window:Minimize(force)
    pcall(function()
        if force == true then
            if Library.Toggled then Library:Toggle() end
        else
            Library:Toggle()
        end
    end)
end
function Window:SelectTab(tab) pcall(function() tab._tab:Show() end) end

local TrayIcon = {}
TrayIcon.isVisible = true
TrayIcon.connection = nil

function TrayIcon:CreateIcon()
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "TrayIconGui"
    screenGui.ResetOnSpawn = false
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.Parent = game:GetService("CoreGui")

    local iconFrame = Instance.new("Frame")
    iconFrame.Name = "TrayIcon"
    iconFrame.Size = UDim2.new(0, 50, 0, 50)
    iconFrame.Position = UDim2.new(1, -60, 0, 10)
    iconFrame.BackgroundColor3 = Color3.fromRGB(0, 120, 212)
    iconFrame.BorderSizePixel = 0
    iconFrame.Parent = screenGui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0.5, 0)
    corner.Parent = iconFrame

    local iconText = Instance.new("TextLabel")
    iconText.Size = UDim2.new(1, 0, 1, 0)
    iconText.Position = UDim2.new(0, 0, 0, 0)
    iconText.BackgroundTransparency = 1
    iconText.Text = "A"
    iconText.TextColor3 = Color3.fromRGB(255, 255, 255)
    iconText.TextScaled = true
    iconText.Font = Enum.Font.GothamBold
    iconText.Parent = iconFrame

    local hoverTween = nil
    iconFrame.MouseEnter:Connect(function()
        if hoverTween then hoverTween:Cancel() end
        hoverTween = TweenService:Create(iconFrame,
            TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            {Size = UDim2.new(0, 55, 0, 55), BackgroundColor3 = Color3.fromRGB(16, 110, 190)}
        )
        hoverTween:Play()
    end)

    iconFrame.MouseLeave:Connect(function()
        if hoverTween then hoverTween:Cancel() end
        hoverTween = TweenService:Create(iconFrame,
            TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            {Size = UDim2.new(0, 50, 0, 50), BackgroundColor3 = Color3.fromRGB(0, 120, 212)}
        )
        hoverTween:Play()
    end)

    local clickDetector = Instance.new("TextButton")
    clickDetector.Size = UDim2.new(1, 0, 1, 0)
    clickDetector.Position = UDim2.new(0, 0, 0, 0)
    clickDetector.BackgroundTransparency = 1
    clickDetector.Text = ""
    clickDetector.Parent = iconFrame

    clickDetector.MouseButton1Click:Connect(function()
        self:ToggleUI()
        local clickTween = TweenService:Create(iconFrame,
            TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut),
            {Size = UDim2.new(0, 45, 0, 45)}
        )
        clickTween:Play()
        clickTween.Completed:Connect(function()
            local returnTween = TweenService:Create(iconFrame,
                TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut),
                {Size = UDim2.new(0, 50, 0, 50)}
            )
            returnTween:Play()
        end)
    end)

    self.gui = screenGui
    self.frame = iconFrame
    self.text = iconText
    self:CreateTooltip()
end

function TrayIcon:CreateTooltip()
    local tooltip = Instance.new("Frame")
    tooltip.Name = "Tooltip"
    tooltip.Size = UDim2.new(0, 200, 0, 30)
    tooltip.Position = UDim2.new(1, -210, 0.5, -15)
    tooltip.BackgroundColor3 = Color3.fromRGB(32, 32, 32)
    tooltip.BorderSizePixel = 0
    tooltip.Visible = false
    tooltip.Parent = self.frame

    local tooltipCorner = Instance.new("UICorner")
    tooltipCorner.CornerRadius = UDim.new(0, 5)
    tooltipCorner.Parent = tooltip

    local tooltipText = Instance.new("TextLabel")
    tooltipText.Size = UDim2.new(1, -10, 1, 0)
    tooltipText.Position = UDim2.new(0, 5, 0, 0)
    tooltipText.BackgroundTransparency = 1
    tooltipText.Text = "Click to toggle UI visibility"
    tooltipText.TextColor3 = Color3.fromRGB(255, 255, 255)
    tooltipText.TextScaled = true
    tooltipText.Font = Enum.Font.Gotham
    tooltipText.Parent = tooltip

    self.frame.MouseEnter:Connect(function() tooltip.Visible = true end)
    self.frame.MouseLeave:Connect(function() tooltip.Visible = false end)
end

function TrayIcon:ToggleUI()
    if self.isVisible then self:HideUI() else self:ShowUI() end
end

function TrayIcon:HideUI()
    if Window and Window.Root then
        Window.Root.Visible = false
        self.isVisible = false
        self.text.Text = "H"
        self.frame.BackgroundColor3 = Color3.fromRGB(220, 53, 69)
        Notifier:Notify({ Title = "UI Hidden", Content = "Click the tray icon to show UI again", Duration = 3 })
    end
end

function TrayIcon:ShowUI()
    if Window and Window.Root then
        Window.Root.Visible = true
        self.isVisible = true
        self.text.Text = "A"
        self.frame.BackgroundColor3 = Color3.fromRGB(0, 120, 212)
        Notifier:Notify({ Title = "UI Shown", Content = "UI is now visible", Duration = 2 })
    end
end

TrayIcon:CreateIcon()

--//==============================\\--
--||         TABS SETUP           ||--
--\\==============================//--

local EarlyAccountTab = Window:AddTab({ Title = "Account", Icon = "user" })

local Tabs = {
    Main          = Window:AddTab({ Title = "Main(Risky)",               Icon = "swords" }),
    AutoJoin      = Window:AddTab({ Title = "Auto Join",                 Icon = "door-open" }),
    Servers       = Window:AddTab({ Title = "Servers",                   Icon = "server" }),
    Misc          = Window:AddTab({ Title = "Misc",                      Icon = "wrench" }),
    Extras        = Window:AddTab({ Title = "Extras",                    Icon = "sparkles" }),
    Esp           = Window:AddTab({ Title = "Titans Esp",                Icon = "eye" }),
    Webhook       = Window:AddTab({ Title = "Webhook",                   Icon = "webhook" }),
    Settings      = Window:AddTab({ Title = "Settings",                  Icon = "settings" }),
}

--//==============================\\--
--||         SETTINGS TAB         ||--
--\\==============================//--

Tabs.Settings:AddToggle("TrayIconToggle", {
    Title = "Show Tray Icon",
    Description = "Show/Hide the system tray icon",
    Default = true,
    Callback = function(state)
        if TrayIcon.gui then TrayIcon.gui.Enabled = state end
    end
})

Tabs.Settings:AddParagraph({
    Title = "Tray Icon Usage",
    Content = "• The tray icon appears in the top-right corner\n• Click it to hide/show the UI\n• Red icon = UI hidden, Blue icon = UI visible\n• Ctrl+H (keyboard) or double-tap the screen (mobile) also toggles the UI"
})

--//==============================\\--
--||       MAINMENU (PlaceId)     ||--
--\\==============================//--

local allowedPlaceId = 13379208636
if game.PlaceId == allowedPlaceId then
    Tabs.Mainmenu = Window:AddTab({ Title = "Mainmenu", Icon = "house" })
    Tabs.Mainmenu:AddToggle("AutoRollToggle", {
        Title = "Auto Roll",
        Default = false,
        Callback = function(state) ENABLED = state end
    })
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Enum.KeyCode.H and UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
        TrayIcon:ToggleUI()
    end
end)

game.Players.PlayerRemoving:Connect(function(plr)
    if plr == player and TrayIcon.gui then TrayIcon.gui:Destroy() end
end)

--------------------------------------------------------------------------

local HttpService     = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VirtualInput    = game:GetService("VirtualInputManager")
local GuiService      = game:GetService("GuiService")
local TeleportService = game:GetService("TeleportService")

local char = player.Character or player.CharacterAdded:Wait()
local hrp  = char:WaitForChild("HumanoidRootPart")

local retryRemote = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Remotes"):WaitForChild("GET")

local isFlying   = false
local bodyPos
local LocalPlayer = Players.LocalPlayer
local startDelay  = 0
local flyHeight   = 250

--//==============================\\--
--||      👑 AUTO KILL TITANS     ||--
--\\==============================//--

local Services = {
    Players         = game:GetService("Players"),
    RunService      = game:GetService("RunService"),
    ReplicatedStorage = game:GetService("ReplicatedStorage"),
    TweenService    = game:GetService("TweenService"),
    CoreGui         = game:GetService("CoreGui")
}

local Player = {
    self      = Services.Players.LocalPlayer,
    character = nil,
    hrp       = nil,
    gui       = nil
}

local Config = {
    flySpeed              = 250,
    canHit                = true,
    isFlying              = false,
    moveMode              = "Teleportation",
    notificationsEnabled  = true,
    startDelay            = 0,
    flyHeight             = 250,
    titanKillCount        = 0,
    autoRefill            = false,
    lastBladesEmpty       = false,
    lastSpearsEmpty       = false
}

local Data = {
    notified    = {},
    activeNotifs = {},
    POST        = nil,
    refill      = nil
}

Player.character = Player.self.Character or Player.self.CharacterAdded:Wait()
Player.hrp       = Player.character:WaitForChild("HumanoidRootPart")
Player.gui       = Player.self:WaitForChild("PlayerGui")

task.spawn(function()
    local success2, result2 = pcall(function()
        return Services.ReplicatedStorage:WaitForChild("Assets", 10):WaitForChild("Remotes", 10):WaitForChild("POST", 10)
    end)
    Data.POST = success2 and result2 or nil
end)

function showKillNotification(count)
    if not Config.notificationsEnabled then return end
    local gui = Instance.new("ScreenGui")
    gui.Name = "TN_" .. tick()
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true
    gui.Parent = Services.CoreGui
    local frame = Instance.new("Frame", gui)
    frame.Size = UDim2.new(0, 190, 0, 75)
    frame.Position = UDim2.new(1, 20, 0, 10 + (#Data.activeNotifs * 80))
    frame.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
    frame.BorderSizePixel = 2
    frame.BorderColor3 = Color3.fromRGB(184, 164, 101)
    local label = Instance.new("TextLabel", frame)
    label.Size = UDim2.new(0.65, 0, 1, 0)
    label.Position = UDim2.new(0, 5, 0, 0)
    label.BackgroundTransparency = 1
    label.Text = "Successfully\nHit:"
    label.TextColor3 = Color3.fromRGB(184, 164, 101)
    label.Font = Enum.Font.Fantasy
    label.TextScaled = true
    local counter = Instance.new("TextLabel", frame)
    counter.Size = UDim2.new(0, 60, 0.5, 0)
    counter.Position = UDim2.new(1, -65, 0, 0)
    counter.BackgroundTransparency = 1
    counter.Text = tostring(count)
    counter.TextColor3 = Color3.fromRGB(255, 255, 255)
    counter.Font = Enum.Font.Fantasy
    counter.TextScaled = true
    table.insert(Data.activeNotifs, gui)
    Services.TweenService:Create(frame, TweenInfo.new(0.35), {
        Position = UDim2.new(1, -210, 0, 10 + ((#Data.activeNotifs - 1) * 80))
    }):Play()
    task.delay(5, function()
        gui:Destroy()
        for i, v in ipairs(Data.activeNotifs) do
            if v == gui then table.remove(Data.activeNotifs, i) break end
        end
    end)
end

local TITAN_PRIORITY = { "Attack_Titan", "Female_Titan", "Armored_Titan" }

local function napeOf(titan)
    local hb = titan:FindFirstChild("Hitboxes")
    local hit = hb and hb:FindFirstChild("Hit")
    return hit and hit:FindFirstChild("Nape")
end

local function isAlive(titan)
    local h = titan:FindFirstChildWhichIsA("Humanoid")
    return h and h.Health > 0
end

-- keep the character reference fresh after respawn (the old code kept a dead HRP)
Player.self.CharacterAdded:Connect(function(c)
    Player.character = c
    Player.hrp = c:WaitForChild("HumanoidRootPart")
end)

local targetList, lastScan = {}, 0

local function scanTargets()
    table.clear(targetList)
    local folder = workspace:FindFirstChild("Titans")
    if not folder or not Player.hrp then return end
    local pos = Player.hrp.Position
    for _, name in ipairs(TITAN_PRIORITY) do
        local t = folder:FindFirstChild(name)
        if t and isAlive(t) then
            local n = napeOf(t)
            if n then targetList[#targetList + 1] = n end
        end
    end
    local others = {}
    for _, t in ipairs(folder:GetChildren()) do
        if not table.find(TITAN_PRIORITY, t.Name) and isAlive(t) then
            local n = napeOf(t)
            if n then others[#others + 1] = { n, (pos - n.Position).Magnitude } end
        end
    end
    table.sort(others, function(a, b) return a[2] < b[2] end)
    for _, o in ipairs(others) do targetList[#targetList + 1] = o[1] end
end

-- target list is rebuilt at most 10x/second instead of every frame
function getClosestValidNape()
    local first = targetList[1]
    if os.clock() - lastScan > 0.1 or not first or not first.Parent then
        scanTargets()
        lastScan = os.clock()
    end
    return targetList[1]
end

Config.hitCooldown = 0.12   -- seconds between hit bursts (was 0.25)
Config.multiHit    = 8      -- napes hit per burst (was 3)
Config.hitAll      = false  -- true = every alive titan gets hit in the same burst

local killConnection
local killStartAt = 0

function killFromAbove()
    killStartAt = os.clock() + Config.startDelay
    if killConnection then return end -- one connection only (old code stacked a new one on every toggle)
    killConnection = Services.RunService.Heartbeat:Connect(function()
        if not Config.isFlying or Config.missionDone or os.clock() < killStartAt then return end
        local hrp = Player.hrp
        if not hrp or not hrp.Parent then return end
        local nape = getClosestValidNape()
        if not nape then return end
        local targetPos = nape.Position + Vector3.new(0, Config.flyHeight, 0)
        if Config.moveMode == "Gliding" then
            local delta = targetPos - hrp.Position
            if delta.Magnitude > 1 then hrp.AssemblyLinearVelocity = delta.Unit * Config.flySpeed end
        else
            hrp.CFrame = CFrame.new(targetPos)
        end
        if Config.canHit and (hrp.Position - nape.Position).Magnitude <= 1520 then
            Config.canHit = false
            task.spawn(function()
                local post = Data.POST
                local count = Config.hitAll and #targetList or math.min(Config.multiHit, #targetList)
                for i = 1, count do
                    local n = targetList[i]
                    if n and n.Parent then
                        if post then
                            post:FireServer("Hitboxes", "Register", n, math.random(200, 300), math.random(20, 30) / 100)
                            post:FireServer("Attacks", "Slash", true)
                        end
                        local id = tostring(n:GetDebugId())
                        if not Data.notified[id] then
                            Data.notified[id] = true
                            Config.titanKillCount = Config.titanKillCount + 1
                            showKillNotification(Config.titanKillCount)
                        end
                    end
                end
                if Config.onKillBurst then task.spawn(Config.onKillBurst) end
                task.wait(Config.hitCooldown)
                Config.canHit = true
            end)
        end
    end)
end

--//==============================\\--
--||   👑 REFILL / RELOAD SYSTEM  ||--
--\\==============================//--

local BladeUI_S2       = nil
local Gradient_S2      = nil
local SetsLabel_S2     = nil
local autoBladeRunning = false

pcall(function()
    BladeUI_S2    = player.PlayerGui.Interface.HUD.Main.Top["7"].Blades
    Gradient_S2   = BladeUI_S2.Inner.Bar.Gradient
    SetsLabel_S2  = BladeUI_S2.Sets
end)

local function TweenTo_S2(cf, speed)
    local charRef = player.Character if not charRef then return end
    local hrpRef  = charRef:FindFirstChild("HumanoidRootPart")
    local humRef  = charRef:FindFirstChild("Humanoid")
    if not hrpRef or not humRef or humRef.Health <= 0 then return end
    local distance = (hrpRef.Position - cf.Position).Magnitude
    local t        = distance / speed
    local tween    = TweenService:Create(hrpRef, TweenInfo.new(t, Enum.EasingStyle.Linear), {CFrame = cf})
    tween:Play()
    return tween
end

local refillParts, refillScanAt = nil, 0

local function FindRefillPart()
    -- scan the whole workspace once, then only re-check the cached parts
    local stale = os.clock() - refillScanAt
    if not refillParts or stale > 30 or (#refillParts == 0 and stale > 3) then
        refillParts = {}
        for _, v in pairs(workspace:GetDescendants()) do
            if v:IsA("BasePart") then
                local name = v.Name:lower()
                if name:find("refill") or name:find("fill") then
                    refillParts[#refillParts + 1] = v
                end
            end
        end
        refillScanAt = os.clock()
    end
    for _, v in ipairs(refillParts) do
        if v.Parent then
            local display = v:FindFirstChild("Display")
            if display then
                local ok, title = pcall(function() return display.Main.Top.Title.Text end)
                if ok and title ~= "REFILLS: 0 / 3 [R]" then return v end
            end
        end
    end
    return nil
end

local function Refill_S2()
    local refillPart = FindRefillPart()
    if not refillPart then return end
    TweenTo_S2(refillPart.CFrame, 6000)
    pcall(function()
        ReplicatedStorage.Assets.Remotes.POST:FireServer("Attacks", "Reload", refillPart)
    end)
end

local function ChangeBlade_S2()
    pcall(function()
        ReplicatedStorage.Assets.Remotes.GET:InvokeServer("Blades", "Reload")
    end)
end

local function CheckBlade_S2()
    if not Gradient_S2 then return false end
    local x = Gradient_S2.Offset.X
    if x < 0 then
        local bladeOk = false
        pcall(function()
            local rig = workspace.Characters[player.Name]["Rig_" .. player.Name]
            local blade = rig.LeftHand.Blade_1
            if blade.Transparency == 0 then bladeOk = true end
        end)
        if bladeOk then return false end
        if SetsLabel_S2 and SetsLabel_S2.Text == "0 / 3" then
            Refill_S2()
        else
            ChangeBlade_S2()
        end
        return true
    end
    return false
end

if Gradient_S2 then
    Gradient_S2:GetPropertyChangedSignal("Offset"):Connect(function()
        if autoBladeRunning then CheckBlade_S2() end
    end)
end

local bladeLoopToken = 0
local function StartBladeLoop()
    bladeLoopToken = bladeLoopToken + 1
    local my = bladeLoopToken
    autoBladeRunning = true
    task.spawn(function()
        while autoBladeRunning and bladeLoopToken == my do
            CheckBlade_S2()
            task.wait(0.2)
        end
    end)
end

Tabs.Main:AddSection("Auto Farm")

local BladeToggle = Tabs.Main:AddToggle("AutoBladeReload", {
    Title = "Auto Reload / Refill Blades",
    Description = "Switches blade sets automatically; teleports to refill station when all sets are empty",
    Default = true,
    Callback = function(state)
        if state then
            StartBladeLoop()
        else
            autoBladeRunning = false
            bladeLoopToken = bladeLoopToken + 1
        end
    end
})
-- callbacks don't fire on creation, so start it for the default-on state
if BladeToggle.Value then StartBladeLoop() end

--//==============================\\--
--||        👑 AUTO CLICK M1       ||--
--\\==============================//--

local autoM1Running = false
local autoM1Token   = 0
local M1_DELAY       = 0.25
local M1Toggle

local RESULT_TITLES_M1 = { ["MISSION COMPLETED"] = true, ["RAID COMPLETED"] = true }

local function GuiVisibleM1(obj)
    local cur = obj
    while cur and cur ~= game do
        if cur:IsA("GuiObject") and not cur.Visible then return false end
        if cur:IsA("ScreenGui") and not cur.Enabled then return false end
        cur = cur.Parent
    end
    return true
end

local function MissionCompleted()
    local ok, res = pcall(function()
        local pg = player:FindFirstChild("PlayerGui")
        if not pg then return false end
        for _, d in ipairs(pg:GetDescendants()) do
            if d:IsA("TextLabel") or d:IsA("TextButton") then
                local t = tostring(d.Text or ""):gsub("<[^>]->", "")
                t = t:gsub("^%s+", ""):gsub("%s+$", "")
                if RESULT_TITLES_M1[t:upper()] and GuiVisibleM1(d) then return true end
            end
        end
        return false
    end)
    return ok and res
end

--//==============================\\--
--||     SLOW LAND AFTER MISSION  ||--
--\\==============================//--

Config.missionDone = false
Config.landSpeed   = 15   -- studs per second (lower = slower)

do
    local landed = false

    -- watch for the MISSION / RAID COMPLETED screen (polled, not every frame)
    task.spawn(function()
        while true do
            local done = MissionCompleted()
            if done and not Config.missionDone then
                Config.missionDone = true
                landed = false
            elseif not done and Config.missionDone then
                Config.missionDone = false  -- new mission / retry: farm resumes
                landed = false
            end
            task.wait(0.5)
        end
    end)

    local rayParams = RaycastParams.new()
    rayParams.FilterType = Enum.RaycastFilterType.Exclude
    rayParams.RespectCanCollide = true

    RunService.Heartbeat:Connect(function(dt)
        if not Config.missionDone or landed then return end
        local char = player.Character
        local hrp  = char and char:FindFirstChild("HumanoidRootPart")
        local hum  = char and char:FindFirstChildWhichIsA("Humanoid")
        if not hrp or not hum or hum.Health <= 0 then return end

        local ignore = { char }
        local titans = workspace:FindFirstChild("Titans")
        local chars  = workspace:FindFirstChild("Characters")
        if titans then ignore[#ignore + 1] = titans end
        if chars  then ignore[#ignore + 1] = chars  end
        rayParams.FilterDescendantsInstances = ignore

        local hit = workspace:Raycast(hrp.Position, Vector3.new(0, -5000, 0), rayParams)
        if not hit then landed = true return end -- nothing below: let normal physics take over

        -- stand height = ground + hip height + half the root part (never lower than this = no clipping)
        local standY = hit.Position.Y + hum.HipHeight + hrp.Size.Y / 2 + 0.2
        local y = hrp.Position.Y

        hrp.AssemblyLinearVelocity  = Vector3.zero
        hrp.AssemblyAngularVelocity = Vector3.zero

        if y <= standY + 0.3 then
            landed = true
            return
        end

        local newY = math.max(standY, y - Config.landSpeed * dt)
        local pos  = hrp.Position
        hrp.CFrame = CFrame.new(pos.X, newY, pos.Z) * (hrp.CFrame - hrp.CFrame.Position)
    end)
end

local cachedAttackBtn
local function FindAttackButton()
    if cachedAttackBtn and cachedAttackBtn.Parent and cachedAttackBtn.Visible then return cachedAttackBtn end
    local pg = player:FindFirstChild("PlayerGui")
    if not pg then return nil end
    for _, d in ipairs(pg:GetDescendants()) do
        if d:IsA("GuiButton") and d.Visible then
            local n = d.Name:lower()
            if n == "attack" or n == "m1" or n == "slash" then cachedAttackBtn = d return d end
        end
    end
    return nil
end

local function ClickM1()
    -- real mouse click in the screen centre (M1)
    pcall(function()
        local cam = workspace.CurrentCamera
        local size = cam and cam.ViewportSize or Vector2.new(800, 600)
        local x, y = size.X / 2, size.Y / 2
        VirtualInput:SendMouseButtonEvent(x, y, 0, true, game, 0)
        task.wait(0.03)
        VirtualInput:SendMouseButtonEvent(x, y, 0, false, game, 0)
    end)
    -- on-screen attack button (mobile layout), if one exists
    pcall(function()
        local btn = FindAttackButton()
        if btn then
            if firesignal then
                firesignal(btn.MouseButton1Down)
                firesignal(btn.MouseButton1Up)
                firesignal(btn.MouseButton1Click)
                firesignal(btn.Activated)
            else
                local pos, sz = btn.AbsolutePosition, btn.AbsoluteSize
                local inset = GuiService:GetGuiInset()
                local cx, cy = pos.X + sz.X / 2, pos.Y + sz.Y / 2 + inset.Y
                VirtualInput:SendMouseButtonEvent(cx, cy, 0, true, game, 0)
                task.wait(0.03)
                VirtualInput:SendMouseButtonEvent(cx, cy, 0, false, game, 0)
            end
        end
    end)
end

-- M1 no longer spams on its own: it only clicks when Auto Kill actually fires a hit burst
local M1Enabled = true
local lastM1 = 0

Config.onKillBurst = function()
    if not M1Enabled then return end
    if os.clock() - lastM1 < M1_DELAY then return end
    lastM1 = os.clock()
    ClickM1()
end

M1Toggle = Tabs.Main:AddToggle("AutoClickM1", {
    Title = "Auto Click M1 (only while killing)",
    Description = "Clicks M1 only when Auto Kill is hitting titans. Follows the Auto Kill switch",
    Default = true,
    Callback = function(state)
        M1Enabled = state and true or false
    end
})
if M1Toggle and M1Toggle.Value ~= nil then M1Enabled = M1Toggle.Value and true or false end

local KillToggle = Tabs.Main:AddToggle("AutoKillTitans", {
    Title = "Auto Kill Titans",
    Description = "Don't Finish the mission under 17 sec",
    Default = true,
    Callback = function(state)
        Config.isFlying = state
        if state then task.spawn(killFromAbove) end
        -- M1 setting turns on/off together with Auto Kill
        if M1Toggle and M1Toggle.SetValue then pcall(function() M1Toggle:SetValue(state and true or false) end) end
    end
})
if KillToggle.Value then Config.isFlying = true task.spawn(killFromAbove) end

Tabs.Main:AddDropdown("MoveMode", {
    Title = "Movement Mode",
    Values = {"Teleportation", "Gliding"},
    Default = 1,
    Callback = function(option) Config.moveMode = option end
})

Tabs.Main:AddSlider("StartDelaySlider", {
    Title = "Farm Delay",
    Description = "0 = start instantly. Raise it if the mission ends too early",
    Default = 0,
    Min = 0,
    Max = 50,
    Rounding = 0,
    Callback = function(value) Config.startDelay = value end
})

Tabs.Main:AddSlider("LandSpeedSlider", {
    Title = "Landing Speed (after mission)",
    Description = "How slowly you descend once the mission is complete",
    Default = 15,
    Min = 5,
    Max = 60,
    Rounding = 0,
    Callback = function(value) Config.landSpeed = value end
})

Tabs.Main:AddSlider("FlySpeedSlider", {
    Title = "Gliding Speed",
    Default = 300,
    Min = 50,
    Max = 500,
    Rounding = 0,
    Callback = function(value) Config.flySpeed = value end
})

Tabs.Main:AddSlider("FlyHeightSlider", {
    Title = "Float Height",
    Default = 250,
    Min = 50,
    Max = 300,
    Rounding = 0,
    Callback = function(value) Config.flyHeight = value end
})

Tabs.Main:AddSlider("HitSpeedSlider", {
    Title = "Hit Interval (ms) - lower = faster",
    Default = 120,
    Min = 50,
    Max = 500,
    Rounding = 0,
    Callback = function(value) Config.hitCooldown = value / 1000 end
})

Tabs.Main:AddSlider("MultiHitSlider", {
    Title = "Titans Hit Per Burst",
    Default = 8,
    Min = 1,
    Max = 20,
    Rounding = 0,
    Callback = function(value) Config.multiHit = value end
})

Tabs.Main:AddToggle("HitAllTitans", {
    Title = "Hit All Titans At Once",
    Description = "Every alive titan gets hit in the same burst (ignores Titans Hit Per Burst)",
    Default = false,
    Callback = function(state) Config.hitAll = state end
})

local _Remotes = game:GetService("ReplicatedStorage").Assets.Remotes
local GET, POST = _Remotes.GET, _Remotes.POST

--//==============================\\--
--||        👑 AUTO Retry         ||--
--\\==============================//--

local VIM = game:GetService("VirtualInputManager")

local interface = player:FindFirstChild("PlayerGui")
    and player.PlayerGui:FindFirstChild("Interface")

local rewards     = interface and interface:FindFirstChild("Rewards")
local rewardsMain = rewards and rewards:FindFirstChild("Main")
local retryBtn    = rewardsMain
    and rewardsMain:FindFirstChild("Info")
    and rewardsMain.Info:FindFirstChild("Main")
    and rewardsMain.Info.Main:FindFirstChild("Buttons")
    and rewardsMain.Info.Main.Buttons:FindFirstChild("Retry")

local autoRetryEnabled = false

local function showDebugDot(x, y)
    local dot = Instance.new("Frame")
    dot.Size = UDim2.new(0, 10, 0, 10)
    dot.Position = UDim2.new(0, x - 5, 0, y - 5)
    dot.BackgroundColor3 = Color3.new(1, 0, 0)
    dot.BorderSizePixel = 0
    dot.ZIndex = 10000
    dot.Name = "DebugDot"
    pcall(function() dot.Parent = game:GetService("CoreGui") end)
    game:GetService("Debris"):AddItem(dot, 2)
end

local function Retryshi()
    local pos  = retryBtn.AbsolutePosition
    local size = retryBtn.AbsoluteSize
    local inset = GuiService:GetGuiInset()
    local x = pos.X + size.X / 2 + 20
    local y
    if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
        y = pos.Y + size.Y / 2 + 60
    else
        y = pos.Y + size.Y / 2 + inset.Y
    end
    showDebugDot(x, y)
    VIM:SendMouseButtonEvent(x, y, 0, true, game, 0)
    task.wait(0.05)
    VIM:SendMouseButtonEvent(x, y, 0, false, game, 0)
end

local function shouldClickRetry()
    return retryBtn
        and rewards and rewards.Visible
        and rewardsMain and rewardsMain.Visible
        and retryBtn.Visible
        and retryBtn.AbsoluteSize.Magnitude > 10
end

task.spawn(function()
    while true do
        if autoRetryEnabled and shouldClickRetry() then
            task.wait(0.3)
            if shouldClickRetry() then
                Retryshi()
                task.wait(2)
            end
        end
        task.wait(0.25)
    end
end)

Tabs.Main:AddSection("Utilities")

Tabs.Main:AddToggle("AutoRetryToggle", {
    Title = "Auto Retry",
    Default = false,
    Callback = function(state) autoRetryEnabled = state end
})

--//==============================\\--
--||     AUTO SKIP CUTSCENES      ||--
--\\==============================//--

do
    local S = { running = false, token = 0, lastPress = 0, tries = setmetatable({}, { __mode = "k" }) }

    local function clean(t)
        return (tostring(t or ""):gsub("<[^>]->", ""):lower())
    end

    -- true only if the object and every parent above it is really on screen
    local function visible(obj)
        local cur = obj
        while cur and cur ~= game do
            if cur:IsA("GuiObject") and not cur.Visible then return false end
            if cur:IsA("ScreenGui") and not cur.Enabled then return false end
            if cur:IsA("CanvasGroup") and cur.GroupTransparency >= 0.95 then return false end
            cur = cur.Parent
        end
        return true
    end

    -- anything that says "skip": its name, its own text, or a text label inside it
    local function mentionsSkip(o)
        if o.Name:lower():find("skip", 1, true) then return true end
        if o:IsA("TextLabel") or o:IsA("TextButton") then
            return clean(o.Text):find("skip", 1, true) ~= nil
        end
        for _, c in ipairs(o:GetChildren()) do
            if c:IsA("TextLabel") and clean(c.Text):find("skip", 1, true) then return true end
        end
        return false
    end

    local function realClick(obj)
        local pos, sz = obj.AbsolutePosition, obj.AbsoluteSize
        local inset = GuiService:GetGuiInset()
        local cx, cy = pos.X + sz.X / 2, pos.Y + sz.Y / 2 + inset.Y
        pcall(function()
            VirtualInput:SendMouseButtonEvent(cx, cy, 0, true, game, 0)
            task.wait(0.03)
            VirtualInput:SendMouseButtonEvent(cx, cy, 0, false, game, 0)
        end)
        if UserInputService.TouchEnabled then
            pcall(function()
                VirtualInput:SendTouchEvent(1, 0, cx, cy)
                task.wait(0.03)
                VirtualInput:SendTouchEvent(1, 2, cx, cy)
            end)
        end
    end

    local function fireSignals(btn)
        local fired = false
        if not btn:IsA("GuiButton") then return false end
        if getconnections then
            for _, name in ipairs({ "MouseButton1Down", "MouseButton1Up", "MouseButton1Click", "Activated" }) do
                pcall(function()
                    for _, c in ipairs(getconnections(btn[name])) do
                        c:Fire()
                        fired = true
                    end
                end)
            end
        end
        if not fired and firesignal then
            pcall(function()
                firesignal(btn.MouseButton1Click)
                firesignal(btn.Activated)
                fired = true
            end)
        end
        return fired
    end

    local function pressOnce()
        local pg = player:FindFirstChild("PlayerGui")
        if not pg then return end
        local now = os.clock()
        for _, d in ipairs(pg:GetDescendants()) do
            if d:IsA("GuiObject") and d.AbsoluteSize.X > 0 and d.AbsoluteSize.Y > 0 then
                local isSkip = mentionsSkip(d)
                local isConfirm = false
                -- right after a skip, a "Yes / Confirm" popup may appear: answer it too
                if not isSkip and now - S.lastPress < 6 and d:IsA("TextButton") then
                    local t = clean(d.Text):gsub("^%s+", ""):gsub("%s+$", "")
                    isConfirm = (t == "yes" or t == "confirm" or t == "ok")
                end
                if (isSkip or isConfirm) and visible(d) then
                    -- find the real clickable thing (the label may sit inside a button)
                    local target = d
                    if not d:IsA("GuiButton") then
                        local p = d.Parent
                        for _ = 1, 3 do
                            if p and p:IsA("GuiButton") then target = p break end
                            p = p and p.Parent
                        end
                        if target == d then
                            target = d:FindFirstChildWhichIsA("GuiButton", true) or d
                        end
                    end
                    local s = target.AbsoluteSize
                    local okSize = target:IsA("GuiButton") or (s.X < 500 and s.Y < 200)
                    if okSize and s.X > 0 and s.Y > 0 then
                        local rec = S.tries[target]
                        if not rec or now - rec.t > 1.5 then
                            rec = { t = now, n = (rec and rec.n or 0) + 1 }
                            S.tries[target] = rec
                            S.lastPress = now
                            -- odd tries: fire the button's own handlers; even tries: a real click
                            if rec.n % 2 == 1 then
                                if not fireSignals(target) then realClick(target) end
                            else
                                realClick(target)
                            end
                            return
                        end
                    end
                end
            end
        end
    end

    function S.start()
        S.token += 1
        local my = S.token
        S.running = true
        task.spawn(function()
            while S.running and S.token == my do
                pcall(pressOnce)
                task.wait(0.35)
            end
        end)
    end

    function S.stop()
        S.running = false
        S.token += 1
    end

    -- used by Extras > "Log Skip Buttons": lists everything that looks like a skip button
    Library.__AotrSkipDump = function()
        local out = {}
        local pg = player:FindFirstChild("PlayerGui")
        if pg then
            for _, d in ipairs(pg:GetDescendants()) do
                if d:IsA("GuiObject") and mentionsSkip(d) then
                    local txt = ""
                    if d:IsA("TextLabel") or d:IsA("TextButton") then txt = ' text="' .. clean(d.Text) .. '"' end
                    out[#out + 1] = d:GetFullName() .. " [" .. d.ClassName .. "] visible=" .. tostring(visible(d)) .. txt
                    if #out >= 25 then break end
                end
            end
        end
        local report = #out > 0 and table.concat(out, "\n") or "(nothing with 'skip' found right now)"
        print("[Aotr:update5] skip candidates:\n" .. report)
        pcall(function() if setclipboard then setclipboard(report) end end)
        Notifier:Notify({ Title = "Skip Debug", Content = #out .. " found - printed to console and copied", Duration = 4 })
    end

    local tg = Tabs.Main:AddToggle("AutoSkipCutscenes", {
        Title = "Auto Skip Cutscenes",
        Description = "Presses Skip (and a Yes/Confirm right after it) as soon as a cutscene shows one",
        Default = true,
        Callback = function(state)
            if state then S.start() else S.stop() end
        end
    })
    if tg.Value then S.start() end
end

--//==============================\\--
--||        👑 AUTO Escape        ||--
--\\==============================//--

local escapeRunning    = false
local escapeThread     = nil
local cleanGUIThread   = nil
local lastEscapeButton = nil

Tabs.Main:AddToggle("Escape", {
    Title = "Auto Escape",
    Default = false,
    Callback = function(Value)
        escapeRunning = Value
        if not Value then lastEscapeButton = nil return end
        escapeThread = task.spawn(function()
            local pg = player:WaitForChild("PlayerGui")
            while escapeRunning do
                local iface   = pg:FindFirstChild("Interface")
                local buttons = iface and iface:FindFirstChild("Buttons")
                if buttons then
                    local list = buttons:GetChildren()
                    if #list > 0 then
                        POST:FireServer("Attacks", "Slash_Escape")
                        for _, b in ipairs(list) do b:Destroy() end
                    end
                end
                task.wait(0.05)
            end
        end)
    end
})

--//==============================\\--
--||         👑 Auto Roll         ||--
--\\==============================//--

local CLICK_DELAY = 0.2
local WAIT_DELAY  = 1
local ENABLED     = false

local function canClick(btn)
    return btn and btn.Visible and btn.AbsoluteSize.Magnitude > 10
end

local function isActuallyVisible(obj)
    if not obj then return false end
    local current = obj
    local Gui = player:WaitForChild("PlayerGui")
    while current and current ~= Gui do
        local success3, result3 = pcall(function() return current.Visible end)
        if success3 and not result3 then return false end
        current = current.Parent
    end
    return obj.AbsoluteSize.Magnitude > 10
end

local function clickButton(btn)
    if not btn then return false end
    local pos  = btn.AbsolutePosition
    local size = btn.AbsoluteSize
    local inset = GuiService:GetGuiInset()
    local x = pos.X + size.X / 2
    local y = pos.Y + size.Y / 2 + inset.Y
    VIM:SendMouseMoveEvent(x, y, game)
    task.wait(0.05)
    VIM:SendMouseButtonEvent(x, y, 0, true, game, 0)
    task.wait(0.05)
    VIM:SendMouseButtonEvent(x, y, 0, false, game, 0)
    return true
end

local function findButton(parent, buttonName)
    if not parent then return nil end
    local function searchRecursive(obj)
        if obj.Name == buttonName and obj:IsA("GuiButton") then return obj end
        for _, child in pairs(obj:GetChildren()) do
            local result4 = searchRecursive(child)
            if result4 then return result4 end
        end
        return nil
    end
    return searchRecursive(parent)
end

local function findButtonByText(parent, text)
    if not parent then return nil end
    local function searchRecursive(obj)
        if obj:IsA("GuiButton") or obj:IsA("TextButton") then
            local hasText = obj:FindFirstChild("Text") or obj.Text
            if hasText and string.find(string.lower(tostring(hasText)), string.lower(text)) then return obj end
        end
        for _, child in pairs(obj:GetChildren()) do
            local result5 = searchRecursive(child)
            if result5 then return result5 end
        end
        return nil
    end
    return searchRecursive(parent)
end

task.spawn(function()
    local Gui = player:WaitForChild("PlayerGui")
    local interface2 = Gui:WaitForChild("Interface", 10)
    if not interface2 then return end
    local rollButton = nil
    local searchPaths = {"Customisation.Family.Buttons_2.Roll", "Roll", "RollButton"}
    for _, path in pairs(searchPaths) do
        local pathParts = string.split(path, ".")
        local current = interface2
        for _, part in pairs(pathParts) do
            if current then current = current:FindFirstChild(part) end
        end
        if current and current:IsA("GuiButton") then rollButton = current break end
    end
    if not rollButton then rollButton = findButton(interface2, "Roll") end
    if not rollButton then rollButton = findButtonByText(interface2, "roll") end
    if not rollButton then return end
    while true do
        if ENABLED then
            if canClick(rollButton) and isActuallyVisible(rollButton) then
                clickButton(rollButton)
                task.wait(CLICK_DELAY)
            else task.wait(WAIT_DELAY) end
        else task.wait(1) end
    end
end)

--//==============================\\--
--||        AUTO JOIN TAB         ||--
--\\==============================//--

local Difficulties      = {"Best For You","Easy","Normal","Hard","Severe","Aberrant"}
local DifficultiesRaids = {"Best For You","Hard","Severe","Aberrant"}
local ModifiersList     = {"No Perks","No Skills","No Memories","Nightmare","Oddball","Injury Prone","Chronic Injuries","Fog","Glass Cannon","Time Trial","Boring","Simple"}
local MissionMaps       = {"Shiganshina","Trost","Outskirts","Forest","Utgard","Docks","Stohess","Chapel"}
local MissionObjectives = {
    ["Shiganshina"]={"Skirmish","Breach","Random"},
    ["Trost"]      ={"Skirmish","Protect","Random"},
    ["Outskirts"]  ={"Skirmish","Escort","Random"},
    ["Forest"]     ={"Skirmish","Guard","Random"},
    ["Utgard"]     ={"Skirmish","Defend","Random"},
    ["Docks"]      ={"Skirmish","Stall","Random"},
    ["Stohess"]    ={"Skirmish","Random"},
    ["Chapel"]     ={"Skirmish","Random"},
}
local RaidMaps      = {"Shiganshina","Trost","Stohess"}
local RaidObjectives= {["Shiganshina"]={"Armored Titan","Colossal Titan"},["Trost"]={"Attack Titan"},["Stohess"]={"Female Titan"}}
local WaveMaps      = {"Trost"}

_G.AJ = {
    SelectMissionMap        = MissionMaps[1],
    SelectMissionObjective  = MissionObjectives[MissionMaps[1]][1],
    SelectMissionDifficulty = "Easy",
    SelectMissionModifiers  = {},
    SelectRaidMap           = RaidMaps[1],
    SelectRaidObjective     = RaidObjectives[RaidMaps[1]][1],
    SelectRaidDifficulty    = "Easy",
    SelectRaidModifiers     = {},
    SelectWaveMap           = WaveMaps[1],
    AutoJoinMission         = false,
    AutoJoinMissionBoost    = false,
    AutoJoinRaid            = false,
    AutoJoinWaves           = false,
}

local function PressButton(d)
    game:GetService("GuiService").SelectedObject = d
    VIM:SendKeyEvent(true,  Enum.KeyCode.Return, false, game)
    task.wait(0.05)
    VIM:SendKeyEvent(false, Enum.KeyCode.Return, false, game)
end

local function CreateAndStart(data)
    if game.PlaceId == 14916516914 then
        local ok, res = pcall(function() return GET:InvokeServer("S_Missions","Create",data) end)
        if ok and typeof(res) == "Instance" then
            task.wait(1)
            pcall(function() return GET:InvokeServer("S_Missions","Start") end)
            return true
        end
        return false
    end
end

-- Mission section
Tabs.AutoJoin:AddSection("Auto Join Missions")

local MissionObjectiveDropdown2

Tabs.AutoJoin:AddDropdown("AJ_MissionMap", {
    Title = "Select Map",
    Values = MissionMaps,
    Default = _G.AJ.SelectMissionMap,
    Callback = function(v)
        _G.AJ.SelectMissionMap = v
        local objs = MissionObjectives[v]
        if objs then _G.AJ.SelectMissionObjective = objs[1] end
        if MissionObjectiveDropdown2 then MissionObjectiveDropdown2:SetValues(MissionObjectives[v] or {}) end
    end
})

MissionObjectiveDropdown2 = Tabs.AutoJoin:AddDropdown("AJ_MissionObjective", {
    Title = "Select Objective",
    Values = MissionObjectives[_G.AJ.SelectMissionMap] or {},
    Default = _G.AJ.SelectMissionObjective,
    Callback = function(v) _G.AJ.SelectMissionObjective = v end
})

Tabs.AutoJoin:AddDropdown("AJ_MissionDifficulty", {
    Title = "Select Difficulty",
    Values = Difficulties,
    Default = _G.AJ.SelectMissionDifficulty,
    Callback = function(v) _G.AJ.SelectMissionDifficulty = v end
})

Tabs.AutoJoin:AddDropdown("AJ_MissionModifiers", {
    Title = "Select Modifiers",
    Values = ModifiersList,
    Multi = true,
    Default = _G.AJ.SelectMissionModifiers,
    Callback = function(v) _G.AJ.SelectMissionModifiers = v end
})

Tabs.AutoJoin:AddToggle("AJ_AutoJoinMission", {
    Title = "Auto Join Mission",
    Description = "Automatically joins missions",
    Default = false,
    Callback = function(v) _G.AJ.AutoJoinMission = v end
})

task.spawn(function()
    while task.wait(0.1) do
        if _G.AJ.AutoJoinMission then
            CreateAndStart({Name=_G.AJ.SelectMissionMap,Type="Missions",Difficulty=_G.AJ.SelectMissionDifficulty,Objective=_G.AJ.SelectMissionObjective,Modifiers=_G.AJ.SelectMissionModifiers,Limit=8})
        end
    end
end)

Tabs.AutoJoin:AddToggle("AJ_AutoJoinMissionBoost", {
    Title = "Auto Join Mission (Rewards Boost)",
    Description = "Automatically joins boosted missions",
    Default = false,
    Callback = function(v) _G.AJ.AutoJoinMissionBoost = v end
})

task.spawn(function()
    while task.wait(0.1) do
        if _G.AJ.AutoJoinMissionBoost then
            CreateAndStart({Name=game:GetService("Workspace"):GetAttribute("Boosted_Map"),Type="Missions",Difficulty=_G.AJ.SelectMissionDifficulty,Objective=_G.AJ.SelectMissionObjective,Modifiers=_G.AJ.SelectMissionModifiers,Limit=8})
        end
    end
end)

-- Raids section
Tabs.AutoJoin:AddSection("Auto Join Raids")

local RaidObjectiveDropdown2

Tabs.AutoJoin:AddDropdown("AJ_RaidMap", {
    Title = "Select Raid Map",
    Values = RaidMaps,
    Default = _G.AJ.SelectRaidMap,
    Callback = function(v)
        _G.AJ.SelectRaidMap = v
        local objs = RaidObjectives[v]
        if objs then _G.AJ.SelectRaidObjective = objs[1] end
        if RaidObjectiveDropdown2 then RaidObjectiveDropdown2:SetValues(RaidObjectives[v] or {}) end
    end
})

RaidObjectiveDropdown2 = Tabs.AutoJoin:AddDropdown("AJ_RaidObjective", {
    Title = "Select Raid Boss",
    Values = RaidObjectives[_G.AJ.SelectRaidMap] or {},
    Default = _G.AJ.SelectRaidObjective,
    Callback = function(v) _G.AJ.SelectRaidObjective = v end
})

Tabs.AutoJoin:AddDropdown("AJ_RaidDifficulty", {
    Title = "Select Difficulty",
    Values = DifficultiesRaids,
    Default = _G.AJ.SelectRaidDifficulty,
    Callback = function(v) _G.AJ.SelectRaidDifficulty = v end
})

Tabs.AutoJoin:AddDropdown("AJ_RaidModifiers", {
    Title = "Select Modifiers",
    Values = ModifiersList,
    Multi = true,
    Default = _G.AJ.SelectRaidModifiers,
    Callback = function(v) _G.AJ.SelectRaidModifiers = v end
})

Tabs.AutoJoin:AddToggle("AJ_AutoJoinRaid", {
    Title = "Auto Join Raid",
    Description = "Automatically joins raids",
    Default = false,
    Callback = function(v) _G.AJ.AutoJoinRaid = v end
})

task.spawn(function()
    while task.wait(0.1) do
        if _G.AJ.AutoJoinRaid then
            CreateAndStart({Name=_G.AJ.SelectRaidMap,Type="Raids",Difficulty=_G.AJ.SelectRaidDifficulty,Objective=_G.AJ.SelectRaidObjective,Modifiers=_G.AJ.SelectRaidModifiers,Limit=8})
        end
    end
end)

-- Waves section
Tabs.AutoJoin:AddSection("Auto Join Waves")

Tabs.AutoJoin:AddDropdown("AJ_WaveMap", {
    Title = "Select Wave Map",
    Values = WaveMaps,
    Default = _G.AJ.SelectWaveMap,
    Callback = function(v) _G.AJ.SelectWaveMap = v end
})

Tabs.AutoJoin:AddToggle("AJ_AutoJoinWaves", {
    Title = "Auto Join Waves",
    Description = "Automatically joins waves",
    Default = false,
    Callback = function(v) _G.AJ.AutoJoinWaves = v end
})

task.spawn(function()
    while task.wait(0.1) do
        if _G.AJ.AutoJoinWaves then
            CreateAndStart({Name=_G.AJ.SelectWaveMap,Type="Waves",Difficulty="Easy",Objective="Waves",Limit=8})
        end
    end
end)

-- Leave wrong mission auto-correct
spawn(function()
    while task.wait(0.1) do
        if _G.AJ.AutoJoinMission or _G.AJ.AutoJoinRaid or _G.AJ.AutoJoinWaves then
            for _, v in pairs(game:GetService("ReplicatedStorage").Missions:GetChildren()) do
                if v.Leader.Value == player.Name then
                    local Target = nil
                    if _G.AJ.AutoJoinMission then Target = _G.AJ.SelectMissionMap
                    elseif _G.AJ.AutoJoinMissionBoost then Target = game:GetService("Workspace"):GetAttribute("Boosted_Map")
                    elseif _G.AJ.AutoJoinRaid then Target = _G.AJ.SelectRaidMap
                    elseif _G.AJ.AutoJoinWaves then Target = _G.AJ.SelectWaveMap end
                    if v.Name ~= Target then
                        GET:InvokeServer("S_Missions","Leave")
                    end
                end
            end
        end
    end
end)

--//==============================\\--
--||        SERVERS TAB           ||--
--\\==============================//--

local TPS = TeleportService

Tabs.Servers:AddSection("Server")

Tabs.Servers:AddInput("JobIDInput", {
    Title = "JobID",
    Placeholder = "Paste Job ID here",
    Callback = function(x) _G.JobId_Textbox = x end
})

Tabs.Servers:AddToggle("AutoJoinJobID", {
    Title = "Auto Join JobID",
    Default = false,
    Callback = function(v)
        _G.AutoJoinJobID = v
        if v then
            task.spawn(function()
                while _G.AutoJoinJobID do
                    if _G.JobId_Textbox and _G.JobId_Textbox ~= "" then
                        TPS:TeleportToPlaceInstance(game.PlaceId, _G.JobId_Textbox, player)
                        Notifier:Notify({ Title="Aotr:update5", Content="Joining JobID... Please wait.", Duration=3 })
                    else
                        warn("Please enter a JobID before enabling Auto Join JobID")
                        _G.AutoJoinJobID = false break
                    end
                    task.wait(1)
                end
            end)
        end
    end
})

Tabs.Servers:AddButton({
    Title = "Join JobID",
    Callback = function()
        TPS:TeleportToPlaceInstance(game.PlaceId, _G.JobId_Textbox, player)
        Notifier:Notify({ Title="Aotr:update5", Content="Joining JobID... Please wait.", Duration=3 })
    end
})

Tabs.Servers:AddButton({
    Title = "Copy JobID",
    Callback = function()
        setclipboard(game.JobId)
        Notifier:Notify({ Title="Aotr:update5", Content="Copied JobID!", Duration=3 })
    end
})

Tabs.Servers:AddSection("Basic")

Tabs.Servers:AddButton({
    Title = "Rejoin",
    Description = "Re-enter the same server",
    Callback = function() TeleportService:Teleport(game.PlaceId, player) end
})

getgenv().ServerHop = function()
    local url = "https://games.roblox.com/v1/games/"..game.PlaceId.."/servers/Public?sortOrder=Asc&limit=100"
    local data = HttpService:JSONDecode(game:HttpGet(url))
    for _, v in ipairs(data.data or {}) do
        if v.playing < v.maxPlayers then
            TeleportService:TeleportToPlaceInstance(game.PlaceId, v.id, Players.LocalPlayer) return
        end
    end
end

Tabs.Servers:AddButton({
    Title = "Server Hop",
    Description = "Move to new server",
    Callback = function() getgenv().ServerHop() end
})

Tabs.Servers:AddSection("Smart Server")

Tabs.Servers:AddSlider("MaxPlayersFilter", {
    Title = "Max Players Filter",
    Min = 1,
    Max = 20,
    Default = 5,
    Rounding = 0,
    Callback = function(v) _G.SetP = v end
})

Tabs.Servers:AddButton({
    Title = "Smart Hop",
    Description = "Find server with fewest players",
    Callback = function()
        local limit = _G.SetP
        local body = HttpService:JSONDecode(game:HttpGet("https://games.roblox.com/v1/games/"..game.PlaceId.."/servers/Public?limit=100"))
        for _, v in ipairs(body.data or {}) do
            if v.playing <= limit then TeleportService:TeleportToPlaceInstance(game.PlaceId, v.id, player) break end
        end
    end
})

Tabs.Servers:AddButton({
    Title = "Low Ping Hop",
    Description = "Find lowest ping server",
    Callback = function()
        pcall(function()
            local bestServer, lowestPing = nil, math.random(50, 200)
            local body = HttpService:JSONDecode(game:HttpGet("https://games.roblox.com/v1/games/"..game.PlaceId.."/servers/Public?limit=100"))
            for _, v in ipairs(body.data or {}) do
                local ping = tonumber(v.ping)
                if ping and ping < lowestPing then lowestPing = ping bestServer = v.id end
            end
            if bestServer then TeleportService:TeleportToPlaceInstance(game.PlaceId, tostring(bestServer), player) end
        end)
    end
})

--//==============================\\--
--||           MISC TAB           ||--
--\\==============================//--

getgenv().AutoHideAfterDelay = false

Tabs.Misc:AddSection("Interface")

Tabs.Misc:AddToggle("AutoHideAfter10s", {
    Title = "Auto Hide UI (5s)",
    Default = false,
    Callback = function(state)
        getgenv().AutoHideAfterDelay = state
        if state then
            task.delay(5, function()
                if not getgenv().AutoHideAfterDelay then return end
                getgenv().AutoHideUI = true
                Window:Minimize(true)
            end)
        end
    end
})

local lastTap = 0
local function toggleUI()
    Window:Minimize()
end

UserInputService.TouchTap:Connect(function(_, gameProcessed)
    if gameProcessed then return end
    local now = tick()
    if now - lastTap <= 0.4 then toggleUI() end
    lastTap = now
end)

Tabs.Misc:AddToggle("ToggleNotifications", {
    Title = "Notifications",
    Default = false,
    Callback = function(value) Config.notificationsEnabled = value end
})

Tabs.Misc:AddSection("Game")

local delaySeconds = 180
local toggleActive = false

Tabs.Misc:AddToggle("ForceRetryToggle", {
    Title = "Fail Safe",
    Default = false,
    Callback = function(state)
        toggleActive = state
        if state then
            task.delay(delaySeconds, function()
                if toggleActive then
                    pcall(function() retryRemote:InvokeServer("Functions", "Retry", "Add") end)
                end
            end)
        end
    end
})

-- Auto Force Retry: fires 15s after the MISSION / RAID COMPLETED screen appears
do
    local AUTO_FORCE_RETRY_DELAY = 15
    local autoForceRetry = true
    Tabs.Misc:AddToggle("AutoForceRetry15", {
        Title = "Auto Force Retry (15s)",
        Description = "Automatically Force Retry 15 seconds after a mission is completed.",
        Default = true,
        Callback = function(state) autoForceRetry = state end
    })
    task.spawn(function()
        local shownAt, fired = nil, false
        while true do
            task.wait(0.5)
            if autoForceRetry and MissionCompleted() then
                shownAt = shownAt or os.clock()
                if not fired and os.clock() - shownAt >= AUTO_FORCE_RETRY_DELAY then
                    fired = true
                    pcall(function() retryRemote:InvokeServer("Functions", "Retry", "Add") end)
                end
            else
                shownAt, fired = nil, false
            end
        end
    end)
end

-- Damage Text
local iface2 = player:WaitForChild("PlayerGui"):WaitForChild("Interface")
local damageConnection

Tabs.Misc:AddToggle("dmg", {
    Title = "Remove Dmg Text",
    Default = false,
    Callback = function(state)
        if state then
            for _, obj in pairs(iface2:GetDescendants()) do
                if obj:IsA("TextLabel") and obj.Name == "Number" then obj.Visible = false end
            end
            damageConnection = iface2.DescendantAdded:Connect(function(obj)
                if obj:IsA("TextLabel") and obj.Name == "Number" then obj.Visible = false end
            end)
        else
            if damageConnection then damageConnection:Disconnect() damageConnection = nil end
        end
    end
})

-- Teleport buttons
local lobbyPlaceId    = 14916516914
local mainMenuPlaceId = 13379208636

Tabs.Misc:AddSection("Teleport")

Tabs.Misc:AddButton({
    Title = "Return to Lobby",
    Callback = function() TeleportService:Teleport(lobbyPlaceId, player) end
})

Tabs.Misc:AddButton({
    Title = "Return to Main Menu",
    Callback = function() TeleportService:Teleport(mainMenuPlaceId, player) end
})

Tabs.Misc:AddButton({
    Title = "Force Retry",
    Callback = function()
        local ok, err = pcall(function()
            retryRemote:InvokeServer("Functions", "Retry", "Add")
        end)
        if not ok then warn(".") end
    end,
})

--//==============================\\--
--||            👑 ESP            ||--
--\\==============================//--

local ESPEnabled = false
local ESPColor   = Color3.fromRGB(96, 205, 255)
local ESPSize    = Vector3.new(50, 50, 50)

local function createNapeESP(nape)
    if not nape:FindFirstChild("NapeESP") then
        local esp = Instance.new("BoxHandleAdornment")
        esp.Name        = "NapeESP"
        esp.Adornee     = nape
        esp.AlwaysOnTop = true
        esp.ZIndex      = 5
        esp.Size        = ESPSize
        esp.Transparency = 0.5
        esp.Color3      = ESPColor
        esp.Parent      = nape
    end
end

local function applyNapeESP()
    local titansFolder = workspace:FindFirstChild("Titans")
    if not titansFolder then return end
    for _, titan in ipairs(titansFolder:GetChildren()) do
        local hitboxes = titan:FindFirstChild("Hitboxes")
        if hitboxes then
            local hit  = hitboxes:FindFirstChild("Hit")
            if hit then
                local nape = hit:FindFirstChild("Nape")
                if nape and nape:IsA("BasePart") then createNapeESP(nape) end
            end
        end
    end
end

local function removeAllNapeESP()
    local titansFolder = workspace:FindFirstChild("Titans")
    if not titansFolder then return end
    for _, titan in ipairs(titansFolder:GetChildren()) do
        local hitboxes = titan:FindFirstChild("Hitboxes")
        if hitboxes then
            local hit = hitboxes:FindFirstChild("Hit")
            if hit then
                local nape = hit:FindFirstChild("Nape")
                if nape and nape:FindFirstChild("NapeESP") then nape.NapeESP:Destroy() end
            end
        end
    end
end

local function updateNapeESPColor()
    local titansFolder = workspace:FindFirstChild("Titans")
    if not titansFolder then return end
    for _, titan in ipairs(titansFolder:GetChildren()) do
        local hitboxes = titan:FindFirstChild("Hitboxes")
        if hitboxes then
            local hit = hitboxes:FindFirstChild("Hit")
            if hit then
                local nape = hit:FindFirstChild("Nape")
                if nape then
                    local esp = nape:FindFirstChild("NapeESP")
                    if esp then esp.Color3 = ESPColor end
                end
            end
        end
    end
end

local titansFolderEsp = workspace:FindFirstChild("Titans")
if titansFolderEsp then
    titansFolderEsp.ChildAdded:Connect(function(titan)
        if not ESPEnabled then return end
        task.wait(0.5)
        local hitboxes = titan:FindFirstChild("Hitboxes")
        if hitboxes then
            local hit = hitboxes:FindFirstChild("Hit")
            if hit then
                local nape = hit:FindFirstChild("Nape")
                if nape then createNapeESP(nape) end
            end
        end
    end)
end

Tabs.Esp:AddToggle("NapeESP", {
    Title = "Enable Nape ESP",
    Default = false,
    Callback = function(value)
        ESPEnabled = value
        if value then applyNapeESP() else removeAllNapeESP() end
    end
})

local Colorpicker = Tabs.Esp:AddColorpicker("ESPColorPicker", {
    Title = "ESP Color",
    Default = ESPColor
})

Colorpicker:OnChanged(function(newColor)
    ESPColor = newColor
    updateNapeESPColor()
end)

Colorpicker:SetValueRGB(Color3.fromRGB(96, 205, 255))

-- ============================================================
--  Account / Webhook
--  Logic is copied verbatim from the original; only the UI layer is Obsidian.
-- ============================================================
do
local okMod, errMod = pcall(function()

-- ---------- compat layer (replaces Smooth Hub globals the extracted code expects) ----------
local HttpService = game:GetService("HttpService")
local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local IN_MENU = (game.PlaceId == 13379208636)
local modToken = {}
_G.AotrUpdate5ModToken = modToken
local function Alive() return _G.AotrUpdate5ModToken == modToken end
local SH = { DEV = false }
function SH.say(...) print("[Aotr:update5]", ...) end
function SH.dbg(...) if SH.DEV then print(...) end end
function SH.Guard(name, fn)
    local ok, err = xpcall(fn, function(e) return tostring(e) .. "\n" .. debug.traceback() end)
    if not ok then warn("[Aotr:update5] block " .. tostring(name) .. " failed to load: " .. tostring(err)) end
end
function SH.PlayOn() return true end
local Farm = {}
SH.Farm = Farm
function Farm.CanUseHere()
    return not IN_MENU and game.PlaceId ~= 14916516914
end
local Cfg = {
    AutoFarmThunder = false,
    UseThunderSpears = false,
}
local function Save() end
-- thunder-spear counter (verbatim from Smooth Hub; the "stuck" detector belongs to its farm loop and is not included)
    local function SpearsLeft()
        local char = LocalPlayer.Character
        local n = char and char:GetAttribute("Spears")
        if type(n) == "number" then return n end
        return nil
    end
Farm.SpearsLeft = SpearsLeft
local function IsShown(obj)
    local cur = obj
    while cur and cur ~= PlayerGui do
        if cur:IsA("GuiObject") and not cur.Visible then return false end
        if cur:IsA("ScreenGui") and not cur.Enabled then return false end
        cur = cur.Parent
    end
    return obj:IsA("GuiObject") and obj.AbsoluteSize.X > 0 and obj.AbsoluteSize.Y > 0
end

-- tiny file store for the Webhook tab (own file, never mixed into configs)
local SettingsStore = {}
do
    local DIR = "Aotr_update5/" .. tostring(LocalPlayer.UserId)
    local function Path(file) return DIR .. "/" .. file .. ".json" end
    function SettingsStore.Load(file)
        local data = {}
        pcall(function()
            if isfile and readfile and isfile(Path(file)) then
                local d = HttpService:JSONDecode(readfile(Path(file)))
                if type(d) == "table" then data = d end
            end
        end)
        return data
    end
    function SettingsStore.Write(file, data)
        pcall(function()
            if not (writefile and makefolder) then return end
            if isfolder and not isfolder("Aotr_update5") then makefolder("Aotr_update5") end
            if isfolder and not isfolder(DIR) then makefolder(DIR) end
            writefile(Path(file), HttpService:JSONEncode(data))
        end)
    end
    function SettingsStore.Restore(target, data)
        if type(data) ~= "table" then return end
        for k, v in pairs(data) do
            if target[k] ~= nil and type(target[k]) == type(v) then target[k] = v end
        end
    end
end

-- paragraph -> object with a .Text setter
local function MakeLabel(para)
    local obj = { __instance = para and para.DescLabel }
    return setmetatable(obj, { __newindex = function(_, k, v)
        if k == "Text" then pcall(function() para:SetDesc(tostring(v)) end) end
    end })
end


local AccountTab = EarlyAccountTab
local WebhookTab = Tabs.Webhook
Tabs.Account = AccountTab


-- ================== ACCOUNT TAB ==================
AccountTab:AddSection("📊 Account Overview")
AccountTab:AddParagraph({ Title = "Info", Content = "Read from your player data. N/A = this value was not found." })
local ReplicatedStorageSvc = game:GetService("ReplicatedStorage")
local function FindGui(path)
    local cur = PlayerGui
    for seg in path:gmatch("[^%.]+") do
        cur = cur and cur:FindFirstChild(seg)
        if not cur then return nil end
    end
    return cur
end
local function CountShards()
    local items = FindGui("Interface.Inventory.Main.Holder.Items")
    if not items then return nil end
    local total = 0
    for _, c in ipairs(items:GetChildren()) do
        if c.Name:lower():find("shard", 1, true) then
            local q = 1
            local label = c:FindFirstChild("Quantity", true)
            if label and (label:IsA("TextLabel") or label:IsA("TextButton")) then
                q = tonumber((label.Text:gsub("[^%d]", ""))) or 1
            end
            total += q
        end
    end
    return total
end
local function CurrentFamily()
    local items = FindGui("Interface.Inventory.Main.Holder.Items")
    if not items then return nil end
    for _, c in ipairs(items:GetChildren()) do
        local id, name = c.Name:match("^(%d+)%s*%-%s*(.+)$")
        if id and tonumber(id) % 100 == 2 then
            local main = c:FindFirstChild("Main")
            local eq = main and main:FindFirstChild("Equipped")
            if eq and eq:IsA("GuiObject") and eq.Visible then
                local check = eq:FindFirstChild("Checkmark")
                local on = true
                if check and check:IsA("ImageLabel") and check.ImageTransparency >= 1 then on = false end
                if on then return name end
            end
        end
    end
    return "None"
end
local function AttrTrue(v)
    if type(v) == "boolean" then return v end
    if type(v) == "number" then return v ~= 0 end
    if type(v) == "string" then
        local x = v:lower()
        return x == "true" or x == "yes" or x == "1"
    end
    return false
end
local hiddenLabelCache, hiddenLabelAt = nil, 0
local function FindWarningLabel()
    if os.clock() - hiddenLabelAt < 15 then return hiddenLabelCache end
    hiddenLabelAt = os.clock()
    hiddenLabelCache = false
    local n = 0
    for _, d in ipairs(PlayerGui:GetDescendants()) do
        n += 1
        if n % 600 == 0 then task.wait() end
        if d:IsA("TextLabel") or d:IsA("TextButton") then
            local t = (d.Text or ""):lower()
            if t:find("exploiter", 1, true) or t:find("shadow ban", 1, true) or t:find("shadowban", 1, true) then
                hiddenLabelCache = d:GetFullName():gsub("^Players%.[^%.]+%.PlayerGui%.", "")
                break
            end
        end
    end
    return hiddenLabelCache
end
local function ShadowStatus()
    if FindWarningLabel() then return "✅" end
    if AttrTrue(LocalPlayer:GetAttribute("Exploiter")) or AttrTrue(LocalPlayer:GetAttribute("Blacklisted")) then
        return "✅"
    end
    return "❌"
end
local function FlagCompare()
    local others, flagged = 0, 0
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then
            others += 1
            if AttrTrue(plr:GetAttribute("Exploiter")) or AttrTrue(plr:GetAttribute("Blacklisted")) then
                flagged += 1
            end
        end
    end
    local mine = (AttrTrue(LocalPlayer:GetAttribute("Exploiter")) or AttrTrue(LocalPlayer:GetAttribute("Blacklisted"))) and "flagged" or "clear"
    return ("You: %s | Others flagged: %d/%d"):format(mine, flagged, others)
end
local FIELDS = {
    { key = "ShadowBan", title = "🛠️ Shadow Ban", raw = true, aliases = {}, calc = ShadowStatus,
      colors = { ["✅"] = Color3.fromRGB(80, 200, 120), ["❌"] = Color3.fromRGB(235, 87, 87) } },
    { key = "FlagCompare", title = "🔍 Flag Compare", raw = true, aliases = {}, calc = FlagCompare },
    { key = "Blacklisted", title = "🚫 Blacklisted", flag = true, aliases = { "blacklisted" } },
    { key = "Exploiter", title = "⚠️ Exploiter Flag", flag = true, aliases = { "exploiter" } },
    { key = "Level",     title = "▶️ Level",    aliases = { "level", "lvl", "playerlevel" } },
    { key = "XP",        title = "📈 XP",       aliases = {}, strip = "^XP:%s*",
      gui = "Interface.Gear_Up.XP.Percentage" },
    { key = "Prestige",  title = "🔺 Prestige", aliases = { "prestige", "prestigelevel" } },
    { key = "Gold",      title = "💰 Gold",     aliases = { "gold", "coins", "money" },
      gui = "Interface.Topbar.Main.Currencies.Gold.Amount" },
    { key = "Gems",      title = "💎 Gems",     aliases = { "gems", "gem" },
      gui = "Interface.Topbar.Main.Currencies.Gems.Amount" },
    { key = "Family",    title = "⚡ Family",   aliases = { "family", "familyname", "clan" }, calc = CurrentFamily },
    { key = "Title",     title = "🏷️ Title",    aliases = { "title" }, pretty = true },
    { key = "Shards",    title = "✨ Shards",   aliases = { "shards", "shard" }, calc = CountShards },
}
for _, f in ipairs(FIELDS) do
    local para = AccountTab:AddParagraph({ Title = f.title, Content = "..." })
    f.label = MakeLabel(para)
    f.last = nil
end
local function NormName(s)
    return (tostring(s):lower():gsub("[^%w]", ""))
end
local function Fmt(v)
    if type(v) == "number" then
        if v ~= math.floor(v) then return string.format("%.2f", v) end
        local s = tostring(math.floor(v))
        local neg = s:sub(1, 1) == "-"
        if neg then s = s:sub(2) end
        s = s:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
        return (neg and "-" or "") .. s
    end
    return tostring(v)
end
local function Truthy(v)
    if type(v) == "boolean" then return v end
    if type(v) == "number" then return v ~= 0 end
    if type(v) == "string" then
        local s = v:lower()
        return s == "true" or s == "yes" or s == "1"
    end
    return false
end
local dataRoots = { LocalPlayer }
local lastRootScan = 0
local function ScanRoots(force)
    if not force and os.clock() - lastRootScan < 15 then return end
    lastRootScan = os.clock()
    local roots = { LocalPlayer }
    local uid = tostring(LocalPlayer.UserId)
    local n = 0
    for _, d in ipairs(ReplicatedStorageSvc:GetDescendants()) do
        n += 1
        if n % 500 == 0 then task.wait() end
        if d.Name == LocalPlayer.Name or d.Name == uid then
            table.insert(roots, d)
        end
    end
    dataRoots = roots
end
local SKIP_NAMES = { PlayerGui = true, PlayerScripts = true }
local function CollectEntries()
    local entries = {}
    local function keep(v)
        local t = type(v)
        return t == "number" or t == "string" or t == "boolean"
    end
    local function walk(inst, depth)
        pcall(function()
            for k, v in pairs(inst:GetAttributes()) do
                if keep(v) then
                    entries[#entries + 1] = { name = k, value = v, path = inst:GetFullName() .. " @" .. k }
                end
            end
            if inst:IsA("ValueBase") then
                local ok, v = pcall(function() return inst.Value end)
                if ok and keep(v) then
                    entries[#entries + 1] = { name = inst.Name, value = v, path = inst:GetFullName() }
                end
            end
        end)
        if depth >= 6 then return end
        for _, c in ipairs(inst:GetChildren()) do
            if not SKIP_NAMES[c.Name] then walk(c, depth + 1) end
        end
    end
    for _, root in ipairs(dataRoots) do
        if root and root.Parent then walk(root, 0) end
    end
    return entries
end
local function IsExcludedPath(path)
    return path:find("%.Boosts") ~= nil or path:find("%.Gamepasses") ~= nil
end
local function LookupField(entries, field)
    for _, alias in ipairs(field.aliases) do
        for _, e in ipairs(entries) do
            if NormName(e.name) == alias and not IsExcludedPath(e.path) then
                return e.value
            end
        end
    end
    return nil
end
local function ReadGui(path)
    local cur = FindGui(path)
    if cur and (cur:IsA("TextLabel") or cur:IsA("TextButton")) then
        local t = (cur.Text or ""):gsub("<[^>]->", "")
        t = t:gsub("^%s+", ""):gsub("%s+$", "")
        if t ~= "" then return t end
    end
    return nil
end
local function LabelObject(label)
    local inst = label and label.__instance
    if not inst then return nil end
    if inst:IsA("TextLabel") then return inst end
    return inst:FindFirstChildWhichIsA("TextLabel", true)
end
local lastEntries = {}
local function RefreshOverview()
    ScanRoots(false)
    local entries = CollectEntries()
    lastEntries = entries
    for _, f in ipairs(FIELDS) do
        local v
        if f.calc then
            local okC, r = pcall(f.calc)
            if okC then v = r end
        end
        if v == nil and f.gui then v = ReadGui(f.gui) end
        if v == nil then v = LookupField(entries, f) end
        local text
        if v == nil then
            text = "N/A"
        elseif f.raw then
            text = tostring(v)
        elseif f.flag then
            text = Truthy(v) and "⚠️ Yes" or "✅ No"
        elseif f.strip then
            text = (tostring(v):gsub(f.strip, ""))
        elseif f.pretty then
            text = (tostring(v):gsub("_", " "))
        else
            text = Fmt(v)
        end
        if text ~= f.last then
            f.last = text
            pcall(function() f.label.Text = text end)
            if f.colors and f.colors[text] then
                pcall(function()
                    local obj = LabelObject(f.label)
                    if obj then obj.TextColor3 = f.colors[text] end
                end)
            end
        end
    end
end
task.spawn(function()
    while Alive() do
        pcall(RefreshOverview)
        for _ = 1, 12 do
            if not Alive() then return end
            task.wait(0.25)
        end
    end
end)

-- ================== WEBHOOK (Rewards Logger) ==================
-- Reads the result screen (MISSION / RAID COMPLETED) and sends Time Taken, Damage,
-- Titan Kills, Crits + Gold / XP / Gems to Discord once per finished run.
-- Exact GUI paths are tried first (same ones the original webhook used), then a
-- label / format based search as a fallback. No item details.
SH.Guard("webhook", function()

    local player = LocalPlayer

    -- ---------- UI (Obsidian) ----------
    Tabs.Webhook:AddSection("Rewards Webhook")

    Tabs.Webhook:AddToggle("SendWebhookToggle", {
        Title = "Notify Webhook",
        Description = "Sends your run stats + rewards to Discord when a mission / raid ends",
        Default = false,
    })

    Tabs.Webhook:AddToggle("DisplayUsernameToggle", {
        Title = "Display Roblox Username",
        Default = true,
    })

    Tabs.Webhook:AddInput("WebhookInput", {
        Title = "Webhook",
        Placeholder = "https://discord.com/api/webhooks/...",
        Finished = true,
    })

    Tabs.Webhook:AddInput("BannerInput", {
        Title = "Banner URL (optional)",
        Placeholder = "image link shown under the stats",
        Finished = true,
    })

    Tabs.Webhook:AddToggle("SessionTotalsToggle", {
        Title = "Show Session Totals",
        Description = "Adds a \"Session Total\" column (gold / gems / xp / runs)",
        Default = true,
    })

    local function opt(idx, default)
        local o = Library.Options and Library.Options[idx]
        if o and o.Value ~= nil then return o.Value end
        return default
    end
    local function tog(idx, default)
        local o = Library.Toggles and Library.Toggles[idx]
        if o and o.Value ~= nil then return o.Value end
        return default
    end
    local function WebhookUrl() return (tostring(opt("WebhookInput", "")):gsub("%s", "")) end
    local function BannerUrl() return (tostring(opt("BannerInput", "")):gsub("%s", "")) end

    -- ---------- helpers ----------
    local function GetRequest()
        return (syn and syn.request) or http_request or request or (fluxus and fluxus.request)
    end

    local URL_PREFIXES = {
        "^https://discord%.com/api/webhooks/",
        "^https://discordapp%.com/api/webhooks/",
        "^https://canary%.discord%.com/api/webhooks/",
        "^https://ptb%.discord%.com/api/webhooks/",
    }
    local function ValidUrl(url)
        url = tostring(url or "")
        for _, p in ipairs(URL_PREFIXES) do
            if url:match(p) then return true end
        end
        return false
    end

    local function Fmt(n)
        n = math.floor((tonumber(n) or 0) + 0.5)
        local s = tostring(math.abs(n)):reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
        return (n < 0 and "-" or "") .. s
    end

    local function ParseNum(s)
        if s == nil then return nil end
        s = tostring(s):gsub(",", ""):gsub("%s", "")
        local num, suffix = s:match("^([%d%.]+)([KkMmBb]?)$")
        if not num then return nil end
        num = tonumber(num)
        if not num then return nil end
        local mult = { k = 1e3, m = 1e6, b = 1e9 }
        return num * (mult[(suffix or ""):lower()] or 1)
    end

    local function CleanText(o)
        local t = tostring(o.Text or ""):gsub("<[^>]->", "")
        return (t:gsub("^%s+", ""):gsub("%s+$", ""))
    end

    local function IsValueText(t)
        return t:match("^[%d,%.]+$") or t:match("^%d+:%d+$") or t:match("^%d+:%d+:%d+$") or t:match("^[%d,%.]+[KkMmBb]$")
    end

    -- ---------- finding the result screen ----------
    local RESULT_TITLES = { ["MISSION COMPLETED"] = true, ["RAID COMPLETED"] = true }

    local function GuiAt(path)
        local node = PlayerGui
        for _, part in ipairs(string.split(path, ".")) do
            node = node and node:FindFirstChild(part)
            if not node then return nil end
        end
        return node
    end

    local INFO = "Interface.Rewards.Main.Info.Main"

    local titleCache, titleScanAt = nil, 0
    local function FindTitle()
        -- fast path: the retry button of the rewards screen (what the original webhook used)
        local retry = GuiAt(INFO .. ".Buttons.Retry")
        if retry and IsShown(retry) then return retry end
        if titleCache and titleCache.Parent then
            return IsShown(titleCache) and titleCache or nil
        end
        titleCache = nil
        if os.clock() - titleScanAt < 1 then return nil end
        titleScanAt = os.clock()
        local n = 0
        for _, d in ipairs(PlayerGui:GetDescendants()) do
            n = n + 1
            if n % 800 == 0 then task.wait() end
            if (d:IsA("TextLabel") or d:IsA("TextButton")) and RESULT_TITLES[CleanText(d):upper()] then
                titleCache = d
                return IsShown(d) and d or nil
            end
        end
        return nil
    end

    -- ---------- reading the numbers ----------
    local function PathText(path)
        local o = GuiAt(path)
        if o and (o:IsA("TextLabel") or o:IsA("TextButton") or o:IsA("TextBox")) then
            local t = CleanText(o)
            if t ~= "" then return t end
        end
        return nil
    end

    local STAT_LABELS = {
        time    = "TIME TAKEN",
        damage  = "DAMAGE DEALT",
        kills   = "TITANS KILLED",
        crits   = "CRITICAL HITS",
    }
    local STAT_PATHS = {
        time   = INFO .. ".Stats.Time_Taken.Amount",
        damage = INFO .. ".Stats.Damage_Dealt.Amount",
        kills  = INFO .. ".Stats.Titans_Killed.Amount",
        crits  = INFO .. ".Stats.Critical_Hits.Amount",
    }
    local REWARD_PATHS = {
        gold = INFO .. ".Items.Gold.Main.Inner.Quantity",
        xp   = INFO .. ".Items.XP.Main.Inner.Quantity",
        gems = INFO .. ".Items.Gems.Main.Inner.Quantity",
    }

    -- fallback: find the value that sits next to a "TIME TAKEN"-style label
    local function ValueNextToLabel(root, labelText)
        for _, d in ipairs(root:GetDescendants()) do
            if d:IsA("TextLabel") and IsShown(d) and CleanText(d):upper() == labelText then
                local a = d.Parent
                for _ = 1, 3 do
                    if not a then break end
                    for _, o in ipairs(a:GetDescendants()) do
                        if o ~= d and o:IsA("TextLabel") and IsShown(o) and IsValueText(CleanText(o)) then
                            return CleanText(o)
                        end
                    end
                    a = a.Parent
                end
            end
        end
        return nil
    end

    local function ScreenRoot()
        return GuiAt(INFO) or GuiAt("Interface.Rewards") or PlayerGui
    end

    local function ReadRun()
        if not FindTitle() then return nil end
        local run = {}
        local root = ScreenRoot()

        for key, path in pairs(STAT_PATHS) do
            run[key] = PathText(path) or ValueNextToLabel(root, STAT_LABELS[key])
        end
        -- last resort for time: the only value on the screen shaped like 12:34
        if not run.time then
            for _, d in ipairs(root:GetDescendants()) do
                if d:IsA("TextLabel") and IsShown(d) then
                    local t = CleanText(d)
                    if t:match("^%d+:%d%d$") or t:match("^%d+:%d%d:%d%d$") then run.time = t break end
                end
            end
        end

        for key, path in pairs(REWARD_PATHS) do
            run[key] = PathText(path)
        end
        return run
    end

    local function Score(r)
        if not r then return -1 end
        local n = 0
        for _, k in ipairs({ "time", "damage", "kills", "crits", "gold", "xp", "gems" }) do
            if r[k] and r[k] ~= "0" then n = n + 1 end
        end
        return n
    end

    -- ---------- session totals ----------
    local Totals = { runs = 0, gold = 0, gems = 0, xp = 0, kills = 0 }
    local function AddToTotals(r)
        Totals.runs = Totals.runs + 1
        Totals.gold = Totals.gold + (ParseNum(r.gold) or 0)
        Totals.gems = Totals.gems + (ParseNum(r.gems) or 0)
        Totals.xp = Totals.xp + (ParseNum(r.xp) or 0)
        Totals.kills = Totals.kills + (ParseNum(r.kills) or 0)
    end

    -- ---------- Discord message ----------
    local function Show(v) return (v and v ~= "") and v or "N/A" end

    local function BuildPayload(r)
        local fields = {
            { name = "**User:**", value = tostring(tog("DisplayUsernameToggle", true) and player.Name or "Hidden"), inline = false },
            { name = "**Stats:**", value = string.format(
                "⏱️ %s Time Taken\n💥 %s Damage Dealt\n🗡️ %s Titan Kills\n🎯 %s Critical Hits",
                Show(r.time), Show(r.damage), Show(r.kills), Show(r.crits)
            ), inline = true },
            { name = "**Rewards:**", value = string.format(
                "💰 %s Gold\n✨ %s XP\n💎 %s Gems",
                Show(r.gold), Show(r.xp), Show(r.gems)
            ), inline = true },
        }

        if tog("SessionTotalsToggle", true) then
            fields[#fields + 1] = { name = "**Session Total:**", value = string.format(
                "🏁 %s runs\n💰 %s gold\n✨ %s xp\n💎 %s gems",
                Fmt(Totals.runs), Fmt(Totals.gold), Fmt(Totals.xp), Fmt(Totals.gems)
            ), inline = true }
        end

        local embed = {
            title = "AOT:R Rewards Logger",
            color = 0xE8B84A,
            fields = fields,
            footer = { text = "Sent at: " .. os.date("%d-%b-%Y %I:%M %p") },
        }
        local banner = BannerUrl()
        if banner ~= "" then embed.image = { url = banner } end
        return { embeds = { embed } }
    end

    local function Post(payload)
        local req = GetRequest()
        if not req then Notifier:Notify({ Title = "Webhook", Content = "This executor has no HTTP request function.", Duration = 5 }) return false end
        local url = WebhookUrl()
        if not ValidUrl(url) then Notifier:Notify({ Title = "Webhook", Content = "Webhook is empty or not a Discord webhook link.", Duration = 5 }) return false end
        for attempt = 1, 2 do
            local ok, res = pcall(req, {
                Url = url,
                Method = "POST",
                Headers = { ["Content-Type"] = "application/json" },
                Body = HttpService:JSONEncode(payload),
            })
            local code = ok and type(res) == "table" and (res.StatusCode or res.Status) or nil
            if code and code >= 200 and code < 300 then return true end
            if attempt == 1 then task.wait(2) end
        end
        return false
    end

    Tabs.Webhook:AddButton({
        Title = "Send Test Message",
        Callback = function()
            task.spawn(function()
                local ok = Post(BuildPayload({
                    time = "02:41", damage = "1,250,000", kills = "12", crits = "48",
                    gold = "1,250", xp = "840", gems = "15",
                }))
                Notifier:Notify({
                    Title = "Webhook",
                    Content = ok and "Test message sent!" or "Test failed - check the webhook link.",
                    Duration = 4,
                })
            end)
        end,
    })

    -- ---------- main loop: one message per finished mission / raid ----------
    local sending = false
    local function SendRun()
        if sending then return end
        sending = true
        local best
        pcall(function() best = ReadRun() end)
        -- the stats fill in a moment after the screen opens: re-read until time + rewards are there
        for _ = 1, 6 do
            task.wait(0.7)
            pcall(function()
                local again = ReadRun()
                if Score(again) >= Score(best) then best = again end
            end)
            if best and best.time and best.time ~= "0" and best.gold then break end
        end
        if best and Score(best) > 0 then
            AddToTotals(best)
            Post(BuildPayload(best))
        end
        sending = false
    end

    task.spawn(function()
        local shownSince, goneSince, sent = nil, nil, false
        while Alive() do
            task.wait(0.3)
            if FindTitle() then
                goneSince = nil
                shownSince = shownSince or os.clock()
                if not sent and os.clock() - shownSince >= 0.5 then
                    sent = true
                    if tog("SendWebhookToggle", false) and WebhookUrl() ~= "" then
                        task.spawn(SendRun)
                    end
                end
            else
                shownSince = nil
                goneSince = goneSince or os.clock()
                if os.clock() - goneSince >= 3 then sent = false end
            end
        end
    end)
end)

end)
if not okMod then warn("[Aotr:update5] Account/Webhook/Refill module failed: " .. tostring(errMod)) end
end

--//==============================\\--
--||     UI BACKGROUND IMAGE      ||--
--\\==============================//--
-- Puts the Mikasa / Eren / Armin picture behind the whole Obsidian window.
-- Panels (groupboxes / top bar / sidebar) are made see-through so the image
-- shows behind the toggles, tabs, sliders etc. Both opacities have sliders
-- in Settings > "Background".
do
local BG_B64 = table.concat({
    "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"
})

local BG_FILE = "Aotr_update5/ui_bg_v2.jpg"  -- new name so the old cached picture is not reused
local IMG_T_DEFAULT   = 40   -- image opacity %  (higher = clearer picture)
local PANEL_T_DEFAULT = 55   -- panel see-through %  (higher = more picture visible)
local IMG_DIM         = 0.55 -- darkens the picture so white text stays readable

local state = {
    enabled = true,
    imgOpacity = IMG_T_DEFAULT,
    panelSee = PANEL_T_DEFAULT,
    image = nil,
    main = nil,
    tracked = {},   -- [guiObject] = original BackgroundTransparency
}

local function b64decode(s)
    for _, fn in ipairs({
        function() return crypt and crypt.base64decode and crypt.base64decode(s) end,
        function() return crypt and crypt.base64 and crypt.base64.decode and crypt.base64.decode(s) end,
        function() return base64_decode and base64_decode(s) end,
        function() return base64 and base64.decode and base64.decode(s) end,
        function() return base64decode and base64decode(s) end,
    }) do
        local ok, r = pcall(fn)
        if ok and type(r) == "string" and #r > 1000 and r:sub(1, 2) == "\255\216" then return r end
    end
    -- manual fallback
    local chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
    local map = {}
    for i = 1, 64 do map[chars:byte(i)] = i - 1 end
    local out, n = {}, 0
    local buf, bits = 0, 0
    for i = 1, #s do
        local v = map[s:byte(i)]
        if v then
            buf = buf * 64 + v
            bits = bits + 6
            if bits >= 8 then
                bits = bits - 8
                local div = 2 ^ bits
                local byte = math.floor(buf / div)
                buf = buf - byte * div
                n = n + 1
                out[n] = string.char(byte)
            end
        end
    end
    local parts = {}
    for i = 1, n, 4000 do parts[#parts + 1] = table.concat(out, "", i, math.min(i + 3999, n)) end
    return table.concat(parts)
end

local function getAsset()
    if not (writefile and getcustomasset) then return nil end
    local ok, asset = pcall(function()
        if makefolder and isfolder and not isfolder("Aotr_update5") then makefolder("Aotr_update5") end
        if not (isfile and isfile(BG_FILE)) then
            writefile(BG_FILE, b64decode(BG_B64))
        end
        return getcustomasset(BG_FILE)
    end)
    if ok and asset and asset ~= "" then return asset end
    return nil
end

local function findMain()
    local m = ObsidianWindow.MainFrame
    if typeof(m) == "Instance" then return m end
    local sg = Library.ScreenGui
    if typeof(sg) ~= "Instance" then return nil end
    local best, bestScore
    for _, d in ipairs(sg:GetDescendants()) do
        if d:IsA("GuiObject") then
            local sz = d.AbsoluteSize
            local score = math.abs(sz.X - 640) + math.abs(sz.Y - 480)
            if d.Name == "Main" then score = score - 1000 end
            if sz.X > 300 and sz.Y > 250 and (not bestScore or score < bestScore) then
                best, bestScore = d, score
            end
        end
    end
    return best
end

local function isPanel(o)
    if o == state.image then return false end
    if not (o:IsA("Frame") or o:IsA("ScrollingFrame") or o:IsA("TextButton")) then return false end
    if o.BackgroundTransparency > 0.3 then return false end      -- already see-through
    local s = o.AbsoluteSize
    if o == state.main then return true end
    return s.X > 100 and s.Y > 28                                -- big panels only, never controls
end

local function applyPanel(o)
    if not isPanel(o) then return end
    if state.tracked[o] == nil then state.tracked[o] = o.BackgroundTransparency end
    o.BackgroundTransparency = state.enabled and (1 - (1 - state.tracked[o]) * (1 - state.panelSee / 100)) or state.tracked[o]
end

local function refresh()
    local img = state.image
    if img then
        img.Visible = state.enabled
        img.ImageTransparency = 1 - state.imgOpacity / 100
    end
    local main = state.main
    if not main then return end
    applyPanel(main)
    for _, d in ipairs(main:GetDescendants()) do applyPanel(d) end
    for o, orig in pairs(state.tracked) do
        if o.Parent then
            o.BackgroundTransparency = state.enabled and (1 - (1 - orig) * (1 - state.panelSee / 100)) or orig
        else
            state.tracked[o] = nil
        end
    end
end

local function build()
    local asset = getAsset()
    if not asset then
        warn("[Aotr:update5] background image needs writefile + getcustomasset (not supported by this executor)")
        return false
    end
    local main = findMain()
    if not main then return false end
    state.main = main

    local img = Instance.new("ImageLabel")
    img.Name = "AotrBackground"
    img.BackgroundTransparency = 1
    img.BorderSizePixel = 0
    img.Size = UDim2.fromScale(1, 1)
    img.Position = UDim2.fromScale(0, 0)
    img.Image = asset
    img.ImageColor3 = Color3.new(IMG_DIM, IMG_DIM, IMG_DIM)
    img.ScaleType = Enum.ScaleType.Crop
    img.ZIndex = 0
    img.Active = false
    img.Interactable = false
    local corner = main:FindFirstChildOfClass("UICorner")
    if corner then corner:Clone().Parent = img end
    img.Parent = main
    state.image = img

    -- new panels created later (config / theme sections) get the same treatment
    main.DescendantAdded:Connect(function(d)
        if d:IsA("Frame") or d:IsA("ScrollingFrame") then
            task.defer(function() if d.Parent then applyPanel(d) end end)
        end
    end)

    refresh()
    return true
end

local ok = pcall(build)
if not ok then warn("[Aotr:update5] background image failed to build") end

-- controls
Tabs.Settings:AddSection("Background")
Tabs.Settings:AddToggle("BgImageToggle", {
    Title = "Show Background Image",
    Default = true,
    Callback = function(v) state.enabled = v; refresh() end,
})
Tabs.Settings:AddSlider("BgImageOpacity", {
    Title = "Image Opacity (%)",
    Default = IMG_T_DEFAULT, Min = 5, Max = 100, Rounding = 0,
    Callback = function(v) state.imgOpacity = v; refresh() end,
})
Tabs.Settings:AddSlider("BgPanelSeeThrough", {
    Title = "Panel See-Through (%)",
    Default = PANEL_T_DEFAULT, Min = 0, Max = 90, Rounding = 0,
    Callback = function(v) state.panelSee = v; refresh() end,
})

Library.__AotrBG = { Refresh = refresh }
end

--//==============================\\--
--||            EXTRAS            ||--
--\\==============================//--
-- Anti AFK, Failsafe, NoClip (buildings only) and Auto Execute.
-- Everything lives in the table X so this block adds almost no new locals.
do
local X = {
    timeout    = 180,
    lastSig    = nil,
    lastChange = os.clock(),
    stage      = 0,
    afkOn      = false,
    afkConn    = nil,
    queuedAt   = 0,
    srcFile    = "Aotr_update5/autoexec_source.txt",
    nc         = { orig = setmetatable({}, { __mode = "k" }), stand = nil, standAt = 0, conn = nil, rp = nil },
}

local function tog(idx)
    local t = Library.Toggles and Library.Toggles[idx]
    return t and t.Value or false
end

--------------------------------------------------------------------------
-- PROTECTION: Anti AFK + Failsafe
--------------------------------------------------------------------------
Tabs.Extras:AddSection("Protection")

X.nudge = function()
    pcall(function()
        local vu = game:GetService("VirtualUser")
        vu:CaptureController()
        vu:ClickButton2(Vector2.new(0, 0))
    end)
end

X.setAFK = function(on)
    if X.afkConn then X.afkConn:Disconnect() X.afkConn = nil end
    X.afkOn = on
    if on then
        X.afkConn = player.Idled:Connect(X.nudge)
    end
end

-- belt and braces: a tiny nudge every 50s as well
task.spawn(function()
    while true do
        task.wait(50)
        if X.afkOn then X.nudge() end
    end
end)

local afkT = Tabs.Extras:AddToggle("ExtrasAntiAFK", {
    Title = "Anti AFK",
    Description = "Stops the idle kick while you farm.",
    Default = true,
    Callback = function(v) X.setAFK(v) end,
})
X.setAFK(afkT.Value)

Tabs.Extras:AddToggle("ExtrasFailsafe", {
    Title = "Failsafe (Retry When Stuck)",
    Description = "Auto Kill is on but no kill / mission change for the timeout below: it Force Retries.",
    Default = true,
})
Tabs.Extras:AddToggle("ExtrasFailsafeRejoin", {
    Title = "Failsafe: Rejoin If Still Stuck",
    Description = "Still stuck 90s after the retry: rejoins the game (use together with Auto Execute).",
    Default = true,
})
Tabs.Extras:AddSlider("ExtrasFailsafeTimeout", {
    Title = "Stuck Timeout (seconds)",
    Default = 180, Min = 60, Max = 900, Rounding = 0,
    Callback = function(v) X.timeout = v end,
})
Tabs.Extras:AddToggle("ExtrasRejoinOnKick", {
    Title = "Auto Rejoin On Disconnect / Kick",
    Description = "If the 'You were kicked / disconnected' box appears, rejoin by itself.",
    Default = true,
})

-- stuck watchdog (only in mission places, only while Auto Kill is running)
task.spawn(function()
    while true do
        task.wait(2)
        pcall(function()
            local pid = game.PlaceId
            local inMission = pid ~= lobbyPlaceId and pid ~= mainMenuPlaceId
            local sig = tostring(Config.titanKillCount) .. "|" .. tostring(MissionCompleted())
            if sig ~= X.lastSig or not (tog("ExtrasFailsafe") and tog("AutoKillTitans") and inMission) then
                X.lastSig, X.lastChange, X.stage = sig, os.clock(), 0
                return
            end
            local idle = os.clock() - X.lastChange
            if X.stage == 0 and idle >= X.timeout then
                X.stage = 1
                Notifier:Notify({ Title = "Failsafe", Content = "Stuck - forcing a retry", Duration = 4 })
                pcall(function() retryRemote:InvokeServer("Functions", "Retry", "Add") end)
            elseif X.stage == 1 and idle >= X.timeout + 90 and tog("ExtrasFailsafeRejoin") then
                X.stage = 2
                Notifier:Notify({ Title = "Failsafe", Content = "Retry did not help - rejoining", Duration = 4 })
                TeleportService:Teleport(game.PlaceId, player)
            end
        end)
    end
end)

-- disconnect / kick -> rejoin
task.spawn(function()
    local ok, overlay = pcall(function()
        return game:GetService("CoreGui"):WaitForChild("RobloxPromptGui", 30):WaitForChild("promptOverlay", 30)
    end)
    if not ok or not overlay then return end
    overlay.ChildAdded:Connect(function(c)
        if c.Name ~= "ErrorPrompt" then return end
        task.spawn(function()
            while c.Parent and tog("ExtrasRejoinOnKick") do
                task.wait(3)
                pcall(function() TeleportService:Teleport(game.PlaceId, player) end)
                task.wait(5)
            end
        end)
    end)
end)

--------------------------------------------------------------------------
-- MOVEMENT: NoClip that only ignores buildings, never the ground
--------------------------------------------------------------------------
Tabs.Extras:AddSection("Movement")

X.ncStep = function()
    local char = player.Character
    local hrp  = char and char:FindFirstChild("HumanoidRootPart")
    local hum  = char and char:FindFirstChildOfClass("Humanoid")
    if not (hrp and hum) then return end
    local nc = X.nc

    -- 1) walk through walls / buildings
    for _, p in ipairs(char:GetDescendants()) do
        if p:IsA("BasePart") then
            if nc.orig[p] == nil then nc.orig[p] = p.CanCollide end
            p.CanCollide = false
        end
    end

    -- 2) but never sink into the ground
    local ignore = { char }
    local t = workspace:FindFirstChild("Titans")
    if t then ignore[#ignore + 1] = t end
    local c = workspace:FindFirstChild("Characters")
    if c then ignore[#ignore + 1] = c end
    nc.rp.FilterDescendantsInstances = ignore

    local off = hum.HipHeight + hrp.Size.Y / 2
    local pos = hrp.Position
    local hit = workspace:Raycast(pos, Vector3.new(0, -(off + 1.5), 0), nc.rp)
    if hit then
        nc.stand, nc.standAt = hit.Position.Y, os.clock()  -- remember the last ground we stood on
        return
    end
    local st = nc.stand
    if st and os.clock() - nc.standAt < 1.5 and pos.Y < st + off - 1.2 then
        -- we dropped below where the ground was: is there still ground right here? then put us back on it
        local probe = workspace:Raycast(Vector3.new(pos.X, st + 3, pos.Z), Vector3.new(0, -8, 0), nc.rp)
        if probe and math.abs(probe.Position.Y - st) <= 3 then
            local v = hrp.AssemblyLinearVelocity
            hrp.CFrame = CFrame.new(pos.X, probe.Position.Y + off + 0.1, pos.Z) * (hrp.CFrame - hrp.CFrame.Position)
            hrp.AssemblyLinearVelocity = Vector3.new(v.X, 0, v.Z)
        end
    end
end

Tabs.Extras:AddToggle("ExtrasNoclip", {
    Title = "NoClip (Buildings Only)",
    Description = "Pass through buildings and walls. The ground still holds you up. Turn it off while you are outside walls.",
    Default = false,
    Callback = function(v)
        local nc = X.nc
        if nc.conn then nc.conn:Disconnect() nc.conn = nil end
        if v then
            nc.rp = RaycastParams.new()
            nc.rp.FilterType = Enum.RaycastFilterType.Exclude
            nc.rp.RespectCanCollide = true
            nc.conn = RunService.Stepped:Connect(function() pcall(X.ncStep) end)
        else
            for p, was in pairs(nc.orig) do
                if p.Parent then p.CanCollide = was end
            end
            nc.orig = setmetatable({}, { __mode = "k" })
            nc.stand = nil
        end
    end,
})

--------------------------------------------------------------------------
-- AUTO EXECUTE: re-run THIS script after every teleport / rejoin / hop
--------------------------------------------------------------------------
Tabs.Extras:AddSection("Auto Execute")

X.trim = function(s)
    return (tostring(s or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

X.loadSource = function()
    local s = ""
    pcall(function() if getgenv and getgenv().AotrScriptURL then s = getgenv().AotrScriptURL end end)
    if X.trim(s) == "" then
        pcall(function() if isfile and isfile(X.srcFile) then s = readfile(X.srcFile) end end)
    end
    return X.trim(s)
end
X.src = X.loadSource()

X.saveSource = function(s)
    X.src = X.trim(s)
    pcall(function()
        if writefile then
            if makefolder and isfolder and not isfolder("Aotr_update5") then makefolder("Aotr_update5") end
            writefile(X.srcFile, X.src)
        end
    end)
end

X.queue = function(silent)
    local q = queue_on_teleport or (syn and syn.queue_on_teleport) or (fluxus and fluxus.queue_on_teleport)
    if not q then
        if not silent then Notifier:Notify({ Title = "Auto Execute", Content = "Your executor has no queue_on_teleport.", Duration = 5 }) end
        return false
    end
    if X.src == "" then
        if not silent then Notifier:Notify({ Title = "Auto Execute", Content = "Paste this script's URL / file name first.", Duration = 5 }) end
        return false
    end
    local run
    if X.src:match("^https?://") then
        run = ("loadstring(game:HttpGet(%q))()"):format(X.src)
    else
        run = ("loadstring(readfile(%q))()"):format(X.src)
    end
    local payload = ("if not game:IsLoaded() then game.Loaded:Wait() end\ntask.wait(3)\npcall(function() getgenv().AotrAutoExec = true; getgenv().AotrScriptURL = %q end)\n%s\n"):format(X.src, run)
    return pcall(q, payload)
end

Tabs.Extras:AddInput("ExtrasAutoExecSource", {
    Title = "This Script's URL / File",
    Default = X.src,
    Placeholder = "raw URL of this script (or workspace file name)",
    Finished = true,
    Callback = function(v) X.saveSource(v) end,
})

Tabs.Extras:AddToggle("ExtrasAutoExec", {
    Title = "Auto Execute On Teleport / Rejoin",
    Description = "Runs the same script again after every teleport, rejoin or server hop.",
    Default = (getgenv and getgenv().AotrAutoExec == true) or false,
})

Tabs.Extras:AddButton({
    Title = "Check Auto Execute",
    Callback = function()
        local q = queue_on_teleport or (syn and syn.queue_on_teleport) or (fluxus and fluxus.queue_on_teleport)
        local msg
        if not q then msg = "Executor has no queue_on_teleport - auto execute can't work here."
        elseif X.src == "" then msg = "No script URL / file saved yet."
        else msg = "Ready. Will re-run: " .. X.src end
        Notifier:Notify({ Title = "Auto Execute", Content = msg, Duration = 6 })
    end,
})

-- queue once per teleport (the new server runs it, and it queues again for the next hop)
player.OnTeleport:Connect(function(state)
    if state == Enum.TeleportState.Started and tog("ExtrasAutoExec") and os.clock() - X.queuedAt > 5 then
        X.queuedAt = os.clock()
        X.queue(true)
    end
end)

--------------------------------------------------------------------------
-- DEBUG
--------------------------------------------------------------------------
Tabs.Extras:AddSection("Debug")
Tabs.Extras:AddButton({
    Title = "Log Skip Buttons",
    Description = "During a cutscene: prints + copies every GUI that looks like a Skip button.",
    Callback = function()
        if Library.__AotrSkipDump then Library.__AotrSkipDump() end
    end,
})
end

--//==============================\\--
--||         SAVE / LOAD          ||--
--\\==============================//--

Window:SelectTab(Tabs.Main)

pcall(function()
    local menu = Tabs.Settings._tab:AddRightGroupbox("Menu")
    menu:AddLabel("Menu keybind"):AddKeyPicker("MenuKeybind", {
        Default = "LeftControl", NoUI = true, Text = "Menu keybind",
    })
    Library.ToggleKeybind = Library.Options.MenuKeybind
end)

local function safe(name, fn)
    local ok, err = pcall(fn)
    if not ok then warn("[Aotr:update5] " .. name .. " failed: " .. tostring(err)) end
end

safe("ThemeManager", function()
    ThemeManager:SetLibrary(Library)
    ThemeManager:SetFolder("Aotr_update5")
end)
safe("SaveManager", function()
    SaveManager:SetLibrary(Library)
    SaveManager:IgnoreThemeSettings()
    SaveManager:SetIgnoreIndexes({ "MenuKeybind" })
    SaveManager:SetFolder("Aotr_update5")
    SaveManager:BuildConfigSection(Tabs.Settings._tab)
end)
safe("ThemeTab", function() ThemeManager:ApplyToTab(Tabs.Settings._tab) end)
safe("Autoload", function() SaveManager:LoadAutoloadConfig() end)
safe("BackgroundRefresh", function() if Library.__AotrBG then Library.__AotrBG.Refresh() end end)

Notifier:Notify({
    Title   = "Aotr:update5",
    Content = "Loaded successfully! Tap the tray icon to hide/show the UI.",
    Duration = 4,
})
