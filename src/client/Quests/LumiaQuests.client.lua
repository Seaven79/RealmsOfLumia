-- Realms of Lumia / First Paths - unified quest and loot cursor, portrait dialogue, static marker v6
-- Cosmetics and mouse responsiveness only; quest truth stays on server.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local CollectionService = game:GetService("CollectionService")
local ContextActionService=game:GetService("ContextActionService")
local player = Players.LocalPlayer
local mouse = player:GetMouse()
local playerGui = player:WaitForChild("PlayerGui")
local net = ReplicatedStorage:WaitForChild("Lumia"):WaitForChild("QuestNetwork")
local getJournal = net:WaitForChild("GetJournal")
local changed = net:WaitForChild("JournalChanged")
local messages = net:WaitForChild("QuestMessage")
local interact=net:WaitForChild("QuestInteract")
local castRemote=net:WaitForChild("QuestCastState")
local resetQuests=net:WaitForChild("ResetMyQuests")
local dialogueRemote=net:WaitForChild("QuestDialogue")
local questAction=net:WaitForChild("QuestAction")
local old = playerGui:FindFirstChild("LumiaFirstPathsJournal")
if old then old:Destroy() end
local gui = Instance.new("ScreenGui")
gui.Name = "LumiaFirstPathsJournal"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = false
gui.DisplayOrder = 35
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = playerGui
local function ui(class, props, parent)
    local node = Instance.new(class)
    for name, value in pairs(props) do node[name] = value end
    node.Parent = parent
    return node
end
local G = Color3.fromRGB(236,191,93)
local Currency=require(game:GetService("ReplicatedStorage"):WaitForChild("Lumia"):WaitForChild("Shared"):WaitForChild("Commerce"):WaitForChild("LumiaCurrency"))
local GOLDLIGHT = Color3.fromRGB(255,224,145)
local PAPER = Color3.fromRGB(220,200,164)
local TEXT = Color3.fromRGB(236,225,204)
local MUTED = Color3.fromRGB(176,162,138)
local DARK = Color3.fromRGB(29,25,22)
local PANEL = Color3.fromRGB(56,43,34)
local INSET = Color3.fromRGB(68,53,40)
local function round(node, pixels)
    ui("UICorner",{CornerRadius=UDim.new(0,pixels)},node)
    return node
end
local function outline(node, color, width)
    ui("UIStroke",{Color=color or G,Thickness=width or 1},node)
end
local function label(parent,name,text,pos,size,font,textSize,color)
    return ui("TextLabel",{
        Name=name,Text=text,Position=pos,Size=size,BackgroundTransparency=1,
        Font=font or Enum.Font.Gotham,TextSize=textSize or 16,
        TextColor3=color or TEXT,TextWrapped=true,
        TextXAlignment=Enum.TextXAlignment.Left,
        TextYAlignment=Enum.TextYAlignment.Center,
    },parent)
end

-- Compact quest tracker under the minimap: title, objective and a progress bar so
-- you can read how far along you are at a glance. The full story and rewards live
-- in the J journal.
local tracker = round(ui("Frame",{
    Name="CompactQuestTracker",AnchorPoint=Vector2.new(1,0),
    Position=UDim2.new(1,-11,0,213),Size=UDim2.fromOffset(202,80),
    BackgroundColor3=DARK,BackgroundTransparency=0.12,BorderSizePixel=0,
    Visible=false,
},gui),7)
outline(tracker,Color3.fromRGB(157,115,67),1)
local trackerTitle=label(tracker,"QuestTitle","",UDim2.fromOffset(9,5),
    UDim2.new(1,-18,0,25),Enum.Font.GothamSemibold,16,GOLDLIGHT)
trackerTitle.TextTruncate=Enum.TextTruncate.AtEnd
local trackerObjective=label(tracker,"QuestObjective","",UDim2.fromOffset(9,33),
    UDim2.new(1,-18,0,20),Enum.Font.Gotham,12,TEXT)
trackerObjective.TextTruncate=Enum.TextTruncate.AtEnd
local trackerTrack=round(ui("Frame",{
    Name="TrackerProgressTrack",Position=UDim2.fromOffset(9,58),
    Size=UDim2.new(1,-18,0,8),BackgroundColor3=Color3.fromRGB(28,31,39),
    BorderSizePixel=0,ZIndex=40,
},tracker),4)
local trackerFill=round(ui("Frame",{
    Name="TrackerProgressFill",Size=UDim2.fromScale(0,1),
    BackgroundColor3=Color3.fromRGB(126,190,128),BorderSizePixel=0,ZIndex=41,
},trackerTrack),4)
local function setTrackerProgress(progress,count,ready)
    local fraction=0
    if ready then
        fraction=1
    elseif type(count)=="number" and count>0 and type(progress)=="number" then
        fraction=math.clamp(progress/count,0,1)
    end
    trackerFill.Size=UDim2.fromScale(fraction,1)
    trackerFill.BackgroundColor3=ready
        and Color3.fromRGB(226,191,122) or Color3.fromRGB(126,190,128)
end

local toast = round(ui("TextLabel",{
    Name="QuestMessage",AnchorPoint=Vector2.new(0.5,0),
    Position=UDim2.new(0.5,0,0,56),Size=UDim2.fromOffset(450,36),
    BackgroundColor3=DARK,BackgroundTransparency=0.08,
    Font=Enum.Font.GothamSemibold,TextSize=15,TextColor3=G,
    BorderSizePixel=0,Text="",Visible=false,ZIndex=50,
},gui),7)
outline(toast,Color3.fromRGB(135,102,60),1)

