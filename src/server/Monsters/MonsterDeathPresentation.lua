-- REALMS OF LUMIA - MONSTER DEATH PRESENTATION v1.0
-- Visual-only pose on the server so all players see the same corpse.
-- Death/respawn timing, loot, damage and persistent player data are elsewhere.
-- Future death animations/ragdolls can replace Apply() without changing AI.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local DeathConfig = require(ReplicatedStorage:WaitForChild("Lumia")
    :WaitForChild("Shared"):WaitForChild("Monsters")
    :WaitForChild("MonsterDeathConfig"))

local MonsterDeathPresentation = {}

local function optionFor(monsterId, option)
    local profile = DeathConfig.Monsters[monsterId]
    if profile and profile[option] ~= nil then
        return profile[option]
    end
    return DeathConfig.Default[option]
end

local function freezeCorpse(model)
    for _, part in ipairs(model:GetDescendants()) do
        if part:IsA("BasePart") then
            -- Prevent the dead wolf from continuing to move or blocking paths.
            part.AssemblyLinearVelocity = Vector3.zero
            part.AssemblyAngularVelocity = Vector3.zero
            part.CanCollide = false
            part.CanTouch = false
            part.Anchored = true
        elseif part:IsA("AlignOrientation") or part:IsA("AlignPosition") then
            part.Enabled = false
        end
    end
end

local function groundHeightFor(model, root)
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = {model}
    params.IgnoreWater = true
    params.RespectCanCollide = true

    local monsterFolder = Workspace:FindFirstChild("LumiaMonsters")
    if monsterFolder then
        params.FilterDescendantsInstances = {monsterFolder}
    end

    local result = Workspace:Raycast(
        root.Position + Vector3.new(0, 3, 0),
        Vector3.new(0, -35, 0),
        params
    )
    return result and result.Position.Y or nil
end

local function boundingBoxBottomY(model)
    local bounds, size = model:GetBoundingBox()
    -- GetBoundingBox() is oriented: calculate its vertical extent in world space.
    local halfY = 0.5 * (
        math.abs(bounds.RightVector.Y) * size.X
        + math.abs(bounds.UpVector.Y) * size.Y
        + math.abs(bounds.LookVector.Y) * size.Z
    )
    return bounds.Position.Y - halfY
end

function MonsterDeathPresentation.Apply(model, monsterId)
    if not model or not model.Parent or model:GetAttribute("LumiaCorpse") then
        return
    end

    local root = model:FindFirstChild("HumanoidRootPart")
    if not root or not root:IsA("BasePart") then
        return
    end

    if optionFor(monsterId, "Mode") ~= "SidePose" then
        return -- Reserved for future animation/ragdoll types.
    end

    -- Sample the ground BEFORE rotating so the ray starts above the corpse.
    local groundY = groundHeightFor(model, root)

    freezeCorpse(model)

    local degrees = tonumber(optionFor(monsterId, "RollDegrees")) or 83
    local roll = math.rad(math.clamp(degrees, -90, 90))
    model:PivotTo(model:GetPivot() * CFrame.Angles(0, 0, roll))

    if groundY then
        local gap = tonumber(optionFor(monsterId, "GroundGap")) or 0.08
        local verticalAdjustment = groundY + gap - boundingBoxBottomY(model)
        model:PivotTo(model:GetPivot() + Vector3.new(0, verticalAdjustment, 0))
    end

    model:SetAttribute("LumiaCorpse", true)
end

return MonsterDeathPresentation