-- REALMS OF ETERNIA
-- ETERNIA BAG - STEP 11N
-- Compact, movable, eight-slot RPG inventory.

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local eternia = ReplicatedStorage:WaitForChild("Eternia")
local ItemIcons = require(
    eternia:WaitForChild("Shared"):WaitForChild("ItemIcons")
)
local ItemTooltip = require(
    script.Parent:WaitForChild("CharacterUI"):WaitForChild("ItemTooltip")
)
local network = eternia:WaitForChild("InventoryNetwork")
local request = network:WaitForChild("GetInventory")

local gui = Instance.new("ScreenGui")
gui.Name = "EterniaBag"
gui.ResetOnSpawn = false
gui.DisplayOrder = 20
gui.Parent = player:WaitForChild("PlayerGui")

local window = Instance.new("Frame")
window.Name = "Window"
window.Size = UDim2.fromOffset(250, 188)
window.Position = UDim2.new(0.5, -125, 0.5, -94)
window.BackgroundColor3 = Color3.fromRGB(24, 22, 22)
window.BorderSizePixel = 0
window.Visible = false
window.Parent = gui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 7)
corner.Parent = window

local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(110, 87, 54)
stroke.Thickness = 2
stroke.Parent = window

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -40, 0, 30)
title.Position = UDim2.fromOffset(12, 5)
title.BackgroundTransparency = 1
title.Text = "ADVENTURER'S BAG"
title.TextColor3 = Color3.fromRGB(224, 194, 130)
title.TextSize = 14
title.Font = Enum.Font.GothamBold
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = window

local close = Instance.new("TextButton")
close.Size = UDim2.fromOffset(25, 25)
close.Position = UDim2.new(1, -31, 0, 7)
close.Text = "X"
close.Font = Enum.Font.GothamBold
close.TextSize = 13
close.TextColor3 = Color3.fromRGB(230, 215, 190)
close.BackgroundColor3 = Color3.fromRGB(58, 43, 39)
close.Parent = window
Instance.new("UICorner", close).CornerRadius = UDim.new(0, 4)

local slots = {}
local renderVersion = 0

for index = 1, 8 do
    local column = (index - 1) % 4
    local row = math.floor((index - 1) / 4)

    local slot = Instance.new("Frame")
    slot.Name = "Slot" .. index
    slot.Size = UDim2.fromOffset(49, 49)
    slot.Position = UDim2.fromOffset(13 + column * 57, 42 + row * 57)
    slot.BackgroundColor3 = Color3.fromRGB(37, 35, 33)
    slot.BorderSizePixel = 0
    slot.Parent = window
    Instance.new("UICorner", slot).CornerRadius = UDim.new(0, 4)

    local border = Instance.new("UIStroke")
    border.Thickness = 1
            border.Color = Color3.fromRGB(79, 69, 54)
    border.Parent = slot

    local number = Instance.new("TextLabel")
    number.Name = "Number"
    number.Size = UDim2.fromScale(1, 1)
    number.BackgroundTransparency = 1
    number.Text = tostring(index)
    number.TextColor3 = Color3.fromRGB(78, 73, 68)
    number.TextSize = 12
    number.Font = Enum.Font.Gotham
    number.Parent = slot

    slots[index] = slot
end

local footer = Instance.new("TextLabel")
footer.Size = UDim2.new(1, -20, 0, 20)
footer.Position = UDim2.fromOffset(10, 159)
footer.BackgroundTransparency = 1
footer.Text = "0 / 8 slots"
footer.TextColor3 = Color3.fromRGB(167, 153, 126)
footer.TextSize = 11
footer.Font = Enum.Font.Gotham
footer.Parent = window

-- Share the same polished mouseover UI as the character sheet.
local tooltip = ItemTooltip.new(gui)
local slotItems = {}
local hoveredIndex = nil

local function clearSlot(slot)
    for _, child in ipairs(slot:GetChildren()) do
        if child.Name == "ItemVisual" or child.Name == "Quantity" then
            child:Destroy()
        end
    end
    slot.Number.Visible = true
end

