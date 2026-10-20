-- REALMS OF LUMIA | OWNER-ONLY ADMIN BRIDGE
-- One RemoteFunction, one owner. Every write is re-validated against the shared
-- AdminSchema; the client is never trusted for range, key, or identity.
-- Non-owners receive an explicit refusal and an audit line, never data.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local services = script.Parent.Parent
local Settings = require(script.Parent:WaitForChild("BalanceSettings"))
local BalanceService = require(script.Parent:WaitForChild("BalanceService"))
local MobTuning = require(script.Parent:WaitForChild("MobTuningService"))
local CurveLab = require(script.Parent:WaitForChild("CurveLabService"))
local ProgressionService = require(services:WaitForChild("Progression"):WaitForChild("ProgressionService"))

local lumia = ReplicatedStorage:WaitForChild("Lumia")
local Shared = lumia:WaitForChild("Shared")
local Schema = require(Shared:WaitForChild("Admin"):WaitForChild("AdminSchema"))
local GlobalTuning = require(Shared:WaitForChild("Admin"):WaitForChild("GlobalTuning"))
local CurveMath = require(Shared:WaitForChild("Progression"):WaitForChild("CurveMath"))

local network = lumia:FindFirstChild("AdminNetwork")
if not network then
    network = Instance.new("Folder")
    network.Name = "AdminNetwork"
    network.Parent = lumia
end

local requestRemote = network:FindFirstChild("AdminRequest")
if not requestRemote then
    requestRemote = Instance.new("RemoteFunction")
    requestRemote.Name = "AdminRequest"
    requestRemote.Parent = network
end

local MAX_OPS = 200
local REQUESTS_PER_SECOND = 15
local AUDIT_LIMIT = 60

local audit = {}
local rateState = setmetatable({}, { __mode = "k" })

