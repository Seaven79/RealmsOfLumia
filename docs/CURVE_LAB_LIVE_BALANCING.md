# Realms of Lumia — Curve Lab & Live Balancing Guide

**Guide version:** 1.0
**Last updated:** 2026-10-17
**Project:** `C:\RobloxDevelopment\RealmsOfLumia`
**Document location:** `docs/CURVE_LAB_LIVE_BALANCING.md`

> **Read this first:** This document distinguishes the Curve Lab **already installed** from the **planned global, spawn-only and Roblox Experience Configs integration**. A feature described as *planned* is **not** available merely because this guide was installed. The documentation installer changes no gameplay scripts.

## 1. The design we chose

Realms of Lumia is a classic MMORPG, with fixed monster levels per zone. Monster levels do not automatically rise to match a player. The goal is to adjust the **difficulty curve for every monster type at once**, while preserving each type's unique base stats and special characteristics.

**Desired final behavior:**

1. Open **F7 — Curve Lab** as the game's authorized owner.
2. Adjust global health, damage, XP and gold curves; use the graph to preview levels 1–59.
3. Run a **temporary test on this server**; only monsters that spawn **after** the settings change receive the new monster stats.
4. Approve and **publish permanent global values through Roblox Creator Hub / Studio Experience Configs**.
5. Running servers receive the new configuration and apply it to **future spawns**, without changing monsters already alive or interrupting combat.
6. Restore a previous configuration using Experience Configs **History → Restore → Publish** if needed.

**Not part of the design:** constantly recalculating every monster each frame, manually modifying each monster, distributing publication credentials to client scripts, or changing persistent player profiles when a curve is adjusted.

## 2. What's available now versus planned

| Feature | Status in the last verified installed Curve Lab (v1.1) | Target upgrade |
|---|---|---|
| F7 owner Curve Lab with optional on-screen button | Installed; client startup confirmed in Studio logs | Keep |
| Preview of 5 curves: monster HP, damage, required XP, kill XP, gold | Installed | Keep, clarify global scope |
| Classic / Gentle / Hardcore presets | Installed | Keep |
| **TEST THIS SERVER** temporary change (8 min) | Installed; limited to Studio/private servers | Keep, make spawn-only and global across types |
| STOP / REVERT TEST | Installed | Keep |
| Apply global curve to all monster types | Not yet verified for every spawn implementation | Implement and test all monster families |
| Change current living monsters instantly | Not the intended final policy | Do **not** do this |
| Automatic future-spawn-only snapshot of HP, damage and rewards | Needs end-to-end verification / integration | Implement |
| Native Roblox Experience Configs global publication | **Not installed** in verified v1.1 | Integrate |
| Balance revision history / live rollback | Roblox provides history for Experience Configs; game integration pending | Integrate |
| Publish from F7 | **Not available, intentionally** | Continue publishing through Creator Hub / Studio for security |

The current F8 balance dashboard is a **different** system. It already includes persistent XP/quest balance options. Do not confuse F7's temporary test with F8's saved changes. Before rollout, test precedence between the two systems explicitly.

## 3. How the global curves work

A monster keeps its own **definition** (species, level, elite/boss status, base HP, base damage, respawn timer and unique mechanics). The game applies a **global multiplier** to the numerical stats being tuned. Therefore the same global curve can affect wolves, skeletons, future creatures and bosses without editing each definition.

The v1 Curve Lab formula is deliberately **relative to existing game balance**: neutral settings do not replace the real monster's stats.

```text
Power(level, linear, quadratic) = 1 + linear × (level − 1) + quadratic × (level − 1)^2

ReferencePower(level) = Power(level, 0.10, 0.002)

Multiplier(kind, level) = Scale × [Power(level, Linear, Quadratic) /
                                   ReferencePower(level)] ^ exponent

exponent = 0.85 for monster damage; 1 for other curves.

NewStat = round(BaseStat × Multiplier)
```

**Important detail:** A level 1 monster has `(level − 1) = 0`, so changing **Linear** or **Quadratic** has no effect on that monster's value. To test a level 1 Forest Wolf, change **Scale** (e.g. 1.00 → 2.00 for HP). For a level 10 or level 20 creature, changing Linear/Quadratic visibly alters the slope.

This is a **global curve**, not automatic level scaling. Changing the level-20 graph does not turn a level-1 wolf into a level-20 wolf; the graph can display hypothetical monsters.

## 4. Recommended Curve Lab workflow

### A. Preview safely

1. Open **F7** (or its on-screen **CURVE LAB** button).
2. Start from **Classic**. This is the reference curve; it should preserve the existing game values at neutral settings.
3. Select **Monster HP**, **Damage**, **XP Required**, **Kill XP** or **Gold**.
4. Edit **Scale**, **Linear** or **Quadratic** and inspect the graph across levels.
5. Check the selected species' **actual level** before judging the results. The graph may show a hypothetical level.

