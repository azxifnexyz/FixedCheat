local Library = loadstring(game:HttpGet('https://raw.githubusercontent.com/KINGHUB01/Gui/main/Gui%20Lib%20%5BLibrary%5D'))()
local ThemeManager = loadstring(game:HttpGet('https://raw.githubusercontent.com/KINGHUB01/Gui/main/Gui%20Lib%20%5BThemeManager%5D'))()
local SaveManager = loadstring(game:HttpGet('https://raw.githubusercontent.com/KINGHUB01/Gui/main/Gui%20Lib%20%5BSaveManager%5D'))()

local Players     = game:GetService("Players")
local RunService  = game:GetService("RunService")
local Camera      = workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer

-- ==================== STATE VARIABLES ====================
-- All FOV state lives in plain Lua variables.
-- We NEVER read back from fovCircle properties to make decisions.
local fovEnabled   = false
local fovThickness = 1       -- 0 = hidden, 1-10 = visible
local fovRadius    = 100
local fovColor     = Color3.new(1, 1, 1)
local fovFilled    = false

local AimbotEnabled   = false
local espEnabled      = false
local targetPart      = "Head"
local smoothnessType  = "Linear"
local smoothIntensity = 0.7
local wallCheck       = true
local teamCheck       = true

-- Create the FOV drawing object but never use its properties as conditions
local fovCircle = Drawing.new("Circle")
fovCircle.NumSides  = 100
fovCircle.Thickness = 1
fovCircle.Radius    = fovRadius
fovCircle.Color     = fovColor
fovCircle.Filled    = fovFilled
fovCircle.Visible   = false

-- Single function that syncs the Drawing to our Lua state
local function syncFOV()
    -- Only truly visible when toggle is on AND thickness is not 0
    fovCircle.Visible   = fovEnabled and (fovThickness > 0)
    fovCircle.Thickness = math.max(fovThickness, 1) -- Drawing min is 1; we gate visibility instead
    fovCircle.Radius    = fovRadius
    fovCircle.Color     = fovColor
    fovCircle.Filled    = fovFilled
    -- Keep it centered at all times when visible
    if fovCircle.Visible then
        fovCircle.Position = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    end
end

local SPECIAL_PLACE_ID = 130650085400942
local isSpecialGame    = game.PlaceId == SPECIAL_PLACE_ID

-- ==================== WINDOW & TABS ====================
local Window = Library:CreateWindow({ Title = 'PolleserHub', Center = true, AutoShow = true })

local Tabs = {
    Main            = Window:AddTab('Main'),
    ESP             = Window:AddTab('ESP'),
    Credits         = Window:AddTab('Credits'),
    ['UI Settings'] = Window:AddTab('UI Settings'),
}
if isSpecialGame then
    Tabs.Weapons = Window:AddTab('Weapons')
end

-- ==================== FOV UI ====================
local FOVBox = Tabs.Main:AddLeftGroupbox('FOV Circle')

FOVBox:AddToggle('FOVEnabled', {
    Text = 'Enabled', Default = false,
    Callback = function(v) fovEnabled = v; syncFOV() end
})
:AddColorPicker('FOVColor', {
    Text = 'Color', Default = fovColor,
    Callback = function(v) fovColor = v; syncFOV() end
})

FOVBox:AddToggle('FOVFilled', {
    Text = 'Filled', Default = false,
    Callback = function(v) fovFilled = v; syncFOV() end
})

FOVBox:AddSlider('FOVRadius', {
    Text = 'Radius', Default = 100, Min = 50, Max = 250, Rounding = 0,
    Callback = function(v) fovRadius = v; syncFOV() end
})

-- Thickness 0 = circle invisible (the FOV toggle stays on, just hidden visually)
-- Thickness 1-10 = circle drawn at that thickness
FOVBox:AddSlider('FOVThickness', {
    Text = 'Thickness  (0 = hidden)', Default = 1, Min = 0, Max = 10, Rounding = 0,
    Callback = function(v) fovThickness = v; syncFOV() end
})

-- ==================== AIMBOT UI ====================
local AimbotBox = Tabs.Main:AddLeftGroupbox('Aimbot')

AimbotBox:AddToggle('AimbotEnabled', {
    Text = 'Enabled', Default = false,
    Callback = function(v) AimbotEnabled = v end
})
AimbotBox:AddDropdown('AimbotHitpart', {
    Values = {
        "Head","UpperTorso","LowerTorso","HumanoidRootPart",
        "LeftUpperArm","LeftLowerArm","LeftHand",
        "RightUpperArm","RightLowerArm","RightHand",
        "LeftUpperLeg","LeftLowerLeg","LeftFoot",
        "RightUpperLeg","RightLowerLeg","RightFoot",
    },
    Default = 1, Multi = false, Text = 'Hitpart',
    Callback = function(v) targetPart = v end
})
AimbotBox:AddDropdown('SmoothnessType', {
    Text = 'Smoothness Type', Values = {"Linear","Ease Out","Dynamic"}, Default = 1,
    Callback = function(v) smoothnessType = v end
})
AimbotBox:AddSlider('SmoothnessIntensity', {
    Text = 'Intensity', Default = 0.7, Min = 0, Max = 1, Rounding = 2,
    Callback = function(v) smoothIntensity = v end
})

-- ==================== CHECKS UI ====================
local CheckBox = Tabs.Main:AddRightGroupbox('Checks')

CheckBox:AddToggle('WallCheck', {
    Text = 'Wall Check', Default = true,
    Callback = function(v) wallCheck = v end
})

-- Team check label differs per game but the variable is the same
local teamCheckLabel = isSpecialGame and 'Team Check (Match)' or 'Team Check'
CheckBox:AddToggle('TeamCheckEnabled', {
    Text = teamCheckLabel, Default = true,
    Callback = function(v) teamCheck = v end
})

