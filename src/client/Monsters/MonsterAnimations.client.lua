-- REALMS OF LUMIA - CLIENT CREATURE ANIMATIONS (WALK + ATTACK)
-- Visual-only procedural joint animation; combat damage stays server-side.
-- A single update loop animates all nearby monsters. No loop per wolf.
-- Uses named Motor6D joints from CreatureAnimationProfiles. No R6/R15 assumptions.
-- Later custom rigs only need a joint profile, not changes to MonsterAI.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local localPlayer = Players.LocalPlayer
local Profiles = require(script.Parent:WaitForChild("CreatureAnimationProfiles"))
local monsterFolder = Workspace:WaitForChild("LumiaMonsters")

local ACTIVE_DISTANCE = 95
local NEAR_DISTANCE = 55
local NEAR_UPDATE_INTERVAL = 1 / 30
local FAR_UPDATE_INTERVAL = 1 / 12
local WALK_SMOOTHING = 11

local records = {} -- Model -> client-only rig/joint and attack animation state
local elapsed = 0

local function findMotorByName(model, motorName)
    local candidate = model:FindFirstChild(motorName, true)
    if candidate and candidate:IsA("Motor6D") then
        return candidate
    end
    return nil
end

local function horizontalSpeed(root)
    local velocity = root.AssemblyLinearVelocity
    return math.sqrt(velocity.X * velocity.X + velocity.Z * velocity.Z)
end

local function currentObserverPosition()
    local character = localPlayer.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    if root and root:IsA("BasePart") then
        return root.Position
    end
    local camera = Workspace.CurrentCamera
    return camera and camera.CFrame.Position or nil
end

local function rigFor(model)
    local rigName = model:GetAttribute("LumiaAnimationRig")
    if type(rigName) ~= "string" or rigName == "" then
        rigName = model:GetAttribute("MonsterId")
    end
    return type(rigName) == "string" and Profiles[rigName] or nil
end

local function trackMonster(model)
    if records[model] or not model:IsA("Model") then
        return
    end

    local profile = rigFor(model)
    if not profile then
        return -- New creature without animation rig profile stays unmodified.
    end

    local humanoid = model:FindFirstChildOfClass("Humanoid")
    local root = model:FindFirstChild("HumanoidRootPart")
    if not humanoid or not root or not root:IsA("BasePart") then
        return
    end

    local joints = {}
    local baseC0 = {}
    local jointCount = 0
    for role, motorName in pairs(profile.Joints) do
        local motor = findMotorByName(model, motorName)
        if motor then
            joints[role] = motor
            baseC0[role] = motor.C0
            jointCount += 1
        end
    end

    -- Do not animate an incomplete or unrelated rig by accident.
    if jointCount < 4
        or not joints.FrontLeft or not joints.FrontRight
        or not joints.RearLeft or not joints.RearRight then
        return
    end

    records[model] = {
        Model = model,
        Humanoid = humanoid,
        Root = root,
        Profile = profile,
        Joints = joints,
        Base = baseC0,
        GaitPhase = 0,
        WalkBlend = 0,
        AttackSerial = model:GetAttribute("LumiaAttackSerial") or 0,
        AttackStarted = -math.huge,
        LastUpdate = 0,
        CurrentAngles = {},
        Reset = false,
    }
end

local function setPose(record, pose)
    for role, motor in pairs(record.Joints) do
        if motor.Parent and record.Base[role] then
            local angles = pose[role]
            if angles then
                motor.C0 = record.Base[role]
                    * CFrame.Angles(angles[1] or 0, angles[2] or 0, angles[3] or 0)
            else
                motor.C0 = record.Base[role]
            end
        end
    end
end

local function resetPose(record)
    if record.Reset then
        return
    end
    setPose(record, {})
    record.Reset = true
end

local function untrackMonster(model)
    local record = records[model]
    if record then
        resetPose(record)
        records[model] = nil
    end
end

