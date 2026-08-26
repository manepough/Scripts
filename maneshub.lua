-- Hub UI Script

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local mouse = player:GetMouse()

-- === SCREEN GUI ===
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "ManesHub"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = player.PlayerGui

-- === BLUR EFFECT ===
local blur = Instance.new("BlurEffect")
blur.Size = 0
blur.Parent = game.Lighting

-- === BACKGROUND ===
local bg = Instance.new("Frame")
bg.Size = UDim2.new(0, 520, 0, 340)
bg.Position = UDim2.new(0.5, -260, 0.5, -170)
bg.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
bg.BackgroundTransparency = 0.55
bg.BorderSizePixel = 0
bg.Visible = false
bg.Parent = screenGui

local bgCorner = Instance.new("UICorner")
bgCorner.CornerRadius = UDim.new(0, 12)
bgCorner.Parent = bg

-- Subtle border
local bgStroke = Instance.new("UIStroke")
bgStroke.Color = Color3.fromRGB(55, 55, 55)
bgStroke.Thickness = 1
bgStroke.Parent = bg

-- === CONSTELLATION SIDE DECORATIONS ===
local constellationContainer = Instance.new("Frame")
constellationContainer.Size = UDim2.new(1, 0, 1, 0)
constellationContainer.BackgroundTransparency = 1
constellationContainer.ZIndex = 0
constellationContainer.Parent = screenGui

local constellations = {}

local function makeDot(parent, x, y)
    local dot = Instance.new("Frame")
    dot.Size = UDim2.new(0, 4, 0, 4)
    dot.Position = UDim2.new(0, x - 2, 0, y - 2)
    dot.BackgroundColor3 = Color3.fromRGB(200, 200, 200)
    dot.BorderSizePixel = 0
    dot.BackgroundTransparency = 0.2
    dot.ZIndex = 2
    dot.Parent = parent
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(1, 0)
    c.Parent = dot
    return dot
end

local function makeLine(parent, x1, y1, x2, y2)
    local dx = x2 - x1
    local dy = y2 - y1
    local length = math.sqrt(dx*dx + dy*dy)
    local angle = math.atan2(dy, dx)
    local line = Instance.new("Frame")
    line.Size = UDim2.new(0, length, 0, 1)
    line.Position = UDim2.new(0, x1, 0, y1)
    line.BackgroundColor3 = Color3.fromRGB(180, 180, 180)
    line.BorderSizePixel = 0
    line.BackgroundTransparency = 0.55
    line.Rotation = math.deg(angle)
    line.AnchorPoint = Vector2.new(0, 0.5)
    line.ZIndex = 1
    line.Parent = parent
    return line
end

