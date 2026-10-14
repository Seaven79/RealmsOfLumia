local Players = game:GetService("Players")

local MonsterAI = {}

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
    local nearest = nil
    local distance = radius

    for _, player in ipairs(Players:GetPlayers()) do
        local _, root = aliveCharacter(player)

        if root then
            local d = (root.Position - position).Magnitude

            if d < distance then
                distance = d
                nearest = player
            end
        end
    end

    return nearest
end

function MonsterAI.Run(model, definition, home)
    local humanoid = model:FindFirstChildOfClass("Humanoid")
    local root = getRoot(model)

    if not humanoid or not root then
        warn("[Lumia] Monster AI missing Humanoid or root")
        return
    end

    local state = "Wander"
    local target = nil
    local nextAttack = 0
    local nextMove = 0
    local wanderGoal = nil
    local nextWander = 0

    humanoid.WalkSpeed = definition.WalkSpeed

    print("[Lumia] Monster AI started: " .. model.Name)

    while model.Parent and humanoid.Health > 0 do
        local now = os.clock()
        local position = root.Position
        local homeDistance = (position - home).Magnitude

        if homeDistance > definition.ChaseLimit then
            target = nil
            state = "Return"
        end

        if target then
            local _, targetRoot = aliveCharacter(target)

            if not targetRoot
                or (targetRoot.Position - home).Magnitude
                    > definition.ChaseLimit then
                target = nil
                state = "Return"
            end
        end

        if not target and state ~= "Return"
            and definition.AggroType == "Aggressive" then

            target = nearestPlayer(
                position,
                definition.DetectionRadius
            )

            if target then
                state = "Chase"
                print("[Lumia] " .. model.Name
                    .. " detected " .. target.Name)
            end
        end

        if target then
            local targetHumanoid, targetRoot =
                aliveCharacter(target)

            if targetHumanoid and targetRoot then
                local distance =
                    (targetRoot.Position - position).Magnitude

                if distance <= definition.AttackRange then
                    state = "Attack"
                    humanoid:MoveTo(position)

                    if now >= nextAttack then
                        nextAttack =
                            now + definition.AttackCooldown

                        targetHumanoid:TakeDamage(
                            definition.Damage
                        )

                        print("[Lumia] " .. model.Name
                            .. " attacked " .. target.Name)
                    end
                else
                    state = "Chase"
                    humanoid.WalkSpeed =
                        definition.ChaseSpeed

                    if now >= nextMove then
                        nextMove = now + 0.8
                        humanoid:MoveTo(targetRoot.Position)
                    end
                end
            end

        elseif state == "Return" then
            humanoid.WalkSpeed = definition.WalkSpeed

            if homeDistance <= 5 then
                state = "Wander"
                wanderGoal = nil
                nextWander = now + 2
            elseif now >= nextMove then
                nextMove = now + 1
                humanoid:MoveTo(home)
            end

        else
            state = "Wander"
            humanoid.WalkSpeed = definition.WalkSpeed

            if now >= nextWander then
                local angle = math.random() * math.pi * 2
                local radius =
                    math.sqrt(math.random())
                    * definition.WanderRadius

                wanderGoal = home + Vector3.new(
                    math.cos(angle) * radius,
                    0,
                    math.sin(angle) * radius
                )

                nextWander = now + math.random(3, 6)
            end

            if wanderGoal and now >= nextMove then
                nextMove = now + 1
                humanoid:MoveTo(wanderGoal)
            end
        end

        model:SetAttribute("InCombat", target ~= nil)
        task.wait(0.25)
    end

    print("[Lumia] Monster AI stopped: " .. model.Name)
end

return MonsterAI