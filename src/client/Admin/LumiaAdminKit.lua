-- REALMS OF LUMIA | ADMIN UI KIT
-- Reusable, theme-matched widgets for owner tools. Nothing here knows about
-- game logic: pass values in, get callbacks out.
--
-- Usage:
--   local Kit = require(script.Parent.LumiaAdminKit)
--   local gui = Kit.MakeGui("MyPanel", 90)
--   local toast = Kit.Toast(gui)
--   Kit.Button({Text = "Save"}, gui, function() toast("Saved", "good") end)
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Kit = {}

Kit.Palette = {
    Screen = Color3.fromRGB(8, 11, 16),
    Panel = Color3.fromRGB(19, 24, 34),
    PanelAlt = Color3.fromRGB(27, 34, 47),
    Rail = Color3.fromRGB(14, 18, 26),
    Stroke = Color3.fromRGB(178, 140, 81),
    StrokeDim = Color3.fromRGB(58, 70, 90),
    Accent = Color3.fromRGB(120, 200, 255),
    Text = Color3.fromRGB(228, 230, 235),
    Dim = Color3.fromRGB(150, 158, 172),
    Gold = Color3.fromRGB(244, 223, 174),
    Good = Color3.fromRGB(136, 213, 169),
    Bad = Color3.fromRGB(226, 122, 108),
    Warn = Color3.fromRGB(240, 200, 120),
}

Kit.Font = Enum.Font.Gotham
Kit.FontBold = Enum.Font.GothamBold
Kit.FontDisplay = Enum.Font.Garamond

-- Instance -> helper function. Weak keys so destroyed buttons are collected.
local buttonSetters = setmetatable({}, { __mode = "k" })

function Kit.Create(className, properties, parent)
    local instance = Instance.new(className)
    for key, value in pairs(properties or {}) do
        instance[key] = value
    end
    if parent then instance.Parent = parent end
    return instance
end

function Kit.Corner(parent, radius)
    return Kit.Create("UICorner", { CornerRadius = UDim.new(0, radius or 8) }, parent)
end

function Kit.Stroke(parent, color, thickness, transparency)
    return Kit.Create("UIStroke", {
        Color = color or Kit.Palette.StrokeDim,
        Thickness = thickness or 1,
        Transparency = transparency or 0,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
    }, parent)
end

function Kit.Padding(parent, left, right, top, bottom)
    return Kit.Create("UIPadding", {
        PaddingLeft = UDim.new(0, left or 0),
        PaddingRight = UDim.new(0, right or 0),
        PaddingTop = UDim.new(0, top or 0),
        PaddingBottom = UDim.new(0, bottom or 0),
    }, parent)
end

function Kit.MakeGui(name, displayOrder)
    local player = Players.LocalPlayer
    local playerGui = player:WaitForChild("PlayerGui")
    local existing = playerGui:FindFirstChild(name)
    if existing then existing:Destroy() end

    local gui = Kit.Create("ScreenGui", {
        Name = name,
        ResetOnSpawn = false,
        IgnoreGuiInset = true,
        DisplayOrder = displayOrder or 90,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    }, playerGui)
    return gui
end

-- Draggable title bar for any frame.
function Kit.MakeDraggable(handle, target)
    local dragging, dragStart, startPos = false, nil, nil

    handle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = target.Position
        end
    end)

    handle.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if not dragging then return end
        if input.UserInputType ~= Enum.UserInputType.MouseMovement
            and input.UserInputType ~= Enum.UserInputType.Touch then
            return
        end
        local delta = input.Position - dragStart
        target.Position = UDim2.new(
            startPos.X.Scale, startPos.X.Offset + delta.X,
            startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end)
end

