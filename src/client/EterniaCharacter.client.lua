-- Realms of Eternia - Step 13.1
-- Character sheet: press C to open. Read-only until EquipmentService (Step 13.2).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local uiModules = script.Parent:WaitForChild("CharacterUI")
local Theme = require(uiModules:WaitForChild("CharacterTheme"))
local EquipmentSlots = require(uiModules:WaitForChild("EquipmentSlots"))
local StatDisplay = require(uiModules:WaitForChild("StatDisplay"))
local ItemTooltip = require(uiModules:WaitForChild("ItemTooltip"))
local eternia = ReplicatedStorage:WaitForChild("Eternia")
local network = eternia:WaitForChild("CharacterNetwork")
local request = network:WaitForChild("GetCharacter")

local function label(parent, name, x, y, w, h, value, size, color, bold)
    local object = Instance.new("TextLabel")
    object.Name = name
    object.Position = UDim2.fromOffset(x, y)
    object.Size = UDim2.fromOffset(w, h)
    object.BackgroundTransparency = 1
    object.Text = value
    object.Font = bold and Enum.Font.GothamBold or Enum.Font.Gotham
    object.TextSize = size
    object.TextColor3 = color
    object.TextXAlignment = Enum.TextXAlignment.Left
    object.TextTruncate = Enum.TextTruncate.AtEnd
    object.ZIndex = 5
    object.Parent = parent
    return object
end

local function corner(object, radius)
    Instance.new("UICorner", object).CornerRadius = UDim.new(0, radius)
end

local gui = Instance.new("ScreenGui")
gui.Name = "EterniaCharacter"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.ZIndexBehavior = Enum.ZIndexBehavior.Global
gui.DisplayOrder = 30
gui.Parent = player:WaitForChild("PlayerGui")

local window = Instance.new("Frame")
window.Name = "CharacterWindow"
window.Size = UDim2.fromOffset(Theme.WindowWidth, Theme.WindowHeight)
window.AnchorPoint = Vector2.new(0.5, 0.5)
window.Position = UDim2.fromScale(0.5, 0.5)
window.BackgroundColor3 = Theme.Background
window.BorderSizePixel = 0
window.Visible = false
window.ZIndex = 2
window.Parent = gui
corner(window, 9)

local windowBorder = Instance.new("UIStroke")
windowBorder.Color = Theme.Border
windowBorder.Thickness = 1.5
windowBorder.Parent = window

-- On smaller displays, scale the whole approved design uniformly.
-- The underlying equipment slots always remain exactly 300 x 51.
local scale = Instance.new("UIScale")
scale.Name = "AdaptiveScale"
scale.Scale = 1
scale.Parent = window

local function updateScale()
    local camera = workspace.CurrentCamera
    if not camera then return end
    local viewport = camera.ViewportSize
    scale.Scale = math.clamp(math.min(
        (viewport.X - 24) / Theme.WindowWidth,
        (viewport.Y - 42) / Theme.WindowHeight), 0.2, 1)
end

local function connectCamera()
    local camera = workspace.CurrentCamera
    if camera then
        camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
    end
    updateScale()
end
connectCamera()
workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(connectCamera)

label(window, "Brand", 18, 13, 350, 19,
    "REALMS OF ETERNIA", 12, Theme.Gold, true)
label(window, "HeaderTitle", 18, 36, 390, 37,
    "Character", 27, Theme.White, true)

local close = Instance.new("TextButton")
close.Name = "Close"
close.Size = UDim2.fromOffset(29, 29)
close.Position = UDim2.fromOffset(585, 19)
close.BackgroundColor3 = Theme.Panel
close.BorderSizePixel = 0
close.Text = "X"
close.Font = Enum.Font.GothamBold
close.TextSize = 13
close.TextColor3 = Theme.White
close.ZIndex = 5
close.Parent = window
corner(close, 5)

local summary = Instance.new("Frame")
summary.Name = "CharacterSummary"
summary.Position = UDim2.fromOffset(12, 88)
summary.Size = UDim2.fromOffset(608, 91)
summary.BackgroundColor3 = Theme.Panel
summary.BorderSizePixel = 0
summary.ZIndex = 3
summary.Parent = window
corner(summary, 7)

local characterName = label(summary, "Name", 15, 10, 390, 23,
    "Loading character...", 17, Theme.White, true)
