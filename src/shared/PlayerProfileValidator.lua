local PlayerProfileTemplate = require(script.Parent.PlayerProfileTemplate)

local PlayerProfileValidator = {}

local function deepCopy(value)
    if type(value) ~= "table" then
        return value
    end

    local copy = {}

    for key, item in pairs(value) do
        copy[deepCopy(key)] = deepCopy(item)
    end

    return copy
end

local function isNonNegativeInteger(value)
    return type(value) == "number"
        and value == value
        and value >= 0
        and value < math.huge
        and value % 1 == 0
end

function PlayerProfileValidator.CreateDefault()
    return deepCopy(PlayerProfileTemplate.Default)
end

function PlayerProfileValidator.Validate(profile)
    if type(profile) ~= "table" then
        return false, "Profile must be a table"
    end

    if profile.SchemaVersion ~= PlayerProfileTemplate.VERSION then
        return false, "Unsupported schema version"
    end

    local character = profile.Character

    if type(character) ~= "table" then
        return false, "Missing Character section"
    end

    if type(character.Name) ~= "string" then
        return false, "Invalid character name"
    end

    if not isNonNegativeInteger(character.Level)
        or character.Level < 1 then
        return false, "Invalid character level"
    end

    if not isNonNegativeInteger(character.Experience) then
        return false, "Invalid experience"
    end

    if not isNonNegativeInteger(character.Gold) then
        return false, "Invalid gold"
    end

    if type(profile.Stats) ~= "table" then
        return false, "Missing Stats section"
    end

    for _, statName in ipairs({
        "Strength",
        "Agility",
        "Intelligence",
        "Vitality"
    }) do
        if not isNonNegativeInteger(profile.Stats[statName]) then
            return false, "Invalid stat: " .. statName
        end
    end

    if type(profile.Progression) ~= "table" then
        return false, "Missing Progression section"
    end

    for _, field in ipairs({
        "CompletedQuests",
        "ActiveQuests",
        "DiscoveredZones"
    }) do
        if type(profile.Progression[field]) ~= "table" then
            return false, "Invalid progression: " .. field
        end
    end

    if type(profile.Inventory) ~= "table" then
        return false, "Missing Inventory section"
    end

    if type(profile.Inventory.Items) ~= "table"
        or type(profile.Inventory.Equipment) ~= "table" then
        return false, "Invalid inventory structure"
    end

    if type(profile.Settings) ~= "table" then
        return false, "Missing Settings section"
    end

    if type(profile.Settings.ShowMinimap) ~= "boolean"
        or type(profile.Settings.ShowQuestTracker) ~= "boolean" then
        return false, "Invalid settings"
    end

    return true, "Profile valid"
end

return PlayerProfileValidator