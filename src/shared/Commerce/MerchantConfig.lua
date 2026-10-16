-- Lumia V17 - shop inventory is chosen by current player level (1-3).
-- NPCs in the two outer regions use their own tier-locked catalogs.
local GearCatalog = require(script.Parent:WaitForChild("GearCatalog"))
local Config = {
    MerchantName = "Mira the Trader",
    InteractionRange = 15,
    MaxStackPurchase = 1,
    MaxGold = 2000000000,
    MaxTier = 3,
    BuyItems = GearCatalog.GetStock(1),
}
function Config.GetStock(level)
    local selected = math.clamp(math.floor(tonumber(level) or 1), 1, Config.MaxTier)
    local items = GearCatalog.GetStock(selected)
    table.insert(items, {ItemId="FieldPotion", Price=12, DisplayName="Herbal Restorative",Description="Restores 35 health"})
    return items
end
return Config
