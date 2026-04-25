repeat task.wait() until game:IsLoaded() and game.Players.LocalPlayer

local Players   = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Camera    = workspace.CurrentCamera
local player    = Players.LocalPlayer

-- ===================== SAFE EXECUTOR WRAPPERS =====================
-- These functions only exist in exploit executors, not plain LocalScripts
-- Wrapping them prevents "attempt to call a nil value" crashes

local function safeTouchInterest(hrp, part, toggle)
    if typeof(firetouchinterest) == "function" then
        pcall(firetouchinterest, hrp, part, toggle)
    end
end

local function safeProximityPrompt(prompt)
    if typeof(fireproximityprompt) == "function" then
        pcall(fireproximityprompt, prompt)
    end
end

local function safeClickDetector(det)
    if typeof(fireclickdetector) == "function" then
        pcall(fireclickdetector, det)
    end
end

local function safeSetQuality(level)
    pcall(function()
        if settings then
            settings().Rendering.QualityLevel = level
        end
    end)
end

-- ===================== STATE =====================

local killAuraEnabled    = false
local killAuraRadius     = 30
local autoChestEnabled   = false
local autoSackEnabled    = false
local itemEspEnabled     = false
local autoFishEnabled    = false
local autoHarpoonEnabled = false
local autoRepairEnabled  = false
local speedBoatEnabled   = false
local godModeEnabled     = false
local autoEatEnabled     = false
local serverInfoEnabled  = false
local boatSpeed          = 50

local itemEspObjects = {}

local NPC_KEYWORDS = {
    "enemy","monster","shark","creature","beast","crab","octopus","eel",
    "siren","leviathan","pirate","bandit","hostile","mob","npc","zombie",
    "ghost","skeleton","seacreature","anglerfish","kraken","serpent","mutant"
}
local ITEM_KEYWORDS = {
    "chest","sack","loot","drop","treasure","fish","item","pickup","crate",
    "barrel","supply","coin","gold","wood","plank","rope","sail","food",
    "meat","bread","water","flask","potion","harpoon","bait","hook","ore",
    "material","resource","pearl","collectible"
}
local CHEST_KEYWORDS   = {"chest","treasure","crate","barrel"}
local SACK_KEYWORDS    = {"sack","bag","drop","pickup","loot","supply"}
local REPAIR_KEYWORDS  = {"hull","plank","mast","sail","deck"}
local FISH_KEYWORDS    = {"fishingspot","fishspot","bobber","fishrod"}
local HARPOON_KEYWORDS = {"harpoontarget","whale","bigfish","kraken","leviathan"}

-- ===================== HELPERS =====================

local function getHRP()
    local c = player.Character
    return c and c:FindFirstChild("HumanoidRootPart")
end

local function getHum()
    local c = player.Character
    return c and c:FindFirstChildWhichIsA("Humanoid")
end

local function nameMatch(name, keywords)
    local n = string.lower(name)
    for _, kw in ipairs(keywords) do
        if n:find(kw, 1, true) then return true end
    end
    return false
end

local function isNPC(model)
    if not model:IsA("Model") then return false end
    local hum = model:FindFirstChildWhichIsA("Humanoid")
    if not hum then return false end
    for _, p in ipairs(Players:GetPlayers()) do
        if p.Character == model then return false end
    end
    return true
end

local function touchPart(part)
    local hrp = getHRP()
    if not hrp or not part then return end
    safeTouchInterest(hrp, part, 0)
    safeTouchInterest(hrp, part, 1)
end

local function fireAllPrompts(obj)
    if not obj then return end
    for _, d in ipairs(obj:GetDescendants()) do
        if d:IsA("ProximityPrompt") then
            safeProximityPrompt(d)
        end
        if d:IsA("ClickDetector") then
            safeClickDetector(d)
        end
    end
    -- also check obj itself
    if obj:IsA("ProximityPrompt") then safeProximityPrompt(obj) end
    if obj:IsA("ClickDetector")   then safeClickDetector(obj)   end
end

local function fireRemoteNamed(pattern, ...)
    local args = {...}
    for _, obj in ipairs(game:GetDescendants()) do
        if obj:IsA("RemoteEvent") then
            if string.lower(obj.Name):find(string.lower(pattern), 1, true) then
                pcall(function() obj:FireServer(table.unpack(args)) end)
            end
        end
    end
end

