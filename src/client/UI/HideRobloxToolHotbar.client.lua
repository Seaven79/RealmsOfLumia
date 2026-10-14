-- REALMS OF LUMIA
-- Hide Roblox's default Tool hotbar, but keep the Tool equipped and usable.
-- The custom B inventory / C character sheet are left untouched.

local StarterGui = game:GetService("StarterGui")
local Players = game:GetService("Players")
local player = Players.LocalPlayer

local function hideHotbar()
    -- SetCoreGuiEnabled can fail briefly during client startup.
    for attempt = 1, 15 do
        local ok = pcall(function()
            StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
        end)
        if ok then
            return
        end
        task.wait(0.2)
    end
    warn("[Lumia] Could not hide the Roblox Tool hotbar")
end

task.spawn(hideHotbar)
player.CharacterAdded:Connect(function()
    task.delay(0.5, hideHotbar)
end)

print("[Lumia] Roblox Tool hotbar hidden; Lumia inventory remains active")