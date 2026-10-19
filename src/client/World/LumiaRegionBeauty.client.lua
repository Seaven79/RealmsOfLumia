-- REALMS OF LUMIA V19 | REGION BEAUTY PASS
-- Client-only props: no replicated decoration, no collisions, no save edits.
-- Deterministic, capped, yields during construction, with streamed-map support.
local Workspace=game:GetService("Workspace")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local forest=Workspace:WaitForChild("ForgottenForest",30)
local grass=forest and forest:FindFirstChild("Grassland",true)
if not grass or not grass:IsA("BasePart") then
    warn("[Lumia Beauty] Main forest ground missing; skipping pass")
    return
end
local old=Workspace:FindFirstChild("LumiaRegionBeautyV19")
if old then old:Destroy() end
local decor=Instance.new("Folder")
decor.Name="LumiaRegionBeautyV19"
decor.Parent=Workspace
local rng=Random.new(1919)
local offsets={
    {name="OldRoad",x=58,z=65,count=24,spanX=61,spanZ=36,seed=1},
    {name="CreekBend",x=-18,z=-73,count=28,spanX=71,spanZ=28,seed=2},
    {name="AncientStones",x=68,z=-6,count=26,spanX=37,spanZ=41,seed=3},
}
local visuals={
    {name="ThornwatchGlade",x=grass.Size.X/2+62,z=0,count=28,spanX=52,spanZ=68,seed=4},
    {name="FirstGateApproach",x=grass.Size.X/2+188,z=0,count=24,spanX=52,spanZ=68,seed=5},
}
for _,v in ipairs(visuals) do offsets[#offsets+1]=v end
local palettes={
    [1]={stone=Color3.fromRGB(133,123,103),plant=Color3.fromRGB(101,112,76),glow=Color3.fromRGB(244,201,126)},
    [2]={stone=Color3.fromRGB(91,113,119),plant=Color3.fromRGB(74,124,109),glow=Color3.fromRGB(129,194,194)},
    [3]={stone=Color3.fromRGB(119,109,137),plant=Color3.fromRGB(91,101,91),glow=Color3.fromRGB(171,148,223)},
    [4]={stone=Color3.fromRGB(91,106,95),plant=Color3.fromRGB(72,107,75),glow=Color3.fromRGB(116,191,151)},
    [5]={stone=Color3.fromRGB(108,111,131),plant=Color3.fromRGB(91,106,109),glow=Color3.fromRGB(132,195,231)},
}
local function part(name,kind,size,color,material,cf,parent)
    local p=Instance.new(kind)
    p.Name=name;p.Size=size;p.Color=color;p.Material=material;p.CFrame=cf
    p.Anchored=true;p.CanCollide=false;p.CanTouch=false;p.CanQuery=false;p.CastShadow=false
    p.Parent=parent or decor
    return p
end
local function groundAt(x,z,zone)
    local pos=grass.CFrame*Vector3.new(x,grass.Size.Y/2+150,z)
    local ray=RaycastParams.new()
    ray.FilterType=Enum.RaycastFilterType.Exclude
    ray.FilterDescendantsInstances={decor}
    ray.RespectCanCollide=true
    local hit=Workspace:Raycast(pos,Vector3.new(0,-320,0),ray)
    if not hit or hit.Normal.Y<0.83 then return nil end
    if hit.Instance~=grass and hit.Instance.Name~="ThornwatchGround"
        and hit.Instance.Name~="FirstGateGround" and not hit.Instance:IsA("Terrain") then
        return nil
    end
    return hit.Position
end
local function rock(where,pal,scale)
    local b=part("MossyBoulder","Part",Vector3.new(3.2,1.35,2.3)*scale,
        pal.stone,Enum.Material.Slate,CFrame.new(where+Vector3.new(0,.35*scale,0))
        *CFrame.Angles(0,rng:NextNumber(-3,3),0))
    b.Shape=Enum.PartType.Ball
    local moss=part("RockMoss","Part",Vector3.new(2.1,.26,1.25)*scale,
        pal.plant,Enum.Material.Grass,b.CFrame*CFrame.new(0,.58*scale,0))
    moss.Shape=Enum.PartType.Ball
end
local function reeds(where,pal)
    for i=1,5 do
        local angle=i*2.399963
        local radius=math.sqrt(i)*.36
        local h=rng:NextNumber(1.0,2.2)
        part("Reed","Part",Vector3.new(.12,h,.12),pal.plant,Enum.Material.Grass,
            CFrame.new(where+Vector3.new(math.cos(angle)*radius,h/2,math.sin(angle)*radius)))
    end
end
local function lantern(where,pal)
    part("TrailLanternPost","Part",Vector3.new(.34,4.0,.34),Color3.fromRGB(99,77,51),
        Enum.Material.Wood,CFrame.new(where+Vector3.new(0,2,0)))
    local lamp=part("WarmTrailLantern","Part",Vector3.new(.72,.9,.72),pal.glow,
        Enum.Material.Neon,CFrame.new(where+Vector3.new(0,4.2,0)))
    local light=Instance.new("PointLight")
    light.Color=pal.glow;light.Range=13;light.Brightness=.65;light.Parent=lamp
end
local function rune(where,pal,scale)
    local pillar=part("WeatheredMenhir","Part",Vector3.new(2,6,1.9)*scale,
        pal.stone,Enum.Material.Slate,CFrame.new(where+Vector3.new(0,3*scale,0))
        *CFrame.Angles(0,rng:NextNumber(-3,3),math.rad(rng:NextInteger(-5,5))))
    local face=part("ForgottenGlyph","Part",Vector3.new(.18,1.65,1.15)*scale,
        pal.glow,Enum.Material.Neon,pillar.CFrame*CFrame.new(1.03*scale,.45*scale,0))
    face.Transparency=.35
end
local function flower(where,pal)
    for i=1,4 do
        local x=rng:NextNumber(-.7,.7)
        local z=rng:NextNumber(-.7,.7)
        local h=rng:NextNumber(.6,1.3)
        part("WildflowerStem","Part",Vector3.new(.09,h,.09),pal.plant,Enum.Material.Grass,
            CFrame.new(where+Vector3.new(x,h/2,z)))
        local bloom=part("Wildflower","Part",Vector3.new(.27,.27,.27),pal.glow,
            Enum.Material.SmoothPlastic,CFrame.new(where+Vector3.new(x,h,z)))
        bloom.Shape=Enum.PartType.Ball
    end
end
local total=0
for _,zone in ipairs(offsets) do
    local pal=palettes[zone.seed]
    local zdir=zone.seed<=3 and -1 or 1
    local placed=0
    for i=1,zone.count do
        -- Preserve a broad clear walking corridor along the center of outer ground.
        local dx=rng:NextNumber(-zone.spanX,zone.spanX)
        local dz=rng:NextNumber(-zone.spanZ,zone.spanZ)
        if zone.seed>=4 and math.abs(dz)<16 then dz=dz<0 and -18 or 18 end
        local where=groundAt(zone.x+dx,zone.z+dz,zone)
        if where then
            if zone.seed==1 then
                if i%7==0 then lantern(where,pal) elseif i%3==0 then rock(where,pal,.75) else reeds(where,pal) end
            elseif zone.seed==2 then
                if i%3==0 then rock(where,pal,.7) else reeds(where,pal) end
            elseif zone.seed==3 then
                if i%4==0 then rune(where,pal,.8) else rock(where,pal,.55) end
            elseif zone.seed==4 then
                if i%5==0 then rune(where,pal,.7) else reeds(where,pal) end
            else
                if i%3==0 then rune(where,pal,.8) else rock(where,pal,.7) end
            end
            total+=1;placed+=1
        end
        if i%8==0 then task.wait() end
    end
    print("[Lumia Beauty] "..zone.name.." decorative clusters: "..placed)
    task.wait()
end
print("[Lumia Beauty] V19 region pass complete; "..total.." client-only clusters")
