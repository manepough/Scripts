repeat task.wait() until game:IsLoaded() and game.Players.LocalPlayer

local Players   = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS       = game:GetService("UserInputService")
local Camera    = workspace.CurrentCamera
local player    = Players.LocalPlayer

-- ===================== SAFE WRAPPERS =====================

local function sFire(a, b, c)
    if type(firetouchinterest) == "function" then
        pcall(firetouchinterest, a, b, c)
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

local godMode        = false
local autoEat        = false
local autoRepair     = false
local speedBoat      = false
local openAllChests  = false
local autoPickUp     = false
local killAura       = false
local autoHarpoon    = false
local autoFish       = false
local itemEsp        = false
local serverInfo     = false
local boatSpeed      = 50
local kaRange        = 20
local kaCooldown     = 0.3  -- seconds between swings

-- Exact tool names from hotbar
local MELEE_TOOLS  = {"Machete", "Knife", "Trident"}
local HARPOON_TOOLS = {"Harpoon", "Riptide"}
local SACK_TOOLS   = {"Giant Sack", "Good Sack", "Old Sack"}
local TOOL_ROD     = "Fishing Rod"

-- ===================== PICKUP / COLLECTIBLE KEYWORDS =====================
-- Very specific — excludes boat parts, dinghy, planks, masts, etc.

local PICKUP_GOOD = {
    "fish","crab","lobster","pearl","coin","gold","ore","coal","scrap",
    "drop","loot","supply","food","meat","bread","apple","berry","flask",
    "potion","collectible","resource","material","item","pickup","sack",
    "chest","crate","barrel","treasure","bait","hook","wood","plank",
    "rope","cloth","leather","bone","shell","egg","seed","herb"
}

local PICKUP_BAD = {
    "dinghy","boat","ship","raft","hull","mast","sail","deck","engine",
    "propeller","rudder","base","spawn","anchor","vehicle","seat","wheel",
    "door","wall","floor","fence","light","lamp","sign","platform",
    "invisible","barrier","blocker","hitbox","region","zone","trigger",
    "player","character","npc","humanoid"
}

local CHEST_GOOD = {"chest","treasure","crate","lootcrate","supplybox","giftbox"}

local NPC_TAGS = {
    "enemy","monster","shark","crab","octopus","eel","pirate","bandit",
    "hostile","mob","zombie","mutant","anglerfish","kraken","serpent",
    "leviathan","siren","seacreature","creature","beast","fish"
}

local BASE_TAGS = {"base","home","storage","dock","island","spawnpoint","spawn","unload"}

-- ===================== HELPERS =====================

local function getHRP()
    local c = player.Character
    return c and c:FindFirstChild("HumanoidRootPart")
end

local function getHum()
    local c = player.Character
    return c and c:FindFirstChildWhichIsA("Humanoid")
end

local function nameGood(name, goodList, badList)
    local n = string.lower(name)
    if badList then
        for _, b in ipairs(badList) do
            if n:find(b, 1, true) then return false end
        end
    end
    for _, g in ipairs(goodList) do
        if n:find(g, 1, true) then return true end
    end
    return false
end

local function isPlayerChar(model)
    for _, p in ipairs(Players:GetPlayers()) do
        if p.Character == model then return true end
    end
    return false
end

local function getBackpack(name)
    local bp = player:FindFirstChild("Backpack")
    if bp then
        for _, t in ipairs(bp:GetChildren()) do
            if t.Name == name then return t end
        end
    end
    local c = player.Character
    if c then
        for _, t in ipairs(c:GetChildren()) do
            if t.Name == name then return t end
        end
    end
    return nil
end

local function equipTool(name)
    local t = getBackpack(name)
    if not t then return nil end
    if t.Parent ~= player.Character then
        t.Parent = player.Character
        task.wait(0.12)
    end
    return player.Character and player.Character:FindFirstChild(name)
end

local function equipAny(list)
    for _, name in ipairs(list) do
        local t = equipTool(name)
        if t then return t, name end
    end
    return nil, nil
end

local function activateTool(tool)
    if tool and tool.Parent then
        pcall(function() tool:Activate() end)
    end
end

local function fireRemote(pattern, ...)
    local args = {...}
    for _, obj in ipairs(game:GetDescendants()) do
        if obj:IsA("RemoteEvent") and
           string.lower(obj.Name):find(pattern, 1, true) then
            pcall(function() obj:FireServer(table.unpack(args)) end)
        end
    end
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

local function touchPart(part)
    local hrp = getHRP()
    if not hrp or not part then return end
    sFire(hrp, part, 0)
    task.wait(0.02)
    sFire(hrp, part, 1)
end

