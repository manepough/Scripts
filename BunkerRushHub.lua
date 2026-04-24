repeat wait() until game:IsLoaded() and game.Players.LocalPlayer

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer

local autoPlace    = false
local instantSkip  = false
local zombieESP    = false
local autoKill     = false
local autoCoin     = false

local plotCF       = nil
local placedCount  = 0
local isBusy       = false
local handled      = {}
local espParts     = {}

local TRACKED_UNITS = {
    "Solar Panel","Oil Rig","Gold Mine","Money Printer",
    "Brick Wall","Forcefield",
    "Noob","Barbed Wire","Archer","Mine","Fire","Turret",
    "Tesla Coil","Sniper","Flamethrower","Cannon","Freeze Ray",
    "Minigun","Leatherface","UFO"
}

-- ===================== GUI =====================

local sg = Instance.new("ScreenGui")
sg.Name = "BunkerRushHub"
sg.ResetOnSpawn = false
sg.Parent = player:WaitForChild("PlayerGui")

local win = Instance.new("Frame")
win.Size = UDim2.new(0, 280, 0, 360)
win.Position = UDim2.new(0, 16, 0.5, -180)
win.BackgroundColor3 = Color3.fromRGB(13, 11, 22)
win.BorderSizePixel = 0
win.Active = true
win.Draggable = true
win.Parent = sg
Instance.new("UICorner", win).CornerRadius = UDim.new(0, 12)

local winStroke = Instance.new("UIStroke", win)
winStroke.Color = Color3.fromRGB(80, 40, 180)
winStroke.Thickness = 1.2

local topAccent = Instance.new("Frame")
topAccent.Size = UDim2.new(1, 0, 0, 3)
topAccent.BackgroundColor3 = Color3.fromRGB(130, 60, 255)
topAccent.BorderSizePixel = 0
topAccent.Parent = win
Instance.new("UICorner", topAccent).CornerRadius = UDim.new(0, 12)

local titleLbl = Instance.new("TextLabel")
titleLbl.Size = UDim2.new(1, -50, 0, 18)
titleLbl.Position = UDim2.new(0, 12, 0, 10)
titleLbl.BackgroundTransparency = 1
titleLbl.Text = "Bunker Rush"
titleLbl.TextColor3 = Color3.fromRGB(220, 220, 240)
titleLbl.TextSize = 13
titleLbl.Font = Enum.Font.GothamBold
titleLbl.TextXAlignment = Enum.TextXAlignment.Left
titleLbl.Parent = win

local subLbl = Instance.new("TextLabel")
subLbl.Size = UDim2.new(1, -50, 0, 13)
subLbl.Position = UDim2.new(0, 12, 0, 26)
subLbl.BackgroundTransparency = 1
subLbl.Text = "Script Hub"
subLbl.TextColor3 = Color3.fromRGB(130, 60, 255)
subLbl.TextSize = 10
subLbl.Font = Enum.Font.GothamBold
subLbl.TextXAlignment = Enum.TextXAlignment.Left
subLbl.Parent = win

local xBtn = Instance.new("TextButton")
xBtn.Size = UDim2.new(0, 24, 0, 24)
xBtn.Position = UDim2.new(1, -32, 0, 10)
xBtn.BackgroundColor3 = Color3.fromRGB(35, 18, 18)
xBtn.Text = "X"
xBtn.TextColor3 = Color3.fromRGB(200, 70, 70)
xBtn.TextSize = 11
xBtn.Font = Enum.Font.GothamBold
xBtn.BorderSizePixel = 0
xBtn.Parent = win
Instance.new("UICorner", xBtn).CornerRadius = UDim.new(0, 5)
xBtn.MouseButton1Click:Connect(function() sg:Destroy() end)

local div1 = Instance.new("Frame")
div1.Size = UDim2.new(1, -24, 0, 1)
div1.Position = UDim2.new(0, 12, 0, 46)
div1.BackgroundColor3 = Color3.fromRGB(40, 28, 65)
div1.BorderSizePixel = 0
div1.Parent = win

