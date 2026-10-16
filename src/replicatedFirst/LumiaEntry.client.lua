-- REALMS OF LUMIA - ENTRY EXPERIENCE v1
-- Starts before StarterPlayerScripts using ReplicatedFirst.
-- Sequence: optional prologue -> character welcome -> authentic loading check
-- -> server-approved entry -> remove overlay. No passwords; Roblox signs in.

local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local ContentProvider = game:GetService("ContentProvider")

-- v7 temporary headless entry. Keep the bridge and its real profile-readiness
-- handshake working while the pre-alpha uses no custom introduction UI.
local entryShared = ReplicatedStorage:WaitForChild("Lumia"):WaitForChild("Shared")
local entryConfig = require(entryShared:WaitForChild("Entry"):WaitForChild("EntryConfig"))
if entryConfig.EnableEntryUI == false then
    local player = Players.LocalPlayer
    task.spawn(function()
        local network = ReplicatedStorage:WaitForChild("Lumia"):WaitForChild("EntryNetwork", 45)
        local status = network and network:WaitForChild("GetEntryStatus", 15)
        local enter = network and network:WaitForChild("EnterWorld", 15)
        if not status or not enter then
            warn("[Lumia - Entry] Entry bridge unavailable. Character may remain protected.")
            return
        end
        local began=os.clock()
        while player and player.Parent and os.clock()-began < 120 do
            local ok, response=pcall(function() return status:InvokeServer() end)
            if ok and type(response)=="table" and response.Ready then
                local entered, confirmed = pcall(function() return enter:InvokeServer() end)
                if entered and confirmed==true then
                    print("[Lumia - Entry] UI temporarily disabled; server approved entry")
                    return
                end
            end
            task.wait(0.7)
        end
        warn("[Lumia - Entry] Server entry handshake timed out; check data/profile logs")
    end)
    return -- v7: no custom UI; entry server service remains fully installed
end

pcall(function() ReplicatedFirst:RemoveDefaultLoadingScreen() end)

local player = Players.LocalPlayer
while not player do
    Players.PlayerAdded:Wait()
    player = Players.LocalPlayer
end
local playerGui = player:WaitForChild("PlayerGui")

local existing = playerGui:FindFirstChild("LumiaEntryExperience")
if existing then existing:Destroy() end

local gui = Instance.new("ScreenGui")
gui.Name = "LumiaEntryExperience"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.DisplayOrder = 1000
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = playerGui

local function create(className, props, parent)
    local object = Instance.new(className)
    for key, value in pairs(props) do object[key] = value end
    object.Parent = parent
    return object
end

local bg = create("Frame", {
    Name = "Background",
    Size = UDim2.fromScale(1, 1),
    BackgroundColor3 = Color3.fromRGB(9, 16, 19),
    BorderSizePixel = 0,
    Active = true,
}, gui)
local glow = create("Frame", {
    Name = "ForestGlow",
    Position = UDim2.fromScale(0, .59),
    Size = UDim2.fromScale(1, .41),
    BackgroundColor3 = Color3.fromRGB(18, 42, 39),
    BackgroundTransparency = .28,
    BorderSizePixel = 0,
}, bg)
local glowGrad = create("UIGradient", {
    Rotation = 90,
    Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(20, 47, 43)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(4, 13, 21)),
    }),
}, glow)
local backgroundArt = create("ImageLabel", {
    Name = "OptionalBackgroundArt",
    BackgroundTransparency = 1,
    Size = UDim2.fromScale(1, 1),
    ScaleType = Enum.ScaleType.Crop,
    ImageTransparency = .33,
    Visible = false,
}, bg)
local tint = create("Frame", {
    Size = UDim2.fromScale(1, 1),
    BackgroundColor3 = Color3.fromRGB(2, 10, 15),
    BackgroundTransparency = .5,
    BorderSizePixel = 0,
}, bg)

local box = create("Frame", {
    Name = "StoryPanel",
    AnchorPoint = Vector2.new(.5, .5),
    Position = UDim2.fromScale(.5, .50),
    Size = UDim2.new(.88, 0, .72, 0),
    BackgroundTransparency = 1,
}, bg)
create("UISizeConstraint", {
    MaxSize = Vector2.new(820, 535),
    MinSize = Vector2.new(260, 280),
}, box)

