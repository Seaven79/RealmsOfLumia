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

-- STEP 11M INVENTORY TEST
-- Temporary development test. Remove after verification.
task.spawn(function()
    local Players = game:GetService("Players")

    local player = Players.PlayerAdded:Wait()

    -- Wait until PlayerDataService creates the profile.
    local profile = nil

    for _ = 1, 100 do
        profile = PlayerDataService:GetProfile(player)
        if profile then break end
        task.wait(0.1)
    end

    if not profile then
        warn("[INVENTORY TEST] FAIL: Profile unavailable")
        return
    end

    local passed = 0
    local failed = 0

    local function check(condition, message)
        if condition then
            passed += 1
            print("[INVENTORY TEST] PASS: " .. message)
        else
            failed += 1
            warn("[INVENTORY TEST] FAIL: " .. message)
        end
    end

    print("========== INVENTORY TESTS ==========")

    local before = InventoryService:GetQuantity(
        player, "RustySword"
    )

    local created, addError = InventoryService:AddItem(
        player, "RustySword", 1
    )

    check(
        created ~= nil and #created == 1,
        "Add RustySword"
    )

    if not created then
        warn("[INVENTORY TEST] " .. tostring(addError))
        return
    end

    local sword = created[1]

    check(
        type(sword.InstanceId) == "string"
            and sword.InstanceId ~= "",
        "Sword has unique instance ID"
    )

    check(
        InventoryService:GetQuantity(player, "RustySword")
            == before + 1,
        "Sword quantity increases by one"
    )

    local found = InventoryService:GetItemByInstanceId(
        player, sword.InstanceId
    )

    check(
        found ~= nil and found.ItemId == "RustySword",
        "Sword can be found by instance ID"
    )

    local removed = InventoryService:RemoveItem(
        player, sword.InstanceId
    )

    check(
        removed == true,
        "Remove RustySword"
    )

    check(
        InventoryService:GetQuantity(player, "RustySword")
            == before,
        "Sword quantity returns to original value"
    )

    local invalid = InventoryService:AddItem(
        player, "NotARealItem", 1
    )

    check(
        invalid == nil,
        "Unknown item rejected"
    )

    print(
        "[INVENTORY TEST] RESULTS: "
        .. passed .. " passed, "
        .. failed .. " failed"
    )

    print("=====================================")
end)
else
    warn("[Eternia] MMO Core startup failed!")
end