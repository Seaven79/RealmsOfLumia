-- REALMS OF LUMIA - SHARED COMBAT AUDIO CONFIG v1.1
-- Tune sound asset IDs and cosmetic timing here. This does not grant damage.
-- Impact audio is a Creator Store sound effect. If Studio reports an
-- audio-permission error, replace it with an accessible sound asset ID.

local CombatAudioConfig = {
    SwingSoundId = "rbxasset://sounds/swordslash.wav",
    HitSoundId = "rbxassetid://7171761940", -- Sword Hit (Impact), Creator Store

    SwingVolume = 0.58,
    HitVolume = 0.78,

    -- The existing procedural animation lasts 0.46 seconds.
    -- Wind-up is 0%-28%, cutting movement 28%-72%, recovery 72%-100%.
    SwingDuration = 0.46,
    WhooshPhase = 0.29,
    TrailStartPhase = 0.28,
    TrailEndPhase = 0.72,

    RollOffMinDistance = 8,
    RollOffMaxDistance = 55,
}

return CombatAudioConfig