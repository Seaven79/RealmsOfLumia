-- Realms of Lumia - Step 13.1
-- Reusable floating item tooltip, shared by Character Sheet and Adventurer's Bag.
-- Uses public ItemDefinitions for display; never changes an item or its stats.
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Theme = require(script.Parent:WaitForChild("CharacterTheme"))
local ItemDefinitions = require(
    ReplicatedStorage:WaitForChild("Lumia")
        :WaitForChild("Shared"):WaitForChild("Items"):WaitForChild("ItemDefinitions")
)

local Currency = require(ReplicatedStorage:WaitForChild("Lumia")
    :WaitForChild("Shared"):WaitForChild("Commerce"):WaitForChild("LumiaCurrency"))
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
    frame.Name = "LumiaItemTooltip"
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

-- Supply a function(itemId) that returns the item currently occupying the
-- matching equipment slot, or nil when nothing is equipped. Comparison then
-- works in every window that uses this tooltip, without the tooltip needing to
-- know where equipment lives.
function ItemTooltip:SetComparisonProvider(provider)
    self._comparisonProvider = (type(provider) == "function") and provider or nil
end

local function shiftHeld()
    return UserInputService:IsKeyDown(Enum.KeyCode.LeftShift)
        or UserInputService:IsKeyDown(Enum.KeyCode.RightShift)
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

    for _,entry in ipairs({
        {"Attack", "+%d Attack"}, {"Defense", "+%d Defense"},
        {"BonusHealth", "+%d Maximum HP"},
    }) do
        local amount=getField(item,definition,entry[1])
        if type(amount)=="number" and amount>0 then
            makeLabel(self.Frame,string.format(entry[2],amount),15,currentY,285,19,12,Theme.Green,true)
            currentY += 21
        end
    end

    -- Comparison with the equipped item in the same slot (hold Shift).
    -- The provider returns { Slot = ..., Equipped = item or nil }. A known slot
    -- with nothing equipped still compares, so the player sees what buying the
    -- item would actually add.
    local provider = self._comparisonProvider
    if provider then
        local comparison = provider(item.ItemId)
        if type(comparison) == "table" then
            if shiftHeld() then
                currentY = self:_drawComparison(item, definition, comparison, currentY)
            else
                makeLabel(self.Frame, "Hold Shift to compare with equipped",
                    15, currentY, 285, 17, 11, Theme.Muted, false)
                currentY += 19
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

    if type(item.Quantity)=="number" and item.Quantity>1 then
        makeLabel(self.Frame,"Stack: "..tostring(item.Quantity),15,currentY,285,19,12,Theme.Secondary,false)
        currentY+=22
    end
    if type(item.StoreBuyPrice)=="number" then
        makeLabel(self.Frame,"Purchase: "..Currency.FormatShort(item.StoreBuyPrice),
            15,currentY,285,23,12,Theme.Gold,true)
        currentY+=25
    end
    local resale=item.StoreSellPrice
    if resale==nil then resale=definition.SellValue end
    if type(resale)=="number" and resale>0 then
        makeLabel(self.Frame,"Merchant pays: "..Currency.FormatShort(resale),
            15,currentY,285,23,12,Theme.Gold,false)
        currentY+=25
    elseif itemType=="Quest" or definition.QuestItem==true then
        makeLabel(self.Frame,"Quest item - cannot be sold",15,currentY,285,22,12,Theme.Gold,true)
        currentY+=24
    end

    if getField(item, definition, "CanBeDropped") == false then
        makeLabel(self.Frame, "Cannot be dropped", 15, currentY + 1, 285, 19, 12, Theme.Gold, false)
        currentY += 24
    end

    self.Frame.Size = UDim2.fromOffset(315, math.max(120, currentY + 9))
    self.Frame.Visible = true
    self:UpdatePosition()
end

