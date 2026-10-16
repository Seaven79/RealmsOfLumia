-- REALMS OF LUMIA - SHARED DESTROY CONFIRMATION v1
-- All client dialogs are informational; the server validates discard requests.
local Players = game:GetService("Players")
local gui = Instance.new("ScreenGui")
gui.Name = "LumiaItemDeleteConfirmation"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.DisplayOrder = 120
gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
local backdrop = Instance.new("Frame")
backdrop.BackgroundColor3 = Color3.new(0, 0, 0)
backdrop.BackgroundTransparency = 0.38
backdrop.Size = UDim2.fromScale(1, 1)
backdrop.Visible = false
backdrop.Active = true
backdrop.Parent = gui
local panel = Instance.new("Frame")
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.fromScale(0.5, 0.5)
panel.Size = UDim2.fromOffset(380, 196)
panel.BackgroundColor3 = Color3.fromRGB(33, 30, 30)
panel.Parent = backdrop
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 8)
local border = Instance.new("UIStroke", panel)
border.Thickness = 2
border.Color = Color3.fromRGB(163, 106, 57)
local function label(y, height, size, color)
    local node = Instance.new("TextLabel")
    node.Size = UDim2.new(1, -30, 0, height)
    node.Position = UDim2.fromOffset(15, y)
    node.BackgroundTransparency = 1
    node.TextColor3 = color
    node.TextSize = size
    node.TextWrapped = true
    node.Font = Enum.Font.GothamBold
    node.Parent = panel
    return node
end
local header = label(11, 34, 16, Color3.fromRGB(250, 191, 125))
local details = label(48, 81, 13, Color3.fromRGB(235, 227, 214))
details.Font = Enum.Font.Gotham
local function button(text, x, color)
    local node = Instance.new("TextButton")
    node.Text = text
    node.Size = UDim2.fromOffset(158, 36)
    node.Position = UDim2.fromOffset(x, 144)
    node.BackgroundColor3 = color
    node.TextColor3 = Color3.new(1, 1, 1)
    node.Font = Enum.Font.GothamBold
    node.TextSize = 13
    node.Parent = panel
    Instance.new("UICorner", node).CornerRadius = UDim.new(0, 5)
    return node
end
local cancel = button("CANCEL", 19, Color3.fromRGB(63, 67, 75))
local destroy = button("DESTROY", 202, Color3.fromRGB(143, 54, 47))
local onFinish
local function finish(confirmed)
    if not backdrop.Visible then return end
    backdrop.Visible = false
    local cb = onFinish
    onFinish = nil
    if cb then cb(confirmed) end
end
cancel.MouseButton1Click:Connect(function() finish(false) end)
destroy.MouseButton1Click:Connect(function() finish(true) end)
local Dialog = {}
function Dialog.Show(item, callback)
    if backdrop.Visible then return false end
    if type(item) ~= "table" or type(callback) ~= "function" then return false end
    local isWeapon = item.Type == "Weapon"
    local name = tostring(item.DisplayName or item.ItemId)
    local count = tonumber(item.Quantity) or 1
    header.Text = isWeapon and "WARNING - WEAPON DELETION" or "DESTROY THIS ITEM?"
    details.Text = "Destroy " .. name .. (count > 1 and " x" .. count or "") .. "?\n\n"
        .. (isWeapon and "This is a WEAPON. You may lose your ability to fight. " or "")
        .. "This cannot be undone."
    border.Color = isWeapon and Color3.fromRGB(209, 70, 63) or Color3.fromRGB(163, 106, 57)
    onFinish = callback
    backdrop.Visible = true
    return true
end
return Dialog