-- REALMS OF LUMIA | restricted Curve Lab remotes (server validates everything).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Settings = require(script.Parent:WaitForChild("BalanceSettings"))
local Lab = require(script.Parent:WaitForChild("CurveLabService"))
local Balance = require(script.Parent:WaitForChild("BalanceService"))
local MobTuning = require(script.Parent:WaitForChild("MobTuningService"))
local Shared = ReplicatedStorage:WaitForChild("Lumia"):WaitForChild("Shared")
local ProgressionConfig = require(Shared:WaitForChild("Progression"):WaitForChild("ProgressionConfig"))
local MonsterConfig = require(Shared:WaitForChild("Monsters"):WaitForChild("MonsterConfig"))
local folder = ReplicatedStorage:WaitForChild("Lumia"):FindFirstChild("CurveLabNetwork")
if not folder then folder = Instance.new("Folder"); folder.Name = "CurveLabNetwork"; folder.Parent = ReplicatedStorage.Lumia end

local function remote(name)
    local object = folder:FindFirstChild(name)
    if object then assert(object:IsA("RemoteFunction"), "Unexpected curve remote")
    else object = Instance.new("RemoteFunction"); object.Name = name; object.Parent = folder end
    return object
end
local get = remote("GetCurveLab")
local set = remote("SetCurveLab")
local previous = {}
local function isOwner(player)
    return player and player.Parent == Players and player.UserId == Settings.OwnerUserId
end
local function snapshot()
    local data = Lab:Snapshot()
    data.MaxLevel = ProgressionConfig.MAX_LEVEL
    data.Monsters = {}
    data.MonsterIds = {}
    for id in pairs(MonsterConfig.Definitions) do
        data.Monsters[id] = MobTuning:GetDefinition(id)
        table.insert(data.MonsterIds, id)
    end
    table.sort(data.MonsterIds)
    data.BaseKillXP = {}
    for id in pairs(MonsterConfig.Definitions) do
        data.BaseKillXP[id] = Balance:GetMonsterXP(id)
    end
    data.BaselineLevelXP = {}
    for lvl = 1, ProgressionConfig.MAX_LEVEL - 1 do
        data.BaselineLevelXP[tostring(lvl)] = Balance:GetBaseRequiredXP(lvl)
    end
    return data
end
get.OnServerInvoke = function(player)
    if not isOwner(player) then return {Authorized = false} end
    return {Authorized = true, Data = snapshot()}
end
set.OnServerInvoke = function(player, action, values)
    if not isOwner(player) then return false, "Not authorized" end
    local now = os.clock()
    if now - (previous[player] or -100) < 0.7 then return false, "Please wait briefly." end
    previous[player] = now
    if action == "Stop" then
        Lab:Stop()
    elseif action == "TestIntensity" then
        -- Never accept arbitrary client-supplied stat tables: only the
        -- server-side ONE-DIAL generator can construct global values.
        local generated = require(Shared:WaitForChild("Progression")
            :WaitForChild("CurveMath")).FromIntensity(values)
        if not generated then return false, "Curve strength must be 0.50 to 2.00." end
        local ok, reason = Lab:Begin(generated)
        if not ok then return false, reason end
    else
        return false, "Unknown action"
    end
    return true, snapshot()
end
Players.PlayerRemoving:Connect(function(player) previous[player] = nil end)
print("[Lumia - Curve Lab] Owner-only, temporary session testing ready")
