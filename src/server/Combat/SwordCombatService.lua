-- REALMS OF LUMIA - SWORD COMBAT SERVICE (MELEE ON STEPS / SLOPES)
-- Only the server chooses weapon, target, hit timing, and damage.
-- The custom inventory remains the ONLY owner of equipped item records.
-- Native Roblox Tool equip handles the physical sword on both R6 and R15.
--
-- This version replaces "nearest root only" targeting with a reusable
-- forward melee volume so attacks feel like a proper frontal sword swing.
-- Any future creature under workspace.LumiaMonsters with a MonsterId
-- attribute automatically works with this hit detection.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local shared = ReplicatedStorage:WaitForChild("Lumia"):WaitForChild("Shared")
local ItemDefinitions = require(shared:WaitForChild("Items"):WaitForChild("ItemDefinitions"))
local services = script.Parent.Parent
local ItemFactory = require(services:WaitForChild("Items"):WaitForChild("ItemFactory"))
local CombatStats = require(script.Parent:WaitForChild("CombatStats"))
local BalanceService = require(services:WaitForChild("Admin"):WaitForChild("BalanceService"))

local SwordCombatService = {}
local dataService = nil
local started = false

local activeTools = {}        -- Player -> Tool created by the server
local refreshTokens = {}      -- Prevent stale equip jobs after a rapid swap
local lastAttacks = {}        -- Player -> server-clock last accepted swing
local playerConnections = {}  -- Player -> connections

local attackRemote
local swingRemote
local hitRemote

-- Allow the melee volume to reach a creature standing a few studs lower/higher.
-- Final target validation still enforces lateral reach, facing, and wall checks.
local HITBOX_HEIGHT = 7.0
local MAX_TARGET_VERTICAL_SEPARATION = 4.0
local HITBOX_MIN_WIDTH = 4.5
local HITBOX_MAX_WIDTH = 7.5
local HITBOX_FRONT_PADDING = -0.15
local HITBOX_REACH_PADDING = 1.25
local HITBOX_MIN_DOT = 0.10
local CLOSE_RANGE_RECOVERY = 3.0 -- Includes targets crowding the avatar, not distant rear targets.

local function getEquipment(player)
    local profile = dataService and dataService:GetProfile(player)
    if not profile then
        return false, nil, nil
    end

    local inventory = profile.Inventory
    if type(inventory) ~= "table"
        or type(inventory.Equipment) ~= "table"
        or type(inventory.Items) ~= "table" then
        return true, nil, nil
    end

    local instanceId = inventory.Equipment.MainHand
    if type(instanceId) ~= "string" then
        return true, nil, nil
    end

    for _, record in ipairs(inventory.Items) do
        if type(record) == "table"
            and record.InstanceId == instanceId
            and record.Quantity == 1 then
            local definition = ItemDefinitions.Get(record.ItemId)
            if definition
                and definition.Type == "Weapon"
                and definition.SubType == "OneHandSword" then
                return true, record, definition
            end
        end
    end

    return true, nil, nil
end

local function humanoidAndRoot(character)
    if not character then
        return nil, nil
    end

    local humanoid = character:FindFirstChildOfClass("Humanoid")
    local root = character:FindFirstChild("HumanoidRootPart")

    if humanoid and root and root:IsA("BasePart") and humanoid.Health > 0 then
        return humanoid, root
    end

    return nil, nil
end

local function isValidWeapon(player, character)
    local ready, record, definition = getEquipment(player)
    if not ready or not record then
        return nil, nil, nil
    end

    local tool = activeTools[player]
    if not tool or tool.Parent ~= character or not tool:IsA("Tool") then
        return nil, nil, nil
    end

    if tool:GetAttribute("LumiaInstanceId") ~= record.InstanceId
        or tool:GetAttribute("LumiaCombatTool") ~= true then
        return nil, nil, nil
    end

    return tool, record, definition
end

