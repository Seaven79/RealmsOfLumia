-- Shared HUD drag controller; uses normalized screen coordinates so layouts
-- survive resolution changes. The server persists positions in profile.Settings.
local UIS=game:GetService("UserInputService")
local GuiService=game:GetService("GuiService")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local workspace=game:GetService("Workspace")
local network=ReplicatedStorage:WaitForChild("Lumia"):WaitForChild("ActionBarNetwork")
local getRemote=network:WaitForChild("GetHudLayout")
local setRemote=network:WaitForChild("SetHudLayout")
local Hud={}
local function valid(v)
    return type(v)=="table" and type(v.X)=="number" and type(v.Y)=="number"
        and v.X==v.X and v.Y==v.Y
        and v.X>=0 and v.X<=1 and v.Y>=0 and v.Y<=1
end
function Hud.Attach(screenGui,window,dragHandle,kind)
    assert(kind=="XPBar" or kind=="ActionBar")
    dragHandle.Active=true
    local dragging=false
    local pointerStart,windowStart
    local grabOffset=Vector2.new(0,0)
    local changedInput=nil
    local revision=0
    local function dimensions()
        return screenGui.AbsoluteSize
    end
    -- AbsolutePosition is screen space; Position is relative to this ScreenGui,
    -- which starts below the topbar unless it ignores the inset.
    local function toGuiSpace(absX,absY)
        if not screenGui.IgnoreGuiInset then
            local inset=GuiService:GetGuiInset()
            return absX-inset.X,absY-inset.Y
        end
        return absX,absY
    end
    local function clampPos(x,y)
        local screen=dimensions()
        return math.clamp(x,0,math.max(0,screen.X-window.AbsoluteSize.X)),
            math.clamp(y,0,math.max(0,screen.Y-window.AbsoluteSize.Y))
    end
    local function movePixels(absX,absY)
        absX,absY=clampPos(absX,absY)
        local gx,gy=toGuiSpace(absX,absY)
        window.AnchorPoint=Vector2.new(0,0)
        window.Position=UDim2.fromOffset(math.round(gx),math.round(gy))
    end
    -- Scale placement: the element keeps its relative position when the window is
    -- resized, instead of staying at a pixel offset measured on an older window.
    -- The bound subtracts the element's own size so it cannot leave the viewport.

    -- Canonical placement: the player's intent, unclamped. Only the DISPLAY is
    -- clamped, so a spell in a small window cannot permanently overwrite a
    -- layout chosen in fullscreen.
    local savedX,savedY=nil,nil
    -- Pixel path for every write: release and resize used to call moveNormalized
    -- (scale space) while dragging used pixels, so letting go of the mouse moved
    -- the element. One space, one function, no shift.
    local function displayPlacement()
        if savedX==nil then return end
        local screen=dimensions()
        if screen.X<1 or screen.Y<1 then return end
        movePixels(savedX*screen.X,savedY*screen.Y)
    end
    local function applyNormalized(data)
        if not valid(data) or dragging then return end
        savedX,savedY=data.X,data.Y
        displayPlacement()
    end
    task.spawn(function()
        for _=1,12 do
            local current=revision
            local ok,result=pcall(function()return getRemote:InvokeServer(kind)end)
            if ok and result and result.Ok then
                if current==revision then applyNormalized(result.Position) end
                return
            end
            task.wait(0.8)
        end
    end)
    dragHandle.InputBegan:Connect(function(input)
        if input.UserInputType~=Enum.UserInputType.MouseButton1 then return end
        if UIS:GetFocusedTextBox() then return end
        revision+=1
        dragging=true
        changedInput=input
        pointerStart=UIS:GetMouseLocation()
        -- Normalise the anchor at grab time, then track the grab point so the
        -- element cannot jump above or below the cursor when the drag starts.
        local abs=window.AbsolutePosition
        windowStart=abs
        local gx,gy=toGuiSpace(abs.X,abs.Y)
        window.AnchorPoint=Vector2.new(0,0)
        window.Position=UDim2.fromOffset(math.round(gx),math.round(gy))
        grabOffset=Vector2.new(pointerStart.X-abs.X,pointerStart.Y-abs.Y)
        if workspace:GetAttribute("LumiaHudDragDebug")==true then
            print(string.format("[Lumia - HUD drag v3] %s grab: abs=(%d,%d) gui=(%d,%d) offset=(%d,%d) anchor=(%.1f,%.1f)",
                kind,abs.X,abs.Y,gx,gy,grabOffset.X,grabOffset.Y,window.AnchorPoint.X,window.AnchorPoint.Y))
        end
    end)
    UIS.InputChanged:Connect(function(input)
        if dragging and input.UserInputType==Enum.UserInputType.MouseMovement then
            local mouse=UIS:GetMouseLocation()
            movePixels(mouse.X-grabOffset.X,mouse.Y-grabOffset.Y)
        end
    end)
    UIS.InputEnded:Connect(function(input)
        if input.UserInputType~=Enum.UserInputType.MouseButton1 or not dragging then return end
        dragging=false
        changedInput=nil
        local screen=dimensions()
        if screen.X<1 or screen.Y<1 then return end
        local pos=window.AbsolutePosition
        local normX=math.clamp(pos.X/screen.X,0,1)
        local normY=math.clamp(pos.Y/screen.Y,0,1)
        -- Record intent from the drop point, then display it clamped.
        savedX,savedY=normX,normY
        displayPlacement()
        task.spawn(function()
            local ok,res=pcall(function()
                return setRemote:InvokeServer(kind,normX,normY)
            end)
            if not ok or not res or not res.Ok then
                warn("[Lumia - HUD] Layout not saved for "..kind)
            end
        end)
    end)
    -- A resize only changes what is DISPLAYED; the canonical placement is never
    -- recomputed from the clamped position.
    local camera=workspace.CurrentCamera
    if camera then
        camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
            if dragging then return end
            local screen=dimensions()
            if screen.X<1 or screen.Y<1 then return end
            if savedX==nil then
                local pos=window.AbsolutePosition
                savedX,savedY=pos.X/screen.X,pos.Y/screen.Y
            end
            displayPlacement()
        end)
    end
end
return Hud
