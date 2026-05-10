-- ============================================================
-- LAMBORGHINI HURACÁN FORMATION SCRIPT — ENHANCED v2
-- Chat commands: !lambo | ?open | ?left | ?right | ?sit | ?unsit | ?close
-- New: door animation, sit/noclip system, block counter + progress bar,
--      commands cheat-sheet panel, GUI door & seat buttons
-- ============================================================

local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local TweenService     = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
if not player then player = Players.PlayerAdded:Wait() end

if not player.Character or not player.Character:FindFirstChild("HumanoidRootPart") then
    player.CharacterAdded:Wait()
    task.wait(0.5)
end

-- ============================================================
-- CONSTANTS & COLORS
-- ============================================================
local LAMBO_YELLOW = Color3.fromRGB(255, 195, 0)
local LAMBO_DARK   = Color3.fromRGB(15,  15,  15)
local LAMBO_CHROME = Color3.fromRGB(200, 200, 210)
local LAMBO_RED    = Color3.fromRGB(255, 30,  30)
local LAMBO_ORANGE = Color3.fromRGB(255, 100, 0)
local LAMBO_GLASS  = Color3.fromRGB(80,  140, 200)

-- ============================================================
-- STATE
-- ============================================================
local controlled   = {}   -- [part] = { bp, bg, origAnch, origCC, origMassless, origPhysProps }
local partCount    = 0
local lamboSlots   = {}
local isActive     = false
local scriptAlive  = true
local heartConn    = nil
local doorState    = "closed"  -- "closed" | "both" | "left" | "right"
local isSeated     = false
local noclipConn   = nil

