local RunService = game:GetService("RunService")

if not RunService:IsStudio() then
    return
end

local registrySource = script.Parent:WaitForChild("ServiceRegistryUnderTest")

local passed = 0
local failed = 0

local function newRegistry()
    -- Every test receives a fresh ModuleScript instance.
    local copy = registrySource:Clone()
    copy.Parent = script

    local registry = require(copy)
    return registry, copy
end

local function test(name, callback)
    local ok, result = pcall(callback)

    if ok and result == true then
        passed += 1
        print("[Lumia - Service Registry Tests] PASS: " .. name)
    else
        failed += 1
        warn("[Lumia - Service Registry Tests] FAIL: " .. name)
        if not ok then
            warn("[Lumia - Service Registry Tests] ERROR: " .. tostring(result))
        end
    end
end

print("[Lumia - Service Registry Tests] ========== LUMIA REGISTRY TESTS ==========")

test("Dependencies control initialization and startup order", function()
    local registry, copy = newRegistry()
    local events = {}

    local function makeService(name)
        return {
            Init = function()
                table.insert(events, "Init:" .. name)
            end,
            Start = function()
                table.insert(events, "Start:" .. name)
            end
        }
    end

    registry.Register("ACombat", makeService("ACombat"), {"ZData"})
    registry.Register("ZData", makeService("ZData"))

    local initialized = registry.InitAll()
    local started = registry.StartAll()
    local order = registry.GetStartupOrder()

    local result = initialized
        and started
        and order[1] == "ZData"
        and order[2] == "ACombat"
        and events[1] == "Init:ZData"
        and events[2] == "Init:ACombat"
        and events[3] == "Start:ZData"
        and events[4] == "Start:ACombat"
        and registry.GetState() == "Started"

    copy:Destroy()
    return result
end)

test("Missing dependencies prevent startup", function()
    local registry, copy = newRegistry()

    registry.Register("Combat", {}, {"MissingDataService"})

    local initialized = registry.InitAll()
    local started = registry.StartAll()

    local result = initialized == false
        and started == false
        and registry.GetState() == "Failed"

    copy:Destroy()
    return result
end)

test("Circular dependencies prevent startup", function()
    local registry, copy = newRegistry()

    registry.Register("Combat", {}, {"Inventory"})
    registry.Register("Inventory", {}, {"Combat"})

    local initialized = registry.InitAll()
    local started = registry.StartAll()

    local result = initialized == false
        and started == false
        and registry.GetState() == "Failed"

    copy:Destroy()
    return result
end)

print(
    "[Lumia - Service Registry Tests] RESULTS: "
    .. passed .. " passed, "
    .. failed .. " failed"
)

if passed == 3 and failed == 0 then
    print("[Lumia - Service Registry Tests] ALL TESTS PASSED!")
else
    warn("[Lumia - Service Registry Tests] SOME TESTS FAILED!")
end

print("[Lumia - Service Registry Tests] ===========================================")