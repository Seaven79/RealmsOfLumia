-- Lumia V17: discoverable merchant NPCs in BOTH new open-world zones.
local Workspace = game:GetService("Workspace")
local CollectionService = game:GetService("CollectionService")
local world = Workspace:WaitForChild("LumiaOpenWorldV15", 45)
local forest = Workspace:FindFirstChild("ForgottenForest")
local grass = forest and forest:FindFirstChild("Grassland", true)
if not world or not grass or not grass:IsA("BasePart") then
    warn("[Lumia V17] Regional merchants not placed: missing map")
    return
end
local old = Workspace:FindFirstChild("LumiaRegionMerchants")
if old then old:Destroy() end
local folder = Instance.new("Folder")
folder.Name = "LumiaRegionMerchants"
folder.Parent = Workspace
local half, top = grass.Size.X/2, grass.Size.Y/2
local function part(model,name,sz,cf,color,mat)
    local p=Instance.new("Part")
    p.Name=name;p.Size=sz;p.CFrame=cf;p.Color=color;p.Material=mat
    p.Anchored=true;p.CanCollide=false;p.CanTouch=false;p.CanQuery=true
    p.Parent=model
    return p
end
local function create(id, title, level, localX, localZ)
    local model=Instance.new("Model")
    model.Name=id
    model:SetAttribute("LumiaMerchant",true)
    model:SetAttribute("LumiaMerchantTier",level)
    model:SetAttribute("LumiaMerchantTitle",title)
    model:SetAttribute("LumiaNPCType","Merchant")
    model.Parent=folder
    local cf=grass.CFrame*CFrame.new(localX,top, localZ)
    local torso=part(model,"MerchantTorso",Vector3.new(2.1,2.5,1.15),cf*CFrame.new(0,3.0,0),
        Color3.fromRGB(61+level*14,63,99),Enum.Material.Fabric)
    model.PrimaryPart=torso
    part(model,"MerchantHead",Vector3.new(1.15,1.15,1.15),cf*CFrame.new(0,4.9,0),
        Color3.fromRGB(213,168,126),Enum.Material.SmoothPlastic).Shape=Enum.PartType.Ball
    for _,side in ipairs({-1,1}) do
        part(model,"MerchantArm",Vector3.new(.55,2.1,.65),cf*CFrame.new(side*1.28,2.85,0),
            Color3.fromRGB(69+level*13,60,93),Enum.Material.Fabric)
        part(model,"MerchantLeg",Vector3.new(.68,2,.72),cf*CFrame.new(side*.55,1,0),
            Color3.fromRGB(52,45,53),Enum.Material.Fabric)
    end
    local badge=Instance.new("BillboardGui")
    badge.Name="ShopkeeperLabel";badge.AlwaysOnTop=false;badge.MaxDistance=65
    badge.Size=UDim2.fromOffset(260,58)
    badge.StudsOffsetWorldSpace=Vector3.new(0,3,0)
    badge.Parent=torso
    local label=Instance.new("TextLabel")
    label.Size=UDim2.fromScale(1,1);label.BackgroundTransparency=1
    label.Font=Enum.Font.GothamBold;label.TextSize=15
    label.TextColor3=Color3.fromRGB(249,218,153)
    label.TextStrokeTransparency=.25
    label.Text=title .. "\nLevel " .. level .. " equipment"
    label.Parent=badge
    CollectionService:AddTag(model,"LumiaMerchant")
end
create("OldRoadOutfitter","Orin the Outfitter",2,36,55)
create("CreekBendTrader","Nessa of the Creek",3,-12,-60)
create("ThornwatchQuartermaster","Bram the Quartermaster",4,half+22,-43)
create("GateArmorer","Serin the Armorer",5,half+125+22,-43)
print("[Lumia V17] Regional merchants spawned")
