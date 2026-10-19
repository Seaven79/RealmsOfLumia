-- REALMS OF LUMIA - CAMERA-RELATIVE MOVEMENT AND PERSONAL KEYBINDS
-- W/S move forward/backward, A/D strafe; remappable in F10 > Movement.
-- While a Lumia combat Tool is equipped the avatar faces camera direction,
-- allowing backpedal/strafe without turning away from the enemy.
-- Touch and gamepad continue using Roblox's native control module.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ContextActionService = game:GetService("ContextActionService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local LumiaModalState = require(script.Parent.Parent:WaitForChild("UI"):WaitForChild("LumiaModalState"))
local controllers = script.Parent.Parent
local Theme = require(controllers:WaitForChild("UI"):WaitForChild("CharacterTheme"))
local Config = require(ReplicatedStorage:WaitForChild("Lumia")
    :WaitForChild("Shared"):WaitForChild("Players"):WaitForChild("MovementKeybindConfig"))
local remote = ReplicatedStorage:WaitForChild("Lumia")
    :WaitForChild("MovementNetwork"):WaitForChild("KeybindSettings")

local ACTION = "Lumia_KeyboardMovement"
local bindings = Config.CopyDefault()
player:SetAttribute("LumiaInteractKey", bindings.Interact)
local heldKeys = {}
local profileReady = false
local busy = false
local capturing = nil
local menuOpen = false
local combatHumanoid = nil
local oldAutoRotate = true

local function make(className, properties, parent)
    local instance = Instance.new(className)
    for name, value in pairs(properties) do
        instance[name] = value
    end
    instance.Parent = parent
    return instance
end

local gui = make("ScreenGui", {
    Name = "LumiaOptionsGui",
    ResetOnSpawn = false,
    IgnoreGuiInset = false,
    DisplayOrder = 20,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
}, playerGui)

-- Always visible, including for players who have not equipped a sword yet.
local opener = make("TextButton", {
    Name = "OptionsButton",
    AnchorPoint = Vector2.new(1, 0),
    Position = UDim2.new(1, -226, 0, 11), -- beside the top-right minimap; never overlaps quest tracker
    Size = UDim2.fromOffset(112, 36),
    BackgroundColor3 = Theme.Panel,
    BorderSizePixel = 0,
    Font = Enum.Font.GothamBold,
    Text = "OPTIONS  F10",
    TextSize = 12,
    TextColor3 = Theme.Gold,
}, gui)
make("UICorner", {CornerRadius = UDim.new(0, 8)}, opener)
make("UIStroke", {Color = Theme.Border, Thickness = 1}, opener)

local panel = make("Frame", {
    Name = "MovementOptions",
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(0.5, 0.5),
    Size = UDim2.new(1, -32, 0, 520),
    BackgroundColor3 = Theme.Background,
    BorderSizePixel = 0,
    Visible = false,
}, gui)
make("UISizeConstraint", {MaxSize = Vector2.new(520, 520), MinSize = Vector2.new(290, 520)}, panel)
make("UICorner", {CornerRadius = UDim.new(0, 12)}, panel)
make("UIStroke", {Color = Theme.Gold, Thickness = 1.3}, panel)

make("TextLabel", {
    Name = "Title",
    BackgroundTransparency = 1,
    Position = UDim2.fromOffset(20, 14),
    Size = UDim2.new(1, -80, 0, 31),
    Font = Enum.Font.GothamBold,
    Text = "REALMS OF LUMIA",
    TextColor3 = Theme.Gold,
    TextSize = 23,
    TextXAlignment = Enum.TextXAlignment.Left,
}, panel)
make("TextLabel", {
    BackgroundTransparency = 1,
    Position = UDim2.fromOffset(20, 46),
    Size = UDim2.new(1, -40, 0, 23),
    Font = Enum.Font.GothamMedium,
    Text = "OPTIONS  /  MOVEMENT & INTERACTION",
    TextColor3 = Theme.Secondary,
    TextSize = 13,
    TextXAlignment = Enum.TextXAlignment.Left,
}, panel)

