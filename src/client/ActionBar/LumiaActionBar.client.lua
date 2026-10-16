-- Realms of Lumia: MMO quick-access action bar.
-- Drag from bag to assign, click or press key to use. Shift+right-click = rebind.
-- Right-click = clear. All saved assignments and consumable effects are server-validated.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer
local lumia = ReplicatedStorage:WaitForChild("Lumia")
local shared = lumia:WaitForChild("Shared")
local Config = require(shared:WaitForChild("ActionBar"):WaitForChild("ActionBarConfig"))
local Definitions = require(shared:WaitForChild("Items"):WaitForChild("ItemDefinitions"))
local Icons = require(shared:WaitForChild("Items"):WaitForChild("ItemIcons"))
local EquipmentRules = require(shared:WaitForChild("Equipment"):WaitForChild("EquipmentRules"))
local ui = script.Parent.Parent:WaitForChild("UI")
local DragDrop = require(ui:WaitForChild("EquipmentDragDrop"))
local EquipmentClient = require(ui:WaitForChild("EquipmentClient"))
local Preview = require(ui:WaitForChild("LumiaItemPreview"))
local Tooltip = require(ui:WaitForChild("ItemTooltip"))
local BarState = require(ui:WaitForChild("LumiaActionBarState"))
local HudDrag = require(ui:WaitForChild("LumiaHudDrag"))
local net = lumia:WaitForChild("ActionBarNetwork")
local getBar = net:WaitForChild("GetActionBar")
local setSlot = net:WaitForChild("SetActionSlot")
local useSlot = net:WaitForChild("UseActionSlot")
local setKey = net:WaitForChild("SetActionKey")

local gui = Instance.new("ScreenGui")
gui.Name = "LumiaActionBar"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.DisplayOrder = 25
local playerGui = player:WaitForChild("PlayerGui")
local existing = playerGui:FindFirstChild(gui.Name)
if existing then existing:Destroy() end
gui.Parent = playerGui
local function create(class,name,parent)
    local node = Instance.new(class)
    node.Name = name
    node.Parent = parent
    return node
end
local gold = Color3.fromRGB(221,177,98)
local textColor = Color3.fromRGB(242,232,205)
local muted = Color3.fromRGB(140,125,107)
local width = Config.SlotCount * 56 + 18
local frame = create("Frame","ActionBar",gui)
frame.AnchorPoint = Vector2.new(0.5,1)
frame.Position = UDim2.new(0.5,0,1,-26)
frame.Size = UDim2.fromOffset(width,82)
frame.BackgroundColor3 = Color3.fromRGB(29,25,25)
frame.BackgroundTransparency = 0.08
frame.BorderSizePixel = 0
create("UICorner","Rounded",frame).CornerRadius = UDim.new(0,8)
local frameStroke = create("UIStroke","Border",frame)
frameStroke.Color = Color3.fromRGB(114,84,48)
frameStroke.Thickness = 1.5
local slots = {}
local bindings = {}
local quantities = {}
local keys = {}
local cooldowns = {}
local busy = false
local waitingRebind = nil
local latestStatus = 0
local tooltip = Tooltip.new(gui)
local status = create("TextLabel","Hint",frame)
status.BackgroundTransparency = 1
status.Position = UDim2.fromOffset(6,59)
status.Size = UDim2.new(1,-12,0,18)
status.Font = Enum.Font.Gotham
status.TextSize = 11
status.TextXAlignment = Enum.TextXAlignment.Center
status.TextColor3 = muted
status.Text = "DRAG HERE TO MOVE BAR  |  Shift+right-click slot: rebind"
status.Active=true
HudDrag.Attach(gui,frame,status,"ActionBar")
local function notify(value)
    latestStatus += 1
    local version = latestStatus
    status.Text = tostring(value)
    status.TextColor3 = gold
    task.delay(3,function()
        if version == latestStatus then
            status.Text = "Drag from bag  |  1–8 to use  |  Right-click: clear"
            status.TextColor3 = muted
        end
    end)
end
local function slotQuantity(index)
    return tonumber(quantities[index]) or 0
