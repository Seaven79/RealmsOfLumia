-- Realms of Lumia: First Paths quests (v2: explicit acceptance and turn-in)
-- Gameplay state stays inside the existing persistent Progression tables.
-- All completion/XP/gold is server-authoritative; clients only receive snapshots.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local services = script.Parent.Parent
local PlayerData = require(services:WaitForChild("Players"):WaitForChild("PlayerDataService"))
local Progression = require(services:WaitForChild("Progression"):WaitForChild("ProgressionService"))
local Achievements = require(services:WaitForChild("Progression"):WaitForChild("AchievementService"))
local Inventory = require(services:WaitForChild("Inventory"):WaitForChild("InventoryService"))
local Life = require(services:WaitForChild("Monsters"):WaitForChild("MonsterLifecycleEvents"))
local Config = require(ReplicatedStorage:WaitForChild("Lumia"):WaitForChild("Shared"):WaitForChild("Quests"):WaitForChild("QuestConfig"))
local Currency=require(ReplicatedStorage.Lumia.Shared:WaitForChild("Commerce"):WaitForChild("LumiaCurrency"))
local Service = {}
local started = false
local notifier
local processed = setmetatable({}, {__mode="k"})
local busy = {}

local function state(player)
    local profile = PlayerData:GetProfile(player)
    if not profile or type(profile.Progression) ~= "table" then return nil end
    local progress = profile.Progression
    if type(progress.ActiveQuests) ~= "table" or type(progress.CompletedQuests) ~= "table" then return nil end
    return profile, progress
end

local function nextQuest(progress)
    for _, q in ipairs(Config.Quests) do
        if not progress.CompletedQuests[q.Id] then return q end
    end
    return nil
end

local function activeQuest(progress)
    local q = nextQuest(progress)
    return q, q and progress.ActiveQuests[q.Id] or nil
end

function Service:Snapshot(player)
    local profile, progress = state(player)
    if not profile then return {Ready=false, Message="Character still loading"} end
    local q,record = activeQuest(progress)
    -- V19 migration: old kill objectives at these IDs cannot count as new rituals.
    if q and q.Kind=="Ritual" and record and record.V19Ritual~=true then
        record.Count=0
        record.Seen={}
        record.V19Ritual=true
    end
    local finished = 0
    for _,entry in ipairs(Config.Quests) do
        if progress.CompletedQuests[entry.Id] then finished += 1 end
    end
    local count = record and math.clamp(tonumber(record.Count) or 0, 0, q.Count) or 0
    if q and record and q.Kind=="Collect" then
        count=math.min(q.Count,Inventory:GetQuantity(player,q.DropItemId))
    end
    local turnIn = record ~= nil and count >= q.Count
    return {
        Ready=true, Campaign=Config.CampaignId, Completed=finished, Total=#Config.Quests,
        Level=profile.Character.Level, Gold=profile.Character.Gold, AllComplete=(q==nil),
        NPCState=q==nil and "Done" or (record==nil and "Available" or (turnIn and "TurnIn" or "Active")),
        Quest=q and {
            Id=q.Id, Name=q.Name, Description=q.Description, Kind=q.Kind, Zone=q.Zone,
            Count=q.Count, Progress=count, Active=record~=nil, ReadyToTurnIn=turnIn,
            XP=q.XP, Gold=q.Gold, Giver=q.Giver or "ElderRowan", MinLevel=q.MinLevel or 1,
            Seen=record and table.clone(record.Seen or {}) or {},
            AcceptText=q.AcceptText, ProgressText=q.ProgressText, TurnInText=q.TurnInText,
        } or nil,
    }
end
function Service:SetNotifier(remote) notifier=remote end
function Service:Notify(player)
    if notifier and player and player.Parent==Players then
        notifier:FireClient(player,self:Snapshot(player))
    end
end

function Service:Accept(player)
    if busy[player] then return false,"Please wait" end
    local profile,progress = state(player)
    if not profile then return false,"Character still loading" end
    local q, record = activeQuest(progress)
    if not q then return false,"All quests completed" end
    if record then return false,"You already accepted this quest" end
    if (q.MinLevel or 1) > profile.Character.Level then return false,"Level too low for this quest" end
    progress.ActiveQuests[q.Id]={Count=0, Seen={}, V19Ritual=(q.Kind=="Ritual")}
    self:Notify(player)
    print("[Lumia - Quest Service] Accepted "..q.Id.." by "..player.Name)
    return true,"Quest accepted: "..q.Name
end