local window = round(ui("Frame",{
    Name="JournalWindow",AnchorPoint=Vector2.new(0.5,0.5),
    Position=UDim2.fromScale(0.5,0.5), Size=UDim2.new(0.84,0,0.81,0),
    BackgroundColor3=PANEL,BorderSizePixel=0,Visible=false,
},gui),10)
ui("UISizeConstraint",{MaxSize=Vector2.new(625,520),MinSize=Vector2.new(330,350)},window)
outline(window,G,2)
local inlay = round(ui("Frame",{
    Name="JournalPage",Position=UDim2.fromOffset(9,9),
    Size=UDim2.new(1,-18,1,-18),BackgroundColor3=INSET,BorderSizePixel=0,
},window),6)
outline(inlay,Color3.fromRGB(138,104,63),1)
local header = label(inlay,"Header","THE FIRST PATHS",UDim2.fromOffset(18,9),UDim2.new(1,-88,0,34),Enum.Font.GothamSemibold,23,GOLDLIGHT)
header.TextYAlignment=Enum.TextYAlignment.Center
local close = round(ui("TextButton",{
    Name="Close",AnchorPoint=Vector2.new(1,0),Position=UDim2.new(1,-12,0,11),
    Size=UDim2.fromOffset(30,29),BackgroundColor3=Color3.fromRGB(92,65,45),
    Text="X",Font=Enum.Font.GothamBold,TextSize=14,TextColor3=G,
    BorderSizePixel=0,
},inlay),5)
local rule = ui("Frame",{Name="Rule",Position=UDim2.fromOffset(18,50),
    Size=UDim2.new(1,-36,0,1),BackgroundColor3=G,BackgroundTransparency=0.45,BorderSizePixel=0},inlay)
local progress = label(inlay,"Progress","CAMPAIGN  •  0 / 12 COMPLETED",UDim2.fromOffset(20,60),UDim2.new(1,-40,0,18),Enum.Font.GothamBold,11,MUTED)
local questTitle = label(inlay,"QuestTitle","Loading quest...",UDim2.fromOffset(20,82),UDim2.new(1,-40,0,34),Enum.Font.GothamSemibold,23,GOLDLIGHT)

local function section(parent,name,heading,y,height)
    local panel = round(ui("Frame",{Name=name,Position=UDim2.new(0,18,0,y),
        Size=UDim2.new(1,-36,0,height),BorderSizePixel=0,
        BackgroundColor3=DARK,BackgroundTransparency=0.31},parent),6)
    label(panel,"Label",heading,UDim2.fromOffset(11,5),UDim2.new(1,-22,0,17),Enum.Font.GothamBold,11,G)
    local content=label(panel,"Value","",UDim2.fromOffset(11,25),UDim2.new(1,-22,1,-31),Enum.Font.Gotham,16,TEXT)
    content.TextYAlignment=Enum.TextYAlignment.Top
    return panel, content
end
local _, story = section(inlay,"Story","QUEST STORY",123,88)
local _, objective = section(inlay,"Objective","OBJECTIVES",219,93)
local _, reward = section(inlay,"Reward","REWARDS ON TURN-IN",320,64)
local footer=label(inlay,"Footer","J — Close journal",UDim2.new(0,20,1,-31),UDim2.new(1,-40,0,19),Enum.Font.Gotham,11,MUTED)
footer.TextXAlignment=Enum.TextXAlignment.Center

local abandonButton=round(ui("TextButton",{
    Name="AbandonQuest",AnchorPoint=Vector2.new(1,1),
    Position=UDim2.new(1,-20,1,-37),Size=UDim2.fromOffset(154,27),
    BackgroundColor3=Color3.fromRGB(89,55,45),
    BorderSizePixel=0,Text="ABANDON QUEST",Font=Enum.Font.GothamBold,
    TextSize=11,TextColor3=PAPER,Visible=false,
},inlay),5)
local abandonDeadline=0

-- An NPC-specific classic RPG dialogue: story, objectives and rewards separated.
local dialogueWindow=round(ui("Frame",{
    Name="QuestDialogue",AnchorPoint=Vector2.new(0.5,0.5),
    Position=UDim2.fromScale(0.5,0.5),Size=UDim2.new(0.86,0,0.83,0),
    BackgroundColor3=PANEL,BorderSizePixel=0,Visible=false,ZIndex=70,
},gui),11)
ui("UISizeConstraint",{MaxSize=Vector2.new(560,540),MinSize=Vector2.new(330,380)},dialogueWindow)
outline(dialogueWindow,G,2)
local paper=round(ui("Frame",{Position=UDim2.fromOffset(9,9),
    Size=UDim2.new(1,-18,1,-18),BackgroundColor3=INSET,BorderSizePixel=0,ZIndex=71,
},dialogueWindow),7)
local npcHeader=label(paper,"NPCName","ELDER ROWAN",UDim2.fromOffset(18,10),
    UDim2.new(1,-75,0,27),Enum.Font.GothamSemibold,23,GOLDLIGHT)
npcHeader.ZIndex=72
local dialogClose=round(ui("TextButton",{AnchorPoint=Vector2.new(1,0),
    Position=UDim2.new(1,-14,0,12),Size=UDim2.fromOffset(31,28),
    BackgroundColor3=Color3.fromRGB(89,57,40),BorderSizePixel=0,
    Font=Enum.Font.GothamBold,TextSize=15,Text="X",TextColor3=PAPER,ZIndex=73,
},paper),5)
local dialogQuest=label(paper,"Title","",UDim2.fromOffset(18,45),
    UDim2.new(1,-36,0,40),Enum.Font.GothamSemibold,23,GOLDLIGHT)
