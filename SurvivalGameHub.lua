repeat wait() until game:IsLoaded() and game.Players.LocalPlayer

local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Camera           = workspace.CurrentCamera
local player           = Players.LocalPlayer

-- ===================== STATE =====================

local aimbotEnabled      = false
local silentAimEnabled   = false
local noLagEnabled       = false
local espEnabled         = false
local itemEspEnabled     = false
local autoCollectEnabled = false
local ignoreTeam         = true

local aimbotPart   = "Head"
local espColor     = Color3.fromRGB(255, 50, 50)
local itemEspColor = Color3.fromRGB(255, 220, 50)

local espObjects     = {}
local itemEspObjects = {}

local ITEM_KEYWORDS = {
    "weapon","sword","axe","bow","gun","rifle","pistol","knife","spear",
    "food","apple","bread","meat","berry","water","flask","bandage","medkit",
    "wood","stone","metal","ore","ammo","arrow","bullet","supply","chest",
    "crate","loot","drop","pickup","item","collectible","resource"
}

-- ===================== GUI =====================

local sg = Instance.new("ScreenGui")
sg.Name = "SurvivalHub"
sg.ResetOnSpawn = false
sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
sg.Parent = player:WaitForChild("PlayerGui")

local win = Instance.new("Frame")
win.Size = UDim2.new(0, 300, 0, 420)
win.Position = UDim2.new(0, 16, 0.5, -210)
win.BackgroundColor3 = Color3.fromRGB(8, 8, 14)
win.BorderSizePixel = 0
win.Active = true
win.Draggable = true
win.Parent = sg
Instance.new("UICorner", win).CornerRadius = UDim.new(0, 12)
local wStroke = Instance.new("UIStroke", win)
wStroke.Color = Color3.fromRGB(220, 30, 30)
wStroke.Thickness = 1.2

local topBar = Instance.new("Frame")
topBar.Size = UDim2.new(1, 0, 0, 3)
topBar.BackgroundColor3 = Color3.fromRGB(220, 30, 30)
topBar.BorderSizePixel = 0
topBar.Parent = win
Instance.new("UICorner", topBar).CornerRadius = UDim.new(0, 12)

local titleLbl = Instance.new("TextLabel")
titleLbl.Size = UDim2.new(1, -50, 0, 18)
titleLbl.Position = UDim2.new(0, 12, 0, 10)
titleLbl.BackgroundTransparency = 1
titleLbl.Text = "The Survival Game"
titleLbl.TextColor3 = Color3.fromRGB(230, 230, 240)
titleLbl.TextSize = 13
titleLbl.Font = Enum.Font.GothamBold
titleLbl.TextXAlignment = Enum.TextXAlignment.Left
titleLbl.Parent = win

local subLbl = Instance.new("TextLabel")
subLbl.Size = UDim2.new(1, -50, 0, 13)
subLbl.Position = UDim2.new(0, 12, 0, 27)
subLbl.BackgroundTransparency = 1
subLbl.Text = "SCRIPT HUB"
subLbl.TextColor3 = Color3.fromRGB(220, 30, 30)
subLbl.TextSize = 10
subLbl.Font = Enum.Font.GothamBold
subLbl.TextXAlignment = Enum.TextXAlignment.Left
subLbl.Parent = win

local xBtn = Instance.new("TextButton")
xBtn.Size = UDim2.new(0, 24, 0, 24)
xBtn.Position = UDim2.new(1, -32, 0, 10)
xBtn.BackgroundColor3 = Color3.fromRGB(35, 14, 14)
xBtn.Text = "X"
xBtn.TextColor3 = Color3.fromRGB(220, 70, 70)
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
    d.BackgroundColor3 = Color3.fromRGB(30, 14, 14)
    d.BorderSizePixel = 0
    d.Parent = parent
end
mkDiv(win, 47)

local tabNames = {"Main", "Visual"}
local tabBtns  = {}
local tabWidth = (300 - 24) / #tabNames

local tabBar = Instance.new("Frame")
tabBar.Size = UDim2.new(1, -24, 0, 28)
tabBar.Position = UDim2.new(0, 12, 0, 53)
tabBar.BackgroundTransparency = 1
tabBar.Parent = win

