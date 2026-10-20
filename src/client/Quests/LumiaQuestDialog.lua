-- REALMS OF LUMIA | Immersive quest dialog
--
-- A single compact card shown when an NPC offers or completes a quest, in the style
-- of the classic quest dialog: speaker at the top, the story, the objective with
-- progress, the reward, and two buttons. It is deliberately NOT the journal - the
-- journal stays the place where you read details and abandon quests.
--
--   QuestDialog.Show{ Title=, Speaker=, Level=, Description=, Objective=,
--                     Progress=, Count=, Rewards={...}, Mode="Offer"|"TurnIn"|"Progress",
--                     OnPrimary=function() end, OnSecondary=function() end }
--
-- Esc closes, Enter activates the primary button.
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local QuestDialog = {}

local GOLD = Color3.fromRGB(226, 191, 122)
local PAPER = Color3.fromRGB(238, 229, 210)
local MUTED = Color3.fromRGB(168, 156, 137)
local DARK = Color3.fromRGB(17, 20, 27)
local CREAM = Color3.fromRGB(34, 38, 48)
local OK_GREEN = Color3.fromRGB(126, 190, 128)

local gui, card, titleLabel, levelLabel, speakerLabel, storyLabel
local objectiveLabel, progressBar, progressFill, rewardLabel, primary, secondary
local callbacks = { primary = nil, secondary = nil }
local modalState = nil

local function node(class, props, parent)
    local instance = Instance.new(class)
    for key, value in pairs(props or {}) do
        instance[key] = value
    end
    if parent then instance.Parent = parent end
    return instance
end

local function rounded(instance, radius)
    node("UICorner", { CornerRadius = UDim.new(0, radius or 6) }, instance)
    return instance
end

local function border(instance, color, thickness)
    node("UIStroke", {
        Color = color or Color3.fromRGB(120, 94, 58),
        Thickness = thickness or 1,
    }, instance)
    return instance
end

local function ensureGui()
    if gui and gui.Parent then return end
    local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
    gui = node("ScreenGui", {
        Name = "LumiaQuestDialog",
        ResetOnSpawn = false,
        IgnoreGuiInset = false,
        DisplayOrder = 80,
        Enabled = false,
    }, playerGui)
    if not modalState then
        local ok, module = pcall(function()
            return require(script.Parent.Parent:WaitForChild("UI"):WaitForChild("LumiaModalState"))
        end)
        if ok then modalState = module end
    end
end

