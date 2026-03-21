--[[
    Aimbot v3.3
    Anti-spin fix + close-range stability + shift-lock compatible
    Full compatibility: PC + Mobile, all executors
]]

----------------------------------------------------------------
-- GUARD
----------------------------------------------------------------
local function try(fn, ...)
    local ok, result = pcall(fn, ...)
    if ok then return result end
    return nil
end

local env = try(function() return getgenv() end) or _G
if env._AimbotV32 then return end
env._AimbotV32 = true

----------------------------------------------------------------
-- SAFE UTILS
----------------------------------------------------------------
local safeWait = (task and task.wait) or wait or function(n)
    local s = tick(); while tick()-s < (n or 0.03) do
        game:GetService("RunService").Heartbeat:Wait()
    end
end
local safeSpawn = (task and task.spawn) or spawn or function(f) coroutine.wrap(f)() end

----------------------------------------------------------------
-- SERVICES
----------------------------------------------------------------
local Players      = game:GetService("Players")
local RunService   = game:GetService("RunService")
local UserInput    = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Stats        = game:GetService("Stats")
local LP           = Players.LocalPlayer
local Camera       = workspace.CurrentCamera

----------------------------------------------------------------
-- FEATURE DETECTION
----------------------------------------------------------------
local Support = {
    drawing  = try(function() local d=Drawing.new("Line"); d:Remove(); return true end) or false,
    gethui   = try(function() return gethui()~=nil end) or false,
    syn      = try(function() return syn~=nil end) or false,
    protect  = try(function() return protect_gui~=nil end) or false,
    autoSize = try(function()
        local f=Instance.new("Frame"); f.AutomaticSize=Enum.AutomaticSize.Y; f:Destroy(); return true
    end) or false,
    asmVel   = try(function()
        local p=Instance.new("Part"); local _=p.AssemblyLinearVelocity; p:Destroy(); return true
    end) or false,
}

----------------------------------------------------------------
-- MATH
----------------------------------------------------------------
local V3=Vector3.new; local CFLA=CFrame.lookAt
local RAD=math.rad; local DEG=math.deg; local ACOS=math.acos
local ATAN2=math.atan2; local SIN=math.sin; local COS=math.cos
local CLAMP=math.clamp; local FLOOR=math.floor; local RANDOM=math.random
local ABS=math.abs; local SQRT=math.sqrt; local PI=math.pi
local HUGE=math.huge; local MAX=math.max; local MIN=math.min

----------------------------------------------------------------
-- PING DETECTION
----------------------------------------------------------------
local cachedPing = 0.1
local pingMethod = "default"

local function getPing()
    local p1 = try(function()
        return Stats.Network.ServerStatsItem["Data Ping"]:GetValue()
    end)
    if p1 and p1 > 1 then
        cachedPing = p1 / 1000
        pingMethod = "stats"
        return
    end

    local p2 = try(function()
        local nc = game:GetService("NetworkClient")
        return nc:GetChildren()[1]:GetPing()
    end)
    if p2 and p2 > 1 then
        cachedPing = p2 / 1000
        pingMethod = "netclient"
        return
    end

    local p3 = try(function() return LP:GetNetworkPing() end)
    if p3 and p3 > 0.001 then
        cachedPing = p3 * 2
        pingMethod = "netping"
        return
    end

    cachedPing = 0.1
    pingMethod = "default"
end

safeSpawn(function()
    while true do getPing(); safeWait(1.5) end
end)

----------------------------------------------------------------
-- CONFIG
----------------------------------------------------------------
local Config = {
    platform     = nil,
    lang         = "en",
    active       = false,
    fov          = 90,
    showFov      = true,
    prediction   = false,
    predValue    = 0.05,
    smartPredict = true,
    autoPing     = true,
    aimPart      = 2,
    humanLike    = false,
    aimSpeed     = 0.35,
    keybind      = Enum.KeyCode.C,
    waitingBind  = false,
    friends      = {},
    showCross    = true,
    crossSize    = 14,
    crossGap     = 4,
    priority     = 1,
    stickyTarget = nil,
    stickyBreak  = 25,
    -- [v3.3] ANTI-SPIN
    maxTurnDeg   = 15,
    closeRange   = 10,
}

local PRIORITIES = {
    {id=1,en="Crosshair",  ru="Перекрестие"},
    {id=2,en="Distance",   ru="Дистанция"},
    {id=3,en="Low HP",     ru="Мало HP"},
    {id=4,en="High Threat",ru="Угроза"},
    {id=5,en="Sticky",     ru="Залипание"},
}

local AIM_PARTS = {
    {id=1, en="Head (hard)", ru="Голова (сложно)"},
    {id=2, en="Body (easy)", ru="Тело (легко)"},
    {id=3, en="Legs / HRP",  ru="Ноги / HRP"},
}

local GC = {conn={},tweens={}}
local currentTarget = nil
local lastFrameDt = 0.016

----------------------------------------------------------------
-- LOCALIZATION
----------------------------------------------------------------
local L = {
    en = {
        choose="Choose Version",pc="PC",mobile="Mobile",
        title="Aimbot",active="Active",fov="FOV",
        showFov="Show FOV Circle",
        prediction="Basic Prediction",predValue="Extra Lead",
        smartPred="Smart Predict",autoPing="Auto Ping Comp.",
        pingInfo="Ping: %dms (%s)",
        aimPart="Aim Part",
        humanLike="Human-like",aimSpeed="Aim Speed",
        keybind="Keybind",langSwitch="RU",pressKey="...",
        aimOn="AIM: ON",aimOff="AIM: OFF",
        friends="Friends",addFriend="Click player to toggle",
        noPlayers="No players found",showCross="Target Cross",
        friend="FRIEND",enemy="ENEMY",
        priority="Priority",stickyBreak="Sticky Break Dist",
        priDesc1="Closest to crosshair center",
        priDesc2="Nearest enemy by distance",
        priDesc3="Lowest health first",
        priDesc4="Who damaged you recently",
        priDesc5="Lock on first target found",
        -- [v3.3]
        antiSpin="ANTI-SPIN",
        maxTurn="Max Turn (°/frame)",
        closeRange="Close Damp Range",
    },
    ru = {
        choose="Выберите версию",pc="ПК",mobile="Телефон",
        title="Аимбот",active="Активен",fov="Обзор (FOV)",
        showFov="Показать круг FOV",
        prediction="Простой предикт",predValue="Доп. поправка",
        smartPred="Умный предикт",autoPing="Авто-комп. пинга",
        pingInfo="Пинг: %dмс (%s)",
        aimPart="Часть тела",
        humanLike="Плавный (Human-like)",aimSpeed="Скорость наводки",
        keybind="Клавиша",langSwitch="EN",pressKey="...",
        aimOn="АИМ: ВКЛ",aimOff="АИМ: ВЫКЛ",
        friends="Друзья",addFriend="Нажмите на игрока",
        noPlayers="Нет игроков",showCross="Крест на цели",
        friend="ДРУГ",enemy="ВРАГ",
        priority="Приоритет",stickyBreak="Откл. залипания",
        priDesc1="Ближе к центру прицела",
        priDesc2="Ближайший враг по расстоянию",
        priDesc3="Сначала с наименьшим HP",
        priDesc4="Кто недавно нанёс урон",
        priDesc5="Захват первой найденной цели",
        -- [v3.3]
        antiSpin="АНТИ-СПИН",
        maxTurn="Макс. поворот (°/кадр)",
        closeRange="Зона замедления",
    },
}
local function t(k) return (L[Config.lang] or L.en)[k] or k end

----------------------------------------------------------------
-- FRIENDS
----------------------------------------------------------------
local function isFriend(n)
    for _,f in ipairs(Config.friends) do if f==n then return true end end; return false
end
local function toggleFriend(n)
    for i,f in ipairs(Config.friends) do
        if f==n then table.remove(Config.friends,i); return false end
    end; table.insert(Config.friends,n); return true
end

----------------------------------------------------------------
-- VELOCITY HELPER
----------------------------------------------------------------
local function getVel(hrp)
    if not hrp then return V3(0,0,0) end
    local v = V3(0,0,0)
    if Support.asmVel then try(function() v=hrp.AssemblyLinearVelocity end) end
    if v.Magnitude<0.01 then try(function() v=hrp.Velocity end) end
    return v
end

----------------------------------------------------------------
-- AIM PART RESOLVER
----------------------------------------------------------------
local function getAimPartPos(char)
    local ap = Config.aimPart
    if ap == 1 then
        local head = char:FindFirstChild("Head")
        if head then return head.Position end
    end
    if ap == 2 then
        local ut = char:FindFirstChild("UpperTorso")
        if ut then return ut.Position + V3(0, 0.3, 0) end
        local torso = char:FindFirstChild("Torso")
        if torso then return torso.Position + V3(0, 0.3, 0) end
        local head = char:FindFirstChild("Head")
        if head then return head.Position end
    end
    if ap == 3 then
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if hrp then return hrp.Position end
    end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if hrp then return hrp.Position end
    local head = char:FindFirstChild("Head")
    if head then return head.Position end
    return nil
