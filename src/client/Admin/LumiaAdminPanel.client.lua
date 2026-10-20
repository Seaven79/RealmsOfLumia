-- REALMS OF LUMIA | OWNER ADMIN PANEL (client)
-- Renders the shared AdminSchema. Contains no balance logic: it reads values
-- from the server, marks edits as "dirty", and sends them back for validation.
-- Non-owners never receive state, so the panel cannot even be inspected.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer

local lumia = ReplicatedStorage:WaitForChild("Lumia", 60)
if not lumia then
    warn("[Lumia - Admin Panel] Lumia folder missing")
    return
end

local network = lumia:WaitForChild("AdminNetwork", 30)
if not network then
    warn("[Lumia - Admin Panel] Admin bridge unavailable; panel disabled")
    return
end

local request = network:WaitForChild("AdminRequest", 30)
if not request or not request:IsA("RemoteFunction") then
    warn("[Lumia - Admin Panel] AdminRequest missing; panel disabled")
    return
end

local Shared = lumia:WaitForChild("Shared")
local Schema = require(Shared:WaitForChild("Admin"):WaitForChild("AdminSchema"))
local Kit = require(script.Parent:WaitForChild("LumiaAdminKit"))

local Palette = Kit.Palette
-- F7 opens the panel. The Ctrl+Shift+A combo is kept as a fallback because
-- Studio can claim function keys during playtests; both call the same toggle.
local TOGGLE_KEY = Enum.KeyCode.F7
local COMBO_KEY = Enum.KeyCode.A

local function isToggleRequest(input)
    if input.KeyCode == TOGGLE_KEY then return true end
    if input.KeyCode == COMBO_KEY
        and UserInputService:IsKeyDown(Enum.KeyCode.LeftControl)
        and UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then
        return true
    end
    return false
end

--------------------------------------------------------------------------------
-- Shell
--------------------------------------------------------------------------------

local gui = Kit.MakeGui("LumiaAdminPanel", 90)
gui.Enabled = false

-- Forward declaration: the launcher button is created before open() is defined.
local open

-- Always-on launcher. Hidden until the server confirms ownership, so ordinary
-- players never see an admin button. This exists because Studio intercepts
-- function keys during playtests, which makes a keybind an unreliable opener.
local launcherGui = Kit.MakeGui("LumiaAdminLauncher", 92)
launcherGui.Enabled = false
-- IgnoreGuiInset = false leaves room for Roblox's topbar. With it true, a
-- button near the top-left corner renders *behind* the Roblox interface.
launcherGui.IgnoreGuiInset = false

local launcherDrag = {
    active = false,
    moved = false,
    startInput = nil,
    startPos = nil,
}

local launcherButton
launcherButton = Kit.Button({
    Text = "⠿  ⚙ ADMIN",
    Size = UDim2.fromOffset(126, 32),
    Position = UDim2.fromOffset(12, 12),
    BackgroundColor3 = Palette.Panel,
    TextColor3 = Palette.Gold,
    StrokeColor = Palette.Stroke,
    TextSize = 14,
}, launcherGui, function()
    -- A drag that ended on the button must not also toggle the panel.
    if launcherDrag.moved then
        launcherDrag.moved = false
        return
    end
    if gui.Enabled then
        gui.Enabled = false
        launcherButton.Text = "⠿  ⚙ ADMIN"
        return
    end
    open()
end)

-- Drag the launcher anywhere on screen. Kept off Kit.MakeDraggable because
-- that helper would fight the button's own click handler.
launcherButton.InputBegan:Connect(function(input)
    if input.UserInputType ~= Enum.UserInputType.MouseButton1
        and input.UserInputType ~= Enum.UserInputType.Touch then
        return
    end
    launcherDrag.active = true
    launcherDrag.moved = false
    launcherDrag.startInput = input.Position
    launcherDrag.startPos = launcherButton.Position
end)

UserInputService.InputChanged:Connect(function(input)
    if not launcherDrag.active then return end
    if input.UserInputType ~= Enum.UserInputType.MouseMovement
        and input.UserInputType ~= Enum.UserInputType.Touch then
        return
    end

    local delta = input.Position - launcherDrag.startInput
    if not launcherDrag.moved then
        if math.abs(delta.X) + math.abs(delta.Y) < 5 then return end
        launcherDrag.moved = true
    end

    local camera = workspace.CurrentCamera
    local viewport = camera and camera.ViewportSize or Vector2.new(1280, 720)
    local startPos = launcherDrag.startPos
    local newX = math.clamp(startPos.X.Offset + delta.X, 0,
        math.max(0, viewport.X - launcherButton.AbsoluteSize.X))
    local newY = math.clamp(startPos.Y.Offset + delta.Y, 0,
        math.max(0, viewport.Y - launcherButton.AbsoluteSize.Y))

    launcherButton.Position = UDim2.new(startPos.X.Scale, newX, startPos.Y.Scale, newY)
end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
        launcherDrag.active = false
    end
end)

