local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerDataService = require(
    script.Parent.Parent:WaitForChild("Players"):WaitForChild("PlayerDataService")
)

local ProgressionConfig = require(
    ReplicatedStorage
        :WaitForChild("Lumia")
        :WaitForChild("Shared")
        :WaitForChild("Progression"):WaitForChild("ProgressionConfig")
)

local BalanceService = require(script.Parent.Parent:WaitForChild("Admin"):WaitForChild("BalanceService"))
local AchievementService = require(script.Parent:WaitForChild("AchievementService"))
local ProgressionService = {}

local MAX_REWARD = 1000000
local MAX_GOLD = 2000000000

local function validAmount(amount)
    return type(amount) == "number"
        and amount == amount
        and amount > 0
        and amount <= MAX_REWARD
        and amount % 1 == 0
end

local function getCharacter(player)
    if typeof(player) ~= "Instance"
        or not player:IsA("Player")
        or player.Parent ~= Players then
        return nil
    end

    local profile = PlayerDataService:GetProfile(player)
    if not profile then
        return nil
    end

    return profile.Character
end

function ProgressionService:Init()
    print("[Lumia - Progression Service] ProgressionService initialized")
end

function ProgressionService:Start()
    print("[Lumia - Progression Service] ProgressionService started")
end

function ProgressionService:GetRequiredXP(level)
    return BalanceService:GetRequiredXP(level)
end

function ProgressionService:GetMaxLevel()
    return ProgressionConfig.MAX_LEVEL
end

function ProgressionService:AddXP(player, amount)
    if not validAmount(amount) then
        return false, "Invalid XP amount"
    end

    local character = getCharacter(player)
    if not character then
        return false, "Player profile unavailable"
    end

    local maxLevel = self:GetMaxLevel()

    if character.Level >= maxLevel then
        return false, "Maximum level reached"
    end

    local previousLevel = character.Level
    local experience = character.Experience + amount
    local level = previousLevel

    while level < maxLevel do
        local required = self:GetRequiredXP(level)

        if not required or experience < required then
            break
        end

        experience -= required
        level += 1
    end

    if level >= maxLevel then
        experience = 0
    end

    character.Level = level
    character.Experience = experience

    print(
        "[Lumia - Progression Service] XP awarded: "
        .. player.Name
        .. " +" .. amount
        .. " | Level " .. level
        .. " | XP " .. experience
    )

    if level > previousLevel then
        print(
            "[Lumia - Progression Service] LEVEL UP: "
            .. player.Name
            .. " | " .. previousLevel
            .. " -> " .. level
        )
    end

    AchievementService:EvaluateProgress(player)

    return true, {
        PreviousLevel = previousLevel,
        Level = level,
        Experience = experience,
        LevelsGained = level - previousLevel
    }
end

function ProgressionService:AddGold(player, amount)
    if not validAmount(amount) then
        return false, "Invalid gold amount"
    end

    local character = getCharacter(player)
    if not character then
        return false, "Player profile unavailable"
    end

    if character.Gold > MAX_GOLD - amount then
        return false, "Gold limit exceeded"
    end

    character.Gold += amount

    print(
        "[Lumia - Progression Service] Gold awarded: "
        .. player.Name
        .. " +" .. amount
        .. " | Total " .. character.Gold
    )

    return true, character.Gold
end

return ProgressionService
