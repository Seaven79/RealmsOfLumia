-- REALMS OF LUMIA - SPAWN SAFETY v1.0
-- Checks ground, monster clearance, houses, trees and other solid scenery.
-- Purely server-side. If no safe location exists, do not spawn the monster.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local CollectionService = game:GetService("CollectionService")

local HouseZones = require(script.Parent:WaitForChild("MonsterHouseZones"))

local SpawnSafety = {}

local ROOT_ABOVE_GROUND = 3.5 -- Keep the current Forest Wolf rig placement.
local MAX_GROUND_DIFFERENCE = 4.25
local MIN_SPAWN_SEPARATION = 8
local PLAYER_CLEARANCE = 8
local FOOTPRINT_HALF_WIDTH = 1.7
local FOOTPRINT_HEIGHT_TOLERANCE = 1.65
local BODY_SIZE = Vector3.new(4.6, 5.1, 4.6)
local BODY_CENTER_HEIGHT = 2.85 -- Query starts above the supporting ground.

local started = false
local blockers = {} -- [explicitly tagged / clearly named obstacle] = true
local forbiddenWords = {
    "house", "cabin", "cottage", "building", "barn", "shed", "hut",
    "roof", "wall", "trunk", "stump", "oak", "pine", "spruce", "birch",
}

local function looksLikeObstacle(instance)
    if not (instance:IsA("Model") or instance:IsA("BasePart")) then return false end
    local name = string.lower(instance.Name)
    -- Groups of many props must not become one giant restricted footprint.
    if name == "trees" or name == "houses" or name == "buildings"
        or name == "walls" or name == "forest" then
        return false
    end
    if string.find(name, "tree", 1, true) then return true end
    for _, word in ipairs(forbiddenWords) do
        if string.find(name, word, 1, true) then return true end
    end
    return false
end

local function track(instance)
    if looksLikeObstacle(instance)
        or CollectionService:HasTag(instance, "LumiaNoMobSpawn") then
        blockers[instance] = true
    end
end

local function getBounds(instance)
    if instance:IsA("BasePart") then
        return instance.CFrame, instance.Size
    end
    if instance:IsA("Model") and instance:FindFirstChildWhichIsA("BasePart", true) then
        return instance:GetBoundingBox()
    end
    return nil, nil
end

local function footprintBlocked(groundPosition)
    if HouseZones.IsRestricted(groundPosition + Vector3.new(0, 1.5, 0), 2.4) then
        return true
    end

    for instance in pairs(blockers) do
        if not instance:IsDescendantOf(Workspace) then
            blockers[instance] = nil
        else
            local cf, size = getBounds(instance)
            -- Ignore huge scene/group models. The individual Parts will still
            -- be tested via actual clearance overlap, even for grouped scenes.
            if cf and size and size.X < 75 and size.Z < 75 then
                local localPoint = cf:PointToObjectSpace(groundPosition)
                if math.abs(localPoint.X) <= size.X * 0.5 + 2.4
                    and math.abs(localPoint.Z) <= size.Z * 0.5 + 2.4
                    and math.abs(localPoint.Y) <= size.Y * 0.5 + 4 then
                    return true
                end
            end
        end
    end
    return false
end

local function getFilters()
    local excluded = {}
    local monsters = Workspace:FindFirstChild("LumiaMonsters")
    if monsters then table.insert(excluded, monsters) end
    local volumes = Workspace:FindFirstChild("LumiaMonsterRestrictedVolumes")
    if volumes then table.insert(excluded, volumes) end
    for _, player in ipairs(Players:GetPlayers()) do
        if player.Character then
            table.insert(excluded, player.Character)
        end
    end
    return excluded
end

local function groundRay(x, y, z, rayParams)
    return Workspace:Raycast(
        Vector3.new(x, y, z),
        Vector3.new(0, -32, 0),
        rayParams
    )
end

local function unsuitableGround(hit)
    if not hit or hit.Normal.Y < 0.78 then return true end
    local item = hit.Instance
    if not item then return true end
    local ancestor = item
    while ancestor do
        if CollectionService:HasTag(ancestor, "LumiaNoMobSpawn")
            or CollectionService:HasTag(ancestor, "LumiaNoMobHouse") then
            return true
        end
        if looksLikeObstacle(ancestor) then return true end
        if ancestor == Workspace then break end
        ancestor = ancestor.Parent
    end
    local name = string.lower(item.Name)
    if string.find(name, "step", 1, true)
        or string.find(name, "stair", 1, true)
        or string.find(name, "platform", 1, true) then
        return true
    end
    return false
end

