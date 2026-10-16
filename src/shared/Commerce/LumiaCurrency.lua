-- Realms of Lumia v10: original minted coinage; persisted Gold is always the smallest unit.
-- Display only: no migration and no change to shop prices, rewards, or save format.
local Currency={}
Currency.SmallName="Cinder"; Currency.MidName="Moon"; Currency.LargeName="Sun"
Currency.SmallPlural="Cinders"; Currency.MidPlural="Moons"; Currency.LargePlural="Suns"
Currency.SmallPerMid=100; Currency.MidPerLarge=100
function Currency.Split(amount)
    amount=math.max(0,math.floor(tonumber(amount) or 0))
    return math.floor(amount/10000),math.floor((amount%10000)/100),amount%100
end
local function unit(n,singular,plural)
    return tostring(n).." "..(n==1 and singular or plural)
end
function Currency.Format(amount)
    local suns,moons,cinders=Currency.Split(amount)
    return unit(suns,"Sun","Suns").."   "..unit(moons,"Moon","Moons").."   "..unit(cinders,"Cinder","Cinders")
end
function Currency.FormatShort(amount)
    local suns,moons,cinders=Currency.Split(amount)
    local out={}
    if suns>0 then table.insert(out,unit(suns,"Sun","Suns")) end
    if moons>0 then table.insert(out,unit(moons,"Moon","Moons")) end
    if cinders>0 or #out==0 then table.insert(out,unit(cinders,"Cinder","Cinders")) end
    return table.concat(out,"  ")
end
return Currency
