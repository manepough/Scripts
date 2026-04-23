-- PlacementSystem.lua  (LocalScript)
-- Place in: StarterPlayerScripts
--
-- ═══════════════════════════════════════════════════════════════
--  SETUP REQUIREMENTS
--  ┌─ ReplicatedStorage
--  │   ├─ GiveUnit      RemoteEvent  (Server→Client) : string unitName
--  │   ├─ PlaceUnit     RemoteEvent  (Client→Server) : number plotIndex, string unitName
--  │   ├─ SellUnit      RemoteEvent  (Client→Server) : number plotIndex
--  │   ├─ PlotUpdated   RemoteEvent  (Server→Client) : number plotIndex, string unitName
--  │   └─ PlotSold      RemoteEvent  (Server→Client) : number plotIndex
--  │
--  └─ Workspace
--      └─ Plots (Folder)
--          ├─ Plot1  (Part or Model – the physical plot in the world)
--          ├─ Plot2
--          └─ ... Plot8
--
--  Each Plot part should be named "Plot1"…"Plot8".
--  The unit will be placed at the Plot's CFrame (top surface center).
-- ═══════════════════════════════════════════════════════════════

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")
local UserInputService  = game:GetService("UserInputService")
local TweenService      = game:GetService("TweenService")

local player    = Players.LocalPlayer
local mouse     = player:GetMouse()
local character = player.Character or player.CharacterAdded:Wait()
local camera    = workspace.CurrentCamera

-- ── Remotes (WaitForChild so it doesn't error if they load slowly) ──
local RS         = ReplicatedStorage
local giveUnit   = RS:WaitForChild("GiveUnit")
local placeUnit  = RS:WaitForChild("PlaceUnit")
local sellUnit   = RS:WaitForChild("SellUnit")
local plotUpdated = RS:WaitForChild("PlotUpdated")
local plotSold   = RS:WaitForChild("PlotSold")

-- ── Plot folder in Workspace ────────────────────────────────────────
local plotFolder = workspace:WaitForChild("Plots")

-- ═══════════════════════════════════════════════════════════════
--  STATE
-- ═══════════════════════════════════════════════════════════════
local heldUnitName  = nil   -- name of unit currently being held
local hoveredPlot   = nil   -- Plot part the mouse is over right now
local placedUnits   = {}    -- placedUnits[plotIndex] = unitName string or nil
local isPlacing     = false -- are we in grab/place mode?

-- ═══════════════════════════════════════════════════════════════
--  GHOST MODEL  (transparent preview that follows the mouse)
-- ═══════════════════════════════════════════════════════════════
local ghost = nil  -- the current ghost Part (recreated per unit)

local function destroyGhost()
    if ghost then ghost:Destroy(); ghost = nil end
end

local function createGhost(unitName)
    destroyGhost()

    -- Simple box ghost — swap this out for your actual unit model if you have one
    local part = Instance.new("Part")
    part.Name         = "Ghost_" .. unitName
    part.Size         = Vector3.new(3, 3, 3)
    part.Anchored     = true
    part.CanCollide   = false
    part.CastShadow   = false
    part.Material     = Enum.Material.Neon
    part.Color        = Color3.fromRGB(80, 220, 80)
    part.Transparency = 0.45
    part.Parent       = workspace

    -- Label above ghost
    local billboard = Instance.new("BillboardGui")
    billboard.Size        = UDim2.new(0, 120, 0, 30)
    billboard.StudsOffset = Vector3.new(0, 3, 0)
    billboard.AlwaysOnTop = true
    billboard.Parent      = part

    local lbl = Instance.new("TextLabel")
    lbl.Size                 = UDim2.new(1,0,1,0)
    lbl.BackgroundTransparency = 1
    lbl.Text                 = unitName
    lbl.TextColor3           = Color3.fromRGB(80,255,80)
    lbl.TextSize             = 14
    lbl.Font                 = Enum.Font.GothamBold
    lbl.TextStrokeTransparency = 0.4
    lbl.Parent               = billboard

    ghost = part
end

-- ═══════════════════════════════════════════════════════════════
--  PLOT HIGHLIGHT  (SelectionBox on hovered plot)
-- ═══════════════════════════════════════════════════════════════
local selectionBox = Instance.new("SelectionBox")
selectionBox.LineThickness  = 0.08
selectionBox.Color3         = Color3.fromRGB(80, 230, 80)
selectionBox.SurfaceColor3  = Color3.fromRGB(80, 230, 80)
selectionBox.SurfaceTransparency = 0.7
selectionBox.Adornee        = nil
selectionBox.Parent         = workspace

local selectionBoxSell = Instance.new("SelectionBox")
selectionBoxSell.LineThickness  = 0.08
selectionBoxSell.Color3         = Color3.fromRGB(230, 60, 60)
selectionBoxSell.SurfaceColor3  = Color3.fromRGB(230, 60, 60)
selectionBoxSell.SurfaceTransparency = 0.7
selectionBoxSell.Adornee        = nil
selectionBoxSell.Parent         = workspace

-- ═══════════════════════════════════════════════════════════════
--  GUI  – small bottom panel showing plot status + SELL button
-- ═══════════════════════════════════════════════════════════════
local screenGui = Instance.new("ScreenGui")
screenGui.Name           = "PlotUI"
screenGui.ResetOnSpawn   = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.IgnoreGuiInset = true
screenGui.Parent         = player.PlayerGui

-- HOLDING BANNER
local holdBar = Instance.new("Frame")
holdBar.Name             = "HoldBar"
holdBar.Size             = UDim2.new(0, 300, 0, 38)
holdBar.Position         = UDim2.new(0.5,-150, 0, 14)
holdBar.BackgroundColor3 = Color3.fromRGB(16,52,16)
holdBar.BorderSizePixel  = 0
holdBar.Visible          = false
holdBar.Parent           = screenGui
do
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0,10); c.Parent = holdBar
    local s = Instance.new("UIStroke"); s.Color = Color3.fromRGB(60,210,60); s.Thickness = 2; s.Parent = holdBar