dialogQuest.ZIndex=72
local function dialogueSection(name,heading,y,height)
    local panel=round(ui("Frame",{Name=name,Position=UDim2.fromOffset(18,y),
        Size=UDim2.new(1,-36,0,height),BackgroundColor3=DARK,
        BackgroundTransparency=0.28,BorderSizePixel=0,ZIndex=72},paper),6)
    local h=label(panel,"Header",heading,UDim2.fromOffset(10,4),
        UDim2.new(1,-20,0,20),Enum.Font.GothamBold,11,G)
    h.ZIndex=73
    local v=label(panel,"Body","",UDim2.fromOffset(10,27),
        UDim2.new(1,-20,1,-33),Enum.Font.Gotham,15,TEXT)
    v.TextYAlignment=Enum.TextYAlignment.Top
    v.TextSize=16
    v.ZIndex=73
    return v
end
local dialogStory=dialogueSection("Story","ELDER ROWAN SAYS",90,118)
dialogStory.TextSize=15
-- A real 3D close-up of the NPC Head and beard; no external asset ID or image required.
local storyBox=dialogStory.Parent
storyBox.Position=UDim2.fromOffset(135,90)
storyBox.Size=UDim2.new(1,-153,0,118)
local portrait=round(ui("ViewportFrame",{
    Name="ElderRowanPortrait", Position=UDim2.fromOffset(18,90),
    Size=UDim2.fromOffset(109,118), BackgroundColor3=Color3.fromRGB(40,50,38),
    BorderSizePixel=0,Ambient=Color3.fromRGB(190,180,158),
    LightColor=Color3.fromRGB(255,231,185),LightDirection=Vector3.new(-1,-1,-2),ZIndex=72,
},paper),6)
outline(portrait,Color3.fromRGB(148,110,64),1)
local portraitWorld=ui("WorldModel",{},portrait)
local portraitCamera=Instance.new("Camera")
portraitCamera.Name="PortraitCamera"
portraitCamera.FieldOfView=36
portraitCamera.CFrame=CFrame.lookAt(Vector3.new(0,0,-3.6),Vector3.zero)
portraitCamera.Parent=portrait
portrait.CurrentCamera=portraitCamera
local function refreshPortrait(npcName)
    portraitWorld:ClearAllChildren()
    local world=workspace:FindFirstChild("LumiaQuestWorld")
    local npc=world and world:FindFirstChild(npcName or "ElderRowan")
    local head=npc and npc:FindFirstChild("Head")
    if not head or not head:IsA("BasePart") then return end
    local origin=head.CFrame
    local function clonePart(real)
        local ok,clone=pcall(function() return real:Clone() end)
        if not ok or not clone or not clone:IsA("BasePart") then return end
        clone.Anchored=true;clone.CanCollide=false;clone.CanTouch=false
        clone.CanQuery=false
        for _,child in ipairs(clone:GetDescendants()) do
            if child:IsA("Constraint") or child:IsA("JointInstance") then child:Destroy() end
        end
        clone.CFrame=CFrame.new()*origin:ToObjectSpace(real.CFrame)
        clone.Parent=portraitWorld
    end
    clonePart(head)
    for _,name in ipairs({"SilverHair","GreyBeard"}) do
        local piece=npc:FindFirstChild(name)
        if piece and piece:IsA("BasePart") then clonePart(piece) end
    end
end
local dialogObjective=dialogueSection("Objectives","OBJECTIVE",218,76)
local dialogReward=dialogueSection("Rewards","REWARDS",303,57)
local dialogNotice=label(paper,"Hint","",UDim2.new(0,19,1,-81),
    UDim2.new(1,-38,0,24),Enum.Font.Gotham,12,MUTED)
dialogNotice.ZIndex=72
local primary=round(ui("TextButton",{Name="PrimaryAction",Position=UDim2.new(0,19,1,-50),
    Size=UDim2.fromOffset(175,35),BackgroundColor3=Color3.fromRGB(105,81,43),
    BorderSizePixel=0,Font=Enum.Font.GothamBold,TextSize=14,
    Text="ACCEPT",TextColor3=GOLDLIGHT,ZIndex=73,
},paper),6)
local decline=round(ui("TextButton",{Name="Decline",AnchorPoint=Vector2.new(1,0),
    Position=UDim2.new(1,-19,1,-50),Size=UDim2.fromOffset(132,35),
    BackgroundColor3=Color3.fromRGB(83,61,47),BorderSizePixel=0,
    Font=Enum.Font.GothamBold,TextSize=14,Text="DECLINE",TextColor3=PAPER,ZIndex=73,
},paper),6)
local dialogVerb=nil
local dialogBusy=false

local resetButton
if player.UserId==1614020138 then
    resetButton=round(ui("TextButton",{
        Name="DevResetQuests",Position=UDim2.new(0,20,1,-60),
        Size=UDim2.fromOffset(177,26),BackgroundColor3=Color3.fromRGB(74,47,34),
        Text="DEV: RESET QUESTS",Font=Enum.Font.GothamBold,TextSize=11,
        TextColor3=GOLDLIGHT,BorderSizePixel=0,
    },inlay),4)
    local armUntil=0
    resetButton.Activated:Connect(function()
        if os.clock()>armUntil then
            armUntil=os.clock()+6
            resetButton.Text="CONFIRM RESET?"
            return
        end
        armUntil=0
        resetButton.Text="DEV: RESET QUESTS"
        task.spawn(function()
            local ok,response=pcall(function() return resetQuests:InvokeServer() end)
            if not ok or not response or not response.Ok then
                warn("[Lumia - Quests] Reset denied: "..tostring(ok and response and response.Message or response))
            end
        end)
    end)
end

