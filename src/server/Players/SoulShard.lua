-- REALMS OF LUMIA - SOUL SHARD SERVICE
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local HttpService = game:GetService("HttpService")

local Service = {}
local dataService = nil
local started = false
local shardByUser = {}
local shardFolder = nil
local onDropped = nil
local onRecovered = nil

local SHARD_ATTRIBUTE = "LumiaSoulShard"
local OWNER_ATTRIBUTE = "LumiaShardOwnerUserId"
local GOLD_ATTRIBUTE = "LumiaShardGold"
local XP_ATTRIBUTE = "LumiaShardXP"
local ITEMS_ATTRIBUTE = "LumiaShardItemsJSON"
local EQUIP_ATTRIBUTE = "LumiaShardEquipmentJSON"

local function ensureFolder()
    if shardFolder and shardFolder.Parent then return shardFolder end
    shardFolder = Workspace:FindFirstChild("LumiaSoulShards")
    if not shardFolder then
        shardFolder = Instance.new("Folder")
        shardFolder.Name = "LumiaSoulShards"
        shardFolder.Parent = Workspace
    end
    return shardFolder
end

local function encodeTable(t)
    if type(t) ~= "table" then return "[]" end
    local ok, encoded = pcall(function() return HttpService:JSONEncode(t) end)
    return ok and encoded or "[]"
end

local function decodeTable(s)
    if type(s) ~= "string" or #s < 2 then return {} end
    local ok, decoded = pcall(function() return HttpService:JSONDecode(s) end)
    if ok and type(decoded) == "table" then return decoded end
    return {}
end

local function buildShardModel(name, gold, xp)
    local model = Instance.new("Model")
    model.Name = name

    local base = Instance.new("Part")
    base.Name = "Pedestal"
    base.Shape = Enum.PartType.Cylinder
    base.Size = Vector3.new(0.4, 2.4, 2.4)
    base.Orientation = Vector3.new(0, 0, 90)
    base.Material = Enum.Material.Slate
    base.Color = Color3.fromRGB(35, 45, 65)
    base.Anchored = true
    base.CanCollide = false
    base.CanTouch = false
    base.Parent = model

    local crystal = Instance.new("Part")
    crystal.Name = "Crystal"
    crystal.Shape = Enum.PartType.Ball
    crystal.Size = Vector3.new(1.6, 2.2, 1.6)
    crystal.Material = Enum.Material.Neon
    crystal.Color = Color3.fromRGB(90, 170, 255)
    crystal.Transparency = 0.25
    crystal.Anchored = true
    crystal.CanCollide = false
    crystal.CanTouch = false
    crystal.CastShadow = false
    crystal.Parent = model

    local core = Instance.new("Part")
    core.Name = "Core"
    core.Shape = Enum.PartType.Ball
    core.Size = Vector3.new(0.7, 0.7, 0.7)
    core.Material = Enum.Material.Neon
    core.Color = Color3.fromRGB(220, 240, 255)
    core.Anchored = true
    core.CanCollide = false
    core.CanTouch = false
    core.CastShadow = false
    core.Parent = model

    local ring = Instance.new("Part")
    ring.Name = "Ring"
    ring.Shape = Enum.PartType.Cylinder
    ring.Size = Vector3.new(0.1, 2.6, 2.6)
    ring.Orientation = Vector3.new(0, 0, 90)
    ring.Material = Enum.Material.Neon
    ring.Color = Color3.fromRGB(120, 200, 255)
    ring.Transparency = 0.35
    ring.Anchored = true
    ring.CanCollide = false
    ring.CanTouch = false
    ring.CastShadow = false
    ring.Parent = model

    local light = Instance.new("PointLight")
    light.Color = Color3.fromRGB(120, 200, 255)
    light.Range = 14
    light.Brightness = 3
    light.Parent = crystal

    local billboard = Instance.new("BillboardGui")
    billboard.Name = "Label"
    billboard.Size = UDim2.new(0, 220, 0, 70)
    billboard.StudsOffset = Vector3.new(0, 2.4, 0)
    billboard.AlwaysOnTop = true
    billboard.Parent = crystal

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, 0, 0.55, 0)
    title.BackgroundTransparency = 1
    title.Text = "SOUL SHARD"
    title.TextColor3 = Color3.fromRGB(180, 220, 255)
    title.TextStrokeTransparency = 0.6
    title.TextScaled = true
    title.Font = Enum.Font.GothamBold
    title.Parent = billboard

    local sub = Instance.new("TextLabel")
    sub.Size = UDim2.new(1, 0, 0.45, 0)
    sub.Position = UDim2.new(0, 0, 0.55, 0)
    sub.BackgroundTransparency = 1
    sub.Text = tostring(gold) .. "g  |  " .. tostring(xp) .. "xp"
    sub.TextColor3 = Color3.fromRGB(255, 230, 140)
    sub.TextStrokeTransparency = 0.6
    sub.TextScaled = true
    sub.Font = Enum.Font.Gotham
    sub.Parent = billboard

    local hitbox = Instance.new("Part")
    hitbox.Name = "Hitbox"
    hitbox.Shape = Enum.PartType.Ball
    hitbox.Size = Vector3.new(4, 4, 4)
    hitbox.Transparency = 1
    hitbox.Anchored = true
    hitbox.CanCollide = false
    hitbox.CanTouch = true
    hitbox.Parent = model

    return model, crystal, core, ring, hitbox
