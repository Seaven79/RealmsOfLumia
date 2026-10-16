-- REALMS OF LUMIA - HOUSE-SIDE PLAYER SPAWN v1.0
-- Server-side runtime setup; source map/Workspace is kept in the Roblox place.
-- Repositions an existing SpawnLocation beside an identified house or manual
-- LumiaPlayerSpawnAnchor. Does NOT destroy arbitrary Parts or map geometry.
-- Future zones: create a checkpoint service; update PlayerSpawnConfig only.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local config = require(ReplicatedStorage:WaitForChild("Lumia")
    :WaitForChild("Shared"):WaitForChild("World")
    :WaitForChild("PlayerSpawnConfig"))

local function allSpawnLocations()
    local found = {}
    for _, instance in ipairs(Workspace:GetDescendants()) do
        if instance:IsA("SpawnLocation") then
            table.insert(found, instance)
        end
    end
    table.sort(found, function(a, b)
        return a:GetFullName() < b:GetFullName()
    end)
    return found
end

local function hidePad(pad)
    pad.Transparency = 1
    pad.CanCollide = false
    pad.CanTouch = false
    pad.CanQuery = false
    pad.CastShadow = false
    for _, descendant in ipairs(pad:GetDescendants()) do
        if descendant:IsA("Decal") or descendant:IsA("Texture") then
            descendant.Transparency = 1
        elseif descendant:IsA("SurfaceGui") then
            descendant.Enabled = false
        end
    end
end

local function isHouse(instance)
    return (instance:IsA("Model") and instance:FindFirstChildWhichIsA("BasePart", true))
        or instance:IsA("BasePart")
end

local function boundsFor(instance)
    if instance:IsA("Model") then return instance:GetBoundingBox() end
    return instance.CFrame, instance.Size
end

local function collectHouses()
    local houses, seen = {}, {}
    for _, instance in ipairs(CollectionService:GetTagged(config.HouseTag)) do
        if isHouse(instance) and instance:IsDescendantOf(Workspace) then
            table.insert(houses, instance)
            seen[instance] = true
        end
    end
    if #houses > 0 then return houses end

    -- Conservative fallback for places that haven't tagged their house model yet.
    for _, instance in ipairs(Workspace:GetDescendants()) do
        if instance:IsA("Model") and not seen[instance]
            and isHouse(instance) then
            local lowerName = instance.Name:lower()
            for _, keyword in ipairs(config.SearchHouseNames) do
                if lowerName:find(keyword, 1, true) then
                    table.insert(houses, instance)
                    seen[instance] = true
                    break
                end
            end
        end
    end
    return houses
end

local function ignoredInstances()
    local ignored = {}
    local monsterFolder = Workspace:FindFirstChild("LumiaMonsters")
    if monsterFolder then table.insert(ignored, monsterFolder) end
    for _, player in ipairs(Players:GetPlayers()) do
        if player.Character then table.insert(ignored, player.Character) end
    end
    for _, spawn in ipairs(allSpawnLocations()) do
        table.insert(ignored, spawn)
    end
    local volumes = Workspace:FindFirstChild("LumiaMonsterRestrictedVolumes")
    if volumes then table.insert(ignored, volumes) end
    return ignored
end

local function groundAndClear(x, z, searchTop, ignored)
    local castParams = RaycastParams.new()
    castParams.FilterType = Enum.RaycastFilterType.Exclude
    castParams.FilterDescendantsInstances = ignored
    castParams.RespectCanCollide = true
    castParams.IgnoreWater = true
    local hit = Workspace:Raycast(Vector3.new(x, searchTop, z),
        Vector3.new(0, -config.MaxCastDepth, 0), castParams)
    if not hit or hit.Normal.Y < 0.8 then return nil end

    -- A body-sized space must be clear, not only the ground directly below.
    local overlap = OverlapParams.new()
    overlap.FilterType = Enum.RaycastFilterType.Exclude
    overlap.FilterDescendantsInstances = ignored
    overlap.MaxParts = 120
    local center = Vector3.new(x, hit.Position.Y + 0.25 + config.ClearHeight / 2, z)
    local size = Vector3.new(config.ClearWidth, config.ClearHeight, config.ClearWidth)
    for _, part in ipairs(Workspace:GetPartBoundsInBox(CFrame.new(center), size, overlap)) do
        if part:IsA("BasePart") and part.CanCollide then
            return nil
        end
    end
    return hit.Position
end

local function manualPosition(ignored)
    local marker = Workspace:FindFirstChild(config.ManualAnchorName, true)
    if not marker or not marker:IsA("BasePart") then return nil end
    local filters = table.clone(ignored)
    table.insert(filters, marker)
    local point = groundAndClear(marker.Position.X, marker.Position.Z,
        marker.Position.Y + 12, filters)
    if not point then
        warn("[Lumia - Player Spawn] Manual anchor is blocked/no ground: " .. marker:GetFullName())
    end
    return point
end

