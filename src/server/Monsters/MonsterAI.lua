-- REALMS OF LUMIA - MONSTER AI WITH GROUNDED PATHFINDING
-- Preserves the tested melee standoff and the two wolf animation signals.
-- Chasing, retreating, returning home and wandering all share one path system.
-- No jumping, climbing, roof shortcuts, or melee attacks through solid walls.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local MonsterNavigation = require(script.Parent:WaitForChild("MonsterNavigation"))
local CombatStats = require(script.Parent.Parent:WaitForChild("Combat"):WaitForChild("CombatStats"))
local PlayerPositions = require(game:GetService("ReplicatedStorage"):WaitForChild("Lumia"):WaitForChild("Shared"):WaitForChild("Players"):WaitForChild("PlayerPositions"))

local MonsterAI = {}

local MIN_STANDOFF = 6.2
local MAX_STANDOFF = 11 -- Explicitly configured large creatures can stand farther.
local DEFAULT_MAX_STANDOFF = 7.0 -- Keep regular mobs inside the current sword reach.
local MELEE_CONTACT_MARGIN = 0.7
local CHASE_BAND = 0.65
local RETREAT_BAND = 1.2
local MELEE_AI_TICK = 0.18
local WANDER_AI_TICK = 0.25
local MAX_MELEE_HEIGHT_DIFFERENCE = 3.3

local function getRoot(model)
    return model and model:FindFirstChild("HumanoidRootPart")
end

local function aliveCharacter(player)
    local character = player.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local root = getRoot(character)
    if humanoid and humanoid.Health > 0 and root then
        return humanoid, root
    end
    return nil, nil
end

local function nearestPlayer(position, radius)
    local entry = PlayerPositions:Nearest(position, radius, function(pos)
        return not MonsterNavigation.IsHouseRestricted(pos)
    end)
    return entry and entry.Player or nil
end

local function horizontalDelta(origin, target)
    local delta = target - origin
    return Vector3.new(delta.X, 0, delta.Z)
end

local function getStandOff(monsterRadius, definition, targetRoot)
    local explicit = tonumber(definition.MeleeStandOffDistance)
    if explicit and explicit == explicit then
        return math.clamp(explicit, 3.5, MAX_STANDOFF)
    end
    local playerRadius = math.max(targetRoot.Size.X, targetRoot.Size.Z) * 0.5
    return math.clamp(monsterRadius + playerRadius + 1.25, MIN_STANDOFF, DEFAULT_MAX_STANDOFF)
end

local function getOrCreateFacing(root)
    local attachment = root:FindFirstChild("LumiaMeleeFacingAttachment")
    if not attachment then
        attachment = Instance.new("Attachment")
        attachment.Name = "LumiaMeleeFacingAttachment"
        attachment.Parent = root
    end

    local constraint = root:FindFirstChild("LumiaMeleeFacing")
    if not constraint then
        constraint = Instance.new("AlignOrientation")
        constraint.Name = "LumiaMeleeFacing"
        constraint.Mode = Enum.OrientationAlignmentMode.OneAttachment
        constraint.Attachment0 = attachment
        constraint.RigidityEnabled = false
        constraint.MaxTorque = 100000
        constraint.MaxAngularVelocity = 12
        constraint.Responsiveness = 15
        constraint.Enabled = false
        constraint.Parent = root
    end
    return constraint
end

local function updateFacing(humanoid, root, targetRoot, enabled)
    local existing = root:FindFirstChild("LumiaMeleeFacing")
    if not enabled then
        humanoid.AutoRotate = true
        if existing then existing.Enabled = false end
        return
    end

    local direction = horizontalDelta(root.Position, targetRoot.Position)
    if direction.Magnitude < 0.05 then return end
    humanoid.AutoRotate = false
    local constraint = existing or getOrCreateFacing(root)
    constraint.CFrame = CFrame.lookAt(Vector3.zero, direction.Unit)
    constraint.Enabled = true
end

local function hasSight(model, targetRoot)
    local root = getRoot(model)
    if not root then return false end
    local origin = root.Position + Vector3.new(0, 1, 0)
    local destination = targetRoot.Position + Vector3.new(0, 1, 0)
    local direction = destination - origin
    if direction.Magnitude < 0.01 then return true end
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = {model}
    params.IgnoreWater = true
    local hit = Workspace:Raycast(origin, direction, params)
    return not hit or hit.Instance:IsDescendantOf(targetRoot.Parent)
end

local function wanderPoint(home, definition)
    local angle = math.random() * math.pi * 2
    local radius = math.sqrt(math.random()) * definition.WanderRadius
    return home + Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
end

