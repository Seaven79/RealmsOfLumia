-- REALMS OF LUMIA - HOUSE RESTRICTED ZONES FOR CREATURES
-- In Studio Edit mode, tag each individual building Model with "LumiaNoMobHouse".
-- A non-collidable PathfindingModifier volume is created while the server runs.
-- Players are not blocked. Monster paths and aggro avoid these volumes.
-- All tagged houses share one registry; no per-monster scanning.

local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")

local TAG = "LumiaNoMobHouse"
local LABEL = "LumiaNoMobHouse"
local SIDE_MARGIN = 1.35 -- Keep wolf bodies away from walls, not just doorways.
local HEIGHT_MARGIN = 4

local HouseZones = {}
local started = false
local zones = {} -- [tagged building] = invisible modifier Part
local zoneFolder

local function getBounds(instance)
    if instance:IsA("Model") then
        if not instance:FindFirstChildWhichIsA("BasePart", true) then
            return nil, nil
        end
        return instance:GetBoundingBox()
    elseif instance:IsA("BasePart") then
        return instance.CFrame, instance.Size
    end
    return nil, nil
end

local function removeZone(instance)
    local zone = zones[instance]
    zones[instance] = nil
    if zone then zone:Destroy() end
end

local function addZone(instance)
    if zones[instance] or not instance:IsDescendantOf(Workspace) then return end
    local cframe, bounds = getBounds(instance)
    if not cframe or not bounds then return end

    local zone = Instance.new("Part")
    zone.Name = "HouseNoMob_" .. instance.Name
    zone.Anchored = true
    zone.Transparency = 1
    zone.CanCollide = false
    zone.CanTouch = false
    zone.CanQuery = false
    zone.CastShadow = false
    zone.CFrame = cframe * CFrame.new(0, -1, 0)
    zone.Size = Vector3.new(
        bounds.X + 2 * SIDE_MARGIN,
        math.max(8, bounds.Y + HEIGHT_MARGIN),
        bounds.Z + 2 * SIDE_MARGIN
    )

    local modifier = Instance.new("PathfindingModifier")
    modifier.Name = "LumiaHouseRestrictedArea"
    modifier.Label = LABEL
    modifier.PassThrough = false
    modifier.Parent = zone
    zone.Parent = zoneFolder
    zones[instance] = zone
    print("[Lumia - Monster House Zones] Mob-free house zone: " .. instance:GetFullName())
end

function HouseZones.Start()
    if started then return end
    started = true
    zoneFolder = Workspace:FindFirstChild("LumiaMonsterRestrictedVolumes")
    if not zoneFolder then
        zoneFolder = Instance.new("Folder")
        zoneFolder.Name = "LumiaMonsterRestrictedVolumes"
        zoneFolder.Parent = Workspace
    end

    for _, instance in ipairs(CollectionService:GetTagged(TAG)) do
        addZone(instance)
    end
    CollectionService:GetInstanceAddedSignal(TAG):Connect(addZone)
    CollectionService:GetInstanceRemovedSignal(TAG):Connect(removeZone)
end

local function insideXZ(localPos, halfX, halfZ)
    return math.abs(localPos.X) <= halfX and math.abs(localPos.Z) <= halfZ
end

function HouseZones.IsRestricted(position, padding)
    if typeof(position) ~= "Vector3" then return false end
    padding = math.max(0, padding or 0)
    for _, zone in pairs(zones) do
        if zone.Parent then
            local localPos = zone.CFrame:PointToObjectSpace(position)
            if math.abs(localPos.Y) <= zone.Size.Y * 0.5 + 2
                and insideXZ(localPos,
                    zone.Size.X * 0.5 + padding,
                    zone.Size.Z * 0.5 + padding) then
                return true
            end
        end
    end
    return false
end

-- Extra fail-safe: inspect each path segment, not only waypoint endpoints.
-- A path is rejected if it would pass through an entire house between points.
local function segmentCrossesRect(fromPoint, toPoint, halfX, halfZ)
    local dx = toPoint.X - fromPoint.X
    local dz = toPoint.Z - fromPoint.Z
    local t0, t1 = 0, 1

    local function clip(p, q)
        if math.abs(p) < 1e-7 then
            return q >= 0
        end
        local r = q / p
        if p < 0 then
            if r > t1 then return false end
            if r > t0 then t0 = r end
        else
            if r < t0 then return false end
            if r < t1 then t1 = r end
        end
        return true
    end

    return clip(-dx, fromPoint.X + halfX)
        and clip(dx, halfX - fromPoint.X)
        and clip(-dz, fromPoint.Z + halfZ)
        and clip(dz, halfZ - fromPoint.Z)
end

function HouseZones.SegmentRestricted(a, b, padding)
    padding = math.max(0, padding or 0)
    for _, zone in pairs(zones) do
        if zone.Parent then
            local localA = zone.CFrame:PointToObjectSpace(a)
            local localB = zone.CFrame:PointToObjectSpace(b)
            local halfY = zone.Size.Y * 0.5 + 2
            if math.min(localA.Y, localB.Y) <= halfY
                and math.max(localA.Y, localB.Y) >= -halfY
                and segmentCrossesRect(
                    localA, localB,
                    zone.Size.X * 0.5 + padding,
                    zone.Size.Z * 0.5 + padding
                ) then
                return true
            end
        end
    end
    return false
end

return HouseZones
