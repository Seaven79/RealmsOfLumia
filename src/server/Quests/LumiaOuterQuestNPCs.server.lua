-- Lumia V17: dedicated quest givers for each outer-zone chapter.
local Workspace=game:GetService("Workspace")
local world=Workspace:WaitForChild("LumiaOpenWorldV15",45)
local forest=Workspace:FindFirstChild("ForgottenForest")
local ground=forest and forest:FindFirstChild("Grassland",true)
if not world or not ground or not ground:IsA("BasePart") then
    warn("[Lumia V17] Outer quest givers skipped: terrain unavailable")
    return
end
local folder=Workspace:WaitForChild("LumiaQuestWorld",35)
if not folder then return end
local half,top=ground.Size.X/2,ground.Size.Y/2
local function create(name,label,localX,color)
    local old=folder:FindFirstChild(name)
    if old then old:Destroy() end
    local model=Instance.new("Model")
    model.Name=name
    model:SetAttribute("LumiaNPCType","QuestGiver")
    model:SetAttribute("LumiaNPCName",label)
    model.Parent=folder
    local base=ground.CFrame*CFrame.new(localX,top,-31)
    local function block(name,size,offset,tint,shape)
        local p=Instance.new("Part")
        p.Name=name;p.Size=size;p.CFrame=base*CFrame.new(offset)
        p.Anchored=true;p.CanCollide=false;p.CanTouch=false;p.CanQuery=true
        p.Material=Enum.Material.SmoothPlastic;p.Color=tint
        if shape then p.Shape=shape end
        p.Parent=model
        return p
    end
    model.PrimaryPart=block("Torso",Vector3.new(2.1,2.6,1.2),Vector3.new(0,3.1,0),color)
    block("Head",Vector3.new(1.2,1.2,1.2),Vector3.new(0,5.0,0),
        Color3.fromRGB(221,185,143),Enum.PartType.Ball)
    for _,side in ipairs({-1,1}) do
        block("Arm",Vector3.new(.62,2.2,.58),Vector3.new(side*1.35,3,0),color)
        block("Leg",Vector3.new(.7,2.0,.7),Vector3.new(side*.54,1,0),
            Color3.fromRGB(71,65,67))
    end
    local gui=Instance.new("BillboardGui")
    gui.Size=UDim2.fromOffset(230,48)
    gui.StudsOffsetWorldSpace=Vector3.new(0,3.15,0)
    gui.MaxDistance=70;gui.Parent=model.PrimaryPart
    local text=Instance.new("TextLabel")
    text.Size=UDim2.fromScale(1,1);text.BackgroundTransparency=1
    text.Font=Enum.Font.GothamSemibold;text.TextSize=17
    text.Text=label.."\nQUESTS"
    text.TextColor3=Color3.fromRGB(252,222,154)
    text.TextStrokeTransparency=.2
    text.Parent=gui
end
create("ThornwatchScout","Lysa the Scout",half+25,Color3.fromRGB(69,116,84))
create("GateWarden","Keeper Arlen",half+125+25,Color3.fromRGB(111,90,145))
print("[Lumia V17] Outer quest NPCs ready")