function Kit.Button(options, parent, onClick)
    local button = Kit.Create("TextButton", {
        Name = options.Name or "Button",
        Text = options.Text or "",
        Font = options.Font or Kit.FontBold,
        TextSize = options.TextSize or 14,
        TextColor3 = options.TextColor3 or Kit.Palette.Text,
        BackgroundColor3 = options.BackgroundColor3 or Kit.Palette.PanelAlt,
        BackgroundTransparency = 0,
        AutoButtonColor = false,
        BorderSizePixel = 0,
        Size = options.Size or UDim2.fromOffset(90, 28),
        Position = options.Position or UDim2.fromOffset(0, 0),
        LayoutOrder = options.LayoutOrder or 0,
        TextTruncate = Enum.TextTruncate.AtEnd,
    }, parent)

    Kit.Corner(button, options.CornerRadius or 6)
    local stroke = Kit.Stroke(button, options.StrokeColor or Kit.Palette.StrokeDim, 1)

    button.MouseEnter:Connect(function()
        if button:GetAttribute("Disabled") then return end
        TweenService:Create(button, TweenInfo.new(0.12), {
            BackgroundColor3 = options.HoverColor or Color3.fromRGB(38, 47, 63),
        }):Play()
        stroke.Color = Kit.Palette.Stroke
    end)

    button.MouseLeave:Connect(function()
        if button:GetAttribute("Disabled") then return end
        TweenService:Create(button, TweenInfo.new(0.12), {
            BackgroundColor3 = options.BackgroundColor3 or Kit.Palette.PanelAlt,
        }):Play()
        stroke.Color = options.StrokeColor or Kit.Palette.StrokeDim
    end)

    button.MouseButton1Click:Connect(function()
        if button:GetAttribute("Disabled") then return end
        if onClick then onClick(button) end
    end)

    -- Roblox Instances reject arbitrary member assignment ("SetDisabled is not
    -- a valid member of TextButton"), so helpers live in this side table
    -- instead of being attached to the instance as methods.
    buttonSetters[button] = function(disabled)
        button:SetAttribute("Disabled", disabled)
        button.TextColor3 = disabled and Kit.Palette.Dim
            or (options.TextColor3 or Kit.Palette.Text)
        button.BackgroundTransparency = disabled and 0.4 or 0
    end

    return button
end

-- Enable/disable a Kit button. Safe to call on any instance without a setter.
function Kit.SetDisabled(button, disabled)
    local setter = button and buttonSetters[button]
    if setter then setter(disabled == true) end
end

-- Set button text; plain property write, kept for call-site symmetry.
function Kit.SetText(button, text)
    if button then button.Text = tostring(text) end
end

-- Small coloured badge used for state ("oversized", "default", "active").
function Kit.Badge(text, color, parent, size)
    local badge = Kit.Create("TextLabel", {
        Text = text,
        Font = Kit.FontBold,
        TextSize = 11,
        TextColor3 = color or Kit.Palette.Dim,
        BackgroundColor3 = Kit.Palette.PanelAlt,
        BackgroundTransparency = 0.25,
        BorderSizePixel = 0,
        Size = size or UDim2.fromOffset(64, 16),
        TextXAlignment = Enum.TextXAlignment.Center,
    }, parent)
    Kit.Corner(badge, 4)
    return badge
end

-- Stack of toast messages in the top-right of the panel.
function Kit.Toast(gui)
    local holder = Kit.Create("Frame", {
        Name = "Toasts",
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -18, 0, 18),
        Size = UDim2.fromOffset(280, 200),
        BackgroundTransparency = 1,
        ZIndex = 40,
    }, gui)

    local list = Kit.Create("UIListLayout", {
        Padding = UDim.new(0, 6),
        HorizontalAlignment = Enum.HorizontalAlignment.Right,
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, holder)

    local order = 0

    return function(message, kind)
        order = order + 1
        local color = Kit.Palette.Accent
        if kind == "good" then color = Kit.Palette.Good
        elseif kind == "bad" then color = Kit.Palette.Bad
        elseif kind == "warn" then color = Kit.Palette.Warn end

        local card = Kit.Create("Frame", {
            Size = UDim2.fromOffset(280, 40),
            BackgroundColor3 = Kit.Palette.Panel,
            BackgroundTransparency = 0.05,
            BorderSizePixel = 0,
            LayoutOrder = order,
            ZIndex = 41,
        }, holder)
        Kit.Corner(card, 8)
        Kit.Stroke(card, color, 1.5)

        Kit.Create("TextLabel", {
            Text = tostring(message),
            Font = Kit.Font,
            TextSize = 13,
            TextWrapped = true,
            TextColor3 = Kit.Palette.Text,
            BackgroundTransparency = 1,
            Position = UDim2.fromOffset(12, 4),
            Size = UDim2.new(1, -24, 1, -8),
            TextXAlignment = Enum.TextXAlignment.Left,
            ZIndex = 42,
        }, card)

        task.delay(3.4, function()
            if not card.Parent then return end
            local fade = TweenService:Create(card, TweenInfo.new(0.3), {
                BackgroundTransparency = 1,
            })
            fade:Play()
            fade.Completed:Connect(function() card:Destroy() end)
        end)
        return card
    end
end

-- Vertical scroller with a list layout and 8px gutters.
function Kit.Scroller(parent, paddingPixels)
    local frame = Kit.Create("ScrollingFrame", {
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Size = UDim2.fromScale(1, 1),
        CanvasSize = UDim2.new(),
        ScrollBarThickness = 4,
        ScrollBarImageColor3 = Kit.Palette.StrokeDim,
        ScrollingDirection = Enum.ScrollingDirection.Y,
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
    }, parent)

    Kit.Create("UIListLayout", {
        Padding = UDim.new(0, paddingPixels or 8),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, frame)
    Kit.Padding(frame, 4, 10, 4, 12)
    return frame
end

function Kit.Header(text, parent, order)
    local label = Kit.Create("TextLabel", {
        Text = text,
        Font = Kit.FontBold,
        TextSize = 14,
        TextColor3 = Kit.Palette.Dim,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 20),
        TextXAlignment = Enum.TextXAlignment.Left,
        LayoutOrder = order or 0,
    }, parent)
    return label
end

-- Numeric field: label + hint, a text box, and a reset button.
-- options: Label, Hint, Unit, Min, Max, Integer, Value, LayoutOrder,
--          IsOverridden, OnCommit(value), OnReset()
function Kit.NumberField(parent, options)
    local row = Kit.Create("Frame", {
        Name = "Field_" .. tostring(options.Id or options.Label),
        Size = UDim2.new(1, 0, 0, 46),
        BackgroundColor3 = Kit.Palette.Panel,
        BackgroundTransparency = 0.35,
        BorderSizePixel = 0,
        LayoutOrder = options.LayoutOrder or 0,
    }, parent)
    Kit.Corner(row, 8)

    local accent = Kit.Create("Frame", {
        Size = UDim2.fromOffset(3, 46),
        BackgroundColor3 = Kit.Palette.Accent,
        BackgroundTransparency = options.IsOverridden and 0 or 1,
        BorderSizePixel = 0,
    }, row)
    Kit.Corner(accent, 2)

    Kit.Create("TextLabel", {
        Text = options.Label or "Value",
        Font = Kit.FontBold,
        TextSize = 16,
        TextColor3 = Kit.Palette.Text,
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(14, 6),
        Size = UDim2.new(1, -190, 0, 16),
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
    }, row)

    local hint = Kit.Create("TextLabel", {
        Text = options.Hint or "",
        Font = Kit.Font,
        TextSize = 11,
        TextColor3 = Kit.Palette.Dim,
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(14, 24),
        Size = UDim2.new(1, -190, 0, 14),
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
    }, row)

    local box = Kit.Create("TextBox", {
        Text = tostring(options.Value or 0),
        Font = Kit.FontBold,
        TextSize = 16,
        TextColor3 = Kit.Palette.Gold,
        BackgroundColor3 = Kit.Palette.Rail,
        BackgroundTransparency = 0,
        BorderSizePixel = 0,
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -42, 0.5, 0),
        Size = UDim2.fromOffset(96, 26),
        ClearTextOnFocus = false,
        TextXAlignment = Enum.TextXAlignment.Right,
    }, row)
    Kit.Corner(box, 5)
    Kit.Stroke(box, Kit.Palette.StrokeDim, 1)
    Kit.Padding(box, 6, 6, 0, 0)

    local unit = Kit.Create("TextLabel", {
        Text = options.Unit or "",
        Font = Kit.Font,
        TextSize = 11,
        TextColor3 = Kit.Palette.Dim,
        BackgroundTransparency = 1,
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -136, 0.5, 0),
        Size = UDim2.fromOffset(34, 14),
        TextXAlignment = Enum.TextXAlignment.Right,
    }, row)

    local reset = Kit.Button({
        Text = "↺",
        Size = UDim2.fromOffset(24, 24),
        CornerRadius = 5,
        TextColor3 = Kit.Palette.Dim,
    }, row)
    reset.AnchorPoint = Vector2.new(1, 0.5)
    reset.Position = UDim2.new(1, -10, 0.5, 0)

    local field = {}
    field.Row = row

    local function parse()
        local text = box.Text:gsub("[^%d%.%-]", "")
        local value = tonumber(text)
        if not value then return nil, "Not a number" end
        if options.Integer and value % 1 ~= 0 then return nil, "Whole numbers only" end
        if value < (options.Min or -math.huge) then
            return nil, "Minimum is " .. tostring(options.Min)
        end
        if value > (options.Max or math.huge) then
            return nil, "Maximum is " .. tostring(options.Max)
        end
        return value
    end

    local function commit()
        local value, reason = parse()
        if not value then
            box.TextColor3 = Kit.Palette.Bad
            hint.Text = tostring(reason)
            hint.TextColor3 = Kit.Palette.Bad
            return
        end
        box.TextColor3 = Kit.Palette.Gold
        hint.Text = options.Hint or ""
        hint.TextColor3 = Kit.Palette.Dim
        if options.OnCommit then options.OnCommit(value) end
    end

    box.FocusLost:Connect(commit)
    reset.MouseButton1Click:Connect(function()
        if options.OnReset then options.OnReset() end
    end)

    function field.SetValue(value)
        box.Text = tostring(value or 0)
    end

    function field.GetValue()
        return parse()
    end

    function field.SetOverridden(isOverridden)
        accent.BackgroundTransparency = isOverridden and 0 or 1
    end

    return field