local snapshot
local markersByGiver = {}
local SILVER = Color3.fromRGB(200,200,200)
local GRAY   = Color3.fromRGB(110,110,110)
local function syncMarkers()
    if not snapshot or type(snapshot.Givers) ~= "table" then return end
    for gName, entry in pairs(markersByGiver) do
        local giver = snapshot.Givers[gName]
        local gui = entry.Gui
        if gui and gui.Parent then
            if not giver or giver.State == "Done" or giver.State == "None" then
                gui.Enabled = false
            else
                gui.Enabled = true
                -- Classic marker language: a golden "!" means a quest is on offer,
                -- a golden "?" means one is already in your log. Accepted quests get
                -- the "?" immediately and it brightens once the objective is done.
                local glyph = "!"
                local color = GOLDLIGHT
                if giver.State == "Current" then
                    glyph = "?"
                    local aq = snapshot.ActiveQuests and snapshot.ActiveQuests[giver.QuestId]
                    color = (aq and aq.ReadyToTurnIn)
                        and Color3.fromRGB(255,240,190) or GOLDLIGHT
                elseif giver.State == "Available" then
                    color = GOLDLIGHT
                elseif giver.State == "Locked" then
                    color = GRAY
                else
                    gui.Enabled = false
                end
                if entry.Icon then entry.Icon.Text = glyph end
                if entry.Icon then
                    entry.Icon.TextColor3 = color
                    -- Clear the pending dim applied when the marker was attached.
                    entry.Icon.TextTransparency = 0
                end
                if entry.Shadow then
                    entry.Shadow.Text = glyph
                    entry.Shadow.TextTransparency = 0
                end
            end
        end
    end
end
local function render(data)
    if type(data)~="table" or not data.Ready then
        tracker.Visible=false
        questTitle.Text="CHARACTER LOADING"
        story.Text="Waiting for player profile..."
        objective.Text=""
        reward.Text=""
        return
    end
    snapshot=data
    progress.Text=string.format("CAMPAIGN PROGRESS  •  %d / %d QUESTS COMPLETE",data.Completed or 0,data.Total or 0)
    if data.AllComplete then
        tracker.Visible=false
        questTitle.Text="A PATH WELL TRAVELLED"
        story.Text="The First Paths are complete. The next chapter awaits."
        objective.Text="All available quests completed."
        reward.Text="Your rewards have been received."
        abandonButton.Visible=false
        syncMarkers()
        return
    end
    local q=data.Quest
    if not q then return end
    questTitle.Text=q.Name
    story.Text=q.Description
    tracker.Visible=q.Active==true
    trackerTitle.Text=q.Name
    local objectiveName=(q.Kind=="Kill" and "Creatures defeated" or
        (q.Kind=="Collect" and "Runestone fragments collected" or (q.Kind=="Ritual" and "Runes activated" or "Clues investigated")))
    trackerObjective.Text=string.format("%s: %d/%d",objectiveName,q.Progress,q.Count)
    if q.ReadyToTurnIn then trackerObjective.Text="Objective complete — turn in" end
    setTrackerProgress(q.Progress,q.Count,q.ReadyToTurnIn==true)
    abandonButton.Visible=q.Active==true
    if not q.Active then abandonDeadline=0;abandonButton.Text="ABANDON QUEST" end
    if not q.Active then
        objective.Text="Find a character offering a new adventure. Look for a golden ! in the world."
    else
        local step=(q.Kind=="Kill" and "Creatures defeated" or
        (q.Kind=="Collect" and "Runestone fragments collected" or (q.Kind=="Ritual" and "Runes activated" or "Clues investigated")))
        local progressLine=string.format("%s: %d / %d",step,q.Progress,q.Count)
        objective.Text=q.ReadyToTurnIn and (progressLine.."\nCompleted — return to the quest giver.")
            or (progressLine.."\nSearch the world and uncover the answer.")
    end
    reward.Text=string.format("+%d EXPERIENCE     •     +%s",q.XP or 0,Currency.FormatShort(q.Gold or 0))
    syncMarkers()
end
local function refresh()
    local ok,data=pcall(function() return getJournal:InvokeServer() end)
    if ok and type(data)=="table" then
        if workspace:GetAttribute("LumiaQuestDebug") == true then
            local count=0
            for _ in pairs(data.Givers or {}) do count=count+1 end
            print(string.format("[Quest Debug] snapshot ready=%s givers=%d at t=%.2f", tostring(data.Ready),count,os.clock()))
        end
        render(data)
    end
end
changed.OnClientEvent:Connect(render)
-- Fetch the snapshot as soon as the session allows it. Markers are attached when the
-- NPC models stream in, but they stay blank until a snapshot exists, and previously
-- that only happened when the journal was opened or the server pushed a change - so
-- the "!" and "?" appeared late. The first attempts can land while the server is
-- still loading the profile, hence the short retry loop.
task.spawn(function()
    for attempt = 1, 16 do
        refresh()
        if snapshot and type(snapshot.Givers) == "table"
            and next(snapshot.Givers) ~= nil then
            syncMarkers()
            return
        end
        task.wait(0.15)
    end
end)
local toastSerial=0
messages.OnClientEvent:Connect(function(msg,success)
    toastSerial+=1
    local serial=toastSerial
    toast.Text=tostring(msg)
    toast.TextColor3=success and GOLDLIGHT or PAPER
    toast.Visible=true
    task.delay(3.2,function() if serial==toastSerial then toast.Visible=false end end)
end)
-- Declared BEFORE toggleWindow: referencing it further down made this a nil
-- global, so the journal never registered as a modal.
local LumiaModalState = require(script.Parent.Parent:WaitForChild("UI"):WaitForChild("LumiaModalState"))
local function toggleWindow()
    if dialogueWindow.Visible then return end
    window.Visible=not window.Visible
    if window.Visible then LumiaModalState:Register("QuestJournal") else LumiaModalState:Unregister("QuestJournal") end
    if window.Visible then task.spawn(refresh) end