print("[Lumia - Admin Panel] loaded • checking owner access")

local toast = Kit.Toast(gui)

local root = Kit.Create("Frame", {
    Name = "Window",
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(0.5, 0.5),
    Size = UDim2.fromOffset(1120, 780),
    BackgroundColor3 = Palette.Screen,
    BackgroundTransparency = 0.04,
    BorderSizePixel = 0,
}, gui)
Kit.Corner(root, 14)
Kit.Stroke(root, Palette.Stroke, 1.5, 0.25)

local titleBar = Kit.Create("Frame", {
    Name = "TitleBar",
    Size = UDim2.new(1, 0, 0, 46),
    BackgroundColor3 = Palette.Panel,
    BackgroundTransparency = 0.15,
    BorderSizePixel = 0,
}, root)
Kit.Corner(titleBar, 14)

Kit.Create("TextLabel", {
    Text = "◈  LUMIA ADMIN",
    Font = Kit.FontDisplay,
    TextSize = 20,
    TextColor3 = Palette.Gold,
    BackgroundTransparency = 1,
    Position = UDim2.fromOffset(18, 0),
    Size = UDim2.fromOffset(240, 46),
    TextXAlignment = Enum.TextXAlignment.Left,
}, titleBar)

local ownerLabel = Kit.Create("TextLabel", {
    Text = "",
    Font = Kit.Font,
    TextSize = 14,
    TextColor3 = Palette.Dim,
    BackgroundTransparency = 1,
    Position = UDim2.fromOffset(250, 0),
    Size = UDim2.new(1, -420, 0, 46),
    TextXAlignment = Enum.TextXAlignment.Left,
}, titleBar)

local closeButton = Kit.Button({
    Text = "✕",
    Size = UDim2.fromOffset(30, 30),
    BackgroundColor3 = Palette.PanelAlt,
    TextColor3 = Palette.Dim,
}, titleBar, function()
    gui.Enabled = false
end)
closeButton.AnchorPoint = Vector2.new(1, 0.5)
closeButton.Position = UDim2.new(1, -12, 0.5, 0)

Kit.MakeDraggable(titleBar, root)

local body = Kit.Create("Frame", {
    Name = "Body",
    Position = UDim2.fromOffset(0, 46),
    Size = UDim2.new(1, 0, 1, -96),
    BackgroundTransparency = 1,
}, root)

--------------------------------------------------------------------------------
-- Section rail
--------------------------------------------------------------------------------

local rail = Kit.Create("Frame", {
    Name = "Rail",
    Size = UDim2.fromOffset(232, 0),
    BackgroundColor3 = Palette.Rail,
    BackgroundTransparency = 0.1,
    BorderSizePixel = 0,
}, body)
rail.Size = UDim2.new(0, 250, 1, 0)

local search = Kit.Create("TextBox", {
    Text = "",
    PlaceholderText = "Search settings…",
    Font = Kit.Font,
    TextSize = 14,
    TextColor3 = Palette.Text,
    PlaceholderColor3 = Palette.Dim,
    BackgroundColor3 = Palette.Panel,
    BorderSizePixel = 0,
    ClearTextOnFocus = false,
    Position = UDim2.fromOffset(12, 12),
    Size = UDim2.new(1, -24, 0, 30),
    TextXAlignment = Enum.TextXAlignment.Left,
}, rail)
Kit.Corner(search, 6)
Kit.Stroke(search, Palette.StrokeDim, 1)
Kit.Padding(search, 8, 8, 0, 0)

local sectionList = Kit.Create("Frame", {
    Position = UDim2.fromOffset(12, 52),
    Size = UDim2.new(1, -24, 1, -64),
    BackgroundTransparency = 1,
}, rail)
Kit.Create("UIListLayout", {
    Padding = UDim.new(0, 6),
    SortOrder = Enum.SortOrder.LayoutOrder,
}, sectionList)

--------------------------------------------------------------------------------
-- Content pane
--------------------------------------------------------------------------------