**Preview only** changes nothing in live combat.

### B. Local test — spawn-only (target behavior)

1. Use an **isolated Studio test place or disposable test profile**, not your real progression profile.
2. Change **global HP Scale** to `2.00` while leaving the other curves neutral.
3. Start a **TEST THIS SERVER** session.
4. Look at a wolf that existed **before** the test: its HP should be unchanged.
5. Defeat/despawn the wolf and let it respawn: **the new wolf** should get the new HP.
6. Repeat with more than one monster type and a high-level creature to verify the same global curve affects all.
7. Stop/revert the test and respawn another wolf: it should use the original configuration.
8. Check server Output, especially for curve validation or remote errors.

In the uploaded game baseline, a Forest Wolf's default values were **level 1, 65 HP, 9 damage, 7 XP, 2 gold**, but any existing F8 per-monster tuning may change these. With no F8 HP override, `HP Scale = 2` would produce **130 HP** on the next spawn.

**Test duration:** the verified v1 service uses **480 seconds (8 minutes)** and automatically restores its server-local test configuration. It also stops the test when the owner leaves.

**Warning:** XP and gold legitimately earned during a temporary test may still be saved into the player's real profile. Reverting the curve does **not** undo rewards already earned.

### C. Changing an active live server (future global config support)

1. Edit global curve values in **Creator Hub → Experience → Configs**, or **Roblox Studio → File → Open Configs**.
2. **Stage** the change. Staged changes are available for Studio testing but do not yet go live to players.
3. Verify the curve in a test session.
4. Click **Publish now** (or a gradual rollout) in the Roblox config UI.
5. Roblox pushes the configuration to running servers, typically in **15–60 seconds**, but sometimes longer.
6. The Realms of Lumia server's `BalanceService` should validate the version and update its **cached curve**.
7. **Already-spawned monsters keep their snapshot.** All **new spawns** use the updated curve.
8. Track rollout by logging the config version and, later, showing it in F7.

**Note:** these steps are the intended operation **after the native config integration is implemented and tested**. Publishing a new Config key now will not automatically affect the game; scripts must explicitly read it.

### D. Restoring an earlier version

For a local temporary test, choose **STOP / REVERT** (or let it expire). Subsequent spawns use the previous cached settings.

For globally published configs, use **Creator Hub → Configs → History → Restore** for the desired entry, then **publish** that restored value. Servers use it for **new monsters**, not retroactively for current encounters.

For a code regression, use the patch's provided backup/rollback and an appropriate Roblox server restart process. A data/config rollback and a code rollback are separate operations.

## 5. Why we update at respawn

**No repeated background calculations.** An individual monster takes a stat snapshot when it spawns, including its global balance revision. It retains that snapshot for the entire lifetime of that spawn. New spawns use the newest **validated** cached revision.

This avoids:

- Changing a boss's maximum HP during a fight;
- Sudden changes to attack damage mid-encounter;
- Repeated work every frame or every AI tick;
- Updating all monster Humanoids immediately across a busy server.

It also gives cleaner test results, because the monster's HP/damage/reward values all belong to a single configuration version.

**Recommended reward rule:** snapshot kill XP and gold at spawn as well; otherwise a monster's payout could unexpectedly change between spawn and death. Quest rewards and XP-to-next-level are separate systems and need explicit testing for already-progressing characters.

## 6. What the server-side architecture should look like

```text
[Owner F7 UI (client)]                    [Creator Hub / Studio]
         |                                   |
         | owner requests + preview          | published config revision
         v                                   v
[CurveLabBridge.server.lua]              [Roblox ConfigService]
         |  validates owner UserId            |
         v                                   v
[CurveLabService.lua] ---- override --> [BalanceService]
  server-local 8-minute test              validate/cache/version
                                             |
                                             v
                                     [Global CurveMath.lua]
                                             |
                                             v
                                   [MonsterService / spawner]
                                             |
                                             v
                             NEW monster stat/reward snapshot only
```

Relevant project source paths (existing/verified in the uploaded baseline or v1 Curve Lab release):

- `src/client/Admin/LumiaCurveLab.client.lua` — F7 owner interface.
- `src/server/Admin/CurveLabBridge.server.lua` — owner-only server remote and input validation.
- `src/server/Admin/CurveLabService.lua` — temporary local test override and expiration.
- `src/server/Admin/BalanceService.lua` — existing persistent F8 balance settings; integration point for published global curves.
- `src/server/Admin/BalanceSettings.lua` — server-side owner numeric UserId and limits.
- `src/shared/Progression/CurveMath.lua` — deterministic, shared mathematical calculations.
- `src/server/Monsters/MonsterService.lua` — monster stat creation / spawn logic.
- `src/shared/Monsters/MonsterConfig.lua` — per-creature base definitions.
- `src/server/Progression/ProgressionBridge.server.lua` — server-confirmed XP rewards.
- `src/shared/Progression/ProgressionConfig.lua` — baseline per-level XP requirements; current level cap 60.

