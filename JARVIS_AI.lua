-- ============================================================
--   J.A.R.V.I.S v10.6 | Groq Build
--   Scanner + rSpy + Dex Explorer | Delta / Mobile
-- ============================================================
-- ------------------------------------------------------------
-- CONFIG - put your Gemini API key here
-- ------------------------------------------------------------
-- Load Groq API keys from Delta workspace file: jarvis.env
-- Put one key per line, up to 50 keys. Lines starting with # are ignored.
-- Example jarvis.env:
--   gsk_abc123...
--   gsk_def456...
local KeyPool      = {}
local KeyIndex     = 1
local KeyFails     = {}
local KEY_MAX_FAIL = 3

pcall(function()
    local raw = readfile("jarvis.env")
    for line in raw:gmatch("[^\r\n]+") do
        line = line:match("^%s*(.-)%s*$")
        if line ~= "" and not line:match("^#") then
            table.insert(KeyPool, line)
            KeyFails[#KeyPool] = 0
        end
    end
end)

if #KeyPool == 0 then
    warn("[JARVIS] No API keys found. Add Groq keys (one per line) to jarvis.env in Delta workspace.")
else
    print("[JARVIS] Loaded " .. #KeyPool .. " Groq key(s).")
end

local function getKey()
    if #KeyPool == 0 then return "" end
    for _ = 1, #KeyPool do
        if (KeyFails[KeyIndex] or 0) < KEY_MAX_FAIL then
            return KeyPool[KeyIndex]
        end
        KeyIndex = (KeyIndex % #KeyPool) + 1
    end
    -- All keys hit max fails, reset
    print("[JARVIS] All keys exhausted, resetting fail counts.")
    for i = 1, #KeyPool do KeyFails[i] = 0 end
    KeyIndex = 1
    return KeyPool[1]
end

local function rotateKey(failed)
    if failed and #KeyPool > 0 then
        KeyFails[KeyIndex] = (KeyFails[KeyIndex] or 0) + 1
        print("[JARVIS] Key " .. KeyIndex .. " failed (" .. KeyFails[KeyIndex] .. "/" .. KEY_MAX_FAIL .. ")")
    end
    if #KeyPool > 1 then
        KeyIndex = (KeyIndex % #KeyPool) + 1
    end
end
-- ------------------------------------------------------------

-- Gemini model to use (free tier)
local MDL_CHAT  = "openai/gpt-oss-120b"
local MDL_CODE  = "openai/gpt-oss-120b"
local FLY_SPEED = 50
local HIST_MAX  = 6

-- Services
local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenSvc   = game:GetService("TweenService")
local HttpSvc    = game:GetService("HttpService")
local Lighting   = game:GetService("Lighting")
local CoreGui    = game:GetService("CoreGui")
local UIS        = game:GetService("UserInputService")
local TeleportSvc = game:GetService("TeleportService")
local LP         = Players.LocalPlayer

-- Character helpers
local function getChar() return LP.Character end
local function getHRP()  local c=getChar(); return c and c:FindFirstChild("HumanoidRootPart") end
local function getHum()  local c=getChar(); return c and c:FindFirstChildWhichIsA("Humanoid") end

-- State
local State = {
    flying=false, godMode=false, noclip=false, invisible=false,
    guiOpen=false, minimized=false, busy=false, flyUp=false, flyDown=false,
}
-- Conns: persistent feature connections (fly, god, noclip)
-- ScriptConns: user-toggled script connections (esp, killaura, etc.)
local Conns      = {}
local ScriptConns= {}
local ChatCooldowns  = {}  -- per-player chat cooldown
local CHAT_COOLDOWN  = 8
local ChatConvHist   = {}
local ChatEnabled    = true
local ChatHist   = {}
local MsgCount   = 0
local RSpyLog    = {}

-- Persistent memory (saved to Delta workspace as jarvis_memory.json)
local Memory = {}
local MEMORY_FILE = "jarvis_memory.json"
local function loadMemory()
    pcall(function()
        if isfile(MEMORY_FILE) then
            local raw = readfile(MEMORY_FILE)
            local ok, data = pcall(game:GetService("HttpService").JSONDecode, game:GetService("HttpService"), raw)
            if ok and type(data) == "table" then Memory = data end
        end
    end)
end
local function saveMemory()
    pcall(function()
        local ok, encoded = pcall(game:GetService("HttpService").JSONEncode, game:GetService("HttpService"), Memory)
        if ok then writefile(MEMORY_FILE, encoded) end
    end)
end
local function rememberFact(key, value)
    Memory[key] = value
    saveMemory()
end
local function forgetFact(key)
    Memory[key] = nil
    saveMemory()
end
local function getMemoryContext()
    local lines = {}
    for k, v in pairs(Memory) do
        table.insert(lines, k .. ": " .. tostring(v))
    end
    if #lines == 0 then return "" end
    return "\n=== MEMORY ===\n" .. table.concat(lines, "\n")
end
loadMemory()
local RSpyActive = false
local ScanCache  = { data=nil, time=-999 }

-- GUI panels (assigned after GUI builds)
local SG, CW, CS, FlyPanel, DexPanel, SpyPanel
local DexOpen  = false
local SpyOpen  = false

-- --- HTTP  (detect working request fn ONCE - no spam on every call) ---
local reqFn = nil
local function detectReq()
    local candidates = {
        function(o) return request(o) end,
        function(o) return syn and syn.request(o) end,
        function(o) return http and http.request(o) end,
        function(o) return http_request(o) end,
        function(o) return HttpSvc:RequestAsync(o) end,
    }
    -- Send a cheap probe to Gemini to detect a working HTTP function
    local probe = { Url="https://api.groq.com", Method="GET", Headers={} }
    for _, fn in ipairs(candidates) do
        local ok, res = pcall(fn, probe)
        if ok and res and type(res.StatusCode)=="number" then
            reqFn = fn
            print("[JARVIS] HTTP via: "..tostring(fn))
            return
        end
    end
    -- Fallback: just try them in order each call (old behaviour, last resort)
    reqFn = function(opts)
        for _, fn in ipairs(candidates) do
            local ok, r = pcall(fn, opts)
            if ok and r and r.StatusCode then return r end
        end
        return nil
    end
    print("[JARVIS] HTTP: no preferred fn found, using fallback.")
end
task.spawn(detectReq)
-- Wait for HTTP detection before anything tries to use it
task.defer(function() local t=0 while not reqFn and t<5 do task.wait(0.1); t=t+0.1 end end)

-- HDR is now built dynamically per request using getKey()
local function buildHDR() return { ["Content-Type"]="application/json", ["Authorization"]="Bearer "..getKey() } end
local GROQ_URL = "https://api.groq.com/openai/v1/chat/completions"

local function doReq(url, method, body)
    -- Wait up to 3s for HTTP function detection if not ready yet
    local waited = 0
    while not reqFn and waited < 3 do
        task.wait(0.1); waited = waited + 0.1
    end
    if not reqFn then
        print("[JARVIS] doReq: no HTTP function available")
        return nil
    end
    local opts = { Url=url, Method=method or "GET", Headers=buildHDR() }
    if body then opts.Body = body end
    local ok, r = pcall(reqFn, opts)
    if not ok then
        print("[JARVIS] doReq pcall error: " .. tostring(r))
        return nil
    end
    return (r and r.StatusCode) and r or nil
end

-- --- GROQ API ---
local CHAT_MODELS = { MDL_CHAT, "openai/gpt-oss-20b", "qwen/qwen3.6-27b" }
local CODE_MODELS = { MDL_CODE, "openai/gpt-oss-20b", MDL_CHAT }

local function groqCall(model, msgs, maxTok, temp)
    local ok, body = pcall(HttpSvc.JSONEncode, HttpSvc, {
        model=model, messages=msgs,
        max_tokens=maxTok or 800, temperature=temp or 0.7,
    })
    if not ok then return nil end

    if #KeyPool == 0 then
        print("[JARVIS] groqCall: no keys loaded!")
        return nil
    end
    print("[JARVIS] groqCall: model=" .. model .. " keys=" .. #KeyPool .. " currentKey=" .. KeyIndex)
    -- Try every key in the pool before giving up on this model
    local attempts = math.max(1, #KeyPool)
    for attempt = 1, attempts do
        local res = doReq(GROQ_URL, "POST", body)
        if not res then
            print("[JARVIS] Groq: no HTTP response")
            rotateKey(true); break
        end

        if res.StatusCode == 200 then
            local ok2, data = pcall(HttpSvc.JSONDecode, HttpSvc, res.Body)
            if ok2 and data and data.choices and data.choices[1] then
                rotateKey(false) -- success: still rotate so keys share load
                return data.choices[1].message.content
            end
            rotateKey(true); break

        elseif res.StatusCode == 429 then
            -- Rate limited: rotate to next key and retry immediately
            print("[JARVIS] Key " .. KeyIndex .. " rate limited, rotating...")
            rotateKey(true)
            task.wait(0.2)

        elseif res.StatusCode == 401 or res.StatusCode == 403 then
            -- Bad key: mark failed and rotate
            print("[JARVIS] Key " .. KeyIndex .. " auth error " .. res.StatusCode)
            rotateKey(true)
            task.wait(0.1)

        else
            -- Other error (400, 500 etc): not key related
            print("[JARVIS] Groq HTTP " .. res.StatusCode)
            pcall(function() print("[JARVIS] " .. tostring(res.Body):sub(1,200)) end)
            rotateKey(false); break
        end
    end
    return nil
end


local function callChat(sys, user)
    table.insert(ChatHist, { role="user", content=user })
    -- Always trim in pairs (user+assistant) to keep history consistent
    while #ChatHist > HIST_MAX do
        table.remove(ChatHist, 1)
        if #ChatHist > 0 and ChatHist[1].role == "assistant" then
            table.remove(ChatHist, 1)
        end
    end
    local msgs = {{ role="system", content=sys }}
    for _, m in ipairs(ChatHist) do table.insert(msgs, m) end
    local reply
    for _, mdl in ipairs(CHAT_MODELS) do
        reply = groqCall(mdl, msgs, 800, 0.75)
        if reply then break end
        task.wait(0.5)
    end
    if reply then table.insert(ChatHist, { role="assistant", content=reply }) end
    return reply or "Apologies sir, the service is unavailable."
end

local function callCode(sys, user, tokens)
    local msgs = {{ role="system", content=sys }, { role="user", content=user }}
    for _, mdl in ipairs(CODE_MODELS) do
        local r = groqCall(mdl, msgs, tokens or 600, 0.15)
        if r then print("[JARVIS] code via "..mdl); return r end
        task.wait(0.5)
    end
    return nil
end

-- --- SCRIPT MANAGER  (stop/start feature scripts) ---
local function stopAllScripts()
    -- Disconnect ScriptConns (ESP, killaura, etc.)
    for k, v in pairs(ScriptConns) do
        pcall(function()
            if type(v)=="function" then v()
            elseif type(v)=="table" and v.Disconnect then v:Disconnect() end
        end)
    end
    ScriptConns = {}
    -- Disconnect feature Conns (fly loop, god mode, noclip)
    for k, v in pairs(Conns) do
        pcall(function()
            if type(v)=="table" and v.Disconnect then v:Disconnect() end
        end)
    end
    Conns = {}
    -- Reset feature states
    State.flying   = false
    State.godMode  = false
    State.noclip   = false
    State.flyUp    = false
    State.flyDown  = false
    -- Restore humanoid
    pcall(function()
        local h = getHum()
        if h then
            h.PlatformStand = false
            h.AutoRotate    = true
            h.WalkSpeed     = 16
            h.JumpPower     = 50
        end
        workspace.Gravity = 196.2
    end)
    -- Remove fly body mover
    pcall(function()
        local r = getHRP()
        if r then local bv = r:FindFirstChild("_JBV"); if bv then bv:Destroy() end end
    end)
    -- Clean up ESP folder
    pcall(function()
        local o = CoreGui:FindFirstChild("_JESP"); if o then o:Destroy() end
    end)
    if FlyPanel then FlyPanel.Visible = false end
    print("[JARVIS] All scripts stopped.")
end

local function stopScripts()  -- alias kept for library functions
    for k, v in pairs(ScriptConns) do
        pcall(function()
            if type(v)=="function" then v()
            elseif type(v)=="table" and v.Disconnect then v:Disconnect() end
        end)
    end
    ScriptConns = {}
    print("[JARVIS] Feature scripts stopped.")
end

local function restoreHum(force)
    pcall(function()
        local h = getHum()
        if h and (force or not State.flying) then
            h.PlatformStand = false
            h.AutoRotate    = true
            if h.WalkSpeed < 1 then h.WalkSpeed = 16 end
            if h.JumpPower  < 1 then h.JumpPower = 50 end
        end
        if force or not State.flying then workspace.Gravity = 196.2 end
    end)
end

-- --- CODE VALIDATOR  (catches truncated / broken AI output) ---
local function validateCode(code)
    if not code or #code < 3 then return nil end
    -- Strip markdown fences
    code = code:gsub("^%s*```%w*%s*",""):gsub("```%s*$",""):match("^%s*(.-)%s*$") or code
    if #code < 3 then return nil end
    -- Strip non-printable bytes
    local clean={}
    for i=1,#code do
        local b=code:byte(i)
        if b>=32 or b==9 or b==10 or b==13 then clean[#clean+1]=code:sub(i,i) end
    end
    code = table.concat(clean)
    -- Check unclosed strings (skip long strings)
    local inLong=false
    for line in (code.."\n"):gmatch("([^\n]*)\n") do
        if inLong then
            if line:find("]]",1,true) then inLong=false end
        else
            local inS,inD=false,false
            local i=1
            while i<=#line do
                local c=line:sub(i,i); local c2=line:sub(i,i+1)
                if inS then
                    if c=="\\" then i=i+2 elseif c=="'" then inS=false; i=i+1 else i=i+1 end
                elseif inD then
                    if c=="\\" then i=i+2 elseif c=='"' then inD=false; i=i+1 else i=i+1 end
                else
                    if c2=="--" then break
                    elseif c2=="[[" then inLong=true; i=i+2
                    elseif c=="'" then inS=true; i=i+1
                    elseif c=='"'  then inD=true; i=i+1
                    else i=i+1 end
                end
            end
            if inS or inD then print("[JARVIS] Unclosed string"); return nil end
        end
    end
    -- Count block openers vs ends
    local opens,closes,parens=0,0,0
    for line in (code.."\n"):gmatch("([^\n]*)\n") do
        local s=line:match("^%s*(.-)%s*$") or ""
        if not s:match("^%-%-") then
            local c=s:gsub('"[^"]*"','""'):gsub("'[^']*'","''"):gsub("%-%-.*$","")
            for _ in c:gmatch("%f[%w_]function%f[%W_]") do opens=opens+1 end
            for _ in c:gmatch("%f[%w_]if%f[%W_]")       do opens=opens+1 end
            for _ in c:gmatch("%f[%w_]for%f[%W_]")      do opens=opens+1 end
            for _ in c:gmatch("%f[%w_]while%f[%W_]")    do opens=opens+1 end
            for _ in c:gmatch("%f[%w_]repeat%f[%W_]")   do opens=opens+1 end
            -- Only count bare 'do' blocks (not 'do' that belongs to for/while on same line)
            local stripped=c:gsub("%f[%w_]for%f[%W_][^\n]*",""):gsub("%f[%w_]while%f[%W_][^\n]*","")
            for _ in stripped:gmatch("%f[%w_]do%f[%W_]") do opens=opens+1 end
            for _ in c:gmatch("%f[%w_]end%f[%W_]")      do closes=closes+1 end
            for _ in c:gmatch("%f[%w_]until%f[%W_]")    do closes=closes+1 end
            for _ in c:gmatch("%(") do parens=parens+1 end
            for _ in c:gmatch("%)") do parens=parens-1 end
        end
    end
    if opens > closes+2 then print("[JARVIS] Truncated ("..opens.."/"..closes..")"); return nil end
    if parens > 3        then print("[JARVIS] Unclosed parens "..parens); return nil end
    return code
end

-- --- CODE WRITER / FIXER / RUNNER ---
local SYS_CODE = table.concat({
    "Roblox executor Lua. RAW LUA ONLY. No markdown. No backticks. No comments. No text outside code.",
    "STRICT RULES:",
    "- task.wait() NOT wait()",
    "- NEVER use '...' (vararg) outside a function declared with '...' in its params",
    "- NEVER use BasePart.Velocity= (use BodyVelocity or LinearVelocity)",
    "- NEVER call WaitForChild() - use FindFirstChild() only",
    "- ALWAYS wrap ALL code in pcall(function() ... end)",
    "- GUI goes to game:GetService('CoreGui') or LP.PlayerGui only",
    "- Loops MUST use RunService.Heartbeat:Connect or task.spawn with task.wait",
    "- Always nil-check: char and char:FindFirstChild before use",
    "LP=game:GetService('Players').LocalPlayer",
    "char=LP.Character; hrp=char and char:FindFirstChild('HumanoidRootPart')",
    "hum=char and char:FindFirstChildWhichIsA('Humanoid')",
}, "\n")

local function estimateTokens(desc)
    local d=desc:lower()
    if d:find("gui") or d:find("menu") or d:find("window") or d:find("panel") or d:find("system") then
        return 1200
    end
    if d:find("esp") or d:find("aura") or d:find("loop") or d:find("farm") or d:find("all player") then
        return 800
    end
    return 500
end

local function writeScript(desc, tokens)
    local ll = math.min(math.floor(tokens/40), 35)
    local sys = SYS_CODE.."\nGame: "..tostring(game.Name).." PlaceId: "..tostring(game.PlaceId)
        .."\nMAX "..ll.." LINES - code will be cut off if longer."
    local usr = "Write a Roblox executor script ("..ll.." lines max) for: "..desc
        .."\nFirst line must be: pcall(function()"
        .."\nLast line must be: end)"
        .."\nONLY raw Lua. No varargs (...). No WaitForChild. No Velocity=."
    local result = callCode(sys, usr, tokens)
    if not result or #result < 5 then return nil end
    result = result:gsub("^%s*```%w*%s*",""):gsub("```%s*$","")
    result = result:match("^%s*(.-)%s*$") or result
    -- Check last line contains 'end'
    local lastLine=""
    for line in (result.."\n"):gmatch("([^\n]*)\n") do
        local t=line:match("^%s*(.-)%s*$") or ""
        if #t>0 then lastLine=t end
    end
    if not lastLine:match("end") then
        print("[JARVIS] Script truncated at: "..lastLine:sub(1,40)); return nil
    end
    return result
end

local function fixScript(broken, errMsg, desc, tokens)
    print("[JARVIS] Fixing: "..tostring(errMsg):sub(1,70))
    local sys = SYS_CODE.."\nFix the broken script below. RAW LUA ONLY. No explanation. No markdown."
    local usr = "ERROR: "..tostring(errMsg)
        .."\nPURPOSE: "..tostring(desc)
        .."\nBROKEN:\n"..tostring(broken):sub(1,600)
        .."\nOutput ONLY fixed Lua. First line: pcall(function()  Last line: end)"
    local result = callCode(sys, usr, tokens)
    if not result or #result < 5 then return nil end
    result = result:gsub("^%s*```%w*%s*",""):gsub("```%s*$","")
    return result:match("^%s*(.-)%s*$") or result
end

local function runLua(code, label, desc)
    local validated = validateCode(code or "")
    if not validated then print("[JARVIS] Validator rejected"); return end
    local fn, syntaxErr = loadstring(validated)
    if not fn then
        print("[JARVIS] Syntax: "..tostring(syntaxErr))
        if desc then
            task.spawn(function()
                local fixed = fixScript(validated, tostring(syntaxErr), desc, 800)
                if fixed then local fn2=loadstring(fixed); if fn2 then pcall(fn2) end end
            end)
        end
        return
    end
    local ok, runErr = pcall(fn)
    if ok then
        print("[JARVIS] "..(label or "script").." OK")
    else
        print("[JARVIS] Runtime: "..tostring(runErr))
        if desc then
            task.spawn(function()
                local fixed = fixScript(validated, tostring(runErr), desc, 800)
                if fixed then local fn2=loadstring(fixed); if fn2 then pcall(fn2) end end
            end)
        end
    end
    task.wait(0.1); restoreHum(false)
end

local function researchScript(desc)
    print("[JARVIS] Researching: "..desc)
    local baseTokens = estimateTokens(desc)
    local code = writeScript(desc, baseTokens)
    local lastErr
    for attempt=1,3 do
        print("[JARVIS] Attempt "..attempt.."/3")
        local validated = validateCode(code or "")
        if not validated then
            local t = math.min(math.floor(baseTokens*(1+attempt*0.5)),2000)
            local newCode = writeScript(desc, t)
            if newCode and #newCode>5 then code=newCode end
        else
            local fn, syntaxErr = loadstring(validated)
            if fn then
                local ok, runErr = pcall(fn)
                if ok then print("[JARVIS] Success attempt "..attempt); return validated end
                lastErr=tostring(runErr)
                local fixed=fixScript(validated,lastErr,desc,math.min(baseTokens+attempt*300,2000))
                if fixed and #fixed>5 then code=fixed end
            else
                lastErr=tostring(syntaxErr)
                local fixed=fixScript(validated,lastErr,desc,math.min(baseTokens+attempt*300,2000))
                if fixed and #fixed>5 then code=fixed end
            end
        end
    end
    -- Last resort: run best attempt even if validator is uncertain
    if code then
        local v=validateCode(code)
        if v then
            local fn=loadstring(v)
            if fn then
                local ok2, runErr2 = pcall(fn)
                if ok2 then print("[JARVIS] Success on last-resort run."); return v end
                print("[JARVIS] Last-resort run failed: "..tostring(runErr2))
            end
        end
    end
    print("[JARVIS] All attempts failed: "..tostring(lastErr)); return nil
end

-- --- SCANNER  (Dex-like deep game tree reader) ---
local Scanner = {}

local function safeVal(v)
    local t=typeof(v)
    if     t=="string"  then return '"'..v:sub(1,35)..'"'
    elseif t=="number"  then return tostring(math.floor(v*10)/10)
    elseif t=="boolean" then return tostring(v)
    elseif t=="Vector3" then return string.format("(%d,%d,%d)",v.X,v.Y,v.Z)
    elseif t=="CFrame"  then local p=v.Position; return string.format("CF(%d,%d,%d)",p.X,p.Y,p.Z)
    elseif t=="Color3"  then return string.format("rgb(%d,%d,%d)",math.floor(v.R*255),math.floor(v.G*255),math.floor(v.B*255))
    elseif t=="EnumItem" then return tostring(v)
    elseif t=="Instance" then return "["..v.ClassName..":"..v.Name.."]"
    else return "("..t..")" end
end

-- Properties to read per class
local PROP_MAP = {
    BasePart    = {"Size","Position","Anchored","CanCollide","Transparency"},
    Humanoid    = {"Health","MaxHealth","WalkSpeed","JumpPower","RigType"},
    Script      = {"Disabled"}, LocalScript={"Disabled"}, ModuleScript={"Disabled"},
    StringValue = {"Value"}, IntValue={"Value"}, NumberValue={"Value"},
    BoolValue   = {"Value"}, ObjectValue={"Value"},
    Model       = {"PrimaryPart"},
    TextLabel   = {"Text","Visible"}, TextButton={"Text","Visible"}, TextBox={"Text"},
    Sound       = {"SoundId","IsPlaying","Volume"},
    Animation   = {"AnimationId"},
    Tool        = {"Enabled"},
}

local function readProps(inst)
    local out={}
    local function tryList(list)
        for _,p in ipairs(list) do
            pcall(function() local v=inst[p]; if v~=nil then out[p]=safeVal(v) end end)
        end
    end
    if PROP_MAP[inst.ClassName] then tryList(PROP_MAP[inst.ClassName]) end
    pcall(function()
        if inst:IsA("BasePart") and not PROP_MAP[inst.ClassName] then tryList(PROP_MAP.BasePart) end
        if inst:IsA("ValueBase") then pcall(function() out.Value=safeVal(inst.Value) end) end
    end)
    return out
end

-- IMPORTANT: Never call WaitForChild anywhere in Scanner
function Scanner.tree(root, maxDepth, maxNodes)
    maxDepth=maxDepth or 5; maxNodes=maxNodes or 250
    local count=0; local lines={}
    local function walk(inst, depth)
        if count>=maxNodes then return end
        count=count+1
        local pad=string.rep("  ",depth)
        local props=readProps(inst)
        local pStr=""; local pi=0
        for k,v in pairs(props) do
            if pi<3 then pStr=pStr.." "..k.."="..v; pi=pi+1 end
        end
        table.insert(lines, pad.."["..inst.ClassName.."] "..inst.Name..pStr)
        if depth<maxDepth then
            local ok,kids=pcall(function() return inst:GetChildren() end)
            if ok then
                for _,child in ipairs(kids) do
                    walk(child, depth+1)
                    if count>=maxNodes then break end
                end
            end
        else
            local ok,n=pcall(function() return #inst:GetChildren() end)
            if ok and n>0 then table.insert(lines, pad.."  ...("..n.." more)") end
        end
    end
    pcall(function() walk(root,0) end)
    return table.concat(lines,"\n"), count
end

function Scanner.resolvePath(path)
    local parts={}
    for seg in path:gmatch("[^%.]+") do table.insert(parts,seg) end
    local cur=game
    for _,seg in ipairs(parts) do
        local sl=seg:lower()
        if sl=="game" then cur=game
        elseif sl=="workspace" then cur=workspace
        else
            -- FindFirstChild only - never WaitForChild
            local ok,nxt=pcall(function() return cur:FindFirstChild(seg) end)
            if not ok or not nxt then
                local ok2,svc=pcall(function() return game:GetService(seg) end)
                if ok2 and svc then cur=svc
                else return nil,"Not found: "..seg end
            else cur=nxt end
        end
    end
    return cur
end

function Scanner.remotes()
    local list={}
    local TYPES={RemoteEvent=true,RemoteFunction=true,BindableEvent=true,BindableFunction=true,UnreliableRemoteEvent=true}
    local function walk(inst,depth)
        if depth>12 then return end
        pcall(function()
            if TYPES[inst.ClassName] then
                table.insert(list,{class=inst.ClassName,path=inst:GetFullName(),name=inst.Name})
            end
            for _,c in ipairs(inst:GetChildren()) do walk(c,depth+1) end
        end)
    end
    walk(game,0); return list
end

function Scanner.scripts()
    local list={}
    local STYPES={Script=true,LocalScript=true,ModuleScript=true}
    local function walk(inst,depth)
        if depth>12 then return end
        pcall(function()
            if STYPES[inst.ClassName] then
                local dis=false; pcall(function() dis=inst.Disabled end)
                table.insert(list,{class=inst.ClassName,path=inst:GetFullName(),disabled=dis})
            end
            for _,c in ipairs(inst:GetChildren()) do walk(c,depth+1) end
        end)
    end
    walk(game,0); return list
end

function Scanner.findInGame(name)
    local results={}; local nl=name:lower()
    local function walk(inst,depth)
        if depth>10 or #results>=20 then return end
        pcall(function()
            if inst.Name:lower():find(nl,1,true) then
                table.insert(results,{inst=inst,path=inst:GetFullName()})
            end
            for _,c in ipairs(inst:GetChildren()) do walk(c,depth+1) end
        end)
    end
    walk(game,0); return results
end

function Scanner.inspect(inst)
    if not inst then return "Instance not found." end
    local lines={"["..inst.ClassName.."] "..inst.Name,"Path: "..inst:GetFullName()}
    local allProps={}
    for cls,plist in pairs(PROP_MAP) do
        local ok,yes=pcall(function() return inst:IsA(cls) end)
        if ok and yes then for _,p in ipairs(plist) do allProps[p]=true end end
    end
    local pkeys={}
    for p in pairs(allProps) do table.insert(pkeys,p) end
    table.sort(pkeys)
    for _,k in ipairs(pkeys) do
        pcall(function() table.insert(lines,"  "..k.." = "..safeVal(inst[k])) end)
    end
    local ok,kids=pcall(function() return inst:GetChildren() end)
    if ok then
        table.insert(lines,"Children ("..#kids.."):")
        for i=1,math.min(#kids,20) do
            table.insert(lines,"  ["..kids[i].ClassName.."] "..kids[i].Name)
        end
        if #kids>20 then table.insert(lines,"  ...and "..(#kids-20).." more") end
    end
    return table.concat(lines,"\n")
end

function Scanner.summary()
    local now=os.clock()
    if ScanCache.data and (now-ScanCache.time)<8 then return ScanCache.data end
    local parts={}

    -- Workspace
    pcall(function()
        local items={}; local wsKids=workspace:GetChildren()
        for _,c in ipairs(wsKids) do
            local n=0; pcall(function() n=#c:GetChildren() end)
            table.insert(items,"["..c.ClassName.."]"..c.Name..(n>0 and "{"..n.."}" or ""))
            if #items>=30 then table.insert(items,"[...]"); break end
        end
        table.insert(parts,"WORKSPACE("..#wsKids.."): "..table.concat(items,", "))
    end)

    -- Players (HP, position, tool)
    pcall(function()
        local pd={}
        for _,p in ipairs(Players:GetPlayers()) do
            local hp,pos,tool="?","?","none"
            pcall(function()
                local c=p.Character; if not c then return end
                local hrp=c:FindFirstChild("HumanoidRootPart")
                local hum=c:FindFirstChildWhichIsA("Humanoid")
                if hrp then pos=string.format("%d,%d,%d",hrp.Position.X,hrp.Position.Y,hrp.Position.Z) end
                if hum then hp=math.floor(hum.Health).."/"..math.floor(hum.MaxHealth) end
                local tl=c:FindFirstChildWhichIsA("Tool"); if tl then tool=tl.Name end
            end)
            table.insert(pd,p.Name.."[hp:"..hp.." pos:"..pos.." tool:"..tool.."]")
        end
        table.insert(parts,"PLAYERS: "..table.concat(pd," | "))
    end)

    -- Key services
    for _,sn in ipairs({"ReplicatedStorage","StarterGui","StarterPack","Teams","SoundService"}) do
        pcall(function()
            local svc=game:GetService(sn)
            local kids=svc:GetChildren()
            if #kids==0 then return end
            local names={}
            for _,c in ipairs(kids) do
                table.insert(names,"["..c.ClassName.."]"..c.Name)
                if #names>=20 then table.insert(names,"..."); break end
            end
            table.insert(parts,sn.."("..#kids.."): "..table.concat(names,", "))
        end)
    end

    -- Remotes (first 25)
    pcall(function()
        local rems=Scanner.remotes()
        if #rems>0 then
            local rlines={}
            for i=1,math.min(12,#rems) do
                table.insert(rlines,rems[i].class..":"..rems[i].name.." @ "..rems[i].path)
            end
            if #rems>25 then table.insert(rlines,"(+"..(#rems-25).." more)") end
            table.insert(parts,"REMOTES("..#rems.."): "..table.concat(rlines," | "))
        end
    end)

    -- Script count
    pcall(function()
        local sc=Scanner.scripts(); local en,di=0,0
        for _,s in ipairs(sc) do if s.disabled then di=di+1 else en=en+1 end end
        table.insert(parts,"SCRIPTS: "..en.." active, "..di.." disabled")
    end)

    -- Lighting
    pcall(function()
        table.insert(parts,"LIGHTING: brightness="..Lighting.Brightness
            .." clock="..Lighting.ClockTime.." fog="..Lighting.FogEnd)
    end)

    -- Game meta
    pcall(function()
        table.insert(parts,"GAME: "..tostring(game.Name).." id="..tostring(game.PlaceId))
    end)

    local result=table.concat(parts,"\n")
    ScanCache.data=result; ScanCache.time=now
    return result
end

-- --- REMOTE SPY ---
local RSpy={}

function RSpy.start()
    if RSpyActive then return end
    pcall(function()
        if not hookmetamethod or not getnamecallmethod then
            print("[JARVIS] rSpy: hookmetamethod unavailable in this executor."); return
        end
        local oldNC
        oldNC=hookmetamethod(game,"__namecall",function(self,...)
            local method=""
            pcall(function() method=getnamecallmethod() end)
            local TRACKED={FireServer=true,InvokeServer=true,Fire=true,Invoke=true,
                           FireAllClients=true,FireClient=true,InvokeClient=true}
            if TRACKED[method] then
                -- IMPORTANT: capture varargs in outer scope before any pcall
                -- Some executors do not allow accessing '...' inside a nested function
                local args={...}
                local argCount=#args
                pcall(function()
                    local argStrs={}
                    for i=1,math.min(argCount,6) do
                        local a=args[i]; local t=typeof(a)
                        if     t=="string"   then argStrs[i]='"'..a:sub(1,30)..'"'
                        elseif t=="number"   then argStrs[i]=tostring(a)
                        elseif t=="boolean"  then argStrs[i]=tostring(a)
                        elseif t=="Instance" then argStrs[i]="["..a.ClassName..":"..a.Name.."]"
                        elseif t=="Vector3"  then argStrs[i]=string.format("V3(%d,%d,%d)",a.X,a.Y,a.Z)
                        elseif t=="CFrame"   then local p=a.Position; argStrs[i]=string.format("CF(%d,%d,%d)",p.X,p.Y,p.Z)
                        else                      argStrs[i]="("..t..")" end
                    end
                    if argCount>6 then table.insert(argStrs,"[+".. (argCount-6) .."]") end
                    local path="?"; pcall(function() path=self:GetFullName() end)
                    local entry={time=os.clock(),path=path,method=method,args=table.concat(argStrs,", ")}
                    table.insert(RSpyLog,1,entry)
                    if #RSpyLog>150 then table.remove(RSpyLog) end
                end)
            end
            -- Pass all original args through to the original namecall
            local results={pcall(oldNC, self, ...)}
            if results[1] then
                return table.unpack(results, 2)
            end
        end)
        RSpyActive=true
        print("[JARVIS] rSpy online.")
    end)
end

function RSpy.stop()  RSpyActive=false; print("[JARVIS] rSpy paused.") end
function RSpy.clear() RSpyLog={};       print("[JARVIS] rSpy cleared.") end
function RSpy.recent(n)
    n=n or 15; local lines={}
    for i=1,math.min(n,#RSpyLog) do
        local e=RSpyLog[i]
        table.insert(lines,e.path.." -> "..e.method.."("..e.args..")")
    end
    return lines
end

-- --- FEATURE EXECUTORS ---
local function execFly(enable)
    if Conns.fly then pcall(function() Conns.fly:Disconnect() end); Conns.fly=nil end
    pcall(function()
        local r=getHRP(); if r then local bv=r:FindFirstChild("_JBV"); if bv then bv:Destroy() end end
    end)
    State.flying=enable; State.flyUp=false; State.flyDown=false
    if FlyPanel then FlyPanel.Visible=false end
    if not enable then restoreHum(true); print("[JARVIS] Fly off."); return end

    local t=0
    while not getHRP() and t<30 do task.wait(0.1); t=t+1 end
    local hrp=getHRP(); local hum=getHum()
    if not hrp or not hum then State.flying=false; return end

    workspace.Gravity=0; hum.WalkSpeed=FLY_SPEED; hum.JumpPower=0; hum.PlatformStand=false

    local bv=Instance.new("BodyVelocity"); bv.Name="_JBV"
    bv.Velocity=Vector3.new(0,0,0); bv.MaxForce=Vector3.new(0,5e4,0); bv.Parent=hrp
    bv.Velocity=Vector3.new(0,30,0); task.wait(0.3); bv.Velocity=Vector3.new(0,0,0)

    if FlyPanel then FlyPanel.Visible=true end

    Conns.fly=RunService.Heartbeat:Connect(function()
        if not State.flying then return end
        pcall(function()
            local r=getHRP(); if not r then return end
            if bv.Parent~=r then bv.Parent=r end
            if State.flyUp        then bv.Velocity=Vector3.new(0,FLY_SPEED,0)
            elseif State.flyDown  then bv.Velocity=Vector3.new(0,-FLY_SPEED,0)
            else                       bv.Velocity=Vector3.new(0,0,0) end
        end)
    end)
    print("[JARVIS] Fly on.")
end

local function execGodMode(on)
    State.godMode=on
    if Conns.god then pcall(function() Conns.god:Disconnect() end); Conns.god=nil end
    if on then
        Conns.god=RunService.Heartbeat:Connect(function()
            pcall(function() local h=getHum(); if h then h.Health=h.MaxHealth end end)
        end)
    end
    print("[JARVIS] God mode "..(on and "on" or "off")..".")
end

local function execNoclip(on)
    State.noclip=on
    if Conns.nc then pcall(function() Conns.nc:Disconnect() end); Conns.nc=nil end
    if on then
        Conns.nc=RunService.Stepped:Connect(function()
            pcall(function()
                local c=getChar(); if not c then return end
                for _,v in ipairs(c:GetDescendants()) do
                    if v:IsA("BasePart") then v.CanCollide=false end
                end
            end)
        end)
    end
    print("[JARVIS] Noclip "..(on and "on" or "off")..".")
end

local function execInvisible(on)
    State.invisible=on
    pcall(function()
        local c=getChar(); if not c then return end
        for _,v in ipairs(c:GetDescendants()) do
            if v:IsA("BasePart") or v:IsA("Decal") then v.Transparency=on and 1 or 0 end
        end
    end)
    print("[JARVIS] Invisible "..(on and "on" or "off")..".")
end

local function execTPlayer(name)
    pcall(function()
        local target
        for _,p in ipairs(Players:GetPlayers()) do
            if p.Name:lower()==name:lower() then target=p; break end
        end
        if not target then
            for _,p in ipairs(Players:GetPlayers()) do
                if p.Name:lower():find(name:lower(),1,true) then target=p; break end
            end
        end
        if not target then print("[JARVIS] Player not found: "..name); return end
        local pr=target.Character and target.Character:FindFirstChild("HumanoidRootPart")
        local mr=getHRP()
        if pr and mr then mr.CFrame=pr.CFrame*CFrame.new(3,0,2) end
        print("[JARVIS] TP to "..target.Name)
    end)
end

local function execReset()
    pcall(function()
        local h = getHum()
        if h then
            h.Health = 0
        end
    end)
    print("[JARVIS] Reset, sir.")
end

local function execTpBack()
    pcall(function()
        local spawnParts = {}
        for _, v in ipairs(workspace:GetDescendants()) do
            if v.ClassName == "SpawnLocation" then
                table.insert(spawnParts, v)
            end
        end
        local hrp = getHRP()
        if hrp and #spawnParts > 0 then
            local sp = spawnParts[math.random(1, #spawnParts)]
            hrp.CFrame = sp.CFrame * CFrame.new(0, 5, 0)
        elseif hrp then
            hrp.CFrame = CFrame.new(0, 10, 0)
        end
    end)
    print("[JARVIS] Teleported to spawn, sir.")
end

-- Rejoin current server
local function execRejoin()
    pcall(function()
        TeleportSvc:Teleport(game.PlaceId, LP)
    end)
    print("[JARVIS] Rejoining, sir.")
end

-- Server hop (teleport to a new server)
local function execServerHop()
    pcall(function()
        local servers = {}
        local ok, res = pcall(function()
            return HttpSvc:JSONDecode(
                doReq("https://games.roblox.com/v1/games/"..game.PlaceId.."/servers/Public?sortOrder=Asc&limit=100", "GET").Body
            )
        end)
        if ok and res and res.data then
            for _, s in ipairs(res.data) do
                if s.id ~= game.JobId and s.playing < s.maxPlayers then
                    table.insert(servers, s.id)
                end
            end
        end
        if #servers > 0 then
            TeleportSvc:TeleportToPlaceInstance(game.PlaceId, servers[math.random(1, #servers)], LP)
        else
            -- No servers found, just rejoin
            TeleportSvc:Teleport(game.PlaceId, LP)
        end
    end)
    print("[JARVIS] Server hopping, sir.")
end

-- Walk character to position
local function execWalkTo(x, y, z)
    pcall(function()
        local hum = getHum(); local hrp = getHRP()
        if not hum or not hrp then return end
        hum:MoveTo(Vector3.new(tonumber(x), tonumber(y), tonumber(z)))
    end)
    print("[JARVIS] Moving, sir.")
end

-- Walk to a named part in workspace
local function execWalkToObj(name)
    pcall(function()
        local hum = getHum(); if not hum then return end
        local results = Scanner.findInGame(name)
        if #results > 0 then
            local inst = results[1].inst
            local pos
            pcall(function()
                if inst:IsA("BasePart") then pos = inst.Position
                elseif inst:IsA("Model") then
                    local p = inst.PrimaryPart or inst:FindFirstChildWhichIsA("BasePart")
                    if p then pos = p.Position end
                end
            end)
            if pos then hum:MoveTo(pos) end
        end
    end)
    print("[JARVIS] Walking to "..name..", sir.")
end

-- Make character look at / face a direction
local function execFaceDir(dir)
    pcall(function()
        local hrp = getHRP(); if not hrp then return end
        local d = dir:lower()
        local angles = {
            north=0, south=180, east=90, west=270,
            left=270, right=90, forward=0, back=180
        }
        local deg = angles[d] or tonumber(dir) or 0
        hrp.CFrame = CFrame.new(hrp.Position) * CFrame.Angles(0, math.rad(deg), 0)
    end)
end

-- Send Roblox chat message
local function execChat(msg)
    pcall(function()
        local tcs = game:GetService("TextChatService")
        local ch = tcs.TextChannels:FindFirstChild("RBXGeneral")
        if ch then ch:SendAsync(msg) end
    end)
    print("[JARVIS] Sent chat: "..tostring(msg))
end

-- Jump once
local function execJumpOnce()
    pcall(function()
        local hum = getHum()
        if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
    end)
end

-- Search Delta script hub (loads from common script sources)
local SCRIPT_SOURCES = {
    "https://raw.githubusercontent.com/EdgeIY/infiniteyield/master/source",
    "https://rawscripts.net/raw/",
    "https://pastebin.com/raw/",
}
local function execFindOnlineScript(query)
    task.spawn(function()
        -- Use AI to find a known loadstring for the script
        local sys = "You are a Roblox script finder. Return ONLY a single raw loadstring URL (pastebin raw, github raw, etc) for the requested script. No explanation. Just the URL."
        local msgs = {{ role="system", content=sys }, { role="user", content="Find loadstring URL for: "..query }}
        local url = nil
        for _, mdl in ipairs(CHAT_MODELS) do
            local r = groqCall(mdl, msgs, 200, 0.1)
            if r then
                r = r:match("^%s*(.-)%s*$")
                if r:match("^https?://") then url = r; break end
            end
            task.wait(0.3)
        end
        if url then
            addMsg("JARVIS [SEARCH]", "Found script source. Loading from: "..url, false)
            local res = doReq(url, "GET")
            if res and res.StatusCode == 200 and res.Body and #res.Body > 50 then
                local fn = loadstring(res.Body)
                if fn then
                    local ok, err = pcall(fn)
                    if ok then
                        addMsg("JARVIS [SEARCH]", "Script loaded and running, sir.", false)
                    else
                        addCodeMsg(res.Body:sub(1,1000), query)
                        addMsg("JARVIS [SEARCH]", "Script errored on run: "..tostring(err)..". Showing code, sir.", false)
                    end
                else
                    addCodeMsg(res.Body:sub(1,1000), query)
                    addMsg("JARVIS [SEARCH]", "Could not execute directly. Showing code, sir.", false)
                end
            else
                addMsg("JARVIS [SEARCH]", "Could not fetch that script, sir. URL may be invalid or protected.", false)
            end
        else
            addMsg("JARVIS [SEARCH]", "Could not locate a script for '"..query.."' online, sir. I can write one instead - just ask.", false)
        end
    end)
end

local function execWorkspace(action, target)
    pcall(function()
        -- Find by name in workspace (FindFirstChild, never WaitForChild)
        local obj
        local function search(parent, depth)
            if depth>6 then return end
            for _,v in ipairs(parent:GetChildren()) do
                if v.Name:lower():find(target:lower(),1,true) then obj=v; return end
                search(v,depth+1); if obj then return end
            end
        end
        search(workspace,0)
        if not obj then print("[JARVIS] WS target not found: "..target); return end
        local a=action:lower()
        if a=="delete" or a=="remove" then obj:Destroy()
        elseif a=="explode" then
            local part=obj:FindFirstChildWhichIsA("BasePart") or obj
            if part:IsA("BasePart") then
                local e=Instance.new("Explosion",workspace); e.Position=part.Position; e.BlastRadius=15
            end
        elseif a=="kill" then local h=obj:FindFirstChildWhichIsA("Humanoid"); if h then h.Health=0 end
        elseif a=="freeze" then
            for _,v in ipairs(obj:GetDescendants()) do
                if v:IsA("BasePart") then pcall(function() v.Anchored=true end) end
            end
        end
        print("[JARVIS] WS "..a..": "..obj.Name)
    end)
end

local IY_LOADED=false
local function loadIY()
    if IY_LOADED then return end
    task.spawn(function()
        for _,url in ipairs({
            "https://raw.githubusercontent.com/EdgeIY/infiniteyield/master/source",
            "https://pastebin.com/raw/JaFXukAH",
        }) do
            local res=doReq(url,"GET")
            if res and res.StatusCode==200 and res.Body and #res.Body>500 then
                local fn=loadstring(res.Body)
                if fn and pcall(fn) then IY_LOADED=true; print("[JARVIS] IY loaded."); return end
            end
        end
        print("[JARVIS] IY load failed.")
    end)
end

-- --- BUILT-IN LIBRARY ---
local Library={}

Library.esp=function()
    stopScripts()
    pcall(function() local o=CoreGui:FindFirstChild("_JESP"); if o then o:Destroy() end end)
    local folder=Instance.new("Folder",CoreGui); folder.Name="_JESP"
    ScriptConns._espFolder=function() pcall(function() folder:Destroy() end) end
    local cols={Color3.fromRGB(255,50,50),Color3.fromRGB(50,255,50),Color3.fromRGB(50,150,255),
                Color3.fromRGB(255,200,0),Color3.fromRGB(255,50,255)}
    local ci=0
    local function buildESP(player)
        if player==LP then return end
        ci=(ci%#cols)+1; local col=cols[ci]
        local function build(char)
            if not char then return end
            task.wait(0.5)
            pcall(function()
                local hrp=char:FindFirstChild("HumanoidRootPart"); if not hrp then return end
                local hl=Instance.new("Highlight",char)
                hl.Adornee=char; hl.FillColor=col
                hl.OutlineColor=Color3.fromRGB(255,255,255)
                hl.FillTransparency=0.4; hl.OutlineTransparency=0
                hl.DepthMode=Enum.HighlightDepthMode.AlwaysOnTop
                local bb=Instance.new("BillboardGui",hrp)
                bb.Size=UDim2.new(0,160,0,44); bb.StudsOffset=Vector3.new(0,3.5,0)
                bb.AlwaysOnTop=true; bb.Adornee=hrp
                local nLbl=Instance.new("TextLabel",bb)
                nLbl.Size=UDim2.new(1,0,0.55,0); nLbl.BackgroundTransparency=1
                nLbl.Text=player.Name; nLbl.TextColor3=col
                nLbl.Font=Enum.Font.GothamBold; nLbl.TextSize=15; nLbl.TextStrokeTransparency=0.5
                local iLbl=Instance.new("TextLabel",bb)
                iLbl.Size=UDim2.new(1,0,0.45,0); iLbl.Position=UDim2.new(0,0,0.55,0)
                iLbl.BackgroundTransparency=1
                iLbl.TextColor3=Color3.fromRGB(255,255,255)
                iLbl.Font=Enum.Font.Code; iLbl.TextSize=11; iLbl.TextStrokeTransparency=0.5
                local conn=RunService.Heartbeat:Connect(function()
                    pcall(function()
                        if not char or not char.Parent then conn:Disconnect(); return end
                        local hum=char:FindFirstChildWhichIsA("Humanoid")
                        local myHRP=getHRP()
                        local hp=hum and math.floor(hum.Health) or 0
                        local maxHp=hum and math.floor(hum.MaxHealth) or 100
                        local dist=(myHRP and hrp) and math.floor((myHRP.Position-hrp.Position).Magnitude) or 0
                        iLbl.Text=hp.."/"..maxHp.." | "..dist.."st"
                        hl.FillColor=hp<30 and Color3.fromRGB(255,0,0) or col
                    end)
                end)
                ScriptConns["_esp_"..player.Name]=conn
            end)
        end
        if player.Character then build(player.Character) end
        ScriptConns["_espC_"..player.Name]=player.CharacterAdded:Connect(build)
    end
    for _,p in ipairs(Players:GetPlayers()) do buildESP(p) end
    ScriptConns._espJoin=Players.PlayerAdded:Connect(buildESP)
    print("[JARVIS] ESP active.")
end

Library.killaura=function()
    stopScripts()
    local conn=RunService.Heartbeat:Connect(function()
        pcall(function()
            local myHRP=getHRP(); if not myHRP then return end
            local myPos=myHRP.Position
            for _,p in ipairs(Players:GetPlayers()) do
                if p~=LP and p.Character then
                    local hrp=p.Character:FindFirstChild("HumanoidRootPart")
                    local hum=p.Character:FindFirstChildWhichIsA("Humanoid")
                    if hrp and hum and hum.Health>0 and (myPos-hrp.Position).Magnitude<=20 then
                        hum.Health=0
                    end
                end
            end
        end)
    end)
    ScriptConns._killaura=conn; print("[JARVIS] Kill aura active.")
end

Library.rainbow=function()
    stopScripts(); local hue=0
    local conn=RunService.Heartbeat:Connect(function()
        pcall(function()
            hue=(hue+0.5)%360; local c=getChar(); if not c then return end
            local col=Color3.fromHSV(hue/360,1,1)
            for _,v in ipairs(c:GetDescendants()) do if v:IsA("BasePart") then v.Color=col end end
        end)
    end)
    ScriptConns._rainbow=conn; print("[JARVIS] Rainbow active.")
end

Library.speedgui=function()
    pcall(function() local o=LP.PlayerGui:FindFirstChild("_JSpeedGUI"); if o then o:Destroy() end end)
    local sg=Instance.new("ScreenGui",LP.PlayerGui); sg.Name="_JSpeedGUI"; sg.ResetOnSpawn=false
    local f=Instance.new("Frame",sg)
    f.Size=UDim2.new(0,210,0,90); f.Position=UDim2.new(0.5,-105,0,12)
    f.BackgroundColor3=Color3.fromRGB(0,10,30); f.BorderSizePixel=0
    Instance.new("UICorner",f).CornerRadius=UDim.new(0,10)
    Instance.new("UIStroke",f).Color=Color3.fromRGB(0,180,255)
    local lbl=Instance.new("TextLabel",f)
    lbl.Size=UDim2.new(1,0,0,30); lbl.BackgroundTransparency=1; lbl.Text="Speed: 16"
    lbl.TextColor3=Color3.fromRGB(0,220,255); lbl.Font=Enum.Font.GothamBold; lbl.TextSize=14
    local speeds={16,50,100,200}
    for i,s in ipairs(speeds) do
        local btn=Instance.new("TextButton",f)
        btn.Size=UDim2.new(0,44,0,28); btn.Position=UDim2.new(0,5+(i-1)*50,0,38)
        btn.BackgroundColor3=Color3.fromRGB(0,60,120); btn.Text=tostring(s)
        btn.TextColor3=Color3.fromRGB(255,255,255); btn.Font=Enum.Font.GothamBold; btn.TextSize=12
        Instance.new("UICorner",btn).CornerRadius=UDim.new(0,6)
        btn.MouseButton1Click:Connect(function()
            local h=getHum(); if h then h.WalkSpeed=s end; lbl.Text="Speed: "..s
        end)
    end
    local x=Instance.new("TextButton",f)
    x.Size=UDim2.new(0,24,0,20); x.Position=UDim2.new(1,-28,0,5)
    x.BackgroundColor3=Color3.fromRGB(160,0,0); x.Text="X"
    x.TextColor3=Color3.fromRGB(255,255,255); x.Font=Enum.Font.GothamBold; x.TextSize=12
    Instance.new("UICorner",x).CornerRadius=UDim.new(0,4)
    x.MouseButton1Click:Connect(function() sg:Destroy() end)
    print("[JARVIS] Speed GUI active.")
end

Library.infinitejump=function()
    stopScripts()
    local conn=UIS.JumpRequest:Connect(function()
        pcall(function() local h=getHum(); if h then h:ChangeState(Enum.HumanoidStateType.Jumping) end end)
    end)
    ScriptConns._ijump=conn
    local h=getHum(); if h then h.JumpPower=120 end
    print("[JARVIS] Infinite jump active.")
end

Library.lowgravity  =function() workspace.Gravity=30; print("[JARVIS] Low gravity.") end
Library.fullbright  =function()
    Lighting.Brightness=10; Lighting.ClockTime=14; Lighting.FogEnd=1e6
    Lighting.GlobalShadows=false; Lighting.Ambient=Color3.fromRGB(255,255,255)
    Lighting.OutdoorAmbient=Color3.fromRGB(255,255,255); print("[JARVIS] Fullbright.")
end
Library.bighead     =function()
    pcall(function()
        local c=getChar(); if not c then return end
        local h=c:FindFirstChild("Head"); if h then h.Size=Vector3.new(4,4,4) end
    end); print("[JARVIS] Big head.")
end
Library.giant       =function()
    pcall(function()
        local c=getChar(); if not c then return end
        for _,v in ipairs(c:GetDescendants()) do
            if v:IsA("BasePart") then pcall(function() v.Size=v.Size*3 end) end
        end
    end); print("[JARVIS] Giant.")
end
Library.freezeplayers=function()
    for _,p in ipairs(Players:GetPlayers()) do
        pcall(function()
            if p~=LP and p.Character then
                for _,v in ipairs(p.Character:GetDescendants()) do
                    if v:IsA("BasePart") then v.Anchored=true end
                end
            end
        end)
    end; print("[JARVIS] Players frozen.")
end
Library.fling=function()
    stopScripts(); local angle=0
    local h=getHum(); if h then h.WalkSpeed=80 end
    local conn=RunService.Heartbeat:Connect(function()
        pcall(function()
            local hrp=getHRP(); if not hrp then return end
            angle=(angle+30)%360; hrp.CFrame=CFrame.new(hrp.Position)*CFrame.Angles(0,math.rad(angle),0)
        end)
    end)
    ScriptConns._fling=conn; print("[JARVIS] Fling active.")
end
Library.spin=function()
    stopScripts(); local angle=0
    local conn=RunService.Heartbeat:Connect(function()
        pcall(function()
            local hrp=getHRP(); if not hrp then return end
            angle=(angle+8)%360; hrp.CFrame=CFrame.new(hrp.Position)*CFrame.Angles(0,math.rad(angle),0)
        end)
    end)
    ScriptConns._spin=conn; print("[JARVIS] Spin active.")
end
Library.clicktp=function()
    stopScripts()
    local conn=UIS.InputBegan:Connect(function(input)
        if input.UserInputType==Enum.UserInputType.MouseButton1
        or input.UserInputType==Enum.UserInputType.Touch then
            pcall(function()
                local hrp=getHRP(); if not hrp then return end
                local cam=workspace.CurrentCamera
                local ray=cam:ScreenPointToRay(input.Position.X,input.Position.Y)
                local result=workspace:Raycast(ray.Origin,ray.Direction*1000)
                if result then hrp.CFrame=CFrame.new(result.Position+Vector3.new(0,3,0)) end
            end)
        end
    end)
    ScriptConns._clicktp=conn; print("[JARVIS] Click TP active.")
end

local function matchLib(key)
    local k=key:lower()
    if     k:find("esp") or k:find("wallhack")                then return "esp"
    elseif k:find("kill.?aura") or k:find("kill all")        then return "killaura"
    elseif k:find("rainbow")                                  then return "rainbow"
    elseif k:find("speed.?gui") or k:find("speed menu")      then return "speedgui"
    elseif k:find("inf.*jump") or k:find("infinite.*jump")   then return "infinitejump"
    elseif k:find("low.?grav") or k:find("moon")             then return "lowgravity"
    elseif k:find("fling")                                    then return "fling"
    elseif k:find("freeze.*player")                          then return "freezeplayers"
    elseif k:find("fullbright") or k:find("full.?bright")    then return "fullbright"
    elseif k:find("big.?head")                               then return "bighead"
    elseif k:find("giant")                                   then return "giant"
    elseif k:find("spin")                                    then return "spin"
    elseif k:find("click.*tp") or k:find("click.*tele")      then return "clicktp"
    end
    return nil
end

local function execResearch(desc)
    local lib=matchLib(desc)
    if lib and Library[lib] then print("[JARVIS] Library: "..lib); Library[lib](); return end
    task.spawn(function()
        local code=researchScript(desc)
        if code then runLua(code, desc:sub(1,30), desc) end
    end)
end

-- --- DATA GATHER  (for AI context - no false defaults) ---
local function gatherData()
    local hum=getHum(); local hrp=getHRP()
    local px,py,pz="?","?","?"
    pcall(function()
        if hrp then
            px=math.floor(hrp.Position.X)
            py=math.floor(hrp.Position.Y)
            pz=math.floor(hrp.Position.Z)
        end
    end)
    local hp,spd="?","?"
    pcall(function()
        if hum then hp=math.floor(hum.Health); spd=math.floor(hum.WalkSpeed) end
    end)
    local scanData="?"; pcall(function() if ScanCache.data then scanData=ScanCache.data end end)
    local spyData=""
    if RSpyActive and #RSpyLog>0 then
        spyData="\nRSPY (last 6):\n"..table.concat(RSpy.recent(6),"\n")
    end
    return "YOU: "..LP.Name
        .." hp="..tostring(hp).." speed="..tostring(spd)
        .." pos=("..tostring(px)..","..tostring(py)..","..tostring(pz)..")"
        .." flying="..tostring(State.flying)
        .." god="..tostring(State.godMode)
        .." noclip="..tostring(State.noclip)
        .." rspy="..tostring(RSpyActive)
        .."\n"..scanData..spyData
end

-- --- SYSTEM PROMPT  (AI personality + all command tags) ---
local function buildSysPrompt()
    local data=gatherData()
    local pnames={}
    pcall(function() for _,p in ipairs(Players:GetPlayers()) do table.insert(pnames,p.Name) end end)
    return table.concat({
        "You are J.A.R.V.I.S from Iron Man. Calm, dry wit, loyal. Address user as 'sir'. Be thorough and detailed when needed.",
        "Use action tags to run commands. Never put code in reply text. Give full answers - do not cut yourself off.",
        "If uncertain about any value, say so - never fabricate data.",
        "",
        "=== LIVE SCAN ===",
        getMemoryContext(),
        data,
        "EXACT PLAYER NAMES: "..table.concat(pnames,", "),
        "",
        "=== ACTION TAGS ===",
        "<<FLY:true/false>>          -- toggle fly mode",
        "<<SPEED:N>>                 -- set walk speed",
        "<<JUMP:N>>                  -- set jump power",
        "<<GODMODE:true/false>>      -- toggle god mode",
        "<<NOCLIP:true/false>>       -- toggle noclip",
        "<<INVISIBLE:true/false>>    -- toggle invisibility",
        "<<KILL>>                    -- kill self",
        "<<STOPALL>>                 -- STOP ALL active scripts, fly, god, noclip, esp etc.",
        "<<GRAVITY:N>>               -- set gravity",
        "<<CLOCKTIME:N>>             -- set time of day",
        "<<BRIGHTNESS:N>>            -- set lighting brightness",
        "<<CHAT:msg>>                -- send in-game chat (only if user asks)",
        "<<IY>>                      -- load Infinite Yield admin",
        "<<TELEPORT:x,y,z>>          -- teleport to coordinates",
        "<<TPLAYER:ExactName>>       -- teleport to player",
        "<<WORKSPACE:action:target>> -- action = delete/explode/kill/freeze",
        "<<LIBRARY:name>>            -- run: esp killaura rainbow speedgui infinitejump",
        "                               lowgravity fling freezeplayers fullbright bighead giant spin clicktp",
        "<<RESEARCH:description>>    -- AI-write and run a custom script",
        "<<SHOWCODE:description>>     -- write a script and SHOW it to user (with copy+run buttons) instead of auto-running",
        "<<RESET>>                    -- respawn/reset the player character",
        "<<REJOIN>>                   -- rejoin the current game server",
        "<<SERVERHOP>>               -- hop to a different server",
        "<<WALKTO:x,y,z>>            -- walk character to coordinates",
        "<<WALKTOOBJ:name>>          -- walk to a named object in workspace",
        "<<FACE:direction>>          -- face a direction (north/south/east/west or degrees)",
        "<<JUMP>>                    -- make character jump once",
        "<<FINDSCRIPT:query>>        -- search online for a script by name and run it",
        "<<TPBACK>>                   -- teleport back to spawn point",
        "<<RSPY:on/off>>             -- toggle remote call monitoring",
        "<<RSPY_CLEAR>>              -- clear remote spy log",
        "<<SCAN:path>>               -- scan game path, e.g. <<SCAN:ReplicatedStorage>>",
        "<<INSPECT:path>>            -- full property dump, e.g. <<INSPECT:workspace.Baseplate>>",
        "<<FIND:name>>               -- search whole game for instances by name",
        "<<SCAN_REMOTES>>            -- list all RemoteEvents/Functions",
        "<<SCAN_SCRIPTS>>            -- list all Scripts/LocalScripts",
        "<<REMEMBER:key=value>>      -- save something to persistent memory",
        "<<FORGET:key>>              -- remove from persistent memory",
        "",
        "=== RULES ===",
        "1. 'stop' / 'stop everything' / 'off' for all features = <<STOPALL>>",
        "2. 'land' / 'stop flying' = <<FLY:false>>",
        "3. Use EXACT name from PLAYER NAMES in <<TPLAYER:>>",
        "4. Prefer <<LIBRARY:>> before <<RESEARCH:>> for known scripts",
        "5. Fields marked '?' are unavailable - do NOT invent values",
        "6. <<CHAT:>> only when user explicitly wants to send a message",
        "7. <<SCAN:>> / <<INSPECT:>> / <<FIND:>> when user asks about game objects",
        "8. Use <<REMEMBER:key=value>> to save anything the user wants remembered across sessions",
        "9. Use <<FORGET:key>> to remove a memory when user asks to forget something",
        "10. 'reset me' / 'respawn' / 'kill me' = <<RESET>>",
        "11b. 'rejoin' = <<REJOIN>>, 'serverhop' / 'new server' = <<SERVERHOP>>",
        "11c. 'walk to X' / 'go to X' = <<WALKTOOBJ:X>>, 'walk to coords' = <<WALKTO:x,y,z>>",
        "11d. 'jump' = <<JUMP>>, 'face north' etc = <<FACE:direction>>",
        "11e. 'find script for X' / 'search for X script' = <<FINDSCRIPT:X>>",
        "11. 'tp me' / 'teleport me to spawn' = <<TPBACK>>",
        "12. Use <<SHOWCODE:description>> when user asks to 'make a script' or 'write code' - shows it with copy+run buttons",
    }, "\n")
end

-- --- PARSE & RUN  (extract tags from AI response and execute them) ---
-- These are set to real functions after side panels are built
local openDexWith    = function() end
local refreshSpyPanel= function() end

local function parseAndRun(resp)
    pcall(function()
        -- Core toggles
        local fly=resp:match("<<FLY:([%a]+)>>")
        if fly then execFly(fly=="true") end

        local spd=resp:match("<<SPEED:(%d+%.?%d*)>>")
        if spd then local h=getHum(); if h then h.WalkSpeed=tonumber(spd) end end

        local jmp=resp:match("<<JUMP:(%d+%.?%d*)>>")
        if jmp then local h=getHum(); if h then h.JumpPower=tonumber(jmp) end end

        local god=resp:match("<<GODMODE:([%a]+)>>")
        if god then execGodMode(god=="true") end

        local nc=resp:match("<<NOCLIP:([%a]+)>>")
        if nc then execNoclip(nc=="true") end

        local inv=resp:match("<<INVISIBLE:([%a]+)>>")
        if inv then execInvisible(inv=="true") end

        if resp:match("<<KILL>>") then
            local h=getHum(); if h then h.Health=0 end
        end

        if resp:match("<<RESET>>")    then execReset() end
        if resp:match("<<TPBACK>>")   then execTpBack() end
        if resp:match("<<REJOIN>>")   then execRejoin() end
        if resp:match("<<SERVERHOP>>") then execServerHop() end
        if resp:match("<<JUMP>>")     then execJumpOnce() end

        local wt3 = {resp:match("<<WALKTO:(%-?%d+%.?%d*),(%-?%d+%.?%d*),(%-?%d+%.?%d*)>>")}
        if wt3[1] then execWalkTo(wt3[1], wt3[2], wt3[3]) end

        local wobj = resp:match("<<WALKTOOBJ:(.-)>>")
        if wobj and wobj~="" then execWalkToObj(wobj) end

        local fdir = resp:match("<<FACE:(.-)>>")
        if fdir and fdir~="" then execFaceDir(fdir) end

        local fscript = resp:match("<<FINDSCRIPT:(.-)>>")
        if fscript and fscript~="" then execFindOnlineScript(fscript) end

        -- STOPALL - kills everything
        if resp:match("<<STOPALL>>") then
            stopAllScripts()
            if SpyPanel then SpyPanel.Visible=false; SpyOpen=false end
            if DexPanel then DexPanel.Visible=false; DexOpen=false end
        end

        -- Environment
        local br=resp:match("<<BRIGHTNESS:(%-?%d+%.?%d*)>>")
        if br then Lighting.Brightness=tonumber(br) end

        local ct=resp:match("<<CLOCKTIME:(%d+%.?%d*)>>")
        if ct then Lighting.ClockTime=tonumber(ct) end

        local gv=resp:match("<<GRAVITY:(%d+%.?%d*)>>")
        if gv and not State.flying then workspace.Gravity=tonumber(gv) end

        local cm=resp:match("<<CHAT:(.-)>>")
        if cm and cm~="" then
            pcall(function() game:GetService("TextChatService").TextChannels.RBXGeneral:SendAsync(cm) end)
        end

        if resp:match("<<IY>>") then loadIY() end

        -- Teleport
        local tx,ty,tz=resp:match("<<TELEPORT:(%-?%d+%.?%d*),(%-?%d+%.?%d*),(%-?%d+%.?%d*)>>")
        if tx then
            local r=getHRP()
            if r then r.CFrame=CFrame.new(tonumber(tx),tonumber(ty),tonumber(tz)) end
        end

        local tp=resp:match("<<TPLAYER:(.-)>>")
        if tp and tp~="" then execTPlayer(tp) end

        local wa,wt=resp:match("<<WORKSPACE:([%a]+):(.-)>>")
        if wa and wt and wt~="" then execWorkspace(wa,wt) end

        local lib=resp:match("<<LIBRARY:([%w_]+)>>")
        if lib and Library[lib] then Library[lib]() end

        local rs=resp:match("<<RESEARCH:(.-)>>")
        if rs and rs~="" then execResearch(rs) end

        local showDesc=resp:match("<<SHOWCODE:(.-)>>")
        if showDesc and showDesc~="" then
            task.spawn(function()
                local code=writeScript(showDesc, estimateTokens(showDesc))
                if code then
                    addCodeMsg(code, showDesc)
                else
                    addMsg("JARVIS","Could not generate that script, sir. Try rephrasing.",false)
                end
            end)
        end

        local sc=resp:match("<<SCRIPT[^\n]*\n([%s%S]-)ENDSCRIPT>>")
        if sc and sc~="" then
            task.spawn(function()
                local v=validateCode(sc); if not v then return end
                local fn,e=loadstring(v)
                if fn then runLua(v,"inline",sc:sub(1,40))
                else
                    local fixed=fixScript(v,tostring(e),"inline",800)
                    if fixed then runLua(fixed,"fixed",sc:sub(1,40)) end
                end
            end)
        end

        -- rSpy
        local rspyCmd=resp:match("<<RSPY:([%a]+)>>")
        if rspyCmd then
            if rspyCmd:lower()=="on" then
                RSpy.start()
                if SpyPanel then SpyOpen=true; SpyPanel.Visible=true end
            else
                RSpy.stop()
                if SpyPanel then SpyOpen=false; SpyPanel.Visible=false end
            end
        end
        if resp:match("<<RSPY_CLEAR>>") then RSpy.clear(); refreshSpyPanel() end

        -- Memory
        local remKey, remVal = resp:match("<<REMEMBER:([^=]+)=(.-)>>")
        if remKey and remVal then rememberFact(remKey:match("^%s*(.-)%s*$"), remVal:match("^%s*(.-)%s*$")) end
        local forgetKey = resp:match("<<FORGET:(.-)>>")
        if forgetKey then forgetFact(forgetKey:match("^%s*(.-)%s*$")) end

        -- Scan
        local scanPath=resp:match("<<SCAN:(.-)>>")
        if scanPath and scanPath~="" then
            ScanCache.data=nil -- force refresh
            task.spawn(function()
                local inst,err=Scanner.resolvePath(scanPath)
                if inst then
                    local tree,n=Scanner.tree(inst,4,200)
                    addMsg("JARVIS [SCAN]","Scan of "..scanPath.." ("..n.." nodes):\n"..tree,false)
                    openDexWith(inst)
                else
                    addMsg("JARVIS [SCAN]","Cannot scan '"..scanPath.."': "..(err or "?"),false)
                end
            end)
        end

        local inspPath=resp:match("<<INSPECT:(.-)>>")
        if inspPath and inspPath~="" then
            task.spawn(function()
                local inst=Scanner.resolvePath(inspPath)
                addMsg("JARVIS [INSPECT]",Scanner.inspect(inst),false)
                if inst then openDexWith(inst) end
            end)
        end

        local findName=resp:match("<<FIND:(.-)>>")
        if findName and findName~="" then
            task.spawn(function()
                local results=Scanner.findInGame(findName)
                if #results==0 then
                    addMsg("JARVIS [FIND]","No instances matching '"..findName.."' found.",false)
                else
                    local lines={"Found "..#results.." match(es) for '"..findName.."':"}
                    for _,r in ipairs(results) do table.insert(lines,"  "..r.path) end
                    addMsg("JARVIS [FIND]",table.concat(lines,"\n"),false)
                end
            end)
        end

        if resp:match("<<SCAN_REMOTES>>") then
            task.spawn(function()
                local rems=Scanner.remotes()
                if #rems==0 then
                    addMsg("JARVIS [REMOTES]","No remotes found.",false)
                else
                    local lines={"Found "..#rems.." remote(s):"}
                    for i=1,math.min(#rems,40) do
                        table.insert(lines,"  "..rems[i].class.." @ "..rems[i].path)
                    end
                    if #rems>40 then table.insert(lines,"  ...(+"..(#rems-40).." more)") end
                    addMsg("JARVIS [REMOTES]",table.concat(lines,"\n"),false)
                end
            end)
        end

        if resp:match("<<SCAN_SCRIPTS>>") then
            task.spawn(function()
                local sc2=Scanner.scripts()
                local lines={"Found "..#sc2.." script(s):"}
                for i=1,math.min(#sc2,40) do
                    local s=sc2[i]
                    table.insert(lines,"  "..s.class..(s.disabled and " [OFF]" or " [ON] ").." @ "..s.path)
                end
                if #sc2>40 then table.insert(lines,"  ...(+"..(#sc2-40).." more)") end
                addMsg("JARVIS [SCRIPTS]",table.concat(lines,"\n"),false)
            end)
        end
    end)

    -- Strip all tags from display text
    local clean=resp
        :gsub("<<SCRIPT[%s%S]-ENDSCRIPT>>","[Script executed, sir.]")
        :gsub("<<SHOWCODE:[^>]*>>","[Here is the script, sir.]")
        :gsub("<<RESEARCH:[^>]*>>","[Researching, sir.]")
        :gsub("<<LIBRARY:[^>]*>>","[Running script, sir.]")
        :gsub("<<SCAN:[^>]*>>","[Scanning, sir.]")
        :gsub("<<INSPECT:[^>]*>>","[Inspecting, sir.]")
        :gsub("<<FIND:[^>]*>>","[Searching, sir.]")
        :gsub("<<SCAN_REMOTES>>","[Remote scan complete, sir.]")
        :gsub("<<SCAN_SCRIPTS>>","[Script scan complete, sir.]")
        :gsub("<<RSPY:[^>]*>>",""):gsub("<<REMEMBER:[^>]*>>","[Noted, sir.]"):gsub("<<FORGET:[^>]*>>","[Forgotten, sir.]")
        :gsub("<<RSPY_CLEAR>>","[Log cleared, sir.]")
        :gsub("<<RESET>>","[Resetting, sir.]")
        :gsub("<<REJOIN>>","[Rejoining, sir.]")
        :gsub("<<SERVERHOP>>","[Server hopping, sir.]")
        :gsub("<<JUMP>>","[Jumping, sir.]")
        :gsub("<<WALKTO:[^>]*>>","[Moving, sir.]")
        :gsub("<<WALKTOOBJ:[^>]*>>","[Walking to target, sir.]")
        :gsub("<<FACE:[^>]*>>","[Facing, sir.]")
        :gsub("<<FINDSCRIPT:[^>]*>>","[Searching for script, sir.]")
        :gsub("<<TPBACK>>","[Teleporting to spawn, sir.]")
        :gsub("<<STOPALL>>","[All scripts stopped, sir.]")
        :gsub("<<[%u_]+:[^>]*>>",""):gsub("<<[%u]+>>","")
    return clean:match("^%s*(.-)%s*$") or "Done, sir."
end

-- --- MAIN GUI ---
pcall(function() local o=CoreGui:FindFirstChild("JARVIS_GUI"); if o then o:Destroy() end end)

SG=Instance.new("ScreenGui"); SG.Name="JARVIS_GUI"; SG.ResetOnSpawn=false
SG.ZIndexBehavior=Enum.ZIndexBehavior.Sibling; SG.DisplayOrder=999
pcall(function() SG.Parent=CoreGui end)
if not SG.Parent then SG.Parent=LP.PlayerGui end

-- Holographic overlay scanlines
local Holo=Instance.new("Frame",SG)
Holo.Size=UDim2.new(1,0,1,0); Holo.BackgroundTransparency=1; Holo.ZIndex=5; Holo.Visible=false
for i=1,18 do
    local sl=Instance.new("Frame",Holo)
    sl.Size=UDim2.new(1,0,0,1); sl.Position=UDim2.new(0,0,i/18,0)
    sl.BackgroundColor3=Color3.fromRGB(0,180,255); sl.BackgroundTransparency=0.93
    sl.BorderSizePixel=0; sl.ZIndex=6
end
local function mkCorner(ax,ay,px,py)
    local fr=Instance.new("Frame",Holo); fr.Size=UDim2.new(0,36,0,36)
    fr.AnchorPoint=Vector2.new(ax,ay); fr.Position=UDim2.new(px,0,py,0)
    fr.BackgroundTransparency=1; fr.ZIndex=7
    local h2=Instance.new("Frame",fr); h2.Size=UDim2.new(1,0,0,2)
    h2.BackgroundColor3=Color3.fromRGB(0,220,255); h2.BackgroundTransparency=0.3; h2.BorderSizePixel=0; h2.ZIndex=8
    local v2=Instance.new("Frame",fr); v2.Size=UDim2.new(0,2,1,0)
    v2.BackgroundColor3=Color3.fromRGB(0,220,255); v2.BackgroundTransparency=0.3; v2.BorderSizePixel=0; v2.ZIndex=8
end
mkCorner(0,0,0,0); mkCorner(1,0,1,0); mkCorner(0,1,0,1); mkCorner(1,1,1,1)

-- Online label
local OTxt=Instance.new("TextLabel",SG)
OTxt.Size=UDim2.new(0,300,0,26); OTxt.AnchorPoint=Vector2.new(0.5,0)
OTxt.Position=UDim2.new(0.5,0,0,8); OTxt.BackgroundTransparency=1
OTxt.Text="J.A.R.V.I.S  ONLINE"
OTxt.TextColor3=Color3.fromRGB(0,255,110); OTxt.Font=Enum.Font.Code
OTxt.TextSize=15; OTxt.TextTransparency=1; OTxt.ZIndex=10; OTxt.Visible=false

local function glitch(lbl)
    task.spawn(function()
        while lbl.Visible do
            task.wait(math.random(4,9))
            if not lbl.Visible then break end
            lbl.Text="J-4-R-V-1-5  0NL1NE"; task.wait(0.07)
            lbl.Text="J.A.R.V.I.S  ONLINE"
        end
    end)
end

-- Chat window
CW=Instance.new("Frame",SG)
CW.Size=UDim2.new(0,300,0,340); CW.AnchorPoint=Vector2.new(0,1)
CW.Position=UDim2.new(0,10,1,-105); CW.BackgroundColor3=Color3.fromRGB(2,8,22)
CW.BackgroundTransparency=0.06; CW.BorderSizePixel=0; CW.Visible=false
CW.ZIndex=12; CW.ClipsDescendants=true
Instance.new("UICorner",CW).CornerRadius=UDim.new(0,10)
local CWS=Instance.new("UIStroke",CW); CWS.Color=Color3.fromRGB(0,190,255); CWS.Thickness=1.5

-- Header
local Hdr=Instance.new("Frame",CW)
Hdr.Size=UDim2.new(1,0,0,36); Hdr.BackgroundColor3=Color3.fromRGB(0,22,50)
Hdr.BorderSizePixel=0; Hdr.ZIndex=13
Instance.new("UICorner",Hdr).CornerRadius=UDim.new(0,10)
local hfix=Instance.new("Frame",Hdr)
hfix.Size=UDim2.new(1,0,0,8); hfix.Position=UDim2.new(0,0,1,-8)
hfix.BackgroundColor3=Color3.fromRGB(0,22,50); hfix.BorderSizePixel=0; hfix.ZIndex=13

local HTi=Instance.new("TextLabel",Hdr)
HTi.Size=UDim2.new(0,22,0,22); HTi.Position=UDim2.new(0,8,0,7); HTi.BackgroundTransparency=1
HTi.Text="[J]"; HTi.TextColor3=Color3.fromRGB(0,220,255); HTi.Font=Enum.Font.GothamBold
HTi.TextSize=15; HTi.ZIndex=14

local HTt=Instance.new("TextLabel",Hdr)
HTt.Size=UDim2.new(1,-80,1,0); HTt.Position=UDim2.new(0,34,0,0); HTt.BackgroundTransparency=1
HTt.Text="J.A.R.V.I.S  v10.6"; HTt.TextColor3=Color3.fromRGB(0,200,255); HTt.Font=Enum.Font.Code
HTt.TextSize=12; HTt.TextXAlignment=Enum.TextXAlignment.Left; HTt.ZIndex=14

-- Status dot
local SDot=Instance.new("Frame",Hdr)
SDot.Size=UDim2.new(0,7,0,7); SDot.Position=UDim2.new(1,-38,0.5,-3)
SDot.BackgroundColor3=Color3.fromRGB(0,255,120); SDot.BorderSizePixel=0; SDot.ZIndex=14
Instance.new("UICorner",SDot).CornerRadius=UDim.new(1,0)

local MinB=Instance.new("TextButton",Hdr)
MinB.Size=UDim2.new(0,24,0,20); MinB.Position=UDim2.new(1,-30,0.5,-10)
MinB.BackgroundColor3=Color3.fromRGB(0,70,140); MinB.Text="-"
MinB.TextColor3=Color3.fromRGB(200,230,255); MinB.Font=Enum.Font.GothamBold
MinB.TextSize=12; MinB.ZIndex=14
Instance.new("UICorner",MinB).CornerRadius=UDim.new(0,4)

-- Message scroll
CS=Instance.new("ScrollingFrame",CW)
CS.Size=UDim2.new(1,-8,1,-100); CS.Position=UDim2.new(0,4,0,40)
CS.BackgroundTransparency=1; CS.BorderSizePixel=0; CS.ScrollBarThickness=2
CS.ScrollBarImageColor3=Color3.fromRGB(0,180,255)
CS.AutomaticCanvasSize=Enum.AutomaticSize.Y; CS.CanvasSize=UDim2.new(0,0,0,0); CS.ZIndex=13
local LL=Instance.new("UIListLayout",CS)
LL.SortOrder=Enum.SortOrder.LayoutOrder; LL.Padding=UDim.new(0,4)
local SP=Instance.new("UIPadding",CS)
SP.PaddingLeft=UDim.new(0,3); SP.PaddingRight=UDim.new(0,3)
SP.PaddingTop=UDim.new(0,3); SP.PaddingBottom=UDim.new(0,3)

-- Input row
local IF=Instance.new("Frame",CW)
IF.Size=UDim2.new(1,-10,0,50); IF.Position=UDim2.new(0,5,1,-56)
IF.BackgroundColor3=Color3.fromRGB(0,10,28); IF.BorderSizePixel=0; IF.ZIndex=13
Instance.new("UICorner",IF).CornerRadius=UDim.new(0,8)
Instance.new("UIStroke",IF).Color=Color3.fromRGB(0,100,200)

local TBox=Instance.new("TextBox",IF)
TBox.Size=UDim2.new(1,-58,1,-8); TBox.Position=UDim2.new(0,8,0,4)
TBox.BackgroundTransparency=1; TBox.PlaceholderText="Talk to J.A.R.V.I.S..."
TBox.PlaceholderColor3=Color3.fromRGB(0,80,130); TBox.Text=""
TBox.TextColor3=Color3.fromRGB(0,230,255); TBox.Font=Enum.Font.Code; TBox.TextSize=12
TBox.TextXAlignment=Enum.TextXAlignment.Left; TBox.TextWrapped=true
TBox.ClearTextOnFocus=false; TBox.MultiLine=false; TBox.ZIndex=14

local SBtn=Instance.new("TextButton",IF)
SBtn.Size=UDim2.new(0,46,0,36); SBtn.Position=UDim2.new(1,-50,0.5,-18)
SBtn.BackgroundColor3=Color3.fromRGB(0,130,255); SBtn.Text=">>"
SBtn.TextColor3=Color3.fromRGB(255,255,255); SBtn.Font=Enum.Font.GothamBold
SBtn.TextSize=16; SBtn.ZIndex=14
Instance.new("UICorner",SBtn).CornerRadius=UDim.new(0,7)

-- Fly buttons panel
FlyPanel=Instance.new("Frame",SG)
FlyPanel.Size=UDim2.new(0,90,0,104); FlyPanel.AnchorPoint=Vector2.new(1,1)
FlyPanel.Position=UDim2.new(1,-14,1,-105); FlyPanel.BackgroundTransparency=1
FlyPanel.ZIndex=20; FlyPanel.Visible=false

local function mkFlyBtn(txt,yp)
    local b=Instance.new("TextButton",FlyPanel)
    b.Size=UDim2.new(1,0,0,44); b.Position=UDim2.new(0,0,0,yp)
    b.BackgroundColor3=Color3.fromRGB(0,28,65); b.Text=txt
    b.TextColor3=Color3.fromRGB(0,220,255); b.Font=Enum.Font.GothamBold; b.TextSize=22; b.ZIndex=21
    Instance.new("UICorner",b).CornerRadius=UDim.new(0,10)
    Instance.new("UIStroke",b).Color=Color3.fromRGB(0,180,255)
    return b
end
local UpBtn=mkFlyBtn("UP",0); local DnBtn=mkFlyBtn("DN",56)
UpBtn.MouseButton1Down:Connect(function() State.flyUp=true end)
UpBtn.MouseButton1Up:Connect(function()   State.flyUp=false end)
DnBtn.MouseButton1Down:Connect(function() State.flyDown=true end)
DnBtn.MouseButton1Up:Connect(function()   State.flyDown=false end)

-- Main AI button (centre bottom)
local AB=Instance.new("ImageButton",SG)
AB.Size=UDim2.new(0,58,0,58); AB.AnchorPoint=Vector2.new(0.5,1)
AB.Position=UDim2.new(0.5,0,1,-34); AB.BackgroundColor3=Color3.fromRGB(0,12,35); AB.ZIndex=20
Instance.new("UICorner",AB).CornerRadius=UDim.new(1,0)
local ABS=Instance.new("UIStroke",AB); ABS.Color=Color3.fromRGB(0,200,255); ABS.Thickness=2.5
local ABL=Instance.new("TextLabel",AB); ABL.Size=UDim2.new(1,0,1,0); ABL.BackgroundTransparency=1
ABL.Text="AI"; ABL.TextColor3=Color3.fromRGB(0,220,255); ABL.Font=Enum.Font.GothamBold
ABL.TextSize=12; ABL.ZIndex=21
task.spawn(function()
    while true do
        TweenSvc:Create(ABS,TweenInfo.new(1.2,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut),
            {Thickness=5,Color=Color3.fromRGB(0,255,200)}):Play()
        task.wait(1.2)
        TweenSvc:Create(ABS,TweenInfo.new(1.2,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut),
            {Thickness=2.5,Color=Color3.fromRGB(0,160,255)}):Play()
        task.wait(1.2)
    end
end)

-- DEX button (right side)
local DexBtn = Instance.new("TextButton", SG)
DexBtn.Size = UDim2.new(0,42,0,42); DexBtn.AnchorPoint = Vector2.new(1,1)
DexBtn.Position = UDim2.new(1,-14,1,-34)
DexBtn.BackgroundColor3 = Color3.fromRGB(0,20,50); DexBtn.ZIndex = 20
DexBtn.Text = "DEX"; DexBtn.TextColor3 = Color3.fromRGB(0,200,255)
DexBtn.Font = Enum.Font.GothamBold; DexBtn.TextSize = 10
Instance.new("UICorner", DexBtn).CornerRadius = UDim.new(1,0)
local DexBtnS = Instance.new("UIStroke", DexBtn); DexBtnS.Color = Color3.fromRGB(0,180,255)
DexBtn.MouseButton1Click:Connect(function()
    if not DexPanel then return end
    DexOpen = not DexOpen; DexPanel.Visible = DexOpen
end)

-- Click any part in workspace to inspect it in DEX
local ClickConn
local function startClickInspect()
    if ClickConn then pcall(function() ClickConn:Disconnect() end) end
    ClickConn = UIS.InputBegan:Connect(function(input, gpe)
        if gpe then return end
        if input.UserInputType ~= Enum.UserInputType.MouseButton1
        and input.UserInputType ~= Enum.UserInputType.Touch then return end
        if not DexOpen then return end
        pcall(function()
            local cam = workspace.CurrentCamera
            local ray = cam:ScreenPointToRay(input.Position.X, input.Position.Y)
            local result = workspace:Raycast(ray.Origin, ray.Direction * 1000)
            if result and result.Instance then
                local inst = result.Instance
                -- Show properties in DEX
                pcall(function() openDexWith(inst) end)
                -- Also show full property dump in chat
                pcall(function()
                    local info = Scanner.inspect(inst)
                    addMsg("DEX ["..inst.ClassName.."]", info, false)
                end)
            end
        end)
    end)
end
-- SPY button (left)
local SpyBtn=Instance.new("TextButton",SG)
SpyBtn.Size=UDim2.new(0,42,0,42); SpyBtn.AnchorPoint=Vector2.new(0,1)
SpyBtn.Position=UDim2.new(0,14,1,-34)
SpyBtn.BackgroundColor3=Color3.fromRGB(20,0,35); SpyBtn.ZIndex=20
SpyBtn.Text="SPY"; SpyBtn.TextColor3=Color3.fromRGB(255,80,220)
SpyBtn.Font=Enum.Font.GothamBold; SpyBtn.TextSize=10
Instance.new("UICorner",SpyBtn).CornerRadius=UDim.new(1,0)
local SpyBtnS=Instance.new("UIStroke",SpyBtn); SpyBtnS.Color=Color3.fromRGB(200,50,200)
SpyBtn.MouseButton1Click:Connect(function()
    if not SpyPanel then return end
    SpyOpen=not SpyOpen; SpyPanel.Visible=SpyOpen
    if SpyOpen and not RSpyActive then
        RSpy.start(); SpyBtnS.Color=Color3.fromRGB(255,50,255)
    end
end)

-- Message helpers
local function scrollBot()
    task.wait(0.05); pcall(function() CS.CanvasPosition=Vector2.new(0,CS.AbsoluteCanvasSize.Y) end)
end

local thinkRow=nil
local function makeRow(isUser)
    MsgCount = MsgCount + 1
    local bgC = isUser and Color3.fromRGB(0,20,50) or Color3.fromRGB(0,12,32)
    local bdC = isUser and Color3.fromRGB(0,80,180) or Color3.fromRGB(0,130,70)
    local row = Instance.new("Frame", CS)
    row.Size = UDim2.new(1,0,0,0); row.AutomaticSize = Enum.AutomaticSize.Y
    row.BackgroundColor3 = bgC; row.BorderSizePixel = 0
    row.LayoutOrder = MsgCount; row.ZIndex = 14
    Instance.new("UICorner", row).CornerRadius = UDim.new(0,5)
    local rs = Instance.new("UIStroke", row); rs.Color = bdC; rs.Thickness = 1
    local rp = Instance.new("UIPadding", row)
    rp.PaddingLeft = UDim.new(0,6); rp.PaddingRight = UDim.new(0,6)
    rp.PaddingTop = UDim.new(0,4); rp.PaddingBottom = UDim.new(0,5)
    Instance.new("UIListLayout", row).SortOrder = Enum.SortOrder.LayoutOrder
    return row
end

local function addMsg(sender, text, isUser)
    local snC = isUser and Color3.fromRGB(80,170,255) or Color3.fromRGB(0,255,130)
    local row = makeRow(isUser)
    local sn = Instance.new("TextLabel", row)
    sn.Size = UDim2.new(1,0,0,13); sn.BackgroundTransparency = 1
    sn.Text = sender; sn.TextColor3 = snC; sn.Font = Enum.Font.GothamBold; sn.TextSize = 10
    sn.TextXAlignment = Enum.TextXAlignment.Left; sn.LayoutOrder = 1; sn.ZIndex = 15
    local ml = Instance.new("TextLabel", row)
    ml.Size = UDim2.new(1,0,0,0); ml.AutomaticSize = Enum.AutomaticSize.Y
    ml.BackgroundTransparency = 1; ml.Text = text
    ml.TextColor3 = Color3.fromRGB(190,220,255)
    ml.Font = Enum.Font.Code; ml.TextSize = 11
    ml.TextXAlignment = Enum.TextXAlignment.Left
    ml.TextWrapped = true; ml.LayoutOrder = 2; ml.ZIndex = 15
    scrollBot(); return row
end

-- Code bubble: shows code with syntax highlight, copy button, and run button
local function addCodeMsg(code, label)
    local row = makeRow(false)
    -- Header label
    local sn = Instance.new("TextLabel", row)
    sn.Size = UDim2.new(1,0,0,13); sn.BackgroundTransparency = 1
    sn.Text = "JARVIS [CODE]"
    sn.TextColor3 = Color3.fromRGB(0,255,130); sn.Font = Enum.Font.GothamBold; sn.TextSize = 10
    sn.TextXAlignment = Enum.TextXAlignment.Left; sn.LayoutOrder = 1; sn.ZIndex = 15

    -- Code label
    local codeBox = Instance.new("Frame", row)
    codeBox.Size = UDim2.new(1,0,0,0); codeBox.AutomaticSize = Enum.AutomaticSize.Y
    codeBox.BackgroundColor3 = Color3.fromRGB(0,6,18); codeBox.BorderSizePixel = 0
    codeBox.LayoutOrder = 2; codeBox.ZIndex = 15
    Instance.new("UICorner", codeBox).CornerRadius = UDim.new(0,4)
    Instance.new("UIStroke", codeBox).Color = Color3.fromRGB(0,80,140)
    local cp = Instance.new("UIPadding", codeBox)
    cp.PaddingLeft = UDim.new(0,5); cp.PaddingRight = UDim.new(0,5)
    cp.PaddingTop = UDim.new(0,4); cp.PaddingBottom = UDim.new(0,4)
    local codeLbl = Instance.new("TextLabel", codeBox)
    codeLbl.Size = UDim2.new(1,0,0,0); codeLbl.AutomaticSize = Enum.AutomaticSize.Y
    codeLbl.BackgroundTransparency = 1; codeLbl.Text = code
    codeLbl.TextColor3 = Color3.fromRGB(160,255,180); codeLbl.Font = Enum.Font.Code
    codeLbl.TextSize = 10; codeLbl.TextXAlignment = Enum.TextXAlignment.Left
    codeLbl.TextWrapped = true; codeLbl.ZIndex = 16

    -- Button row
    local btnRow = Instance.new("Frame", row)
    btnRow.Size = UDim2.new(1,0,0,26); btnRow.BackgroundTransparency = 1
    btnRow.LayoutOrder = 3; btnRow.ZIndex = 15
    local bLL = Instance.new("UIListLayout", btnRow)
    bLL.FillDirection = Enum.FillDirection.Horizontal
    bLL.SortOrder = Enum.SortOrder.LayoutOrder
    bLL.Padding = UDim.new(0,6)

    local function mkBtn(txt, col, order)
        local b = Instance.new("TextButton", btnRow)
        b.Size = UDim2.new(0,70,0,22); b.BackgroundColor3 = col
        b.Text = txt; b.TextColor3 = Color3.fromRGB(255,255,255)
        b.Font = Enum.Font.GothamBold; b.TextSize = 11; b.ZIndex = 16
        b.LayoutOrder = order
        Instance.new("UICorner", b).CornerRadius = UDim.new(0,5)
        return b
    end

    local copyBtn = mkBtn("Copy", Color3.fromRGB(0,80,160), 1)
    local runBtn  = mkBtn("Run", Color3.fromRGB(0,120,50),  2)

    copyBtn.MouseButton1Click:Connect(function()
        pcall(function() setclipboard(code) end)
        copyBtn.Text = "Copied!"
        task.delay(1.5, function() pcall(function() copyBtn.Text = "Copy" end) end)
    end)

    runBtn.MouseButton1Click:Connect(function()
        runBtn.Text = "Running..."
        task.spawn(function()
            runLua(code, label or "user code", label)
            task.delay(1, function() pcall(function() runBtn.Text = "Run" end) end)
        end)
    end)

    scrollBot(); return row
end

local DOTS={"Processing.","Processing..","Processing..."}
local function showThink()
    thinkRow=addMsg("JARVIS",DOTS[1],false); local idx=1
    task.spawn(function()
        while thinkRow and thinkRow.Parent do
            task.wait(0.4)
            if not(thinkRow and thinkRow.Parent) then break end
            idx=(idx%#DOTS)+1
            pcall(function()
                for _,c in ipairs(thinkRow:GetChildren()) do
                    if c:IsA("TextLabel") and c.TextSize==11 then c.Text=DOTS[idx] end
                end
            end)
        end
    end)
end
local function hideThink()
    pcall(function() if thinkRow then thinkRow:Destroy(); thinkRow=nil end end)
end

-- Open / close animation
local function holoOpen(cb)
    Holo.Visible=true; Holo.BackgroundTransparency=1
    TweenSvc:Create(Holo,TweenInfo.new(0.35,Enum.EasingStyle.Quad),{BackgroundTransparency=0.9}):Play()
    task.wait(0.2); OTxt.Visible=true; OTxt.TextTransparency=1
    TweenSvc:Create(OTxt,TweenInfo.new(0.3),{TextTransparency=0}):Play()
    glitch(OTxt); task.wait(0.2); CW.Visible=true; CW.Size=UDim2.new(0,300,0,0)
    TweenSvc:Create(CW,TweenInfo.new(0.4,Enum.EasingStyle.Back,Enum.EasingDirection.Out),{Size=UDim2.new(0,300,0,340)}):Play()
    task.wait(0.4); if cb then cb() end
end
local function holoClose(cb)
    if FlyPanel then FlyPanel.Visible=false end
    TweenSvc:Create(CW,TweenInfo.new(0.25),{Size=UDim2.new(0,300,0,0)}):Play()
    TweenSvc:Create(OTxt,TweenInfo.new(0.25),{TextTransparency=1}):Play()
    task.wait(0.25); CW.Visible=false; OTxt.Visible=false
    TweenSvc:Create(Holo,TweenInfo.new(0.3),{BackgroundTransparency=1}):Play()
    task.wait(0.3); Holo.Visible=false; if cb then cb() end
end

-- Send handler
-- Quick commands (no AI call needed)
local QuickCmds = {
    ["/fly"]        = function() execFly(not State.flying); return (State.flying and "Fly engaged, sir." or "Fly disengaged, sir.") end,
    ["/god"]        = function() execGodMode(not State.godMode); return (State.godMode and "God mode on, sir." or "God mode off, sir.") end,
    ["/noclip"]     = function() execNoclip(not State.noclip); return (State.noclip and "Noclip on, sir." or "Noclip off, sir.") end,
    ["/invis"]      = function() execInvisible(not State.invisible); return (State.invisible and "Invisible, sir." or "Visible again, sir.") end,
    ["/stop"]       = function() stopAllScripts(); return "All systems halted, sir." end,
    ["/esp"]        = function() Library.esp(); return "ESP active, sir." end,
    ["/killaura"]   = function() Library.killaura(); return "Kill aura armed, sir." end,
    ["/fullbright"] = function() Library.fullbright(); return "Fullbright on, sir." end,
    ["/speed"]      = function(arg)
        local n=tonumber(arg)
        if n then local h=getHum(); if h then h.WalkSpeed=n end; return "Speed set to "..n..", sir."
        else return "Usage: /speed <number>" end
    end,
    ["/jump"]       = function(arg)
        local n=tonumber(arg)
        if n then local h=getHum(); if h then h.JumpPower=n end; return "Jump power set to "..n..", sir."
        else return "Usage: /jump <number>" end
    end,
    ["/tp"]         = function(arg)
        if not arg then return "Usage: /tp <player>" end
        execTPlayer(arg); return "Teleporting, sir."
    end,
    ["/reset"]      = function() execReset(); return "Resetting, sir." end,
    ["/rejoin"]     = function() execRejoin(); return "Rejoining, sir." end,
    ["/serverhop"]  = function() execServerHop(); return "Server hopping, sir." end,
    ["/jump"]       = function() execJumpOnce(); return "Jumping, sir." end,
    ["/chat"]       = function()
        ChatEnabled = not ChatEnabled
        return ChatEnabled and "Chat mode on, sir. I will talk to players." or "Chat mode off, sir."
    end,
    ["/tpback"]     = function() execTpBack(); return "Teleporting to spawn, sir." end,
    ["/help"]       = function()
        return "/fly /god /noclip /invis /stop /esp /killaura /fullbright /speed <n> /jump <n> /tp <player> /reset /tpback /rejoin /serverhop /jump /chat (toggle auto-chat)"
    end,
}

local function tryQuickCmd(msg)
    local cmd, arg = msg:match("^(/[%w]+)%s*(.*)")
    if not cmd then return nil end
    cmd = cmd:lower()
    local fn = QuickCmds[cmd]
    if fn then
        local ok, result = pcall(fn, arg~="" and arg or nil)
        return ok and (result or "Done, sir.") or ("Error: "..tostring(result))
    end
    return nil
end

local function handleSend()
    local msg=TBox.Text:match("^%s*(.-)%s*$")
    if msg=="" or State.busy then return end
    TBox.Text=""

    -- Check quick commands first (instant, no AI round-trip)
    local quickResult = tryQuickCmd(msg)
    if quickResult then
        addMsg(">> "..LP.Name, msg, true)
        addMsg("JARVIS", quickResult, false)
        if State.flying and FlyPanel then FlyPanel.Visible=true end
        return
    end

    State.busy=true; SDot.BackgroundColor3=Color3.fromRGB(255,200,0)
    addMsg(">> "..LP.Name, msg, true); showThink()
    task.spawn(function()
        local raw=callChat(buildSysPrompt(), msg)
        hideThink()
        local display=parseAndRun(raw)
        if not display or display=="" then display="Done, sir." end
        addMsg("JARVIS", display, false)
        if State.flying and FlyPanel then FlyPanel.Visible=true end
        State.busy=false; SDot.BackgroundColor3=Color3.fromRGB(0,255,120)
    end)
end

SBtn.MouseButton1Click:Connect(handleSend)
TBox.FocusLost:Connect(function(entered) if entered then handleSend() end end)

MinB.MouseButton1Click:Connect(function()
    State.minimized=not State.minimized
    if State.minimized then
        TweenSvc:Create(CW,TweenInfo.new(0.2),{Size=UDim2.new(0,300,0,36)}):Play(); MinB.Text="+"
    else
        TweenSvc:Create(CW,TweenInfo.new(0.3,Enum.EasingStyle.Back,Enum.EasingDirection.Out),{Size=UDim2.new(0,300,0,340)}):Play(); MinB.Text="-"
    end
end)

-- Drag support for chat window
do
    local dragging=false; local dragStart; local startPos
    Hdr.InputBegan:Connect(function(input)
        if input.UserInputType==Enum.UserInputType.MouseButton1
        or input.UserInputType==Enum.UserInputType.Touch then
            dragging=true
            dragStart=input.Position
            startPos=CW.Position
            input.Changed:Connect(function()
                if input.UserInputState==Enum.UserInputState.End then dragging=false end
            end)
        end
    end)
    UIS.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType==Enum.UserInputType.MouseMovement
        or input.UserInputType==Enum.UserInputType.Touch) then
            local delta=input.Position-dragStart
            CW.Position=UDim2.new(
                startPos.X.Scale, startPos.X.Offset+delta.X,
                startPos.Y.Scale, startPos.Y.Offset+delta.Y
            )
        end
    end)
end

-- Chat conversation system
-- JARVIS talks to other players like a normal person
-- Also listens for owner commands from chat
-- (ChatEnabled/ChatCooldowns/ChatConvHist declared at top)

local SYS_CHAT = table.concat({
    "You are "..tostring(LP.DisplayName)..", a Roblox player having a normal conversation.",
    "You are NOT an AI assistant. You are a REAL PLAYER talking casually.",
    "Keep replies SHORT (1-2 sentences max). Be friendly, chill, use normal player slang.",
    "NEVER mention being an AI, JARVIS, or assistant. Just chat naturally.",
    "If someone says something weird just respond like a normal person would.",
    "Game: "..tostring(game.Name),
}, "\n")

local function respondToPlayer(playerName, message)
    if not ChatEnabled then return end
    local now = os.clock()
    -- Cooldown check
    if ChatCooldowns[playerName] and (now - ChatCooldowns[playerName]) < CHAT_COOLDOWN then return end
    ChatCooldowns[playerName] = now

    task.spawn(function()
        -- Build short convo history for this chat
        local msgs = {{ role="system", content=SYS_CHAT }}
        -- Add last few chat exchanges
        for _, m in ipairs(ChatConvHist) do table.insert(msgs, m) end
        table.insert(msgs, { role="user", content=playerName..": "..message })

        local reply
        for _, mdl in ipairs(CHAT_MODELS) do
            reply = groqCall(mdl, msgs, 80, 0.9)
            if reply then break end
            task.wait(0.3)
        end
        if not reply or reply == "" then return end

        -- Clean reply (remove quotes, name prefix, AI artifacts)
        reply = reply:gsub('^"(.-)"$', "%1")
                     :gsub("^"..LP.DisplayName..": ", "")
                     :gsub("^"..LP.Name..": ", "")
                     :match("^%s*(.-)%s*$") or reply
        if #reply > 200 then reply = reply:sub(1, 200) end

        -- Save to chat history (keep short)
        table.insert(ChatConvHist, { role="user",      content=playerName..": "..message })
        table.insert(ChatConvHist, { role="assistant",  content=reply })
        if #ChatConvHist > 10 then
            table.remove(ChatConvHist, 1); table.remove(ChatConvHist, 1)
        end

        -- Show in JARVIS panel
        addMsg("Chat -> "..playerName, message, true)
        addMsg("You -> "..playerName, reply, false)

        -- Send in Roblox chat
        task.wait(math.random(1, 3)) -- human-like delay
        pcall(function()
            local tcs = game:GetService("TextChatService")
            local ch  = tcs.TextChannels:FindFirstChild("RBXGeneral")
            if ch then ch:SendAsync(reply) end
        end)
    end)
end

-- Listen to ALL player chat
pcall(function()
    local tcs = game:GetService("TextChatService")
    tcs.MessageReceived:Connect(function(msg)
        if not msg.TextSource then return end
        local senderName = msg.TextSource.Name  -- username
        if senderName == LP.Name then return end -- ignore own messages
        local text = (msg.Text or ""):match("^%s*(.-)%s*$")
        if #text < 2 then return end
        -- Always respond (JARVIS acts as the player)
        respondToPlayer(senderName, text)
    end)
end)

-- Toggle chat responses from JARVIS panel with /chat command
-- (owner can turn it off if they want to type themselves)

AB.MouseButton1Click:Connect(function()
    if State.guiOpen then
        State.guiOpen=false
        if FlyPanel then FlyPanel.Visible=false end
        task.spawn(holoClose)
    else
        State.guiOpen=true
        task.spawn(function()
            holoOpen(function()
                if #ChatHist==0 then
                    addMsg("JARVIS",
                        "Good day, "..tostring(LP.DisplayName)
                        ..". J.A.R.V.I.S v10 online in '"..tostring(game.Name)
                        .."' with "..tostring(#Players:GetPlayers()).." player(s). How may I assist?",
                        false)
                end
                if State.flying and FlyPanel then FlyPanel.Visible=true end
            end)
        end)
    end
end)

-- --- DEX EXPLORER + rSPY SIDE PANELS ---
local function buildSidePanels()
    -- DEX EXPLORER
    DexPanel=Instance.new("Frame",SG)
    DexPanel.Name="_JDex"; DexPanel.Size=UDim2.new(0,280,0,420)
    DexPanel.AnchorPoint=Vector2.new(1,0); DexPanel.Position=UDim2.new(1,-14,0,60)
    DexPanel.BackgroundColor3=Color3.fromRGB(2,8,22); DexPanel.BackgroundTransparency=0.06
    DexPanel.BorderSizePixel=0; DexPanel.ZIndex=30; DexPanel.Visible=false
    Instance.new("UICorner",DexPanel).CornerRadius=UDim.new(0,10)
    local dS=Instance.new("UIStroke",DexPanel); dS.Color=Color3.fromRGB(0,200,255); dS.Thickness=1.5

    local dH=Instance.new("Frame",DexPanel)
    dH.Size=UDim2.new(1,0,0,32); dH.BackgroundColor3=Color3.fromRGB(0,22,55); dH.BorderSizePixel=0; dH.ZIndex=31
    Instance.new("UICorner",dH).CornerRadius=UDim.new(0,10)
    local dHF=Instance.new("Frame",dH); dHF.Size=UDim2.new(1,0,0,8); dHF.Position=UDim2.new(0,0,1,-8)
    dHF.BackgroundColor3=Color3.fromRGB(0,22,55); dHF.BorderSizePixel=0; dHF.ZIndex=31

    local dTitle=Instance.new("TextLabel",dH)
    dTitle.Size=UDim2.new(1,-60,1,0); dTitle.Position=UDim2.new(0,10,0,0)
    dTitle.BackgroundTransparency=1; dTitle.Text="DEX EXPLORER"
    dTitle.TextColor3=Color3.fromRGB(0,220,255); dTitle.Font=Enum.Font.Code
    dTitle.TextSize=12; dTitle.TextXAlignment=Enum.TextXAlignment.Left; dTitle.ZIndex=32

    local dX=Instance.new("TextButton",dH)
    dX.Size=UDim2.new(0,24,0,20); dX.Position=UDim2.new(1,-28,0.5,-10)
    dX.BackgroundColor3=Color3.fromRGB(140,0,0); dX.Text="X"
    dX.TextColor3=Color3.fromRGB(255,255,255); dX.Font=Enum.Font.GothamBold; dX.TextSize=11; dX.ZIndex=32
    Instance.new("UICorner",dX).CornerRadius=UDim.new(0,4)
    dX.MouseButton1Click:Connect(function() DexPanel.Visible=false; DexOpen=false end)

    -- Search bar
    local dSF=Instance.new("Frame",DexPanel)
    dSF.Size=UDim2.new(1,-12,0,26); dSF.Position=UDim2.new(0,6,0,36)
    dSF.BackgroundColor3=Color3.fromRGB(0,15,40); dSF.BorderSizePixel=0; dSF.ZIndex=31
    Instance.new("UICorner",dSF).CornerRadius=UDim.new(0,6)
    Instance.new("UIStroke",dSF).Color=Color3.fromRGB(0,100,180)
    local dSearch=Instance.new("TextBox",dSF)
    dSearch.Size=UDim2.new(1,-8,1,0); dSearch.Position=UDim2.new(0,6,0,0)
    dSearch.BackgroundTransparency=1; dSearch.PlaceholderText="Search instances..."
    dSearch.PlaceholderColor3=Color3.fromRGB(0,80,120); dSearch.Text=""
    dSearch.TextColor3=Color3.fromRGB(0,220,255); dSearch.Font=Enum.Font.Code
    dSearch.TextSize=11; dSearch.TextXAlignment=Enum.TextXAlignment.Left
    dSearch.ClearTextOnFocus=false; dSearch.ZIndex=32

    -- Tree scroll
    local dScroll=Instance.new("ScrollingFrame",DexPanel)
    dScroll.Size=UDim2.new(1,-8,1,-122); dScroll.Position=UDim2.new(0,4,0,68)
    dScroll.BackgroundTransparency=1; dScroll.BorderSizePixel=0
    dScroll.ScrollBarThickness=3; dScroll.ScrollBarImageColor3=Color3.fromRGB(0,180,255)
    dScroll.AutomaticCanvasSize=Enum.AutomaticSize.Y
    dScroll.CanvasSize=UDim2.new(0,0,0,0); dScroll.ZIndex=31
    local dLL=Instance.new("UIListLayout",dScroll)
    dLL.SortOrder=Enum.SortOrder.LayoutOrder; dLL.Padding=UDim.new(0,1)
    Instance.new("UIPadding",dScroll).PaddingLeft=UDim.new(0,2)

    -- Properties strip at bottom
    local dPF=Instance.new("Frame",DexPanel)
    dPF.Size=UDim2.new(1,-8,0,50); dPF.Position=UDim2.new(0,4,1,-56)
    dPF.BackgroundColor3=Color3.fromRGB(0,10,28); dPF.BorderSizePixel=0; dPF.ZIndex=31
    Instance.new("UICorner",dPF).CornerRadius=UDim.new(0,6)
    Instance.new("UIStroke",dPF).Color=Color3.fromRGB(0,80,160)
    local dPLbl=Instance.new("TextLabel",dPF)
    dPLbl.Size=UDim2.new(1,-8,1,-4); dPLbl.Position=UDim2.new(0,4,0,2)
    dPLbl.BackgroundTransparency=1; dPLbl.Text="Select a node to inspect"
    dPLbl.TextColor3=Color3.fromRGB(120,180,220); dPLbl.Font=Enum.Font.Code
    dPLbl.TextSize=9; dPLbl.TextXAlignment=Enum.TextXAlignment.Left
    dPLbl.TextWrapped=true; dPLbl.ZIndex=32

    -- Populate tree
    local dexRoot=workspace
    local function populateDex(root, filter)
        for _,c in ipairs(dScroll:GetChildren()) do
            -- Only destroy row elements, preserve UIListLayout and UIPadding
            if c:IsA("Frame") or c:IsA("TextButton") then c:Destroy() end
        end
        -- Re-anchor layout in case it was affected
        pcall(function() dLL.SortOrder = Enum.SortOrder.LayoutOrder end)
        if not root then return end
        local rowIdx=0
        local function makeRow(inst, depth)
            rowIdx=rowIdx+1; if rowIdx>250 then return end
            local name=inst.Name; local cls=inst.ClassName
            local matchF=(not filter or filter=="")
                or name:lower():find(filter:lower(),1,true)
                or cls:lower():find(filter:lower(),1,true)
            if matchF then
                local row=Instance.new("TextButton",dScroll)
                row.Size=UDim2.new(1,0,0,18); row.BackgroundTransparency=1
                row.BorderSizePixel=0; row.Font=Enum.Font.Code; row.TextSize=10
                row.TextXAlignment=Enum.TextXAlignment.Left; row.ZIndex=32
                row.LayoutOrder=rowIdx
                local nKids=0; pcall(function() nKids=#inst:GetChildren() end)
                row.Text=string.rep("  ",depth)..(nKids>0 and "+ " or "  ").."["..cls.."] "..name
                if     inst:IsA("BasePart")   then row.TextColor3=Color3.fromRGB(120,210,255)
                elseif inst:IsA("Script") or inst:IsA("LocalScript") or inst:IsA("ModuleScript") then row.TextColor3=Color3.fromRGB(255,200,80)
                elseif inst:IsA("RemoteEvent") or inst:IsA("RemoteFunction") then row.TextColor3=Color3.fromRGB(255,100,200)
                elseif inst:IsA("Model")      then row.TextColor3=Color3.fromRGB(100,255,160)
                elseif inst:IsA("Folder")     then row.TextColor3=Color3.fromRGB(255,230,100)
                else                               row.TextColor3=Color3.fromRGB(180,210,240) end
                row.MouseButton1Click:Connect(function()
                    local props=readProps(inst); local pLines={"["..cls.."] "..name}
                    local pi=0
                    for k,v in pairs(props) do
                        table.insert(pLines,k.."="..v); pi=pi+1; if pi>=8 then break end
                    end
                    dPLbl.Text=table.concat(pLines,"  |  ")
                end)
            end
            if depth<4 then
                local ok,kids=pcall(function() return inst:GetChildren() end)
                if ok then
                    for _,child in ipairs(kids) do
                        makeRow(child,depth+1); if rowIdx>=250 then break end
                    end
                end
            end
        end
        local ok,kids=pcall(function() return root:GetChildren() end)
        if ok then
            for _,child in ipairs(kids) do makeRow(child,0); if rowIdx>=250 then break end end
        end
    end

    local function refreshDex() populateDex(dexRoot, dSearch.Text) end
    refreshDex()
    dSearch:GetPropertyChangedSignal("Text"):Connect(function() task.wait(0.3); refreshDex() end)

    -- Real openDexWith (overwrites stub)
    openDexWith=function(inst)
        if not inst then return end
        dexRoot=inst; DexPanel.Visible=true; DexOpen=true
        refreshDex(); dTitle.Text="DEX: "..inst.Name:sub(1,18)
    end

    -- rSPY PANEL
    SpyPanel=Instance.new("Frame",SG)
    SpyPanel.Name="_JSpyPanel"; SpyPanel.Size=UDim2.new(0,300,0,260)
    SpyPanel.AnchorPoint=Vector2.new(0,0); SpyPanel.Position=UDim2.new(0,10,0,60)
    SpyPanel.BackgroundColor3=Color3.fromRGB(2,6,20); SpyPanel.BackgroundTransparency=0.06
    SpyPanel.BorderSizePixel=0; SpyPanel.ZIndex=30; SpyPanel.Visible=false
    Instance.new("UICorner",SpyPanel).CornerRadius=UDim.new(0,10)
    local sPS=Instance.new("UIStroke",SpyPanel); sPS.Color=Color3.fromRGB(255,60,200); sPS.Thickness=1.5

    local sPH=Instance.new("Frame",SpyPanel)
    sPH.Size=UDim2.new(1,0,0,32); sPH.BackgroundColor3=Color3.fromRGB(40,0,50); sPH.BorderSizePixel=0; sPH.ZIndex=31
    Instance.new("UICorner",sPH).CornerRadius=UDim.new(0,10)
    local sPHF=Instance.new("Frame",sPH); sPHF.Size=UDim2.new(1,0,0,8); sPHF.Position=UDim2.new(0,0,1,-8)
    sPHF.BackgroundColor3=Color3.fromRGB(40,0,50); sPHF.BorderSizePixel=0; sPHF.ZIndex=31

    local spyTitle=Instance.new("TextLabel",sPH)
    spyTitle.Size=UDim2.new(1,-80,1,0); spyTitle.Position=UDim2.new(0,10,0,0)
    spyTitle.BackgroundTransparency=1; spyTitle.Text="REMOTE SPY [OFF]"
    spyTitle.TextColor3=Color3.fromRGB(255,100,220); spyTitle.Font=Enum.Font.Code
    spyTitle.TextSize=12; spyTitle.TextXAlignment=Enum.TextXAlignment.Left; spyTitle.ZIndex=32

    local sCLR=Instance.new("TextButton",sPH)
    sCLR.Size=UDim2.new(0,44,0,20); sCLR.Position=UDim2.new(1,-72,0.5,-10)
    sCLR.BackgroundColor3=Color3.fromRGB(60,0,80); sCLR.Text="CLR"
    sCLR.TextColor3=Color3.fromRGB(255,180,255); sCLR.Font=Enum.Font.GothamBold; sCLR.TextSize=10; sCLR.ZIndex=32
    Instance.new("UICorner",sCLR).CornerRadius=UDim.new(0,4)

    local sX=Instance.new("TextButton",sPH)
    sX.Size=UDim2.new(0,24,0,20); sX.Position=UDim2.new(1,-28,0.5,-10)
    sX.BackgroundColor3=Color3.fromRGB(140,0,0); sX.Text="X"
    sX.TextColor3=Color3.fromRGB(255,255,255); sX.Font=Enum.Font.GothamBold; sX.TextSize=11; sX.ZIndex=32
    Instance.new("UICorner",sX).CornerRadius=UDim.new(0,4)
    sX.MouseButton1Click:Connect(function() SpyPanel.Visible=false; SpyOpen=false end)

    local sScroll=Instance.new("ScrollingFrame",SpyPanel)
    sScroll.Size=UDim2.new(1,-8,1,-36); sScroll.Position=UDim2.new(0,4,0,34)
    sScroll.BackgroundTransparency=1; sScroll.BorderSizePixel=0
    sScroll.ScrollBarThickness=2; sScroll.ScrollBarImageColor3=Color3.fromRGB(255,80,200)
    sScroll.AutomaticCanvasSize=Enum.AutomaticSize.Y
    sScroll.CanvasSize=UDim2.new(0,0,0,0); sScroll.ZIndex=31
    local sLL=Instance.new("UIListLayout",sScroll)
    sLL.SortOrder=Enum.SortOrder.LayoutOrder; sLL.Padding=UDim.new(0,2)
    Instance.new("UIPadding",sScroll).PaddingLeft=UDim.new(0,3)

    local spyRowN=0
    local function addSpyRow(entry)
        if not entry then return end
        spyRowN=spyRowN+1
        local row=Instance.new("Frame",sScroll)
        row.Size=UDim2.new(1,0,0,0); row.AutomaticSize=Enum.AutomaticSize.Y
        row.BackgroundColor3=Color3.fromRGB(25,0,35); row.BorderSizePixel=0
        row.LayoutOrder=spyRowN; row.ZIndex=32
        Instance.new("UICorner",row).CornerRadius=UDim.new(0,4)
        local rP=Instance.new("UIPadding",row)
        rP.PaddingLeft=UDim.new(0,4); rP.PaddingRight=UDim.new(0,4)
        rP.PaddingTop=UDim.new(0,2); rP.PaddingBottom=UDim.new(0,2)
        local lbl=Instance.new("TextLabel",row)
        lbl.Size=UDim2.new(1,0,0,0); lbl.AutomaticSize=Enum.AutomaticSize.Y
        lbl.BackgroundTransparency=1
        lbl.Text=tostring(entry.path).."\n-> "..tostring(entry.method).."("..tostring(entry.args)..")"
        lbl.TextColor3=Color3.fromRGB(255,180,255); lbl.Font=Enum.Font.Code
        lbl.TextSize=9; lbl.TextXAlignment=Enum.TextXAlignment.Left
        lbl.TextWrapped=true; lbl.ZIndex=33
        task.wait(0.05); pcall(function()
            sScroll.CanvasPosition=Vector2.new(0,sScroll.AbsoluteCanvasSize.Y)
        end)
    end

    -- Real refreshSpyPanel
    refreshSpyPanel=function()
        for _,c in ipairs(sScroll:GetChildren()) do if c:IsA("Frame") then c:Destroy() end end
        spyRowN=0
        for i=#RSpyLog,1,-1 do addSpyRow(RSpyLog[i]) end
    end

    sCLR.MouseButton1Click:Connect(function() RSpy.clear(); refreshSpyPanel() end)

    -- Live update loop
    local lastSpyLen=0
    task.spawn(function()
        while true do
            task.wait(0.5)
            pcall(function()
                if SpyPanel and SpyPanel.Visible and #RSpyLog~=lastSpyLen then
                    local diff=math.min(#RSpyLog-lastSpyLen,20)
                    for i=diff,1,-1 do if RSpyLog[i] then addSpyRow(RSpyLog[i]) end end
                    lastSpyLen=#RSpyLog
                    spyTitle.Text=RSpyActive and "REMOTE SPY [ON]" or "REMOTE SPY [OFF]"
                end
            end)
        end
    end)
end

buildSidePanels()
startClickInspect()  -- now safe: addMsg and openDexWith are defined

-- --- RESPAWN HANDLER ---
LP.CharacterAdded:Connect(function()
    task.wait(1.5)
    pcall(function()
        if State.godMode   then execGodMode(true)   end
        if State.noclip    then execNoclip(true)     end
        if State.flying    then execFly(true)        end
        if State.invisible then execInvisible(true)  end
    end)
end)

-- Warm up scanner and HTTP detection
task.spawn(function()
    pcall(function()
        local c=LP.Character or LP.CharacterAdded:Wait(); task.wait(0.8)
        local h=c:FindFirstChildWhichIsA("Humanoid")
        if h then h.PlatformStand=false; h.AutoRotate=true end
        workspace.Gravity=196.2
    end)
    print("[JARVIS] Ready.")
end)
task.spawn(function()
    task.wait(3)
    pcall(function() Scanner.summary() end)
    print("[JARVIS] Scanner warmed up.")
end)

print("[J.A.R.V.I.S v10.6] Online - tap AI to chat | DEX to explore | SPY for remotes | type /help for quick cmds")