local close = make("TextButton", {
    Position = UDim2.new(1, -47, 0, 16),
    Size = UDim2.fromOffset(30, 30),
    BackgroundColor3 = Theme.Slot,
    Font = Enum.Font.GothamBold,
    Text = "X",
    TextSize = 16,
    TextColor3 = Theme.White,
    BorderSizePixel = 0,
}, panel)
make("UICorner", {CornerRadius = UDim.new(0, 5)}, close)

make("TextLabel", {
    BackgroundTransparency = 1,
    Position = UDim2.fromOffset(20, 83),
    Size = UDim2.new(1, -40, 0, 35),
    Text = "Choose a binding. Talk, examine and loot use Right Mouse by default.",
    Font = Enum.Font.Gotham,
    TextColor3 = Theme.White,
    TextSize = 13,
    TextXAlignment = Enum.TextXAlignment.Left,
    TextWrapped = true,
}, panel)

local rows = {}
for index, action in ipairs(Config.Order) do
    local y = 125 + (index - 1) * 50
    local line = make("Frame", {
        Name = action .. "Row",
        BackgroundColor3 = Theme.Panel,
        BorderSizePixel = 0,
        Position = UDim2.new(0, 18, 0, y),
        Size = UDim2.new(1, -36, 0, 44),
    }, panel)
    make("UICorner", {CornerRadius = UDim.new(0, 6)}, line)
    make("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(14, 0),
        Size = UDim2.new(1, -148, 1, 0),
        Font = Enum.Font.GothamMedium,
        Text = Config.Labels[action],
        TextSize = 15,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextColor3 = Theme.White,
    }, line)
    local button = make("TextButton", {
        Name = action .. "Key",
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -10, 0.5, 0),
        Size = UDim2.fromOffset(112, 32),
        Font = Enum.Font.GothamBold,
        Text = Config.Defaults[action],
        TextSize = 16,
        TextColor3 = Theme.Gold,
        BackgroundColor3 = Theme.Slot,
        BorderSizePixel = 0,
    }, line)
    make("UICorner", {CornerRadius = UDim.new(0, 6)}, button)
    make("UIStroke", {Color = Theme.Border, Thickness = 1}, button)
    rows[action] = button
end

local reset = make("TextButton", {
    Name = "ResetDefaults",
    Position = UDim2.new(0, 20, 1, -85),
    Size = UDim2.fromOffset(154, 34),
    BackgroundColor3 = Theme.Panel,
    BorderSizePixel = 0,
    Font = Enum.Font.GothamBold,
    Text = "RESET DEFAULTS",
    TextColor3 = Theme.Gold,
    TextSize = 12,
}, panel)
make("UICorner", {CornerRadius = UDim.new(0, 6)}, reset)
make("UIStroke", {Color = Theme.Border, Thickness = 1}, reset)

local status = make("TextLabel", {
    Name = "Status",
    Position = UDim2.new(0, 20, 1, -125),
    Size = UDim2.new(1, -40, 0, 30),
    BackgroundTransparency = 1,
    Text = "Loading your character preferences...",
    Font = Enum.Font.Gotham,
    TextSize = 12,
    TextWrapped = true,
    TextXAlignment = Enum.TextXAlignment.Left,
    TextColor3 = Theme.Secondary,
}, panel)
make("TextLabel", {
    BackgroundTransparency = 1,
    Position = UDim2.new(0, 185, 1, -85),
    Size = UDim2.new(1, -205, 0, 36),
    Text = "F10 opens Options  |  ESC cancels rebinding",
    TextColor3 = Theme.Muted,
    Font = Enum.Font.Gotham,
    TextSize = 11,
    TextWrapped = true,
    TextXAlignment = Enum.TextXAlignment.Right,
}, panel)

local function showStatus(message, isError)
    status.Text = message
    status.TextColor3 = isError and Color3.fromRGB(255, 155, 155) or Theme.Secondary
end

local function redraw()
    for _, action in ipairs(Config.Order) do
        local button = rows[action]
        button.Text = (capturing == action) and "PRESS KEY..." or (bindings[action]=="MouseButton2" and "RIGHT MOUSE" or bindings[action])
        button.TextColor3 = capturing == action and Theme.Green or Theme.Gold
    end
end

local function clearHeld()
    table.clear(heldKeys)
end

