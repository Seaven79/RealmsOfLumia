-- Realms of Lumia: NPC quests, naturally-discoverable clue props.
-- Play-mode generated props only; does NOT alter the Studio-saved ForgottenForest map.
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local Workspace=game:GetService("Workspace")
local CollectionService=game:GetService("CollectionService")
local lumia=ReplicatedStorage:WaitForChild("Lumia")
local shared=lumia:WaitForChild("Shared")
local Config=require(shared:WaitForChild("Quests"):WaitForChild("QuestConfig"))
local QuestService=require(script.Parent:WaitForChild("QuestService"))
local network=lumia:FindFirstChild("QuestNetwork")
if not network then network=Instance.new("Folder"); network.Name="QuestNetwork"; network.Parent=lumia end
local function remote(name,class)
    local r=network:FindFirstChild(name)
    if r then assert(r.ClassName==class,"Quest remote type mismatch: "..name); return r end
    r=Instance.new(class); r.Name=name; r.Parent=network; return r
end
local getJournal=remote("GetJournal","RemoteFunction")
local changed=remote("JournalChanged","RemoteEvent")
local message=remote("QuestMessage","RemoteEvent")
local interact=remote("QuestInteract","RemoteEvent")
local questCast=remote("QuestCastState","RemoteEvent")
local dialogue=remote("QuestDialogue","RemoteEvent")
local questAction=remote("QuestAction","RemoteFunction")
local resetQuest=remote("ResetMyQuests","RemoteFunction")
resetQuest.OnServerInvoke=function(player)
    local ok,reply=QuestService:ResetMyQuests(player)
    return {Ok=ok,Message=reply}
end
getJournal.OnServerInvoke=function(player) return QuestService:Snapshot(player) end
QuestService:SetNotifier(changed)
QuestService:Start()

-- Explicit server-authoritative quest decisions: no reward without interaction.
local actionBusy={}
local function questGiver(player)
    local snapshot=QuestService:Snapshot(player)
    local q=snapshot and snapshot.Quest
    local name=(q and q.Giver) or "ElderRowan"
    local world=Workspace:FindFirstChild("LumiaQuestWorld")
    return world and world:FindFirstChild(name),name
end
local function nearQuestNPC(player)
    local character=player.Character
    local root=character and character:FindFirstChild("HumanoidRootPart")
    local health=character and character:FindFirstChildOfClass("Humanoid")
    local actor=questGiver(player)
    local npcRoot=actor and (actor:FindFirstChild("HumanoidRootPart") or actor.PrimaryPart)
    return root~=nil and health~=nil and health.Health>0 and npcRoot~=nil
        and (root.Position-npcRoot.Position).Magnitude<=16
end
questAction.OnServerInvoke=function(player,verb)
    if actionBusy[player] then return {Ok=false,Message="Please wait"} end
    if type(verb)~="string" then return {Ok=false,Message="Invalid action"} end
    if verb~="Abandon" and not nearQuestNPC(player) then
        return {Ok=false,Message="You must speak to the quest giver"}
    end
    actionBusy[player]=true
    local ok,result,reason=pcall(function()
        if verb=="Accept" then return QuestService:Accept(player) end
        if verb=="TurnIn" then return QuestService:TurnIn(player) end
        if verb=="Abandon" then return QuestService:Abandon(player) end
        return false,"Invalid action"
    end)
    actionBusy[player]=nil
    if not ok then
        warn("[Lumia - Quest Bridge] Quest action error: "..tostring(result))
        return {Ok=false,Message="Quest action failed. Please try again."}
    end
    return {Ok=result==true,Message=tostring(reason),Snapshot=QuestService:Snapshot(player)}
end

local folder=Workspace:FindFirstChild("LumiaQuestWorld")
if not folder then folder=Instance.new("Folder"); folder.Name="LumiaQuestWorld"; folder.Parent=Workspace end
for _,v in ipairs(folder:GetChildren()) do
    if v.Name=="FirstPathsQuestBoard" or v.Name=="ElderRowan" or
        v.Name:sub(1,7)=="Marker_" or v.Name:sub(1,5)=="Clue_" then
        v:Destroy()
    end
