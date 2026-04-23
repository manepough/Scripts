-- PlotPanelUI.lua  (LocalScript)
-- Place inside: StarterGui  OR  StarterPlayerScripts
-- ─────────────────────────────────────────────────────────────
-- HOW IT WORKS:
--   • Panel at bottom-center shows 8 plot slots
--   • Click a slot  → opens unit picker popup (if plot is empty)
--   • Pick a unit   → fires PlaceUnit RemoteEvent to server
--   • SELL button   → toggles sell mode; click any occupied plot to sell it
-- ─────────────────────────────────────────────────────────────

local Players        = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService   = game:GetService("TweenService")

local player    = Players.LocalPlayer
local playerGui = player.PlayerGui

-- ─── RemoteEvents ────────────────────────────────────────────
-- Create both of these in ReplicatedStorage on the SERVER:
--   • PlaceUnit  (server receives: plotIndex: number, unitName: string)
--   • SellUnit   (server receives: plotIndex: number)
-- ─────────────────────────────────────────────────────────────

-- ─── Customise your unit roster here ─────────────────────────
local UNITS = {
    { name = "Soldier",  cost = 100, color = Color3.fromRGB( 80, 200,  80) },
    { name = "Sniper",   cost = 250, color = Color3.fromRGB( 80, 140, 230) },
    { name = "Medic",    cost = 150, color = Color3.fromRGB(230,  80,  80) },
    { name = "Heavy",    cost = 400, color = Color3.fromRGB(230, 160,  50) },
    { name = "Engineer", cost = 200, color = Color3.fromRGB(160,  80, 230) },
}

-- ─── State ────────────────────────────────────────────────────
local sellMode    = false
local selectedPlot = nil   -- 1-8 while picking, nil otherwise

-- what unit occupies each plot (nil = empty)
local plotUnit = {}        -- plotUnit[i] = string or nil

-- ─── Helpers ──────────────────────────────────────────────────
local TWEEN_FAST = TweenInfo.new(0.12, Enum.EasingStyle.Quad)

local function tween(obj, props)
    TweenService:Create(obj, TWEEN_FAST, props):Play()
end

local function fireRemote(name, ...)
    local r = ReplicatedStorage:FindFirstChild(name)
    if r then r:FireServer(...) end
end

-- ─── ScreenGui ───────────────────────────────────────────────
local gui = Instance.new("ScreenGui")
gui.Name          = "PlotPanelUI"
gui.ResetOnSpawn  = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent        = playerGui

-- ════════════════════════════════════════════════════════════
--  MAIN PANEL
-- ════════════════════════════════════════════════════════════
local panel = Instance.new("Frame")
panel.Name                = "Panel"
panel.Size                = UDim2.new(0, 660, 0, 128)
panel.Position            = UDim2.new(0.5, -330, 1, -142)
panel.BackgroundColor3    = Color3.fromRGB(14, 16, 26)
panel.BorderSizePixel     = 0
panel.Parent              = gui

do
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0,14); c.Parent = panel
    local s = Instance.new("UIStroke"); s.Color = Color3.fromRGB(55,75,130); s.Thickness = 2; s.Parent = panel
end

-- "PLOTS" header
local header = Instance.new("TextLabel")
header.Size               = UDim2.new(1,0,0,18)
header.Position           = UDim2.new(0,0,0,5)
header.BackgroundTransparency = 1
header.Text               = "── PLOTS ──"
header.TextColor3         = Color3.fromRGB(160,185,255)
header.TextSize           = 11
header.Font               = Enum.Font.GothamBold
header.Parent             = panel

-- ─── Plot-slots container ─────────────────────────────────────
local slotsFrame = Instance.new("Frame")
slotsFrame.Name           = "Slots"
slotsFrame.Size           = UDim2.new(1,-14, 0, 92)
slotsFrame.Position       = UDim2.new(0, 7, 0, 27)
slotsFrame.BackgroundTransparency = 1
slotsFrame.Parent         = panel

do
    local l = Instance.new("UIListLayout")
    l.FillDirection         = Enum.FillDirection.Horizontal
    l.HorizontalAlignment   = Enum.HorizontalAlignment.Center
    l.VerticalAlignment     = Enum.VerticalAlignment.Center
    l.Padding               = UDim.new(0, 5)
    l.Parent                = slotsFrame
end

