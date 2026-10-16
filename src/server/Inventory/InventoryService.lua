-- REALMS OF LUMIA - INVENTORY SERVICE / FIVE-BAG FOUNDATION
-- The server owns item records and exact bag coordinates. Equipped items retain
-- their ownership records but have NO bag position. Legacy profiles are migrated
-- in-place on first access, preserving their original visible item order.
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Lumia"):WaitForChild("Shared")
local ItemDefinitions = require(Shared:WaitForChild("Items"):WaitForChild("ItemDefinitions"))
local BagConfig = require(Shared:WaitForChild("Inventory"):WaitForChild("BagConfig"))

local InventoryService = {}
local dataService = nil
local started = false
local MAX_QUANTITY = 999999
local MAX_UNIQUE_PER_CALL = 100
local MAX_EQUIPPED = 8

local function validQuantity(value)
    return type(value) == "number" and value == value and value % 1 == 0
        and value >= 1 and value <= MAX_QUANTITY
end

local function validSlot(value, capacity)
    return type(value) == "number" and value % 1 == 0
        and value >= 1 and value <= capacity
end

-- On first access, legacy inventory entries with no BagId/BagSlot receive
-- open slots in their existing order. No items are deleted or re-created.
local function ensureLayout(inventory)
    if type(inventory.Bags) ~= "table" then
        inventory.Bags = { [1] = BagConfig.StarterBag }
    end
    if inventory.Bags[1] ~= BagConfig.StarterBag then
        -- Starter backpack may never be removed in V1.
        inventory.Bags[1] = BagConfig.StarterBag
    end
    local worn = {}
    for _, instanceId in pairs(inventory.Equipment) do
        if type(instanceId) == "string" then worn[instanceId] = true end
    end
    local taken = {}
    local awaiting = {}
    for _, record in ipairs(inventory.Items) do
        if type(record) == "table" then
            if type(record.InstanceId) == "string" and worn[record.InstanceId] then
                record.BagId = nil
                record.BagSlot = nil
            else
                local bagId, bagSlot = record.BagId, record.BagSlot
                local capacity = BagConfig.GetCapacity(inventory.Bags, bagId)
                if validSlot(bagSlot, capacity) then
                    taken[bagId] = taken[bagId] or {}
                    if not taken[bagId][bagSlot] then
                        taken[bagId][bagSlot] = true
                    else
                        table.insert(awaiting, record)
                    end
                else
                    table.insert(awaiting, record)
                end
            end
        end
    end
    for _, record in ipairs(awaiting) do
        local placed = false
        for bagId = 1, BagConfig.MaxBags do
            local capacity = BagConfig.GetCapacity(inventory.Bags, bagId)
            taken[bagId] = taken[bagId] or {}
            for bagSlot = 1, capacity do
                if not taken[bagId][bagSlot] then
                    record.BagId = bagId
                    record.BagSlot = bagSlot
                    taken[bagId][bagSlot] = true
                    placed = true
                    break
                end
            end
            if placed then break end
        end
        if not placed then
            -- Preserve an oversized legacy record rather than deleting it.
            -- It is not presented until there is enough capacity to place it.
            record.BagId = nil
            record.BagSlot = nil
            warn("[Lumia - Inventory Service] Inventory over capacity: legacy record preserved")
        end
    end
end

local function getInventory(player)
    if not dataService or typeof(player) ~= "Instance" or not player:IsA("Player")
        or player.Parent ~= Players then return nil end
    local profile = dataService:GetProfile(player)
    if not profile or type(profile.Inventory) ~= "table" then return nil end
    local inventory = profile.Inventory
    if type(inventory.Items) ~= "table" or type(inventory.Equipment) ~= "table" then
        return nil
    end
    ensureLayout(inventory)
    return inventory
end

local function getRecordAt(inventory, bagId, bagSlot)
    for _, record in ipairs(inventory.Items) do
        if type(record) == "table" and record.BagId == bagId
            and record.BagSlot == bagSlot then
            return record
        end
    end
    return nil
end

local function firstFree(inventory)
    for bagId = 1, BagConfig.MaxBags do
        local capacity = BagConfig.GetCapacity(inventory.Bags, bagId)
        for bagSlot = 1, capacity do
            if not getRecordAt(inventory, bagId, bagSlot) then
                return bagId, bagSlot
            end
        end
    end
    return nil, nil
end

function InventoryService:Configure(service)
    assert(not started, "Cannot configure after startup")
    assert(type(service) == "table" and type(service.GetProfile) == "function",
        "InventoryService requires PlayerDataService")
    dataService = service
end
function InventoryService:Init()
    assert(dataService, "InventoryService was not configured")
    print("[Lumia - Inventory Service] InventoryService initialized")
end
function InventoryService:Start()
    if started then return end
    started = true
    print("[Lumia - Inventory Service] InventoryService started")
end

