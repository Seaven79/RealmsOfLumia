local ServiceRegistry = {}

local registered = {}
local initialized = {}
local started = {}
local resolvedOrder = nil
local state = "Registered"

function ServiceRegistry.Register(name, service, dependencies)
    assert(state == "Registered", "Cannot register after initialization")
    assert(type(name) == "string" and name ~= "", "Invalid service name")
    assert(type(service) == "table", "Service must be a table")
    assert(not registered[name], "Duplicate service: " .. name)

    dependencies = dependencies or {}
    assert(type(dependencies) == "table", "Dependencies must be a table")

    local copied = {}
    local seen = {}

    for index, dependency in ipairs(dependencies) do
        assert(type(dependency) == "string" and dependency ~= "",
            "Invalid dependency")
        assert(not seen[dependency], "Duplicate dependency: " .. dependency)

        seen[dependency] = true
        copied[index] = dependency
    end

    registered[name] = {
        Service = service,
        Dependencies = copied
    }
end

local function resolveDependencies()
    local order = {}
    local visited = {}
    local names = {}

    for name in pairs(registered) do
        table.insert(names, name)
    end

    table.sort(names)

    local function visit(name)
        if visited[name] == 1 then
            error("Circular dependency involving: " .. name)
        end

        if visited[name] == 2 then
            return
        end

        local entry = registered[name]

        if not entry then
            error("Missing dependency: " .. name)
        end

        visited[name] = 1

        local dependencies = table.clone(entry.Dependencies)
        table.sort(dependencies)

        for _, dependency in ipairs(dependencies) do
            visit(dependency)
        end

        visited[name] = 2
        table.insert(order, name)
    end

    for _, name in ipairs(names) do
        visit(name)
    end

    return order
end

function ServiceRegistry.InitAll()
    if state ~= "Registered" then
        warn("[Lumia - Service Registry] Initialization already attempted")
        return false
    end

    state = "Initializing"

    local ok, result = pcall(resolveDependencies)

    if not ok then
        state = "Failed"
        warn("[Lumia - Service Registry] Dependency error: " .. tostring(result))
        return false
    end

    resolvedOrder = result

    for _, name in ipairs(resolvedOrder) do
        local service = registered[name].Service

        local success, err = pcall(function()
            if service.Init then
                service:Init()
            end
        end)

        if not success then
            state = "Failed"
            warn("[Lumia - Service Registry] Init failed: " .. name .. " - " .. tostring(err))
            return false
        end

        initialized[name] = true
        print("[Lumia - Service Registry] Service initialized: " .. name)
    end

    state = "Initialized"
    return true
end

function ServiceRegistry.StartAll()
    if state ~= "Initialized" then
        warn("[Lumia - Service Registry] Services not ready to start")
        return false
    end

    state = "Starting"

    for _, name in ipairs(resolvedOrder) do
        local service = registered[name].Service

        local success, err = pcall(function()
            if service.Start then
                service:Start()
            end
        end)

        if not success then
            state = "Failed"
            warn("[Lumia - Service Registry] Start failed: " .. name .. " - " .. tostring(err))
            return false
        end

        started[name] = true
        print("[Lumia - Service Registry] Service started: " .. name)
    end

    state = "Started"
    return true
end

function ServiceRegistry.IsStarted(name)
    return started[name] == true
end

function ServiceRegistry.GetStartupOrder()
    if not resolvedOrder then
        return nil
    end

    return table.clone(resolvedOrder)
end

function ServiceRegistry.GetState()
    return state
end

return ServiceRegistry