local function prepareVisual(tool, record, definition)
    tool:SetAttribute("LumiaCombatTool", true)
    tool:SetAttribute("LumiaInstanceId", record.InstanceId)
    tool:SetAttribute("LumiaItemId", record.ItemId)
    tool:SetAttribute("LumiaCooldown", definition.Cooldown)
    tool.CanBeDropped = false
    tool.RequiresHandle = true
    tool.TextureId = "" -- Keep Roblox from showing the default hotbar icon when possible.

    -- Sword geometry must not shove the player around or block the world.
    for _, piece in ipairs(tool:GetDescendants()) do
        if piece:IsA("BasePart") then
            piece.CanCollide = false
            piece.CanTouch = false
            piece.Massless = true
        end
    end

    -- Cosmetic motion streak on the actual blade; NOT a hitbox.
    local blade = tool:FindFirstChild("Steel Blade", true)
    if blade and blade:IsA("BasePart") and not blade:FindFirstChild("LumiaSwingTrail") then
        local dimensions = blade.Size
        local axis = "Y"
        if dimensions.X > dimensions.Y and dimensions.X > dimensions.Z then
            axis = "X"
        elseif dimensions.Z > dimensions.Y then
            axis = "Z"
        end

        local offset = math.max(0.05, math.min(3, dimensions[axis] * 0.45))

        local front = Instance.new("Attachment")
        front.Name = "LumiaBladeTip"
        front.Position = Vector3.new(
            axis == "X" and offset or 0,
            axis == "Y" and offset or 0,
            axis == "Z" and offset or 0
        )
        front.Parent = blade

        local back = Instance.new("Attachment")
        back.Name = "LumiaBladeBase"
        back.Position = -front.Position
        back.Parent = blade

        local trail = Instance.new("Trail")
        trail.Name = "LumiaSwingTrail"
        trail.Attachment0 = front
        trail.Attachment1 = back
        trail.Enabled = false
        trail.Lifetime = 0.13
        trail.MinLength = 0.05
        trail.LightEmission = 0.65
        trail.Color = ColorSequence.new(
            Color3.fromRGB(145, 204, 255),
            Color3.fromRGB(255, 223, 140)
        )
        trail.Transparency = NumberSequence.new(0.15, 1)
        trail.Parent = blade
    end
end

local function removeTool(player)
    local tool = activeTools[player]
    activeTools[player] = nil
    if tool then
        tool:Destroy()
    end
end

local function syncWeapon(player, record, definition)
    local character = player.Character
    if not record then
        removeTool(player)
        return true
    end

    local humanoid = humanoidAndRoot(character)
    local backpack = player:FindFirstChildOfClass("Backpack")
    if not humanoid or not backpack then
        return false
    end

    local existing = activeTools[player]
    if existing
        and existing:GetAttribute("LumiaInstanceId") == record.InstanceId
        and (existing.Parent == character or existing.Parent == backpack) then
        if existing.Parent == backpack then
            humanoid:EquipTool(existing)
        end
        return true
    end

    removeTool(player)

    local tool = ItemFactory.Create(record.ItemId)
    if not tool then
        warn("[Lumia - Sword Combat Service] Sword model missing. Equipment data was NOT modified.")
        return true
    end

    local handle = tool:FindFirstChild("Handle")
    if not handle or not handle:IsA("BasePart") then
        warn("[Lumia - Sword Combat Service] Sword Tool has no BasePart named Handle")
        tool:Destroy()
        return true
    end

    prepareVisual(tool, record, definition)
    activeTools[player] = tool
    tool.Parent = backpack
    humanoid:EquipTool(tool)
    print("[Lumia - Sword Combat Service] Sword equipped in hand: " .. player.Name)
    return true
end

function SwordCombatService:Configure(playerDataService)
    assert(not started, "SwordCombatService already started")
    assert(
        type(playerDataService) == "table"
            and type(playerDataService.GetProfile) == "function",
        "SwordCombatService requires PlayerDataService"
    )
    dataService = playerDataService
end

