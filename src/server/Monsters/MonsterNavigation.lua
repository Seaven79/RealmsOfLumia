-- REALMS OF LUMIA - REUSABLE GROUND MONSTER NAVIGATION
-- Server authoritative. No straight-line MoveTo fallback through buildings.
-- Compute paths at a bounded rate, then follow waypoints on the existing AI tick.
-- One navigation object per active creature, shared implementation for all rigs.

local PathfindingService = game:GetService("PathfindingService")
local HouseZones = require(script.Parent:WaitForChild("MonsterHouseZones"))
local PathfindingQueue = require(script.Parent:WaitForChild("PathfindingQueue"))

local MonsterNavigation = {}
MonsterNavigation.__index = MonsterNavigation

local REPATH_SECONDS = 1.35
local REPATH_MOVE_DISTANCE = 3.5
local WAYPOINT_REACHED = 2.3
local MAX_GROUND_CHANGE = 5.5
local MAX_STEP_CHANGE = 3.8
local MOVE_REFRESH = 0.40
local STUCK_SECONDS = 2.1

local function flatDistance(a, b)
    local dx, dz = a.X - b.X, a.Z - b.Z
    return math.sqrt(dx * dx + dz * dz)
end

local function usablePath(waypoints, homeY, radius)
    if #waypoints < 2 then
        return false
    end
    for i, waypoint in ipairs(waypoints) do
        -- A ground creature never climbs or jumps onto a roof.
        if waypoint.Action == Enum.PathWaypointAction.Jump then
            return false
        end
        if math.abs(waypoint.Position.Y - homeY) > MAX_GROUND_CHANGE then
            return false
        end
        if i > 1 and math.abs(waypoint.Position.Y - waypoints[i - 1].Position.Y) > MAX_STEP_CHANGE then
            return false
        end
        if HouseZones.IsRestricted(waypoint.Position, 0.2) then
            return false
        end
        if i > 1 and HouseZones.SegmentRestricted(
            waypoints[i - 1].Position, waypoint.Position, 0.2
        ) then
            return false
        end
    end
    return true
end

function MonsterNavigation.new(model, humanoid, root, home)
    HouseZones.Start()
    local bounds = model:GetExtentsSize()
    local radius = math.clamp(math.min(bounds.X, bounds.Z) * 0.32, 2, 3.8)
    local height = math.clamp(bounds.Y + 0.7, 5, 11)

    local self = setmetatable({
        Model = model,
        Humanoid = humanoid,
        Root = root,
        HomeY = home.Y,
        Radius = radius,
        Height = height,
        Goal = nil,
        Intent = nil,
        PathGoal = nil,
        Route = nil,
        Index = 1,
        Blocked = false,
        Computing = false,
        NextCompute = 0,
        Token = 0,
        LastMove = 0,
        LastPosition = root.Position,
        LastProgress = os.clock(),
        Destroyed = false,
        PathConnection = nil,
    }, MonsterNavigation)

    -- A real solid root prevents physics from passing through collidable walls.
    -- Decorative animated parts can still remain non-collidable.
    root.CanCollide = true
    humanoid.Jump = false
    humanoid.JumpPower = 0
    humanoid.JumpHeight = 0
    humanoid.MaxSlopeAngle = 30
    humanoid:SetStateEnabled(Enum.HumanoidStateType.Climbing, false)
    humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)

    return self
end

function MonsterNavigation:_clearRoute()
    if self.PathConnection then
        self.PathConnection:Disconnect()
        self.PathConnection = nil
    end
    self.Route = nil
    self.Index = 1
end

function MonsterNavigation:Stop()
    self.Token += 1
    self.Goal = nil
    self.Intent = nil
    self.PathGoal = nil
    self.Blocked = false
    self:_clearRoute()
    if self.Root.Parent and self.Humanoid.Health > 0 then
        self.Humanoid:MoveTo(self.Root.Position)
    end
