-- ╔══════════════════════════════════════════╗
-- ║     Hack Event — Aimbot GUI v4           ║
-- ║  Circle targeting, glow, auto shoot      ║
-- ╚══════════════════════════════════════════╝

local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService     = game:GetService("TweenService")

local player  = Players.LocalPlayer
local camera  = workspace.CurrentCamera

-- ┌─────────────────────────────────────────┐
-- │              CONFIG                      │
-- └─────────────────────────────────────────┘
local circleRadius  = 180   -- starting circle px
local MIN_RADIUS    = 60
local MAX_RADIUS    = 350
local SHOOT_DELAY   = 0.12  -- seconds between auto shots

-- ┌─────────────────────────────────────────┐
-- │              STATE                       │
-- └─────────────────────────────────────────┘
local aimbotEnabled    = false
local autoShootEnabled = false
local throughWalls     = true
local guiVisible       = true
local currentTarget    = nil
local currentHighlight = nil
local lastShot         = 0

local PANEL_BASE_H     = 352
local PANEL_SLIDER_H   = 412

-- ═══════════════════════════════════════════
--                  SCREENGUI
-- ═══════════════════════════════════════════

local sg = Instance.new("ScreenGui")
sg.Name              = "HackEventGUI"
sg.ResetOnSpawn      = false
sg.ZIndexBehavior    = Enum.ZIndexBehavior.Sibling
sg.IgnoreGuiInset    = true
sg.Parent            = player.PlayerGui

-- ═══════════════════════════════════════════
--              CROSSHAIR (circle)
-- ═══════════════════════════════════════════

local crosshairFrame = Instance.new("Frame")
crosshairFrame.BackgroundTransparency = 1
crosshairFrame.BorderSizePixel        = 0
crosshairFrame.ZIndex                 = 2
crosshairFrame.Visible                = false   -- hidden until aimbot ON
crosshairFrame.Parent                 = sg
Instance.new("UICorner", crosshairFrame).CornerRadius = UDim.new(1, 0)

local ringStroke = Instance.new("UIStroke", crosshairFrame)
ringStroke.Thickness = 2

-- Center dot
local centerDot = Instance.new("Frame")
centerDot.Size                 = UDim2.new(0, 8, 0, 8)
centerDot.BackgroundColor3     = Color3.fromRGB(255, 255, 255)
centerDot.BorderSizePixel      = 0
centerDot.ZIndex               = 3
centerDot.Visible              = false
centerDot.Parent               = sg
Instance.new("UICorner", centerDot).CornerRadius = UDim.new(1, 0)

-- Cross lines
local lineH = Instance.new("Frame")
lineH.Size             = UDim2.new(0, 22, 0, 2)
lineH.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
lineH.BorderSizePixel  = 0
lineH.ZIndex           = 3
lineH.Visible          = false
lineH.Parent           = sg

local lineV = Instance.new("Frame")
lineV.Size             = UDim2.new(0, 2, 0, 22)
lineV.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
lineV.BorderSizePixel  = 0
lineV.ZIndex           = 3
lineV.Visible          = false
lineV.Parent           = sg

local function refreshCrosshairGeometry()
    crosshairFrame.Size     = UDim2.new(0, circleRadius * 2, 0, circleRadius * 2)
    crosshairFrame.Position = UDim2.new(0.5, -circleRadius, 0.5, -circleRadius)
    centerDot.Position      = UDim2.new(0.5, -4, 0.5, -4)
    lineH.Position          = UDim2.new(0.5, -11, 0.5, -1)
    lineV.Position          = UDim2.new(0.5, -1, 0.5, -11)
end

local function setCrosshairColor(hasTarget)
    local col   = hasTarget and Color3.fromRGB(255, 50, 50) or Color3.fromRGB(170, 165, 255)
    local thick = hasTarget and 2.8 or 1.8
    ringStroke.Color     = col
    ringStroke.Thickness = thick
    centerDot.BackgroundColor3 = col
    lineH.BackgroundColor3     = col
    lineV.BackgroundColor3     = col
