-- REALMS OF LUMIA - Equipment requests return both authoritative UI views.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local services = script.Parent.Parent
local EquipmentService = require(services:WaitForChild("Equipment"):WaitForChild("EquipmentService"))
local InventoryService = require(services:WaitForChild("Inventory"):WaitForChild("InventoryService"))
local PlayerDataService = require(services:WaitForChild("Players"):WaitForChild("PlayerDataService"))
local BagSnapshot = require(services:WaitForChild("Inventory"):WaitForChild("BagSnapshot"))
local lumia = ReplicatedStorage:WaitForChild("Lumia")
local network = lumia:FindFirstChild("EquipmentNetwork")
if not network then
    network = Instance.new("Folder")
    network.Name = "EquipmentNetwork"
    network.Parent = lumia
end
local function makeRemote(name)
    local remote = network:FindFirstChild(name)
    if not remote then
        remote = Instance.new("RemoteFunction")
        remote.Name = name
        remote.Parent = network
    end
    assert(remote:IsA("RemoteFunction"), "Unexpected EquipmentNetwork." .. name)
    return remote
end
local equipRemote, unequipRemote = makeRemote("Equip"), makeRemote("Unequip")
local lastRequest = {}
local function snapshots(player)
    local profile = PlayerDataService:GetProfile(player)
    local inventory = profile and profile.Inventory
    if not inventory or type(inventory.Equipment) ~= "table"
        or type(inventory.Items) ~= "table" then return nil, nil end
    local bag = BagSnapshot.Build(player)
    if not bag then return nil, nil end
    local equipment = {}
    local allItems = InventoryService:GetItems(player)
    if not allItems then return nil, nil end
    for slotKey, instanceId in pairs(inventory.Equipment) do
        if type(slotKey) == "string" and type(instanceId) == "string" then
            for _, record in ipairs(allItems) do
                if record.InstanceId == instanceId then
                    local item = BagSnapshot.PublicItem(record)
                    if item then
                        item.InstanceId = nil
                        equipment[slotKey] = item
                    end
                    break
                end
            end
        end
    end
    return bag, equipment
end
local function invoke(player, action, ...)
    if typeof(player) ~= "Instance" or not player:IsA("Player")
        or player.Parent ~= Players then
        return { Ok = false, Error = "Invalid player" }
    end
    local now = os.clock()
    if lastRequest[player] and now - lastRequest[player] < 0.1 then
        return { Ok = false, Error = "Please wait a moment" }
    end
    lastRequest[player] = now
    local arguments = { ... }
    local success, ok, info = pcall(function()
        if action == "Equip" then
            return EquipmentService:Equip(player, arguments[1])
        end
        return EquipmentService:Unequip(player, arguments[1], arguments[2], arguments[3])
    end)
    if not success then
        warn("[Lumia] Equipment request failed: " .. tostring(ok))
        return { Ok = false, Error = "Equipment unavailable" }
    end
    if not ok then return { Ok = false, Error = tostring(info) } end
    local bag, equipment = snapshots(player)
    if bag and equipment then
        return { Ok = true, Slot = info, Bag = bag, Equipment = equipment }
    end
    return { Ok = true, Slot = info }
end

equipRemote.OnServerInvoke = function(player, instanceId)
    return invoke(player, "Equip", instanceId)
end
unequipRemote.OnServerInvoke = function(player, slot, bagId, bagSlot)
    return invoke(player, "Unequip", slot, bagId, bagSlot)
end
Players.PlayerRemoving:Connect(function(player)
    lastRequest[player] = nil
end)
print("[Lumia] EquipmentBridge ready")
