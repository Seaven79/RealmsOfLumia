-- Realms of Eternia
-- SpawnManager v1.0
-- Shared player-centered activation with remembered roaming positions.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MonsterService = require(
    script.Parent:WaitForChild("MonsterService")
)

local MonsterConfig = require(
    ReplicatedStorage:WaitForChild("Eternia")
        :WaitForChild("Shared")
        :WaitForChild("MonsterConfig")
)

local SpawnManager = {}

local SPAWN_RADIUS = 100
local DESPAWN_RADIUS = 130
local DESPAWN_DELAY = 20
local COMBAT_GRACE = 10
local CHECK_INTERVAL = 0.25

local points = {}
local started = false

local offsets = {
    Vector3.new(13, 0, 13),
    Vector3.new(-13, 0, 13),
    Vector3.new(13, 0, -13),
    Vector3.new(-13, 0, -13),
}

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

local function findGround(position)
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude

    local monsters = workspace:FindFirstChild("EterniaMonsters")

    if monsters then
        params.FilterDescendantsInstances = {monsters}
    end

    local hit = workspace:Raycast(
        position + Vector3.new(0, 60, 0),
        Vector3.new(0, -180, 0),
        params
    )

    if hit then
        return hit.Position + Vector3.new(0, 3.5, 0)
    end

    return position + Vector3.new(0, 5, 0)
end

local function activate(point)
    if point.state ~= "Inactive" then
        return
    end

    point.state = "Spawning"

    local location = point.lastPosition or point.position

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
    point.state = "Alive"
    point.outsideSince = nil
    point.lastCombat = 0

    model:SetAttribute("SpawnPointId", point.id)

    local humanoid = model:FindFirstChildOfClass("Humanoid")

    humanoid.Died:Connect(function()
        if point.model ~= model then
            return
        end

        local definition =
            MonsterConfig.Definitions[point.monsterId]

        -- Death resets position to the original spawn location.
        point.lastPosition = nil
        point.model = nil
        point.state = "Cooldown"
        point.nextSpawn = os.clock() +
            (definition.RespawnDelay or 15)

        print("[Eternia] Wolf defeated; respawn timer:", point.id)
    end)

    print(
        "[Eternia] Wolf activated:",
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
            "[Eternia] Wolf unloaded, roaming position saved:",
            point.id,
            point.lastPosition
        )
    end
end

function SpawnManager:Init()
    print("[Eternia] SpawnManager initialized")
end

function SpawnManager:Start()
    if started then
        return
    end

    started = true

    task.spawn(function()
        -- Temporary test spawn points near the first player.
        -- Later replaced by fixed Forgotten Forest locations.
        local center

        while not center do
            for _, player in ipairs(Players:GetPlayers()) do
                local character = player.Character
                local root = character and
                    character:FindFirstChild("HumanoidRootPart")

                if root then
                    center = root.Position
                    break
                end
            end

            if not center then
                task.wait(0.5)
            end
        end

        for index, offset in ipairs(offsets) do
            points[index] = {
                id = "ForgottenForest_Wolf_" .. index,
                monsterId = "ForestWolf",
                position = findGround(center + offset),
                lastPosition = nil,
                state = "Inactive",
                lastCombat = 0,
            }
        end

        print(
            "[Eternia] SpawnManager registered",
            #points,
            "shared spawn points"
        )

        while started do
            local now = os.clock()
            local roots = getPlayerRoots()

            for _, point in ipairs(points) do
                update(point, roots, now)
            end

            task.wait(CHECK_INTERVAL)
        end
    end)

    print("[Eternia] SpawnManager started")
end

return SpawnManager