-- REALMS OF LUMIA | XP REWARDS AND PROGRESSION NETWORK v1.0
-- Server-only listener. No client may request XP awards.
-- Existing ProgressionService owns character.Level and character.Experience.
-- MonsterService fires MonsterLifecycleEvents.Died after a confirmed death.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local services = script.Parent.Parent
local ProgressionService = require(script.Parent:WaitForChild("ProgressionService"))
local PlayerPositions = require(game:GetService("ReplicatedStorage"):WaitForChild("Lumia"):WaitForChild("Shared"):WaitForChild("Players"):WaitForChild("PlayerPositions"))
local PlayerDataService = require(services:WaitForChild("Players"):WaitForChild("PlayerDataService"))
local Events = require(services:WaitForChild("Monsters"):WaitForChild("MonsterLifecycleEvents"))

local lumia = ReplicatedStorage:WaitForChild("Lumia")
local shared = lumia:WaitForChild("Shared")
local ProgressionConfig = require(shared:WaitForChild("Progression"):WaitForChild("ProgressionConfig"))
local BalanceService = require(services:WaitForChild("Admin"):WaitForChild("BalanceService"))
local CurveLab = require(services:WaitForChild("Admin"):WaitForChild("CurveLabService"))
local LootConfig = require(shared:WaitForChild("Loot"):WaitForChild("LootConfig"))

local network = lumia:FindFirstChild("ProgressionNetwork")
if not network then
    network = Instance.new("Folder")
    network.Name = "ProgressionNetwork"
    network.Parent = lumia
end

local changed = network:FindFirstChild("ProgressionChanged")
if not changed then
    changed = Instance.new("RemoteEvent")
    changed.Name = "ProgressionChanged"
    changed.Parent = network
end

local getProgression = network:FindFirstChild("GetProgression")
if not getProgression then
    getProgression = Instance.new("RemoteFunction")
    getProgression.Name = "GetProgression"
    getProgression.Parent = network
end

local processed = setmetatable({}, {__mode = "k"})

local function snapshot(player)
    local profile = PlayerDataService:GetProfile(player)
    local character = profile and profile.Character
    if not character then
        return { Ready = false }
    end

    local level = character.Level
    if type(level) ~= "number" or type(character.Experience) ~= "number" then
        return { Ready = false }
    end

    return {
        Ready = true,
        Level = level,
        Experience = character.Experience,
        RequiredXP = BalanceService:GetRequiredXP(level),
        MaxLevel = ProgressionConfig.MAX_LEVEL,
    }
end

-- Read only: this RemoteFunction cannot grant experience.
getProgression.OnServerInvoke = function(player)
    if player.Parent ~= Players then
        return { Ready = false }
    end
    return snapshot(player)
end

Events.Died.Event:Connect(function(model, monsterId)
    if typeof(model) ~= "Instance" or not model:IsA("Model") or processed[model] then
        return
    end
    processed[model] = true -- one award attempt per defeated monster

    if model:GetAttribute("LumiaDead") ~= true then
        return
    end

    -- Kill XP was snapshotted when this monster spawned.
    -- Legacy monsters without this attribute use the original calculation.
    local monsterLevel = model:GetAttribute("MonsterLevel") or 1
    local xp = model:GetAttribute("LumiaSpawnXP")
    if type(xp) ~= "number" then
        xp = CurveLab:Adjust("KillXP", monsterLevel,
            BalanceService:GetMonsterXP(monsterId), 1000000)
    end
    if type(xp) ~= "number" or xp % 1 ~= 0 or xp < 1 or xp > 1000000 then
        return
    end

    -- SwordCombatService writes these ONLY after server-validated hits.
    local userId = model:GetAttribute("LumiaLastHitUserId")
    local hitTime = model:GetAttribute("LumiaLastHitAt")
    if type(userId) ~= "number" or type(hitTime) ~= "number" then
        return
    end
    local elapsed = os.clock() - hitTime
    local creditSeconds = LootConfig.HitCreditLifetimeSeconds or 10
    if elapsed < 0 or elapsed > creditSeconds then
        return
    end

    local killer = Players:GetPlayerByUserId(userId)
    if not killer then
        return
    end

    -- Co-op pre-alpha: teammates close to the *defeated wolf* receive the same
    -- XP as the last hitter. The monster and hit are still validated above.
    -- This mirrors QuestService's co-op objective credit and prevents level gaps.
    local defeatedAt=model:GetPivot().Position
    local recipients={killer}
    for _,entry in ipairs(PlayerPositions:Roots()) do
        if entry.Player~=killer then
            if (entry.Position-defeatedAt).Magnitude<=36 then
                table.insert(recipients,entry.Player)
            end
        end
    end
    for _,recipient in ipairs(recipients) do
        local ok, awarded, details=pcall(function()
            return ProgressionService:AddXP(recipient,xp)
        end)
        if not ok then
            warn("[Lumia - Progression Bridge] Award error: "..tostring(awarded))
        elseif awarded then
            local data=snapshot(recipient)
            if data.Ready then
                data.GainedXP=xp
                data.LevelsGained=details.LevelsGained or 0
                changed:FireClient(recipient,data)
            end
            local coins = model:GetAttribute("LumiaSpawnGold")
            if type(coins) ~= "number" then
                local mobConfig = require(shared:WaitForChild("Monsters"):WaitForChild("MonsterConfig"))
                local base = mobConfig.Definitions[monsterId]
                coins = CurveLab:Adjust("Gold", monsterLevel,
                    base and base.GoldReward or 0, 1000000)
            end
            if type(coins)=="number" and coins>=1 and coins<=1000000 and coins%1==0 then
                ProgressionService:AddGold(recipient, coins)
            end
            print(string.format("[Lumia XP] %s earned %d XP for %s",recipient.Name,xp,monsterId))
        end
    end
end)

BalanceService.Changed.Event:Connect(function()
    for _, player in ipairs(Players:GetPlayers()) do
        local data=snapshot(player)
        if data.Ready then changed:FireClient(player,data) end
    end
end)

print("[Lumia - Progression Bridge] XP rewards ready - server-confirmed kills, persistent progression")
