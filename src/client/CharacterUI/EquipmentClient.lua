-- REALMS OF ETERNIA - FAST PREDICTED EQUIPMENT + SAVED BAG REARRANGEMENT
-- The client predicts only how items LOOK. Server responses are authoritative.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local eternia = ReplicatedStorage:WaitForChild("Eternia")
local equipmentNetwork = eternia:WaitForChild("EquipmentNetwork")
local inventoryNetwork = eternia:WaitForChild("InventoryNetwork")
local equipRemote = equipmentNetwork:WaitForChild("Equip")
local unequipRemote = equipmentNetwork:WaitForChild("Unequip")
local moveRemote = inventoryNetwork:WaitForChild("MoveBagItem")

local EquipmentClient = {}
local bagChanged = Instance.new("BindableEvent")
local equipmentChanged = Instance.new("BindableEvent")
local completed = Instance.new("BindableEvent")
local needsRefresh = Instance.new("BindableEvent")
EquipmentClient.BagChanged = bagChanged.Event
EquipmentClient.EquipmentChanged = equipmentChanged.Event
EquipmentClient.Completed = completed.Event -- (ok, message, sourceKind)
EquipmentClient.NeedsRefresh = needsRefresh.Event

local confirmedBag = nil -- { Items = {...}, Bags = {...}, ViewMode = ..., SelectedBagId = ... }
local confirmedEquipment = nil
local pending = nil
local revision = 0

local function normalizeBag(raw)
    if type(raw) ~= "table" then return nil end
    -- Older servers returned a compact array; the new bridge returns an object.
    if type(raw.Items) == "table" and type(raw.Bags) == "table" then return raw end
    return nil
end
function EquipmentClient.GetRevision() return revision end
function EquipmentClient.IsBusy() return pending ~= nil end

function EquipmentClient.UpdateBagSnapshot(raw, beganRevision)
    local snapshot = normalizeBag(raw)
    if not snapshot or pending then return false end
    if beganRevision ~= nil and beganRevision ~= revision then return false end
    confirmedBag = snapshot
    bagChanged:Fire()
    return true
end
function EquipmentClient.UpdateEquipmentSnapshot(snapshot, beganRevision)
    if type(snapshot) ~= "table" or pending then return false end
    if beganRevision ~= nil and beganRevision ~= revision then return false end
    confirmedEquipment = snapshot
    equipmentChanged:Fire()
    return true
end

local function cloneItems(items)
    local copy = {}
    for _, item in ipairs(items) do table.insert(copy, table.clone(item)) end
    return copy
end
local function findAt(items, bagId, bagSlot)
    for index, item in ipairs(items) do
        if item.BagId == bagId and item.BagSlot == bagSlot then
            return item, index
        end
    end
    return nil, nil
end

function EquipmentClient.GetBagView()
    local base = confirmedBag or { Items = {}, Bags = {} }
    local items = cloneItems(base.Items)
    if pending then
        if pending.Kind == "Move" then
            local source = findAt(items, pending.FromBag, pending.FromSlot)
            local destination = findAt(items, pending.ToBag, pending.ToSlot)
            if source then
                source.BagId, source.BagSlot = pending.ToBag, pending.ToSlot
                if destination then
                    destination.BagId, destination.BagSlot = pending.FromBag, pending.FromSlot
                end
            end
        elseif pending.Kind == "Equip" then
            local source, sourceIndex = findAt(items, pending.FromBag, pending.FromSlot)
            if sourceIndex then table.remove(items, sourceIndex) end
            local oldItem = confirmedEquipment and confirmedEquipment[pending.Slot]
            if source and oldItem then
                local copy = table.clone(oldItem)
                copy.BagId, copy.BagSlot = pending.FromBag, pending.FromSlot
                table.insert(items, copy)
            end
        elseif pending.Kind == "Unequip" then
            local worn = confirmedEquipment and confirmedEquipment[pending.Slot]
            if worn then
                local copy = table.clone(worn)
                copy.BagId, copy.BagSlot = pending.ToBag, pending.ToSlot
                table.insert(items, copy)
            end
        end
    end
    return {
        Items = items, Bags = base.Bags,
        ViewMode = base.ViewMode, SelectedBagId = base.SelectedBagId,
    }