-- ==================== WEAPON MODS (special game only) ====================
local WepVars = {
    AutoFire = false, NoReload = false, NoRecoil = false,
    CustomMag = false, MagSize = 100, CustomROF = false, RateOfFire = 1000,
}
local origWep = {}

local function storeOriginals(w)
    if origWep[w] then return end
    origWep[w] = {
        fireMode     = w:GetAttribute("fireMode"),
        reloadTime   = w:GetAttribute("reloadTime"),
        recoilMax    = w:GetAttribute("recoilMax"),
        recoilMin    = w:GetAttribute("recoilMin"),
        magazineSize = w:GetAttribute("magazineSize"),
        rateOfFire   = w:GetAttribute("rateOfFire"),
    }
end

local function applyToWeapon(w)
    if not (w:IsA("Tool") and w:GetAttribute("_ammo")) then return end
    storeOriginals(w)
    local o = origWep[w]
    w:SetAttribute("fireMode",     WepVars.AutoFire  and "Auto" or (o.fireMode or "Semi"))
    w:SetAttribute("reloadTime",   WepVars.NoReload  and 0      or o.reloadTime)
    w:SetAttribute("magazineSize", WepVars.CustomMag and WepVars.MagSize or o.magazineSize)
    w:SetAttribute("rateOfFire",   WepVars.CustomROF and WepVars.RateOfFire or o.rateOfFire)
    if WepVars.NoRecoil then
        if w:GetAttribute("recoilMax") ~= nil then w:SetAttribute("recoilMax", Vector2.new(0,0)) end
        if w:GetAttribute("recoilMin") ~= nil then w:SetAttribute("recoilMin", Vector2.new(0,0)) end
    else
        if o.recoilMax ~= nil then w:SetAttribute("recoilMax", o.recoilMax) end
        if o.recoilMin ~= nil then w:SetAttribute("recoilMin", o.recoilMin) end
    end
end

local function applyWeaponMods()
    local c = LocalPlayer.Character
    if not c then return end
    for _, w in pairs(c:GetChildren()) do applyToWeapon(w) end
end

if isSpecialGame then
    local function hookChar(char)
        char.ChildAdded:Connect(function(child)
            task.wait(0.1); applyToWeapon(child)
        end)
    end
    if LocalPlayer.Character then hookChar(LocalPlayer.Character) end
    LocalPlayer.CharacterAdded:Connect(hookChar)

    local WA = Tabs.Weapons:AddLeftGroupbox('Fire Mode')
    WA:AddToggle('WepAutoFire', { Text='Auto Fire', Default=false, Callback=function(v) WepVars.AutoFire=v; applyWeaponMods() end })
    WA:AddLabel('Switches fireMode: Semi → Auto')

    local WR = Tabs.Weapons:AddLeftGroupbox('Reload')
    WR:AddToggle('WepNoReload', { Text='No Reload', Default=false, Callback=function(v) WepVars.NoReload=v; applyWeaponMods() end })
    WR:AddLabel('Sets reloadTime to 0')

    local WRC = Tabs.Weapons:AddLeftGroupbox('Recoil')
    WRC:AddToggle('WepNoRecoil', { Text='No Recoil', Default=false, Callback=function(v) WepVars.NoRecoil=v; applyWeaponMods() end })
    WRC:AddLabel('Sets recoilMax & recoilMin to 0,0')

    local WM = Tabs.Weapons:AddRightGroupbox('Magazine')
    WM:AddToggle('WepCustomMag', { Text='Custom Mag Size', Default=false, Callback=function(v) WepVars.CustomMag=v; applyWeaponMods() end })
    WM:AddSlider('WepMagSize', { Text='Magazine Size', Default=100, Min=1, Max=500, Rounding=0, Callback=function(v) WepVars.MagSize=v; if WepVars.CustomMag then applyWeaponMods() end end })

    local WF = Tabs.Weapons:AddRightGroupbox('Rate of Fire')
    WF:AddToggle('WepCustomROF', { Text='Custom Rate of Fire', Default=false, Callback=function(v) WepVars.CustomROF=v; applyWeaponMods() end })
    WF:AddSlider('WepROF', { Text='Rate of Fire', Default=1000, Min=100, Max=10000, Rounding=0, Callback=function(v) WepVars.RateOfFire=v; if WepVars.CustomROF then applyWeaponMods() end end })

    Tabs.Weapons:AddLeftGroupbox('Apply'):AddButton('Re-Apply to Current Weapon', applyWeaponMods)
end

-- ==================== ESP CONSTANTS ====================
local PINK     = Color3.fromRGB(255, 182, 213)
local PINK_DIM = Color3.fromRGB(220, 130, 180)
local BLACK    = Color3.fromRGB(0, 0, 0)
local WHITE    = Color3.fromRGB(255, 255, 255)

local EV = {
    BoxEnabled=true, BoxColor=PINK, BoxThickness=1.5, BoxOutline=true, BoxOutlineColor=BLACK,
    BoxFilled=false, BoxFilledColor=PINK, BoxFilledTransparency=0.82, CornerBox=false, CornerLength=6,
    HealthBar=true, HealthBarSide="Left", HealthBarOutline=true,
    NameEnabled=true, NameColor=WHITE, NameSize=13, ShowDisplayName=false,
    DistanceEnabled=true, DistanceColor=PINK_DIM,
    WeaponEnabled=false, WeaponColor=PINK_DIM,
    TracerEnabled=false, TracerOrigin="Bottom", TracerColor=PINK, TracerThickness=1, TracerOutline=true,
    HeadDot=false, HeadDotColor=PINK, HeadDotFilled=true, HeadDotOutlineColor=BLACK,
    SkeletonEnabled=false, SkeletonColor=PINK,
    LookDirectionEnabled=false, LookDirectionColor=PINK, LookDirectionLength=4,
    OffscreenArrow=false, OffscreenArrowColor=PINK, OffscreenArrowSize=14, OffscreenArrowRadius=120,
}

