-- REALMS OF LUMIA V19: REGIONAL WILDLIFE
-- Six managed mobs total, only active near players. More dangerous in later biomes.
-- Uses the existing MonsterService, combat, AI, loot, global curve and XP logic.
local Players=game:GetService("Players")
local Workspace=game:GetService("Workspace")
local MonsterService=require(script.Parent:WaitForChild("MonsterService"))
local SpawnSafety=require(script.Parent:WaitForChild("SpawnSafety"))
local PlayerPositions = require(game:GetService("ReplicatedStorage"):WaitForChild("Lumia"):WaitForChild("Shared"):WaitForChild("Players"):WaitForChild("PlayerPositions"))
local forest=Workspace:WaitForChild("ForgottenForest",30)
local grass=forest and forest:FindFirstChild("Grassland",true)
if not grass or not grass:IsA("BasePart") then
    warn("[Lumia V19] Regional wildlife skipped: no Grassland")
    return
end
local definitions={
    {id="Road_A",type="OldRoadStalker",x=24,z=67},
    {id="Road_B",type="OldRoadStalker",x=85,z=73},
    {id="Creek_A",type="CreekFenWolf",x=-57,z=-83},
    {id="Creek_B",type="CreekFenWolf",x=21,z=-88},
    {id="Ruins_A",type="StoneboundWolf",x=38,z=-46},
    {id="Ruins_B",type="StoneboundWolf",x=99,z=-29},
}
local points={}
local function nearPlayers(position,radius)
    for _,player in ipairs(Players:GetPlayers()) do
        local character=player.Character
        local root=character and character:FindFirstChild("HumanoidRootPart")
        local hum=character and character:FindFirstChildOfClass("Humanoid")
        if root and hum and hum.Health>0 and (root.Position-position).Magnitude<=radius then
            return true
        end
    end
    return false
end
local function findAnchor(dx,dz)
    local localXZ=grass.CFrame:PointToObjectSpace(grass.Position+Vector3.new(dx,0,dz))
    if math.abs(localXZ.X)>grass.Size.X/2-5
        or math.abs(localXZ.Z)>grass.Size.Z/2-5 then return nil end
    local center=grass.Position+Vector3.new(dx,grass.Size.Y/2+3.5,dz)
    return SpawnSafety.FindSafeNear(center,points)
end
local t=0
for _,def in ipairs(definitions) do
    local position=findAnchor(def.x,def.z)
    if position then
        local point={id=def.id,monsterId=def.type,position=position,model=nil,nextSpawn=0}
        table.insert(points,point)
    else
        warn("[Lumia V19] Skipping unsafe regional spawn: "..def.id)
    end
end
local function tint(model,monsterId)
    local colors={OldRoadStalker=Color3.fromRGB(167,133,94),
        CreekFenWolf=Color3.fromRGB(101,159,170),
        StoneboundWolf=Color3.fromRGB(171,148,188)}
    local color=colors[monsterId]
    if not color then return end
    for _,part in ipairs(model:GetDescendants()) do
        if part:IsA("BasePart") and part.Name~="HumanoidRootPart" then
            part.Color=part.Color:Lerp(color,0.40)
        end
    end
    model:SetAttribute("LumiaBiomeVariant",monsterId)
end
while grass.Parent and script.Parent do
    local now=os.clock()
    for _,point in ipairs(points) do
        if point.model and not point.model.Parent then
            point.model=nil
            point.nextSpawn=now+24
        end
        if point.model and point.model.Parent and point.model:GetAttribute("InCombat")~=true
            and not nearPlayers(point.position,165) then
            point.model:Destroy()
            point.model=nil
            point.nextSpawn=now+12
        end
        if not point.model and now>=point.nextSpawn and nearPlayers(point.position,95) then
            local safe=SpawnSafety.FindSafeNear(point.position,points,point.id)
            if safe then
                local ok,model=pcall(MonsterService.SpawnMonster,MonsterService,point.monsterId,safe,true)
                if ok and model then
                    point.model=model
                    tint(model,point.monsterId)
                else point.nextSpawn=now+10 end
            else point.nextSpawn=now+7 end
        end
    end
    task.wait(2.5)
end
