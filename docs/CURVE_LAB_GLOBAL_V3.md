# Realms of Lumia — F7 Global Monster Balancing v3

Status: source patch for the **existing v2 Curve Lab**. Validate in Roblox Studio before production deployment. This document lives in the game project's `docs` folder and can be committed to Git.

## What changed

**Every monster type** spawned through `MonsterService:SpawnMonster` uses **the same global curve**. Selecting Forest Wolf / Dire Wolf / Gatewatch / Guardian in F7 affects the graph **only**. You no longer have to configure each species individually.

F7 now has a scrollable list of 12 independent global curves:

| Curve | Affects |
|---|---|
| Health | MaxHealth on newly spawned monsters |
| Damage | Damage per monster hit |
| Defense | Incoming player sword damage multiplier: defense 2x = damage / 2 |
| AttackSpeed | Monster AttackCooldown; larger multiplier = faster attack, shorter cooldown |
| Movement | WalkSpeed and ChaseSpeed |
| Detection | DetectionRadius and ChaseLimit; not through walls |
| Wander | WanderRadius for idle roaming |
| AttackRange | AttackRange, subject to existing melee reach / line-of-sight logic |
| Respawn | Time after corpse removal, outer-zone and Guardian schedules; larger multiplier = shorter delay |
| LevelXP | Player XP-to-next-level; this particular curve refreshes immediately, unlike monster stats |
| KillXP | XP award locked when each monster spawns |
| Gold | Gold award locked when each monster spawns |

**Base values come from your existing MonsterConfig / F8 MobTuning service.** Default Classic parameters have no effect on original balances. Existing monster levels remain fixed by their zones. Attack cooldown, movement, detection, and range have server-side safety limits. Respawn applies when scheduling a new timer (in practice, after the previous monster is removed); existing cooldowns already ticking are not rescheduled.

Existing monsters keep every stat and XP/gold snapshot as of their spawn, even if you edit/revert/publish curves while they live. Future spawn values use the effective current global config.

## Formula

```
P(L,a,b) = 1 + a*(L-1) + b*(L-1)^2
factor = Scale * (P(L,Linear,Quadratic) / P(L,0.10,0.002)) ^ exponent
```

`Damage` exponent is 0.85; all others use 1. `Scale` controls global multiplier at *every* monster level; `Linear` and `Quadratic` control how differently higher levels scale. **At level 1, Linear/Quadratic have no impact**. For `AttackSpeed` and `Respawn`, the factor is inverted against their durations (attack cooldown and respawn seconds).

Limits: Scale 0.25–3, Linear 0–0.4, Quadratic 0–0.02, with per-stat clamping where required. Server validates every adjustment and only owner UserId defined in `src/server/Admin/BalanceSettings.lua` can call its remotes. The F7 UI also hides from non-owners; this is convenience, not authorization.

## First test — safe and reversible

1. Stop Play and install `.ps1` with `-Apply`. The script requires the known v2 files and known original monster/AI/combat source, and creates a timestamped backup/rollback manifest. If your files have changed, **do not force**; provide a fresh source ZIP.
2. Run `& 'C:\rojo\rojo.exe' serve default.project.json` from the game root and reconnect the Rojo plugin.
3. Restart Play in a **Studio test server**. Open F7 or use the gold `CURVE LAB [F7]` launcher. New categories are in the scrolling left editor panel.
4. Use **CLASSIC** preset first. Select **Health**, set `Scale=2`, and wait for the green server confirmation. Existing living wolves stay at baseline. Kill one and wait for its replacement. A 65-HP Forest Wolf should respawn with ~130 HP unless F8 tuned the base.
5. Select Dire Wolf as *graph preview only*. Its **next** spawn should also receive the same 2x global HP factor, with its own level and base HP. Change preview species again; it must not change which monsters the global setting affects.
6. Test **AttackSpeed** at Scale=2: the next Forest Wolf should attack every ~1s rather than its baseline 2s, respecting combat mechanics. Test **Defense** at Scale=2: next spawned creature takes approximately half as much sword damage from identical hits.
7. Test **Movement** and **Detection** at small adjustments first (e.g. 1.15). Test **Respawn** at 2: the *next completed respawn cycle* should shorten; it does not make existing corpses vanish or restart timers already scheduled.
8. Click **REVERT TEST**. Future monsters once again spawn under the published baseline. Existing monsters are intentionally unchanged. Restart Play and test with a second player to confirm F7 is invisible/inaccessible.

**Critical:** Local test duration is 8 minutes and auto-reverts on expiry/owner departure. Earned XP or gold during a test can still be saved by normal player persistence. Do reward tests with a disposable test account / isolated test place. Never force-roll back a live player's DataStore to experiment.