end
local holdLbl = Instance.new("TextLabel")
holdLbl.Size                 = UDim2.new(1,0,1,0)
holdLbl.BackgroundTransparency = 1
holdLbl.Text                 = ""
holdLbl.TextColor3           = Color3.fromRGB(80,255,80)
holdLbl.TextSize             = 14
holdLbl.Font                 = Enum.Font.GothamBold
holdLbl.Parent               = holdBar

-- ESC hint label under hold bar
local escLbl = Instance.new("TextLabel")
escLbl.Size                 = UDim2.new(0,300,0,18)
escLbl.Position             = UDim2.new(0.5,-150,0,56)
escLbl.BackgroundTransparency = 1
escLbl.Text                 = "[ESC / Right-click to cancel]"
escLbl.TextColor3           = Color3.fromRGB(180,180,180)
escLbl.TextSize             = 11
escLbl.Font                 = Enum.Font.Gotham
escLbl.Visible              = false
escLbl.Parent               = screenGui

-- BOTTOM PANEL (8 plot slots)
local SLOT_W, SLOT_H, SLOT_GAP, PAD = 58, 150, 4, 8
local totalW  = PAD*2 + SLOT_W*8 + SLOT_GAP*7
local panelH  = SLOT_H + 28

local panel = Instance.new("Frame")
panel.Name             = "Panel"
panel.Size             = UDim2.new(0, totalW, 0, panelH)
panel.Position         = UDim2.new(0.5, -totalW/2, 1, -(panelH+8))
panel.BackgroundColor3 = Color3.fromRGB(14,16,26)
panel.BorderSizePixel  = 0
panel.Parent           = screenGui
do
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0,14); c.Parent = panel
    local s = Instance.new("UIStroke"); s.Color = Color3.fromRGB(48,68,130); s.Thickness = 2; s.Parent = panel
end

local panelHdr = Instance.new("TextLabel")
panelHdr.Size                 = UDim2.new(1,0,0,20)
panelHdr.Position             = UDim2.new(0,0,0,4)
panelHdr.BackgroundTransparency = 1
panelHdr.Text                 = "── PLOTS ──"
panelHdr.TextColor3           = Color3.fromRGB(130,158,245)
panelHdr.TextSize             = 10
panelHdr.Font                 = Enum.Font.GothamBold
panelHdr.Parent               = panel

-- SELL button
local sellMode = false
local sellBtn = Instance.new("TextButton")
sellBtn.Size             = UDim2.new(0,56,0,50)
sellBtn.Position         = UDim2.new(1,8,0.5,-25)
sellBtn.BackgroundColor3 = Color3.fromRGB(148,30,30)
sellBtn.Text             = "SELL"
sellBtn.TextColor3       = Color3.fromRGB(255,255,255)
sellBtn.TextSize         = 12
sellBtn.Font             = Enum.Font.GothamBold
sellBtn.BorderSizePixel  = 0
sellBtn.AutoButtonColor  = false
sellBtn.Parent           = panel
do
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0,10); c.Parent = sellBtn
    local s = Instance.new("UIStroke"); s.Name="Stroke"; s.Color=Color3.fromRGB(255,70,70); s.Thickness=2; s.Parent=sellBtn
