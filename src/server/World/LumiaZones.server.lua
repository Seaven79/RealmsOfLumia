-- REALMS OF LUMIA V15 - CONNECTED OUTER REGIONS
-- Adds land to the east of the existing Grassland. No inter-zone teleport.
-- All regions are freely explorable. Recommended monster levels, not invisible
-- barriers or teleports, convey progression risk.
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Services = script.Parent.Parent
local PlayerData = require(Services:WaitForChild("Players"):WaitForChild("PlayerDataService"))
local Achievements = require(Services:WaitForChild("Progression"):WaitForChild("AchievementService"))
local ZoneConfig = require(ReplicatedStorage:WaitForChild("Lumia")
    :WaitForChild("Shared"):WaitForChild("World"):WaitForChild("ZoneConfig"))
local root = ReplicatedStorage:WaitForChild("Lumia")
local network = root:FindFirstChild("ZoneNetwork") or Instance.new("Folder")
network.Name = "ZoneNetwork"
network.Parent = root
local notice = network:FindFirstChild("ZoneNotice") or Instance.new("RemoteEvent")
notice.Name = "ZoneNotice"
notice.Parent = network

local old = Workspace:FindFirstChild("LumiaOpenWorldV15")
if old then old:Destroy() end
local folder = Instance.new("Folder")
folder.Name = "LumiaOpenWorldV15"
folder.Parent = Workspace
local regions = Instance.new("Folder")
regions.Name = "Regions"
regions.Parent = folder
local scenery = Instance.new("Folder")
scenery.Name = "Scenery"
scenery.Parent = folder

local function part(parent, name, size, cf, material, color, collidable)
    local p = Instance.new("Part")
    p.Name = name
    p.Size = size
    p.CFrame = cf
    p.Material = material
    p.Color = color
    p.Anchored = true
    p.CanCollide = collidable == true
    p.CanTouch = false
    p.CanQuery = collidable == true
    p.CastShadow = true
    p.TopSurface = Enum.SurfaceType.Smooth
    p.BottomSurface = Enum.SurfaceType.Smooth
    p.Parent = parent
    return p
end

local function regionVolume(id, cf, size)
    local def = ZoneConfig.Zones[id]
    local p = part(regions, id, size, cf, Enum.Material.SmoothPlastic,
        Color3.fromRGB(255, 255, 255), false)
    p.Transparency = 1
    p:SetAttribute("ZoneId", id)
    p:SetAttribute("ZoneName", def.Name)
    p:SetAttribute("ZoneSubtitle", def.Subtitle)
    p:SetAttribute("RequiredLevel", def.MinLevel or 1)
    CollectionService:AddTag(p, "LumiaRegion")
    return {Id = id, Part = p, Level = def.MinLevel or 1}
end

local function magicalArch(cf, label, level)
    local center = cf.Position
    for _, side in ipairs({-1, 1}) do
        local post = part(scenery, "AncientGatePillar", Vector3.new(2.6, 15, 3),
            cf * CFrame.new(0, 7, side * 16), Enum.Material.Slate,
            Color3.fromRGB(82, 86, 88), false)
        local glyph = part(scenery, "RunicInset", Vector3.new(0.5, 5, 2.1),
            cf * CFrame.new(0.7, 9, side * 16), Enum.Material.Neon,
            Color3.fromRGB(86, 180, 215), false)
        glyph.Transparency = 0.28
    end
    part(scenery, "GateLintel", Vector3.new(3, 2.8, 36),
        cf * CFrame.new(0, 14.8, 0), Enum.Material.Rock,
        Color3.fromRGB(94, 92, 96), false)
    local beacon = part(scenery, "GateBeacon", Vector3.new(2, 2, 2),
        cf * CFrame.new(0, 17.3, 0), Enum.Material.Neon,
        Color3.fromRGB(110, 218, 220), false)
    beacon.Shape = Enum.PartType.Ball
    local light = Instance.new("PointLight")
    light.Color = beacon.Color
    light.Range = 25
    light.Brightness = 1.5
    light.Parent = beacon
    local billboard = Instance.new("BillboardGui")
    billboard.Name = "GateInformation"
    billboard.Size = UDim2.fromOffset(330, 64)
    billboard.StudsOffsetWorldSpace = Vector3.new(0, 3, 0)
    billboard.MaxDistance = 110
    billboard.AlwaysOnTop = false
    billboard.Parent = beacon
    local text = Instance.new("TextLabel")
    text.Size = UDim2.fromScale(1, 1)
    text.BackgroundColor3 = Color3.fromRGB(16, 24, 35)
    text.BackgroundTransparency = 0.3
    text.Font = Enum.Font.Garamond
    text.TextSize = 22
    text.TextColor3 = Color3.fromRGB(249, 217, 154)
    text.Text = label .. "  |  Suggested Lv. " .. level
    text.Parent = billboard
    Instance.new("UICorner", text).CornerRadius = UDim.new(0, 8)
