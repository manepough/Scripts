-- NPC Controller v2 (Recreated)
-- Changes from original:
--   * Removed all dot-prefixed admin cmds (.givecommand, .stripcommand, .drag, .bring, .disarm, .range, .summon)
--   * .summon replaced with .wake (stronger: retries failed teleports, verifies connection before moving)
--   * Stronger connection: persistent re-connection loop, faster retry, ReceiveAge + network-owner double check
--   * New cmds: shield, ghost, frenzy, freeze me, unfreeze me, scatter, recall, spotlight, flashstep, conga

-- ─────────────────────────────────────────
--  SERVICES
-- ─────────────────────────────────────────
local Players            = game:GetService("Players")
local RunService         = game:GetService("RunService")
local PathfindingService = game:GetService("PathfindingService")
local TweenService       = game:GetService("TweenService")
local UserInputService   = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer or Players:GetPlayers()[1]
Players.PlayerAdded:Connect(function(p)
	if not LocalPlayer then LocalPlayer = p end
end)

-- ─────────────────────────────────────────
--  STATE
-- ─────────────────────────────────────────
local state = {
	Follow           = false,
	Spin             = false,
	Chat             = false,
	ESP              = false,
	AutoConnect      = false,
	Gossip           = false,
	AntiLag          = false,
	CurrentTarget    = nil,
	CurrentTargetName= nil,
	Mode             = nil,
	CommandIssuer    = LocalPlayer,
	YesOrNoPick      = 1,
	YesOrNoTick      = 0,
	StayingNPCs      = {},
	StackUpPos       = nil,
	NetworkRange     = math.huge,
	SpecificFollow   = {},
	RoamPoints       = {},
	CurrentRoamIndex = {},
	MimicNPCs        = {},
	OrbitSpeed       = 1,
	SelfDefense      = false,
	ShowRadius       = false,
	GlobalAttackTarget = nil,
	GlobalFreeze     = false,
	PossessedNPC     = nil,
	BlueNPC          = nil,
	RedNPC           = nil,
	PurplePhase      = 0,
	PurpleTick       = 0,
	PurpleStartCFrame= nil,
	IsOverridden     = {},
	JoinedRealPlayers= {},
	-- Murder Mystery
	MMKiller  = nil,
	MMFleeing = {},
	MMChasing = nil,
	-- Among Us
	AURoles   = {},
	AUVents   = {},
	AUTasks   = {},
	AUCafs    = {},
	AUMeeting = false,
	AUVotes   = {},
	AULastKill= tick(),
	AUPhase   = nil,
	-- New features
	ShieldNPCs    = false,   -- ghost: NPCs become translucent & no-collide
	FrenzyMode    = false,   -- frenzy: NPCs sprint/jump chaotically
	SpotlightNPC  = nil,     -- spotlight [id]: camera lock onto NPC
	CongaMode     = false,   -- conga: chain-follow like a conga line
	ScatterRadius = 60,
	WhoDidItTarget= nil,
	KillTargetNPC = nil,
	nextGossipTick= 0,
	WallPos       = nil,
	WallDir       = nil,
	-- Whitelist: players allowed to use commands besides LocalPlayer
	Whitelist     = {},  -- [Player] = true
}

-- ═══════════════════════════════════════════════════════════
--  CONNECTION SYSTEM  (lag-free, proximity-resistant)
--
--  KEY DESIGN: nothing iterates NPC descendants every frame.
--  All heavy work is throttled per-NPC with cooldowns.
--  Only HRP ownership matters — Roblox decides ownership by
--  the primary part, not every limb.
-- ═══════════════════════════════════════════════════════════

-- ── SimulationRadius: set once, re-set only on respawn ──
local function pushSimRadius()
	if not LocalPlayer then return end
	pcall(function()
		if sethiddenproperty then
			sethiddenproperty(LocalPlayer, "SimulationRadius",    math.huge)
			sethiddenproperty(LocalPlayer, "MaxSimulationRadius", math.huge)
		end
	end)
end
pushSimRadius()
-- Re-apply on character respawn (radius resets on death)
Players.LocalPlayer and Players.LocalPlayer.CharacterAdded:Connect(pushSimRadius)

-- Radius visualiser — only runs when ShowRadius is toggled on
task.spawn(function()
	while task.wait(0.5) do
		pcall(function()
			local r       = state.NetworkRange or math.huge
			local radPart = workspace:FindFirstChild("NPCRadiusVisual")
			if state.ShowRadius and r ~= math.huge then
				if not radPart then
					radPart            = Instance.new("Part")
					radPart.Name       = "NPCRadiusVisual"
					radPart.Shape      = Enum.PartType.Ball
					radPart.Material   = Enum.Material.ForceField
					radPart.Color      = Color3.fromRGB(0, 255, 0)
					radPart.Anchored   = true
					radPart.CanCollide = false
					radPart.CastShadow = false
					radPart.Parent     = workspace
				end
				radPart.Size = Vector3.new(r*2, r*2, r*2)
				local myRoot = LocalPlayer and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
				if myRoot then radPart.Position = myRoot.Position end
			elseif radPart then
				radPart:Destroy()
			end
		end)
	end
end)

-- ── Ownership: only HRP needs SetNetworkOwner(nil) ──
-- Roblox determines ownership from the assembly root (HRP).
-- Iterating all limbs was the #1 lag source — removed.
local function enforceServerOwnership(npc)
	local hrp = npc:FindFirstChild("HumanoidRootPart")
	if not hrp then return end
	pcall(function() hrp:SetNetworkOwner(nil) end)
	pcall(function()
		if type(setnetworkowner) == "function" then
			setnetworkowner(hrp, nil)
		end
	end)
end

-- ── Connection check: fast path first, pcall only as fallback ──
local function isConnected(npc)
	local hrp = npc:FindFirstChild("HumanoidRootPart")
	if not hrp then return false end

	-- Fast path: exploit-level owner check (no pcall overhead if available)
	if type(getnetworkowner) == "function" then
		local ok, owner = pcall(getnetworkowner, hrp)
		if ok and owner == nil then return true end
	end

	-- Standard API fallback
	local ok2, owner2 = pcall(function() return hrp:GetNetworkOwner() end)
	if ok2 and owner2 == nil then return true end

	-- ReceiveAge fallback: 0 = we are simulating this part locally
	local ok3, age = pcall(function() return hrp.ReceiveAge end)
	if ok3 and age == 0 and not hrp.Anchored then return true end

	return false
end

-- ── forceConnect: lightweight — no descendant iteration ──
local function forceConnect(npc)
	local hrp = npc:FindFirstChild("HumanoidRootPart")
	if not hrp then return end
	local hum = npc:FindFirstChild("Humanoid")
	if not hum or hum.Health <= 0 then return end

	enforceServerOwnership(npc)
	hrp.Anchored = false

	pcall(function()
		hum:ChangeState(Enum.HumanoidStateType.Running)
		hum.PlatformStand = false
		hum.Sit           = false
		hum.AutoRotate    = true
	end)

	-- Single upward nudge is enough to wake physics
	pcall(function()
		hrp.AssemblyLinearVelocity = hrp.AssemblyLinearVelocity + Vector3.new(0, 0.05, 0)
	end)
end

-- ═══════════════════════════════════════════════════════════
--  CLONE RECOVERY  (throttled, non-blocking, no jitter)
-- ═══════════════════════════════════════════════════════════
local CloneRecovery    = {}
local recoveryInFlight = {}

function CloneRecovery.IsConnected(npc)
	return isConnected(npc)
end

function CloneRecovery.Recover(npc)
	if isConnected(npc) then return true end
	if recoveryInFlight[npc] then return false end
	recoveryInFlight[npc] = true

	-- Burst: 5 attempts, 0.1s apart — enough to reclaim without flooding
	for i = 1, 5 do
		forceConnect(npc)
		if isConnected(npc) then
			recoveryInFlight[npc] = nil
			return true
		end
		task.wait(0.1)
	end

	recoveryInFlight[npc] = nil
	return isConnected(npc)
end

function CloneRecovery.Verify(npc)
	if isConnected(npc) then return true end
	task.spawn(function() CloneRecovery.Recover(npc) end)
	return false
end

-- ═══════════════════════════════════════════════════════════
--  PROXIMITY WATCH  — pre-empt ownership steal
--  Runs every 0.5s (not 0.1s). Only fires enforceServer-
--  Ownership when a player is actually close — not every tick.
-- ═══════════════════════════════════════════════════════════
local PROXIMITY_STEAL_RANGE = 20

task.spawn(function()
	while task.wait(0.5) do
		pcall(function()
			local allPlayers = Players:GetPlayers()
			for _, npc in ipairs(cachedNpcsList) do
				local hrp = npc:FindFirstChild("HumanoidRootPart")
				local hum = npc:FindFirstChild("Humanoid")
				if not hrp or not hum or hum.Health <= 0 then continue end

				for _, p in ipairs(allPlayers) do
					if p == LocalPlayer then continue end
					local pRoot = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
					if pRoot and (pRoot.Position - hrp.Position).Magnitude < PROXIMITY_STEAL_RANGE then
						-- Someone is close — reclaim HRP ownership only
						enforceServerOwnership(npc)
						if not isConnected(npc) then
							task.spawn(function() CloneRecovery.Recover(npc) end)
						end
						break
					end
				end
			end
		end)
	end
end)

-- ═══════════════════════════════════════════════════════════
--  WATCHDOG  — catch any NPC that slipped through
--  Runs every 1s, not 0.15s. Recovery has its own cooldown.
-- ═══════════════════════════════════════════════════════════
task.spawn(function()
	while task.wait(1) do
		pcall(function()
			for _, npc in ipairs(cachedNpcsList) do
				local hum = npc:FindFirstChild("Humanoid")
				if hum and hum.Health > 0 and not isConnected(npc) then
					local cache   = npcCache[npc]
					local lastTry = cache and cache.lastWatchdogTry or 0
					if tick() - lastTry > 2 then
						if cache then cache.lastWatchdogTry = tick() end
						task.spawn(function() CloneRecovery.Recover(npc) end)
					end
				end
			end
		end)
	end
end)

-- ─────────────────────────────────────────
--  TELEPORT HELPER
-- ─────────────────────────────────────────
local function teleportNPC(npc, targetCFrame)
	local hrp = npc:FindFirstChild("HumanoidRootPart")
	if not hrp then return false end
	if not CloneRecovery.Verify(npc) then return false end
	hrp.CFrame = targetCFrame
	hrp.AssemblyLinearVelocity  = Vector3.zero
	hrp.AssemblyAngularVelocity = Vector3.zero
	return true
end

-- ─────────────────────────────────────────
--  NPC CACHE
-- ─────────────────────────────────────────
local npcCache         = {}
local cachedNpcsList   = {}
local nextNpcId        = 1
local npcOwnershipState= {}
local lastNpcRefresh   = 0

