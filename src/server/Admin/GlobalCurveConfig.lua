-- REALMS OF LUMIA | Global curve config (server-only).
-- Roblox Experience Config key: lumia_global_curves_v1 (JSON).
-- This module READS Creator Hub-published configs. It does not publish from Roblox.
-- All changes use validated snapshots and only affect future monster spawns.
local ConfigService = game:GetService("ConfigService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CurveMath = require(ReplicatedStorage:WaitForChild("Lumia")
    :WaitForChild("Shared"):WaitForChild("Progression"):WaitForChild("CurveMath"))

local GlobalCurveConfig = {}
GlobalCurveConfig.Changed = Instance.new("BindableEvent")
GlobalCurveConfig.Key = "lumia_global_curves_v1"

local published = CurveMath.Presets("Classic")
local status = "Loading"
local version = 0
local snapshot = nil
local started = false

local function copyValues(values)
    local copy = {}
    for _, kind in ipairs(CurveMath.Order) do
        copy[kind] = table.clone(values[kind] or CurveMath.Neutral)
    end
    return copy
end

local function consume(value)
    if value == nil then
        published = CurveMath.Presets("Classic")
        version = 0
        status = "Not configured (original balance)"
        GlobalCurveConfig.Changed:Fire()
        return
    end
    if type(value) ~= "table" then
        warn("[Lumia - Global Curves] Config must be a JSON object. Keeping last valid curves.")
        status = "Invalid config: expected JSON object"
        return
    end
    -- Modern single-dial published format: {Version=4,Intensity=1.25}
    -- Existing v2/v3 12-category config snapshots stay backward-compatible.
    local values
    if value.Intensity ~= nil then
        values = CurveMath.FromIntensity(value.Intensity)
    elseif value.Preset ~= nil then
        if CurveMath.ProfileIntensities[value.Preset] == nil then
            status = "Invalid preset: retaining previous curves"
            return
        end
        values = CurveMath.Presets(value.Preset)
    else
        values = value.Values or value
    end
    if not CurveMath.Valid(values) then
        warn("[Lumia - Global Curves] Config failed range validation; keeping last valid curves.")
        status = "Invalid config: retaining previous curves"
        return
    end
    if value.Version ~= nil and (type(value.Version) ~= "number"
        or value.Version < 0 or value.Version % 1 ~= 0) then
        warn("[Lumia - Global Curves] Invalid Version; keeping previous curves.")
        status = "Invalid version: retaining previous curves"
        return
    end
    published = copyValues(values)
    version = value.Version or 0
    status = "Published config loaded"
    GlobalCurveConfig.Changed:Fire()
    print("[Lumia - Global Curves] Published config loaded, version " .. tostring(version))
end

local function refresh()
    if not snapshot then return end
    local ok, err = pcall(function()
        snapshot:Refresh()
        consume(snapshot:GetValue(GlobalCurveConfig.Key))
    end)
    if not ok then warn("[Lumia - Global Curves] Refresh failed: " .. tostring(err)) end
end

function GlobalCurveConfig:GetValues()
    return copyValues(published)
end

function GlobalCurveConfig:GetStatus()
    return status, version
end

function GlobalCurveConfig:Start()
    if started then return end
    started = true
    task.spawn(function()
        while not snapshot do
            local ok, result = pcall(function() return ConfigService:GetConfigAsync() end)
            if not ok then
                status = "ConfigService unavailable; original balance active"
                warn("[Lumia - Global Curves] Config fetch failed: " .. tostring(result))
                task.wait(90)
            else
                snapshot = result
                local readOk, readResult = pcall(function()
                    return snapshot:GetValue(GlobalCurveConfig.Key)
                end)
                if readOk then consume(readResult) else
                    status = "Config read failed; original balance active"
                    warn("[Lumia - Global Curves] Initial read failed: " .. tostring(readResult))
                end
                snapshot.UpdateAvailable:Connect(function()
                    task.spawn(refresh)
                end)
            end
        end
    end)
end

GlobalCurveConfig:Start()
return GlobalCurveConfig
