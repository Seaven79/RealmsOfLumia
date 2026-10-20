-- REALMS OF LUMIA V16 | Reliable XP bar dragging and persistence
-- Keeps the V14 action-bar drag controller untouched. Only the XP bar uses this.
local UIS = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local workspace = game:GetService("Workspace")
local Drag = {}

local function viewportSize()
    local camera = workspace.CurrentCamera
    return camera and camera.ViewportSize or Vector2.new(0, 0)
end
local function valid(value)
    return type(value) == "table" and type(value.X) == "number"
        and type(value.Y) == "number" and value.X == value.X and value.Y == value.Y
        and value.X >= 0 and value.X <= 1 and value.Y >= 0 and value.Y <= 1
end

function Drag.Attach(panel)
    assert(panel and panel:IsA("GuiObject"), "XP bar panel expected")
    panel.Active = true
    local network = ReplicatedStorage:WaitForChild("Lumia"):WaitForChild("XPBarLayoutNetwork", 30)
    if not network then
        warn("[Lumia V16] XP bar layout network missing; dragging remains local")
        return
    end
    local getRemote = network:WaitForChild("GetPosition", 12)
    local setRemote = network:WaitForChild("SetPosition", 12)
    if not getRemote or not setRemote then return end

    local dragging = false
    local mouseStart, panelStart
    local revision = 0
    local hadMoved = false
    local connections = {}
    local active = true

    -- Screen-space origin of the panel's PARENT. AbsolutePosition is screen space
    -- while Position is parent space, and the two differ by the topbar inset plus
    -- any nesting. Assigning one straight into the other made every drag begin with
    -- a jump of exactly that difference. Measuring a 1x1 probe beats assuming the
    -- offset is zero - and when it genuinely is zero, this changes nothing.
    local parentOffsetX, parentOffsetY = 0, 0
    local function measureParentOffset()
        local parent = panel.Parent
        if not parent then return end
        local probe = Instance.new("Frame")
        probe.Name = "LumiaGuiProbe"
        probe.Size = UDim2.fromOffset(1, 1)
        probe.Position = UDim2.fromOffset(0, 0)
        probe.BackgroundTransparency = 1
        probe.BorderSizePixel = 0
        probe.Parent = parent
        local abs = probe.AbsolutePosition
        parentOffsetX, parentOffsetY = abs.X, abs.Y
        probe:Destroy()
    end
    measureParentOffset()

    local function clampPixels(x, y)
        local screen = viewportSize()
        if screen.X <= 0 or screen.Y <= 0 then return x, y end
        return math.clamp(x, 0, math.max(0, screen.X - panel.AbsoluteSize.X)),
            math.clamp(y, 0, math.max(0, screen.Y - panel.AbsoluteSize.Y))
    end
    local function moveTo(x, y)
        x, y = clampPixels(x, y)
        panel.AnchorPoint = Vector2.new(0, 0)
        -- Screen space -> parent space, using the measured origin.
        panel.Position = UDim2.fromOffset(
            math.round(x - parentOffsetX), math.round(y - parentOffsetY))
    end
    local function applySaved(pos)
        if not valid(pos) or dragging then return end
        local screen = viewportSize()
        if screen.X <= 0 or screen.Y <= 0 then return end
        moveTo(pos.X * screen.X, pos.Y * screen.Y)
    end

    -- Wait for profile readiness and ignore a late server response if a local
    -- drag has already occurred. Never overwrite a player's fresh placement.
    task.spawn(function()
        for _ = 1, 24 do
            if not panel.Parent then return end
            local startRevision = revision
            local ok, result = pcall(function() return getRemote:InvokeServer() end)
            if ok and type(result) == "table" and result.Ok then
                if startRevision == revision then applySaved(result.Position) end
                return
            end
            task.wait(0.75)
        end
        warn("[Lumia V16] XP bar position was not loaded; using default")
    end)

    local function persist()
        local screen = viewportSize()
        if screen.X < 1 or screen.Y < 1 then return end
        local pos = panel.AbsolutePosition
        local x = math.clamp(pos.X / screen.X, 0, 1)
        local y = math.clamp(pos.Y / screen.Y, 0, 1)
        task.spawn(function()
            for attempt = 1, 4 do
                if not active then return end
                local ok, result = pcall(function()
                    return setRemote:InvokeServer(x, y)
                end)
                if ok and type(result) == "table" and result.Ok then
                    print(string.format("[Lumia V16] XP bar position saved (%.3f, %.3f)", x, y))
                    return
                end
                task.wait(0.4 + attempt * 0.25)
            end
            warn("[Lumia V16] XP bar save failed; check persistent profile and Output")
        end)
    end

    -- Use the GUI input event rather than checking gameProcessedEvent on UIS.
    -- GUI clicks can be marked processed, which made dragging seem broken.
    connections[#connections + 1] = panel.InputBegan:Connect(function(input)
        if dragging or not panel.Parent or UIS:GetFocusedTextBox() then return end
        if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
        local mouse = UIS:GetMouseLocation()
        dragging = true
        hadMoved = false
        revision += 1
        mouseStart = mouse
        panelStart = panel.AbsolutePosition
    end)
    connections[#connections + 1] = UIS.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            local delta = UIS:GetMouseLocation() - mouseStart
            if delta.Magnitude > 3 then hadMoved = true end
            moveTo(panelStart.X + delta.X, panelStart.Y + delta.Y)
        end
    end)
    connections[#connections + 1] = UIS.InputEnded:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
            if hadMoved then persist() end
        end
    end)
    panel.Destroying:Connect(function()
        active = false
        for _, connection in ipairs(connections) do connection:Disconnect() end
    end)
end

return Drag
