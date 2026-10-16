-- Lumia V15 achievement startup: never lets clients grant achievements.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local services = script.Parent.Parent
local Achievements = require(script.Parent:WaitForChild("AchievementService"))
local PlayerData = require(services:WaitForChild("Players"):WaitForChild("PlayerDataService"))
local Life = require(services:WaitForChild("Monsters"):WaitForChild("MonsterLifecycleEvents"))
local QuestConfig = require(ReplicatedStorage:WaitForChild("Lumia")
    :WaitForChild("Shared"):WaitForChild("Quests"):WaitForChild("QuestConfig"))

Achievements:Init()
Achievements:Start()

local function recover(player)
    local deadline = os.clock() + 40
    while player.Parent == Players and os.clock() < deadline do
        if PlayerData:GetProfile(player) then
            Achievements:EvaluateProgress(player)
            return
        end
        task.wait(0.4)
    end
end
Players.PlayerAdded:Connect(function(player) task.spawn(recover, player) end)
for _, player in ipairs(Players:GetPlayers()) do task.spawn(recover, player) end

local processed = setmetatable({}, {__mode="k"})
Life.Died.Event:Connect(function(model, monsterId)
    -- This achievement is ready for the future boss encounter. No fake boss
    -- completion from quests or unrelated wolf kills.
    if monsterId ~= "ThornboundGuardian" or not model or processed[model] then return end
    processed[model] = true
    if model:GetAttribute("LumiaDead") ~= true then return end
    local lastHitter = model:GetAttribute("LumiaLastHitUserId")
    local time = model:GetAttribute("LumiaLastHitAt")
    if type(lastHitter) ~= "number" or type(time) ~= "number"
        or os.clock() - time > (QuestConfig.HitCreditSeconds or 10) then return end
    local center = model:GetPivot().Position
    local eligible = {}
    for _, player in ipairs(Players:GetPlayers()) do
        local c = player.Character
        local h = c and c:FindFirstChildOfClass("Humanoid")
        local r = c and c:FindFirstChild("HumanoidRootPart")
        local p = PlayerData:GetProfile(player)
        if p and p.Character.Level >= 5 and h and h.Health > 0 and r
            and (r.Position - center).Magnitude <= 50 then
            local questDone = true
            for _, quest in ipairs(QuestConfig.Quests) do
                if not p.Progression.CompletedQuests[quest.Id] then
                    questDone = false
                    break
                end
            end
            if questDone then table.insert(eligible,player) end
        end
    end
    -- Requires exactly two eligible nearby players, including the real last hitter.
    if #eligible ~= 2 then return end
    if eligible[1].UserId ~= lastHitter and eligible[2].UserId ~= lastHitter then return end
    for _, player in ipairs(eligible) do
        Achievements:Award(player, "GuardiansOfLumia")
    end
end)
print("[Lumia V15] Achievements initialized, boss reward waits for genuine cooperative victory")
