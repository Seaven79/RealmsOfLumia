-- Realms of Lumia v10: original minted coinage; persisted Gold is always the smallest unit.
-- Display only: no migration and no change to shop prices, rewards, or save format.
--
-- ONE ladder, one source of truth. Every UI reads Tiers, so a rename here is
-- complete: the previous version hardcoded the coin names inside Format and
-- FormatShort, which is how names drift apart.
--
--   Platinum  10,000 bronze
--   Copper       100 bronze
--   Bronze         1  (the stored unit)
local Currency={}

Currency.Tiers={
    {Id="Platinum", Name="Platinum", Plural="Platinum", Per=10000},
    {Id="Copper",   Name="Copper",   Plural="Copper",   Per=100},
    {Id="Bronze",   Name="Bronze",   Plural="Bronze",   Per=1},
}

-- Metals are uncountable, so plural == singular ("50 bronze", not "50 bronzes").
Currency.SmallName="Bronze"; Currency.MidName="Copper"; Currency.LargeName="Platinum"
Currency.SmallPlural="Bronze"; Currency.MidPlural="Copper"; Currency.LargePlural="Platinum"
Currency.SmallPerMid=100; Currency.MidPerLarge=100

function Currency.Split(amount)
    amount=math.max(0,math.floor(tonumber(amount) or 0))
    return math.floor(amount/10000),math.floor((amount%10000)/100),amount%100
end

local large,mid,small=Currency.Tiers[1],Currency.Tiers[2],Currency.Tiers[3]

local function unit(n,singular,plural)
    return tostring(n).." "..(n==1 and singular or plural)
end

function Currency.Format(amount)
    local highDenom,midDenom,lowDenom=Currency.Split(amount)
    return unit(highDenom,large.Name,large.Plural).."   "
        ..unit(midDenom,mid.Name,mid.Plural).."   "
        ..unit(lowDenom,small.Name,small.Plural)
end

function Currency.FormatShort(amount)
    local highDenom,midDenom,lowDenom=Currency.Split(amount)
    local out={}
    if highDenom>0 then table.insert(out,unit(highDenom,large.Name,large.Plural)) end
    if midDenom>0 then table.insert(out,unit(midDenom,mid.Name,mid.Plural)) end
    if lowDenom>0 or #out==0 then table.insert(out,unit(lowDenom,small.Name,small.Plural)) end
    return table.concat(out,"  ")
end
return Currency
