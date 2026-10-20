local MonsterConfig = {}

MonsterConfig.Definitions = {
    ThornboundGuardian = {
        DisplayName = "Thornbound Guardian", ModelId = "ForestWolf",
        -- Bosses are excluded from the global Difficulty dial; they use BossScale.
        IsBoss = true,
        Level = 5, AggroType = "Aggressive", MaxHealth = 6400, Damage = 45,
        WanderRadius = 3, DetectionRadius = 35, ChaseLimit = 28,
        AttackRange = 5.8, AttackCooldown = 2.7, WalkSpeed = 6, ChaseSpeed = 9,
        RespawnDelay = 60, ExperienceReward = 600, GoldReward = 250,
    },
    ThornboundWhelp = {
   DisplayName = "Thornbound Whelp", ModelId = "ForestWolf",
   -- Phase-two adds for the Guardian fight: fast, fragile, meant to be cleared.
   Level = 5, AggroType = "Aggressive", MaxHealth = 300, Damage = 15,
   WanderRadius = 2, DetectionRadius = 44, ChaseLimit = 48,
   AttackRange = 4.2, AttackCooldown = 1.5, WalkSpeed = 12, ChaseSpeed = 16,
   RespawnDelay = 5, ExperienceReward = 12, GoldReward = 2,
   },
   DireForestWolf = {
        DisplayName = "Thornwatch Dire Wolf", ModelId = "ForestWolf",
        Level = 4, AggroType = "Aggressive", MaxHealth = 470, Damage = 30,
        WanderRadius = 6, DetectionRadius = 13, ChaseLimit = 40,
        AttackRange = 4.5, AttackCooldown = 2.1, WalkSpeed = 8, ChaseSpeed = 13,
        RespawnDelay = 22, ExperienceReward = 65, GoldReward = 10,
    },
    GatewatchWolf = {
        DisplayName = "Gatewatch Alpha", ModelId = "ForestWolf",
        Level = 5, AggroType = "Aggressive", MaxHealth = 490, Damage = 34,
        WanderRadius = 7, DetectionRadius = 14, ChaseLimit = 44,
        AttackRange = 4.5, AttackCooldown = 2.1, WalkSpeed = 9, ChaseSpeed = 14,
        RespawnDelay = 25, ExperienceReward = 85, GoldReward = 13,
    },

    OldRoadStalker = {
        DisplayName="Roadside Stalker", ModelId="ForestWolf", Level=2,
        AggroType="Aggressive", MaxHealth=220, Damage=16,
        WanderRadius=5, DetectionRadius=11, ChaseLimit=38,
        AttackRange=4.1, AttackCooldown=2.4, WalkSpeed=7, ChaseSpeed=12,
        RespawnDelay=22, ExperienceReward=30, GoldReward=5,
    },
    CreekFenWolf = {
        DisplayName="Creek Fen Wolf", ModelId="ForestWolf", Level=3,
        AggroType="Aggressive", MaxHealth=290, Damage=20,
        WanderRadius=6, DetectionRadius=12, ChaseLimit=42,
        AttackRange=4.4, AttackCooldown=2.4, WalkSpeed=8, ChaseSpeed=12,
        RespawnDelay=25, ExperienceReward=42, GoldReward=6,
    },
    StoneboundWolf = {
        DisplayName="Stonebound Watcher", ModelId="ForestWolf", Level=4,
        AggroType="Aggressive", MaxHealth=350, Damage=26,
        WanderRadius=5, DetectionRadius=12, ChaseLimit=40,
        AttackRange=4.4, AttackCooldown=2.5, WalkSpeed=7, ChaseSpeed=11,
        RespawnDelay=28, ExperienceReward=55, GoldReward=8,
    },
    ForestWolf = {
        DisplayName = "Forest Wolf",
        Level = 1,
        AggroType = "Aggressive",

        MaxHealth = 160,
        Damage = 12,

        WanderRadius = 6,
        DetectionRadius = 12,
        ChaseLimit = 40,
        AttackRange = 4,
        AttackCooldown = 2,

        WalkSpeed = 8,
        ChaseSpeed = 13,
        RespawnDelay = 15,

        ExperienceReward = 22, -- Quest turn-ins, not grinding, drive the campaign.
        GoldReward = 4,
    },
}

return MonsterConfig