end
close.MouseButton1Click:Connect(function() window.Visible=false end)
-- V18 micro menu opens the full quest journal, not the compact tracker.
local MenuBus = require(script.Parent.Parent:WaitForChild("UI"):WaitForChild("LumiaMicroMenuBus"))
MenuBus.Register("Quests", toggleWindow)
UserInputService.InputBegan:Connect(function(input,processed)
    if not processed and input.KeyCode==Enum.KeyCode.J and not UserInputService:GetFocusedTextBox() then
        toggleWindow()
    end
end)

local function requestAction(verb)
    local ok,response=pcall(function() return questAction:InvokeServer(verb) end)
    if ok and type(response)=="table" then
        if response.Snapshot then render(response.Snapshot) end
        if not response.Ok then
            warn("[Lumia - Quest Journal] "..tostring(response.Message))
            toast.Text=tostring(response.Message)
            toast.Visible=true
            task.delay(3,function() toast.Visible=false end)
        end
        return response.Ok
    end
    warn("[Lumia - Quest Journal] Interaction failed: "..tostring(response))
    return false
end

abandonButton.Activated:Connect(function()
    if not snapshot or not snapshot.Quest or not snapshot.Quest.Active then return end
    if os.clock()>abandonDeadline then
        abandonDeadline=os.clock()+7
        abandonButton.Text="CONFIRM ABANDON?"
        return
    end
    abandonDeadline=0
    abandonButton.Text="ABANDON QUEST"
    task.spawn(function() requestAction("Abandon") end)
end)
-- Immersive-style card used for NPC offers and turn-ins. The journal above stays
-- the place for details and abandoning; this is only the conversation.
local QuestDialog = require(script.Parent:WaitForChild("LumiaQuestDialog"))

local function openDialogue(data)
    if type(data)~="table" or not data.Ready then return end
    render(data)
    window.Visible=false
    dialogueWindow.Visible=false
    dialogBusy=false
    local q=data.Quest
    task.spawn(function() refreshPortrait(q and q.Giver or "ElderRowan") end)
    if not q then
        -- Nothing on offer: fall back to the classic window rather than showing an
        -- empty quest card.
        dialogueWindow.Visible=true
        dialogQuest.Text="The First Paths"
        dialogStory.Text="You have completed the available adventures, traveler."
        dialogObjective.Text="All quests completed."
        dialogReward.Text=""
        dialogNotice.Text="A new chapter awaits."
        primary.Visible=false
        decline.Text="CLOSE"
        dialogVerb=nil
        return
    end
    npcHeader.Text=(q.Giver=="ThornwatchScout" and "LYSA THE SCOUT")
        or (q.Giver=="GateWarden" and "KEEPER ARLEN") or "ELDER ROWAN"
    dialogQuest.Text=q.Name
    -- The same NPC tells different story text when offering versus completing.
    if not q.Active then
        dialogStory.Text=q.AcceptText or q.Description
    elseif q.ReadyToTurnIn then
        dialogStory.Text=q.TurnInText or ("You have returned, traveler. " ..
            "The forest is safer because of your efforts. Take this reward.")
    else
        dialogStory.Text=q.ProgressText or ("Keep searching, traveler. " ..
            "Return when your task is finished.")
    end
    local objectiveName=(q.Kind=="Kill" and "Creatures defeated" or
        (q.Kind=="Collect" and "Runestone fragments collected" or (q.Kind=="Ritual" and "Runes activated" or "Clues investigated")))
    dialogObjective.Text=string.format("%s: %d / %d",objectiveName,q.Progress,q.Count)
    dialogReward.Text=string.format("%d XP    |    %s",q.XP or 0,Currency.FormatShort(q.Gold or 0))
    if not q.Active then
        dialogVerb="Accept"
        primary.Text="ACCEPT QUEST"
        primary.Visible=true
        decline.Text="DECLINE"
        dialogNotice.Text="Accept this quest to begin tracking its objectives."
    elseif q.ReadyToTurnIn then
        dialogVerb="TurnIn"
        primary.Text="COMPLETE QUEST"
        primary.Visible=true
        decline.Text="NOT YET"
        dialogNotice.Text="Your quest is complete. Claim your reward."
    else
        dialogVerb=nil
        primary.Visible=false
        decline.Text="CLOSE"
        dialogNotice.Text="Your quest remains active. Return when finished."
    end

    -- Present the same information as a compact conversation card.
    QuestDialog.Show{
        Title=q.Name,
        Speaker=npcHeader.Text,
        Level=q.MinLevel or 1,
        Description=dialogStory.Text,
        Objective=objectiveName,
        Progress=q.Progress or 0,
        Count=q.Count or 0,
        Rewards={string.format("%d XP",q.XP or 0),Currency.FormatShort(q.Gold or 0)},
        Mode=(q.ReadyToTurnIn and "TurnIn") or (q.Active and "Progress") or "Offer",
        PrimaryText=primary.Text,
        SecondaryText=decline.Text,
        HidePrimary=(dialogVerb==nil),
        OnPrimary=function()
            if dialogVerb then task.spawn(function() requestAction(dialogVerb) end) end
        end,
        OnSecondary=function() end,
    }
