-- REALMS OF LUMIA - ZONE MUSIC CONFIG v1.0
-- All zone music settings live here for simple future expansion.
-- Upload The_Forgotten_Forest_Living_Piano_Full_Loop.wav to Roblox to obtain an Audio Asset ID.
-- Replace only the AssetId for ForgottenForest; a value of 0 disables playback.

return {
    Enabled = true,
    StartingZoneId = "ForgottenForest",
    Tracks = {
        ForgottenForest = {
            AssetId = "rbxassetid://116378882206513",
            Volume = 0.24,      -- Keep voice, sword and wolf effects audible.
            FadeInSeconds = 2.0,
            Looped = true,
        },
        -- Add other zones here later. Zone transitions are not implemented yet.
    },
}