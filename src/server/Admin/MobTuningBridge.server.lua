-- REALMS OF LUMIA | Server authorization for monster balance changes.
local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local Settings=require(script.Parent:WaitForChild("BalanceSettings"))
local Tuning=require(script.Parent:WaitForChild("MobTuningService"))
local lumia=ReplicatedStorage:WaitForChild("Lumia")
local network=lumia:FindFirstChild("AdminMobNetwork") or Instance.new("Folder")
network.Name="AdminMobNetwork"
network.Parent=lumia
local function remote(name)
    local existing=network:FindFirstChild(name)
    if existing then
        assert(existing:IsA("RemoteFunction"),"Unexpected admin remote type")
        return existing
    end
    local object=Instance.new("RemoteFunction")
    object.Name=name
    object.Parent=network
    return object
end
local get=remote("GetMobs")
local set=remote("SetMob")
local lastChange={}
local function authorized(player)
    return player and player.Parent==Players and player.UserId==Settings.OwnerUserId
end
get.OnServerInvoke=function(player)
    if not authorized(player) then return {Authorized=false} end
    return {Authorized=true,Data=Tuning:Snapshot()}
end
set.OnServerInvoke=function(player,monsterId,kind,key,value)
    if not authorized(player) then
        warn("[Lumia - Mob Tuning Bridge] Rejected request from "..tostring(player and player.UserId))
        return false,"Not authorized"
    end
    local now=os.clock()
    if now-(lastChange[player] or -100)<0.6 then return false,"Wait briefly before saving again" end
    lastChange[player]=now
    if type(monsterId)~="string" or #monsterId>64 or type(kind)~="string" or #kind>32
        or (key~=nil and (type(key)~="string" or #key>64))
        or (value~=nil and type(value)~="number") then
        return false,"Invalid admin request"
    end
    return Tuning:Update(monsterId,kind,key,value)
end
Players.PlayerRemoving:Connect(function(player) lastChange[player]=nil end)
task.spawn(function()
    Tuning:EnsureLoaded()
    Tuning:StartCrossServerSync()
end)
print("[Lumia - Mob Tuning Bridge] Owner-only mob tuning network ready")
