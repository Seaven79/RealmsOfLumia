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

-- Resolve the curve layer once. ItemDefinitions is the single choke point every
-- consumer reads through (tooltip, bag, merchant, combat), so applying the template
-- here is what makes gear numbers follow the active template everywhere.
local GearCurveModule
local function gearCurve()
    if GearCurveModule ~= nil then return GearCurveModule or nil end
    GearCurveModule = false
    local shared = script.Parent.Parent
    local commerce = shared:FindFirstChild("Commerce")
    local moduleScript = commerce and commerce:FindFirstChild("GearCurve")
    if moduleScript then
        local ok, result = pcall(function() return require(moduleScript) end)
        if ok and type(result) == "table" then
            GearCurveModule = result
        else
            warn("[Lumia - ItemDefinitions] GearCurve require failed: " .. tostring(result))
        end
    end
    return GearCurveModule or nil
end

function ItemDefinitions.Get(itemId)
    if type(itemId) ~= "string" then return nil end
    local definition = ItemDefinitions.Definitions[itemId]
    if not definition then return nil end
    local curve = gearCurve()
    if curve then return curve.Apply(definition) end
    return definition
end

-- The authored definition, ignoring the active template. Used by the admin panel
-- and by previews that need to show the baseline numbers.
function ItemDefinitions.GetAuthored(itemId)
    if type(itemId) ~= "string" then return nil end
    return ItemDefinitions.Definitions[itemId]
end

return ItemDefinitions