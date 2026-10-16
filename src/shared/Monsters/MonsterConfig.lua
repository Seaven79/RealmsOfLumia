local MonsterConfig = {}

MonsterConfig.Definitions = {
    ThornboundGuardian = {
        DisplayName = "Thornbound Guardian", ModelId = "ForestWolf",
        Level = 5, AggroType = "Aggressive", MaxHealth = 6400, Damage = 20,
        WanderRadius = 3, DetectionRadius = 35, ChaseLimit = 28,
        AttackRange = 5.8, AttackCooldown = 2.7, WalkSpeed = 6, ChaseSpeed = 9,
        RespawnDelay = 60, ExperienceReward = 0, GoldReward = 0,
    },
    DireForestWolf = {
        DisplayName = "Thornwatch Dire Wolf", ModelId = "ForestWolf",
        Level = 4, AggroType = "Aggressive", MaxHealth = 185, Damage = 22,
        WanderRadius = 6, DetectionRadius = 11, ChaseLimit = 20,
        AttackRange = 4.5, AttackCooldown = 2.1, WalkSpeed = 8, ChaseSpeed = 13,
        RespawnDelay = 22, ExperienceReward = 15, GoldReward = 4,
    },
    GatewatchWolf = {
        DisplayName = "Gatewatch Alpha", ModelId = "ForestWolf",
        Level = 5, AggroType = "Aggressive", MaxHealth = 280, Damage = 26,
        WanderRadius = 7, DetectionRadius = 12, ChaseLimit = 22,
        AttackRange = 4.5, AttackCooldown = 2.1, WalkSpeed = 9, ChaseSpeed = 14,
        RespawnDelay = 25, ExperienceReward = 17, GoldReward = 7,
    },

    ForestWolf = {
        DisplayName = "Forest Wolf",
        Level = 1,
        AggroType = "Aggressive",

        MaxHealth = 65,
        Damage = 9,

        WanderRadius = 6,
        DetectionRadius = 8,
        ChaseLimit = 20,
        AttackRange = 4,
        AttackCooldown = 2,

        WalkSpeed = 8,
        ChaseSpeed = 13,
        RespawnDelay = 15,

        ExperienceReward = 7, -- Quest turn-ins, not grinding, drive the campaign.
        GoldReward = 2,
    },
}

return MonsterConfig