local function updateXPBar(player)
    local lumia=ReplicatedStorage:FindFirstChild("Lumia")
    local net=lumia and lumia:FindFirstChild("ProgressionNetwork")
    local remote=net and net:FindFirstChild("ProgressionChanged")
    local profile=PlayerData:GetProfile(player)
    if not remote or not remote:IsA("RemoteEvent") or not profile then return end
    local c=profile.Character
    remote:FireClient(player,{
        Ready=true,Level=c.Level,Experience=c.Experience,
        RequiredXP=Progression:GetRequiredXP(c.Level), MaxLevel=Progression:GetMaxLevel(),
    })
end

function Service:TurnIn(player)
    if busy[player] then return false,"Please wait" end
    local profile, progress=state(player)
    if not profile then return false,"Character still loading" end
    local q,record=activeQuest(progress)
    if not q then return false,"All quests completed" end
    if not record then return false,"Ask about your next quest" end
    local completed = (tonumber(record.Count) or 0)>=q.Count
    if q.Kind=="Collect" then
        completed=Inventory:GetQuantity(player,q.DropItemId)>=q.Count
    end
    if not completed then return false,"Objectives not complete" end
    busy[player]=true
    -- Reward before marking completion. No yields here: one user cannot claim twice.
    local goldOK,goldReason=Progression:AddGold(player,q.Gold)
    -- Rejection at max level is normal; the quest can still complete.
    if not goldOK then
        busy[player]=nil
        warn("[Lumia - Quest Service] Turn-in rejected: "..tostring(goldReason))
        return false,"Reward could not be granted; please try again"
    end
    local xpOK,xpReason=Progression:AddXP(player,q.XP)
    if not xpOK then print("[Lumia - Quest Service] XP not granted: "..tostring(xpReason)) end
    if q.Kind=="Collect" then
        local removed,reason=Inventory:RemoveQuantity(player,q.DropItemId,q.Count)
        if not removed then
            -- Inventory is checked again at the server; cannot turn in without items.
            -- Rewards are already granted above, but this branch is unreachable
            -- without a yielding operation. Keep a log if another module changes this.
            warn("[Lumia - Quest Service] Collect remove failed: "..tostring(reason))
            busy[player]=nil
            return false,"Could not hand over quest items"
        end
    end
    progress.CompletedQuests[q.Id]=true
    progress.ActiveQuests[q.Id]=nil
    Achievements:EvaluateProgress(player)
    updateXPBar(player)
    busy[player]=nil
    self:Notify(player)
    print("[Lumia - Quest Service] Turn-in "..q.Id.." by "..player.Name)
    return true,"Quest complete: "..q.Name.." | +"..Currency.FormatShort(q.Gold)
end

-- DEV ONLY: user-initiated reset of this campaign for the owner, no level/gold/inventory changes.
function Service:ResetMyQuests(player)
    if not player or player.UserId~=1614020138 then
        return false,"Only the DEV owner can reset quests"
    end
    local _,progress=state(player)
    if not progress then return false,"Character profile not ready" end
    for _,entry in ipairs(Config.Quests) do
        progress.CompletedQuests[entry.Id]=nil
        progress.ActiveQuests[entry.Id]=nil
    end
    for _,q in ipairs(Config.Quests) do
        if q.Kind=="Collect" then
            local held=Inventory:GetQuantity(player,q.DropItemId)
            if held>0 then Inventory:RemoveQuantity(player,q.DropItemId,held) end
        end
    end
    self:Notify(player)
    print("[Lumia - Quest Service] DEV owner reset The First Paths campaign: "..player.Name)
    return true,"Quest campaign reset. Return to Elder Rowan."
end

-- NPC conversation is read-only: never silently accept or turn in a quest.
-- The client must explicitly choose Accept or Complete Quest in the dialogue.
function Service:Talk(player)
    return self:Snapshot(player)
end

-- Abandon removes only this active quest record. The player can accept it
-- again from the NPC; prior completed quests and other progress stay intact.
function Service:Abandon(player)
    if busy[player] then return false,"Please wait" end
    local _,progress=state(player)
    if not progress then return false,"Character still loading" end
    local q,record=activeQuest(progress)
    if not q or not record then return false,"You have no active quest to abandon" end
    progress.ActiveQuests[q.Id]=nil
    if q.Kind=="Collect" then
        local held=Inventory:GetQuantity(player,q.DropItemId)
        if held>0 then Inventory:RemoveQuantity(player,q.DropItemId,held) end
    end
    self:Notify(player)
    print("[Lumia - Quest Service] Abandoned "..q.Id.." by "..player.Name)
    return true,"Quest abandoned. You can accept it again later."
end

