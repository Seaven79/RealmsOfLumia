-- Realms of Lumia: reusable icon merchant UI; server owns money, inventory and pricing.
-- Bag auto-opens beside the merchant. Drag an item from the bag to the sell tray.
local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local UIS=game:GetService("UserInputService")
local CAS=game:GetService("ContextActionService")
local player=Players.LocalPlayer
local mouse=player:GetMouse()
local base=script.Parent.Parent
local Shared=ReplicatedStorage:WaitForChild("Lumia"):WaitForChild("Shared")
local Items=require(Shared:WaitForChild("Items"):WaitForChild("ItemDefinitions"))
local Currency=require(Shared:WaitForChild("Commerce"):WaitForChild("LumiaCurrency"))
local Coins=require(base:WaitForChild("UI"):WaitForChild("LumiaCoinUI"))
local Preview=require(base:WaitForChild("UI"):WaitForChild("LumiaItemPreview"))
local Tooltip=require(base:WaitForChild("UI"):WaitForChild("ItemTooltip"))
local DragDrop=require(base:WaitForChild("UI"):WaitForChild("EquipmentDragDrop"))
local Bridge=require(base:WaitForChild("UI"):WaitForChild("MerchantUIBridge"))
local EquipmentClient=require(base:WaitForChild("UI"):WaitForChild("EquipmentClient"))
local EquipmentRules=require(Shared:WaitForChild("Equipment"):WaitForChild("EquipmentRules"))
local net=ReplicatedStorage.Lumia:WaitForChild("CommerceNetwork")
local openRemote=net:WaitForChild("OpenMerchant")
local action=net:WaitForChild("MerchantAction")
local gui=Instance.new("ScreenGui")
gui.Name="LumiaMerchantUI";gui.ResetOnSpawn=false
gui.IgnoreGuiInset=true;gui.DisplayOrder=70
local playerGui=player:WaitForChild("PlayerGui")
local LumiaModalState = require(script.Parent.Parent:WaitForChild("UI"):WaitForChild("LumiaModalState"))
local old=playerGui:FindFirstChild(gui.Name)
if old then old:Destroy() end
gui.Parent=playerGui
local function node(class,props,parent)
    local o=Instance.new(class)
    for k,v in pairs(props) do o[k]=v end
    o.Parent=parent;return o
end
local gold=Color3.fromRGB(227,180,100)
local cream=Color3.fromRGB(237,219,184)
local dark=Color3.fromRGB(38,29,24)
local panel=Color3.fromRGB(53,39,31)
local function text(parent,name,t,pos,size,pts,col,bold)
    return node("TextLabel",{Name=name,Position=pos,Size=size,Text=t,
        BackgroundTransparency=1,TextColor3=col or cream,
        TextSize=pts or 13,Font=bold and Enum.Font.GothamBold or Enum.Font.Gotham,
        TextXAlignment=Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Center,
        TextWrapped=true},parent)
end
local frame=node("Frame",{Name="MerchantWindow",Position=UDim2.fromOffset(200,120),
    Size=UDim2.fromOffset(445,475),BackgroundColor3=dark,BorderSizePixel=0,
    Visible=false},gui)
node("UICorner",{CornerRadius=UDim.new(0,9)},frame)
node("UIStroke",{Color=gold,Thickness=1.5},frame)
text(frame,"Name","MIRA THE TRADER",UDim2.fromOffset(16,12),UDim2.fromOffset(330,27),19,gold,true)
local wallet=Coins.Wallet(frame,Currency,0,false)
wallet.Position=UDim2.fromOffset(16,47)
local close=node("TextButton",{Name="Close",Text="X",Position=UDim2.fromOffset(408,13),
    Size=UDim2.fromOffset(25,25),BackgroundColor3=Color3.fromRGB(90,62,44),
    TextColor3=cream,TextSize=13,Font=Enum.Font.GothamBold},frame)
node("UICorner",{CornerRadius=UDim.new(0,5)},close)
text(frame,"MerchantGreeting","The hearth is warm. Choose what you need.",
    UDim2.fromOffset(16,75),UDim2.fromOffset(410,22),12,cream,false)
