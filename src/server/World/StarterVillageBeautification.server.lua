-- REALMS OF LUMIA - STARTER VILLAGE BEAUTIFICATION
-- Runtime-only additive props to make the starting area feel warmer and more alive.
-- Does not delete or resize existing map geometry.

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local rng = Random.new(41531)

local SpawnConfig = require(ReplicatedStorage:WaitForChild("Lumia")
    :WaitForChild("Shared"):WaitForChild("World"):WaitForChild("PlayerSpawnConfig"))

local function findAnchor()
    local sceneryAnchor = Workspace:FindFirstChild("LumiaSceneryAnchor", true)
    if sceneryAnchor and sceneryAnchor:IsA("BasePart") then
        return sceneryAnchor.Position
    end
    local marker = Workspace:FindFirstChild(SpawnConfig.ManualAnchorName, true)
    if marker and marker:IsA("BasePart") then
        return marker.Position
    end

    for _, item in ipairs(Workspace:GetDescendants()) do
        if item:IsA("SpawnLocation") then
            return item.Position
        end
    end

    local forest = Workspace:FindFirstChild("ForgottenForest")
    if forest and forest:IsA("Model") then
        local cf = forest:GetBoundingBox()
        return cf.Position
    end

    return Vector3.new(0, 4, 0)
end

local old = Workspace:FindFirstChild("LumiaStarterScenery")
if old then
    old:Destroy()
end

local folder = Instance.new("Folder")
folder.Name = "LumiaStarterScenery"
folder.Parent = Workspace

local anchor = findAnchor()
local forest = Workspace:FindFirstChild("ForgottenForest")
local mainGrass = forest and forest:FindFirstChild("Grassland", true)
if mainGrass and mainGrass:IsA("BasePart") then
    -- Align the props to the known flat forest floor instead of the spawn pad height.
    anchor = Vector3.new(anchor.X, mainGrass.Position.Y + mainGrass.Size.Y * 0.5,
        anchor.Z)
end

local function addPart(name, size, cf, color, material, shape)
    local part = Instance.new("Part")
    part.Name = name
    part.Size = size
    part.CFrame = cf
    part.Color = color
    part.Material = material or Enum.Material.SmoothPlastic
    part.Shape = shape or Enum.PartType.Block
    part.Anchored = true
    part.CanCollide = false
    part.CanTouch = false
    part.CanQuery = false
    part.TopSurface = Enum.SurfaceType.Smooth
    part.BottomSurface = Enum.SurfaceType.Smooth
    part.Parent = folder
    return part
end

local function campfire(position)
    local base = addPart("CampfireBase", Vector3.new(4.2, 0.35, 4.2), CFrame.new(position),
        Color3.fromRGB(89, 82, 77), Enum.Material.Slate)

    for i = 1, 8 do
        local angle = math.rad((i - 1) * 45)
        local stonePos = position + Vector3.new(math.cos(angle) * 1.5, 0.35, math.sin(angle) * 1.5)
        addPart("CampfireStone", Vector3.new(0.65, 0.45, 0.6), CFrame.new(stonePos),
            Color3.fromRGB(104, 101, 109), Enum.Material.Rock)
    end

    local log1 = addPart("CampfireLog", Vector3.new(2.3, 0.35, 0.45),
        CFrame.new(position + Vector3.new(0, 0.28, 0)) * CFrame.Angles(0, math.rad(26), math.rad(6)),
        Color3.fromRGB(108, 82, 52), Enum.Material.Wood)
    local log2 = addPart("CampfireLog", Vector3.new(2.2, 0.35, 0.45),
        CFrame.new(position + Vector3.new(0, 0.28, 0)) * CFrame.Angles(0, math.rad(-32), math.rad(-5)),
        Color3.fromRGB(92, 73, 46), Enum.Material.Wood)

    local flame = addPart("CampfireFlame", Vector3.new(0.95, 1.2, 0.95),
        CFrame.new(position + Vector3.new(0, 1.08, 0)), Color3.fromRGB(255, 181, 83), Enum.Material.Neon,
        Enum.PartType.Ball)

    local light = Instance.new("PointLight")
    light.Color = Color3.fromRGB(255, 194, 116)
    light.Brightness = 2.1
    light.Range = 18
    light.Parent = flame

    local fire = Instance.new("ParticleEmitter")
    fire.Texture = "rbxasset://textures/particles/fire_main.dds"
    fire.Lifetime = NumberRange.new(0.45, 0.8)
    fire.Rate = 24
    fire.Speed = NumberRange.new(0.8, 1.5)
    fire.Rotation = NumberRange.new(-30, 30)
    fire.RotSpeed = NumberRange.new(-20, 20)
    fire.SpreadAngle = Vector2.new(10, 10)
    fire.Size = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.55),
        NumberSequenceKeypoint.new(1, 0.05),
    })
    fire.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.1),
        NumberSequenceKeypoint.new(1, 1),
    })
    fire.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 226, 150)),
        ColorSequenceKeypoint.new(0.55, Color3.fromRGB(255, 140, 61)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(122, 51, 24)),
    })
    fire.Parent = flame

    local smoke = Instance.new("ParticleEmitter")
    smoke.Texture = "rbxasset://textures/particles/smoke_main.dds"
    smoke.Lifetime = NumberRange.new(1.2, 1.8)
    smoke.Rate = 8
    smoke.Speed = NumberRange.new(0.6, 1.2)
    smoke.SpreadAngle = Vector2.new(12, 12)
    smoke.Size = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.35),
        NumberSequenceKeypoint.new(1, 1.55),
    })
    smoke.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.65),
        NumberSequenceKeypoint.new(1, 1),
    })
    smoke.Color = ColorSequence.new(Color3.fromRGB(120, 118, 120))
    smoke.Parent = flame

    return base, log1, log2
