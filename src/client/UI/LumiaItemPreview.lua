-- 3D item icon renderer for viewport inventory slots. No external asset IDs.
-- Only constructs tiny, noninteractive client models inside a ViewportFrame.
local Preview={}
local models={WolfTornFur="fur",WolfBrokenFang="fang",WolfMattedHide="hide",
    WolfDullClaw="claw",WolfRunestone="rune",FieldPotion="potion",ForgedSword="sword"}
local function part(parent,shape,size,color,cf)
    local p=Instance.new("Part")
    p.Shape=shape; p.Size=size; p.Color=color; p.Material=Enum.Material.SmoothPlastic
    p.Anchored=true; p.CanCollide=false; p.CanQuery=false; p.CFrame=cf; p.Parent=parent
    return p
end
function Preview.Attach(slot,itemId)
    local style=models[itemId]
    local tier, gearType
    if type(itemId)=="string" then tier, gearType=itemId:match("^Lumia([1-5])(.+)$") end
    if tier and gearType then
        if gearType=="Sword" then style="sword"
        elseif gearType=="Hood" then style="hood"
        elseif gearType=="Vest" then style="vest"
        elseif gearType=="Gloves" then style="gloves"
        elseif gearType=="Leggings" then style="leggings"
        elseif gearType=="Boots" then style="boots"
        elseif gearType=="Ward" then style="ward"
        elseif gearType=="Band" then style="band" end
    end
    if not style then return false end
    local view=Instance.new("ViewportFrame")
    view.Name="ItemVisual"; view.BackgroundTransparency=1
    view.Size=UDim2.fromScale(0.95,0.95); view.Position=UDim2.fromScale(0.025,0.025)
    view.Ambient=Color3.fromRGB(175,170,155); view.LightColor=Color3.fromRGB(255,231,183)
    view.LightDirection=Vector3.new(-0.5,-0.8,-0.8);view.Parent=slot
    local world=Instance.new("WorldModel");world.Parent=view
    local brown=Color3.fromRGB(139,97,62)
    local silver=Color3.fromRGB(212,210,194)
    local colors={Color3.fromRGB(141,113,85),Color3.fromRGB(84,137,90),
        Color3.fromRGB(88,132,175),Color3.fromRGB(126,89,149),Color3.fromRGB(201,169,87)}
    local gearColor=colors[tonumber(tier) or 1]
    if style=="fur" then
        part(world,Enum.PartType.Ball,Vector3.new(2.2,1.7,0.85),Color3.fromRGB(147,128,103),CFrame.new())
        for i=-2,2 do
            part(world,Enum.PartType.Block,Vector3.new(0.32,1.4,0.52),Color3.fromRGB(105+math.abs(i)*13,90+math.abs(i)*12,76+math.abs(i)*8),CFrame.new(i*0.34,0.1,-0.36)*CFrame.Angles(0,0,math.rad(i*10)))
        end
    elseif style=="fang" or style=="claw" then
        local rot=style=="claw" and -0.3 or 0.35
        part(world,Enum.PartType.Wedge,Vector3.new(0.9,2.4,0.95),style=="claw" and Color3.fromRGB(170,151,123) or silver,
            CFrame.Angles(0,0,rot))
        part(world,Enum.PartType.Ball,Vector3.new(0.9,0.48,0.92),brown,CFrame.new(0,-1.03,0))
    elseif style=="hide" then
        part(world,Enum.PartType.Block,Vector3.new(2.45,1.85,0.2),Color3.fromRGB(117,79,54),CFrame.Angles(0,0,0.12))
        for x=-1,1,2 do for y=-1,1,2 do
            part(world,Enum.PartType.Ball,Vector3.new(0.65,0.62,0.24),brown,CFrame.new(x*1.1,y*0.73,-0.05))
        end end
    elseif style=="rune" then
        local rock=part(world,Enum.PartType.Block,Vector3.new(1.7,1.8,0.6),Color3.fromRGB(83,106,125),CFrame.Angles(0,0,0.25))
        rock.Material=Enum.Material.Slate
        local rune=part(world,Enum.PartType.Block,Vector3.new(0.22,1.1,0.09),Color3.fromRGB(102,231,226),CFrame.new(0,0,-0.36))
        rune.Material=Enum.Material.Neon
    elseif style=="potion" then
        local bottle=part(world,Enum.PartType.Ball,Vector3.new(1.65,1.55,1),Color3.fromRGB(56,160,117),CFrame.new(0,-0.3,0))
        bottle.Material=Enum.Material.Glass
        part(world,Enum.PartType.Block,Vector3.new(0.5,0.7,0.5),Color3.fromRGB(115,196,160),CFrame.new(0,0.62,0))
        part(world,Enum.PartType.Block,Vector3.new(0.75,0.4,0.75),brown,CFrame.new(0,1.03,0))
    elseif style=="hood" then
        local cap=part(world,Enum.PartType.Ball,Vector3.new(2.25,1.3,1.9),gearColor,CFrame.new(0,.2,0))
        part(world,Enum.PartType.Block,Vector3.new(2.35,.28,1.9),brown,CFrame.new(0,-.25,0))
    elseif style=="vest" then
        part(world,Enum.PartType.Block,Vector3.new(2.1,2.1,.6),gearColor,CFrame.new())
        part(world,Enum.PartType.Block,Vector3.new(.25,2.2,.67),silver,CFrame.new(0,0,-.05))
    elseif style=="gloves" then
        for x=-1,1,2 do part(world,Enum.PartType.Block,Vector3.new(.9,1.8,.8),gearColor,CFrame.new(x*.65,0,0)) end
    elseif style=="leggings" then
        for x=-1,1,2 do part(world,Enum.PartType.Block,Vector3.new(.95,2.4,.8),gearColor,CFrame.new(x*.55,0,0)) end
    elseif style=="boots" then
        for x=-1,1,2 do part(world,Enum.PartType.Block,Vector3.new(1,1.3,1.25),gearColor,CFrame.new(x*.65,-.4,0)) end
    elseif style=="ward" then
        part(world,Enum.PartType.Block,Vector3.new(2.2,2.5,.34),gearColor,CFrame.new())
        part(world,Enum.PartType.Block,Vector3.new(.26,2.35,.39),silver,CFrame.new())
    elseif style=="band" then
        local p=part(world,Enum.PartType.Cylinder,Vector3.new(.45,2.3,2.3),gearColor,CFrame.Angles(0,0,math.pi/2))
    elseif style=="sword" then
        part(world,Enum.PartType.Block,Vector3.new(0.48,2.6,0.2),tier and gearColor or silver,CFrame.new(0,0.45,0)*CFrame.Angles(0,0,0.65))
        part(world,Enum.PartType.Block,Vector3.new(1.4,0.24,0.35),Color3.fromRGB(178,136,59),CFrame.Angles(0,0,0.65)*CFrame.new(0,-0.85,0))
        part(world,Enum.PartType.Block,Vector3.new(0.27,1.15,0.28),brown,CFrame.Angles(0,0,0.65)*CFrame.new(0,-1.47,0))
    end
    local camera=Instance.new("Camera");camera.FieldOfView=42
    camera.CFrame=CFrame.lookAt(Vector3.new(3,2.4,-7),Vector3.new(0,0,0))
    camera.Parent=view; view.CurrentCamera=camera
    return true
end
return Preview
