-- REALMS OF LUMIA | XP CURVE v2
-- Required XP is per-level, not cumulative. ProgressionService owns XP grants.
-- Keep rewards server-authoritative; these quest tiers are design defaults,
-- not automatic payouts until a QuestService is implemented.
local ProgressionConfig = {}

ProgressionConfig.MAX_LEVEL = 60

ProgressionConfig.XP_REQUIREMENTS = {
    [1] = 1200,
    [2] = 2000,
    [3] = 3200,
    [4] = 4800,
    [5] = 6600,
}

-- Early quest XP targets for the upcoming quest service.
ProgressionConfig.QUEST_XP_REWARDS = {
    Starter = 150,
    Side = 200,
    Main = 300,
}

function ProgressionConfig.GetQuestRewardXP(tier)
    if type(tier) ~= "string" then
        return nil
    end
    return ProgressionConfig.QUEST_XP_REWARDS[tier]
end

function ProgressionConfig.GetRequiredXP(level)
    if type(level) ~= "number"
        or level ~= level
        or level % 1 ~= 0
        or level < 1
        or level >= ProgressionConfig.MAX_LEVEL then
        return nil
    end

    local configured = ProgressionConfig.XP_REQUIREMENTS[level]
    if configured then
        return configured
    end

    local extraLevels = level - 5

    return math.floor(
        6600
        + extraLevels * 1800
        + extraLevels * extraLevels * 250
    )
end

return ProgressionConfig