## F7 behavior and owner security

- Editing a valid value in Studio/private server applies it after a 0.55s debounce **only if SERVER TEST is ON**.
- SERVER TEST is restricted to Studio and private servers, and to owner `BalanceSettings.OwnerUserId` on the **server**. In public live servers F7 is view-only. Remote requests from non-owners are rejected.
- `REVERT TEST` stops the local override. Server automatically expires the test after eight minutes.
- F8 still owns per-monster baseline numbers and persistent adjustments; F7 global settings multiply the baseline. Do not alter F8 and F7 at the same time until the precedence is clear.
- The preview graph uses a **hypothetical** level, and never changes monster levels.

## Live global balancing without restarts

After this code is deployed to all game servers, owner can publish numerical changes using Roblox **Creator Hub > Experience Configs**, JSON key `lumia_global_curves_v1`. The running server's `GlobalCurveConfig` script reads approved configs through ConfigService, listens for updates, validates and caches them. The game itself cannot publish changes and has **no API keys**.

Example v3 neutral config:

```json
{
  "Version": 3,
  "Values": {
    "Health": {"Scale":1,"Linear":0.1,"Quadratic":0.002},
    "Damage": {"Scale":1,"Linear":0.1,"Quadratic":0.002},
    "Defense": {"Scale":1,"Linear":0.1,"Quadratic":0.002},
    "AttackSpeed": {"Scale":1,"Linear":0.1,"Quadratic":0.002},
    "Movement": {"Scale":1,"Linear":0.1,"Quadratic":0.002},
    "Detection": {"Scale":1,"Linear":0.1,"Quadratic":0.002},
    "Wander": {"Scale":1,"Linear":0.1,"Quadratic":0.002},
    "AttackRange": {"Scale":1,"Linear":0.1,"Quadratic":0.002},
    "Respawn": {"Scale":1,"Linear":0.1,"Quadratic":0.002},
    "LevelXP": {"Scale":1,"Linear":0.1,"Quadratic":0.002},
    "KillXP": {"Scale":1,"Linear":0.1,"Quadratic":0.002},
    "Gold": {"Scale":1,"Linear":0.1,"Quadratic":0.002}
  }
}
```

To raise HP globally 25%, change only `Values.Health.Scale` to `1.25` and increase `Version` before publishing. Revert through Creator Hub config history. If an older v2 config contains only the original five keys, new fields are auto-filled with neutral defaults (backward compatible).

**Code/content patches are different:** they require publishing a new Roblox experience version and coordinated restart of old servers. Experience Configs only distribute **data**, not Luau source.

## Technical integration

- Shared: `src/shared/Progression/CurveMath.lua` — deterministic math, categories, validation, compatibility.
- Server: `src/server/Admin/CurveLabService.lua` — read effective values (temporary test or published config), generate per-spawn definitions.
- Server: `src/server/Admin/GlobalCurveConfig.lua` — Roblox Experience Config read + refresh; legacy config support.
- Server: `src/server/Monsters/MonsterService.lua` — single spawn stat snapshot, XP/gold, defense and respawn rate attributes.
- Server: `src/server/Combat/SwordCombatService.lua` — applies snapshotted Defense only to sword attacks. **Other future player abilities must explicitly use the same defense calculation** when implemented.
- Server: `src/server/Monsters/SpawnManager.lua` — fixed-forest wolf respawn cooldown.
- Server: `src/server/Monsters/LumiaOuterMonsters.server.lua` — outer zone respawn cooldown and removal of duplicate automatic-respawn ownership.
- Server: `src/server/Monsters/GuardianEncounter.server.lua` — quest Guardian cooldown and removal of duplicate automatic-respawn ownership.
- Client: `src/client/Admin/LumiaCurveLab.client.lua` — F7 graph and scrollable all-stats editor.

All changes are event-driven, only on value change or monster spawn/attack/corpse removal. No per-frame global rescans.

**Scope note:** Defense currently covers the existing sword combat pipeline, not damage from future weapon systems. Movement/attack-range settings are still bounded by the existing anti-wall/pathfinding and melee stand-off logic. Rare item loot tables are still set in F8; F7 Gold affects coins, not item rarity. Some boss scripts may have intentionally scripted phases/requirements that global curves do not override.

## Rollback

The installer prints `Backup: <path>`. Copy that exact folder into:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\Downloads\Install-RealmsOfLumia-Global-CurveLab-v3.ps1" -Rollback -BackupDir "C:\RobloxDevelopment\RealmsOfLumia\.lumia-backups\<exact-backup-name>"
```

Rollback **refuses** if any installed source file changed after installation, and validates all backups first. It does not revert earned rewards or change persisted player profiles. Commit to Git only after Studio verification.
