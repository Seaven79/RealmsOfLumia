-- REALMS OF LUMIA V20 - PREMIUM WORLD ART PASS
-- Original procedural stylized scenery, not World Zero assets or copied locations.
-- Additive and strictly CLIENT-SIDE; no physics, server networking, saves or quest edits.
-- Runtime art: stop/play after installation or rollback to refresh visuals.
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local world = ReplicatedStorage:WaitForChild("Lumia"):WaitForChild("Shared"):WaitForChild("World")
local cfg = require(world:WaitForChild("LumiaPremiumWorldConfig"))
local graphics = require(script.Parent:WaitForChild("GraphicsManager"))
if not cfg.Enabled then return end
local quality = graphics.GetProfile()
local preset = cfg.Presets[quality.Name] or cfg.Presets.Balanced
local forest = Workspace:WaitForChild("ForgottenForest", 40)
if not forest then warn("[Lumia V20] Original ForgottenForest missing; art safely skipped") return end
local grass = graphics.WaitForGround(forest)
if not grass or not grass:IsA("BasePart") then
    warn("[Lumia V20] Existing Grassland missing; premium art safely skipped")
    return
end

local old = Workspace:FindFirstChild("LumiaPremiumWorldV20")
if old then old:Destroy() end
local decor = Instance.new("Folder")
decor.Name = "LumiaPremiumWorldV20"
decor.Parent = Workspace
local oldGrade = Lighting:FindFirstChild("LumiaPremiumWorldGradeV20")
if oldGrade and not oldGrade:IsA("ColorCorrectionEffect") then
    warn("[Lumia V20] Local grade name occupied; grade skipped")
end
local grade = not oldGrade and Instance.new("ColorCorrectionEffect") or (oldGrade:IsA("ColorCorrectionEffect") and oldGrade or nil)
if grade then
    grade.Name = "LumiaPremiumWorldGradeV20"
    grade.Enabled = true
    grade.Brightness = 0
    grade.Contrast = 0.04
    grade.Saturation = 0.08
    grade.TintColor = Color3.fromRGB(255, 241, 216)
    grade.Parent = Lighting
end

local rng = Random.new(cfg.Seed)
local partCount, lightCount, particleCount, regionCount = 0, 0, 0, 0
local maxParts = preset.PartBudget
local regions = {}
local halfGrass = grass.Size.X * 0.5
local spawn = Workspace:FindFirstChild("LumiaSceneryAnchor", true)
    or Workspace:FindFirstChild("LumiaPlayerSpawnAnchor", true)
    or Workspace:FindFirstChildWhichIsA("SpawnLocation", true)
local localSpawn = spawn and grass.CFrame:PointToObjectSpace(spawn.Position) or Vector3.zero
for _, def in ipairs(cfg.Regions) do
    local item = table.clone(def)
    if item.Outer then
        item.X = halfGrass + 62.5 + (item.Outer - 1) * 125
        item.Z = 0
    elseif item.Id == "Hamlet" then
        item.X = localSpawn.X
        item.Z = localSpawn.Z
    end
    item.Built = false
    item.Attempts = 0
    regions[#regions + 1] = item
end

local markers = {}
local questCfg = require(ReplicatedStorage.Lumia.Shared:WaitForChild("Quests"):WaitForChild("QuestConfig"))
for _, m in ipairs(questCfg.Markers or {}) do
    if type(m.X) == "number" and type(m.Z) == "number" then
        markers[#markers + 1] = Vector2.new(m.X, m.Z)
    end
end

local function create(name, position, size, color, material, shape, transparency, rotation)
    if partCount >= maxParts then return nil end
    local p = Instance.new("Part")
    p.Name = name
    p.Size = size
    p.CFrame = CFrame.new(position) * (rotation or CFrame.identity)
    p.Material = material or Enum.Material.SmoothPlastic
    p.Color = color
    p.Shape = shape or Enum.PartType.Block
    p.Transparency = transparency or 0
    p.Anchored = true
    p.CanCollide, p.CanTouch, p.CanQuery = false, false, false
    p.CastShadow = false -- original trees/landmarks provide the large world shadows
    p.TopSurface = Enum.SurfaceType.Smooth
    p.BottomSurface = Enum.SurfaceType.Smooth
    p.Parent = decor
    partCount += 1
    return p
end

local function glow(host, color, range, strength)
    if not host or lightCount >= preset.Lights then return end
    local lamp = Instance.new("PointLight")
    lamp.Color = color
    lamp.Range = range or 11
    lamp.Brightness = strength or 0.7
    lamp.Shadows = false
    lamp.Parent = host
    lightCount += 1
end

local function motes(host, color, count)
    if not host or preset.ParticleRate <= 0 or particleCount >= 7 then return end
    local dust = Instance.new("ParticleEmitter")
    dust.Name = "LumiaFantasyMotes"
    dust.Texture = "rbxasset://textures/particles/sparkles_main.dds"
    dust.Rate = (count or 1) * preset.ParticleRate
    dust.Lifetime = NumberRange.new(2.2, 5.0)
    dust.Speed = NumberRange.new(0.1, 0.4)
    dust.SpreadAngle = Vector2.new(50, 50)
    dust.Color = ColorSequence.new(color)
    dust.LightEmission = 0.4
    dust.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(.4, .13), NumberSequenceKeypoint.new(1, 0)})
    dust.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(.4, .3), NumberSequenceKeypoint.new(1, 1)})
    dust.Parent = host
    particleCount += 1
