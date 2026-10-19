-- REALMS OF LUMIA | spawn-only global difficulty curves.
-- Published settings are read from Roblox Experience Configs (read-only).
-- Owner may temporarily override them on Studio/private servers for 8 minutes.
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CurveMath = require(ReplicatedStorage:WaitForChild("Lumia")
    :WaitForChild("Shared"):WaitForChild("Progression"):WaitForChild("CurveMath"))
local Settings = require(script.Parent:WaitForChild("BalanceSettings"))
local GlobalConfig = require(script.Parent:WaitForChild("GlobalCurveConfig"))

local CurveLabService = {}
CurveLabService.Changed = Instance.new("BindableEvent")
local active = false
local activeValues = CurveMath.Presets("Classic")
local generation = 0
local expiresAt = 0
local TRIAL_SECONDS = 480

local function safeServer()
    return RunService:IsStudio() or game.PrivateServerId ~= ""
end

local function stop()
    if not active then return end
    active = false
    expiresAt = 0
    generation += 1
    CurveLabService.Changed:Fire()
end

function CurveLabService:IsActive()
    if active and os.clock() >= expiresAt then stop() end
    return active
end

function CurveLabService:GetEffectiveValues()
    if self:IsActive() then return activeValues end
    return GlobalConfig:GetValues()
end

function CurveLabService:Snapshot()
    local testing = self:IsActive()
    local status, version = GlobalConfig:GetStatus()
    return {
        Active = testing,
        SecondsRemaining = testing and math.max(0, math.ceil(expiresAt - os.clock())) or 0,
        CanTest = safeServer(),
        Values = testing and table.clone(activeValues) or GlobalConfig:GetValues(),
        Source = testing and "Local server test" or status,
        PublishedVersion = version,
        DurationSeconds = TRIAL_SECONDS,
        SpawnOnly = true,
        GlobalForAllMonsters = true,
    }
end

function CurveLabService:Begin(values)
    if not safeServer() then
        return false, "Testing is restricted to Studio or a private server."
    end
    if not CurveMath.Valid(values) then return false, "Invalid global curve values." end
    activeValues = CurveMath.Normalize(values)
    active = true
    expiresAt = os.clock() + TRIAL_SECONDS
    generation += 1
    local ticket = generation
    CurveLabService.Changed:Fire()
    task.delay(TRIAL_SECONDS, function()
        if ticket == generation then stop() end
    end)
    return true, self:Snapshot()
end

function CurveLabService:Stop()
    stop()
    return true, self:Snapshot()
end

function CurveLabService:Adjust(kind, level, base, maxValue)
    return CurveMath.Adjust(kind, level, base, self:GetEffectiveValues(), maxValue)
end

function CurveLabService:GetDefenseFactor(level)
    return CurveMath.Factor("Defense", level, self:GetEffectiveValues())
end

function CurveLabService:GetRespawnFactor(level)
    return 1 / CurveMath.Factor("Respawn", level, self:GetEffectiveValues())
end

function CurveLabService:ApplyMonsterDefinition(definition)
    if type(definition) ~= "table" then return definition end
    local copy = table.clone(definition)
    local level = copy.Level or 1
    copy.MaxHealth = self:Adjust("Health", level, copy.MaxHealth, 100000)
    copy.Damage = self:Adjust("Damage", level, copy.Damage, 10000)
    copy.AttackCooldown = CurveMath.AdjustStat("AttackSpeed", level,
        copy.AttackCooldown or 2, self:GetEffectiveValues(), 0.6, 12)
    copy.WalkSpeed = CurveMath.AdjustStat("Movement", level,
        copy.WalkSpeed or 8, self:GetEffectiveValues(), 2, 20)
    copy.ChaseSpeed = CurveMath.AdjustStat("Movement", level,
        copy.ChaseSpeed or 13, self:GetEffectiveValues(), 3, 26)
    copy.DetectionRadius = CurveMath.AdjustStat("Detection", level,
        copy.DetectionRadius or 8, self:GetEffectiveValues(), 3, 45)
    copy.ChaseLimit = CurveMath.AdjustStat("Detection", level,
        copy.ChaseLimit or 20, self:GetEffectiveValues(), 10, 65)
    copy.WanderRadius = CurveMath.AdjustStat("Wander", level,
        copy.WanderRadius or 6, self:GetEffectiveValues(), 0, 100)
    copy.AttackRange = CurveMath.AdjustStat("AttackRange", level,
        copy.AttackRange or 4, self:GetEffectiveValues(), 3, 9)
    -- Keep the existing wall and melee-position checks intact.
    return copy
end

GlobalConfig.Changed.Event:Connect(function()
    -- Existing monsters keep per-spawn values; player XP bar can refresh.
    CurveLabService.Changed:Fire()
end)

Players.PlayerRemoving:Connect(function(player)
    if player.UserId == Settings.OwnerUserId then stop() end
end)

return CurveLabService