local tabBar = Instance.new("Frame")
tabBar.Size = UDim2.new(1, -24, 0, 28)
tabBar.Position = UDim2.new(0, 12, 0, 52)
tabBar.BackgroundTransparency = 1
tabBar.Parent = win

local tabNames = {"Main", "Auto Buy", "Auto Place"}
local tabBtns = {}
local tabWidth = (280 - 24) / 3

for i, name in ipairs(tabNames) do
    local tb = Instance.new("TextButton")
    tb.Size = UDim2.new(0, tabWidth - 4, 0, 26)
    tb.Position = UDim2.new(0, (i-1)*(tabWidth), 0, 0)
    tb.BackgroundColor3 = Color3.fromRGB(20, 14, 36)
    tb.BorderSizePixel = 0
    tb.Text = name
    tb.TextColor3 = Color3.fromRGB(120, 100, 160)
    tb.TextSize = 11
    tb.Font = Enum.Font.GothamBold
    tb.Parent = tabBar
    Instance.new("UICorner", tb).CornerRadius = UDim.new(0, 6)
    tabBtns[name] = tb
end

local content = Instance.new("Frame")
content.Size = UDim2.new(1, -24, 0, 256)
content.Position = UDim2.new(0, 12, 0, 86)
content.BackgroundTransparency = 1
content.Parent = win

local statusBar = Instance.new("Frame")
statusBar.Size = UDim2.new(1, -24, 0, 22)
statusBar.Position = UDim2.new(0, 12, 0, 328)
statusBar.BackgroundColor3 = Color3.fromRGB(10, 7, 18)
statusBar.BorderSizePixel = 0
statusBar.Parent = win
Instance.new("UICorner", statusBar).CornerRadius = UDim.new(0, 5)

local sDot = Instance.new("Frame")
sDot.Size = UDim2.new(0, 5, 0, 5)
sDot.Position = UDim2.new(0, 8, 0.5, -2)
sDot.BackgroundColor3 = Color3.fromRGB(130, 60, 255)
sDot.BorderSizePixel = 0
sDot.Parent = statusBar
Instance.new("UICorner", sDot).CornerRadius = UDim.new(1, 0)

local sTxt = Instance.new("TextLabel")
sTxt.Size = UDim2.new(1, -22, 1, 0)
sTxt.Position = UDim2.new(0, 18, 0, 0)
sTxt.BackgroundTransparency = 1
sTxt.Text = "Ready"
sTxt.TextColor3 = Color3.fromRGB(90, 70, 130)
sTxt.TextSize = 9
sTxt.Font = Enum.Font.Code
sTxt.TextXAlignment = Enum.TextXAlignment.Left
sTxt.Parent = statusBar

local function setStatus(txt)
    sTxt.Text = "> " .. txt
end

-- ===================== TAB PAGES =====================

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
        local tb = tabBtns[n]
        if n == name then
            tb.BackgroundColor3 = Color3.fromRGB(80, 35, 180)
            tb.TextColor3 = Color3.fromRGB(255, 255, 255)
        else
            tb.BackgroundColor3 = Color3.fromRGB(20, 14, 36)
            tb.TextColor3 = Color3.fromRGB(110, 90, 150)
        end
    end
end
switchTab("Main")

for _, name in ipairs(tabNames) do
    tabBtns[name].MouseButton1Click:Connect(function() switchTab(name) end)
end

-- ===================== UI HELPERS =====================

