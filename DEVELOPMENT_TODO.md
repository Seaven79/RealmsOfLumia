# REALMS OF LUMIA - DEVELOPMENT TODO

**Roadmap version:** 1.0
**Updated:** 2026-10-14
**Project:** `C:\RobloxDevelopment\RealmsOfLumia`
**Goal:** A playable, persistent fantasy RPG first; expand toward an MMO with ~20 players per server after profiling.

> Working rule: implement the simplest useful feature today, but keep modules, configuration, and save data extensible for future updates. Avoid replacing working systems wholesale.
>
> `[x]` means confirmed by the October 14 Studio Output or inspected source, **not necessarily gameplay-tested**. `[ ]` means still needs work or an in-game verification.

## Current focus - finish the starting area

**Next recommended task:** Verify the recent player-spawn, hurt-audio, combat and wolf-spawn changes in Roblox Studio. Then complete the first wolf kill-to-reward loop.

### Observed working foundation

- [x] MMO server bootstrap initializes and starts the registered services.
- [x] ServiceRegistry tests pass: 3 passed, 0 failed.
- [x] A persistent player profile loads successfully (level 1, gold 0 in the latest log).
- [x] Inventory, equipment, progression, sword, movement, UI, and monster systems report startup.
- [x] Four Forest Wolf monsters spawn and begin navigation.
- [x] The house exclusion system detects `Workspace.ForgottenForest.House`.
- [x] Runtime PlayerSpawn detects two SpawnLocations, disables the extra and configures the active invisible spawn near the house at approximately `(25, 0.5, -20)`.
- [x] The separate sword whoosh/impact audio controller reports that it is ready.

### PHASE 0 - Verify and polish what is already installed (highest priority)

- [ ] **Player spawn:** Confirm the player *actually* appears on clear ground near the house at join and after death/respawn, with no visible spawn pad.
- [ ] **Second floor square:** Identify it in Roblox Studio Explorer; remove it from the saved place only if it is confirmed unnecessary. The runtime script currently disables the extra SpawnLocation; it does not delete source map objects.
- [ ] **Player hurt audio:** Confirm the short hurt/grunt sound plays exactly when a wolf reduces player health; avoid duplicate grunts and avoid sound on healing.
- [ ] **Swing and hit audio:** Swing should play a whoosh even on a miss. Impact should play only on a confirmed hit and feel synchronized.
- [ ] **Melee on steps:** Re-test sword hits at different elevations and against walls; hits should register within range but never through solid walls.
- [ ] **Wolf safe spawning:** Check that wolves never appear inside trees, walls, houses, or other wolves; blocked locations should relocate or skip spawning.
- [ ] **Wolf death pose:** Confirm defeated wolves lie sideways, stay briefly, clean up, and respawn normally.
- [ ] **Zone announcement:** Confirm the dark/gold `Forgotten Forest` banner appears once on entry, fades away, and supports future tagged regions without flickering.
- [ ] **Two-player test:** Join using two Studio test clients. Confirm spawns, monster hits and damage events are correct for both players.

**Phase 0 done when:** No regression in existing gameplay; sounds, spawns, collision and death presentation work during live tests.

## PHASE 1 - First complete RPG gameplay loop (next development milestone)

- [ ] **Reliable kill credit:** The server records the player who dealt the verified killing damage to a wolf; grant a reward only once per kill.
- [ ] **Wolf rewards:** Connect kill credit to the existing `ProgressionService` so wolf kills award the configured XP/gold. The inspected `MonsterService` explicitly has rewards disabled pending verified attribution.
- [ ] **Level feedback:** Show visible XP gain / level-up feedback without changing authoritative progression calculations.
- [ ] **One item drop:** Add a simple `Wolf Pelt` drop through a reusable loot table and the existing inventory service (no special loot script for each monster).
- [ ] **Inventory persistence:** Verify wolf loot and equipment persist after leaving and rejoining, without duplication.
- [ ] **One complete quest:** Implement or integrate Eldric's `Collect 3 Crates` starter quest with server-checked objectives, 10 gold reward, and saved completion.
- [ ] **Quest UI:** Show active objectives and turn-in state; use the modular quest data rather than hardcoded text.
- [ ] **Player death/respawn loop:** Define health recovery, safe re-entry near the house, and no duplicate rewards/items.
- [ ] **Acceptance test:** New player joins, kills wolves, receives XP/gold/loot, completes Eldric's quest, leaves and rejoins with correct saved progress.

