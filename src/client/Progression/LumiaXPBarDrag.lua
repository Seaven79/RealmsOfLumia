-- REALMS OF LUMIA V16 | Reliable XP bar dragging and persistence
-- Keeps the V14 action-bar drag controller untouched. Only the XP bar uses this.
local UIS = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local workspace = game:GetService("Workspace")
local Drag = {}

local function viewportSize()
    local camera = workspace.CurrentCamera
    return camera and camera.ViewportSize or Vector2.new(0, 0)
end
-- AbsolutePosition is screen space; Position is relative to the owning ScreenGui,
-- which starts BELOW the topbar unless the gui ignores the inset. Converting is
-- what keeps a grab from shifting the element by the inset (~36px).
local function toGuiSpace(element, absX, absY)
    local gui = element:FindFirstAncestorWhichIsA("ScreenGui")
    if gui and not gui.IgnoreGuiInset then
        local inset = GuiService:GetGuiInset()
        return absX - inset.X, absY - inset.Y
    end
    return absX, absY
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
    local mouseStart, panelStart, grabOffset
    local revision = 0
    local hadMoved = false
    local connections = {}
    local active = true

    local function clampPixels(x, y)
        local screen = viewportSize()
        if screen.X <= 0 or screen.Y <= 0 then return x, y end
        return math.clamp(x, 0, math.max(0, screen.X - panel.AbsoluteSize.X)),
            math.clamp(y, 0, math.max(0, screen.Y - panel.AbsoluteSize.Y))
    end
    -- Takes ABSOLUTE screen coordinates and writes them into the panel's own
    -- coordinate space, so the element lands exactly where the cursor is rather
    -- than being offset by an anchor or a topbar inset.
    local function moveTo(absX, absY)
        absX, absY = clampPixels(absX, absY)
        local gx, gy = toGuiSpace(panel, absX, absY)
        panel.AnchorPoint = Vector2.new(0, 0)
        panel.Position = UDim2.fromOffset(math.round(gx), math.round(gy))
    end
    -- Places the panel using SCALE, so resizing the window keeps it in the same
    -- relative spot instead of stranding it at a stale pixel offset. The upper
    -- bound accounts for the panel's own size, so a saved 0.95 cannot push the
    -- bar off the right edge of a narrower window.
    local function moveToScale(nx, ny)
        local screen = viewportSize()
        if screen.X < 1 or screen.Y < 1 then return end
        local size = panel.AbsoluteSize
        local maxX = math.max(0, (screen.X - math.max(1, size.X)) / screen.X)
        local maxY = math.max(0, (screen.Y - math.max(1, size.Y)) / screen.Y)
        panel.AnchorPoint = Vector2.new(0, 0)
        panel.Position = UDim2.fromScale(
            math.clamp(nx, 0, maxX), math.clamp(ny, 0, maxY))
    end
    -- Canonical placement: the player's INTENT, unclamped. The clamped value is
    -- only what gets displayed. Deriving the canonical value from the displayed
    -- position would let a temporary small window overwrite a fullscreen layout
    -- permanently, which is exactly the bug this guards against.
    local savedX, savedY = nil, nil
    local function displayPlacement()
        if savedX == nil then return end
        moveToScale(savedX, savedY)
    end
    local function applySaved(pos)
        if not valid(pos) or dragging then return end
        savedX, savedY = pos.X, pos.Y
        displayPlacement()
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

    local function persist(nx, ny)
        local screen = viewportSize()
        if screen.X < 1 or screen.Y < 1 then return end
        local x = math.clamp(nx, 0, 1)
        local y = math.clamp(ny, 0, 1)
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
        -- Normalise the anchor at grab time and remember where inside the panel the
        -- grab happened. The panel then tracks the cursor by that offset, so it can
        -- never jump above or below the pointer when the drag starts.
        local abs = panel.AbsolutePosition
        panelStart = abs
        local gx, gy = toGuiSpace(panel, abs.X, abs.Y)
        panel.AnchorPoint = Vector2.new(0, 0)
        panel.Position = UDim2.fromOffset(math.round(gx), math.round(gy))
        grabOffset = Vector2.new(mouse.X - abs.X, mouse.Y - abs.Y)
    end)
    connections[#connections + 1] = UIS.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            local mouse = UIS:GetMouseLocation()
            local delta = mouse - mouseStart
            if delta.Magnitude > 3 then hadMoved = true end
            -- Grab-offset tracking: the grabbed point stays exactly under the cursor.
            moveTo(mouse.X - grabOffset.X, mouse.Y - grabOffset.Y)
        end
    end)
    connections[#connections + 1] = UIS.InputEnded:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
            if hadMoved then
                -- Record intent from where it was dropped, then display it clamped.
                local screen = viewportSize()
                if screen.X >= 1 and screen.Y >= 1 then
                    local pos = panel.AbsolutePosition
                    savedX = math.clamp(pos.X / screen.X, 0, 1)
                    savedY = math.clamp(pos.Y / screen.Y, 0, 1)
                    displayPlacement()
                    persist(savedX, savedY)
                end
            end
        end
    end)
    -- A resize only changes what is DISPLAYED. The canonical placement is never
    -- recomputed from the clamped position, so a small window cannot erase it.
    local camera = workspace.CurrentCamera
    if camera then
        connections[#connections + 1] = camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
            if dragging then return end
            local screen = viewportSize()
            if screen.X < 1 or screen.Y < 1 then return end
            if savedX == nil then
                local pos = panel.AbsolutePosition
                savedX, savedY = pos.X / screen.X, pos.Y / screen.Y
            end
            displayPlacement()
        end)
    end
    panel.Destroying:Connect(function()
        active = false
        for _, connection in ipairs(connections) do connection:Disconnect() end
    end)
end

return Drag