function MonsterAI.Run(model, definition, home)
    local humanoid = model:FindFirstChildOfClass("Humanoid")
    local root = getRoot(model)
    if not humanoid or not root then
        warn("[Lumia - Monster AI] Monster AI missing Humanoid or root")
        return
    end

    local state = "Wander"
    local target = nil
    local nextAttack = 0
    local nextWander = 0
    local wanderGoal = nil
    local wanderGoal = nillocal roofEscapeTimer = nil
    local creatureBounds = model:GetExtentsSize()
    local monsterRadius = math.max(creatureBounds.X, creatureBounds.Z) * 0.5
    local navigator = MonsterNavigation.new(model, humanoid, root, home)
    humanoid.WalkSpeed = definition.WalkSpeed

    print("[Lumia - Monster AI] Ground navigation started: " .. model.Name)

    while model.Parent and humanoid.Health > 0 do
        local now = os.clock()
        local position = root.Position
        local homeDistance = (position - home).Magnitude
        local tickInterval = WANDER_AI_TICK

        if homeDistance > definition.ChaseLimit and state ~= "Return" then
            target = nil
            state = "Return"
            navigator:Stop()
        end

        if target then
            local _, targetRoot = aliveCharacter(target)
            if not targetRoot
                or MonsterNavigation.IsHouseRestricted(targetRoot.Position)
                or (targetRoot.Position - home).Magnitude > definition.ChaseLimit then
                target = nil
                state = "Return"
                navigator:Stop()
            end
        end

        if not target and state ~= "Return"
            and definition.AggroType == "Aggressive" then
            target = nearestPlayer(position, definition.DetectionRadius)
            if target then
                state = "Chase"
                navigator:Stop()
                print("[Lumia - Monster AI] " .. model.Name .. " detected " .. target.Name)
            end
        end

        if target then
            local targetHumanoid, targetRoot = aliveCharacter(target)
            if targetHumanoid and targetRoot then
                tickInterval = MELEE_AI_TICK
                local delta = horizontalDelta(position, targetRoot.Position)
                local distance = delta.Magnitude
                local verticalDistance = math.abs(targetRoot.Position.Y - position.Y)
                local direction = distance > 0.05 and delta.Unit or root.CFrame.LookVector
                direction = Vector3.new(direction.X, 0, direction.Z)
                direction = direction.Magnitude > 0.05 and direction.Unit or Vector3.new(0, 0, -1)

                local standOff = getStandOff(monsterRadius, definition, targetRoot)
                local retreatDistance = tonumber(definition.MeleeRetreatDistance)
                    or (standOff - RETREAT_BAND)
                retreatDistance = math.clamp(retreatDistance, 2.5, standOff - 0.4)
                local attackDistance = math.max(
                    tonumber(definition.AttackRange) or standOff,
                    standOff + MELEE_CONTACT_MARGIN
                )
                local visible = verticalDistance <= MAX_MELEE_HEIGHT_DIFFERENCE
                    and hasSight(model, targetRoot)

                if verticalDistance > 5.5 then
                    -- Stage 3a: player is unreachable above. Wolf paths to base,
                    -- waits 8s, then leashes home. Never freezes forever.
                    state = "Chase"
                    updateFacing(humanoid, root, targetRoot, false)
                    if not roofEscapeTimer then
                        roofEscapeTimer = now
                        local roofBase = Vector3.new(targetRoot.Position.X, home.Y, targetRoot.Position.Z)
                        navigator:SetGoal(roofBase, "Chase")
                        humanoid.WalkSpeed = math.min(definition.ChaseSpeed, 10)
                    end
                    if now - roofEscapeTimer >= 8 then
                        target = nil
                        state = "Return"
                        roofEscapeTimer = nil
                        navigator:Stop()
                    else
                        navigator:Step(now)
                    end
                elseif distance < retreatDistance and visible then
                    state = "Reposition"
                    updateFacing(humanoid, root, targetRoot, true)
                    humanoid.WalkSpeed = math.min(definition.WalkSpeed, 7)
                    navigator:SetGoal(
                        position - direction * math.max(2, standOff - distance + 0.7),
                        "Retreat"
                    )
                    navigator:Step(now)
                elseif distance <= standOff + CHASE_BAND and visible then
                    state = "Attack"
                    updateFacing(humanoid, root, targetRoot, true)
                    navigator:Stop()
                    humanoid.WalkSpeed = 0

                    if distance <= attackDistance and now >= nextAttack then
                        nextAttack = now + definition.AttackCooldown
                        model:SetAttribute("LumiaAttackSerial", (model:GetAttribute("LumiaAttackSerial") or 0) + 1)
                        local rawDamage = definition.Damage
                        if model:GetAttribute("LumiaBossEnraged") == true then rawDamage *= 1.25 end
                        targetHumanoid:TakeDamage(CombatStats.IncomingDamage(target, rawDamage))
                        print("[Lumia - Monster AI] " .. model.Name .. " attacked " .. target.Name)
                    end
                else
                    state = "Chase"
                    updateFacing(humanoid, root, targetRoot, false)
                    humanoid.WalkSpeed = distance < standOff + 3
                        and math.min(definition.ChaseSpeed, 7) or definition.ChaseSpeed
                    navigator:SetGoal(targetRoot.Position - direction * standOff, "Chase")
                    navigator:Step(now)
                end
            end
        elseif state == "Return" then
            updateFacing(humanoid, root, root, false)
            humanoid.WalkSpeed = definition.WalkSpeed
            if homeDistance <= 5 then
                state = "Wander"
                wanderGoal = nil
                nextWander = now + 2
                navigator:Stop()
            else
                navigator:SetGoal(home, "Return")
                navigator:Step(now)
            end
        else
            updateFacing(humanoid, root, root, false)
            state = "Wander"
            humanoid.WalkSpeed = definition.WalkSpeed
            if now >= nextWander then
                wanderGoal = wanderPoint(home, definition)
                nextWander = now + math.random(3, 6)
            end
            if wanderGoal then
                navigator:SetGoal(wanderGoal, "Wander")
                navigator:Step(now)
            end
        end

        model:SetAttribute("InCombat", target ~= nil)
        task.wait(tickInterval)
    end

    navigator:Destroy()
    updateFacing(humanoid, root, root, false)
    print("[Lumia - Monster AI] Monster AI stopped: " .. model.Name)
end

return MonsterAI
