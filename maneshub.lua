-- ManesHub

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local http = game:GetService("HttpService")

local player = Players.LocalPlayer
local mouse = player:GetMouse()
local mult = 4

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

-- Highlight for player builds
local buildHighlight = Instance.new("Highlight")
buildHighlight.Parent = game.CoreGui
buildHighlight.FillColor = Color3.fromRGB(0, 255, 0)
buildHighlight.FillTransparency = 0.9
buildHighlight.OutlineColor = Color3.fromRGB(0, 255, 0)
buildHighlight.OutlineTransparency = 0
buildHighlight.Adornee = nil

-- ==================
-- HELPERS
-- ==================

local function getEvent(toolName)
    local bt = player.Backpack:FindFirstChild(toolName)
    if bt and bt:FindFirstChild("Script") and bt.Script:FindFirstChild("Event") then
        return bt.Script.Event
    end
    if player.Character then
        local ct = player.Character:FindFirstChild(toolName)
        if ct and ct:FindFirstChild("Script") and ct.Script:FindFirstChild("Event") then
            return ct.Script.Event
        end
    end
    return nil
end

local function findbtools(name)
    local btools = {}
    local bt = player.Backpack:FindFirstChild(name)
    if bt and bt:FindFirstChild("Script") and bt.Script:FindFirstChild("Event") then
        table.insert(btools, {bt = bt, e = bt.Script.Event})
    end
    if player.Character then
        local ct = player.Character:FindFirstChild(name)
        if ct and ct:FindFirstChild("Script") and ct.Script:FindFirstChild("Event") then
            table.insert(btools, {bt = ct, e = ct.Script.Event})
        end
    end
    return btools
end

-- materials map
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
local swappedmaterials = {}
for i,v in pairs(materials) do swappedmaterials[v] = i end

-- saves
local BUILDS_FOLDER = "ManesHubBuilds"
pcall(function() if not isfolder(BUILDS_FOLDER) then makefolder(BUILDS_FOLDER) end end)

local function jsonEncode(t) return http:JSONEncode(t) end
local function jsonDecode(s) return http:JSONDecode(s) end

local function listSaves()
    local files = {}
    pcall(function()
        for _, v in listfiles(BUILDS_FOLDER) do
            local name = v:gsub(BUILDS_FOLDER.."/",""):gsub(BUILDS_FOLDER.."\\",""):gsub(".json","")
            if name ~= "" and name ~= "_lastbuild" then table.insert(files, name) end
        end
    end)
    return files
end

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

-- build state
local stopped     = false
local skipblock   = false
local childcube   = nil
local built       = false
local resizewait  = 0.05
local oldprt      = nil -- placeholder part
local cubechild   = nil

local function setupBrickListener()
    if cubechild then pcall(function() cubechild:Disconnect() end) end
    local bfolder = workspace:FindFirstChild("Bricks") and workspace.Bricks:FindFirstChild(player.Name)
    if bfolder then
        cubechild = bfolder.ChildAdded:Connect(function(child)
            childcube = child
            built = true
        end)
    end
end
setupBrickListener()
player.CharacterAdded:Connect(function() task.wait(1) setupBrickListener() end)

-- create a local placeholder part so server knows a block exists here
local function createPartRepl(pos, bsize, col, mat)
    if oldprt then pcall(function() oldprt:Destroy() end) end
    local p = Instance.new("Part")
    p.Anchored = true
    p.CanCollide = false
    p.CastShadow = false
    p.CanQuery = false
    p.Color = col or Color3.fromRGB(192,192,192)
    p.Transparency = 0.5
    p.Material = mat or Enum.Material.SmoothPlastic
    p.Size = bsize or Vector3.new(mult,mult,mult)
    p.CFrame = CFrame.new(pos)
    p.Parent = workspace
    oldprt = p
    return p
end

-- delete any block at exact position that's blocking a build spot
local function deleteBlockingBrick(pos)
    local deleteEvent = getEvent("Delete")
    if not deleteEvent then return end
    local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    for _, v in workspace:GetDescendants() do
        if v:IsA("BasePart") and v.Name == "Brick" and (v.Position - pos).Magnitude < 3 then
            pcall(function() deleteEvent:FireServer(v, hrp.Position) end)
            task.wait(0.05)
        end
    end
