-- Realms of Lumia v10: original minted coinage; persisted Gold is always the smallest unit.
-- Display only: no migration and no change to shop prices, rewards, or save format.
--
-- ONE ladder, one source of truth. Every UI that shows coinage reads Tiers, so a
-- rename here is complete — the previous version hardcoded "Sun"/"Moon"/"Cinder"
-- inside Format and FormatShort, which is exactly how names drift apart.
--
--   Platinum  10,000 copper
--   Silver       100 copper
--   Copper         1  (the stored unit)
local Currency={}

Currency.Tiers={
    {Id="Platinum", Name="Platinum", Plural="Platinum", Per=10000},
    {Id="Silver",   Name="Silver",   Plural="Silver",   Per=100},
    {Id="Copper",   Name="Copper",   Plural="Copper",   Per=1},
}

-- Metals are uncountable, so plural == singular ("50 silver", not "50 silvers").
Currency.SmallName="Copper"; Currency.MidName="Silver"; Currency.LargeName="Platinum"
Currency.SmallPlural="Copper"; Currency.MidPlural="Silver"; Currency.LargePlural="Platinum"
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
    local denomHigh,denomMid,denomLow=Currency.Split(amount)
    return unit(denomHigh,large.Name,large.Plural).."   "
        ..unit(denomMid,mid.Name,mid.Plural).."   "
        ..unit(denomLow,small.Name,small.Plural)
end

function Currency.FormatShort(amount)
    local denomHigh,denomMid,denomLow=Currency.Split(amount)
    local out={}
    if denomHigh>0 then table.insert(out,unit(denomHigh,large.Name,large.Plural)) end
    if denomMid>0 then table.insert(out,unit(denomMid,mid.Name,mid.Plural)) end
    if denomLow>0 or #out==0 then table.insert(out,unit(denomLow,small.Name,small.Plural)) end
    return table.concat(out,"  ")
end
return Currency
