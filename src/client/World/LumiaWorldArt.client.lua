-- REALMS OF LUMIA V19.1 | WORLD ART POLISH
-- Everything created here lives on the client. No physics, combat, saving,
-- quest positions, replicated map geometry or server-side performance costs.
-- Requires V19's open-world ground. Works with Roblox StreamingEnabled.
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local SharedWorld = ReplicatedStorage:WaitForChild("Lumia"):WaitForChild("Shared"):WaitForChild("World")
local Art = require(SharedWorld:WaitForChild("LumiaWorldArtConfig"))
local GraphicsManager = require(script.Parent:WaitForChild("GraphicsManager"))
local QuestConfig = require(ReplicatedStorage.Lumia.Shared:WaitForChild("Quests"):WaitForChild("QuestConfig"))
if not Art.Enabled then return end

local forest = Workspace:WaitForChild("ForgottenForest", 40)
if not forest then warn("[Lumia Art V19.1] Forest unavailable; art pass safely skipped") return end
local grass = GraphicsManager.WaitForGround(forest)
if not grass then warn("[Lumia Art V19.1] Grassland unavailable; art pass safely skipped") return end
local profile = GraphicsManager.GetProfile()
local preset = Art.Presets[profile.Name] or Art.Presets.Balanced
local rng = Random.new(Art.Seed)

-- A new local-only folder is idempotent; destroying it never changes saved map parts.
local old = Workspace:FindFirstChild("LumiaWorldArtV191")
if old then old:Destroy() end
local decor = Instance.new("Folder")
decor.Name = "LumiaWorldArtV191"
decor.Parent = Workspace

local villageSpawn = Workspace:FindFirstChild("LumiaSceneryAnchor", true)
    or Workspace:FindFirstChild("LumiaPlayerSpawnAnchor", true)
    or Workspace:FindFirstChildWhichIsA("SpawnLocation", true)
