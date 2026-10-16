-- REALMS OF LUMIA V16 | XP BAR POSITION SAVE
-- Isolated HUD bridge: does not modify V14 action bar or its inventory behavior.
-- Reuses the existing profile.Settings.HudPositions.XPBar to avoid a schema bump.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Data = require(script.Parent.Parent:WaitForChild("Players"):WaitForChild("PlayerDataService"))

local lumia = ReplicatedStorage:WaitForChild("Lumia")
local network = lumia:FindFirstChild("XPBarLayoutNetwork") or Instance.new("Folder")
network.Name = "XPBarLayoutNetwork"
network.Parent = lumia
local function getRemote(name)
    local remote = network:FindFirstChild(name)
    if remote then
        assert(remote:IsA("RemoteFunction"), "Invalid XP bar layout remote " .. name)
        return remote
    end
    remote = Instance.new("RemoteFunction")
    remote.Name = name
    remote.Parent = network
    return remote
end
local getPosition = getRemote("GetPosition")
local setPosition = getRemote("SetPosition")
local lastSave = setmetatable({}, {__mode = "k"})

local function validNumber(value)
    return type(value) == "number" and value == value
        and value >= 0 and value <= 1
end
local function positionsFor(player)
    if player.Parent ~= Players then return nil end
    local profile = Data:GetProfile(player)
    if not profile or type(profile.Settings) ~= "table" then return nil end
    if type(profile.Settings.HudPositions) ~= "table" then
        profile.Settings.HudPositions = {}
    end
    return profile.Settings.HudPositions
end

getPosition.OnServerInvoke = function(player)
    local saved = positionsFor(player)
    if not saved then return {Ok = false, Message = "Profile loading"} end
    local pos = saved.XPBar
    if type(pos) ~= "table" or not validNumber(pos.X) or not validNumber(pos.Y) then
        return {Ok = true, Position = nil}
    end
    return {Ok = true, Position = {X = pos.X, Y = pos.Y}}
end

setPosition.OnServerInvoke = function(player, x, y)
    if not validNumber(x) or not validNumber(y) then
        return {Ok = false, Message = "Invalid position"}
    end
    local positions = positionsFor(player)
    if not positions then return {Ok = false, Message = "Profile loading"} end
    local now = os.clock()
    if now - (lastSave[player] or -100) < 0.15 then
        return {Ok = false, Message = "Saving too quickly"}
    end
    lastSave[player] = now
    positions.XPBar = {X = x, Y = y}
    -- Position is saved with the regular session autosave and safe exit.
    return {Ok = true, Position = {X = x, Y = y}}
end
Players.PlayerRemoving:Connect(function(player) lastSave[player] = nil end)
print("[Lumia V16] XP bar position save bridge ready")
