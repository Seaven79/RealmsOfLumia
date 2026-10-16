-- Client-side projection of server-saved quickbar assignments.
-- No ownership or bag records are modified here. The visible bag omits reserved stacks;
-- they still occupy physical inventory capacity until a future container migration.
local State={}
local event=Instance.new("BindableEvent")
State.Changed=event.Event
local reserved={}
function State.SetSlots(slots)
    local nextReserved={}
    if type(slots)=="table" then
        for _,itemId in pairs(slots) do
            if type(itemId)=="string" and itemId~="" then
                nextReserved[itemId]=true
            end
        end
    end
    reserved=nextReserved
    event:Fire()
end
function State.IsOnBar(itemId)
    return type(itemId)=="string" and reserved[itemId]==true
end
return State