end

-- Build 8 plot slots
local slotFrames = {}
local slotUnitPills = {}
local slotUnitLbls  = {}
local slotNumLbls   = {}

local function refreshSlot(i)
    local f   = slotFrames[i];   if not f then return end
    local pill = slotUnitPills[i]
    local lbl  = slotUnitLbls[i]
    local num  = slotNumLbls[i]
    local hasUnit = placedUnits[i] ~= nil
    local stk = f:FindFirstChild("Stroke")

    if sellMode and hasUnit then
        f.BackgroundColor3 = Color3.fromRGB(55,14,14)
        if stk then stk.Color=Color3.fromRGB(230,55,55); stk.Thickness=2 end
    elseif hasUnit then
        f.BackgroundColor3 = Color3.fromRGB(16,40,20)
        if stk then stk.Color=Color3.fromRGB(55,200,55); stk.Thickness=2 end
    else
        f.BackgroundColor3 = Color3.fromRGB(26,28,44)
        if stk then stk.Color=Color3.fromRGB(40,44,72); stk.Thickness=1 end
    end

    pill.Visible = hasUnit
    lbl.Text     = placedUnits[i] or ""
    num.TextColor3 = hasUnit and Color3.fromRGB(95,105,150) or Color3.fromRGB(150,162,212)
end

local function refreshAll()
    for i=1,8 do refreshSlot(i) end
end

for i = 1, 8 do
    local xPos = PAD + (i-1)*(SLOT_W+SLOT_GAP)

    local f = Instance.new("Frame")
    f.Name             = "Slot"..i
    f.Size             = UDim2.new(0,SLOT_W,0,SLOT_H)
    f.Position         = UDim2.new(0,xPos,0,24)
    f.BackgroundColor3 = Color3.fromRGB(26,28,44)
    f.BorderSizePixel  = 0
    f.Parent           = panel
    do
        local c = Instance.new("UICorner"); c.CornerRadius=UDim.new(0,8); c.Parent=f
        local s = Instance.new("UIStroke"); s.Name="Stroke"; s.Color=Color3.fromRGB(40,44,72); s.Thickness=1; s.Parent=f
    end

    -- number pill (top)
    local numPill = Instance.new("Frame")
    numPill.Size=UDim2.new(1,-8,0,20); numPill.Position=UDim2.new(0,4,0,4)
    numPill.BackgroundColor3=Color3.fromRGB(20,22,36); numPill.BorderSizePixel=0; numPill.Parent=f
    do local c=Instance.new("UICorner"); c.CornerRadius=UDim.new(0,5); c.Parent=numPill end

    local numLbl = Instance.new("TextLabel")
    numLbl.Size=UDim2.new(1,0,1,0); numLbl.BackgroundTransparency=1
    numLbl.Text=tostring(i); numLbl.TextColor3=Color3.fromRGB(150,162,212)
    numLbl.TextSize=11; numLbl.Font=Enum.Font.GothamBold; numLbl.Parent=numPill

    -- divider
    local div = Instance.new("Frame")
    div.Size=UDim2.new(0,1,0,SLOT_H-54); div.Position=UDim2.new(0.5,0,0,28)
    div.BackgroundColor3=Color3.fromRGB(36,40,62); div.BorderSizePixel=0; div.Parent=f

    -- unit pill (bottom)
    local pill = Instance.new("Frame")
    pill.Size=UDim2.new(1,-8,0,24); pill.Position=UDim2.new(0,4,1,-28)
    pill.BackgroundColor3=Color3.fromRGB(18,22,36); pill.BorderSizePixel=0
    pill.Visible=false; pill.Parent=f
    do local c=Instance.new("UICorner"); c.CornerRadius=UDim.new(0,5); c.Parent=pill end

    local unitLbl = Instance.new("TextLabel")
    unitLbl.Size=UDim2.new(1,-4,1,0); unitLbl.Position=UDim2.new(0,2,0,0)
    unitLbl.BackgroundTransparency=1; unitLbl.Text=""
    unitLbl.TextColor3=Color3.fromRGB(65,220,65); unitLbl.TextSize=8
    unitLbl.Font=Enum.Font.GothamBold; unitLbl.TextWrapped=true
    unitLbl.TextScaled=true; unitLbl.Parent=pill

    slotFrames[i]    = f
    slotUnitPills[i] = pill
    slotUnitLbls[i]  = unitLbl
    slotNumLbls[i]   = numLbl
