-- REALMS OF LUMIA V19.1 | WORLD ART DIRECTION
-- Client-only cosmetics; change preset here or in GraphicsSettings.SelectedPreset.
-- No game balance, terrain, AI, NPC, quests or save data are modified.
local Art = {}
Art.Seed = 190101
Art.Enabled = false -- V20 premium layer replaces this decor pass; rollback restores true.
Art.Presets = {
    Low =      {TreePerRegion=2, BushPerRegion=4, DetailPerRegion=4, VillageExtras=1, PartBudget=350, ParticleRate=0, Lights=false},
    Balanced = {TreePerRegion=5, BushPerRegion=8, DetailPerRegion=8, VillageExtras=3, PartBudget=750, ParticleRate=0.5, Lights=true},
    High =     {TreePerRegion=9, BushPerRegion=14, DetailPerRegion=13, VillageExtras=5, PartBudget=1250, ParticleRate=0.9, Lights=true},
}
Art.Regions = {
    {Id="Village",       X=0,  Z=0,   SpanX=30, SpanZ=28, Style="Meadow", Seed=1},
    {Id="ForestTrail",   X=-69,Z=9,   SpanX=29, SpanZ=35, Style="Meadow", Seed=2},
    {Id="OldRoad",       X=58, Z=65,  SpanX=38, SpanZ=29, Style="Road",   Seed=3},
    {Id="CreekBend",     X=-18,Z=-73, SpanX=43, SpanZ=21, Style="Creek",  Seed=4},
    {Id="AncientStones", X=68, Z=-6,  SpanX=26, SpanZ=31, Style="Ruins",  Seed=5},
    -- Outer-zone centers are resolved against the existing Grassland size by the client.
    {Id="Thornwatch",    Outer=1,     SpanX=46, SpanZ=57, Style="Thorn",  Seed=6},
    {Id="FirstGate",     Outer=2,     SpanX=46, SpanZ=57, Style="Gate",   Seed=7},
}
Art.Palettes = {
    Meadow = {Bark=Color3.fromRGB(101,73,53), Leaf=Color3.fromRGB(81,128,71), Leaf2=Color3.fromRGB(113,153,83), Accent=Color3.fromRGB(234,197,116), Rock=Color3.fromRGB(127,128,116)},
    Road   = {Bark=Color3.fromRGB(96,76,56), Leaf=Color3.fromRGB(101,119,68), Leaf2=Color3.fromRGB(147,139,79), Accent=Color3.fromRGB(244,199,122), Rock=Color3.fromRGB(134,125,108)},
    Creek  = {Bark=Color3.fromRGB(79,84,65), Leaf=Color3.fromRGB(64,125,105), Leaf2=Color3.fromRGB(93,153,128), Accent=Color3.fromRGB(157,212,207), Rock=Color3.fromRGB(100,119,124)},
    Ruins  = {Bark=Color3.fromRGB(91,80,82), Leaf=Color3.fromRGB(75,104,79), Leaf2=Color3.fromRGB(102,127,109), Accent=Color3.fromRGB(185,157,232), Rock=Color3.fromRGB(119,112,132)},
    Thorn  = {Bark=Color3.fromRGB(68,70,53), Leaf=Color3.fromRGB(54,94,70), Leaf2=Color3.fromRGB(72,122,77), Accent=Color3.fromRGB(155,222,179), Rock=Color3.fromRGB(94,105,97)},
    Gate   = {Bark=Color3.fromRGB(73,72,74), Leaf=Color3.fromRGB(69,88,95), Leaf2=Color3.fromRGB(91,114,118), Accent=Color3.fromRGB(145,201,240), Rock=Color3.fromRGB(115,116,140)},
}
Art.ColorGrades = {
    Meadow = {Tint=Color3.fromRGB(255,245,221), Saturation=0.045, Contrast=0.015},
    Road   = {Tint=Color3.fromRGB(255,231,204), Saturation=-0.025, Contrast=0.04},
    Creek  = {Tint=Color3.fromRGB(221,251,247), Saturation=0.015, Contrast=0.025},
    Ruins  = {Tint=Color3.fromRGB(235,222,250), Saturation=-0.055, Contrast=0.065},
    Thorn  = {Tint=Color3.fromRGB(220,235,216), Saturation=-0.075, Contrast=0.07},
    Gate   = {Tint=Color3.fromRGB(216,230,250), Saturation=-0.085, Contrast=0.095},
}
return Art
