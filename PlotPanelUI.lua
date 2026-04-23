-- PlotPanelUI.lua  (LocalScript)
-- Place inside: StarterGui  (with ResetOnSpawn = false)
-- ══════════════════════════════════════════════════════════════════
--  HOW IT WORKS:
--    1. Player buys from shop → server fires "GiveUnit" to client
--       → "HOLDING: [unit]" banner appears, green highlights show on empty plots
--    2. Click an EMPTY plot slot → fires "PlaceUnit" to server
--       → slot shows the unit name at bottom
--    3. Press SELL button → sell mode ON → click OCCUPIED plot → fires "SellUnit"
--    4. Server fires "PlotUpdated" → GUI auto-updates (handles upgrades)
--    5. Server fires "PlotSold"    → GUI clears that slot
-- ══════════════════════════════════════════════════════════════════

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")

local player    = Players.LocalPlayer
local playerGui = player.PlayerGui

-- ── RemoteEvents (create these in ReplicatedStorage on the server) ─
--  GiveUnit    Server→Client : (string unitName)
--  PlaceUnit   Client→Server : (number plotIndex, string unitName)
--  SellUnit    Client→Server : (number plotIndex)
--  PlotUpdated Server→Client : (number plotIndex, string unitName)
--  PlotSold    Server→Client : (number plotIndex)

-- ── State ──────────────────────────────────────────────────────────
local heldUnit = nil   -- unit name currently being held, or nil
local sellMode = false
local plotUnit = {}    -- plotUnit[1..8] = string unit name or nil

-- ── Helpers ────────────────────────────────────────────────────────
local function tw(obj, props, t)
    TweenService:Create(obj, TweenInfo.new(t or 0.12, Enum.EasingStyle.Quad), props):Play()
end

local function fire(name, ...)
    local r = ReplicatedStorage:FindFirstChild(name)
    if r then r:FireServer(...) end
end

-- ══════════════════════════════════════════════════════════════════
--  SCREEN GUI
-- ══════════════════════════════════════════════════════════════════
local gui = Instance.new("ScreenGui")
gui.Name           = "PlotPanelUI"
gui.ResetOnSpawn   = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.IgnoreGuiInset = true
gui.Parent         = playerGui

-- ══════════════════════════════════════════════════════════════════
--  HOLDING BANNER  (top-center, only visible when holding a unit)
-- ══════════════════════════════════════════════════════════════════
local holdBar = Instance.new("Frame")
holdBar.Name             = "HoldBar"
holdBar.Size             = UDim2.new(0, 290, 0, 36)
holdBar.Position         = UDim2.new(0.5, -145, 0, 12)
holdBar.BackgroundColor3 = Color3.fromRGB(18, 55, 18)
holdBar.BorderSizePixel  = 0
holdBar.Visible          = false
holdBar.Parent           = gui
do
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0,10); c.Parent = holdBar
    local s = Instance.new("UIStroke"); s.Color = Color3.fromRGB(60,210,60); s.Thickness = 2; s.Parent = holdBar
end

local holdLbl = Instance.new("TextLabel")
holdLbl.Size                 = UDim2.new(1,0,1,0)
holdLbl.BackgroundTransparency = 1
holdLbl.Text                 = "⚑ HOLDING: ?"
holdLbl.TextColor3           = Color3.fromRGB(90,255,90)
holdLbl.TextSize             = 13
holdLbl.Font                 = Enum.Font.GothamBold
holdLbl.Parent               = holdBar

-- ══════════════════════════════════════════════════════════════════
--  MAIN PANEL  (bottom of screen, 8 tall narrow vertical slots)
-- ══════════════════════════════════════════════════════════════════
local SLOT_W   = 60   -- narrow width
local SLOT_H   = 155  -- tall height (portrait ratio like in-game)
local SLOT_GAP = 5
local PAD      = 8
local HDR_H    = 22

local totalW = PAD * 2 + SLOT_W * 8 + SLOT_GAP * 7
local panelH = HDR_H + SLOT_H + PAD + 6

