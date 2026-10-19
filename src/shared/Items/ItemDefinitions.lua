-- REALMS OF LUMIA
-- ITEM DEFINITIONS
-- Stage 1 patch: GearCatalog merge moved to module load (hot path fix).

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
    ForgedSword = { Id = "ForgedSword", DisplayName = "Wayfarer Blade",
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
        HitDelay = 0.18,
        AnimationClass = "OneHandSword",
        ModelId = "RustySword",
        CanBeDropped = false,
    },
}

-- Stage 1: merge GearCatalog ONCE at module load (was: on every Get call).
-- Guard against load-order issues using FindFirstChild + pcall, no yielding wait.
do
    local shared = script.Parent.Parent
    local commerce = shared:FindFirstChild("Commerce")
    local gearScript = commerce and commerce:FindFirstChild("GearCatalog")
    if gearScript then
        local ok, GearCatalog = pcall(function() return require(gearScript) end)
        if ok and type(GearCatalog) == "table" and type(GearCatalog.Items) == "table" then
            for itemId, definition in pairs(GearCatalog.Items) do
                if ItemDefinitions.Definitions[itemId] == nil then
                    ItemDefinitions.Definitions[itemId] = definition
                end
            end
        else
            warn("[Lumia - ItemDefinitions] GearCatalog require failed at load: " .. tostring(GearCatalog))
        end
    else
        warn("[Lumia - ItemDefinitions] GearCatalog not found at load; catalog items will not be resolvable")
    end
end

function ItemDefinitions.Get(itemId)
    if type(itemId) ~= "string" then return nil end
    return ItemDefinitions.Definitions[itemId]
end

return ItemDefinitions