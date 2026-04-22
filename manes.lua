-- ╔══════════════════════════════════════════════════════╗
-- ║   Hack Event  •  Meteor UI  •  v5                   ║
-- ║   3D box, centered tracer, fixed auto shoot         ║
-- ╚══════════════════════════════════════════════════════╝

local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService     = game:GetService("TweenService")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

-- ══════════════════ CONFIG ══════════════════
local HOLD_TIME   = 0.38
local SHOOT_DELAY = 0.14
local MIN_R, MAX_R = 60, 420

-- ══════════════════ PALETTE ══════════════════
local BG     = Color3.fromRGB( 10,  10,  18)
local BG2    = Color3.fromRGB( 16,  14,  30)
local HDR    = Color3.fromRGB( 22,  20,  50)
local ROW    = Color3.fromRGB( 24,  22,  44)
local ROW_ON = Color3.fromRGB( 18,  28,  80)
local BDR    = Color3.fromRGB( 80,  60, 210)
local BLUE   = Color3.fromRGB(100,  80, 255)
local BLUE2  = Color3.fromRGB( 48,  36, 148)
local TEXT   = Color3.fromRGB(222, 220, 252)
local DIM    = Color3.fromRGB(145, 142, 178)
local OFF    = Color3.fromRGB( 52,  50,  80)
local RED    = Color3.fromRGB(255,  55,  55)
local GREEN  = Color3.fromRGB( 55, 225, 100)
local YLW    = Color3.fromRGB(255, 210,  50)
local ESP_C  = Color3.fromRGB( 80, 130, 255)

-- ══════════════════ STATE ══════════════════
local S = {
    aimbot = { enabled=false, radius=180, throughWalls=true, autoShoot=false },
    esp    = { enabled=false, box=true, tracer=true, health=true,
               showName=true, distance=true },
}
local aimTarget, aimHL, lastShot = nil, nil, 0
local espObjs = {}

-- ══════════════════ 3-D BOX DATA ══════════════════
local HW, HD, YT, YB = 1.15, 0.55, 2.85, -2.85
local CORNERS = {
    Vector3.new(-HW, YB, -HD), Vector3.new( HW, YB, -HD),
    Vector3.new( HW, YB,  HD), Vector3.new(-HW, YB,  HD),
    Vector3.new(-HW, YT, -HD), Vector3.new( HW, YT, -HD),
    Vector3.new( HW, YT,  HD), Vector3.new(-HW, YT,  HD),
}
local EDGES = {
    {1,2},{2,3},{3,4},{4,1},   -- bottom
    {5,6},{6,7},{7,8},{8,5},   -- top
    {1,5},{2,6},{3,7},{4,8},   -- pillars
}

-- ══════════════════ SCREEN GUI ══════════════════
local sg = Instance.new("ScreenGui")
sg.Name="HE"; sg.ResetOnSpawn=false
sg.IgnoreGuiInset=true; sg.ZIndexBehavior=Enum.ZIndexBehavior.Sibling
sg.Parent = player.PlayerGui

-- ══════════════════ UTILITY ══════════════════
local TI = TweenInfo.new(0.14, Enum.EasingStyle.Quad)

local function mk(cls, props, parent)
    local i = Instance.new(cls)
    for k,v in pairs(props) do i[k]=v end
    if parent then i.Parent=parent end
    return i
end

local function corner(p, r)
    mk("UICorner",{CornerRadius=UDim.new(0,r or 6)},p); return p
end

local function stroke(p, col, th)
    mk("UIStroke",{Color=col or BDR, Thickness=th or 0.8},p); return p
end

local function fixBot(p, h, col)     -- square off bottom corners of rounded header
    mk("Frame",{Size=UDim2.new(1,0,0,h or 8),Position=UDim2.new(0,0,1,-(h or 8)),
                BackgroundColor3=col or HDR,BorderSizePixel=0},p)
end

local function drawEdge(f, ax,ay,az, bx,by,bz)
    if az<=0 or bz<=0 then f.Visible=false; return end
    local dx,dy = bx-ax, by-ay
    local ln = math.sqrt(dx*dx+dy*dy)
    if ln<0.5 then f.Visible=false; return end
    f.AnchorPoint = Vector2.new(0,0.5)
    f.Position    = UDim2.new(0,ax,0,ay)
    f.Size        = UDim2.new(0,ln,0,1.5)
    f.Rotation    = math.deg(math.atan2(dy,dx))
    f.Visible     = true
end

