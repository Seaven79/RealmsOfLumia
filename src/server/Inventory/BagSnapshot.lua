-- REALMS OF LUMIA - Shared server-side bag snapshot formatter.
-- No client-supplied item metadata is trusted; all display info is looked up.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ItemDefinitions = require(ReplicatedStorage:WaitForChild("Lumia")
    :WaitForChild("Shared"):WaitForChild("Items"):WaitForChild("ItemDefinitions"))
local InventoryService = require(script.Parent:WaitForChild("InventoryService"))
local PlayerDataService = require(script.Parent.Parent:WaitForChild("Players"):WaitForChild("PlayerDataService"))

local BagSnapshot = {}
function BagSnapshot.PublicItem(record)
    if type(record) ~= "table" then return nil end
    local definition = ItemDefinitions.Get(record.ItemId)
    if not definition then return nil end
    return {
        ItemId = record.ItemId,
        InstanceId = record.InstanceId,
        BagId = record.BagId,
        BagSlot = record.BagSlot,
        DisplayName = definition.DisplayName,
        Quantity = record.Quantity,
        Rarity = definition.Rarity,
        Type = definition.Type,
        SubType = definition.SubType,
        Damage = definition.Damage,
        Cooldown = definition.Cooldown,
        RequiredLevel = definition.RequiredLevel,
        IconId = definition.IconId,
        ModelId = definition.ModelId,
    }
end

function BagSnapshot.Build(player)
    local records = InventoryService:GetBagItems(player)
    local bags = InventoryService:GetBags(player)
    if not records or not bags then return nil end
    local items = {}
    for _, record in ipairs(records) do
        local public = BagSnapshot.PublicItem(record)
        if public then table.insert(items, public) end
    end
    local profile = PlayerDataService:GetProfile(player)
    local settings = profile and profile.Settings or {}
    return {
        Items = items,
        Bags = bags,
        ViewMode = settings.BagViewMode == "all" and "all" or "selected",
        SelectedBagId = type(settings.SelectedBagId) == "number"
            and math.clamp(math.floor(settings.SelectedBagId), 1, 5) or 1,
    }
end
return BagSnapshot
