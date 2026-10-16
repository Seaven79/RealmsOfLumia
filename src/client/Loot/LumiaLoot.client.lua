-- REALMS OF LUMIA - LOOT WINDOW v15: inventory-matching icons
-- Simple loot UI; future rarities/drop types require data, not another UI.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local ContextActionService=game:GetService("ContextActionService")
local lumia = ReplicatedStorage:WaitForChild("Lumia")
local net = lumia:WaitForChild("LootNetwork")
local openRemote = net:WaitForChild("OpenLoot")
local action = net:WaitForChild("LootAction")
local requestOpen = net:WaitForChild("RequestOpenLoot")
local components = script.Parent.Parent:WaitForChild("UI")
local EquipmentClient = require(components:WaitForChild("EquipmentClient"))
local ItemPreview = require(components:WaitForChild("LumiaItemPreview"))
local ItemIcons = require(lumia:WaitForChild("Shared"):WaitForChild("Items"):WaitForChild("ItemIcons"))
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local mouse = player:GetMouse()
local gui = Instance.new("ScreenGui")
gui.Name = "LumiaLoot"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 45
gui.Parent = playerGui

-- Interaction cursor is rendered centrally by LumiaQuests.client.lua.
-- This script remains responsible only for server-validated right-click LOOT.
-- No second cursor and no competing MouseIconEnabled toggles.

local frame = Instance.new("Frame")
frame.Name = "LootWindow"
frame.Size = UDim2.fromOffset(308, 245)
frame.Position = UDim2.new(0.5, -154, 0.5, -125)
frame.BackgroundColor3 = Color3.fromRGB(25, 25, 29)
frame.BorderSizePixel = 0
frame.Visible = false
frame.Parent = gui
Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 7)
local stroke = Instance.new("UIStroke", frame)
stroke.Thickness = 2
stroke.Color = Color3.fromRGB(118, 94, 57)

local function text(parent, name, value, y, height, size, color)
    local label = Instance.new("TextLabel")
    label.Name = name
    label.Text = value
    label.Position = UDim2.fromOffset(15, y)
    label.Size = UDim2.new(1, -30, 0, height)
    label.Font = Enum.Font.Gotham
    label.TextSize = size
    label.TextColor3 = color
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.BackgroundTransparency = 1
    label.Parent = parent
    return label
end
local heading = text(frame, "Title", "LOOT", 10, 26, 18, Color3.fromRGB(227, 191, 132))
local status = text(frame, "Status", "Select an item to loot", 213, 20, 11, Color3.fromRGB(180, 170, 150))
local close = Instance.new("TextButton")
close.Name = "Close"
close.Text = "X"
close.Size = UDim2.fromOffset(27, 27)
close.Position = UDim2.new(1, -35, 0, 7)
close.TextColor3 = Color3.fromRGB(250, 230, 215)
close.BackgroundColor3 = Color3.fromRGB(76, 48, 42)
close.Parent = frame
Instance.new("UICorner", close).CornerRadius = UDim.new(0, 4)
local contents = Instance.new("ScrollingFrame")
contents.Name = "LootItems"
contents.ScrollBarThickness = 4
contents.ScrollBarImageColor3 = Color3.fromRGB(169, 137, 80)
contents.ScrollingDirection = Enum.ScrollingDirection.Y
contents.AutomaticCanvasSize = Enum.AutomaticSize.Y
contents.CanvasSize = UDim2.fromOffset(0, 0)
contents.Size = UDim2.new(1, -22, 0, 158)
contents.Position = UDim2.fromOffset(11, 47)
contents.BackgroundTransparency = 1
contents.Parent = frame
local list = Instance.new("UIListLayout", contents)
list.Padding = UDim.new(0, 5)
list.SortOrder = Enum.SortOrder.LayoutOrder
local currentToken = nil
local busy = false
local colors = {
    Poor = Color3.fromRGB(166, 166, 166),
    Common = Color3.fromRGB(232, 234, 236),
    Uncommon = Color3.fromRGB(101, 217, 154),
    Rare = Color3.fromRGB(104, 169, 255),
    Epic = Color3.fromRGB(200, 156, 255),
    Legendary = Color3.fromRGB(247, 191, 104),
}
local function clearContents()
    for _, child in ipairs(contents:GetChildren()) do
        if child:IsA("GuiObject") then child:Destroy() end
    end
end
local function closeWindow()
    currentToken = nil
    frame.Visible = false
