-- Realms of Lumia - Step 13.1
-- Draws and updates four persisted character attributes and gold.
local Theme = require(script.Parent:WaitForChild("CharacterTheme"))

local StatDisplay = {}
StatDisplay.__index = StatDisplay

local function createText(parent, name, x, y, width, height, value, color, bold, align)
    local label = Instance.new("TextLabel")
    label.Name = name
    label.Position = UDim2.fromOffset(x, y)
    label.Size = UDim2.fromOffset(width, height)
    label.BackgroundTransparency = 1
    label.Text = value
    label.Font = bold and Enum.Font.GothamBold or Enum.Font.Gotham
    label.TextSize = 13
    label.TextColor3 = color
    label.TextXAlignment = align or Enum.TextXAlignment.Left
    label.ZIndex = 5
    label.Parent = parent
    return label
end

function StatDisplay.new(parent)
    local self = setmetatable({ Labels = {} }, StatDisplay)
    local panel = Instance.new("Frame")
    panel.Name = "AttributesPanel"
    panel.Position = UDim2.fromOffset(12, 471)
    panel.Size = UDim2.fromOffset(608, 179)
    panel.BackgroundColor3 = Theme.Panel
    panel.BorderSizePixel = 0
    panel.ZIndex = 2
    panel.Parent = parent
    Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 7)

    createText(panel, "Heading", 14, 10, 400, 23,
        "CHARACTER ATTRIBUTES", Theme.White, true)

    local names = { "Strength", "Agility", "Intelligence", "Vitality" }
    for index, name in ipairs(names) do
        local col = (index - 1) % 2
        local row = math.floor((index - 1) / 2)
        local x = 13 + col * 294
        local y = 39 + row * 47
        local cell = Instance.new("Frame")
        cell.Name = name .. "Cell"
        cell.Position = UDim2.fromOffset(x, y)
        cell.Size = UDim2.fromOffset(287, 39)
        cell.BackgroundColor3 = Theme.StatCell
        cell.BorderSizePixel = 0
        cell.ZIndex = 3
        cell.Parent = panel
        Instance.new("UICorner", cell).CornerRadius = UDim.new(0, 5)

        createText(cell, "StatName", 12, 0, 191, 39,
            name, Theme.Secondary, false)
        self.Labels[name] = createText(cell, "StatValue", 218, 0, 56, 39,
            "--", Theme.White, true, Enum.TextXAlignment.Right)
    end

    local line = Instance.new("Frame")
    line.Position = UDim2.fromOffset(14, 139)
    line.Size = UDim2.fromOffset(580, 1)
    line.BackgroundColor3 = Theme.Border
    line.BorderSizePixel = 0
    line.ZIndex = 4
    line.Parent = panel

    createText(panel, "GoldLabel", 14, 145, 200, 24,
        "Gold", Theme.Gold, true)
    self.GoldLabel = createText(panel, "GoldValue", 380, 145, 214, 24,
        "--", Theme.Gold, true, Enum.TextXAlignment.Right)
    return self
end

function StatDisplay:Update(stats, gold)
    stats = type(stats) == "table" and stats or {}
    for name, label in pairs(self.Labels) do
        local value = stats[name]
        label.Text = type(value) == "number" and tostring(value) or "--"
    end
    self.GoldLabel.Text = type(gold) == "number" and tostring(gold) or "--"
end

return StatDisplay
