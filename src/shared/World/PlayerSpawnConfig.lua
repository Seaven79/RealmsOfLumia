-- REALMS OF LUMIA - PLAYER SPAWN SETTINGS v1.0
-- One starting village for now; per-zone checkpoints can be added later.
return {
    HouseTag = "LumiaNoMobHouse", -- Also used by existing wolf house-exclusion logic.
    ManualAnchorName = "LumiaPlayerSpawnAnchor", -- Optional Part in Workspace for exact placement.
    SearchHouseNames = {"house", "cottage", "hut", "cabin"}, -- Fallback if no tag.
    SideDistances = {6, 8, 11, 14}, -- From the bounding-box edge, in studs.
    ClearWidth = 4.5,
    ClearHeight = 5.5,
    MaxCastDepth = 220,
    HideAllSpawnPads = true,
    DisableOtherSpawnLocations = true, -- Starting village only; set false for checkpoints.
    ForceInitialCharacterPosition = true, -- Handles characters that loaded before setup.
    SpawnProtectionSeconds = 3,
}