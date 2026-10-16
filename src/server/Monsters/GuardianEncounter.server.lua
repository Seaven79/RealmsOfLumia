-- Realms of Lumia V17: final boss requires TWO level-five adventurers.
-- Only server-confirmed sword hits and living, nearby participants grant completion.
local Players=game:GetService("Players")
local Workspace=game:GetService("Workspace")
local services=script.Parent.Parent
local Data=require(services:WaitForChild("Players"):WaitForChild("PlayerDataService"))
local Quests=require(services:WaitForChild("Quests"):WaitForChild("QuestService"))
local Achievements=require(services:WaitForChild("Progression"):WaitForChild("AchievementService"))
local Monsters=require(script.Parent:WaitForChild("MonsterService"))
local Life=require(script.Parent:WaitForChild("MonsterLifecycleEvents"))
local map=Workspace:WaitForChild("LumiaOpenWorldV15",45)
local anchor=map and map:FindFirstChild("GuardianEncounterAnchor")
if not anchor or not anchor:IsA("BasePart") then
    warn("[Lumia V17] Guardian encounter skipped: boss anchor missing")
    return
end
local active=nil
local nextSpawn=0
local desertedSince=nil
local function eligible(player)
    local profile=Data:GetProfile(player)
    if not profile or profile.Character.Level<5 then return false end
    local done=profile.Progression.CompletedQuests or {}
    local activeQuests=profile.Progression.ActiveQuests or {}
    if not done.fp15 or done.fp16 or not activeQuests.fp16 then return false end
    local c=player.Character
    local h=c and c:FindFirstChildOfClass("Humanoid")
    local r=c and c:FindFirstChild("HumanoidRootPart")
    return r~=nil and h~=nil and h.Health>0
        and (r.Position-anchor.Position).Magnitude<=46
end
local function group()
    local found={}
    for _,player in ipairs(Players:GetPlayers()) do
        if eligible(player) then table.insert(found,player) end
    end
    return found
end
Life.Died.Event:Connect(function(model,monsterId)
    if monsterId~="ThornboundGuardian" or model~=active or
        model:GetAttribute("LumiaBossEncounter")~=true then return end
    local adventurers=group()
    local valid={}
    for _,p in ipairs(adventurers) do
        if (model:GetAttribute("LumiaBossHit_"..p.UserId) or 0)>=1 then
            valid[#valid+1]=p
        end
    end
    if #valid==2 then
        for _,player in ipairs(valid) do
            Quests:Advance(player,"Kill","ThornboundGuardian")
            Achievements:Award(player,"GuardiansOfLumia")
        end
        print("[Lumia V17] Guardian defeated by two verified players")
    else
        warn("[Lumia V17] Guardian died without two eligible contributors; no quest or achievement rewards")
    end
    active=nil
    nextSpawn=os.clock()+45
end)
task.spawn(function()
    while anchor.Parent do
        local adventurers=group()
        if active and not active.Parent then
            active=nil
            nextSpawn=os.clock()+40
        end
        if active then
            if #adventurers==0 and not desertedSince then desertedSince=os.clock() end
            if #adventurers>0 then desertedSince=nil end
            if desertedSince and os.clock()-desertedSince>45 then
                local abandoned=active
                active=nil
                abandoned:Destroy()
                nextSpawn=os.clock()+12
                desertedSince=nil
            end
        elseif os.clock()>=nextSpawn and #adventurers==2 then
            local boss=Monsters:SpawnMonster("ThornboundGuardian",anchor.Position,false)
            if boss then
                boss:SetAttribute("LumiaBossEncounter",true)
                pcall(function()boss:ScaleTo(1.45)end)
                local glow=Instance.new("Highlight")
                glow.FillColor=Color3.fromRGB(121,69,140)
                glow.OutlineColor=Color3.fromRGB(238,170,108)
                glow.FillTransparency=.65
                glow.OutlineTransparency=.12
                glow.Parent=boss
                local humanoid=boss:FindFirstChildOfClass("Humanoid")
                if humanoid then
                    humanoid.HealthChanged:Connect(function(health)
                        if health>0 and health<=humanoid.MaxHealth*.5
                            and boss:GetAttribute("LumiaBossEnraged")~=true then
                            boss:SetAttribute("LumiaBossEnraged",true)
                            glow.FillColor=Color3.fromRGB(210,81,91)
                            glow.OutlineColor=Color3.fromRGB(255,185,117)
                            humanoid.DisplayName="Thornbound Guardian [Enraged]"
                        end
                    end)
                end
                active=boss
                print("[Lumia V17] Thornbound Guardian has appeared for two players")
            else
                nextSpawn=os.clock()+8
            end
        end
        task.wait(1.5)
    end
end)
