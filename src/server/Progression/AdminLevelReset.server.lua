-- REALMS OF LUMIA | Owner-only Level/XP reset v1
-- Dedicated dev action. Server validates identity and updates the live profile.
-- Never clear inventory, class, gold, equipment, or quest progress.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local services = script.Parent.Parent
local PlayerData = require(services:WaitForChild("Players"):WaitForChild("PlayerDataService"))
local Persistence = require(services:WaitForChild("Players"):WaitForChild("PlayerPersistenceService"))
local Progression = require(script.Parent:WaitForChild("ProgressionService"))

local OWNER_ID = 1614020138
local REQUEST_COOLDOWN = 3
local inFlight = {}
local lastRequest = {}

local lumia = ReplicatedStorage:WaitForChild("Lumia")
local network = lumia:WaitForChild("ProgressionNetwork")
local changed = network:WaitForChild("ProgressionChanged")
local getProgression = network:WaitForChild("GetProgression")

local reset = network:FindFirstChild("AdminResetLevel")
if reset and not reset:IsA("RemoteFunction") then
    error("[Lumia Admin] AdminResetLevel exists with wrong type")
end
if not reset then
    reset = Instance.new("RemoteFunction")
    reset.Name = "AdminResetLevel"
    reset.Parent = network
end

local function currentSnapshot(player)
    -- Use the established progression bridge, including admin-modified XP rules.
    local reader = getProgression.OnServerInvoke
    if type(reader) == "function" then
        local success, state = pcall(reader, player)
        if success and type(state) == "table" and state.Ready == true then
            return state
        end
    end
    local profile = PlayerData:GetProfile(player)
    if not profile then return {Ready = false} end
    return {
        Ready = true,
        Level = profile.Character.Level,
        Experience = profile.Character.Experience,
        RequiredXP = Progression:GetRequiredXP(profile.Character.Level),
        MaxLevel = Progression:GetMaxLevel(),
    }
end

reset.OnServerInvoke = function(player, action)
    if player.UserId ~= OWNER_ID or player.Parent ~= Players then
        return {Ok = false, Message = "Not authorized"}
    end
    if action ~= "CONFIRM_RESET_LEVEL_XP" then
        return {Ok = false, Message = "Confirmation required"}
    end
    local userId = player.UserId
    if inFlight[userId] then
        return {Ok = false, Message = "Reset already in progress"}
    end
    if os.clock() - (lastRequest[userId] or -100) < REQUEST_COOLDOWN then
        return {Ok = false, Message = "Wait a few seconds before trying again"}
    end
    local profile = PlayerData:GetProfile(player)
    local character = profile and profile.Character
    if not character then
        return {Ok = false, Message = "Character profile not loaded"}
    end
    inFlight[userId] = true
    lastRequest[userId] = os.clock()
    character.Level = 1
    character.Experience = 0

    -- Persist immediately with the existing session-locked save path.
    local completed, saved, reason = pcall(function()
        return Persistence:Save(userId, false)
    end)
    local state = currentSnapshot(player)
    if state.Ready then changed:FireClient(player, state) end
    inFlight[userId] = nil

    if not completed or not saved then
        warn("[Lumia - Admin Level Reset] Reset changed live profile, but save failed: " .. tostring(reason or saved))
        return {Ok = false, Message = "Reset applied in memory, but saving failed. Check Output."}
    end
    print("[Lumia - Admin Level Reset] Owner reset Level and XP only: " .. player.Name)
    return {Ok = true, Message = "Level and XP reset to 1 / 0"}
end

Players.PlayerRemoving:Connect(function(player)
    inFlight[player.UserId] = nil
    lastRequest[player.UserId] = nil
end)

print("[Lumia - Admin Level Reset] Owner-only XP reset ready")
