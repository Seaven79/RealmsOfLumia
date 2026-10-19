-- REALMS OF LUMIA | Server-authoritative monster balancing v1
-- Separate from player saves and XP tuning. Changes apply to NEW spawns / loot rolls.
-- Future monster types automatically appear when added to MonsterConfig and LootConfig.
local DataStoreService = game:GetService("DataStoreService")
local MessagingService = game:GetService("MessagingService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Lumia"):WaitForChild("Shared")
local MonsterConfig = require(Shared:WaitForChild("Monsters"):WaitForChild("MonsterConfig"))
local LootConfig = require(Shared:WaitForChild("Loot"):WaitForChild("LootConfig"))
local ItemDefinitions = require(Shared:WaitForChild("Items"):WaitForChild("ItemDefinitions"))

local MobTuning = {}
MobTuning.Loaded = Instance.new("BindableEvent")
local store = DataStoreService:GetDataStore("RealmsOfLumia_MobTuning_" .. tostring(game.GameId))
local KEY = "MobTuning_v1"
local TOPIC = "LumiaMobTuning_v1"

local STAT_FIELDS = {
    {Key="Level",Label="Level",Min=1,Max=60,Integer=true},
    {Key="MaxHealth",Label="Maximum health",Min=1,Max=100000,Integer=true},
    {Key="Damage",Label="Attack damage",Min=0,Max=10000,Integer=true},
    {Key="WanderRadius",Label="Wander radius",Min=0,Max=150},
    {Key="DetectionRadius",Label="Detection radius",Min=1,Max=200},
    {Key="ChaseLimit",Label="Chase distance",Min=1,Max=300},
    {Key="AttackRange",Label="Attack range",Min=1,Max=30},
    {Key="AttackCooldown",Label="Seconds per attack",Min=0.2,Max=30},
    {Key="WalkSpeed",Label="Walking speed",Min=0,Max=32},
    {Key="ChaseSpeed",Label="Chasing speed",Min=0,Max=48},
}
local specByKey = {}
for _,field in ipairs(STAT_FIELDS) do specByKey[field.Key] = field end

local function allowedItem(itemId)
    local item = ItemDefinitions.Get(itemId)
    return item and item.CanBeDropped == true and item.Rarity == "Poor"
end

local function validNumber(value,minValue,maxValue,isInteger)
    return type(value)=="number" and value==value and value > -math.huge and value < math.huge
        and value>=minValue and value<=maxValue and (not isInteger or value%1==0)
end

local function clean(record)
    local result = {Revision=0, Stats={}, Loot={}}
    if type(record) ~= "table" then return result end
    if validNumber(record.Revision,0,1000000000,true) then result.Revision = record.Revision end
    for id in pairs(MonsterConfig.Definitions) do
        local stats = type(record.Stats)=="table" and record.Stats[id]
        if type(stats)=="table" then
            local valid = {}
            for _,field in ipairs(STAT_FIELDS) do
                local v = stats[field.Key]
                if validNumber(v,field.Min,field.Max,field.Integer) then valid[field.Key]=v end
            end
            result.Stats[id]=valid
        end
        local loot = type(record.Loot)=="table" and record.Loot[id]
        if type(loot)=="table" then
            local sanitized = {Weights={}}
            if validNumber(loot.DropCount,0,5,true) then sanitized.DropCount=loot.DropCount end
            if type(loot.Weights)=="table" then
                for itemId,value in pairs(loot.Weights) do
                    if type(itemId)=="string" and allowedItem(itemId)
                        and validNumber(value,0,1000,true) then
                        sanitized.Weights[itemId]=value
                    end
                end
            end
            result.Loot[id]=sanitized
        end
    end
    return result
end

local loaded, loading, available = false, false, false
local values = clean(nil)
function MobTuning:EnsureLoaded()
    if loaded then return available end
    if loading then
        MobTuning.Loaded.Event:Wait()
        return available
    end
    loading=true
    local ok,data = pcall(function() return store:GetAsync(KEY) end)
    if ok then
        values=clean(data)
        available=true
    else
        warn("[Lumia - Mob Tuning Service] Admin settings unavailable: "..tostring(data))
    end
    loaded=true
    loading=false
    MobTuning.Loaded:Fire()
    return available
end

function MobTuning:GetDefinition(monsterId)
    self:EnsureLoaded()
    local base=MonsterConfig.Definitions[monsterId]
    if not base then return nil end
    local result=table.clone(base)
    for key,value in pairs(values.Stats[monsterId] or {}) do result[key]=value end
    return result
end

