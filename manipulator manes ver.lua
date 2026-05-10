-- ============================================================
-- LAMBORGHINI + SWORD FORMATION SCRIPT  v4
-- Commands:
--   !lambo               build + activate Lamborghini
--   !stop                release all Lambo blocks
--   !autograb            TP to every anchored block and grab it
--   !sword               spawn 5 spinning swords around you (white)
--   !swordstop           release sword blocks
--   ?open                open both scissor doors
--   ?left                open left door only
--   ?right               open right door only
--   ?close               close all doors
--   ?sit                 enter driver seat (noclip on)
--   ?unsit               exit car (noclip off)
--   ?hover               sword platform sits at your feet while you walk
--   ?land                return swords to orbit
--   ?attack <name> <1-5> fire swords at a player (partial name ok)
--   .whitelist <name>    allow another player to use all commands
-- ============================================================

local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
if not player then player = Players.PlayerAdded:Wait() end
if not player.Character or not player.Character:FindFirstChild("HumanoidRootPart") then
    player.CharacterAdded:Wait(); task.wait(0.5)
end

-- ============================================================
-- COLORS
-- ============================================================
local YELLOW  = Color3.fromRGB(255, 195,   0)
local DARK    = Color3.fromRGB( 12,  12,  16)
local CHROME  = Color3.fromRGB(200, 200, 210)
local RED     = Color3.fromRGB(255,  30,  30)
local ORANGE  = Color3.fromRGB(255, 100,   0)
local GLASS   = Color3.fromRGB( 80, 140, 200)

-- Sword color: plain white/off-white, no tinting
local SWORD_WHITE = Color3.fromRGB(235, 235, 235)
local SWORD_BLADE  = SWORD_WHITE
local SWORD_GUARD  = SWORD_WHITE
local SWORD_HANDLE = SWORD_WHITE
local SWORD_GEM    = SWORD_WHITE

-- ============================================================
-- STATE
-- ============================================================
local scriptAlive   = true

-- Lambo state
local lamboControlled = {}   -- [part] = data
local lamboSlots      = {}
local lamboPartCount  = 0
local lamboActive     = false
local lamboHeart      = nil
local doorState       = "closed"
local isSeated        = false
local noclipConn      = nil

-- Sword state
local swordControlled = {}   -- [part] = data
local swordPartCount  = 0
local swordActive     = false
local swordHeart      = nil
local spinRadius      = 10   -- studs, controlled by slider
local spinSpeed       = 2.0  -- radians per second

-- Hover / fly state
local hoverActive    = false
local hoverHeart     = nil
local hoverSwordPart = nil   -- the big sword block used for hover

-- Whitelist
local whitelist = {}  -- set of full player names (lower)

-- ============================================================
-- WHITELIST  (partial name match)
-- ============================================================
local function findPlayerByName(partial)
    partial = partial:lower()
    for _, p in ipairs(Players:GetPlayers()) do
        if p.Name:lower():find(partial, 1, true)
        or p.DisplayName:lower():find(partial, 1, true) then
            return p
        end
    end
    return nil
end

local function isAllowed(sendingPlayer)
    if sendingPlayer == player then return true end
    return whitelist[sendingPlayer.Name:lower()] == true
end

-- ============================================================
-- GRAB / RELEASE  (generic, works on anchored blocks)
-- ============================================================
local function grabInto(pool, part)
    if pool[part] then return end
    if not part or not part.Parent then return end
    if not part:IsA("BasePart") then return end
    if part.Size.Magnitude < 0.2 then return end
    if part.Transparency >= 1   then return end
    if part.Name == "Baseplate" then return end
    -- Skip character parts
    local p = part.Parent
    while p and p ~= workspace do
        if p:FindFirstChildOfClass("Humanoid") then return end
        p = p.Parent
    end
    -- Skip already-grabbed parts
    if lamboControlled[part] or swordControlled[part] then return end

    local origAnch  = part.Anchored
    local origCC    = part.CanCollide
    local origMless = part.Massless
    local origPhys  = part.CustomPhysicalProperties

    pcall(function() part.Anchored   = false end)
    pcall(function() part.CanCollide = false end)
    pcall(function() part:SetNetworkOwner(player) end)
    pcall(function()
        part.CustomPhysicalProperties = PhysicalProperties.new(0.01,0.3,0.5,1,1)
        part.Massless = true
    end)

    local bp = Instance.new("BodyPosition")
    bp.MaxForce = Vector3.new(1e9,1e9,1e9); bp.P=300000; bp.D=8000
    bp.Position = part.Position; bp.Parent = part

    local bg = Instance.new("BodyGyro")
    bg.MaxTorque = Vector3.new(1e9,1e9,1e9); bg.P=300000; bg.D=8000
    bg.CFrame = part.CFrame; bg.Parent = part

    pool[part] = {
        bp=bp, bg=bg,
        origAnch=origAnch, origCC=origCC,
        origMless=origMless, origPhys=origPhys,
        origColor=part.Color, origMat=part.Material,
    }
end

local function releaseFrom(pool, part, data)
    pcall(function()
        if data.bp and data.bp.Parent then data.bp:Destroy() end
        if data.bg and data.bg.Parent then data.bg:Destroy() end
    end)
    if part and part.Parent then pcall(function()
        part.Anchored   = data.origAnch  or false
        part.CanCollide = data.origCC    or true
        part.Massless   = data.origMless or false
        if data.origPhys  then part.CustomPhysicalProperties = data.origPhys end
        if data.origColor then part.Color    = data.origColor end
        if data.origMat   then part.Material = data.origMat   end
    end) end
    pool[part] = nil
end

local function releasePool(pool)
    for part, data in pairs(pool) do releaseFrom(pool, part, data) end
end

-- ============================================================
-- AUTO-GRAB: teleport to every anchored block and grab it
-- ============================================================
local autoGrabRunning = false

local function autoGrabAll()
    if autoGrabRunning then return end
    autoGrabRunning = true

    local char = player.Character
    if not char then autoGrabRunning = false; return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then autoGrabRunning = false; return end

    -- Store original position to come back after
    local origCF = hrp.CFrame

    -- Collect ALL anchored BaseParts in workspace first
    local anchored = {}
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("BasePart")
           and obj.Anchored == true
           and obj.Transparency < 1
           and obj.Size.Magnitude >= 0.2
           and obj.Name ~= "Baseplate"
           and not lamboControlled[obj]
           and not swordControlled[obj] then
            local isChar = false
            local p = obj.Parent
            while p and p ~= workspace do
                if p:FindFirstChildOfClass("Humanoid") then isChar = true; break end
                p = p.Parent
            end
            if not isChar then table.insert(anchored, obj) end
        end
    end

    -- Teleport to each block, grab it, brief yield so network catches up
    local grabbed = 0
    for _, part in ipairs(anchored) do
        if part and part.Parent then
            -- Teleport player right on top of the block
            local tp = part.Position + Vector3.new(0, part.Size.Y/2 + 3, 0)
            pcall(function() hrp.CFrame = CFrame.new(tp) end)
            task.wait(0.05)  -- tiny yield — just enough for network ownership claim
            grabInto(lamboControlled, part)
            grabbed = grabbed + 1
        end
    end

    -- Teleport back to start
    pcall(function() hrp.CFrame = origCF end)

    lamboPartCount = 0
    for _ in pairs(lamboControlled) do lamboPartCount = lamboPartCount + 1 end

    print("[AutoGrab] Grabbed " .. grabbed .. " anchored blocks.")
    autoGrabRunning = false
