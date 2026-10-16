-- REALMS OF LUMIA | Forgotten Forest visual atmosphere v1
-- Runs server-side so every player sees the same lighting.
-- Does not move, delete, resize, recolor or replace any Workspace parts.
local Lighting = game:GetService("Lighting")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Lumia")
    :WaitForChild("Shared"):WaitForChild("World"):WaitForChild("RPGEnvironmentConfig"))

local function applyProperties(instance, settings)
    for property, value in pairs(settings) do
        instance[property] = value
    end
end

local function managedEffect(className, name, settings)
    local effect = Lighting:FindFirstChild(name)
    if effect and not effect:IsA(className) then
        warn("[Lumia - RPG Environment] Existing " .. name .. " is not " .. className .. "; keeping it unchanged")
        return
    end
    if not effect then
        effect = Instance.new(className)
        effect.Name = name
        effect.Parent = Lighting
    end
    applyProperties(effect, settings)
    effect.Enabled = true
end

Lighting.ClockTime = Config.ClockTime
Lighting.Brightness = Config.Brightness
Lighting.ExposureCompensation = Config.ExposureCompensation
Lighting.GlobalShadows = Config.GlobalShadows
Lighting.ShadowSoftness = Config.ShadowSoftness
Lighting.Ambient = Config.Ambient
Lighting.OutdoorAmbient = Config.OutdoorAmbient
Lighting.EnvironmentDiffuseScale = Config.EnvironmentDiffuseScale
Lighting.EnvironmentSpecularScale = Config.EnvironmentSpecularScale

-- Atmosphere has no Enabled property; create/reuse just our own named instance.
local atmosphere = Lighting:FindFirstChild("LumiaForestAtmosphere")
if atmosphere and not atmosphere:IsA("Atmosphere") then
    warn("[Lumia - RPG Environment] LumiaForestAtmosphere name is occupied; atmosphere unchanged")
else
    if not atmosphere then
        atmosphere = Instance.new("Atmosphere")
        atmosphere.Name = "LumiaForestAtmosphere"
        atmosphere.Parent = Lighting
    end
    applyProperties(atmosphere, Config.Atmosphere)
end

managedEffect("ColorCorrectionEffect", "LumiaForestColors", Config.ColorCorrection)
managedEffect("BloomEffect", "LumiaForestBloom", Config.Bloom)
managedEffect("SunRaysEffect", "LumiaForestSunRays", Config.SunRays)

-- Opt-in, tag-based tree tinting for the later forest art pass.
-- Never change scale, parts, collisions, parentage, or unrelated map models.
local function styleTaggedTree(tree)
    if not Config.TreeStylingEnabled or not tree:IsDescendantOf(workspace) then
        return
    end
    for _, child in ipairs(tree:GetDescendants()) do
        if child:IsA("BasePart") then
            local name = child.Name:lower()
            if name:find("leaf", 1, true) or name:find("foliage", 1, true) then
                child.Color = child.Color:Lerp(Config.TreeLeafTint, Config.TreeTintAmount)
            elseif name:find("trunk", 1, true) or name:find("bark", 1, true) then
                child.Color = child.Color:Lerp(Config.TreeBarkTint, Config.TreeTintAmount)
            end
        end
    end
end
if Config.TreeStylingEnabled then
    for _, tree in ipairs(CollectionService:GetTagged("LumiaFantasyTree")) do
        styleTaggedTree(tree)
    end
    CollectionService:GetInstanceAddedSignal("LumiaFantasyTree"):Connect(styleTaggedTree)
end
print("[Lumia - RPG Environment] Forgotten Forest golden-hour lighting active (map geometry untouched)")
