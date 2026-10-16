-- REALMS OF LUMIA - LOOT SERVICE v1
-- Authoritative loot generation, ownership, inspection and pickup.
-- No dependency on MonsterService/SpawnManager: listens to lifecycle events.
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Services = script.Parent.Parent
local InventoryService = require(Services:WaitForChild("Inventory"):WaitForChild("InventoryService"))
local BagSnapshot = require(Services:WaitForChild("Inventory"):WaitForChild("BagSnapshot"))
local LifecycleEvents = require(Services:WaitForChild("Monsters"):WaitForChild("MonsterLifecycleEvents"))
local Shared = ReplicatedStorage:WaitForChild("Lumia"):WaitForChild("Shared")
local ItemDefinitions = require(Shared:WaitForChild("Items"):WaitForChild("ItemDefinitions"))
local Config = require(Shared:WaitForChild("Loot"):WaitForChild("LootConfig"))
local MobTuning = require(Services:WaitForChild("Admin"):WaitForChild("MobTuningService"))
local QuestService = require(Services:WaitForChild("Quests"):WaitForChild("QuestService"))

local LootService = {}
local started = false
local active = {} -- generated corpse token -> private table
local tokenByModel = setmetatable({}, {__mode = "k"}) -- private server lookup
local rng = Random.new()
local openRequested = Instance.new("BindableEvent")
LootService.OpenRequested = openRequested.Event -- (player, corpseToken)

local function roll(drops)
    local total = 0
    for _, entry in ipairs(drops) do
        if type(entry.ItemId) == "string" and ItemDefinitions.Get(entry.ItemId)
            and type(entry.Weight) == "number" and entry.Weight > 0 then
            total += entry.Weight
        end
    end
    if total <= 0 then return nil end
    local choice = rng:NextNumber(0, total)
    local sum = 0
    for _, entry in ipairs(drops) do
        if type(entry.ItemId) == "string" and ItemDefinitions.Get(entry.ItemId)
            and type(entry.Weight) == "number" and entry.Weight > 0 then
            sum += entry.Weight
            if choice <= sum then return entry.ItemId end
        end
    end
    return nil
end

local function inRange(player, model)
    local character = player.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local corpseRoot = model and model:FindFirstChild("HumanoidRootPart")
    return root and humanoid and humanoid.Health > 0 and corpseRoot
        and (root.Position - corpseRoot.Position).Magnitude <= Config.OpenDistance
end

local function visibleItems(entry)
    local result = {}
    for index, lootItem in ipairs(entry.Items) do
        local definition = ItemDefinitions.Get(lootItem.ItemId)
        if definition then
            result[#result + 1] = {
                Slot = index, ItemId = lootItem.ItemId,
                DisplayName = definition.DisplayName,
                Type = definition.Type, Rarity = definition.Rarity,
                Quantity = lootItem.Quantity,
            }
        end
    end
    return result
end

local function allowed(player, token)
    if typeof(player) ~= "Instance" or not player:IsA("Player")
        or player.Parent ~= Players or type(token) ~= "string" or #token > 80 then
        return nil, "Invalid request"
    end
    local entry = active[token]
    if not entry or not entry.Model or not entry.Model.Parent then
        return nil, "Loot expired"
    end
    if entry.OwnerUserId ~= player.UserId then return nil, "Not your loot" end
    if not inRange(player, entry.Model) then return nil, "Move closer to the corpse" end
    return entry
end

