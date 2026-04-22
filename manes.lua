-- ╔═══════════════════════════════════════════════════╗
-- ║   Hack Event  •  Meteor Client UI  •  v4          ║
-- ║   Combat: Aimbot  |  Visual: ESP                  ║
-- ╚═══════════════════════════════════════════════════╝

local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService     = game:GetService("TweenService")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

-- ════════════════════════ CONSTANTS ════════════════════════
local HOLD_TIME   = 0.35
local SHOOT_DELAY = 0.12
local MIN_R, MAX_R = 60, 360

-- ════════════════════════ COLORS ════════════════════════
local BG    = Color3.fromRGB(8,   8,  15)
local BG2   = Color3.fromRGB(13,  13,  25)
local HDR   = Color3.fromRGB(15,  17,  42)
local ROW   = Color3.fromRGB(18,  18,  33)
local BDR   = Color3.fromRGB(35,  58, 172)
local BLUE  = Color3.fromRGB(55, 110, 255)
local BLUE2 = Color3.fromRGB(28,  54, 158)
local BLUE3 = Color3.fromRGB(45,  80, 200)
local TEXT  = Color3.fromRGB(212, 217, 248)
local DIM   = Color3.fromRGB(128, 133, 168)
local RED   = Color3.fromRGB(255,  50,  50)
local GREEN = Color3.fromRGB(50,  220, 100)
local YLW   = Color3.fromRGB(255, 200,  40)
local DARK  = Color3.fromRGB(40,  40,  65)
local OFF   = Color3.fromRGB(48,  48,  75)

-- ════════════════════════ STATE ════════════════════════
local S = {
    aimbot = { enabled=false, circleSize=180, throughWalls=true, autoShoot=false },
    esp    = { enabled=false, box=true, tracer=true, health=true, showName=true, distance=true },
}
local aimTarget  = nil
local aimHL      = nil
local lastShot   = 0
local espObjects = {}   -- [userId] = { bT,bB,bL,bR, nameL, hpBg,hpFill, distL, tracer }

-- ════════════════════════ SCREENGUI ════════════════════════
local sg = Instance.new("ScreenGui")
sg.Name="HackEvent"; sg.ResetOnSpawn=false
sg.IgnoreGuiInset=true; sg.ZIndexBehavior=Enum.ZIndexBehavior.Sibling
sg.Parent = player.PlayerGui

-- ════════════════════════ CROSSHAIR ════════════════════════
local cRing = Instance.new("Frame")
cRing.BackgroundTransparency=1; cRing.BorderSizePixel=0
cRing.ZIndex=4; cRing.Visible=false; cRing.Parent=sg
Instance.new("UICorner",cRing).CornerRadius=UDim.new(1,0)
local cStroke=Instance.new("UIStroke",cRing); cStroke.Thickness=2; cStroke.Color=BLUE

local cDot=Instance.new("Frame"); cDot.Size=UDim2.new(0,6,0,6)
cDot.BackgroundColor3=TEXT; cDot.BorderSizePixel=0; cDot.ZIndex=4; cDot.Visible=false; cDot.Parent=sg
Instance.new("UICorner",cDot).CornerRadius=UDim.new(1,0)

local cLH=Instance.new("Frame"); cLH.Size=UDim2.new(0,20,0,2)
cLH.BackgroundColor3=TEXT; cLH.BorderSizePixel=0; cLH.ZIndex=4; cLH.Visible=false; cLH.Parent=sg
local cLV=Instance.new("Frame"); cLV.Size=UDim2.new(0,2,0,20)
cLV.BackgroundColor3=TEXT; cLV.BorderSizePixel=0; cLV.ZIndex=4; cLV.Visible=false; cLV.Parent=sg

local function updCross()
    local r=S.aimbot.circleSize
    cRing.Size=UDim2.new(0,r*2,0,r*2); cRing.Position=UDim2.new(0.5,-r,0.5,-r)
    cDot.Position=UDim2.new(0.5,-3,0.5,-3)
    cLH.Position=UDim2.new(0.5,-10,0.5,-1); cLV.Position=UDim2.new(0.5,-1,0.5,-10)
end
local function crossCol(t)
    local c=t and RED or BLUE
    cStroke.Color=c; cDot.BackgroundColor3=c; cLH.BackgroundColor3=c; cLV.BackgroundColor3=c
