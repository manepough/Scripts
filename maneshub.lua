-- ManesHub

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local mouse = player:GetMouse()

-- ScreenGui
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "ManesHub"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = player.PlayerGui

-- Blur
local blur = Instance.new("BlurEffect")
blur.Size = 0
blur.Parent = game.Lighting

-- Main window
local bg = Instance.new("Frame")
bg.Size = UDim2.new(0, 500, 0, 320)
bg.Position = UDim2.new(0.5, -250, 0.5, -160)
bg.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
bg.BackgroundTransparency = 0
bg.BorderSizePixel = 0
bg.Visible = false
bg.ZIndex = 5
bg.Parent = screenGui
Instance.new("UICorner", bg).CornerRadius = UDim.new(0, 10)
local bgStroke = Instance.new("UIStroke", bg)
bgStroke.Color = Color3.fromRGB(60, 60, 60)
bgStroke.Thickness = 1

-- Title bar
local titleBar = Instance.new("Frame")
titleBar.Size = UDim2.new(1, 0, 0, 34)
titleBar.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
titleBar.BackgroundTransparency = 0
titleBar.BorderSizePixel = 0
titleBar.ZIndex = 6
titleBar.Parent = bg
local tbCorner = Instance.new("UICorner", titleBar)
tbCorner.CornerRadius = UDim.new(0, 10)
local tbFix = Instance.new("Frame", titleBar)
tbFix.Size = UDim2.new(1, 0, 0.5, 0)
tbFix.Position = UDim2.new(0, 0, 0.5, 0)
tbFix.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
tbFix.BackgroundTransparency = 0
tbFix.BorderSizePixel = 0
tbFix.ZIndex = 6

local titleLbl = Instance.new("TextLabel", titleBar)
titleLbl.Size = UDim2.new(1, -50, 1, 0)
titleLbl.Position = UDim2.new(0, 14, 0, 0)
titleLbl.BackgroundTransparency = 1
titleLbl.Font = Enum.Font.GothamBold
titleLbl.TextSize = 13
titleLbl.TextColor3 = Color3.fromRGB(220, 220, 220)
titleLbl.Text = "ManesHub"
titleLbl.TextXAlignment = Enum.TextXAlignment.Left
titleLbl.ZIndex = 7

local closeBtn = Instance.new("TextButton", titleBar)
closeBtn.Size = UDim2.new(0, 24, 0, 24)
closeBtn.Position = UDim2.new(1, -30, 0.5, -12)
closeBtn.BackgroundColor3 = Color3.fromRGB(180, 45, 45)
closeBtn.BorderSizePixel = 0
closeBtn.Text = "x"
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 13
closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
closeBtn.ZIndex = 8
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 6)

-- Tab bar
local tabBar = Instance.new("Frame", bg)
tabBar.Size = UDim2.new(1, 0, 0, 30)
tabBar.Position = UDim2.new(0, 0, 0, 34)
tabBar.BackgroundColor3 = Color3.fromRGB(12, 12, 12)
tabBar.BackgroundTransparency = 0
tabBar.BorderSizePixel = 0
tabBar.ZIndex = 6
local tabList = Instance.new("UIListLayout", tabBar)
tabList.FillDirection = Enum.FillDirection.Horizontal
tabList.Padding = UDim.new(0, 4)
tabList.VerticalAlignment = Enum.VerticalAlignment.Center
local tabPad = Instance.new("UIPadding", tabBar)
tabPad.PaddingLeft = UDim.new(0, 8)

-- Content area
local contentArea = Instance.new("Frame", bg)
contentArea.Size = UDim2.new(1, 0, 1, -64)
contentArea.Position = UDim2.new(0, 0, 0, 64)
contentArea.BackgroundTransparency = 1
contentArea.ZIndex = 6

-- Tab system
local tabs = {}
local tabContents = {}

