-- ============================================================
--  ManesHub | Lag Machine + Select Block
--  Standalone client script
-- ============================================================

local Players       = game:GetService("Players")
local RunService    = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer   = Players.LocalPlayer

-- ============================================================
-- SHARED STATE
-- ============================================================
local SelectedBlock   = nil   -- currently selected BasePart
local isSelectingMode = false
local isSpamming      = false
local isProcessing    = false
local spamLoop        = nil
local currentWeld     = nil
local weldedBlock     = nil
local blockOriginalPosition = nil
local positionBeforeStop    = nil

-- Blackhole state
_G.LagMachineWebhook        = _G.LagMachineWebhook or {}
_G.BlackholeTargetPosition  = nil
_G.BlockAmountTracker       = _G.BlockAmountTracker or {}

-- ============================================================
-- GUI BUILDER
-- ============================================================
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name            = "ManesHub"
ScreenGui.ResetOnSpawn    = false
ScreenGui.ZIndexBehavior  = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent          = LocalPlayer.PlayerGui

-- Main window
local MainFrame = Instance.new("Frame")
MainFrame.Name            = "MainFrame"
MainFrame.Size            = UDim2.new(0, 220, 0, 360)
MainFrame.Position        = UDim2.new(0, 20, 0.5, -180)
MainFrame.BackgroundColor3 = Color3.fromRGB(18, 18, 18)
MainFrame.BorderSizePixel = 0
MainFrame.Active          = true
MainFrame.Parent          = ScreenGui

local UICorner = Instance.new("UICorner")
UICorner.CornerRadius = UDim.new(0, 8)
UICorner.Parent = MainFrame

-- Title bar
local TitleBar = Instance.new("Frame")
TitleBar.Name            = "TitleBar"
TitleBar.Size            = UDim2.new(1, 0, 0, 30)
TitleBar.BackgroundColor3 = Color3.fromRGB(0, 170, 255)
TitleBar.BorderSizePixel = 0
TitleBar.Parent          = MainFrame

local TitleCorner = Instance.new("UICorner")
TitleCorner.CornerRadius = UDim.new(0, 8)
TitleCorner.Parent = TitleBar

-- Patch bottom corners of title so they're square
local TitlePatch = Instance.new("Frame")
TitlePatch.Size = UDim2.new(1, 0, 0.5, 0)
TitlePatch.Position = UDim2.new(0, 0, 0.5, 0)
TitlePatch.BackgroundColor3 = Color3.fromRGB(0, 170, 255)
TitlePatch.BorderSizePixel = 0
TitlePatch.Parent = TitleBar

local TitleLabel = Instance.new("TextLabel")
TitleLabel.Text           = "ManesHub"
TitleLabel.Font           = Enum.Font.GothamBold
TitleLabel.TextSize       = 15
TitleLabel.TextColor3     = Color3.new(1, 1, 1)
TitleLabel.BackgroundTransparency = 1
TitleLabel.Size           = UDim2.new(1, -10, 1, 0)
TitleLabel.Position       = UDim2.new(0, 10, 0, 0)
TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
TitleLabel.Parent         = TitleBar

-- Drag window
do
    local dragging, dragStart, startPos
    TitleBar.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1
        or i.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = i.Position
            startPos  = MainFrame.Position
        end
    end)
    UserInputService.InputChanged:Connect(function(i)
        if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement
        or i.UserInputType == Enum.UserInputType.Touch) then
            local delta = i.Position - dragStart
            MainFrame.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + delta.X,
                startPos.Y.Scale, startPos.Y.Offset + delta.Y
            )
        end
    end)
    UserInputService.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1
        or i.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
end

-- Content area
local Content = Instance.new("Frame")
Content.Name = "Content"
Content.Size = UDim2.new(1, -16, 1, -38)
Content.Position = UDim2.new(0, 8, 0, 34)
Content.BackgroundTransparency = 1
Content.Parent = MainFrame

local ContentList = Instance.new("UIListLayout")
ContentList.SortOrder = Enum.SortOrder.LayoutOrder
ContentList.Padding    = UDim.new(0, 6)
ContentList.Parent     = Content

-- Accent colour (used for tick-box ON state)
local ACCENT = Color3.fromRGB(0, 170, 255)

-- ── Helper: make a label row ──────────────────────────────────
local function makeLabel(text, order)
    local lbl = Instance.new("TextLabel")
    lbl.Text              = text
    lbl.Font              = Enum.Font.GothamSemibold
    lbl.TextSize          = 12
    lbl.TextColor3        = Color3.fromRGB(160, 160, 160)
    lbl.BackgroundTransparency = 1
    lbl.Size              = UDim2.new(1, 0, 0, 16)
    lbl.TextXAlignment    = Enum.TextXAlignment.Left
    lbl.LayoutOrder       = order
    lbl.Parent            = Content
    return lbl
end

-- ── Helper: make a full-width button ─────────────────────────
local function makeButton(text, order)
    local btn = Instance.new("TextButton")
    btn.Text           = text
    btn.Font           = Enum.Font.GothamSemibold
    btn.TextSize       = 13
    btn.TextColor3     = Color3.new(1, 1, 1)
    btn.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    btn.BorderSizePixel = 0
    btn.Size           = UDim2.new(1, 0, 0, 28)
    btn.LayoutOrder    = order
    btn.Parent         = Content
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 5)
    c.Parent = btn
    return btn
