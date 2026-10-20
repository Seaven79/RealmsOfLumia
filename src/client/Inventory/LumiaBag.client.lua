-- REALMS OF LUMIA - FIVE BAG POSITIONS / STARTER BACKPACK V1
-- 1 equipped 8-slot starter backpack, 4 empty bag-equipment positions.
-- Selected Bag and All Bags viewing modes; slot-position drag/drop/swap.
-- Client view moves immediately; server validates and persists the result.
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local lumia = ReplicatedStorage:WaitForChild("Lumia")
local ItemIcons = require(lumia:WaitForChild("Shared"):WaitForChild("Items"):WaitForChild("ItemIcons"))
local ItemPreview = require(script.Parent.Parent:WaitForChild("UI"):WaitForChild("LumiaItemPreview"))
local Currency = require(lumia:WaitForChild("Shared"):WaitForChild("Commerce"):WaitForChild("LumiaCurrency"))
local Coins=require(script.Parent.Parent:WaitForChild("UI"):WaitForChild("LumiaCoinUI"))
local ShopBridge=require(script.Parent.Parent:WaitForChild("UI"):WaitForChild("MerchantUIBridge"))
local components = script.Parent.Parent:WaitForChild("UI")
local LumiaModalState = require(components:WaitForChild("LumiaModalState"))
local ItemTooltip = require(components:WaitForChild("ItemTooltip"))
local BagIcon = require(components:WaitForChild("BagIcon"))
local EquipmentClient = require(components:WaitForChild("EquipmentClient"))
local DragDrop = require(components:WaitForChild("EquipmentDragDrop"))
local ItemDeleteDialog = require(components:WaitForChild("ItemDeleteDialog"))
local network = lumia:WaitForChild("InventoryNetwork")
local request = network:WaitForChild("GetInventory")
local preferenceRequest = network:WaitForChild("SetBagView")
local discardRequest = network:WaitForChild("DiscardBagItem")

local gui = Instance.new("ScreenGui")
gui.Name = "LumiaBag"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 20
gui.Parent = player:WaitForChild("PlayerGui")

local WIDTH, HEIGHT = 282, 348
local basePosition = UDim2.new(0.5, -WIDTH / 2, 0.5, -HEIGHT / 2)
local window = Instance.new("Frame")
window.Name = "Window"
window.Size = UDim2.fromOffset(WIDTH, HEIGHT)
window.Position = basePosition
window.BackgroundColor3 = Color3.fromRGB(24, 22, 22)
window.BorderSizePixel = 0
window.Visible = false
window.Parent = gui
Instance.new("UICorner", window).CornerRadius = UDim.new(0, 7)
local outline = Instance.new("UIStroke")
outline.Thickness = 2
outline.Color = Color3.fromRGB(110, 87, 54)
outline.Parent = window

local function label(parent, name, text, x, y, w, h, size, color, bold)
    local node = Instance.new("TextLabel")
    node.Name = name
    node.BackgroundTransparency = 1
    node.Text = text
    node.Position = UDim2.fromOffset(x, y)
    node.Size = UDim2.fromOffset(w, h)
    node.Font = bold and Enum.Font.GothamBold or Enum.Font.Gotham
    node.TextSize = size
    node.TextColor3 = color
    node.TextXAlignment = Enum.TextXAlignment.Left
    node.TextTruncate = Enum.TextTruncate.AtEnd
    node.Parent = parent
    return node
end

local title = label(window, "Title", "ADVENTURER'S BAGS", 12, 6, 228, 30,
    14, Color3.fromRGB(224, 194, 130), true)
local close = Instance.new("TextButton")
close.Name = "Close"
close.Position = UDim2.fromOffset(WIDTH - 31, 7)
close.Size = UDim2.fromOffset(25, 25)
close.BackgroundColor3 = Color3.fromRGB(58, 43, 39)
close.TextColor3 = Color3.fromRGB(230, 215, 190)
close.Text = "X"
close.TextSize = 13
close.Font = Enum.Font.GothamBold
close.Parent = window
Instance.new("UICorner", close).CornerRadius = UDim.new(0, 4)

label(window, "BagSlotsHeading", "BAG POSITIONS (1 / 5 EQUIPPED)",
    13, 39, WIDTH - 26, 14, 10, Color3.fromRGB(169, 158, 143), true)
