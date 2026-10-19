-- REALMS OF LUMIA | Curve Lab | pure deterministic mathematics (shared)
-- Uses original monsters/XP as the baseline; neutral parameters change nothing.
local CurveMath = {}

CurveMath.Order = {
    "Health", "Damage", "Defense", "AttackSpeed", "Movement",
    "Detection", "Wander", "AttackRange", "Respawn", "LevelXP", "KillXP", "Gold",
}
CurveMath.CoreOrder = {"Health", "Damage", "LevelXP", "KillXP", "Gold"}
CurveMath.Labels = {
    Health = "Monster HP", Damage = "Monster damage",
    Defense = "Defense", AttackSpeed = "Attack speed",
    Movement = "Move speed", Detection = "Detection", Wander = "Wander radius",
    AttackRange = "Attack range", Respawn = "Respawn rate",
    LevelXP = "XP to level", KillXP = "Kill XP", Gold = "Monster gold",
}
CurveMath.Reference = {Linear = 0.10, Quadratic = 0.002}
CurveMath.Neutral = {Scale = 1, Linear = 0.10, Quadratic = 0.002}
CurveMath.Limits = {
    Scale = {0.25, 3}, Linear = {0, 0.4}, Quadratic = {0, 0.02},
}

-- One dial drives every global category. 1.00 is the ORIGINAL game balance.
-- At level 1 the Scale still changes HP / damage; the growth coefficients
-- gently separate high-level enemies further. These weights are DESIGN data,
-- not values the owner has to tune individually.
CurveMath.IntensityMin = 0.50
CurveMath.IntensityMax = 2.00
CurveMath.ProfileIntensities = {Gentle = 0.70, Classic = 1.00, Hardcore = 1.40}
local weights = {
    Health      = {1.00, 0.070,  0.0015},
    Damage      = {0.75, 0.050,  0.0010},
    Defense     = {0.35, 0.015,  0.0003},
    AttackSpeed = {0.18, 0.010,  0.0002},
    Movement    = {0.10, 0.005,  0.0001},
    Detection   = {0.14, 0.008,  0.0001},
    Wander      = {0.08, 0.005,  0.0001},
    AttackRange = {0.05, 0.002,  0.00005},
    Respawn     = {0.20, 0.012,  0.0002},
    LevelXP     = {0.70, 0.035,  0.0007},
    KillXP      = {-0.25, 0.000, 0.0000},
    Gold        = {-0.20, 0.000, 0.0000},
}

function CurveMath.FromIntensity(value)
    if type(value) ~= "number" or value ~= value or value <= -math.huge
        or value >= math.huge or value < CurveMath.IntensityMin
        or value > CurveMath.IntensityMax then
        return nil
    end
    local offset = value - 1
    local result = {}
    for _, kind in ipairs(CurveMath.Order) do
        local w = weights[kind]
        result[kind] = {
            Scale = 1 + offset * w[1],
            Linear = CurveMath.Reference.Linear + offset * w[2],
            Quadratic = CurveMath.Reference.Quadratic + offset * w[3],
        }
    end
    return result
end

function CurveMath.Presets(name)
    return CurveMath.FromIntensity(CurveMath.ProfileIntensities[name] or 1)
end

-- Previous independently edited 12-curve configurations still load.
-- They are not falsely labelled as a single preset in the new GUI.
function CurveMath.InferIntensity(values)
    if type(values) ~= "table" or type(values.Health) ~= "table" then return nil end
    local value = values.Health.Scale
    local rebuilt = CurveMath.FromIntensity(value)
    if not rebuilt then return nil end
    for _, kind in ipairs(CurveMath.Order) do
        if type(values[kind]) ~= "table" then return nil end
        for _, name in ipairs({"Scale", "Linear", "Quadratic"}) do
            if type(values[kind][name]) ~= "number"
                or math.abs(values[kind][name] - rebuilt[kind][name]) > 0.00001 then
                return nil
            end
        end
    end
    return value
end

function CurveMath.Valid(values)
    if type(values) ~= "table" then return false end
    for _, kind in ipairs(CurveMath.Order) do
        local entry = values[kind]
        -- Legacy Experience Config v2 published only five categories.
        -- These are required; new categories default to neutral.
        if entry == nil and not table.find(CurveMath.CoreOrder, kind) then
            entry = CurveMath.Neutral
        end
        if type(entry) ~= "table" then return false end
        for field, bounds in pairs(CurveMath.Limits) do
            local value = entry[field]
            if type(value) ~= "number" or value ~= value
                or value <= -math.huge or value >= math.huge
                or value < bounds[1] or value > bounds[2] then
                return false
            end
        end
    end
    return true
end

function CurveMath.Power(level, linear, quadratic)
    local n = math.clamp(math.floor(tonumber(level) or 1), 1, 60) - 1
    return 1 + linear * n + quadratic * n * n
end

function CurveMath.Factor(kind, level, values)
    local entry = values and values[kind]
    if not entry then return 1 end
    local reference = CurveMath.Power(level,
        CurveMath.Reference.Linear, CurveMath.Reference.Quadratic)
    local candidate = CurveMath.Power(level, entry.Linear, entry.Quadratic)
    local exponent = kind == "Damage" and 0.85 or 1
    return entry.Scale * (candidate / reference) ^ exponent
end

function CurveMath.Normalize(values)
    if not CurveMath.Valid(values) then return nil end
    local result = {}
    for _, kind in ipairs(CurveMath.Order) do
        result[kind] = table.clone(values[kind] or CurveMath.Neutral)
    end
    return result
end

-- All non-integer stats are calculated ONCE at spawn and captured in AI's
-- definition table. Respawn rate is stored separately on the monster model.
-- Scale > 1 means faster attacks and more frequent respawns.
function CurveMath.AdjustStat(kind, level, base, values, low, high)
    if type(base) ~= "number" or base ~= base or base <= 0 then return base end
    local factor = CurveMath.Factor(kind, level, values)
    if kind == "AttackSpeed" or kind == "Respawn" then
        factor = 1 / factor
    end
    if math.abs(factor - 1) < 0.0000001 then return base end
    return math.clamp(math.round(base * factor * 100) / 100, low, high)
end

function CurveMath.Adjust(kind, level, base, values, maxValue)
    if type(base) ~= "number" or base <= 0 then return base end
    return math.clamp(math.round(base * CurveMath.Factor(kind, level, values)),
        1, maxValue or 10000000)
end

-- Preview a known monster at an imaginary level. Does not change its actual level.
function CurveMath.PreviewMonster(kind, definition, level, values)
    local baseLevel = definition.Level or 1
    local base = kind == "Health" and definition.MaxHealth or definition.Damage
    if type(base) ~= "number" then return 0 end
    local exponent = kind == "Damage" and 0.85 or 1
    local referenceAtBase = CurveMath.Power(baseLevel, 0.10, 0.002) ^ exponent
    local referenceAtLevel = CurveMath.Power(level, 0.10, 0.002) ^ exponent
    local hypothetical = base * referenceAtLevel / referenceAtBase
    return CurveMath.Adjust(kind, level, hypothetical, values, 10000000)
end

return CurveMath
