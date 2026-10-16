-- REALMS OF LUMIA | Large owner-only admin dashboard (F8)
-- XP & Quests / Mobs & Loot. The SERVER checks the UserId on every request.
local Players=game:GetService("Players")
local UserInputService=game:GetService("UserInputService")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local player=Players.LocalPlayer
if player.UserId~=1614020138 then return end -- cosmetic visibility guard only

local lumia=ReplicatedStorage:WaitForChild("Lumia")
local xpNet=lumia:WaitForChild("AdminBalanceNetwork")
local mobNet=lumia:WaitForChild("AdminMobNetwork")
local getXP=xpNet:WaitForChild("GetBalance")
local setXP=xpNet:WaitForChild("SetBalance")
local getMobs=mobNet:WaitForChild("GetMobs")
local setMobs=mobNet:WaitForChild("SetMob")

local GOLD=Color3.fromRGB(235,192,120)
local WHITE=Color3.fromRGB(243,238,230)
local MUTED=Color3.fromRGB(182,189,200)
local PANEL=Color3.fromRGB(31,35,46)
local INPUT=Color3.fromRGB(44,51,65)
local OK=Color3.fromRGB(151,225,173)
local ERROR=Color3.fromRGB(255,161,140)

local function corner(obj,r)
    local c=Instance.new("UICorner")
    c.CornerRadius=UDim.new(0,r or 7)
    c.Parent=obj
end
local function frame(parent,name,x,y,w,h,color)
    local obj=Instance.new("Frame")
    obj.Name=name
    obj.Position=UDim2.fromOffset(x,y)
    obj.Size=UDim2.fromOffset(w,h)
    obj.BackgroundColor3=color or PANEL
    obj.BorderSizePixel=0
    obj.Parent=parent
    corner(obj,8)
    return obj
end
local function label(parent,value,x,y,w,h,size,color,bold)
    local obj=Instance.new("TextLabel")
    obj.Text=value
    obj.Position=UDim2.fromOffset(x,y)
    obj.Size=UDim2.fromOffset(w,h)
    obj.BackgroundTransparency=1
    obj.Font=bold and Enum.Font.GothamBold or Enum.Font.Gotham
    obj.TextSize=size or 17
    obj.TextColor3=color or WHITE
    obj.TextXAlignment=Enum.TextXAlignment.Left
    obj.TextYAlignment=Enum.TextYAlignment.Center
    obj.TextTruncate=Enum.TextTruncate.AtEnd
    obj.Parent=parent
    return obj
end
local function button(parent,value,x,y,w,h,onClick,isSecondary)
    local obj=Instance.new("TextButton")
    obj.Text=value
    obj.Position=UDim2.fromOffset(x,y)
    obj.Size=UDim2.fromOffset(w,h)
    obj.BackgroundColor3=isSecondary and INPUT or Color3.fromRGB(98,71,41)
    obj.BorderSizePixel=0
    obj.TextColor3=WHITE
    obj.Font=Enum.Font.GothamBold
    obj.TextSize=16
    obj.Parent=parent
    corner(obj,6)
    if onClick then obj.Activated:Connect(onClick) end
    return obj
end
local function input(parent,value,x,y,w,h)
    local obj=Instance.new("TextBox")
    obj.Position=UDim2.fromOffset(x,y)
    obj.Size=UDim2.fromOffset(w,h)
    obj.BackgroundColor3=INPUT
    obj.BorderSizePixel=0
    obj.Text=tostring(value or "")
    obj.TextColor3=WHITE
    obj.Font=Enum.Font.GothamMedium
    obj.TextSize=18
    obj.ClearTextOnFocus=false
    obj.TextXAlignment=Enum.TextXAlignment.Center
    obj.Parent=parent
    corner(obj,6)
    return obj
end
local function wholeNumber(field)
    local v=tonumber(field.Text)
    if not v or v~=v or v==math.huge or v==-math.huge then return nil end
    return v
end

local gui=Instance.new("ScreenGui")
gui.Name="LumiaAdminDashboard"
gui.DisplayOrder=160
gui.ResetOnSpawn=false
gui.IgnoreGuiInset=true
gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling
gui.Parent=player:WaitForChild("PlayerGui")
local dim=frame(gui,"Backdrop",0,0,0,0,Color3.fromRGB(5,8,15))
dim.Size=UDim2.fromScale(1,1)
dim.BackgroundTransparency=.35
dim.Visible=false
local panel=frame(gui,"AdminWindow",0,0,940,645,Color3.fromRGB(20,24,33))
panel.AnchorPoint=Vector2.new(.5,.5)
panel.Position=UDim2.fromScale(.5,.5)
panel.Visible=false
local edge=Instance.new("UIStroke")
edge.Color=Color3.fromRGB(190,142,73)
edge.Thickness=2
edge.Parent=panel
local scale=Instance.new("UIScale")
scale.Parent=panel
local function resize()
    local camera=workspace.CurrentCamera
    if not camera then return end
    local v=camera.ViewportSize
    -- Real desktop size: 940px with 17-22px fonts, never tiny 11px controls.
    scale.Scale=math.min(1.15,(v.X-40)/940,(v.Y-40)/645)