end

-- Sweep map into a pool, stop after maxCount parts
local function sweepInto(pool, maxCount)
    local grabbed = 0
    for _, obj in ipairs(workspace:GetDescendants()) do
        if maxCount and grabbed >= maxCount then break end
        if not pool[obj] and not lamboControlled[obj] and not swordControlled[obj]
           and obj and obj.Parent
           and obj:IsA("BasePart")
           and obj.Size.Magnitude >= 0.2
           and obj.Transparency < 1
           and obj.Name ~= "Baseplate" then
            local isChar = false
            local p = obj.Parent
            while p and p ~= workspace do
                if p:FindFirstChildOfClass("Humanoid") then isChar=true; break end
                p = p.Parent
            end
            if not isChar then
                grabInto(pool, obj)
                grabbed = grabbed + 1
            end
        end
    end
end

-- ============================================================
-- =====================  LAMBO SYSTEM  =======================
-- ============================================================

local function buildLamboPositions()
    local p = {}
    local function add(x,y,z) table.insert(p, Vector3.new(x,y,z)) end

    -- FRONT SPLITTER
    for xi=-8,8,2 do add(xi,0,-14); add(xi,0,-13) end
    add(-9,0,-13); add(9,0,-13)

    -- FRONT BUMPER
    for xi=-8,8,2 do add(xi,1,-12); add(xi,2,-12) end
    add(-9,1,-12); add(-9,2,-12); add(9,1,-12); add(9,2,-12)
    for xi=-6,6,2 do add(xi,3,-12) end
    add(-8,2,-11); add(-8,3,-11); add(-7,2,-11); add(-7,3,-11)
    add( 8,2,-11); add( 8,3,-11); add( 7,2,-11); add( 7,3,-11)

    -- ANGULAR HEADLIGHTS
    add(-9,2,-11); add(-9,3,-10); add(-8,4,-9); add(-7,4,-8); add(-6,4,-8)
    add(-9,3,-11); add(-8,3,-10); add(-7,4,-9)
    add(-8,5,-10); add(-7,5,-9); add(-6,5,-8); add(-5,5,-8)
    add( 9,2,-11); add( 9,3,-10); add( 8,4,-9); add( 7,4,-8); add( 6,4,-8)
    add( 9,3,-11); add( 8,3,-10); add( 7,4,-9)
    add( 8,5,-10); add( 7,5,-9); add( 6,5,-8); add( 5,5,-8)

    -- HOOD
    local hoodRows = {
        {z=-11,y=3,hw=6},{z=-9,y=3,hw=6},{z=-7,y=4,hw=5},{z=-5,y=4,hw=5},{z=-3,y=5,hw=4},
    }
    for _,row in ipairs(hoodRows) do
        for xi=-row.hw,row.hw,2 do add(xi,row.y,row.z) end
        add(-(row.hw+1),row.y,row.z); add(row.hw+1,row.y,row.z)
    end
    add(0,4,-10); add(0,4,-8); add(0,5,-6); add(0,5,-4)
    add(-2,4,-8); add(2,4,-8); add(-2,5,-5); add(2,5,-5)

    -- WINDSHIELD
    local wsFace={{z=-2,y=5},{z=-1,y=6},{z=0,y=7},{z=1,y=8}}
    for _,row in ipairs(wsFace) do
        for xi=-4,4,2 do add(xi,row.y,row.z) end
        add(-5,row.y,row.z); add(5,row.y,row.z)
        add(-6,row.y,row.z); add(6,row.y,row.z)
    end

    -- ROOF
    for zi=2,5 do
        for xi=-4,4,2 do add(xi,9,zi) end
        add(-5,9,zi); add(5,9,zi)
    end

    -- REAR WINDSHIELD
    local rwsFace={{z=5,y=9},{z=6,y=8},{z=7,y=7}}
    for _,row in ipairs(rwsFace) do
        for xi=-4,4,2 do add(xi,row.y,row.z) end
        add(-5,row.y,row.z); add(5,row.y,row.z)
    end

    -- DOOR PANELS
    for zi=-4,5,3 do
        for yi=2,7 do add(-7,yi,zi); add(7,yi,zi) end
    end
    for zi=-8,6,3 do
        add(-7,1,zi); add(-8,1,zi); add(7,1,zi); add(8,1,zi)
    end
    for zi=-5,5,3 do add(-8,5,zi); add(8,5,zi) end

    -- REAR ENGINE INTAKES
    for yi=3,7,2 do
        for zi=4,9,2 do add(-9,yi,zi); add(9,yi,zi) end
    end
    for yi=4,6,2 do
        add(-10,yi,5); add(-10,yi,7); add(-10,yi,9)
        add( 10,yi,5); add( 10,yi,7); add( 10,yi,9)
    end

    -- REAR HAUNCHES
    for yi=2,6,2 do
        for zi=8,12,2 do
            add(-10,yi,zi); add(-11,yi,zi); add(10,yi,zi); add(11,yi,zi)
        end
    end
    for zi=8,12,2 do
        add(-9,7,zi); add(9,7,zi); add(-10,6,zi); add(10,6,zi)
    end

    -- REAR DECK / ENGINE COVER
    for zi=7,11,2 do
        for xi=-6,6,2 do add(xi,5,zi); add(xi,6,zi) end
    end
    for zi=8,11,2 do for xi=-4,4,2 do add(xi,7,zi) end end
    add(-2,8,9); add(0,8,9); add(2,8,9); add(-2,8,10); add(0,8,10); add(2,8,10)

    -- TAILLIGHTS
    for xi=-9,9,2 do add(xi,6,12); add(xi,7,12); add(xi,8,12) end
    for yi=5,8 do
        add(-10,yi,12); add(-11,yi,11); add(10,yi,12); add(11,yi,11)
    end
    add(-3,9,12); add(-1,9,12); add(1,9,12); add(3,9,12)

    -- REAR BUMPER + DIFFUSER
    for xi=-9,9,2 do
        add(xi,4,12); add(xi,3,12); add(xi,2,13); add(xi,1,13); add(xi,0,13)
    end
    for zi=12,15 do
        add(-6,0,zi); add(-3,0,zi); add(0,0,zi); add(3,0,zi); add(6,0,zi)
    end
    for zi=12,14 do
        add(-8,0,zi); add(-8,1,zi); add(8,0,zi); add(8,1,zi)
    end

    -- QUAD EXHAUSTS
    add(-4,2,13); add(-2,2,13); add(2,2,13); add(4,2,13)
    add(-4,1,14); add(-2,1,14); add(2,1,14); add(4,1,14)
    for _,ex in ipairs({-4,-2,2,4}) do
        add(ex-1,2,14); add(ex+1,2,14); add(ex,3,14); add(ex,1,14)
    end

    -- REAR WING
    for xi=-11,11,2 do
        add(xi,11,10); add(xi,12,10); add(xi,11,9); add(xi,11,11)
    end
    for yi=8,11 do
        add(-7,yi,10); add(7,yi,10); add(-6,yi,10); add(6,yi,10)
    end
    for zi=9,12 do
        add(-11,10,zi); add(-11,11,zi); add(11,10,zi); add(11,11,zi)
    end
    for xi=-11,11,2 do add(xi,13,10) end

    -- WHEELS
    local function addWheel(cx,cz,outerR,innerR)
        for a=0,math.pi*2-0.01,math.pi/5 do
            add(cx, 3+math.round(math.sin(a)*outerR), cz+math.round(math.cos(a)*outerR))
        end
        for a=0,math.pi*2-0.01,math.pi/6 do
            add(cx, 3+math.round(math.sin(a)*(outerR-1)), cz+math.round(math.cos(a)*(outerR-1)))
        end
        for sp=0,4 do
            local a=sp*math.pi*2/5
            for r=1,innerR+1 do
                add(cx, 3+math.round(math.sin(a)*r), cz+math.round(math.cos(a)*r))
            end
        end
        add(cx,3,cz); add(cx,4,cz); add(cx,2,cz)
    end
    addWheel(-10,-8,3,2); addWheel(10,-8,3,2)
    addWheel(-11,9,3,2);  addWheel(11,9,3,2)

    -- WHEEL ARCHES
    local function addArch(cx,cz,archR)
        for a=math.pi,0,-math.pi/8 do
            add(cx, 3+math.round(math.sin(a)*archR), cz+math.round(math.cos(a)*archR))
        end
    end
    addArch(-9,-8,4); addArch(9,-8,4); addArch(-10,9,5); addArch(10,9,5)

    -- UNDERBODY
    for xi=-6,6,3 do for zi=-11,11,3 do add(xi,0,zi) end end

    return p
