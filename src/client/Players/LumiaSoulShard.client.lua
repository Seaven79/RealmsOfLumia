-- REALMS OF LUMIA - SOUL SHARD CLIENT
-- Death is server-authoritative: SoulShard.lua strips the profile and drops a
-- crystal where the body fell. This controller makes that loss legible.
-- It never decides what is lost or whether a shard may be recovered.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local network = ReplicatedStorage:WaitForChild("Lumia"):WaitForChild("SoulShardNetwork", 20)
if not network then
    warn("[Lumia - Soul Shard] SoulShardNetwork missing")
    return
end

local droppedRemote = network:WaitForChild("OnShardDropped", 20)
local recoveredRemote = network:WaitForChild("OnShardRecovered", 20)
if not droppedRemote or not recoveredRemote then
    warn("[Lumia - Soul Shard] Shard events missing")
    return
end

local old = playerGui:FindFirstChild("LumiaSoulShard")
if old then old:Destroy() end

local gui = Instance.new("ScreenGui")
gui.Name = "LumiaSoulShard"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 46
gui.Parent = playerGui

-- Palette kept in step with the achievement toast and character sheet.
local PANEL_BG = Color3.fromRGB(19, 24, 34)
local GOLD_STROKE = Color3.fromRGB(178, 140, 81)
local LOSS_STROKE = Color3.fromRGB(196, 96, 84)
local SHARD_BLUE = Color3.fromRGB(120, 200, 255)
local RECOVER_GREEN = Color3.fromRGB(136, 213, 169)
local TITLE_GOLD = Color3.fromRGB(244, 223, 174)
local BODY_GREY = Color3.fromRGB(212, 208, 198)

local function fmt(value)
    local n = math.floor(tonumber(value) or 0)
    local sign = n < 0 and "-" or ""
    n = math.abs(n)
    local str = tostring(n)
    local out = str:reverse():gsub("(%d%d%d)", "%1,"):reverse()
    -- A trailing comma appears when the digit count is an exact multiple of 3.
    out = out:gsub("^,", "")
    return sign .. out
end

--------------------------------------------------------------------------------
-- Loss / recovery banner (top centre, clear of the minimap and micro menu)
--------------------------------------------------------------------------------

local banner = Instance.new("Frame")
banner.Name = "SoulShardBanner"
banner.AnchorPoint = Vector2.new(0.5, 0)
banner.Position = UDim2.new(0.5, 0, 0, 138)
banner.Size = UDim2.fromOffset(560, 128)
banner.BackgroundTransparency = 1
banner.Visible = false
banner.Parent = gui

local bannerPanel = Instance.new("Frame")
bannerPanel.Name = "Panel"
bannerPanel.Size = UDim2.fromScale(1, 1)
bannerPanel.BackgroundColor3 = PANEL_BG
bannerPanel.BackgroundTransparency = 0.08
bannerPanel.BorderSizePixel = 0
bannerPanel.Parent = banner

local bannerCorner = Instance.new("UICorner")
bannerCorner.CornerRadius = UDim.new(0, 12)
bannerCorner.Parent = bannerPanel

local bannerStroke = Instance.new("UIStroke")
bannerStroke.Color = LOSS_STROKE
bannerStroke.Thickness = 1.5
bannerStroke.Parent = bannerPanel

local bannerIcon = Instance.new("TextLabel")
bannerIcon.BackgroundTransparency = 1
bannerIcon.Position = UDim2.fromOffset(18, 30)
bannerIcon.Size = UDim2.fromOffset(52, 52)
bannerIcon.Font = Enum.Font.Garamond
bannerIcon.TextSize = 40
bannerIcon.TextColor3 = SHARD_BLUE
bannerIcon.Text = "◈"
bannerIcon.Parent = bannerPanel

local bannerTitle = Instance.new("TextLabel")
bannerTitle.BackgroundTransparency = 1
bannerTitle.Position = UDim2.fromOffset(78, 16)
bannerTitle.Size = UDim2.new(1, -96, 0, 26)
bannerTitle.Font = Enum.Font.GothamBold
bannerTitle.TextXAlignment = Enum.TextXAlignment.Left
bannerTitle.TextSize = 17
bannerTitle.TextColor3 = TITLE_GOLD
bannerTitle.Text = ""
bannerTitle.Parent = bannerPanel

local bannerLine = Instance.new("TextLabel")
bannerLine.BackgroundTransparency = 1
bannerLine.Position = UDim2.fromOffset(78, 44)
bannerLine.Size = UDim2.new(1, -96, 0, 22)
bannerLine.Font = Enum.Font.Garamond
bannerLine.TextXAlignment = Enum.TextXAlignment.Left
bannerLine.TextSize = 20
bannerLine.TextColor3 = Color3.fromRGB(255, 241, 212)
bannerLine.Text = ""
bannerLine.Parent = bannerPanel