local function spawnConstellation()
    local sideLeft = math.random(1, 2) == 1
    local sideWidth = 110
    local screenH = workspace.CurrentCamera.ViewportSize.Y

    local baseX = sideLeft and math.random(10, sideWidth) or (workspace.CurrentCamera.ViewportSize.X - math.random(10, sideWidth))
    local baseY = math.random(60, screenH - 60)

    local numPoints = math.random(3, 6)
    local points = {}
    for i = 1, numPoints do
        local px = baseX + math.random(-55, 55)
        local py = baseY + math.random(-70, 70)
        px = math.clamp(px, sideLeft and 4 or (workspace.CurrentCamera.ViewportSize.X - sideWidth), sideLeft and sideWidth or workspace.CurrentCamera.ViewportSize.X - 4)
        table.insert(points, {x = px, y = py})
    end

    local holder = Instance.new("Frame")
    holder.Size = UDim2.new(1, 0, 1, 0)
    holder.BackgroundTransparency = 1
    holder.ZIndex = 0
    holder.Parent = constellationContainer

    local lines = {}
    local dots = {}

    -- connect points in order to form shapes
    for i = 1, #points do
        local a = points[i]
        local b = points[(i % #points) + 1]
        local line = makeLine(holder, a.x, a.y, b.x, b.y)
        line.BackgroundTransparency = 1
        table.insert(lines, line)
    end

    for _, p in ipairs(points) do
        local dot = makeDot(holder, p.x, p.y)
        dot.BackgroundTransparency = 1
        table.insert(dots, dot)
    end

    -- fade in
    for _, l in ipairs(lines) do
        TweenService:Create(l, TweenInfo.new(0.6, Enum.EasingStyle.Quad), {BackgroundTransparency = 0.55}):Play()
    end
    for _, d in ipairs(dots) do
        TweenService:Create(d, TweenInfo.new(0.4, Enum.EasingStyle.Quad), {BackgroundTransparency = 0.2}):Play()
    end

    table.insert(constellations, holder)

    -- drift slowly
    local driftX = math.random(-18, 18)
    local driftY = math.random(-25, 25)
    TweenService:Create(holder, TweenInfo.new(5, Enum.EasingStyle.Linear), {
        Position = UDim2.new(0, driftX, 0, driftY)
    }):Play()

    -- fade out and destroy
    task.delay(4, function()
        for _, l in ipairs(lines) do
            TweenService:Create(l, TweenInfo.new(0.7), {BackgroundTransparency = 1}):Play()
        end
        for _, d in ipairs(dots) do
            TweenService:Create(d, TweenInfo.new(0.5), {BackgroundTransparency = 1}):Play()
        end
        task.delay(0.8, function()
            holder:Destroy()
            for i, v in ipairs(constellations) do
                if v == holder then table.remove(constellations, i) break end
            end
        end)
    end)
end

local function spawnString()
    spawnConstellation()
end

-- === TITLE BAR ===
local titleBar = Instance.new("Frame")
titleBar.Size = UDim2.new(1, 0, 0, 36)
titleBar.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
titleBar.BackgroundTransparency = 0.4
titleBar.BorderSizePixel = 0
titleBar.Parent = bg

local titleCorner = Instance.new("UICorner")
titleCorner.CornerRadius = UDim.new(0, 12)
titleCorner.Parent = titleBar

local titleFix = Instance.new("Frame")
titleFix.Size = UDim2.new(1, 0, 0.5, 0)
titleFix.Position = UDim2.new(0, 0, 0.5, 0)
titleFix.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
titleFix.BackgroundTransparency = 0.4
titleFix.BorderSizePixel = 0
titleFix.Parent = titleBar

local titleLabel = Instance.new("TextLabel")
titleLabel.Size = UDim2.new(1, -60, 1, 0)
titleLabel.Position = UDim2.new(0, 16, 0, 0)
titleLabel.BackgroundTransparency = 1
titleLabel.Font = Enum.Font.GothamBold
titleLabel.TextSize = 13
titleLabel.TextColor3 = Color3.fromRGB(210, 210, 210)
titleLabel.Text = "ManesHub"
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.Parent = titleBar

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 28, 0, 28)
closeBtn.Position = UDim2.new(1, -34, 0.5, -14)
closeBtn.BackgroundColor3 = Color3.fromRGB(180, 50, 50)
closeBtn.BorderSizePixel = 0
closeBtn.Text = "x"
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 13
closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
closeBtn.Parent = titleBar

local closeBtnCorner = Instance.new("UICorner")
closeBtnCorner.CornerRadius = UDim.new(0, 6)
closeBtnCorner.Parent = closeBtn

-- === TABS BAR ===
local tabBar = Instance.new("Frame")
tabBar.Size = UDim2.new(1, 0, 0, 34)
tabBar.Position = UDim2.new(0, 0, 0, 36)
tabBar.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
tabBar.BackgroundTransparency = 0.5
tabBar.BorderSizePixel = 0
tabBar.Parent = bg

local tabLayout = Instance.new("UIListLayout")
tabLayout.FillDirection = Enum.FillDirection.Horizontal
tabLayout.Padding = UDim.new(0, 2)
tabLayout.VerticalAlignment = Enum.VerticalAlignment.Center
tabLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
tabLayout.Parent = tabBar

local tabPadding = Instance.new("UIPadding")
tabPadding.PaddingLeft = UDim.new(0, 8)
tabPadding.Parent = tabBar

-- === CONTENT AREA ===
local contentArea = Instance.new("Frame")
contentArea.Size = UDim2.new(1, 0, 1, -70)
contentArea.Position = UDim2.new(0, 0, 0, 70)
contentArea.BackgroundTransparency = 1
contentArea.Parent = bg

-- === TAB SYSTEM ===
local tabs = {}
local tabContents = {}
local currentTab = nil

local function createTab(name)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, 80, 0, 26)
    btn.BackgroundColor3 = Color3.fromRGB(22, 22, 22)
    btn.BorderSizePixel = 0
    btn.Text = name
    btn.Font = Enum.Font.Gotham
    btn.TextSize = 12
    btn.TextColor3 = Color3.fromRGB(130, 130, 130)
    btn.Parent = tabBar

    local btnCorner = Instance.new("UICorner")
    btnCorner.CornerRadius = UDim.new(0, 6)
    btnCorner.Parent = btn

    local content = Instance.new("ScrollingFrame")
    content.Size = UDim2.new(1, 0, 1, 0)
    content.BackgroundTransparency = 1
    content.BorderSizePixel = 0
    content.ScrollBarThickness = 3
    content.ScrollBarImageColor3 = Color3.fromRGB(60, 60, 60)
    content.Visible = false
    content.Parent = contentArea

    local contentLayout = Instance.new("UIListLayout")
    contentLayout.FillDirection = Enum.FillDirection.Vertical
    contentLayout.Padding = UDim.new(0, 8)
    contentLayout.SortOrder = Enum.SortOrder.LayoutOrder
    contentLayout.Parent = content

    local contentPad = Instance.new("UIPadding")
    contentPad.PaddingLeft = UDim.new(0, 14)
    contentPad.PaddingRight = UDim.new(0, 14)
    contentPad.PaddingTop = UDim.new(0, 12)
    contentPad.Parent = content

    contentLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        content.CanvasSize = UDim2.new(0, 0, 0, contentLayout.AbsoluteContentSize.Y + 24)
    end)

    tabs[name] = btn
    tabContents[name] = content

    btn.MouseButton1Click:Connect(function()
        for n, b in pairs(tabs) do
            b.TextColor3 = Color3.fromRGB(130, 130, 130)
            b.BackgroundColor3 = Color3.fromRGB(22, 22, 22)
        end
        for n, c in pairs(tabContents) do
            c.Visible = false
        end
        btn.TextColor3 = Color3.fromRGB(220, 220, 220)
        btn.BackgroundColor3 = Color3.fromRGB(38, 38, 38)
        content.Visible = true
        currentTab = name
    end)

    return content
