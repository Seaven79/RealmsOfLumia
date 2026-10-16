-- Realms of Lumia: server-side physical quickbar item storage.
-- Stored in Profile.Inventory.ActionBarItems, separate from bag Items.
-- DataStore validator permits extra inventory fields; no global schema reset.
-- All transfers are synchronous: no yielding or client-provided prices/stats.
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local Services=script.Parent.Parent
local Data=require(Services:WaitForChild("Players"):WaitForChild("PlayerDataService"))
local Inventory=require(Services:WaitForChild("Inventory"):WaitForChild("InventoryService"))
local Equipment=require(Services:WaitForChild("Equipment"):WaitForChild("EquipmentService"))
local Combat=require(Services:WaitForChild("Combat"):WaitForChild("SwordCombatService"))
local Snapshot=require(Services:WaitForChild("Inventory"):WaitForChild("BagSnapshot"))
local Shared=ReplicatedStorage:WaitForChild("Lumia"):WaitForChild("Shared")
local Definitions=require(Shared:WaitForChild("Items"):WaitForChild("ItemDefinitions"))
local Config=require(Shared:WaitForChild("ActionBar"):WaitForChild("ActionBarConfig"))
local Storage={}
local function get(player)
    local profile=Data:GetProfile(player)
    local inv=profile and profile.Inventory
    if not inv or type(inv.Items)~="table" or type(inv.Equipment)~="table" then return nil end
    return inv
end
local function valid(index)
    return type(index)=="number" and index%1==0 and index>=1 and index<=Config.SlotCount
end
local function worn(inv,record)
    if type(record.InstanceId)~="string" then return false end
    for _,instance in pairs(inv.Equipment) do
        if instance==record.InstanceId then return true end
    end
    return false
end
local function findRaw(inv,bagId,bagSlot,id,instanceId)
    for n,record in ipairs(inv.Items) do
        if record.BagId==bagId and record.BagSlot==bagSlot
            and record.ItemId==id and record.InstanceId==instanceId then
            return n,record
        end
    end
    return nil,nil
end
local function rawCopy(rec)
    -- Preserve the complete persistent item record (including future metadata),
    -- while ensuring an action-bar item no longer occupies an inventory bag slot.
    local result=table.clone(rec)
    result.BagId=nil
    result.BagSlot=nil
    return result
end
function Storage:Initialize(player,slots)
    local inv=get(player)
    if not inv then return false end
    if type(inv.ActionBarItems)=="table" then return true end
    inv.ActionBarItems={}
    -- First v14 login: convert only v13's existing owned shortcuts into real
    -- items. Equipped weapons stay as equipment shortcuts (no item duplication).
    local used={}
    for index=1,Config.SlotCount do
        local key=tostring(index)
        local itemId=slots[key] or slots[index]
        local definition=type(itemId)=="string" and Definitions.Get(itemId)
        if definition and Config.IsAssignable(definition) then
            local recordIndex=nil
            if not used[itemId] then
                for n,record in ipairs(inv.Items) do
                    if record.ItemId==itemId and record.BagId~=nil
                        and type(record.Quantity)=="number" and record.Quantity>=1
                        and not worn(inv,record) then
                        recordIndex=n;break
                    end
                end
            end
            if recordIndex then
                local record=table.remove(inv.Items,recordIndex)
                inv.ActionBarItems[key]=rawCopy(record)
                used[itemId]=true
            else
                local equipped=false
                for _,rec in ipairs(inv.Items) do
                    if rec.ItemId==itemId and worn(inv,rec) then equipped=true break end
                end
                if not equipped then slots[key]=nil end
            end
        else
            slots[key]=nil
        end
        slots[index]=nil
    end
    return true
end
function Storage:Quantity(player,index)
    local inv=get(player)
    if not inv or not valid(index) then return 0 end
    local record=type(inv.ActionBarItems)=="table" and inv.ActionBarItems[tostring(index)]
    return record and type(record.Quantity)=="number" and record.Quantity or 0
end
function Storage:EquippedShortcut(player,id)
    local inv=get(player)
    if not inv then return false end
    for _,rec in ipairs(inv.Items) do
        if rec.ItemId==id and worn(inv,rec) then return true end
    end
    return false
end
function Storage:Public(player,slots)
    local inv=get(player)
    local listed,counts={},{}
    for index=1,Config.SlotCount do
        local key=tostring(index)
        local record=inv and type(inv.ActionBarItems)=="table" and inv.ActionBarItems[key]
        local id=record and record.ItemId or slots[key] or slots[index]
        local def=type(id)=="string" and Definitions.Get(id)
        if type(id)=="string" and def and Config.IsAssignable(def)
            and (record or self:EquippedShortcut(player,id)) then
            listed[index]=id
            counts[index]=record and record.Quantity or 1
            slots[key]=id
        else
            listed[index]=""
            counts[index]=0
            slots[key]=nil
        end
        slots[index]=nil
    end
    return listed,counts