end
local function crossVis(v)
    cRing.Visible=v; cDot.Visible=v; cLH.Visible=v; cLV.Visible=v
end
updCross()

-- ════════════════════════ SETTINGS OVERLAY ════════════════════════
local openSettings  -- forward declare

local overlay=Instance.new("Frame")
overlay.Size=UDim2.new(1,0,1,0); overlay.BackgroundColor3=Color3.fromRGB(0,0,0)
overlay.BackgroundTransparency=0.45; overlay.BorderSizePixel=0
overlay.ZIndex=20; overlay.Visible=false; overlay.Parent=sg

local sBox=Instance.new("Frame")
sBox.AnchorPoint=Vector2.new(0.5,0.5); sBox.Position=UDim2.new(0.5,0,0.5,0)
sBox.Size=UDim2.new(0,295,0,60)   -- height set when opened
sBox.BackgroundColor3=BG2; sBox.BorderSizePixel=0; sBox.ZIndex=21; sBox.Parent=overlay
Instance.new("UICorner",sBox).CornerRadius=UDim.new(0,8)
local sbS=Instance.new("UIStroke",sBox); sbS.Color=BLUE3; sbS.Thickness=1

local sHdr=Instance.new("Frame")
sHdr.Size=UDim2.new(1,0,0,46); sHdr.BackgroundColor3=HDR; sHdr.BorderSizePixel=0
sHdr.ZIndex=22; sHdr.Parent=sBox
Instance.new("UICorner",sHdr).CornerRadius=UDim.new(0,8)
local shFix=Instance.new("Frame"); shFix.Size=UDim2.new(1,0,0,8); shFix.Position=UDim2.new(0,0,1,-8)
shFix.BackgroundColor3=HDR; shFix.BorderSizePixel=0; shFix.ZIndex=22; shFix.Parent=sHdr

local backBtn=Instance.new("TextButton"); backBtn.Text="←"
backBtn.Size=UDim2.new(0,36,0,30); backBtn.Position=UDim2.new(0,8,0.5,-15)
backBtn.BackgroundColor3=BLUE2; backBtn.TextColor3=TEXT; backBtn.TextSize=18
backBtn.Font=Enum.Font.GothamBold; backBtn.BorderSizePixel=0; backBtn.ZIndex=23; backBtn.Parent=sHdr
Instance.new("UICorner",backBtn).CornerRadius=UDim.new(0,5)

local sTitleL=Instance.new("TextLabel"); sTitleL.Size=UDim2.new(1,-55,1,0)
sTitleL.Position=UDim2.new(0,52,0,0); sTitleL.BackgroundTransparency=1
sTitleL.TextColor3=TEXT; sTitleL.TextSize=15; sTitleL.Font=Enum.Font.GothamBold
sTitleL.TextXAlignment=Enum.TextXAlignment.Left; sTitleL.ZIndex=23; sTitleL.Parent=sHdr

local sCont=Instance.new("Frame")
sCont.Position=UDim2.new(0,10,0,52); sCont.Size=UDim2.new(1,-20,1,-60)
sCont.BackgroundTransparency=1; sCont.ZIndex=22; sCont.Parent=sBox
local sLL=Instance.new("UIListLayout",sCont); sLL.Padding=UDim.new(0,5); sLL.SortOrder=Enum.SortOrder.LayoutOrder

backBtn.MouseButton1Click:Connect(function()
    overlay.Visible=false
    for _,c in ipairs(sCont:GetChildren()) do if not c:IsA("UIListLayout") then c:Destroy() end end
end)

