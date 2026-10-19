-- REALMS OF LUMIA V19.1 | LIGHTING TUNED FOR COZY STARTER FOREST
-- REALMS OF LUMIA | RPG Environment settings v1
-- Visual-only configuration; do not modify terrain or map dimensions.
-- Adjust these values later without touching the environment controller.
local Config = {}

Config.ClockTime = 16.0 -- afternoon golden-hour sunlight
Config.Brightness = 2.2
Config.ExposureCompensation = -0.06
Config.GlobalShadows = true
Config.ShadowSoftness = 0.36
Config.Ambient = Color3.fromRGB(79, 83, 84)
Config.OutdoorAmbient = Color3.fromRGB(145, 151, 146)
Config.EnvironmentDiffuseScale = 0.42
Config.EnvironmentSpecularScale = 0.34

Config.Atmosphere = {
    Density = 0.20,
    Offset = 0.12,
    Color = Color3.fromRGB(227, 225, 211),
    Decay = Color3.fromRGB(138, 146, 117),
    Glare = 0.17,
    Haze = 0.74,
}
Config.ColorCorrection = {
    Brightness = 0.015,
    Contrast = 0.115,
    Saturation = 0.095,
    TintColor = Color3.fromRGB(255, 245, 229),
}
Config.Bloom = {Intensity = 0.14, Size = 18, Threshold = 1.6}
Config.SunRays = {Intensity = 0.062, Spread = 0.76}

-- Future forest art pass: tag selected tree models "LumiaFantasyTree".
-- Disabled intentionally until the actual map trees can be inspected.
Config.TreeStylingEnabled = false
Config.TreeLeafTint = Color3.fromRGB(73, 112, 74)
Config.TreeBarkTint = Color3.fromRGB(93, 75, 62)
Config.TreeTintAmount = 0.22

return Config
