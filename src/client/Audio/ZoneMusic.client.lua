-- REALMS OF LUMIA - ZONE MUSIC CLIENT v1.0
-- One local music controller for the player's game session.
-- Starts Forgotten Forest music when the player joins; runs independently of character respawns.
-- Zone changes, crossfading and music options can be added here later without changing combat.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local config = require(ReplicatedStorage:WaitForChild("Lumia")
    :WaitForChild("Shared"):WaitForChild("Audio"):WaitForChild("ZoneMusicConfig"))

if not config.Enabled then
    return
end

local track = config.Tracks[config.StartingZoneId]
if not track then
    warn("[Lumia - Zone Music] Starting zone has no soundtrack: " .. tostring(config.StartingZoneId))
    return
end

local numericId = tostring(track.AssetId or ""):match("^rbxassetid://(%d+)$")
if not numericId or numericId == "0" then
    warn("[Lumia - Zone Music] No Roblox audio ID configured. Import the WAV and rerun the music installer with -AudioId.")
    return
end

-- Music lives in SoundService: same volume throughout the world (not 3D positional audio).
local sound = SoundService:FindFirstChild("LumiaZoneBackgroundMusic")
if sound and not sound:IsA("Sound") then
    warn("[Lumia - Zone Music] SoundService.LumiaZoneBackgroundMusic is not a Sound.")
    return
end
if not sound then
    sound = Instance.new("Sound")
    sound.Name = "LumiaZoneBackgroundMusic"
    sound.Parent = SoundService
else
    sound:Stop()
end

sound.SoundId = "rbxassetid://" .. numericId
sound.Looped = (track.Looped ~= false)
sound.Volume = 0
sound.PlaybackSpeed = 1
sound:Play()

local targetVolume = math.clamp(tonumber(track.Volume) or 0.24, 0, 1)
local fadeSeconds = math.max(0, tonumber(track.FadeInSeconds) or 2)

local function fadeIn()
    if not sound.Parent then return end
    if fadeSeconds == 0 then
        sound.Volume = targetVolume
        return
    end
    local tween = TweenService:Create(sound,
        TweenInfo.new(fadeSeconds, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
        {Volume = targetVolume})
    tween:Play()
end

if sound.IsLoaded then
    fadeIn()
else
    -- Fade only once the audio becomes available, not during a network-loading pause.
    task.spawn(function()
        local deadline = os.clock() + 15
        while sound.Parent and not sound.IsLoaded and os.clock() < deadline do
            task.wait(0.15)
        end
        if sound.IsLoaded then
            fadeIn()
        else
            warn("[Lumia - Zone Music] Audio did not load in 15 seconds. Verify asset ID, moderation and experience permissions.")
        end
    end)
end

print("[Lumia - Zone Music] Forgotten Forest soundtrack configured: " .. sound.SoundId)