local bagButtons = {}
for i = 1, 5 do
    local button = Instance.new("TextButton")
    button.Name = "BagPosition" .. i
    button.Position = UDim2.fromOffset(13 + (i - 1) * 51, 59)
    button.Size = UDim2.fromOffset(45, 45)
    button.BackgroundColor3 = Color3.fromRGB(30, 44, 64)
    button.Text = "" -- custom backpack icon + bag number are child visuals
    button.AutoButtonColor = false
    button.Parent = window
    Instance.new("UICorner", button).CornerRadius = UDim.new(0, 5)
    local stroke = Instance.new("UIStroke")
    stroke.Thickness = 1
    stroke.Color = Color3.fromRGB(59, 74, 96)
    stroke.Parent = button
    local icon = BagIcon.Attach(button, i)
    bagButtons[i] = { Button = button, Border = stroke, Icon = icon }
end

local mode = "selected"
local selectedBag = 1
local receivedPreferences = false
local preferenceVersion = 0
local function requestPreferences()
    preferenceVersion += 1
    local version = preferenceVersion
    task.delay(0.35, function()
        if version ~= preferenceVersion then return end
        local requestedMode, requestedBag = mode, selectedBag
        task.spawn(function()
            local ok, saved = pcall(function()
                return preferenceRequest:InvokeServer(requestedMode, requestedBag)
            end)
            if not ok or not saved then
                warn("[Lumia - Lumia Bag] Bag view preference was not saved")
            end
        end)
    end)
end
local selectedButton, allButton
local function makeModeButton(name, text, x)
    local button = Instance.new("TextButton")
    button.Name = name
    button.Position = UDim2.fromOffset(x, 115)
    button.Size = UDim2.fromOffset(121, 28)
    button.BackgroundColor3 = Color3.fromRGB(42, 39, 36)
    button.Text = text
    button.TextColor3 = Color3.fromRGB(205, 193, 171)
    button.TextSize = 11
    button.Font = Enum.Font.GothamBold
    button.AutoButtonColor = false
    button.Parent = window
    Instance.new("UICorner", button).CornerRadius = UDim.new(0, 5)
    return button
end
selectedButton = makeModeButton("SelectedBagMode", "SELECTED BAG", 13)
allButton = makeModeButton("AllBagsMode", "ALL BAGS", 146)

local scroll = Instance.new("ScrollingFrame")
scroll.Name = "BagsContent"
scroll.Position = UDim2.fromOffset(12, 151)
scroll.Size = UDim2.fromOffset(WIDTH - 24, 167)
scroll.BackgroundTransparency = 1
scroll.BorderSizePixel = 0
scroll.ScrollBarThickness = 4
scroll.ScrollBarImageColor3 = Color3.fromRGB(125, 106, 75)
scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
scroll.Parent = window
local contentsLayout = Instance.new("UIListLayout")
contentsLayout.Padding = UDim.new(0, 8)
contentsLayout.SortOrder = Enum.SortOrder.LayoutOrder
contentsLayout.Parent = scroll

local emptyMessage = label(scroll, "EmptyBagMessage", "No bag equipped in this position.",
    7, 0, 242, 130, 12, Color3.fromRGB(181, 162, 128))
emptyMessage.TextWrapped = true
emptyMessage.TextXAlignment = Enum.TextXAlignment.Center
emptyMessage.LayoutOrder = 1
emptyMessage.Visible = false

local footer = label(window, "Footer", "0 / 8 slots", 13, HEIGHT - 29,
    WIDTH - 122, 20, 11, Color3.fromRGB(167, 153, 126))
local wallet=Coins.Wallet(window,Currency,0,true)
wallet.Position=UDim2.fromOffset(WIDTH-164,HEIGHT-28)
-- Denominations are published by Coins.Wallet itself from Currency.Tiers, so
-- there is no second copy of the coin names to fall out of date here.
-- Drag an item outside all visible UI windows to request destruction.
-- No trash button: shared DragDrop emits DeleteRequested on a world-view drop.
local tooltip = ItemTooltip.new(gui)
local statusSerial = 0
local defaultFooter = "0 / 8 slots"
local function showStatus(text)
    statusSerial += 1
    local token = statusSerial
    footer.Text = tostring(text)
    task.delay(2, function()
        if token == statusSerial then
            statusSerial = 0
            footer.Text = defaultFooter
        end
    end)