-- Only sections without Hidden render. The per-item authoring sections stay in
-- the schema (the server still validates them) but are hidden from the UI.
local visibleSections = {}
for _, section in ipairs(Schema.Sections) do
    if not section.Hidden then
        visibleSections[#visibleSections + 1] = section
    end
end

local railWidth = 250
if #visibleSections <= 1 then
    -- A single tab does not need a navigation rail; give the space back to the
    -- content so labels and sliders render larger.
    railWidth = 0
    rail.Visible = false
end

local content = Kit.Create("Frame", {
    Position = UDim2.fromOffset(railWidth, 0),
    Size = UDim2.new(1, -railWidth, 1, 0),
    BackgroundTransparency = 1,
}, body)

local sectionTitle = Kit.Create("TextLabel", {
    Text = "",
    Font = Kit.FontBold,
    TextSize = 22,
    TextColor3 = Palette.Text,
    BackgroundTransparency = 1,
    Position = UDim2.fromOffset(20, 14),
    Size = UDim2.new(1, -40, 0, 22),
    TextXAlignment = Enum.TextXAlignment.Left,
}, content)

local sectionBlurb = Kit.Create("TextLabel", {
    Text = "",
    Font = Kit.Font,
    TextSize = 14,
    TextColor3 = Palette.Dim,
    BackgroundTransparency = 1,
    Position = UDim2.fromOffset(20, 38),
    Size = UDim2.new(1, -40, 0, 16),
    TextXAlignment = Enum.TextXAlignment.Left,
    TextWrapped = false,
    TextTruncate = Enum.TextTruncate.AtEnd,
}, content)

local scrollerHolder = Kit.Create("Frame", {
    Position = UDim2.fromOffset(16, 62),
    Size = UDim2.new(1, -32, 1, -70),
    BackgroundTransparency = 1,
}, content)
local scroller = Kit.Scroller(scrollerHolder)

--------------------------------------------------------------------------------
-- Footer
--------------------------------------------------------------------------------

local footer = Kit.Create("Frame", {
    Name = "Footer",
    AnchorPoint = Vector2.new(0, 1),
    Position = UDim2.new(0, 0, 1, 0),
    Size = UDim2.new(1, 0, 0, 50),
    BackgroundColor3 = Palette.Panel,
    BackgroundTransparency = 0.2,
    BorderSizePixel = 0,
}, root)
Kit.Corner(footer, 12)

local statusLabel = Kit.Create("TextLabel", {
    Text = "Connecting…",
    Font = Kit.Font,
    TextSize = 14,
    TextColor3 = Palette.Dim,
    BackgroundTransparency = 1,
    Position = UDim2.fromOffset(18, 0),
    Size = UDim2.new(1, -360, 0, 50),
    TextXAlignment = Enum.TextXAlignment.Left,
}, footer)

local applyButton = Kit.Button({
    Text = "Apply  (0)",
    Size = UDim2.fromOffset(140, 32),
    BackgroundColor3 = Color3.fromRGB(34, 52, 42),
    TextColor3 = Palette.Good,
    StrokeColor = Palette.Good,
}, footer, function() end)
applyButton.AnchorPoint = Vector2.new(1, 0.5)
applyButton.Position = UDim2.new(1, -14, 0.5, 0)

local revertButton = Kit.Button({
    Text = "Revert",
    Size = UDim2.fromOffset(90, 32),
}, footer, function() end)
revertButton.AnchorPoint = Vector2.new(1, 0.5)
revertButton.Position = UDim2.new(1, -162, 0.5, 0)

local refreshButton = Kit.Button({
    Text = "Refresh",
    Size = UDim2.fromOffset(90, 32),
}, footer, function() end)
refreshButton.AnchorPoint = Vector2.new(1, 0.5)
refreshButton.Position = UDim2.new(1, -260, 0.5, 0)

-- Apply/Revert only make sense for batched field edits. Global sliders save on
-- release, so hide the pair when no field section is visible.
local hasFieldSections = false
for _, section in ipairs(visibleSections) do
    if section.Kind == "fields" then hasFieldSections = true end
end
if not hasFieldSections then
    applyButton.Visible = false
    revertButton.Visible = false
    refreshButton.Position = UDim2.new(1, -14, 0.5, 0)
end

--------------------------------------------------------------------------------
-- State
--------------------------------------------------------------------------------

local state = nil
local dirty = {}
local activeSection = Schema.Sections[1] and Schema.Sections[1].Id or "progression"
local selectedMonster = nil
local searchTerm = ""
local countdown = 0

local function dirtyCount()
    local count = 0
    for _ in pairs(dirty) do count = count + 1 end
    return count
end

local function updateFooter(message, kind)
    local count = dirtyCount()
    applyButton.Text = string.format("Apply  (%d)", count)
    Kit.SetDisabled(applyButton, count == 0)

    if message then
        statusLabel.Text = message
        statusLabel.TextColor3 = kind == Palette.Bad and Palette.Bad
            or (kind == Palette.Good and Palette.Good or Palette.Dim)
        return
    end

    if not state then
        statusLabel.Text = "Connecting…"
        return
    end

    local persistence = state.Persistence or {}
    local bits = {}
    bits[#bits + 1] = persistence.Balance and "balance saved" or "balance NOT saving"
    bits[#bits + 1] = persistence.MobTuning and "mobs saved" or "mobs NOT saving"
    bits[#bits + 1] = "rev " .. tostring(state.Revision or 0)
    local text = table.concat(bits, "  •  ")
    if count > 0 then
        text = string.format("%d unsaved change%s  •  %s", count, count == 1 and "" or "s", text)
    end
    statusLabel.Text = text
    statusLabel.TextColor3 = (persistence.Balance == false) and Palette.Warn or Palette.Dim
end

local function clearScroller()
    for _, child in ipairs(scroller:GetChildren()) do
        if child:IsA("GuiObject") then child:Destroy() end
    end
end

local function markDirty(fieldId, value)
    local field = Schema.GetField(fieldId)
    if not field then return end
    if value == state.Values[fieldId] then
        dirty[fieldId] = nil
    else
        dirty[fieldId] = value
    end
    updateFooter()
end

local function invoke(action, payload)
    local ok, response = pcall(function()
        return request:InvokeServer(action, payload)
    end)
    if not ok then
        toast("Server did not respond", "bad")
        return nil
    end
    if type(response) ~= "table" then
        toast("Malformed server response", "bad")
        return nil
    end
    if response.Authorized == false then
        gui.Enabled = false
        warn("[Lumia - Admin Panel] " .. tostring(response.Reason or "Not authorized"))
        return nil
    end
    if response.State then
        state = response.State
        countdown = tonumber(state.Difficulty and state.Difficulty.SecondsRemaining) or 0
    end
    return response
end

--------------------------------------------------------------------------------
-- Renderers
--------------------------------------------------------------------------------

local renderSection

local function renderFields(section)
    local fields = Schema.BySection[section.Id] or {}
    local order = 0
    local shown = 0

    for _, field in ipairs(fields) do
        local label = tostring(field.Label or field.Id):lower()
        local hint = tostring(field.Hint or ""):lower()
        if searchTerm == "" or label:find(searchTerm, 1, true) or hint:find(searchTerm, 1, true)
            or tostring(field.Id):lower():find(searchTerm, 1, true) then
            order = order + 1
            shown = shown + 1
            local value = dirty[field.Id]
            if value == nil then value = state.Values[field.Id] end
            if value == nil then value = field.Default end

            Kit.NumberField(scroller, {
                Id = field.Id,
                Label = field.Label,
                Hint = field.Hint or string.format("%s  •  default %s",
                    tostring(field.Category), tostring(field.Default)),
                Unit = field.Unit,
                Min = field.Min,
                Max = field.Max,
                Integer = field.Integer,
                Value = value,
                LayoutOrder = order,
                IsOverridden = state.Overridden and state.Overridden[field.Id] == true,
                OnCommit = function(newValue)
                    markDirty(field.Id, newValue)
                end,
                OnReset = function()
                    local response = invoke("Reset", { Ids = { field.Id } })
                    if response and response.Ok then
                        dirty[field.Id] = nil
                        toast("Reset " .. tostring(field.Label), "good")
                        renderSection(section)
                    elseif response then
                        toast(tostring(response.Reason or "Reset failed"), "bad")
                    end
                end,
            })
        end
    end

    if shown == 0 then
        Kit.Create("TextLabel", {
            Text = "No settings match \"" .. searchTerm .. "\"",
            Font = Kit.Font,
            TextSize = 14,
            TextColor3 = Palette.Dim,
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 40),
            TextXAlignment = Enum.TextXAlignment.Left,
            LayoutOrder = 1,
        }, scroller)
    end
end

local function renderMobStats(section)
    local monsters = state.Monsters
    if not monsters or not monsters.Monsters then
        Kit.Create("TextLabel", {
            Text = "Monster tuning service is not reporting. Check the server Output for DataStore errors.",
            Font = Kit.Font,
            TextSize = 14,
            TextColor3 = Palette.Warn,
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 44),
            TextWrapped = true,
            TextXAlignment = Enum.TextXAlignment.Left,
            LayoutOrder = 1,
        }, scroller)
        return
    end

    local ids = monsters.MonsterIds or Schema.MonsterIds
    if not selectedMonster then selectedMonster = ids[1] end

    local order = 1
    Kit.Header("MONSTER", scroller, order)
    order = order + 1

    local picker = Kit.Create("Frame", {
        Size = UDim2.new(1, 0, 0, 34),
        BackgroundTransparency = 1,
        LayoutOrder = order,
    }, scroller)
    order = order + 1
    Kit.Create("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        Padding = UDim.new(0, 6),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, picker)

    for index, monsterId in ipairs(ids) do
        local entry = monsters.Monsters[monsterId]
        local isActive = monsterId == selectedMonster
        local button = Kit.Button({
            Text = entry and entry.Name or monsterId,
            Size = UDim2.fromOffset(120, 30),
            TextSize = 13,
            BackgroundColor3 = isActive and Color3.fromRGB(38, 50, 68) or Palette.Panel,
            TextColor3 = isActive and Palette.Accent or Palette.Dim,
            StrokeColor = isActive and Palette.Accent or Palette.StrokeDim,
        }, picker, function()
            selectedMonster = monsterId
            renderSection(section)
        end)
        button.LayoutOrder = index
    end

    local record = monsters.Monsters[selectedMonster]
    if not record then return end

    order = order + 1
    Kit.Divider(scroller, order)
    order = order + 1

    for _, spec in ipairs(monsters.StatFields or {}) do
        local stats = record.Stats or {}
        local value = stats[spec.Key]
        if value == nil then value = spec.Min end
        local step = spec.Integer and 1 or 0.1

        Kit.SliderField(scroller, {
            Label = spec.Label,
            Hint = string.format("%s  •  %s to %s", spec.Key,
                tostring(spec.Min), tostring(spec.Max)),
            Min = spec.Min,
            Max = spec.Max,
            Step = step,
            Value = value,
            LayoutOrder = order,
            OnCommit = function(newValue)
                if not spec.Integer then
                    newValue = math.floor(newValue * 100 + 0.5) / 100
                end
                local response = invoke("MobStat", {
                    MonsterId = selectedMonster,
                    Key = spec.Key,
                    Value = newValue,
                })
                if response and response.Ok then
                    toast(string.format("%s %s = %s", record.Name, spec.Label,
                        tostring(newValue)), "good")
                    renderSection(section)
                elseif response then
                    toast(tostring(response.Reason or "Rejected"), "bad")
                end
            end,
        })
        order = order + 1
    end

    order = order + 1
    Kit.Button({
        Text = "Reset all stats for " .. tostring(record.Name),
        Size = UDim2.new(1, 0, 0, 30),
        LayoutOrder = order,
        TextColor3 = Palette.Warn,
    }, scroller, function()
        for _, spec in ipairs(monsters.StatFields or {}) do
            invoke("MobStat", { MonsterId = selectedMonster, Key = spec.Key, Value = nil })
        end
        toast("Reverted " .. tostring(record.Name) .. " to config values", "good")
        invoke("State")
        renderSection(section)
    end)
end

local function renderDifficulty(section)
    local report = state.Difficulty or {}
    local order = 1

    local activeIntensity = 1
    if report.Active and report.Values and report.Values.Health then
        activeIntensity = tonumber(report.Values.Health.Scale) or 1
    end

    Kit.Header("GLOBAL SPAWN CURVE", scroller, order)
    order = order + 1

    Kit.Create("TextLabel", {
        Text = "Affects newly spawned monsters only. Saved monster stats are untouched. Trials expire after 8 minutes.",
        Font = Kit.Font,
        TextSize = 14,
        TextColor3 = Palette.Dim,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 30),
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
        LayoutOrder = order,
    }, scroller)
    order = order + 1

    Kit.SliderField(scroller, {
        Label = "Difficulty intensity",
        Hint = "0.50 = gentle  •  1.00 = original balance  •  2.00 = hardcore",
        Min = 0.5,
        Max = 2,
        Step = 0.05,
        Value = activeIntensity,
        LayoutOrder = order,
        OnCommit = function(value)
            local response = invoke("Difficulty", { Intensity = value })
            if response and response.Ok then
                toast(string.format("Trial started at %.2f", value), "good")
                renderSection(section)
            elseif response then
                toast(tostring(response.Reason or "Rejected"), "bad")
            end
        end,
    })
    order = order + 1

    local presets = Kit.Create("Frame", {
        Size = UDim2.new(1, 0, 0, 32),
        BackgroundTransparency = 1,
        LayoutOrder = order,
    }, scroller)
    order = order + 1
    Kit.Create("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        Padding = UDim.new(0, 6),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, presets)

    for index, preset in ipairs({
        { Label = "Gentle", Value = 0.70 },
        { Label = "Classic", Value = 1.00 },
        { Label = "Hardcore", Value = 1.40 },
    }) do
        local button = Kit.Button({
            Text = preset.Label,
            Size = UDim2.fromOffset(96, 30),
            TextSize = 13,
        }, presets, function()
            local response = invoke("Difficulty", { Intensity = preset.Value })
            if response and response.Ok then
                toast(preset.Label .. " trial started", "good")
                renderSection(section)
            elseif response then
                toast(tostring(response.Reason or "Rejected"), "bad")
            end
        end)
        button.LayoutOrder = index
    end

    local statusText = "No trial running"
    if report.Active then
        local remaining = countdown > 0 and countdown or 0
        statusText = string.format("Trial ACTIVE  •  %s remaining  •  source: %s",
            string.format("%d:%02d", math.floor(remaining / 60), remaining % 60),
            tostring(report.Source or "?"))
    else
        statusText = "No trial running  •  source: " .. tostring(report.Source or "published config")
    end

    Kit.Create("TextLabel", {
        Text = statusText,
        Font = Kit.FontBold,
        TextSize = 13,
        TextColor3 = report.Active and Palette.Good or Palette.Dim,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 26),
        TextXAlignment = Enum.TextXAlignment.Left,
        LayoutOrder = order,
    }, scroller)
    order = order + 1

    if report.Active then
        Kit.Button({
            Text = "Stop trial",
            Size = UDim2.new(1, 0, 0, 30),
            LayoutOrder = order,
            TextColor3 = Palette.Bad,
        }, scroller, function()
            local response = invoke("Difficulty", { Stop = true })
            if response and response.Ok then
                toast("Trial stopped", "good")
                renderSection(section)
            end
        end)
    end

    if report.CanTest == false then
        Kit.Create("TextLabel", {
            Text = "Difficulty trials are restricted to Studio or a private server.",
            Font = Kit.Font,
            TextSize = 13,
            TextColor3 = Palette.Warn,
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 24),
            TextXAlignment = Enum.TextXAlignment.Left,
            LayoutOrder = order + 1,
        }, scroller)
    end
end

local function renderGlobal(section)
    local global = state.Global or {}
    local dials = global.Dials or {}
    local presets = global.Presets or {}
    local values = global.Values or {}
    local order = 1

    -- Active preset description, shown as a caption under the buttons.
    local activeHint = "Custom mix"
    for _, preset in ipairs(presets) do
        if preset.Id == global.Preset then activeHint = preset.Hint or preset.Label end
    end

    Kit.Header("TEMPLATE", scroller, order)
    order = order + 1

    local presetRow = Kit.Create("Frame", {
        Size = UDim2.new(1, 0, 0, 34),
        BackgroundTransparency = 1,
        LayoutOrder = order,
    }, scroller)
    order = order + 1
    Kit.Create("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        Padding = UDim.new(0, 6),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, presetRow)

    for index, preset in ipairs(presets) do
        local isActive = preset.Id == global.Preset
        local button = Kit.Button({
            Text = preset.Label,
            Size = UDim2.fromOffset(132, 40),
            TextSize = 14,
            BackgroundColor3 = isActive and Color3.fromRGB(34, 48, 66) or Palette.Panel,
            TextColor3 = isActive and Palette.Gold or Palette.Dim,
            StrokeColor = isActive and Palette.Stroke or Palette.StrokeDim,
        }, presetRow, function()
            local response = invoke("Global", { Preset = preset.Id })
            if response and response.Ok then
                toast("Template applied: " .. preset.Label, "good")
                renderSection(section)
            elseif response then
                toast(tostring(response.Reason or "Rejected"), "bad")
            end
        end)
        button.LayoutOrder = index
    end

    Kit.Create("TextLabel", {
        Text = activeHint,
        Font = Kit.Font,
        TextSize = 14,
        TextColor3 = Palette.Dim,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 18),
        TextXAlignment = Enum.TextXAlignment.Left,
        LayoutOrder = order,
    }, scroller)
    order = order + 1

    Kit.Header("MASTER DIALS", scroller, order)
    order = order + 1

    for _, dial in ipairs(dials) do
        Kit.SliderField(scroller, {
            Label = dial.Label,
            Hint = dial.Hint,
            Min = dial.Min,
            Max = dial.Max,
            Step = dial.Step or 0.05,
            Unit = dial.Unit or "x",
            Value = values[dial.Id] or dial.Default,
            LayoutOrder = order,
            OnCommit = function(value)
                local response = invoke("Global", { Id = dial.Id, Value = value })
                if response and response.Ok then
                    toast(string.format("%s = %.2fx", dial.Label, value), "good")
                    renderSection(section)
                elseif response then
                    toast(tostring(response.Reason or "Rejected"), "bad")
                end
            end,
        })
        order = order + 1
    end

    Kit.Header("PREVIEW — WHAT PLAYERS GET NOW", scroller, order)
    order = order + 1

    for _, row in ipairs(global.Preview or {}) do
        local card = Kit.Create("Frame", {
            Size = UDim2.new(1, 0, 0, 62),
            BackgroundColor3 = Palette.Panel,
            BackgroundTransparency = 0.35,
            BorderSizePixel = 0,
            LayoutOrder = order,
        }, scroller)
        Kit.Corner(card, 8)

        Kit.Create("TextLabel", {
            Text = tostring(row.Name) .. (row.IsBoss and "   · BOSS" or ""),
            Font = Kit.FontBold,
            TextSize = 16,
            TextColor3 = row.IsBoss and Palette.Warn or Palette.Text,
            BackgroundTransparency = 1,
            Position = UDim2.fromOffset(14, 7),
            Size = UDim2.new(1, -28, 0, 20),
            TextXAlignment = Enum.TextXAlignment.Left,
        }, card)

        local parts = {
            string.format("HP %s → %s", tostring(row.BaseHealth), tostring(row.Health)),
            string.format("DMG %s → %s", tostring(row.BaseDamage), tostring(row.Damage)),
            string.format("XP %s → %s", tostring(row.BaseXP or 0), tostring(row.XP or 0)),
            string.format("Gold %s → %s", tostring(row.BaseGold or 0), tostring(row.Gold or 0)),
            string.format("≈%s hits (%s each)", tostring(row.HitsToKill or 0),
                tostring(row.HitDamage or 0)),
        }
        Kit.Create("TextLabel", {
            Text = table.concat(parts, "     "),
            Font = Kit.Font,
            TextSize = 14,
            TextColor3 = Palette.Dim,
            BackgroundTransparency = 1,
            Position = UDim2.fromOffset(14, 33),
            Size = UDim2.new(1, -28, 0, 20),
            TextXAlignment = Enum.TextXAlignment.Left,
            TextTruncate = Enum.TextTruncate.AtEnd,
        }, card)

        order = order + 1
    end

    Kit.Create("TextLabel", {
        Text = "Dials apply immediately to newly spawned monsters and to every quest turn-in. "
            .. "They never rewrite your authoring values, so setting 1.00x restores the shipped balance exactly.",
        Font = Kit.Font,
        TextSize = 14,
        TextColor3 = Palette.Dim,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 46),
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
        LayoutOrder = order,
    }, scroller)
