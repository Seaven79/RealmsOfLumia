-- Realms of Eternia - Step 13.1
-- Reusable floating item tooltip, shared by Character Sheet and Adventurer's Bag.
-- Uses public ItemDefinitions for display; never changes an item or its stats.
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Theme = require(script.Parent:WaitForChild("CharacterTheme"))
local ItemDefinitions = require(
    ReplicatedStorage:WaitForChild("Eternia")
        :WaitForChild("Shared"):WaitForChild("ItemDefinitions")
)

local ItemTooltip = {}
ItemTooltip.__index = ItemTooltip

local function rounded(object, radius)
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, radius)
    corner.Parent = object
end

local function makeLabel(parent, text, x, y, width, height, fontSize, color, bold)
    local label = Instance.new("TextLabel")
    label.Name = "TooltipContent"
    label.Position = UDim2.fromOffset(x, y)
    label.Size = UDim2.fromOffset(width, height)
    label.BackgroundTransparency = 1
    label.Font = bold and Enum.Font.GothamBold or Enum.Font.Gotham
    label.TextSize = fontSize
    label.TextColor3 = color
    label.Text = tostring(text)
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.TextYAlignment = Enum.TextYAlignment.Center
    label.TextTruncate = Enum.TextTruncate.AtEnd
    label.ZIndex = 113
    label.Parent = parent
    return label
end

local function getField(item, definition, key)
    if item[key] ~= nil then
        return item[key]
    end
    return definition[key]
end

function ItemTooltip.new(screenGui)
    local self = setmetatable({}, ItemTooltip)
    local frame = Instance.new("Frame")
    frame.Name = "EterniaItemTooltip"
    frame.Size = UDim2.fromOffset(315, 156)
    frame.BackgroundColor3 = Theme.TooltipBackground
    frame.BorderSizePixel = 0
    frame.ZIndex = 110
    frame.Visible = false
    frame.Parent = screenGui
    rounded(frame, 7)

    local border = Instance.new("UIStroke")
    border.Name = "RarityBorder"
    border.Color = Theme.Border
    border.Thickness = 1.5
    border.Parent = frame

    self.Frame = frame
    self.ScreenGui = screenGui
    self._connection = RunService.RenderStepped:Connect(function()
        if self.Frame.Visible then
            self:UpdatePosition()
        end
    end)
    return self
end

function ItemTooltip:IsVisible()
    return self.Frame.Visible
end

function ItemTooltip:Hide()
    self.Frame.Visible = false
end

function ItemTooltip:UpdatePosition()
    local mouse = UserInputService:GetMouseLocation()
    if not self.ScreenGui.IgnoreGuiInset then
        local topLeft = GuiService:GetGuiInset()
        mouse -= topLeft
    end
    local screen = self.ScreenGui.AbsoluteSize
    local width = self.Frame.AbsoluteSize.X
    local height = self.Frame.AbsoluteSize.Y
    local x = mouse.X + 18
    local y = mouse.Y + 18

    if x + width > screen.X - 8 then
        x = mouse.X - width - 18
    end
    if y + height > screen.Y - 8 then
        y = mouse.Y - height - 18
    end

    self.Frame.Position = UDim2.fromOffset(
        math.clamp(x, 8, math.max(8, screen.X - width - 8)),
        math.clamp(y, 8, math.max(8, screen.Y - height - 8))
    )
end

function ItemTooltip:Show(item)
    if type(item) ~= "table" or type(item.ItemId) ~= "string" then
        self:Hide()
        return
    end

    local definition = ItemDefinitions.Get(item.ItemId) or {}
    local rarity = tostring(getField(item, definition, "Rarity") or "Common")
    local rarityColor = Theme.RarityColors[rarity] or Theme.RarityColors.Common
    local name = getField(item, definition, "DisplayName") or item.ItemId
    local itemType = tostring(getField(item, definition, "Type") or "Item")
    local subType = getField(item, definition, "SubType")
    local detailType = itemType
    if type(subType) == "string" and subType ~= "" then
        detailType = detailType .. " / " .. subType
    end

    for _, child in ipairs(self.Frame:GetChildren()) do
        if child.Name == "TooltipContent" then
            child:Destroy()
        end
    end

    self.Frame.RarityBorder.Color = rarityColor
    makeLabel(self.Frame, name, 15, 12, 285, 24, 16, rarityColor, true)
    makeLabel(self.Frame, detailType, 15, 36, 285, 19, 12, Theme.Secondary, false)
    local currentY = 62
    makeLabel(self.Frame, rarity .. " item", 15, currentY, 285, 19, 12, rarityColor, true)
    currentY += 25

    local separator = Instance.new("Frame")
    separator.Name = "TooltipContent"
    separator.Position = UDim2.fromOffset(15, currentY)
    separator.Size = UDim2.fromOffset(285, 1)
    separator.BackgroundColor3 = Theme.Border
    separator.BorderSizePixel = 0
    separator.ZIndex = 113
    separator.Parent = self.Frame
    currentY += 10

    local damage = getField(item, definition, "Damage")
    if type(damage) == "number" then
        makeLabel(self.Frame, "Damage  " .. tostring(damage), 15, currentY, 285, 20, 13, Theme.White, true)
        currentY += 22
    end

    local cooldown = getField(item, definition, "Cooldown")
    if type(cooldown) == "number" then
        makeLabel(self.Frame, "Attack interval  " .. tostring(cooldown) .. "s", 15, currentY, 285, 19, 12, Theme.Secondary, false)
        currentY += 21
    end

    -- Optional future item modifiers. These are only displayed if defined.
    local modifiers = definition.Bonuses or definition.StatBonuses
    if type(modifiers) == "table" then
        for _, stat in ipairs({ "Strength", "Agility", "Intelligence", "Vitality" }) do
            local amount = modifiers[stat]
            if type(amount) == "number" and amount ~= 0 then
                local prefix = amount > 0 and "+" or ""
                makeLabel(self.Frame, prefix .. tostring(amount) .. " " .. stat, 15, currentY, 285, 19, 12, Theme.Green, true)
                currentY += 21
            end
        end
    end

    local level = getField(item, definition, "RequiredLevel")
    if type(level) == "number" then
        makeLabel(self.Frame, "Requires level " .. tostring(level), 15, currentY + 1, 285, 19, 12, Theme.White, false)
        currentY += 24
    end

    local flavor = getField(item, definition, "FlavorText") or getField(item, definition, "Description")
    if type(flavor) == "string" and flavor ~= "" then
        local description = makeLabel(self.Frame, flavor, 15, currentY + 3, 285, 43, 12, Theme.Muted, false)
        description.TextWrapped = true
        description.TextTruncate = Enum.TextTruncate.None
        description.TextYAlignment = Enum.TextYAlignment.Top
        currentY += 49
    end

    if getField(item, definition, "CanBeDropped") == false then
        makeLabel(self.Frame, "Cannot be dropped", 15, currentY + 1, 285, 19, 12, Theme.Gold, false)
        currentY += 24
    end

    self.Frame.Size = UDim2.fromOffset(315, math.max(120, currentY + 9))
    self.Frame.Visible = true
    self:UpdatePosition()
end

function ItemTooltip:Destroy()
    if self._connection then
        self._connection:Disconnect()
        self._connection = nil
    end
    self.Frame:Destroy()
end

return ItemTooltip