end
local function part(name,size,color,material,cf,parent,shape)
    local p=Instance.new("Part")
    p.Name=name; p.Size=size; p.Color=color; p.Material=material
    p.CFrame=cf; p.Anchored=true; p.CanCollide=false; p.CanTouch=false
    p.TopSurface=Enum.SurfaceType.Smooth; p.BottomSurface=Enum.SurfaceType.Smooth
    if shape then p.Shape=shape end
    p.Parent=parent
    return p
end
local function groundAt(x,z)
    local params=RaycastParams.new()
    params.FilterType=Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances={folder}
    local hit=Workspace:Raycast(Vector3.new(x,130,z),Vector3.new(0,-260,0),params)
    return hit and hit.Position.Y or 0
end
local forest=Workspace:FindFirstChild("ForgottenForest") or Workspace:WaitForChild("ForgottenForest",15)
local grass=forest and forest:FindFirstChild("Grassland")
local center=grass and grass:IsA("BasePart") and grass.Position or Vector3.zero

-- Realms of Lumia: Elder Rowan is a true R15 Humanoid with wandering/idle behavior.
-- Server validates all clicks. Never changes the saved map or DataStore.
local Players=game:GetService("Players")
local spawn=forest and forest:FindFirstChild("Village Spawn")
local px,pz
if spawn and spawn:IsA("BasePart") then
    px=spawn.Position.X+Config.QuestGiverOffset.X
    pz=spawn.Position.Z+Config.QuestGiverOffset.Z
else
    px=center.X+11; pz=center.Z-55
end
local floorY=groundAt(px,pz)
local home=Vector3.new(px,floorY+3,pz)
local npc
local humanoid
local rigOk,rigOrError=pcall(function()
    local description=Instance.new("HumanoidDescription")
    description.HeightScale=1
    description.WidthScale=1
    description.DepthScale=1
    description.HeadScale=1
    description.BodyTypeScale=0
    description.ProportionScale=0
    return Players:CreateHumanoidModelFromDescription(description,Enum.HumanoidRigType.R15)
end)
if rigOk and typeof(rigOrError)=="Instance" and rigOrError:IsA("Model") then
    npc=rigOrError
    humanoid=npc:FindFirstChildOfClass("Humanoid")
else
    warn("[Lumia - Quest Bridge] R15 elder unavailable; using stationary fallback: "..tostring(rigOrError))
    npc=Instance.new("Model")
    local base=part("Torso",Vector3.new(2.2,3.3,1.1),Color3.fromRGB(42,79,55),Enum.Material.Fabric,
        CFrame.new(px,floorY+2.7,pz),npc)
    part("Head",Vector3.new(1.4,1.4,1.4),Color3.fromRGB(226,190,149),Enum.Material.SmoothPlastic,
        CFrame.new(px,floorY+5,pz),npc,Enum.PartType.Ball)
    npc.PrimaryPart=base
end
npc.Name="ElderRowan"
npc:SetAttribute("LumiaNPCName","Elder Rowan")
npc:SetAttribute("LumiaNPCType","QuestGiver")
npc.Parent=folder
if humanoid then
    npc:PivotTo(CFrame.new(home))
    humanoid.WalkSpeed=7
    humanoid.JumpPower=0
    humanoid.DisplayDistanceType=Enum.HumanoidDisplayDistanceType.None
    humanoid.MaxHealth=1e7
    humanoid.Health=1e7
    for _,bodyPart in ipairs(npc:GetDescendants()) do
        if bodyPart:IsA("BasePart") then
            -- Keep normal R15 physics collision so he can stand on the ground.
            bodyPart.CanTouch=false
        end
    end
    local bodyColors=npc:FindFirstChildOfClass("BodyColors") or Instance.new("BodyColors")
    bodyColors.Name="ElderColors"
    bodyColors.HeadColor3=Color3.fromRGB(225,181,140)
    bodyColors.LeftArmColor3=Color3.fromRGB(40,82,61)
    bodyColors.RightArmColor3=Color3.fromRGB(40,82,61)
    bodyColors.TorsoColor3=Color3.fromRGB(43,92,65)
    bodyColors.LeftLegColor3=Color3.fromRGB(80,61,42)
    bodyColors.RightLegColor3=Color3.fromRGB(80,61,42)
    bodyColors.Parent=npc
    -- Keep server ownership for steady walk replication to all clients.
    local main=npc:FindFirstChild("HumanoidRootPart")
    if main then pcall(function() main:SetNetworkOwner(nil) end) end