end

-- === WIDGET HELPERS ===
local function makeLabel(parent, text, order)
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, 0, 0, 16)
    lbl.BackgroundTransparency = 1
    lbl.Font = Enum.Font.Gotham
    lbl.TextSize = 11
    lbl.TextColor3 = Color3.fromRGB(100, 100, 100)
    lbl.Text = text
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.LayoutOrder = order or 0
    lbl.Parent = parent
    return lbl
end

local function makeValue(parent, text, order)
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, 0, 0, 20)
    lbl.BackgroundTransparency = 1
    lbl.Font = Enum.Font.GothamBold
    lbl.TextSize = 14
    lbl.TextColor3 = Color3.fromRGB(210, 210, 210)
    lbl.Text = text
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.LayoutOrder = order or 0
    lbl.Parent = parent
    return lbl
end

local function makeDivider(parent, order)
    local div = Instance.new("Frame")
    div.Size = UDim2.new(1, 0, 0, 1)
    div.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
    div.BorderSizePixel = 0
    div.LayoutOrder = order or 0
    div.Parent = parent
    return div
end

local function makeButton(parent, text, color, order)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, 34)
    btn.BackgroundColor3 = color or Color3.fromRGB(30, 30, 30)
    btn.BorderSizePixel = 0
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 12
    btn.TextColor3 = Color3.fromRGB(210, 210, 210)
    btn.Text = text
    btn.LayoutOrder = order or 0
    btn.Parent = parent

    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 8)
    c.Parent = btn

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(50, 50, 50)
    stroke.Thickness = 1
    stroke.Parent = btn

    return btn
end

