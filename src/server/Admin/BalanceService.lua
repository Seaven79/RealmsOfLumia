-- REALMS OF LUMIA | Server-authoritative, persisted progression balance.
-- Does not change player records. One settings record per Roblox experience.
-- Quest reward tiers are stored now for use by the future QuestService.
local DataStoreService = game:GetService("DataStoreService")
local MessagingService = game:GetService("MessagingService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Lumia"):WaitForChild("Shared")
local ProgressionConfig = require(Shared:WaitForChild("Progression"):WaitForChild("ProgressionConfig"))
local MonsterConfig = require(Shared:WaitForChild("Monsters"):WaitForChild("MonsterConfig"))
local QuestConfig = require(Shared:WaitForChild("Quests"):WaitForChild("QuestConfig"))
local GlobalTuning = require(Shared:WaitForChild("Admin"):WaitForChild("GlobalTuning"))
local GearCatalog = require(Shared:WaitForChild("Commerce"):WaitForChild("GearCatalog"))
local GearCurve = require(Shared:WaitForChild("Commerce"):WaitForChild("GearCurve"))
local Settings = require(script.Parent:WaitForChild("BalanceSettings"))
local CurveLab = require(script.Parent:WaitForChild("CurveLabService"))

local BalanceService = {}
BalanceService.Changed = Instance.new("BindableEvent")
BalanceService.Loaded = Instance.new("BindableEvent")
local store = DataStoreService:GetDataStore("RealmsOfLumia_Balance_" .. tostring(game.GameId))
local STORE_KEY = "SharedBalance_v1"
local TOPIC = "LumiaBalance_v1"
local loaded = false
local loading = false
local persistenceAvailable = false
local config = {
    Revision = 0, LevelXP = {}, QuestXP = {}, MonsterXP = {},
    QuestRewardXP = {}, QuestRewardGold = {},
    Global = GlobalTuning.Defaults(),
}

-- Quest ids are validated against the real content table so an override can
-- never target a quest that does not exist.
local questById = {}
for _, quest in ipairs(QuestConfig.Quests) do
    questById[quest.Id] = quest
end

local function integer(value, upper)
    return type(value)=="number" and value==value and value%1==0 and value>=Settings.MinXP and value<=upper
end

local function sanitize(record)
    local result = {
        Revision = 0, LevelXP = {}, QuestXP = {}, MonsterXP = {},
        QuestRewardXP = {}, QuestRewardGold = {},
        Global = GlobalTuning.Normalize(record and record.Global),
    }
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
        for monsterId in pairs(MonsterConfig.Definitions) do
            local value=record.MonsterXP[monsterId]
            if integer(value,Settings.MaxRewardXP) then result.MonsterXP[monsterId]=value end
        end
    end
    for questId in pairs(questById) do
        if type(record.QuestRewardXP)=="table" then
            local value=record.QuestRewardXP[questId]
            if integer(value,Settings.MaxRewardXP) then result.QuestRewardXP[questId]=value end
        end
        if type(record.QuestRewardGold)=="table" then
            local value=record.QuestRewardGold[questId]
            if integer(value,Settings.MaxRewardXP) then result.QuestRewardGold[questId]=value end
        end
    end
    return result
end

-- Publishes the active template so the shared GearCurve layer derives gear numbers
-- from it on every client and on the server. MatchPreset returns nil for hand-tuned
-- dial sets; the neutral template is the correct shape in that case.
local function publishGearTemplate()
    local folder = ReplicatedStorage:FindFirstChild("Lumia")
    if not folder then return end
    local preset = nil
    local ok, matched = pcall(function()
        return BalanceService:GetGlobalPreset()
    end)
    if ok and type(matched) == "string" then preset = matched end
    if not preset or GearCurve.Templates[preset] == nil then
        preset = GearCurve.DefaultTemplate
    end
    if folder:GetAttribute(GearCurve.AttributeName) ~= preset then
        folder:SetAttribute(GearCurve.AttributeName, preset)
    end
end

local function broadcast()
    publishGearTemplate()
    BalanceService.Changed:Fire()
end

function BalanceService:EnsureLoaded()
    if loaded then return persistenceAvailable end
    if loading then
        BalanceService.Loaded.Event:Wait()
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
    BalanceService.Loaded:Fire()
    broadcast()
    return persistenceAvailable
end

function BalanceService:GetBaseRequiredXP(level)
    self:EnsureLoaded()
    if type(level)~="number" then return nil end
    return config.LevelXP[tostring(level)] or ProgressionConfig.GetRequiredXP(level)
end