function SwordCombatService:Init()
    assert(dataService, "SwordCombatService not configured")

    local lumia = ReplicatedStorage:WaitForChild("Lumia")
    local network = lumia:FindFirstChild("CombatNetwork")
    if not network then
        network = Instance.new("Folder")
        network.Name = "CombatNetwork"
        network.Parent = lumia
    end

    local function event(name)
        local remote = network:FindFirstChild(name)
        if not remote then
            remote = Instance.new("RemoteEvent")
            remote.Name = name
            remote.Parent = network
        end
        assert(remote:IsA("RemoteEvent"), "Wrong combat remote: " .. name)
        return remote
    end

    attackRemote = event("RequestSwordAttack")
    swingRemote = event("SwordSwing")
    hitRemote = event("SwordHit")

    print("[Lumia - Sword Combat Service] SwordCombatService initialized")
end

-- The profile loads asynchronously; a bounded wait equips saved weapons on join.
function SwordCombatService:Refresh(player, waitForLoad)
    if not started
        or typeof(player) ~= "Instance"
        or not player:IsA("Player")
        or player.Parent ~= Players then
        return
    end

    local token = (refreshTokens[player] or 0) + 1
    refreshTokens[player] = token

    task.spawn(function()
        local tries = waitForLoad and 80 or 1
        for attempt = 1, tries do
            if player.Parent ~= Players or refreshTokens[player] ~= token then
                return
            end

            local ready, record, definition = getEquipment(player)
            if ready and syncWeapon(player, record, definition) then
                return
            end

            if attempt < tries then
                task.wait(0.25)
            end
        end
    end)
end

local function getForwardFlat(root)
    local forward = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
    if forward.Magnitude < 0.1 then
        return Vector3.new(0, 0, -1)
    end
    return forward.Unit
end

-- Do not fire a single low ray through the edge of a stepping stone.
-- Test body-height lines between the attacker and monster; any unobstructed
-- line means the weapon can reach the enemy without passing through a wall.
-- Tall house walls continue to obstruct every line.
local function hasLineOfSight(character, tool, model, attackerRoot, targetRoot)
    local rayParams = RaycastParams.new()
    rayParams.FilterType = Enum.RaycastFilterType.Exclude
    rayParams.IgnoreWater = true

    local excluded = { character }
    if tool then
        table.insert(excluded, tool)
    end
    rayParams.FilterDescendantsInstances = excluded

    local heightPairs = {
        { 1.25, 0.60 }, -- original body ray
        { 2.10, 1.45 }, -- chest-to-upper-body; clears most small steps
        { 2.65, 1.90 }, -- upper-body fallback for downhill attacks
    }

    for _, pair in ipairs(heightPairs) do
        local origin = attackerRoot.Position + Vector3.new(0, pair[1], 0)
        local target = targetRoot.Position + Vector3.new(0, pair[2], 0)
        local hit = Workspace:Raycast(origin, target - origin, rayParams)
        if not hit or hit.Instance:IsDescendantOf(model) then
            return true
        end
    end
    return false
end

local function findMonsterModel(instance)
    local current = instance
    while current and current ~= Workspace do
        if current:IsA("Model") and type(current:GetAttribute("MonsterId")) == "string" then
            return current
        end
        current = current.Parent
    end
    return nil
end

local function getAttackHitbox(root, range)
    local forward = getForwardFlat(root)
    local width = math.clamp(range * 1.05, HITBOX_MIN_WIDTH, HITBOX_MAX_WIDTH)
    local depth = math.clamp(range + HITBOX_REACH_PADDING, 4.5, 10)

    -- Box begins just behind the player's root and projects forward.
    -- This prevents an NPC partially overlapping the avatar from vanishing
    -- from the hitbox, while still preventing full rear attacks.
    -- Center closer to the attacker's feet, rather than above the waist.
    -- This gives the box room BELOW raised walkways as well as above them.
    local center = root.Position
        + Vector3.new(0, 0.2, 0)
        + forward * (depth * 0.5 + HITBOX_FRONT_PADDING)

    return CFrame.lookAt(center, center + forward),
        Vector3.new(width, HITBOX_HEIGHT, depth), forward