function InventoryService:GetBagItems(player)
    local inventory = getInventory(player)
    if not inventory then return nil end
    local result = {}
    for _, record in ipairs(inventory.Items) do
        if type(record) == "table" and record.BagId ~= nil then
            table.insert(result, table.clone(record))
        end
    end
    table.sort(result, function(a, b)
        if a.BagId == b.BagId then return a.BagSlot < b.BagSlot end
        return a.BagId < b.BagId
    end)
    return result
end

function InventoryService:GetBags(player)
    local inventory = getInventory(player)
    return inventory and BagConfig.GetPublicBags(inventory.Bags) or nil
end

function InventoryService:GetBagItemAt(player, bagId, bagSlot)
    local inventory = getInventory(player)
    if not inventory then return nil end
    if not validSlot(bagSlot, BagConfig.GetCapacity(inventory.Bags, bagId)) then
        return nil
    end
    local record = getRecordAt(inventory, bagId, bagSlot)
    return record and table.clone(record) or nil
end

function InventoryService:GetFreeBagSlot(player)
    local inventory = getInventory(player)
    if not inventory then return nil, nil end
    return firstFree(inventory)
end

function InventoryService:GetEquipment(player)
    local inventory = getInventory(player)
    return inventory and table.clone(inventory.Equipment) or nil
end

function InventoryService:GetItems(player)
    local inventory = getInventory(player)
    if not inventory then return nil end
    local result = {}
    for _, record in ipairs(inventory.Items) do
        if type(record) == "table" then table.insert(result, table.clone(record)) end
    end
    return result
end

function InventoryService:GetQuantity(player, itemId)
    local inventory = getInventory(player)
    if not inventory or not ItemDefinitions.Get(itemId) then return 0 end
    local total = 0
    for _, record in ipairs(inventory.Items) do
        if type(record) == "table" and record.ItemId == itemId
            and validQuantity(record.Quantity) then
            total += record.Quantity
        end
    end
    return total
end
-- Only trusted server modules call this. Removes an exact stack amount without yielding.
-- Used for quest turn-ins, consumables and merchant selling.
function InventoryService:RemoveQuantity(player, itemId, quantity)
    if not validQuantity(quantity) or type(itemId)~="string" then
        return false, "Invalid item or quantity"
    end
    local inventory=getInventory(player)
    if not inventory then return false,"Inventory unavailable" end
    local owned=0
    for _, record in ipairs(inventory.Items) do
        if record.ItemId==itemId and record.BagId~=nil and validQuantity(record.Quantity) then
            owned += record.Quantity
        end
    end
    if owned<quantity then return false,"Not enough items" end
    local remaining=quantity
    for index=#inventory.Items,1,-1 do
        local rec=inventory.Items[index]
        if rec.ItemId==itemId and rec.BagId~=nil and remaining>0 then
            local removed=math.min(rec.Quantity,remaining)
            rec.Quantity -= removed
            remaining -= removed
            if rec.Quantity==0 then table.remove(inventory.Items,index) end
        end
    end
    return true,quantity
end

function InventoryService:HasItem(player, itemId)
    return self:GetQuantity(player, itemId) > 0
end

function InventoryService:AddItem(player, itemId, quantity)
    quantity = quantity or 1
    if not validQuantity(quantity) then return nil, "Invalid quantity" end
    local definition = ItemDefinitions.Get(itemId)
    if not definition then return nil, "Unknown item" end
    local inventory = getInventory(player)
    if not inventory then return nil, "Inventory unavailable" end
    local items = inventory.Items
    local individual = definition.Type == "Weapon" or definition.Type == "Armor"
    if not individual then
        for _, record in ipairs(items) do
            if type(record) == "table" and record.ItemId == itemId
                and record.InstanceId == nil then
                if not validQuantity(record.Quantity) then
                    return nil, "Invalid existing stack"
                end
                if record.Quantity + quantity > MAX_QUANTITY then
                    return nil, "Stack limit exceeded"
                end
                record.Quantity += quantity
                return { table.clone(record) }
            end
        end
    end
    local needed = individual and quantity or 1
    if needed > MAX_UNIQUE_PER_CALL then return nil, "Too many unique items" end
    local capacity = BagConfig.TotalCapacity(inventory.Bags)
    local bagCount = #self:GetBagItems(player)
    if bagCount + needed > capacity or #items + needed > capacity + MAX_EQUIPPED then
        return nil, "Inventory full"
    end
    local result = {}
    for _ = 1, needed do
        local bagId, bagSlot = firstFree(inventory)
        if not bagId then return nil, "Bag is full" end
        local record = {
            ItemId = itemId, Quantity = individual and 1 or quantity,
            BagId = bagId, BagSlot = bagSlot,
        }
        if individual then record.InstanceId = HttpService:GenerateGUID(false) end
        table.insert(items, record)
        table.insert(result, table.clone(record))
    end
    return result
end