end

-- ═══════════════════════════════════════════════════════════════
--  SELL BUTTON
-- ═══════════════════════════════════════════════════════════════
local sellStroke = sellBtn:FindFirstChild("Stroke")

local function setSellMode(on)
    sellMode = on
    if on then
        sellBtn.BackgroundColor3 = Color3.fromRGB(210,42,42)
        sellStroke.Color         = Color3.fromRGB(255,130,130)
        sellBtn.Text             = "SELL\n[ON]"
        selectionBoxSell.Adornee = nil
    else
        sellBtn.BackgroundColor3 = Color3.fromRGB(148,30,30)
        sellStroke.Color         = Color3.fromRGB(255,70,70)
        sellBtn.Text             = "SELL"
        selectionBoxSell.Adornee = nil
    end
    refreshAll()
end

sellBtn.MouseButton1Click:Connect(function()
    setSellMode(not sellMode)
end)

-- ═══════════════════════════════════════════════════════════════
--  PLACEMENT HELPERS
-- ═══════════════════════════════════════════════════════════════
local function getPlotIndex(plotPart)
    -- expects plot named "Plot1"…"Plot8"
    if not plotPart then return nil end
    local n = tonumber(plotPart.Name:match("%d+"))
    return (n and n >= 1 and n <= 8) and n or nil
end

local function getPlotTopCFrame(plotPart)
    -- returns a CFrame sitting on top of the plot part
    local size = plotPart.Size
    return plotPart.CFrame * CFrame.new(0, size.Y/2, 0)
end

local function enterPlacingMode(unitName)
    isPlacing   = true
    heldUnitName = unitName
    sellMode    = false
    setSellMode(false)

    holdLbl.Text    = "⚑ HOLDING: " .. unitName .. "  |  Click a plot to place"
    holdBar.Visible = true
    escLbl.Visible  = true
    createGhost(unitName)

    -- Make the cursor a crosshair
    mouse.Icon = "rbxasset://textures/Cursors/CrosshairCursor.png"
end

local function cancelPlacing()
    isPlacing    = false
    heldUnitName = nil
    hoveredPlot  = nil

    holdBar.Visible         = false
    escLbl.Visible          = false
    selectionBox.Adornee    = nil
    mouse.Icon              = ""
    destroyGhost()
end

