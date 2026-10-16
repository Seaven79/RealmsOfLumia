-- REALMS OF LUMIA | Character classes v1
-- This module defines class identity only. Skills, gear restrictions,
-- class selection, and stat bonuses can be implemented later.
local CharacterClassConfig = {}

CharacterClassConfig.DEFAULT_CLASS = "Warrior"
CharacterClassConfig.Definitions = {
    Warrior = {
        DisplayName = "Warrior",
        Description = "A melee-focused adventurer",
    },
}

-- Preserve future selected classes, but assign Warrior to legacy characters
-- that do not have a class or were previously shown as Unassigned.
function CharacterClassConfig.Resolve(savedClass)
    if type(savedClass) ~= "string"
        or savedClass == ""
        or savedClass == "Unassigned" then
        return CharacterClassConfig.DEFAULT_CLASS
    end
    return savedClass
end

return CharacterClassConfig
