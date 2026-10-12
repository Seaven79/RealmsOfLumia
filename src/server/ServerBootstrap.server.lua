local ServiceRegistry = require(script.Parent:WaitForChild("ServiceRegistry"))

print("[Eternia] MMO server bootstrap starting...")

-- Temporary test service.
-- This verifies our MMO Core without changing existing gameplay.
local TestService = {}

function TestService:Init()
    print("[Eternia] TestService initialized")
end

function TestService:Start()
    print("[Eternia] TestService running")
end

ServiceRegistry.Register("TestService", TestService)

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