end

local function firTree(cf, n, color)
    local height = 12 + n * 3
    local trunk = part(scenery, "PineTrunk", Vector3.new(2, height * 0.48, 2),
        cf * CFrame.new(0, height * 0.24, 0), Enum.Material.Wood,
        Color3.fromRGB(79, 61, 44), false)
    for k = 1, 3 do
        local crown = part(scenery, "PineCanopy", Vector3.new(11 - 1.7 * k, 6, 11 - 1.7 * k),
            cf * CFrame.new(0, height * (0.32 + k * 0.15), 0),
            Enum.Material.Grass, color, false)
        crown.Shape = Enum.PartType.Ball
    end
end

local function flowerBeds(cf, seed)
    local colors = {
        Color3.fromRGB(231, 198, 111),
        Color3.fromRGB(235, 179, 198),
        Color3.fromRGB(179, 197, 235),
    }
    for i = 1, 6 do
        local localX = 3 + i * 3
        local localZ = (i % 2 == 0) and 6 or -5
        local stem = part(scenery, "MeadowFlower", Vector3.new(0.1, 1.5, 0.1),
            cf * CFrame.new(localX, 0.75, localZ), Enum.Material.Grass,
            Color3.fromRGB(80, 122, 66), false)
        local top = part(scenery, "Flower", Vector3.new(0.5, 0.35, 0.5),
            cf * CFrame.new(localX, 1.55, localZ), Enum.Material.SmoothPlastic,
            colors[(i + seed) % #colors + 1], false)
        top.Shape = Enum.PartType.Ball
    end
end

local function createExpansion()
    local forest = Workspace:WaitForChild("ForgottenForest", 25)
    local grassland = forest and forest:FindFirstChild("Grassland", true)
    if not grassland or not grassland:IsA("BasePart") or grassland.Size.X < 80 then
        warn("[Lumia V15] Grassland unavailable; outer zones not generated. No original map changed.")
        return nil
    end
    local width = 125
    local half = grassland.Size.X / 2
    local topY = grassland.Size.Y / 2
    local firstLocal = half + width / 2
    local secondLocal = half + width * 1.5
    local base = grassland.CFrame
    local positions = {}
    for index, localX in ipairs({firstLocal, secondLocal}) do
        local groundCf = base * CFrame.new(localX, topY - 3.5, 0)
        local grass = part(folder, index == 1 and "ThornwatchGround" or "FirstGateGround",
            Vector3.new(width, 7, math.min(170, grassland.Size.Z)), groundCf,
            Enum.Material.Grass,
            index == 1 and Color3.fromRGB(66, 105, 63) or Color3.fromRGB(76, 89, 79), true)
        local surfaceCf = base * CFrame.new(localX, topY, 0)
        positions[index] = surfaceCf
        -- Visual paths and flanking scenery avoid the central walking corridor.
        for i = -4, 4 do
            local x = i * 13.5
            local slab = part(scenery, "OldStoneTrail", Vector3.new(9.0, 0.2, 6.4),
                surfaceCf * CFrame.new(x, 0.08, 0), Enum.Material.Slate,
                Color3.fromRGB(138, 132, 120), false)
            slab.Transparency = 0.08
        end
        for j = 1, 7 do
            for _, side in ipairs({-1, 1}) do
                local lx = -54 + (j-1) * 17
                local lz = side * (28 + (j % 3) * 9)
                firTree(surfaceCf * CFrame.new(lx, 0, lz), j % 3,
                    index == 1 and Color3.fromRGB(52 + j * 2, 91, 69)
                        or Color3.fromRGB(59, 78 + j, 82))
            end
        end
        flowerBeds(surfaceCf * CFrame.new(-20, 0, 0), index)
    end
    -- Stone landmarks mark the road to each region; no collision gates.
    magicalArch(base * CFrame.new(half + 12, topY, 0), "THORNWATCH GLADE", 4)
    magicalArch(base * CFrame.new(half + width + 12, topY, 0), "FIRST GATE APPROACH", 5)
    local subzones = {
        regionVolume("ThornwatchGlade", base * CFrame.new(firstLocal, topY + 13, 0),
            Vector3.new(width - 1, 34, math.min(168, grassland.Size.Z) - 1)),
        regionVolume("FirstGateApproach", base * CFrame.new(secondLocal, topY + 13, 0),
            Vector3.new(width - 1, 34, math.min(168, grassland.Size.Z) - 1)),
    }
    -- Boss fight location inside level-five approach, away from the gate.
    local bossAnchor = part(folder, "GuardianEncounterAnchor", Vector3.new(2, 1, 2),
        positions[2] * CFrame.new(31, 4, 0), Enum.Material.SmoothPlastic,
        Color3.fromRGB(255, 255, 255), false)
    bossAnchor.Transparency = 1
    bossAnchor.CanQuery = false
    -- Mark actual monster coordinates for an independent, server-authoritative spawner.
    local spawnFolder = Instance.new("Folder")
    spawnFolder.Name = "OuterMonsterAnchors"
    spawnFolder.Parent = folder
    for zoneIndex, zoneId in ipairs({"ThornwatchGlade", "FirstGateApproach"}) do
        for index = 1, 4 do
            local pos = positions[zoneIndex] * CFrame.new(-40 + (index-1) * 25, 4, (index%2==0 and 20 or -20))
            local anchor = part(spawnFolder, zoneId .. "_Monster" .. index,
                Vector3.new(1, 1, 1), pos, Enum.Material.SmoothPlastic,
                Color3.fromRGB(255,255,255), false)
            anchor.Transparency = 1
            anchor:SetAttribute("ZoneId", zoneId)
        end
    end
    print("[Lumia V15] Two adjacent outdoor regions added to existing Grassland (no travel teleport)")
    return subzones
end

-- V19 open-world discovery: keep the existing decorative gateways and grounds,
-- but NEVER change player collision groups or reposition their characters.
local openZones = createExpansion()
local seenByPlayer = setmetatable({}, {__mode="k"})
local function inside(p, position)
    local relative=p.CFrame:PointToObjectSpace(position)
    local half=p.Size*0.5
    return math.abs(relative.X)<=half.X and math.abs(relative.Y)<=half.Y
        and math.abs(relative.Z)<=half.Z
end
local function watch(player)
    task.spawn(function()
        while player.Parent==Players do
            local character=player.Character
            local humanoid=character and character:FindFirstChildOfClass("Humanoid")
            local rootPart=character and character:FindFirstChild("HumanoidRootPart")
            local profile=PlayerData:GetProfile(player)
            if profile and rootPart and humanoid and humanoid.Health>0 and openZones then
                for _,entry in ipairs(openZones) do
                    if inside(entry.Part,rootPart.Position) then
                        local seen=seenByPlayer[player]
                        if not seen then seen={}; seenByPlayer[player]=seen end
                        if not seen[entry.Id] then
                            seen[entry.Id]=true
                            Achievements:OnZoneDiscovered(player,entry.Id)
                            -- Major-zone title is handled by ZoneTitle; do not fire
                            -- a duplicate ZoneNotice event here.
                        end
                    end
                end
            end
            task.wait(0.7)
        end
        seenByPlayer[player]=nil
    end)
end
Players.PlayerAdded:Connect(watch)
for _,player in ipairs(Players:GetPlayers()) do watch(player) end
print("[Lumia V19] Outer regions are open; suggested monster levels only")
