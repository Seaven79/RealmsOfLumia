-- REALMS OF LUMIA - STEP 13.2 DRAG & DROP
-- Single shared client controller for bag <-> character sheet drag/drop.
-- Client predicts visuals; server owns equip/unequip and bag ordering.
-- Clicking without dragging NEVER sends an equip request.

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local Shared = ReplicatedStorage:WaitForChild("Lumia"):WaitForChild("Shared")
local ItemDefinitions = require(Shared:WaitForChild("Items"):WaitForChild("ItemDefinitions"))
local ItemIcons = require(Shared:WaitForChild("Items"):WaitForChild("ItemIcons"))
local EquipmentRules = require(Shared:WaitForChild("Equipment"):WaitForChild("EquipmentRules"))
local EquipmentClient = require(script.Parent:WaitForChild("EquipmentClient"))

local DragDrop = {}
local sources = {}
local pending = nil
local dragging = false
local busy = false
local threshold = 8
local resultEvent = Instance.new("BindableEvent")
local startedEvent = Instance.new("BindableEvent")
local windowsEvent = Instance.new("BindableEvent")
local finishedEvent = Instance.new("BindableEvent")
local deleteRequestEvent = Instance.new("BindableEvent")
DragDrop.Result = resultEvent.Event -- (ok, message, sourceKind)
DragDrop.Started = startedEvent.Event -- (sourceKind, sourceFrame)
DragDrop.Finished = finishedEvent.Event -- (sourceKind, sourceFrame)
DragDrop.WindowsChanged = windowsEvent.Event
DragDrop.DeleteRequested = deleteRequestEvent.Event -- (item, bagSlotCoordinates)

local gui = Instance.new("ScreenGui")
gui.Name = "LumiaDragOverlay"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Global
gui.DisplayOrder = 100
gui.Parent = playerGui

-- While dragging, ONLY the item icon follows the cursor.
-- The original inventory slot hides its icon until the drag ends.
local ghost = Instance.new("Frame")
ghost.Name = "DraggedItemIcon"
ghost.Size = UDim2.fromOffset(44, 44)
ghost.BackgroundTransparency = 1
ghost.BorderSizePixel = 0
ghost.Visible = false
ghost.Active = false
ghost.ZIndex = 110
ghost.Parent = gui

local preview = Instance.new("ImageLabel")
preview.Name = "Image"
preview.Size = UDim2.fromScale(1, 1)
preview.BackgroundTransparency = 1
preview.ScaleType = Enum.ScaleType.Fit
preview.Visible = false
preview.ZIndex = 111
preview.Parent = ghost

-- Only used when an item has no image asset; no item name follows the mouse.
local symbol = Instance.new("TextLabel")
symbol.Name = "SymbolFallback"
symbol.Size = UDim2.fromScale(1, 1)
symbol.BackgroundTransparency = 1
symbol.Font = Enum.Font.GothamBold
symbol.TextSize = 30
symbol.TextColor3 = Color3.fromRGB(227, 180, 94)
symbol.Visible = false
symbol.ZIndex = 111
symbol.Parent = ghost

-- The old independent green overlay had its own ScreenGui coordinates;
-- under different insets or UIScale it could appear over Legs while the
-- valid target was Main Hand. Stroke the actual target slot instead.
local highlightStroke = Instance.new("UIStroke")
highlightStroke.Name = "LumiaValidDropStroke"
highlightStroke.Color = Color3.fromRGB(97, 217, 154)
highlightStroke.Thickness = 3
highlightStroke.Transparency = 0
highlightStroke.Enabled = false
local highlightedFrame = nil
local highlightedOriginalColor = nil

local function setHighlight(target)
    local newFrame = target and target.frame or nil
    if highlightedFrame == newFrame then return end
    if highlightedFrame and highlightedFrame.Parent and highlightedOriginalColor then
        highlightedFrame.BackgroundColor3 = highlightedOriginalColor
    end
    highlightStroke.Parent = nil
    highlightStroke.Enabled = false
    highlightedFrame = newFrame
    highlightedOriginalColor = nil
    if newFrame then
        -- Tint the actual valid drop surface GREEN, not a detached overlay.
        -- Save its original color so it is restored on leave/drop.
        highlightedOriginalColor = newFrame.BackgroundColor3
        newFrame.BackgroundColor3 = Color3.fromRGB(32, 91, 63)
        highlightStroke.Parent = newFrame
        highlightStroke.Enabled = true
    end
end

local function isVisible(frame)
    if not frame or not frame.Parent then return false end
    local node = frame
    while node do
        if node:IsA("GuiObject") and not node.Visible then return false end
        if node:IsA("ScreenGui") and not node.Enabled then return false end
        node = node.Parent
    end
    return true