**Phase 1 done when:** A new player can complete a small, satisfying 10-15 minute loop that survives a rejoin.

## PHASE 2 - Grow Forgotten Forest without overengineering

- [ ] **Map source safety:** Save versioned backups of the Roblox Studio place (`.rbxl` / `.rbxlx`) as well as Git code. Current Rojo mapping does not store the whole Workspace terrain/map in `src`.
- [ ] **Spawn anchors:** Add an explicit `LumiaPlayerSpawnAnchor` beside the house so spawn placement remains intentional when buildings change.
- [ ] **Village polish:** Make safe walking routes, clear entrances, non-overlapping props, and comfortable NPC interaction distances.
- [ ] **Region volumes:** Add and test tagged `LumiaRegion` volumes for future zone names, subtitles, and transitions.
- [ ] **Second creature:** Add a new monster using the same MonsterService / CombatService / loot data and presentation modules; no duplicated combat code.
- [ ] **Creature variety:** Add a few patrol/wander patterns and appropriate aggro boundaries without expensive constant pathfinding.
- [ ] **Environment polish:** Add modest ambient forest audio, lighting, and landmarks after gameplay reliability is established.

**Phase 2 done when:** The forest feels like a small explorable zone with multiple activities, not just a combat test area.

## PHASE 3 - MMO reliability and maintainability

- [ ] **Save recovery:** Test DataStore failure/retry, disconnect during save, and rejoining another server instance.
- [ ] **Data migrations:** Add and test versioned profile migration before changing the saved schema; never wipe existing profiles to ship a feature.
- [ ] **Remote security:** Check all combat, quest, item and equipment requests on the server for ownership, range, cooldown, payload validity and rate limiting.
- [ ] **Automated regression tests:** Cover kill rewards, duplicate hit/reward prevention, inventory transactions, monster spawn clearance and service startup.
- [ ] **Patch safety:** Keep small replacement installers with backups and clear rollback notes. Commit functional changes to Git in focused steps.
- [ ] **Performance:** Profile 20 concurrent players with monsters, effects and UI. Measure before adding complex parallelism or premature optimizations.
- [ ] **Diagnostics:** Make development-only debug toggles for monster spawn rejections, attack misses, reward attribution and save failures.

**Phase 3 done when:** The starting zone remains stable across patches, save errors and a realistic multiplayer load.

## PHASE 4 - Later MMO systems (backlog, not needed now)

- [ ] Additional named regions and portal/zone travel.
- [ ] More quests, dialogue, story and branching progression.
- [ ] Reusable weapons/armor classes, equipment requirements and combat animation sets.
- [ ] Party system and cooperative encounters.
- [ ] Trading and an economy with strong server-side safeguards.
- [ ] Professions, gathering, crafting and vendors.
- [ ] Dungeons, bosses and instanced content after the basic world loop is stable.
- [ ] Cross-server world features and release/deployment strategy.
- [ ] Custom visual/audio polish, settings, accessibility and controller/mobile support.

## Sprint notes - edit these as we go

**Current sprint:** Phase 0 - test the latest installed updates.
**Next coding sprint:** Phase 1 - verified wolf kill credit, XP and gold.
**Known concerns:** Melee from steps was problematic; safe wolf spawns, player hurt sound, invisible house-side spawn, gold zone title and sideways corpse pose need live verification.
**Do not break:** Existing DataStore profiles, inventory, equipment, movement, sword combat, four-wolf spawn system, house exclusion, or Rojo structure.

### Simple test log

| Date | Feature | PASS / FAIL | Details / next fix |
| --- | --- | --- | --- |
| 2026-10-14 | Server startup / registry | PASS (logs) | 3/3 registry tests, MMO Core started |
| 2026-10-14 | Invisible spawn configuration | PASS (logs only) | Needs visual and respawn check |
| 2026-10-14 | Combat audio / corpse pose / spawn clearance | NOT YET TESTED | Confirm in Roblox Studio |

---

**How to update this file:** Tick boxes (`[ ]` to `[x]`) when a feature passes testing. Change the current sprint and test log as development continues. Keep this Markdown file at the project root; it is a planning document and is not loaded as a Roblox script.