end

local function isDoorSlot(slot)
    local ax = math.abs(slot.X)
    return ax>=7 and ax<=8 and slot.Y>=1 and slot.Y<=7 and slot.Z>=-5 and slot.Z<=6
end

local function shouldOpenSlot(slot)
    if doorState == "closed" then return false end
    if not isDoorSlot(slot) then return false end
    if doorState == "both"  then return true end
    if doorState == "left"  then return slot.X < 0 end
    if doorState == "right" then return slot.X > 0 end
    return false
end

local function getDoorOpenSlot(slot)
    local sign = slot.X < 0 and -1 or 1
    local ty   = math.clamp((slot.Y-1)/6, 0, 1)
    local tz   = math.clamp((slot.Z-(-5))/11, 0, 1)
    return slot + Vector3.new(sign*(1+ty*2), 4+ty*4+tz*1, -1-tz*2)
end

local function getLamboColor(slot)
    local y,z = slot.Y, slot.Z
    if z>=11 and y>=5  then return RED,    Enum.Material.Neon          end
    if z<=-8 and y>=4  then return ORANGE, Enum.Material.Neon          end
    if z>=-2 and z<=5 and y>=5 then return GLASS, Enum.Material.Glass  end
    if z>=8  and y>=7  then return GLASS,  Enum.Material.Glass         end
    if z>=13 and y<=2  then return CHROME, Enum.Material.Metal         end
    if y>=10           then return DARK,   Enum.Material.SmoothPlastic  end
    if y<=0            then return DARK,   Enum.Material.SmoothPlastic  end
    return YELLOW, Enum.Material.SmoothPlastic
end

local function applyLamboColors()
    local i = 0
    for part, _ in pairs(lamboControlled) do
        i = i + 1
        if i <= #lamboSlots and part and part.Parent then
            local col,mat = getLamboColor(lamboSlots[i])
            pcall(function() part.Color=col; part.Material=mat end)
        end
    end
end

local function setCharNoclip(enable)
    local char = player.Character; if not char then return end
    for _, p in ipairs(char:GetDescendants()) do
        if p:IsA("BasePart") then pcall(function() p.CanCollide=not enable end) end
    end
end

local function doSit()
    if not lamboActive then return end
    isSeated = true
    setCharNoclip(true)
    if noclipConn then noclipConn:Disconnect() end
    noclipConn = RunService.Heartbeat:Connect(function()
        if not isSeated then
            if noclipConn then noclipConn:Disconnect(); noclipConn=nil end
            return
        end
        setCharNoclip(true)
    end)
    local char = player.Character
    if char then
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if hrp then
            local carCF  = hrp.CFrame * CFrame.new(0,-3,0)
            local seatWP = carCF:PointToWorldSpace(Vector3.new(-4,4,0))
            hrp.CFrame   = CFrame.new(seatWP, seatWP + hrp.CFrame.LookVector)
        end
    end
end

local function doUnsit()
    isSeated = false
    if noclipConn then noclipConn:Disconnect(); noclipConn=nil end
    setCharNoclip(false)
    local char = player.Character
    if char then
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if hrp then
            local carCF  = hrp.CFrame * CFrame.new(0,-3,0)
            local exitWP = carCF:PointToWorldSpace(Vector3.new(-16,4,0))
            hrp.CFrame   = CFrame.new(exitWP, exitWP + hrp.CFrame.LookVector)
        end
    end
end

local function startLamboFormation()
    if lamboHeart then lamboHeart:Disconnect() end
    lamboHeart = RunService.Heartbeat:Connect(function()
        if not scriptAlive or not lamboActive then return end
        local char = player.Character; if not char then return end
        local hrp  = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso")
        if not hrp then return end
        local carCF    = hrp.CFrame * CFrame.new(0,-3,0)
        local slotCount = #lamboSlots
        local i = 0
        for part, data in pairs(lamboControlled) do
            i = i + 1
            if data and data.bp and data.bp.Parent then
                if i <= slotCount then
                    local slot = lamboSlots[i]
                    local targetSlot = shouldOpenSlot(slot) and getDoorOpenSlot(slot) or slot
                    local worldPos = carCF:PointToWorldSpace(targetSlot)
                    data.bp.Position = worldPos
                    data.bg.CFrame   = CFrame.new(worldPos) * (carCF - carCF.Position)
                else
                    local extra = i - slotCount
                    local angle = (extra/10)*math.pi*2 + tick()
                    data.bp.Position = hrp.Position + Vector3.new(
                        math.cos(angle)*(14+extra*0.3), 10+extra*0.4,
                        math.sin(angle)*(14+extra*0.3)
                    )
                end
            end
        end
    end)
end

local function activateLambo()
    sweepInto(lamboControlled, nil)
    lamboPartCount = 0
    for _ in pairs(lamboControlled) do lamboPartCount = lamboPartCount + 1 end
    lamboActive = true
    startLamboFormation()
    task.wait(0.5)
    applyLamboColors()
end

local function deactivateLambo()
    lamboActive = false
    if isSeated then doUnsit() end
    if lamboHeart then lamboHeart:Disconnect(); lamboHeart=nil end
    releasePool(lamboControlled)
    lamboPartCount = 0
end

-- ============================================================
-- ====================  SWORD SYSTEM  ========================
-- ============================================================
-- Each sword = 10 blocks: 5 blade + 2 guard + 2 handle + 1 gem
-- All 5 swords = 50 blocks
-- Local offsets (sword points along +Z, hilt at 0):
--   Handle:  y=0,z=0 and y=0,z=1
--   Guard:   x=-1,y=0,z=2 and x=1,y=0,z=2
--   Blade:   z=3,4,5,6,7  (single column)
--   Gem:     x=0,y=0,z=2  (center of guard)

