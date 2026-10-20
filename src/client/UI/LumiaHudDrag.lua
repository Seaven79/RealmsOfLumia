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
