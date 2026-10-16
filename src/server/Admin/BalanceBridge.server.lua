-- REALMS OF LUMIA | Server-side admin-only network bridge.
-- UI visibility never grants permissions. Every request verifies UserId.
local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local Settings=require(script.Parent:WaitForChild("BalanceSettings"))
local Balance=require(script.Parent:WaitForChild("BalanceService"))
local lumia=ReplicatedStorage:WaitForChild("Lumia")
local folder=lumia:FindFirstChild("AdminBalanceNetwork") or Instance.new("Folder")
folder.Name="AdminBalanceNetwork"
folder.Parent=lumia
local function remote(name)
    local existing=folder:FindFirstChild(name)
    if existing then return existing end
    local obj=Instance.new("RemoteFunction")
    obj.Name=name
    obj.Parent=folder
    return obj
end
local get=remote("GetBalance")
local set=remote("SetBalance")
local lastRequest={}
local function permitted(player)
    return player and player.Parent==Players and player.UserId==Settings.OwnerUserId
end
get.OnServerInvoke=function(player)
    if not permitted(player) then return {Authorized=false} end
    return {Authorized=true, Data=Balance:Snapshot()}
end
set.OnServerInvoke=function(player,kind,key,value)
    if not permitted(player) then
        warn("[Lumia - Balance Bridge] Rejected admin request from "..tostring(player and player.UserId))
        return false,"Not authorized"
    end
    local now=os.clock()
    if now-(lastRequest[player] or -100)<1.0 then return false,"Wait a moment before changing another value" end
    lastRequest[player]=now
    -- Exact numeric types only; the client cannot send a table or hidden admin identity.
    if type(kind)~="string" or (type(key)~="string" and type(key)~="number")
        or (value~=nil and type(value)~="number") then
        return false,"Invalid request"
    end
    return Balance:Update(kind,key,value)
end
Players.PlayerRemoving:Connect(function(player) lastRequest[player]=nil end)
task.spawn(function()
    Balance:EnsureLoaded()
    Balance:StartCrossServerSync()
end)
print("[Lumia - Balance Bridge] Balance network ready; server-only UserId authorization")
