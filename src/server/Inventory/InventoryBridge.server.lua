-- REALMS OF LUMIA - BAG NETWORK
-- Read snapshots; move or swap saved positions; remember viewing preferences.
-- All slot changes are checked by InventoryService on the server.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local services = script.Parent.Parent
local InventoryService = require(services:WaitForChild("Inventory"):WaitForChild("InventoryService"))
local PlayerDataService = require(services:WaitForChild("Players"):WaitForChild("PlayerDataService"))
local BagSnapshot = require(services:WaitForChild("Inventory"):WaitForChild("BagSnapshot"))
local network = ReplicatedStorage:WaitForChild("Lumia"):FindFirstChild("InventoryNetwork")
if not network then
    network = Instance.new("Folder")
    network.Name = "InventoryNetwork"
    network.Parent = ReplicatedStorage.Lumia
end
local function remote(name)
    local existing = network:FindFirstChild(name)
    if not existing then
        existing = Instance.new("RemoteFunction")
        existing.Name = name
        existing.Parent = network
    end
    assert(existing:IsA("RemoteFunction"), "Bad InventoryNetwork remote: " .. name)
    return existing
end
local request = remote("GetInventory")
local moveRequest = remote("MoveBagItem")
local discardRequest = remote("DiscardBagItem")
local preferenceRequest = remote("SetBagView")
local lastRead, lastMove, lastPreference, lastDiscard = {}, {}, {}, {}
local function validPlayer(player)
    return player and player:IsA("Player") and player.Parent == Players
end
local function throttle(last, player, interval)
    local now = os.clock()
    if last[player] and now - last[player] < interval then return false end
    last[player] = now
    return true
end

request.OnServerInvoke = function(player)
    if not validPlayer(player) then return { Items = {}, Bags = {} } end
    if not throttle(lastRead, player, 0.15) then return nil end
    return BagSnapshot.Build(player) or { Items = {}, Bags = {} }
end

moveRequest.OnServerInvoke = function(player, args)
    if not validPlayer(player) then return { Ok = false, Error = "Invalid player" } end
    if not throttle(lastMove, player, 0.08) then
        return { Ok = false, Error = "Please wait a moment" }
    end
    if type(args) ~= "table" then return { Ok = false, Error = "Invalid bag move" } end
    local ok, allowed, info = pcall(function()
        return InventoryService:MoveBagItem(player,
            args.FromBag, args.FromSlot, args.ToBag, args.ToSlot)
    end)
    if not ok then
        warn("[Lumia - Inventory Bridge] Bag move error: " .. tostring(allowed))
        return { Ok = false, Error = "Inventory unavailable" }
    end
    if not allowed then return { Ok = false, Error = tostring(info) } end
    return { Ok = true, Bag = BagSnapshot.Build(player) }
end

discardRequest.OnServerInvoke = function(player, args)
    if not validPlayer(player) or type(args) ~= "table" then
        return { Ok = false, Error = "Invalid request" }
    end
    if not throttle(lastDiscard, player, 0.25) then
        return { Ok = false, Error = "Please wait" }
    end
    if type(args.ItemId) ~= "string" or #args.ItemId > 80
        or (args.InstanceId ~= nil and (type(args.InstanceId) ~= "string"
        or #args.InstanceId > 80)) then
        return { Ok = false, Error = "Invalid item" }
    end
    local ok, allowed, info = pcall(function()
        return InventoryService:DiscardBagItem(player, args.BagId, args.Slot,
            args.ItemId, args.InstanceId, args.ConfirmWeapon)
    end)
    if not ok then return { Ok = false, Error = "Unable to destroy item" } end
    if not allowed then return { Ok = false, Error = tostring(info) } end
    return { Ok = true, Message = tostring(info), Bag = BagSnapshot.Build(player) }
end

preferenceRequest.OnServerInvoke = function(player, mode, bagId)
    if not validPlayer(player) then return false end
    if not throttle(lastPreference, player, 0.08) then return false end
    if mode ~= "selected" and mode ~= "all" then return false end
    if type(bagId) ~= "number" or bagId % 1 ~= 0
        or bagId < 1 or bagId > 5 then return false end
    local profile = PlayerDataService:GetProfile(player)
    if not profile or type(profile.Settings) ~= "table" then return false end
    profile.Settings.BagViewMode = mode
    profile.Settings.SelectedBagId = bagId
    return true
end

Players.PlayerRemoving:Connect(function(player)
    lastRead[player], lastMove[player], lastPreference[player], lastDiscard[player] = nil, nil, nil, nil
end)
print("[Lumia - Inventory Bridge] Bag network ready - five bag positions, starter capacity eight")