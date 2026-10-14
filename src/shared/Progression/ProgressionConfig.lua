local ProgressionConfig = {}

ProgressionConfig.MAX_LEVEL = 60

ProgressionConfig.XP_REQUIREMENTS = {
    [1] = 400,
    [2] = 800,
    [3] = 1400,
    [4] = 2200,
}

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

    local extraLevels = level - 4

    return math.floor(
        2200
        + extraLevels * 600
        + extraLevels * extraLevels * 100
    )
end

return ProgressionConfig