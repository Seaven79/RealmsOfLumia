-- REALMS OF LUMIA - PRE-ALPHA ACHIEVEMENTS
-- Shared metadata only. Unlock logic lives in AchievementService.
local AchievementConfig = {}

AchievementConfig.Definitions = {
    Level2 = {
        Id = "Level2",
        Name = "On the Path",
        Description = "Reach level 2.",
        ToastIcon = "+",
    },
    Level3 = {
        Id = "Level3",
        Name = "Wilderness Ready",
        Description = "Reach level 3.",
        ToastIcon = "+",
    },
    Level5 = {
        Id = "Level5",
        Name = "Pathwarden",
        Description = "Reach level 5.",
        ToastIcon = "+",
    },
    FirstQuest = {
        Id = "FirstQuest",
        Name = "A Helping Hand",
        Description = "Complete your first quest in Lumia.",
        ToastIcon = "★",
    },
    Explorer3 = {
        Id = "Explorer3",
        Name = "Trailblazer",
        Description = "Discover three regions beyond the village.",
        ToastIcon = "✦",
    },
    ExplorerAll = {
        Id = "ExplorerAll",
        Name = "Frontier Walker",
        Description = "Discover all starter-world regions.",
        ToastIcon = "✦",
    },
    FirstPaths = {
        Id = "FirstPaths",
        Name = "The First Paths",
        Description = "Complete the twelve village quests.",
        ToastIcon = "✦",
    },
    GuardiansOfLumia = {
        Id = "GuardiansOfLumia",
        Name = "Guardians of Lumia",
        Description = "Defeat the Thornbound Guardian together as two adventurers.",
        ToastIcon = "✦",
        TitleReward = "Guardian of the First Gate",
        ItemReward = "SigilOfPassage",
    },
}

AchievementConfig.Order = {
    "Level2",
    "Level3",
    "Level5",
    "FirstQuest",
    "Explorer3",
    "ExplorerAll",
    "FirstPaths",
    "GuardiansOfLumia",
}

function AchievementConfig.Get(id)
    if type(id) ~= "string" then
        return nil
    end
    return AchievementConfig.Definitions[id]
end

return AchievementConfig