local bannerHint = Instance.new("TextLabel")
bannerHint.BackgroundTransparency = 1
bannerHint.Position = UDim2.fromOffset(78, 70)
bannerHint.Size = UDim2.new(1, -96, 0, 30)
bannerHint.Font = Enum.Font.Gotham
bannerHint.TextXAlignment = Enum.TextXAlignment.Left
bannerHint.TextWrapped = true
bannerHint.TextSize = 12
bannerHint.TextColor3 = BODY_GREY
bannerHint.Text = ""
bannerHint.Parent = bannerPanel

local bannerSequence = 0
local bannerTweens = {}

local function cancelBannerTweens()
    for _, tween in ipairs(bannerTweens) do
        tween:Cancel()
    end
    table.clear(bannerTweens)
end

local function showBanner(kind, title, line, hint)
    bannerSequence += 1
    local current = bannerSequence
    cancelBannerTweens()

    bannerStroke.Color = kind == "loss" and LOSS_STROKE or RECOVER_GREEN
    bannerIcon.Text = kind == "loss" and "◈" or "✦"
    bannerIcon.TextColor3 = kind == "loss" and SHARD_BLUE or RECOVER_GREEN
    bannerTitle.Text = title
    bannerTitle.TextColor3 = kind == "loss" and TITLE_GOLD or RECOVER_GREEN
    bannerLine.Text = line
    bannerHint.Text = hint

    banner.Visible = true
    bannerPanel.BackgroundTransparency = 0.4
    banner.Position = UDim2.new(0.5, 0, 0, 108)

    local slide = TweenService:Create(banner, TweenInfo.new(0.34, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Position = UDim2.new(0.5, 0, 0, 138),
    })
    bannerTweens[#bannerTweens + 1] = slide
    slide:Play()

    local fade = TweenService:Create(bannerPanel, TweenInfo.new(0.34), {
        BackgroundTransparency = 0.08,
    })
    bannerTweens[#bannerTweens + 1] = fade
    fade:Play()

    local hold = kind == "loss" and 7.5 or 4.6
    task.delay(hold, function()
        if current ~= bannerSequence or not banner.Parent then return end
        local out = TweenService:Create(bannerPanel, TweenInfo.new(0.4), {
            BackgroundTransparency = 1,
        })
        out:Play()
        task.delay(0.42, function()
            if current == bannerSequence and banner.Parent then
                banner.Visible = false
            end
        end)
    end)
end

--------------------------------------------------------------------------------
-- Waypoint chip, anchored under the minimap so it never fights other HUD
--------------------------------------------------------------------------------

local tracker = Instance.new("Frame")
tracker.Name = "SoulShardTracker"
tracker.AnchorPoint = Vector2.new(1, 0)
tracker.Position = UDim2.new(1, -9, 0, 214)
tracker.Size = UDim2.fromOffset(200, 50)
tracker.BackgroundColor3 = PANEL_BG
tracker.BackgroundTransparency = 0.12
tracker.BorderSizePixel = 0
tracker.Visible = false
tracker.Parent = gui

local trackerCorner = Instance.new("UICorner")
trackerCorner.CornerRadius = UDim.new(0, 10)
trackerCorner.Parent = tracker

local trackerStroke = Instance.new("UIStroke")
trackerStroke.Color = SHARD_BLUE
trackerStroke.Thickness = 1.25
trackerStroke.Transparency = 0.35
trackerStroke.Parent = tracker

local trackerArrow = Instance.new("TextLabel")
trackerArrow.BackgroundTransparency = 1
trackerArrow.AnchorPoint = Vector2.new(0.5, 0.5)
trackerArrow.Position = UDim2.fromOffset(18, 25)
trackerArrow.Size = UDim2.fromOffset(24, 24)
trackerArrow.Font = Enum.Font.GothamBlack
trackerArrow.TextSize = 20
trackerArrow.TextColor3 = SHARD_BLUE
trackerArrow.Text = "▲"
trackerArrow.Parent = tracker

local trackerLabel = Instance.new("TextLabel")
trackerLabel.BackgroundTransparency = 1
trackerLabel.Position = UDim2.fromOffset(30, 5)
trackerLabel.Size = UDim2.fromOffset(162, 18)
trackerLabel.Font = Enum.Font.GothamBold
trackerLabel.TextSize = 11
trackerLabel.TextXAlignment = Enum.TextXAlignment.Left
trackerLabel.TextColor3 = Color3.fromRGB(180, 220, 255)
trackerLabel.Text = "SOUL SHARD"
trackerLabel.Parent = tracker

local trackerDistance = Instance.new("TextLabel")
trackerDistance.BackgroundTransparency = 1
trackerDistance.Position = UDim2.fromOffset(30, 23)
trackerDistance.Size = UDim2.fromOffset(162, 20)
trackerDistance.Font = Enum.Font.Gotham
trackerDistance.TextSize = 13
trackerDistance.TextXAlignment = Enum.TextXAlignment.Left
trackerDistance.TextColor3 = Color3.fromRGB(255, 230, 140)
trackerDistance.Text = ""
trackerDistance.Parent = tracker

--------------------------------------------------------------------------------
-- State
--------------------------------------------------------------------------------

local shardPosition = nil -- Vector3 of the last known shard location
local shardModel = nil

local function findShardModel()
    local folder = Workspace:FindFirstChild("LumiaSoulShards")
    if not folder then return nil end
    for _, model in ipairs(folder:GetChildren()) do
        if model:GetAttribute("LumiaShardOwnerUserId") == player.UserId then
            return model
        end
    end
    return nil
end

local function shardWorldPosition()
    if shardModel and shardModel.Parent then
        local crystal = shardModel:FindFirstChild("Crystal")
        if crystal and crystal:IsA("BasePart") then
            return crystal.Position
        end
    end
    return shardPosition
end

-- A thin client-only light pillar. The crystal's own billboard only reads at
-- short range; the pillar is what makes the drop findable across a valley.
local function addBeacon(model)
    local crystal = model:FindFirstChild("Crystal")
    if not crystal or not crystal:IsA("BasePart") then return end
    if crystal:FindFirstChild("LumiaShardBeacon") then return end

    local beacon = Instance.new("Part")
    beacon.Name = "LumiaShardBeacon"
    beacon.Size = Vector3.new(1.1, 220, 1.1)
    beacon.Anchored = true
    beacon.CanCollide = false
    beacon.CanTouch = false
    beacon.CanQuery = false
    beacon.CastShadow = false
    beacon.Material = Enum.Material.Neon
    beacon.Color = SHARD_BLUE
    beacon.Transparency = 0.87
    beacon.CFrame = crystal.CFrame * CFrame.new(0, 110, 0)
    beacon.Parent = model
end

local function clearTracker()
    shardPosition = nil
    shardModel = nil
    tracker.Visible = false
end

local function updateTracker()
    if not shardPosition then
        tracker.Visible = false
        return
    end

    local character = player.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    if not root or not root:IsA("BasePart") then
        tracker.Visible = false
        return
    end

    if not shardModel or not shardModel.Parent then
        shardModel = findShardModel()
        if shardModel then addBeacon(shardModel) end
    end

    local target = shardWorldPosition()
    if not target then
        -- The crystal left the world. Recovery is reported by the server, so
        -- treat a vanished model without an event as an end of the objective.
        clearTracker()
        return
    end

    local delta = target - root.Position
    local flat = Vector3.new(delta.X, 0, delta.Z)
    local distance = flat.Magnitude

    -- Bearing convention matches the minimap: -Z is north, +X is east.
    trackerArrow.Rotation = math.deg(math.atan2(delta.X, -delta.Z))
    trackerDistance.Text = fmt(distance) .. " studs"
    tracker.Visible = true
end

--------------------------------------------------------------------------------
-- Events
--------------------------------------------------------------------------------

droppedRemote.OnClientEvent:Connect(function(gold, xp, itemCount, position)
    gold = tonumber(gold) or 0
    xp = tonumber(xp) or 0
    itemCount = tonumber(itemCount) or 0

    shardPosition = typeof(position) == "Vector3" and position or nil
    shardModel = findShardModel()
    if shardModel then
        addBeacon(shardModel)
        local crystal = shardModel:FindFirstChild("Crystal")
        if crystal and crystal:IsA("BasePart") then
            shardPosition = crystal.Position
        end
    end

    local parts = {}
    if gold > 0 then parts[#parts + 1] = fmt(gold) .. " gold" end
    if xp > 0 then parts[#parts + 1] = fmt(xp) .. " xp" end
    if itemCount > 0 then
        parts[#parts + 1] = fmt(itemCount) .. (itemCount == 1 and " item" or " items")
    end

    showBanner(
        "loss",
        "SOUL SHARD LOST",
        table.concat(parts, "  •  "),
        "Your belongings are bound to the crystal where you fell. Return to it to reclaim them."
    )

    task.defer(updateTracker)
end)

recoveredRemote.OnClientEvent:Connect(function(gold, xp, itemCount)
    gold = tonumber(gold) or 0
    xp = tonumber(xp) or 0
    itemCount = tonumber(itemCount) or 0

    clearTracker()

    local parts = {}
    if gold > 0 then parts[#parts + 1] = "+" .. fmt(gold) .. " gold" end
    if xp > 0 then parts[#parts + 1] = "+" .. fmt(xp) .. " xp" end
    if itemCount > 0 then
        parts[#parts + 1] = "+" .. fmt(itemCount) .. (itemCount == 1 and " item" or " items")
    end

    showBanner(
        "recover",
        "SOUL SHARD RECOVERED",
        table.concat(parts, "  •  "),
        "Everything you carried has been returned."
    )
end)

local elapsed = 0
RunService.Heartbeat:Connect(function(dt)
    elapsed += dt
    if elapsed < 0.1 then return end
    elapsed = 0
    updateTracker()
end)

updateTracker()
print("[Lumia - Soul Shard] Death and recovery UI ready")