local function selectTab(name)
    for n, b in pairs(tabs) do
        b.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
        b.TextColor3 = Color3.fromRGB(120, 120, 120)
    end
    for n, c in pairs(tabContents) do
        c.Visible = false
    end
    tabs[name].BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    tabs[name].TextColor3 = Color3.fromRGB(220, 220, 220)
    tabContents[name].Visible = true
end

local function createTab(name)
    local btn = Instance.new("TextButton", tabBar)
    btn.Size = UDim2.new(0, 76, 0, 22)
    btn.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    btn.BorderSizePixel = 0
    btn.Text = name
    btn.Font = Enum.Font.Gotham
    btn.TextSize = 11
    btn.TextColor3 = Color3.fromRGB(120, 120, 120)
    btn.ZIndex = 7
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)

    local scroll = Instance.new("ScrollingFrame", contentArea)
    scroll.Size = UDim2.new(1, 0, 1, 0)
    scroll.BackgroundTransparency = 1
    scroll.BorderSizePixel = 0
    scroll.ScrollBarThickness = 2
    scroll.ScrollBarImageColor3 = Color3.fromRGB(70, 70, 70)
    scroll.Visible = false
    scroll.ZIndex = 6
    local layout = Instance.new("UIListLayout", scroll)
    layout.Padding = UDim.new(0, 7)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    local pad = Instance.new("UIPadding", scroll)
    pad.PaddingLeft = UDim.new(0, 12)
    pad.PaddingRight = UDim.new(0, 12)
    pad.PaddingTop = UDim.new(0, 10)
    layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        scroll.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 20)
    end)

    tabs[name] = btn
    tabContents[name] = scroll

    btn.MouseButton1Click:Connect(function()
        selectTab(name)
    end)

    return scroll
end

-- Widget helpers
local function makeLabel(parent, text, order)
    local l = Instance.new("TextLabel", parent)
    l.Size = UDim2.new(1, 0, 0, 14)
    l.BackgroundTransparency = 1
    l.Font = Enum.Font.Gotham
    l.TextSize = 10
    l.TextColor3 = Color3.fromRGB(90, 90, 90)
    l.Text = text
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.LayoutOrder = order or 0
    l.ZIndex = 7
    return l
end

local function makeValue(parent, text, order)
    local l = Instance.new("TextLabel", parent)
    l.Size = UDim2.new(1, 0, 0, 18)
    l.BackgroundTransparency = 1
    l.Font = Enum.Font.GothamBold
    l.TextSize = 13
    l.TextColor3 = Color3.fromRGB(210, 210, 210)
    l.Text = text
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.LayoutOrder = order or 0
    l.ZIndex = 7
    return l
end

local function makeDivider(parent, order)
    local d = Instance.new("Frame", parent)
    d.Size = UDim2.new(1, 0, 0, 1)
    d.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
    d.BorderSizePixel = 0
    d.LayoutOrder = order or 0
    d.ZIndex = 7
    return d
end