local function bindMovementKeys()
    ContextActionService:UnbindAction(ACTION)
    clearHeld()
    local all = {}
    for _, name in ipairs({"W", "A", "S", "D"}) do
        all[name] = true -- stop the default Roblox movement even after a rebind
    end
    for _, action in ipairs(Config.MovementOrder) do
        all[bindings[action]] = true
    end
    local keyCodes = {}
    for name in pairs(all) do
        table.insert(keyCodes, Enum.KeyCode[name])
    end

    ContextActionService:BindActionAtPriority(ACTION, function(_, inputState, inputObject)
        local name = inputObject.KeyCode.Name
        if UserInputService:GetFocusedTextBox() then
            heldKeys[name] = nil
            return Enum.ContextActionResult.Pass
        end
        if inputState == Enum.UserInputState.Begin then
            heldKeys[name] = true
        elseif inputState == Enum.UserInputState.End or inputState == Enum.UserInputState.Cancel then
            heldKeys[name] = nil
        end
        return Enum.ContextActionResult.Sink
    end, false, 3000, table.unpack(keyCodes))
end
bindMovementKeys()

local function setMenu(open)
    menuOpen = open
    panel.Visible = open
    if open then
        LumiaModalState:Register("OptionsPanel")
    else
        LumiaModalState:Unregister("OptionsPanel")
        capturing = nil
    end
    clearHeld()
    player:SetAttribute("LumiaOptionsOpen", open)
    redraw()
end

opener.Activated:Connect(function()
    setMenu(not menuOpen)
end)
close.Activated:Connect(function()
    setMenu(false)
end)
-- V18 micro menu replaces the redundant top-right Options button.
opener.Visible = false
local MenuBus = require(controllers:WaitForChild("UI"):WaitForChild("LumiaMicroMenuBus"))
MenuBus.Register("Options", function() setMenu(not menuOpen) end)

local function submit(operation, action, keyName)
    if busy or not profileReady then return end
    busy = true
    showStatus("Saving your keybinds...", false)
    task.spawn(function()
        local ok, result = pcall(function()
            return remote:InvokeServer(operation, action, keyName)
        end)
        busy = false
        if ok and type(result) == "table" and result.Ok then
            bindings = Config.CopyOrDefault(result.Bindings)
            player:SetAttribute("LumiaInteractKey", bindings.Interact)
            bindMovementKeys()
            showStatus("Saved with your character profile.", false)
        else
            local reason = ok and type(result) == "table" and result.Error
                or "Network error, try again"
            showStatus(tostring(reason), true)
        end
        redraw()
    end)
end

for _, action in ipairs(Config.Order) do
    rows[action].Activated:Connect(function()
        if not profileReady or busy then
            showStatus("Wait for your character profile to load.", true)
            return
        end
        capturing = action
        clearHeld()
        showStatus("Press a new key for " .. Config.Labels[action] .. ". ESC to cancel.", false)
        redraw()
    end)
end

reset.Activated:Connect(function()
    if not profileReady or busy then
        showStatus("Wait for your character profile to load.", true)
        return
    end
    capturing = nil
    redraw()
    submit("Reset")
end)

UserInputService.InputBegan:Connect(function(input, processed)
    if UserInputService:GetFocusedTextBox() then return end
    local isRightMouse = input.UserInputType == Enum.UserInputType.MouseButton2
    if input.UserInputType ~= Enum.UserInputType.Keyboard and not (capturing == "Interact" and isRightMouse) then return end
    local name = isRightMouse and "MouseButton2" or input.KeyCode.Name

    if capturing then
        if name == "Escape" then
            capturing = nil
            showStatus("Keybind change cancelled.", false)
            redraw()
            return
        end
        if not Config.IsAllowed(name,capturing) then
            showStatus("That key is reserved or unsupported. Choose a letter or arrow.", true)
            return
        end
        local candidate = Config.CopyOrDefault(bindings)
        candidate[capturing] = name
        local valid, reason = Config.Validate(candidate)
        if not valid then
            showStatus(reason, true)
            return
        end
        local action = capturing
        capturing = nil
        redraw()
        submit("Set", action, name)
        return
    end

    if name == "F10" and not processed then
        setMenu(not menuOpen)
    end
end)

UserInputService.TextBoxFocused:Connect(clearHeld)
UserInputService.WindowFocusReleased:Connect(clearHeld)