end
local head=npc:FindFirstChild("Head") or npc.PrimaryPart
local rootPart=npc:FindFirstChild("HumanoidRootPart") or npc.PrimaryPart
local function addHairPiece(partName,shape,size,offset,color,material)
    if not head or not rootPart or not humanoid then return end
    local visual=Instance.new("Part")
    visual.Name=partName
    visual.Shape=shape
    visual.Size=size
    visual.Color=color
    visual.Material=material
    visual.CanCollide=false
    visual.CanTouch=false
    visual.CanQuery=false
    visual.Massless=true
    visual.CFrame=head.CFrame*offset
    visual.Parent=npc
    local weld=Instance.new("WeldConstraint")
    weld.Part0=head; weld.Part1=visual; weld.Parent=visual
end
addHairPiece("SilverHair",Enum.PartType.Ball,Vector3.new(1.28,0.45,1.13),CFrame.new(0,0.48,0.02),Color3.fromRGB(190,195,188),Enum.Material.SmoothPlastic)
addHairPiece("GreyBeard",Enum.PartType.Block,Vector3.new(0.78,0.85,0.3),CFrame.new(0,-0.48,-0.48),Color3.fromRGB(203,207,202),Enum.Material.SmoothPlastic)
-- Names and quest markers remain independent; each player receives their own quest icon.
if head then
    local label=Instance.new("BillboardGui")
    label.Name="NPCTitle"; label.Adornee=head; label.Size=UDim2.fromOffset(200,32)
    label.StudsOffsetWorldSpace=Vector3.new(0,1.65,0); label.MaxDistance=70; label.Parent=head
    local title=Instance.new("TextLabel")
    title.Name="Name"; title.Size=UDim2.fromScale(1,1); title.Text="Elder Rowan"
    title.BackgroundTransparency=1; title.Font=Enum.Font.GothamSemibold; title.TextSize=16
    title.TextColor3=Color3.fromRGB(243,217,160)
    title.TextStrokeColor3=Color3.fromRGB(19,16,11); title.TextStrokeTransparency=0.15
    title.Parent=label
end
local npcPauseUntil=0
local function talkTo(player, actor)
    local wanted=questGiver(player)
    if not actor or actor~=wanted then return end
    local character=player.Character
    local playerRoot=character and character:FindFirstChild("HumanoidRootPart")
    local anchor=actor:FindFirstChild("HumanoidRootPart") or actor.PrimaryPart
    if not playerRoot or not anchor or (playerRoot.Position-anchor.Position).Magnitude>16 then return end
    if actor==npc then npcPauseUntil=os.clock()+6 end
    if actor==npc and humanoid then
        humanoid:MoveTo(anchor.Position)
        humanoid.WalkSpeed=0
        local goal=Vector3.new(playerRoot.Position.X,anchor.Position.Y,playerRoot.Position.Z)
        if (goal-anchor.Position).Magnitude>0.3 then
            npc:PivotTo(CFrame.lookAt(npc:GetPivot().Position,Vector3.new(goal.X,npc:GetPivot().Position.Y,goal.Z)))
        end
    end
    -- Opening the NPC is a read-only preview. Players explicitly choose a button.
    dialogue:FireClient(player,QuestService:Talk(player))
