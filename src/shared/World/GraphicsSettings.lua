-- Realms of Lumia | Client graphics presets v1.0
-- Change SelectedPreset to "Low", "Balanced" or "High" for testing.
-- Visual options only. This does NOT change Roblox's engine-level graphics slider.
local GraphicsSettings = {}

GraphicsSettings.SelectedPreset = "Balanced"
GraphicsSettings.GroundPartName = "Grassland"
GraphicsSettings.GroundWaitSeconds = 20

GraphicsSettings.Presets = {
    Low = {
        GrassTufts = 45, Flowers = 6,
        DecorationBatch = 5, TreeBatch = 6,
        EnableBloom = false, EnableSunRays = false,
    },
    Balanced = {
        GrassTufts = 90, Flowers = 14,
        DecorationBatch = 8, TreeBatch = 10,
        EnableBloom = true, EnableSunRays = true,
    },
    High = {
        GrassTufts = 150, Flowers = 26,
        DecorationBatch = 10, TreeBatch = 16,
        EnableBloom = true, EnableSunRays = true,
    },
}

return GraphicsSettings
