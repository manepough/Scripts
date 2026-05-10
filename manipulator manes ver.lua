-- ============================================================
-- LAMBORGHINI HURACÁN FORMATION SCRIPT  (Enhanced TCO Edition)
-- Chat Commands:
--   !lambo   → Build & activate the lambo
--   ?open    → Open both doors (scissor style)
--   ?left    → Toggle left door
--   ?right   → Toggle right door
--   ?close   → Close all doors
--   ?sit     → Sit in driver seat, noclip, walk to drive
--   ?unsit   → Exit car, go beside it, re-enable collision
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
-- CONSTANTS
-- ============================================================
local LAMBO_YELLOW = Color3.fromRGB(255, 195, 0)
local LAMBO_DARK   = Color3.fromRGB(15,  15,  15)
local LAMBO_CHROME = Color3.fromRGB(200, 200, 210)
local LAMBO_RED    = Color3.fromRGB(255, 30,  30)
local LAMBO_ORANGE = Color3.fromRGB(255, 100, 0)
local LAMBO_GLASS  = Color3.fromRGB(80,  140, 200)

-- Scissor door open offsets (car-local space: up + outward)
local DOOR_OPEN_LEFT  = Vector3.new(-6, 11, 0)
local DOOR_OPEN_RIGHT = Vector3.new( 6, 11, 0)
local DOOR_CLOSED     = Vector3.new( 0,  0, 0)

-- ============================================================
-- STATE
-- ============================================================
local controlled     = {}   -- [part] = { bp, bg, origAnch, origCC, origMassless, origPhysProps, origColor, origMaterial }
local partCount      = 0
local lamboSlots     = {}
local isActive       = false
local scriptAlive    = true
local heartConn      = nil
local isSitting      = false
local noclipConn     = nil

-- Door animation state
local doorOffsets    = {}   -- [slotIdx] = current Vector3 extra offset applied to that slot
local doorTargets    = {}   -- [slotIdx] = target  Vector3 the offset is lerping toward
local leftDoorSlots  = {}   -- [slotIdx] = true   for left door blocks
local rightDoorSlots = {}   -- [slotIdx] = true   for right door blocks
local leftDoorOpen   = false
local rightDoorOpen  = false

