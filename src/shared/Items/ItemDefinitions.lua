-- REALMS OF LUMIA
-- ITEM DEFINITIONS
-- Shared item statistics and properties.
-- No 3D model construction here.

local ItemDefinitions = {}

ItemDefinitions.Definitions = {
    SigilOfPassage = {
        Id = "SigilOfPassage", DisplayName = "Sigil of Passage",
        Type = "Quest", Rarity = "Rare", CanBeDropped = false,
        SellValue = 0, QuestItem = true,
    },

    WolfRunestone = { Id = "WolfRunestone", DisplayName = "Runestone Fragment",
        Type = "Quest", Rarity = "Uncommon", CanBeDropped = false,
        SellValue = 0, QuestItem = true },
    FieldPotion = { Id = "FieldPotion", DisplayName = "Herbal Restorative",
        Type = "Potion", Rarity = "Common", CanBeDropped = true,
        Heal = 35, SellValue = 9 },
    ForgedSword = { Id = "ForgedSword", DisplayName = "Wayfarer's Blade",
        Type = "Weapon", SubType = "OneHandSword", Rarity = "Uncommon",
        RequiredLevel = 2, Damage = 20, Range = 7, Cooldown = 0.5,
        HitDelay = 0.18, AnimationClass = "OneHandSword", ModelId = "RustySword",
        CanBeDropped = false, SellValue = 38 },
    WolfTornFur = { Id = "WolfTornFur", DisplayName = "Torn Wolf Fur",
        Type = "Material", Rarity = "Poor", CanBeDropped = true, SellValue = 3 },
    WolfBrokenFang = { Id = "WolfBrokenFang", DisplayName = "Chipped Wolf Fang",
        Type = "Material", Rarity = "Poor", CanBeDropped = true, SellValue = 5 },
    WolfMattedHide = { Id = "WolfMattedHide", DisplayName = "Matted Wolf Hide",
        Type = "Material", Rarity = "Poor", CanBeDropped = true, SellValue = 4 },
    WolfDullClaw = { Id = "WolfDullClaw", DisplayName = "Dull Wolf Claw",
        Type = "Material", Rarity = "Poor", CanBeDropped = true, SellValue = 6 },

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
        HitDelay = 0.18, -- Earlier server contact check to reduce sound lag (cut peaks around 0.23 s).

        AnimationClass = "OneHandSword",

        ModelId = "RustySword",

        CanBeDropped = false,
    },

}

function ItemDefinitions.Get(itemId)
    if type(itemId) ~= "string" then
        return nil
    end

    local GearCatalog = require(script.Parent.Parent:WaitForChild("Commerce"):WaitForChild("GearCatalog"))
for itemId, definition in pairs(GearCatalog.Items) do
    ItemDefinitions.Definitions[itemId] = definition
end

return ItemDefinitions.Definitions[itemId]
end

local GearCatalog = require(script.Parent.Parent:WaitForChild("Commerce"):WaitForChild("GearCatalog"))
for itemId, definition in pairs(GearCatalog.Items) do
    ItemDefinitions.Definitions[itemId] = definition
end

return ItemDefinitions