-- ============================================================
-- BUILD LAMBORGHINI HURACÁN POSITIONS
-- Z = front(-) / rear(+)   X = left(-) / right(+)   Y = height
-- ============================================================
local function buildLamboPositions()
    local p = {}
    local function add(x, y, z) table.insert(p, Vector3.new(x, y, z)) end

    -- FRONT SPLITTER
    for xi = -8, 8, 2 do add(xi, 0, -14); add(xi, 0, -13) end
    add(-9, 0, -13); add(9, 0, -13)

    -- FRONT BUMPER LOWER
    for xi = -8, 8, 2 do add(xi, 1, -12); add(xi, 2, -12) end
    add(-9, 1, -12); add(-9, 2, -12); add(9, 1, -12); add(9, 2, -12)
    for xi = -6, 6, 2 do add(xi, 3, -12) end
    add(-8, 2, -11); add(-8, 3, -11); add(-7, 2, -11); add(-7, 3, -11)
    add( 8, 2, -11); add( 8, 3, -11); add( 7, 2, -11); add( 7, 3, -11)

    -- ANGULAR HEADLIGHTS
    add(-9, 2, -11); add(-9, 3, -10); add(-8, 4, -9); add(-7, 4, -8); add(-6, 4, -8)
    add(-9, 3, -11); add(-8, 3, -10); add(-7, 4, -9)
    add(-8, 5, -10); add(-7, 5, -9); add(-6, 5, -8); add(-5, 5, -8)
    add( 9, 2, -11); add( 9, 3, -10); add( 8, 4, -9); add( 7, 4, -8); add( 6, 4, -8)
    add( 9, 3, -11); add( 8, 3, -10); add( 7, 4, -9)
    add( 8, 5, -10); add( 7, 5, -9); add( 6, 5, -8); add( 5, 5, -8)

    -- HOOD (wedge, rises from front to windshield base)
    local hoodRows = {
        { z = -11, y = 3, hw = 6 }, { z = -9, y = 3, hw = 6 },
        { z = -7,  y = 4, hw = 5 }, { z = -5, y = 4, hw = 5 },
        { z = -3,  y = 5, hw = 4 },
    }
    for _, row in ipairs(hoodRows) do
        for xi = -row.hw, row.hw, 2 do add(xi, row.y, row.z) end
        add(-(row.hw + 1), row.y, row.z); add(row.hw + 1, row.y, row.z)
    end
    add(0, 4, -10); add(0, 4, -8); add(0, 5, -6); add(0, 5, -4)
    add(-2, 4, -8); add(2, 4, -8); add(-2, 5, -5); add(2, 5, -5)

    -- WINDSHIELD (steeply raked ~40°)
    local wsFace = {
        { z = -2, y = 5 }, { z = -1, y = 6 },
        { z =  0, y = 7 }, { z =  1, y = 8 },
    }
    for _, row in ipairs(wsFace) do
        for xi = -4, 4, 2 do add(xi, row.y, row.z) end
        add(-5, row.y, row.z); add(5, row.y, row.z)
        add(-6, row.y, row.z); add(6, row.y, row.z)
    end

    -- ROOF (very short, super low)
    for zi = 2, 5, 1 do
        for xi = -4, 4, 2 do add(xi, 9, zi) end
        add(-5, 9, zi); add(5, 9, zi)
    end

    -- REAR WINDSHIELD
    local rwsFace = {
        { z = 5, y = 9 }, { z = 6, y = 8 }, { z = 7, y = 7 },
    }
    for _, row in ipairs(rwsFace) do
        for xi = -4, 4, 2 do add(xi, row.y, row.z) end
        add(-5, row.y, row.z); add(5, row.y, row.z)
    end

    -- DOOR PANELS (flat sides with character lines)
    for zi = -4, 5, 3 do
        for yi = 2, 7 do
            add(-7, yi, zi); add(7, yi, zi)
        end
    end
    -- Sill / rocker panel
    for zi = -8, 6, 3 do
        add(-7, 1, zi); add(-8, 1, zi)
        add( 7, 1, zi); add( 8, 1, zi)
    end
    -- Door upper feature line
    for zi = -5, 5, 3 do
        add(-8, 5, zi); add(8, 5, zi)
    end

    -- REAR ENGINE INTAKES (NACA scoops behind doors)
    for yi = 3, 7, 2 do
        for zi = 4, 9, 2 do
            add(-9, yi, zi); add(9, yi, zi)
        end
    end
    for yi = 4, 6, 2 do
        add(-10, yi, 5); add(-10, yi, 7); add(-10, yi, 9)
        add( 10, yi, 5); add( 10, yi, 7); add( 10, yi, 9)
    end

    -- REAR HAUNCHES (wide flared fenders)
    for yi = 2, 6, 2 do
        for zi = 8, 12, 2 do
            add(-10, yi, zi); add(-11, yi, zi)
            add( 10, yi, zi); add( 11, yi, zi)
        end
    end
    for zi = 8, 12, 2 do
        add(-9, 7, zi); add(9, 7, zi)
        add(-10, 6, zi); add(10, 6, zi)
    end

    -- REAR DECK / ENGINE COVER
    for zi = 7, 11, 2 do
        for xi = -6, 6, 2 do
            add(xi, 5, zi); add(xi, 6, zi)
        end
    end
    for zi = 8, 11, 2 do
        for xi = -4, 4, 2 do add(xi, 7, zi) end
    end
    add(-2, 8, 9); add(0, 8, 9); add(2, 8, 9)
    add(-2, 8,10); add(0, 8,10); add(2, 8,10)

    -- TAILLIGHTS (full-width light bar)
    for xi = -9, 9, 2 do
        add(xi, 6, 12); add(xi, 7, 12); add(xi, 8, 12)
    end
    for yi = 5, 8 do
        add(-10, yi, 12); add(-11, yi, 11)
        add( 10, yi, 12); add( 11, yi, 11)
    end
    add(-3, 9, 12); add(-1, 9, 12); add(1, 9, 12); add(3, 9, 12)

    -- REAR BUMPER + DIFFUSER
    for xi = -9, 9, 2 do
        add(xi, 4, 12); add(xi, 3, 12)
        add(xi, 2, 13); add(xi, 1, 13); add(xi, 0, 13)
    end
    for zi = 12, 15 do
        add(-6, 0, zi); add(-3, 0, zi); add(0, 0, zi); add(3, 0, zi); add(6, 0, zi)
    end
    for zi = 12, 14 do
        add(-8, 0, zi); add(-8, 1, zi)
        add( 8, 0, zi); add( 8, 1, zi)
    end

    -- QUAD EXHAUST PIPES
    add(-4, 2, 13); add(-2, 2, 13); add(2, 2, 13); add(4, 2, 13)
    add(-4, 1, 14); add(-2, 1, 14); add(2, 1, 14); add(4, 1, 14)
    for _, ex in ipairs({ -4, -2, 2, 4 }) do
        add(ex - 1, 2, 14); add(ex + 1, 2, 14)
        add(ex,     3, 14); add(ex,     1, 14)
    end

    -- REAR WING (active aero spoiler)
    for xi = -11, 11, 2 do
        add(xi, 11, 10); add(xi, 12, 10)
        add(xi, 11,  9); add(xi, 11, 11)
    end
    for yi = 8, 11 do
        add(-7, yi, 10); add(7, yi, 10)
        add(-6, yi, 10); add(6, yi, 10)
    end
    for zi = 9, 12 do
        add(-11, 10, zi); add(-11, 11, zi)
        add( 11, 10, zi); add( 11, 11, zi)
    end
    for xi = -11, 11, 2 do add(xi, 13, 10) end

    -- WHEELS (4 large 5-spoke rims)
    local function addWheel(cx, cz, outerR, innerR)
        for a = 0, math.pi * 2 - 0.01, math.pi / 5 do
            local ry = math.round(math.sin(a) * outerR)
            local rz = math.round(math.cos(a) * outerR)
            add(cx, 3 + ry, cz + rz)
        end
        for a = 0, math.pi * 2 - 0.01, math.pi / 6 do
            local ry = math.round(math.sin(a) * (outerR - 1))
            local rz = math.round(math.cos(a) * (outerR - 1))
            add(cx, 3 + ry, cz + rz)
        end
        for sp = 0, 4 do
            local a = sp * math.pi * 2 / 5
            for r = 1, innerR + 1 do
                local ry = math.round(math.sin(a) * r)
                local rz = math.round(math.cos(a) * r)
                add(cx, 3 + ry, cz + rz)
            end
        end
        add(cx, 3, cz); add(cx, 4, cz); add(cx, 2, cz)
    end
    addWheel(-10, -8, 3, 2); addWheel( 10, -8, 3, 2)
    addWheel(-11,  9, 3, 2); addWheel( 11,  9, 3, 2)

    -- WHEEL ARCHES
    local function addArch(cx, cz, archR)
        for a = math.pi, 0, -math.pi / 8 do
            local ry = math.round(math.sin(a) * archR)
            local rz = math.round(math.cos(a) * archR)
            add(cx, 3 + ry, cz + rz)
        end
    end
    addArch(-9, -8, 4); addArch( 9, -8, 4)
    addArch(-10, 9, 5); addArch( 10, 9, 5)

    -- UNDERBODY / FLOOR PAN
    for xi = -6, 6, 3 do
        for zi = -11, 11, 3 do add(xi, 0, zi) end
    end

    return p