end
dialogueRemote.OnClientEvent:Connect(openDialogue)
primary.Activated:Connect(function()
    if dialogBusy or not dialogVerb then return end
    dialogBusy=true
    primary.Text="PLEASE WAIT..."
    local verb=dialogVerb
    task.spawn(function()
        local success=requestAction(verb)
        dialogBusy=false
        if success then
            dialogueWindow.Visible=false
        else
            task.spawn(refresh)
            primary.Text=verb=="TurnIn" and "COMPLETE QUEST" or "ACCEPT QUEST"
        end
    end)
end)
local function closeDialogue() dialogueWindow.Visible=false end
dialogClose.Activated:Connect(closeDialogue)
decline.Activated:Connect(closeDialogue)

-- Per-player 3D quest glyph: solid display font, layered outline/shadow, distance scaling.
local function attachMarkerForGiver(npc)
    if not npc then return end
    local name = npc.Name
    if markersByGiver[name] then return end
    local root = npc:FindFirstChild("HumanoidRootPart") or npc.PrimaryPart
    if not root then root = npc:WaitForChild("HumanoidRootPart", 8) end
    if not root then return end
    local gui = ui("BillboardGui", {
        Name="LumiaPersonalQuestSymbol", Adornee=root, AlwaysOnTop=false, LightInfluence=0,
        Size=UDim2.fromOffset(70,85), StudsOffsetWorldSpace=Vector3.new(0,4.55,0),
        MaxDistance=80, Enabled=false,
    }, playerGui)
    local canvas = ui("Frame",{Name="MarkerCanvas",Size=UDim2.fromScale(1,1),BackgroundTransparency=1},gui)
    local scale = ui("UIScale",{Scale=1},canvas)
    local shadow = ui("TextLabel",{
        Name="DropShadow",Position=UDim2.fromOffset(2,4),Size=UDim2.fromScale(1,1),
        Text="!",Font=Enum.Font.GothamBlack,TextSize=69,
        TextColor3=Color3.fromRGB(14,13,13),TextStrokeTransparency=0,
        TextStrokeColor3=Color3.fromRGB(12,10,9),BackgroundTransparency=1,
    },canvas)
    local icon = ui("TextLabel",{
        Name="Glyph",Size=UDim2.fromScale(1,1),Text="!",
        Font=Enum.Font.GothamBlack,TextSize=69,
        TextColor3=GOLDLIGHT,TextStrokeTransparency=0.06,
        TextStrokeColor3=Color3.fromRGB(28,19,10),BackgroundTransparency=1,
    },canvas)
    markersByGiver[name] = { Gui=gui, Icon=icon, Shadow=shadow, Scale=scale, Head=root }
    -- Show a dimmed glyph straight away so a giver reads as a quest giver while the
    -- player's profile is still loading. syncMarkers() replaces the dim state with
    -- the real glyph and colour as soon as the snapshot arrives.
    icon.TextTransparency = 0.55
    shadow.TextTransparency = 0.55
    if workspace:GetAttribute("LumiaQuestDebug") == true then
        print(string.format("[Quest Debug] marker attached: %s at t=%.2f", name, os.clock()))
    end
    gui.Enabled = true
end
task.spawn(function()
    local world = workspace:WaitForChild("LumiaQuestWorld", 40)
    if not world then return end
    local function scan()
        for _, desc in ipairs(world:GetDescendants()) do
            if desc:IsA("Model") and desc:GetAttribute("LumiaNPCType") == "QuestGiver" then
                attachMarkerForGiver(desc)
            end
        end
    end
    scan()
    world.DescendantAdded:Connect(function(d)
        if d:IsA("Model") and d:GetAttribute("LumiaNPCType") == "QuestGiver" then
            attachMarkerForGiver(d)
        end
    end)
    if snapshot then syncMarkers() end
end)

-- Frame-perfect hover and cursor alignment: no previous 65ms throttle.
-- E is never shown; only a gold star and TALK/EXAMINE near the actual mouse.
local pointer=ui("Frame",{
    Name="QuestStarCursor",Size=UDim2.fromOffset(112,29),
    BackgroundTransparency=1,Visible=false,Active=false,ZIndex=140,
},gui)
local star=round(ui("TextLabel",{
    Name="Symbol",Size=UDim2.fromOffset(29,29),
    Text="✦",Font=Enum.Font.Garamond,TextSize=23,
    TextColor3=Color3.fromRGB(247,201,101),BackgroundColor3=Color3.fromRGB(66,48,20),
    ZIndex=141,
},pointer),14)
outline(star,Color3.fromRGB(214,162,79),1)
local hint=round(ui("TextLabel",{
    Name="Interact",Position=UDim2.fromOffset(31,3),Size=UDim2.fromOffset(79,24),
    Text="INTERACT",Font=Enum.Font.GothamBold,TextSize=11,
    TextColor3=Color3.fromRGB(243,207,139),
    BackgroundColor3=Color3.fromRGB(27,23,19),ZIndex=141,
},pointer),4)
-- The native cursor is NEVER hidden. This star is a badge that travels with the
-- real pointer, not a replacement for it: replacing the cursor put the visible
-- glyph ~26px right and ~22px below the true click point, which felt like a
-- cursor that was out of sync with the aim.
UserInputService.MouseIconEnabled = true

local function setPointer(show,caption)
    pointer.Visible=show
    if show then
        hint.Text=caption or "INTERACT"
        local mousePosition=UserInputService:GetMouseLocation()
        local topLeftInset=GuiService:GetGuiInset()
        pointer.Position=UDim2.fromOffset(
            mousePosition.X-topLeftInset.X+12,
            mousePosition.Y-topLeftInset.Y+8)
    end
end
local function findQuestPart(target)
    if not target then return nil end
    if CollectionService:HasTag(target,"LumiaQuestInteractable") then return target end
    local ancestor=target:FindFirstAncestorOfClass("Model")
    if ancestor and ancestor:GetAttribute("LumiaNPCType")=="QuestGiver" then
        return ancestor:FindFirstChild("HumanoidRootPart") or ancestor.PrimaryPart
    end
    return nil