local function makeToggle(parent, text, order, callback)
    local container = Instance.new("Frame")
    container.Size = UDim2.new(1, 0, 0, 34)
    container.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    container.BorderSizePixel = 0
    container.LayoutOrder = order or 0
    container.Parent = parent

    local cCorner = Instance.new("UICorner")
    cCorner.CornerRadius = UDim.new(0, 8)
    cCorner.Parent = container

    local cStroke = Instance.new("UIStroke")
    cStroke.Color = Color3.fromRGB(45, 45, 45)
    cStroke.Thickness = 1
    cStroke.Parent = container

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -60, 1, 0)
    lbl.Position = UDim2.new(0, 12, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Font = Enum.Font.Gotham
    lbl.TextSize = 12
    lbl.TextColor3 = Color3.fromRGB(190, 190, 190)
    lbl.Text = text
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = container

    local toggleBg = Instance.new("Frame")
    toggleBg.Size = UDim2.new(0, 36, 0, 18)
    toggleBg.Position = UDim2.new(1, -48, 0.5, -9)
    toggleBg.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    toggleBg.BorderSizePixel = 0
    toggleBg.Parent = container

    local tCorner = Instance.new("UICorner")
    tCorner.CornerRadius = UDim.new(1, 0)
    tCorner.Parent = toggleBg

    local knob = Instance.new("Frame")
    knob.Size = UDim2.new(0, 12, 0, 12)
    knob.Position = UDim2.new(0, 3, 0.5, -6)
    knob.BackgroundColor3 = Color3.fromRGB(120, 120, 120)
    knob.BorderSizePixel = 0
    knob.Parent = toggleBg

    local kCorner = Instance.new("UICorner")
    kCorner.CornerRadius = UDim.new(1, 0)
    kCorner.Parent = knob

    local state = false
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 1, 0)
    btn.BackgroundTransparency = 1
    btn.Text = ""
    btn.Parent = container

    btn.MouseButton1Click:Connect(function()
        state = not state
        if state then
            TweenService:Create(toggleBg, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(80, 200, 120)}):Play()
            TweenService:Create(knob, TweenInfo.new(0.15), {Position = UDim2.new(0, 21, 0.5, -6), BackgroundColor3 = Color3.fromRGB(255, 255, 255)}):Play()
        else
            TweenService:Create(toggleBg, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(40, 40, 40)}):Play()
            TweenService:Create(knob, TweenInfo.new(0.15), {Position = UDim2.new(0, 3, 0.5, -6), BackgroundColor3 = Color3.fromRGB(120, 120, 120)}):Play()
        end
        if callback then callback(state) end
    end)

    return container, function() return state end
end

-- =====================
-- === MAIN TAB ===
-- =====================
local mainContent = createTab("Main")

local char = player.Character or player.CharacterAdded:Wait()
local humanoid = char:WaitForChild("Humanoid")

makeLabel(mainContent, "player", 1)
makeValue(mainContent, player.Name, 2)
makeDivider(mainContent, 3)
makeLabel(mainContent, "display name", 4)
makeValue(mainContent, player.DisplayName, 5)
makeDivider(mainContent, 6)
makeLabel(mainContent, "user id", 7)
makeValue(mainContent, tostring(player.UserId), 8)
makeDivider(mainContent, 9)
makeLabel(mainContent, "account age (days)", 10)
makeValue(mainContent, tostring(player.AccountAge), 11)
makeDivider(mainContent, 12)
makeLabel(mainContent, "character loaded", 13)

local charTime = makeValue(mainContent, "checking...", 14)

task.spawn(function()
    local c = player.Character or player.CharacterAdded:Wait()
    c:WaitForChild("HumanoidRootPart")
    charTime.Text = tostring(os.date("%H:%M:%S"))
end)

makeDivider(mainContent, 15)
makeLabel(mainContent, "team", 16)
local teamVal = makeValue(mainContent, player.Team and player.Team.Name or "none", 17)

-- =====================
-- === DEADLY TAB ===
-- =====================
local deadlyContent = createTab("Deadly")

