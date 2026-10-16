-- Realms of Lumia: persistent action slots + server-authoritative item activation.
-- No new DataStore; slots are stored in the existing profile.Settings table.
-- Designed to be reused for new potions and action types as the MMO grows.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local lumia = ReplicatedStorage:WaitForChild("Lumia")
local shared = lumia:WaitForChild("Shared")
local Definitions = require(shared:WaitForChild("Items"):WaitForChild("ItemDefinitions"))
local Config = require(shared:WaitForChild("ActionBar"):WaitForChild("ActionBarConfig"))
local services = script.Parent.Parent
local Data = require(services:WaitForChild("Players"):WaitForChild("PlayerDataService"))
local Inventory = require(services:WaitForChild("Inventory"):WaitForChild("InventoryService"))
local Snapshot = require(services:WaitForChild("Inventory"):WaitForChild("BagSnapshot"))
local Storage = require(script.Parent:WaitForChild("ActionBarStorageService"))

local folder = lumia:FindFirstChild("ActionBarNetwork")
if not folder then
    folder = Instance.new("Folder")
    folder.Name = "ActionBarNetwork"
    folder.Parent = lumia
end
local function remote(name)
    local existing = folder:FindFirstChild(name)
    if existing then
        assert(existing:IsA("RemoteFunction"), "Action bar remote class mismatch: " .. name)
        return existing
    end
    local value = Instance.new("RemoteFunction")
    value.Name = name
    value.Parent = folder
    return value
end
local getRemote = remote("GetActionBar")
local setRemote = remote("SetActionSlot")
local useRemote = remote("UseActionSlot")
local keyRemote = remote("SetActionKey")
local getHudRemote=remote("GetHudLayout")
local setHudRemote=remote("SetHudLayout")
local lastHudSet=setmetatable({}, {__mode="k"})
local function hudSettings(player)
    local profile=Data:GetProfile(player)
    if not profile or type(profile.Settings)~="table" then return nil end
    local settings=profile.Settings
    if type(settings.HudPositions)~="table" then settings.HudPositions={} end
    return settings.HudPositions
end
local function validHud(name)
    return name=="XPBar" or name=="ActionBar"
end
getHudRemote.OnServerInvoke=function(player,name)
    if not validHud(name) then return {Ok=false,Message="Unknown HUD panel"} end
    local saved=hudSettings(player)
    if not saved then return {Ok=false,Message="Player loading"} end
    return {Ok=true,Position=saved[name]}
end
setHudRemote.OnServerInvoke=function(player,name,x,y)
    if not validHud(name) or type(x)~="number" or type(y)~="number"
        or x~=x or y~=y or x<0 or x>1 or y<0 or y>1 then
        return {Ok=false,Message="Invalid HUD position"}
    end
    local now=os.clock()
    if now-(lastHudSet[player] or -100)<0.2 then
        return {Ok=false,Message="Please wait"}
    end
    local saved=hudSettings(player)
    if not saved then return {Ok=false,Message="Player loading"} end
    lastHudSet[player]=now
    saved[name]={X=x,Y=y}
    return {Ok=true}
end


local cooldowns = setmetatable({}, {__mode="k"})
local lastSet = setmetatable({}, {__mode="k"})
local working = setmetatable({}, {__mode="k"})

local function state(player)
    if not player or player.Parent ~= Players then return nil end
    local profile = Data:GetProfile(player)
    if not profile or type(profile.Settings) ~= "table" then return nil end
    if type(profile.Settings.ActionBarSlots) ~= "table" then
        profile.Settings.ActionBarSlots = {}
    end
    return profile.Settings.ActionBarSlots
end
local function actionKeys(player)
    local profile = Data:GetProfile(player)
    if not profile or type(profile.Settings) ~= "table" then return nil end
    if type(profile.Settings.ActionBarKeys) ~= "table" then
        profile.Settings.ActionBarKeys = {}
    end
    local saved = profile.Settings.ActionBarKeys
    for i = 1, Config.SlotCount do
        local key = tostring(i)
        if not Config.ValidKey(saved[key]) then
            saved[key] = Config.ValidKey(saved[i]) and saved[i] or Config.DefaultKeys[i]
        end
        saved[i] = nil -- DataStore-safe string keys instead of sparse numeric array keys.
    end
    return saved
end
local function publicKeys(keys)
    local result = {}
    for i = 1, Config.SlotCount do result[i] = keys[tostring(i)] end
    return result
end
local function indexOk(i)
    return type(i) == "number" and i % 1 == 0 and i >= 1 and i <= Config.SlotCount