end

-- ── Helper: make a tick-box row ───────────────────────────────
local function makeTickRow(labelText, order)
    local row = Instance.new("Frame")
    row.BackgroundTransparency = 1
    row.Size = UDim2.new(1, 0, 0, 26)
    row.LayoutOrder = order
    row.Parent = Content

    local tick = Instance.new("TextButton")
    tick.Size = UDim2.new(0, 18, 0, 18)
    tick.Position = UDim2.new(0, 0, 0.5, -9)
    tick.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    tick.BorderSizePixel = 0
    tick.Text = ""
    tick.Parent = row
    local tc = Instance.new("UICorner")
    tc.CornerRadius = UDim.new(0, 3)
    tc.Parent = tick

    local lbl = Instance.new("TextLabel")
    lbl.Text = labelText
    lbl.Font = Enum.Font.Gotham
    lbl.TextSize = 13
    lbl.TextColor3 = Color3.new(1, 1, 1)
    lbl.BackgroundTransparency = 1
    lbl.Size = UDim2.new(1, -26, 1, 0)
    lbl.Position = UDim2.new(0, 26, 0, 0)
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = row

    return row, tick
end

-- ── Helper: small number input ────────────────────────────────
local function makeInputRow(labelText, default, order)
    local row = Instance.new("Frame")
    row.BackgroundTransparency = 1
    row.Size = UDim2.new(1, 0, 0, 26)
    row.LayoutOrder = order
    row.Parent = Content

    local lbl = Instance.new("TextLabel")
    lbl.Text = labelText
    lbl.Font = Enum.Font.Gotham
    lbl.TextSize = 13
    lbl.TextColor3 = Color3.new(1, 1, 1)
    lbl.BackgroundTransparency = 1
    lbl.Size = UDim2.new(0.6, 0, 1, 0)
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = row

    local box = Instance.new("TextBox")
    box.Text = tostring(default)
    box.Font = Enum.Font.Gotham
    box.TextSize = 13
    box.TextColor3 = Color3.new(1, 1, 1)
    box.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
    box.BorderSizePixel = 0
    box.Size = UDim2.new(0.38, 0, 0, 22)
    box.Position = UDim2.new(0.62, 0, 0.5, -11)
    box.Parent = row
    local bc = Instance.new("UICorner")
    bc.CornerRadius = UDim.new(0, 4)
    bc.Parent = box

    return row, box
end

-- ── Helper: divider ───────────────────────────────────────────
local function makeDivider(order)
    local d = Instance.new("Frame")
    d.Size = UDim2.new(1, 0, 0, 1)
    d.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
    d.BorderSizePixel = 0
    d.LayoutOrder = order
    d.Parent = Content
    return d
end

-- ============================================================
-- BUILD UI ROWS
-- ============================================================
makeLabel("── SELECT BLOCK ──", 1)

local SelectButton = makeButton("Select Block", 2)

makeDivider(3)
makeLabel("── LAG MACHINE ──", 4)

local StartSpamButton = makeButton("Start Spam", 5)

local _, BlockSizeBox = makeInputRow("Block Size (1-6)", 1, 6)

local _, ReduceLagTick   = makeTickRow("Reduce Lag (local)", 7)
local _, BlackholeTick   = makeTickRow("Blackhole Mode", 8)
local _, OrbitTick       = makeTickRow("Orbit Blackhole", 9)
local _, OrbitSpeedBox   = makeInputRow("Orbit Speed", 10, 10)

makeDivider(11)

local BlockCountLabel = makeLabel("Block Count: 0", 12)

-- ============================================================
-- TOOL HELPERS
-- ============================================================
local function getTool(name)
    return LocalPlayer.Backpack:FindFirstChild(name)
        or (LocalPlayer.Character and LocalPlayer.Character:FindFirstChild(name))
end

local function getEvent(toolName)
    local t = getTool(toolName)
    return t and t:FindFirstChild("Script") and t.Script:FindFirstChild("Event")
end

local function getBuildUI()
    return LocalPlayer.PlayerGui:FindFirstChild("Build")
end

local function refreshBuildTool()
    local tool = getTool("Build")
    if not tool then return false end
    local buildUI = getBuildUI()
    if not buildUI then return false end
    local char = LocalPlayer.Character
    if not char then return false end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return false end
    hum:UnequipTools(); task.wait(0.03)
    hum:EquipTool(tool)
    RunService.RenderStepped:Wait()
    buildUI.Enabled = true
    hum:UnequipTools()
    task.wait(0.05)
    buildUI.Enabled = true
    return true
end

-- ============================================================
-- HIGHLIGHT
-- ============================================================
local currentHighlight = nil

local function removeHighlight()
    if currentHighlight then
        currentHighlight:Destroy()
        currentHighlight = nil
    end
end

