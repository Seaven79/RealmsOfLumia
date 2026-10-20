-- Realms of Lumia V18 | The Thornbound Guardian
--
-- Always available: the boss forms whenever at least one adventurer enters the
-- arena, so a solo player can fight it. Difficulty scales with the number of
-- players present when it forms, and the fight has three phases with a rule the
-- player can learn and beat:
--
--   Phase 1 (100-65%)  Telegraphed ground slam. The red ring marks where it will
--                      land; step out of it and you take nothing.
--   Phase 2 (65-30%)   Slams land faster and the Guardian calls Whelps. Clear the
--                      adds or they grind you down while you dodge.
--   Phase 3 (below 30%) Enraged: bigger ring, shorter fuse, no more adds. Damage
--                      is up, so this is a race to finish before you run dry.
--
-- A player who lands at least one hit is credited, solo included. If everyone
-- leaves or dies the Guardian dissolves and re-forms on the next attempt.
local Players=game:GetService("Players")
local Workspace=game:GetService("Workspace")
local services=script.Parent.Parent
local Quests=require(services:WaitForChild("Quests"):WaitForChild("QuestService"))
local Achievements=require(services:WaitForChild("Progression"):WaitForChild("AchievementService"))
local CombatStats=require(services:WaitForChild("Combat"):WaitForChild("CombatStats"))
local Monsters=require(script.Parent:WaitForChild("MonsterService"))
local Life=require(script.Parent:WaitForChild("MonsterLifecycleEvents"))

local map=Workspace:WaitForChild("LumiaOpenWorldV15",45)
local anchor=map and map:FindFirstChild("GuardianEncounterAnchor")
if not anchor or not anchor:IsA("BasePart") then
    warn("[Lumia V18] Guardian encounter skipped: boss anchor missing")
    return
end

local ARENA_RADIUS=46
local ENGAGE_RADIUS=64
local REFORM_DELAY=30
local DESERT_GRACE=20

-- Ring radius is in studs; slamDamage is pre-armor, mitigation is applied through
-- CombatStats so gear still matters.
local PHASES={
    {
        id=1, untilFraction=0.65,
        slamInterval=6.5, telegraph=1.45, radius=12, slamDamage=22,
        addInterval=nil, maxAdds=0,
    },
    {
        id=2, untilFraction=0.30,
        slamInterval=5.0, telegraph=1.15, radius=13, slamDamage=26,
        addInterval=18, maxAdds=4,
    },
    {
        id=3, untilFraction=0,
        slamInterval=3.8, telegraph=0.95, radius=16, slamDamage=32,
        addInterval=nil, maxAdds=0,
    },
}

-- Solo gets a smaller health pool and softer hits; a group gets the full fight.
local function scalingFor(count)
    if count<=1 then return { health=0.55, damage=0.80 } end
    if count==2 then return { health=1.00, damage=1.00 } end
    return { health=1.25, damage=1.10 }
end

local active=nil
local fight=nil
local nextSpawn=0
local desertedSince=nil

local function rootOf(player)
    local character=player.Character
    if not character then return nil end
    local humanoid=character:FindFirstChildOfClass("Humanoid")
    local root=character:FindFirstChild("HumanoidRootPart")
    if not humanoid or not root or humanoid.Health<=0 then return nil end
    return root,humanoid
end

local function distanceToAnchor(player)
    local root=rootOf(player)
    if not root then return nil end
    return (root.Position-anchor.Position).Magnitude
end

