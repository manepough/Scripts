-- ManesHub

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

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

-- === HELPERS ===

-- Equip tool to character then return its event
local function equipAndGetEvent(toolName)
    local bt = player.Backpack:FindFirstChild(toolName)
    if bt then
        pcall(function() bt.Parent = player.Character end)
    end
    local ct = player.Character and player.Character:FindFirstChild(toolName)
    if ct and ct:FindFirstChild("Script") and ct.Script:FindFirstChild("Event") then
        return ct.Script.Event
    end
    return nil
end

-- findbtools: gets event directly from backpack, no equipping needed
local function findbtools(name)
    local btools = {}
    for _, v in player.Backpack:GetChildren() do
        if v:IsA("Tool") and v.Name == name and v:FindFirstChild("Script") and v.Script:FindFirstChild("Event") then
            table.insert(btools, {bt = v, e = v.Script.Event})
        end
    end
    if player.Character then
        for _, v in player.Character:GetChildren() do
            if v:IsA("Tool") and v.Name == name and v:FindFirstChild("Script") and v.Script:FindFirstChild("Event") then
                table.insert(btools, {bt = v, e = v.Script.Event})
            end
        end
    end
    return btools
end

-- Circle button declared early so closeUI can reference it
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
openBtn.Visible = true
Instance.new("UICorner", openBtn).CornerRadius = UDim.new(1, 0)
local btnStroke = Instance.new("UIStroke", openBtn)
btnStroke.Color = Color3.fromRGB(70, 70, 70)
btnStroke.Thickness = 1.5

-- Main window
local bg = Instance.new("Frame")
bg.Size = UDim2.new(0, 500, 0, 340)
bg.Position = UDim2.new(0.5, -250, 0.5, -170)
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
titleLbl.Size = UDim2.new(1, -80, 1, 0)
titleLbl.Position = UDim2.new(0, 14, 0, 0)
titleLbl.BackgroundTransparency = 1
titleLbl.Font = Enum.Font.GothamBold
titleLbl.TextSize = 13
titleLbl.TextColor3 = Color3.fromRGB(220, 220, 220)
titleLbl.Text = "ManesHub"
titleLbl.TextXAlignment = Enum.TextXAlignment.Left
titleLbl.ZIndex = 7

-- Minimize button (-)
local minBtn = Instance.new("TextButton", titleBar)
minBtn.Size = UDim2.new(0, 24, 0, 24)
minBtn.Position = UDim2.new(1, -58, 0.5, -12)
minBtn.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
minBtn.BorderSizePixel = 0
minBtn.Text = "-"
minBtn.Font = Enum.Font.GothamBold
minBtn.TextSize = 16
minBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
minBtn.ZIndex = 8
Instance.new("UICorner", minBtn).CornerRadius = UDim.new(0, 6)

-- Close/destroy button (X)
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

-- Left side tab bar (scrollable vertical)
local tabBar = Instance.new("ScrollingFrame", bg)
tabBar.Size = UDim2.new(0, 80, 1, -34)
tabBar.Position = UDim2.new(0, 0, 0, 34)
tabBar.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
tabBar.BackgroundTransparency = 0
tabBar.BorderSizePixel = 0
tabBar.ScrollBarThickness = 2
tabBar.ScrollBarImageColor3 = Color3.fromRGB(50, 50, 50)
tabBar.ScrollingDirection = Enum.ScrollingDirection.Y
tabBar.ZIndex = 6
local tabList = Instance.new("UIListLayout", tabBar)
tabList.FillDirection = Enum.FillDirection.Vertical
tabList.Padding = UDim.new(0, 3)
tabList.SortOrder = Enum.SortOrder.LayoutOrder
tabList.HorizontalAlignment = Enum.HorizontalAlignment.Center
local tabPad = Instance.new("UIPadding", tabBar)
tabPad.PaddingTop = UDim.new(0, 6)
tabPad.PaddingBottom = UDim.new(0, 6)
tabList:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    tabBar.CanvasSize = UDim2.new(0, 0, 0, tabList.AbsoluteContentSize.Y + 12)
end)

-- Left border line
local tabBorder = Instance.new("Frame", bg)
tabBorder.Size = UDim2.new(0, 1, 1, -34)
tabBorder.Position = UDim2.new(0, 80, 0, 34)
tabBorder.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
tabBorder.BorderSizePixel = 0
tabBorder.ZIndex = 6

-- Content area (right of tabs)
local contentArea = Instance.new("Frame", bg)
contentArea.Size = UDim2.new(1, -81, 1, -34)
contentArea.Position = UDim2.new(0, 81, 0, 34)
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
    btn.Size = UDim2.new(0, 70, 0, 28)
    btn.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    btn.BorderSizePixel = 0
    btn.Text = name
    btn.Font = Enum.Font.Gotham
    btn.TextSize = 10
    btn.TextColor3 = Color3.fromRGB(120, 120, 120)
    btn.ZIndex = 7
    btn.TextWrapped = true
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
    pad.PaddingLeft = UDim.new(0, 10)
    pad.PaddingRight = UDim.new(0, 10)
    pad.PaddingTop = UDim.new(0, 10)
    layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        scroll.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 20)
    end)

    tabs[name] = btn
    tabContents[name] = scroll
    btn.MouseButton1Click:Connect(function() selectTab(name) end)
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

    local function setOff()
        state = false
        TweenService:Create(bg2, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(38, 38, 38)}):Play()
        TweenService:Create(knob, TweenInfo.new(0.15), {Position = UDim2.new(0, 3, 0.5, -5), BackgroundColor3 = Color3.fromRGB(110,110,110)}):Play()
    end

    -- Mirrors setOff: syncs internal `state` AND the visual, without firing `callback`.
    -- Needed for auto-continue-on-rejoin, which starts the build loop itself and would
    -- double-start it if this also invoked callback(true).
    local function setOn()
        state = true
        TweenService:Create(bg2, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(70, 190, 100)}):Play()
        TweenService:Create(knob, TweenInfo.new(0.15), {Position = UDim2.new(0, 21, 0.5, -5), BackgroundColor3 = Color3.fromRGB(255,255,255)}):Play()
    end

    return row, setOff, setOn
end

-- ==================
-- MAIN TAB
-- ==================
local mainTab = createTab("Main")

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
makeValue(mainTab, os.date("%H:%M:%S"), 14)
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
        local char = player.Character or player.CharacterAdded:Wait()
        local hrp = char:WaitForChild("HumanoidRootPart")

        while deleteRunning do
            local dtools = findbtools("Delete")
            if #dtools == 0 then task.wait(0.5) continue end

            local dt = dtools[1]

            local bricks = {}
            for _, v in workspace:GetDescendants() do
                if v:IsA("BasePart") and v.Name == "Brick" and v.Parent then
                    table.insert(bricks, v)
                end
            end

            if #bricks == 0 then task.wait(0.3) continue end

            for _, v in bricks do
                if not deleteRunning then break end
                if v and v.Parent then
                    pcall(function()
                        dt.e:FireServer(v, hrp.Position)
                    end)
                    task.wait(0.03)
                end
            end

            task.wait(0.1)
        end
    end)
end)

makeDivider(deadlyTab, 2)