local SKEL = {
    {"Head","UpperTorso"},{"UpperTorso","LowerTorso"},
    {"UpperTorso","LeftUpperArm"},{"LeftUpperArm","LeftLowerArm"},{"LeftLowerArm","LeftHand"},
    {"UpperTorso","RightUpperArm"},{"RightUpperArm","RightLowerArm"},{"RightLowerArm","RightHand"},
    {"LowerTorso","LeftUpperLeg"},{"LeftUpperLeg","LeftLowerLeg"},{"LeftLowerLeg","LeftFoot"},
    {"LowerTorso","RightUpperLeg"},{"RightUpperLeg","RightLowerLeg"},{"RightLowerLeg","RightFoot"},
}

local espObjects = {}

-- ==================== ESP DRAWING HELPERS ====================
local function nd(t, p)
    local d = Drawing.new(t)
    for k,v in pairs(p) do d[k]=v end
    return d
end

local function createESP(model)
    if espObjects[model] then return end
    local o = {}
    o.boxOutline = nd("Square",{Visible=false,Filled=false,Color=BLACK,Thickness=3.5})
    o.boxFill    = nd("Square",{Visible=false,Filled=true, Color=PINK, Transparency=0.18})
    o.box        = nd("Square",{Visible=false,Filled=false,Color=PINK, Thickness=1.5})
    o.corners={}; o.cornerOutlines={}
    for i=1,8 do
        table.insert(o.cornerOutlines, nd("Line",{Visible=false,Color=BLACK,Thickness=3}))
        table.insert(o.corners,        nd("Line",{Visible=false,Color=PINK, Thickness=1.8}))
    end
    o.healthBg      = nd("Square",{Visible=false,Filled=true, Color=Color3.fromRGB(20,20,20),Transparency=0.4})
    o.healthBar     = nd("Square",{Visible=false,Filled=true, Color=Color3.fromRGB(100,255,100)})
    o.healthOutline = nd("Square",{Visible=false,Filled=false,Color=BLACK,Thickness=1})
    o.nameLabel        = nd("Text",{Visible=false,Text=model.Name,Color=WHITE,   Size=13,Center=true,Outline=true,OutlineColor=BLACK,Font=2})
    o.displayNameLabel = nd("Text",{Visible=false,Text="",        Color=PINK_DIM,Size=11,Center=true,Outline=true,OutlineColor=BLACK,Font=2})
    o.distLabel        = nd("Text",{Visible=false,Text="0m",      Color=PINK_DIM,Size=11,Center=true,Outline=true,OutlineColor=BLACK,Font=2})
    o.weaponLabel      = nd("Text",{Visible=false,Text="",        Color=PINK_DIM,Size=11,Center=true,Outline=true,OutlineColor=BLACK,Font=2})
    o.tracerOutline = nd("Line",  {Visible=false,Color=BLACK,Thickness=2.5})
    o.tracer        = nd("Line",  {Visible=false,Color=PINK, Thickness=1})
    o.headDotOutline = nd("Circle",{Visible=false,Color=BLACK,Filled=true,NumSides=32})
    o.headDot        = nd("Circle",{Visible=false,Color=PINK, Filled=true,NumSides=32})
    o.skeleton={}; o.skeletonOutlines={}
    for i=1,#SKEL do
        table.insert(o.skeletonOutlines, nd("Line",{Visible=false,Color=BLACK,Thickness=2.5}))
        table.insert(o.skeleton,         nd("Line",{Visible=false,Color=PINK, Thickness=1}))
    end
    o.lookLineOutline = nd("Line",    {Visible=false,Color=BLACK,Thickness=3})
    o.lookLine        = nd("Line",    {Visible=false,Color=PINK, Thickness=1.5})
    o.arrowOutline    = nd("Triangle",{Visible=false,Filled=true,Color=BLACK})
    o.arrow           = nd("Triangle",{Visible=false,Filled=true,Color=PINK})
    espObjects[model] = o
end

local function removeESP(model)
    local o = espObjects[model]
    if not o then return end
    for _, v in pairs(o) do
        if type(v) == "table" then
            for _, item in ipairs(v) do if item and item.Remove then item:Remove() end end
        else
            if v and v.Remove then v:Remove() end
        end
    end
    espObjects[model] = nil
end

local function hideESP(o)
    for _, v in pairs(o) do
        if type(v) == "table" then
            for _, item in ipairs(v) do if item then item.Visible = false end end
        else
            if v then v.Visible = false end
        end
    end
end

-- ==================== VALIDITY ====================
local function isDead(model)
    local h = model:FindFirstChildOfClass("Humanoid")
    if not h then return true end
    if isSpecialGame and h:GetAttribute("Ragdoll") == true then return true end
    return h.Health <= 0
end

local function isValidCharacter(model)
    if not model or not model:IsA("Model") or not model.Parent then return false end
    if isSpecialGame then
        if not (
            model:GetAttribute("TeamName")   ~= nil or
            model:GetAttribute("MatchId")    ~= nil or
            model:GetAttribute("InMatch")    ~= nil or
            model:GetAttribute("InSafeZone") ~= nil
        ) then return false end
    end
    if isDead(model) then return false end
    -- confirm it belongs to a player (non-special) or just exists (special)
    if not isSpecialGame then
        local found = false
        for _, p in ipairs(Players:GetPlayers()) do
            if p.Character == model then found = true; break end
        end
        if not found then return false end
    end
    return true
