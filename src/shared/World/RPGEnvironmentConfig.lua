-- REALMS OF LUMIA | RPG Environment settings v1
-- Visual-only configuration; do not modify terrain or map dimensions.
-- Adjust these values later without touching the environment controller.
local Config = {}

Config.ClockTime = 16.25 -- afternoon golden-hour sunlight
Config.Brightness = 2.1
Config.ExposureCompensation = -0.10
Config.GlobalShadows = true
Config.ShadowSoftness = 0.28
Config.Ambient = Color3.fromRGB(66, 74, 80)
Config.OutdoorAmbient = Color3.fromRGB(132, 139, 143)
Config.EnvironmentDiffuseScale = 0.36
Config.EnvironmentSpecularScale = 0.30

Config.Atmosphere = {
    Density = 0.22,
    Offset = 0.11,
    Color = Color3.fromRGB(206, 220, 213),
    Decay = Color3.fromRGB(125, 132, 113),
    Glare = 0.16,
    Haze = 0.65,
}
Config.ColorCorrection = {
    Brightness = 0.015,
    Contrast = 0.10,
    Saturation = 0.08,
    TintColor = Color3.fromRGB(255, 242, 223),
}
Config.Bloom = {Intensity = 0.12, Size = 16, Threshold = 1.65}
Config.SunRays = {Intensity = 0.055, Spread = 0.78}

-- Future forest art pass: tag selected tree models "LumiaFantasyTree".
-- Disabled intentionally until the actual map trees can be inspected.
Config.TreeStylingEnabled = false
Config.TreeLeafTint = Color3.fromRGB(73, 112, 74)
Config.TreeBarkTint = Color3.fromRGB(93, 75, 62)
Config.TreeTintAmount = 0.22

return Config
