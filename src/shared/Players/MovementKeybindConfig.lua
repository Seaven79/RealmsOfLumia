-- Realms of Lumia - shared movement and interaction keybinds v4
-- Existing four-key profiles are transparently upgraded in memory.
local Config = {}
Config.MovementOrder = {"Forward", "Backward", "StrafeLeft", "StrafeRight"}
Config.Order = {"Forward", "Backward", "StrafeLeft", "StrafeRight", "Interact"}
Config.Labels = {
    Forward="Move Forward", Backward="Move Backward",
    StrafeLeft="Strafe Left", StrafeRight="Strafe Right",
    Interact="Interact / Talk / Loot",
}
Config.Defaults = {
    Forward="W", Backward="S", StrafeLeft="A", StrafeRight="D",
    Interact="MouseButton2",
}
local allowed={}
for letter in ("ADEFGHIJKLMNPQRSTUVWX YZ"):gmatch("%a") do
    if letter~="B" and letter~="C" and letter~="O" then allowed[letter]=true end
end
for _,arrow in ipairs({"Up","Down","Left","Right"}) do allowed[arrow]=true end
function Config.IsAllowed(keyName, action)
    if keyName=="MouseButton2" then return action==nil or action=="Interact" end
    return type(keyName)=="string" and allowed[keyName]==true and Enum.KeyCode[keyName]~=nil
end
function Config.CopyDefault()
    local t={}
    for _,a in ipairs(Config.Order) do t[a]=Config.Defaults[a] end
    return t
end
function Config.Validate(bindings)
    if type(bindings)~="table" then return false,"Expected keybind table" end
    local used={}
    for _,a in ipairs(Config.Order) do
        local name=bindings[a]
        if not Config.IsAllowed(name,a) then return false,"Invalid key for "..a end
        if used[name] then return false,name.." already assigned to "..used[name] end
        used[name]=a
    end
    return true
end
function Config.CopyOrDefault(existing)
    local merged=Config.CopyDefault()
    if type(existing)=="table" then
        for _,a in ipairs(Config.Order) do
            if existing[a]~=nil then merged[a]=existing[a] end
        end
    end
    local ok=Config.Validate(merged)
    return ok and merged or Config.CopyDefault()
end
return Config