end

local function setCrosshairVisible(v)
    crosshairFrame.Visible = v
    centerDot.Visible      = v
    lineH.Visible          = v
    lineV.Visible          = v
end

refreshCrosshairGeometry()
setCrosshairColor(false)

-- ═══════════════════════════════════════════
--               FLOATING M BUTTON
-- ═══════════════════════════════════════════

local mBtn = Instance.new("TextButton")
mBtn.Text              = "M"
mBtn.Size              = UDim2.new(0, 56, 0, 56)
mBtn.Position          = UDim2.new(0, 16, 0.5, -28)
mBtn.BackgroundColor3  = Color3.fromRGB(28, 26, 50)
mBtn.TextColor3        = Color3.fromRGB(200, 195, 255)
mBtn.TextSize          = 22
mBtn.Font              = Enum.Font.GothamBold
mBtn.BorderSizePixel   = 0
mBtn.ZIndex            = 10
mBtn.Parent            = sg
Instance.new("UICorner", mBtn).CornerRadius = UDim.new(1, 0)
local mStroke = Instance.new("UIStroke", mBtn)
mStroke.Color     = Color3.fromRGB(90, 80, 200)
mStroke.Thickness = 1.5

-- ═══════════════════════════════════════════
--                  PANEL
-- ═══════════════════════════════════════════

local panel = Instance.new("Frame")
panel.Name             = "Panel"
panel.Size             = UDim2.new(0, 275, 0, PANEL_BASE_H)
panel.Position         = UDim2.new(0, 82, 0.5, -(PANEL_BASE_H / 2))
panel.BackgroundColor3 = Color3.fromRGB(18, 18, 24)
panel.BorderSizePixel  = 0
panel.Active           = true
panel.ClipsDescendants = true
panel.Parent           = sg
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 12)
local panelStroke = Instance.new("UIStroke", panel)
panelStroke.Color     = Color3.fromRGB(90, 80, 200)
panelStroke.Thickness = 1.5

-- Title bar
local titleBar = Instance.new("Frame")
titleBar.Size             = UDim2.new(1, 0, 0, 48)
titleBar.BackgroundColor3 = Color3.fromRGB(28, 26, 50)
titleBar.BorderSizePixel  = 0
titleBar.Parent           = panel
Instance.new("UICorner", titleBar).CornerRadius = UDim.new(0, 12)

local tbFix = Instance.new("Frame")    -- square off bottom corners of titlebar
tbFix.Size             = UDim2.new(1, 0, 0, 12)
tbFix.Position         = UDim2.new(0, 0, 1, -12)
tbFix.BackgroundColor3 = Color3.fromRGB(28, 26, 50)
tbFix.BorderSizePixel  = 0
tbFix.Parent           = titleBar

local acDot = Instance.new("Frame")
acDot.Size             = UDim2.new(0, 10, 0, 10)
acDot.Position         = UDim2.new(0, 14, 0.5, -5)
acDot.BackgroundColor3 = Color3.fromRGB(130, 110, 255)
acDot.BorderSizePixel  = 0
acDot.Parent           = titleBar
Instance.new("UICorner", acDot).CornerRadius = UDim.new(1, 0)

local titleLbl = Instance.new("TextLabel")
titleLbl.Text               = "Hack Event"
titleLbl.Size               = UDim2.new(1, -30, 1, 0)
titleLbl.Position           = UDim2.new(0, 32, 0, 0)
titleLbl.BackgroundTransparency = 1
titleLbl.TextColor3         = Color3.fromRGB(220, 215, 255)
titleLbl.TextSize           = 17
titleLbl.Font               = Enum.Font.GothamBold
titleLbl.TextXAlignment     = Enum.TextXAlignment.Left
titleLbl.Parent             = titleBar

-- Content frame
local content = Instance.new("Frame")
content.Size                = UDim2.new(1, -24, 1, -56)
content.Position            = UDim2.new(0, 12, 0, 56)
content.BackgroundTransparency = 1
content.Parent              = panel