local function onDied(model, monsterId)
    if not model or not model:IsA("Model") or not model.Parent then return end
    local profile = MobTuning:GetLootProfile(monsterId)
    if not profile then return end
    local ownerUserId = model:GetAttribute("LumiaLastHitUserId")
    local hitAt = model:GetAttribute("LumiaLastHitAt")
    if type(ownerUserId) ~= "number" or type(hitAt) ~= "number"
        or os.clock() - hitAt > Config.HitCreditLifetimeSeconds then return end
    local owner = Players:GetPlayerByUserId(ownerUserId)
    if not owner then return end
    local root = model:FindFirstChild("HumanoidRootPart")
    if not root then return end

    local items = {}
    for _ = 1, math.clamp(math.floor(profile.DropCount or 1), 0, 5) do
        local itemId = roll(profile.Drops or {})
        if itemId then items[#items + 1] = { ItemId = itemId, Quantity = 1 } end
    end
    -- Extra quest loot is generated only for an active collecting objective.
    -- Normal random creature drops remain unchanged. Server rolls probability.
    local questId,chance=QuestService:GetMonsterQuestDrop(owner,monsterId)
    if questId and rng:NextNumber()<chance then
        items[#items+1]={ItemId=questId,Quantity=1}
    end
    -- Personal collect credit for living nearby teammates. The current normal
    -- loot UI is single-owner, so teammates receive their quest fragment directly.
    -- Future personal-loot windows can replace only this block.
    for _,teammate in ipairs(Players:GetPlayers()) do
        if teammate~=owner then
            local ch=teammate.Character
            local hrp=ch and ch:FindFirstChild("HumanoidRootPart")
            local hum=ch and ch:FindFirstChildOfClass("Humanoid")
            if hrp and hum and hum.Health>0 and
                (hrp.Position-root.Position).Magnitude<=36 then
                local dropId,dropChance=QuestService:GetMonsterQuestDrop(teammate,monsterId)
                if dropId and rng:NextNumber()<dropChance then
                    local given=InventoryService:AddItem(teammate,dropId,1)
                    if given then
                        QuestService:Notify(teammate)
                        local qnet=ReplicatedStorage.Lumia:FindFirstChild("QuestNetwork")
                        local popup=qnet and qnet:FindFirstChild("QuestMessage")
                        if popup then popup:FireClient(teammate,"Recovered a quest fragment",true) end
                    end
                end
            end
        end
    end
    if #items == 0 then return end
    local token = HttpService:GenerateGUID(false)
    local prompt = Instance.new("ProximityPrompt")
    prompt.Name = "LumiaLootPrompt"
    prompt.ActionText = "Loot"
    prompt.ObjectText = model.Name
    prompt.KeyboardKeyCode = Enum.KeyCode.E
    prompt.MaxActivationDistance = Config.OpenDistance
    prompt.RequiresLineOfSight = false
    prompt.Style = Enum.ProximityPromptStyle.Custom -- hide default E popup, retain E interaction
    prompt.HoldDuration = 0
    prompt.Parent = root
    local entry = { Model = model, OwnerUserId = ownerUserId, Items = items, Prompt = prompt }
    active[token] = entry
    tokenByModel[model] = token
    -- Client-visible hint only. NOT used as permission by the server.
    model:SetAttribute("LumiaLootableCorpse", true)
    model:SetAttribute("LumiaLootOwnerUserId", ownerUserId)
    prompt.Triggered:Connect(function(player)
        if player.UserId == ownerUserId and inRange(player, model) and #entry.Items > 0 then
            openRequested:Fire(player, token)
        end
    end)
    model.Destroying:Connect(function()
        active[token] = nil
        tokenByModel[model] = nil
    end)
    print("[Lumia - Loot Service] Generated " .. #items .. " gray item(s) for " .. owner.Name)
end

function LootService:Start()
    if started then return end
    started = true
    LifecycleEvents.Died.Event:Connect(onDied)
    print("[Lumia - Loot Service] LootService listening for defeated monsters")
end

-- Called by LootBridge after a click. Do not trust client-supplied models:
-- only the server's private corpse map + existing ownership/range checks count.
function LootService:GetTokenForModel(player, model)
    if typeof(model) ~= "Instance" or not model:IsA("Model") then return nil end
    local token = tokenByModel[model]
    if not token then return nil end
    local entry = allowed(player, token)
    if not entry or #entry.Items == 0 then return nil end
    return token
end

function LootService:Inspect(player, token)
    local entry, err = allowed(player, token)
    if not entry then return {Ok = false, Error = err} end
    return {Ok = true, Items = visibleItems(entry), MonsterName = entry.Model.Name}
end

function LootService:Take(player, token, slot)
    local entry, err = allowed(player, token)
    if not entry then return {Ok = false, Error = err} end
    if type(slot) ~= "number" or slot % 1 ~= 0 or slot < 1 or slot > 5 then
        return {Ok = false, Error = "Invalid loot slot"}
    end
    local lootItem = entry.Items[slot]
    if not lootItem then return {Ok = false, Error = "Item already taken"} end
    -- No yields between grant and removal: one authoritative server operation.
    local granted, grantError = InventoryService:AddItem(player, lootItem.ItemId, lootItem.Quantity)
    if not granted then return {Ok = false, Error = tostring(grantError or "Bag full")} end
    table.remove(entry.Items, slot)
    if #entry.Items == 0 then
        entry.Model:SetAttribute("LumiaLootableCorpse", false)
        if entry.Prompt.Parent then entry.Prompt:Destroy() end
        LifecycleEvents.LootCompleted:Fire(entry.Model)
    end
    QuestService:Notify(player) -- Update live collect quest tracker after bag pickup.
    print("[Lumia - Loot Service] " .. player.Name .. " collected " .. lootItem.ItemId)
    return {Ok = true, Items = visibleItems(entry), Bag = BagSnapshot.Build(player)}
end

return LootService