end

local function bestTarget(character, tool, root, range)
    local folder = Workspace:FindFirstChild("LumiaMonsters")
    if not folder then
        return nil
    end

    local hitboxCFrame, hitboxSize, forward = getAttackHitbox(root, range)
    local overlap = OverlapParams.new()
    overlap.FilterType = Enum.RaycastFilterType.Include
    overlap.FilterDescendantsInstances = { folder }
    overlap.MaxParts = 128

    local parts = Workspace:GetPartBoundsInBox(hitboxCFrame, hitboxSize, overlap)
    local candidates = {}

    for _, part in ipairs(parts) do
        if part:IsDescendantOf(folder) then
            local model = findMonsterModel(part)
            if model then
                candidates[model] = true
            end
        end
    end

    -- Root-position fallback prevents an elevation offset, or a model with
    -- non-queryable decorative parts, from disappearing from the hitbox.
    -- Still require horizontal reach, limited height difference, and facing.
    -- The original code already scanned this folder to recover close targets.
    local nearestFlat = math.huge
    local nearestHeight = 0
    local nearestFacing = 0
    for _, model in ipairs(folder:GetChildren()) do
        if model:IsA("Model") and type(model:GetAttribute("MonsterId")) == "string" then
            local monsterRoot = model:FindFirstChild("HumanoidRootPart")
            local monsterHumanoid = model:FindFirstChildOfClass("Humanoid")
            if monsterRoot and monsterRoot:IsA("BasePart")
                and monsterHumanoid and monsterHumanoid.Health > 0 then
                local offset = monsterRoot.Position - root.Position
                local flat = Vector3.new(offset.X, 0, offset.Z)
                local flatDistance = flat.Magnitude
                local facing = flatDistance < 0.15 and 1 or forward:Dot(flat.Unit)
                if flatDistance < nearestFlat then
                    nearestFlat = flatDistance
                    nearestHeight = math.abs(offset.Y)
                    nearestFacing = facing
                end
                local close = flatDistance <= CLOSE_RANGE_RECOVERY
                local facingLimit = close and -0.15 or HITBOX_MIN_DOT
                if flatDistance <= range + HITBOX_REACH_PADDING
                    and math.abs(offset.Y) <= MAX_TARGET_VERTICAL_SEPARATION
                    and facing >= facingLimit then
                    candidates[model] = true
                end
            end
        end
    end

    local bestModel, bestHumanoid, bestScore
    local blockedByWall = false
    for model in pairs(candidates) do
        local humanoid = model:FindFirstChildOfClass("Humanoid")
        local targetRoot = model:FindFirstChild("HumanoidRootPart")

        if humanoid and humanoid.Health > 0
            and targetRoot and targetRoot:IsA("BasePart") then
            local delta = targetRoot.Position - root.Position
            local flat = Vector3.new(delta.X, 0, delta.Z)
            local flatDistance = flat.Magnitude
            local verticalDistance = math.abs(delta.Y)
            local close = flatDistance <= CLOSE_RANGE_RECOVERY
                and verticalDistance <= MAX_TARGET_VERTICAL_SEPARATION
            local facing = flatDistance < 0.15 and 1
                or forward:Dot(flat.Unit)
            local allowedFacing = close and -0.15 or HITBOX_MIN_DOT

            -- Sword reach is measured across the ground plane. Raised steps
            -- must not shorten an otherwise valid 7-stud melee attack.
            if flatDistance <= range + HITBOX_REACH_PADDING
                and verticalDistance <= MAX_TARGET_VERTICAL_SEPARATION
                and facing >= allowedFacing then
                if hasLineOfSight(character, tool, model, root, targetRoot) then
                    local score = facing * 100 - flatDistance * 6
                    if not bestScore or score > bestScore then
                        bestModel, bestHumanoid, bestScore = model, humanoid, score
                    end
                else
                    blockedByWall = true
                end
            end
        end
    end

    local debugInfo = {
        NearestFlat = nearestFlat,
        NearestHeight = nearestHeight,
        NearestFacing = nearestFacing,
        BlockedByWall = blockedByWall,
    }
    return bestModel, bestHumanoid, debugInfo