local listLayout = Instance.new("UIListLayout")
listLayout.SortOrder = Enum.SortOrder.LayoutOrder
listLayout.Padding   = UDim.new(0, 8)
listLayout.Parent    = content

-- ─── UI Helpers ───────────────────────────

local tweenInfo = TweenInfo.new(0.15, Enum.EasingStyle.Quad)

local function makeSection(txt, order)
    local l = Instance.new("TextLabel")
    l.Text               = txt
    l.Size               = UDim2.new(1, 0, 0, 16)
    l.BackgroundTransparency = 1
    l.TextColor3         = Color3.fromRGB(90, 85, 125)
    l.TextSize           = 11
    l.Font               = Enum.Font.GothamBold
    l.TextXAlignment     = Enum.TextXAlignment.Left
    l.LayoutOrder        = order
    l.Parent             = content
    return l
end

local function makeToggleRow(labelText, state, order)
    local row = Instance.new("Frame")
    row.Size             = UDim2.new(1, 0, 0, 44)
    row.BackgroundColor3 = Color3.fromRGB(28, 26, 45)
    row.BorderSizePixel  = 0
    row.LayoutOrder      = order
    row.Parent           = content
    Instance.new("UICorner", row).CornerRadius = UDim.new(0, 9)

    local lbl = Instance.new("TextLabel")
    lbl.Text               = labelText
    lbl.Size               = UDim2.new(1, -68, 1, 0)
    lbl.Position           = UDim2.new(0, 14, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.TextColor3         = Color3.fromRGB(205, 200, 235)
    lbl.TextSize           = 14
    lbl.Font               = Enum.Font.Gotham
    lbl.TextXAlignment     = Enum.TextXAlignment.Left
    lbl.Parent             = row

    local bg = Instance.new("Frame")
    bg.Size             = UDim2.new(0, 48, 0, 27)
    bg.Position         = UDim2.new(1, -58, 0.5, -13)
    bg.BackgroundColor3 = state and Color3.fromRGB(90, 75, 220) or Color3.fromRGB(55, 50, 78)
    bg.BorderSizePixel  = 0
    bg.Parent           = row
    Instance.new("UICorner", bg).CornerRadius = UDim.new(1, 0)

    local knob = Instance.new("Frame")
    knob.Size             = UDim2.new(0, 21, 0, 21)
    knob.Position         = state and UDim2.new(1, -24, 0.5, -10) or UDim2.new(0, 3, 0.5, -10)
    knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    knob.BorderSizePixel  = 0
    knob.Parent           = bg
    Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)

    local hit = Instance.new("TextButton")
    hit.Size                = UDim2.new(1, 0, 1, 0)
    hit.BackgroundTransparency = 1
    hit.Text                = ""
    hit.Parent              = row

    return hit, bg, knob
end

local function setToggleVisual(bg, knob, state)
    TweenService:Create(bg, tweenInfo, {
        BackgroundColor3 = state and Color3.fromRGB(90, 75, 220) or Color3.fromRGB(55, 50, 78)
    }):Play()
    TweenService:Create(knob, tweenInfo, {
        Position = state and UDim2.new(1, -24, 0.5, -10) or UDim2.new(0, 3, 0.5, -10)
    }):Play()
end

-- ─── Status row ───────────────────────────
makeSection("STATUS", 1)

local statusRow = Instance.new("Frame")
statusRow.Size             = UDim2.new(1, 0, 0, 40)
statusRow.BackgroundColor3 = Color3.fromRGB(28, 26, 45)
statusRow.BorderSizePixel  = 0
statusRow.LayoutOrder      = 2
statusRow.Parent           = content
Instance.new("UICorner", statusRow).CornerRadius = UDim.new(0, 9)