local function refreshNPCs()
	local current = {}
	for _, obj in ipairs(workspace:GetDescendants()) do
		local hum = obj:FindFirstChild("Humanoid")
		if obj:IsA("Model") and hum and hum.Health > 0 and obj:FindFirstChild("HumanoidRootPart") then
			local isPlayer = false
			for _, p in ipairs(Players:GetPlayers()) do
				if p.Character == obj then isPlayer = true; break end
			end
			if not isPlayer then
				table.insert(current, obj)
				if not npcCache[obj] then
					npcCache[obj] = { id = nextNpcId, type = obj.Name }
					nextNpcId = nextNpcId + 1
				end
			end
		end
	end
	cachedNpcsList = current
end

local function getNPCs()
	if tick() - lastNpcRefresh > 2 then
		lastNpcRefresh = tick()
		task.spawn(refreshNPCs)
	end
	for i = #cachedNpcsList, 1, -1 do
		local obj = cachedNpcsList[i]
		local hum = obj and obj:FindFirstChild("Humanoid")
		if not obj or not obj.Parent or not obj:FindFirstChild("HumanoidRootPart") or not hum or hum.Health <= 0 then
			table.remove(cachedNpcsList, i)
		end
	end
	for obj in pairs(npcCache) do
		if not obj or not obj.Parent then
			npcCache[obj] = nil
			npcOwnershipState[obj] = nil
		end
	end
	return cachedNpcsList
end

local function getNPCById(id)
	for obj, data in pairs(npcCache) do
		if data.id == id and obj and obj.Parent then return obj end
	end
	return nil
end

-- ─────────────────────────────────────────
--  PLAYER LOOKUP
-- ─────────────────────────────────────────
local function getPlayer(nameStr)
	if type(nameStr) ~= "string" then return nil end
	local low = string.lower(string.match(nameStr, "^%s*(.-)%s*$") or nameStr)
	low = string.gsub(low, "[%(%)]", "")
	if low == "" then return nil end
	for _, p in ipairs(Players:GetPlayers()) do
		if string.lower(p.Name) == low or string.lower(p.DisplayName) == low then return p end
	end
	for _, p in ipairs(Players:GetPlayers()) do
		local pn = string.lower(p.Name)
		local pd = string.lower(p.DisplayName)
		if string.find(pn, low, 1, true) or string.find(pd, low, 1, true) then return p end
	end
	return nil
end

local function notify(title, text)
	print("[NPC v2] " .. title .. ": " .. text)
	pcall(function()
		game:GetService("StarterGui"):SetCore("SendNotification", {
			Title    = title,
			Text     = text,
			Duration = 3,
		})
	end)
end

-- ─────────────────────────────────────────
--  GUI
-- ─────────────────────────────────────────
local targetParent = LocalPlayer and LocalPlayer:WaitForChild("PlayerGui") or game:GetService("StarterGui")
pcall(function()
	for _, g in ipairs(targetParent:GetChildren()) do
		if g.Name == "NPCv2GUI" then g:Destroy() end
	end
end)

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name           = "NPCv2GUI"
ScreenGui.ResetOnSpawn   = false
ScreenGui.DisplayOrder   = 9999
ScreenGui.IgnoreGuiInset = true
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent         = targetParent

-- Bubble (minimized icon)
local BubbleFrame = Instance.new("ImageButton")
BubbleFrame.Size              = UDim2.new(0, 50, 0, 50)
BubbleFrame.AnchorPoint       = Vector2.new(0.5, 0)
BubbleFrame.Position          = UDim2.new(0.5, 0, 0.1, 0)
BubbleFrame.BackgroundColor3  = Color3.fromRGB(30, 30, 30)
BubbleFrame.Visible           = false
BubbleFrame.AutoButtonColor   = false
BubbleFrame.Parent            = ScreenGui
Instance.new("UICorner", BubbleFrame).CornerRadius = UDim.new(1, 0)
local BubbleText = Instance.new("TextLabel", BubbleFrame)
BubbleText.Size                = UDim2.new(1,0,1,0)
BubbleText.BackgroundTransparency = 1
BubbleText.Text                = "NPC"
BubbleText.TextColor3          = Color3.fromRGB(255,255,255)
BubbleText.Font                = Enum.Font.SourceSansBold
BubbleText.TextSize            = 14

-- Main frame
local MainFrame = Instance.new("Frame")
MainFrame.Size            = UDim2.new(0, 160, 0, 340)
MainFrame.AnchorPoint     = Vector2.new(0.5, 0.5)
MainFrame.Position        = UDim2.new(0.5, 0, 0.5, 0)
MainFrame.BackgroundColor3= Color3.fromRGB(35, 35, 35)
MainFrame.Active          = true
MainFrame.Parent          = ScreenGui

local CloseBtn = Instance.new("TextButton", MainFrame)
CloseBtn.Size             = UDim2.new(0, 25, 0, 25)
CloseBtn.Position         = UDim2.new(1, -25, 0, 0)
CloseBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
CloseBtn.TextColor3       = Color3.fromRGB(255,255,255)
CloseBtn.Text             = "X"
CloseBtn.Font             = Enum.Font.SourceSansBold
CloseBtn.TextSize         = 14
CloseBtn.MouseButton1Click:Connect(function()
	MainFrame.Visible  = false
	BubbleFrame.Visible= true
end)
BubbleFrame.MouseButton1Click:Connect(function()
	BubbleFrame.Visible= false
	MainFrame.Visible  = true
end)

local Title = Instance.new("TextLabel", MainFrame)
Title.Size             = UDim2.new(1, -25, 0, 25)
Title.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
Title.TextColor3       = Color3.fromRGB(255,255,255)
Title.Text             = "NPC Controller v2"
Title.Font             = Enum.Font.SourceSansBold
Title.TextSize         = 14

local MainScroll = Instance.new("ScrollingFrame", MainFrame)
MainScroll.Size               = UDim2.new(1, 0, 1, -25)
MainScroll.Position           = UDim2.new(0, 0, 0, 25)
MainScroll.BackgroundColor3   = Color3.fromRGB(35, 35, 35)
MainScroll.ScrollBarThickness = 4
MainScroll.CanvasSize         = UDim2.new(0, 0, 0, 400)
local UIList = Instance.new("UIListLayout", MainScroll)
UIList.Padding              = UDim.new(0, 2)
UIList.HorizontalAlignment  = Enum.HorizontalAlignment.Center
UIList:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
	MainScroll.CanvasSize = UDim2.new(0, 0, 0, UIList.AbsoluteContentSize.Y + 10)
end)

local function makeToggle(name)
	local b = Instance.new("TextButton", MainScroll)
	b.Size             = UDim2.new(1, -16, 0, 25)
	b.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
	b.TextColor3       = Color3.fromRGB(255, 255, 255)
	b.Text             = name .. ": OFF"
	b.Font             = Enum.Font.SourceSans
	b.TextSize         = 12
	return b
end
local function makeButton(name, col)
	local b = Instance.new("TextButton", MainScroll)
	b.Size             = UDim2.new(1, -16, 0, 25)
	b.BackgroundColor3 = col or Color3.fromRGB(70, 70, 70)
	b.TextColor3       = Color3.fromRGB(255, 255, 255)
	b.Text             = name
	b.Font             = Enum.Font.SourceSans
	b.TextSize         = 12
	return b
end

local btnFollow      = makeToggle("Follow Me")
local btnSpin        = makeToggle("Spin NPCs")
local btnChat        = makeToggle("Chat Cmds")
local btnESP         = makeToggle("NPC ESP")
local btnAutoConnect = makeToggle("Auto Connect")
local btnGossip      = makeToggle("Gossip Mode")
local btnAntiLag     = makeToggle("Anti-Lag")
local btnShowRadius  = makeToggle("Visible Radius")
local btnFrenzy      = makeToggle("Frenzy Mode")
local btnGhost       = makeToggle("Ghost Mode")
local btnCmdsList    = makeButton("Show Commands")
local btnNPCList     = makeButton("NPC Lists")
local btnKillRad     = makeButton("Kill NPCs (2 Studs)",   Color3.fromRGB(150, 50, 50))
local btnKillPass    = makeButton("Kill Passive (900 Studs)", Color3.fromRGB(150, 50, 80))
local btnWake        = makeButton("Wake All NPCs",         Color3.fromRGB(50, 100, 180))

-- NPC List panel
local NPCListFrame = Instance.new("Frame", MainFrame)
NPCListFrame.Size             = UDim2.new(0, 250, 1, 0)
NPCListFrame.Position         = UDim2.new(1, 10, 0, 0)
NPCListFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
NPCListFrame.Visible          = false
local NPCListTitle = Instance.new("TextLabel", NPCListFrame)
NPCListTitle.Size             = UDim2.new(1, 0, 0, 30)
NPCListTitle.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
NPCListTitle.TextColor3       = Color3.fromRGB(255,255,255)
NPCListTitle.Text             = "NPC Connections List"
NPCListTitle.Font             = Enum.Font.SourceSansBold
NPCListTitle.TextSize         = 14
local NPCScroll = Instance.new("ScrollingFrame", NPCListFrame)
NPCScroll.Size                = UDim2.new(1, 0, 1, -30)
NPCScroll.Position            = UDim2.new(0, 0, 0, 30)
NPCScroll.BackgroundColor3    = Color3.fromRGB(30, 30, 30)
NPCScroll.ScrollBarThickness  = 5
NPCScroll.CanvasSize          = UDim2.new(0, 0, 0, 0)
local UIListNPC = Instance.new("UIListLayout", NPCScroll)
UIListNPC.Padding = UDim.new(0, 2)
UIListNPC:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
	NPCScroll.CanvasSize = UDim2.new(0, 0, 0, UIListNPC.AbsoluteContentSize.Y)
end)

-- Commands list panel
local CmdsFrame = Instance.new("Frame", MainFrame)
CmdsFrame.Size             = UDim2.new(0, 260, 0, 380)
CmdsFrame.Position         = UDim2.new(0, -270, 0, 0)
CmdsFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
CmdsFrame.Visible          = false
local CmdsTitle = Instance.new("TextLabel", CmdsFrame)
CmdsTitle.Size             = UDim2.new(1, 0, 0, 30)
CmdsTitle.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
CmdsTitle.TextColor3       = Color3.fromRGB(255,255,255)
CmdsTitle.Text             = "Chat Command List"
CmdsTitle.Font             = Enum.Font.SourceSansBold
CmdsTitle.TextSize         = 14
local CmdsScroll = Instance.new("ScrollingFrame", CmdsFrame)
CmdsScroll.Size                = UDim2.new(1, 0, 1, -30)
CmdsScroll.Position            = UDim2.new(0, 0, 0, 30)
CmdsScroll.BackgroundColor3    = Color3.fromRGB(30, 30, 30)
CmdsScroll.ScrollBarThickness  = 5
local CmdsLayout = Instance.new("UIListLayout", CmdsScroll)
CmdsLayout.Padding = UDim.new(0, 2)
CmdsLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
	CmdsScroll.CanvasSize = UDim2.new(0, 0, 0, CmdsLayout.AbsoluteContentSize.Y)