local function tpTo(cf)
    local hrp = getHRP()
    if hrp then
        pcall(function() hrp.CFrame = cf end)
    end
end

-- ===================== CACHE (refresh every 4s) =====================

local cachedNPCs   = {}
local cachedItems  = {}
local cachedChests = {}
local cachedBase   = nil
local scanTimer    = 0
local SCAN_RATE    = 4

local function refreshCache()
    cachedNPCs   = {}
    cachedItems  = {}
    cachedChests = {}

    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("Model") and obj:FindFirstChildWhichIsA("Humanoid") then
            if not isPlayerChar(obj) then
                local root = obj:FindFirstChild("HumanoidRootPart")
                    or obj:FindFirstChildWhichIsA("BasePart")
                if root then
                    cachedNPCs[#cachedNPCs+1] = {model=obj, root=root}
                end
            end
        elseif (obj:IsA("Model") or obj:IsA("BasePart")) and not obj:FindFirstChildWhichIsA("Humanoid") then
            local part = obj:IsA("BasePart") and obj or obj:FindFirstChildWhichIsA("BasePart")
            if part then
                if nameGood(obj.Name, CHEST_GOOD, PICKUP_BAD) then
                    cachedChests[#cachedChests+1] = {obj=obj, part=part}
                elseif nameGood(obj.Name, PICKUP_GOOD, PICKUP_BAD) then
                    cachedItems[#cachedItems+1]  = {obj=obj, part=part}
                end
            end
        end
    end

    -- Find base/storage
    if not cachedBase then
        for _, obj in ipairs(workspace:GetDescendants()) do
            if obj:IsA("BasePart") and nameGood(obj.Name, BASE_TAGS, nil) then
                local dist = obj.Position.Magnitude
                if dist < 2000 then
                    cachedBase = obj.CFrame * CFrame.new(0, 4, 0)
                    break
                end
            end
        end
    end
end

-- ===================== SACK FULL CHECK =====================

local function isSackFull()
    -- Check GUI for "full" text near sack
    for _, gui in ipairs(player.PlayerGui:GetChildren()) do
        for _, d in ipairs(gui:GetDescendants()) do
            local t = string.lower(d.Text or "")
            if t:find("full", 1, true) or t:find("sack full", 1, true) then
                return true
            end
        end
    end
    return false
end

local function unloadSack()
    -- TP to base
    if cachedBase then
        tpTo(cachedBase)
        task.wait(0.5)
    end
    -- Fire unload/drop remotes
    fireRemote("unload")
    fireRemote("store")
    fireRemote("deposit")
    fireRemote("empty")
    -- Touch storage parts
    local hrp = getHRP()
    if hrp then
        for _, obj in ipairs(workspace:GetDescendants()) do
            if obj:IsA("BasePart") and nameGood(obj.Name, {"storage","dock","unload","deposit","chest","box"}, nil) then
                local dist = (hrp.Position - obj.Position).Magnitude
                if dist < 30 then
                    touchPart(obj)
                    fireAllPrompts(obj)
                end
            end
        end
    end
    task.wait(0.5)
end

-- ===================== GUI =====================

local sg = Instance.new("ScreenGui")
sg.Name = "SeaHub"
sg.ResetOnSpawn = false
sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
sg.Parent = player:WaitForChild("PlayerGui")

local win = Instance.new("Frame")
win.Size = UDim2.new(0, 310, 0, 480)
win.Position = UDim2.new(0, 16, 0.5, -240)
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
subLbl.Text = "SCRIPT HUB v3"
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

local tabNames = {"Main","Combat","Visual","Info"}
local tabBtns = {}
local tabWidth = (310-24)/#tabNames

local tabBar = Instance.new("Frame")
tabBar.Size = UDim2.new(1,-24,0,28)
tabBar.Position = UDim2.new(0,12,0,53)
tabBar.BackgroundTransparency = 1
tabBar.Parent = win

for i, name in ipairs(tabNames) do
    local tb = Instance.new("TextButton")
    tb.Size = UDim2.new(0,tabWidth-3,0,26)
    tb.Position = UDim2.new(0,(i-1)*tabWidth,0,0)
    tb.BackgroundColor3 = Color3.fromRGB(10,16,28)
    tb.BorderSizePixel = 0
    tb.Text = name
    tb.TextColor3 = Color3.fromRGB(60,100,160)
    tb.TextSize = 10
    tb.Font = Enum.Font.GothamBold
    tb.Parent = tabBar
    Instance.new("UICorner",tb).CornerRadius = UDim.new(0,6)
    tabBtns[name] = tb
end

mkDiv(win, 86)

local content = Instance.new("Frame")
content.Size = UDim2.new(1,-24,0,352)
content.Position = UDim2.new(0,12,0,93)
content.BackgroundTransparency = 1
content.Parent = win

local statusBar = Instance.new("Frame")
statusBar.Size = UDim2.new(1,-24,0,22)
statusBar.Position = UDim2.new(0,12,0,450)
statusBar.BackgroundColor3 = Color3.fromRGB(5,8,16)
statusBar.BorderSizePixel = 0
statusBar.Parent = win
Instance.new("UICorner",statusBar).CornerRadius = UDim.new(0,5)

local sDot = Instance.new("Frame")
sDot.Size = UDim2.new(0,5,0,5)
sDot.Position = UDim2.new(0,8,0.5,-2)
sDot.BackgroundColor3 = Color3.fromRGB(30,120,255)
sDot.BorderSizePixel = 0
sDot.Parent = statusBar
Instance.new("UICorner",sDot).CornerRadius = UDim.new(1,0)

local sTxt = Instance.new("TextLabel")
sTxt.Size = UDim2.new(1,-22,1,0)
sTxt.Position = UDim2.new(0,18,0,0)
sTxt.BackgroundTransparency = 1
sTxt.Text = "Ready"
sTxt.TextColor3 = Color3.fromRGB(60,100,160)
sTxt.TextSize = 9
sTxt.Font = Enum.Font.Code
sTxt.TextXAlignment = Enum.TextXAlignment.Left
sTxt.Parent = statusBar

local function setStatus(txt) sTxt.Text = "> "..txt end

local pages = {}
for _, name in ipairs(tabNames) do
    local p = Instance.new("Frame")
    p.Size = UDim2.new(1,0,1,0)
    p.BackgroundTransparency = 1
    p.Visible = false
    p.Parent = content
    pages[name] = p
end
pages["Main"].Visible = true

local function switchTab(name)
    for _, n in ipairs(tabNames) do
        pages[n].Visible = (n==name)
        tabBtns[n].BackgroundColor3 = (n==name) and Color3.fromRGB(20,80,200) or Color3.fromRGB(10,16,28)
        tabBtns[n].TextColor3 = (n==name) and Color3.fromRGB(220,235,255) or Color3.fromRGB(60,100,160)
    end
end
switchTab("Main")
for _, n in ipairs(tabNames) do
    tabBtns[n].MouseButton1Click:Connect(function() switchTab(n) end)
end

-- ===================== UI BUILDERS =====================

local function mkLabel(parent, y, text)
    local l = Instance.new("TextLabel")
    l.Size = UDim2.new(1,0,0,14)
    l.Position = UDim2.new(0,0,0,y)
    l.BackgroundTransparency = 1
    l.Text = text
    l.TextColor3 = Color3.fromRGB(40,80,150)
    l.TextSize = 9
    l.Font = Enum.Font.GothamBold
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.Parent = parent
end

local function mkToggle(parent, y, label, cb)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1,0,0,34)
    row.Position = UDim2.new(0,0,0,y)
    row.BackgroundColor3 = Color3.fromRGB(10,16,28)
    row.BorderSizePixel = 0
    row.Parent = parent
    Instance.new("UICorner",row).CornerRadius = UDim.new(0,7)

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1,-60,1,0)
    lbl.Position = UDim2.new(0,10,0,0)
    lbl.BackgroundTransparency = 1
    lbl.Text = label
    lbl.TextColor3 = Color3.fromRGB(180,210,255)
    lbl.TextSize = 12
    lbl.Font = Enum.Font.GothamBold
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = row

    local swBg = Instance.new("Frame")
    swBg.Size = UDim2.new(0,36,0,20)
    swBg.Position = UDim2.new(1,-44,0.5,-10)
    swBg.BackgroundColor3 = Color3.fromRGB(18,28,50)
    swBg.BorderSizePixel = 0
    swBg.Parent = row
    Instance.new("UICorner",swBg).CornerRadius = UDim.new(1,0)

    local knob = Instance.new("Frame")
    knob.Size = UDim2.new(0,14,0,14)
    knob.Position = UDim2.new(0,3,0.5,-7)
    knob.BackgroundColor3 = Color3.fromRGB(40,70,120)
    knob.BorderSizePixel = 0
    knob.Parent = swBg
    Instance.new("UICorner",knob).CornerRadius = UDim.new(1,0)

    local on = false
    local function set(s)
        on = s
        swBg.BackgroundColor3 = on and Color3.fromRGB(20,100,255) or Color3.fromRGB(18,28,50)
        knob.Position = on and UDim2.new(0,19,0.5,-7) or UDim2.new(0,3,0.5,-7)
        knob.BackgroundColor3 = on and Color3.fromRGB(255,255,255) or Color3.fromRGB(40,70,120)
    end

    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1,0,1,0)
    btn.BackgroundTransparency = 1
    btn.Text = ""
    btn.Parent = row
    btn.MouseButton1Click:Connect(function() set(not on) cb(on) end)
    return set
