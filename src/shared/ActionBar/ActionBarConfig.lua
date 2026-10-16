-- Realms of Lumia: shared action bar rules (reusable for all future consumables).
-- Items and effects are always resolved/validated on the server; this is display/config only.
local Config = {}
Config.SlotCount = 8
Config.DefaultKeys = {"One","Two","Three","Four","Five","Six","Seven","Eight"}
Config.KeyLabels = {"1","2","3","4","5","6","7","8"}
Config.DefaultCooldown = 8
Config.MaxCooldown = 120
-- Only safe, client-selectable keyboard keys. 1–8 are the defaults.
Config.AllowedKeys = {
    One=true, Two=true, Three=true, Four=true, Five=true, Six=true,
    Seven=true, Eight=true, Nine=true, Zero=true,
    Q=true, E=true, R=true, T=true, F=true, G=true, Z=true, X=true,
    C=true, V=true,
}
function Config.ValidKey(name)
    return type(name)=="string" and Config.AllowedKeys[name]==true
end

function Config.IsAssignable(definition)
    if type(definition) ~= "table" then return false end
    return definition.Type == "Potion" and type(definition.Heal) == "number"
        and definition.Heal > 0 and definition.Heal < 10000
        or definition.Type == "Weapon" and type(definition.SubType) == "string"
end

function Config.IsConsumable(definition)
    return type(definition) == "table" and definition.Type == "Potion"
        and type(definition.Heal) == "number" and definition.Heal > 0
        and definition.Heal < 10000
end
return Config
