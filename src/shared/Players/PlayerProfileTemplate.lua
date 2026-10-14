local PlayerProfileTemplate = {}

PlayerProfileTemplate.VERSION = 1

PlayerProfileTemplate.Default = {
    SchemaVersion = 1,

    Character = {
        Name = "",
        Level = 1,
        Experience = 0,
        Gold = 0,
    },

    Stats = {
        Strength = 5,
        Agility = 5,
        Intelligence = 5,
        Vitality = 5,
    },

    Progression = {
        CompletedQuests = {},
        ActiveQuests = {},
        DiscoveredZones = {},
    },

    Inventory = {
        Items = {},
        Equipment = {},
        Bags = { [1] = "StarterBackpack" },
    },

    Settings = {
        ShowMinimap = true,
        ShowQuestTracker = true,
        BagViewMode = "selected",
        SelectedBagId = 1,
        -- Player-customizable movement controls, saved with the existing profile.
        Keybinds = {
            Forward = "W",
            Backward = "S",
            StrafeLeft = "A",
            StrafeRight = "D",
        },
    },
}

return PlayerProfileTemplate