end

local function isValidTarget(model)
    if not model then return false end
    if model == LocalPlayer.Character then return false end
    if not isSpecialGame then
        if teamCheck then
            local tp = Players:GetPlayerFromCharacter(model)
            if tp and LocalPlayer.Team ~= nil and tp.Team ~= nil then
                if LocalPlayer.Team == tp.Team then return false end
            end
        end
        return true
    end
    -- special game team logic
    local chars = workspace:FindFirstChild("Characters")
    if not chars then return true end
    local lc = chars:FindFirstChild(LocalPlayer.Name)
    if not lc then return true end
    local inSZ   = lc:GetAttribute("InSafeZone")
    local inM    = lc:GetAttribute("InMatch")
    local battle = (inSZ == nil or inSZ == false) and (inM == nil or inM ~= "1v1")
    if not battle then return true end
    local myMID  = lc:GetAttribute("MatchId")
    local myTeam = lc:GetAttribute("TeamName")
    if not myMID then return true end
    local tMID  = model:GetAttribute("MatchId")
    local tTeam = model:GetAttribute("TeamName")
    if tMID and tMID ~= myMID then return false end
    if teamCheck and myTeam and tTeam and myTeam == tTeam then return false end
    return true
end

-- ==================== ESP RENDER HELPERS ====================
local function getModelBounds(model)
    local minX, minY, maxX, maxY = math.huge, math.huge, -math.huge, -math.huge
    local any = false
    for _, part in ipairs(model:GetDescendants()) do
        if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
            local c = {
                Vector3.new( part.Size.X/2,  part.Size.Y/2,  part.Size.Z/2),
                Vector3.new(-part.Size.X/2,  part.Size.Y/2,  part.Size.Z/2),
                Vector3.new( part.Size.X/2, -part.Size.Y/2,  part.Size.Z/2),
                Vector3.new(-part.Size.X/2, -part.Size.Y/2,  part.Size.Z/2),
                Vector3.new( part.Size.X/2,  part.Size.Y/2, -part.Size.Z/2),
                Vector3.new(-part.Size.X/2,  part.Size.Y/2, -part.Size.Z/2),
                Vector3.new( part.Size.X/2, -part.Size.Y/2, -part.Size.Z/2),
                Vector3.new(-part.Size.X/2, -part.Size.Y/2, -part.Size.Z/2),
            }
            for _, off in ipairs(c) do
                local sp, on = Camera:WorldToViewportPoint((part.CFrame * CFrame.new(off)).Position)
                if on and sp.Z > 0 then
                    any = true
                    if sp.X < minX then minX = sp.X end
                    if sp.Y < minY then minY = sp.Y end
                    if sp.X > maxX then maxX = sp.X end
                    if sp.Y > maxY then maxY = sp.Y end
                end
            end
        end
    end
    return any, minX, minY, maxX, maxY
end

local function getHealth(model)
    local h = model:FindFirstChildOfClass("Humanoid")
    if not h then return 100,100 end
    return math.clamp(h.Health,0,h.MaxHealth), math.max(h.MaxHealth,1)
end

local function getDist(model)
    local r  = model:FindFirstChild("HumanoidRootPart")
    local mc = LocalPlayer.Character
    if not r or not mc then return 0 end
    local mr = mc:FindFirstChild("HumanoidRootPart")
    if not mr then return 0 end
    return math.floor((r.Position - mr.Position).Magnitude)
end

local function hpColor(hp, mx)
    local t = math.clamp(hp/mx,0,1)
    if t > 0.5 then
        local s=(t-0.5)*2; return Color3.fromRGB(math.floor((1-s)*255),220,80)
    else
        local s=t*2; return Color3.fromRGB(255,math.floor(s*220),80)
    end
end

local function equippedWeapon(model)
    for _, c in ipairs(model:GetChildren()) do if c:IsA("Tool") then return c.Name end end
    return nil
end

local function offscreenArrow(worldPos, radius)
    local center = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2)
    local sp, on = Camera:WorldToViewportPoint(worldPos)
    if on and sp.Z > 0 then return nil, nil end
    local dir = (Vector2.new(sp.X, sp.Y) - center)
    if dir.Magnitude < 0.001 then return nil, nil end
    dir = dir.Unit
    return center + dir*radius, math.atan2(dir.Y, dir.X)
end