for i, name in ipairs(tabNames) do
    local tb = Instance.new("TextButton")
    tb.Size = UDim2.new(0, tabWidth - 4, 0, 26)
    tb.Position = UDim2.new(0, (i-1)*tabWidth, 0, 0)
    tb.BackgroundColor3 = Color3.fromRGB(16, 10, 10)
    tb.BorderSizePixel = 0
    tb.Text = name
    tb.TextColor3 = Color3.fromRGB(130, 80, 80)
    tb.TextSize = 11
    tb.Font = Enum.Font.GothamBold
    tb.Parent = tabBar
    Instance.new("UICorner", tb).CornerRadius = UDim.new(0, 6)
    tabBtns[name] = tb
end

mkDiv(win, 86)

local content = Instance.new("Frame")
content.Size = UDim2.new(1, -24, 0, 295)
content.Position = UDim2.new(0, 12, 0, 93)
content.BackgroundTransparency = 1
content.Parent = win

local statusBar = Instance.new("Frame")
statusBar.Size = UDim2.new(1, -24, 0, 22)
statusBar.Position = UDim2.new(0, 12, 0, 390)
statusBar.BackgroundColor3 = Color3.fromRGB(6, 4, 10)
statusBar.BorderSizePixel = 0
statusBar.Parent = win
Instance.new("UICorner", statusBar).CornerRadius = UDim.new(0, 5)

local sDot = Instance.new("Frame")
sDot.Size = UDim2.new(0, 5, 0, 5)
sDot.Position = UDim2.new(0, 8, 0.5, -2)
sDot.BackgroundColor3 = Color3.fromRGB(220, 30, 30)
sDot.BorderSizePixel = 0
sDot.Parent = statusBar
Instance.new("UICorner", sDot).CornerRadius = UDim.new(1, 0)

local sTxt = Instance.new("TextLabel")
sTxt.Size = UDim2.new(1, -22, 1, 0)
sTxt.Position = UDim2.new(0, 18, 0, 0)
sTxt.BackgroundTransparency = 1
sTxt.Text = "Ready"
sTxt.TextColor3 = Color3.fromRGB(100, 60, 60)
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
            tabBtns[n].BackgroundColor3 = Color3.fromRGB(160, 20, 20)
            tabBtns[n].TextColor3 = Color3.fromRGB(255, 220, 220)
        else
            tabBtns[n].BackgroundColor3 = Color3.fromRGB(16, 10, 10)
            tabBtns[n].TextColor3 = Color3.fromRGB(130, 80, 80)
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
    l.TextColor3 = Color3.fromRGB(100, 40, 40)
    l.TextSize = 9
    l.Font = Enum.Font.GothamBold
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.Parent = parent
end

local function mkToggle(parent, y, label, cb)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 34)
    row.Position = UDim2.new(0, 0, 0, y)
    row.BackgroundColor3 = Color3.fromRGB(14, 8, 8)
    row.BorderSizePixel = 0
    row.Parent = parent
    Instance.new("UICorner", row).CornerRadius = UDim.new(0, 7)

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -60, 1, 0)
    lbl.Position = UDim2.new(0, 10, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = label
    lbl.TextColor3 = Color3.fromRGB(200, 170, 170)
    lbl.TextSize = 12
    lbl.Font = Enum.Font.GothamBold
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = row

    local swBg = Instance.new("Frame")
    swBg.Size = UDim2.new(0, 36, 0, 20)
    swBg.Position = UDim2.new(1, -44, 0.5, -10)
    swBg.BackgroundColor3 = Color3.fromRGB(30, 16, 16)
    swBg.BorderSizePixel = 0
    swBg.Parent = row
    Instance.new("UICorner", swBg).CornerRadius = UDim.new(1, 0)

    local knob = Instance.new("Frame")
    knob.Size = UDim2.new(0, 14, 0, 14)
    knob.Position = UDim2.new(0, 3, 0.5, -7)
    knob.BackgroundColor3 = Color3.fromRGB(80, 40, 40)
    knob.BorderSizePixel = 0
    knob.Parent = swBg
    Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)

    local on = false
    local function setState(state)
        on = state
        swBg.BackgroundColor3 = on and Color3.fromRGB(200,30,30) or Color3.fromRGB(30,16,16)
        knob.Position = on and UDim2.new(0,19,0.5,-7) or UDim2.new(0,3,0.5,-7)
        knob.BackgroundColor3 = on and Color3.fromRGB(255,255,255) or Color3.fromRGB(80,40,40)
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