function Service:Advance(player,kind,key)
    if busy[player] then return end
    local profile,progress=state(player)
    if not profile then return end
    local q,record=activeQuest(progress)
    if not q or not record or q.Kind~=kind then return end
    if (tonumber(record.Count) or 0)>=q.Count then return end
    if kind=="Kill" and q.MonsterId~=key then return end
    if kind=="Explore" or kind=="Ritual" then
        local marker
        for _,entry in ipairs(Config.Markers) do
            if entry.Id==key then marker=entry;break end
        end
        if not marker or marker.Zone~=q.Zone then return end
        if type(record.Seen)~="table" then record.Seen={} end
        if record.Seen[key] then return end
        -- Rituals must be activated in marker order, not by running to the last one.
        if kind=="Ritual" then
            local ordered={}
            for _, site in ipairs(Config.Markers) do
                if site.Zone==q.Zone then ordered[#ordered+1]=site.Id end
            end
            if ordered[(tonumber(record.Count) or 0)+1] ~= key then return end
        end
        record.Seen[key]=true
    end
    record.Count=math.min(q.Count,(tonumber(record.Count) or 0)+1)
    -- Deliberately NO auto rewards. Return to the NPC to turn in.
    self:Notify(player)
end

-- Generic long-term objective hook: any monster can drop any configured
-- quest item. Called by LootService only on the server after a confirmed kill.
function Service:GetMonsterQuestDrop(player,monsterId)
    local _,progress=state(player)
    if not progress then return nil end
    local q,record=activeQuest(progress)
    if not q or not record or q.Kind~="Collect" or q.MonsterId~=monsterId
        or type(q.DropItemId)~="string" or type(q.DropChance)~="number" then
        return nil
    end
    if Inventory:GetQuantity(player,q.DropItemId)>=q.Count then return nil end
    return q.DropItemId,math.clamp(q.DropChance,0,1)
end

function Service:IsVisitAvailable(player,markerId)
    local _,progress=state(player)
    if not progress then return false end
    local q,record=activeQuest(progress)
    if not q or not record or (q.Kind~="Explore" and q.Kind~="Ritual") or (tonumber(record.Count) or 0)>=q.Count then return false end
    for _,entry in ipairs(Config.Markers) do
        if entry.Id==markerId and entry.Zone==q.Zone then
            if type(record.Seen)=="table" and record.Seen[markerId] then return false end
            if q.Kind=="Ritual" then
                local index=0
                for _, candidate in ipairs(Config.Markers) do
                    if candidate.Zone==q.Zone then
                        index+=1
                        if candidate.Id==markerId then
                            return index == (tonumber(record.Count) or 0)+1
                        end
                    end
                end
                return false
            end
            return true
        end
    end
    return false
end
function Service:Visit(player,markerId)
    if not self:IsVisitAvailable(player,markerId) then return false end
    local _, progress=state(player)
    local q=progress and activeQuest(progress)
    if not q then return false end
    self:Advance(player,q.Kind,markerId)
    return true
end

local function onDeath(self,model,monsterId)
    if typeof(model)~="Instance" or not model:IsA("Model") or processed[model] then return end
    -- Cooperative Guardian is handled by GuardianEncounter with two verified participants.
    if monsterId=="ThornboundGuardian" then return end
    processed[model]=true
    if model:GetAttribute("LumiaDead")~=true then return end
    local id=model:GetAttribute("LumiaLastHitUserId")
    local lastHit=model:GetAttribute("LumiaLastHitAt")
    if type(id)~="number" or type(lastHit)~="number" then return end
    if os.clock()-lastHit<0 or os.clock()-lastHit>Config.HitCreditSeconds then return end
    local killer=Players:GetPlayerByUserId(id)
    if not killer or not PlayerData:GetProfile(killer) then return end
    local origin=model:GetPivot().Position
    for _,player in ipairs(Players:GetPlayers()) do
        if player==killer then self:Advance(player,"Kill",monsterId)
        else
            local character=player.Character
            local root=character and character:FindFirstChild("HumanoidRootPart")
            local humanoid=character and character:FindFirstChildOfClass("Humanoid")
            if root and humanoid and humanoid.Health>0 and (root.Position-origin).Magnitude<=Config.CoopCreditRadius then
                self:Advance(player,"Kill",monsterId)
            end
        end
    end
end
function Service:Start()
    if started then return end
    started=true
    Life.Died.Event:Connect(function(model,monsterId)
        local ok,err=pcall(onDeath,self,model,monsterId)
        if not ok then warn("[Lumia - Quest Service] Monster tracking: "..tostring(err)) end
    end)
    Players.PlayerRemoving:Connect(function(player) busy[player]=nil end)
    print("[Lumia - Quest Service] NPC turn-in quests active")
end
return Service