end
function EquipmentClient.GetEquipmentView()
    local equipment = type(confirmedEquipment) == "table"
        and table.clone(confirmedEquipment) or {}
    if pending then
        if pending.Kind == "Equip" then
            equipment[pending.Slot] = pending.Item
        elseif pending.Kind == "Unequip" then
            equipment[pending.Slot] = nil
        end
    end
    return equipment
end

local function send(action)
    if pending then return false, "Wait for the previous item move" end
    pending = action
    revision += 1
    bagChanged:Fire()
    equipmentChanged:Fire() -- Instant, while the network call is pending.

    task.spawn(function()
        local startedAt = os.clock()
        local success, response = pcall(function()
            if action.Kind == "Equip" then
                return equipRemote:InvokeServer(action.Item.InstanceId)
            elseif action.Kind == "Unequip" then
                return unequipRemote:InvokeServer(action.Slot, action.ToBag, action.ToSlot)
            else
                return moveRemote:InvokeServer({
                    FromBag = action.FromBag, FromSlot = action.FromSlot,
                    ToBag = action.ToBag, ToSlot = action.ToSlot,
                })
            end
        end)
        local accepted = success and type(response) == "table"
            and response.Ok == true
        local snap = accepted and normalizeBag(response.Bag)
        local hasEquipment = action.Kind == "Move"
            or (accepted and type(response.Equipment) == "table")
        if snap then
            confirmedBag = snap
            if action.Kind ~= "Move" and hasEquipment then
                confirmedEquipment = response.Equipment
            end
        end
        pending = nil
        revision += 1
        bagChanged:Fire()
        equipmentChanged:Fire() -- Confirm or undo the predicted local move.
        local ms = math.floor((os.clock() - startedAt) * 1000 + 0.5)
        print("[Eternia] " .. action.Kind .. " server reply " .. ms .. "ms")
        if not accepted or not snap or not hasEquipment then
            needsRefresh:Fire()
        end
        local message
        if accepted then
            message = action.Kind == "Move" and "Bag item moved"
                or action.Kind == "Equip" and "Equipped" or "Returned to bag"
        elseif not success then
            message = "Connection failed; item restored"
        else
            message = type(response) == "table"
                and tostring(response.Error or "Request rejected") or "No server response"
        end
        completed:Fire(accepted, message,
            action.Kind == "Unequip" and "Equipment" or "Bag")
    end)
    return true
end

function EquipmentClient.RequestEquip(item, slot)
    if type(item) ~= "table" or type(item.InstanceId) ~= "string"
        or type(item.BagId) ~= "number" or type(item.BagSlot) ~= "number"
        or type(slot) ~= "string" then return false, "Invalid equipment request" end
    return send({ Kind = "Equip", Item = item, Slot = slot,
        FromBag = item.BagId, FromSlot = item.BagSlot })
end
function EquipmentClient.RequestUnequip(item, slot, toBag, toSlot)
    if type(item) ~= "table" or type(slot) ~= "string"
        or type(toBag) ~= "number" or type(toSlot) ~= "number" then
        return false, "Invalid destination" end
    return send({ Kind = "Unequip", Item = item, Slot = slot,
        ToBag = toBag, ToSlot = toSlot })
end
function EquipmentClient.RequestMoveBag(fromBag, fromSlot, toBag, toSlot)
    if type(fromBag) ~= "number" or type(fromSlot) ~= "number"
        or type(toBag) ~= "number" or type(toSlot) ~= "number" then
        return false, "Invalid bag move" end
    if fromBag == toBag and fromSlot == toSlot then
        return false, "Already in that slot" end
    return send({ Kind = "Move", FromBag = fromBag, FromSlot = fromSlot,
        ToBag = toBag, ToSlot = toSlot })
end
return EquipmentClient