end
local cameraConnection
local function watchCamera()
    if cameraConnection then cameraConnection:Disconnect() end
    local camera=workspace.CurrentCamera
    if camera then cameraConnection=camera:GetPropertyChangedSignal("ViewportSize"):Connect(resize) end
    resize()
end
workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(watchCamera)
watchCamera()

label(panel,"REALMS OF LUMIA",24,17,475,25,23,GOLD,true)
label(panel,"OWNER DASHBOARD  ·  F8 to close",24,49,570,22,15,MUTED)
button(panel,"X",882,19,36,36,function()
    panel.Visible=false
    dim.Visible=false
end,true)
local xpTab=button(panel,"XP & QUESTS",24,85,215,44,nil)
local mobTab=button(panel,"MOBS & LOOT",250,85,215,44,nil,true)
local pages=frame(panel,"Pages",24,141,892,434,Color3.fromRGB(20,24,33))
pages.BackgroundTransparency=1
local xpPage=frame(pages,"XPPage",0,0,892,434,Color3.fromRGB(20,24,33))
xpPage.BackgroundTransparency=1
local mobPage=frame(pages,"MobsPage",0,0,892,434,Color3.fromRGB(20,24,33))
mobPage.BackgroundTransparency=1
mobPage.Visible=false
local status=label(panel,"Open F8 to load settings.",24,585,882,43,15,MUTED)
status.TextWrapped=true
status.TextTruncate=Enum.TextTruncate.None
local busy=false
local xpData,mobData
local selectedId
local selectedTab="XP"
local function setStatus(msg,isGood)
    status.Text=tostring(msg)
    status.TextColor3=isGood==nil and MUTED or (isGood and OK or ERROR)
end
local function selectTab(which)
    selectedTab=which
    xpPage.Visible=(which=="XP")
    mobPage.Visible=(which=="Mobs")
    xpTab.BackgroundColor3=which=="XP" and Color3.fromRGB(98,71,41) or INPUT
    mobTab.BackgroundColor3=which=="Mobs" and Color3.fromRGB(98,71,41) or INPUT
end
xpTab.Activated:Connect(function() selectTab("XP") end)
mobTab.Activated:Connect(function() selectTab("Mobs") end)

-- XP TAB: preserve XP level, quests, and wolf kill rewards from old panel.
local xpLeft=frame(xpPage,"Progression",0,0,434,423)
local xpRight=frame(xpPage,"Rewards",449,0,443,423)
label(xpLeft,"LEVEL PROGRESSION",18,16,391,30,20,GOLD,true)
label(xpLeft,"Level to advance FROM (1–59)",18,61,390,22,16,MUTED)
local levelField=input(xpLeft,"1",18,93,92,39)
local xpField=input(xpLeft,"1000",124,93,185,39)
button(xpLeft,"SAVE",318,93,98,39,function()
    local level,value=wholeNumber(levelField),wholeNumber(xpField)
    if not level or level%1~=0 or not value or value%1~=0 then
        setStatus("Level and XP must be whole numbers.",false) return
    end
    if busy then return end
    busy=true
    setStatus("Saving level XP...",nil)
    task.spawn(function()
        local ok,accepted,result=pcall(function() return setXP:InvokeServer("LevelXP",level,value) end)
        busy=false
        if not ok or not accepted then setStatus(ok and result or accepted,false) return end
        xpData=result
        setStatus("Level XP saved. Revision "..tostring(result.Revision),true)
    end)
end)
button(xpLeft,"RESET LEVEL TO DEFAULT",18,144,395,44,function()
    local level=wholeNumber(levelField)
    if not level or level%1~=0 then setStatus("Enter a valid level.",false) return end
    if busy then return end
    busy=true
    task.spawn(function()
        local ok,accepted,result=pcall(function() return setXP:InvokeServer("ResetLevelXP",level,nil) end)
        busy=false
        if not ok or not accepted then setStatus(ok and result or accepted,false) return end
        xpData=result
        xpField.Text=tostring(result.LevelXP[tostring(level)] or 1000)
        setStatus("Level requirement restored.",true)
    end)
end,true)
label(xpLeft,"Current required XP",18,228,376,25,17,MUTED)
local levelCurrent=label(xpLeft,"1,000 XP",18,261,397,45,27,WHITE,true)
label(xpLeft,"Changes affect future leveling calculations.",18,337,398,55,15,MUTED)
levelField.FocusLost:Connect(function()
    local level=wholeNumber(levelField)
    if level and level%1==0 and xpData then
        local value=xpData.LevelXP[tostring(level)]
        if value then xpField.Text=tostring(value); levelCurrent.Text=tostring(value).." XP" end
    end
end)
label(xpRight,"QUEST & KILL XP REWARDS",18,16,410,30,20,GOLD,true)
local xpFields={}
local function rewardRow(title,y,kind,key)
    label(xpRight,title,18,y,185,37,16,WHITE)
    local field=input(xpRight,"0",205,y,115,37)
    button(xpRight,"SAVE",332,y,92,37,function()
        local value=wholeNumber(field)
        if not value or value%1~=0 then setStatus("XP must be a whole number.",false) return end
        if busy then return end
        busy=true
        task.spawn(function()
            local ok,accepted,result=pcall(function() return setXP:InvokeServer(kind,key,value) end)
            busy=false
            if not ok or not accepted then setStatus(ok and result or accepted,false) return end
            xpData=result
            setStatus(title.." saved successfully.",true)
        end)
    end)
    return field