local function build()
    ensureGui()
    if card and card.Parent then return end

    -- Dim backdrop so the dialog reads as a conversation, not a page.
    local backdrop = node("Frame", {
        Name = "Backdrop",
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = Color3.fromRGB(0, 0, 0),
        BackgroundTransparency = 0.55,
        BorderSizePixel = 0,
        Visible = false,
        ZIndex = 90,
    }, gui)
    backdrop.Name = "Backdrop"
    callbacks.backdrop = backdrop

    card = rounded(node("Frame", {
        Name = "Card",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(478, 306),
        BackgroundColor3 = DARK,
        BackgroundTransparency = 0.04,
        BorderSizePixel = 0,
        ZIndex = 91,
    }, gui), 10)
    border(card, Color3.fromRGB(146, 112, 66), 1.6)

    -- Speaker line: this is the "who is talking" cue Immersive gives you.
    local headerBar = node("Frame", {
        Name = "Header",
        Size = UDim2.new(1, 0, 0, 46),
        BackgroundColor3 = CREAM,
        BackgroundTransparency = 0.25,
        BorderSizePixel = 0,
        ZIndex = 92,
    }, card)
    rounded(headerBar, 9)

    speakerLabel = node("TextLabel", {
        Name = "Speaker",
        Text = "",
        Position = UDim2.fromOffset(16, 5),
        Size = UDim2.new(1, -140, 0, 18),
        BackgroundTransparency = 1,
        Font = Enum.Font.GothamBold,
        TextSize = 11,
        TextColor3 = GOLD,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 93,
    }, headerBar)

    titleLabel = node("TextLabel", {
        Name = "Title",
        Text = "",
        Position = UDim2.fromOffset(16, 21),
        Size = UDim2.new(1, -140, 0, 20),
        BackgroundTransparency = 1,
        Font = Enum.Font.GothamBold,
        TextSize = 17,
        TextColor3 = PAPER,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        ZIndex = 93,
    }, headerBar)

    local levelPill = rounded(node("Frame", {
        Name = "LevelPill",
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -14, 0.5, 0),
        Size = UDim2.fromOffset(74, 22),
        BackgroundColor3 = Color3.fromRGB(52, 42, 28),
        BorderSizePixel = 0,
        ZIndex = 93,
    }, headerBar), 11)
    levelLabel = node("TextLabel", {
        Name = "Level",
        Text = "",
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        Font = Enum.Font.GothamBold,
        TextSize = 12,
        TextColor3 = GOLD,
        ZIndex = 94,
    }, levelPill)

    storyLabel = node("TextLabel", {
        Name = "Story",
        Text = "",
        Position = UDim2.fromOffset(18, 56),
        Size = UDim2.new(1, -36, 0, 96),
        BackgroundTransparency = 1,
        Font = Enum.Font.Gotham,
        TextSize = 14,
        TextColor3 = PAPER,
        TextWrapped = true,
        TextYAlignment = Enum.TextYAlignment.Top,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 92,
    }, card)

    local objectiveBox = rounded(node("Frame", {
        Name = "ObjectiveBox",
        Position = UDim2.fromOffset(18, 158),
        Size = UDim2.new(1, -36, 0, 60),
        BackgroundColor3 = CREAM,
        BackgroundTransparency = 0.35,
        BorderSizePixel = 0,
        ZIndex = 92,
    }, card), 7)
    border(objectiveBox, Color3.fromRGB(84, 72, 54), 1)

    objectiveLabel = node("TextLabel", {
        Name = "Objective",
        Text = "",
        Position = UDim2.fromOffset(12, 6),
        Size = UDim2.new(1, -24, 0, 18),
        BackgroundTransparency = 1,
        Font = Enum.Font.GothamBold,
        TextSize = 13,
        TextColor3 = PAPER,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 93,
    }, objectiveBox)

    local track = rounded(node("Frame", {
        Name = "ProgressTrack",
        Position = UDim2.fromOffset(12, 30),
        Size = UDim2.new(1, -24, 0, 10),
        BackgroundColor3 = Color3.fromRGB(28, 31, 39),
        BorderSizePixel = 0,
        ZIndex = 93,
    }, objectiveBox), 5)
    progressFill = rounded(node("Frame", {
        Name = "Fill",
        Size = UDim2.fromScale(0, 1),
        BackgroundColor3 = OK_GREEN,
        BorderSizePixel = 0,
        ZIndex = 94,
    }, track), 5)
    progressBar = track

    rewardLabel = node("TextLabel", {
        Name = "Reward",
        Text = "",
        Position = UDim2.fromOffset(18, 224),
        Size = UDim2.new(1, -36, 0, 18),
        BackgroundTransparency = 1,
        Font = Enum.Font.GothamBold,
        TextSize = 13,
        TextColor3 = GOLD,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 92,
    }, card)

    primary = rounded(node("TextButton", {
        Name = "Primary",
        Position = UDim2.new(0, 18, 1, -52),
        Size = UDim2.fromOffset(212, 36),
        BackgroundColor3 = Color3.fromRGB(105, 81, 43),
        BorderSizePixel = 0,
        Font = Enum.Font.GothamBold,
        TextSize = 14,
        TextColor = GOLD,
        Text = "ACCEPT",
        AutoButtonColor = true,
        ZIndex = 93,
    }, card), 7)
    secondary = rounded(node("TextButton", {
        Name = "Secondary",
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -18, 1, -52),
        Size = UDim2.fromOffset(212, 36),
        BackgroundColor3 = Color3.fromRGB(46, 41, 36),
        BorderSizePixel = 0,
        Font = Enum.Font.GothamBold,
        TextSize = 14,
        TextColor = MUTED,
        Text = "DECLINE",
        AutoButtonColor = true,
        ZIndex = 93,
    }, card), 7)