local function mkToggle(parent, y, labelText, callback)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 36)
    row.Position = UDim2.new(0, 0, 0, y)
    row.BackgroundColor3 = Color3.fromRGB(18, 12, 30)
    row.BorderSizePixel = 0
    row.Parent = parent
    Instance.new("UICorner", row).CornerRadius = UDim.new(0, 7)

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -60, 1, 0)
    lbl.Position = UDim2.new(0, 10, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = labelText
    lbl.TextColor3 = Color3.fromRGB(180, 160, 220)
    lbl.TextSize = 12
    lbl.Font = Enum.Font.GothamBold
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = row

    local swBg = Instance.new("Frame")
    swBg.Size = UDim2.new(0, 36, 0, 20)
    swBg.Position = UDim2.new(1, -44, 0.5, -10)
    swBg.BackgroundColor3 = Color3.fromRGB(30, 20, 50)
    swBg.BorderSizePixel = 0
    swBg.Parent = row
    Instance.new("UICorner", swBg).CornerRadius = UDim.new(1, 0)

    local knob = Instance.new("Frame")
    knob.Size = UDim2.new(0, 14, 0, 14)
    knob.Position = UDim2.new(0, 3, 0.5, -7)
    knob.BackgroundColor3 = Color3.fromRGB(70, 50, 100)
    knob.BorderSizePixel = 0
    knob.Parent = swBg
    Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)

    local on = false
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 1, 0)
    btn.BackgroundTransparency = 1
    btn.Text = ""
    btn.Parent = row

    btn.MouseButton1Click:Connect(function()
        on = not on
        if on then
            swBg.BackgroundColor3 = Color3.fromRGB(110, 40, 240)
            knob.Position = UDim2.new(0, 19, 0.5, -7)
            knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        else
            swBg.BackgroundColor3 = Color3.fromRGB(30, 20, 50)
            knob.Position = UDim2.new(0, 3, 0.5, -7)
            knob.BackgroundColor3 = Color3.fromRGB(70, 50, 100)
        end
        callback(on)
    end)
end

local function mkButton(parent, y, labelText, callback)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, 34)
    btn.Position = UDim2.new(0, 0, 0, y)
    btn.BackgroundColor3 = Color3.fromRGB(80, 35, 180)
    btn.BorderSizePixel = 0
    btn.Text = labelText
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.TextSize = 12
    btn.Font = Enum.Font.GothamBold
    btn.Parent = parent
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 7)
    btn.MouseButton1Click:Connect(callback)
end

local function mkLabel(parent, y, text)
    local l = Instance.new("TextLabel")
    l.Size = UDim2.new(1, 0, 0, 14)
    l.Position = UDim2.new(0, 0, 0, y)
    l.BackgroundTransparency = 1
    l.Text = text
    l.TextColor3 = Color3.fromRGB(80, 55, 130)
    l.TextSize = 9
    l.Font = Enum.Font.GothamBold
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.Parent = parent
end

-- ===================== MAIN TAB =====================

local mp = pages["Main"]
mkLabel(mp, 0, "GENERAL")
mkToggle(mp, 16, "Instant Skip Wave", function(on) instantSkip = on setStatus(on and "Instant Skip ON" or "Instant Skip OFF") end)
mkToggle(mp, 58, "Zombie ESP", function(on)
    zombieESP = on
    if not on then for _, p in pairs(espParts) do pcall(function() p:Destroy() end) end espParts = {} end
    setStatus(on and "Zombie ESP ON" or "Zombie ESP OFF")
end)
mkToggle(mp, 100, "Auto Kill", function(on) autoKill = on setStatus(on and "Auto Kill ON" or "Auto Kill OFF") end)
mkToggle(mp, 142, "Auto Coin Collect", function(on) autoCoin = on setStatus(on and "Auto Coin Collect ON" or "Auto Coin Collect OFF") end)

-- ===================== AUTO BUY TAB =====================

local abp = pages["Auto Buy"]
local autoBuyEnabled = false
local unitCostMap = {
    ["Solar Panel"]=350,["Oil Rig"]=5000,["Gold Mine"]=100000,["Money Printer"]=350000,
    ["Brick Wall"]=10000,["Forcefield"]=250000,
    ["Noob"]=1000,["Barbed Wire"]=2500,["Archer"]=5000,["Mine"]=7500,
    ["Fire"]=10000,["Turret"]=35000,["Tesla Coil"]=50000,["Sniper"]=100000,
    ["Flamethrower"]=200000,["Cannon"]=300000,["Freeze Ray"]=500000,
    ["Minigun"]=1000000,["Leatherface"]=1250000,["UFO"]=2000000
}

