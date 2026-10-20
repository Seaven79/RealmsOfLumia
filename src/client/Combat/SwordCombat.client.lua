-- REALMS OF LUMIA - PLAYER SWORD CONTROLLER
-- Tool.Activated handles mouse/controller/touch. Server validates every hit.
-- Whoosh plays on procedural blade's cutting phase; no sound on wind-up.
-- Procedural shoulder + elbow motion supports R6 Motor6D and newer R15
-- AnimationConstraint rigs without requiring an uploaded animation asset.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")
local ContentProvider = game:GetService("ContentProvider")
local Debris = game:GetService("Debris")

local player = Players.LocalPlayer
local network = ReplicatedStorage:WaitForChild("Lumia"):WaitForChild("CombatNetwork")
local attackRemote = network:WaitForChild("RequestSwordAttack")
local swingRemote = network:WaitForChild("SwordSwing")
local hitRemote = network:WaitForChild("SwordHit")
local AudioConfig = require(ReplicatedStorage:WaitForChild("Lumia")
    :WaitForChild("Shared"):WaitForChild("Combat"):WaitForChild("CombatAudioConfig"))

-- One cached sound template for all swings; creation and asset fetching are
-- moved out of the attack itself to minimize perceived audio lag.
local whooshTemplate = Instance.new("Sound")
whooshTemplate.Name = "LumiaWhooshPreloaded"
whooshTemplate.SoundId = AudioConfig.SwingSoundId
whooshTemplate.Volume = AudioConfig.SwingVolume
whooshTemplate.RollOffMode = Enum.RollOffMode.Inverse
whooshTemplate.RollOffMinDistance = AudioConfig.RollOffMinDistance
whooshTemplate.RollOffMaxDistance = AudioConfig.RollOffMaxDistance
whooshTemplate.Parent = SoundService

task.spawn(function()
    local ok, err = pcall(function()
        ContentProvider:PreloadAsync({ whooshTemplate })
    end)
    if not ok then
        warn("[Lumia - Sword Combat] Could not preload sword whoosh: " .. tostring(err))
    end
end)

local localConnections = {}
local trackedTool = nil
local localNextSwing = 0
local swings = {} -- Character -> {StartedAt, Joints, Trail}
local SWING_TIME = AudioConfig.SwingDuration
local soundRandom = Random.new()

local function findJoint(character, name)
    local fallback = nil
    for _, instance in ipairs(character:GetDescendants()) do
        if instance.Name == name then
            if instance:IsA("AnimationConstraint") then return instance end
            if instance:IsA("Motor6D") then fallback = instance end
        end
    end
    return fallback
end

local function jointsFor(character)
    return {
        Shoulder = findJoint(character, "RightShoulder")
            or findJoint(character, "Right Shoulder"),
        Elbow = findJoint(character, "RightElbow") or findJoint(character, "Right Elbow"),
        LeftShoulder = findJoint(character, "LeftShoulder")
            or findJoint(character, "Left Shoulder"),
        LeftElbow = findJoint(character, "LeftElbow") or findJoint(character, "Left Elbow"),
        Waist = findJoint(character, "Waist"),
    }
end

local function findSword(character)
    if not character then return nil end
    for _, instance in ipairs(character:GetChildren()) do
        if instance:IsA("Tool") and instance:GetAttribute("LumiaCombatTool") == true then
            return instance
        end
    end
    return nil
end

local function setTrail(tool, enabled)
    if not tool then return end
    local trail = tool:FindFirstChild("LumiaSwingTrail", true)
    if trail and trail:IsA("Trail") then trail.Enabled = enabled end
end

local function playSwing(character)
    if not character or not character.Parent then return end
    local sword = findSword(character)
    if not sword then return end
    -- A new valid attack restarts the local visual animation.
    swings[character] = {
        StartedAt = os.clock(),
        Joints = jointsFor(character),
        Sword = sword,
        WhooshPlayed = false,
        TrailOn = false,
    }
    setTrail(sword, false) -- Only the cutting movement should leave a streak.
end

