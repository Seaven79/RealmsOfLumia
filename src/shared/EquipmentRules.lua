-- Realms of Eternia - Step 13.2
-- Shared data-only equipment compatibility rules.
-- The server ALWAYS repeats these checks before changing saved data.

local EquipmentRules = {}

EquipmentRules.ValidSlots = {
    Head = true,
    Chest = true,
    Hands = true,
    Legs = true,
    Feet = true,
    MainHand = true,
    OffHand = true,
    Ring = true,
}

-- Explicit mapping; unsupported item types NEVER equip accidentally.
-- When new items are designed, expand this table deliberately.
local compatible = {
    Weapon = {
        OneHandSword = "MainHand",
        TwoHandSword = "MainHand",
        Dagger = "MainHand",
        Staff = "MainHand",
        Bow = "MainHand",
    },
    Armor = {
        Helmet = "Head",
        Head = "Head",
        Chest = "Chest",
        Gloves = "Hands",
        Hands = "Hands",
        Legs = "Legs",
        Boots = "Feet",
        Feet = "Feet",
        Shield = "OffHand",
        Ring = "Ring",
    },
}

function EquipmentRules.GetSlot(definition)
    if type(definition) ~= "table" then
        return nil
    end
    local typeMap = compatible[definition.Type]
    if type(typeMap) ~= "table" then
        return nil
    end
    return typeMap[definition.SubType]
end

function EquipmentRules.IsValidSlot(slot)
    return type(slot) == "string" and EquipmentRules.ValidSlots[slot] == true
end

return EquipmentRules