-- swordLayout[swordIndex][blockIndex] = local offset (Vector3)
local function buildSwordLayout()
    local layout = {}
    for s = 1, 5 do
        local offsets = {}
        -- handle
        table.insert(offsets, Vector3.new(0, 0,  0))
        table.insert(offsets, Vector3.new(0, 0,  1))
        -- crossguard
        table.insert(offsets, Vector3.new(-1.5, 0, 2))
        table.insert(offsets, Vector3.new( 1.5, 0, 2))
        -- gem (center of guard)
        table.insert(offsets, Vector3.new(0,    0, 2))
        -- blade (5 blocks, tapering toward tip)
        table.insert(offsets, Vector3.new(0, 0,  3))
        table.insert(offsets, Vector3.new(0, 0,  4))
        table.insert(offsets, Vector3.new(0, 0,  5))
        table.insert(offsets, Vector3.new(0, 0,  6))
        table.insert(offsets, Vector3.new(0, 0,  7))
        layout[s] = offsets
    end
    return layout
end

-- Color index per block in a sword (same order as offsets above)
-- 1=handle, 2=handle, 3=guard, 4=guard, 5=gem, 6-10=blade
local SWORD_BLOCK_COLORS = {
    SWORD_HANDLE, SWORD_HANDLE,
    SWORD_GUARD,  SWORD_GUARD,
    SWORD_GEM,
    SWORD_BLADE,  SWORD_BLADE, SWORD_BLADE, SWORD_BLADE, SWORD_BLADE,
}
local SWORD_BLOCK_MATS = {
    Enum.Material.SmoothPlastic, Enum.Material.SmoothPlastic,
    Enum.Material.SmoothPlastic, Enum.Material.SmoothPlastic,
    Enum.Material.SmoothPlastic,
    Enum.Material.SmoothPlastic, Enum.Material.SmoothPlastic,
    Enum.Material.SmoothPlastic, Enum.Material.SmoothPlastic,
    Enum.Material.SmoothPlastic,
}

local SWORD_LAYOUT    = buildSwordLayout()
local BLOCKS_PER_SWORD = 10
local SWORD_COUNT      = 5
local TOTAL_SWORD_BLOCKS = SWORD_COUNT * BLOCKS_PER_SWORD

-- Ordered list of sword blocks so we can map pool to layout
local swordOrder = {}  -- filled when grabbing

local function applySwordColors()
    for i, part in ipairs(swordOrder) do
        if part and part.Parent then
            local blockInSword = ((i-1) % BLOCKS_PER_SWORD) + 1
            local col = SWORD_BLOCK_COLORS[blockInSword]
            local mat = SWORD_BLOCK_MATS[blockInSword]
            if col and mat then
                pcall(function() part.Color=col; part.Material=mat end)
            end
        end
    end
end

local function activateSwords()
    -- grab exactly what we need
    sweepInto(swordControlled, TOTAL_SWORD_BLOCKS)
    swordOrder = {}
    for part, _ in pairs(swordControlled) do table.insert(swordOrder, part) end
    swordPartCount = #swordOrder
    swordActive = true

    task.wait(0.3)
    applySwordColors()

    if swordHeart then swordHeart:Disconnect() end
    swordHeart = RunService.Heartbeat:Connect(function()
        if not scriptAlive or not swordActive then return end
        local char = player.Character; if not char then return end
        local hrp  = char:FindFirstChild("HumanoidRootPart"); if not hrp then return end

        local t       = tick()
        local hrpPos  = hrp.Position
        local hrpY    = hrpPos.Y  -- orbit at player body height

        for i, part in ipairs(swordOrder) do
            if part and part.Parent then
                local data = swordControlled[part]
                if data and data.bp and data.bp.Parent then
                    local swordIdx = math.ceil(i / BLOCKS_PER_SWORD)
                    local blockIdx = ((i-1) % BLOCKS_PER_SWORD) + 1
                    if swordIdx < 1 then swordIdx = 1 end
                    if swordIdx > SWORD_COUNT then swordIdx = SWORD_COUNT end

                    -- Orbit angle for this sword
                    local baseAngle = (swordIdx-1) * (math.pi*2 / SWORD_COUNT)
                    local angle     = baseAngle + t * spinSpeed

                    -- Sword center at orbit position
                    local cx = hrpPos.X + math.cos(angle) * spinRadius
                    local cz = hrpPos.Z + math.sin(angle) * spinRadius
                    local cy = hrpY + 2  -- float at mid-body height

                    -- Sword points outward from player (away from center)
                    -- Direction the sword points: same as orbit tangent rotated 90 = radial outward
                    -- We want blade tip pointing outward, handle toward player
                    local offset = SWORD_LAYOUT[swordIdx <= SWORD_COUNT and swordIdx or 1][blockIdx]

                    -- Rotate offset so sword faces outward along orbit tangent
                    -- sword Z axis -> outward radial direction
                    local radialX = math.cos(angle)
                    local radialZ = math.sin(angle)
                    -- tangent (sword X axis, crossguard direction)
                    local tangX = -math.sin(angle)
                    local tangZ =  math.cos(angle)

                    -- Transform local offset to world
                    -- local X -> tangent, local Y -> up, local Z -> radial outward
                    local worldX = cx + offset.X * tangX + offset.Z * radialX
                    local worldY = cy + offset.Y
                    local worldZ = cz + offset.X * tangZ + offset.Z * radialZ

                    -- Tilt blade slightly upward (30 degree lean back = cool look)
                    local tilt = math.sin(angle) * 0.4
                    worldY = worldY + offset.Z * 0.3 + tilt * 0.1

                    data.bp.Position = Vector3.new(worldX, worldY, worldZ)

                    -- Orientation: sword faces outward, handle down slightly
                    local lookAt = Vector3.new(cx + radialX*10, cy, cz + radialZ*10)
                    data.bg.CFrame = CFrame.lookAt(
                        Vector3.new(worldX, worldY, worldZ),
                        lookAt
                    )
                end
            end
        end
    end)
end

local function deactivateSwords()
    swordActive = false
    if swordHeart then swordHeart:Disconnect(); swordHeart=nil end
    if hoverActive then
        -- also kill hover since it depends on swords
        hoverActive = false
        if hoverHeart then hoverHeart:Disconnect(); hoverHeart=nil end
        setCharNoclip(false)
        local char = player.Character
        if char then
            local hrp = char:FindFirstChild("HumanoidRootPart")
            if hrp then
                local bv = hrp:FindFirstChildOfClass("BodyVelocity")
                if bv then bv:Destroy() end
                local bg2 = hrp:FindFirstChildOfClass("BodyGyro")
                if bg2 then bg2:Destroy() end
                local hum = char:FindFirstChildOfClass("Humanoid")
                if hum then hum.PlatformStand = false end
            end
        end
    end
    releasePool(swordControlled)
    swordOrder = {}
    swordPartCount = 0
    hoverSwordPart = nil
end