local eyebrow = create("TextLabel", {
    Name = "Section", Text = "LOADING ADVENTURE",
    AnchorPoint = Vector2.new(.5, 0), Position = UDim2.fromScale(.5, .045),
    Size = UDim2.fromScale(1, .085), BackgroundTransparency = 1,
    Font = Enum.Font.GothamBold, TextSize = 13,
    TextColor3 = Color3.fromRGB(179, 208, 162), TextScaled = false,
}, box)
local title = create("TextLabel", {
    Name = "Title", Text = "REALMS OF LUMIA",
    AnchorPoint = Vector2.new(.5, 0), Position = UDim2.fromScale(.5, .17),
    Size = UDim2.fromScale(1, .17), BackgroundTransparency = 1,
    Font = Enum.Font.Garamond, TextSize = 54,
    TextColor3 = Color3.fromRGB(238, 212, 150),
    TextScaled = true, TextWrapped = true,
}, box)
local titleSize = create("UITextSizeConstraint", { MaxTextSize = 54, MinTextSize = 23 }, title)
local description = create("TextLabel", {
    Name = "Description", Text = "Preparing your journey...",
    AnchorPoint = Vector2.new(.5, 0), Position = UDim2.fromScale(.5, .41),
    Size = UDim2.fromScale(.92, .26), BackgroundTransparency = 1,
    Font = Enum.Font.Gotham, TextSize = 18,
    TextColor3 = Color3.fromRGB(223, 224, 214),
    TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Center,
}, box)
create("UITextSizeConstraint", { MaxTextSize = 20, MinTextSize = 12 }, description)
local statusText = create("TextLabel", {
    Name = "Status", Text = "Waiting for world services...",
    AnchorPoint = Vector2.new(.5, 0), Position = UDim2.fromScale(.5, .70),
    Size = UDim2.fromScale(.96, .07), BackgroundTransparency = 1,
    Font = Enum.Font.Gotham, TextSize = 12,
    TextColor3 = Color3.fromRGB(165, 183, 183),
    TextWrapped = true,
}, box)
local mainButton = create("TextButton", {
    Name = "ContinueButton", Text = "PLEASE WAIT",
    AnchorPoint = Vector2.new(.5, 0), Position = UDim2.fromScale(.5, .80),
    Size = UDim2.new(.65, 0, 0, 46),
    BackgroundColor3 = Color3.fromRGB(70, 110, 80),
    BorderSizePixel = 0, Font = Enum.Font.GothamBold, TextSize = 16,
    TextColor3 = Color3.fromRGB(247, 246, 233),
    AutoButtonColor = true, Active = false,
}, box)
create("UICorner", { CornerRadius = UDim.new(0, 7) }, mainButton)
local skipButton = create("TextButton", {
    Name = "SkipStory", Text = "SKIP INTRO",
    AnchorPoint = Vector2.new(.5, 1), Position = UDim2.fromScale(.5, .99),
    Size = UDim2.new(.52, 0, 0, 28), BackgroundTransparency = 1,
    Font = Enum.Font.GothamMedium, TextSize = 12,
    TextColor3 = Color3.fromRGB(174, 187, 170),
    Visible = false,
}, box)
local footer = create("TextLabel", {
    Name = "Footer", Text = "REALMS OF LUMIA  /  PRE-ALPHA",
    AnchorPoint = Vector2.new(.5, 1), Position = UDim2.fromScale(.5, .985),
    Size = UDim2.fromScale(.95, .05), BackgroundTransparency = 1,
    Font = Enum.Font.Gotham, TextSize = 10,
    TextColor3 = Color3.fromRGB(124, 147, 144),
}, bg)

local phase = "Boot"
local settings
local slideIndex = 1
local lastStatus = nil
local requestStatus
local requestEnter
local hasServerReady = false
local enterBusy = false
local loadingStarted = 0
local finished = false

local function button(label, enabled)
    mainButton.Text = label
    mainButton.Active = enabled
    mainButton.AutoButtonColor = enabled
    mainButton.BackgroundColor3 = enabled
        and Color3.fromRGB(83, 118, 87)
        or Color3.fromRGB(60, 72, 71)
end

local function showWelcome()
    if finished or phase == "Loading" then return end
    phase = "Welcome"
    skipButton.Visible = false
    eyebrow.Text = "YOUR JOURNEY BEGINS"
    title.Text = settings and settings.ProductName or "REALMS OF LUMIA"
    if lastStatus and lastStatus.Ready then
        description.Text = (lastStatus.Name or player.DisplayName)
            .. "  |  Level " .. tostring(lastStatus.Level or 1)
            .. " " .. tostring(lastStatus.Class or "Adventurer")
            .. "\n\nThe First Gate awaits beyond the forest."
    else
        description.Text = "Welcome, " .. player.DisplayName
            .. ".\n\nYour character is being prepared for the world."
    end
    statusText.Text = lastStatus and lastStatus.Message or "Connecting to server..."
    button("ENTER WORLD", true)
end