end
local function equipped(itemId)
    local current = EquipmentClient.GetEquipmentView()
    local snap = EquipmentClient.GetBagView()
    for _, instanceId in pairs(current) do
        if type(instanceId) == "table" and instanceId.ItemId == itemId then return true end
        if type(instanceId) == "string" then
            -- Public equipment data may use only instance ID; item may be absent from bag.
            for _,record in ipairs(snap.Items or {}) do
                if record.InstanceId == instanceId and record.ItemId == itemId then return true end
            end
        end
    end
    return false
end
local function renderSlot(index)
    local entry = slots[index]
    local itemId = bindings[index]
    if entry and entry.ItemId == itemId then
        -- Item ID unchanged; quantities and key display still update below.
    else
        for _, visual in ipairs(entry.IconHolder:GetChildren()) do visual:Destroy() end
        entry.ItemId = itemId
        if itemId then
            if not Preview.Attach(entry.IconHolder,itemId) then
                local asset, symbol = Icons.Resolve({ItemId=itemId})
                if asset then
                    local picture = create("ImageLabel","ItemIcon",entry.IconHolder)
                    picture.Image = asset
                    picture.BackgroundTransparency = 1
                    picture.Size = UDim2.fromScale(1,1)
                    picture.ScaleType = Enum.ScaleType.Fit
                else
                    local glyph = create("TextLabel","ItemIcon",entry.IconHolder)
                    glyph.BackgroundTransparency = 1
                    glyph.Size = UDim2.fromScale(1,1)
                    glyph.Font = Enum.Font.GothamBold
                    glyph.TextSize = 28
                    glyph.Text = symbol or "?"
                    glyph.TextColor3 = gold
                end
            end
        end
    end
    if not entry then return end
    entry.KeyLabel.Text = Config.KeyLabels[index]
    local keyName = keys[index] or Config.DefaultKeys[index]
    local lookup = {One="1",Two="2",Three="3",Four="4",Five="5",Six="6",
        Seven="7",Eight="8",Nine="9",Zero="0"}
    entry.KeyLabel.Text = lookup[keyName] or keyName
    local definition = itemId and Definitions.Get(itemId)
    local quantity = itemId and slotQuantity(index) or 0
    if definition and definition.Type=="Weapon" and equipped(itemId) then quantity = math.max(1,quantity) end
    entry.Quantity.Text = quantity > 0 and tostring(quantity) or ""
    entry.IconHolder.ImageTransparency = 1 -- transparent parent, icon remains visible
    entry.Empty.Text = itemId and "" or "+"
    entry.Button.BackgroundColor3 = itemId and Color3.fromRGB(58,48,39)
        or Color3.fromRGB(43,40,37)
    entry.Outline.Color = itemId and gold or Color3.fromRGB(97,80,59)
    entry.IconHolder.Visible = itemId ~= nil
    entry.Quantity.Visible = quantity > 1
    entry.OutOfStock.Visible = itemId~=nil and quantity==0
end
local function refresh()
    for i=1,Config.SlotCount do renderSlot(i) end
end
local function applySlots(serverSlots,serverKeys,serverQuantities)
    if type(serverSlots)=="table" then
        table.clear(bindings)
        for i=1,Config.SlotCount do
            if type(serverSlots[i])=="string" and serverSlots[i]~="" then
                bindings[i]=serverSlots[i]
            end
        end
    end
    if type(serverQuantities)=="table" then
        table.clear(quantities)
        for i=1,Config.SlotCount do quantities[i]=tonumber(serverQuantities[i]) or 0 end
    end
    if type(serverKeys)=="table" then
        table.clear(keys)
        for i=1,Config.SlotCount do keys[i]=serverKeys[i] or Config.DefaultKeys[i] end
    end
    BarState.SetSlots(bindings)
    refresh()
