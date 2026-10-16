-- REALMS OF LUMIA - WORLD REGION DEFINITIONS
-- Expanded starter-world zones for the pre-alpha open-world experience.
-- Client UI reads Name/Subtitle; server scaffolding also reads MinLevel/Volume/ReturnPoint.
local ZoneConfig = {
    DefaultId = "ForgottenForest",
    Zones = {
        ForgottenForest = {
            Name = "Forgotten Forest",
            Subtitle = "Where the wilderness awakens",
            MinLevel = 1,
        },
        StarterVillage = {
            Name = "Lumia Hamlet",
            Subtitle = "A refuge at the forest edge",
            MinLevel = 1,
            Volume = {
                Center = Vector3.new(0, 8, 0),
                Size = Vector3.new(74, 34, 74),
            },
            ReturnPoint = Vector3.new(0, 6, 0),
            MarkerText = "Welcome to Lumia Hamlet",
        },
        ForestTrail = {
            Name = "Forest Trail",
            Subtitle = "The first path into the wilds",
            MinLevel = 1,
            Volume = {
                Center = Vector3.new(-69, 9, 9),
                Size = Vector3.new(76, 34, 104),
            },
            ReturnPoint = Vector3.new(-44, 6, -2),
            MarkerText = "Forest Trail • Recommended Lv. 1",
        },
        OldRoad = {
            Name = "Old Road",
            Subtitle = "A weathered route of merchants and pilgrims",
            MinLevel = 1,
            Volume = {
                Center = Vector3.new(59, 9, 63),
                Size = Vector3.new(102, 34, 78),
            },
            ReturnPoint = Vector3.new(28, 6, 38),
            MarkerText = "Old Road • Old Merchant Route",
        },
        CreekBend = {
            Name = "Creek Bend",
            Subtitle = "Cold water, slick stones, and deeper shadows",
            MinLevel = 1,
            Volume = {
                Center = Vector3.new(-14, 9, -74),
                Size = Vector3.new(132, 34, 72),
            },
            ReturnPoint = Vector3.new(-20, 6, -48),
            MarkerText = "Creek Bend • Flowing Waters",
        },
        ThornwatchGlade = {
            Name = "Thornwatch Glade",
            Subtitle = "A wildland held by dire wolves",
            MinLevel = 4,
        },
        FirstGateApproach = {
            Name = "First Gate Approach",
            Subtitle = "Beyond this road lies the Guardian's domain",
            MinLevel = 5,
        },
        AncientStones = {
            Name = "Ancient Stones",
            Subtitle = "Ruins watched by powers older than the village",
            MinLevel = 1,
            Volume = {
                Center = Vector3.new(71, 9, -1),
                Size = Vector3.new(94, 34, 88),
            },
            ReturnPoint = Vector3.new(48, 6, 22),
            MarkerText = "Ancient Stones • Forgotten Ruins",
        },
    },
}

return ZoneConfig