local sDot = Instance.new("Frame")
sDot.Size             = UDim2.new(0, 10, 0, 10)
sDot.Position         = UDim2.new(0, 14, 0.5, -5)
sDot.BackgroundColor3 = Color3.fromRGB(70, 65, 100)
sDot.BorderSizePixel  = 0
sDot.Parent           = statusRow
Instance.new("UICorner", sDot).CornerRadius = UDim.new(1, 0)

local sLabel = Instance.new("TextLabel")
sLabel.Text               = "No target"
sLabel.Size               = UDim2.new(1, -32, 1, 0)
sLabel.Position           = UDim2.new(0, 32, 0, 0)
sLabel.BackgroundTransparency = 1
sLabel.TextColor3         = Color3.fromRGB(130, 125, 160)
sLabel.TextSize           = 13
sLabel.Font               = Enum.Font.Gotham
sLabel.TextXAlignment     = Enum.TextXAlignment.Left
sLabel.Parent             = statusRow

-- ─── Aimbot toggle ────────────────────────
makeSection("AIMBOT", 3)
local aimbotHit, aimbotBg, aimbotKnob = makeToggleRow("Auto aim", false, 4)

-- ─── Circle size slider (hidden until aimbot ON) ───
local sliderRow = Instance.new("Frame")
sliderRow.Size             = UDim2.new(1, 0, 0, 0)   -- 0 = collapsed
sliderRow.BackgroundColor3 = Color3.fromRGB(22, 20, 40)
sliderRow.BorderSizePixel  = 0
sliderRow.LayoutOrder      = 5
sliderRow.ClipsDescendants = true
sliderRow.Parent           = content
Instance.new("UICorner", sliderRow).CornerRadius = UDim.new(0, 9)

local sliderLblTxt = Instance.new("TextLabel")
sliderLblTxt.Text               = "Circle size:  " .. circleRadius .. " px"
sliderLblTxt.Size               = UDim2.new(1, -14, 0, 20)
sliderLblTxt.Position           = UDim2.new(0, 14, 0, 7)
sliderLblTxt.BackgroundTransparency = 1
sliderLblTxt.TextColor3         = Color3.fromRGB(175, 170, 215)
sliderLblTxt.TextSize           = 13
sliderLblTxt.Font               = Enum.Font.Gotham
sliderLblTxt.TextXAlignment     = Enum.TextXAlignment.Left
sliderLblTxt.Parent             = sliderRow

local trackBg = Instance.new("Frame")
trackBg.Size             = UDim2.new(1, -28, 0, 7)
trackBg.Position         = UDim2.new(0, 14, 0, 36)
trackBg.BackgroundColor3 = Color3.fromRGB(45, 42, 72)
trackBg.BorderSizePixel  = 0
trackBg.Parent           = sliderRow
Instance.new("UICorner", trackBg).CornerRadius = UDim.new(1, 0)

local initPct = (circleRadius - MIN_RADIUS) / (MAX_RADIUS - MIN_RADIUS)

local trackFill = Instance.new("Frame")
trackFill.Size             = UDim2.new(initPct, 0, 1, 0)
trackFill.BackgroundColor3 = Color3.fromRGB(90, 75, 220)
trackFill.BorderSizePixel  = 0
trackFill.Parent           = trackBg
Instance.new("UICorner", trackFill).CornerRadius = UDim.new(1, 0)

local trackKnob = Instance.new("Frame")
trackKnob.Size             = UDim2.new(0, 20, 0, 20)
trackKnob.Position         = UDim2.new(initPct, -10, 0.5, -10)
trackKnob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
trackKnob.BorderSizePixel  = 0
trackKnob.Parent           = trackBg
Instance.new("UICorner", trackKnob).CornerRadius = UDim.new(1, 0)

-- Slider drag
local sliderDragging = false
trackBg.InputBegan:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.MouseButton1
        or inp.UserInputType == Enum.UserInputType.Touch then
        sliderDragging = true
    end
end)
trackBg.InputEnded:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.MouseButton1
        or inp.UserInputType == Enum.UserInputType.Touch then
        sliderDragging = false
    end
