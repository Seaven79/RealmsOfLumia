-- REALMS OF LUMIA | Server-authoritative, persisted progression balance.
-- Does not change player records. One settings record per Roblox experience.
-- Quest reward tiers are stored now for use by the future QuestService.
local DataStoreService = game:GetService("DataStoreService")
local MessagingService = game:GetService("MessagingService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Lumia"):WaitForChild("Shared")
local ProgressionConfig = require(Shared:WaitForChild("Progression"):WaitForChild("ProgressionConfig"))
local MonsterConfig = require(Shared:WaitForChild("Monsters"):WaitForChild("MonsterConfig"))
local Settings = require(script.Parent:WaitForChild("BalanceSettings"))

local BalanceService = {}
BalanceService.Changed = Instance.new("BindableEvent")
local store = DataStoreService:GetDataStore("RealmsOfLumia_Balance_" .. tostring(game.GameId))
local STORE_KEY = "SharedBalance_v1"
local TOPIC = "LumiaBalance_v1"
local loaded = false
local loading = false
local persistenceAvailable = false
local config = {Revision=0, LevelXP={}, QuestXP={}, MonsterXP={}}

local function integer(value, upper)
    return type(value)=="number" and value==value and value%1==0 and value>=Settings.MinXP and value<=upper
end

local function sanitize(record)
    local result = {Revision=0, LevelXP={}, QuestXP={}, MonsterXP={}}
    if type(record)~="table" then return result end
    if type(record.Revision)=="number" and record.Revision>=0 and record.Revision%1==0 then
        result.Revision=record.Revision
    end
    if type(record.LevelXP)=="table" then
        for level=1,ProgressionConfig.MAX_LEVEL-1 do
            local value=record.LevelXP[tostring(level)]
            if integer(value,Settings.MaxXPPerLevel) then result.LevelXP[tostring(level)]=value end
        end
    end
    if type(record.QuestXP)=="table" then
        for _,tier in ipairs({"Starter","Side","Main"}) do
            local value=record.QuestXP[tier]
            if integer(value,Settings.MaxRewardXP) then result.QuestXP[tier]=value end
        end
    end
    if type(record.MonsterXP)=="table" then
        local value=record.MonsterXP.ForestWolf
        if integer(value,Settings.MaxRewardXP) then result.MonsterXP.ForestWolf=value end
    end
    return result
end

local function broadcast()
    BalanceService.Changed:Fire()
end

function BalanceService:EnsureLoaded()
    if loaded then return persistenceAvailable end
    if loading then
        while not loaded do task.wait(0.05) end
        return persistenceAvailable
    end
    loading=true
    local ok, result=pcall(function() return store:GetAsync(STORE_KEY) end)
    if ok then
        config=sanitize(result)
        persistenceAvailable=true
    else
        warn("[Lumia - Balance Service] Settings load failed; defaults active. No admin writes: "..tostring(result))
    end
    loaded=true
    loading=false
    broadcast()
    return persistenceAvailable
end

function BalanceService:GetRequiredXP(level)
    self:EnsureLoaded()
    if type(level)~="number" then return nil end
    return config.LevelXP[tostring(level)] or ProgressionConfig.GetRequiredXP(level)
end

function BalanceService:GetQuestXP(tier)
    self:EnsureLoaded()
    local defaults={Starter=150,Side=200,Main=300}
    local configured=(type(ProgressionConfig.GetQuestRewardXP)=="function")
        and ProgressionConfig.GetQuestRewardXP(tier)
    return config.QuestXP[tier] or configured or defaults[tier]
end

function BalanceService:GetMonsterXP(monsterId)
    self:EnsureLoaded()
    local definition=MonsterConfig.Definitions[monsterId]
    if not definition then return nil end
    return config.MonsterXP[monsterId] or definition.ExperienceReward
end

function BalanceService:Snapshot()
    self:EnsureLoaded()
    local required={}
    for level=1,ProgressionConfig.MAX_LEVEL-1 do
        required[tostring(level)]=self:GetRequiredXP(level)
    end
    return {
        Revision=config.Revision,
        PersistenceAvailable=persistenceAvailable,
        LevelXP=required,
        LevelOverrides=table.clone(config.LevelXP),
        QuestXP={
            Starter=self:GetQuestXP("Starter"),
            Side=self:GetQuestXP("Side"),
            Main=self:GetQuestXP("Main"),
        },
        MonsterXP={ForestWolf=self:GetMonsterXP("ForestWolf")},
    }
end

local function validChange(kind, key, value)
    if kind=="LevelXP" or kind=="ResetLevelXP" then
        if type(key)~="number" or key%1~=0 or key<1 or key>=ProgressionConfig.MAX_LEVEL then
            return false, "Select a level from 1 to "..tostring(ProgressionConfig.MAX_LEVEL-1)
        end
        if kind=="ResetLevelXP" then return true end
        if not integer(value,Settings.MaxXPPerLevel) then return false,"Invalid required XP" end
        return true
    elseif kind=="QuestXP" then
        if key~="Starter" and key~="Side" and key~="Main" then return false,"Unknown quest tier" end
        if not integer(value,Settings.MaxRewardXP) then return false,"Invalid quest XP" end
        return true
    elseif kind=="MonsterXP" then
        if key~="ForestWolf" then return false,"Unknown monster type" end
        if not integer(value,Settings.MaxRewardXP) then return false,"Invalid monster XP" end
        return true
    end
    return false,"Unknown setting"
end

function BalanceService:Update(kind, key, value)
    if not self:EnsureLoaded() then return false,"DataStore unavailable: enable Studio API access or check Output" end
    local valid,reason=validChange(kind,key,value)
    if not valid then return false,reason end
    local ok, saved=pcall(function()
        return store:UpdateAsync(STORE_KEY,function(old)
            local nextValue=sanitize(old)
            if kind=="LevelXP" then
                nextValue.LevelXP[tostring(key)]=value
            elseif kind=="ResetLevelXP" then
                nextValue.LevelXP[tostring(key)]=nil
            elseif kind=="QuestXP" then
                nextValue.QuestXP[key]=value
            elseif kind=="MonsterXP" then
                nextValue.MonsterXP[key]=value
            end
            nextValue.Revision+=1
            return nextValue
        end)
    end)
    if not ok then return false,"Save failed: "..tostring(saved) end
    local nextValue=sanitize(saved)
    if nextValue.Revision>=config.Revision then
        config=nextValue
        broadcast()
    end
    task.spawn(function()
        local published,err=pcall(function() MessagingService:PublishAsync(TOPIC,config) end)
        if not published then warn("[Lumia - Balance Service] Live cross-server sync unavailable: "..tostring(err)) end
    end)
    return true,self:Snapshot()
end

function BalanceService:StartCrossServerSync()
    if self._subscribed then return end
    self._subscribed=true
    task.spawn(function()
        local ok,err=pcall(function()
            MessagingService:SubscribeAsync(TOPIC,function(message)
                local incoming=sanitize(message.Data)
                if incoming.Revision>config.Revision then
                    config=incoming
                    broadcast()
                end
            end)
        end)
        if not ok then warn("[Lumia - Balance Service] Messaging subscription unavailable: "..tostring(err)) end
    end)
end

return BalanceService
