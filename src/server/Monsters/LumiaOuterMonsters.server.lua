-- REALMS OF LUMIA V15 - OUTER REGION ENCOUNTERS
-- Uses original ForestWolf rig with server-tuned levels 4 / 5.
-- Player-proximity activation; no edits to the original forest spawn population.
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local Service = require(script.Parent:WaitForChild("MonsterService"))
local folder = Workspace:WaitForChild("LumiaOpenWorldV15", 45)
local points = folder and folder:WaitForChild("OuterMonsterAnchors", 35)
if not points then
    warn("[Lumia V15] No expansion ground; outer monster spawner skipped")
    return
end
local live = {}
local function near(position, radius)
    for _, player in ipairs(Players:GetPlayers()) do
        local c = player.Character
        local h = c and c:FindFirstChildOfClass("Humanoid")
        local root = c and c:FindFirstChild("HumanoidRootPart")
        if root and h and h.Health > 0 and (root.Position-position).Magnitude <= radius then
            return true
        end
    end
    return false
end
local function monsterId(anchor)
    if anchor:GetAttribute("ZoneId") == "ThornwatchGlade" then
        return "DireForestWolf"
    end
    return "GatewatchWolf"
end
local function addAppearance(model, zone)
    local color = zone == "ThornwatchGlade"
        and Color3.fromRGB(116, 155, 91) or Color3.fromRGB(102, 171, 185)
    local highlight = Instance.new("Highlight")
    highlight.Name = "LumiaEliteMark"
    highlight.FillColor = color
    highlight.OutlineColor = color
    highlight.FillTransparency = 0.9
    highlight.OutlineTransparency = 0.55
    highlight.Parent = model
end
task.wait(4)
for _, anchor in ipairs(points:GetChildren()) do
    if anchor:IsA("BasePart") then
        live[anchor] = {Model=nil, Next=0}
    end
end
while folder.Parent do
    for anchor, entry in pairs(live) do
        local monster = entry.Model
        if monster and not monster.Parent then
            local factor = tonumber(monster:GetAttribute("LumiaRespawnFactor")) or 1
            entry.Model = nil
            entry.Next = os.clock() + math.clamp(16 * factor, 2, 3600)
        end
        if not entry.Model and os.clock() >= entry.Next and near(anchor.Position, 110) then
            local success, created = pcall(Service.SpawnMonster, Service,
                monsterId(anchor), anchor.Position, true)
            if success and created then
                entry.Model = created
                addAppearance(created, anchor:GetAttribute("ZoneId"))
            else
                entry.Next = os.clock() + 7
            end
        elseif entry.Model and entry.Model:GetAttribute("InCombat") ~= true
            and not near(anchor.Position, 170) then
            local factor = tonumber(entry.Model:GetAttribute("LumiaRespawnFactor")) or 1
            entry.Model:Destroy()
            entry.Model = nil
            entry.Next = os.clock() + math.clamp(6 * factor, 2, 3600)
        end
    end
    task.wait(2)
end
