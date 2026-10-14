-- REALMS OF LUMIA
-- Classic creature nameplates V2 (client-side UI only)
-- Mounts the bottom of each nameplate above the creature's actual 3D bounds.
-- Scales DOWN smoothly with camera distance; never gets bigger far away.
-- No DataStore writes and no changes to damage or spawning logic.

local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")

local TRACK_RANGE = 65
local NEAR_DISTANCE = 12
local MIN_SCALE = 0.42
local WIDTH = 224
local HEIGHT = 63
local UPDATE_INTERVAL = 0.10
local tracked = {}

local function roundCorners(parent, radius)
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, radius)
    corner.Parent = parent
end

local function addStroke(parent, color, thickness, transparency)
    local stroke = Instance.new("UIStroke")
    stroke.Color = color
    stroke.Thickness = thickness
    stroke.Transparency = transparency or 0
    stroke.Parent = parent
end

local function cleanup(model)
    local state = tracked[model]
    if not state then
        return
    end
    tracked[model] = nil

    for _, connection in ipairs(state.connections) do
        connection:Disconnect()
    end
    if state.plate then
        state.plate:Destroy()
    end
end

local function buildNameplate(model, state)
    if state.plate or model:GetAttribute("MonsterId") == nil then
        return
    end

    local humanoid = model:FindFirstChildOfClass("Humanoid")
    local root = model:FindFirstChild("HumanoidRootPart")
    if not humanoid or not root or not root:IsA("BasePart") then
        return
    end

    -- Anchor at the actual TOP of the model, not at a humanoid head or root
    -- height assumption. Works for small wolves, tall NPCs, and other rigs.
    local boxCFrame, boxSize = model:GetBoundingBox()
    local halfWorldY = (
        math.abs(boxCFrame.RightVector.Y) * boxSize.X
        + math.abs(boxCFrame.UpVector.Y) * boxSize.Y
        + math.abs(boxCFrame.LookVector.Y) * boxSize.Z
    ) * 0.5
    local creatureTopY = boxCFrame.Position.Y + halfWorldY
    local offsetY = math.max(1.0, creatureTopY - root.Position.Y + 0.55)

    -- Suppress Roblox's plain NPC name/health UI, not player nameplates.
    humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None

    local plate = Instance.new("BillboardGui")
    plate.Name = "LumiaClassicNameplate"
    plate.Adornee = root
    plate.Size = UDim2.fromOffset(WIDTH, HEIGHT)
    -- Bottom-center of the plate sits at the point ABOVE the creature.
    plate.SizeOffset = Vector2.new(0, 0.5)
    plate.StudsOffsetWorldSpace = Vector3.new(0, offsetY, 0)
    plate.MaxDistance = TRACK_RANGE
    plate.AlwaysOnTop = false
    plate.LightInfluence = 0
    plate.ResetOnSpawn = false
    plate.Parent = root
    state.plate = plate

    local canvas = Instance.new("Frame")
    canvas.Name = "Canvas"
    canvas.BackgroundTransparency = 1
    canvas.Size = UDim2.fromOffset(WIDTH, HEIGHT)
    canvas.Parent = plate

    -- Scale the CONTENTS together with the billboard. Updating only the
    -- BillboardGui.Size would leave fixed-pixel text and frames unscaled.
    local uiScale = Instance.new("UIScale")
    uiScale.Name = "DistanceScale"
    uiScale.Scale = 1
    uiScale.Parent = canvas

    state.root = root
    state.humanoid = humanoid
    state.uiScale = uiScale

    local levelFrame = Instance.new("Frame")
    levelFrame.Name = "LevelBadge"
    levelFrame.Size = UDim2.fromOffset(40, 25)
    levelFrame.Position = UDim2.fromOffset(5, 4)
    levelFrame.BackgroundColor3 = Color3.fromRGB(25, 28, 36)
    levelFrame.BorderSizePixel = 0
    levelFrame.Parent = canvas
    roundCorners(levelFrame, 5)
    addStroke(levelFrame, Color3.fromRGB(174, 136, 72), 1)

    local levelText = Instance.new("TextLabel")
    levelText.Name = "Level"
    levelText.Size = UDim2.fromScale(1, 1)
    levelText.BackgroundTransparency = 1
    levelText.Font = Enum.Font.GothamBold
    levelText.TextSize = 13
    levelText.TextColor3 = Color3.fromRGB(246, 219, 161)
    levelText.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    levelText.TextStrokeTransparency = 0.45
    levelText.Parent = levelFrame

    local nameText = Instance.new("TextLabel")
    nameText.Name = "CreatureName"
    nameText.BackgroundTransparency = 1
    nameText.Position = UDim2.fromOffset(49, 0)
    nameText.Size = UDim2.new(1, -53, 0, 31)
    nameText.Font = Enum.Font.Garamond
    nameText.TextSize = 22
    nameText.TextColor3 = Color3.fromRGB(255, 224, 165)
    nameText.TextStrokeColor3 = Color3.fromRGB(5, 5, 8)
    nameText.TextStrokeTransparency = 0.18
    nameText.TextTruncate = Enum.TextTruncate.AtEnd
    nameText.TextXAlignment = Enum.TextXAlignment.Left
    nameText.Parent = canvas

    local outer = Instance.new("Frame")
    outer.Name = "HealthBorder"
    outer.Position = UDim2.fromOffset(12, 31)
    outer.Size = UDim2.new(1, -24, 0, 24)
    outer.BackgroundColor3 = Color3.fromRGB(19, 21, 28)
    outer.BorderSizePixel = 0
    outer.Parent = canvas
    roundCorners(outer, 5)
    addStroke(outer, Color3.fromRGB(161, 125, 70), 1)

    local inner = Instance.new("Frame")
    inner.Name = "HealthBackground"
    inner.Position = UDim2.fromOffset(3, 3)
    inner.Size = UDim2.new(1, -6, 1, -6)
    inner.BackgroundColor3 = Color3.fromRGB(49, 23, 25)
    inner.BorderSizePixel = 0
    inner.ClipsDescendants = true
    inner.Parent = outer
    roundCorners(inner, 3)

    local fill = Instance.new("Frame")
    fill.Name = "HealthFill"
    fill.BackgroundColor3 = Color3.fromRGB(181, 51, 53)
    fill.BorderSizePixel = 0
    fill.Size = UDim2.fromScale(1, 1)
    fill.Parent = inner
    roundCorners(fill, 3)

    local gradient = Instance.new("UIGradient")
    gradient.Rotation = 90
    gradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(231, 75, 75)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(112, 29, 32)),
    })
    gradient.Parent = fill

    local healthText = Instance.new("TextLabel")
    healthText.Name = "HealthText"
    healthText.BackgroundTransparency = 1
    healthText.Size = UDim2.fromScale(1, 1)
    healthText.Font = Enum.Font.GothamBold
    healthText.TextSize = 12
    healthText.TextColor3 = Color3.fromRGB(255, 250, 235)
    healthText.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    healthText.TextStrokeTransparency = 0.15
    healthText.ZIndex = 3
    healthText.Parent = inner

    local function updateName()
        nameText.Text = model.Name
        levelText.Text = "Lv " .. tostring(model:GetAttribute("MonsterLevel") or "?")
    end

    local function updateHealth()
        local maximum = math.max(1, humanoid.MaxHealth)
        local current = math.clamp(humanoid.Health, 0, maximum)
        fill.Size = UDim2.fromScale(current / maximum, 1)
        healthText.Text = string.format("%d / %d", math.ceil(current), math.ceil(maximum))
    end

    local function listen(connection)
        table.insert(state.connections, connection)
    end

    listen(model:GetPropertyChangedSignal("Name"):Connect(updateName))
    listen(model:GetAttributeChangedSignal("MonsterLevel"):Connect(updateName))
    listen(humanoid.HealthChanged:Connect(updateHealth))
    listen(humanoid:GetPropertyChangedSignal("MaxHealth"):Connect(updateHealth))

    updateName()
    updateHealth()