end
close.MouseButton1Click:Connect(closeWindow)
-- Hover is a CLIENT convenience only; server validates every click.
local hoveredCorpse = nil
local MAX_LOOT_DISTANCE = 12 -- same as LootConfig.OpenDistance (visual hint only)

local function overInteractiveGui(position)
    local inset = GuiService:GetGuiInset()
    for _, hit in ipairs(playerGui:GetGuiObjectsAtPosition(
        math.floor(position.X - inset.X), math.floor(position.Y - inset.Y))) do
        if not hit:IsDescendantOf(gui) then
            local node = hit
            while node and node ~= playerGui do
                if node:IsA("GuiObject") and node.Visible then
                    local name = node.Name:lower()
                    if name == "window" or name == "lootwindow"
                        or name == "characterwindow" or name == "panel"
                        or name == "backdrop" or node:IsA("TextButton")
                        or node:IsA("ImageButton")
                        or node:IsA("TextBox")
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

local function findLootableCorpse()
    if frame.Visible or UserInputService:GetFocusedTextBox() then return nil end
    if player:GetAttribute("LumiaDraggingItem") == true then return nil end
    local character = player.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if not root or not humanoid or humanoid.Health <= 0 then return nil end
    local target = mouse.Target
    if not target then return nil end
    local model = target:FindFirstAncestorOfClass("Model")
    if not model or model:GetAttribute("LumiaLootableCorpse") ~= true then return nil end
    if model:GetAttribute("LumiaLootOwnerUserId") ~= player.UserId then return nil end
    local corpseRoot = model:FindFirstChild("HumanoidRootPart")
    if not corpseRoot or (root.Position - corpseRoot.Position).Magnitude > MAX_LOOT_DISTANCE then
        return nil
    end
    if overInteractiveGui(UserInputService:GetMouseLocation()) then return nil end
    return model
end

local function updateLootCursor(model)
    if hoveredCorpse ~= model then
        hoveredCorpse=model
        player:SetAttribute("LumiaLootHoverActive",model~=nil)
    end
end

RunService.RenderStepped:Connect(function()
    if not gui.Parent then return end
    -- Resolve hover every frame; old 50ms throttle caused cursor lag and jitter.
    updateLootCursor(findLootableCorpse())
end)

-- Uses the same F10 interaction binding as NPC conversations and clues.
local LOOT_ACTION="Lumia_LootInteract_v4"
local function bindLootAction()
    ContextActionService:UnbindAction(LOOT_ACTION)
    local name=player:GetAttribute("LumiaInteractKey") or "MouseButton2"
    local input=name=="MouseButton2" and Enum.UserInputType.MouseButton2 or Enum.KeyCode[name]
    if not input then input=Enum.UserInputType.MouseButton2 end
    ContextActionService:BindActionAtPriority(LOOT_ACTION,function(_,state)
        if state~=Enum.UserInputState.Begin then return Enum.ContextActionResult.Pass end
        if player:GetAttribute("LumiaOptionsOpen") then return Enum.ContextActionResult.Pass end
        local corpse=findLootableCorpse()
        if corpse then
            requestOpen:FireServer(corpse)
            return Enum.ContextActionResult.Sink
        end
        return Enum.ContextActionResult.Pass
    end,false,3240,input)
end
player:GetAttributeChangedSignal("LumiaInteractKey"):Connect(bindLootAction)
bindLootAction()

script.Destroying:Connect(function()
    updateLootCursor(nil)
    ContextActionService:UnbindAction(LOOT_ACTION)
end)

