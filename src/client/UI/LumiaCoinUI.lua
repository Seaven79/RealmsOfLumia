-- Realms of Lumia original coin glyphs (Roblox primitives, no third-party icon IDs).
-- Full icons rendered using a circular metal disk, subtle bevel, and embossed mark.
local UserInputService=game:GetService("UserInputService")
local GuiService=game:GetService("GuiService")
local RunService=game:GetService("RunService")
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
-- Hover help: hovering a coin names it. Kept additive so the wallet structure,
-- holder names and SetWallet lookups are untouched.
local function infoCard(screenGui)
    local existing=screenGui:FindFirstChild("LumiaCoinInfo")
    if existing then return existing end
    local card=new("TextLabel",screenGui,{Name="LumiaCoinInfo",Visible=false,
        BackgroundColor3=Color3.fromRGB(11,18,32),BackgroundTransparency=0.05,
        BorderSizePixel=0,Text="",Font=Enum.Font.GothamBold,TextSize=12,
        TextColor3=Color3.fromRGB(235,242,250),TextWrapped=true,
        TextXAlignment=Enum.TextXAlignment.Center,TextYAlignment=Enum.TextYAlignment.Center,
        Size=UDim2.fromOffset(120,26),ZIndex=200})
    new("UICorner",card,{CornerRadius=UDim.new(0,6)})
    new("UIStroke",card,{Color=Color3.fromRGB(120,90,50),Thickness=1})
    return card
end

-- Positions a card beside the pointer. GetMouseLocation includes the topbar
-- inset, so subtract it when the owning ScreenGui does not ignore the inset
-- (same rule ItemTooltip uses). Clamped so the card never leaves the viewport.
local function placeCard(card,screenGui)
    local mouse=UserInputService:GetMouseLocation()
    if not screenGui.IgnoreGuiInset then
        local inset=GuiService:GetGuiInset()
        mouse=mouse-inset
    end
    -- AbsoluteSize can be 0 on the very first frame; fall back to the intended
    -- size so the first placement is not clamped to the top-left corner.
    local cardWidth=card.AbsoluteSize.X
    if not cardWidth or cardWidth<=0 then cardWidth=120 end
    local cardHeight=card.AbsoluteSize.Y
    if not cardHeight or cardHeight<=0 then cardHeight=26 end
    local screen=screenGui.AbsoluteSize
    card.Position=UDim2.fromOffset(
        math.clamp(math.floor(mouse.X+18),0,math.max(0,screen.X-cardWidth-4)),
        math.clamp(math.floor(mouse.Y+18),0,math.max(0,screen.Y-cardHeight-4)))
end

-- Followers are dropped whenever the card hides, so an idle wallet costs nothing.
local followConnection=nil
local moveConnection=nil
local function stopFollowing()
    if followConnection then
        followConnection:Disconnect()
        followConnection=nil
    end
    if moveConnection then
        moveConnection:Disconnect()
        moveConnection=nil
    end
end
local function followPointer(card,screenGui)
    stopFollowing()
    placeCard(card,screenGui)
    -- RenderStepped runs before the frame is drawn, so the card is placed with the
    -- freshest position available for that frame.
    followConnection=RunService.RenderStepped:Connect(function()
        if not card.Visible or not card.Parent then
            stopFollowing()
            return
        end
        placeCard(card,screenGui)
    end)
    -- Mouse movement events arrive on the input stream, which can be sampled more
    -- often than the frame rate. Updating here removes the sub-frame delay that
    -- makes a fast-moving cursor appear to outrun its label.
    moveConnection=UserInputService.InputChanged:Connect(function(input)
        if input.UserInputType~=Enum.UserInputType.MouseMovement
            and input.UserInputType~=Enum.UserInputType.Touch then return end
        if not card.Visible or not card.Parent then
            stopFollowing()
            return
        end
        placeCard(card,screenGui)
    end)
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

        -- Transparent hover target laid over the coin. A Frame cannot raise
        -- MouseEnter, and swapping the holder to a button would change the
        -- structure SetWallet depends on.
        local hover=new("TextButton",holder,{Name="CoinHover",Text="",
            BackgroundTransparency=1,AutoButtonColor=false,BorderSizePixel=0,
            Size=UDim2.fromScale(1,1),ZIndex=2})
        local tier=currencyModule.Tiers[i]
        hover.MouseEnter:Connect(function()
            local screenGui=outer:FindFirstAncestorWhichIsA("ScreenGui")
            if not screenGui or not tier then return end
            local card=infoCard(screenGui)
            card.Text=tier.Name
            card.Visible=true
            followPointer(card,screenGui)
        end)
        hover.MouseLeave:Connect(function()
            local screenGui=outer:FindFirstAncestorWhichIsA("ScreenGui")
            local card=screenGui and screenGui:FindFirstChild("LumiaCoinInfo")
            if card then card.Visible=false end
            stopFollowing()
        end)
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
