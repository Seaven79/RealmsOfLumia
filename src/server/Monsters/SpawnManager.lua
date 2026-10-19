-- Realms of Lumia
-- SpawnManager v1.1: protected monster spawn locations
-- Shared player-centered activation with remembered roaming positions.
-- SpawnSafety validates every initial spawn and every reactivation.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MonsterService = require(
    script.Parent:WaitForChild("MonsterService")
)

local MonsterConfig = require(
    ReplicatedStorage:WaitForChild("Lumia")
        :WaitForChild("Shared")
        :WaitForChild("Monsters"):WaitForChild("MonsterConfig")
)

local SpawnSafety = require(script.Parent:WaitForChild("SpawnSafety"))
local PlayerPositions = require(game:GetService("ReplicatedStorage"):WaitForChild("Lumia"):WaitForChild("Shared"):WaitForChild("Players"):WaitForChild("PlayerPositions"))
local LifecycleEvents = require(script.Parent:WaitForChild("MonsterLifecycleEvents"))
local LifecycleConfig = require(ReplicatedStorage:WaitForChild("Lumia")
    :WaitForChild("Shared"):WaitForChild("Monsters")
    :WaitForChild("CorpseLifecycleConfig"))

local WolfSpawnConfig = require(ReplicatedStorage:WaitForChild("Lumia")
    :WaitForChild("Shared"):WaitForChild("Monsters"):WaitForChild("WolfSpawnConfig"))
local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")
local randomizer = Random.new()

local SpawnManager = {}

local SPAWN_RADIUS = WolfSpawnConfig.ActivationRadius
local DESPAWN_RADIUS = WolfSpawnConfig.DespawnRadius
local DESPAWN_DELAY = 20
local COMBAT_GRACE = 10
local CHECK_INTERVAL = 0.25

local points = {}
local pointById = {}
local started = false

-- Prefer explicit tagged spawn area; otherwise infer playable forest ground.
-- Ground and region setup are resolved ONCE when the first player arrives.
local region

local function getMapArea()
    for _, obj in ipairs(CollectionService:GetTagged("LumiaWolfSpawnArea")) do
        if obj:IsA("BasePart") and obj:IsDescendantOf(Workspace) then
            print("[Lumia - Spawn Manager] Wolf habitat: tagged area " .. obj:GetFullName())
            return {cf=obj.CFrame, sx=obj.Size.X, sz=obj.Size.Z, y=obj.Position.Y+obj.Size.Y*0.5}
        end
    end
    local map=Workspace:FindFirstChild("ForgottenForest")
    if map then
        local best,score=nil,0
        for _, part in ipairs(map:GetDescendants()) do
            if part:IsA("BasePart") and part.Size.X>=40 and part.Size.Z>=40 and part.Size.Y<=16 then
                local name=string.lower(part.Name)
                local isGround=(string.find(name,"ground",1,true) or string.find(name,"terrain",1,true)
                    or string.find(name,"grass",1,true) or string.find(name,"floor",1,true)
                    or string.find(name,"land",1,true))
                local candidateScore=part.Size.X*part.Size.Z*(isGround and 10 or 1)
                if candidateScore>score then best,score=part,candidateScore end
            end
        end
        if best then
            print("[Lumia - Spawn Manager] Wolf habitat: forest ground "..best:GetFullName())
            return {cf=best.CFrame,
                sx=math.min(best.Size.X,WolfSpawnConfig.MaxMapSide),
                sz=math.min(best.Size.Z,WolfSpawnConfig.MaxMapSide),
                y=best.Position.Y+best.Size.Y*0.5}
        end
        if map:IsA("Model") then
            local cf,size=map:GetBoundingBox()
            print("[Lumia - Spawn Manager] Wolf habitat: forest model bounds")
            return {cf=cf, sx=math.min(size.X,WolfSpawnConfig.MaxMapSide),
                sz=math.min(size.Z,WolfSpawnConfig.MaxMapSide), y=cf.Position.Y}
        end
    end
    warn("[Lumia - Spawn Manager] No marked wolf zone or forest model: using fixed map bounds")
    return {cf=CFrame.new(0,0,0), sx=WolfSpawnConfig.FallbackMapSize.X,
        sz=WolfSpawnConfig.FallbackMapSize.Y, y=0}
end

local function inRegion(position)
    if not region then return false end
    local localPosition=region.cf:PointToObjectSpace(position)
    return math.abs(localPosition.X)<region.sx*.5-4
        and math.abs(localPosition.Z)<region.sz*.5-4