local function mkLine(zi, col)
    return mk("Frame",{BackgroundColor3=col or ESP_C,BorderSizePixel=0,
                       AnchorPoint=Vector2.new(0,0.5),ZIndex=zi or 2,Visible=false},sg)
end

-- ══════════════════ CROSSHAIR ══════════════════
local cRing = corner(mk("Frame",{
    BackgroundTransparency=1,BorderSizePixel=0,ZIndex=4,Visible=false},sg),500)
local cRS = mk("UIStroke",{Color=BLUE,Thickness=2},cRing)

local cDot = corner(mk("Frame",{
    Size=UDim2.new(0,7,0,7),BackgroundColor3=TEXT,
    BorderSizePixel=0,ZIndex=5,Visible=false},sg),500)

local cLH = mk("Frame",{Size=UDim2.new(0,20,0,2),BackgroundColor3=TEXT,
    BorderSizePixel=0,ZIndex=5,Visible=false},sg)
local cLV = mk("Frame",{Size=UDim2.new(0,2,0,20),BackgroundColor3=TEXT,
    BorderSizePixel=0,ZIndex=5,Visible=false},sg)

local function updCross()
    local r = S.aimbot.radius
    cRing.Size     = UDim2.new(0,r*2,0,r*2)
    cRing.Position = UDim2.new(0.5,-r,0.5,-r)
    cDot.Position  = UDim2.new(0.5,-3,0.5,-3)
    cLH.Position   = UDim2.new(0.5,-10,0.5,-1)
    cLV.Position   = UDim2.new(0.5,-1,0.5,-10)
end

local function crossCol(t)
    local c = t and RED or BLUE
    cRS.Color=c; cDot.BackgroundColor3=c; cLH.BackgroundColor3=c; cLV.BackgroundColor3=c
end

local function crossVis(v)
    cRing.Visible=v; cDot.Visible=v; cLH.Visible=v; cLV.Visible=v
end

updCross()

-- ══════════════════ SETTINGS OVERLAY ══════════════════
local ov = mk("Frame",{Size=UDim2.new(1,0,1,0),BackgroundColor3=Color3.new(0,0,0),
    BackgroundTransparency=0.48,BorderSizePixel=0,ZIndex=30,Visible=false},sg)

local sBox = corner(mk("Frame",{
    AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.new(0.5,0,0.5,0),
    Size=UDim2.new(0,310,0,80),BackgroundColor3=BG2,
    BorderSizePixel=0,ZIndex=31},ov),8)
stroke(sBox,BLUE,1)

local sHdr = mk("Frame",{Size=UDim2.new(1,0,0,48),BackgroundColor3=HDR,
    BorderSizePixel=0,ZIndex=32},sBox)
corner(sHdr,8); fixBot(sHdr,8,HDR)

local backBtn = corner(mk("TextButton",{
    Text="←",Size=UDim2.new(0,38,0,30),Position=UDim2.new(0,8,0.5,-15),
    BackgroundColor3=BLUE2,TextColor3=TEXT,TextSize=18,
    Font=Enum.Font.GothamBold,BorderSizePixel=0,ZIndex=33},sHdr),5)

local sTitleL = mk("TextLabel",{
    Size=UDim2.new(1,-58,1,0),Position=UDim2.new(0,54,0,0),
    BackgroundTransparency=1,TextColor3=TEXT,TextSize=16,
    Font=Enum.Font.GothamBold,TextXAlignment=Enum.TextXAlignment.Left,ZIndex=33},sHdr)

local sCont = mk("Frame",{
    Position=UDim2.new(0,10,0,54),Size=UDim2.new(1,-20,1,-62),
    BackgroundTransparency=1,ZIndex=32},sBox)
local sLL = mk("UIListLayout",{Padding=UDim.new(0,5),SortOrder=Enum.SortOrder.LayoutOrder},sCont)

local slConns = {}

local function clearSettings()
    for _,c in ipairs(slConns) do c:Disconnect() end
    table.clear(slConns)
    for _,c in ipairs(sCont:GetChildren()) do
        if not c:IsA("UIListLayout") then c:Destroy() end
    end
end

backBtn.MouseButton1Click:Connect(function()
    ov.Visible=false; clearSettings()
end)