end)

local cmdListText = {
	"── MOVEMENT ──",
	"follow me       – Follow you",
	"arise           – Walk randomly",
	"makeway         – Spread away from you",
	"train           – Follow each other",
	"assemble        – Line up behind you",
	"stack up        – Stack in front of you",
	"conga           – Conga-line follow",
	"scatter         – Flee in all directions",
	"recall          – Return to your side",
	"── FORMATION ──",
	"orbit           – Circle around you",
	"ufo             – Float + orbit",
	"wall orbit      – Orbit in a wall",
	"make a wall     – 5-wide wall",
	"star            – Star-shaped orbit",
	"sphere          – Sphere orbit",
	"sts             – Shoulder-to-shoulder",
	"helicopter      – Helicopter formation",
	"mecha           – Combine into mecha",
	"stairs          – Staircase in front",
	"── ACTIONS ──",
	"sit             – Sit down",
	"dance           – Dance",
	"do a backflip   – Backflip",
	"yes or no       – Random nod/shake",
	"who did it      – Point at random player",
	"flashstep [id]  – NPC vanishes & reappears at you",
	"── TARGETING ──",
	"attack [player] – Chase and attack",
	"fling [player]  – Walk target to fling",
	"kill [id/name]  – Chase and kill NPC",
	"find [player]   – Push you to player",
	"look at [player]– Face target",
	"── CONTROL ──",
	"stay [id/all]   – Freeze in place",
	"follow [id/all] – Unfreeze",
	".wake           – Teleport all NPCs to you",
	"tp [id]         – Teleport to NPC",
	"posses [id]     – Control NPC body",
	"unposses        – Stop possessing",
	"spotlight [id]  – Camera snap to NPC",
	"unspotlight     – Return camera",
	"[id] goto [p]   – Teleport NPC to player",
	"[id] tempgoto [p]– Temp teleport (5s)",
	"[id] follow [p] – NPC follows specific player",
	"── EFFECTS ──",
	"ghost           – NPCs translucent, no-collide",
	"unghost         – Restore NPCs",
	"frenzy          – Random sprint/jump chaos",
	"shield          – Bodyguard ring around you",
	"unshield        – Remove shield",
	"── PATHFINDING ──",
	"pathfind [player]– Navigate to player",
	"roam here [id]  – Set roam waypoint (use 2x)",
	"stop roam [id]  – Cancel roaming",
	"── ORBIT TUNING ──",
	"orbit speed [n] – Set orbit speed",
	"── NETWORK ──",
	"self defense        – Toggle fling protection",
	".whitelist [user]   – Allow player to use cmds",
	".unwhitelist [user] – Remove player from list",
	".wlist              – Show whitelisted players",
	"── JJK MOVES ──",
	"lapse blue      – Gojo Lapse Blue",
	"reversal red    – Gojo Reversal Red",
	"hollow purple   – Combine Blue + Red",
	"── GAMES ──",
	"murder mystery  – Start Murder Mystery",
	"!among us       – Start Among Us",
	"!build          – Map build tool",
	"!stop game      – Stop minigame",
	"!freeze         – Freeze all NPCs",
	"!unfreeze       – Unfreeze all NPCs",
	"!attack [p]     – All NPCs attack player",
}
for _, msg in ipairs(cmdListText) do
	local lbl = Instance.new("TextLabel", CmdsScroll)
	lbl.Size                 = UDim2.new(1, -10, 0, 22)
	lbl.BackgroundTransparency = 1
	lbl.TextColor3           = msg:find("──") and Color3.fromRGB(120,200,255) or Color3.fromRGB(220,220,220)
	lbl.Text                 = " " .. msg
	lbl.TextXAlignment       = Enum.TextXAlignment.Left
	lbl.Font                 = Enum.Font.SourceSans
	lbl.TextSize             = 13
end

-- ─────────────────────────────────────────
--  DRAGGABLE FRAMES
-- ─────────────────────────────────────────
local function makeDraggable(frame)
	local dragging, dragInput, dragStart, startPos
	frame.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging  = true
			dragStart = input.Position
			startPos  = frame.Position
			input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then dragging = false end
			end)
		end
	end)
	frame.InputChanged:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
			dragInput = input
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if input == dragInput and dragging then
			local delta = input.Position - dragStart
			frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
		end
	end)
end
makeDraggable(MainFrame)
makeDraggable(BubbleFrame)

-- ─────────────────────────────────────────
--  GUI BUTTON LOGIC
-- ─────────────────────────────────────────
btnCmdsList.MouseButton1Click:Connect(function() CmdsFrame.Visible = not CmdsFrame.Visible end)
btnNPCList.MouseButton1Click:Connect(function() NPCListFrame.Visible = not NPCListFrame.Visible end)

btnFollow.MouseButton1Click:Connect(function()
	state.Follow = not state.Follow
	btnFollow.Text = "Follow Me: " .. (state.Follow and "ON" or "OFF")
	if state.Follow then state.Mode = nil; state.CommandIssuer = LocalPlayer end
end)
btnSpin.MouseButton1Click:Connect(function()
	state.Spin = not state.Spin
	btnSpin.Text = "Spin NPCs: " .. (state.Spin and "ON" or "OFF")
	for _, npc in ipairs(getNPCs()) do
		local hrp = npc:FindFirstChild("HumanoidRootPart")
		if hrp then
			if state.Spin then
				local att = Instance.new("Attachment", hrp); att.Name = "SpinAtt"
				local av = Instance.new("AngularVelocity", hrp)
				av.Name = "NPCSpin"; av.MaxTorque = math.huge
				av.AngularVelocity = Vector3.new(0, 50, 0); av.Attachment0 = att
			else
				local av = hrp:FindFirstChild("NPCSpin"); if av then av:Destroy() end
				local att = hrp:FindFirstChild("SpinAtt"); if att then att:Destroy() end
				pcall(function() hrp.RotVelocity = Vector3.new(0,0,0) end)
			end
		end
	end
end)
btnChat.MouseButton1Click:Connect(function()
	state.Chat = not state.Chat
	btnChat.Text = "Chat Cmds: " .. (state.Chat and "ON" or "OFF")
end)
btnESP.MouseButton1Click:Connect(function()
	state.ESP = not state.ESP
	btnESP.Text = "NPC ESP: " .. (state.ESP and "ON" or "OFF")
	if not state.ESP then
		for _, npc in ipairs(getNPCs()) do
			local hl = npc:FindFirstChild("NPC_ESP_HL"); if hl then hl:Destroy() end
			local bb = npc:FindFirstChild("NPC_ESP_BB"); if bb then bb:Destroy() end
		end
	end
end)
btnAutoConnect.MouseButton1Click:Connect(function()
	state.AutoConnect = not state.AutoConnect
	btnAutoConnect.Text = "Auto Connect: " .. (state.AutoConnect and "ON" or "OFF")
end)
btnGossip.MouseButton1Click:Connect(function()
	state.Gossip = not state.Gossip
	btnGossip.Text = "Gossip Mode: " .. (state.Gossip and "ON" or "OFF")
end)
btnAntiLag.MouseButton1Click:Connect(function()
	state.AntiLag = not state.AntiLag
	btnAntiLag.Text = "Anti-Lag: " .. (state.AntiLag and "ON" or "OFF")
	for _, npc in ipairs(getNPCs()) do
		for _, v in ipairs(npc:GetDescendants()) do
			if v:IsA("BasePart") then
				v.Material  = state.AntiLag and Enum.Material.SmoothPlastic or Enum.Material.Plastic
				v.CastShadow= not state.AntiLag
			end
		end
	end
end)
btnShowRadius.MouseButton1Click:Connect(function()
	state.ShowRadius = not state.ShowRadius
	btnShowRadius.Text = "Visible Radius: " .. (state.ShowRadius and "ON" or "OFF")
	btnShowRadius.BackgroundColor3 = state.ShowRadius and Color3.fromRGB(50,150,50) or Color3.fromRGB(50,50,50)
end)
btnFrenzy.MouseButton1Click:Connect(function()
	state.FrenzyMode = not state.FrenzyMode
	btnFrenzy.Text = "Frenzy Mode: " .. (state.FrenzyMode and "ON" or "OFF")
	btnFrenzy.BackgroundColor3 = state.FrenzyMode and Color3.fromRGB(200,80,0) or Color3.fromRGB(50,50,50)
end)
btnGhost.MouseButton1Click:Connect(function()
	state.ShieldNPCs = not state.ShieldNPCs  -- reusing ShieldNPCs bool as ghost toggle here for GUI
	local isGhost = state.ShieldNPCs
	btnGhost.Text = "Ghost Mode: " .. (isGhost and "ON" or "OFF")
	for _, npc in ipairs(getNPCs()) do
		for _, v in ipairs(npc:GetDescendants()) do
			if v:IsA("BasePart") then
				v.Transparency = isGhost and 0.7 or 0
				v.CanCollide   = not isGhost
			end
		end
	end
end)

-- Kill buttons
btnKillRad.MouseButton1Click:Connect(function()
	local myRoot = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
	if not myRoot then return end
	local count = 0
	for _, npc in ipairs(getNPCs()) do
		local hrp = npc:FindFirstChild("HumanoidRootPart")
		local hum = npc:FindFirstChild("Humanoid")
		if hrp and hum and hum.Health > 0 and (hrp.Position - myRoot.Position).Magnitude <= 2.5 then
			hrp.CFrame = CFrame.new(0, -50000, 0)
			pcall(function() hrp.AssemblyLinearVelocity = Vector3.new(0,-1000,0) end)
			count = count + 1
		end
	end
	notify("Kill", "Killed " .. count .. " NPCs nearby")
end)
btnKillPass.MouseButton1Click:Connect(function()
	local myRoot = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
	if not myRoot then return end
	local count = 0
	for _, npc in ipairs(getNPCs()) do
		local hrp = npc:FindFirstChild("HumanoidRootPart")
		local hum = npc:FindFirstChild("Humanoid")
		if hrp and hum and hum.Health > 0 and (hrp.Position - myRoot.Position).Magnitude <= 900 then
			if not isConnected(npc) then
				hrp.CFrame = CFrame.new(0, -50000, 0)
				pcall(function() hrp.AssemblyLinearVelocity = Vector3.new(0,-1000,0) end)
				count = count + 1
			end
		end
	end
	notify("Kill Passive", "Killed " .. count .. " unowned NPCs")
end)

