-- REALMS OF LUMIA - PLAYER HURT AUDIO v1.0
-- Locally plays a short grunt when the player's Humanoid loses health.
-- Works for wolf attacks and future damage sources; never grants damage.
-- Uses one Sound and one health listener per character (no duplicate voices).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local ContentProvider = game:GetService("ContentProvider")

local player = Players.LocalPlayer
local config = require(ReplicatedStorage:WaitForChild("Lumia")
    :WaitForChild("Shared"):WaitForChild("Players")
    :WaitForChild("PlayerHurtAudioConfig"))

local grunt = Instance.new("Sound")
grunt.Name = "LumiaPlayerHurtGrunt"
grunt.SoundId = config.SoundId
grunt.Volume = config.Volume
grunt.PlaybackSpeed = config.PlaybackSpeed
grunt.Looped = false
grunt.Parent = SoundService

task.spawn(function()
    pcall(function()
        ContentProvider:PreloadAsync({grunt})
    end)
end)

local healthConnection
local lastPlayed = -math.huge
local characterVersion = 0

local function onCharacterAdded(character)
    characterVersion += 1
    local myVersion = characterVersion
    if healthConnection then
        healthConnection:Disconnect()
        healthConnection = nil
    end
    grunt:Stop()
    local humanoid = character:WaitForChild("Humanoid", 10)
    if not humanoid or characterVersion ~= myVersion then return end

    local previousHealth = humanoid.Health
    healthConnection = humanoid.HealthChanged:Connect(function(health)
        local damage = previousHealth - health
        previousHealth = health
        if damage < config.MinDamage then return end
        if health <= 0 and not config.PlayOnDeath then return end

        local now = os.clock()
        if now - lastPlayed < config.MinInterval then return end
        lastPlayed = now
        grunt:Stop()
        grunt.TimePosition = 0
        grunt:Play()
    end)
end

player.CharacterAdded:Connect(onCharacterAdded)
if player.Character then task.defer(onCharacterAdded, player.Character) end