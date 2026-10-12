-- Realms of Eternia
-- CreatureFactory v1.0
--
-- Loads reusable creature models from ServerStorage.
-- Falls back to the original R6 rig when no asset exists.

local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")

local CreatureFactory = {}

local function getLibrary()
    local assets = ServerStorage:FindFirstChild("EterniaAssets")
    return assets and assets:FindFirstChild("Creatures")
end

local function validRig(model)
    if not model or not model:IsA("Model") then
        return false
    end

    local humanoid = model:FindFirstChildOfClass("Humanoid")
    local root = model:FindFirstChild("HumanoidRootPart")

    if not humanoid or not root or not root:IsA("BasePart") then
        return false
    end

    if humanoid.Health <= 0 then
        return false
    end

    return true
end

local function createFallback()
    local description = Instance.new("HumanoidDescription")

    local success, result = pcall(function()
        return Players:CreateHumanoidModelFromDescription(
            description,
            Enum.HumanoidRigType.R6
        )
    end)

    description:Destroy()

    if not success or not result then
        warn("[Eternia] Fallback rig creation failed: "
            .. tostring(result))
        return nil
    end

    if not validRig(result) then
        result:Destroy()
        warn("[Eternia] Fallback rig validation failed")
        return nil
    end

    return result
end

function CreatureFactory.Create(monsterId, definition)
    if type(definition) ~= "table" then
        warn("[Eternia] Invalid creature definition")
        return nil
    end

    local modelId = definition.ModelId or monsterId

    if type(modelId) ~= "string" or modelId == "" then
        warn("[Eternia] Invalid creature ModelId")
        return nil
    end

    local library = getLibrary()
    local template = library and library:FindFirstChild(modelId)

    if template then
        if not validRig(template) then
            warn("[Eternia] Invalid creature asset: " .. modelId)
        else
            local success, clone = pcall(function()
                return template:Clone()
            end)

            if success and clone and validRig(clone) then
                print("[Eternia] Loaded creature model: " .. modelId)
                return clone
            end

            if clone then
                clone:Destroy()
            end

            warn("[Eternia] Failed to clone creature: " .. modelId)
        end
    else
        warn("[Eternia] Creature asset unavailable: "
            .. modelId .. " - using R6 fallback")
    end

    return createFallback()
end

return CreatureFactory