local function mkDropdown(parent, y, label, options, cb)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 0, 34)
    frame.Position = UDim2.new(0, 0, 0, y)
    frame.BackgroundColor3 = Color3.fromRGB(14, 8, 8)
    frame.BorderSizePixel = 0
    frame.Parent = parent
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 7)

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(0.52, 0, 1, 0)
    lbl.Position = UDim2.new(0, 10, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = label
    lbl.TextColor3 = Color3.fromRGB(200, 170, 170)
    lbl.TextSize = 11
    lbl.Font = Enum.Font.GothamBold
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = frame

    local idx = 1
    local valBtn = Instance.new("TextButton")
    valBtn.Size = UDim2.new(0.44, 0, 0, 24)
    valBtn.Position = UDim2.new(0.54, 0, 0.5, -12)
    valBtn.BackgroundColor3 = Color3.fromRGB(30, 14, 14)
    valBtn.BorderSizePixel = 0
    valBtn.Text = options[1]
    valBtn.TextColor3 = Color3.fromRGB(220, 50, 50)
    valBtn.TextSize = 10
    valBtn.Font = Enum.Font.GothamBold
    valBtn.Parent = frame
    Instance.new("UICorner", valBtn).CornerRadius = UDim.new(0, 5)
    valBtn.MouseButton1Click:Connect(function()
        idx = (idx % #options) + 1
        valBtn.Text = options[idx]
        cb(options[idx])
    end)
end

-- ===================== TEAM / TARGET CHECK =====================

local function isTeammate(tgt)
    if not ignoreTeam then return false end
    if player.Team and tgt.Team then
        return player.Team == tgt.Team
    end
    if player.TeamColor and tgt.TeamColor then
        return player.TeamColor == tgt.TeamColor
    end
    return false
end

local function isValidTarget(tgt)
    if tgt == player then return false end
    local char = tgt.Character
    if not char then return false end
    local hum = char:FindFirstChildWhichIsA("Humanoid")
    if not hum or hum.Health <= 0 then return false end
    if isTeammate(tgt) then return false end
    return true
end

local function getNearestPlayer()
    local best, bestDist = nil, math.huge
    local viewSize = Camera:GetViewportSize()
    local cx, cy = viewSize.X/2, viewSize.Y/2
    for _, p in ipairs(Players:GetPlayers()) do
        if not isValidTarget(p) then continue end
        local part = p.Character:FindFirstChild(aimbotPart)
            or p.Character:FindFirstChild("HumanoidRootPart")
        if not part then continue end
        local sp, onScreen = Camera:WorldToViewportPoint(part.Position)
        if not onScreen then continue end
        local d = math.sqrt((sp.X-cx)^2 + (sp.Y-cy)^2)
        if d < bestDist then bestDist = d best = p end
    end
    return best
end

-- ===================== MAIN TAB =====================

local mp = pages["Main"]

mkLabel(mp, 0, "PERFORMANCE")
mkToggle(mp, 14, "No Lag", function(on)
    noLagEnabled = on
    if on then
        for _, obj in ipairs(workspace:GetDescendants()) do
            pcall(function()
                if obj:IsA("ParticleEmitter") or obj:IsA("Smoke")
                or obj:IsA("Fire") or obj:IsA("Sparkles") then
                    obj.Enabled = false
                elseif obj:IsA("SurfaceAppearance") then
                    obj:Destroy()
                end
            end)
        end
        settings().Rendering.QualityLevel = 1
        setStatus("No Lag ON")
    else
        settings().Rendering.QualityLevel = 10
        setStatus("No Lag OFF")
    end
end)

mkLabel(mp, 56, "COMBAT")

local setIgnoreTeam = mkToggle(mp, 70, "Ignore Team", function(on)
    ignoreTeam = on
    setStatus(on and "Ignore Team ON" or "Ignore Team OFF - targeting all")
end)
setIgnoreTeam(true) -- default ON

mkToggle(mp, 112, "Aimbot", function(on)
    aimbotEnabled = on
    setStatus(on and "Aimbot ON - " .. aimbotPart or "Aimbot OFF")
end)

mkDropdown(mp, 154, "Aim At", {"Head", "HumanoidRootPart", "LeftFoot"}, function(val)
    aimbotPart = val
    setStatus("Aim target: " .. val)
end)

mkToggle(mp, 196, "Silent Aim", function(on)
    silentAimEnabled = on
    setStatus(on and "Silent Aim ON" or "Silent Aim OFF")
end)

mkLabel(mp, 238, "UTILITY")

mkToggle(mp, 252, "Auto Collect", function(on)
    autoCollectEnabled = on
    setStatus(on and "Auto Collect ON" or "Auto Collect OFF")
end)

-- ===================== VISUAL TAB =====================

local vp = pages["Visual"]

mkLabel(vp, 0, "PLAYER ESP")
mkToggle(vp, 14, "Player ESP", function(on)
    espEnabled = on
    if not on then
        for _, t in pairs(espObjects) do
            pcall(function()
                if t.box    then t.box:Destroy()    end
                if t.tracer then t.tracer:Destroy()  end
                if t.nameBB then t.nameBB:Destroy()  end
            end)
        end
        espObjects = {}
    end
    setStatus(on and "Player ESP ON" or "Player ESP OFF")
end)

mkDropdown(vp, 56, "ESP Color", {"Red","White","Green","Yellow"}, function(val)
    local cmap = {Red=Color3.fromRGB(255,50,50),White=Color3.fromRGB(255,255,255),
        Green=Color3.fromRGB(50,255,100),Yellow=Color3.fromRGB(255,220,50)}
    espColor = cmap[val]
    for _, t in pairs(espObjects) do
        if t.box then t.box.Color3 = espColor t.box.SurfaceColor3 = espColor end
    end
    setStatus("ESP color: " .. val)
end)

mkLabel(vp, 98, "ITEM ESP")
mkToggle(vp, 112, "Item ESP", function(on)
    itemEspEnabled = on
    if not on then
        for _, t in pairs(itemEspObjects) do
            pcall(function()
                if t.box    then t.box:Destroy()   end
                if t.nameBB then t.nameBB:Destroy() end
            end)
        end
        itemEspObjects = {}
    end
    setStatus(on and "Item ESP ON" or "Item ESP OFF")
end)

mkDropdown(vp, 154, "Item Color", {"Yellow","Cyan","White","Green"}, function(val)
    local cmap = {Yellow=Color3.fromRGB(255,220,50),Cyan=Color3.fromRGB(50,220,255),
        White=Color3.fromRGB(255,255,255),Green=Color3.fromRGB(50,255,100)}
    itemEspColor = cmap[val]
    for _, t in pairs(itemEspObjects) do
        if t.box then t.box.Color3 = itemEspColor t.box.SurfaceColor3 = itemEspColor end
    end
    setStatus("Item ESP color: " .. val)
end)

-- ===================== ESP FUNCTIONS =====================

local function setupPlayerESP(char, plr)
    if espObjects[char] then return end
    local hrp  = char:FindFirstChild("HumanoidRootPart")
    local head = char:FindFirstChild("Head")
    if not hrp or not head then return end

    local box = Instance.new("SelectionBox")
    box.Color3 = espColor
    box.LineThickness = 0.04
    box.SurfaceTransparency = 0.85
    box.SurfaceColor3 = espColor
    box.Adornee = char
    box.Parent = workspace

    local nameBB = Instance.new("BillboardGui")
    nameBB.Size = UDim2.new(0, 130, 0, 40)
    nameBB.StudsOffset = Vector3.new(0, 3.2, 0)
    nameBB.AlwaysOnTop = true
    nameBB.Adornee = head
    nameBB.Parent = sg

    local nameTag = Instance.new("TextLabel")
    nameTag.Size = UDim2.new(1, 0, 0.55, 0)
    nameTag.BackgroundTransparency = 1
    nameTag.Text = plr.Name
    nameTag.TextColor3 = espColor
    nameTag.TextSize = 12
    nameTag.Font = Enum.Font.GothamBold
    nameTag.TextStrokeTransparency = 0.4
    nameTag.Parent = nameBB

    local hpTag = Instance.new("TextLabel")
    hpTag.Size = UDim2.new(1, 0, 0.45, 0)
    hpTag.Position = UDim2.new(0, 0, 0.55, 0)
    hpTag.BackgroundTransparency = 1
    hpTag.Text = "HP: ?"
    hpTag.TextColor3 = Color3.fromRGB(255, 255, 255)
    hpTag.TextSize = 10
    hpTag.Font = Enum.Font.Gotham
    hpTag.TextStrokeTransparency = 0.4
    hpTag.Parent = nameBB

    local tracer = Instance.new("Frame")
    tracer.BackgroundColor3 = espColor
    tracer.BorderSizePixel = 0
    tracer.AnchorPoint = Vector2.new(0.5, 0)
    tracer.Size = UDim2.new(0, 1, 0, 1)
    tracer.ZIndex = 5
    tracer.Parent = sg

    espObjects[char] = {box=box, tracer=tracer, nameBB=nameBB, hpTag=hpTag, plr=plr}
end

local function isItemPart(obj)
    if not (obj:IsA("BasePart") or obj:IsA("Model")) then return false end
    if obj:FindFirstChildWhichIsA("Humanoid") then return false end
    -- skip player characters
    for _, p in ipairs(Players:GetPlayers()) do
        if p.Character == obj or p.Character == obj.Parent then return false end
    end
    local n = string.lower(obj.Name)
    for _, kw in ipairs(ITEM_KEYWORDS) do
        if n:find(kw) then return true end
    end
    return false
end

local function setupItemESP(part)
    if itemEspObjects[part] then return end

    local box = Instance.new("SelectionBox")
    box.Color3 = itemEspColor
    box.LineThickness = 0.05
    box.SurfaceTransparency = 0.8
    box.SurfaceColor3 = itemEspColor
    box.Adornee = part
    box.Parent = workspace

    local nameBB = Instance.new("BillboardGui")
    nameBB.Size = UDim2.new(0, 120, 0, 22)
    nameBB.StudsOffset = Vector3.new(0, 2.5, 0)
    nameBB.AlwaysOnTop = true
    nameBB.Adornee = part
    nameBB.Parent = sg

    local nameTag = Instance.new("TextLabel")
    nameTag.Size = UDim2.new(1, 0, 1, 0)
    nameTag.BackgroundTransparency = 1
    nameTag.Text = part.Name
    nameTag.TextColor3 = itemEspColor
    nameTag.TextSize = 11
    nameTag.Font = Enum.Font.GothamBold
    nameTag.TextStrokeTransparency = 0.4
    nameTag.Parent = nameBB

    itemEspObjects[part] = {box=box, nameBB=nameBB}
end

-- ===================== UPDATE LOOPS =====================

local function updatePlayerESP()
    if not espEnabled then return end

    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= player and p.Character then
            setupPlayerESP(p.Character, p)
        end
    end

    local myChar = player.Character
    local myHRP  = myChar and myChar:FindFirstChild("HumanoidRootPart")
    local myHead = myChar and myChar:FindFirstChild("Head")
    local viewSize = Camera:GetViewportSize()

    for char, t in pairs(espObjects) do
        if not char or not char.Parent then
            pcall(function()
                if t.box    then t.box:Destroy()    end
                if t.tracer then t.tracer:Destroy()  end
                if t.nameBB then t.nameBB:Destroy()  end
            end)
            espObjects[char] = nil
            continue
        end

        local hum = char:FindFirstChildWhichIsA("Humanoid")
        if hum and t.hpTag then
            t.hpTag.Text = "HP: " .. math.floor(hum.Health)
        end

        local targetHRP = char:FindFirstChild("HumanoidRootPart")
        if not targetHRP or not t.tracer then continue end

        local tp, onScreen = Camera:WorldToViewportPoint(targetHRP.Position)
        if not onScreen then t.tracer.Visible = false continue end
        t.tracer.Visible = true

        -- Start point: 1st person = screen center, 3rd person = my head
        local sx, sy
        local camDist = myHRP and (Camera.CFrame.Position - myHRP.Position).Magnitude or 5
        if camDist < 1.5 then
            sx, sy = viewSize.X/2, viewSize.Y/2
        else
            if myHead then
                local hp, hs = Camera:WorldToViewportPoint(myHead.Position)
                sx = hs and hp.X or viewSize.X/2
                sy = hs and hp.Y or viewSize.Y/2
            else
                sx, sy = viewSize.X/2, viewSize.Y/2
            end
        end

        local dx = tp.X - sx
        local dy = tp.Y - sy
        t.tracer.Position = UDim2.new(0, sx, 0, sy)
        t.tracer.Size = UDim2.new(0, math.sqrt(dx*dx+dy*dy), 0, 1.5)
        t.tracer.Rotation = math.deg(math.atan2(dy, dx))
    end
end

local function updateItemESP()
    if not itemEspEnabled then return end
    for _, obj in ipairs(workspace:GetDescendants()) do
        if isItemPart(obj) then
            local part = obj:IsA("BasePart") and obj or obj:FindFirstChildWhichIsA("BasePart")
            if part and not itemEspObjects[part] then setupItemESP(part) end
        end
    end
    for part, t in pairs(itemEspObjects) do
        if not part or not part.Parent then
            pcall(function()
                if t.box    then t.box:Destroy()   end
                if t.nameBB then t.nameBB:Destroy() end
            end)
            itemEspObjects[part] = nil
        end
    end
end

-- ===================== AIMBOT =====================

local function doAimbot()
    if not aimbotEnabled then return end
    local target = getNearestPlayer()
    if not target or not target.Character then return end
    local part = target.Character:FindFirstChild(aimbotPart)
        or target.Character:FindFirstChild("HumanoidRootPart")
    if not part then return end
    local cf = Camera.CFrame
    Camera.CFrame = cf:Lerp(CFrame.lookAt(cf.Position, part.Position), 0.3)
end

-- ===================== SILENT AIM =====================
-- Snaps camera to target instantly the moment a tool fires,
-- then restores camera. Makes every shot perfectly land.

local silentFireing = false

RunService.RenderStepped:Connect(function()
    if not silentAimEnabled then return end
    local target = getNearestPlayer()
    if not target or not target.Character then return end

    local part = target.Character:FindFirstChild(aimbotPart)
        or target.Character:FindFirstChild("HumanoidRootPart")
    if not part then return end

    local myChar = player.Character
    local tool = myChar and myChar:FindFirstChildWhichIsA("Tool")
    if not tool then return end

    -- Predict target position using velocity
    local hrp = target.Character:FindFirstChild("HumanoidRootPart")
    local predictedPos = part.Position
    if hrp then
        predictedPos = part.Position + hrp.AssemblyLinearVelocity * 0.09
    end

    -- Silently snap camera to target for the frame the bullet travels
    local savedCF = Camera.CFrame
    Camera.CFrame = CFrame.lookAt(Camera.CFrame.Position, predictedPos)
    task.defer(function()
        -- Restore camera next frame so player doesn't notice snap
        if not aimbotEnabled then -- only restore if aimbot isn't also running
            Camera.CFrame = savedCF
        end
    end)
end)

-- ===================== AUTO COLLECT =====================

local function doAutoCollect()
    if not autoCollectEnabled then return end
    local myChar = player.Character
    local myHRP  = myChar and myChar:FindFirstChild("HumanoidRootPart")
    if not myHRP then return end

    for _, obj in ipairs(workspace:GetDescendants()) do
        if isItemPart(obj) then
            local part = obj:IsA("BasePart") and obj or obj:FindFirstChildWhichIsA("BasePart")
            if part then
                local dist = (myHRP.Position - part.Position).Magnitude
                if dist < 22 then
                    pcall(function() firetouchinterest(myHRP, part, 0) end)
                    pcall(function() firetouchinterest(myHRP, part, 1) end)
                    local prompt = obj:FindFirstChildWhichIsA("ProximityPrompt", true)
                        or (obj.Parent and obj.Parent:FindFirstChildWhichIsA("ProximityPrompt", true))
                    if prompt then
                        pcall(function() fireproximityprompt(prompt) end)
                    end
                end
            end
        end
    end
end

-- ===================== HEARTBEAT LOOP =====================

RunService.Heartbeat:Connect(function()
    doAimbot()
    doAutoCollect()
end)

RunService.RenderStepped:Connect(function()
    updatePlayerESP()
    updateItemESP()
end)

-- ESP respawn hooks
for _, p in ipairs(Players:GetPlayers()) do
    if p ~= player then
        p.CharacterAdded:Connect(function(char)
            task.wait(1)
            if espEnabled then setupPlayerESP(char, p) end
        end)
    end
end

Players.PlayerAdded:Connect(function(p)
    p.CharacterAdded:Connect(function(char)
        task.wait(1)
        if espEnabled then setupPlayerESP(char, p) end
    end)
end)

Players.PlayerRemoving:Connect(function(p)
    if not p.Character then return end
    local t = espObjects[p.Character]
    if not t then return end
    pcall(function()
        if t.box    then t.box:Destroy()    end
        if t.tracer then t.tracer:Destroy()  end
        if t.nameBB then t.nameBB:Destroy()  end
    end)
    espObjects[p.Character] = nil
end)

print("[Survival Hub] Loaded.")
setStatus("Loaded. All features ready.")
