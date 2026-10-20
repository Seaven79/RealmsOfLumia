-- Shared HUD drag controller; uses normalized screen coordinates so layouts
-- survive resolution changes. The server persists positions in profile.Settings.
local UIS=game:GetService("UserInputService")
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
    local changedInput=nil
    local revision=0
    local function dimensions()
        return screenGui.AbsoluteSize
    end
    local function clampPos(x,y)
        local screen=dimensions()
        return math.clamp(x,0,math.max(0,screen.X-window.AbsoluteSize.X)),
            math.clamp(y,0,math.max(0,screen.Y-window.AbsoluteSize.Y))
    end
    local function movePixels(x,y)
        x,y=clampPos(x,y)
        window.AnchorPoint=Vector2.new(0,0)
        window.Position=UDim2.fromOffset(math.round(x),math.round(y))
    end
    -- Scale placement: the element keeps its relative position when the window is
    -- resized, instead of staying at a pixel offset measured on an older window.
    -- The bound subtracts the element's own size so it cannot leave the viewport.
    local function moveNormalized(nx,ny)
        local screen=dimensions()
        if screen.X<1 or screen.Y<1 then return end
        local size=window.AbsoluteSize
        local maxX=math.max(0,(screen.X-math.max(1,size.X))/screen.X)
        local maxY=math.max(0,(screen.Y-math.max(1,size.Y))/screen.Y)
        window.AnchorPoint=Vector2.new(0,0)
        window.Position=UDim2.fromScale(math.clamp(nx,0,maxX),math.clamp(ny,0,maxY))
    end
    local function applyNormalized(data)
        if not valid(data) or dragging then return end
        moveNormalized(data.X,data.Y)
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
        windowStart=window.AbsolutePosition
    end)
    UIS.InputChanged:Connect(function(input)
        if dragging and input.UserInputType==Enum.UserInputType.MouseMovement then
            local delta=UIS:GetMouseLocation()-pointerStart
            movePixels(windowStart.X+delta.X,windowStart.Y+delta.Y)
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
        -- Settle onto scale coordinates so the drop survives a window resize.
        moveNormalized(normX,normY)
        task.spawn(function()
            local ok,res=pcall(function()
                return setRemote:InvokeServer(kind,normX,normY)
            end)
            if not ok or not res or not res.Ok then
                warn("[Lumia - HUD] Layout not saved for "..kind)
            end
        end)
    end)
    -- Keep the element visible when the viewport changes (fullscreen toggle).
    local camera=workspace.CurrentCamera
    if camera then
        camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
            if dragging then return end
            local screen=dimensions()
            if screen.X<1 or screen.Y<1 then return end
            local pos=window.AbsolutePosition
            moveNormalized(pos.X/screen.X,pos.Y/screen.Y)
        end)
    end
end
return Hud