-- Rainbow paint ground
local paintRunning = false
makeToggle(deadlyTab, "Rainbow paint ground", 3, function(state)
    paintRunning = state
    if not state then return end
    task.spawn(function()
        local pti = 0
        local tparams = RaycastParams.new()
        tparams.FilterType = Enum.RaycastFilterType.Include
        tparams.FilterDescendantsInstances = {workspace.Terrain}
        local hgy = 20

        while paintRunning do
            local s, e = pcall(function()
                local paints = findbtools("Paint")
                if #paints == 0 then return end

                local char = player.Character
                if not char then return end
                local hrp = char:FindFirstChild("HumanoidRootPart")
                if not hrp then return end

                local hx = hrp.Position.X
                local hz = hrp.Position.Z

                local highestground = workspace:Raycast(Vector3.new(hx, 200, hz), Vector3.new(0, -300, 0), tparams)
                if highestground then hgy = highestground.Position.Y end

                pti = pti + 1
                local paint = paints[(pti % #paints) + 1]
                paint.e:FireServer(
                    workspace.Terrain,
                    Enum.NormalId.Top,
                    Vector3.new(hx, math.clamp(hrp.Position.Y, hgy - 3.9, hgy), hz),
                    "color",
                    Color3.fromHSV((tick() / 5) % 1, 1, 1),
                    "",
                    ""
                )
            end)
            if not s then warn(e) end
            task.wait(0.15)
        end
    end)
end)

makeDivider(deadlyTab, 4)

-- Glitch blocks with color picker
local glitchRunning = false
local glitchColor1 = Color3.fromRGB(255, 0, 127)
local glitchColor2 = Color3.fromRGB(0, 0, 0)

local colorRow = Instance.new("Frame", deadlyTab)
colorRow.Size = UDim2.new(1, 0, 0, 32)
colorRow.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
colorRow.BorderSizePixel = 0
colorRow.LayoutOrder = 5
colorRow.ZIndex = 7
Instance.new("UICorner", colorRow).CornerRadius = UDim.new(0, 7)
local colorStroke = Instance.new("UIStroke", colorRow)
colorStroke.Color = Color3.fromRGB(40, 40, 40)
colorStroke.Thickness = 1

local colorLbl = Instance.new("TextLabel", colorRow)
colorLbl.Size = UDim2.new(0.4, 0, 1, 0)
colorLbl.Position = UDim2.new(0, 10, 0, 0)
colorLbl.BackgroundTransparency = 1
colorLbl.Font = Enum.Font.Gotham
colorLbl.TextSize = 10
colorLbl.TextColor3 = Color3.fromRGB(150, 150, 150)
colorLbl.Text = "glitch colors"
colorLbl.TextXAlignment = Enum.TextXAlignment.Left
colorLbl.ZIndex = 8

local swatch1 = Instance.new("TextButton", colorRow)
swatch1.Size = UDim2.new(0, 22, 0, 22)
swatch1.Position = UDim2.new(1, -56, 0.5, -11)
swatch1.BackgroundColor3 = glitchColor1
swatch1.BorderSizePixel = 0
swatch1.Text = ""
swatch1.ZIndex = 8
Instance.new("UICorner", swatch1).CornerRadius = UDim.new(0, 5)

local swatch2 = Instance.new("TextButton", colorRow)
swatch2.Size = UDim2.new(0, 22, 0, 22)
swatch2.Position = UDim2.new(1, -30, 0.5, -11)
swatch2.BackgroundColor3 = glitchColor2
swatch2.BorderSizePixel = 0
swatch2.Text = ""
swatch2.ZIndex = 8
Instance.new("UICorner", swatch2).CornerRadius = UDim.new(0, 5)
local swatch2Stroke = Instance.new("UIStroke", swatch2)
swatch2Stroke.Color = Color3.fromRGB(80, 80, 80)
swatch2Stroke.Thickness = 1

local presets = {
    Color3.fromRGB(255,0,127),
    Color3.fromRGB(0,0,0),
    Color3.fromRGB(255,255,255),
    Color3.fromRGB(255,0,0),
    Color3.fromRGB(0,255,0),
    Color3.fromRGB(0,0,255),
    Color3.fromRGB(255,165,0),
    Color3.fromRGB(128,0,255),
    Color3.fromRGB(0,255,255),
    Color3.fromRGB(255,255,0),
}

local pickerPopup = Instance.new("Frame", screenGui)
pickerPopup.Size = UDim2.new(0, 220, 0, 60)
pickerPopup.BackgroundColor3 = Color3.fromRGB(18, 18, 18)
pickerPopup.BorderSizePixel = 0
pickerPopup.Visible = false
pickerPopup.ZIndex = 30
Instance.new("UICorner", pickerPopup).CornerRadius = UDim.new(0, 8)
local ppStroke = Instance.new("UIStroke", pickerPopup)
ppStroke.Color = Color3.fromRGB(60, 60, 60)
ppStroke.Thickness = 1

local ppGrid = Instance.new("Frame", pickerPopup)
ppGrid.Size = UDim2.new(1, -10, 1, -10)
ppGrid.Position = UDim2.new(0, 5, 0, 5)
ppGrid.BackgroundTransparency = 1
ppGrid.ZIndex = 31

local ppLayout = Instance.new("UIGridLayout", ppGrid)
ppLayout.CellSize = UDim2.new(0, 18, 0, 18)
ppLayout.CellPadding = UDim2.new(0, 3, 0, 3)
ppLayout.SortOrder = Enum.SortOrder.LayoutOrder

local activeSwatch = nil

for i, col in presets do
    local dot = Instance.new("TextButton", ppGrid)
    dot.Size = UDim2.new(0, 18, 0, 18)
    dot.BackgroundColor3 = col
    dot.BorderSizePixel = 0
    dot.Text = ""
    dot.ZIndex = 32
    dot.LayoutOrder = i
    Instance.new("UICorner", dot).CornerRadius = UDim.new(0, 4)
    dot.MouseButton1Click:Connect(function()
        if activeSwatch == 1 then
            glitchColor1 = col
            swatch1.BackgroundColor3 = col
        else
            glitchColor2 = col
            swatch2.BackgroundColor3 = col
        end
        pickerPopup.Visible = false
    end)
end

local function showPicker(swatchNum, btn)
    activeSwatch = swatchNum
    local absPos = btn.AbsolutePosition
    pickerPopup.Position = UDim2.new(0, absPos.X - 180, 0, absPos.Y - 70)
    pickerPopup.Visible = true
end

swatch1.MouseButton1Click:Connect(function() showPicker(1, swatch1) end)
swatch2.MouseButton1Click:Connect(function() showPicker(2, swatch2) end)

UserInputService.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        pickerPopup.Visible = false
    end
end)

makeToggle(deadlyTab, "Glitch blocks", 6, function(state)
    glitchRunning = state
    if not state then return end
    task.spawn(function()
        while glitchRunning do
            local paints = findbtools("Paint")
            if #paints == 0 then task.wait(0.3) continue end

            local cfolder = workspace:FindFirstChild("Bricks")
            if not cfolder then task.wait(0.3) continue end

            local bricks = {}
            for _, v in cfolder:GetDescendants() do
                if v:IsA("BasePart") then
                    table.insert(bricks, v)
                end
            end

            local colorIndex = (math.floor(tick() * 10) % 2) + 1
            local col = colorIndex == 1 and glitchColor1 or glitchColor2

            local pt = paints[1]
            for _, v in bricks do
                if not glitchRunning then break end
                if v and v.Parent then
                    pcall(function()
                        pt.e:FireServer(
                            v,
                            Enum.NormalId.Top,
                            v.Position,
                            "both \xF0\x9F\xA4\x9D",
                            col,
                            "neon",
                            ""
                        )
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

local materials = {}
materials[Enum.Material.SmoothPlastic] = "smooth"
materials[Enum.Material.Plastic]       = "plastic"
materials[Enum.Material.Neon]          = "neon"
materials[Enum.Material.Brick]         = "bricks"
materials[Enum.Material.WoodPlanks]    = "planks"
materials[Enum.Material.Ice]           = "ice"
materials[Enum.Material.Grass]         = "grass"
materials[Enum.Material.Sand]          = "sand"
materials[Enum.Material.Snow]          = "snow"
materials[Enum.Material.Glass]         = "glass"
materials[Enum.Material.Wood]          = "wood"
materials[Enum.Material.Slate]         = "stone"
materials[Enum.Material.Metal]         = "metal"
materials[Enum.Material.Concrete]      = "concrete"
materials[Enum.Material.DiamondPlate]  = "steel"
materials[Enum.Material.Cobblestone]   = "pebble"
materials[Enum.Material.Marble]        = "marble"
materials[Enum.Material.Granite]       = "granite"
materials[Enum.Material.Asphalt]       = "asphalt"
materials[Enum.Material.Pavement]      = "pavement"

-- friend's material map (covers extra names from BuildTools)
local materialMap = {
    SmoothPlastic="smooth", Plastic="plastic", Wood="wood", WoodPlanks="planks",
    Brick="bricks", Glass="glass", Slate="stone", Cobblestone="pebble", Marble="marble",
    Ice="ice", Grass="grass", Sand="sand", Snow="snow", Granite="granite",
    DiamondPlate="steel", CorrodedMetal="metal", Metal="metal", Asphalt="asphalt",
    Concrete="concrete", Pavement="pavement", Neon="neon",
    CeramicTiles="tiles", Sandstone="sandstone", Limestone="limestone",
}
local function getMaterialStr(mat)
    local matName = typeof(mat) == "EnumItem" and mat.Name or tostring(mat):match("Enum%.Material%.(.+)") or tostring(mat)
    return materialMap[matName] or materials[mat] or "smooth"
end

local BUILDS_FOLDER = "ManesHubBuilds"
local autoBuildRunning = false
local stopped = false
local skipblock = false
local childcube = nil
local built = false
local resizewait = 0.4  -- must match original script speed for shape tool

pcall(function()
    if not isfolder(BUILDS_FOLDER) then makefolder(BUILDS_FOLDER) end
end)

local http = game:GetService("HttpService")
local function jsonEncode(t) return http:JSONEncode(t) end
local function jsonDecode(s) return http:JSONDecode(s) end

local function listSaves()
    local files = {}
    pcall(function()
        for _, v in listfiles(BUILDS_FOLDER) do
            local name = v:gsub(BUILDS_FOLDER .. "/", ""):gsub(BUILDS_FOLDER .. "\\", ""):gsub(".json", "")
            if name ~= "" and name ~= "_lastbuild" then
                table.insert(files, name)
            end
        end
    end)
    return files
end

local function saveBlock(bl)
    if not bl:IsA("BasePart") then return nil end
    local bd = {}
    bd.a  = bl.Anchored
    bd.p  = {bl.Position.X, bl.Position.Y, bl.Position.Z}
    bd.c  = {math.round(bl.Color.R*255), math.round(bl.Color.G*255), math.round(bl.Color.B*255)}
    bd.m  = getMaterialStr(bl.Material)
    bd.sp = {}
    bd.o  = bl.Material.Name
    bd.cc = bl.CanCollide
    if bl.Size.X ~= 4 or bl.Size.Y ~= 4 or bl.Size.Z ~= 4 then
        bd.s = {bl.Size.X, bl.Size.Y, bl.Size.Z}
    end
    return bd
end

local function makeBuildLabel(parent, text, order)
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

local function makeBuildBtn(parent, text, order, callback)
    local btn = Instance.new("TextButton", parent)
    btn.Size = UDim2.new(1, 0, 0, 30)
    btn.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    btn.BorderSizePixel = 0
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 11
    btn.TextColor3 = Color3.fromRGB(200, 200, 200)
    btn.Text = text
    btn.LayoutOrder = order or 0
    btn.ZIndex = 7
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 7)
    local s = Instance.new("UIStroke", btn)
    s.Color = Color3.fromRGB(45, 45, 45)
    s.Thickness = 1
    btn.MouseButton1Click:Connect(callback)
    return btn
end

local function makeBuildDivider(parent, order)
    local d = Instance.new("Frame", parent)
    d.Size = UDim2.new(1, 0, 0, 1)
    d.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
    d.BorderSizePixel = 0
    d.LayoutOrder = order or 0
    d.ZIndex = 7
    return d
end

-- Status label
local buildStatus = makeBuildLabel(buildTab, "", 0)
buildStatus.TextColor3 = Color3.fromRGB(80, 200, 120)
buildStatus.LayoutOrder = 0

local function setStatus(msg, isErr)
    buildStatus.Text = msg
    buildStatus.TextColor3 = isErr and Color3.fromRGB(220, 80, 80) or Color3.fromRGB(80, 200, 120)
end

-- Build name input
makeBuildLabel(buildTab, "build name", 1)
local nameInput = Instance.new("TextBox", buildTab)
nameInput.Size = UDim2.new(1, 0, 0, 28)
nameInput.BackgroundColor3 = Color3.fromRGB(22, 22, 22)
nameInput.BorderSizePixel = 0
nameInput.Font = Enum.Font.Code
nameInput.TextSize = 11
nameInput.TextColor3 = Color3.fromRGB(200, 200, 200)
nameInput.PlaceholderText = "enter build name..."
nameInput.PlaceholderColor3 = Color3.fromRGB(65, 65, 65)
nameInput.Text = "MyBuild"
nameInput.LayoutOrder = 2
nameInput.ClearTextOnFocus = false
nameInput.ZIndex = 7
Instance.new("UICorner", nameInput).CornerRadius = UDim.new(0, 7)
local nPad = Instance.new("UIPadding", nameInput)
nPad.PaddingLeft = UDim.new(0, 8)

makeBuildDivider(buildTab, 3)

-- Save my build
makeBuildBtn(buildTab, "Save My Build", 4, function()
    local name = nameInput.Text
    if name == "" then setStatus("enter a name first", true) return end
    local playerFolder = workspace:FindFirstChild("Bricks") and workspace.Bricks:FindFirstChild(player.Name)
    if not playerFolder then setStatus("no blocks found", true) return end
    local builddata = {}
    for _, v in playerFolder:GetChildren() do
        if v:IsA("BasePart") then
            local bd = saveBlock(v)
            if bd then table.insert(builddata, bd) end
        end
    end
    if #builddata == 0 then setStatus("no blocks to save", true) return end
    pcall(function()
        writefile(BUILDS_FOLDER .. "/" .. name .. ".json", jsonEncode(builddata))
    end)
    setStatus("saved " .. #builddata .. " blocks as '" .. name .. "'")
    refreshSavesList()
end)

-- Save server builds
makeBuildBtn(buildTab, "Save Server Builds", 5, function()
    local name = nameInput.Text
    if name == "" then setStatus("enter a name first", true) return end
    local builddata = {}
    for _, v in workspace:GetDescendants() do
        if v:IsA("BasePart") and v.Name == "Brick" then
            local bd = saveBlock(v)
            if bd then table.insert(builddata, bd) end
        end
    end
    if #builddata == 0 then setStatus("no blocks found", true) return end
    pcall(function()
        writefile(BUILDS_FOLDER .. "/" .. name .. ".json", jsonEncode(builddata))
    end)
    setStatus("saved " .. #builddata .. " blocks as '" .. name .. "'")
    refreshSavesList()
end)

makeBuildDivider(buildTab, 55)

-- ==================
-- SAVE SPECIFIC PLAYERS BLOCK
-- ==================
makeBuildLabel(buildTab, "save specific player's build", 56)

local playerNameInput = Instance.new("TextBox", buildTab)
playerNameInput.Size = UDim2.new(1, 0, 0, 28)
playerNameInput.BackgroundColor3 = Color3.fromRGB(22, 22, 22)
playerNameInput.BorderSizePixel = 0
playerNameInput.Font = Enum.Font.Code
playerNameInput.TextSize = 11
playerNameInput.TextColor3 = Color3.fromRGB(200, 200, 200)
playerNameInput.PlaceholderText = "enter player name..."
playerNameInput.PlaceholderColor3 = Color3.fromRGB(65, 65, 65)
playerNameInput.Text = ""
playerNameInput.LayoutOrder = 57
playerNameInput.ClearTextOnFocus = false
playerNameInput.ZIndex = 7
Instance.new("UICorner", playerNameInput).CornerRadius = UDim.new(0, 7)
local pnPad = Instance.new("UIPadding", playerNameInput)
pnPad.PaddingLeft = UDim.new(0, 8)

makeBuildBtn(buildTab, "Save Player's Build", 58, function()
    local targetName = playerNameInput.Text
    if targetName == "" then setStatus("enter a player name", true) return end
    local saveName = nameInput.Text
    if saveName == "" then setStatus("enter a build name too", true) return end

    -- find matching player (partial name ok)
    local targetFolder = nil
    local bricksFolder = workspace:FindFirstChild("Bricks")
    if not bricksFolder then setStatus("no Bricks folder found", true) return end

    for _, folder in bricksFolder:GetChildren() do
        if folder.Name:lower():find(targetName:lower(), 1, true) then
            targetFolder = folder
            break
        end
    end

    if not targetFolder then setStatus("player '" .. targetName .. "' not found", true) return end

    local builddata = {}
    for _, v in targetFolder:GetChildren() do
        if v:IsA("BasePart") then
            local bd = saveBlock(v)
            if bd then table.insert(builddata, bd) end
        end
    end
    if #builddata == 0 then setStatus("no blocks from " .. targetFolder.Name, true) return end
    pcall(function()
        writefile(BUILDS_FOLDER .. "/" .. saveName .. ".json", jsonEncode(builddata))
    end)
    setStatus("saved " .. #builddata .. " blocks from " .. targetFolder.Name)
    refreshSavesList()
end)

makeBuildDivider(buildTab, 6)

-- Saved builds list
makeBuildLabel(buildTab, "saved builds", 7)

local savesFrame = Instance.new("Frame", buildTab)
savesFrame.Size = UDim2.new(1, 0, 0, 80)
savesFrame.BackgroundColor3 = Color3.fromRGB(18, 18, 18)
savesFrame.BorderSizePixel = 0
savesFrame.LayoutOrder = 8
savesFrame.ZIndex = 7
Instance.new("UICorner", savesFrame).CornerRadius = UDim.new(0, 7)

local savesScroll = Instance.new("ScrollingFrame", savesFrame)
savesScroll.Size = UDim2.new(1, 0, 1, 0)
savesScroll.BackgroundTransparency = 1
savesScroll.BorderSizePixel = 0
savesScroll.ScrollBarThickness = 2
savesScroll.ScrollBarImageColor3 = Color3.fromRGB(60, 60, 60)
savesScroll.ZIndex = 8
local savesLayout = Instance.new("UIListLayout", savesScroll)
savesLayout.Padding = UDim.new(0, 2)
local savesPad = Instance.new("UIPadding", savesScroll)
savesPad.PaddingLeft = UDim.new(0, 4)
savesPad.PaddingRight = UDim.new(0, 4)
savesPad.PaddingTop = UDim.new(0, 4)
savesLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    savesScroll.CanvasSize = UDim2.new(0, 0, 0, savesLayout.AbsoluteContentSize.Y + 8)
end)

local selectedSaveBtn = nil
local selectedBuild = nil
local selectedBuildName = nil

function refreshSavesList()
    for _, c in savesScroll:GetChildren() do
        if c:IsA("TextButton") or c:IsA("TextLabel") then c:Destroy() end
    end
    local saves = listSaves()
    if #saves == 0 then
        local empty = Instance.new("TextLabel", savesScroll)
        empty.Size = UDim2.new(1, 0, 0, 20)
        empty.BackgroundTransparency = 1
        empty.Font = Enum.Font.Gotham
        empty.TextSize = 10
        empty.TextColor3 = Color3.fromRGB(70, 70, 70)
        empty.Text = "no saves yet"
        empty.ZIndex = 9
        return
    end
    for _, name in saves do
        local btn = Instance.new("TextButton", savesScroll)
        btn.Size = UDim2.new(1, 0, 0, 22)
        btn.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
        btn.BorderSizePixel = 0
        btn.Font = Enum.Font.Gotham
        btn.TextSize = 11
        btn.TextColor3 = Color3.fromRGB(170, 170, 170)
        btn.Text = name
        btn.ZIndex = 9
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 5)
        btn.MouseButton1Click:Connect(function()
            if selectedSaveBtn then
                selectedSaveBtn.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
                selectedSaveBtn.TextColor3 = Color3.fromRGB(170, 170, 170)
            end
            selectedSaveBtn = btn
            btn.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
            btn.TextColor3 = Color3.fromRGB(220, 220, 220)
            selectedBuildName = name
            local ok, data = pcall(function()
                return jsonDecode(readfile(BUILDS_FOLDER .. "/" .. name .. ".json"))
            end)
            if ok then
                selectedBuild = data
                setStatus("selected: " .. name .. " (" .. #data .. " blocks)")
            else
                setStatus("failed to load " .. name, true)
            end
        end)
    end
end

refreshSavesList()

makeBuildDivider(buildTab, 9)

-- Cross-server load (manual button, still here if you want to force a reload)
local function loadLastBuild(silent)
    local ok, data = pcall(function()
        return jsonDecode(readfile(BUILDS_FOLDER .. "/_lastbuild.json"))
    end)
    if not ok or not data then
        if not silent then setStatus("no cross-server build found", true) end
        return false
    end
    selectedBuild = data.data
    selectedBuildName = data.name or "cross-server"
    if not silent then
        setStatus("loaded: " .. (data.name or "cross-server") .. " (" .. #selectedBuild .. " blocks)")
    end
    return true
end

makeBuildBtn(buildTab, "Load Last Build (Cross-Server)", 91, function()
    loadLastBuild(false)
end)

-- Auto-continue toggle: if a build was running when you left (RJ/hop), pick it back
-- up automatically instead of sitting idle. Off by default since not everyone wants this.
local autoContinueBuild = true
makeToggle(buildTab, "Auto-Continue Build On Rejoin", 92, function(state)
    autoContinueBuild = state
end)

-- ==================
-- AUTO BUILD (FIXED)
-- Uses the same build method as Extra Stuff:
-- equip tool to Character, teleport to block, fire event, wait for ChildAdded
-- ==================

-- Track newly placed blocks via ChildAdded on player's bricks folder
local cubechild = nil

local function setupBrickListener()
    if cubechild then cubechild:Disconnect() end
    local bfolder = workspace:FindFirstChild("Bricks") and workspace.Bricks:FindFirstChild(player.Name)
    if bfolder then
        cubechild = bfolder.ChildAdded:Connect(function(child)
            childcube = child
            built = true
        end)
    end
end

setupBrickListener()
player.CharacterAdded:Connect(function()
    task.wait(1)
    setupBrickListener()
end)

-- Get tool's event directly from Backpack — no equip, no Parent reassignment.
-- Falls back to Character only if the tool genuinely isn't in Backpack (e.g. it's
-- already equipped from a prior session), so this still works either way without
-- ever moving anything itself.
local function getBackpackEvent(toolName)
    local bp = player.Backpack:FindFirstChild(toolName)
    if bp and bp:FindFirstChild("Script") and bp.Script:FindFirstChild("Event") then
        return bp.Script.Event
    end
    local ct = player.Character and player.Character:FindFirstChild(toolName)
    if ct and ct:FindFirstChild("Script") and ct.Script:FindFirstChild("Event") then
        return ct.Script.Event
    end
    return nil
end

-- Friend's getInfiniteBuildArgs: finds adjacent block to build from for infinite range
local function getInfiniteBuildArgs(targetPos)
    local bricks = workspace:FindFirstChild("Bricks")
    if bricks then
        for _, p in ipairs(bricks:GetDescendants()) do
            if p:IsA("BasePart") then
                local diff = targetPos - p.Position
                if math.abs(diff.Magnitude - 4) < 0.2 then
                    local normal = Enum.NormalId.Top
                    if     diff.X >  3 then normal = Enum.NormalId.Right
                    elseif diff.X < -3 then normal = Enum.NormalId.Left
                    elseif diff.Y >  3 then normal = Enum.NormalId.Top
                    elseif diff.Y < -3 then normal = Enum.NormalId.Bottom
                    elseif diff.Z >  3 then normal = Enum.NormalId.Back
                    elseif diff.Z < -3 then normal = Enum.NormalId.Front
                    end
                    return p, normal, targetPos
                end
            end
        end
    end
    return workspace.Terrain, Enum.NormalId.Top, targetPos
end

-- Place one block using getInfiniteBuildArgs for infinite range
local function placeBlock(pos, bsize)
    built = false
    childcube = nil
    local c = 0

    local buildEvent = getBackpackEvent("Build")
    if not buildEvent then return nil end

    -- use adjacent block method (friend's approach) for infinite placement
    local tBlock, tNorm, tHit = getInfiniteBuildArgs(pos)
    local args = {tBlock, tNorm, tHit, bsize or "normal"}

    pcall(function() buildEvent:FireServer(table.unpack(args)) end)

    repeat
        c = c + 1
        buildEvent = getBackpackEvent("Build") or buildEvent
        -- refresh getInfiniteBuildArgs each retry in case new blocks were placed
        tBlock, tNorm, tHit = getInfiniteBuildArgs(pos)
        args = {tBlock, tNorm, tHit, bsize or "normal"}
        if buildEvent then
            pcall(function() buildEvent:FireServer(table.unpack(args)) end)
        end
        task.wait(0.08)
    until (built and childcube) or stopped or skipblock or c > 200

    built = false
    return childcube
end

-- Paint block using friend's method: fires color+material together with "both 🤝"
local function paintBlock(block, color, matStr, origmat)
    if not block or not block.Parent then return end
    local c = 0
    local pos = block.Position + block.Size / 2
    local mat = matStr or getMaterialStr(block.Material)

    local paintEvent = getBackpackEvent("Paint")
    if not paintEvent then return end

    if color then
        -- use "both 🤝" to set color AND material in one call (friend's method)
        local args = {block, Enum.NormalId.Top, pos, "both \xF0\x9F\xA4\x9D", color, mat, ""}
        c = 0
        repeat
            c = c + 1
            paintEvent = getBackpackEvent("Paint") or paintEvent
            if paintEvent and block and block.Parent then
                pos = block.Position + block.Size / 2
                args[3] = pos
                pcall(function() paintEvent:FireServer(table.unpack(args)) end)
            end
            task.wait(0.2)
        until not block or not block.Parent
            or (math.abs(block.Color.R - color.R) < 0.02
                and math.abs(block.Color.G - color.G) < 0.02
                and math.abs(block.Color.B - color.B) < 0.02)
            or stopped or skipblock or c > 200
    end
end

-- Resize block: fire Shape event directly from Backpack, per axis, no equip/teleport.
local function resizeBlock(block, targetSize)
    if not block or not block.Parent then return end

    local shapeEvent = getBackpackEvent("Shape")
    if not shapeEvent then return end

    local axes = {
        {Enum.NormalId.Right, "X"},
        {Enum.NormalId.Top,   "Y"},
        {Enum.NormalId.Back,  "Z"},
    }

    for _, axisData in ipairs(axes) do
        local face, axis = axisData[1], axisData[2]
        local target = targetSize[axis]
        local c = 0

        while block and block.Parent and block.Size[axis] ~= target and not stopped and not skipblock and c < target * 4 do
            c = c + 1
            local dir = block.Size[axis] > target and "decrease" or "increase"

            shapeEvent = getBackpackEvent("Shape") or shapeEvent

            if shapeEvent then
                pcall(function()
                    shapeEvent:FireServer(block, face, block.Position + block.Size / 2, dir)
                end)
            end

            task.wait(resizewait)
        end
    end
end

-- Verify build: check for missing blocks and fill them
local function verifyAndFill(build)
    local bfolder = workspace:FindFirstChild("Bricks") and workspace.Bricks:FindFirstChild(player.Name)
    if not bfolder then return 0 end
    local missing = 0
    for _, v in ipairs(build) do
        if stopped then break end
        local pos = Vector3.new(v.p[1], v.p[2], v.p[3])
        local found = false
        for _, bl in bfolder:GetChildren() do
            if bl:IsA("BasePart") and (bl.Position - pos).Magnitude < 3 then
                found = true
                break
            end
        end
        if not found then
            missing = missing + 1
            skipblock = false
            local placed = placeBlock(pos, v.s and "detailed" or "normal")
            if placed then
                local col = v.c and Color3.fromRGB(v.c[1], v.c[2], v.c[3]) or nil
                paintBlock(placed, col, v.m, v.o)
                if v.s then
                    resizeBlock(placed, Vector3.new(v.s[1], v.s[2], v.s[3]))
                end
            end
        end
    end
    return missing
end

local autoBuildSetOff = nil

-- Named so both the toggle's own click handler and the auto-continue-on-rejoin
-- logic below can call the exact same start path. Keeping this as one function
-- (instead of duplicating the task.spawn body) is what guarantees rejoin-triggered
-- builds run through identical equip/teleport/fire logic as a manually-toggled one.
local function startAutoBuild()
    autoBuildRunning = true
    stopped = false
    skipblock = false
    if not selectedBuild then
        setStatus("select a save first", true)
        autoBuildRunning = false
        if autoBuildSetOff then autoBuildSetOff() end
        return
    end

    task.spawn(function()
        local build = selectedBuild
        local buildName = selectedBuildName

        -- write cross-server file so other servers can pick this build back up after RJ.
        -- "complete = false" here marks it as in-progress; set true once we're done below,
        -- so a rejoin after a *finished* build doesn't needlessly replay it.
        pcall(function()
            writefile(BUILDS_FOLDER .. "/_lastbuild.json", jsonEncode({
                name = buildName,
                data = build,
                complete = false
            }))
        end)

        -- wait for char
        local char = player.Character or player.CharacterAdded:Wait()
        char:WaitForChild("HumanoidRootPart")

        -- ensure brick listener is active
        setupBrickListener()

        local total = #build
        setStatus("building " .. total .. " blocks...")

        for i, v in ipairs(build) do
            if not autoBuildRunning or stopped then break end
            skipblock = false

            local pos = Vector3.new(v.p[1], v.p[2], v.p[3])
            local bsize = v.s and "detailed" or "normal"

            local placed = placeBlock(pos, bsize)

            if placed then
                local col = v.c and Color3.fromRGB(v.c[1], v.c[2], v.c[3]) or nil
                paintBlock(placed, col, v.m, v.o)
                if v.s then
                    resizeBlock(placed, Vector3.new(v.s[1], v.s[2], v.s[3]))
                end
            end

            setStatus("building " .. i .. "/" .. total)
        end

        if stopped then
            setStatus("build stopped")
            autoBuildRunning = false
            if autoBuildSetOff then autoBuildSetOff() end
            return
        end

        setStatus("verifying build...")
        task.wait(0.5)
        local missing = verifyAndFill(build)

        if missing and missing > 0 then
            setStatus("fixed " .. missing .. " missing! done")
        else
            setStatus("build complete! " .. total .. " blocks")
        end

        -- mark this build as finished in the cross-server file so a later rejoin
        -- (for an unrelated reason) doesn't auto-replay a build that's already done
        pcall(function()
            writefile(BUILDS_FOLDER .. "/_lastbuild.json", jsonEncode({
                name = buildName,
                data = build,
                complete = true
            }))
        end)

        autoBuildRunning = false
        if autoBuildSetOff then autoBuildSetOff() end
    end)
end

local _, autoBuildSetOffRef, autoBuildSetOnRef = makeToggle(buildTab, "Auto Build (loads selected)", 10, function(state)
    if state then
        startAutoBuild()
    else
        autoBuildRunning = false
        stopped = true
        skipblock = false
    end
end)
autoBuildSetOff = autoBuildSetOffRef
local autoBuildSetOn = autoBuildSetOnRef

-- Auto-continue: if the last build was interrupted (RJ/server hop mid-build),
-- pick it back up on load. Runs once, after the UI and brick listener are ready.
task.spawn(function()
    task.wait(2)  -- let character/backpack settle first
    if not autoContinueBuild then return end
    local ok, data = pcall(function()
        return jsonDecode(readfile(BUILDS_FOLDER .. "/_lastbuild.json"))
    end)
    if not ok or not data then return end
    if data.complete then return end  -- last build finished normally, nothing to resume
    if not data.data or #data.data == 0 then return end

    selectedBuild = data.data
    selectedBuildName = data.name or "cross-server"
    setStatus("resuming interrupted build: " .. selectedBuildName .. " (" .. #selectedBuild .. " blocks)")
    if autoBuildSetOn then autoBuildSetOn() end
    startAutoBuild()
end)

-- Skip block button
makeBuildBtn(buildTab, "Skip Block", 105, function()
    skipblock = true
    task.delay(0.1, function() skipblock = false end)
end)

-- Stop build button
makeBuildBtn(buildTab, "Stop Build", 11, function()
    autoBuildRunning = false
    stopped = true
    setStatus("build stopped")
end)

makeBuildDivider(buildTab, 12)

-- Delete save
makeBuildBtn(buildTab, "Delete Selected Save", 13, function()
    if not selectedBuildName then setStatus("select a save first", true) return end
    pcall(function()
        delfile(BUILDS_FOLDER .. "/" .. selectedBuildName .. ".json")
    end)
    setStatus("deleted: " .. selectedBuildName)
    selectedBuild = nil
    selectedBuildName = nil
    selectedSaveBtn = nil
    refreshSavesList()
end)

makeBuildDivider(buildTab, 14)

-- Get Decal Tool
makeBuildLabel(buildTab, "decal tool", 15)
makeBuildBtn(buildTab, "Get Decal Tool", 16, function()
    if player.Backpack:FindFirstChild("Decal Tool") or (player.Character and player.Character:FindFirstChild("Decal Tool")) then
        setStatus("already in inventory!")
        return
    end
    local dectool = Instance.new("Tool")
    dectool.Name = "Decal Tool"
    dectool.RequiresHandle = true
    local handle = Instance.new("Part")
    handle.Size = Vector3.one * 1.001
    handle.Shape = Enum.PartType.Cylinder
    handle.CanCollide = false
    handle.Name = "Handle"
    handle.Color = Color3.fromRGB(0, 255, 255)
    handle.Parent = dectool
    dectool.Parent = player.Backpack
    setStatus("decal tool added to inventory!")
end)

-- ==================
-- SHARED HELPERS
-- ==================
local function makeBtn(parent, text, order, callback)
    local btn = Instance.new("TextButton", parent)
    btn.Size = UDim2.new(1, 0, 0, 30)
    btn.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    btn.BorderSizePixel = 0
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 11
    btn.TextColor3 = Color3.fromRGB(200, 200, 200)
    btn.Text = text
    btn.LayoutOrder = order or 0
    btn.ZIndex = 7
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 7)
    local st = Instance.new("UIStroke", btn)
    st.Color = Color3.fromRGB(45, 45, 45)
    st.Thickness = 1
    btn.MouseButton1Click:Connect(callback)
    return btn
end

local function sayInChat(text)
    pcall(function()
        game:GetService("TextChatService").TextChannels.RBXGeneral:SendAsync(text)
    end)
end

local function hasArkenstone()
    return player.Character and player.Character:FindFirstChild("The Arkenstone")
        or player.Backpack:FindFirstChild("The Arkenstone")
end

local function equipArkenstone()
    local a = player.Backpack:FindFirstChild("The Arkenstone")
    if a and player.Character then a.Parent = player.Character end
    return player.Character and player.Character:FindFirstChild("The Arkenstone")
end

-- ==================
-- AUTOMATION TAB
-- ==================
local autoTab = createTab("Auto")

local autoStatus = makeLabel(autoTab, "", 0)
autoStatus.TextColor3 = Color3.fromRGB(80, 200, 120)
autoStatus.LayoutOrder = 0

-- Auto pick up Enlighten/Arkenstone
local pickupRunning = false
makeToggle(autoTab, "Auto pickup Enlighten/Arkenstone", 1, function(state)
    pickupRunning = state
    if not state then return end
    task.spawn(function()
        while pickupRunning do
            local char = player.Character
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            if hum and hum.Health > 0 then
                -- check workspace directly for The Arkenstone dropped there
                for _, v in workspace:GetChildren() do
                    if v:IsA("Tool") and v.Name == "The Arkenstone" then
                        pcall(function() hum:EquipTool(v) end)
                        autoStatus.Text = "picked up: The Arkenstone"
                    end
                end
                -- also check for any enlighten-related tools dropped in workspace
                for _, v in workspace:GetChildren() do
                    if v:IsA("Tool") and v:FindFirstChild("Handle")
                        and v.Name:lower():find("enlighten") then
                        pcall(function() hum:EquipTool(v) end)
                        autoStatus.Text = "picked up: " .. v.Name
                    end
                end
            end
            task.wait(0.1)
        end
        autoStatus.Text = ""
    end)
end)

makeDivider(autoTab, 2)

-- Auto keep Arkenstone equipped
local autoArkRunning = false
makeToggle(autoTab, "Auto keep Arkenstone equipped", 3, function(state)
    autoArkRunning = state
    if not state then return end
    task.spawn(function()
        while autoArkRunning do
            local char = player.Character
            if char then
                local a = player.Backpack:FindFirstChild("The Arkenstone")
                if a then
                    pcall(function() a.Parent = char end)
                    autoStatus.Text = "arkenstone kept"
                end
            end
            task.wait(0.2)
        end
        autoStatus.Text = ""
    end)
end)

makeDivider(autoTab, 4)

-- ==================
-- STASH TAB
-- ==================
local stashTab = createTab("Stash")

local stashStatus = makeLabel(stashTab, "", 0)
stashStatus.TextColor3 = Color3.fromRGB(80, 200, 120)
stashStatus.LayoutOrder = 0

local stopstash = false

-- random position far away like command line
local rng = Random.new()
local function randomoutlier(positiveonly)
    local ro = rng:NextInteger(5000, 10000)
    if positiveonly or rng:NextNumber() >= 0.5 then return ro
    else return -ro end
end

local cfolder = workspace:FindFirstChild("Bricks")
local playerIndex = 1
if cfolder then
    for i, v in cfolder:GetChildren() do
        if v.Name == player.Name then playerIndex = i break end
    end
end

local stashposition = Vector3.new(
    randomoutlier(),
    randomoutlier(true) + (playerIndex * 40),
    randomoutlier()
)

-- invisible stash platform
local invisstashplatform = Instance.new("Part")
invisstashplatform.CFrame = CFrame.new(stashposition - Vector3.new(0, 10, 0))
invisstashplatform.Anchored = true
invisstashplatform.Transparency = 0.9
invisstashplatform.Color = Color3.fromRGB(0, 255, 0)
invisstashplatform.Size = Vector3.new(200, 0, 1000)
invisstashplatform.CanCollide = true
invisstashplatform.Parent = workspace

local function setStashStatus(msg, isErr)
    stashStatus.Text = msg
    stashStatus.TextColor3 = isErr and Color3.fromRGB(220,80,80) or Color3.fromRGB(80,200,120)
end

-- stash amount input
makeLabel(stashTab, "stash amount", 1)
local stashInput = Instance.new("TextBox", stashTab)
stashInput.Size = UDim2.new(1, 0, 0, 28)
stashInput.BackgroundColor3 = Color3.fromRGB(22, 22, 22)
stashInput.BorderSizePixel = 0
stashInput.Font = Enum.Font.Code
stashInput.TextSize = 11
stashInput.TextColor3 = Color3.fromRGB(200, 200, 200)
stashInput.PlaceholderText = "how many stashes..."
stashInput.PlaceholderColor3 = Color3.fromRGB(65, 65, 65)
stashInput.Text = "2"
stashInput.LayoutOrder = 2
stashInput.ClearTextOnFocus = false
stashInput.ZIndex = 7
Instance.new("UICorner", stashInput).CornerRadius = UDim.new(0, 7)
local stashPad = Instance.new("UIPadding", stashInput)
stashPad.PaddingLeft = UDim.new(0, 8)

makeDivider(stashTab, 3)

-- Start stash
makeBtn(stashTab, "Start Stash", 4, function()
    if not hasArkenstone() then
        setStashStatus("need Arkenstone/Enlighten!", true)
        return
    end
    local stashamt = tonumber(stashInput.Text) or 2
    stopstash = false
    task.spawn(function()
        local char = player.Character
        if not char then return end
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if not hrp then return end
        local originalCFrame = hrp.CFrame

        -- mute self first
        if not player:HasTag("Muted") then
            task.wait(0.5)
            sayInChat(";mute me")
            task.wait(3.5)
        end

        -- teleport to stash position
        hrp.CFrame = CFrame.new(stashposition + Vector3.new(0, 30, 0))

        for i = 1, stashamt do
            if stopstash then break end

            -- check arkenstone
            if not hasArkenstone() then
                setStashStatus("lost arkenstone, stopping", true)
                stopstash = true
                break
            end

            -- grid position
            local clonesFolder = workspace:FindFirstChild("Clones") and workspace.Clones:FindFirstChild(player.Name)
            local cloneamt = clonesFolder and #clonesFolder:GetChildren() or 0
            local x = (cloneamt % 4) * 10
            local y = math.floor(cloneamt / 4) * 10

            -- move to position
            hrp.CFrame = CFrame.new(stashposition + Vector3.new(x, 0, y))
            task.wait(0.3)
            if stopstash then break end

            -- equip arkenstone
            equipArkenstone()
            task.wait(0.3)
            if stopstash then break end

            -- get bucket: loop until we have it, try 25162389 and 25162389.1
            local hasBucket = player.Backpack:FindFirstChild("BlueBucket") or (char:FindFirstChild("BlueBucket"))
            if not hasBucket then
                setStashStatus("getting bucket...")
                local bucketAttempts = 0
                local useAlt = false
                while not hasBucket and not stopstash do
                    bucketAttempts = bucketAttempts + 1
                    local gearId = useAlt and "25162389.1" or "25162389"
                    sayInChat(";gear me " .. gearId)
                    useAlt = not useAlt
                    task.wait(1) -- 1s delay to avoid chat cooldown
                    task.wait(2)
                    hasBucket = player.Backpack:FindFirstChild("BlueBucket") or char:FindFirstChild("BlueBucket")
                    if bucketAttempts > 10 then
                        setStashStatus("can't get bucket, skipping", true)
                        break
                    end
                end
            end

            if stopstash then break end

            -- equip both arkenstone AND bucket to character
            equipArkenstone()
            task.wait(0.2)
            local bucket = player.Backpack:FindFirstChild("BlueBucket")
            if bucket then
                bucket.Parent = char
                task.wait(0.2)
            end

            if stopstash then break end

            -- freeze clone unfreeze with 1s between each command
            sayInChat(";freeze me")
            task.wait(1)
            if stopstash then break end

            sayInChat(";clone me")
            task.wait(1)
            if stopstash then break end

            sayInChat(";unfreeze me")
            task.wait(1)
            if stopstash then break end

            -- move up and wait 8s cooldown between clones
            hrp.CFrame = CFrame.new(stashposition + Vector3.new(x, 15, y))
            setStashStatus("stash " .. i .. "/" .. stashamt .. " — waiting 8s cooldown...")
            for w = 1, 8 do
                task.wait(1)
                if stopstash then break end
            end

            setStashStatus("stash " .. i .. "/" .. stashamt .. " done")
        end

        -- unmute and return
        task.wait(0.5)
        sayInChat(";unmute me")
        task.wait(0.5)

        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then hum:UnequipTools() end
        task.wait(0.3)
        hrp.CFrame = originalCFrame

        if not stopstash then
            setStashStatus("stash complete! " .. stashamt .. " done")
        else
            setStashStatus("stash stopped")
        end
        stopstash = false
    end)
end)

-- Stop stash
makeBtn(stashTab, "Stop Stash", 5, function()
    stopstash = true
    setStashStatus("stopping stash...")
end)

makeDivider(stashTab, 6)

-- Go to stash
makeBtn(stashTab, "Go To Stash", 7, function()
    local char = player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if hrp then
        hrp.CFrame = CFrame.new(stashposition + Vector3.new(-20, 30, -20))
        setStashStatus("teleported to stash")
    end
end)

-- Go to spawn
makeBtn(stashTab, "Go To Spawn", 8, function()
    local char = player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local spawn = workspace:FindFirstChild("Spawn")
    if hrp and spawn then
        hrp.CFrame = CFrame.new(spawn.Position + Vector3.new(0, 5, 0))
        setStashStatus("teleported to spawn")
    elseif hrp then
        hrp.CFrame = CFrame.new(Vector3.new(0, 10, 0))
        setStashStatus("teleported to origin")
    end
end)

-- Toggle stash platform
makeBtn(stashTab, "Toggle Stash Platform", 9, function()
    invisstashplatform.CanCollide = not invisstashplatform.CanCollide
    invisstashplatform.Transparency = invisstashplatform.CanCollide and 0.7 or 1
    setStashStatus("platform: " .. (invisstashplatform.CanCollide and "ON" or "OFF"))
end)

makeDivider(stashTab, 10)
makeLabel(stashTab, "stash position (auto-generated)", 11)
makeValue(stashTab, math.round(stashposition.X)..","..math.round(stashposition.Y)..","..math.round(stashposition.Z), 12)

-- ==================
-- ABUSE TAB
-- ==================
local abuseTab = createTab("Abuse")

local abuseStatus = makeLabel(abuseTab, "", 0)
abuseStatus.TextColor3 = Color3.fromRGB(80, 200, 120)
abuseStatus.LayoutOrder = 0

local function setAbuseStatus(msg, isErr)
    abuseStatus.Text = msg
    abuseStatus.TextColor3 = isErr and Color3.fromRGB(220,80,80) or Color3.fromRGB(80,200,120)
end

makeLabel(abuseTab, "select players (multi-select)", 1)

-- Player list frame
local plrListFrame = Instance.new("Frame", abuseTab)
plrListFrame.Size = UDim2.new(1, 0, 0, 110)
plrListFrame.BackgroundColor3 = Color3.fromRGB(18, 18, 18)
plrListFrame.BorderSizePixel = 0
plrListFrame.LayoutOrder = 2
plrListFrame.ZIndex = 7
Instance.new("UICorner", plrListFrame).CornerRadius = UDim.new(0, 7)

local plrListScroll = Instance.new("ScrollingFrame", plrListFrame)
plrListScroll.Size = UDim2.new(1, 0, 1, 0)
plrListScroll.BackgroundTransparency = 1
plrListScroll.BorderSizePixel = 0
plrListScroll.ScrollBarThickness = 2
plrListScroll.ScrollBarImageColor3 = Color3.fromRGB(60, 60, 60)
plrListScroll.ZIndex = 8
local plrListLayout = Instance.new("UIListLayout", plrListScroll)
plrListLayout.Padding = UDim.new(0, 2)
local plrListPad = Instance.new("UIPadding", plrListScroll)
plrListPad.PaddingLeft = UDim.new(0, 4)
plrListPad.PaddingRight = UDim.new(0, 4)
plrListPad.PaddingTop = UDim.new(0, 4)
plrListLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    plrListScroll.CanvasSize = UDim2.new(0, 0, 0, plrListLayout.AbsoluteContentSize.Y + 8)
end)

local selectedPlayers = {}
local plrBtns = {}
local allBtn = nil

local function refreshAbusePlayerList()
    for _, c in plrListScroll:GetChildren() do
        if c:IsA("TextButton") or c:IsA("TextLabel") then c:Destroy() end
    end
    plrBtns = {}

    -- > Select All button
    allBtn = Instance.new("TextButton", plrListScroll)
    allBtn.Size = UDim2.new(1, 0, 0, 22)
    allBtn.BackgroundColor3 = selectedPlayers["__ALL__"] and Color3.fromRGB(0, 150, 255) or Color3.fromRGB(30, 30, 30)
    allBtn.BorderSizePixel = 0
    allBtn.Font = Enum.Font.GothamBold
    allBtn.TextSize = 11
    allBtn.TextColor3 = Color3.fromRGB(220, 220, 220)
    allBtn.Text = "> Select All"
    allBtn.ZIndex = 9
    Instance.new("UICorner", allBtn).CornerRadius = UDim.new(0, 5)
    allBtn.MouseButton1Click:Connect(function()
        if selectedPlayers["__ALL__"] then
            selectedPlayers = {}
            allBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
            for _, b in plrBtns do b.BackgroundColor3 = Color3.fromRGB(25, 25, 25) end
        else
            selectedPlayers = {["__ALL__"] = true}
            for _, p in Players:GetPlayers() do
                if p ~= player then selectedPlayers[p.Name] = true end
            end
            allBtn.BackgroundColor3 = Color3.fromRGB(0, 150, 255)
            for _, b in plrBtns do b.BackgroundColor3 = Color3.fromRGB(0, 120, 200) end
        end
        local count = 0
        for k in selectedPlayers do if k ~= "__ALL__" then count += 1 end end
        setAbuseStatus(count .. " selected")
    end)

    -- individual player buttons
    for _, p in Players:GetPlayers() do
        if p == player then continue end
        local btn = Instance.new("TextButton", plrListScroll)
        btn.Size = UDim2.new(1, 0, 0, 22)
        btn.BackgroundColor3 = selectedPlayers[p.Name] and Color3.fromRGB(0, 120, 200) or Color3.fromRGB(25, 25, 25)
        btn.BorderSizePixel = 0
        btn.Font = Enum.Font.Gotham
        btn.TextSize = 11
        btn.TextColor3 = Color3.fromRGB(200, 200, 200)
        btn.Text = p.Name
        btn.ZIndex = 9
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 5)
        table.insert(plrBtns, btn)
        local pname = p.Name
        btn.MouseButton1Click:Connect(function()
            if selectedPlayers[pname] then
                selectedPlayers[pname] = nil
                selectedPlayers["__ALL__"] = nil
                btn.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
                if allBtn then allBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 30) end
            else
                selectedPlayers[pname] = true
                btn.BackgroundColor3 = Color3.fromRGB(0, 120, 200)
            end
            local count = 0
            for k in selectedPlayers do if k ~= "__ALL__" then count += 1 end end
            setAbuseStatus(count .. " selected")
        end)
    end
end

Players.PlayerAdded:Connect(function() task.wait(0.5) refreshAbusePlayerList() end)
Players.PlayerRemoving:Connect(function(p)
    selectedPlayers[p.Name] = nil
    task.wait(0.2)
    refreshAbusePlayerList()
end)
refreshAbusePlayerList()

makeBtn(abuseTab, "Refresh Player List", 3, function()
    selectedPlayers = {}
    refreshAbusePlayerList()
    setAbuseStatus("list refreshed")
end)

makeDivider(abuseTab, 4)

local function getTargets()
    local targets = {}
    for name, v in selectedPlayers do
        if name ~= "__ALL__" and v then
            table.insert(targets, name:gsub("_", "."):sub(1, 7))
        end
    end
    -- mapseed if more than 4 selected
    local mapseedAllowed = #targets > 4
    return targets, mapseedAllowed
end

local abuseRunning = false
makeToggle(abuseTab, "Full Abuse (toggle)", 5, function(state)
    abuseRunning = state
    if not state then
        setAbuseStatus("abuse stopped")
        return
    end
    local targets, mapseedAllowed = getTargets()
    if #targets == 0 then
        setAbuseStatus("select players first", true)
        abuseRunning = false
        return
    end
    task.spawn(function()
        while abuseRunning do
            -- TCO supports multi-target: ;oof user1 user2 user3
            -- chunk into groups of 4 (safe limit per command)
            local chunks = {}
            local chunk = {}
            for _, sn in targets do
                table.insert(chunk, sn)
                if #chunk >= 4 then
                    table.insert(chunks, table.concat(chunk, " "))
                    chunk = {}
                end
            end
            if #chunk > 0 then table.insert(chunks, table.concat(chunk, " ")) end

            local commands = {"oof", "mute", "dumb", "myopic", "blind", "delcubes"}
            for _, cmd in commands do
                if not abuseRunning then break end
                for _, ch in chunks do
                    if not abuseRunning then break end
                    sayInChat(";" .. cmd .. " " .. ch)
                    setAbuseStatus(cmd .. " → " .. ch)
                    task.wait(1)
                end
            end

            if mapseedAllowed and abuseRunning then
                sayInChat(";mapseed nan")
                setAbuseStatus("mapseed sent (>" .. #targets .. " targets)")
                task.wait(1)
            end

            if abuseRunning then
                setAbuseStatus("looping... (" .. #targets .. " targets)")
                task.wait(math.random(2, 3))
            end
        end
    end)
end)

-- ==================
-- MIC TAB
-- ==================
local micTab = createTab("Misc")

local micStatus = makeLabel(micTab, "", 0)
micStatus.TextColor3 = Color3.fromRGB(80, 200, 120)
micStatus.LayoutOrder = 0

local spychatLog = {}

-- Always-on spychat using exact command line OnIncomingMessage method
local tcs = game:GetService("TextChatService")
local prevOIM = tcs.OnIncomingMessage

tcs.OnIncomingMessage = function(mdata)
    if prevOIM then pcall(prevOIM, mdata) end

    if mdata.Status ~= Enum.TextChatMessageStatus.Success then return end

    local src = mdata.TextSource
    if not src then return end
    local p = Players:GetPlayerByUserId(src.UserId)
    if not p then return end

    local msg = mdata.Text
    if not msg or msg == "" then return end

    -- log in format: <playername>: "what they said"
    local entry = p.Name .. ": \"" .. msg .. "\""
    table.insert(spychatLog, entry)
end

-- also catch local player's own chatted
player.Chatted:Connect(function(msg)
    if not msg or msg == "" then return end
    local entry = player.Name .. ": \"" .. msg .. "\""
    table.insert(spychatLog, entry)
end)

-- Fly toggle
makeDivider(micTab, 1)
makeLabel(micTab, "movement", 2)
makeToggle(micTab, "Fly", 3, function(state)
    local char = player.Character
    if not char then return end
    local flyScript = char:FindFirstChild("Flying")
    if flyScript then flyScript.Enabled = state end
    player:SetAttribute("Flying", state)
    if not state then
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if hrp then
            local bv = hrp:FindFirstChild("FlyBV")
            if bv then bv:Destroy() end
            local bg = hrp:FindFirstChild("FlyBG")
            if bg then bg:Destroy() end
        end
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then hum.PlatformStand = false end
    end
end)

makeDivider(micTab, 4)
makeLabel(micTab, "spy chat log", 5)

-- Download log
makeBtn(micTab, "Download Chat Log", 6, function()
    if #spychatLog == 0 then
        micStatus.Text = "no messages logged yet"
        return
    end
    local content = table.concat(spychatLog, "\n")
    pcall(function()
        writefile("ManesHubChatLog.txt", content)
        micStatus.Text = "saved! " .. #spychatLog .. " messages"
    end)
end)

-- Clear log
makeBtn(micTab, "Clear Log", 7, function()
    spychatLog = {}
    micStatus.Text = "log cleared"
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
    task.delay(0.2, function()
        bg.Visible = false
    end)
end

minBtn.MouseButton1Click:Connect(function()
    closeUI()
end)

closeBtn.MouseButton1Click:Connect(function()
    TweenService:Create(blur, TweenInfo.new(0.2), {Size = 0}):Play()
    task.delay(0.2, function()
        screenGui:Destroy()
        blur:Destroy()
    end)
end)

UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if input.KeyCode == Enum.KeyCode.RightShift then
        if isOpen then closeUI()
        else openUI() end
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

-- Draggable circle button
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
end)

print("ManesHub loaded. Tap M or press RightShift to open.")
