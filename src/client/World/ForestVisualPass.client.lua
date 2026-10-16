-- Realms of Lumia | Forgotten Forest Visual Pass v1.1 - streaming-safe, budgeted
-- Client-only decorations: zero network replication, collision, or save changes.
-- Uses existing terrain/ground surfaces. Skips unsafe samples rather than filling paths or houses.
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Lumia")
    :WaitForChild("Shared"):WaitForChild("World"):WaitForChild("ForestVisualConfig"))
local GraphicsManager = require(script.Parent:WaitForChild("GraphicsManager"))
local quality = GraphicsManager.GetProfile()
local localPlayer = Players.LocalPlayer
local region = Workspace:WaitForChild(Config.Vegetation.RegionName, 20)
if not region then
    warn("[Lumia - Forest Visual Pass] ForgottenForest missing in Workspace; visual pass skipped")
    return
end

local oldFolder = Workspace:FindFirstChild("LumiaClientForestDecor")
if oldFolder then oldFolder:Destroy() end
local decor = Instance.new("Folder")
decor.Name = "LumiaClientForestDecor"
decor.Parent = Workspace

-- StreamingEnabled can replicate the region model before its ground parts.
-- Never create a duplicate floor: simply wait for the existing Grassland.
local groundPart = GraphicsManager.WaitForGround(region)
local rng = Random.new(Config.Vegetation.RandomSeed)
local function choose(items)
    return items[rng:NextInteger(1, #items)]
end
local function lower(stringValue)
    return string.lower(stringValue)
end
local function hasAny(name, words)
    local value = lower(name)
    for _, word in ipairs(words) do
        if string.find(value, word, 1, true) then return true end
    end
    return false
end

-- Tinted existing trees, not replaced: preserves mesh textures, placement and collision.
local styled = {}
local treeCount = 0
local function styleTree(tree)
    if styled[tree] or treeCount >= Config.Tree.MaxModels then return end
    if not tree:IsDescendantOf(Workspace) then return end
    if not (tree:IsA("Model") or tree:IsA("Folder")) then return end
    styled[tree] = true
    local leafColor = choose(Config.Tree.LeafPalette)
    local barkColor = choose(Config.Tree.BarkPalette)
    local changed = 0
    for _, part in ipairs(tree:GetDescendants()) do
        if part:IsA("BasePart") then
            local name = lower(part.Name)
            local hue, saturation = part.Color:ToHSV()
            local looksLikeLeaves = hue > 0.18 and hue < 0.47 and saturation > 0.15
            local looksLikeBark = part.Material == Enum.Material.Wood
                or part.Material == Enum.Material.WoodPlanks
            if hasAny(name, {"leaf", "leaves", "foliage", "needle", "canopy", "crown"})
                or (looksLikeLeaves and not looksLikeBark) then
                part.Color = part.Color:Lerp(leafColor, Config.Tree.LeafTintStrength)
                changed += 1
            elseif hasAny(name, {"trunk", "bark", "branch", "log"}) or looksLikeBark then
                part.Color = part.Color:Lerp(barkColor, Config.Tree.BarkTintStrength)
                changed += 1
                if Config.Tree.ApplyWoodToSimpleTrunks and part:IsA("Part")
                    and not part:FindFirstChildWhichIsA("SpecialMesh") then
                    part.Material = Enum.Material.Wood
                end
            end
        end
    end
    if changed > 0 then treeCount += 1 end
end
if Config.Tree.Enabled then
    for _, tree in ipairs(CollectionService:GetTagged(Config.Tree.Tag)) do
        styleTree(tree)
    end
    if Config.Tree.AutoDetectNamedModels then
        local scanned = 0
        for _, inst in ipairs(region:GetDescendants()) do
            if inst:IsA("Model") and hasAny(inst.Name,
                {"tree", "pine", "oak", "birch", "spruce", "fir"}) then
                styleTree(inst)
                scanned += 1
                GraphicsManager.YieldIfNeeded(scanned, quality.TreeBatch)
            end
        end
    end
    CollectionService:GetInstanceAddedSignal(Config.Tree.Tag):Connect(styleTree)
end

if Config.Weather.NativeTerrainGrass then
    pcall(function() Workspace.Terrain.Decoration = true end)
end
if Config.Weather.ClientClouds then
    local clouds = Workspace.Terrain:FindFirstChild("LumiaForestClouds")
    if not clouds then
        clouds = Instance.new("Clouds")
        clouds.Name = "LumiaForestClouds"
        clouds.Parent = Workspace.Terrain
    end
    if clouds:IsA("Clouds") then
        clouds.Cover = Config.Weather.CloudCover
        clouds.Density = Config.Weather.CloudDensity
        clouds.Color = Config.Weather.CloudColor
    end
end

if not Config.Vegetation.Enabled then
    print("[Lumia - Forest Visual Pass] Styled " .. treeCount .. " trees; plants disabled")
    return
end

-- Sample designated volumes first. If none exist, use actual broad ground parts.
local areas = {}
for _, item in ipairs(CollectionService:GetTagged(Config.Vegetation.AreaTag)) do
    if item:IsA("BasePart") and item:IsDescendantOf(region) then
        table.insert(areas, item)
    end
end
local surfaces = {}
local seenSurface = {}
local function addSurface(item)
    if not item or seenSurface[item] then return end
    if item:IsA("BasePart") and item.CanCollide
        and item.Size.X >= 24 and item.Size.Z >= 24
        and (item.Material == Enum.Material.Grass
            or hasAny(item.Name, {"grass", "ground", "forestfloor", "meadow", "landscape"}))
        and not hasAny(item.Name, {"roof", "wall", "ceiling", "platform"}) then
        seenSurface[item] = true
        table.insert(surfaces, item)
    end
end
-- Prefer the real Grassland part; if not replicated, the scanned fallback still works.
addSurface(groundPart)
for _, item in ipairs(region:GetDescendants()) do
    addSurface(item)
end

local center = Vector3.zero
local topY = 75
if groundPart and groundPart:IsA("BasePart") then
    center = groundPart.Position
    topY = groundPart.Position.Y + groundPart.Size.Y * 0.5 + 75
elseif region:IsA("Model") and region:FindFirstChildWhichIsA("BasePart", true) then
    local cf, size = region:GetBoundingBox()
    center = cf.Position
    topY = cf.Position.Y + math.max(25, size.Y * 0.5 + 8)
elseif #surfaces > 0 then
    center = surfaces[1].Position
    topY = center.Y + 75
end

-- Refuse to decorate an unknown map region with no identifiable ground or terrain.
if #areas == 0 and #surfaces == 0 then
    local hit = Workspace:Raycast(center + Vector3.new(0, 30, 0), Vector3.new(0, -160, 0))
    if not hit or not hit.Instance:IsA("Terrain") then
        warn("[Lumia - Forest Visual Pass] Grassland not streamed or no suitable ground found; plants skipped. Ground must be Workspace.ForgottenForest.Grassland. No new floor needed.")
        print("[Lumia - Forest Visual Pass] Styled " .. treeCount .. " trees; no plants placed")
        return
    end
end

local houses = {}
local function addHouse(item)
    if not item:IsDescendantOf(region) then return end
    local cf, size
    if item:IsA("Model") then
        if not item:FindFirstChildWhichIsA("BasePart", true) then return end
        cf, size = item:GetBoundingBox()
    elseif item:IsA("BasePart") then
        cf, size = item.CFrame, item.Size
    else
        return
    end
    table.insert(houses, {cf = cf, size = size})
end
for _, house in ipairs(CollectionService:GetTagged("LumiaNoMobHouse")) do addHouse(house) end
if #houses == 0 then
    for _, item in ipairs(region:GetDescendants()) do
        if item:IsA("Model") and hasAny(item.Name, {"house", "cottage", "inn"}) then
            addHouse(item)
        end
    end
end
local spawns = {}
for _, part in ipairs(Workspace:GetDescendants()) do
    if part:IsA("SpawnLocation") then table.insert(spawns, part.Position) end
end

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
local overlapParams = OverlapParams.new()
overlapParams.FilterType = Enum.RaycastFilterType.Exclude
overlapParams.MaxParts = 12

local function exclusionList(extra)
    local exclude = {decor}
    if extra then table.insert(exclude, extra) end
    local char = localPlayer.Character
    if char then table.insert(exclude, char) end
    local monsters = Workspace:FindFirstChild("LumiaMonsters")
    if monsters then table.insert(exclude, monsters) end
    for _, tagged in ipairs(areas) do table.insert(exclude, tagged) end
    return exclude
end
local function nearProtected(position)
    for _, entry in ipairs(houses) do
        local p = entry.cf:PointToObjectSpace(position)
        if math.abs(p.X) < entry.size.X * 0.5 + Config.Vegetation.AvoidHouseStuds
            and math.abs(p.Z) < entry.size.Z * 0.5 + Config.Vegetation.AvoidHouseStuds then
            return true
        end
    end
    for _, point in ipairs(spawns) do
        local dx, dz = point.X - position.X, point.Z - position.Z
        if dx * dx + dz * dz < Config.Vegetation.AvoidSpawnStuds ^ 2 then
            return true
        end
    end
    return false
end
local function isNaturalSurface(hit)
    if not hit then return false end
    if hit.Material == Enum.Material.Grass then return true end
    return hasAny(hit.Instance.Name, {"grass", "ground", "forestfloor", "meadow"})
end

local function randomCandidate()
    if #areas > 0 then
        local vol = choose(areas)
        local localX = rng:NextNumber(-vol.Size.X * 0.49, vol.Size.X * 0.49)
        local localZ = rng:NextNumber(-vol.Size.Z * 0.49, vol.Size.Z * 0.49)
        return (vol.CFrame * CFrame.new(localX, vol.Size.Y * 0.5 + 8, localZ)).Position
    end
    if #surfaces > 0 then
        local surface = choose(surfaces)
        local halfX = math.min(surface.Size.X * 0.48, Config.Vegetation.MaxOffsetFromRegionCenter)
        local halfZ = math.min(surface.Size.Z * 0.48, Config.Vegetation.MaxOffsetFromRegionCenter)
        return (surface.CFrame * CFrame.new(
            rng:NextNumber(-halfX, halfX), surface.Size.Y * 0.5 + 12,
            rng:NextNumber(-halfZ, halfZ))).Position
    end
    return Vector3.new(center.X + rng:NextNumber(-100, 100), topY,
        center.Z + rng:NextNumber(-100, 100))
end

local function findPlantPosition()
    for _ = 1, Config.Vegetation.MaxSamplesPerPlant do
        local origin = randomCandidate()
        local dx, dz = origin.X - center.X, origin.Z - center.Z
        if dx * dx + dz * dz <= Config.Vegetation.MaxOffsetFromRegionCenter ^ 2 then
            rayParams.FilterDescendantsInstances = exclusionList()
            local hit = Workspace:Raycast(origin, Vector3.new(0, -220, 0), rayParams)
            if hit and hit.Normal.Y >= Config.Vegetation.MaxGroundSlope
                and isNaturalSurface(hit) and not nearProtected(hit.Position) then
                overlapParams.FilterDescendantsInstances = exclusionList(hit.Instance)
                local obstacles = Workspace:GetPartBoundsInBox(
                    CFrame.new(hit.Position + Vector3.new(0, 1.0, 0)),
                    Vector3.new(Config.Vegetation.ClearanceStuds * 2, 1.6,
                        Config.Vegetation.ClearanceStuds * 2), overlapParams)
                local blocked = false
                for _, part in ipairs(obstacles) do
                    if part.CanCollide and part.Transparency < 0.99 then
                        blocked = true
                        break
                    end
                end
                if not blocked then return hit.Position end
            end
        end
    end
    return nil
end
local function makePart(name, shape, size, color, material, cf)
    local part = Instance.new(shape)
    part.Name = name
    part.Size = size
    part.Color = color
    part.Material = material
    part.CFrame = cf
    part.Anchored = true
    part.CanCollide = false
    part.CanTouch = false
    part.CanQuery = false
    part.CastShadow = false
    part.Parent = decor
    return part
end
local function grassTuft(position)
    local angle = rng:NextNumber(-math.pi, math.pi)
    local color = choose(Config.Vegetation.GrassColors)
    for blade = 1, 2 do
        local height = rng:NextNumber(0.65, 1.15)
        local cf = CFrame.new(position + Vector3.new(0, height / 2, 0))
            * CFrame.Angles(0, angle + blade * math.pi / 2, math.rad(rng:NextNumber(-13, 13)))
        makePart("GrassBlade", "WedgePart", Vector3.new(0.11, height, 0.30),
            color, Enum.Material.Grass, cf)
    end
end
local function flower(position)
    local height = rng:NextNumber(0.55, 0.95)
    local centerOfFlower = position + Vector3.new(0, height, 0)
    makePart("FlowerStem", "Part", Vector3.new(0.065, height, 0.065),
        Color3.fromRGB(73, 124, 68), Enum.Material.SmoothPlastic,
        CFrame.new(position + Vector3.new(0, height / 2, 0)))
    makePart("FlowerCenter", "Part", Vector3.new(0.18, 0.12, 0.18),
        Color3.fromRGB(223, 178, 63), Enum.Material.SmoothPlastic,
        CFrame.new(centerOfFlower)).Shape = Enum.PartType.Ball
    local color = choose(Config.Vegetation.FlowerColors)
    local offsetAngle = rng:NextNumber(0, math.pi * 2)
    for petal = 1, 5 do
        local a = offsetAngle + (petal / 5) * math.pi * 2
        local petalPosition = centerOfFlower + Vector3.new(math.cos(a) * 0.15, 0, math.sin(a) * 0.15)
        makePart("FlowerPetal", "Part", Vector3.new(0.19, 0.075, 0.22),
            color, Enum.Material.SmoothPlastic, CFrame.new(petalPosition)).Shape = Enum.PartType.Ball
    end
end

local grassCount, flowerCount = 0, 0
local grassTarget = math.min(Config.Vegetation.GrassTufts, quality.GrassTufts)
local flowerTarget = math.min(Config.Vegetation.FlowerPatches, quality.Flowers)
print(string.format("[Lumia Graphics] Profile %s | ground=%s | grass=%d flowers=%d",
    quality.Name, groundPart and groundPart:GetFullName() or "fallback", grassTarget, flowerTarget))
for i = 1, grassTarget do
    local where = findPlantPosition()
    if where then grassTuft(where); grassCount += 1 end
    GraphicsManager.YieldIfNeeded(i, quality.DecorationBatch)
end
for i = 1, flowerTarget do
    local where = findPlantPosition()
    if where then flower(where); flowerCount += 1 end
    GraphicsManager.YieldIfNeeded(i, quality.DecorationBatch)
end
print(string.format("[Lumia Forest] Visual pass: %d trees tinted, %d grass tufts, %d flowers. Client-only visuals.",
    treeCount, grassCount, flowerCount))
