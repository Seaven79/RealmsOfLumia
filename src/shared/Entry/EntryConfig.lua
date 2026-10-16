-- REALMS OF LUMIA - ENTRY EXPERIENCE CONFIG v1
-- Shared, data-only configuration. Replace story text/art later without modifying services.
return {
    Version = 2,
    EnableEntryUI = false, -- v7: temporarily disable cinematic/welcome/loading UI, keep server entry bridge.

    ProductName = "REALMS OF LUMIA",
    Subtitle = "THE FIRST GATE",
    ShowStoryForReturningPlayers = false,
    ProtectCharacterUntilEntry = true,
    LoadingTimeout = 60,
    PollInterval = 0.65,
    -- Optional owned, moderated Roblox image IDs, e.g. "rbxassetid://1234".
    -- Empty values render a self-contained procedural background.
    BackgroundImage = "",
    IntroSlides = {
        {
            Eyebrow = "THE AGE OF SHADOWS",
            Heading = "The forest remembers.",
            Body = "An ancient gate has slept beyond the forest for generations. Its guardian will awaken only when two adventurers stand together.",
        },
        {
            Eyebrow = "THE FIRST ADVENTURE",
            Heading = "Every legend begins somewhere.",
            Body = "Begin in the village, learn the paths, help its people, and grow from a new adventurer into a defender of Lumia.",
        },
        {
            Eyebrow = "THE CALL TO ARMS",
            Heading = "You will not face it alone.",
            Body = "Reach level five, prepare your equipment, and join a trusted companion to challenge the Thornbound Guardian at the First Gate.",
        },
    },
}