end

-- Armed until this clock time; a second click inside the window commits.
local toolsArmedUntil = 0

local function renderTools(section)
    local order = 1

    Kit.Header("CHARACTER", scroller, order)
    order = order + 1

    Kit.Create("TextLabel", {
        Text = "Resets YOUR level to 1 and XP to 0. Gold, inventory, quests and achievements are untouched.",
        Font = Kit.Font,
        TextSize = 13,
        TextColor3 = Palette.Dim,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 34),
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
        LayoutOrder = order,
    }, scroller)
    order = order + 1

    local resetButton
    resetButton = Kit.Button({
        Text = "Reset level and XP",
        Size = UDim2.new(1, 0, 0, 40),
        BackgroundColor3 = Color3.fromRGB(48, 30, 30),
        TextColor3 = Palette.Bad,
        StrokeColor = Palette.Bad,
        TextSize = 15,
        LayoutOrder = order,
    }, scroller, function(button)
        local now = os.clock()
        if now > toolsArmedUntil then
            -- First click only arms the action.
            toolsArmedUntil = now + 5
            button.Text = "Click again to confirm (5s)"
            return
        end

        toolsArmedUntil = 0
        button.Text = "Resetting…"
        local response = invoke("ResetLevel")
        if response and response.Ok then
            local result = response.Result or {}
            toast(string.format("Level reset: %s (%s xp) → 1 (0 xp)",
                tostring(result.PreviousLevel), tostring(result.PreviousExperience)), "good")
            renderSection(section)
        elseif response then
            toast(tostring(response.Reason or "Reset failed"), "bad")
            button.Text = "Reset level and XP"
        else
            button.Text = "Reset level and XP"
        end
    end)

    order = order + 1
    Kit.Create("TextLabel", {
        Text = "The first click arms the button; the second click within 5 seconds performs the reset.",
        Font = Kit.Font,
        TextSize = 12,
        TextColor3 = Palette.Muted,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 20),
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
        LayoutOrder = order,
    }, scroller)
