-- REALMS OF LUMIA | XP HUD V16 (dedicated persistent drag)
-- Self-contained client display; server owns XP rewards, levels, and saving.
-- Uses existing ProgressionConfig requirements and ProgressionNetwork snapshots.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local XPBarDrag = require(script.Parent:WaitForChild("LumiaXPBarDrag"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local network = ReplicatedStorage:WaitForChild("Lumia"):WaitForChild("ProgressionNetwork")
local changed = network:WaitForChild("ProgressionChanged")
local getProgression = network:WaitForChild("GetProgression")

local existing = playerGui:FindFirstChild("LumiaXPBar")
if existing then existing:Destroy() end

local gui = Instance.new("ScreenGui")
gui.Name = "LumiaXPBar"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 25
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = playerGui

local root = Instance.new("Frame")
root.Name = "XPBarPanel"
root.AnchorPoint = Vector2.new(0.5, 1)
root.Position = UDim2.new(0.5, 0, 1, -120)
root.Size = UDim2.new(0.75, 0, 0, 27)
root.BackgroundColor3 = Color3.fromRGB(19, 20, 28)
root.BackgroundTransparency = 0.08
root.BorderSizePixel = 0
root.Parent = gui
Instance.new("UICorner", root).CornerRadius = UDim.new(0, 5)
local widthLimit = Instance.new("UISizeConstraint")
widthLimit.MaxSize = Vector2.new(700, 35)
widthLimit.Parent = root
local frameStroke = Instance.new("UIStroke")
frameStroke.Color = Color3.fromRGB(169, 127, 70)
frameStroke.Thickness = 1.2
frameStroke.Parent = root
root.Active = true
XPBarDrag.Attach(root)

local levelLabel = Instance.new("TextLabel")
levelLabel.Name = "Level"
levelLabel.Size = UDim2.fromOffset(70, 27)
levelLabel.BackgroundTransparency = 1
levelLabel.Text = "LEVEL 1"
levelLabel.TextColor3 = Color3.fromRGB(240, 203, 142)
levelLabel.Font = Enum.Font.GothamBold
levelLabel.TextSize = 12
levelLabel.ZIndex = 4
levelLabel.Parent = root

local track = Instance.new("Frame")
track.Name = "XPTrack"
track.Position = UDim2.fromOffset(71, 4)
track.Size = UDim2.new(1, -76, 1, -8)
track.BackgroundColor3 = Color3.fromRGB(44, 39, 56)
track.BorderSizePixel = 0
track.ClipsDescendants = true
track.ZIndex = 2
track.Parent = root
Instance.new("UICorner", track).CornerRadius = UDim.new(0, 3)

local fill = Instance.new("Frame")
fill.Name = "XPFill"
fill.Size = UDim2.fromScale(0, 1)
fill.BackgroundColor3 = Color3.fromRGB(149, 106, 192)
fill.BorderSizePixel = 0
fill.ZIndex = 3
fill.Parent = track
Instance.new("UICorner", fill).CornerRadius = UDim.new(0, 3)

local values = Instance.new("TextLabel")
values.Name = "XPText"
values.Size = UDim2.fromScale(1, 1)
values.BackgroundTransparency = 1
values.Text = "Loading XP..."
values.Font = Enum.Font.GothamBold
values.TextSize = 11
values.TextColor3 = Color3.fromRGB(247, 241, 253)
values.TextStrokeColor3 = Color3.fromRGB(12, 10, 16)
values.TextStrokeTransparency = 0.35
values.ZIndex = 5
values.Parent = track

local activeFillTween = nil
local revision = 0
local ready = false

local function validState(state)
    return type(state) == "table" and state.Ready == true
        and type(state.Level) == "number" and state.Level >= 1
        and type(state.Experience) == "number" and state.Experience >= 0
        and type(state.MaxLevel) == "number" and state.MaxLevel >= state.Level
end

local function popup(message, isLevelUp)
    local notice = Instance.new("TextLabel")
    notice.Name = isLevelUp and "LevelUpNotice" or "XPNotice"
    notice.AnchorPoint = Vector2.new(0.5, 1)
    notice.Position = UDim2.new(0.5, 0, 0, -6)
    notice.Size = UDim2.fromOffset(isLevelUp and 310 or 170, 35)
    notice.BackgroundTransparency = 1
    notice.Text = message
    notice.TextColor3 = isLevelUp and Color3.fromRGB(255, 222, 135)
        or Color3.fromRGB(193, 161, 236)
    notice.TextStrokeColor3 = Color3.fromRGB(17, 12, 25)
    notice.TextStrokeTransparency = 0.35
    notice.TextTransparency = 0
    notice.Font = Enum.Font.GothamBold
    notice.TextSize = isLevelUp and 24 or 17
    notice.ZIndex = 8
    notice.Parent = root
    TweenService:Create(notice, TweenInfo.new(1.5, Enum.EasingStyle.Quad), {
        Position = UDim2.new(0.5, 0, 0, -42),
        TextTransparency = 1,
        TextStrokeTransparency = 1,
    }):Play()
    task.delay(1.6, function()
        if notice.Parent then notice:Destroy() end
    end)
end

local function render(state, animate)
    if not validState(state) then return end
    ready = true
    local atCap = state.Level >= state.MaxLevel
    local required = state.RequiredXP
    local ratio = 1
    if not atCap and type(required) == "number" and required > 0 then
        ratio = math.clamp(state.Experience / required, 0, 1)
    end
    levelLabel.Text = "LEVEL " .. tostring(state.Level)
    values.Text = atCap and "MAX LEVEL"
        or (string.format("%d / %d XP", state.Experience, required or 0))

    if activeFillTween then activeFillTween:Cancel() end
    local target = UDim2.fromScale(ratio, 1)
    if animate then
        activeFillTween = TweenService:Create(fill,
            TweenInfo.new(0.38, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            {Size = target})
        activeFillTween:Play()
    else
        fill.Size = target
    end

    if animate and type(state.GainedXP) == "number" and state.GainedXP > 0 then
        popup("+" .. tostring(state.GainedXP) .. " XP", false)
    end
    if animate and type(state.LevelsGained) == "number" and state.LevelsGained > 0 then
        popup("LEVEL UP!  " .. tostring(state.Level), true)
    end
end

-- Connect BEFORE requesting the initial snapshot. Stale initial responses
-- must not overwrite a live kill reward that arrived in the meantime.
changed.OnClientEvent:Connect(function(state)
    revision += 1
    render(state, true)
end)

task.spawn(function()
    while gui.Parent and not ready do
        local initialRevision = revision
        local ok, state = pcall(function()
            return getProgression:InvokeServer()
        end)
        if ok and revision == initialRevision and validState(state) then
            render(state, false)
            break
        end
        task.wait(1.5)
    end
end)

print("[Lumia - Lumia XP Bar] XP bar ready - server-driven level and XP")
