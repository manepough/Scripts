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

-- findbtools: gets event directly from backpack, no equipping needed
local function findbtools(name)
    local btools = {}
    for _, v in player.Backpack:GetChildren() do
        if v:IsA("Tool") and v.Name == name and v:FindFirstChild("Script") and v.Script:FindFirstChild("Event") then
            table.insert(btools, {bt = v, e = v.Script.Event})
        end
    end
    -- also check character in case it's already equipped
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
    return row
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

-- Delete all blocks - optimized, no red coloring, batch fire
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

            -- collect all bricks at once
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

-- Color picker row
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

-- Color 1 swatch
local swatch1 = Instance.new("TextButton", colorRow)
swatch1.Size = UDim2.new(0, 22, 0, 22)
swatch1.Position = UDim2.new(1, -56, 0.5, -11)
swatch1.BackgroundColor3 = glitchColor1
swatch1.BorderSizePixel = 0
swatch1.Text = ""
swatch1.ZIndex = 8
Instance.new("UICorner", swatch1).CornerRadius = UDim.new(0, 5)

-- Color 2 swatch
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

-- Preset colors for picker
local presets = {
    Color3.fromRGB(255,0,127),   -- hot pink
    Color3.fromRGB(0,0,0),       -- black
    Color3.fromRGB(255,255,255), -- white
    Color3.fromRGB(255,0,0),     -- red
    Color3.fromRGB(0,255,0),     -- green
    Color3.fromRGB(0,0,255),     -- blue
    Color3.fromRGB(255,165,0),   -- orange
    Color3.fromRGB(128,0,255),   -- purple
    Color3.fromRGB(0,255,255),   -- cyan
    Color3.fromRGB(255,255,0),   -- yellow
}

-- Color picker popup
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

-- Close picker if clicking elsewhere
UserInputService.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        pickerPopup.Visible = false
    end
end)