end

local ray = RaycastParams.new()
ray.FilterType = Enum.RaycastFilterType.Exclude
ray.RespectCanCollide = true
ray.IgnoreWater = true
local overlap = OverlapParams.new()
overlap.FilterType = Enum.RaycastFilterType.Exclude
overlap.MaxParts = 65

local function isFloor(hit)
    if not hit then return false end
    local instance = hit.Instance
    return instance == grass or instance:IsA("Terrain") or instance.Name == "ThornwatchGround"
        or instance.Name == "FirstGateGround"
end
local function nearMarker(localX, localZ, distance)
    for _, pt in ipairs(markers) do
        local dx, dz = localX - pt.X, localZ - pt.Y
        if dx * dx + dz * dz < distance * distance then return true end
    end
    local dx, dz = localX - localSpawn.X, localZ - localSpawn.Z
    return dx * dx + dz * dz < 13 * 13
end
local function groundAt(localX, localZ, clearance)
    if nearMarker(localX, localZ, clearance + 6) then return nil end
    local origin = grass.CFrame:PointToWorldSpace(Vector3.new(localX, grass.Size.Y * .5 + 135, localZ))
    local excluded = {decor}
    if player.Character then excluded[#excluded + 1] = player.Character end
    local mobs = Workspace:FindFirstChild("LumiaMonsters")
    if mobs then excluded[#excluded + 1] = mobs end
    ray.FilterDescendantsInstances = excluded
    local hit = Workspace:Raycast(origin, Vector3.new(0, -365, 0), ray)
    if not isFloor(hit) or hit.Normal.Y < .86 then return nil end
    local ignore = {decor, hit.Instance, grass}
    local forestExtras = Workspace:FindFirstChild("LumiaClientForestDecor")
    local oldExtras = Workspace:FindFirstChild("LumiaRegionBeautyV19")
    if forestExtras then ignore[#ignore + 1] = forestExtras end
    if oldExtras then ignore[#ignore + 1] = oldExtras end
    if player.Character then ignore[#ignore + 1] = player.Character end
    overlap.FilterDescendantsInstances = ignore
    local nearby = Workspace:GetPartBoundsInBox(CFrame.new(hit.Position + Vector3.new(0, 3.6, 0)),
        Vector3.new(clearance * 2, 6.8, clearance * 2), overlap)
    for _, object in ipairs(nearby) do
        if object:IsA("BasePart") and object.CanCollide then return nil end
    end
    return hit.Position
end

local function findSpot(region, clearance, extraX, extraZ)
    for i = 1, 20 do
        local x = region.X + (extraX or 0) + rng:NextNumber(-region.Radius * .63, region.Radius * .63)
        local z = region.Z + (extraZ or 0) + rng:NextNumber(-region.Radius * .69, region.Radius * .69)
        local dx, dz = x - region.X, z - region.Z
        if dx * dx + dz * dz < region.Radius ^ 2 and not (region.Outer and math.abs(z) < 19) then
            local pt = groundAt(x, z, clearance)
            if pt then return pt end
        end
    end
    return nil
end
local function choose(a,b) return rng:NextNumber() < .5 and a or b end
local function rotY(angle) return CFrame.Angles(0, angle, 0) end

local function canopyTree(p, pal, style)
    local height = rng:NextNumber(12, 19)
    if style == "Thorn" or style == "Gate" then height += 5 end
    create("SculptedTrunk", p + Vector3.new(0, height*.33, 0), Vector3.new(1.45, height*.66, 1.35), pal.Bark, Enum.Material.Wood)
    local branchY = height * .55
    for branch = 1, 3 do
        local a = branch * 2.094 + rng:NextNumber(-.25, .25)
        local offset = Vector3.new(math.cos(a)*2, branchY + (branch%2)*1.5, math.sin(a)*2)
        create("SculptedBranch", p + offset, Vector3.new(1.05, 5.5, 1.03), pal.Bark,
            Enum.Material.Wood, nil, 0, CFrame.Angles(math.sin(a)*.58, 0, math.cos(a)*.58))
    end
    local scale = style == "Creek" and 1.08 or 1
    for layer = 1, 5 do
        local a = layer * 2.41
        local x,z = math.sin(a)*3.1, math.cos(a)*2.65
        local y = height * (.65 + (layer%3)*.08)
        local radius = (layer==5 and 6.8 or rng:NextNumber(6.5, 9.3)) * scale
        create("RoundedLeafMass", p + Vector3.new(x, y, z), Vector3.new(radius, radius*.74, radius),
            layer%2==0 and pal.Alt or pal.Leaf, Enum.Material.Grass, Enum.PartType.Ball)
    end
    if style == "Ruins" or style == "Thorn" then
        create("AncientClimber", p + Vector3.new(0, 4, 0), Vector3.new(1.7, 5.4, 1.7),
            pal.Alt, Enum.Material.Grass, Enum.PartType.Ball, .35)
    end
end
local function fern(p, pal)
    for blade = 1, 4 do
        local angle = blade * 1.57 + rng:NextNumber(-.2,.2)
        local dir = Vector3.new(math.cos(angle), 0, math.sin(angle))
        create("ArchingFern", p + dir*.5 + Vector3.new(0, .75, 0),
            Vector3.new(.35, 1.9, .95), blade%2==0 and pal.Alt or pal.Leaf,
            Enum.Material.Grass, nil, 0, rotY(angle) * CFrame.Angles(.5,0,.3))
    end
end
local function shrub(p, pal)
    for i=1,4 do
        local a=i*1.57
        create("LeafShrub", p + Vector3.new(math.sin(a)*.85,.7,math.cos(a)*.75),
            Vector3.new(2.2,1.8,2.5), i%2==0 and pal.Leaf or pal.Alt, Enum.Material.Grass, Enum.PartType.Ball)
    end
end
local function rockCluster(p, pal)
    local yaw = rng:NextNumber(0,math.pi*2)
    for i=1,3 do
        local a = yaw + i*2.09
        local size = rng:NextNumber(1.6,3.0)
        create("NaturalBoulder", p + Vector3.new(math.cos(a)*1.2,size*.23,math.sin(a)*1.2),
            Vector3.new(size*1.4,size*.7,size),pal.Rock,Enum.Material.Slate,Enum.PartType.Ball,
            0,rotY(a))
    end
end
local function wildflowers(p, pal)
    for i=1,5 do
        local angle=i*2.39
        local x,z = math.sin(angle)*.9,math.cos(angle)*.8
        local h=rng:NextNumber(.6,1.05)
        create("FlowerStalk", p+Vector3.new(x,h*.5,z),Vector3.new(.07,h,.07),pal.Leaf,Enum.Material.Grass)
        create("FantasyPetal",p+Vector3.new(x,h+.03,z),Vector3.new(.42,.26,.38),
            i%3==0 and pal.Accent or pal.Bloom,Enum.Material.SmoothPlastic,Enum.PartType.Ball)
    end
end
local function lantern(p, pal)
    create("CarvedOakPost",p+Vector3.new(0,2.8,0),Vector3.new(.35,5.6,.4),pal.Wood,Enum.Material.Wood)
    create("TimberCrossBeam",p+Vector3.new(.65,5.1,0),Vector3.new(1.65,.23,.3),pal.Wood,Enum.Material.Wood)
    local glass=create("WarmLantern",p+Vector3.new(1.25,4.5,0),Vector3.new(.68,1.05,.65),
        pal.Accent,Enum.Material.Glass,nil,.22)
    if glass then glow(glass,pal.Accent,14,.9) end
    create("LanternCap",p+Vector3.new(1.25,5.1,0),Vector3.new(.92,.24,.84),pal.Rock,Enum.Material.Metal)
end
local function markerText(host, label, accent)
    if not host then return end
    local gui=Instance.new("BillboardGui")
    gui.Name="LumiaHandCarvedTitle"
    gui.Size=UDim2.fromOffset(225,48)
    gui.StudsOffsetWorldSpace=Vector3.new(0,2.5,0)
    gui.MaxDistance=65
    gui.AlwaysOnTop=false
    gui.Parent=host
    local frame=Instance.new("TextLabel")
    frame.Size=UDim2.fromScale(1,1)
    frame.BackgroundColor3=Color3.fromRGB(25,26,31)
    frame.BackgroundTransparency=.32
    frame.TextColor3=accent
    frame.Font=Enum.Font.Garamond
    frame.TextSize=22
    frame.Text=label
    frame.Parent=gui
    local corner=Instance.new("UICorner")
    corner.CornerRadius=UDim.new(0,6)
    corner.Parent=frame
end
local function obelisk(p, pal, height, luminous)
    height = height or 11
    create("SanctuaryPlinth",p+Vector3.new(0,.5,0),Vector3.new(4.0,1.0,3.6),pal.Rock,Enum.Material.Slate)
    local pillar=create("SculptedStandingStone",p+Vector3.new(0,height*.5+.5,0),
        Vector3.new(2.3,height,2.0),pal.Rock,Enum.Material.Slate,nil,0,rotY(.24))
    if luminous then
        local symbol=create("AwakenedRune",p+Vector3.new(0,height*.58,1.15),
            Vector3.new(1.1,2.3,.12),pal.Accent,Enum.Material.Neon,nil,.16)
        if symbol then glow(symbol,pal.Accent,15,.58) end
    end
    return pillar
end
local function arc(p, radius, pal, runes)
    local steps = 14
    for i=1,steps do
        local t = (i/steps)*math.pi
        local a = (i-.5)/steps*math.pi
        local h = math.sin(a)*radius
        local x = math.cos(a)*radius
        create("ElderArchStone",p+Vector3.new(x,h+.5,0),Vector3.new(2.35,2.3,2.6),
            pal.Rock,Enum.Material.Slate,nil,0,CFrame.Angles(0,0,-a))
    end
    if runes then
        local gem=create("SuspendedSoulCrystal",p+Vector3.new(0,radius*.52,0),
            Vector3.new(1.55,2.9,1.55),pal.Accent,Enum.Material.Neon,Enum.PartType.Ball,.3)
        if gem then glow(gem,pal.Accent,19,.6); motes(gem,pal.Accent,1) end
    end
end
local function carvedSign(p, pal, title)
    create("TownSignPost",p+Vector3.new(0,2.4,0),Vector3.new(.45,4.8,.45),pal.Bark,Enum.Material.Wood)
    local panel=create("CarvedSign",p+Vector3.new(0,4.65,.15),Vector3.new(5.5,1.75,.4),pal.Wood,Enum.Material.WoodPlanks)
    if panel then markerText(panel,title,pal.Accent) end
end
local function villagePavilion(p, pal)
    for _,x in ipairs({-3.6,3.6}) do
        for _,z in ipairs({-2.8,2.8}) do
            create("VillageOakFrame",p+Vector3.new(x,3.5,z),Vector3.new(.42,7,.42),pal.Wood,Enum.Material.Wood)
        end
    end
    for i=-3,3 do
        create("ArtisanCanvasRoof",p+Vector3.new(i*1.15,7.22-math.abs(i)*.18,0),
            Vector3.new(1.25,.28,6.8),i%2==0 and Color3.fromRGB(218,190,129) or Color3.fromRGB(142,96,75),
            Enum.Material.Fabric,nil,0,CFrame.Angles(0,0,i*.04))
    end
    create("FestivalTable",p+Vector3.new(0,1.55,0),Vector3.new(6,.35,2.25),pal.Wood,Enum.Material.WoodPlanks)
    for i=1,4 do
        create("VillageGift",p+Vector3.new(-2.1+i,2.15,0),Vector3.new(.7,.65,.65),
            i%2==0 and pal.Leaf or pal.Accent,Enum.Material.WoodPlanks)
    end
    lantern(p+Vector3.new(-4.7,0,-2.9),pal)
end
local function tradeCart(p,pal)
    create("WeatheredCartBox",p+Vector3.new(0,2.15,0),Vector3.new(5.6,1.5,3.4),pal.Wood,Enum.Material.WoodPlanks)
    for _,x in ipairs({-2,2}) do
        for _,z in ipairs({-2,2}) do
            local wheel=create("OldCartWheel",p+Vector3.new(x,1.1,z),Vector3.new(.45,2.2,2.2),pal.Bark,Enum.Material.Wood,Enum.PartType.Cylinder,
                0,CFrame.Angles(0,0,0))
            if wheel then
                create("IronHub",wheel.Position,Vector3.new(.55,.55,.55),pal.Rock,Enum.Material.Metal,Enum.PartType.Ball)
            end
        end
    end
    for i=-1,1 do create("SuppliesSack",p+Vector3.new(i*1.3,3.2,0),Vector3.new(1.1,.8,.9),
        Color3.fromRGB(174,151,111),Enum.Material.Fabric,Enum.PartType.Ball) end
    carvedSign(p+Vector3.new(8,0,-4),pal,"OLD ROAD")
end
local function waterGarden(p,pal)
    -- Scenic pool is visual only; this does not carve or flood Terrain.
    create("CrystalClearPool",p+Vector3.new(0,.16,0),Vector3.new(13,.16,8),
        Color3.fromRGB(63,167,166),Enum.Material.Glass,Enum.PartType.Ball,.28)
    for i=1,9 do
        local a=i*math.pi*2/9
        local x,z=math.cos(a)*6.6,math.sin(a)*4.45
        create("CreekBankStone",p+Vector3.new(x,.26,z),Vector3.new(2.5,.7,1.8),pal.Rock,
            Enum.Material.Slate,Enum.PartType.Ball,0,rotY(a))
        if i%2==0 then fern(p+Vector3.new(x*1.18,0,z*1.26),pal) end
    end
    local falls=create("SilverWaterVeil",p+Vector3.new(-3.5,2.6,-3.4),
        Vector3.new(5.2,5.2,.16),Color3.fromRGB(150,226,226),Enum.Material.Glass,nil,.42)
    if falls then motes(falls,pal.Accent,1.1) end
end
local function sanctuary(p,pal)
    for i=1,5 do
        local a=i*math.pi*2/5
        obelisk(p+Vector3.new(math.sin(a)*8,0,math.cos(a)*8),pal,7+i%2*2,i%2==0)
    end
    local orb=create("MoonstoneHeart",p+Vector3.new(0,5.5,0),Vector3.new(3.3,3.3,3.3),
        pal.Accent,Enum.Material.Neon,Enum.PartType.Ball,.39)
    if orb then glow(orb,pal.Accent,23,.85); motes(orb,pal.Accent,.85) end
    for i=1,12 do
        local a=i*math.pi/6
        create("SanctuaryGlyph",p+Vector3.new(math.cos(a)*4,.25,math.sin(a)*4),
            Vector3.new(1.15,.12,.33),pal.Accent,Enum.Material.Neon,nil,.45,rotY(-a))
    end
end
local function thornWatch(p,pal)
    obelisk(p+Vector3.new(-6,0,4),pal,9,true)
    obelisk(p+Vector3.new(7,0,-3),pal,8,false)
    for i=1,5 do
        local a=i*1.24
        create("TwistedRoot",p+Vector3.new(math.sin(a)*6,1.4,math.cos(a)*5),
            Vector3.new(1.1,4,1.2),pal.Bark,Enum.Material.Wood,nil,0,CFrame.Angles(.4,0,.4))
    end
end
local function firstGate(p,pal)
    arc(p,12,pal,true)
    for _,side in ipairs({-1,1}) do
        obelisk(p+Vector3.new(side*12,0,-1),pal,13,true)
    end
    for i=1,10 do
        local a=i*math.pi/5
        create("AzureCircleRune",p+Vector3.new(math.cos(a)*7,.28,math.sin(a)*7),
            Vector3.new(1.6,.13,.42),pal.Accent,Enum.Material.Neon,nil,.3,rotY(-a))
    end
end

local function grandFeature(region,pal)
    local offX = region.Outer and -20 or (region.Id == "Hamlet" and 18 or 7)
    local offZ = region.Outer and 31 or (region.Id == "Hamlet" and -19 or 8)
    local p = groundAt(region.X+offX,region.Z+offZ,region.Id=="Hamlet" and 7 or 8)
    if not p then
        p = findSpot(region,8,0,region.Outer and 20 or 0)
    end
    if not p then return end
    if region.Major=="Village" then
        villagePavilion(p,pal)
    elseif region.Major=="ElderGrove" then
        canopyTree(p,pal,"Trail")
        for i=1,4 do rockCluster(p+Vector3.new(math.cos(i*1.57)*8,0,math.sin(i*1.57)*8),pal) end
    elseif region.Major=="Cart" then
        tradeCart(p,pal)
    elseif region.Major=="WaterGarden" then
        waterGarden(p,pal)
    elseif region.Major=="RuinedSanctuary" then
        sanctuary(p,pal)
    elseif region.Major=="ThornWatch" then
        thornWatch(p,pal)
    elseif region.Major=="FirstGate" then
        firstGate(p,pal)
    end
end

local function buildRegion(region)
    region.Attempts += 1
    local pal=cfg.Palettes[region.Style]
    local built = 0
    -- Landmarks, vegetation and props are visual and do not obstruct player movement.
    local before = partCount
    grandFeature(region,pal)
    for i=1,preset.Trees do
        local at=findSpot(region,4)
        if at then canopyTree(at,pal,region.Style) end
        if i%3==0 then task.wait() end
    end
    for i=1,preset.Shrubs do
        local at=findSpot(region,2.3)
        if at then shrub(at,pal) end
        if i%4==0 then task.wait() end
    end
    for i=1,preset.Rocks do
        local at=findSpot(region,2)
        if at then rockCluster(at,pal) end
        if i%4==0 then task.wait() end
    end
    for i=1,preset.Foliage do
        local at=findSpot(region,1.15)
        if at then
            if i%3==0 then fern(at,pal) else wildflowers(at,pal) end
        end
        if i%6==0 then task.wait() end
    end
    if region.Style=="Hamlet" or region.Style=="Road" then
        for i=1,preset.Lanterns do
            local at=findSpot(region,3)
            if at then lantern(at,pal) end
        end
    end
    built=partCount-before
    if built>0 then
        region.Built=true
        regionCount+=1
        print(string.format("[Lumia V20] %s: %d premium art parts, total %d/%d",region.Id,built,partCount,maxParts))
    end
end

-- Stream new scenery only as the player approaches; don't assume remote ground exists at join.
local currentStyle = "Hamlet"
local styleCandidate, candidateTime, gradeTween
local function nearestRegion(position)
    local localPos=grass.CFrame:PointToObjectSpace(position)
    local closest,distance
    for _,region in ipairs(regions) do
        local dx=localPos.X-region.X
        local dz=localPos.Z-region.Z
        local d=dx*dx+dz*dz
        if not distance or d<distance then closest,distance=region,d end
    end
    return closest,distance
end
local function setRegionStyle(style)
    if not grade or style == currentStyle then return end
    currentStyle=style
    local settings=cfg.Grades[style] or cfg.Grades.Hamlet
    if gradeTween then gradeTween:Cancel() end
    gradeTween=TweenService:Create(grade,TweenInfo.new(3.1,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut),{
        TintColor=settings.Tint,Saturation=settings.Saturation,Contrast=settings.Contrast,
    })
    gradeTween:Play()
end

task.spawn(function()
    while decor.Parent==Workspace do
        local character=player.Character
        local root=character and character:FindFirstChild("HumanoidRootPart")
        if root then
            local nearest,dist=nearestRegion(root.Position)
            if nearest then
                local now=os.clock()
                if nearest.Style~=styleCandidate then styleCandidate=nearest.Style;candidateTime=now end
                if now-(candidateTime or now)>=2.3 then setRegionStyle(nearest.Style) end
                -- Build all nearby regions once, not every time a boundary is crossed.
                for _,region in ipairs(regions) do
                    if not region.Built and region.Attempts<9 then
                        local where=grass.CFrame:PointToWorldSpace(Vector3.new(region.X,0,region.Z))
                        if (where-root.Position).Magnitude<=cfg.DistanceToBuild and partCount<maxParts then
                            buildRegion(region)
                        end
                    end
                end
            end
        end
        task.wait(cfg.RefreshSeconds)
    end
end)
print("[Lumia V20] Premium world pass started | "..quality.Name.." quality, local part cap "..maxParts)