local villageLocal = villageSpawn and grass.CFrame:PointToObjectSpace(villageSpawn.Position) or Vector3.zero
local halfWidth = grass.Size.X * 0.5
local regionList = {}
for _, region in ipairs(Art.Regions) do
    local entry = table.clone(region)
    if entry.Outer then
        entry.X = halfWidth + 62.5 + (entry.Outer - 1) * 125
        entry.Z = 0
    elseif entry.Id == "Village" then
        entry.X = villageLocal.X
        entry.Z = villageLocal.Z
    end
    regionList[#regionList + 1] = entry
end

local forbidden = {}
for _, marker in ipairs(QuestConfig.Markers or {}) do
    if type(marker.X) == "number" and type(marker.Z) == "number" then
        forbidden[#forbidden + 1] = Vector2.new(marker.X, marker.Z)
    end
end

local treeCount, shrubCount, detailCount, partCount, lightCount = 0, 0, 0, 0, 0
local partLimit = preset.PartBudget
local function make(name, size, cf, color, material, shape, transparency)
    if partCount >= partLimit then return nil end
    local object = Instance.new("Part")
    object.Name = name
    object.Size = size
    object.CFrame = cf
    object.Color = color
    object.Material = material
    object.Shape = shape or Enum.PartType.Block
    object.Transparency = transparency or 0
    object.Anchored = true
    object.CanCollide = false
    object.CanTouch = false
    object.CanQuery = false
    object.CastShadow = false -- decorative shadows are expensive on low-end devices
    object.TopSurface = Enum.SurfaceType.Smooth
    object.BottomSurface = Enum.SurfaceType.Smooth
    object.Parent = decor
    partCount += 1
    return object
end

local function safelyAddLight(host, color)
    if not preset.Lights or not host or lightCount >= 8 then return end
    local light = Instance.new("PointLight")
    light.Color = color
    light.Brightness = 0.65
    light.Range = 12
    light.Shadows = false
    light.Parent = host
    lightCount += 1
end

local ray = RaycastParams.new()
ray.FilterType = Enum.RaycastFilterType.Exclude
ray.RespectCanCollide = true
ray.IgnoreWater = true
local overlap = OverlapParams.new()
overlap.FilterType = Enum.RaycastFilterType.Exclude
-- Only use original and V19 generated floor. Skip rooftops, bridges and props.
local function isGround(hit)
    if not hit or not hit.Instance then return false end
    local instance = hit.Instance
    return instance == grass or instance:IsA("Terrain")
        or instance.Name == "ThornwatchGround"
        or instance.Name == "FirstGateGround"
end
local function nearRelic(x, z, radius)
    for _, point in ipairs(forbidden) do
        local dx, dz = x - point.X, z - point.Y
        if dx * dx + dz * dz <= radius * radius then return true end
    end
    return false
end
local function protectedSpace(point, clearance)
    local ignored = {decor, grass}
    local forestDecor = Workspace:FindFirstChild("LumiaClientForestDecor")
    if forestDecor then ignored[#ignored + 1] = forestDecor end
    local legacyDecor = Workspace:FindFirstChild("LumiaRegionBeautyV19")
    if legacyDecor then ignored[#ignored + 1] = legacyDecor end
    local character = Players.LocalPlayer.Character
    if character then ignored[#ignored + 1] = character end
    overlap.FilterDescendantsInstances = ignored
    overlap.MaxParts = 65
    local hits = Workspace:GetPartBoundsInBox(CFrame.new(point + Vector3.new(0, 3.5, 0)),
        Vector3.new(clearance * 2, 7, clearance * 2), overlap)
    for _, object in ipairs(hits) do
        if object:IsA("BasePart") and object.CanCollide
            and object.Name ~= "ThornwatchGround"
            and object.Name ~= "FirstGateGround" then
            return true
        end
    end
    return false
end
local function groundAt(x, z, clearance)
    if nearRelic(x, z, clearance + 5) then return nil end
    local test = grass.CFrame:PointToWorldSpace(Vector3.new(x, grass.Size.Y * 0.5 + 160, z))
    local filter = {decor}
    local char = Players.LocalPlayer.Character
    if char then filter[#filter + 1] = char end
    local monsters = Workspace:FindFirstChild("LumiaMonsters")
    if monsters then filter[#filter + 1] = monsters end
    ray.FilterDescendantsInstances = filter
    local hit = Workspace:Raycast(test, Vector3.new(0, -410, 0), ray)
    if not isGround(hit) or hit.Normal.Y < 0.91 then return nil end
    if protectedSpace(hit.Position, clearance) then return nil end
    return hit.Position
end
local function pickPoint(region, clearance, tries)
    for _ = 1, tries or 9 do
        local x = region.X + rng:NextNumber(-region.SpanX, region.SpanX)
        local z = region.Z + rng:NextNumber(-region.SpanZ, region.SpanZ)
        if region.Outer and math.abs(z) < 18 then
            z = z < 0 and -(18 + rng:NextNumber(0, 11)) or (18 + rng:NextNumber(0, 11))
        end
        -- Keep the main hamlet plaza and player spawn free of tall props.
        if region.Id ~= "Village" or (x - region.X)^2 + (z - region.Z)^2 >= 14^2 then
            local result = groundAt(x, z, clearance)
            if result then return result end
        end
    end
    return nil
end

local function tree(where, pal, style)
    local tall = rng:NextNumber(10, 16)
    if style == "Thorn" or style == "Gate" then tall *= 1.17 end
    local trunk = make("AncientBark", Vector3.new(1.5, tall * .72, 1.5),
        CFrame.new(where + Vector3.new(0, tall * .36, 0)), pal.Bark, Enum.Material.Wood)
    if not trunk then return end
    local canopyColor = rng:NextNumber() < .5 and pal.Leaf or pal.Leaf2
    local layers = (style == "Thorn" or style == "Gate") and 3 or 4
    for n = 1, layers do
        local scale = n == 1 and 1 or 0.86
        local offsetX = rng:NextNumber(-1.6, 1.6)
        local offsetZ = rng:NextNumber(-1.4, 1.4)
        local size = rng:NextNumber(5.5, 7.8) * scale
        make("LeafyCanopy", Vector3.new(size, size * .76, size),
            CFrame.new(where + Vector3.new(offsetX, tall * (.67 + (n % 2) * .10), offsetZ)),
            n % 2 == 0 and pal.Leaf2 or canopyColor, Enum.Material.Grass, Enum.PartType.Ball)
    end
    if style == "Meadow" and rng:NextNumber() < .45 then
        for n = 1, 3 do
            local angle = n * (math.pi * 2 / 3)
            make("Roots", Vector3.new(0.8, 0.45, 2.2),
                CFrame.new(where + Vector3.new(math.sin(angle) * .5, .25, math.cos(angle) * .5))
                * CFrame.Angles(0, angle, 0), pal.Bark, Enum.Material.Wood)
        end
    end
    treeCount += 1
end
local function bush(where, pal, style)
    local scale = rng:NextNumber(.65, 1.2)
    for i = 1, 3 do
        local x = (i - 2) * .85
        make(style == "Creek" and "RiverShrub" or "ForestShrub",
            Vector3.new(2.5, 1.9, 2.3) * scale,
            CFrame.new(where + Vector3.new(x, 0.75 * scale, math.sin(i * 2) * .45)),
            i == 2 and pal.Leaf2 or pal.Leaf, Enum.Material.Grass, Enum.PartType.Ball)
    end
    shrubCount += 1
end
local function stones(where, pal)
    local scale = rng:NextNumber(.6, 1.2)
    local p = make("MossyStone", Vector3.new(3.3, 1.45, 2.2) * scale,
        CFrame.new(where + Vector3.new(0, .50 * scale, 0))
        * CFrame.Angles(0, rng:NextNumber(0, 6.2), 0),
        pal.Rock, Enum.Material.Slate, Enum.PartType.Ball)
    if p and rng:NextNumber() < .75 then
        make("StoneMoss", Vector3.new(2.2, .24, 1.45) * scale,
            p.CFrame * CFrame.new(0, .68 * scale, 0), pal.Leaf, Enum.Material.Grass, Enum.PartType.Ball)
    end
end
local function flowerCluster(where, pal, style)
    for i = 1, 3 do
        local x = rng:NextNumber(-.8, .8)
        local z = rng:NextNumber(-.8, .8)
        local h = rng:NextNumber(.5, 1.1)
        local stalk = make(style == "Creek" and "WetlandReed" or "MeadowStem",
            Vector3.new(.09, h, .09), CFrame.new(where + Vector3.new(x, h/2, z)),
            pal.Leaf2, Enum.Material.Grass)
        if style ~= "Thorn" and style ~= "Gate" then
            make("WildPetal", Vector3.new(.31, .18, .31),
                CFrame.new(where + Vector3.new(x, h, z)), pal.Accent,
                Enum.Material.SmoothPlastic, Enum.PartType.Ball)
        end
    end
    detailCount += 1
end
local function lantern(where, pal)
    local post = make("RoadsideLanternPost", Vector3.new(.34, 4.8, .34),
        CFrame.new(where + Vector3.new(0, 2.4, 0)), Color3.fromRGB(104, 77, 50), Enum.Material.Wood)
    make("RoadsideLanternBracket", Vector3.new(1.5, .19, .2),
        CFrame.new(where + Vector3.new(.58, 4.4, 0)), Color3.fromRGB(104, 77, 50), Enum.Material.Wood)
    local lamp = make("LanternGlass", Vector3.new(.65, .78, .65),
        CFrame.new(where + Vector3.new(1.08, 3.92, 0)), pal.Accent, Enum.Material.Glass, nil, .18)
    safelyAddLight(lamp, pal.Accent)
    return post
end
local function standingStone(where, pal)
    local yaw = rng:NextNumber(-math.pi, math.pi)
    local pillar = make("OldKingdomStandingStone", Vector3.new(2.35, 7.3, 1.65),
        CFrame.new(where + Vector3.new(0, 3.65, 0))
        * CFrame.Angles(0, yaw, math.rad(rng:NextInteger(-4, 4))),
        pal.Rock, Enum.Material.Slate)
    if pillar then
        make("MoonlitRune", Vector3.new(.15, 1.65, 1.00),
            pillar.CFrame * CFrame.new(1.23, .35, 0),
            pal.Accent, Enum.Material.Neon, nil, .22)
    end
end
local function displaySign(where, title, pal)
    local board = make("WayfinderPost", Vector3.new(.35, 5.8, .4),
        CFrame.new(where + Vector3.new(0, 2.9, 0)), pal.Bark, Enum.Material.Wood)
    local plank = make("WayfinderSign", Vector3.new(5.9, 1.6, .3),
        CFrame.new(where + Vector3.new(.25, 4.45, 0)), pal.Bark, Enum.Material.WoodPlanks)
    if not plank then return end
    local gold = make("WayfinderGoldTrim", Vector3.new(6.1, .10, .37),
        CFrame.new(where + Vector3.new(.25, 5.27, 0)), pal.Accent, Enum.Material.Metal)
    local gui = Instance.new("SurfaceGui")
    gui.Name = "HandPaintedName"
    gui.Face = Enum.NormalId.Front
    gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
    gui.PixelsPerStud = 40
    gui.Parent = plank
    local label = Instance.new("TextLabel")
    label.Size = UDim2.fromScale(1, 1)
    label.BackgroundTransparency = 1
    label.Font = Enum.Font.Garamond
    label.TextScaled = true
    label.Text = title
    label.TextColor3 = Color3.fromRGB(255, 237, 197)
    label.TextStrokeTransparency = .55
    label.Parent = gui
    return board, gold
end
local function marketStall(where, pal)
    -- Four supports, a striped cloth canopy and a display counter.
    for _, x in ipairs({-2.7, 2.7}) do
        for _, z in ipairs({-1.7, 1.7}) do
            make("MarketTimber", Vector3.new(.3, 5.4, .3),
                CFrame.new(where + Vector3.new(x, 2.7, z)), pal.Bark, Enum.Material.Wood)
        end
    end
    make("MarketCounter", Vector3.new(5.9, .45, 3.4),
        CFrame.new(where + Vector3.new(0, 2.1, 0)), pal.Bark, Enum.Material.WoodPlanks)
    for i = -2, 2 do
        make("StripedMerchantAwning", Vector3.new(1.25, .22, 4.1),
            CFrame.new(where + Vector3.new(i * 1.22, 5.55, 0))
                * CFrame.Angles(0, 0, math.rad(i * -3)),
            i % 2 == 0 and Color3.fromRGB(162, 111, 72) or Color3.fromRGB(230, 202, 142),
            Enum.Material.Fabric)
    end
    for i = 1, 3 do
        make("MerchantBasket", Vector3.new(.9, .55, .9),
            CFrame.new(where + Vector3.new(-1.75 + i * 1.3, 2.65, .45)),
            Color3.fromRGB(135, 104, 67), Enum.Material.WoodPlanks)
    end
end
local function fireflies(where, pal)
    if preset.ParticleRate <= 0 then return end
    local anchor = make("FloatingPollenAnchor", Vector3.new(.2, .2, .2),
        CFrame.new(where + Vector3.new(0, 2.8, 0)), pal.Accent,
        Enum.Material.SmoothPlastic, nil, 1)
    if not anchor then return end
    local particle = Instance.new("ParticleEmitter")
    particle.Name = "SubtleForestMotes"
    particle.Texture = "rbxasset://textures/particles/sparkles_main.dds"
    particle.Rate = preset.ParticleRate
    particle.Lifetime = NumberRange.new(2.8, 4.6)
    particle.Speed = NumberRange.new(.10, .36)
    particle.SpreadAngle = Vector2.new(55, 55)
    particle.Color = ColorSequence.new(pal.Accent)
    particle.LightEmission = .25
    particle.Size = NumberSequence.new(.13)
    particle.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 1),
        NumberSequenceKeypoint.new(.3, .38),
        NumberSequenceKeypoint.new(1, 1),
    })
    particle.Parent = anchor
end

local function landmark(region, pal)
    -- Only in free space: markers, roads, houses, quest objectives must stay accessible.
    local center = groundAt(region.X + 6, region.Z + 9, 6)
    if not center then return end
    if region.Id == "Village" then
        marketStall(center, pal)
    elseif region.Id == "OldRoad" then
        displaySign(center, "OLD ROAD", pal)
        lantern(center + Vector3.new(7, 0, 0), pal)
    elseif region.Id == "CreekBend" then
        stones(center, pal)
        stones(center + Vector3.new(3, 0, 4), pal)
    elseif region.Id == "AncientStones" then
        standingStone(center, pal)
        standingStone(center + Vector3.new(5, 0, 4), pal)
    elseif region.Id == "Thornwatch" then
        standingStone(center, pal)
    elseif region.Id == "FirstGate" then
        standingStone(center, pal)
        fireflies(center + Vector3.new(3, 0, 1), pal)
    end
end

for _, region in ipairs(regionList) do
    local pal = Art.Palettes[region.Style]
    -- These regions are visually different, while all monsters/quests remain server-owned.
    for i = 1, preset.TreePerRegion do
        local where = pickPoint(region, 4.0, 11)
        if where then tree(where, pal, region.Style) end
        if i % 4 == 0 then task.wait() end
    end
    for i = 1, preset.BushPerRegion do
        local where = pickPoint(region, 2.0, 9)
        if where then bush(where, pal, region.Style) end
        if i % 6 == 0 then task.wait() end
    end
    for i = 1, preset.DetailPerRegion do
        local where = pickPoint(region, 1.0, 9)
        if where then
            if i % 4 == 0 or region.Style == "Ruins" then
                stones(where, pal)
            else
                flowerCluster(where, pal, region.Style)
            end
        end
        if i % 9 == 0 then task.wait() end
    end
    landmark(region, pal)
    if region.Id == "Village" then
        for i = 1, preset.VillageExtras do
            local where = pickPoint(region, 3, 14)
            if where then
                if i % 2 == 0 then lantern(where, pal) else flowerCluster(where, pal, region.Style) end
            end
        end
        local nameSpot = groundAt(region.X - 20, region.Z + 20, 4)
        if nameSpot then displaySign(nameSpot, "LUMIA HAMLET", pal) end
        local firefliesWhere = groundAt(region.X + 18, region.Z - 15, 2)
        if firefliesWhere then fireflies(firefliesWhere, pal) end
    elseif region.Id == "CreekBend" or region.Id == "AncientStones" then
        local where = pickPoint(region, 3, 8)
        if where then fireflies(where, pal) end
    end
    print(string.format("[Lumia Art V19.1] %s decorations prepared", region.Id))
    task.wait()
end

-- Gently blend the atmosphere on the LOCAL client while travelling between regions.
-- This is intentionally separate from the server's global golden-hour lighting.
local existingGrade = Lighting:FindFirstChild("LumiaLocalRegionGradeV191")
if existingGrade and not existingGrade:IsA("ColorCorrectionEffect") then
    warn("[Lumia Art V19.1] Color grade name occupied, skipping local grade")
    return
end
local grade = existingGrade or Instance.new("ColorCorrectionEffect")
grade.Name = "LumiaLocalRegionGradeV191"
grade.Enabled = true
grade.Brightness = 0
local defaultGrade = Art.ColorGrades.Meadow
grade.TintColor = defaultGrade.Tint
grade.Saturation = defaultGrade.Saturation
grade.Contrast = defaultGrade.Contrast
grade.Parent = Lighting
local player = Players.LocalPlayer
local activeStyle = "Meadow"
local gradeTween
local function resolveStyle(point)
    local localPoint = grass.CFrame:PointToObjectSpace(point)
    local chosen, minDistance
    for _, region in ipairs(regionList) do
        local dx = (localPoint.X - region.X) / region.SpanX
        local dz = (localPoint.Z - region.Z) / region.SpanZ
        local distance = dx * dx + dz * dz
        if distance <= 1.65 and (not minDistance or distance < minDistance) then
            chosen, minDistance = region.Style, distance
        end
    end
    return chosen or "Meadow"
end
task.spawn(function()
    while grade.Parent == Lighting do
        local character = player.Character
        local root = character and character:FindFirstChild("HumanoidRootPart")
        if root then
            local style = resolveStyle(root.Position)
            if style ~= activeStyle then
                activeStyle = style
                local target = Art.ColorGrades[style] or defaultGrade
                if gradeTween then gradeTween:Cancel() end
                gradeTween = TweenService:Create(grade,
                    TweenInfo.new(2.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
                    {TintColor = target.Tint, Saturation = target.Saturation, Contrast = target.Contrast})
                gradeTween:Play()
            end
        end
        task.wait(1.75)
    end
end)
print(string.format("[Lumia Art V19.1] Loaded %s quality | trees=%d shrubs=%d details=%d parts=%d lights=%d",
    profile.Name, treeCount, shrubCount, detailCount, partCount, lightCount))