end
local rarityColors = {
    Poor = Color3.fromRGB(150, 150, 150),
    Common = Color3.fromRGB(140, 132, 118),
    Uncommon = Color3.fromRGB(65, 170, 90),
    Rare = Color3.fromRGB(70, 125, 230),
    Epic = Color3.fromRGB(165, 80, 215),
    Legendary = Color3.fromRGB(230, 150, 35),
}

-- Widgets are created only once for each equipped bag position/slot.
-- Switching views hides/shows them, keeping the drag controller registered.
local bagSections = {}
local hoveredSlot = nil
local function setSlotVisualVisible(slot, visible)
    for _, child in ipairs(slot:GetChildren()) do
        if child.Name == "ItemVisual" or child.Name == "Quantity" then
            child.Visible = visible
        end
    end
end
local function addIcon(slot, item)
    if ItemPreview.Attach(slot,item.ItemId) then return end
    local imageId, symbol = ItemIcons.Resolve(item)
    if imageId then
        local image = Instance.new("ImageLabel")
        image.Name = "ItemVisual"
        image.BackgroundTransparency = 1
        image.Size = UDim2.fromScale(0.85, 0.85)
        image.Position = UDim2.fromScale(0.075, 0.075)
        image.ScaleType = Enum.ScaleType.Fit
        image.Image = imageId
        image.Parent = slot
    else
        local glyph = Instance.new("TextLabel")
        glyph.Name = "ItemVisual"
        glyph.BackgroundTransparency = 1
        glyph.Size = UDim2.fromScale(1, 1)
        glyph.Font = Enum.Font.GothamBold
        glyph.TextSize = 29
        glyph.TextColor3 = Color3.fromRGB(211, 188, 139)
        glyph.Text = symbol or "?"
        glyph.Parent = slot
    end
end
local function ensureSection(bag)
    local bagId, capacity = bag.BagId, bag.Capacity
    if capacity < 1 then return end
    local existing = bagSections[bagId]
    if existing then return existing end
    local cols, rowHeight = 4, 57
    local rows = math.ceil(capacity / cols)
    local section = Instance.new("Frame")
    section.Name = "Bag" .. bagId .. "Contents"
    section.Size = UDim2.new(1, -5, 0, 27 + rows * rowHeight)
    section.BackgroundTransparency = 1
    section.LayoutOrder = bagId
    section.Parent = scroll
    local heading = label(section, "BagName", bag.Name or "Bag", 1, 1, 242, 21,
        12, Color3.fromRGB(224, 194, 130), true)
    local widgets = {}
    for bagSlot = 1, capacity do
        local col = (bagSlot - 1) % 4
        local row = math.floor((bagSlot - 1) / 4)
        local slot = Instance.new("TextButton")
        slot.Name = "Bag" .. bagId .. "Slot" .. bagSlot
        slot.Size = UDim2.fromOffset(49, 49)
        slot.Position = UDim2.fromOffset(7 + col * 59, 27 + row * rowHeight)
        slot.Text = ""
        slot.AutoButtonColor = false
        slot.BackgroundColor3 = Color3.fromRGB(37, 35, 33)
        slot.BorderSizePixel = 0
        slot.Active = true
        slot.Parent = section
        Instance.new("UICorner", slot).CornerRadius = UDim.new(0, 4)
        local border = Instance.new("UIStroke")
        border.Name = "SlotBorder"
        border.Thickness = 1
        border.Color = Color3.fromRGB(79, 69, 54)
        border.Parent = slot
        local number = label(slot, "Number", tostring(bagSlot), 0, 0,
            49, 49, 12, Color3.fromRGB(78, 73, 68))
        number.TextXAlignment = Enum.TextXAlignment.Center
        local widget = { Frame = slot, Border = border, Number = number, Item = nil,
            BagId = bagId, Slot = bagSlot }
        widgets[bagSlot] = widget
        -- Classic vendor behaviour: RIGHT-click a bag item while the shop is open
        -- sells that stack. Left-click stays harmless so inspecting or dragging
        -- can never cost the player an item by accident.
        slot.MouseButton2Click:Connect(function()
            if DragDrop.IsDragging() then return end
            if not ShopBridge.IsOpen() then return end
            local item = widget.Item
            if not item or type(item.ItemId) ~= "string" then return end
            ShopBridge.SellStack(item, { BagId = bagId, Slot = bagSlot })
        end)
        slot.MouseEnter:Connect(function()
            hoveredSlot = widget
            if widget.Item and not DragDrop.IsDragging() then
                tooltip:Show(widget.Item)
            end
        end)
        slot.MouseLeave:Connect(function()
            if hoveredSlot == widget then hoveredSlot = nil end
            tooltip:Hide()
        end)
        DragDrop.RegisterSlot(slot, "Bag", function()
            return widget.Item
        end, { BagId = bagId, Slot = bagSlot })
    end
    local record = { Frame = section, Widgets = widgets, Heading = heading }
    bagSections[bagId] = record
    return record