end
local function targetLabel()
    if window.Visible or dialogueWindow.Visible or player:GetAttribute("LumiaOptionsOpen") then return nil end
    local lootGui=playerGui:FindFirstChild("LumiaLoot")
    local lootWindow=lootGui and lootGui:FindFirstChild("LootWindow")
    if lootWindow and lootWindow.Visible then return nil end
    if UserInputService:GetFocusedTextBox() then return nil end
    local character=player.Character
    local root=character and character:FindFirstChild("HumanoidRootPart")
    local humanoid=character and character:FindFirstChildOfClass("Humanoid")
    if not root or not humanoid or humanoid.Health<=0 then return nil end
    local aimed=mouse.Target
    if not aimed then return nil end
    -- One shared cursor displays LOOT / INTERACT / EXAMINE; server controls the action.
    local corpse=aimed:FindFirstAncestorOfClass("Model")
    if corpse and corpse:GetAttribute("LumiaLootableCorpse")==true
        and corpse:GetAttribute("LumiaLootOwnerUserId")==player.UserId then
        local corpseRoot=corpse:FindFirstChild("HumanoidRootPart")
        if corpseRoot and (root.Position-corpseRoot.Position).Magnitude<=12 then
            return "LOOT"
        end
    end
    if corpse and corpse:GetAttribute("LumiaMerchant") then
        return (root.Position-corpse:GetPivot().Position).Magnitude<=14 and "TRADE" or nil
    end
    local target=findQuestPart(aimed)
    if not target or not target:IsA("BasePart") then return nil end
    local model=target:FindFirstAncestorOfClass("Model")
    if model and model:GetAttribute("LumiaNPCType")=="QuestGiver" then
        return (root.Position-target.Position).Magnitude<=14 and "INTERACT" or nil
    end
    if target:GetAttribute("LumiaInteractType")~="QuestClue" then return nil end
    if (root.Position-target.Position).Magnitude>11 then return nil end
    local current=snapshot and snapshot.Quest
    if not current or not current.Active or current.ReadyToTurnIn or (current.Kind~="Explore" and current.Kind~="Ritual") then return nil end
    if target:GetAttribute("QuestZone")~=current.Zone then return nil end
    local id=target:GetAttribute("QuestMarkerId")
    if current.Seen and current.Seen[id] then return nil end
    if current.Kind=="Ritual" and target:GetAttribute("QuestOrder") ~= current.Progress+1 then return nil end
    return current.Kind=="Ritual" and "CHANNEL" or "EXAMINE"
end
-- v7 subtle active-clue shimmer. Local-only and distance-gated: no quest GPS.
-- A clue is highlighted ONLY if it belongs to the current active explore quest
-- and the player has not inspected it yet. All other players see plain props.
local clueHighlights={}
local function updateClueGlow()
    local q=snapshot and snapshot.Quest
    local character=player.Character
    local root=character and character:FindFirstChild("HumanoidRootPart")
    for _,clue in ipairs(CollectionService:GetTagged("LumiaQuestInteractable")) do
        if clue:IsA("BasePart") and clue:IsDescendantOf(workspace) then
            local id=clue:GetAttribute("QuestMarkerId")
            local relevant=q and q.Active and not q.ReadyToTurnIn and (q.Kind=="Explore" or q.Kind=="Ritual")
                and q.Zone==clue:GetAttribute("QuestZone")
                and not (q.Seen and q.Seen[id])
                and (q.Kind~="Ritual" or clue:GetAttribute("QuestOrder")==q.Progress+1)
            local near=root and (root.Position-clue.Position).Magnitude<=(id=="ruins_3" and 110 or 65)
            local enabled=(relevant and near)==true
            local model=clue:FindFirstAncestorOfClass("Model")
            if enabled and model then
                local highlight=clueHighlights[clue]
                if not highlight or not highlight.Parent then
                    highlight=Instance.new("Highlight")
                    highlight.Name="LumiaQuestClueSubtleGlow"
                    highlight.Adornee=model
                    highlight.DepthMode=Enum.HighlightDepthMode.Occluded
                    highlight.FillColor=Color3.fromRGB(241,207,114)
                    highlight.OutlineColor=Color3.fromRGB(241,202,99)
                    highlight.FillTransparency=0.86
                    highlight.OutlineTransparency=0.56
                    highlight.Parent=model
                    clueHighlights[clue]=highlight
                end
                highlight.Enabled=true
            else
                local highlight=clueHighlights[clue]
                if highlight then highlight.Enabled=false end
            end
        end
    end
end
-- Classic RPG quest-object cast bar. Server starts, validates and finishes the cast.
-- Client clock is DISPLAY ONLY, never grants an objective.
local castFrame=round(ui("Frame",{
    Name="QuestInteractionCast",AnchorPoint=Vector2.new(0.5,1),
    Position=UDim2.new(0.5,0,1,-116),Size=UDim2.fromOffset(360,67),
    BackgroundColor3=Color3.fromRGB(30,25,20),BorderSizePixel=0,
    Visible=false,ZIndex=155,
},gui),8)
outline(castFrame,Color3.fromRGB(196,151,71),2)
local castLabel=label(castFrame,"CastTitle","EXAMINING",UDim2.fromOffset(13,6),
    UDim2.new(1,-26,0,21),Enum.Font.GothamSemibold,14,GOLDLIGHT)
