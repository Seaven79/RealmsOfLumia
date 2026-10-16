-- REALMS OF LUMIA V15 - QUEST REGION LABELS AND DISCOVERY
-- Uses the real quest-marker coordinates; no existing geometry is moved.
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local services = script.Parent.Parent
local Data = require(services:WaitForChild("Players"):WaitForChild("PlayerDataService"))
local Achievements = require(services:WaitForChild("Progression"):WaitForChild("AchievementService"))
local shared = ReplicatedStorage:WaitForChild("Lumia"):WaitForChild("Shared")
local QuestConfig = require(shared:WaitForChild("Quests"):WaitForChild("QuestConfig"))
local ZoneConfig = require(shared:WaitForChild("World"):WaitForChild("ZoneConfig"))

local existing = Workspace:FindFirstChild("LumiaStarterRegionTriggers")
if existing then existing:Destroy() end
local folder = Instance.new("Folder")
folder.Name = "LumiaStarterRegionTriggers"
folder.Parent = Workspace
local byZone = {}
for _, marker in ipairs(QuestConfig.Markers) do
    local entry = byZone[marker.Zone]
    if not entry then
        entry = {MinX = marker.X, MinZ = marker.Z, MaxX = marker.X, MaxZ = marker.Z}
        byZone[marker.Zone] = entry
    end
    entry.MinX = math.min(entry.MinX, marker.X)
    entry.MaxX = math.max(entry.MaxX, marker.X)
    entry.MinZ = math.min(entry.MinZ, marker.Z)
    entry.MaxZ = math.max(entry.MaxZ, marker.Z)
end

local function create(id, center, size)
    local def = ZoneConfig.Zones[id]
    if not def then return nil end
    local p = Instance.new("Part")
    p.Name = id
    p.CFrame = CFrame.new(center)
    p.Size = size
    p.Transparency = 1
    p.Anchored = true
    p.CanCollide = false
    p.CanQuery = false
    p.CanTouch = false
    p:SetAttribute("ZoneId", id)
    p:SetAttribute("ZoneName", def.Name)
    p:SetAttribute("ZoneSubtitle", def.Subtitle)
    p.Parent = folder
    CollectionService:AddTag(p, "LumiaRegion")
    return p
end

local regions = {}
for id, box in pairs(byZone) do
    local center = Vector3.new((box.MinX + box.MaxX) / 2, 8, (box.MinZ + box.MaxZ) / 2)
    local size = Vector3.new(box.MaxX - box.MinX + 22, 110, box.MaxZ - box.MinZ + 22)
    local p = create(id, center, size)
    if p then regions[#regions + 1] = {Id = id, Part = p, Area = size.X * size.Z} end
end
local village = create("StarterVillage", Vector3.new(0, 8, 0), Vector3.new(42, 110, 42))
if village then regions[#regions + 1] = {Id="StarterVillage", Part=village, Area=42*42} end

table.sort(regions,function(a,b) return a.Area < b.Area end)
local last = setmetatable({}, {__mode="k"})
local function inside(p, v)
    local o = p.CFrame:PointToObjectSpace(v)
    return math.abs(o.X) <= p.Size.X/2 and math.abs(o.Y) <= p.Size.Y/2
        and math.abs(o.Z) <= p.Size.Z/2
end
local function watch(player)
    task.spawn(function()
        while player.Parent == Players do
            local char = player.Character
            local root = char and char:FindFirstChild("HumanoidRootPart")
            local profile = Data:GetProfile(player)
            if root and profile then
                local zone
                for _, entry in ipairs(regions) do
                    if inside(entry.Part, root.Position) then zone = entry.Id; break end
                end
                if zone and last[player] ~= zone then
                    last[player] = zone
                    Achievements:OnZoneDiscovered(player, zone)
                elseif not zone then
                    last[player] = nil
                end
            end
            task.wait(0.5)
        end
        last[player] = nil
    end)
end
Players.PlayerAdded:Connect(watch)
for _, player in ipairs(Players:GetPlayers()) do watch(player) end
print("[Lumia V15] Quest-area discoveries enabled")
