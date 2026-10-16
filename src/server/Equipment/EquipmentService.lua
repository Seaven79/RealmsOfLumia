-- REALMS OF LUMIA - EQUIPMENT SERVICE WITH SAVED BAG POSITIONS
-- Only server-verified owned unique items can be equipped.
-- Equipped items hold no BagId/BagSlot, freeing a visible bag position.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Lumia"):WaitForChild("Shared")
local ItemDefinitions = require(Shared:WaitForChild("Items"):WaitForChild("ItemDefinitions"))
local EquipmentRules = require(Shared:WaitForChild("Equipment"):WaitForChild("EquipmentRules"))
local BagConfig = require(Shared:WaitForChild("Inventory"):WaitForChild("BagConfig"))

local EquipmentService = {}
local dataService, inventoryService = nil, nil
local started = false
local function getInventory(player)
    if not started or not dataService or typeof(player) ~= "Instance"
        or not player:IsA("Player") or player.Parent ~= Players then
        return nil, nil
    end
    local profile = dataService:GetProfile(player)
    if not profile or type(profile.Character) ~= "table"
        or type(profile.Inventory) ~= "table" then return nil, nil end
    local inventory = profile.Inventory
    if type(inventory.Items) ~= "table" or type(inventory.Equipment) ~= "table" then
        return nil, nil
    end
    if not inventoryService:PrepareBagLayout(player) then return nil, nil end
    return profile, inventory
end

local function rawById(items, instanceId)
    for _, record in ipairs(items) do
        if type(record) == "table" and record.InstanceId == instanceId then
            return record
        end
    end
    return nil
end

function EquipmentService:Configure(playerDataService, invService)
    assert(not started, "EquipmentService already started")
    assert(type(playerDataService) == "table"
        and type(playerDataService.GetProfile) == "function", "Need PlayerDataService")
    assert(type(invService) == "table"
        and type(invService.GetItemByInstanceId) == "function", "Need InventoryService")
    dataService = playerDataService
    inventoryService = invService
end
function EquipmentService:Init()
    assert(dataService and inventoryService, "EquipmentService not configured")
    print("[Lumia - Equipment Service] EquipmentService initialized")
end
function EquipmentService:Start()
    started = true
    print("[Lumia - Equipment Service] EquipmentService started")
end

function EquipmentService:Equip(player, instanceId)
    if type(instanceId) ~= "string" or #instanceId < 1
        or #instanceId > 128 then return false, "Invalid item ID" end
    local profile, inventory = getInventory(player)
    if not inventory then return false, "Character data not ready" end
    local record = rawById(inventory.Items, instanceId)
    if not record or record.Quantity ~= 1 then
        return false, "Item is not owned or cannot be equipped"
    end
    local definition = ItemDefinitions.Get(record.ItemId)
    local slot = EquipmentRules.GetSlot(definition)
    if not slot then return false, "This item cannot be equipped yet" end
    local required = definition.RequiredLevel or 1
    if type(required) ~= "number" or required % 1 ~= 0 or required < 1
        or type(profile.Character.Level) ~= "number"
        or profile.Character.Level < required then
        return false, "Character level is too low"
    end
    if not record.BagId or not record.BagSlot then
        return false, "Item is not in an available bag"
    end
    for _, wornId in pairs(inventory.Equipment) do
        if wornId == instanceId then return false, "Item already equipped" end
    end
    local oldId = inventory.Equipment[slot]
    local oldRecord = oldId and rawById(inventory.Items, oldId) or nil
    if oldId and not oldRecord then return false, "Previous equipment is missing" end
    -- An equipped replacement returns directly to the exact bag space that
    -- the newly equipped item is vacating. All changes happen without yielding.
    local fromBag, fromSlot = record.BagId, record.BagSlot
    record.BagId, record.BagSlot = nil, nil
    if oldRecord then
        oldRecord.BagId, oldRecord.BagSlot = fromBag, fromSlot
    end
    inventory.Equipment[slot] = instanceId
    return true, slot
end

function EquipmentService:Unequip(player, slot, bagId, bagSlot)
    if not EquipmentRules.IsValidSlot(slot) then
        return false, "Invalid equipment slot"
    end
    local _, inventory = getInventory(player)
    if not inventory then return false, "Character data not ready" end
    local instanceId = inventory.Equipment[slot]
    if type(instanceId) ~= "string" then return false, "Slot is already empty" end
    local record = rawById(inventory.Items, instanceId)
    if not record then return false, "Equipped item record is missing" end
    if bagId == nil and bagSlot == nil then
        -- Compatibility with older callers that only supplied equipment slot.
        bagId, bagSlot = inventoryService:GetFreeBagSlot(player)
    end
    if not bagId or not bagSlot or not BagConfig.IsBagPosition(bagId)
        or type(bagSlot) ~= "number" or bagSlot % 1 ~= 0
        or bagSlot < 1 or bagSlot > BagConfig.GetCapacity(inventory.Bags, bagId) then
        return false, "No valid empty bag slot"
    end
    if inventoryService:GetBagItemAt(player, bagId, bagSlot) then
        return false, "Bag slot is occupied"
    end
    record.BagId, record.BagSlot = bagId, bagSlot
    inventory.Equipment[slot] = nil
    return true, slot
end
return EquipmentService