-- .wake button
btnWake.MouseButton1Click:Connect(function()
	local pChar = LocalPlayer.Character
	local pRoot = pChar and pChar:FindFirstChild("HumanoidRootPart")
	if not pRoot then return end
	task.spawn(function()
		local npcs = getNPCs()
		local ok, fail = 0, 0
		for i, npc in ipairs(npcs) do
			local offset = Vector3.new(math.cos(i / #npcs * math.pi * 2) * 6, 0, math.sin(i / #npcs * math.pi * 2) * 6)
			local success = teleportNPC(npc, pRoot.CFrame + offset)
			if success then ok = ok + 1 else fail = fail + 1 end
		end
		notify("Wake", "Woke " .. ok .. " NPCs (" .. fail .. " failed)")
	end)
end)

-- ═══════════════════════════════════════════════════════════
--  PERSISTENT OWNERSHIP ENFORCEMENT LOOP
--  Runs every 1s. Only does HRP SetNetworkOwner — no loops
--  over descendants. Recovery fires with a per-NPC cooldown.
-- ═══════════════════════════════════════════════════════════
task.spawn(function()
	while task.wait(1) do
		pcall(function()
			local npcs = getNPCs()
			for _, npc in ipairs(npcs) do
				local hum = npc:FindFirstChild("Humanoid")
				if not hum or hum.Health <= 0 then continue end

				enforceServerOwnership(npc)  -- HRP only, cheap

				if not isConnected(npc) then
					local cache   = npcCache[npc]
					local lastTry = cache and cache.lastForceConnect or 0
					local cd      = state.AutoConnect and 1 or 3
					if tick() - lastTry > cd then
						if cache then cache.lastForceConnect = tick() end
						task.spawn(function() CloneRecovery.Recover(npc) end)
					end
				end
			end
		end)
	end
end)

-- Pathfind update loop
task.spawn(function()
	while task.wait(0.5) do
		if not state.AutoConnect then continue end
		local npcs = getNPCs()
		local targetRoot = nil
		if state.Follow and state.CommandIssuer and state.CommandIssuer.Character then
			targetRoot = state.CommandIssuer.Character:FindFirstChild("HumanoidRootPart")
		end
		if not targetRoot then continue end
		for _, npc in ipairs(npcs) do
			local hrp   = npc:FindFirstChild("HumanoidRootPart")
			local hum   = npc:FindFirstChild("Humanoid")
			local cache = npcCache[npc]
			if hrp and hum and hum.Health > 0 and cache and isConnected(npc) then
				local dist = (hrp.Position - targetRoot.Position).Magnitude
				if dist > 5 and dist < 500 then
					local ray = Ray.new(hrp.Position, (targetRoot.Position - hrp.Position).Unit * dist)
					local hit = workspace:FindPartOnRayWithIgnoreList(ray, {npc, targetRoot.Parent})
					if hit and not hit.CanCollide then hit = nil end
					if hit then
						local path = PathfindingService:CreatePath({
							AgentRadius = 2, AgentHeight = 5,
							AgentCanJump = true, AgentCanClimb = true,
							WaypointSpacing = 4,
						})
						pcall(function()
							path:ComputeAsync(hrp.Position, targetRoot.Position)
							if path.Status == Enum.PathStatus.Success then
								cache.waypoints      = path:GetWaypoints()
								cache.currentWaypoint= 2
							else
								cache.waypoints = nil
							end
						end)
					else
						cache.waypoints = nil
					end
				else
					cache.waypoints = nil
				end
			end
		end
	end
end)

-- ─────────────────────────────────────────
--  CHAT COMMAND HANDLER
-- ─────────────────────────────────────────
-- ── Whitelist helpers ──
local function isAuthorized(player)
	if player == LocalPlayer then return true end
	return state.Whitelist[player] == true
end

local function isOwner(player)
	return player == LocalPlayer
end

local function handleCommand(player, msg)
	if type(msg) ~= "string" then return end
	if not state.Chat then return end

	-- .whitelist / .unwhitelist are owner-only and work even before the
	-- auth check so the owner can always manage the list.
	local rawLower = string.lower(string.match(msg, "^%s*(.-)%s*$") or msg)
	local rawArgs  = string.split(rawLower, " ")
	if rawArgs[1] == ".whitelist" or rawArgs[1] == ".unwhitelist" or rawArgs[1] == ".wlist" then
		if not isOwner(player) then return end  -- only owner can manage whitelist
		local targetName = table.concat(rawArgs, " ", 2)
		local target     = getPlayer(targetName)
		if rawArgs[1] == ".whitelist" then
			if target then
				state.Whitelist[target] = true
				notify("Whitelist", target.Name .. " can now use NPC commands")
			else
				notify("Whitelist", "Player not found: " .. targetName)
			end
		elseif rawArgs[1] == ".unwhitelist" then
			if target then
				state.Whitelist[target] = nil
				notify("Whitelist", target.Name .. " removed from whitelist")
			else
				notify("Whitelist", "Player not found: " .. targetName)
			end
		elseif rawArgs[1] == ".wlist" then
			-- Show current whitelist
			local names = {}
			for p in pairs(state.Whitelist) do
				if p and p.Parent then
					table.insert(names, p.Name)
				else
					state.Whitelist[p] = nil  -- clean up left players
				end
			end
			if #names == 0 then
				notify("Whitelist", "No whitelisted players")
			else
				notify("Whitelist", table.concat(names, ", "))
			end
		end
		return
	end

	-- All other commands: must be owner or whitelisted
	if not isAuthorized(player) then return end

	local msgLower = string.lower(msg)
	local args     = string.split(msgLower, " ")
	local cmd      = args[1]

	-- ── Numeric ID commands ──
	local isNumFirst = tonumber(cmd) ~= nil
	if isNumFirst then
		local npcId  = tonumber(cmd)
		local subCmd = args[2]
		local npc    = getNPCById(npcId)
		if not npc then return end
		if subCmd == "follow" and args[3] then
			local target = getPlayer(table.concat(args, " ", 3))
			if target then
				state.SpecificFollow[npc] = target
				notify("Follow", "NPC "..npcId.." following "..target.Name)
			end
		elseif subCmd == "goto" and args[3] then
			local target = getPlayer(table.concat(args, " ", 3))
			if target and target.Character then
				local tRoot = target.Character:FindFirstChild("HumanoidRootPart")
				local hrp   = npc:FindFirstChild("HumanoidRootPart")
				if tRoot and hrp then
					teleportNPC(npc, tRoot.CFrame * CFrame.new(0, 0, -3))
				end
			end
		elseif subCmd == "tempgoto" and args[3] then
			local target = getPlayer(table.concat(args, " ", 3))
			if target and target.Character then
				task.spawn(function()
					local tRoot = target.Character:FindFirstChild("HumanoidRootPart")
					local hrp   = npc:FindFirstChild("HumanoidRootPart")
					if tRoot and hrp then
						teleportNPC(npc, tRoot.CFrame * CFrame.new(0, 0, -3))
						task.wait(5)
						local myRoot = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
						if myRoot and hrp then
							teleportNPC(npc, myRoot.CFrame * CFrame.new(0, 0, -3))
						end
					end
				end)
			end
		end
		return
	end

	-- ── Named commands ──
	if cmd == "ufo" then
		state.Mode = "UFO"; state.Follow = false; state.CommandIssuer = player
		notify("UFO", "Orbit mode active")

	elseif cmd == "orbit" then
		state.Mode = "Orbit"; state.Follow = false; state.CommandIssuer = player
		notify("Orbit", "Circling you")

	elseif cmd == "star" then
		state.Mode = "Star"; state.Follow = false; state.CommandIssuer = player

	elseif cmd == "sphere" then
		state.Mode = "Sphere"; state.Follow = false; state.CommandIssuer = player

	elseif cmd == "wall" and args[2] == "orbit" then
		state.Mode = "WallOrbit"; state.Follow = false; state.CommandIssuer = player

	elseif cmd == "helicopter" then
		state.Mode = "Helicopter"; state.Follow = false; state.CommandIssuer = player

	elseif cmd == "mecha" then
		state.Mode = "Mecha"; state.Follow = false; state.CommandIssuer = player

	elseif cmd == "sts" then
		state.Mode = "STS"; state.Follow = false; state.CommandIssuer = player

	elseif cmd == "make" and args[2] == "a" and args[3] == "wall" then
		state.Mode = "Wall"; state.Follow = false; state.CommandIssuer = player
		local issuerRoot = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if issuerRoot then
			state.WallPos = issuerRoot.Position + issuerRoot.CFrame.LookVector * 10
			state.WallDir = issuerRoot.CFrame.RightVector
		end

	elseif cmd == "stairs" then
		state.Mode = "Stairs"; state.Follow = false; state.CommandIssuer = player

	elseif cmd == "assemble" then
		state.Mode = "Assemble"; state.Follow = false; state.CommandIssuer = player

	elseif cmd == "dance" then
		state.Mode = "Dance"; state.Follow = false; state.CommandIssuer = player

	elseif cmd == "sit" then
		state.Mode = "Sit"; state.Follow = false; state.CommandIssuer = player

	elseif cmd == "yes" and args[2] == "or" and args[3] == "no" then
		state.Mode       = "YesOrNo"
		state.YesOrNoPick= Random.new():NextInteger(1, 2)
		state.YesOrNoTick= tick()
		state.Follow     = false; state.CommandIssuer = player

	elseif cmd == "do" and args[2] == "a" and args[3] == "backflip" then
		state.Mode = "Backflip"; state.Follow = false; state.CommandIssuer = player

	elseif cmd == "who" and args[2] == "did" and args[3] == "it" then
		state.Mode = "WhoDidIt"; state.Follow = false; state.CommandIssuer = player
		local plrs = Players:GetPlayers()
		if #plrs > 0 then state.WhoDidItTarget = plrs[math.random(1, #plrs)] end

	elseif cmd == "train" then
		state.Mode = "Train"; state.Follow = false; state.CommandIssuer = player

	elseif cmd == "makeway" then
		state.Mode = "Makeway"; state.Follow = false; state.CommandIssuer = player

	elseif cmd == "arise" then
		state.Mode = "Arise"; state.Follow = false; state.CommandIssuer = player

	elseif cmd == "stack" and args[2] == "up" then
		state.Mode = "StackUp"; state.Follow = false; state.CommandIssuer = player
		local issuerRoot = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if issuerRoot then
			state.StackUpPos = issuerRoot.Position + issuerRoot.CFrame.LookVector * 5
		end

	elseif cmd == "stay" and args[2] then
		if args[2] == "all" then
			for _, npc in ipairs(getNPCs()) do state.StayingNPCs[npc] = true end
		else
			local npc = getNPCById(tonumber(args[2]))
			if npc then state.StayingNPCs[npc] = true end
		end

	elseif cmd == "follow" and args[2] then
		if args[2] == "all" then
			for _, npc in ipairs(getNPCs()) do state.StayingNPCs[npc] = nil end
		else
			local npc = getNPCById(tonumber(args[2]))
			if npc then state.StayingNPCs[npc] = nil end
		end

	elseif cmd == "attack" and args[2] then
		local target = getPlayer(table.concat(args, " ", 2))
		if target and target.Character then
			state.CurrentTarget = target; state.Mode = "Attack"
			state.Follow = false; state.CommandIssuer = player
		end

	elseif cmd == "look" and args[2] == "at" and args[3] then
		local target = getPlayer(table.concat(args, " ", 3))
		if target then
			state.CurrentTargetName = table.concat(args, " ", 3)
			state.Mode = "LookAt"; state.Follow = false; state.CommandIssuer = player
		end

	elseif cmd == "find" and args[2] then
		state.Mode = "Find"; state.CurrentTargetName = table.concat(args, " ", 2)
		state.Follow = false; state.CommandIssuer = player
		local pRoot = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if pRoot then
			for i, npc in ipairs(getNPCs()) do
				local hrp = npc:FindFirstChild("HumanoidRootPart")
				if hrp then
					local offset = Vector3.new(math.cos(i)*5, 0, math.sin(i)*5)
					hrp.CFrame = pRoot.CFrame + offset
					pcall(function() hrp.AssemblyLinearVelocity = Vector3.zero end)
				end
			end
		end

	elseif cmd == "kill" and args[2] then
		local npc = getNPCById(tonumber(args[2]))
		if not npc then
			for _, n in ipairs(getNPCs()) do
				if string.lower(n.Name) == args[2] then npc = n; break end
			end
		end
		if npc then
			state.Mode = "KillNPC"; state.KillTargetNPC = npc; state.Follow = false
		end

	elseif cmd == "tp" and args[2] then
		local npc    = getNPCById(tonumber(args[2]))
		local myRoot = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
		if npc and myRoot and npc:FindFirstChild("HumanoidRootPart") then
			myRoot.CFrame = npc.HumanoidRootPart.CFrame
			notify("TP", "Teleported to NPC " .. args[2])
		end

	elseif cmd == "posses" and args[2] then
		local npc = getNPCById(tonumber(args[2]))
		if npc and npc:FindFirstChild("Humanoid") then
			state.PossessedNPC = npc
			notify("Possess", "Possessing NPC " .. args[2])
		end

	elseif cmd == "unposses" then
		state.PossessedNPC = nil
		if workspace.CurrentCamera and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
			workspace.CurrentCamera.CameraSubject = LocalPlayer.Character.Humanoid
		end
		notify("Possess", "Unpossessed")

	-- ── .wake: replaces .summon, stronger version ──
	elseif cmd == ".wake" then
		local pRoot = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if pRoot then
			task.spawn(function()
				local npcs = getNPCs()
				local ok, fail = 0, 0
				for i, npc in ipairs(npcs) do
					local angle  = (i / #npcs) * math.pi * 2
					local offset = Vector3.new(math.cos(angle)*6, 0, math.sin(angle)*6)
					if teleportNPC(npc, pRoot.CFrame + offset) then
						ok = ok + 1
					else
						fail = fail + 1
					end
				end
				notify(".wake", ok .. " NPCs woken, " .. fail .. " failed")
			end)
		end

	-- ── NEW: scatter ──
	elseif cmd == "scatter" then
		local pRoot = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if pRoot then
			for _, npc in ipairs(getNPCs()) do
				local hum = npc:FindFirstChild("Humanoid")
				local hrp = npc:FindFirstChild("HumanoidRootPart")
				if hum and hrp then
					local r = state.ScatterRadius
					local dir = Vector3.new(math.random(-100,100)/100, 0, math.random(-100,100)/100).Unit
					hum:MoveTo(hrp.Position + dir * r)
				end
			end
			notify("Scatter", "NPCs fleeing!")
		end

	-- ── NEW: recall ──
	elseif cmd == "recall" then
		local pRoot = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if pRoot then
			for i, npc in ipairs(getNPCs()) do
				local hum = npc:FindFirstChild("Humanoid")
				if hum then
					local offset = Vector3.new(math.cos(i)*4, 0, math.sin(i)*4)
					hum:MoveTo(pRoot.Position + offset)
				end
			end
			notify("Recall", "NPCs returning to you")
		end

	-- ── NEW: conga ──
	elseif cmd == "conga" then
		state.Mode = "Conga"; state.Follow = false; state.CommandIssuer = player
		state.CongaMode = true
		notify("Conga", "Conga line started!")

	-- ── NEW: flashstep [id] ──
	elseif cmd == "flashstep" and args[2] then
		local npc = getNPCById(tonumber(args[2]))
		local pRoot = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if npc and pRoot then
			task.spawn(function()
				local hrp = npc:FindFirstChild("HumanoidRootPart")
				if not hrp then return end
				-- Vanish
				for _, v in ipairs(npc:GetDescendants()) do
					if v:IsA("BasePart") then v.Transparency = 1 end
				end
				task.wait(0.3)
				teleportNPC(npc, pRoot.CFrame * CFrame.new(0, 0, -3))
				task.wait(0.1)
				-- Reappear
				for _, v in ipairs(npc:GetDescendants()) do
					if v:IsA("BasePart") then v.Transparency = 0 end
				end
				notify("Flashstep", "NPC " .. args[2] .. " appeared behind you!")
			end)
		end

	-- ── NEW: ghost / unghost ──
	elseif cmd == "ghost" then
		for _, npc in ipairs(getNPCs()) do
			for _, v in ipairs(npc:GetDescendants()) do
				if v:IsA("BasePart") then v.Transparency = 0.7; v.CanCollide = false end
			end
		end
		notify("Ghost", "NPCs are now ghostly")

	elseif cmd == "unghost" then
		for _, npc in ipairs(getNPCs()) do
			for _, v in ipairs(npc:GetDescendants()) do
				if v:IsA("BasePart") then v.Transparency = 0; v.CanCollide = true end
			end
		end
		notify("Ghost", "NPCs restored")

	-- ── NEW: shield / unshield ──
	elseif cmd == "shield" then
		state.Mode = "Shield"; state.Follow = false; state.CommandIssuer = player
		notify("Shield", "NPCs forming a bodyguard ring")

	elseif cmd == "unshield" then
		if state.Mode == "Shield" then state.Mode = nil end
		notify("Shield", "Shield disbanded")

	-- ── NEW: spotlight [id] ──
	elseif cmd == "spotlight" and args[2] then
		local npc = getNPCById(tonumber(args[2]))
		if npc and npc:FindFirstChild("Humanoid") then
			state.SpotlightNPC = npc
			workspace.CurrentCamera.CameraSubject = npc.Humanoid
			notify("Spotlight", "Camera locked on NPC " .. args[2])
		end

	elseif cmd == "unspotlight" then
		state.SpotlightNPC = nil
		local myChar = LocalPlayer.Character
		if myChar and myChar:FindFirstChild("Humanoid") then
			workspace.CurrentCamera.CameraSubject = myChar.Humanoid
		end
		notify("Spotlight", "Camera restored")

	-- ── NEW: frenzy / unfrenzy ──
	elseif cmd == "frenzy" then
		state.FrenzyMode = not state.FrenzyMode
		notify("Frenzy", state.FrenzyMode and "ACTIVATED" or "Deactivated")

	-- ── Orbit speed ──
	elseif cmd == "orbit" and args[2] == "speed" and args[3] then
		state.OrbitSpeed = tonumber(args[3]) or 1
		notify("Orbit", "Speed set to " .. state.OrbitSpeed)

	-- ── Self defense ──
	elseif cmd == "self" and args[2] == "defense" then
		state.SelfDefense = not state.SelfDefense
		notify("Self Defense", state.SelfDefense and "ON" or "OFF")

	-- ── Roam ──
	elseif cmd == "roam" and args[2] == "here" and args[3] then
		local npc = getNPCById(tonumber(args[3]))
		local myRoot = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
		if npc and myRoot then
			state.RoamPoints[npc] = state.RoamPoints[npc] or {}
			table.insert(state.RoamPoints[npc], myRoot.Position)
			state.CurrentRoamIndex[npc] = 1
			notify("Roam", "Waypoint added for NPC " .. args[3])
		end

	elseif cmd == "stop" and args[2] == "roam" and args[3] then
		local npc = getNPCById(tonumber(args[3]))
		if npc then
			state.RoamPoints[npc] = nil
			notify("Roam", "Stopped roaming NPC " .. args[3])
		end

	elseif cmd == "pathfind" and args[2] then
		local target = getPlayer(table.concat(args, " ", 2))
		if target then
			state.PathfindTarget = target
			notify("Pathfind", "Pathfinding to " .. target.Name)
		end

	-- ── Fling ──
	elseif cmd == "fling" and args[2] then
		local target = getPlayer(table.concat(args, " ", 2))
		if target and target.Character then
			state.CurrentTarget = target; state.Mode = "Fling"
			state.Follow = false; state.CommandIssuer = player
		end

	elseif cmd == "nanfling" and args[2] then
		local target = getPlayer(table.concat(args, " ", 2))
		if target and target.Character then
			local tRoot = target.Character:FindFirstChild("HumanoidRootPart")
			if tRoot then
				for _, npc in ipairs(getNPCs()) do
					local hrp = npc:FindFirstChild("HumanoidRootPart")
					if hrp then
						teleportNPC(npc, tRoot.CFrame)
					end
				end
			end
		end

	-- ── Freeze / unfreeze global ──
	elseif cmd == "!freeze" then
		state.GlobalFreeze = true; notify("Freeze", "All NPCs frozen")

	elseif cmd == "!unfreeze" then
		state.GlobalFreeze = false; notify("Freeze", "All NPCs unfrozen")

	elseif cmd == "!attack" and args[2] then
		local target = getPlayer(table.concat(args, " ", 2))
		if target then
			state.GlobalAttackTarget = target
			notify("Global Attack", "All NPCs attacking " .. target.Name)
		end

	elseif cmd == "!stop" and args[2] == "game" then
		state.Mode = nil
		notify("Game", "Minigame stopped")

	-- ── JJK moves ──
	elseif cmd == "lapse" and args[2] == "blue" then
		for _, n in ipairs(getNPCs()) do
			if n ~= state.RedNPC and n ~= state.BlueNPC and not state.StayingNPCs[n] then
				state.BlueNPC = n; state.PurplePhase = 0
				notify("JJK", "Lapse Blue initiated"); break
			end
		end

	elseif cmd == "reversal" and args[2] == "red" then
		for _, n in ipairs(getNPCs()) do
			if n ~= state.RedNPC and n ~= state.BlueNPC and not state.StayingNPCs[n] then
				state.RedNPC = n; state.PurplePhase = 0
				notify("JJK", "Reversal Red initiated"); break
			end
		end

	elseif cmd == "hollow" and args[2] == "purple" then
		if state.BlueNPC and state.RedNPC then
			state.PurplePhase = 1; state.PurpleTick = tick()
			notify("JJK", "Hollow Purple combining!")
		else
			notify("JJK", "Need both Blue and Red first!")
		end

	-- ── Games ──
	elseif cmd == "murder" and args[2] == "mystery" then
		state.Mode = "MurderMystery"
		state.MMKiller = nil; state.MMChasing = nil; state.MMFleeing = {}
		local parts = {}
		for _, n in ipairs(getNPCs()) do table.insert(parts, n) end
		if #parts > 0 then
			state.MMKiller = parts[math.random(1, #parts)]
			notify("Murder Mystery", "Game started! Killer chosen.")
		end

	elseif cmd == "!among" and args[2] == "us" then
		state.Mode = "AmongUs"; state.AUPhase = "Playing"
		state.AURoles = {}; state.AULastKill = tick()
		local parts = {}
		for _, n in ipairs(getNPCs()) do table.insert(parts, n) end
		if #parts > 0 then
			local numImps = math.max(1, math.floor(#parts / 4))
			local shuffled = {table.unpack(parts)}
			for i = #shuffled, 2, -1 do
				local j = math.random(i)
				shuffled[i], shuffled[j] = shuffled[j], shuffled[i]
			end
			for i = 1, numImps do
				state.AURoles[shuffled[i]] = i == 1 and "Shapeshifter" or "Imposter"
			end
			for i = numImps + 1, #shuffled do
				state.AURoles[shuffled[i]] = "Crewmate"
			end
			notify("Among Us", "Game started! " .. numImps .. " impostor(s)")
		end

	elseif cmd == "!build" then
		notify("Build", "Build mode toggled")
		-- (Extend with your game's build tool logic)
	end
end

for _, p in ipairs(Players:GetPlayers()) do
	p.Chatted:Connect(function(msg) handleCommand(p, msg) end)
end
Players.PlayerAdded:Connect(function(p)
	p.Chatted:Connect(function(msg) handleCommand(p, msg) end)
end)
-- Clean up whitelist when a player leaves so no ghost entries accumulate
Players.PlayerRemoving:Connect(function(p)
	if state.Whitelist[p] then
		state.Whitelist[p] = nil
		notify("Whitelist", p.Name .. " left — removed from whitelist")
	end
end)

-- ─────────────────────────────────────────
--  MAIN HEARTBEAT LOOP
-- ─────────────────────────────────────────
local nextRandomMove  = tick()
local lastUIRefresh   = tick()
local lastFrenzyTick  = tick()

RunService.Heartbeat:Connect(function()
	pcall(function()
		-- Self-defense: cancel any huge velocity applied to player
		if LocalPlayer and LocalPlayer.Character then
			local myRoot = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
			if myRoot and state.SelfDefense then
				if myRoot.AssemblyLinearVelocity.Magnitude > 250 then
					myRoot.AssemblyLinearVelocity = Vector3.zero
					myRoot.AssemblyAngularVelocity = Vector3.zero
				end
			end
		end

		local npcs      = getNPCs()
		local ownedNpcs = {}

		-- Ownership enforcement pass
		for _, npc in ipairs(npcs) do
			local hrp = npc:FindFirstChild("HumanoidRootPart")
			local hum = npc:FindFirstChild("Humanoid")
			if not hrp then continue end

			-- Lightweight per-frame pass: just keep HRP unanchored
			-- and physics ticking. Heavy ownership work is handled
			-- by the throttled loops, not here.
			hrp.Anchored = false
			pcall(function()
				local vel = hrp.AssemblyLinearVelocity
				if vel.Magnitude < 0.01 then
					hrp.AssemblyLinearVelocity = vel + Vector3.new(0, 0.001, 0)
				end
			end)

			local owned = isConnected(npc)
			if owned then
				table.insert(ownedNpcs, npc)
				if npcOwnershipState[npc] ~= true then
					if hum then
						hum:ChangeState(Enum.HumanoidStateType.Running)
						hum.PlatformStand = false
						hum.Sit           = false
						hum.AutoRotate    = true
					end
					npcOwnershipState[npc] = true
				end
			else
				npcOwnershipState[npc] = false
			end

			if hum and state.Mode ~= "Sit" then
				hum.Sit = false
				hum.PlatformStand = false
			end
		end

		-- Gossip mode
		if state.Gossip then
			local myRoot = LocalPlayer and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
			if myRoot then
				if not state.nextGossipTick then state.nextGossipTick = tick() end
				if tick() > state.nextGossipTick then
					state.nextGossipTick = tick() + math.random(3, 6)
					for _, npc in ipairs(ownedNpcs) do
						if not state.StayingNPCs[npc] then
							local hrp = npc:FindFirstChild("HumanoidRootPart")
							local hum = npc:FindFirstChild("Humanoid")
							if hrp and hum then
								if math.random() > 0.5 then
									hum:MoveTo(myRoot.Position + Vector3.new(math.random(-20,20), 0, math.random(-20,20)))
								else
									local animType = math.random(1, 5)
									if animType == 1 then hrp.CFrame = hrp.CFrame * CFrame.Angles(0, math.pi/4, 0)
									elseif animType == 2 then hum.Jump = true
									elseif animType == 3 then pcall(function() hrp.RotVelocity = Vector3.new(0,10,0) end)
									end
								end
							end
						end
					end
				end
			end
		end

		-- Frenzy mode
		if state.FrenzyMode and tick() - lastFrenzyTick > 0.4 then
			lastFrenzyTick = tick()
			for _, npc in ipairs(ownedNpcs) do
				local hum = npc:FindFirstChild("Humanoid")
				local hrp = npc:FindFirstChild("HumanoidRootPart")
				if hum and hrp then
					local rDir = Vector3.new(math.random(-100,100)/100, 0, math.random(-100,100)/100).Unit
					hum:MoveTo(hrp.Position + rDir * math.random(10, 30))
					if math.random() > 0.6 then hum.Jump = true end
				end
			end
		end

		-- ESP
		if state.ESP then
			for _, npc in ipairs(npcs) do
				local cache  = npcCache[npc]
				if not cache then continue end
				local isConn = isConnected(npc)
				local hl     = npc:FindFirstChild("NPC_ESP_HL")
				if not hl then
					hl = Instance.new("Highlight", npc)
					hl.Name             = "NPC_ESP_HL"
					hl.FillTransparency = 0.5
					hl.OutlineTransparency = 0
				end
				hl.FillColor    = isConn and Color3.fromRGB(0,255,0)   or Color3.fromRGB(255,255,255)
				hl.OutlineColor = isConn and Color3.fromRGB(0,255,0)   or Color3.fromRGB(255,255,255)
				local anchor = npc:FindFirstChild("HumanoidRootPart") or npc:FindFirstChild("Head")
				if anchor then
					local bb = npc:FindFirstChild("NPC_ESP_BB")
					if not bb then
						bb = Instance.new("BillboardGui", npc)
						bb.Name = "NPC_ESP_BB"; bb.Size = UDim2.new(0,100,0,50)
						bb.StudsOffset = Vector3.new(0,3,0); bb.AlwaysOnTop = true
						local txt = Instance.new("TextLabel", bb)
						txt.Size = UDim2.new(1,0,1,0); txt.BackgroundTransparency = 1
						txt.TextColor3 = Color3.fromRGB(255,255,255)
						txt.TextStrokeTransparency = 0
						txt.Font = Enum.Font.SourceSansBold; txt.TextSize = 20
					end
					local txt = bb:FindFirstChildOfClass("TextLabel")
					if txt then
						txt.Text       = "[" .. cache.id .. "] " .. cache.type
						txt.TextColor3 = isConn and Color3.fromRGB(0,255,0) or Color3.fromRGB(255,255,255)
					end
				end
			end
		end

		-- NPC list UI refresh
		if tick() - lastUIRefresh > 1 and NPCListFrame.Visible then
			lastUIRefresh = tick()
			for _, v in ipairs(NPCScroll:GetChildren()) do if v:IsA("Frame") then v:Destroy() end end
			for _, npc in ipairs(npcs) do
				local cache  = npcCache[npc]; if not cache then continue end
				local isConn = isConnected(npc)
				local row = Instance.new("Frame", NPCScroll)
				row.Size = UDim2.new(1, 0, 0, 30); row.BackgroundColor3 = Color3.fromRGB(50,50,50)
				local lbl = Instance.new("TextLabel", row)
				lbl.Size = UDim2.new(0.7,-5,1,0); lbl.Position = UDim2.new(0,5,0,0)
				lbl.BackgroundTransparency = 1; lbl.TextColor3 = Color3.fromRGB(255,255,255)
				lbl.Text = "["..cache.id.."] "..cache.type
				lbl.TextXAlignment = Enum.TextXAlignment.Left
				lbl.Font = Enum.Font.SourceSans; lbl.TextSize = 14
				local btn = Instance.new("TextButton", row)
				btn.Size = UDim2.new(0.3,-5,0,24); btn.Position = UDim2.new(0.7,0,0.5,-12)
				btn.BackgroundColor3 = isConn and Color3.fromRGB(0,150,0) or Color3.fromRGB(150,0,0)
				btn.TextColor3 = Color3.fromRGB(255,255,255)
				btn.Text = isConn and "OK" or "Connect"
				btn.Font = Enum.Font.SourceSans; btn.TextSize = 12
				btn.MouseButton1Click:Connect(function()
					btn.Text = "Wait.."
					task.spawn(function()
						CloneRecovery.Recover(npc)
						btn.Text = isConnected(npc) and "OK" or "Failed"
					end)
				end)
			end
		end

		-- Possess
		if state.PossessedNPC and state.PossessedNPC.Parent and state.PossessedNPC:FindFirstChild("Humanoid") then
			local myChar = LocalPlayer.Character
			local myHum  = myChar and myChar:FindFirstChild("Humanoid")
			if myHum and workspace.CurrentCamera then
				myHum.WalkSpeed = 0; myHum.JumpPower = 0
				workspace.CurrentCamera.CameraSubject = state.PossessedNPC.Humanoid
				state.PossessedNPC.Humanoid:Move(myHum.MoveDirection, false)
				state.PossessedNPC.Humanoid.Jump = myHum.Jump
			end
		else
			if not state.PossessedNPC and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
				local myHum = LocalPlayer.Character.Humanoid
				if myHum.WalkSpeed == 0 then myHum.WalkSpeed = 16; myHum.JumpPower = 50 end
			end
		end

		-- JJK Blue / Red / Purple
		local t = tick()
		if state.BlueNPC and state.BlueNPC.Parent then
			local hrp    = state.BlueNPC:FindFirstChild("HumanoidRootPart")
			local myRoot = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
			if hrp and myRoot and state.PurplePhase == 0 then
				pcall(function() state.BlueNPC.Humanoid.PlatformStand = true end)
				local tp = myRoot.CFrame * CFrame.new(-5, 3, -4)
				hrp.CFrame = hrp.CFrame:Lerp(tp * CFrame.Angles(0, t*5, 0), 0.1)
				hrp.AssemblyLinearVelocity = Vector3.zero
			end
		end
		if state.RedNPC and state.RedNPC.Parent then
			local hrp    = state.RedNPC:FindFirstChild("HumanoidRootPart")
			local myRoot = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
			if hrp and myRoot and state.PurplePhase == 0 then
				pcall(function() state.RedNPC.Humanoid.PlatformStand = true end)
				local tp = myRoot.CFrame * CFrame.new(5, 3, -4)
				hrp.CFrame = hrp.CFrame:Lerp(tp * CFrame.Angles(0, t*200, 0), 0.1)
				hrp.AssemblyLinearVelocity = Vector3.zero
			end
		end
		if state.PurplePhase == 1 and state.BlueNPC and state.RedNPC then
			local bRoot = state.BlueNPC:FindFirstChild("HumanoidRootPart")
			local rRoot = state.RedNPC:FindFirstChild("HumanoidRootPart")
			local myRoot= LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
			if bRoot and rRoot and myRoot then
				local tp = myRoot.CFrame * CFrame.new(0, 4, -6)
				bRoot.CFrame = bRoot.CFrame:Lerp(tp * CFrame.Angles(0, t*500, 0), 0.05)
				rRoot.CFrame = rRoot.CFrame:Lerp(tp * CFrame.Angles(0, t*500, 0), 0.05)
				if tick() - state.PurpleTick > 3 then
					state.PurplePhase = 2
					state.PurpleStartCFrame = myRoot.CFrame
					state.PurpleTick = tick()
				end
			end
		elseif state.PurplePhase == 2 and state.BlueNPC and state.RedNPC then
			local bRoot = state.BlueNPC:FindFirstChild("HumanoidRootPart")
			local rRoot = state.RedNPC:FindFirstChild("HumanoidRootPart")
			if bRoot and rRoot and state.PurpleStartCFrame then
				local elapsed = (tick() - state.PurpleTick) * 200
				local tp = state.PurpleStartCFrame * CFrame.new(0, 4, -6 - elapsed)
				bRoot.CFrame = tp * CFrame.Angles(0, t*500, 0)
				rRoot.CFrame = tp * CFrame.Angles(0, t*500, 0)
				if elapsed > 400 then
					state.PurplePhase = 0; state.BlueNPC = nil; state.RedNPC = nil
				end
			end
		end

		-- Global freeze / attack
		if state.GlobalFreeze or state.GlobalAttackTarget then
			local gRoot = state.GlobalAttackTarget and state.GlobalAttackTarget.Character and state.GlobalAttackTarget.Character:FindFirstChild("HumanoidRootPart")
			for _, npc in ipairs(npcs) do
				local hrp = npc:FindFirstChild("HumanoidRootPart")
				local hum = npc:FindFirstChild("Humanoid")
				if hrp and hum and hum.Health > 0 then
					if state.GlobalFreeze then
						pcall(function() hrp.AssemblyLinearVelocity = Vector3.zero; hrp.AssemblyAngularVelocity = Vector3.zero end)
					elseif gRoot then
						hum:MoveTo(gRoot.Position)
					end
				end
			end
		end

		-- Per-NPC overrides (specific follow, roam)
		state.IsOverridden = {}
		for _, npc in ipairs(ownedNpcs) do
			local overridden = false
			local sTarget = state.SpecificFollow[npc]
			if sTarget and sTarget.Character then
				local tRoot = sTarget.Character:FindFirstChild("HumanoidRootPart")
				local hum   = npc:FindFirstChild("Humanoid")
				if tRoot and hum then
					if (npc.HumanoidRootPart.Position - tRoot.Position).Magnitude > 3 then
						hum:MoveTo(tRoot.Position)
					end
					overridden = true
				end
			end
			local rPoints = state.RoamPoints[npc]
			if not overridden and rPoints and #rPoints > 0 then
				local hrp = npc:FindFirstChild("HumanoidRootPart")
				local hum = npc:FindFirstChild("Humanoid")
				if hrp and hum then
					local idx  = state.CurrentRoamIndex[npc] or 1
					local tPos = rPoints[idx]
					if (hrp.Position - tPos).Magnitude < 3 then
						state.CurrentRoamIndex[npc] = (idx % #rPoints) + 1
					else
						hum:MoveTo(tPos)
					end
					overridden = true
				end
			end
			state.IsOverridden[npc] = overridden or npc == state.BlueNPC or npc == state.RedNPC
		end

		-- Mode locomotion
		local issuerChar = state.CommandIssuer and state.CommandIssuer.Character
		local issuerRoot = issuerChar and issuerChar:FindFirstChild("HumanoidRootPart")

		-- HELPER: create/get AlignPosition on an NPC
		local function getAlignPos(hrp)
			local att = hrp:FindFirstChild("MechaAtt") or Instance.new("Attachment", hrp)
			att.Name = "MechaAtt"
			local ap = hrp:FindFirstChild("MechaAlign")
			if not ap then
				ap = Instance.new("AlignPosition", hrp)
				ap.Name = "MechaAlign"
				ap.Mode = Enum.PositionAlignmentMode.OneAttachment
				ap.Attachment0 = att
				ap.MaxForce    = 1000000
				ap.Responsiveness = 200
			end
			local ao = hrp:FindFirstChild("MechaOri")
			if not ao then
				ao = Instance.new("AlignOrientation", hrp)
				ao.Name = "MechaOri"
				ao.Mode = Enum.OrientationAlignmentMode.OneAttachment
				ao.Attachment0 = att
				ao.MaxTorque   = 1000000
				ao.Responsiveness = 200
			end
			return ap, hrp:FindFirstChild("MechaOri")
		end

		if state.Follow and issuerRoot then
			for _, npc in ipairs(ownedNpcs) do
				if state.StayingNPCs[npc] or state.IsOverridden[npc] then continue end
				local hum   = npc:FindFirstChild("Humanoid")
				local cache = npcCache[npc]
				if hum and hum.Health > 0 then
					if cache and cache.waypoints and cache.currentWaypoint and cache.currentWaypoint <= #cache.waypoints then
						local wp  = cache.waypoints[cache.currentWaypoint]
						local hrp = npc:FindFirstChild("HumanoidRootPart")
						if hrp then
							hum:MoveTo(wp.Position)
							-- Jump obstacle detection
							local lookDir = hrp.CFrame.LookVector
							local ray = Ray.new(hrp.Position, lookDir * 4)
							local hit, pos = workspace:FindPartOnRay(ray, npc)
							if hit and hit.CanCollide then
								local jRay = Ray.new(pos + Vector3.new(0,7,0), Vector3.new(0,-7,0))
								local tHit, tPos = workspace:FindPartOnRay(jRay, npc)
								if tHit and math.abs(pos.Y - tPos.Y) < 6 then hum.Jump = true end
							end
							if (hrp.Position - wp.Position).Magnitude < 3 then cache.currentWaypoint = cache.currentWaypoint + 1 end
							if wp.Action == Enum.PathWaypointAction.Jump then hum.Jump = true end
						end
					else
						hum:MoveTo(issuerRoot.Position)
					end
				end
			end

		elseif state.Mode == "Conga" and issuerRoot then
			-- Conga: each NPC follows the one ahead, first follows player
			local leader = issuerRoot.Position
			for _, npc in ipairs(ownedNpcs) do
				if state.StayingNPCs[npc] or state.IsOverridden[npc] then continue end
				local hum = npc:FindFirstChild("Humanoid")
				local hrp = npc:FindFirstChild("HumanoidRootPart")
				if hum and hrp then
					hum:MoveTo(leader)
					leader = hrp.Position
				end
			end

		elseif state.Mode == "Shield" and issuerRoot then
			for i, npc in ipairs(ownedNpcs) do
				if state.IsOverridden[npc] then continue end
				local hrp = npc:FindFirstChild("HumanoidRootPart")
				local hum = npc:FindFirstChild("Humanoid")
				if hrp and hum then
					hum.PlatformStand = true
					local angle = (i / #ownedNpcs) * math.pi * 2
					local tp    = issuerRoot.CFrame * CFrame.new(math.cos(angle)*5, 0, math.sin(angle)*5)
					local ap, ao = getAlignPos(hrp)
					ap.Position = tp.Position
					if ao then ao.CFrame = CFrame.new(hrp.Position, issuerRoot.Position) end
					hrp.AssemblyLinearVelocity = Vector3.zero
				end
			end

		elseif state.Mode == "Mecha" and issuerRoot then
			local roles = {
				CFrame.new(-2,-1,0), CFrame.new(2,-1,0),
				CFrame.new(-1,-3,0), CFrame.new(1,-3,0), CFrame.new(0,-1,0.5),
			}
			for i, npc in ipairs(ownedNpcs) do
				if i > 5 then break end
				local hrp = npc:FindFirstChild("HumanoidRootPart")
				local hum = npc:FindFirstChild("Humanoid")
				if hrp and hum then
					hum.PlatformStand = true
					local ap, ao = getAlignPos(hrp)
					local tp = issuerRoot.CFrame * roles[i]
					ap.Position = tp.Position
					if ao then ao.CFrame = tp end
					hrp.AssemblyLinearVelocity = Vector3.zero; hrp.AssemblyAngularVelocity = Vector3.zero
				end
			end

		elseif state.Mode == "UFO" and issuerRoot then
			for i, npc in ipairs(ownedNpcs) do
				if state.StayingNPCs[npc] or state.IsOverridden[npc] then continue end
				local hrp = npc:FindFirstChild("HumanoidRootPart")
				local hum = npc:FindFirstChild("Humanoid")
				if hrp and hum then
					hum.PlatformStand = true
					local angle  = (t * 2 * (state.OrbitSpeed or 1)) + (i * (math.pi*2 / #ownedNpcs))
					local yOff   = math.sin(t * 3) * 5 + 10
					local tp     = issuerRoot.Position + Vector3.new(math.cos(angle)*10, yOff, math.sin(angle)*10)
					local ap, ao = getAlignPos(hrp)
					ap.Position  = tp
					if ao then ao.CFrame = CFrame.new(hrp.Position, issuerRoot.Position) end
					hrp.AssemblyLinearVelocity = Vector3.zero
				end
			end

		elseif state.Mode == "Orbit" and issuerRoot then
			for i, npc in ipairs(ownedNpcs) do
				if state.StayingNPCs[npc] or state.IsOverridden[npc] then continue end
				local hrp = npc:FindFirstChild("HumanoidRootPart")
				local hum = npc:FindFirstChild("Humanoid")
				if hrp and hum then
					hum.PlatformStand = true
					local angle = (t * (state.OrbitSpeed or 1)) + (i * math.pi * 2 / #ownedNpcs)
					local tp    = issuerRoot.Position + Vector3.new(math.cos(angle)*8, 0, math.sin(angle)*8)
					local ap, ao = getAlignPos(hrp)
					ap.Position = tp
					if ao then ao.CFrame = CFrame.new(hrp.Position, issuerRoot.Position) end
					hrp.AssemblyLinearVelocity = Vector3.zero
				end
			end

		elseif state.Mode == "Sphere" and issuerRoot then
			local n = #ownedNpcs
			for i, npc in ipairs(ownedNpcs) do
				if state.IsOverridden[npc] then continue end
				local hrp = npc:FindFirstChild("HumanoidRootPart")
				local hum = npc:FindFirstChild("Humanoid")
				if hrp and hum then
					hum.PlatformStand = true
					local phi   = math.acos(1 - 2*(i/n))
					local theta = math.pi * (1 + 5^0.5) * i + t * (state.OrbitSpeed or 1)
					local r     = 10
					local tp    = issuerRoot.Position + Vector3.new(r*math.sin(phi)*math.cos(theta), r*math.cos(phi), r*math.sin(phi)*math.sin(theta))
					local ap, ao = getAlignPos(hrp)
					ap.Position = tp
					if ao then ao.CFrame = CFrame.new(hrp.Position, issuerRoot.Position) end
					hrp.AssemblyLinearVelocity = Vector3.zero
				end
			end

		elseif state.Mode == "Helicopter" and issuerRoot then
			for i, npc in ipairs(ownedNpcs) do
				if state.IsOverridden[npc] then continue end
				local hrp = npc:FindFirstChild("HumanoidRootPart")
				local hum = npc:FindFirstChild("Humanoid")
				if hrp and hum then
					hum.PlatformStand = true
					local angle = (t * 3 * (state.OrbitSpeed or 1)) + (i * math.pi * 2 / #ownedNpcs)
					local tp    = issuerRoot.Position + Vector3.new(math.cos(angle)*8, 5, math.sin(angle)*8)
					local ap, ao = getAlignPos(hrp)
					ap.Position = tp
					if ao then ao.CFrame = CFrame.new(hrp.Position, issuerRoot.Position) end
					hrp.AssemblyLinearVelocity = Vector3.zero
				end
			end

		elseif state.Mode == "WallOrbit" and issuerRoot then
			for i, npc in ipairs(ownedNpcs) do
				if state.IsOverridden[npc] then continue end
				local hrp = npc:FindFirstChild("HumanoidRootPart")
				local hum = npc:FindFirstChild("Humanoid")
				if hrp and hum then
					hum.PlatformStand = true
					local angle  = (t * (state.OrbitSpeed or 1)) + (i * math.pi * 2 / #ownedNpcs)
					local radius = 10
					local tp     = issuerRoot.Position + Vector3.new(math.cos(angle)*radius, (i-1)*2-#ownedNpcs, math.sin(angle)*radius)
					local ap, ao = getAlignPos(hrp)
					ap.Position = tp
					if ao then ao.CFrame = CFrame.new(hrp.Position, issuerRoot.Position) end
					hrp.AssemblyLinearVelocity = Vector3.zero
				end
			end

		elseif state.Mode == "Star" and issuerRoot then
			local starPoints = 5
			for i, npc in ipairs(ownedNpcs) do
				if state.IsOverridden[npc] then continue end
				local hrp = npc:FindFirstChild("HumanoidRootPart")
				local hum = npc:FindFirstChild("Humanoid")
				if hrp and hum then
					hum.PlatformStand = true
					local ptIdx  = ((i - 1) % starPoints)
					local angle  = ptIdx * (2 * math.pi / starPoints) - math.pi / 2 + t * (state.OrbitSpeed or 1)
					local r      = ((i - 1) // starPoints % 2 == 0) and 10 or 5
					local tp     = issuerRoot.Position + Vector3.new(math.cos(angle)*r, 0, math.sin(angle)*r)
					local ap, ao = getAlignPos(hrp)
					ap.Position = tp
					if ao then ao.CFrame = CFrame.new(hrp.Position, issuerRoot.Position) end
					hrp.AssemblyLinearVelocity = Vector3.zero
				end
			end

		elseif state.Mode == "Attack" and state.CurrentTarget and state.CurrentTarget.Character then
			local tRoot = state.CurrentTarget.Character:FindFirstChild("HumanoidRootPart")
			for _, npc in ipairs(ownedNpcs) do
				if state.StayingNPCs[npc] or state.IsOverridden[npc] then continue end
				local hum = npc:FindFirstChild("Humanoid")
				if hum and tRoot then hum:MoveTo(tRoot.Position) end
			end

		elseif state.Mode == "LookAt" and state.CurrentTargetName then
			local target = getPlayer(state.CurrentTargetName)
			if target and target.Character then
				local tRoot = target.Character:FindFirstChild("HumanoidRootPart")
				if tRoot then
					for _, npc in ipairs(ownedNpcs) do
						local hrp = npc:FindFirstChild("HumanoidRootPart")
						if hrp then
							local lookCF = CFrame.lookAt(hrp.Position, Vector3.new(tRoot.Position.X, hrp.Position.Y, tRoot.Position.Z))
							hrp.CFrame = hrp.CFrame:Lerp(lookCF, 0.2)
						end
					end
				end
			end

		elseif state.Mode == "KillNPC" and state.KillTargetNPC then
			local tHRP = state.KillTargetNPC:FindFirstChild("HumanoidRootPart")
			if tHRP then
				for _, npc in ipairs(ownedNpcs) do
					if state.IsOverridden[npc] then continue end
					local hum = npc:FindFirstChild("Humanoid")
					if hum then hum:MoveTo(tHRP.Position) end
				end
			else
				state.Mode = nil; state.KillTargetNPC = nil
			end

		elseif state.Mode == "Makeway" and issuerRoot then
			for _, npc in ipairs(ownedNpcs) do
				local hum = npc:FindFirstChild("Humanoid")
				local hrp = npc:FindFirstChild("HumanoidRootPart")
				if hum and hrp then
					local dir = (hrp.Position - issuerRoot.Position).Unit
					hum:MoveTo(hrp.Position + dir * 30)
				end
			end

		elseif state.Mode == "Arise" then
			if tick() > nextRandomMove then
				nextRandomMove = tick() + math.random(2, 5)
				for _, npc in ipairs(ownedNpcs) do
					local hum = npc:FindFirstChild("Humanoid")
					local hrp = npc:FindFirstChild("HumanoidRootPart")
					if hum and hrp then
						hum:MoveTo(hrp.Position + Vector3.new(math.random(-40,40), 0, math.random(-40,40)))
					end
				end
			end

		elseif state.Mode == "StackUp" and state.StackUpPos then
			for i, npc in ipairs(ownedNpcs) do
				local hrp = npc:FindFirstChild("HumanoidRootPart")
				local hum = npc:FindFirstChild("Humanoid")
				if hrp and hum then
					hum.PlatformStand = true
					local tp = CFrame.new(state.StackUpPos + Vector3.new(0, (i-1)*5, 0))
					hrp.CFrame = hrp.CFrame:Lerp(tp, 0.1)
					hrp.AssemblyLinearVelocity = Vector3.zero
				end
			end

		elseif state.Mode == "Assemble" and issuerRoot then
			for i, npc in ipairs(ownedNpcs) do
				local hum = npc:FindFirstChild("Humanoid")
				if hum then
					local offset = Vector3.new((i-1) * 3, 0, -4)
					hum:MoveTo(issuerRoot.Position - issuerRoot.CFrame.LookVector * 4 + issuerRoot.CFrame.RightVector * ((i-1)*3 - #ownedNpcs*1.5))
				end
			end

		elseif state.Mode == "Dance" then
			if tick() > nextRandomMove then
				nextRandomMove = tick() + 0.5
				for _, npc in ipairs(ownedNpcs) do
					local hrp = npc:FindFirstChild("HumanoidRootPart")
					if hrp then
						hrp.CFrame = hrp.CFrame * CFrame.Angles(0, math.rad(math.random(-30,30)), 0)
					end
				end
			end

		elseif state.Mode == "STS" and issuerRoot then
			for i, npc in ipairs(ownedNpcs) do
				local hum = npc:FindFirstChild("Humanoid")
				if hum then
					local offset = (i - math.ceil(#ownedNpcs/2)) * 3
					hum:MoveTo(issuerRoot.Position + issuerRoot.CFrame.RightVector * offset + issuerRoot.CFrame.LookVector * 3)
				end
			end

		elseif state.Mode == "Wall" and state.WallPos and state.WallDir then
			for i, npc in ipairs(ownedNpcs) do
				if i > 5 then break end
				local hum = npc:FindFirstChild("Humanoid")
				if hum then
					local pos = state.WallPos + state.WallDir * ((i-3)*3)
					hum:MoveTo(pos)
				end
			end

		elseif state.Mode == "Stairs" and issuerRoot then
			for i, npc in ipairs(ownedNpcs) do
				local hrp = npc:FindFirstChild("HumanoidRootPart")
				local hum = npc:FindFirstChild("Humanoid")
				if hrp and hum then
					hum.PlatformStand = true
					local tp = issuerRoot.CFrame * CFrame.new(0, (i-1)*3, -(i-1)*3)
					local ap, ao = getAlignPos(hrp)
					ap.Position = tp.Position
					if ao then ao.CFrame = tp end
					hrp.AssemblyLinearVelocity = Vector3.zero
				end
			end

		elseif state.Mode == "Train" then
			local leader = issuerRoot
			if leader then
				for _, npc in ipairs(ownedNpcs) do
					if state.IsOverridden[npc] then continue end
					local hum = npc:FindFirstChild("Humanoid")
					local hrp = npc:FindFirstChild("HumanoidRootPart")
					if hum and hrp then
						hum:MoveTo(leader.Position)
						leader = hrp
					end
				end
			end
		end

		-- Stay enforcement
		for _, npc in ipairs(ownedNpcs) do
			if state.StayingNPCs[npc] then
				local hum = npc:FindFirstChild("Humanoid")
				local hrp = npc:FindFirstChild("HumanoidRootPart")
				if hum and hrp then hum:MoveTo(hrp.Position) end
			end
		end
	end)
end)

notify("NPC Controller v2", "Loaded! Chat commands: toggle 'Chat Cmds' first.")