-- Helper: toggle row inside settings
local function mkSToggle(label, initVal, onChange)
    local row=Instance.new("Frame"); row.Size=UDim2.new(1,0,0,42)
    row.BackgroundColor3=ROW; row.BorderSizePixel=0; row.ZIndex=23; row.Parent=sCont
    Instance.new("UICorner",row).CornerRadius=UDim.new(0,6)

    local l=Instance.new("TextLabel"); l.Text=label
    l.Size=UDim2.new(1,-62,1,0); l.Position=UDim2.new(0,12,0,0)
    l.BackgroundTransparency=1; l.TextColor3=TEXT; l.TextSize=13
    l.Font=Enum.Font.Gotham; l.TextXAlignment=Enum.TextXAlignment.Left; l.ZIndex=24; l.Parent=row

    local bg=Instance.new("Frame"); bg.Size=UDim2.new(0,44,0,24); bg.Position=UDim2.new(1,-52,0.5,-12)
    bg.BackgroundColor3=initVal and BLUE or OFF; bg.BorderSizePixel=0; bg.ZIndex=24; bg.Parent=row
    Instance.new("UICorner",bg).CornerRadius=UDim.new(1,0)

    local kn=Instance.new("Frame"); kn.Size=UDim2.new(0,18,0,18)
    kn.Position=initVal and UDim2.new(1,-21,0.5,-9) or UDim2.new(0,3,0.5,-9)
    kn.BackgroundColor3=Color3.fromRGB(255,255,255); kn.BorderSizePixel=0; kn.ZIndex=25; kn.Parent=bg
    Instance.new("UICorner",kn).CornerRadius=UDim.new(1,0)

    local st={v=initVal}
    local hit=Instance.new("TextButton"); hit.Size=UDim2.new(1,0,1,0)
    hit.BackgroundTransparency=1; hit.Text=""; hit.ZIndex=25; hit.Parent=row
    local ti=TweenInfo.new(0.12,Enum.EasingStyle.Quad)
    hit.MouseButton1Click:Connect(function()
        st.v=not st.v
        TweenService:Create(bg,ti,{BackgroundColor3=st.v and BLUE or OFF}):Play()
        TweenService:Create(kn,ti,{Position=st.v and UDim2.new(1,-21,0.5,-9) or UDim2.new(0,3,0.5,-9)}):Play()
        onChange(st.v)
    end)
end

-- Helper: slider row inside settings
local sliderConns={}

local function mkSSlider(label, mn, mx, initVal, onChange)
    local row=Instance.new("Frame"); row.Size=UDim2.new(1,0,0,58)
    row.BackgroundColor3=ROW; row.BorderSizePixel=0; row.ZIndex=23; row.Parent=sCont
    Instance.new("UICorner",row).CornerRadius=UDim.new(0,6)

    local lbl=Instance.new("TextLabel"); lbl.Text=label.."  "..tostring(initVal)
    lbl.Size=UDim2.new(1,-12,0,26); lbl.Position=UDim2.new(0,12,0,4)
    lbl.BackgroundTransparency=1; lbl.TextColor3=TEXT; lbl.TextSize=13
    lbl.Font=Enum.Font.Gotham; lbl.TextXAlignment=Enum.TextXAlignment.Left; lbl.ZIndex=24; lbl.Parent=row

    local trk=Instance.new("Frame"); trk.Size=UDim2.new(1,-24,0,7); trk.Position=UDim2.new(0,12,0,36)
    trk.BackgroundColor3=DARK; trk.BorderSizePixel=0; trk.ZIndex=24; trk.Parent=row
    Instance.new("UICorner",trk).CornerRadius=UDim.new(1,0)

    local p0=(initVal-mn)/(mx-mn)
    local fill=Instance.new("Frame"); fill.Size=UDim2.new(p0,0,1,0)
    fill.BackgroundColor3=BLUE; fill.BorderSizePixel=0; fill.ZIndex=25; fill.Parent=trk
    Instance.new("UICorner",fill).CornerRadius=UDim.new(1,0)

    local kn=Instance.new("Frame"); kn.Size=UDim2.new(0,20,0,20)
    kn.Position=UDim2.new(p0,-10,0.5,-10); kn.BackgroundColor3=Color3.fromRGB(255,255,255)
    kn.BorderSizePixel=0; kn.ZIndex=26; kn.Parent=trk
    Instance.new("UICorner",kn).CornerRadius=UDim.new(1,0)

    local dragging=false
    trk.InputBegan:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then
            dragging=true
        end
    end)
    trk.InputEnded:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then
            dragging=false
        end
    end)
    table.insert(sliderConns, UserInputService.InputChanged:Connect(function(i)
        if not dragging then return end
        if i.UserInputType~=Enum.UserInputType.MouseMovement and i.UserInputType~=Enum.UserInputType.Touch then return end
        local ap=trk.AbsolutePosition; local as=trk.AbsoluteSize
        local p=math.clamp((i.Position.X-ap.X)/as.X, 0, 1)
        local val=math.floor(mn+p*(mx-mn))
        fill.Size=UDim2.new(p,0,1,0); kn.Position=UDim2.new(p,-10,0.5,-10)
        lbl.Text=label.."  "..tostring(val); onChange(val)
    end))
