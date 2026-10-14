local services = script.Parent.Parent -- Services root; script is inside Core
local ServiceRegistry = require(script.Parent:WaitForChild("ServiceRegistry"))

local PlayerSessionService = require(services:WaitForChild("Players"):WaitForChild("PlayerSessionService"))
local PlayerPersistenceService = require(services:WaitForChild("Players"):WaitForChild("PlayerPersistenceService"))
local PlayerDataService = require(services:WaitForChild("Players"):WaitForChild("PlayerDataService"))
local InventoryService = require(services:WaitForChild("Inventory"):WaitForChild("InventoryService"))
local EquipmentService = require(services:WaitForChild("Equipment"):WaitForChild("EquipmentService"))
local ProgressionService = require(services:WaitForChild("Progression"):WaitForChild("ProgressionService"))
local MonsterService = require(services:WaitForChild("Monsters"):WaitForChild("MonsterService"))
local SpawnManager = require(services:WaitForChild("Monsters"):WaitForChild("SpawnManager"))
local SwordCombatService = require(services:WaitForChild("Combat"):WaitForChild("SwordCombatService"))

print("[Lumia] MMO server bootstrap starting...")

ServiceRegistry.Register("PlayerSessionService", PlayerSessionService)

ServiceRegistry.Register(
    "PlayerPersistenceService",
    PlayerPersistenceService,
    {"PlayerSessionService"}
)

ServiceRegistry.Register(
    "PlayerDataService",
    PlayerDataService,
    {"PlayerPersistenceService"}
)

InventoryService:Configure(PlayerDataService)

ServiceRegistry.Register(
    "InventoryService",
    InventoryService,
    {"PlayerDataService"}
)

EquipmentService:Configure(PlayerDataService, InventoryService)
ServiceRegistry.Register(
    "EquipmentService",
    EquipmentService,
    {"InventoryService", "PlayerDataService"}
)

ServiceRegistry.Register(
    "ProgressionService",
    ProgressionService,
    {"PlayerDataService"}
)

ServiceRegistry.Register(
    "MonsterService",
    MonsterService,
    {"ProgressionService"}
)

ServiceRegistry.Register(
    "SpawnManager",
    SpawnManager,
    {"MonsterService"}
)

SwordCombatService:Configure(PlayerDataService)
ServiceRegistry.Register(
    "SwordCombatService",
    SwordCombatService,
    {"PlayerDataService", "EquipmentService", "MonsterService"}
)

local initialized = ServiceRegistry.InitAll()

if not initialized then
    warn("[Lumia] MMO Core initialization failed!")
    return
end

local started = ServiceRegistry.StartAll()

if started then
    print("[Lumia] MMO Core started successfully!")
else
    warn("[Lumia] MMO Core startup failed!")
end