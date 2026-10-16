local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local services = script.Parent.Parent
local PlayerDataService = require(services:WaitForChild("Players"):WaitForChild("PlayerDataService"))
local InventoryService = require(services:WaitForChild("Inventory"):WaitForChild("InventoryService"))
local AchievementConfig = require(ReplicatedStorage:WaitForChild("Lumia")
    :WaitForChild("Shared"):WaitForChild("Progression"):WaitForChild("AchievementConfig"))
local QuestConfig = require(ReplicatedStorage:WaitForChild("Lumia")
    :WaitForChild("Shared"):WaitForChild("Quests"):WaitForChild("QuestConfig"))

local AchievementService = {}
local started = false
local earnedEvent
local networkFolder

local function ensureProgression(profile)
    profile.Progression = profile.Progression or {}
    profile.Progression.CompletedQuests = profile.Progression.CompletedQuests or {}
    profile.Progression.ActiveQuests = profile.Progression.ActiveQuests or {}
    profile.Progression.DiscoveredZones = profile.Progression.DiscoveredZones or {}
    profile.Progression.Achievements = profile.Progression.Achievements or {}
    profile.Progression.AchievementRewardsGranted = profile.Progression.AchievementRewardsGranted or {}
    if type(profile.Progression.CurrentTitle) ~= "string" then
        profile.Progression.CurrentTitle = ""
    end
    return profile.Progression
end

local function getProfile(player)
    local profile = PlayerDataService:GetProfile(player)
    if not profile then
        return nil
    end
    ensureProgression(profile)
    return profile
end

local function countKeys(map)
    local count = 0
    if type(map) ~= "table" then
        return 0
    end
    for _ in pairs(map) do
        count += 1
    end
    return count
end

local function completedQuestCount(profile)
    return countKeys(profile and profile.Progression and profile.Progression.CompletedQuests)
end

local function rewardItem(player, profile, achievementId, itemId)
    if type(itemId) ~= "string" or itemId == "" then
        return
    end

    local progress = ensureProgression(profile)
    if progress.AchievementRewardsGranted[achievementId] == true then
        return
    end

    local added = InventoryService:AddItem(player, itemId, 1)
    if added then
        progress.AchievementRewardsGranted[achievementId] = true
    else
        warn("[Lumia - Achievement Service] Could not grant reward item: " .. tostring(itemId))
    end
end

