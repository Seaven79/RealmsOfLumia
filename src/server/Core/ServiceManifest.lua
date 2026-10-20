-- REALMS OF LUMIA - SERVICE MANIFEST
-- Declarative list of all services registered in ServerBootstrap.
-- Adding a new service: add ONE entry to this manifest. DO NOT edit ServerBootstrap.
-- Each entry: name (string), folder (string), module (string), deps (array, optional), configure (array, optional)

return {
    {name = "PlayerSessionService",     folder = "Players",     module = "PlayerSessionService"},

    {name = "PlayerPersistenceService", folder = "Players",     module = "PlayerPersistenceService",
        deps = {"PlayerSessionService"}},

    {name = "PlayerDataService",        folder = "Players",     module = "PlayerDataService",
        deps = {"PlayerPersistenceService"}},

    {name = "InventoryService",         folder = "Inventory",   module = "InventoryService",
        deps = {"PlayerDataService"},
        configure = {"PlayerDataService"}},

    {name = "EquipmentService",         folder = "Equipment",   module = "EquipmentService",
        deps = {"InventoryService", "PlayerDataService"},
        configure = {"PlayerDataService", "InventoryService"}},

    {name = "ProgressionService",       folder = "Progression", module = "ProgressionService",
        deps = {"PlayerDataService"}},

    {name = "MonsterService",           folder = "Monsters",    module = "MonsterService",
        deps = {"ProgressionService"}},

    {name = "SpawnManager",             folder = "Monsters",    module = "SpawnManager",
        deps = {"MonsterService"}},

    {name = "SwordCombatService",       folder = "Combat",      module = "SwordCombatService",
        deps = {"PlayerDataService", "EquipmentService", "MonsterService"},
        configure = {"PlayerDataService"}},
    {name = "SoulShard",              folder = "Players",    module = "SoulShard",
        deps = {"PlayerDataService"},
        configure = {"PlayerDataService"}},
}