local function highlightBlock(block)
    removeHighlight()
    if not block or not block:IsA("BasePart") then return end
    local h = Instance.new("Highlight")
    h.Adornee           = block
    h.FillColor         = Color3.fromRGB(255, 255, 0)
    h.OutlineColor      = Color3.fromRGB(255, 200, 0)
    h.FillTransparency  = 0.5
    h.OutlineTransparency = 0
    h.Parent            = block
    currentHighlight = h
end

-- ============================================================
-- SELECT BLOCK LOGIC
-- ============================================================
local mouseConn = nil

local TEXT_DEFAULT   = "Select Block"
local TEXT_SELECTING = "Select a block..."
local TEXT_SELECTED  = "✓ Block Selected"

local function unselectBlock()
    SelectedBlock = nil
    removeHighlight()
    isSelectingMode = false
    SelectButton.Text = TEXT_DEFAULT
end

local function selectBlock(block)
    if not block or not block:IsA("BasePart") or block.Name ~= "Brick" then return false end
    local parent = block.Parent
    if not parent or parent.Parent ~= workspace:FindFirstChild("Bricks") then return false end
    SelectedBlock = block
    highlightBlock(block)
    isSelectingMode = false
    SelectButton.Text = TEXT_SELECTED

    -- Auto-unselect on deletion
    block.AncestryChanged:Connect(function()
        if SelectedBlock == block and not block:IsDescendantOf(workspace) then
            unselectBlock()
        end
    end)
    return true
end

local function stopSelecting()
    isSelectingMode = false
    if mouseConn then mouseConn:Disconnect(); mouseConn = nil end
    SelectButton.Text = SelectedBlock and TEXT_SELECTED or TEXT_DEFAULT
end

local function startSelecting()
    isSelectingMode = true
    SelectButton.Text = TEXT_SELECTING
    if mouseConn then mouseConn:Disconnect(); mouseConn = nil end
    local mouse = LocalPlayer:GetMouse()
    mouseConn = mouse.Button1Down:Connect(function()
        if not isSelectingMode then return end
        local target = mouse.Target
        if not target then return end
        if SelectedBlock == target then
            unselectBlock()
        else
            if selectBlock(target) then
                if mouseConn then mouseConn:Disconnect(); mouseConn = nil end
            end
        end
    end)
end

SelectButton.MouseButton1Click:Connect(function()
    if isSelectingMode then
        stopSelecting()
    elseif SelectedBlock then
        startSelecting()
    else
        startSelecting()
    end
end)

-- ============================================================
-- BLOCK SIZE
-- ============================================================
local targetBlockSize = 1

BlockSizeBox:GetPropertyChangedSignal("Text"):Connect(function()
    BlockSizeBox.Text = BlockSizeBox.Text:gsub("[^%d]", "")
end)
BlockSizeBox.FocusLost:Connect(function()
    local n = tonumber(BlockSizeBox.Text) or 1
    n = math.clamp(math.floor(n), 1, 6)
    targetBlockSize = n
    BlockSizeBox.Text = tostring(n)
end)

-- ============================================================
-- BLOCK COUNT TRACKER
-- ============================================================
local spamBlockCount = 0

local function updateBlockCount()
    BlockCountLabel.Text = "Block Count: " .. spamBlockCount
end

local function markAndTrackBlock(block)
    if not block or not block:IsA("BasePart") then return end
    if block:GetAttribute("ManesSpamBlock") then return end
    block:SetAttribute("ManesSpamBlock", true)
    spamBlockCount = spamBlockCount + 1
    updateBlockCount()
    block.AncestryChanged:Connect(function()
        if not block:IsDescendantOf(workspace) and block:GetAttribute("ManesSpamBlock") then
            spamBlockCount = math.max(0, spamBlockCount - 1)
            updateBlockCount()
        end
    end)
end

local blockWatcher = nil

_G.BlockAmountTracker.StartWatching = function()
    if blockWatcher then return end
    local bricks = workspace:FindFirstChild("Bricks")
    if not bricks then return end
    local folder = bricks:FindFirstChild(LocalPlayer.Name)
    if not folder then return end
    blockWatcher = folder.ChildAdded:Connect(function(child)
        if child.Name == "Brick" and child:IsA("BasePart") then
            markAndTrackBlock(child)
        end
    end)
end

_G.BlockAmountTracker.StopWatching = function()
    if blockWatcher then blockWatcher:Disconnect(); blockWatcher = nil end
end

-- ============================================================
-- SPAM STEPS
-- ============================================================
local function removeAllSprays(block)
    local paintEvent = getEvent("Paint")
    if not paintEvent then return false end
    local sides = {
        {Enum.NormalId.Front,  block.Position + block.CFrame.LookVector  * block.Size.Z/2},
        {Enum.NormalId.Right,  block.Position + block.CFrame.RightVector * block.Size.X/2},
        {Enum.NormalId.Back,   block.Position - block.CFrame.LookVector  * block.Size.Z/2},
        {Enum.NormalId.Left,   block.Position - block.CFrame.RightVector * block.Size.X/2},
        {Enum.NormalId.Top,    block.Position + block.CFrame.UpVector    * block.Size.Y/2},
        {Enum.NormalId.Bottom, block.Position - block.CFrame.UpVector    * block.Size.Y/2},
    }
    for i = 1, 5 do
        if not isSpamming then return false end
        for _, sd in ipairs(sides) do
            if not isSpamming then return false end
            pcall(function() paintEvent:FireServer(block, sd[1], sd[2], "both 🤝", Color3.fromRGB(2,2,1), "spray", "") end)
            task.wait(0.02)
        end
    end
    return true