end)
UserInputService.InputChanged:Connect(function(inp)
    if not sliderDragging then return end
    if inp.UserInputType ~= Enum.UserInputType.MouseMovement
        and inp.UserInputType ~= Enum.UserInputType.Touch then return end
    local absPos  = trackBg.AbsolutePosition
    local absSize = trackBg.AbsoluteSize
    local pct     = math.clamp((inp.Position.X - absPos.X) / absSize.X, 0, 1)
    circleRadius  = math.floor(MIN_RADIUS + pct * (MAX_RADIUS - MIN_RADIUS))
    trackFill.Size     = UDim2.new(pct, 0, 1, 0)
    trackKnob.Position = UDim2.new(pct, -10, 0.5, -10)
    sliderLblTxt.Text  = "Circle size:  " .. circleRadius .. " px"
    refreshCrosshairGeometry()
end)

-- ─── Through walls toggle ─────────────────
makeSection("OPTIONS", 6)
local wallsHit, wallsBg, wallsKnob = makeToggleRow("Through walls", true, 7)

-- ─── Auto shoot toggle ────────────────────
makeSection("AUTO SHOOT", 8)
local shootHit, shootBg, shootKnob = makeToggleRow("Auto shoot", false, 9)

-- ═══════════════════════════════════════════
--                  LOGIC
-- ═══════════════════════════════════════════

local function clearHighlight()
    if currentHighlight then
        currentHighlight:Destroy()
        currentHighlight = nil
    end
end

local function applyHighlight(character)
    clearHighlight()
    if not character then return end
    local hl                  = Instance.new("Highlight")
    hl.FillColor              = Color3.fromRGB(255, 0, 0)
    hl.FillTransparency       = 0.15
    hl.OutlineColor           = Color3.fromRGB(255, 90, 90)
    hl.OutlineTransparency    = 0
    hl.DepthMode              = Enum.HighlightDepthMode.AlwaysOnTop
    hl.Parent                 = character
    currentHighlight          = hl

    -- Hell-glow pulse
    local function pulse()
        if not hl or not hl.Parent then return end
        TweenService:Create(hl, TweenInfo.new(0.22, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
            FillTransparency = 0.7
        }):Play()
        task.delay(0.22, function()
            if not hl or not hl.Parent then return end
            TweenService:Create(hl, TweenInfo.new(0.22, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
                FillTransparency = 0.0
            }):Play()
            task.delay(0.22, pulse)
        end)
    end
    pulse()
end

local function setStatus(target)
    if target then
        sDot.BackgroundColor3 = Color3.fromRGB(255, 55, 55)
        sLabel.Text           = "Locked: " .. target.Name
        sLabel.TextColor3     = Color3.fromRGB(255, 140, 140)
    else
        sDot.BackgroundColor3 = Color3.fromRGB(70, 65, 100)
        sLabel.Text           = "No target"
        sLabel.TextColor3     = Color3.fromRGB(130, 125, 160)
    end
end

-- Line of sight check via raycast
local function hasLOS(targetChar)
    local hrp = targetChar:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end
    local origin = camera.CFrame.Position
    local dir    = hrp.Position - origin
    local params = RaycastParams.new()
    params.FilterType                  = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances  = {player.Character, targetChar}
    local result = workspace:Raycast(origin, dir, params)
    return result == nil   -- nil = nothing blocking = clear LOS
end

-- Find closest player whose HumanoidRootPart projects inside the circle
local function getTargetInCircle()
    if not player.Character or not player.Character:FindFirstChild("HumanoidRootPart") then
        return nil
    end
    local vp     = camera.ViewportSize
    local center = Vector2.new(vp.X / 2, vp.Y / 2)
    local closest, closestDist = nil, math.huge

    for _, target in pairs(Players:GetPlayers()) do
        if target == player then continue end
        local char = target.Character
        if not char then continue end
        local hrp  = char:FindFirstChild("HumanoidRootPart")
        local hum  = char:FindFirstChildOfClass("Humanoid")
        if not hrp or not hum or hum.Health <= 0 then continue end

        -- Wall check
        if not throughWalls and not hasLOS(char) then continue end

        local screenPos, onScreen = camera:WorldToViewportPoint(hrp.Position)
        if onScreen and screenPos.Z > 0 then
            local dist2D = (Vector2.new(screenPos.X, screenPos.Y) - center).Magnitude
            if dist2D <= circleRadius and dist2D < closestDist then
                closestDist = dist2D
                closest     = target
            end
        end
    end
    return closest