local function addPreview(slot, item)
    local imageId, symbol = ItemIcons.Resolve(item)

    if imageId then
        local image = Instance.new("ImageLabel")
        image.Name = "ItemVisual"
        image.Size = UDim2.fromScale(0.85, 0.85)
        image.Position = UDim2.fromScale(0.075, 0.075)
        image.BackgroundTransparency = 1
        image.ScaleType = Enum.ScaleType.Fit
        image.Image = imageId
        image.Parent = slot
    else
        local label = Instance.new("TextLabel")
        label.Name = "ItemVisual"
        label.Size = UDim2.fromScale(1, 1)
        label.BackgroundTransparency = 1
        label.Text = symbol or "?"
        label.TextColor3 = Color3.fromRGB(211, 188, 139)
        label.TextSize = 29
        label.Font = Enum.Font.GothamBold
        label.TextScaled = false
        label.Parent = slot
    end
end
local rarityColors = {
    Common = Color3.fromRGB(140, 132, 118),
    Uncommon = Color3.fromRGB(65, 170, 90),
    Rare = Color3.fromRGB(70, 125, 230),
    Epic = Color3.fromRGB(165, 80, 215),
    Legendary = Color3.fromRGB(230, 150, 35),
}

local function render(items)
    if not window.Visible then return end
    renderVersion += 1

    for index, slot in ipairs(slots) do
        clearSlot(slot)
        local item = items[index]
        slotItems[index] = item
        local border = slot:FindFirstChildOfClass("UIStroke")

        if item then
            slot.Number.Visible = false
            border.Thickness = 3
            border.Color = rarityColors[item.Rarity]
                or rarityColors.Common

            addPreview(slot, item)

            if (item.Quantity or 1) > 1 then
                local quantity = Instance.new("TextLabel")
                quantity.Name = "Quantity"
                quantity.Size = UDim2.fromOffset(28, 15)
                quantity.Position = UDim2.new(1, -30, 1, -17)
                quantity.BackgroundTransparency = 1
                quantity.Text = tostring(item.Quantity)
                quantity.TextColor3 = Color3.new(1, 1, 1)
                quantity.TextStrokeTransparency = 0.2
                quantity.TextSize = 12
                quantity.Font = Enum.Font.GothamBold
                quantity.ZIndex = 5
                quantity.Parent = slot
            end

        else
            border.Thickness = 1
            border.Color = Color3.fromRGB(79, 69, 54)
        end
    end

    footer.Text = tostring(#items) .. " / 8 slots"

    if hoveredIndex and slotItems[hoveredIndex] then
        tooltip:Show(slotItems[hoveredIndex])
    else
        tooltip:Hide()
    end
end

for index, slot in ipairs(slots) do
    slot.MouseEnter:Connect(function()
        hoveredIndex = index
        if slotItems[index] then
            tooltip:Show(slotItems[index])
        end
    end)
    slot.MouseLeave:Connect(function()
        if hoveredIndex == index then
            hoveredIndex = nil
        end
        tooltip:Hide()
    end)
end

-- Drag window by its title bar.
local dragging = false
local dragStart
local originalPosition

title.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = true
        dragStart = input.Position
        originalPosition = window.Position
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
        local delta = input.Position - dragStart
        window.Position = UDim2.new(
            originalPosition.X.Scale, originalPosition.X.Offset + delta.X,
            originalPosition.Y.Scale, originalPosition.Y.Offset + delta.Y
        )
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = false
    end
end)

local refreshing = false
local function refresh()
    if refreshing or not window.Visible then return end
    refreshing = true
    local success, items = pcall(function()
        return request:InvokeServer()
    end)
    refreshing = false

    if success and type(items) == "table" then
        render(items)
    end
end

local function toggle()
    window.Visible = not window.Visible
    tooltip:Hide()
    hoveredIndex = nil
    if window.Visible then
        task.spawn(refresh)
    end
end

close.MouseButton1Click:Connect(toggle)

UserInputService.InputBegan:Connect(function(input, processed)
    if processed or UserInputService:GetFocusedTextBox() then return end
    if input.KeyCode == Enum.KeyCode.B then
        toggle()
    end
end)

task.spawn(function()
    while gui.Parent do
        task.wait(2)
        if window.Visible then
            refresh()
        end
    end
end)

print("[Eternia] EterniaBag controller ready - Press B")