end

local function paintAndToxify(block)
    local c = block.Color
    local colorOk = (c.R*255 >= 1 and c.R*255 <= 3) and (c.G*255 >= 1 and c.G*255 <= 3) and (c.B*255 >= 0 and c.B*255 <= 2)
    if colorOk and block.Material == Enum.Material.Neon then return true end
    for _, ch in ipairs(block:GetChildren()) do if ch.Name == "Spray" then return false end end
    local pe = getEvent("Paint"); if not pe then return false end
    for i = 1, 5 do
        if not isSpamming then return false end
        pcall(function() pe:FireServer(block, Enum.NormalId.Top, block.Position, "both 🤝", Color3.fromRGB(2,2,1), "toxic", "") end)
        task.wait(0.05)
    end
    return true
end

local function unanchorBlock(block)
    if block:FindFirstChild("Drag") then return true end
    local pe = getEvent("Paint"); if not pe then return false end
    local bottomPos = block.Position - (block.CFrame.UpVector * block.Size.Y/2)
    local t0 = tick()
    while tick() - t0 < 2 do
        if not isSpamming then return false end
        pcall(function() pe:FireServer(block, Enum.NormalId.Bottom, bottomPos, "material", Color3.fromRGB(2,2,1), "anchor", "") end)
        task.wait(0.2)
        if block:FindFirstChild("Drag") then return true end
    end
    return false
end

local function resizeBlock(block, sz)
    if block.Size == Vector3.new(sz, sz, sz) then return true end
    for attempt = 1, 3 do
        if not isSpamming then return false end
        local se = getEvent("Shape")
        if not se then
            local st = getTool("Shape")
            if st and st.Parent == LocalPlayer.Backpack then
                LocalPlayer.Character.Humanoid:EquipTool(st); task.wait(0.2)
            else return false end
            se = getEvent("Shape"); if not se then return false end
        end
        for _ = 1, 40 do
            if not isSpamming then return false end
            local cur = block.Size
            if cur == Vector3.new(sz, sz, sz) then return true end
            local pos = block.Position; local s = block.Size
            if cur.X ~= sz then pcall(function() se:FireServer(block, Enum.NormalId.Right,  Vector3.new(pos.X+s.X/2,pos.Y,pos.Z), cur.X<sz and "increase" or "decrease") end); task.wait(0.08) end
            if cur.Y ~= sz then pcall(function() se:FireServer(block, Enum.NormalId.Top,    Vector3.new(pos.X,pos.Y+s.Y/2,pos.Z), cur.Y<sz and "increase" or "decrease") end); task.wait(0.08) end
            if cur.Z ~= sz then pcall(function() se:FireServer(block, Enum.NormalId.Back,   Vector3.new(pos.X,pos.Y,pos.Z-s.Z/2), cur.Z<sz and "increase" or "decrease") end); task.wait(0.08) end
            task.wait(0.2)
        end
        if attempt < 3 then task.wait(0.3) end
    end
    local f = block.Size; return f.X == sz and f.Y == sz and f.Z == sz
end

local function sprayAllSides(block)
    local pe = getEvent("Paint"); if not pe then return false end
    local sprayText = string.rep("#", 132)
    local sides = {
        {Enum.NormalId.Front,  block.Position + block.CFrame.LookVector  * block.Size.Z/2},
        {Enum.NormalId.Right,  block.Position + block.CFrame.RightVector * block.Size.X/2},
        {Enum.NormalId.Back,   block.Position - block.CFrame.LookVector  * block.Size.Z/2},
        {Enum.NormalId.Left,   block.Position - block.CFrame.RightVector * block.Size.X/2},
        {Enum.NormalId.Top,    block.Position + block.CFrame.UpVector    * block.Size.Y/2},
        {Enum.NormalId.Bottom, block.Position - block.CFrame.UpVector    * block.Size.Y/2},
    }
    local deadline = tick() + 5
    while tick() < deadline do
        if not isSpamming then return false end
        local n = 0
        for _, c in ipairs(block:GetChildren()) do if c.Name == "Spray" then n += 1 end end
        if n >= 6 then return true end
        for _, sd in ipairs(sides) do
            if not isSpamming then return false end
            pcall(function() pe:FireServer(block, sd[1], sd[2], "both 🤝", Color3.fromRGB(2,2,1), "spray", sprayText) end)
            task.wait(0.05)
        end
    end
    return true
end