mkLabel(abp, 0, "AUTO BUY")
mkToggle(abp, 16, "Auto Buy All Units", function(on) autoBuyEnabled = on setStatus(on and "Auto Buy ON" or "Auto Buy OFF") end)
mkLabel(abp, 65, "PRIORITY UNIT")

local priorityBox = Instance.new("TextBox")
priorityBox.Size = UDim2.new(1, 0, 0, 32)
priorityBox.Position = UDim2.new(0, 0, 0, 80)
priorityBox.BackgroundColor3 = Color3.fromRGB(18, 12, 30)
priorityBox.BorderSizePixel = 0
priorityBox.PlaceholderText = "e.g. Solar Panel"
priorityBox.PlaceholderColor3 = Color3.fromRGB(80, 60, 110)
priorityBox.Text = ""
priorityBox.TextColor3 = Color3.fromRGB(200, 180, 240)
priorityBox.TextSize = 11
priorityBox.Font = Enum.Font.Gotham
priorityBox.Parent = abp
Instance.new("UICorner", priorityBox).CornerRadius = UDim.new(0, 7)

-- ===================== AUTO PLACE TAB =====================

local app = pages["Auto Place"]
local placedStatLbl

mkToggle(app, 0, "Auto Place", function(on) autoPlace = on setStatus(on and "Auto Place ON" or "Auto Place OFF") end)
mkButton(app, 46, "Set Plot Position", function()
    local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    if not hrp then setStatus("No character!") return end
    plotCF = hrp.CFrame
    setStatus("Plot position saved!")
end)

mkLabel(app, 88, "STATS")

local statsRow = Instance.new("Frame")
statsRow.Size = UDim2.new(1, 0, 0, 28)
statsRow.Position = UDim2.new(0, 0, 0, 102)
statsRow.BackgroundTransparency = 1
statsRow.Parent = app

placedStatLbl = Instance.new("TextLabel")
placedStatLbl.Size = UDim2.new(0.5, -2, 1, 0)
placedStatLbl.BackgroundColor3 = Color3.fromRGB(18, 12, 30)
placedStatLbl.Text = "PLACED: 0"
placedStatLbl.TextColor3 = Color3.fromRGB(130, 60, 255)
placedStatLbl.TextSize = 10
placedStatLbl.Font = Enum.Font.GothamBold
placedStatLbl.Parent = statsRow
Instance.new("UICorner", placedStatLbl).CornerRadius = UDim.new(0, 5)

local trackStatLbl = Instance.new("TextLabel")
trackStatLbl.Size = UDim2.new(0.5, -2, 1, 0)
trackStatLbl.Position = UDim2.new(0.5, 2, 0, 0)
trackStatLbl.BackgroundColor3 = Color3.fromRGB(18, 12, 30)
trackStatLbl.Text = "UNITS: " .. #TRACKED_UNITS
trackStatLbl.TextColor3 = Color3.fromRGB(90, 60, 160)
trackStatLbl.TextSize = 10
trackStatLbl.Font = Enum.Font.GothamBold
trackStatLbl.Parent = statsRow
Instance.new("UICorner", trackStatLbl).CornerRadius = UDim.new(0, 5)

-- ===================== FEATURE LOGIC =====================

local function getHRP()
    local c = player.Character
    return c and c:FindFirstChild("HumanoidRootPart")
end

local function clickBtn(btn)
    if not btn or not btn.Parent then return end
    pcall(function()
        btn.MouseButton1Down:Fire()
        task.wait(0.04)
        btn.MouseButton1Up:Fire()
        btn.MouseButton1Click:Fire()
    end)
end

local function findGuiBtn(pattern)
    for _, gui in ipairs(player.PlayerGui:GetChildren()) do
        for _, d in ipairs(gui:GetDescendants()) do
            if (d:IsA("TextButton") or d:IsA("ImageButton")) and d.Visible then
                if string.find(string.lower(d.Text or ""), string.lower(pattern)) then
                    return d
                end
            end
        end
    end
    return nil