-- ==================== ESP UPDATE ====================
local function updateESP(model, o)
    local vis, x1, y1, x2, y2 = getModelBounds(model)
    local dist = getDist(model)

    -- Offscreen arrow (independent of on-screen visibility)
    if EV.OffscreenArrow then
        local root = model:FindFirstChild("HumanoidRootPart")
        if root then
            local ap, angle = offscreenArrow(root.Position, EV.OffscreenArrowRadius)
            if ap and angle then
                local s   = EV.OffscreenArrowSize
                local tip  = ap + Vector2.new(math.cos(angle),          math.sin(angle))          * s
                local lft  = ap + Vector2.new(math.cos(angle+math.pi*0.75), math.sin(angle+math.pi*0.75)) * (s*0.6)
                local rgt  = ap + Vector2.new(math.cos(angle-math.pi*0.75), math.sin(angle-math.pi*0.75)) * (s*0.6)
                o.arrowOutline.Visible=true; o.arrowOutline.PointA=tip; o.arrowOutline.PointB=lft; o.arrowOutline.PointC=rgt
                o.arrow.Visible=true; o.arrow.PointA=tip; o.arrow.PointB=lft; o.arrow.PointC=rgt; o.arrow.Color=EV.OffscreenArrowColor
            else
                o.arrow.Visible=false; o.arrowOutline.Visible=false
            end
        else
            o.arrow.Visible=false; o.arrowOutline.Visible=false
        end
    else
        o.arrow.Visible=false; o.arrowOutline.Visible=false
    end

    if not vis then
        o.box.Visible=false; o.boxOutline.Visible=false; o.boxFill.Visible=false
        o.healthBar.Visible=false; o.healthBg.Visible=false; o.healthOutline.Visible=false
        o.nameLabel.Visible=false; o.displayNameLabel.Visible=false
        o.distLabel.Visible=false; o.weaponLabel.Visible=false
        o.tracer.Visible=false; o.tracerOutline.Visible=false
        o.headDot.Visible=false; o.headDotOutline.Visible=false
        o.lookLine.Visible=false; o.lookLineOutline.Visible=false
        for _,l in ipairs(o.corners)         do l.Visible=false end
        for _,l in ipairs(o.cornerOutlines)  do l.Visible=false end
        for _,l in ipairs(o.skeleton)        do l.Visible=false end
        for _,l in ipairs(o.skeletonOutlines)do l.Visible=false end
        return
    end

    local w  = x2-x1; local h = y2-y1; local cx = (x1+x2)/2
    local hp, mhp = getHealth(model)
    local hpr = math.clamp(hp/mhp,0,1)
    local BW, BG = 4, 3

    -- BOX
    if EV.BoxEnabled then
        if EV.BoxFilled then
            o.boxFill.Visible=true; o.boxFill.Position=Vector2.new(x1,y1); o.boxFill.Size=Vector2.new(w,h)
            o.boxFill.Color=EV.BoxFilledColor; o.boxFill.Transparency=1-EV.BoxFilledTransparency
        else o.boxFill.Visible=false end

        if EV.CornerBox then
            o.box.Visible=false; o.boxOutline.Visible=false
            local cl = math.min(EV.CornerLength, w/3, h/3)
            local pts = {
                {Vector2.new(x1,y1),Vector2.new(x1+cl,y1),Vector2.new(x1,y1+cl)},
                {Vector2.new(x2,y1),Vector2.new(x2-cl,y1),Vector2.new(x2,y1+cl)},
                {Vector2.new(x1,y2),Vector2.new(x1+cl,y2),Vector2.new(x1,y2-cl)},
                {Vector2.new(x2,y2),Vector2.new(x2-cl,y2),Vector2.new(x2,y2-cl)},
            }
            local li=1
            for _,c in ipairs(pts) do
                for j=2,3 do
                    if EV.BoxOutline then
                        o.cornerOutlines[li].Visible=true; o.cornerOutlines[li].From=c[1]; o.cornerOutlines[li].To=c[j]; o.cornerOutlines[li].Color=EV.BoxOutlineColor
                    else o.cornerOutlines[li].Visible=false end
                    o.corners[li].Visible=true; o.corners[li].From=c[1]; o.corners[li].To=c[j]
                    o.corners[li].Color=EV.BoxColor; o.corners[li].Thickness=EV.BoxThickness+0.5
                    li=li+1
                end
            end
        else
            for _,l in ipairs(o.corners)        do l.Visible=false end
            for _,l in ipairs(o.cornerOutlines) do l.Visible=false end
            if EV.BoxOutline then
                o.boxOutline.Visible=true; o.boxOutline.Position=Vector2.new(x1-1,y1-1)
                o.boxOutline.Size=Vector2.new(w+2,h+2); o.boxOutline.Color=EV.BoxOutlineColor; o.boxOutline.Thickness=EV.BoxThickness+2
            else o.boxOutline.Visible=false end
            o.box.Visible=true; o.box.Position=Vector2.new(x1,y1); o.box.Size=Vector2.new(w,h)
            o.box.Color=EV.BoxColor; o.box.Thickness=EV.BoxThickness
        end
    else
        o.box.Visible=false; o.boxOutline.Visible=false; o.boxFill.Visible=false
        for _,l in ipairs(o.corners)        do l.Visible=false end
        for _,l in ipairs(o.cornerOutlines) do l.Visible=false end
    end

    -- HEALTH BAR
    if EV.HealthBar then
        local barH = h*hpr
        local bx   = (EV.HealthBarSide=="Left") and (x1-BG-BW) or (x2+BG)
        o.healthBg.Visible=true;  o.healthBg.Position=Vector2.new(bx,y1);        o.healthBg.Size=Vector2.new(BW,h)
        o.healthBar.Visible=true; o.healthBar.Position=Vector2.new(bx,y1+(h-barH)); o.healthBar.Size=Vector2.new(BW,barH); o.healthBar.Color=hpColor(hp,mhp)
        if EV.HealthBarOutline then
            o.healthOutline.Visible=true; o.healthOutline.Position=Vector2.new(bx-1,y1-1); o.healthOutline.Size=Vector2.new(BW+2,h+2)
        else o.healthOutline.Visible=false end
    else
        o.healthBar.Visible=false; o.healthBg.Visible=false; o.healthOutline.Visible=false
    end

    -- NAME
    local ty = y1 - EV.NameSize - 2
    if EV.NameEnabled then
        o.nameLabel.Visible=true; o.nameLabel.Position=Vector2.new(cx,ty)
        o.nameLabel.Color=EV.NameColor; o.nameLabel.Size=EV.NameSize; o.nameLabel.Text=model.Name
        ty=ty-13
    else o.nameLabel.Visible=false end

    if EV.ShowDisplayName then
        local pl = Players:GetPlayerFromCharacter(model)
        local dn = pl and pl.DisplayName or ""
        if dn~=model.Name and dn~="" then
            o.displayNameLabel.Visible=true; o.displayNameLabel.Position=Vector2.new(cx,ty)
            o.displayNameLabel.Text="("..dn..")"; o.displayNameLabel.Color=EV.NameColor; ty=ty-12
        else o.displayNameLabel.Visible=false end
    else o.displayNameLabel.Visible=false end

    -- DISTANCE
    if EV.DistanceEnabled then
        o.distLabel.Visible=true; o.distLabel.Position=Vector2.new(cx,y2+2)
        o.distLabel.Color=EV.DistanceColor; o.distLabel.Text="["..dist.."m]"
    else o.distLabel.Visible=false end

    -- WEAPON NAME
    if EV.WeaponEnabled then
        local wn = equippedWeapon(model)
        if wn then
            o.weaponLabel.Visible=true; o.weaponLabel.Position=Vector2.new(cx,y2+13)
            o.weaponLabel.Color=EV.WeaponColor; o.weaponLabel.Text="⚔ "..wn
        else o.weaponLabel.Visible=false end
    else o.weaponLabel.Visible=false end

    -- TRACERS
    if EV.TracerEnabled then
        local fr
        if EV.TracerOrigin=="Bottom" then fr=Vector2.new(Camera.ViewportSize.X/2,Camera.ViewportSize.Y)
        elseif EV.TracerOrigin=="Top" then fr=Vector2.new(Camera.ViewportSize.X/2,0)
        else fr=Vector2.new(Camera.ViewportSize.X/2,Camera.ViewportSize.Y/2) end
        local to=Vector2.new(cx,y2)
        if EV.TracerOutline then
            o.tracerOutline.Visible=true; o.tracerOutline.From=fr; o.tracerOutline.To=to; o.tracerOutline.Thickness=EV.TracerThickness+1.5
        else o.tracerOutline.Visible=false end
        o.tracer.Visible=true; o.tracer.From=fr; o.tracer.To=to; o.tracer.Color=EV.TracerColor; o.tracer.Thickness=EV.TracerThickness
    else o.tracer.Visible=false; o.tracerOutline.Visible=false end

    -- HEAD DOT
    if EV.HeadDot then
        local head=model:FindFirstChild("Head")
        if head then
            local sp,on=Camera:WorldToViewportPoint(head.Position)
            if on and sp.Z>0 then
                local r=math.clamp(400/math.max(dist,1),3,10)
                o.headDotOutline.Visible=true; o.headDotOutline.Position=Vector2.new(sp.X,sp.Y); o.headDotOutline.Radius=r+1.5; o.headDotOutline.Color=EV.HeadDotOutlineColor
                o.headDot.Visible=true; o.headDot.Position=Vector2.new(sp.X,sp.Y); o.headDot.Radius=r; o.headDot.Color=EV.HeadDotColor; o.headDot.Filled=EV.HeadDotFilled
            else o.headDot.Visible=false; o.headDotOutline.Visible=false end
        else o.headDot.Visible=false; o.headDotOutline.Visible=false end
    else o.headDot.Visible=false; o.headDotOutline.Visible=false end

    -- SKELETON
    if EV.SkeletonEnabled then
        for i,conn in ipairs(SKEL) do
            local p1=model:FindFirstChild(conn[1]); local p2=model:FindFirstChild(conn[2])
            if p1 and p2 then
                local s1,on1=Camera:WorldToViewportPoint(p1.Position)
                local s2,on2=Camera:WorldToViewportPoint(p2.Position)
                if on1 and on2 and s1.Z>0 and s2.Z>0 then
                    o.skeletonOutlines[i].Visible=true; o.skeletonOutlines[i].From=Vector2.new(s1.X,s1.Y); o.skeletonOutlines[i].To=Vector2.new(s2.X,s2.Y)
                    o.skeleton[i].Visible=true; o.skeleton[i].From=Vector2.new(s1.X,s1.Y); o.skeleton[i].To=Vector2.new(s2.X,s2.Y); o.skeleton[i].Color=EV.SkeletonColor
                else o.skeleton[i].Visible=false; o.skeletonOutlines[i].Visible=false end
            else o.skeleton[i].Visible=false; o.skeletonOutlines[i].Visible=false end
        end
    else
        for _,l in ipairs(o.skeleton)         do l.Visible=false end
        for _,l in ipairs(o.skeletonOutlines) do l.Visible=false end
    end

    -- LOOK DIRECTION
    if EV.LookDirectionEnabled then
        local root=model:FindFirstChild("HumanoidRootPart")
        if root then
            local orig=root.Position; local le=orig+root.CFrame.LookVector*(EV.LookDirectionLength*3)
            local s1,on1=Camera:WorldToViewportPoint(orig); local s2,on2=Camera:WorldToViewportPoint(le)
            if on1 and on2 and s1.Z>0 and s2.Z>0 then
                o.lookLineOutline.Visible=true; o.lookLineOutline.From=Vector2.new(s1.X,s1.Y); o.lookLineOutline.To=Vector2.new(s2.X,s2.Y)
                o.lookLine.Visible=true; o.lookLine.From=Vector2.new(s1.X,s1.Y); o.lookLine.To=Vector2.new(s2.X,s2.Y); o.lookLine.Color=EV.LookDirectionColor
            else o.lookLine.Visible=false; o.lookLineOutline.Visible=false end
        else o.lookLine.Visible=false; o.lookLineOutline.Visible=false end
    else o.lookLine.Visible=false; o.lookLineOutline.Visible=false end
