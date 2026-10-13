-- REALMS OF ETERNIA
-- PLAYER DATA SERVICE
-- Profiles are published only after persistent loading succeeds.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local shared = ReplicatedStorage:WaitForChild("Eternia"):WaitForChild("Shared")
local Validator = require(shared:WaitForChild("PlayerProfileValidator"))
local Persistence = require(script.Parent:WaitForChild("PlayerPersistenceService"))

local PlayerDataService = {}

local profiles = {}
local loading = {}
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
        task.spawn(function()
            self:OnPlayerJoined(player)
        end)
    end)

    Players.PlayerRemoving:Connect(function(player)
        self:OnPlayerLeaving(player)
    end)

    for _, player in ipairs(Players:GetPlayers()) do
        task.spawn(function()
            self:OnPlayerJoined(player)
        end)
    end

    game:BindToClose(function()
        Persistence:Shutdown()
    end)

    print("[Eternia] PlayerDataService listening for players")
end

function PlayerDataService:OnPlayerJoined(player)
    local userId = player.UserId

    if profiles[userId] or loading[userId] then
        return
    end

    loading[userId] = true

    local profile, reason = Persistence:Load(userId)

    loading[userId] = nil

    if not profile then
        warn(
            "[Eternia] Profile loading denied for "
            .. player.Name
            .. ": "
            .. tostring(reason)
        )

        if player.Parent == Players then
            player:Kick(
                "Your character data could not be loaded safely. "
                .. "Please try joining again shortly."
            )
        end

        return
    end

    if player.Parent ~= Players then
        local saved, saveReason = Persistence:Release(userId)

        if not saved then
            warn(
                "[Eternia] Could not release disconnected player "
                .. userId
                .. ": "
                .. tostring(saveReason)
            )
        end

        return
    end

    profile.Character.Name = player.Name

    local valid, validationReason = Validator.Validate(profile)

    if not valid then
        warn(
            "[Eternia] Loaded profile invalid: "
            .. tostring(validationReason)
        )

        player:Kick("Your character data failed validation.")
        Persistence:Release(userId)
        return
    end

    profiles[userId] = profile

    print(
        "[Eternia] Persistent profile ready: "
        .. player.Name
        .. " | Level "
        .. profile.Character.Level
        .. " | Gold "
        .. profile.Character.Gold
    )
end

function PlayerDataService:OnPlayerLeaving(player)
    local userId = player.UserId

    if not profiles[userId] then
        return
    end

    local saved = false
    local reason = nil

    for attempt = 1, 3 do
        saved, reason = Persistence:Release(userId)

        if saved then
            break
        end

        warn(
            "[Eternia] Player exit save attempt "
            .. attempt
            .. " failed for "
            .. player.Name
            .. ": "
            .. tostring(reason)
        )

        if reason == "Session ownership lost" then
            break
        end

        if attempt < 3 then
            task.wait(2 * attempt)
        end
    end

    if saved then
        print(
            "[Eternia] Player exit persistence confirmed: "
            .. player.Name
        )
    else
        warn(
            "[Eternia] CRITICAL: Player exit save failed for "
            .. player.Name
            .. ". Shutdown recovery may still be required. "
            .. tostring(reason)
        )
    end

    profiles[userId] = nil
end

function PlayerDataService:GetProfile(player)
    if not player then
        return nil
    end

    if not Persistence:IsUsable(player.UserId) then
        return nil
    end

    return profiles[player.UserId]
end

function PlayerDataService:GetProfileByUserId(userId)
    if not Persistence:IsUsable(userId) then
        return nil
    end

    return profiles[userId]
end

function PlayerDataService:GetActiveCount()
    local count = 0

    for userId in pairs(profiles) do
        if Persistence:IsUsable(userId) then
            count += 1
        end
    end

    return count
end

return PlayerDataService