function BalanceService:GetRequiredXP(level)
    -- EFFECTIVE value: authoring base x level-pace dial, then the published
    -- curve factor. ProgressionService levels players with this number.
    local baseline = self:GetBaseRequiredXP(level)
    if not baseline then return nil end
    local pace = self:GetGlobal("LevelPace")
    return CurveLab:Adjust("LevelXP", level, baseline * pace, Settings.MaxXPPerLevel)
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

-- Per-quest reward resolution. An admin override wins; otherwise the quest
-- table itself is the source of truth. QuestService pays through these so the
-- panel edits a value the player actually receives.
function BalanceService:GetQuestRewardXP(questId)
    self:EnsureLoaded()
    local override = config.QuestRewardXP[questId]
    if override then return override end
    local quest = questById[questId]
    return quest and tonumber(quest.XP) or nil
end

function BalanceService:GetQuestRewardGold(questId)
    self:EnsureLoaded()
    local override = config.QuestRewardGold[questId]
    if override then return override end
    local quest = questById[questId]
    return quest and tonumber(quest.Gold) or nil
end

function BalanceService:GetBaseRequiredXPForPanel(level)
    self:EnsureLoaded()
    return config.LevelXP[tostring(level)] or ProgressionConfig.GetRequiredXP(level)
end

--------------------------------------------------------------------------------
-- GLOBAL DIALS
-- Authoring values above stay untouched. These multipliers are applied when the
-- game reads a value, so presets can be applied repeatedly with no drift.
--------------------------------------------------------------------------------

function BalanceService:GetGlobal(dialId)
    self:EnsureLoaded()
    local dial = GlobalTuning.ById[dialId]
    if not dial then return 1 end
    local value = config.Global[dialId]
    if type(value) ~= "number" then return dial.Default end
    return math.clamp(value, dial.Min, dial.Max)
end

function BalanceService:GetGlobalValues()
    self:EnsureLoaded()
    local values = {}
    for _, dial in ipairs(GlobalTuning.Dials) do
        values[dial.Id] = self:GetGlobal(dial.Id)
    end
    return values
end

function BalanceService:GetGlobalPreset()
    return GlobalTuning.MatchPreset(self:GetGlobalValues())
end

function BalanceService:SetGlobal(dialId, value)
    if not self:EnsureLoaded() then
        return false, "DataStore unavailable: enable Studio API access or check Output"
    end
    local ok, reason = GlobalTuning.Validate(dialId, value)
    if not ok then return false, reason end
    return self:Update("Global", dialId, value)
end

-- Writes every dial in ONE transaction. Two rapid preset clicks therefore
-- cannot interleave and leave a half-applied preset behind.
function BalanceService:ApplyPreset(presetId)
    if not self:EnsureLoaded() then
        return false, "DataStore unavailable: enable Studio API access or check Output"
    end
    local preset = GlobalTuning.GetPreset(presetId)
    if not preset then return false, "Unknown preset: " .. tostring(presetId) end

    local ok, saved = pcall(function()
        return store:UpdateAsync(STORE_KEY, function(old)
            local nextValue = sanitize(old)
            for dialId, value in pairs(preset.Values) do
                nextValue.Global[dialId] = value
            end
            nextValue.Revision += 1
            return nextValue
        end)
    end)
    if not ok then return false, "Save failed: " .. tostring(saved) end

    local nextValue = sanitize(saved)
    if nextValue.Revision >= config.Revision then
        config = nextValue
        broadcast()
    end
    task.spawn(function()
        local published, err = pcall(function()
            MessagingService:PublishAsync(TOPIC, config)
        end)
        if not published then
            warn("[Lumia - Balance Service] Live cross-server sync unavailable: " .. tostring(err))
        end
    end)
    return true, self:Snapshot()
end

--------------------------------------------------------------------------------
-- EFFECTIVE reward values (authoring x dial)
--------------------------------------------------------------------------------

function BalanceService:GetMonsterRewardXP(monsterId)
    local base = self:GetMonsterXP(monsterId)
    if not base then return nil end
    local scaled = base * self:GetGlobal("MobRewards")
    return math.max(1, math.floor(scaled + 0.5))
end

function BalanceService:GetMonsterGold(monsterId)
    local definition = MonsterConfig.Definitions[monsterId]
    if not definition then return nil end
    return tonumber(definition.GoldReward) or 0
end

function BalanceService:GetMonsterRewardGold(monsterId)
    local base = self:GetMonsterGold(monsterId)
    if not base then return nil end
    local scaled = base * self:GetGlobal("MobRewards")
    return math.max(0, math.floor(scaled + 0.5))
end

function BalanceService:GetEffectiveQuestRewardXP(questId)
    local base = self:GetQuestRewardXP(questId)
    if not base then return nil end
    local scaled = base * self:GetGlobal("QuestRewards")
    return math.max(0, math.floor(scaled + 0.5))
