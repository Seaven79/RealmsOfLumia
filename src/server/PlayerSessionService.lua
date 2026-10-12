local Players = game:GetService("Players")

local PlayerSessionService = {}

local sessions = {}

function PlayerSessionService:Init()
    print("[Eternia] PlayerSessionService initialized")
end

function PlayerSessionService:Start()
    Players.PlayerAdded:Connect(function(player)
        self:OnPlayerJoined(player)
    end)

    Players.PlayerRemoving:Connect(function(player)
        self:OnPlayerLeaving(player)
    end)

    for _, player in ipairs(Players:GetPlayers()) do
        self:OnPlayerJoined(player)
    end

    print("[Eternia] PlayerSessionService listening for players")
end

function PlayerSessionService:OnPlayerJoined(player)
    if sessions[player.UserId] then
        return
    end

    sessions[player.UserId] = {
        UserId = player.UserId,
        JoinedAt = os.time(),
        State = "Active"
    }

    print("[Eternia] Player joined: " .. player.Name)
end

function PlayerSessionService:OnPlayerLeaving(player)
    local session = sessions[player.UserId]

    if not session then
        return
    end

    session.State = "Leaving"

    print("[Eternia] Player leaving: " .. player.Name)

    sessions[player.UserId] = nil
end

function PlayerSessionService:GetSession(userId)
    return sessions[userId]
end

function PlayerSessionService:GetActiveCount()
    local count = 0

    for _ in pairs(sessions) do
        count += 1
    end

    return count
end

return PlayerSessionService