end

----------------------------------------------------------------
-- THREAT
----------------------------------------------------------------
local ThreatData = {}
local lastHP = nil

local function updateThreats()
    local char=LP.Character; if not char then return end
    local hum=char:FindFirstChildOfClass("Humanoid"); if not hum then return end
    local hp=hum.Health
    if lastHP and hp<lastHP then
        local dmg=lastHP-hp; local now=tick()
        local myH=char:FindFirstChild("HumanoidRootPart")
        if myH then
            local myP=myH.Position; local cl,cd=nil,HUGE
            for _,p in ipairs(Players:GetPlayers()) do
                if p~=LP and p.Character and not isFriend(p.Name) then
                    local h=p.Character:FindFirstChild("HumanoidRootPart")
                    if h then local d=(h.Position-myP).Magnitude
                        if d<cd and d<50 then cd=d; cl=p end
                    end
                end
            end
            if cl then
                if not ThreatData[cl.Name] then ThreatData[cl.Name]={totalDmg=0,lastHit=0,hits=0} end
                local td=ThreatData[cl.Name]; td.totalDmg=td.totalDmg+dmg; td.lastHit=now; td.hits=td.hits+1
            end
        end
    end; lastHP=hp
end

local function getThreat(name)
    local td=ThreatData[name]; if not td then return 0 end
    local age=tick()-td.lastHit
    if age>15 then ThreatData[name]=nil; return 0 end
    return (td.totalDmg*0.5+td.hits*10)*MAX(0,1-age/15)
end

----------------------------------------------------------------
-- SMART PREDICT ENGINE v3
----------------------------------------------------------------
local SPData = {}

local function spInit()
    return {
        posBuf     = {},
        rawVel     = V3(0,0,0),
        smoothVel  = V3(0,0,0),
        accel      = V3(0,0,0),
        angVel     = 0,
        isSprint   = false,
        isStop     = false,
        isStrafe   = false,
        baseSpeed  = 16,
        lastFlatDir= V3(0,0,0),
        dirChanges = {},
        confidence = 0.6,
        lastTime   = 0,
    }
end

local function v3FM(v) return SQRT(v.X*v.X+v.Z*v.Z) end
local function v3FU(v) local m=v3FM(v); if m<0.001 then return V3(0,0,0) end; return V3(v.X/m,0,v.Z/m) end
local function angF(a,b)
    local au,bu=v3FU(a),v3FU(b)
    if au.Magnitude<0.001 or bu.Magnitude<0.001 then return 0 end
    return ACOS(CLAMP(au:Dot(bu),-1,1))
end
local function crsY(a,b) return a.X*b.Z-a.Z*b.X end