local function farEnough(position, points, ignoredId)
    for _, point in ipairs(points) do
        if point.id ~= ignoredId then
            local other = (point.model and point.model.Parent
                and point.model:FindFirstChild("HumanoidRootPart"))
            local otherPosition = other and other.Position
                or point.lastPosition or point.position
            if otherPosition then
                local dx = position.X - otherPosition.X
                local dz = position.Z - otherPosition.Z
                if dx * dx + dz * dz < MIN_SPAWN_SEPARATION ^ 2 then
                    return false
                end
            end
        end
    end

    for _, player in ipairs(Players:GetPlayers()) do
        local character = player.Character
        local root = character and character:FindFirstChild("HumanoidRootPart")
        if root then
            local dx = position.X - root.Position.X
            local dz = position.Z - root.Position.Z
            if dx * dx + dz * dz < PLAYER_CLEARANCE ^ 2
                and math.abs(position.Y - root.Position.Y) < 7 then
                return false
            end
        end
    end
    return true
end

local function tryPosition(position, points, ignoredId)
    local excluded = getFilters()
    local rayParams = RaycastParams.new()
    rayParams.FilterType = Enum.RaycastFilterType.Exclude
    rayParams.FilterDescendantsInstances = excluded
    rayParams.RespectCanCollide = true

    local hit = groundRay(position.X, position.Y + 2.5, position.Z, rayParams)
    if unsuitableGround(hit) then return nil end
    local ground = hit.Position
    if math.abs(ground.Y - (position.Y - ROOT_ABOVE_GROUND)) > MAX_GROUND_DIFFERENCE then
        return nil
    end
    if footprintBlocked(ground) then return nil end

    -- Verify support on every side. A wolf must not straddle a ledge.
    for _, offset in ipairs({
        Vector2.new(FOOTPRINT_HALF_WIDTH, 0),
        Vector2.new(-FOOTPRINT_HALF_WIDTH, 0),
        Vector2.new(0, FOOTPRINT_HALF_WIDTH),
        Vector2.new(0, -FOOTPRINT_HALF_WIDTH),
    }) do
        local support = groundRay(
            ground.X + offset.X,
            ground.Y + 2,
            ground.Z + offset.Y,
            rayParams
        )
        if unsuitableGround(support)
            or math.abs(support.Position.Y - ground.Y) > FOOTPRINT_HEIGHT_TOLERANCE then
            return nil
        end
    end

    local overlap = OverlapParams.new()
    overlap.FilterType = Enum.RaycastFilterType.Exclude
    overlap.FilterDescendantsInstances = excluded
    overlap.MaxParts = 0 -- Do not truncate obstacle results.
    local occupants = Workspace:GetPartBoundsInBox(
        CFrame.new(ground + Vector3.new(0, BODY_CENTER_HEIGHT, 0)),
        BODY_SIZE,
        overlap
    )
    for _, part in ipairs(occupants) do
        if part.CanCollide or looksLikeObstacle(part) then
            return nil
        end
        -- Block non-colliding decorative trees or structural wall parts too.
        local parent = part.Parent
        while parent and parent ~= Workspace do
            if blockers[parent] then return nil end
            parent = parent.Parent
        end
    end

    local finalPosition = ground + Vector3.new(0, ROOT_ABOVE_GROUND, 0)
    if not farEnough(finalPosition, points, ignoredId) then return nil end
    return finalPosition
end

function SpawnSafety.Start()
    if started then return end
    started = true
    HouseZones.Start()
    for _, descendant in ipairs(Workspace:GetDescendants()) do
        track(descendant)
    end
    for _, tagged in ipairs(CollectionService:GetTagged("LumiaNoMobSpawn")) do
        track(tagged)
    end
    Workspace.DescendantAdded:Connect(track)
    CollectionService:GetInstanceAddedSignal("LumiaNoMobSpawn"):Connect(track)
    CollectionService:GetInstanceRemovedSignal("LumiaNoMobSpawn"):Connect(function(instance)
        if not looksLikeObstacle(instance) then blockers[instance] = nil end
    end)
end

-- Fast exact safety validation for broad randomized spawn searches.
-- Does NOT use fallback rings that could drift out of the desired map area.
function SpawnSafety.FindSafeAt(position, points, ignoredId)
    SpawnSafety.Start()
    if typeof(position) ~= "Vector3" then return nil end
    return tryPosition(position, points or {}, ignoredId)
end

function SpawnSafety.FindSafeNear(position, points, ignoredId)
    SpawnSafety.Start()
    if typeof(position) ~= "Vector3" then return nil end
    points = points or {}

    -- Original point first. Rings are deterministic, capped, and only searched
    -- on a spawn/respawn (never on the per-frame AI update).
    local result = tryPosition(position, points, ignoredId)
    if result then return result end

    for _, ring in ipairs({
        {radius = 6, samples = 10},
        {radius = 12, samples = 14},
        {radius = 20, samples = 18},
        {radius = 28, samples = 20},
    }) do
        for step = 1, ring.samples do
            local angle = math.pi * 2 * (step - 1) / ring.samples
            local candidate = position + Vector3.new(
                ring.radius * math.cos(angle),
                0,
                ring.radius * math.sin(angle)
            )
            result = tryPosition(candidate, points, ignoredId)
            if result then return result end
        end
    end
    return nil
end

return SpawnSafety