end

local function safeRandomPosition(tries, ignoredId)
    if not region then return nil end
    local cast=RaycastParams.new()
    cast.FilterType=Enum.RaycastFilterType.Exclude
    local excluded={}
    local monsters=Workspace:FindFirstChild("LumiaMonsters")
    if monsters then table.insert(excluded,monsters) end
    for _, player in ipairs(Players:GetPlayers()) do
        if player.Character then table.insert(excluded,player.Character) end
    end
    cast.FilterDescendantsInstances=excluded
    cast.RespectCanCollide=true -- Do not hit non-colliding area markers.
    for _=1,tries do
        local dx=(randomizer:NextNumber()-.5)*math.max(region.sx-14,2)
        local dz=(randomizer:NextNumber()-.5)*math.max(region.sz-14,2)
        local sample=region.cf:PointToWorldSpace(Vector3.new(dx,0,dz))
        -- Find actual ground before using the EXISTING obstacle/house validator.
        local hit=Workspace:Raycast(Vector3.new(sample.X, region.y+140, sample.Z),
            Vector3.new(0,-350,0),cast)
        if hit then
            local candidate=SpawnSafety.FindSafeAt(hit.Position+Vector3.new(0,3.5,0),points,ignoredId)
            if candidate and inRegion(candidate) then
                local separated=true
                for _,point in ipairs(points) do
                    if point.id~=ignoredId then
                        local difference=candidate-point.position
                        if Vector3.new(difference.X,0,difference.Z).Magnitude < WolfSpawnConfig.MinAnchorSeparation then
                            separated=false
                            break
                        end
                    end
                end
                if separated then return candidate end
            end
        end
    end
    return nil
end

local function getPlayerRoots()
    local roots = {}

    for _, player in ipairs(Players:GetPlayers()) do
        local character = player.Character
        local root = character and
            character:FindFirstChild("HumanoidRootPart")

        local humanoid = character and
            character:FindFirstChildOfClass("Humanoid")

        if root and humanoid and humanoid.Health > 0 then
            table.insert(roots, root)
        end
    end

    return roots
end

local function withinRadius(roots, position, radius)
    local radiusSquared = radius * radius

    for _, root in ipairs(roots) do
        local delta = root.Position - position

        if delta:Dot(delta) <= radiusSquared then
            return true
        end
    end

    return false
end

local function activate(point)
    if point.state ~= "Inactive" then
        return
    end

    point.state = "Spawning"

    -- A remembered wolf position may become blocked after scenery changes.
    -- Never place a creature into a wall or tree to recover its roaming state.
    if point.randomizeNext then
        local nextPosition=safeRandomPosition(WolfSpawnConfig.RespawnPlacementAttempts,point.id)
        if nextPosition then
            point.position=nextPosition
            point.lastPosition=nil
        end
        point.randomizeNext=false
    end
    local location = SpawnSafety.FindSafeNear(
        point.lastPosition or point.position, points, point.id
    )
    if not location and point.lastPosition then
        -- Fallback to the original safe spawn area.
        location = SpawnSafety.FindSafeNear(point.position, points, point.id)
        point.lastPosition = nil
    end
    if not location then
        point.state = "Cooldown"
        point.nextSpawn = os.clock() + 5
        warn("[Lumia - Spawn Manager] Wolf spawn deferred (no clear ground): " .. point.id)
        return
    end

    local model = MonsterService:SpawnMonster(
        point.monsterId,
        location,
        true
    )

    if not model then
        point.state = "Cooldown"
        point.nextSpawn = os.clock() + 5
        return
    end

    point.model = model
    -- Record a successful safe spawn so respawns remain anchored to its area.
    if point.lastPosition then point.lastPosition = location end
    point.state = "Alive"
    point.outsideSince = nil
    point.lastCombat = 0

    model:SetAttribute("SpawnPointId", point.id)

    -- Death and cleanup are announced through LifecycleEvents. We do not
    -- schedule respawns directly from Humanoid.Died anymore.

    print(
        "[Lumia - Spawn Manager] Wolf activated:",
        point.id,
        "position:",
        location
    )
end

