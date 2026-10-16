-- Realms of Lumia | GraphicsManager v1.0
-- Client graphics coordination: quality presets, streaming wait, frame budgets.
-- Server never owns graphics. This module never edits the existing terrain or house.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local Settings = require(ReplicatedStorage:WaitForChild("Lumia")
    :WaitForChild("Shared"):WaitForChild("World"):WaitForChild("GraphicsSettings"))

local GraphicsManager = {}
local preset = Settings.Presets[Settings.SelectedPreset] or Settings.Presets.Balanced
local profile = table.clone(preset)
profile.Name = Settings.SelectedPreset
if not Settings.Presets[Settings.SelectedPreset] then profile.Name = "Balanced" end

-- Keep native lighting under RPGEnvironment; only control effects owned by Lumia.
-- Low can turn off expensive optional effects without modifying other games' effects.
local function applyOptionalEffect(name, enabled)
    local effect = Lighting:FindFirstChild(name)
    if effect and effect:IsA("PostEffect") then
        effect.Enabled = enabled
    end
end

function GraphicsManager.GetProfile()
    applyOptionalEffect("LumiaForestBloom", profile.EnableBloom)
    applyOptionalEffect("LumiaForestSunRays", profile.EnableSunRays)
    return profile
end

function GraphicsManager.WaitForGround(region)
    if not region then return nil end
    local current = region:FindFirstChild(Settings.GroundPartName, true)
    if current and current:IsA("BasePart") then return current end
    print("[Lumia - Graphics Manager] Waiting for existing " .. Settings.GroundPartName .. " to stream...")
    -- Direct child in the current Forgotten Forest map.
    local part = region:WaitForChild(Settings.GroundPartName, Settings.GroundWaitSeconds)
    if part and part:IsA("BasePart") then
        print("[Lumia - Graphics Manager] Ground streamed: " .. part:GetFullName())
        return part
    end
    local descendant = region:FindFirstChild(Settings.GroundPartName, true)
    if descendant and descendant:IsA("BasePart") then return descendant end
    return nil
end

function GraphicsManager.YieldIfNeeded(iteration, batchSize)
    if iteration % math.max(1, batchSize) == 0 then
        task.wait() -- allow input, character and UI rendering to continue
    end
end

return GraphicsManager