end

local function aimAt(target)
    local hrp = target and target.Character and target.Character:FindFirstChild("HumanoidRootPart")
    if hrp then
        camera.CFrame = CFrame.new(camera.CFrame.Position, hrp.Position)
    end
end

-- Auto shoot: activate equipped tool (no VirtualInputManager = no mobile layout break)
local function doShoot()
    if not player.Character then return end
    local tool = player.Character:FindFirstChildOfClass("Tool")
    if tool then
        tool:Activate()
    end
end

-- ═══════════════════════════════════════════
--            TOGGLE CONNECTIONS
-- ═══════════════════════════════════════════

aimbotHit.MouseButton1Click:Connect(function()
    aimbotEnabled = not aimbotEnabled
    setToggleVisual(aimbotBg, aimbotKnob, aimbotEnabled)
    setCrosshairVisible(aimbotEnabled)

    -- Slide slider row open or closed
    local targetH  = aimbotEnabled and 54 or 0
    local targetPH = aimbotEnabled and PANEL_SLIDER_H or PANEL_BASE_H
    TweenService:Create(sliderRow, tweenInfo, { Size = UDim2.new(1, 0, 0, targetH) }):Play()
    TweenService:Create(panel, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {
        Size = UDim2.new(0, 275, 0, targetPH)
    }):Play()

    if not aimbotEnabled then
        clearHighlight()
        currentTarget = nil
        setStatus(nil)
        setCrosshairColor(false)
    end
end)

wallsHit.MouseButton1Click:Connect(function()
    throughWalls = not throughWalls
    setToggleVisual(wallsBg, wallsKnob, throughWalls)
end)

shootHit.MouseButton1Click:Connect(function()
    autoShootEnabled = not autoShootEnabled
    setToggleVisual(shootBg, shootKnob, autoShootEnabled)
end)

mBtn.MouseButton1Click:Connect(function()
    guiVisible = not guiVisible
    panel.Visible = guiVisible
    TweenService:Create(mBtn, tweenInfo, {
        BackgroundColor3 = guiVisible
            and Color3.fromRGB(28, 26, 50)
            or  Color3.fromRGB(90, 75, 220)
    }):Play()
end)

UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.KeyCode == Enum.KeyCode.M then
        mBtn.MouseButton1Click:Fire()
    end
end)

-- ═══════════════════════════════════════════
--               RENDER LOOP
-- ═══════════════════════════════════════════

RunService.RenderStepped:Connect(function()
    if not aimbotEnabled then return end

    local target = getTargetInCircle()

    -- Update highlight only when target changes
    if target ~= currentTarget then
        currentTarget = target
        if target then
            applyHighlight(target.Character)
        else
            clearHighlight()
        end
        setStatus(target)
        setCrosshairColor(target ~= nil)
    end

    -- Clean up if target died or left mid-frame
    if currentTarget then
        local char = currentTarget.Character
        local hum  = char and char:FindFirstChildOfClass("Humanoid")
        if not char
            or not char:FindFirstChild("HumanoidRootPart")
            or (hum and hum.Health <= 0) then
            clearHighlight()
            currentTarget = nil
            setStatus(nil)
            setCrosshairColor(false)
        end
    end

    -- Aim
    if currentTarget then
        aimAt(currentTarget)
    end

    -- Auto shoot
    if autoShootEnabled and currentTarget then
        local now = tick()
        if (now - lastShot) >= SHOOT_DELAY then
            doShoot()
            lastShot = now
        end
    end
end)