local panel = Instance.new("Frame")
panel.Name             = "Panel"
panel.Size             = UDim2.new(0, totalW, 0, panelH)
panel.Position         = UDim2.new(0.5, -totalW/2, 1, -(panelH + 8))
panel.BackgroundColor3 = Color3.fromRGB(14, 16, 26)
panel.BorderSizePixel  = 0
panel.Parent           = gui
do
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0,14); c.Parent = panel
    local s = Instance.new("UIStroke"); s.Color = Color3.fromRGB(50,70,135); s.Thickness = 2; s.Parent = panel
end

-- Header label
local hdr = Instance.new("TextLabel")
hdr.Size                 = UDim2.new(1,0,0,HDR_H)
hdr.Position             = UDim2.new(0,0,0,4)
hdr.BackgroundTransparency = 1
hdr.Text                 = "── PLOTS ──"
hdr.TextColor3           = Color3.fromRGB(140,165,250)
hdr.TextSize             = 10
hdr.Font                 = Enum.Font.GothamBold
hdr.Parent               = panel

-- SELL button (anchored to right of panel)
local sellBtn = Instance.new("TextButton")
sellBtn.Name             = "SellBtn"
sellBtn.Size             = UDim2.new(0, 58, 0, 52)
sellBtn.Position         = UDim2.new(1, 8, 0.5, -26)
sellBtn.BackgroundColor3 = Color3.fromRGB(150, 32, 32)
sellBtn.Text             = "SELL"
sellBtn.TextColor3       = Color3.fromRGB(255,255,255)
sellBtn.TextSize         = 12
sellBtn.Font             = Enum.Font.GothamBold
sellBtn.BorderSizePixel  = 0
sellBtn.AutoButtonColor  = false
sellBtn.Parent           = panel
do
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0,10); c.Parent = sellBtn
    Instance.new("UIStroke", sellBtn).Name = "Stroke"
    sellBtn:FindFirstChild("Stroke").Color     = Color3.fromRGB(255,75,75)
    sellBtn:FindFirstChild("Stroke").Thickness = 2
end

-- ══════════════════════════════════════════════════════════════════
--  BUILD SLOT VISUALS  (8 tall narrow plots)
-- ══════════════════════════════════════════════════════════════════
local C = {
    empty     = Color3.fromRGB(26, 28, 44),
    occupied  = Color3.fromRGB(16, 40, 20),
    holdAvail = Color3.fromRGB(16, 46, 16),   -- empty+holding
    sell      = Color3.fromRGB(55, 14, 14),
}

local slots = {}

local function refreshSlot(i)
    local s = slots[i]; if not s then return end
    local hasUnit = plotUnit[i] ~= nil

    -- frame bg
    local bg = C.empty
    if sellMode and hasUnit then
        bg = C.sell
    elseif heldUnit and not hasUnit then
        bg = C.holdAvail
    elseif hasUnit then
        bg = C.occupied
    end
    s.frame.BackgroundColor3 = bg

    -- stroke
    local stk = s.frame:FindFirstChild("Stroke")
    if stk then
        if hasUnit and sellMode then
            stk.Color = Color3.fromRGB(230,60,60); stk.Thickness = 2
        elseif hasUnit then
            stk.Color = Color3.fromRGB(55,195,55); stk.Thickness = 2
        elseif heldUnit then
            stk.Color = Color3.fromRGB(55,195,55); stk.Thickness = 1.5
        else
            stk.Color = Color3.fromRGB(42,46,76); stk.Thickness = 1
        end
    end

    -- unit pill (bottom)
    s.unitPill.Visible    = hasUnit
    s.unitLbl.Text        = plotUnit[i] or ""

    -- number dimming
    s.numLbl.TextColor3   = hasUnit
        and Color3.fromRGB(100,108,155)
        or  Color3.fromRGB(155,165,215)
end

local function refreshAll()
    for i = 1,8 do refreshSlot(i) end
end