end
-- Interactions arrive through QuestInteract; left-click detectors removed.
if humanoid then
    local animator=humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator")
    animator.Parent=humanoid
    local function tryTrack(assetId)
        local animation=Instance.new("Animation")
        animation.AnimationId="rbxassetid://"..assetId
        local ok,track=pcall(function() return animator:LoadAnimation(animation) end)
        animation:Destroy()
        return ok and track or nil
    end
    local idle=tryTrack("507766666")
    local walk=tryTrack("507777826")
    if idle then idle.Looped=true; idle.Priority=Enum.AnimationPriority.Idle; pcall(function() idle:Play(0.2) end) end
    if walk then walk.Looped=true; walk.Priority=Enum.AnimationPriority.Movement end
    humanoid.Running:Connect(function(speed)
        if walk then
            if speed>1 and os.clock()>=npcPauseUntil then
                if not walk.IsPlaying then walk:Play(0.2) end
                walk:AdjustSpeed(math.max(0.4,speed/10))
            elseif walk.IsPlaying then walk:Stop(0.2) end
        end
    end)
    -- Stay near the village. Walking is ambient, never required for quest progress.
    task.spawn(function()
        local rng=Random.new()
        while npc.Parent and humanoid.Health>0 do
            if os.clock()<npcPauseUntil then
                humanoid.WalkSpeed=0
                task.wait(0.5)
            else
                humanoid.WalkSpeed=7
                local dx=rng:NextNumber(-9,9)
                local dz=rng:NextNumber(-9,9)
                local destX=px+dx
                local destZ=pz+dz
                local destination=Vector3.new(destX,groundAt(destX,destZ)+2.5,destZ)
                humanoid:MoveTo(destination)
                local finished=false
                local conn
                conn=humanoid.MoveToFinished:Connect(function() finished=true end)
                local startedAt=os.clock()
                while npc.Parent and not finished and os.clock()-startedAt<3.5 and os.clock()>=npcPauseUntil do
                    task.wait(0.12)
                end
                if conn then conn:Disconnect() end
                humanoid:MoveTo((npc:FindFirstChild("HumanoidRootPart") or rootPart).Position)
                task.wait(rng:NextNumber(1.6,3.8))
            end
        end
    end)
end

-- Realistic, low-key world props instead of luminous waypoints or quest arrows.
-- They remain in the landscape for other players, but clients only expose a
-- mouseover star for an ACTIVE, relevant, not-yet-visited quest clue.
for idx,record in ipairs(Config.Markers) do
    local x=center.X+record.X
    local z=center.Z+record.Z
    local floorY=groundAt(x,z)
    local model=Instance.new("Model")
    model.Name="Clue_"..record.Id; model.Parent=folder
    local clue
    if idx%3==1 then
        clue=part("OldMarker",Vector3.new(1.5,2.1,0.5),Color3.fromRGB(120,99,68),Enum.Material.Wood,
            CFrame.new(x,floorY+1.1,z)*CFrame.Angles(0,math.rad(18),0),model)
        part("MarkerCap",Vector3.new(1.7,0.28,0.75),Color3.fromRGB(86,67,46),Enum.Material.Wood,
            CFrame.new(x,floorY+2.2,z),model)
    elseif idx%3==2 then
        clue=part("BrokenStone",Vector3.new(2.2,1.3,1.5),Color3.fromRGB(110,110,105),Enum.Material.Slate,
            CFrame.new(x,floorY+0.7,z)*CFrame.Angles(0,math.rad(27),math.rad(7)),model)
    else
        clue=part("AncientPost",Vector3.new(1,2.4,1),Color3.fromRGB(103,109,99),Enum.Material.Slate,
            CFrame.new(x,floorY+1.2,z),model)
    end
    clue:SetAttribute("LumiaInteractType","QuestClue")
    clue:SetAttribute("QuestMarkerId",record.Id)
    clue:SetAttribute("QuestZone",record.Zone)
    clue:SetAttribute("ClueLabel",record.Label)
    CollectionService:AddTag(clue,"LumiaQuestInteractable")
    -- All monster navigation/spawn checks already respect this shared tag.
    -- Expand the marker model's bounds to create a usable no-creature buffer.
    local noMob=part("NoMobFootprint",Vector3.new(6,2,6),Color3.new(0,0,0),
        Enum.Material.SmoothPlastic,CFrame.new(x,floorY+1,z),model)
    noMob.Transparency=1; noMob.CanQuery=false; noMob.CastShadow=false
    CollectionService:AddTag(model,"LumiaNoMobHouse")
