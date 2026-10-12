local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local shared = ReplicatedStorage:WaitForChild("Eternia"):WaitForChild("Shared")
local PlayerProfileValidator = require(shared:WaitForChild("PlayerProfileValidator"))

local PlayerDataService = {}

local profiles = {}
local started = false

function PlayerDataService:Init()
    print("[Eternia] PlayerDataService initialized")
end

function PlayerDataService:Start()
    if started then
        return
    end

    started = true

    Players.PlayerAdded:Connect(function(player)
        self:OnPlayerJoined(player)
    end)

    Players.PlayerRemoving:Connect(function(player)
        self:OnPlayerLeaving(player)
    end)

    for _, player in ipairs(Players:GetPlayers()) do
        self:OnPlayerJoined(player)
    end

    print("[Eternia] PlayerDataService listening for players")
end

function PlayerDataService:OnPlayerJoined(player)
    local userId = player.UserId

    if profiles[userId] then
        return
    end

    local profile = PlayerProfileValidator.CreateDefault()

    local valid = PlayerProfileValidator.Validate(profile)
    if not valid then
        warn("[Eternia] Failed to create valid profile: " .. player.Name)
        return
    end

    profile.Character.Name = player.Name
    profiles[userId] = profile

    print(
        "[Eternia] Profile created: "
        .. player.Name
        .. " | Level "
        .. profile.Character.Level
        .. " | Gold "
        .. profile.Character.Gold
    )
end

function PlayerDataService:OnPlayerLeaving(player)
    local userId = player.UserId

    if profiles[userId] then
        profiles[userId] = nil
        print("[Eternia] Profile removed from memory: " .. player.Name)
    end
end

function PlayerDataService:GetProfile(player)
    if not player then
        return nil
    end

    return profiles[player.UserId]
end

function PlayerDataService:GetProfileByUserId(userId)
    return profiles[userId]
end

function PlayerDataService:GetActiveCount()
    local count = 0

    for _ in pairs(profiles) do
        count += 1
    end

    return count
end

return PlayerDataService