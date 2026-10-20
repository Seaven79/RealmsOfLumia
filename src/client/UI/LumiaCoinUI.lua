-- Realms of Lumia original coin glyphs (Roblox primitives, no third-party icon IDs).
-- Full icons rendered using a circular metal disk, subtle bevel, and embossed mark.
local Coins={}
local specs={
    Sun={color=Color3.fromRGB(209,157,60),edge=Color3.fromRGB(119,76,30),mark="✦"},
    Moon={color=Color3.fromRGB(171,193,207),edge=Color3.fromRGB(84,103,127),mark="◐"},
    Cinder={color=Color3.fromRGB(171,103,65),edge=Color3.fromRGB(96,53,40),mark="✧"},
}
local function new(class,parent,properties)
    local x=Instance.new(class)
    for k,v in pairs(properties) do x[k]=v end
    x.Parent=parent
    return x
end
function Coins.Create(parent,tier,px)
    local spec=assert(specs[tier],"Unknown coin tier")
    px=px or 16
    local disk=new("Frame",parent,{Name=tier.."Coin",Size=UDim2.fromOffset(px,px),BackgroundColor3=spec.color,BorderSizePixel=0})
    new("UICorner",disk,{CornerRadius=UDim.new(1,0)})
    new("UIStroke",disk,{Color=spec.edge,Thickness=1.4})
    new("UIGradient",disk,{Rotation=45,Color=ColorSequence.new({
        ColorSequenceKeypoint.new(0,Color3.fromRGB(252,241,203)),
        ColorSequenceKeypoint.new(.3,spec.color),
        ColorSequenceKeypoint.new(1,spec.edge)
    })})
    local mark=new("TextLabel",disk,{Size=UDim2.fromScale(1,1),BackgroundTransparency=1,Text=spec.mark,
        Font=Enum.Font.GothamBold,TextScaled=true,TextColor3=spec.edge,TextStrokeTransparency=0.8})
    return disk
end
function Coins.Wallet(parent,currencyModule,balance,isCompact)
    local sun,moon,cinder=currencyModule.Split(balance)
    local tiers={{"Sun",sun},{"Moon",moon},{"Cinder",cinder}}
    local width=isCompact and 52 or 99
    local radius=isCompact and 13 or 18
    local outer=new("Frame",parent,{Name="LumiaCoinWallet",BackgroundTransparency=1,
        Size=UDim2.fromOffset(width*3,isCompact and 18 or 24)})
    for i,entry in ipairs(tiers) do
        local holder=new("Frame",outer,{Name=entry[1],BackgroundTransparency=1,
            Position=UDim2.fromOffset((i-1)*width,0),Size=UDim2.fromOffset(width,radius+2)})
        local disk=Coins.Create(holder,entry[1],radius)
        disk.Position=UDim2.fromOffset(0,1)
        new("TextLabel",holder,{Name="Amount",BackgroundTransparency=1,Text=tostring(entry[2]),
            Position=UDim2.fromOffset(radius+4,0),Size=UDim2.fromOffset(width-radius-4,radius+2),
            Font=Enum.Font.GothamBold,TextSize=isCompact and 10 or 13,
            TextColor3=Color3.fromRGB(241,221,186),TextXAlignment=Enum.TextXAlignment.Left})
    end
    return outer
end
function Coins.SetWallet(wallet,currencyModule,balance)
    local sun,moon,cinder=currencyModule.Split(balance)
    local values={Sun=sun,Moon=moon,Cinder=cinder}
    for tier,n in pairs(values) do
        local frame=wallet:FindFirstChild(tier)
        if frame then frame.Amount.Text=tostring(n) end
    end
end
return Coins