end
-- A clue requires a REAL server-authoritative uninterrupted five-second cast.
-- Clients only display progress. Never trust client clocks or progress messages.
local CAST_SECONDS=5
local CAST_MOVE_TOLERANCE=2.5
local activeCasts={}
local function castStillValid(player,cast)
    if not player or player.Parent~=Players then return false end
    local target=cast.Target
    if typeof(target)~="Instance" or not target:IsA("BasePart") or not target:IsDescendantOf(folder)
        or not CollectionService:HasTag(target,"LumiaQuestInteractable")
        or target:GetAttribute("LumiaInteractType")~="QuestClue" then return false end
    local character=player.Character
    local root=character and character:FindFirstChild("HumanoidRootPart")
    local humanoid=character and character:FindFirstChildOfClass("Humanoid")
    if not root or not humanoid or humanoid.Health<=0 then return false end
    if (root.Position-cast.StartPosition).Magnitude>CAST_MOVE_TOLERANCE then return false end
    if (root.Position-target.Position).Magnitude>12 then return false end
    local markerId=target:GetAttribute("QuestMarkerId")
    return type(markerId)=="string" and QuestService:IsVisitAvailable(player,markerId)
end
local function cancelCast(player,reason)
    if not activeCasts[player] then return end
    activeCasts[player]=nil
    if player.Parent==Players then
        questCast:FireClient(player,"Cancelled",reason or "Interaction interrupted")
    end
end
local function beginCast(player,target,root)
    if activeCasts[player] then return end
    local markerId=target:GetAttribute("QuestMarkerId")
    if type(markerId)~="string" or not QuestService:IsVisitAvailable(player,markerId) then return end
    local cast={Target=target,StartPosition=root.Position,StartedAt=os.clock()}
    activeCasts[player]=cast
    questCast:FireClient(player,"Started",tostring(target:GetAttribute("ClueLabel") or "Investigating"),CAST_SECONDS)
    task.spawn(function()
        while activeCasts[player]==cast do
            if not castStillValid(player,cast) then
                cancelCast(player,"Moved away or quest unavailable")
                return
            end
            if os.clock()-cast.StartedAt>=CAST_SECONDS then break end
            task.wait(0.08)
        end
        if activeCasts[player]~=cast then return end
        if not castStillValid(player,cast) then
            cancelCast(player,"Interaction interrupted")
            return
        end
        -- Clear before granting credit; fast clicks cannot complete twice.
        activeCasts[player]=nil
        local id=target:GetAttribute("QuestMarkerId")
        if QuestService:Visit(player,id) then
            questCast:FireClient(player,"Completed",tostring(target:GetAttribute("ClueLabel") or "Clue"))
            message:FireClient(player,"You discovered: "..tostring(target:GetAttribute("ClueLabel") or "a clue"),true)
        else
            questCast:FireClient(player,"Cancelled","Quest objective no longer available")
        end
    end)
end

-- Every interaction is validated server-side: distance, ownership, quest state, and target.
local lastInteract={}
interact.OnServerEvent:Connect(function(player,target)
    if player.Parent~=Players then return end
    if target=="CancelCast" then
        cancelCast(player,"Cancelled")
        return
    end
    if typeof(target)~="Instance" then return end
    local character=player.Character
    local root=character and character:FindFirstChild("HumanoidRootPart")
    local humanoidPlayer=character and character:FindFirstChildOfClass("Humanoid")
    if not root or not humanoidPlayer or humanoidPlayer.Health<=0 then return end
    local now=os.clock()
    if lastInteract[player] and now-lastInteract[player]<0.18 then return end
    lastInteract[player]=now
    local actor=target:IsA("Model") and target or target:FindFirstAncestorOfClass("Model")
    if actor and actor:GetAttribute("LumiaNPCType")=="QuestGiver"
        and actor:IsDescendantOf(folder) then
        talkTo(player,actor)
        return
    end
    if not target:IsA("BasePart") or not target:IsDescendantOf(folder)
        or not CollectionService:HasTag(target,"LumiaQuestInteractable")
        or target:GetAttribute("LumiaInteractType")~="QuestClue"
        or (root.Position-target.Position).Magnitude>12 then return end
    beginCast(player,target,root)
end)
Players.PlayerRemoving:Connect(function(player)
    activeCasts[player]=nil
    lastInteract[player]=nil
    actionBusy[player]=nil
end)
print("[Lumia - Quest Bridge] Walking Elder Rowan and quest clue props ready")