end

local function watch(model)
    if not model:IsA("Model") or tracked[model] then
        return
    end

    local state = {connections = {}, plate = nil}
    tracked[model] = state

    -- MonsterId/parts can replicate slightly later than the model itself.
    table.insert(state.connections, model:GetAttributeChangedSignal("MonsterId"):Connect(function()
        buildNameplate(model, state)
    end))
    table.insert(state.connections, model.ChildAdded:Connect(function()
        buildNameplate(model, state)
    end))
    task.defer(function()
        if tracked[model] == state then
            buildNameplate(model, state)
        end
    end)
end

local folder = Workspace:WaitForChild("LumiaMonsters")

folder.ChildAdded:Connect(watch)
folder.ChildRemoved:Connect(cleanup)

for _, model in ipairs(folder:GetChildren()) do
    watch(model)
end

-- One throttled loop for ALL monsters, instead of one RenderStepped
-- connection for every single creature. This scales to larger zones.
local timeSinceUpdate = 0
RunService.Heartbeat:Connect(function(dt)
    timeSinceUpdate += dt
    if timeSinceUpdate < UPDATE_INTERVAL then
        return
    end
    timeSinceUpdate = 0

    local camera = Workspace.CurrentCamera
    if not camera then
        return
    end

    local cameraPosition = camera.CFrame.Position
    for model, state in pairs(tracked) do
        local plate = state.plate
        local root = state.root
        local humanoid = state.humanoid
        local uiScale = state.uiScale
        if plate and root and humanoid and uiScale then
            local distance = (cameraPosition - root.Position).Magnitude
            local visible = distance <= TRACK_RANGE and humanoid.Health > 0
            plate.Enabled = visible
            if visible then
                local fraction = math.clamp(
                    (distance - NEAR_DISTANCE) / (TRACK_RANGE - NEAR_DISTANCE),
                    0,
                    1
                )
                local scale = 1 - (1 - MIN_SCALE) * fraction
                uiScale.Scale = scale
                plate.Size = UDim2.fromOffset(
                    math.max(1, math.floor(WIDTH * scale + 0.5)),
                    math.max(1, math.floor(HEIGHT * scale + 0.5))
                )
            end
        end
    end
end)

print("[Lumia] Classic creature nameplates V2 ready - above creatures, distance scaled")
