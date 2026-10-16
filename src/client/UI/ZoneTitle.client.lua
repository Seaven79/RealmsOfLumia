-- REALMS OF LUMIA V16 | MAJOR REGION BANNER ONLY
-- Quest subzones stay functional for quests and discovery, but never show
-- the main region banner. Each major region shows at most once per join.
-- No false "NEW AREA DISCOVERED" header on repeat visits.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local zoneConfig = require(ReplicatedStorage:WaitForChild("Lumia")
    :WaitForChild("Shared"):WaitForChild("World"):WaitForChild("ZoneConfig"))
local playerGui = player:WaitForChild("PlayerGui")
local existing = playerGui:FindFirstChild("LumiaZoneTitle")
if existing then existing:Destroy() end

local MAIN_ZONES = {
    ForgottenForest = true,
    ThornwatchGlade = true,
    FirstGateApproach = true,
}
local DWELL_SECONDS = 1.3  -- do not react to a brief edge crossing
local displayed = {}
local candidate, candidateSince = nil, 0
local sequence = 0
local activeTweens = {}

local gui = Instance.new("ScreenGui")
gui.Name = "LumiaZoneTitle"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.DisplayOrder = 30
gui.Parent = playerGui

local panel = Instance.new("Frame")
panel.Name = "MajorRegionBanner"
panel.AnchorPoint = Vector2.new(0.5, 0)
panel.Position = UDim2.new(0.5, 0, 0, 75)
panel.Size = UDim2.new(0.82, 0, 0, 83)
panel.BackgroundColor3 = Color3.fromRGB(17, 23, 32)
panel.BackgroundTransparency = 1
panel.BorderSizePixel = 0
panel.Visible = false
panel.Parent = gui
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 9)
local limit = Instance.new("UISizeConstraint")
limit.MaxSize = Vector2.new(420, 83)
limit.Parent = panel
local border = Instance.new("UIStroke")
border.Color = Color3.fromRGB(177, 140, 83)
border.Thickness = 1.2
border.Transparency = 1
border.Parent = panel

local function label(name, y, height, size, font, color)
    local txt = Instance.new("TextLabel")
    txt.Name = name
    txt.Position = UDim2.new(0, 12, 0, y)
    txt.Size = UDim2.new(1, -24, 0, height)
    txt.BackgroundTransparency = 1
    txt.TextXAlignment = Enum.TextXAlignment.Center
    txt.TextYAlignment = Enum.TextYAlignment.Center
    txt.TextWrapped = true
    txt.Font = font
    txt.TextSize = size
    txt.TextColor3 = color
    txt.TextTransparency = 1
    txt.Parent = panel
    return txt
end

local eyebrow = label("RegionHeader", 5, 14, 10, Enum.Font.GothamMedium, Color3.fromRGB(203, 176, 129))
eyebrow.Text = "REALMS OF LUMIA  •  REGION"
local title = label("RegionName", 20, 38, 33, Enum.Font.Garamond, Color3.fromRGB(247, 219, 168))
local subtitle = label("RegionSubtitle", 57, 19, 12, Enum.Font.Gotham, Color3.fromRGB(220, 211, 192))

local function fade(show, duration)
    for _, tween in ipairs(activeTweens) do tween:Cancel() end
    table.clear(activeTweens)
    local info = TweenInfo.new(duration, Enum.EasingStyle.Quad,
        show and Enum.EasingDirection.Out or Enum.EasingDirection.In)
    for _, entry in ipairs({
        {panel, {BackgroundTransparency = show and 0.23 or 1}},
        {border, {Transparency = show and 0.2 or 1}},
        {eyebrow, {TextTransparency = show and 0.06 or 1}},
        {title, {TextTransparency = show and 0 or 1}},
        {subtitle, {TextTransparency = show and 0.12 or 1}},
    }) do
        local tween = TweenService:Create(entry[1], info, entry[2])
        table.insert(activeTweens, tween)
        tween:Play()
    end
end

local function announce(id)
    if displayed[id] then return end
    displayed[id] = true -- at most once per join, even if boundary flickers
    local definition = zoneConfig.Zones[id]
    if not definition then return end
    sequence += 1
    local token = sequence
    title.Text = definition.Name or id
    subtitle.Text = definition.Subtitle or ""
    panel.Visible = true
    fade(true, 0.48)
    task.delay(3.0, function()
        if token ~= sequence or not panel.Parent then return end
        fade(false, 0.75)
        task.delay(0.78, function()
            if token == sequence and panel.Parent then panel.Visible = false end
        end)
    end)
end

local function inside(part, position)
    if not part:IsA("BasePart") or not part:IsDescendantOf(workspace) then return false end
    local delta = part.CFrame:PointToObjectSpace(position)
    local half = part.Size * 0.5
    return math.abs(delta.X) <= half.X and math.abs(delta.Y) <= half.Y
        and math.abs(delta.Z) <= half.Z
end

local function majorRegion(position)
    -- Only the two real, expanded outdoor regions may override ForgottenForest.
    -- Ignore StarterVillage/ForestTrail/OldRoad/CreekBend/AncientStones.
    for _, region in ipairs(CollectionService:GetTagged("LumiaRegion")) do
        local id = region:GetAttribute("ZoneId") or region.Name
        if MAIN_ZONES[id] and id ~= "ForgottenForest" and inside(region, position) then
            return id
        end
    end
    return "ForgottenForest"
end

task.spawn(function()
    while gui.Parent do
        local character = player.Character
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        local root = character and character:FindFirstChild("HumanoidRootPart")
        if root and humanoid and humanoid.Health > 0 then
            local id = majorRegion(root.Position)
            if candidate ~= id then
                candidate = id
                candidateSince = os.clock()
            elseif not displayed[id] and os.clock() - candidateSince >= DWELL_SECONDS then
                announce(id)
            end
        end
        task.wait(0.4)
    end
end)
