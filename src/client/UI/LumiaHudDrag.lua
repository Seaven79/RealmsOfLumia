-- Shared HUD drag controller; uses normalized screen coordinates so layouts
-- survive resolution changes. The server persists positions in profile.Settings.
local UIS=game:GetService("UserInputService")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
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
    -- Screen-space origin of the window's parent. AbsolutePosition is screen space
    -- while Position is parent space; they differ by the topbar inset plus nesting.
    -- Measuring it stops every drag from starting with a jump equal to that gap,
    -- and when the offset really is zero this changes nothing.
    local parentOffsetX,parentOffsetY=0,0
    local function measureParentOffset()
        local parent=window.Parent
        if not parent then return end
        local probe=Instance.new("Frame")
        probe.Name="LumiaGuiProbe"
        probe.Size=UDim2.fromOffset(1,1)
        probe.Position=UDim2.fromOffset(0,0)
        probe.BackgroundTransparency=1
        probe.BorderSizePixel=0
        probe.Parent=parent
        local abs=probe.AbsolutePosition
        parentOffsetX,parentOffsetY=abs.X,abs.Y
        probe:Destroy()
    end
    measureParentOffset()
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
        window.Position=UDim2.fromOffset(math.round(x-parentOffsetX),math.round(y-parentOffsetY))
    end
    -- Incremental move: shift Position by the measured pixel difference between
    -- where the window is on screen and where it should be. This never needs to
    -- know the space mapping (inset, parent, anchor, scale); it corrects from the
    -- observed result instead of predicting it.
    local function nudgeToScreen(targetAbsX,targetAbsY)
        targetAbsX,targetAbsY=clampPos(targetAbsX,targetAbsY)
        local cur=window.AbsolutePosition
        local dx=targetAbsX-cur.X
        local dy=targetAbsY-cur.Y
        if math.abs(dx)<1 and math.abs(dy)<1 then return end
        window.Position=UDim2.new(
            window.Position.X.Scale,window.Position.X.Offset+dx,
            window.Position.Y.Scale,window.Position.Y.Offset+dy)
    end
    local function applyNormalized(data)
        if not valid(data) or dragging then return end
        local screen=dimensions()
        if screen.X<=0 or screen.Y<=0 then return end
        movePixels(data.X*screen.X,data.Y*screen.Y)
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
        if not dragging then return end
        if input.UserInputType~=Enum.UserInputType.MouseMovement then return end
        local mouse=UIS:GetMouseLocation()
        local delta=mouse-pointerStart
        -- Desired screen position = grab position + cursor travel, applied as a
        -- measured nudge so the window tracks the cursor 1:1 with no jump.
        nudgeToScreen(windowStart.X+delta.X,windowStart.Y+delta.Y)
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
        task.spawn(function()
            local ok,res=pcall(function()
                return setRemote:InvokeServer(kind,normX,normY)
            end)
            if not ok or not res or not res.Ok then
                warn("[Lumia - HUD] Layout not saved for "..kind)
            end
        end)
    end)
end
return Hud