local function spUpdate(plr, char)
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hrp or not hum then return nil end

    local now = tick()
    local pos = hrp.Position
    local d = SPData[plr]
    if not d then d = spInit(); SPData[plr] = d end

    local dt = now - d.lastTime
    if dt < 0.005 then return d end
    d.lastTime = now

    table.insert(d.posBuf, {p=pos, t=now})
    while #d.posBuf > 20 do table.remove(d.posBuf, 1) end

    local serverVel = getVel(hrp)

    local posVel = V3(0,0,0)
    if #d.posBuf >= 3 then
        local idx = MAX(1, #d.posBuf - 1)
        local old = d.posBuf[idx]
        local pdt = now - old.t
        if pdt > 0.005 then posVel = (pos - old.p) / pdt end
    elseif #d.posBuf >= 2 then
        local old = d.posBuf[#d.posBuf - 1]
        local pdt = now - old.t
        if pdt > 0.005 then posVel = (pos - old.p) / pdt end
    end

    local useVel
    if serverVel.Magnitude > 1 and posVel.Magnitude > 0.5 then
        local agree = serverVel.Unit:Dot(posVel.Unit)
        if agree > 0.5 then
            useVel = serverVel
        else
            useVel = posVel
        end
    elseif serverVel.Magnitude > 1 then
        useVel = serverVel
    else
        useVel = posVel
    end

    d.rawVel = useVel
    d.smoothVel = useVel * 0.92 + d.smoothVel * 0.08

    if #d.posBuf >= 4 then
        local i1 = MAX(1, #d.posBuf - 3)
        local v1 = V3(0,0,0)
        if i1 > 1 then
            local dt1 = d.posBuf[i1].t - d.posBuf[i1-1].t
            if dt1 > 0.005 then v1 = (d.posBuf[i1].p - d.posBuf[i1-1].p) / dt1 end
        end
        local dt2 = now - d.posBuf[#d.posBuf-1].t
        local v2 = dt2 > 0.005 and (pos - d.posBuf[#d.posBuf-1].p) / dt2 or useVel
        local adt = now - d.posBuf[i1].t
        if adt > 0.01 then
            d.accel = d.accel + ((v2-v1)/adt - d.accel) * 0.5
        end
    end

    local ws = 16; try(function() ws = hum.WalkSpeed end)
    d.baseSpeed = MAX(d.baseSpeed * 0.995, ws * 0.75)

    local flatSpeed = v3FM(useVel)
    d.isSprint = ws / MAX(d.baseSpeed, 1) > 1.35 or flatSpeed > d.baseSpeed * 1.35

    local moveDir = V3(0,0,0); try(function() moveDir = hum.MoveDirection end)
    d.isStop = v3FM(moveDir) < 0.1 and flatSpeed > 0.5

    local flatDir = v3FU(useVel)
    if flatSpeed > 1 and d.lastFlatDir.Magnitude > 0.01 then
        local ta = angF(d.lastFlatDir, flatDir)
        d.isStrafe = ta > 0.6 and dt < 0.2
        if ta > 0.3 then
            table.insert(d.dirChanges, {a=ta, s=crsY(d.lastFlatDir,flatDir)>0 and 1 or -1, t=now})
            while #d.dirChanges > 15 do table.remove(d.dirChanges, 1) end
        end
    end
    if flatSpeed > 1 then d.lastFlatDir = flatDir end

    if #d.posBuf >= 5 then
        local p0 = d.posBuf[MAX(1,#d.posBuf-4)]
        local p1 = d.posBuf[MAX(1,#d.posBuf-2)]
        local p2 = d.posBuf[#d.posBuf]
        local d0 = v3FU(p1.p-p0.p); local d1 = v3FU(p2.p-p1.p)
        if d0.Magnitude>0.001 and d1.Magnitude>0.001 then
            local ad = angF(d0,d1); local adt = p2.t-p0.t
            if adt>0.01 then
                local sign = crsY(d0,d1)>0 and 1 or -1
                d.angVel = d.angVel + (sign*ad/adt - d.angVel) * 0.35
            end
        end
    end

    local conf = 0.6
    if flatSpeed > 2 and not d.isStrafe then conf = conf + 0.25 end
    if d.isSprint then conf = conf + 0.1 end
    if d.isStop then conf = conf * 0.5 end
    local rs = 0
    for _,dc in ipairs(d.dirChanges) do if now-dc.t<0.4 then rs=rs+1 end end
    if rs > 3 then conf = conf * 0.7 end
    d.confidence = CLAMP(conf, 0.3, 0.95)

    return d
end

local function getSmartPredTime()
    local total = 0
    if Config.autoPing then
        total = total + cachedPing
        total = total + lastFrameDt
        if Config.platform == "mobile" then
            total = total + 0.05
        end
    end
    total = total + Config.predValue
    return MAX(total, 0.01)
end

local function spPredict(plr, char)
    local d = spUpdate(plr, char)
    if not d then return V3(0,0,0) end

    local pt = getSmartPredTime()
    if pt < 0.005 then return V3(0,0,0) end

    local flatSpeed = v3FM(d.rawVel)

    if d.isStop and flatSpeed < 2 then
        local stopFactor = CLAMP(flatSpeed / MAX(d.baseSpeed, 1), 0, 1)
        return d.rawVel * pt * stopFactor * 0.3
    end

    local vel = d.rawVel
    local base = vel * pt

    local accelOff = d.accel * 0.5 * pt * pt
    if accelOff.Magnitude > flatSpeed * pt * 0.5 then
        accelOff = accelOff.Unit * flatSpeed * pt * 0.5
    end

    local sprintMult = 1.0
    if d.isSprint then
        sprintMult = 1.08
        local mf = v3FU(vel)
        if mf.Magnitude > 0.01 then
            base = base + mf * (flatSpeed * 0.03 * pt)
        end
    end

    if ABS(d.angVel) > 0.15 and flatSpeed > 2 then
        local ad = d.angVel * pt
        local cd = v3FU(vel)
        if cd.Magnitude > 0.01 then
            local ca, sa = COS(ad), SIN(ad)
            local rd = V3(cd.X*ca - cd.Z*sa, 0, cd.X*sa + cd.Z*ca)
            local cv = rd * flatSpeed * pt
            local cf = CLAMP(ABS(d.angVel) / 3, 0, 0.4)
            local fb = V3(base.X, 0, base.Z)
            base = V3(fb.X*(1-cf)+cv.X*cf, base.Y, fb.Z*(1-cf)+cv.Z*cf)
        end
    end

    local vertOff = V3(0,0,0)
    if ABS(vel.Y) > 1 then
        vertOff = V3(0, vel.Y*pt - 0.5*196.2*pt*pt - vel.Y*pt, 0)
    end

    local total = (base + accelOff + vertOff) * sprintMult * d.confidence

    local mx = flatSpeed * pt * 2.5
    if mx < 0.1 then mx = 0.1 end
    if total.Magnitude > mx then total = total.Unit * mx end

    return total
end

local function simplePred(char)
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return V3(0,0,0) end
    local v = getVel(hrp)
    local pt = Config.predValue
    if Config.autoPing then pt = pt + cachedPing end
    return v * pt
end

----------------------------------------------------------------
-- ROTATION  [v3.3 ANTI-SPIN REWRITE]
----------------------------------------------------------------
local function getYP(cf)
    local lv=cf.LookVector
    return ATAN2(-lv.X,-lv.Z),ATAN2(lv.Y,SQRT(lv.X*lv.X+lv.Z*lv.Z))
end
local function ypTo(from,to)
    local d=(to-from).Unit
    return ATAN2(-d.X,-d.Z),ATAN2(d.Y,SQRT(d.X*d.X+d.Z*d.Z))
end
local function cfYP(pos,y,p)
    local cy,sy=COS(y),SIN(y); local cp,sp=COS(p),SIN(p)
    return CFLA(pos,pos+V3(-sy*cp,sp,-cy*cp))
end
local function aDiff(a,b) local d=(b-a)%(2*PI); if d>PI then d=d-2*PI end; return d end
local function lAng(a,b,f) return a+aDiff(a,b)*f end

-- [v3.3] helper: compute distance-based damping multiplier
local function distDamp(aimPos, camPos)
    local dist = (aimPos - camPos).Magnitude
    if dist >= Config.closeRange then return 1.0 end
    local ratio = CLAMP(dist / Config.closeRange, 0, 1)
    -- smooth curve: keeps ~60% power at half-range, drops to 15% at point-blank
    return 0.15 + 0.85 * ratio * ratio
end

-- [v3.3] helper: clamp yaw/pitch rotation to maxTurnDeg per frame
local function clampRotation(oldY, oldP, newY, newP, dt)
    local maxRad = RAD(Config.maxTurnDeg) * CLAMP(dt * 60, 0.5, 3)
    local maxPitch = maxRad * 0.6 -- pitch axis more restrictive

    local dy = aDiff(oldY, newY)
    local dp = aDiff(oldP, newP)

    if ABS(dy) > maxRad then
        newY = oldY + (dy > 0 and maxRad or -maxRad)
    end
    if ABS(dp) > maxPitch then
        newP = oldP + (dp > 0 and maxPitch or -maxPitch)
    end
    return newY, newP
end

-- [v3.3] REWRITTEN: smoothAim now takes dt, applies distance damping + rotation cap
local function smoothAim(cur, tgt, fac, dt)
    local pos = cur.Position
    local cy, cp = getYP(cur)
    local ty, tp = ypTo(pos, tgt)

    -- distance-based damping
    local dm = distDamp(tgt, pos)
    local effectiveFac = fac * dm

    -- interpolate
    local newY = lAng(cy, ty, effectiveFac)
    local newP = lAng(cp, tp, effectiveFac)

    -- clamp max rotation per frame
    newY, newP = clampRotation(cy, cp, newY, newP, dt)

    return cfYP(pos, newY, newP)
end

-- [v3.3] REWRITTEN: human-like aim with distance damping + rotation cap
local HA={yO=0,pO=0,yT=0,pT=0,nt=0}
function HA:tick()
    local now=tick()
    if now>=self.nt then
        self.yT=(RANDOM()-0.5)*0.012; self.pT=(RANDOM()-0.5)*0.008
        self.nt=now+0.06+RANDOM()*0.12
    end
    self.yO=self.yO+(self.yT-self.yO)*0.14
    self.pO=self.pO+(self.pT-self.pO)*0.14
end
function HA:aim(cur,ap,dt)
    self:tick(); local pos=cur.Position
    local cy,cp=getYP(cur); local ty,tp=ypTo(pos,ap)
    ty=ty+self.yO; tp=tp+self.pO
    local td=DEG(ABS(aDiff(cy,ty))+ABS(aDiff(cp,tp)))
    local curve=0.12+0.88*CLAMP(td/20,0,1)
    local fac=CLAMP(Config.aimSpeed*curve*dt*60,0.005,0.85)

    -- [v3.3] distance damping
    local dm = distDamp(ap, pos)
    fac = fac * dm

    -- interpolate
    local newY = lAng(cy, ty, fac)
    local newP = lAng(cp, tp, fac)

    -- [v3.3] clamp max rotation
    newY, newP = clampRotation(cy, cp, newY, newP, dt)

    return cfYP(pos, newY, newP)
end

----------------------------------------------------------------
-- TARGET SELECTION
----------------------------------------------------------------
local function alive(c)
    if not c then return false end
    local h=c:FindFirstChildOfClass("Humanoid")
    local r=c:FindFirstChild("HumanoidRootPart")
    return h and r and h.Health>0
end

local function getValid()
    Camera=workspace.CurrentCamera; local cf=Camera.CFrame; local tgts={}
    for _,p in ipairs(Players:GetPlayers()) do
        if p~=LP and p.Character and alive(p.Character) and not isFriend(p.Name) then
            local aimPos = getAimPartPos(p.Character)
            local hrp=p.Character:FindFirstChild("HumanoidRootPart")
            local hum=p.Character:FindFirstChildOfClass("Humanoid")
            if aimPos and hrp and hum then
                local dir=(aimPos-cf.Position); local dist=dir.Magnitude
                if dist>0.5 then
                    dir=dir.Unit
                    local dot=CLAMP(cf.LookVector:Dot(dir),-1,1)
                    local angle=DEG(ACOS(dot))
                    if Config.fov>=360 or angle<Config.fov/2 then
                        local hp=100; try(function() hp=hum.Health end)
                        local mhp=100; try(function() mhp=hum.MaxHealth end)
                        table.insert(tgts,{
                            player=p,dist=dist,angle=angle,
                            hp=hp,maxHp=mhp,threat=getThreat(p.Name),
                        })
                    end
                end
            end
        end
    end; return tgts
end

local function bestTarget()
    local tgts=getValid()
    if #tgts==0 then Config.stickyTarget=nil; return nil end
    local pri=Config.priority

    if pri==5 then
        local st=Config.stickyTarget
        if st then
            for _,tg in ipairs(tgts) do
                if tg.player==st then
                    if tg.dist<=Config.stickyBreak then return st
                    else Config.stickyTarget=nil; break end
                end
            end; Config.stickyTarget=nil
        end
    end

    if pri==1 then table.sort(tgts,function(a,b) return a.angle<b.angle end)
    elseif pri==2 then table.sort(tgts,function(a,b) return a.dist<b.dist end)
    elseif pri==3 then table.sort(tgts,function(a,b)
        if ABS(a.hp-b.hp)<1 then return a.dist<b.dist end; return a.hp<b.hp end)
    elseif pri==4 then table.sort(tgts,function(a,b)
        if ABS(a.threat-b.threat)<0.5 then return a.angle<b.angle end; return a.threat>b.threat end)
    elseif pri==5 then table.sort(tgts,function(a,b) return a.angle<b.angle end)
    end

    local chosen=tgts[1].player
    if pri==5 then Config.stickyTarget=chosen end
    return chosen
end

----------------------------------------------------------------
-- GET AIM POS  [v3.3 close-range prediction scaling]
----------------------------------------------------------------
local function getAimPos(plr)
    local c=plr.Character; if not c then return nil end
    local pos = getAimPartPos(c)
    if not pos then return nil end

    local predOffset = V3(0,0,0)
    if Config.smartPredict then
        predOffset = spPredict(plr, c)
    elseif Config.prediction then
        predOffset = simplePred(c)
    end

    -- [v3.3] scale prediction down at close range to prevent overshoot/spin
    if predOffset.Magnitude > 0.01 then
        local camPos = Camera.CFrame.Position
        local dist = (pos - camPos).Magnitude
        if dist < Config.closeRange then
            predOffset = predOffset * CLAMP(dist / Config.closeRange, 0.05, 1.0)
        end
        -- cap prediction to 40% of distance (prevents aim point behind player)
        local maxPred = MAX(dist * 0.4, 0.5)
        if predOffset.Magnitude > maxPred then
            predOffset = predOffset.Unit * maxPred
        end
    end

    return pos + predOffset
end

----------------------------------------------------------------
-- VISUALS
----------------------------------------------------------------
local FovCircle, CrossLines, CrossPhase = nil, {}, 0
local fovFrame, crossFrames = nil, {}

if Support.drawing then
    try(function()
        FovCircle=Drawing.new("Circle"); FovCircle.Color=Color3.fromRGB(145,145,175)
        FovCircle.Thickness=1.2; FovCircle.Filled=false; FovCircle.Transparency=0.4
        FovCircle.NumSides=56; FovCircle.Visible=false
    end)
    try(function()
        for i=1,4 do
            local ln=Drawing.new("Line"); ln.Color=Color3.fromRGB(175,175,195)
            ln.Thickness=2; ln.Visible=false; CrossLines[i]=ln
        end
    end)
end

try(function()
    local p=try(function() return gethui() end) or game:GetService("CoreGui")
    local old=p:FindFirstChild("AimbotV33"); if old then old:Destroy() end
end)

local Gui=Instance.new("ScreenGui"); Gui.Name="AimbotV33"; Gui.ResetOnSpawn=false
try(function() Gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling end)
if Support.syn then try(function() syn.protect_gui(Gui) end) end
if Support.protect then try(function() protect_gui(Gui) end) end

local guiP
if Support.gethui then guiP=try(function() return gethui() end) end
if not guiP then guiP=try(function() return game:GetService("CoreGui") end) end
if not guiP then guiP=LP:WaitForChild("PlayerGui") end
Gui.Parent=guiP

local function createFallback()
    if Support.drawing then return end
    fovFrame=Instance.new("Frame"); fovFrame.Name="Fov"
    fovFrame.BackgroundTransparency=1; fovFrame.BorderSizePixel=0
    fovFrame.AnchorPoint=Vector2.new(0.5,0.5); fovFrame.Visible=false; fovFrame.Parent=Gui
    try(function() local s=Instance.new("UIStroke"); s.Color=Color3.fromRGB(145,145,175); s.Thickness=1.2; s.Transparency=0.5; s.Parent=fovFrame end)
    try(function() local c=Instance.new("UICorner"); c.CornerRadius=UDim.new(0.5,0); c.Parent=fovFrame end)
    for i=1,4 do
        local ln=Instance.new("Frame"); ln.Name="C"..i; ln.BackgroundColor3=Color3.fromRGB(175,175,195)
        ln.BorderSizePixel=0; ln.Visible=false; ln.AnchorPoint=Vector2.new(0.5,0.5); ln.Parent=Gui
        crossFrames[i]=ln
    end
end
createFallback()

local function setFovVis(vis,radius)
    if Support.drawing and FovCircle then
        try(function() local vs=Camera.ViewportSize; FovCircle.Position=Vector2.new(vs.X/2,vs.Y/2)
            FovCircle.Radius=radius or 100; FovCircle.Visible=vis end)
    elseif fovFrame then
        local vs=Camera.ViewportSize; local r=radius or 100
        fovFrame.Size=UDim2.new(0,r*2,0,r*2); fovFrame.Position=UDim2.new(0,vs.X/2,0,vs.Y/2); fovFrame.Visible=vis
    end
end

local function setCrossVis(v)
    if Support.drawing then for _,ln in ipairs(CrossLines) do try(function() ln.Visible=v end) end
    else for _,fr in ipairs(crossFrames) do try(function() fr.Visible=v end) end end
end

local function updateCross(sx,sy)
    CrossPhase=CrossPhase+0.04
    local w=SIN(CrossPhase*1.7)
    local b=135+FLOOR(w*48); local p=195+FLOOR(w*55)
    local c1=Color3.fromRGB(b,b,b+12); local c2=Color3.fromRGB(p,p,p+8)
    local sz,gp=Config.crossSize,Config.crossGap
    if Support.drawing then
        if #CrossLines<4 then return end
        try(function() CrossLines[1].From=Vector2.new(sx,sy-gp); CrossLines[1].To=Vector2.new(sx,sy-gp-sz); CrossLines[1].Color=c2 end)
        try(function() CrossLines[2].From=Vector2.new(sx,sy+gp); CrossLines[2].To=Vector2.new(sx,sy+gp+sz); CrossLines[2].Color=c1 end)
        try(function() CrossLines[3].From=Vector2.new(sx-gp,sy); CrossLines[3].To=Vector2.new(sx-gp-sz,sy); CrossLines[3].Color=c1 end)
        try(function() CrossLines[4].From=Vector2.new(sx+gp,sy); CrossLines[4].To=Vector2.new(sx+gp+sz,sy); CrossLines[4].Color=c2 end)
    else
        if #crossFrames<4 then return end
        try(function() crossFrames[1].Size=UDim2.new(0,2,0,sz); crossFrames[1].Position=UDim2.new(0,sx,0,sy-gp-sz/2); crossFrames[1].BackgroundColor3=c2; crossFrames[1].Visible=true end)
        try(function() crossFrames[2].Size=UDim2.new(0,2,0,sz); crossFrames[2].Position=UDim2.new(0,sx,0,sy+gp+sz/2); crossFrames[2].BackgroundColor3=c1; crossFrames[2].Visible=true end)
        try(function() crossFrames[3].Size=UDim2.new(0,sz,0,2); crossFrames[3].Position=UDim2.new(0,sx-gp-sz/2,0,sy); crossFrames[3].BackgroundColor3=c1; crossFrames[3].Visible=true end)
        try(function() crossFrames[4].Size=UDim2.new(0,sz,0,2); crossFrames[4].Position=UDim2.new(0,sx+gp+sz/2,0,sy); crossFrames[4].BackgroundColor3=c2; crossFrames[4].Visible=true end)
    end
end

----------------------------------------------------------------
-- UI HELPERS
----------------------------------------------------------------
local function corner(p,r) try(function() local c=Instance.new("UICorner"); c.CornerRadius=UDim.new(0,r or 8); c.Parent=p end) end
local function shimmer(p) try(function()
    local g=Instance.new("UIGradient")
    g.Color=ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.fromRGB(15,15,20)),ColorSequenceKeypoint.new(0.35,Color3.fromRGB(15,15,20)),ColorSequenceKeypoint.new(0.48,Color3.fromRGB(50,50,68)),ColorSequenceKeypoint.new(0.50,Color3.fromRGB(125,125,150)),ColorSequenceKeypoint.new(0.52,Color3.fromRGB(50,50,68)),ColorSequenceKeypoint.new(0.65,Color3.fromRGB(15,15,20)),ColorSequenceKeypoint.new(1,Color3.fromRGB(15,15,20))})
    g.Rotation=25; g.Offset=Vector2.new(-1.5,0); g.Parent=p
    local tw=TweenService:Create(g,TweenInfo.new(3.5,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut,-1,true),{Offset=Vector2.new(1.5,0)})
    tw:Play(); table.insert(GC.tweens,tw)
end) end
local function glowS(p) try(function()
    local s=Instance.new("UIStroke"); s.Thickness=1.2; s.Color=Color3.fromRGB(55,55,75); s.Parent=p
    safeSpawn(function() local ph=0; while s and s.Parent do ph=ph+0.025; local v=0.22+0.1*SIN(ph*1.3)
        s.Color=Color3.fromRGB(FLOOR(v*255),FLOOR(v*255),FLOOR((v+0.04)*255)); RunService.Heartbeat:Wait() end end)
end) end

local function drag(frame,handle)
    handle=handle or frame; local dr,di,ds,sp
    handle.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then
        dr=true; ds=i.Position; sp=frame.Position; i.Changed:Connect(function() if i.UserInputState==Enum.UserInputState.End then dr=false end end) end end)
    handle.InputChanged:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseMovement or i.UserInputType==Enum.UserInputType.Touch then di=i end end)
    UserInput.InputChanged:Connect(function(i) if i==di and dr then local d=i.Position-ds
        frame.Position=UDim2.new(sp.X.Scale,sp.X.Offset+d.X,sp.Y.Scale,sp.Y.Offset+d.Y) end end)
end

local function hBtn(btn,base,hov) try(function()
    btn.MouseEnter:Connect(function() TweenService:Create(btn,TweenInfo.new(0.12),{BackgroundColor3=hov}):Play() end)
    btn.MouseLeave:Connect(function() TweenService:Create(btn,TweenInfo.new(0.12),{BackgroundColor3=base}):Play() end)
end) end

----------------------------------------------------------------
-- UI COMPONENTS
----------------------------------------------------------------
local function uiToggle(par,text,def,cb,ord)
    local f=Instance.new("Frame"); f.Size=UDim2.new(1,0,0,36); f.BackgroundColor3=Color3.fromRGB(22,22,30)
    f.BorderSizePixel=0; f.LayoutOrder=ord or 0; f.Parent=par; corner(f,7)
    local lb=Instance.new("TextLabel"); lb.BackgroundTransparency=1; lb.Size=UDim2.new(0.64,-10,1,0)
    lb.Position=UDim2.new(0,12,0,0); lb.Font=Enum.Font.GothamSemibold; lb.TextColor3=Color3.fromRGB(220,220,230)
    lb.TextSize=13; lb.TextXAlignment=Enum.TextXAlignment.Left; lb.Text=text; lb.Parent=f
    local tr=Instance.new("Frame"); tr.Size=UDim2.new(0,40,0,20); tr.Position=UDim2.new(1,-52,0.5,-10)
    tr.BackgroundColor3=def and Color3.fromRGB(60,148,98) or Color3.fromRGB(46,46,58); tr.BorderSizePixel=0; tr.Parent=f; corner(tr,10)
    local kn=Instance.new("Frame"); kn.Size=UDim2.new(0,16,0,16)
    kn.Position=def and UDim2.new(1,-18,0.5,-8) or UDim2.new(0,2,0.5,-8)
    kn.BackgroundColor3=Color3.fromRGB(240,240,246); kn.BorderSizePixel=0; kn.Parent=tr; corner(kn,8)
    local state=def
    local function sync(v) state=v; try(function()
        TweenService:Create(tr,TweenInfo.new(0.18),{BackgroundColor3=v and Color3.fromRGB(60,148,98) or Color3.fromRGB(46,46,58)}):Play()
        TweenService:Create(kn,TweenInfo.new(0.18,Enum.EasingStyle.Quart),{Position=v and UDim2.new(1,-18,0.5,-8) or UDim2.new(0,2,0.5,-8)}):Play()
    end) end
    local btn=Instance.new("TextButton"); btn.BackgroundTransparency=1; btn.Size=UDim2.new(1,0,1,0); btn.Text=""; btn.Parent=f
    btn.MouseButton1Click:Connect(function() state=not state; sync(state); if cb then cb(state) end end)
    return f,lb,sync
end

local function uiSlider(par,text,mn,mx,def,dec,cb,ord)
    local f=Instance.new("Frame"); f.Size=UDim2.new(1,0,0,50); f.BackgroundColor3=Color3.fromRGB(22,22,30)
    f.BorderSizePixel=0; f.LayoutOrder=ord or 0; f.Parent=par; corner(f,7)
    local lb=Instance.new("TextLabel"); lb.BackgroundTransparency=1; lb.Size=UDim2.new(0.55,-8,0,22)
    lb.Position=UDim2.new(0,12,0,2); lb.Font=Enum.Font.GothamSemibold; lb.TextColor3=Color3.fromRGB(220,220,230)
    lb.TextSize=13; lb.TextXAlignment=Enum.TextXAlignment.Left; lb.Text=text; lb.Parent=f
    local vl=Instance.new("TextLabel"); vl.BackgroundTransparency=1; vl.Size=UDim2.new(0.45,-12,0,22)
    vl.Position=UDim2.new(0.55,0,0,2); vl.Font=Enum.Font.GothamSemibold; vl.TextColor3=Color3.fromRGB(148,148,170)
    vl.TextSize=13; vl.TextXAlignment=Enum.TextXAlignment.Right; vl.Text=tostring(def); vl.Parent=f
    local bar=Instance.new("Frame"); bar.Size=UDim2.new(1,-24,0,6); bar.Position=UDim2.new(0,12,0,32)
    bar.BackgroundColor3=Color3.fromRGB(34,34,44); bar.BorderSizePixel=0; bar.Parent=f; corner(bar,3)
    local pct=CLAMP((def-mn)/(mx-mn),0,1)
    local fill=Instance.new("Frame"); fill.Size=UDim2.new(pct,0,1,0); fill.BackgroundColor3=Color3.fromRGB(88,88,140)
    fill.BorderSizePixel=0; fill.Parent=bar; corner(fill,3)
    local hd=Instance.new("Frame"); hd.Size=UDim2.new(0,14,0,14); hd.Position=UDim2.new(pct,-7,0.5,-7)
    hd.BackgroundColor3=Color3.fromRGB(180,180,205); hd.BorderSizePixel=0; hd.ZIndex=3; hd.Parent=bar; corner(hd,7)
    local sliding=false
    local function apply(input)
        local rel=CLAMP((input.Position.X-bar.AbsolutePosition.X)/bar.AbsoluteSize.X,0,1)
        local val=mn+(mx-mn)*rel
        if dec then val=FLOOR(val*10^dec+0.5)/10^dec else val=FLOOR(val+0.5) end
        local np=CLAMP((val-mn)/(mx-mn),0,1)
        fill.Size=UDim2.new(np,0,1,0); hd.Position=UDim2.new(np,-7,0.5,-7)
        vl.Text=tostring(val); if cb then cb(val) end
    end
    bar.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then sliding=true; apply(i) end end)
    bar.InputEnded:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then sliding=false end end)
    UserInput.InputChanged:Connect(function(i) if sliding and (i.UserInputType==Enum.UserInputType.MouseMovement or i.UserInputType==Enum.UserInputType.Touch) then apply(i) end end)
    return f,lb,vl
end

local function uiHeader(par,text,ord)
    local f=Instance.new("Frame"); f.Size=UDim2.new(1,0,0,28); f.BackgroundColor3=Color3.fromRGB(18,18,24)
    f.BorderSizePixel=0; f.LayoutOrder=ord or 0; f.Parent=par; corner(f,6)
    local line=Instance.new("Frame"); line.Size=UDim2.new(0,3,0,16); line.Position=UDim2.new(0,8,0.5,-8)
    line.BackgroundColor3=Color3.fromRGB(100,100,145); line.BorderSizePixel=0; line.Parent=f; corner(line,2)
    local lb=Instance.new("TextLabel"); lb.BackgroundTransparency=1; lb.Size=UDim2.new(1,-20,1,0)
    lb.Position=UDim2.new(0,18,0,0); lb.Font=Enum.Font.GothamBold; lb.TextColor3=Color3.fromRGB(165,165,195)
    lb.TextSize=12; lb.TextXAlignment=Enum.TextXAlignment.Left; lb.Text=string.upper(text); lb.Parent=f
    return f,lb
end

local function uiPingInfo(par, ord)
    local f=Instance.new("Frame"); f.Size=UDim2.new(1,0,0,24); f.BackgroundColor3=Color3.fromRGB(18,18,24)
    f.BorderSizePixel=0; f.LayoutOrder=ord or 0; f.Parent=par; corner(f,5)
    local lb=Instance.new("TextLabel"); lb.BackgroundTransparency=1; lb.Size=UDim2.new(1,-16,1,0)
    lb.Position=UDim2.new(0,8,0,0); lb.Font=Enum.Font.Gotham; lb.TextColor3=Color3.fromRGB(110,180,130)
    lb.TextSize=11; lb.TextXAlignment=Enum.TextXAlignment.Left
    lb.Text=string.format(t("pingInfo"), FLOOR(cachedPing*1000), pingMethod); lb.Parent=f
    safeSpawn(function() while lb and lb.Parent do
        try(function() lb.Text=string.format(t("pingInfo"), FLOOR(cachedPing*1000), pingMethod) end)
        safeWait(1) end end)
    return f
end

local function uiPriority(par,mob,ord)
    local container=Instance.new("Frame"); container.Size=UDim2.new(1,0,0,0)
    container.BackgroundTransparency=1; container.BorderSizePixel=0; container.LayoutOrder=ord
    if Support.autoSize then try(function() container.AutomaticSize=Enum.AutomaticSize.Y end) end
    container.Parent=par
    local lay=Instance.new("UIListLayout"); lay.SortOrder=Enum.SortOrder.LayoutOrder; lay.Padding=UDim.new(0,3); lay.Parent=container
    if not Support.autoSize then lay:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        container.Size=UDim2.new(1,0,0,lay.AbsoluteContentSize.Y) end) end
    local selC=Color3.fromRGB(55,110,85); local unC=Color3.fromRGB(28,28,38)
    local selH=Color3.fromRGB(62,125,95); local unH=Color3.fromRGB(38,38,52)
    local descK={"priDesc1","priDesc2","priDesc3","priDesc4","priDesc5"}
    local btns={}
    for idx,pri in ipairs(PRIORITIES) do
        local h=mob and 48 or 40
        local f=Instance.new("TextButton"); f.Size=UDim2.new(1,0,0,h)
        f.BackgroundColor3=Config.priority==pri.id and selC or unC; f.BorderSizePixel=0
        f.Font=Enum.Font.GothamBold; f.TextColor3=Color3.fromRGB(235,235,248)
        f.TextSize=mob and 13 or 12; f.TextXAlignment=Enum.TextXAlignment.Left
        f.AutoButtonColor=false; f.LayoutOrder=idx; f.Parent=container; corner(f,7)
        try(function() local tp=Instance.new("UIPadding"); tp.PaddingLeft=UDim.new(0,14); tp.Parent=f end)
        f.Text=Config.lang=="ru" and pri.ru or pri.en
        local desc=Instance.new("TextLabel"); desc.BackgroundTransparency=1
        desc.Size=UDim2.new(1,-28,0,12); desc.Position=UDim2.new(0,14,1,-15)
        desc.Font=Enum.Font.Gotham; desc.TextColor3=Color3.fromRGB(120,120,145)
        desc.TextSize=9; desc.TextXAlignment=Enum.TextXAlignment.Left; desc.Text=t(descK[idx]); desc.Parent=f
        local ind=Instance.new("Frame"); ind.Size=UDim2.new(0,4,0,h-14)
        ind.Position=UDim2.new(1,-18,0.5,-(h-14)/2)
        ind.BackgroundColor3=Config.priority==pri.id and Color3.fromRGB(100,210,140) or Color3.fromRGB(50,50,65)
        ind.BorderSizePixel=0; ind.Parent=f; corner(ind,2)
        btns[idx]={btn=f,ind=ind,pri=pri}
        f.MouseButton1Click:Connect(function() Config.priority=pri.id; Config.stickyTarget=nil
            for _,b in ipairs(btns) do local isSel=Config.priority==b.pri.id; try(function()
                TweenService:Create(b.btn,TweenInfo.new(0.15),{BackgroundColor3=isSel and selC or unC}):Play()
                TweenService:Create(b.ind,TweenInfo.new(0.15),{BackgroundColor3=isSel and Color3.fromRGB(100,210,140) or Color3.fromRGB(50,50,65)}):Play()
            end) end end)
        hBtn(f,Config.priority==pri.id and selC or unC,Config.priority==pri.id and selH or unH)
    end; return container
end

local function uiAimPart(par,mob,ord)
    local con=Instance.new("Frame"); con.Size=UDim2.new(1,0,0,0)
    con.BackgroundTransparency=1; con.BorderSizePixel=0; con.LayoutOrder=ord
    if Support.autoSize then try(function() con.AutomaticSize=Enum.AutomaticSize.Y end) end
    con.Parent=par
    local lay=Instance.new("UIListLayout"); lay.SortOrder=Enum.SortOrder.LayoutOrder; lay.Padding=UDim.new(0,3); lay.Parent=con
    if not Support.autoSize then lay:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        con.Size=UDim2.new(1,0,0,lay.AbsoluteContentSize.Y) end) end
    local sC=Color3.fromRGB(55,100,120); local uC=Color3.fromRGB(28,28,38)
    local sH=Color3.fromRGB(62,115,135); local uH=Color3.fromRGB(38,38,52)
    local btns={}
    for idx,ap in ipairs(AIM_PARTS) do
        local h=mob and 36 or 30
        local f=Instance.new("TextButton"); f.Size=UDim2.new(1,0,0,h)
        f.BackgroundColor3=Config.aimPart==ap.id and sC or uC; f.BorderSizePixel=0
        f.Font=Enum.Font.GothamBold; f.TextColor3=Color3.fromRGB(235,235,248)
        f.TextSize=mob and 13 or 12; f.TextXAlignment=Enum.TextXAlignment.Left
        f.AutoButtonColor=false; f.LayoutOrder=idx; f.Parent=con; corner(f,6)
        try(function() local tp=Instance.new("UIPadding"); tp.PaddingLeft=UDim.new(0,12); tp.Parent=f end)
        f.Text=Config.lang=="ru" and ap.ru or ap.en
        local ind=Instance.new("Frame"); ind.Size=UDim2.new(0,4,0,h-10)
        ind.Position=UDim2.new(1,-14,0.5,-(h-10)/2)
        ind.BackgroundColor3=Config.aimPart==ap.id and Color3.fromRGB(100,190,210) or Color3.fromRGB(50,50,65)
        ind.BorderSizePixel=0; ind.Parent=f; corner(ind,2)
        btns[idx]={btn=f,ind=ind,ap=ap}
        f.MouseButton1Click:Connect(function() Config.aimPart=ap.id
            for _,b in ipairs(btns) do local sel=Config.aimPart==b.ap.id; try(function()
                TweenService:Create(b.btn,TweenInfo.new(0.15),{BackgroundColor3=sel and sC or uC}):Play()
                TweenService:Create(b.ind,TweenInfo.new(0.15),{BackgroundColor3=sel and Color3.fromRGB(100,190,210) or Color3.fromRGB(50,50,65)}):Play()
            end) end end)
        hBtn(f,Config.aimPart==ap.id and sC or uC,Config.aimPart==ap.id and sH or uH)
    end; return con
end

----------------------------------------------------------------
-- REFS
----------------------------------------------------------------
local selScreen,mainPanel,showBtn,mobBtn
local activeSync,friendsCon,friendUpd

local function destroyAll()
    for _,c in pairs(GC.conn) do try(function() c:Disconnect() end) end
    for _,tw in pairs(GC.tweens) do try(function() tw:Cancel() end) end
    try(function() RunService:UnbindFromRenderStep("AimbotV32") end)
    if Support.drawing then
        try(function() if FovCircle then FovCircle:Remove() end end)
        for _,ln in ipairs(CrossLines) do try(function() ln:Remove() end) end
    end
    try(function() if mobBtn then mobBtn:Destroy() end end)
    try(function() if showBtn then showBtn:Destroy() end end)
    SPData={}; ThreatData={}; Gui:Destroy()
    try(function() env._AimbotV32=false end)
end

----------------------------------------------------------------
-- SELECTION
----------------------------------------------------------------
local function buildSelect()
    selScreen=Instance.new("Frame"); selScreen.Size=UDim2.new(0,340,0,240)
    selScreen.Position=UDim2.new(0.5,-170,0.5,-120); selScreen.BackgroundColor3=Color3.fromRGB(15,15,20)
    selScreen.BorderSizePixel=0; selScreen.Parent=Gui
    corner(selScreen,14); shimmer(selScreen); glowS(selScreen); drag(selScreen)
    local ti=Instance.new("TextLabel"); ti.BackgroundTransparency=1; ti.Size=UDim2.new(1,0,0,40)
    ti.Position=UDim2.new(0,0,0,28); ti.Font=Enum.Font.GothamBold; ti.TextColor3=Color3.fromRGB(235,235,248)
    ti.TextSize=21; ti.Text=t("choose"); ti.Parent=selScreen
    local lg=Instance.new("TextButton"); lg.Size=UDim2.new(0,44,0,24); lg.Position=UDim2.new(1,-56,0,10)
    lg.BackgroundColor3=Color3.fromRGB(35,35,48); lg.BorderSizePixel=0; lg.Font=Enum.Font.GothamBold
    lg.TextColor3=Color3.fromRGB(195,195,215); lg.TextSize=11; lg.Text=t("langSwitch"); lg.Parent=selScreen
    corner(lg,6); hBtn(lg,Color3.fromRGB(35,35,48),Color3.fromRGB(50,50,65))
    lg.MouseButton1Click:Connect(function() Config.lang=Config.lang=="en" and "ru" or "en"; selScreen:Destroy(); buildSelect() end)
    local bb=Color3.fromRGB(55,55,74); local bh=Color3.fromRGB(72,72,94)
    local pcb=Instance.new("TextButton"); pcb.Size=UDim2.new(0,130,0,52); pcb.Position=UDim2.new(0.5,-140,0,98)
    pcb.BackgroundColor3=bb; pcb.BorderSizePixel=0; pcb.Font=Enum.Font.GothamBold
    pcb.TextColor3=Color3.fromRGB(240,240,255); pcb.TextSize=17; pcb.Text=t("pc"); pcb.Parent=selScreen
    corner(pcb,10); hBtn(pcb,bb,bh)
    pcb.MouseButton1Click:Connect(function() Config.platform="pc"; selScreen:Destroy(); buildMain() end)
    local mb=Instance.new("TextButton"); mb.Size=UDim2.new(0,130,0,52); mb.Position=UDim2.new(0.5,10,0,98)
    mb.BackgroundColor3=bb; mb.BorderSizePixel=0; mb.Font=Enum.Font.GothamBold
    mb.TextColor3=Color3.fromRGB(240,240,255); mb.TextSize=17; mb.Text=t("mobile"); mb.Parent=selScreen
    corner(mb,10); hBtn(mb,bb,bh)
    mb.MouseButton1Click:Connect(function() Config.platform="mobile"; selScreen:Destroy(); buildMain() end)
    local vr=Instance.new("TextLabel"); vr.BackgroundTransparency=1; vr.Size=UDim2.new(1,0,0,18)
    vr.Position=UDim2.new(0,0,1,-28); vr.Font=Enum.Font.Gotham; vr.TextColor3=Color3.fromRGB(65,65,82)
    vr.TextSize=10; vr.Text="Aimbot v3.3"; vr.Parent=selScreen
end

----------------------------------------------------------------
-- FRIENDS
----------------------------------------------------------------
local function buildFE(par,pn,mob,ord)
    local fr=isFriend(pn); local h=mob and 40 or 34
    local f=Instance.new("Frame"); f.Size=UDim2.new(1,0,0,h)
    f.BackgroundColor3=fr and Color3.fromRGB(28,52,38) or Color3.fromRGB(26,26,34)
    f.BorderSizePixel=0; f.LayoutOrder=ord; f.Parent=par; corner(f,6)
    local nm=Instance.new("TextLabel"); nm.BackgroundTransparency=1; nm.Size=UDim2.new(0.55,-6,1,0)
    nm.Position=UDim2.new(0,10,0,0); nm.Font=Enum.Font.GothamSemibold; nm.TextColor3=Color3.fromRGB(210,210,225)
    nm.TextSize=mob and 13 or 12; nm.TextXAlignment=Enum.TextXAlignment.Left
    try(function() nm.TextTruncate=Enum.TextTruncate.AtEnd end); nm.Text=pn; nm.Parent=f
    local bE=Color3.fromRGB(58,42,42); local bF=Color3.fromRGB(48,128,78)
    local badge=Instance.new("TextButton"); badge.Size=UDim2.new(0,mob and 80 or 68,0,mob and 26 or 22)
    badge.Position=UDim2.new(1,mob and -88 or -76,0.5,mob and -13 or -11)
    badge.BackgroundColor3=fr and bF or bE; badge.BorderSizePixel=0; badge.Font=Enum.Font.GothamBold
    badge.TextColor3=Color3.fromRGB(240,240,248); badge.TextSize=mob and 11 or 10
    badge.Text=fr and t("friend") or t("enemy"); badge.Parent=f; corner(badge,mob and 6 or 5)
    badge.MouseButton1Click:Connect(function()
        local nf=toggleFriend(pn)
        try(function()
            TweenService:Create(f,TweenInfo.new(0.2),{BackgroundColor3=nf and Color3.fromRGB(28,52,38) or Color3.fromRGB(26,26,34)}):Play()
            TweenService:Create(badge,TweenInfo.new(0.2),{BackgroundColor3=nf and bF or bE}):Play()
        end); badge.Text=nf and t("friend") or t("enemy")
    end)
    hBtn(badge,fr and bF or bE,fr and Color3.fromRGB(58,148,92) or Color3.fromRGB(75,52,52))
end

local function refreshFL(c,mob)
    if not c or not c.Parent then return end
    for _,ch in ipairs(c:GetChildren()) do if ch:IsA("Frame") or ch:IsA("TextLabel") then ch:Destroy() end end
    local o=0
    for _,p in ipairs(Players:GetPlayers()) do if p~=LP then o=o+1; buildFE(c,p.Name,mob,o) end end
    if o==0 then local e=Instance.new("TextLabel"); e.Size=UDim2.new(1,0,0,30); e.BackgroundTransparency=1
        e.Font=Enum.Font.Gotham; e.TextColor3=Color3.fromRGB(95,95,115); e.TextSize=12; e.Text=t("noPlayers"); e.Parent=c end
end

----------------------------------------------------------------
-- MAIN
----------------------------------------------------------------
function buildMain()
    local mob=Config.platform=="mobile"
    local W=mob and 300 or 265; local H=mob and 580 or 540

    mainPanel=Instance.new("Frame"); mainPanel.Size=UDim2.new(0,W,0,H)
    mainPanel.Position=mob and UDim2.new(0.5,-W/2,0.03,0) or UDim2.new(1,-W-14,1,-H-14)
    mainPanel.BackgroundColor3=Color3.fromRGB(15,15,20); mainPanel.BorderSizePixel=0; mainPanel.Parent=Gui
    corner(mainPanel,12); shimmer(mainPanel); glowS(mainPanel)

    local tb=Instance.new("Frame"); tb.Size=UDim2.new(1,0,0,36); tb.BackgroundColor3=Color3.fromRGB(18,18,25)
    tb.BorderSizePixel=0; tb.Parent=mainPanel; corner(tb,12)
    local tbf=Instance.new("Frame"); tbf.Size=UDim2.new(1,0,0,12); tbf.Position=UDim2.new(0,0,1,-12)
    tbf.BackgroundColor3=Color3.fromRGB(18,18,25); tbf.BorderSizePixel=0; tbf.Parent=tb
    local ttl=Instance.new("TextLabel"); ttl.BackgroundTransparency=1; ttl.Size=UDim2.new(0.55,0,1,0)
    ttl.Position=UDim2.new(0,14,0,0); ttl.Font=Enum.Font.GothamBold; ttl.TextColor3=Color3.fromRGB(230,230,242)
    ttl.TextSize=15; ttl.TextXAlignment=Enum.TextXAlignment.Left; ttl.Text=t("title"); ttl.Parent=tb
    drag(mainPanel,tb)

    local clB=Color3.fromRGB(135,34,34)
    local cl=Instance.new("TextButton"); cl.Size=UDim2.new(0,26,0,26); cl.Position=UDim2.new(1,-32,0,5)
    cl.BackgroundColor3=clB; cl.BorderSizePixel=0; cl.Font=Enum.Font.GothamBold
    cl.TextColor3=Color3.fromRGB(255,255,255); cl.TextSize=12; cl.Text="X"; cl.Parent=tb
    corner(cl,6); hBtn(cl,clB,Color3.fromRGB(170,48,48)); cl.MouseButton1Click:Connect(destroyAll)

    local hiB=Color3.fromRGB(40,40,55)
    local hi=Instance.new("TextButton"); hi.Size=UDim2.new(0,26,0,26); hi.Position=UDim2.new(1,-62,0,5)
    hi.BackgroundColor3=hiB; hi.BorderSizePixel=0; hi.Font=Enum.Font.GothamBold
    hi.TextColor3=Color3.fromRGB(220,220,235); hi.TextSize=14; hi.Text="-"; hi.Parent=tb
    corner(hi,6); hBtn(hi,hiB,Color3.fromRGB(56,56,74))
    hi.MouseButton1Click:Connect(function() mainPanel.Visible=false; if showBtn then showBtn.Visible=true end end)

    local sc=Instance.new("ScrollingFrame"); sc.Size=UDim2.new(1,-6,1,-42); sc.Position=UDim2.new(0,3,0,40)
    sc.BackgroundTransparency=1; sc.BorderSizePixel=0; sc.ScrollBarThickness=2
    sc.ScrollBarImageColor3=Color3.fromRGB(80,80,105); sc.CanvasSize=UDim2.new(0,0,0,0); sc.Parent=mainPanel
    local lay=Instance.new("UIListLayout"); lay.SortOrder=Enum.SortOrder.LayoutOrder; lay.Padding=UDim.new(0,4); lay.Parent=sc
    local pad=Instance.new("UIPadding"); pad.PaddingLeft=UDim.new(0,3); pad.PaddingRight=UDim.new(0,3); pad.PaddingTop=UDim.new(0,3); pad.Parent=sc
    lay:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        sc.CanvasSize=UDim2.new(0,0,0,lay.AbsoluteContentSize.Y+10) end)

    local n=0; local function nx() n=n+1; return n end

    uiHeader(sc,t("title"),nx())
    local _,_,aSync=uiToggle(sc,t("active"),Config.active,function(v)
        Config.active=v; Config.stickyTarget=nil
        if mobBtn then mobBtn.Text=v and t("aimOn") or t("aimOff")
            try(function() TweenService:Create(mobBtn,TweenInfo.new(0.14),{
                BackgroundColor3=v and Color3.fromRGB(44,118,76) or Color3.fromRGB(32,32,44)}):Play() end)
        end
    end,nx()); activeSync=aSync

    uiSlider(sc,t("fov"),0,360,Config.fov,0,function(v) Config.fov=v end,nx())
    uiToggle(sc,t("showFov"),Config.showFov,function(v) Config.showFov=v end,nx())
    uiToggle(sc,t("showCross"),Config.showCross,function(v) Config.showCross=v end,nx())

    -- AIM PART
    uiHeader(sc,t("aimPart"),nx())
    uiAimPart(sc,mob,nx())

    -- PREDICTION
    uiHeader(sc,"PREDICTION",nx())
    uiToggle(sc,t("smartPred"),Config.smartPredict,function(v) Config.smartPredict=v end,nx())
    uiToggle(sc,t("autoPing"),Config.autoPing,function(v) Config.autoPing=v end,nx())
    uiPingInfo(sc,nx())
    uiToggle(sc,t("prediction"),Config.prediction,function(v) Config.prediction=v end,nx())
    uiSlider(sc,t("predValue"),0,0.3,Config.predValue,3,function(v) Config.predValue=v end,nx())

    -- AIM
    uiHeader(sc,"AIM",nx())
    uiToggle(sc,t("humanLike"),Config.humanLike,function(v) Config.humanLike=v end,nx())
    uiSlider(sc,t("aimSpeed"),0.05,1.0,Config.aimSpeed,2,function(v) Config.aimSpeed=v end,nx())

    if not mob then
        local kf=Instance.new("Frame"); kf.Size=UDim2.new(1,0,0,36); kf.BackgroundColor3=Color3.fromRGB(22,22,30)
        kf.BorderSizePixel=0; kf.LayoutOrder=nx(); kf.Parent=sc; corner(kf,7)
        local kl=Instance.new("TextLabel"); kl.BackgroundTransparency=1; kl.Size=UDim2.new(0.5,-8,1,0)
        kl.Position=UDim2.new(0,12,0,0); kl.Font=Enum.Font.GothamSemibold; kl.TextColor3=Color3.fromRGB(220,220,230)
        kl.TextSize=13; kl.TextXAlignment=Enum.TextXAlignment.Left; kl.Text=t("keybind"); kl.Parent=kf
        local kbB=Color3.fromRGB(35,35,48)
        local kb=Instance.new("TextButton"); kb.Size=UDim2.new(0.42,-6,0,24); kb.Position=UDim2.new(0.58,0,0.5,-12)
        kb.BackgroundColor3=kbB; kb.BorderSizePixel=0; kb.Font=Enum.Font.GothamSemibold
        kb.TextColor3=Color3.fromRGB(182,182,208); kb.TextSize=12; kb.Text=Config.keybind.Name; kb.Parent=kf
        corner(kb,5); hBtn(kb,kbB,Color3.fromRGB(48,48,65))
        kb.MouseButton1Click:Connect(function()
            Config.waitingBind=true; kb.Text=t("pressKey")
            local cn; cn=UserInput.InputBegan:Connect(function(inp,gpe)
                if gpe then return end
                if inp.UserInputType==Enum.UserInputType.Keyboard then
                    Config.keybind=inp.KeyCode; kb.Text=inp.KeyCode.Name
                    Config.waitingBind=false; cn:Disconnect()
                end end) end)
    end

    -- [v3.3] ANTI-SPIN SECTION
    uiHeader(sc,t("antiSpin"),nx())
    uiSlider(sc,t("maxTurn"),3,30,Config.maxTurnDeg,0,function(v) Config.maxTurnDeg=v end,nx())
    uiSlider(sc,t("closeRange"),3,25,Config.closeRange,0,function(v) Config.closeRange=v end,nx())

    uiHeader(sc,t("priority"),nx())
    uiPriority(sc,mob,nx())
    uiSlider(sc,t("stickyBreak"),5,100,Config.stickyBreak,0,function(v) Config.stickyBreak=v end,nx())

    uiHeader(sc,t("friends"),nx())
    local hint=Instance.new("TextLabel"); hint.Size=UDim2.new(1,0,0,20); hint.BackgroundTransparency=1
    hint.Font=Enum.Font.Gotham; hint.TextColor3=Color3.fromRGB(90,90,112); hint.TextSize=11
    hint.Text=t("addFriend"); hint.LayoutOrder=nx(); hint.Parent=sc

    friendsCon=Instance.new("Frame"); friendsCon.Size=UDim2.new(1,0,0,0)
    friendsCon.BackgroundTransparency=1; friendsCon.BorderSizePixel=0; friendsCon.LayoutOrder=nx()
    if Support.autoSize then try(function() friendsCon.AutomaticSize=Enum.AutomaticSize.Y end) end
    friendsCon.Parent=sc
    local fLay=Instance.new("UIListLayout"); fLay.SortOrder=Enum.SortOrder.LayoutOrder; fLay.Padding=UDim.new(0,3); fLay.Parent=friendsCon
    if not Support.autoSize then fLay:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        friendsCon.Size=UDim2.new(1,0,0,fLay.AbsoluteContentSize.Y) end) end
    refreshFL(friendsCon,mob)
    friendUpd=function() refreshFL(friendsCon,mob) end

    table.insert(GC.conn,Players.PlayerAdded:Connect(function() safeWait(0.5); if friendUpd then friendUpd() end end))
    table.insert(GC.conn,Players.PlayerRemoving:Connect(function(p)
        SPData[p]=nil; ThreatData[p.Name]=nil; safeWait(0.3); if friendUpd then friendUpd() end end))

    local lsB=Color3.fromRGB(28,28,38)
    local ls=Instance.new("TextButton"); ls.Size=UDim2.new(1,0,0,32); ls.BackgroundColor3=lsB
    ls.BorderSizePixel=0; ls.Font=Enum.Font.GothamSemibold; ls.TextColor3=Color3.fromRGB(190,190,212)
    ls.TextSize=13; ls.Text=t("langSwitch"); ls.LayoutOrder=nx(); ls.Parent=sc; corner(ls,7)
    hBtn(ls,lsB,Color3.fromRGB(42,42,58))
    ls.MouseButton1Click:Connect(function()
        Config.lang=Config.lang=="en" and "ru" or "en"; mainPanel:Destroy()
        if showBtn then showBtn:Destroy(); showBtn=nil end
        if mobBtn then mobBtn:Destroy(); mobBtn=nil end; buildMain() end)

    showBtn=Instance.new("TextButton"); showBtn.Size=UDim2.new(0,36,0,36)
    showBtn.Position=mob and UDim2.new(1,-46,0,38) or UDim2.new(1,-46,1,-46)
    showBtn.BackgroundColor3=Color3.fromRGB(20,20,30); showBtn.BorderSizePixel=0
    showBtn.Font=Enum.Font.GothamBold; showBtn.TextColor3=Color3.fromRGB(210,210,230)
    showBtn.TextSize=14; showBtn.Text="A"; showBtn.Visible=false; showBtn.Parent=Gui
    corner(showBtn,18); glowS(showBtn)
    showBtn.MouseButton1Click:Connect(function() mainPanel.Visible=true; showBtn.Visible=false end)

    if mob then
        mobBtn=Instance.new("TextButton"); mobBtn.Size=UDim2.new(0,100,0,40); mobBtn.Position=UDim2.new(0,12,1,-54)
        mobBtn.BackgroundColor3=Config.active and Color3.fromRGB(44,118,76) or Color3.fromRGB(32,32,44)
        mobBtn.BorderSizePixel=0; mobBtn.Font=Enum.Font.GothamBold; mobBtn.TextColor3=Color3.fromRGB(225,225,240)
        mobBtn.TextSize=14; mobBtn.Text=Config.active and t("aimOn") or t("aimOff"); mobBtn.Parent=Gui
        corner(mobBtn,8); glowS(mobBtn)
        mobBtn.MouseButton1Click:Connect(function()
            Config.active=not Config.active; Config.stickyTarget=nil
            mobBtn.Text=Config.active and t("aimOn") or t("aimOff")
            try(function() TweenService:Create(mobBtn,TweenInfo.new(0.14),{
                BackgroundColor3=Config.active and Color3.fromRGB(44,118,76) or Color3.fromRGB(32,32,44)}):Play() end)
            if activeSync then activeSync(Config.active) end end)
    end