local function playWhoosh(tool)
    local handle = tool and tool:FindFirstChild("Handle")
    if not handle or not handle:IsA("BasePart") then return end

    local sound = whooshTemplate:Clone()
    sound.Name = "LumiaSwordWhoosh"
    sound.PlaybackSpeed = soundRandom:NextNumber(0.96, 1.04)
    sound.Parent = handle
    sound:Play()
    Debris:AddItem(sound, 2)
end

local function eased(t)
    t = math.clamp(t, 0, 1)
    return t * t * (3 - 2 * t)
end

local function swingPose(t)
    -- Wind-up (0-28%), diagonal cut (28-72%), recovery (72-100%).
    local startShoulder = CFrame.new()
    local windShoulder = CFrame.Angles(math.rad(-62), math.rad(18), math.rad(52))
    local cutShoulder = CFrame.Angles(math.rad(42), math.rad(-22), math.rad(-68))
    local startElbow = CFrame.new()
    local windElbow = CFrame.Angles(math.rad(-58), 0, 0)
    local cutElbow = CFrame.Angles(math.rad(12), 0, 0)
    local windWaist = CFrame.Angles(0, math.rad(-17), 0)
    local cutWaist = CFrame.Angles(0, math.rad(20), 0)

    if t < 0.28 then
        local alpha = eased(t / 0.28)
        return startShoulder:Lerp(windShoulder, alpha),
            startElbow:Lerp(windElbow, alpha),
            CFrame.new():Lerp(windWaist, alpha)
    elseif t < 0.72 then
        local alpha = eased((t - 0.28) / 0.44)
        return windShoulder:Lerp(cutShoulder, alpha),
            windElbow:Lerp(cutElbow, alpha),
            windWaist:Lerp(cutWaist, alpha)
    end
    local alpha = eased((t - 0.72) / 0.28)
    return cutShoulder:Lerp(CFrame.new(), alpha),
        cutElbow:Lerp(CFrame.new(), alpha),
        cutWaist:Lerp(CFrame.new(), alpha)
end

local function applyOffset(joint, offset)
    if joint and joint.Parent then
        -- Animator evaluates first; PreSimulation layers the sword pose on top.
        joint.Transform = joint.Transform * offset
    end
end

RunService.PreSimulation:Connect(function()
    local now = os.clock()
    for character, state in pairs(swings) do
        local elapsed = now - state.StartedAt
        if elapsed >= SWING_TIME or character.Parent == nil
            or state.Sword.Parent ~= character then
            setTrail(state.Sword, false)
            swings[character] = nil
        else
            local phase = elapsed / SWING_TIME

            -- The whoosh begins on the FIRST simulation step of the cut,
            -- not at mouse-click/wind-up and not after a network response.
            if not state.WhooshPlayed and phase >= AudioConfig.WhooshPhase then
                state.WhooshPlayed = true
                playWhoosh(state.Sword)
            end

            local trailShouldBeOn = phase >= AudioConfig.TrailStartPhase
                and phase < AudioConfig.TrailEndPhase
            if state.TrailOn ~= trailShouldBeOn then
                state.TrailOn = trailShouldBeOn
                setTrail(state.Sword, trailShouldBeOn)
            end

            local humanoid = character:FindFirstChildOfClass("Humanoid")
            local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
            if not animator or not animator.EvaluationThrottled then
                local shoulder, elbow, waist = swingPose(phase)
                applyOffset(state.Joints.Shoulder, shoulder)
                applyOffset(state.Joints.Elbow, elbow)
                applyOffset(state.Joints.Waist, waist)
            end
        end
    end
end)

local function disconnectTool()
    for _, connection in ipairs(localConnections) do connection:Disconnect() end
    table.clear(localConnections)
    trackedTool = nil
end