end

local function waitForBtn(pattern, timeout)
    local t = 0
    while t < timeout do
        local b = findGuiBtn(pattern)
        if b then return b end
        task.wait(0.05)
        t += 0.05
    end
    return nil
end

local function touchModel(model)
    local hrp = getHRP()
    if not hrp then return end
    for _, p in ipairs(model:GetDescendants()) do
        if p:IsA("BasePart") then
            pcall(function() firetouchinterest(hrp, p, 0) end)
            pcall(function() firetouchinterest(hrp, p, 1) end)
        end
    end
end

local function isTracked(name)
    for _, n in ipairs(TRACKED_UNITS) do
        if n == name then return true end
    end
    return false
end

-- AUTO PLACE
local function handleUnit(model, unitName)
    if isBusy or not autoPlace then return end
    if handled[model] then return end
    handled[model] = true
    isBusy = true

    local hrp = getHRP()
    if not hrp then isBusy = false handled[model] = nil return end

    local savedCF = hrp.CFrame
    local pivot = model.PrimaryPart
        or model:FindFirstChild("Handle")
        or model:FindFirstChild("HumanoidRootPart")
        or model:FindFirstChildWhichIsA("BasePart")

    if not pivot then isBusy = false handled[model] = nil return end

    setStatus("Detected: " .. unitName)

    hrp.CFrame = pivot.CFrame * CFrame.new(0, 2, 0)
    task.wait(0.15)
    touchModel(model)
    task.wait(0.1)

    for _, d in ipairs(model:GetDescendants()) do
        if d:IsA("ProximityPrompt") then pcall(function() fireproximityprompt(d) end) end
    end
    task.wait(0.05)

    local grabBtn = waitForBtn("grab", 1.2)
    if grabBtn then
        clickBtn(grabBtn) task.wait(0.1)
        clickBtn(grabBtn) task.wait(0.1)
    else
        hrp.CFrame = pivot.CFrame
        task.wait(0.1)
        touchModel(model)
        task.wait(0.1)
    end

    if plotCF then
        hrp.CFrame = plotCF * CFrame.new(0, 3, 0)
        task.wait(0.2)
        for _, pat in ipairs({"place","put","drop","confirm","ok"}) do
            local b = findGuiBtn(pat)
            if b then clickBtn(b) task.wait(0.08) end
        end
        for _, obj in ipairs(workspace:GetDescendants()) do
            if obj:IsA("BasePart") then
                local n = string.lower(obj.Name)
                if n:find("plot") or n:find("base") or n:find("floor") then
                    pcall(function() firetouchinterest(hrp, obj, 0) end)
                    pcall(function() firetouchinterest(hrp, obj, 1) end)
                    break
                end
            end
        end
        task.wait(0.1)
    else
        setStatus("Set plot position first!")
    end

    hrp.CFrame = savedCF
    placedCount += 1
    placedStatLbl.Text = "PLACED: " .. placedCount
    setStatus("Placed: " .. unitName)
    task.delay(4, function() handled[model] = nil end)
    isBusy = false
end

-- AUTO BUY
local function tryAutoBuy()
    if not autoBuyEnabled then return end
    local priority = priorityBox.Text:gsub("^%s+",""):gsub("%s+$","")
    local function tryBuyName(name)
        for _, gui in ipairs(player.PlayerGui:GetChildren()) do
            for _, d in ipairs(gui:GetDescendants()) do
                if d:IsA("TextLabel") and d.Text == name then
                    local par = d.Parent
                    if par then
                        for _, sib in ipairs(par:GetChildren()) do
                            if sib:IsA("TextButton") and string.lower(sib.Text) == "buy" then
                                clickBtn(sib)
                                setStatus("Bought: " .. name)
                                return true
                            end
                        end
                    end
                end
            end
        end
        return false
    end
    if priority ~= "" then tryBuyName(priority) return end
    for _, name in ipairs(TRACKED_UNITS) do if tryBuyName(name) then break end end
