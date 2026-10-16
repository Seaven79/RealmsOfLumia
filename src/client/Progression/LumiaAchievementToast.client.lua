-- V16: Achievement toast moved below the major-region banner and lock notice.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local network = ReplicatedStorage:WaitForChild("Lumia"):WaitForChild("AchievementNetwork", 20)
if not network then
    warn("[Lumia - Achievement Toast] Achievement network missing")
    return
end

local earned = network:WaitForChild("AchievementEarned", 20)
if not earned then
    warn("[Lumia - Achievement Toast] Achievement event missing")
    return
end

local old = playerGui:FindFirstChild("LumiaAchievementToast")
if old then old:Destroy() end

local gui = Instance.new("ScreenGui")
gui.Name = "LumiaAchievementToast"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 45
gui.Parent = playerGui

local holder = Instance.new("Frame")
holder.Name = "ToastHolder"
holder.AnchorPoint = Vector2.new(1, 0)
holder.Position = UDim2.new(1, -24, 0, 248)
holder.Size = UDim2.fromOffset(360, 112)
holder.BackgroundTransparency = 1
holder.Parent = gui

local panel = Instance.new("Frame")
panel.Name = "ToastPanel"
panel.AnchorPoint = Vector2.new(1, 0)
panel.Position = UDim2.new(1, 40, 0, 0)
panel.Size = UDim2.fromOffset(340, 94)
panel.BackgroundColor3 = Color3.fromRGB(19, 24, 34)
panel.BackgroundTransparency = 0.1
panel.BorderSizePixel = 0
panel.Visible = false
panel.Parent = holder

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 10)
corner.Parent = panel

local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(178, 140, 81)
stroke.Thickness = 1.5
stroke.Parent = panel

local icon = Instance.new("TextLabel")
icon.BackgroundTransparency = 1
icon.Position = UDim2.fromOffset(16, 14)
icon.Size = UDim2.fromOffset(44, 44)
icon.Font = Enum.Font.Garamond
icon.TextSize = 34
icon.TextColor3 = Color3.fromRGB(240, 214, 154)
icon.Text = "✦"
icon.Parent = panel

local title = Instance.new("TextLabel")
title.BackgroundTransparency = 1
title.Position = UDim2.fromOffset(66, 12)
title.Size = UDim2.fromOffset(252, 22)
title.Font = Enum.Font.GothamBold
title.TextXAlignment = Enum.TextXAlignment.Left
title.TextSize = 14
title.TextColor3 = Color3.fromRGB(244, 223, 174)
title.Text = "ACHIEVEMENT UNLOCKED"
title.Parent = panel

local nameLabel = Instance.new("TextLabel")
nameLabel.BackgroundTransparency = 1
nameLabel.Position = UDim2.fromOffset(66, 34)
nameLabel.Size = UDim2.fromOffset(252, 24)
nameLabel.Font = Enum.Font.Garamond
nameLabel.TextXAlignment = Enum.TextXAlignment.Left
nameLabel.TextSize = 26
nameLabel.TextColor3 = Color3.fromRGB(255, 241, 212)
nameLabel.Text = ""
nameLabel.Parent = panel

local desc = Instance.new("TextLabel")
desc.BackgroundTransparency = 1
desc.Position = UDim2.fromOffset(66, 58)
desc.Size = UDim2.fromOffset(252, 18)
desc.Font = Enum.Font.Gotham
desc.TextXAlignment = Enum.TextXAlignment.Left
desc.TextSize = 12
desc.TextColor3 = Color3.fromRGB(212, 208, 198)
desc.Text = ""
desc.Parent = panel

local reward = Instance.new("TextLabel")
reward.BackgroundTransparency = 1
reward.Position = UDim2.fromOffset(66, 76)
reward.Size = UDim2.fromOffset(252, 14)
reward.Font = Enum.Font.GothamSemibold
reward.TextXAlignment = Enum.TextXAlignment.Left
reward.TextSize = 11
reward.TextColor3 = Color3.fromRGB(136, 213, 169)
reward.Text = ""
reward.Parent = panel

local sequence = 0
local tweens = {}

local function stopTweens()
    for _, tween in ipairs(tweens) do
        tween:Cancel()
    end
    table.clear(tweens)
end

local function tween(instance, info, goal)
    local handle = TweenService:Create(instance, info, goal)
    tweens[#tweens + 1] = handle
    handle:Play()
    return handle
end

local function showToast(payload)
    sequence += 1
    local current = sequence
    stopTweens()

    icon.Text = payload.ToastIcon or "✦"
    nameLabel.Text = payload.Name or "Achievement"
    desc.Text = payload.Description or ""

    local rewardParts = {}
    if type(payload.TitleReward) == "string" and payload.TitleReward ~= "" then
        rewardParts[#rewardParts + 1] = "Title: " .. payload.TitleReward
    end
    if type(payload.ItemReward) == "string" and payload.ItemReward ~= "" then
        rewardParts[#rewardParts + 1] = "Reward item: " .. payload.ItemReward
    end
    reward.Text = table.concat(rewardParts, "  •  ")

    panel.Visible = true
    panel.Position = UDim2.new(1, 40, 0, 0)
    panel.BackgroundTransparency = 0.18

    tween(panel, TweenInfo.new(0.33, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Position = UDim2.new(1, 0, 0, 0),
        BackgroundTransparency = 0.08,
    })

    task.delay(4.2, function()
        if current ~= sequence or not panel.Parent then
            return
        end
        tween(panel, TweenInfo.new(0.36, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
            Position = UDim2.new(1, 40, 0, 0),
            BackgroundTransparency = 1,
        })
        task.delay(0.38, function()
            if current == sequence and panel.Parent then
                panel.Visible = false
            end
        end)
    end)
end

earned.OnClientEvent:Connect(function(payload)
    if type(payload) ~= "table" or payload.Ready == false then
        return
    end
    showToast(payload)
end)