end

-- ============================================================
-- DOOR SLOT DETECTION
-- Door panels are at |X| ≈ 7-8, Y 1-7, Z -5 to 6
-- ============================================================
local function isDoorSlot(slot)
    local ax = math.abs(slot.X)
    return ax >= 7 and ax <= 8
       and slot.Y >= 1 and slot.Y <= 7
       and slot.Z >= -5 and slot.Z <= 6
end

local function shouldOpenSlot(slot)
    if doorState == "closed" then return false end
    if not isDoorSlot(slot) then return false end
    if doorState == "both" then return true end
    if doorState == "left"  then return slot.X < 0 end
    if doorState == "right" then return slot.X > 0 end
    return false
end

-- Scissor-door open offset: hinge at front-bottom, swings up
local function getDoorOpenSlot(slot)
    local sign    = slot.X < 0 and -1 or 1
    -- Normalize along door height (0 = bottom, 1 = top)
    local ty      = math.clamp((slot.Y - 1) / 6, 0, 1)
    -- Normalize along door length (0 = front, 1 = rear)
    local tz      = math.clamp((slot.Z - (-5)) / 11, 0, 1)
    -- Swing blocks up and slightly outward; rear/top swing most
    local dX = sign * (1 + ty * 2)
    local dY = 4 + ty * 4 + tz * 1
    local dZ = -1 - tz * 2
    return slot + Vector3.new(dX, dY, dZ)
end

-- ============================================================
-- PART GRAB / RELEASE
-- ============================================================
local function grabPart(part)
    if controlled[part] then return end
    if not part or not part.Parent then return end
    if not part:IsA("BasePart") then return end
    if part.Size.Magnitude < 0.2 then return end
    if part.Transparency >= 1 then return end
    if part.Name == "Baseplate" then return end
    local p = part.Parent
    while p and p ~= workspace do
        if p:FindFirstChildOfClass("Humanoid") then return end
        p = p.Parent
    end

    local origAnch      = part.Anchored
    local origCC        = part.CanCollide
    local origMassless  = part.Massless
    local origPhysProps = part.CustomPhysicalProperties

    pcall(function() part.Anchored   = false end)
    pcall(function() part.CanCollide = false end)
    pcall(function() part:SetNetworkOwner(player) end)
    pcall(function()
        part.CustomPhysicalProperties = PhysicalProperties.new(0.01, 0.3, 0.5, 1, 1)
        part.Massless = true
    end)

    local bp = Instance.new("BodyPosition")
    bp.MaxForce = Vector3.new(1e9, 1e9, 1e9)
    bp.P = 300000; bp.D = 8000
    bp.Position = part.Position; bp.Parent = part

    local bg = Instance.new("BodyGyro")
    bg.MaxTorque = Vector3.new(1e9, 1e9, 1e9)
    bg.P = 300000; bg.D = 8000
    bg.CFrame = part.CFrame; bg.Parent = part

    controlled[part] = {
        bp = bp, bg = bg,
        origAnch = origAnch, origCC = origCC,
        origMassless = origMassless, origPhysProps = origPhysProps,
        origColor = part.Color, origMaterial = part.Material,
    }
    partCount = partCount + 1
end

local function releasePart(part, data)
    pcall(function()
        if data.bp and data.bp.Parent then data.bp:Destroy() end
        if data.bg and data.bg.Parent then data.bg:Destroy() end
    end)
    if part and part.Parent then
        pcall(function()
            part.Anchored   = data.origAnch     or false
            part.CanCollide = data.origCC        or true
            part.Massless   = data.origMassless  or false
            if data.origPhysProps then part.CustomPhysicalProperties = data.origPhysProps end
            if data.origColor     then part.Color    = data.origColor    end
            if data.origMaterial  then part.Material = data.origMaterial end
        end)
    end
