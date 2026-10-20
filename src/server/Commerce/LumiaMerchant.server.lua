-- Realms of Lumia merchant v1: shopkeeper and interior props created in Play mode.
-- No changes to Studio-saved house. Add an anchored invisible Part called
-- LumiaMerchantAnchor INSIDE the house for precise placement when desired.
local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local Workspace=game:GetService("Workspace")
local CollectionService=game:GetService("CollectionService")
local server=script.Parent.Parent
local inv=require(server:WaitForChild("Inventory"):WaitForChild("InventoryService"))
local data=require(server:WaitForChild("Players"):WaitForChild("PlayerDataService"))
local snapshot=require(server:WaitForChild("Inventory"):WaitForChild("BagSnapshot"))
local shared=ReplicatedStorage:WaitForChild("Lumia"):WaitForChild("Shared")
local items=require(shared:WaitForChild("Items"):WaitForChild("ItemDefinitions"))
local cfg=require(shared:WaitForChild("Commerce"):WaitForChild("MerchantConfig"))
local currency=require(shared:WaitForChild("Commerce"):WaitForChild("LumiaCurrency"))
local net=ReplicatedStorage.Lumia:FindFirstChild("CommerceNetwork") or Instance.new("Folder")
net.Name="CommerceNetwork";net.Parent=ReplicatedStorage.Lumia
local function remote(name)
    local r=net:FindFirstChild(name) or Instance.new("RemoteFunction")
    r.Name=name;r.Parent=net;assert(r:IsA("RemoteFunction"));return r
end
local open=remote("OpenMerchant")
local action=remote("MerchantAction")
local folder=Instance.new("Folder");folder.Name="LumiaMerchantScene";folder.Parent=Workspace
local merchant=nil
local last={}
local function decor(name,size,color,material,cf,parent)
    local p=Instance.new("Part");p.Name=name;p.Size=size;p.Anchored=true
    p.Material=material;p.Color=color;p.TopSurface=Enum.SurfaceType.Smooth
    p.BottomSurface=Enum.SurfaceType.Smooth;p.CFrame=cf;p.Parent=parent
    return p
