repeat task.wait() until game:IsLoaded() and game.Players.LocalPlayer

local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Camera           = workspace.CurrentCamera
local player           = Players.LocalPlayer

-- ===================== SAFE WRAPPERS =====================

local function sFire(hrp, part, tog)
    if type(firetouchinterest) == "function" then
        pcall(firetouchinterest, hrp, part, tog)
    end
end

local function sPrompt(p)
    if type(fireproximityprompt) == "function" then
        pcall(fireproximityprompt, p)
    end
end

local function sClick(d)
    if type(fireclickdetector) == "function" then
        pcall(fireclickdetector, d)
    end
end

-- ===================== STATE =====================

local godMode       = false
local autoEat       = false
local autoRepair    = false
local speedBoat     = false
local autoChest     = false
local autoSack      = false
local killAura      = false
local autoHarpoon   = false
local autoFish      = false
local itemEsp       = false
local serverInfo    = false
local boatSpeed     = 50

-- Tool names exactly as seen in hotbar
local TOOL_HARPOON  = "Harpoon"
local TOOL_MACHETE  = "Machete"
local TOOL_ROD      = "Fishing Rod"
local TOOL_SACK     = "Old Sack"

-- ===================== CACHED WORKSPACE SCAN =====================
-- Instead of GetDescendants() every frame (VERY laggy),
-- we cache results and only refresh every N seconds

local cachedNPCs   = {}
local cachedItems  = {}
local cachedChests = {}
local lastScan     = 0
local SCAN_INTERVAL = 3  -- rescan every 3 seconds

local NPC_TAGS   = {"enemy","monster","shark","crab","creature","beast","crab","octopus",
                    "eel","pirate","bandit","hostile","mob","zombie","mutant","anglerfish",
                    "kraken","serpent","leviathan","siren"}
local ITEM_TAGS  = {"sack","drop","loot","supply","coin","gold","ore","pearl",
                    "fish","bait","rope","plank","barrel","resource","collectible"}
local CHEST_TAGS = {"chest","treasure","crate"}

local function tagMatch(name, tags)
    local n = string.lower(name)
    for _, t in ipairs(tags) do
        if n:find(t, 1, true) then return true end
    end
    return false
end

local function isPlayerChar(model)
    for _, p in ipairs(Players:GetPlayers()) do
        if p.Character == model then return true end
    end
    return false
end

