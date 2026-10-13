-- REALMS OF ETERNIA - STEP 13.2 DRAG & DROP
-- Approved layout is preserved: EXACTLY two columns of 300 x 51 slots.
-- Equipped item icons share ItemIcons.Resolve() with the original bag.
-- Clicking a slot does nothing. Drag an equipped item to an empty bag slot.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Theme = require(script.Parent:WaitForChild("CharacterTheme"))
local ItemIcons = require(ReplicatedStorage:WaitForChild("Eternia")
    :WaitForChild("Shared"):WaitForChild("ItemIcons"))
local DragDrop = require(script.Parent:WaitForChild("EquipmentDragDrop"))

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
        local slot = Instance.new("TextButton")
        slot.Text = ""
        slot.AutoButtonColor = false
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
        local itemImage = Instance.new("ImageLabel")
        itemImage.Name = "EquippedItemImage"
        itemImage.Size = UDim2.fromOffset(30, 30)
        itemImage.Position = UDim2.fromOffset(1, 1)
        itemImage.BackgroundTransparency = 1
        itemImage.ScaleType = Enum.ScaleType.Fit
        itemImage.Visible = false
        itemImage.ZIndex = 6
        itemImage.Parent = icon

        textLabel(slot, "SlotTitle", 48, 5, 240, 18,
            definition.Label, Enum.Font.GothamBold, 12, Theme.Secondary)
        local itemText = textLabel(slot, "ItemName", 48, 24, 240, 20,
            "Empty", Enum.Font.Gotham, 12, Theme.Muted)

        local widget = {
            Frame = slot, Border = border, ItemText = itemText,
            Image = itemImage, Glyph = glyph, Item = nil,
        }
        self.Widgets[definition.Key] = widget

        slot.MouseEnter:Connect(function()
            if widget.Item and not DragDrop.IsDragging() then
                tooltip:Show(widget.Item)
            end
        end)
        slot.MouseLeave:Connect(function()
            tooltip:Hide()
        end)
        DragDrop.RegisterSlot(slot, "Equipment", function()
            return widget.Item
        end, definition.Key)

        -- Mirror the bag: while dragging equipment out, keep only the
        -- moving icon under the pointer. Restore it on release/cancel.
        local function setEquippedVisible(visible)
            widget.ItemText.Visible = visible
            if widget.Item then
                widget.Image.Visible = visible and widget.Image.Image ~= ""
                widget.Glyph.Visible = visible and widget.Image.Image == ""
            end
        end
        DragDrop.Started:Connect(function(kind, sourceFrame)
            if kind == "Equipment" and sourceFrame == slot then
                setEquippedVisible(false)
            end
        end)
        DragDrop.Finished:Connect(function(kind, sourceFrame)
            if kind == "Equipment" and sourceFrame == slot then
                setEquippedVisible(true)
            end
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
            widget.Border.Color = Theme.Gold
            widget.Border.Thickness = 2
            local imageId, symbol = ItemIcons.Resolve(item)
            widget.Image.Image = imageId or ""
            widget.Image.Visible = imageId ~= nil
            widget.Glyph.Visible = imageId == nil
            widget.Glyph.Text = symbol or definition.Icon
            widget.Glyph.TextColor3 = Theme.RarityColors[rarity] or Theme.Gold
            if DragDrop.IsDraggingSource(widget.Frame) then
                widget.Image.Visible = false
                widget.Glyph.Visible = false
                widget.ItemText.Visible = false
            else
                widget.ItemText.Visible = true
            end
        else
            widget.Item = nil
            widget.ItemText.Visible = true
            widget.ItemText.Text = "Empty"
            widget.ItemText.TextColor3 = Theme.Muted
            widget.Border.Color = Theme.Border
            widget.Border.Thickness = 1
            widget.Image.Visible = false
            widget.Image.Image = ""
            widget.Glyph.Visible = true
            widget.Glyph.Text = definition.Icon
            widget.Glyph.TextColor3 = Theme.Gold
        end
    end
end

return EquipmentSlots