local function restoreAutoRotate()
    if combatHumanoid and combatHumanoid.Parent then
        combatHumanoid.AutoRotate = oldAutoRotate
    end
    combatHumanoid = nil
end

local function isCombatToolEquipped(character)
    if not character then return false end
    for _, child in ipairs(character:GetChildren()) do
        if child:IsA("Tool") and child:GetAttribute("LumiaCombatTool") == true then
            return true
        end
    end
    return false
end

local function nativeGamepadOrTouchActive()
    local last = UserInputService:GetLastInputType()
    if last == Enum.UserInputType.Touch then return true end
    for n = 1, 8 do
        if last == Enum.UserInputType["Gamepad" .. n] then return true end
    end
    return false
end

-- Run just AFTER Roblox's default control module so customized keyboard
-- movement overrides normal W/A/S/D, while touch/gamepad stay native.
RunService:BindToRenderStep("Lumia_Movement", Enum.RenderPriority.Input.Value + 2, function()
    if not UserInputService.KeyboardEnabled or nativeGamepadOrTouchActive() then
        return
    end
    local forward, strafe = 0, 0
    if not menuOpen and not capturing and not UserInputService:GetFocusedTextBox() then
        if heldKeys[bindings.Forward] then forward += 1 end
        if heldKeys[bindings.Backward] then forward -= 1 end
        if heldKeys[bindings.StrafeRight] then strafe += 1 end
        if heldKeys[bindings.StrafeLeft] then strafe -= 1 end
    end
    local vector = Vector3.new(strafe, 0, -forward)
    if vector.Magnitude > 1 then vector = vector.Unit end
    -- Player.Character can be nil during the initial spawn or respawn.
    -- Drive the current Humanoid only after its rig is fully available.
    local character = player.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local root = character and character:FindFirstChild("HumanoidRootPart")
    if not character or not character:IsDescendantOf(workspace)
        or not humanoid or humanoid.Health <= 0 or not root then
        return
    end
    humanoid:Move(vector, true)
end)

-- Only a sword held in MainHand activates camera-facing combat movement.
-- The avatar always faces its current camera, even while moving backward.
RunService:BindToRenderStep("Lumia_CombatFacing", Enum.RenderPriority.Camera.Value + 2, function(dt)
    local character = player.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local root = character and character:FindFirstChild("HumanoidRootPart")
    local active = humanoid and root and humanoid.Health > 0
        and humanoid.SeatPart == nil and isCombatToolEquipped(character)

    if not active then
        restoreAutoRotate()
        return
    end
    if combatHumanoid ~= humanoid then
        restoreAutoRotate()
        combatHumanoid = humanoid
        oldAutoRotate = humanoid.AutoRotate
        humanoid.AutoRotate = false
    end
    local camera = workspace.CurrentCamera
    if not camera then return end
    local look = camera.CFrame.LookVector
    local flat = Vector3.new(look.X, 0, look.Z)
    if flat.Magnitude < 0.01 then return end
    local target = CFrame.lookAt(root.Position, root.Position + flat.Unit)
    root.CFrame = root.CFrame:Lerp(target, math.clamp(dt * 14, 0, 1))
end)

player.CharacterRemoving:Connect(function()
    restoreAutoRotate()
    clearHeld()
end)

task.spawn(function()
    for _ = 1, 35 do
        local ok, result = pcall(function()
            return remote:InvokeServer("Get")
        end)
        if ok and type(result) == "table" and result.Ok then
            bindings = Config.CopyOrDefault(result.Bindings)
            player:SetAttribute("LumiaInteractKey", bindings.Interact)
            bindMovementKeys()
            profileReady = true
            showStatus("Keybinds loaded. Changes save with your character.", false)
            redraw()
            print("[Lumia - Lumia Movement] Movement keybinds loaded: W/A/S/D by default; press F10")
            return
        end
        task.wait(1)
    end
    -- Keep default movement working even if server settings aren't ready.
    showStatus("Could not load keybinds. Movement defaults still work.", true)
    warn("[Lumia - Lumia Movement] Movement options could not load player preferences")
end)

print("[Lumia - Lumia Movement] Keyboard movement controller ready (F10 for Options)")
