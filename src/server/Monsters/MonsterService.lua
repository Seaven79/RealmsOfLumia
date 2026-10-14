local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MonsterConfig = require(
    ReplicatedStorage
        :WaitForChild("Lumia")
        :WaitForChild("Shared")
        :WaitForChild("Monsters"):WaitForChild("MonsterConfig")
)

local MonsterAI = require(
    script.Parent:WaitForChild("MonsterAI")
)

local CreatureFactory = require(
    script.Parent:WaitForChild("CreatureFactory")
)

local MonsterService = {}

local started = false
local spawned = false

local folder

local function findGround(position)
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude

    local result = workspace:Raycast(
        position + Vector3.new(0, 60, 0),
        Vector3.new(0, -180, 0),
        params
    )

    if result then
        return result.Position + Vector3.new(0, 3.5, 0)
    end

    return position + Vector3.new(0, 5, 0)
end

function MonsterService:Init()
    folder = workspace:FindFirstChild("LumiaMonsters")

    if not folder then
        folder = Instance.new("Folder")
        folder.Name = "LumiaMonsters"
        folder.Parent = workspace
    end

    print("[Lumia] MonsterService initialized")
end

function MonsterService:SpawnMonster(monsterId, position, managedSpawn)
    local definition =
        MonsterConfig.Definitions[monsterId]

    if not definition then
        warn("[Lumia] Unknown monster: " .. tostring(monsterId))
        return nil
    end

    local model = CreatureFactory.Create(monsterId, definition)

    if not model then
        warn("[Lumia] Could not spawn: " .. tostring(monsterId))
        return nil
    end

    model.Name = definition.DisplayName
    model:SetAttribute("MonsterId", monsterId)
    model:SetAttribute("ManagedSpawn", managedSpawn == true)
    model:SetAttribute("MonsterLevel", definition.Level)
    model:SetAttribute("AggroType", definition.AggroType)

    local humanoid = model:FindFirstChildOfClass("Humanoid")
    local root = model:FindFirstChild("HumanoidRootPart")

    if not humanoid or not root then
        model:Destroy()
        return nil
    end

    humanoid.MaxHealth = definition.MaxHealth
    humanoid.Health = definition.MaxHealth
    humanoid.DisplayName =
        definition.DisplayName .. " [Lv. "
        .. definition.Level .. "]"

    humanoid.BreakJointsOnDeath = false

    root.Anchored = false
    model.PrimaryPart = root

    model.Parent = folder
    model:PivotTo(CFrame.new(position))

    pcall(function()
        root:SetNetworkOwner(nil)
    end)

    print("[Lumia] Monster spawned: " .. model.Name)

    humanoid.Died:Connect(function()
        print("[Lumia] Monster defeated: " .. model.Name)

        -- Rewards intentionally disabled until the existing
        -- sword system provides verified server-side attribution.

        task.delay(3, function()
            if model.Parent then
                model:Destroy()
            end
        end)

        task.delay(definition.RespawnDelay, function()
            if started and not model:GetAttribute("ManagedSpawn") then
                self:SpawnMonster(monsterId, position)
            end
        end)
    end)

    task.spawn(function()
        MonsterAI.Run(model, definition, position)
    end)

    return model
end

function MonsterService:Start()
    if started then
        return
    end

    started = true

    print("[Lumia] MonsterService started")
end

return MonsterService