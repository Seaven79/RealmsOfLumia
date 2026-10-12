local ServiceRegistry = {}

local registered = {}
local initialized = {}
local started = {}

function ServiceRegistry.Register(name, service)
    assert(type(name) == "string" and name ~= "", "Invalid service name")
    assert(type(service) == "table", "Service must be a table")
    assert(not registered[name], "Service already registered: " .. name)

    registered[name] = service
end

function ServiceRegistry.InitAll()
    local names = {}

    for name in pairs(registered) do
        table.insert(names, name)
    end

    table.sort(names)

    for _, name in ipairs(names) do
        local service = registered[name]

        local success, err = pcall(function()
            if service.Init then
                service:Init()
            end
        end)

        if not success then
            warn("[Eternia] Initialization failed: " .. name .. " - " .. tostring(err))
            return false
        end

        initialized[name] = true
        print("[Eternia] Service initialized: " .. name)
    end

    return true
end

function ServiceRegistry.StartAll()
    for name in pairs(registered) do
        if not initialized[name] then
            warn("[Eternia] Service not initialized: " .. name)
            return false
        end
    end

    local names = {}

    for name in pairs(registered) do
        table.insert(names, name)
    end

    table.sort(names)

    for _, name in ipairs(names) do
        local service = registered[name]

        local success, err = pcall(function()
            if service.Start then
                service:Start()
            end
        end)

        if not success then
            warn("[Eternia] Startup failed: " .. name .. " - " .. tostring(err))
            return false
        end

        started[name] = true
        print("[Eternia] Service started: " .. name)
    end

    return true
end

function ServiceRegistry.IsStarted(name)
    return started[name] == true
end

return ServiceRegistry
