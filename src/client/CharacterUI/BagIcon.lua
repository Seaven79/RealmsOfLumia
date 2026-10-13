-- REALMS OF ETERNIA - BAG SELECTOR ICON
-- Decorative, client-only component for the five bag-equipment positions.
-- No inventory logic here: the server decides which bags are equipped.
-- When we have custom bag artwork, replace the vector drawing in THIS module.

local BagIcon = {}

local ACTIVE_GOLD = Color3.fromRGB(227, 180, 94)
local INACTIVE_GREY = Color3.fromRGB(113, 127, 147)
local ACTIVE_LABEL = Color3.fromRGB(240, 244, 251)
local INACTIVE_LABEL = Color3.fromRGB(150, 163, 181)

local function shape(parent, name, position, size, radius)
    local frame = Instance.new("Frame")
    frame.Name = name
    frame.Position = position
    frame.Size = size
    frame.BorderSizePixel = 0
    frame.BackgroundColor3 = ACTIVE_GOLD
    frame.Parent = parent
    if radius then
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, radius)
        corner.Parent = frame
    end
    return frame
end

local function text(parent, name, content, x, y, width, height, size)
    local element = Instance.new("TextLabel")
    element.Name = name
    element.BackgroundTransparency = 1
    element.Position = UDim2.fromOffset(x, y)
    element.Size = UDim2.fromOffset(width, height)
    element.Text = content
    element.TextColor3 = ACTIVE_LABEL
    element.TextSize = size
    element.Font = Enum.Font.GothamBold
    element.TextXAlignment = Enum.TextXAlignment.Center
    element.Parent = parent
    return element
end

function BagIcon.Attach(button, bagId)
    -- Each button is 45x45. The backpack is drawn inside a 30x28 pixel area,
    -- leaving room for the bag number beneath it.
    local container = Instance.new("Frame")
    container.Name = "BagIcon"
    container.Position = UDim2.fromOffset(8, 2)
    container.Size = UDim2.fromOffset(29, 29)
    container.BackgroundTransparency = 1
    container.BorderSizePixel = 0
    container.Parent = button

    local handle = shape(container, "Handle", UDim2.fromOffset(10, 2), UDim2.fromOffset(10, 9), 4)
    handle.BackgroundTransparency = 1
    local handleStroke = Instance.new("UIStroke")
    handleStroke.Thickness = 2
    handleStroke.Color = ACTIVE_GOLD
    handleStroke.Parent = handle

    local body = shape(container, "Backpack", UDim2.fromOffset(4, 9), UDim2.fromOffset(22, 18), 4)
    local flap = shape(container, "Flap", UDim2.fromOffset(5, 10), UDim2.fromOffset(20, 7), 2)
    local flapStroke = Instance.new("UIStroke")
    flapStroke.Thickness = 1
    flapStroke.Color = Color3.fromRGB(66, 58, 52)
    flapStroke.Transparency = 0.45
    flapStroke.Parent = flap
    local clasp = shape(container, "Clasp", UDim2.fromOffset(13, 15), UDim2.fromOffset(4, 6), 1)
    clasp.BackgroundColor3 = Color3.fromRGB(55, 49, 48)

    -- Unused bag positions have a tiny, muted lock on the backpack.
    -- This is a visual placeholder, not a gameplay unlock requirement.
    local lockBody = shape(container, "UnusedBagLock", UDim2.fromOffset(18, 19), UDim2.fromOffset(10, 9), 2)
    lockBody.BackgroundColor3 = INACTIVE_GREY
    local lockHandle = shape(container, "UnusedLockHandle", UDim2.fromOffset(20, 15), UDim2.fromOffset(6, 8), 3)
    lockHandle.BackgroundTransparency = 1
    local lockStroke = Instance.new("UIStroke")
    lockStroke.Thickness = 1.5
    lockStroke.Color = INACTIVE_GREY
    lockStroke.Parent = lockHandle

    local number = text(button, "BagNumber", tostring(bagId), 3, 29, 39, 13, 10)
    local capacity = text(button, "BagCapacityBadge", "", 29, 0, 15, 12, 9)

    local component = {}
    function component:SetState(equipped, selected, slots)
        local color = equipped and ACTIVE_GOLD or INACTIVE_GREY
        local transparency = equipped and 0 or 0.45
        body.BackgroundColor3 = color
        body.BackgroundTransparency = transparency
        flap.BackgroundColor3 = color
        flap.BackgroundTransparency = transparency
        handleStroke.Color = color
        handleStroke.Transparency = transparency
        clasp.BackgroundTransparency = equipped and 0 or 0.6
        number.TextColor3 = selected and ACTIVE_LABEL
            or (equipped and ACTIVE_GOLD or INACTIVE_LABEL)
        capacity.Text = equipped and tostring(slots or 0) or ""
        capacity.TextColor3 = ACTIVE_GOLD
        lockBody.Visible = not equipped
        lockHandle.Visible = not equipped
    end
    component:SetState(bagId == 1, bagId == 1, bagId == 1 and 8 or 0)
    return component
end

return BagIcon