-- ============================================================
-- WELD / SPAM LOOP
-- ============================================================
local function cleanupWeld()
    local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if hrp then
        if currentWeld and currentWeld.Parent then currentWeld:Destroy() end
        local w = hrp:FindFirstChild("ManesSpamWeld"); if w then w:Destroy() end
        for _, c in ipairs(hrp:GetChildren()) do
            if c:IsA("WeldConstraint") and weldedBlock and (c.Part0 == weldedBlock or c.Part1 == weldedBlock) then
                c:Destroy()
            end
        end
    end
    currentWeld = nil
    task.wait(0.15)
    if weldedBlock and weldedBlock:IsDescendantOf(workspace) then
        weldedBlock.CanCollide = true
        if blockOriginalPosition then
            weldedBlock.CFrame = blockOriginalPosition
            weldedBlock.AssemblyLinearVelocity = Vector3.zero
            weldedBlock.AssemblyAngularVelocity = Vector3.zero
        end
    end
    weldedBlock = nil; blockOriginalPosition = nil
end

local function stopSpam()
    isSpamming = false; isProcessing = false
    StartSpamButton.Text = "Start Spam"
    spamLoop = nil
    _G.BlockAmountTracker.StopWatching()
    cleanupWeld()
    local ui = getBuildUI(); if ui then ui.Enabled = true end
    positionBeforeStop = nil
    if _G.LagMachineWebhook.OnLagEnded then _G.LagMachineWebhook.OnLagEnded() end
end

local function startSpamBuilding(block)
    if not getTool("Build") then StartSpamButton.Text = "No Build tool"; task.wait(1); StartSpamButton.Text = "Start Spam"; return false end
    if not getBuildUI()     then StartSpamButton.Text = "No Build UI";   task.wait(1); StartSpamButton.Text = "Start Spam"; return false end
    if not refreshBuildTool() then StartSpamButton.Text = "Activate failed"; task.wait(1); StartSpamButton.Text = "Start Spam"; return false end

    isSpamming = true
    StartSpamButton.Text = "Stop Spam"
    if _G.LagMachineWebhook.OnLagStarted then _G.LagMachineWebhook.OnLagStarted() end
    local ui = getBuildUI(); if ui then ui.Enabled = false end
    _G.BlockAmountTracker.StartWatching()

    spamLoop = task.spawn(function()
        local refreshCounter = 0
        while isSpamming do
            if not getTool("Build") then stopSpam(); break end
            if not block or not block:IsDescendantOf(workspace) or not block:FindFirstChild("Drag") then stopSpam(); break end
            local ev = getEvent("Build"); local bui = getBuildUI()
            if ev and bui then
                pcall(function()
                    local spawnPos = _G.BlackholeTargetPosition or block.Position
                    ev:FireServer(block, Enum.NormalId.Top, spawnPos, bui.Button.Text)
                end)
            else
                refreshBuildTool()
            end
            refreshCounter += 1
            if refreshCounter >= 50 then refreshBuildTool(); refreshCounter = 0 end
            task.wait(0.05)
        end
    end)
    return true
end