end

local function lanternPost(position)
    local post = addPart("LanternPost", Vector3.new(0.35, 4.6, 0.35),
        CFrame.new(position + Vector3.new(0, 2.3, 0)), Color3.fromRGB(101, 78, 51), Enum.Material.Wood)
    local arm = addPart("LanternArm", Vector3.new(1.5, 0.18, 0.18),
        CFrame.new(position + Vector3.new(0.55, 4.2, 0)), Color3.fromRGB(101, 78, 51), Enum.Material.Wood)
    local lantern = addPart("Lantern", Vector3.new(0.55, 0.75, 0.55),
        CFrame.new(position + Vector3.new(1.1, 3.65, 0)), Color3.fromRGB(246, 208, 121), Enum.Material.Glass)
    lantern.Transparency = 0.3
    local light = Instance.new("PointLight")
    light.Color = Color3.fromRGB(255, 223, 160)
    light.Brightness = 1.35
    light.Range = 16
    light.Parent = lantern
    return post, arm, lantern
end

local function fenceSegment(position, yaw)
    addPart("FencePost", Vector3.new(0.25, 1.4, 0.25),
        CFrame.new(position + Vector3.new(-1.2, 0.7, 0)) * CFrame.Angles(0, yaw, 0),
        Color3.fromRGB(105, 82, 57), Enum.Material.Wood)
    addPart("FencePost", Vector3.new(0.25, 1.4, 0.25),
        CFrame.new(position + Vector3.new(1.2, 0.7, 0)) * CFrame.Angles(0, yaw, 0),
        Color3.fromRGB(105, 82, 57), Enum.Material.Wood)
    addPart("FenceRail", Vector3.new(2.7, 0.16, 0.16),
        CFrame.new(position + Vector3.new(0, 1.0, 0)) * CFrame.Angles(0, yaw, 0),
        Color3.fromRGB(124, 96, 65), Enum.Material.Wood)
    addPart("FenceRail", Vector3.new(2.7, 0.16, 0.16),
        CFrame.new(position + Vector3.new(0, 0.55, 0)) * CFrame.Angles(0, yaw, 0),
        Color3.fromRGB(124, 96, 65), Enum.Material.Wood)
end

local function crate(position, size)
    addPart("VillageCrate", size or Vector3.new(1.3, 1.2, 1.3), CFrame.new(position + Vector3.new(0, (size and size.Y or 1.2) / 2, 0)),
        Color3.fromRGB(122, 92, 56), Enum.Material.WoodPlanks)
end