-- Draw the "equipped vs hovered" block. Returns the new Y cursor.
-- Values are read through getField so instance overrides win, exactly like the
-- stat rows above. Lower is better for attack interval, higher for the rest.
--
-- Colour rules:
--   better  -> green
--   worse   -> red
--   same    -> white (neutral). Green means "an upgrade" and must never be used
--              for an unchanged stat, or the colour stops carrying information.
--   empty slot -> every added stat is a gain, so nothing is red.
function ItemTooltip:_drawComparison(item, definition, comparison, startY)
    local y = startY
    local isEmpty = type(comparison.Equipped) ~= "table"
    -- An empty slot has no record to read from; an empty table keeps getField
    -- total instead of indexing nil.
    local equipped = isEmpty and {} or comparison.Equipped
    local equippedDef = isEmpty and {} or (ItemDefinitions.Get(equipped.ItemId) or {})

    y += 8
    local separator = Instance.new("Frame")
    separator.Name = "TooltipContent"
    separator.Position = UDim2.fromOffset(15, y)
    separator.Size = UDim2.fromOffset(285, 1)
    separator.BackgroundColor3 = Theme.Border
    separator.BorderSizePixel = 0
    separator.ZIndex = 113
    separator.Parent = self.Frame
    y += 10

    -- Block layout:
    --   NEW ITEM      / <hovered item name>
    --   IF EQUIPPED   / <equipped item name, or nothing>
    --   <stat changes>
    local newName = getField(item, definition, "DisplayName") or item.ItemId
    local newRarity = tostring(getField(item, definition, "Rarity") or "Common")
    local newColor = Theme.RarityColors[newRarity] or Theme.RarityColors.Common

    makeLabel(self.Frame, "NEW ITEM", 15, y, 285, 14, 11, Theme.Muted, true)
    y += 15
    makeLabel(self.Frame, newName, 15, y, 285, 21, 16, newColor, true)
    y += 24

    makeLabel(self.Frame, "IF EQUIPPED", 15, y, 285, 14, 11, Theme.Muted, true)
    y += 16
    if isEmpty then
        -- No item name here: the equipped piece is unnamed by design, but the
        -- slot state still needs to be stated or the 0 -> N rows look broken.
        local slotName = tostring(comparison.Slot or "slot")
        slotName = slotName:gsub("(%l)(%u)", "%1 %2")
        makeLabel(self.Frame, "Nothing equipped in the " .. slotName:lower() .. " slot",
            15, y, 285, 18, 12, Theme.Muted, false)
        y += 20
    else
        y += 4
    end

    local rows = {
        { Label = "Damage", Key = "Damage", HigherIsBetter = true },
        { Label = "Attack", Key = "Attack", HigherIsBetter = true },
        { Label = "Defense", Key = "Defense", HigherIsBetter = true },
        { Label = "Maximum HP", Key = "BonusHealth", HigherIsBetter = true },
        { Label = "Attack interval", Key = "Cooldown", HigherIsBetter = false, Suffix = "s" },
    }

    local drewAny = false
    for _, row in ipairs(rows) do
        local rawBefore = tonumber(getField(equipped, equippedDef, row.Key))
        local rawAfter = tonumber(getField(item, definition, row.Key))
        -- 0 is truthy in Lua, so compare against nil explicitly. A stat is only
        -- worth a row when at least one side actually has it.
        if (rawBefore ~= nil and rawBefore ~= 0) or (rawAfter ~= nil and rawAfter ~= 0) then
            local before = rawBefore or 0
            local after = rawAfter or 0
            local delta = after - before
            local suffix = row.Suffix or ""

            local color = Theme.White
            if isEmpty then
                -- Buying into an empty slot only ever adds stats.
                if after ~= 0 then color = Theme.Green end
            elseif delta ~= 0 then
                local better = row.HigherIsBetter and delta > 0
                    or (not row.HigherIsBetter and delta < 0)
                color = better and Theme.Green or Theme.Red
            end

            local deltaText
            if isEmpty then
                deltaText = string.format("  (+%s%s)", tostring(after), suffix)
            elseif delta == 0 then
                deltaText = "  (same)"
            else
                deltaText = string.format("  (%s%s%s)", delta > 0 and "+" or "", tostring(delta), suffix)
            end

            makeLabel(self.Frame,
                string.format("%s  %s%s → %s%s%s", row.Label,
                    tostring(before), suffix, tostring(after), suffix, deltaText),
                15, y, 285, 19, 12, color, true)
            y += 20
            drewAny = true
        end
    end

    if not drewAny then
        makeLabel(self.Frame, "No comparable stats", 15, y, 285, 17, 11, Theme.Muted, false)
        y += 19
    end
    return y
end

function ItemTooltip:Destroy()
    if self._connection then
        self._connection:Disconnect()
        self._connection = nil
    end
    self.Frame:Destroy()
end

return ItemTooltip