end

-- openSettings definition
openSettings = function(key)
    for _,c in ipairs(sliderConns) do c:Disconnect() end
    table.clear(sliderConns)
    for _,c in ipairs(sCont:GetChildren()) do if not c:IsA("UIListLayout") then c:Destroy() end end

    sTitleL.Text = key:sub(1,1):upper()..key:sub(2)
    overlay.Visible = true

    if key=="aimbot" then
        mkSSlider("Circle size", MIN_R, MAX_R, S.aimbot.circleSize, function(v)
            S.aimbot.circleSize=v; updCross()
        end)
        mkSToggle("Through walls", S.aimbot.throughWalls, function(v) S.aimbot.throughWalls=v end)
        mkSToggle("Auto shoot",    S.aimbot.autoShoot,    function(v) S.aimbot.autoShoot=v   end)
        sBox.Size=UDim2.new(0,295,0, 46+10+58+42+42+14)

    elseif key=="esp" then
        mkSToggle("Box",      S.esp.box,      function(v) S.esp.box=v      end)
        mkSToggle("Tracer",   S.esp.tracer,   function(v) S.esp.tracer=v   end)
        mkSToggle("Health",   S.esp.health,   function(v) S.esp.health=v   end)
        mkSToggle("Name",     S.esp.showName, function(v) S.esp.showName=v end)
        mkSToggle("Distance", S.esp.distance, function(v) S.esp.distance=v end)
        sBox.Size=UDim2.new(0,295,0, 46+10+42*5+5*5+10)
    end
end

-- ════════════════════════ PANEL ════════════════════════
local PW,TH,HH,MH = 434, 44, 42, 40
local CW,CG,PAD   = 202, 10, 10

local combatList={"Aimbot"}
local visualList={"ESP"}
local cExp,vExp=false,false