end
local function place()
    -- Analyze the actual DEV Pre-Alpha building: Floor 20x18 centered (25,0.5,5), front at z=-4.
    -- This is parametric relative to the floor so rebuilding the world doesn't re-bury the NPC.
    local forest=Workspace:FindFirstChild("ForgottenForest") or Workspace:WaitForChild("ForgottenForest",20)
    local house=forest and forest:FindFirstChild("House",true)
    local floor=house and house:FindFirstChild("Cabin Floor")
    if not (floor and floor:IsA("BasePart") and floor.Size.X>=18 and floor.Size.Z>=16) then
        warn("[Lumia - Merchant] Shop requires the House/Cabin Floor from your DEV place; leaving the scene untouched")
        return
    end
    local origin=floor.CFrame*CFrame.new(0,floor.Size.Y/2,0)
    local function cf(x,y,z) return origin*CFrame.new(x,y,z) end
    local function piece(name,size,color,mat,x,y,z,solid)
        local p=decor(name,size,color,mat,cf(x,y,z),folder)
        p.CanCollide=solid==true;p.CanTouch=false
        return p
    end
    local wood=Color3.fromRGB(104,67,39)
    local oak=Color3.fromRGB(162,111,61)
    local deep=Color3.fromRGB(54,38,32)
    local brass=Color3.fromRGB(191,141,72)
    local pale=Color3.fromRGB(233,198,131)
    local rock=Color3.fromRGB(95,87,77)
    local function lamp(name,x,y,z,brightness,range)
        local mount=piece(name.."Backplate",Vector3.new(.7,1,.28),deep,Enum.Material.Metal,x,y,z-.18,false)
        local glass=piece(name.."Glow",Vector3.new(.48,.7,.48),Color3.fromRGB(255,200,112),Enum.Material.Glass,x,y,z,false)
        glass.Transparency=.16
        piece(name.."Base",Vector3.new(.7,.18,.7),brass,Enum.Material.Metal,x,y-.39,z,false)
        piece(name.."Cap",Vector3.new(.7,.16,.7),brass,Enum.Material.Metal,x,y+.40,z,false)
        local light=Instance.new("PointLight")
        light.Name="WarmShopLight";light.Color=Color3.fromRGB(255,196,117)
        light.Brightness=brightness;light.Range=range;light.Shadows=false;light.Parent=glass
    end
    -- Facade of the original house: retain the roof, side walls and walkable floor.
    -- Two solid front wall panels are replaced by wooden window surrounds with translucent panes.
    for _,name in ipairs({"Cabin Front Left","Cabin Front Right"}) do
        local existing=house:FindFirstChild(name)
        if existing and existing:IsA("BasePart") then
            existing.Transparency=1;existing.CanCollide=false;existing.CastShadow=false
        end
    end
    for _,x in ipairs({-6,6}) do
        piece("PlankBelowWindow",Vector3.new(8,4.1,1),wood,Enum.Material.WoodPlanks,x,2.05,-9,true)
        piece("PlankAboveWindow",Vector3.new(8,4.1,1),wood,Enum.Material.WoodPlanks,x,9.95,-9,true)
        for _,side in ipairs({-1,1}) do
            piece("WindowSideFrame",Vector3.new(1.55,3.8,1),wood,Enum.Material.WoodPlanks,x+side*3.225,6,-9,true)
        end
        local glass=piece("AmberGlassWindow",Vector3.new(4.8,3.8,.27),Color3.fromRGB(133,180,191),Enum.Material.Glass,x,6,-9.48,true)
        glass.Transparency=.38
        for _,dx in ipairs({-2.5,0,2.5}) do
            piece("WindowMullion",Vector3.new(.20,4.0,.35),deep,Enum.Material.Wood,x+dx,6,-9.71,false)
        end
        piece("WindowSill",Vector3.new(5.4,.28,.65),oak,Enum.Material.Wood,x,4.03,-9.57,false)
        piece("WindowHeader",Vector3.new(5.4,.3,.6),oak,Enum.Material.Wood,x,7.94,-9.57,false)
    end
    -- Oak corner posts, rich fascia and roof trim; the doorway stays open.
    for _,x in ipairs({-9.5,9.5}) do
        piece("StorefrontPost",Vector3.new(.65,12.3,.85),oak,Enum.Material.Wood,x,6.16,-9.18,false)
        lamp("EntranceLantern"..x,x*.87,7.6,-10.1,.82,14)
    end
    piece("DoorLeftCarving",Vector3.new(.5,8.5,1),oak,Enum.Material.Wood,-2.25,4.25,-9.3,false)
    piece("DoorRightCarving",Vector3.new(.5,8.5,1),oak,Enum.Material.Wood,2.25,4.25,-9.3,false)
    piece("DoorLintel",Vector3.new(5.3,.6,.9),oak,Enum.Material.Wood,0,8.58,-9.25,false)
    piece("RoofEaveTrim",Vector3.new(21,.55,1.3),deep,Enum.Material.Wood,0,12.55,-10.2,false)
    piece("BrassEaveTrim",Vector3.new(21,.14,1.35),brass,Enum.Material.Metal,0,12.24,-10.2,false)
    local shopSign=piece("TheHearthAndHollowSign",Vector3.new(12,2.1,.45),deep,Enum.Material.Wood,0,10.9,-10.14,false)
    local signGui=Instance.new("SurfaceGui")
    signGui.Name="LumiaShopSign";signGui.Face=Enum.NormalId.Front
    signGui.PixelsPerStud=55;signGui.SizingMode=Enum.SurfaceGuiSizingMode.PixelsPerStud
    signGui.LightInfluence=0;signGui.Parent=shopSign
    local signLabel=Instance.new("TextLabel")
    signLabel.Size=UDim2.fromScale(1,1);signLabel.BackgroundTransparency=1
    signLabel.Text="THE HEARTH & HOLLOW\nTRAVELERS' SUPPLIES"
    signLabel.TextScaled=true;signLabel.Font=Enum.Font.GothamBold
    signLabel.TextColor3=pale;signLabel.TextStrokeTransparency=.25;signLabel.Parent=signGui
    for _,x in ipairs({-6.5,6.5}) do
        piece("SignRivet",Vector3.new(.18,.18,.16),brass,Enum.Material.Metal,x*.83,10.9,-10.45,false)
    end
    -- Warm interior: dark wood counter along the back half, clear entrance walkway.
    piece("WelcomeRunner",Vector3.new(3.5,.06,10),Color3.fromRGB(93,31,40),Enum.Material.Fabric,0,.09,-2,false)
    piece("RunnerBorder",Vector3.new(3.9,.04,10.4),brass,Enum.Material.Fabric,0,.07,-2,false)
    piece("RunnerCore",Vector3.new(3.4,.07,9.7),Color3.fromRGB(107,43,49),Enum.Material.Fabric,0,.12,-2,false)
    piece("CounterBody",Vector3.new(12,2.9,2.2),wood,Enum.Material.WoodPlanks,0,1.45,3.6,true)
    piece("CounterTop",Vector3.new(12.7,.28,2.9),oak,Enum.Material.Wood,0,3.08,3.6,true)
    piece("CounterBrassLip",Vector3.new(12.7,.14,.12),brass,Enum.Material.Metal,0,2.92,2.1,false)
    for _,x in ipairs({-5.8,5.8}) do
        piece("CounterCarvedPillar",Vector3.new(.48,3.02,.42),deep,Enum.Material.Wood,x,1.55,2.44,false)
    end
    -- Side fixtures and a back wall of stocked shelves.
    local function shelves(side,z)
        local x=side*7.35
        for _,yy in ipairs({1.35,3.5,5.65}) do
            piece("ShopWallShelf",Vector3.new(2.7,.25,4.4),oak,Enum.Material.Wood,x,yy,z,true)
        end
        for _,zz in ipairs({z-1.9,z+1.9}) do
            piece("ShelfSupport",Vector3.new(.25,5.9,.3),deep,Enum.Material.Wood,x,3.0,zz,false)
        end
        for j=1,4 do
            local dx=(j%2==0) and .65 or -.55
            local bottle=piece("MerchantPotionBottle",Vector3.new(.45,.8,.4),j%2==0 and Color3.fromRGB(88,169,132) or Color3.fromRGB(129,105,168),Enum.Material.Glass,x+dx,3.97,z-1.65+j*.75,false)
            bottle.Transparency=.17
            piece("PotionCork",Vector3.new(.22,.2,.22),deep,Enum.Material.Wood,x+dx,4.48,z-1.65+j*.75,false)
        end
    end
    shelves(-1,-1.6);shelves(1,-1.6)
    for _,x in ipairs({-7.4,7.4}) do
        for _,z in ipairs({5.8,7.2}) do
            piece("BackStockCrate",Vector3.new(1.55,1.4,1.3),Color3.fromRGB(99,72,46),Enum.Material.WoodPlanks,x,.72,z,true)
        end
    end
    -- Back shelf for relics, books, swords and candles.
    for _,h in ipairs({1.4,3.8,6.4}) do
        piece("BackDisplayShelf",Vector3.new(13.5,.28,1.1),oak,Enum.Material.Wood,0,h,7.85,true)
    end
    for j=-4,4 do
        local x=j*1.27
        if j%3==0 then
            piece("BookStack",Vector3.new(.9,1.1,.6),Color3.fromRGB(82,74,113),Enum.Material.Fabric,x,4.48,7.8,false)
            piece("BookSpineGold",Vector3.new(.09,1.14,.65),brass,Enum.Material.Metal,x+.4,4.48,7.8,false)
        else
            local jar=piece("StockGlassJar",Vector3.new(.62,.72,.58),Color3.fromRGB(106,150,126),Enum.Material.Glass,x,4.32,7.75,false)
            jar.Transparency=.28
        end
    end
    -- Ambient lighting: small number of non-shadowed point lights.
    for _,x in ipairs({-5.5,5.5}) do lamp("InteriorSconce"..x,x,6.3,7.25,1.05,13) end
    lamp("CounterWorkLamp",-4.8,3.95,3.6,.75,9)
    lamp("CounterWorkLamp2",4.8,3.95,3.6,.75,9)
    piece("CoinTray",Vector3.new(1.5,.17,.9),brass,Enum.Material.Metal,3.6,3.32,3.6,false)
    piece("ShopLedger",Vector3.new(1.4,.11,.9),Color3.fromRGB(75,54,45),Enum.Material.Fabric,-3.2,3.32,3.6,false)
    -- Stationary NPC. Position from the ACTUAL floor surface, not the roof-inclusive bounding box.
    local npcBase=cf(0,0,6.15)
    local anchor=Workspace:FindFirstChild("LumiaMerchantAnchor",true)
    if anchor and anchor:IsA("BasePart") then npcBase=anchor.CFrame end
    local ok,rig=pcall(function()
        local desc=Instance.new("HumanoidDescription")
        return Players:CreateHumanoidModelFromDescription(desc,Enum.HumanoidRigType.R15)
    end)
    if ok and rig then
        merchant=rig;merchant.Name="MiraTheTrader";merchant.Parent=folder
        merchant:PivotTo(npcBase*CFrame.new(0,3.0,0))
        local _,sz=merchant:GetBoundingBox()
        local bbCF=select(1,merchant:GetBoundingBox())
        local feet=bbCF.Position.Y-sz.Y/2
        local targetFeet=(anchor and anchor:IsA("BasePart")) and anchor.Position.Y or origin.Position.Y+.06
        merchant:PivotTo(merchant:GetPivot()+Vector3.new(0,targetFeet-feet,0))
        local humanoid=merchant:FindFirstChildOfClass("Humanoid")
        if humanoid then humanoid.DisplayDistanceType=Enum.HumanoidDisplayDistanceType.None end
        for _,part in ipairs(merchant:GetDescendants()) do
            if part:IsA("BasePart") then part.Anchored=true;part.CanTouch=false end
        end
        local colors=merchant:FindFirstChildOfClass("BodyColors") or Instance.new("BodyColors")
        colors.HeadColor3=Color3.fromRGB(232,186,143)
        colors.LeftArmColor3=Color3.fromRGB(107,69,116)
        colors.RightArmColor3=colors.LeftArmColor3
        colors.TorsoColor3=Color3.fromRGB(96,54,103)
        colors.LeftLegColor3=Color3.fromRGB(59,46,64)
        colors.RightLegColor3=colors.LeftLegColor3
        colors.Parent=merchant
    else
        merchant=Instance.new("Model")
        merchant.Name="MiraTheTrader";merchant.Parent=folder
        local root=decor("Root",Vector3.new(2,3,1),Color3.fromRGB(107,62,96),Enum.Material.Fabric,npcBase*CFrame.new(0,2.15,0),merchant)
        root.CanCollide=false;merchant.PrimaryPart=root
        decor("Head",Vector3.new(1.2,1.2,1.2),Color3.fromRGB(221,170,125),Enum.Material.SmoothPlastic,npcBase*CFrame.new(0,4.4,0),merchant)
    end
    merchant:SetAttribute("LumiaMerchant",true)
    merchant:SetAttribute("LumiaMerchantTitle","Mira the Trader")
    merchant:SetAttribute("LumiaNPCType","Merchant")
    CollectionService:AddTag(merchant,"LumiaMerchant")
    local head=merchant:FindFirstChild("Head") or merchant.PrimaryPart
    if head then
        local billboard=Instance.new("BillboardGui")
        billboard.Name="MerchantName";billboard.Adornee=head
        billboard.Size=UDim2.fromOffset(200,40)
        billboard.StudsOffsetWorldSpace=Vector3.new(0,1.85,0)
        billboard.MaxDistance=50;billboard.Parent=head
        local label=Instance.new("TextLabel")
        label.Size=UDim2.fromScale(1,1);label.BackgroundTransparency=1
        label.Text="Mira the Trader";label.Font=Enum.Font.GothamBold;label.TextSize=16
        label.TextColor3=Color3.fromRGB(244,205,124)
        label.TextStrokeTransparency=.08;label.Parent=billboard
    end
    print("[Lumia - Merchant] Hearth & Hollow shop ready; Mira feet aligned to Cabin Floor")
