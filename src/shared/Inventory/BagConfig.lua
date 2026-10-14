-- REALMS OF LUMIA - BAGS V1
-- Five bag EQUIPMENT positions. Only position 1 is populated at creation.
-- Expansion requires adding real bag definitions and an authoritative equip-bag action.
local BagConfig = {}
BagConfig.MaxBags = 5
BagConfig.StarterBag = "StarterBackpack"
BagConfig.Definitions = {
    StarterBackpack = { Name = "Starter Backpack", Capacity = 8 },
}

function BagConfig.IsBagPosition(value)
    return type(value) == "number" and value % 1 == 0
        and value >= 1 and value <= BagConfig.MaxBags
end

function BagConfig.GetCapacity(bags, bagId)
    if not BagConfig.IsBagPosition(bagId) or type(bags) ~= "table" then return 0 end
    local definition = BagConfig.Definitions[bags[bagId]]
    return definition and definition.Capacity or 0
end

function BagConfig.GetPublicBags(bags)
    local result = {}
    for bagId = 1, BagConfig.MaxBags do
        local bagType = type(bags) == "table" and bags[bagId] or nil
        local definition = bagType and BagConfig.Definitions[bagType]
        result[bagId] = {
            BagId = bagId,
            Equipped = definition ~= nil,
            BagType = definition and bagType or "",
            Name = definition and definition.Name or "Empty Bag Slot",
            Capacity = definition and definition.Capacity or 0,
        }
    end
    return result
end

function BagConfig.TotalCapacity(bags)
    local total = 0
    for bagId = 1, BagConfig.MaxBags do
        total += BagConfig.GetCapacity(bags, bagId)
    end
    return total
end

return BagConfig