for i = 1, 8 do
    local xPos = PAD + (i-1) * (SLOT_W + SLOT_GAP)
    local yPos = HDR_H + 4

    -- SLOT FRAME
    local frame = Instance.new("Frame")
    frame.Name             = "Plot"..i
    frame.Size             = UDim2.new(0, SLOT_W, 0, SLOT_H)
    frame.Position         = UDim2.new(0, xPos, 0, yPos)
    frame.BackgroundColor3 = C.empty
    frame.BorderSizePixel  = 0
    frame.Parent           = panel
    do
        local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0,8); c.Parent = frame
        local s = Instance.new("UIStroke"); s.Name = "Stroke"; s.Color = Color3.fromRGB(42,46,76); s.Thickness = 1; s.Parent = frame
    end

    -- NUMBER PILL (top)
    local numPill = Instance.new("Frame")
    numPill.Size             = UDim2.new(1,-10, 0, 20)
    numPill.Position         = UDim2.new(0, 5, 0, 4)
    numPill.BackgroundColor3 = Color3.fromRGB(20, 22, 36)
    numPill.BorderSizePixel  = 0
    numPill.Parent           = frame
    do local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0,5); c.Parent = numPill end

    local numLbl = Instance.new("TextLabel")
    numLbl.Size                 = UDim2.new(1,0,1,0)
    numLbl.BackgroundTransparency = 1
    numLbl.Text                 = tostring(i)
    numLbl.TextColor3           = Color3.fromRGB(155,165,215)
    numLbl.TextSize             = 11
    numLbl.Font                 = Enum.Font.GothamBold
    numLbl.Parent               = numPill

    -- CENTER DIVIDER LINE (decorative, matches vertical plot look)
    local divLine = Instance.new("Frame")
    divLine.Size             = UDim2.new(0, 1, 0, SLOT_H - 56)
    divLine.Position         = UDim2.new(0.5, 0, 0, 28)
    divLine.BackgroundColor3 = Color3.fromRGB(38, 42, 65)
    divLine.BorderSizePixel  = 0
    divLine.Parent           = frame

    -- UNIT PILL (bottom) — hidden when empty
    local unitPill = Instance.new("Frame")
    unitPill.Name            = "UnitPill"
    unitPill.Size            = UDim2.new(1,-8, 0, 24)
    unitPill.Position        = UDim2.new(0, 4, 1, -28)
    unitPill.BackgroundColor3 = Color3.fromRGB(18, 22, 36)
    unitPill.BorderSizePixel = 0
    unitPill.Visible         = false
    unitPill.Parent          = frame
    do local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0,5); c.Parent = unitPill end

    local unitLbl = Instance.new("TextLabel")
    unitLbl.Size                 = UDim2.new(1,-4, 1, 0)
    unitLbl.Position             = UDim2.new(0, 2, 0, 0)
    unitLbl.BackgroundTransparency = 1
    unitLbl.Text                 = ""
    unitLbl.TextColor3           = Color3.fromRGB(70,225,70)
    unitLbl.TextSize             = 8
    unitLbl.Font                 = Enum.Font.GothamBold
    unitLbl.TextWrapped          = true
    unitLbl.TextScaled           = true
    unitLbl.Parent               = unitPill

    -- INVISIBLE CLICK BUTTON (sits on top of everything in the slot)
    local btn = Instance.new("TextButton")
    btn.Size                = UDim2.new(1,0,1,0)
    btn.BackgroundTransparency = 1
    btn.Text                = ""
    btn.ZIndex              = 10
    btn.AutoButtonColor     = false
    btn.Parent              = frame

    slots[i] = {
        frame    = frame,
        numLbl   = numLbl,
        unitPill = unitPill,
        unitLbl  = unitLbl,
        btn      = btn,
    }

    -- ── CLICK ────────────────────────────────────────────────────
    btn.MouseButton1Click:Connect(function()
        if sellMode then
            -- sell mode: sell whatever is on this plot
            if plotUnit[i] then
                fire("SellUnit", i)
                print("[Panel] Selling", plotUnit[i], "from Plot", i)
                plotUnit[i] = nil
                refreshAll()
            end

        elseif heldUnit then
            -- holding a unit: place it on this empty plot
            if not plotUnit[i] then
                fire("PlaceUnit", i, heldUnit)
                print("[Panel] Placing", heldUnit, "on Plot", i)
                plotUnit[i] = heldUnit
                heldUnit    = nil
                holdBar.Visible = false
                refreshAll()
            else
                print("[Panel] Plot", i, "is occupied by:", plotUnit[i])
            end

        else
            print("[Panel] Not holding anything. Buy a unit from the shop first!")
        end
    end)

    -- hover feedback
    btn.MouseEnter:Connect(function()
        local hasUnit = plotUnit[i] ~= nil
        if sellMode and hasUnit then
            tw(frame, { BackgroundColor3 = Color3.fromRGB(100,18,18) })
        elseif heldUnit and not hasUnit then
            tw(frame, { BackgroundColor3 = Color3.fromRGB(26,70,26) })
        end
    end)
    btn.MouseLeave:Connect(function()
        refreshSlot(i)
    end)