end
local function activate(index)
    if busy or waitingRebind then return end
    local itemId = bindings[index]
    if not itemId then notify("Drag a usable item from your bag onto this slot") return end
    local definition = Definitions.Get(itemId)
    if not definition then notify("Unknown item") return end
    if slotQuantity(index)<1 then notify("No item remaining") return end
    local untilTime = cooldowns[itemId] or 0
    if os.clock()<untilTime then notify("Item is on cooldown") return end
    busy = true
    task.spawn(function()
        local ok,response=pcall(function() return useSlot:InvokeServer(index) end)
        busy=false
        if not ok or type(response)~="table" then notify("Cannot reach action service") return end
        if response.Bag then EquipmentClient.UpdateBagSnapshot(response.Bag) end
        if response.Equipment then EquipmentClient.UpdateEquipmentSnapshot(response.Equipment) end
        if response.Slots then applySlots(response.Slots,nil,response.Quantities) end
        if response.Ok then
            cooldowns[itemId] = os.clock() + (tonumber(response.Cooldown) or 0)
            notify(response.Message or "Item used")
        else
            if tonumber(response.Remaining) then
                cooldowns[itemId]=os.clock()+response.Remaining
            end
            notify(response.Message or "Cannot use item")
        end
        refresh()
    end)
end
for index=1,Config.SlotCount do
    local slot=create("TextButton","ActionSlot"..index,frame)
    slot.Position=UDim2.fromOffset(10+(index-1)*56,7)
    slot.Size=UDim2.fromOffset(51,51)
    slot.Text=""
    slot.AutoButtonColor=false
    slot.BorderSizePixel=0
    slot.BackgroundColor3=Color3.fromRGB(43,40,37)
    create("UICorner","Rounded",slot).CornerRadius=UDim.new(0,5)
    local border=create("UIStroke","SlotStroke",slot)
    border.Color=Color3.fromRGB(97,80,59)
    border.Thickness=1.5
    local visuals=create("ImageLabel","IconContainer",slot)
    visuals.BackgroundTransparency=1
    visuals.Image=""
    visuals.Size=UDim2.fromOffset(43,43)
    visuals.Position=UDim2.fromOffset(4,4)
    local blank=create("TextLabel","EmptySlot",slot)
    blank.BackgroundTransparency=1
    blank.Size=UDim2.fromScale(1,1)
    blank.TextColor3=Color3.fromRGB(92,83,73)
    blank.Font=Enum.Font.Gotham
    blank.TextSize=23
    blank.Text="+"
    local keyLabel=create("TextLabel","Keybind",slot)
    keyLabel.BackgroundTransparency=1
    keyLabel.Position=UDim2.fromOffset(3,0)
    keyLabel.Size=UDim2.fromOffset(24,16)
    keyLabel.TextColor3=textColor
    keyLabel.TextStrokeTransparency=0.15
    keyLabel.TextSize=11
    keyLabel.Font=Enum.Font.GothamBold
    keyLabel.TextXAlignment=Enum.TextXAlignment.Left
    local quantity=create("TextLabel","Quantity",slot)
    quantity.BackgroundTransparency=1
    quantity.Position=UDim2.new(0,3,1,-19)
    quantity.Size=UDim2.new(1,-6,0,16)
    quantity.TextSize=12
    quantity.Font=Enum.Font.GothamBold
    quantity.TextColor3=textColor
    quantity.TextStrokeTransparency=0.2
    quantity.TextXAlignment=Enum.TextXAlignment.Right
    local dark=create("Frame","Unavailable",slot)
    dark.Size=UDim2.fromScale(1,1)
    dark.BackgroundColor3=Color3.new(0,0,0)
    dark.BackgroundTransparency=0.47
    dark.Visible=false
    dark.ZIndex=2
    create("UICorner","Rounded",dark).CornerRadius=UDim.new(0,5)
    local cd=create("TextLabel","Cooldown",slot)
    cd.Size=UDim2.fromScale(1,1)
    cd.BackgroundTransparency=1
    cd.TextColor3=textColor
    cd.TextStrokeTransparency=0
    cd.Font=Enum.Font.GothamBold
    cd.TextSize=12
    cd.Text=""
    cd.ZIndex=6
    local entry={Button=slot,Outline=border,IconHolder=visuals,Empty=blank,
        Quantity=quantity,KeyLabel=keyLabel,OutOfStock=dark,Cooldown=cd}
    slots[index]=entry
    slot.MouseButton1Click:Connect(function() activate(index) end)
    slot.MouseButton2Click:Connect(function()
        if UIS:IsKeyDown(Enum.KeyCode.LeftShift) or UIS:IsKeyDown(Enum.KeyCode.RightShift) then
            waitingRebind=index
            notify("Press a new key for slot "..index.." (Esc cancels)")
        else
            if busy then return end
            task.spawn(function()
                local ok,reply=pcall(function()return setSlot:InvokeServer(index,nil)end)
                if ok and type(reply)=="table" and reply.Ok then
                    if reply.Bag then EquipmentClient.UpdateBagSnapshot(reply.Bag) end
                    applySlots(reply.Slots,nil,reply.Quantities)
                    notify("Returned to bag")
                else notify(reply and reply.Message or "Cannot clear slot") end
            end)
        end
    end)
    slot.MouseEnter:Connect(function()
        local id=bindings[index]
        if id and not DragDrop.IsDragging() then
            tooltip:Show({ItemId=id,Quantity=slotQuantity(index)})
        end
    end)
    slot.MouseLeave:Connect(function() tooltip:Hide() end)
    DragDrop.RegisterExternalTarget(slot,function(item)
        local definition=item and Definitions.Get(item.ItemId)
        return Config.IsAssignable(definition)
    end,function(item,coordinates)
        tooltip:Hide()
        local ok,reply=pcall(function()
            local pos=coordinates
            return setSlot:InvokeServer(index,item.ItemId,
                pos and pos.BagId,pos and pos.Slot,item.InstanceId)
        end)
        if not ok or type(reply)~="table" or not reply.Ok then
            local reason=ok and type(reply)=="table" and reply.Message or "Could not assign"
            notify(reason)
            return false,reason
        end
        if reply.Bag then EquipmentClient.UpdateBagSnapshot(reply.Bag) end
        applySlots(reply.Slots,nil,reply.Quantities)
        notify((Definitions.Get(item.ItemId) or {}).DisplayName or "Item moved to bar")
        return true,"Item assigned"
    end)
