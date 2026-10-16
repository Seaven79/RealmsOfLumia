-- Realms of Lumia | Forgotten Forest Visual Pass v1.0
-- Visuals only: no changes to map geometry, spawns, physics, or saves.
-- Most values can be tuned without changing the controller.
local Config = {}

Config.Tree = {
    Enabled = true,
    AutoDetectNamedModels = true,
    Tag = "LumiaFantasyTree", -- tag models when their names don't contain Tree/Pine/Oak/etc.
    MaxModels = 250,
    LeafTintStrength = 0.36,
    BarkTintStrength = 0.22,
    ApplyWoodToSimpleTrunks = true,
    LeafPalette = {
        Color3.fromRGB(55, 100, 58),
        Color3.fromRGB(75, 117, 65),
        Color3.fromRGB(91, 126, 66),
        Color3.fromRGB(57, 109, 78),
    },
    BarkPalette = {
        Color3.fromRGB(87, 70, 52),
        Color3.fromRGB(105, 82, 59),
        Color3.fromRGB(79, 68, 59),
    },
}

Config.Vegetation = {
    Enabled = true,
    RegionName = "ForgottenForest",
    AreaTag = "LumiaVegetationArea", -- optional invisible parts marking safe areas
    GrassTufts = 150,
    FlowerPatches = 26,
    MaxSamplesPerPlant = 12,
    MaxOffsetFromRegionCenter = 150,
    AvoidHouseStuds = 6,
    AvoidSpawnStuds = 9,
    ClearanceStuds = 1.0,
    MaxGroundSlope = 0.86, -- minimum surface normal Y
    RandomSeed = 1862,
    GrassColors = {
        Color3.fromRGB(61, 107, 53),
        Color3.fromRGB(75, 121, 66),
        Color3.fromRGB(93, 134, 70),
        Color3.fromRGB(55, 100, 68),
    },
    FlowerColors = {
        Color3.fromRGB(241, 222, 164),
        Color3.fromRGB(239, 231, 219),
        Color3.fromRGB(173, 167, 227),
        Color3.fromRGB(232, 174, 184),
    },
}

Config.Weather = {
    ClientClouds = true,
    CloudCover = 0.28,
    CloudDensity = 0.40,
    CloudColor = Color3.fromRGB(255, 247, 225),
    NativeTerrainGrass = true,
}

return Config
