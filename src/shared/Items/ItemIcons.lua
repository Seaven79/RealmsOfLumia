local ItemIcons = {}

-- Default category images
ItemIcons.DefaultImages = {
    Weapon = "rbxassetid://84219802960571",
}

-- Symbol fallbacks
ItemIcons.Categories = {
    Weapon = { Symbol = "⚔", Label = "Weapon" },
    Armor = { Symbol = "◆", Label = "Armor" },
    Potion = { Symbol = "✚", Label = "Potion" },
    Consumable = { Symbol = "✚", Label = "Consumable" },
    Material = { Symbol = "✦", Label = "Material" },
    Food = { Symbol = "●", Label = "Food" },
    Quest = { Symbol = "✉", Label = "Quest Item" },
}

ItemIcons.Default = {
    Symbol = "?",
    Label = "Item",
}

function ItemIcons.Resolve(item)
    if type(item) ~= "table" then
        return nil, ItemIcons.Default.Symbol
    end

    -- Priority 1: Unique item image
    if type(item.IconId) == "string" and item.IconId ~= "" then
        return item.IconId, nil
    end

    -- Priority 2: Category image
    local defaultImage = ItemIcons.DefaultImages[item.Type]

    if defaultImage then
        return defaultImage, nil
    end

    -- Priority 3: Symbol
    local category = ItemIcons.Categories[item.Type]
        or ItemIcons.Default

    return nil, category.Symbol
end

return ItemIcons