-- ============================================================
-- BUILD LAMBORGHINI HURACÁN POSITIONS
-- All offsets are relative to car center (player feet level)
-- Z = front(-) / rear(+)   X = left(-) / right(+)   Y = height
-- ============================================================
local function buildLamboPositions()
    local p = {}
    local function add(x, y, z) table.insert(p, Vector3.new(x, y, z)) end

    -- FRONT SPLITTER
    for xi = -8, 8, 2 do
        add(xi, 0, -14)
        add(xi, 0, -13)
    end
    add(-9, 0, -13); add(9, 0, -13)

    -- FRONT BUMPER LOWER
    for xi = -8, 8, 2 do add(xi, 1, -12); add(xi, 2, -12) end
    add(-9, 1, -12); add(-9, 2, -12); add(9, 1, -12); add(9, 2, -12)
    for xi = -6, 6, 2 do add(xi, 3, -12) end
    add(-8, 2, -11); add(-8, 3, -11); add(-7, 2, -11); add(-7, 3, -11)
    add( 8, 2, -11); add( 8, 3, -11); add( 7, 2, -11); add( 7, 3, -11)

    -- ANGULAR HEADLIGHTS (signature Lambo blades)
    add(-9, 2, -11); add(-9, 3, -10); add(-8, 4, -9); add(-7, 4, -8); add(-6, 4, -8)
    add(-9, 3, -11); add(-8, 3, -10); add(-7, 4, -9)
    add(-8, 5, -10); add(-7, 5, -9); add(-6, 5, -8); add(-5, 5, -8)
    add( 9, 2, -11); add( 9, 3, -10); add( 8, 4, -9); add( 7, 4, -8); add( 6, 4, -8)
    add( 9, 3, -11); add( 8, 3, -10); add( 7, 4, -9)
    add( 8, 5, -10); add( 7, 5, -9); add( 6, 5, -8); add( 5, 5, -8)

    -- HOOD (wedge rises front-to-rear)
    local hoodRows = {
        { z = -11, y = 3, hw = 6 }, { z = -9,  y = 3, hw = 6 },
        { z = -7,  y = 4, hw = 5 }, { z = -5,  y = 4, hw = 5 },
        { z = -3,  y = 5, hw = 4 },
    }
    for _, row in ipairs(hoodRows) do
        for xi = -row.hw, row.hw, 2 do add(xi, row.y, row.z) end
        add(-(row.hw + 1), row.y, row.z); add(row.hw + 1, row.y, row.z)
    end
    add(0, 4, -10); add(0, 4, -8); add(0, 5, -6); add(0, 5, -4)
    add(-2, 4, -8); add(2, 4, -8); add(-2, 5, -5); add(2, 5, -5)

    -- WINDSHIELD (~40° rake)
    local wsFace = {
        { z = -2, y = 5 }, { z = -1, y = 6 },
        { z =  0, y = 7 }, { z =  1, y = 8 },
    }
    for _, row in ipairs(wsFace) do
        for xi = -4, 4, 2 do add(xi, row.y, row.z) end
        add(-5, row.y, row.z); add(5, row.y, row.z)
        add(-6, row.y, row.z); add(6, row.y, row.z)
    end

    -- ROOF (short, super low)
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

    -- DOOR PANELS (x=±7, z=-4 to 5, y=2-7)
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
    -- Door upper feature line crease
    for zi = -5, 5, 3 do
        add(-8, 5, zi); add(8, 5, zi)
    end

    -- REAR ENGINE INTAKES
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
    end
    for xi = -11, 11, 2 do
        add(xi, 11,  9)
        add(xi, 11, 11)
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

    addWheel(-10, -8, 3, 2)
    addWheel( 10, -8, 3, 2)
    addWheel(-11,  9, 3, 2)
    addWheel( 11,  9, 3, 2)

    -- WHEEL ARCHES
    local function addArch(cx, cz, archR)
        for a = math.pi, 0, -math.pi / 8 do
            local ry = math.round(math.sin(a) * archR)
            local rz = math.round(math.cos(a) * archR)
            add(cx, 3 + ry, cz + rz)
        end
    end

    addArch(-9,  -8, 4)
    addArch( 9,  -8, 4)
    addArch(-10,  9, 5)
    addArch( 10,  9, 5)

    -- UNDERBODY / FLOOR PAN
    for xi = -6, 6, 3 do
        for zi = -11, 11, 3 do
            add(xi, 0, zi)
        end
    end

    return p
end

-- ============================================================
-- CLASSIFY DOOR SLOTS  (called right after lamboSlots is built)
-- Identifies which slot indices belong to left/right doors
-- ============================================================
local function classifyDoorSlots()
    leftDoorSlots  = {}
    rightDoorSlots = {}
    doorOffsets    = {}
    doorTargets    = {}

    for i, slot in ipairs(lamboSlots) do
        doorOffsets[i] = Vector3.zero
        doorTargets[i] = Vector3.zero

        local x, y, z = slot.X, slot.Y, slot.Z
        -- Left door: x=-7 or x=-8, z in door zone (-9 to 6), y in panel range (1-7)
        if (x == -7 or x == -8) and z >= -9 and z <= 6 and y >= 1 and y <= 7 then
            leftDoorSlots[i] = true
        end
        -- Right door: x=7 or x=8, z in door zone (-9 to 6), y in panel range (1-7)
        if (x == 7 or x == 8) and z >= -9 and z <= 6 and y >= 1 and y <= 7 then
            rightDoorSlots[i] = true
        end
    end
end

