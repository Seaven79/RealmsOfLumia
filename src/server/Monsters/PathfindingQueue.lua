-- REALMS OF LUMIA - PATHFINDING BUDGET QUEUE (Stage 3a)
-- Global rate-limited queue for PathfindingService:ComputeAsync.
-- Max 3 ComputeAsync per second across all wolves.

local PathfindingService = game:GetService("PathfindingService")
local RunService = game:GetService("RunService")

local PathfindingQueue = {}

local MAX_COMPUTES_PER_SECOND = 3
local MAX_QUEUE_AGE = 5

local queue = {}
local queueByModel = {}
local computeTokensThisSecond = 0
local nextSecondReset = 0
local idCounter = 0

local function newRequest(model, source, destination, params, priority, callback)
    idCounter = idCounter + 1
    return {
        Id = idCounter, Model = model, Source = source, Destination = destination,
        Params = params or {}, Priority = priority or 1000, Callback = callback,
        CreatedAt = os.clock(), Started = false,
    }
end

function PathfindingQueue:Request(model, source, destination, params, priority, callback)
    if not model or not model.Parent then return end
    if typeof(source) ~= "Vector3" or typeof(destination) ~= "Vector3" then return end
    local prior = queueByModel[model]
    if prior then
        prior.Callback = nil
        prior.Cancelled = true
    end
    local req = newRequest(model, source, destination, params, priority or 500, callback)
    table.insert(queue, req)
    queueByModel[model] = req
    return req.Id
end

function PathfindingQueue:Cancel(model)
    local prior = queueByModel[model]
    if prior then
        prior.Cancelled = true
        prior.Callback = nil
        queueByModel[model] = nil
    end
end

function PathfindingQueue:IsStalled(model)
    local req = queueByModel[model]
    if not req then return false end
    return not req.Started and (os.clock() - req.CreatedAt) >= 1.5
end

local function sortQueue()
    table.sort(queue, function(a, b)
        if a.Priority ~= b.Priority then return a.Priority < b.Priority end
        return a.Id < b.Id
    end)
end

local function dropStale(now)
    for i = #queue, 1, -1 do
        local req = queue[i]
        if req.Cancelled or (now - req.CreatedAt) > MAX_QUEUE_AGE
            or not req.Model or not req.Model.Parent then
            if req.Callback and not req.Cancelled then
                task.spawn(req.Callback, nil, nil)
            end
            if queueByModel[req.Model] == req then queueByModel[req.Model] = nil end
            table.remove(queue, i)
        end
    end
end

local function execute(req, now)
    req.Started = true
    local success, waypoints, path
    success = pcall(function()
        local params = req.Params
        path = PathfindingService:CreatePath({
            AgentRadius = params.Radius or 3,
            AgentHeight = params.Height or 6,
            AgentCanJump = false,
            AgentCanClimb = false,
            WaypointSpacing = params.WaypointSpacing or 3,
            Costs = params.Costs or { LumiaNoMobHouse = math.huge },
        })
        path:ComputeAsync(req.Source, req.Destination)
        if path.Status == Enum.PathStatus.Success then
            waypoints = path:GetWaypoints()
        end
    end)
    if not success then waypoints = nil; path = nil end
    if req.Callback and not req.Cancelled then
        task.spawn(req.Callback, waypoints, path)
    end
    if queueByModel[req.Model] == req then queueByModel[req.Model] = nil end
end

local function tick()
    local now = os.clock()
    if now >= nextSecondReset then
        computeTokensThisSecond = 0
        nextSecondReset = now + 1
    end
    dropStale(now)
    if #queue == 0 then return end
    sortQueue()
    while computeTokensThisSecond < MAX_COMPUTES_PER_SECOND and #queue > 0 do
        local req = table.remove(queue, 1)
        if not req.Cancelled and req.Model and req.Model.Parent then
            computeTokensThisSecond = computeTokensThisSecond + 1
            execute(req, now)
        else
            if queueByModel[req.Model] == req then queueByModel[req.Model] = nil end
        end
    end
end

local connection = nil
function PathfindingQueue:Start()
    if connection then return end
    connection = RunService.Heartbeat:Connect(tick)
    print("[Lumia - Pathfinding Queue] Started (max " .. MAX_COMPUTES_PER_SECOND .. " ComputeAsync/sec)")
end

return PathfindingQueue