local function showSlide()
    if not settings or not settings.IntroSlides then return end
    local slide = settings.IntroSlides[slideIndex]
    if not slide then showWelcome() return end
    phase = "Story"
    skipButton.Visible = true
    eyebrow.Text = slide.Eyebrow or "THE STORY"
    title.Text = slide.Heading or settings.ProductName
    description.Text = slide.Body or ""
    statusText.Text = tostring(slideIndex) .. " / " .. tostring(#settings.IntroSlides)
    button(slideIndex < #settings.IntroSlides and "CONTINUE" or "MEET YOUR HERO", true)
end

local function endOverlay()
    if finished then return end
    finished = true
    statusText.Text = "Entering the world..."
    button("WELCOME TO LUMIA", false)
    local fade = TweenService:Create(bg, TweenInfo.new(.35), { BackgroundTransparency = 1 })
    -- Fade is cosmetic; full-screen UI is destroyed so existing client UI remains.
    fade:Play()
    task.delay(.4, function()
        if gui then gui:Destroy() end
    end)
    print("[Lumia - Entry Experience] World entered; interface released")
end

local function enterWhenReady()
    if phase ~= "Loading" or finished or enterBusy then return end
    if not lastStatus or not lastStatus.Ready or not requestEnter then return end
    enterBusy = true
    statusText.Text = "Verifying your character with the server..."
    button("ENTERING WORLD...", false)
    task.spawn(function()
        local ok, result, message = pcall(function()
            return requestEnter:InvokeServer()
        end)
        enterBusy = false
        if finished or phase ~= "Loading" then return end
        if ok and result == true then
            -- A short transition gives the loading screen a visible purpose,
            -- but it never substitutes for the server's actual readiness.
            local elapsed = os.clock() - loadingStarted
            if elapsed < .7 then task.wait(.7 - elapsed) end
            endOverlay()
        else
            statusText.Text = ok and tostring(message) or "Connection interrupted. Try again."
            button("RETRY", true)
        end
    end)
end

local function beginLoading()
    phase = "Loading"
    loadingStarted = os.clock()
    skipButton.Visible = false
    eyebrow.Text = "ENTERING LUMIA"
    title.Text = "THE WORLD AWAITS"
    description.Text = "Loading your character and preparing the world."
    statusText.Text = lastStatus and lastStatus.Message or "Waiting for game services..."
    button("CHECKING CHARACTER...", false)
    enterWhenReady()
end

mainButton.MouseButton1Click:Connect(function()
    if phase == "Story" then
        slideIndex += 1
        showSlide()
    elseif phase == "Welcome" then
        beginLoading()
    elseif phase == "Loading" and not enterBusy then
        enterWhenReady()
    end
end)
skipButton.MouseButton1Click:Connect(function()
    if phase == "Story" then showWelcome() end
end)

-- The overlay appears immediately. The three layers load independently:
-- ReplicatedFirst UI, ReplicatedStorage config, then server-ready network.
task.spawn(function()
    local success, result = pcall(function()
        local lumia = ReplicatedStorage:WaitForChild("Lumia", 35)
        if not lumia then error("Lumia replicated folder unavailable") end
        local shared = lumia:WaitForChild("Shared", 35)
        if not shared then error("Shared definitions unavailable") end
        local entryFolder = shared:WaitForChild("Entry", 35)
        if not entryFolder then error("Entry story configuration unavailable") end
        local configScript = entryFolder:WaitForChild("EntryConfig", 35)
        if not configScript then error("EntryConfig unavailable") end
        return require(configScript)
    end)
    if not success then
        eyebrow.Text = "ENTRY CONFIGURATION ISSUE"
        description.Text = tostring(result)
        statusText.Text = "The base game has not been changed. Check Rojo synchronization."
        return
    end
    settings = result
    if type(settings.BackgroundImage) == "string" and settings.BackgroundImage ~= "" then
        backgroundArt.Image = settings.BackgroundImage
        backgroundArt.Visible = true
        task.spawn(function()
            pcall(function() ContentProvider:PreloadAsync({backgroundArt}) end)
        end)
    end
    if lastStatus and lastStatus.HasSeenIntro and not settings.ShowStoryForReturningPlayers then
        showWelcome()
    else
        showSlide()
    end
end)

task.spawn(function()
    local lumia = ReplicatedStorage:WaitForChild("Lumia", 40)
    local network = lumia and lumia:WaitForChild("EntryNetwork", 40)
    requestStatus = network and network:WaitForChild("GetEntryStatus", 15)
    requestEnter = network and network:WaitForChild("EnterWorld", 15)
    if not requestStatus or not requestEnter then
        statusText.Text = "Entry server unavailable. Check Rojo and published DEV experience."
        return
    end
    local started = os.clock()
    while not finished do
        local ok, serverStatus = pcall(function()
            return requestStatus:InvokeServer()
        end)
        if ok and type(serverStatus) == "table" then
            lastStatus = serverStatus
            hasServerReady = serverStatus.Ready == true
            if phase == "Welcome" then
                showWelcome()
            elseif phase == "Loading" then
                if hasServerReady then
                    enterWhenReady()
                elseif not enterBusy then
                    statusText.Text = serverStatus.Message or "Loading..."
                end
            end
            if phase == "Story" and serverStatus.HasSeenIntro
                and settings and not settings.ShowStoryForReturningPlayers then
                showWelcome()
            end
        elseif phase == "Loading" then
            statusText.Text = "Waiting for a response from the server..."
        end
        if phase == "Loading" and not hasServerReady and settings
            and os.clock() - started > (settings.LoadingTimeout or 60) then
            statusText.Text = "Still loading. Check Roblox Output for DataStore or player errors."
        end
        task.wait(settings and settings.PollInterval or .65)
    end
end)

print("[Lumia - Entry Experience] Loading overlay running in ReplicatedFirst")