text(frame,"BuyHeading","SUPPLIES",UDim2.fromOffset(16,106),UDim2.fromOffset(300,19),14,gold,true)
local grid=node("Frame",{Name="ShopSlots",Position=UDim2.fromOffset(16,130),
    Size=UDim2.fromOffset(412,190),BackgroundTransparency=1},frame)
text(frame,"SellHeading","SELL ITEMS",UDim2.fromOffset(16,325),UDim2.fromOffset(160,20),14,gold,true)
local sellTray=node("Frame",{Name="SellDropTarget",Position=UDim2.fromOffset(16,351),
    Size=UDim2.fromOffset(411,66),BackgroundColor3=Color3.fromRGB(61,45,32),
    BorderSizePixel=0,Active=true},frame)
node("UICorner",{CornerRadius=UDim.new(0,7)},sellTray)
node("UIStroke",{Color=Color3.fromRGB(129,94,54),Thickness=1.4},sellTray)
text(sellTray,"TrayIcon","◈",UDim2.fromOffset(17,12),UDim2.fromOffset(42,42),30,gold,true)
text(sellTray,"TrayTitle","DRAG ITEM FROM BAG HERE",UDim2.fromOffset(74,12),UDim2.fromOffset(321,24),14,cream,true)
text(sellTray,"TrayNote","Click a bag stack to sell all of it · drag sells 1 · quest items protected",
    UDim2.fromOffset(74,35),UDim2.fromOffset(321,20),11,Color3.fromRGB(178,160,137),false)
local status=text(frame,"Status","Hover to inspect an item. Drag from the open bag to sell.",
    UDim2.fromOffset(16,426),UDim2.fromOffset(412,38),12,gold,false)
status.TextXAlignment=Enum.TextXAlignment.Center
local tooltip=Tooltip.new(gui)

-- Hold Shift while hovering to compare against what is equipped in that slot.
-- Returns the slot plus whatever occupies it (nil when the slot is empty), so
-- the tooltip can still show the gains from buying into an empty slot.
tooltip:SetComparisonProvider(function(itemId)
    local def=Items.Get(itemId)
    if not def then return nil end
    local slot=EquipmentRules.GetSlot(def)
    if not slot then return nil end
    local equipped=EquipmentClient.GetEquipmentView()
    return { Slot = slot, Equipped = equipped and equipped[slot] or nil }
end)

local hoveredEntry=nil
local function showEntryTooltip(entry)
    if not entry then return end
    tooltip:Show({ItemId=entry.ItemId,StoreBuyPrice=entry.Price,Quantity=1})
end
local shiftKeys={[Enum.KeyCode.LeftShift]=true,[Enum.KeyCode.RightShift]=true}
UIS.InputBegan:Connect(function(input)
    if shiftKeys[input.KeyCode] and hoveredEntry then showEntryTooltip(hoveredEntry) end
end)
UIS.InputEnded:Connect(function(input)
    if shiftKeys[input.KeyCode] and hoveredEntry then showEntryTooltip(hoveredEntry) end
end)

local busy=false
local showing=nil
local last=nil
local function layoutShop()
    local screen=gui.AbsoluteSize
    local width=445+12+282
    local x=math.max(8,math.floor((screen.X-width)/2))
    local y=math.max(8,math.floor((screen.Y-475)/2))
    frame.Position=UDim2.fromOffset(x,y)
end
local function notify(message)
    status.Text=tostring(message or "")
end
local function updateInventory(response)
    if response and type(response.Bag)=="table" then
        if not EquipmentClient.UpdateBagSnapshot(response.Bag) then
            -- A concurrent equip operation will let the normal bag polling refresh.
        end
    end
end
local function transact(verb,id,bagId,bagSlot,instanceId)
    if busy then return false,"Please wait" end
    busy=true
    local ok,reply=pcall(function()
        return action:InvokeServer(verb,id,bagId,bagSlot,instanceId)
    end)
    busy=false
    if not ok or type(reply)~="table" then
        notify("Shop connection failed")
        return false,"Shop connection failed"
    end
    if not reply.Ok then
        notify(reply.Message or "Trade rejected")
        return false,reply.Message or "Trade rejected"
    end
    updateInventory(reply)
    if reply.BuyItems then
        last=reply
        Coins.SetWallet(wallet,Currency,reply.Gold or 0)
    end
    notify(verb=="Sell" and "Item sold!" or "Purchased! Check your bag.")
    return true,verb=="Sell" and "Sold one item" or "Purchased"
