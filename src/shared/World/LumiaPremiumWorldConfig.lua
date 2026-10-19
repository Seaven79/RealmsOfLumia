-- REALMS OF LUMIA V20 | PREMIUM WORLD ART CONFIGURATION
-- Purely local decoration. Does not change terrain, player saves, combat or quests.
local Art = {}
Art.Enabled = true
Art.Seed = 202020
Art.DistanceToBuild = 190 -- Create scenic content near the viewer; StreamingEnabled-friendly
Art.RefreshSeconds = 3
Art.Presets = {
    Low = {PartBudget=680, Trees=1, Shrubs=2, Foliage=4, Rocks=2, Lanterns=1, Lights=2, ParticleRate=0},
    Balanced = {PartBudget=1420, Trees=4, Shrubs=6, Foliage=10, Rocks=4, Lanterns=1, Lights=7, ParticleRate=0.65},
    High = {PartBudget=2250, Trees=7, Shrubs=10, Foliage=17, Rocks=7, Lanterns=2, Lights=12, ParticleRate=1.25},
}
Art.Regions = {
    {Id="Hamlet", X=0, Z=0, Radius=39, Style="Hamlet", Major="Village"},
    {Id="Trail", X=-68, Z=8, Radius=44, Style="Trail", Major="ElderGrove"},
    {Id="Road", X=61, Z=65, Radius=45, Style="Road", Major="Cart"},
    {Id="Creek", X=-15, Z=-76, Radius=46, Style="Creek", Major="WaterGarden"},
    {Id="Ruins", X=70, Z=-9, Radius=42, Style="Ruins", Major="RuinedSanctuary"},
    {Id="Thorn", Outer=1, Radius=53, Style="Thorn", Major="ThornWatch"},
    {Id="Gate", Outer=2, Radius=53, Style="Gate", Major="FirstGate"},
}
Art.Palettes = {
    Hamlet = {Bark=Color3.fromRGB(94,65,43), Wood=Color3.fromRGB(134,92,59), Leaf=Color3.fromRGB(71,131,66), Alt=Color3.fromRGB(127,173,78), Rock=Color3.fromRGB(143,132,113), Accent=Color3.fromRGB(255,211,122), Bloom=Color3.fromRGB(243,177,198)},
    Trail  = {Bark=Color3.fromRGB(91,72,49), Wood=Color3.fromRGB(125,91,60), Leaf=Color3.fromRGB(65,118,60), Alt=Color3.fromRGB(120,164,87), Rock=Color3.fromRGB(125,131,111), Accent=Color3.fromRGB(238,206,126), Bloom=Color3.fromRGB(236,225,180)},
    Road   = {Bark=Color3.fromRGB(99,76,52), Wood=Color3.fromRGB(133,103,71), Leaf=Color3.fromRGB(106,126,64), Alt=Color3.fromRGB(153,143,75), Rock=Color3.fromRGB(150,135,116), Accent=Color3.fromRGB(254,197,117), Bloom=Color3.fromRGB(236,213,149)},
    Creek  = {Bark=Color3.fromRGB(70,91,72), Wood=Color3.fromRGB(109,117,90), Leaf=Color3.fromRGB(42,126,99), Alt=Color3.fromRGB(90,166,142), Rock=Color3.fromRGB(100,130,132), Accent=Color3.fromRGB(137,226,220), Bloom=Color3.fromRGB(218,250,232)},
    Ruins  = {Bark=Color3.fromRGB(85,76,84), Wood=Color3.fromRGB(105,94,104), Leaf=Color3.fromRGB(73,105,88), Alt=Color3.fromRGB(112,135,109), Rock=Color3.fromRGB(133,120,147), Accent=Color3.fromRGB(193,150,255), Bloom=Color3.fromRGB(221,195,255)},
    Thorn  = {Bark=Color3.fromRGB(66,63,53), Wood=Color3.fromRGB(94,92,67), Leaf=Color3.fromRGB(51,91,68), Alt=Color3.fromRGB(72,114,82), Rock=Color3.fromRGB(99,111,98), Accent=Color3.fromRGB(151,222,168), Bloom=Color3.fromRGB(198,230,165)},
    Gate   = {Bark=Color3.fromRGB(65,74,75), Wood=Color3.fromRGB(84,101,104), Leaf=Color3.fromRGB(60,89,102), Alt=Color3.fromRGB(91,119,129), Rock=Color3.fromRGB(112,119,144), Accent=Color3.fromRGB(121,205,255), Bloom=Color3.fromRGB(187,236,255)},
}
Art.Grades = {
    Hamlet={Tint=Color3.fromRGB(255,241,216),Saturation=0.09,Contrast=0.04},
    Trail ={Tint=Color3.fromRGB(248,242,221),Saturation=0.08,Contrast=0.04},
    Road  ={Tint=Color3.fromRGB(255,233,211),Saturation=0.04,Contrast=0.06},
    Creek ={Tint=Color3.fromRGB(223,252,243),Saturation=0.08,Contrast=0.05},
    Ruins ={Tint=Color3.fromRGB(239,220,255),Saturation=-0.035,Contrast=0.095},
    Thorn ={Tint=Color3.fromRGB(220,239,221),Saturation=-0.055,Contrast=0.095},
    Gate  ={Tint=Color3.fromRGB(220,231,255),Saturation=-0.06,Contrast=0.105},
}
return Art
