-- Lumia V17: visible lightweight ORIGINAL armor, R6 / R15, server replicated.
-- All geometry is noncolliding and welded; no purchased or licensed assets.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Lumia"):WaitForChild("Shared")
local Items = require(Shared:WaitForChild("Items"):WaitForChild("ItemDefinitions"))
local Data = require(script.Parent.Parent:WaitForChild("Players"):WaitForChild("PlayerDataService"))
local Stats = require(script.Parent:WaitForChild("CombatStats"))
local PlayerPositions = require(game:GetService("ReplicatedStorage"):WaitForChild("Lumia"):WaitForChild("Shared"):WaitForChild("Players"):WaitForChild("PlayerPositions"))
local palette = {
    [1] = Color3.fromRGB(141, 113, 85),
    [2] = Color3.fromRGB(84, 137, 90),
    [3] = Color3.fromRGB(88, 132, 175),
    [4] = Color3.fromRGB(126, 89, 149),
    [5] = Color3.fromRGB(201, 169, 87),
}
local attachments = {
    Head = {"Head", CFrame.new(0, 0.37, 0), Vector3.new(1.35, .45, 1.28)},
    Chest = {"UpperTorso", CFrame.new(0, 0, -.29), Vector3.new(2.25, 1.25, .35)},
    Hands = {"RightHand", CFrame.new(0, 0, 0), Vector3.new(.55, .72, .58)},
    Legs = {"RightUpperLeg", CFrame.new(0, -.08, 0), Vector3.new(.75, 1.2, .73)},
    Feet = {"RightFoot", CFrame.new(0, -.1, 0), Vector3.new(.83, .5, 1.05)},
    OffHand = {"LeftHand", CFrame.new(0, -.1, -.45), Vector3.new(1.5, 1.7, .22)},
    Ring = {"LeftHand", CFrame.new(0, -.22, 0), Vector3.new(.52, .16, .52)},
}
local fallback = {
    UpperTorso = "Torso", RightHand = "Right Arm", LeftHand = "Left Arm",
    RightUpperLeg = "Right Leg", RightFoot = "Right Leg",
    LeftUpperLeg = "Left Leg", LeftFoot = "Left Leg",
}
local function equipped(profile)
    local indexed = {}
    local inv = profile.Inventory or {}
    for _, record in ipairs(inv.Items or {}) do
        if type(record) == "table" then indexed[record.InstanceId] = record.ItemId end
    end
    local current = {}
    local signature = {}
    for slot, id in pairs(inv.Equipment or {}) do
        local itemId = indexed[id]
        local item = itemId and Items.Get(itemId)
        if item then
            current[slot] = item
            signature[#signature+1] = slot .. ":" .. itemId
        end
    end
    table.sort(signature)
    return current, table.concat(signature, "|")
end
local function buildPiece(character, slot, definition, container, bodyOverride)
    local plan = attachments[slot]
    if not plan then return end
    local bodyName = bodyOverride or plan[1]
    local body = character:FindFirstChild(bodyName) or character:FindFirstChild(fallback[bodyName] or "")
    if not body or not body:IsA("BasePart") then return end
    local part = Instance.new("Part")
    part.Name = "Lumia" .. slot
    part.Size = Vector3.new(math.min(body.Size.X * 1.12, plan[3].X),
        math.min(body.Size.Y * 0.97, plan[3].Y), math.min(body.Size.Z * 1.15, plan[3].Z))
    part.Material = definition.GearTier >= 4 and Enum.Material.Metal or Enum.Material.SmoothPlastic
    part.Color = palette[definition.GearTier] or palette[1]
    part.Transparency = 0.07
    part.Anchored = false
    part.CanCollide = false
    part.CanTouch = false
    part.CanQuery = false
    part.CastShadow = false
    part.Massless = true
    local offset = plan[2]
    if slot == "Head" then offset = CFrame.new(0, body.Size.Y * .43, 0) end
    if slot == "Chest" then offset = CFrame.new(0, 0, -body.Size.Z * .52) end
    part.CFrame = body.CFrame * offset
    part.Parent = container
    local weld = Instance.new("WeldConstraint")
    weld.Part0 = body
    weld.Part1 = part
    weld.Parent = part
end
local function render(player, character, current)
    local old = character:FindFirstChild("LumiaWornEquipment")
    if old then old:Destroy() end
    local folder = Instance.new("Folder")
    folder.Name = "LumiaWornEquipment"
    folder.Parent = character
    for slot, definition in pairs(current) do
        if definition.Type == "Armor" then
            buildPiece(character, slot, definition, folder)
            if slot == "Hands" then buildPiece(character, slot, definition, folder, "LeftHand") end
            if slot == "Legs" then buildPiece(character, slot, definition, folder, "LeftUpperLeg") end
            if slot == "Feet" then buildPiece(character, slot, definition, folder, "LeftFoot") end
        end
    end
end
local function refreshHealth(player, humanoid)
    local stats = Stats.Get(player)
    if not stats or not humanoid or humanoid.Health <= 0 then return end
    local oldMax = math.max(1, humanoid.MaxHealth)
    local newMax = math.clamp(stats.MaxHealth, 100, 800)
    if oldMax ~= newMax then
        local ratio = humanoid.Health / oldMax
        humanoid.MaxHealth = newMax
        humanoid.Health = math.max(1, math.min(newMax, math.floor(ratio * newMax + .5)))
    end
    player:SetAttribute("LumiaAttack", stats.Attack)
    player:SetAttribute("LumiaDefense", stats.Defense)
end
local function watch(player)
    task.spawn(function()
        local signature = ""
        local watchedCharacter
        while player.Parent == Players do
            local character = player.Character
            local humanoid = character and character:FindFirstChildOfClass("Humanoid")
            local profile = Data:GetProfile(player)
            if character and humanoid and profile then
                local current, value = equipped(profile)
                if watchedCharacter ~= character or signature ~= value then
                    watchedCharacter = character
                    signature = value
                    render(player, character, current)
                end
                refreshHealth(player, humanoid)
            end
            task.wait(.7)
        end
    end)
end
Players.PlayerAdded:Connect(watch)
for _, p in ipairs(Players:GetPlayers()) do watch(p) end
