-- Realms of Lumia - Step 13.1
-- All character sheet colors and fixed layout dimensions live here.
-- Change this file later to restyle the interface without touching player data.
local Theme = {}

Theme.WindowWidth = 632
Theme.WindowHeight = 660
Theme.HorizontalPadding = 12
Theme.SlotWidth = 300
Theme.SlotHeight = 51
Theme.SlotGap = 8

Theme.Background = Color3.fromRGB(16, 24, 39)
Theme.Panel = Color3.fromRGB(30, 44, 64)
Theme.Slot = Color3.fromRGB(34, 49, 69)
Theme.StatCell = Color3.fromRGB(41, 57, 78)
Theme.Border = Color3.fromRGB(52, 70, 95)
Theme.Gold = Color3.fromRGB(227, 180, 94)
Theme.White = Color3.fromRGB(235, 242, 250)
Theme.Secondary = Color3.fromRGB(163, 181, 204)
Theme.Muted = Color3.fromRGB(120, 141, 167)
Theme.Green = Color3.fromRGB(97, 217, 154)
Theme.TooltipBackground = Color3.fromRGB(11, 18, 32)

Theme.RarityColors = {
    Common = Color3.fromRGB(226, 232, 240),
    Uncommon = Color3.fromRGB(97, 217, 154),
    Rare = Color3.fromRGB(103, 167, 255),
    Epic = Color3.fromRGB(199, 154, 255),
    Legendary = Color3.fromRGB(242, 187, 98),
}

return Theme
