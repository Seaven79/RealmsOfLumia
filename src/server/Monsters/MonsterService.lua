local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Monster type data comes from a server-only persisted balance service.
-- Keep MonsterAI on a per-spawn snapshot so existing AI is not disturbed.
local MobTuning = require(script.Parent.Parent:WaitForChild("Admin"):WaitForChild("MobTuningService"))

local MonsterAI = require(
    script.Parent:WaitForChild("MonsterAI")
)

local CreatureFactory = require(
    script.Parent:WaitForChild("CreatureFactory")
)

local MonsterDeathPresentation = require(
    script.Parent:WaitForChild("MonsterDeathPresentation")
)

local LifecycleEvents = require(script.Parent:WaitForChild("MonsterLifecycleEvents"))
local LifecycleConfig = require(ReplicatedStorage:WaitForChild("Lumia")
    :WaitForChild("Shared"):WaitForChild("Monsters")
    :WaitForChild("CorpseLifecycleConfig"))

local MonsterService = {}

local started = false
local spawned = false

local folder
-- Weak keys let removed monsters be garbage-collected normally.
local cleanupGeneration = setmetatable({}, {__mode = "k"})
local spawnOrigins = setmetatable({}, {__mode = "k"})

local function scheduleRemoval(self, model, monsterId, fullyLooted)
    if not model or not model.Parent then return end
    local generation = (cleanupGeneration[model] or 0) + 1
    cleanupGeneration[model] = generation
    local key = fullyLooted and "LootedCorpseSeconds" or "UnlootedCorpseSeconds"
    local delaySeconds = LifecycleConfig.Get(monsterId, key)
    task.delay(delaySeconds, function()
        if cleanupGeneration[model] ~= generation or not model.Parent then return end
        local pointId = model:GetAttribute("SpawnPointId")
        local managed = model:GetAttribute("ManagedSpawn") == true
        local origin = spawnOrigins[model]
        cleanupGeneration[model] = nil
        spawnOrigins[model] = nil
        model:Destroy()
        -- Start the timer *after* the model disappears, never at death.
        LifecycleEvents.CorpseRemoved:Fire(model, pointId, monsterId, fullyLooted)
        if started and not managed and origin then
            local respawnKey = fullyLooted and "RespawnAfterLootedSeconds"
                or "RespawnAfterUnlootedSeconds"
            task.delay(LifecycleConfig.Get(monsterId, respawnKey), function()
                if started then self:SpawnMonster(monsterId, origin, false) end
            end)
        end
    end)
end

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

    LifecycleEvents.LootCompleted.Event:Connect(function(model)
        if not model or not model.Parent
            or model:GetAttribute("LumiaDead") ~= true
            or model:GetAttribute("LumiaLooted") == true then return end
        model:SetAttribute("LumiaLooted", true)
        local monsterId = model:GetAttribute("MonsterId")
        scheduleRemoval(self, model, monsterId, true)
        print("[Lumia - Monster Service] Corpse fully looted: 3s cleanup scheduled for " .. model.Name)
    end)
    print("[Lumia - Monster Service] MonsterService initialized")
end

function MonsterService:SpawnMonster(monsterId, position, managedSpawn)
    local definition = MobTuning:GetDefinition(monsterId)

    if not definition then
        warn("[Lumia - Monster Service] Unknown monster: " .. tostring(monsterId))
        return nil
    end

    local model = CreatureFactory.Create(monsterId, definition)

    if not model then
        warn("[Lumia - Monster Service] Could not spawn: " .. tostring(monsterId))
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
    spawnOrigins[model] = position

    pcall(function()
        root:SetNetworkOwner(nil)
    end)

    print("[Lumia - Monster Service] Monster spawned: " .. model.Name)

    humanoid.Died:Connect(function()
        if model:GetAttribute("LumiaDead") then return end
        model:SetAttribute("LumiaDead", true)
        print("[Lumia - Monster Service] Monster defeated: " .. model.Name)
        local success, err = pcall(MonsterDeathPresentation.Apply, model, monsterId)
        if not success then warn("[Lumia - Monster Service] Corpse pose failed: " .. tostring(err)) end
        -- LootService listens to Died and owns rolls/ownership. It may call
        -- LootCompleted later; then the 20-second cleanup is superseded.
        LifecycleEvents.Died:Fire(model, monsterId)
        scheduleRemoval(self, model, monsterId, false)
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

    print("[Lumia - Monster Service] MonsterService started")
end

return MonsterService
