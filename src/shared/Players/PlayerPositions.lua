-- REALMS OF LUMIA - SHARED PLAYER POSITION CACHE (Stage 2 v2a)
-- Phase 1: just the module. No consumers wired yet.
-- Phase 2 (v2b) will rewire MonsterAI, SpawnManager, etc. to call into this.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local PlayerPositions = {}

local REFRESH_INTERVAL = 1/30
local nextRefresh = 0
local cached = {}
local byPlayer = {}
local started = false
local heartbeatConn = nil

local function buildEntry(player)
    local character = player.Character
    if not character or not character.Parent then return nil end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid or humanoid.Health <= 0 then return nil end
    local root = character:FindFirstChild("HumanoidRootPart")
    if not root or not root.Parent then return nil end
    return { Player = player, Root = root, Position = root.Position }
end

local function refresh()
    local newCached = {}
    local newByPlayer = {}
    for _, player in ipairs(Players:GetPlayers()) do
        local entry = buildEntry(player)
        if entry then
            table.insert(newCached, entry)
            newByPlayer[player] = entry
        end
    end
    cached = newCached
    byPlayer = newByPlayer
end

local function tick()
    local now = os.clock()
    if now < nextRefresh then return end
    nextRefresh = now + REFRESH_INTERVAL
    refresh()
end

function PlayerPositions:Start()
    if started then return end
    started = true
    refresh()
    heartbeatConn = RunService.Heartbeat:Connect(tick)
end

function PlayerPositions:Stop()
    if heartbeatConn then heartbeatConn:Disconnect(); heartbeatConn = nil end
    started = false
    cached = {}
    byPlayer = {}
end

function PlayerPositions:Roots() return cached end

function PlayerPositions:Snapshot()
    local copy = table.create(#cached)
    for i, entry in ipairs(cached) do copy[i] = entry end
    return copy
end

function PlayerPositions:Nearest(position, radius, requireOpen)
    local best, bestDist = nil, radius
    for _, entry in ipairs(cached) do
        if not requireOpen or requireOpen(entry.Position) then
            local d = (entry.Position - position).Magnitude
            if d < bestDist then best, bestDist = entry, d end
        end
    end
    return best
end

function PlayerPositions:Within(position, radius)
    local radiusSquared = radius * radius
    for _, entry in ipairs(cached) do
        local delta = entry.Position - position
        if delta:Dot(delta) <= radiusSquared then return true end
    end
    return false
end

function PlayerPositions:NearestFlat(position, radius, requireOpen)
    local best, bestDist = nil, radius
    for _, entry in ipairs(cached) do
        if not requireOpen or requireOpen(entry.Position) then
            local delta = Vector3.new(entry.Position.X - position.X, 0, entry.Position.Z - position.Z)
            local d = delta.Magnitude
            if d < bestDist then best, bestDist = entry, d end
        end
    end
    return best
end

function PlayerPositions:Get(player) return byPlayer[player] end

return PlayerPositions