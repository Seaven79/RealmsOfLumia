-- Realms of Lumia original coin glyphs (Roblox primitives, no third-party icon IDs).
-- Full icons rendered using a circular metal disk, subtle bevel, and embossed mark.
local Coins={}
local specs={
    Platinum={color=Color3.fromRGB(229,228,226),edge=Color3.fromRGB(118,122,132),mark="✦"},
    Copper={color=Color3.fromRGB(184,115,51),edge=Color3.fromRGB(108,64,30),mark="◐"},
    Bronze={color=Color3.fromRGB(150,101,56),edge=Color3.fromRGB(92,58,28),mark="✧"},
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
    local highDenom,midDenom,lowDenom=currencyModule.Split(balance)
    -- Holder names come from the shared ladder, so a rename in LumiaCurrency can
    -- never desync the wallet from the names SetWallet looks up.
    local tiers={{currencyModule.Tiers[1].Id,highDenom},
        {currencyModule.Tiers[2].Id,midDenom},
        {currencyModule.Tiers[3].Id,lowDenom}}
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
    local splits={currencyModule.Split(balance)}
    for index,tier in ipairs(currencyModule.Tiers) do
        local frame=wallet:FindFirstChild(tier.Id)
        local amount=frame and frame:FindFirstChild("Amount")
        if amount then amount.Text=tostring(splits[index] or 0) end
    end
end
return Coins
