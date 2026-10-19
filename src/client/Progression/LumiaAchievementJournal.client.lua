-- REALMS OF LUMIA V16 | ACHIEVEMENT JOURNAL
-- Toggle L. Shows saved achievements via read-only GetAchievements network.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UIS = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local LumiaModalState = require(script.Parent.Parent:WaitForChild("UI"):WaitForChild("LumiaModalState"))
local shared = ReplicatedStorage:WaitForChild("Lumia"):WaitForChild("Shared")
local Config = require(shared:WaitForChild("Progression"):WaitForChild("AchievementConfig"))
local network = ReplicatedStorage.Lumia:WaitForChild("AchievementNetwork", 30)
if not network then
    warn("[Lumia V16] Achievement journal could not find network")
    return
end
local fetch = network:WaitForChild("GetAchievements", 15)
local earned = network:WaitForChild("AchievementEarned", 15)
if not fetch or not earned then return end

local previous = playerGui:FindFirstChild("LumiaAchievementJournal")
if previous then previous:Destroy() end
local gui = Instance.new("ScreenGui")
gui.Name = "LumiaAchievementJournal"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 46
gui.Enabled = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = playerGui

local shade = Instance.new("Frame")
shade.Name = "Backdrop"
shade.Size = UDim2.fromScale(1, 1)
shade.BackgroundColor3 = Color3.fromRGB(4, 7, 13)
shade.BackgroundTransparency = 0.42
shade.BorderSizePixel = 0
shade.Parent = gui

local panel = Instance.new("Frame")
panel.Name = "JournalWindow"
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.fromScale(0.5, 0.5)
panel.Size = UDim2.new(0.88, 0, 0.83, 0)
panel.BackgroundColor3 = Color3.fromRGB(20, 29, 42)
panel.BorderSizePixel = 0
panel.Parent = shade
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 12)
local limit = Instance.new("UISizeConstraint")
limit.MaxSize = Vector2.new(635, 540)
limit.MinSize = Vector2.new(300, 275)
limit.Parent = panel
local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(178, 139, 77)
stroke.Thickness = 1.7
stroke.Parent = panel

local heading = Instance.new("TextLabel")
heading.Name = "Heading"
heading.Position = UDim2.fromOffset(18, 11)
heading.Size = UDim2.new(1, -88, 0, 42)
heading.BackgroundTransparency = 1
heading.Font = Enum.Font.Garamond
heading.TextSize = 35
heading.TextXAlignment = Enum.TextXAlignment.Left
heading.TextColor3 = Color3.fromRGB(243, 218, 167)
heading.Text = "ACHIEVEMENTS"
heading.Parent = panel

local close = Instance.new("TextButton")
close.Name = "Close"
close.AnchorPoint = Vector2.new(1, 0)
close.Position = UDim2.new(1, -14, 0, 15)
close.Size = UDim2.fromOffset(35, 34)
close.BackgroundColor3 = Color3.fromRGB(45, 53, 67)
close.Text = "X"
close.Font = Enum.Font.GothamBold
close.TextSize = 16
close.TextColor3 = Color3.fromRGB(244, 235, 217)
close.Parent = panel
Instance.new("UICorner", close).CornerRadius = UDim.new(0, 7)

local subtitle = Instance.new("TextLabel")
subtitle.Name = "Progress"
subtitle.Position = UDim2.fromOffset(19, 51)
subtitle.Size = UDim2.new(1, -38, 0, 29)
subtitle.BackgroundTransparency = 1
subtitle.Font = Enum.Font.Gotham
subtitle.TextSize = 13
subtitle.TextXAlignment = Enum.TextXAlignment.Left
subtitle.TextColor3 = Color3.fromRGB(179, 190, 199)
subtitle.Text = "Loading your achievements..."
subtitle.Parent = panel

local line = Instance.new("Frame")
line.Size = UDim2.new(1, -36, 0, 1)
line.Position = UDim2.fromOffset(18, 85)
line.BorderSizePixel = 0
line.BackgroundColor3 = Color3.fromRGB(91, 79, 62)
line.Parent = panel

local scroll = Instance.new("ScrollingFrame")
scroll.Name = "Achievements"
scroll.Position = UDim2.fromOffset(18, 95)
scroll.Size = UDim2.new(1, -36, 1, -142)
scroll.BackgroundTransparency = 1
scroll.ScrollBarThickness = 5
scroll.ScrollBarImageColor3 = Color3.fromRGB(190, 153, 93)
scroll.BorderSizePixel = 0
scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
scroll.Parent = panel
local layout = Instance.new("UIListLayout")
layout.FillDirection = Enum.FillDirection.Vertical
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Padding = UDim.new(0, 7)
layout.Parent = scroll

local footer = Instance.new("TextLabel")
footer.Name = "Shortcut"
footer.Position = UDim2.new(0, 18, 1, -37)
footer.Size = UDim2.new(1, -36, 0, 27)
footer.BackgroundTransparency = 1
footer.Font = Enum.Font.GothamMedium
footer.TextSize = 11
footer.TextColor3 = Color3.fromRGB(161, 175, 186)
footer.Text = "L  •  Open / close achievement journal"
footer.Parent = panel

