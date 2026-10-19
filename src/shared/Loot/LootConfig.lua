-- REALMS OF LUMIA - LOOT CONFIG v1
-- All drops are ordinary free in-game rewards; no purchases or Robux.
-- Add monster entries without rewriting the loot UI or bag service.
return {
    OpenDistance = 12,
    HitCreditLifetimeSeconds = 10,
    Monsters = {
        OldRoadStalker = {DropCount=1, Drops={
            {ItemId="WolfTornFur",Weight=50},{ItemId="WolfBrokenFang",Weight=30},
            {ItemId="WolfMattedHide",Weight=20},
        }},
        CreekFenWolf = {DropCount=1, Drops={
            {ItemId="WolfTornFur",Weight=25},{ItemId="WolfMattedHide",Weight=45},
            {ItemId="WolfDullClaw",Weight=30},
        }},
        StoneboundWolf = {DropCount=2, Drops={
            {ItemId="WolfBrokenFang",Weight=30},{ItemId="WolfMattedHide",Weight=25},
            {ItemId="WolfDullClaw",Weight=45},
        }},
        ThornboundGuardian = {DropCount=2,Drops={{ItemId="WolfDullClaw",Weight=40},{ItemId="WolfBrokenFang",Weight=60}}},
        DireForestWolf = {
            DropCount = 1,
            Drops = {
                { ItemId = "WolfTornFur", Weight = 40 },
                { ItemId = "WolfBrokenFang", Weight = 30 },
                { ItemId = "WolfMattedHide", Weight = 20 },
                { ItemId = "WolfDullClaw", Weight = 10 },
            },
        },
        GatewatchWolf = {
            DropCount = 2,
            Drops = {
                { ItemId = "WolfTornFur", Weight = 20 },
                { ItemId = "WolfBrokenFang", Weight = 30 },
                { ItemId = "WolfMattedHide", Weight = 25 },
                { ItemId = "WolfDullClaw", Weight = 25 },
            },
        },

        ForestWolf = {
            DropCount = 1,
            -- Weighted random selection; always one gray item for easy testing.
            Drops = {
                { ItemId = "WolfTornFur", Weight = 40 },
                { ItemId = "WolfBrokenFang", Weight = 30 },
                { ItemId = "WolfMattedHide", Weight = 20 },
                { ItemId = "WolfDullClaw", Weight = 10 },
            },
        },
    },
}