end

task.spawn(place)
-- Network bridge only. MerchantTradeService owns validated business logic and
-- supports future merchants with different catalog modules/placement resolvers.
local TradeService=require(script.Parent:WaitForChild("MerchantTradeService"))
local OwnerUserId=require(script.Parent.Parent:WaitForChild("Admin"):WaitForChild("BalanceSettings")).OwnerUserId
local trades=TradeService.new({Merchant=function() return merchant end,Config=cfg})
local GearCatalog=require(shared:WaitForChild("Commerce"):WaitForChild("GearCatalog"))
local activeTrade=setmetatable({}, {__mode="k"})
local regionalTrades=setmetatable({}, {__mode="k"})
local function nearestTrade(player)
    local c=player.Character
    local root=c and c:FindFirstChild("HumanoidRootPart")
    if not root then return nil, nil end
    local nearest, distance = nil, 16
    if merchant and merchant.Parent then
        local d=(merchant:GetPivot().Position-root.Position).Magnitude
        if d <= distance then nearest=trades; distance=d end
    end
    -- A gear merchant the player is standing at but is not high enough level for.
    -- Reported separately so the shop can say WHY instead of "come closer".
    local blockedLevel=nil
    local folder=Workspace:FindFirstChild("LumiaRegionMerchants")
    if folder then
        for _,npc in ipairs(folder:GetChildren()) do
            if npc:IsA("Model") and npc:GetAttribute("LumiaMerchant") then
                local level=npc:GetAttribute("LumiaMerchantTier")
                local profile=data:GetProfile(player)
                local playerLevel=profile and profile.Character.Level or 1
                local inRange=(npc:GetPivot().Position-root.Position).Magnitude<=distance
                -- The owner can trade at any tier: this is a development build and
                -- tuning gear tiers requires reaching a deliberately gated shop.
                local allowed=(type(level)~="number") or (playerLevel>=level) or (player.UserId==OwnerUserId)
                if inRange and not allowed then
                    if not blockedLevel or level<blockedLevel then blockedLevel=level end
                elseif inRange then
                    if not regionalTrades[npc] then
                        local names={[2]="Orin the Outfitter",[3]="Nessa of the Creek",
                            [4]="Bram the Quartermaster",[5]="Serin the Armorer"}
                        local merchantCfg={MerchantName=names[level] or "Regional Merchant",
                            InteractionRange=16,MaxGold=2000000000}
                        function merchantCfg.GetStock()
                            local stock=GearCatalog.GetStock(level)
                            table.insert(stock,{ItemId="FieldPotion", Price=12})
                            return stock
                        end
                        regionalTrades[npc]=TradeService.new({Merchant=function() return npc end,Config=merchantCfg})
                    end
                    nearest=regionalTrades[npc]
                    distance=(npc:GetPivot().Position-root.Position).Magnitude
                end
            end
        end
    end
    return nearest, blockedLevel