local function refreshCache()
    cachedNPCs   = {}
    cachedItems  = {}
    cachedChests = {}

    for _, obj in ipairs(workspace:GetDescendants()) do
        -- NPCs: Models with Humanoid, not a player
        if obj:IsA("Model") and obj:FindFirstChildWhichIsA("Humanoid") then
            if not isPlayerChar(obj) then
                cachedNPCs[#cachedNPCs+1] = obj
            end
        -- Chests
        elseif (obj:IsA("Model") or obj:IsA("BasePart")) then
            if not obj:FindFirstChildWhichIsA("Humanoid") then
                if tagMatch(obj.Name, CHEST_TAGS) then
                    local part = obj:IsA("BasePart") and obj or obj:FindFirstChildWhichIsA("BasePart")
                    if part then cachedChests[#cachedChests+1] = {obj=obj, part=part} end
                elseif tagMatch(obj.Name, ITEM_TAGS) then
                    local part = obj:IsA("BasePart") and obj or obj:FindFirstChildWhichIsA("BasePart")
                    if part then cachedItems[#cachedItems+1] = {obj=obj, part=part} end
                end
            end
        end
    end
end

-- ===================== TOOL HELPERS =====================

local function getHRP()
    local c = player.Character
    return c and c:FindFirstChild("HumanoidRootPart")
end

local function getHum()
    local c = player.Character
    return c and c:FindFirstChildWhichIsA("Humanoid")
end

local function getBackpackTool(name)
    -- Check backpack first
    local bp = player:FindFirstChild("Backpack")
    if bp then
        local t = bp:FindFirstChild(name)
        if t then return t end
    end
    -- Then character (already equipped)
    local c = player.Character
    if c then
        local t = c:FindFirstChild(name)
        if t then return t end
    end
    return nil
end

local function equipTool(name)
    local tool = getBackpackTool(name)
    if not tool then return nil end
    -- If in backpack, move to character to equip
    if tool.Parent == player.Backpack then
        tool.Parent = player.Character
    end
    task.wait(0.1)
    return player.Character and player.Character:FindFirstChild(name)
end

local function activateTool(tool)
    if not tool then return end
    pcall(function()
        tool:Activate()
    end)
end

local function fireAllPrompts(obj)
    if not obj then return end
    for _, d in ipairs(obj:GetDescendants()) do
        if d:IsA("ProximityPrompt") then sPrompt(d) end
        if d:IsA("ClickDetector")   then sClick(d)  end
    end
    if obj:IsA("ProximityPrompt") then sPrompt(obj) end
    if obj:IsA("ClickDetector")   then sClick(obj)  end
end

local function fireRemote(pattern, ...)
    local args = {...}
    for _, obj in ipairs(game:GetDescendants()) do
        if obj:IsA("RemoteEvent") and
           string.lower(obj.Name):find(string.lower(pattern), 1, true) then
            pcall(function() obj:FireServer(table.unpack(args)) end)
        end
    end
end

local function clickGuiBtn(pattern)
    for _, gui in ipairs(player.PlayerGui:GetChildren()) do
        for _, d in ipairs(gui:GetDescendants()) do
            if (d:IsA("TextButton") or d:IsA("ImageButton")) and d.Visible then
                if string.lower(d.Text or ""):find(pattern, 1, true) then
                    pcall(function()
                        d.MouseButton1Down:Fire()
                        task.wait(0.05)
                        d.MouseButton1Up:Fire()
                        d.MouseButton1Click:Fire()
                    end)
                end
            end
        end
    end
end

-- ===================== GUI =====================

local sg = Instance.new("ScreenGui")
sg.Name = "SeaHub"
sg.ResetOnSpawn = false
sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
sg.Parent = player:WaitForChild("PlayerGui")

local win = Instance.new("Frame")
win.Size = UDim2.new(0, 310, 0, 460)
win.Position = UDim2.new(0, 16, 0.5, -230)
win.BackgroundColor3 = Color3.fromRGB(7, 12, 22)
win.BorderSizePixel = 0
win.Active = true
win.Draggable = true
win.Parent = sg
Instance.new("UICorner", win).CornerRadius = UDim.new(0, 12)
local wStr = Instance.new("UIStroke", win)
wStr.Color = Color3.fromRGB(30, 100, 200)
wStr.Thickness = 1.2

local topBar = Instance.new("Frame")
topBar.Size = UDim2.new(1, 0, 0, 3)
topBar.BackgroundColor3 = Color3.fromRGB(30, 120, 255)
topBar.BorderSizePixel = 0
topBar.Parent = win
Instance.new("UICorner", topBar).CornerRadius = UDim.new(0, 12)

local titleLbl = Instance.new("TextLabel")
titleLbl.Size = UDim2.new(1, -50, 0, 18)
titleLbl.Position = UDim2.new(0, 12, 0, 10)
titleLbl.BackgroundTransparency = 1
titleLbl.Text = "100 Days at Sea"
titleLbl.TextColor3 = Color3.fromRGB(220, 235, 255)
titleLbl.TextSize = 13
titleLbl.Font = Enum.Font.GothamBold
titleLbl.TextXAlignment = Enum.TextXAlignment.Left
titleLbl.Parent = win

local subLbl = Instance.new("TextLabel")
subLbl.Size = UDim2.new(1, -50, 0, 13)
subLbl.Position = UDim2.new(0, 12, 0, 27)
subLbl.BackgroundTransparency = 1
subLbl.Text = "SCRIPT HUB"
subLbl.TextColor3 = Color3.fromRGB(30, 120, 255)
subLbl.TextSize = 10
subLbl.Font = Enum.Font.GothamBold
subLbl.TextXAlignment = Enum.TextXAlignment.Left
subLbl.Parent = win

local xBtn = Instance.new("TextButton")
xBtn.Size = UDim2.new(0, 24, 0, 24)
xBtn.Position = UDim2.new(1, -32, 0, 10)
xBtn.BackgroundColor3 = Color3.fromRGB(14, 18, 30)
xBtn.Text = "X"
xBtn.TextColor3 = Color3.fromRGB(100, 150, 255)
xBtn.TextSize = 11
xBtn.Font = Enum.Font.GothamBold
xBtn.BorderSizePixel = 0
xBtn.Parent = win
Instance.new("UICorner", xBtn).CornerRadius = UDim.new(0, 5)
xBtn.MouseButton1Click:Connect(function() sg:Destroy() end)

local function mkDiv(parent, y)
    local d = Instance.new("Frame")
    d.Size = UDim2.new(1, -24, 0, 1)
    d.Position = UDim2.new(0, 12, 0, y)
    d.BackgroundColor3 = Color3.fromRGB(18, 28, 50)
    d.BorderSizePixel = 0
    d.Parent = parent
end
mkDiv(win, 47)

local tabNames = {"Main", "Combat", "Visual", "Info"}
local tabBtns  = {}
local tabWidth = (310 - 24) / #tabNames

local tabBar = Instance.new("Frame")
tabBar.Size = UDim2.new(1, -24, 0, 28)
tabBar.Position = UDim2.new(0, 12, 0, 53)
tabBar.BackgroundTransparency = 1
tabBar.Parent = win

for i, name in ipairs(tabNames) do
    local tb = Instance.new("TextButton")
    tb.Size = UDim2.new(0, tabWidth - 3, 0, 26)
    tb.Position = UDim2.new(0, (i-1)*tabWidth, 0, 0)
    tb.BackgroundColor3 = Color3.fromRGB(10, 16, 28)
    tb.BorderSizePixel = 0
    tb.Text = name
    tb.TextColor3 = Color3.fromRGB(60, 100, 160)
    tb.TextSize = 10
    tb.Font = Enum.Font.GothamBold
    tb.Parent = tabBar
    Instance.new("UICorner", tb).CornerRadius = UDim.new(0, 6)
    tabBtns[name] = tb
end

mkDiv(win, 86)

local content = Instance.new("Frame")
content.Size = UDim2.new(1, -24, 0, 336)
content.Position = UDim2.new(0, 12, 0, 93)
content.BackgroundTransparency = 1
content.Parent = win

local statusBar = Instance.new("Frame")
statusBar.Size = UDim2.new(1, -24, 0, 22)
statusBar.Position = UDim2.new(0, 12, 0, 430)
statusBar.BackgroundColor3 = Color3.fromRGB(5, 8, 16)
statusBar.BorderSizePixel = 0
statusBar.Parent = win
Instance.new("UICorner", statusBar).CornerRadius = UDim.new(0, 5)

local sDot = Instance.new("Frame")
sDot.Size = UDim2.new(0, 5, 0, 5)
sDot.Position = UDim2.new(0, 8, 0.5, -2)
sDot.BackgroundColor3 = Color3.fromRGB(30, 120, 255)
sDot.BorderSizePixel = 0
sDot.Parent = statusBar
Instance.new("UICorner", sDot).CornerRadius = UDim.new(1, 0)

local sTxt = Instance.new("TextLabel")
sTxt.Size = UDim2.new(1, -22, 1, 0)
sTxt.Position = UDim2.new(0, 18, 0, 0)
sTxt.BackgroundTransparency = 1
sTxt.Text = "Ready"
sTxt.TextColor3 = Color3.fromRGB(60, 100, 160)
sTxt.TextSize = 9
sTxt.Font = Enum.Font.Code
sTxt.TextXAlignment = Enum.TextXAlignment.Left
sTxt.Parent = statusBar

local function setStatus(txt) sTxt.Text = "> " .. txt end

local pages = {}
for _, name in ipairs(tabNames) do
    local p = Instance.new("Frame")
    p.Size = UDim2.new(1, 0, 1, 0)
    p.BackgroundTransparency = 1
    p.Visible = false
    p.Parent = content
    pages[name] = p
end
pages["Main"].Visible = true

local function switchTab(name)
    for _, n in ipairs(tabNames) do
        pages[n].Visible = (n == name)
        if n == name then
            tabBtns[n].BackgroundColor3 = Color3.fromRGB(20, 80, 200)
            tabBtns[n].TextColor3 = Color3.fromRGB(220, 235, 255)
        else
            tabBtns[n].BackgroundColor3 = Color3.fromRGB(10, 16, 28)
            tabBtns[n].TextColor3 = Color3.fromRGB(60, 100, 160)
        end
    end
end
switchTab("Main")
for _, n in ipairs(tabNames) do
    tabBtns[n].MouseButton1Click:Connect(function() switchTab(n) end)
end

-- ===================== UI HELPERS =====================

local function mkLabel(parent, y, text)
    local l = Instance.new("TextLabel")
    l.Size = UDim2.new(1, 0, 0, 14)
    l.Position = UDim2.new(0, 0, 0, y)
    l.BackgroundTransparency = 1
    l.Text = text
    l.TextColor3 = Color3.fromRGB(40, 80, 150)
    l.TextSize = 9
    l.Font = Enum.Font.GothamBold
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.Parent = parent
end

local function mkToggle(parent, y, label, cb)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 34)
    row.Position = UDim2.new(0, 0, 0, y)
    row.BackgroundColor3 = Color3.fromRGB(10, 16, 28)
    row.BorderSizePixel = 0
    row.Parent = parent
    Instance.new("UICorner", row).CornerRadius = UDim.new(0, 7)

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -60, 1, 0)
    lbl.Position = UDim2.new(0, 10, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = label
    lbl.TextColor3 = Color3.fromRGB(180, 210, 255)
    lbl.TextSize = 12
    lbl.Font = Enum.Font.GothamBold
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = row

    local swBg = Instance.new("Frame")
    swBg.Size = UDim2.new(0, 36, 0, 20)
    swBg.Position = UDim2.new(1, -44, 0.5, -10)
    swBg.BackgroundColor3 = Color3.fromRGB(18, 28, 50)
    swBg.BorderSizePixel = 0
    swBg.Parent = row
    Instance.new("UICorner", swBg).CornerRadius = UDim.new(1, 0)

    local knob = Instance.new("Frame")
    knob.Size = UDim2.new(0, 14, 0, 14)
    knob.Position = UDim2.new(0, 3, 0.5, -7)
    knob.BackgroundColor3 = Color3.fromRGB(40, 70, 120)
    knob.BorderSizePixel = 0
    knob.Parent = swBg
    Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)

    local on = false
    local function setState(s)
        on = s
        swBg.BackgroundColor3 = on and Color3.fromRGB(20,100,255) or Color3.fromRGB(18,28,50)
        knob.Position = on and UDim2.new(0,19,0.5,-7) or UDim2.new(0,3,0.5,-7)
        knob.BackgroundColor3 = on and Color3.fromRGB(255,255,255) or Color3.fromRGB(40,70,120)
    end
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 1, 0)
    btn.BackgroundTransparency = 1
    btn.Text = ""
    btn.Parent = row
    btn.MouseButton1Click:Connect(function() setState(not on) cb(on) end)
    return setState