local shown = false
local requestNumber = 0
local latest = {Ready = false, Unlocked = {}, CurrentTitle = ""}
local function createRow(id, order, unlocked)
    local definition = Config.Get(id)
    if not definition then return end
    local row = Instance.new("Frame")
    row.Name = "Achievement_" .. id
    row.LayoutOrder = order
    row.Size = UDim2.new(1, -10, 0, 69)
    row.BackgroundColor3 = unlocked and Color3.fromRGB(38, 53, 62) or Color3.fromRGB(29, 38, 51)
    row.BorderSizePixel = 0
    row.Parent = scroll
    Instance.new("UICorner", row).CornerRadius = UDim.new(0, 7)
    local border = Instance.new("UIStroke")
    border.Color = unlocked and Color3.fromRGB(168, 134, 80) or Color3.fromRGB(65, 74, 86)
    border.Transparency = unlocked and 0.12 or 0.38
    border.Thickness = 1
    border.Parent = row

    local glyph = Instance.new("TextLabel")
    glyph.Position = UDim2.fromOffset(10, 11)
    glyph.Size = UDim2.fromOffset(39, 42)
    glyph.BackgroundTransparency = 1
    glyph.Font = Enum.Font.Garamond
    glyph.TextSize = 30
    glyph.Text = unlocked and (definition.ToastIcon or "✦") or "◇"
    glyph.TextColor3 = unlocked and Color3.fromRGB(231, 196, 127)
        or Color3.fromRGB(105, 120, 140)
    glyph.Parent = row

    local name = Instance.new("TextLabel")
    name.Position = UDim2.fromOffset(55, 6)
    name.Size = UDim2.new(1, -141, 0, 24)
    name.BackgroundTransparency = 1
    name.TextXAlignment = Enum.TextXAlignment.Left
    name.Font = Enum.Font.GothamBold
    name.TextSize = 15
    name.TextTruncate = Enum.TextTruncate.AtEnd
    name.Text = definition.Name or id
    name.TextColor3 = unlocked and Color3.fromRGB(240, 224, 191)
        or Color3.fromRGB(170, 181, 191)
    name.Parent = row

    local description = Instance.new("TextLabel")
    description.Position = UDim2.fromOffset(55, 30)
    description.Size = UDim2.new(1, -75, 0, 33)
    description.BackgroundTransparency = 1
    description.TextXAlignment = Enum.TextXAlignment.Left
    description.TextYAlignment = Enum.TextYAlignment.Top
    description.Font = Enum.Font.Gotham
    description.TextSize = 11
    description.TextWrapped = true
    description.Text = definition.Description or ""
    description.TextColor3 = Color3.fromRGB(167, 180, 191)
    description.Parent = row

    local status = Instance.new("TextLabel")
    status.AnchorPoint = Vector2.new(1, 0)
    status.Position = UDim2.new(1, -10, 0, 10)
    status.Size = UDim2.fromOffset(75, 20)
    status.BackgroundTransparency = 1
    status.TextXAlignment = Enum.TextXAlignment.Right
    status.Font = Enum.Font.GothamBold
    status.TextSize = 10
    status.Text = unlocked and "UNLOCKED" or "LOCKED"
    status.TextColor3 = unlocked and Color3.fromRGB(124, 209, 161)
        or Color3.fromRGB(126, 136, 148)
    status.Parent = row
end

local function render()
    for _, child in ipairs(scroll:GetChildren()) do
        if child:IsA("Frame") then child:Destroy() end
    end
    local unlockedMap = {}
    for _, id in ipairs(latest.Unlocked or {}) do
        if type(id) == "string" then unlockedMap[id] = true end
    end
    local total = #Config.Order
    local count = 0
    for idx, id in ipairs(Config.Order) do
        if unlockedMap[id] then count += 1 end
        createRow(id, idx, unlockedMap[id] == true)
    end
    local titleText = latest.CurrentTitle
    local suffix = type(titleText) == "string" and titleText ~= "" and ("  •  Title: " .. titleText) or ""
    subtitle.Text = string.format("%d / %d achievements unlocked%s", count, total, suffix)
end

local function refresh()
    requestNumber += 1
    local number = requestNumber
    task.spawn(function()
        local ok, result = pcall(function() return fetch:InvokeServer() end)
        if number ~= requestNumber or not gui.Parent then return end
        if ok and type(result) == "table" and result.Ready == true then
            latest = result
            render()
        else
            subtitle.Text = "Character loading — reopen with L to retry"
        end
    end)
end

local function setOpen(open)
    if shown == open then return end
    shown = open
    gui.Enabled = open
    if open then
        LumiaModalState:Register("AchievementJournal")
        refresh()
    else
        LumiaModalState:Unregister("AchievementJournal")
    end
end
close.Activated:Connect(function() setOpen(false) end)
-- V18 micro menu shares the same journal state as the L hotkey.
local MenuBus = require(script.Parent.Parent:WaitForChild("UI"):WaitForChild("LumiaMicroMenuBus"))
MenuBus.Register("Achievements", function() setOpen(not shown) end)
UIS.InputBegan:Connect(function(input, processed)
    if processed or UIS:GetFocusedTextBox() then return end
    if input.KeyCode == Enum.KeyCode.L then
        setOpen(not shown)
    end
end)
earned.OnClientEvent:Connect(function(data)
    if shown and type(data) == "table" and data.Id then refresh() end
end)
print("[Lumia V16] Achievement journal ready: press L")