end
local function openFor(player)
    local selected,blockedLevel=nearestTrade(player)
    if not selected then
        if blockedLevel then
            local profile=data:GetProfile(player)
            local playerLevel=profile and profile.Character.Level or 1
            return {Ok=false,Message=string.format(
                "This merchant sells level %d gear - you are level %d",
                blockedLevel,playerLevel)}
        end
        -- Silent: the client always asks now, so "nothing nearby" must not pop a
        -- message every time the player presses interact for another reason.
        return {Ok=false,Silent=true,Message="Come closer to the merchant"}
    end
    local response=selected:Open(player)
    if response and response.Ok then activeTrade[player]=selected end
    return response
end
open.OnServerInvoke=function(player) return openFor(player) end

-- Server-driven interaction. ProximityPrompt does not depend on mouse.Target, on
-- ContextActionService priority, or on the player's interact keybind, so a shop
-- can never silently fail to open because a cursor raycast missed the NPC.
local opened=net:FindFirstChild("MerchantOpened")
if not opened then
    opened=Instance.new("RemoteEvent")
    opened.Name="MerchantOpened"
    opened.Parent=net
end

local function attachPrompt(model)
    if not model or not model:IsA("Model") then return end
    if model:GetAttribute("LumiaTradePromptReady") then return end
    local host=model.PrimaryPart or model:FindFirstChild("HumanoidRootPart")
    if not host then return end
    model:SetAttribute("LumiaTradePromptReady",true)

    local prompt=Instance.new("ProximityPrompt")
    prompt.Name="LumiaTradePrompt"
    prompt.ActionText="Trade"
    prompt.ObjectText=model:GetAttribute("LumiaMerchantTitle") or model.Name
    prompt.KeyboardKeyCode=Enum.KeyCode.E
    prompt.GamepadKeyCode=Enum.KeyCode.ButtonX
    prompt.MaxActivationDistance=12
    prompt.HoldDuration=0
    prompt.RequiresLineOfSight=false
    prompt.Parent=host

    prompt.Triggered:Connect(function(player)
        local reply=openFor(player)
        if not reply then return end
        if reply.Ok then
            opened:FireClient(player,reply)
        elseif not reply.Silent then
            opened:FireClient(player,{Ok=false,Message=reply.Message})
        end
    end)
end

-- Attach to Mira and to every regional merchant, including ones spawned later.
task.spawn(function()
    local seen=setmetatable({},{__mode="k"})
    while true do
        local scene=Workspace:FindFirstChild("LumiaMerchantScene")
        local regional=Workspace:FindFirstChild("LumiaRegionMerchants")
        for _,container in ipairs({scene,regional}) do
            if container then
                for _,model in ipairs(container:GetChildren()) do
                    if model:IsA("Model") and model:GetAttribute("LumiaMerchant")
                        and not seen[model] then
                        seen[model]=true
                        attachPrompt(model)
                    end
                end
            end
        end
        task.wait(2)
    end
end)
action.OnServerInvoke=function(player,verb,itemId,bagId,bagSlot,instanceId)
    local selected=activeTrade[player]
    if verb=="UsePotion" then return trades:Perform(player,verb,itemId,bagId,bagSlot,instanceId) end
    if not selected or not selected:Within(player) then
        activeTrade[player]=nil
        return {Ok=false,Message="Move closer and reopen the shop"}
    end
    return selected:Perform(player,verb,itemId,bagId,bagSlot,instanceId)
end
Players.PlayerRemoving:Connect(function(player) activeTrade[player]=nil end)