local function makeToggle(parent, text, order, callback)
    local row = Instance.new("Frame", parent)
    row.Size = UDim2.new(1, 0, 0, 32)
    row.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    row.BorderSizePixel = 0
    row.LayoutOrder = order or 0
    row.ZIndex = 7
    Instance.new("UICorner", row).CornerRadius = UDim.new(0, 7)
    local s = Instance.new("UIStroke", row)
    s.Color = Color3.fromRGB(40, 40, 40)
    s.Thickness = 1

    local lbl = Instance.new("TextLabel", row)
    lbl.Size = UDim2.new(1, -55, 1, 0)
    lbl.Position = UDim2.new(0, 10, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Font = Enum.Font.Gotham
    lbl.TextSize = 11
    lbl.TextColor3 = Color3.fromRGB(190, 190, 190)
    lbl.Text = text
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.ZIndex = 8

    local bg2 = Instance.new("Frame", row)
    bg2.Size = UDim2.new(0, 34, 0, 16)
    bg2.Position = UDim2.new(1, -44, 0.5, -8)
    bg2.BackgroundColor3 = Color3.fromRGB(38, 38, 38)
    bg2.BorderSizePixel = 0
    bg2.ZIndex = 8
    Instance.new("UICorner", bg2).CornerRadius = UDim.new(1, 0)

    local knob = Instance.new("Frame", bg2)
    knob.Size = UDim2.new(0, 10, 0, 10)
    knob.Position = UDim2.new(0, 3, 0.5, -5)
    knob.BackgroundColor3 = Color3.fromRGB(110, 110, 110)
    knob.BorderSizePixel = 0
    knob.ZIndex = 9
    Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)

    local state = false
    local hitbox = Instance.new("TextButton", row)
    hitbox.Size = UDim2.new(1, 0, 1, 0)
    hitbox.BackgroundTransparency = 1
    hitbox.Text = ""
    hitbox.ZIndex = 10
    hitbox.MouseButton1Click:Connect(function()
        state = not state
        if state then
            TweenService:Create(bg2, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(70, 190, 100)}):Play()
            TweenService:Create(knob, TweenInfo.new(0.15), {Position = UDim2.new(0, 21, 0.5, -5), BackgroundColor3 = Color3.fromRGB(255,255,255)}):Play()
        else
            TweenService:Create(bg2, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(38, 38, 38)}):Play()
            TweenService:Create(knob, TweenInfo.new(0.15), {Position = UDim2.new(0, 3, 0.5, -5), BackgroundColor3 = Color3.fromRGB(110,110,110)}):Play()
        end
        if callback then callback(state) end
    end)
    return row
end

-- ==================
-- MAIN TAB
-- ==================
local mainTab = createTab("Main")

local char = player.Character or player.CharacterAdded:Wait()

makeLabel(mainTab, "player", 1)
makeValue(mainTab, player.Name, 2)
makeDivider(mainTab, 3)
makeLabel(mainTab, "display name", 4)
makeValue(mainTab, player.DisplayName, 5)
makeDivider(mainTab, 6)
makeLabel(mainTab, "user id", 7)
makeValue(mainTab, tostring(player.UserId), 8)
makeDivider(mainTab, 9)
makeLabel(mainTab, "account age (days)", 10)
makeValue(mainTab, tostring(player.AccountAge), 11)
makeDivider(mainTab, 12)
makeLabel(mainTab, "character loaded at", 13)
local charTimeLbl = makeValue(mainTab, os.date("%H:%M:%S"), 14)
makeDivider(mainTab, 15)
makeLabel(mainTab, "team", 16)
makeValue(mainTab, player.Team and player.Team.Name or "none", 17)

-- ==================
-- DEADLY TAB
-- ==================
local deadlyTab = createTab("Deadly")

-- Delete all blocks
local deleteRunning = false
makeToggle(deadlyTab, "Delete all blocks", 1, function(state)
    deleteRunning = state
    if not state then return end
    task.spawn(function()
        local char2 = player.Character
        if not char2 then return end
        local deleteTool = player.Backpack:FindFirstChild("Delete")
        if not deleteTool then
            warn("No Delete tool found")
            return
        end
        deleteTool.Parent = char2
        task.wait(0.2)
        local ok, Event = pcall(function()
            return char2.Delete.Script.Event
        end)
        if not ok then warn("Could not find Delete event") return end
        local hrp = char2:FindFirstChild("HumanoidRootPart")
        if not hrp then return end
        local bricksFolder = workspace:FindFirstChild("Bricks")
        if not bricksFolder then warn("No Bricks folder") return end
        local playerBricks = bricksFolder:FindFirstChild(player.Name)
        if not playerBricks then warn("No bricks folder for player") return end
        for _, v in playerBricks:GetChildren() do
            if not deleteRunning then break end
            if v.Name == "Brick" then
                pcall(function()
                    v.BrickColor = BrickColor.new("Really red")
                    v.Material = Enum.Material.Neon
                end)
                task.wait(0.25)
                pcall(function()
                    Event:FireServer(v, hrp.Position)
                end)
                task.wait(0.1)
            end
        end
        if char2:FindFirstChild("Delete") then
            char2.Delete.Parent = player.Backpack
        end
        deleteRunning = false
    end)
end)