local render
render = function(items)
    clearContents()
    if #items == 0 then
        -- Last item was granted by the authoritative server; close instantly.
        -- Corpse cleanup and respawn use separate server-side timers.
        closeWindow()
        return
    end
    status.Text = "Click an item to take it (B opens your bag)"
    for index, item in ipairs(items) do
        local button = Instance.new("TextButton")
        button.Name = "Loot" .. tostring(index)
        button.LayoutOrder = index
        button.Size = UDim2.new(1, 0, 0, 42)
        button.BackgroundColor3 = Color3.fromRGB(47, 45, 42)
        button.Text = ""
        button.AutoButtonColor = true
        button.Parent = contents
        Instance.new("UICorner", button).CornerRadius = UDim.new(0, 5)

        local iconFrame = Instance.new("Frame")
        iconFrame.Name = "ItemIcon"
        iconFrame.Size = UDim2.fromOffset(35, 35)
        iconFrame.Position = UDim2.fromOffset(5, 3)
        iconFrame.BorderSizePixel = 0
        iconFrame.BackgroundColor3 = Color3.fromRGB(27, 30, 35)
        iconFrame.ClipsDescendants = true
        iconFrame.Parent = button
        Instance.new("UICorner", iconFrame).CornerRadius = UDim.new(0, 5)
        local iconStroke = Instance.new("UIStroke")
        iconStroke.Color = colors[item.Rarity] or colors.Common
        iconStroke.Thickness = 1
        iconStroke.Parent = iconFrame

        -- Exactly the same preview renderer used by the bag. The item ID,
        -- display name, rarity and quantity still originate from LootService.
        if not ItemPreview.Attach(iconFrame, item.ItemId) then
            local imageId, symbol = ItemIcons.Resolve(item)
            if imageId then
                local image = Instance.new("ImageLabel")
                image.Name = "ItemVisual"
                image.BackgroundTransparency = 1
                image.Size = UDim2.fromScale(0.9, 0.9)
                image.Position = UDim2.fromScale(0.05, 0.05)
                image.ScaleType = Enum.ScaleType.Fit
                image.Image = imageId
                image.Parent = iconFrame
            else
                local glyph = Instance.new("TextLabel")
                glyph.Name = "ItemVisual"
                glyph.BackgroundTransparency = 1
                glyph.Size = UDim2.fromScale(1, 1)
                glyph.Font = Enum.Font.GothamBold
                glyph.TextSize = 22
                glyph.TextColor3 = colors[item.Rarity] or colors.Common
                glyph.Text = symbol or "?"
                glyph.Parent = iconFrame
            end
        end

        local nameLabel = Instance.new("TextLabel")
        nameLabel.Name = "ItemName"
        nameLabel.BackgroundTransparency = 1
        nameLabel.Position = UDim2.fromOffset(48, 0)
        nameLabel.Size = UDim2.new(1, -100, 1, 0)
        nameLabel.Font = Enum.Font.GothamBold
        nameLabel.TextSize = 13
        nameLabel.TextXAlignment = Enum.TextXAlignment.Left
        nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
        nameLabel.TextColor3 = colors[item.Rarity] or colors.Common
        nameLabel.Text = tostring(item.DisplayName or item.ItemId or "Unknown item")
        nameLabel.Parent = button

        local qtyLabel = Instance.new("TextLabel")
        qtyLabel.Name = "Quantity"
        qtyLabel.BackgroundTransparency = 1
        qtyLabel.AnchorPoint = Vector2.new(1, 0)
        qtyLabel.Position = UDim2.new(1, -7, 0, 0)
        qtyLabel.Size = UDim2.fromOffset(45, 42)
        qtyLabel.Font = Enum.Font.GothamBold
        qtyLabel.TextSize = 13
        qtyLabel.TextXAlignment = Enum.TextXAlignment.Right
        qtyLabel.TextColor3 = Color3.fromRGB(222, 207, 177)
        qtyLabel.Text = "x" .. tostring(item.Quantity or 1)
        qtyLabel.Parent = button

        button.MouseButton1Click:Connect(function()
            if busy or not currentToken then return end
            busy = true
            local token = currentToken
            local ok, response = pcall(function()
                return action:InvokeServer("Take", token, item.Slot)
            end)
            busy = false
            if currentToken ~= token then return end
            if not ok or type(response) ~= "table" or not response.Ok then
                status.Text = type(response) == "table" and tostring(response.Error) or "Loot request failed"
                return
            end
            if response.Bag then
                EquipmentClient.UpdateBagSnapshot(response.Bag)
            end
            render(response.Items or {})
        end)
    end
end
openRemote.OnClientEvent:Connect(function(token)
    if type(token) ~= "string" then return end
    currentToken = token
    frame.Visible = true
    status.Text = "Checking corpse..."
    local ok, response = pcall(function()
        return action:InvokeServer("Inspect", token)
    end)
    if currentToken ~= token then return end
    if not ok or type(response) ~= "table" or not response.Ok then
        status.Text = type(response) == "table" and tostring(response.Error) or "Loot unavailable"
        return
    end
    heading.Text = "LOOT - " .. tostring(response.MonsterName or "Monster")
    render(response.Items or {})
end)
print("[Lumia - Lumia Loot] v6: unified star hover, F10 interaction binding, right mouse default")
