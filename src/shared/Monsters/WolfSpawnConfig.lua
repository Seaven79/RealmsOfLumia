-- REALMS OF LUMIA | Wolf population / map-area settings.
-- For exact designer control, tag one invisible anchored Part in Workspace
-- with "LumiaWolfSpawnArea"; its footprint defines the wolf habitat.
local Config={}
Config.WolfCount=12
Config.ActivationRadius=125
Config.DespawnRadius=155
Config.InitialPlacementAttempts=300
Config.RespawnPlacementAttempts=24
Config.MinAnchorSeparation=16
Config.MaxMapSide=360 -- cap inferred map bounds; explicit spawn region may exceed this
Config.FallbackMapSize=Vector2.new(240,240)
return Config
