-- REALMS OF LUMIA | Gear curve layer
--
-- Templates reshape the gear ladder WITHOUT touching the authored catalog.
-- The authored numbers in GearCatalog stay exactly as written, and this module
-- derives the effective numbers that combat, tooltips, the bag and merchants use.
--
--   authored (GearCatalog)  x  tier weight for the active template  =  effective
--
-- Every weight list is 1.0 by default, which means "identity": the derived values
-- are the authored values, so switching back to a neutral template is an exact
-- revert with nothing to undo.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GearCurve = {}

-- Weight per GearTier, index 1..5. Shape matters more than scale here: the global
-- PlayerDamage dial already handles "everything hits harder". These weights change
-- how much each tier is worth relative to the others.
GearCurve.Templates = {
    -- Flattens the top end: cheap gear stays close to good gear, so difficulty
    -- comes from mobs rather than from being under-geared.
    Casual = { 1.00, 0.98, 0.95, 0.92, 0.88 },
    -- Neutral reference. Identity, so this is the "authored" game.
    QuestLed = { 1.00, 1.00, 1.00, 1.00, 1.00 },
    -- Rewards climbing the ladder: late tiers are worth noticeably more.
    GrindHeavy = { 0.92, 0.96, 1.04, 1.12, 1.20 },
    -- Identity shape; the squeeze comes from the PlayerDamage/PlayerArmor dials.
    Hard = { 1.00, 1.00, 1.00, 1.00, 1.00 },
    Hell = { 1.00, 1.00, 1.00, 1.00, 1.00 },
}

GearCurve.DefaultTemplate = "QuestLed"
GearCurve.AttributeName = "LumiaActiveGearTemplate"

-- Fields a template is allowed to reshape. Range, cooldown, level requirement and
-- tier identity are never touched: those are design constants, not balance sliders.
GearCurve.ScaledFields = { "Damage", "Attack", "Defense", "BonusHealth", "SellValue" }

local cache = {}

local function hub()
    return ReplicatedStorage:FindFirstChild("Lumia")
end

function GearCurve.GetTemplate()
    local folder = hub()
    local name = folder and folder:GetAttribute(GearCurve.AttributeName)
    if type(name) == "string" and GearCurve.Templates[name] ~= nil then
        return name
    end
    return GearCurve.DefaultTemplate
end

function GearCurve.Weight(templateName, tier)
    local weights = GearCurve.Templates[templateName]
        or GearCurve.Templates[GearCurve.DefaultTemplate]
    local numeric = tonumber(tier)
    if not numeric then return 1 end
    local index = math.clamp(math.floor(numeric), 1, #weights)
    return weights[index] or 1
end

function GearCurve.WeightFor(definition)
    if type(definition) ~= "table" then return 1 end
    if type(definition.GearTier) ~= "number" then return 1 end
    return GearCurve.Weight(GearCurve.GetTemplate(), definition.GearTier)
end

local function scaleValue(value, weight)
    if type(value) ~= "number" or weight == 1 then return value end
    local scaled = value * weight
    if value % 1 == 0 then
        scaled = math.floor(scaled + 0.5)
    end
    -- A positive stat must never round down to nothing.
    if value > 0 and scaled < 1 then scaled = 1 end
    return scaled
end

-- Returns the effective definition. Untiered items (potions, quest items) and
-- identity templates return the authored table itself, so the hot path is free.
function GearCurve.Apply(definition)
    if type(definition) ~= "table" then return definition end
    local tier = tonumber(definition.GearTier)
    if not tier then return definition end

    local template = GearCurve.GetTemplate()
    local weight = GearCurve.Weight(template, tier)
    if weight == 1 then return definition end

    local cached = cache[definition.Id]
    if cached and cached.template == template
        and cached.source == definition then
        return cached.derived
    end

    local derived = {}
    for key, value in pairs(definition) do
        derived[key] = value
    end
    for _, field in ipairs(GearCurve.ScaledFields) do
        derived[field] = scaleValue(definition[field], weight)
    end
    -- Kept for tooltips/admin so the UI can explain a reshaped number.
    derived.LumiaCurveWeight = weight
    derived.LumiaAuthoredDefinition = definition

    cache[definition.Id] = {
        template = template,
        source = definition,
        derived = derived,
    }
    return derived
end

-- Price multiplier for a stock entry, which stores its own fixed price rather
-- than reading SellValue from the definition.
function GearCurve.PriceScale(definition)
    local weight = GearCurve.WeightFor(definition)
    if weight == 1 then return 1 end
    return weight
end

function GearCurve.ClearCache()
    cache = {}
end

-- The server publishes the active template as an attribute; clients pick it up
-- here and drop stale derived values.
local folder = hub()
if folder then
    folder:GetAttributeChangedSignal(GearCurve.AttributeName):Connect(function()
        cache = {}
    end)
end

return GearCurve
