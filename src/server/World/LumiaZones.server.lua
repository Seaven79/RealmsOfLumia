-- REALMS OF LUMIA V15 - CONNECTED OUTER REGIONS
-- Adds land to the east of the existing Grassland. No inter-zone teleport.
-- Progression enforcement is server authoritative and returns a player to their
-- own last safe location only after they enter a locked area.
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
    text.Text = label .. "  |  Level " .. level
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
    -- Level gates guard the trail at the start of each new ground section.
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

local lockedZones = createExpansion()
local function inside(partObj, position)
    local rel = partObj.CFrame:PointToObjectSpace(position)
    local half = partObj.Size * 0.5
    return math.abs(rel.X) < half.X and math.abs(rel.Y) < half.Y and math.abs(rel.Z) < half.Z
end
-- V17: actual PHYSICAL level barriers. Characters never teleport for level gates.
-- Collision groups allow only sufficiently experienced players through each wall.
local GROUPS = {"LumiaLow", "LumiaMid", "LumiaHigh", "LumiaGate4", "LumiaGate5"}
for _, name in ipairs(GROUPS) do
    if not Workspace:IsCollisionGroupRegistered(name) then
        Workspace:RegisterCollisionGroup(name)
    end
end
for _, name in ipairs({"LumiaLow", "LumiaMid", "LumiaHigh"}) do
    Workspace:CollisionGroupSetCollidable(name, name, false)
end
for _, wall in ipairs({"LumiaGate4", "LumiaGate5"}) do
    Workspace:CollisionGroupSetCollidable("Default", wall, false)
    Workspace:CollisionGroupSetCollidable(wall, wall, false)
end
Workspace:CollisionGroupSetCollidable("LumiaLow", "LumiaGate4", true)
Workspace:CollisionGroupSetCollidable("LumiaLow", "LumiaGate5", true)
Workspace:CollisionGroupSetCollidable("LumiaMid", "LumiaGate4", false)
Workspace:CollisionGroupSetCollidable("LumiaMid", "LumiaGate5", true)
Workspace:CollisionGroupSetCollidable("LumiaHigh", "LumiaGate4", false)
Workspace:CollisionGroupSetCollidable("LumiaHigh", "LumiaGate5", false)

local gateBarriers = {}
local function makeBarrier(id, worldCF, halfZ, level)
    -- Only a slim, visible magical pane has collision. No player CFrame/position edits.
    local beam = part(folder, "Physical" .. id, Vector3.new(3, 30, halfZ * 2 + 1),
        worldCF * CFrame.new(0, 12, 0), Enum.Material.ForceField,
        level == 4 and Color3.fromRGB(90, 180, 172) or Color3.fromRGB(167, 114, 227), true)
    beam.Transparency = .78
    beam.CastShadow = false
    beam.CollisionGroup = "LumiaGate" .. level
    beam:SetAttribute("RequiredLevel", level)
    return {Part=beam, Level=level, Name=id}
end
local grassland = Workspace:FindFirstChild("ForgottenForest")
local ground = grassland and grassland:FindFirstChild("Grassland", true)
if ground and ground:IsA("BasePart") then
    local half = ground.Size.X / 2
    local top = ground.Size.Y / 2
    local halfZ = math.min(170, ground.Size.Z) / 2
    gateBarriers = {
        makeBarrier("ThornwatchGlade", ground.CFrame * CFrame.new(half + 3, top, 0), halfZ, 4),
        makeBarrier("FirstGateApproach", ground.CFrame * CFrame.new(half + 128, top, 0), halfZ, 5),
    }
end

local lastRegion = setmetatable({}, {__mode="k"})
local lastWarning = setmetatable({}, {__mode="k"})
local characterConnections = setmetatable({}, {__mode="k"})
local function collisionName(level)
    if level >= 5 then return "LumiaHigh" end
    if level >= 4 then return "LumiaMid" end
    return "LumiaLow"
end
local function setGroup(character, group)
    for _, descendant in ipairs(character:GetDescendants()) do
        if descendant:IsA("BasePart") and descendant.CollisionGroup ~= group then
            descendant.CollisionGroup = group
        end
    end
end
local function watch(player)
    task.spawn(function()
        local seenCharacter, previousGroup
        while player.Parent == Players do
            local profile = PlayerData:GetProfile(player)
            local character = player.Character
            local rootPart = character and character:FindFirstChild("HumanoidRootPart")
            local humanoid = character and character:FindFirstChildOfClass("Humanoid")
            local level = profile and profile.Character and profile.Character.Level or 1
            local group = collisionName(level)
            if character ~= seenCharacter then
                if characterConnections[player] then characterConnections[player]:Disconnect() end
                seenCharacter = character
                previousGroup = nil
                if character then
                    characterConnections[player] = character.DescendantAdded:Connect(function(descendant)
                        if descendant:IsA("BasePart") then
                            local live=PlayerData:GetProfile(player)
                            local currentLevel=live and live.Character and live.Character.Level or 1
                            descendant.CollisionGroup = collisionName(currentLevel)
                        end
                    end)
                end
            end
            if character and previousGroup ~= group then
                setGroup(character, group)
                previousGroup = group
            end
            if rootPart and humanoid and humanoid.Health > 0 and profile then
                if lockedZones then
                    for _, entry in ipairs(lockedZones) do
                        if inside(entry.Part, rootPart.Position) and level >= entry.Level then
                            if lastRegion[player] ~= entry.Id then
                                lastRegion[player] = entry.Id
                                Achievements:OnZoneDiscovered(player, entry.Id)
                            end
                        end
                    end
                end
                for _, gate in ipairs(gateBarriers) do
                    if level < gate.Level then
                        local point = gate.Part.CFrame:PointToObjectSpace(rootPart.Position)
                        if math.abs(point.X) < 12 and math.abs(point.Z) < gate.Part.Size.Z / 2 then
                            local last = lastWarning[player] or -100
                            if os.clock() - last > 9 then
                                lastWarning[player] = os.clock()
                                notice:FireClient(player, {Type="Denied", ZoneName=gate.Name,
                                    RequiredLevel=gate.Level})
                            end
                        end
                    end
                end
            end
            task.wait(.45)
        end
        if characterConnections[player] then characterConnections[player]:Disconnect() end
        characterConnections[player] = nil
        lastRegion[player] = nil
        lastWarning[player] = nil
    end)
end
Players.PlayerAdded:Connect(watch)
for _, player in ipairs(Players:GetPlayers()) do watch(player) end
print("[Lumia V17] Physical level gates ready; no teleports")