end
xpFields.Starter=rewardRow("Starter quest",75,"QuestXP","Starter")
xpFields.Side=rewardRow("Side quest",125,"QuestXP","Side")
xpFields.Main=rewardRow("Main quest",175,"QuestXP","Main")
xpFields.ForestWolf=rewardRow("Forest Wolf kill",245,"MonsterXP","ForestWolf")
label(xpRight,"Quest XP tiers are ready for future quest rewards.",18,338,414,52,15,MUTED)
local function applyXP(snapshot)
    xpData=snapshot
    local level=wholeNumber(levelField) or 1
    local value=snapshot.LevelXP[tostring(level)] or 1000
    xpField.Text=tostring(value)
    levelCurrent.Text=tostring(value).." XP"
    for _,tier in ipairs({"Starter","Side","Main"}) do
        xpFields[tier].Text=tostring(snapshot.QuestXP[tier])
    end
    xpFields.ForestWolf.Text=tostring(snapshot.MonsterXP.ForestWolf)
    if not snapshot.PersistenceAvailable then
        setStatus("XP settings DataStore unavailable; check Studio API access.",false)
    end
end

-- MOBS TAB: all values come from secure server snapshots; never trust UI values.
local mobHeader=frame(mobPage,"MobHeader",0,0,892,66)
label(mobHeader,"MONSTER TYPE",16,12,160,42,19,GOLD,true)
local mobName=label(mobHeader,"Loading...",260,14,370,38,21,WHITE,true)
local prev=button(mobHeader,"<",186,13,54,39,nil,true)
local next=button(mobHeader,">",817,13,54,39,nil,true)
local statsPanel=frame(mobPage,"Stats",0,77,434,346)
local lootPanel=frame(mobPage,"Loot",449,77,443,346)
label(statsPanel,"STATS",17,6,390,28,19,GOLD,true)
label(lootPanel,"GRAY LOOT TABLE",17,6,405,28,19,GOLD,true)
local function scroller(parent,name,x,y,w,h)
    local scrolling=Instance.new("ScrollingFrame")
    scrolling.Name=name
    scrolling.Position=UDim2.fromOffset(x,y)
    scrolling.Size=UDim2.fromOffset(w,h)
    scrolling.BackgroundTransparency=1
    scrolling.BorderSizePixel=0
    scrolling.ScrollBarThickness=8
    scrolling.ScrollBarImageColor3=GOLD
    scrolling.CanvasSize=UDim2.fromOffset(0,0)
    scrolling.Parent=parent
    return scrolling
end
local statList=scroller(statsPanel,"StatRows",12,42,410,294)
local lootList=scroller(lootPanel,"LootRows",12,42,419,294)
local function clear(list)
    for _,child in ipairs(list:GetChildren()) do child:Destroy() end
end
local refreshMobs
local function requestMob(kind,key,value,description)
    if busy then return end
    if not selectedId then setStatus("Select a monster first.",false) return end
    busy=true
    setStatus("Saving "..description.."...",nil)
    local id=selectedId
    task.spawn(function()
        local ok,accepted,result=pcall(function() return setMobs:InvokeServer(id,kind,key,value) end)
        busy=false
        if not ok or not accepted then setStatus(ok and result or accepted,false) return end
        mobData=result
        setStatus(description.." saved. New spawns will use the updated values.",true)
        -- Rebuild controls from confirmed authoritative settings.
        if selectedId==id then
            local oldStatY,oldLootY=statList.CanvasPosition.Y,lootList.CanvasPosition.Y
            refreshMobs()
            statList.CanvasPosition=Vector2.new(0,oldStatY)
            lootList.CanvasPosition=Vector2.new(0,oldLootY)
        end
    end)