-- ─── SELL button (sits to the right of the panel) ────────────
local sellBtn = Instance.new("TextButton")
sellBtn.Name              = "SellBtn"
sellBtn.Size              = UDim2.new(0, 68, 0, 60)
sellBtn.Position          = UDim2.new(1, 10, 0.5, -30)
sellBtn.BackgroundColor3  = Color3.fromRGB(160, 40, 40)
sellBtn.Text              = "SELL"
sellBtn.TextColor3        = Color3.fromRGB(255,255,255)
sellBtn.TextSize          = 13
sellBtn.Font              = Enum.Font.GothamBold
sellBtn.BorderSizePixel   = 0
sellBtn.AutoButtonColor   = false
sellBtn.Parent            = panel

do
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0,10); c.Parent = sellBtn
    local s = Instance.new("UIStroke"); s.Name = "Stroke"; s.Color = Color3.fromRGB(255,90,90); s.Thickness = 2; s.Parent = sellBtn
end

-- ════════════════════════════════════════════════════════════
--  UNIT PICKER POPUP
-- ════════════════════════════════════════════════════════════
local picker = Instance.new("Frame")
picker.Name               = "UnitPicker"
picker.Size               = UDim2.new(0, 340, 0, 115)
picker.Position           = UDim2.new(0.5, -170, 1, -275)
picker.BackgroundColor3   = Color3.fromRGB(14, 16, 26)
picker.BorderSizePixel    = 0
picker.Visible            = false
picker.Parent             = gui

do
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0,14); c.Parent = picker
    local s = Instance.new("UIStroke"); s.Color = Color3.fromRGB(80,120,220); s.Thickness = 2; s.Parent = picker
end

local pickerTitle = Instance.new("TextLabel")
pickerTitle.Size              = UDim2.new(1,-40,0,20)
pickerTitle.Position          = UDim2.new(0,8,0,5)
pickerTitle.BackgroundTransparency = 1
pickerTitle.Text              = "SELECT UNIT"
pickerTitle.TextColor3        = Color3.fromRGB(160,185,255)
pickerTitle.TextSize          = 11
pickerTitle.Font              = Enum.Font.GothamBold
pickerTitle.TextXAlignment    = Enum.TextXAlignment.Left
pickerTitle.Parent            = picker

-- Close (✕) button
local closeBtn = Instance.new("TextButton")
closeBtn.Size             = UDim2.new(0,20,0,20)
closeBtn.Position         = UDim2.new(1,-26,0,5)
closeBtn.BackgroundColor3 = Color3.fromRGB(160,40,40)
closeBtn.Text             = "✕"
closeBtn.TextColor3       = Color3.fromRGB(255,255,255)
closeBtn.TextSize         = 11
closeBtn.Font             = Enum.Font.GothamBold
closeBtn.BorderSizePixel  = 0
closeBtn.AutoButtonColor  = false
closeBtn.Parent           = picker

do local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0,5); c.Parent = closeBtn end

-- Units row
local unitsRow = Instance.new("Frame")
unitsRow.Size             = UDim2.new(1,-12, 0, 78)
unitsRow.Position         = UDim2.new(0, 6, 0, 30)
unitsRow.BackgroundTransparency = 1
unitsRow.Parent           = picker

do
    local l = Instance.new("UIListLayout")
    l.FillDirection       = Enum.FillDirection.Horizontal
    l.HorizontalAlignment = Enum.HorizontalAlignment.Center
    l.VerticalAlignment   = Enum.VerticalAlignment.Center
    l.Padding             = UDim.new(0, 6)
    l.Parent              = unitsRow
end

-- ════════════════════════════════════════════════════════════
--  SLOT VISUAL REFRESH
-- ════════════════════════════════════════════════════════════
local slots = {}   -- filled below

local COLORS = {
    empty    = Color3.fromRGB(30, 32, 48),
    selected = Color3.fromRGB(40, 80, 190),
    occupied = Color3.fromRGB(22, 50, 30),
    sellHov  = Color3.fromRGB(90, 22, 22),
}

local function refreshSlot(i)
    local s = slots[i]; if not s then return end
    local isSelected = (selectedPlot == i)
    local hasUnit    = (plotUnit[i] ~= nil)

    -- background
    local bg = isSelected and (sellMode and Color3.fromRGB(160,40,40) or COLORS.selected)
              or (hasUnit and COLORS.occupied or COLORS.empty)
    s.btn.BackgroundColor3 = bg

    -- stroke
    local stroke = s.btn:FindFirstChild("Stroke")
    if stroke then
        stroke.Color = isSelected and Color3.fromRGB(120,170,255)
                     or (hasUnit and Color3.fromRGB(60,180,60) or Color3.fromRGB(55,60,90))
        stroke.Thickness = isSelected and 2.5 or 1.2
    end

    -- text
    s.unitLbl.Text      = plotUnit[i] or "Empty"
    s.unitLbl.TextColor3 = hasUnit and Color3.fromRGB(100,255,110) or Color3.fromRGB(90,90,120)
    s.iconFrame.BackgroundColor3 = hasUnit and Color3.fromRGB(50,130,50) or Color3.fromRGB(40,42,60)
