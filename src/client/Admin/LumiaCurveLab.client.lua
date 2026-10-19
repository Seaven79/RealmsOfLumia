-- REALMS OF LUMIA | Curve Lab v4 - one master progression curve.
-- F7 only. No on-screen launcher. CLIENT UI IS NOT AN AUTHORITY.
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer
if player.UserId ~= 1614020138 then return end -- server also verifies this ID

local lumia = ReplicatedStorage:WaitForChild("Lumia")
local CurveMath = require(lumia:WaitForChild("Shared")
    :WaitForChild("Progression"):WaitForChild("CurveMath"))
local network = lumia:WaitForChild("CurveLabNetwork")
local getRemote = network:WaitForChild("GetCurveLab")
local setRemote = network:WaitForChild("SetCurveLab")
local playerGui = player:WaitForChild("PlayerGui")
local previous = playerGui:FindFirstChild("LumiaCurveLab")
if previous then previous:Destroy() end

local BG = Color3.fromRGB(23, 29, 41)
local SURFACE = Color3.fromRGB(37, 46, 60)
local FIELD = Color3.fromRGB(52, 63, 80)
local GOLD = Color3.fromRGB(235, 187, 103)
local WHITE = Color3.fromRGB(245, 241, 233)
local MUTED = Color3.fromRGB(176, 191, 207)
local GREEN = Color3.fromRGB(142, 226, 178)
local RED = Color3.fromRGB(250, 150, 140)

local function shape(class, name, parent, x, y, w, h, color)
    local item = Instance.new(class)
    item.Name = name
    item.Size = UDim2.fromOffset(w, h)
    item.Position = UDim2.fromOffset(x, y)
    item.BorderSizePixel = 0
    if color then item.BackgroundColor3 = color end
    item.Parent = parent
    return item
end
local function round(obj, radius)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, radius or 8)
    c.Parent = obj
end
local function label(parent, str, x, y, w, h, fontSize, color, bold)
    local l = shape("TextLabel", "Label", parent, x, y, w, h)
    l.BackgroundTransparency = 1
    l.Text = str
    l.TextColor3 = color or WHITE
    l.TextSize = fontSize or 15
    l.Font = bold and Enum.Font.GothamBold or Enum.Font.Gotham
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.TextWrapped = true
    return l
end
local function button(parent, name, x, y, w, h, onClick)
    local b = shape("TextButton", name, parent, x, y, w, h, FIELD)
    b.Text = name
    b.TextColor3 = WHITE
    b.TextSize = 17
    b.Font = Enum.Font.GothamBold
    round(b, 7)
    b.Activated:Connect(onClick)
    return b
end

local gui = Instance.new("ScreenGui")
gui.Name = "LumiaCurveLab"
gui.DisplayOrder = 170
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Parent = playerGui
local backdrop = shape("Frame", "Backdrop", gui, 0, 0, 0, 0, Color3.fromRGB(6, 9, 15))
backdrop.Size = UDim2.fromScale(1, 1)
backdrop.BackgroundTransparency = 0.35
backdrop.Active = true
backdrop.Visible = false
local panel = shape("Frame", "Window", gui, 0, 0, 660, 492, BG)
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.fromScale(0.5, 0.5)
panel.Visible = false
round(panel, 11)
local outline = Instance.new("UIStroke")
outline.Color = GOLD
outline.Thickness = 1.5
outline.Parent = panel
local sizeFit = Instance.new("UIScale")
sizeFit.Parent = panel
local cameraConnection
local function fit()
    local camera = workspace.CurrentCamera
    if camera then
        sizeFit.Scale = math.max(0.45, math.min(1,
            (camera.ViewportSize.X - 24) / 660,
            (camera.ViewportSize.Y - 24) / 492))
    end
end
local function trackCamera()
    if cameraConnection then cameraConnection:Disconnect() end
    if workspace.CurrentCamera then
        cameraConnection = workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fit)
    end
    fit()
end
workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(trackCamera)
trackCamera()

label(panel, "REALMS OF LUMIA  |  CURVE LAB", 22, 12, 550, 32, 22, GOLD, true)
label(panel, "One progression curve for every monster. New spawns only.",
    22, 44, 595, 23, 14, MUTED)
local function close()
    panel.Visible = false
    backdrop.Visible = false