end

-- ==================== ESP TAB UI ====================
local ET = Tabs.ESP:AddLeftGroupbox('ESP')
ET:AddToggle('ESPEnabled',{Text='Enable ESP',Default=false,Callback=function(v) espEnabled=v; if not v then for _,o in pairs(espObjects) do hideESP(o) end end end})

local BG2 = Tabs.ESP:AddLeftGroupbox('Box')
BG2:AddToggle('BoxEnabled',{Text='Box',Default=true,Callback=function(v) EV.BoxEnabled=v end})
   :AddColorPicker('BoxColor',{Text='Color',Default=PINK,Callback=function(v) EV.BoxColor=v end})
BG2:AddToggle('BoxOutline',{Text='Outline',Default=true,Callback=function(v) EV.BoxOutline=v end})
   :AddColorPicker('BoxOutlineColor',{Text='Outline Color',Default=BLACK,Callback=function(v) EV.BoxOutlineColor=v end})
BG2:AddToggle('BoxFilled',{Text='Filled',Default=false,Callback=function(v) EV.BoxFilled=v end})
   :AddColorPicker('BoxFilledColor',{Text='Fill Color',Default=PINK,Callback=function(v) EV.BoxFilledColor=v end})
BG2:AddSlider('BoxFilledTransparency',{Text='Fill Opacity',Default=0.82,Min=0,Max=1,Rounding=2,Callback=function(v) EV.BoxFilledTransparency=v end})
BG2:AddSlider('BoxThickness',{Text='Thickness',Default=1,Min=1,Max=5,Rounding=1,Callback=function(v) EV.BoxThickness=v end})
BG2:AddToggle('CornerBox',{Text='Corner Box Style',Default=false,Callback=function(v) EV.CornerBox=v end})
BG2:AddSlider('CornerLength',{Text='Corner Length',Default=6,Min=3,Max=20,Rounding=0,Callback=function(v) EV.CornerLength=v end})

