local MonsterConfig = {}

MonsterConfig.Definitions = {
    ForestWolf = {
        DisplayName = "Forest Wolf",
        Level = 1,
        AggroType = "Aggressive",

        MaxHealth = 65,
        Damage = 5,

        WanderRadius = 6,
        DetectionRadius = 8,
        ChaseLimit = 20,
        AttackRange = 4,
        AttackCooldown = 2,

        WalkSpeed = 8,
        ChaseSpeed = 13,
        RespawnDelay = 15,

        ExperienceReward = 25,
        GoldReward = 2,
    },
}

return MonsterConfig