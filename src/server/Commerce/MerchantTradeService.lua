-- Realms of Lumia commerce backend. One reusable instance per server-owned NPC and catalog.
-- Never trusts client prices, quantities, money, or item type. No DataStore schema change.
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local server=script.Parent.Parent
local Inventory=require(server:WaitForChild("Inventory"):WaitForChild("InventoryService"))
local Data=require(server:WaitForChild("Players"):WaitForChild("PlayerDataService"))
local Snapshot=require(server:WaitForChild("Inventory"):WaitForChild("BagSnapshot"))
local Shared=ReplicatedStorage:WaitForChild("Lumia"):WaitForChild("Shared")
local Items=require(Shared:WaitForChild("Items"):WaitForChild("ItemDefinitions"))
local Currency=require(Shared:WaitForChild("Commerce"):WaitForChild("LumiaCurrency"))
local Trade={}
local function offers(config, level)
    if type(config.GetStock)=="function" then return config.GetStock(level) end
    return config.BuyItems or {}
end
Trade.__index=Trade
function Trade.new(options)
    assert(type(options)=="table" and type(options.Merchant)=="function" and options.Config,
        "Merchant resolver and catalog config required")
    return setmetatable({resolver=options.Merchant,config=options.Config,throttles=setmetatable({},{__mode="k"})},Trade)
end
local function character(player)
    local profile=Data:GetProfile(player)
    return profile and profile.Character
end
function Trade:Within(player)
    local npc=self.resolver()
    local root=player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    local hum=player.Character and player.Character:FindFirstChildOfClass("Humanoid")
    return npc and npc.Parent and root and hum and hum.Health>0
        and (root.Position-npc:GetPivot().Position).Magnitude<=self.config.InteractionRange
end
function Trade:Public(player)
    local char=character(player)
    local selling={}
    for _,rec in ipairs(Inventory:GetBagItems(player) or {}) do
        local def=Items.Get(rec.ItemId)
        if def and def.Type~="Quest" and not def.QuestItem and (def.SellValue or 0)>0 then
            table.insert(selling,{ItemId=rec.ItemId,Name=def.DisplayName,
                Price=def.SellValue,Quantity=rec.Quantity,
                BagId=rec.BagId,BagSlot=rec.BagSlot})
        end
    end
    return {Ok=true,Gold=char and char.Gold or 0,
        Currency=Currency.Format(char and char.Gold or 0),
        BuyItems=offers(self.config, char and char.Level or 1),SellItems=selling,MerchantName=self.config.MerchantName,Bag=Snapshot.Build(player)}
end
function Trade:Open(player)
    if not self:Within(player) then return {Ok=false,Message="Move closer to the trader"} end
    if not character(player) then return {Ok=false,Message="Player data unavailable"} end
    return self:Public(player)
end
function Trade:Perform(player,verb,itemId,bagId,bagSlot,instanceId)
    if type(verb)~="string" or type(itemId)~="string" then
        return {Ok=false,Message="Invalid request"}
    end
    local now=os.clock()
    if self.throttles[player] and now-self.throttles[player]<0.12 then
        return {Ok=false,Message="Please wait a moment"}
    end
    self.throttles[player]=now
    local ok,reply=pcall(function()
        local char=character(player)
        if not char then return {Ok=false,Message="Player data unavailable"} end
        if verb=="UsePotion" then
            if itemId~="FieldPotion" then return {Ok=false,Message="Unknown potion"} end
            local hum=player.Character and player.Character:FindFirstChildOfClass("Humanoid")
            if not hum or hum.Health<=0 then
                return {Ok=false,Message="Potion not needed"}
            end
            if Inventory:GetQuantity(player,"FieldPotion")<1 then
                return {Ok=false,Message="No potion in bag"}
            end
            local removed=Inventory:RemoveQuantity(player,"FieldPotion",1)
            if not removed then return {Ok=false,Message="Potion could not be used"} end
            local healed=math.max(0,math.min(35,hum.MaxHealth-hum.Health))
            hum.Health=math.min(hum.MaxHealth,hum.Health+healed)
            return {Ok=true,Message=healed>0 and ("Restored "..tostring(math.floor(healed)).." health")
                or "Potion consumed (health already full)",Bag=Snapshot.Build(player)}
        end
        if not self:Within(player) then return {Ok=false,Message="Visit the merchant counter"} end
        if verb=="Buy" then
            local offer=nil
            for _,entry in ipairs(offers(self.config,char.Level)) do
                if entry.ItemId==itemId then offer=entry break end
            end
            if not offer or not Items.Get(itemId) or type(offer.Price)~="number" or offer.Price<=0
                or (Items.Get(itemId).RequiredLevel or 1)>char.Level
                or char.Gold<offer.Price then
                return {Ok=false,Message="Not enough coins, or item unavailable"}
            end
            local added,errorMessage=Inventory:AddItem(player,itemId,1)
            if not added then return {Ok=false,Message=tostring(errorMessage)} end
            char.Gold-=offer.Price
        elseif verb=="Sell" then
            if type(bagId)~="number" or type(bagSlot)~="number"
                or (instanceId~=nil and type(instanceId)~="string") then
                return {Ok=false,Message="Invalid bag slot"}
            end
            local record=Inventory:GetBagItemAt(player,bagId,bagSlot)
            if not record or record.ItemId~=itemId or record.InstanceId~=instanceId then
                return {Ok=false,Message="Inventory changed"}
            end
            local def=Items.Get(itemId)
            local price=def and def.SellValue
            if not def or def.Type=="Quest" or def.QuestItem
                or type(price)~="number" or price<=0
                or char.Gold+price>self.config.MaxGold then
                return {Ok=false,Message="Item cannot be sold"}
            end
            local removed,why=Inventory:RemoveBagQuantityAt(player,bagId,bagSlot,itemId,instanceId,1)
            if not removed then return {Ok=false,Message=tostring(why)} end
            char.Gold+=price
        else
            return {Ok=false,Message="Unknown trade action"}
        end
        local result=self:Public(player)
        result.Message=verb=="Buy" and "Purchased" or "Sold 1 item"
        return result
    end)
    if not ok then
        warn("[Lumia - Commerce] "..tostring(reply))
        return {Ok=false,Message="Trade unavailable"}
    end
    return reply
end
return Trade