end

local function releaseAll()
    for part, data in pairs(controlled) do releasePart(part, data) end
    controlled = {}; partCount = 0
end

local function sweepMap()
    for _, obj in ipairs(workspace:GetDescendants()) do
        if not controlled[obj] and obj and obj.Parent
           and obj:IsA("BasePart")
           and obj.Size.Magnitude >= 0.2
           and obj.Transparency < 1
           and obj.Name ~= "Baseplate" then
            local isChar = false
            local p = obj.Parent
            while p and p ~= workspace do
                if p:FindFirstChildOfClass("Humanoid") then isChar = true; break end
                p = p.Parent
            end
            if not isChar then grabPart(obj) end
        end
    end
end

-- ============================================================
-- COLOR SYSTEM
-- ============================================================
local function getLamboColor(slot)
    local y, z = slot.Y, slot.Z
    if z >= 11 and y >= 5 then return LAMBO_RED,    Enum.Material.Neon         end
    if z <= -8 and y >= 4 then return LAMBO_ORANGE, Enum.Material.Neon         end
    if (z >= -2 and z <= 5) and y >= 5 then return LAMBO_GLASS, Enum.Material.Glass end
    if z >= 8 and y >= 7 then return LAMBO_GLASS,  Enum.Material.Glass         end
    if z >= 13 and y <= 2 then return LAMBO_CHROME, Enum.Material.Metal        end
    if y >= 10 then return LAMBO_DARK, Enum.Material.SmoothPlastic             end
    if y <= 0  then return LAMBO_DARK, Enum.Material.SmoothPlastic             end
    return LAMBO_YELLOW, Enum.Material.SmoothPlastic
end

local function applyLamboColors(partList)
    for i, part in ipairs(partList) do
        if part and part.Parent and i <= #lamboSlots then
            local col, mat = getLamboColor(lamboSlots[i])
            pcall(function()
                part.Color    = col
                part.Material = mat
            end)
        end
    end
end

-- ============================================================
-- NOCLIP / SIT SYSTEM
-- ============================================================
local function setCharNoclip(enable)
    local char = player.Character
    if not char then return end
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") then
            pcall(function() part.CanCollide = not enable end)
        end
    end
end

local function doSit()
    if not isActive then
        print("[LamboScript] Activate the lambo first with !lambo"); return
    end
    isSeated = true
    setCharNoclip(true)

    -- Keep noclip persistent while seated (Roblox may reset CanCollide each frame)
    if noclipConn then noclipConn:Disconnect() end
    noclipConn = RunService.Heartbeat:Connect(function()
        if not isSeated then
            if noclipConn then noclipConn:Disconnect(); noclipConn = nil end
            return
        end
        setCharNoclip(true)
    end)

    -- Nudge player to driver seat position (local -5, 2, 0 from HRP = inside left cabin)
    local char = player.Character
    if char then
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if hrp then
            -- Compute car frame and seat world position
            local carCF  = hrp.CFrame * CFrame.new(0, -3, 0)
            local seatWP = carCF:PointToWorldSpace(Vector3.new(-4, 4, 0))
            hrp.CFrame   = CFrame.new(seatWP, seatWP + hrp.CFrame.LookVector)
        end
    end

    print("[LamboScript] ?sit → Noclipped & seated. Walk to drive the Lambo! Use ?unsit to exit.")
end

local function doUnsit()
    isSeated = false
    if noclipConn then noclipConn:Disconnect(); noclipConn = nil end
    setCharNoclip(false)

    -- Teleport player to left side of the car
    local char = player.Character
    if char then
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if hrp then
            local carCF  = hrp.CFrame * CFrame.new(0, -3, 0)
            local exitWP = carCF:PointToWorldSpace(Vector3.new(-16, 4, 0))
            hrp.CFrame   = CFrame.new(exitWP, exitWP + hrp.CFrame.LookVector)
        end
    end

    print("[LamboScript] ?unsit → Clip restored. You exited the car!")
end