end

-- place one block and wait for ChildAdded confirmation
local function placeAndWait(buildEvent, pos, bsize)
    built = false
    childcube = nil
    createPartRepl(pos, bsize and Vector3.new(table.unpack(bsize)) or nil)
    local args = {workspace.Terrain, Enum.NormalId.Top, pos, bsize and "detailed" or "normal"}
    local c = 0
    repeat
        c = c + 1
        pcall(function() buildEvent:FireServer(table.unpack(args)) end)
        task.wait(0.08)
        -- if something is blocking, delete it and retry
        if c == 5 then
            deleteBlockingBrick(pos)
        end
    until (built and childcube and childcube.Parent) or stopped or skipblock or c > 50
    if oldprt then pcall(function() oldprt:Destroy() end) oldprt = nil end
    return childcube
end

-- paint block with color + material
local function paintBlock(paintEvent, block, color, matStr, origmat)
    if not paintEvent or not block or not block.Parent then return end
    local pos = block.Position + block.Size/2
    if color then
        local args = {block, Enum.NormalId.Top, pos, "both 🤝", color, matStr or "smooth", ""}
        local c = 0
        repeat
            c = c + 1
            pcall(function() paintEvent:FireServer(table.unpack(args)) end)
            task.wait(0.08)
        until not block or not block.Parent or block.Color == color or stopped or skipblock or c > 40
    end
end

-- resize block using Shape tool
local function resizeBlock(shapeEvent, block, targetSize)
    if not shapeEvent or not block or not block.Parent then return end
    local axes = {
        {Enum.NormalId.Right, "X"},
        {Enum.NormalId.Top,   "Y"},
        {Enum.NormalId.Back,  "Z"},
    }
    for _, axisData in ipairs(axes) do
        local face, axis = axisData[1], axisData[2]
        local target = targetSize[axis]
        local c = 0
        while block and block.Parent and block.Size[axis] ~= target and not stopped and not skipblock and c < target*6 do
            c = c + 1
            local pos2 = block.Position + block.Size/2
            local dir = block.Size[axis] > target and "decrease" or "increase"
            pcall(function() shapeEvent:FireServer(block, face, pos2, dir) end)
            task.wait(resizewait)
        end
    end
end

-- verify build and fill ALL missing blocks — never stops until done
local function verifyAndFill(buildEvent, paintEvent, shapeEvent, build)
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
            missing += 1
            skipblock = false
            buildEvent = getEvent("Build") or buildEvent
            paintEvent = getEvent("Paint") or paintEvent
            shapeEvent = getEvent("Shape") or shapeEvent
            local placed = placeAndWait(buildEvent, pos, v.s)
            if placed and paintEvent and v.c then
                paintBlock(paintEvent, placed, Color3.fromRGB(v.c[1],v.c[2],v.c[3]), v.m, v.o)
            end
            if placed and shapeEvent and v.s then
                resizeBlock(shapeEvent, placed, Vector3.new(v.s[1],v.s[2],v.s[3]))
            end
        end
    end
    return missing
end

-- ==================
-- UI
-- ==================

-- Circle button declared early
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
local titleBar = Instance.new("Frame", bg)
titleBar.Size = UDim2.new(1, 0, 0, 34)
titleBar.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
titleBar.BackgroundTransparency = 0
titleBar.BorderSizePixel = 0
titleBar.ZIndex = 6
Instance.new("UICorner", titleBar).CornerRadius = UDim.new(0, 10)
local tbFix = Instance.new("Frame", titleBar)
tbFix.Size = UDim2.new(1, 0, 0.5, 0)
tbFix.Position = UDim2.new(0, 0, 0.5, 0)
tbFix.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
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
    for n, c in pairs(tabContents) do c.Visible = false end
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
            TweenService:Create(bg2, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(70,190,100)}):Play()
            TweenService:Create(knob, TweenInfo.new(0.15), {Position = UDim2.new(0,21,0.5,-5), BackgroundColor3 = Color3.fromRGB(255,255,255)}):Play()
        else
            TweenService:Create(bg2, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(38,38,38)}):Play()
            TweenService:Create(knob, TweenInfo.new(0.15), {Position = UDim2.new(0,3,0.5,-5), BackgroundColor3 = Color3.fromRGB(110,110,110)}):Play()
        end
        if callback then callback(state) end
    end)

    local function setOff()
        state = false
        TweenService:Create(bg2, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(38,38,38)}):Play()
        TweenService:Create(knob, TweenInfo.new(0.15), {Position = UDim2.new(0,3,0.5,-5), BackgroundColor3 = Color3.fromRGB(110,110,110)}):Play()
    end

    return row, setOff
