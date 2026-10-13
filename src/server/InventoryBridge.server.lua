-- REALMS OF ETERNIA
-- INVENTORY BRIDGE
-- Read-only inventory snapshots and visual item previews.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local services = script.Parent
local InventoryService = require(services:WaitForChild("InventoryService"))
local ItemDefinitions = require(
    ReplicatedStorage:WaitForChild("Eternia")
        :WaitForChild("Shared"):WaitForChild("ItemDefinitions")
)

local eternia = ReplicatedStorage:WaitForChild("Eternia")

local network = eternia:FindFirstChild("InventoryNetwork")
if not network then
    network = Instance.new("Folder")
    network.Name = "InventoryNetwork"
    network.Parent = eternia
end

local request = network:FindFirstChild("GetInventory")
if not request then
    request = Instance.new("RemoteFunction")
    request.Name = "GetInventory"
    request.Parent = network
end

local lastRequest = {}

request.OnServerInvoke = function(player)
    if not player or player.Parent ~= Players then
        return {}
    end

    local now = os.clock()
    if lastRequest[player] and now - lastRequest[player] < 0.15 then
        return nil
    end
    lastRequest[player] = now

    local items = InventoryService:GetItems(player)
    if not items then
        return {}
    end

    local snapshot = {}
    for index, record in ipairs(items) do
        if index > 8 then break end

        local definition = ItemDefinitions.Get(record.ItemId)
        if definition then
            table.insert(snapshot, {
                ItemId = record.ItemId,
                DisplayName = definition.DisplayName,
                Quantity = record.Quantity,
                Rarity = definition.Rarity,
                Type = definition.Type,
                Damage = definition.Damage,
                RequiredLevel = definition.RequiredLevel,
                IconId = definition.IconId,
                ModelId = definition.ModelId,
            })
        end
    end

    return snapshot
end

Players.PlayerRemoving:Connect(function(player)
    lastRequest[player] = nil
end)

print("[Eternia] InventoryBridge ready")