end

local handleTouch

local function spawnShard(player, position, gold, xp, itemsJson, equipJson)
    local folder = ensureFolder()
    local model, crystal, core, ring, hitbox = buildShardModel(player.Name, gold, xp)

    model:SetAttribute(SHARD_ATTRIBUTE, true)
    model:SetAttribute(OWNER_ATTRIBUTE, player.UserId)
    model:SetAttribute(GOLD_ATTRIBUTE, gold)
    model:SetAttribute(XP_ATTRIBUTE, xp)
    model:SetAttribute(ITEMS_ATTRIBUTE, itemsJson)
    model:SetAttribute(EQUIP_ATTRIBUTE, equipJson)

    hitbox:SetAttribute(SHARD_ATTRIBUTE, true)
    hitbox:SetAttribute(OWNER_ATTRIBUTE, player.UserId)
    hitbox:SetAttribute(GOLD_ATTRIBUTE, gold)
    hitbox:SetAttribute(XP_ATTRIBUTE, xp)
    hitbox:SetAttribute(ITEMS_ATTRIBUTE, itemsJson)
    hitbox:SetAttribute(EQUIP_ATTRIBUTE, equipJson)

    model:PivotTo(CFrame.new(position + Vector3.new(0, 1.5, 0)))
    hitbox.Position = position + Vector3.new(0, 1.5, 0)
    model.PrimaryPart = crystal
    model.Parent = folder
    print("[SHARD] model parent=" .. tostring(model.Parent) .. " children=" .. tostring(#folder:GetChildren()))

    shardByUser[player.UserId] = model
    model:SetAttribute("LumiaShardDropTime", tick())
    hitbox:SetAttribute("LumiaShardDropTime", tick())

    hitbox.Touched:Connect(function(hit)
        if handleTouch then
            handleTouch(hitbox, hit)
        end
    end)

    print("[SHARD] shard spawned: " .. tostring(gold) .. "g " .. tostring(xp) .. "xp")

    -- Tell the owner where their shard fell. The client cannot see the drop
    -- otherwise: the loss is silent until someone walks into the crystal.
    if onDropped then
        local itemCount = #decodeTable(itemsJson)
        onDropped:FireClient(player, gold, xp, itemCount, position)
    end

    return model
end

handleTouch = function(part, toucher)
    if not part or not part.Parent then return end
    local dropTime = part:GetAttribute("LumiaShardDropTime") or 0
    if tick() - dropTime < 2 then return end
    if part:GetAttribute(SHARD_ATTRIBUTE) ~= true then return end
    local userId = part:GetAttribute(OWNER_ATTRIBUTE)
    if type(userId) ~= "number" then return end
    local player = Players:GetPlayerByUserId(userId)
    if not player then return end
    local character = player.Character
    if not character or character ~= toucher.Parent then return end
    if not dataService then return end
    local profile = dataService:GetProfileUnchecked(player)
    if not profile or type(profile.Character) ~= "table" then return end
    if type(profile.Inventory) ~= "table" then return end

    local gold = tonumber(part:GetAttribute(GOLD_ATTRIBUTE)) or 0
    local xp = tonumber(part:GetAttribute(XP_ATTRIBUTE)) or 0
    local items = decodeTable(part:GetAttribute(ITEMS_ATTRIBUTE))
    local equip = decodeTable(part:GetAttribute(EQUIP_ATTRIBUTE))

    profile.Character.Gold = (tonumber(profile.Character.Gold) or 0) + gold
    profile.Character.Experience = (tonumber(profile.Character.Experience) or 0) + xp

    if type(profile.Inventory.Items) ~= "table" then profile.Inventory.Items = {} end
    if type(profile.Inventory.Equipment) ~= "table" then profile.Inventory.Equipment = {} end

    for _, record in ipairs(items) do
        if record ~= nil then table.insert(profile.Inventory.Items, record) end
    end
    for slot, instanceId in pairs(equip) do
        profile.Inventory.Equipment[slot] = instanceId
    end

    shardByUser[userId] = nil
    part.Parent:Destroy()

    print("[SHARD] pickup OK gold=" .. tostring(gold) .. " xp=" .. tostring(xp) .. " items=" .. tostring(#items))

    if onRecovered then
        pcall(function() onRecovered:FireClient(player, gold, xp, #items) end)
    end
end

local function destroyShardFor(userId)
    local model = shardByUser[userId]
    shardByUser[userId] = nil
    if model and model.Parent then model:Destroy() end
end

-- Remove an existing shard and return what it was holding so a repeat death
-- can carry the payload forward instead of deleting it.
local function takeExistingShard(userId)
    local model = shardByUser[userId]
    shardByUser[userId] = nil
    if not model then return 0, 0, {}, {} end

    local gold = tonumber(model:GetAttribute(GOLD_ATTRIBUTE)) or 0
    local xp = tonumber(model:GetAttribute(XP_ATTRIBUTE)) or 0
    local items = decodeTable(model:GetAttribute(ITEMS_ATTRIBUTE))
    local equip = decodeTable(model:GetAttribute(EQUIP_ATTRIBUTE))
    if model.Parent then model:Destroy() end
    return gold, xp, items, equip
end

local function handleDeath(player, character)
    if not dataService then return end
    local profile = dataService:GetProfileUnchecked(player)
    if not profile then
        for i = 1, 30 do
            task.wait(0.1)
            profile = dataService:GetProfileUnchecked(player)
            if profile then break end
        end
    end
    if not profile then
        print("[SHARD] profile still nil, skipping penalty")
        return
    end

    local gold = 0
    local xp = 0
    local items = {}
    local equip = {}

    if type(profile.Character) == "table" then
        gold = tonumber(profile.Character.Gold) or 0
        xp = tonumber(profile.Character.Experience) or 0
    end
    if type(profile.Inventory) == "table" then
        items = profile.Inventory.Items or {}
        equip = profile.Inventory.Equipment or {}
    end

    local lostItemCount = 0
    for _, record in ipairs(items) do
        if type(record) == "table" and (tonumber(record.Quantity) or 1) > 0 then
            lostItemCount = lostItemCount + 1
        end
    end
    for _ in pairs(equip) do
        lostItemCount = lostItemCount + 1
    end

    -- A fresh character owns nothing. Spawning an empty shard would leave a
    -- worthless crystal on the ground and an alarming loss message.
    if gold <= 0 and xp <= 0 and lostItemCount == 0 then
        print("[SHARD] " .. player.Name .. " died with nothing to lose, no shard dropped")
        return
    end

    -- Consume the profile only once a shard is certain to hold it.
    if type(profile.Character) == "table" then
        profile.Character.Gold = 0
        profile.Character.Experience = 0
    end
    if type(profile.Inventory) == "table" then
        profile.Inventory.Items = {}
        profile.Inventory.Equipment = {}
    end

    local char = character or player.Character
    if char then
        for _, child in ipairs(char:GetChildren()) do
            if child:IsA("Tool") then child:Destroy() end
        end
    end
    local backpack = player:FindFirstChild("Backpack")
    if backpack then
        for _, child in ipairs(backpack:GetChildren()) do
            if child:IsA("Tool") then child:Destroy() end
        end
    end

    -- Dying a second time before recovering must not erase the first shard's
    -- contents. Fold the old shard's payload into the new one instead.
    local oldGold, oldXp, oldItems, oldEquip = takeExistingShard(player.UserId)
    gold = gold + oldGold
    xp = xp + oldXp
    for _, record in ipairs(oldItems) do
        table.insert(items, record)
    end
    for slot, instanceId in pairs(oldEquip) do
        equip[slot] = instanceId
    end

    local rootPart = char and char:FindFirstChild("HumanoidRootPart")
    if not rootPart then return end

    -- A death mid-fall or over water leaves the root above the world. Snap the
    -- shard to the surface below the body so it is always physically reachable.
    local dropPosition = rootPart.Position
    local rayParams = RaycastParams.new()
    rayParams.FilterType = Enum.RaycastFilterType.Exclude
    rayParams.FilterDescendantsInstances = { char }
    rayParams.IgnoreWater = true
    local ground = Workspace:Raycast(
        dropPosition + Vector3.new(0, 3, 0), Vector3.new(0, -80, 0), rayParams)
    if ground then
        dropPosition = ground.Position
    end

    local itemsJson = encodeTable(items)
    local equipJson = encodeTable(equip)
    spawnShard(player, dropPosition, gold, xp, itemsJson, equipJson)
end

local function hookPlayer(player)
    player.CharacterAdded:Connect(function(character)
        local humanoid = character:WaitForChild("Humanoid", 10)
        if not humanoid then return end
        humanoid.Died:Connect(function()
            task.defer(function() handleDeath(player, character) end)
        end)
    end)
    if player.Character then
        local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
        if humanoid then
            humanoid.Died:Connect(function()
                task.defer(function() handleDeath(player, player.Character) end)
            end)
        end
    end
end

function Service:Configure(playerDataService)
    assert(type(playerDataService) == "table" and type(playerDataService.GetProfileUnchecked) == "function",
        "SoulShard requires PlayerDataService")
    dataService = playerDataService
end

function Service:Init()
    assert(dataService, "SoulShard not configured")
    local lumia = ReplicatedStorage:WaitForChild("Lumia")
    local net = lumia:FindFirstChild("SoulShardNetwork")
    if not net then
        net = Instance.new("Folder")
        net.Name = "SoulShardNetwork"
        net.Parent = lumia
    end
    local function remote(name)
        local r = net:FindFirstChild(name)
        if not r then
            r = Instance.new("RemoteEvent")
            r.Name = name
            r.Parent = net
        end
        return r
    end
    onDropped = remote("OnShardDropped")
    onRecovered = remote("OnShardRecovered")
    print("[Lumia - Soul Shard] SoulShardService initialized")
end

function Service:Start()
    if started then return end
    started = true
    ensureFolder()
    for _, player in ipairs(Players:GetPlayers()) do hookPlayer(player) end
    Players.PlayerAdded:Connect(hookPlayer)
    Players.PlayerRemoving:Connect(function(player)
        destroyShardFor(player.UserId)
    end)
    print("[Lumia - Soul Shard] SoulShardService started")
end

return Service