end

local function bagInfo(snapshot, bagId)
    for _, info in ipairs(snapshot.Bags or {}) do
        if info.BagId == bagId then return info end
    end
    return { BagId = bagId, Equipped = false, Capacity = 0, Name = "Empty Bag Slot" }
end
local function refreshVisualMode(snapshot)
    for i, widget in ipairs(bagButtons) do
        local info = bagInfo(snapshot, i)
        local isSelected = mode == "selected" and selectedBag == i
        -- Highlight the actual bag button, not an independently positioned overlay.
        widget.Button.BackgroundColor3 = isSelected
            and Color3.fromRGB(32, 88, 62) or Color3.fromRGB(30, 44, 64)
        widget.Border.Color = isSelected
            and Color3.fromRGB(80, 223, 138) or Color3.fromRGB(59, 74, 96)
        widget.Border.Thickness = isSelected and 2 or 1
        widget.Icon:SetState(info.Equipped, isSelected, info.Capacity)
    end
    selectedButton.BackgroundColor3 = mode == "selected"
        and Color3.fromRGB(35, 91, 64) or Color3.fromRGB(42, 39, 36)
    allButton.BackgroundColor3 = mode == "all"
        and Color3.fromRGB(35, 91, 64) or Color3.fromRGB(42, 39, 36)
    local current = bagInfo(snapshot, selectedBag)
    emptyMessage.Visible = mode == "selected" and not current.Equipped
    for bagId, section in pairs(bagSections) do
        section.Frame.Visible = mode == "all" or selectedBag == bagId
    end
end