end

-- Slider + numeric readout. Used where ranges are bounded and feel matters
-- (mob stats, difficulty).
-- options: Label, Hint, Min, Max, Step, Value, Unit, LayoutOrder,
--          OnCommit(value)
function Kit.SliderField(parent, options)
    local row = Kit.Create("Frame", {
        Size = UDim2.new(1, 0, 0, 74),
        BackgroundColor3 = Kit.Palette.Panel,
        BackgroundTransparency = 0.35,
        BorderSizePixel = 0,
        LayoutOrder = options.LayoutOrder or 0,
    }, parent)
    Kit.Corner(row, 8)

    Kit.Create("TextLabel", {
        Text = options.Label or "Value",
        Font = Kit.FontBold,
        TextSize = 16,
        TextColor3 = Kit.Palette.Text,
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(16, 8),
        Size = UDim2.new(1, -130, 0, 20),
        TextXAlignment = Enum.TextXAlignment.Left,
    }, row)

    local readout = Kit.Create("TextLabel", {
        Text = tostring(options.Value or 0),
        Font = Kit.FontBold,
        TextSize = 16,
        TextColor3 = Kit.Palette.Gold,
        BackgroundTransparency = 1,
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -16, 0, 8),
        Size = UDim2.fromOffset(110, 20),
        TextXAlignment = Enum.TextXAlignment.Right,
    }, row)

    local hint = Kit.Create("TextLabel", {
        Text = options.Hint or "",
        Font = Kit.Font,
        TextSize = 13,
        TextColor3 = Kit.Palette.Dim,
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(16, 30),
        Size = UDim2.new(1, -130, 0, 16),
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
    }, row)

    local bar = Kit.Create("Frame", {
        Position = UDim2.fromOffset(16, 54),
        Size = UDim2.new(1, -32, 0, 10),
        BackgroundColor3 = Kit.Palette.Rail,
        BorderSizePixel = 0,
    }, row)
    Kit.Corner(bar, 3)

    local fill = Kit.Create("Frame", {
        Size = UDim2.new(0, 0, 1, 0),
        BackgroundColor3 = Kit.Palette.Accent,
        BorderSizePixel = 0,
    }, bar)
    Kit.Corner(fill, 3)

    local slider = Kit.Create("TextButton", {
        Text = "",
        BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1),
    }, bar)

    local minimum = options.Min or 0
    local maximum = options.Max or 1
    local function span()
        local valueSpan = maximum - minimum
        if valueSpan <= 0 then return 1 end
        return valueSpan
    end

    local current = tonumber(options.Value) or minimum

    local function applyVisual()
        local alpha = math.clamp((current - minimum) / span(), 0, 1)
        fill.Size = UDim2.fromScale(alpha, 1)
        local shown = tostring(current)
    if (options.Step or 0) > 0 and (options.Step or 0) < 1 then
        shown = string.format("%.2f", current)
    end
    readout.Text = shown .. (options.Unit or "")
    end
    applyVisual()

    local function setFromX(x)
        local absX = bar.AbsolutePosition.X
        local width = math.max(1, bar.AbsoluteSize.X)
        local alpha = math.clamp((x - absX) / width, 0, 1)
        local raw = minimum + alpha * span()
        local step = options.Step or 0
        if step > 0 then raw = minimum + math.floor((raw - minimum) / step + 0.5) * step end
        current = math.clamp(raw, minimum, maximum)
        applyVisual()
    end

    slider.InputBegan:Connect(function(input)
        if input.UserInputType ~= Enum.UserInputType.MouseButton1
            and input.UserInputType ~= Enum.UserInputType.Touch then return end
        setFromX(input.Position.X)
    end)

    slider.InputChanged:Connect(function(input)
        if input.UserInputType ~= Enum.UserInputType.MouseMovement
            and input.UserInputType ~= Enum.UserInputType.Touch then return end
        if UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)
            or input.UserInputType == Enum.UserInputType.Touch then
            setFromX(input.Position.X)
        end
    end)

    slider.MouseButton1Up:Connect(function()
        if options.OnCommit then options.OnCommit(current) end
    end)

    local field = {}
    field.Row = row
    function field.SetValue(value)
        current = tonumber(value) or minimum
        applyVisual()
    end
    function field.SetHint(text)
        hint.Text = text
    end
    return field
end

function Kit.Divider(parent, order)
    return Kit.Create("Frame", {
        Size = UDim2.new(1, 0, 0, 1),
        BackgroundColor3 = Kit.Palette.StrokeDim,
        BackgroundTransparency = 0.6,
        BorderSizePixel = 0,
        LayoutOrder = order or 0,
    }, parent)
end

return Kit