local IG = Tabs.ESP:AddLeftGroupbox('Info')
IG:AddToggle('NameEnabled',{Text='Name',Default=true,Callback=function(v) EV.NameEnabled=v end})
  :AddColorPicker('NameColor',{Text='Color',Default=WHITE,Callback=function(v) EV.NameColor=v end})
IG:AddSlider('NameSize',{Text='Name Size',Default=13,Min=8,Max=20,Rounding=0,Callback=function(v) EV.NameSize=v end})
IG:AddToggle('ShowDisplayName',{Text='Display Name',Default=false,Callback=function(v) EV.ShowDisplayName=v end})
IG:AddToggle('DistanceEnabled',{Text='Distance',Default=true,Callback=function(v) EV.DistanceEnabled=v end})
  :AddColorPicker('DistanceColor',{Text='Color',Default=PINK_DIM,Callback=function(v) EV.DistanceColor=v end})
IG:AddToggle('WeaponEnabled',{Text='Weapon Name',Default=false,Callback=function(v) EV.WeaponEnabled=v end})
  :AddColorPicker('WeaponColor',{Text='Color',Default=PINK_DIM,Callback=function(v) EV.WeaponColor=v end})

local HG = Tabs.ESP:AddRightGroupbox('Health Bar')
HG:AddToggle('HealthBar',{Text='Health Bar',Default=true,Callback=function(v) EV.HealthBar=v end})
HG:AddToggle('HealthBarOutline',{Text='Outline',Default=true,Callback=function(v) EV.HealthBarOutline=v end})
HG:AddDropdown('HealthBarSide',{Text='Side',Values={"Left","Right"},Default=1,Callback=function(v) EV.HealthBarSide=v end})

local TG = Tabs.ESP:AddRightGroupbox('Tracers')
TG:AddToggle('TracerEnabled',{Text='Tracers',Default=false,Callback=function(v) EV.TracerEnabled=v end})
  :AddColorPicker('TracerColor',{Text='Color',Default=PINK,Callback=function(v) EV.TracerColor=v end})
TG:AddDropdown('TracerOrigin',{Text='Origin',Values={"Bottom","Top","Center"},Default=1,Callback=function(v) EV.TracerOrigin=v end})
TG:AddSlider('TracerThickness',{Text='Thickness',Default=1,Min=1,Max=4,Rounding=1,Callback=function(v) EV.TracerThickness=v end})
TG:AddToggle('TracerOutline',{Text='Outline',Default=true,Callback=function(v) EV.TracerOutline=v end})

local XG = Tabs.ESP:AddRightGroupbox('Extras')
XG:AddToggle('HeadDot',{Text='Head Dot',Default=false,Callback=function(v) EV.HeadDot=v end})
  :AddColorPicker('HeadDotColor',{Text='Color',Default=PINK,Callback=function(v) EV.HeadDotColor=v end})
XG:AddToggle('HeadDotFilled',{Text='Head Dot Filled',Default=true,Callback=function(v) EV.HeadDotFilled=v end})
XG:AddToggle('SkeletonEnabled',{Text='Skeleton',Default=false,Callback=function(v) EV.SkeletonEnabled=v end})
  :AddColorPicker('SkeletonColor',{Text='Color',Default=PINK,Callback=function(v) EV.SkeletonColor=v end})
XG:AddToggle('LookDirectionEnabled',{Text='Look Direction',Default=false,Callback=function(v) EV.LookDirectionEnabled=v end})
  :AddColorPicker('LookDirectionColor',{Text='Color',Default=PINK,Callback=function(v) EV.LookDirectionColor=v end})
XG:AddSlider('LookDirectionLength',{Text='Look Length',Default=4,Min=1,Max=20,Rounding=0,Callback=function(v) EV.LookDirectionLength=v end})
XG:AddToggle('OffscreenArrow',{Text='Offscreen Arrow',Default=false,Callback=function(v) EV.OffscreenArrow=v end})
  :AddColorPicker('OffscreenArrowColor',{Text='Color',Default=PINK,Callback=function(v) EV.OffscreenArrowColor=v end})