end
local function statRow(spec,value,y)
    label(statList,spec.Label,4,y,178,40,15,WHITE)
    local field=input(statList,tostring(value),177,y+3,82,35)
    button(statList,"SAVE",268,y+3,75,35,function()
        local newValue=wholeNumber(field)
        if not newValue then setStatus("Enter a valid number.",false) return end
        requestMob("Stat",spec.Key,newValue,spec.Label)
    end)
    button(statList,"↺",352,y+3,46,35,function()
        requestMob("ResetStat",spec.Key,nil,spec.Label.." default")
    end,true)
end
local function lootRow(title,id,weight,y)
    label(lootList,title,4,y,182,40,15,WHITE)
    local field=input(lootList,tostring(weight),185,y+3,79,35)
    button(lootList,"SAVE",273,y+3,72,35,function()
        local newValue=wholeNumber(field)
        if not newValue or newValue%1~=0 then setStatus("Loot weight must be a whole number.",false) return end
        requestMob("Weight",id,newValue,title.." weight")
    end)
    button(lootList,"↺",353,y+3,47,35,function()
        requestMob("ResetWeight",id,nil,title.." default")
    end,true)
end
refreshMobs=function()
    clear(statList)
    clear(lootList)
    if not mobData or not selectedId or not mobData.Monsters[selectedId] then return end
    local data=mobData.Monsters[selectedId]
    mobName.Text=data.Name.."  ("..selectedId..")"
    for index,spec in ipairs(mobData.StatFields) do
        statRow(spec,data.Stats[spec.Key],(index-1)*44)
    end
    statList.CanvasSize=UDim2.fromOffset(0,#mobData.StatFields*44+8)
    label(lootList,"Items generated per kill (0–5)",4,0,260,38,15,WHITE)
    local dropCount=input(lootList,tostring(data.Loot.DropCount),263,3,57,35)
    button(lootList,"SAVE",326,3,74,35,function()
        local value=wholeNumber(dropCount)
        if not value or value%1~=0 then setStatus("Drop count must be a whole number.",false) return end
        requestMob("DropCount",nil,value,"Drop count")
    end)
    label(lootList,"Relative drop weights (0 disables an item)",4,49,400,27,14,MUTED)
    for i,item in ipairs(mobData.ItemCatalog) do
        lootRow(item.Name,item.Id,data.Loot.Weights[item.Id] or 0,80+(i-1)*47)
    end
    local bottom=80+#mobData.ItemCatalog*47
    label(lootList,"Only existing gray materials are selectable.",4,bottom+4,397,30,14,MUTED)
    label(lootList,"New items can be added to ItemDefinitions later.",4,bottom+32,397,30,14,MUTED)
    lootList.CanvasSize=UDim2.fromOffset(0,bottom+80)
end
local function selectMonster(change)
    if not mobData then return end
    local ids=mobData.MonsterIds
    if #ids==0 then return end
    local index=table.find(ids,selectedId) or 1
    index=((index-1+change)%#ids)+1
    selectedId=ids[index]
    refreshMobs()
end
prev.Activated:Connect(function() selectMonster(-1) end)
next.Activated:Connect(function() selectMonster(1) end)

local function load()
    setStatus("Loading XP and mob settings...",nil)
    local okXP,resultXP=pcall(function() return getXP:InvokeServer() end)
    if not okXP or type(resultXP)~="table" or resultXP.Authorized~=true then
        setStatus("XP admin settings unavailable or access denied.",false)
    else
        applyXP(resultXP.Data)
    end
    local okMob,resultMob=pcall(function() return getMobs:InvokeServer() end)
    if not okMob or type(resultMob)~="table" or resultMob.Authorized~=true then
        setStatus("Mob admin settings unavailable or access denied.",false)
    else
        mobData=resultMob.Data
        if not selectedId or not mobData.Monsters[selectedId] then
            selectedId=mobData.MonsterIds[1]
        end
        refreshMobs()
        if mobData.PersistenceAvailable then
            setStatus("Admin dashboard ready. Mob changes affect new spawns and loot rolls.",true)
        else
            setStatus("Mob DataStore unavailable; changes cannot be saved.",false)
        end
    end
end
UserInputService.InputBegan:Connect(function(inputEvent,processed)
    if processed or inputEvent.KeyCode~=Enum.KeyCode.F8 then return end
    panel.Visible=not panel.Visible
    dim.Visible=panel.Visible
    if panel.Visible then task.spawn(load) end
end)
selectTab("XP")
print("[Lumia - Lumia Admin Balance] Large F8 dashboard ready: XP & Quests / Mobs & Loot")