local function processBlock(block)
    if not block or not block:IsDescendantOf(workspace) then return false end
    local sz = targetBlockSize
    if not getTool("Paint") or not getTool("Shape") then
        StartSpamButton.Text = "Tools not found"; task.wait(1); StartSpamButton.Text = "Start Spam"; return false
    end

    if _G.LagMachineWebhook.OnProcessingStarted then _G.LagMachineWebhook.OnProcessingStarted() end
    isProcessing = true; isSpamming = true
    StartSpamButton.Text = "Stop Spam"

    local prevTool = LocalPlayer.Character:FindFirstChildOfClass("Tool")
    if not positionBeforeStop then positionBeforeStop = LocalPlayer.Character.HumanoidRootPart.CFrame end
    local origCF = positionBeforeStop
    blockOriginalPosition = block.CFrame

    -- Teleport under block
    local underPos = block.Position - Vector3.new(0, 20, 0)
    LocalPlayer.Character.HumanoidRootPart.CFrame = CFrame.new(underPos)
    LocalPlayer.Character.HumanoidRootPart.AssemblyLinearVelocity = Vector3.zero

    local lock = RunService.RenderStepped:Connect(function()
        if block:IsDescendantOf(workspace) and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
            LocalPlayer.Character.HumanoidRootPart.CFrame = CFrame.new(block.Position - Vector3.new(0,20,0))
            LocalPlayer.Character.HumanoidRootPart.AssemblyLinearVelocity = Vector3.zero
        end
    end)

    -- Equip paint
    local pt = getTool("Paint"); if pt and pt.Parent == LocalPlayer.Backpack then LocalPlayer.Character.Humanoid:EquipTool(pt); task.wait(0.3) end

    -- Check if block is already ready
    local correctSprays = 0
    for _, c in ipairs(block:GetChildren()) do
        if c.Name == "Spray" then
            local lbl = c:FindFirstChild("Label")
            if lbl and lbl.Text and lbl.Text:find("#") then correctSprays += 1 end
        end
    end
    local col = block.Color
    local colorOk = (col.R*255 >= 1 and col.R*255 <= 3) and (col.G*255 >= 1 and col.G*255 <= 3) and (col.B*255 >= 0 and col.B*255 <= 2)
    local ready = correctSprays == 6 and colorOk and block.Material == Enum.Material.Neon and block.Size == Vector3.new(sz,sz,sz)

    local function finishAndWeld()
        LocalPlayer.Character.Humanoid:UnequipTools(); task.wait(0.1)
        if prevTool and prevTool.Parent == LocalPlayer.Backpack then LocalPlayer.Character.Humanoid:EquipTool(prevTool) end
        lock:Disconnect(); task.wait(0.1)
        if not isSpamming then LocalPlayer.Character.HumanoidRootPart.CFrame = origCF; return false end
        block.CanCollide = false
        LocalPlayer.Character.HumanoidRootPart.CFrame = CFrame.new(block.Position - Vector3.new(0,8,0))
        LocalPlayer.Character.HumanoidRootPart.AssemblyLinearVelocity = Vector3.zero
        task.wait(0.1)
        local weld = Instance.new("WeldConstraint")
        weld.Name = "ManesSpamWeld"; weld.Part0 = LocalPlayer.Character.HumanoidRootPart; weld.Part1 = block
        weld.Parent = LocalPlayer.Character.HumanoidRootPart
        task.wait(0.2)
        LocalPlayer.Character.HumanoidRootPart.CFrame = origCF
        if _G.LagMachineWebhook.OnProcessingFinished then _G.LagMachineWebhook.OnProcessingFinished() end
        currentWeld = weld; weldedBlock = block
        StartSpamButton.Text = "Stop Spam"
        if not startSpamBuilding(block) then cleanupWeld(); LocalPlayer.Character.HumanoidRootPart.CFrame = origCF; return false end
        return true
    end

    if ready then
        return finishAndWeld()
    end

    -- Steps
    local function abort(msg)
        lock:Disconnect()
        LocalPlayer.Character.Humanoid:UnequipTools()
        LocalPlayer.Character.HumanoidRootPart.CFrame = origCF
        if msg then StartSpamButton.Text = msg; task.wait(2) end
        StartSpamButton.Text = "Start Spam"
        isSpamming = false; isProcessing = false
    end

    if not isSpamming then abort(nil); return false end

    -- Remove existing sprays
    local hasSpray = false
    for _, c in ipairs(block:GetChildren()) do if c.Name == "Spray" then hasSpray = true; break end end
    if hasSpray and not removeAllSprays(block) then abort("Spray remove failed"); return false end
    if not isSpamming then abort(nil); return false end
    if not removeAllSprays(block) then abort("Spray remove failed"); return false end
    if not isSpamming then abort(nil); return false end
    if not paintAndToxify(block) then abort("Paint failed"); return false end
    if not isSpamming then abort(nil); return false end
    if not unanchorBlock(block) then abort("Unanchor failed"); return false end
    if not isSpamming then abort(nil); return false end

    -- Shape
    local st = getTool("Shape"); if st and st.Parent == LocalPlayer.Backpack then LocalPlayer.Character.Humanoid:EquipTool(st); task.wait(0.2) end
    if not resizeBlock(block, sz) then abort("Resize failed"); return false end

    -- Re-equip paint for spraying
    local pt2 = getTool("Paint"); if pt2 and pt2.Parent == LocalPlayer.Backpack then LocalPlayer.Character.Humanoid:EquipTool(pt2); task.wait(0.2) end
    if correctSprays ~= 6 then
        if not isSpamming then abort(nil); return false end
        task.wait(0.1); sprayAllSides(block)
    end

    if not isSpamming then abort(nil); return false end
    return finishAndWeld()
end

-- ============================================================
-- START SPAM BUTTON
-- ============================================================
StartSpamButton.MouseButton1Click:Connect(function()
    if isSpamming then
        stopSpam()
    else
        if not SelectedBlock or not SelectedBlock:IsDescendantOf(workspace) then
            StartSpamButton.Text = "No Block Selected!"; task.wait(1); StartSpamButton.Text = "Start Spam"; return
        end
        isProcessing = true
        StartSpamButton.Text = "Processing..."
        if not processBlock(SelectedBlock) then
            StartSpamButton.Text = "Failed – Press Again"; task.wait(1)
            isProcessing = false; StartSpamButton.Text = "Start Spam"
        end
    end
end)

-- ============================================================
-- REDUCE LAG (local visual optimisation)
-- ============================================================
local reduceLagEnabled = false
local trackedReduceBlocks = {}

local function disableBlockEffects(block)
    if not block or not block:GetAttribute("ManesSpamBlock") then return end
    if not trackedReduceBlocks[block] then
        trackedReduceBlocks[block] = { Material = block.Material, CastShadow = block.CastShadow, Sprays = {}, Light = nil }
    end
    if block.Material == Enum.Material.Neon then trackedReduceBlocks[block].Material = Enum.Material.Neon end
    block.Material = Enum.Material.Air; block.CastShadow = false
    for _, c in ipairs(block:GetChildren()) do
        if c.Name == "Spray" and (c:IsA("Texture") or c:IsA("Decal") or c:IsA("SurfaceGui")) then
            if c.Enabled then trackedReduceBlocks[block].Sprays[c] = true end
            c.Enabled = false
        end
    end
    local light = block:FindFirstChildOfClass("Light")
    if light and light.Enabled then trackedReduceBlocks[block].Light = true; light.Enabled = false end
end

