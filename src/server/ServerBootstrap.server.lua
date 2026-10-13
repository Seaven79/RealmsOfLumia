local ServiceRegistry = require(script.Parent:WaitForChild("ServiceRegistry"))
local PlayerSessionService = require(script.Parent:WaitForChild("PlayerSessionService"))
local PlayerDataService = require(script.Parent:WaitForChild("PlayerDataService"))
local InventoryService = require(script.Parent:WaitForChild("InventoryService"))
local ProgressionService = require(script.Parent:WaitForChild("ProgressionService"))
local MonsterService = require(script.Parent:WaitForChild("MonsterService"))
local SpawnManager = require(script.Parent:WaitForChild("SpawnManager"))

print("[Eternia] MMO server bootstrap starting...")

-- Register our MMO services.
ServiceRegistry.Register("PlayerSessionService", PlayerSessionService)
ServiceRegistry.Register("PlayerDataService", PlayerDataService, {"PlayerSessionService"})
InventoryService:Configure(PlayerDataService)
ServiceRegistry.Register("InventoryService", InventoryService, {"PlayerDataService"})
ServiceRegistry.Register("ProgressionService", ProgressionService, {"PlayerDataService"})
ServiceRegistry.Register("MonsterService", MonsterService, {"ProgressionService"})
ServiceRegistry.Register("SpawnManager", SpawnManager, {"MonsterService"})

-- Initialize every service before starting any service.
local initialized = ServiceRegistry.InitAll()

if not initialized then
    warn("[Eternia] MMO Core initialization failed!")
    return
end

-- Start services only after initialization succeeds.
local started = ServiceRegistry.StartAll()

if started then
    print("[Eternia] MMO Core started successfully!")
else
    warn("[Eternia] MMO Core startup failed!")
end