local function clickGuiBtn(pattern)
    for _, gui in ipairs(player.PlayerGui:GetChildren()) do
        for _, d in ipairs(gui:GetDescendants()) do
            if (d:IsA("TextButton") or d:IsA("ImageButton")) and d.Visible then
                local t = string.lower(d.Text or "")
                if t:find(string.lower(pattern), 1, true) then
                    pcall(function()
                        d.MouseButton1Down:Fire()
                        task.wait(0.04)
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
    local function setState(state)
        on = state
        swBg.BackgroundColor3 = on and Color3.fromRGB(20,100,255) or Color3.fromRGB(18,28,50)
        knob.Position = on and UDim2.new(0,19,0.5,-7) or UDim2.new(0,3,0.5,-7)
        knob.BackgroundColor3 = on and Color3.fromRGB(255,255,255) or Color3.fromRGB(40,70,120)
    end

    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 1, 0)
    btn.BackgroundTransparency = 1
    btn.Text = ""
    btn.Parent = row
    btn.MouseButton1Click:Connect(function()
        setState(not on)
        cb(on)
    end)
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
    thumb.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    thumb.Text = ""
    thumb.BorderSizePixel = 0
    thumb.Parent = track
    Instance.new("UICorner", thumb).CornerRadius = UDim.new(1, 0)

    local dragging = false
    thumb.MouseButton1Down:Connect(function() dragging = true end)
    UserInputService.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1
        or i.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
    local function update(inputX)
        local rel = math.clamp((inputX - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
        local val = math.floor(min + rel*(max-min))
        fill.Size = UDim2.new(rel, 0, 1, 0)
        thumb.Position = UDim2.new(rel, -7, 0.5, -7)
        valLbl.Text = tostring(val)
        cb(val)
    end
    UserInputService.InputChanged:Connect(function(i)
        if dragging then update(i.Position.X) end
    end)
    track.InputBegan:Connect(function(i) update(i.Position.X) end)
end

local function mkInfoRow(parent, y, label)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 0, 26)
    frame.Position = UDim2.new(0, 0, 0, y)
    frame.BackgroundColor3 = Color3.fromRGB(10, 16, 28)
    frame.BorderSizePixel = 0
    frame.Parent = parent
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 6)

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(0.5, 0, 1, 0)
    lbl.Position = UDim2.new(0, 8, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = label
    lbl.TextColor3 = Color3.fromRGB(100, 140, 200)
    lbl.TextSize = 10
    lbl.Font = Enum.Font.GothamBold
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = frame

    local val = Instance.new("TextLabel")
    val.Size = UDim2.new(0.48, 0, 1, 0)
    val.Position = UDim2.new(0.52, 0, 0, 0)
    val.BackgroundTransparency = 1
    val.Text = "..."
    val.TextColor3 = Color3.fromRGB(30, 180, 255)
    val.TextSize = 10
    val.Font = Enum.Font.GothamBold
    val.TextXAlignment = Enum.TextXAlignment.Right
    val.Parent = frame
    return val
end

-- ===================== MAIN TAB =====================

local mTab = pages["Main"]
mkLabel(mTab, 0, "SURVIVAL")

mkToggle(mTab, 14, "God Mode", function(on)
    godModeEnabled = on
    setStatus(on and "God Mode ON" or "God Mode OFF")
end)

mkToggle(mTab, 56, "Auto Eat / Drink", function(on)
    autoEatEnabled = on
    setStatus(on and "Auto Eat ON" or "Auto Eat OFF")
end)

mkToggle(mTab, 98, "Auto Repair Boat", function(on)
    autoRepairEnabled = on
    setStatus(on and "Auto Repair ON" or "Auto Repair OFF")
end)

mkLabel(mTab, 148, "BOAT")

mkToggle(mTab, 162, "Speed Boat", function(on)
    speedBoatEnabled = on
    setStatus(on and "Speed Boat ON" or "Speed Boat OFF")
end)

mkSlider(mTab, 204, "Boat Speed", 10, 200, 50, function(val)
    boatSpeed = val
    setStatus("Boat speed: " .. val)
end)

mkLabel(mTab, 260, "ITEMS")

mkToggle(mTab, 274, "Auto Open Chests", function(on)
    autoChestEnabled = on
    setStatus(on and "Auto Chest ON" or "Auto Chest OFF")
end)

mkToggle(mTab, 316, "Auto Sack Items", function(on)
    autoSackEnabled = on
    setStatus(on and "Auto Sack ON" or "Auto Sack OFF")
end)

-- ===================== COMBAT TAB =====================

local cTab = pages["Combat"]
mkLabel(cTab, 0, "COMBAT - NPC / MONSTERS ONLY")

mkToggle(cTab, 14, "Kill Aura", function(on)
    killAuraEnabled = on
    setStatus(on and "Kill Aura ON" or "Kill Aura OFF")
end)

mkSlider(cTab, 56, "Aura Radius", 5, 150, 30, function(val)
    killAuraRadius = val
end)

mkLabel(cTab, 112, "FISHING")

mkToggle(cTab, 126, "Auto Fish", function(on)
    autoFishEnabled = on
    setStatus(on and "Auto Fish ON" or "Auto Fish OFF")
end)

mkToggle(cTab, 168, "Auto Harpoon", function(on)
    autoHarpoonEnabled = on
    setStatus(on and "Auto Harpoon ON" or "Auto Harpoon OFF")
end)

-- ===================== VISUAL TAB =====================

local vTab = pages["Visual"]
mkLabel(vTab, 0, "ITEM ESP")

mkToggle(vTab, 14, "Item ESP", function(on)
    itemEspEnabled = on
    if not on then
        for _, t in pairs(itemEspObjects) do
            pcall(function()
                if t.box then t.box:Destroy() end
                if t.bb  then t.bb:Destroy()  end
            end)
        end
        itemEspObjects = {}
    end
    setStatus(on and "Item ESP ON" or "Item ESP OFF")
end)

-- ===================== INFO TAB =====================

local iTab = pages["Info"]
mkLabel(iTab, 0, "SERVER INFO")

local infoLabels = {"Server ID","Players","Your Position","Your Health","Ping","Server Time","Day","Map Seed"}
local infoRows   = {}
for i, lbl in ipairs(infoLabels) do
    infoRows[lbl] = mkInfoRow(iTab, 14 + (i-1)*30, lbl)
end

mkToggle(iTab, 14 + #infoLabels*30 + 6, "Auto Refresh", function(on)
    serverInfoEnabled = on
    setStatus(on and "Server Info ON" or "Server Info OFF")
end)

-- ===================== ITEM ESP LOGIC =====================

local function updateItemESP()
    if not itemEspEnabled then return end
    for _, obj in ipairs(workspace:GetDescendants()) do
        if not obj:FindFirstChildWhichIsA("Humanoid") then
            local n = string.lower(obj.Name)
            local isItem = false
            for _, kw in ipairs(ITEM_KEYWORDS) do
                if n:find(kw, 1, true) then isItem = true break end
            end
            if isItem then
                local part = obj:IsA("BasePart") and obj or obj:FindFirstChildWhichIsA("BasePart")
                if part and not itemEspObjects[part] then
                    local ok, box = pcall(function()
                        local b = Instance.new("SelectionBox")
                        b.Color3 = Color3.fromRGB(30, 200, 255)
                        b.LineThickness = 0.05
                        b.SurfaceTransparency = 0.8
                        b.SurfaceColor3 = Color3.fromRGB(30, 200, 255)
                        b.Adornee = part
                        b.Parent = workspace
                        return b
                    end)
                    local ok2, bb = pcall(function()
                        local gui = Instance.new("BillboardGui")
                        gui.Size = UDim2.new(0, 120, 0, 20)
                        gui.StudsOffset = Vector3.new(0, 3, 0)
                        gui.AlwaysOnTop = true
                        gui.Adornee = part
                        gui.Parent = sg
                        local tag = Instance.new("TextLabel")
                        tag.Size = UDim2.new(1, 0, 1, 0)
                        tag.BackgroundTransparency = 1
                        tag.Text = obj.Name
                        tag.TextColor3 = Color3.fromRGB(30, 200, 255)
                        tag.TextSize = 11
                        tag.Font = Enum.Font.GothamBold
                        tag.TextStrokeTransparency = 0.4
                        tag.Parent = gui
                        return gui
                    end)
                    itemEspObjects[part] = {
                        box = ok and box or nil,
                        bb  = ok2 and bb or nil
                    }
                end
            end
        end
    end
    -- cleanup
    for part, t in pairs(itemEspObjects) do
        if not part or not part.Parent then
            pcall(function() if t.box then t.box:Destroy() end end)
            pcall(function() if t.bb  then t.bb:Destroy()  end end)
            itemEspObjects[part] = nil
        end
    end
end

-- ===================== FEATURE LOGIC =====================

local function doGodMode()
    if not godModeEnabled then return end
    pcall(function()
        local hum = getHum()
        if hum then hum.Health = hum.MaxHealth end
    end)
end

local function doAutoEat()
    if not autoEatEnabled then return end
    fireRemoteNamed("eat")
    fireRemoteNamed("drink")
    fireRemoteNamed("consume")
    fireRemoteNamed("hunger")
    fireRemoteNamed("thirst")
    clickGuiBtn("eat")
    clickGuiBtn("drink")
    local hrp = getHRP()
    if not hrp then return end
    for _, obj in ipairs(workspace:GetDescendants()) do
        local n = string.lower(obj.Name)
        if n:find("food",1,true) or n:find("water",1,true) or n:find("drink",1,true)
        or n:find("apple",1,true) or n:find("meat",1,true) or n:find("bread",1,true) then
            local part = obj:IsA("BasePart") and obj or obj:FindFirstChildWhichIsA("BasePart")
            if part and (hrp.Position - part.Position).Magnitude < 12 then
                touchPart(part)
                fireAllPrompts(obj)
            end
        end
    end
end

local function doKillAura()
    if not killAuraEnabled then return end
    local hrp = getHRP()
    if not hrp then return end
    for _, obj in ipairs(workspace:GetDescendants()) do
        if isNPC(obj) then
            local root = obj:FindFirstChild("HumanoidRootPart")
                or obj:FindFirstChildWhichIsA("BasePart")
            if root and (hrp.Position - root.Position).Magnitude <= killAuraRadius then
                local hum = obj:FindFirstChildWhichIsA("Humanoid")
                if hum and hum.Health > 0 then
                    pcall(function() hum:TakeDamage(9999) end)
                    touchPart(root)
                    fireRemoteNamed("attack")
                    fireRemoteNamed("hit")
                    fireRemoteNamed("damage")
                end
            end
        end
    end
end

local function doAutoChest()
    if not autoChestEnabled then return end
    local hrp = getHRP()
    if not hrp then return end
    for _, obj in ipairs(workspace:GetDescendants()) do
        if nameMatch(obj.Name, CHEST_KEYWORDS) then
            local part = obj:IsA("BasePart") and obj or obj:FindFirstChildWhichIsA("BasePart")
            if part and (hrp.Position - part.Position).Magnitude < 40 then
                -- TP close to it
                pcall(function() hrp.CFrame = part.CFrame * CFrame.new(0, 3, 0) end)
                task.wait(0.1)
                fireAllPrompts(obj)
                touchPart(part)
                fireRemoteNamed("openchest")
                fireRemoteNamed("open")
                fireRemoteNamed("loot")
                task.wait(0.2)
            end
        end
    end
end

local function doAutoSack()
    if not autoSackEnabled then return end
    local hrp = getHRP()
    if not hrp then return end
    for _, obj in ipairs(workspace:GetDescendants()) do
        if nameMatch(obj.Name, SACK_KEYWORDS) and not obj:FindFirstChildWhichIsA("Humanoid") then
            local part = obj:IsA("BasePart") and obj or obj:FindFirstChildWhichIsA("BasePart")
            if part and (hrp.Position - part.Position).Magnitude < 20 then
                touchPart(part)
                fireAllPrompts(obj)
                fireRemoteNamed("pickup")
                fireRemoteNamed("collect")
                fireRemoteNamed("sack")
                fireRemoteNamed("grab")
            end
        end
    end
end

local function doAutoRepair()
    if not autoRepairEnabled then return end
    local hrp = getHRP()
    if not hrp then return end
    for _, obj in ipairs(workspace:GetDescendants()) do
        if nameMatch(obj.Name, REPAIR_KEYWORDS) then
            local part = obj:IsA("BasePart") and obj or obj:FindFirstChildWhichIsA("BasePart")
            if part and (hrp.Position - part.Position).Magnitude < 25 then
                touchPart(part)
                fireAllPrompts(obj)
                fireRemoteNamed("repair")
                fireRemoteNamed("fix")
                fireRemoteNamed("patch")
            end
        end
    end
end

local function doSpeedBoat()
    if not speedBoatEnabled then return end
    local hrp = getHRP()
    if not hrp then return end
    pcall(function()
        for _, obj in ipairs(workspace:GetDescendants()) do
            if obj:IsA("VehicleSeat") and obj.Occupant then
                local char = player.Character
                if char and obj.Occupant.Parent == char then
                    obj.MaxSpeed = boatSpeed
                    obj.Throttle = 1
                end
            end
            -- BodyVelocity on nearby boat parts
            if obj:IsA("BodyVelocity") then
                local p = obj.Parent
                if p and p:IsA("BasePart") then
                    local n = string.lower(p.Name)
                    if (n:find("boat",1,true) or n:find("ship",1,true) or n:find("raft",1,true) or n:find("hull",1,true))
                    and (hrp.Position - p.Position).Magnitude < 20 then
                        obj.MaxForce = Vector3.new(1e6, 1e6, 1e6)
                        obj.Velocity = p.CFrame.LookVector * boatSpeed
                    end
                end
            end
        end
        fireRemoteNamed("setspeed")
        fireRemoteNamed("boostboat")
    end)
end

local function doAutoFish()
    if not autoFishEnabled then return end
    fireRemoteNamed("castrod")
    fireRemoteNamed("fish")
    fireRemoteNamed("castline")
    fireRemoteNamed("reel")
    fireRemoteNamed("catch")
    clickGuiBtn("fish")
    clickGuiBtn("cast")
    clickGuiBtn("reel")
    local hrp = getHRP()
    if not hrp then return end
    for _, obj in ipairs(workspace:GetDescendants()) do
        if nameMatch(obj.Name, FISH_KEYWORDS) then
            local part = obj:IsA("BasePart") and obj or obj:FindFirstChildWhichIsA("BasePart")
            if part and (hrp.Position - part.Position).Magnitude < 20 then
                fireAllPrompts(obj)
                touchPart(part)
            end
        end
    end
end

local function doAutoHarpoon()
    if not autoHarpoonEnabled then return end
    local hrp = getHRP()
    if not hrp then return end
    local best, bestDist = nil, math.huge
    for _, obj in ipairs(workspace:GetDescendants()) do
        if nameMatch(obj.Name, HARPOON_KEYWORDS) then
            local part = obj:IsA("BasePart") and obj or obj:FindFirstChildWhichIsA("BasePart")
            if part then
                local dist = (hrp.Position - part.Position).Magnitude
                if dist < bestDist then bestDist = dist best = part end
            end
        end
    end
    if best then
        pcall(function()
            Camera.CFrame = CFrame.lookAt(Camera.CFrame.Position, best.Position)
        end)
        fireRemoteNamed("harpoon")
        fireRemoteNamed("throw")
        fireRemoteNamed("shoot")
        touchPart(best)
        setStatus("Harpooning: " .. best.Name .. " (" .. math.floor(bestDist) .. " studs)")
    end
end

local function doServerInfo()
    if not serverInfoEnabled then return end
    pcall(function() infoRows["Server ID"].Text = game.JobId ~= "" and game.JobId:sub(1,10).."…" or "Private" end)
    pcall(function() infoRows["Players"].Text = #Players:GetPlayers() .. "/" .. Players.MaxPlayers end)
    pcall(function()
        local hrp = getHRP()
        if hrp then
            local p = hrp.Position
            infoRows["Your Position"].Text = string.format("%.0f,%.0f,%.0f", p.X, p.Y, p.Z)
        end
    end)
    pcall(function()
        local hum = getHum()
        if hum then
            infoRows["Your Health"].Text = math.floor(hum.Health) .. "/" .. math.floor(hum.MaxHealth)
        end
    end)
    pcall(function()
        local s = game:GetService("Stats")
        local ping = s.Network.ServerStatsItem["Data Ping"]:GetValue()
        infoRows["Ping"].Text = math.floor(ping) .. " ms"
    end)
    pcall(function()
        infoRows["Server Time"].Text = string.format("%.0fs", workspace.DistributedGameTime)
    end)
    pcall(function()
        -- Day counter: search workspace values
        for _, obj in ipairs(workspace:GetDescendants()) do
            if (obj:IsA("IntValue") or obj:IsA("NumberValue")) and string.lower(obj.Name):find("day",1,true) then
                infoRows["Day"].Text = tostring(obj.Value)
                break
            end
        end
    end)
    pcall(function()
        -- Map seed shown in UI bottom right in the screenshot: "Map Seed: 1777103967"
        for _, gui in ipairs(player.PlayerGui:GetChildren()) do
            for _, d in ipairs(gui:GetDescendants()) do
                if d:IsA("TextLabel") then
                    local seed = (d.Text or ""):match("Map Seed:%s*(%d+)")
                    if seed then
                        infoRows["Map Seed"].Text = seed
                        break
                    end
                end
            end
        end
    end)
end

-- ===================== MAIN LOOPS =====================

local ticker = 0
RunService.Heartbeat:Connect(function(dt)
    ticker += dt
    -- Every frame: god mode, kill aura, speed boat
    pcall(doGodMode)
    pcall(doKillAura)
    pcall(doSpeedBoat)

    -- Every 0.5s: everything else
    if ticker >= 0.5 then
        ticker = 0
        pcall(doAutoEat)
        pcall(doAutoChest)
        pcall(doAutoSack)
        pcall(doAutoRepair)
        pcall(doAutoFish)
        pcall(doAutoHarpoon)
        pcall(updateItemESP)
        pcall(doServerInfo)
    end
end)

print("[100 Days at Sea Hub] Loaded successfully.")
setStatus("Loaded. All features ready.")