XG:AddSlider('OffscreenArrowRadius',{Text='Arrow Radius',Default=120,Min=60,Max=250,Rounding=0,Callback=function(v) EV.OffscreenArrowRadius=v end})
XG:AddSlider('OffscreenArrowSize',{Text='Arrow Size',Default=14,Min=6,Max=30,Rounding=0,Callback=function(v) EV.OffscreenArrowSize=v end})

-- ==================== SMOOTHNESS ====================
local function getSmooth(curLook, tDir, intensity)
    if intensity <= 0 then return 0 end
    if intensity >= 1 then return 1 end
    if smoothnessType == "Linear" then return intensity
    elseif smoothnessType == "Ease Out" then return 1-(1-intensity)^3
    elseif smoothnessType == "Dynamic" then
        local angle = math.acos(math.clamp(curLook:Dot(tDir),-1,1))
        return intensity * math.clamp(angle/math.pi,0,1)
    end
    return intensity
end

-- ==================== MAIN RENDER LOOP ====================
-- KEY DESIGN:
--   * FOV circle visibility is driven ONLY by fovEnabled and fovThickness Lua vars via syncFOV().
--   * Aimbot reads fovEnabled and fovRadius Lua vars directly — never touches fovCircle properties.
--   * ESP has zero awareness of FOV anything. It runs on its own player list scan every frame.

RunService.RenderStepped:Connect(function()

    -- ── FOV CIRCLE ──────────────────────────────────────────────────
    -- Just keep it centered. syncFOV() already handled visibility.
    if fovEnabled and fovThickness > 0 then
        fovCircle.Position = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2)
    end

    -- ── AIMBOT ──────────────────────────────────────────────────────
    -- Works whether FOV is on or off.
    -- When FOV is ON:  only snaps to targets within fovRadius of screen center.
    -- When FOV is OFF: snaps to closest target anywhere on screen (no radius cap).
    if AimbotEnabled then
        local center = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2)
        local cap    = fovEnabled and fovRadius or math.huge  -- use our Lua var, not fovCircle.Radius

        local best, bestDist = nil, math.huge

        local function tryModel(model)
            if not isValidTarget(model) or not isValidCharacter(model) then return end
            local part = model:FindFirstChild(targetPart)
            if not part then return end
            local sp, on = Camera:WorldToViewportPoint(part.Position)
            if not on or sp.Z <= 0 then return end
            local d = (Vector2.new(sp.X, sp.Y) - center).Magnitude
            if d < cap and d < bestDist then
                best = model; bestDist = d
            end
        end

        if isSpecialGame and workspace:FindFirstChild("Characters") then
            for _, m in ipairs(workspace.Characters:GetChildren()) do tryModel(m) end
        else
            for _, p in ipairs(Players:GetPlayers()) do
                if p ~= LocalPlayer and p.Character then tryModel(p.Character) end
            end
        end

        if best then
            local part = best:FindFirstChild(targetPart)
            if part then
                local blocked = false
                if wallCheck then
                    local origin = Camera.CFrame.Position
                    local rp = RaycastParams.new()
                    rp.FilterDescendantsInstances = {LocalPlayer.Character, best}
                    rp.FilterType = Enum.RaycastFilterType.Blacklist
                    local res = workspace:Raycast(origin, part.Position - origin, rp)
                    if res and res.Instance then blocked = true end
                end
                if not blocked then
                    local cur    = Camera.CFrame
                    local tDir   = (part.Position - cur.Position).Unit
                    local smooth = getSmooth(cur.LookVector, tDir, smoothIntensity)
                    Camera.CFrame = CFrame.new(cur.Position, cur.Position + cur.LookVector:Lerp(tDir, smooth))
                end
            end
        end
    end

    -- ── ESP ─────────────────────────────────────────────────────────
    -- Completely standalone. Not gated by FOV toggle, FOV radius, or anything else.
    if espEnabled then
        local seen = {}

        local function proc(model)
            if model == LocalPlayer.Character then return end
            if not isValidCharacter(model) then return end
            if not isValidTarget(model) then return end
            seen[model] = true
            if not espObjects[model] then createESP(model) end
            updateESP(model, espObjects[model])
        end

        if isSpecialGame and workspace:FindFirstChild("Characters") then
            for _, m in ipairs(workspace.Characters:GetChildren()) do proc(m) end
        else
            for _, p in ipairs(Players:GetPlayers()) do
                if p ~= LocalPlayer and p.Character then proc(p.Character) end
            end
        end

        for model in pairs(espObjects) do
            if not seen[model] then
                hideESP(espObjects[model])
                removeESP(model)
            end
        end
    else
        for _, o in pairs(espObjects) do hideESP(o) end
    end
end)

-- ==================== CREDITS & SETTINGS ====================
Tabs.Credits:AddLeftGroupbox('Credits'):AddLabel('Script by PolleserHub')

local MG = Tabs['UI Settings']:AddLeftGroupbox('Menu')
MG:AddButton('Unload GUI', function()
    for m in pairs(espObjects) do removeESP(m) end
    fovCircle:Remove()
    Library:Unload()
end)
MG:AddLabel('Menu Keybind'):AddKeyPicker('MenuKeybind',{Default='End',NoUI=true,Text='Menu keybind'})
Library.ToggleKeybind = Options.MenuKeybind

ThemeManager:SetLibrary(Library)
SaveManager:SetLibrary(Library)
SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({'MenuKeybind'})
ThemeManager:SetFolder('PolleserHub')
SaveManager:SetFolder('PolleserHub/Config')
SaveManager:BuildConfigSection(Tabs['UI Settings'])
ThemeManager:ApplyToTab(Tabs['UI Settings'])