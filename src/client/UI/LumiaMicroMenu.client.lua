-- REALMS OF LUMIA | V18 ORIGINAL FANTASY MICRO MENU
-- Bottom-right buttons: character C, bag B, journal J, achievements L, options F10.
-- Uses original client window actions via LumiaMicroMenuBus. No player-data changes.
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local Bus = require(script.Parent:WaitForChild("LumiaMicroMenuBus"))
local old = playerGui:FindFirstChild("LumiaMicroMenu")
if old then old:Destroy() end

local COLORS = {
    Back = Color3.fromRGB(18, 22, 30),
    Panel = Color3.fromRGB(33, 38, 48),
    Raised = Color3.fromRGB(52, 55, 60),
    Border = Color3.fromRGB(163, 124, 70),
    Gold = Color3.fromRGB(238, 206, 150),
    Muted = Color3.fromRGB(166, 169, 174),
    Green = Color3.fromRGB(110, 204, 148),
}
local entries = {
    {Id="Character", Glyph="C", Name="Character Sheet", Key="C"},
    {Id="Bag", Glyph="B", Name="Inventory / Bags", Key="B"},
    {Id="Quests", Glyph="J", Name="Quest Journal", Key="J"},
    {Id="Achievements", Glyph="A", Name="Achievements", Key="L"},
    {Id="Options", Glyph="O", Name="Options / Keybinds", Key="F10"},
}

local function create(className, props, parent)
    local instance = Instance.new(className)
    for key,value in pairs(props) do
        instance[key] = value
    end
    instance.Parent = parent
    return instance
end
local function rounded(node, radius)
    create("UICorner", {CornerRadius=UDim.new(0,radius)},node)
    return node
end
local function stroke(node,color,thickness)
    create("UIStroke", {Color=color, Thickness=thickness},node)
end

local gui = create("ScreenGui",{
    Name="LumiaMicroMenu", ResetOnSpawn=false, IgnoreGuiInset=false,
    DisplayOrder=65, ZIndexBehavior=Enum.ZIndexBehavior.Sibling,
},playerGui)

local holder = rounded(create("Frame",{
    Name="MicroMenuFrame", AnchorPoint=Vector2.new(1,1),
    Position=UDim2.new(1,-15,1,-13), Size=UDim2.fromOffset(310,74),
    BackgroundColor3=COLORS.Back, BorderSizePixel=0,
},gui),8)
stroke(holder,COLORS.Border,1.4)
create("UIGradient", {
    Color=ColorSequence.new({
        ColorSequenceKeypoint.new(0,Color3.fromRGB(48,47,48)),
        ColorSequenceKeypoint.new(0.45,COLORS.Back),
        ColorSequenceKeypoint.new(1,Color3.fromRGB(20,25,32)),
    }), Rotation=90,
},holder)

local header = create("TextLabel",{
    Name="MicroMenuTitle", BackgroundTransparency=1,
    Position=UDim2.fromOffset(8,3), Size=UDim2.new(1,-16,0,14),
    Font=Enum.Font.Garamond, TextSize=14, Text="✦  L U M I A   M E N U  ✦",
    TextColor3=COLORS.Gold, TextXAlignment=Enum.TextXAlignment.Center,
},holder)

local layout = create("Frame",{
    Name="ButtonStrip", BackgroundTransparency=1,
    Position=UDim2.fromOffset(10,19), Size=UDim2.fromOffset(290,46),
},holder)

local tooltip = rounded(create("Frame",{
    Name="HoverTooltip", AnchorPoint=Vector2.new(1,1),
    Position=UDim2.new(1,0,0,-8), Size=UDim2.fromOffset(214,45),
    BackgroundColor3=Color3.fromRGB(14,18,26), BorderSizePixel=0,
    Visible=false, ZIndex=12,
},holder),7)
stroke(tooltip,COLORS.Border,1)
local tooltipText = create("TextLabel",{
    Name="TooltipText", BackgroundTransparency=1,
    Position=UDim2.fromOffset(8,4), Size=UDim2.new(1,-16,1,-8),
    TextColor3=COLORS.Gold, Font=Enum.Font.GothamMedium,
    TextWrapped=true, TextSize=12, TextXAlignment=Enum.TextXAlignment.Left,
    ZIndex=13, Text="",
},tooltip)

local buttons = {}
local pending=0
local function showHint(text)
    pending += 1
    local version=pending
    tooltipText.Text=text
    tooltip.Visible=true
    task.delay(2.2,function()
        if pending==version and tooltip.Parent then tooltip.Visible=false end
    end)
end

for index,entry in ipairs(entries) do
    local x=(index-1)*58
    local button=rounded(create("TextButton",{
        Name="Open"..entry.Id, Position=UDim2.fromOffset(x,0),
        Size=UDim2.fromOffset(54,46), BackgroundColor3=COLORS.Panel,
        BorderSizePixel=0, AutoButtonColor=false, Text="",
        Selectable=true,
    },layout),6)
    stroke(button,COLORS.Border,0.75)
    create("TextLabel",{
        Name="Symbol", BackgroundTransparency=1,
        Position=UDim2.fromOffset(0,3), Size=UDim2.new(1,0,0,25),
        Font=Enum.Font.Garamond, Text=entry.Glyph, TextSize=25,
        TextColor3=COLORS.Gold,
    },button)
    create("TextLabel",{
        Name="Shortcut", BackgroundTransparency=1,
        Position=UDim2.fromOffset(0,30), Size=UDim2.new(1,0,0,13),
        Font=Enum.Font.GothamBold, Text=entry.Key, TextSize=9,
        TextColor3=COLORS.Muted,
    },button)
    button.MouseEnter:Connect(function()
        button.BackgroundColor3=COLORS.Raised
        showHint(entry.Name .. "  (" .. entry.Key .. ")")
    end)
    button.MouseLeave:Connect(function()
        button.BackgroundColor3=COLORS.Panel
        pending += 1
        tooltip.Visible=false
    end)
    button.Activated:Connect(function()
        if UserInputService:GetFocusedTextBox() then
            UserInputService:GetFocusedTextBox():ReleaseFocus()
        end
        local ok,reason=Bus.Toggle(entry.Id)
        if not ok then
            showHint(reason or "Window unavailable")
        else
            pending += 1
            tooltip.Visible=false
        end
    end)
    buttons[entry.Id]=button
end

local scale=create("UIScale",{Scale=1},holder)
local function adapt()
    local cam=workspace.CurrentCamera
    if not cam then return end
    local view=cam.ViewportSize
    scale.Scale=math.clamp(math.min(view.X/900, view.Y/560),0.66,1)
end
local cameraConn
local function hookCamera()
    if cameraConn then cameraConn:Disconnect(); cameraConn=nil end
    local cam=workspace.CurrentCamera
    if cam then
        cameraConn=cam:GetPropertyChangedSignal("ViewportSize"):Connect(adapt)
    end
    adapt()
end
hookCamera()
workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(hookCamera)

print("[Lumia V18] Bottom-right micro menu ready - C B J L F10")
