-- REALMS OF ETERNIA
-- ITEM DEFINITIONS
-- Shared item statistics and properties.
-- No 3D model construction here.

local ItemDefinitions = {}

ItemDefinitions.Definitions = {

    RustySword = {
        Id = "RustySword",
        DisplayName = "Rusty Adventurer Sword",

        Type = "Weapon",
        SubType = "OneHandSword",
        Rarity = "Common",

        RequiredLevel = 1,

        Damage = 15,
        Range = 7,
        Cooldown = 0.5,
        HitDelay = 0.24,

        AnimationClass = "OneHandSword",

        ModelId = "RustySword",

        CanBeDropped = false,
    },

}

function ItemDefinitions.Get(itemId)
    if type(itemId) ~= "string" then
        return nil
    end

    return ItemDefinitions.Definitions[itemId]
end

return ItemDefinitions