end
local function rarityColor(id)
    local item=Items.Get(id) or {}
    local rare=item.Rarity
    return rare=="Uncommon" and Color3.fromRGB(87,175,116)
        or rare=="Rare" and Color3.fromRGB(79,139,236)
        or rare=="Epic" and Color3.fromRGB(174,104,231)
        or rare=="Poor" and Color3.fromRGB(139,134,130)
        or Color3.fromRGB(148,120,78)
end
local shopButtons={}
-- Price chip: the coin glyph that matches the DENOMINATION, then the amount.
-- Currency is 1 Platinum = 10,000, 1 Copper = 100, 1 Bronze = 1, so a price of 95
-- is 95 Bronze and must show a Bronze coin, not a generic gold icon. Up to three
-- denominations fit in the 60px cell; the row is centred.
local CHIP_WIDTH=60
local function priceChip(parent,amount)
    local row=node("Frame",{Name="PriceRow",BackgroundTransparency=1,
        Position=UDim2.fromOffset(1,58),Size=UDim2.fromOffset(CHIP_WIDTH,22)},parent)
    local highDenom,midDenom,lowDenom=Currency.Split(amount)
    local groups={}
    if highDenom>0 then groups[#groups+1]={Currency.Tiers[1].Id,highDenom} end
    if midDenom>0 then groups[#groups+1]={Currency.Tiers[2].Id,midDenom} end
    if lowDenom>0 or #groups==0 then groups[#groups+1]={Currency.Tiers[3].Id,lowDenom} end

    local count=#groups
    -- Up to 3 denominations must share a 60px cell: shrink the glyph and type
    -- rather than letting the amounts overlap.
    local coinSize=count>=3 and 10 or 13
    local textSize=count>=3 and 9 or 11
    local step=math.min(30,math.floor(CHIP_WIDTH/count))
    local startX=math.max(0,math.floor((CHIP_WIDTH-step*count)/2))
    for i,g in ipairs(groups) do
        local x=startX+(i-1)*step
        local coin=Coins.Create(row,g[1],coinSize)
        coin.Position=UDim2.fromOffset(x,math.floor((22-coinSize)/2))
        node("TextLabel",{Name="Amount",BackgroundTransparency=1,Text=tostring(g[2]),
            Position=UDim2.fromOffset(x+coinSize+2,0),
            Size=UDim2.fromOffset(math.max(8,step-coinSize-2),22),
            Font=Enum.Font.GothamBold,TextSize=textSize,TextColor3=gold,
            TextXAlignment=Enum.TextXAlignment.Left,TextTruncate=Enum.TextTruncate.AtEnd},row)
    end
    return row
end
local function clearShopSlots()
    for _,button in ipairs(shopButtons) do button:Destroy() end
    table.clear(shopButtons)
end
local function render(data)
    if not data or not data.Ok then
        notify(data and data.Message or "Merchant unavailable")
        return
    end
    last=data
    local header=frame:FindFirstChild("Name")
    if header and type(data.MerchantName)=="string" then header.Text=string.upper(data.MerchantName) end
    Coins.SetWallet(wallet,Currency,data.Gold or 0)
    clearShopSlots()
    for i=1,12 do
        local col=(i-1)%6
        local row=math.floor((i-1)/6)
        local entry=(data.BuyItems or {})[i]
        local button=node("TextButton",{Name="ShopSlot"..i,
            Position=UDim2.fromOffset(col*69,row*91),Size=UDim2.fromOffset(62,83),
            BackgroundColor3=panel,AutoButtonColor=false,
            Text="",BorderSizePixel=0},grid)
        node("UICorner",{CornerRadius=UDim.new(0,5)},button)
        node("UIStroke",{Color=entry and rarityColor(entry.ItemId) or Color3.fromRGB(82,63,48),
            Thickness=entry and 2 or 1},button)
        if entry then
            local iconCell=node("Frame",{Name="IconCell",Size=UDim2.fromOffset(57,58),
                Position=UDim2.fromOffset(2,2),BackgroundTransparency=1},button)
            if not Preview.Attach(iconCell,entry.ItemId) then
                text(iconCell,"Fallback","◆",UDim2.fromScale(0,0),UDim2.fromScale(1,1),28,gold,true)
            end
            priceChip(button,entry.Price)
            button.MouseEnter:Connect(function()
                hoveredEntry=entry
                showEntryTooltip(entry)
            end)
            button.MouseLeave:Connect(function()
                if hoveredEntry==entry then hoveredEntry=nil end
                tooltip:Hide()
            end)
            button.MouseButton1Click:Connect(function()
                tooltip:Hide()
                transact("Buy",entry.ItemId)
            end)
        end
        table.insert(shopButtons,button)
    end
end
local function closeMerchant()
    if not frame.Visible then return end
    tooltip:Hide()
    Bridge.Close(frame)
    frame.Visible=false
    LumiaModalState:Unregister("MerchantWindow")
end
close.MouseButton1Click:Connect(closeMerchant)
DragDrop.RegisterExternalTarget(sellTray,function(item)
    local def=item and Items.Get(item.ItemId)
    return frame.Visible and def~=nil and def.Type~="Quest"
        and def.QuestItem~=true and type(def.SellValue)=="number" and def.SellValue>0
end,function(item,coordinates)
    tooltip:Hide()
    if not frame.Visible then return false,"The shop is closed" end
    if type(coordinates)~="table" then return false,"Invalid bag position" end
    return transact("Sell",item.ItemId,coordinates.BagId,coordinates.Slot,item.InstanceId)
end)
-- Clicking a stack in the bag sells the whole stack. Dragging still sells one, so
-- both habits work and the tray hint explains the difference.
Bridge.SellStackRequested:Connect(function(item,coordinates)
    if not frame.Visible then return end
    if type(item)~="table" or type(coordinates)~="table" then return end
    local def=Items.Get(item.ItemId)
    if not def or def.Type=="Quest" or def.QuestItem==true then return end
    if type(def.SellValue)~="number" or def.SellValue<=0 then return end
    tooltip:Hide()
    transact("SellStack",item.ItemId,coordinates.BagId,coordinates.Slot,item.InstanceId)
end)
local function npcAtMouse()
    local target=mouse.Target
    local model=target and target:FindFirstAncestorOfClass("Model")
    return model and model:GetAttribute("LumiaMerchant") and model or nil
end
local function openMerchant()
    if not npcAtMouse() or busy then return end
    busy=true
    local ok,reply=pcall(function()return openRemote:InvokeServer()end)
    busy=false
    if not ok or not reply or not reply.Ok then
        notify(reply and reply.Message or "Merchant unavailable")
        return
    end
    layoutShop()
    frame.Visible=true
    LumiaModalState:Register("MerchantWindow")
    render(reply)
    updateInventory(reply)
    Bridge.Open(frame)
    -- Equip comparisons need the equipped map. If nothing has loaded it yet
    -- (character sheet never opened), ask for it now instead of showing
    -- "nothing equipped" for gear the player is wearing.
    if next(EquipmentClient.GetEquipmentView())==nil then
        EquipmentClient.RequestRefresh()
    end
end
local bindId="Lumia_MerchantInteract"
local function rebind()
    CAS:UnbindAction(bindId)
    local name=player:GetAttribute("LumiaInteractKey") or "MouseButton2"
    local input=name=="MouseButton2" and Enum.UserInputType.MouseButton2 or Enum.KeyCode[name]
    if not input then input=Enum.UserInputType.MouseButton2 end
    CAS:BindActionAtPriority(bindId,function(_,state)
        if state~=Enum.UserInputState.Begin or not npcAtMouse() then
            return Enum.ContextActionResult.Pass
        end
        if not frame.Visible and not UIS:GetFocusedTextBox() then task.spawn(openMerchant) end
        return Enum.ContextActionResult.Sink
    end,false,3200,input)
end
player:GetAttributeChangedSignal("LumiaInteractKey"):Connect(rebind)
rebind()
UIS.InputBegan:Connect(function(input,processed)
    if processed or UIS:GetFocusedTextBox() then return end
    if input.KeyCode==Enum.KeyCode.Escape and frame.Visible then closeMerchant() end
    if input.KeyCode==Enum.KeyCode.H then
        local ok,message=transact("UsePotion","FieldPotion")
        if ok then notify(message) end
    end
end)
print("[Lumia - Commerce] Slot merchant & drag-to-sell UI ready")