makeDivider(deadlyTab, 2)

-- Rainbow paint
local paintColors = {
    Color3.new(0.769, 0.157, 0.110),
    Color3.new(0.294, 0.592, 0.294),
    Color3.new(0.961, 0.804, 0.188),
    Color3.new(0.706, 0.502, 1),
    Color3.new(0.855, 0.522, 0.255),
    Color3.new(0.016, 0.686, 0.925),
}
local paintIndex = 1
local paintRunning = false

makeToggle(deadlyTab, "Rainbow paint ground", 3, function(state)
    paintRunning = state
    if not state then return end
    task.spawn(function()
        local ok, paintEvent = pcall(function()
            return player.Backpack.Paint.Script.Event
        end)
        if not ok then warn("No Paint event") return end
        while paintRunning do
            if mouse.Target then
                pcall(function()
                    paintEvent:FireServer(
                        mouse.Target,
                        mouse.TargetSurface,
                        mouse.Hit.Position,
                        "both",
                        paintColors[paintIndex],
                        "smooth",
                        ""
                    )
                end)
                paintIndex = paintIndex % #paintColors + 1
            end
            task.wait(0.3)
        end
    end)
end)

makeDivider(deadlyTab, 4)

-- Glitch blocks
local glitchRunning = false
makeToggle(deadlyTab, "Glitch blocks (pink + black)", 5, function(state)
    glitchRunning = state
    if not state then return end
    task.spawn(function()
        local bricksFolder = workspace:FindFirstChild("Bricks")
        if not bricksFolder then return end
        local playerBricks = bricksFolder:FindFirstChild(player.Name)
        if not playerBricks then return end
        while glitchRunning do
            for _, v in playerBricks:GetChildren() do
                if not glitchRunning then break end
                if v.Name == "Brick" then
                    pcall(function()
                        v.BrickColor = math.random(1,2)==1 and BrickColor.new("Hot pink") or BrickColor.new("Really black")
                        v.Material = Enum.Material.Neon
                    end)
                end
            end
            task.wait(0.1)
        end
    end)
end)

-- ==================
-- BUILD TAB
-- ==================
local buildTab = createTab("Build")

makeLabel(buildTab, "memeify decal id", 1)

local decalInput = Instance.new("TextBox", buildTab)
decalInput.Size = UDim2.new(1, 0, 0, 30)
decalInput.BackgroundColor3 = Color3.fromRGB(22, 22, 22)
decalInput.BorderSizePixel = 0
decalInput.Font = Enum.Font.Code
decalInput.TextSize = 11
decalInput.TextColor3 = Color3.fromRGB(200, 200, 200)
decalInput.PlaceholderText = "enter decal id..."
decalInput.PlaceholderColor3 = Color3.fromRGB(65, 65, 65)
decalInput.Text = "11894923077"
decalInput.LayoutOrder = 2
decalInput.ClearTextOnFocus = false
decalInput.ZIndex = 7
Instance.new("UICorner", decalInput).CornerRadius = UDim.new(0, 7)
local dPad = Instance.new("UIPadding", decalInput)
dPad.PaddingLeft = UDim.new(0, 8)

makeDivider(buildTab, 3)

local applyBtn = Instance.new("TextButton", buildTab)
applyBtn.Size = UDim2.new(1, 0, 0, 30)
applyBtn.BackgroundColor3 = Color3.fromRGB(28, 28, 28)
applyBtn.BorderSizePixel = 0
applyBtn.Font = Enum.Font.GothamBold
applyBtn.TextSize = 11
applyBtn.TextColor3 = Color3.fromRGB(210, 210, 210)
applyBtn.Text = "Apply memeify decal"
applyBtn.LayoutOrder = 4
applyBtn.ZIndex = 7
Instance.new("UICorner", applyBtn).CornerRadius = UDim.new(0, 7)
local applyStroke = Instance.new("UIStroke", applyBtn)
applyStroke.Color = Color3.fromRGB(50, 50, 50)
applyStroke.Thickness = 1