-- ============================================================
-- MAIN FORMATION LOOP  (door offsets applied here)
-- ============================================================
local function startFormation()
    if heartConn then heartConn:Disconnect() end

    heartConn = RunService.Heartbeat:Connect(function()
        if not scriptAlive or not isActive then return end
        local char = player.Character
        if not char then return end
        local hrp = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso")
        if not hrp then return end

        local carCF    = hrp.CFrame * CFrame.new(0, -3, 0)
        local partList = {}
        for part, _ in pairs(controlled) do
            if part and part.Parent then table.insert(partList, part) end
        end

        local slotCount = #lamboSlots

        for i, part in ipairs(partList) do
            local data = controlled[part]
            if data and data.bp and data.bp.Parent then
                if i <= slotCount then
                    local slot = lamboSlots[i]

                    -- Apply door offset if this slot should be open
                    local targetSlot = shouldOpenSlot(slot)
                        and getDoorOpenSlot(slot)
                        or  slot

                    local worldPos = carCF:PointToWorldSpace(targetSlot)
                    data.bp.Position = worldPos
                    data.bg.CFrame   = CFrame.new(worldPos) * (carCF - carCF.Position)
                else
                    -- Extra blocks: orbit above the car
                    local extra = i - slotCount
                    local angle = (extra / 10) * math.pi * 2 + tick()
                    data.bp.Position = hrp.Position + Vector3.new(
                        math.cos(angle) * (14 + extra * 0.3),
                        10 + extra * 0.4,
                        math.sin(angle) * (14 + extra * 0.3)
                    )
                end
            end
        end
    end)
end

-- ============================================================
-- COMMAND HANDLER  (used by chat listener AND GUI buttons)
-- ============================================================
local function handleCommand(raw)
    local cmd = raw:lower():match("^%s*(.-)%s*$")

    if cmd == "!lambo" then
        if not isActive then
            sweepMap(); isActive = true; startFormation()
            task.wait(0.5)
            local pl = {}
            for part, _ in pairs(controlled) do table.insert(pl, part) end
            applyLamboColors(pl)
            print("[LamboScript] !lambo → Formation activated!")
        else
            print("[LamboScript] Already active!")
        end

    elseif cmd == "?open" then
        doorState = "both"
        print("[LamboScript] ?open → Both scissor doors OPEN!")

    elseif cmd == "?left" then
        doorState = "left"
        print("[LamboScript] ?left → Left door OPEN!")

    elseif cmd == "?right" then
        doorState = "right"
        print("[LamboScript] ?right → Right door OPEN!")

    elseif cmd == "?close" then
        doorState = "closed"
        print("[LamboScript] ?close → Doors CLOSED!")

    elseif cmd == "?sit" then
        doSit()

    elseif cmd == "?unsit" then
        doUnsit()
    end
end

-- Chat listener
player.Chatted:Connect(handleCommand)

