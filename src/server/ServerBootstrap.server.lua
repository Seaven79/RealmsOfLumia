local ServiceRegistry = require(script.Parent:WaitForChild("ServiceRegistry"))

local PlayerSessionService = require(script.Parent:WaitForChild("PlayerSessionService"))
local PlayerPersistenceService = require(script.Parent:WaitForChild("PlayerPersistenceService"))
local PlayerDataService = require(script.Parent:WaitForChild("PlayerDataService"))
local InventoryService = require(script.Parent:WaitForChild("InventoryService"))
local ProgressionService = require(script.Parent:WaitForChild("ProgressionService"))
local MonsterService = require(script.Parent:WaitForChild("MonsterService"))
local SpawnManager = require(script.Parent:WaitForChild("SpawnManager"))

print("[Eternia] MMO server bootstrap starting...")

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

local initialized = ServiceRegistry.InitAll()

if not initialized then
    warn("[Eternia] MMO Core initialization failed!")
    return
end

local started = ServiceRegistry.StartAll()

if started then
    print("[Eternia] MMO Core started successfully!")
else
    warn("[Eternia] MMO Core startup failed!")
end