local function render(snapshot)
    if not window.Visible or type(snapshot) ~= "table" then return end
    local items = snapshot.Items or {}
    if #snapshot.Bags == 5 and not receivedPreferences then
        receivedPreferences = true
        mode = snapshot.ViewMode == "all" and "all" or "selected"
        selectedBag = math.clamp(snapshot.SelectedBagId or 1, 1, 5)
    end
    local positionItems = {}
    for _, item in ipairs(items) do
        if type(item) == "table" and type(item.BagId) == "number"
            and type(item.BagSlot) == "number" then
            positionItems[item.BagId] = positionItems[item.BagId] or {}
            positionItems[item.BagId][item.BagSlot] = item
        end
    end
    local capacityTotal = 0
    for _, info in ipairs(snapshot.Bags) do
        capacityTotal += info.Capacity
        if info.Equipped and info.Capacity > 0 then
            local section = ensureSection(info)
            section.Heading.Text = info.Name .. " (" .. info.Capacity .. " slots)"
            for slotId, widget in ipairs(section.Widgets) do
                local slot = widget.Frame
                for _, child in ipairs(slot:GetChildren()) do
                    if child.Name == "ItemVisual" or child.Name == "Quantity"
                        or child.Name == "ReservedOnBar" then
                        child:Destroy()
                    end
                end
                local item = positionItems[info.BagId]
                    and positionItems[info.BagId][slotId] or nil
                widget.Item = item
                widget.Number.Visible = item == nil
                if item then
                    widget.Border.Color = rarityColors[item.Rarity] or rarityColors.Common
                    widget.Border.Thickness = 3
                    addIcon(slot, item)
                    if (item.Quantity or 1) > 1 then
                        local quantity = label(slot, "Quantity",
                            tostring(item.Quantity), 27, 32, 21, 16, 12,
                            Color3.fromRGB(245, 243, 234), true)
                        quantity.TextXAlignment = Enum.TextXAlignment.Right
                    end
                else
                    widget.Border.Color = Color3.fromRGB(79, 69, 54)
                    widget.Border.Thickness = 1
                end
                if DragDrop.IsDraggingSource(slot) then
                    setSlotVisualVisible(slot, false)
                end
            end
        end
    end
    defaultFooter = tostring(#items) .. " / " .. tostring(capacityTotal) .. " slots"
    Coins.SetWallet(wallet,Currency,snapshot.Currency or 0)
    if statusSerial == 0 then footer.Text = defaultFooter end
    refreshVisualMode(snapshot)
    if hoveredSlot and hoveredSlot.Item and not DragDrop.IsDragging() then
        tooltip:Show(hoveredSlot.Item)
    else
        tooltip:Hide()
    end
end

local function updateView()
    if not window.Visible then return end
    render(EquipmentClient.GetBagView())
end
for i, widget in ipairs(bagButtons) do
    widget.Button.MouseButton1Click:Connect(function()
        if DragDrop.IsDragging() then return end
        mode = "selected"
        selectedBag = i
        receivedPreferences = true
        requestPreferences()
        updateView()
    end)
end
selectedButton.MouseButton1Click:Connect(function()
    if DragDrop.IsDragging() then return end
    mode = "selected"
    receivedPreferences = true
    requestPreferences()
    updateView()
end)
allButton.MouseButton1Click:Connect(function()
    if DragDrop.IsDragging() then return end
    mode = "all"
    receivedPreferences = true
    requestPreferences()
    updateView()
end)

DragDrop.Started:Connect(function(sourceKind, sourceFrame)
    tooltip:Hide()
    if sourceKind == "Bag" then setSlotVisualVisible(sourceFrame, false) end
end)
DragDrop.Finished:Connect(function(sourceKind, sourceFrame)
    if sourceKind == "Bag" and sourceFrame.Parent then
        setSlotVisualVisible(sourceFrame, true)
    end
end)
DragDrop.Result:Connect(function(ok, message, sourceKind)
    if not window.Visible then return end
    if sourceKind == "Bag" or sourceKind == "Equipment" then
        showStatus(message)
    end
end)

local preTradeVisible=false
local preTradePosition=nil
local shopFrame=nil
local function positionBesideShop()
    if not shopFrame or not shopFrame.Parent or not shopFrame.Visible then return end
    local screen=gui.AbsoluteSize
    local mp,ms=shopFrame.AbsolutePosition,shopFrame.AbsoluteSize
    local right=mp.X+ms.X+12
    local left=mp.X-WIDTH-12
    local x=right+WIDTH<=screen.X-8 and right or left>=8 and left or 8
    local y=math.clamp(mp.Y+58,8,math.max(8,screen.Y-HEIGHT-8))
    window.Position=UDim2.fromOffset(math.floor(x),math.floor(y))
end
ShopBridge.Changed:Connect(function(open,merchantFrame)
    if open then
        preTradeVisible=window.Visible
        preTradePosition=window.Position
        shopFrame=merchantFrame
        window.Visible=true
        LumiaModalState:Register("BagWindow")
        positionBesideShop()
        task.spawn(function()
            local ok,snapshot=pcall(function()return request:InvokeServer()end)
            if ok and snapshot then EquipmentClient.UpdateBagSnapshot(snapshot) end
        end)
    else
        shopFrame=nil
        window.Visible=preTradeVisible
        if preTradePosition then window.Position=preTradePosition end
        -- The bag was auto-opened for trading. If it was not open before the
        -- trade, closing the shop hides it and MUST also clear its modal
        -- registration, or every system reading modal state (the quest pointer,
        -- the bag hotkey) keeps believing a window is still open.
        if not window.Visible then
            LumiaModalState:Unregister("BagWindow")
        end
    end
    tooltip:Hide()
    hoveredSlot=nil
    DragDrop.NotifyWindowsChanged()
    if window.Visible then updateView() end
end)
local manualPosition = false
local docked = false
local function arrangeBag()
    if ShopBridge.IsOpen() then positionBesideShop() return end
    if not window.Visible or manualPosition then return end
    local characterGui = player.PlayerGui:FindFirstChild("LumiaCharacter")
    local charWindow = characterGui and characterGui:FindFirstChild("CharacterWindow")
    if charWindow and charWindow.Visible then
        local pos, size = charWindow.AbsolutePosition, charWindow.AbsoluteSize
        local screen = gui.AbsoluteSize
        local right = pos.X + size.X + 12
        local left = pos.X - WIDTH - 12
        local x = right + WIDTH < screen.X - 8 and right
            or left >= 8 and left or math.max(8, screen.X - WIDTH - 8)
        local y = math.clamp(pos.Y + 70, 8, math.max(8, screen.Y - HEIGHT - 8))
        window.Position = UDim2.fromOffset(math.floor(x), math.floor(y))
        docked = true
    elseif docked then
        window.Position = basePosition
        docked = false
    end
end
DragDrop.WindowsChanged:Connect(function() task.defer(arrangeBag) end)

local moving, startMouse, startPosition = false, nil, nil
title.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        moving = true
        manualPosition, docked = true, false
        startMouse = input.Position
        startPosition = window.Position
    end
end)
UserInputService.InputChanged:Connect(function(input)
    if moving and input.UserInputType == Enum.UserInputType.MouseMovement then
        local delta = input.Position - startMouse
        window.Position = UDim2.new(startPosition.X.Scale,
            startPosition.X.Offset + delta.X, startPosition.Y.Scale,
            startPosition.Y.Offset + delta.Y)
    end
end)
UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then moving = false end
end)