end
button(panel, "X", 603, 18, 35, 34, close)

local current = 1.00
local snapshot
local requestBusy = false
local requestAgain = false
local serial = 0
local testEnabled = false
local controls = {}
local readBusy = false
local setStatus
local scheduleTest

label(panel, "DIFFICULTY PRESET", 22, 80, 300, 22, 14, MUTED, true)
local function updatePreview() end
local presetButtons = {}
for index, preset in ipairs({"Gentle", "Classic", "Hardcore"}) do
    local key = preset
    presetButtons[key] = button(panel, string.upper(key), 22 + (index-1)*208, 106, 198, 47,
        function()
            current = CurveMath.ProfileIntensities[key]
            controls.curve.Text = string.format("%.2f", current)
            updatePreview()
            scheduleTest()
        end)
end

label(panel, "CUSTOM CURVE STRENGTH", 22, 170, 292, 22, 14, MUTED, true)
local curve = shape("TextBox", "CurveStrength", panel, 324, 169, 125, 38, FIELD)
curve.Text = "1.00"
curve.TextColor3 = WHITE
curve.Font = Enum.Font.GothamBold
curve.TextSize = 21
curve.ClearTextOnFocus = false
curve.TextXAlignment = Enum.TextXAlignment.Center
round(curve)
controls.curve = curve
label(panel, "0.50 = easier   ·   1.00 = original   ·   2.00 = harder",
    22, 212, 616, 22, 13, MUTED)

local graph = shape("Frame", "CurvePreview", panel, 22, 248, 616, 121, SURFACE)
round(graph)
label(graph, "Monster HP relative to original", 12, 3, 500, 22, 14, WHITE, true)
local baselineLabel = label(graph, "", 12, 94, 592, 20, 13, MUTED)
local plot = shape("Frame", "Plot", graph, 12, 29, 592, 59)
plot.BackgroundTransparency = 1
local axis = shape("Frame", "Axis", plot, 0, 40, 592, 1, MUTED)
axis.BackgroundTransparency = 0.6
local function segment(parent, x0, y0, x1, y1, color)
    local dx, dy = x1 - x0, y1 - y0
    local line = shape("Frame", "Segment", parent, 0, 0,
        math.sqrt(dx*dx + dy*dy), 2.5, color)
    line.AnchorPoint = Vector2.new(0.5, 0.5)
    line.Position = UDim2.fromOffset((x0+x1)*0.5, (y0+y1)*0.5)
    line.Rotation = math.deg(math.atan2(dy, dx))
end

local outcome = label(panel, "", 22, 380, 617, 40, 13, MUTED)
local status = label(panel, "Loading owner settings...", 22, 421, 480, 55, 14, MUTED)
local revertButton = button(panel, "REVERT", 522, 432, 116, 37, function() end)

setStatus = function(message, color)
    status.Text = message
    status.TextColor3 = color or MUTED
end
updatePreview = function()
    local values = CurveMath.FromIntensity(current)
    if not values then return end
    for name, btn in pairs(presetButtons) do
        local selected = math.abs(current - CurveMath.ProfileIntensities[name]) < 0.001
        btn.BackgroundColor3 = selected and Color3.fromRGB(116, 82, 42) or FIELD
    end
    for _, item in ipairs(plot:GetChildren()) do
        if item.Name == "Segment" then item:Destroy() end
    end
    local factors = {}
    local maxFactor = 1
    for i = 1, 30 do
        local level = 1+(i-1)*2
        local factor = CurveMath.Factor("Health", level, values)
        factors[i] = factor
        maxFactor = math.max(maxFactor, factor)
    end
    local function y(factor)
        return 51 - factor / math.max(1.3, maxFactor*1.1) * 45
    end
    for i = 2, #factors do
        local x0, x1 = (i-2)*592/29, (i-1)*592/29
        segment(plot, x0, y(1), x1, y(1), MUTED)
        segment(plot, x0, y(factors[i-1]), x1, y(factors[i]), GOLD)
    end
    baselineLabel.Text = string.format("Monster HP: Lv1 %.2fx  ·  Lv20 %.2fx  ·  Lv50 %.2fx",
        CurveMath.Factor("Health", 1, values), CurveMath.Factor("Health", 20, values),
        CurveMath.Factor("Health", 50, values))
    outcome.Text = "Automatically adjusts HP, damage, defense, attacks, movement, aggro, "
        .. "respawn, level XP, kill XP and gold."