end

function SwordCombatService:_onAttack(player)
    if player.Parent ~= Players then
        return
    end

    local character = player.Character
    local humanoid, root = humanoidAndRoot(character)
    if not humanoid then
        return
    end

    local tool, record, definition = isValidWeapon(player, character)
    if not tool then
        SwordCombatService:_onFistAttack(player, humanoid, root)
        return
    end

    -- Clamp item values to safe bounds. Clients cannot set them.
    local cooldown = tonumber(definition.Cooldown)
    local hitDelay = tonumber(definition.HitDelay)
    local damage = tonumber(definition.Damage)
    local range = tonumber(definition.Range)

    if not cooldown or cooldown ~= cooldown
        or not hitDelay or hitDelay ~= hitDelay
        or not damage or damage ~= damage
        or not range or range ~= range then
        return
    end

    cooldown = math.clamp(cooldown, 0.25, 3)
    hitDelay = math.clamp(hitDelay, 0.06, math.min(cooldown, 0.65))
    damage = math.clamp(damage, 0, 100)
    range = math.clamp(range, 2.5, 10)
    local stats = CombatStats.Get(player)
    damage = math.clamp(math.floor(damage + (stats and stats.Attack or 0)), 1, 160)
    -- Global player-damage dial: one knob for "how fast do weapons kill".
    -- Applied after gear stats so it scales the whole loadout, not one tier.
    local power = BalanceService:GetGlobal("PlayerDamage")
    if power ~= 1 then
        damage = math.max(1, math.floor(damage * power + 0.5))
    end

    local now = os.clock()
    if lastAttacks[player] and now - lastAttacks[player] < cooldown then
        return
    end
    lastAttacks[player] = now

    -- All clients animate accepted attacks, including spectators/nearby players.
    swingRemote:FireAllClients(player)

    task.delay(hitDelay, function()
        if player.Parent ~= Players
            or player.Character ~= character
            or humanoid.Health <= 0 then
            return
        end

        local liveTool, liveRecord = isValidWeapon(player, character)
        if liveTool ~= tool or not liveRecord or liveRecord.InstanceId ~= record.InstanceId then
            return
        end

        local _, liveRoot = humanoidAndRoot(character)
        if not liveRoot then
            return
        end

        local model, targetHumanoid, debugInfo = bestTarget(character, tool, liveRoot, range)
        if not model or not targetHumanoid then
            -- Optional Studio diagnostic, off by default. In SERVER Command Bar:
            -- workspace:SetAttribute("LumiaMeleeDebug", true)
            if Workspace:GetAttribute("LumiaMeleeDebug") == true then
                if debugInfo and debugInfo.NearestFlat < math.huge then
                    print(string.format(
                        "[Lumia][Melee] MISS %s: nearest wolf horizontal=%.1f studs, height difference=%.1f, facing=%.2f, wall=%s, allowed reach=%.1f",
                        player.Name, debugInfo.NearestFlat,
                        debugInfo.NearestHeight, debugInfo.NearestFacing,
                        tostring(debugInfo.BlockedByWall), range + HITBOX_REACH_PADDING
                    ))
                else
                    print("[Lumia - Sword Combat Service] [Melee] MISS " .. player.Name .. ": no living monsters found")
                end
            end
            return
        end

        -- Server-validated attribution for loot; never trust a client claim.
        model:SetAttribute("LumiaLastHitUserId", player.UserId)
        model:SetAttribute("LumiaLastHitAt", os.clock())
        if model:GetAttribute("MonsterId")=="ThornboundGuardian"
            and model:GetAttribute("LumiaBossEncounter")==true then
            local hitKey="LumiaBossHit_"..player.UserId
            model:SetAttribute(hitKey,(model:GetAttribute(hitKey) or 0)+1)
        end
        -- Defense is a spawn-time monster attribute written only by MonsterService.
        -- Factor 2 gives half incoming weapon damage; 1 leaves existing balance.
        local defense = tonumber(model:GetAttribute("LumiaDefenseFactor")) or 1
        defense = math.clamp(defense, 0.25, 8)
        local finalDamage = math.max(1, math.round(damage / defense))
        targetHumanoid:TakeDamage(finalDamage)
        hitRemote:FireClient(player, model, finalDamage)

        print(
            "[Lumia - Sword Combat Service] "
                .. player.Name
                .. " hit "
                .. model.Name
                .. " for "
                .. tostring(finalDamage)
                .. " damage"
        )
    end)
