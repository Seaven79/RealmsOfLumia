-- Realms of Eternia - Step 13.1
-- Eight display-only equipment slots. No equip/unequip requests in this step.
local Theme = require(script.Parent:WaitForChild("CharacterTheme"))

local EquipmentSlots = {}
EquipmentSlots.__index = EquipmentSlots

EquipmentSlots.Definitions = {
    { Key = "Head", Label = "Head", Icon = "H" },
    { Key = "Chest", Label = "Chest", Icon = "C" },
    { Key = "Hands", Label = "Hands", Icon = "G" },
    { Key = "Legs", Label = "Legs", Icon = "L" },
    { Key = "Feet", Label = "Feet", Icon = "F" },
    { Key = "MainHand", Label = "Main Hand", Icon = "W" },
    { Key = "OffHand", Label = "Off Hand", Icon = "S" },
    { Key = "Ring", Label = "Ring", Icon = "R" },
}

local function textLabel(parent, name, x, y, width, height, value, font, size, color)
    local label = Instance.new("TextLabel")
    label.Name = name
    label.Position = UDim2.fromOffset(x, y)
    label.Size = UDim2.fromOffset(width, height)
    label.BackgroundTransparency = 1
    label.Text = value
    label.Font = font
    label.TextSize = size
    label.TextColor3 = color
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.TextTruncate = Enum.TextTruncate.AtEnd
    label.ZIndex = 5
    label.Parent = parent
    return label
end

function EquipmentSlots.new(parent, tooltip)
    local self = setmetatable({ Widgets = {} }, EquipmentSlots)

    for index, definition in ipairs(EquipmentSlots.Definitions) do
        local column = (index - 1) % 2
        local row = math.floor((index - 1) / 2)
        local slot = Instance.new("Frame")
        slot.Name = definition.Key .. "Slot"
        slot.Position = UDim2.fromOffset(
            column * (Theme.SlotWidth + Theme.SlotGap),
            row * (Theme.SlotHeight + Theme.SlotGap)
        )
        slot.Size = UDim2.fromOffset(Theme.SlotWidth, Theme.SlotHeight)
        slot.BackgroundColor3 = Theme.Slot
        slot.BorderSizePixel = 0
        slot.Active = true
        slot.ZIndex = 3
        slot.Parent = parent
        Instance.new("UICorner", slot).CornerRadius = UDim.new(0, 6)

        local border = Instance.new("UIStroke")
        border.Name = "SlotBorder"
        border.Color = Theme.Border
        border.Thickness = 1
        border.Parent = slot

        local icon = Instance.new("Frame")
        icon.Name = "SlotIcon"
        icon.Size = UDim2.fromOffset(32, 32)
        icon.Position = UDim2.fromOffset(9, 9)
        icon.BackgroundColor3 = Theme.Panel
        icon.BorderSizePixel = 0
        icon.ZIndex = 4
        icon.Parent = slot
        Instance.new("UICorner", icon).CornerRadius = UDim.new(0, 5)
        local glyph = textLabel(icon, "Glyph", 0, 0, 32, 32,
            definition.Icon, Enum.Font.GothamBold, 14, Theme.Gold)
        glyph.TextXAlignment = Enum.TextXAlignment.Center

        textLabel(slot, "SlotTitle", 48, 5, 240, 18,
            definition.Label, Enum.Font.GothamBold, 12, Theme.Secondary)
        local itemText = textLabel(slot, "ItemName", 48, 24, 240, 20,
            "Empty", Enum.Font.Gotham, 12, Theme.Muted)

        local widget = { Frame = slot, Border = border, ItemText = itemText, Item = nil }
        self.Widgets[definition.Key] = widget

        slot.MouseEnter:Connect(function()
            if widget.Item then
                tooltip:Show(widget.Item)
            end
        end)
        slot.MouseLeave:Connect(function()
            tooltip:Hide()
        end)
    end

    return self
end

function EquipmentSlots:Update(equipment)
    equipment = type(equipment) == "table" and equipment or {}
    for _, definition in ipairs(EquipmentSlots.Definitions) do
        local widget = self.Widgets[definition.Key]
        local item = equipment[definition.Key]
        if type(item) == "table" and type(item.ItemId) == "string" then
            widget.Item = item
            widget.ItemText.Text = tostring(item.DisplayName or item.ItemId)
            local rarity = tostring(item.Rarity or "Common")
            widget.ItemText.TextColor3 = Theme.RarityColors[rarity] or Theme.White
            -- Gold outline matches the approved equipped-slot design.
            widget.Border.Color = Theme.Gold
            widget.Border.Thickness = 2
        else
            widget.Item = nil
            widget.ItemText.Text = "Empty"
            widget.ItemText.TextColor3 = Theme.Muted
            widget.Border.Color = Theme.Border
            widget.Border.Thickness = 1
        end
    end
end

return EquipmentSlots