local function confirmPlace(plotPart)
    local idx = getPlotIndex(plotPart)
    if not idx then return end
    if placedUnits[idx] then
        print("[Placement] Plot", idx, "already occupied!")
        return
    end

    -- Snap ghost to plot with a quick tween before confirming
    if ghost then
        local targetCF = getPlotTopCFrame(plotPart)
        TweenService:Create(ghost, TweenInfo.new(0.1, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
            { CFrame = targetCF }):Play()
        task.wait(0.08)
    end

    -- Fire server
    placeUnit:FireServer(idx, heldUnitName)
    print("[Placement] Placed", heldUnitName, "on Plot", idx)

    -- Optimistic update (server will confirm via PlotUpdated)
    placedUnits[idx] = heldUnitName
    refreshAll()
    cancelPlacing()
end

-- ═══════════════════════════════════════════════════════════════
--  MOUSE / RENDER LOOP  — move ghost + highlight hovered plot
-- ═══════════════════════════════════════════════════════════════
RunService.RenderStepped:Connect(function()
    if not isPlacing then
        selectionBox.Adornee = nil
        return
    end

    -- Raycast from mouse to find plot
    local unitRay = camera:ScreenPointToRay(mouse.X, mouse.Y)
    local params  = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Include
    -- include the Plots folder parts
    params.FilterDescendantsInstances = { plotFolder }

    local result = workspace:Raycast(unitRay.Origin, unitRay.Direction * 1000, params)

    local hitPlot = nil
    if result and result.Instance then
        -- walk up to find Plot part
        local inst = result.Instance
        while inst and inst ~= plotFolder do
            if inst.Parent == plotFolder then hitPlot = inst; break end
            inst = inst.Parent
        end
    end

    hoveredPlot = hitPlot

    if hitPlot then
        local idx = getPlotIndex(hitPlot)
        local occupied = idx and placedUnits[idx]

        selectionBox.Color3    = occupied and Color3.fromRGB(230,80,80) or Color3.fromRGB(80,230,80)
        selectionBox.SurfaceColor3 = selectionBox.Color3
        selectionBox.Adornee   = hitPlot

        -- Move ghost to top of plot
        if ghost then
            local targetCF = getPlotTopCFrame(hitPlot)
            ghost.CFrame   = targetCF
            ghost.Color    = occupied and Color3.fromRGB(220,80,80) or Color3.fromRGB(80,220,80)
        end
    else
        selectionBox.Adornee = nil

        -- Ghost floats in front of player when not hovering a plot
        if ghost and character and character:FindFirstChild("HumanoidRootPart") then
            local hrp = character.HumanoidRootPart
            ghost.CFrame = hrp.CFrame * CFrame.new(0, 2, -6)
            ghost.Color  = Color3.fromRGB(80,220,80)
        end
    end
end)

-- ═══════════════════════════════════════════════════════════════
--  SELL MODE HOVER  (separate loop for sell selection box)
-- ═══════════════════════════════════════════════════════════════
RunService.RenderStepped:Connect(function()
    if not sellMode then
        selectionBoxSell.Adornee = nil
        return
    end

    local unitRay = camera:ScreenPointToRay(mouse.X, mouse.Y)
    local params  = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Include
    params.FilterDescendantsInstances = { plotFolder }

    local result = workspace:Raycast(unitRay.Origin, unitRay.Direction * 1000, params)
    local hitPlot = nil
    if result and result.Instance then
        local inst = result.Instance
        while inst and inst ~= plotFolder do
            if inst.Parent == plotFolder then hitPlot = inst; break end
            inst = inst.Parent
        end
    end

    if hitPlot then
        local idx = getPlotIndex(hitPlot)
        if idx and placedUnits[idx] then
            selectionBoxSell.Adornee = hitPlot
        else
            selectionBoxSell.Adornee = nil
        end
    else
        selectionBoxSell.Adornee = nil
    end
end)

-- ═══════════════════════════════════════════════════════════════
--  INPUT — left click to place / sell,  ESC / right-click cancel
-- ═══════════════════════════════════════════════════════════════
UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end  -- ignore if over GUI

    -- Cancel placement
    if input.KeyCode == Enum.KeyCode.Escape then
        if isPlacing then cancelPlacing() end
        if sellMode   then setSellMode(false) end
        return
    end

    if input.UserInputType == Enum.UserInputType.MouseButton2 then
        if isPlacing then cancelPlacing() end
        return
    end

    -- Left click
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        if isPlacing then
            if hoveredPlot then
                confirmPlace(hoveredPlot)
            end

        elseif sellMode then
            -- sell: raycast to find plot
            local unitRay = camera:ScreenPointToRay(mouse.X, mouse.Y)
            local params  = RaycastParams.new()
            params.FilterType = Enum.RaycastFilterType.Include
            params.FilterDescendantsInstances = { plotFolder }
            local result = workspace:Raycast(unitRay.Origin, unitRay.Direction * 1000, params)

            if result and result.Instance then
                local inst = result.Instance
                local hitPlot = nil
                while inst and inst ~= plotFolder do
                    if inst.Parent == plotFolder then hitPlot = inst; break end
                    inst = inst.Parent
                end
                if hitPlot then
                    local idx = getPlotIndex(hitPlot)
                    if idx and placedUnits[idx] then
                        sellUnit:FireServer(idx)
                        print("[Sell] Sold", placedUnits[idx], "from Plot", idx)
                        placedUnits[idx] = nil
                        setSellMode(false)
                        refreshAll()
                    end
                end
            end
        end
    end
end)

-- ═══════════════════════════════════════════════════════════════
--  SERVER → CLIENT  EVENTS
-- ═══════════════════════════════════════════════════════════════

-- Shop bought a unit → enter grab/place mode
giveUnit.OnClientEvent:Connect(function(unitName)
    enterPlacingMode(unitName)
end)

-- Server confirms a plot unit (or upgrade)
plotUpdated.OnClientEvent:Connect(function(idx, unitName)
    placedUnits[idx] = unitName
    refreshAll()
    print("[Panel] Plot", idx, "→", unitName)
end)

-- Server confirms a plot was sold/cleared
plotSold.OnClientEvent:Connect(function(idx)
    placedUnits[idx] = nil
    refreshAll()
    print("[Panel] Plot", idx, "cleared")
end)

-- ── Initial draw ──────────────────────────────────────────────
refreshAll()
print("[PlacementSystem] Ready.")