castLabel.ZIndex=156
local castBackground=round(ui("Frame",{
    Name="Track",Position=UDim2.fromOffset(12,33),Size=UDim2.new(1,-24,0,21),
    BackgroundColor3=Color3.fromRGB(65,58,48),BorderSizePixel=0,ZIndex=156,
},castFrame),4)
local castFill=round(ui("Frame",{
    Name="Progress",Size=UDim2.fromScale(0,1),
    BackgroundColor3=Color3.fromRGB(217,157,68),BorderSizePixel=0,ZIndex=157,
},castBackground),4)
local castTime=label(castBackground,"Remaining","5.0s",UDim2.fromScale(0,0),
    UDim2.fromScale(1,1),Enum.Font.GothamBold,12,Color3.fromRGB(255,241,200))
castTime.TextXAlignment=Enum.TextXAlignment.Center
castTime.ZIndex=158
local castBusy=false
local castStart=0
local castSeconds=5
local castStartPosition=nil
local function stopCast()
    castBusy=false
    castFrame.Visible=false
    castStartPosition=nil
end
castRemote.OnClientEvent:Connect(function(status,labelText,seconds)
    if status=="Started" then
        castBusy=true
        castStart=os.clock()
        castSeconds=tonumber(seconds) or 5
        local root=player.Character and player.Character:FindFirstChild("HumanoidRootPart")
        castStartPosition=root and root.Position or nil
        castLabel.Text="EXAMINING  •  "..tostring(labelText)
        castFill.Size=UDim2.fromScale(0,1)
        castTime.Text=string.format("%.1fs",castSeconds)
        castFrame.Visible=true
    elseif status=="Completed" then
        stopCast()
    elseif status=="Cancelled" then
        stopCast()
        -- Existing quest toast handles errors; do not interrupt gameplay with modal UI.
    end
end)

player.CharacterAdded:Connect(function()
    if castBusy then
        interact:FireServer("CancelCast")
        stopCast()
    end
end)

-- Bind to current character setting; higher priority than Roblox camera ONLY when hovered on quest objects.
local QUEST_ACTION="Lumia_QuestInteract_v4"
local function bindQuestAction()
    ContextActionService:UnbindAction(QUEST_ACTION)
    local name=player:GetAttribute("LumiaInteractKey") or "MouseButton2"
    local input=name=="MouseButton2" and Enum.UserInputType.MouseButton2 or Enum.KeyCode[name]
    if not input then input=Enum.UserInputType.MouseButton2 end
    ContextActionService:BindActionAtPriority(QUEST_ACTION,function(_,state)
        if state~=Enum.UserInputState.Begin then return Enum.ContextActionResult.Pass end
        if UserInputService:GetFocusedTextBox() then return Enum.ContextActionResult.Pass end
        if castBusy then return Enum.ContextActionResult.Sink end
        local caption=targetLabel()
        if caption==nil or caption=="LOOT" then return Enum.ContextActionResult.Pass end
        -- A merchant is not a quest target. Passing the click through lets the
        -- merchant's own binding (priority 3200) open the shop; sinking it here
        -- silently swallowed every shop click.
        if caption=="TRADE" then return Enum.ContextActionResult.Pass end
        local target=findQuestPart(mouse.Target)
        if not target then return Enum.ContextActionResult.Pass end
        local npcModel=target:FindFirstAncestorOfClass("Model")
        if npcModel and npcModel:GetAttribute("LumiaNPCType")=="QuestGiver" then
            interact:FireServer(npcModel)
        else
            interact:FireServer(target)
        end
        return Enum.ContextActionResult.Sink
    end,false,3250,input)
end
player:GetAttributeChangedSignal("LumiaInteractKey"):Connect(bindQuestAction)
bindQuestAction()

local lastGlowRefresh=0
RunService.RenderStepped:Connect(function()
    if castBusy then
        local elapsed=os.clock()-castStart
        local fraction=math.clamp(elapsed/castSeconds,0,1)
        castFill.Size=UDim2.fromScale(fraction,1)
        castTime.Text=string.format("%.1fs",math.max(0,castSeconds-elapsed))
        if castStartPosition then
            local character=player.Character
            local root=character and character:FindFirstChild("HumanoidRootPart")
            if not root or (root.Position-castStartPosition).Magnitude>2.5 then
                interact:FireServer("CancelCast")
                stopCast()
            end
        end
    end
    if os.clock()-lastGlowRefresh>=0.3 then
        lastGlowRefresh=os.clock()
        updateClueGlow()
    end
    local target=(not castBusy) and targetLabel() or nil
    -- The quest pointer replaces the native mouse cursor with its own glyph.
    -- While any modal window is open the player needs a real cursor to click
    -- items, so suppress the pointer even when an NPC is under the window.
    if target~=nil and LumiaModalState:IsOpen() then target=nil end
    setPointer(target~=nil,target)
    local camera = workspace.CurrentCamera
    if camera then
        for _, entry in pairs(markersByGiver) do
            if entry.Head and entry.Head.Parent and entry.Scale then
                local d = (camera.CFrame.Position - entry.Head.Position).Magnitude
                entry.Scale.Scale = 1 - 0.58*math.clamp((d-14)/65, 0, 1)
            end
        end
    end
end)
script.Destroying:Connect(function()
    if castBusy then interact:FireServer("CancelCast") end
    stopCast()
    setPointer(false)
    ContextActionService:UnbindAction(QUEST_ACTION)
    for _,h in pairs(clueHighlights) do if h and h.Parent then h:Destroy() end end
end)
task.spawn(function()
    for _=1,30 do
        refresh()
        if snapshot then break end
        task.wait(1)
    end
end)
print("[Lumia - Quest Journal] v6: portrait dialogue, fixed-height quest marker, unified hover/loot cursor")