end

-- ══════════════════════════════════════════════════════════════════
--  SELL BUTTON LOGIC
-- ══════════════════════════════════════════════════════════════════
local sellStroke = sellBtn:FindFirstChild("Stroke")

sellBtn.MouseButton1Click:Connect(function()
    sellMode = not sellMode

    -- cancel held unit when toggling sell mode
    heldUnit        = nil
    holdBar.Visible = false

    if sellMode then
        tw(sellBtn, { BackgroundColor3 = Color3.fromRGB(210,42,42) })
        sellStroke.Color = Color3.fromRGB(255,140,140)
        sellBtn.Text     = "SELL\n[ON]"
    else
        tw(sellBtn, { BackgroundColor3 = Color3.fromRGB(150,32,32) })
        sellStroke.Color = Color3.fromRGB(255,75,75)
        sellBtn.Text     = "SELL"
    end
    refreshAll()
end)

-- ══════════════════════════════════════════════════════════════════
--  SERVER → CLIENT EVENTS
-- ══════════════════════════════════════════════════════════════════

-- Server gives player a unit to hold (after buying from shop)
local giveUnit = ReplicatedStorage:WaitForChild("GiveUnit", 10)
if giveUnit then
    giveUnit.OnClientEvent:Connect(function(unitName)
        -- exit sell mode when picking something up
        sellMode         = false
        tw(sellBtn, { BackgroundColor3 = Color3.fromRGB(150,32,32) })
        sellStroke.Color = Color3.fromRGB(255,75,75)
        sellBtn.Text     = "SELL"

        heldUnit         = unitName
        holdLbl.Text     = "⚑ HOLDING: " .. unitName
        holdBar.Visible  = true

        -- gentle pulse on the hold bar
        local function pulse()
            if not heldUnit then return end
            tw(holdBar, { BackgroundColor3 = Color3.fromRGB(28,80,28) }, 0.45)
            task.delay(0.45, function()
                if heldUnit then
                    tw(holdBar, { BackgroundColor3 = Color3.fromRGB(18,55,18) }, 0.45)
                    task.delay(0.45, pulse)
                end
            end)
        end
        pulse()
        refreshAll()
        print("[Panel] Now holding:", unitName)
    end)
end

-- Server confirms plot was updated OR upgraded — auto-reflect in GUI
local plotUpdated = ReplicatedStorage:WaitForChild("PlotUpdated", 10)
if plotUpdated then
    plotUpdated.OnClientEvent:Connect(function(plotIndex, unitName)
        plotUnit[plotIndex] = unitName
        refreshAll()
        print("[Panel] Plot", plotIndex, "→", unitName)
    end)
end

-- Server confirms plot was sold / cleared
local plotSold = ReplicatedStorage:WaitForChild("PlotSold", 10)
if plotSold then
    plotSold.OnClientEvent:Connect(function(plotIndex)
        plotUnit[plotIndex] = nil
        refreshAll()
        print("[Panel] Plot", plotIndex, "cleared")
    end)
end

-- ── Initial draw ──────────────────────────────────────────────────
refreshAll()
print("[PlotPanelUI] Ready.")