local function restoreBlockEffects(block)
    if not block or not block:GetAttribute("ManesSpamBlock") then return end
    local orig = trackedReduceBlocks[block]
    block.Material = (orig and orig.Material) or Enum.Material.Neon
    block.CastShadow = (orig and orig.CastShadow ~= nil) and orig.CastShadow or true
    for _, c in ipairs(block:GetChildren()) do
        if c.Name == "Spray" and (c:IsA("Texture") or c:IsA("Decal") or c:IsA("SurfaceGui")) then
            c.Enabled = (orig and orig.Sprays[c] ~= nil) and orig.Sprays[c] or true
        end
    end
    local light = block:FindFirstChildOfClass("Light")
    if light then light.Enabled = (orig and orig.Light) or true end
    if orig then trackedReduceBlocks[block] = nil end
end

local function processAllReduceBlocks()
    local bricks = workspace:FindFirstChild("Bricks")
    if not bricks then return end
    local folder = bricks:FindFirstChild(LocalPlayer.Name)
    if not folder then return end
    for _, b in ipairs(folder:GetChildren()) do
        if b.Name == "Brick" and b:GetAttribute("ManesSpamBlock") then
            if reduceLagEnabled then disableBlockEffects(b) else restoreBlockEffects(b) end
        end
    end
end

ReduceLagTick.MouseButton1Click:Connect(function()
    reduceLagEnabled = not reduceLagEnabled
    ReduceLagTick.BackgroundColor3 = reduceLagEnabled and ACCENT or Color3.fromRGB(0,0,0)
    processAllReduceBlocks()
end)

-- ============================================================
-- BLACKHOLE
-- ============================================================
local bhEnabled     = false
local bhHandles     = nil
local bhBodyPosMap  = {}
local bhMonitor     = nil
local bhSizeWatch   = nil
local bhDragConns   = {}
local bhTargetPos   = nil
local bhLastPos     = nil
local bhPaused      = false

local PICKUP_RADIUS = 2000
LocalPlayer.ReplicationFocus = workspace
pcall(function() sethiddenproperty(LocalPlayer, "SimulationRadius", PICKUP_RADIUS) end)

local function isTrulyUnanchored(p) return not p:IsGrounded() end

local function addBodyPos(block)
    if bhBodyPosMap[block] then return end
    local props = { canCollide = block.CanCollide, canTouch = block.CanTouch, cPhys = block.CustomPhysicalProperties }
    block.CustomPhysicalProperties = PhysicalProperties.new(0.01,0,0,0,0)
    block.CanCollide = false; block.CanTouch = false
    local mass = block:GetMass()
    local bp = Instance.new("BodyPosition")
    bp.Name = "ManesBH"; bp.P = mass/0.64e-5; bp.D = mass/0.64e-3
    bp.MaxForce = Vector3.one * (mass/0.64e-6); bp.Parent = block
    bhBodyPosMap[block] = { bp = bp, props = props }
end

local function isBHBlock(obj)
    if not (obj:IsA("BasePart") or obj:IsA("UnionOperation")) then return false end
    if obj.Anchored then return false end
    for _, p in ipairs(Players:GetPlayers()) do
        if p.Character and obj:IsDescendantOf(p.Character) then return false end
    end
    local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if hrp then
        for _, c in ipairs(hrp:GetChildren()) do
            if c:IsA("WeldConstraint") and c.Name == "ManesSpamWeld" then
                if c.Part0 == obj or c.Part1 == obj then return false end
            end
        end
    end
    if not obj:FindFirstChild("Drag") then return false end
    if not isTrulyUnanchored(obj) then return false end
    return true
end

local function bhCheckAdd(obj) if isBHBlock(obj) and not bhBodyPosMap[obj] then addBodyPos(obj) end end

local function createBHHandles()
    local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    local sz = targetBlockSize + 1
    local spawnPos = bhLastPos or Vector3.new(hrp.Position.X, hrp.Position.Y + 10, hrp.Position.Z)

    bhHandles = Instance.new("Part")
    bhHandles.Name = "ManesBlackhole"; bhHandles.Size = Vector3.one * sz
    bhHandles.Position = spawnPos; bhHandles.Anchored = true
    bhHandles.CanCollide = false; bhHandles.Transparency = 0.5
    bhHandles.Material = Enum.Material.ForceField; bhHandles.BrickColor = BrickColor.new("Bright blue")
    bhHandles.Parent = workspace

    local sel = Instance.new("SelectionBox")
    sel.Adornee = bhHandles; sel.LineThickness = 0.05
    sel.Color3 = Color3.fromRGB(0,170,255); sel.Parent = bhHandles

    bhTargetPos = bhHandles.Position
    _G.BlackholeTargetPosition = bhTargetPos

    -- Drag system
    local dragging, dragStart, dragStartPos, origCamType
    local function startDrag(i)
        if bhOrbitEnabled then return end
        dragging = true; dragStart = i.Position; dragStartPos = bhHandles.Position
        local cam = workspace.CurrentCamera; origCamType = cam.CameraType
        cam.CameraType = Enum.CameraType.Scriptable
    end
    local function updateDrag(i)
        if not dragging then return end
        local cam = workspace.CurrentCamera; local delta = i.Position - dragStart
        local wd = cam.CFrame.RightVector*(delta.X*0.05) + cam.CFrame.UpVector*(-delta.Y*0.05)
        bhHandles.Position = dragStartPos + wd; bhTargetPos = bhHandles.Position
        _G.BlackholeTargetPosition = bhTargetPos
    end
    local function stopDrag()
        dragging = false; dragStart = nil; dragStartPos = nil
        if origCamType then workspace.CurrentCamera.CameraType = origCamType; origCamType = nil end
    end

    table.insert(bhDragConns, UserInputService.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            if LocalPlayer:GetMouse().Target == bhHandles then startDrag(i) end
        end
    end))
    table.insert(bhDragConns, UserInputService.InputChanged:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch then updateDrag(i) end
    end))
    table.insert(bhDragConns, UserInputService.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then stopDrag() end
    end))

    bhSizeWatch = RunService.Heartbeat:Connect(function()
        if bhEnabled and bhHandles then bhHandles.Size = Vector3.one * (targetBlockSize+1) end
    end)