-- Settings row builders
local function mkSTog(lbl,init,cb,order)
    local row = corner(mk("Frame",{Size=UDim2.new(1,0,0,44),BackgroundColor3=ROW,
        BorderSizePixel=0,ZIndex=33,LayoutOrder=order or 1},sCont),7)
    mk("TextLabel",{Text=lbl,Size=UDim2.new(1,-62,1,0),Position=UDim2.new(0,13,0,0),
        BackgroundTransparency=1,TextColor3=TEXT,TextSize=14,
        Font=Enum.Font.Gotham,TextXAlignment=Enum.TextXAlignment.Left,ZIndex=34},row)
    local bg = corner(mk("Frame",{Size=UDim2.new(0,46,0,26),Position=UDim2.new(1,-54,0.5,-13),
        BackgroundColor3=init and BLUE or OFF,BorderSizePixel=0,ZIndex=34},row),500)
    local kn = corner(mk("Frame",{Size=UDim2.new(0,20,0,20),
        Position=init and UDim2.new(1,-23,0.5,-10) or UDim2.new(0,3,0.5,-10),
        BackgroundColor3=Color3.new(1,1,1),BorderSizePixel=0,ZIndex=35},bg),500)
    local st={v=init}
    local hit=mk("TextButton",{Size=UDim2.new(1,0,1,0),BackgroundTransparency=1,
        Text="",ZIndex=35},row)
    hit.MouseButton1Click:Connect(function()
        st.v=not st.v
        TweenService:Create(bg,TI,{BackgroundColor3=st.v and BLUE or OFF}):Play()
        TweenService:Create(kn,TI,{Position=st.v and UDim2.new(1,-23,0.5,-10)
            or UDim2.new(0,3,0.5,-10)}):Play()
        cb(st.v)
    end)
end

local function mkSSl(lbl,mn,mx,init,cb,order)
    local row = corner(mk("Frame",{Size=UDim2.new(1,0,0,60),BackgroundColor3=ROW,
        BorderSizePixel=0,ZIndex=33,LayoutOrder=order or 1},sCont),7)
    local valLbl=mk("TextLabel",{Text=lbl.."   "..init,Size=UDim2.new(1,-12,0,24),
        Position=UDim2.new(0,13,0,4),BackgroundTransparency=1,TextColor3=TEXT,TextSize=13,
        Font=Enum.Font.Gotham,TextXAlignment=Enum.TextXAlignment.Left,ZIndex=34},row)
    local trk=corner(mk("Frame",{Size=UDim2.new(1,-26,0,7),Position=UDim2.new(0,13,0,38),
        BackgroundColor3=Color3.fromRGB(38,36,70),BorderSizePixel=0,ZIndex=34},row),500)
    local p0=(init-mn)/(mx-mn)
    local fill=corner(mk("Frame",{Size=UDim2.new(p0,0,1,0),BackgroundColor3=BLUE,
        BorderSizePixel=0,ZIndex=35},trk),500)
    local kn=corner(mk("Frame",{Size=UDim2.new(0,20,0,20),
        Position=UDim2.new(p0,-10,0.5,-10),BackgroundColor3=Color3.new(1,1,1),
        BorderSizePixel=0,ZIndex=36},trk),500)
    local drag=false
    trk.InputBegan:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseButton1
            or i.UserInputType==Enum.UserInputType.Touch then drag=true end
    end)
    trk.InputEnded:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseButton1
            or i.UserInputType==Enum.UserInputType.Touch then drag=false end
    end)
    table.insert(slConns, UserInputService.InputChanged:Connect(function(i)
        if not drag then return end
        if i.UserInputType~=Enum.UserInputType.MouseMovement
            and i.UserInputType~=Enum.UserInputType.Touch then return end
        local ap=trk.AbsolutePosition; local as=trk.AbsoluteSize
        local p=math.clamp((i.Position.X-ap.X)/as.X,0,1)
        local v=math.floor(mn+p*(mx-mn))
        fill.Size=UDim2.new(p,0,1,0); kn.Position=UDim2.new(p,-10,0.5,-10)
        valLbl.Text=lbl.."   "..v; cb(v)
    end))
end