local function housePosition(reference, ignored)
    local houses = collectHouses()
    if #houses == 0 then
        warn("[Lumia - Player Spawn] No tagged/named house found. Tag house 'LumiaNoMobHouse' or add a Part named 'LumiaPlayerSpawnAnchor'.")
        return nil
    end
    table.sort(houses, function(a, b)
        local acf = boundsFor(a)
        local bcf = boundsFor(b)
        return (acf.Position - reference).Magnitude < (bcf.Position - reference).Magnitude
    end)

    -- Prefer a valid nearby side of the house over an arbitrary world coordinate.
    local candidates = {}
    for houseIndex, house in ipairs(houses) do
        local houseFrame, houseSize = boundsFor(house)
        local searchY = houseFrame.Position.Y + houseSize.Y * 0.5 + 12
        for _, distance in ipairs(config.SideDistances) do
            local halves = {houseSize.X * 0.5 + distance,
                houseSize.Z * 0.5 + distance}
            local sides = {
                Vector3.new( halves[1], 0, 0),
                Vector3.new(-halves[1], 0, 0),
                Vector3.new(0, 0,  halves[2]),
                Vector3.new(0, 0, -halves[2]),
            }
            for _, localOffset in ipairs(sides) do
                local worldPoint = houseFrame:PointToWorldSpace(localOffset)
                local ground = groundAndClear(worldPoint.X, worldPoint.Z, searchY, ignored)
                if ground then
                    -- Discourage distant and elevated sites; prefer near the original spawn.
                    local horizontal = Vector3.new(ground.X - reference.X, 0, ground.Z - reference.Z)
                    local score = horizontal.Magnitude + (houseIndex - 1) * 15 + distance * 0.3
                    table.insert(candidates, {position = ground, score = score,
                        house = house})
                end
            end
        end
    end
    table.sort(candidates, function(a, b) return a.score < b.score end)
    if #candidates == 0 then
        warn("[Lumia - Player Spawn] Houses found but no safe ground beside them. Not moving the existing spawn.")
        return nil
    end
    return candidates[1].position, candidates[1].house
end

local function run()
    local spawns = allSpawnLocations()
    print("[Lumia - Player Spawn] Existing SpawnLocation count: " .. #spawns)
    for _, spawn in ipairs(spawns) do
        print("[Lumia - Player Spawn] Found: " .. spawn:GetFullName() .. " @ " .. tostring(spawn.Position))
    end

    local primary = spawns[1]
    local reference = primary and primary.Position or Vector3.zero
    local ignored = ignoredInstances()
    local point = manualPosition(ignored)
    local house
    if not point then point, house = housePosition(reference, ignored) end

    if not primary and point then
        primary = Instance.new("SpawnLocation")
        primary.Name = "LumiaPlayerSpawn"
        primary.Size = Vector3.new(5, 1, 5)
        primary.Anchored = true
        primary.Neutral = true
        primary.Parent = Workspace
        print("[Lumia - Player Spawn] Created runtime SpawnLocation for the starting village.")
    end

    if config.HideAllSpawnPads then
        for _, spawn in ipairs(spawns) do hidePad(spawn) end
        if primary then hidePad(primary) end
    end

    if not point or not primary then
        warn("[Lumia - Player Spawn] No safe destination found; original player spawn behavior preserved. Pads were hidden when possible.")
        return
    end

    -- We keep the original part and only move it while Play is running.
    primary.CFrame = CFrame.new(point + Vector3.new(0, primary.Size.Y / 2, 0))
    primary.Anchored = true
    primary.Neutral = true
    primary.AllowTeamChangeOnTouch = false
    primary.Enabled = true
    primary.Duration = config.SpawnProtectionSeconds
    if config.HideAllSpawnPads then hidePad(primary) end

    if config.DisableOtherSpawnLocations then
        for _, spawn in ipairs(spawns) do
            if spawn ~= primary then
                spawn.Enabled = false
                if config.HideAllSpawnPads then hidePad(spawn) end
                print("[Lumia - Player Spawn] Disabled extra SpawnLocation (not deleted): " .. spawn:GetFullName())
            end
        end
    end

    local function assignPlayer(player)
        player.RespawnLocation = primary
        player.CharacterAdded:Connect(function(character)
            if not config.ForceInitialCharacterPosition then return end
            task.defer(function()
                local root = character:WaitForChild("HumanoidRootPart", 8)
                if not root or player.Character ~= character then return end
                if (root.Position - primary.Position).Magnitude > 15 then
                    -- Only correct characters whose first spawn used the old pad.
                    character:PivotTo(primary.CFrame + Vector3.new(0, 4, 0))
                end
            end)
        end)
        if config.ForceInitialCharacterPosition and player.Character then
            local character = player.Character
            task.defer(function()
                local root = character:WaitForChild("HumanoidRootPart", 8)
                if root and player.Character == character
                    and (root.Position - primary.Position).Magnitude > 15 then
                    character:PivotTo(primary.CFrame + Vector3.new(0, 4, 0))
                end
            end)
        end
    end

    Players.PlayerAdded:Connect(assignPlayer)
    for _, player in ipairs(Players:GetPlayers()) do assignPlayer(player) end
    print("[Lumia - Player Spawn] Active invisible spawn beside "
        .. (house and house.Name or "manual spawn anchor") .. ": " .. tostring(primary.Position))
    print("[Lumia - Player Spawn] Other non-SpawnLocation squares were NOT deleted or modified.")
end

-- Small startup delay allows Studio-built houses/tags to register.
task.delay(0.35, run)