-- ============================================================
-- DOOR CONTROL
-- Sets target offsets for door blocks; heartbeat lerps them
-- ============================================================
local function setDoorTarget(doorTable, targetVec)
    for idx in pairs(doorTable) do
        doorTargets[idx] = targetVec
    end
end

local function openLeftDoor()
    leftDoorOpen = true
    setDoorTarget(leftDoorSlots, DOOR_OPEN_LEFT)
    print("[Lambo] Left door opening 🔓")
end

local function closeLeftDoor()
    leftDoorOpen = false
    setDoorTarget(leftDoorSlots, DOOR_CLOSED)
    print("[Lambo] Left door closing 🔒")
end

local function openRightDoor()
    rightDoorOpen = true
    setDoorTarget(rightDoorSlots, DOOR_OPEN_RIGHT)
    print("[Lambo] Right door opening 🔓")
end

local function closeRightDoor()
    rightDoorOpen = false
    setDoorTarget(rightDoorSlots, DOOR_CLOSED)
    print("[Lambo] Right door closing 🔒")
end

-- ============================================================
-- SIT SYSTEM
-- ?sit  → noclip + move character into driver seat
--         walking naturally drives the lambo (lambo follows HRP)
-- ?unsit → re-clip + teleport beside the car
-- ============================================================
local function setCharNoclip(state)
    local char = player.Character
    if not char then return end
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") then
            pcall(function() part.CanCollide = not state end)
        end
    end
end

local function sitInCar()
    local char = player.Character
    if not char then return end
    local hrp  = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    -- Driver seat in car-local space:
    --   x=-4 (left/driver side), y=8 (seat height), z=0 (mid-car)
    -- Car center = hrp.CFrame offset down by 3 studs
    local carCF   = hrp.CFrame * CFrame.new(0, -3, 0)
    local seatPos = carCF:PointToWorldSpace(Vector3.new(-4, 8, 0))

    -- Teleport character into seat
    hrp.CFrame = CFrame.new(seatPos, seatPos + hrp.CFrame.LookVector)
    task.wait(0.05)

    -- Enable noclip so character doesn't collide with lambo blocks
    setCharNoclip(true)
    isSitting = true

    -- Persistent noclip loop (keeps it on in case game resets it)
    if noclipConn then noclipConn:Disconnect(); noclipConn = nil end
    noclipConn = RunService.Heartbeat:Connect(function()
        if not isSitting then
            noclipConn:Disconnect(); noclipConn = nil
            return
        end
        local c = player.Character
        if not c then return end
        for _, part in ipairs(c:GetDescendants()) do
            if part:IsA("BasePart") and part.CanCollide then
                pcall(function() part.CanCollide = false end)
            end
        end
    end)

    print("[Lambo] 🪑 Sitting in driver seat! Walk to drive the lambo.")
end

