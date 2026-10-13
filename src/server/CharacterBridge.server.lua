-- Realms of Eternia - Step 13.1
-- Read-only character snapshot for the Character Sheet.
-- Independent Roblox server Script: does NOT need ServiceRegistry registration.
-- All values come from the active, validated server-side player profile.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local services = script.Parent
local PlayerDataService = require(services:WaitForChild("PlayerDataService"))
local shared = ReplicatedStorage:WaitForChild("Eternia"):WaitForChild("Shared")
local ItemDefinitions = require(shared:WaitForChild("ItemDefinitions"))
local ProgressionConfig = require(shared:WaitForChild("ProgressionConfig"))

local eternia = ReplicatedStorage:WaitForChild("Eternia")
local network = eternia:FindFirstChild("CharacterNetwork")
if not network then
    network = Instance.new("Folder")
    network.Name = "CharacterNetwork"
    network.Parent = eternia
end

local request = network:FindFirstChild("GetCharacter")
if not request then
    request = Instance.new("RemoteFunction")
    request.Name = "GetCharacter"
    request.Parent = network
end

local lastRequest = {}
local SLOT_KEYS = {
    "Head", "Chest", "Hands", "Legs", "Feet", "MainHand", "OffHand", "Ring"
}

-- The persisted Equipment table is expected to map slot -> unique InstanceId.
-- Step 13.1 only READS this representation. Step 13.2 will define writes.
local function findItem(items, instanceId)
    if type(instanceId) ~= "string" or type(items) ~= "table" then
        return nil
    end
    for _, record in ipairs(items) do
        if type(record) == "table" and record.InstanceId == instanceId then
            return record
        end
    end
    return nil
end

local function buildEquipment(inventory)
    local result = {}
    if type(inventory) ~= "table"
        or type(inventory.Equipment) ~= "table"
        or type(inventory.Items) ~= "table" then
        return result
    end

    for _, slotKey in ipairs(SLOT_KEYS) do
        local record = findItem(inventory.Items, inventory.Equipment[slotKey])
        if record then
            local definition = ItemDefinitions.Get(record.ItemId)
            if definition then
                -- Display metadata only. Never expose an InstanceId here.
                result[slotKey] = {
                    ItemId = record.ItemId,
                    DisplayName = definition.DisplayName,
                    Type = definition.Type,
                    SubType = definition.SubType,
                    Rarity = definition.Rarity,
                    Damage = definition.Damage,
                    RequiredLevel = definition.RequiredLevel,
                    IconId = definition.IconId,
                }
            end
        end
    end
    return result
end

request.OnServerInvoke = function(player)
    if typeof(player) ~= "Instance"
        or not player:IsA("Player")
        or player.Parent ~= Players then
        return { Ready = false }
    end

    local now = os.clock()
    if lastRequest[player] and now - lastRequest[player] < 0.25 then
        return { Ready = false, Retry = true }
    end
    lastRequest[player] = now

    local profile = PlayerDataService:GetProfile(player)
    if not profile then
        return { Ready = false }
    end

    local character = profile.Character
    local stats = profile.Stats
    if type(character) ~= "table" or type(stats) ~= "table" then
        return { Ready = false }
    end

    local level = character.Level
    return {
        Ready = true,
        Name = character.Name,
        Class = character.Class, -- nil today: class selection is not implemented.
        Level = level,
        Experience = character.Experience,
        RequiredXP = ProgressionConfig.GetRequiredXP(level),
        MaxLevel = ProgressionConfig.MAX_LEVEL,
        Gold = character.Gold,
        Stats = {
            Strength = stats.Strength,
            Agility = stats.Agility,
            Intelligence = stats.Intelligence,
            Vitality = stats.Vitality,
        },
        Equipment = buildEquipment(profile.Inventory),
    }
end

Players.PlayerRemoving:Connect(function(player)
    lastRequest[player] = nil
end)

print("[Eternia] CharacterBridge ready - read-only GetCharacter")
