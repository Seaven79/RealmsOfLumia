-- REALMS OF LUMIA / 2D WORLD MINIMAP v6
-- Entirely client-side projection of actual replicated forest parts.
-- No invented quest areas, no quest GPS, no extra player rings.
local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local player=Players.LocalPlayer
local playerGui=player:WaitForChild("PlayerGui")
local existing=playerGui:FindFirstChild("LumiaMiniMap")
if existing then existing:Destroy() end
local gui=Instance.new("ScreenGui")
gui.Name="LumiaMiniMap"
gui.ResetOnSpawn=false
-- Keep below dialog overlays, but above core HUD.
gui.DisplayOrder=20
-- Roblox controls the safe inset, preserving the top-right edge.
gui.IgnoreGuiInset=false
 gui.Parent=playerGui
local function create(class,parent,properties)
    local obj=Instance.new(class)
    for name,value in pairs(properties) do obj[name]=value end
    obj.Parent=parent
    return obj
end
local diameter=196
local radius=diameter/2
local holder=create("Frame",gui,{
    Name="RoundWorldMap",AnchorPoint=Vector2.new(1,0),
    Position=UDim2.new(1,-9,0,1),Size=UDim2.fromOffset(200,200),
    BackgroundTransparency=1,BorderSizePixel=0,
})
local disc=create("Frame",holder,{
    Name="FlatWorld",Position=UDim2.fromOffset(2,2),
    Size=UDim2.fromOffset(diameter,diameter),
    BackgroundColor3=Color3.fromRGB(93,130,77),
    ClipsDescendants=true,BorderSizePixel=0,
})
create("UICorner",disc,{CornerRadius=UDim.new(1,0)})
create("UIStroke",disc,{Color=Color3.fromRGB(191,146,80),Thickness=2})
-- All drawn objects use actual world X/Z positions, size and approximate footprint.
local palette={
    Tree=Color3.fromRGB(36,83,43),
    Path=Color3.fromRGB(178,157,114),
    Building=Color3.fromRGB(136,98,68),
    Water=Color3.fromRGB(55,119,155),
    Rock=Color3.fromRGB(132,139,125),
}
local drawOrder={Water=2,Path=3,Building=4,Rock=5,Tree=6}
local features={}
local NPCDots={}
local worldRadius=143 -- studs from center to edge
local forest=workspace:FindFirstChild("ForgottenForest") or workspace:WaitForChild("ForgottenForest",15)
local function kindFor(part)
    if not part:IsA("BasePart") or not part.Anchored or part.Transparency>0.95 then return nil end
    if part.Size.X>450 or part.Size.Z>450 then return nil end
    local name=part.Name:lower()
    local ancestor=part.Parent
    for _=1,5 do
        if ancestor and ancestor.Name then name=name.." "..ancestor.Name:lower(); ancestor=ancestor.Parent end
    end
    if name:find("grassland") or name:find("spawn") or name:find("invisible") or name:find("marker") then return nil end
    if name:find("water") or name:find("creek") or name:find("river") or name:find("pond") then return "Water" end
    if name:find("path") or name:find("road") or name:find("step") or name:find("bridge") or name:find("walkway") then return "Path" end
    if name:find("house") or name:find("building") or name:find("roof") or name:find("cabin") then return "Building" end
    if name:find("tree") or name:find("trunk") or name:find("foliage") or name:find("canopy") or name:find("pine") then return "Tree" end
    if name:find("rock") or name:find("stone") or name:find("boulder") then return "Rock" end
    -- Conservative fallback for unnamed wooden tree trunks/canopies.
    if part.Material==Enum.Material.Wood and part.Size.Y>part.Size.X*1.9
        and part.Size.Y>part.Size.Z*1.9 and part.Size.Y>4 then return "Tree" end
    if part.Material==Enum.Material.Slate and part.Size.Y<2 and part.Size.X>3 and part.Size.Z>3 then return "Path" end
    return nil
end
local function featureKey(part,kind)
    local model=part:FindFirstAncestorOfClass("Model")
    if kind=="Tree" and model and model.Name:lower():find("tree") then return model end
    if kind=="Building" and model and model.Name:lower():find("house") then return model end
    return part
end
local function featurePosition(key,part,kind)
    if key:IsA("Model") and key.PrimaryPart then return key.PrimaryPart.Position end
    if key:IsA("Model") and kind=="Building" then
        local cf=key:GetBoundingBox()
        return cf.Position
    end
    return part.Position
end
local function featureSize(key,part,kind)
    if key:IsA("Model") then
        local _,size=key:GetBoundingBox()
        return size
    end
    return part.Size