local function flowerClump(position)
    for _, offset in ipairs({
        Vector3.new(0, 0, 0),
        Vector3.new(0.45, 0, 0.2),
        Vector3.new(-0.35, 0, -0.2),
        Vector3.new(0.15, 0, -0.42),
    }) do
        local stemHeight = 0.55 + rng:NextNumber() * 0.25
        addPart("FlowerStem", Vector3.new(0.05, stemHeight, 0.05),
            CFrame.new(position + offset + Vector3.new(0, stemHeight / 2, 0)), Color3.fromRGB(80, 124, 70), Enum.Material.Grass)
        addPart("FlowerBloom", Vector3.new(0.16, 0.16, 0.16),
            CFrame.new(position + offset + Vector3.new(0, stemHeight, 0)),
            ({Color3.fromRGB(232, 183, 194), Color3.fromRGB(236, 227, 205), Color3.fromRGB(190, 181, 241)})[rng:NextInteger(1, 3)],
            Enum.Material.SmoothPlastic, Enum.PartType.Ball)
    end
end

local function pathStone(position, size)
    local stone = addPart("PathStone", size or Vector3.new(2.2, 0.25, 1.4),
        CFrame.new(position + Vector3.new(0, 0.12, 0)) * CFrame.Angles(0, math.rad(rng:NextInteger(-20, 20)), 0),
        Color3.fromRGB(124, 119, 112), Enum.Material.Slate)
    stone.Transparency = 0.05
end

local function signBoard(position, text)
    local post = addPart("VillageSignPost", Vector3.new(0.3, 4.6, 0.3),
        CFrame.new(position + Vector3.new(0, 2.3, 0)), Color3.fromRGB(104, 79, 52), Enum.Material.Wood)
    local board = addPart("VillageSign", Vector3.new(4.6, 1.6, 0.24),
        CFrame.new(position + Vector3.new(0, 4.1, 0)), Color3.fromRGB(82, 61, 40), Enum.Material.WoodPlanks)
    local surf = Instance.new("SurfaceGui")
    surf.Face = Enum.NormalId.Front
    surf.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
    surf.PixelsPerStud = 40
    surf.Parent = board
    local label = Instance.new("TextLabel")
    label.BackgroundTransparency = 1
    label.Size = UDim2.fromScale(1, 1)
    label.Font = Enum.Font.Garamond
    label.TextScaled = true
    label.TextColor3 = Color3.fromRGB(242, 224, 188)
    label.TextStrokeTransparency = 0.8
    label.Text = text
    label.Parent = surf
    return post, board
end

-- Deterministic decorations selected using the local seeded Random instance.

campfire(anchor + Vector3.new(8, 0, 8))
lanternPost(anchor + Vector3.new(4, 0, 2))
lanternPost(anchor + Vector3.new(12, 0, 4))
lanternPost(anchor + Vector3.new(-6, 0, -2))
signBoard(anchor + Vector3.new(-10, 0, 6), "Lumia Hamlet")
crate(anchor + Vector3.new(10, 0, 5), Vector3.new(1.35, 1.05, 1.35))
crate(anchor + Vector3.new(11.6, 0, 6.1), Vector3.new(1.0, 0.9, 1.0))
crate(anchor + Vector3.new(9.6, 0, 6.6), Vector3.new(0.9, 0.75, 0.9))

for i = -2, 2 do
    fenceSegment(anchor + Vector3.new(-8 + i * 2.8, 0, -6), 0)
end

for _, offset in ipairs({
    Vector3.new(0, 0, 0),
    Vector3.new(2.6, 0, 1.6),
    Vector3.new(5.4, 0, 3.1),
    Vector3.new(8.2, 0, 4.8),
    Vector3.new(11.1, 0, 6.7),
}) do
    pathStone(anchor + Vector3.new(-2, 0, 1) + offset)
end

for _, offset in ipairs({
    Vector3.new(-5.5, 0, 4.3),
    Vector3.new(-3.5, 0, 5.5),
    Vector3.new(2.2, 0, -3.8),
    Vector3.new(6.4, 0, 0.6),
    Vector3.new(12.4, 0, 8.2),
    Vector3.new(-9.2, 0, 7.1),
}) do
    flowerClump(anchor + offset)
end

print("[Lumia - Starter Village] Starter-area beautification props created")