local function nearbyPlayers()
    local found={}
    for _,player in ipairs(Players:GetPlayers()) do
        local distance=distanceToAnchor(player)
        if distance and distance<=ENGAGE_RADIUS then
            found[#found+1]=player
        end
    end
    return found
end

local function setPhaseGlow(boss,phaseId)
    local highlight=boss:FindFirstChildOfClass("Highlight")
    if not highlight then return end
    if phaseId>=3 then
        highlight.FillColor=Color3.fromRGB(210,81,91)
        highlight.OutlineColor=Color3.fromRGB(255,185,117)
    elseif phaseId==2 then
        highlight.FillColor=Color3.fromRGB(155,86,120)
        highlight.OutlineColor=Color3.fromRGB(244,178,116)
    end
end

local function clearFight()
    if not fight then return end
    for _,part in ipairs(fight.telegraphs) do
        if part.Parent then part:Destroy() end
    end
    for _,add in ipairs(fight.adds) do
        if add.Parent then add:Destroy() end
    end
    fight=nil
end

-- Ground level under a point. The anchor is not necessarily floor height (it can
-- sit above uneven terrain), which made the ring float. A downward ray finds the
-- real surface; characters and the boss are filtered out so nothing hits itself.
local RING_THICKNESS=0.12
local function groundBelow(x,y,z,boss)
    local ignore={boss}
    for _,player in ipairs(Players:GetPlayers()) do
        if player.Character then table.insert(ignore,player.Character) end
    end
    if fight then
        for _,add in ipairs(fight.adds) do
            if add.Parent then table.insert(ignore,add) end
        end
    end
    local params=RaycastParams.new()
    params.FilterType=Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances=ignore
    local origin=Vector3.new(x,y+8,z)
    local hit=Workspace:Raycast(origin,Vector3.new(0,-80,0),params)
    if hit then return hit.Position.Y end
    return anchor.Position.Y
end

-- One ring under one player, drawn flush with the floor and resolved once.
local function spawnRing(boss,phase,target)
    if not active then return end
    local root,humanoid=rootOf(target)
    if not root or not humanoid then return end
    local groundY=groundBelow(root.Position.X,root.Position.Y,root.Position.Z,boss)
    local center=Vector3.new(root.Position.X,groundY+RING_THICKNESS/2,root.Position.Z)

    local ring=Instance.new("Part")
    ring.Name="LumiaBossTelegraph"
    ring.Shape=Enum.PartType.Cylinder
    ring.Anchored=true
    ring.CanCollide=false
    ring.CanQuery=false
    ring.CanTouch=false
    ring.Material=Enum.Material.Neon
    ring.Color=Color3.fromRGB(196,63,74)
    ring.Transparency=0.62
    -- Thin disc lying flat: the cylinder axis is X, so rotate it onto Y.
    ring.Size=Vector3.new(RING_THICKNESS,phase.radius*2,phase.radius*2)
    ring.CFrame=CFrame.new(center)*CFrame.Angles(0,0,math.rad(90))
    ring.Parent=Workspace
    if fight then fight.telegraphs[#fight.telegraphs+1]=ring end

    local damageScale=tonumber(boss:GetAttribute("LumiaDamageScale")) or 1
    task.delay(phase.telegraph,function()
        if not ring.Parent then return end
        ring.Transparency=0.15
        ring.Color=Color3.fromRGB(255,124,84)
        for _,player in ipairs(nearbyPlayers()) do
            local playerRoot,playerHumanoid=rootOf(player)
            if playerRoot and playerHumanoid then
                local flat=Vector3.new(playerRoot.Position.X,center.Y,playerRoot.Position.Z)
                if (flat-center).Magnitude<=phase.radius then
                    playerHumanoid:TakeDamage(CombatStats.IncomingDamage(
                        player,phase.slamDamage*damageScale))
                end
            end
        end
        task.delay(0.3,function()
            if ring.Parent then ring:Destroy() end
        end)
    end)
end

-- Phase 1 marks one player so the rule is easy to read. From phase 2 every player
-- in range gets their own ring, staggered slightly - otherwise only the targeted
-- player had to move and the rest could stand in melee untouched, which made group
-- fights easier per player than solo.
local RING_STAGGER=0.28
local function startSlam(boss,phase)
    local crowd=nearbyPlayers()
    if #crowd==0 then return end
    if phase.id>=2 then
        for index,target in ipairs(crowd) do
            local delay=(index-1)*RING_STAGGER
            if delay<=0 then
                spawnRing(boss,phase,target)
            else
                task.delay(delay,function() spawnRing(boss,phase,target) end)
            end
        end
    else
        spawnRing(boss,phase,crowd[math.random(#crowd)])
    end
end

local function spawnWhelps(boss)
    if not fight then return end
    local alive=0
    for _,add in ipairs(fight.adds) do
        local humanoid=add.Parent and add:FindFirstChildOfClass("Humanoid")
        if humanoid and humanoid.Health>0 then alive+=1 end
    end
    local phase=PHASES[2]
    for _=1,math.min(2,math.max(0,phase.maxAdds-alive)) do
        local offset=Vector3.new(math.random(-12,12),0,math.random(-12,12))
        local whelp=Monsters:SpawnMonster("ThornboundWhelp",
            boss:GetPivot().Position+offset,false)
        if whelp then
            whelp:SetAttribute("LumiaBossAdd",true)
            fight.adds[#fight.adds+1]=whelp
        end
    end
end

local function phaseFor(fraction)
    for _,phase in ipairs(PHASES) do
        if fraction>phase.untilFraction then return phase end
    end
    return PHASES[#PHASES]
end

local function runFight(boss)
    local humanoid=boss:FindFirstChildOfClass("Humanoid")
    if not humanoid then return end
    local state={ nextSlam=os.clock()+2.5, nextAdds=os.clock()+8, phaseId=0 }
    while active==boss and boss.Parent and humanoid.Health>0 do
        local fraction=humanoid.Health/math.max(1,humanoid.MaxHealth)
        local phase=phaseFor(fraction)
        if phase.id~=state.phaseId then
            state.phaseId=phase.id
            state.nextSlam=os.clock()+1.5
            setPhaseGlow(boss,phase.id)
            if phase.id>=3 then
                boss:SetAttribute("LumiaBossEnraged",true)
                humanoid.DisplayName="Thornbound Guardian [Enraged]"
                print("[Lumia V18] Guardian enraged - final phase")
            elseif phase.id==2 then
                print("[Lumia V18] Guardian phase 2 - whelps incoming")
            else
                print("[Lumia V18] Guardian phase 1 - dodge the rings")
            end
        end
        if phase.addInterval and os.clock()>=state.nextAdds then
            state.nextAdds=os.clock()+phase.addInterval
            spawnWhelps(boss)
        end
        if os.clock()>=state.nextSlam then
            state.nextSlam=os.clock()+phase.slamInterval
            startSlam(boss,phase)
        end
        task.wait(0.2)
    end
end

local function spawnBoss()
    local crowd=nearbyPlayers()
    local count=math.max(1,#crowd)
    local scaling=scalingFor(count)
    local boss=Monsters:SpawnMonster("ThornboundGuardian",anchor.Position,true)
    if not boss then
        nextSpawn=os.clock()+8
        return nil
    end
    boss:SetAttribute("LumiaBossEncounter",true)
    boss:SetAttribute("LumiaDamageScale",scaling.damage)
    pcall(function() boss:ScaleTo(1.45) end)

    local humanoid=boss:FindFirstChildOfClass("Humanoid")
    if humanoid then
        local maxHealth=math.max(1,math.floor(humanoid.MaxHealth*scaling.health))
        humanoid.MaxHealth=maxHealth
        humanoid.Health=maxHealth
        humanoid.DisplayName="Thornbound Guardian"
    end

    local glow=Instance.new("Highlight")
    glow.FillColor=Color3.fromRGB(121,69,140)
    glow.OutlineColor=Color3.fromRGB(238,170,108)
    glow.FillTransparency=0.65
    glow.OutlineTransparency=0.12
    glow.Parent=boss

    active=boss
    fight={ telegraphs={}, adds={} }
    desertedSince=nil
    print(string.format("[Lumia V18] Thornbound Guardian formed for %d player(s) | health x%.2f damage x%.2f",
        count,scaling.health,scaling.damage))
    task.spawn(runFight,boss)
    return boss
end

Life.Died.Event:Connect(function(model,monsterId)
    if monsterId~="ThornboundGuardian" or model~=active then return end
    if model:GetAttribute("LumiaBossEncounter")~=true then return end
    local credited=0
    for _,player in ipairs(Players:GetPlayers()) do
        if (model:GetAttribute("LumiaBossHit_"..player.UserId) or 0)>=1 then
            Quests:Advance(player,"Kill","ThornboundGuardian")
            Achievements:Award(player,"GuardiansOfLumia")
            credited+=1
        end
    end
    if credited>0 then
        print(string.format("[Lumia V18] Guardian defeated by %d player(s)",credited))
    else
        warn("[Lumia V18] Guardian died with no contributor; no rewards granted")
    end
    clearFight()
    active=nil
    nextSpawn=os.clock()+REFORM_DELAY
end)

task.spawn(function()
    while anchor.Parent do
        local crowd=nearbyPlayers()
        if active and not active.Parent then
            clearFight()
            active=nil
            nextSpawn=os.clock()+REFORM_DELAY
        end
        if active then
            if #crowd==0 then
                desertedSince=desertedSince or os.clock()
                if os.clock()-desertedSince>DESERT_GRACE then
                    local abandoned=active
                    clearFight()
                    active=nil
                    if abandoned.Parent then abandoned:Destroy() end
                    nextSpawn=os.clock()+12
                    desertedSince=nil
                    print("[Lumia V18] Guardian dissolved - nobody in the arena")
                end
            else
                desertedSince=nil
            end
        elseif os.clock()>=nextSpawn and #crowd>=1 then
            spawnBoss()
        end
        task.wait(1.5)
    end
end)