end

local function validTarget(entry)
    if not pending or not entry or not isVisible(entry.frame) then return false end
    if entry.kind == "External" then
        local ok,accepted=pcall(entry.accept,pending.item,pending.slotKey)
        return pending.kind == "Bag" and ok and accepted==true
    end
    if pending.kind == "Bag" then
        if entry.kind == "Bag" then
            local from, to = pending.slotKey, entry.slotKey
            return type(from) == "table" and type(to) == "table"
                and (from.BagId ~= to.BagId or from.Slot ~= to.Slot)
        end
        if entry.kind == "Equipment" then
            if type(pending.item.InstanceId) ~= "string" then return false end
            local definition = ItemDefinitions.Get(pending.item.ItemId)
            return EquipmentRules.GetSlot(definition) == entry.slotKey
        end
    end
    if pending.kind == "Equipment" then
        return entry.kind == "Bag" and entry.getItem() == nil
    end
    return false
end

local function findDropTarget(mouse)
    -- Hit-test the REAL GuiObjects under the cursor. Unlike a separately
    -- positioned overlay, this respects screen insets and parent UIScale.
    -- Descendants count (the image or text inside a slot might be hit).
    -- GetMouseLocation includes the top bar; GetGuiObjectsAtPosition expects
    -- coordinates after the GUI inset. Convert before hit testing.
    local inset = GuiService:GetGuiInset()
    local hits = playerGui:GetGuiObjectsAtPosition(
        math.floor(mouse.X - inset.X), math.floor(mouse.Y - inset.Y)
    )
    -- ScreenGui.IgnoreGuiInset=true for merchant and bag: absolute GUI bounds
    -- avoid the built-in 36px top-bar mismatch when dropping into an external tray.
    for _,entry in ipairs(sources) do
        if entry.kind=="External" and validTarget(entry) then
            local pos,size=entry.frame.AbsolutePosition,entry.frame.AbsoluteSize
            if mouse.X>=pos.X and mouse.X<=pos.X+size.X
                and mouse.Y>=pos.Y and mouse.Y<=pos.Y+size.Y then
                return entry
            end
        end
    end
    for _, hit in ipairs(hits) do
        for _, entry in ipairs(sources) do
            if validTarget(entry)
                and (hit == entry.frame or hit:IsDescendantOf(entry.frame)) then
                return entry
            end
        end
    end
    return nil
end

-- Outside-window drop means the unobstructed WORLD view, not a blank
-- region of another open UI panel. Never destroy by dropping over any UI.
local function isOverVisibleUi(mouse)
    local inset = GuiService:GetGuiInset()
    local hits = playerGui:GetGuiObjectsAtPosition(
        math.floor(mouse.X - inset.X), math.floor(mouse.Y - inset.Y)
    )
    for _, hit in ipairs(hits) do
        if not hit:IsDescendantOf(gui) then
            local node = hit
            while node and node ~= playerGui do
                if node:IsA("GuiObject") and isVisible(node) then
                    local name = node.Name:lower()
                    if name == "window" or name == "characterwindow"
                        or name == "lootwindow" or name == "panel"
                        or name == "backdrop" or name:find("dialog", 1, true)
                        or node:IsA("TextButton") or node:IsA("ImageButton")
                        or node:IsA("TextBox") or node:IsA("ScrollingFrame")
                        or (node.BackgroundTransparency < 0.92
                            and node.AbsoluteSize.X > 16
                            and node.AbsoluteSize.Y > 16) then
                        return true
                    end
                end
                node = node.Parent
            end
        end
    end
    return false
end

local function fillGhost(item)
    local imageId, fallbackSymbol = ItemIcons.Resolve(item)
    preview.Visible = imageId ~= nil
    preview.Image = imageId or ""
    symbol.Visible = imageId == nil
    symbol.Text = fallbackSymbol or "?"
end

local function moveGhost(mouse)
    local bounds = gui.AbsoluteSize
    ghost.Position = UDim2.fromOffset(
        math.clamp(mouse.X + 10, 0, math.max(0, bounds.X - 44)),
        math.clamp(mouse.Y + 10, 0, math.max(0, bounds.Y - 44))
    )
    setHighlight(findDropTarget(mouse))
end

function DragDrop.IsDragging()
    return dragging
end

function DragDrop.IsDraggingSource(frame)
    return dragging and pending ~= nil and pending.frame == frame
end

function DragDrop.NotifyWindowsChanged()
    windowsEvent:Fire()
end