-- Delete all blocks
local deleteRunning = false
local deleteToggle, getDeleteState = makeToggle(deadlyContent, "Delete all blocks", 1, function(state)
    deleteRunning = state
    if state then
        task.spawn(function()
            local char2 = player.Character
            if not char2 then return end
            local deleteTool = player.Backpack:FindFirstChild("Delete")
            if not deleteTool then return end
            deleteTool.Parent = char2
            task.wait(0.2)
            local Event = char2.Delete.Script.Event
            local hrp = char2:FindFirstChild("HumanoidRootPart")
            if not hrp then return end
            local bricksFolder = workspace.Bricks:FindFirstChild(player.Name)
            if not bricksFolder then return end
            for _, v in bricksFolder:GetChildren() do
                if not deleteRunning then break end
                if v.Name == "Brick" then
                    pcall(function()
                        v.BrickColor = BrickColor.new("Really red")
                        v.Material = Enum.Material.Neon
                    end)
                    task.wait(0.3)
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
    end
end)

makeDivider(deadlyContent, 2)

-- Rainbow paint
local paintColors = {
    Color3.new(0.76862746477127, 0.15686275064945, 0.10980392247438),
    Color3.new(0.29411765933037, 0.59215688705444, 0.29411765933037),
    Color3.new(0.96078431606293, 0.80392158031464, 0.18823529779911),
    Color3.new(0.70588237047195, 0.50196081399918, 1),
    Color3.new(0.85490196943283, 0.52156865596771, 0.2549019753933),
    Color3.new(0.015686275437474, 0.68627452850342, 0.92549020051956),
}
local paintIndex = 1
local paintRunning = false

local rainbowToggle, getRainbowState = makeToggle(deadlyContent, "Rainbow paint ground", 3, function(state)
    paintRunning = state
    if state then
        task.spawn(function()
            local paintEvent = player.Backpack.Paint.Script.Event
            while paintRunning do
                local target = mouse.Hit.Position
                local normal = mouse.TargetSurface
                if mouse.Target then
                    pcall(function()
                        paintEvent:FireServer(
                            mouse.Target,
                            normal,
                            target,
                            "both",
                            paintColors[paintIndex],
                            "smooth",
                            ""
                        )
                    end)
                end
                paintIndex = paintIndex % #paintColors + 1
                task.wait(0.3)
            end
        end)
    end
end)

makeDivider(deadlyContent, 4)

-- Glitch blocks
local glitchRunning = false
local glitchToggle, getGlitchState = makeToggle(deadlyContent, "Glitch blocks (pink + black)", 5, function(state)
    glitchRunning = state
    if state then
        task.spawn(function()
            local paintEvent = player.Backpack.Paint.Script.Event
            local bricksFolder = workspace.Bricks:FindFirstChild(player.Name)
            if not bricksFolder then return end
            while glitchRunning do
                for _, v in bricksFolder:GetChildren() do
                    if not glitchRunning then break end
                    if v.Name == "Brick" then
                        local isPink = math.random(1, 2) == 1
                        pcall(function()
                            v.BrickColor = isPink and BrickColor.new("Hot pink") or BrickColor.new("Really black")
                            v.Material = Enum.Material.Neon
                        end)
                    end
                end
                task.wait(0.1)
            end
        end)
    end
end)

-- =====================
-- === BUILD TAB ===
-- =====================
local buildContent = createTab("Build")

makeLabel(buildContent, "memeify decal id", 1)

local decalInput = Instance.new("TextBox")
decalInput.Size = UDim2.new(1, 0, 0, 32)
decalInput.BackgroundColor3 = Color3.fromRGB(22, 22, 22)
decalInput.BorderSizePixel = 0
decalInput.Font = Enum.Font.Code
decalInput.TextSize = 12
decalInput.TextColor3 = Color3.fromRGB(200, 200, 200)
decalInput.PlaceholderText = "enter decal id..."
decalInput.PlaceholderColor3 = Color3.fromRGB(70, 70, 70)
decalInput.Text = "11894923077"
decalInput.LayoutOrder = 2
decalInput.ClearTextOnFocus = false
decalInput.Parent = buildContent

local dInputCorner = Instance.new("UICorner")
dInputCorner.CornerRadius = UDim.new(0, 8)
dInputCorner.Parent = decalInput

local dInputStroke = Instance.new("UIStroke")
dInputStroke.Color = Color3.fromRGB(45, 45, 45)
dInputStroke.Thickness = 1
dInputStroke.Parent = decalInput

local dInputPad = Instance.new("UIPadding")
dInputPad.PaddingLeft = UDim.new(0, 10)
dInputPad.Parent = decalInput

makeDivider(buildContent, 3)

local applyDecalBtn = makeButton(buildContent, "Apply memeify decal", Color3.fromRGB(25, 25, 25), 4)

local decalStatus = makeLabel(buildContent, "", 5)
decalStatus.TextColor3 = Color3.fromRGB(80, 200, 120)

applyDecalBtn.MouseButton1Click:Connect(function()
    local id = decalInput.Text:gsub("%D+", "")
    if id == "" then
        decalStatus.Text = "enter a valid decal id"
        decalStatus.TextColor3 = Color3.fromRGB(200, 80, 80)
        return
    end
    decalStatus.Text = "sending memeify command..."
    decalStatus.TextColor3 = Color3.fromRGB(180, 180, 80)
    -- memeify is applied via the ;memeify command in game chat
    -- this fires the chat with the decal id
    game:GetService("ReplicatedStorage"):WaitForChild("DefaultChatSystemChatEvents", 5)
    pcall(function()
        local chatEvent = game:GetService("ReplicatedStorage").DefaultChatSystemChatEvents.SayMessageRequest
        chatEvent:FireServer(";memeify " .. id, "All")
    end)
    task.wait(0.5)
    decalStatus.Text = "memeify sent: " .. id
    decalStatus.TextColor3 = Color3.fromRGB(80, 200, 120)
end)

-- === OPEN/CLOSE LOGIC ===
local isOpen = false

local function openUI()
    isOpen = true
    bg.Visible = true
    bg.BackgroundTransparency = 1
    TweenService:Create(bg, TweenInfo.new(0.25, Enum.EasingStyle.Quart), {BackgroundTransparency = 0.55}):Play()
    TweenService:Create(blur, TweenInfo.new(0.25), {Size = 14}):Play()

    -- open first tab by default
    tabs["Main"].TextColor3 = Color3.fromRGB(220, 220, 220)
    tabs["Main"].BackgroundColor3 = Color3.fromRGB(38, 38, 38)
    tabContents["Main"].Visible = true
    currentTab = "Main"
end

local function closeUI()
    isOpen = false
    TweenService:Create(bg, TweenInfo.new(0.2), {BackgroundTransparency = 1}):Play()
    TweenService:Create(blur, TweenInfo.new(0.2), {Size = 0}):Play()
    task.delay(0.2, function()
        bg.Visible = false
    end)
end

-- Toggle with RightShift
UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if input.KeyCode == Enum.KeyCode.RightShift then
        if isOpen then closeUI() else openUI() end
    end
end)