local refreshing = false
local function refresh()
    if refreshing or not window.Visible then return end
    refreshing = true
    local startedRevision = EquipmentClient.GetRevision()
    local success, result = pcall(function()
        return request:InvokeServer()
    end)
    refreshing = false
    if success and type(result) == "table" then
        EquipmentClient.UpdateBagSnapshot(result, startedRevision)
    end
end
local deleting = false
DragDrop.DeleteRequested:Connect(function(item, coordinates)
    if deleting or not window.Visible or type(item) ~= "table"
        or type(coordinates) ~= "table" then return end
    ItemDeleteDialog.Show(item, function(confirmed)
        if not confirmed then return end
        deleting = true
        task.spawn(function()
            local ok, result = pcall(function()
                return discardRequest:InvokeServer({
                    BagId = coordinates.BagId,
                    Slot = coordinates.Slot,
                    ItemId = item.ItemId,
                    InstanceId = item.InstanceId,
                    ConfirmWeapon = item.Type == "Weapon",
                })
            end)
            deleting = false
            if not ok or type(result) ~= "table" or not result.Ok then
                showStatus(type(result) == "table" and tostring(result.Error)
                    or "Delete request failed")
                return
            end
            if not EquipmentClient.UpdateBagSnapshot(result.Bag) then
                task.defer(refresh)
            end
            showStatus(result.Message or "Item destroyed")
        end)
    end)
end)
EquipmentClient.BagChanged:Connect(updateView)
EquipmentClient.NeedsRefresh:Connect(function()
    task.delay(0.25, function()
        if window.Visible then task.spawn(refresh) end
    end)
end)

local function toggle()
    if ShopBridge.IsOpen() then
        showStatus("Close the merchant window to leave trading")
        return
    end
    window.Visible = not window.Visible
    tooltip:Hide()
    hoveredSlot = nil
    DragDrop.NotifyWindowsChanged()
    if window.Visible then
        LumiaModalState:Register("BagWindow")
        task.spawn(refresh)
        updateView()
    else
        LumiaModalState:Unregister("BagWindow")
    end
end
close.MouseButton1Click:Connect(toggle)
-- V18 micro menu calls the same validated BAG toggle as the B hotkey.
local MenuBus = require(components:WaitForChild("LumiaMicroMenuBus"))
MenuBus.Register("Bag", toggle)
UserInputService.InputBegan:Connect(function(input, processed)
    if processed or UserInputService:GetFocusedTextBox() then return end
    if input.KeyCode == Enum.KeyCode.B then toggle() end
end)
task.spawn(function()
    while gui.Parent do
        task.wait(2)
        if window.Visible then refresh() end
    end
end)
print("[Lumia - Lumia Bag] Bag ready - drop outside UI to request item destruction")