local statusLbl = makeLabel(buildTab, "", 5)
statusLbl.TextColor3 = Color3.fromRGB(80, 200, 120)

applyBtn.MouseButton1Click:Connect(function()
    local id = decalInput.Text:gsub("%D+", "")
    if id == "" then
        statusLbl.Text = "enter a valid id"
        statusLbl.TextColor3 = Color3.fromRGB(200, 80, 80)
        return
    end
    statusLbl.Text = "sending..."
    statusLbl.TextColor3 = Color3.fromRGB(180, 180, 60)
    pcall(function()
        local chatEvent = game:GetService("ReplicatedStorage").DefaultChatSystemChatEvents.SayMessageRequest
        chatEvent:FireServer(";memeify " .. id, "All")
    end)
    task.wait(0.4)
    statusLbl.Text = "sent: " .. id
    statusLbl.TextColor3 = Color3.fromRGB(80, 200, 120)
end)

-- ==================
-- OPEN / CLOSE
-- ==================
local isOpen = false

local function openUI()
    isOpen = true
    bg.Visible = true
    selectTab("Main")
    TweenService:Create(blur, TweenInfo.new(0.2), {Size = 12}):Play()
end

local function closeUI()
    isOpen = false
    TweenService:Create(blur, TweenInfo.new(0.2), {Size = 0}):Play()
    task.delay(0.2, function() bg.Visible = false end)
end

closeBtn.MouseButton1Click:Connect(function()
    closeUI()
    openBtn.Visible = true
end)

UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if input.KeyCode == Enum.KeyCode.RightShift then
        if isOpen then closeUI() openBtn.Visible = true
        else openUI() openBtn.Visible = false end
    end
end)

-- Drag window
local dragging, dragStart, startPos
titleBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = bg.Position
    end
end)
UserInputService.InputChanged:Connect(function(input)
    if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - dragStart
        bg.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)
UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = false
    end
end)

-- ==================
-- CIRCLE BUTTON
-- ==================
local openBtn = Instance.new("TextButton", screenGui)
openBtn.Size = UDim2.new(0, 52, 0, 52)
openBtn.Position = UDim2.new(0, 20, 1, -80)
openBtn.BackgroundColor3 = Color3.fromRGB(18, 18, 18)
openBtn.BorderSizePixel = 0
openBtn.Text = "M"
openBtn.Font = Enum.Font.GothamBold
openBtn.TextSize = 18
openBtn.TextColor3 = Color3.fromRGB(210, 210, 210)
openBtn.ZIndex = 20
openBtn.Visible = false
Instance.new("UICorner", openBtn).CornerRadius = UDim.new(1, 0)
local btnStroke = Instance.new("UIStroke", openBtn)
btnStroke.Color = Color3.fromRGB(70, 70, 70)
btnStroke.Thickness = 1.5

-- Drag circle button
local btnDragging = false
local btnDragStart = nil
local btnStartPos = nil
local btnMoved = false

openBtn.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        btnDragging = true
        btnMoved = false
        btnDragStart = input.Position
        btnStartPos = openBtn.Position
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if btnDragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - btnDragStart
        if delta.Magnitude > 5 then btnMoved = true end
        openBtn.Position = UDim2.new(btnStartPos.X.Scale, btnStartPos.X.Offset + delta.X, btnStartPos.Y.Scale, btnStartPos.Y.Offset + delta.Y)
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        btnDragging = false
    end
end)

openBtn.MouseButton1Click:Connect(function()
    if btnMoved then return end
    openUI()
    openBtn.Visible = false
end)

-- Start closed, show circle button
openBtn.Visible = true

print("ManesHub loaded. Tap M or press RightShift to open.")