end

function SwordCombatService:_onFistAttack(player, humanoid, root)
    if not humanoid or not root then return end
    local cooldown = 0.6
    local hitDelay = 0.15
    local range = 5
    local stats = CombatStats.Get(player)
    local damage = math.clamp(5 + (stats and stats.Attack or 0), 1, 160)
    local power = BalanceService:GetGlobal("PlayerDamage")
    if power ~= 1 then
        damage = math.max(1, math.floor(damage * power + 0.5))
    end
    local now = os.clock()
    if lastAttacks[player] and now - lastAttacks[player] < cooldown then return end
    lastAttacks[player] = now
    task.delay(hitDelay, function()
        if player.Parent ~= Players then return end
        if not player.Character then return end
        if humanoid.Health <= 0 then return end
        local _, liveRoot = humanoidAndRoot(player.Character)
        if not liveRoot then return end
        local model, targetHumanoid = bestTarget(player.Character, nil, liveRoot, range)
        if not model or not targetHumanoid then return end
        model:SetAttribute("LumiaLastHitUserId", player.UserId)
        model:SetAttribute("LumiaLastHitAt", os.clock())
        if model:GetAttribute("MonsterId") == "ThornboundGuardian" and model:GetAttribute("LumiaBossEncounter") == true then
            local hitKey = "LumiaBossHit_" .. player.UserId
            model:SetAttribute(hitKey, (model:GetAttribute(hitKey) or 0) + 1)
        end
        local defense = tonumber(model:GetAttribute("LumiaDefenseFactor")) or 1
        defense = math.clamp(defense, 0.25, 8)
        local finalDamage = math.max(1, math.round(damage / defense))
        targetHumanoid:TakeDamage(finalDamage)
        hitRemote:FireClient(player, model, finalDamage)
        print("[Lumia - Sword Combat Service] " .. player.Name .. " punched " .. model.Name .. " for " .. tostring(finalDamage) .. " damage")
    end)
end

local function hookPlayer(self, player)
    if playerConnections[player] then
        return
    end

    local connections = {}
    playerConnections[player] = connections

    table.insert(connections, player.CharacterAdded:Connect(function()
        self:Refresh(player, true)
    end))

    table.insert(connections, player.CharacterRemoving:Connect(function()
        refreshTokens[player] = (refreshTokens[player] or 0) + 1
        removeTool(player)
    end))

    self:Refresh(player, true)
end

function SwordCombatService:Start()
    if started then
        return
    end

    started = true

    attackRemote.OnServerEvent:Connect(function(player)
        self:_onAttack(player)
    end)

    Players.PlayerAdded:Connect(function(player)
        hookPlayer(self, player)
    end)

    Players.PlayerRemoving:Connect(function(player)
        refreshTokens[player] = nil
        lastAttacks[player] = nil
        removeTool(player)

        local connections = playerConnections[player]
        if connections then
            for _, connection in ipairs(connections) do
                connection:Disconnect()
            end
            playerConnections[player] = nil
        end
    end)

    for _, player in ipairs(Players:GetPlayers()) do
        hookPlayer(self, player)
    end

    print("[Lumia - Sword Combat Service] SwordCombatService started")
end

return SwordCombatService