end
local limits={Tree=95,Rock=60,Path=85,Building=24,Water=16}
local function buildMap()
    for _,entry in ipairs(features) do entry.ui:Destroy() end
    table.clear(features)
    if not forest then return end
    local seen={}
    local count={Tree=0,Rock=0,Path=0,Building=0,Water=0}
    -- Sort by type so roads paint below buildings, which paint below trees.
    local collected={}
    for _,part in ipairs(forest:GetDescendants()) do
        local kind=kindFor(part)
        if kind and count[kind]<limits[kind] then
            local key=featureKey(part,kind)
            if not seen[key] then
                seen[key]=true
                count[kind]+=1
                table.insert(collected,{key=key,part=part,kind=kind})
            end
        end
    end
    table.sort(collected,function(a,b) return drawOrder[a.kind]<drawOrder[b.kind] end)
    for _,item in ipairs(collected) do
        local kind=item.kind
        local shape=create("Frame",disc,{
            Name="World"..kind,AnchorPoint=Vector2.new(0.5,0.5),
            BackgroundColor3=palette[kind],BorderSizePixel=0,
            Visible=false,ZIndex=drawOrder[kind],
        })
        if kind=="Tree" or kind=="Rock" then
            create("UICorner",shape,{CornerRadius=UDim.new(1,0)})
        elseif kind=="Path" then
            shape.BackgroundTransparency=0.08
        end
        item.ui=shape
        table.insert(features,item)
    end
end
local arrow=create("TextLabel",disc,{
    Name="YourPosition",Size=UDim2.fromOffset(21,22),
    AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromOffset(radius,radius),
    Text="▲",Font=Enum.Font.GothamBlack,TextSize=21,
    TextColor3=Color3.fromRGB(218,250,255),BackgroundTransparency=1,
    TextStrokeColor3=Color3.fromRGB(8,23,28),TextStrokeTransparency=0.05,ZIndex=18,
})
local function getNPCDot(npc)
    if NPCDots[npc] then return NPCDots[npc] end
    local dot=create("Frame",disc,{
        Name="NPC",AnchorPoint=Vector2.new(0.5,0.5),
        Size=UDim2.fromOffset(7,7),BorderSizePixel=0,
        BackgroundColor3=Color3.fromRGB(252,213,126),ZIndex=13,Visible=false,
    })
    create("UICorner",dot,{CornerRadius=UDim.new(1,0)})
    create("UIStroke",dot,{Color=Color3.fromRGB(38,31,21),Thickness=1})
    NPCDots[npc]=dot
    return dot
end
local function coords(worldPosition,origin)
    local u=radius+(worldPosition.X-origin.X)/worldRadius*radius
    local v=radius+(worldPosition.Z-origin.Z)/worldRadius*radius
    local dx=u-radius
    local dy=v-radius
    return u,v,dx*dx+dy*dy<(radius-5)^2
end
local function update()
    local char=player.Character
    local root=char and char:FindFirstChild("HumanoidRootPart")
    arrow.Visible=root~=nil
    if not root then return end
    local origin=root.Position
    arrow.Rotation=math.deg(math.atan2(root.CFrame.LookVector.X,-root.CFrame.LookVector.Z))
    for _,item in ipairs(features) do
        local graphic=item.ui
        local part=item.part
        if not part.Parent or not item.key.Parent then graphic.Visible=false;continue end
        local u,v,visible=coords(featurePosition(item.key,part,item.kind),origin)
        graphic.Visible=visible
        if visible then
            graphic.Position=UDim2.fromOffset(u,v)
            local sz=featureSize(item.key,part,item.kind)
            local sx=math.clamp(sz.X/worldRadius*radius,3,63)
            local sy=math.clamp(sz.Z/worldRadius*radius,3,63)
            if item.kind=="Tree" then
                local n=math.clamp(math.max(sx,sy),7,18)
                graphic.Size=UDim2.fromOffset(n,n)
                graphic.Rotation=0
            elseif item.kind=="Rock" then
                graphic.Size=UDim2.fromOffset(math.clamp(sx,4,13),math.clamp(sy,4,13))
            else
                graphic.Size=UDim2.fromOffset(math.max(4,sx),math.max(4,sy))
                local _,yaw,_=part.CFrame:ToEulerAnglesYXZ()
                graphic.Rotation=-math.deg(yaw)
            end
        end
    end
    local questWorld=workspace:FindFirstChild("LumiaQuestWorld")
    for npc,dot in pairs(NPCDots) do
        dot.Visible=false
        if not npc.Parent then dot:Destroy();NPCDots[npc]=nil end
    end
    local npcWorlds={}
    if questWorld then table.insert(npcWorlds,questWorld) end
    local shopScene=workspace:FindFirstChild("LumiaMerchantScene")
    if shopScene then table.insert(npcWorlds,shopScene) end
    for _,npcWorld in ipairs(npcWorlds) do
        if npcWorld then for _,npc in ipairs(npcWorld:GetChildren()) do
            if npc:IsA("Model") and npc:GetAttribute("LumiaNPCType") then
                local npcRoot=npc:FindFirstChild("HumanoidRootPart") or npc.PrimaryPart
                if npcRoot then
                    local u,v,visible=coords(npcRoot.Position,origin)
                    local dot=getNPCDot(npc)
                    dot.Visible=visible
                    if visible then dot.Position=UDim2.fromOffset(u,v) end
                end
            end
        end end
    end
end
buildMap()
local elapsed=0
RunService.Heartbeat:Connect(function(dt)
    elapsed+=dt
    if elapsed<1/15 then return end
    elapsed=0
    update()
end)
-- Rebuild snapshots for additions/streaming; never invent quest locations.
task.spawn(function()
    while gui.Parent do
        task.wait(12)
        buildMap()
    end
end)
update()
print("[Lumia - Minimap] v6: flat map of real world geometry and NPC dots")