function MobTuning:GetLootProfile(monsterId)
    self:EnsureLoaded()
    local base=LootConfig.Monsters[monsterId]
    if not base then return nil end
    local override=values.Loot[monsterId] or {}
    local result={DropCount=override.DropCount or base.DropCount or 1, Drops={}}
    local seen={}
    for _,drop in ipairs(base.Drops or {}) do
        if allowedItem(drop.ItemId) then
            local weight=(override.Weights or {})[drop.ItemId]
            if weight==nil then weight=drop.Weight end
            result.Drops[#result.Drops+1]={ItemId=drop.ItemId, Weight=weight}
            seen[drop.ItemId]=true
        end
    end
    -- Newly added eligible catalog items can be enabled by weight in a future patch.
    for itemId,weight in pairs(override.Weights or {}) do
        if not seen[itemId] and allowedItem(itemId) then
            result.Drops[#result.Drops+1]={ItemId=itemId,Weight=weight}
        end
    end
    return result
end

function MobTuning:Snapshot()
    self:EnsureLoaded()
    local monsterIds={}
    local monsters={}
    for id,base in pairs(MonsterConfig.Definitions) do
        monsterIds[#monsterIds+1]=id
        local actual=self:GetDefinition(id)
        local loot=self:GetLootProfile(id)
        local weights={}
        for _,drop in ipairs(loot and loot.Drops or {}) do weights[drop.ItemId]=drop.Weight end
        monsters[id]={Name=base.DisplayName,Stats=actual,
            Loot={DropCount=loot and loot.DropCount or 0,Weights=weights},
            Overrides={Stats=table.clone(values.Stats[id] or {}),Loot=table.clone((values.Loot[id] or {}).Weights or {})}}
    end
    table.sort(monsterIds)
    local catalog={}
    for itemId,entry in pairs(ItemDefinitions.Definitions) do
        if allowedItem(itemId) then
            catalog[#catalog+1]={Id=itemId,Name=entry.DisplayName}
        end
    end
    table.sort(catalog,function(a,b) return a.Name<b.Name end)
    return {Revision=values.Revision,PersistenceAvailable=available,
        MonsterIds=monsterIds,Monsters=monsters,StatFields=STAT_FIELDS,ItemCatalog=catalog}
end

function MobTuning:Update(monsterId,kind,key,value)
    if not self:EnsureLoaded() then return false,"Mob tuning DataStore unavailable" end
    if type(monsterId)~="string" or not MonsterConfig.Definitions[monsterId] then
        return false,"Unknown monster ID"
    end
    if kind=="Stat" then
        local spec=specByKey[key]
        if not spec or not validNumber(value,spec.Min,spec.Max,spec.Integer) then
            return false,"Invalid monster statistic"
        end
    elseif kind=="ResetStat" then
        if not specByKey[key] then return false,"Unknown statistic" end
    elseif kind=="DropCount" then
        if not LootConfig.Monsters[monsterId] or not validNumber(value,0,5,true) then
            return false,"Drop count must be 0–5"
        end
    elseif kind=="Weight" then
        if not LootConfig.Monsters[monsterId] or type(key)~="string" or not allowedItem(key)
            or not validNumber(value,0,1000,true) then
            return false,"Invalid gray loot item or weight"
        end
    elseif kind=="ResetWeight" then
        if type(key)~="string" or not allowedItem(key) then return false,"Invalid item" end
    elseif kind=="ResetDropCount" then
        if not LootConfig.Monsters[monsterId] then return false,"No loot table" end
    else
        return false,"Unknown mob tuning operation"
    end
    local ok,saved=pcall(function()
        return store:UpdateAsync(KEY,function(old)
            local nextValue=clean(old)
            nextValue.Stats[monsterId]=nextValue.Stats[monsterId] or {}
            nextValue.Loot[monsterId]=nextValue.Loot[monsterId] or {Weights={}}
            local stat=nextValue.Stats[monsterId]
            local loot=nextValue.Loot[monsterId]
            loot.Weights=loot.Weights or {}
            if kind=="Stat" then stat[key]=value
            elseif kind=="ResetStat" then stat[key]=nil
            elseif kind=="DropCount" then loot.DropCount=value
            elseif kind=="ResetDropCount" then loot.DropCount=nil
            elseif kind=="Weight" then loot.Weights[key]=value
            elseif kind=="ResetWeight" then loot.Weights[key]=nil end
            nextValue.Revision+=1
            return nextValue
        end)
    end)
    if not ok then return false,"Save failed: "..tostring(saved) end
    local updated=clean(saved)
    if updated.Revision>=values.Revision then values=updated end
    task.spawn(function()
        local published,err=pcall(function()
            MessagingService:PublishAsync(TOPIC,values)
        end)
        if not published then warn("[Lumia - Mob Tuning Service] Cross-server update not published: "..tostring(err)) end
    end)
    return true,self:Snapshot()
end

function MobTuning:StartCrossServerSync()
    if self._subscribed then return end
    self._subscribed=true
    task.spawn(function()
        local ok,err=pcall(function()
            MessagingService:SubscribeAsync(TOPIC,function(message)
                local incoming=clean(message.Data)
                if incoming.Revision>values.Revision then values=incoming end
            end)
        end)
        if not ok then warn("[Lumia - Mob Tuning Service] Cross-server subscription unavailable: "..tostring(err)) end
    end)
end
return MobTuning
