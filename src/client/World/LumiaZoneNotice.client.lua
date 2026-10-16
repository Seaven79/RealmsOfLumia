-- V16: Locked-zone notices stay below the compact major-region banner.
-- Lumia V15 - friendly notification when a new area is level-locked.
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
local network = ReplicatedStorage:WaitForChild("Lumia"):WaitForChild("ZoneNetwork", 30)
if not network then return end
local remote = network:WaitForChild("ZoneNotice", 20)
if not remote then return end
local old = playerGui:FindFirstChild("LumiaZoneNotice")
if old then old:Destroy() end
local gui = Instance.new("ScreenGui")
gui.Name = "LumiaZoneNotice"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.DisplayOrder = 34
gui.Parent = playerGui
local label = Instance.new("TextLabel")
label.Name = "LockedZoneNotice"
label.Size = UDim2.new(0.78, 0, 0, 54)
label.AnchorPoint = Vector2.new(0.5, 0)
label.Position = UDim2.new(0.5, 0, 0, 169)
label.BackgroundColor3 = Color3.fromRGB(25, 27, 37)
label.BackgroundTransparency = 0.25
label.Font = Enum.Font.Garamond
label.TextSize = 24
label.TextColor3 = Color3.fromRGB(247, 205, 128)
label.TextWrapped = true
label.Visible = false
label.Parent = gui
Instance.new("UICorner", label).CornerRadius = UDim.new(0, 8)
local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(151, 112, 62)
stroke.Thickness = 1.5
stroke.Parent = label
local limit = Instance.new("UISizeConstraint")
limit.MaxSize = Vector2.new(610, 54)
limit.Parent = label
local seq = 0
remote.OnClientEvent:Connect(function(data)
    if type(data) ~= "table" or data.Type ~= "Denied" then return end
    seq += 1
    local token = seq
    label.Text = string.format("%s  •  Level %d required", tostring(data.ZoneName), data.RequiredLevel or 1)
    label.TextTransparency = 0
    label.Visible = true
    task.delay(2.6, function()
        if token ~= seq or not label.Parent then return end
        local tween = TweenService:Create(label, TweenInfo.new(0.45), {TextTransparency = 1})
        tween:Play()
        tween.Completed:Wait()
        if token == seq then label.Visible = false end
    end)
end)