end

----------------------------------------------------------------
-- KEYBIND
----------------------------------------------------------------
table.insert(GC.conn,UserInput.InputBegan:Connect(function(input,gpe)
    if gpe or Config.waitingBind then return end
    if Config.platform~="pc" then return end
    if input.KeyCode~=Config.keybind then return end
    Config.active=not Config.active; Config.stickyTarget=nil
    if activeSync then activeSync(Config.active) end
end))

----------------------------------------------------------------
-- BACKGROUND
----------------------------------------------------------------
table.insert(GC.conn,RunService.Heartbeat:Connect(function()
    updateThreats()
    for _,p in ipairs(Players:GetPlayers()) do
        if p~=LP and p.Character and alive(p.Character) then
            try(function() spUpdate(p,p.Character) end)
        end
    end
end))

----------------------------------------------------------------
-- RENDER  [v3.3 ANTI-SPIN FIX]
----------------------------------------------------------------
RunService:BindToRenderStep("AimbotV32",Enum.RenderPriority.Camera.Value+1,function(dt)
    Camera=workspace.CurrentCamera
    lastFrameDt=dt

    if Config.fov>=360 then setFovVis(false,0)
    else
        local hr=RAD(Config.fov/2); local cr=RAD(Camera.FieldOfView/2)
        local dn=math.tan(cr); local vs=Camera.ViewportSize
        local radius=dn>0 and (math.tan(hr)/dn*(vs.Y/2)) or 200
        setFovVis(Config.active and Config.showFov,radius)
    end

    if not Config.active then currentTarget=nil; setCrossVis(false); return end

    local tgt=bestTarget(); currentTarget=tgt
    if not tgt or not tgt.Character then setCrossVis(false); return end
    local ap=getAimPos(tgt)
    if not ap then setCrossVis(false); return end
    if (ap-Camera.CFrame.Position).Magnitude<0.5 then setCrossVis(false); return end

    if Config.showCross then
        local sp,onS=Camera:WorldToViewportPoint(ap)
        if onS then setCrossVis(true); updateCross(sp.X,sp.Y) else setCrossVis(false) end
    else setCrossVis(false) end

    -- [v3.3] ANTI-SPIN: human-like uses HA:aim with built-in damping
    -- non-human uses high factor BUT smoothAim now has distance damping + rotation cap
    if Config.humanLike then
        Camera.CFrame=HA:aim(Camera.CFrame,ap,dt)
    else
        local baseFac = CLAMP(Config.aimSpeed * 2.5, 0.3, 0.9)
        Camera.CFrame=smoothAim(Camera.CFrame,ap,baseFac,dt)
    end
end)

----------------------------------------------------------------
buildSelect()
