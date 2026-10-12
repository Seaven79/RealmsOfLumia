local ServiceRegistry = require(script.Parent:WaitForChild("ServiceRegistry"))
local PlayerSessionService = require(script.Parent:WaitForChild("PlayerSessionService"))
local PlayerDataService = require(script.Parent:WaitForChild("PlayerDataService"))

print("[Eternia] MMO server bootstrap starting...")

-- Register our MMO services.
ServiceRegistry.Register("PlayerSessionService", PlayerSessionService)
ServiceRegistry.Register("PlayerDataService", PlayerDataService, {"PlayerSessionService"})

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