local function animate(record, dt, now)
    local model = record.Model
    local humanoid = record.Humanoid
    local root = record.Root
    if model.Parent ~= monsterFolder or not root.Parent
        or humanoid.Health <= 0 then
        untrackMonster(model)
        return
    end

    local observer = currentObserverPosition()
    if not observer then
        resetPose(record)
        return
    end

    local distance = (root.Position - observer).Magnitude
    if distance > ACTIVE_DISTANCE then
        resetPose(record)
        return
    end

    local interval = distance < NEAR_DISTANCE and NEAR_UPDATE_INTERVAL or FAR_UPDATE_INTERVAL
    if now - record.LastUpdate < interval then
        return
    end
    local updateDt = math.min(now - record.LastUpdate, 0.15)
    record.LastUpdate = now

    local serial = model:GetAttribute("LumiaAttackSerial")
    if type(serial) == "number" and serial ~= record.AttackSerial then
        record.AttackSerial = serial
        record.AttackStarted = now
    end

    -- Walking follows actual horizontal motion, not the AI's chosen target.
    local walk = record.Profile.Walk
    local speed = horizontalSpeed(root)
    local desired = speed >= walk.MinSpeed and 1 or 0
    record.WalkBlend += (desired - record.WalkBlend)
        * (1 - math.exp(-WALK_SMOOTHING * updateDt))

    record.GaitPhase += updateDt * walk.Frequency * math.pi * 2
    local swing = math.sin(record.GaitPhase) * record.WalkBlend
    local counter = math.sin(record.GaitPhase + math.pi) * record.WalkBlend
    local step = math.abs(math.cos(record.GaitPhase)) * record.WalkBlend

    local pose = {
        -- Diagonal quadruped gait: front-left matches rear-right.
        FrontLeft = {swing * walk.LegPitch},
        FrontRight = {counter * walk.LegPitch},
        RearLeft = {counter * walk.LegPitch},
        RearRight = {swing * walk.LegPitch},
        FrontLeftPaw = {-swing * walk.PawPitch},
        FrontRightPaw = {-counter * walk.PawPitch},
        RearLeftPaw = {-counter * walk.PawPitch},
        RearRightPaw = {-swing * walk.PawPitch},
        Neck = {step * walk.HeadPitch},
        Tail = {0, swing * walk.TailYaw},
    }

    -- Attack is triggered by MonsterAI on the server whenever a real bite
    -- deals damage. This does not change damage, cooldowns or attack range.
    local attack = record.Profile.Attack
    local elapsedAttack = now - record.AttackStarted
    if elapsedAttack >= 0 and elapsedAttack < attack.Duration then
        local progress = elapsedAttack / attack.Duration
        local strike = math.sin(progress * math.pi)
        -- Slight head pullback, then quick forward bite gesture.
        local head = progress < 0.3
            and (-attack.HeadPitch * (progress / 0.3))
            or (attack.HeadPitch * strike)

        pose.FrontLeft = {-attack.FrontLegPitch * strike}
        pose.FrontRight = {-attack.FrontLegPitch * strike}
        pose.RearLeft = {attack.RearLegPitch * strike}
        pose.RearRight = {attack.RearLegPitch * strike}
        pose.Neck = {head}
        pose.Muzzle = {-attack.MuzzlePitch * strike}
        pose.Tail = {-attack.TailPitch * strike}
    end

    setPose(record, pose)
    record.Reset = false
end

for _, model in ipairs(monsterFolder:GetChildren()) do
    trackMonster(model)
end

monsterFolder.ChildAdded:Connect(function(model)
    trackMonster(model)
end)

monsterFolder.ChildRemoved:Connect(function(model)
    untrackMonster(model)
end)

RunService.Heartbeat:Connect(function(dt)
    elapsed += dt
    local now = os.clock()
    for _, record in pairs(records) do
        animate(record, dt, now)
    end
end)

print("[Lumia - Monster Animations] Creature animations ready - Walk + Bite (client LOD)")
