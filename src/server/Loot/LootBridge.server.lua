-- REALMS OF LUMIA - LOOT NETWORK BRIDGE v1
-- Networking only: never rolls loot or changes inventory directly.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LootService = require(script.Parent:WaitForChild("LootService"))
local lumia = ReplicatedStorage:WaitForChild("Lumia")
local network = lumia:FindFirstChild("LootNetwork")
if not network then
    network = Instance.new("Folder")
    network.Name = "LootNetwork"
    network.Parent = lumia
end
local function remote(name, className)
    local result = network:FindFirstChild(name)
    if not result then
        result = Instance.new(className)
        result.Name = name
        result.Parent = network
    end
    assert(result:IsA(className), "Bad LootNetwork." .. name)
    return result
end
local openRemote = remote("OpenLoot", "RemoteEvent")
local clickRemote = remote("RequestOpenLoot", "RemoteEvent")
local actionRemote = remote("LootAction", "RemoteFunction")
local lastRequest = {}
local lastClick = {}
LootService.OpenRequested:Connect(function(player, token)
    if player.Parent == Players then openRemote:FireClient(player, token) end
end)
clickRemote.OnServerEvent:Connect(function(player, model)
    if player.Parent ~= Players then return end
    local now = os.clock()
    if lastClick[player] and now - lastClick[player] < 0.22 then return end
    lastClick[player] = now
    local token = LootService:GetTokenForModel(player, model)
    if token then openRemote:FireClient(player, token) end
end)

actionRemote.OnServerInvoke = function(player, action, token, slot)
    if action ~= "Inspect" and action ~= "Take" then
        return {Ok = false, Error = "Unknown loot action"}
    end
    local now = os.clock()
    if lastRequest[player] and now - lastRequest[player] < 0.12 then
        return {Ok = false, Error = "Please wait"}
    end
    lastRequest[player] = now
    if action == "Inspect" then return LootService:Inspect(player, token) end
    return LootService:Take(player, token, slot)
end
Players.PlayerRemoving:Connect(function(player)
    lastRequest[player] = nil
    lastClick[player] = nil
end)
LootService:Start()
print("[Lumia - Loot Bridge] Loot window network ready")