-- open settings for a key
local function openSettings(key)
    clearSettings()
    sTitleL.Text = key:sub(1,1):upper()..key:sub(2).." Settings"
    ov.Visible = true
    if key=="aimbot" then
        mkSSl("Circle radius",MIN_R,MAX_R,S.aimbot.radius,function(v)
            S.aimbot.radius=v; updCross()
        end,1)
        mkSTog("Through walls",S.aimbot.throughWalls,function(v)S.aimbot.throughWalls=v end,2)
        mkSTog("Auto shoot",S.aimbot.autoShoot,function(v)S.aimbot.autoShoot=v end,3)
        sBox.Size=UDim2.new(0,310,0, 48+10+60+44+44+18)
    elseif key=="esp" then
        mkSTog("Box",        S.esp.box,      function(v)S.esp.box=v      end,1)
        mkSTog("Tracer",     S.esp.tracer,   function(v)S.esp.tracer=v   end,2)
        mkSTog("Health bar", S.esp.health,   function(v)S.esp.health=v   end,3)
        mkSTog("Name",       S.esp.showName, function(v)S.esp.showName=v end,4)
        mkSTog("Distance",   S.esp.distance, function(v)S.esp.distance=v end,5)
        sBox.Size=UDim2.new(0,310,0, 48+10+44*5+5*4+18)
    end
end

-- ══════════════════ METEOR PANEL ══════════════════
-- Toggle cube (bottom-right like Meteor logo)
local cube = corner(mk("Frame",{
    Size=UDim2.new(0,50,0,50),AnchorPoint=Vector2.new(1,1),
    Position=UDim2.new(1,-16,1,-80),BackgroundColor3=BLUE2,
    BorderSizePixel=0,ZIndex=10},sg),10)
stroke(cube,BLUE,1)

-- Inner cube decoration
corner(mk("Frame",{Size=UDim2.new(0,28,0,28),AnchorPoint=Vector2.new(0.5,0.5),
    Position=UDim2.new(0.5,0,0.5,0),BackgroundColor3=BLUE,
    BorderSizePixel=0,ZIndex=11},cube),6)
mk("TextLabel",{Text="HE",Size=UDim2.new(1,0,1,0),BackgroundTransparency=1,
    TextColor3=TEXT,TextSize=14,Font=Enum.Font.GothamBold,ZIndex=12},cube)

local cubeBtn = mk("TextButton",{Size=UDim2.new(1,0,1,0),BackgroundTransparency=1,
    Text="",ZIndex=13},cube)

-- Main panel (two columns)
local COL_W = 160
local COL_GAP = 8
local PAD = 8
local PANEL_W = PAD + COL_W + COL_GAP + COL_W + PAD  -- 356
local MOD_H = 38
local HDR_H = 40

local panel = corner(mk("Frame",{
    Size=UDim2.new(0,PANEL_W,0,HDR_H + MOD_H + PAD*2),
    Position=UDim2.new(0.5,-PANEL_W/2,0,60),
    BackgroundColor3=BG,BorderSizePixel=0,
    ClipsDescendants=true,Parent=sg,ZIndex=5}),8)
stroke(panel,BDR,0.8)

-- Drag
local dragging,dragStart,dragOrigin=false
local dTb=mk("Frame",{Size=UDim2.new(1,0,0,40),BackgroundColor3=HDR,
    BorderSizePixel=0,ZIndex=6},panel)
corner(dTb,8); fixBot(dTb,8,HDR)

mk("Frame",{Size=UDim2.new(0,9,0,9),Position=UDim2.new(0,12,0.5,-4),
    BackgroundColor3=BLUE,BorderSizePixel=0,ZIndex=7},dTb)
    :FindFirstChildOfClass("UICorner") -- no-op, just chained. We add it below:
local tdot=dTb:FindFirstChildOfClass("Frame")
if tdot then corner(tdot,500) end

mk("TextLabel",{Text="Hack Event",Size=UDim2.new(1,-30,1,0),Position=UDim2.new(0,28,0,0),
    BackgroundTransparency=1,TextColor3=TEXT,TextSize=17,Font=Enum.Font.GothamBold,
    TextXAlignment=Enum.TextXAlignment.Left,ZIndex=7},dTb)

dTb.InputBegan:Connect(function(i)
    if i.UserInputType==Enum.UserInputType.MouseButton1
        or i.UserInputType==Enum.UserInputType.Touch then
        dragging=true; dragStart=i.Position; dragOrigin=panel.Position
    end
end)
UserInputService.InputChanged:Connect(function(i)
    if dragging and (i.UserInputType==Enum.UserInputType.MouseMovement
        or i.UserInputType==Enum.UserInputType.Touch) then
        local d=i.Position-dragStart
        panel.Position=UDim2.new(dragOrigin.X.Scale,dragOrigin.X.Offset+d.X,
                                  dragOrigin.Y.Scale,dragOrigin.Y.Offset+d.Y)
    end
end)
UserInputService.InputEnded:Connect(function(i)
    if i.UserInputType==Enum.UserInputType.MouseButton1
        or i.UserInputType==Enum.UserInputType.Touch then dragging=false end
end)