end

function MonsterNavigation:Destroy()
    if self.Destroyed then return end
    self:Stop()
    self.Destroyed = true
end

function MonsterNavigation:SetGoal(position, intent)
    if self.Destroyed or typeof(position) ~= "Vector3" then return end
    if HouseZones.IsRestricted(position, 0.25) then
        -- No walking into houses even when a player or random wander goal is inside.
        self:Stop()
        return
    end
    if math.abs(position.Y - self.HomeY) > MAX_GROUND_CHANGE + 2 then
        -- No climbing toward roof-level destinations.
        self:Stop()
        return
    end
    if intent ~= self.Intent then
        self.Token += 1
        self:_clearRoute()
        self.PathGoal = nil
        self.Blocked = false
        self.Intent = intent
    end
    self.Goal = position
end

function MonsterNavigation:_requestPath(now)
    if self.Destroyed or self.Computing or not self.Goal or now < self.NextCompute then
        return
    end

    if self.Route and not self.Blocked and self.PathGoal
        and flatDistance(self.PathGoal, self.Goal) < REPATH_MOVE_DISTANCE then
        return
    end

    self.NextCompute = now + REPATH_SECONDS
    self.Computing = true
    local generation = self.Token
    local destination = self.Goal
    local source = self.Root.Position

    -- Stage 3a: route through global budget queue
    local priority = (self.Intent == "Chase" or self.Intent == "Retreat") and 100 or 800
    PathfindingQueue:Request(
        self.Model, source, destination,
        { Radius = self.Radius, Height = self.Height, WaypointSpacing = 3, Costs = { LumiaNoMobHouse = math.huge } },
        priority,
        function(waypoints, path)
            self.Computing = false
            if self.Destroyed or self.Token ~= generation
                or not self.Model.Parent or self.Humanoid.Health <= 0 then
                return
            end
            self:_clearRoute()
            self.Blocked = false
            self.PathGoal = destination
            if waypoints and usablePath(waypoints, self.HomeY, self.Radius) then
                self.Route = waypoints
                self.Index = 2
                self.LastProgress = os.clock()
                self.LastPosition = self.Root.Position
                if path then
                    self.PathConnection = path.Blocked:Connect(function(blockedIndex)
                        if blockedIndex >= self.Index then self.Blocked = true end
                    end)
                end
            else
                self.Humanoid:MoveTo(self.Root.Position)
            end
        end
    )
end

function MonsterNavigation:Step(now)
    if self.Destroyed or not self.Goal or self.Humanoid.Health <= 0 then return end

    self:_requestPath(now)
    if not self.Route or self.Blocked then
        if self.Blocked and now >= self.NextCompute then
            self:_clearRoute()
            self:_requestPath(now)
        end
        return
    end

    local current = self.Route[self.Index]
    while current and flatDistance(self.Root.Position, current.Position) <= WAYPOINT_REACHED
        and math.abs(self.Root.Position.Y - current.Position.Y) <= 4 do
        self.Index += 1
        current = self.Route[self.Index]
        self.LastProgress = now
        self.LastPosition = self.Root.Position
    end

    if not current then
        self:_clearRoute()
        self.PathGoal = nil
        self.Humanoid:MoveTo(self.Root.Position)
        return
    end

    if flatDistance(self.Root.Position, self.LastPosition) >= 1 then
        self.LastPosition = self.Root.Position
        self.LastProgress = now
    elseif now - self.LastProgress >= STUCK_SECONDS then
        self.Blocked = true
        self.NextCompute = math.min(self.NextCompute, now)
        self.LastProgress = now
        return
    end

    if now - self.LastMove >= MOVE_REFRESH then
        self.LastMove = now
        self.Humanoid:MoveTo(current.Position)
    end
end

function MonsterNavigation.IsHouseRestricted(position)
    HouseZones.Start()
    return HouseZones.IsRestricted(position)
end

return MonsterNavigation
