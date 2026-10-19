local PlayerProfileTemplate = require(script.Parent.PlayerProfileTemplate)

local PlayerProfileValidator = {}

local function deepCopy(value)
    if type(value) ~= "table" then return value end
    local copy = {}
    for key, item in pairs(value) do copy[deepCopy(key)] = deepCopy(item) end
    return copy
end

local function isNonNegativeInteger(value)
    return type(value) == "number" and value == value
        and value >= 0 and value < math.huge and value % 1 == 0
end

function PlayerProfileValidator.CreateDefault()
    return deepCopy(PlayerProfileTemplate.Default)
end

local MAX_ITEM_QUANTITY = 999999
local MAX_ITEM_ID_LEN   = 128
local MAX_INSTANCE_LEN  = 128
local MAX_ITEMS         = 2000

local function isValidItemRecord(record)
    if type(record) ~= "table" then return false, "record not a table" end
    if type(record.ItemId) ~= "string" then return false, "ItemId missing" end
    if #record.ItemId < 1 or #record.ItemId > MAX_ITEM_ID_LEN then return false, "ItemId length" end
    if type(record.Quantity) ~= "number" or record.Quantity ~= record.Quantity
        or record.Quantity < 1 or record.Quantity > MAX_ITEM_QUANTITY
        or record.Quantity % 1 ~= 0 then return false, "Quantity invalid" end
    local hasBagId   = record.BagId   ~= nil
    local hasBagSlot = record.BagSlot ~= nil
    if hasBagId ~= hasBagSlot then return false, "BagId/BagSlot mismatch" end
    if hasBagId then
        if type(record.BagId) ~= "number" or record.BagId % 1 ~= 0
            or record.BagId < 1 or record.BagId > 5 then return false, "BagId range" end
        if type(record.BagSlot) ~= "number" or record.BagSlot % 1 ~= 0
            or record.BagSlot < 1 then return false, "BagSlot range" end
    end
    if record.InstanceId ~= nil then
        if type(record.InstanceId) ~= "string" or #record.InstanceId < 1
            or #record.InstanceId > MAX_INSTANCE_LEN then return false, "InstanceId" end
    end
    return true
end

local function validateInventory(inventory)
    if type(inventory) ~= "table" then return false, "Missing Inventory" end
    if type(inventory.Items) ~= "table" or type(inventory.Equipment) ~= "table" then
        return false, "Invalid inventory structure" end
    if #inventory.Items > MAX_ITEMS then return false, "Item count exceeds limit" end
    local seenInstance = {}
    for index, record in ipairs(inventory.Items) do
        local ok, why = isValidItemRecord(record)
        if not ok then
            return false, string.format("Invalid item record %d: %s", index, tostring(why))
        end
        if record.InstanceId then
            if seenInstance[record.InstanceId] then
                return false, "Duplicate InstanceId: " .. record.InstanceId
            end
            seenInstance[record.InstanceId] = true
        end
    end
    for slot, instanceId in pairs(inventory.Equipment) do
        if type(slot) ~= "string" then return false, "Equipment slot key must be string" end
        if type(instanceId) ~= "string" then return false, "Equipment " .. slot .. " must reference InstanceId" end
        if not seenInstance[instanceId] then return false, "Equipment " .. slot .. " references unknown InstanceId" end
    end
    return true
end

function PlayerProfileValidator.Validate(profile)
    if type(profile) ~= "table" then return false, "Profile must be a table" end
    if profile.SchemaVersion ~= PlayerProfileTemplate.VERSION then return false, "Unsupported schema version" end
    local character = profile.Character
    if type(character) ~= "table" then return false, "Missing Character" end
    if type(character.Name) ~= "string" then return false, "Invalid character name" end
    if not isNonNegativeInteger(character.Level) or character.Level < 1 then return false, "Invalid level" end
    if not isNonNegativeInteger(character.Experience) then return false, "Invalid experience" end
    if not isNonNegativeInteger(character.Gold) then return false, "Invalid gold" end
    if type(profile.Stats) ~= "table" then return false, "Missing Stats" end
    for _, statName in ipairs({"Strength","Agility","Intelligence","Vitality"}) do
        if not isNonNegativeInteger(profile.Stats[statName]) then return false, "Invalid stat: " .. statName end
    end
    if type(profile.Progression) ~= "table" then return false, "Missing Progression" end
    for _, field in ipairs({"CompletedQuests","ActiveQuests","DiscoveredZones"}) do
        if type(profile.Progression[field]) ~= "table" then return false, "Invalid progression: " .. field end
    end
    local invOk, invWhy = validateInventory(profile.Inventory)
    if not invOk then return false, tostring(invWhy) end
    if type(profile.Settings) ~= "table" then return false, "Missing Settings" end
    if type(profile.Settings.ShowMinimap) ~= "boolean"
        or type(profile.Settings.ShowQuestTracker) ~= "boolean" then return false, "Invalid settings" end
    return true, "Profile valid"
end

return PlayerProfileValidator