local function calcPH()
    local a=HH+(cExp and #combatList*MH or 0)
    local b=HH+(vExp and #visualList*MH or 0)
    return TH+math.max(a,b)+PAD*2
end

local panel=Instance.new("Frame")
panel.Size=UDim2.new(0,PW,0,calcPH()); panel.Position=UDim2.new(0.5,-PW/2,0,72)
panel.BackgroundColor3=BG; panel.BorderSizePixel=0
panel.Active=true; panel.ClipsDescendants=true; panel.Parent=sg
Instance.new("UICorner",panel).CornerRadius=UDim.new(0,6)
local pS=Instance.new("UIStroke",panel); pS.Color=BDR; pS.Thickness=0.8

-- Title bar
local tb=Instance.new("Frame"); tb.Size=UDim2.new(1,0,0,TH)
tb.BackgroundColor3=HDR; tb.BorderSizePixel=0; tb.Active=true; tb.Parent=panel
Instance.new("UICorner",tb).CornerRadius=UDim.new(0,6)
local tbF=Instance.new("Frame"); tbF.Size=UDim2.new(1,0,0,6); tbF.Position=UDim2.new(0,0,1,-6)
tbF.BackgroundColor3=HDR; tbF.BorderSizePixel=0; tbF.Parent=tb

local tDot=Instance.new("Frame"); tDot.Size=UDim2.new(0,8,0,8); tDot.Position=UDim2.new(0,13,0.5,-4)
tDot.BackgroundColor3=BLUE; tDot.BorderSizePixel=0; tDot.Parent=tb
Instance.new("UICorner",tDot).CornerRadius=UDim.new(1,0)

local tLbl=Instance.new("TextLabel"); tLbl.Text="Hack Event"
tLbl.Size=UDim2.new(1,-30,1,0); tLbl.Position=UDim2.new(0,28,0,0)
tLbl.BackgroundTransparency=1; tLbl.TextColor3=TEXT; tLbl.TextSize=17
tLbl.Font=Enum.Font.GothamBold; tLbl.TextXAlignment=Enum.TextXAlignment.Left; tLbl.Parent=tb

-- Drag
local dr=false; local drS,drP
tb.InputBegan:Connect(function(i)
    if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then
        dr=true; drS=i.Position; drP=panel.Position
    end
end)
UserInputService.InputChanged:Connect(function(i)
    if dr and (i.UserInputType==Enum.UserInputType.MouseMovement or i.UserInputType==Enum.UserInputType.Touch) then
        local d=i.Position-drS
        panel.Position=UDim2.new(drP.X.Scale,drP.X.Offset+d.X,drP.Y.Scale,drP.Y.Offset+d.Y)
    end
end)
UserInputService.InputEnded:Connect(function(i)
    if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then dr=false end
end)

-- Columns
local cols=Instance.new("Frame")
cols.Size=UDim2.new(1,-PAD*2,0,calcPH()-TH-PAD)
cols.Position=UDim2.new(0,PAD,0,TH+PAD/2)
cols.BackgroundTransparency=1; cols.ClipsDescendants=false; cols.Parent=panel

local cCol=Instance.new("Frame"); cCol.BackgroundTransparency=1; cCol.ClipsDescendants=true; cCol.Parent=cols
cCol.Size=UDim2.new(0,CW,1,0); cCol.Position=UDim2.new(0,0,0,0)
local vCol=Instance.new("Frame"); vCol.BackgroundTransparency=1; vCol.ClipsDescendants=true; vCol.Parent=cols
vCol.Size=UDim2.new(0,CW,1,0); vCol.Position=UDim2.new(0,CW+CG,0,0)

local function reflow()
    local a=HH+(cExp and #combatList*MH or 0)
    local b=HH+(vExp and #visualList*MH or 0)
    local mx=math.max(a,b); local ph=TH+mx+PAD*2
    local tw=TweenInfo.new(0.18,Enum.EasingStyle.Quad)
    TweenService:Create(panel,tw,{Size=UDim2.new(0,PW,0,ph)}):Play()
    TweenService:Create(cols,tw,{Size=UDim2.new(1,-PAD*2,0,mx)}):Play()
    TweenService:Create(cCol,tw,{Size=UDim2.new(0,CW,0,mx)}):Play()
    TweenService:Create(vCol,tw,{Size=UDim2.new(0,CW,0,mx)}):Play()
end

-- Module info for dot/row coloring
local modInfo={}   -- [key] = {dot, row}

local function refreshMod(key)
    local m=modInfo[key]; if not m then return end
    local on=S[key] and S[key].enabled
    TweenService:Create(m.dot,TweenInfo.new(0.1),{BackgroundColor3=on and BLUE or DIM}):Play()
    TweenService:Create(m.row,TweenInfo.new(0.1),{BackgroundColor3=on and Color3.fromRGB(14,26,65) or ROW}):Play()
end

-- ════════════════════════ COLUMN BUILDER ════════════════════════
local function buildCol(parent, title, mods, catKey)
    -- header
    local hdr=Instance.new("Frame"); hdr.Size=UDim2.new(1,0,0,HH)
    hdr.BackgroundColor3=HDR; hdr.BorderSizePixel=0; hdr.Parent=parent
    Instance.new("UICorner",hdr).CornerRadius=UDim.new(0,5)
    local hs=Instance.new("UIStroke",hdr); hs.Color=BDR; hs.Thickness=0.7

    local hL=Instance.new("TextLabel"); hL.Text=title
    hL.Size=UDim2.new(1,-46,1,0); hL.Position=UDim2.new(0,11,0,0)
    hL.BackgroundTransparency=1; hL.TextColor3=TEXT; hL.TextSize=15
    hL.Font=Enum.Font.GothamBold; hL.TextXAlignment=Enum.TextXAlignment.Left; hL.Parent=hdr

    local arw=Instance.new("TextButton"); arw.Text=">"
    arw.Size=UDim2.new(0,32,0,28); arw.Position=UDim2.new(1,-36,0.5,-14)
    arw.BackgroundColor3=BLUE2; arw.TextColor3=TEXT; arw.TextSize=14
    arw.Font=Enum.Font.GothamBold; arw.BorderSizePixel=0; arw.Parent=hdr
    Instance.new("UICorner",arw).CornerRadius=UDim.new(0,5)

    -- module list
    local mFrame=Instance.new("Frame"); mFrame.Position=UDim2.new(0,0,0,HH+4)
    mFrame.Size=UDim2.new(1,0,0,#mods*MH+4); mFrame.BackgroundTransparency=1
    mFrame.Visible=false; mFrame.Parent=parent
    local ll=Instance.new("UIListLayout",mFrame); ll.Padding=UDim.new(0,4); ll.SortOrder=Enum.SortOrder.LayoutOrder

    for idx,modName in ipairs(mods) do
        local key=modName:lower()
        local row=Instance.new("Frame"); row.Size=UDim2.new(1,0,0,MH-4)
        row.BackgroundColor3=ROW; row.BorderSizePixel=0; row.LayoutOrder=idx; row.Parent=mFrame
        Instance.new("UICorner",row).CornerRadius=UDim.new(0,5)
        local rs=Instance.new("UIStroke",row); rs.Color=BDR; rs.Thickness=0.6

        local dot=Instance.new("Frame"); dot.Size=UDim2.new(0,7,0,7)
        dot.Position=UDim2.new(0,11,0.5,-3); dot.BackgroundColor3=DIM; dot.BorderSizePixel=0; dot.Parent=row
        Instance.new("UICorner",dot).CornerRadius=UDim.new(1,0)

        local rl=Instance.new("TextLabel"); rl.Text=modName
        rl.Size=UDim2.new(1,-26,1,0); rl.Position=UDim2.new(0,24,0,0)
        rl.BackgroundTransparency=1; rl.TextColor3=TEXT; rl.TextSize=14
        rl.Font=Enum.Font.Gotham; rl.TextXAlignment=Enum.TextXAlignment.Left; rl.Parent=row

        local hit=Instance.new("TextButton"); hit.Size=UDim2.new(1,0,1,0)
        hit.BackgroundTransparency=1; hit.Text=""; hit.Parent=row

        modInfo[key]={dot=dot, row=row}

        -- hold vs tap
        local hConn=nil
        hit.InputBegan:Connect(function(i)
            if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then
                hConn=task.delay(HOLD_TIME, function()
                    hConn=nil
                    openSettings(key)
                end)
            end
        end)
        hit.InputEnded:Connect(function(i)
            if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then
                if hConn then
                    task.cancel(hConn); hConn=nil
                    -- toggle
                    S[key].enabled=not S[key].enabled
                    if key=="aimbot" then
                        crossVis(S.aimbot.enabled)
                        if not S.aimbot.enabled then
                            if aimHL then aimHL:Destroy(); aimHL=nil end
                            aimTarget=nil; crossCol(false)
                        end
                    elseif key=="esp" then
                        if not S.esp.enabled then
                            for _,d in pairs(espObjects) do
                                for _,v in pairs(d) do
                                    if typeof(v)=="Instance" and v:IsA("GuiObject") then v.Visible=false end
                                end
                            end
                        end
                    end
                    refreshMod(key)
                end
            end
        end)
    end

    -- expand/collapse
    local exp=false
    arw.MouseButton1Click:Connect(function()
        exp=not exp; mFrame.Visible=exp
        arw.Text=exp and "v" or ">"
        if catKey=="combat" then cExp=exp else vExp=exp end
        reflow()
    end)
end

buildCol(cCol,"Combat",combatList,"combat")
buildCol(vCol,"Visual",visualList,"visual")

-- ════════════════════════ ESP OBJECT MANAGEMENT ════════════════════════
local function mkLine(zidx)
    local f=Instance.new("Frame")
    f.BackgroundColor3=BLUE; f.BorderSizePixel=0
    f.ZIndex=zidx; f.Visible=false; f.Parent=sg
    return f
end

local function createESP(plr)
    if plr==player then return end
    local d={}
    d.bT=mkLine(2); d.bB=mkLine(2); d.bL=mkLine(2); d.bR=mkLine(2)

    d.nameL=Instance.new("TextLabel")
    d.nameL.BackgroundTransparency=1; d.nameL.TextColor3=Color3.fromRGB(255,255,255)
    d.nameL.TextSize=12; d.nameL.Font=Enum.Font.GothamBold
    d.nameL.TextStrokeTransparency=0.4; d.nameL.TextStrokeColor3=Color3.new(0,0,0)
    d.nameL.ZIndex=3; d.nameL.Visible=false; d.nameL.Parent=sg

    d.hpBg=Instance.new("Frame"); d.hpBg.BackgroundColor3=Color3.fromRGB(35,35,35)
    d.hpBg.BorderSizePixel=0; d.hpBg.ZIndex=2; d.hpBg.Visible=false; d.hpBg.Parent=sg
    Instance.new("UICorner",d.hpBg).CornerRadius=UDim.new(0,2)

    d.hpFill=Instance.new("Frame"); d.hpFill.BackgroundColor3=GREEN
    d.hpFill.BorderSizePixel=0; d.hpFill.ZIndex=3; d.hpFill.Parent=d.hpBg
    Instance.new("UICorner",d.hpFill).CornerRadius=UDim.new(0,2)

    d.distL=Instance.new("TextLabel")
    d.distL.BackgroundTransparency=1; d.distL.TextColor3=DIM
    d.distL.TextSize=11; d.distL.Font=Enum.Font.Gotham
    d.distL.TextStrokeTransparency=0.5; d.distL.TextStrokeColor3=Color3.new(0,0,0)
    d.distL.ZIndex=3; d.distL.Visible=false; d.distL.Parent=sg

    d.tracer=Instance.new("Frame"); d.tracer.BackgroundColor3=BLUE
    d.tracer.BorderSizePixel=0; d.tracer.AnchorPoint=Vector2.new(0,0.5)
    d.tracer.ZIndex=1; d.tracer.Visible=false; d.tracer.Parent=sg

    espObjects[plr.UserId]=d
end

local function hideESP(d)
    if not d then return end
    d.bT.Visible=false; d.bB.Visible=false; d.bL.Visible=false; d.bR.Visible=false
    d.nameL.Visible=false; d.hpBg.Visible=false; d.distL.Visible=false; d.tracer.Visible=false
end

local function removeESP(plr)
    local d=espObjects[plr.UserId]; if not d then return end
    for _,v in pairs(d) do if typeof(v)=="Instance" then v:Destroy() end end
    espObjects[plr.UserId]=nil
end

local function updateESPFor(plr)
    local d=espObjects[plr.UserId]; if not d then return end
    local es=S.esp
    if not es.enabled then hideESP(d); return end

    local char=plr.Character
    local hrp=char and char:FindFirstChild("HumanoidRootPart")
    local hum=char and char:FindFirstChildOfClass("Humanoid")
    if not hrp or not hum then hideESP(d); return end

    local sp,onS=camera:WorldToViewportPoint(hrp.Position)
    if not onS or sp.Z<=0 then hideESP(d); return end

    -- box
    local topS=camera:WorldToViewportPoint(hrp.Position+Vector3.new(0,2.9,0))
    local botS=camera:WorldToViewportPoint(hrp.Position+Vector3.new(0,-3.1,0))
    local bH=math.abs(botS.Y-topS.Y); local bW=bH*0.54
    local bX=sp.X-bW/2; local bY=math.min(topS.Y,botS.Y); local lt=1.5

    d.bT.Size=UDim2.new(0,bW,0,lt); d.bT.Position=UDim2.new(0,bX,0,bY);         d.bT.Visible=es.box
    d.bB.Size=UDim2.new(0,bW,0,lt); d.bB.Position=UDim2.new(0,bX,0,bY+bH-lt);   d.bB.Visible=es.box
    d.bL.Size=UDim2.new(0,lt,0,bH); d.bL.Position=UDim2.new(0,bX,0,bY);         d.bL.Visible=es.box
    d.bR.Size=UDim2.new(0,lt,0,bH); d.bR.Position=UDim2.new(0,bX+bW-lt,0,bY);   d.bR.Visible=es.box

    -- name
    if es.showName then
        d.nameL.Text=plr.Name
        d.nameL.Size=UDim2.new(0,bW+10,0,16)
        d.nameL.Position=UDim2.new(0,bX-5,0,bY-18)
        d.nameL.Visible=true
    else d.nameL.Visible=false end

    -- health bar (left side, vertical)
    if es.health then
        local pct=math.clamp(hum.Health/math.max(hum.MaxHealth,1),0,1)
        d.hpBg.Size=UDim2.new(0,4,0,bH)
        d.hpBg.Position=UDim2.new(0,bX-8,0,bY)
        d.hpBg.Visible=true
        local fillH=math.max(2,bH*pct)
        d.hpFill.Size=UDim2.new(1,0,0,fillH)
        d.hpFill.Position=UDim2.new(0,0,1,-fillH)
        d.hpFill.BackgroundColor3=pct>0.6 and GREEN or (pct>0.3 and YLW or RED)
    else d.hpBg.Visible=false end

    -- distance
    if es.distance and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
        local dist=math.floor((hrp.Position-player.Character.HumanoidRootPart.Position).Magnitude)
        d.distL.Text=dist.."m"
        d.distL.Size=UDim2.new(0,bW,0,14)
        d.distL.Position=UDim2.new(0,bX,0,bY+bH+3)
        d.distL.Visible=true
    else d.distL.Visible=false end

    -- tracer
    if es.tracer then
        local vps=camera.ViewportSize
        local x1,y1=vps.X/2,vps.Y
        local x2,y2=sp.X,sp.Y
        local dx,dy=x2-x1,y2-y1
        local len=math.sqrt(dx*dx+dy*dy)
        d.tracer.Size=UDim2.new(0,len,0,1)
        d.tracer.Position=UDim2.new(0,x1,0,y1)
        d.tracer.Rotation=math.deg(math.atan2(dy,dx))
        d.tracer.Visible=true
    else d.tracer.Visible=false end
end

-- ════════════════════════ AIMBOT LOGIC ════════════════════════
local function hasLOS(char)
    local hrp=char:FindFirstChild("HumanoidRootPart"); if not hrp then return false end
    local origin=camera.CFrame.Position
    local dir=hrp.Position-origin
    local params=RaycastParams.new()
    params.FilterType=Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances={player.Character, char}
    return workspace:Raycast(origin, dir, params)==nil
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
        local d2=(Vector2.new(sp.X,sp.Y)-Vector2.new(cx,cy)).Magnitude
        if d2<=S.aimbot.circleSize and d2<bestD then
            bestD=d2; best=t
        end
    end
    return best
end

local function clearAimHL()
    if aimHL then aimHL:Destroy(); aimHL=nil end
end

local function applyAimHL(char)
    clearAimHL()
    if not char then return end
    local hl=Instance.new("Highlight")
    hl.FillColor=Color3.fromRGB(255,0,0); hl.FillTransparency=0.15
    hl.OutlineColor=Color3.fromRGB(255,80,80); hl.OutlineTransparency=0
    hl.DepthMode=Enum.HighlightDepthMode.AlwaysOnTop; hl.Parent=char
    aimHL=hl
    -- pulse
    local function pulse()
        if not hl or not hl.Parent then return end
        TweenService:Create(hl,TweenInfo.new(0.22,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut),{FillTransparency=0.72}):Play()
        task.delay(0.22,function()
            if not hl or not hl.Parent then return end
            TweenService:Create(hl,TweenInfo.new(0.22,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut),{FillTransparency=0.0}):Play()
            task.delay(0.22,pulse)
        end)
    end
    pulse()
end

local function doShoot()
    if not player.Character then return end
    local tool=player.Character:FindFirstChildOfClass("Tool")
    if tool then tool:Activate() end
end

-- ════════════════════════ PLAYER EVENTS ════════════════════════
for _,p in ipairs(Players:GetPlayers()) do createESP(p) end
Players.PlayerAdded:Connect(createESP)
Players.PlayerRemoving:Connect(removeESP)

-- ════════════════════════ RENDER LOOP ════════════════════════
RunService.RenderStepped:Connect(function()
    -- ── AIMBOT ──
    if S.aimbot.enabled then
        local t=getAimTarget()

        if t~=aimTarget then
            aimTarget=t
            if t then
                applyAimHL(t.Character)
            else
                clearAimHL()
            end
            crossCol(t~=nil)
        end

        -- clean up if target died/left
        if aimTarget then
            local ch=aimTarget.Character
            local hu=ch and ch:FindFirstChildOfClass("Humanoid")
            if not ch or not ch:FindFirstChild("HumanoidRootPart") or (hu and hu.Health<=0) then
                clearAimHL(); aimTarget=nil; crossCol(false)
            end
        end

        -- also keep HL fresh if character changed (respawn)
        if aimTarget and aimHL and not aimHL.Parent then
            if aimTarget.Character then applyAimHL(aimTarget.Character) end
        end

        -- aim camera
        if aimTarget then
            local hrp=aimTarget.Character and aimTarget.Character:FindFirstChild("HumanoidRootPart")
            if hrp then
                camera.CFrame=CFrame.new(camera.CFrame.Position, hrp.Position)
            end
        end

        -- auto shoot
        if S.aimbot.autoShoot and aimTarget then
            local now=tick()
            if now-lastShot>=SHOOT_DELAY then doShoot(); lastShot=now end
        end
    end

    -- ── ESP ──
    if S.esp.enabled then
        for _,p in ipairs(Players:GetPlayers()) do
            if p~=player then updateESPFor(p) end
        end
    end
end)
