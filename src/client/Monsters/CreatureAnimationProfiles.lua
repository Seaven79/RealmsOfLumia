-- REALMS OF LUMIA - CLIENT CREATURE ANIMATION PROFILES
-- Each entry maps a CREATURE RIG (not a player avatar rig) to joint names.
-- This design does not depend on Roblox R6 or R15 and accepts later custom rigs.
-- A monster can select a profile with its LumiaAnimationRig attribute;
-- otherwise the MonsterId attribute is used.
-- Add a NEW profile for future rigs without editing MonsterAI.

local Profiles = {
    ForestWolf = {
        Joints = {
            FrontLeft = "FrontLeftLegJoint",
            FrontRight = "FrontRightLegJoint",
            RearLeft = "RearLeftLegJoint",
            RearRight = "RearRightLegJoint",
            FrontLeftPaw = "FrontLeftPawJoint",
            FrontRightPaw = "FrontRightPawJoint",
            RearLeftPaw = "RearLeftPawJoint",
            RearRightPaw = "RearRightPawJoint",
            Neck = "NeckJoint",
            Muzzle = "MuzzleJoint",
            Tail = "TailJoint",
        },
        Walk = {
            Frequency = 1.5,       -- complete gait cycles per second
            LegPitch = 0.55,      -- radians
            PawPitch = 0.28,
            HeadPitch = 0.06,
            TailYaw = 0.12,
            MinSpeed = 0.5,
        },
        -- Skill wind-ups. The client plays these while the server telegraphs, so the
        -- body commits to the attack before the effect lands.
        Cast = {
            Slam = {
                NeckPitch = -0.5, MuzzlePitch = -0.22,
                FrontLegPitch = -0.32, RearLegPitch = 0.26, TailPitch = 0.34,
            },
            Fireball = {
                NeckPitch = 0.34, MuzzlePitch = 0.46,
                FrontLegPitch = 0.12, RearLegPitch = -0.16, TailPitch = -0.26,
            },
        },
        Attack = {
            Duration = 0.45,     -- seconds; purely visual
            FrontLegPitch = 0.55,
            RearLegPitch = 0.21,
            HeadPitch = 0.34,
            MuzzlePitch = 0.17,
            TailPitch = 0.13,
        },
    },
}

return Profiles
