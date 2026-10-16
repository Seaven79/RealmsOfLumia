-- REALMS OF LUMIA | Owner-only button near XP bar v1
-- Hiding the button is cosmetic; the server checks UserId independently.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer
if player.UserId ~= 1614020138 then return end

local playerGui = player:WaitForChild("PlayerGui")
local network = ReplicatedStorage:WaitForChild("Lumia"):WaitForChild("ProgressionNetwork")
local resetRemote = network:WaitForChild("AdminResetLevel")
local barGui = playerGui:WaitForChild("LumiaXPBar", 30)
if not barGui then
    warn("[Lumia - Admin Level Reset Button] XP bar not found; reset button not attached")
    return
end
local xpRoot = barGui:WaitForChild("XPBarPanel", 10)
if not xpRoot then return end

local old = xpRoot:FindFirstChild("AdminResetLevelButton")
if old then old:Destroy() end

local button = Instance.new("TextButton")
button.Name = "AdminResetLevelButton"
button.AnchorPoint = Vector2.new(1, 1)
button.Position = UDim2.new(1, 0, 0, -7)
button.Size = UDim2.fromOffset(105, 25)
button.BackgroundColor3 = Color3.fromRGB(58, 41, 41)
button.BorderSizePixel = 0
button.Text = "Reset Level"
button.TextColor3 = Color3.fromRGB(250, 213, 181)
button.TextSize = 12
button.Font = Enum.Font.GothamBold
button.ZIndex = 11
button.Parent = xpRoot
Instance.new("UICorner", button).CornerRadius = UDim.new(0, 5)
local border = Instance.new("UIStroke")
border.Color = Color3.fromRGB(192, 131, 89)
border.Thickness = 1
border.Parent = button

local dialog = Instance.new("Frame")
dialog.Name = "ResetLevelConfirmation"
dialog.AnchorPoint = Vector2.new(0.5, 0.5)
dialog.Position = UDim2.fromScale(0.5, 0.5)
dialog.Size = UDim2.new(0.86, 0, 0, 172)
dialog.BackgroundColor3 = Color3.fromRGB(23, 25, 35)
dialog.BorderSizePixel = 0
dialog.Visible = false
dialog.ZIndex = 30
dialog.Parent = barGui
Instance.new("UICorner", dialog).CornerRadius = UDim.new(0, 8)
local limit = Instance.new("UISizeConstraint")
limit.MaxSize = Vector2.new(420, 172)
limit.Parent = dialog
local line = Instance.new("UIStroke")
line.Color = Color3.fromRGB(196, 151, 86)
line.Thickness = 1.5
line.Parent = dialog

local function textLabel(message, y, height, fontSize)
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -24, 0, height)
    label.Position = UDim2.fromOffset(12, y)
    label.BackgroundTransparency = 1
    label.Text = message
    label.TextWrapped = true
    label.Font = Enum.Font.Gotham
    label.TextSize = fontSize
    label.TextColor3 = Color3.fromRGB(239, 231, 219)
    label.ZIndex = 31
    label.Parent = dialog
    return label
end

textLabel("RESET LEVEL & XP?", 10, 28, 17).Font = Enum.Font.GothamBold
local description = textLabel("Your saved Level becomes 1 and XP becomes 0. Your items, gold, Warrior class and quests stay intact.", 43, 58, 13)

local function actionButton(label, position, color)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(0.5, -18, 0, 33)
    b.Position = position
    b.BackgroundColor3 = color
    b.BorderSizePixel = 0
    b.Text = label
    b.Font = Enum.Font.GothamBold
    b.TextSize = 13
    b.TextColor3 = Color3.fromRGB(252, 243, 225)
    b.ZIndex = 32
    b.Parent = dialog
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 5)
    return b
end
local cancel = actionButton("Cancel", UDim2.new(0, 12, 1, -46), Color3.fromRGB(58, 67, 80))
local confirm = actionButton("Reset", UDim2.new(0.5, 6, 1, -46), Color3.fromRGB(125, 62, 53))

local waiting = false
button.MouseButton1Click:Connect(function()
    if not waiting then dialog.Visible = not dialog.Visible end
end)
cancel.MouseButton1Click:Connect(function()
    if not waiting then dialog.Visible = false end
end)
confirm.MouseButton1Click:Connect(function()
    if waiting then return end
    waiting = true
    confirm.Text = "Saving..."
    local success, result = pcall(function()
        return resetRemote:InvokeServer("CONFIRM_RESET_LEVEL_XP")
    end)
    waiting = false
    confirm.Text = "Reset"
    if success and type(result) == "table" and result.Ok then
        dialog.Visible = false
    else
        description.Text = (success and type(result) == "table" and result.Message) or "Unable to reset now; check Output."
        warn("[Lumia - Admin Level Reset Button] Level reset unsuccessful: " .. tostring(description.Text))
    end
end)
print("[Lumia - Admin Level Reset Button] Reset Level button ready beside XP bar")