end

renderSection = function(section)
    clearScroller()
    sectionTitle.Text = string.upper(section.Label or section.Id)
    sectionBlurb.Text = section.Description or ""

    if not state then return end
    if section.Kind == "global" then
        renderGlobal(section)
    elseif section.Kind == "tools" then
        renderTools(section)
    elseif section.Kind == "mobstats" then
        renderMobStats(section)
    elseif section.Kind == "difficulty" then
        renderDifficulty(section)
    else
        renderFields(section)
    end
end

--------------------------------------------------------------------------------
-- Rail buttons
--------------------------------------------------------------------------------

local sectionButtons = {}
for index, section in ipairs(visibleSections) do
    local button = Kit.Button({
        Text = section.Advanced and ("   · " .. section.Label) or section.Label,
        Size = UDim2.new(1, 0, 0, 36),
        TextSize = 15,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextColor3 = section.Advanced and Palette.Dim or Palette.Text,
        BackgroundColor3 = Palette.Panel,
    }, sectionList, function()
        activeSection = section.Id
        for id, other in pairs(sectionButtons) do
            local isActive = id == activeSection
            local target = Schema.GetSection(id)
            other.TextColor3 = isActive and Palette.Accent
                or ((target and target.Advanced) and Palette.Dim or Palette.Text)
            other.BackgroundColor3 = isActive and Color3.fromRGB(30, 42, 58) or Palette.Panel
        end
        renderSection(section)
    end)
    button.LayoutOrder = index
    sectionButtons[section.Id] = button
