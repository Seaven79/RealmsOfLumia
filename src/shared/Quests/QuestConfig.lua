-- Realms of Lumia - The First Paths (pre-alpha content only).
-- Quests are data, not hard-coded in the engine. Replace this table for the real story.
local QuestConfig = {}
QuestConfig.CampaignId = "FirstPathsPreAlphaV1"
QuestConfig.HitCreditSeconds = 10
QuestConfig.CoopCreditRadius = 36
QuestConfig.QuestGiverOffset = Vector3.new(11, 0, 8)
QuestConfig.Markers = {
    {Id="trail_1", Zone="ForestTrail", Label="Trail Watchpost", X=-55, Z=-25},
    {Id="trail_2", Zone="ForestTrail", Label="Fallen Oak", X=-77, Z=4},
    {Id="trail_3", Zone="ForestTrail", Label="North Thicket", X=-83, Z=43},
    {Id="road_1", Zone="OldRoad", Label="Old Road Sign", X=26, Z=47},
    {Id="road_2", Zone="OldRoad", Label="Broken Cart", X=61, Z=59},
    {Id="road_3", Zone="OldRoad", Label="Road's End", X=90, Z=84},
    {Id="creek_1", Zone="CreekBend", Label="Waterfall Stone", X=-69, Z=-65},
    {Id="creek_2", Zone="CreekBend", Label="River Crossing", X=-17, Z=-82},
    {Id="creek_3", Zone="CreekBend", Label="Mossy Bridge", X=43, Z=-75},
    {Id="ruins_1", Zone="AncientStones", Label="Forgotten Tablet", X=71, Z=-34},
    {Id="ruins_2", Zone="AncientStones", Label="Moonstone Circle", X=92, Z=2},
    {Id="ruins_3", Zone="AncientStones", Label="Guardian's Arch", X=51, Z=29, Landmark=true},
    -- Ritual challenges: investigate three separate sites IN ORDER. Existing quest IDs remain stable.
    {Id="wards_1", Zone="CrossingWards", Label="South Crossing Ward", X=-48, Z=-42},
    {Id="wards_2", Zone="CrossingWards", Label="Creekside Ward", X=-20, Z=-52},
    {Id="wards_3", Zone="CrossingWards", Label="North Crossing Ward", X=11, Z=-43},
    {Id="fires_1", Zone="CampBeacons", Label="Hunter Campfire", X=-52, Z=28},
    {Id="fires_2", Zone="CampBeacons", Label="Trail Lookout Fire", X=-27, Z=44},
    {Id="fires_3", Zone="CampBeacons", Label="Roadside Signal Fire", X=12, Z=48},
    {Id="seals_1", Zone="AncientSeals", Label="Seal of the Pathfinder", X=43, Z=-24},
    {Id="seals_2", Zone="AncientSeals", Label="Seal of the Watch", X=69, Z=2},
    {Id="seals_3", Zone="AncientSeals", Label="Seal of the Gate", X=48, Z=21},
}
-- V17: quest XP dominates (approx 95% to level 5); 3h duo playtest target.
-- Existing F8 balance overrides may alter the real XP curve and should be reset in DEV before timed testing.
QuestConfig.Quests = {
    {Id="fp01", Name="A Call from the Village", Description="Defeat wolves threatening the nearby trail.", Kind="Kill", MonsterId="ForestWolf", Count=3, XP=150, Gold=10, AcceptText="The village hunters returned without their supplies. Wolves prowl by the trail and our people are afraid to venture out. Drive three away; show them the road is ours.", ProgressText="Stay alert. Three wolves stand between the village and a safer path.", TurnInText="The village can breathe easier now. You have earned your first reward. Take it, and remember: even a small act of courage matters."},
    {Id="fp02", Name="Tracks in the Ferns", Description="The old forest paths hold three forgotten clues. Seek them out.", Kind="Explore", Zone="ForestTrail", Count=3, XP=220, Gold=12, AcceptText="The old paths have secrets that even my maps have forgotten. Find the three signs left by the trail keepers and study each one. There is no hurry; look closely.", ProgressText="The trails do not mark themselves. Search the wood for the forgotten signs.", TurnInText="You found them! Those signs were placed by the earliest pathfinders. The forest has a longer memory than any of us."},
    {Id="fp03", Name="A Broken Supply Line", Description="Clear wolves from the routes used by merchants.", Kind="Kill", MonsterId="ForestWolf", Count=5, XP=300, Gold=16, AcceptText="The merchants have stopped using the woodland road. Five hungry wolves haunt their way home. Clear a route before the next caravan arrives.", ProgressText="Merchants will not travel until the wolf pack thins.", TurnInText="The caravan will pass safely. I will see that the merchants know who protected the road."},
    {Id="fp04", Name="The Old Road", Description="Find three traces of the journeys once made through these woods.", Kind="Explore", Zone="OldRoad", Count=3, XP=330, Gold=20, AcceptText="A broken cart was found beyond the last bend. Walk the Old Road and look for what the travelers left behind. Their traces may explain the silence.", ProgressText="Look for the signs of an interrupted journey, not just the road itself.", TurnInText="So the wagon did not vanish without a trace. That may explain why our trade has failed. Thank you for finding the evidence."},
    {Id="fp05", Name="Wards of the Crossing", Description="Restore three protective wards in order while staying alert for wolves.", Kind="Ritual", Zone="CrossingWards", Count=3, XP=360, Gold=24, AcceptText="The crossing wards failed in the night. Restore the South, Creekside, then North wards, in that order. Hold position while channeling; the forest will not stand still for you.", ProgressText="Activate each ward in order. Moving interrupts the channel.", TurnInText="The old wards glow again. You have protected a crossing without simply clearing another pack."},
    {Id="fp06", Name="Whispers of the Creek", Description="The sound of water hides three clues from earlier travelers.", Kind="Explore", Zone="CreekBend", Count=3, XP=400, Gold=28, AcceptText="Water carries stories farther than wind. Along the creek are three objects once known to our village. Follow the sound, and learn why they were left.", ProgressText="Listen for flowing water and search for traces of old travelers.", TurnInText="The creek has returned its stories. Now I can read what the older travelers tried to tell us."},
    {Id="fp07", Name="Signals in the Dark", Description="Reignite three old camp beacons in order to guide travelers home.", Kind="Ritual", Zone="CampBeacons", Count=3, XP=450, Gold=35, AcceptText="Wolves are not the only danger to lost travelers. Relight our three signal fires, starting from the hunter camp. Keep your watch during each ritual.", ProgressText="Hold your ground to light each beacon in sequence. Stop moving while channeling.", TurnInText="Travelers can follow the beacons once more. Good work."},
    {Id="fp08", Name="Stones of a Lost Kingdom", Description="Three weathered relics hint at a lost kingdom.", Kind="Explore", Zone="AncientStones", Count=3, XP=550, Gold=40, AcceptText="These stones stood here before our village had a name. Seek three relics in the ancient ruins; do not mistake an old story for a finished one.", ProgressText="Ancient stones hold memories. Examine three distinct relics.", TurnInText="These relics have marks of the old kingdom. Their meaning may unlock something beyond these woods."},
    {Id="fp09", Name="Fragments from the Pack", Description="Recover five runestone fragments from the forest wolves and return them to Rowan.", Kind="Collect", MonsterId="ForestWolf", DropItemId="WolfRunestone", DropChance=0.42, Count=5, XP=650, Gold=50, AcceptText="I have found markings on broken stone in the wolves' territory. The creatures carry fragments that could unlock the First Gate. Retrieve five fragments from their remains. Only the ones in your bag count, and bring them back to me.", ProgressText="Search the wolves' remains. I need five runestone fragments, not just stories about them.", TurnInText="These fragments are real. Together they form part of the ancient seal. Let me keep them safely while you continue preparing for the gate."},
    {Id="fp10", Name="The Pilgrim's Route", Description="Revisit three remnants of the merchants who came before you.", Kind="Explore", Zone="OldRoad", Count=3, XP=700, Gold=60, AcceptText="The pilgrims crossed this forest before the gate was sealed. Follow the Old Road again. Old clues mean different things once you know their story.", ProgressText="You have seen these roads before. This time, look for their history.", TurnInText="The pilgrim route was not abandoned by chance. You have uncovered more than a path."},
    {Id="fp11", Name="Trial of the Three Seals", Description="Awaken three ancient seals in sequence to prepare the First Gate.", Kind="Ritual", Zone="AncientSeals", Count=3, XP=780, Gold=70, AcceptText="It is time to test your focus, not only your sword. The three ancient seals must be stirred in sequence. Stay still while each responds.", ProgressText="Channel the Pathfinder, Watch, then Gate seals without interruption.", TurnInText="The seals are listening now. You are nearly ready for the Gate."},
    {Id="fp12", Name="The First Gate's Secret", Description="Three relics may reveal why the First Gate remains sealed.", Kind="Explore", Zone="AncientStones", Count=3, XP=850, Gold=85, AcceptText="The first gate does not answer to strength alone. Return to the ruins and study three signs of the old kingdom. Bring back what you discover.", ProgressText="A sealed gate is a question. The ruins contain three pieces of the answer.", TurnInText="These signs belong to the First Gate. You have prepared well, adventurer. The tale continues beyond this chapter."},
}
-- V17: two connected outer-zone chapters and the cooperative First Gate finale.
local finalChapter = {
    {Id="fp13",Name="Into Thornwatch",Description="Defeat four dire wolves beyond the level-four gate.",Kind="Kill",MonsterId="DireForestWolf",Count=4,XP=1900,Gold=180,Giver="ThornwatchScout",MinLevel=4,AcceptText="Our sentries are holding Thornwatch. Help us defeat four dire wolves.",ProgressText="Four dire wolves stand between us and the next road.",TurnInText="Thornwatch is safer. Equip your new gear before pushing onward."},
    {Id="fp14",Name="Thornwatch Cleared",Description="Drive back six more dire wolves and secure the path.",Kind="Kill",MonsterId="DireForestWolf",Count=6,XP=2100,Gold=260,Giver="ThornwatchScout",MinLevel=4,AcceptText="Clear the last dangerous pack. Our route to the First Gate will open when you are level five.",ProgressText="Defeat six dire wolves, then return to the scout.",TurnInText="The pass is secure. You are ready to enter the First Gate Approach."},
    {Id="fp15",Name="Guardians of the Approach",Description="Defeat five gatewatch wolves on the road to the First Gate.",Kind="Kill",MonsterId="GatewatchWolf",Count=5,XP=800,Gold=380,Giver="GateWarden",MinLevel=5,AcceptText="The Gatewatch pack guards the ruins. Defeat five and return before confronting the Guardian.",ProgressText="Hold the approach and defeat five gatewatch wolves.",TurnInText="You've cleared the approach. The Thornbound Guardian is waking."},
    {Id="fp16",Name="The Guardian of the First Gate",Description="Two level-five adventurers must defeat the Thornbound Guardian together.",Kind="Kill",MonsterId="ThornboundGuardian",Count=1,XP=500,Gold=400,Giver="GateWarden",MinLevel=5,AcceptText="Only two prepared adventurers can awaken the Guardian. Join your companion and face it together.",ProgressText="Both adventurers must participate and survive until the Guardian falls.",TurnInText="The First Gate has recognized you both as Guardians of Lumia."},
}
for _, quest in ipairs(finalChapter) do table.insert(QuestConfig.Quests,quest) end
return QuestConfig