end

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
                    pcall(function() dt.e:FireServer(v, hrp.Position) end)
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
                local hx, hz = hrp.Position.X, hrp.Position.Z
                local hit = workspace:Raycast(Vector3.new(hx,200,hz), Vector3.new(0,-300,0), tparams)
                if hit then hgy = hit.Position.Y end
                pti = pti + 1
                local paint = paints[(pti%#paints)+1]
                paint.e:FireServer(
                    workspace.Terrain, Enum.NormalId.Top,
                    Vector3.new(hx, math.clamp(hrp.Position.Y, hgy-3.9, hgy), hz),
                    "color", Color3.fromHSV((tick()/5)%1,1,1), "", ""
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
local cStroke = Instance.new("UIStroke", colorRow)
cStroke.Color = Color3.fromRGB(40,40,40)
cStroke.Thickness = 1

local colorLbl = Instance.new("TextLabel", colorRow)
colorLbl.Size = UDim2.new(0.5, 0, 1, 0)
colorLbl.Position = UDim2.new(0, 10, 0, 0)
colorLbl.BackgroundTransparency = 1
colorLbl.Font = Enum.Font.Gotham
colorLbl.TextSize = 10
colorLbl.TextColor3 = Color3.fromRGB(150,150,150)
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
local sw2Stroke = Instance.new("UIStroke", swatch2)
sw2Stroke.Color = Color3.fromRGB(80,80,80)
sw2Stroke.Thickness = 1

local presets = {
    Color3.fromRGB(255,0,127), Color3.fromRGB(0,0,0),
    Color3.fromRGB(255,255,255), Color3.fromRGB(255,0,0),
    Color3.fromRGB(0,255,0), Color3.fromRGB(0,0,255),
    Color3.fromRGB(255,165,0), Color3.fromRGB(128,0,255),
    Color3.fromRGB(0,255,255), Color3.fromRGB(255,255,0),
}

local pickerPopup = Instance.new("Frame", screenGui)
pickerPopup.Size = UDim2.new(0, 220, 0, 60)
pickerPopup.BackgroundColor3 = Color3.fromRGB(18,18,18)
pickerPopup.BorderSizePixel = 0
pickerPopup.Visible = false
pickerPopup.ZIndex = 30
Instance.new("UICorner", pickerPopup).CornerRadius = UDim.new(0, 8)
local ppStroke = Instance.new("UIStroke", pickerPopup)
ppStroke.Color = Color3.fromRGB(60,60,60)
ppStroke.Thickness = 1

local ppGrid = Instance.new("Frame", pickerPopup)
ppGrid.Size = UDim2.new(1,-10,1,-10)
ppGrid.Position = UDim2.new(0,5,0,5)
ppGrid.BackgroundTransparency = 1
ppGrid.ZIndex = 31
local ppLayout = Instance.new("UIGridLayout", ppGrid)
ppLayout.CellSize = UDim2.new(0,18,0,18)
ppLayout.CellPadding = UDim2.new(0,3,0,3)
ppLayout.SortOrder = Enum.SortOrder.LayoutOrder

local activeSwatch = nil
for i, col in presets do
    local dot = Instance.new("TextButton", ppGrid)
    dot.Size = UDim2.new(0,18,0,18)
    dot.BackgroundColor3 = col
    dot.BorderSizePixel = 0
    dot.Text = ""
    dot.ZIndex = 32
    dot.LayoutOrder = i
    Instance.new("UICorner", dot).CornerRadius = UDim.new(0, 4)
    dot.MouseButton1Click:Connect(function()
        if activeSwatch == 1 then glitchColor1 = col swatch1.BackgroundColor3 = col
        else glitchColor2 = col swatch2.BackgroundColor3 = col end
        pickerPopup.Visible = false
    end)
end

local function showPicker(swatchNum, btn)
    activeSwatch = swatchNum
    local absPos = btn.AbsolutePosition
    pickerPopup.Position = UDim2.new(0, absPos.X-180, 0, absPos.Y-70)
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
                if v:IsA("BasePart") then table.insert(bricks, v) end
            end
            local colorIndex = (math.floor(tick()*10)%2)+1
            local col = colorIndex == 1 and glitchColor1 or glitchColor2
            local pt = paints[1]
            for _, v in bricks do
                if not glitchRunning then break end
                if v and v.Parent then
                    pcall(function()
                        pt.e:FireServer(v, Enum.NormalId.Top, v.Position, "both 🤝", col, "neon", "")
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

local selectedBuild = nil
local selectedBuildName = nil
local selectedSaveBtn = nil
local autoBuildRunning = false
local autoBuildSetOff = nil

local buildStatus = makeLabel(buildTab, "", 0)
buildStatus.TextColor3 = Color3.fromRGB(80,200,120)
buildStatus.LayoutOrder = 0

local function setStatus(msg, isErr)
    buildStatus.Text = msg
    buildStatus.TextColor3 = isErr and Color3.fromRGB(220,80,80) or Color3.fromRGB(80,200,120)
end

-- Build name input
makeLabel(buildTab, "build name", 1)
local nameInput = Instance.new("TextBox", buildTab)
nameInput.Size = UDim2.new(1, 0, 0, 28)
nameInput.BackgroundColor3 = Color3.fromRGB(22,22,22)
nameInput.BorderSizePixel = 0
nameInput.Font = Enum.Font.Code
nameInput.TextSize = 11
nameInput.TextColor3 = Color3.fromRGB(200,200,200)
nameInput.PlaceholderText = "enter build name..."
nameInput.PlaceholderColor3 = Color3.fromRGB(65,65,65)
nameInput.Text = "MyBuild"
nameInput.LayoutOrder = 2
nameInput.ClearTextOnFocus = false
nameInput.ZIndex = 7
Instance.new("UICorner", nameInput).CornerRadius = UDim.new(0, 7)
local nPad = Instance.new("UIPadding", nameInput)
nPad.PaddingLeft = UDim.new(0, 8)

makeDivider(buildTab, 3)

-- Save my build
makeBtn(buildTab, "Save My Build", 4, function()
    local name = nameInput.Text
    if name == "" then setStatus("enter a name first", true) return end
    local playerFolder = workspace:FindFirstChild("Bricks") and workspace.Bricks:FindFirstChild(player.Name)
    if not playerFolder then setStatus("no blocks found", true) return end
    local builddata = {}
    for _, v in playerFolder:GetChildren() do
        local bd = saveBlock(v)
        if bd then table.insert(builddata, bd) end
    end
    if #builddata == 0 then setStatus("no blocks to save", true) return end
    pcall(function() writefile(BUILDS_FOLDER.."/"..name..".json", jsonEncode(builddata)) end)
    setStatus("saved "..#builddata.." blocks as '"..name.."'")
    refreshSavesList()
end)

-- Save server builds
makeBtn(buildTab, "Save Server Builds", 5, function()
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
    pcall(function() writefile(BUILDS_FOLDER.."/"..name..".json", jsonEncode(builddata)) end)
    setStatus("saved "..#builddata.." blocks as '"..name.."'")
    refreshSavesList()
end)

makeDivider(buildTab, 6)

-- Saves list
makeLabel(buildTab, "saved builds", 7)

local savesFrame = Instance.new("Frame", buildTab)
savesFrame.Size = UDim2.new(1, 0, 0, 80)
savesFrame.BackgroundColor3 = Color3.fromRGB(18,18,18)
savesFrame.BorderSizePixel = 0
savesFrame.LayoutOrder = 8
savesFrame.ZIndex = 7
Instance.new("UICorner", savesFrame).CornerRadius = UDim.new(0, 7)

local savesScroll = Instance.new("ScrollingFrame", savesFrame)
savesScroll.Size = UDim2.new(1,0,1,0)
savesScroll.BackgroundTransparency = 1
savesScroll.BorderSizePixel = 0
savesScroll.ScrollBarThickness = 2
savesScroll.ScrollBarImageColor3 = Color3.fromRGB(60,60,60)
savesScroll.ZIndex = 8
local savesLayout = Instance.new("UIListLayout", savesScroll)
savesLayout.Padding = UDim.new(0, 2)
local savesPad = Instance.new("UIPadding", savesScroll)
savesPad.PaddingLeft = UDim.new(0, 4)
savesPad.PaddingRight = UDim.new(0, 4)
savesPad.PaddingTop = UDim.new(0, 4)
savesLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    savesScroll.CanvasSize = UDim2.new(0,0,0,savesLayout.AbsoluteContentSize.Y+8)
end)

function refreshSavesList()
    for _, c in savesScroll:GetChildren() do if c:IsA("TextButton") or c:IsA("TextLabel") then c:Destroy() end end
    local saves = listSaves()
    if #saves == 0 then
        local empty = Instance.new("TextLabel", savesScroll)
        empty.Size = UDim2.new(1,0,0,20)
        empty.BackgroundTransparency = 1
        empty.Font = Enum.Font.Gotham
        empty.TextSize = 10
        empty.TextColor3 = Color3.fromRGB(70,70,70)
        empty.Text = "no saves yet"
        empty.ZIndex = 9
        return
    end
    for _, name in saves do
        local btn = Instance.new("TextButton", savesScroll)
        btn.Size = UDim2.new(1,0,0,22)
        btn.BackgroundColor3 = Color3.fromRGB(25,25,25)
        btn.BorderSizePixel = 0
        btn.Font = Enum.Font.Gotham
        btn.TextSize = 11
        btn.TextColor3 = Color3.fromRGB(170,170,170)
        btn.Text = name
        btn.ZIndex = 9
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 5)
        btn.MouseButton1Click:Connect(function()
            if selectedSaveBtn then
                selectedSaveBtn.BackgroundColor3 = Color3.fromRGB(25,25,25)
                selectedSaveBtn.TextColor3 = Color3.fromRGB(170,170,170)
            end
            selectedSaveBtn = btn
            btn.BackgroundColor3 = Color3.fromRGB(45,45,45)
            btn.TextColor3 = Color3.fromRGB(220,220,220)
            selectedBuildName = name
            local ok, data = pcall(function()
                return jsonDecode(readfile(BUILDS_FOLDER.."/"..name..".json"))
            end)
            if ok then
                selectedBuild = data
                setStatus("selected: "..name.." ("..#data.." blocks)")
            else
                setStatus("failed to load "..name, true)
            end
        end)
    end
end
refreshSavesList()

makeDivider(buildTab, 9)

-- Cross-server load
makeBtn(buildTab, "Load Last Build (Cross-Server)", 91, function()
    local ok, data = pcall(function()
        return jsonDecode(readfile(BUILDS_FOLDER.."/_lastbuild.json"))
    end)
    if not ok or not data then setStatus("no cross-server build found", true) return end
    selectedBuild = data.data
    selectedBuildName = data.name or "cross-server"
    setStatus("loaded: "..(data.name or "cross-server").." ("..#selectedBuild.." blocks)")
end)

makeDivider(buildTab, 10)

-- ==================
-- PLAYER BUILDS LIST
-- ==================
makeLabel(buildTab, "player builds (click to highlight)", 11)

local plrBuildsFrame = Instance.new("Frame", buildTab)
plrBuildsFrame.Size = UDim2.new(1, 0, 0, 80)
plrBuildsFrame.BackgroundColor3 = Color3.fromRGB(18,18,18)
plrBuildsFrame.BorderSizePixel = 0
plrBuildsFrame.LayoutOrder = 12
plrBuildsFrame.ZIndex = 7
Instance.new("UICorner", plrBuildsFrame).CornerRadius = UDim.new(0, 7)

local plrScroll = Instance.new("ScrollingFrame", plrBuildsFrame)
plrScroll.Size = UDim2.new(1,0,1,0)
plrScroll.BackgroundTransparency = 1
plrScroll.BorderSizePixel = 0
plrScroll.ScrollBarThickness = 2
plrScroll.ScrollBarImageColor3 = Color3.fromRGB(60,60,60)
plrScroll.ZIndex = 8
local plrLayout = Instance.new("UIListLayout", plrScroll)
plrLayout.Padding = UDim.new(0, 2)
local plrPad = Instance.new("UIPadding", plrScroll)
plrPad.PaddingLeft = UDim.new(0, 4)
plrPad.PaddingRight = UDim.new(0, 4)
plrPad.PaddingTop = UDim.new(0, 4)
plrLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    plrScroll.CanvasSize = UDim2.new(0,0,0,plrLayout.AbsoluteContentSize.Y+8)
end)

local plrBtnMap = {}
local selectedPlrBtn = nil

local function addPlayerBuildBtn(folder)
    if plrBtnMap[folder.Name] then return end
    local btn = Instance.new("TextButton", plrScroll)
    btn.Size = UDim2.new(1,0,0,22)
    btn.BackgroundColor3 = Color3.fromRGB(25,25,25)
    btn.BorderSizePixel = 0
    btn.Font = Enum.Font.Gotham
    btn.TextSize = 11
    btn.TextColor3 = Color3.fromRGB(170,170,170)
    btn.Text = folder.Name
    btn.ZIndex = 9
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 5)
    plrBtnMap[folder.Name] = btn

    btn.MouseButton1Click:Connect(function()
        if selectedPlrBtn then
            selectedPlrBtn.BackgroundColor3 = Color3.fromRGB(25,25,25)
            selectedPlrBtn.TextColor3 = Color3.fromRGB(170,170,170)
        end
        selectedPlrBtn = btn
        btn.BackgroundColor3 = Color3.fromRGB(45,45,45)
        btn.TextColor3 = Color3.fromRGB(220,220,220)
        -- highlight the folder (model)
        buildHighlight.Adornee = folder
        setStatus("highlighting "..folder.Name.."'s build")
    end)

    -- remove button if folder is removed
    folder.AncestryChanged:Connect(function()
        if not folder.Parent then
            btn:Destroy()
            plrBtnMap[folder.Name] = nil
            if buildHighlight.Adornee == folder then
                buildHighlight.Adornee = nil
            end
        end
    end)

    -- also add ChildAdded to detect if they place their first block
    folder.ChildAdded:Connect(function()
        btn.TextColor3 = Color3.fromRGB(170,170,170)
    end)
end

-- populate existing player folders
local bricksFolder = workspace:FindFirstChild("Bricks")
if bricksFolder then
    for _, v in bricksFolder:GetChildren() do
        if v:IsA("Model") or v:IsA("Folder") then
            addPlayerBuildBtn(v)
        end
    end
    bricksFolder.ChildAdded:Connect(function(child)
        if child:IsA("Model") or child:IsA("Folder") then
            addPlayerBuildBtn(child)
        end
    end)
end

-- Save selected player's build
makeBtn(buildTab, "Save Selected Player Build", 13, function()
    if not selectedPlrBtn then setStatus("select a player first", true) return end
    local plrName = selectedPlrBtn.Text
    local folder = bricksFolder and bricksFolder:FindFirstChild(plrName)
    if not folder then setStatus("folder not found", true) return end
    local builddata = {}
    for _, v in folder:GetChildren() do
        if v:IsA("BasePart") then
            local bd = saveBlock(v)
            if bd then table.insert(builddata, bd) end
        end
    end
    if #builddata == 0 then setStatus("no blocks", true) return end
    local saveName = plrName.."_build"
    pcall(function() writefile(BUILDS_FOLDER.."/"..saveName..".json", jsonEncode(builddata)) end)
    setStatus("saved "..#builddata.." blocks as '"..saveName.."'")
    refreshSavesList()
end)

makeDivider(buildTab, 14)

-- Auto Build
local _, autoBuildSetOffFn = makeToggle(buildTab, "Auto Build (loads selected)", 15, function(state)
    autoBuildRunning = state
    stopped = not state
    skipblock = false
    if not state then return end
    if not selectedBuild then setStatus("select a save first", true) if autoBuildSetOff then autoBuildSetOff() end return end
    task.spawn(function()
        local build = selectedBuild
        local buildName = selectedBuildName

        -- cross-server: write last build
        pcall(function()
            writefile(BUILDS_FOLDER.."/_lastbuild.json", jsonEncode({name=buildName, data=build}))
        end)

        local buildEvent = getEvent("Build")
        local paintEvent = getEvent("Paint")
        local shapeEvent = getEvent("Shape")

        if not buildEvent then
            setStatus("no Build tool found", true)
            autoBuildRunning = false
            if autoBuildSetOff then autoBuildSetOff() end
            return
        end

        local total = #build
        setStatus("building "..total.." blocks...")

        -- Pass 1: place all blocks — never give up on a block
        for i, v in ipairs(build) do
            if not autoBuildRunning or stopped then break end
            skipblock = false

            buildEvent = getEvent("Build") or buildEvent
            paintEvent = getEvent("Paint") or paintEvent
            shapeEvent = getEvent("Shape") or shapeEvent

            local pos = Vector3.new(v.p[1], v.p[2], v.p[3])

            -- delete anything blocking this spot first
            deleteBlockingBrick(pos)
            task.wait(0.05)

            local placed = placeAndWait(buildEvent, pos, v.s)

            if placed and paintEvent and v.c then
                paintBlock(paintEvent, placed, Color3.fromRGB(v.c[1],v.c[2],v.c[3]), v.m, v.o)
            end

            if placed and shapeEvent and v.s then
                resizeBlock(shapeEvent, placed, Vector3.new(v.s[1],v.s[2],v.s[3]))
            end

            setStatus("building "..i.."/"..total)
        end

        if stopped then
            setStatus("build stopped")
            autoBuildRunning = false
            if autoBuildSetOff then autoBuildSetOff() end
            return
        end

        -- Pass 2: verify and fill ALL missing — loops until 0 missing
        local attempts = 0
        repeat
            attempts += 1
            setStatus("verifying... (pass "..attempts..")")
            task.wait(0.5)
            buildEvent = getEvent("Build") or buildEvent
            paintEvent = getEvent("Paint") or paintEvent
            shapeEvent = getEvent("Shape") or shapeEvent
            local missing = verifyAndFill(buildEvent, paintEvent, shapeEvent, build)
            if missing == 0 then break end
            setStatus("fixed "..missing.." blocks, re-checking...")
        until attempts >= 5 or stopped

        if not stopped then
            setStatus("build complete! "..total.." blocks")
        else
            setStatus("build stopped")
        end
        autoBuildRunning = false
        if autoBuildSetOff then autoBuildSetOff() end
    end)
end)
autoBuildSetOff = autoBuildSetOffFn

-- Stop build
makeBtn(buildTab, "Stop Build", 16, function()
    autoBuildRunning = false
    stopped = true
    skipblock = true
    setStatus("build stopped")
    if autoBuildSetOff then autoBuildSetOff() end
end)

makeDivider(buildTab, 17)

-- Delete save
makeBtn(buildTab, "Delete Selected Save", 18, function()
    if not selectedBuildName then setStatus("select a save first", true) return end
    pcall(function() delfile(BUILDS_FOLDER.."/"..selectedBuildName..".json") end)
    setStatus("deleted: "..selectedBuildName)
    selectedBuild = nil
    selectedBuildName = nil
    selectedSaveBtn = nil
    refreshSavesList()
end)

makeDivider(buildTab, 19)

-- Get Decal Tool
makeLabel(buildTab, "decal tool", 20)
makeBtn(buildTab, "Get Decal Tool", 21, function()
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
    handle.Color = Color3.fromRGB(0,255,255)
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
    task.delay(0.2, function() bg.Visible = false end)
end

minBtn.MouseButton1Click:Connect(closeUI)
closeBtn.MouseButton1Click:Connect(function()
    TweenService:Create(blur, TweenInfo.new(0.2), {Size = 0}):Play()
    task.delay(0.2, function() screenGui:Destroy() blur:Destroy() end)
end)

UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if input.KeyCode == Enum.KeyCode.RightShift then
        if isOpen then closeUI() else openUI() end
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
        bg.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset+delta.X, startPos.Y.Scale, startPos.Y.Offset+delta.Y)
    end
end)
UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = false
    end
end)

-- Circle button drag
local btnDragging, btnDragStart, btnStartPos, btnMoved = false, nil, nil, false
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
        openBtn.Position = UDim2.new(btnStartPos.X.Scale, btnStartPos.X.Offset+delta.X, btnStartPos.Y.Scale, btnStartPos.Y.Offset+delta.Y)
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

openUI()
print("ManesHub loaded. Tap M or RightShift to toggle.")