-- Dragging
local dragging, dragStart, startPos
titleBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = true
        dragStart = input.Position
        startPos = bg.Position
    end
end)
UserInputService.InputChanged:Connect(function(input)
    if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
        local delta = input.Position - dragStart
        bg.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)
UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = false
    end
end)

-- Floating strings loop (only when open)
task.spawn(function()
    while true do
        if isOpen then
            spawnString()
        end
        task.wait(1.2)
    end
end)

-- === MOBILE OPEN BUTTON ===
local openBtn = Instance.new("TextButton")
openBtn.Size = UDim2.new(0, 52, 0, 52)
openBtn.Position = UDim2.new(0, 16, 1, -80)
openBtn.BackgroundColor3 = Color3.fromRGB(18, 18, 18)
openBtn.BorderSizePixel = 0
openBtn.Text = "M"
openBtn.Font = Enum.Font.GothamBold
openBtn.TextSize = 18
openBtn.TextColor3 = Color3.fromRGB(210, 210, 210)
openBtn.ZIndex = 10
openBtn.Parent = screenGui

local openBtnCorner = Instance.new("UICorner")
openBtnCorner.CornerRadius = UDim.new(1, 0)
openBtnCorner.Parent = openBtn

local openBtnStroke = Instance.new("UIStroke")
openBtnStroke.Color = Color3.fromRGB(70, 70, 70)
openBtnStroke.Thickness = 1.5
openBtnStroke.Parent = openBtn

openBtn.MouseButton1Click:Connect(function()
    if isOpen then
        closeUI()
        openBtn.Visible = true
    else
        openUI()
        openBtn.Visible = false
    end
end)

closeBtn.MouseButton1Click:Connect(function()
    openBtn.Visible = true
end)

-- Open on load
openUI()
openBtn.Visible = false

print("ManesHub loaded. Press RightShift or tap M button to toggle.")