local function unsitFromCar()
    isSitting = false
    if noclipConn then noclipConn:Disconnect(); noclipConn = nil end

    local char = player.Character
    if not char then return end
    local hrp  = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    -- Re-enable collision
    setCharNoclip(false)

    -- Teleport character to beside the car (right side, +15 studs)
    local carCF   = hrp.CFrame * CFrame.new(0, -3, 0)
    local exitPos = carCF:PointToWorldSpace(Vector3.new(15, 3, 0))
    hrp.CFrame    = CFrame.new(exitPos)

    print("[Lambo] 🚶 Exited car. Collision re-enabled.")
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
    -- Skip character parts
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
    bp.P        = 300000
    bp.D        = 8000
    bp.Position = part.Position
    bp.Parent   = part

    local bg = Instance.new("BodyGyro")
    bg.MaxTorque = Vector3.new(1e9, 1e9, 1e9)
    bg.P         = 300000
    bg.D         = 8000
    bg.CFrame    = part.CFrame
    bg.Parent    = part

    controlled[part] = {
        bp           = bp,
        bg           = bg,
        origAnch     = origAnch,
        origCC       = origCC,
        origMassless = origMassless,
        origPhysProps = origPhysProps,
        origColor    = part.Color,
        origMaterial = part.Material,
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
            part.Anchored   = data.origAnch or false
            part.CanCollide = data.origCC or true
            part.Massless   = data.origMassless or false
            if data.origPhysProps then
                part.CustomPhysicalProperties = data.origPhysProps
            end
            if data.origColor    then part.Color    = data.origColor    end
            if data.origMaterial then part.Material = data.origMaterial end
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
    if z >= -2 and z <= 5  and y >= 5 then return LAMBO_GLASS, Enum.Material.Glass end
    if z >= 8  and y >= 7 then return LAMBO_GLASS,  Enum.Material.Glass        end
    if z >= 13 and y <= 2 then return LAMBO_CHROME, Enum.Material.Metal        end
    if y >= 10            then return LAMBO_DARK,   Enum.Material.SmoothPlastic end
    if y <= 0             then return LAMBO_DARK,   Enum.Material.SmoothPlastic end
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
-- MAIN FORMATION LOOP  (modified: applies door offsets + lerps them)
-- ============================================================
local function startFormation()
    if heartConn then heartConn:Disconnect() end

    heartConn = RunService.Heartbeat:Connect(function(dt)
        if not scriptAlive or not isActive then return end
        local char = player.Character
        if not char then return end
        local hrp  = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso")
        if not hrp then return end

        -- Car CFrame: centered at player feet, facing same direction
        local carCF = hrp.CFrame * CFrame.new(0, -3, 0)

        -- ── Animate door offsets (lerp current → target) ──
        local alpha = math.min(dt * 7, 1)
        for idx, target in pairs(doorTargets) do
            local cur = doorOffsets[idx] or Vector3.zero
            doorOffsets[idx] = cur:Lerp(target, alpha)
        end

        -- ── Position blocks ──
        local partList = {}
        for part, _ in pairs(controlled) do
            if part and part.Parent then table.insert(partList, part) end
        end

        local slotCount = #lamboSlots

        for i, part in ipairs(partList) do
            local data = controlled[part]
            if data and data.bp and data.bp.Parent then
                if i <= slotCount then
                    local slot    = lamboSlots[i]
                    -- Apply door scissor offset if this slot has one
                    local dOff    = doorOffsets[i] or Vector3.zero
                    local localPos = slot + dOff
                    local worldPos = carCF:PointToWorldSpace(localPos)
                    data.bp.Position = worldPos
                    data.bg.CFrame   = CFrame.new(worldPos) * (carCF - carCF.Position)
                else
                    -- Extra blocks: orbit loosely above the car
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
-- ACTIVATE HELPER  (used by both GUI button and !lambo command)
-- ============================================================
local function activateLambo()
    if isActive then
        print("[Lambo] Already active!")
        return
    end
    sweepMap()
    isActive = true
    startFormation()
    task.wait(0.5)
    local pl = {}
    for part, _ in pairs(controlled) do table.insert(pl, part) end
    applyLamboColors(pl)
    print("[Lambo] 🚗 Lambo activated! " .. partCount .. " blocks grabbed.")
end

local function deactivateLambo()
    isActive = false
    if heartConn then heartConn:Disconnect(); heartConn = nil end
    releaseAll()
    closeLeftDoor(); closeRightDoor()
    unsitFromCar()
    print("[Lambo] Deactivated.")
end

-- ============================================================
-- CHAT COMMANDS
-- Supported: !lambo  ?open  ?left  ?right  ?close  ?sit  ?unsit
-- ============================================================
player.Chatted:Connect(function(raw)
    local msg = raw:lower():gsub("^%s+", ""):gsub("%s+$", "")

    if msg == "!lambo" then
        activateLambo()

    elseif msg == "?open" then
        if isActive then openLeftDoor(); openRightDoor() end

    elseif msg == "?left" then
        if isActive then
            if leftDoorOpen then closeLeftDoor() else openLeftDoor() end
        end

    elseif msg == "?right" then
        if isActive then
            if rightDoorOpen then closeRightDoor() else openRightDoor() end
        end

    elseif msg == "?close" then
        if isActive then closeLeftDoor(); closeRightDoor() end

    elseif msg == "?sit" then
        if isActive then sitInCar() end

    elseif msg == "?unsit" then
        unsitFromCar()
    end
end)

-- ============================================================
-- GUI  (enhanced: progress bar, door status, seat status,
--       door/sit buttons, commands reference panel)
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

    -- ── Main panel (sized dynamically at the end) ──
    local panel = Instance.new("Frame", gui)
    panel.Name              = "Panel"
    panel.Size              = UDim2.fromOffset(226, 600)
    panel.Position          = UDim2.new(0, 12, 0.5, -300)
    panel.BackgroundColor3  = Color3.fromRGB(8, 8, 12)
    panel.BorderSizePixel   = 0
    Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 10)

    -- Yellow accent stripe at top
    local accent = Instance.new("Frame", panel)
    accent.Size             = UDim2.new(1, 0, 0, 4)
    accent.BackgroundColor3 = LAMBO_YELLOW
    accent.BorderSizePixel  = 0
    Instance.new("UICorner", accent).CornerRadius = UDim.new(0, 10)

    -- Title
    local title = Instance.new("TextLabel", panel)
    title.Size              = UDim2.new(1, -44, 0, 26)
    title.Position          = UDim2.fromOffset(8, 7)
    title.BackgroundTransparency = 1
    title.Text              = "🚗  LAMBORGHINI"
    title.TextColor3        = LAMBO_YELLOW
    title.TextSize          = 12
    title.Font              = Enum.Font.GothamBold
    title.TextXAlignment    = Enum.TextXAlignment.Left

    local sub = Instance.new("TextLabel", panel)
    sub.Size                = UDim2.new(1, -12, 0, 13)
    sub.Position            = UDim2.fromOffset(8, 28)
    sub.BackgroundTransparency = 1
    sub.Text                = "HURACÁN  TCO BLOCK FORMATION"
    sub.TextColor3          = Color3.fromRGB(90, 90, 100)
    sub.TextSize            = 7
    sub.Font                = Enum.Font.Gotham
    sub.TextXAlignment      = Enum.TextXAlignment.Left

    -- Close / minimize button
    local closeBtn = Instance.new("TextButton", panel)
    closeBtn.Size             = UDim2.fromOffset(22, 22)
    closeBtn.Position         = UDim2.new(1, -26, 0, 5)
    closeBtn.BackgroundColor3 = Color3.fromRGB(30, 10, 10)
    closeBtn.TextColor3       = Color3.fromRGB(200, 80, 80)
    closeBtn.Text             = "✕"
    closeBtn.TextSize         = 10
    closeBtn.Font             = Enum.Font.GothamBold
    closeBtn.BorderSizePixel  = 0
    Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 4)
    closeBtn.MouseButton1Click:Connect(function()
        gui:Destroy()
        -- Mini icon to re-open
        local mini = Instance.new("ScreenGui")
        mini.Name = "LamboIcon"; mini.ResetOnSpawn = false
        mini.DisplayOrder = 999; mini.Parent = pg
        local ib = Instance.new("TextButton", mini)
        ib.Size             = UDim2.fromOffset(36, 36)
        ib.Position         = UDim2.new(0, 12, 0.5, -18)
        ib.BackgroundColor3 = Color3.fromRGB(8, 8, 12)
        ib.TextColor3       = LAMBO_YELLOW
        ib.Text             = "🚗"
        ib.TextSize         = 18
        ib.Font             = Enum.Font.GothamBold
        ib.BorderSizePixel  = 0
        Instance.new("UICorner", ib).CornerRadius = UDim.new(0, 8)
        ib.MouseButton1Click:Connect(function() mini:Destroy(); createGUI() end)
    end)

    -- ── Divider ──
    local function makeDivider(yOff)
        local d = Instance.new("Frame", panel)
        d.Size             = UDim2.new(1, -12, 0, 1)
        d.Position         = UDim2.fromOffset(6, yOff)
        d.BackgroundColor3 = Color3.fromRGB(28, 28, 38)
        d.BorderSizePixel  = 0
    end

    makeDivider(46)

    -- ── STATUS label ──
    local statusLbl = Instance.new("TextLabel", panel)
    statusLbl.Size              = UDim2.new(1, -12, 0, 16)
    statusLbl.Position          = UDim2.fromOffset(8, 52)
    statusLbl.BackgroundTransparency = 1
    statusLbl.Text              = "STATUS: IDLE"
    statusLbl.TextColor3        = Color3.fromRGB(70, 70, 80)
    statusLbl.TextSize          = 8
    statusLbl.Font              = Enum.Font.GothamBold
    statusLbl.TextXAlignment    = Enum.TextXAlignment.Left

    -- ── BLOCKS counter (larger, prominent) ──
    local blocksLbl = Instance.new("TextLabel", panel)
    blocksLbl.Size              = UDim2.new(1, -12, 0, 20)
    blocksLbl.Position          = UDim2.fromOffset(8, 68)
    blocksLbl.BackgroundTransparency = 1
    blocksLbl.Text              = "BLOCKS: 0 / " .. #lamboSlots
    blocksLbl.TextColor3        = LAMBO_YELLOW
    blocksLbl.TextSize          = 11
    blocksLbl.Font              = Enum.Font.GothamBold
    blocksLbl.TextXAlignment    = Enum.TextXAlignment.Left

    -- Progress bar background
    local barBg = Instance.new("Frame", panel)
    barBg.Size             = UDim2.new(1, -12, 0, 7)
    barBg.Position         = UDim2.fromOffset(6, 90)
    barBg.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
    barBg.BorderSizePixel  = 0
    Instance.new("UICorner", barBg).CornerRadius = UDim.new(0, 4)

    -- Progress bar fill
    local barFill = Instance.new("Frame", barBg)
    barFill.Size             = UDim2.new(0, 0, 1, 0)
    barFill.BackgroundColor3 = LAMBO_YELLOW
    barFill.BorderSizePixel  = 0
    Instance.new("UICorner", barFill).CornerRadius = UDim.new(0, 4)

    -- ── Door & seat state indicator ──
    local stateLbl = Instance.new("TextLabel", panel)
    stateLbl.Size              = UDim2.new(1, -12, 0, 14)
    stateLbl.Position          = UDim2.fromOffset(8, 101)
    stateLbl.BackgroundTransparency = 1
    stateLbl.Text              = "DOORS  L:🔒  R:🔒   |   SEAT: —"
    stateLbl.TextColor3        = Color3.fromRGB(75, 75, 85)
    stateLbl.TextSize          = 7
    stateLbl.Font              = Enum.Font.Gotham
    stateLbl.TextXAlignment    = Enum.TextXAlignment.Left

    -- Live update loop
    task.spawn(function()
        while gui.Parent and scriptAlive do
            -- Status
            statusLbl.Text       = isActive and "STATUS: 🟡 ACTIVE" or "STATUS: ⬛ IDLE"
            statusLbl.TextColor3 = isActive and LAMBO_YELLOW or Color3.fromRGB(70, 70, 80)

            -- Block counter + progress bar
            local used  = partCount
            local total = #lamboSlots
            local pct   = math.min(used / math.max(total, 1), 1)
            blocksLbl.Text        = "BLOCKS: " .. used .. " / " .. total
            blocksLbl.TextColor3  = pct >= 1 and Color3.fromRGB(80, 255, 110) or LAMBO_YELLOW
            barFill.Size          = UDim2.new(pct, 0, 1, 0)
            barFill.BackgroundColor3 = pct >= 1
                and Color3.fromRGB(80, 255, 110) or LAMBO_YELLOW

            -- Door + seat state
            local lStr = leftDoorOpen  and "🔓" or "🔒"
            local rStr = rightDoorOpen and "🔓" or "🔒"
            local sStr = isSitting     and "🪑 IN" or "—"
            stateLbl.Text = "DOORS  L:" .. lStr .. "  R:" .. rStr .. "   |   SEAT: " .. sStr

            task.wait(0.4)
        end
    end)

    makeDivider(120)

    -- ── Button builder ──
    local btnY = 128
    local function makeBtn(label, bgCol, fgCol, cb)
        local btn = Instance.new("TextButton", panel)
        btn.Size             = UDim2.new(1, -12, 0, 26)
        btn.Position         = UDim2.fromOffset(6, btnY)
        btn.BackgroundColor3 = bgCol
        btn.TextColor3       = fgCol
        btn.Text             = label
        btn.TextSize         = 8
        btn.Font             = Enum.Font.GothamBold
        btn.BorderSizePixel  = 0
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
        btn.MouseButton1Click:Connect(cb)
        btnY = btnY + 30
        return btn
    end

    -- ── Section: Core ──
    makeBtn("🔍  SCAN BLOCKS",              Color3.fromRGB(16, 40, 16),  Color3.fromRGB(80, 255, 100), sweepMap)
    makeBtn("▶  ACTIVATE  ( !lambo )",      Color3.fromRGB(50, 38, 0),   LAMBO_YELLOW,               activateLambo)
    makeBtn("⏹  DEACTIVATE",               Color3.fromRGB(50, 10, 10),  Color3.fromRGB(255, 70, 70), deactivateLambo)
    makeBtn("🔄  RESCAN + RECOLOR",         Color3.fromRGB(10, 20, 40),  Color3.fromRGB(80, 160, 255), function()
        sweepMap()
        local pl = {}
        for part, _ in pairs(controlled) do table.insert(pl, part) end
        applyLamboColors(pl)
    end)

    btnY = btnY + 4; makeDivider(btnY); btnY = btnY + 8

    -- ── Section: Doors ──
    makeBtn("🚪  OPEN BOTH DOORS   (?open)",  Color3.fromRGB(12, 28, 48), Color3.fromRGB(110, 195, 255), function()
        if isActive then openLeftDoor(); openRightDoor() end
    end)
    makeBtn("🔒  CLOSE BOTH DOORS  (?close)", Color3.fromRGB(12, 28, 48), Color3.fromRGB(110, 195, 255), function()
        if isActive then closeLeftDoor(); closeRightDoor() end
    end)
    makeBtn("◀  LEFT DOOR TOGGLE   (?left)", Color3.fromRGB(18, 18, 45), Color3.fromRGB(155, 155, 255), function()
        if isActive then
            if leftDoorOpen then closeLeftDoor() else openLeftDoor() end
        end
    end)
    makeBtn("▶  RIGHT DOOR TOGGLE  (?right)",Color3.fromRGB(18, 18, 45), Color3.fromRGB(155, 155, 255), function()
        if isActive then
            if rightDoorOpen then closeRightDoor() else openRightDoor() end
        end
    end)

    btnY = btnY + 4; makeDivider(btnY); btnY = btnY + 8

    -- ── Section: Seat ──
    makeBtn("🪑  SIT IN CAR   (?sit)",       Color3.fromRGB(16, 40, 18), Color3.fromRGB(90, 255, 115), function()
        if isActive then sitInCar() end
    end)
    makeBtn("🚶  EXIT CAR     (?unsit)",      Color3.fromRGB(40, 18, 18), Color3.fromRGB(255, 110, 90), unsitFromCar)

    btnY = btnY + 4; makeDivider(btnY); btnY = btnY + 8

    -- ── Commands Reference ──
    local cmdTitle = Instance.new("TextLabel", panel)
    cmdTitle.Size              = UDim2.new(1, -12, 0, 14)
    cmdTitle.Position          = UDim2.fromOffset(8, btnY)
    cmdTitle.BackgroundTransparency = 1
    cmdTitle.Text              = "📋  CHAT COMMANDS"
    cmdTitle.TextColor3        = Color3.fromRGB(150, 150, 165)
    cmdTitle.TextSize          = 7
    cmdTitle.Font              = Enum.Font.GothamBold
    cmdTitle.TextXAlignment    = Enum.TextXAlignment.Left
    btnY = btnY + 16

    local CMDS = {
        { "!lambo",  "Build & activate the lambo" },
        { "?open",   "Open both doors (scissor)" },
        { "?left",   "Toggle left door" },
        { "?right",  "Toggle right door" },
        { "?close",  "Close all doors" },
        { "?sit",    "Sit → walk to drive" },
        { "?unsit",  "Exit + re-enable collision" },
    }

    for _, cmd in ipairs(CMDS) do
        local row = Instance.new("Frame", panel)
        row.Size              = UDim2.new(1, -12, 0, 14)
        row.Position          = UDim2.fromOffset(6, btnY)
        row.BackgroundTransparency = 1

        local kLbl = Instance.new("TextLabel", row)
        kLbl.Size             = UDim2.new(0, 62, 1, 0)
        kLbl.BackgroundTransparency = 1
        kLbl.Text             = cmd[1]
        kLbl.TextColor3       = LAMBO_YELLOW
        kLbl.TextSize         = 7
        kLbl.Font             = Enum.Font.GothamBold
        kLbl.TextXAlignment   = Enum.TextXAlignment.Left

        local dLbl = Instance.new("TextLabel", row)
        dLbl.Size             = UDim2.new(1, -66, 1, 0)
        dLbl.Position         = UDim2.fromOffset(66, 0)
        dLbl.BackgroundTransparency = 1
        dLbl.Text             = cmd[2]
        dLbl.TextColor3       = Color3.fromRGB(110, 110, 120)
        dLbl.TextSize         = 6
        dLbl.Font             = Enum.Font.Gotham
        dLbl.TextXAlignment   = Enum.TextXAlignment.Left

        btnY = btnY + 15
    end

    -- Resize panel to fit all content
    local finalH = btnY + 10
    panel.Size     = UDim2.fromOffset(226, finalH)
    panel.Position = UDim2.new(0, 12, 0.5, -finalH / 2)

    -- ── Draggable ──
    local dragging, dragStartM, dragStartPos = false, Vector2.zero, UDim2.new()
    panel.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1
        or inp.UserInputType == Enum.UserInputType.Touch then
            dragging      = true
            dragStartM    = Vector2.new(inp.Position.X, inp.Position.Y)
            dragStartPos  = panel.Position
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
classifyDoorSlots()

print("[LamboScript] Slots built: "     .. #lamboSlots)
print("[LamboScript] Left door slots: " .. (function()
    local n = 0; for _ in pairs(leftDoorSlots)  do n = n + 1 end; return n
end)())
print("[LamboScript] Right door slots: " .. (function()
    local n = 0; for _ in pairs(rightDoorSlots) do n = n + 1 end; return n
end)())

createGUI()

-- Periodic rescan while active
task.spawn(function()
    while scriptAlive do
        task.wait(4)
        if isActive then sweepMap() end
    end
end)

-- Reset sit state on respawn
player.CharacterAdded:Connect(function()
    isSitting = false
    if noclipConn then noclipConn:Disconnect(); noclipConn = nil end
    task.wait(0.5)
    if isActive then sweepMap() end
end)

print("[LamboScript] ✅ Ready!  Type  !lambo  in chat to build the car.")
print("[LamboScript] GUI panel on the left — drag it anywhere you like.")