-- ============================================================
-- GUI — EXPANDED  (formation + doors + seat + commands panel)
-- ============================================================
local function createGUI()
    local pg  = player:FindFirstChildOfClass("PlayerGui")
    local old = pg:FindFirstChild("LamboGui")
    if old then old:Destroy() end

    local gui = Instance.new("ScreenGui")
    gui.Name          = "LamboGui"
    gui.ResetOnSpawn  = false
    gui.DisplayOrder  = 999
    gui.Parent        = pg

    -- ── Main panel ──────────────────────────────────────────
    local panel = Instance.new("Frame", gui)
    panel.Name             = "Panel"
    panel.Size             = UDim2.fromOffset(220, 560)
    panel.Position         = UDim2.new(0, 12, 0, 8)
    panel.BackgroundColor3 = Color3.fromRGB(8, 8, 12)
    panel.BorderSizePixel  = 0
    Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 10)

    -- Top accent bar
    local accent = Instance.new("Frame", panel)
    accent.Size             = UDim2.new(1, 0, 0, 4)
    accent.BackgroundColor3 = LAMBO_YELLOW
    accent.BorderSizePixel  = 0
    Instance.new("UICorner", accent).CornerRadius = UDim.new(0, 10)

    -- Title
    local title = Instance.new("TextLabel", panel)
    title.Size               = UDim2.new(1, -36, 0, 26)
    title.Position           = UDim2.fromOffset(8, 8)
    title.BackgroundTransparency = 1
    title.Text               = "🚗  LAMBORGHINI"
    title.TextColor3         = LAMBO_YELLOW
    title.TextSize           = 12; title.Font = Enum.Font.GothamBold
    title.TextXAlignment     = Enum.TextXAlignment.Left

    local sub = Instance.new("TextLabel", panel)
    sub.Size               = UDim2.new(1, -12, 0, 14)
    sub.Position           = UDim2.fromOffset(8, 28)
    sub.BackgroundTransparency = 1
    sub.Text               = "HURACÁN BLOCK FORMATION v2"
    sub.TextColor3         = Color3.fromRGB(90, 90, 90)
    sub.TextSize           = 7; sub.Font = Enum.Font.Gotham
    sub.TextXAlignment     = Enum.TextXAlignment.Left

    -- ── Status / counters ───────────────────────────────────
    local function makeDivLine(y)
        local d = Instance.new("Frame", panel)
        d.Size             = UDim2.new(1, -12, 0, 1)
        d.Position         = UDim2.fromOffset(6, y)
        d.BackgroundColor3 = Color3.fromRGB(28, 28, 38)
        d.BorderSizePixel  = 0
    end
    makeDivLine(46)

    local status = Instance.new("TextLabel", panel)
    status.Size               = UDim2.new(1, -12, 0, 16)
    status.Position           = UDim2.fromOffset(8, 50)
    status.BackgroundTransparency = 1
    status.Text               = "STATUS: IDLE"
    status.TextColor3         = Color3.fromRGB(80, 80, 90)
    status.TextSize           = 8; status.Font = Enum.Font.GothamBold
    status.TextXAlignment     = Enum.TextXAlignment.Left

    -- Block counter
    local partsLbl = Instance.new("TextLabel", panel)
    partsLbl.Size               = UDim2.new(1, -12, 0, 13)
    partsLbl.Position           = UDim2.fromOffset(8, 68)
    partsLbl.BackgroundTransparency = 1
    partsLbl.Text               = "BLOCKS: 0 / 0"
    partsLbl.TextColor3         = Color3.fromRGB(60, 60, 70)
    partsLbl.TextSize           = 7; partsLbl.Font = Enum.Font.Gotham
    partsLbl.TextXAlignment     = Enum.TextXAlignment.Left

    -- Progress bar
    local barBg = Instance.new("Frame", panel)
    barBg.Size             = UDim2.new(1, -12, 0, 6)
    barBg.Position         = UDim2.fromOffset(6, 83)
    barBg.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
    barBg.BorderSizePixel  = 0
    Instance.new("UICorner", barBg).CornerRadius = UDim.new(0, 3)

    local barFill = Instance.new("Frame", barBg)
    barFill.Size             = UDim2.fromScale(0, 1)
    barFill.BackgroundColor3 = LAMBO_YELLOW
    barFill.BorderSizePixel  = 0
    Instance.new("UICorner", barFill).CornerRadius = UDim.new(0, 3)

    -- Door & seat state labels
    local doorLbl = Instance.new("TextLabel", panel)
    doorLbl.Size               = UDim2.new(0.5, -8, 0, 13)
    doorLbl.Position           = UDim2.fromOffset(8, 93)
    doorLbl.BackgroundTransparency = 1
    doorLbl.Text               = "DOORS: CLOSED"
    doorLbl.TextColor3         = Color3.fromRGB(60, 60, 70)
    doorLbl.TextSize           = 7; doorLbl.Font = Enum.Font.Gotham
    doorLbl.TextXAlignment     = Enum.TextXAlignment.Left

    local seatLbl = Instance.new("TextLabel", panel)
    seatLbl.Size               = UDim2.new(0.5, -4, 0, 13)
    seatLbl.Position           = UDim2.new(0.5, -2, 0, 93)
    seatLbl.BackgroundTransparency = 1
    seatLbl.Text               = "SEAT: EMPTY"
    seatLbl.TextColor3         = Color3.fromRGB(60, 60, 70)
    seatLbl.TextSize           = 7; seatLbl.Font = Enum.Font.Gotham
    seatLbl.TextXAlignment     = Enum.TextXAlignment.Left

    -- Live update loop
    task.spawn(function()
        while gui.Parent and scriptAlive do
            -- Status
            status.Text       = isActive and "STATUS: 🟡 ACTIVE" or "STATUS: IDLE"
            status.TextColor3 = isActive and LAMBO_YELLOW or Color3.fromRGB(80, 80, 90)

            -- Block counter + bar
            local slots   = #lamboSlots
            local used    = math.min(partCount, slots)
            local pct     = slots > 0 and (used / slots) or 0
            partsLbl.Text = "BLOCKS: " .. used .. " / " .. slots
                          .. "  (" .. math.floor(pct * 100) .. "%)"
            barFill.Size  = UDim2.fromScale(pct, 1)
            barFill.BackgroundColor3 = pct >= 1 and Color3.fromRGB(80,255,80)
                                    or pct >= 0.5 and LAMBO_YELLOW
                                    or Color3.fromRGB(255,100,40)

            -- Doors
            local dTxt = (doorState == "closed") and "🔒 CLOSED"
                      or (doorState == "both")   and "🟡 BOTH OPEN"
                      or (doorState == "left")   and "🟡 LEFT OPEN"
                      or                              "🟡 RIGHT OPEN"
            doorLbl.Text       = "DOORS: " .. dTxt
            doorLbl.TextColor3 = (doorState ~= "closed") and LAMBO_YELLOW or Color3.fromRGB(60,60,70)

            -- Seat
            seatLbl.Text       = isSeated and "SEAT: 🟢 IN" or "SEAT: EMPTY"
            seatLbl.TextColor3 = isSeated and Color3.fromRGB(60,230,100) or Color3.fromRGB(60,60,70)

            task.wait(0.4)
        end
    end)

    makeDivLine(110)

    -- ── Button helpers ──────────────────────────────────────
    local btnY = 116

    local function makeBtn(label, bgCol, txCol, cb, btnH)
        btnH = btnH or 26
        local b = Instance.new("TextButton", panel)
        b.Size             = UDim2.new(1, -12, 0, btnH)
        b.Position         = UDim2.fromOffset(6, btnY)
        b.BackgroundColor3 = bgCol
        b.TextColor3       = txCol
        b.Text             = label
        b.TextSize         = 9; b.Font = Enum.Font.GothamBold
        b.BorderSizePixel  = 0
        Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
        b.MouseButton1Click:Connect(cb)
        btnY = btnY + btnH + 4
        return b
    end

    local function makeHalfBtnPair(lLbl, lBg, lTx, lCb, rLbl, rBg, rTx, rCb)
        local halfW = 101
        local function mkHalf(lbl, bg, tx, cb, xOff)
            local b = Instance.new("TextButton", panel)
            b.Size             = UDim2.fromOffset(halfW, 26)
            b.Position         = UDim2.fromOffset(xOff, btnY)
            b.BackgroundColor3 = bg; b.TextColor3 = tx
            b.Text             = lbl; b.TextSize = 8
            b.Font             = Enum.Font.GothamBold
            b.BorderSizePixel  = 0
            Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
            b.MouseButton1Click:Connect(cb)
        end
        mkHalf(lLbl, lBg, lTx, lCb, 6)
        mkHalf(rLbl, rBg, rTx, rCb, 6 + halfW + 6)
        btnY = btnY + 30
    end

    local function makeSectionHead(text)
        local lbl = Instance.new("TextLabel", panel)
        lbl.Size               = UDim2.new(1, -12, 0, 14)
        lbl.Position           = UDim2.fromOffset(8, btnY)
        lbl.BackgroundTransparency = 1
        lbl.Text               = text
        lbl.TextColor3         = Color3.fromRGB(100, 100, 130)
        lbl.TextSize           = 7; lbl.Font = Enum.Font.GothamBold
        lbl.TextXAlignment     = Enum.TextXAlignment.Left
        btnY = btnY + 16
    end

    -- ── FORMATION section ────────────────────────────────────
    makeSectionHead("── FORMATION ──")
    makeBtn("🔍  SCAN BLOCKS",        Color3.fromRGB(16,40,16),  Color3.fromRGB(80,255,100), function() sweepMap() end)
    makeBtn("▶  ACTIVATE LAMBO",      Color3.fromRGB(50,38,0),   LAMBO_YELLOW, function()
        if not isActive then
            sweepMap(); isActive = true; startFormation()
            task.wait(0.5)
            local pl = {}
            for part, _ in pairs(controlled) do table.insert(pl, part) end
            applyLamboColors(pl)
        end
    end)
    makeBtn("⏹  DEACTIVATE",         Color3.fromRGB(50,10,10),  Color3.fromRGB(255,70,70), function()
        isActive = false
        if heartConn then heartConn:Disconnect(); heartConn = nil end
        releaseAll()
    end)
    makeBtn("🔄  RESCAN + RECOLOR",   Color3.fromRGB(10,20,40),  Color3.fromRGB(80,160,255), function()
        sweepMap()
        local pl = {}
        for part, _ in pairs(controlled) do table.insert(pl, part) end
        applyLamboColors(pl)
    end)

    -- ── DOORS section ────────────────────────────────────────
    btnY = btnY + 4; makeDivLine(btnY); btnY = btnY + 8
    makeSectionHead("── DOORS ──")

    makeHalfBtnPair(
        "🚪 LEFT",   Color3.fromRGB(35,30,5), LAMBO_YELLOW, function() doorState = "left"  end,
        "RIGHT 🚪",  Color3.fromRGB(35,30,5), LAMBO_YELLOW, function() doorState = "right" end
    )
    makeBtn("🚪🚪  OPEN BOTH DOORS",  Color3.fromRGB(45,35,0),   LAMBO_YELLOW,              function() doorState = "both"   end)
    makeBtn("🔒  CLOSE ALL DOORS",    Color3.fromRGB(35,12,12),  Color3.fromRGB(220,80,80), function() doorState = "closed" end)

    -- ── SEAT section ─────────────────────────────────────────
    btnY = btnY + 4; makeDivLine(btnY); btnY = btnY + 8
    makeSectionHead("── DRIVER SEAT ──")

    makeHalfBtnPair(
        "🪑  SIT",   Color3.fromRGB(10,30,10), Color3.fromRGB(80,255,100), function() doSit()   end,
        "🚶  UNSIT", Color3.fromRGB(35,12,12), Color3.fromRGB(255,100,80), function() doUnsit() end
    )

    -- ── COMMANDS cheat-sheet ─────────────────────────────────
    btnY = btnY + 4; makeDivLine(btnY); btnY = btnY + 8
    makeSectionHead("── CHAT COMMANDS ──")

    local cmds = {
        { "!lambo",  "Activate block formation" },
        { "?open",   "Open both scissor doors"  },
        { "?left",   "Open left door only"      },
        { "?right",  "Open right door only"     },
        { "?close",  "Close all doors"          },
        { "?sit",    "Enter seat + noclip"      },
        { "?unsit",  "Exit car + re-clip"       },
    }
    for _, c in ipairs(cmds) do
        local row = Instance.new("Frame", panel)
        row.Size               = UDim2.new(1, -12, 0, 12)
        row.Position           = UDim2.fromOffset(6, btnY)
        row.BackgroundTransparency = 1

        local kLbl = Instance.new("TextLabel", row)
        kLbl.Size               = UDim2.fromOffset(56, 12)
        kLbl.BackgroundTransparency = 1
        kLbl.Text               = c[1]
        kLbl.TextColor3         = LAMBO_YELLOW
        kLbl.TextSize           = 7; kLbl.Font = Enum.Font.GothamBold
        kLbl.TextXAlignment     = Enum.TextXAlignment.Left

        local vLbl = Instance.new("TextLabel", row)
        vLbl.Size               = UDim2.new(1, -58, 1, 0)
        vLbl.Position           = UDim2.fromOffset(58, 0)
        vLbl.BackgroundTransparency = 1
        vLbl.Text               = c[2]
        vLbl.TextColor3         = Color3.fromRGB(130, 130, 150)
        vLbl.TextSize           = 6; vLbl.Font = Enum.Font.Gotham
        vLbl.TextXAlignment     = Enum.TextXAlignment.Left

        btnY = btnY + 13
    end

    -- ── Close / mini-icon ───────────────────────────────────
    local closeBtn = Instance.new("TextButton", panel)
    closeBtn.Size             = UDim2.fromOffset(20, 20)
    closeBtn.Position         = UDim2.new(1, -24, 0, 6)
    closeBtn.BackgroundColor3 = Color3.fromRGB(30, 10, 10)
    closeBtn.TextColor3       = Color3.fromRGB(200, 80, 80)
    closeBtn.Text             = "✕"; closeBtn.TextSize = 10
    closeBtn.Font             = Enum.Font.GothamBold
    closeBtn.BorderSizePixel  = 0
    Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 4)
    closeBtn.MouseButton1Click:Connect(function()
        gui:Destroy()
        local mini = Instance.new("ScreenGui")
        mini.Name = "LamboIcon"; mini.ResetOnSpawn = false
        mini.DisplayOrder = 999; mini.Parent = pg
        local ib = Instance.new("TextButton", mini)
        ib.Size             = UDim2.fromOffset(36, 36)
        ib.Position         = UDim2.new(0, 12, 0, 8)
        ib.BackgroundColor3 = Color3.fromRGB(8, 8, 12)
        ib.TextColor3       = LAMBO_YELLOW
        ib.Text             = "🚗"; ib.TextSize = 16
        ib.Font             = Enum.Font.GothamBold
        ib.BorderSizePixel  = 0
        Instance.new("UICorner", ib).CornerRadius = UDim.new(0, 8)
        ib.MouseButton1Click:Connect(function() mini:Destroy(); createGUI() end)
    end)

    -- ── Draggable panel ─────────────────────────────────────
    local dragging, dragStartM, dragStartPos = false, Vector2.zero, UDim2.new()
    panel.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1
        or inp.UserInputType == Enum.UserInputType.Touch then
            dragging     = true
            dragStartM   = Vector2.new(inp.Position.X, inp.Position.Y)
            dragStartPos = panel.Position
        end
    end)
    UserInputService.InputChanged:Connect(function(inp)
        if not dragging then return end
        if inp.UserInputType == Enum.UserInputType.MouseMovement
        or inp.UserInputType == Enum.UserInputType.Touch then
            local d = Vector2.new(inp.Position.X, inp.Position.Y) - dragStartM
            panel.Position = UDim2.new(
                dragStartPos.X.Scale, dragStartPos.X.Offset + d.X,
                dragStartPos.Y.Scale, dragStartPos.Y.Offset + d.Y
            )
        end
    end)
    UserInputService.InputEnded:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1
        or inp.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
end

-- ============================================================
-- INIT
-- ============================================================
lamboSlots = buildLamboPositions()
print("[LamboScript] Slots built: " .. #lamboSlots)

createGUI()

-- Periodic rescan while active
task.spawn(function()
    while scriptAlive do
        task.wait(4)
        if isActive then sweepMap() end
    end
end)

-- Reset seat/noclip on respawn
player.CharacterAdded:Connect(function()
    task.wait(0.5)
    isSeated = false
    if noclipConn then noclipConn:Disconnect(); noclipConn = nil end
    if isActive then sweepMap() end
end)

print("[LamboScript] Ready!")
print("[LamboScript] Chat:  !lambo | ?open | ?left | ?right | ?close | ?sit | ?unsit")
print("[LamboScript] Or use the GUI panel on the left side of the screen.")
