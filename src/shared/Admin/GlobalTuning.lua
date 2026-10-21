-- REALMS OF LUMIA | GLOBAL TUNING DIALS (shared)
-- The single source of truth for the master multipliers. The server validates
-- against this table and the client renders from it.
--
-- Model (industry standard, three layers):
--   AUTHORING value  -> what you type in Advanced (stored, never multiplied)
--   GLOBAL dials     -> multipliers stored here, applied at read/spawn time
--   EFFECTIVE value  -> authoring x dial, what the game actually uses
--
-- Because dials are applied on read, applying a preset twice is identical to
-- applying it once, and setting every dial to 1.0 restores the shipped
-- balance exactly. No compounding, no unrecoverable saves.
local GlobalTuning = {}

GlobalTuning.Version = 1

-- Order controls the UI order.
GlobalTuning.Dials = {
    {
        Id = "Difficulty",
        Label = "Enemy difficulty",
        Hint = "Scales TRASH mob health and damage. Bosses are excluded and use their own dial.",
        Min = 0.4,
        Max = 3.0,
        Step = 0.05,
        Default = 1.0,
        Unit = "x",
    },
    {
        Id = "MobRewards",
        Label = "Kill rewards",
        Hint = "Scales XP and gold from all kills, bosses included.",
        Min = 0.25,
        Max = 3.0,
        Step = 0.05,
        Default = 1.0,
        Unit = "x",
    },
    {
        Id = "QuestRewards",
        Label = "Quest rewards",
        Hint = "Scales quest XP and gold. Raise this to shift progress toward questing.",
        Min = 0.25,
        Max = 3.0,
        Step = 0.05,
        Default = 1.0,
        Unit = "x",
    },
    {
        Id = "LevelPace",
        Label = "Level pace",
        Hint = "Scales XP required per level. Above 1.0 levels slower, below 1.0 faster.",
        Min = 0.5,
        Max = 2.5,
        Step = 0.05,
        Default = 1.0,
        Unit = "x",
    },
    {
        Id = "BossScale",
        Label = "Boss power",
        Hint = "Scales BOSS health and damage only. Tune it apart from trash.",
        Min = 0.5,
        Max = 3.0,
        Step = 0.05,
        Default = 1.0,
        Unit = "x",
    },
    {
        Id = "PlayerDamage",
        Label = "Player damage",
        Hint = "Scales ALL damage you deal: weapons and fists. Lower it if gear kills too fast.",
        Min = 0.4,
        Max = 3.0,
        Step = 0.05,
        Default = 1.0,
        Unit = "x",
    },
    {
        Id = "FistDamage",
        Label = "Fist damage",
        Hint = "Unarmed damage only, independent of every template. Leave at 1.00 to keep punches on the gear curve's defaults.",
        Min = 0.4,
        Max = 3.0,
        Step = 0.05,
        Default = 1.0,
        Unit = "x",
    },
    {
        Id = "PlayerArmor",
        Label = "Player armor",
        Hint = "Scales your defense, which governs damage taken. Raise it to survive longer.",
        Min = 0.4,
        Max = 3.0,
        Step = 0.05,
        Default = 1.0,
        Unit = "x",
    },
}

GlobalTuning.ById = {}
for _, dial in ipairs(GlobalTuning.Dials) do
    GlobalTuning.ById[dial.Id] = dial
end

-- Presets only ever set dials. They never write authoring values, so a preset
-- and a hand edit can never fight each other.
GlobalTuning.Presets = {
    {
        Id = "Casual",
        Label = "Casual",
        Hint = "Softer enemies, sturdier player, faster levels, richer rewards.",
        Values = {
            Difficulty = 0.7, MobRewards = 1.15, QuestRewards = 1.15,
            LevelPace = 0.85, BossScale = 0.8,
            PlayerDamage = 1.15, PlayerArmor = 1.3,
        },
    },
    {
        Id = "QuestLed",
        Label = "Quest-led",
        Hint = "Shipped balance. Quests drive progression, light grinding.",
        Values = {
            Difficulty = 1.0, MobRewards = 1.0, QuestRewards = 1.0,
            LevelPace = 1.0, BossScale = 1.0,
            PlayerDamage = 1.0, PlayerArmor = 1.0,
        },
    },
    {
        Id = "GrindHeavy",
        Label = "Grind-heavy",
        Hint = "Kills pay far more; quests matter less.",
        Values = {
            Difficulty = 1.0, MobRewards = 1.6, QuestRewards = 0.85,
            LevelPace = 1.0, BossScale = 1.0,
            PlayerDamage = 1.0, PlayerArmor = 1.0,
        },
    },
    {
        Id = "Hard",
        Label = "Hard",
        Hint = "Tougher mobs, frailer player, more XP needed, tougher boss.",
        Values = {
            Difficulty = 1.35, MobRewards = 0.9, QuestRewards = 1.0,
            LevelPace = 1.1, BossScale = 1.25,
            PlayerDamage = 0.9, PlayerArmor = 0.85,
        },
    },
    {
        Id = "Hell",
        Label = "Hell",
        Hint = "Brutal trash, thin rewards, brittle player. Stress test.",
        Values = {
            Difficulty = 2.0, MobRewards = 0.7, QuestRewards = 0.9,
            LevelPace = 1.25, BossScale = 1.6,
            PlayerDamage = 0.8, PlayerArmor = 0.7,
        },
    },
}

GlobalTuning.DefaultPreset = "QuestLed"

function GlobalTuning.GetPreset(id)
    for _, preset in ipairs(GlobalTuning.Presets) do
        if preset.Id == id then return preset end
    end
    return nil
end

function GlobalTuning.Defaults()
    local values = {}
    for _, dial in ipairs(GlobalTuning.Dials) do
        values[dial.Id] = dial.Default
    end
    return values
end

function GlobalTuning.Validate(id, value)
    local dial = GlobalTuning.ById[id]
    if not dial then return false, "Unknown dial: " .. tostring(id) end
    if type(value) ~= "number" or value ~= value
        or value <= -math.huge or value >= math.huge then
        return false, "Value must be a number"
    end
    if value < dial.Min or value > dial.Max then
        return false, string.format("%s must be between %.2f and %.2f",
            dial.Label, dial.Min, dial.Max)
    end
    return true
end

-- Fill missing dials with defaults and clamp anything out of range. Used when
-- reading persisted data that may predate a dial being added.
function GlobalTuning.Normalize(values)
    local result = {}
    for _, dial in ipairs(GlobalTuning.Dials) do
        local value = type(values) == "table" and tonumber(values[dial.Id]) or nil
        if not value or value ~= value then
            value = dial.Default
        end
        result[dial.Id] = math.clamp(value, dial.Min, dial.Max)
    end
    return result
end

-- Which preset (if any) these dials currently match exactly.
function GlobalTuning.MatchPreset(values)
    for _, preset in ipairs(GlobalTuning.Presets) do
        local matches = true
        for _, dial in ipairs(GlobalTuning.Dials) do
            local want = preset.Values[dial.Id]
            local have = values[dial.Id]
            if want == nil or have == nil or math.abs(want - have) > 0.0001 then
                matches = false
                break
            end
        end
        if matches then return preset.Id end
    end
    return "Custom"
end

return GlobalTuning