local function update(point, roots, now)
    if point.state == "Cooldown" then
        if now < point.nextSpawn then
            return
        end

        point.state = "Inactive"
    end

    if point.state == "Inactive" then
        local position = point.lastPosition or point.position

        if withinRadius(roots, position, SPAWN_RADIUS) then
            activate(point)
        end

        return
    end

    if point.state == "Corpse" then return end -- Wait for corpse-removed event.
    if point.state ~= "Alive" then
        return
    end

    local model = point.model

    if not model or not model.Parent then
        point.model = nil
        point.state = "Inactive"
        return
    end

    local humanoid = model:FindFirstChildOfClass("Humanoid")

    if not humanoid or humanoid.Health <= 0 then
        return
    end

    if model:GetAttribute("InCombat") == true then
        point.lastCombat = now
        point.outsideSince = nil
        return
    end

    if now - point.lastCombat < COMBAT_GRACE then
        point.outsideSince = nil
        return
    end

    local root = model:FindFirstChild("HumanoidRootPart")

    local nearWolf = root and withinRadius(
        roots,
        root.Position,
        DESPAWN_RADIUS
    )

    local nearSpawn = withinRadius(
        roots,
        point.position,
        DESPAWN_RADIUS
    )

    if nearWolf or nearSpawn then
        point.outsideSince = nil
        return
    end

    point.outsideSince = point.outsideSince or now

    if now - point.outsideSince >= DESPAWN_DELAY then
        -- Preserve only the roaming location.
        if root then
            point.lastPosition = root.Position
        end

        point.model = nil
        point.state = "Inactive"
        point.outsideSince = nil

        model:Destroy()

        print(
            "[Lumia - Spawn Manager] Wolf unloaded, roaming position saved:",
            point.id,
            point.lastPosition
        )
    end
end

function SpawnManager:Init()
    LifecycleEvents.Died.Event:Connect(function(model)
        local id = model and model:GetAttribute("SpawnPointId")
        local point = id and pointById[id]
        if point and point.model == model then
            point.state = "Corpse"
            point.outsideSince = nil
        end
    end)
    LifecycleEvents.CorpseRemoved.Event:Connect(function(model, pointId, monsterId, fullyLooted, respawnFactor)
        local point = pointId and pointById[pointId]
        if not point or point.model ~= model then return end
        point.model = nil
        point.lastPosition = nil -- Return to original spawn location.
        point.outsideSince = nil
        point.state = "Cooldown"
        local key = fullyLooted and "RespawnAfterLootedSeconds"
            or "RespawnAfterUnlootedSeconds"
        -- Use the defeated mob's SPAWN-TIME rate, not the current global rate.
        local factor = tonumber(respawnFactor) or 1
        local seconds = math.clamp(LifecycleConfig.Get(monsterId, key) * factor, 2, 3600)
        point.nextSpawn = os.clock() + seconds
        point.randomizeNext = true -- Respawns can relocate across the map.
        print("[Lumia - Spawn Manager] Corpse removed; " .. tostring(pointId)
            .. " respawn in " .. tostring(seconds) .. "s (looted="
            .. tostring(fullyLooted) .. ")")
    end)
    print("[Lumia - Spawn Manager] SpawnManager initialized")
end

function SpawnManager:Start()
    if started then
        return
    end

    started = true
    SpawnSafety.Start()

    task.spawn(function()
        -- Wait for the map and first character before registering the habitat.
        local center
        while not center and started do
            for _, player in ipairs(Players:GetPlayers()) do
                local character=player.Character
                local root=character and character:FindFirstChild("HumanoidRootPart")
                if root then
                    center=root.Position
                    break
                end
            end
            if not center then task.wait(0.5) end
        end
        if not started then return end
        region=getMapArea()
        for index=1,WolfSpawnConfig.WolfCount do
            local groundPosition=safeRandomPosition(WolfSpawnConfig.InitialPlacementAttempts)
            if groundPosition then
                local point={
                    id="ForgottenForest_Wolf_"..index,
                    monsterId="ForestWolf",
                    position=groundPosition,
                    lastPosition=nil,
                    state="Inactive",
                    lastCombat=0,
                    randomizeNext=false,
                }
                points[#points+1]=point
                pointById[point.id]=point
            else
                warn("[Lumia - Spawn Manager] No valid map-wide spawn for wolf "..index)
            end
        end
        print("[Lumia - Spawn Manager] SpawnManager registered",#points,
            "random shared spawn points across Forgotten Forest")

        while started do
            local now = os.clock()
            local roots = getPlayerRoots()

            for _, point in ipairs(points) do
                update(point, roots, now)
            end

            task.wait(CHECK_INTERVAL)
        end
    end)

    print("[Lumia - Spawn Manager] SpawnManager started")
end

return SpawnManager