local function bindTool(tool)
    if trackedTool == tool then return end
    disconnectTool()
    if not tool or tool:GetAttribute("LumiaCombatTool") ~= true then return end
    trackedTool = tool

    table.insert(localConnections, tool.Activated:Connect(function()
        if tool.Parent ~= player.Character then return end
        -- Loot clicks are interactions, not attacks. Loot controller owns
        -- hover feedback; server still verifies corpse ownership and range.
        if player:GetAttribute("LumiaLootHoverActive") == true then return end
        local target = player:GetMouse().Target
        local corpse = target and target:FindFirstAncestorOfClass("Model")
        if corpse and corpse:GetAttribute("LumiaLootableCorpse") == true
            and corpse:GetAttribute("LumiaLootOwnerUserId") == player.UserId then
            local corpseRoot = corpse:FindFirstChild("HumanoidRootPart")
            local ownRoot = player.Character:FindFirstChild("HumanoidRootPart")
            if corpseRoot and ownRoot
                and (ownRoot.Position - corpseRoot.Position).Magnitude <= 12 then return end
        end
        local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
        if not humanoid or humanoid.Health <= 0 then return end
        local cooldown = tonumber(tool:GetAttribute("LumiaCooldown")) or 0.5
        cooldown = math.clamp(cooldown, 0.25, 3)
        local now = os.clock()
        if now < localNextSwing then return end
        localNextSwing = now + cooldown
        playSwing(player.Character) -- Instant local feedback.
        attackRemote:FireServer()  -- No client damage/target/range supplied.
    end))
end

local function watchCharacter(character)
    local function check()
        bindTool(findSword(character))
    end
    local added = character.ChildAdded:Connect(function(child)
        if child:IsA("Tool") then task.defer(check) end
    end)
    local removed = character.ChildRemoved:Connect(function(child)
        if child == trackedTool then task.defer(check) end
    end)
    localNextSwing = 0
    check()
    return added, removed
end

local characterConnections = {}
local function attach(character)
    for _, connection in ipairs(characterConnections) do connection:Disconnect() end
    table.clear(characterConnections)
    disconnectTool()
    if character then
        local a, b = watchCharacter(character)
        table.insert(characterConnections, a)
        table.insert(characterConnections, b)
    end
end

player.CharacterAdded:Connect(attach)
player.CharacterRemoving:Connect(function(character)
    local state = swings[character]
    if state then setTrail(state.Sword, false) end
    swings[character] = nil
    attach(nil)
end)
attach(player.Character)

swingRemote.OnClientEvent:Connect(function(attacker)
    if typeof(attacker) ~= "Instance" or not attacker:IsA("Player") then return end
    if attacker == player then return end -- We already animated immediately on click.
    playSwing(attacker.Character)
end)

hitRemote.OnClientEvent:Connect(function(model, damage)
    if typeof(model) ~= "Instance" or not model:IsA("Model")
        or type(damage) ~= "number" then return end
    local root = model:FindFirstChild("HumanoidRootPart")
    if not root or not root:IsA("BasePart") then return end

    local playerGui = player:FindFirstChildOfClass("PlayerGui")
    if not playerGui then return end
    local popup = Instance.new("BillboardGui")
    popup.Name = "LumiaSwordHit"
    popup.Adornee = root
    popup.Size = UDim2.fromOffset(130, 60)
    popup.StudsOffsetWorldSpace = Vector3.new(0, 3, 0)
    popup.AlwaysOnTop = true
    popup.Parent = playerGui

    local label = Instance.new("TextLabel")
    label.Size = UDim2.fromScale(1, 1)
    label.BackgroundTransparency = 1
    label.Font = Enum.Font.GothamBold
    label.TextScaled = true
    label.TextColor3 = Color3.fromRGB(255, 220, 120)
    label.TextStrokeTransparency = 0.2
    label.Text = "-" .. tostring(math.floor(damage))
    label.Parent = popup

    TweenService:Create(popup, TweenInfo.new(0.65), {
        StudsOffsetWorldSpace = Vector3.new(0, 5.25, 0),
    }):Play()
    TweenService:Create(label, TweenInfo.new(0.65), {
        TextTransparency = 1,
        TextStrokeTransparency = 1,
    }):Play()
    task.delay(0.7, function() popup:Destroy() end)
end)

print("[Lumia - Sword Combat] Sword controls ready - equip MainHand, then click to swing")

-- ===== FIST FALLBACK =====
-- Weaponless left-click fires RequestSwordAttack; server routes to _onFistAttack.
-- Punch animation via Motor6D / AnimationConstraint Transform offset (no asset needed).

local UserInputService = game:GetService("UserInputService")
local fistCooldownUntil = 0
local FIST_COOLDOWN = 0.6
local FIST_SWING_TIME = 0.28