-- ============================================================
-- ====================  HOVER  ===============================
-- ============================================================
-- ?hover: swords gather flat under your feet and stay there
-- as you walk. No flying. Just sword platform at feet.
-- ?land: swords return to normal orbit.

local function doHover()
    if not swordActive then
        activateSwords()
        task.wait(0.5)
    end

    hoverActive = true

    if hoverHeart then hoverHeart:Disconnect() end
    hoverHeart = RunService.Heartbeat:Connect(function()
        if not hoverActive or not scriptAlive then return end
        local char = player.Character; if not char then return end
        local hrp  = char:FindFirstChild("HumanoidRootPart"); if not hrp then return end

        local pos = hrp.Position
        local t   = tick()

        -- Arrange all sword blocks in a flat ring directly under player feet
        local total = #swordOrder
        for idx, part in ipairs(swordOrder) do
            local data = swordControlled[part]
            if data and data.bp and data.bp.Parent then
                -- Spread into a flat rosette under feet
                local a      = (idx / total) * math.pi * 2 + t * 0.3
                local ring   = 1 + (idx % 3) * 0.8  -- 3 rings of density
                data.bp.Position = Vector3.new(
                    pos.X + math.cos(a) * ring,
                    pos.Y - 3.2,          -- just below feet
                    pos.Z + math.sin(a) * ring
                )
                -- All blocks lay flat (face upward)
                data.bg.CFrame = CFrame.new(data.bp.Position)
                    * CFrame.Angles(0, a, 0)
            end
        end
    end)
end

local function doLand()
    hoverActive = false
    if hoverHeart then hoverHeart:Disconnect(); hoverHeart=nil end
    -- Resume normal sword orbit
    if swordActive then
        if swordHeart then swordHeart:Disconnect(); swordHeart=nil end
        activateSwords()
    end
end

-- ============================================================
-- ====================  ATTACK SYSTEM  =======================
-- ============================================================
-- ?attack <partialName> <count 1-5>
-- Sends <count> sword blocks flying at target player's HRP

local attackConns = {}  -- cleanup connections