end

local function refreshAll()
    for i = 1,8 do refreshSlot(i) end
end

-- ════════════════════════════════════════════════════════════
--  BUILD PLOT SLOTS
-- ════════════════════════════════════════════════════════════
for i = 1, 8 do
    local btn = Instance.new("TextButton")
    btn.Name             = "Slot"..i
    btn.Size             = UDim2.new(0, 72, 0, 88)
    btn.BackgroundColor3 = COLORS.empty
    btn.BorderSizePixel  = 0
    btn.Text             = ""
    btn.AutoButtonColor  = false
    btn.Parent           = slotsFrame

    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0,9); c.Parent = btn
    local s = Instance.new("UIStroke"); s.Name = "Stroke"; s.Color = Color3.fromRGB(55,60,90); s.Thickness = 1.2; s.Parent = btn

    -- "Plot N" header
    local numLbl = Instance.new("TextLabel")
    numLbl.Size               = UDim2.new(1,0,0,18)
    numLbl.Position           = UDim2.new(0,0,0,5)
    numLbl.BackgroundTransparency = 1
    numLbl.Text               = "Plot "..i
    numLbl.TextColor3         = Color3.fromRGB(150,160,200)
    numLbl.TextSize           = 10
    numLbl.Font               = Enum.Font.GothamBold
    numLbl.Parent             = btn

    -- icon square
    local iconFrame = Instance.new("Frame")
    iconFrame.Size            = UDim2.new(0,28,0,28)
    iconFrame.Position        = UDim2.new(0.5,-14, 0, 24)
    iconFrame.BackgroundColor3 = Color3.fromRGB(40,42,60)
    iconFrame.BorderSizePixel = 0
    iconFrame.Parent          = btn
    do local ic = Instance.new("UICorner"); ic.CornerRadius = UDim.new(0,6); ic.Parent = iconFrame end

    -- unit name label
    local unitLbl = Instance.new("TextLabel")
    unitLbl.Size              = UDim2.new(1,-4,0,18)
    unitLbl.Position          = UDim2.new(0,2,0,57)
    unitLbl.BackgroundTransparency = 1
    unitLbl.Text              = "Empty"
    unitLbl.TextColor3        = Color3.fromRGB(90,90,120)
    unitLbl.TextSize          = 9
    unitLbl.Font              = Enum.Font.Gotham
    unitLbl.TextWrapped       = true
    unitLbl.Parent            = btn

    slots[i] = { btn = btn, unitLbl = unitLbl, iconFrame = iconFrame }

    -- ── click ──────────────────────────────────────────────
    btn.MouseButton1Click:Connect(function()
        if sellMode then
            -- SELL MODE: sell whatever is on this plot
            if plotUnit[i] then
                fireRemote("SellUnit", i)
                print("[PlotPanel] Sold", plotUnit[i], "from Plot", i)
                plotUnit[i] = nil
            else
                print("[PlotPanel] Plot", i, "is already empty.")
            end
            selectedPlot = nil
            refreshAll()
        else
            -- NORMAL MODE: select plot → open picker
            if plotUnit[i] then
                -- plot occupied; you could add upgrade logic here
                print("[PlotPanel] Plot", i, "occupied by:", plotUnit[i])
                return
            end
            selectedPlot = i
            pickerTitle.Text = "SELECT UNIT  →  Plot "..i
            picker.Visible   = true
            refreshAll()
        end
    end)

    -- hover glow
    btn.MouseEnter:Connect(function()
        if selectedPlot ~= i then
            tween(btn, { BackgroundColor3 =
                sellMode and COLORS.sellHov or Color3.fromRGB(48,52,80) })
        end
    end)
    btn.MouseLeave:Connect(function()
        refreshSlot(i)
    end)
end

