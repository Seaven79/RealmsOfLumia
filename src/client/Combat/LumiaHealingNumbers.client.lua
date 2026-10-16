-- REALMS OF LUMIA - FLOATING HEAL NUMBERS (V14 ADD-ON)
-- Purely visual client feature: observes server-replicated Humanoid.Health.
-- Shows the ACTUAL HP restored over each player's head (R6 and R15).
-- Does not grant healing, consume items, change saves, or call remotes.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local MIN_VISIBLE_HEAL = 0.5
local FLOAT_DURATION = 0.9
local MAX_VIEW_DISTANCE = 85
local random = Random.new()
local tracked = {}

local function showHeal(head, healed)
    if not head or not head:IsA("BasePart") or not head.Parent or healed < 1 then
        return
    end

    local offset = Vector3.new(random:NextNumber(-0.35, 0.35), 1.7, 0)
    local billboard = Instance.new("BillboardGui")
    billboard.Name = "LumiaFloatingHeal"
    billboard.Adornee = head
    billboard.AlwaysOnTop = true
    billboard.LightInfluence = 0
    billboard.MaxDistance = MAX_VIEW_DISTANCE
    billboard.Size = UDim2.fromOffset(110, 44)
    billboard.StudsOffsetWorldSpace = offset
    billboard.Parent = head

    local number = Instance.new("TextLabel")
    number.Name = "Amount"
    number.BackgroundTransparency = 1
    number.Size = UDim2.fromScale(1, 1)
    number.Text = "+" .. tostring(healed)
    number.TextColor3 = Color3.fromRGB(105, 255, 138)
    number.TextStrokeColor3 = Color3.fromRGB(12, 50, 22)
    number.TextStrokeTransparency = 0.22
    number.Font = Enum.Font.GothamBold
    number.TextScaled = true
    number.Parent = billboard

    local tweenInfo = TweenInfo.new(FLOAT_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    TweenService:Create(billboard, tweenInfo, {
        StudsOffsetWorldSpace = offset + Vector3.new(0, 1.2, 0),
    }):Play()
    TweenService:Create(number, tweenInfo, {
        TextTransparency = 1,
        TextStrokeTransparency = 1,
    }):Play()
    Debris:AddItem(billboard, FLOAT_DURATION + 0.15)
end

local function clearHealthConnection(state)
    if state.healthConnection then
        state.healthConnection:Disconnect()
        state.healthConnection = nil
    end
end

local function watchCharacter(player, character)
    local state = tracked[player]
    if not state then return end
    state.serial += 1
    local serial = state.serial
    clearHealthConnection(state)

    task.spawn(function()
        local humanoid = character:WaitForChild("Humanoid", 10)
        local head = character:WaitForChild("Head", 10)
        if not humanoid or not humanoid:IsA("Humanoid")
            or not head or not head:IsA("BasePart")
            or tracked[player] ~= state or state.serial ~= serial then
            return
        end

        local previousHealth = humanoid.Health
        state.healthConnection = humanoid.HealthChanged:Connect(function(health)
            local gained = health - previousHealth
            previousHealth = health

            -- A 35 HP potion at 90/100 correctly shows +10, not +35.
            -- Damage and max-health initialization should never generate fake heals.
            if gained < MIN_VISIBLE_HEAL or health <= 0 or not character.Parent then return end
            local displayed = math.floor(gained + 0.5)
            if displayed > 0 then showHeal(head, displayed) end
        end)
    end)
end

local function stopTracking(player)
    local state = tracked[player]
    if not state then return end
    state.serial += 1
    clearHealthConnection(state)
    for _, connection in ipairs(state.connections) do
        connection:Disconnect()
    end
    tracked[player] = nil
end

local function startTracking(player)
    if tracked[player] then return end
    local state = { serial = 0, connections = {}, healthConnection = nil }
    tracked[player] = state

    table.insert(state.connections, player.CharacterAdded:Connect(function(character)
        watchCharacter(player, character)
    end))
    table.insert(state.connections, player.CharacterRemoving:Connect(function()
        state.serial += 1
        clearHealthConnection(state)
    end))
    if player.Character then
        watchCharacter(player, player.Character)
    end
end

Players.PlayerAdded:Connect(startTracking)
Players.PlayerRemoving:Connect(stopTracking)
for _, player in ipairs(Players:GetPlayers()) do
    startTracking(player)
end

print("[Lumia - Floating Heal] Green healing numbers above player heads ready")