end
local function payload(player,slots,extra)
    local listed,counts=Storage:Public(player,slots)
    local result={Ok=true,Slots=listed,Quantities=counts,Bag=Snapshot.Build(player)}
    if extra then for key,value in pairs(extra) do result[key]=value end end
    return result
end
getRemote.OnServerInvoke=function(player)
    local slots=state(player)
    if not slots then return {Ok=false,Message="Your character is still loading"} end
    if not Storage:Initialize(player,slots) then return {Ok=false,Message="Inventory loading"} end
    local keys=actionKeys(player)
    return payload(player,slots,{Keys=publicKeys(keys)})
end
setRemote.OnServerInvoke=function(player,index,itemId,bagId,bagSlot,instanceId)
    local slots=state(player)
    if not slots then return {Ok=false,Message="Your character is still loading"} end
    if not indexOk(index) then return {Ok=false,Message="Invalid action slot"} end
    if not Storage:Initialize(player,slots) then return {Ok=false,Message="Inventory loading"} end
    local now=os.clock()
    if now-(lastSet[player] or -100)<0.1 then
        return {Ok=false,Message="Please wait"}
    end
    lastSet[player]=now
    local ok,why
    if itemId==nil then
        ok,why=Storage:Clear(player,index,slots)
    else
        ok,why=Storage:MoveToBar(player,index,itemId,bagId,bagSlot,instanceId,slots)
    end
    if not ok then return {Ok=false,Message=why} end
    return payload(player,slots,{Message=why})
end
keyRemote.OnServerInvoke = function(player, index, keyName)
    local keys = actionKeys(player)
    if not keys then return {Ok=false, Message="Your character is still loading"} end
    if not indexOk(index) or not Config.ValidKey(keyName) then
        return {Ok=false, Message="Invalid action key"}
    end
    local previous = keys[tostring(index)]
    for other = 1, Config.SlotCount do
        if other ~= index and keys[tostring(other)] == keyName then
            keys[tostring(other)] = previous
        end
    end
    keys[tostring(index)] = keyName
    return {Ok=true, Keys=publicKeys(keys), Message="Key assigned"}
end

useRemote.OnServerInvoke=function(player,index)
    local slots=state(player)
    if not slots then return {Ok=false,Message="Your character is still loading"} end
    if not indexOk(index) then return {Ok=false,Message="Invalid action slot"} end
    if working[player] then return {Ok=false,Message="Please wait"} end
    if not Storage:Initialize(player,slots) then return {Ok=false,Message="Inventory loading"} end
    working[player]=true
    local safe,result=pcall(function()
        local itemId=slots[tostring(index)] or slots[index]
        local def=type(itemId)=="string" and Definitions.Get(itemId)
        if not def then return {Ok=false,Message="No assigned item"} end
        if def.Type=="Weapon" then
            local equipped,message=Storage:EquipWeapon(player,index,slots)
            if not equipped then return {Ok=false,Message=message} end
            return payload(player,slots,{Message=message,Equipment=Storage:EquipmentSnapshot(player)})
        end
        if not Config.IsConsumable(def) then return {Ok=false,Message="Item cannot be activated"} end
        local character=player.Character
        local humanoid=character and character:FindFirstChildOfClass("Humanoid")
        if not humanoid or humanoid.Health<=0 then return {Ok=false,Message="You cannot use that now"} end
        local now=os.clock()
        local expiry=cooldowns[player] and cooldowns[player][itemId] or 0
        if now<expiry then return {Ok=false,Message="Potion cooling down",Remaining=expiry-now} end
        local drank,why=Storage:Drink(player,index,itemId)
        if not drank then return {Ok=false,Message=why} end
        local heal=math.max(0,math.min(def.Heal,humanoid.MaxHealth-humanoid.Health))
        humanoid.Health=math.min(humanoid.MaxHealth,humanoid.Health+heal)
        local cooldown=type(def.ActionCooldown)=="number"
            and math.clamp(def.ActionCooldown,0,Config.MaxCooldown) or Config.DefaultCooldown
        cooldowns[player]=cooldowns[player] or {}
        cooldowns[player][itemId]=now+cooldown
        return payload(player,slots,{Cooldown=cooldown,ItemId=itemId,
            Message=heal>0 and ("Restored "..tostring(math.floor(heal+0.5)).." health")
                or "Potion consumed (health already full)"})
    end)
    working[player]=nil
    if not safe then
        warn("[Lumia - Action Bar] "..tostring(result))
        return {Ok=false,Message="Action failed safely. Please retry."}
    end
    return result
end
Players.PlayerRemoving:Connect(function(player)
    cooldowns[player] = nil
    lastSet[player] = nil
    working[player] = nil
    lastHudSet[player]=nil
end)
print("[Lumia - Action Bar] Server-authoritative toolbar online")
