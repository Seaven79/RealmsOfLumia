-- REALMS OF LUMIA | XP CURVE v2
-- Required XP is per-level, not cumulative. ProgressionService owns XP grants.
-- Keep rewards server-authoritative; these quest tiers are design defaults,
-- not automatic payouts until a QuestService is implemented.
local ProgressionConfig = {}

ProgressionConfig.MAX_LEVEL = 60

ProgressionConfig.XP_REQUIREMENTS = {
    [1] = 1000,
    [2] = 1800,
    [3] = 2900,
    [4] = 4300,
    [5] = 6000,
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
        6000
        + extraLevels * 1500
        + extraLevels * extraLevels * 200
    )
end

return ProgressionConfig