end
refresh()
EquipmentClient.BagChanged:Connect(refresh)
EquipmentClient.EquipmentChanged:Connect(refresh)
UIS.InputBegan:Connect(function(input,processed)
    if UIS:GetFocusedTextBox() then return end
    if waitingRebind then
        if input.KeyCode==Enum.KeyCode.Escape then
            waitingRebind=nil
            notify("Rebind cancelled")
        elseif Config.ValidKey(input.KeyCode.Name) then
            local slotIndex=waitingRebind
            waitingRebind=nil
            task.spawn(function()
                local ok,reply=pcall(function()
                    return setKey:InvokeServer(slotIndex,input.KeyCode.Name)
                end)
                if ok and reply and reply.Ok then
                    applySlots(nil,reply.Keys)
                    notify("Slot "..slotIndex.." key updated")
                else notify(reply and reply.Message or "Could not rebind") end
            end)
        else
            notify("Use 0–9 or Q, E, R, T, F, G, Z, X, C, V")
        end
        return
    end
    if processed or UIS:IsKeyDown(Enum.KeyCode.LeftControl)
        or UIS:IsKeyDown(Enum.KeyCode.RightControl)
        or UIS:IsKeyDown(Enum.KeyCode.LeftAlt)
        or UIS:IsKeyDown(Enum.KeyCode.RightAlt) then return end
    local pressed=input.KeyCode.Name
    for index=1,Config.SlotCount do
        if pressed==(keys[index] or Config.DefaultKeys[index]) then
            activate(index)
            return
        end
    end
end)
local displayAccum=0
RunService.RenderStepped:Connect(function(dt)
    displayAccum += dt
    if displayAccum < 0.08 then return end
    displayAccum=0
    for index,entry in ipairs(slots) do
        local id=bindings[index]
        local remaining=id and math.max(0,(cooldowns[id] or 0)-os.clock()) or 0
        entry.Cooldown.Text=remaining>0 and string.format("%.1f",remaining) or ""
    end
end)
task.spawn(function()
    for attempt=1,12 do
        local ok,reply=pcall(function()return getBar:InvokeServer()end)
        if ok and type(reply)=="table" and reply.Ok then
            if type(reply.Bag)=="table" then
                EquipmentClient.UpdateBagSnapshot(reply.Bag)
            end
            applySlots(reply.Slots,reply.Keys,reply.Quantities)
            notify("Action bar ready. Drag items from your bag.")
            return
        end
        task.wait(0.75)
    end
    notify("Action bar could not load. Rejoin to retry.")
end)
print("[Lumia - Action Bar] Toolbar ready: drag from bag, use keys, rebind with Shift+right-click")
