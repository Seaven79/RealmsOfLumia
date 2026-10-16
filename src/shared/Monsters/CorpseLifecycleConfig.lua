-- REALMS OF LUMIA - CORPSE AND RESPAWN POLICY v1
-- Timer after death if still unlooted; timer after taking all items; and
-- the *separate* respawn delays that start only when a corpse disappears.
local Config = {}
Config.Default = {
    UnlootedCorpseSeconds = 20,
    LootedCorpseSeconds = 3,
    RespawnAfterUnlootedSeconds = 30,
    RespawnAfterLootedSeconds = 10,
}
Config.Monsters = {
    ForestWolf = {}, -- Override individual values here as new monsters are added.
}
function Config.Get(monsterId, key)
    local profile = Config.Monsters[monsterId]
    local value = profile and profile[key]
    if type(value) ~= "number" then value = Config.Default[key] end
    return math.clamp(value or 0, 0, 3600)
end
return Config