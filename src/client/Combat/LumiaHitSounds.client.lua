-- REALMS OF LUMIA - CONFIRMED MELEE IMPACT AUDIO v1.1
-- Plays an IMPACT ONLY on SwordHit, emitted after server damage validation.
-- Swing audio belongs to SwordCombat.client.lua and is always independent.
-- Roblox client asset preloading helps avoid delayed first-hit playback.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ContentProvider = game:GetService("ContentProvider")
local SoundService = game:GetService("SoundService")
local Debris = game:GetService("Debris")

local AudioConfig = require(ReplicatedStorage:WaitForChild("Lumia")
    :WaitForChild("Shared"):WaitForChild("Combat"):WaitForChild("CombatAudioConfig"))
local network = ReplicatedStorage:WaitForChild("Lumia"):WaitForChild("CombatNetwork")
local hitRemote = network:WaitForChild("SwordHit")
local soundRandom = Random.new()

-- Prepare a sound once per player client rather than wait until the first hit.
local hitTemplate = Instance.new("Sound")
hitTemplate.Name = "LumiaHitPreloaded"
hitTemplate.SoundId = AudioConfig.HitSoundId
hitTemplate.Volume = AudioConfig.HitVolume
hitTemplate.RollOffMode = Enum.RollOffMode.Inverse
hitTemplate.RollOffMinDistance = AudioConfig.RollOffMinDistance
hitTemplate.RollOffMaxDistance = AudioConfig.RollOffMaxDistance
hitTemplate.Parent = SoundService

task.spawn(function()
    local ok, err = pcall(function()
        ContentProvider:PreloadAsync({ hitTemplate }, function(id, status)
            if status ~= Enum.AssetFetchStatus.Success then
                warn("[Lumia - Lumia Hit Sounds] Impact audio not available: " .. tostring(id)
                    .. " (" .. status.Name .. "). Choose an accessible ID in CombatAudioConfig.")
            end
        end)
    end)
    if not ok then
        warn("[Lumia - Lumia Hit Sounds] Impact audio preload error: " .. tostring(err))
    end
end)

hitRemote.OnClientEvent:Connect(function(creature, damage)
    if typeof(creature) ~= "Instance" or not creature:IsA("Model") then return end
    if type(damage) ~= "number" or damage <= 0 then return end
    local root = creature:FindFirstChild("HumanoidRootPart")
    if not root or not root:IsA("BasePart") then return end

    -- This sound is new on every confirmed hit so rapid impacts can overlap.
    -- Its content is already cached via hitTemplate.
    local sound = hitTemplate:Clone()
    sound.Name = "LumiaConfirmedMeleeHit"
    sound.PlaybackSpeed = soundRandom:NextNumber(0.97, 1.03)
    sound.Parent = root
    sound:Play()
    Debris:AddItem(sound, 3)
end)

print("[Lumia - Lumia Hit Sounds] Separate whoosh + confirmed impact audio ready")