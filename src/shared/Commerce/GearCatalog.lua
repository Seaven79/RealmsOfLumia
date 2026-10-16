-- Lumia V17 - equipment progression and vendor stocks
local Catalog = {}
Catalog.Stock = {}
Catalog.Items = {}
Catalog.TierNames = {
    [1] = "Apprentice",
    [2] = "Trailkeeper",
    [3] = "Pathfinder",
    [4] = "Thornwatch",
    [5] = "Gatewarden",
}
for level = 1, 5 do
    Catalog.Stock[level] = {}
end

Catalog.Items.Lumia1Sword = {Id="Lumia1Sword",DisplayName="Apprentice Sword",Type="Weapon",SubType="OneHandSword",Rarity="Common",RequiredLevel=1,GearTier=1,Attack=2,Defense=0,BonusHealth=0,SellValue=4,CanBeDropped=false,Damage=23,Range=7.78,Cooldown=0.5,HitDelay=0.17,AnimationClass="OneHandSword",ModelId="RustySword"}
table.insert(Catalog.Stock[1], {ItemId="Lumia1Sword",Price=14,DisplayName="Apprentice Sword",Description="Level 1 MainHand"})
Catalog.Items.Lumia1Hood = {Id="Lumia1Hood",DisplayName="Apprentice Hood",Type="Armor",SubType="Helmet",Rarity="Common",RequiredLevel=1,GearTier=1,Attack=0,Defense=4,BonusHealth=0,SellValue=2,CanBeDropped=false,}
table.insert(Catalog.Stock[1], {ItemId="Lumia1Hood",Price=6,DisplayName="Apprentice Hood",Description="Level 1 Head"})
Catalog.Items.Lumia1Vest = {Id="Lumia1Vest",DisplayName="Apprentice Vest",Type="Armor",SubType="Chest",Rarity="Common",RequiredLevel=1,GearTier=1,Attack=0,Defense=7,BonusHealth=3,SellValue=4,CanBeDropped=false,}
table.insert(Catalog.Stock[1], {ItemId="Lumia1Vest",Price=12,DisplayName="Apprentice Vest",Description="Level 1 Chest"})
Catalog.Items.Lumia1Gloves = {Id="Lumia1Gloves",DisplayName="Apprentice Gloves",Type="Armor",SubType="Gloves",Rarity="Common",RequiredLevel=1,GearTier=1,Attack=0,Defense=4,BonusHealth=0,SellValue=1,CanBeDropped=false,}
table.insert(Catalog.Stock[1], {ItemId="Lumia1Gloves",Price=5,DisplayName="Apprentice Gloves",Description="Level 1 Hands"})
Catalog.Items.Lumia1Leggings = {Id="Lumia1Leggings",DisplayName="Apprentice Leggings",Type="Armor",SubType="Legs",Rarity="Common",RequiredLevel=1,GearTier=1,Attack=0,Defense=6,BonusHealth=3,SellValue=3,CanBeDropped=false,}
table.insert(Catalog.Stock[1], {ItemId="Lumia1Leggings",Price=9,DisplayName="Apprentice Leggings",Description="Level 1 Legs"})
Catalog.Items.Lumia1Boots = {Id="Lumia1Boots",DisplayName="Apprentice Boots",Type="Armor",SubType="Boots",Rarity="Common",RequiredLevel=1,GearTier=1,Attack=0,Defense=4,BonusHealth=0,SellValue=2,CanBeDropped=false,}
table.insert(Catalog.Stock[1], {ItemId="Lumia1Boots",Price=6,DisplayName="Apprentice Boots",Description="Level 1 Feet"})
Catalog.Items.Lumia1Ward = {Id="Lumia1Ward",DisplayName="Apprentice Ward",Type="Armor",SubType="Shield",Rarity="Common",RequiredLevel=1,GearTier=1,Attack=0,Defense=5,BonusHealth=0,SellValue=2,CanBeDropped=false,}
table.insert(Catalog.Stock[1], {ItemId="Lumia1Ward",Price=8,DisplayName="Apprentice Ward",Description="Level 1 OffHand"})
Catalog.Items.Lumia1Band = {Id="Lumia1Band",DisplayName="Apprentice Band",Type="Armor",SubType="Ring",Rarity="Common",RequiredLevel=1,GearTier=1,Attack=0,Defense=3,BonusHealth=0,SellValue=1,CanBeDropped=false,}
table.insert(Catalog.Stock[1], {ItemId="Lumia1Band",Price=5,DisplayName="Apprentice Band",Description="Level 1 Ring"})
Catalog.Items.Lumia2Sword = {Id="Lumia2Sword",DisplayName="Trailkeeper Sword",Type="Weapon",SubType="OneHandSword",Rarity="Common",RequiredLevel=2,GearTier=2,Attack=4,Defense=0,BonusHealth=0,SellValue=9,CanBeDropped=false,Damage=30,Range=7.96,Cooldown=0.5,HitDelay=0.17,AnimationClass="OneHandSword",ModelId="RustySword"}
table.insert(Catalog.Stock[2], {ItemId="Lumia2Sword",Price=27,DisplayName="Trailkeeper Sword",Description="Level 2 MainHand"})
Catalog.Items.Lumia2Hood = {Id="Lumia2Hood",DisplayName="Trailkeeper Hood",Type="Armor",SubType="Helmet",Rarity="Common",RequiredLevel=2,GearTier=2,Attack=0,Defense=6,BonusHealth=0,SellValue=4,CanBeDropped=false,}
table.insert(Catalog.Stock[2], {ItemId="Lumia2Hood",Price=12,DisplayName="Trailkeeper Hood",Description="Level 2 Head"})
Catalog.Items.Lumia2Vest = {Id="Lumia2Vest",DisplayName="Trailkeeper Vest",Type="Armor",SubType="Chest",Rarity="Common",RequiredLevel=2,GearTier=2,Attack=0,Defense=9,BonusHealth=6,SellValue=8,CanBeDropped=false,}
table.insert(Catalog.Stock[2], {ItemId="Lumia2Vest",Price=24,DisplayName="Trailkeeper Vest",Description="Level 2 Chest"})
Catalog.Items.Lumia2Gloves = {Id="Lumia2Gloves",DisplayName="Trailkeeper Gloves",Type="Armor",SubType="Gloves",Rarity="Common",RequiredLevel=2,GearTier=2,Attack=0,Defense=6,BonusHealth=0,SellValue=4,CanBeDropped=false,}
table.insert(Catalog.Stock[2], {ItemId="Lumia2Gloves",Price=12,DisplayName="Trailkeeper Gloves",Description="Level 2 Hands"})
Catalog.Items.Lumia2Leggings = {Id="Lumia2Leggings",DisplayName="Trailkeeper Leggings",Type="Armor",SubType="Legs",Rarity="Common",RequiredLevel=2,GearTier=2,Attack=0,Defense=8,BonusHealth=6,SellValue=5,CanBeDropped=false,}
table.insert(Catalog.Stock[2], {ItemId="Lumia2Leggings",Price=17,DisplayName="Trailkeeper Leggings",Description="Level 2 Legs"})
Catalog.Items.Lumia2Boots = {Id="Lumia2Boots",DisplayName="Trailkeeper Boots",Type="Armor",SubType="Boots",Rarity="Common",RequiredLevel=2,GearTier=2,Attack=0,Defense=6,BonusHealth=0,SellValue=4,CanBeDropped=false,}
table.insert(Catalog.Stock[2], {ItemId="Lumia2Boots",Price=12,DisplayName="Trailkeeper Boots",Description="Level 2 Feet"})
Catalog.Items.Lumia2Ward = {Id="Lumia2Ward",DisplayName="Trailkeeper Ward",Type="Armor",SubType="Shield",Rarity="Common",RequiredLevel=2,GearTier=2,Attack=0,Defense=7,BonusHealth=0,SellValue=5,CanBeDropped=false,}
table.insert(Catalog.Stock[2], {ItemId="Lumia2Ward",Price=16,DisplayName="Trailkeeper Ward",Description="Level 2 OffHand"})
Catalog.Items.Lumia2Band = {Id="Lumia2Band",DisplayName="Trailkeeper Band",Type="Armor",SubType="Ring",Rarity="Common",RequiredLevel=2,GearTier=2,Attack=0,Defense=5,BonusHealth=0,SellValue=3,CanBeDropped=false,}
table.insert(Catalog.Stock[2], {ItemId="Lumia2Band",Price=11,DisplayName="Trailkeeper Band",Description="Level 2 Ring"})
Catalog.Items.Lumia3Sword = {Id="Lumia3Sword",DisplayName="Pathfinder Sword",Type="Weapon",SubType="OneHandSword",Rarity="Uncommon",RequiredLevel=3,GearTier=3,Attack=6,Defense=0,BonusHealth=0,SellValue=13,CanBeDropped=false,Damage=37,Range=8.14,Cooldown=0.5,HitDelay=0.17,AnimationClass="OneHandSword",ModelId="RustySword"}
table.insert(Catalog.Stock[3], {ItemId="Lumia3Sword",Price=40,DisplayName="Pathfinder Sword",Description="Level 3 MainHand"})
Catalog.Items.Lumia3Hood = {Id="Lumia3Hood",DisplayName="Pathfinder Hood",Type="Armor",SubType="Helmet",Rarity="Uncommon",RequiredLevel=3,GearTier=3,Attack=0,Defense=8,BonusHealth=0,SellValue=7,CanBeDropped=false,}
table.insert(Catalog.Stock[3], {ItemId="Lumia3Hood",Price=21,DisplayName="Pathfinder Hood",Description="Level 3 Head"})
Catalog.Items.Lumia3Vest = {Id="Lumia3Vest",DisplayName="Pathfinder Vest",Type="Armor",SubType="Chest",Rarity="Uncommon",RequiredLevel=3,GearTier=3,Attack=0,Defense=11,BonusHealth=9,SellValue=13,CanBeDropped=false,}
table.insert(Catalog.Stock[3], {ItemId="Lumia3Vest",Price=40,DisplayName="Pathfinder Vest",Description="Level 3 Chest"})
Catalog.Items.Lumia3Gloves = {Id="Lumia3Gloves",DisplayName="Pathfinder Gloves",Type="Armor",SubType="Gloves",Rarity="Uncommon",RequiredLevel=3,GearTier=3,Attack=1,Defense=8,BonusHealth=0,SellValue=6,CanBeDropped=false,}
table.insert(Catalog.Stock[3], {ItemId="Lumia3Gloves",Price=20,DisplayName="Pathfinder Gloves",Description="Level 3 Hands"})
Catalog.Items.Lumia3Leggings = {Id="Lumia3Leggings",DisplayName="Pathfinder Leggings",Type="Armor",SubType="Legs",Rarity="Uncommon",RequiredLevel=3,GearTier=3,Attack=0,Defense=10,BonusHealth=9,SellValue=9,CanBeDropped=false,}
table.insert(Catalog.Stock[3], {ItemId="Lumia3Leggings",Price=29,DisplayName="Pathfinder Leggings",Description="Level 3 Legs"})
Catalog.Items.Lumia3Boots = {Id="Lumia3Boots",DisplayName="Pathfinder Boots",Type="Armor",SubType="Boots",Rarity="Uncommon",RequiredLevel=3,GearTier=3,Attack=0,Defense=8,BonusHealth=0,SellValue=7,CanBeDropped=false,}
table.insert(Catalog.Stock[3], {ItemId="Lumia3Boots",Price=21,DisplayName="Pathfinder Boots",Description="Level 3 Feet"})
Catalog.Items.Lumia3Ward = {Id="Lumia3Ward",DisplayName="Pathfinder Ward",Type="Armor",SubType="Shield",Rarity="Uncommon",RequiredLevel=3,GearTier=3,Attack=0,Defense=9,BonusHealth=0,SellValue=9,CanBeDropped=false,}
table.insert(Catalog.Stock[3], {ItemId="Lumia3Ward",Price=29,DisplayName="Pathfinder Ward",Description="Level 3 OffHand"})
Catalog.Items.Lumia3Band = {Id="Lumia3Band",DisplayName="Pathfinder Band",Type="Armor",SubType="Ring",Rarity="Uncommon",RequiredLevel=3,GearTier=3,Attack=1,Defense=7,BonusHealth=0,SellValue=6,CanBeDropped=false,}
table.insert(Catalog.Stock[3], {ItemId="Lumia3Band",Price=19,DisplayName="Pathfinder Band",Description="Level 3 Ring"})
Catalog.Items.Lumia4Sword = {Id="Lumia4Sword",DisplayName="Thornwatch Sword",Type="Weapon",SubType="OneHandSword",Rarity="Uncommon",RequiredLevel=4,GearTier=4,Attack=8,Defense=0,BonusHealth=0,SellValue=21,CanBeDropped=false,Damage=44,Range=8.32,Cooldown=0.5,HitDelay=0.17,AnimationClass="OneHandSword",ModelId="RustySword"}
table.insert(Catalog.Stock[4], {ItemId="Lumia4Sword",Price=65,DisplayName="Thornwatch Sword",Description="Level 4 MainHand"})
Catalog.Items.Lumia4Hood = {Id="Lumia4Hood",DisplayName="Thornwatch Hood",Type="Armor",SubType="Helmet",Rarity="Uncommon",RequiredLevel=4,GearTier=4,Attack=0,Defense=10,BonusHealth=0,SellValue=10,CanBeDropped=false,}
table.insert(Catalog.Stock[4], {ItemId="Lumia4Hood",Price=30,DisplayName="Thornwatch Hood",Description="Level 4 Head"})
Catalog.Items.Lumia4Vest = {Id="Lumia4Vest",DisplayName="Thornwatch Vest",Type="Armor",SubType="Chest",Rarity="Uncommon",RequiredLevel=4,GearTier=4,Attack=0,Defense=13,BonusHealth=12,SellValue=20,CanBeDropped=false,}
table.insert(Catalog.Stock[4], {ItemId="Lumia4Vest",Price=62,DisplayName="Thornwatch Vest",Description="Level 4 Chest"})
Catalog.Items.Lumia4Gloves = {Id="Lumia4Gloves",DisplayName="Thornwatch Gloves",Type="Armor",SubType="Gloves",Rarity="Uncommon",RequiredLevel=4,GearTier=4,Attack=2,Defense=10,BonusHealth=0,SellValue=9,CanBeDropped=false,}
table.insert(Catalog.Stock[4], {ItemId="Lumia4Gloves",Price=29,DisplayName="Thornwatch Gloves",Description="Level 4 Hands"})
Catalog.Items.Lumia4Leggings = {Id="Lumia4Leggings",DisplayName="Thornwatch Leggings",Type="Armor",SubType="Legs",Rarity="Uncommon",RequiredLevel=4,GearTier=4,Attack=0,Defense=12,BonusHealth=12,SellValue=14,CanBeDropped=false,}
table.insert(Catalog.Stock[4], {ItemId="Lumia4Leggings",Price=43,DisplayName="Thornwatch Leggings",Description="Level 4 Legs"})
Catalog.Items.Lumia4Boots = {Id="Lumia4Boots",DisplayName="Thornwatch Boots",Type="Armor",SubType="Boots",Rarity="Uncommon",RequiredLevel=4,GearTier=4,Attack=0,Defense=10,BonusHealth=0,SellValue=9,CanBeDropped=false,}
table.insert(Catalog.Stock[4], {ItemId="Lumia4Boots",Price=29,DisplayName="Thornwatch Boots",Description="Level 4 Feet"})
Catalog.Items.Lumia4Ward = {Id="Lumia4Ward",DisplayName="Thornwatch Ward",Type="Armor",SubType="Shield",Rarity="Uncommon",RequiredLevel=4,GearTier=4,Attack=0,Defense=11,BonusHealth=0,SellValue=15,CanBeDropped=false,}
table.insert(Catalog.Stock[4], {ItemId="Lumia4Ward",Price=45,DisplayName="Thornwatch Ward",Description="Level 4 OffHand"})
Catalog.Items.Lumia4Band = {Id="Lumia4Band",DisplayName="Thornwatch Band",Type="Armor",SubType="Ring",Rarity="Uncommon",RequiredLevel=4,GearTier=4,Attack=2,Defense=9,BonusHealth=0,SellValue=9,CanBeDropped=false,}
table.insert(Catalog.Stock[4], {ItemId="Lumia4Band",Price=28,DisplayName="Thornwatch Band",Description="Level 4 Ring"})
Catalog.Items.Lumia5Sword = {Id="Lumia5Sword",DisplayName="Gatewarden Sword",Type="Weapon",SubType="OneHandSword",Rarity="Rare",RequiredLevel=5,GearTier=5,Attack=10,Defense=0,BonusHealth=0,SellValue=31,CanBeDropped=false,Damage=51,Range=8.50,Cooldown=0.5,HitDelay=0.17,AnimationClass="OneHandSword",ModelId="RustySword"}
table.insert(Catalog.Stock[5], {ItemId="Lumia5Sword",Price=95,DisplayName="Gatewarden Sword",Description="Level 5 MainHand"})
Catalog.Items.Lumia5Hood = {Id="Lumia5Hood",DisplayName="Gatewarden Hood",Type="Armor",SubType="Helmet",Rarity="Rare",RequiredLevel=5,GearTier=5,Attack=0,Defense=12,BonusHealth=0,SellValue=15,CanBeDropped=false,}
table.insert(Catalog.Stock[5], {ItemId="Lumia5Hood",Price=45,DisplayName="Gatewarden Hood",Description="Level 5 Head"})
Catalog.Items.Lumia5Vest = {Id="Lumia5Vest",DisplayName="Gatewarden Vest",Type="Armor",SubType="Chest",Rarity="Rare",RequiredLevel=5,GearTier=5,Attack=0,Defense=15,BonusHealth=15,SellValue=30,CanBeDropped=false,}
table.insert(Catalog.Stock[5], {ItemId="Lumia5Vest",Price=90,DisplayName="Gatewarden Vest",Description="Level 5 Chest"})
Catalog.Items.Lumia5Gloves = {Id="Lumia5Gloves",DisplayName="Gatewarden Gloves",Type="Armor",SubType="Gloves",Rarity="Rare",RequiredLevel=5,GearTier=5,Attack=3,Defense=12,BonusHealth=0,SellValue=14,CanBeDropped=false,}
table.insert(Catalog.Stock[5], {ItemId="Lumia5Gloves",Price=43,DisplayName="Gatewarden Gloves",Description="Level 5 Hands"})
Catalog.Items.Lumia5Leggings = {Id="Lumia5Leggings",DisplayName="Gatewarden Leggings",Type="Armor",SubType="Legs",Rarity="Rare",RequiredLevel=5,GearTier=5,Attack=0,Defense=14,BonusHealth=15,SellValue=21,CanBeDropped=false,}
table.insert(Catalog.Stock[5], {ItemId="Lumia5Leggings",Price=63,DisplayName="Gatewarden Leggings",Description="Level 5 Legs"})
Catalog.Items.Lumia5Boots = {Id="Lumia5Boots",DisplayName="Gatewarden Boots",Type="Armor",SubType="Boots",Rarity="Rare",RequiredLevel=5,GearTier=5,Attack=0,Defense=12,BonusHealth=0,SellValue=14,CanBeDropped=false,}
table.insert(Catalog.Stock[5], {ItemId="Lumia5Boots",Price=43,DisplayName="Gatewarden Boots",Description="Level 5 Feet"})
Catalog.Items.Lumia5Ward = {Id="Lumia5Ward",DisplayName="Gatewarden Ward",Type="Armor",SubType="Shield",Rarity="Rare",RequiredLevel=5,GearTier=5,Attack=0,Defense=13,BonusHealth=0,SellValue=22,CanBeDropped=false,}
table.insert(Catalog.Stock[5], {ItemId="Lumia5Ward",Price=66,DisplayName="Gatewarden Ward",Description="Level 5 OffHand"})
Catalog.Items.Lumia5Band = {Id="Lumia5Band",DisplayName="Gatewarden Band",Type="Armor",SubType="Ring",Rarity="Rare",RequiredLevel=5,GearTier=5,Attack=3,Defense=11,BonusHealth=0,SellValue=14,CanBeDropped=false,}
table.insert(Catalog.Stock[5], {ItemId="Lumia5Band",Price=42,DisplayName="Gatewarden Band",Description="Level 5 Ring"})

function Catalog.GetStock(level)
    local result = {}
    for _, item in ipairs(Catalog.Stock[math.clamp(math.floor(level), 1, 5)] or {}) do
        table.insert(result, table.clone(item))
    end
    return result
end
return Catalog