end

-- ZOMBIE ESP
local function updateESP()
    if not zombieESP then return end
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("Model") and obj:FindFirstChildWhichIsA("Humanoid") then
            local isPlayer = false
            for _, p in ipairs(Players:GetPlayers()) do if p.Character == obj then isPlayer = true break end end
            if not isPlayer and not espParts[obj] then
                local root = obj:FindFirstChild("HumanoidRootPart") or obj:FindFirstChildWhichIsA("BasePart")
                if root then
                    local box = Instance.new("SelectionBox")
                    box.Adornee = root
                    box.Color3 = Color3.fromRGB(255, 50, 50)
                    box.LineThickness = 0.05
                    box.SurfaceTransparency = 0.8
                    box.SurfaceColor3 = Color3.fromRGB(255, 50, 50)
                    box.Parent = workspace
                    espParts[obj] = box
                end
            end
        end
    end
    for obj, box in pairs(espParts) do
        if not obj or not obj.Parent then pcall(function() box:Destroy() end) espParts[obj] = nil end
    end
end

-- AUTO KILL
local function doAutoKill()
    if not autoKill then return end
    local hrp = getHRP()
    if not hrp then return end
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("Humanoid") and obj.Health > 0 then
            local par = obj.Parent
            local isPlayer = false
            for _, p in ipairs(Players:GetPlayers()) do if p.Character == par then isPlayer = true break end end
            if not isPlayer then
                local root = par and (par:FindFirstChild("HumanoidRootPart") or par:FindFirstChildWhichIsA("BasePart"))
                if root and (hrp.Position - root.Position).Magnitude < 60 then
                    pcall(function() obj:TakeDamage(math.huge) end)
                    pcall(function() firetouchinterest(hrp, root, 0) end)
                    pcall(function() firetouchinterest(hrp, root, 1) end)
                end
            end
        end
    end
end

-- AUTO COIN
local function doAutoCoin()
    if not autoCoin then return end
    local hrp = getHRP()
    if not hrp then return end
    for _, obj in ipairs(workspace:GetDescendants()) do
        local n = string.lower(obj.Name)
        if n:find("coin") or n:find("cash") or n:find("money") then
            local part = obj:IsA("BasePart") and obj or (obj:IsA("Model") and obj:FindFirstChildWhichIsA("BasePart"))
            if part then
                pcall(function() firetouchinterest(hrp, part, 0) end)
                pcall(function() firetouchinterest(hrp, part, 1) end)
            end
        end
    end
end

-- INSTANT SKIP
local function doInstantSkip()
    if not instantSkip then return end
    for _, gui in ipairs(player.PlayerGui:GetChildren()) do
        for _, d in ipairs(gui:GetDescendants()) do
            if (d:IsA("TextButton") or d:IsA("ImageButton")) then
                local t = string.upper(d.Text or "")
                if t == "SKIP" or t:find("^SKIP") then clickBtn(d) end
            end
        end
    end
    for _, obj in ipairs(game:GetDescendants()) do
        if obj:IsA("RemoteEvent") then
            local n = string.lower(obj.Name)
            if n:find("skip") or n:find("vote") or n:find("next") then
                pcall(function() obj:FireServer() end)
            end
        end
    end
end

-- ===================== LOOPS =====================

task.spawn(function()
    while task.wait(0.25) do
        if not autoPlace or isBusy then continue end
        for _, obj in ipairs(workspace:GetDescendants()) do
            if obj:IsA("Model") and isTracked(obj.Name) and not handled[obj] then
                task.spawn(handleUnit, obj, obj.Name)
                break
            end
        end
    end
end)

RunService.Heartbeat:Connect(function()
    doInstantSkip()
    doAutoKill()
    doAutoCoin()
    updateESP()
end)

task.spawn(function()
    while task.wait(0.5) do tryAutoBuy() end
end)

print("[Bunker Rush Hub] Loaded.")
setStatus("Loaded. All features ready.")