end

local bhOrbitEnabled = false
local bhOrbitSpeed   = 10

local function destroyBHHandles()
    if workspace.CurrentCamera.CameraType == Enum.CameraType.Scriptable then
        workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
    end
    if bhHandles then bhHandles:Destroy(); bhHandles = nil end
    for _, c in ipairs(bhDragConns) do c:Disconnect() end; bhDragConns = {}
    if bhSizeWatch then bhSizeWatch:Disconnect(); bhSizeWatch = nil end
    bhTargetPos = nil; _G.BlackholeTargetPosition = nil
end

local function releaseAllBH()
    for block, data in pairs(bhBodyPosMap) do
        if block and block.Parent then
            if data.bp and data.bp.Parent then data.bp:Destroy() end
            if data.props then
                block.CustomPhysicalProperties = data.props.cPhys
                block.CanCollide = data.props.canCollide; block.CanTouch = data.props.canTouch
            end
            block.AssemblyLinearVelocity = Vector3.new(
                math.random()*2-1, math.random()*2-1, math.random()*2-1).Unit * 500
        end
    end
    bhBodyPosMap = {}
end

local function enableBH()
    bhEnabled = true
    BlackholeTick.BackgroundColor3 = ACCENT
    for _, obj in ipairs(workspace:GetDescendants()) do bhCheckAdd(obj) end
    workspace.DescendantAdded:Connect(function(obj) if bhEnabled then bhCheckAdd(obj) end end)
    createBHHandles()
    bhMonitor = RunService.Heartbeat:Connect(function()
        if not bhEnabled or not bhTargetPos then return end
        if bhOrbitEnabled then
            local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            if hrp and bhHandles then
                local t = tick() / (35/bhOrbitSpeed) * math.pi * 2
                bhHandles.Position = hrp.Position + Vector3.new(math.cos(t)*15, 0, math.sin(t)*15)
                bhTargetPos = bhHandles.Position; _G.BlackholeTargetPosition = bhTargetPos
            end
        end
        if not bhPaused then
            for block, data in pairs(bhBodyPosMap) do
                if block and block.Parent and data.bp and data.bp.Parent then data.bp.Position = bhTargetPos end
            end
        end
        pcall(function() sethiddenproperty(LocalPlayer, "SimulationRadius", PICKUP_RADIUS) end)
    end)
end

local function disableBH()
    bhEnabled = false
    BlackholeTick.BackgroundColor3 = Color3.fromRGB(0,0,0)
    if bhHandles then bhLastPos = bhHandles.Position end
    if bhMonitor then bhMonitor:Disconnect(); bhMonitor = nil end
    releaseAllBH(); destroyBHHandles()
end

BlackholeTick.MouseButton1Click:Connect(function()
    if bhEnabled then disableBH() else enableBH() end
end)
BlackholeTick.BackgroundColor3 = Color3.fromRGB(0,0,0)

-- Orbit toggle
OrbitTick.MouseButton1Click:Connect(function()
    bhOrbitEnabled = not bhOrbitEnabled
    OrbitTick.BackgroundColor3 = bhOrbitEnabled and ACCENT or Color3.fromRGB(0,0,0)
end)
OrbitTick.BackgroundColor3 = Color3.fromRGB(0,0,0)

-- Orbit speed
OrbitSpeedBox:GetPropertyChangedSignal("Text"):Connect(function()
    OrbitSpeedBox.Text = OrbitSpeedBox.Text:gsub("[^%d%.]", "")
end)
OrbitSpeedBox.FocusLost:Connect(function()
    local n = tonumber(OrbitSpeedBox.Text); if n and n > 0 then bhOrbitSpeed = n else OrbitSpeedBox.Text = tostring(bhOrbitSpeed) end
end)

-- Webhook hooks for blackhole <-> blockspam sync
_G.LagMachineWebhook.OnProcessingStarted = function()
    if bhEnabled then bhPaused = true end
end
_G.LagMachineWebhook.OnProcessingFinished = function()
    if bhEnabled then bhPaused = false end
end

print("[ManesHub] Loaded — Lag Machine + Select Block ready")