local function log(line)
    audit[#audit + 1] = string.format("%s  %s", os.date("%H:%M:%S"), line)
    while #audit > AUDIT_LIMIT do
        table.remove(audit, 1)
    end
    print("[Lumia - Admin] " .. line)
end

local function rateLimited(player)
    local now = os.clock()
    local entry = rateState[player]
    if not entry or now - entry.Window >= 1 then
        rateState[player] = { Window = now, Count = 1 }
        return false
    end
    entry.Count = entry.Count + 1
    return entry.Count > REQUESTS_PER_SECOND
end

--------------------------------------------------------------------------------
-- Reads
--------------------------------------------------------------------------------

local function currentValue(field)
    if field.Category == "LevelXP" then
        return BalanceService:GetBaseRequiredXPForPanel(field.Key)
    elseif field.Category == "QuestRewardXP" then
        return BalanceService:GetQuestRewardXP(field.Key)
    elseif field.Category == "QuestRewardGold" then
        return BalanceService:GetQuestRewardGold(field.Key)
    elseif field.Category == "MonsterXP" then
        return BalanceService:GetMonsterXP(field.Key)
    end
    return nil
end

local function buildState(player)
    local values = {}
    local overridden = {}
    for _, field in ipairs(Schema.Fields) do
        local value = currentValue(field)
        values[field.Id] = value
        if value ~= nil and value ~= field.Default then
            overridden[field.Id] = true
        end
    end

    local balance = BalanceService:Snapshot()
    local monsters = MobTuning:Snapshot()
    local difficulty = CurveLab:Snapshot()

    return {
        Ok = true,
        Authorized = true,
        SchemaVersion = Schema.Version,
        Values = values,
        Overridden = overridden,
        Revision = balance.Revision,
        Persistence = {
            Balance = balance.PersistenceAvailable == true,
            MobTuning = monsters.PersistenceAvailable == true,
            DifficultyTest = difficulty.CanTest == true,
        },
        Monsters = monsters,
        Difficulty = difficulty,
        Global = {
            Values = balance.Global,
            Preset = balance.GlobalPreset,
            Dials = GlobalTuning.Dials,
            Presets = GlobalTuning.Presets,
            Preview = balance.Preview,
        },
        Audit = table.clone(audit),
        Server = {
            PlaceId = game.PlaceId,
            OwnerUserId = Settings.OwnerUserId,
            PlayerUserId = player.UserId,
        },
    }
end

--------------------------------------------------------------------------------
-- Writes
--------------------------------------------------------------------------------

local RESET_KIND = {
    LevelXP = "ResetLevelXP",
    QuestRewardXP = "ResetQuestRewardXP",
    QuestRewardGold = "ResetQuestRewardGold",
    MonsterXP = "ResetMonsterXP",
}

local function applyOperation(player, operation)
    if type(operation) ~= "table" or type(operation.Id) ~= "string" then
        return false, "Malformed operation"
    end

    local field = Schema.GetField(operation.Id)
    if not field then
        return false, "Unknown setting: " .. tostring(operation.Id)
    end

    local ok, reason = Schema.Validate(field, operation.Value)
    if not ok then
        return false, tostring(reason)
    end

    local before = currentValue(field)
    local saved, errorReason = BalanceService:Update(
        field.Category, field.Key, operation.Value)
    if not saved then
        return false, tostring(errorReason)
    end

    log(string.format("%s  %s  %s -> %s", player.Name, field.Id,
        tostring(before), tostring(operation.Value)))
    return true
end

local function applyReset(player, fieldId)
    local field = Schema.GetField(fieldId)
    if not field then return false, "Unknown setting" end
    local resetKind = RESET_KIND[field.Category]
    if not resetKind then return false, "This setting cannot be reset" end

    local saved, errorReason = BalanceService:Update(resetKind, field.Key)
    if not saved then return false, tostring(errorReason) end

    log(string.format("%s  reset %s", player.Name, fieldId))
    return true
end

local function applyMobStat(player, payload)
    local monsterId = payload.MonsterId
    local key = payload.Key
    local value = payload.Value

    if type(monsterId) ~= "string" or type(key) ~= "string" then
        return false, "Malformed monster operation"
    end

    if value == nil then
        local ok, reason = MobTuning:Update(monsterId, "ResetStat", key)
        if ok then log(string.format("%s  reset %s.%s", player.Name, monsterId, key)) end
        return ok, reason
    end

    local ok, reason = MobTuning:Update(monsterId, "Stat", key, value)
    if ok then
        log(string.format("%s  %s.%s -> %s", player.Name, monsterId, key, tostring(value)))
    end
    return ok, reason
end

local function applyDifficulty(player, payload)
    if payload.Stop == true then
        local ok, reason = CurveLab:Stop()
        if ok then log(string.format("%s  stopped difficulty trial", player.Name)) end
        return ok, reason
    end

    local intensity = tonumber(payload.Intensity)
    if not intensity then return false, "Intensity must be a number" end
    intensity = math.clamp(intensity, CurveMath.IntensityMin, CurveMath.IntensityMax)

    local values = CurveMath.FromIntensity(intensity)
    if not values then return false, "Intensity out of range" end

    local ok, reason = CurveLab:Begin(values)
    if ok then
        log(string.format("%s  started difficulty trial at %.2f", player.Name, intensity))
    end
    return ok, reason
end

--------------------------------------------------------------------------------
-- Dispatch
--------------------------------------------------------------------------------

local handlers = {}

-- Lightweight ownership probe. Returns no game data, so the client can decide
-- whether to show its launcher button without paying for a full state build.
handlers.Ping = function(player)
    return { Ok = true, Authorized = true, UserId = player.UserId }
end

handlers.State = function(player)
    return { Ok = true, State = buildState(player) }
end

handlers.Apply = function(player, payload)
    local operations = type(payload) == "table" and payload.Ops or nil
    if type(operations) ~= "table" or #operations == 0 then
        return { Ok = false, Reason = "No changes to apply" }
    end
    if #operations > MAX_OPS then
        return { Ok = false, Reason = "Too many changes in one request" }
    end

    local applied, failures = 0, {}
    for _, operation in ipairs(operations) do
        local ok, reason = applyOperation(player, operation)
        if ok then
            applied = applied + 1
        else
            failures[#failures + 1] = {
                Id = operation and operation.Id or "?",
                Reason = tostring(reason),
            }
        end
    end

    return {
        Ok = applied > 0,
        Applied = applied,
        Failures = failures,
        State = buildState(player),
    }
end

handlers.Reset = function(player, payload)
    local ids = type(payload) == "table" and payload.Ids or nil
    if type(ids) ~= "table" or #ids == 0 then
        return { Ok = false, Reason = "No settings selected" }
    end
    if #ids > MAX_OPS then
        return { Ok = false, Reason = "Too many changes in one request" }
    end

    local applied, failures = 0, {}
    for _, fieldId in ipairs(ids) do
        local ok, reason = applyReset(player, fieldId)
        if ok then
            applied = applied + 1
        else
            failures[#failures + 1] = { Id = tostring(fieldId), Reason = tostring(reason) }
        end
    end

    return {
        Ok = applied > 0,
        Applied = applied,
        Failures = failures,
        State = buildState(player),
    }
end

-- Owner-only maintenance actions. These change the OWNER's own character and
-- are audited like any other write.
handlers.ResetLevel = function(player)
    local ok, result = ProgressionService:ResetProgress(player)
    if not ok then
        return { Ok = false, Reason = tostring(result) }
    end

    -- Refresh the XP bar immediately; otherwise it keeps showing the old level.
    local networkFolder = lumia:FindFirstChild("ProgressionNetwork")
    local changed = networkFolder and networkFolder:FindFirstChild("ProgressionChanged")
    if changed and changed:IsA("RemoteEvent") then
        changed:FireClient(player, {
            Ready = true,
            Level = result.Level,
            Experience = result.Experience,
            RequiredXP = result.RequiredXP,
            MaxLevel = result.MaxLevel,
        })
    end

    log(string.format("%s  RESET LEVEL  %d (%d xp) -> 1 (0 xp)", player.Name,
        result.PreviousLevel, result.PreviousExperience))
    return { Ok = true, Result = result, State = buildState(player) }
end

handlers.MobStat = function(player, payload)
    if type(payload) ~= "table" then
        return { Ok = false, Reason = "Malformed request" }
    end
    local ok, reason = applyMobStat(player, payload)
    return { Ok = ok == true, Reason = reason, State = buildState(player) }
end

-- Global dials: either one dial, or a whole preset in a single transaction.
handlers.Global = function(player, payload)
    if type(payload) ~= "table" then
        return { Ok = false, Reason = "Malformed request" }
    end

    if payload.Preset ~= nil then
        local ok, reason = BalanceService:ApplyPreset(payload.Preset)
        if not ok then return { Ok = false, Reason = tostring(reason) } end
        log(string.format("%s  preset -> %s", player.Name, tostring(payload.Preset)))
        return { Ok = true, State = buildState(player) }
    end

    local dialId = payload.Id
    local value = tonumber(payload.Value)
    if type(dialId) ~= "string" or not value then
        return { Ok = false, Reason = "Malformed dial request" }
    end

    local ok, reason = BalanceService:SetGlobal(dialId, value)
    if not ok then return { Ok = false, Reason = tostring(reason) } end

    log(string.format("%s  %s = %.2f", player.Name, dialId, value))
    return { Ok = true, State = buildState(player) }
end

handlers.Difficulty = function(player, payload)
    if type(payload) ~= "table" then
        return { Ok = false, Reason = "Malformed request" }
    end
    local ok, reason = applyDifficulty(player, payload)
    return { Ok = ok == true, Reason = reason, State = buildState(player) }
end

requestRemote.OnServerInvoke = function(player, action, payload)
    -- Identity check first: nothing else runs for a non-owner.
    if player.UserId ~= Settings.OwnerUserId then
        -- Ownership probes are expected from every client; do not spam the log.
        if action ~= "Ping" then
            log(string.format("REFUSED %s (%d) action=%s", player.Name, player.UserId,
                tostring(action)))
        end
        return { Ok = false, Authorized = false, Reason = "Not authorized" }
    end

    if type(action) ~= "string" then
        return { Ok = false, Authorized = true, Reason = "Malformed request" }
    end

    local handler = handlers[action]
    if not handler then
        return { Ok = false, Authorized = true, Reason = "Unknown action" }
    end

    if rateLimited(player) then
        return { Ok = false, Authorized = true, Reason = "Slow down" }
    end

    local ok, result = pcall(handler, player, payload)
    if not ok then
        warn("[Lumia - Admin] Handler error for " .. tostring(action) .. ": " .. tostring(result))
        return { Ok = false, Authorized = true, Reason = "Server error" }
    end
    return result
end

Players.PlayerRemoving:Connect(function(player)
    rateState[player] = nil
end)

print("[Lumia - Admin] Owner-only admin bridge ready")