-- Fighting-game punch, Street Fighter style: the striking arm rises just past
-- horizontal and crosses toward the centre line while the off arm stays up in
-- a guard. Chamber -> strike -> recover.
-- Composition note: the strike shoulder is built as Y * X, not CFrame.Angles(x, y, 0).
-- A hanging arm points along -Y, so a Y rotation applied FIRST does nothing to
-- it. Y has to wrap the already-extended arm to sweep the fist sideways.
local CHAMBER_SHOULDER = CFrame.Angles(math.rad(-20), 0, 0)
local STRIKE_SHOULDER = CFrame.Angles(0, math.rad(18), 0) * CFrame.Angles(math.rad(98), 0, 0)
local CHAMBER_ELBOW = CFrame.Angles(math.rad(-68), 0, 0)
local STRIKE_ELBOW = CFrame.Angles(math.rad(8), 0, 0)

-- Off arm: raised and folded in front of the chest for the whole punch.
local GUARD_SHOULDER = CFrame.Angles(math.rad(58), 0, 0)
local GUARD_ELBOW = CFrame.Angles(math.rad(-88), 0, 0)

local CHAMBER_WAIST = CFrame.Angles(0, math.rad(-14), 0)
local STRIKE_WAIST = CFrame.Angles(0, math.rad(22), 0)

local function punchPose(t)
    local neutral = CFrame.new()

    if t < 0.22 then
        -- Chamber: fist back to the ribs, guard comes up, torso coils.
        local a = eased(t / 0.22)
        return {
            Shoulder = neutral:Lerp(CHAMBER_SHOULDER, a),
            Elbow = neutral:Lerp(CHAMBER_ELBOW, a),
            LeftShoulder = neutral:Lerp(GUARD_SHOULDER, a),
            LeftElbow = neutral:Lerp(GUARD_ELBOW, a),
            Waist = neutral:Lerp(CHAMBER_WAIST, a),
        }
    elseif t < 0.50 then
        -- Strike: arm extends forward, above the horizontal, across the body.
        local a = eased((t - 0.22) / 0.28)
        return {
            Shoulder = CHAMBER_SHOULDER:Lerp(STRIKE_SHOULDER, a),
            Elbow = CHAMBER_ELBOW:Lerp(STRIKE_ELBOW, a),
            LeftShoulder = GUARD_SHOULDER,
            LeftElbow = GUARD_ELBOW,
            Waist = CHAMBER_WAIST:Lerp(STRIKE_WAIST, a),
        }
    end

    -- Recovery: everything returns to neutral, slower than the strike.
    local a = eased((t - 0.50) / 0.50)
    return {
        Shoulder = STRIKE_SHOULDER:Lerp(neutral, a),
        Elbow = STRIKE_ELBOW:Lerp(neutral, a),
        LeftShoulder = GUARD_SHOULDER:Lerp(neutral, a),
        LeftElbow = GUARD_ELBOW:Lerp(neutral, a),
        Waist = STRIKE_WAIST:Lerp(neutral, a),
    }
end

local function playFistSwing(character)
    if not character or not character.Parent then return end
    local joints = jointsFor(character)
    if not joints.Shoulder then return end
    local startTime = os.clock()
    local conn
    conn = RunService.PreSimulation:Connect(function()
        local elapsed = os.clock() - startTime
        if elapsed >= FIST_SWING_TIME or not joints.Shoulder.Parent then
            conn:Disconnect()
            return
        end
        local phase = math.clamp(elapsed / FIST_SWING_TIME, 0, 1)
        for key, offset in pairs(punchPose(phase)) do
            applyOffset(joints[key], offset)
        end
    end)
end

UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
    local character = player.Character
    if not character then return end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid or humanoid.Health <= 0 then return end
    if trackedTool then return end
    if player:GetAttribute("LumiaLootHoverActive") == true then return end
    local now = os.clock()
    if now < fistCooldownUntil then return end
    fistCooldownUntil = now + FIST_COOLDOWN
    playFistSwing(character)
    attackRemote:FireServer()
end)

print("[Lumia - Sword Combat] Fist fallback ready - click with no weapon to punch")
