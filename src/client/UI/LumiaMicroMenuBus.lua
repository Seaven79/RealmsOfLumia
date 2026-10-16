-- REALMS OF LUMIA | V18 Micro Menu bus
-- Client-only API. Buttons call the original window handlers; no replicated remotes.
local MenuBus = {}
local handlers = {}
local registered = Instance.new("BindableEvent")
MenuBus.Registered = registered.Event

function MenuBus.Register(name, callback)
    assert(type(name) == "string" and name ~= "", "Invalid Lumia menu name")
    assert(type(callback) == "function", "Invalid Lumia menu callback")
    assert(not handlers[name], "Duplicate Lumia menu handler: " .. name)
    handlers[name] = callback
    registered:Fire(name)
end

function MenuBus.IsReady(name)
    return type(handlers[name]) == "function"
end

function MenuBus.Toggle(name)
    local callback = handlers[name]
    if not callback then
        return false, "Window is still loading"
    end
    local ok, err = pcall(callback)
    if not ok then
        warn("[Lumia V18] Micro menu handler error (" .. tostring(name) .. "): " .. tostring(err))
        return false, "This window could not open"
    end
    return true
end

return MenuBus