-- Glitch toggle
makeToggle(deadlyTab, "Glitch blocks", 6, function(state)
    glitchRunning = state
    if not state then return end
    task.spawn(function()
        local paints = findbtools("Paint")

        while glitchRunning do
            -- refresh paint tools each loop
            paints = findbtools("Paint")
            if #paints == 0 then task.wait(0.3) continue end

            local cfolder = workspace:FindFirstChild("Bricks")
            if not cfolder then task.wait(0.3) continue end

            -- collect all bricks once per loop
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
                            "both 🤝",
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

-- Materials map (same as Extra Stuff)
local materials = {}
materials[Enum.Material.SmoothPlastic] = "smooth"
materials[Enum.Material.Plastic] = "plastic"
materials[Enum.Material.Neon] = "neon"
materials[Enum.Material.Brick] = "bricks"
materials[Enum.Material.WoodPlanks] = "planks"
materials[Enum.Material.Ice] = "ice"
materials[Enum.Material.Grass] = "grass"
materials[Enum.Material.Sand] = "sand"
materials[Enum.Material.Snow] = "snow"
materials[Enum.Material.Glass] = "glass"
materials[Enum.Material.Wood] = "wood"
materials[Enum.Material.Slate] = "stone"
materials[Enum.Material.Metal] = "metal"
materials[Enum.Material.Concrete] = "concrete"
materials[Enum.Material.DiamondPlate] = "steel"
materials[Enum.Material.SmoothPlastic] = "smooth"
local swappedmaterials = {}
for i, v in pairs(materials) do swappedmaterials[v] = i end

local BUILDS_FOLDER = "ManesHubBuilds"
local stopped = false
local buildingExec = nil
local selectedBuild = nil
local selectedBuildName = nil

-- ensure folder exists
pcall(function()
    if not isfolder(BUILDS_FOLDER) then makefolder(BUILDS_FOLDER) end
end)

-- JSON helpers
local http = game:GetService("HttpService")

local function jsonEncode(t)
    return http:JSONEncode(t)
end
local function jsonDecode(s)
    return http:JSONDecode(s)
end

-- list saves
local function listSaves()
    local files = {}
    pcall(function()
        for _, v in listfiles(BUILDS_FOLDER) do
            local name = v:gsub(BUILDS_FOLDER .. "/", ""):gsub(BUILDS_FOLDER .. "\\", ""):gsub(".json", "")
            if name ~= "" then table.insert(files, name) end
        end
    end)
    return files
end

-- fire build event without holding tool
local function fireBuild(pos, size)
    local buildEvent = player.Backpack:FindFirstChild("Build")
    if buildEvent then
        buildEvent = buildEvent:FindFirstChild("Script") and buildEvent.Script:FindFirstChild("Event") and buildEvent.Script.Event
    end
    if not buildEvent then
        -- try from character
        local ct = player.Character and player.Character:FindFirstChild("Build")
        if ct and ct:FindFirstChild("Script") and ct.Script:FindFirstChild("Event") then
            buildEvent = ct.Script.Event
        end
    end
    if buildEvent then
        pcall(function()
            buildEvent:FireServer(
                workspace.Terrain,
                Enum.NormalId.Top,
                pos,
                "normal"
            )
        end)
    end
end

-- save a single block's data
local function saveBlock(bl)
    if not bl:IsA("BasePart") then return nil end
    local bd = {}
    bd.p = {bl.Position.X, bl.Position.Y, bl.Position.Z}
    bd.c = {math.round(bl.Color.R*255), math.round(bl.Color.G*255), math.round(bl.Color.B*255)}
    bd.m = materials[bl.Material] or "smooth"
    bd.o = bl.Material.Name
    bd.a = bl.Anchored
    bd.cc = bl.CanCollide
    if bl.Size.X ~= 4 or bl.Size.Y ~= 4 or bl.Size.Z ~= 4 then
        bd.s = {bl.Size.X, bl.Size.Y, bl.Size.Z}
    end
    return bd
end

-- Widget helpers (reuse from above)
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
    -- refresh dropdown
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

makeBuildDivider(buildTab, 6)

-- Saved builds list label
makeBuildLabel(buildTab, "saved builds", 7)

-- Saves dropdown (scrollable list of buttons)
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

function refreshSavesList()
    for _, c in savesScroll:GetChildren() do
        if c:IsA("TextButton") then c:Destroy() end
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

-- Auto build toggle
local autoBuildRunning = false
local autoBuildToggleRow = makeToggle(buildTab, "Auto Build (loads selected)", 10, function(state)
    autoBuildRunning = state
    stopped = not state
    if not state then return end
    if not selectedBuild then setStatus("select a save first", true) return end
    task.spawn(function()
        local build = selectedBuild
        local buildEvent = nil
        -- get event from backpack directly
        local bt = player.Backpack:FindFirstChild("Build")
        if bt and bt:FindFirstChild("Script") and bt.Script:FindFirstChild("Event") then
            buildEvent = bt.Script.Event
        end
        if not buildEvent then
            local ct = player.Character and player.Character:FindFirstChild("Build")
            if ct and ct:FindFirstChild("Script") and ct.Script:FindFirstChild("Event") then
                buildEvent = ct.Script.Event
            end
        end
        if not buildEvent then setStatus("no Build tool found", true) return end

        local paintEvent = nil
        local pt = player.Backpack:FindFirstChild("Paint")
        if pt and pt:FindFirstChild("Script") and pt.Script:FindFirstChild("Event") then
            paintEvent = pt.Script.Event
        end

        local total = #build
        for i, v in ipairs(build) do
            if not autoBuildRunning or stopped then break end
            local pos = Vector3.new(v.p[1], v.p[2], v.p[3])
            -- place block instantly using terrain as base
            pcall(function()
                buildEvent:FireServer(workspace.Terrain, Enum.NormalId.Top, pos, "normal")
            end)
            -- paint color if needed
            if paintEvent and v.c then
                local col = Color3.fromRGB(v.c[1], v.c[2], v.c[3])
                task.wait(0.05)
                -- find the placed block
                local placed = nil
                local bfolder = workspace.Bricks:FindFirstChild(player.Name)
                if bfolder then
                    for _, bl in bfolder:GetChildren() do
                        if bl:IsA("BasePart") and (bl.Position - pos).Magnitude < 3 then
                            placed = bl
                            break
                        end
                    end
                end
                if placed then
                    pcall(function()
                        paintEvent:FireServer(placed, Enum.NormalId.Top, placed.Position, "color", col, v.m or "smooth", "")
                    end)
                end
            end
            setStatus("building " .. i .. "/" .. total)
            task.wait(0.05)
        end
        if not stopped then
            setStatus("build complete! " .. total .. " blocks")
        end
        autoBuildRunning = false
    end)
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
local getDecalBtn = makeBuildBtn(buildTab, "Get Decal Tool", 16, function()
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

-- Minimize (-)
minBtn.MouseButton1Click:Connect(function()
    closeUI()
end)

-- Destroy (X) - destroys the whole UI
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

-- ==================
-- CIRCLE BUTTON DRAG
-- ==================
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
