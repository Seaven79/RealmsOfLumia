-- REALMS OF LUMIA | ADMIN PANEL SCHEMA (shared, single source of truth)
-- The client renders these fields. The server validates every write against
-- the same table, so a modified client cannot write an out-of-range value.
--
-- TO ADD A CONTROL (the "template" workflow):
--   1. Add a section entry to Schema.Sections (Kind = "fields").
--   2. Add fields with Schema.AddField{ Id=..., Section=..., Category=..., Key=... }.
--   3. Add a matching branch in AdminBridge.server.lua for that Category.
-- Nothing else needs editing: labels, ranges, defaults and validation all come
-- from here.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Lumia"):WaitForChild("Shared")
local QuestConfig = require(Shared:WaitForChild("Quests"):WaitForChild("QuestConfig"))
local MonsterConfig = require(Shared:WaitForChild("Monsters"):WaitForChild("MonsterConfig"))
local ProgressionConfig = require(Shared:WaitForChild("Progression"):WaitForChild("ProgressionConfig"))

local Schema = {}
Schema.Version = 1
Schema.Sections = {}
Schema.Fields = {}
Schema.ById = {}

-- Sections render in array order. Kind decides which renderer the client uses.
-- "Advanced" sections are the per-item authoring values; the Global section is
-- the primary control surface (master dials + presets).
Schema.Sections = {
    {
        Id = "global",
        Label = "Global tuning",
        Kind = "global",
        Description = "Master multipliers. One dial changes every monster, reward and level requirement at once.",
    },
    {
        Id = "progression",
        Label = "Level XP",
        Kind = "fields",
        Hidden = true,
        Advanced = true,
        Description = "Authoring values: XP required to advance, before the Level pace dial.",
    },
    {
        Id = "quests",
        Label = "Quest rewards",
        Kind = "fields",
        Hidden = true,
        Advanced = true,
        Description = "Authoring values per quest, before the Quest rewards dial.",
    },
    {
        Id = "monsters",
        Label = "Kill rewards",
        Kind = "fields",
        Hidden = true,
        Advanced = true,
        Description = "Authoring values per monster, before the Kill rewards dial.",
    },
    {
        Id = "mobstats",
        Label = "Mob stats",
        Kind = "mobstats",
        Hidden = true,
        Advanced = true,
        Description = "Per-monster health, damage and movement. Multiplied by the difficulty dials at spawn.",
    },
    {
        Id = "tools",
        Label = "Tools",
        Kind = "tools",
        Description = "Owner-only maintenance. These change YOUR OWN character immediately and cannot be undone.",
    },
}

function Schema.AddField(entry)
    assert(type(entry) == "table", "AddField expects a table")
    assert(type(entry.Id) == "string" and entry.Id ~= "", "field needs an Id")
    assert(Schema.ById[entry.Id] == nil, "duplicate field Id: " .. tostring(entry.Id))
    Schema.ById[entry.Id] = entry
    Schema.Fields[#Schema.Fields + 1] = entry
    return entry
end

function Schema.GetField(id)
    return Schema.ById[id]
end

function Schema.GetSection(id)
    for _, section in ipairs(Schema.Sections) do
        if section.Id == id then return section end
    end
    return nil
end

-- Bounds check shared by the client (disable + error hint) and the server
-- (authoritative rejection).
function Schema.Validate(field, value)
    if type(field) ~= "table" then return false, "Unknown setting" end
    if type(value) ~= "number" or value ~= value
        or value <= -math.huge or value >= math.huge then
        return false, "Value must be a number"
    end
    if field.Integer and value % 1 ~= 0 then
        return false, "Value must be a whole number"
    end
    if value < field.Min or value > field.Max then
        return false, string.format("Value must be between %s and %s",
            tostring(field.Min), tostring(field.Max))
    end
    return true
end

--------------------------------------------------------------------------------
-- Progression: XP required per level
--------------------------------------------------------------------------------

local LEVEL_ROWS = 8
for level = 1, LEVEL_ROWS do
    local defaultXP = ProgressionConfig.GetRequiredXP(level) or 0
    Schema.AddField({
        Id = "LevelXP:" .. tostring(level),
        Section = "progression",
        Category = "LevelXP",
        Key = level,
        Label = string.format("Level %d to %d", level, level + 1),
        Min = 1,
        Max = 10000000,
        Integer = true,
        Unit = "xp",
        Default = defaultXP,
    })
end

--------------------------------------------------------------------------------
-- Quests: per-quest XP and gold
--------------------------------------------------------------------------------

for _, quest in ipairs(QuestConfig.Quests) do
    Schema.AddField({
        Id = "QuestXP:" .. quest.Id,
        Section = "quests",
        Category = "QuestRewardXP",
        Key = quest.Id,
        Label = quest.Name,
        Hint = quest.Id .. "  •  " .. tostring(quest.Kind or "Quest"),
        Min = 0,
        Max = 1000000,
        Integer = true,
        Unit = "xp",
        Default = tonumber(quest.XP) or 0,
    })
    Schema.AddField({
        Id = "QuestGold:" .. quest.Id,
        Section = "quests",
        Category = "QuestRewardGold",
        Key = quest.Id,
        Label = quest.Name,
        Hint = quest.Id .. "  •  gold reward",
        Min = 0,
        Max = 1000000,
        Integer = true,
        Unit = "g",
        Default = tonumber(quest.Gold) or 0,
    })
end

--------------------------------------------------------------------------------
-- Monsters: kill XP
--------------------------------------------------------------------------------

local monsterIds = {}
for monsterId in pairs(MonsterConfig.Definitions) do
    monsterIds[#monsterIds + 1] = monsterId
end
table.sort(monsterIds)

for _, monsterId in ipairs(monsterIds) do
    local definition = MonsterConfig.Definitions[monsterId]
    Schema.AddField({
        Id = "MonsterXP:" .. monsterId,
        Section = "monsters",
        Category = "MonsterXP",
        Key = monsterId,
        Label = definition.DisplayName or monsterId,
        Hint = string.format("%s  •  level %s  •  %d gold per kill",
            monsterId, tostring(definition.Level or 1), tonumber(definition.GoldReward) or 0),
        Min = 1,
        Max = 1000000,
        Integer = true,
        Unit = "xp",
        Default = tonumber(definition.ExperienceReward) or 0,
    })
end

-- Fields grouped by section, built once so the client does not re-scan.
Schema.BySection = {}
for _, section in ipairs(Schema.Sections) do
    Schema.BySection[section.Id] = {}
end
for _, field in ipairs(Schema.Fields) do
    local bucket = Schema.BySection[field.Section]
    if bucket then bucket[#bucket + 1] = field end
end

Schema.QuestIds = {}
for _, quest in ipairs(QuestConfig.Quests) do
    Schema.QuestIds[#Schema.QuestIds + 1] = quest.Id
end

Schema.MonsterIds = monsterIds

return Schema
