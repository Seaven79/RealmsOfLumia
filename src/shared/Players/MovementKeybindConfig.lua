-- REALMS OF LUMIA - MOVEMENT KEYBINDS
-- Shared validation prevents collisions and invalid saved key names.
local Config = {}

Config.Order = {"Forward", "Backward", "StrafeLeft", "StrafeRight"}
Config.Labels = {
    Forward = "Move Forward",
    Backward = "Move Backward",
    StrafeLeft = "Strafe Left",
    StrafeRight = "Strafe Right",
}
Config.Defaults = {
    Forward = "W",
    Backward = "S",
    StrafeLeft = "A",
    StrafeRight = "D",
}

-- B and C are reserved for existing Lumia bag/character controls.
-- Space and Escape retain their Roblox jump/menu behavior.
local allowed = {}
for letter in ("ADEFGHIJKLMNPQRSTUVWX YZ"):gmatch("%a") do
    -- B = Bag; C = Character; O = default Roblox camera zoom.
    if letter ~= "B" and letter ~= "C" and letter ~= "O" then
        allowed[letter] = true
    end
end
for _, arrow in ipairs({"Up", "Down", "Left", "Right"}) do
    allowed[arrow] = true
end

function Config.IsAllowed(keyName)
    return type(keyName) == "string" and allowed[keyName] == true
        and Enum.KeyCode[keyName] ~= nil
end

function Config.CopyDefault()
    local result = {}
    for _, action in ipairs(Config.Order) do
        result[action] = Config.Defaults[action]
    end
    return result
end

function Config.Validate(bindings)
    if type(bindings) ~= "table" then
        return false, "Expected a keybind table"
    end
    local used = {}
    for _, action in ipairs(Config.Order) do
        local name = bindings[action]
        if not Config.IsAllowed(name) then
            return false, "Invalid key for " .. action
        end
        if used[name] then
            return false, name .. " is already assigned to " .. used[name]
        end
        used[name] = action
    end
    return true
end

function Config.CopyOrDefault(bindings)
    local ok = Config.Validate(bindings)
    if not ok then
        return Config.CopyDefault()
    end
    local result = {}
    for _, action in ipairs(Config.Order) do
        result[action] = bindings[action]
    end
    return result
end

return Config