local function doAttack(targetPlayer, count)
    if not swordActive or #swordOrder == 0 then return end
    count = math.clamp(count, 1, math.min(5, #swordOrder))

    local targetChar = targetPlayer.Character
    if not targetChar then return end
    local targetHRP = targetChar:FindFirstChild("HumanoidRootPart")
                   or targetChar:FindFirstChild("Torso")
    if not targetHRP then return end

    -- Pick the first <count> sword parts
    local attackParts = {}
    for i = 1, count do
        if swordOrder[i] then table.insert(attackParts, swordOrder[i]) end
    end

    for idx, part in ipairs(attackParts) do
        local data = swordControlled[part]
        if data and data.bp and data.bp.Parent then
            -- Crank up speed massively for attack
            data.bp.P = 5000000
            data.bp.D = 20000
            data.bp.MaxForce = Vector3.new(1e12, 1e12, 1e12)
        end
    end

    -- Heartbeat: continuously drive toward target (they might move)
    local conn
    local elapsed = 0
    conn = RunService.Heartbeat:Connect(function(dt)
        elapsed = elapsed + dt
        if elapsed > 4 then
            -- After 4 seconds, snap back into orbit
            conn:Disconnect()
            for _, part in ipairs(attackParts) do
                local data = swordControlled[part]
                if data and data.bp and data.bp.Parent then
                    data.bp.P = 300000
                    data.bp.D = 8000
                    data.bp.MaxForce = Vector3.new(1e9,1e9,1e9)
                end
            end
            return
        end

        local tc = targetPlayer.Character
        if not tc then conn:Disconnect(); return end
        local th = tc:FindFirstChild("HumanoidRootPart") or tc:FindFirstChild("Torso")
        if not th then conn:Disconnect(); return end

        local tPos = th.Position
        for i, part in ipairs(attackParts) do
            local data = swordControlled[part]
            if data and data.bp and data.bp.Parent then
                -- Stagger so swords come from slightly different angles (looks like a real stab)
                local spread = (i-1) * 0.5
                data.bp.Position = tPos + Vector3.new(
                    math.sin(tick()*8 + spread) * 0.3,
                    1 + (i-1) * 0.4,
                    math.cos(tick()*8 + spread) * 0.3
                )
                -- Point sword at target
                data.bg.CFrame = CFrame.lookAt(part.Position, tPos)
            end
        end
    end)
    table.insert(attackConns, conn)
end

-- ============================================================
-- ====================  COMMAND HANDLER  =====================
-- ============================================================
local function handleCommand(raw, sender)
    if not isAllowed(sender) then return end
    local cmd = raw:lower():match("^%s*(.-)%s*$")

    -- LAMBO
    if cmd == "!lambo" then
        if not lamboActive then activateLambo() end

    elseif cmd == "!autograb" then
        task.spawn(autoGrabAll)

    elseif cmd == "!stop" then
        deactivateLambo()

    -- DOORS
    elseif cmd == "?open"  then doorState = "both"
    elseif cmd == "?left"  then doorState = "left"
    elseif cmd == "?right" then doorState = "right"
    elseif cmd == "?close" then doorState = "closed"

    -- SEAT
    elseif cmd == "?sit"   then doSit()
    elseif cmd == "?unsit" then doUnsit()

    -- SWORD
    elseif cmd == "!sword" then
        if not swordActive then activateSwords() end

    elseif cmd == "!swordstop" then
        deactivateSwords()

    -- HOVER / FLY
    elseif cmd == "?hover" then
        doHover()

    elseif cmd == "?land" then
        doLand()

    -- ATTACK  ?attack <name> <count>
    elseif cmd:sub(1,7) == "?attack" then
        local args   = {}
        for w in cmd:gmatch("%S+") do table.insert(args, w) end
        -- args[1]="?attack"  args[2]=name  args[3]=count
        if #args >= 3 then
            local targetName = args[2]
            local count      = tonumber(args[3]) or 1
            local target     = findPlayerByName(targetName)
            if target and target ~= player then
                doAttack(target, count)
            end
        end

    -- WHITELIST  .whitelist <name>
    elseif cmd:sub(1,10) == ".whitelist" then
        -- Only the local player (owner) can whitelist
        if sender ~= player then return end
        local args = {}
        for w in cmd:gmatch("%S+") do table.insert(args, w) end
        if #args >= 2 then
            local partial = args[2]
            local target  = findPlayerByName(partial)
            if target then
                whitelist[target.Name:lower()] = true
                print("[Script] Whitelisted: " .. target.Name)
            end
        end
    end
end

-- Listen to local player chat
player.Chatted:Connect(function(msg) handleCommand(msg, player) end)

-- Listen to all other players (for whitelist system)
Players.PlayerAdded:Connect(function(p)
    p.Chatted:Connect(function(msg) handleCommand(msg, p) end)
end)
for _, p in ipairs(Players:GetPlayers()) do
    if p ~= player then
        p.Chatted:Connect(function(msg) handleCommand(msg, p) end)
    end
end

-- ============================================================
-- ====================  GUI  =================================
-- ============================================================
local function createGUI()
    local pg  = player:FindFirstChildOfClass("PlayerGui")
    local old = pg:FindFirstChild("LamboGui")
    if old then old:Destroy() end

    local gui = Instance.new("ScreenGui")
    gui.Name="LamboGui"; gui.ResetOnSpawn=false; gui.DisplayOrder=999; gui.Parent=pg

    -- ── MAIN PANEL ──────────────────────────────────────────
    local panel = Instance.new("Frame", gui)
    panel.Name             = "Panel"
    panel.Size             = UDim2.fromOffset(230, 10)  -- height set dynamically below
    panel.Position         = UDim2.new(0, 12, 0, 8)
    panel.BackgroundColor3 = Color3.fromRGB(8, 8, 12)
    panel.BorderSizePixel  = 0
    Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 10)

    local function makeDivLine(y)
        local d = Instance.new("Frame", panel)
        d.Size=UDim2.new(1,-12,0,1); d.Position=UDim2.fromOffset(6,y)
        d.BackgroundColor3=Color3.fromRGB(28,28,38); d.BorderSizePixel=0
    end

    -- Accent bar
    local accent = Instance.new("Frame", panel)
    accent.Size=UDim2.new(1,0,0,4); accent.BackgroundColor3=YELLOW; accent.BorderSizePixel=0
    Instance.new("UICorner", accent).CornerRadius = UDim.new(0,10)

    -- Title
    local title = Instance.new("TextLabel", panel)
    title.Size=UDim2.new(1,-38,0,24); title.Position=UDim2.fromOffset(8,7)
    title.BackgroundTransparency=1; title.Text="LAMBORGHINI + SWORD"
    title.TextColor3=YELLOW; title.TextSize=11; title.Font=Enum.Font.GothamBold
    title.TextXAlignment=Enum.TextXAlignment.Left

    local sub = Instance.new("TextLabel", panel)
    sub.Size=UDim2.new(1,-12,0,12); sub.Position=UDim2.fromOffset(8,28)
    sub.BackgroundTransparency=1; sub.Text="FORMATION SCRIPT  v3"
    sub.TextColor3=Color3.fromRGB(80,80,80); sub.TextSize=7; sub.Font=Enum.Font.Gotham
    sub.TextXAlignment=Enum.TextXAlignment.Left

    makeDivLine(44)

    -- STATUS LABELS
    local statusLbl = Instance.new("TextLabel", panel)
    statusLbl.Size=UDim2.new(1,-12,0,14); statusLbl.Position=UDim2.fromOffset(8,48)
    statusLbl.BackgroundTransparency=1; statusLbl.TextSize=8; statusLbl.Font=Enum.Font.GothamBold
    statusLbl.TextXAlignment=Enum.TextXAlignment.Left

    local swordStatusLbl = Instance.new("TextLabel", panel)
    swordStatusLbl.Size=UDim2.new(1,-12,0,14); swordStatusLbl.Position=UDim2.fromOffset(8,62)
    swordStatusLbl.BackgroundTransparency=1; swordStatusLbl.TextSize=8; swordStatusLbl.Font=Enum.Font.GothamBold
    swordStatusLbl.TextXAlignment=Enum.TextXAlignment.Left

    -- BLOCK COUNTER
    local lamboCountLbl = Instance.new("TextLabel", panel)
    lamboCountLbl.Size=UDim2.new(1,-12,0,12); lamboCountLbl.Position=UDim2.fromOffset(8,78)
    lamboCountLbl.BackgroundTransparency=1; lamboCountLbl.TextSize=7; lamboCountLbl.Font=Enum.Font.Gotham
    lamboCountLbl.TextXAlignment=Enum.TextXAlignment.Left

    -- Progress bar for lambo
    local barBg = Instance.new("Frame", panel)
    barBg.Size=UDim2.new(1,-12,0,5); barBg.Position=UDim2.fromOffset(6,92)
    barBg.BackgroundColor3=Color3.fromRGB(20,20,30); barBg.BorderSizePixel=0
    Instance.new("UICorner", barBg).CornerRadius=UDim.new(0,3)

    local barFill = Instance.new("Frame", barBg)
    barFill.Size=UDim2.fromScale(0,1); barFill.BackgroundColor3=YELLOW; barFill.BorderSizePixel=0
    Instance.new("UICorner", barFill).CornerRadius=UDim.new(0,3)

    local swordCountLbl = Instance.new("TextLabel", panel)
    swordCountLbl.Size=UDim2.new(1,-12,0,12); swordCountLbl.Position=UDim2.fromOffset(8,100)
    swordCountLbl.BackgroundTransparency=1; swordCountLbl.TextSize=7; swordCountLbl.Font=Enum.Font.Gotham
    swordCountLbl.TextXAlignment=Enum.TextXAlignment.Left

    -- Progress bar for swords
    local swordBarBg = Instance.new("Frame", panel)
    swordBarBg.Size=UDim2.new(1,-12,0,5); swordBarBg.Position=UDim2.fromOffset(6,114)
    swordBarBg.BackgroundColor3=Color3.fromRGB(20,20,30); swordBarBg.BorderSizePixel=0
    Instance.new("UICorner", swordBarBg).CornerRadius=UDim.new(0,3)

    local swordBarFill = Instance.new("Frame", swordBarBg)
    swordBarFill.Size=UDim2.fromScale(0,1); swordBarFill.BackgroundColor3=SWORD_BLADE
    swordBarFill.BorderSizePixel=0
    Instance.new("UICorner", swordBarFill).CornerRadius=UDim.new(0,3)

    makeDivLine(123)

    -- ── SPIN RADIUS SLIDER ──────────────────────────────────
    local sliderY = 128
    local sliderLbl = Instance.new("TextLabel", panel)
    sliderLbl.Size=UDim2.new(1,-12,0,13); sliderLbl.Position=UDim2.fromOffset(8,sliderY)
    sliderLbl.BackgroundTransparency=1
    sliderLbl.Text="SWORD SPIN RADIUS:  " .. spinRadius .. " studs"
    sliderLbl.TextColor3=Color3.fromRGB(160,160,180); sliderLbl.TextSize=7
    sliderLbl.Font=Enum.Font.GothamBold; sliderLbl.TextXAlignment=Enum.TextXAlignment.Left

    local sliderTrack = Instance.new("Frame", panel)
    sliderTrack.Size=UDim2.new(1,-20,0,8); sliderTrack.Position=UDim2.fromOffset(10,sliderY+15)
    sliderTrack.BackgroundColor3=Color3.fromRGB(25,25,40); sliderTrack.BorderSizePixel=0
    Instance.new("UICorner", sliderTrack).CornerRadius=UDim.new(0,4)

    local sliderFill = Instance.new("Frame", sliderTrack)
    sliderFill.Size=UDim2.fromScale(spinRadius/25, 1)
    sliderFill.BackgroundColor3=SWORD_BLADE; sliderFill.BorderSizePixel=0
    Instance.new("UICorner", sliderFill).CornerRadius=UDim.new(0,4)

    local sliderKnob = Instance.new("TextButton", sliderTrack)
    sliderKnob.Size=UDim2.fromOffset(14,14)
    sliderKnob.Position=UDim2.new(spinRadius/25,-7,0.5,-7)
    sliderKnob.BackgroundColor3=Color3.fromRGB(220,230,255); sliderKnob.BorderSizePixel=0
    sliderKnob.Text=""; Instance.new("UICorner",sliderKnob).CornerRadius=UDim.new(1,0)

    -- Drag logic for slider
    local sliderDragging = false
    sliderKnob.InputBegan:Connect(function(inp)
        if inp.UserInputType==Enum.UserInputType.MouseButton1
        or inp.UserInputType==Enum.UserInputType.Touch then
            sliderDragging = true
        end
    end)
    UserInputService.InputChanged:Connect(function(inp)
        if not sliderDragging then return end
        if inp.UserInputType==Enum.UserInputType.MouseMovement
        or inp.UserInputType==Enum.UserInputType.Touch then
            local trackPos   = sliderTrack.AbsolutePosition
            local trackWidth = sliderTrack.AbsoluteSize.X
            local relX = math.clamp(inp.Position.X - trackPos.X, 0, trackWidth)
            local pct  = relX / trackWidth
            spinRadius = math.floor(pct * 25 + 0.5)  -- 0-25 studs
            spinRadius = math.max(3, spinRadius)
            sliderFill.Size = UDim2.fromScale(pct, 1)
            sliderKnob.Position = UDim2.new(pct,-7,0.5,-7)
            sliderLbl.Text = "SWORD SPIN RADIUS:  " .. spinRadius .. " studs"
        end
    end)
    UserInputService.InputEnded:Connect(function(inp)
        if inp.UserInputType==Enum.UserInputType.MouseButton1
        or inp.UserInputType==Enum.UserInputType.Touch then
            sliderDragging = false
        end
    end)

    makeDivLine(sliderY + 28)

    -- ── BUTTONS ──────────────────────────────────────────────
    local btnY = sliderY + 34
    local PW   = 230

    local function makeBtn(lbl, bg, tx, cb)
        local b = Instance.new("TextButton", panel)
        b.Size=UDim2.fromOffset(PW-18,24); b.Position=UDim2.fromOffset(9,btnY)
        b.BackgroundColor3=bg; b.TextColor3=tx; b.Text=lbl
        b.TextSize=8; b.Font=Enum.Font.GothamBold; b.BorderSizePixel=0
        Instance.new("UICorner",b).CornerRadius=UDim.new(0,5)
        b.MouseButton1Click:Connect(cb)
        btnY = btnY + 27
    end

    local function makeHalf(lLbl,lBg,lTx,lCb, rLbl,rBg,rTx,rCb)
        local hw = math.floor((PW-18-6)/2)
        local function half(lbl,bg,tx,cb,xo)
            local b = Instance.new("TextButton",panel)
            b.Size=UDim2.fromOffset(hw,24); b.Position=UDim2.fromOffset(9+xo,btnY)
            b.BackgroundColor3=bg; b.TextColor3=tx; b.Text=lbl
            b.TextSize=8; b.Font=Enum.Font.GothamBold; b.BorderSizePixel=0
            Instance.new("UICorner",b).CornerRadius=UDim.new(0,5)
            b.MouseButton1Click:Connect(cb)
        end
        half(lLbl,lBg,lTx,lCb,0); half(rLbl,rBg,rTx,rCb,hw+6)
        btnY = btnY + 27
    end

    local function sectionHead(txt)
        local lbl = Instance.new("TextLabel",panel)
        lbl.Size=UDim2.new(1,-12,0,13); lbl.Position=UDim2.fromOffset(8,btnY)
        lbl.BackgroundTransparency=1; lbl.Text=txt
        lbl.TextColor3=Color3.fromRGB(90,90,120); lbl.TextSize=7
        lbl.Font=Enum.Font.GothamBold; lbl.TextXAlignment=Enum.TextXAlignment.Left
        btnY = btnY + 15
    end

    -- LAMBO section
    sectionHead("-- LAMBO --")
    makeBtn("SCAN BLOCKS",   Color3.fromRGB(12,30,12), Color3.fromRGB(80,255,100), function() sweepInto(lamboControlled,nil) end)
    makeBtn("AUTO-GRAB ALL ANCHORED", Color3.fromRGB(8,28,40), Color3.fromRGB(80,220,255), function()
        task.spawn(autoGrabAll)
    end)
    makeBtn("ACTIVATE LAMBO",Color3.fromRGB(50,38,0),  YELLOW, function()
        if not lamboActive then activateLambo() end
    end)
    makeBtn("DEACTIVATE",    Color3.fromRGB(50,10,10), Color3.fromRGB(255,70,70), function()
        deactivateLambo()
    end)
    makeBtn("RESCAN + RECOLOR",Color3.fromRGB(10,20,40),Color3.fromRGB(80,160,255),function()
        sweepInto(lamboControlled,nil); applyLamboColors()
    end)

    -- DOORS section
    btnY=btnY+2; makeDivLine(btnY); btnY=btnY+6
    sectionHead("-- DOORS --")
    makeHalf(
        "LEFT DOOR",  Color3.fromRGB(35,30,5), YELLOW, function() doorState="left"  end,
        "RIGHT DOOR", Color3.fromRGB(35,30,5), YELLOW, function() doorState="right" end
    )
    makeBtn("OPEN BOTH DOORS", Color3.fromRGB(45,35,0),  YELLOW,                    function() doorState="both"   end)
    makeBtn("CLOSE ALL DOORS", Color3.fromRGB(35,12,12), Color3.fromRGB(220,80,80), function() doorState="closed" end)

    -- SEAT section
    btnY=btnY+2; makeDivLine(btnY); btnY=btnY+6
    sectionHead("-- DRIVER SEAT --")
    makeHalf(
        "SIT",   Color3.fromRGB(10,30,10), Color3.fromRGB(80,255,100), function() doSit()   end,
        "UNSIT", Color3.fromRGB(35,12,12), Color3.fromRGB(255,100,80), function() doUnsit() end
    )

    -- SWORD section
    btnY=btnY+2; makeDivLine(btnY); btnY=btnY+6
    sectionHead("-- SWORD --")
    makeHalf(
        "ACTIVATE SWORDS", Color3.fromRGB(20,10,40), SWORD_BLADE, function()
            if not swordActive then activateSwords() end
        end,
        "STOP SWORDS", Color3.fromRGB(35,12,12), Color3.fromRGB(255,80,80), function()
            deactivateSwords()
        end
    )
    makeHalf(
        "HOVER / FLY", Color3.fromRGB(10,20,40), Color3.fromRGB(80,180,255), function() doHover() end,
        "LAND",        Color3.fromRGB(20,30,10), Color3.fromRGB(80,255,130), function() doLand()  end
    )

    -- COMMANDS cheat sheet
    btnY=btnY+2; makeDivLine(btnY); btnY=btnY+6
    sectionHead("-- CHAT COMMANDS --")

    local cmdList = {
        {"!lambo",              "Build + activate Lambo"},
        {"!stop",               "Release Lambo blocks"},
        {"!autograb",           "TP to every anchored block + grab"},
        {"!sword",              "Spin 5 swords around you"},
        {"!swordstop",          "Release sword blocks"},
        {"?open / ?left / ?right","Open scissor doors"},
        {"?close",              "Close doors"},
        {"?sit / ?unsit",       "Enter / exit car"},
        {"?hover",              "Sword platform at your feet"},
        {"?land",               "Return swords to orbit"},
        {"?attack <name> <1-5>","Fire swords at player"},
        {".whitelist <name>",   "Allow player to use cmds"},
    }

    for _, c in ipairs(cmdList) do
        local row = Instance.new("Frame", panel)
        row.Size=UDim2.new(1,-12,0,11); row.Position=UDim2.fromOffset(6,btnY)
        row.BackgroundTransparency=1

        local kLbl = Instance.new("TextLabel", row)
        kLbl.Size=UDim2.fromOffset(90,11); kLbl.BackgroundTransparency=1
        kLbl.Text=c[1]; kLbl.TextColor3=YELLOW
        kLbl.TextSize=6; kLbl.Font=Enum.Font.GothamBold
        kLbl.TextXAlignment=Enum.TextXAlignment.Left

        local vLbl = Instance.new("TextLabel", row)
        vLbl.Size=UDim2.new(1,-92,1,0); vLbl.Position=UDim2.fromOffset(92,0)
        vLbl.BackgroundTransparency=1; vLbl.Text=c[2]
        vLbl.TextColor3=Color3.fromRGB(110,110,140); vLbl.TextSize=6
        vLbl.Font=Enum.Font.Gotham; vLbl.TextXAlignment=Enum.TextXAlignment.Left

        btnY = btnY + 12
    end

    -- Final panel height
    panel.Size = UDim2.fromOffset(PW, btnY + 10)

    -- Close button
    local closeBtn = Instance.new("TextButton", panel)
    closeBtn.Size=UDim2.fromOffset(20,20); closeBtn.Position=UDim2.new(1,-24,0,6)
    closeBtn.BackgroundColor3=Color3.fromRGB(30,10,10); closeBtn.TextColor3=Color3.fromRGB(200,80,80)
    closeBtn.Text="X"; closeBtn.TextSize=9; closeBtn.Font=Enum.Font.GothamBold; closeBtn.BorderSizePixel=0
    Instance.new("UICorner",closeBtn).CornerRadius=UDim.new(0,4)
    closeBtn.MouseButton1Click:Connect(function()
        gui:Destroy()
        local mini = Instance.new("ScreenGui")
        mini.Name="LamboIcon"; mini.ResetOnSpawn=false; mini.DisplayOrder=999; mini.Parent=pg
        local ib = Instance.new("TextButton", mini)
        ib.Size=UDim2.fromOffset(36,36); ib.Position=UDim2.new(0,12,0,8)
        ib.BackgroundColor3=DARK; ib.TextColor3=YELLOW; ib.Text="L"
        ib.TextSize=14; ib.Font=Enum.Font.GothamBold; ib.BorderSizePixel=0
        Instance.new("UICorner",ib).CornerRadius=UDim.new(0,8)
        ib.MouseButton1Click:Connect(function() mini:Destroy(); createGUI() end)
    end)

    -- Drag panel
    local dragging,ds,dp = false,Vector2.zero,UDim2.new()
    panel.InputBegan:Connect(function(inp)
        if inp.UserInputType==Enum.UserInputType.MouseButton1
        or inp.UserInputType==Enum.UserInputType.Touch then
            dragging=true; ds=Vector2.new(inp.Position.X,inp.Position.Y); dp=panel.Position
        end
    end)
    UserInputService.InputChanged:Connect(function(inp)
        if not dragging then return end
        if inp.UserInputType==Enum.UserInputType.MouseMovement
        or inp.UserInputType==Enum.UserInputType.Touch then
            local d=Vector2.new(inp.Position.X,inp.Position.Y)-ds
            panel.Position=UDim2.new(dp.X.Scale,dp.X.Offset+d.X,dp.Y.Scale,dp.Y.Offset+d.Y)
        end
    end)
    UserInputService.InputEnded:Connect(function(inp)
        if inp.UserInputType==Enum.UserInputType.MouseButton1
        or inp.UserInputType==Enum.UserInputType.Touch then dragging=false end
    end)

    -- Live status update
    task.spawn(function()
        while gui.Parent and scriptAlive do
            -- Lambo status
            statusLbl.Text      = lamboActive and "LAMBO: ACTIVE" or "LAMBO: IDLE  (say !lambo)"
            statusLbl.TextColor3 = lamboActive and YELLOW or Color3.fromRGB(60,60,70)

            -- Sword status
            local swordTxt = hoverActive and "SWORD: FLYING" or (swordActive and "SWORD: ACTIVE" or "SWORD: OFF  (say !sword)")
            swordStatusLbl.Text      = swordTxt
            swordStatusLbl.TextColor3 = hoverActive and Color3.fromRGB(80,180,255) or (swordActive and SWORD_BLADE or Color3.fromRGB(60,60,70))

            -- Lambo counter
            local lSlots = #lamboSlots
            local lUsed  = math.min(lamboPartCount, lSlots)
            local lPct   = lSlots>0 and lUsed/lSlots or 0
            lamboCountLbl.Text = "  Lambo blocks: " .. lUsed .. " / " .. lSlots
                .. "  (" .. math.floor(lPct*100) .. "%)"
            lamboCountLbl.TextColor3 = lPct>=1 and Color3.fromRGB(80,255,80) or Color3.fromRGB(160,160,180)
            barFill.Size = UDim2.fromScale(lPct,1)
            barFill.BackgroundColor3 = lPct>=1 and Color3.fromRGB(80,255,80)
                                    or lPct>=0.5 and YELLOW
                                    or Color3.fromRGB(255,100,40)

            -- Sword counter
            local sUsed = swordPartCount
            local sNeed = TOTAL_SWORD_BLOCKS
            local sPct  = math.clamp(sUsed/sNeed, 0, 1)
            swordCountLbl.Text = "  Sword blocks: " .. sUsed .. " / " .. sNeed
                .. "  (" .. math.floor(sPct*100) .. "%)"
            swordCountLbl.TextColor3 = sPct>=1 and Color3.fromRGB(80,255,80) or SWORD_BLADE
            swordBarFill.Size = UDim2.fromScale(sPct,1)

            task.wait(0.25)
        end
    end)
end

-- ============================================================
-- INIT
-- ============================================================
lamboSlots = buildLamboPositions()
print("[Script v3] Ready.  " .. #lamboSlots .. " lambo slots.  " .. TOTAL_SWORD_BLOCKS .. " sword blocks needed.")
print("[Script v3] Commands: !lambo | !stop | !sword | !swordstop | ?hover | ?land | ?attack <name> <1-5> | .whitelist <name>")

createGUI()

-- Periodic rescan
task.spawn(function()
    while scriptAlive do
        task.wait(5)
        if lamboActive then
            sweepInto(lamboControlled, nil)
            lamboPartCount = 0
            for _ in pairs(lamboControlled) do lamboPartCount=lamboPartCount+1 end
        end
    end
end)

-- Reset on respawn
player.CharacterAdded:Connect(function()
    task.wait(0.5)
    isSeated   = false
    hoverActive = false
    if noclipConn then noclipConn:Disconnect(); noclipConn=nil end
    if hoverHeart then hoverHeart:Disconnect(); hoverHeart=nil end
    if lamboActive then sweepInto(lamboControlled, nil) end
end)