local characterDetails = label(summary, "LevelAndXP", 15, 33, 430, 19,
    "Please wait for saved character data", 12, Theme.Secondary, false)
local classPill = Instance.new("Frame")
classPill.Name = "ClassPill"
classPill.Position = UDim2.fromOffset(469, 14)
classPill.Size = UDim2.fromOffset(125, 27)
classPill.BackgroundColor3 = Theme.StatCell
classPill.BorderSizePixel = 0
classPill.ZIndex = 4
classPill.Parent = summary
corner(classPill, 13)
local classText = label(classPill, "ClassName", 6, 0, 113, 27,
    "Unassigned", 11, Theme.Gold, true)
classText.TextXAlignment = Enum.TextXAlignment.Center

local xpTrack = Instance.new("Frame")
xpTrack.Name = "XPTrack"
xpTrack.Position = UDim2.fromOffset(15, 71)
xpTrack.Size = UDim2.fromOffset(578, 7)
xpTrack.BackgroundColor3 = Theme.StatCell
xpTrack.BorderSizePixel = 0
xpTrack.ZIndex = 4
xpTrack.Parent = summary
corner(xpTrack, 4)
local xpFill = Instance.new("Frame")
xpFill.Name = "XPFill"
xpFill.Size = UDim2.fromScale(0, 1)
xpFill.BackgroundColor3 = Theme.Gold
xpFill.BorderSizePixel = 0
xpFill.ZIndex = 5
xpFill.Parent = xpTrack
corner(xpFill, 4)

label(window, "EquipmentHeader", 13, 191, 300, 23,
    "EQUIPMENT", 13, Theme.White, true)
local equipmentArea = Instance.new("Frame")
equipmentArea.Name = "EquipmentGrid"
equipmentArea.Position = UDim2.fromOffset(12, 223)
equipmentArea.Size = UDim2.fromOffset(608, 228)
equipmentArea.BackgroundTransparency = 1
equipmentArea.ZIndex = 3
equipmentArea.Parent = window

local tooltip = ItemTooltip.new(gui)
local equipment = EquipmentSlots.new(equipmentArea, tooltip)
local statsPanel = StatDisplay.new(window)

local function render(snapshot)
    characterName.Text = tostring(snapshot.Name or player.Name)
    local level = type(snapshot.Level) == "number" and snapshot.Level or 1
    local xp = type(snapshot.Experience) == "number" and snapshot.Experience or 0
    local requiredXP = snapshot.RequiredXP
    local maxLevel = type(snapshot.MaxLevel) == "number" and snapshot.MaxLevel or 60

    if level >= maxLevel then
        characterDetails.Text = "Level " .. level .. "  |  MAX LEVEL"
        xpFill.Size = UDim2.fromScale(1, 1)
    elseif type(requiredXP) == "number" and requiredXP > 0 then
        characterDetails.Text = "Level " .. level .. "  |  "
            .. tostring(xp) .. " / " .. tostring(requiredXP) .. " XP"
        xpFill.Size = UDim2.fromScale(math.clamp(xp / requiredXP, 0, 1), 1)
    else
        characterDetails.Text = "Level " .. level .. "  |  " .. tostring(xp) .. " XP"
        xpFill.Size = UDim2.fromScale(0, 1)
    end

    local characterClass = snapshot.Class
    classText.Text = type(characterClass) == "string" and characterClass ~= ""
        and characterClass or "Unassigned"
    equipment:Update(snapshot.Equipment)
    statsPanel:Update(snapshot.Stats, snapshot.Gold)
end

local isRefreshing = false
local function refresh()
    if isRefreshing or not window.Visible then return end
    isRefreshing = true
    local ok, result = pcall(function()
        return request:InvokeServer()
    end)
    isRefreshing = false
    if not window.Visible then return end
    if ok and type(result) == "table" and result.Ready then
        render(result)
    elseif not ok then
        characterDetails.Text = "Connection issue - retrying..."
    elseif not result or not result.Retry then
        characterDetails.Text = "Waiting for character data..."
    end
end

local function toggle()
    window.Visible = not window.Visible
    tooltip:Hide()
    if window.Visible then
        task.spawn(refresh)
    end
end

close.MouseButton1Click:Connect(toggle)
UserInputService.InputBegan:Connect(function(input, processed)
    if processed or UserInputService:GetFocusedTextBox() then return end
    if input.KeyCode == Enum.KeyCode.C then
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

print("[Eternia] Character Sheet ready - Press C")