end

--------------------------------------------------------------------------------
-- Actions
--------------------------------------------------------------------------------

search:GetPropertyChangedSignal("Text"):Connect(function()
    searchTerm = string.lower(search:GetText()):gsub("^%s+", ""):gsub("%s+$", "")
    local section = Schema.GetSection(activeSection)
    if section then renderSection(section) end
end)

applyButton.MouseButton1Click:Connect(function()
    local ops = {}
    for fieldId, value in pairs(dirty) do
        ops[#ops + 1] = { Id = fieldId, Value = value }
    end
    if #ops == 0 then
        toast("Nothing to apply", "warn")
        return
    end
    Kit.SetDisabled(applyButton, true)
    local response = invoke("Apply", { Ops = ops })
    if not response then
        updateFooter("Apply failed: no response", Palette.Bad)
        return
    end
    if response.Ok then
        dirty = {}
        local failures = response.Failures or {}
        if #failures > 0 then
            local first = failures[1]
            toast(string.format("Saved %d, %d rejected (%s)", response.Applied or 0,
                #failures, tostring(first and first.Reason or "?")), "warn")
        else
            toast(string.format("Saved %d change%s", response.Applied or 0,
                (response.Applied or 0) == 1 and "" or "s"), "good")
        end
        local section = Schema.GetSection(activeSection)
        if section then renderSection(section) end
    else
        toast(tostring(response.Reason or "Apply failed"), "bad")
    end
    updateFooter()
end)

revertButton.MouseButton1Click:Connect(function()
    dirty = {}
    local section = Schema.GetSection(activeSection)
    if section and state then renderSection(section) end
    updateFooter("Reverted unsaved changes", Palette.Dim)
    toast("Unsaved changes reverted", "good")
end)

refreshButton.MouseButton1Click:Connect(function()
    if invoke("State") then
        local section = Schema.GetSection(activeSection)
        if section then renderSection(section) end
        updateFooter()
        toast("State refreshed", "good")
    end
end)

--------------------------------------------------------------------------------
-- Open / close
--------------------------------------------------------------------------------

open = function()
    local response = invoke("State")
    if not response then
        warn("[Lumia - Admin Panel] Access denied or server unreachable")
        return
    end
    if not response.State then
        toast(tostring(response.Reason or "Access denied"), "bad")
        return
    end

    state = response.State
    dirty = {}
    countdown = tonumber(state.Difficulty and state.Difficulty.SecondsRemaining) or 0
    ownerLabel.Text = string.format("owner %d  •  schema v%d",
        tonumber(state.Server and state.Server.PlayerUserId) or 0, Schema.Version)

    local active = Schema.GetSection(activeSection) or Schema.Sections[1]
    sectionButtons[active.Id].TextColor3 = Palette.Accent
    sectionButtons[active.Id].BackgroundColor3 = Color3.fromRGB(30, 42, 58)

    gui.Enabled = true
    renderSection(active)
    updateFooter()

    launcherGui.Enabled = true
    launcherButton.Text = "✕  CLOSE"

    if not state.Persistence.Balance then
        toast("Balance DataStore unavailable — changes will not save", "warn")
    end
end

UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    if not isToggleRequest(input) then return end
    if UserInputService:GetFocusedTextBox() then return end

    if gui.Enabled then
        gui.Enabled = false
        return
    end
    open()
end)

-- Ownership probe: non-owners get no UI, no error, and no server log spam.
task.spawn(function()
    local ok, response = pcall(function()
        return request:InvokeServer("Ping")
    end)
    if not ok or type(response) ~= "table" or response.Authorized ~= true then
        print("[Lumia - Admin Panel] Not the owner; panel stays hidden")
        return
    end
    launcherGui.Enabled = true
    print("[Lumia - Admin Panel] Owner verified • click the ADMIN button or press F7 / Ctrl+Shift+A")
end)

-- No startup probe: non-owners never trigger a request. The panel asks the
-- server for state only when opened, and the server refuses non-owners.
-- No idle ticker. The curve-trial countdown was its only consumer and that UI
-- was replaced by the global dials, which persist instead of expiring. Every
-- client therefore runs zero background loops for this panel.
print("[Lumia - Admin Panel] ready • F7, Ctrl+Shift+A, or the ADMIN button")