end

local function describeRewards(rewards)
    if type(rewards) ~= "table" or #rewards == 0 then return "" end
    return "REWARD   " .. table.concat(rewards, "     ")
end

function QuestDialog.IsOpen()
    return gui ~= nil and gui.Enabled == true
end

function QuestDialog.Hide()
    callbacks.primary = nil
    callbacks.secondary = nil
    if gui then gui.Enabled = false end
    if callbacks.backdrop then callbacks.backdrop.Visible = false end
    if modalState then
        pcall(function() modalState:Unregister("QuestDialog") end)
    end
end

function QuestDialog.Show(options)
    options = options or {}
    build()

    titleLabel.Text = tostring(options.Title or "Quest")
    speakerLabel.Text = string.upper(tostring(options.Speaker or "QUEST GIVER"))
    levelLabel.Text = options.Level and ("LEVEL " .. tostring(options.Level)) or ""
    storyLabel.Text = tostring(options.Description or "")
    rewardLabel.Text = describeRewards(options.Rewards)

    local count = tonumber(options.Count) or 0
    local progress = tonumber(options.Progress) or 0
    local complete = count > 0 and progress >= count
    objectiveLabel.Text = string.format("%s   %d/%d%s",
        tostring(options.Objective or "Objective"),
        progress, count, complete and "   COMPLETE" or "")
    objectiveLabel.TextColor3 = complete and OK_GREEN or PAPER
    progressFill.Size = UDim2.fromScale(
        count > 0 and math.clamp(progress / count, 0, 1) or 0, 1)

    primary.Text = tostring(options.PrimaryText
        or (options.Mode == "TurnIn" and "COMPLETE QUEST" or "ACCEPT"))
    secondary.Text = tostring(options.SecondaryText
        or (options.Mode == "TurnIn" and "NOT YET" or "DECLINE"))
    primary.Visible = options.HidePrimary ~= true
    secondary.Visible = options.HideSecondary ~= true

    callbacks.primary = options.OnPrimary
    callbacks.secondary = options.OnSecondary

    callbacks.backdrop.Visible = true
    gui.Enabled = true
    if modalState then
        pcall(function() modalState:Register("QuestDialog") end)
    end
end

-- Buttons are wired once, at build time, and read the current callbacks.
local function connectOnce()
    build()
    if primary and not primary:GetAttribute("Wired") then
        primary:SetAttribute("Wired", true)
        secondary:SetAttribute("Wired", true)
        local function invoke(kind)
            local callback = callbacks[kind]
            QuestDialog.Hide()
            if type(callback) == "function" then
                local ok, err = pcall(callback)
                if not ok then
                    warn("[Lumia - Quest Dialog] " .. tostring(err))
                end
            end
        end
        primary.Activated:Connect(function() invoke("primary") end)
        secondary.Activated:Connect(function() invoke("secondary") end)
        UserInputService.InputBegan:Connect(function(input, processed)
            if processed or not gui or not gui.Enabled then return end
            if UserInputService:GetFocusedTextBox() then return end
            if input.KeyCode == Enum.KeyCode.Escape then
                invoke("secondary")
            elseif input.KeyCode == Enum.KeyCode.Return
                or input.KeyCode == Enum.KeyCode.KeypadEnter then
                if primary.Visible then invoke("primary") end
            end
        end)
    end
end

task.defer(connectOnce)

return QuestDialog
