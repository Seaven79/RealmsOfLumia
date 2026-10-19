-- REALMS OF LUMIA - Shared client modal UI registry
-- Any modal window calls Register on open, Unregister on close.
-- Other systems read player:GetAttribute("LumiaModalOpen") to check state.

local Players = game:GetService("Players")
local player = Players.LocalPlayer

local LumiaModalState = {}
local openModals = {}

function LumiaModalState:Register(name)
    if type(name) ~= "string" or name == "" then return end
    openModals[name] = true
    player:SetAttribute("LumiaModalOpen", true)
end

function LumiaModalState:Unregister(name)
    openModals[name] = nil
    for _ in pairs(openModals) do
        player:SetAttribute("LumiaModalOpen", true)
        return
    end
    player:SetAttribute("LumiaModalOpen", false)
end

function LumiaModalState:IsOpen()
    return player:GetAttribute("LumiaModalOpen") == true
end

return LumiaModalState