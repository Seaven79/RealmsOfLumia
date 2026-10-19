local services = script.Parent.Parent -- Services root; script is inside Core
local ServiceRegistry = require(script.Parent:WaitForChild("ServiceRegistry"))
local Manifest = require(script.Parent:WaitForChild("ServiceManifest"))

local PlayerPositions = require(game:GetService("ReplicatedStorage")
    :WaitForChild("Lumia")
    :WaitForChild("Shared")
    :WaitForChild("Players")
    :WaitForChild("PlayerPositions"))

local PathfindingQueue = require(services:WaitForChild("Monsters"):WaitForChild("PathfindingQueue"))

print("[Lumia - Server Bootstrap] MMO server bootstrap starting...")

PlayerPositions:Start()
PathfindingQueue:Start()

-- Phase 1: Load all service modules from manifest
local loaded = {}
for _, entry in ipairs(Manifest) do
    local folder = services:WaitForChild(entry.folder)
    local module = folder:WaitForChild(entry.module)
    loaded[entry.name] = require(module)
end

-- Phase 2: Configure services that declare a configure list (dependency injection)
for _, entry in ipairs(Manifest) do
    if entry.configure and type(loaded[entry.name].Configure) == "function" then
        local args = {}
        for _, depName in ipairs(entry.configure) do
            if not loaded[depName] then
                error("[Lumia Bootstrap] Configure dependency not loaded: " .. depName)
            end
            table.insert(args, loaded[depName])
        end
        loaded[entry.name]:Configure(table.unpack(args))
    end
end

-- Phase 3: Register all services with the registry
for _, entry in ipairs(Manifest) do
    ServiceRegistry.Register(entry.name, loaded[entry.name], entry.deps or {})
end

-- Phase 4: Initialize and start
local initialized = ServiceRegistry.InitAll()

if not initialized then
    warn("[Lumia - Server Bootstrap] MMO Core initialization failed!")
    return
end

local started = ServiceRegistry.StartAll()

if started then
    print("[Lumia - Server Bootstrap] MMO Core started successfully!")
else
    warn("[Lumia - Server Bootstrap] MMO Core startup failed!")
end