-- ════════════════════════════════════════════════════════════
--  BUILD UNIT BUTTONS IN PICKER
-- ════════════════════════════════════════════════════════════
for _, u in ipairs(UNITS) do
    local uBtn = Instance.new("TextButton")
    uBtn.Name             = u.name
    uBtn.Size             = UDim2.new(0, 58, 0, 72)
    uBtn.BackgroundColor3 = Color3.fromRGB(24, 28, 46)
    uBtn.BorderSizePixel  = 0
    uBtn.Text             = ""
    uBtn.AutoButtonColor  = false
    uBtn.Parent           = unitsRow

    local uc = Instance.new("UICorner"); uc.CornerRadius = UDim.new(0,9); uc.Parent = uBtn
    local us = Instance.new("UIStroke"); us.Color = u.color; us.Thickness = 1.5; us.Parent = uBtn

    -- coloured icon
    local uIcon = Instance.new("Frame")
    uIcon.Size            = UDim2.new(0,26,0,26)
    uIcon.Position        = UDim2.new(0.5,-13, 0, 8)
    uIcon.BackgroundColor3 = u.color
    uIcon.BorderSizePixel = 0
    uIcon.Parent          = uBtn
    do local ic = Instance.new("UICorner"); ic.CornerRadius = UDim.new(0,6); ic.Parent = uIcon end

    local uName = Instance.new("TextLabel")
    uName.Size            = UDim2.new(1,0,0,16)
    uName.Position        = UDim2.new(0,0,0,36)
    uName.BackgroundTransparency = 1
    uName.Text            = u.name
    uName.TextColor3      = Color3.fromRGB(220,225,255)
    uName.TextSize        = 9
    uName.Font            = Enum.Font.GothamBold
    uName.TextWrapped     = true
    uName.Parent          = uBtn

    local uCost = Instance.new("TextLabel")
    uCost.Size            = UDim2.new(1,0,0,14)
    uCost.Position        = UDim2.new(0,0,0,52)
    uCost.BackgroundTransparency = 1
    uCost.Text            = "$"..u.cost
    uCost.TextColor3      = Color3.fromRGB(255,215,60)
    uCost.TextSize        = 9
    uCost.Font            = Enum.Font.Gotham
    uCost.Parent          = uBtn

    uBtn.MouseButton1Click:Connect(function()
        if not selectedPlot then return end
        local idx = selectedPlot

        fireRemote("PlaceUnit", idx, u.name)
        print("[PlotPanel] Placed", u.name, "on Plot", idx)

        plotUnit[idx] = u.name
        picker.Visible = false
        selectedPlot   = nil
        refreshAll()
    end)

    uBtn.MouseEnter:Connect(function()
        tween(uBtn, { BackgroundColor3 = Color3.fromRGB(44, 50, 80) })
        tween(us,   { Thickness = 2.5 })
    end)
    uBtn.MouseLeave:Connect(function()
        tween(uBtn, { BackgroundColor3 = Color3.fromRGB(24, 28, 46) })
        tween(us,   { Thickness = 1.5 })
    end)
end

-- ════════════════════════════════════════════════════════════
--  SELL BUTTON LOGIC
-- ════════════════════════════════════════════════════════════
local sellStroke = sellBtn:FindFirstChild("Stroke")

sellBtn.MouseButton1Click:Connect(function()
    sellMode = not sellMode
    picker.Visible = false   -- close picker if open
    selectedPlot   = nil

    if sellMode then
        tween(sellBtn,   { BackgroundColor3 = Color3.fromRGB(210, 50, 50) })
        sellStroke.Color = Color3.fromRGB(255, 160, 160)
        sellBtn.Text     = "SELL\n[ON]"
    else
        tween(sellBtn,   { BackgroundColor3 = Color3.fromRGB(160, 40, 40) })
        sellStroke.Color = Color3.fromRGB(255, 90, 90)
        sellBtn.Text     = "SELL"
    end
    refreshAll()
    print("[PlotPanel] Sell mode:", sellMode)
end)

-- close picker ✕ button
closeBtn.MouseButton1Click:Connect(function()
    picker.Visible = false
    selectedPlot   = nil
    refreshAll()
end)

-- ─── Optional: listen for server-authoritative updates ────────
-- If the server fires back a "PlotUpdated" event, use it here:
--
-- local plotUpdated = ReplicatedStorage:WaitForChild("PlotUpdated")
-- plotUpdated.OnClientEvent:Connect(function(plotIndex, unitName)
--     plotUnit[plotIndex] = unitName   -- nil = sold / removed
--     refreshAll()
-- end)

-- ─── Initial draw ─────────────────────────────────────────────
refreshAll()

print("[PlotPanel] UI loaded successfully.")