end
function Storage:MoveToBar(player,index,itemId,bagId,bagSlot,instanceId,slots)
    if not valid(index) or type(itemId)~="string" or type(bagId)~="number"
        or type(bagSlot)~="number" then return false,"Invalid action slot or bag source" end
    local def=Definitions.Get(itemId)
    if not Config.IsAssignable(def) then return false,"Cannot place this item on the bar" end
    if bagId%1~=0 or bagSlot%1~=0 then return false,"Invalid bag position" end
    local inv=get(player)
    if not inv or type(inv.ActionBarItems)~="table" then return false,"Inventory loading" end
    local key=tostring(index)
    if inv.ActionBarItems[key] then return false,"Return the existing bar item to your bag first" end
    local item=Inventory:GetBagItemAt(player,bagId,bagSlot)
    if not item or item.ItemId~=itemId or item.InstanceId~=instanceId then
        return false,"Bag changed; try again" end
    if type(item.Quantity)~="number" or item.Quantity<1 then return false,"Invalid stack" end
    if worn(inv,item) then return false,"Unequip the item first" end
    for other=1,Config.SlotCount do
        if other~=index and inv.ActionBarItems[tostring(other)]
            and inv.ActionBarItems[tostring(other)].ItemId==itemId then
            return false,"This item is already on the action bar"
        end
    end
    local n,raw=findRaw(inv,bagId,bagSlot,itemId,instanceId)
    if not n or not raw then return false,"Bag item changed" end
    -- No yields between ownership changes. The player profile saves both tables.
    table.remove(inv.Items,n)
    inv.ActionBarItems[key]=rawCopy(raw)
    slots[key]=itemId
    slots[index]=nil
    return true,"Item moved to action bar"
end
function Storage:Clear(player,index,slots)
    if not valid(index) then return false,"Invalid action slot" end
    local inv=get(player)
    if not inv then return false,"Inventory loading" end
    local key=tostring(index)
    local record=type(inv.ActionBarItems)=="table" and inv.ActionBarItems[key]
    if record then
        local putInto=nil
        local def=Definitions.Get(record.ItemId)
        if def and def.Type~="Weapon" and def.Type~="Armor" and not record.InstanceId then
            for _,entry in ipairs(inv.Items) do
                if entry.ItemId==record.ItemId and not entry.InstanceId and entry.BagId~=nil
                    and type(entry.Quantity)=="number" and entry.Quantity+record.Quantity<=999999 then
                    putInto=entry;break
                end
            end
        end
        local bagId,bagSlot
        if not putInto then
            bagId,bagSlot=Inventory:GetFreeBagSlot(player)
            if not bagId then return false,"Your bag is full. Free a slot before removing this item." end
        end
        if putInto then
            putInto.Quantity+=record.Quantity
        else
            local restored=rawCopy(record)
            restored.BagId=bagId
            restored.BagSlot=bagSlot
            table.insert(inv.Items,restored)
        end
        inv.ActionBarItems[key]=nil
    end
    slots[key]=nil
    slots[index]=nil
    return true,"Returned to bag"
end
function Storage:Drink(player,index,itemId)
    local inv=get(player)
    local key=tostring(index)
    local rec=inv and type(inv.ActionBarItems)=="table" and inv.ActionBarItems[key]
    if not rec or rec.ItemId~=itemId or type(rec.Quantity)~="number"
        or rec.Quantity<1 then return false,"No potion in action slot" end
    rec.Quantity-=1
    if rec.Quantity==0 then inv.ActionBarItems[key]=nil end
    return true
end
function Storage:EquipWeapon(player,index,slots)
    local inv=get(player)
    if not inv then return false,"Inventory loading" end
    local key=tostring(index)
    local rec=type(inv.ActionBarItems)=="table" and inv.ActionBarItems[key]
    if not rec then
        return false,self:EquippedShortcut(player,slots[key])
            and "Weapon already equipped" or "Weapon missing from action bar"
    end
    local def=Definitions.Get(rec.ItemId)
    if not def or def.Type~="Weapon" or type(rec.InstanceId)~="string" then
        return false,"Only weapon items can be equipped this way" end
    local bagId,bagSlot=Inventory:GetFreeBagSlot(player)
    if not bagId then return false,"Bag full: free one slot to equip this weapon" end
    local restore=rawCopy(rec)
    restore.BagId=bagId;restore.BagSlot=bagSlot
    -- EquipService is server-authoritative and returns the replaced weapon to
    -- exactly the freed bag slot, so ownership is never duplicated.
    table.insert(inv.Items,restore)
    inv.ActionBarItems[key]=nil
    local ok,slot=Equipment:Equip(player,restore.InstanceId)
    if not ok then
        for n,entry in ipairs(inv.Items) do
            if entry==restore then table.remove(inv.Items,n) break end
        end
        inv.ActionBarItems[key]=rawCopy(rec)
        return false,tostring(slot)
    end
    local success,err=pcall(function() Combat:Refresh(player) end)
    if not success then warn("[Lumia - Action Bar] Weapon visual refresh: "..tostring(err)) end
    return true,"Equipped "..tostring(def.DisplayName or rec.ItemId)
end
function Storage:EquipmentSnapshot(player)
    local inv=get(player)
    local result={}
    if not inv then return result end
    for slot,instance in pairs(inv.Equipment) do
        for _,record in ipairs(inv.Items) do
            if record.InstanceId==instance then
                local public=Snapshot.PublicItem(record)
                if public then public.InstanceId=nil; result[slot]=public end
                break
            end
        end
    end
    return result
end
return Storage