end

local function mkSlider(parent, y, label, min, max, default, cb)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1,0,0,44)
    frame.Position = UDim2.new(0,0,0,y)
    frame.BackgroundColor3 = Color3.fromRGB(10,16,28)
    frame.BorderSizePixel = 0
    frame.Parent = parent
    Instance.new("UICorner",frame).CornerRadius = UDim.new(0,7)

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(0.65,0,0,16)
    lbl.Position = UDim2.new(0,10,0,4)
    lbl.BackgroundTransparency = 1
    lbl.Text = label
    lbl.TextColor3 = Color3.fromRGB(180,210,255)
    lbl.TextSize = 11
    lbl.Font = Enum.Font.GothamBold
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = frame

    local valLbl = Instance.new("TextLabel")
    valLbl.Size = UDim2.new(0.32,0,0,16)
    valLbl.Position = UDim2.new(0.66,0,0,4)
    valLbl.BackgroundTransparency = 1
    valLbl.Text = tostring(default)
    valLbl.TextColor3 = Color3.fromRGB(30,120,255)
    valLbl.TextSize = 11
    valLbl.Font = Enum.Font.GothamBold
    valLbl.TextXAlignment = Enum.TextXAlignment.Right
    valLbl.Parent = frame

    local track = Instance.new("Frame")
    track.Size = UDim2.new(1,-20,0,4)
    track.Position = UDim2.new(0,10,0,30)
    track.BackgroundColor3 = Color3.fromRGB(18,28,50)
    track.BorderSizePixel = 0
    track.Parent = frame
    Instance.new("UICorner",track).CornerRadius = UDim.new(1,0)

    local fill = Instance.new("Frame")
    fill.Size = UDim2.new((default-min)/(max-min),0,1,0)
    fill.BackgroundColor3 = Color3.fromRGB(20,100,255)
    fill.BorderSizePixel = 0
    fill.Parent = track
    Instance.new("UICorner",fill).CornerRadius = UDim.new(1,0)

    local thumb = Instance.new("TextButton")
    thumb.Size = UDim2.new(0,14,0,14)
    thumb.Position = UDim2.new((default-min)/(max-min),-7,0.5,-7)
    thumb.BackgroundColor3 = Color3.fromRGB(255,255,255)
    thumb.Text = ""
    thumb.BorderSizePixel = 0
    thumb.Parent = track
    Instance.new("UICorner",thumb).CornerRadius = UDim.new(1,0)

    local dragging = false
    thumb.MouseButton1Down:Connect(function() dragging = true end)
    UIS.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1
        or i.UserInputType == Enum.UserInputType.Touch then dragging = false end
    end)
    local function update(x)
        local rel = math.clamp((x - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
        local val = math.floor(min + rel*(max-min))
        fill.Size = UDim2.new(rel,0,1,0)
        thumb.Position = UDim2.new(rel,-7,0.5,-7)
        valLbl.Text = tostring(val)
        cb(val)
    end
    UIS.InputChanged:Connect(function(i) if dragging then update(i.Position.X) end end)
    track.InputBegan:Connect(function(i) update(i.Position.X) end)
end

local function mkInfoRow(parent, y, label)
    local f = Instance.new("Frame")
    f.Size = UDim2.new(1,0,0,24)
    f.Position = UDim2.new(0,0,0,y)
    f.BackgroundColor3 = Color3.fromRGB(10,16,28)
    f.BorderSizePixel = 0
    f.Parent = parent
    Instance.new("UICorner",f).CornerRadius = UDim.new(0,5)

    local l = Instance.new("TextLabel")
    l.Size = UDim2.new(0.5,0,1,0)
    l.Position = UDim2.new(0,8,0,0)
    l.BackgroundTransparency = 1
    l.Text = label
    l.TextColor3 = Color3.fromRGB(100,140,200)
    l.TextSize = 10
    l.Font = Enum.Font.GothamBold
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.Parent = f

    local v = Instance.new("TextLabel")
    v.Size = UDim2.new(0.48,0,1,0)
    v.Position = UDim2.new(0.52,0,0,0)
    v.BackgroundTransparency = 1
    v.Text = "..."
    v.TextColor3 = Color3.fromRGB(30,180,255)
    v.TextSize = 10
    v.Font = Enum.Font.GothamBold
    v.TextXAlignment = Enum.TextXAlignment.Right
    v.Parent = f
    return v
end

-- ===================== BUILD TABS =====================

local mTab = pages["Main"]
mkLabel(mTab, 0, "SURVIVAL")
mkToggle(mTab, 14, "God Mode",        function(on) godMode = on    setStatus(on and "God Mode ON" or "OFF") end)
mkToggle(mTab, 56, "Auto Eat/Drink",  function(on) autoEat = on    setStatus(on and "Auto Eat ON" or "OFF") end)
mkToggle(mTab, 98, "Auto Repair",     function(on) autoRepair = on setStatus(on and "Auto Repair ON" or "OFF") end)
mkLabel(mTab, 140, "BOAT")
mkToggle(mTab, 154, "Speed Boat",     function(on) speedBoat = on  setStatus(on and "Speed Boat ON" or "OFF") end)
mkSlider(mTab, 196, "Boat Speed", 10, 200, 50, function(v) boatSpeed = v end)
mkLabel(mTab, 248, "LOOT")
mkToggle(mTab, 262, "Auto Pick Up",   function(on) autoPickUp = on setStatus(on and "Auto Pick Up ON" or "OFF") end)
mkToggle(mTab, 304, "Open All Chests", function(on) openAllChests = on setStatus(on and "Open All Chests ON" or "OFF") end)

local cTab = pages["Combat"]
mkLabel(cTab, 0,  "KILL AURA  (Machete / Knife / Trident - no camera shake)")
mkToggle(cTab, 14,  "Kill Aura", function(on) killAura = on setStatus(on and "Kill Aura ON" or "OFF") end)
mkSlider(cTab, 56,  "Range (studs)", 5, 80, 20,  function(v) kaRange    = v end)
mkSlider(cTab, 108, "Cooldown (0=spam, 10=slow)", 0, 10, 3, function(v) kaCooldown = v * 0.1 end)
mkLabel(cTab,  160, "AUTO HARPOON  (Harpoon + Riptide, targets sea creatures)")
mkToggle(cTab, 174, "Auto Harpoon", function(on) autoHarpoon = on setStatus(on and "Auto Harpoon ON" or "OFF") end)
mkLabel(cTab,  216, "AUTO FISH  (Equips Rod, casts, reels on bite)")
mkToggle(cTab, 230, "Auto Fish", function(on) autoFish = on setStatus(on and "Auto Fish ON" or "OFF") end)

local vTab = pages["Visual"]
mkLabel(vTab, 0, "ITEM ESP  (Pickable / collectible items only)")
mkToggle(vTab, 14, "Item ESP", function(on)
    itemEsp = on
    if not on then
        for _, t in pairs(espObjects) do
            pcall(function() if t.box then t.box:Destroy() end end)
            pcall(function() if t.bb  then t.bb:Destroy()  end end)
        end
        espObjects = {}
    end
    setStatus(on and "Item ESP ON" or "OFF")
end)

local iTab = pages["Info"]
mkLabel(iTab, 0, "SERVER INFO")
local infoKeys = {"Server ID","Players","Position","Health","Ping","Day","Server Time","Map Seed"}
local infoRows = {}
for i, k in ipairs(infoKeys) do infoRows[k] = mkInfoRow(iTab, 14+(i-1)*28, k) end
mkToggle(iTab, 14+#infoKeys*28+4, "Auto Refresh", function(on)
    serverInfo = on setStatus(on and "Info refreshing" or "Info OFF")
end)

-- ===================== ESP (event-based) =====================

espObjects = {}

local function addESP(part, name)
    if espObjects[part] then return end
    local _, box = pcall(function()
        local b = Instance.new("SelectionBox")
        b.Color3 = Color3.fromRGB(30,200,255)
        b.LineThickness = 0.05
        b.SurfaceTransparency = 0.82
        b.SurfaceColor3 = Color3.fromRGB(30,200,255)
        b.Adornee = part
        b.Parent = workspace
        return b
    end)
    local _, bb = pcall(function()
        local g = Instance.new("BillboardGui")
        g.Size = UDim2.new(0,110,0,18)
        g.StudsOffset = Vector3.new(0,3,0)
        g.AlwaysOnTop = true
        g.Adornee = part
        g.Parent = sg
        local t = Instance.new("TextLabel")
        t.Size = UDim2.new(1,0,1,0)
        t.BackgroundTransparency = 1
        t.Text = name
        t.TextColor3 = Color3.fromRGB(30,200,255)
        t.TextSize = 11
        t.Font = Enum.Font.GothamBold
        t.TextStrokeTransparency = 0.3
        t.Parent = g
        return g
    end)
    espObjects[part] = {box=box, bb=bb}
end

workspace.DescendantAdded:Connect(function(obj)
    if not itemEsp then return end
    task.wait(0.05)
    if not obj or not obj.Parent then return end
    if obj:FindFirstChildWhichIsA("Humanoid") then return end
    -- Only pickable items, not boat/dinghy parts
    if nameGood(obj.Name, PICKUP_GOOD, PICKUP_BAD) or nameGood(obj.Name, CHEST_GOOD, PICKUP_BAD) then
        local part = obj:IsA("BasePart") and obj or obj:FindFirstChildWhichIsA("BasePart")
        if part then addESP(part, obj.Name) end
    end
end)

workspace.DescendantRemoving:Connect(function(obj)
    local t = espObjects[obj]
    if t then
        pcall(function() if t.box then t.box:Destroy() end end)
        pcall(function() if t.bb  then t.bb:Destroy()  end end)
        espObjects[obj] = nil
    end
end)

-- ===================== FEATURE LOGIC =====================

-- GOD MODE
local function doGodMode()
    if not godMode then return end
    pcall(function()
        local h = getHum()
        if h then h.Health = h.MaxHealth end
    end)
end

-- KILL AURA
-- NO camera manipulation - purely damage + touch + tool swing
local kaTimer = 0
local function doKillAura(dt)
    if not killAura then return end
    kaTimer += dt
    if kaTimer < kaCooldown then return end
    kaTimer = 0

    local hrp = getHRP()
    if not hrp then return end

    -- Equip best available melee
    local char = player.Character
    local tool
    for _, name in ipairs(MELEE_TOOLS) do
        local t = char and char:FindFirstChild(name)
        if not t then t = equipTool(name) end
        if t then tool = t break end
    end

    -- Find nearest NPC
    local best, bestDist = nil, math.huge
    for _, entry in ipairs(cachedNPCs) do
        if entry.model and entry.model.Parent and entry.root and entry.root.Parent then
            local hum = entry.model:FindFirstChildWhichIsA("Humanoid")
            if hum and hum.Health > 0 then
                local dist = (hrp.Position - entry.root.Position).Magnitude
                if dist < kaRange and dist < bestDist then
                    best = entry
                    bestDist = dist
                end
            end
        end
    end

    if not best then return end

    local hum = best.model:FindFirstChildWhichIsA("Humanoid")
    if not hum then return end

    -- 1. Direct damage (most reliable)
    pcall(function() hum:TakeDamage(25) end)

    -- 2. Touch all body parts
    for _, part in ipairs(best.model:GetDescendants()) do
        if part:IsA("BasePart") then
            sFire(hrp, part, 0)
            sFire(hrp, part, 1)
        end
    end

    -- 3. Activate tool swing (no camera movement)
    if tool then
        activateTool(tool)
    end

    -- 4. Fire attack remotes
    fireRemote("attack")
    fireRemote("hit")
    fireRemote("damage")

    setStatus("Kill Aura: "..best.model.Name.." ("..math.floor(bestDist).."m)")
end

-- AUTO HARPOON (Harpoon + Riptide, no lag, 1.5s cooldown)
local harpTimer = 0
local function doAutoHarpoon(dt)
    if not autoHarpoon then return end
    harpTimer += dt
    if harpTimer < 1.5 then return end
    harpTimer = 0

    local hrp = getHRP()
    if not hrp then return end

    -- Equip harpoon or riptide
    local char = player.Character
    local tool
    for _, name in ipairs(HARPOON_TOOLS) do
        local t = char and char:FindFirstChild(name)
        if not t then t = equipTool(name) end
        if t then tool = t break end
    end
    if not tool then return end

    -- Find nearest NPC from cache
    local best, bestDist = nil, math.huge
    for _, entry in ipairs(cachedNPCs) do
        if entry.model and entry.model.Parent and entry.root and entry.root.Parent then
            local hum = entry.model:FindFirstChildWhichIsA("Humanoid")
            if hum and hum.Health > 0 then
                local dist = (hrp.Position - entry.root.Position).Magnitude
                if dist < 120 and dist < bestDist then
                    best = entry
                    bestDist = dist
                end
            end
        end
    end

    if not best then return end

    -- Aim camera at target WITHOUT locking (smooth look)
    pcall(function()
        local targetPos = best.root.Position
        local cf = Camera.CFrame
        -- Only update if target is roughly in front (avoids spinning)
        local dir = (targetPos - cf.Position).Unit
        local lookDir = cf.LookVector
        local dot = dir:Dot(lookDir)
        if dot > -0.5 then -- target is roughly in front or side
            Camera.CFrame = cf:Lerp(CFrame.lookAt(cf.Position, targetPos), 0.6)
        end
    end)

    -- Fire the harpoon
    activateTool(tool)
    fireRemote("harpoon")
    fireRemote("throw")
    fireRemote("shoot")
    touchPart(best.root)

    setStatus("Harpoon -> "..best.model.Name.." ("..math.floor(bestDist).."m)")
end

-- AUTO FISH (state machine, no lag)
local fishState = "idle"
local fishTimer = 0
local function doAutoFish(dt)
    if not autoFish then fishState = "idle" return end
    fishTimer += dt

    local char = player.Character
    if not char then return end

    -- Make sure rod is equipped
    local rod = char:FindFirstChild(TOOL_ROD)
    if not rod then
        if fishTimer > 1.5 then
            rod = equipTool(TOOL_ROD)
            fishTimer = 0
            if rod then
                setStatus("Auto Fish: rod equipped")
            else
                setStatus("Auto Fish: no rod in backpack!")
            end
        end
        return
    end

    if fishState == "idle" then
        if fishTimer > 0.5 then
            -- Cast line
            activateTool(rod)
            fireRemote("cast")
            fireRemote("fish")
            fishState = "waiting"
            fishTimer = 0
            setStatus("Auto Fish: cast, waiting for bite...")
        end

    elseif fishState == "waiting" then
        -- Detect bite via GUI text
        local bite = false
        for _, gui in ipairs(player.PlayerGui:GetChildren()) do
            for _, d in ipairs(gui:GetDescendants()) do
                local t = string.lower(d.Text or "")
                if t:find("bite") or t:find("reel") or t:find("catch")
                or t:find("got") or t:find("press") or t:find("hook") then
                    bite = true break
                end
            end
            if bite then break end
        end

        if bite then
            fishState = "reeling"
            fishTimer = 0
            setStatus("Auto Fish: BITE - reeling!")
        elseif fishTimer > 15 then
            -- Timeout, cast again
            fishState = "idle"
            fishTimer = 0
            setStatus("Auto Fish: timeout, recasting...")
        end

    elseif fishState == "reeling" then
        -- Spam reel
        activateTool(rod)
        fireRemote("reel")
        fireRemote("catch")

        if fishTimer > 2.5 then
            fishState = "idle"
            fishTimer = 0
            setStatus("Auto Fish: reeled in! Casting again...")
        end
    end
end

-- AUTO PICK UP (uses cache, runs every 0.8s)
local pickTimer = 0
local function doAutoPickUp(dt)
    if not autoPickUp then return end
    pickTimer += dt
    if pickTimer < 0.8 then return end
    pickTimer = 0

    local hrp = getHRP()
    if not hrp then return end

    -- Equip best sack available
    local char = player.Character
    local sack
    for _, name in ipairs(SACK_TOOLS) do
        local t = char and char:FindFirstChild(name)
        if not t then t = getBackpack(name) end
        if t then
            sack = char:FindFirstChild(name)
            if not sack then
                sack = equipTool(name)
            end
            break
        end
    end

    local count = 0
    for _, entry in ipairs(cachedItems) do
        if entry.part and entry.part.Parent then
            local dist = (hrp.Position - entry.part.Position).Magnitude
            if dist < 18 then
                touchPart(entry.part)
                fireAllPrompts(entry.obj)
                if sack then activateTool(sack) end
                fireRemote("pickup")
                fireRemote("collect")
                fireRemote("grab")
                count += 1
            end
        end
    end

    if count > 0 then
        setStatus("Auto Pick Up: collected "..count.." items")
    end
end

-- OPEN ALL CHESTS (runs in coroutine, checks sack full + unloads)
local chestRunning = false
local function doOpenAllChests()
    if not openAllChests or chestRunning then return end
    chestRunning = true

    local hrp = getHRP()
    if not hrp then chestRunning = false return end

    -- Equip best sack
    local char = player.Character
    local sack
    for _, name in ipairs(SACK_TOOLS) do
        local t = getBackpack(name)
        if t then
            sack = equipTool(name)
            break
        end
    end

    for _, entry in ipairs(cachedChests) do
        if not openAllChests then break end
        if entry.part and entry.part.Parent then
            -- Check sack full before each chest
            if isSackFull() then
                setStatus("Sack full! Unloading at base...")
                unloadSack()
                -- Re-equip sack
                for _, name in ipairs(SACK_TOOLS) do
                    local t = getBackpack(name)
                    if t then sack = equipTool(name) break end
                end
            end

            -- TP to chest
            tpTo(entry.part.CFrame * CFrame.new(0, 3, 0))
            task.wait(0.3)

            -- Open chest
            fireAllPrompts(entry.obj)
            touchPart(entry.part)
            fireRemote("open")
            fireRemote("loot")
            fireRemote("openchest")
            task.wait(0.4)

            -- Collect items that spawned from chest
            local hrp2 = getHRP()
            if hrp2 then
                for _, obj in ipairs(workspace:GetDescendants()) do
                    if not obj:FindFirstChildWhichIsA("Humanoid") then
                        if nameGood(obj.Name, PICKUP_GOOD, PICKUP_BAD) then
                            local part = obj:IsA("BasePart") and obj or obj:FindFirstChildWhichIsA("BasePart")
                            if part then
                                local dist = (hrp2.Position - part.Position).Magnitude
                                if dist < 20 then
                                    touchPart(part)
                                    fireAllPrompts(obj)
                                    if sack then activateTool(sack) end
                                    fireRemote("pickup")
                                    fireRemote("collect")
                                end
                            end
                        end
                    end
                end
            end

            setStatus("Opened: "..entry.obj.Name)
            task.wait(0.2)
        end
    end

    -- Final unload if sack has items
    if isSackFull() then
        setStatus("Final unload at base...")
        unloadSack()
    end

    chestRunning = false
    setStatus("Open All Chests: done!")
end

-- SPEED BOAT (lightweight)
local function doSpeedBoat()
    if not speedBoat then return end
    pcall(function()
        local char = player.Character
        if not char then return end
        for _, obj in ipairs(workspace:GetDescendants()) do
            if obj:IsA("VehicleSeat") and obj.Occupant and obj.Occupant.Parent == char then
                obj.MaxSpeed = boatSpeed
                obj.Throttle = 1
                return
            end
        end
    end)
end

-- AUTO EAT
local eatTimer = 0
local function doAutoEat(dt)
    if not autoEat then return end
    eatTimer += dt
    if eatTimer < 2.5 then return end
    eatTimer = 0
    fireRemote("eat")
    fireRemote("drink")
    fireRemote("consume")
end

-- AUTO REPAIR
local repTimer = 0
local function doAutoRepair(dt)
    if not autoRepair then return end
    repTimer += dt
    if repTimer < 4 then return end
    repTimer = 0
    fireRemote("repair")
    fireRemote("fix")
    local hrp = getHRP()
    if not hrp then return end
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("BasePart") then
            local n = string.lower(obj.Name)
            if (n:find("hull",1,true) or n:find("plank",1,true)) and
               (hrp.Position - obj.Position).Magnitude < 18 then
                fireAllPrompts(obj)
                touchPart(obj)
            end
        end
    end
end

-- SERVER INFO
local infoT = 0
local function doServerInfo(dt)
    if not serverInfo then return end
    infoT += dt
    if infoT < 2.5 then return end
    infoT = 0
    pcall(function() infoRows["Server ID"].Text = game.JobId ~= "" and game.JobId:sub(1,10).."…" or "Private" end)
    pcall(function() infoRows["Players"].Text = #Players:GetPlayers().."/"..Players.MaxPlayers end)
    pcall(function()
        local hrp = getHRP()
        if hrp then
            local p = hrp.Position
            infoRows["Position"].Text = string.format("%.0f,%.0f,%.0f", p.X, p.Y, p.Z)
        end
    end)
    pcall(function()
        local h = getHum()
        if h then infoRows["Health"].Text = math.floor(h.Health).."/"..math.floor(h.MaxHealth) end
    end)
    pcall(function()
        local s = game:GetService("Stats")
        infoRows["Ping"].Text = math.floor(s.Network.ServerStatsItem["Data Ping"]:GetValue()).."ms"
    end)
    pcall(function() infoRows["Server Time"].Text = string.format("%.0fs", workspace.DistributedGameTime) end)
    pcall(function()
        for _, obj in ipairs(workspace:GetDescendants()) do
            if (obj:IsA("IntValue") or obj:IsA("NumberValue")) and
               string.lower(obj.Name):find("day",1,true) then
                infoRows["Day"].Text = tostring(obj.Value) return
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

RunService.Heartbeat:Connect(function(dt)
    -- Cache refresh
    scanTimer += dt
    if scanTimer >= SCAN_RATE then
        scanTimer = 0
        pcall(refreshCache)
    end

    -- Lightweight every frame
    pcall(doGodMode)
    pcall(doSpeedBoat)

    -- Rate-limited
    pcall(doKillAura,     dt)
    pcall(doAutoHarpoon,  dt)
    pcall(doAutoFish,     dt)
    pcall(doAutoPickUp,   dt)
    pcall(doAutoEat,      dt)
    pcall(doAutoRepair,   dt)
    pcall(doServerInfo,   dt)
end)

-- Open all chests runs in its own coroutine so it doesn't block
RunService.Heartbeat:Connect(function()
    if openAllChests and not chestRunning then
        task.spawn(doOpenAllChests)
    end
end)

-- Initial cache build
task.spawn(refreshCache)

print("[100 Days at Sea Hub v3] Loaded.")
setStatus("v3 Loaded. No lag. All features ready.")
