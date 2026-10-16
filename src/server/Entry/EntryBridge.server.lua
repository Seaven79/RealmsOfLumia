-- REALMS OF LUMIA - ENTRY BRIDGE v1
-- Independent server Script, loaded by Roblox with other .server.lua files.
-- No existing bootstrap/service requires changing. Never accepts XP, gold or
-- character identity from the client. Authentication is provided by Roblox.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local lumia = ReplicatedStorage:WaitForChild("Lumia")
local shared = lumia:WaitForChild("Shared")
local config = require(shared:WaitForChild("Entry"):WaitForChild("EntryConfig"))
local playerData = require(script.Parent.Parent:WaitForChild("Players"):WaitForChild("PlayerDataService"))

local network = lumia:FindFirstChild("EntryNetwork")
if not network then
    network = Instance.new("Folder")
    network.Name = "EntryNetwork"
    network.Parent = lumia
end

local function remoteFunction(name)
    local existing = network:FindFirstChild(name)
    if existing then
        assert(existing:IsA("RemoteFunction"), "Entry network type mismatch: " .. name)
        return existing
    end
    local remote = Instance.new("RemoteFunction")
    remote.Name = name
    remote.Parent = network
    return remote
end

local queryStatus = remoteFunction("GetEntryStatus")
local enterWorld = remoteFunction("EnterWorld")
local PROTECTION_NAME = "LumiaEntryProtection"

local function protectCharacter(player, character)
    if not config.ProtectCharacterUntilEntry then return end
    if player:GetAttribute("LumiaEnteredWorld") == true then return end
    if character:FindFirstChild(PROTECTION_NAME) then return end
    local field = Instance.new("ForceField")
    field.Name = PROTECTION_NAME
    field.Visible = false
    field.Parent = character
end

local function preparePlayer(player)
    player:SetAttribute("LumiaEnteredWorld", false)
    player.CharacterAdded:Connect(function(character)
        protectCharacter(player, character)
    end)
    if player.Character then
        protectCharacter(player, player.Character)
    end
end

Players.PlayerAdded:Connect(preparePlayer)
for _, player in ipairs(Players:GetPlayers()) do
    preparePlayer(player)
end

local function status(player)
    if typeof(player) ~= "Instance" or not player:IsA("Player")
        or player.Parent ~= Players then
        return { Ready = false, Message = "Player session unavailable" }
    end

    -- GetProfile returns nil until DataStore load and validation succeed.
    -- This avoids showing a fake 'loaded' status or exposing unsaved defaults.
    local profile = playerData:GetProfile(player)
    if not profile then
        return { Ready = false, Message = "Loading your saved character..." }
    end

    local character = player.Character
    if not character then
        return { Ready = false, Message = "Spawning your character..." }
    end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    local root = character:FindFirstChild("HumanoidRootPart")
    if not humanoid or not root or humanoid.Health <= 0 then
        return { Ready = false, Message = "Preparing your character..." }
    end

    local settings = profile.Settings
    return {
        Ready = true,
        Message = "Your adventure is ready.",
        Name = player.DisplayName,
        Level = profile.Character.Level,
        Class = profile.Character.Class or "Adventurer",
        HasSeenIntro = settings and settings.LumiaEntryIntroSeen == true or false,
        EnteredWorld = player:GetAttribute("LumiaEnteredWorld") == true,
    }
end

queryStatus.OnServerInvoke = function(player)
    return status(player)
end

enterWorld.OnServerInvoke = function(player)
    local result = status(player)
    if not result.Ready then
        return false, result.Message
    end

    -- This is a persisted presentation preference, not a replacement for
    -- account login, session locking, progression or any existing services.
    local profile = playerData:GetProfile(player)
    if not profile then
        return false, "Character profile no longer available"
    end
    profile.Settings.LumiaEntryIntroSeen = true
    player:SetAttribute("LumiaEnteredWorld", true)
    if player.Character then
        local field = player.Character:FindFirstChild(PROTECTION_NAME)
        if field then field:Destroy() end
    end
    print("[Lumia - Entry Bridge] Enter World confirmed: " .. player.Name)
    return true, "Welcome to Lumia"
end

print("[Lumia - Entry Bridge] Entry network ready; waiting for real player profiles")
