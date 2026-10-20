-- Lumia V17: one authoritative formula for equipment/level statistics.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Items = require(ReplicatedStorage:WaitForChild("Lumia"):WaitForChild("Shared")
    :WaitForChild("Items"):WaitForChild("ItemDefinitions"))
local Data = require(script.Parent.Parent:WaitForChild("Players"):WaitForChild("PlayerDataService"))
local BalanceService = require(script.Parent.Parent:WaitForChild("Admin"):WaitForChild("BalanceService"))
local CombatStats = {}

-- Cached armor dial. IncomingDamage runs on every monster hit, so it must not
-- reach into the balance service (and its DataStore load) per hit. Refreshed on
-- startup and whenever the owner changes a dial.
local armorScale = 1
local function refreshArmorScale()
    armorScale = BalanceService:GetGlobal("PlayerArmor")
end
BalanceService.Changed.Event:Connect(refreshArmorScale)
task.spawn(refreshArmorScale)

function CombatStats.Get(player)
    local profile = Data:GetProfile(player)
    if not profile then return nil end
    local character = profile.Character or {}
    local stats = profile.Stats or {}
    local inventory = profile.Inventory or {}
    local records = {}
    for _, record in ipairs(inventory.Items or {}) do
        if type(record) == "table" and type(record.InstanceId) == "string" then
            records[record.InstanceId] = record
        end
    end
    local level = math.clamp(math.floor(character.Level or 1), 1, 60)
    local attack = math.floor((stats.Strength or 5) * 0.4) + math.floor((level - 1) * 1.8)
    local defense, bonusHP, pieces, tierTotal = 0, 0, 0, 0
    for _, instanceId in pairs(inventory.Equipment or {}) do
        local record = records[instanceId]
        local definition = record and Items.Get(record.ItemId)
        if definition then
            attack += tonumber(definition.Attack) or 0
            defense += tonumber(definition.Defense) or 0
            bonusHP += tonumber(definition.BonusHealth) or 0
            pieces += 1
            tierTotal += tonumber(definition.GearTier) or 0
        end
    end
    local meanTier = pieces > 0 and tierTotal / pieces or 0
    return {
        Level = level, Attack = math.floor(attack), Defense = math.floor(defense),
        MaxHealth = 100 + 9 * (level - 1) + math.floor(bonusHP),
        GearPieces = pieces, MeanTier = meanTier,
    }
end

function CombatStats.IncomingDamage(player, rawDamage)
    local stats = CombatStats.Get(player)
    local amount = math.max(0, tonumber(rawDamage) or 0)
    if not stats or amount <= 0 then return amount end
    -- Armor has meaningful diminishing returns; no invulnerability at any tier.
    -- The global armor dial scales effective defense, so it rides the same curve
    -- rather than adding a flat bonus that could push past 100% mitigation.
    local defense = stats.Defense * armorScale
    local mitigation = (defense / (defense + 92))
    -- Completing a six-piece loadout makes the end of each tier notably easier.
    if stats.GearPieces >= 6 and stats.MeanTier >= math.max(1, stats.Level - 1) then
        mitigation = math.min(0.72, mitigation + 0.12)
    end
    return math.max(1, math.ceil(amount * (1 - mitigation)))
end
return CombatStats