local function buildSnapshot(player)
    local profile = getProfile(player)
    if not profile then
        return {Ready = false}
    end

    local progress = ensureProgression(profile)
    local unlocked = {}
    for _, id in ipairs(AchievementConfig.Order) do
        if progress.Achievements[id] then
            unlocked[#unlocked + 1] = id
        end
    end

    return {
        Ready = true,
        CurrentTitle = progress.CurrentTitle,
        Unlocked = unlocked,
    }
end

function AchievementService:Init()
    local lumia = ReplicatedStorage:WaitForChild("Lumia")
    networkFolder = lumia:FindFirstChild("AchievementNetwork")
    if not networkFolder then
        networkFolder = Instance.new("Folder")
        networkFolder.Name = "AchievementNetwork"
        networkFolder.Parent = lumia
    end

    earnedEvent = networkFolder:FindFirstChild("AchievementEarned")
    if not earnedEvent then
        earnedEvent = Instance.new("RemoteEvent")
        earnedEvent.Name = "AchievementEarned"
        earnedEvent.Parent = networkFolder
    end

    local getAchievements = networkFolder:FindFirstChild("GetAchievements")
    if not getAchievements then
        getAchievements = Instance.new("RemoteFunction")
        getAchievements.Name = "GetAchievements"
        getAchievements.Parent = networkFolder
    end

    getAchievements.OnServerInvoke = function(player)
        if player.Parent ~= Players then
            return {Ready = false}
        end
        return buildSnapshot(player)
    end

    print("[Lumia - Achievement Service] AchievementService initialized")
end

function AchievementService:Start()
    if started then
        return
    end
    started = true

    Players.PlayerAdded:Connect(function(player)
        task.spawn(function()
            local deadline = os.clock() + 25
            while player.Parent == Players and os.clock() < deadline do
                local profile = PlayerDataService:GetProfile(player)
                if profile then
                    ensureProgression(profile)
                    break
                end
                task.wait(0.25)
            end
        end)
    end)

    for _, player in ipairs(Players:GetPlayers()) do
        task.spawn(function()
            local profile = PlayerDataService:GetProfile(player)
            if profile then
                ensureProgression(profile)
            end
        end)
    end

    print("[Lumia - Achievement Service] AchievementService started")
end

function AchievementService:Award(player, achievementId)
    if typeof(player) ~= "Instance" or not player:IsA("Player") or player.Parent ~= Players then
        return false, "Invalid player"
    end

    local profile = getProfile(player)
    if not profile then
        return false, "Player profile unavailable"
    end

    local definition = AchievementConfig.Get(achievementId)
    if not definition then
        return false, "Unknown achievement"
    end

    local progress = ensureProgression(profile)
    if progress.Achievements[achievementId] then
        if definition.ItemReward then
            rewardItem(player, profile, achievementId, definition.ItemReward)
        end
        return true, "Already unlocked"
    end

    progress.Achievements[achievementId] = {
        UnlockedAt = os.time(),
    }

    if type(definition.TitleReward) == "string" and definition.TitleReward ~= "" then
        progress.CurrentTitle = definition.TitleReward
    end

    if type(definition.ItemReward) == "string" and definition.ItemReward ~= "" then
        rewardItem(player, profile, achievementId, definition.ItemReward)
    end

    if earnedEvent then
        earnedEvent:FireClient(player, {
            Ready = true,
            Id = definition.Id,
            Name = definition.Name,
            Description = definition.Description,
            TitleReward = definition.TitleReward,
            ItemReward = definition.ItemReward,
            ToastIcon = definition.ToastIcon,
        })
    end

    print("[Lumia - Achievement Service] " .. player.Name .. " unlocked achievement " .. definition.Id)
    return true, definition
end

function AchievementService:EvaluateProgress(player)
    local profile = getProfile(player)
    if not profile then
        return
    end

    local character = profile.Character or {}
    local discovered = countKeys(profile.Progression and profile.Progression.DiscoveredZones)
    local completed = completedQuestCount(profile)

    if (character.Level or 0) >= 2 then
        self:Award(player, "Level2")
    end
    if (character.Level or 0) >= 3 then
        self:Award(player, "Level3")
    end
    if (character.Level or 0) >= 5 then
        self:Award(player, "Level5")
    end
    if completed >= 1 then
        self:Award(player, "FirstQuest")
    end
    if discovered >= 3 then
        self:Award(player, "Explorer3")
    end
    if discovered >= 7 then
        self:Award(player, "ExplorerAll")
    end
    if profile.Progression.CompletedQuests.fp12 then
        self:Award(player, "FirstPaths")
    end
    -- Retry a previously earned sigil after bag space becomes available.
    if profile.Progression.Achievements.GuardiansOfLumia then
        self:Award(player, "GuardiansOfLumia")
    end
end

function AchievementService:OnZoneDiscovered(player, zoneId)
    local profile = getProfile(player)
    if not profile then
        return false
    end

    local progress = ensureProgression(profile)
    if type(zoneId) ~= "string" or zoneId == "" then
        return false
    end

    if not progress.DiscoveredZones[zoneId] then
        progress.DiscoveredZones[zoneId] = true
        print("[Lumia - Achievement Service] Zone discovered: " .. player.Name .. " -> " .. zoneId)
    end

    self:EvaluateProgress(player)
    return true
end

function AchievementService:GetCurrentTitle(player)
    local profile = getProfile(player)
    if not profile then
        return ""
    end
    return ensureProgression(profile).CurrentTitle or ""
end

return AchievementService
