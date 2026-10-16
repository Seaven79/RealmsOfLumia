-- REALMS OF LUMIA - MONSTER DEATH PRESENTATION SETTINGS
-- Simple side-lying corpse for now. Later, change Mode for specific monsters
-- when a proper animation/ragdoll feature is added. No combat data lives here.
return {
    Default = {
        Mode = "SidePose",       -- Supported now: "SidePose" or "None".
        RollDegrees = 83,        -- Rotate around the creature's local forward axis.
        GroundGap = 0.08,        -- Small gap above the ground to avoid clipping.
    },
    Monsters = {
        ForestWolf = {
            Mode = "SidePose",
            RollDegrees = 83,
        },
    },
}