-- Panel visibility
local panelVisible = true
cubeBtn.MouseButton1Click:Connect(function()
    panelVisible=not panelVisible
    panel.Visible=panelVisible
end)

-- Columns container
local colsFrame = mk("Frame",{
    Size=UDim2.new(1,-PAD*2,1,-HDR_H-PAD),
    Position=UDim2.new(0,PAD,0,HDR_H+PAD/2),
    BackgroundTransparency=1,ClipsDescendants=false,ZIndex=6},panel)

local modInfo = {}

local function mkCol(parent, xOff, title, key, mods)
    local col = mk("Frame",{
        Size=UDim2.new(0,COL_W,1,0),Position=UDim2.new(0,xOff,0,0),
        BackgroundTransparency=1,ClipsDescendants=false,ZIndex=6},parent)

    -- Column header
    local hdr = corner(mk("Frame",{Size=UDim2.new(1,0,0,HDR_H),
        BackgroundColor3=HDR,BorderSizePixel=0,ZIndex=7},col),6)
    stroke(hdr,BDR,0.7)

    local dot = corner(mk("Frame",{Size=UDim2.new(0,7,0,7),
        Position=UDim2.new(0,10,0.5,-3),BackgroundColor3=DIM,
        BorderSizePixel=0,ZIndex=8},hdr),500)

    mk("TextLabel",{Text=title,Size=UDim2.new(1,-28,1,0),Position=UDim2.new(0,24,0,0),
        BackgroundTransparency=1,TextColor3=TEXT,TextSize=14,
        Font=Enum.Font.GothamBold,TextXAlignment=Enum.TextXAlignment.Left,ZIndex=8},hdr)

    -- Module rows
    local mFrame=mk("Frame",{Position=UDim2.new(0,0,0,HDR_H+4),
        Size=UDim2.new(1,0,0,#mods*MOD_H),BackgroundTransparency=1,ZIndex=7},col)
    mk("UIListLayout",{Padding=UDim.new(0,3),SortOrder=Enum.SortOrder.LayoutOrder},mFrame)

    local function reflow()
        local es = S[key] and S[key].enabled
        TweenService:Create(dot,TI,{BackgroundColor3=es and BLUE or DIM}):Play()
    end

    for idx,modName in ipairs(mods) do
        local mkey = modName:lower()
        local row = corner(mk("Frame",{Size=UDim2.new(1,0,0,MOD_H-3),
            BackgroundColor3=ROW,BorderSizePixel=0,ZIndex=8,LayoutOrder=idx},mFrame),6)
        stroke(row,BDR,0.5)

        local mdot = corner(mk("Frame",{Size=UDim2.new(0,7,0,7),
            Position=UDim2.new(0,10,0.5,-3),BackgroundColor3=DIM,
            BorderSizePixel=0,ZIndex=9},row),500)

        mk("TextLabel",{Text=modName,Size=UDim2.new(1,-24,1,0),
            Position=UDim2.new(0,23,0,0),BackgroundTransparency=1,
            TextColor3=TEXT,TextSize=13,Font=Enum.Font.Gotham,
            TextXAlignment=Enum.TextXAlignment.Left,ZIndex=9},row)

        local hit=mk("TextButton",{Size=UDim2.new(1,0,1,0),BackgroundTransparency=1,
            Text="",ZIndex=10},row)

        modInfo[mkey]={dot=mdot, row=row}

        -- Tap vs Hold
        local hConn=nil
        hit.InputBegan:Connect(function(i)
            if i.UserInputType==Enum.UserInputType.MouseButton1
                or i.UserInputType==Enum.UserInputType.Touch then
                hConn=task.delay(HOLD_TIME,function()
                    hConn=nil; openSettings(mkey)
                end)
            end
        end)
        hit.InputEnded:Connect(function(i)
            if i.UserInputType==Enum.UserInputType.MouseButton1
                or i.UserInputType==Enum.UserInputType.Touch then
                if hConn then
                    task.cancel(hConn); hConn=nil
                    S[mkey].enabled=not S[mkey].enabled
                    local on=S[mkey].enabled
                    TweenService:Create(mdot,TI,{BackgroundColor3=on and BLUE or DIM}):Play()
                    TweenService:Create(row,TI,{BackgroundColor3=on and ROW_ON or ROW}):Play()
                    if mkey=="aimbot" then
                        crossVis(on)
                        if not on then
                            if aimHL then aimHL:Destroy(); aimHL=nil end
                            aimTarget=nil; crossCol(false)
                        end
                    elseif mkey=="esp" and not on then
                        for _,d in pairs(espObjs) do
                            for _,v in pairs(d) do
                                if typeof(v)=="Instance" then v.Visible=false end
                            end
                            if d.edges then for _,e in ipairs(d.edges) do e.Visible=false end end
                        end
                    end
                    reflow()
                end
            end
        end)
    end

    -- Adjust panel height to tallest column after module list
    local function resizePanel()
        local total=#mods*MOD_H+HDR_H+PAD*2+4
        return total
    end

    return resizePanel
end

local resizeCombat = mkCol(colsFrame, 0,              "Combat", "aimbot", {"Aimbot"})
local resizeVisual = mkCol(colsFrame, COL_W+COL_GAP,  "Visual", "esp",   {"ESP"})

local function resizePanel()
    local h = math.max(resizeCombat(), resizeVisual())
    TweenService:Create(panel,TweenInfo.new(0.18,Enum.EasingStyle.Quad),
        {Size=UDim2.new(0,PANEL_W,0,h)}):Play()
    TweenService:Create(colsFrame,TweenInfo.new(0.18,Enum.EasingStyle.Quad),
        {Size=UDim2.new(1,-PAD*2,0,h-HDR_H-PAD)}):Play()
end
resizePanel()

-- ══════════════════ ESP OBJECT MANAGEMENT ══════════════════
local function createESP(plr)
    if plr==player then return end
    local d={}

    -- 3D box: 12 edge lines
    d.edges={}
    for _=1,12 do
        table.insert(d.edges, mk("Frame",{
            BackgroundColor3=ESP_C,BorderSizePixel=0,
            AnchorPoint=Vector2.new(0,0.5),ZIndex=2,Visible=false},sg))
    end

    -- Name label
    d.nameL=mk("TextLabel",{BackgroundTransparency=1,TextColor3=Color3.new(1,1,1),
        TextSize=13,Font=Enum.Font.GothamBold,TextStrokeTransparency=0.35,
        TextStrokeColor3=Color3.new(0,0,0),ZIndex=3,Visible=false},sg)

    -- Health bar (bg + fill)
    d.hpBg=corner(mk("Frame",{BackgroundColor3=Color3.fromRGB(30,30,30),
        BorderSizePixel=0,ZIndex=2,Visible=false},sg),2)
    d.hpFill=corner(mk("Frame",{BackgroundColor3=GREEN,BorderSizePixel=0,ZIndex=3},d.hpBg),2)

    -- Distance label
    d.distL=mk("TextLabel",{BackgroundTransparency=1,TextColor3=DIM,
        TextSize=11,Font=Enum.Font.Gotham,TextStrokeTransparency=0.5,
        TextStrokeColor3=Color3.new(0,0,0),ZIndex=3,Visible=false},sg)

    -- Tracer (from crosshair center to player)
    d.tracer=mk("Frame",{BackgroundColor3=ESP_C,BorderSizePixel=0,
        AnchorPoint=Vector2.new(0,0.5),ZIndex=1,Visible=false},sg)

    espObjs[plr.UserId]=d
end

local function hideESP(d)
    if not d then return end
    for _,e in ipairs(d.edges or {}) do e.Visible=false end
    d.nameL.Visible=false; d.hpBg.Visible=false
    d.distL.Visible=false; d.tracer.Visible=false
end

local function removeESP(plr)
    local d=espObjs[plr.UserId]; if not d then return end
    for _,e in ipairs(d.edges or {}) do e:Destroy() end
    for _,v in pairs(d) do if typeof(v)=="Instance" then v:Destroy() end end
    espObjs[plr.UserId]=nil
end

local function updateESP(plr)
    local d=espObjs[plr.UserId]; if not d then return end
    if not S.esp.enabled then hideESP(d); return end
    local char=plr.Character
    local hrp=char and char:FindFirstChild("HumanoidRootPart")
    local hum=char and char:FindFirstChildOfClass("Humanoid")
    if not hrp or not hum or hum.Health<=0 then hideESP(d); return end

    -- Screen position of center
    local sp,onS = camera:WorldToViewportPoint(hrp.Position)
    if not onS or sp.Z<=0 then hideESP(d); return end

    -- ─── 3D BOX ───
    if S.esp.box then
        local cf=hrp.CFrame
        -- project all 8 corners
        local px,py,pz={},{},{}
        for i,offset in ipairs(CORNERS) do
            local wp=cf:PointToWorldSpace(offset)
            local s=camera:WorldToViewportPoint(wp)
            px[i]=s.X; py[i]=s.Y; pz[i]=s.Z
        end
        for i,ep in ipairs(EDGES) do
            local a,b=ep[1],ep[2]
            drawEdge(d.edges[i], px[a],py[a],pz[a], px[b],py[b],pz[b])
            d.edges[i].BackgroundColor3=ESP_C
        end
    else
        for _,e in ipairs(d.edges) do e.Visible=false end
    end

    -- ─── NAME ───
    -- estimate box top
    local topSp=camera:WorldToViewportPoint(hrp.Position+Vector3.new(0,YT,0))
    if S.esp.showName then
        d.nameL.Text=plr.Name
        d.nameL.Size=UDim2.new(0,120,0,16)
        d.nameL.Position=UDim2.new(0,sp.X-60,0,math.min(topSp.Y,sp.Y)-20)
        d.nameL.Visible=true
    else d.nameL.Visible=false end

    -- ─── HEALTH BAR ───
    if S.esp.health then
        local botSp=camera:WorldToViewportPoint(hrp.Position+Vector3.new(0,YB,0))
        local bh=math.abs(topSp.Y-botSp.Y)
        local topY=math.min(topSp.Y,botSp.Y)
        local pct=math.clamp(hum.Health/math.max(hum.MaxHealth,1),0,1)
        d.hpBg.Size=UDim2.new(0,4,0,bh)
        d.hpBg.Position=UDim2.new(0,sp.X-18,0,topY)
        d.hpBg.Visible=true
        local fh=math.max(2,bh*pct)
        d.hpFill.Size=UDim2.new(1,0,0,fh)
        d.hpFill.Position=UDim2.new(0,0,1,-fh)
        d.hpFill.BackgroundColor3=pct>0.6 and GREEN or (pct>0.3 and YLW or RED)
    else d.hpBg.Visible=false end

    -- ─── DISTANCE ───
    if S.esp.distance then
        local lc=player.Character
        local lhrp=lc and lc:FindFirstChild("HumanoidRootPart")
        if lhrp then
            local dist=math.floor((hrp.Position-lhrp.Position).Magnitude)
            local botSp2=camera:WorldToViewportPoint(hrp.Position+Vector3.new(0,YB,0))
            d.distL.Text=dist.." m"
            d.distL.Size=UDim2.new(0,80,0,14)
            d.distL.Position=UDim2.new(0,sp.X-40,0,math.max(topSp.Y,botSp2.Y)+4)
            d.distL.Visible=true
        end
    else d.distL.Visible=false end

    -- ─── TRACER (from crosshair center to player feet) ───
    if S.esp.tracer then
        local vp=camera.ViewportSize
        local cx,cy=vp.X/2,vp.Y/2          -- crosshair = screen center
        local botSp3=camera:WorldToViewportPoint(hrp.Position+Vector3.new(0,YB,0))
        local ex,ey=botSp3.X,botSp3.Y       -- target feet
        local dx,dy=ex-cx,ey-cy
        local ln=math.sqrt(dx*dx+dy*dy)
        if ln>1 then
            d.tracer.Position=UDim2.new(0,cx,0,cy)
            d.tracer.Size=UDim2.new(0,ln,0,1.2)
            d.tracer.Rotation=math.deg(math.atan2(dy,dx))
            d.tracer.Visible=true
        else d.tracer.Visible=false end
    else d.tracer.Visible=false end
end

-- ══════════════════ AIMBOT ══════════════════
local function hasLOS(char)
    local hrp=char:FindFirstChild("HumanoidRootPart"); if not hrp then return false end
    local p=RaycastParams.new()
    p.FilterType=Enum.RaycastFilterType.Exclude
    p.FilterDescendantsInstances={player.Character, char}
    local origin=camera.CFrame.Position
    local hit=workspace:Raycast(origin,(hrp.Position-origin),p)
    return hit==nil
end

local function getAimTarget()
    local lc=player.Character
    if not lc or not lc:FindFirstChild("HumanoidRootPart") then return nil end
    local vp=camera.ViewportSize
    local cx,cy=vp.X/2,vp.Y/2
    local best,bestD=nil,math.huge
    for _,t in ipairs(Players:GetPlayers()) do
        if t==player then continue end
        local ch=t.Character; if not ch then continue end
        local hrp=ch:FindFirstChild("HumanoidRootPart"); if not hrp then continue end
        local hum=ch:FindFirstChildOfClass("Humanoid")
        if not hum or hum.Health<=0 then continue end
        if not S.aimbot.throughWalls and not hasLOS(ch) then continue end
        local sp,onS=camera:WorldToViewportPoint(hrp.Position)
        if not onS or sp.Z<=0 then continue end
        local d=(Vector2.new(sp.X,sp.Y)-Vector2.new(cx,cy)).Magnitude
        if d<=S.aimbot.radius and d<bestD then bestD=d; best=t end
    end
    return best
end

local function clearAimHL()
    if aimHL then aimHL:Destroy(); aimHL=nil end
end

local function applyAimHL(char)
    clearAimHL(); if not char then return end
    local hl=Instance.new("Highlight")
    hl.FillColor=Color3.fromRGB(255,0,0); hl.FillTransparency=0.15
    hl.OutlineColor=Color3.fromRGB(255,80,80); hl.OutlineTransparency=0
    hl.DepthMode=Enum.HighlightDepthMode.AlwaysOnTop; hl.Parent=char
    aimHL=hl
    local function pulse()
        if not hl or not hl.Parent then return end
        TweenService:Create(hl,TweenInfo.new(0.2,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut),
            {FillTransparency=0.75}):Play()
        task.delay(0.2,function()
            if not hl or not hl.Parent then return end
            TweenService:Create(hl,TweenInfo.new(0.2,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut),
                {FillTransparency=0.0}):Play()
            task.delay(0.2,pulse)
        end)
    end
    pulse()
end

-- Auto shoot — tool:Activate() is the most mobile-safe approach.
-- Also fires any RemoteEvent with common shoot keywords as fallback.
local function doShoot()
    local char=player.Character; if not char then return end
    local tool=char:FindFirstChildOfClass("Tool"); if not tool then return end

    -- Try standard activation first
    pcall(function() tool:Activate() end)

    -- Fallback: fire any remote that looks like a shoot/attack remote
    pcall(function()
        for _,v in ipairs(tool:GetDescendants()) do
            if v:IsA("RemoteEvent") then
                local n=v.Name:lower()
                if n:find("shoot") or n:find("fire") or n:find("attack") or n:find("hit") then
                    local hrp=char:FindFirstChild("HumanoidRootPart")
                    local target=aimTarget and aimTarget.Character
                        and aimTarget.Character:FindFirstChild("HumanoidRootPart")
                    if hrp and target then
                        v:FireServer(target.Position)
                    else
                        v:FireServer()
                    end
                end
            end
        end
    end)
end

-- ══════════════════ PLAYER EVENTS ══════════════════
for _,p in ipairs(Players:GetPlayers()) do createESP(p) end
Players.PlayerAdded:Connect(createESP)
Players.PlayerRemoving:Connect(removeESP)

-- ══════════════════ RENDER LOOP ══════════════════
RunService.RenderStepped:Connect(function()
    -- AIMBOT
    if S.aimbot.enabled then
        local t=getAimTarget()
        if t~=aimTarget then
            aimTarget=t
            if t then applyAimHL(t.Character) else clearAimHL() end
            crossCol(t~=nil)
        end
        -- Recover from respawn
        if aimTarget and aimHL and not aimHL.Parent then
            if aimTarget.Character then applyAimHL(aimTarget.Character) end
        end
        -- Death/left cleanup
        if aimTarget then
            local ch=aimTarget.Character
            local hu=ch and ch:FindFirstChildOfClass("Humanoid")
            if not ch or not ch:FindFirstChild("HumanoidRootPart") or (hu and hu.Health<=0) then
                clearAimHL(); aimTarget=nil; crossCol(false)
            end
        end
        -- Aim camera
        if aimTarget then
            local hrp=aimTarget.Character and aimTarget.Character:FindFirstChild("HumanoidRootPart")
            if hrp then camera.CFrame=CFrame.new(camera.CFrame.Position,hrp.Position) end
        end
        -- Shoot
        if S.aimbot.autoShoot and aimTarget then
            local now=tick()
            if now-lastShot>=SHOOT_DELAY then doShoot(); lastShot=now end
        end
    end

    -- ESP
    if S.esp.enabled then
        for _,p in ipairs(Players:GetPlayers()) do
            if p~=player then updateESP(p) end
        end
    end
end)