end

local function requestSnapshot()
    if readBusy then return end
    readBusy = true
    local ok, result = pcall(function() return getRemote:InvokeServer() end)
    readBusy = false
    if not ok or type(result) ~= "table" or not result.Authorized then
        setStatus("Server unavailable or you're not authorized.", RED)
        return
    end
    snapshot = result.Data
    local recognized = CurveMath.InferIntensity(snapshot.Values)
    if recognized then
        current = recognized
        curve.Text = string.format("%.2f", current)
        updatePreview()
    elseif not testEnabled then
        setStatus("Custom legacy balance loaded; choose a preset to replace it.", MUTED)
        return
    end
    if snapshot.Active then
        setStatus("TEST ACTIVE (8 min). Only new spawns change. XP/gold earned can save.", GREEN)
    elseif snapshot.CanTest then
        setStatus("READY · Choose a preset or enter one value. Auto-tests this server.", GREEN)
    else
        setStatus("PREVIEW ONLY · Testing is limited to Studio/private servers.", MUTED)
    end
end

local function sendTest()
    if not snapshot or not snapshot.CanTest then
        setStatus("PREVIEW ONLY · Testing requires Studio or private server.", MUTED)
        return
    end
    if requestBusy then
        requestAgain = true
        return
    end
    requestBusy = true
    local strength = current
    setStatus("Updating future monster spawns...", GOLD)
    task.spawn(function()
        local ok, accepted, result = pcall(function()
            return setRemote:InvokeServer("TestIntensity", strength)
        end)
        requestBusy = false
        if not ok or not accepted then
            setStatus(ok and tostring(result) or "Server request failed.", RED)
        else
            snapshot = result
            testEnabled = true
            setStatus("GLOBAL TEST ACTIVE · New spawns use " .. string.format("%.2f", strength)
                .. " · auto-reverts after 8 min.", GREEN)
        end
        if requestAgain then
            requestAgain = false
            scheduleTest()
        end
    end)
end

scheduleTest = function()
    serial += 1
    local ticket = serial
    updatePreview()
    if not snapshot then
        setStatus("Open the panel after server startup to load settings.", MUTED)
        return
    end
    if not snapshot.CanTest then
        setStatus("PREVIEW ONLY · Studio/private server required.", MUTED)
        return
    end
    setStatus("Preview updated · Applying to future spawns...", GOLD)
    task.delay(0.9, function()
        if ticket ~= serial then return end
        sendTest()
    end)
end

curve.FocusLost:Connect(function()
    local n = tonumber(curve.Text)
    if not CurveMath.FromIntensity(n) then
        curve.Text = string.format("%.2f", current)
        setStatus("Enter a number between 0.50 and 2.00.", RED)
        return
    end
    current = math.floor(n * 100 + 0.5) / 100
    curve.Text = string.format("%.2f", current)
    scheduleTest()
end)

revertButton.Activated:Connect(function()
    serial += 1  -- cancel unsubmitted drafts
    requestAgain = false
    setStatus("Reverting to published/original balance...", GOLD)
    task.spawn(function()
        while requestBusy do task.wait(0.05) end
        local ok, accepted, result = pcall(function()
            return setRemote:InvokeServer("Stop")
        end)
        if not ok or not accepted then
            setStatus(ok and tostring(result) or "Revert request failed.", RED)
            return
        end
        snapshot = result
        testEnabled = false
        local recognized = CurveMath.InferIntensity(result.Values)
        current = recognized or 1
        curve.Text = string.format("%.2f", current)
        updatePreview()
        setStatus("REVERTED · Future spawns use published/original settings.", GREEN)
    end)
end)

updatePreview()
UserInputService.InputBegan:Connect(function(input)
    if input.KeyCode ~= Enum.KeyCode.F7 then return end
    if UserInputService:GetFocusedTextBox() then return end
    local opening = not panel.Visible
    panel.Visible = opening
    backdrop.Visible = opening
    if opening then task.spawn(requestSnapshot) end
end)

print("[Lumia - Curve Lab] v4 SIMPLE: F7 only, one global progression dial")
