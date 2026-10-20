-- Shared merchant/bag presentation bus. Client UX only; all trades remain server-side.
-- Future merchants call Bridge.Open/Close and share the same inventory window.
local Bridge={}
local changed=Instance.new("BindableEvent")
Bridge.Changed=changed.Event
local sellStack=Instance.new("BindableEvent")
Bridge.SellStackRequested=sellStack.Event
local active=nil
function Bridge.Open(merchantWindow)
    active=merchantWindow
    changed:Fire(true,merchantWindow)
end
function Bridge.Close(merchantWindow)
    if active~=merchantWindow then return end
    active=nil
    changed:Fire(false,merchantWindow)
end
function Bridge.IsOpen()
    return active~=nil and active.Parent~=nil and active.Visible
end
-- The bag asks the merchant window to sell a whole stack. The merchant owns the
-- network call, so the bag does not need to know about CommerceNetwork.
function Bridge.SellStack(item,coordinates)
    if type(item)~="table" or type(coordinates)~="table" then return end
    sellStack:Fire(item,coordinates)
end
return Bridge