function InventoryService:GetItemByInstanceId(player, instanceId)
    if type(instanceId) ~= "string" then return nil end
    local inventory = getInventory(player)
    if not inventory then return nil end
    for _, record in ipairs(inventory.Items) do
        if type(record) == "table" and record.InstanceId == instanceId then
            return table.clone(record)
        end
    end
    return nil
end

function InventoryService:MoveBagItem(player, fromBag, fromSlot, toBag, toSlot)
    local inventory = getInventory(player)
    if not inventory then return false, "Inventory unavailable" end
    if not validSlot(fromSlot, BagConfig.GetCapacity(inventory.Bags, fromBag))
        or not validSlot(toSlot, BagConfig.GetCapacity(inventory.Bags, toBag)) then
        return false, "Invalid or unavailable bag slot"
    end
    if fromBag == toBag and fromSlot == toSlot then
        return false, "Item is already in this slot"
    end
    local source = getRecordAt(inventory, fromBag, fromSlot)
    if not source then return false, "Source slot is empty" end
    local destination = getRecordAt(inventory, toBag, toSlot)
    -- No yields / DataStore calls: both records change together on the server.
    source.BagId, source.BagSlot = toBag, toSlot
    if destination then
        destination.BagId, destination.BagSlot = fromBag, fromSlot
    end
    return true, "Moved"
end

function InventoryService:RemoveItem(player, instanceId)
    if type(instanceId) ~= "string" or instanceId == "" then
        return false, "Invalid instance ID"
    end
    local inventory = getInventory(player)
    if not inventory then return false, "Inventory unavailable" end
    for _, equippedId in pairs(inventory.Equipment) do
        if equippedId == instanceId then return false, "Item is equipped" end
    end
    for index, record in ipairs(inventory.Items) do
        if type(record) == "table" and record.InstanceId == instanceId then
            local removed = table.clone(record)
            table.remove(inventory.Items, index)
            return true, removed
        end
    end
    return false, "Item not found"
end

-- Permanent destroy from a bag slot. Does NOT touch equipped items.
-- Expected item identifiers prevent deleting a different item after a drag.
function InventoryService:DiscardBagItem(player, bagId, bagSlot, expectedItemId, expectedInstanceId, confirmWeapon)
    local inventory = getInventory(player)
    if not inventory then return false, "Inventory unavailable" end
    if not validSlot(bagSlot, BagConfig.GetCapacity(inventory.Bags, bagId)) then
        return false, "Invalid bag slot"
    end
    local record = getRecordAt(inventory, bagId, bagSlot)
    if not record or record.ItemId ~= expectedItemId
        or record.InstanceId ~= expectedInstanceId then
        return false, "Item changed; please try again"
    end
    local definition = ItemDefinitions.Get(record.ItemId)
    if not definition then return false, "Item definition missing" end
    if definition.Type=="Quest" or definition.QuestItem then
        return false, "Quest items cannot be discarded"
    end
    if definition.Type == "Weapon" and confirmWeapon ~= true then
        return false, "Weapon destruction requires confirmation"
    end
    for _, instanceId in pairs(inventory.Equipment) do
        if record.InstanceId ~= nil and instanceId == record.InstanceId then
            return false, "Unequip this item first"
        end
    end
    for index, item in ipairs(inventory.Items) do
        if item == record then
            table.remove(inventory.Items, index)
            return true, "Destroyed " .. tostring(definition.DisplayName)
        end
    end
    return false, "Item not found"
end

function InventoryService:PrepareBagLayout(player)
    return getInventory(player) ~= nil
end

-- Remove a specified quantity from exactly one validated bag slot (merchant/crafting use).
-- No yielding or DataStore access; the calling server service owns transaction pricing.
function InventoryService:RemoveBagQuantityAt(player,bagId,bagSlot,expectedItemId,expectedInstanceId,quantity)
    if type(quantity)~="number" or quantity%1~=0 or quantity<1 then
        return false,"Invalid quantity"
    end
    local inventory=getInventory(player)
    if not inventory then return false,"Inventory unavailable" end
    if not validSlot(bagSlot,BagConfig.GetCapacity(inventory.Bags,bagId)) then
        return false,"Invalid bag slot"
    end
    local record=getRecordAt(inventory,bagId,bagSlot)
    if not record or record.ItemId~=expectedItemId or record.InstanceId~=expectedInstanceId then
        return false,"Inventory changed"
    end
    if type(record.Quantity)~="number" or record.Quantity<quantity then
        return false,"Not enough items"
    end
    for _,id in pairs(inventory.Equipment) do
        if record.InstanceId~=nil and id==record.InstanceId then
            return false,"Cannot sell equipped items"
        end
    end
    local removed=table.clone(record)
    removed.Quantity=quantity
    if record.Quantity==quantity then
        for i,entry in ipairs(inventory.Items) do
            if entry==record then table.remove(inventory.Items,i) break end
        end
    else
        record.Quantity-=quantity
    end
    return true,removed
end

return InventoryService