end

local function mkSlider(parent, y, label, min, max, default, cb)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 0, 48)
    frame.Position = UDim2.new(0, 0, 0, y)
    frame.BackgroundColor3 = Color3.fromRGB(10, 16, 28)
    frame.BorderSizePixel = 0
    frame.Parent = parent
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 7)

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(0.65, 0, 0, 18)
    lbl.Position = UDim2.new(0, 10, 0, 4)
    lbl.BackgroundTransparency = 1
    lbl.Text = label
    lbl.TextColor3 = Color3.fromRGB(180, 210, 255)
    lbl.TextSize = 11
    lbl.Font = Enum.Font.GothamBold
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = frame

    local valLbl = Instance.new("TextLabel")
    valLbl.Size = UDim2.new(0.32, 0, 0, 18)
    valLbl.Position = UDim2.new(0.66, 0, 0, 4)
    valLbl.BackgroundTransparency = 1
    valLbl.Text = tostring(default)
    valLbl.TextColor3 = Color3.fromRGB(30, 120, 255)
    valLbl.TextSize = 11
    valLbl.Font = Enum.Font.GothamBold
    valLbl.TextXAlignment = Enum.TextXAlignment.Right
    valLbl.Parent = frame

    local track = Instance.new("Frame")
    track.Size = UDim2.new(1, -20, 0, 4)
    track.Position = UDim2.new(0, 10, 0, 34)
    track.BackgroundColor3 = Color3.fromRGB(18, 28, 50)
    track.BorderSizePixel = 0
    track.Parent = frame
    Instance.new("UICorner", track).CornerRadius = UDim.new(1, 0)

    local fill = Instance.new("Frame")
    fill.Size = UDim2.new((default-min)/(max-min), 0, 1, 0)
    fill.BackgroundColor3 = Color3.fromRGB(20, 100, 255)
    fill.BorderSizePixel = 0
    fill.Parent = track
    Instance.new("UICorner", fill).CornerRadius = UDim.new(1, 0)

    local thumb = Instance.new("TextButton")
    thumb.Size = UDim2.new(0, 14, 0, 14)
    thumb.Position = UDim2.new((default-min)/(max-min), -7, 0.5, -7)
    thumb.BackgroundColor3 = Color3.fromRGB(255,255,255)
    thumb.Text = ""
    thumb.BorderSizePixel = 0
    thumb.Parent = track
    Instance.new("UICorner", thumb).CornerRadius = UDim.new(1, 0)

    local dragging = false
    thumb.MouseButton1Down:Connect(function() dragging = true end)
    UserInputService.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1
        or i.UserInputType == Enum.UserInputType.Touch then dragging = false end
    end)
    local function update(x)
        local rel = math.clamp((x - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
        local val = math.floor(min + rel*(max-min))
        fill.Size = UDim2.new(rel, 0, 1, 0)
        thumb.Position = UDim2.new(rel, -7, 0.5, -7)
        valLbl.Text = tostring(val)
        cb(val)
    end
    UserInputService.InputChanged:Connect(function(i) if dragging then update(i.Position.X) end end)
    track.InputBegan:Connect(function(i) update(i.Position.X) end)
end

local function mkInfoRow(parent, y, label)
    local f = Instance.new("Frame")
    f.Size = UDim2.new(1, 0, 0, 26)
    f.Position = UDim2.new(0, 0, 0, y)
    f.BackgroundColor3 = Color3.fromRGB(10, 16, 28)
    f.BorderSizePixel = 0
    f.Parent = parent
    Instance.new("UICorner", f).CornerRadius = UDim.new(0, 6)

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(0.5, 0, 1, 0)
    lbl.Position = UDim2.new(0, 8, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = label
    lbl.TextColor3 = Color3.fromRGB(100, 140, 200)
    lbl.TextSize = 10
    lbl.Font = Enum.Font.GothamBold
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = f

    local val = Instance.new("TextLabel")
    val.Size = UDim2.new(0.48, 0, 1, 0)
    val.Position = UDim2.new(0.52, 0, 0, 0)
    val.BackgroundTransparency = 1
    val.Text = "..."
    val.TextColor3 = Color3.fromRGB(30, 180, 255)
    val.TextSize = 10
    val.Font = Enum.Font.GothamBold
    val.TextXAlignment = Enum.TextXAlignment.Right
    val.Parent = f
    return val
end

-- ===================== BUILD TABS =====================

-- MAIN TAB
local mTab = pages["Main"]
mkLabel(mTab, 0, "SURVIVAL")
mkToggle(mTab, 14, "God Mode", function(on) godMode = on setStatus(on and "God Mode ON" or "OFF") end)
mkToggle(mTab, 56, "Auto Eat / Drink", function(on) autoEat = on setStatus(on and "Auto Eat ON" or "OFF") end)
mkToggle(mTab, 98, "Auto Repair Boat", function(on) autoRepair = on setStatus(on and "Auto Repair ON" or "OFF") end)
mkLabel(mTab, 148, "BOAT")
mkToggle(mTab, 162, "Speed Boat", function(on) speedBoat = on setStatus(on and "Speed Boat ON" or "OFF") end)
mkSlider(mTab, 204, "Boat Speed", 10, 200, 50, function(val) boatSpeed = val end)
mkLabel(mTab, 260, "ITEMS")
mkToggle(mTab, 274, "Auto Open Chests", function(on) autoChest = on setStatus(on and "Auto Chest ON" or "OFF") end)
mkToggle(mTab, 316, "Auto Sack Items", function(on) autoSack = on setStatus(on and "Auto Sack ON" or "OFF") end)

-- COMBAT TAB
local cTab = pages["Combat"]
mkLabel(cTab, 0, "KILL AURA  (Equips Machete, swings at NPCs)")
mkToggle(cTab, 14, "Kill Aura", function(on)
    killAura = on
    setStatus(on and "Kill Aura ON - Machete equipped" or "Kill Aura OFF")
end)

mkLabel(cTab, 60, "AUTO HARPOON  (Equips Harpoon, targets sea creatures)")
mkToggle(cTab, 74, "Auto Harpoon", function(on)
    autoHarpoon = on
    setStatus(on and "Auto Harpoon ON" or "Auto Harpoon OFF")
end)

mkLabel(cTab, 120, "AUTO FISH  (Equips Fishing Rod, fishes automatically)")
mkToggle(cTab, 134, "Auto Fish", function(on)
    autoFish = on
    setStatus(on and "Auto Fish ON - equipping rod" or "Auto Fish OFF")
end)

-- VISUAL TAB
local vTab = pages["Visual"]
mkLabel(vTab, 0, "ITEM ESP  (Low perf impact - uses event-based tracking)")
mkToggle(vTab, 14, "Item ESP", function(on)
    itemEsp = on
    if not on then clearESP() end
    setStatus(on and "Item ESP ON" or "Item ESP OFF")
end)

-- INFO TAB
local iTab = pages["Info"]
mkLabel(iTab, 0, "SERVER INFO")
local infoKeys = {"Server ID","Players","Position","Health","Ping","Day","Server Time","Map Seed"}
local infoRows = {}
for i, k in ipairs(infoKeys) do
    infoRows[k] = mkInfoRow(iTab, 14 + (i-1)*30, k)
end
mkToggle(iTab, 14 + #infoKeys*30 + 4, "Auto Refresh", function(on)
    serverInfo = on
    setStatus(on and "Server Info refreshing" or "Server Info OFF")
end)

-- ===================== ITEM ESP (event-based, no scan loop) =====================

local espObjects = {}

local function addESP(part, name)
    if espObjects[part] then return end
    local ok, box = pcall(function()
        local b = Instance.new("SelectionBox")
        b.Color3 = Color3.fromRGB(30, 200, 255)
        b.LineThickness = 0.05
        b.SurfaceTransparency = 0.82
        b.SurfaceColor3 = Color3.fromRGB(30, 200, 255)
        b.Adornee = part
        b.Parent = workspace
        return b
    end)
    local ok2, bb = pcall(function()
        local g = Instance.new("BillboardGui")
        g.Size = UDim2.new(0, 110, 0, 18)
        g.StudsOffset = Vector3.new(0, 3, 0)
        g.AlwaysOnTop = true
        g.Adornee = part
        g.Parent = sg
        local t = Instance.new("TextLabel")
        t.Size = UDim2.new(1, 0, 1, 0)
        t.BackgroundTransparency = 1
        t.Text = name
        t.TextColor3 = Color3.fromRGB(30, 200, 255)
        t.TextSize = 11
        t.Font = Enum.Font.GothamBold
        t.TextStrokeTransparency = 0.3
        t.Parent = g
        return g
    end)
    espObjects[part] = {box = ok and box or nil, bb = ok2 and bb or nil}
end

function clearESP()
    for _, t in pairs(espObjects) do
        pcall(function() if t.box then t.box:Destroy() end end)
        pcall(function() if t.bb  then t.bb:Destroy()  end end)
    end
    espObjects = {}
end

-- Use DescendantAdded instead of scanning every frame
workspace.DescendantAdded:Connect(function(obj)
    if not itemEsp then return end
    task.wait(0.1) -- small settle
    if not obj or not obj.Parent then return end
    if obj:FindFirstChildWhichIsA("Humanoid") then return end
    local n = string.lower(obj.Name)
    local isItem = false
    for _, kw in ipairs(ITEM_TAGS) do
        if n:find(kw, 1, true) then isItem = true break end
    end
    if not isItem then
        for _, kw in ipairs(CHEST_TAGS) do
            if n:find(kw, 1, true) then isItem = true break end
        end
    end
    if isItem then
        local part = obj:IsA("BasePart") and obj or obj:FindFirstChildWhichIsA("BasePart")
        if part then addESP(part, obj.Name) end
    end
end)

workspace.DescendantRemoving:Connect(function(obj)
    if espObjects[obj] then
        pcall(function() if espObjects[obj].box then espObjects[obj].box:Destroy() end end)
        pcall(function() if espObjects[obj].bb  then espObjects[obj].bb:Destroy()  end end)
        espObjects[obj] = nil
    end
end)

-- ===================== FEATURE LOOPS =====================

-- GOD MODE (every frame - lightweight)
local function doGodMode()
    if not godMode then return end
    pcall(function()
        local h = getHum()
        if h then h.Health = h.MaxHealth end
    end)
end

-- KILL AURA: equip Machete, find nearest NPC, aim + swing every 0.4s
local kaTimer = 0
local function doKillAura(dt)
    if not killAura then return end
    kaTimer += dt
    if kaTimer < 0.35 then return end
    kaTimer = 0

    local hrp = getHRP()
    if not hrp then return end

    -- Equip Machete if not already
    local char = player.Character
    local tool = char and char:FindFirstChild(TOOL_MACHETE)
    if not tool then
        tool = equipTool(TOOL_MACHETE)
        if not tool then return end
    end

    -- Find nearest NPC from cache
    local best, bestDist = nil, math.huge
    for _, npc in ipairs(cachedNPCs) do
        if npc and npc.Parent then
            local root = npc:FindFirstChild("HumanoidRootPart") or npc:FindFirstChildWhichIsA("BasePart")
            if root then
                local dist = (hrp.Position - root.Position).Magnitude
                if dist < 30 and dist < bestDist then
                    local hum = npc:FindFirstChildWhichIsA("Humanoid")
                    if hum and hum.Health > 0 then
                        best = {npc=npc, root=root, hum=hum}
                        bestDist = dist
                    end
                end
            end
        end
    end

    if best then
        -- Aim camera at enemy
        pcall(function()
            Camera.CFrame = CFrame.lookAt(Camera.CFrame.Position, best.root.Position)
        end)
        -- Swing tool (activate)
        activateTool(tool)
        -- Touch attack
        pcall(function() sFire(hrp, best.root, 0) end)
        pcall(function() sFire(hrp, best.root, 1) end)
        -- Direct damage fallback
        pcall(function() best.hum:TakeDamage(10) end)
        setStatus("Kill Aura: " .. best.npc.Name .. " (" .. math.floor(bestDist) .. "m)")
    end
end

-- AUTO HARPOON: equip Harpoon, find nearest sea creature, aim + fire every 1.5s
local harpTimer = 0
local function doAutoHarpoon(dt)
    if not autoHarpoon then return end
    harpTimer += dt
    if harpTimer < 1.2 then return end
    harpTimer = 0

    local hrp = getHRP()
    if not hrp then return end

    -- Equip Harpoon
    local char = player.Character
    local tool = char and char:FindFirstChild(TOOL_HARPOON)
    if not tool then
        tool = equipTool(TOOL_HARPOON)
        if not tool then return end
        task.wait(0.15)
    end

    -- Find nearest NPC from cache
    local best, bestDist = nil, math.huge
    for _, npc in ipairs(cachedNPCs) do
        if npc and npc.Parent then
            local root = npc:FindFirstChild("HumanoidRootPart") or npc:FindFirstChildWhichIsA("BasePart")
            if root then
                local dist = (hrp.Position - root.Position).Magnitude
                if dist < 80 and dist < bestDist then
                    local hum = npc:FindFirstChildWhichIsA("Humanoid")
                    if hum and hum.Health > 0 then
                        best = root
                        bestDist = dist
                    end
                end
            end
        end
    end

    if best then
        -- Aim camera directly at target
        pcall(function()
            Camera.CFrame = CFrame.lookAt(Camera.CFrame.Position, best.Position)
        end)
        task.wait(0.05)
        -- Fire harpoon
        activateTool(tool)
        setStatus("Harpoon fired at target (" .. math.floor(bestDist) .. "m)")
    end
end

-- AUTO FISH: equip rod, cast, wait for bite UI, reel, repeat
local fishState  = "idle"  -- idle / casting / waiting / reeling
local fishTimer  = 0
local function doAutoFish(dt)
    if not autoFish then fishState = "idle" return end
    fishTimer += dt

    local char = player.Character
    local hrp  = getHRP()
    if not hrp then return end

    -- Equip Fishing Rod
    local rod = char and char:FindFirstChild(TOOL_ROD)
    if not rod then
        if fishTimer > 1 then
            rod = equipTool(TOOL_ROD)
            fishTimer = 0
        end
        return
    end

    if fishState == "idle" or fishState == "casting" then
        if fishTimer > 1.5 then
            -- Cast the rod by activating
            activateTool(rod)
            fireRemote("cast")
            fireRemote("fish")
            clickGuiBtn("cast")
            clickGuiBtn("fish")
            fishState = "waiting"
            fishTimer = 0
            setStatus("Auto Fish: line cast, waiting for bite...")
        end

    elseif fishState == "waiting" then
        -- Look for bite indicator in PlayerGui
        local bitDetected = false
        for _, gui in ipairs(player.PlayerGui:GetChildren()) do
            for _, d in ipairs(gui:GetDescendants()) do
                local t = string.lower(d.Text or "")
                if t:find("bite") or t:find("reel") or t:find("catch") or t:find("got") or t:find("press") then
                    bitDetected = true
                    break
                end
            end
            if bitDetected then break end
        end

        if bitDetected or fishTimer > 12 then
            -- Reel in
            fishState = "reeling"
            fishTimer = 0
        end

    elseif fishState == "reeling" then
        -- Spam reel/activate to catch fish
        activateTool(rod)
        fireRemote("reel")
        fireRemote("catch")
        clickGuiBtn("reel")
        clickGuiBtn("catch")
        setStatus("Auto Fish: reeling in!")

        if fishTimer > 2 then
            fishState = "idle"
            fishTimer = 0
            setStatus("Auto Fish: caught! Casting again...")
        end
    end
end

-- SPEED BOAT (every frame - lightweight)
local function doSpeedBoat()
    if not speedBoat then return end
    local hrp = getHRP()
    if not hrp then return end
    pcall(function()
        for _, obj in ipairs(workspace:GetDescendants()) do
            if obj:IsA("VehicleSeat") and obj.Occupant then
                if player.Character and obj.Occupant.Parent == player.Character then
                    obj.MaxSpeed = boatSpeed
                    obj.Throttle = 1
                    return
                end
            end
        end
    end)
end

-- AUTO EAT (runs every 2s)
local eatTimer = 0
local function doAutoEat(dt)
    if not autoEat then return end
    eatTimer += dt
    if eatTimer < 2 then return end
    eatTimer = 0
    fireRemote("eat")
    fireRemote("drink")
    fireRemote("consume")
    clickGuiBtn("eat")
    clickGuiBtn("drink")
end

-- AUTO CHEST (runs every 2s, uses cache)
local chestTimer = 0
local function doAutoChest(dt)
    if not autoChest then return end
    chestTimer += dt
    if chestTimer < 2 then return end
    chestTimer = 0
    local hrp = getHRP()
    if not hrp then return end
    for _, entry in ipairs(cachedChests) do
        if entry.part and entry.part.Parent then
            local dist = (hrp.Position - entry.part.Position).Magnitude
            if dist < 50 then
                pcall(function() hrp.CFrame = entry.part.CFrame * CFrame.new(0, 3, 0) end)
                task.wait(0.15)
                fireAllPrompts(entry.obj)
                sFire(hrp, entry.part, 0)
                sFire(hrp, entry.part, 1)
                fireRemote("open")
                fireRemote("loot")
                task.wait(0.3)
                setStatus("Opened chest: " .. entry.obj.Name)
            end
        end
    end
end

-- AUTO SACK (runs every 1.5s, uses cache)
local sackTimer = 0
local function doAutoSack(dt)
    if not autoSack then return end
    sackTimer += dt
    if sackTimer < 1.5 then return end
    sackTimer = 0
    local hrp = getHRP()
    if not hrp then return end

    -- Also equip Old Sack if nearby items found
    local char = player.Character
    local sackTool = char and char:FindFirstChild(TOOL_SACK)

    for _, entry in ipairs(cachedItems) do
        if entry.part and entry.part.Parent then
            local dist = (hrp.Position - entry.part.Position).Magnitude
            if dist < 15 then
                sFire(hrp, entry.part, 0)
                sFire(hrp, entry.part, 1)
                fireAllPrompts(entry.obj)
                if sackTool then activateTool(sackTool) end
                fireRemote("pickup")
                fireRemote("collect")
                fireRemote("sack")
            end
        end
    end
end

-- AUTO REPAIR (runs every 3s)
local repairTimer = 0
local function doAutoRepair(dt)
    if not autoRepair then return end
    repairTimer += dt
    if repairTimer < 3 then return end
    repairTimer = 0
    local hrp = getHRP()
    if not hrp then return end
    for _, obj in ipairs(workspace:GetDescendants()) do
        local n = string.lower(obj.Name)
        if n:find("hull",1,true) or n:find("plank",1,true) or n:find("mast",1,true) then
            local part = obj:IsA("BasePart") and obj or obj:FindFirstChildWhichIsA("BasePart")
            if part and (hrp.Position - part.Position).Magnitude < 20 then
                fireAllPrompts(obj)
                fireRemote("repair")
                fireRemote("fix")
            end
        end
    end
end

-- SERVER INFO (runs every 2s)
local infoTimer = 0
local function doServerInfo(dt)
    if not serverInfo then return end
    infoTimer += dt
    if infoTimer < 2 then return end
    infoTimer = 0

    pcall(function() infoRows["Server ID"].Text = game.JobId ~= "" and game.JobId:sub(1,10).."…" or "Private" end)
    pcall(function() infoRows["Players"].Text = #Players:GetPlayers() .. "/" .. Players.MaxPlayers end)
    pcall(function()
        local hrp = getHRP()
        if hrp then
            local p = hrp.Position
            infoRows["Position"].Text = string.format("%.0f,%.0f,%.0f", p.X, p.Y, p.Z)
        end
    end)
    pcall(function()
        local h = getHum()
        if h then infoRows["Health"].Text = math.floor(h.Health) .. "/" .. math.floor(h.MaxHealth) end
    end)
    pcall(function()
        local s = game:GetService("Stats")
        infoRows["Ping"].Text = math.floor(s.Network.ServerStatsItem["Data Ping"]:GetValue()) .. "ms"
    end)
    pcall(function()
        infoRows["Server Time"].Text = string.format("%.0fs", workspace.DistributedGameTime)
    end)
    pcall(function()
        for _, obj in ipairs(workspace:GetDescendants()) do
            if (obj:IsA("IntValue") or obj:IsA("NumberValue")) and
               string.lower(obj.Name):find("day",1,true) then
                infoRows["Day"].Text = tostring(obj.Value) break
            end
        end
    end)
    pcall(function()
        for _, gui in ipairs(player.PlayerGui:GetChildren()) do
            for _, d in ipairs(gui:GetDescendants()) do
                local seed = (d.Text or ""):match("Map Seed:%s*(%d+)")
                if seed then infoRows["Map Seed"].Text = seed return end
            end
        end
    end)
end

-- ===================== MASTER HEARTBEAT =====================
-- Only god mode, kill aura, harpoon, fish run every frame
-- Everything else is rate-limited internally

local scanTimer = 0
RunService.Heartbeat:Connect(function(dt)
    -- Refresh workspace cache every SCAN_INTERVAL seconds
    scanTimer += dt
    if scanTimer >= SCAN_INTERVAL then
        scanTimer = 0
        pcall(refreshCache)
    end

    -- Every frame (lightweight)
    pcall(doGodMode)
    pcall(doSpeedBoat)

    -- Rate-limited internally
    pcall(doKillAura, dt)
    pcall(doAutoHarpoon, dt)
    pcall(doAutoFish, dt)
    pcall(doAutoEat, dt)
    pcall(doAutoChest, dt)
    pcall(doAutoSack, dt)
    pcall(doAutoRepair, dt)
    pcall(doServerInfo, dt)
end)

-- Initial cache
pcall(refreshCache)

print("[100 Days at Sea Hub v2] Loaded.")
setStatus("Loaded. No lag mode active.")
