-- REALMS OF ETERNIA
-- INVENTORY SERVICE
-- Server-authoritative inventory records.
-- Physical Tools are handled separately by ItemFactory.
-- Persistence will be handled by PlayerDataService.

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ItemDefinitions = require(
    ReplicatedStorage
        :WaitForChild("Eternia")
        :WaitForChild("Shared")
        :WaitForChild("ItemDefinitions")
)

local InventoryService = {}

local playerDataService = nil
local started = false

local MAX_QUANTITY = 999999
local MAX_RECORDS = 200
local MAX_UNIQUE_PER_CALL = 100

local function validQuantity(value)
    return type(value) == "number"
        and value == value
        and value % 1 == 0
        and value >= 1
        and value <= MAX_QUANTITY
end

local function getInventory(player)
    if not playerDataService then
        return nil
    end

    if typeof(player) ~= "Instance"
        or not player:IsA("Player")
        or player.Parent ~= Players then
        return nil
    end

    local profile = playerDataService:GetProfile(player)

    if not profile or type(profile.Inventory) ~= "table" then
        return nil
    end

    local inventory = profile.Inventory

    if type(inventory.Items) ~= "table"
        or type(inventory.Equipment) ~= "table" then
        return nil
    end

    return inventory
end

local function copyRecord(record)
    return table.clone(record)
end

function InventoryService:Configure(dataService)
    assert(
        type(dataService) == "table"
            and type(dataService.GetProfile) == "function",
        "InventoryService requires PlayerDataService"
    )

    assert(not started, "Cannot configure after startup")

    playerDataService = dataService
end

function InventoryService:Init()
    assert(
        playerDataService,
        "InventoryService was not configured"
    )

    print("[Eternia] InventoryService initialized")
end

function InventoryService:Start()
    if started then
        return
    end

    started = true
    print("[Eternia] InventoryService started")
end

function InventoryService:GetItems(player)
    local inventory = getInventory(player)

    if not inventory then
        return nil
    end

    local result = {}

    for _, record in ipairs(inventory.Items) do
        if type(record) == "table" then
            table.insert(result, copyRecord(record))
        end
    end

    return result
end

function InventoryService:GetQuantity(player, itemId)
    local inventory = getInventory(player)

    if not inventory or not ItemDefinitions.Get(itemId) then
        return 0
    end

    local total = 0

    for _, record in ipairs(inventory.Items) do
        if type(record) == "table"
            and record.ItemId == itemId
            and validQuantity(record.Quantity) then
            total += record.Quantity
        end
    end

    return total
end

function InventoryService:HasItem(player, itemId)
    return self:GetQuantity(player, itemId) > 0
end

function InventoryService:AddItem(player, itemId, quantity)
    quantity = quantity or 1

    if not validQuantity(quantity) then
        return nil, "Invalid quantity"
    end

    local definition = ItemDefinitions.Get(itemId)

    if not definition then
        return nil, "Unknown item"
    end

    local inventory = getInventory(player)

    if not inventory then
        return nil, "Inventory unavailable"
    end

    local items = inventory.Items

    local individual = definition.Type == "Weapon"
        or definition.Type == "Armor"

    if individual then
        if quantity > MAX_UNIQUE_PER_CALL then
            return nil, "Too many unique items"
        end

        if #items + quantity > MAX_RECORDS then
            return nil, "Inventory full"
        end

        local created = {}

        for _ = 1, quantity do
            local record = {
                ItemId = itemId,
                InstanceId = HttpService:GenerateGUID(false),
                Quantity = 1,
            }

            table.insert(items, record)
            table.insert(created, copyRecord(record))
        end

        return created
    end

    -- Stackable items have no unique instance ID.
    for _, record in ipairs(items) do
        if type(record) == "table"
            and record.ItemId == itemId
            and record.InstanceId == nil then

            if not validQuantity(record.Quantity) then
                return nil, "Invalid existing stack"
            end

            if record.Quantity + quantity > MAX_QUANTITY then
                return nil, "Stack limit exceeded"
            end

            record.Quantity += quantity

            return { copyRecord(record) }
        end
    end

    if #items >= MAX_RECORDS then
        return nil, "Inventory full"
    end

    local record = {
        ItemId = itemId,
        Quantity = quantity,
    }

    table.insert(items, record)

    return { copyRecord(record) }
end

function InventoryService:GetItemByInstanceId(player, instanceId)
    if type(instanceId) ~= "string" then
        return nil
    end

    local inventory = getInventory(player)

    if not inventory then
        return nil
    end

    for _, record in ipairs(inventory.Items) do
        if type(record) == "table"
            and record.InstanceId == instanceId then
            return copyRecord(record)
        end
    end

    return nil
end

function InventoryService:RemoveItem(player, instanceId)
    if type(instanceId) ~= "string"
        or instanceId == "" then
        return false, "Invalid instance ID"
    end

    local inventory = getInventory(player)

    if not inventory then
        return false, "Inventory unavailable"
    end

    for _, equippedId in pairs(inventory.Equipment) do
        if equippedId == instanceId then
            return false, "Item is equipped"
        end
    end

    for index, record in ipairs(inventory.Items) do
        if type(record) == "table"
            and record.InstanceId == instanceId then

            local removed = copyRecord(record)
            table.remove(inventory.Items, index)

            return true, removed
        end
    end

    return false, "Item not found"
end

return InventoryService