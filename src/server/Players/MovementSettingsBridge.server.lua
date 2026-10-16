-- REALMS OF LUMIA - SERVER-VALIDATED MOVEMENT KEYBIND SETTINGS
-- Saved in the existing player profile; no additional DataStore is created.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local shared = ReplicatedStorage:WaitForChild("Lumia"):WaitForChild("Shared")
local Config = require(shared:WaitForChild("Players"):WaitForChild("MovementKeybindConfig"))
local PlayerDataService = require(script.Parent:WaitForChild("PlayerDataService"))

local lumia = ReplicatedStorage:WaitForChild("Lumia")
local network = lumia:FindFirstChild("MovementNetwork")
if not network then
    network = Instance.new("Folder")
    network.Name = "MovementNetwork"
    network.Parent = lumia
end

local remote = network:FindFirstChild("KeybindSettings")
if not remote then
    remote = Instance.new("RemoteFunction")
    remote.Name = "KeybindSettings"
    remote.Parent = network
end
assert(remote:IsA("RemoteFunction"), "MovementNetwork.KeybindSettings must be RemoteFunction")

local lastWrite = {}

remote.OnServerInvoke = function(player, operation, action, keyName)
    if player.Parent ~= Players then
        return {Ok = false, Error = "Invalid player"}
    end
    local profile = PlayerDataService:GetProfile(player)
    if not profile or type(profile.Settings) ~= "table" then
        return {Ok = false, Error = "Character profile is still loading"}
    end

    local settings = profile.Settings
    local current = Config.CopyOrDefault(settings.Keybinds)

    if operation == "Get" then
        return {Ok = true, Bindings = current}
    end
    if operation ~= "Set" and operation ~= "Reset" then
        return {Ok = false, Error = "Unknown settings operation"}
    end

    local now = os.clock()
    if lastWrite[player] and now - lastWrite[player] < 0.2 then
        return {Ok = false, Error = "Please wait a moment"}
    end
    lastWrite[player] = now

    if operation == "Reset" then
        current = Config.CopyDefault()
    else
        if type(action) ~= "string" or Config.Defaults[action] == nil then
            return {Ok = false, Error = "Unknown movement action"}
        end
        if not Config.IsAllowed(keyName) then
            return {Ok = false, Error = "That key is reserved or unsupported"}
        end
        current[action] = keyName
        local valid, reason = Config.Validate(current)
        if not valid then
            return {Ok = false, Error = reason}
        end
    end

    settings.Keybinds = current
    print("[Lumia - Movement Settings Bridge] Saved movement keybind preferences in profile: " .. player.Name)
    return {Ok = true, Bindings = Config.CopyOrDefault(settings.Keybinds)}
end

Players.PlayerRemoving:Connect(function(player)
    lastWrite[player] = nil
end)

print("[Lumia - Movement Settings Bridge] Movement settings bridge ready")
