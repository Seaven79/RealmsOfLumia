-- REALMS OF LUMIA - SERVER ONLY MONSTER EVENTS
-- Defined in one ModuleScript: all require() callers share these BindableEvents.
-- No service reaches into another service's private state.
-- Died: (model, monsterId)
-- LootCompleted: (model)
-- CorpseRemoved: (model, spawnPointId, monsterId, fullyLooted)
local function signal(name)
    local event = Instance.new("BindableEvent")
    event.Name = name
    return event
end
return {
    Died = signal("MonsterDied"),
    LootCompleted = signal("MonsterLootCompleted"),
    CorpseRemoved = signal("MonsterCorpseRemoved"),
}