Rojo maps `src/client`, `src/server` and `src/shared` into the live Roblox hierarchy. This `docs/` file is for humans and version control and is **not** replicated into the game.

## 7. Security and safe rollout rules

1. **The client is never trusted.** All remotes check the caller's numeric owner UserId on the **server**, not a display name or a client claim.
2. Verify curve data: recognized keys only, finite numbers, safe ranges, no unexpected tables or oversized payloads.
3. Never let the client publish Experience Configs or hold API keys/secrets. Global publish occurs through authorized Creator Hub / Studio access.
4. Prefer a single **versioned JSON config** (planned key name `lumia_global_balance_v1`), with a schema version, revision and the five curves. The exact key must match source code once implemented.
5. A missing or invalid config must fall back to verified game defaults; a load error must not wipe data.
6. Ensure the precedence of base definitions, existing F8 adjustments, published global curve, and local F7 test overlay is documented and tested; **local test must never alter the published value**.
7. Keep **player DataStore schema and character progression unchanged** when releasing balance-only updates.
8. Keep changes server-local during tests. Never publish an untested draft accidentally.
9. Log the config version used for a monster and the effective settings applied at spawn, initially in Studio diagnostics only.
10. Use git checkpoints and rollback backups before deploying any Lua/script updates.

## 8. Monster types and exceptions

The default global curve affects **all monster families** through shared stat creation, including future creatures. Individual monsters retain their base level, health ratio and special mechanics. Optional overrides should be rare and explicit (for example, a scripted raid boss phase), rather than requiring you to edit every wolf and skeleton.

Special cases to check before rollout:

- Bosses should hold a single consistent balance snapshot throughout the entire encounter.
- Creature classes such as elites should keep their intended multipliers.
- Bosses with scripted health thresholds should calculate from the spawned snapshot.
- Monsters from every spawner (forest, outer zones, instanced dungeon, scripted event) must pass through the shared stat resolver.
- Player-versus-player stats should **not** inherit PvE monster curves.

## 9. Updating the game code itself

**Balance values ≠ code changes.** Publishing a global curve does not add new Lua logic, animations, dungeons or UI features. For those:

1. Work on a separate local test branch and save a git checkpoint.
2. Test using Rojo and Roblox Studio, including a profile save/rejoin test.
3. Publish the experience code/content from Studio.
4. Plan server updates. Existing Roblox servers can remain on the old place version until Roblox's restart workflow moves players to newer servers.
5. For disruptive updates, notify players and schedule a controlled restart in **Creator Hub → Server Management → Restart Servers**.
6. Verify save/release behavior on shutdown, then monitor server versions and errors.

Do not rely on a config update to perform code migration. Do not migrate persistent player data as an incidental side effect of balancing.

## 10. Acceptance checklist for the planned upgrade

- [ ] F7 opens for the authorized owner; non-owners cannot retrieve or change Curve Lab values.
- [ ] A neutral curve leaves the original game stats unchanged.
- [ ] One global HP curve adjusts **all** monster types at their **next spawn**.
- [ ] Existing living monsters remain untouched by settings changes.
- [ ] New monsters use the newest valid revision (not stale cached settings).
- [ ] Damage, XP and gold follow the same consistent spawn revision.
- [ ] Level-1 Scale tests change stats; level-1 Linear/Quadratic tests correctly do not.
- [ ] Changing one curve does not inadvertently change unrelated curves.
- [ ] Temporary test expires and returns to original settings; published balance stays unchanged.
- [ ] Current and future spawn systems share one stats path.
- [ ] Roblox Experience Config is staged/published and received by a running server.
- [ ] Missing/invalid Experience Config correctly falls back to original values.
- [ ] Global rollback applies to the **next spawns** and leaves existing encounters alone.
- [ ] Player rejoin saves profile, gold, XP and equipment correctly.
- [ ] No redundant per-frame recalculation; no performance regression in a 20-player test.

## 11. Useful references

- Roblox Experience Configs: https://create.roblox.com/docs/production/configs
- Roblox ConfigService API: https://create.roblox.com/docs/reference/engine/classes/ConfigService
- Project architecture: `README.md`, `DEVELOPMENT_TODO.md` and `default.project.json`

**Keep this guide updated with each Curve Lab release.** Record the final Experience Config key/schema once coded, and change the status table above only after live Studio tests confirm the feature works.