-- Bag and character sheet both register their slots here, using live getters.
-- A clicked slot creates a pending drag only. Moving 8 pixels starts dragging.
function DragDrop.RegisterSlot(frame, kind, getItem, slotKey)
    assert(kind == "Bag" or kind == "Equipment", "Unknown slot type")
    assert(kind ~= "Bag" or type(slotKey) == "table", "Bag slot coordinates required")
    local entry = { frame = frame, kind = kind, getItem = getItem, slotKey = slotKey }
    table.insert(sources, entry)
    frame.InputBegan:Connect(function(input)
        if input.UserInputType ~= Enum.UserInputType.MouseButton1
            or busy or pending then return end
        local item = getItem()
        if type(item) ~= "table" or type(item.ItemId) ~= "string" then return end
        pending = { kind = kind, frame = frame, item = item, slotKey = slotKey,
            start = UserInputService:GetMouseLocation() }
        dragging = false
    end)
end

-- Public interface for merchant sell trays, future crafting benches and mail slots.
-- Never grants items or currency: onDrop must invoke a validated server remote.
function DragDrop.RegisterExternalTarget(frame,accept,onDrop)
    assert(frame and frame:IsA("GuiObject"),"Expected a GuiObject drop target")
    assert(type(accept)=="function" and type(onDrop)=="function","External target requires callbacks")
    local entry={frame=frame,kind="External",accept=accept,onDrop=onDrop}
    table.insert(sources,entry)
    return function()
        for i,e in ipairs(sources) do
            if e==entry then table.remove(sources,i) break end
        end
    end
end

UserInputService.InputChanged:Connect(function(input)
    if not pending or input.UserInputType ~= Enum.UserInputType.MouseMovement then return end
    local mouse = UserInputService:GetMouseLocation()
    if not dragging and (mouse - pending.start).Magnitude >= threshold then
        dragging = true
        player:SetAttribute("LumiaDraggingItem", true)
        fillGhost(pending.item)
        ghost.Visible = true
        startedEvent:Fire(pending.kind, pending.frame)
    end
    if dragging then
        moveGhost(mouse)
    end
end)

-- Keep highlight over a target even if a UIScale or window position changes.
RunService.RenderStepped:Connect(function()
    if dragging and pending then
        moveGhost(UserInputService:GetMouseLocation())
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType ~= Enum.UserInputType.MouseButton1 or not pending then return end
    local held = pending
    local wasDragging = dragging
    local target = wasDragging and findDropTarget(UserInputService:GetMouseLocation()) or nil
    pending = nil
    dragging = false
    player:SetAttribute("LumiaDraggingItem", false)
    ghost.Visible = false
    setHighlight(nil)
    if wasDragging then
        finishedEvent:Fire(held.kind, held.frame)
    end
    if not wasDragging then return end -- ordinary click: no equipment action
    if not target then
        -- Bag item released over the game WORLD: offer permanent deletion.
        -- Never do this for an equipped item or over any visible UI.
        if held.kind == "Bag" and not isOverVisibleUi(UserInputService:GetMouseLocation()) then
            deleteRequestEvent:Fire(held.item, held.slotKey)
            return -- confirmation UI + server checks still required.
        end
        local instruction = held.kind == "Bag"
            and "Drop outside UI to destroy, or onto a valid slot"
            or "Drop on an empty bag slot (B)"
        resultEvent:Fire(false, instruction, held.kind)
        return
    end
    if busy then return end
    if target.kind=="External" then
        busy=true
        task.spawn(function()
            local ok,accepted,message=pcall(target.onDrop,held.item,held.slotKey)
            busy=false
            resultEvent:Fire(ok and accepted==true,
                ok and tostring(message or (accepted and "Transaction complete" or "Rejected"))
                    or "Shop interaction failed",held.kind)
        end)
        return
    end
    busy = true
    -- Start a local visual prediction SYNCHRONOUSLY on mouse release.
    -- EquipmentClient sends the actual request asynchronously; the server
    -- still decides ownership, level, and equipment compatibility.
    local started, reason
    if held.kind == "Bag" and target.kind == "Bag" then
        started, reason = EquipmentClient.RequestMoveBag(
            held.slotKey.BagId, held.slotKey.Slot,
            target.slotKey.BagId, target.slotKey.Slot)
    elseif held.kind == "Bag" then
        started, reason = EquipmentClient.RequestEquip(held.item, target.slotKey)
    else
        started, reason = EquipmentClient.RequestUnequip(
            held.item, held.slotKey, target.slotKey.BagId, target.slotKey.Slot)
    end
    if not started then
        busy = false
        resultEvent:Fire(false, tostring(reason), held.kind)
    end
end)

EquipmentClient.Completed:Connect(function(ok, message, sourceKind)
    busy = false
    resultEvent:Fire(ok, message, sourceKind)
end)

print("[Lumia - Equipment Drag Drop] Drag and drop controller ready - instant visual prediction")
return DragDrop
