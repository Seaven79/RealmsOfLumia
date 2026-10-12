-- REALMS OF ETERNIA
-- ITEM FACTORY
-- Creates physical items from reusable templates.
-- Item stats remain in ItemDefinitions.

local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ItemDefinitions = require(
    ReplicatedStorage
        :WaitForChild("Eternia")
        :WaitForChild("Shared")
        :WaitForChild("ItemDefinitions")
)

local ItemFactory = {}

local function getModelsFolder()
    local assets = ServerStorage:FindFirstChild("EterniaAssets")
    if not assets then
        warn("[Eternia] Missing EterniaAssets")
        return nil
    end

    return assets:FindFirstChild("Items")
end

function ItemFactory.Create(itemId)
    local definition = ItemDefinitions.Get(itemId)

    if not definition then
        warn("[Eternia] Unknown item: " .. tostring(itemId))
        return nil
    end

    local modelsFolder = getModelsFolder()

    if not modelsFolder then
        warn("[Eternia] Item model folder not installed yet")
        return nil
    end

    local template = modelsFolder:FindFirstChild(
        definition.ModelId
    )

    if not template then
        warn(
            "[Eternia] Missing item model: "
                .. tostring(definition.ModelId)
        )
        return nil
    end

    if not template:IsA("Tool") then
        warn("[Eternia] Item template must be a Tool")
        return nil
    end

    local item = template:Clone()

    item.Name = definition.DisplayName

    item:SetAttribute("ItemId", itemId)
    item:SetAttribute("ItemType", definition.Type)
    item:SetAttribute("ItemSubType", definition.SubType)
    item:SetAttribute("Rarity", definition.Rarity)
    item:SetAttribute(
        "RequiredLevel",
        definition.RequiredLevel
    )

    item.CanBeDropped = definition.CanBeDropped == true

    return item
end

return ItemFactory