end

function BalanceService:GetEffectiveQuestRewardGold(questId)
    local base = self:GetQuestRewardGold(questId)
    if not base then return nil end
    local scaled = base * self:GetGlobal("QuestRewards")
    return math.max(0, math.floor(scaled + 0.5))
end

--------------------------------------------------------------------------------
-- PREVIEW: what the current dials do to a real monster, before you play.
--------------------------------------------------------------------------------

function BalanceService:PreviewTuning()
    local rows = {}
    local sample = { "ForestWolf", "StoneboundWolf", "DireForestWolf", "ThornboundGuardian" }
    local difficulty = self:GetGlobal("Difficulty")
    local bossScale = self:GetGlobal("BossScale")
    local power = self:GetGlobal("PlayerDamage")

    for _, monsterId in ipairs(sample) do
        local definition = MonsterConfig.Definitions[monsterId]
        if definition then
            local isBoss = definition.IsBoss == true
            local scale = isBoss and bossScale or difficulty
            local health = math.max(1, math.floor(definition.MaxHealth * scale + 0.5))

            -- Reference loadout: that tier's shop sword plus the level's innate
            -- attack. Mirrors CombatStats so the hit count is not a guess.
            local level = math.clamp(tonumber(definition.Level) or 1, 1, 5)
            local weaponId = string.format("Lumia%dSword", level)
            local weapon = GearCatalog.Items[weaponId]
            local attackStat = math.floor(5 * 0.4) + math.floor((level - 1) * 1.8)
            local perHit = weapon
                and math.max(1, math.floor((weapon.Damage + attackStat) * power + 0.5)) or 0
            local defenseFactor = math.clamp(CurveLab:GetDefenseFactor(level), 0.25, 8)
            local effectiveHit = math.max(1, math.round(perHit / defenseFactor))

            rows[#rows + 1] = {
                Id = monsterId,
                Name = definition.DisplayName or monsterId,
                IsBoss = isBoss,
                BaseHealth = definition.MaxHealth,
                Health = health,
                BaseDamage = definition.Damage,
                Damage = math.max(0, math.floor(definition.Damage * scale + 0.5)),
                BaseXP = self:GetMonsterXP(monsterId),
                XP = self:GetMonsterRewardXP(monsterId),
                BaseGold = self:GetMonsterGold(monsterId),
                Gold = self:GetMonsterRewardGold(monsterId),
                Scale = scale,
                HitDamage = effectiveHit,
                HitsToKill = perHit > 0 and math.ceil(health / effectiveHit) or 0,
            }
        end
    end
    return rows
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
        MonsterXP=table.clone(config.MonsterXP),
        QuestRewardXP=table.clone(config.QuestRewardXP),
        QuestRewardGold=table.clone(config.QuestRewardGold),
        Global=self:GetGlobalValues(),
        GlobalPreset=self:GetGlobalPreset(),
        Preview=self:PreviewTuning(),
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
    elseif kind=="MonsterXP" or kind=="ResetMonsterXP" then
        if type(key)~="string" or not MonsterConfig.Definitions[key] then
            return false,"Unknown monster type"
        end
        if kind=="ResetMonsterXP" then return true end
        if not integer(value,Settings.MaxRewardXP) then return false,"Invalid monster XP" end
        return true
    elseif kind=="QuestRewardXP" or kind=="ResetQuestRewardXP"
        or kind=="QuestRewardGold" or kind=="ResetQuestRewardGold" then
        if type(key)~="string" or not questById[key] then return false,"Unknown quest id" end
        if kind=="ResetQuestRewardXP" or kind=="ResetQuestRewardGold" then return true end
        if not integer(value,Settings.MaxRewardXP) then return false,"Invalid quest reward" end
        return true
    elseif kind=="Global" then
        local ok, reason = GlobalTuning.Validate(key, value)
        if not ok then return false, reason end
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
            elseif kind=="ResetMonsterXP" then
                nextValue.MonsterXP[key]=nil
            elseif kind=="QuestRewardXP" then
                nextValue.QuestRewardXP[key]=value
            elseif kind=="ResetQuestRewardXP" then
                nextValue.QuestRewardXP[key]=nil
            elseif kind=="QuestRewardGold" then
                nextValue.QuestRewardGold[key]=value
            elseif kind=="ResetQuestRewardGold" then
                nextValue.QuestRewardGold[key]=nil
            elseif kind=="Global" then
                nextValue.Global[key]=value
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

-- Refresh player XP bar when a temporary curve test starts/stops.
CurveLab.Changed.Event:Connect(function()
    BalanceService.Changed:Fire()
end)

return BalanceService
