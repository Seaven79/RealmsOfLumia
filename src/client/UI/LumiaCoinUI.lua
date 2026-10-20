-- Realms of Lumia original coin glyphs (Roblox primitives, no third-party icon IDs).
-- Full icons rendered using a circular metal disk, subtle bevel, and embossed mark.
--
-- The wallet is driven by Currency.Tiers, so renaming the coinage is a one-file
-- change: tiers, glyphs, amounts and hover labels all follow the same table.
local Coins={}

local specs={
    Platinum={color=Color3.fromRGB(229,228,226),edge=Color3.fromRGB(118,122,132),mark="✦"},
    Silver={color=Color3.fromRGB(192,197,206),edge=Color3.fromRGB(98,104,115),mark="◐"},
    Copper={color=Color3.fromRGB(184,115,51),edge=Color3.fromRGB(108,64,30),mark="✧"},
}

local function new(class,parent,properties)
    local x=Instance.new(class)
    for k,v in pairs(properties) do x[k]=v end
    x.Parent=parent
    return x
end

local function groupThousands(n)
    local text=tostring(math.floor(tonumber(n) or 0))
    local out=text:reverse():gsub("(%d%d%d)","%1,"):reverse():gsub("^,","")
    return out
end

function Coins.Create(parent,tier,px)
    local spec=assert(specs[tier],"Unknown coin tier")
    px=px or 16
    local disk=new("Frame",parent,{Name=tier.."Coin",Size=UDim2.fromOffset(px,px),BackgroundColor3=spec.color,BorderSizePixel=0})
    new("UICorner",disk,{CornerRadius=UDim.new(1,0)})
    new("UIStroke",disk,{Color=spec.edge,Thickness=1.4})
    new("UIGradient",disk,{Rotation=45,ColorSequence.new({
        ColorSequenceKeypoint.new(0,Color3.fromRGB(252,241,203)),
        ColorSequenceKeypoint.new(.3,spec.color),
        ColorSequenceKeypoint.new(1,spec.edge)
    })})
    new("TextLabel",disk,{Size=UDim2.fromScale(1,1),BackgroundTransparency=1,Text=spec.mark,
        Font=Enum.Font.GothamBold,TextScaled=true,TextColor3=spec.edge,TextStrokeTransparency=0.8})
    return disk
end

-- Small label that explains what a coin is worth. One per ScreenGui, reused.
local function infoCard(screenGui)
    local existing=screenGui:FindFirstChild("LumiaCoinInfo")
    if existing then return existing end
    local card=new("TextLabel",screenGui,{Name="LumiaCoinInfo",Visible=false,
        BackgroundColor3=Color3.fromRGB(11,18,32),BackgroundTransparency=0.05,
        BorderSizePixel=0,Text="",Font=Enum.Font.GothamBold,TextSize=12,
        TextColor3=Color3.fromRGB(235,242,250),TextWrapped=true,
        TextXAlignment=Enum.TextXAlignment.Center,TextYAlignment=Enum.TextYAlignment.Center,
        Size=UDim2.fromOffset(210,26),ZIndex=200})
    new("UICorner",card,{CornerRadius=UDim.new(0,6)})
    new("UIStroke",card,{Color=Color3.fromRGB(120,90,50),Thickness=1})
    return card
end

function Coins.Wallet(parent,currencyModule,balance,isCompact)
    local tiers=currencyModule.Tiers
    local split={currencyModule.Split(balance)}
    local base=tiers[#tiers]
    local width=isCompact and 52 or 99
    local radius=isCompact and 13 or 18
    local outer=new("Frame",parent,{Name="LumiaCoinWallet",BackgroundTransparency=1,
        Size=UDim2.fromOffset(width*#tiers,isCompact and 18 or 24)})

    local names={}
    for i,tier in ipairs(tiers) do
        names[#names+1]=tier.Name
        -- TextButton, not Frame: only buttons raise MouseEnter/MouseLeave, which
        -- is what lets a player hover a coin to learn what it is.
        local holder=new("TextButton",outer,{Name=tier.Id,Text="",AutoButtonColor=false,
            BackgroundTransparency=1,BorderSizePixel=0,
            Position=UDim2.fromOffset((i-1)*width,0),Size=UDim2.fromOffset(width,radius+2)})
        local disk=Coins.Create(holder,tier.Id,radius)
        disk.Position=UDim2.fromOffset(0,1)
        new("TextLabel",holder,{Name="Amount",BackgroundTransparency=1,Text=tostring(split[i] or 0),
            Position=UDim2.fromOffset(radius+4,0),Size=UDim2.fromOffset(width-radius-4,radius+2),
            Font=Enum.Font.GothamBold,TextSize=isCompact and 10 or 13,
            TextColor3=Color3.fromRGB(241,221,186),TextXAlignment=Enum.TextXAlignment.Left})

        local label
        if tier.Per<=1 then
            label=string.format("%s  ·  base unit",tier.Name)
        else
            label=string.format("%s  ·  %s %s each",tier.Name,groupThousands(tier.Per),base.Name)
        end

        holder.MouseEnter:Connect(function()
            local screenGui=outer:FindFirstAncestorWhichIsA("ScreenGui")
            if not screenGui then return end
            local card=infoCard(screenGui)
            card.Text=label
            local pos=holder.AbsolutePosition
            local size=holder.AbsoluteSize
            card.Position=UDim2.fromOffset(
                math.floor(pos.X+size.X/2-105),
                math.max(0,math.floor(pos.Y-30)))
            card.Visible=true
        end)
        holder.MouseLeave:Connect(function()
            local screenGui=outer:FindFirstAncestorWhichIsA("ScreenGui")
            if not screenGui then return end
            local card=screenGui:FindFirstChild("LumiaCoinInfo")
            if card then card.Visible=false end
        end)
    end

    outer:SetAttribute("CurrencyDenominations",table.concat(names,"/"))
    return outer
end

function Coins.SetWallet(wallet,currencyModule,balance)
    local split={currencyModule.Split(balance)}
    for i,tier in ipairs(currencyModule.Tiers) do
        local frame=wallet:FindFirstChild(tier.Id)
        local amount=frame and frame:FindFirstChild("Amount")
        if amount then amount.Text=tostring(split[i] or 0) end
    end
end
return Coins
